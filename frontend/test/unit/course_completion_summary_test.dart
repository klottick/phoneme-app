import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/features/course/course_completion_summary.dart';

void main() {
  final registry = LearningRegistry.french();
  final scope = LearningScope(courseId: 'en-fr', owner: LearningOwner.guest());

  CourseLearningState stateWith(List<LearningCompletion> completions) =>
      CourseLearningState(
        scope: scope,
        revision: 0,
        commitOrdinal: 0,
        history: const [],
        activities: const {},
        mistakes: const {},
        summaries: const {},
        completions: completions,
        bestScores: const {},
        pending: const [],
      );

  LearningCompletion completion(
          String lessonId, int contentRevision, CompletionPolicyKind policyKind,
          {int? threshold}) =>
      LearningCompletion(
        lessonId: lessonId,
        contentRevision: contentRevision,
        policyKind: policyKind,
        policyRevision: 1,
        thresholdPercent: threshold,
        committedAt: DateTime.utc(2026),
      );

  test('completion_projection_separates_discovery_from_existing', () {
    final legacyVowels =
        completion('en-fr-vowels', 1, CompletionPolicyKind.legacyOnePass);
    final stalePilot = completion(
        'en-fr-u-y', 2, CompletionPolicyKind.discoveryThreshold,
        threshold: 80);
    final legacyPilot =
        completion('en-fr-u-y', 1, CompletionPolicyKind.legacyOnePass);
    final discoveryPilot = completion(
        'en-fr-u-y', 1, CompletionPolicyKind.discoveryThreshold,
        threshold: 100);
    final unknown =
        completion('unknown-lesson', 1, CompletionPolicyKind.legacyOnePass);

    final historical = CourseCompletionSummary.fromState(
        state: stateWith([
          legacyVowels,
          stalePilot,
          completion('en-fr-vowels', 1, CompletionPolicyKind.legacyOnePass),
          completion('en-fr-vowels', 1, CompletionPolicyKind.legacyOnePass),
          unknown,
        ]),
        registry: registry);
    expect(historical.existingComplete, 1);
    expect(historical.existingTotal, 5);
    expect(historical.discoveryCompleteCount, 0);
    expect(historical.discoveryTotal, 1);
    expect(historical.completedExistingLessonIds, {'en-fr-vowels'});
    expect(() => historical.completedExistingLessonIds.add('unknown-lesson'),
        throwsUnsupportedError);

    final discovered = CourseCompletionSummary.fromState(
        state: stateWith([
          legacyVowels,
          stalePilot,
          discoveryPilot,
          discoveryPilot,
          unknown,
        ]),
        registry: registry);
    expect(discovered.discoveryComplete, isTrue);
    expect(discovered.discoveryCompleteCount, 1);
    expect(discovered.existingComplete, 2);
    expect(discovered.completedExistingLessonIds.length, 2);

    final allKnownWithDuplicates = CourseCompletionSummary.fromState(
        state: stateWith([
          for (final lesson in registry.activities
              .where((activity) => activity.id.startsWith('lesson:')))
            completion(
                lesson.id.substring('lesson:'.length),
                lesson.contentRevision,
                lesson.id.endsWith('en-fr-u-y')
                    ? CompletionPolicyKind.discoveryThreshold
                    : CompletionPolicyKind.legacyOnePass,
                threshold: lesson.id.endsWith('en-fr-u-y') ? 100 : null),
          for (final lesson in registry.activities
              .where((activity) => activity.id.startsWith('lesson:')))
            completion(
                lesson.id.substring('lesson:'.length),
                lesson.contentRevision,
                lesson.id.endsWith('en-fr-u-y')
                    ? CompletionPolicyKind.discoveryThreshold
                    : CompletionPolicyKind.legacyOnePass,
                threshold: lesson.id.endsWith('en-fr-u-y') ? 100 : null),
        ]),
        registry: registry);
    expect(allKnownWithDuplicates.existingComplete, 5);
    expect(allKnownWithDuplicates.existingTotal, 5);
    expect(allKnownWithDuplicates.discoveryCompleteCount, 1);
    expect(allKnownWithDuplicates.discoveryTotal, 1);
    expect(allKnownWithDuplicates.completedExistingLessonIds.length, 5);

    final legacyOnlyPilot = CourseCompletionSummary.fromState(
        state: stateWith([legacyPilot]), registry: registry);
    expect(legacyOnlyPilot.existingComplete, 1);
    expect(legacyOnlyPilot.discoveryComplete, isFalse);

    expect(discovered.discoveryComplete, isTrue);
  });
}
