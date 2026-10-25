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
      final height = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : (width / .94).clamp(260.0, 520.0).toDouble();
      final placements = _authoredPlacements(state.bodies, width, height);
      final current = state.currentBodyId;
      final hasCurrentBody =
          current != null &&
          state.bodies.any((body) => body.definition.id == current);
      final currentRect = hasCurrentBody ? placements[current] : null;
      return SizedBox(
        height: height,
        child: CourseMapMotion(
          anchor: currentRect?.center,
          child: Stack(
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
                _interactiveBody(
                  body,
                  placements[body.definition.id]!.center,
                  state.bodies.indexOf(body),
                  focusOrderOffset,
                ),
              if (state.currentBodyId case final currentId?)
                if (state.bodies.any((body) => body.definition.id == currentId))
                  Positioned.fromRect(
                    rect: placements[currentId]!,
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
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x66F7B84B),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFFFFB640),
                        BlendMode.modulate,
                      ),
                      child: Image.asset(
                        'assets/images/course_map/art/sun.png',
                        key: const ValueKey('course-map-sun-art'),
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
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
              '${body.definition.title}, ${_role(body.definition.role)}, ${_availability(body)}${current ? ', current location, stationary' : ''}${body.recommended ? ', recommended next' : ''}',
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
                      key: ValueKey('body-art-frame-${body.definition.id}'),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
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
                      child: _bodyIllustration(
                        body.definition.id,
                        body.definition.role,
                        40,
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
                          size: 12,
                          color: SpaceCourseColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (body.recommended)
                    const Positioned(
                      left: 0,
                      top: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: SpaceCourseColors.canvas,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(1),
                          child: Icon(
                            Icons.star,
                            size: 12,
                            color: SpaceCourseColors.ship,
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

  static String _role(MapBodyRole role) => switch (role) {
    MapBodyRole.planet => 'planet',
    MapBodyRole.moon => 'moon',
    MapBodyRole.station => 'station',
    MapBodyRole.asteroidField => 'arcade',
  };

  static Widget _bodyIllustration(String id, MapBodyRole role, double size) {
    final asset = switch (id) {
      'discovery' => 'planet_discovery.png',
      'comparison' => 'planet_comparison.png',
      'context' => 'planet_context.png',
      'spelling' => 'planet_spelling.png',
      'checkpoint' => 'planet_checkpoint.png',
      'coaching' => 'moon.png',
      'review' => 'station_review.png',
      'mixed-comparison' => 'station_mixed.png',
      'sentence-practice' => 'station_sentences.png',
      'arcade' => null,
      _ => null,
    };
    if (asset == null && role != MapBodyRole.asteroidField) {
      return _roleFallback(role, size, key: ValueKey('body-art-image-$id'));
    }
    if (asset != null) {
      return Image.asset(
        'assets/images/course_map/art/$asset',
        key: ValueKey('body-art-image-$id'),
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) =>
            _roleFallback(role, size, key: ValueKey('body-art-fallback-$id')),
      );
    }
    return SizedBox(
      key: ValueKey('body-art-image-$id'),
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            key: const ValueKey('asteroid-cluster-a'),
            left: size * .05,
            top: size * .08,
            child: Image.asset(
              'assets/images/course_map/art/asteroid_small.png',
              key: const ValueKey('asteroid-image-small-a'),
              width: size * .46,
              height: size * .46,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
          Positioned(
            key: const ValueKey('asteroid-cluster-b'),
            right: size * .05,
            top: size * .13,
            child: Image.asset(
              'assets/images/course_map/art/asteroid_large.png',
              key: const ValueKey('asteroid-image-large'),
              width: size * .46,
              height: size * .46,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
          Positioned(
            key: const ValueKey('asteroid-cluster-c'),
            left: size * .12,
            bottom: size * .08,
            child: Image.asset(
              'assets/images/course_map/art/asteroid_small.png',
              key: const ValueKey('asteroid-image-small-b'),
              width: size * .46,
              height: size * .46,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _roleFallback(MapBodyRole role, double size, {Key? key}) =>
      Container(
        key: key,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _bodyColor(role),
        ),
        child: Icon(_icon(role), size: size * .55, color: Colors.white),
      );

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
    for (var radius = 4.0; radius <= 32; radius += 4) {
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
