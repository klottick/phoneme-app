import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:linguist/src/features/course_map/course_map_catalogue.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/course_system_view.dart';
import 'package:linguist/src/routing/course_map_navigation.dart';

void main() {
  test('routes only validated typed targets', () {
    expect(
      courseMapLocation(MapTarget.discovery, MapLaunch.start),
      '/course-lesson/en-fr-u-y',
    );
    expect(
      courseMapLocation(MapTarget.discovery, MapLaunch.review),
      '/course-lesson/en-fr-u-y?review=true',
    );
    expect(
      courseMapLocation(MapTarget.mixedComparison, MapLaunch.open),
      '/course-comparison/en-fr-phoneme-comparison',
    );
    expect(
      courseMapLocation(MapTarget.sentenceSections, MapLaunch.open),
      '/course-sentence-hunt',
    );
    expect(courseMapLocation(MapTarget.discovery, MapLaunch.open), isNull);
    expect(courseMapLocation(MapTarget.arcade, MapLaunch.review), isNull);
  });

  testWidgets('system view composes recovery footer in its scroll surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseSystemView(
            state: CourseMapState(
              systemId: 'en-fr-u-y-system',
              bodies: const [],
              currentBodyId: null,
              allAvailableMainComplete: false,
              completedLegacyLessonIds: null,
            ),
            selectedBodyId: null,
            onInspect: (_) {},
            onLaunch: (_) {},
            footer: const Text('Recovery and legacy access'),
          ),
        ),
      ),
    );
    expect(find.text('Recovery and legacy access'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
