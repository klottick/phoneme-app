import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course_map/course_map_canvas.dart';
import 'package:linguist/src/features/course_map/course_map_motion.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';

void main() {
  testWidgets('orbit_is_34_seconds_and_selection_does_not_move_anchor', (
    tester,
  ) async {
    expect(CourseMapMotion.orbitPeriod, const Duration(seconds: 34));
    const anchor = Offset(150, 120);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 240,
            child: CourseMapMotion(
              anchor: anchor,
              child: Semantics(
                label: 'Current location: Discovery, stationary',
                child: ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 8, milliseconds: 500));
    final ship = tester.getCenter(
      find.byKey(const ValueKey('map-motion-ship')),
    );
    expect(
      ship.dx,
      closeTo(
        tester.getTopLeft(find.byType(CourseMapMotion)).dx + anchor.dx,
        3,
      ),
    );
    expect(
      ship.dy,
      lessThan(tester.getTopLeft(find.byType(CourseMapMotion)).dy + anchor.dy),
    );
    expect(find.bySemanticsLabel('Pause map motion'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Current location: Discovery, stationary'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Pause map motion'));
    await tester.pump();
    expect(find.bySemanticsLabel('Play map motion'), findsOneWidget);

    final mapState = CourseMapState(
      systemId: frenchUySystemId,
      bodies: frenchSpaceSystems.first.bodies
          .map(
            (definition) => MapBodyState(
              definition: definition,
              readiness: MapReadiness.alpha,
              progress: MapProgress.unknown,
              recommended: false,
              explanation: '',
              launch: MapLaunch.open,
            ),
          )
          .toList(),
      currentBodyId: 'discovery',
      allAvailableMainComplete: false,
      completedLegacyLessonIds: null,
    );
    Widget canvas(String selected) => MaterialApp(
      home: Scaffold(
        body: CourseMapCanvas(
          state: mapState,
          selectedBodyId: selected,
          onInspect: (_) {},
        ),
      ),
    );
    await tester.pumpWidget(canvas('discovery'));
    await tester.pump(const Duration(seconds: 8, milliseconds: 500));
    final beforeSelection = tester.getCenter(
      find.byKey(const ValueKey('map-motion-ship')),
    );
    await tester.pumpWidget(canvas('comparison'));
    final afterSelection = tester.getCenter(
      find.byKey(const ValueKey('map-motion-ship')),
    );
    expect(afterSelection, beforeSelection);
  });

  testWidgets('pause_and_each_platform_motion_flag_stop_frames', (
    tester,
  ) async {
    final dispatcher = tester.binding.platformDispatcher;
    var ticks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseMapMotion(
            anchor: const Offset(100, 100),
            child: Builder(
              builder: (_) {
                ticks++;
                return const SizedBox(width: 200, height: 200);
              },
            ),
          ),
        ),
      ),
    );
    final initial = tester.getTopLeft(
      find.byKey(const ValueKey('map-motion-ship')),
    );
    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('map-motion-ship'))),
      initial,
    );
    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      reduceMotion: true,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('map-motion-ship'))),
      initial,
    );
    dispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Pause map motion'));
    await tester.pump();
    final paused = tester.getTopLeft(
      find.byKey(const ValueKey('map-motion-ship')),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('map-motion-ship'))),
      paused,
    );
    expect(ticks, lessThan(5));
    addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
  });

  testWidgets('covered_background_offstage_and_disposed_stop_tickers', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        home: Scaffold(
          body: CourseMapMotion(
            anchor: const Offset(100, 100),
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    key.currentState!.push<void>(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('cover'))),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    final shipFinder = find.byKey(
      const ValueKey('map-motion-ship'),
      skipOffstage: false,
    );
    final covered = tester.getTopLeft(shipFinder);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getTopLeft(shipFinder), covered);
    key.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        home: Scaffold(
          body: CourseMapMotion(
            anchor: const Offset(100, 100),
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ),
    );
    showModalBottomSheet<void>(
      context: key.currentContext!,
      builder: (_) => const SizedBox(height: 100),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final modalCovered = tester.getTopLeft(
      find.byKey(const ValueKey('map-motion-ship')),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('map-motion-ship'))),
      modalCovered,
    );
    key.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    final resumed = tester.getTopLeft(
      find.byKey(const ValueKey('map-motion-ship')),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('map-motion-ship'))),
      resumed,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpWidget(
      const MaterialApp(
        home: TickerMode(
          enabled: false,
          child: Scaffold(
            body: CourseMapMotion(
              anchor: const Offset(100, 100),
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      ),
    );
    final disabled = tester.getTopLeft(
      find.byKey(const ValueKey('map-motion-ship')),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('map-motion-ship'))),
      disabled,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Offstage(
          offstage: true,
          child: CourseMapMotion(
            anchor: const Offset(100, 100),
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('animation_does_not_rebuild_learning_state', (tester) async {
    var childBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseMapMotion(
            anchor: const Offset(100, 100),
            child: Builder(
              builder: (_) {
                childBuilds++;
                return const SizedBox(width: 200, height: 200);
              },
            ),
          ),
        ),
      ),
    );
    final builds = childBuilds;
    await tester.pump(const Duration(seconds: 4));
    expect(childBuilds, builds);
  });
}
