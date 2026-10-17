import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/features/course/course_lesson_screen.dart';
import 'package:linguist/src/features/course/course_completion_summary.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/features/course/course_progress_screen.dart';
import 'package:linguist/src/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/controlled_listening_audio.dart';
import '../support/course_learning_widget_store.dart';

final _activeStoreProvider = StateProvider<CourseLearningWidgetStore>(
    (ref) => CourseLearningWidgetStore());
final _emptyComparisonStateOverride =
    comparisonLearningStateProvider.overrideWith((ref) async =>
        ComparisonLearningState.empty(ComparisonProfileScope(
            courseId: 'en-fr', owner: LearningOwner.guest())));

Future<ProviderContainer> _mountApp(WidgetTester tester,
    CourseLearningWidgetStore store, ControlledListeningAudio audio) async {
  await tester.pumpWidget(ProviderScope(overrides: [
    courseLearningStoreProvider.overrideWithValue(store),
    courseAudioProvider.overrideWithValue(audio),
    _emptyComparisonStateOverride,
  ], child: const LinguistApp()));
  final scope = tester
      .element(find.byType(LinguistApp))
      .getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>()!
      .widget as UncontrolledProviderScope;
  return scope.container;
}

Future<(ProviderContainer, GoRouter, ControlledListeningAudio)> mountApp(
    WidgetTester tester, CourseLearningWidgetStore store) async {
  final audio = ControlledListeningAudio();
  final container = await _mountApp(tester, store, audio);
  return (container, container.read(appRouterProvider), audio);
}

Future<void> unmountApp(WidgetTester tester,
    (ProviderContainer, GoRouter, ControlledListeningAudio) app) async {
  app.$3.releaseAll();
  await tester.pumpWidget(const SizedBox());
  app.$2.dispose();
  app.$1.dispose();
  await app.$3.dispose();
}

void main() {
  setUp(() =>
      SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'}));

  testWidgets('home_enters_real_discovery_before_legacy', (tester) async {
    final store = CourseLearningWidgetStore();
    final app = await mountApp(tester, store);
    addTearDown(() => unmountApp(tester, app));

    await tester.pumpAndSettle();
    expect(find.text('Continue discovery'), findsOneWidget);
    await tester.tap(find.text('Continue discovery'));
    await tester.pumpAndSettle();
    expect(find.text('Listening practice'), findsWidgets);
    expect(find.byType(DiscoveryLessonScreen), findsOneWidget);
    expect(find.text('Item 1 of 10'), findsOneWidget);
    expect(find.text(frenchUySection.explanation), findsNothing);
    expect(find.textContaining('Word reference'), findsNothing);
  });

  testWidgets('real_links_preserve_legacy_unknown_and_review_semantics',
      (tester) async {
    final store = CourseLearningWidgetStore();
    final app = await mountApp(tester, store);
    addTearDown(() => unmountApp(tester, app));
    await tester.pumpAndSettle();

    for (final id in [
      'en-fr-vowels',
      'en-fr-nasal',
      'en-fr-r',
      'en-fr-mix',
    ]) {
      app.$2.go('/course-lesson/$id');
      await tester.pumpAndSettle();
      final lesson =
          tester.widget<CourseLessonScreen>(find.byType(CourseLessonScreen));
      expect(lesson.lessonId, id);
      expect(find.text('Listen to French word'), findsOneWidget);
      await tester.tap(find.text('Listen to French word'));
      await tester.pump();
      app.$3.requests.last.complete();
      await tester.pumpAndSettle();
      final definition =
          frenchLessons.firstWhere((candidate) => candidate.id == id);
      final word = wordByText(definition.words.first);
      final expected = definition.sounds.firstWhere(word.contains);
      await tester.tap(find.text('/$expected/').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Record yourself'), 200);
      expect(find.text('Record yourself'), findsOneWidget);
      expect(store.prepareCalls, greaterThan(0));
      expect(store.submitted, isNotEmpty);
    }

    final preparesBeforeUnknown = store.prepareCalls;
    final submitsBeforeUnknown = store.submitted.length;
    app.$2.go('/course-lesson/not-a-lesson');
    await tester.pumpAndSettle();
    expect(find.text('This lesson is unavailable.'), findsOneWidget);
    expect(store.prepareCalls, preparesBeforeUnknown);
    expect(store.submitted, hasLength(submitsBeforeUnknown));

    final preparesBeforePilot = store.prepareCalls;
    app.$2.go('/course-lesson/en-fr-u-y');
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryLessonScreen), findsOneWidget);
    expect(find.text('Item 1 of 10'), findsOneWidget);
    expect(find.text(frenchUySection.explanation), findsNothing);
    expect(store.prepareCalls, preparesBeforePilot + 1);

    store.seedSession(_passedSession('review-route'));
    app.$1.invalidate(courseLearningStateProvider);
    app.$2.go('/home');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue discovery'));
    await tester.pumpAndSettle();
    expect(find.text('Section debrief'), findsOneWidget);
    await tester.tap(find.text('Finish section'));
    await tester.pumpAndSettle();
    expect(store.committedState.completions.length, 1);

    for (final (id, title) in [
      ('en-fr-vowels', 'Keep French vowels steady'),
      ('en-fr-nasal', 'Let vowels resonate'),
      ('en-fr-r', 'Meet the French R'),
      ('en-fr-mix', 'Mix your new sounds'),
    ]) {
      app.$2.go('/home');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(title), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<CourseLessonScreen>(find.byType(CourseLessonScreen))
              .lessonId,
          id);
    }

    app.$2.go('/course-review');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CourseProgressScreen>(find.byType(CourseProgressScreen))
            .review,
        isTrue);
    expect(find.text('Unresolved sounds'), findsOneWidget);
    app.$2.go('/home');
    await tester.pumpAndSettle();
    expect(find.text('Review discovery'), findsOneWidget);
    await tester.tap(find.text('Review discovery'));
    await tester.pumpAndSettle();
    expect(app.$2.state.uri.path, '/course-lesson/en-fr-u-y');
    expect(app.$2.state.uri.queryParameters['review'], 'true');
    expect(
        tester
            .widget<DiscoveryLessonScreen>(find.byType(DiscoveryLessonScreen))
            .review,
        isTrue);
    expect(find.text('Section debrief'), findsOneWidget);
    await tester.tap(find.text('Finish section'));
    await tester.pumpAndSettle();
    expect(store.committedState.completions.length, 1);
  });

  testWidgets('entry_layout_keyboard_and_load_states_are_honest',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() async {
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final loadingStore = CourseLearningWidgetStore()
      ..loadGate = Completer<void>();
    final loadingApp = await mountApp(tester, loadingStore);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Continue discovery'), findsNothing);
    expect(find.text('Review discovery'), findsNothing);
    expect(find.textContaining('Discovery lessons:'), findsNothing);
    loadingStore.loadGate!.complete();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Continue discovery'), 180);
    expect(find.text('Continue discovery'), findsOneWidget);
    final homeMedia =
        tester.widgetList<MediaQuery>(find.byType(MediaQuery)).first;
    expect(homeMedia.data.size, const Size(360, 640));
    expect(homeMedia.data.textScaler.scale(1), 2);
    expect(tester.view.physicalSize, const Size(360, 640));
    expect(
        loadingStore.submitted
            .where((command) => command.action is StartLearningRun),
        isEmpty);

    // Actually keyboard-activate the primary and each legacy destination at
    // the constrained viewport and enlarged text size.
    final primary = find.ancestor(
        of: find.text('Continue discovery'),
        matching: find.byType(FilledButton));
    await _activateUsingKeyboard(tester, primary);
    expect(find.byType(DiscoveryLessonScreen), findsOneWidget);
    expect(
        loadingStore.submitted
            .where((command) => command.action is StartLearningRun),
        hasLength(1));
    loadingApp.$2.go('/home');
    await tester.pumpAndSettle();

    for (final (id, title) in [
      ('en-fr-vowels', 'Keep French vowels steady'),
      ('en-fr-nasal', 'Let vowels resonate'),
      ('en-fr-r', 'Meet the French R'),
      ('en-fr-mix', 'Mix your new sounds'),
    ]) {
      await tester.scrollUntilVisible(find.text(title), 180);
      expect(find.text(title), findsOneWidget);
      final tile =
          find.ancestor(of: find.text(title), matching: find.byType(ListTile));
      await _activateUsingKeyboard(tester, tile);
      expect(
          tester
              .widget<CourseLessonScreen>(find.byType(CourseLessonScreen))
              .lessonId,
          id);
      loadingApp.$2.go('/home');
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);

    await unmountApp(tester, loadingApp);
    final failedStore = CourseLearningWidgetStore()..failLoad = true;
    final failedApp = await mountApp(tester, failedStore);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Retry loading progress'), 180);
    expect(find.text('Retry loading progress'), findsOneWidget);
    expect(find.text('Continue discovery'), findsNothing);
    expect(find.text('Review discovery'), findsNothing);
    expect(find.textContaining('Discovery lessons:'), findsNothing);
    expect(find.textContaining('Existing lessons (includes discovery pilot)'),
        findsNothing);
    expect(
        failedStore.submitted
            .where((command) => command.action is StartLearningRun),
        isEmpty);
    await tester.ensureVisible(find.text('Retry loading progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry loading progress'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Continue discovery'), 180);
    expect(find.text('Continue discovery'), findsOneWidget);
    await unmountApp(tester, failedApp);
  });

  for (final phase in ['first-pass', 'review', 'debrief']) {
    testWidgets('primary discovery entry resumes saved $phase state',
        (tester) async {
      final savedStore = CourseLearningWidgetStore();
      savedStore.seedSession(_savedSession(phase));
      final savedApp = await mountApp(tester, savedStore);
      addTearDown(() => unmountApp(tester, savedApp));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Continue discovery'), 180);
      await tester.tap(find.text('Continue discovery'));
      await tester.pumpAndSettle();
      if (phase == 'first-pass') {
        expect(find.text('Item 2 of 10'), findsOneWidget);
      } else if (phase == 'review') {
        expect(find.textContaining('Review round 2'), findsOneWidget);
      } else {
        expect(find.text('Section debrief'), findsOneWidget);
      }
      expect(savedStore.prepareCalls, 0);
      expect(
          savedStore.submitted
              .where((command) => command.action is StartLearningRun),
          isEmpty);
      expect(savedStore.committedState.history, isEmpty);
    });
  }

  testWidgets('home_counts_only_acknowledged_finish', (tester) async {
    final store = CourseLearningWidgetStore()
      ..actionGates[FinishLearningActivity] = Completer<void>()
      ..failingActions.add(FinishLearningActivity);
    final app = await mountApp(tester, store);
    var homeNavigationCount = 0;
    Uri? lastObservedUri;
    void countHomeNavigation() {
      final currentUri = app.$2.state.uri;
      if (currentUri != lastObservedUri && currentUri.path == '/home') {
        homeNavigationCount++;
      }
      lastObservedUri = currentUri;
    }

    app.$2.routerDelegate.addListener(countHomeNavigation);
    addTearDown(() async {
      app.$2.routerDelegate.removeListener(countHomeNavigation);
      store.actionGates[FinishLearningActivity]?.complete();
      await unmountApp(tester, app);
    });
    await tester.pumpAndSettle();
    homeNavigationCount = 0;
    lastObservedUri = app.$2.state.uri;
    expect(find.text('Continue discovery'), findsOneWidget);
    final startCountBeforeRefresh = store.submitted
        .where((command) => command.action is StartLearningRun)
        .length;
    app.$2.go('/home');
    await tester.pumpAndSettle();
    expect(
        store.submitted
            .where((command) => command.action is StartLearningRun)
            .length,
        startCountBeforeRefresh);

    await tester.tap(find.text('Continue discovery'));
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryLessonScreen), findsOneWidget);
    for (var i = 0; i < frenchUySection.items.length; i++) {
      final item = frenchUySection.items[i];
      expect(find.text('Item ${i + 1} of 10'), findsOneWidget);
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      app.$3.requests.last.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('/${item.expectedSound}/'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(i == frenchUySection.items.length - 1
          ? 'See section explanation'
          : 'Next word'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Section debrief'), findsOneWidget);
    expect(store.committedState.history.expand((batch) => batch.attempts),
        hasLength(10));
    final preFinishSummary = CourseCompletionSummary.fromState(
      state: store.committedState,
      registry: LearningRegistry.french(),
    );
    expect(preFinishSummary.discoveryCompleteCount, 0);
    expect(preFinishSummary.existingComplete, 0);

    final finishButton = find.widgetWithText(FilledButton, 'Finish section');
    final finishCallback = tester.widget<FilledButton>(finishButton).onPressed!;
    finishCallback();
    finishCallback();
    await tester.pump();
    expect(
        store.submitted
            .where((command) => command.action is FinishLearningActivity),
        hasLength(1));
    expect(store.committedState.completions, isEmpty);
    expect(app.$2.state.uri.path, '/course-lesson/en-fr-u-y');
    expect(homeNavigationCount, 0);

    final pendingFinish = store.submitted
        .singleWhere((command) => command.action is FinishLearningActivity);
    store.actionGates[FinishLearningActivity]!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Retry saving'), findsOneWidget);
    expect(store.committedState.completions, isEmpty);
    expect(app.$2.state.uri.path, '/course-lesson/en-fr-u-y');
    expect(homeNavigationCount, 0);

    store.failingActions.remove(FinishLearningActivity);
    store.actionGates.remove(FinishLearningActivity);
    await tester.tap(find.text('Retry saving'));
    await tester.pumpAndSettle();
    expect(store.submitted.last, same(pendingFinish));
    expect(store.committedState.completions, hasLength(1));
    expect(app.$2.state.uri.path, '/home');
    expect(homeNavigationCount, 1);
    await tester.pumpAndSettle();
    expect(find.text('Discovery lessons: 1/1 complete'), findsOneWidget);
    expect(find.text('Review discovery'), findsOneWidget);
    expect(
        store.submitted
            .where((command) => command.action is FinishLearningActivity),
        hasLength(2));
    await tester.pump(const Duration(milliseconds: 50));
    expect(homeNavigationCount, 1);

    app.$2.go('/course-progress');
    await tester.pumpAndSettle();
    expect(find.text('Discovery lessons: 1/1 complete'), findsOneWidget);
    expect(
        find.text('Existing lessons (includes discovery pilot): 1/5 complete'),
        findsOneWidget);
  });

  testWidgets('home account A-B-A replacement never publishes departed state',
      (tester) async {
    final accountA = _storeWithPilotCompletion('account-a');
    final accountBLoad = Completer<void>();
    final accountB = CourseLearningWidgetStore(
      scope: LearningScope(
          courseId: 'en-fr', owner: LearningOwner.account('account-b')),
    )..loadGate = accountBLoad;
    final staleALoad = Completer<void>();
    final accountARefresh = CourseLearningWidgetStore(
      scope: accountA.scope,
      initialState: accountA.committedState,
    )..loadGate = staleALoad;
    final audio = ControlledListeningAudio();
    await tester.pumpWidget(ProviderScope(overrides: [
      _activeStoreProvider.overrideWith((ref) => accountA),
      courseLearningStoreProvider
          .overrideWith((ref) => ref.watch(_activeStoreProvider)),
      courseAudioProvider.overrideWithValue(audio),
      _emptyComparisonStateOverride,
    ], child: const LinguistApp()));
    final scope = tester
        .element(find.byType(LinguistApp))
        .getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>()!
        .widget as UncontrolledProviderScope;
    final container = scope.container;
    final router = container.read(appRouterProvider);
    addTearDown(() async {
      if (!accountBLoad.isCompleted) accountBLoad.complete();
      if (!staleALoad.isCompleted) staleALoad.complete();
      audio.releaseAll();
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
      await audio.dispose();
    });
    await tester.pumpAndSettle();
    expect(find.text('Discovery lessons: 1/1 complete'), findsOneWidget);
    expect(find.text('Review discovery'), findsOneWidget);
    await _expectLegacyCompletionIcon(
        tester, 'Keep French vowels steady', true);
    await _scrollHomeToDiscoverySummary(tester);

    // Replace the store with a same-owner delayed refresh, then change A→B.
    // The watched store provider dependency invalidates course state naturally.
    container.read(_activeStoreProvider.notifier).state = accountARefresh;
    await tester.pump();
    container.read(_activeStoreProvider.notifier).state = accountB;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await _scrollHomeToDiscoverySummary(tester);
    expect(find.text('Discovery lessons: 1/1 complete'), findsNothing);
    expect(find.text('Review discovery'), findsNothing);
    expect(find.text('Continue discovery'), findsNothing);
    await _expectLegacyCompletionIcon(
        tester, 'Keep French vowels steady', false);
    await _scrollHomeToDiscoverySummary(tester);

    accountBLoad.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
    expect(find.text('Continue discovery'), findsOneWidget);
    staleALoad.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await _scrollHomeToDiscoverySummary(tester);
    expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
    expect(find.text('Review discovery'), findsNothing);
    await _expectLegacyCompletionIcon(
        tester, 'Keep French vowels steady', false);
    await _scrollHomeToDiscoverySummary(tester);

    container.read(_activeStoreProvider.notifier).state = accountA;
    await tester.pumpAndSettle();
    await _scrollHomeToDiscoverySummary(tester);
    expect(find.text('Discovery lessons: 1/1 complete'), findsOneWidget);
    expect(find.text('Review discovery'), findsOneWidget);
    await _expectLegacyCompletionIcon(
        tester, 'Keep French vowels steady', true);
  });

  testWidgets('home hides completed state during explicit held refresh',
      (tester) async {
    final initial = _storeWithPilotCompletion('refresh-owner');
    var refresh = Completer<void>();
    var loads = 0;
    initial.loadHandler = (call) async {
      loads = call;
      if (call > 1) await refresh.future;
      return initial.committedState;
    };
    final audio = ControlledListeningAudio();
    await tester.pumpWidget(ProviderScope(overrides: [
      _activeStoreProvider.overrideWith((ref) => initial),
      courseLearningStoreProvider
          .overrideWith((ref) => ref.watch(_activeStoreProvider)),
      courseAudioProvider.overrideWithValue(audio),
      _emptyComparisonStateOverride,
    ], child: const LinguistApp()));
    final scope = tester
        .element(find.byType(LinguistApp))
        .getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>()!
        .widget as UncontrolledProviderScope;
    final container = scope.container;
    final router = container.read(appRouterProvider);
    addTearDown(() async {
      if (!refresh.isCompleted) refresh.complete();
      audio.releaseAll();
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
      await audio.dispose();
    });
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(find.text('Discovery lessons: 1/1 complete'), findsOneWidget);
    expect(find.text('Review discovery'), findsOneWidget);
    await _expectLegacyCompletionIcon(
        tester, 'Keep French vowels steady', true);
    await _scrollHomeToDiscoverySummary(tester);

    container.invalidate(courseLearningStateProvider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(loads, 2);
    await _scrollHomeToDiscoverySummary(tester);
    expect(find.textContaining('Discovery lessons:'), findsNothing);
    expect(find.text('Review discovery'), findsNothing);
    expect(find.text('Continue discovery'), findsNothing);
    await _expectLegacyCompletionIcon(
        tester, 'Keep French vowels steady', false);
    await _scrollHomeToDiscoverySummary(tester);

    refresh.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    router.go('/course-progress');
    await tester.pumpAndSettle();
    expect(find.text('Discovery lessons: 1/1 complete'), findsOneWidget);
    refresh = Completer<void>();
    container.invalidate(courseLearningStateProvider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.textContaining('Discovery lessons:'), findsNothing);
    expect(find.textContaining('Existing lessons (includes discovery pilot)'),
        findsNothing);
  });

  testWidgets('departed discovery save cannot publish after A-B-A',
      (tester) async {
    final scopeA = LearningScope(
        courseId: 'en-fr', owner: LearningOwner.account('answer-owner-a'));
    final accountA = CourseLearningWidgetStore(scope: scopeA)
      ..actionGates[ChooseSound] = Completer<void>()
      ..failingActions.add(ChooseSound);
    final accountBLoad = Completer<void>();
    final accountB = CourseLearningWidgetStore(
      scope: LearningScope(
          courseId: 'en-fr', owner: LearningOwner.account('answer-owner-b')),
    )..loadGate = accountBLoad;
    final replacementA = CourseLearningWidgetStore(
      scope: scopeA,
      initialState: accountA.committedState,
    );
    final audio = ControlledListeningAudio();
    await tester.pumpWidget(ProviderScope(overrides: [
      _activeStoreProvider.overrideWith((ref) => accountA),
      courseLearningStoreProvider
          .overrideWith((ref) => ref.watch(_activeStoreProvider)),
      courseAudioProvider.overrideWithValue(audio),
      _emptyComparisonStateOverride,
    ], child: const LinguistApp()));
    final scope = tester
        .element(find.byType(LinguistApp))
        .getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>()!
        .widget as UncontrolledProviderScope;
    final container = scope.container;
    final router = container.read(appRouterProvider);
    addTearDown(() async {
      if (!accountBLoad.isCompleted) accountBLoad.complete();
      final answerGate = accountA.actionGates[ChooseSound];
      if (answerGate != null && !answerGate.isCompleted) answerGate.complete();
      audio.releaseAll();
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
      await audio.dispose();
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue discovery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    audio.requests.last.complete();
    await tester.pumpAndSettle();
    await tester
        .tap(find.text('/${frenchUySection.items.first.expectedSound}/'));
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Not yet'), findsNothing);
    final departedAnswer = accountA.submitted
        .singleWhere((command) => command.action is ChooseSound);
    expect(departedAnswer.scope, scopeA);

    container.read(_activeStoreProvider.notifier).state = accountB;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Continue discovery'), findsNothing);
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Not yet'), findsNothing);
    container.read(_activeStoreProvider.notifier).state = replacementA;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryLessonScreen), findsOneWidget);
    expect(find.text('Item 1 of 10'), findsOneWidget);
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Not yet'), findsNothing);
    expect(
        replacementA.submitted
            .where((command) => command.action is ChooseSound),
        isEmpty);

    accountA.actionGates[ChooseSound]!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(accountA.submitted.where((command) => command.action is ChooseSound),
        hasLength(1));
    expect(
        replacementA.submitted
            .where((command) => command.action is ChooseSound),
        isEmpty);
    expect(find.text('Retry saving'), findsNothing);
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Not yet'), findsNothing);
    expect(router.state.uri.path, '/course-lesson/en-fr-u-y');
  });
}

Future<void> _scrollHomeToDiscoverySummary(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 1600));
  await tester.pump();
}

Future<void> _expectLegacyCompletionIcon(
    WidgetTester tester, String title, bool completed) async {
  await tester.scrollUntilVisible(find.text(title), 250,
      scrollable: find.byType(Scrollable).first);
  await tester.pump();
  final tile =
      find.ancestor(of: find.text(title), matching: find.byType(ListTile));
  expect(find.descendant(of: tile, matching: find.byIcon(Icons.check)),
      completed ? findsOneWidget : findsNothing);
}

Future<void> _activateUsingKeyboard(WidgetTester tester, Finder control) async {
  final textFinder = find.descendant(of: control, matching: find.byType(Text));
  expect(textFinder, findsWidgets);
  final focusNode =
      Focus.of(tester.element(textFinder.first), createDependency: false);
  var reachedByTab = false;
  for (var i = 0; i < 50 && !reachedByTab; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    reachedByTab = focusNode.hasFocus;
  }
  expect(reachedByTab, isTrue,
      reason: 'the control must be reachable through keyboard traversal');
  expect(focusNode.hasFocus, isTrue);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

CourseLearningWidgetStore _storeWithPilotCompletion(String userId) {
  final scope =
      LearningScope(courseId: 'en-fr', owner: LearningOwner.account(userId));
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
        contentRevision: LearningRegistry.french()
            .require('lesson:en-fr-vowels')
            .contentRevision,
        policyKind: CompletionPolicyKind.legacyOnePass,
        policyRevision: 1,
        thresholdPercent: null,
        committedAt: DateTime.utc(2026, 10, 16),
      ),
      LearningCompletion(
        lessonId: 'en-fr-u-y',
        contentRevision: LearningRegistry.french()
            .require('lesson:en-fr-u-y')
            .contentRevision,
        policyKind: CompletionPolicyKind.discoveryThreshold,
        policyRevision: 1,
        thresholdPercent: 100,
        committedAt: DateTime.utc(2026, 10, 16),
      ),
    ],
    bestScores: const {},
    pending: const [],
  );
  return CourseLearningWidgetStore(scope: scope, initialState: state);
}

LessonSectionSession _savedSession(String phase) {
  final session = LessonSectionSession(
      itemIds: frenchUySection.items.map((item) => item.id).toList(),
      sessionId: 'saved-$phase',
      policy: LessonPolicy());
  if (phase == 'first-pass') {
    session.submit(true);
    session.advance();
  } else if (phase == 'review') {
    const firstPass = [
      true,
      false,
      true,
      true,
      true,
      true,
      true,
      false,
      true,
      true
    ];
    for (final correct in firstPass) {
      session.submit(correct);
      session.advance();
    }
    session.reviewMistakes();
  } else {
    for (var i = 0; i < 10; i++) {
      session.submit(true);
      session.advance();
    }
  }
  return session;
}

LessonSectionSession _passedSession(String sessionId) {
  final session = LessonSectionSession(
      itemIds: frenchUySection.items.map((item) => item.id).toList(),
      sessionId: sessionId);
  for (var i = 0; i < 10; i++) {
    session.submit(true);
    session.advance();
  }
  return session;
}
