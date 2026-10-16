import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/features/course/exercises/listening_choice.dart';
import '../support/controlled_listening_audio.dart';
import '../support/course_learning_widget_store.dart';

Future<void> _seedDebriefWithMurMistake(CourseLearningWidgetStore store) async {
  var state = store.committedState;
  Future<void> commit(LearningAction action) async {
    final command = store.prepare(
      state: state,
      activityId: 'lesson:en-fr-u-y',
      action: action,
    );
    state = (await store.submit(command)).state;
  }

  await commit(StartLearningRun(
      options:
          RunOptions(policy: LessonPolicy(completionThresholdPercent: 100))));
  final items = LearningRegistry.french().require('lesson:en-fr-u-y').items;
  for (final item in items) {
    final selected = item.sessionAlias == 'mur'
        ? (item.expectedChoice == 'u' ? 'y' : 'u')
        : item.expectedChoice!;
    await commit(ChooseSound(
      selectedSound: selected,
      audioSource: authoredAudioSource(item)!,
    ));
    await commit(const AdvanceLesson());
  }
}

void main() {
  for (final outcome in ['failed', 'cancelled']) {
    testWidgets('failed_or_cancelled_replay_is_unscored ($outcome)',
        (tester) async {
      final audio = ControlledListeningAudio();
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          courseAudioProvider.overrideWithValue(audio),
          courseLearningStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      audio.requests.single.complete();
      await tester.pumpAndSettle();

      final beforeReplay = store.committedState;
      final preparedBeforeReplay = store.prepared.length;
      final submittedBeforeReplay = store.submitted.length;
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      if (outcome == 'failed') {
        audio.requests.last.fail(cause: StateError('secret hidden word'));
      } else {
        audio.requests.last.cancel();
      }
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<ButtonStyleButton>(find
                  .ancestor(
                    of: find.text('/u/'),
                    matching: find.bySubtype<ButtonStyleButton>(),
                  )
                  .first)
              .onPressed,
          isNull);
      expect(store.prepared.length, preparedBeforeReplay);
      expect(store.submitted.length, submittedBeforeReplay);
      expect(store.committedState, same(beforeReplay));
      expect(find.textContaining('secret hidden word'), findsNothing);
      if (outcome == 'failed') {
        expect(find.textContaining('could not be played'), findsOneWidget);
      }

      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      audio.requests.last.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(store.prepared.where((command) => command.action is ChooseSound),
          hasLength(1));
      expect(find.text('Correct'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('replay_provider_failure_revokes_prior_hearing', (tester) async {
    final audio = ControlledListeningAudio();
    final store = CourseLearningWidgetStore();
    var failProvider = false;
    final container = ProviderContainer(overrides: [
      courseAudioProvider.overrideWith((ref) {
        if (failProvider) throw StateError('hidden-word-sentinel');
        return audio;
      }),
      courseLearningStoreProvider.overrideWithValue(store),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    audio.requests.single.complete();
    await tester.pumpAndSettle();

    failProvider = true;
    container.invalidate(courseAudioProvider);
    final beforeReplay = store.committedState;
    final preparedBeforeReplay = store.prepared.length;
    await tester.tap(find.text('Listen to the word'));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<ButtonStyleButton>(find
                .ancestor(
                  of: find.text('/u/'),
                  matching: find.bySubtype<ButtonStyleButton>(),
                )
                .first)
            .onPressed,
        isNull);
    expect(find.textContaining('could not be played'), findsOneWidget);
    expect(find.textContaining('hidden-word-sentinel'), findsNothing);
    expect(store.prepared.length, preparedBeforeReplay);
    expect(store.committedState, same(beforeReplay));

    failProvider = false;
    container.invalidate(courseAudioProvider);
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    audio.requests.last.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('/u/'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('pilot_uses_reusable_choice_and_allows_replay', (tester) async {
    final audio = ControlledListeningAudio();
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseAudioProvider.overrideWithValue(audio),
        courseLearningStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(
        home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    audio.requests.single.complete();
    await tester.pumpAndSettle();

    expect(find.byType(ListeningChoice), findsOneWidget);
    expect(
        tester
            .widget<ButtonStyleButton>(find
                .ancestor(
                  of: find.text('Listen to the word'),
                  matching: find.bySubtype<ButtonStyleButton>(),
                )
                .first)
            .onPressed,
        isNotNull);
    final beforeReplay = store.committedState;
    final preparedBeforeReplay = store.prepared.length;
    final submittedBeforeReplay = store.submitted.length;

    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    expect(find.text('Playback in progress'), findsOneWidget);
    final replayChoice = tester.widget<ButtonStyleButton>(find
        .ancestor(
          of: find.text('/u/'),
          matching: find.bySubtype<ButtonStyleButton>(),
        )
        .first);
    expect(replayChoice.onPressed, isNull);
    expect(store.committedState, same(beforeReplay));
    expect(store.prepared.length, preparedBeforeReplay);
    expect(store.submitted.length, submittedBeforeReplay);

    audio.requests.last.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('/u/'));
    await tester.pumpAndSettle();

    expect(store.prepared.where((command) => command.action is ChooseSound),
        hasLength(1));
    expect(find.text('Correct'), findsOneWidget);
    expect(store.committedState.history, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('replay_and_answer_claim_once_before_redraw_and_retry_is_frozen',
      (tester) async {
    final audio = ControlledListeningAudio();
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseAudioProvider.overrideWithValue(audio),
        courseLearningStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(
        home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    audio.requests.single.complete();
    await tester.pumpAndSettle();

    final beforeReplayCount = audio.requests.length;
    final listen = tester.widget<ButtonStyleButton>(find
        .ancestor(
          of: find.text('Listen to the word'),
          matching: find.bySubtype<ButtonStyleButton>(),
        )
        .first);
    listen.onPressed!();
    listen.onPressed!();
    await tester.pump();
    expect(audio.requests, hasLength(beforeReplayCount + 1));
    audio.requests.last.complete();
    await tester.pumpAndSettle();

    store.failingActions.add(ChooseSound);
    final choice = tester.widget<ButtonStyleButton>(find
        .ancestor(
          of: find.text('/u/'),
          matching: find.bySubtype<ButtonStyleButton>(),
        )
        .first);
    choice.onPressed!();
    choice.onPressed!();
    await tester.pumpAndSettle();
    final answerCommands = store.prepared
        .where((command) => command.action is ChooseSound)
        .toList();
    expect(answerCommands, hasLength(1));
    final originalCommand = store.submitted.last;
    expect(find.text('Correct'), findsOneWidget);
    final stateBeforeAcknowledgement = store.committedState;
    expect(store.committedState.history, isEmpty);

    store.failingActions.clear();
    await tester.tap(find.text('Retry saving'));
    await tester.pumpAndSettle();
    expect(store.submitted.last, same(originalCommand));
    expect(store.prepared.where((command) => command.action is ChooseSound),
        hasLength(1));
    expect(store.committedState.history, hasLength(1));
    expect(store.committedState, isNot(same(stateBeforeAcknowledgement)));

    final advanceGate = Completer<void>();
    store.actionGates[AdvanceLesson] = advanceGate;
    final beforeAdvance = store.committedState;
    await tester.tap(find.text('Next word'));
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Item 1 of 10'), findsOneWidget);
    expect(store.committedState, same(beforeAdvance));
    advanceGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Item 2 of 10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final lifecycleState in [
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.detached,
  ]) {
    testWidgets('${lifecycleState.name}_replay_cannot_unlock_resumed_listen',
        (tester) async {
      final audio = ControlledListeningAudio();
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          courseAudioProvider.overrideWithValue(audio),
          courseLearningStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      audio.requests.single.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      final departedReplay = audio.requests.last;

      tester.binding.handleAppLifecycleStateChanged(lifecycleState);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      final currentListen = audio.requests.last;
      expect(currentListen, isNot(same(departedReplay)));

      departedReplay.complete();
      await tester.pump();
      expect(find.text('Playback in progress'), findsOneWidget);
      expect(
          tester
              .widget<ButtonStyleButton>(find
                  .ancestor(
                    of: find.text('/u/'),
                    matching: find.bySubtype<ButtonStyleButton>(),
                  )
                  .first)
              .onPressed,
          isNull,
          reason:
              'the departed replay cannot grant hearing or clear current busy');
      currentListen.complete();
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<ButtonStyleButton>(find
                  .ancestor(
                    of: find.text('/u/'),
                    matching: find.bySubtype<ButtonStyleButton>(),
                  )
                  .first)
              .onPressed,
          isNotNull,
          reason: 'resume only grants hearing after its own fresh success');
      expect(store.prepared.where((command) => command.action is ChooseSound),
          isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('departed_replay_cannot_unlock_A_B_A_owner_replacement',
      (tester) async {
    final audio = ControlledListeningAudio();
    final ownerA = CourseLearningWidgetStore(
        scope: LearningScope(
            courseId: 'en-fr', owner: LearningOwner.account('owner-a')));
    final ownerB = CourseLearningWidgetStore(
        scope: LearningScope(
            courseId: 'en-fr', owner: LearningOwner.account('owner-b')));
    var currentStore = ownerA;
    final container = ProviderContainer(overrides: [
      courseAudioProvider.overrideWithValue(audio),
      courseLearningStoreProvider.overrideWith((ref) => currentStore),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child:
          const MaterialApp(home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y')),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    audio.requests.single.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    final departedReplay = audio.requests.last;
    currentStore = ownerB;
    container.invalidate(courseLearningStoreProvider);
    await tester.pumpAndSettle();
    final ownerBState = ownerB.committedState;
    currentStore = ownerA;
    container.invalidate(courseLearningStoreProvider);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    final currentListen = audio.requests.last;
    final stopCountForCurrentAudio = audio.stopCalls;
    departedReplay.fail(cause: StateError('stale hidden word'));
    await tester.pump();
    expect(find.text('Playback in progress'), findsOneWidget);
    expect(audio.stopCalls, stopCountForCurrentAudio,
        reason: 'the stale owner settlement cannot stop current playback');
    expect(ownerB.committedState, same(ownerBState));
    expect(ownerB.prepared.where((command) => command.action is ChooseSound),
        isEmpty);
    expect(ownerA.prepared.where((command) => command.action is ChooseSound),
        isEmpty);
    currentListen.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('stale hidden word'), findsNothing);
    expect(
        tester
            .widget<ButtonStyleButton>(find
                .ancestor(
                  of: find.text('/u/'),
                  matching: find.bySubtype<ButtonStyleButton>(),
                )
                .first)
            .onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('restored_answer_does_not_invent_selected_choice',
      (tester) async {
    final audio = ControlledListeningAudio();
    final store = CourseLearningWidgetStore();
    final overrides = [
      courseAudioProvider.overrideWithValue(audio),
      courseLearningStoreProvider.overrideWithValue(store),
    ];
    await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    audio.requests.single.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('/u/'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);
    final answerCount =
        store.prepared.where((command) => command.action is ChooseSound).length;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'))));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Not yet'), findsNothing);
    expect(
        tester
            .getSemantics(find
                .ancestor(
                  of: find.text('/u/'),
                  matching: find.bySubtype<ButtonStyleButton>(),
                )
                .first)
            .getSemanticsData()
            .flagsCollection
            .isSelected
            .name,
        'none');
    expect(store.prepared.where((command) => command.action is ChooseSound),
        hasLength(answerCount));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Next word'))
            .onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('one_item_review_replay_preserves_repeat_context',
      (tester) async {
    final store = CourseLearningWidgetStore();
    await _seedDebriefWithMurMistake(store);
    expect(store.discoverySession!.unresolvedItemIds, isNotEmpty,
        reason: 'typed seed must retain the authored mur mistake');
    final audio = ControlledListeningAudio();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseAudioProvider.overrideWithValue(audio),
        courseLearningStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(
        home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y', review: true),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Section debrief'), findsOneWidget);
    await tester.tap(find.text('Review mistakes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 1'), findsOneWidget);
    expect(
        tester
            .widget<ButtonStyleButton>(find
                .ancestor(
                  of: find.text('/u/'),
                  matching: find.bySubtype<ButtonStyleButton>(),
                )
                .first)
            .onPressed,
        isNull,
        reason: 'review items require fresh listening');
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    audio.requests.last.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    audio.requests.last.complete();
    await tester.pumpAndSettle();
    final mur = LearningRegistry.french()
        .require('lesson:en-fr-u-y')
        .items
        .singleWhere((item) => item.sessionAlias == 'mur');
    await tester.tap(find.text('/${mur.expectedChoice}/'));
    await tester.pumpAndSettle();
    final attempt = store.committedState.history.last.attempts.single;
    expect(attempt.itemOccurrence, 2);
    expect(attempt.presentation, AttemptPresentation.repeatInRun);
    expect(attempt.assistance, contains(AssistanceFlag.afterDebrief));
    expect(store.discoverySession!.attemptCount, 11);
    expect(store.discoverySession!.policy.requiredCorrect(10), 10);
    expect(find.text('Section debrief'), findsNothing,
        reason: 'the debrief waits for explicit Advance acknowledgement');
    await tester.tap(find.text('See section explanation'));
    await tester.pumpAndSettle();
    expect(find.text('Section debrief'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pilot_accessibility_survives_extraction', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();
    final audio = ControlledListeningAudio();
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseAudioProvider.overrideWithValue(audio),
        courseLearningStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(
        home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text(alphaAudioDisclosure), findsOneWidget);
    expect(find.text('mur'), findsNothing);
    expect(find.text('wall'), findsNothing);
    expect(find.text('Section debrief'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(audio.requests, hasLength(1),
        reason: 'keyboard focus activates the same real Listen action');
    expect(find.text('Playback in progress'), findsOneWidget);
    expect(
        tester
            .getSemantics(find.text('Listen to the word'))
            .getSemanticsData()
            .flagsCollection
            .isButton,
        isTrue);
    expect(
        tester
            .getSemantics(find.byKey(const ValueKey('choice-u')))
            .getSemanticsData()
            .flagsCollection
            .isButton,
        isTrue);
    audio.requests.single.complete();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('/y/'), 120);
    await tester.tap(find.text('/y/'));
    await tester.pumpAndSettle();
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.text('mur'), findsNothing);
    expect(find.text('wall'), findsNothing);
    expect(find.text('Tu or tout?'), findsNothing);
    expect(find.text(alphaAudioDisclosure), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });
}
