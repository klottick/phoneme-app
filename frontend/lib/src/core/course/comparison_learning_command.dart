import 'dart:convert';
import 'comparison_content.dart';
import 'comparison_learning_state.dart';
import 'lesson_policy.dart';

sealed class ComparisonAction {
  const ComparisonAction();
}

final class StartComparisonRun extends ComparisonAction {
  const StartComparisonRun({required this.sessionId, required this.policy});
  final String sessionId;
  final LessonPolicy policy;
}

final class AnswerComparisonPair extends ComparisonAction {
  AnswerComparisonPair(this.answer);
  final ComparePhonemesAnswer answer;
}

final class AdvanceComparisonPair extends ComparisonAction {
  const AdvanceComparisonPair();
}

final class ReviewComparisonPairs extends ComparisonAction {
  const ReviewComparisonPairs();
}

final class FinishComparisonRun extends ComparisonAction {
  const FinishComparisonRun({required this.recordCompletion});
  final bool recordCompletion;
}

final class ComparePhonemesAnswer {
  ComparePhonemesAnswer(
      {required this.selectedRelation,
      required this.expectedRelationSnapshot,
      required List<ComparisonPlaybackObservation> observations})
      : observations = List.unmodifiable(observations) {
    if (observations.length != 2 ||
        observations[0].slot != ComparisonSample.a ||
        observations[1].slot != ComparisonSample.b) {
      throw ArgumentError('Observations must be ordered A then B');
    }
  }
  final PhonemeRelation selectedRelation, expectedRelationSnapshot;
  final List<ComparisonPlaybackObservation> observations;
}

final class ComparisonLearningCommand {
  ComparisonLearningCommand(
      {required this.scope,
      required int authGeneration,
      required this.activityId,
      required this.expected,
      required this.token,
      required this.submittedAt,
      required this.action})
      : authGeneration = comparisonCounter(authGeneration, 'authGeneration') {
    if (activityId != comparisonActivityId ||
        !RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(token) ||
        !submittedAt.isUtc) {
      throw ArgumentError('Invalid comparison command');
    }
  }
  final ComparisonProfileScope scope;
  final int authGeneration;
  final String activityId, token;
  final ComparisonCursor expected;
  final DateTime submittedAt;
  final ComparisonAction action;
}

String comparisonCanonicalCommand(ComparisonLearningCommand c) {
  final owner = c.scope.owner.isGuest
      ? <String, Object?>{'kind': 'guest', 'userId': null}
      : <String, Object?>{'kind': 'account', 'userId': c.scope.owner.userId};
  final action = switch (c.action) {
    StartComparisonRun(:final sessionId, :final policy) => <String, Object?>{
        'kind': 'start',
        'sessionId': sessionId,
        'policy': policy.toJson()
      },
    AnswerComparisonPair(:final answer) => <String, Object?>{
        'kind': 'answer',
        'selectedRelation': answer.selectedRelation.name,
        'expectedRelationSnapshot': answer.expectedRelationSnapshot.name,
        'observations': [
          for (final o in answer.observations)
            {
              'slot': o.slot.name,
              'referenceId': o.referenceId,
              'outcome': o.outcome.name,
              'source': o.source?.name,
              'activityId': o.activityId,
              'runGeneration': o.runGeneration,
              'round': o.round,
              'pairId': o.pairId,
              'uiGeneration': o.uiGeneration
            }
        ]
      },
    AdvanceComparisonPair() => <String, Object?>{'kind': 'advance'},
    ReviewComparisonPairs() => <String, Object?>{'kind': 'review'},
    FinishComparisonRun(:final recordCompletion) => <String, Object?>{
        'kind': 'finish',
        'recordCompletion': recordCompletion
      },
  };
  final cursor = c.expected;
  return jsonEncode(<String, Object?>{
    'schemaVersion': 1,
    'family': 'comparison',
    'courseId': c.scope.courseId,
    'owner': owner,
    'authGeneration': c.authGeneration,
    'activityId': c.activityId,
    'generation': cursor.generation,
    'sequence': cursor.sequence,
    'revision': cursor.revision,
    'token': c.token,
    'submittedAt': c.submittedAt.toIso8601String(),
    'action': action
  });
}
