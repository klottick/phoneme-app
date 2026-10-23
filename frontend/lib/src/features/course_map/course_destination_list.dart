import 'package:flutter/material.dart';

import '../../core/theme/space_course_colors.dart';
import 'course_map_state.dart';

class CourseDestinationList extends StatelessWidget {
  const CourseDestinationList({
    super.key,
    required this.state,
    required this.selectedBodyId,
    required this.onInspect,
  });
  final CourseMapState state;
  final String? selectedBodyId;
  final ValueChanged<String> onInspect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final body in state.bodies)
        Semantics(
          label:
              '${body.definition.title}, ${body.definition.role.name}, ${_status(body)}',
          button: true,
          selected: body.definition.id == selectedBodyId,
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              minVerticalPadding: 8,
              selected: body.definition.id == selectedBodyId,
              selectedTileColor: SpaceCourseColors.selected,
              leading: ExcludeSemantics(
                child: Icon(
                  _statusIcon(body),
                  color: SpaceCourseColors.textPrimary,
                ),
              ),
              title: Text(body.definition.title),
              subtitle: Text(_status(body)),
              onTap: () => onInspect(body.definition.id),
            ),
          ),
        ),
    ],
  );

  static String _status(MapBodyState body) => switch (body.readiness) {
    MapReadiness.planned => 'Coming soon',
    MapReadiness.qualificationBlocked => 'Qualification required',
    MapReadiness.loading => 'Availability loading',
    MapReadiness.unavailable => 'Unavailable',
    MapReadiness.alpha => body.progress.name,
  };
  static IconData _statusIcon(MapBodyState body) => switch (body.readiness) {
    MapReadiness.planned => Icons.schedule,
    MapReadiness.qualificationBlocked => Icons.info_outline,
    MapReadiness.loading => Icons.hourglass_empty,
    MapReadiness.unavailable => Icons.error_outline,
    MapReadiness.alpha => Icons.public,
  };
}
