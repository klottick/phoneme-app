import 'dart:convert';

import '../comparison_content.dart';
import '../comparison_learning_state.dart';
import '../lesson_policy.dart';
import '../lesson_section_session.dart';
import 'learning_tables.dart' show learningMaxCheckpointBytes;

/// Bounded codec for exactly one resumable comparison session checkpoint.
///
/// No attempt, receipt, aggregate, or whole comparison-state document is
/// serialized here. The normalized run columns carry the remaining metadata.
final class ComparisonLearningCheckpointCodec {
  const ComparisonLearningCheckpointCodec();

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

  String encode(ComparisonCheckpoint checkpoint) {
    final raw = Map<String, Object?>.from(checkpoint.sessionJson);
    _exactKeys(raw, _sessionKeys, 'checkpoint session', ordered: true);
    final itemIds = _strings(raw['itemIds'], 'itemIds');
    final session = _readSession(
      raw,
      itemIds: itemIds,
      contentRevision: checkpoint.contentRevision,
      policy: checkpoint.policy,
    );
    if (session.sessionId != checkpoint.sessionId ||
        session.contentRevision != checkpoint.contentRevision ||
        session.policy.completionThresholdPercent !=
            checkpoint.policy.completionThresholdPercent) {
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

  ComparisonCheckpoint decode(
    String json, {
    required ComparisonProfileScope scope,
    required String activityId,
    required ComparisonCatalogue catalogue,
    required LessonPolicy policy,
  }) {
    try {
      if (utf8.encode(json).length > learningMaxCheckpointBytes) {
        throw const FormatException('Checkpoint exceeds the byte limit.');
      }
      if (activityId != catalogue.activityId ||
          catalogue.activityId != comparisonActivityId ||
          catalogue.contentRevision < 1) {
        throw const FormatException('Checkpoint content identity mismatch.');
      }
      final raw = _object(jsonDecode(json), 'checkpoint session');
      _exactKeys(raw, _sessionKeys, 'checkpoint session', ordered: true);
      final itemIds = catalogue.exercises
          .map((exercise) => exercise.id)
          .toList(growable: false);
      final session = _readSession(
        raw,
        itemIds: itemIds,
        contentRevision: catalogue.contentRevision,
        policy: policy,
      );
      final canonical = jsonEncode(session.toJson());
      if (canonical != json) {
        throw const FormatException('Checkpoint JSON is not canonical.');
      }
      return ComparisonCheckpoint(
        scope: scope,
        sessionId: session.sessionId,
        contentRevision: session.contentRevision,
        policy: session.policy,
        sessionJson: session.toJson(),
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid comparison checkpoint: $error');
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
    return LessonSectionSession.fromJson(
      Map<String, dynamic>.from(raw),
      itemIds: itemIds,
      contentRevision: contentRevision,
    );
  }
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$name must be an object with string keys.');
  }
  return value.cast<String, Object?>();
}

List<String> _strings(Object? value, String name) {
  if (value is! List) throw FormatException('$name must be a list.');
  final strings = <String>[];
  final seen = <String>{};
  for (final item in value) {
    if (item is! String || item.trim().isEmpty || !seen.add(item)) {
      throw FormatException('$name must contain unique nonblank strings.');
    }
    strings.add(item);
  }
  if (strings.isEmpty) throw FormatException('$name must not be empty.');
  return strings;
}

void _exactKeys(
  Map<String, Object?> value,
  List<String> expected,
  String name, {
  bool ordered = false,
}) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key)) ||
      (ordered && !_sameOrder(value.keys.toList(), expected))) {
    throw FormatException(
      '$name has missing, unknown, or out-of-order fields.',
    );
  }
}

bool _sameOrder(List<String> actual, List<String> expected) {
  if (actual.length != expected.length) return false;
  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) return false;
  }
  return true;
}
