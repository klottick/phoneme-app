import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';

import 'package:linguist/src/features/arcade/arcade_screen.dart';
import 'package:linguist/src/features/arcade/sound_match_engine.dart';
import 'package:linguist/src/features/arcade/word_match_engine.dart';
import '../support/course_learning_widget_store.dart';

class _FailOncePersistence implements LearningPersistence {
  _FailOncePersistence(this.delegate);
  final LearningPersistence delegate;
  bool failNextWrite = false;
  Completer<void>? writeEntered;
  Completer<bool>? writeGate;

  void holdAndRejectNextWrite() {
    failNextWrite = true;
    writeEntered = Completer<void>();
    writeGate = Completer<bool>();
  }

  @override
  Future<String?> read(String key) => delegate.read(key);
  @override
  Future<void> write(String key, String value) async {
    await delegate.write(key, value);
    if (failNextWrite) {
      failNextWrite = false;
      writeEntered!.complete();
      if (!await writeGate!.future) {
        throw StateError(
            'injected preferences save failure after cache update');
      }
    }
  }

  @override
  Future<void> restore(String key, String? value) =>
      delegate.restore(key, value);
  @override
  Future<void> reload() => delegate.reload();
}

void main() {
  testWidgets(
      'legacy arcade bytes stay untouched and new round commits typed checkpoint',
      (tester) async {
    final engine = SoundMatchEngine(random: Random(23));
    SharedPreferences.setMockInitialValues({
      'arcade.v1.en-fr.sound': jsonEncode({
        'session': {'remaining': 17, 'round': 1, 'score': 9},
        'board': engine.toJson(),
      }),
      'auth.token': 'keep-auth',
      'profile.name': 'keep-profile',
      'streak.days': 9,
    });
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [courseLearningStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: ArcadeScreen(silent: false)),
    ));
    await tester.pump();
    await tester.pump();
    // The new typed namespace must not resume a development-only board.
    await tester.scrollUntilVisible(find.text('Start 60-second round'), 200);
    expect(find.text('Start 60-second round'), findsOneWidget);
    expect(find.text('Resume saved board'), findsNothing);
    final before = await store.load();
    expect(before.activities, isEmpty);
    await tester.tap(find.text('Start 60-second round'));
    await tester.pump();
    await tester.pump();
    final state = await store.load();
    final checkpoint =
        state.activities['arcade:sound']!.snapshot as SoundGameCheckpoint;
    expect(checkpoint.clock.paused, isFalse);
    expect(checkpoint.clock.remaining, 60);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('arcade.v1.en-fr.sound'), isNotNull);
    expect(prefs.getString('auth.token'), 'keep-auth');
    expect(prefs.getString('profile.name'), 'keep-profile');
    expect(prefs.getInt('streak.days'), 9);
    expect(prefs.getString('course.learning.v2.ZW4tZnI.g'), isNull);
  });

  test(
      'real repository rolls back a failed whole game batch for same-command retry',
      () async {
    SharedPreferences.setMockInitialValues({});
    final owner = LearningOwner.guest();
    var tokenCounter = 0;
    final persistence = _FailOncePersistence(PreferencesLearningPersistence());
    final repository = CourseLearningRepository(
      scope: LearningScope(courseId: 'en-fr', owner: owner),
      authGeneration: 0,
      currentAuth: () =>
          LearningAuthScope(owner: owner, generation: 0, ready: true),
      backendOwner: () => owner,
      persistence: persistence,
      transitions: LearningTransitionEngine(LearningRegistry.french()),
      clock: () => DateTime.utc(2026, 10, 15),
      newToken: () => (++tokenCounter).toRadixString(36).padLeft(22, '0'),
      random: Random(23),
    );
    await SharedPreferences.getInstance();
    final initial = await repository.load();
    final start = repository.prepare(
        state: initial,
        activityId: 'arcade:word',
        action: StartLearningRun(options: RunOptions()));
    final started = await repository.submit(start);
    final active = repository.prepare(
        state: started.state,
        activityId: 'arcade:word',
        action: CheckpointArcade(elapsedSeconds: 0, paused: false));
    final activeCommit = await repository.submit(active);
    final initialCheckpoint = activeCommit.slot.snapshot as WordGameCheckpoint;
    final board =
        WordMatchEngine.fromState(initialCheckpoint.board, random: Random(2));
    final selected = board.findChain();
    final command = repository.prepare(
        state: activeCommit.state,
        activityId: 'arcade:word',
        action: LinkWordTiles(indices: selected, elapsedSeconds: 1));
    persistence.holdAndRejectNextWrite();
    final pending = repository.submit(command);
    await persistence.writeEntered!.future;
    final prefs = await SharedPreferences.getInstance();
    final optimistic =
        jsonDecode(prefs.getString('course.learning.v2.ZW4tZnI.g')!) as Map;
    expect(optimistic['history'], hasLength(1),
        reason:
            'the platform cache has optimistically accepted the full batch');
    expect((optimistic['history'] as List).single['attempts'],
        hasLength(selected.length),
        reason: 'all selected tiles are one atomic persisted evidence batch');
    var readFinished = false;
    final read = repository.load().then((state) {
      readFinished = true;
      return state;
    });
    await Future<void>.delayed(Duration.zero);
    expect(readFinished, isFalse,
        reason: 'a concurrent reader cannot see pre-acknowledgment history');
    persistence.writeGate!.complete(false);
    await expectLater(pending, throwsA(isA<LearningSaveException>()));
    final unchanged = await read;
    expect(unchanged.history, isEmpty);
    expect(
        (unchanged.activities['arcade:word']!.snapshot as WordGameCheckpoint)
            .board
            .board,
        initialCheckpoint.board.board);
    final committed = (await repository.submit(command)).state;
    expect(committed.history, hasLength(1));
    expect(committed.history.single.attempts, hasLength(selected.length));
    expect(committed.activities['arcade:word']!.latestReceipt.token,
        command.token);
    final persisted =
        jsonDecode(prefs.getString('course.learning.v2.ZW4tZnI.g')!) as Map;
    expect(persisted['history'], hasLength(1));
  });

  testWidgets(
      'whole game batch save failure holds board and retries same command once',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [courseLearningStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: ArcadeScreen(silent: true)),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Start 60-second round'), 200);
    await tester.tap(find.text('Start 60-second round'));
    await tester.pump();
    await tester.pump();
    final initialCheckpoint = store.committedState.activities['arcade:word']!
        .snapshot as WordGameCheckpoint;
    final board =
        WordMatchEngine.fromState(initialCheckpoint.board, random: Random(2));
    final selected = board.findChain();
    store.failingActions.add(LinkWordTiles);
    for (final index in selected) {
      await tester.tap(find.byKey(ValueKey('word-tile-$index')));
      await tester.pump();
    }
    await tester.tap(find.text('Link ${selected.length} words'));
    await tester.pump();
    expect(find.text('Retry save'), findsOneWidget);
    final pending = store.prepared.last;
    expect(pending.feedback.message, isNotEmpty);
    final unchanged = store.committedState;
    expect(unchanged.history, isEmpty);
    expect(
        (unchanged.activities['arcade:word']!.snapshot as WordGameCheckpoint)
            .board
            .board,
        initialCheckpoint.board.board);
    store.failingActions.remove(LinkWordTiles);
    await tester.tap(find.text('Retry save'));
    await tester.pump();
    await tester.pump();
    expect(identical(store.submitted.last, pending), isTrue);
    expect(store.submitted.where((command) => command.token == pending.token),
        hasLength(2));
    expect(store.committedState.history.single.attempts,
        hasLength(selected.length));
    expect(find.text(pending.feedback.message), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
