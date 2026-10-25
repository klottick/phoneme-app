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
    this.pickerRevision,
  });

  final CourseMapState state;
  final String? selectedBodyId;
  final ValueChanged<String> onInspect;
  final ValueChanged<MapBodyState> onLaunch;
  final Widget? progressSummary;
  final Object? pickerRevision;

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

      final picker = _DestinationPickerButton(
        state: state,
        selectedBodyId: selected?.definition.id,
        currentBodyId: current?.definition.id,
        onInspect: onInspect,
        pickerRevision: pickerRevision,
        focusOrder: state.bodies.length,
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
}

class _DestinationPickerButton extends StatefulWidget {
  const _DestinationPickerButton({
    required this.state,
    required this.selectedBodyId,
    required this.currentBodyId,
    required this.onInspect,
    required this.pickerRevision,
    required this.focusOrder,
  });

  final CourseMapState state;
  final String? selectedBodyId;
  final String? currentBodyId;
  final ValueChanged<String> onInspect;
  final Object? pickerRevision;
  final int focusOrder;

  @override
  State<_DestinationPickerButton> createState() =>
      _DestinationPickerButtonState();
}

class _DestinationPickerButtonState extends State<_DestinationPickerButton> {
  Route<void>? _pickerRoute;
  NavigatorState? _pickerNavigator;
  Object? _pickerToken;

  @override
  void didUpdateWidget(covariant _DestinationPickerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state, widget.state) ||
        oldWidget.selectedBodyId != widget.selectedBodyId ||
        oldWidget.currentBodyId != widget.currentBodyId ||
        oldWidget.pickerRevision != widget.pickerRevision) {
      _dismissOwnedPicker();
    }
  }

  @override
  void dispose() {
    _dismissOwnedPicker();
    super.dispose();
  }

  void _dismissOwnedPicker() {
    final route = _pickerRoute;
    final navigator = _pickerNavigator;
    _pickerRoute = null;
    _pickerNavigator = null;
    _pickerToken = null;
    if (route == null || navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && route.isActive) {
        navigator.removeRoute<void>(route);
      }
    });
  }

  void _openPicker() {
    final openingState = widget.state;
    final openingSelection = widget.selectedBodyId;
    final openingCurrentBody = widget.currentBodyId;
    final openingRevision = widget.pickerRevision;
    final token = Object();
    _pickerToken = token;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        if (!mounted) return const SizedBox.shrink();
        _pickerRoute = ModalRoute.of<void>(sheetContext);
        _pickerNavigator = Navigator.of(sheetContext);
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
                            style: Theme.of(sheetContext).textTheme.titleMedium,
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
                    state: openingState,
                    selectedBodyId: openingSelection,
                    currentBodyId: openingCurrentBody,
                    focusOrderOffset: 0,
                    onInspect: (id) {
                      if (!mounted || !identical(_pickerToken, token)) {
                        return;
                      }
                      final route = ModalRoute.of<void>(sheetContext);
                      if (route == null ||
                          !route.isActive ||
                          !route.isCurrent ||
                          !identical(widget.state, openingState) ||
                          widget.selectedBodyId != openingSelection ||
                          widget.currentBodyId != openingCurrentBody ||
                          widget.pickerRevision != openingRevision ||
                          !openingState.bodies.any(
                            (body) => body.definition.id == id,
                          )) {
                        return;
                      }
                      final navigator = Navigator.of(sheetContext);
                      if (identical(_pickerRoute, route)) {
                        _pickerRoute = null;
                        _pickerNavigator = null;
                        _pickerToken = null;
                      }
                      widget.onInspect(id);
                      navigator.pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (identical(_pickerToken, token)) {
        _pickerRoute = null;
        _pickerNavigator = null;
        _pickerToken = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) => FocusTraversalOrder(
    order: NumericFocusOrder((widget.focusOrder + 1).toDouble()),
    child: Semantics(
      key: const ValueKey('destination-picker-semantics'),
      button: true,
      label: 'Choose a destination',
      sortKey: OrdinalSortKey((widget.focusOrder + 1).toDouble()),
      child: IconButton(
        key: const ValueKey('destination-picker'),
        tooltip: 'Destinations',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: _openPicker,
        icon: const Icon(Icons.list_alt),
      ),
    ),
  );
}
