import 'package:flutter/material.dart';

import '../../core/theme/space_course_colors.dart';
import 'course_destination_list.dart';
import 'course_destination_panel.dart';
import 'course_map_canvas.dart';
import 'course_map_state.dart';

class CourseSystemView extends StatefulWidget {
  const CourseSystemView({
    super.key,
    required this.state,
    required this.selectedBodyId,
    required this.onInspect,
    required this.onLaunch,
  });
  final CourseMapState state;
  final String? selectedBodyId;
  final ValueChanged<String> onInspect;
  final ValueChanged<MapBodyState> onLaunch;

  @override
  State<CourseSystemView> createState() => _CourseSystemViewState();
}

class _CourseSystemViewState extends State<CourseSystemView> {
  bool _showDestinations = false;
  MapBodyState? get _selected {
    for (final body in widget.state.bodies) {
      if (body.definition.id == widget.selectedBodyId) return body;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SpaceCourseColors.background,
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
            child: Text(
              'SOUND SYSTEM',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SpaceCourseColors.textSecondary,
                letterSpacing: 2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.state.systemId,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Explore the destinations in this sound system.',
              style: TextStyle(color: SpaceCourseColors.textSecondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: CourseMapCanvas(
              state: widget.state,
              selectedBodyId: widget.selectedBodyId,
              onInspect: widget.onInspect,
            ),
          ),
          if (!widget.state.bodies.any(
            (body) => body.definition.id == widget.state.currentBodyId,
          ))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                label: 'Current location unknown; ship indicator stationary',
                child: const Text(
                  'Current location unavailable · stationary ship indicator',
                  style: TextStyle(color: SpaceCourseColors.textSecondary),
                ),
              ),
            ),
          if (_selected case final selected?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CourseDestinationPanel(
                body: selected,
                onLaunch: selected.launch == null
                    ? null
                    : () => widget.onLaunch(selected),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _showDestinations = !_showDestinations),
              icon: Icon(_showDestinations ? Icons.expand_less : Icons.list),
              label: Text(
                _showDestinations ? 'Hide destinations' : 'All destinations',
              ),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
          ),
          if (_showDestinations)
            CourseDestinationList(
              state: widget.state,
              selectedBodyId: widget.selectedBodyId,
              onInspect: widget.onInspect,
            ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}
