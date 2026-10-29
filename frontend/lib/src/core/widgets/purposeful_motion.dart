import 'package:flutter/material.dart';

/// A short content change that retires the previous subtree from input and
/// semantics as soon as the replacement is built.
///
/// The outgoing child remains painted during its brief exit so the content
/// change reads as a transition, but it can no longer invoke owner callbacks.
class PurposefulSwitcher extends StatefulWidget {
  const PurposefulSwitcher({super.key, required this.child});

  final Widget child;

  @override
  State<PurposefulSwitcher> createState() => _PurposefulSwitcherState();
}

class _PurposefulSwitcherState extends State<PurposefulSwitcher>
    with WidgetsBindingObserver {
  static const Duration _duration = Duration(milliseconds: 240);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _reduceMotion(BuildContext context) {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        features.disableAnimations ||
        features.reduceMotion;
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;

    final Key? currentKey = widget.child.key;
    return AnimatedSwitcher(
      duration: _duration,
      reverseDuration: _duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final bool entering = child.key == currentKey;
        final Animation<double> curved = CurvedAnimation(
          parent: animation,
          curve: entering ? Curves.easeOutCubic : Curves.easeInCubic,
        );
        final Offset begin = entering
            ? const Offset(0, .04)
            : const Offset(0, -.04);
        return FadeTransition(
          opacity: Tween<double>(begin: entering ? .01 : 0, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) =>
          Stack(
            alignment: Alignment.topCenter,
            fit: StackFit.passthrough,
            children: <Widget>[
              for (final Widget previous in previousChildren)
                IgnorePointer(child: ExcludeSemantics(child: previous)),
              if (currentChild != null) currentChild,
            ],
          ),
      child: widget.child,
    );
  }
}

/// Route-level motion for refreshed course screens, including an immediate
/// input/semantics fence on pages covered by a new route.
class PurposefulRouteTransition extends StatefulWidget {
  const PurposefulRouteTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<PurposefulRouteTransition> createState() =>
      _PurposefulRouteTransitionState();
}

class _PurposefulRouteTransitionState extends State<PurposefulRouteTransition>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _reduceMotion(BuildContext context) {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        features.disableAnimations ||
        features.reduceMotion;
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = _reduceMotion(context);
    final Widget animated = reduced
        ? widget.child
        : FadeTransition(
            opacity: Tween<double>(begin: .01, end: 1).animate(
              CurvedAnimation(
                parent: widget.animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, .025),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: widget.animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: widget.child,
            ),
          );

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.animation,
        widget.secondaryAnimation,
      ]),
      child: animated,
      builder: (BuildContext context, Widget? child) {
        final bool outgoing =
            widget.animation.status == AnimationStatus.reverse ||
            widget.secondaryAnimation.status != AnimationStatus.dismissed;
        return IgnorePointer(
          ignoring: outgoing,
          child: ExcludeSemantics(excluding: outgoing, child: child),
        );
      },
    );
  }
}
