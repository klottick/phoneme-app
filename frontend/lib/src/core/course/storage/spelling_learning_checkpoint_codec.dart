import 'dart:convert';

import '../course_attempt.dart';
import '../french_uy_demo_spelling_content.dart';
import '../lesson_policy.dart';
import '../lesson_section_session.dart';
import '../spelling_learning_state.dart';
import 'learning_tables.dart' show learningMaxCheckpointBytes;

final class SpellingLearningCheckpointCodec {
  const SpellingLearningCheckpointCodec();

  static const List<String> _checkpointFields = <String>[
    'version',
    'scope',
    'sessionId',
    'contentRevision',
    'policy',
    'mode',
    'runStartRound',
    'finished',
    'session',
    'firstAttemptAnswers',
    'baseline',
  ];

  static const List<String> _sessionFields = <String>[
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
  ];

  static const List<String> _baselineFields = <String>[
    'sourceGeneration',
    'sourceSessionId',
    'sourceContentRevision',
    'sourceRound',
    'firstAttemptAnswers',
    'latestPracticeAnswers',
    'policy',
  ];

  String encode(SpellingCheckpoint checkpoint) {
    final catalogue = loadFrenchUyDemoSpellingCatalogue();
    final session = _validateCheckpoint(
      checkpoint,
      scope: checkpoint.scope,
      catalogue: catalogue,
      policy: checkpoint.policy,
    );
    final encoded = jsonEncode(<String, Object?>{
      'version': 1,
      'scope': _scopeJson(checkpoint.scope),
      'sessionId': checkpoint.sessionId,
      'contentRevision': checkpoint.contentRevision,
      'policy': checkpoint.policy.toJson(),
      'mode': checkpoint.mode.name,
      'runStartRound': checkpoint.runStartRound,
      'finished': checkpoint.finished,
      'session': session.toJson(),
      'firstAttemptAnswers': checkpoint.firstAttemptAnswers,
      'baseline': checkpoint.baseline == null
          ? null
          : _baselineJson(checkpoint.baseline!),
    });
    if (utf8.encode(encoded).length > learningMaxCheckpointBytes) {
      throw ArgumentError.value(
        checkpoint,
        'checkpoint',
        'Checkpoint exceeds $learningMaxCheckpointBytes UTF-8 bytes.',
      );
    }
    return encoded;
  }

  SpellingCheckpoint decode(
    String json, {
    required SpellingProfileScope scope,
    required FrenchUyDemoSpellingCatalogue catalogue,
    required LessonPolicy policy,
  }) {
    try {
      if (utf8.encode(json).length > learningMaxCheckpointBytes) {
        throw const FormatException('Checkpoint exceeds the UTF-8 byte limit.');
      }
      validateFrenchUyDemoSpellingCatalogue(catalogue);
      final root = _object(jsonDecode(json), 'checkpoint');
      _exactKeys(root, _checkpointFields, 'checkpoint');
      if (_integer(root['version'], 'checkpoint.version') != 1) {
        throw const FormatException('Unsupported spelling checkpoint version.');
      }
      final savedScope = _readScope(root['scope'], 'checkpoint.scope');
      final sessionId = _text(root['sessionId'], 'checkpoint.sessionId');
      final contentRevision = _positive(
        root['contentRevision'],
        'checkpoint.contentRevision',
      );
      final savedPolicy = _readPolicy(root['policy'], 'checkpoint.policy');
      final mode = _runMode(root['mode']);
      final runStartRound = _positive(
        root['runStartRound'],
        'checkpoint.runStartRound',
      );
      final finished = _boolean(root['finished'], 'checkpoint.finished');
      if (savedScope != scope ||
          savedScope.courseId != 'en-fr' ||
          contentRevision != catalogue.contentRevision ||
          contentRevision != 1 ||
          savedPolicy.completionThresholdPercent !=
              policy.completionThresholdPercent ||
          policy.completionThresholdPercent != 80 ||
          catalogue.activityId != 'en-fr-u-y-spelling') {
        throw const FormatException('Checkpoint profile or policy mismatch.');
      }
      final ids = catalogue.rows.map((row) => row.exercise.id).toList();
      final sessionRaw = _object(root['session'], 'checkpoint.session');
      _exactKeys(sessionRaw, _sessionFields, 'checkpoint.session');
      final session = _readSession(
        sessionRaw,
        itemIds: ids,
        contentRevision: contentRevision,
        policy: savedPolicy,
      );
      if (session.sessionId != sessionId ||
          session.contentRevision != contentRevision ||
          runStartRound > session.round ||
          (finished && session.phase != LessonSectionPhase.debrief)) {
        throw const FormatException('Checkpoint session is unreachable.');
      }
      final first = _answerMap(
        root['firstAttemptAnswers'],
        'checkpoint.firstAttemptAnswers',
        ids,
        allowPrefix: mode == SpellingRunMode.practice && session.round == 1,
      );
      final baselineRaw = root['baseline'];
      final baseline = baselineRaw == null
          ? null
          : _readBaseline(baselineRaw, ids: ids, policy: savedPolicy);
      final checkpoint = SpellingCheckpoint(
        scope: savedScope,
        sessionId: sessionId,
        contentRevision: contentRevision,
        policy: savedPolicy,
        mode: mode,
        runStartRound: runStartRound,
        finished: finished,
        sessionJson: session.toJson().cast<String, Object?>(),
        firstAttemptAnswers: first,
        baseline: baseline,
      );
      _validateCheckpoint(
        checkpoint,
        scope: scope,
        catalogue: catalogue,
        policy: policy,
      );
      if (encode(checkpoint) != json) {
        throw const FormatException('Checkpoint JSON is not canonical.');
      }
      return checkpoint;
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid spelling checkpoint: $error');
    }
  }

  static LessonSectionSession _validateCheckpoint(
    SpellingCheckpoint checkpoint, {
    required SpellingProfileScope scope,
    required FrenchUyDemoSpellingCatalogue catalogue,
    required LessonPolicy policy,
  }) {
    if (checkpoint.scope != scope ||
        scope.courseId != 'en-fr' ||
        catalogue.activityId != 'en-fr-u-y-spelling' ||
        catalogue.sectionId != catalogue.activityId ||
        catalogue.contentRevision != 1 ||
        checkpoint.contentRevision != catalogue.contentRevision ||
        checkpoint.policy.completionThresholdPercent != 80 ||
        checkpoint.policy.completionThresholdPercent !=
            policy.completionThresholdPercent ||
        checkpoint.runStartRound < 1 ||
        checkpoint.finished && checkpoint.sessionJson['phase'] != 'debrief') {
      throw const FormatException('Checkpoint metadata is invalid.');
    }
    final ids = catalogue.rows.map((row) => row.exercise.id).toList();
    final raw = _object(checkpoint.sessionJson, 'checkpoint.session');
    _exactKeys(raw, _sessionFields, 'checkpoint.session');
    final session = _readSession(
      raw,
      itemIds: ids,
      contentRevision: catalogue.contentRevision,
      policy: checkpoint.policy,
    );
    if (session.sessionId != checkpoint.sessionId ||
        session.contentRevision != checkpoint.contentRevision ||
        session.round < checkpoint.runStartRound ||
        checkpoint.finished && session.phase != LessonSectionPhase.debrief) {
      throw const FormatException('Checkpoint does not match its session.');
    }
    final first = _answerMap(
      checkpoint.firstAttemptAnswers,
      'checkpoint.firstAttemptAnswers',
      ids,
      allowPrefix:
          checkpoint.mode == SpellingRunMode.practice && session.round == 1,
    );
    if (checkpoint.mode == SpellingRunMode.practice) {
      if (checkpoint.runStartRound != 1 || checkpoint.baseline != null) {
        throw const FormatException('Practice checkpoint has review lineage.');
      }
      if (session.round == 1) {
        if (!_sameOrder(first.keys.toList(), _submittedThisRound(session)) ||
            first.entries.any(
              (entry) => session.latestAnswers[entry.key] != entry.value,
            )) {
          throw const FormatException(
            'First-pass prefix differs from session.',
          );
        }
      } else if (!_sameOrder(first.keys.toList(), ids)) {
        throw const FormatException('Completed first-pass map must be full.');
      }
    } else {
      final baseline = checkpoint.baseline;
      if (baseline == null ||
          first.length != ids.length ||
          !_sameOrder(first.keys.toList(), ids) ||
          !_sameOrder(baseline.firstAttemptAnswers.keys.toList(), ids) ||
          !_sameOrder(baseline.latestPracticeAnswers.keys.toList(), ids) ||
          !_sameAnswers(first, baseline.firstAttemptAnswers) ||
          baseline.sourceContentRevision != checkpoint.contentRevision ||
          baseline.policy.completionThresholdPercent !=
              checkpoint.policy.completionThresholdPercent ||
          baseline.sourceRound + 1 != checkpoint.runStartRound ||
          checkpoint.runStartRound < 2 ||
          !baseline.latestPracticeAnswers.values.any((answer) => !answer)) {
        throw const FormatException('Review-only baseline is invalid.');
      }
      if (session.round == checkpoint.runStartRound) {
        final submitted = _submittedThisRound(session).toSet();
        final unchangedIds = ids.where((id) => !submitted.contains(id));
        if (!_sameOrder(
              session.queue,
              ids
                  .where((id) => baseline.latestPracticeAnswers[id] == false)
                  .toList(),
            ) ||
            unchangedIds.any(
              (id) =>
                  session.latestAnswers[id] !=
                  baseline.latestPracticeAnswers[id],
            )) {
          throw const FormatException(
            'Review-only start does not match its baseline.',
          );
        }
      }
    }
    return session;
  }

  static LessonSectionSession _readSession(
    Map<String, Object?> raw, {
    required List<String> itemIds,
    required int contentRevision,
    required LessonPolicy policy,
  }) {
    for (final key in const [
      'version',
      'contentRevision',
      'position',
      'round',
      'attemptCount',
    ]) {
      _integer(raw[key], 'session.$key');
    }
    _text(raw['sessionId'], 'session.sessionId');
    _stringList(raw['itemIds'], 'session.itemIds');
    _stringList(raw['queue'], 'session.queue');
    _stringList(raw['submittedThisRound'], 'session.submittedThisRound');
    _text(raw['phase'], 'session.phase');
    _boolean(raw['answered'], 'session.answered');
    if (raw['lastCorrect'] != null) {
      _boolean(raw['lastCorrect'], 'session.lastCorrect');
    }
    final savedPolicy = _readPolicy(raw['policy'], 'session.policy');
    if (savedPolicy.completionThresholdPercent !=
        policy.completionThresholdPercent) {
      throw const FormatException('Session policy differs from checkpoint.');
    }
    final latest = _answerMap(
      raw['latestAnswers'],
      'session.latestAnswers',
      itemIds,
      allowPrefix: true,
    );
    if (!_sameOrder(latest.keys.toList(), [
      for (final id in itemIds)
        if (latest.containsKey(id)) id,
    ])) {
      throw const FormatException(
        'Session answer keys are out of authored order.',
      );
    }
    final session = LessonSectionSession.fromJson(
      Map<String, dynamic>.from(raw),
      itemIds: itemIds,
      contentRevision: contentRevision,
    );
    if (jsonEncode(session.toJson()) != jsonEncode(raw)) {
      throw const FormatException('Session JSON is not canonical.');
    }
    return session;
  }

  static SpellingPracticeBaseline _readBaseline(
    Object? raw, {
    required List<String> ids,
    required LessonPolicy policy,
  }) {
    final value = _object(raw, 'checkpoint.baseline');
    _exactKeys(value, _baselineFields, 'checkpoint.baseline');
    final savedPolicy = _readPolicy(value['policy'], 'baseline.policy');
    if (savedPolicy.completionThresholdPercent !=
        policy.completionThresholdPercent) {
      throw const FormatException('Baseline policy differs from checkpoint.');
    }
    return SpellingPracticeBaseline(
      sourceGeneration: _positive(
        value['sourceGeneration'],
        'baseline.sourceGeneration',
      ),
      sourceSessionId: _text(
        value['sourceSessionId'],
        'baseline.sourceSessionId',
      ),
      sourceContentRevision: _positive(
        value['sourceContentRevision'],
        'baseline.sourceContentRevision',
      ),
      sourceRound: _positive(value['sourceRound'], 'baseline.sourceRound'),
      firstAttemptAnswers: _answerMap(
        value['firstAttemptAnswers'],
        'baseline.firstAttemptAnswers',
        ids,
        allowPrefix: false,
      ),
      latestPracticeAnswers: _answerMap(
        value['latestPracticeAnswers'],
        'baseline.latestPracticeAnswers',
        ids,
        allowPrefix: false,
      ),
      policy: savedPolicy,
    );
  }

  static Map<String, Object?> _scopeJson(SpellingProfileScope scope) =>
      <String, Object?>{
        'courseId': scope.courseId,
        'owner': <String, Object?>{
          'kind': scope.owner.isGuest ? 'guest' : 'account',
          'id': scope.owner.userId ?? '',
        },
      };

  static Map<String, Object?> _baselineJson(
    SpellingPracticeBaseline baseline,
  ) => <String, Object?>{
    'sourceGeneration': baseline.sourceGeneration,
    'sourceSessionId': baseline.sourceSessionId,
    'sourceContentRevision': baseline.sourceContentRevision,
    'sourceRound': baseline.sourceRound,
    'firstAttemptAnswers': baseline.firstAttemptAnswers,
    'latestPracticeAnswers': baseline.latestPracticeAnswers,
    'policy': baseline.policy.toJson(),
  };

  static SpellingProfileScope _readScope(Object? raw, String name) {
    final value = _object(raw, name);
    _exactKeys(value, const ['courseId', 'owner'], name);
    final owner = _object(value['owner'], '$name.owner');
    _exactKeys(owner, const ['kind', 'id'], '$name.owner');
    final kind = _text(owner['kind'], '$name.owner.kind');
    final id = owner['id'];
    if (kind == 'guest' && id == '') {
      return SpellingProfileScope(
        courseId: _text(value['courseId'], '$name.courseId'),
        owner: LearningOwner.guest(),
      );
    }
    if (kind == 'account' && id is String && id.trim().isNotEmpty) {
      return SpellingProfileScope(
        courseId: _text(value['courseId'], '$name.courseId'),
        owner: LearningOwner.account(id),
      );
    }
    throw FormatException('$name.owner is invalid.');
  }

  static SpellingRunMode _runMode(Object? raw) {
    final value = _text(raw, 'checkpoint.mode');
    return switch (value) {
      'practice' => SpellingRunMode.practice,
      'reviewOnly' => SpellingRunMode.reviewOnly,
      _ => throw const FormatException('Unknown spelling run mode.'),
    };
  }
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$name must be an object with string keys.');
  }
  return Map<String, Object?>.from(value);
}

void _exactKeys(
  Map<String, Object?> value,
  List<String> expected,
  String name,
) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key)) ||
      expected.any((key) => !value.containsKey(key)) ||
      !_sameOrder(value.keys.toList(), expected)) {
    throw FormatException('$name has missing, extra, or out-of-order fields.');
  }
}

String _text(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$name must be nonblank text.');
  }
  return value;
}

int _integer(Object? value, String name) {
  if (value is! int || value < 0 || value > spellingMaxSafeInteger) {
    throw FormatException('$name must be a safe nonnegative integer.');
  }
  return value;
}

int _positive(Object? value, String name) {
  final result = _integer(value, name);
  if (result == 0) throw FormatException('$name must be positive.');
  return result;
}

bool _boolean(Object? value, String name) {
  if (value is! bool) throw FormatException('$name must be a boolean.');
  return value;
}

List<String> _stringList(Object? value, String name) {
  if (value is! List) throw FormatException('$name must be an array.');
  final result = <String>[];
  for (final entry in value) {
    result.add(_text(entry, name));
  }
  return result;
}

Map<String, bool> _answerMap(
  Object? raw,
  String name,
  List<String> authoredIds, {
  required bool allowPrefix,
}) {
  final value = _object(raw, name);
  final ids = value.keys.toList();
  if (ids.any((id) => !authoredIds.contains(id)) ||
      !_sameOrder(ids, authoredIds.where(value.containsKey).toList()) ||
      (!allowPrefix && ids.length != authoredIds.length)) {
    throw FormatException('$name does not follow authored item order.');
  }
  return <String, bool>{
    for (final entry in value.entries)
      entry.key: _boolean(entry.value, '$name.${entry.key}'),
  };
}

LessonPolicy _readPolicy(Object? raw, String name) {
  final value = _object(raw, name);
  _exactKeys(value, const ['completionThresholdPercent'], name);
  return LessonPolicy.fromJson(Map<String, dynamic>.from(value));
}

bool _sameOrder(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _sameAnswers(Map<String, bool> left, Map<String, bool> right) =>
    left.length == right.length &&
    left.entries.every((entry) => right[entry.key] == entry.value);

List<String> _submittedThisRound(LessonSectionSession session) =>
    List<String>.from(session.toJson()['submittedThisRound'] as List);
