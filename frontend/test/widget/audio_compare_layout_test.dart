import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/audio/audio_compare_screen.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1280, 900),
  ]) {
    testWidgets('instructions and recording control reachable at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AudioCompareScreen())),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(find.text('How to use:'), 120);
      expect(find.text('How to use:'), findsOneWidget);
      expect(
        find.text('4. Listen for differences in clarity and tone'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Record your pronunciation'),
        -120,
      );
      expect(find.byTooltip('Record your pronunciation'), findsOneWidget);
      expect(find.text('Play Reference'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
