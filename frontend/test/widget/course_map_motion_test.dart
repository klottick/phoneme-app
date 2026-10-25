import 'package:flutter/material.dart';
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
}
