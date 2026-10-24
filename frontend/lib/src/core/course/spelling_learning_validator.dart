import 'dart:convert';

import 'course_attempt.dart';
import 'course_audio_contract.dart';
import 'french_uy_demo_spelling_content.dart';
import 'lesson_section_session.dart';
import 'spelling_learning_command.dart';
import 'spelling_learning_state.dart';
import 'storage/spelling_learning_checkpoint_codec.dart';
import 'storage/spelling_learning_command_codec.dart';

final class SpellingLearningStateValidator {
  const SpellingLearningStateValidator._();

  static void validate(
    SpellingLearningState state,
    FrenchUyDemoSpellingCatalogue catalogue,
  ) {
    try {
      validateFrenchUyDemoSpellingCatalogue(catalogue);
      _validate(state, catalogue);
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid spelling learning state: $error');
    }
  }

  static void _validate(
    SpellingLearningState state,
    FrenchUyDemoSpellingCatalogue catalogue,
  ) {
    final ids = catalogue.rows.map((row) => row.exercise.id).toList();
    if (state.scope.courseId != 'en-fr' ||
        catalogue.activityId != 'en-fr-u-y-spelling' ||
        catalogue.sectionId != catalogue.activityId ||
        catalogue.contentRevision != 1 ||
        state.revision != state.commitOrdinal ||
        state.attempts.length > spellingMaxRetainedAttempts ||
        state.receipts.length > spellingMaxRetainedReceipts ||
        state.slots.length > 1 ||
        state.slots.keys.any((id) => id != catalogue.activityId)) {
      throw const FormatException('Spelling state header is invalid.');
    }
    if (state.commitOrdinal == 0) {
      if (state.slots.isNotEmpty ||
          state.attempts.isNotEmpty ||
          state.receipts.isNotEmpty ||
          state.mistakes.isNotEmpty ||
          state.summaries.isNotEmpty ||
          state.exposures.isNotEmpty ||
          state.completions.isNotEmpty) {
        throw const FormatException('Empty spelling state contains evidence.');
      }
      return;
    }
    if (state.slots.length != 1 ||
        state.receipts.isEmpty ||
        state.receipts.last.commitOrdinal != state.commitOrdinal) {
      throw const FormatException('Spelling state lacks its current receipt.');
    }

    final receiptByCursor = <String, _ReceiptProof>{};
    final receiptByToken = <String, SpellingReceipt>{};
    final priorCursorByGeneration = <int, SpellingCursor>{};
    final modeByGeneration = <int, SpellingRunMode>{};
    var previousOrdinal = state.receipts.first.commitOrdinal - 1;
    for (final receipt in state.receipts) {
      if (receipt.scope != state.scope ||
          receipt.activityId != catalogue.activityId ||
          receipt.commitOrdinal != previousOrdinal + 1 ||
          receipt.commitOrdinal > state.commitOrdinal ||
          receipt.generation != receipt.after.generation ||
          receipt.sequence != receipt.after.sequence) {
        throw const FormatException('Spelling receipt history is invalid.');
      }
      previousOrdinal = receipt.commitOrdinal;
      final command = const SpellingLearningCommandCodec().decode(
        receipt.canonicalCommand,
      );
      if (command.scope != state.scope ||
          command.activityId != receipt.activityId ||
          command.token != receipt.token ||
          command.expected != receipt.before ||
          command.expectedScopeRevision != receipt.commitOrdinal - 1 ||
          !_reachableCursor(command.action, receipt.before, receipt.after)) {
        throw const FormatException('Spelling receipt command is unreachable.');
      }
      final previous = priorCursorByGeneration[receipt.before.generation];
      if (receipt.before.generation > 0 &&
          previous != null &&
          previous != receipt.before) {
        throw const FormatException(
          'Spelling receipt cursors are discontinuous.',
        );
      }
      priorCursorByGeneration[receipt.after.generation] = receipt.after;
      if (receiptByToken.containsKey(receipt.token)) {
        throw const FormatException('Spelling receipt token is duplicated.');
      }
      receiptByToken[receipt.token] = receipt;
      final key = _cursorKey(receipt.activityId, receipt.after);
      if (receiptByCursor.containsKey(key)) {
        throw const FormatException('Spelling receipt cursor is duplicated.');
      }
      receiptByCursor[key] = _ReceiptProof(receipt, command);
      _validateReceiptAnswer(command, receipt, catalogue);
      if (command.action is StartSpellingPractice) {
        modeByGeneration[receipt.after.generation] = SpellingRunMode.practice;
      } else if (command.action is StartSpellingReviewOnly) {
        modeByGeneration[receipt.after.generation] = SpellingRunMode.reviewOnly;
      } else if (command.action case FinishSpellingRun(
        :final recordCompletion,
      )) {
        final currentMode =
            modeByGeneration[receipt.after.generation] ??
            (state.slots[catalogue.activityId]!.cursor.generation ==
                    receipt.after.generation
                ? state.slots[catalogue.activityId]!.checkpoint.mode
                : null);
        if (recordCompletion && currentMode == SpellingRunMode.reviewOnly) {
          throw const FormatException(
            'A retained review-only finish cannot record completion.',
          );
        }
        if (recordCompletion &&
            !state.completions.any(
              (completion) =>
                  completion.scope == state.scope &&
                  completion.activityId == catalogue.activityId &&
                  completion.contentRevision == catalogue.contentRevision &&
                  completion.policyKind ==
                      CompletionPolicyKind.discoveryThreshold &&
                  completion.policyRevision == 1 &&
                  completion.thresholdPercent == 80,
            )) {
          throw const FormatException(
            'A retained qualifying finish lacks completion evidence.',
          );
        }
      }
    }

    final slot = state.slots[catalogue.activityId]!;
    if (slot.scope != state.scope ||
        slot.activityId != catalogue.activityId ||
        slot.cursor != slot.latestReceipt.after ||
        slot.latestReceipt.commitOrdinal != state.commitOrdinal ||
        !_sameReceipt(state.receipts.last, slot.latestReceipt)) {
      throw const FormatException('Spelling slot is not the latest commit.');
    }
    final checkpoint = slot.checkpoint;
    final checkpointJson = const SpellingLearningCheckpointCodec().encode(
      checkpoint,
    );
    final restored = const SpellingLearningCheckpointCodec().decode(
      checkpointJson,
      scope: state.scope,
      catalogue: catalogue,
      policy: checkpoint.policy,
    );
    final session = _session(restored, ids);
    final latestCommand = const SpellingLearningCommandCodec().decode(
      slot.latestReceipt.canonicalCommand,
    );
    _validateLatestSlot(state, slot, latestCommand, session, catalogue);

    for (final receipt in state.receipts) {
      if (!state.slots.containsKey(receipt.activityId)) {
        throw const FormatException('Spelling receipt has no current slot.');
      }
    }
    _validateAttempts(state, catalogue, receiptByCursor);
    _validateCurrentAnswers(state, slot, session, receiptByCursor, ids);
    _validateMistakes(state, catalogue);
    _validateSummaries(state, catalogue);
    _validateExposures(state, catalogue);
    _validateCompletions(state, catalogue);
  }

  static void _validateReceiptAnswer(
    SpellingLearningCommand command,
    SpellingReceipt receipt,
    FrenchUyDemoSpellingCatalogue catalogue,
  ) {
    if (command.action case AnswerSpellingChoice(
      :final itemId,
      :final contentRevision,
      :final selectedOptionId,
      :final expectedOptionIdSnapshot,
      :final playback,
    )) {
      final row = catalogue.rows.singleWhere(
        (candidate) => candidate.exercise.id == itemId,
      );
      if (contentRevision != catalogue.contentRevision ||
          row.exercise.correctOptionId != expectedOptionIdSnapshot ||
          !row.exercise.options.any(
            (option) => option.id == selectedOptionId,
          ) ||
          playback.runGeneration != receipt.after.generation ||
          playback.round < 1) {
        throw const FormatException('Spelling receipt answer is invalid.');
      }
    }
  }

  static void _validateLatestSlot(
    SpellingLearningState state,
    SpellingSlot slot,
    SpellingLearningCommand command,
    LessonSectionSession session,
    FrenchUyDemoSpellingCatalogue catalogue,
  ) {
    final checkpoint = slot.checkpoint;
    final action = command.action;
    if (action case StartSpellingPractice(:final sessionId, :final policy)) {
      final fresh = LessonSectionSession(
        itemIds: catalogue.rows.map((row) => row.exercise.id).toList(),
        sessionId: sessionId,
        contentRevision: catalogue.contentRevision,
        policy: policy,
      );
      if (checkpoint.mode != SpellingRunMode.practice ||
          checkpoint.finished ||
          checkpoint.sessionId != sessionId ||
          checkpoint.runStartRound != 1 ||
          checkpoint.baseline != null ||
          checkpoint.firstAttemptAnswers.isNotEmpty ||
          jsonEncode(fresh.toJson()) != jsonEncode(session.toJson())) {
        throw const FormatException('Latest practice start is not fresh.');
      }
    } else if (action case StartSpellingReviewOnly(:final sessionId)) {
      final baseline = checkpoint.baseline;
      if (checkpoint.mode != SpellingRunMode.reviewOnly ||
          checkpoint.finished ||
          checkpoint.sessionId != sessionId ||
          baseline == null ||
          baseline.sourceGeneration != command.expected.generation ||
          baseline.sourceRound + 1 != checkpoint.runStartRound ||
          checkpoint.runStartRound != session.round) {
        throw const FormatException('Latest review-only start is invalid.');
      }
    } else if (action case AnswerSpellingChoice(
      :final itemId,
      :final selectedOptionId,
      :final expectedOptionIdSnapshot,
      :final playback,
    )) {
      final correct = selectedOptionId == expectedOptionIdSnapshot;
      final row = catalogue.rows.singleWhere(
        (candidate) => candidate.exercise.id == itemId,
      );
      if (checkpoint.finished ||
          session.currentItemId != itemId ||
          !session.answered ||
          session.round != playback.round ||
          session.latestAnswers[itemId] != correct ||
          session.lastCorrect != correct ||
          row.exercise.correctOptionId != expectedOptionIdSnapshot) {
        throw const FormatException(
          'Latest spelling answer differs from session.',
        );
      }
      final isFirstPracticeAnswer =
          checkpoint.mode == SpellingRunMode.practice && session.round == 1;
      if (isFirstPracticeAnswer &&
          checkpoint.firstAttemptAnswers[itemId] != correct) {
        throw const FormatException('First answer differs from checkpoint.');
      }
    } else if (action is AdvanceSpellingItem) {
      if (checkpoint.finished ||
          session.answered ||
          session.phase != LessonSectionPhase.debrief &&
              session.position == 0) {
        throw const FormatException('Latest advance lacks submitted progress.');
      }
    } else if (action is ReviewSpellingMistakes) {
      if (checkpoint.finished ||
          session.phase != LessonSectionPhase.exercise ||
          session.round < 2 ||
          session.position != 0 ||
          session.answered) {
        throw const FormatException('Latest review did not start a round.');
      }
    } else if (action case FinishSpellingRun(:final recordCompletion)) {
      if (!checkpoint.finished || session.phase != LessonSectionPhase.debrief) {
        throw const FormatException('Latest finish is not a finished debrief.');
      }
      if (checkpoint.mode == SpellingRunMode.reviewOnly && recordCompletion) {
        throw const FormatException(
          'Review-only finish cannot record completion.',
        );
      }
      if (recordCompletion &&
          (checkpoint.mode != SpellingRunMode.practice ||
              !session.canComplete ||
              checkpoint.firstAttemptAnswers.length != catalogue.rows.length ||
              !_hasCompletion(state, checkpoint))) {
        throw const FormatException('Eligible finish lacks completion proof.');
      }
    } else {
      throw const FormatException('Unknown spelling action.');
    }
  }

  static void _validateAttempts(
    SpellingLearningState state,
    FrenchUyDemoSpellingCatalogue catalogue,
    Map<String, _ReceiptProof> receipts,
  ) {
    final seen = <String>{};
    final retainedSummaryCounts = <SpellingSummaryKey, (int, int, int, int)>{};
    for (final attempt in state.attempts) {
      final rowMatches = catalogue.rows.where(
        (row) => row.exercise.id == attempt.itemId,
      );
      if (rowMatches.length != 1) {
        throw const FormatException('Attempt uses an unknown spelling item.');
      }
      final row = rowMatches.single;
      final playback = attempt.playback;
      if (attempt.scope != state.scope ||
          attempt.activityId != catalogue.activityId ||
          attempt.contentRevision != catalogue.contentRevision ||
          attempt.expectedOptionId != row.exercise.correctOptionId ||
          !row.exercise.options.any(
            (option) => option.id == attempt.selectedOptionId,
          ) ||
          attempt.correct !=
              (attempt.selectedOptionId == attempt.expectedOptionId) ||
          attempt.presentation !=
              (attempt.round == 1
                  ? AttemptPresentation.firstInRun
                  : AttemptPresentation.repeatInRun) ||
          attempt.afterDebrief != (attempt.round > 1) ||
          attempt.teachingExposed != attempt.afterDebrief ||
          attempt.audioSource != AttemptAudioSource.pendingRecording ||
          playback.profile != state.scope ||
          playback.activityId != attempt.activityId ||
          playback.contentRevision != attempt.contentRevision ||
          playback.runGeneration != attempt.generation ||
          playback.round != attempt.round ||
          playback.itemId != attempt.itemId ||
          playback.referenceId != row.exercise.audioRefId ||
          playback.outcome != CourseAudioOutcome.completed ||
          playback.source != CourseAudioSource.unverifiedRecording ||
          !attempt.committedAt.isUtc ||
          !seen.add(
            '${attempt.activityId}:${attempt.generation}:${attempt.sequence}',
          )) {
        throw const FormatException('Spelling attempt evidence is invalid.');
      }
      final receiptProof = _proofForSequence(
        receipts,
        attempt.activityId,
        attempt.generation,
        attempt.sequence,
      );
      if (receiptProof != null) {
        final action = receiptProof.command.action;
        if (action is! AnswerSpellingChoice ||
            action.itemId != attempt.itemId ||
            action.selectedOptionId != attempt.selectedOptionId ||
            action.expectedOptionIdSnapshot != attempt.expectedOptionId ||
            action.contentRevision != attempt.contentRevision ||
            receiptProof.command.token != attempt.attemptId ||
            receiptProof.receipt.after.generation != attempt.generation ||
            receiptProof.receipt.after.sequence != attempt.sequence ||
            !_samePlayback(action.playback, playback)) {
          throw const FormatException(
            'Attempt differs from its receipt proof.',
          );
        }
      }
      final summaryKey = SpellingSummaryKey(
        scope: state.scope,
        activityId: attempt.activityId,
        itemId: attempt.itemId,
        sound: row.exercise.targetSound,
        contentRevision: attempt.contentRevision,
      );
      final old = retainedSummaryCounts[summaryKey] ?? (0, 0, 0, 0);
      retainedSummaryCounts[summaryKey] = attempt.round == 1
          ? (old.$1 + 1, old.$2 + (attempt.correct ? 1 : 0), old.$3, old.$4)
          : (old.$1, old.$2, old.$3 + 1, old.$4 + (attempt.correct ? 1 : 0));
    }
    for (final entry in retainedSummaryCounts.entries) {
      final summary = state.summaries[entry.key];
      if (summary == null ||
          summary.firstInRun.total < entry.value.$1 ||
          summary.firstInRun.correct < entry.value.$2 ||
          summary.afterDebrief.total < entry.value.$3 ||
          summary.afterDebrief.correct < entry.value.$4) {
        throw const FormatException('Spelling summary undercounts attempts.');
      }
    }
  }

  static void _validateCurrentAnswers(
    SpellingLearningState state,
    SpellingSlot slot,
    LessonSectionSession session,
    Map<String, _ReceiptProof> receipts,
    List<String> ids,
  ) {
    final generation = slot.cursor.generation;
    final latest = <String, (int, bool)>{};
    final first = <String, bool>{};
    void record(int sequence, String itemId, bool correct, int round) {
      if (round == 1) {
        final priorFirst = first[itemId];
        if (priorFirst != null && priorFirst != correct) {
          throw const FormatException(
            'Conflicting first spelling answer proof.',
          );
        }
        first[itemId] = correct;
      }
      final old = latest[itemId];
      if (old == null || sequence > old.$1) {
        latest[itemId] = (sequence, correct);
      } else if (sequence == old.$1 && old.$2 != correct) {
        throw const FormatException(
          'Conflicting latest spelling answer proof.',
        );
      }
    }

    for (final proof in receipts.values) {
      if (proof.receipt.activityId != slot.activityId ||
          proof.receipt.after.generation != generation ||
          proof.command.action is! AnswerSpellingChoice) {
        continue;
      }
      final answer = proof.command.action as AnswerSpellingChoice;
      record(
        proof.receipt.after.sequence,
        answer.itemId,
        answer.selectedOptionId == answer.expectedOptionIdSnapshot,
        answer.playback.round,
      );
    }
    for (final attempt in state.attempts) {
      if (attempt.activityId == slot.activityId &&
          attempt.generation == generation) {
        record(
          attempt.sequence,
          attempt.itemId,
          attempt.correct,
          attempt.round,
        );
      }
    }
    for (final entry in latest.entries) {
      if (session.latestAnswers[entry.key] != entry.value.$2) {
        throw const FormatException(
          'Session answer differs from retained proof.',
        );
      }
    }
    final baseline = slot.checkpoint.baseline;
    if (baseline != null) {
      final sourceFirst = <String, bool>{};
      final sourceLatest = <String, (int, bool)>{};
      var sourceLatestRound = 0;
      final sourceStarts = receipts.values
          .where(
            (proof) =>
                proof.receipt.activityId == slot.activityId &&
                proof.receipt.after.generation == baseline.sourceGeneration &&
                proof.command.action is StartSpellingPractice,
          )
          .toList();
      if (sourceStarts.length > 1) {
        throw const FormatException(
          'Baseline source generation has duplicate starts.',
        );
      }
      if (sourceStarts.isNotEmpty) {
        final sourceStart =
            sourceStarts.single.command.action as StartSpellingPractice;
        if (sourceStart.sessionId != baseline.sourceSessionId ||
            sourceStart.policy.completionThresholdPercent !=
                baseline.policy.completionThresholdPercent) {
          throw const FormatException(
            'Baseline source identity differs from its retained start.',
          );
        }
      }
      for (final proof in receipts.values) {
        if (proof.receipt.activityId != slot.activityId ||
            proof.receipt.after.generation != baseline.sourceGeneration ||
            proof.command.action is! AnswerSpellingChoice) {
          continue;
        }
        final answer = proof.command.action as AnswerSpellingChoice;
        final correct =
            answer.selectedOptionId == answer.expectedOptionIdSnapshot;
        if (answer.playback.round > sourceLatestRound) {
          sourceLatestRound = answer.playback.round;
        }
        if (answer.playback.round == 1) sourceFirst[answer.itemId] = correct;
        final old = sourceLatest[answer.itemId];
        if (old == null || proof.receipt.after.sequence > old.$1) {
          sourceLatest[answer.itemId] = (proof.receipt.after.sequence, correct);
        }
      }
      for (final attempt in state.attempts) {
        if (attempt.activityId != slot.activityId ||
            attempt.generation != baseline.sourceGeneration) {
          continue;
        }
        if (attempt.round == 1) sourceFirst[attempt.itemId] = attempt.correct;
        if (attempt.round > sourceLatestRound) {
          sourceLatestRound = attempt.round;
        }
        final old = sourceLatest[attempt.itemId];
        if (old == null || attempt.sequence > old.$1) {
          sourceLatest[attempt.itemId] = (attempt.sequence, attempt.correct);
        }
      }
      for (final entry in sourceFirst.entries) {
        if (baseline.firstAttemptAnswers[entry.key] != entry.value) {
          throw const FormatException(
            'Baseline first score differs from evidence.',
          );
        }
      }
      for (final entry in sourceLatest.entries) {
        if (baseline.latestPracticeAnswers[entry.key] != entry.value.$2) {
          throw const FormatException(
            'Baseline latest score differs from evidence.',
          );
        }
      }
      if (sourceLatest.isNotEmpty &&
          sourceLatestRound != baseline.sourceRound) {
        throw const FormatException(
          'Baseline source round differs from retained answer evidence.',
        );
      }
    }
    final currentFirst = slot.checkpoint.firstAttemptAnswers;
    for (final entry in first.entries) {
      if (currentFirst[entry.key] != entry.value) {
        throw const FormatException(
          'First score differs from retained evidence.',
        );
      }
    }
    if (slot.checkpoint.mode == SpellingRunMode.practice &&
        session.round > 1 &&
        currentFirst.length != ids.length) {
      throw const FormatException(
        'Practice review lacks the full first score.',
      );
    }
  }

  static void _validateMistakes(
    SpellingLearningState state,
    FrenchUyDemoSpellingCatalogue catalogue,
  ) {
    for (final entry in state.mistakes.entries) {
      final key = entry.key;
      final mistake = entry.value;
      final rows = catalogue.rows.where((row) => row.exercise.id == key.itemId);
      if (key != mistake.key ||
          key.scope != state.scope ||
          key.activityId != catalogue.activityId ||
          key.contentRevision != catalogue.contentRevision ||
          rows.length != 1 ||
          rows.single.exercise.targetSound != key.targetSound ||
          mistake.failureCount < 1 ||
          !mistake.firstWrongAt.isUtc ||
          !mistake.latestWrongAt.isUtc ||
          mistake.latestWrongAt.isBefore(mistake.firstWrongAt)) {
        throw const FormatException('Spelling mistake identity is invalid.');
      }
    }
  }

  static void _validateSummaries(
    SpellingLearningState state,
    FrenchUyDemoSpellingCatalogue catalogue,
  ) {
    for (final entry in state.summaries.entries) {
      final key = entry.key;
      final summary = entry.value;
      final rows = catalogue.rows.where((row) => row.exercise.id == key.itemId);
      if (key != summary.key ||
          key.scope != state.scope ||
          key.activityId != catalogue.activityId ||
          key.contentRevision != catalogue.contentRevision ||
          rows.length != 1 ||
          rows.single.exercise.targetSound != key.sound) {
        throw const FormatException('Spelling summary identity is invalid.');
      }
      _validateCount(summary.firstInRun);
      _validateCount(summary.afterDebrief);
    }
  }

  static void _validateExposures(
    SpellingLearningState state,
    FrenchUyDemoSpellingCatalogue catalogue,
  ) {
    for (final entry in state.exposures.entries) {
      final key = entry.key;
      final exposure = entry.value;
      final rows = catalogue.rows.where((row) => row.exercise.id == key.itemId);
      if (key != exposure.key ||
          key.scope != state.scope ||
          key.activityId != catalogue.activityId ||
          key.contentRevision != catalogue.contentRevision ||
          rows.length != 1 ||
          rows.single.exercise.targetSound != key.targetSound ||
          exposure.presentations < 0 ||
          exposure.assistanceMask < 0 ||
          exposure.assistanceMask > 15) {
        throw const FormatException('Spelling exposure identity is invalid.');
      }
    }
    for (final attempt in state.attempts) {
      final row = catalogue.rows.singleWhere(
        (candidate) => candidate.exercise.id == attempt.itemId,
      );
      final key = SpellingExposureKey(
        scope: state.scope,
        activityId: attempt.activityId,
        itemId: attempt.itemId,
        targetSound: row.exercise.targetSound,
        contentRevision: attempt.contentRevision,
      );
      final exposure = state.exposures[key];
      if (exposure == null ||
          exposure.presentations <
              state.attempts
                  .where(
                    (other) =>
                        other.activityId == attempt.activityId &&
                        other.itemId == attempt.itemId &&
                        other.contentRevision == attempt.contentRevision,
                  )
                  .length ||
          attempt.teachingExposed && (exposure.assistanceMask & 13) != 13) {
        throw const FormatException('Attempt lacks its spelling exposure.');
      }
    }
  }

  static void _validateCompletions(
    SpellingLearningState state,
    FrenchUyDemoSpellingCatalogue catalogue,
  ) {
    final identities = <String>{};
    for (final completion in state.completions) {
      final identity =
          '${completion.activityId}:${completion.contentRevision}:'
          '${completion.policyKind.name}:${completion.policyRevision}:'
          '${completion.thresholdPercent}';
      if (completion.scope != state.scope ||
          completion.activityId != catalogue.activityId ||
          completion.contentRevision != catalogue.contentRevision ||
          completion.policyKind != CompletionPolicyKind.discoveryThreshold ||
          completion.policyRevision != 1 ||
          completion.thresholdPercent != 80 ||
          !completion.committedAt.isUtc ||
          !identities.add(identity)) {
        throw const FormatException('Spelling completion is invalid.');
      }
    }
  }

  static bool _hasCompletion(
    SpellingLearningState state,
    SpellingCheckpoint checkpoint,
  ) => state.completions.any(
    (completion) =>
        completion.activityId == 'en-fr-u-y-spelling' &&
        completion.contentRevision == checkpoint.contentRevision &&
        completion.policyKind == CompletionPolicyKind.discoveryThreshold &&
        completion.policyRevision == 1 &&
        completion.thresholdPercent ==
            checkpoint.policy.completionThresholdPercent,
  );

  static LessonSectionSession _session(
    SpellingCheckpoint checkpoint,
    List<String> ids,
  ) => LessonSectionSession.fromJson(
    Map<String, dynamic>.from(checkpoint.sessionJson),
    itemIds: ids,
    contentRevision: checkpoint.contentRevision,
  );

  static bool _reachableCursor(
    SpellingAction action,
    SpellingCursor before,
    SpellingCursor after,
  ) {
    if (action is StartSpellingPractice || action is StartSpellingReviewOnly) {
      if (before.generation == 0) {
        return before.sequence == 0 &&
            before.revision == 0 &&
            after.generation == 1 &&
            after.sequence == 1 &&
            after.revision == 0;
      }
      return before.generation < spellingMaxSafeInteger &&
          before.sequence < spellingMaxSafeInteger &&
          after.generation == before.generation + 1 &&
          after.sequence == before.sequence + 1 &&
          after.revision == 0;
    }
    return before.generation > 0 &&
        before.sequence < spellingMaxSafeInteger &&
        before.revision < spellingMaxSafeInteger &&
        after.generation == before.generation &&
        after.sequence == before.sequence + 1 &&
        after.revision == before.revision + 1;
  }

  static String _cursorKey(String activityId, SpellingCursor cursor) =>
      '$activityId:${cursor.generation}:${cursor.sequence}';

  static _ReceiptProof? _proofForSequence(
    Map<String, _ReceiptProof> receipts,
    String activityId,
    int generation,
    int sequence,
  ) => receipts['$activityId:$generation:$sequence'];

  static bool _sameReceipt(SpellingReceipt left, SpellingReceipt right) =>
      left.scope == right.scope &&
      left.activityId == right.activityId &&
      left.generation == right.generation &&
      left.sequence == right.sequence &&
      left.token == right.token &&
      left.canonicalCommand == right.canonicalCommand &&
      left.before == right.before &&
      left.after == right.after &&
      left.commitOrdinal == right.commitOrdinal;

  static bool _samePlayback(
    SpellingPlaybackObservation left,
    SpellingPlaybackObservation right,
  ) =>
      left.profile == right.profile &&
      left.authGeneration == right.authGeneration &&
      left.activityId == right.activityId &&
      left.contentRevision == right.contentRevision &&
      left.runGeneration == right.runGeneration &&
      left.round == right.round &&
      left.itemId == right.itemId &&
      left.referenceId == right.referenceId &&
      left.promptEpoch == right.promptEpoch &&
      left.outcome == right.outcome &&
      left.source == right.source;

  static void _validateCount(SpellingCount count) {
    if (count.correct < 0 ||
        count.total < 0 ||
        count.correct > count.total ||
        count.correct > spellingMaxSafeInteger ||
        count.total > spellingMaxSafeInteger) {
      throw const FormatException('Invalid spelling summary count.');
    }
  }
}

final class _ReceiptProof {
  const _ReceiptProof(this.receipt, this.command);

  final SpellingReceipt receipt;
  final SpellingLearningCommand command;
}
