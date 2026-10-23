import 'package:flutter/widgets.dart';
import '../course_map/course_map_screen.dart';

/// Compatibility entry point retained for callers that construct Home directly.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const CourseMapScreen(systemId: 'en-fr-u-y-system');
}
