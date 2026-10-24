import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course_map/course_map_canvas.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';

void main() {
  testWidgets('map bodies and sun render bundled decorative artwork', (
    tester,
  ) async {
    final system = frenchSpaceSystems.first;
    final state = CourseMapState(
      systemId: system.id,
      bodies: system.bodies
          .map(
            (definition) => MapBodyState(
              definition: definition,
              readiness: definition.planned
                  ? MapReadiness.planned
                  : MapReadiness.alpha,
              progress: MapProgress.unknown,
              recommended: false,
              explanation: definition.description,
              launch: definition.planned ? null : MapLaunch.open,
            ),
          )
          .toList(),
      currentBodyId: 'discovery',
      allAvailableMainComplete: false,
      completedLegacyLessonIds: null,
    );

    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CourseMapCanvas(
              state: state,
              selectedBodyId: 'comparison',
              onInspect: (_) {},
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpAt(const Size(800, 900));

    final bodyArtworkPaths = <String>{};
    for (final body in state.bodies) {
      final art = find.byKey(ValueKey('body-art-image-${body.definition.id}'));
      expect(art, findsOneWidget);
      if (body.definition.id != 'arcade') {
        final image = tester.widget<Image>(art);
        final provider = image.image as AssetImage;
        expect(provider.assetName, startsWith('assets/images/course_map/art/'));
        bodyArtworkPaths.add(provider.assetName);
      }
    }
    expect(bodyArtworkPaths, hasLength(state.bodies.length - 1));
    final selectedFrame = tester.widget<Container>(
      find.byKey(const ValueKey('body-art-frame-comparison')),
    );
    expect((selectedFrame.decoration! as BoxDecoration).boxShadow, isNotEmpty);
    final currentFrame = tester.widget<Container>(
      find.byKey(const ValueKey('body-art-frame-discovery')),
    );
    expect((currentFrame.decoration! as BoxDecoration).border, isNotNull);
    expect(find.byKey(const ValueKey('course-map-sun-art')), findsOneWidget);
    expect(
      (tester
                  .widget<Image>(
                    find.byKey(const ValueKey('course-map-sun-art')),
                  )
                  .image
              as AssetImage)
          .assetName,
      'assets/images/course_map/art/sun.png',
    );
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('destination-semantics-discovery')),
      findsOneWidget,
    );

    await pumpAt(const Size(360, 640));
    expect(
      find.byKey(const ValueKey('body-art-image-discovery')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('destination-semantics-discovery')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('course-map-sun-art')), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('body-art-context')))
          .opacity,
      .55,
    );
    expect(find.byIcon(Icons.schedule), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
