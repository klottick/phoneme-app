import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
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

void main() {
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
}
