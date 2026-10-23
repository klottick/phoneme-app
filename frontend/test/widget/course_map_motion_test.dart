import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course_map/course_map_canvas.dart';
import 'package:linguist/src/features/course_map/course_map_motion.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';

void _resumeMotion(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  testWidgets('orbit_is_34_seconds_and_selection_does_not_move_anchor', (
    tester,
  ) async {
    _resumeMotion(tester);
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
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(Duration.zero);
    final canvasOrigin = tester.getTopLeft(find.byType(CourseMapMotion));
    final anchorGlobal = canvasOrigin + anchor;
    final shipFinder = find.byKey(const ValueKey('map-motion-ship'));
    final initial = tester.getCenter(shipFinder);
    final radius = anchorGlobal.dy - initial.dy;
    expect(radius, greaterThan(1));

    await tester.pump(const Duration(milliseconds: 8500));
    final quarterLap = tester.getCenter(shipFinder);
    expect(quarterLap.dx, closeTo(anchorGlobal.dx + radius, 1));
    expect(quarterLap.dy, closeTo(anchorGlobal.dy, 1));

    await tester.pump(const Duration(milliseconds: 8500));
    final halfLap = tester.getCenter(shipFinder);
    expect(halfLap.dx, closeTo(anchorGlobal.dx, 1));
    expect(halfLap.dy, closeTo(anchorGlobal.dy + radius, 1));

    await tester.pump(const Duration(seconds: 17));
    final fullLap = tester.getCenter(shipFinder);
    expect((fullLap - initial).distance, lessThan(1));
    expect(find.bySemanticsLabel('Pause map motion'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Current location: Discovery, stationary'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Pause map motion'));
    await tester.pump();
    expect(find.bySemanticsLabel('Play map motion'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Play map motion'));
    await tester.pump();
    final resumed = tester.getCenter(shipFinder);
    expect((resumed - fullLap).distance, lessThan(1));
    await tester.pump(const Duration(seconds: 3));
    expect((tester.getCenter(shipFinder) - resumed).distance, greaterThan(1));

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

  testWidgets(
    'mounted_offstage_motion_stops_and_resumes_without_elapsed_catchup',
    (tester) async {
      _resumeMotion(tester);
      var offstage = false;
      const motionKey = ValueKey('retained-motion');
      Widget host() => MaterialApp(
        home: TickerMode(
          enabled: !offstage,
          child: Offstage(
            offstage: offstage,
            child: const CourseMapMotion(
              key: motionKey,
              anchor: Offset(120, 120),
              child: SizedBox(width: 240, height: 240),
            ),
          ),
        ),
      );

      await tester.pumpWidget(host());
      await tester.pump(const Duration(seconds: 2));
      final ship = find.byKey(
        const ValueKey('map-motion-ship'),
        skipOffstage: false,
      );

      offstage = true;
      await tester.pumpWidget(host());
      await tester.pump();
      final hiddenPosition = tester.getCenter(ship);
      await tester.pump(const Duration(seconds: 8));
      expect(tester.getCenter(ship), hiddenPosition);
      expect(find.byKey(motionKey, skipOffstage: false), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);

      offstage = false;
      await tester.pumpWidget(host());
      await tester.pump();
      expect(tester.getCenter(ship), hiddenPosition);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getCenter(ship), isNot(hiddenPosition));

      offstage = true;
      await tester.pumpWidget(host());
      await tester.pump();
      final initiallyHidden = tester.getCenter(ship);
      await tester.pump(const Duration(seconds: 4));
      expect(tester.getCenter(ship), initiallyHidden);
      offstage = false;
      await tester.pumpWidget(host());
      await tester.pump();
      expect(tester.getCenter(ship), initiallyHidden);
    },
  );

  testWidgets('initially_offstage_motion_stays_stopped_until_visible', (
    tester,
  ) async {
    _resumeMotion(tester);
    var offstage = true;
    const motionKey = ValueKey('initially-offstage-motion');
    Widget host() => MaterialApp(
      home: TickerMode(
        enabled: !offstage,
        child: Offstage(
          offstage: offstage,
          child: const CourseMapMotion(
            key: motionKey,
            anchor: Offset(120, 120),
            child: SizedBox(width: 240, height: 240),
          ),
        ),
      ),
    );

    await tester.pumpWidget(host());
    final ship = find.byKey(
      const ValueKey('map-motion-ship'),
      skipOffstage: false,
    );
    final hiddenPosition = tester.getCenter(ship);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.getCenter(ship), hiddenPosition);
    expect(tester.binding.transientCallbackCount, 0);

    offstage = false;
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byKey(motionKey), findsOneWidget);
    expect(tester.getCenter(ship), hiddenPosition);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getCenter(ship), isNot(hiddenPosition));
  });

  testWidgets('pause_and_each_platform_motion_flag_stop_frames', (
    tester,
  ) async {
    _resumeMotion(tester);
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
    _resumeMotion(tester);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        home: const Scaffold(
          body: CourseMapMotion(
            anchor: Offset(100, 100),
            child: SizedBox(width: 200, height: 200),
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
        home: const Scaffold(
          body: CourseMapMotion(
            anchor: Offset(100, 100),
            child: SizedBox(width: 200, height: 200),
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
              anchor: Offset(100, 100),
              child: SizedBox(width: 200, height: 200),
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
            anchor: Offset(100, 100),
            child: SizedBox(width: 200, height: 200),
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
