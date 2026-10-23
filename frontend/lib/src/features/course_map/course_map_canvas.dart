import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/theme/space_course_colors.dart';
import 'course_map_catalogue.dart';
import 'course_map_motion.dart';
import 'course_map_state.dart';

class CourseMapCanvas extends StatelessWidget {
  const CourseMapCanvas({
    super.key,
    required this.state,
    required this.selectedBodyId,
    required this.onInspect,
    this.focusOrderOffset = 0,
  });

  final CourseMapState state;
  final String? selectedBodyId;
  final ValueChanged<String> onInspect;
  final int focusOrderOffset;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
      final longTitle = state.bodies.any(
        (body) => body.definition.title.length > 32,
      );
      final fallback = width < 370 || largeText || longTitle;
      final height = fallback
          ? math.min(width * .6, 240.0).toDouble()
          : (width / .94).clamp(320.0, 520.0).toDouble();
      final placements = fallback
          ? const <String, Rect>{}
          : _authoredPlacements(state.bodies, width, height);
      final current = state.currentBodyId;
      final hasCurrentBody =
          current != null &&
          state.bodies.any((body) => body.definition.id == current);
      final currentRect = !hasCurrentBody
          ? null
          : fallback
          ? _authoredMarkerRect(state, current, width, height)
          : placements[current];
      return SizedBox(
        height: height,
        child: CourseMapMotion(
          anchor: currentRect?.center,
          child: Stack(
            key: fallback ? const ValueKey('map-list-fallback') : null,
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: _OrbitalArt(
                  radii:
                      state.bodies
                          .map((body) => body.definition.orbitRadius)
                          .toSet()
                          .toList()
                        ..sort(),
                ),
              ),
              for (final body in state.bodies)
                if (fallback)
                  _decorativeBody(body, width, height)
                else
                  _interactiveBody(
                    body,
                    placements[body.definition.id]!.center,
                    state.bodies.indexOf(body),
                    focusOrderOffset,
                  ),
              if (state.currentBodyId case final currentId?)
                if (state.bodies.any((body) => body.definition.id == currentId))
                  Positioned.fromRect(
                    rect: fallback
                        ? _authoredMarkerRect(state, currentId, width, height)
                        : placements[currentId]!,
                    child: const IgnorePointer(
                      child: ExcludeSemantics(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Icon(
                            Icons.navigation,
                            size: 18,
                            color: SpaceCourseColors.ship,
                          ),
                        ),
                      ),
                    ),
                  ),
              Positioned(
                left: width * .46,
                top: height * .44,
                child: const ExcludeSemantics(
                  child: Icon(Icons.circle, size: 28, color: Color(0xFFE6C98F)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _interactiveBody(
    MapBodyState body,
    Offset center,
    int index,
    int offset,
  ) {
    final current = body.definition.id == state.currentBodyId;
    return Positioned(
      left: center.dx - 24,
      top: center.dy - 24,
      width: 48,
      height: 48,
      child: FocusTraversalOrder(
        order: NumericFocusOrder((offset + index).toDouble()),
        child: Semantics(
          key: ValueKey('destination-semantics-${body.definition.id}'),
          sortKey: OrdinalSortKey((offset + index).toDouble()),
          label:
              '${body.definition.title}, ${_role(body.definition.role)}, ${_availability(body)}${current ? ', current location, stationary' : ''}',
          button: true,
          selected: body.definition.id == selectedBodyId,
          child: Tooltip(
            message: body.definition.title,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onInspect(body.definition.id),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    key: ValueKey('body-art-${body.definition.id}'),
                    opacity: _artOpacity(body.readiness),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _bodyColor(body.definition.role),
                        border: current
                            ? Border.all(
                                color: SpaceCourseColors.currentRing,
                                width: 3,
                              )
                            : null,
                        boxShadow: body.definition.id == selectedBodyId
                            ? [
                                const BoxShadow(
                                  color: SpaceCourseColors.currentRing,
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _icon(body.definition.role),
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: SpaceCourseColors.canvas,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: Icon(
                          _readinessIcon(body),
                          size: 16,
                          color: SpaceCourseColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _decorativeBody(MapBodyState body, double width, double height) {
    const size = 44.0;
    return Positioned.fromRect(
      rect: _authoredMarkerRect(state, body.definition.id, width, height),
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Opacity(
            key: ValueKey('body-art-${body.definition.id}'),
            opacity: _artOpacity(body.readiness),
            child: SizedBox(
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _bodyColor(body.definition.role),
                ),
                child: Icon(_icon(body.definition.role), color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _role(MapBodyRole role) => switch (role) {
    MapBodyRole.planet => 'planet',
    MapBodyRole.moon => 'moon',
    MapBodyRole.station => 'station',
    MapBodyRole.asteroidField => 'arcade',
  };
  static double _artOpacity(MapReadiness readiness) => switch (readiness) {
    MapReadiness.alpha => 1,
    MapReadiness.planned => .55,
    MapReadiness.qualificationBlocked => .65,
    MapReadiness.loading => .7,
    MapReadiness.unavailable => .4,
  };
  static IconData _readinessIcon(MapBodyState body) => switch (body.readiness) {
    MapReadiness.alpha => switch (body.progress) {
      MapProgress.unknown => Icons.help_outline,
      MapProgress.notStarted => Icons.radio_button_unchecked,
      MapProgress.resumable => Icons.play_arrow,
      MapProgress.completed => Icons.check_circle_outline,
    },
    MapReadiness.planned => Icons.schedule,
    MapReadiness.qualificationBlocked => Icons.info_outline,
    MapReadiness.loading => Icons.hourglass_empty,
    MapReadiness.unavailable => Icons.error_outline,
  };
  static String _availability(MapBodyState body) => switch (body.readiness) {
    MapReadiness.alpha => switch (body.progress) {
      MapProgress.unknown => 'Progress unknown',
      MapProgress.notStarted => 'Not started',
      MapProgress.resumable => 'In progress',
      MapProgress.completed => 'Completed',
    },
    MapReadiness.planned => 'Coming soon',
    MapReadiness.qualificationBlocked => 'Qualification required',
    MapReadiness.loading => 'Availability loading',
    MapReadiness.unavailable => 'Unavailable',
  };
  static Color _bodyColor(MapBodyRole role) => switch (role) {
    MapBodyRole.planet => const Color(0xFF91A7A5),
    MapBodyRole.moon => const Color(0xFFAAB5C5),
    MapBodyRole.station => const Color(0xFF8799B6),
    MapBodyRole.asteroidField => const Color(0xFFB7A58B),
  };
  static IconData _icon(MapBodyRole role) => switch (role) {
    MapBodyRole.planet => Icons.public,
    MapBodyRole.moon => Icons.circle,
    MapBodyRole.station => Icons.dns,
    MapBodyRole.asteroidField => Icons.scatter_plot,
  };
}

Map<String, Rect> _authoredPlacements(
  List<MapBodyState> bodies,
  double width,
  double height,
) {
  final result = <String, Rect>{};
  for (final body in bodies) {
    final authored = Offset(
      body.definition.x * width,
      body.definition.y * height,
    );
    final candidates = <Offset>[authored];
    for (var radius = 4.0; radius <= 20; radius += 4) {
      for (var step = 0; step < 32; step++) {
        final angle = step * math.pi / 16;
        candidates.add(
          authored + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
        );
      }
    }
    final chosen = candidates.firstWhere((center) {
      if (center.dx < 24 ||
          center.dx > width - 24 ||
          center.dy < 24 ||
          center.dy > height - 24) {
        return false;
      }
      final candidate = Rect.fromCenter(center: center, width: 48, height: 48);
      return result.values.every((placed) => !placed.overlaps(candidate));
    }, orElse: () => authored);
    result[body.definition.id] = Rect.fromCenter(
      center: chosen,
      width: 48,
      height: 48,
    );
  }
  return result;
}

Rect _authoredMarkerRect(
  CourseMapState state,
  String id,
  double width,
  double height,
) {
  final definition = state.bodies
      .firstWhere((body) => body.definition.id == id)
      .definition;
  const markerSize = 44.0;
  return Rect.fromCenter(
    center: Offset(definition.x * width, definition.y * height),
    width: markerSize,
    height: markerSize,
  );
}

class _OrbitalArt extends StatelessWidget {
  const _OrbitalArt({required this.radii});
  final List<double> radii;

  @override
  Widget build(BuildContext context) {
    final maxRadius = radii.isEmpty ? 1.0 : radii.last;
    return ColoredBox(
      color: SpaceCourseColors.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final radius in radii)
            Positioned.fill(
              child: CustomPaint(
                key: ValueKey('orbit-radius-${radius.toStringAsFixed(2)}'),
                painter: _OrbitPainter(radius, maxRadius),
              ),
            ),
          const Positioned.fill(
            child: CustomPaint(painter: _StarFieldPainter()),
          ),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter(this.orbitRadius, this.maxOrbitRadius);

  final double orbitRadius;
  final double maxOrbitRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final maxSemiAxis = math.min(size.width * .47, size.height * .45);
    final radius = orbitRadius / maxOrbitRadius * maxSemiAxis;
    final paint = Paint()
      ..color = SpaceCourseColors.border.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * .47),
        width: radius * 2,
        height: radius * 1.44,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      orbitRadius != oldDelegate.orbitRadius ||
      maxOrbitRadius != oldDelegate.maxOrbitRadius;
}

class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()..color = const Color(0xFFFFE2A3);
    for (final p in [
      const Offset(.12, .1),
      const Offset(.84, .12),
      const Offset(.92, .53),
      const Offset(.15, .79),
      const Offset(.7, .91),
      const Offset(.29, .4),
    ]) {
      canvas.drawCircle(
        Offset(p.dx * size.width, p.dy * size.height),
        1.2,
        starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => false;
}
