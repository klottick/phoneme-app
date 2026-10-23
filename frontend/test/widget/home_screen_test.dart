import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/home/home_screen.dart';
import '../support/map_motion_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreen', () {
    testWidgets('renders without crashing', (tester) async {
      disableMapMotion(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HomeScreen()),
        ),
      );

      await tester.pump();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('displays the app title', (tester) async {
      disableMapMotion(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HomeScreen()),
        ),
      );

      await tester.pump();
      expect(find.text('Linguist'), findsOneWidget);
    });
  });
}
