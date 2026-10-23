import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../routing/course_root_navigation.dart';
import 'course_star_chart_view.dart';
import 'french_space_map.dart';

class CourseChartScreen extends StatelessWidget {
  const CourseChartScreen({super.key});
  @override
  Widget build(BuildContext context) => CourseRootNavigation(
    location: '/course-chart',
    child: Scaffold(
      appBar: AppBar(title: const Text('Course chart')),
      body: CourseStarChartView(
        systems: frenchSpaceSystems,
        onOpenSystem: (id) => context.go('/course-system/$id'),
      ),
    ),
  );
}
