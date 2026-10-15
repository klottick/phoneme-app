import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/course_progress.dart';
import 'package:linguist/src/features/arcade/word_match_engine.dart';
import 'package:linguist/src/features/arcade/sound_match_engine.dart';
import 'package:linguist/src/features/arcade/arcade_session.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_random.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('French words have explicit sounds, not inferred letters', () {
    expect(frenchCourse.sourceLanguage, 'en');
    expect(frenchCourse.targetLanguage, 'fr');
    expect(
        frenchWords.firstWhere((w) => w.text == 'tout').contains('u'), isTrue);
    expect(
        frenchWords.firstWhere((w) => w.text == 'tu').contains('u'), isFalse);
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

  test('word chains reject repeated and disconnected tiles without clearing',
      () {
    final game = WordMatchEngine(random: Random(1));
    final before = List<String>.of(game.board);
    expect(game.submit([0, 0, 1]).accepted, isFalse);
    expect(game.submit([0, 15, 1]).accepted, isFalse);
    expect(game.board, before);
  });

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

  test('typed arcade snapshots restore strictly without consuming random draws',
      () {
    final word = WordMatchEngine(random: Random(30));
    final wordState = word.snapshot();
    final wordRandom = RecordingLearningRandom(Random(31));
    final restoredWord =
        WordMatchEngine.fromState(wordState, random: wordRandom);
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
    final restoredSound =
        SoundMatchEngine.fromState(soundState, random: soundRandom);
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
  });

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
  });

  test('invalid saved boards are rejected rather than indexing corrupt data',
      () {
    expect(
        () => WordMatchEngine().restore({
              'board': ['unknown'],
              'target': 'u'
            }),
        throwsFormatException);
    expect(
        () => SoundMatchEngine().restore({
              'board': ['u']
            }),
        throwsFormatException);
  });

  test('a wrong word supplies spelling evidence without awarding points', () {
    final word = WordMatchEngine();
    word.board.setRange(0, 3, ['tout', 'tu', 'vous']);
    final result = word.submit([0, 1, 2]);
    expect(result.accepted, isFalse);
    expect(result.points, 0);
    expect(result.evidence, [('u', true), ('u', false), ('u', true)]);
  });

  test('concurrent answers do not overwrite one another', () async {
    await Future.wait(List.generate(20,
        (_) => CourseProgressStore('en-fr').record('u', 'listening', true)));
    final data = await CourseProgressStore('en-fr').load();
    expect(data['evidence']['listening:u']['attempts'], 20);
  });

  test('progress keeps listening and spelling separate and survives reload',
      () async {
    final store = CourseProgressStore('en-fr');
    await store.record('u', 'spelling', true);
    await store.completeLesson('en-fr-vowels');
    final data = await CourseProgressStore('en-fr').load();
    expect(data['evidence']['spelling:u']['correct'], 1);
    expect(data['evidence']['listening:u'], isNull);
    expect(data['lessons'], contains('en-fr-vowels'));
    expect((await CourseProgressStore('fr-en').load())['lessons'], isEmpty);
  });
}
