import 'dart:convert';

import '../lesson_policy.dart';
import '../lesson_section_session.dart';
import '../sentence_hunt_content.dart';
import '../sentence_hunt_learning_state.dart';
import 'learning_tables.dart' show learningMaxCheckpointBytes;

/// Encodes exactly one resumable sentence-hunt session, never profile history.
final class SentenceHuntCheckpointCodec {
  const SentenceHuntCheckpointCodec();

  static const List<String> _sessionKeys = <String>[
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

  String encode(SentenceHuntCheckpoint checkpoint) {
    final raw = _object(checkpoint.sessionJson, 'checkpoint session');
    _exactKeys(raw, _sessionKeys, 'checkpoint session', ordered: true);
    final itemIds = _strings(raw['itemIds'], 'itemIds', requireNonempty: true);
    final session = _readSession(
      raw,
      itemIds: itemIds,
      contentRevision: checkpoint.contentRevision,
      policy: checkpoint.policy,
    );
    if (session.sessionId != checkpoint.sessionId ||
        session.contentRevision != checkpoint.contentRevision ||
        session.policy.completionThresholdPercent !=
            checkpoint.policy.completionThresholdPercent ||
        checkpoint.runStartRound > session.round ||
        (checkpoint.finished && session.phase != LessonSectionPhase.debrief)) {
      throw const FormatException('Checkpoint metadata differs from session.');
    }
    final encoded = jsonEncode(session.toJson());
    if (utf8.encode(encoded).length > learningMaxCheckpointBytes) {
      throw ArgumentError.value(
        checkpoint,
        'checkpoint',
        'Checkpoint exceeds $learningMaxCheckpointBytes UTF-8 bytes.',
      );
    }
    if (jsonEncode(raw) != encoded) {
      throw const FormatException('Checkpoint session is not canonical.');
    }
    return encoded;
  }

  SentenceHuntCheckpoint decode(
    String json, {
    required SentenceHuntProfileScope scope,
    required String sectionId,
    required SentenceHuntCatalogue catalogue,
    required SentenceHuntRunMode mode,
    required bool finished,
    required LessonPolicy policy,
    required int runStartRound,
  }) {
    try {
      if (utf8.encode(json).length > learningMaxCheckpointBytes) {
        throw const FormatException('Checkpoint exceeds the byte limit.');
      }
      final section = catalogue.section(sectionId);
      if (!catalogue.isAvailable(sectionId) ||
          section.contentRevision < 1 ||
          policy.completionThresholdPercent !=
              section.policy.completionThresholdPercent ||
          runStartRound < 1 ||
          runStartRound > sentenceHuntMaxSafeInteger) {
        throw const FormatException('Checkpoint content identity mismatch.');
      }
      final raw = _object(jsonDecode(json), 'checkpoint session');
      _exactKeys(raw, _sessionKeys, 'checkpoint session', ordered: true);
      final itemIds = section.items
          .map((item) => item.identity.itemId)
          .toList(growable: false);
      final session = _readSession(
        raw,
        itemIds: itemIds,
        contentRevision: section.contentRevision,
        policy: policy,
      );
      if (runStartRound > session.round ||
          (finished && session.phase != LessonSectionPhase.debrief)) {
        throw const FormatException('Checkpoint run metadata is unreachable.');
      }
      final canonical = jsonEncode(session.toJson());
      if (canonical != json) {
        throw const FormatException('Checkpoint JSON is not canonical.');
      }
      return SentenceHuntCheckpoint(
        scope: scope,
        sessionId: session.sessionId,
        sectionFingerprint: section.sectionFingerprint,
        contentRevision: section.contentRevision,
        mode: mode,
        finished: finished,
        policy: policy,
        sessionJson: session.toJson().cast<String, Object?>(),
        runStartRound: runStartRound,
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid sentence-hunt checkpoint: $error');
    }
  }

  LessonSectionSession _readSession(
    Map<String, Object?> raw, {
    required List<String> itemIds,
    required int contentRevision,
    required LessonPolicy policy,
  }) {
    final savedPolicy = _object(raw['policy'], 'policy');
    _exactKeys(
      savedPolicy,
      const ['completionThresholdPercent'],
      'policy',
      ordered: true,
    );
    final parsedPolicy = LessonPolicy.fromJson(
      Map<String, dynamic>.from(savedPolicy),
    );
    if (parsedPolicy.completionThresholdPercent !=
        policy.completionThresholdPercent) {
      throw const FormatException('Checkpoint policy mismatch.');
    }
    for (final name in const [
      'version',
      'contentRevision',
      'position',
      'round',
      'attemptCount',
    ]) {
      _integer(raw[name], name);
    }
    for (final name in const ['itemIds', 'queue', 'submittedThisRound']) {
      _strings(raw[name], name);
    }
    _string(raw['sessionId'], 'sessionId');
    _string(raw['phase'], 'phase');
    if (raw['lastCorrect'] != null) _boolean(raw['lastCorrect'], 'lastCorrect');
    _boolean(raw['answered'], 'answered');
    final latestAnswers = _object(raw['latestAnswers'], 'latestAnswers');
    for (final entry in latestAnswers.entries) {
      _boolean(entry.value, 'latestAnswers.${entry.key}');
    }
    final session = LessonSectionSession.fromJson(
      Map<String, dynamic>.from(raw),
      itemIds: itemIds,
      contentRevision: contentRevision,
    );
    if (!_sameOrder(session.itemIds, itemIds)) {
      throw const FormatException('Checkpoint item order mismatch.');
    }
    return session;
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
  String name, {
  bool ordered = false,
}) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key)) ||
      expected.any((key) => !value.containsKey(key)) ||
      (ordered && !_sameOrder(value.keys.toList(), expected))) {
    throw FormatException(
      '$name has missing, unknown, or out-of-order fields.',
    );
  }
}

String _string(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$name must be nonblank text.');
  }
  return value;
}

int _integer(Object? value, String name) {
  if (value is! int || value < 0 || value > sentenceHuntMaxSafeInteger) {
    throw FormatException('$name must be a safe nonnegative integer.');
  }
  return value;
}

bool _boolean(Object? value, String name) {
  if (value is! bool) throw FormatException('$name must be a boolean.');
  return value;
}

List<String> _strings(
  Object? value,
  String name, {
  bool requireNonempty = false,
}) {
  if (value is! List) throw FormatException('$name must be a list.');
  final result = <String>[];
  final seen = <String>{};
  for (final entry in value) {
    final text = _string(entry, name);
    if (!seen.add(text)) throw FormatException('$name contains duplicates.');
    result.add(text);
  }
  if (requireNonempty && result.isEmpty) {
    throw FormatException('$name must not be empty.');
  }
  return result;
}

bool _sameOrder(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
