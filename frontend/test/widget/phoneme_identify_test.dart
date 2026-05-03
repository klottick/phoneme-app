import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/phoneme_id/phoneme_identify_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhonemeIdentifyScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: PhonemeIdentifyScreen()),
        ),
      );

      await tester.pump();
      expect(find.byType(PhonemeIdentifyScreen), findsOneWidget);
    });

    testWidgets('displays the screen title', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: PhonemeIdentifyScreen()),
        ),
      );

      await tester.pump();
      expect(find.text('Phoneme Identification'), findsOneWidget);
    });
  });
}