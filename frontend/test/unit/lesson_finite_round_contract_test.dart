import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';

LessonSectionSession _answeredSection(
    {required int items, required int correct, int percent = 80}) {
  final session = LessonSectionSession(
      itemIds: List.generate(items, (index) => 'item-$index'),
      sessionId: 'finite-round-contract',
      policy: LessonPolicy(completionThresholdPercent: percent));
  for (var index = 0; index < items; index++) {
    session.submit(index < correct);
    if (index < items - 1) session.advance();
  }
  return session;
}

void main() {
  test('session_threshold_matrix_requires_full_coverage_and_debrief', () {
    const cases = [
      (10, 7, 80, false),
      (10, 8, 80, true),
      (8, 6, 80, false),
      (8, 7, 80, true),
      (8, 6, 75, true),
      (10, 9, 100, false),
      (10, 10, 100, true),
    ];
    for (final (items, correct, percent, passes) in cases) {
      final session =
          _answeredSection(items: items, correct: correct, percent: percent);
      expect(session.answeredItemCount, items);
      expect(session.canComplete, isFalse);
      session.advance();
      expect(session.phase, LessonSectionPhase.debrief);
      expect(session.canComplete, passes);
    }
  });

  test('all_wrong_rounds_remain_finite_beyond_twelve_submissions', () {
    final session = LessonSectionSession(
        itemIds: const ['a', 'b', 'c'], sessionId: 'finite-all-wrong');
    final unresolved = ['a', 'b', 'c'];
    for (var round = 1; round <= 5; round++) {
      if (round > 1) session.reviewMistakes();
      final queue = List<String>.from(session.queue);
      for (var index = 0; index < 3; index++) {
        session.submit(false);
        session.advance();
      }
      expect(session.phase, LessonSectionPhase.debrief);
      expect(session.attemptCount, 3 * round);
      expect(session.unresolvedItemIds, unresolved);
      expect(session.canComplete, isFalse);
      expect(session.queue, queue);
    }
  });

  test('partial_later_round_restore_preserves_queue_and_saved_policy', () {
    final session = LessonSectionSession(
        itemIds: const ['a', 'b', 'c'],
        sessionId: 'finite-restore',
        policy: LessonPolicy(completionThresholdPercent: 75));
    for (var index = 0; index < 3; index++) {
      session.submit(false);
      session.advance();
    }
    session.reviewMistakes();
    for (var index = 0; index < 3; index++) {
      session.submit(false);
      session.advance();
    }
    session.reviewMistakes();
    session.submit(true);

    final restored = LessonSectionSession.fromJson(session.toJson(),
        itemIds: const ['a', 'b', 'c'], contentRevision: 1);
    expect(restored.round, 3);
    expect(restored.position, 0);
    expect(restored.answered, isTrue);
    expect(restored.lastCorrect, isTrue);
    expect(restored.attemptCount, 7);
    expect(restored.queue, ['a', 'b', 'c']);
    expect(restored.policy.completionThresholdPercent, 75);
    expect(restored.latestAnswers, {'a': true, 'b': false, 'c': false});

    restored.advance();
    for (var index = 0; index < 2; index++) {
      restored.submit(false);
      restored.advance();
    }
    expect(restored.phase, LessonSectionPhase.debrief);
    expect(restored.attemptCount, 9);
    expect(restored.unresolvedItemIds, ['b', 'c']);
  });
}
