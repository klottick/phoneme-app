import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course_map/course_map_canvas.dart';
import 'package:linguist/src/features/course_map/course_map_motion.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';

CourseMapState _state() => CourseMapState(
  systemId: frenchUySystemId,
  bodies: frenchSpaceSystems.first.bodies
      .map(
        (definition) => MapBodyState(
          definition: definition,
          readiness: definition.planned
              ? MapReadiness.planned
              : MapReadiness.alpha,
          progress: MapProgress.notStarted,
          recommended: definition.id == 'comparison',
          explanation: definition.description,
          launch: definition.planned ? null : MapLaunch.start,
        ),
      )
      .toList(),
  currentBodyId: 'discovery',
  allAvailableMainComplete: false,
  completedLegacyLessonIds: null,
);

void main() {
  testWidgets('interim_map_decoration_has_no_pause_control_or_endless_ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 240,
            child: CourseMapMotion(
              anchor: Offset(120, 120),
              child: ColoredBox(
                key: ValueKey('motion-child'),
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
    final child = find.byKey(const ValueKey('motion-child'));
    final initialPosition = tester.getTopLeft(child);
    expect(child, findsOneWidget);
    expect(find.byKey(const ValueKey('map-motion-toggle')), findsNothing);

    await tester.pump(const Duration(seconds: 90));
    expect(tester.getTopLeft(child), initialPosition);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('selection_never_moves_the_current_location_marker', (
    tester,
  ) async {
    final state = _state();
    final inspected = <String>[];

    Future<void> pumpCanvas(String selectedBodyId) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CourseMapCanvas(
              state: state,
              selectedBodyId: selectedBodyId,
              onInspect: inspected.add,
            ),
          ),
        ),
      );
    }

    await pumpCanvas('discovery');
    final currentTarget = find.byKey(
      const ValueKey('destination-semantics-discovery'),
    );
    final marker = find.byIcon(Icons.navigation);
    final targetCenter = tester.getRect(currentTarget).center;
    final markerCenter = tester.getRect(marker).center;
    expect((targetCenter - markerCenter).distance, lessThan(40));
    final initialMarker = tester.getRect(marker);

    await tester.pump(const Duration(seconds: 90));
    expect(tester.getRect(marker), initialMarker);
    expect(tester.binding.transientCallbackCount, 0);

    await tester.tap(find.byKey(const ValueKey('body-art-frame-comparison')));
    await tester.pump();
    expect(inspected, contains('comparison'));
    expect(state.currentBodyId, 'discovery');
    expect(tester.getRect(marker), initialMarker);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('selected_destination_gets_a_finite_visible_ship_flight', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_MotionCanvasHarnessState>();
    await tester.pumpWidget(_MotionCanvasHarness(key: harnessKey));
    await tester.pump();

    final ship = find.byKey(const ValueKey('course-map-preview-ship'));
    expect(ship, findsOneWidget);
    final start = tester.getCenter(ship);
    final origin = tester.getCenter(
      find.byKey(const ValueKey('body-art-frame-discovery')),
    );
    final destination = tester.getCenter(
      find.byKey(const ValueKey('body-art-frame-comparison')),
    );
    final marker = find.byIcon(Icons.navigation);
    final truthfulMarkerBefore = tester.getRect(marker);

    expect((start - origin).distance, lessThan(2));
    expect((destination - start).distance, greaterThan(80));

    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    final midFlight = tester.getCenter(ship);
    expect((midFlight - start).distance, greaterThan(20));
    expect((destination - midFlight).distance, greaterThan(20));

    await tester.pump(const Duration(seconds: 2));
    expect(tester.getCenter(ship), destination);
    expect(tester.getRect(marker), truthfulMarkerBefore);
    expect(tester.binding.transientCallbackCount, 0);

    final semantics = tester.ensureSemantics();
    final mapSemantics = tester.getSemantics(find.byType(CourseMapCanvas));
    expect(_semanticsLabels(mapSemantics), isNot(contains('Preview ship')));
    semantics.dispose();

    await tester.tap(find.byKey(const ValueKey('body-art-frame-comparison')));
    await tester.pump();
    expect(harnessKey.currentState!.inspected, contains('comparison'));
  });

  testWidgets('rapid_selection_retargets_from_the_rendered_ship_position', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_MotionCanvasHarnessState>();
    await tester.pumpWidget(_MotionCanvasHarness(key: harnessKey));
    final ship = find.byKey(const ValueKey('course-map-preview-ship'));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 250));
    final firstRenderedPosition = tester.getCenter(ship);
    harnessKey.currentState!.select('context');
    await tester.pump();
    expect(
      (tester.getCenter(ship) - firstRenderedPosition).distance,
      lessThan(1),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final secondRenderedPosition = tester.getCenter(ship);
    expect(
      (secondRenderedPosition - firstRenderedPosition).distance,
      greaterThan(8),
    );
    harnessKey.currentState!.select('spelling');
    await tester.pump();
    await tester.pump();
    expect(
      (tester.getCenter(ship) - secondRenderedPosition).distance,
      lessThan(1),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(ship),
      tester.getCenter(find.byKey(const ValueKey('body-art-frame-spelling'))),
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced_motion_snaps_initial_and_live_flights_to_stable', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_MotionCanvasHarnessState>();
    await tester.pumpWidget(
      _MotionCanvasHarness(key: harnessKey, reduced: true),
    );
    final ship = find.byKey(const ValueKey('course-map-preview-ship'));
    final destination = tester.getCenter(
      find.byKey(const ValueKey('body-art-frame-comparison')),
    );

    expect(tester.getCenter(ship), destination);
    expect(tester.binding.transientCallbackCount, 0);

    harnessKey.currentState!.setReducedMotion(false);
    await tester.pump();
    harnessKey.currentState!.select('context');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final movingPosition = tester.getCenter(ship);
    expect(
      (movingPosition -
              tester.getCenter(
                find.byKey(const ValueKey('body-art-frame-comparison')),
              ))
          .distance,
      greaterThan(10),
    );

    harnessKey.currentState!.setReducedMotion(true);
    await tester.pump();
    expect(
      tester.getCenter(ship),
      tester.getCenter(find.byKey(const ValueKey('body-art-frame-context'))),
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('ticker_suspension_freezes_and_resumes_without_catching_up', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_MotionCanvasHarnessState>();
    await tester.pumpWidget(_MotionCanvasHarness(key: harnessKey));
    final ship = find.byKey(const ValueKey('course-map-preview-ship'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final suspendedPosition = tester.getCenter(ship);

    harnessKey.currentState!.setTickerMode(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getCenter(ship), suspendedPosition);
    expect(tester.binding.transientCallbackCount, 0);

    harnessKey.currentState!.setTickerMode(true);
    await tester.pump();
    expect(tester.getCenter(ship), suspendedPosition);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(
      (tester.getCenter(ship) - suspendedPosition).distance,
      greaterThan(8),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(ship),
      tester.getCenter(find.byKey(const ValueKey('body-art-frame-comparison'))),
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'backgrounding_suspends_flight_and_resume_starts_from_frozen_position',
    (tester) async {
      final harnessKey = GlobalKey<_MotionCanvasHarnessState>();
      await tester.pumpWidget(_MotionCanvasHarness(key: harnessKey));
      final ship = find.byKey(const ValueKey('course-map-preview-ship'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      final suspendedPosition = tester.getCenter(ship);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getCenter(ship), suspendedPosition);
      expect(tester.binding.transientCallbackCount, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.getCenter(ship), suspendedPosition);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        (tester.getCenter(ship) - suspendedPosition).distance,
        greaterThan(8),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}

String _semanticsLabels(SemanticsNode node) {
  final labels = StringBuffer(node.label);
  node.visitChildren((child) {
    labels.write(_semanticsLabels(child));
    return true;
  });
  return labels.toString();
}

class _MotionCanvasHarness extends StatefulWidget {
  const _MotionCanvasHarness({super.key, this.reduced = false});

  final bool reduced;

  @override
  State<_MotionCanvasHarness> createState() => _MotionCanvasHarnessState();
}

class _MotionCanvasHarnessState extends State<_MotionCanvasHarness> {
  String selectedBodyId = 'comparison';
  bool reduced = false;
  bool tickerEnabled = true;
  final List<String> inspected = <String>[];

  @override
  void initState() {
    super.initState();
    reduced = widget.reduced;
  }

  void select(String id) => setState(() => selectedBodyId = id);

  void setReducedMotion(bool value) => setState(() => reduced = value);

  void setTickerMode(bool value) => setState(() => tickerEnabled = value);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: TickerMode(
          enabled: tickerEnabled,
          child: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              disableAnimations: reduced,
            ),
            child: SizedBox(
              width: 390,
              height: 420,
              child: CourseMapCanvas(
                state: _state(),
                selectedBodyId: selectedBodyId,
                onInspect: inspected.add,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
