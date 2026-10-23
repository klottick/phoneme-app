import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/french_sentence_exercises.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/features/course/course_completion_summary.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/features/course_map/course_map_screen.dart';
import 'package:linguist/src/features/course_map/course_map_providers.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/controlled_listening_audio.dart';
import '../support/course_learning_widget_store.dart';
import '../support/map_motion_test_support.dart';

final class _ComparisonMapFixture {
  const _ComparisonMapFixture({required this.registry, required this.state});

  final ComparisonCatalogueRegistry registry;
  final ComparisonLearningState state;
}

final class _RecommendationMapApp {
  const _RecommendationMapApp({
    required this.container,
    required this.router,
    required this.courseStore,
    required this.audio,
  });

  final ProviderContainer container;
  final GoRouter router;
  final CourseLearningWidgetStore courseStore;
  final ControlledListeningAudio audio;
}

Future<CourseLearningState> _discoveryMapState({
  bool started = false,
  bool completed = false,
}) async {
  const activityId = 'lesson:en-fr-u-y';
  final store = CourseLearningWidgetStore();
  var state = store.committedState;

  Future<void> apply(LearningAction action) async {
    final command = store.prepare(
      state: state,
      activityId: activityId,
      action: action,
    );
    state = (await store.submit(command)).state;
  }

  if (started || completed) {
    await apply(StartLearningRun(options: RunOptions()));
  }
  if (completed) {
    final activity = LearningRegistry.french().require(activityId);
    for (final _ in activity.items) {
      final checkpoint =
          state.activities[activityId]!.snapshot as DiscoveryCheckpoint;
      final item = activity.items.singleWhere(
        (candidate) =>
            candidate.sessionAlias == checkpoint.session.currentItemId,
      );
      await apply(
        ChooseSound(
          selectedSound: item.expectedChoice!,
          audioSource: authoredAudioSource(item)!,
        ),
      );
      await apply(const AdvanceLesson());
    }
    await apply(const FinishLearningActivity());
  }
  return state;
}

_ComparisonMapFixture _comparisonMapFixture({
  bool dedicatedStarted = false,
  bool dedicatedCompleted = false,
  bool dedicatedAvailable = true,
}) {
  const activityId = uyDemoComparisonActivityId;
  final scope = ComparisonProfileScope(
    courseId: 'en-fr',
    owner: LearningOwner.guest(),
  );
  final mixedCatalogue = loadFrenchComparisonCatalogue();
  final dedicatedCatalogue = loadFrenchUyDemoComparisonCatalogue();
  final registry = ComparisonCatalogueRegistry([
    ComparisonCatalogueRegistration.available(mixedCatalogue),
    if (dedicatedAvailable)
      ComparisonCatalogueRegistration.available(dedicatedCatalogue)
    else
      ComparisonCatalogueRegistration.unavailable(
        activityId: activityId,
        cause: StateError('Test fixture keeps dedicated content unavailable.'),
      ),
  ]);
  var state = ComparisonLearningState.empty(scope);
  final engine = ComparisonLearningTransitionEngine(registry: registry);
  var sequence = 0;

  void apply(ComparisonAction action) {
    sequence++;
    final submittedAt = DateTime.utc(
      2026,
      10,
      23,
    ).add(Duration(seconds: sequence));
    final command = engine.prepare(
      state: state,
      activityId: activityId,
      action: action,
      authGeneration: 0,
      token: sequence.toString().padLeft(22, '0'),
      submittedAt: submittedAt,
    );
    state = engine
        .evaluate(state: state, command: command, committedAt: submittedAt)
        .nextState;
  }

  if (dedicatedStarted || dedicatedCompleted) {
    apply(
      StartComparisonRun(
        sessionId: 'map-recommendation-dedicated-run',
        policy: LessonPolicy(),
      ),
    );
  }
  if (dedicatedCompleted) {
    for (final _ in dedicatedCatalogue.exercises) {
      final slot = state.slots[activityId]!;
      final session = LessonSectionSession.fromJson(
        Map<String, dynamic>.from(slot.checkpoint.sessionJson),
        itemIds: dedicatedCatalogue.exercises
            .map((exercise) => exercise.id)
            .toList(growable: false),
        contentRevision: dedicatedCatalogue.contentRevision,
      );
      final exercise = dedicatedCatalogue.exercise(session.currentItemId!);
      apply(
        AnswerComparisonPair(
          ComparePhonemesAnswer(
            selectedRelation: exercise.expectedRelation,
            expectedRelationSnapshot: exercise.expectedRelation,
            observations: [
              for (final sample in [exercise.sampleA, exercise.sampleB])
                ComparisonPlaybackObservation(
                  slot: sample.slot,
                  referenceId: sample.referenceId,
                  outcome: CourseAudioOutcome.completed,
                  source: CourseAudioSource.unverifiedRecording,
                  activityId: activityId,
                  runGeneration: slot.cursor.generation,
                  round: session.round,
                  pairId: exercise.id,
                  profile: scope,
                  uiGeneration: 0,
                ),
            ],
          ),
        ),
      );
      apply(const AdvanceComparisonPair());
    }
    apply(const FinishComparisonRun(recordCompletion: true));
  }

  return _ComparisonMapFixture(registry: registry, state: state);
}

Future<_RecommendationMapApp> _mountRecommendationMap(
  WidgetTester tester, {
  required Map<String, String> sentenceAssets,
  required CourseLearningState courseState,
  required _ComparisonMapFixture comparison,
}) async {
  disableMapMotion(tester);
  final owner = LearningOwner.guest();
  final courseStore = CourseLearningWidgetStore(initialState: courseState);
  final audio = ControlledListeningAudio();
  final container = ProviderContainer(
    overrides: [
      learningAuthScopeProvider.overrideWith(
        (ref) => LearningAuthTracker(owner: owner, ready: true),
      ),
      courseLearningStoreProvider.overrideWithValue(courseStore),
      courseLearningStateProvider.overrideWith((ref) async => courseState),
      courseAudioProvider.overrideWithValue(audio),
      courseReferenceAudioProvider.overrideWithValue(audio),
      comparisonCatalogueRegistryProvider.overrideWithValue(
        comparison.registry,
      ),
      comparisonLearningStateProvider.overrideWith(
        (ref) async => comparison.state,
      ),
      sentencePackageLoaderProvider.overrideWithValue(
        FrenchSentencePackageLoader(
          bundle: _RepositoryAssetBundle(sentenceAssets),
        ),
      ),
      sentenceHuntLearningStateProvider.overrideWith((ref) async {
        return SentenceHuntLearningState.empty(
          SentenceHuntProfileScope(courseId: 'en-fr', owner: owner),
        );
      }),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const LinguistApp()),
  );
  await tester.pumpAndSettle();
  return _RecommendationMapApp(
    container: container,
    router: container.read(appRouterProvider),
    courseStore: courseStore,
    audio: audio,
  );
}

Future<void> _unmountRecommendationMap(
  WidgetTester tester,
  _RecommendationMapApp app,
) async {
  app.audio.releaseAll();
  await tester.pumpWidget(const SizedBox.shrink());
  app.router.dispose();
  app.container.dispose();
  await app.audio.dispose();
}

Future<void> _inspectMapBody(WidgetTester tester, String title) async {
  final body = find.widgetWithText(ListTile, title);
  if (body.evaluate().isEmpty) {
    final disclosure = find.text('All destinations');
    await tester.ensureVisible(disclosure);
    await tester.tap(disclosure);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(body);
  await tester.tap(body);
  await tester.pumpAndSettle();
}

void main() {
  late Map<String, String> sentenceAssets;
  setUpAll(() {
    sentenceAssets = {
      for (final file in const [
        'manifest.json',
        'provenance.json',
        'annotations.json',
        'source-evidence.json',
      ])
        'assets/audio/fr-sentences/$file': File(
          'assets/audio/fr-sentences/$file',
        ).readAsStringSync(),
    };
  });
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'}),
  );

  testWidgets(
    'authored recommendation stays visible while inspecting another body',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(
        () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
      );

      final courseState = await _discoveryMapState(started: true);
      final comparison = _comparisonMapFixture(dedicatedStarted: true);
      final app = await _mountRecommendationMap(
        tester,
        sentenceAssets: sentenceAssets,
        courseState: courseState,
        comparison: comparison,
      );
      addTearDown(() => _unmountRecommendationMap(tester, app));

      final projected = app.container.read(
        courseMapStateProvider('en-fr-u-y-system'),
      );
      final recommendation = projected.bodies.singleWhere(
        (body) => body.recommended,
      );
      expect(recommendation.definition.id, 'discovery');
      expect(recommendation.progress, MapProgress.resumable);
      expect(
        find.text('Recommended next: Hear the difference'),
        findsOneWidget,
      );
      expect(find.text('Continue your saved run.'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Recommended next: Hear the difference. Continue your saved run.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.text('Recommended next: Hear the difference'),
      );

      final currentBodyId = projected.currentBodyId;
      final comparisonBefore = await app.container.read(
        comparisonLearningStateProvider.future,
      );
      final dedicatedSlotBefore =
          comparisonBefore.slots[uyDemoComparisonActivityId]!;
      await _inspectMapBody(tester, 'Compare /u/ and /y/');
      expect(find.text('Continue comparison'), findsOneWidget);
      expect(
        find.text('Recommended next: Hear the difference'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.text('Recommended next: Hear the difference'),
      );
      expect(
        app.container
            .read(courseMapStateProvider('en-fr-u-y-system'))
            .currentBodyId,
        currentBodyId,
      );
      expect(app.router.state.uri.path, '/home');
      expect(app.courseStore.submitted, isEmpty);
      expect(app.audio.requests, isEmpty);

      final comparisonAfter = await app.container.read(
        comparisonLearningStateProvider.future,
      );
      final dedicatedSlotAfter =
          comparisonAfter.slots[uyDemoComparisonActivityId]!;
      expect(comparisonAfter.revision, comparisonBefore.revision);
      expect(comparisonAfter.commitOrdinal, comparisonBefore.commitOrdinal);
      expect(dedicatedSlotAfter.cursor, dedicatedSlotBefore.cursor);
      expect(
        dedicatedSlotAfter.checkpoint.sessionJson,
        dedicatedSlotBefore.checkpoint.sessionJson,
      );
    },
  );

  testWidgets(
    'recommendation falls back to the first incomplete available main lesson',
    (tester) async {
      final courseState = await _discoveryMapState(completed: true);
      final comparison = _comparisonMapFixture();
      final app = await _mountRecommendationMap(
        tester,
        sentenceAssets: sentenceAssets,
        courseState: courseState,
        comparison: comparison,
      );
      addTearDown(() => _unmountRecommendationMap(tester, app));

      final projected = app.container.read(
        courseMapStateProvider('en-fr-u-y-system'),
      );
      final recommendation = projected.bodies.singleWhere(
        (body) => body.recommended,
      );
      expect(recommendation.definition.id, 'comparison');
      expect(recommendation.progress, MapProgress.notStarted);
      expect(
        find.text('Recommended next: Compare /u/ and /y/'),
        findsOneWidget,
      );
      expect(
        find.text('First available incomplete main lesson.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'unavailable main and non-main destinations receive no recommendation',
    (tester) async {
      final courseState = await _discoveryMapState(completed: true);
      final comparison = _comparisonMapFixture(dedicatedAvailable: false);
      final app = await _mountRecommendationMap(
        tester,
        sentenceAssets: sentenceAssets,
        courseState: courseState,
        comparison: comparison,
      );
      addTearDown(() => _unmountRecommendationMap(tester, app));

      final projected = app.container.read(
        courseMapStateProvider('en-fr-u-y-system'),
      );
      expect(
        projected.bodies
            .singleWhere((body) => body.definition.id == 'comparison')
            .readiness,
        MapReadiness.unavailable,
      );
      expect(projected.bodies.where((body) => body.recommended), isEmpty);
      expect(
        projected.bodies
            .where(
              (body) =>
                  !['discovery', 'comparison'].contains(body.definition.id),
            )
            .where((body) => body.recommended),
        isEmpty,
      );
      expect(find.textContaining('Recommended next:'), findsNothing);
      expect(
        find.text('All currently available lessons complete.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'both current main completions show positive available-complete status',
    (tester) async {
      final courseState = await _discoveryMapState(completed: true);
      final comparison = _comparisonMapFixture(dedicatedCompleted: true);
      expect(courseState.completions, hasLength(1));
      expect(courseState.completions.single.lessonId, frenchUySection.lessonId);
      expect(
        courseState.completions.single.contentRevision,
        frenchUySection.contentRevision,
      );
      expect(comparison.state.completions, hasLength(1));
      expect(
        comparison.state.completions.single.activityId,
        uyDemoComparisonActivityId,
      );
      expect(
        comparison.state.completions.single.contentRevision,
        loadFrenchUyDemoComparisonCatalogue().contentRevision,
      );

      final app = await _mountRecommendationMap(
        tester,
        sentenceAssets: sentenceAssets,
        courseState: courseState,
        comparison: comparison,
      );
      addTearDown(() => _unmountRecommendationMap(tester, app));

      final projected = app.container.read(
        courseMapStateProvider('en-fr-u-y-system'),
      );
      expect(projected.allAvailableMainComplete, isTrue);
      expect(projected.bodies.where((body) => body.recommended), isEmpty);
      expect(
        find.text('Available main lessons: 2/2 available complete'),
        findsOneWidget,
      );
      expect(
        find.text('All currently available lessons complete.'),
        findsOneWidget,
      );
      expect(find.textContaining('Recommended next:'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      for (final (id, title, description) in const [
        (
          'context',
          'Find sounds in context',
          'Planned listening lesson: find /u/ and /y/ in context. '
              '"Coming soon"; the existing mixed sentence-hunt group is not '
              'remapped into this planet.',
        ),
        (
          'spelling',
          'Sound → spelling',
          'Planned spelling lesson. "Coming soon"; existing game hints are '
              'not a substitute.',
        ),
        (
          'checkpoint',
          'Checkpoint',
          'Planned assessment. "Coming soon"; no unassessed zero score is '
              'offered.',
        ),
      ]) {
        expect(
          projected.bodies
              .singleWhere((body) => body.definition.id == id)
              .readiness,
          MapReadiness.planned,
        );
        await _inspectMapBody(tester, title);
        final plannedDisclosure = find.text(description);
        await tester.ensureVisible(plannedDisclosure);
        expect(plannedDisclosure, findsOneWidget);
      }
    },
  );

  testWidgets('map_journey_uses_real_committed_state', (tester) async {
    final store = CourseLearningWidgetStore()
      ..actionGates[FinishLearningActivity] = Completer<void>()
      ..failingActions.add(FinishLearningActivity);
    final audio = ControlledListeningAudio();
    disableMapMotion(tester);
    final container = ProviderContainer(
      overrides: [
        courseLearningStoreProvider.overrideWithValue(store),
        courseAudioProvider.overrideWithValue(audio),
        sentencePackageLoaderProvider.overrideWithValue(
          FrenchSentencePackageLoader(
            bundle: _RepositoryAssetBundle(sentenceAssets),
          ),
        ),
        comparisonLearningStateProvider.overrideWith(
          (ref) async => ComparisonLearningState.empty(
            ComparisonProfileScope(
              courseId: 'en-fr',
              owner: LearningOwner.guest(),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    addTearDown(() async {
      store.actionGates[FinishLearningActivity]?.complete();
      audio.releaseAll();
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
      await audio.dispose();
    });

    expect(router.state.uri.path, '/home');
    expect(find.byType(CourseMapScreen), findsOneWidget);
    expect(find.text('Start lesson'), findsOneWidget);
    expect(
      find.textContaining('%'),
      findsNothing,
      reason: 'the map must not fabricate a course mastery percentage',
    );

    final planned = find.widgetWithText(ListTile, 'Compare /u/ and /y/');
    if (planned.evaluate().isEmpty) {
      await tester.ensureVisible(find.text('All destinations'));
      await tester.tap(find.text('All destinations'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(
      find.widgetWithText(ListTile, 'Compare /u/ and /y/'),
    );
    await tester.tap(find.widgetWithText(ListTile, 'Compare /u/ and /y/'));
    await tester.pumpAndSettle();
    expect(find.text('Start comparison'), findsOneWidget);
    expect(
      find.text(
        'Demo practice: this authored comparison content has not had qualified French review. It is practice, not an assessment.',
      ),
      findsOneWidget,
    );
    expect(
      router.state.uri.path,
      '/home',
      reason: 'inspection does not navigate',
    );
    expect(
      store.submitted,
      isEmpty,
      reason:
          'inspection and optional practice do not move the ship or write learning',
    );

    await tester.ensureVisible(
      find.widgetWithText(ListTile, 'Hear the difference'),
    );
    await tester.tap(find.widgetWithText(ListTile, 'Hear the difference'));
    await tester.pumpAndSettle();
    final launch = find.text('Start lesson');
    await tester.ensureVisible(launch);
    await tester.tap(launch);
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryLessonScreen), findsOneWidget);
    expect(
      store.submitted.where((command) => command.action is StartLearningRun),
      hasLength(1),
    );

    for (var i = 0; i < frenchUySection.items.length; i++) {
      final item = frenchUySection.items[i];
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      expect(
        audio.requests,
        isNotEmpty,
        reason: 'the real discovery screen requested controlled audio',
      );
      audio.requests.last.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('/${item.expectedSound}/'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          i == frenchUySection.items.length - 1
              ? 'See section explanation'
              : 'Next word',
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Section debrief'), findsOneWidget);
    expect(
      store.committedState.completions,
      isEmpty,
      reason: 'a valid debrief is not durable completion',
    );
    expect(
      store.committedState.history.expand((batch) => batch.attempts),
      hasLength(10),
    );
    final preFinish = CourseCompletionSummary.fromState(
      state: store.committedState,
      registry: LearningRegistry.french(),
    );
    expect(preFinish.discoveryCompleteCount, 0);

    await tester.tap(find.text('Finish section'));
    await tester.pump();
    expect(store.committedState.completions, isEmpty);
    expect(router.state.uri.path, '/course-lesson/en-fr-u-y');
    expect(find.text('Retry saving'), findsNothing);
    final pendingFinish = store.submitted.singleWhere(
      (command) => command.action is FinishLearningActivity,
    );
    store.actionGates[FinishLearningActivity]!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Retry saving'), findsOneWidget);
    expect(store.committedState.completions, isEmpty);
    expect(router.state.uri.path, '/course-lesson/en-fr-u-y');

    store.failingActions.remove(FinishLearningActivity);
    store.actionGates.remove(FinishLearningActivity);
    await tester.tap(find.text('Retry saving'));
    await tester.pumpAndSettle();
    expect(store.submitted.last, same(pendingFinish));
    expect(store.committedState.completions, hasLength(1));
    expect(router.state.uri.path, '/home');
    await tester.pumpAndSettle();
    expect(
      find.text('Available main lessons: 1/2 available complete'),
      findsOneWidget,
    );
    expect(
      find.text('All currently available lessons complete.'),
      findsNothing,
    );
    expect(find.text('Review lesson'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);

    final currentBody = container
        .read(courseMapStateProvider('en-fr-u-y-system'))
        .currentBodyId;
    final destinationDisclosure = find.text('All destinations');
    if (destinationDisclosure.evaluate().isNotEmpty) {
      await tester.ensureVisible(destinationDisclosure);
      await tester.tap(destinationDisclosure);
      await tester.pumpAndSettle();
    }
    final optionalPractice = find.widgetWithText(
      ListTile,
      'Mixed comparison practice',
    );
    expect(optionalPractice, findsOneWidget);
    await tester.ensureVisible(optionalPractice);
    await tester.tap(optionalPractice);
    await tester.pumpAndSettle();
    expect(
      container.read(courseMapStateProvider('en-fr-u-y-system')).currentBodyId,
      currentBody,
      reason:
          'optional practice inspection does not move the committed ship anchor',
    );
    expect(store.committedState.completions, hasLength(1));

    router.go('/course-sentence-hunt/en-fr-sentence-hunt-vowels');
    await container.read(sentenceHuntCatalogueProvider.future);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Keep the observed route output in failure logs: a blocked route must not
    // silently fall back to another lesson or become a launchable activity.
    final routeText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .where((text) => text.isNotEmpty)
        .toList();
    expect(
      find.textContaining('This complete sentence section is unavailable'),
      findsOneWidget,
      reason:
          'actual blocked sentence route ${router.state.uri}: ${routeText.join(' | ')}, known IDs: ${sentenceHuntSectionSpecifications.map((section) => section.id).join(',')}',
    );
    expect(find.text('Retry validation'), findsNothing);
    expect(
      store.submitted.where((command) => command.action is StartLearningRun),
      hasLength(1),
      reason: 'the actual blocked sentence package cannot launch learning',
    );
  });
}

/// Reads the shipped, unmodified production packet through Flutter's loader.
/// Widget tests do not mount the application's asset bundle automatically.
final class _RepositoryAssetBundle extends AssetBundle {
  _RepositoryAssetBundle(this.contents);

  final Map<String, String> contents;

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      Future<String>.value(contents[key]!);

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(contents[key]!));
}
