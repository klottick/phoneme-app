import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/features/course/discovery_section_view.dart';

import '../support/course_learning_widget_store.dart';

const _lessonId = 'lesson:en-fr-u-y';

Future<void> _seedDebrief(CourseLearningWidgetStore store,
    {Set<int> wrongIndexes = const {9}, int percent = 100}) async {
  var state = store.committedState;
  Future<void> commit(LearningAction action) async {
    final command =
        store.prepare(state: state, activityId: _lessonId, action: action);
    state = (await store.submit(command)).state;
  }

  await commit(StartLearningRun(
      options: RunOptions(
          policy: LessonPolicy(completionThresholdPercent: percent))));
  final definition = LearningRegistry.french().require(_lessonId);
  for (var i = 0; i < definition.items.length; i++) {
    final item = definition.items[i];
    await commit(ChooseSound(
      selectedSound: wrongIndexes.contains(i)
          ? (item.expectedChoice == 'u' ? 'y' : 'u')
          : item.expectedChoice!,
      audioSource: authoredAudioSource(item)!,
    ));
    await commit(const AdvanceLesson());
  }
}

Widget _app(CourseLearningWidgetStore store, CourseAudio audio,
        {bool review = false, LessonPolicy? policy}) =>
    ProviderScope(
      overrides: [
        courseLearningStoreProvider.overrideWithValue(store),
        courseAudioProvider.overrideWithValue(audio),
      ],
      child: MaterialApp(
        home: DiscoveryLessonScreen(
            lessonId: 'en-fr-u-y', review: review, policy: policy),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

Future<void> _enterReview(WidgetTester tester) async {
  await tester.tap(find.text('Review mistakes'));
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('failed_one_item_review_returns_to_debrief_without_auto_restart',
      (tester) async {
    final store = CourseLearningWidgetStore();
    await _seedDebrief(store);
    final audio = _TestAudio();
    await tester.pumpWidget(_app(store, audio,
        policy: LessonPolicy(completionThresholdPercent: 80)));
    await _settle(tester);
    expect(find.text('You got 9 of 10 correct.'), findsOneWidget);
    expect(find.text('Passing needs 10 of 10 correct.'), findsOneWidget);
    expect(store.discoverySession!.canComplete, isFalse);
    await _enterReview(tester);
    expect(find.text('Review round 2 · item 1 of 1'), findsOneWidget);
    expect(find.text('Section debrief'), findsNothing);
    expect(find.text('mur'), findsNothing);
    expect(find.text('/u/'), findsOneWidget);
    expect(find.text('/y/'), findsOneWidget);
    expect(_button(tester, '/u/').onPressed, isNull);
    expect(_button(tester, '/y/').onPressed, isNull);
    await tester.tap(find.text('Listen to the word'));
    await _settle(tester);
    final item = LearningRegistry.french().require(_lessonId).items.last;
    await tester.tap(find.text('/${item.expectedChoice == 'u' ? 'y' : 'u'}/'));
    await _settle(tester);
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.text(frenchUySection.explanation), findsNothing);
    await tester.tap(find.text('See section explanation'));
    await _settle(tester);
    expect(find.text('You got 9 of 10 correct.'), findsOneWidget);
    expect(store.discoverySession!.attemptCount, 11);
    expect(store.discoverySession!.unresolvedItemIds, ['mur']);
    expect(store.discoverySession!.round, 2);
    expect(store.discoverySession!.canComplete, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Section debrief'), findsOneWidget);
    expect(store.discoverySession!.round, 2);
    final reviewStartsBefore = store.submitted
        .where((command) => command.action is ReviewDiscoveryMistakes)
        .length;
    await tester.tap(find.text('Review mistakes'));
    await _settle(tester);
    expect(
        store.submitted
            .where((command) => command.action is ReviewDiscoveryMistakes)
            .length,
        reviewStartsBefore + 1);
    expect(store.discoverySession!.round, 3);
    expect(find.text('Review round 3 · item 1 of 1'), findsOneWidget);
    expect(find.text('Section debrief'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('held_review_final_advance_retries_frozen_command',
      (tester) async {
    final store = CourseLearningWidgetStore();
    await _seedDebrief(store);
    await tester.pumpWidget(_app(store, _TestAudio()));
    await _settle(tester);
    await _enterReview(tester);
    await tester.tap(find.text('Listen to the word'));
    await _settle(tester);
    final item = LearningRegistry.french().require(_lessonId).items.last;
    final reviewWrong = item.expectedChoice == 'u' ? 'y' : 'u';
    await tester.tap(find.text('/$reviewWrong/'));
    await _settle(tester);
    final attemptsBefore = store.discoverySession!.attemptCount;
    final historyBefore = store.committedState.history.length;
    final preparesBefore = store.prepareCalls;
    final gate = Completer<void>();
    store.actionGates[AdvanceLesson] = gate;
    await tester.tap(find.text('See section explanation'));
    await tester.pump();
    expect(find.text('Not yet'), findsOneWidget);
    expect(store.discoverySession!.answered, isTrue);
    expect(store.committedState.history.length, historyBefore);
    expect(find.text('Section debrief'), findsNothing);
    expect(_button(tester, '/u/').onPressed, isNull);
    expect(_button(tester, '/y/').onPressed, isNull);
    expect(_button(tester, 'See section explanation').onPressed, isNull);
    final preparedWhileAdvanceHeld = store.prepareCalls;
    await tester.tap(find.text('/u/'));
    await tester.tap(find.text('See section explanation'));
    await tester.pump();
    expect(store.prepareCalls, preparedWhileAdvanceHeld,
        reason: 'pending answer/advance controls must not prepare a command');
    expect(store.submitted.last.action, isA<AdvanceLesson>());
    final originalAdvance = store.submitted.last;
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Section debrief'), findsNothing);
    gate.complete();
    store.actionGates.remove(AdvanceLesson);
    store.failingActions.add(AdvanceLesson);
    await tester.pump();
    await tester.pump();
    expect(find.text('Retry saving'), findsOneWidget);
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.text('Section debrief'), findsNothing);
    store.failingActions.remove(AdvanceLesson);
    await tester.tap(find.text('Retry saving'));
    await _settle(tester);
    expect(store.submitted.last, same(originalAdvance));
    expect(originalAdvance.action, isA<AdvanceLesson>());
    expect(store.prepareCalls, preparesBefore + 1);
    expect(store.discoverySession!.attemptCount, attemptsBefore);
    expect(store.discoverySession!.phase, LessonSectionPhase.debrief);
    expect(store.committedState.history.length, historyBefore);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('remount_after_failed_advance_restores_answer_not_pending_intent',
      (tester) async {
    final store = CourseLearningWidgetStore();
    await _seedDebrief(store);
    await tester.pumpWidget(_app(store, _TestAudio()));
    await _settle(tester);
    await _enterReview(tester);
    await tester.tap(find.text('Listen to the word'));
    await _settle(tester);
    final item = LearningRegistry.french().require(_lessonId).items.last;
    await tester.tap(find.text('/${item.expectedChoice == 'u' ? 'y' : 'u'}/'));
    await _settle(tester);
    store.failingActions.add(AdvanceLesson);
    await tester.tap(find.text('See section explanation'));
    await _settle(tester);
    expect(find.text('Retry saving'), findsOneWidget);
    final committed = store.committedState;
    final historyLength = committed.history.length;
    final attemptCount = store.discoverySession!.attemptCount;
    store.failingActions.remove(AdvanceLesson);
    await tester.pumpWidget(const SizedBox());
    final restored = CourseLearningWidgetStore(initialState: committed);
    await tester.pumpWidget(_app(restored, _TestAudio()));
    await _settle(tester);
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.text('Retry saving'), findsNothing);
    expect(restored.submitted, isEmpty);
    expect(restored.discoverySession!.attemptCount, attemptCount);
    expect(restored.committedState.history.length, historyLength);
    await tester.tap(find.text('See section explanation'));
    await _settle(tester);
    expect(find.text('Section debrief'), findsOneWidget);
    expect(restored.discoverySession!.attemptCount, attemptCount);
    expect(restored.committedState.history.length, historyLength);
    await tester.pumpWidget(const SizedBox());
  });

  for (final cancel in [false, true]) {
    testWidgets('review_audio_unavailable_is_unscored (cancel=$cancel)',
        (tester) async {
      final store = CourseLearningWidgetStore();
      await _seedDebrief(store);
      final audio = _TestAudio()
        ..failure = !cancel
        ..cancel = cancel;
      await tester.pumpWidget(_app(store, audio));
      await _settle(tester);
      await _enterReview(tester);
      final history = store.committedState.history;
      final mistakes = store.committedState.mistakes;
      final attempts = store.discoverySession!.attemptCount;
      final chooseSubmissionsBefore =
          store.submitted.where((c) => c.action is ChooseSound).length;
      await tester.tap(find.text('Listen to the word'));
      await _settle(tester);
      if (cancel) {
        expect(find.textContaining('could not be played'), findsNothing);
      } else {
        expect(find.textContaining('could not be played'), findsOneWidget);
      }
      expect(_button(tester, '/u/').onPressed, isNull);
      expect(_button(tester, '/y/').onPressed, isNull);
      expect(find.text('mur'), findsNothing);
      expect(store.discoverySession!.attemptCount, attempts);
      expect(store.committedState.history, same(history));
      expect(store.committedState.mistakes, same(mistakes));
      expect(store.submitted.where((c) => c.action is ChooseSound).length,
          chooseSubmissionsBefore);
      audio.failure = false;
      audio.cancel = false;
      await tester.tap(find.text('Listen to the word'));
      await _settle(tester);
      final item = LearningRegistry.french().require(_lessonId).items.last;
      await tester.tap(find.text('/${item.expectedChoice}/'));
      await _settle(tester);
      expect(find.text('Correct'), findsOneWidget);
      expect(store.discoverySession!.attemptCount, attempts + 1);
      final attempt = store.committedState.history.last.attempts.single;
      expect(attempt.assistance, contains(AssistanceFlag.afterDebrief));
      expect(attempt.presentation, AttemptPresentation.repeatInRun);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final terminal in ['owner-cycle', 'disposal']) {
    testWidgets('held_review_start_cannot_publish_after_$terminal',
        (tester) async {
      final ownerA = _TestOwner.store('A');
      await _seedDebrief(ownerA);
      final ownerB = _TestOwner.store('B');
      final container = ProviderContainer(overrides: [
        courseLearningStoreProvider.overrideWithValue(ownerA),
        courseAudioProvider.overrideWithValue(_TestAudio()),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y')),
      ));
      await _settle(tester);
      final gate = Completer<void>();
      ownerA.actionGates[ReviewDiscoveryMistakes] = gate;
      await tester.tap(find.text('Review mistakes'));
      await tester.pump();
      expect(ownerA.submitted.last.action, isA<ReviewDiscoveryMistakes>());
      if (terminal == 'owner-cycle') {
        container.updateOverrides([
          courseLearningStoreProvider.overrideWithValue(ownerB),
          courseAudioProvider.overrideWithValue(_TestAudio()),
        ]);
        await tester.pump();
        container.updateOverrides([
          courseLearningStoreProvider.overrideWithValue(ownerA),
          courseAudioProvider.overrideWithValue(_TestAudio()),
        ]);
        await _settle(tester);
      } else {
        await tester.pumpWidget(const SizedBox());
      }
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(ownerA.discoverySession!.phase, LessonSectionPhase.exercise);
      expect(ownerB.committedState.history, isEmpty);
      expect(ownerB.committedState.mistakes, isEmpty);
      expect(ownerB.committedState.completions, isEmpty);
      if (terminal == 'owner-cycle') {
        expect(find.text('Section debrief'), findsOneWidget);
        expect(find.text('Listen to the word'), findsNothing);
      }
    });
  }

  testWidgets(
      'failed_final_advance_retry_intent_is_retired_on_provider_owner_change',
      (tester) async {
    final ownerA = _TestOwner.store('A');
    await _seedDebrief(ownerA);
    final ownerB = _TestOwner.store('B');
    await _seedDebrief(ownerB, wrongIndexes: {8, 9});
    final ownerBBefore = ownerB.committedState;
    final ownerBSubmissionsBefore = ownerB.submitted.length;
    final container = ProviderContainer(overrides: [
      courseLearningStoreProvider.overrideWithValue(ownerA),
      courseAudioProvider.overrideWithValue(_TestAudio()),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const Text('home')),
        GoRoute(
          path: '/course-lesson/:id',
          builder: (_, state) =>
              DiscoveryLessonScreen(lessonId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    router.push('/course-lesson/en-fr-u-y');
    await _settle(tester);
    final initialLocation = router.routeInformationProvider.value.uri;
    await _enterReview(tester);
    await tester.tap(find.text('Listen to the word'));
    await _settle(tester);
    final item = LearningRegistry.french().require(_lessonId).items.last;
    await tester.tap(find.text('/${item.expectedChoice}/'));
    await _settle(tester);
    final attemptsBeforeAdvance = ownerA.discoverySession!.attemptCount;
    final historyBeforeAdvance = ownerA.committedState.history.length;
    ownerA.failingActions.add(AdvanceLesson);
    await tester.tap(find.text('See section explanation'));
    await _settle(tester);
    expect(find.text('Retry saving'), findsOneWidget);
    expect(ownerA.discoverySession!.answered, isTrue);
    expect(ownerA.discoverySession!.attemptCount, attemptsBeforeAdvance);
    expect(ownerA.committedState.history.length, historyBeforeAdvance);
    final pendingAdvance = ownerA.submitted.last;
    expect(pendingAdvance.action, isA<AdvanceLesson>());
    final submissionsAAfterFailure = ownerA.submitted.length;

    container.updateOverrides([
      courseLearningStoreProvider.overrideWithValue(ownerB),
      courseAudioProvider.overrideWithValue(_TestAudio()),
    ]);
    await _settle(tester);

    expect(find.text('Section debrief'), findsOneWidget);
    expect(find.text('Retry saving'), findsNothing,
        reason: 'owner replacement retires the departing owner pending intent');
    expect(find.text('Listen to the word'), findsNothing,
        reason: 'the new owner remains at its own debrief');
    expect(ownerA.submitted.length, submissionsAAfterFailure,
        reason: 'owner change must not replay the frozen Advance');
    expect(ownerB.submitted.length, ownerBSubmissionsBefore,
        reason: 'the old-owner Advance must never be submitted to B');
    expect(ownerB.committedState, same(ownerBBefore));
    expect(ownerB.discoverySession!.phase, LessonSectionPhase.debrief);
    expect(ownerB.discoverySession!.attemptCount, 10);
    expect(router.routeInformationProvider.value.uri, initialLocation,
        reason: 'retiring A retry intent cannot navigate the replacement UI');
    expect(tester.takeException(), isNull);
    ownerA.failingActions.remove(AdvanceLesson);
    await tester.pump(const Duration(seconds: 1));
    expect(ownerA.submitted.length, submissionsAAfterFailure);
    expect(ownerB.committedState, same(ownerBBefore));
    expect(find.text('Section debrief'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('all_wrong_first_pass_debrief_is_available_but_not_passing',
      (tester) async {
    final store = CourseLearningWidgetStore();
    final audio = _TestAudio();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const Text('home')),
        GoRoute(
            path: '/course-lesson/:id',
            builder: (_, state) =>
                DiscoveryLessonScreen(lessonId: state.pathParameters['id']!)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseLearningStoreProvider.overrideWithValue(store),
        courseAudioProvider.overrideWithValue(audio),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    router.push('/course-lesson/en-fr-u-y');
    await _settle(tester);
    final definition = LearningRegistry.french().require(_lessonId);
    for (var index = 0; index < definition.items.length; index++) {
      final item = definition.items[index];
      final word = frenchUySection.items[index].word;
      expect(find.text('Correct'), findsNothing);
      expect(find.text('Not yet'), findsNothing);
      expect(find.text(word), findsNothing);
      expect(
          _semanticsText(tester).contains(frenchUySection.explanation), isFalse,
          reason: 'explanation must stay absent from exercise semantics');
      await tester.tap(find.text('Listen to the word'));
      await _settle(tester);
      final wrong = item.expectedChoice == 'u' ? 'y' : 'u';
      await tester.tap(find.text('/$wrong/'));
      await _settle(tester);
      expect(find.text('Not yet'), findsOneWidget);
      expect(find.text(word), findsNothing);
      expect(find.bySemanticsLabel(word), findsNothing);
      expect(find.text(frenchUySection.title), findsNothing);
      expect(
          _semanticsText(tester).contains(frenchUySection.explanation), isFalse,
          reason: 'wrong feedback must not expose explanation semantics');
      await tester.tap(find.text(item == definition.items.last
          ? 'See section explanation'
          : 'Next word'));
      await _settle(tester);
    }
    expect(find.text(frenchUySection.explanation), findsOneWidget);
    expect(_semanticsText(tester).contains(frenchUySection.explanation), isTrue,
        reason: 'debrief explanation must be available in semantics');
    expect(find.text('You got 0 of 10 correct.'), findsOneWidget);
    expect(_button(tester, 'Finish section').onPressed, isNull);
    expect(store.committedState.mistakes, hasLength(10));
    expect(store.discoverySession!.canComplete, isFalse);
    await tester.tap(find.byTooltip('Back'));
    await _settle(tester);
    expect(find.text('home'), findsOneWidget);
    expect(store.discoverySession!.phase, LessonSectionPhase.debrief);
    expect(store.committedState.mistakes, hasLength(10));
    expect(
        store.submitted
            .where((command) => command.action is ReviewDiscoveryMistakes),
        isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}

ButtonStyleButton _button(WidgetTester tester, String text) =>
    tester.widget<ButtonStyleButton>(find
        .ancestor(
            of: find.text(text),
            matching:
                find.byWidgetPredicate((widget) => widget is ButtonStyleButton))
        .first);

String _semanticsText(WidgetTester tester) {
  final root = tester.getSemantics(find.byType(DiscoverySectionView));
  final text = StringBuffer();
  bool visit(SemanticsNode node) {
    text
      ..writeln(node.label)
      ..writeln(node.value)
      ..writeln(node.hint);
    node.visitChildren(visit);
    return true;
  }

  visit(root);
  return text.toString();
}

final class _TestAudio implements CourseAudio {
  bool failure = false;
  bool cancel = false;
  @override
  Future<void> speak(String word) async {
    if (cancel) throw const CourseAudioCancelledException();
    if (failure) throw StateError('hidden answer $word');
  }

  @override
  Future<void> stop() async {}
}

final class _TestOwner extends CourseLearningWidgetStore {
  _TestOwner.store(String owner)
      : super(
            scope: LearningScope(
                courseId: 'en-fr', owner: LearningOwner.account(owner)));
}
