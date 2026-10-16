import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';

import '../support/course_learning_widget_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> finishRun(CourseLearningWidgetStore store,
      {required bool recordCompletion}) async {
    var state = store.committedState;
    Future<void> commit(LearningAction action) async {
      final command = store.prepare(
        state: state,
        activityId: 'lesson:en-fr-u-y',
        action: action,
      );
      state = (await store.submit(command)).state;
    }

    await commit(StartLearningRun(options: RunOptions()));
    final definition = LearningRegistry.french().require('lesson:en-fr-u-y');
    for (var i = 0; i < definition.items.length; i++) {
      final item = definition.items[i];
      await commit(ChooseSound(
        selectedSound: item.expectedChoice!,
        audioSource: authoredAudioSource(item)!,
      ));
      await commit(const AdvanceLesson());
    }
    await commit(FinishLearningActivity(recordCompletion: recordCompletion));
  }

  for (final bool hadCompletion in [false, true]) {
    testWidgets(
        'review repeat starts explicitly and Finish preserves history '
        '(completion=$hadCompletion)', (tester) async {
      final store = CourseLearningWidgetStore();
      await finishRun(store, recordCompletion: hadCompletion);
      final before = store.committedState;
      expect(
          before.history.fold<int>(0, (n, batch) => n + batch.attempts.length),
          10);
      final priorCompletions = before.completions;

      final router = GoRouter(
        initialLocation: '/course-lesson/en-fr-u-y?review=true',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/course-lesson/:id',
            builder: (_, state) => DiscoveryLessonScreen(
              lessonId: state.pathParameters['id']!,
              review: state.uri.queryParameters['review'] == 'true',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(_SilentAudio()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Section debrief'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Practise again'), 100);
      await tester.tap(find.text('Practise again'));
      await tester.pumpAndSettle();
      final restarted = store.committedState.activities['lesson:en-fr-u-y']!;
      expect(restarted.cursor.generation,
          before.activities['lesson:en-fr-u-y']!.cursor.generation + 1);
      expect(restarted.snapshot is DiscoveryCheckpoint, isTrue);
      expect(
          (restarted.snapshot as DiscoveryCheckpoint).session.attemptCount, 0);
      expect(store.committedState.history.length, before.history.length,
          reason: 'a run start does not erase prior attempts');
      expect(store.committedState.completions, priorCompletions,
          reason: 'starting a repeat does not change completion history');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(_SilentAudio()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      final items = LearningRegistry.french().require('lesson:en-fr-u-y').items;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        await tester.scrollUntilVisible(find.text('Listen to the word'), 100);
        await tester.tap(find.text('Listen to the word'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
            find.text('/${item.expectedChoice}/'), 100);
        await tester.tap(find.text('/${item.expectedChoice}/'));
        await tester.pumpAndSettle();
        final next = i == items.length - 1
            ? find.text('See section explanation')
            : find.text('Next word');
        await tester.scrollUntilVisible(next, 100);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(find.text('Finish section'), 100);
      await tester.tap(find.text('Finish section'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(store.committedState.completions, priorCompletions,
          reason: 'review Finish is always recordCompletion:false');
      expect(
          store.committedState.history
              .fold<int>(0, (n, batch) => n + batch.attempts.length),
          20);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

class _SilentAudio implements CourseAudio {
  @override
  Future<void> speak(String word) async {}

  @override
  Future<void> stop() async {}
}
