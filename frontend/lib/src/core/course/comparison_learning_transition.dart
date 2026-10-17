import 'comparison_content.dart';
import 'comparison_learning_command.dart';
import 'comparison_learning_state.dart';
import 'lesson_section_session.dart';
import 'course_audio_contract.dart';

final class ComparisonLearningTransition {
  ComparisonLearningTransition(
      {required this.nextState,
      required this.slot,
      required List<ComparisonPairAttempt> attempts,
      required this.duplicate})
      : attempts = List.unmodifiable(attempts);
  final ComparisonLearningState nextState;
  final ComparisonSlot slot;
  final List<ComparisonPairAttempt> attempts;
  final bool duplicate;
}

final class ComparisonLearningTransitionEngine {
  ComparisonLearningTransitionEngine({required this.catalogue});
  final ComparisonCatalogue catalogue;

  ComparisonLearningCommand prepare(
      {required ComparisonLearningState state,
      required String activityId,
      required ComparisonAction action,
      required int authGeneration,
      required String token,
      required DateTime submittedAt}) {
    if (activityId != catalogue.activityId || state.scope.courseId != 'en-fr') {
      throw ArgumentError('Comparison identity mismatch');
    }
    final slot = state.slot;
    final expected = slot?.cursor ??
        ComparisonCursor(generation: 0, sequence: 0, revision: 0);
    final command = ComparisonLearningCommand(
        scope: state.scope,
        authGeneration: authGeneration,
        activityId: activityId,
        expected: expected,
        token: token,
        submittedAt: submittedAt,
        action: action);
    // Validate through the same pure transition used at commit time. The
    // returned projection is discarded; the local session is reconstructed
    // from checkpoint JSON, so preparation cannot advance caller state.
    evaluate(state: state, command: command, committedAt: submittedAt);
    return command;
  }

  ComparisonLearningTransition evaluate(
      {required ComparisonLearningState state,
      required ComparisonLearningCommand command,
      required DateTime committedAt}) {
    if (command.scope != state.scope ||
        command.activityId != catalogue.activityId ||
        !committedAt.isUtc ||
        command.expected !=
            (state.slot?.cursor ??
                ComparisonCursor(generation: 0, sequence: 0, revision: 0))) {
      throw ArgumentError('Stale comparison command');
    }
    final before = state.slot;
    LessonSectionSession session;
    if (command.action
        case StartComparisonRun(:final sessionId, :final policy)) {
      session = LessonSectionSession(
          itemIds: catalogue.exercises.map((e) => e.id).toList(),
          sessionId: sessionId,
          contentRevision: catalogue.contentRevision,
          policy: policy);
    } else {
      if (before == null) {
        throw StateError('Comparison run has not started');
      }
      session = LessonSectionSession.fromJson(
          Map<String, dynamic>.from(before.checkpoint.sessionJson),
          itemIds: catalogue.exercises.map((e) => e.id).toList(),
          contentRevision: catalogue.contentRevision);
    }
    final attempts = <ComparisonPairAttempt>[];
    final mistakes =
        Map<ComparisonPairMistakeKey, ComparisonPairMistake>.of(state.mistakes);
    final summaries =
        Map<ComparisonSummaryKey, ComparisonPairSummary>.of(state.summaries);
    final completions = List<ComparisonCompletion>.of(state.completions);
    final generation = before == null
        ? 1
        : command.action is StartComparisonRun
            ? before.cursor.generation + 1
            : before.cursor.generation;
    if (command.action case AnswerComparisonPair(:final answer)) {
      final id = session.currentItemId;
      if (id == null || session.answered) {
        throw StateError('No comparison pair is answerable');
      }
      final exercise = catalogue.exercise(id);
      if (answer.expectedRelationSnapshot != exercise.expectedRelation) {
        throw ArgumentError('Expected-relation snapshot is stale');
      }
      final observations = answer.observations;
      for (var i = 0; i < 2; i++) {
        final o = observations[i];
        final sample = i == 0 ? exercise.sampleA : exercise.sampleB;
        if (o.slot != (i == 0 ? ComparisonSample.a : ComparisonSample.b) ||
            o.referenceId != sample.referenceId ||
            o.outcome != CourseAudioOutcome.completed ||
            o.source != CourseAudioSource.unverifiedRecording ||
            o.profile != state.scope ||
            o.activityId != command.activityId ||
            o.runGeneration != generation ||
            o.round != session.round ||
            o.pairId != id ||
            o.uiGeneration != observations.first.uiGeneration) {
          throw ArgumentError('Invalid comparison playback provenance');
        }
      }
      final correct = answer.selectedRelation == exercise.expectedRelation;
      final repeat = session.latestAnswers.containsKey(id);
      session.submit(correct);
      final key = ComparisonPairMistakeKey(
          scope: state.scope,
          activityId: command.activityId,
          pairId: id,
          contentRevision: catalogue.contentRevision);
      if (correct) {
        mistakes.remove(key);
      } else {
        final prev = mistakes[key];
        mistakes[key] = ComparisonPairMistake(
            scope: state.scope,
            key: key,
            firstWrongAt: prev?.firstWrongAt ?? command.submittedAt,
            latestWrongAt: command.submittedAt,
            failureCount: (prev?.failureCount ?? 0) + 1);
      }
      final sk = ComparisonSummaryKey(
          scope: state.scope,
          activityId: command.activityId,
          pairId: id,
          contentRevision: catalogue.contentRevision);
      final prior = summaries[sk];
      final first = prior?.firstInRun ?? ComparisonCount(correct: 0, total: 0),
          rep = prior?.repeatInRun ?? ComparisonCount(correct: 0, total: 0),
          after = prior?.afterDebrief ?? ComparisonCount(correct: 0, total: 0);
      final inc = (ComparisonCount(correct: correct ? 1 : 0, total: 1));
      summaries[sk] = ComparisonPairSummary(
          key: sk,
          firstInRun: repeat
              ? first
              : ComparisonCount(
                  correct: first.correct + inc.correct, total: first.total + 1),
          repeatInRun: repeat
              ? ComparisonCount(
                  correct: rep.correct + inc.correct, total: rep.total + 1)
              : rep,
          afterDebrief: session.round > 1
              ? ComparisonCount(
                  correct: after.correct + inc.correct, total: after.total + 1)
              : after);
      attempts.add(ComparisonPairAttempt(
          scope: state.scope,
          activityId: command.activityId,
          pairId: id,
          contentRevision: catalogue.contentRevision,
          runGeneration: generation,
          round: session.round,
          sequence: (before?.cursor.sequence ?? 0) + 1,
          selectedRelation: answer.selectedRelation,
          expectedRelation: exercise.expectedRelation,
          correct: correct,
          presentation: repeat
              ? AttemptPresentation.repeatInRun
              : AttemptPresentation.firstInRun,
          afterDebrief: session.round > 1,
          observations: observations,
          answeredAt: command.submittedAt,
          committedAt: committedAt));
    } else if (command.action is AdvanceComparisonPair) {
      session.advance();
    } else if (command.action is ReviewComparisonPairs) {
      session.reviewMistakes();
    } else if (command.action
        case FinishComparisonRun(:final recordCompletion)) {
      if (recordCompletion && !session.canComplete) {
        throw StateError('Comparison run is not complete');
      }
      if (recordCompletion) {
        final threshold = session.policy.completionThresholdPercent;
        if (!completions.any((c) =>
            c.activityId == command.activityId &&
            c.contentRevision == catalogue.contentRevision &&
            c.policyRevision == 1 &&
            c.thresholdPercent == threshold)) {
          completions.add(ComparisonCompletion(
              scope: state.scope,
              activityId: command.activityId,
              contentRevision: catalogue.contentRevision,
              policyRevision: 1,
              thresholdPercent: threshold,
              committedAt: committedAt));
        }
      }
    }
    final cursor = command.action is StartComparisonRun
        ? ComparisonCursor(
            generation: generation,
            sequence: (before?.cursor.sequence ?? 0) + 1,
            revision: 0)
        : ComparisonCursor(
            generation: generation,
            sequence: (before?.cursor.sequence ?? 0) + 1,
            revision: (before?.cursor.revision ?? 0) + 1);
    final canon = comparisonCanonicalCommand(command);
    final ordinal = state.commitOrdinal + 1;
    final receipt = ComparisonReceipt(
        scope: state.scope,
        activityId: command.activityId,
        generation: generation,
        sequence: cursor.sequence,
        token: command.token,
        canonicalCommand: canon,
        before: before?.cursor ??
            ComparisonCursor(generation: 0, sequence: 0, revision: 0),
        after: cursor,
        commitOrdinal: ordinal);
    final checkpoint = ComparisonCheckpoint(
        scope: state.scope,
        sessionId: session.sessionId,
        contentRevision: catalogue.contentRevision,
        policy: session.policy,
        sessionJson: session.toJson());
    final slot = ComparisonSlot(
        scope: state.scope,
        activityId: command.activityId,
        cursor: cursor,
        checkpoint: checkpoint,
        latestReceipt: receipt);
    final retainedAttempts = [...state.attempts, ...attempts];
    final retainedReceipts = [...state.receipts, receipt];
    final next = ComparisonLearningState(
        scope: state.scope,
        revision: state.revision + 1,
        commitOrdinal: ordinal,
        slot: slot,
        attempts: retainedAttempts
            .skip(retainedAttempts.length > 2000
                ? retainedAttempts.length - 2000
                : 0)
            .toList(),
        receipts: retainedReceipts
            .skip(retainedReceipts.length > 2000
                ? retainedReceipts.length - 2000
                : 0)
            .toList(),
        mistakes: mistakes,
        summaries: summaries,
        completions: completions);
    return ComparisonLearningTransition(
        nextState: next, slot: slot, attempts: attempts, duplicate: false);
  }
}
