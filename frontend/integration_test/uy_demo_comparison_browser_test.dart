import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_store.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabaseHandle;
import 'package:linguist/src/core/providers/app_providers.dart'
    show onboardingControllerProvider;
import 'package:linguist/src/features/course/comparison_lesson_screen.dart';
import 'package:linguist/src/features/course_map/course_map_screen.dart';
import 'package:linguist/src/routing/app_router.dart';

const _dedicatedPath = '/course-comparison/en-fr-u-y-comparison';

final class _BrowserReferenceAudio implements CourseReferenceAudio {
  final List<String> requests = [];

  @override
  Future<CourseAudioResult> playReference(
    String referenceId, {
    CourseAudioUse use = CourseAudioUse.alphaPractice,
    CourseAudioVariant variant = CourseAudioVariant.normal,
    bool allowPracticeTts = false,
  }) async {
    requests.add(referenceId);
    return CourseAudioResult.completed(
      referenceId: referenceId,
      source: CourseAudioSource.unverifiedRecording,
    );
  }

  @override
  Future<void> speak(String word) async =>
      throw StateError('The browser acceptance test must not use TTS.');

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

final class _BrowserApp {
  _BrowserApp(this.container, this.audio, this.storeAcquisitions);

  final ProviderContainer container;
  final _BrowserReferenceAudio audio;
  final _StoreAcquisitionCounter storeAcquisitions;
  bool disposed = false;

  GoRouter get router => container.read(appRouterProvider);
}

final class _StoreAcquisitionCounter {
  int value = 0;
}

final class _ForbiddenComparisonStore implements ComparisonLearningStore {
  _ForbiddenComparisonStore()
    : scope = ComparisonProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.guest(),
      );

  @override
  final ComparisonProfileScope scope;

  @override
  Future<ComparisonLearningState> load() async =>
      throw StateError('Unknown routes must not acquire or use the store.');

  @override
  Future<ComparisonLearningState> retryLoad() => load();

  @override
  ComparisonLearningCommand prepare({
    required ComparisonLearningState state,
    required String activityId,
    required ComparisonAction action,
  }) => throw StateError('Unknown routes must not prepare commands.');

  @override
  Future<ComparisonCommit> submit(ComparisonLearningCommand command) async =>
      throw StateError('Unknown routes must not submit commands.');
}

Future<_BrowserApp> _createBrowserApp({
  bool forbidComparisonStore = false,
}) async {
  final audio = _BrowserReferenceAudio();
  final owner = LearningOwner.guest();
  final storeAcquisitions = _StoreAcquisitionCounter();
  final container = ProviderContainer(
    overrides: [
      learningAuthScopeProvider.overrideWith(
        (ref) => LearningAuthTracker(owner: owner, ready: true),
      ),
      courseReferenceAudioProvider.overrideWithValue(audio),
      if (forbidComparisonStore)
        comparisonLearningStoreProvider.overrideWith((ref) {
          storeAcquisitions.value++;
          return _ForbiddenComparisonStore();
        }),
    ],
  );
  await container
      .read(onboardingControllerProvider.notifier)
      .selectCourse('en-fr');
  return _BrowserApp(container, audio, storeAcquisitions);
}

Future<void> _disposeBrowserApp(WidgetTester tester, _BrowserApp app) async {
  if (app.disposed) return;
  app.disposed = true;
  await tester.pumpWidget(const SizedBox.shrink());
  app.router.dispose();
  final LearningDatabaseHandle handle = app.container.read(
    learningDatabaseHandleProvider,
  );
  app.container.dispose();
  await handle.close();
  await app.audio.dispose();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 45),
  );
}

Map<String, Object?> _slotSnapshot(ComparisonSlot slot) => {
  'sessionId': slot.checkpoint.sessionId,
  'sessionJson': jsonEncode(slot.checkpoint.sessionJson),
  'cursor': [
    slot.cursor.generation,
    slot.cursor.sequence,
    slot.cursor.revision,
  ],
  'latestReceipt': slot.latestReceipt.canonicalCommand,
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dedicated map answer survives in-page provider and web SQL reopen', (
    WidgetTester tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final _BrowserApp first = await _createBrowserApp();
    final GoRouter firstRouter = first.router;
    addTearDown(() => _disposeBrowserApp(tester, first));

    final store = first.container.read(comparisonLearningStoreProvider);
    expect(store, isA<SqliteComparisonLearningRepository>());
    var comparisonState = await store.load();
    expect(comparisonState.slots, isEmpty);
    final mixedCommand = store.prepare(
      state: comparisonState,
      activityId: comparisonActivityId,
      action: StartComparisonRun(
        sessionId: 'task5-mixed-compatibility-run',
        policy: LessonPolicy(),
      ),
    );
    comparisonState = (await store.submit(mixedCommand)).state;
    final mixedBefore = _slotSnapshot(
      comparisonState.slots[comparisonActivityId]!,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: first.container,
        child: const LinguistApp(),
      ),
    );
    await _settle(tester);
    expect(firstRouter.state.uri.path, '/home');
    expect(find.byType(CourseMapScreen), findsOneWidget);

    final comparisonEntry = find.widgetWithText(
      ListTile,
      'Compare /u/ and /y/',
    );
    if (comparisonEntry.evaluate().isEmpty) {
      final disclosure = find.text('All destinations');
      await tester.ensureVisible(disclosure);
      await tester.tap(disclosure);
      await _settle(tester);
    }
    await tester.ensureVisible(comparisonEntry);
    await tester.tap(comparisonEntry);
    await _settle(tester);
    expect(firstRouter.state.uri.path, '/home');
    expect(find.text('Start comparison'), findsOneWidget);
    expect(
      find.text(
        'Demo practice: this authored comparison content has not had qualified French review. It is practice, not an assessment.',
      ),
      findsOneWidget,
    );
    expect(first.audio.requests, isEmpty);
    expect(
      (await store.load()).slots[comparisonActivityId]!.checkpoint.sessionJson,
      comparisonState.slots[comparisonActivityId]!.checkpoint.sessionJson,
    );

    final startComparison = find.ancestor(
      of: find.text('Start comparison'),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(startComparison);
    await tester.tap(startComparison);
    await _settle(tester);
    expect(firstRouter.state.uri.path, _dedicatedPath);
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    expect(find.text('Compare the vowel in each sample.'), findsOneWidget);

    await tester.tap(find.text('Listen to sample A'));
    await _settle(tester);
    await tester.tap(find.text('Listen to sample B'));
    await _settle(tester);
    await tester.tap(find.text('Different'));
    await _settle(tester);
    expect(first.audio.requests, ['fr-word-tout', 'fr-word-tu']);
    expect(find.text('Continue'), findsOneWidget);

    comparisonState = await first.container.read(
      comparisonLearningStateProvider.future,
    );
    final dedicatedSlot = comparisonState.slots[uyDemoComparisonActivityId]!;
    final dedicatedCheckpoint = _slotSnapshot(dedicatedSlot);
    expect(dedicatedSlot.checkpoint.sessionJson['answered'], isTrue);
    expect(
      comparisonState.attempts.where(
        (attempt) => attempt.activityId == uyDemoComparisonActivityId,
      ),
      hasLength(1),
    );
    expect(
      _slotSnapshot(comparisonState.slots[comparisonActivityId]!),
      mixedBefore,
    );

    await _disposeBrowserApp(tester, first);

    final _BrowserApp reopened = await _createBrowserApp();
    final GoRouter reopenedRouter = reopened.router;
    addTearDown(() => _disposeBrowserApp(tester, reopened));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: reopened.container,
        child: const LinguistApp(),
      ),
    );
    await _settle(tester);
    reopenedRouter.go(_dedicatedPath);
    await _settle(tester);
    expect(reopenedRouter.state.uri.path, _dedicatedPath);
    expect(find.text('Continue'), findsOneWidget);
    final listenA = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Listen to sample A'),
    );
    expect(
      listenA.onPressed,
      isNull,
      reason: 'the saved answered checkpoint resumes without audio grants',
    );

    final reopenedState = await reopened.container
        .read(comparisonLearningStoreProvider)
        .load();
    expect(
      _slotSnapshot(reopenedState.slots[uyDemoComparisonActivityId]!),
      dedicatedCheckpoint,
    );
    expect(
      _slotSnapshot(reopenedState.slots[comparisonActivityId]!),
      mixedBefore,
    );
    expect(reopened.audio.requests, isEmpty);

    final invalid = await _createBrowserApp(forbidComparisonStore: true);
    final invalidRouter = invalid.router;
    addTearDown(() => _disposeBrowserApp(tester, invalid));
    invalidRouter.go('/course-comparison/not-a-registered-activity');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: invalid.container,
        child: const LinguistApp(),
      ),
    );
    await _settle(tester);
    expect(
      find.text('This comparison activity is unavailable.'),
      findsOneWidget,
    );
    invalidRouter.go('$_dedicatedPath?unknown=true');
    await _settle(tester);
    expect(
      find.text('This comparison activity is unavailable.'),
      findsOneWidget,
    );
    expect(invalid.storeAcquisitions.value, 0);

    // ignore: avoid_print
    print(
      'TASK5 WEB SQL IN-PAGE REOPEN: dedicatedCheckpoint=$dedicatedCheckpoint mixedCheckpoint=$mixedBefore answerCount=1 fakeAudio=${first.audio.requests} invalidRouteStoreAcquisitions=0',
    );
  });
}
