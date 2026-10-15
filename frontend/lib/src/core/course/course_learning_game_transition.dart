import 'dart:math';

import '../../features/arcade/sound_match_engine.dart';
import '../../features/arcade/word_match_engine.dart';
import 'course_attempt.dart';
import 'course_learning_checkpoint.dart';
import 'course_learning_command.dart';
import 'course_learning_error.dart';
import 'course_learning_registry.dart';
import 'course_learning_state.dart';
import 'french_course.dart';

class GameAnswerEvidence {
  const GameAnswerEvidence({
    required this.item,
    required this.target,
    required this.selected,
    required this.expectedMembership,
    required this.correct,
    required this.audioSource,
    required this.tileIndex,
  });

  final LearningSourceItem item;
  final String target, selected;
  final bool expectedMembership, correct;
  final AttemptAudioSource audioSource;
  final int tileIndex;
}

class ArcadeGameMutation {
  ArcadeGameMutation({
    required this.snapshot,
    this.feedback = const LearningFeedback.none(),
    List<GameAnswerEvidence> evidence = const [],
  }) : evidence = List.unmodifiable(evidence);

  final ActivitySnapshot snapshot;
  final LearningFeedback feedback;
  final List<GameAnswerEvidence> evidence;
}

/// Reuses the shipped arcade engines while freezing all randomness and evidence.
class CourseLearningGameTransition {
  const CourseLearningGameTransition(this.registry);

  final LearningRegistry registry;

  ArcadeGameMutation apply({
    required LearningActivityDefinition definition,
    required ActivitySlot? slot,
    required LearningAction action,
    required Random random,
  }) {
    if (definition.kind != LearningActivityKind.soundGame &&
        definition.kind != LearningActivityKind.wordGame) {
      throw const LearningInvalidCommandException();
    }
    if (action is StartLearningRun) {
      if (definition.kind == LearningActivityKind.soundGame) {
        final board = SoundMatchEngine(random: random).snapshot();
        return ArcadeGameMutation(
          snapshot: SoundGameCheckpoint(
            board: board,
            clock: ArcadeClockState(
                remaining: 60, round: 1, score: 0, paused: true),
          ),
        );
      }
      final board = WordMatchEngine(random: random).snapshot();
      return ArcadeGameMutation(
        snapshot: WordGameCheckpoint(
          board: board,
          clock:
              ArcadeClockState(remaining: 60, round: 1, score: 0, paused: true),
        ),
      );
    }
    if (slot == null || slot.kind != definition.kind) {
      throw const LearningInvalidCommandException();
    }
    return switch ((definition.kind, slot.snapshot, action)) {
      (
        LearningActivityKind.soundGame,
        SoundGameCheckpoint(:final board, :final clock),
        CheckpointArcade(:final elapsedSeconds, :final paused)
      ) =>
        ArcadeGameMutation(
            snapshot: SoundGameCheckpoint(
          board: board,
          clock: _checkpoint(clock, elapsedSeconds, paused),
        )),
      (
        LearningActivityKind.wordGame,
        WordGameCheckpoint(:final board, :final clock),
        CheckpointArcade(:final elapsedSeconds, :final paused)
      ) =>
        ArcadeGameMutation(
            snapshot: WordGameCheckpoint(
          board: board,
          clock: _checkpoint(clock, elapsedSeconds, paused),
        )),
      (
        LearningActivityKind.soundGame,
        SoundGameCheckpoint(:final board, :final clock),
        ContinueArcadeRound()
      ) =>
        ArcadeGameMutation(
            snapshot: SoundGameCheckpoint(
          board: board,
          clock: _continue(clock),
        )),
      (
        LearningActivityKind.wordGame,
        WordGameCheckpoint(:final board, :final clock),
        ContinueArcadeRound()
      ) =>
        ArcadeGameMutation(
            snapshot: WordGameCheckpoint(
          board: board,
          clock: _continue(clock),
        )),
      (
        LearningActivityKind.soundGame,
        SoundGameCheckpoint(:final board, :final clock),
        SwapSoundTiles(
          :final first,
          :final second,
          :final cue,
          :final elapsedSeconds
        )
      ) =>
        _swap(definition, board, clock, first, second, cue, elapsedSeconds,
            random),
      (
        LearningActivityKind.wordGame,
        WordGameCheckpoint(:final board, :final clock),
        LinkWordTiles(:final indices, :final elapsedSeconds)
      ) =>
        _link(definition, board, clock, indices, elapsedSeconds, random),
      _ => throw const LearningInvalidCommandException(),
    };
  }

  ArcadeGameMutation _swap(
    LearningActivityDefinition definition,
    SoundBoardState board,
    ArcadeClockState clock,
    int first,
    int second,
    HeardSoundCue? cue,
    int elapsed,
    Random random,
  ) {
    final updatedClock = _beforeMove(clock, elapsed);
    final game = SoundMatchEngine.fromState(board, random: random);
    final preMoveFamilies = game.availableFamilies();
    final move = game.swap(first, second);
    if (!move.accepted) {
      return ArcadeGameMutation(
        snapshot:
            SoundGameCheckpoint(board: game.snapshot(), clock: updatedClock),
        feedback: LearningFeedback(
          message: 'Swap neighbors to make a line of three.',
          points: 0,
          cascades: 0,
          bonus: 0,
          correct: null,
        ),
      );
    }
    final cueItem = cue == null ? null : _authoredItem(definition, cue.wordId);
    final qualifies = cue != null &&
        move.families.length == 1 &&
        preMoveFamilies.contains(cue.targetSound) &&
        cueItem != null &&
        cue.audioSource == authoredAudioSource(cueItem) &&
        wordByText(cue.wordId).contains(cue.targetSound);
    final evidence = <GameAnswerEvidence>[];
    var bonus = 0;
    var suffix = '';
    if (qualifies) {
      final item = cueItem;
      final answerFamily = move.families.single;
      final correct = answerFamily == cue.targetSound;
      if (correct) bonus = 100;
      suffix = correct
          ? ' · Sound bonus +100!'
          : ' · ${cue.wordId} contains /${cue.targetSound}/.';
      evidence.add(GameAnswerEvidence(
        item: item,
        target: cue.targetSound,
        selected: answerFamily,
        expectedMembership: true,
        correct: correct,
        audioSource: cue.audioSource,
        tileIndex: -1,
      ));
    }
    final score = clock.score + move.points + bonus;
    final updated = ArcadeClockState(
      remaining: updatedClock.remaining,
      round: updatedClock.round,
      score: score,
      paused: updatedClock.paused,
    );
    return ArcadeGameMutation(
      snapshot: SoundGameCheckpoint(board: game.snapshot(), clock: updated),
      evidence: evidence,
      feedback: LearningFeedback(
        message:
            '${move.cascades > 1 ? '${move.cascades} cascades! ' : ''}+${move.points}$suffix',
        points: move.points,
        cascades: move.cascades,
        bonus: bonus,
        correct: evidence.isEmpty ? null : evidence.single.correct,
      ),
    );
  }

  ArcadeGameMutation _link(
    LearningActivityDefinition definition,
    WordBoardState board,
    ArcadeClockState clock,
    List<int> indices,
    int elapsed,
    Random random,
  ) {
    final updatedClock = _beforeMove(clock, elapsed);
    final game = WordMatchEngine.fromState(board, random: random);
    final selectedWords = [for (final index in indices) game.board[index]];
    final target = game.target;
    final result = game.submit(indices);
    final evidence = <GameAnswerEvidence>[];
    if (indices.length >= 3 && _geometry(game, indices)) {
      for (var i = 0; i < indices.length; i++) {
        final word = selectedWords[i];
        final item = _authoredItem(definition, word);
        if (item == null) throw const LearningInvalidCommandException();
        final membership = wordByText(word).contains(target);
        evidence.add(GameAnswerEvidence(
          item: item,
          target: target,
          selected: word,
          expectedMembership: membership,
          correct: membership,
          audioSource: AttemptAudioSource.notApplicable,
          tileIndex: indices[i],
        ));
      }
    }
    return ArcadeGameMutation(
      snapshot: WordGameCheckpoint(
        board: game.snapshot(),
        clock: ArcadeClockState(
          remaining: updatedClock.remaining,
          round: updatedClock.round,
          score: updatedClock.score + result.points,
          paused: updatedClock.paused,
        ),
      ),
      evidence: evidence,
      feedback: LearningFeedback(
        message: result.message,
        points: result.points,
        cascades: 0,
        bonus: 0,
        correct:
            evidence.isEmpty ? null : evidence.every((entry) => entry.correct),
      ),
    );
  }

  bool _geometry(WordMatchEngine game, List<int> indices) {
    if (indices.length < 3 || indices.toSet().length != indices.length) {
      return false;
    }
    for (var i = 1; i < indices.length; i++) {
      if (!game.adjacent(indices[i - 1], indices[i])) return false;
    }
    return true;
  }

  LearningSourceItem? _authoredItem(
      LearningActivityDefinition definition, String word) {
    final matches = definition.items.where((item) => item.id == word);
    if (matches.length != 1) return null;
    return matches.single;
  }

  ArcadeClockState _beforeMove(ArcadeClockState clock, int elapsed) {
    if (clock.paused ||
        clock.remaining == 0 ||
        elapsed < 0 ||
        elapsed >= clock.remaining) {
      throw const LearningInvalidCommandException();
    }
    return ArcadeClockState(
      remaining: clock.remaining - elapsed,
      round: clock.round,
      score: clock.score,
      paused: false,
    );
  }

  ArcadeClockState _checkpoint(
      ArcadeClockState clock, int elapsed, bool paused) {
    final remaining =
        clock.paused ? clock.remaining : clock.remaining - elapsed;
    if (elapsed < 0 || elapsed > clock.remaining || remaining < 0) {
      throw const LearningInvalidCommandException();
    }
    if (remaining == 0 && !paused) {
      throw const LearningInvalidCommandException();
    }
    return ArcadeClockState(
      remaining: remaining,
      round: clock.round,
      score: clock.score,
      paused: paused,
    );
  }

  ArcadeClockState _continue(ArcadeClockState clock) {
    if (clock.remaining != 0) throw const LearningInvalidCommandException();
    return ArcadeClockState(
      remaining: 60,
      round: clock.round + 1,
      score: clock.score,
      paused: true,
    );
  }
}
