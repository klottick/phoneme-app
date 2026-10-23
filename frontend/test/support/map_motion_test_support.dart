import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

/// Keeps settle-based tests deterministic without changing bounded motion tests.
void disableMapMotion(WidgetTester tester) {
  tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(() {
    tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
}

/// Selects the live discovery body and its explicitly labeled map action.
Future<void> openMapDiscoveryAction(
  WidgetTester tester, {
  required String action,
}) async {
  // Home's router/provider composition is asynchronous. Wait for the initial
  // reduced-motion map before asking Flutter to reveal or hit-test controls.
  await tester.pumpAndSettle();
  final actionButton = find.widgetWithText(FilledButton, action);
  if (actionButton.evaluate().isEmpty) {
    final disclosure = find.text('All destinations');
    if (disclosure.evaluate().isNotEmpty) {
      await tester.ensureVisible(disclosure);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
    }
    final entry = find.widgetWithText(ListTile, 'Hear the difference');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
  }
  final launch = find.widgetWithText(FilledButton, action);
  await tester.ensureVisible(launch);
  await tester.tap(launch);
  await tester.pumpAndSettle();
}
