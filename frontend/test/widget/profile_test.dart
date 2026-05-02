import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/profile/profile_screen.dart';

void main() {
  group('ProfileScreen', () {
    testWidgets('renders Profile title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreen()),
        ),
      );

      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('shows not signed in when no user', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreen()),
        ),
      );

      expect(find.textContaining('Not signed in'), findsOneWidget);
    });
  });
}