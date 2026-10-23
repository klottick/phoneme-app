import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/features/course_map/course_system_view.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/course_learning_widget_store.dart';
import '../support/map_motion_test_support.dart';
import '../support/sentence_hunt_fixtures.dart';

class _HeldRetryStore extends CourseLearningWidgetStore {
  _HeldRetryStore({required super.scope}) {
    failLoad = true;
  }

  final entered = Completer<void>();
  final gate = Completer<void>();

  @override
  Future<CourseLearningState> retryLoad() async {
    if (!entered.isCompleted) entered.complete();
    await gate.future;
    failLoad = false;
    return committedState;
  }
}

List<Override> _ownerFixture(LearningAuthTracker tracker) => [
  learningAuthScopeProvider.overrideWith((ref) => tracker),
  courseLearningStoreProvider.overrideWith((ref) {
    final owner = ref.watch(learningAuthScopeProvider).owner;
    return CourseLearningWidgetStore(
      scope: LearningScope(courseId: 'en-fr', owner: owner),
    );
  }),
  courseLearningStateProvider.overrideWith(
    (ref) => ref.watch(courseLearningStoreProvider).load(),
  ),
  comparisonLearningStateProvider.overrideWith((ref) async {
    final owner = ref.watch(learningAuthScopeProvider).owner;
    return ComparisonLearningState.empty(
      ComparisonProfileScope(courseId: 'en-fr', owner: owner),
    );
  }),
  sentenceHuntCatalogueProvider.overrideWith(
    (ref) async => syntheticSentenceCatalogue(),
  ),
  sentenceHuntLearningStateProvider.overrideWith((ref) async {
    final owner = ref.watch(learningAuthScopeProvider).owner;
    return SentenceHuntState.empty(
      SentenceHuntProfileScope(courseId: 'en-fr', owner: owner),
    );
  }),
];

void main() {
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'}),
  );

  testWidgets('guest_A_B_A_resets_inspection_and_feedback', (tester) async {
    disableMapMotion(tester);
    final guest = LearningOwner.guest();
    final tracker = LearningAuthTracker(owner: guest, ready: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _ownerFixture(tracker),
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();

    final view = tester.widget<CourseSystemView>(find.byType(CourseSystemView));
    view.onInspect('review');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CourseSystemView>(find.byType(CourseSystemView))
          .selectedBodyId,
      'review',
    );

    tracker.observe(owner: LearningOwner.account('A'), ready: true);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CourseSystemView>(find.byType(CourseSystemView))
          .selectedBodyId,
      'discovery',
      reason: 'owner replacement clears the prior learner selection',
    );
    tracker.observe(owner: LearningOwner.account('B'), ready: true);
    await tester.pumpAndSettle();
    final secondOwnerView = tester.widget<CourseSystemView>(
      find.byType(CourseSystemView),
    );
    secondOwnerView.onInspect('review');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CourseSystemView>(find.byType(CourseSystemView))
          .selectedBodyId,
      'review',
    );
    tracker.observe(owner: LearningOwner.account('A'), ready: true);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CourseSystemView>(find.byType(CourseSystemView))
          .selectedBodyId,
      'discovery',
      reason: 'returning A after B is a fresh owner generation',
    );
    tracker.observe(owner: guest, ready: true);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CourseSystemView>(find.byType(CourseSystemView))
          .selectedBodyId,
      'discovery',
      reason: 'returning to guest is a new generation, not stale UI state',
    );
    expect(find.text('Progress unknown'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('launch_rechecks_current_owner_and_readiness', (tester) async {
    disableMapMotion(tester);
    final tracker = LearningAuthTracker(
      owner: LearningOwner.guest(),
      ready: true,
    );
    final guestStore = CourseLearningWidgetStore();
    final accountStore = CourseLearningWidgetStore(
      scope: LearningScope(
        courseId: 'en-fr',
        owner: LearningOwner.account('new-owner'),
      ),
    );
    var activeStore = guestStore;
    final epoch = StateProvider<int>((ref) => 0);
    final container = ProviderContainer(
      overrides: [
        ..._ownerFixture(tracker),
        courseLearningStoreProvider.overrideWith((ref) {
          ref.watch(epoch);
          return activeStore;
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();

    final view = tester.widget<CourseSystemView>(find.byType(CourseSystemView));
    final discovery = view.state.bodies.firstWhere(
      (body) => body.definition.id == 'discovery',
    );
    final staleActivation = view.onLaunch;

    guestStore.failLoad = true;
    container.invalidate(courseLearningStateProvider);
    await tester.pumpAndSettle();
    staleActivation(discovery);
    await tester.pumpAndSettle();
    final unavailable = tester
        .widget<CourseSystemView>(find.byType(CourseSystemView))
        .state
        .bodies
        .firstWhere((body) => body.definition.id == 'discovery');
    expect(unavailable.progress, MapProgress.unknown);
    expect(unavailable.launch, isNull);

    activeStore = accountStore;
    tracker.observe(owner: LearningOwner.account('new-owner'), ready: true);
    container.read(epoch.notifier).state++;
    await tester.pumpAndSettle();
    staleActivation(discovery);
    await tester.pumpAndSettle();

    expect(find.text('Listening practice'), findsNothing);
    expect(find.text('Hear the difference'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'retired retry finally cannot clear replacement owner busy state',
    (tester) async {
      disableMapMotion(tester);
      final ownerA = LearningOwner.account('retry-A');
      final ownerB = LearningOwner.account('retry-B');
      final tracker = LearningAuthTracker(owner: ownerA, ready: true);
      final storeA = _HeldRetryStore(
        scope: LearningScope(courseId: 'en-fr', owner: ownerA),
      );
      final storeB = _HeldRetryStore(
        scope: LearningScope(courseId: 'en-fr', owner: ownerB),
      );
      var activeStore = storeA;
      final epoch = StateProvider<int>((ref) => 0);
      final container = ProviderContainer(
        overrides: [
          ..._ownerFixture(tracker),
          courseLearningStoreProvider.overrideWith((ref) {
            ref.watch(epoch);
            return activeStore;
          }),
        ],
      );
      addTearDown(() async {
        if (!storeA.gate.isCompleted) storeA.gate.complete();
        if (!storeB.gate.isCompleted) storeB.gate.complete();
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LinguistApp(),
        ),
      );
      await tester.pumpAndSettle();
      final retry = find.text('Retry loading progress');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      await storeA.entered.future;

      activeStore = storeB;
      tracker.observe(owner: ownerB, ready: true);
      container.read(epoch.notifier).state++;
      await tester.pumpAndSettle();
      final replacementRetry = find.text('Retry loading progress');
      await tester.ensureVisible(replacementRetry);
      await tester.tap(replacementRetry);
      await tester.pump();
      await storeB.entered.future;
      expect(find.text('Retrying…'), findsOneWidget);

      storeA.gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        find.text('Retrying…'),
        findsOneWidget,
        reason: 'A completion must not clear B’s in-flight retry indicator',
      );

      storeB.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Retrying…'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('family_failures_leave_other_bodies_and_recovery_usable', (
    tester,
  ) async {
    disableMapMotion(tester);
    final tracker = LearningAuthTracker(
      owner: LearningOwner.guest(),
      ready: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._ownerFixture(tracker),
          comparisonLearningStateProvider.overrideWith(
            (ref) async => throw StateError('comparison storage unavailable'),
          ),
          sentenceHuntLearningStateProvider.overrideWith(
            (ref) async => throw StateError('sentence storage unavailable'),
          ),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hear the difference'), findsWidgets);
    expect(find.text('Open mixed comparison recovery'), findsOneWidget);
    expect(find.text('View sentence sections'), findsOneWidget);
    expect(find.text('Retry sentence catalogue'), findsOneWidget);
    final disclosure = find.text('All destinations');
    await tester.ensureVisible(disclosure);
    await tester.tap(disclosure);
    await tester.pumpAndSettle();
    final mixedEntry = find.widgetWithText(
      ListTile,
      'Mixed comparison practice',
    );
    await tester.ensureVisible(mixedEntry);
    await tester.tap(mixedEntry);
    await tester.pumpAndSettle();
    final openRecovery = find.text('Open recovery');
    await tester.ensureVisible(openRecovery);
    await tester.tap(openRecovery);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sound comparison practice'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    final sentenceEntry = find.widgetWithText(ListTile, 'Sentence practice');
    await tester.ensureVisible(sentenceEntry);
    await tester.tap(sentenceEntry);
    await tester.pumpAndSettle();
    final sentenceRecovery = find.text('Open recovery');
    await tester.ensureVisible(sentenceRecovery);
    await tester.tap(sentenceRecovery);
    await tester.pumpAndSettle();
    expect(find.text('Sentence sound hunt'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View sentence sections'));
    await tester.tap(find.text('View sentence sections'));
    await tester.pumpAndSettle();
    expect(find.text('Sentence sound hunt'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Practice tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practice tools'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('IPA Explorer'), 220);
    expect(find.text('IPA Explorer'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late_retry_cannot_publish_into_new_owner', (tester) async {
    disableMapMotion(tester);
    final tracker = LearningAuthTracker(
      owner: LearningOwner.guest(),
      ready: true,
    );
    final oldStore = CourseLearningWidgetStore()..failLoad = true;
    final newStore = CourseLearningWidgetStore(
      scope: LearningScope(
        courseId: 'en-fr',
        owner: LearningOwner.account('new-owner'),
      ),
    )..failLoad = true;
    final epoch = StateProvider<int>((ref) => 0);
    final retryGate = Completer<void>();
    oldStore.loadHandler = (call) async {
      if (call == 1) throw StateError('initial profile load failed');
      await retryGate.future;
      return oldStore.committedState;
    };
    var activeStore = oldStore;
    final container = ProviderContainer(
      overrides: [
        ..._ownerFixture(tracker),
        courseLearningStoreProvider.overrideWith((ref) {
          ref.watch(epoch);
          return activeStore;
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry loading progress'), findsOneWidget);
    final failedMap = tester.widget<CourseSystemView>(
      find.byType(CourseSystemView),
    );
    final unknownDiscovery = failedMap.state.bodies.firstWhere(
      (body) => body.definition.id == 'discovery',
    );
    expect(unknownDiscovery.progress, MapProgress.unknown);
    expect(unknownDiscovery.launch, isNull);
    await tester.ensureVisible(find.text('Retry loading progress'));
    await tester.tap(find.text('Retry loading progress'));
    await tester.pump();
    expect(oldStore.retryLoadCalls, 1);

    activeStore = newStore;
    tracker.observe(owner: LearningOwner.account('new-owner'), ready: true);
    container.read(epoch.notifier).state++;
    await tester.pumpAndSettle();
    expect(newStore.loadCalls, greaterThan(0));
    expect(
      find.text('Retry loading progress'),
      findsOneWidget,
      reason: 'the replacement owner retains its own recovery action',
    );
    expect(
      find.text('Retrying…'),
      findsNothing,
      reason:
          'a retired owner retry must not leave busy feedback on its successor',
    );
    final newOwnerLoads = newStore.loadCalls;
    retryGate.complete();
    await tester.pumpAndSettle();
    expect(
      newStore.loadCalls,
      newOwnerLoads,
      reason: 'retired retry completion cannot invalidate new-owner state',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed_finish_does_not_complete_map', (tester) async {
    disableMapMotion(tester);
    final registry = LearningRegistry.french();
    final itemIds = registry
        .require('lesson:en-fr-u-y')
        .items
        .map((item) => item.sessionAlias!)
        .toList(growable: false);
    final session = LessonSectionSession(
      itemIds: itemIds,
      sessionId: 'map-finish-failure',
    );
    for (var i = 0; i < itemIds.length; i++) {
      session.submit(true);
      session.advance();
    }
    final store = CourseLearningWidgetStore()
      ..seedSession(session)
      ..failingActions.add(FinishLearningActivity);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [courseLearningStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Finish section'), findsOneWidget);
    await tester.tap(find.text('Finish section'));
    await tester.pumpAndSettle();
    expect(store.committedState.completions, isEmpty);
    expect(store.submitted.last.action, isA<FinishLearningActivity>());
    expect(find.textContaining('could not be saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
