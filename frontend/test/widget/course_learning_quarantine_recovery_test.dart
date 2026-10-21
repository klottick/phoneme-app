import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/features/course/course_lesson_screen.dart';
import '../support/course_learning_widget_store.dart';

class _Audio implements CourseAudio {
  @override
  Future<void> speak(String word) async {}

  @override
  Future<void> stop() async {}
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('failed SQL answer remains exact-command retryable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = CourseLearningSqlTestHarness();
    final store = harness.store;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(_Audio()),
        ],
        child: const MaterialApp(
          home: CourseLessonScreen(lessonId: 'en-fr-vowels'),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Listen to French word'));
    await _settle(tester);
    await harness.rejectNextInsertInto('learning_attempts');
    await tester.tap(find.text('/i/'));
    await _settle(tester);
    expect(
      find.text('Retry saving'),
      findsOneWidget,
      reason: 'the write failure initially remains same-command retryable',
    );

    await harness.clearWriteFailure();
    await tester.tap(find.text('Retry saving'));
    await _settle(tester);
    final recovered = await store.load();
    expect(recovered.history, hasLength(1));
    expect(recovered.history.single.attempts, hasLength(1));
    expect(
      recovered.summaries.values.fold<int>(
        0,
        (total, count) => total + count.total,
      ),
      1,
    );
    expect(
      (recovered.activities['lesson:en-fr-vowels']!.snapshot
              as LegacyLessonCheckpoint)
          .selectedSound,
      'i',
    );
    expect(find.text('Listen 1 of 4'), findsOneWidget);
  });
}
