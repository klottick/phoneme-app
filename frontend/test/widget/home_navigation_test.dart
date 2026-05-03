import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/main.dart' as app;

void main() {
  testWidgets('app smoke test', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();

    expect(find.text('Linguist'), findsOneWidget);
  });

  testWidgets('home screen shows all feature buttons', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();

    expect(find.text('Identify'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
  });

  testWidgets('tap identify navigates correctly', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Identify'));
    await tester.pumpAndSettle();

    expect(find.text('Identify Phoneme'), findsOneWidget);
  });

  testWidgets('tap test navigates correctly', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();

    expect(find.text('Speaking Test'), findsOneWidget);
  });

  testWidgets('tap explore navigates correctly', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Search'), findsOneWidget);
  });

  testWidgets('settings accessible from home', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Difficulty'), findsOneWidget);
  });

  testWidgets('analytics accessible from home', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Analytics'));
    await tester.pumpAndSettle();

    expect(find.text('Progress'), findsOneWidget);
  });
}