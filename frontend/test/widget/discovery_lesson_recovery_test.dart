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

  Widget app(CourseLearningWidgetStore store) => ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(_SilentAudio()),
        ],
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
        ),
      );

  testWidgets(
      'reopening after failed answer does not restore uncommitted result',
      (tester) async {
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to the word'));
    await tester.pumpAndSettle();
    store.failSubmit = true;
    await tester.tap(find.text('/u/'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget,
        reason: 'pending immediate feedback is visible to the first screen');
    await tester.pumpWidget(const SizedBox());

    store.failSubmit = false;
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    expect(find.text('Item 1 of 10'), findsOneWidget);
    expect(find.text('Correct'), findsNothing,
        reason: 'reopening renders only committed state');
    expect(store.committedState.history, isEmpty);
    await tester.tap(find.text('Listen to the word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('/u/'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next word'));
    await tester.pumpAndSettle();
    expect(find.text('Item 2 of 10'), findsOneWidget);
    expect(store.committedState.history.single.attempts, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('corrupt or future scope stays unavailable without overwrite',
      (tester) async {
    final store = CourseLearningWidgetStore()
      ..failLoad = true
      ..loadFailure = const LearningUnsupportedVersionException();
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(find.text('Retry loading'), findsOneWidget);
    expect(store.submitCalls, 0,
        reason: 'unavailable data never triggers an automatic fresh start');

    store.failLoad = false;
    await tester.tap(find.text('Retry loading'));
    await tester.pumpAndSettle();
    expect(find.text('Item 1 of 10'), findsOneWidget);
    expect(store.submitCalls, 1,
        reason: 'a fresh run starts only after an explicit verified reload');
    await tester.pumpWidget(const SizedBox());
  });
}

class _SilentAudio implements CourseAudio {
  @override
  Future<void> speak(String word) async {}

  @override
  Future<void> stop() async {}
}
