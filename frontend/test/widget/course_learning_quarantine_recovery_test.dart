import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/features/course/course_lesson_screen.dart';

class _Audio implements CourseAudio {
  @override
  Future<void> speak(String word) async {}

  @override
  Future<void> stop() async {}
}

class _RollbackFailurePersistence implements LearningPersistence {
  _RollbackFailurePersistence(this.delegate);
  final LearningPersistence delegate;
  bool failNextWrite = false;
  bool failRestore = false;

  @override
  Future<String?> read(String key) => delegate.read(key);

  @override
  Future<void> write(String key, String value) async {
    await delegate.write(key, value);
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('injected write failure');
    }
  }

  @override
  Future<void> restore(String key, String? lastCommitted) {
    if (failRestore) throw StateError('injected rollback repair failure');
    return delegate.restore(key, lastCommitted);
  }

  @override
  Future<void> reload() => delegate.reload();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('quarantined lesson answer recovers via retryLoad without credit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final owner = LearningOwner.guest();
    final scope = LearningScope(courseId: 'en-fr', owner: owner);
    final auth = LearningAuthScope(owner: owner, generation: 0, ready: true);
    var tokenNumber = 0;
    final persistence = _RollbackFailurePersistence(
      PreferencesLearningPersistence(
          preferences: SharedPreferences.getInstance),
    );
    final store = CourseLearningRepository(
      scope: scope,
      authGeneration: 0,
      currentAuth: () => auth,
      backendOwner: () => owner,
      persistence: persistence,
      transitions: LearningTransitionEngine(LearningRegistry.french()),
      clock: () => DateTime.utc(2026, 10, 15),
      newToken: () => (++tokenNumber).toRadixString(36).padLeft(22, '0'),
      random: Random(1),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseLearningStoreProvider.overrideWithValue(store),
        courseAudioProvider.overrideWithValue(_Audio()),
      ],
      child: const MaterialApp(
        home: CourseLessonScreen(lessonId: 'en-fr-vowels'),
      ),
    ));
    await _settle(tester);
    await tester.tap(find.text('Listen to French word'));
    await _settle(tester);
    persistence
      ..failNextWrite = true
      ..failRestore = true;
    await tester.tap(find.text('/i/'));
    await _settle(tester);
    expect(find.text('Retry saving'), findsOneWidget,
        reason: 'the write failure initially remains same-command retryable');

    await tester.tap(find.text('Retry saving'));
    await _settle(tester);
    expect(find.text('Retry saving'), findsNothing);
    expect(find.text('Retry loading'), findsOneWidget,
        reason: 'a quarantined repository requires repair, not resubmission');

    persistence.failRestore = false;
    await tester.tap(find.text('Retry loading'));
    await _settle(tester);
    final recovered = await store.load();
    expect(recovered.history, isEmpty);
    expect(
        recovered.summaries.values
            .fold<int>(0, (total, count) => total + count.total),
        0);
    expect(
        (recovered.activities['lesson:en-fr-vowels']!.snapshot
                as LegacyLessonCheckpoint)
            .selectedSound,
        isNull);
    expect(find.text('Listen 1 of 4'), findsOneWidget);
    expect(find.text('Next word'), findsNothing);
  });
}
