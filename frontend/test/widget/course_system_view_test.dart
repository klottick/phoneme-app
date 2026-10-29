import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/course_map_canvas.dart';
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
            launch: body.planned
                ? null
                : body.id == 'comparison'
                ? MapLaunch.start
                : MapLaunch.open,
          ),
        ),
  ],
  currentBodyId: 'discovery',
  allAvailableMainComplete: false,
  completedLegacyLessonIds: null,
);

void main() {
  testWidgets('map_and_primary_action_fit_supported_viewports', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in const [
      Size(1280, 800),
      Size(390, 844),
      Size(360, 640),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_view(_state(), selectedId: 'discovery'));

      final map = tester.getRect(find.byType(CourseMapCanvas));
      final launch = tester.getRect(
        find.ancestor(
          of: find.text('Start lesson'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(map.top, greaterThanOrEqualTo(0), reason: '$size map top');
      expect(
        map.bottom,
        lessThanOrEqualTo(size.height),
        reason: '$size map bottom',
      );
      expect(launch.top, greaterThanOrEqualTo(0), reason: '$size action top');
      expect(
        launch.bottom,
        lessThanOrEqualTo(size.height),
        reason: '$size action bottom',
      );
      expect(
        find.byKey(const ValueKey('destination-semantics-discovery')),
        findsOneWidget,
        reason: 'the normal-size map remains interactive at $size',
      );
      expect(find.byKey(const ValueKey('map-motion-toggle')), findsNothing);
      expect(tester.takeException(), isNull, reason: '$size layout');
    }
  });

  testWidgets('destination_picker_inspects_without_launching', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _state();
    final inspected = <String>[];
    final launched = <MapBodyState>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: state,
            selectedBodyId: 'discovery',
            onInspect: inspected.add,
            onLaunch: launched.add,
          ),
        ),
      ),
    );

    var selectedId = 'discovery';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CourseSystemView(
              state: state,
              selectedBodyId: selectedId,
              onInspect: (id) {
                inspected.add(id);
                setState(() => selectedId = id);
              },
              onLaunch: launched.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('destination-picker')));
    await tester.pumpAndSettle();
    final comparison = find.widgetWithText(ListTile, 'Compare /u/ and /y/');
    expect(comparison.hitTestable(), findsOneWidget);
    await tester.tap(comparison);
    await tester.pumpAndSettle();

    expect(inspected, contains('comparison'));
    expect(launched, isEmpty);
    expect(state.currentBodyId, 'discovery');
    expect(find.text('Start comparison'), findsOneWidget);
  });

  testWidgets(
    'retiring_inspector_action_leaves_keyboard_focus_and_cannot_launch',
    (tester) async {
      final state = _state();
      var selectedId = 'discovery';
      final launched = <MapBodyState>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CourseSystemView(
                state: state,
                selectedBodyId: selectedId,
                onInspect: (id) => setState(() => selectedId = id),
                onLaunch: launched.add,
              ),
            ),
          ),
        ),
      );

      // Use the real map target to replace the inspector while its outgoing
      // button remains painted during AnimatedSwitcher’s exit.
      final comparisonTarget = find.ancestor(
        of: find.byKey(const ValueKey('body-art-frame-comparison')),
        matching: find.byType(InkWell),
      );
      tester.widget<InkWell>(comparisonTarget).onTap!();
      await tester.pump();
      final oldPanel = find.byKey(
        const ValueKey('destination-panel-discovery'),
        skipOffstage: false,
      );
      final currentPanel = find.byKey(
        const ValueKey('destination-panel-comparison'),
        skipOffstage: false,
      );
      expect(oldPanel, findsOneWidget);
      expect(currentPanel, findsOneWidget);

      expect(
        find.text('Start lesson', skipOffstage: false),
        findsOneWidget,
        reason: 'the outgoing action remains painted during the transition',
      );
      expect(
        find.text('Start comparison', skipOffstage: false),
        findsOneWidget,
      );
      tester.binding.focusManager.primaryFocus?.unfocus();
      var retiringActionFocused = false;
      for (var tab = 0; tab < state.bodies.length + 8; tab++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        if (_primaryFocusContainsText(tester, 'Start lesson')) {
          retiringActionFocused = true;
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          break;
        }
      }
      expect(
        launched,
        isEmpty,
        reason: 'keyboard activation cannot launch the retiring destination',
      );
      expect(
        retiringActionFocused,
        isFalse,
        reason: 'keyboard traversal skips the retiring action',
      );

      // The current action stays interactive while both transition children
      // are still painted.
      final currentAction = find.widgetWithText(
        FilledButton,
        'Start comparison',
      );
      expect(currentAction.hitTestable(), findsOneWidget);
      await tester.tap(currentAction);
      expect(launched.map((body) => body.definition.id), ['comparison']);
    },
  );

  testWidgets('picker_selection_matches_the_resolved_inspector_fallback', (
    tester,
  ) async {
    final state = _state();
    await tester.pumpWidget(_view(state, selectedId: null));
    expect(
      tester
          .widget<CourseMapCanvas>(find.byType(CourseMapCanvas))
          .selectedBodyId,
      'discovery',
    );

    await tester.tap(find.byKey(const ValueKey('destination-picker')));
    await tester.pumpAndSettle();
    final discoverySemantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('destination-list-semantics-discovery')),
    );
    expect(
      discoverySemantics.properties.selected,
      isTrue,
      reason: 'the picker must highlight the same fallback body as the map',
    );
    expect(
      tester
          .widget<ListTile>(
            find.widgetWithText(ListTile, 'Hear the difference'),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('dismissed_picker_callbacks_cannot_change_selection', (
    tester,
  ) async {
    final state = _state();
    final inspections = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: state,
            selectedBodyId: 'discovery',
            onInspect: inspections.add,
            onLaunch: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('destination-picker')));
    await tester.pumpAndSettle();
    final staleInspection = tester
        .widget<ListTile>(find.widgetWithText(ListTile, 'Compare /u/ and /y/'))
        .onTap;
    expect(staleInspection, isNotNull);

    await tester.tap(find.byTooltip('Close destinations'));
    await tester.pumpAndSettle();
    staleInspection!();
    await tester.pump();

    expect(inspections, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retained_picker_opener_after_unmount_is_a_noop', (tester) async {
    await tester.pumpWidget(_view(_state(), selectedId: 'discovery'));
    final retainedOpener = tester
        .widget<IconButton>(find.byKey(const ValueKey('destination-picker')))
        .onPressed!;

    await tester.pumpWidget(const SizedBox.shrink());
    retainedOpener();
    await tester.pump();

    expect(find.byType(ModalBarrier), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
    await tester.tap(find.byKey(const ValueKey('destination-picker')));
    await tester.pumpAndSettle();
    final destination = find.text('Compare /u/ and /y/').first;
    await tester.tap(destination);
    expect(inspected, contains('comparison'));
    expect(launched, isEmpty);
    expect(state.currentBodyId, 'discovery');
  });

  testWidgets('planned_and_unavailable_explain_without_play', (tester) async {
    final state = _state();
    final launched = <MapBodyState>[];
    const plannedBodyId = 'context';
    final plannedBody = state.bodies.singleWhere(
      (body) => body.definition.id == plannedBodyId,
    );
    expect(plannedBody.definition.planned, isTrue);
    expect(plannedBody.readiness, MapReadiness.planned);
    expect(plannedBody.launch, isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: state,
            selectedBodyId: plannedBodyId,
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
  required String? selectedId,
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

bool _primaryFocusContainsText(WidgetTester tester, String text) {
  final BuildContext? context =
      tester.binding.focusManager.primaryFocus?.context;
  if (context is! Element) return false;
  var containsText = false;
  void visit(Element element) {
    if (element.widget case final Text widget when widget.data == text) {
      containsText = true;
      return;
    }
    if (!containsText) element.visitChildElements(visit);
  }

  visit(context);
  return containsText;
}
