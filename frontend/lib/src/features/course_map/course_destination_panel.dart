import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'course_map_catalogue.dart';
import 'course_map_state.dart';

class CourseDestinationPanel extends StatelessWidget {
  const CourseDestinationPanel({
    super.key,
    required this.body,
    required this.onLaunch,
    this.focusOrder,
  });
  final MapBodyState body;
  final VoidCallback? onLaunch;
  final int? focusOrder;

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
        MapLaunch.start =>
          body.definition.target == MapTarget.dedicatedComparison
              ? 'Start comparison'
              : 'Start lesson',
        MapLaunch.resume =>
          body.definition.target == MapTarget.dedicatedComparison
              ? 'Continue comparison'
              : 'Continue lesson',
        MapLaunch.review =>
          body.definition.target == MapTarget.mixedComparison ||
                  body.definition.target == MapTarget.dedicatedComparison
              ? 'Review comparison'
              : 'Review lesson',
        MapLaunch.open =>
          body.definition.target == MapTarget.dedicatedComparison
              ? null
              : 'Open destination',
        null => null,
      },
    };
    final launchButton = FilledButton(
      onPressed: body.readiness == MapReadiness.alpha
          ? onLaunch
          : (body.launch == null ? null : onLaunch),
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      child: Text(action ?? ''),
    );
    final launchControl = focusOrder == null
        ? launchButton
        : FocusTraversalOrder(
            order: NumericFocusOrder(focusOrder!.toDouble()),
            child: Semantics(
              key: const ValueKey('destination-panel-action-semantics'),
              sortKey: OrdinalSortKey(focusOrder!.toDouble()),
              child: launchButton,
            ),
          );
    return Card(
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
            Text('${body.definition.role.name} · $status'),
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
              SizedBox(width: double.infinity, child: launchControl),
            ],
          ],
        ),
      ),
    );
  }
}
