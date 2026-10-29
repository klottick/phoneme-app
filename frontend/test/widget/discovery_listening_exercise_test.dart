import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
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

  await commit(
    StartLearningRun(
      options: RunOptions(
        policy: LessonPolicy(completionThresholdPercent: 100),
      ),
    ),
  );
  final items = LearningRegistry.french().require('lesson:en-fr-u-y').items;
  for (final item in items) {
    final selected = item.sessionAlias == 'mur'
        ? (item.expectedChoice == 'u' ? 'y' : 'u')
        : item.expectedChoice!;
    await commit(
      ChooseSound(
        selectedSound: selected,
        audioSource: authoredAudioSource(item)!,
      ),
    );
    await commit(const AdvanceLesson());
  }
}

void _expectNoHiddenPayload(WidgetTester tester, Iterable<String> sentinels) {
  final root = tester
      .binding
      .renderViews
      .first
      .owner!
      .semanticsOwner!
      .rootSemanticsNode!;
  final nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  final semanticPayload = nodes
      .expand(
        (node) => [
          node.getSemanticsData().label,
          node.getSemanticsData().value,
          node.getSemanticsData().hint,
          node.getSemanticsData().tooltip,
        ],
      )
      .join('\n');
  for (final sentinel in sentinels) {
    expect(find.textContaining(sentinel), findsNothing, reason: sentinel);
    expect(find.byTooltip(sentinel), findsNothing, reason: sentinel);
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(sentinel))),
      findsNothing,
      reason: sentinel,
    );
    expect(semanticPayload, isNot(contains(sentinel)), reason: sentinel);
  }
}

List<SemanticsNode> _pilotSemanticsSubtree(WidgetTester tester, Finder finder) {
  final nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(finder));
  return nodes;
}

void _expectPilotResponseSemantics(
  WidgetTester tester, {
  required String id,
  required bool selected,
  required bool enabled,
}) {
  final label = '/$id/';
  final labelFinder = find.bySemanticsLabel(
    RegExp(
      '^${RegExp.escape(label)}'
      r'$',
    ),
  );
  expect(labelFinder, findsOneWidget, reason: 'one visible response label');
  final data = tester.getSemantics(labelFinder).getSemanticsData();
  expect(data.label, label);
  expect(data.flagsCollection.isButton, isTrue);
  expect(data.flagsCollection.isSelected.name, selected ? 'isTrue' : 'isFalse');
  expect(data.flagsCollection.isEnabled.name, enabled ? 'isTrue' : 'isFalse');
  expect(data.hasAction(SemanticsAction.tap), enabled);
  final buttonNodes =
      _pilotSemanticsSubtree(tester, find.byKey(ValueKey('choice-$id')))
          .where(
            (node) =>
                !node.isMergedIntoParent &&
                node.getSemanticsData().flagsCollection.isButton,
          )
          .toList();
  expect(
    buttonNodes,
    hasLength(1),
    reason: 'one labeled response node, no extra unlabeled button',
  );
  expect(buttonNodes.single.getSemanticsData().label, label);
}

bool _hasPrimaryFocus(WidgetTester tester, String label) {
  final element = find.text(label).evaluate().single;
  return Focus.of(element).hasPrimaryFocus;
}

Future<void> _tabUntilFocused(WidgetTester tester, String label) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    if (_hasPrimaryFocus(tester, label)) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  }
  expect(
    _hasPrimaryFocus(tester, label),
    isTrue,
    reason: 'keyboard traversal reaches $label',
  );
}

void main() {
  for (final outcome in ['failed', 'cancelled']) {
    testWidgets('failed_or_cancelled_replay_is_unscored ($outcome)', (
      tester,
    ) async {
      final audio = ControlledListeningAudio();
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseAudioProvider.overrideWithValue(audio),
            courseLearningStoreProvider.overrideWithValue(store),
          ],
          child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
          ),
        ),
      );
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
            .widget<ButtonStyleButton>(
              find
                  .ancestor(
                    of: find.text('/u/'),
                    matching: find.bySubtype<ButtonStyleButton>(),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
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
      expect(
        store.prepared.where((command) => command.action is ChooseSound),
        hasLength(1),
      );
      expect(find.text('Correct'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('replay_provider_failure_revokes_prior_hearing', (tester) async {
    final audio = ControlledListeningAudio();
    final store = CourseLearningWidgetStore();
    var failProvider = false;
    final container = ProviderContainer(
      overrides: [
        courseAudioProvider.overrideWith((ref) {
          if (failProvider) throw StateError('hidden-word-sentinel');
          return audio;
        }),
        courseLearningStoreProvider.overrideWithValue(store),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
        ),
      ),
    );
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
          .widget<ButtonStyleButton>(
            find
                .ancestor(
                  of: find.text('/u/'),
                  matching: find.bySubtype<ButtonStyleButton>(),
                )
                .first,
          )
          .onPressed,
      isNull,
    );
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseAudioProvider.overrideWithValue(audio),
          courseLearningStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    audio.requests.single.complete();
    await tester.pumpAndSettle();

    expect(find.byType(ListeningChoice), findsOneWidget);
    expect(
      tester
          .widget<ButtonStyleButton>(
            find
                .ancestor(
                  of: find.text('Listen to the word'),
                  matching: find.bySubtype<ButtonStyleButton>(),
                )
                .first,
          )
          .onPressed,
      isNotNull,
    );
    final beforeReplay = store.committedState;
    final preparedBeforeReplay = store.prepared.length;
    final submittedBeforeReplay = store.submitted.length;

    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    expect(find.text('Playback in progress'), findsOneWidget);
    final replayChoice = tester.widget<ButtonStyleButton>(
      find
          .ancestor(
            of: find.text('/u/'),
            matching: find.bySubtype<ButtonStyleButton>(),
          )
          .first,
    );
    expect(replayChoice.onPressed, isNull);
    expect(store.committedState, same(beforeReplay));
    expect(store.prepared.length, preparedBeforeReplay);
    expect(store.submitted.length, submittedBeforeReplay);

    audio.requests.last.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('/u/'));
    await tester.pumpAndSettle();

    expect(
      store.prepared.where((command) => command.action is ChooseSound),
      hasLength(1),
    );
    expect(find.text('Correct'), findsOneWidget);
    expect(store.committedState.history, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pilot_labeled_response_semantics_activation_is_owner_guarded', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final audio = ControlledListeningAudio();
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseAudioProvider.overrideWithValue(audio),
          courseLearningStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    audio.requests.single.complete();
    await tester.pumpAndSettle();
    _expectPilotResponseSemantics(
      tester,
      id: 'u',
      selected: false,
      enabled: true,
    );
    _expectPilotResponseSemantics(
      tester,
      id: 'y',
      selected: false,
      enabled: true,
    );

    final beforeAnswer = store.committedState;
    final labeledResponse = find.semantics.byLabel(RegExp(r'^/u/$'));
    tester.semantics.performAction(labeledResponse, SemanticsAction.tap);
    tester.semantics.performAction(labeledResponse, SemanticsAction.tap);
    expect(
      store.prepared.where((command) => command.action is ChooseSound),
      hasLength(1),
      reason: 'same-node semantic activation is guarded once',
    );
    expect(
      store.submitted.where((command) => command.action is ChooseSound),
      hasLength(1),
    );
    expect(store.committedState, same(beforeAnswer));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);
    _expectPilotResponseSemantics(
      tester,
      id: 'u',
      selected: true,
      enabled: false,
    );
    _expectPilotResponseSemantics(
      tester,
      id: 'y',
      selected: false,
      enabled: false,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('retained_listen_callback_is_ignored_after_debrief', (
    tester,
  ) async {
    final audio = ControlledListeningAudio();
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseAudioProvider.overrideWithValue(audio),
          courseLearningStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final retainedListen = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Listen to the word'),
        )
        .onPressed!;
    final items = LearningRegistry.french().require('lesson:en-fr-u-y').items;
    for (var index = 0; index < items.length; index++) {
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      audio.requests.last.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('/${items[index].expectedChoice}/'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          index == items.length - 1 ? 'See section explanation' : 'Next word',
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Section debrief'), findsOneWidget);
    final requestCount = audio.requests.length;
    final preparedCount = store.prepared.length;
    retainedListen();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(audio.requests, hasLength(requestCount));
    expect(store.prepared, hasLength(preparedCount));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'replay_and_answer_claim_once_before_redraw_and_retry_is_frozen',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final audio = ControlledListeningAudio();
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseAudioProvider.overrideWithValue(audio),
            courseLearningStoreProvider.overrideWithValue(store),
          ],
          child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      audio.requests.single.complete();
      await tester.pumpAndSettle();

      final beforeReplayCount = audio.requests.length;
      final listen = tester.widget<ButtonStyleButton>(
        find
            .ancestor(
              of: find.text('Listen to the word'),
              matching: find.bySubtype<ButtonStyleButton>(),
            )
            .first,
      );
      listen.onPressed!();
      listen.onPressed!();
      await tester.pump();
      expect(audio.requests, hasLength(beforeReplayCount + 1));
      audio.requests.last.complete();
      await tester.pumpAndSettle();

      final beforeAnswer = store.committedState;
      final requestsBeforeAnswer = audio.requests.length;
      final listenCallback = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Listen to the word'),
          )
          .onPressed!;
      final answerGate = Completer<void>();
      store.actionGates[ChooseSound] = answerGate;
      final choice = tester.widget<ButtonStyleButton>(
        find
            .ancestor(
              of: find.text('/u/'),
              matching: find.bySubtype<ButtonStyleButton>(),
            )
            .first,
      );
      choice.onPressed!();
      choice.onPressed!();
      await tester.pump();
      final answerCommands = store.prepared
          .where((command) => command.action is ChooseSound)
          .toList();
      expect(answerCommands, hasLength(1));
      expect(store.committedState, same(beforeAnswer));
      final originalCommand = store.submitted.last;
      expect(find.text('Correct'), findsOneWidget);
      _expectPilotResponseSemantics(
        tester,
        id: 'u',
        selected: true,
        enabled: false,
      );
      final requestsWhileHeld = audio.requests.length;
      listenCallback();
      choice.onPressed!();
      await tester.pump();
      expect(audio.requests, hasLength(requestsBeforeAnswer));
      expect(
        store.prepared.where((command) => command.action is ChooseSound),
        hasLength(1),
      );
      expect(
        store.submitted.where((command) => command.action is ChooseSound),
        hasLength(1),
      );
      expect(store.committedState, same(beforeAnswer));
      expect(audio.requests, hasLength(requestsWhileHeld));

      store.failingActions.add(ChooseSound);
      answerGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);
      expect(store.committedState, same(beforeAnswer));
      _expectPilotResponseSemantics(
        tester,
        id: 'u',
        selected: true,
        enabled: false,
      );
      final requestsAfterFailure = audio.requests.length;
      listenCallback();
      choice.onPressed!();
      await tester.pump();
      expect(audio.requests, hasLength(requestsAfterFailure));
      expect(
        store.prepared.where((command) => command.action is ChooseSound),
        hasLength(1),
      );
      expect(
        store.submitted.where((command) => command.action is ChooseSound),
        hasLength(1),
      );
      expect(store.committedState, same(beforeAnswer));

      store.failingActions.clear();
      store.actionGates.remove(ChooseSound);
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(store.submitted.last, same(originalCommand));
      expect(
        store.prepared.where((command) => command.action is ChooseSound),
        hasLength(1),
      );
      expect(
        store.submitted.where((command) => command.action is ChooseSound),
        hasLength(2),
      );
      expect(store.committedState.history, hasLength(1));
      expect(store.committedState, isNot(same(beforeAnswer)));

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
      semantics.dispose();
    },
  );

  testWidgets('known_selection_survives_same_owner_suspend_and_frozen_retry', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final audio = ControlledListeningAudio();
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseAudioProvider.overrideWithValue(audio),
          courseLearningStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    audio.requests.single.complete();
    await tester.pumpAndSettle();
    store.failingActions.add(ChooseSound);
    await tester.tap(find.text('/u/'));
    await tester.pumpAndSettle();
    final beforeSuspend = store.committedState;
    expect(find.text('Correct'), findsOneWidget);
    _expectPilotResponseSemantics(
      tester,
      id: 'u',
      selected: true,
      enabled: false,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(store.committedState, same(beforeSuspend));
    expect(find.text('Correct'), findsOneWidget);
    _expectPilotResponseSemantics(
      tester,
      id: 'u',
      selected: true,
      enabled: false,
    );

    store.failingActions.clear();
    final retryGate = Completer<void>();
    store.actionGates[ChooseSound] = retryGate;
    await tester.tap(find.text('Retry saving'));
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    _expectPilotResponseSemantics(
      tester,
      id: 'u',
      selected: true,
      enabled: false,
    );
    expect(store.committedState, same(beforeSuspend));
    retryGate.complete();
    await tester.pumpAndSettle();
    expect(store.committedState.history, hasLength(1));
    _expectPilotResponseSemantics(
      tester,
      id: 'u',
      selected: true,
      enabled: false,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  for (final lifecycleState in [
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.detached,
  ]) {
    testWidgets('${lifecycleState.name}_replay_cannot_unlock_resumed_listen', (
      tester,
    ) async {
      final audio = ControlledListeningAudio();
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseAudioProvider.overrideWithValue(audio),
            courseLearningStoreProvider.overrideWithValue(store),
          ],
          child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
          ),
        ),
      );
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
            .widget<ButtonStyleButton>(
              find
                  .ancestor(
                    of: find.text('/u/'),
                    matching: find.bySubtype<ButtonStyleButton>(),
                  )
                  .first,
            )
            .onPressed,
        isNull,
        reason:
            'the departed replay cannot grant hearing or clear current busy',
      );
      currentListen.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ButtonStyleButton>(
              find
                  .ancestor(
                    of: find.text('/u/'),
                    matching: find.bySubtype<ButtonStyleButton>(),
                  )
                  .first,
            )
            .onPressed,
        isNotNull,
        reason: 'resume only grants hearing after its own fresh success',
      );
      expect(
        store.prepared.where((command) => command.action is ChooseSound),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('departed_replay_cannot_unlock_A_B_A_owner_replacement', (
    tester,
  ) async {
    final audio = ControlledListeningAudio();
    final ownerA = CourseLearningWidgetStore(
      scope: LearningScope(
        courseId: 'en-fr',
        owner: LearningOwner.account('owner-a'),
      ),
    );
    final ownerB = CourseLearningWidgetStore(
      scope: LearningScope(
        courseId: 'en-fr',
        owner: LearningOwner.account('owner-b'),
      ),
    );
    var currentStore = ownerA;
    final container = ProviderContainer(
      overrides: [
        courseAudioProvider.overrideWithValue(audio),
        courseLearningStoreProvider.overrideWith((ref) => currentStore),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
        ),
      ),
    );
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
    expect(
      audio.stopCalls,
      stopCountForCurrentAudio,
      reason: 'the stale owner settlement cannot stop current playback',
    );
    expect(ownerB.committedState, same(ownerBState));
    expect(
      ownerB.prepared.where((command) => command.action is ChooseSound),
      isEmpty,
    );
    expect(
      ownerA.prepared.where((command) => command.action is ChooseSound),
      isEmpty,
    );
    currentListen.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('stale hidden word'), findsNothing);
    expect(
      tester
          .widget<ButtonStyleButton>(
            find
                .ancestor(
                  of: find.text('/u/'),
                  matching: find.bySubtype<ButtonStyleButton>(),
                )
                .first,
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  for (final outcome in ['success', 'failure', 'cancel']) {
    testWidgets('stale_A_replay_${outcome}_cannot_stop_B_owner_playback', (
      tester,
    ) async {
      final audioA = ControlledListeningAudio();
      final audioB = ControlledListeningAudio();
      final ownerA = CourseLearningWidgetStore(
        scope: LearningScope(
          courseId: 'en-fr',
          owner: LearningOwner.account('replay-a'),
        ),
      );
      final ownerB = CourseLearningWidgetStore(
        scope: LearningScope(
          courseId: 'en-fr',
          owner: LearningOwner.account('replay-b'),
        ),
      );
      var currentStore = ownerA;
      var currentAudio = audioA;
      final container = ProviderContainer(
        overrides: [
          courseAudioProvider.overrideWith((ref) => currentAudio),
          courseLearningStoreProvider.overrideWith((ref) => currentStore),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      audioA.requests.single.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      final staleAReplay = audioA.requests.last;

      currentStore = ownerB;
      currentAudio = audioB;
      container.invalidate(courseLearningStoreProvider);
      container.invalidate(courseAudioProvider);
      await tester.pumpAndSettle();
      final bState = ownerB.committedState;
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      expect(audioB.requests, hasLength(1));
      final stopCountWhileBPlaying = audioB.stopCalls;
      if (outcome == 'success') {
        staleAReplay.complete();
      } else if (outcome == 'failure') {
        staleAReplay.fail(cause: StateError('stale A exception sentinel'));
      } else {
        staleAReplay.cancel();
      }
      await tester.pump();
      expect(find.text('Playback in progress'), findsOneWidget);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find
                  .ancestor(
                    of: find.text('/u/'),
                    matching: find.bySubtype<ButtonStyleButton>(),
                  )
                  .first,
            )
            .onPressed,
        isNull,
        reason: 'B has not yet acquired hearing permission',
      );
      expect(
        audioB.stopCalls,
        stopCountWhileBPlaying,
        reason: 'settling A must not stop actively playing B',
      );
      expect(ownerB.committedState, same(bState));
      expect(ownerB.committedState.history, isEmpty);
      expect(ownerB.committedState.mistakes, isEmpty);
      expect(
        ownerB.prepared.where((command) => command.action is ChooseSound),
        isEmpty,
      );
      expect(
        ownerB.submitted.where((command) => command.action is ChooseSound),
        isEmpty,
      );
      expect(tester.takeException(), isNull);

      audioB.requests.single.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ButtonStyleButton>(
              find
                  .ancestor(
                    of: find.text('/u/'),
                    matching: find.bySubtype<ButtonStyleButton>(),
                  )
                  .first,
            )
            .onPressed,
        isNotNull,
        reason: 'only B current successful playback grants hearing',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
  }

  for (final outcome in ['success', 'failure', 'cancel']) {
    testWidgets('disposed_held_replay_${outcome}_cannot_unlock_remount', (
      tester,
    ) async {
      final departedAudio = ControlledListeningAudio();
      final currentAudio = ControlledListeningAudio();
      final store = CourseLearningWidgetStore();
      final overrides = [
        courseLearningStoreProvider.overrideWithValue(store),
        courseAudioProvider.overrideWithValue(departedAudio),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      departedAudio.requests.single.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      final departedReplay = departedAudio.requests.last;
      await tester.pumpWidget(const SizedBox.shrink());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseLearningStoreProvider.overrideWithValue(store),
            courseAudioProvider.overrideWithValue(currentAudio),
          ],
          child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      expect(currentAudio.requests, hasLength(1));
      final stopCount = currentAudio.stopCalls;
      if (outcome == 'success') {
        departedReplay.complete();
      } else if (outcome == 'failure') {
        departedReplay.fail(cause: StateError('departed exception sentinel'));
      } else {
        departedReplay.cancel();
      }
      await tester.pump();
      expect(find.text('Playback in progress'), findsOneWidget);
      expect(currentAudio.stopCalls, stopCount);
      expect(
        store.prepared.where((command) => command.action is ChooseSound),
        isEmpty,
      );
      expect(store.committedState.history, isEmpty);
      expect(tester.takeException(), isNull);
      currentAudio.requests.single.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ButtonStyleButton>(
              find
                  .ancestor(
                    of: find.text('/u/'),
                    matching: find.bySubtype<ButtonStyleButton>(),
                  )
                  .first,
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final isCorrect in [true, false]) {
    testWidgets('restored_answer_does_not_invent_selected_choice '
        '(correct=$isCorrect)', (tester) async {
      final semantics = tester.ensureSemantics();
      final audio = ControlledListeningAudio();
      final store = CourseLearningWidgetStore();
      final overrides = [
        courseAudioProvider.overrideWithValue(audio),
        courseLearningStoreProvider.overrideWithValue(store),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      audio.requests.single.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text(isCorrect ? '/u/' : '/y/'));
      await tester.pumpAndSettle();
      expect(find.text(isCorrect ? 'Correct' : 'Not yet'), findsOneWidget);
      final committed = store.committedState;
      final restoredStore = CourseLearningWidgetStore(initialState: committed);
      final restoredAudio = ControlledListeningAudio();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseAudioProvider.overrideWithValue(restoredAudio),
            courseLearningStoreProvider.overrideWithValue(restoredStore),
          ],
          child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(isCorrect ? 'Correct' : 'Not yet'), findsOneWidget);
      for (final choice in ['u', 'y']) {
        _expectPilotResponseSemantics(
          tester,
          id: choice,
          selected: false,
          enabled: false,
        );
        expect(
          tester
              .widget<ButtonStyleButton>(
                find
                    .ancestor(
                      of: find.text('/$choice/'),
                      matching: find.bySubtype<ButtonStyleButton>(),
                    )
                    .first,
              )
              .onPressed,
          isNull,
          reason: 'answered checkpoints cannot be reanswered',
        );
      }
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Listen to the word'),
            )
            .onPressed,
        isNull,
        reason: 'answered checkpoints cannot replay',
      );
      expect(
        restoredStore.prepared,
        isEmpty,
        reason: 'restore does not invent or resubmit a response',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Next word'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();
      expect(find.text('Item 2 of 10'), findsOneWidget);
      expect(find.text('Correct'), findsNothing);
      expect(find.text('Not yet'), findsNothing);
      for (final choice in ['u', 'y']) {
        _expectPilotResponseSemantics(
          tester,
          id: choice,
          selected: false,
          enabled: false,
        );
        expect(
          restoredStore.prepared.where(
            (command) => command.action is ChooseSound,
          ),
          isEmpty,
          reason: 'advancement must not synthesize a ChooseSound',
        );
      }
      expect(
        tester
            .widget<ButtonStyleButton>(
              find
                  .ancestor(
                    of: find.text('/u/'),
                    matching: find.bySubtype<ButtonStyleButton>(),
                  )
                  .first,
            )
            .onPressed,
        isNull,
        reason: 'the next item requires fresh hearing',
      );
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      restoredAudio.requests.single.complete();
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsNothing);
      expect(find.text('Not yet'), findsNothing);
      expect(
        restoredStore.prepared.where(
          (command) => command.action is ChooseSound,
        ),
        isEmpty,
      );
      _expectPilotResponseSemantics(
        tester,
        id: 'u',
        selected: false,
        enabled: true,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    });
  }

  testWidgets('one_item_review_replay_preserves_repeat_context', (
    tester,
  ) async {
    final store = CourseLearningWidgetStore();
    await _seedDebriefWithMurMistake(store);
    expect(
      store.discoverySession!.unresolvedItemIds,
      isNotEmpty,
      reason: 'typed seed must retain the authored mur mistake',
    );
    final audio = ControlledListeningAudio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseAudioProvider.overrideWithValue(audio),
          courseLearningStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y', review: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Section debrief'), findsOneWidget);
    await tester.tap(find.text('Review mistakes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 1'), findsOneWidget);
    expect(
      tester
          .widget<ButtonStyleButton>(
            find
                .ancestor(
                  of: find.text('/u/'),
                  matching: find.bySubtype<ButtonStyleButton>(),
                )
                .first,
          )
          .onPressed,
      isNull,
      reason: 'review items require fresh listening',
    );
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
    expect(
      find.text('Section debrief'),
      findsNothing,
      reason: 'the debrief waits for explicit Advance acknowledgement',
    );
    final advanceGate = Completer<void>();
    store.actionGates[AdvanceLesson] = advanceGate;
    final beforeFinalAdvance = store.committedState;
    await tester.tap(find.text('See section explanation'));
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Section debrief'), findsNothing);
    expect(find.textContaining('1 of 1'), findsOneWidget);
    expect(store.committedState, same(beforeFinalAdvance));
    advanceGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Section debrief'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pilot_accessibility_survives_extraction', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();
    final audio = ControlledListeningAudio();
    final store = CourseLearningWidgetStore();
    var failProvider = true;
    final container = ProviderContainer(
      overrides: [
        courseAudioProvider.overrideWith((ref) {
          if (failProvider) throw StateError('hidden-exception-sentinel');
          return audio;
        }),
        courseLearningStoreProvider.overrideWithValue(store),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(alphaAudioDisclosure), findsNothing);
    expect(find.text('Section debrief'), findsNothing);
    final section = sectionForLesson('en-fr-u-y')!;
    final tout = section.items.firstWhere((item) => item.id == 'tout');
    _expectNoHiddenPayload(tester, [
      tout.word,
      'all',
      'tu',
      section.explanation,
      'hidden-exception-sentinel',
    ]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      audio.requests,
      isEmpty,
      reason: 'provider failure occurs before playback request creation',
    );
    _expectNoHiddenPayload(tester, [
      tout.word,
      'all',
      'tu',
      section.explanation,
      'hidden-exception-sentinel',
    ]);
    expect(find.textContaining('could not be played'), findsOneWidget);

    failProvider = false;
    container.invalidate(courseAudioProvider);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      audio.requests,
      hasLength(1),
      reason: 'keyboard focus activates the same real Listen action',
    );
    expect(find.text('Playback in progress'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Playback in progress')).label,
      contains('Playback in progress'),
    );
    expect(
      tester
          .getSemantics(find.text('Listen to the word'))
          .getSemanticsData()
          .flagsCollection
          .isButton,
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.text('/u/'))
          .getSemanticsData()
          .flagsCollection
          .isButton,
      isTrue,
    );
    _expectPilotResponseSemantics(
      tester,
      id: 'u',
      selected: false,
      enabled: false,
    );
    expect(
      tester
          .getSemantics(find.text('Listen to the word'))
          .getSemanticsData()
          .flagsCollection
          .isEnabled
          .name,
      'isFalse',
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Listen to the word'),
          )
          .onPressed,
      isNull,
      reason: 'pending playback exposes disabled state',
    );
    audio.requests.single.complete();
    await tester.pumpAndSettle();
    expect(find.text(alphaAudioDisclosure), findsNothing);
    _expectNoHiddenPayload(tester, [
      tout.word,
      'all',
      'tu',
      section.explanation,
      'hidden-exception-sentinel',
    ]);
    await _tabUntilFocused(tester, '/y/');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      store.prepared.where((command) => command.action is ChooseSound),
      hasLength(1),
      reason: 'rapid keyboard Enter admits one answer',
    );
    final answer = store.prepared.singleWhere(
      (command) => command.action is ChooseSound,
    );
    expect((answer.action as ChooseSound).selectedSound, 'y');
    expect(find.text('Not yet'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Not yet')).label,
      contains('Not yet'),
    );
    expect(
      tester
          .getSemantics(find.text('/y/'))
          .getSemanticsData()
          .flagsCollection
          .isEnabled
          .name,
      'isFalse',
    );
    _expectPilotResponseSemantics(
      tester,
      id: 'y',
      selected: true,
      enabled: false,
    );
    _expectPilotResponseSemantics(
      tester,
      id: 'u',
      selected: false,
      enabled: false,
    );
    for (final choiceLabel in ['/u/', '/y/']) {
      expect(
        tester
            .getSemantics(find.text(choiceLabel))
            .getSemanticsData()
            .flagsCollection
            .isEnabled
            .name,
        'isFalse',
        reason: 'answered choice $choiceLabel is semantically disabled',
      );
    }
    expect(
      tester
          .getSemantics(find.text('Listen to the word'))
          .getSemanticsData()
          .flagsCollection
          .isEnabled
          .name,
      'isFalse',
    );
    _expectNoHiddenPayload(tester, [
      tout.word,
      'all',
      'tu',
      section.explanation,
      'hidden-exception-sentinel',
    ]);
    expect(find.text('Retry saving'), findsNothing);
    expect(store.committedState.history, hasLength(1));
    expect(find.text(alphaAudioDisclosure), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
    container.dispose();
  });
}
