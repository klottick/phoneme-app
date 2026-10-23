import 'package:flutter/material.dart';

import '../../core/theme/space_course_colors.dart';
import 'course_map_catalogue.dart';
import 'course_map_state.dart';

class CourseMapCanvas extends StatelessWidget {
  const CourseMapCanvas({
    super.key,
    required this.state,
    required this.selectedBodyId,
    required this.onInspect,
  });

  final CourseMapState state;
  final String? selectedBodyId;
  final ValueChanged<String> onInspect;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 0.94,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final shortest = constraints.maxWidth;
        return Stack(
          children: [
            const Positioned.fill(child: _OrbitalArt()),
            for (final body in state.bodies)
              Positioned(
                left: (body.definition.x * constraints.maxWidth - 56).clamp(
                  0,
                  constraints.maxWidth - 112,
                ),
                top: (body.definition.y * constraints.maxHeight - 40).clamp(
                  0,
                  constraints.maxHeight - 88,
                ),
                width: 112,
                height: 88,
                child: Semantics(
                  label:
                      '${body.definition.title}, ${_role(body.definition.role)}, ${_availability(body)}${body.definition.id == state.currentBodyId ? ', current location, stationary' : ''}',
                  button: true,
                  selected: body.definition.id == selectedBodyId,
                  child: Tooltip(
                    message: body.definition.title,
                    child: InkWell(
                      onTap: () => onInspect(body.definition.id),
                      customBorder: const CircleBorder(),
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: body.definition.id == selectedBodyId
                                  ? 40
                                  : 32,
                              height: body.definition.id == selectedBodyId
                                  ? 40
                                  : 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _bodyColor(body.definition.role),
                                border:
                                    body.definition.id == state.currentBodyId
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
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              body.definition.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: SpaceCourseColors.textPrimary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: shortest * .46,
              top: constraints.maxHeight * .44,
              child: const ExcludeSemantics(
                child: Icon(Icons.circle, size: 28, color: Color(0xFFE6C98F)),
              ),
            ),
          ],
        );
      },
    ),
  );

  static String _role(MapBodyRole role) => switch (role) {
    MapBodyRole.planet => 'planet',
    MapBodyRole.moon => 'moon',
    MapBodyRole.station => 'station',
    MapBodyRole.asteroidField => 'arcade',
  };
  static String _availability(MapBodyState body) => switch (body.readiness) {
    MapReadiness.alpha => body.progress.name,
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
