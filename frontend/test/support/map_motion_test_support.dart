import 'package:flutter_test/flutter_test.dart';

/// Keeps settle-based tests deterministic without changing bounded motion tests.
void disableMapMotion(WidgetTester tester) {
  tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(() {
    tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
}
