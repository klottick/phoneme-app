import 'package:flutter/material.dart';

/// Temporary handoff wrapper for the map's current-location scene.
///
/// The previous ambient orbit ran forever behind a pause button. The approved
/// map direction replaces it with interruptible, purposeful travel in the next
/// motion task. Until then, keep the authored current-location marker visible
/// without running an uncontrolled animation.
class CourseMapMotion extends StatelessWidget {
  const CourseMapMotion({super.key, required this.anchor, required this.child});

  static const orbitPeriod = Duration(seconds: 34);

  final Offset? anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
