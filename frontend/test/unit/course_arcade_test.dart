import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/features/arcade/word_match_engine.dart';
import 'package:linguist/src/features/arcade/sound_match_engine.dart';
import 'package:linguist/src/features/arcade/arcade_session.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_random.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';

import '../support/course_learning_widget_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('French words have explicit sounds, not inferred letters', () {
    expect(frenchCourse.sourceLanguage, 'en');
    expect(frenchCourse.targetLanguage, 'fr');
    expect(
      frenchWords.firstWhere((w) => w.text == 'tout').contains('u'),
      isTrue,
    );
    expect(
      frenchWords.firstWhere((w) => w.text == 'tu').contains('u'),
      isFalse,
    );
    for (final word in frenchWords) {
      expect(word.text.contains(word.hint), isTrue);
    }
  });

  test('word boards always have a valid chain after clears', () {
    final game = WordMatchEngine(random: Random(4));
    for (var n = 0; n < 80; n++) {
      final chain = game.findChain();
      expect(chain.length, greaterThanOrEqualTo(3));
      final result = game.submit(chain);
      expect(result.accepted, isTrue);
      expect(result.evidence.length, chain.length);
      expect(game.board.length, 16);
    }
  });

  test(
    'word chains reject repeated and disconnected tiles without clearing',
    () {
      final game = WordMatchEngine(random: Random(1));
      final before = List<String>.of(game.board);
      expect(game.submit([0, 0, 1]).accepted, isFalse);
      expect(game.submit([0, 15, 1]).accepted, isFalse);
      expect(game.board, before);
    },
  );

  test('sound boards are settled, playable, and reject remote swaps', () {
    final game = SoundMatchEngine(random: Random(7));
    expect(game.matches(), isEmpty);
    expect(game.swap(0, 35).accepted, isFalse);
    for (var n = 0; n < 60; n++) {
      final move = game.legalMoves().first;
      final result = game.swap(move.$1, move.$2);
      expect(result.accepted, isTrue);
      expect(result.points, greaterThan(0));
      expect(game.matches(), isEmpty);
      expect(game.legalMoves(), isNotEmpty);
    }
  });

  test('session pauses and continues the same score at minute boundary', () {
    final session = ArcadeSession();
    session.score = 120;
    session.elapse(59);
    session.paused = true;
    session.elapse(20);
    expect(session.remaining, 1);
    session.paused = false;
    session.elapse(1);
    expect(session.roundOver, isTrue);
    session.continueRound();
    expect(session.remaining, 60);
    expect(session.score, 120);
    expect(session.round, 2);
  });

  test('restoring a board retains tiles, specials, and target', () {
    final word = WordMatchEngine(random: Random(22));
    word.submit(word.findChain());
    final restoredWord = WordMatchEngine()..restore(word.toJson());
    expect(restoredWord.toJson(), word.toJson());
    final sound = SoundMatchEngine(random: Random(23));
    final move = sound.legalMoves().first;
    sound.swap(move.$1, move.$2);
    final restoredSound = SoundMatchEngine()..restore(sound.toJson());
    expect(restoredSound.toJson(), sound.toJson());
  });

  test(
    'typed arcade snapshots restore strictly without consuming random draws',
    () {
      final word = WordMatchEngine(random: Random(30));
      final wordState = word.snapshot();
      final wordRandom = RecordingLearningRandom(Random(31));
      final restoredWord = WordMatchEngine.fromState(
        wordState,
        random: wordRandom,
      );
      expect(wordRandom.draws, isEmpty);
      expect(restoredWord.snapshot().board, wordState.board);
      expect(restoredWord.snapshot().target, wordState.target);
      expect(restoredWord.snapshot().stars, wordState.stars);
      final detachedWord = word.snapshot();
      word.board[0] = word.board[0] == 'tout' ? 'tu' : 'tout';
      expect(detachedWord.board, wordState.board);

      final sound = SoundMatchEngine(random: Random(32));
      final soundState = sound.snapshot();
      final soundRandom = RecordingLearningRandom(Random(33));
      final restoredSound = SoundMatchEngine.fromState(
        soundState,
        random: soundRandom,
      );
      expect(soundRandom.draws, isEmpty);
      expect(restoredSound.snapshot().board, soundState.board);
      expect(restoredSound.snapshot().stars, soundState.stars);
      final clock = ArcadeSession()..paused = true;
      clock.score = 140;
      final clockState = clock.snapshot();
      final restoredClock = ArcadeSession.fromState(clockState);
      expect(restoredClock.snapshot().remaining, clockState.remaining);
      expect(restoredClock.snapshot().round, clockState.round);
      expect(restoredClock.snapshot().score, clockState.score);
      expect(restoredClock.snapshot().paused, isTrue);
    },
  );

  test(
    'generated star and obstacle respawns round-trip through typed restore',
    () {
      var reproduced = false;
      for (var seed = 0; seed < 2000 && !reproduced; seed++) {
        final game = WordMatchEngine(random: Random(seed));
        final firstChain = _chainClearingAllObstacles(game);
        if (firstChain == null) continue;
        expect(firstChain.length, greaterThanOrEqualTo(5));
        expect(game.submit(firstChain).accepted, isTrue);
        final afterStarAndRespawn = game.toJson();
        final stars = List<int>.from(afterStarAndRespawn['stars'] as List);
        final obstacles = List<int>.from(
          afterStarAndRespawn['obstacles'] as List,
        );
        if (stars.toSet().intersection(obstacles.toSet()).isEmpty) continue;

        reproduced = true;
        expect(stars, isNotEmpty);
        expect(obstacles, hasLength(2));
        var state = _wordStateFromLegacyJson(afterStarAndRespawn);
        final draws = RecordingLearningRandom(Random(seed + 4000));
        var restored = WordMatchEngine.fromState(state, random: draws);
        expect(draws.draws, isEmpty);
        expect(restored.snapshot().board, state.board);
        expect(restored.snapshot().stars, state.stars);
        expect(restored.snapshot().obstacles, state.obstacles);

        while (game.moves < 4) {
          expect(game.submit(game.findChain()).accepted, isTrue);
          state = _wordStateFromLegacyJson(game.toJson());
          final roundTripDraws = RecordingLearningRandom(Random(seed + 4001));
          restored = WordMatchEngine.fromState(state, random: roundTripDraws);
          expect(roundTripDraws.draws, isEmpty);
          expect(restored.snapshot().board, state.board);
          expect(restored.snapshot().target, state.target);
          expect(restored.snapshot().stars, state.stars);
          expect(restored.snapshot().obstacles, state.obstacles);
        }
        expect(state.moves, 4);
        expect(state.target, 'y');
      }
      expect(
        reproduced,
        isTrue,
        reason: 'seeded legacy engine must reproduce reachable respawn overlap',
      );
    },
  );

  test(
    'typed game restore rejects invalid special positions instead of filtering',
    () {
      final word = WordMatchEngine(random: Random(34));
      expect(
        () => WordMatchEngine.fromState(
          WordBoardState(
            board: word.board,
            target: word.target,
            moves: word.moves,
            combo: word.combo,
            stars: const {16},
            obstacles: word.obstacles,
          ),
          random: Random(35),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'invalid saved boards are rejected rather than indexing corrupt data',
    () {
      expect(
        () => WordMatchEngine().restore({
          'board': ['unknown'],
          'target': 'u',
        }),
        throwsFormatException,
      );
      expect(
        () => SoundMatchEngine().restore({
          'board': ['u'],
        }),
        throwsFormatException,
      );
    },
  );

  test('a wrong word supplies spelling evidence without awarding points', () {
    final word = WordMatchEngine();
    word.board.setRange(0, 3, ['tout', 'tu', 'vous']);
    final result = word.submit([0, 1, 2]);
    expect(result.accepted, isFalse);
    expect(result.points, 0);
    expect(result.evidence, [('u', true), ('u', false), ('u', true)]);
  });

  test(
    'stale unrelated course commit retries without overwriting another slot',
    () async {
      final harness = CourseLearningSqlTestHarness();
      final before = await harness.store.load();
      final lessonStart = harness.store.prepare(
        state: before,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()),
      );
      final drillStart = harness.store.prepare(
        state: before,
        activityId: 'drill:minimal-pairs',
        action: StartLearningRun(options: RunOptions()),
      );
      await harness.store.submit(lessonStart);
      await expectLater(
        harness.store.submit(drillStart),
        throwsA(isA<LearningConflictException>()),
      );
      final refreshed = await harness.store.load();
      await harness.store.submit(
        harness.store.prepare(
          state: refreshed,
          activityId: 'drill:minimal-pairs',
          action: StartLearningRun(options: RunOptions()),
        ),
      );
      final state = await harness.store.load();
      expect(
        state.activities.keys,
        containsAll(['lesson:en-fr-u-y', 'drill:minimal-pairs']),
      );
    },
  );

  test(
    'progress keeps listening and spelling separate and survives reload',
    () async {
      final harness = CourseLearningSqlTestHarness();
      await harness.start('lesson:en-fr-u-y');
      await harness.answerPilot('u');
      await harness.start('arcade:word');
      await harness.store.submit(
        harness.store.prepare(
          state: await harness.store.load(),
          activityId: 'arcade:word',
          action: CheckpointArcade(elapsedSeconds: 0, paused: false),
        ),
      );
      final state = await harness.store.load();
      final board =
          (state.activities['arcade:word']!.snapshot as WordGameCheckpoint)
              .board;
      final game = WordMatchEngine.fromState(board, random: Random(9));
      final validChain = game.findChain();
      await harness.store.submit(
        harness.store.prepare(
          state: state,
          activityId: 'arcade:word',
          action: LinkWordTiles(indices: validChain),
        ),
      );
      await harness.database.reopen();
      final loaded = await harness.store.load();
      final listening = loaded.summaries.entries.where(
        (entry) => entry.key.skill == LearningSkill.listening,
      );
      final spelling = loaded.summaries.entries.where(
        (entry) => entry.key.skill == LearningSkill.spelling,
      );
      expect(listening, isNotEmpty);
      expect(spelling, isNotEmpty);
      expect(
        spelling.every((entry) => entry.key.origin == AttemptOrigin.game),
        isTrue,
      );
      expect(
        listening.every((entry) => entry.key.origin == AttemptOrigin.practice),
        isTrue,
      );
    },
  );
}

WordBoardState _wordStateFromLegacyJson(Map<String, dynamic> json) =>
    WordBoardState(
      board: List<String>.from(json['board'] as List),
      target: json['target'] as String,
      moves: json['moves'] as int,
      combo: json['combo'] as int,
      stars: Set<int>.from(json['stars'] as List),
      obstacles: Set<int>.from(json['obstacles'] as List),
    );

List<int>? _chainClearingAllObstacles(WordMatchEngine game) {
  bool matches(int index) =>
      wordByText(game.board[index]).contains(game.target);
  final required = Set<int>.of(game.obstacles);

  List<int>? visit(List<int> path) {
    if (path.length >= 5 && path.toSet().containsAll(required)) return path;
    for (var next = 0; next < game.board.length; next++) {
      if (path.contains(next) || !matches(next)) continue;
      if (path.isNotEmpty && !game.adjacent(path.last, next)) continue;
      final result = visit([...path, next]);
      if (result != null) return result;
    }
    return null;
  }

  for (var start = 0; start < game.board.length; start++) {
    if (!matches(start)) continue;
    final result = visit([start]);
    if (result != null) return result;
  }
  return null;
}
