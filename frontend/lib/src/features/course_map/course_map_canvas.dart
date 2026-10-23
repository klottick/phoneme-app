import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/theme/space_course_colors.dart';
import 'course_map_catalogue.dart';
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
      final rows = (state.bodies.length / 3).ceil();
      final height = math.max(width * 1.35, rows * 160.0);
      final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
      final longTitle = state.bodies.any(
        (body) => body.definition.title.length > 32,
      );
      final fallback = width < 370 || largeText || longTitle;
      final placements = fallback
          ? const <String, Rect>{}
          : _placementsForBodies(state.bodies, width, height);
      return SizedBox(
        key: fallback ? const ValueKey('map-list-fallback') : null,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: _OrbitalArt()),
            for (final body in state.bodies)
              if (fallback)
                _decorativeBody(body, width, height)
              else
                _interactiveBody(
                  body,
                  placements[body.definition.id]!,
                  state.bodies.indexOf(body),
                  focusOrderOffset,
                ),
            if (state.currentBodyId case final currentId?)
              if (state.bodies.any((body) => body.definition.id == currentId))
                Positioned.fromRect(
                  rect:
                      (fallback
                              ? _authoredMarkerRect(
                                  state,
                                  currentId,
                                  width,
                                  height,
                                )
                              : placements[currentId]!)
                          .deflate(-2),
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
      );
    },
  );

  Widget _interactiveBody(MapBodyState body, Rect rect, int index, int offset) {
    final current = body.definition.id == state.currentBodyId;
    return Positioned.fromRect(
      rect: rect,
      child: FocusTraversalOrder(
        order: NumericFocusOrder((offset + index).toDouble()),
        child: Semantics(
          key: ValueKey('destination-semantics-${body.definition.id}'),
          sortKey: OrdinalSortKey((offset + index).toDouble()),
          label:
              '${body.definition.title}, ${_role(body.definition.role)}, ${_availability(body)}${current ? ', current location, stationary' : ''}',
          button: true,
          selected: body.definition.id == selectedBodyId,
          child: InkWell(
            onTap: () => onInspect(body.definition.id),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  Text(
                    body.definition.title,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: const TextStyle(
                      color: SpaceCourseColors.textPrimary,
                    ),
                  ),
                  Icon(
                    _readinessIcon(body),
                    size: 18,
                    color: SpaceCourseColors.textSecondary,
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

Map<String, Rect> _placementsForBodies(
  List<MapBodyState> bodies,
  double width,
  double height,
) {
  const columns = 3;
  const itemWidth = 112.0;
  const itemHeight = 156.0;
  final rows = (height / 160).floor();
  final cellWidth = width / columns;
  final cellHeight = height / rows;
  final available = <Rect>[];
  for (var index = 0; index < rows * columns && index < 12; index++) {
    final row = index ~/ columns;
    final column = index % columns;
    available.add(
      Rect.fromLTWH(
        column * cellWidth + (cellWidth - itemWidth) / 2,
        row * cellHeight + (cellHeight - itemHeight) / 2,
        itemWidth,
        itemHeight,
      ),
    );
  }
  final result = <String, Rect>{};
  for (final body in bodies) {
    final target = Offset(
      body.definition.x * width,
      body.definition.y * height,
    );
    available.sort(
      (a, b) => (a.center - target).distanceSquared.compareTo(
        (b.center - target).distanceSquared,
      ),
    );
    result[body.definition.id] = available.removeAt(0);
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
  const _OrbitalArt();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _OrbitPainter());
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(SpaceCourseColors.canvas, BlendMode.src);
    final paint = Paint()
      ..color = SpaceCourseColors.border.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height * .47);
    for (final fraction in [.18, .31, .44, .58, .71]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width * fraction * 2,
          height: size.width * fraction * 1.45,
        ),
        paint,
      );
    }
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
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => false;
}
