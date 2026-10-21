import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/profile/profile_screen.dart';

void main() {
  group('ProfileScreen', () {
    testWidgets('renders Profile title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ProfileScreen())),
      );

      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('shows not signed in when no user', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ProfileScreen())),
      );

      expect(find.textContaining('Not signed in'), findsOneWidget);
    });

    testWidgets(
      'does not report a fabricated session total and retains streaks',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: ProfileScreen())),
        );
        await tester.pumpAndSettle();

        expect(find.text('Not measured'), findsOneWidget);
        expect(find.text('Sessions'), findsOneWidget);
        expect(find.text('Day Streak'), findsOneWidget);
        expect(find.text('Best'), findsOneWidget);
        expect(find.text('0'), findsNWidgets(2));
      },
    );
  });
}
