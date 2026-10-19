import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart';

const List<String> learningTableNames = <String>[
  'learning_scopes',
  'learning_content_bindings',
  'learning_runs',
  'learning_attempts',
  'learning_attempt_values',
  'learning_attempt_evidence',
  'learning_command_receipts',
  'learning_mistakes',
  'learning_summaries',
  'learning_completions',
  'learning_exposure',
  'learning_best_scores',
  'supported_sync_outbox',
];

const Map<String, List<String>> learningColumnNames = <String, List<String>>{
  'learning_scopes': <String>[
    'id',
    'owner_kind',
    'owner_id',
    'course_id',
    'family',
    'schema_version',
    'revision',
    'commit_ordinal',
    'availability_state',
  ],
  'learning_content_bindings': <String>[
    'id',
    'scope_id',
    'activity_id',
    'content_revision',
    'policy_kind',
    'policy_revision',
    'catalogue_fingerprint',
    'section_fingerprint',
    'annotation_hash',
    'annotation_revision',
  ],
  'learning_runs': <String>[
    'scope_id',
    'activity_id',
    'activity_kind',
    'run_generation',
    'sequence',
    'cursor_revision',
    'content_binding_id',
    'run_mode',
    'finished',
    'session_id',
    'policy_revision',
    'threshold_percent',
    'run_start_round',
    'checkpoint_json',
    'latest_receipt_token',
    'latest_receipt_payload',
    'latest_receipt_before_generation',
    'latest_receipt_before_sequence',
    'latest_receipt_before_cursor_revision',
    'latest_receipt_commit_ordinal',
  ],
  'learning_attempts': <String>[
    'scope_id',
    'attempt_id',
    'activity_id',
    'run_generation',
    'command_sequence',
    'batch_index',
    'item_id',
    'item_occurrence',
    'content_revision',
    'commit_ordinal',
    'answered_at_us',
    'committed_at_us',
    'answer_kind',
    'correct',
    'skill',
    'origin',
    'presentation',
    'assistance_mask',
    'content_state',
    'audio_source',
    'round',
    'after_debrief',
    'teaching_exposed',
    'selected_relation',
    'expected_relation',
    'section_id',
    'sentence_id',
    'annotation_hash',
    'annotation_revision',
  ],
  'learning_attempt_values': <String>[
    'scope_id',
    'attempt_id',
    'field',
    'ordinal',
    'value_type',
    'text_value',
    'int_value',
    'bool_value',
  ],
  'learning_attempt_evidence': <String>[
    'scope_id',
    'attempt_id',
    'evidence_index',
    'evidence_kind',
    'slot',
    'reference_id',
    'outcome',
    'source',
    'activity_id',
    'run_generation',
    'round',
    'pair_id',
    'ui_generation',
    'section_id',
    'item_id',
    'sentence_id',
    'audio_ref_id',
    'annotation_hash',
    'annotation_revision',
    'content_revision',
  ],
  'learning_command_receipts': <String>[
    'scope_id',
    'activity_id',
    'token',
    'canonical_payload',
    'before_generation',
    'before_sequence',
    'before_cursor_revision',
    'after_generation',
    'after_sequence',
    'after_cursor_revision',
    'commit_ordinal',
    'result_activity_id',
    'result_generation',
    'result_sequence',
    'result_cursor_revision',
  ],
  'learning_mistakes': <String>[
    'scope_id',
    'family',
    'activity_id',
    'item_id',
    'target_sound',
    'skill',
    'pair_id',
    'section_id',
    'sentence_id',
    'audio_ref_id',
    'annotation_hash',
    'annotation_revision',
    'content_revision',
    'first_wrong_attempt_id',
    'latest_wrong_attempt_id',
    'first_wrong_at_us',
    'latest_wrong_at_us',
    'failure_count',
    'last_run_generation',
  ],
  'learning_summaries': <String>[
    'scope_id',
    'family',
    'activity_id',
    'sound',
    'skill',
    'origin',
    'presentation',
    'assistance_mask',
    'pair_id',
    'section_id',
    'item_id',
    'sentence_id',
    'audio_ref_id',
    'annotation_hash',
    'annotation_revision',
    'content_revision',
    'bucket',
    'correct',
    'total',
  ],
  'learning_completions': <String>[
    'scope_id',
    'activity_id',
    'content_revision',
    'policy_kind',
    'policy_revision',
    'threshold_percent',
    'committed_at_us',
  ],
  'learning_exposure': <String>[
    'scope_id',
    'family',
    'activity_id',
    'item_id',
    'target_sound',
    'section_id',
    'content_revision',
    'presentations',
    'assistance_mask',
  ],
  'learning_best_scores': <String>['scope_id', 'activity_id', 'score'],
  'supported_sync_outbox': <String>[
    'scope_id',
    'event_id',
    'enqueue_commit_ordinal',
    'enqueue_event_index',
    'user_id',
    'course_id',
    'kind',
    'sound',
    'skill',
    'correct',
    'activity',
    'lesson_id',
    'game',
    'score',
  ],
};

Future<LearningDatabase> openFileLearningTestDatabase(File file) async =>
    LearningDatabase(DatabaseConnection(NativeDatabase(file)));

/// Opens an independent file connection with WAL enabled for tests that need a
/// writer to commit while another connection holds a read snapshot.
Future<LearningDatabase> openWalFileLearningTestDatabase(File file) async =>
    LearningDatabase(
      DatabaseConnection(
        NativeDatabase(
          file,
          setup: (database) => database.execute('PRAGMA journal_mode = WAL'),
        ),
      ),
    );

Future<List<String>> tableNames(LearningDatabase database) async {
  final rows = await database
      .customSelect(
        "SELECT name FROM sqlite_schema WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY rowid",
      )
      .get();
  return rows.map((row) => row.read<String>('name')).toList();
}

Future<List<String>> columnNames(
  LearningDatabase database,
  String table,
) async {
  final rows = await database.customSelect('PRAGMA table_info($table)').get();
  return rows.map((row) => row.read<String>('name')).toList();
}

Future<int> pragmaUserVersion(LearningDatabase database) async =>
    (await database.customSelect('PRAGMA user_version').getSingle()).read<int>(
      'user_version',
    );

Future<List<String>> namedSchemaObjects(
  LearningDatabase database,
  String type,
) async {
  final rows = await database
      .customSelect(
        "SELECT name FROM sqlite_schema WHERE type = ? AND name NOT LIKE 'sqlite_%' "
        'ORDER BY name',
        variables: <Variable<Object>>[Variable<String>(type)],
      )
      .get();
  return rows.map((row) => row.read<String>('name')).toList();
}

Future<bool> hasNoLearningRows(LearningDatabase database) async {
  for (final table in learningTableNames) {
    final row = await database
        .customSelect('SELECT COUNT(*) AS row_count FROM $table')
        .getSingle();
    if (row.read<int>('row_count') != 0) return false;
  }
  return true;
}

Future<void> insertRow(
  LearningDatabase database,
  String table,
  Map<String, Object?> values,
) async {
  final columns = values.keys.join(', ');
  final placeholders = List<String>.filled(values.length, '?').join(', ');
  await database.customStatement(
    'INSERT INTO $table ($columns) VALUES ($placeholders)',
    values.values.toList(),
  );
}

Future<void> updateRows(
  LearningDatabase database,
  String table,
  Map<String, Object?> values, {
  required String where,
  required List<Object?> whereArgs,
}) async {
  final assignments = values.keys.map((column) => '$column = ?').join(', ');
  await database.customStatement(
    'UPDATE $table SET $assignments WHERE $where',
    <Object?>[...values.values, ...whereArgs],
  );
}

Future<void> expectSqlRejected(Future<void> action) async {
  await expectLater(action, throwsA(anything));
}

Future<void> insertScope(
  LearningDatabase database, {
  required int id,
  required String ownerKind,
  required String ownerId,
  required String courseId,
  required String family,
  int schemaVersion = 1,
  int revision = 0,
  int commitOrdinal = 0,
  String availabilityState = 'available',
}) => insertRow(database, 'learning_scopes', <String, Object?>{
  'id': id,
  'owner_kind': ownerKind,
  'owner_id': ownerId,
  'course_id': courseId,
  'family': family,
  'schema_version': schemaVersion,
  'revision': revision,
  'commit_ordinal': commitOrdinal,
  'availability_state': availabilityState,
});

Future<void> insertBinding(
  LearningDatabase database, {
  required int id,
  required int scopeId,
  required String activityId,
  int contentRevision = 1,
  String? policyKind,
  int? policyRevision,
  String? catalogueFingerprint,
  String? sectionFingerprint,
  String? annotationHash,
  int? annotationRevision,
}) => insertRow(database, 'learning_content_bindings', <String, Object?>{
  'id': id,
  'scope_id': scopeId,
  'activity_id': activityId,
  'content_revision': contentRevision,
  'policy_kind': policyKind,
  'policy_revision': policyRevision,
  'catalogue_fingerprint': catalogueFingerprint,
  'section_fingerprint': sectionFingerprint,
  'annotation_hash': annotationHash,
  'annotation_revision': annotationRevision,
});

Map<String, Object?> runRow({
  required int scopeId,
  required String activityId,
  required String activityKind,
  required int contentBindingId,
  required String token,
  int runGeneration = 1,
  int sequence = 1,
  int cursorRevision = 0,
  String? runMode,
  int finished = 0,
  String? sessionId,
  int? policyRevision,
  int? thresholdPercent,
  int? runStartRound,
  String checkpointJson = '{}',
  String? receiptPayload,
  int beforeGeneration = 0,
  int beforeSequence = 0,
  int beforeCursorRevision = 0,
  int receiptCommitOrdinal = 1,
}) => <String, Object?>{
  'scope_id': scopeId,
  'activity_id': activityId,
  'activity_kind': activityKind,
  'run_generation': runGeneration,
  'sequence': sequence,
  'cursor_revision': cursorRevision,
  'content_binding_id': contentBindingId,
  'run_mode': runMode,
  'finished': finished,
  'session_id': sessionId,
  'policy_revision': policyRevision,
  'threshold_percent': thresholdPercent,
  'run_start_round': runStartRound,
  'checkpoint_json': checkpointJson,
  'latest_receipt_token': token,
  'latest_receipt_payload':
      receiptPayload ??
      '{"activityId":"$activityId","expectedScopeRevision":0}',
  'latest_receipt_before_generation': beforeGeneration,
  'latest_receipt_before_sequence': beforeSequence,
  'latest_receipt_before_cursor_revision': beforeCursorRevision,
  'latest_receipt_commit_ordinal': receiptCommitOrdinal,
};

Map<String, Object?> courseAttemptRow({
  required int scopeId,
  String attemptId = 'attempt-course',
  String activityId = 'course-a',
  String itemId = 'item-a',
  int? itemOccurrence = 1,
  String answerKind = 'soundChoice',
  int correct = 1,
  String? skill = 'listening',
  String? origin = 'practice',
  String? presentation = 'firstInRun',
  int? assistanceMask = 0,
  String? contentState = 'reviewed',
  String? audioSource = 'pendingRecording',
  int batchIndex = 0,
}) => <String, Object?>{
  'scope_id': scopeId,
  'attempt_id': attemptId,
  'activity_id': activityId,
  'run_generation': 1,
  'command_sequence': 1,
  'batch_index': batchIndex,
  'item_id': itemId,
  'item_occurrence': itemOccurrence,
  'content_revision': 1,
  'commit_ordinal': 1,
  'answered_at_us': 100,
  'committed_at_us': 101,
  'answer_kind': answerKind,
  'correct': correct,
  'skill': skill,
  'origin': origin,
  'presentation': presentation,
  'assistance_mask': assistanceMask,
  'content_state': contentState,
  'audio_source': audioSource,
  'round': null,
  'after_debrief': null,
  'teaching_exposed': null,
  'selected_relation': null,
  'expected_relation': null,
  'section_id': null,
  'sentence_id': null,
  'annotation_hash': null,
  'annotation_revision': null,
};

Map<String, Object?> comparisonAttemptRow() => <String, Object?>{
  'scope_id': 2,
  'attempt_id': 'attempt-comparison',
  'activity_id': 'en-fr-phoneme-comparison',
  'run_generation': 1,
  'command_sequence': 1,
  'batch_index': 0,
  'item_id': 'pair-1',
  'item_occurrence': null,
  'content_revision': 1,
  'commit_ordinal': 1,
  'answered_at_us': 100,
  'committed_at_us': 101,
  'answer_kind': 'comparisonPair',
  'correct': 1,
  'skill': null,
  'origin': null,
  'presentation': 'firstInRun',
  'assistance_mask': null,
  'content_state': null,
  'audio_source': null,
  'round': 1,
  'after_debrief': 0,
  'teaching_exposed': null,
  'selected_relation': 'same',
  'expected_relation': 'same',
  'section_id': null,
  'sentence_id': null,
  'annotation_hash': null,
  'annotation_revision': null,
};

Map<String, Object?> sentenceAttemptRow() => <String, Object?>{
  'scope_id': 3,
  'attempt_id': 'attempt-sentence',
  'activity_id': 'section-1',
  'run_generation': 1,
  'command_sequence': 1,
  'batch_index': 0,
  'item_id': 'sentence-item',
  'item_occurrence': null,
  'content_revision': 1,
  'commit_ordinal': 1,
  'answered_at_us': 100,
  'committed_at_us': 101,
  'answer_kind': 'sentenceHunt',
  'correct': 1,
  'skill': null,
  'origin': null,
  'presentation': 'firstInRun',
  'assistance_mask': null,
  'content_state': null,
  'audio_source': null,
  'round': 1,
  'after_debrief': null,
  'teaching_exposed': 0,
  'selected_relation': null,
  'expected_relation': null,
  'section_id': 'section-1',
  'sentence_id': 'sentence-1',
  'annotation_hash': 'annotation-1',
  'annotation_revision': 1,
};

Map<String, Object?> comparisonEvidenceRow({
  required int evidenceIndex,
  required String slot,
}) => <String, Object?>{
  'scope_id': 2,
  'attempt_id': 'attempt-comparison',
  'evidence_index': evidenceIndex,
  'evidence_kind': 'comparisonPlayback',
  'slot': slot,
  'reference_id': 'reference-$slot',
  'outcome': 'completed',
  'source': 'unverifiedRecording',
  'activity_id': 'en-fr-phoneme-comparison',
  'run_generation': 1,
  'round': 1,
  'pair_id': 'pair-1',
  'ui_generation': 0,
  'section_id': null,
  'item_id': null,
  'sentence_id': null,
  'audio_ref_id': null,
  'annotation_hash': null,
  'annotation_revision': null,
  'content_revision': null,
};

Map<String, Object?> sentenceEvidenceRow({
  int scopeId = 3,
  String attemptId = 'attempt-sentence',
  int evidenceIndex = 0,
  String evidenceKind = 'sentencePlayback',
}) => <String, Object?>{
  'scope_id': scopeId,
  'attempt_id': attemptId,
  'evidence_index': evidenceIndex,
  'evidence_kind': evidenceKind,
  'slot': null,
  'reference_id': 'audio-reference-1',
  'outcome': 'completed',
  'source': 'unverifiedRecording',
  'activity_id': 'section-1',
  'run_generation': 1,
  'round': 1,
  'pair_id': null,
  'ui_generation': 0,
  'section_id': 'section-1',
  'item_id': 'sentence-item',
  'sentence_id': 'sentence-1',
  'audio_ref_id': 'audio-reference-1',
  'annotation_hash': 'annotation-1',
  'annotation_revision': 1,
  'content_revision': 1,
};

Future<void> createCoreLearningRows(LearningDatabase database) async {
  await insertScope(
    database,
    id: 1,
    ownerKind: 'account',
    ownerId: ' account-42 ',
    courseId: 'en-fr',
    family: 'course',
  );
  await insertScope(
    database,
    id: 2,
    ownerKind: 'guest',
    ownerId: '',
    courseId: 'en-fr',
    family: 'comparison',
  );
  await insertScope(
    database,
    id: 3,
    ownerKind: 'guest',
    ownerId: '',
    courseId: 'en-fr',
    family: 'sentence-hunt',
  );
  await insertScope(
    database,
    id: 4,
    ownerKind: 'guest',
    ownerId: '',
    courseId: 'en-fr-other',
    family: 'sentence-hunt',
  );
  await insertScope(
    database,
    id: 5,
    ownerKind: 'guest',
    ownerId: '',
    courseId: 'en-fr',
    family: 'course',
  );
  await insertScope(
    database,
    id: 6,
    ownerKind: 'account',
    ownerId: 'account-compare',
    courseId: 'en-fr',
    family: 'comparison',
  );
  await insertScope(
    database,
    id: 7,
    ownerKind: 'account',
    ownerId: 'account-other-course',
    courseId: 'es-fr',
    family: 'course',
  );

  await insertBinding(
    database,
    id: 101,
    scopeId: 1,
    activityId: 'course-a',
    catalogueFingerprint: 'catalogue-1',
  );
  await insertBinding(
    database,
    id: 102,
    scopeId: 2,
    activityId: 'en-fr-phoneme-comparison',
    policyKind: 'discoveryThreshold',
    policyRevision: 1,
    sectionFingerprint: 'comparison-section',
  );
  await insertBinding(
    database,
    id: 103,
    scopeId: 3,
    activityId: 'section-1',
    policyKind: 'discoveryThreshold',
    policyRevision: 1,
    sectionFingerprint: 'section-fingerprint-1',
  );
  await insertBinding(
    database,
    id: 104,
    scopeId: 4,
    activityId: 'section-other',
    policyKind: 'discoveryThreshold',
    policyRevision: 1,
    sectionFingerprint: 'section-fingerprint-other',
  );
  await insertBinding(
    database,
    id: 105,
    scopeId: 5,
    activityId: 'guest-course',
    catalogueFingerprint: 'catalogue-guest',
  );
  await insertBinding(
    database,
    id: 106,
    scopeId: 6,
    activityId: 'en-fr-phoneme-comparison',
    policyKind: 'discoveryThreshold',
    policyRevision: 1,
    sectionFingerprint: 'account-comparison-section',
  );
  await insertBinding(
    database,
    id: 107,
    scopeId: 7,
    activityId: 'other-course',
    catalogueFingerprint: 'catalogue-other-course',
  );
  await insertBinding(
    database,
    id: 108,
    scopeId: 1,
    activityId: 'course-b',
    catalogueFingerprint: 'catalogue-1',
  );

  await insertRow(
    database,
    'learning_runs',
    runRow(
      scopeId: 1,
      activityId: 'course-a',
      activityKind: 'discovery',
      contentBindingId: 101,
      token: 'AAAAAAAAAAAAAAAAAAAAAA',
    ),
  );
  await insertRow(
    database,
    'learning_runs',
    runRow(
      scopeId: 2,
      activityId: 'en-fr-phoneme-comparison',
      activityKind: 'comparison',
      contentBindingId: 102,
      token: 'BBBBBBBBBBBBBBBBBBBBBB',
      sessionId: 'comparison-session',
      policyRevision: 1,
      thresholdPercent: 80,
    ),
  );
  await insertRow(
    database,
    'learning_runs',
    runRow(
      scopeId: 3,
      activityId: 'section-1',
      activityKind: 'sentence-hunt',
      contentBindingId: 103,
      token: 'CCCCCCCCCCCCCCCCCCCCCC',
      runMode: 'practice',
      sessionId: 'sentence-session',
      policyRevision: 1,
      thresholdPercent: 80,
      runStartRound: 1,
    ),
  );

  await insertRow(database, 'learning_attempts', courseAttemptRow(scopeId: 1));
  await insertRow(database, 'learning_attempts', comparisonAttemptRow());
  await insertRow(database, 'learning_attempts', sentenceAttemptRow());
  await insertRow(database, 'learning_attempt_values', <String, Object?>{
    'scope_id': 1,
    'attempt_id': 'attempt-course',
    'field': 'selected_sound',
    'ordinal': 0,
    'value_type': 'text',
    'text_value': 'ɛ',
    'int_value': null,
    'bool_value': null,
  });
  await insertRow(database, 'learning_attempt_values', <String, Object?>{
    'scope_id': 3,
    'attempt_id': 'attempt-sentence',
    'field': 'selected_token_id',
    'ordinal': 0,
    'value_type': 'text',
    'text_value': 'token-a',
    'int_value': null,
    'bool_value': null,
  });
  await insertRow(database, 'learning_attempt_values', <String, Object?>{
    'scope_id': 3,
    'attempt_id': 'attempt-sentence',
    'field': 'expected_token_id',
    'ordinal': 0,
    'value_type': 'text',
    'text_value': 'token-a',
    'int_value': null,
    'bool_value': null,
  });
  await insertRow(
    database,
    'learning_attempt_evidence',
    comparisonEvidenceRow(evidenceIndex: 0, slot: 'a'),
  );
  await insertRow(
    database,
    'learning_attempt_evidence',
    comparisonEvidenceRow(evidenceIndex: 1, slot: 'b'),
  );
  await insertRow(database, 'learning_attempt_evidence', sentenceEvidenceRow());
}
