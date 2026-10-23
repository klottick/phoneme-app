import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative motion isolated from the supplied map and its learning state.
///
/// A host that retains this subtree while hiding it must pair its visibility
/// change with `TickerMode(enabled: visible)`. `Offstage` alone intentionally
/// does not mute descendant tickers; this widget consumes the host's standard
/// `TickerMode` signal and does not poll the render tree for visibility.
class CourseMapMotion extends StatefulWidget {
  const CourseMapMotion({super.key, required this.anchor, required this.child});

  static const orbitPeriod = Duration(seconds: 34);

  final Offset? anchor;
  final Widget child;

  @override
  State<CourseMapMotion> createState() => _CourseMapMotionState();
}

class _CourseMapMotionState extends State<CourseMapMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: CourseMapMotion.orbitPeriod,
  );
  bool _paused = false;
  ModalRoute<dynamic>? _route;

  bool get _reducedMotion {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.disableAnimations || features.reduceMotion;
  }

  void _update() {
    final enabled =
        widget.anchor != null &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
        TickerMode.valuesOf(context).enabled &&
        (_route?.isCurrent ?? true) &&
        !_reducedMotion &&
        !_paused;
    if (enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!enabled && _controller.isAnimating) {
      _controller.stop(canceled: false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _update();
  }

  @override
  void didUpdateWidget(covariant CourseMapMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _update();

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(_update);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (_route != route) _route = route;
    _update();
    final reduced = _reducedMotion;
    final playing = !_paused && !reduced;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.anchor != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: CustomPaint(
                  key: const ValueKey('map-motion-paint'),
                  painter: _MotionPainter(animation: _controller),
                ),
              ),
            ),
          ),
        if (widget.anchor != null)
          AnimatedBuilder(
            animation: _controller,
            child: const _Ship(),
            builder: (context, ship) {
              final angle = -math.pi / 2 + _controller.value * math.pi * 2;
              final radius =
                  math.min(
                    MediaQuery.sizeOf(context).width,
                    MediaQuery.sizeOf(context).height,
                  ) *
                  .075;
              final position =
                  widget.anchor! +
                  Offset(math.cos(angle) * radius, math.sin(angle) * radius);
              return Positioned(
                left: position.dx - 8,
                top: position.dy - 8,
                width: 16,
                height: 16,
                child: IgnorePointer(child: ExcludeSemantics(child: ship!)),
              );
            },
          ),
        Positioned(
          right: 8,
          top: 8,
          child: Semantics(
            button: true,
            label: playing ? 'Pause map motion' : 'Play map motion',
            child: IconButton(
              key: const ValueKey('map-motion-toggle'),
              tooltip: playing ? 'Pause map motion' : 'Play map motion',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: reduced
                  ? null
                  : () => setState(() => _paused = !_paused),
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
          ),
        ),
      ],
    );
  }
}

class _Ship extends StatelessWidget {
  const _Ship();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: ValueKey('map-motion-ship'),
    width: 16,
    height: 16,
    child: CustomPaint(painter: _ShipPainter()),
  );
}

class _ShipPainter extends CustomPainter {
  const _ShipPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width * .9, size.height * .85)
      ..lineTo(size.width / 2, size.height * .68)
      ..lineTo(size.width * .1, size.height * .85)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF70438F));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE6EAF2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ShipPainter oldDelegate) => false;
}

class _MotionPainter extends CustomPainter {
  _MotionPainter({required this.animation}) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation.value;
    final stars = Paint();
    const starPoints = <Offset>[
      Offset(.12, .1),
      Offset(.84, .12),
      Offset(.92, .53),
      Offset(.15, .79),
      Offset(.7, .91),
      Offset(.29, .4),
    ];
    for (var index = 0; index < starPoints.length; index++) {
      final shimmer = .52 + .16 * math.sin(phase * math.pi * 2 + index);
      stars.color = const Color(0xFFFFE2A3).withValues(alpha: shimmer);
      final point = starPoints[index];
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        1.2,
        stars,
      );
    }
    // A short deterministic streak appears once per lap, never randomized.
    if (phase < .07) {
      final progress = phase / .07;
      final comet = Offset(
        size.width * (.08 + progress * .2),
        size.height * .12,
      );
      final trail = Paint()
        ..color = const Color(0xFFE6EAF2).withValues(alpha: .42)
        ..strokeWidth = 1.5;
      canvas.drawLine(comet, comet + const Offset(-15, 6), trail);
      canvas.drawCircle(comet, 1.5, trail);
    }
  }

  @override
  bool shouldRepaint(covariant _MotionPainter oldDelegate) =>
      animation != oldDelegate.animation;
}
