import 'lesson_section_session.dart';

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
      {required this.remaining,
      required this.round,
      required this.score,
      required this.paused}) {
    if (remaining < 0 || remaining > 60 || round < 1 || score < 0)
      throw ArgumentError('Invalid arcade clock values');
  }
  final int remaining;
  final int round;
  final int score;
  final bool paused;
}

class SoundBoardState {
  SoundBoardState({required List<String> board, required Set<int> stars})
      : board = List.unmodifiable(board),
        stars = Set.unmodifiable(stars) {
    if (this.board.length != 36)
      throw ArgumentError.value(board, 'board', 'Must contain 36 entries');
  }
  final List<String> board;
  final Set<int> stars;
}

class WordBoardState {
  WordBoardState(
      {required List<String> board,
      required this.target,
      required this.moves,
      required this.combo,
      required Set<int> stars,
      required Set<int> obstacles})
      : board = List.unmodifiable(board),
        stars = Set.unmodifiable(stars),
        obstacles = Set.unmodifiable(obstacles) {
    if (this.board.length != 16 || moves < 0 || combo < 0)
      throw ArgumentError('Invalid word board values');
  }
  final List<String> board;
  final String target;
  final int moves;
  final int combo;
  final Set<int> stars;
  final Set<int> obstacles;
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
