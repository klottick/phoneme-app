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
import 'package:linguist/src/features/drills/drill_screen.dart';

class _Audio implements CourseAudio {
  @override
  Future<void> speak(String word) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('real drill repository cycles, reopens, and counts repeat pairs',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final guest = LearningOwner.guest();
    final scope = LearningScope(courseId: 'en-fr', owner: guest);
    final auth = LearningAuthScope(owner: guest, generation: 0, ready: true);
    final definition = LearningRegistry.french().require('drill:minimal-pairs');
    var token = 0;
    CourseLearningRepository repository() => CourseLearningRepository(
          scope: scope,
          authGeneration: 0,
          currentAuth: () => auth,
          backendOwner: () => guest,
          persistence: PreferencesLearningPersistence(
            preferences: SharedPreferences.getInstance,
          ),
          transitions: LearningTransitionEngine(LearningRegistry.french()),
          clock: () => DateTime.utc(2026, 10, 15),
          newToken: () => (++token).toString().padLeft(22, '0'),
          random: Random(1),
        );
    final audio = _Audio();
    var store = repository();

    Future<void> mount(int index) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(audio),
        ],
        child: const MaterialApp(home: DrillScreen()),
      ));
      final itemFinder = find.text('Item ${index + 1}');
      for (var attempt = 0;
          attempt < 20 && itemFinder.evaluate().isEmpty;
          attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(itemFinder, findsOneWidget);
    }

    Future<void> answerItem(int index) async {
      expect(find.text('Item ${index + 1}'), findsOneWidget);
      await tester.tap(find.byTooltip('Play audio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(
          definition.items[index % definition.items.length].expectedChoice!));
      await tester.pumpAndSettle();
    }

    await mount(0);
    for (var index = 0; index < definition.items.length; index++) {
      await answerItem(index);
    }
    expect(find.text('Item ${definition.items.length + 1}'), findsOneWidget);
    final beforeReopen = await store.load();
    expect(
        (beforeReopen.activities['drill:minimal-pairs']!.snapshot
                as DrillCheckpoint)
            .index,
        definition.items.length);

    await tester.pumpWidget(const SizedBox());
    store = repository();
    final reopened = await store.load();
    expect(
        (reopened.activities['drill:minimal-pairs']!.snapshot
                as DrillCheckpoint)
            .index,
        definition.items.length);
    await mount(definition.items.length);
    await answerItem(definition.items.length);

    final saved = await store.load();
    final attempts = saved.history.expand((batch) => batch.attempts).toList();
    expect(attempts, hasLength(definition.items.length + 1));
    expect(attempts.map((attempt) => attempt.itemId), [
      ...definition.items.map((item) => item.id),
      definition.items.first.id,
    ]);
    expect(attempts.last.presentation, AttemptPresentation.repeatInRun);
    expect(attempts.last.itemOccurrence, 2);
    expect(attempts.map((attempt) => attempt.correct), everyElement(isTrue));
    final lifetimeTargetCounts = attempts.fold<int>(
        0, (total, attempt) => total + attempt.targetSounds.length);
    expect(
        saved.summaries.values
            .fold<int>(0, (total, count) => total + count.total),
        lifetimeTargetCounts);
    expect(
        saved.summaries.values
            .fold<int>(0, (correct, count) => correct + count.correct),
        lifetimeTargetCounts);
  });
}
