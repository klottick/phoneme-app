import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import '../support/course_learning_widget_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'reopen resumes next unanswered item but requires fresh playback',
    (tester) async {
      final store = CourseLearningWidgetStore();
      var state = await store.load();
      Future<void> commit(LearningAction action) async {
        final command = store.prepare(
          state: state,
          activityId: 'lesson:en-fr-u-y',
          action: action,
        );
        state = (await store.submit(command)).state;
      }

      await commit(StartLearningRun(options: RunOptions()));
      await commit(
        ChooseSound(
          selectedSound: 'u',
          audioSource: AttemptAudioSource.pendingRecording,
        ),
      );
      await commit(const AdvanceLesson());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseLearningStoreProvider.overrideWithValue(store),
            courseAudioProvider.overrideWithValue(_SilentAudio()),
          ],
          child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Item 2 of 10'), findsOneWidget);
      expect(
        find.text('Correct'),
        findsNothing,
        reason: 'feedback for the previous item does not move to the next',
      );
      expect(
        store.committedState.history.single.attempts.single.correct,
        isTrue,
        reason: 'the prior committed result remains in typed history',
      );
      expect(
        tester
            .widgetList<TextButton>(find.byType(TextButton))
            .where((button) => button.onPressed != null),
        isEmpty,
        reason: 'the unanswered item must require fresh playback after resume',
      );
    },
  );

  testWidgets(
    'failed answer blocks advance and retry submits same command once',
    (tester) async {
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseLearningStoreProvider.overrideWithValue(store),
            courseAudioProvider.overrideWithValue(_SilentAudio()),
          ],
          child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      store.failSubmit = true;
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      final original = store.submitted.last;
      expect(find.text('Correct'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Next word'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Retry saving'), findsOneWidget);
      expect(
        store.committedState.history,
        isEmpty,
        reason: 'failed submissions do not publish history',
      );

      store.failSubmit = false;
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(
        store.submitted.length,
        3,
        reason: 'one start, failed answer, and its successful retry',
      );
      expect(
        identical(store.submitted[1], store.submitted[2]),
        isTrue,
        reason: 'Retry resubmits the immutable original command',
      );
      expect(store.committedState.history.single.attempts, hasLength(1));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Next word'),
            )
            .onPressed,
        isNotNull,
      );
      expect(original, same(store.submitted.last));
    },
  );

  testWidgets('A to B to A never publishes a delayed old-generation answer', (
    tester,
  ) async {
    final a = CourseLearningWidgetStore();
    final b = CourseLearningWidgetStore();
    final currentStore = StateProvider<CourseLearningWidgetStore>((_) => a);
    final container = ProviderContainer(
      overrides: [
        courseLearningStoreProvider.overrideWith(
          (ref) => ref.watch(currentStore),
        ),
        courseAudioProvider.overrideWithValue(_SilentAudio()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    a.submitGate = Completer<void>();
    await tester.tap(find.text('Listen to the word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('/u/'));
    await tester.pump();

    container.read(currentStore.notifier).state = b;
    await tester.pumpAndSettle();
    container.read(currentStore.notifier).state = a;
    await tester.pumpAndSettle();
    expect(find.text('Item 1 of 10'), findsOneWidget);
    a.submitGate!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Correct'),
      findsNothing,
      reason: 'the original A generation cannot publish after A→B→A',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late departed owner commit cannot seed the new owner command', (
    tester,
  ) async {
    final a = CourseLearningWidgetStore();
    final b = CourseLearningWidgetStore();
    final currentStore = StateProvider<CourseLearningWidgetStore>((_) => a);
    final container = ProviderContainer(
      overrides: [
        courseLearningStoreProvider.overrideWith(
          (ref) => ref.watch(currentStore),
        ),
        courseAudioProvider.overrideWithValue(_SilentAudio()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    a.submitGate = Completer<void>();
    await tester.tap(find.text('Listen to the word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('/u/'));
    await tester.pump();
    container.read(currentStore.notifier).state = b;
    await tester.pumpAndSettle();
    a.submitGate!.complete();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listen to the word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('/u/'));
    await tester.pumpAndSettle();
    expect(
      find.text('Reload saved progress'),
      findsNothing,
      reason: 'the active owner prepares from its own loaded state',
    );
    expect(b.committedState.history, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
}

class _SilentAudio implements CourseAudio {
  @override
  Future<void> speak(String word) async {}

  @override
  Future<void> stop() async {}
}
