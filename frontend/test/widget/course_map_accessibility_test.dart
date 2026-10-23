import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/course_system_view.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';

CourseMapState _state(String titleSuffix) => CourseMapState(
  systemId: frenchUySystemId,
  bodies: frenchSpaceSystems.first.bodies
      .map(
        (body) => MapBodyState(
          definition: body,
          readiness: body.planned ? MapReadiness.planned : MapReadiness.alpha,
          progress: MapProgress.unknown,
          recommended: false,
          explanation: '${body.description} $titleSuffix',
          launch: body.planned ? null : MapLaunch.open,
        ),
      )
      .toList(),
  currentBodyId: 'unrecognized-current-body',
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
        final listButton = find.text('All destinations');
        await tester.ensureVisible(listButton);
        expect(listButton, findsOneWidget, reason: '$size at scale $scale');
        final button = tester.widget<OutlinedButton>(
          find.ancestor(of: listButton, matching: find.byType(OutlinedButton)),
        );
        expect(
          button.style?.minimumSize?.resolve({})?.height ?? 0,
          greaterThanOrEqualTo(48),
        );
        final mapTarget = tester.getSize(find.byType(InkWell).first);
        expect(mapTarget.width, greaterThanOrEqualTo(48));
        expect(mapTarget.height, greaterThanOrEqualTo(48));
        final launch = find.text('Open destination');
        await tester.ensureVisible(launch);
        expect(
          launch,
          findsOneWidget,
          reason: 'launch reachable at $size scale $scale',
        );
      }
    }
  });

  testWidgets('keyboard_inspects_then_launches', (tester) async {
    final inspected = <String>[];
    var launches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: _state('long'),
            selectedBodyId: 'discovery',
            onInspect: inspected.add,
            onLaunch: (_) => launches++,
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(inspected, isNotEmpty);
    expect(launches, 0);
    final launch = find.text('Open destination');
    await tester.ensureVisible(launch);
    await tester.tap(launch);
    expect(launches, 1);
  });

  testWidgets('destinations_announce_state_and_role', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: _state('long'),
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
      find.bySemanticsLabel(RegExp('Current location.*stationary')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Compare /u/ and /y/.*Coming soon')),
      findsWidgets,
    );
  });
}
