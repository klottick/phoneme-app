import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CourseRootNavigation extends StatelessWidget {
  const CourseRootNavigation({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  int get _index => switch (location) {
    '/home' || '/course-chart' => 0,
    '/course-review' => 1,
    '/arcade' => 2,
    '/course-progress' => 3,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (index) {
        final route = switch (index) {
          0 => '/home', 1 => '/course-review', 2 => '/arcade', _ => '/course-progress',
        };
        if (route != location) context.go(route);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.public), label: 'Map'),
        NavigationDestination(icon: Icon(Icons.replay), label: 'Review'),
        NavigationDestination(icon: Icon(Icons.sports_esports), label: 'Games'),
        NavigationDestination(icon: Icon(Icons.insights), label: 'Progress'),
      ],
    ),
  );
}
