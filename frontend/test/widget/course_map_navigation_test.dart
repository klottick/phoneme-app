import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/features/course/comparison_lesson_screen.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt_lesson_screen.dart';
import 'package:linguist/src/features/course_map/course_map_screen.dart';
import 'package:linguist/src/features/course_map/course_map_catalogue.dart';
import 'package:linguist/src/features/course_map/course_map_canvas.dart';
import 'package:linguist/src/features/course_map/course_map_motion.dart';
import 'package:linguist/src/features/course_map/course_map_providers.dart';
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
    await tester.tap(find.byKey(const ValueKey('destination-picker')));
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

  testWidgets('healthy_map_and_primary_action_fit_every_approved_viewport', (
    tester,
  ) async {
    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    for (final size in const [
      Size(1280, 800),
      Size(390, 844),
      Size(360, 640),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      await tester.pump();

      final appBar = tester.getRect(find.byType(AppBar));
      final navigation = tester.getRect(find.byType(NavigationBar));
      final map = tester.getRect(find.byType(CourseMapCanvas));
      final action = tester.getRect(
        find.ancestor(
          of: find.text('Start lesson'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(
        map.top,
        greaterThanOrEqualTo(appBar.bottom),
        reason: '$size map top',
      );
      expect(
        map.bottom,
        lessThanOrEqualTo(navigation.top),
        reason: '$size map bottom',
      );
      expect(
        action.top,
        greaterThanOrEqualTo(appBar.bottom),
        reason: '$size action top',
      );
      expect(
        action.bottom,
        lessThanOrEqualTo(navigation.top),
        reason: '$size action bottom',
      );
      expect(
        find.byKey(const ValueKey('destination-semantics-discovery')),
        findsOneWidget,
        reason: 'active destinations at $size',
      );
      expect(
        find.byTooltip('More learning tools'),
        findsOneWidget,
        reason: 'secondary tools entry at $size',
      );
      expect(find.text('Open discovery recovery'), findsNothing);
      expect(find.text('Legacy practice'), findsNothing);
      expect(tester.takeException(), isNull, reason: '$size layout');
    }

    await tester.tap(find.byTooltip('More learning tools'));
    await _pumpApp(tester);
    expect(find.text('Open discovery recovery'), findsOneWidget);
    expect(find.text('Legacy practice'), findsOneWidget);
    expect(find.text('Start lesson'), findsOneWidget);
    await tester.tap(find.byTooltip('Close tools'));
    await _pumpApp(tester);
  });

  test('routes only validated typed targets', () {
    expect(
      courseMapLocation(MapTarget.discovery, MapLaunch.start),
      '/course-lesson/en-fr-u-y',
    );
    expect(
      courseMapLocation(MapTarget.discovery, MapLaunch.review),
      '/course-lesson/en-fr-u-y?review=true',
    );
    final dedicatedTarget = MapTarget.values
        .where((target) => target.name == 'dedicatedComparison')
        .firstOrNull;
    expect(dedicatedTarget, isNotNull);
    if (dedicatedTarget != null) {
      expect(
        courseMapLocation(dedicatedTarget, MapLaunch.start),
        '/course-comparison/en-fr-u-y-comparison',
      );
      expect(
        courseMapLocation(dedicatedTarget, MapLaunch.resume),
        '/course-comparison/en-fr-u-y-comparison',
      );
      expect(
        courseMapLocation(dedicatedTarget, MapLaunch.review),
        '/course-comparison/en-fr-u-y-comparison?review=true',
      );
      expect(courseMapLocation(dedicatedTarget, MapLaunch.open), isNull);
    }
    expect(
      courseMapLocation(MapTarget.mixedComparison, MapLaunch.open),
      '/course-comparison/en-fr-phoneme-comparison',
    );
    expect(
      courseMapLocation(MapTarget.mixedComparison, MapLaunch.review),
      '/course-comparison/en-fr-phoneme-comparison?review=true',
    );
    expect(
      courseMapLocation(MapTarget.sentenceSections, MapLaunch.open),
      '/course-sentence-hunt',
    );
    expect(courseMapLocation(MapTarget.discovery, MapLaunch.open), isNull);
    expect(courseMapLocation(MapTarget.arcade, MapLaunch.review), isNull);
  });

  testWidgets(
    'system view omits recovery footer and offers destination picker',
    (tester) async {
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
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('destination-picker')), findsOneWidget);
      expect(find.text('Recovery and legacy access'), findsNothing);
      expect(find.byType(SingleChildScrollView), findsNothing);
    },
  );

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

  testWidgets('dedicated_planet_uses_activity_specific_action_labels', (
    tester,
  ) async {
    final target = MapTarget.values
        .where((value) => value.name == 'dedicatedComparison')
        .firstOrNull;
    expect(target, isNotNull);
    if (target == null) return;
    final comparison = frenchSpaceSystems.first.bodies.firstWhere(
      (body) => body.id == 'comparison',
    );
    for (final (launch, label, progress) in const [
      (MapLaunch.start, 'Start comparison', MapProgress.notStarted),
      (MapLaunch.resume, 'Continue comparison', MapProgress.resumable),
      (MapLaunch.review, 'Review comparison', MapProgress.completed),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CourseDestinationPanel(
              body: MapBodyState(
                definition: comparison,
                readiness: MapReadiness.alpha,
                progress: progress,
                recommended: false,
                explanation: comparison.description,
                launch: launch,
              ),
              onLaunch: () {},
            ),
          ),
        ),
      );
      expect(find.text(label), findsOneWidget);
      expect(find.text('Open destination'), findsNothing);
      expect(find.text('Start lesson'), findsNothing);
      expect(find.text('Continue lesson'), findsNothing);
      expect(find.text('Review lesson'), findsNothing);
    }
  });

  testWidgets('alpha_recovery_explanation_is_not_hidden_with_routine_status', (
    tester,
  ) async {
    final discovery = frenchSpaceSystems.first.bodies.firstWhere(
      (body) => body.id == 'discovery',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseDestinationPanel(
            body: MapBodyState(
              definition: discovery,
              readiness: MapReadiness.alpha,
              progress: MapProgress.notStarted,
              recommended: false,
              explanation: 'Start discovery.',
              launch: MapLaunch.start,
            ),
            onLaunch: () {},
          ),
        ),
      ),
    );
    expect(
      find.text('Start discovery.'),
      findsNothing,
      reason: 'the routine progress prompt duplicates the primary action',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseDestinationPanel(
            body: MapBodyState(
              definition: discovery,
              readiness: MapReadiness.alpha,
              progress: MapProgress.unknown,
              recommended: false,
              explanation: 'Saved session needs recovery.',
              launch: null,
            ),
            onLaunch: () {},
          ),
        ),
      ),
    );
    expect(find.text('Saved session needs recovery.'), findsOneWidget);
  });

  testWidgets('integrated_phone_map_fits_without_page_scrolling', (
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
          expect(find.text('Start lesson'), findsOneWidget);
          expect(find.text('Map'), findsWidgets);
          final appBar = tester.getRect(find.byType(AppBar));
          final navigation = tester.getRect(find.byType(NavigationBar));
          final map = tester.getRect(find.byType(CourseMapCanvas));
          final launchButton = find.ancestor(
            of: find.text('Start lesson'),
            matching: find.byType(FilledButton),
          );
          expect(launchButton.hitTestable(), findsOneWidget);
          final launchRect = tester.getRect(launchButton);
          expect(launchRect.top, greaterThanOrEqualTo(appBar.bottom));
          expect(launchRect.bottom, lessThanOrEqualTo(navigation.top));
          expect(map.top, greaterThanOrEqualTo(appBar.bottom));
          expect(map.bottom, lessThanOrEqualTo(navigation.top));
          expect(
            find.ancestor(
              of: find.byType(CourseMapCanvas),
              matching: find.byType(SingleChildScrollView),
            ),
            findsNothing,
            reason: 'the map itself is not inside a scrolling page',
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('destination-picker')))
                .shortestSide,
            greaterThanOrEqualTo(48),
          );
          expect(
            find.byKey(const ValueKey('destination-picker')).hitTestable(),
            findsOneWidget,
          );
          if (scale == 1) {
            expect(
              find
                  .byKey(const ValueKey('destination-semantics-discovery'))
                  .hitTestable(),
              findsOneWidget,
              reason:
                  'map destination at ${width}x$height scale=$scale dpr=$pixelRatio map=$map',
            );
          } else {
            expect(
              find.byKey(const ValueKey('destination-picker')).hitTestable(),
              findsOneWidget,
              reason:
                  'large-text destination picker at ${width}x$height scale=$scale dpr=$pixelRatio map=$map',
            );
          }
          expect(find.text('Open discovery recovery'), findsNothing);
          expect(find.text('Legacy practice'), findsNothing);
          expect(find.byTooltip('Star chart'), findsOneWidget);
          expect(find.byTooltip('Settings'), findsOneWidget);
          expect(tester.takeException(), isNull);
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
          final navigationBar = tester.widget<NavigationBar>(
            find.byType(NavigationBar),
          );
          expect(navigationBar.selectedIndex, 0);
        }
      }
    }
  });

  testWidgets('integrated_phone_targets_are_safe_or_picker_only', (
    tester,
  ) async {
    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    for (final size in const [Size(390, 844), Size(360, 640)]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      for (final scale in const [1.0, 2.0, 3.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pump();

        final canvasFinder = find.byType(CourseMapCanvas);
        final canvas = tester.widget<CourseMapCanvas>(canvasFinder);
        final mapRect = tester.getRect(canvasFinder);
        final bodyIds = canvas.state.bodies
            .map((body) => body.definition.id)
            .toList(growable: false);
        final activeIds = bodyIds
            .where(
              (id) => find
                  .byKey(ValueKey('destination-semantics-$id'))
                  .evaluate()
                  .isNotEmpty,
            )
            .toList(growable: false);

        expect(
          activeIds.isEmpty || activeIds.length == bodyIds.length,
          isTrue,
          reason:
              'all map targets are active together or all are absent at '
              '${size.width}x${size.height}, text=$scale',
        );
        if (activeIds.isNotEmpty) {
          final targetRects = <Rect>[];
          for (final id in activeIds) {
            final target = find.byKey(ValueKey('destination-semantics-$id'));
            expect(
              target.hitTestable(),
              findsOneWidget,
              reason: '$id must be tappable at $size, text=$scale',
            );
            final targetSize = tester.getSize(target);
            final rect = tester.getRect(target);
            expect(targetSize.width, greaterThanOrEqualTo(48), reason: id);
            expect(targetSize.height, greaterThanOrEqualTo(48), reason: id);
            expect(rect.left, greaterThanOrEqualTo(mapRect.left), reason: id);
            expect(rect.top, greaterThanOrEqualTo(mapRect.top), reason: id);
            expect(rect.right, lessThanOrEqualTo(mapRect.right), reason: id);
            expect(rect.bottom, lessThanOrEqualTo(mapRect.bottom), reason: id);
            for (final placed in targetRects) {
              expect(
                placed.overlaps(rect),
                isFalse,
                reason:
                    '$id overlaps another active map target at $size, '
                    'text=$scale',
              );
            }
            targetRects.add(rect);
          }
          for (final id in bodyIds) {
            await tester.tap(find.byKey(ValueKey('destination-semantics-$id')));
            await tester.pump();
            expect(
              tester.widget<CourseMapCanvas>(canvasFinder).selectedBodyId,
              id,
              reason: '$id inspection must work through its map target',
            );
          }
        } else {
          expect(
            find.descendant(of: canvasFinder, matching: find.byType(InkWell)),
            findsNothing,
            reason: 'a cramped decorative map has no focusable tap targets',
          );
          expect(
            find.descendant(
              of: canvasFinder,
              matching: find.byType(FocusTraversalOrder),
            ),
            findsNothing,
            reason: 'decorative bodies are absent from map focus traversal',
          );
          for (final id in bodyIds) {
            expect(
              find.byKey(ValueKey('destination-semantics-$id')),
              findsNothing,
            );
          }
          await tester.tap(find.byKey(const ValueKey('destination-picker')));
          await tester.pumpAndSettle();
          for (final body in canvas.state.bodies) {
            final row = find.widgetWithText(ListTile, body.definition.title);
            await tester.ensureVisible(row);
            expect(
              row.hitTestable(),
              findsOneWidget,
              reason: '${body.definition.id} remains reachable in the picker',
            );
          }
          final lastBody = canvas.state.bodies.last;
          final lastRow = find.widgetWithText(
            ListTile,
            lastBody.definition.title,
          );
          await tester.tap(lastRow);
          await tester.pumpAndSettle();
          expect(
            tester.widget<CourseMapCanvas>(canvasFinder).selectedBodyId,
            lastBody.definition.id,
            reason: 'the picker remains an actionable alternative',
          );
        }
        expect(tester.takeException(), isNull, reason: '$size text=$scale');
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

    await tester.tap(find.byTooltip('More learning tools'));
    await _pumpApp(tester);
    expect(find.text('Open discovery recovery'), findsOneWidget);
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

    if (find.text('Practice tools').evaluate().isEmpty) {
      await tester.tap(find.byTooltip('More learning tools'));
      await _pumpApp(tester);
    }

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
      if (find.text('Practice tools').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('More learning tools'));
        await _pumpApp(tester);
      }
    }
    await tester.tap(find.byTooltip('Close tools'));
    await _pumpApp(tester);
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

  testWidgets('actual_router_covers_static_map_without_background_tickers', (
    tester,
  ) async {
    final app = await _mountMapApp(tester, normalMotion: true);
    addTearDown(() => _unmountMapApp(tester, app));

    expect(find.byType(CourseMapScreen), findsOneWidget);
    expect(find.byType(CourseMapMotion), findsOneWidget);
    expect(find.byKey(const ValueKey('map-motion-toggle')), findsNothing);
    expect(
      find.bySemanticsLabel(
        RegExp('Current location: Hear the difference, stationary'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 90));
    expect(tester.binding.transientCallbackCount, 0);

    app.router.push('/course-lesson/en-fr-u-y');
    await _pumpApp(tester);
    expect(app.router.state.uri.path, '/course-lesson/en-fr-u-y');
    expect(find.byType(CourseMapScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(CourseMapMotion, skipOffstage: false), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);

    app.router.pop();
    await _pumpApp(tester);
    expect(app.router.state.uri.path, '/home');
    expect(find.byType(CourseMapScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('map-motion-toggle')), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);

    app.router.go('/arcade');
    await _pumpApp(tester);
    expect(app.router.state.uri.path, '/arcade');
    expect(find.byType(CourseMapScreen, skipOffstage: false), findsNothing);
    expect(find.byType(CourseMapMotion, skipOffstage: false), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('map_has_no_page_scroll_and_inspection_only_changes_selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));
    final map = find.byType(CourseMapCanvas);
    final mapBeforeDrag = tester.getRect(map);
    await tester.drag(map, const Offset(0, -180));
    await tester.pump();
    expect(tester.getRect(map), mapBeforeDrag);

    final currentBodyId = app.container
        .read(courseMapStateProvider('en-fr-u-y-system'))
        .currentBodyId;
    final comparison = find.byKey(
      const ValueKey('destination-semantics-comparison'),
    );
    expect(comparison.hitTestable(), findsOneWidget);
    await tester.tap(comparison);
    await _pumpApp(tester);

    final canvas = tester.widget<CourseMapCanvas>(map);
    expect(canvas.selectedBodyId, 'comparison');
    expect(canvas.state.currentBodyId, currentBodyId);
    expect(app.router.state.uri.path, '/home');
    expect(app.store.submitted, isEmpty);
    expect(app.audio.requests, isEmpty);
    expect(find.text('Start comparison').hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('map-motion-toggle')), findsNothing);
  });

  testWidgets('large_text_picker_preserves_selection_and_owner_reset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
    );

    final app = await _mountMapApp(tester);
    addTearDown(() => _unmountMapApp(tester, app));
    expect(
      tester.takeException(),
      isNull,
      reason:
          'large text keeps the compact inspector and action from overflowing',
    );
    final mapBefore = tester.getRect(find.byType(CourseMapCanvas));
    final action = find.text('Start lesson');
    expect(action.hitTestable(), findsOneWidget);
    expect(
      find.byKey(const ValueKey('destination-picker')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('map-motion-toggle')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('destination-picker')));
    await _pumpApp(tester);
    final comparison = find.widgetWithText(ListTile, 'Compare /u/ and /y/');
    await tester.ensureVisible(comparison);
    expect(comparison.hitTestable(), findsOneWidget);
    await tester.tap(comparison);
    await _pumpApp(tester);
    expect(find.text('Start comparison').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.byType(CourseMapCanvas)), mapBefore);
    expect(
      app.container
          .read(courseMapStateProvider('en-fr-u-y-system'))
          .currentBodyId,
      'discovery',
    );

    app.container
        .read(learningAuthScopeProvider.notifier)
        .observe(
          owner: LearningOwner.account('responsive-layout-owner'),
          ready: true,
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    final canvas = tester.widget<CourseMapCanvas>(find.byType(CourseMapCanvas));
    expect(canvas.selectedBodyId, 'discovery');
    expect(canvas.selectedBodyId, isNot('comparison'));
    expect(canvas.state.currentBodyId, isNull);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('More learning tools'));
    await _pumpApp(tester);
    final toolsHeading = tester.widget<Semantics>(
      find.byKey(const ValueKey('map-tools-heading')),
    );
    expect(toolsHeading.properties.label, 'More learning tools');
    expect(toolsHeading.properties.header, isTrue);
    final recovery = find.text('Open discovery recovery');
    final toolsViewport = tester.getRect(
      find.ancestor(of: recovery, matching: find.byType(SingleChildScrollView)),
    );
    expect(
      toolsViewport.height,
      greaterThanOrEqualTo(200),
      reason: 'large-text tools title must leave recovery actions usable',
    );
    await tester.ensureVisible(recovery);
    expect(recovery.hitTestable(), findsOneWidget);
  });
}
