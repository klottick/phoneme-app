import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/core/providers/app_providers.dart';
import 'package:linguist/src/core/models/phoneme.dart';
import 'package:linguist/src/features/progress/progress_screen.dart';

void main() {
  testWidgets(
    'legacy progress labels goal and mastery as unavailable while preserving phonemes',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            phonemesProvider.overrideWith(
              (ref) async => const [
                Phoneme(
                  id: 'fr-y',
                  languageCode: 'fr',
                  ipaSymbol: 'y',
                  descriptor: 'lune',
                  difficultyLevel: 1,
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: ProgressScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Daily goal tracking is not available.'),
        findsOneWidget,
      );
      expect(find.text('Mastery not measured'), findsOneWidget);
      expect(find.text('2 / 10'), findsNothing);
      expect(find.text('y'), findsOneWidget);
      expect(find.text('lune'), findsOneWidget);
    },
  );
}
