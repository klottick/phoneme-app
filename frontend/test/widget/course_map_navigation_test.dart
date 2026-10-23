import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/features/course/comparison_lesson_screen.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt_lesson_screen.dart';
import 'package:linguist/src/features/course_map/course_map_screen.dart';
import 'package:linguist/src/features/course_map/course_map_catalogue.dart';
import 'package:linguist/src/features/course_map/course_map_canvas.dart';
import 'package:linguist/src/features/course_map/course_map_motion.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/course_destination_panel.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';
import 'package:linguist/src/features/course_map/course_system_view.dart';
import 'package:linguist/src/routing/app_router.dart';
import 'package:linguist/src/routing/course_map_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/controlled_listening_audio.dart';
import '../support/course_learning_widget_store.dart';
import '../support/map_motion_test_support.dart';
import '../support/sentence_hunt_fixtures.dart';

class _MountedMapApp {
  const _MountedMapApp(this.container, this.router, this.store, this.audio);
  final ProviderContainer container;
  final GoRouter router;
  final CourseLearningWidgetStore store;
  final ControlledListeningAudio audio;
}

Future<_MountedMapApp> _mountMapApp(
  WidgetTester tester, {
  bool normalMotion = false,
}) async {
  if (normalMotion) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  } else {
    disableMapMotion(tester);
  }
  final owner = LearningOwner.guest();
  final store = CourseLearningWidgetStore();
  final audio = ControlledListeningAudio();
  final container = ProviderContainer(
    overrides: [
      courseLearningStoreProvider.overrideWithValue(store),
      courseAudioProvider.overrideWithValue(audio),
      courseReferenceAudioProvider.overrideWithValue(audio),
      learningAuthScopeProvider.overrideWith(
        (ref) => LearningAuthTracker(owner: owner, ready: true),
      ),
      comparisonLearningStateProvider.overrideWith(
        (ref) async => ComparisonLearningState.empty(
          ComparisonProfileScope(courseId: 'en-fr', owner: owner),
        ),
      ),
      sentenceHuntCatalogueProvider.overrideWith(
        (ref) async => syntheticSentenceCatalogue(),
      ),
      sentenceHuntLearningStateProvider.overrideWith(
        (ref) async => SentenceHuntState.empty(
          SentenceHuntProfileScope(courseId: 'en-fr', owner: owner),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const LinguistApp()),
  );
  if (normalMotion) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  } else {
    await tester.pumpAndSettle();
  }
  // Read only after the persisted onboarding owner has selected its final
  // router instance and MaterialApp.router has attached it.
  return _MountedMapApp(
    container,
    container.read(appRouterProvider),
    store,
    audio,
  );
}

Future<void> _unmountMapApp(WidgetTester tester, _MountedMapApp app) async {
  app.audio.releaseAll();
  await tester.pumpWidget(const SizedBox.shrink());
  app.router.dispose();
  app.container.dispose();
  await app.audio.dispose();
}

Future<void> _pumpApp(WidgetTester tester) async {
  // First build the route scheduled by the navigation action, then advance
  // through its finite transition. One delayed frame alone does not advance a
  // transition created during that frame.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _inspectDiscovery(WidgetTester tester) async {
  final tile = find.widgetWithText(ListTile, 'Hear the difference');
  if (tile.evaluate().isEmpty) {
    final disclosure = find.text('All destinations');
    await tester.ensureVisible(disclosure);
    await tester.tap(disclosure);
    await _pumpApp(tester);
  }
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await _pumpApp(tester);
}

void main() {
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'}),
  );

  test('routes only validated typed targets', () {
    expect(
      courseMapLocation(MapTarget.discovery, MapLaunch.start),
      '/course-lesson/en-fr-u-y',
    );
    expect(
      courseMapLocation(MapTarget.discovery, MapLaunch.review),
      '/course-lesson/en-fr-u-y?review=true',
    );
    expect(
      courseMapLocation(MapTarget.mixedComparison, MapLaunch.open),
      '/course-comparison/en-fr-phoneme-comparison',
    );
    expect(
      courseMapLocation(MapTarget.sentenceSections, MapLaunch.open),
      '/course-sentence-hunt',
    );
    expect(courseMapLocation(MapTarget.discovery, MapLaunch.open), isNull);
    expect(courseMapLocation(MapTarget.arcade, MapLaunch.review), isNull);
  });

  testWidgets('system view composes recovery footer in its scroll surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: CourseMapState(
              systemId: 'en-fr-u-y-system',
              bodies: const [],
              currentBodyId: null,
              allAvailableMainComplete: false,
              completedLegacyLessonIds: null,
            ),
            selectedBodyId: null,
            onInspect: (_) {},
            onLaunch: (_) {},
            footer: const Text('Recovery and legacy access'),
          ),
        ),
      ),
    );
    expect(find.text('Recovery and legacy access'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('onboarding_enters_live_map', (tester) async {
    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));

    expect(app.router.state.uri.toString(), '/home');
    expect(find.byType(CourseMapScreen), findsOneWidget);
    expect(find.text('Hear the difference'), findsWidgets);
    expect(app.router.state.uri.path, '/home');
  });

  testWidgets('tabs_do_not_duplicate_roots', (tester) async {
    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));

    // Exercise a real destination tap, then walk every root through the same
    // production router and prove repeated selection never stacks roots.
    await tester.tap(find.text('Review').last, warnIfMissed: false);
    await _pumpApp(tester);
    expect(app.router.state.uri.path, '/course-review');
    for (final (path, destination) in const [
      ('/home', 'Map'),
      ('/course-review', 'Review'),
      ('/arcade', 'Games'),
      ('/course-progress', 'Progress'),
    ]) {
      app.router.go(path);
      await _pumpApp(tester);
      expect(app.router.state.uri.toString(), path);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text(destination).last);
      await _pumpApp(tester);
      expect(app.router.state.uri.toString(), path);
      expect(app.router.canPop(), isFalse);
    }
    app.router.go('/course-progress');
    await _pumpApp(tester);
    expect(app.router.state.uri.toString(), '/course-progress');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      app.router.canPop(),
      isFalse,
      reason: 'reselecting a current root tab must not push another root',
    );
  });

  testWidgets('map_tab_returns_to_home_from_chart', (tester) async {
    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));

    app.router.go('/course-chart');
    await _pumpApp(tester);
    expect(app.router.state.uri.path, '/course-chart');
    await tester.tap(find.text('Map').last);
    await _pumpApp(tester);

    expect(app.router.state.uri.path, '/home');
  });

  testWidgets('map_tab_returns_to_home_from_direct_system', (tester) async {
    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));

    app.router.go('/course-system/en-fr-u-y-system');
    await _pumpApp(tester);
    await tester.tap(find.text('Map').last);
    await _pumpApp(tester);

    expect(app.router.state.uri.path, '/home');
  });

  testWidgets('reselecting_map_on_home_does_not_duplicate_the_root', (
    tester,
  ) async {
    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));

    await tester.tap(find.text('Map').last);
    await _pumpApp(tester);

    expect(app.router.state.uri.toString(), '/home');
    expect(app.router.canPop(), isFalse);
  });

  testWidgets('mixed_comparison_review_action_keeps_its_identity', (
    tester,
  ) async {
    final comparison = frenchSpaceSystems.first.bodies.firstWhere(
      (body) => body.target == MapTarget.mixedComparison,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseDestinationPanel(
            body: MapBodyState(
              definition: comparison,
              readiness: MapReadiness.alpha,
              progress: MapProgress.completed,
              recommended: false,
              explanation: comparison.description,
              launch: MapLaunch.review,
            ),
            onLaunch: () {},
          ),
        ),
      ),
    );

    expect(find.text('Review comparison'), findsOneWidget);
    expect(find.text('Review lesson'), findsNothing);
  });

  testWidgets('integrated_map_footer_and_root_fit_phone_viewport_matrix', (
    tester,
  ) async {
    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    for (final (width, height) in const [(390.0, 844.0), (360.0, 640.0)]) {
      for (final scale in const [1.0, 2.0, 3.0]) {
        for (final pixelRatio in const [1.0, 2.0, 3.0]) {
          tester.view.devicePixelRatio = pixelRatio;
          tester.view.physicalSize = Size(
            width * pixelRatio,
            height * pixelRatio,
          );
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pump();

          expect(find.byType(CourseMapScreen), findsOneWidget);
          expect(find.text('Hear the difference'), findsWidgets);
          expect(find.text('Start lesson'), findsOneWidget);
          expect(find.text('Map'), findsWidgets);
          expect(
            tester.getSize(find.text('Start lesson').first).height,
            greaterThan(0),
          );
          await tester.ensureVisible(find.text('Start lesson'));
          final launchButton = find.ancestor(
            of: find.text('Start lesson'),
            matching: find.byType(FilledButton),
          );
          expect(launchButton.hitTestable(), findsOneWidget);
          expect(tester.getSize(launchButton).height, greaterThanOrEqualTo(48));
          for (final target in [
            ...find
                .byType(IconButton)
                .evaluate()
                .map((element) => element.widget),
            ...find
                .byType(NavigationDestination)
                .evaluate()
                .map((element) => element.widget),
          ]) {
            final targetFinder = find.byWidget(target);
            final size = tester.getSize(targetFinder);
            expect(size.width, greaterThanOrEqualTo(48), reason: '$target');
            expect(size.height, greaterThanOrEqualTo(48), reason: '$target');
          }

          for (final label in const [
            'Open discovery recovery',
            'Open mixed comparison recovery',
            'View sentence sections',
            'Retry mixed comparison catalogue',
            'Retry sentence catalogue',
            'Retry map content registry',
          ]) {
            final control = find.text(label);
            await tester.ensureVisible(control);
            expect(control, findsOneWidget);
            expect(
              control.hitTestable(),
              findsOneWidget,
              reason: '$label at ${width}x$height scale=$scale dpr=$pixelRatio',
            );
          }

          final legacyDisclosure = find.text('Legacy practice');
          await tester.ensureVisible(legacyDisclosure);
          expect(legacyDisclosure.hitTestable(), findsOneWidget);
          if (find.text('Keep French vowels steady').evaluate().isEmpty) {
            await tester.tap(legacyDisclosure);
            await _pumpApp(tester);
          }
          for (final lesson in frenchLessons.where(
            (lesson) => lesson.id != 'en-fr-u-y',
          )) {
            final title = find.text(lesson.title);
            await tester.ensureVisible(title);
            await _pumpApp(tester);
            expect(title.hitTestable(), findsOneWidget, reason: lesson.title);
          }

          final toolsDisclosure = find.text('Practice tools');
          await tester.ensureVisible(toolsDisclosure);
          expect(toolsDisclosure.hitTestable(), findsOneWidget);
          if (find.text('IPA Explorer').evaluate().isEmpty) {
            await tester.tap(toolsDisclosure);
            await _pumpApp(tester);
          }
          for (final label in const [
            'IPA Explorer',
            'Listening Drill',
            'Phoneme ID',
            'Phoneme Test',
            'Audio Compare',
            'Profile',
            'Settings',
          ]) {
            final control = find.text(label);
            await tester.ensureVisible(control);
            expect(
              control.hitTestable(),
              findsOneWidget,
              reason: '$label at ${width}x$height scale=$scale dpr=$pixelRatio',
            );
          }

          final mapTab = find.text('Map').last;
          await tester.ensureVisible(mapTab);
          expect(mapTab.hitTestable(), findsOneWidget);
          final navigationBar = tester.widget<NavigationBar>(
            find.byType(NavigationBar),
          );
          expect(navigationBar.selectedIndex, 0);
        }
      }
    }
  });

  testWidgets('invalid_or_planned_system_has_safe_return', (tester) async {
    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));

    for (final (id, explanation) in const [
      ('en-fr-nasals-system', 'Planned sound system'),
      ('unknown-system', 'This sound system is not available.'),
    ]) {
      app.router.go('/course-system/$id');
      await _pumpApp(tester);
      expect(app.router.state.uri.path, '/course-system/$id');
      expect(find.textContaining(explanation), findsOneWidget);
      await tester.tap(find.text('Return to map'));
      await _pumpApp(tester);
      expect(app.router.state.uri.toString(), '/home');
    }
  });

  testWidgets('mixed_practice_keeps_its_identity', (tester) async {
    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));

    app.router.go('/course-comparison/en-fr-phoneme-comparison');
    await _pumpApp(tester);

    expect(
      app.router.state.uri.toString(),
      '/course-comparison/en-fr-phoneme-comparison',
    );
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    expect(
      tester
          .widget<ComparisonLessonScreen>(find.byType(ComparisonLessonScreen))
          .activityId,
      'en-fr-phoneme-comparison',
    );
    expect(
      find.byType(NavigationBar),
      findsNothing,
      reason: 'practice routes do not receive root tabs',
    );
  });

  testWidgets('all_legacy_tools_remain_reachable', (tester) async {
    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));

    await tester.ensureVisible(find.text('Legacy practice'));
    await tester.tap(find.text('Legacy practice'));
    await _pumpApp(tester);
    final legacyLesson = find.widgetWithText(
      ListTile,
      'Keep French vowels steady',
    );
    await tester.ensureVisible(legacyLesson);
    await _pumpApp(tester);
    await tester.tap(legacyLesson);
    await _pumpApp(tester);
    expect(app.router.state.uri.path, '/course-lesson/en-fr-vowels');
    expect(find.byType(NavigationBar), findsNothing);
    app.router.pop();
    await _pumpApp(tester);

    final tools = find.ancestor(
      of: find.text('Practice tools'),
      matching: find.byType(ExpansionTile),
    );
    await tester.ensureVisible(tools);
    await tester.tap(tools);
    await _pumpApp(tester);

    for (final (label, path) in const [
      ('IPA Explorer', '/ipa'),
      ('Listening Drill', '/drill'),
      ('Phoneme ID', '/phoneme-id'),
      ('Phoneme Test', '/phoneme-test'),
      ('Audio Compare', '/compare'),
      ('Profile', '/profile'),
    ]) {
      final entry = find.widgetWithText(ListTile, label);
      await tester.ensureVisible(entry);
      await _pumpApp(tester);
      await tester.tap(entry);
      await _pumpApp(tester);
      expect(app.router.state.uri.path, path);
      expect(find.byType(NavigationBar), findsNothing);
      app.router.pop();
      await _pumpApp(tester);
    }
    await tester.tap(find.byTooltip('Settings'));
    await _pumpApp(tester);
    expect(app.router.state.uri.path, '/settings');
  });

  testWidgets('direct_targeted_links_keep_validation', (tester) async {
    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));

    app.router.go(
      '/course-comparison/en-fr-phoneme-comparison?review=true&pairId=fr07b-pair-01',
    );
    await _pumpApp(tester);
    expect(
      app.router.state.uri.toString(),
      '/course-comparison/en-fr-phoneme-comparison?review=true&pairId=fr07b-pair-01',
    );
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    expect(
      tester
          .widget<ComparisonLessonScreen>(find.byType(ComparisonLessonScreen))
          .pairId,
      'fr07b-pair-01',
    );

    for (final invalid in [
      '/course-comparison/en-fr-phoneme-comparison?unknown=true',
      '/course-comparison/en-fr-phoneme-comparison?pairId=fr07b-pair-01&pairId=fr07b-pair-02',
      '/course-comparison/not-the-activity',
    ]) {
      app.router.go(invalid);
      await _pumpApp(tester);
      expect(
        find.text('This comparison activity is unavailable.'),
        findsOneWidget,
      );
      expect(find.byType(ComparisonLessonScreen), findsNothing);
    }

    app.router.go(
      '/course-sentence-hunt/${fixtureSectionIds.first}?review=true&itemId=${fixtureItemIds.first[1]}',
    );
    await _pumpApp(tester);
    expect(find.byType(SentenceHuntLessonScreen), findsOneWidget);
    expect(
      app.router.state.uri.queryParameters['itemId'],
      fixtureItemIds.first[1],
    );
    for (final invalid in [
      '/course-sentence-hunt/${fixtureSectionIds.first}?unknown=true',
      '/course-sentence-hunt/${fixtureSectionIds.first}?itemId=${fixtureItemIds.first[0]}&itemId=${fixtureItemIds.first[1]}',
      '/course-sentence-hunt/${fixtureSectionIds.first}?itemId=unknown-item',
    ]) {
      app.router.go(invalid);
      await _pumpApp(tester);
      expect(
        find.text('This sentence-hunt route is unavailable.'),
        findsOneWidget,
      );
      expect(find.byType(SentenceHuntLessonScreen), findsNothing);
    }
  });

  testWidgets('inspection_makes_no_commands', (tester) async {
    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));

    await _inspectDiscovery(tester);
    expect(app.router.state.uri.toString(), '/home');
    expect(app.store.prepareCalls, 0);
    expect(app.store.submitted, isEmpty);
    expect(app.audio.requests, isEmpty);
  });

  testWidgets('actual_router_covers_and_disposes_normal_motion_map', (
    tester,
  ) async {
    final app = await _mountMapApp(tester, normalMotion: true);
    addTearDown(() => _unmountMapApp(tester, app));
    final ship = find.byKey(
      const ValueKey('map-motion-ship'),
      skipOffstage: false,
    );
    expect(ship, findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    final beforeLesson = tester.getCenter(ship);

    app.router.push('/course-lesson/en-fr-u-y');
    await _pumpApp(tester);
    expect(app.router.state.uri.path, '/course-lesson/en-fr-u-y');
    expect(find.byType(CourseMapScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(CourseMapMotion, skipOffstage: false), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.transientCallbackCount, 0);

    app.router.pop();
    await _pumpApp(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(ship, findsOneWidget);
    final resumed = tester.getCenter(ship);
    expect(resumed, isNot(beforeLesson));

    final mapContext = tester.element(find.byType(CourseMapScreen));
    showDialog<void>(
      context: mapContext,
      builder: (context) => AlertDialog(
        title: const Text('Motion cover'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close cover'),
          ),
        ],
      ),
    );
    await _pumpApp(tester);
    final modalCovered = tester.getCenter(ship);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getCenter(ship), modalCovered);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.tap(find.text('Close cover'));
    await _pumpApp(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getCenter(ship), isNot(modalCovered));

    app.router.go('/arcade');
    await _pumpApp(tester);
    expect(app.router.state.uri.path, '/arcade');
    expect(find.byType(CourseMapScreen, skipOffstage: false), findsNothing);
    expect(
      find.byKey(const ValueKey('map-motion-ship'), skipOffstage: false),
      findsNothing,
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'production_home_scroll_stops_offscreen_map_motion_and_resumes_in_place',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(
        () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
      );

      final app = await _mountMapApp(tester, normalMotion: true);
      addTearDown(() => _unmountMapApp(tester, app));
      expect(app.router.state.uri.path, '/home');

      final motion = find.byType(CourseMapMotion);
      final ship = find.byKey(const ValueKey('map-motion-ship'));
      expect(motion, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(TickerMode.valuesOf(tester.element(motion)).enabled, isTrue);

      await tester.ensureVisible(find.text('Open discovery recovery'));
      await tester.pump();
      await tester.pump();

      final scrollViewport = tester.getRect(find.byType(SingleChildScrollView));
      final hiddenMap = tester.getRect(find.byType(CourseMapCanvas));
      expect(
        hiddenMap.intersect(scrollViewport).isEmpty,
        isTrue,
        reason: 'the production map canvas must be outside its scroll viewport',
      );
      expect(TickerMode.valuesOf(tester.element(motion)).enabled, isFalse);
      final hiddenShip = tester.getCenter(ship);
      final hiddenRelative =
          hiddenShip - tester.getTopLeft(find.byType(CourseMapCanvas));

      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getCenter(ship), hiddenShip);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.ensureVisible(ship);
      await tester.pump();
      await tester.pump();
      expect(TickerMode.valuesOf(tester.element(motion)).enabled, isTrue);
      final resumedRelative =
          tester.getCenter(ship) -
          tester.getTopLeft(find.byType(CourseMapCanvas));
      expect((resumedRelative - hiddenRelative).distance, lessThan(0.1));

      await tester.pump(const Duration(milliseconds: 600));
      expect(
        tester.getCenter(ship) -
            tester.getTopLeft(find.byType(CourseMapCanvas)),
        isNot(hiddenRelative),
      );

      await tester.ensureVisible(find.byTooltip('Pause map motion'));
      await tester.pump();
      await tester.tap(find.byTooltip('Pause map motion'));
      await tester.pump();
      expect(find.byTooltip('Play map motion'), findsOneWidget);
      final pausedRelative =
          tester.getCenter(ship) -
          tester.getTopLeft(find.byType(CourseMapCanvas));

      final disclosure = find.text('All destinations');
      await tester.ensureVisible(disclosure);
      await tester.tap(disclosure);
      await tester.pump();
      final comparison = find.widgetWithText(ListTile, 'Compare /u/ and /y/');
      await tester.ensureVisible(comparison);
      await tester.tap(comparison);
      await tester.pump();
      await tester.ensureVisible(find.text('SOUND SYSTEM'));
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Play map motion'), findsOneWidget);
      expect(TickerMode.valuesOf(tester.element(motion)).enabled, isTrue);
      final selectedPausedRelative =
          tester.getCenter(ship) -
          tester.getTopLeft(find.byType(CourseMapCanvas));
      expect((selectedPausedRelative - pausedRelative).distance, lessThan(0.1));

      await tester.ensureVisible(find.text('Open discovery recovery'));
      await tester.pump();
      await tester.pump();
      expect(TickerMode.valuesOf(tester.element(motion)).enabled, isFalse);
      final hiddenPausedShip = tester.getCenter(ship);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getCenter(ship), hiddenPausedShip);

      await tester.ensureVisible(ship);
      await tester.pump();
      await tester.pump();
      expect(TickerMode.valuesOf(tester.element(motion)).enabled, isTrue);
      expect(find.byTooltip('Play map motion'), findsOneWidget);
      final stillPausedRelative =
          tester.getCenter(ship) -
          tester.getTopLeft(find.byType(CourseMapCanvas));
      expect((stillPausedRelative - pausedRelative).distance, lessThan(0.1));

      await tester.ensureVisible(find.byTooltip('Play map motion'));
      await tester.pump();
      await tester.tap(find.byTooltip('Play map motion'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        tester.getCenter(ship) -
            tester.getTopLeft(find.byType(CourseMapCanvas)),
        isNot(stillPausedRelative),
      );
    },
  );

  testWidgets(
    'initial_fallback_below_fold_remeasures_when_viewport_and_text_scale_change',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(
        () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
      );

      final app = await _mountMapApp(tester, normalMotion: true);
      addTearDown(() => _unmountMapApp(tester, app));

      final motion = find.byType(CourseMapMotion);
      final ship = find.byKey(const ValueKey('map-motion-ship'));
      expect(find.byKey(const ValueKey('map-list-fallback')), findsOneWidget);
      expect(motion, findsOneWidget);
      final scrollViewport = tester.getRect(find.byType(SingleChildScrollView));
      final hiddenMap = tester.getRect(find.byType(CourseMapCanvas));
      expect(hiddenMap.intersect(scrollViewport).isEmpty, isTrue);
      expect(TickerMode.valuesOf(tester.element(motion)).enabled, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      final initialShip = tester.getCenter(ship);

      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getCenter(ship), initialShip);
      expect(tester.binding.transientCallbackCount, 0);

      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('map-list-fallback')), findsNothing);
      expect(TickerMode.valuesOf(tester.element(motion)).enabled, isTrue);
      final normalShip = tester.getCenter(ship);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getCenter(ship), isNot(normalShip));

      tester.view.physicalSize = const Size(360, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pump();
      await tester.pump();
      await tester.ensureVisible(find.text('SOUND SYSTEM'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('map-list-fallback')), findsOneWidget);
      final fallbackScrollViewport = tester.getRect(
        find.byType(SingleChildScrollView),
      );
      final fallbackMap = tester.getRect(find.byType(CourseMapCanvas));
      expect(fallbackMap.intersect(fallbackScrollViewport).isEmpty, isTrue);
      expect(TickerMode.valuesOf(tester.element(motion)).enabled, isFalse);
      final resizedFallbackShip = tester.getCenter(ship);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getCenter(ship), resizedFallbackShip);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.ensureVisible(ship);
      await tester.pump();
      await tester.pump();
      expect(TickerMode.valuesOf(tester.element(motion)).enabled, isTrue);
      final resumedShip = tester.getCenter(ship);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getCenter(ship), isNot(resumedShip));
    },
  );
}
