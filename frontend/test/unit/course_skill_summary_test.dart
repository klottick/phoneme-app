import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_skill_summary.dart';
import '../support/course_learning_fixtures.dart';
import 'package:linguist/src/core/course/course_attempt.dart';

void main() {
  test('distinct targets contribute once and preserve old buckets', () {
    final key = SummaryKey(
        sound: 's',
        skill: LearningSkill.listening,
        origin: AttemptOrigin.practice,
        presentation: AttemptPresentation.firstInRun,
        assistance: <AssistanceFlag>{});
    final previous = <SummaryKey, SkillCount>{
      key: SkillCount(total: 1, correct: 0)
    };
    final buckets = addAttemptCounts(previous, [
      sampleAttempt(),
      sampleAttempt(
          correct: true,
          presentation: AttemptPresentation.repeatInRun,
          sequence: 2),
    ]);
    expect(buckets.values.map((c) => c.total).reduce((a, b) => a + b), 3);
    expect(buckets.keys.map((k) => k.presentation).toSet(), {
      AttemptPresentation.firstInRun,
      AttemptPresentation.repeatInRun,
    });
    expect(previous[key]!.total, 1);
    expect(buckets[key]!.correct, 0);
  });
}
