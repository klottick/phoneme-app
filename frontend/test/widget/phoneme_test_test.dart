import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/phoneme_test/phoneme_test_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhonemeTestScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: PhonemeTestScreen()),
        ),
      );

      await tester.pump();
      expect(find.byType(PhonemeTestScreen), findsOneWidget);
    });

    testWidgets('displays the screen title', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: PhonemeTestScreen()),
        ),
      );

      await tester.pump();
      expect(find.text('Phoneme Test'), findsOneWidget);
    });

    testWidgets('displays the say prompt', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: PhonemeTestScreen()),
        ),
      );

      await tester.pump();
      expect(find.text('Say this phoneme:'), findsOneWidget);
    });

    testWidgets('displays record button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: PhonemeTestScreen()),
        ),
      );

      await tester.pump();
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });
  });
}