import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course_map/course_map_catalogue.dart';
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
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpAt(const Size(800, 900));

    await _verifyRenderedArtwork(tester, state);
    final selectedFrame = tester.widget<Container>(
      find.byKey(const ValueKey('body-art-frame-comparison')),
    );
    expect((selectedFrame.decoration! as BoxDecoration).boxShadow, isNotEmpty);
    final currentFrame = tester.widget<Container>(
      find.byKey(const ValueKey('body-art-frame-discovery')),
    );
    expect((currentFrame.decoration! as BoxDecoration).border, isNotNull);
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('destination-semantics-discovery')),
      findsOneWidget,
    );

    await pumpAt(const Size(360, 640));
    await _verifyRenderedArtwork(tester, state);
    expect(
      find.byKey(const ValueKey('destination-semantics-discovery')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('body-art-context')))
          .opacity,
      .55,
    );
    expect(
      find.byIcon(Icons.schedule),
      findsNWidgets(system.bodies.where((body) => body.planned).length),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sun_art_cannot_intercept_overlapping_destination_targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    final inspected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 336,
              height: 150,
              child: CourseMapCanvas(
                state: state,
                selectedBodyId: 'discovery',
                onInspect: inspected.add,
              ),
            ),
          ),
        ),
      ),
    );

    final canvasRect = tester.getRect(find.byType(CourseMapCanvas));
    expect(canvasRect.size, const Size(336, 150));
    final sunRect = tester.getRect(
      find.byKey(const ValueKey('course-map-sun-art')),
    );
    for (final (id, localPoint) in const <(String, Offset)>[
      ('sentence-practice', Offset(160, 96)),
      ('arcade', Offset(180, 96)),
    ]) {
      final point = canvasRect.topLeft + localPoint;
      final targetRect = tester.getRect(
        find.byKey(ValueKey('destination-semantics-$id')),
      );
      expect(targetRect.contains(point), isTrue, reason: '$id target overlap');
      expect(sunRect.contains(point), isTrue, reason: '$id sun overlap');

      await tester.tapAt(point);
      await tester.pump();
      expect(inspected.lastOrNull, id, reason: '$id must receive the tap');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown body IDs retain a role-appropriate fallback', (
    tester,
  ) async {
    final definition = MapBodyDefinition(
      id: 'unmapped-station',
      title: 'Unmapped station',
      description: 'Test-only renderer fallback.',
      role: MapBodyRole.station,
      optional: true,
      planned: true,
      x: .5,
      y: .5,
      orbitRadius: .3,
    );
    final state = CourseMapState(
      systemId: 'test-system',
      bodies: [
        MapBodyState(
          definition: definition,
          readiness: MapReadiness.planned,
          progress: MapProgress.unknown,
          recommended: false,
          explanation: definition.description,
          launch: null,
        ),
      ],
      currentBodyId: null,
      allAvailableMainComplete: false,
      completedLegacyLessonIds: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseMapCanvas(
            state: state,
            selectedBodyId: null,
            onInspect: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('body-art-image-unmapped-station')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.dns), findsOneWidget);
    expect(find.byKey(const ValueKey('asteroid-image-small-a')), findsNothing);
    expect(find.byKey(const ValueKey('asteroid-image-large')), findsNothing);
    expect(find.byKey(const ValueKey('asteroid-image-small-b')), findsNothing);
  });
}

const _bodyAssets = <String, String>{
  'discovery': 'planet_discovery.png',
  'comparison': 'planet_comparison.png',
  'context': 'planet_context.png',
  'spelling': 'planet_spelling.png',
  'checkpoint': 'planet_checkpoint.png',
  'coaching': 'moon.png',
  'review': 'station_review.png',
  'mixed-comparison': 'station_mixed.png',
  'sentence-practice': 'station_sentences.png',
};

Future<void> _verifyRenderedArtwork(
  WidgetTester tester,
  CourseMapState state,
) async {
  final renderedPaths = tester
      .widgetList<Image>(find.byType(Image))
      .map(_assetPath)
      .toList();
  expect(renderedPaths, hasLength(14));
  expect(
    renderedPaths,
    contains('assets/images/course_map/art/ship_preview.png'),
  );
  final decodedPaths = await tester.runAsync(() async {
    final decoded = <String>[];
    for (final path in renderedPaths) {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
        decoded.add(path);
      } finally {
        codec.dispose();
      }
    }
    return decoded;
  });
  expect(decodedPaths, isNotNull);
  expect(decodedPaths, unorderedEquals(renderedPaths));

  final expectedPaths = <String>[];
  for (final body in state.bodies) {
    if (body.definition.id == 'arcade') {
      final asteroidFinder = find.descendant(
        of: find.byKey(const ValueKey('body-art-image-arcade')),
        matching: find.byType(Image),
      );
      final widgets = tester.widgetList<Image>(asteroidFinder).toList();
      expect(widgets, hasLength(3));
      final paths = widgets.map(_assetPath).toList();
      expect(paths.toSet(), {
        'assets/images/course_map/art/asteroid_small.png',
        'assets/images/course_map/art/asteroid_large.png',
      });
      final rects = [
        tester.getRect(find.byKey(const ValueKey('asteroid-image-small-a'))),
        tester.getRect(find.byKey(const ValueKey('asteroid-image-large'))),
        tester.getRect(find.byKey(const ValueKey('asteroid-image-small-b'))),
      ];
      for (var first = 0; first < rects.length; first++) {
        expect(rects[first].width, lessThanOrEqualTo(21));
        for (var second = first + 1; second < rects.length; second++) {
          expect(
            (rects[first].center - rects[second].center).distance,
            greaterThan(11),
          );
        }
      }
      expectedPaths.addAll(paths);
    } else {
      final id = body.definition.id;
      final image = tester.widget<Image>(
        find.byKey(ValueKey('body-art-image-$id')),
      );
      final path = _assetPath(image);
      expect(
        path,
        'assets/images/course_map/art/${_bodyAssets[id]}',
        reason: '$id is pinned to its unique authored artwork',
      );
      expectedPaths.add(path);
    }
  }
  final sun = tester.widget<Image>(
    find.byKey(const ValueKey('course-map-sun-art')),
  );
  expect(_assetPath(sun), 'assets/images/course_map/art/sun.png');
  expectedPaths.add(_assetPath(sun));
  expectedPaths.add('assets/images/course_map/art/ship_preview.png');
  expect(renderedPaths, unorderedEquals(expectedPaths));
}

String _assetPath(Image image) => (image.image as AssetImage).assetName;
