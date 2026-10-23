import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'course_map_state.dart';

class CourseDestinationList extends StatelessWidget {
  const CourseDestinationList({
    super.key,
    required this.state,
    required this.selectedBodyId,
    required this.onInspect,
    required this.focusOrderOffset,
    required this.currentBodyId,
  });
  final CourseMapState state;
  final String? selectedBodyId;
  final ValueChanged<String> onInspect;
  final int focusOrderOffset;
  final String? currentBodyId;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < state.bodies.length; index++)
        FocusTraversalOrder(
          order: NumericFocusOrder((focusOrderOffset + index).toDouble()),
          child: Semantics(
            key: ValueKey(
              'destination-list-semantics-${state.bodies[index].definition.id}',
            ),
            sortKey: OrdinalSortKey((focusOrderOffset + index).toDouble()),
            label:
                '${state.bodies[index].definition.title}, ${state.bodies[index].definition.role.name}, ${_status(state.bodies[index])}${state.bodies[index].definition.id == currentBodyId ? ', current location, stationary' : ''}',
            button: true,
            selected: state.bodies[index].definition.id == selectedBodyId,
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                minVerticalPadding: 12,
                selected: state.bodies[index].definition.id == selectedBodyId,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                selectedColor: Theme.of(
                  context,
                ).colorScheme.onSecondaryContainer,
                leading: ExcludeSemantics(
                  child: Icon(_statusIcon(state.bodies[index])),
                ),
                title: Text(state.bodies[index].definition.title),
                subtitle: Text(
                  '${_status(state.bodies[index])}${state.bodies[index].definition.id == currentBodyId ? ' · Current location (stationary)' : ''}',
                ),
                onTap: () => onInspect(state.bodies[index].definition.id),
              ),
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
    MapReadiness.alpha => switch (body.progress) {
      MapProgress.unknown => 'Progress unknown',
      MapProgress.notStarted => 'Not started',
      MapProgress.resumable => 'In progress',
      MapProgress.completed => 'Completed',
    },
  };
  static IconData _statusIcon(MapBodyState body) => switch (body.readiness) {
    MapReadiness.planned => Icons.schedule,
    MapReadiness.qualificationBlocked => Icons.info_outline,
    MapReadiness.loading => Icons.hourglass_empty,
    MapReadiness.unavailable => Icons.error_outline,
    MapReadiness.alpha => Icons.public,
  };
}
