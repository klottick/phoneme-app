import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/settings/settings_screen.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('renders settings title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsScreen())),
      );

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows language options', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsScreen())),
      );

      expect(find.text('English → French'), findsOneWidget);
    });

    testWidgets('shows about section', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsScreen())),
      );

      expect(find.text('About'), findsOneWidget);
      expect(find.text('Linguist v0.1.0'), findsOneWidget);
    });
  });
}
