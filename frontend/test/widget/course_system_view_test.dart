import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/course_system_view.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';

CourseMapState _state() => CourseMapState(
  systemId: frenchUySystemId,
  bodies: [
    MapBodyState(
      definition: frenchSpaceSystems.first.bodies.first,
      readiness: MapReadiness.alpha,
      progress: MapProgress.notStarted,
      recommended: true,
      explanation: 'Hear both sounds in real words.',
      launch: MapLaunch.start,
    ),
    ...frenchSpaceSystems.first.bodies
        .skip(1)
        .map(
          (body) => MapBodyState(
            definition: body,
            readiness: body.planned ? MapReadiness.planned : MapReadiness.alpha,
            progress: MapProgress.unknown,
            recommended: false,
            explanation: body.description,
            launch: body.planned ? null : MapLaunch.open,
          ),
        ),
  ],
  currentBodyId: 'discovery',
  allAvailableMainComplete: false,
  completedLegacyLessonIds: null,
);

void main() {
  testWidgets('inspection_is_not_launch_or_travel', (tester) async {
    final state = _state();
    final inspected = <String>[];
    final launched = <MapBodyState>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: state,
            selectedBodyId: null,
            onInspect: inspected.add,
            onLaunch: launched.add,
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('All destinations'));
    await tester.tap(find.text('All destinations'));
    await tester.pumpAndSettle();
    final destination = find.text('Compare /u/ and /y/').first;
    await tester.ensureVisible(destination);
    await tester.tap(destination);
    expect(inspected, contains('comparison'));
    expect(launched, isEmpty);
    expect(state.currentBodyId, 'discovery');
  });

  testWidgets('planned_and_unavailable_explain_without_play', (tester) async {
    final state = _state();
    final launched = <MapBodyState>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: state,
            selectedBodyId: 'comparison',
            onInspect: (_) {},
            onLaunch: launched.add,
          ),
        ),
      ),
    );
    expect(find.textContaining('Coming soon'), findsWidgets);
    expect(find.textContaining('Start'), findsNothing);
    expect(launched, isEmpty);
    final sentence = state.bodies.firstWhere(
      (body) => body.definition.id == 'sentence-practice',
    );
    expect(sentence.launch, MapLaunch.open);
    expect(find.textContaining('View sections'), findsNothing);
  });
}
