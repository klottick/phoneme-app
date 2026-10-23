import 'package:flutter/material.dart';

import '../../core/theme/space_course_colors.dart';
import 'course_map_state.dart';

class CourseDestinationPanel extends StatelessWidget {
  const CourseDestinationPanel({
    super.key,
    required this.body,
    required this.onLaunch,
  });
  final MapBodyState body;
  final VoidCallback? onLaunch;

  @override
  Widget build(BuildContext context) {
    final status = switch (body.readiness) {
      MapReadiness.planned => 'Coming soon',
      MapReadiness.qualificationBlocked => 'Qualification required',
      MapReadiness.loading => 'Availability is loading',
      MapReadiness.unavailable => 'Destination unavailable',
      MapReadiness.alpha => switch (body.progress) {
        MapProgress.completed => 'Completed',
        MapProgress.resumable => 'In progress',
        MapProgress.unknown => 'Progress unknown',
        MapProgress.notStarted => 'Available',
      },
    };
    final action = switch (body.readiness) {
      MapReadiness.planned => null,
      MapReadiness.qualificationBlocked => 'View sections',
      MapReadiness.loading || MapReadiness.unavailable => 'Open recovery',
      MapReadiness.alpha => switch (body.launch) {
        MapLaunch.start => 'Start lesson',
        MapLaunch.resume => 'Continue lesson',
        MapLaunch.review => 'Review lesson',
        MapLaunch.open => 'Open destination',
        null => null,
      },
    };
    return Card(
      color: SpaceCourseColors.panel,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              body.definition.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '${body.definition.role.name} · $status',
              style: const TextStyle(color: SpaceCourseColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(body.definition.description),
            if (body.explanation.isNotEmpty &&
                body.explanation != body.definition.description) ...[
              const SizedBox(height: 6),
              Text(body.explanation),
            ],
            if (body.evidenceLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final label in body.evidenceLabels) Text(label),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: body.readiness == MapReadiness.alpha
                      ? onLaunch
                      : (body.launch == null ? null : onLaunch),
                  style: FilledButton.styleFrom(
                    backgroundColor: SpaceCourseColors.action,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(action),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
