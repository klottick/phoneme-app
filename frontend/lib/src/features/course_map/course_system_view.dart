import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'course_destination_list.dart';
import 'course_destination_panel.dart';
import 'course_map_canvas.dart';
import 'course_map_state.dart';
import 'french_space_map.dart';

class CourseSystemView extends StatelessWidget {
  const CourseSystemView({
    super.key,
    required this.state,
    required this.selectedBodyId,
    required this.onInspect,
    required this.onLaunch,
    this.progressSummary,
  });

  final CourseMapState state;
  final String? selectedBodyId;
  final ValueChanged<String> onInspect;
  final ValueChanged<MapBodyState> onLaunch;
  final Widget? progressSummary;

  MapBodyState? get _selected =>
      state.bodies
          .where((body) => body.definition.id == selectedBodyId)
          .firstOrNull ??
      state.bodies.firstOrNull;

  MapBodyState? get _current => state.bodies
      .where((body) => body.definition.id == state.currentBodyId)
      .firstOrNull;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final selected = _selected;
      final current = _current;
      final wideLayout = constraints.maxWidth >= 760;
      final availableHeight = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : 800.0;
      final panelFraction = MediaQuery.textScalerOf(context).scale(1) >= 2
          ? .48
          : .38;
      final panelHeight = math.min(
        280.0,
        math.max(164.0, availableHeight * panelFraction),
      );
      final systemTitle =
          findSpaceSystem(state.systemId)?.title ?? 'Sound system';

      Widget selectedPanel() {
        if (selected == null) {
          return const Card(
            margin: EdgeInsets.zero,
            child: Center(child: Text('No destinations are available.')),
          );
        }
        return CourseDestinationPanel(
          body: selected,
          onLaunch: selected.launch == null ? null : () => onLaunch(selected),
          focusOrder: state.bodies.length,
          compact: true,
          isCurrentLocation: selected.definition.id == current?.definition.id,
          progressSummary: progressSummary,
        );
      }

      Widget mapCanvas() => CourseMapCanvas(
        state: state,
        selectedBodyId: selected?.definition.id,
        onInspect: onInspect,
        focusOrderOffset: 0,
      );

      final picker = FocusTraversalOrder(
        order: NumericFocusOrder((state.bodies.length + 1).toDouble()),
        child: Semantics(
          key: const ValueKey('destination-picker-semantics'),
          button: true,
          label: 'Choose a destination',
          sortKey: OrdinalSortKey((state.bodies.length + 1).toDouble()),
          child: IconButton(
            key: const ValueKey('destination-picker'),
            tooltip: 'Destinations',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => _openDestinationPicker(context),
            icon: const Icon(Icons.list_alt),
          ),
        ),
      );

      final header = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  systemTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              picker,
            ],
          ),
          Semantics(
            label: current == null
                ? 'Current location unknown'
                : 'Current location: ${current.definition.title}, stationary',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(
                    Icons.my_location,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      current == null
                          ? 'Current location unknown'
                          : 'Current · ${current.definition.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

      return FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 8),
              Expanded(
                child: wideLayout
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: mapCanvas()),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: math.min(360.0, constraints.maxWidth * .36),
                            child: selectedPanel(),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: mapCanvas()),
                          const SizedBox(height: 8),
                          SizedBox(height: panelHeight, child: selectedPanel()),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _openDestinationPicker(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) {
          final height = MediaQuery.sizeOf(sheetContext).height * .84;
          return SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          key: const ValueKey('destination-picker-heading'),
                          header: true,
                          label: 'Choose a destination',
                          child: ExcludeSemantics(
                            child: Text(
                              'Destinations',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                sheetContext,
                              ).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close destinations',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: CourseDestinationList(
                      state: state,
                      selectedBodyId: selectedBodyId,
                      currentBodyId: state.currentBodyId,
                      focusOrderOffset: 0,
                      onInspect: (id) {
                        onInspect(id);
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}
