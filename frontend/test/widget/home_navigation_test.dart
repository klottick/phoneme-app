import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/course_learning_widget_store.dart';
import '../support/map_motion_test_support.dart';

Override _comparisonStateOverride() =>
    comparisonLearningStateProvider.overrideWith(
      (ref) async => ComparisonLearningState.empty(
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest()),
      ),
    );

void main() {
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'}),
  );
  testWidgets('course home opens discovery before legacy practice', (
    tester,
  ) async {
    disableMapMotion(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(
            CourseLearningWidgetStore(),
          ),
          _comparisonStateOverride(),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('destination-picker'));
    await tester.tap(picker);
    await tester.pumpAndSettle();
    final discoveryEntry = find.widgetWithText(ListTile, 'Hear the difference');
    expect(discoveryEntry.hitTestable(), findsOneWidget);
    await tester.tap(discoveryEntry);
    await tester.pumpAndSettle();
    final discover = find.text('Start lesson');
    await tester.ensureVisible(discover.first);
    await tester.tap(discover.first);
    await tester.pumpAndSettle();
    expect(find.text('Listening practice'), findsWidgets);
    expect(find.text('Item 1 of 10'), findsOneWidget);
  });
  testWidgets('course progress and settings remain accessible', (tester) async {
    disableMapMotion(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(
            CourseLearningWidgetStore(),
          ),
          _comparisonStateOverride(),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('English → French'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
    expect(
      find.text('Existing lessons (includes discovery pilot): 0/5 complete'),
      findsOneWidget,
    );
  });
}
