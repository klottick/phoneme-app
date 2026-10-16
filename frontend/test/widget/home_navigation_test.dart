import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/course_learning_widget_store.dart';

void main() {
  setUp(() =>
      SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'}));
  testWidgets('course home opens its next lesson', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      courseLearningStoreProvider
          .overrideWithValue(CourseLearningWidgetStore()),
    ], child: const LinguistApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Listen to French word'), findsOneWidget);
    expect(find.text('Listen 1 of 4'), findsOneWidget);
  });
  testWidgets('course progress and settings remain accessible', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      courseLearningStoreProvider
          .overrideWithValue(CourseLearningWidgetStore()),
    ], child: const LinguistApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('English → French'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('0/5 lessons complete'), findsOneWidget);
  });
}
