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
    final unavailableState = _stateWithReadiness(
      state,
      'sentence-practice',
      MapReadiness.unavailable,
    );
    final unavailableSentence = unavailableState.bodies.firstWhere(
      (body) => body.definition.id == 'sentence-practice',
    );
    await tester.pumpWidget(
      _view(
        unavailableState,
        selectedId: 'sentence-practice',
        launched: launched,
      ),
    );
    expect(find.text('Open recovery'), findsOneWidget);
    await tester.ensureVisible(find.text('Open recovery'));
    await tester.tap(find.text('Open recovery'));
    expect(launched.single.definition.id, unavailableSentence.definition.id);
    expect(launched.single.readiness, MapReadiness.unavailable);

    launched.clear();
    final blockedState = _stateWithReadiness(
      state,
      'sentence-practice',
      MapReadiness.qualificationBlocked,
    );
    final blockedSentence = blockedState.bodies.firstWhere(
      (body) => body.definition.id == 'sentence-practice',
    );
    await tester.pumpWidget(
      _view(blockedState, selectedId: 'sentence-practice', launched: launched),
    );
    expect(find.text('View sections'), findsOneWidget);
    await tester.ensureVisible(find.text('View sections'));
    await tester.tap(find.text('View sections'));
    expect(launched.single.definition.id, blockedSentence.definition.id);
    expect(launched.single.readiness, MapReadiness.qualificationBlocked);
    expect(find.text('Start lesson'), findsNothing);
  });

  testWidgets('authored_system_title_and_current_location_are_truthful', (
    tester,
  ) async {
    final state = _state();
    await tester.pumpWidget(_view(state, selectedId: 'discovery'));
    expect(find.text('Tu or tout? /u/–/y/'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp('Hear the difference.*current location.*stationary'),
      ),
      findsOneWidget,
    );

    final unknown = CourseMapState(
      systemId: state.systemId,
      bodies: state.bodies,
      currentBodyId: 'unknown-id',
      allAvailableMainComplete: false,
      completedLegacyLessonIds: null,
    );
    await tester.pumpWidget(_view(unknown, selectedId: 'discovery'));
    expect(find.text('Current location unknown'), findsOneWidget);
    expect(find.textContaining('stationary ship'), findsNothing);
  });
}

CourseMapState _stateWithReadiness(
  CourseMapState state,
  String id,
  MapReadiness readiness,
) => CourseMapState(
  systemId: state.systemId,
  bodies: state.bodies
      .map(
        (original) => MapBodyState(
          definition: original.definition,
          readiness: original.definition.id == id
              ? readiness
              : original.readiness,
          progress: original.progress,
          recommended: original.recommended,
          explanation: original.explanation,
          launch: original.launch,
        ),
      )
      .toList(),
  currentBodyId: state.currentBodyId,
  allAvailableMainComplete: state.allAvailableMainComplete,
  completedLegacyLessonIds: state.completedLegacyLessonIds,
);

Widget _view(
  CourseMapState state, {
  required String selectedId,
  List<MapBodyState>? launched,
}) => MaterialApp(
  home: Scaffold(
    body: CourseSystemView(
      state: state,
      selectedBodyId: selectedId,
      onInspect: (_) {},
      onLaunch: (body) => launched?.add(body),
    ),
  ),
);
