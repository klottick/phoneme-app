import 'dart:convert';
import 'dart:math';

import '../../../features/arcade/sound_match_engine.dart';
import '../../../features/arcade/word_match_engine.dart';
import '../course_attempt.dart';
import '../course_learning_checkpoint.dart';
import '../course_learning_registry.dart';
import '../course_learning_state.dart';
import '../lesson_section_session.dart';
import 'learning_tables.dart';

/// Strict, bounded codec for one resumable course activity checkpoint.
///
/// This codec intentionally has no access to course history, receipts, or
/// aggregates. The normalized SQL repository stores exactly one checkpoint
/// document per activity run.
final class CourseLearningCheckpointCodec {
  const CourseLearningCheckpointCodec();

  String encode(ActivitySnapshot snapshot) {
    final Object encoded = _encodeSnapshot(snapshot);
    final String json = jsonEncode(encoded);
    if (utf8.encode(json).length > learningMaxCheckpointBytes) {
      throw ArgumentError.value(
        snapshot,
        'snapshot',
        'Checkpoint exceeds $learningMaxCheckpointBytes UTF-8 bytes.',
      );
    }
    return json;
  }

  ActivitySnapshot decode(
    String json, {
    required LearningActivityKind kind,
    required LearningActivityDefinition definition,
    required RunOptions options,
  }) {
    try {
      if (utf8.encode(json).length > learningMaxCheckpointBytes) {
        throw const FormatException('Checkpoint exceeds the byte limit.');
      }
      if (definition.kind != kind) {
        throw const FormatException('Checkpoint activity kind mismatch.');
      }
      final Map<String, Object?> value = _object(
        jsonDecode(json),
        'checkpoint',
      );
      final String encodedKind = _string(value['kind'], 'checkpoint.kind');
      final ActivitySnapshot snapshot;
      switch (encodedKind) {
        case 'discovery':
          _keys(value, const {'kind', 'session'}, 'discovery checkpoint');
          if (kind != LearningActivityKind.discovery) {
            throw const FormatException('Checkpoint activity kind mismatch.');
          }
          final Map<String, Object?> sessionValue = _object(
            value['session'],
            'checkpoint.session',
          );
          _keys(sessionValue, const {
            'version',
            'sessionId',
            'contentRevision',
            'itemIds',
            'queue',
            'position',
            'round',
            'attemptCount',
            'phase',
            'submittedThisRound',
            'lastCorrect',
            'answered',
            'latestAnswers',
            'policy',
          }, 'checkpoint.session');
          final Map<String, Object?> policy = _object(
            sessionValue['policy'],
            'checkpoint.session.policy',
          );
          _keys(policy, const {
            'completionThresholdPercent',
          }, 'checkpoint.session.policy');
          final List<String> itemIds = definition.items
              .map(
                (item) =>
                    item.sessionAlias ??
                    (throw const FormatException(
                      'Discovery definition has an item without a session alias.',
                    )),
              )
              .toList(growable: false);
          final session = LessonSectionSession.fromJson(
            Map<String, dynamic>.from(sessionValue),
            itemIds: itemIds,
            contentRevision: definition.contentRevision,
          );
          if (session.policy.completionThresholdPercent !=
              options.policy.completionThresholdPercent) {
            throw const FormatException('Checkpoint policy mismatch.');
          }
          snapshot = DiscoveryCheckpoint(session: session);
        case 'legacyLesson':
          _keys(value, const {
            'kind',
            'wordIndex',
            'selectedSound',
            'finished',
          }, 'legacy lesson checkpoint');
          if (kind != LearningActivityKind.legacyLesson) {
            throw const FormatException('Checkpoint activity kind mismatch.');
          }
          final int wordIndex = _integer(value['wordIndex'], 'wordIndex');
          final Object? selectedValue = value['selectedSound'];
          if (selectedValue != null && selectedValue is! String) {
            throw const FormatException('selectedSound must be text or null.');
          }
          final String? selectedSound = selectedValue as String?;
          final bool finished = _boolean(value['finished'], 'finished');
          if (wordIndex > definition.items.length ||
              (selectedSound != null &&
                  (selectedSound.trim().isEmpty ||
                      wordIndex >= definition.items.length ||
                      !definition.items[wordIndex].choices.contains(
                        selectedSound,
                      ))) ||
              (finished &&
                  (wordIndex != definition.items.length ||
                      selectedSound != null))) {
            throw const FormatException(
              'Legacy lesson checkpoint does not match registered content.',
            );
          }
          snapshot = LegacyLessonCheckpoint(
            wordIndex: wordIndex,
            selectedSound: selectedSound,
            finished: finished,
          );
        case 'drill':
          _keys(value, const {
            'kind',
            'pairIds',
            'index',
            'correct',
            'ended',
          }, 'drill checkpoint');
          if (kind != LearningActivityKind.drill) {
            throw const FormatException('Checkpoint activity kind mismatch.');
          }
          final List<String> pairIds = _strings(value['pairIds'], 'pairIds');
          final int index = _integer(value['index'], 'index');
          final int correct = _integer(value['correct'], 'correct');
          final bool ended = _boolean(value['ended'], 'ended');
          if (!_sameOrder(
                pairIds,
                definition.items.map((item) => item.id).toList(),
              ) ||
              pairIds.isEmpty ||
              pairIds.toSet().length != pairIds.length ||
              index > learningMaxSafeInteger ||
              correct > index) {
            throw const FormatException(
              'Drill checkpoint does not match registered content.',
            );
          }
          snapshot = DrillCheckpoint(
            pairIds: pairIds,
            index: index,
            correct: correct,
            ended: ended,
          );
        case 'soundGame':
          _keys(value, const {
            'kind',
            'board',
            'clock',
          }, 'sound game checkpoint');
          if (kind != LearningActivityKind.soundGame) {
            throw const FormatException('Checkpoint activity kind mismatch.');
          }
          final Map<String, Object?> boardValue = _object(
            value['board'],
            'checkpoint.board',
          );
          _keys(boardValue, const {'board', 'stars'}, 'sound game board');
          final board = SoundBoardState(
            board: _strings(boardValue['board'], 'board'),
            stars: _integerSet(boardValue['stars'], 'stars'),
          );
          SoundMatchEngine.fromState(board, random: _CheckpointRandom());
          snapshot = SoundGameCheckpoint(
            board: board,
            clock: _clock(value['clock']),
          );
        case 'wordGame':
          _keys(value, const {
            'kind',
            'board',
            'clock',
          }, 'word game checkpoint');
          if (kind != LearningActivityKind.wordGame) {
            throw const FormatException('Checkpoint activity kind mismatch.');
          }
          final Map<String, Object?> boardValue = _object(
            value['board'],
            'checkpoint.board',
          );
          _keys(boardValue, const {
            'board',
            'target',
            'moves',
            'combo',
            'stars',
            'obstacles',
          }, 'word game board');
          final board = WordBoardState(
            board: _strings(boardValue['board'], 'board'),
            target: _string(boardValue['target'], 'target'),
            moves: _integer(boardValue['moves'], 'moves'),
            combo: _integer(boardValue['combo'], 'combo'),
            stars: _integerSet(boardValue['stars'], 'stars'),
            obstacles: _integerSet(boardValue['obstacles'], 'obstacles'),
          );
          WordMatchEngine.fromState(board, random: _CheckpointRandom());
          snapshot = WordGameCheckpoint(
            board: board,
            clock: _clock(value['clock']),
          );
        default:
          throw const FormatException('Unknown checkpoint kind.');
      }

      // A typed constructor alone does not establish that a snapshot is
      // reachable for the current registered activity.
      return snapshot;
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid course checkpoint: $error');
    }
  }

  Object _encodeSnapshot(ActivitySnapshot snapshot) => switch (snapshot) {
    DiscoveryCheckpoint(:final session) => {
      'kind': 'discovery',
      'session': session.toJson(),
    },
    LegacyLessonCheckpoint(
      :final wordIndex,
      :final selectedSound,
      :final finished,
    ) =>
      _legacyJson(wordIndex, selectedSound, finished),
    DrillCheckpoint(
      :final pairIds,
      :final index,
      :final correct,
      :final ended,
    ) =>
      _drillJson(pairIds, index, correct, ended),
    SoundGameCheckpoint(:final board, :final clock) => {
      'kind': 'soundGame',
      'board': {'board': board.board, 'stars': board.stars.toList()..sort()},
      'clock': _clockJson(clock),
    },
    WordGameCheckpoint(:final board, :final clock) => {
      'kind': 'wordGame',
      'board': {
        'board': board.board,
        'target': board.target,
        'moves': board.moves,
        'combo': board.combo,
        'stars': board.stars.toList()..sort(),
        'obstacles': board.obstacles.toList()..sort(),
      },
      'clock': _clockJson(clock),
    },
  };

  Object _legacyJson(int wordIndex, String? selectedSound, bool finished) {
    _integer(wordIndex, 'wordIndex');
    if (selectedSound != null) _string(selectedSound, 'selectedSound');
    return {
      'kind': 'legacyLesson',
      'wordIndex': wordIndex,
      'selectedSound': selectedSound,
      'finished': finished,
    };
  }

  Object _drillJson(List<String> pairIds, int index, int correct, bool ended) {
    final ids = _strings(pairIds, 'pairIds');
    if (ids.isEmpty || ids.toSet().length != ids.length) {
      throw ArgumentError.value(pairIds, 'pairIds');
    }
    _integer(index, 'index');
    _integer(correct, 'correct');
    if (correct > index) throw ArgumentError.value(correct, 'correct');
    return {
      'kind': 'drill',
      'pairIds': ids,
      'index': index,
      'correct': correct,
      'ended': ended,
    };
  }

  ArcadeClockState _clock(Object? value) {
    final Map<String, Object?> clock = _object(value, 'clock');
    _keys(clock, const {'remaining', 'round', 'score', 'paused'}, 'clock');
    return ArcadeClockState(
      remaining: _integer(clock['remaining'], 'clock.remaining'),
      round: _integer(clock['round'], 'clock.round'),
      score: _integer(clock['score'], 'clock.score'),
      paused: _boolean(clock['paused'], 'clock.paused'),
    );
  }

  Map<String, Object?> _clockJson(ArcadeClockState clock) => {
    'remaining': clock.remaining,
    'round': clock.round,
    'score': clock.score,
    'paused': clock.paused,
  };
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is Map && value.keys.every((key) => key is String)) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('$name must be an object.');
}

void _keys(Map<String, Object?> value, Set<String> keys, String name) {
  if (value.length != keys.length || !value.keys.toSet().containsAll(keys)) {
    throw FormatException('$name has an invalid field set.');
  }
}

String _string(Object? value, String name) {
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$name must be a nonblank string.');
}

int _integer(Object? value, String name) {
  if (value is int && value >= 0 && value <= learningMaxSafeInteger) {
    return value;
  }
  throw FormatException('$name must be a supported nonnegative integer.');
}

bool _boolean(Object? value, String name) {
  if (value is bool) return value;
  throw FormatException('$name must be a boolean.');
}

List<String> _strings(Object? value, String name) {
  if (value is! List) throw FormatException('$name must be a list.');
  final result = value.map((entry) => _string(entry, name)).toList();
  if (result.toSet().length != result.length) {
    throw FormatException('$name contains duplicates.');
  }
  return result;
}

Set<int> _integerSet(Object? value, String name) {
  if (value is! List) throw FormatException('$name must be a list.');
  final values = value.map((entry) => _integer(entry, name)).toList();
  if (values.toSet().length != values.length) {
    throw FormatException('$name contains duplicates.');
  }
  return values.toSet();
}

bool _sameOrder(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

final class _CheckpointRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => throw const FormatException(
    'Checkpoint validation unexpectedly requested randomness.',
  );
}
