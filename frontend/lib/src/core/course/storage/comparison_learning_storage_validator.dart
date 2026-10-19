import 'dart:convert';

import '../comparison_content.dart';
import '../comparison_learning_command.dart' as domain;
import '../comparison_learning_state.dart';
import '../course_audio_contract.dart';
import '../lesson_section_session.dart';
import 'comparison_learning_checkpoint_codec.dart';
import 'comparison_learning_command_codec.dart';

/// Validates comparison state assembled from normalized SQLite rows.
///
/// The validator checks one current checkpoint at a time and never round-trips
/// the whole learner document. Attempts and aggregates are validated directly
/// from their typed rows and are not derived from one another after pruning.
final class ComparisonLearningStateValidator {
  const ComparisonLearningStateValidator._();

  static const int _maxAggregateIdentities = 4096;
  static const int _maxRetainedAttempts = 2000;
  static const int _maxRetainedReceipts = 2000;

  static void validate(
    ComparisonLearningState state,
    ComparisonCatalogue catalogue,
  ) {
    try {
      _validate(state, catalogue);
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid comparison learning state: $error');
    }
  }

  static void _validate(
    ComparisonLearningState state,
    ComparisonCatalogue catalogue,
  ) {
    if (state.schemaVersion != 1 ||
        catalogue.activityId != comparisonActivityId ||
        catalogue.contentRevision < 1 ||
        state.revision < 0 ||
        state.revision > comparisonMaxSafeInteger ||
        state.commitOrdinal < 0 ||
        state.commitOrdinal > state.revision ||
        state.attempts.length > _maxRetainedAttempts ||
        state.receipts.length > _maxRetainedReceipts ||
        state.mistakes.length > _maxAggregateIdentities ||
        state.summaries.length > _maxAggregateIdentities ||
        state.completions.length > _maxAggregateIdentities) {
      throw const FormatException(
        'Comparison state exceeds its supported bounds.',
      );
    }

    for (final entry in state.mistakes.entries) {
      final key = entry.key;
      final mistake = entry.value;
      _requireContent(
        key.activityId,
        key.pairId,
        key.contentRevision,
        catalogue,
      );
      if (key != mistake.key ||
          key.scope != state.scope ||
          mistake.scope != state.scope ||
          mistake.failureCount < 1 ||
          !mistake.firstWrongAt.isUtc ||
          !mistake.latestWrongAt.isUtc ||
          mistake.latestWrongAt.isBefore(mistake.firstWrongAt)) {
        throw const FormatException('Invalid comparison mistake identity.');
      }
    }

    for (final entry in state.summaries.entries) {
      final key = entry.key;
      final summary = entry.value;
      _requireContent(
        key.activityId,
        key.pairId,
        key.contentRevision,
        catalogue,
      );
      if (entry.key != summary.key || key.scope != state.scope) {
        throw const FormatException('Invalid comparison summary identity.');
      }
      _validateCount(summary.firstInRun);
      _validateCount(summary.repeatInRun);
      _validateCount(summary.afterDebrief);
      if (summary.afterDebrief.total >
              summary.firstInRun.total + summary.repeatInRun.total ||
          summary.afterDebrief.correct >
              summary.firstInRun.correct + summary.repeatInRun.correct ||
          summary.afterDebrief.total - summary.afterDebrief.correct >
              summary.firstInRun.total -
                  summary.firstInRun.correct +
                  summary.repeatInRun.total -
                  summary.repeatInRun.correct) {
        throw const FormatException('Invalid after-debrief summary subset.');
      }
    }

    final receiptsBySequence = <String, ComparisonReceipt>{};
    final receiptTokens = <String>{};
    final receiptCursors = <String>{};
    for (var index = 0; index < state.receipts.length; index++) {
      final receipt = state.receipts[index];
      final command = _decodeDomainReceipt(receipt, state.scope, catalogue);
      if (receipt.scope != state.scope ||
          receipt.activityId != catalogue.activityId ||
          receipt.commitOrdinal > state.commitOrdinal ||
          !receiptTokens.add(receipt.token) ||
          !receiptCursors.add(_cursorKey(receipt.activityId, receipt.after)) ||
          command.token != receipt.token ||
          command.activityId != receipt.activityId ||
          command.expected != receipt.before) {
        throw const FormatException('Invalid comparison receipt identity.');
      }
      _validateReceiptAction(command, receipt, catalogue);
      if (index > 0) {
        final previous = state.receipts[index - 1];
        if (receipt.commitOrdinal != previous.commitOrdinal + 1 ||
            receipt.before != previous.after) {
          throw const FormatException(
            'Retained receipt chain is inconsistent.',
          );
        }
      }
      receiptsBySequence[_cursorKey(receipt.activityId, receipt.after)] =
          receipt;
    }

    final attemptIdentities = <String>{};
    final retainedCounts = <ComparisonSummaryKey, List<int>>{};
    for (final attempt in state.attempts) {
      _requireContent(
        attempt.activityId,
        attempt.pairId,
        attempt.contentRevision,
        catalogue,
      );
      final exercise = catalogue.exercise(attempt.pairId);
      final identity = _cursorKey(
        attempt.activityId,
        ComparisonCursor(
          generation: attempt.runGeneration,
          sequence: attempt.sequence,
          revision: 0,
        ),
      );
      if (attempt.scope != state.scope ||
          attempt.contentRevision != catalogue.contentRevision ||
          attempt.runGeneration < 1 ||
          attempt.sequence < 1 ||
          attempt.round < 1 ||
          !attemptIdentities.add(identity) ||
          attempt.expectedRelation != exercise.expectedRelation ||
          attempt.correct !=
              (attempt.selectedRelation == exercise.expectedRelation) ||
          attempt.observations.length != 2 ||
          !_validObservation(
            attempt.observations[0],
            state.scope,
            exercise.sampleA,
            attempt,
            ComparisonSample.a,
          ) ||
          !_validObservation(
            attempt.observations[1],
            state.scope,
            exercise.sampleB,
            attempt,
            ComparisonSample.b,
          ) ||
          attempt.observations[0].uiGeneration !=
              attempt.observations[1].uiGeneration ||
          !attempt.answeredAt.isUtc ||
          !attempt.committedAt.isUtc ||
          attempt.committedAt.isBefore(attempt.answeredAt) ||
          (attempt.round == 1 &&
              (attempt.presentation != AttemptPresentation.firstInRun ||
                  attempt.afterDebrief)) ||
          (attempt.round > 1 &&
              (attempt.presentation != AttemptPresentation.repeatInRun ||
                  !attempt.afterDebrief))) {
        throw const FormatException(
          'Comparison attempt content/evidence mismatch.',
        );
      }
      final receipt = receiptsBySequence[identity];
      if (receipt != null) {
        final command = _decodeDomainReceipt(receipt, state.scope, catalogue);
        if (command.action is! domain.AnswerComparisonPair) {
          throw const FormatException('Attempt links to a non-answer receipt.');
        }
        final answer = (command.action as domain.AnswerComparisonPair).answer;
        if (receipt.commitOrdinal != attempt.sequence &&
            receipt.commitOrdinal < attempt.sequence) {
          throw const FormatException('Attempt/receipt ordinal mismatch.');
        }
        if (receipt.after.generation != attempt.runGeneration ||
            receipt.after.sequence != attempt.sequence ||
            command.submittedAt != attempt.answeredAt ||
            answer.selectedRelation != attempt.selectedRelation ||
            answer.expectedRelationSnapshot != attempt.expectedRelation ||
            !_sameObservations(answer.observations, attempt.observations)) {
          throw const FormatException('Attempt/receipt link mismatch.');
        }
      }
      final key = ComparisonSummaryKey(
        scope: state.scope,
        activityId: attempt.activityId,
        pairId: attempt.pairId,
        contentRevision: attempt.contentRevision,
      );
      final counts = retainedCounts.putIfAbsent(
        key,
        () => List<int>.filled(6, 0),
      );
      final first = attempt.presentation == AttemptPresentation.firstInRun;
      counts[first ? 0 : 2]++;
      if (attempt.correct) counts[first ? 1 : 3]++;
      if (attempt.afterDebrief) {
        counts[4]++;
        if (attempt.correct) counts[5]++;
      }
    }

    for (final entry in retainedCounts.entries) {
      final summary = state.summaries[entry.key];
      final counts = entry.value;
      if (summary == null ||
          summary.firstInRun.total < counts[0] ||
          summary.firstInRun.correct < counts[1] ||
          summary.firstInRun.total - summary.firstInRun.correct <
              counts[0] - counts[1] ||
          summary.repeatInRun.total < counts[2] ||
          summary.repeatInRun.correct < counts[3] ||
          summary.repeatInRun.total - summary.repeatInRun.correct <
              counts[2] - counts[3] ||
          summary.afterDebrief.total < counts[4] ||
          summary.afterDebrief.correct < counts[5] ||
          summary.afterDebrief.total - summary.afterDebrief.correct <
              counts[4] - counts[5]) {
        throw const FormatException('Summary undercounts retained attempts.');
      }
    }

    final completionIdentities = <String>{};
    for (final completion in state.completions) {
      final identity = jsonEncode([
        completion.activityId,
        completion.contentRevision,
        completion.policyRevision,
        completion.thresholdPercent,
      ]);
      if (completion.scope != state.scope ||
          completion.activityId != catalogue.activityId ||
          completion.contentRevision != catalogue.contentRevision ||
          completion.policyRevision != 1 ||
          completion.thresholdPercent < 1 ||
          completion.thresholdPercent > 100 ||
          !completion.committedAt.isUtc ||
          !completionIdentities.add(identity)) {
        throw const FormatException('Invalid comparison completion identity.');
      }
    }

    final slot = state.slot;
    if (slot == null) {
      if (state.commitOrdinal != 0 ||
          state.revision != 0 ||
          state.attempts.isNotEmpty ||
          state.receipts.isNotEmpty ||
          state.mistakes.isNotEmpty ||
          state.summaries.isNotEmpty ||
          state.completions.isNotEmpty) {
        throw const FormatException(
          'Slotless comparison state has durable data.',
        );
      }
      return;
    }

    if (slot.scope != state.scope ||
        slot.activityId != catalogue.activityId ||
        slot.checkpoint.scope != state.scope ||
        slot.checkpoint.contentRevision != catalogue.contentRevision ||
        slot.latestReceipt.commitOrdinal != state.commitOrdinal ||
        slot.latestReceipt.after != slot.cursor) {
      throw const FormatException('Comparison slot identity mismatch.');
    }
    const checkpointCodec = ComparisonLearningCheckpointCodec();
    final checkpointJson = checkpointCodec.encode(slot.checkpoint);
    final checkpoint = checkpointCodec.decode(
      checkpointJson,
      scope: state.scope,
      activityId: slot.activityId,
      catalogue: catalogue,
      policy: slot.checkpoint.policy,
    );
    final session = _session(checkpoint.sessionJson, catalogue);
    final latest = slot.latestReceipt;
    final latestCommand = _decodeDomainReceipt(latest, state.scope, catalogue);
    if (latestCommand.token != latest.token ||
        latestCommand.activityId != latest.activityId ||
        latestCommand.expected != latest.before ||
        latest.after != slot.cursor) {
      throw const FormatException('Latest comparison receipt mismatch.');
    }
    _validateReceiptAction(latestCommand, latest, catalogue);
    if (state.receipts.isNotEmpty &&
        !_sameReceipt(state.receipts.last, latest)) {
      throw const FormatException('Latest receipt differs from retained tail.');
    }

    if (latestCommand.action case domain.StartComparisonRun(
      :final sessionId,
      :final policy,
    )) {
      final fresh = LessonSectionSession(
        itemIds: catalogue.exercises.map((exercise) => exercise.id).toList(),
        sessionId: sessionId,
        contentRevision: catalogue.contentRevision,
        policy: slot.checkpoint.policy,
      );
      if (slot.checkpoint.sessionId != sessionId ||
          slot.checkpoint.policy.completionThresholdPercent !=
              policy.completionThresholdPercent ||
          jsonEncode(session.toJson()) != jsonEncode(fresh.toJson())) {
        throw const FormatException('Latest start is not a fresh checkpoint.');
      }
    } else if (latestCommand.action case domain.AnswerComparisonPair(
      :final answer,
    )) {
      final pairId = answer.observations.first.pairId;
      final retainedAttempt = state.attempts.where(
        (attempt) =>
            attempt.activityId == slot.activityId &&
            attempt.runGeneration == latest.after.generation &&
            attempt.sequence == latest.after.sequence,
      );
      final expectedCorrect =
          answer.selectedRelation == answer.expectedRelationSnapshot;
      if (!session.answered ||
          session.currentItemId != pairId ||
          answer.observations.first.round != session.round ||
          session.lastCorrect != expectedCorrect ||
          session.latestAnswers[pairId] != expectedCorrect ||
          (retainedAttempt.isNotEmpty &&
              (retainedAttempt.length != 1 ||
                  retainedAttempt.single.pairId != pairId ||
                  retainedAttempt.single.round != session.round ||
                  retainedAttempt.single.selectedRelation !=
                      answer.selectedRelation ||
                  retainedAttempt.single.expectedRelation !=
                      answer.expectedRelationSnapshot ||
                  retainedAttempt.single.correct != expectedCorrect ||
                  retainedAttempt.single.answeredAt !=
                      latestCommand.submittedAt ||
                  !_sameObservations(
                    retainedAttempt.single.observations,
                    answer.observations,
                  )))) {
        throw const FormatException('Latest answer differs from checkpoint.');
      }
    } else if (latestCommand.action is domain.AdvanceComparisonPair) {
      if (session.answered) {
        throw const FormatException('Latest advance left an answered item.');
      }
    } else if (latestCommand.action is domain.ReviewComparisonPairs) {
      if (session.round < 2) {
        throw const FormatException(
          'Latest review did not start a review round.',
        );
      }
    } else if (latestCommand.action case domain.FinishComparisonRun(
      recordCompletion: true,
    )) {
      final threshold = session.policy.completionThresholdPercent;
      if (!session.canComplete ||
          !state.completions.any(
            (completion) =>
                completion.activityId == slot.activityId &&
                completion.contentRevision == slot.checkpoint.contentRevision &&
                completion.policyRevision == 1 &&
                completion.thresholdPercent == threshold,
          )) {
        throw const FormatException(
          'Recorded finish lacks eligible completion evidence.',
        );
      }
    }

    _validateCurrentRunAnswers(state, slot, session, catalogue);
    _validateCompletionReceipts(state, catalogue);
  }

  static domain.ComparisonLearningCommand _decodeDomainReceipt(
    ComparisonReceipt receipt,
    ComparisonProfileScope scope,
    ComparisonCatalogue catalogue,
  ) => ComparisonLearningCommandCodec.decodeLegacyCanonicalCommand(
    receipt.canonicalCommand,
    scope: scope,
    catalogue: catalogue,
  );

  static void _validateReceiptAction(
    domain.ComparisonLearningCommand command,
    ComparisonReceipt receipt,
    ComparisonCatalogue catalogue,
  ) {
    if (command.scope != receipt.scope ||
        command.expected != receipt.before ||
        command.activityId != catalogue.activityId ||
        command.token != receipt.token) {
      throw const FormatException(
        'Comparison receipt command header mismatch.',
      );
    }
    final isStart = command.action is domain.StartComparisonRun;
    final isInitial = receipt.before.generation == 0;
    final isRestart = receipt.after.generation == receipt.before.generation + 1;
    if (isStart != (isInitial || isRestart)) {
      throw const FormatException('Comparison start action/cursor mismatch.');
    }
    final initial =
        isStart &&
        receipt.before ==
            ComparisonCursor(generation: 0, sequence: 0, revision: 0) &&
        receipt.after ==
            ComparisonCursor(generation: 1, sequence: 1, revision: 0);
    final continuation =
        !isStart &&
        receipt.before.generation > 0 &&
        receipt.after.generation == receipt.before.generation &&
        receipt.after.sequence == receipt.before.sequence + 1 &&
        receipt.after.revision == receipt.before.revision + 1;
    final restart =
        isStart &&
        receipt.before.generation > 0 &&
        receipt.after.generation == receipt.before.generation + 1 &&
        receipt.after.sequence == receipt.before.sequence + 1 &&
        receipt.after.revision == 0;
    if (!(initial || continuation || restart)) {
      throw const FormatException('Unreachable comparison receipt cursor.');
    }
  }

  static bool _validObservation(
    ComparisonPlaybackObservation observation,
    ComparisonProfileScope scope,
    ComparisonSampleContent sample,
    ComparisonPairAttempt attempt,
    ComparisonSample expectedSlot,
  ) =>
      observation.slot == expectedSlot &&
      observation.referenceId == sample.referenceId &&
      observation.outcome == CourseAudioOutcome.completed &&
      observation.source == CourseAudioSource.unverifiedRecording &&
      observation.activityId == attempt.activityId &&
      observation.runGeneration == attempt.runGeneration &&
      observation.round == attempt.round &&
      observation.pairId == attempt.pairId &&
      observation.profile == scope &&
      observation.uiGeneration >= 0;

  static void _validateCurrentRunAnswers(
    ComparisonLearningState state,
    ComparisonSlot slot,
    LessonSectionSession session,
    ComparisonCatalogue catalogue,
  ) {
    final factsBySequence = <int, (String, bool)>{};
    final latestByPair = <String, (int, bool)>{};

    void record(int generation, int sequence, String pairId, bool correct) {
      if (generation != slot.cursor.generation) return;
      final fact = (pairId, correct);
      final prior = factsBySequence[sequence];
      if (prior != null && prior != fact) {
        throw const FormatException('Conflicting current-run answer facts.');
      }
      factsBySequence[sequence] = fact;
      final previousForPair = latestByPair[pairId];
      if (previousForPair == null || sequence > previousForPair.$1) {
        latestByPair[pairId] = (sequence, correct);
      }
    }

    void readReceipt(ComparisonReceipt receipt) {
      if (receipt.generation != slot.cursor.generation) return;
      final command = _decodeDomainReceipt(receipt, state.scope, catalogue);
      if (command.action case domain.AnswerComparisonPair(:final answer)) {
        record(
          receipt.generation,
          receipt.sequence,
          answer.observations.first.pairId,
          answer.selectedRelation == answer.expectedRelationSnapshot,
        );
      }
    }

    for (final receipt in state.receipts) {
      readReceipt(receipt);
    }
    readReceipt(slot.latestReceipt);
    for (final attempt in state.attempts) {
      record(
        attempt.runGeneration,
        attempt.sequence,
        attempt.pairId,
        attempt.correct,
      );
    }
    for (final entry in latestByPair.entries) {
      if (!catalogue.byId.containsKey(entry.key) ||
          session.latestAnswers[entry.key] != entry.value.$2) {
        throw const FormatException(
          'Checkpoint latest answer differs from available run evidence.',
        );
      }
    }
  }

  static void _validateCompletionReceipts(
    ComparisonLearningState state,
    ComparisonCatalogue catalogue,
  ) {
    final slot = state.slot!;
    final receipts = <ComparisonReceipt>[
      ...state.receipts,
      if (state.receipts.isEmpty) slot.latestReceipt,
    ];
    final policyByGeneration = <int, int>{};
    final justifiedCompletions = <String>{};
    for (final receipt in receipts) {
      final command = _decodeDomainReceipt(receipt, state.scope, catalogue);
      switch (command.action) {
        case domain.StartComparisonRun(:final policy):
          final previous = policyByGeneration[receipt.generation];
          if (previous != null &&
              previous != policy.completionThresholdPercent) {
            throw const FormatException('Conflicting start policies in a run.');
          }
          policyByGeneration[receipt.generation] =
              policy.completionThresholdPercent;
        case domain.FinishComparisonRun(recordCompletion: true):
          final threshold = policyByGeneration[receipt.generation];
          if (threshold != null) {
            justifiedCompletions.add(
              _completionKey(
                command.activityId,
                catalogue.contentRevision,
                1,
                threshold,
              ),
            );
          }
          if (!state.completions.any(
            (completion) =>
                completion.activityId == command.activityId &&
                completion.contentRevision == catalogue.contentRevision &&
                completion.policyRevision == 1 &&
                (threshold == null || completion.thresholdPercent == threshold),
          )) {
            throw const FormatException(
              'Recorded finish receipt lacks matching completion.',
            );
          }
        case _:
          break;
      }
    }

    final completeHistory = state.receipts.isNotEmpty
        ? state.receipts.first.commitOrdinal == 1 &&
              state.receipts.last.commitOrdinal == state.commitOrdinal
        : slot.latestReceipt.commitOrdinal == 1 && state.commitOrdinal == 1;
    if (completeHistory &&
        state.completions.any(
          (completion) => !justifiedCompletions.contains(
            _completionKey(
              completion.activityId,
              completion.contentRevision,
              completion.policyRevision,
              completion.thresholdPercent,
            ),
          ),
        )) {
      throw const FormatException(
        'Complete receipt history does not justify stored completion.',
      );
    }
  }

  static String _completionKey(
    String activityId,
    int contentRevision,
    int policyRevision,
    int threshold,
  ) => jsonEncode([activityId, contentRevision, policyRevision, threshold]);

  static LessonSectionSession _session(
    Map<String, Object?> sessionJson,
    ComparisonCatalogue catalogue,
  ) => LessonSectionSession.fromJson(
    Map<String, dynamic>.from(sessionJson),
    itemIds: catalogue.exercises.map((exercise) => exercise.id).toList(),
    contentRevision: catalogue.contentRevision,
  );

  static void _requireContent(
    String activityId,
    String pairId,
    int contentRevision,
    ComparisonCatalogue catalogue,
  ) {
    if (activityId != catalogue.activityId ||
        contentRevision != catalogue.contentRevision ||
        !catalogue.byId.containsKey(pairId)) {
      throw const FormatException('Unknown comparison content identity.');
    }
  }

  static void _validateCount(ComparisonCount count) {
    if (count.correct < 0 ||
        count.total < 0 ||
        count.correct > count.total ||
        count.correct > comparisonMaxSafeInteger ||
        count.total > comparisonMaxSafeInteger) {
      throw const FormatException('Invalid comparison summary count.');
    }
  }

  static String _cursorKey(String activityId, ComparisonCursor cursor) =>
      jsonEncode([activityId, cursor.generation, cursor.sequence]);

  static bool _sameReceipt(ComparisonReceipt left, ComparisonReceipt right) =>
      left.scope == right.scope &&
      left.activityId == right.activityId &&
      left.generation == right.generation &&
      left.sequence == right.sequence &&
      left.token == right.token &&
      left.canonicalCommand == right.canonicalCommand &&
      left.before == right.before &&
      left.after == right.after &&
      left.commitOrdinal == right.commitOrdinal;

  static bool _sameObservations(
    List<ComparisonPlaybackObservation> left,
    List<ComparisonPlaybackObservation> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      final a = left[index];
      final b = right[index];
      if (a.slot != b.slot ||
          a.referenceId != b.referenceId ||
          a.outcome != b.outcome ||
          a.source != b.source ||
          a.activityId != b.activityId ||
          a.runGeneration != b.runGeneration ||
          a.round != b.round ||
          a.pairId != b.pairId ||
          a.profile != b.profile ||
          a.uiGeneration != b.uiGeneration) {
        return false;
      }
    }
    return true;
  }
}
