import 'lesson_section_session.dart';

const int _maxSafeInteger = 9007199254740991;

int _bounded(int value, String name, {int minimum = 0, int? maximum}) {
  if (value < minimum || value > (maximum ?? _maxSafeInteger)) {
    throw ArgumentError.value(value, name, 'Out of supported range.');
  }
  return value;
}

List<String> _board(List<String> board, int size) {
  final copy = List<String>.of(board);
  if (copy.length != size || copy.any((value) => value.trim().isEmpty)) {
    throw ArgumentError.value(
        board, 'board', 'Must contain $size nonblank entries.');
  }
  return List.unmodifiable(copy);
}

Set<int> _boardPositions(Set<int> positions, int size, String name) {
  final copy = Set<int>.of(positions);
  if (copy.any((value) => value < 0 || value >= size)) {
    throw ArgumentError.value(
        positions, name, 'Positions must be within the board.');
  }
  return Set.unmodifiable(copy);
}

sealed class ActivitySnapshot {
  const ActivitySnapshot();
}

class DiscoveryCheckpoint extends ActivitySnapshot {
  DiscoveryCheckpoint({required LessonSectionSession session})
      : session = LessonSectionSession.fromJson(
          session.toJson(),
          itemIds: session.itemIds,
          contentRevision: session.contentRevision,
        );
  final LessonSectionSession session;
}

class LegacyLessonCheckpoint extends ActivitySnapshot {
  const LegacyLessonCheckpoint(
      {required this.wordIndex, this.selectedSound, required this.finished});
  final int wordIndex;
  final String? selectedSound;
  final bool finished;
}

class DrillCheckpoint extends ActivitySnapshot {
  DrillCheckpoint(
      {required List<String> pairIds,
      required this.index,
      required this.correct,
      required this.ended})
      : pairIds = List.unmodifiable(pairIds);
  final List<String> pairIds;
  final int index;
  final int correct;
  final bool ended;
}

class ArcadeClockState {
  ArcadeClockState(
      {required int remaining,
      required int round,
      required int score,
      required this.paused})
      : remaining = _bounded(remaining, 'remaining', maximum: 60),
        round = _bounded(round, 'round', minimum: 1),
        score = _bounded(score, 'score');
  final int remaining;
  final int round;
  final int score;
  final bool paused;
}

class SoundBoardState {
  SoundBoardState({required List<String> board, required Set<int> stars})
      : board = _board(board, 36),
        stars = _boardPositions(stars, 36, 'stars');
  final List<String> board;
  final Set<int> stars;
}

class WordBoardState {
  WordBoardState(
      {required List<String> board,
      required String target,
      required int moves,
      required int combo,
      required Set<int> stars,
      required Set<int> obstacles})
      : board = _board(board, 16),
        target = _requiredTarget(target),
        moves = _bounded(moves, 'moves'),
        combo = _bounded(combo, 'combo'),
        stars = _boardPositions(stars, 16, 'stars'),
        obstacles = _boardPositions(obstacles, 16, 'obstacles') {
    if (this.stars.intersection(this.obstacles).isNotEmpty) {
      throw ArgumentError('Stars and obstacles cannot occupy the same tile.');
    }
  }
  final List<String> board;
  final String target;
  final int moves;
  final int combo;
  final Set<int> stars;
  final Set<int> obstacles;
}

String _requiredTarget(String value) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, 'target', 'Must not be blank.');
  }
  return value;
}

class SoundGameCheckpoint extends ActivitySnapshot {
  const SoundGameCheckpoint({required this.board, required this.clock});
  final SoundBoardState board;
  final ArcadeClockState clock;
}

class WordGameCheckpoint extends ActivitySnapshot {
  const WordGameCheckpoint({required this.board, required this.clock});
  final WordBoardState board;
  final ArcadeClockState clock;
}
