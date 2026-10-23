import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'course_destination_list.dart';
import 'course_destination_panel.dart';
import 'course_map_canvas.dart';
import 'course_map_state.dart';
import 'french_space_map.dart';

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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final selected = _selected;
        MapBodyState? currentBody;
        for (final body in widget.state.bodies) {
          if (body.definition.id == widget.state.currentBodyId) {
            currentBody = body;
          }
        }
        final hasSelectedAction =
            selected != null &&
            selected.readiness != MapReadiness.planned &&
            selected.launch != null;
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
        final longTitle = widget.state.bodies.any(
          (body) => body.definition.title.length > 32,
        );
        final fallback =
            constraints.maxWidth - 16 < 370 || largeText || longTitle;
        final actionOrder = fallback ? 0 : widget.state.bodies.length;
        final disclosureOrder = fallback
            ? -1
            : widget.state.bodies.length + (hasSelectedAction ? 1 : 0);

        Widget selectedPanel() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CourseDestinationPanel(
            body: selected!,
            onLaunch: selected.launch == null
                ? null
                : () => widget.onLaunch(selected),
            focusOrder: actionOrder,
          ),
        );

        Widget disclosure() => Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: FocusTraversalOrder(
            order: NumericFocusOrder(disclosureOrder.toDouble()),
            child: Semantics(
              key: const ValueKey('destination-list-disclosure-semantics'),
              sortKey: OrdinalSortKey(disclosureOrder.toDouble()),
              child: OutlinedButton.icon(
                key: const ValueKey('destination-list-disclosure'),
                onPressed: () =>
                    setState(() => _showDestinations = !_showDestinations),
                icon: Icon(_showDestinations ? Icons.expand_less : Icons.list),
                label: Text(
                  _showDestinations ? 'Hide destinations' : 'All destinations',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
              ),
            ),
          ),
        );

        Widget destinationList(int order) => CourseDestinationList(
          state: widget.state,
          selectedBodyId: widget.selectedBodyId,
          onInspect: widget.onInspect,
          focusOrderOffset: order,
          currentBodyId: widget.state.currentBodyId,
        );

        Widget mapCanvas() => Padding(
          padding: const EdgeInsets.all(8),
          child: CourseMapCanvas(
            state: widget.state,
            selectedBodyId: widget.selectedBodyId,
            onInspect: widget.onInspect,
            focusOrderOffset: 0,
          ),
        );

        Widget currentLocationCue() {
          final label = currentBody == null
              ? 'Current location unknown'
              : 'Current location: ${currentBody.definition.title}, stationary';
          final copy = currentBody == null
              ? 'Current location unknown'
              : 'Current location: ${currentBody.definition.title} · stationary';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              label: label,
              child: currentBody == null
                  ? Text(
                      copy,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                  : ExcludeSemantics(
                      child: Text(
                        copy,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
            ),
          );
        }

        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                  child: Text(
                    'SOUND SYSTEM',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    findSpaceSystem(widget.state.systemId)?.title ??
                        'Sound system',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Explore the destinations in this sound system.'),
                ),
                if (fallback) currentLocationCue(),
                if (fallback && selected != null) selectedPanel(),
                if (fallback) destinationList(hasSelectedAction ? 1 : 0),
                if (!fallback) mapCanvas(),
                if (!fallback) currentLocationCue(),
                if (!fallback && selected != null) selectedPanel(),
                if (!fallback) disclosure(),
                if (!fallback && _showDestinations)
                  destinationList(disclosureOrder + 1),
                if (fallback) mapCanvas(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
