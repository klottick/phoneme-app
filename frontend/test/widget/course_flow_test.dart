import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/features/arcade/arcade_screen.dart';
import 'package:linguist/src/features/arcade/sound_match_engine.dart';
import 'package:linguist/src/features/arcade/word_match_engine.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabaseHandle;
import 'package:linguist/src/features/course/course_lesson_screen.dart';
import '../support/course_learning_widget_store.dart';
import '../support/map_motion_test_support.dart';
import '../support/sqlite_learning_test_harness.dart';

class TestFrenchAudio implements CourseAudio {
  TestFrenchAudio({this.fail = false});
  final bool fail;
  int calls = 0;
  @override
  Future<void> speak(String word) async {
    calls++;
    if (fail) throw StateError('Audio unavailable');
  }

  @override
  Future<void> stop() async {}
}

/// One retained request of [HeldCueAudio]: released exactly once, with
/// success or the exact engine error.
final class HeldCue {
  HeldCue(this._settle);

  final Completer<Object?> _settle;

  bool get settled => _settle.isCompleted;

  void release([Object? error]) {
    if (_settle.isCompleted) return;
    if (error == null) {
      _settle.complete();
    } else {
      _settle.completeError(error);
    }
  }
}

/// Adversarial-compatible [CourseAudio] boundary for caller-generation
/// tests (I3 fix): [speak] retains a per-request cue; [stop] only records
/// itself (a compatible implementation may settle after Stop); the cues
/// then really settle with success or an exact error, and each must be
/// survivable by the screen's generation guard.
final class HeldCueAudio implements CourseAudio {
  final List<String> spoken = <String>[];
  final List<HeldCue> cues = <HeldCue>[];
  int stops = 0;

  @override
  Future<void> speak(String word) {
    spoken.add(word);
    final Completer<Object?> settle = Completer<Object?>();
    final HeldCue cue = HeldCue(settle);
    cues.add(cue);
    final Future<void> delivery = settle.future.then((Object? value) {});
    unawaited(
        delivery.then<void>((Object? value) {}, onError: (Object error) {}));
    return delivery;
  }

  @override
  Future<void> stop() {
    // Stop is recorded; the request stays retained and settles later,
    // really — that is the stale-settlement shape callers must survive.
    stops++;
    return Future<void>.value();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('onboard into a directional course and open silent arcade',
      (tester) async {
    disableMapMotion(tester);
    final tempDir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('course-flow-sqlite-'),
    ))!;
    final handle = LearningDatabaseHandle(
      open: () => openFileLearningTestDatabase(
        File('${tempDir.path}/phoneme_learning.sqlite'),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await handle.close();
      await tempDir.delete(recursive: true);
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [learningDatabaseHandleProvider.overrideWithValue(handle)],
      child: const LinguistApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('I speak English'), findsOneWidget);
    await tester.tap(find.text('Start English → French'));
    await tester.pumpAndSettle();
    expect(find.text('All destinations'), findsOneWidget);
    await tester.tap(find.text('Games').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Word Match'));
    await tester.pumpAndSettle();
    expect(find.text('No audio needed'), findsOneWidget);
    await tester.tap(find.text('Start 60-second round'));
    await tester.pump();
    expect(find.textContaining('Connect words containing'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('silent game ends at a minute and continues the same score',
      (tester) async {
    final audio = TestFrenchAudio(fail: true);
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(ProviderScope(overrides: [
      courseAudioProvider.overrideWithValue(audio),
      courseLearningStoreProvider.overrideWithValue(store),
    ], child: const MaterialApp(home: ArcadeScreen(silent: true))));
    await tester.pump();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(find.text('Round complete'), findsOneWidget);
    await tester.tap(find.text('Continue this board'));
    await tester.pump();
    expect(find.textContaining('Round 2'), findsOneWidget);
    expect(audio.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed sound cue never records an incorrect listening answer',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(ProviderScope(overrides: [
      courseAudioProvider.overrideWithValue(TestFrenchAudio(fail: true)),
      courseLearningStoreProvider.overrideWithValue(store),
    ], child: const MaterialApp(home: ArcadeScreen(silent: false))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(find.textContaining('Audio unavailable.'), findsOneWidget);
    final slot = store.committedState.activities['arcade:sound']!;
    final checkpoint = slot.snapshot as SoundGameCheckpoint;
    final board =
        SoundMatchEngine.fromState(checkpoint.board, random: Random(9));
    final move = board.legalMoves().first;
    await tester.tap(find.byKey(ValueKey('sound-tile-${move.$1}')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('sound-tile-${move.$2}')));
    await tester.pump();
    expect(find.text('0 pts'), findsNothing);
    expect(store.committedState.history, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  // Suspend while a cue is held, resume, take the explicit Resume, and wait
  // for the round's NEXT cue (the Resume action intentionally retires the
  // current cue, so the timer raises a fresh one). Returns the index of
  // that new cue in [HeldCueAudio.cues].
  Future<int> suspendResumeAndNextCue(
      WidgetTester tester, HeldCueAudio audio) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(audio.spoken, hasLength(2));
    return 1;
  }

  testWidgets(
      'backgrounding retires a held cue: a really late SUCCESS during a '
      'newer held attempt cannot arm the bonus', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore();
    final audio = HeldCueAudio();
    await tester.pumpWidget(ProviderScope(overrides: [
      courseAudioProvider.overrideWithValue(audio),
      courseLearningStoreProvider.overrideWithValue(store),
    ], child: const MaterialApp(home: ArcadeScreen(silent: false))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(audio.spoken, isNotEmpty,
        reason: 'the cue must reach playback before suspension');
    final HeldCue firstCue = audio.cues[0];
    // Suspend: the screen must stop the in-flight audio and release its
    // audio-owned busy state; resume + explicit Resume retires the current
    // cue by design, and the round's timer raises the newer one (B) which
    // stays held while A is still pending.
    await suspendResumeAndNextCue(tester, audio);
    expect(
      audio.stops,
      greaterThanOrEqualTo(1),
      reason: 'suspending must stop in-flight audio',
    );
    final HeldCue secondCue = audio.cues[1];
    // The stale request settles with SUCCESS now, while the newer one is
    // held: it must not arm the bonus and must not touch the newer state.
    firstCue.release();
    await tester.pumpAndSettle();
    expect(
      find.text('Which vowel did you hear? Your next match can earn +100.'),
      findsNothing,
      reason: 'a stale success must not arm the bonus match',
    );
    expect(store.committedState.history, isEmpty,
        reason: 'a stale success never records listening evidence');
    // Only the current request may later complete and arm.
    secondCue.release();
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Which vowel did you hear? Your next match can earn +100.'),
      findsWidgets,
      reason: 'the current request may arm the bonus on its own success',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'backgrounding retires a held cue: a really late ERROR during a newer '
      'held attempt must not publish failure or clear it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore();
    final audio = HeldCueAudio();
    await tester.pumpWidget(ProviderScope(overrides: [
      courseAudioProvider.overrideWithValue(audio),
      courseLearningStoreProvider.overrideWithValue(store),
    ], child: const MaterialApp(home: ArcadeScreen(silent: false))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(audio.spoken, isNotEmpty,
        reason: 'the cue must reach playback before suspension');
    final HeldCue firstCue = audio.cues[0];
    await suspendResumeAndNextCue(tester, audio);
    expect(
      audio.stops,
      greaterThanOrEqualTo(1),
      reason: 'suspending must stop in-flight audio',
    );
    final HeldCue secondCue = audio.cues[1];
    // The stale request settles with a REAL engine failure now.
    firstCue.release(StateError('late engine failure'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Audio unavailable.'),
      findsNothing,
      reason: 'a stale failure must not publish failure over the newer '
          'request',
    );
    expect(
      find.text('Which vowel did you hear? Your next match can earn +100.'),
      findsNothing,
      reason: 'a stale failure must not arm the bonus match',
    );
    // The newer request is still owned (busy) despite the stale error.
    final IconButton replay = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Replay sound'),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      replay.onPressed,
      isNull,
      reason: 'a stale failure must not clear the newer held request busy',
    );
    expect(store.committedState.history, isEmpty,
        reason: 'a stale failure never records listening evidence');
    // The current request still completes and arms on its own success.
    secondCue.release();
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Which vowel did you hear? Your next match can earn +100.'),
      findsWidgets,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('lesson completion records real answers and advances the path',
      (tester) async {
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          courseAudioProvider.overrideWithValue(TestFrenchAudio()),
          courseLearningStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
            home: CourseLessonScreen(lessonId: 'en-fr-vowels'))));
    await tester.pumpAndSettle();
    var step = 0;
    for (final sound in ['i', 'o', 'i', 'o']) {
      await tester.scrollUntilVisible(find.text('Listen to French word'), -200);
      await tester.tap(find.text('Listen to French word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/$sound/'));
      await tester.pumpAndSettle();
      step++;
      await tester.scrollUntilVisible(
          find.text(step == 4 ? 'Finish' : 'Next word'), 200);
      if (step == 4) {
        await tester.tap(find.text('Finish'));
      } else {
        await tester.tap(find.text('Next word'));
      }
      await tester.pumpAndSettle();
    }
    final data = store.committedState;
    expect(data.completions.map((completion) => completion.lessonId),
        contains('en-fr-vowels'));
    expect(
        data.summaries.entries
            .where((entry) => entry.key.sound == 'i')
            .fold<int>(0, (sum, entry) => sum + entry.value.correct),
        2);
    expect(
        data.summaries.entries
            .where((entry) => entry.key.sound == 'o')
            .fold<int>(0, (sum, entry) => sum + entry.value.correct),
        2);
  });

  testWidgets('backgrounding pauses the game until explicitly resumed',
      (tester) async {
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(ProviderScope(
        overrides: [courseLearningStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: ArcadeScreen(silent: true))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pump(const Duration(seconds: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 80));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Round 1 · 50s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'dragging a word chain clears tiles and records only selected words',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore();
    final audio = TestFrenchAudio(fail: true);
    await tester.pumpWidget(ProviderScope(overrides: [
      courseAudioProvider.overrideWithValue(audio),
      courseLearningStoreProvider.overrideWithValue(store),
    ], child: const MaterialApp(home: ArcadeScreen(silent: true))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pump();
    final checkpoint = store.committedState.activities['arcade:word']!.snapshot
        as WordGameCheckpoint;
    final board =
        WordMatchEngine.fromState(checkpoint.board, random: Random(3));
    final chain = board.findChain();
    final start =
        tester.getCenter(find.byKey(ValueKey('word-tile-${chain.first}')));
    final gesture = await tester.startGesture(start);
    // Cross the touch-slop threshold inside the first tile before linking others.
    await gesture.moveTo(start + const Offset(22, 0));
    await tester.pump();
    for (final i in chain.skip(1)) {
      await gesture
          .moveTo(tester.getCenter(find.byKey(ValueKey('word-tile-$i'))));
      await tester.pump();
    }
    expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .where((t) => t?.startsWith('Link ') ?? false),
        contains('Link 3 words'));
    await gesture.up();
    await tester.pump();
    expect(find.text('0 pts'), findsNothing);
    final batch = store.committedState.history.last;
    expect(batch.attempts, hasLength(chain.length));
    expect(
        batch.attempts
            .map((attempt) => (attempt.answer as WordTileAnswer).wordId),
        chain.map((index) => checkpoint.board.board[index]));
    expect(batch.attempts.every((attempt) => attempt.correct), isTrue);
    expect(
        batch.attempts.every((attempt) =>
            attempt.audioSource == AttemptAudioSource.notApplicable),
        isTrue);
    expect(audio.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
