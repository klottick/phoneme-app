import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course_map/course_map_catalogue.dart';
import 'package:linguist/src/features/course_map/course_map_canvas.dart';
import 'package:linguist/src/features/course_map/course_destination_list.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/course_system_view.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';

CourseMapState _state(
  String titleSuffix, {
  bool longTitle = false,
  String? currentBodyId = 'unrecognized-current-body',
}) => CourseMapState(
  systemId: frenchUySystemId,
  bodies: frenchSpaceSystems.first.bodies
      .map(
        (body) => MapBodyState(
          definition: longTitle && body.id == 'discovery'
              ? MapBodyDefinition(
                  id: body.id,
                  title:
                      'Hear the difference with this intentionally long destination name',
                  description: body.description,
                  role: body.role,
                  optional: body.optional,
                  planned: body.planned,
                  target: body.target,
                  activityId: body.activityId,
                  parentId: body.parentId,
                  prerequisites: body.prerequisites,
                  x: body.x,
                  y: body.y,
                  orbitRadius: body.orbitRadius,
                )
              : body,
          readiness: body.planned ? MapReadiness.planned : MapReadiness.alpha,
          progress: MapProgress.unknown,
          recommended: false,
          explanation: '${body.description} $titleSuffix',
          launch: body.planned ? null : MapLaunch.open,
        ),
      )
      .toList(),
  currentBodyId: currentBodyId,
  allAvailableMainComplete: false,
  completedLegacyLessonIds: null,
);

void main() {
  testWidgets('small_phone_large_text_actions_reachable', (tester) async {
    for (final size in [const Size(390, 844), const Size(360, 640)]) {
      for (final scale in [1.0, 2.0, 3.0]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: CourseSystemView(
                state: _state('A deliberately long destination title'),
                selectedBodyId: 'discovery',
                onInspect: (_) {},
                onLaunch: (_) {},
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$size at scale $scale');
        final picker = find.byKey(const ValueKey('destination-picker'));
        expect(
          picker.hitTestable(),
          findsOneWidget,
          reason: '$size scale $scale',
        );
        expect(tester.getSize(picker).shortestSide, greaterThanOrEqualTo(48));
        final targets = [
          for (final id in frenchSpaceSystems.first.bodies.map(
            (body) => body.id,
          ))
            find.byKey(ValueKey('destination-semantics-$id')),
        ];
        final canvas = tester.getRect(find.byType(CourseMapCanvas));
        final rects = targets.map(tester.getRect).toList();
        expect(rects.length, 10);
        for (var left = 0; left < rects.length; left++) {
          expect(rects[left].width, greaterThanOrEqualTo(47.9));
          expect(rects[left].height, greaterThanOrEqualTo(47.9));
          final body = frenchSpaceSystems.first.bodies[left];
          final authored = Offset(
            body.x * canvas.width,
            body.y * canvas.height,
          );
          expect(
            (rects[left].center - canvas.topLeft - authored).distance,
            lessThanOrEqualTo(32),
            reason: '${body.id} remains near its authored location at $size',
          );
          for (var right = left + 1; right < rects.length; right++) {
            expect(
              rects[left].overlaps(rects[right]),
              isFalse,
              reason:
                  '$size scale $scale targets $left ${rects[left]} and $right ${rects[right]}',
            );
          }
        }
        final launch = find.text('Open destination');
        expect(
          launch.hitTestable(),
          findsOneWidget,
          reason: 'launch reachable at $size scale $scale',
        );
        final launchButton = find.ancestor(
          of: launch,
          matching: find.byType(FilledButton),
        );
        expect(tester.getSize(launchButton).height, greaterThanOrEqualTo(48));

        await tester.tap(picker);
        await tester.pumpAndSettle();
        expect(find.byType(CourseDestinationList), findsOneWidget);
        final pickerHeading = tester.widget<Semantics>(
          find.byKey(const ValueKey('destination-picker-heading')),
        );
        expect(pickerHeading.properties.label, 'Choose a destination');
        expect(pickerHeading.properties.header, isTrue);
        final comparison = find.widgetWithText(ListTile, 'Compare /u/ and /y/');
        final listScrollViewport = tester.getRect(
          find.ancestor(
            of: find.byType(CourseDestinationList),
            matching: find.byType(SingleChildScrollView),
          ),
        );
        if (size == const Size(360, 640) && scale == 3) {
          expect(
            listScrollViewport.height,
            greaterThanOrEqualTo(200),
            reason: 'the large-text title must not starve the destination list',
          );
        }
        await tester.ensureVisible(comparison);
        expect(
          comparison.hitTestable(),
          findsOneWidget,
          reason:
              '$size scale $scale list ${tester.getRect(comparison)} viewport $listScrollViewport',
        );
        await tester.tap(find.byTooltip('Close destinations'));
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('authored_keyboard_and_semantics_order_is_pinned', (
    tester,
  ) async {
    final inspected = <String>[];
    var launches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: _state('long', currentBodyId: 'discovery'),
            selectedBodyId: 'discovery',
            onInspect: inspected.add,
            onLaunch: (_) => launches++,
          ),
        ),
      ),
    );
    const authoredOrder = [
      'discovery',
      'comparison',
      'context',
      'spelling',
      'checkpoint',
      'coaching',
      'review',
      'mixed-comparison',
      'sentence-practice',
      'arcade',
    ];
    for (final id in authoredOrder) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(inspected.last, id);
      expect(launches, 0);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(launches, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(CourseDestinationList), findsOneWidget);

    for (var index = 0; index < authoredOrder.length; index++) {
      final semantics = tester.widget<Semantics>(
        find.byKey(ValueKey('destination-semantics-${authoredOrder[index]}')),
      );
      expect(
        (semantics.properties.sortKey as OrdinalSortKey).order,
        index.toDouble(),
      );
    }
    final actionSemantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('destination-panel-action-semantics')),
    );
    expect((actionSemantics.properties.sortKey as OrdinalSortKey).order, 10);
    expect(inspected, containsAllInOrder(['discovery', 'comparison']));
    final pickerSemantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('destination-picker-semantics')),
    );
    expect((pickerSemantics.properties.sortKey as OrdinalSortKey).order, 11);
  });

  testWidgets('destinations_announce_state_and_role', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: _state('long', currentBodyId: 'discovery'),
            selectedBodyId: 'comparison',
            onInspect: (_) {},
            onLaunch: (_) {},
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel(RegExp('Hear the difference.*planet.*')),
      findsWidgets,
    );
    expect(
      find.bySemanticsLabel(
        'Current location: Hear the difference, stationary',
      ),
      findsOneWidget,
    );
    final currentCue = tester.getRect(find.byIcon(Icons.navigation));
    final currentBody = tester.getRect(
      find.byKey(const ValueKey('destination-semantics-discovery')),
    );
    final selectedBody = tester.getRect(
      find.byKey(const ValueKey('destination-semantics-comparison')),
    );
    expect((currentCue.center - currentBody.center).distance, lessThan(40));
    expect((currentCue.center - selectedBody.center).distance, greaterThan(40));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('destination-semantics-discovery')),
        matching: find.byType(Tooltip),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp('Compare /u/ and /y/.*planet.*Progress unknown'),
      ),
      findsWidgets,
    );
  });

  testWidgets('long_authored_title_is_available_in_explicit_picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: _state('long', longTitle: true),
            selectedBodyId: 'discovery',
            onInspect: (_) {},
            onLaunch: (_) {},
          ),
        ),
      ),
    );
    const title =
        'Hear the difference with this intentionally long destination name';
    expect(
      find.byKey(const ValueKey('destination-semantics-discovery')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('destination-picker')));
    await tester.pumpAndSettle();
    expect(find.text(title), findsWidgets);
    expect(find.widgetWithText(ListTile, title).hitTestable(), findsOneWidget);
  });

  testWidgets('orbital_controls_follow_authored_positions_and_stay_stable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _state('geometry', currentBodyId: 'discovery');

    Future<List<Offset>> renderAndReadCenters() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CourseSystemView(
              state: state,
              selectedBodyId: 'discovery',
              onInspect: (_) {},
              onLaunch: (_) {},
            ),
          ),
        ),
      );
      final canvas = tester.getRect(find.byType(CourseMapCanvas));
      final actual = <Offset>[];
      for (final body in state.bodies) {
        final target = tester.getRect(
          find.byKey(ValueKey('destination-semantics-${body.definition.id}')),
        );
        final center = target.center - canvas.topLeft;
        final authored = Offset(
          body.definition.x * canvas.width,
          body.definition.y * canvas.height,
        );
        expect(
          (center - authored).distance,
          lessThanOrEqualTo(24),
          reason:
              '${body.definition.id} should stay near its authored scene position',
        );
        actual.add(center);
      }
      for (var left = 0; left < actual.length; left++) {
        for (var right = left + 1; right < actual.length; right++) {
          final first = tester.getRect(
            find.byKey(
              ValueKey(
                'destination-semantics-${state.bodies[left].definition.id}',
              ),
            ),
          );
          final second = tester.getRect(
            find.byKey(
              ValueKey(
                'destination-semantics-${state.bodies[right].definition.id}',
              ),
            ),
          );
          expect(first.overlaps(second), isFalse);
        }
      }
      return actual;
    }

    final first = await renderAndReadCenters();
    expect(first.toSet().length, state.bodies.length);
    final second = await renderAndReadCenters();
    expect(second, first);

    final radii = state.bodies
        .map((body) => body.definition.orbitRadius)
        .toSet();
    for (final radius in radii) {
      expect(
        find.byKey(ValueKey('orbit-radius-${radius.toStringAsFixed(2)}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('orbital_scene_height_is_bounded_by_viewport_not_body_count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<double> heightFor(CourseMapState state) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CourseSystemView(
              state: state,
              selectedBodyId: 'discovery',
              onInspect: (_) {},
              onLaunch: (_) {},
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(CourseMapCanvas)).height;
    }

    final full = _state('height');
    final oneBody = CourseMapState(
      systemId: full.systemId,
      bodies: [full.bodies.first],
      currentBodyId: full.currentBodyId,
      allAvailableMainComplete: full.allAvailableMainComplete,
      completedLegacyLessonIds: full.completedLegacyLessonIds,
    );
    final fullHeight = await heightFor(full);
    final oneBodyHeight = await heightFor(oneBody);
    expect(fullHeight, lessThanOrEqualTo(520));
    expect(fullHeight, oneBodyHeight);
  });

  testWidgets('large_text_keeps_map_action_and_explicit_picker_available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(
          body: CourseSystemView(
            state: _state('fallback'),
            selectedBodyId: 'discovery',
            onInspect: (_) {},
            onLaunch: (_) {},
          ),
        ),
      ),
    );
    final canvas = tester.getRect(find.byType(CourseMapCanvas));
    final action = tester.getRect(find.text('Open destination'));
    expect(action.top, greaterThanOrEqualTo(0));
    expect(action.bottom, lessThanOrEqualTo(640));
    expect(canvas.top, greaterThanOrEqualTo(0));
    expect(canvas.bottom, lessThanOrEqualTo(640));
    expect(
      find.byKey(const ValueKey('destination-picker')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('destination-semantics-discovery')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('destination-picker')));
    await tester.pumpAndSettle();
    expect(find.byType(CourseDestinationList), findsOneWidget);
  });

  testWidgets('light_and_dark_controls_use_theme_readable_surfaces', (
    tester,
  ) async {
    for (final theme in [ThemeData.light(), ThemeData.dark()]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: CourseSystemView(
              state: _state('theme'),
              selectedBodyId: 'discovery',
              onInspect: (_) {},
              onLaunch: (_) {},
            ),
          ),
        ),
      );
      final title = tester.element(find.text('Tu or tout? /u/–/y/'));
      final titleStyle = DefaultTextStyle.of(title).style;
      final expectedText = Theme.of(title).colorScheme.onSurface;
      expect(titleStyle.color, expectedText);
      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNull);
      final panelTextFinder = find.descendant(
        of: find.byType(Card).first,
        matching: find.text('Hear the difference'),
      );
      final panelText = tester.element(panelTextFinder);
      final panelColor =
          DefaultTextStyle.of(panelText).style.color ??
          Theme.of(panelText).colorScheme.onSurface;
      final surface = Theme.of(panelText).cardColor;
      expect(_contrast(panelColor, surface), greaterThanOrEqualTo(4.5));
      expect(find.byType(CustomPaint), findsWidgets);
      if (find.byType(ListTile).evaluate().isEmpty) {
        final picker = find.byKey(const ValueKey('destination-picker'));
        await tester.tap(picker);
        await tester.pumpAndSettle();
      }
      final selectedTile = tester.widget<ListTile>(find.byType(ListTile).first);
      final listForeground =
          selectedTile.selectedColor ??
          Theme.of(panelText).colorScheme.onSurface;
      final listSurface =
          selectedTile.selectedTileColor ??
          Theme.of(panelText).colorScheme.surface;
      expect(_contrast(listForeground, listSurface), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('readiness_fades_art_but_keeps_visible_status', (tester) async {
    final bodies = _state('visual').bodies.map((body) {
      if (body.definition.id != 'comparison' &&
          body.definition.id != 'sentence-practice') {
        return body;
      }
      return MapBodyState(
        definition: body.definition,
        readiness: body.definition.id == 'comparison'
            ? MapReadiness.planned
            : MapReadiness.unavailable,
        progress: body.progress,
        recommended: false,
        explanation: body.explanation,
        launch: body.definition.id == 'sentence-practice'
            ? MapLaunch.open
            : null,
      );
    }).toList();
    final state = CourseMapState(
      systemId: frenchUySystemId,
      bodies: bodies,
      currentBodyId: 'discovery',
      allAvailableMainComplete: false,
      completedLegacyLessonIds: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: state,
            selectedBodyId: 'comparison',
            onInspect: (_) {},
            onLaunch: (_) {},
          ),
        ),
      ),
    );
    final plannedArt = tester.widget<Opacity>(
      find.byKey(const ValueKey('body-art-comparison')),
    );
    expect(plannedArt.opacity, lessThan(1));
    expect(find.textContaining('Coming soon'), findsWidgets);
    expect(find.text('Compare /u/ and /y/'), findsWidgets);
    expect(find.byIcon(Icons.schedule), findsWidgets);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: state,
            selectedBodyId: 'sentence-practice',
            onInspect: (_) {},
            onLaunch: (_) {},
          ),
        ),
      ),
    );
    final unavailableArt = tester.widget<Opacity>(
      find.byKey(const ValueKey('body-art-sentence-practice')),
    );
    expect(unavailableArt.opacity, lessThan(plannedArt.opacity));
    expect(find.textContaining('Destination unavailable'), findsOneWidget);
    expect(find.text('Open recovery'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsWidgets);

    final blockedState = CourseMapState(
      systemId: state.systemId,
      bodies: state.bodies
          .map(
            (body) => MapBodyState(
              definition: body.definition,
              readiness: body.definition.id == 'sentence-practice'
                  ? MapReadiness.qualificationBlocked
                  : body.readiness,
              progress: body.progress,
              recommended: body.recommended,
              explanation: body.explanation,
              launch: body.launch,
            ),
          )
          .toList(),
      currentBodyId: state.currentBodyId,
      allAvailableMainComplete: state.allAvailableMainComplete,
      completedLegacyLessonIds: state.completedLegacyLessonIds,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: blockedState,
            selectedBodyId: 'sentence-practice',
            onInspect: (_) {},
            onLaunch: (_) {},
          ),
        ),
      ),
    );
    final blockedArt = tester.widget<Opacity>(
      find.byKey(const ValueKey('body-art-sentence-practice')),
    );
    expect(blockedArt.opacity, lessThan(1));
    expect(find.textContaining('Qualification required'), findsOneWidget);
    expect(find.text('View sections'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsWidgets);
  });
}

double _contrast(Color foreground, Color background) {
  final light = foreground.computeLuminance();
  final dark = background.computeLuminance();
  return (light > dark ? light + .05 : dark + .05) /
      (light > dark ? dark + .05 : light + .05);
}
