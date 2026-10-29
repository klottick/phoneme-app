import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks route coverage on the app navigator, including non-opaque popup
/// routes such as the course-map sheets.
class CourseMapRouteCoverageObserver extends NavigatorObserver {
  final Map<Route<dynamic>, Set<VoidCallback>> _listeners =
      <Route<dynamic>, Set<VoidCallback>>{};
  final Map<Route<dynamic>, Route<dynamic>> _coveringRouteParents =
      <Route<dynamic>, Route<dynamic>>{};
  final Map<Route<dynamic>, int> _coverCount = <Route<dynamic>, int>{};

  bool isCovered(Route<dynamic> route) => (_coverCount[route] ?? 0) > 0;

  VoidCallback subscribe(Route<dynamic> route, VoidCallback listener) {
    _listeners.putIfAbsent(route, () => <VoidCallback>{}).add(listener);
    return () {
      final Set<VoidCallback>? listeners = _listeners[route];
      listeners?.remove(listener);
      if (listeners?.isEmpty ?? false) _listeners.remove(route);
    };
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute == null) return;
    _coveringRouteParents[route] = previousRoute;
    _changeCoverCount(previousRoute, 1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute == null ||
        !identical(_coveringRouteParents[route], previousRoute)) {
      return;
    }
    if (route is! TransitionRoute<dynamic>) {
      _releaseCover(route);
      return;
    }
    // A route is still visually covering its predecessor while its reverse
    // transition runs. Keep the map frozen until the overlay entry is gone.
    route.completed.then((_) {
      if (identical(_coveringRouteParents[route], previousRoute)) {
        _releaseCover(route);
      }
    });
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _reparentChildren(route, previousRoute);
    _releaseCover(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute == null) return;
    final Route<dynamic>? parent = _coveringRouteParents.remove(oldRoute);
    if (newRoute != null && parent != null) {
      _coveringRouteParents[newRoute] = parent;
    } else if (parent != null) {
      _changeCoverCount(parent, -1);
    }
    if (newRoute != null) _reparentChildren(oldRoute, newRoute);
  }

  void _reparentChildren(
    Route<dynamic> route,
    Route<dynamic>? replacementParent,
  ) {
    final List<Route<dynamic>> children = _coveringRouteParents.entries
        .where((entry) => identical(entry.value, route))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final Route<dynamic> child in children) {
      _changeCoverCount(route, -1);
      if (replacementParent == null) {
        _coveringRouteParents.remove(child);
      } else {
        _coveringRouteParents[child] = replacementParent;
        _changeCoverCount(replacementParent, 1);
      }
    }
  }

  void _releaseCover(Route<dynamic> route) {
    final Route<dynamic>? parent = _coveringRouteParents.remove(route);
    if (parent != null) _changeCoverCount(parent, -1);
  }

  void _changeCoverCount(Route<dynamic> route, int delta) {
    final int oldCount = _coverCount[route] ?? 0;
    final int newCount = oldCount + delta;
    if (newCount <= 0) {
      _coverCount.remove(route);
    } else {
      _coverCount[route] = newCount;
    }
    if ((oldCount == 0) == (newCount == 0)) return;
    for (final VoidCallback listener in List<VoidCallback>.of(
      _listeners[route] ?? const <VoidCallback>{},
    )) {
      listener();
    }
  }

  void dispose() {
    _listeners.clear();
    _coveringRouteParents.clear();
    _coverCount.clear();
  }
}

final courseMapRouteCoverageObserverProvider =
    Provider<CourseMapRouteCoverageObserver>((ref) {
      final CourseMapRouteCoverageObserver observer =
          CourseMapRouteCoverageObserver();
      ref.onDispose(observer.dispose);
      return observer;
    });
