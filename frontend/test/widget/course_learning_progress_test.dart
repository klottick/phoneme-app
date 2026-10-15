import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_skill_summary.dart';
import 'package:linguist/src/features/course/course_progress_screen.dart';
import 'package:linguist/src/features/home/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('progress explains the new format and assessment boundary',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: CourseProgressScreen()),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This alpha uses a new progress format. Earlier development progress has not been imported.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('not assessed'), findsWidgets);
  });

  testWidgets('wrong first and successful retry stay separately visible',
      (tester) async {
    final scope = LearningScope(
        courseId: 'en-fr', owner: LearningOwner.account('progress-user'));
    final state = CourseLearningState(
      scope: scope,
      revision: 1,
      commitOrdinal: 1,
      history: const [],
      activities: const {},
      mistakes: const {},
      summaries: {
        SummaryKey(
          sound: 'u',
          skill: LearningSkill.listening,
          origin: AttemptOrigin.practice,
          presentation: AttemptPresentation.firstInRun,
          assistance: const {},
        ): SkillCount(total: 1, correct: 0),
        SummaryKey(
          sound: 'u',
          skill: LearningSkill.listening,
          origin: AttemptOrigin.practice,
          presentation: AttemptPresentation.repeatInRun,
          assistance: const {AssistanceFlag.explanationVisible},
        ): SkillCount(total: 1, correct: 1),
        SummaryKey(
          sound: 'u',
          skill: LearningSkill.listening,
          origin: AttemptOrigin.game,
          presentation: AttemptPresentation.firstInRun,
          assistance: const {AssistanceFlag.graphemeHint},
        ): SkillCount(total: 3, correct: 2),
      },
      completions: const [],
      bestScores: const {},
      pending: [
        SupportedCloudEvent(
          id: 'pending-event',
          userId: 'progress-user',
          courseId: 'en-fr',
          payload: CloudAnswer(
            sound: 'u',
            skill: LearningSkill.listening,
            correct: true,
            activity: 'lesson:en-fr-u-y',
          ),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseLearningStateProvider.overrideWith((ref) async => state)
      ],
      child: const MaterialApp(home: CourseProgressScreen()),
    ));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('Practice · first presentation'), findsOneWidget);
    expect(find.textContaining('0 correct / 1 answer'), findsOneWidget);
    expect(
        find.textContaining('Practice · repeat presentation'), findsOneWidget);
    expect(find.textContaining('1 correct / 1 answer'), findsOneWidget);
    expect(find.textContaining('assisted'), findsWidgets);
    await tester.scrollUntilVisible(
        find.textContaining('Game · first presentation'), 180);
    expect(find.textContaining('Game · first presentation'), findsOneWidget);
    expect(find.textContaining('2 correct / 3 answers'), findsOneWidget);
    expect(find.textContaining('sample'), findsWidgets);
    expect(find.textContaining('pending recording'), findsWidgets);
    expect(
        find.textContaining(
            'Supported backup covers scores and answer totals.'),
        findsOneWidget);
    expect(
        find.textContaining(
            'Detailed history, mistakes and lesson resume stay on this device.'),
        findsOneWidget);
    expect(
        find.textContaining(
            'Offline: supported backup is pending; local commits remain saved on this device.'),
        findsOneWidget);
    expect(
        find.textContaining(
            'Earlier server totals were not reset or imported.'),
        findsWidgets);
  });

  testWidgets('home completion uses committed current-revision records only',
      (tester) async {
    final scope =
        LearningScope(courseId: 'en-fr', owner: LearningOwner.guest());
    final currentRevision = LearningRegistry.french()
        .require('lesson:en-fr-vowels')
        .contentRevision;
    final state = CourseLearningState(
      scope: scope,
      revision: 1,
      commitOrdinal: 1,
      history: const [],
      activities: const {},
      mistakes: const {},
      summaries: const {},
      completions: [
        LearningCompletion(
          lessonId: 'en-fr-vowels',
          contentRevision: currentRevision,
          policyKind: CompletionPolicyKind.legacyOnePass,
          policyRevision: 1,
          thresholdPercent: null,
          committedAt: DateTime.utc(2026, 10, 15),
        ),
        LearningCompletion(
          lessonId: 'en-fr-u-y',
          contentRevision: 2,
          policyKind: CompletionPolicyKind.discoveryThreshold,
          policyRevision: 1,
          thresholdPercent: 80,
          committedAt: DateTime.utc(2026, 10, 15),
        ),
      ],
      bestScores: const {},
      pending: const [],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseLearningStateProvider.overrideWith((ref) async => state)
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();

    expect(
        find.text('1 of 5 lessons complete · about 3 minutes'), findsOneWidget);
    expect(find.textContaining('Continue lesson'), findsOneWidget);
  });

  testWidgets('unavailable mistakes are labeled and cannot route to review',
      (tester) async {
    final scope =
        LearningScope(courseId: 'en-fr', owner: LearningOwner.guest());
    final key = MistakeKey(
      activityId: 'lesson:removed-content',
      itemId: 'removed-word',
      contentRevision: 1,
      skill: LearningSkill.listening,
      targetSound: 'u',
    );
    final state = CourseLearningState(
      scope: scope,
      revision: 1,
      commitOrdinal: 1,
      history: const [],
      activities: const {},
      mistakes: {
        key: LearningMistake(
          key: key,
          firstWrongId: 'first',
          firstWrongAt: DateTime.utc(2026, 10, 15),
          latestWrongId: 'latest',
          latestWrongAt: DateTime.utc(2026, 10, 15),
          failureCount: 1,
          lastRunGeneration: 1,
        ),
      },
      summaries: const {},
      completions: const [],
      bestScores: const {},
      pending: const [],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseLearningStateProvider.overrideWith((ref) async => state)
      ],
      child: const MaterialApp(home: CourseProgressScreen(review: true)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unavailable content · not reviewable'),
        findsOneWidget);
    final tile = tester.widget<ListTile>(find.byType(ListTile).last);
    expect(tile.onTap, isNull);
  });
}
