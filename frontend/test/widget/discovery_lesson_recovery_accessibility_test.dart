import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';

import '../support/course_learning_widget_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget pumpLargeScreen(WidgetTester tester, CourseLearningWidgetStore store) {
    return ProviderScope(
      overrides: [
        courseAudioProvider.overrideWithValue(_Audio()),
        courseLearningStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(3),
          ),
          child: child!,
        ),
        home: const DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
      ),
    );
  }

  void setSmallPhone3x(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('unavailable recovery stays scrollable at 360x800 with 3x text',
      (tester) async {
    setSmallPhone3x(tester);
    final store = CourseLearningWidgetStore()..failLoad = true;
    await tester.pumpWidget(pumpLargeScreen(tester, store));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Retry loading'), findsOneWidget);
    store.failLoad = false;
    await tester.scrollUntilVisible(find.text('Retry loading'), 200);
    await tester.tap(find.text('Retry loading'));
    await tester.pumpAndSettle();
    expect(find.text('Item 1 of 10'), findsOneWidget,
        reason: 'recovery remains usable at large accessibility text');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed answer keeps Retry saving reachable at 3x text',
      (tester) async {
    setSmallPhone3x(tester);
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(pumpLargeScreen(tester, store));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Listen to the word'), 200);
    await tester.tap(find.text('Listen to the word'));
    await tester.pumpAndSettle();
    store.failSubmit = true;
    await tester.scrollUntilVisible(find.text('/u/'), 200);
    await tester.tap(find.text('/u/'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('could not be saved'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Retry saving'), 200);
    store.failSubmit = false;
    await tester.tap(find.text('Retry saving'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);
    expect(store.committedState.history.length, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('conflict reload stays reachable and discards local feedback',
      (tester) async {
    setSmallPhone3x(tester);
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(pumpLargeScreen(tester, store));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Listen to the word'), 200);
    await tester.tap(find.text('Listen to the word'));
    await tester.pumpAndSettle();
    store.submitFailure = const LearningConflictException();
    await tester.scrollUntilVisible(find.text('/u/'), 200);
    await tester.tap(find.text('/u/'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Retry saving'), findsNothing);
    await tester.scrollUntilVisible(find.text('Reload saved progress'), 200);
    store.submitFailure = null;
    await tester.tap(find.text('Reload saved progress'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Item 1 of 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

class _Audio implements CourseAudio {
  @override
  Future<void> speak(String word) async {}

  @override
  Future<void> stop() async {}
}
