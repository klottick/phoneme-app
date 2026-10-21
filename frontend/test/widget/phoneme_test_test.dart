import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/phoneme_test/phoneme_test_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhonemeTestScreen', () {
    testWidgets('scrolls to initial and hinted recording controls on a small phone', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [phonemeRecordingAvailableProvider.overrideWithValue(false)],
          child: const MaterialApp(home: PhonemeTestScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byTooltip('Recording is not available in this browser'), 120);
      expect(find.byTooltip('Recording is not available in this browser'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Recording is not available in this browser'), 120);
      expect(find.text('Recording is not available in this browser'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Show Hint'));
      await tester.tap(find.text('Show Hint'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Hide Hint'), findsOneWidget);
      await tester.scrollUntilVisible(find.byTooltip('Recording is not available in this browser'), 120);
      expect(find.byTooltip('Recording is not available in this browser'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Recording is not available in this browser'), 120);
      expect(find.text('Recording is not available in this browser'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('recording control is reachable at 390x844', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PhonemeTestScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Say this phoneme:'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Record phoneme'));
      expect(find.byTooltip('Record phoneme'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

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
