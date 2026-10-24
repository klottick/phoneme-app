import 'lesson_policy.dart';
import 'spelling_learning_state.dart';

sealed class SpellingAction {
  const SpellingAction();
}

final class StartSpellingPractice extends SpellingAction {
  StartSpellingPractice({required this.sessionId, required this.policy}) {
    if (sessionId.trim().isEmpty || policy.completionThresholdPercent != 80) {
      throw ArgumentError('Spelling practice starts use the saved 80% policy.');
    }
  }

  final String sessionId;
  final LessonPolicy policy;
}

final class AnswerSpellingChoice extends SpellingAction {
  AnswerSpellingChoice({
    required this.itemId,
    required int contentRevision,
    required this.selectedOptionId,
    required this.expectedOptionIdSnapshot,
    required this.playback,
  }) : contentRevision = _positive(contentRevision, 'contentRevision') {
    if (itemId.trim().isEmpty ||
        !const {'u', 'ou'}.contains(selectedOptionId) ||
        !const {'u', 'ou'}.contains(expectedOptionIdSnapshot)) {
      throw ArgumentError('Spelling choices must use explicit option IDs.');
    }
  }

  final String itemId;
  final int contentRevision;
  final String selectedOptionId;
  final String expectedOptionIdSnapshot;
  final SpellingPlaybackObservation playback;
}

final class AdvanceSpellingItem extends SpellingAction {
  const AdvanceSpellingItem();
}

final class ReviewSpellingMistakes extends SpellingAction {
  const ReviewSpellingMistakes();
}

final class StartSpellingReviewOnly extends SpellingAction {
  const StartSpellingReviewOnly({required this.sessionId});

  final String sessionId;
}

final class FinishSpellingRun extends SpellingAction {
  const FinishSpellingRun({required this.recordCompletion});

  final bool recordCompletion;
}

final class SpellingLearningCommand {
  SpellingLearningCommand({
    required this.scope,
    required int authGeneration,
    required this.activityId,
    required this.expected,
    required int expectedScopeRevision,
    required this.token,
    required this.submittedAt,
    required this.action,
  }) : authGeneration = _counter(authGeneration, 'authGeneration'),
       expectedScopeRevision = _counter(
         expectedScopeRevision,
         'expectedScopeRevision',
       ) {
    if (activityId != 'en-fr-u-y-spelling' ||
        !RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(token) ||
        !submittedAt.isUtc) {
      throw ArgumentError('Invalid spelling command identity.');
    }
  }

  final SpellingProfileScope scope;
  final int authGeneration;
  final String activityId;
  final SpellingCursor expected;
  final int expectedScopeRevision;
  final String token;
  final DateTime submittedAt;
  final SpellingAction action;
}

int _counter(int value, String name) {
  if (value < 0 || value > spellingMaxSafeInteger) {
    throw ArgumentError.value(value, name);
  }
  return value;
}

int _positive(int value, String name) {
  if (value < 1 || value > spellingMaxSafeInteger) {
    throw ArgumentError.value(value, name);
  }
  return value;
}
