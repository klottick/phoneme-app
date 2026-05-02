import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/home/home_screen.dart';
import 'package:linguist/src/core/providers/app_providers.dart';
import 'package:linguist/src/features/onboarding/onboarding_controller.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('displays app title', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingControllerProvider.overrideWith((ref) {
              final controller = OnboardingController();
              controller.selectLanguage('en');
              return controller;
            }),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      expect(find.text('Linguist'), findsOneWidget);
    });

    testWidgets('displays today plan section', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingControllerProvider.overrideWith((ref) {
              final controller = OnboardingController();
              controller.selectLanguage('en');
              return controller;
            }),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      expect(find.text("Today's Plan"), findsOneWidget);
    });

    testWidgets('displays navigation buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingControllerProvider.overrideWith((ref) {
              final controller = OnboardingController();
              controller.selectLanguage('en');
              return controller;
            }),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      expect(find.text('Speaking'), findsOneWidget);
      expect(find.text('IPA Explorer'), findsOneWidget);
      expect(find.text('Listening Drill'), findsOneWidget);
      expect(find.text('Due Review'), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
    });

    testWidgets('displays current track language', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingControllerProvider.overrideWith((ref) {
              final controller = OnboardingController();
              controller.selectLanguage('en');
              return controller;
            }),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      expect(find.textContaining('English'), findsOneWidget);
    });
  });
}