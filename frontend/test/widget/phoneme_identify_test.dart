import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/phoneme_id/phoneme_identify_screen.dart';
import 'package:linguist/src/core/models/phoneme.dart';
import 'package:linguist/src/core/providers/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhonemeIdentifyScreen', () {
    testWidgets(
      'offers the correct phoneme exactly once and keeps choices stable',
      (tester) async {
        final items = List.generate(
          8,
          (i) => Phoneme(
            id: '$i',
            languageCode: 'fr',
            ipaSymbol: '/p$i/',
            descriptor: 'word$i',
            difficultyLevel: 1,
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [phonemesProvider.overrideWith((ref) async => items)],
            child: const MaterialApp(home: PhonemeIdentifyScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final initial = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(GridView),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data!)
            .toList();
        expect(initial, hasLength(4));
        expect(initial.where((option) => option == '/p0/'), hasLength(1));

        await tester.tap(find.byIcon(Icons.volume_up));
        await tester.pump();
        final afterPlayback = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(GridView),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data!)
            .toList();
        expect(afterPlayback, initial);
      },
    );

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PhonemeIdentifyScreen())),
      );

      await tester.pump();
      expect(find.byType(PhonemeIdentifyScreen), findsOneWidget);
    });

    testWidgets('displays the screen title', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PhonemeIdentifyScreen())),
      );

      await tester.pump();
      expect(find.text('Phoneme Identification'), findsOneWidget);
    });
  });
}
