import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course_map/course_star_chart_view.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';

void main() {
  testWidgets('chart_planned_system_has_no_launch', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseStarChartView(
            systems: frenchSpaceSystems,
            onOpenSystem: opened.add,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Nasal vowels'));
    expect(opened, isEmpty);
    expect(
      find.textContaining('Planned sound system: French nasal vowels'),
      findsWidgets,
    );
    expect(find.textContaining('Coming soon'), findsWidgets);
    expect(find.textContaining('Start'), findsNothing);
  });
}
