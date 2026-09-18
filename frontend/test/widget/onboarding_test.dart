import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/onboarding/onboarding_screen.dart';

void main() {
  group('OnboardingScreen', () {
    testWidgets('displays language selection title',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      expect(find.text('Start English → French'), findsOneWidget);
    });

    testWidgets('displays available languages', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      expect(find.text('I speak English'), findsOneWidget);
      expect(find.text('I want to learn French'), findsOneWidget);
      expect(find.text('Japanese'), findsNothing);
    });
  });
}
