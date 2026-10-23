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
    this.footer,
  });
  final CourseMapState state;
  final String? selectedBodyId;
  final ValueChanged<String> onInspect;
  final ValueChanged<MapBodyState> onLaunch;
  final Widget? footer;

  @override
  State<CourseSystemView> createState() => _CourseSystemViewState();
}

class _CourseSystemViewState extends State<CourseSystemView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewportKey = GlobalKey();
  final GlobalKey _mapCanvasKey = GlobalKey();
  bool _showDestinations = false;
  bool _mapVisible = false;
  bool _visibilityUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scheduleVisibilityUpdate);
  }

  @override
  void didUpdateWidget(covariant CourseSystemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleVisibilityUpdate();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_scheduleVisibilityUpdate)
      ..dispose();
    super.dispose();
  }

  void _scheduleVisibilityUpdate() {
    if (_visibilityUpdateScheduled) return;
    _visibilityUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityUpdateScheduled = false;
      if (!mounted) return;
      final mapRenderObject = _mapCanvasKey.currentContext?.findRenderObject();
      final viewportRenderObject = _scrollViewportKey.currentContext
          ?.findRenderObject();
      final visible =
          mapRenderObject is RenderBox &&
          mapRenderObject.hasSize &&
          viewportRenderObject is RenderBox &&
          viewportRenderObject.hasSize &&
          _intersectsVisibleViewport(mapRenderObject, viewportRenderObject);
      if (_mapVisible != visible) setState(() => _mapVisible = visible);
    });
  }

  bool _intersectsVisibleViewport(RenderBox map, RenderBox viewport) {
    final mapRect = map.localToGlobal(Offset.zero) & map.size;
    final viewportRect = viewport.localToGlobal(Offset.zero) & viewport.size;
    final screenRect = Offset.zero & MediaQuery.sizeOf(context);
    final visibleRect = mapRect.intersect(viewportRect).intersect(screenRect);
    return visibleRect.width > 0 && visibleRect.height > 0;
  }

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
        _scheduleVisibilityUpdate();
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
          child: TickerMode(
            enabled: _mapVisible,
            child: CourseMapCanvas(
              key: _mapCanvasKey,
              state: widget.state,
              selectedBodyId: widget.selectedBodyId,
              onInspect: widget.onInspect,
              focusOrderOffset: 0,
            ),
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
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _scheduleVisibilityUpdate();
              return false;
            },
            child: SingleChildScrollView(
              key: _scrollViewportKey,
              controller: _scrollController,
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
                    child: Text(
                      'Explore the destinations in this sound system.',
                    ),
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
                  if (widget.footer != null) widget.footer!,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
