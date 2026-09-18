import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/ipa/ipa_explorer_screen.dart';
import 'package:linguist/src/core/providers/app_providers.dart';
import 'package:linguist/src/features/onboarding/onboarding_controller.dart';
import 'package:linguist/src/core/models/phoneme.dart';

void main() {
  group('IpaExplorerScreen', () {
    testWidgets('displays IPA Explorer title', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingControllerProvider.overrideWith((ref) {
              return OnboardingController();
            }),
          ],
          child: const MaterialApp(
            home: IpaExplorerScreen(),
          ),
        ),
      );

      expect(find.text('IPA Explorer'), findsOneWidget);
    });

    testWidgets('shows loading indicator when fetching',
        (WidgetTester tester) async {
      final pending = Completer<List<Phoneme>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [phonemesProvider.overrideWith((ref) => pending.future)],
          child: const MaterialApp(
            home: IpaExplorerScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete([]);
      await tester.pumpAndSettle();
    });
  });
}
