import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/onboarding/onboarding_screen.dart';
import 'package:linguist/src/core/providers/app_providers.dart';

void main() {
  group('OnboardingScreen', () {
    testWidgets('displays language selection title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      expect(find.text('Choose learning language'), findsOneWidget);
    });

    testWidgets('displays available languages', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      expect(find.text('English'), findsOneWidget);
      expect(find.text('French'), findsOneWidget);
      expect(find.text('Japanese'), findsOneWidget);
    });
  });
}