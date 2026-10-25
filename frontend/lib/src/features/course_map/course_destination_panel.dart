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
    this.compact = false,
    this.isCurrentLocation = false,
    this.progressSummary,
  });

  final MapBodyState body;
  final VoidCallback? onLaunch;
  final int? focusOrder;
  final bool compact;
  final bool isCurrentLocation;
  final Widget? progressSummary;

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
          body.definition.target == MapTarget.dedicatedSpelling
              ? 'Start spelling'
              : body.definition.target == MapTarget.dedicatedComparison
              ? 'Start comparison'
              : 'Start lesson',
        MapLaunch.resume =>
          body.definition.target == MapTarget.dedicatedSpelling
              ? 'Continue spelling'
              : body.definition.target == MapTarget.dedicatedComparison
              ? 'Continue comparison'
              : 'Continue lesson',
        MapLaunch.review =>
          body.definition.target == MapTarget.dedicatedSpelling
              ? 'Review spelling'
              : body.definition.target == MapTarget.mixedComparison ||
                    body.definition.target == MapTarget.dedicatedComparison
              ? 'Review comparison'
              : 'Review lesson',
        MapLaunch.open =>
          body.definition.target == MapTarget.dedicatedComparison ||
                  body.definition.target == MapTarget.dedicatedSpelling
              ? null
              : 'Open destination',
        null => null,
      },
    };
    final actionIcon = switch (body.readiness) {
      MapReadiness.planned => Icons.schedule,
      MapReadiness.qualificationBlocked => Icons.list_alt,
      MapReadiness.loading || MapReadiness.unavailable => Icons.refresh,
      MapReadiness.alpha => switch (body.launch) {
        MapLaunch.start => Icons.play_arrow,
        MapLaunch.resume => Icons.play_circle_outline,
        MapLaunch.review => Icons.replay,
        MapLaunch.open => Icons.open_in_new,
        null => Icons.open_in_new,
      },
    };
    final launchButton = FilledButton.icon(
      onPressed: body.readiness == MapReadiness.alpha
          ? onLaunch
          : (body.launch == null ? null : onLaunch),
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      icon: Icon(actionIcon),
      label: Text(action ?? ''),
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

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progressSummary != null) ...[
          progressSummary!,
          const SizedBox(height: 8),
        ],
        Text(
          body.definition.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            _StatusTag(label: _role(body.definition.role)),
            _StatusTag(label: status),
            if (isCurrentLocation)
              const _StatusTag(
                label: 'Current location',
                icon: Icons.my_location,
              ),
            if (body.recommended)
              const _StatusTag(label: 'Recommended', icon: Icons.star),
          ],
        ),
        const SizedBox(height: 6),
        Text(_mapDescription(body)),
        if (_shouldShowExplanation(body)) ...[
          const SizedBox(height: 6),
          Text(body.explanation),
        ],
        if (body.evidenceLabels.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final label in body.evidenceLabels) Text(label),
        ],
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: SingleChildScrollView(child: details)),
                  if (action != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: launchControl),
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  if (action != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: launchControl),
                  ],
                ],
              ),
      ),
    );
  }

  static String _role(MapBodyRole role) => switch (role) {
    MapBodyRole.planet => 'Planet',
    MapBodyRole.moon => 'Moon',
    MapBodyRole.station => 'Station',
    MapBodyRole.asteroidField => 'Arcade',
  };

  static bool _shouldShowExplanation(MapBodyState body) {
    if (body.explanation.isEmpty ||
        body.explanation == body.definition.description) {
      return false;
    }
    if (body.readiness != MapReadiness.alpha) return true;
    return switch ((body.progress, body.launch)) {
      (MapProgress.notStarted, MapLaunch.start) ||
      (MapProgress.resumable, MapLaunch.resume) ||
      (MapProgress.completed, MapLaunch.review) => false,
      _ => true,
    };
  }

  static String _mapDescription(MapBodyState body) =>
      switch (body.definition.id) {
        'comparison' => 'Practice comparing /u/ and /y/.',
        'spelling' => 'Practice connecting sounds with their written forms.',
        'context' => 'Find /u/ and /y/ in listening contexts.',
        'checkpoint' => 'Assessment checkpoint for this sound contrast.',
        'coaching' => 'Optional articulation coaching for /u/ and /y/.',
        _ => body.definition.description,
      };
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14),
              const SizedBox(width: 4),
            ],
            Flexible(child: Text(label)),
          ],
        ),
      ),
    ),
  );
}
