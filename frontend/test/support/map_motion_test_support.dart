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
    await selectMapDestination(tester, 'Hear the difference');
  }
  final launch = find.widgetWithText(FilledButton, action);
  await tester.ensureVisible(launch);
  await tester.tap(launch);
  await tester.pumpAndSettle();
}

/// Selects a destination without launching its primary action.
Future<void> selectMapDestination(WidgetTester tester, String title) async {
  await tester.pumpAndSettle();
  final pickerHeading = find.byKey(
    const ValueKey('destination-picker-heading'),
  );
  if (pickerHeading.evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('destination-picker')));
    await tester.pumpAndSettle();
  }
  final entry = find.widgetWithText(ListTile, title);
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

/// Opens the secondary tools sheet when a test needs recovery controls.
Future<void> openMapTools(WidgetTester tester) async {
  await tester.pumpAndSettle();
  if (find.byKey(const ValueKey('map-tools-heading')).evaluate().isNotEmpty) {
    return;
  }
  await tester.tap(find.byTooltip('More learning tools'));
  await tester.pumpAndSettle();
}
