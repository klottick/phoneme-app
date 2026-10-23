import 'package:flutter/material.dart';

import '../../core/theme/space_course_colors.dart';
import 'course_map_catalogue.dart';

class CourseStarChartView extends StatefulWidget {
  const CourseStarChartView({
    super.key,
    required this.systems,
    required this.onOpenSystem,
  });
  final List<MapSystemDefinition> systems;
  final ValueChanged<String> onOpenSystem;

  @override
  State<CourseStarChartView> createState() => _CourseStarChartViewState();
}

class _CourseStarChartViewState extends State<CourseStarChartView> {
  String? _inspectedSystemId;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SpaceCourseColors.background,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Star chart', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('English → French sound systems'),
        const SizedBox(height: 12),
        for (final system in widget.systems)
          Card(
            color: SpaceCourseColors.panel,
            child: ListTile(
              minVerticalPadding: 8,
              leading: const ExcludeSemantics(
                child: Icon(Icons.auto_awesome, color: Color(0xFFE6C98F)),
              ),
              title: Text(system.title),
              subtitle: Text(
                system.planned
                    ? '${system.description}\nComing soon'
                    : system.description,
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => system.planned
                  ? setState(
                      () => _inspectedSystemId = _inspectedSystemId == system.id
                          ? null
                          : system.id,
                    )
                  : widget.onOpenSystem(system.id),
            ),
          ),
        for (final system in widget.systems)
          if (system.planned && system.id == _inspectedSystemId)
            Card(
              color: SpaceCourseColors.raised,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      system.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(system.description),
                    const SizedBox(height: 8),
                    const Text('Coming soon'),
                  ],
                ),
              ),
            ),
      ],
    ),
  );
}
