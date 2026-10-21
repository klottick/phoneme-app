import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/features/arcade/arcade_screen.dart';
import 'package:linguist/src/features/arcade/sound_match_engine.dart';
import '../support/course_learning_widget_store.dart';

final _activeStoreProvider = StateProvider<CourseLearningStore>(
    (ref) => throw StateError('test store must be overridden'));

final class _HeldCueAudio implements CourseAudio {
  final List<Completer<void>> cues = [];
  int stops = 0;

  @override
  Future<void> speak(String word) {
    final cue = Completer<void>();
    cues.add(cue);
    return cue.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

final class _RecordingAudio implements CourseAudio {
  final spoken = <String>[];

  @override
  Future<void> speak(String word) async => spoken.add(word);

  @override
  Future<void> stop() async {}
}

void main() {
  for (final invalidOldPoolBoard in [false, true]) {
    testWidgets(
        'stale arcade revision waits for explicit fresh run, invalid old pool = $invalidOldPoolBoard',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = CourseLearningWidgetStore();
      const lessonId = 'lesson:en-fr-vowels';
      var state = store.committedState;
      state = (await store.submit(store.prepare(
        state: state,
        activityId: lessonId,
        action: StartLearningRun(options: RunOptions()),
      )))
          .state;
      final lessonItem =
          LearningRegistry.french().require(lessonId).items.first;
      final wrongChoice = lessonItem.choices
          .firstWhere((choice) => choice != lessonItem.expectedChoice);
      state = (await store.submit(store.prepare(
        state: state,
        activityId: lessonId,
        action: ChooseSound(
          selectedSound: wrongChoice,
          audioSource: AttemptAudioSource.pendingRecording,
        ),
      )))
          .state;
      final oldBoard = invalidOldPoolBoard
          ? SoundBoardState(
              board: List.filled(36, 'retired-pool'), stars: const {})
          : SoundMatchEngine(random: Random(7)).snapshot();
      final oldCursor = SlotCursor(generation: 1, sequence: 1, revision: 0);
      final oldSlot = ActivitySlot(
        activityId: 'arcade:sound',
        kind: LearningActivityKind.soundGame,
        contentRevision: 2,
        cursor: oldCursor,
        options: RunOptions(),
        snapshot: SoundGameCheckpoint(
          board: oldBoard,
          clock: ArcadeClockState(
            remaining: 41,
            round: 3,
            score: 29,
            paused: true,
          ),
        ),
        exposures: const {},
        latestReceipt: CommandReceipt(
          token: 'AAAAAAAAAAAAAAAAAAAAAA',
          canonicalCommand: 'saved-old-content-board',
          before: SlotCursor(generation: 0, sequence: 0, revision: 0),
          after: oldCursor,
          commitOrdinal: state.commitOrdinal,
        ),
      );
      state = CourseLearningState(
        scope: state.scope,
        revision: state.revision,
        commitOrdinal: state.commitOrdinal,
        history: state.history,
        activities: {...state.activities, 'arcade:sound': oldSlot},
        mistakes: state.mistakes,
        summaries: state.summaries,
        completions: state.completions,
        bestScores: const {'arcade:sound': 17, 'arcade:word': 8},
        pending: state.pending,
      );
      store.seedCommittedState(state);
      store.submitted.clear();
      store.prepared.clear();
      final audio = _RecordingAudio();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(audio),
        ],
        child: const MaterialApp(home: ArcadeScreen(silent: false)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Start new run'), findsOneWidget);
      expect(find.text('Resume saved board'), findsNothing);
      expect(store.submitted, isEmpty,
          reason:
              'loading a stale slot must not mutate it or observe assistance');
      expect(
          store.committedState.activities['arcade:sound']!.contentRevision, 2);
      expect(audio.spoken, isEmpty,
          reason: 'stale content does not grant cue or heard permission');

      await tester.tap(find.text('Start new run'));
      await tester.pumpAndSettle();

      final start = store.prepared.singleWhere((command) =>
          command.activityId == 'arcade:sound' &&
          command.action is StartLearningRun);
      expect(start.expected.generation, oldCursor.generation);
      expect(start.expected.sequence, oldCursor.sequence);
      expect(start.expected.revision, oldCursor.revision);
      final after = store.committedState;
      final freshSlot = after.activities['arcade:sound']!;
      final freshBoard = (freshSlot.snapshot as SoundGameCheckpoint).board;
      expect(freshSlot.contentRevision, 1);
      expect(freshSlot.cursor.generation, oldCursor.generation + 1);
      expect(freshSlot.cursor.sequence, oldCursor.sequence + 3,
          reason:
              'Start, initial checkpoint, then preview assistance are saved');
      expect(freshSlot.cursor.revision, 2,
          reason: 'Start and initial checkpoint advance the board revision');
      expect(freshBoard.board, isNot(oldBoard.board));
      expect(freshBoard.board, everyElement(anyOf('u', 'y', 'i', 'o')));
      expect(after.history, hasLength(state.history.length));
      expect(after.mistakes.keys, state.mistakes.keys);
      expect(after.summaries, state.summaries);
      expect(after.bestScores, state.bestScores);
      expect(audio.spoken, isEmpty);
    });
  }

  for (final failSave in [false, true]) {
    testWidgets(
        'switch games preserves typed progress with save failure = $failSave',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = CourseLearningWidgetStore();
      final router = GoRouter(initialLocation: '/arcade/sound', routes: [
        GoRoute(
            path: '/arcade/sound',
            builder: (_, __) => const ArcadeScreen(silent: false)),
        GoRoute(
            path: '/arcade/word',
            builder: (_, __) => const ArcadeScreen(silent: true)),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [courseLearningStoreProvider.overrideWithValue(store)],
          child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start 60-second round'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 7));
      var slot = store.committedState.activities['arcade:sound']!;
      var checkpoint = slot.snapshot as SoundGameCheckpoint;
      final board = SoundMatchEngine.fromState(checkpoint.board,
          random: SoundMatchEngine().random);
      final move = board.legalMoves().first;
      await tester.tap(find.byKey(ValueKey('sound-tile-${move.$1}')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('sound-tile-${move.$2}')));
      await tester.pumpAndSettle();
      slot = store.committedState.activities['arcade:sound']!;
      checkpoint = slot.snapshot as SoundGameCheckpoint;
      final savedBoard = checkpoint.board.board;
      final savedScore = checkpoint.clock.score;
      expect(savedScore, greaterThan(0));
      if (failSave) store.failingActions.add(CheckpointArcade);
      await tester.tap(find.text('Play without audio: Word Match'));
      await tester.pumpAndSettle();
      if (failSave) {
        expect(router.routeInformationProvider.value.uri.path, '/arcade/sound');
        expect(
            find.textContaining('Could not save this round.'), findsOneWidget);
        expect(find.text('Retry save'), findsOneWidget);
        store.failingActions.remove(CheckpointArcade);
        await tester.tap(find.text('Retry save'));
        await tester.pumpAndSettle();
      } else {
        store.failingActions.remove(CheckpointArcade);
      }
      expect(router.routeInformationProvider.value.uri.path, '/arcade/word');
      slot = store.committedState.activities['arcade:sound']!;
      checkpoint = slot.snapshot as SoundGameCheckpoint;
      expect(checkpoint.clock.score, savedScore);
      expect(checkpoint.board.board, savedBoard);
      expect(checkpoint.clock.paused, isTrue);
      router.go('/arcade/sound');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Resume saved board'), 200);
      await tester.tap(find.text('Resume saved board'));
      await tester.pumpAndSettle();
      expect(find.text('$savedScore pts'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'switch during held cue retires transient playback without evidence',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore();
    final audio = _HeldCueAudio();
    final router = GoRouter(initialLocation: '/arcade/sound', routes: [
      GoRoute(
          path: '/arcade/sound',
          builder: (_, __) => const ArcadeScreen(silent: false)),
      GoRoute(
          path: '/arcade/word',
          builder: (_, __) => const ArcadeScreen(silent: true)),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      courseLearningStoreProvider.overrideWithValue(store),
      courseAudioProvider.overrideWithValue(audio),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(audio.cues, hasLength(1));
    await tester.tap(find.text('Play without audio: Word Match'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/arcade/word');
    expect(audio.stops, greaterThan(0));
    audio.cues.single.completeError(StateError('late audio error'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Audio unavailable.'), findsNothing);
    expect(store.committedState.history, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('arcade intro retries an unavailable initial load',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore()..failLoad = true;
    await tester.pumpWidget(ProviderScope(
      overrides: [courseLearningStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: ArcadeScreen(silent: true)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Retry loading'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start 60-second round'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Retry loading'));
    await tester.pumpAndSettle();
    expect(store.retryLoadCalls, 1);
    expect(find.text('Start 60-second round'), findsOneWidget);
    expect(find.text('Retry loading'), findsNothing);
  });

  testWidgets('arcade intro retries the identical failed initial Start command',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore()
      ..failingActions.add(StartLearningRun);
    await tester.pumpWidget(ProviderScope(
      overrides: [courseLearningStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: ArcadeScreen(silent: true)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pumpAndSettle();
    expect(find.text('Retry save'), findsOneWidget);
    final failed = store.submitted
        .singleWhere((command) => command.action is StartLearningRun);

    store.failingActions.remove(StartLearningRun);
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(store.submitted.where((command) => command.token == failed.token),
        hasLength(2));
    expect(find.byTooltip('Pause'), findsOneWidget,
        reason: 'retrying Start continues through the initial checkpoint');
    final checkpoint = store.committedState.activities['arcade:word']!.snapshot
        as WordGameCheckpoint;
    expect(checkpoint.clock.paused, isFalse);
  });

  testWidgets('arcade intro retries the identical failed initial unpause',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore()
      ..failingActions.add(CheckpointArcade);
    await tester.pumpWidget(ProviderScope(
      overrides: [courseLearningStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: ArcadeScreen(silent: true)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pumpAndSettle();
    expect(find.text('Retry save'), findsOneWidget);
    final failed = store.submitted
        .singleWhere((command) => command.action is CheckpointArcade);
    expect(
        (store.committedState.activities['arcade:word']!.snapshot
                as WordGameCheckpoint)
            .clock
            .paused,
        isTrue);

    store.failingActions.remove(CheckpointArcade);
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(store.submitted.where((command) => command.token == failed.token),
        hasLength(2));
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(
        (store.committedState.activities['arcade:word']!.snapshot
                as WordGameCheckpoint)
            .clock
            .paused,
        isFalse);
  });

  testWidgets('unavailable arcade save retries loading instead of resending',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore()
      ..actionFailures[CheckpointArcade] = const LearningUnavailableException();
    await tester.pumpWidget(ProviderScope(
      overrides: [courseLearningStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: ArcadeScreen(silent: true)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pumpAndSettle();
    expect(find.text('Retry save'), findsNothing);
    expect(find.text('Retry loading'), findsOneWidget);
    final checkpointAttempts = store.submitted
        .where((command) => command.action is CheckpointArcade)
        .length;
    await tester.tap(find.text('Retry loading'));
    await tester.pumpAndSettle();
    expect(store.retryLoadCalls, 1);
    expect(
        store.submitted
            .where((command) => command.action is CheckpointArcade)
            .length,
        checkpointAttempts);
    expect(find.text('Resume saved board'), findsOneWidget);
  });

  testWidgets('invalid arcade command requires reload, not save retry',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore()
      ..actionFailures[CheckpointArcade] =
          const LearningInvalidCommandException();
    await tester.pumpWidget(ProviderScope(
      overrides: [courseLearningStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: ArcadeScreen(silent: true)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pumpAndSettle();
    expect(find.text('Retry save'), findsNothing);
    expect(find.text('Reload saved board'), findsOneWidget);
    expect(store.committedState.activities, contains('arcade:word'));
  });

  testWidgets('arcade same-slot conflict reloads current saved board',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [courseLearningStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: ArcadeScreen(silent: true)),
    ));
    await tester.pumpAndSettle();
    final competing = store.prepare(
      state: store.committedState,
      activityId: 'arcade:word',
      action: StartLearningRun(options: RunOptions()),
    );
    await store.submit(competing);
    await tester.tap(find.text('Start 60-second round'));
    await tester.pumpAndSettle();

    expect(find.text('Retry save'), findsNothing);
    expect(find.text('Reload saved board'), findsOneWidget);
    await tester.tap(find.text('Reload saved board'));
    await tester.pumpAndSettle();
    expect(store.loadCalls, 2);
    expect(store.retryLoadCalls, 0);
    expect(find.text('Resume saved board'), findsOneWidget);
  });

  testWidgets('A to B to A ignores delayed old-owner move feedback and score',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storeA = CourseLearningWidgetStore();
    final storeB = CourseLearningWidgetStore();
    final gate = Completer<void>();
    storeA.actionGates[SwapSoundTiles] = gate;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        _activeStoreProvider.overrideWith((ref) => storeA),
        courseLearningStoreProvider
            .overrideWith((ref) => ref.watch(_activeStoreProvider)),
      ],
      child: const MaterialApp(home: ArcadeScreen(silent: false)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pump();
    await tester.pump();
    final checkpoint = storeA.committedState.activities['arcade:sound']!
        .snapshot as SoundGameCheckpoint;
    final board =
        SoundMatchEngine.fromState(checkpoint.board, random: Random(4));
    final move = board.legalMoves().first;
    await tester.tap(find.byKey(ValueKey('sound-tile-${move.$1}')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('sound-tile-${move.$2}')));
    await tester.pump();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ArcadeScreen)));
    container.read(_activeStoreProvider.notifier).state = storeB;
    await tester.pumpAndSettle();
    expect(storeB.committedState.activities, isEmpty);
    storeA.actionFailures[SwapSoundTiles] =
        const LearningOwnerChangedException();
    gate.complete();
    await tester.pump();
    await tester.pump();
    container.read(_activeStoreProvider.notifier).state = storeA;
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Resume saved board'), 200);
    await tester.tap(find.text('Resume saved board'));
    await tester.pump();
    await tester.pump();
    final returned = storeA.committedState.activities['arcade:sound']!.snapshot
        as SoundGameCheckpoint;
    expect(returned.clock.score, 0);
    expect(find.text('0 pts'), findsOneWidget);
    expect(storeB.committedState.activities, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });


  for (final silent in [false, true]) {
    testWidgets(
      'Finish from root ${silent ? "Word Match" : "Sound Match"} returns to arcade',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final store = CourseLearningWidgetStore();
        final gamePath = silent ? '/arcade/word' : '/arcade/sound';
        final router = GoRouter(
          initialLocation: gamePath,
          routes: [
            GoRoute(
              path: '/arcade',
              builder: (_, __) => const Text('Arcade home'),
            ),
            GoRoute(
              path: '/arcade/sound',
              builder: (_, __) => const ArcadeScreen(silent: false),
            ),
            GoRoute(
              path: '/arcade/word',
              builder: (_, __) => const ArcadeScreen(silent: true),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [courseLearningStoreProvider.overrideWithValue(store)],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start 60-second round'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Pause'));
        await tester.pumpAndSettle();
        expect(find.text('Paused'), findsOneWidget);
        await tester.tap(find.text('Finish'));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/arcade');
        expect(find.text('Arcade home'), findsOneWidget);
        expect(
          store.committedState.activities,
          contains(silent ? 'arcade:word' : 'arcade:sound'),
        );
      },
    );

    testWidgets('Finish from pushed ${silent ? "Word" : "Sound"} returns to previous route', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = CourseLearningWidgetStore();
      final gamePath = silent ? '/arcade/word' : '/arcade/sound';
      final router = GoRouter(initialLocation: '/arcade', routes: [
        GoRoute(path: '/arcade', builder: (_, __) => const ArcadeLobby()),
        GoRoute(path: '/arcade/sound', builder: (_, __) => const ArcadeScreen(silent: false)),
        GoRoute(path: '/arcade/word', builder: (_, __) => const ArcadeScreen(silent: true)),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [courseLearningStoreProvider.overrideWithValue(store)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      router.push(gamePath);
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeScreen), findsOneWidget);
      await tester.tap(find.text('Start 60-second round'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/arcade');
      expect(find.text('One minute. One more combo.'), findsOneWidget);
    });

    testWidgets('Finish after saved/reloaded ${silent ? "Word" : "Sound"} board', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = CourseLearningWidgetStore();
      final gamePath = silent ? '/arcade/word' : '/arcade/sound';
      GoRouter makeRouter() => GoRouter(initialLocation: gamePath, routes: [
        GoRoute(path: '/arcade', builder: (_, __) => const Text('Arcade home')),
        GoRoute(path: '/arcade/sound', builder: (_, __) => const ArcadeScreen(silent: false)),
        GoRoute(path: '/arcade/word', builder: (_, __) => const ArcadeScreen(silent: true)),
      ]);
      var router = makeRouter();
      await tester.pumpWidget(ProviderScope(
        overrides: [courseLearningStoreProvider.overrideWithValue(store)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start 60-second round'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      expect(store.committedState.activities, contains(silent ? 'arcade:word' : 'arcade:sound'));
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      router = makeRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [courseLearningStoreProvider.overrideWithValue(store)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Resume saved board'), findsOneWidget);
      await tester.tap(find.text('Resume saved board'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/arcade');
      expect(find.text('Arcade home'), findsOneWidget);
    });

    testWidgets('failed Finish checkpoint retries identical ${silent ? "Word" : "Sound"} command without exiting', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = CourseLearningWidgetStore();
      final gamePath = silent ? '/arcade/word' : '/arcade/sound';
      final router = GoRouter(initialLocation: gamePath, routes: [
        GoRoute(path: '/arcade', builder: (_, __) => const Text('Arcade home')),
        GoRoute(path: '/arcade/sound', builder: (_, __) => const ArcadeScreen(silent: false)),
        GoRoute(path: '/arcade/word', builder: (_, __) => const ArcadeScreen(silent: true)),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [courseLearningStoreProvider.overrideWithValue(store)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start 60-second round'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      store.failingActions.add(CheckpointArcade);
      final before = store.submitted.length;
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, gamePath);
      expect(find.text('Retry save'), findsOneWidget);
      final failed = store.submitted[before];
      expect(failed.action, isA<CheckpointArcade>());
      store.failingActions.remove(CheckpointArcade);
      await tester.tap(find.text('Retry save'));
      await tester.pumpAndSettle();
      expect(store.submitted.where((command) => command.token == failed.token), hasLength(2));
      expect(router.routeInformationProvider.value.uri.path, '/arcade');
      expect(find.text('Arcade home'), findsOneWidget);
    });
  }
}
