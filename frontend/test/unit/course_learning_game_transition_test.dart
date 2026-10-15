import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/features/arcade/word_match_engine.dart';
import 'package:linguist/src/features/arcade/sound_match_engine.dart';

import '../support/course_learning_fixtures.dart';

void main() {
  late LearningTransitionEngine engine;
  setUp(() => engine = LearningTransitionEngine(LearningRegistry.french()));

  test('same frozen command replays identical board stars and score', () {
    final started = _start(engine, 'arcade:word', 1);
    final before = started.$1;
    final chain = _validChain(
        (before.activities['arcade:word']!.snapshot as WordGameCheckpoint)
            .board);
    final legacy = WordMatchEngine.fromState(
      (before.activities['arcade:word']!.snapshot as WordGameCheckpoint).board,
      random: Random(19),
    );
    final legacyResult = legacy.submit(chain);
    final prepared = engine.prepare(
      state: before,
      authGeneration: 0,
      activityId: 'arcade:word',
      action: LinkWordTiles(indices: chain),
      token: _tokenFor(2),
      submittedAt: fixedTime,
      random: Random(19),
    );
    final committed = engine.evaluate(
        state: before, command: prepared, committedAt: fixedTime);
    final replayed = engine.evaluate(
        state: before, command: prepared, committedAt: fixedTime);
    final actual = replayed.slot.snapshot as WordGameCheckpoint;
    final expected = committed.slot.snapshot as WordGameCheckpoint;
    expect(actual.board.board, expected.board.board);
    expect(actual.board.stars, expected.board.stars);
    expect(actual.clock.score, expected.clock.score);
    expect(prepared.feedback.message, legacyResult.message);
    expect(prepared.feedback.points, legacyResult.points);
    expect(prepared.feedback.cascades, 0);
    expect(prepared.feedback.bonus, 0);
    expect(
        (prepared.candidate as WordGameCheckpoint).board.board, legacy.board);
    expect(
        (prepared.candidate as WordGameCheckpoint).board.stars, legacy.stars);
  });

  test('evaluation rejects extra missing and wrong-bound candidate draws', () {
    final empty = CourseLearningState.empty(guestScope);
    final prepared = engine.prepare(
      state: empty,
      authGeneration: 0,
      activityId: 'arcade:word',
      action: StartLearningRun(options: RunOptions()),
      token: _tokenFor(13),
      submittedAt: fixedTime,
      random: Random(13),
    );
    LearningCommand altered(List<RandomDraw> draws) => LearningCommand(
          scope: prepared.scope,
          authGeneration: prepared.authGeneration,
          activityId: prepared.activityId,
          expected: prepared.expected,
          token: prepared.token,
          submittedAt: prepared.submittedAt,
          action: prepared.action,
          draws: draws,
          candidate: prepared.candidate,
          feedback: prepared.feedback,
        );
    expect(
      () => engine.evaluate(
        state: empty,
        command:
            altered([...prepared.draws, RandomDraw(upperBound: 2, value: 1)]),
        committedAt: fixedTime,
      ),
      throwsA(isA<LearningInvalidCommandException>()),
    );
    expect(
      () => engine.evaluate(
        state: empty,
        command:
            altered(prepared.draws.take(prepared.draws.length - 1).toList()),
        committedAt: fixedTime,
      ),
      throwsA(isA<LearningInvalidCommandException>()),
    );
    final wrongBound = [...prepared.draws];
    wrongBound[0] = RandomDraw(
      upperBound: wrongBound.first.upperBound + 1,
      value: wrongBound.first.value,
    );
    expect(
      () => engine.evaluate(
        state: empty,
        command: altered(wrongBound),
        committedAt: fixedTime,
      ),
      throwsA(isA<LearningInvalidCommandException>()),
    );
  });

  test(
      'equal word tiles remain distinct attempts across an automatic star clear',
      () {
    final started = _start(engine, 'arcade:word', 3);
    final original =
        (started.$1.activities['arcade:word']!.snapshot as WordGameCheckpoint)
            .board;
    final board = List<String>.of(original.board);
    board[0] = 'tout';
    board[1] = 'tout';
    board[2] = 'tout';
    final slot = _replaceWordBoard(
        started.$1,
        WordBoardState(
          board: board,
          target: 'u',
          moves: 0,
          combo: 0,
          stars: const {0},
          obstacles: const {5, 10},
        ));
    final input = [0, 1, 2];
    final action = LinkWordTiles(indices: input);
    final command = engine.prepare(
      state: slot,
      authGeneration: 0,
      activityId: 'arcade:word',
      action: action,
      token: _tokenFor(4),
      submittedAt: fixedTime,
      random: Random(20),
    );
    input[0] = 15;
    expect(action.indices, [0, 1, 2]);
    expect(() => (command.draws as List).clear(), throwsUnsupportedError);
    final transition =
        engine.evaluate(state: slot, command: command, committedAt: fixedTime);
    expect(transition.attempts.length, 3);
    expect(transition.attempts.map((attempt) => attempt.batchIndex).toSet(),
        {0, 1, 2});
    expect(transition.attempts.map((attempt) => attempt.itemId),
        ['tout', 'tout', 'tout']);
  });

  test('invalid geometry and automatic clears produce no attempts', () {
    final started = _start(engine, 'arcade:word', 5);
    final original =
        (started.$1.activities['arcade:word']!.snapshot as WordGameCheckpoint)
            .board;
    final board = List<String>.of(original.board)
      ..setRange(0, 3, ['tout', 'tout', 'tout']);
    final state = _replaceWordBoard(
        started.$1,
        WordBoardState(
          board: board,
          target: 'u',
          moves: 0,
          combo: 0,
          stars: const {},
          obstacles: const {5, 10},
        ));
    final invalid = engine.prepare(
      state: state,
      authGeneration: 0,
      activityId: 'arcade:word',
      action: LinkWordTiles(indices: [0, 3, 6]),
      token: _tokenFor(6),
      submittedAt: fixedTime,
      random: Random(1),
    );
    expect(
        engine
            .evaluate(state: state, command: invalid, committedAt: fixedTime)
            .attempts,
        isEmpty);
  });

  test('first four moves retain grapheme hints for selected words', () {
    final started = _start(engine, 'arcade:word', 7);
    final slot = _replaceWordBoard(
        started.$1,
        WordBoardState(
          board: List.filled(16, 'tout'),
          target: 'u',
          moves: 0,
          combo: 0,
          stars: const {},
          obstacles: const {5, 10},
        ));
    CourseLearningState current = slot;
    for (var move = 0; move < 4; move++) {
      final board =
          (current.activities['arcade:word']!.snapshot as WordGameCheckpoint)
              .board;
      final chain = _validChain(board);
      final command = engine.prepare(
        state: current,
        authGeneration: 0,
        activityId: 'arcade:word',
        action: LinkWordTiles(indices: chain),
        token: _tokenFor(8 + move),
        submittedAt: fixedTime,
        random: Random(8 + move),
      );
      final result = engine.evaluate(
          state: current, command: command, committedAt: fixedTime);
      expect(result.attempts, hasLength(chain.length));
      expect(
          result.attempts
              .every((a) => a.assistance.contains(AssistanceFlag.graphemeHint)),
          isTrue);
      current = stateAfter(current, result);
    }
  });

  test('wrong-chain feedback assists only the subsequent occurrence', () {
    final started = _start(engine, 'arcade:word', 71);
    final state = _replaceWordBoard(
        started.$1,
        WordBoardState(
          board: List.filled(16, 'tout')..[1] = 'tu',
          target: 'u',
          moves: 0,
          combo: 0,
          stars: const {},
          obstacles: const {5, 10},
        ));
    CourseLearningState current = state;
    LearningTransition? last;
    for (var i = 0; i < 2; i++) {
      final command = engine.prepare(
        state: current,
        authGeneration: 0,
        activityId: 'arcade:word',
        action: LinkWordTiles(indices: [0, 1, 2]),
        token: _tokenFor(72 + i),
        submittedAt: fixedTime,
        random: Random(72),
      );
      last = engine.evaluate(
          state: current, command: command, committedAt: fixedTime);
      if (i == 0) {
        expect(
            last.attempts.every(
                (a) => !a.assistance.contains(AssistanceFlag.answerRevealed)),
            isTrue);
      } else {
        expect(last.attempts.firstWhere((a) => a.itemId == 'tu').assistance,
            contains(AssistanceFlag.answerRevealed));
      }
      current = stateAfter(current, last);
    }
    expect(last!.attempts, hasLength(3));
  });

  test('observed explanation preview assists later game attempts', () {
    final started = _start(engine, 'arcade:word', 73).$1;
    final context = ItemContextKey(itemId: 'tout', targetSound: 'u');
    final observe = engine.prepare(
      state: started,
      authGeneration: 0,
      activityId: 'arcade:word',
      action: ObserveAssistance(
        items: {context},
        flags: {AssistanceFlag.explanationVisible},
      ),
      token: _tokenFor(74),
      submittedAt: fixedTime,
      random: Random(74),
    );
    final observed = engine.evaluate(
        state: started, command: observe, committedAt: fixedTime);
    final state = stateAfter(started, observed);
    expect(observed.attempts, isEmpty);
    final board =
        (state.activities['arcade:word']!.snapshot as WordGameCheckpoint).board;
    final chain = _validChain(board);
    final command = engine.prepare(
      state: state,
      authGeneration: 0,
      activityId: 'arcade:word',
      action: LinkWordTiles(indices: chain),
      token: _tokenFor(75),
      submittedAt: fixedTime,
      random: Random(75),
    );
    final result =
        engine.evaluate(state: state, command: command, committedAt: fixedTime);
    expect(
        result.attempts
            .firstWhere((attempt) => attempt.itemId == 'tout')
            .assistance,
        contains(AssistanceFlag.explanationVisible));
  });

  test('single heard family records one answer and the existing 100 bonus', () {
    final state = _start(engine, 'arcade:sound', 81).$1;
    final board =
        (state.activities['arcade:sound']!.snapshot as SoundGameCheckpoint)
            .board;
    final legacy = SoundMatchEngine.fromState(board, random: Random(41));
    final move = legacy.legalMoves().firstWhere(
        (move) => _swapFamilies(board.board, move.$1, move.$2).length == 1);
    final legacyResult = legacy.swap(move.$1, move.$2);
    final target = legacyResult.families.single;
    final word = LearningRegistry.french()
        .require('arcade:sound')
        .items
        .firstWhere((item) => wordByText(item.id).contains(target));
    final command = engine.prepare(
      state: state,
      authGeneration: 0,
      activityId: 'arcade:sound',
      action: SwapSoundTiles(
        first: move.$1,
        second: move.$2,
        cue: HeardSoundCue(
          wordId: word.id,
          targetSound: target,
          audioSource: AttemptAudioSource.practiceSpeech,
        ),
      ),
      token: _tokenFor(82),
      submittedAt: fixedTime,
      random: Random(41),
    );
    final result =
        engine.evaluate(state: state, command: command, committedAt: fixedTime);
    final snapshot = result.slot.snapshot as SoundGameCheckpoint;
    expect(result.attempts, hasLength(1));
    expect(result.attempts.single.correct, isTrue);
    expect(snapshot.clock.score, legacyResult.points + 100);
    expect(command.feedback.points, legacyResult.points);
    expect(command.feedback.cascades, legacyResult.cascades);
    expect(command.feedback.bonus, 100);
    expect(command.feedback.message,
        '${legacyResult.cascades > 1 ? '${legacyResult.cascades} cascades! ' : ''}+${legacyResult.points} · Sound bonus +100!');
    expect(snapshot.board.board, legacy.board);
    expect(snapshot.board.stars, legacy.stars);
  });

  test('rejected sound swap retains the existing UI feedback without evidence',
      () {
    final state = _start(engine, 'arcade:sound', 84).$1;
    final command = engine.prepare(
      state: state,
      authGeneration: 0,
      activityId: 'arcade:sound',
      action: SwapSoundTiles(first: 0, second: 35),
      token: _tokenFor(85),
      submittedAt: fixedTime,
      random: Random(85),
    );
    expect(command.feedback.message, 'Swap neighbors to make a line of three.');
    expect(command.feedback.points, 0);
    expect(
        engine
            .evaluate(state: state, command: command, committedAt: fixedTime)
            .attempts,
        isEmpty);
  });

  test('ambiguous family and unavailable cue audio produce no answer', () {
    late CourseLearningState state;
    late SoundBoardState board;
    late SoundMatchEngine game;
    late (int, int) ambiguous;
    late (int, int) unavailable;
    for (var seed = 91; seed < 191; seed++) {
      state = _start(engine, 'arcade:sound', seed).$1;
      board =
          (state.activities['arcade:sound']!.snapshot as SoundGameCheckpoint)
              .board;
      game = SoundMatchEngine.fromState(board, random: Random(12));
      final moves = game.legalMoves();
      final ambiguousMoves = moves.where(
          (move) => _swapFamilies(board.board, move.$1, move.$2).length > 1);
      final singleMoves = moves.where(
          (move) => _swapFamilies(board.board, move.$1, move.$2).length == 1);
      if (ambiguousMoves.isNotEmpty && singleMoves.isNotEmpty) {
        ambiguous = ambiguousMoves.first;
        unavailable = singleMoves.first;
        break;
      }
    }
    for (final entry in [
      (
        ambiguous,
        AttemptAudioSource.practiceSpeech,
        game.availableFamilies().first
      ),
      (
        unavailable,
        AttemptAudioSource.notApplicable,
        _swapFamilies(board.board, unavailable.$1, unavailable.$2).single
      ),
    ]) {
      final cueWord = LearningRegistry.french()
          .require('arcade:sound')
          .items
          .firstWhere((item) => wordByText(item.id).contains(entry.$3));
      final command = engine.prepare(
        state: state,
        authGeneration: 0,
        activityId: 'arcade:sound',
        action: SwapSoundTiles(
          first: entry.$1.$1,
          second: entry.$1.$2,
          cue: HeardSoundCue(
            wordId: cueWord.id,
            targetSound: entry.$3,
            audioSource: entry.$2,
          ),
        ),
        token: _tokenFor(
            92 + (entry.$2 == AttemptAudioSource.notApplicable ? 1 : 0)),
        submittedAt: fixedTime,
        random: Random(12),
      );
      final result = engine.evaluate(
          state: state, command: command, committedAt: fixedTime);
      expect(result.attempts, isEmpty);
    }
  });

  test(
      'a cue whose family left the legal board moves retires without an attempt',
      () {
    late CourseLearningState state;
    late SoundBoardState board;
    late SoundMatchEngine game;
    late (int, int) move;
    for (var seed = 191; seed < 291; seed++) {
      state = _start(engine, 'arcade:sound', seed).$1;
      board =
          (state.activities['arcade:sound']!.snapshot as SoundGameCheckpoint)
              .board;
      game = SoundMatchEngine.fromState(board, random: Random(seed));
      if (!game.availableFamilies().contains('u') &&
          game.legalMoves().isNotEmpty) {
        move = game.legalMoves().first;
        break;
      }
    }
    final command = engine.prepare(
      state: state,
      authGeneration: 0,
      activityId: 'arcade:sound',
      action: SwapSoundTiles(
        first: move.$1,
        second: move.$2,
        cue: HeardSoundCue(
          wordId: 'tout',
          targetSound: 'u',
          audioSource: AttemptAudioSource.practiceSpeech,
        ),
      ),
      token: _tokenFor(292),
      submittedAt: fixedTime,
      random: Random(292),
    );
    expect(
        engine
            .evaluate(state: state, command: command, committedAt: fixedTime)
            .attempts,
        isEmpty);
  });

  test('clock elapsed is applied before a move and timeout awards no points',
      () {
    final started = _start(engine, 'arcade:word', 9);
    final original =
        (started.$1.activities['arcade:word']!.snapshot as WordGameCheckpoint)
            .board;
    final slot = _replaceWordBoard(
        started.$1,
        WordBoardState(
          board: List.filled(16, 'tout'),
          target: 'u',
          moves: 0,
          combo: 0,
          stars: const {},
          obstacles: const {5, 10},
        ),
        remaining: 1);
    final clockOnly = engine.prepare(
      state: slot,
      authGeneration: 0,
      activityId: 'arcade:word',
      action: CheckpointArcade(elapsedSeconds: 1, paused: true),
      token: _tokenFor(10),
      submittedAt: fixedTime,
      random: Random(5),
    );
    final timeout = engine.evaluate(
        state: slot, command: clockOnly, committedAt: fixedTime);
    expect((timeout.slot.snapshot as WordGameCheckpoint).clock.remaining, 0);
    expect(timeout.slot.snapshot is WordGameCheckpoint, isTrue);
    final timedOutState = stateAfter(slot, timeout);
    expect(
      () => engine.prepare(
        state: timedOutState,
        authGeneration: 0,
        activityId: 'arcade:word',
        action: LinkWordTiles(indices: [0, 1, 2]),
        token: _tokenFor(11),
        submittedAt: fixedTime,
        random: Random(5),
      ),
      throwsA(anything),
    );
    expect(original.board, hasLength(16));
  });

  test(
      'pause freezes elapsed time and continue preserves score at sixty seconds',
      () {
    final started = _start(engine, 'arcade:word', 101).$1;
    final tenSeconds = _clockCommand(
        engine,
        started,
        CheckpointArcade(
          elapsedSeconds: 10,
          paused: true,
        ),
        102);
    final paused = stateAfter(
        started,
        engine.evaluate(
            state: started, command: tenSeconds, committedAt: fixedTime));
    expect(
        (paused.activities['arcade:word']!.snapshot as WordGameCheckpoint)
            .clock
            .remaining,
        50);

    final resume = _clockCommand(engine, paused,
        CheckpointArcade(elapsedSeconds: 20, paused: false), 103);
    final running = stateAfter(
        paused,
        engine.evaluate(
            state: paused, command: resume, committedAt: fixedTime));
    expect(
        (running.activities['arcade:word']!.snapshot as WordGameCheckpoint)
            .clock
            .remaining,
        50);

    final timeout = _clockCommand(engine, running,
        CheckpointArcade(elapsedSeconds: 50, paused: true), 104);
    final ended = stateAfter(
        running,
        engine.evaluate(
            state: running, command: timeout, committedAt: fixedTime));
    final continueRound =
        _clockCommand(engine, ended, const ContinueArcadeRound(), 105);
    final continued = engine
        .evaluate(state: ended, command: continueRound, committedAt: fixedTime)
        .slot
        .snapshot as WordGameCheckpoint;
    expect(continued.clock.remaining, 60);
    expect(continued.clock.round, 2);
    expect(continued.clock.score, 0);
    expect(continued.clock.paused, isTrue);
  });
}

String _tokenFor(int value) =>
    'AAAAAAAAAAAAAAAAAAAA${(value % 1296).toRadixString(36).padLeft(2, '0')}';

LearningCommand _clockCommand(LearningTransitionEngine engine,
        CourseLearningState state, LearningAction action, int token) =>
    engine.prepare(
      state: state,
      authGeneration: 0,
      activityId: 'arcade:word',
      action: action,
      token: _tokenFor(token),
      submittedAt: fixedTime,
      random: Random(token),
    );

Set<String> _swapFamilies(List<String> source, int first, int second) {
  final board = List<String>.of(source);
  final value = board[first];
  board[first] = board[second];
  board[second] = value;
  final families = <String>{};
  for (var i = 0; i < 36; i++) {
    if (i % 6 <= 3 && board[i] == board[i + 1] && board[i] == board[i + 2]) {
      families.add(board[i]);
    }
    if (i ~/ 6 <= 3 && board[i] == board[i + 6] && board[i] == board[i + 12]) {
      families.add(board[i]);
    }
  }
  return families;
}

(CourseLearningState, Object?) _start(
    LearningTransitionEngine engine, String activityId, int seed) {
  final empty = CourseLearningState.empty(guestScope);
  final command = engine.prepare(
    state: empty,
    authGeneration: 0,
    activityId: activityId,
    action: StartLearningRun(options: RunOptions()),
    token: _tokenFor(seed),
    submittedAt: fixedTime,
    random: Random(seed),
  );
  final transition =
      engine.evaluate(state: empty, command: command, committedAt: fixedTime);
  final state = stateAfter(empty, transition);
  final resume = engine.prepare(
    state: state,
    authGeneration: 0,
    activityId: activityId,
    action: CheckpointArcade(elapsedSeconds: 0, paused: false),
    token: _tokenFor(seed + 100),
    submittedAt: fixedTime,
    random: Random(seed),
  );
  final resumed =
      engine.evaluate(state: state, command: resume, committedAt: fixedTime);
  return (stateAfter(state, resumed), transition);
}

List<int> _validChain(WordBoardState board) {
  final engine = WordMatchEngine.fromState(board, random: Random(1));
  return engine.findChain();
}

CourseLearningState _replaceWordBoard(
    CourseLearningState state, WordBoardState board,
    {int remaining = 60}) {
  final old = state.activities['arcade:word']!;
  final snapshot = WordGameCheckpoint(
    board: board,
    clock: ArcadeClockState(
      remaining: remaining,
      round: 1,
      score: 0,
      paused: false,
    ),
  );
  final replaced = ActivitySlot(
    activityId: old.activityId,
    kind: old.kind,
    contentRevision: old.contentRevision,
    cursor: old.cursor,
    options: old.options,
    snapshot: snapshot,
    exposures: old.exposures,
    latestReceipt: old.latestReceipt,
  );
  return CourseLearningState(
    scope: state.scope,
    revision: state.revision,
    commitOrdinal: state.commitOrdinal,
    history: state.history,
    activities: {...state.activities, 'arcade:word': replaced},
    mistakes: state.mistakes,
    summaries: state.summaries,
    completions: state.completions,
    bestScores: state.bestScores,
    pending: state.pending,
  );
}
