import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/widgets/purposeful_motion.dart';

void main() {
  testWidgets(
    'route_transition_rebuilds_do_not_accumulate_animation_status_listeners',
    (tester) async {
      final primary = _CountingAnimation();
      final secondary = _CountingAnimation();
      late StateSetter rebuild;
      var revision = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Scaffold(
                body: PurposefulRouteTransition(
                  animation: primary,
                  secondaryAnimation: secondary,
                  child: Text('revision $revision'),
                ),
              );
            },
          ),
        ),
      );

      final primaryListenersAfterFirstBuild = primary.statusListenerCount;
      final secondaryListenersAfterFirstBuild = secondary.statusListenerCount;
      for (var i = 0; i < 5; i++) {
        rebuild(() => revision++);
        await tester.pump();
      }

      expect(primary.statusListenerCount, primaryListenersAfterFirstBuild);
      expect(secondary.statusListenerCount, secondaryListenersAfterFirstBuild);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(primary.statusListenerCount, 0);
      expect(secondary.statusListenerCount, 0);
    },
  );
}

class _CountingAnimation extends Animation<double> {
  final Set<VoidCallback> _listeners = <VoidCallback>{};
  final Set<AnimationStatusListener> _statusListeners =
      <AnimationStatusListener>{};

  int get statusListenerCount => _statusListeners.length;

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  double get value => .5;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) =>
      _statusListeners.add(listener);

  @override
  void removeStatusListener(AnimationStatusListener listener) =>
      _statusListeners.remove(listener);
}
