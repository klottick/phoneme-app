import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../routing/course_map_route_coverage.dart';

/// Finite, event-driven preview travel on the course map.
///
/// [anchor] remains the actual current location. The separate preview ship
/// travels to [destination] when [selectionKey] changes and never writes
/// learning progress or intercepts map input.
class CourseMapMotion extends StatefulWidget {
  const CourseMapMotion({
    super.key,
    required this.anchor,
    required this.child,
    this.destination,
    this.selectionKey,
    this.anchorKey,
    this.routeCoverageObserver,
  });

  static const flightDuration = Duration(milliseconds: 880);

  final Offset? anchor;
  final Offset? destination;
  final Object? selectionKey;
  final Object? anchorKey;
  final CourseMapRouteCoverageObserver? routeCoverageObserver;
  final Widget child;

  @override
  State<CourseMapMotion> createState() => _CourseMapMotionState();
}

class _CourseMapMotionState extends State<CourseMapMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _shipSize = 32;

  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  Offset? _position;
  Offset? _flightStart;
  Offset? _flightEnd;
  Offset? _suspendedTarget;
  bool _flightActive = false;
  bool _initialized = false;
  bool _mediaDisablesMotion = false;
  bool _platformDisablesMotion = false;
  bool _tickerEnabled = true;
  bool _appActive = true;
  ModalRoute<dynamic>? _route;
  CourseMapRouteCoverageObserver? _boundCoverageObserver;
  VoidCallback? _unsubscribeRouteCoverage;
  bool _routeVisible = true;
  int _requestGeneration = 0;

  bool get _reducedMotion => _mediaDisablesMotion || _platformDisablesMotion;

  bool get _canAnimate =>
      !_reducedMotion && _tickerEnabled && _appActive && _routeVisible;

  Offset? get _target => widget.destination ?? widget.anchor;

  Offset? get _renderedPosition {
    if (!_flightActive) return _position;
    final Offset? start = _flightStart;
    final Offset? end = _flightEnd;
    if (start == null || end == null) return _position;

    final double progress = _curve.value;
    final Offset delta = end - start;
    final double distance = delta.distance;
    final Offset normal = distance == 0
        ? Offset.zero
        : Offset(-delta.dy / distance, delta.dx / distance);
    final double arc =
        math.min(34, distance * .12) * math.sin(math.pi * progress);
    return Offset.lerp(start, end, progress)! + normal * arc;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _platformDisablesMotion = _platformReducedMotion;
    _position = widget.anchor ?? _target;
    _controller = AnimationController(
      vsync: this,
      duration: CourseMapMotion.flightDuration,
      debugLabel: 'course-map-preview-flight',
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.addStatusListener(_onStatusChanged);
  }

  bool get _platformReducedMotion {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.disableAnimations || features.reduceMotion;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool wasReduced = _reducedMotion;
    final bool wasEnabled = _canAnimate;
    _mediaDisablesMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _platformDisablesMotion = _platformReducedMotion;
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _bindRoute(ModalRoute.of<dynamic>(context));
    _routeVisible = _isRouteVisible;

    if (!_initialized) {
      _initialized = true;
      final Offset? target = _target;
      final Offset? start = widget.anchor;
      if (target == null) return;
      if (_reducedMotion) {
        _snapTo(target);
      } else if (start == null || start == target) {
        _position = target;
      } else if (_canAnimate) {
        _scheduleFlight(target);
      } else {
        _suspendedTarget = target;
      }
      return;
    }

    _reconcileAvailability(wasReduced: wasReduced, wasEnabled: wasEnabled);
  }

  void _bindRoute(ModalRoute<dynamic>? route) {
    if (identical(route, _route) &&
        identical(widget.routeCoverageObserver, _boundCoverageObserver)) {
      return;
    }
    _unsubscribeRouteCoverage?.call();
    _unsubscribeRouteCoverage = null;
    _route = route;
    _boundCoverageObserver = widget.routeCoverageObserver;
    final CourseMapRouteCoverageObserver? observer =
        widget.routeCoverageObserver;
    if (route != null && observer != null) {
      _unsubscribeRouteCoverage = observer.subscribe(
        route,
        _onRouteCoverageChanged,
      );
    }
  }

  bool get _isRouteVisible {
    final ModalRoute<dynamic>? route = _route;
    if (route == null) return true;
    if (!route.isCurrent || route.offstage) return false;
    return !(widget.routeCoverageObserver?.isCovered(route) ?? false);
  }

  void _onRouteCoverageChanged() {
    if (!mounted) return;
    final bool wasEnabled = _canAnimate;
    final bool wasVisible = _routeVisible;
    _routeVisible = _isRouteVisible;
    if (wasVisible == _routeVisible) return;
    _reconcileAvailability(wasReduced: _reducedMotion, wasEnabled: wasEnabled);
  }

  @override
  void didUpdateWidget(covariant CourseMapMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool wasEnabled = _canAnimate;
    if (!identical(
      oldWidget.routeCoverageObserver,
      widget.routeCoverageObserver,
    )) {
      _bindRoute(_route);
      _routeVisible = _isRouteVisible;
      _reconcileAvailability(
        wasReduced: _reducedMotion,
        wasEnabled: wasEnabled,
      );
    }
    if (oldWidget.anchor == widget.anchor &&
        oldWidget.destination == widget.destination &&
        oldWidget.selectionKey == widget.selectionKey &&
        oldWidget.anchorKey == widget.anchorKey) {
      return;
    }
    _requestGeneration++;

    final bool identityChanged =
        oldWidget.selectionKey != widget.selectionKey ||
        oldWidget.anchorKey != widget.anchorKey;
    final Offset? target = _target;
    if (target == null) return;

    if (!identityChanged) {
      // A size/orbit layout change moves every destination together; do not
      // turn that relayout into a fake journey across the map.
      _snapTo(target);
      return;
    }

    if (_reducedMotion) {
      _snapTo(target);
    } else if (_canAnimate) {
      _beginFlight(target);
    } else {
      _suspendAtCurrent(target);
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    final bool wasReduced = _reducedMotion;
    final bool wasEnabled = _canAnimate;
    _platformDisablesMotion = _platformReducedMotion;
    _reconcileAvailability(wasReduced: wasReduced, wasEnabled: wasEnabled);
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool wasEnabled = _canAnimate;
    _appActive = state == AppLifecycleState.resumed;
    _reconcileAvailability(wasReduced: _reducedMotion, wasEnabled: wasEnabled);
  }

  void _reconcileAvailability({
    required bool wasReduced,
    required bool wasEnabled,
  }) {
    if (_reducedMotion) {
      final Offset? target = _target ?? _suspendedTarget;
      if (target != null && (wasEnabled || wasReduced != _reducedMotion)) {
        _snapTo(target);
      }
      return;
    }

    if (!_canAnimate) {
      if (wasEnabled) _suspendFlight();
      return;
    }

    if (!wasEnabled && _suspendedTarget != null) {
      _beginFlight(_suspendedTarget!);
    }
  }

  void _scheduleFlight(Offset target) {
    final int generation = ++_requestGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _requestGeneration) return;
      if (_reducedMotion) {
        _snapTo(target);
      } else if (_canAnimate) {
        _beginFlight(target);
      } else {
        _suspendAtCurrent(target);
      }
    });
  }

  void _beginFlight(Offset target) {
    final Offset start = _renderedPosition ?? widget.anchor ?? target;
    _controller.stop();
    _position = start;
    _flightStart = start;
    _flightEnd = target;
    _suspendedTarget = null;
    if (start == target) {
      _flightActive = false;
      _position = target;
      return;
    }
    _flightActive = true;
    _controller.forward(from: 0);
  }

  void _suspendFlight() {
    if (!_flightActive) return;
    final Offset? target = _flightEnd;
    _suspendAtCurrent(target);
  }

  void _suspendAtCurrent(Offset? target) {
    final Offset? current = _renderedPosition;
    _controller.stop();
    _position = current ?? _position;
    _flightActive = false;
    _flightStart = null;
    _flightEnd = null;
    _suspendedTarget = target;
    if (mounted) setState(() {});
  }

  void _snapTo(Offset target) {
    _requestGeneration++;
    _controller.stop();
    _flightActive = false;
    _flightStart = null;
    _flightEnd = null;
    _suspendedTarget = null;
    _position = target;
    if (mounted) setState(() {});
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_flightActive) return;
    _position = _flightEnd;
    _flightStart = null;
    _flightEnd = null;
    _flightActive = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribeRouteCoverage?.call();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    clipBehavior: Clip.hardEdge,
    children: <Widget>[
      widget.child,
      if (_position != null)
        AnimatedBuilder(
          animation: _controller,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1F7FD8FF),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x665FCBF3),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all((_shipSize - 22) / 2),
                  child: Image.asset(
                    'assets/images/course_map/art/ship_preview.png',
                    key: const ValueKey('course-map-preview-ship'),
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
          builder: (BuildContext context, Widget? ship) {
            final Offset position = _renderedPosition ?? Offset.zero;
            final Offset direction =
                (_flightEnd ?? position) - (_flightStart ?? position);
            final double rotation = direction == Offset.zero
                ? 0
                : math.atan2(direction.dy, direction.dx) + math.pi / 2;
            return Positioned(
              left: position.dx - _shipSize / 2,
              top: position.dy - _shipSize / 2,
              width: _shipSize,
              height: _shipSize,
              child: Transform.rotate(angle: rotation, child: ship),
            );
          },
        ),
    ],
  );
}
