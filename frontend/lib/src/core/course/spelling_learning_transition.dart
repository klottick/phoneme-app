import 'dart:convert';

import 'course_attempt.dart';
import 'course_audio_contract.dart';
import 'french_uy_demo_spelling_content.dart';
import 'lesson_section_session.dart';
import 'spelling_learning_command.dart';
import 'spelling_learning_state.dart';
import 'storage/spelling_learning_command_codec.dart';
import 'spelling_learning_validator.dart';

final class SpellingLearningTransition {
  SpellingLearningTransition({
    required this.nextState,
    required this.slot,
    required List<SpellingAttempt> attempts,
    required this.duplicate,
  }) : attempts = List<SpellingAttempt>.unmodifiable(attempts);

  final SpellingLearningState nextState;
  final SpellingSlot slot;
  final List<SpellingAttempt> attempts;
  final bool duplicate;
}

final class SpellingLearningTransitionEngine {
  SpellingLearningTransitionEngine({required this.catalogue}) {
    validateFrenchUyDemoSpellingCatalogue(catalogue);
    if (catalogue.activityId != 'en-fr-u-y-spelling' ||
        catalogue.contentRevision != 1) {
      throw ArgumentError('Unsupported spelling catalogue identity.');
    }
  }

  final FrenchUyDemoSpellingCatalogue catalogue;

  SpellingLearningCommand prepare({
    required SpellingLearningState state,
    required SpellingAction action,
    required int authGeneration,
    required String token,
    required DateTime submittedAt,
  }) {
    final slot = state.slots[catalogue.activityId];
    final command = SpellingLearningCommand(
      scope: state.scope,
      authGeneration: authGeneration,
      activityId: catalogue.activityId,
      expected:
          slot?.cursor ??
          SpellingCursor(generation: 0, sequence: 0, revision: 0),
      expectedScopeRevision: state.revision,
      token: token,
      submittedAt: submittedAt,
      action: action,
    );
    evaluate(state: state, command: command, committedAt: submittedAt);
    return command;
  }

  SpellingLearningTransition evaluate({
    required SpellingLearningState state,
    required SpellingLearningCommand command,
    required DateTime committedAt,
  }) {
    SpellingLearningStateValidator.validate(state, catalogue);
    final canonicalCommand = const SpellingLearningCommandCodec().encode(
      command,
    );
    if (!committedAt.isUtc ||
        command.scope != state.scope ||
        command.activityId != catalogue.activityId) {
      throw ArgumentError('Stale spelling command.');
    }

    final sameToken = state.receipts.where(
      (receipt) => receipt.token == command.token,
    );
    if (sameToken.isNotEmpty) {
      final receipt = sameToken.single;
      if (receipt.canonicalCommand != canonicalCommand) {
        throw ArgumentError('Spelling token was reused for another command.');
      }
      final slot = state.slots[catalogue.activityId];
      if (slot == null) {
        throw StateError('Duplicate command has no spelling slot.');
      }
      return SpellingLearningTransition(
        nextState: state,
        slot: slot,
        attempts: const <SpellingAttempt>[],
        duplicate: true,
      );
    }

    if (command.expectedScopeRevision != state.revision) {
      throw ArgumentError('Stale spelling scope revision.');
    }
    final beforeSlot = state.slots[catalogue.activityId];
    final before =
        beforeSlot?.cursor ??
        SpellingCursor(generation: 0, sequence: 0, revision: 0);
    if (command.expected != before) {
      throw ArgumentError('Stale spelling cursor.');
    }
    if (command.action is! StartSpellingPractice && beforeSlot == null) {
      throw StateError('Spelling practice has not started.');
    }
    if (beforeSlot?.checkpoint.finished == true &&
        command.action is! StartSpellingPractice &&
        command.action is! StartSpellingReviewOnly) {
      throw StateError('Finished spelling run requires an explicit new start.');
    }

    final itemIds = catalogue.rows.map((row) => row.exercise.id).toList();
    final List<SpellingAttempt> emittedAttempts = <SpellingAttempt>[];
    final mistakes = Map<SpellingMistakeKey, SpellingMistake>.of(
      state.mistakes,
    );
    final summaries = Map<SpellingSummaryKey, SpellingSummary>.of(
      state.summaries,
    );
    final exposures = Map<SpellingExposureKey, SpellingExposure>.of(
      state.exposures,
    );
    final completions = List<SpellingCompletion>.of(state.completions);
    final bool startsGeneration =
        command.action is StartSpellingPractice ||
        command.action is StartSpellingReviewOnly;
    final generation = startsGeneration
        ? before.generation + 1
        : before.generation;
    final sequence = before.sequence + 1;
    final SpellingCheckpoint checkpoint;
    final LessonSectionSession session;

    if (command.action case StartSpellingPractice(
      :final sessionId,
      :final policy,
    )) {
      if (policy.completionThresholdPercent != 80) {
        throw ArgumentError('Spelling practice requires the saved 80% policy.');
      }
      session = LessonSectionSession(
        itemIds: itemIds,
        sessionId: sessionId,
        contentRevision: catalogue.contentRevision,
        policy: policy,
      );
      checkpoint = SpellingCheckpoint(
        scope: state.scope,
        sessionId: sessionId,
        contentRevision: catalogue.contentRevision,
        policy: policy,
        mode: SpellingRunMode.practice,
        runStartRound: 1,
        finished: false,
        sessionJson: session.toJson().cast<String, Object?>(),
        firstAttemptAnswers: const <String, bool>{},
      );
    } else if (command.action case StartSpellingReviewOnly(:final sessionId)) {
      final sourceSlot = beforeSlot;
      if (sourceSlot == null) {
        throw StateError('There is no practice run to review.');
      }
      final source = sourceSlot.checkpoint;
      final sourceSession = _session(source);
      if (source.mode != SpellingRunMode.practice ||
          sourceSession.phase != LessonSectionPhase.debrief ||
          sourceSession.latestAnswers.length != itemIds.length ||
          source.firstAttemptAnswers.length != itemIds.length ||
          sourceSession.unresolvedItemIds.isEmpty) {
        throw StateError(
          'Review-only requires a complete practice debrief with misses.',
        );
      }
      final copied = Map<String, Object?>.of(source.sessionJson)
        ..['sessionId'] = sessionId;
      session = LessonSectionSession.fromJson(
        Map<String, dynamic>.from(copied),
        itemIds: itemIds,
        contentRevision: source.contentRevision,
      );
      final sourceRound = session.round;
      final expectedQueue = itemIds
          .where((id) => sourceSession.latestAnswers[id] == false)
          .toList();
      session.reviewMistakes();
      if (session.round != sourceRound + 1 ||
          session.round < 2 ||
          jsonEncode(session.queue) != jsonEncode(expectedQueue)) {
        throw StateError(
          'Review-only mistake queue differs from source debrief.',
        );
      }
      final baseline = SpellingPracticeBaseline(
        sourceGeneration: sourceSlot.cursor.generation,
        sourceSessionId: source.sessionId,
        sourceContentRevision: source.contentRevision,
        sourceRound: sourceRound,
        firstAttemptAnswers: source.firstAttemptAnswers,
        latestPracticeAnswers: sourceSession.latestAnswers,
        policy: source.policy,
      );
      checkpoint = SpellingCheckpoint(
        scope: state.scope,
        sessionId: sessionId,
        contentRevision: source.contentRevision,
        policy: source.policy,
        mode: SpellingRunMode.reviewOnly,
        runStartRound: sourceRound + 1,
        finished: false,
        sessionJson: session.toJson().cast<String, Object?>(),
        firstAttemptAnswers: source.firstAttemptAnswers,
        baseline: baseline,
      );
    } else {
      final currentSlot = beforeSlot!;
      final old = currentSlot.checkpoint;
      if (old.finished) {
        throw StateError('Finished spelling run is immutable.');
      }
      session = _session(old);
      if (command.action case final AnswerSpellingChoice answer) {
        _validatePlayback(command, answer, session, generation);
        final currentId = session.currentItemId;
        if (currentId != answer.itemId || session.answered) {
          throw StateError('Current spelling prompt is not answerable.');
        }
        final row = catalogue.rows.singleWhere(
          (candidate) => candidate.exercise.id == currentId,
        );
        if (answer.contentRevision != catalogue.contentRevision ||
            answer.expectedOptionIdSnapshot != row.exercise.correctOptionId ||
            !row.exercise.options.any(
              (option) => option.id == answer.selectedOptionId,
            )) {
          throw ArgumentError(
            'Spelling answer does not match authored content.',
          );
        }
        final correct =
            answer.selectedOptionId == answer.expectedOptionIdSnapshot;
        final isRepeat = session.latestAnswers.containsKey(currentId);
        session.submit(correct);
        final firstAnswers = Map<String, bool>.of(old.firstAttemptAnswers);
        if (old.mode == SpellingRunMode.practice && session.round == 1) {
          final submitted = _submittedThisRound(session);
          for (final id in itemIds) {
            if (submitted.contains(id)) {
              firstAnswers[id] = session.latestAnswers[id]!;
            }
          }
        }
        final first = firstAnswers;
        final afterDebrief = session.round > 1;
        final attempt = SpellingAttempt(
          scope: state.scope,
          attemptId: command.token,
          activityId: command.activityId,
          generation: generation,
          sequence: sequence,
          itemId: currentId!,
          round: session.round,
          contentRevision: catalogue.contentRevision,
          selectedOptionId: answer.selectedOptionId,
          expectedOptionId: row.exercise.correctOptionId,
          correct: correct,
          presentation: isRepeat
              ? AttemptPresentation.repeatInRun
              : AttemptPresentation.firstInRun,
          afterDebrief: afterDebrief,
          teachingExposed: afterDebrief,
          audioSource: AttemptAudioSource.pendingRecording,
          playback: answer.playback,
          committedAt: committedAt,
        );
        emittedAttempts.add(attempt);

        final mistakeKey = SpellingMistakeKey(
          scope: state.scope,
          activityId: command.activityId,
          itemId: currentId,
          targetSound: row.exercise.targetSound,
          contentRevision: catalogue.contentRevision,
        );
        if (correct) {
          mistakes.remove(mistakeKey);
        } else {
          final previous = mistakes[mistakeKey];
          mistakes[mistakeKey] = SpellingMistake(
            key: mistakeKey,
            firstWrongAt: previous?.firstWrongAt ?? command.submittedAt,
            latestWrongAt: command.submittedAt,
            failureCount: (previous?.failureCount ?? 0) + 1,
          );
        }

        final summaryKey = SpellingSummaryKey(
          scope: state.scope,
          activityId: command.activityId,
          itemId: currentId,
          sound: row.exercise.targetSound,
          contentRevision: catalogue.contentRevision,
        );
        final oldSummary = summaries[summaryKey];
        final firstCount =
            oldSummary?.firstInRun ?? SpellingCount(correct: 0, total: 0);
        final afterCount =
            oldSummary?.afterDebrief ?? SpellingCount(correct: 0, total: 0);
        summaries[summaryKey] = SpellingSummary(
          key: summaryKey,
          firstInRun: session.round == 1
              ? SpellingCount(
                  correct: firstCount.correct + (correct ? 1 : 0),
                  total: firstCount.total + 1,
                )
              : firstCount,
          afterDebrief: session.round > 1
              ? SpellingCount(
                  correct: afterCount.correct + (correct ? 1 : 0),
                  total: afterCount.total + 1,
                )
              : afterCount,
        );

        final exposureKey = SpellingExposureKey(
          scope: state.scope,
          activityId: command.activityId,
          itemId: currentId,
          targetSound: row.exercise.targetSound,
          contentRevision: catalogue.contentRevision,
        );
        final previousExposure = exposures[exposureKey];
        final assistance = afterDebrief
            ? (1 << AssistanceFlag.explanationVisible.index) |
                  (1 << AssistanceFlag.afterDebrief.index) |
                  (1 << AssistanceFlag.answerRevealed.index)
            : 0;
        exposures[exposureKey] = SpellingExposure(
          key: exposureKey,
          presentations: (previousExposure?.presentations ?? 0) + 1,
          assistanceMask: (previousExposure?.assistanceMask ?? 0) | assistance,
        );
        checkpoint = SpellingCheckpoint(
          scope: state.scope,
          sessionId: old.sessionId,
          contentRevision: old.contentRevision,
          policy: old.policy,
          mode: old.mode,
          runStartRound: old.runStartRound,
          finished: false,
          sessionJson: session.toJson().cast<String, Object?>(),
          firstAttemptAnswers: first,
          baseline: old.baseline,
        );
      } else if (command.action is AdvanceSpellingItem) {
        session.advance();
        checkpoint = _copyCheckpoint(old, session, finished: false);
      } else if (command.action is ReviewSpellingMistakes) {
        session.reviewMistakes();
        checkpoint = _copyCheckpoint(old, session, finished: false);
      } else if (command.action case FinishSpellingRun(
        :final recordCompletion,
      )) {
        if (session.phase != LessonSectionPhase.debrief) {
          throw StateError('Spelling Finish requires debrief.');
        }
        if (recordCompletion &&
            (old.mode != SpellingRunMode.practice ||
                !session.canComplete ||
                old.firstAttemptAnswers.length != itemIds.length)) {
          throw StateError(
            'Spelling practice does not qualify for completion.',
          );
        }
        if (old.mode == SpellingRunMode.reviewOnly && recordCompletion) {
          throw StateError('Review-only Finish cannot record completion.');
        }
        if (recordCompletion &&
            !_containsCompletion(completions, old, command.activityId)) {
          completions.add(
            SpellingCompletion(
              scope: state.scope,
              activityId: command.activityId,
              contentRevision: old.contentRevision,
              policyKind: CompletionPolicyKind.discoveryThreshold,
              policyRevision: 1,
              thresholdPercent: old.policy.completionThresholdPercent,
              committedAt: committedAt,
            ),
          );
        }
        checkpoint = _copyCheckpoint(old, session, finished: true);
      } else {
        throw StateError('Unsupported spelling action.');
      }
    }

    final cursor = startsGeneration
        ? SpellingCursor(
            generation: generation,
            sequence: sequence,
            revision: 0,
          )
        : SpellingCursor(
            generation: generation,
            sequence: sequence,
            revision: before.revision + 1,
          );
    final ordinal = state.commitOrdinal + 1;
    final receipt = SpellingReceipt(
      scope: state.scope,
      activityId: command.activityId,
      generation: cursor.generation,
      sequence: cursor.sequence,
      token: command.token,
      canonicalCommand: canonicalCommand,
      before: before,
      after: cursor,
      commitOrdinal: ordinal,
    );
    final slot = SpellingSlot(
      scope: state.scope,
      activityId: command.activityId,
      cursor: cursor,
      checkpoint: checkpoint,
      latestReceipt: receipt,
    );
    final slots = Map<String, SpellingSlot>.of(state.slots)
      ..[command.activityId] = slot;
    final retainedAttempts = <SpellingAttempt>[
      ...state.attempts,
      ...emittedAttempts,
    ];
    final retainedReceipts = <SpellingReceipt>[...state.receipts, receipt];
    final nextState = SpellingLearningState(
      scope: state.scope,
      revision: state.revision + 1,
      commitOrdinal: ordinal,
      slots: slots,
      attempts: retainedAttempts
          .skip(
            retainedAttempts.length > spellingMaxRetainedAttempts
                ? retainedAttempts.length - spellingMaxRetainedAttempts
                : 0,
          )
          .toList(),
      receipts: retainedReceipts
          .skip(
            retainedReceipts.length > spellingMaxRetainedReceipts
                ? retainedReceipts.length - spellingMaxRetainedReceipts
                : 0,
          )
          .toList(),
      mistakes: mistakes,
      summaries: summaries,
      exposures: exposures,
      completions: completions,
    );
    SpellingLearningStateValidator.validate(nextState, catalogue);
    return SpellingLearningTransition(
      nextState: nextState,
      slot: slot,
      attempts: emittedAttempts,
      duplicate: false,
    );
  }

  void _validatePlayback(
    SpellingLearningCommand command,
    AnswerSpellingChoice answer,
    LessonSectionSession session,
    int generation,
  ) {
    final row = catalogue.rows.singleWhere(
      (candidate) => candidate.exercise.id == answer.itemId,
    );
    final playback = answer.playback;
    if (answer.contentRevision != catalogue.contentRevision ||
        playback.profile != command.scope ||
        playback.authGeneration != command.authGeneration ||
        playback.activityId != catalogue.activityId ||
        playback.contentRevision != catalogue.contentRevision ||
        playback.runGeneration != generation ||
        playback.round != session.round ||
        playback.itemId != answer.itemId ||
        playback.referenceId != row.exercise.audioRefId ||
        playback.promptEpoch < 0 ||
        playback.outcome != CourseAudioOutcome.completed ||
        playback.source != CourseAudioSource.unverifiedRecording) {
      throw ArgumentError('Spelling playback provenance is stale or invalid.');
    }
  }

  LessonSectionSession _session(SpellingCheckpoint checkpoint) =>
      LessonSectionSession.fromJson(
        Map<String, dynamic>.from(checkpoint.sessionJson),
        itemIds: catalogue.rows.map((row) => row.exercise.id).toList(),
        contentRevision: checkpoint.contentRevision,
      );

  SpellingCheckpoint _copyCheckpoint(
    SpellingCheckpoint old,
    LessonSectionSession session, {
    required bool finished,
  }) => SpellingCheckpoint(
    scope: old.scope,
    sessionId: old.sessionId,
    contentRevision: old.contentRevision,
    policy: old.policy,
    mode: old.mode,
    runStartRound: old.runStartRound,
    finished: finished,
    sessionJson: session.toJson().cast<String, Object?>(),
    firstAttemptAnswers: old.firstAttemptAnswers,
    baseline: old.baseline,
  );

  bool _containsCompletion(
    List<SpellingCompletion> completions,
    SpellingCheckpoint checkpoint,
    String activityId,
  ) => completions.any(
    (completion) =>
        completion.activityId == activityId &&
        completion.contentRevision == checkpoint.contentRevision &&
        completion.policyKind == CompletionPolicyKind.discoveryThreshold &&
        completion.policyRevision == 1 &&
        completion.thresholdPercent ==
            checkpoint.policy.completionThresholdPercent,
  );
}

List<String> _submittedThisRound(LessonSectionSession session) =>
    List<String>.from(session.toJson()['submittedThisRound'] as List);
