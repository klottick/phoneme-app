import 'package:flutter/material.dart';

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
    color: Theme.of(context).scaffoldBackgroundColor,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Star chart',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'English → French sound systems',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(height: 12),
        for (final system in widget.systems)
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => system.planned
                  ? setState(
                      () => _inspectedSystemId = _inspectedSystemId == system.id
                          ? null
                          : system.id,
                    )
                  : widget.onOpenSystem(system.id),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: ExcludeSemantics(child: Icon(Icons.auto_awesome)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            system.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            system.planned
                                ? '${system.description}\nComing soon'
                                : system.description,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ),
          ),
        for (final system in widget.systems)
          if (system.planned && system.id == _inspectedSystemId)
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      system.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      system.description,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Coming soon',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    ),
  );
}
