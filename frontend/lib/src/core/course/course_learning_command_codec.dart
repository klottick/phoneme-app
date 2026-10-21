import 'dart:convert';

import 'course_attempt.dart';
import 'course_learning_checkpoint.dart';
import 'course_learning_command.dart';
import 'course_learning_state.dart';
import 'lesson_policy.dart';
import 'lesson_section_session.dart';

/// SQL-facing command identity, distinct from the active preferences payload.
final class CourseLearningCommandCodec {
  const CourseLearningCommandCodec();

  static String canonicalCommand(LearningCommand command) {
    final Map<String, Object?> identity = Map<String, Object?>.from(
      jsonDecode(legacyCanonicalCommand(command)) as Map<String, dynamic>,
    );
    identity['expectedScopeRevision'] = command.expectedScopeRevision;
    return jsonEncode(_sort(identity));
  }

  static String legacyCanonicalCommand(LearningCommand command) =>
      jsonEncode(_sort(_legacyCommandProjection(command)));

  static LearningCommand decodeCanonicalCommand(
    String raw, {
    required LearningScope scope,
  }) {
    try {
      final Map<String, Object?> value = _object(jsonDecode(raw), 'command');
      _keys(value, const <String>{
        'action',
        'activityId',
        'authGeneration',
        'candidate',
        'draws',
        'expected',
        'expectedScopeRevision',
        'feedback',
        'scope',
        'submittedAt',
        'token',
      }, 'command');
      if (_string(value['scope'], 'scope') != scope.storageKey) {
        throw const FormatException('Command scope mismatch.');
      }
      final LearningCommand command = LearningCommand(
        scope: scope,
        authGeneration: _integer(value['authGeneration'], 'authGeneration'),
        activityId: _string(value['activityId'], 'activityId'),
        expected: _readCursor(value['expected']),
        expectedScopeRevision: _integer(
          value['expectedScopeRevision'],
          'expectedScopeRevision',
        ),
        token: _string(value['token'], 'token'),
        submittedAt: _utc(value['submittedAt'], 'submittedAt'),
        action: _readAction(value['action']),
        draws: _array(
          value['draws'],
          'draws',
        ).map((Object? entry) => _readDraw(entry)).toList(growable: false),
        candidate: _readSnapshot(value['candidate']),
        feedback: _readFeedback(value['feedback']),
      );
      if (canonicalCommand(command) != raw) {
        throw const FormatException('Noncanonical SQL command identity.');
      }
      return command;
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Invalid SQL command identity: $error');
    }
  }
}

Map<String, Object?> _legacyCommandProjection(LearningCommand command) =>
    <String, Object?>{
      'scope': command.scope.storageKey,
      'authGeneration': command.authGeneration,
      'activityId': command.activityId,
      'expected': _legacyCursor(command.expected),
      'token': command.token,
      'submittedAt': command.submittedAt.toUtc().toIso8601String(),
      'action': _legacyAction(command.action),
      'draws': command.draws
          .map(
            (RandomDraw draw) => <String, Object?>{
              'upperBound': draw.upperBound,
              'value': draw.value,
            },
          )
          .toList(),
      'candidate': _legacySnapshot(command.candidate),
      'feedback': <String, Object?>{
        'message': command.feedback.message,
        'points': command.feedback.points,
        'cascades': command.feedback.cascades,
        'bonus': command.feedback.bonus,
        'correct': command.feedback.correct,
      },
    };

Map<String, Object?> _legacyCursor(SlotCursor cursor) => <String, Object?>{
  'generation': cursor.generation,
  'sequence': cursor.sequence,
  'revision': cursor.revision,
};

Map<String, Object?> _legacyAction(LearningAction action) => switch (action) {
  final StartLearningRun value => <String, Object?>{
    'kind': 'startRun',
    'options': value.options.policy.toJson(),
  },
  final ChooseSound value => <String, Object?>{
    'kind': 'chooseSound',
    'selectedSound': value.selectedSound,
    'audioSource': value.audioSource.name,
  },
  final ChooseDrillWord value => <String, Object?>{
    'kind': 'chooseDrillWord',
    'selectedWord': value.selectedWord,
    'audioSource': value.audioSource.name,
  },
  AdvanceLesson _ => <String, Object?>{'kind': 'advanceLesson'},
  ReviewDiscoveryMistakes _ => <String, Object?>{
    'kind': 'reviewDiscoveryMistakes',
  },
  final ObserveAssistance value => <String, Object?>{
    'kind': 'observeAssistance',
    'items':
        value.items
            .map(
              (ItemContextKey item) => <String, Object?>{
                'itemId': item.itemId,
                'targetSound': item.targetSound,
              },
            )
            .toList()
          ..sort(
            (Map<String, Object?> first, Map<String, Object?> second) =>
                jsonEncode(first).compareTo(jsonEncode(second)),
          ),
    'flags': _legacyEnumSet(value.flags),
  },
  final FinishLearningActivity value => <String, Object?>{
    'kind': 'finishLearningActivity',
    'recordCompletion': value.recordCompletion,
  },
  EndDrill _ => <String, Object?>{'kind': 'endDrill'},
  final SwapSoundTiles value => <String, Object?>{
    'kind': 'swapSoundTiles',
    'first': value.first,
    'second': value.second,
    'cue': value.cue == null
        ? null
        : <String, Object?>{
            'wordId': value.cue!.wordId,
            'targetSound': value.cue!.targetSound,
            'audioSource': value.cue!.audioSource.name,
          },
    'elapsedSeconds': value.elapsedSeconds,
  },
  final LinkWordTiles value => <String, Object?>{
    'kind': 'linkWordTiles',
    'indices': value.indices,
    'elapsedSeconds': value.elapsedSeconds,
  },
  final CheckpointArcade value => <String, Object?>{
    'kind': 'checkpointArcade',
    'elapsedSeconds': value.elapsedSeconds,
    'paused': value.paused,
  },
  ContinueArcadeRound _ => <String, Object?>{'kind': 'continueArcadeRound'},
};

Map<String, Object?> _legacySnapshot(ActivitySnapshot snapshot) =>
    switch (snapshot) {
      final DiscoveryCheckpoint value => <String, Object?>{
        'kind': 'discovery',
        'session': value.session.toJson(),
      },
      final LegacyLessonCheckpoint value => <String, Object?>{
        'kind': 'legacyLesson',
        'wordIndex': value.wordIndex,
        'selectedSound': value.selectedSound,
        'finished': value.finished,
      },
      final DrillCheckpoint value => <String, Object?>{
        'kind': 'drill',
        'pairIds': value.pairIds,
        'index': value.index,
        'correct': value.correct,
        'ended': value.ended,
      },
      final SoundGameCheckpoint value => <String, Object?>{
        'kind': 'soundGame',
        'board': <String, Object?>{
          'board': value.board.board,
          'stars': _legacySortedSet(value.board.stars),
        },
        'clock': _legacyClock(value.clock),
      },
      final WordGameCheckpoint value => <String, Object?>{
        'kind': 'wordGame',
        'board': <String, Object?>{
          'board': value.board.board,
          'target': value.board.target,
          'moves': value.board.moves,
          'combo': value.board.combo,
          'stars': _legacySortedSet(value.board.stars),
          'obstacles': _legacySortedSet(value.board.obstacles),
        },
        'clock': _legacyClock(value.clock),
      },
    };

Map<String, Object?> _legacyClock(ArcadeClockState clock) => <String, Object?>{
  'remaining': clock.remaining,
  'round': clock.round,
  'score': clock.score,
  'paused': clock.paused,
};

List<int> _legacySortedSet(Set<int> values) => values.toList()..sort();

List<String> _legacyEnumSet<T extends Enum>(Set<T> values) =>
    values.map((T value) => value.name).toList()..sort();

LearningAction _readAction(Object? raw) {
  final Map<String, Object?> value = _object(raw, 'action');
  final String kind = _string(value['kind'], 'action.kind');
  switch (kind) {
    case 'startRun':
      _keys(value, const <String>{'kind', 'options'}, 'action');
      final Map<String, Object?> options = _object(value['options'], 'options');
      _keys(options, const <String>{'completionThresholdPercent'}, 'options');
      return StartLearningRun(
        options: RunOptions(
          policy: LessonPolicy.fromJson(Map<String, dynamic>.from(options)),
        ),
      );
    case 'chooseSound':
      _keys(value, const <String>{
        'kind',
        'selectedSound',
        'audioSource',
      }, 'action');
      return ChooseSound(
        selectedSound: _string(value['selectedSound'], 'selectedSound'),
        audioSource: _enumValue(
          AttemptAudioSource.values,
          value['audioSource'],
          'audioSource',
        ),
      );
    case 'chooseDrillWord':
      _keys(value, const <String>{
        'kind',
        'selectedWord',
        'audioSource',
      }, 'action');
      return ChooseDrillWord(
        selectedWord: _string(value['selectedWord'], 'selectedWord'),
        audioSource: _enumValue(
          AttemptAudioSource.values,
          value['audioSource'],
          'audioSource',
        ),
      );
    case 'advanceLesson':
      _keys(value, const <String>{'kind'}, 'action');
      return const AdvanceLesson();
    case 'reviewDiscoveryMistakes':
      _keys(value, const <String>{'kind'}, 'action');
      return const ReviewDiscoveryMistakes();
    case 'observeAssistance':
      _keys(value, const <String>{'kind', 'items', 'flags'}, 'action');
      final Set<ItemContextKey> items = <ItemContextKey>{};
      for (final Object? item in _array(value['items'], 'items')) {
        final Map<String, Object?> itemValue = _object(item, 'item');
        _keys(itemValue, const <String>{'itemId', 'targetSound'}, 'item');
        if (!items.add(
          ItemContextKey(
            itemId: _string(itemValue['itemId'], 'itemId'),
            targetSound: _string(itemValue['targetSound'], 'targetSound'),
          ),
        )) {
          throw const FormatException('Duplicate assistance item.');
        }
      }
      return ObserveAssistance(
        items: items,
        flags: _enumList(
          AssistanceFlag.values,
          value['flags'],
          'flags',
        ).toSet(),
      );
    case 'finishLearningActivity':
      _keys(value, const <String>{'kind', 'recordCompletion'}, 'action');
      return FinishLearningActivity(
        recordCompletion: _boolean(
          value['recordCompletion'],
          'recordCompletion',
        ),
      );
    case 'endDrill':
      _keys(value, const <String>{'kind'}, 'action');
      return const EndDrill();
    case 'swapSoundTiles':
      _keys(value, const <String>{
        'kind',
        'first',
        'second',
        'cue',
        'elapsedSeconds',
      }, 'action');
      final Object? cueRaw = value['cue'];
      final HeardSoundCue? cue;
      if (cueRaw == null) {
        cue = null;
      } else {
        final Map<String, Object?> cueValue = _object(cueRaw, 'cue');
        _keys(cueValue, const <String>{
          'wordId',
          'targetSound',
          'audioSource',
        }, 'cue');
        cue = HeardSoundCue(
          wordId: _string(cueValue['wordId'], 'cue.wordId'),
          targetSound: _string(cueValue['targetSound'], 'cue.targetSound'),
          audioSource: _enumValue(
            AttemptAudioSource.values,
            cueValue['audioSource'],
            'cue.audioSource',
          ),
        );
      }
      return SwapSoundTiles(
        first: _integer(value['first'], 'first'),
        second: _integer(value['second'], 'second'),
        cue: cue,
        elapsedSeconds: _integer(value['elapsedSeconds'], 'elapsedSeconds'),
      );
    case 'linkWordTiles':
      _keys(value, const <String>{
        'kind',
        'indices',
        'elapsedSeconds',
      }, 'action');
      return LinkWordTiles(
        indices: _integerList(value['indices'], 'indices'),
        elapsedSeconds: _integer(value['elapsedSeconds'], 'elapsedSeconds'),
      );
    case 'checkpointArcade':
      _keys(value, const <String>{
        'kind',
        'elapsedSeconds',
        'paused',
      }, 'action');
      return CheckpointArcade(
        elapsedSeconds: _integer(value['elapsedSeconds'], 'elapsedSeconds'),
        paused: _boolean(value['paused'], 'paused'),
      );
    case 'continueArcadeRound':
      _keys(value, const <String>{'kind'}, 'action');
      return const ContinueArcadeRound();
    default:
      throw const FormatException('Unknown action kind.');
  }
}

ActivitySnapshot _readSnapshot(Object? raw) {
  final Map<String, Object?> value = _object(raw, 'candidate');
  switch (_string(value['kind'], 'candidate.kind')) {
    case 'discovery':
      _keys(value, const <String>{'kind', 'session'}, 'candidate');
      final Map<String, Object?> session = _object(value['session'], 'session');
      _keys(session, const <String>{
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
      }, 'session');
      final List<String> itemIds = _stringList(session['itemIds'], 'itemIds');
      return DiscoveryCheckpoint(
        session: LessonSectionSession.fromJson(
          Map<String, dynamic>.from(session),
          itemIds: itemIds,
          contentRevision: _integer(
            session['contentRevision'],
            'contentRevision',
          ),
        ),
      );
    case 'legacyLesson':
      _keys(value, const <String>{
        'kind',
        'wordIndex',
        'selectedSound',
        'finished',
      }, 'candidate');
      final Object? selectedSound = value['selectedSound'];
      return LegacyLessonCheckpoint(
        wordIndex: _integer(value['wordIndex'], 'wordIndex'),
        selectedSound: selectedSound == null
            ? null
            : _string(selectedSound, 'selectedSound'),
        finished: _boolean(value['finished'], 'finished'),
      );
    case 'drill':
      _keys(value, const <String>{
        'kind',
        'pairIds',
        'index',
        'correct',
        'ended',
      }, 'candidate');
      return DrillCheckpoint(
        pairIds: _stringList(value['pairIds'], 'pairIds'),
        index: _integer(value['index'], 'index'),
        correct: _integer(value['correct'], 'correct'),
        ended: _boolean(value['ended'], 'ended'),
      );
    case 'soundGame':
      _keys(value, const <String>{'kind', 'board', 'clock'}, 'candidate');
      final Map<String, Object?> board = _object(value['board'], 'board');
      _keys(board, const <String>{'board', 'stars'}, 'board');
      return SoundGameCheckpoint(
        board: SoundBoardState(
          board: _stringList(board['board'], 'board'),
          stars: _integerSet(board['stars'], 'stars'),
        ),
        clock: _readClock(value['clock']),
      );
    case 'wordGame':
      _keys(value, const <String>{'kind', 'board', 'clock'}, 'candidate');
      final Map<String, Object?> board = _object(value['board'], 'board');
      _keys(board, const <String>{
        'board',
        'target',
        'moves',
        'combo',
        'stars',
        'obstacles',
      }, 'board');
      return WordGameCheckpoint(
        board: WordBoardState(
          board: _stringList(board['board'], 'board'),
          target: _string(board['target'], 'target'),
          moves: _integer(board['moves'], 'moves'),
          combo: _integer(board['combo'], 'combo'),
          stars: _integerSet(board['stars'], 'stars'),
          obstacles: _integerSet(board['obstacles'], 'obstacles'),
        ),
        clock: _readClock(value['clock']),
      );
    default:
      throw const FormatException('Unknown candidate kind.');
  }
}

ArcadeClockState _readClock(Object? raw) {
  final Map<String, Object?> value = _object(raw, 'clock');
  _keys(value, const <String>{
    'remaining',
    'round',
    'score',
    'paused',
  }, 'clock');
  return ArcadeClockState(
    remaining: _integer(value['remaining'], 'remaining'),
    round: _integer(value['round'], 'round'),
    score: _integer(value['score'], 'score'),
    paused: _boolean(value['paused'], 'paused'),
  );
}

LearningFeedback _readFeedback(Object? raw) {
  final Map<String, Object?> value = _object(raw, 'feedback');
  _keys(value, const <String>{
    'message',
    'points',
    'cascades',
    'bonus',
    'correct',
  }, 'feedback');
  final Object? correct = value['correct'];
  if (correct != null && correct is! bool) {
    throw const FormatException('feedback.correct must be boolean or null.');
  }
  final Object? message = value['message'];
  if (message is! String) {
    throw const FormatException('feedback.message must be a string.');
  }
  return LearningFeedback(
    message: message,
    points: _integer(value['points'], 'points'),
    cascades: _integer(value['cascades'], 'cascades'),
    bonus: _integer(value['bonus'], 'bonus'),
    correct: correct as bool?,
  );
}

RandomDraw _readDraw(Object? raw) {
  final Map<String, Object?> value = _object(raw, 'draw');
  _keys(value, const <String>{'upperBound', 'value'}, 'draw');
  return RandomDraw(
    upperBound: _integer(value['upperBound'], 'upperBound'),
    value: _integer(value['value'], 'value'),
  );
}

SlotCursor _readCursor(Object? raw) {
  final Map<String, Object?> value = _object(raw, 'expected');
  _keys(value, const <String>{
    'generation',
    'sequence',
    'revision',
  }, 'expected');
  return SlotCursor(
    generation: _integer(value['generation'], 'generation'),
    sequence: _integer(value['sequence'], 'sequence'),
    revision: _integer(value['revision'], 'revision'),
  );
}

List<int> _integerList(Object? raw, String name) =>
    _array(raw, name).map((Object? value) => _integer(value, name)).toList();

List<String> _stringList(Object? raw, String name) =>
    _array(raw, name).map((Object? value) => _string(value, name)).toList();

Set<int> _integerSet(Object? raw, String name) {
  final List<int> values = _integerList(raw, name);
  if (values.toSet().length != values.length) {
    throw FormatException('$name contains duplicates.');
  }
  return values.toSet();
}

List<T> _enumList<T extends Enum>(List<T> values, Object? raw, String name) {
  final List<T> parsed = _array(
    raw,
    name,
  ).map((Object? value) => _enumValue(values, value, name)).toList();
  if (parsed.toSet().length != parsed.length) {
    throw FormatException('$name contains duplicates.');
  }
  return parsed;
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, String name) {
  final String text = _string(raw, name);
  for (final T value in values) {
    if (value.name == text) return value;
  }
  throw FormatException('$name has an unknown value.');
}

DateTime _utc(Object? raw, String name) {
  final DateTime parsed = DateTime.parse(_string(raw, name));
  if (!parsed.isUtc) throw FormatException('$name must be UTC.');
  return parsed;
}

int _integer(Object? value, String name) {
  if (value is int && value >= 0 && value <= 9007199254740991) return value;
  throw FormatException('$name must be a supported nonnegative integer.');
}

String _string(Object? value, String name) {
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$name must be a nonblank string.');
}

bool _boolean(Object? value, String name) {
  if (value is bool) return value;
  throw FormatException('$name must be boolean.');
}

List<Object?> _array(Object? value, String name) {
  if (value is List) return value;
  throw FormatException('$name must be a list.');
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is Map && value.keys.every((Object? key) => key is String)) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('$name must be an object.');
}

void _keys(Map<String, Object?> value, Set<String> expected, String name) {
  if (value.length != expected.length ||
      !value.keys.toSet().containsAll(expected)) {
    throw FormatException('$name has an invalid field set.');
  }
}

Object? _sort(Object? value) {
  if (value is Map) {
    final List<String> keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final String key in keys) key: _sort(value[key]),
    };
  }
  if (value is List) return value.map(_sort).toList();
  return value;
}
