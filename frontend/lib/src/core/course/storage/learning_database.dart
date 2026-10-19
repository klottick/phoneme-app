import 'dart:async';

import 'package:drift/drift.dart';

import '../course_learning_error.dart';
import 'learning_tables.dart';

part 'learning_database.g.dart';

typedef LearningMigrationRunner =
    Future<void> Function(Migrator migrator, int from, int to);

const List<String> _tableNames = <String>[
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

const Map<String, List<String>>
_expectedForeignKeySignatures = <String, List<String>>{
  'learning_scopes': <String>[],
  'learning_content_bindings': <String>[
    'learning_scopes|scope_id|id|NO ACTION|RESTRICT|NONE',
  ],
  'learning_runs': <String>[
    'learning_scopes|scope_id|id|NO ACTION|RESTRICT|NONE',
    'learning_content_bindings|content_binding_id|id|NO ACTION|RESTRICT|NONE',
  ],
  'learning_attempts': <String>[
    'learning_scopes|scope_id|id|NO ACTION|RESTRICT|NONE',
  ],
  'learning_attempt_values': <String>[
    'learning_scopes|scope_id|id|NO ACTION|RESTRICT|NONE',
    'learning_attempts|scope_id,attempt_id|scope_id,attempt_id|NO ACTION|RESTRICT|NONE',
  ],
  'learning_attempt_evidence': <String>[
    'learning_scopes|scope_id|id|NO ACTION|RESTRICT|NONE',
    'learning_attempts|scope_id,attempt_id|scope_id,attempt_id|NO ACTION|RESTRICT|NONE',
  ],
  'learning_command_receipts': <String>[
    'learning_scopes|scope_id|id|NO ACTION|RESTRICT|NONE',
  ],
  'learning_mistakes': <String>[
    'learning_scopes|scope_id|id|NO ACTION|RESTRICT|NONE',
  ],
  'learning_summaries': <String>[
    'learning_scopes|scope_id|id|NO ACTION|RESTRICT|NONE',
  ],
  'learning_completions': <String>[
    'learning_scopes|scope_id|id|NO ACTION|RESTRICT|NONE',
  ],
  'learning_exposure': <String>[
    'learning_scopes|scope_id|id|NO ACTION|RESTRICT|NONE',
  ],
  'learning_best_scores': <String>[
    'learning_scopes|scope_id|id|NO ACTION|RESTRICT|NONE',
  ],
  'supported_sync_outbox': <String>[
    'learning_scopes|scope_id|id|NO ACTION|RESTRICT|NONE',
  ],
};

const Map<String, List<String>> _columnNames = <String, List<String>>{
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

const Set<String> _integerColumns = <String>{
  'id',
  'scope_id',
  'schema_version',
  'revision',
  'commit_ordinal',
  'content_revision',
  'policy_revision',
  'annotation_revision',
  'run_generation',
  'sequence',
  'cursor_revision',
  'content_binding_id',
  'finished',
  'threshold_percent',
  'run_start_round',
  'latest_receipt_before_generation',
  'latest_receipt_before_sequence',
  'latest_receipt_before_cursor_revision',
  'latest_receipt_commit_ordinal',
  'command_sequence',
  'batch_index',
  'item_occurrence',
  'answered_at_us',
  'committed_at_us',
  'correct',
  'assistance_mask',
  'round',
  'after_debrief',
  'teaching_exposed',
  'ordinal',
  'int_value',
  'bool_value',
  'evidence_index',
  'ui_generation',
  'before_generation',
  'before_sequence',
  'before_cursor_revision',
  'after_generation',
  'after_sequence',
  'after_cursor_revision',
  'result_generation',
  'result_sequence',
  'result_cursor_revision',
  'first_wrong_at_us',
  'latest_wrong_at_us',
  'failure_count',
  'last_run_generation',
  'total',
  'presentations',
  'score',
  'enqueue_commit_ordinal',
  'enqueue_event_index',
};

const Map<String, Set<String>> _nullableColumns = <String, Set<String>>{
  'learning_scopes': <String>{},
  'learning_content_bindings': <String>{
    'policy_kind',
    'policy_revision',
    'catalogue_fingerprint',
    'section_fingerprint',
    'annotation_hash',
    'annotation_revision',
  },
  'learning_runs': <String>{
    'run_mode',
    'session_id',
    'policy_revision',
    'threshold_percent',
    'run_start_round',
  },
  'learning_attempts': <String>{
    'item_id',
    'item_occurrence',
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
  },
  'learning_attempt_values': <String>{'text_value', 'int_value', 'bool_value'},
  'learning_attempt_evidence': <String>{
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
  },
  'learning_command_receipts': <String>{},
  'learning_mistakes': <String>{
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
    'first_wrong_attempt_id',
    'latest_wrong_attempt_id',
    'last_run_generation',
  },
  'learning_summaries': <String>{
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
  },
  'learning_completions': <String>{},
  'learning_exposure': <String>{
    'activity_id',
    'item_id',
    'target_sound',
    'section_id',
    'content_revision',
    'presentations',
    'assistance_mask',
  },
  'learning_best_scores': <String>{},
  'supported_sync_outbox': <String>{
    'sound',
    'skill',
    'correct',
    'activity',
    'lesson_id',
    'game',
    'score',
  },
};

const List<String> _indexStatements = <String>[
  'CREATE UNIQUE INDEX ux_learning_scopes_owner_course_family ON learning_scopes(owner_kind, owner_id, course_id, family)',
  "CREATE UNIQUE INDEX ux_learning_content_bindings_identity ON learning_content_bindings(scope_id, activity_id, content_revision, COALESCE(policy_kind, ''), COALESCE(policy_revision, -1), COALESCE(catalogue_fingerprint, ''), COALESCE(section_fingerprint, ''), COALESCE(annotation_hash, ''), COALESCE(annotation_revision, -1))",
  'CREATE UNIQUE INDEX ux_learning_runs_scope_activity ON learning_runs(scope_id, activity_id)',
  'CREATE UNIQUE INDEX ux_learning_runs_scope_latest_receipt_token ON learning_runs(scope_id, latest_receipt_token)',
  'CREATE UNIQUE INDEX ux_learning_attempts_scope_attempt ON learning_attempts(scope_id, attempt_id)',
  'CREATE UNIQUE INDEX ux_learning_attempts_command_batch ON learning_attempts(scope_id, activity_id, run_generation, command_sequence, batch_index)',
  'CREATE UNIQUE INDEX ux_learning_attempt_values_attempt_field_ordinal ON learning_attempt_values(scope_id, attempt_id, field, ordinal)',
  'CREATE UNIQUE INDEX ux_learning_attempt_evidence_attempt_index ON learning_attempt_evidence(scope_id, attempt_id, evidence_index)',
  'CREATE UNIQUE INDEX ux_learning_command_receipts_scope_token ON learning_command_receipts(scope_id, token)',
  'CREATE UNIQUE INDEX ux_learning_command_receipts_activity_cursor ON learning_command_receipts(scope_id, activity_id, after_generation, after_sequence)',
  "CREATE UNIQUE INDEX ux_learning_mistakes_identity ON learning_mistakes(scope_id, family, COALESCE(activity_id, ''), COALESCE(item_id, ''), COALESCE(target_sound, ''), COALESCE(skill, ''), COALESCE(pair_id, ''), COALESCE(section_id, ''), COALESCE(sentence_id, ''), COALESCE(audio_ref_id, ''), COALESCE(annotation_hash, ''), COALESCE(annotation_revision, -1), content_revision)",
  "CREATE UNIQUE INDEX ux_learning_summaries_identity_bucket ON learning_summaries(scope_id, family, bucket, COALESCE(activity_id, ''), COALESCE(sound, ''), COALESCE(skill, ''), COALESCE(origin, ''), COALESCE(presentation, ''), COALESCE(assistance_mask, -1), COALESCE(pair_id, ''), COALESCE(section_id, ''), COALESCE(item_id, ''), COALESCE(sentence_id, ''), COALESCE(audio_ref_id, ''), COALESCE(annotation_hash, ''), COALESCE(annotation_revision, -1), COALESCE(content_revision, -1))",
  'CREATE UNIQUE INDEX ux_learning_completions_identity ON learning_completions(scope_id, activity_id, content_revision, policy_kind, policy_revision, threshold_percent)',
  "CREATE UNIQUE INDEX ux_learning_exposure_identity ON learning_exposure(scope_id, family, COALESCE(activity_id, ''), COALESCE(item_id, ''), COALESCE(target_sound, ''), COALESCE(section_id, ''), COALESCE(content_revision, -1))",
  'CREATE UNIQUE INDEX ux_learning_best_scores_scope_activity ON learning_best_scores(scope_id, activity_id)',
  'CREATE UNIQUE INDEX ux_supported_sync_outbox_scope_event ON supported_sync_outbox(scope_id, event_id)',
  'CREATE UNIQUE INDEX ux_supported_sync_outbox_scope_enqueue_order ON supported_sync_outbox(scope_id, enqueue_commit_ordinal, enqueue_event_index)',
  'CREATE INDEX ix_learning_attempts_scope_commit_batch ON learning_attempts(scope_id, commit_ordinal, activity_id, run_generation, command_sequence, batch_index)',
  'CREATE INDEX ix_learning_receipts_scope_commit_ordinal ON learning_command_receipts(scope_id, commit_ordinal, activity_id, after_generation, after_sequence)',
  'CREATE INDEX ix_learning_runs_scope_cursor ON learning_runs(scope_id, activity_id, run_generation, sequence, cursor_revision)',
];

const String _contentBindingFamilyCondition = '''
EXISTS (
  SELECT 1 FROM learning_scopes AS s
  WHERE s.id = NEW.scope_id AND (
    (s.family = 'course' AND NEW.section_fingerprint IS NULL AND
      NEW.annotation_hash IS NULL AND NEW.annotation_revision IS NULL) OR
    (s.family = 'comparison' AND NEW.catalogue_fingerprint IS NULL AND
      NEW.annotation_hash IS NULL AND NEW.annotation_revision IS NULL) OR
    (s.family = 'sentence-hunt' AND NEW.catalogue_fingerprint IS NULL AND
      NEW.section_fingerprint IS NOT NULL AND NEW.annotation_hash IS NULL AND
      NEW.annotation_revision IS NULL)
  )
)''';

const String _runFamilyCondition = '''
EXISTS (
  SELECT 1 FROM learning_scopes AS s
  JOIN learning_content_bindings AS b
    ON b.scope_id = s.id AND b.id = NEW.content_binding_id
  WHERE s.id = NEW.scope_id AND b.activity_id = NEW.activity_id AND (
    (s.family = 'course' AND NEW.activity_kind IN
      ('discovery', 'legacyLesson', 'drill', 'soundGame', 'wordGame') AND
      NEW.run_mode IS NULL AND NEW.run_start_round IS NULL) OR
    (s.family = 'comparison' AND NEW.activity_kind = 'comparison' AND
      NEW.run_mode IS NULL AND NEW.session_id IS NOT NULL AND
      NEW.policy_revision IS NOT NULL AND NEW.threshold_percent IS NOT NULL AND
      NEW.run_start_round IS NULL) OR
    (s.family = 'sentence-hunt' AND NEW.activity_kind = 'sentence-hunt' AND
      NEW.run_mode IN ('practice', 'reviewOnly') AND
      NEW.session_id IS NOT NULL AND NEW.policy_revision IS NOT NULL AND
      NEW.threshold_percent IS NOT NULL AND NEW.run_start_round IS NOT NULL)
  )
)''';

const String _attemptFamilyCondition = '''
EXISTS (
  SELECT 1 FROM learning_scopes AS s
  WHERE s.id = NEW.scope_id AND (
    (s.family = 'course' AND NEW.item_id IS NOT NULL AND
      NEW.item_occurrence IS NOT NULL AND NEW.answer_kind IN
        ('soundChoice', 'drillChoice', 'soundCue', 'wordTile') AND
      NEW.skill IS NOT NULL AND NEW.origin IS NOT NULL AND
      NEW.presentation IS NOT NULL AND NEW.assistance_mask IS NOT NULL AND
      NEW.content_state IS NOT NULL AND NEW.audio_source IS NOT NULL AND
      NEW.round IS NULL AND NEW.after_debrief IS NULL AND
      NEW.teaching_exposed IS NULL AND NEW.selected_relation IS NULL AND
      NEW.expected_relation IS NULL AND NEW.section_id IS NULL AND
      NEW.sentence_id IS NULL AND NEW.annotation_hash IS NULL AND
      NEW.annotation_revision IS NULL) OR
    (s.family = 'comparison' AND NEW.item_id IS NOT NULL AND
      NEW.item_occurrence IS NULL AND NEW.answer_kind = 'comparisonPair' AND
      NEW.skill IS NULL AND NEW.origin IS NULL AND
      NEW.presentation IS NOT NULL AND NEW.assistance_mask IS NULL AND
      NEW.content_state IS NULL AND NEW.audio_source IS NULL AND
      NEW.round IS NOT NULL AND NEW.after_debrief IS NOT NULL AND
      NEW.teaching_exposed IS NULL AND NEW.selected_relation IS NOT NULL AND
      NEW.expected_relation IS NOT NULL AND NEW.section_id IS NULL AND
      NEW.sentence_id IS NULL AND NEW.annotation_hash IS NULL AND
      NEW.annotation_revision IS NULL) OR
    (s.family = 'sentence-hunt' AND NEW.item_id IS NOT NULL AND
      NEW.item_occurrence IS NULL AND NEW.answer_kind = 'sentenceHunt' AND
      NEW.skill IS NULL AND NEW.origin IS NULL AND
      NEW.presentation IS NOT NULL AND NEW.assistance_mask IS NULL AND
      NEW.content_state IS NULL AND NEW.audio_source IS NULL AND
      NEW.round IS NOT NULL AND NEW.after_debrief IS NULL AND
      NEW.teaching_exposed IS NOT NULL AND NEW.selected_relation IS NULL AND
      NEW.expected_relation IS NULL AND NEW.section_id IS NOT NULL AND
      NEW.activity_id = NEW.section_id AND NEW.sentence_id IS NOT NULL AND
      NEW.annotation_hash IS NOT NULL AND NEW.annotation_revision IS NOT NULL)
  )
)''';

const String _attemptValueFamilyCondition = '''
EXISTS (
  SELECT 1 FROM learning_scopes AS s
  WHERE s.id = NEW.scope_id AND (
    (s.family = 'course' AND NEW.field IN
      ('selected_sound', 'expected_sound', 'choice', 'selected_word',
       'expected_word', 'pair_id', 'selected_family', 'expected_family',
       'word_id', 'tile_index', 'target_sound', 'expected_membership')) OR
    (s.family = 'sentence-hunt' AND NEW.field IN
      ('selected_token_id', 'expected_token_id'))
  )
)''';

const String _attemptEvidenceFamilyCondition = '''
EXISTS (
  SELECT 1 FROM learning_scopes AS s
  WHERE s.id = NEW.scope_id AND (
    (s.family = 'comparison' AND NEW.evidence_kind = 'comparisonPlayback' AND
      ((NEW.evidence_index = 0 AND NEW.slot = 'a') OR
       (NEW.evidence_index = 1 AND NEW.slot = 'b')) AND
      NEW.reference_id IS NOT NULL AND NEW.outcome = 'completed' AND
      NEW.source = 'unverifiedRecording' AND NEW.activity_id IS NOT NULL AND
      NEW.run_generation IS NOT NULL AND NEW.round IS NOT NULL AND
      NEW.pair_id IS NOT NULL AND NEW.ui_generation IS NOT NULL AND
      NEW.section_id IS NULL AND NEW.item_id IS NULL AND
      NEW.sentence_id IS NULL AND NEW.audio_ref_id IS NULL AND
      NEW.annotation_hash IS NULL AND NEW.annotation_revision IS NULL AND
      NEW.content_revision IS NULL) OR
    (s.family = 'sentence-hunt' AND
      NEW.evidence_kind = 'sentencePlayback' AND NEW.evidence_index = 0 AND
      NEW.slot IS NULL AND NEW.reference_id IS NOT NULL AND
      NEW.outcome IS NOT NULL AND NEW.source IS NOT NULL AND
      NEW.activity_id IS NOT NULL AND NEW.run_generation IS NOT NULL AND
      NEW.round IS NOT NULL AND NEW.pair_id IS NULL AND
      NEW.ui_generation IS NOT NULL AND NEW.section_id IS NOT NULL AND
      NEW.item_id IS NOT NULL AND NEW.sentence_id IS NOT NULL AND
      NEW.audio_ref_id IS NOT NULL AND NEW.annotation_hash IS NOT NULL AND
      NEW.annotation_revision IS NOT NULL AND NEW.content_revision IS NOT NULL) OR
    (s.family = 'sentence-hunt' AND
      NEW.evidence_kind = 'sentenceContent' AND NEW.evidence_index = 1 AND
      NEW.slot IS NULL AND NEW.reference_id IS NULL AND NEW.outcome IS NULL AND
      NEW.source IS NULL AND NEW.activity_id IS NULL AND
      NEW.run_generation IS NULL AND NEW.round IS NULL AND
      NEW.pair_id IS NULL AND NEW.ui_generation IS NULL AND
      NEW.section_id IS NOT NULL AND NEW.item_id IS NOT NULL AND
      NEW.sentence_id IS NOT NULL AND NEW.audio_ref_id IS NOT NULL AND
      NEW.annotation_hash IS NOT NULL AND NEW.annotation_revision IS NOT NULL AND
      NEW.content_revision IS NOT NULL)
  )
)''';

const String _mistakeFamilyCondition = '''
EXISTS (SELECT 1 FROM learning_scopes AS s
  WHERE s.id = NEW.scope_id AND s.family = NEW.family)''';

const String _summaryFamilyCondition = '''
EXISTS (SELECT 1 FROM learning_scopes AS s
  WHERE s.id = NEW.scope_id AND s.family = NEW.family)''';

const String _completionFamilyCondition = '''
EXISTS (
  SELECT 1 FROM learning_scopes AS s
  WHERE s.id = NEW.scope_id AND (
    (s.family = 'course' AND
      ((NEW.policy_kind = 'legacyOnePass' AND NEW.threshold_percent = -1) OR
       (NEW.policy_kind = 'discoveryThreshold' AND
        NEW.threshold_percent BETWEEN 1 AND 100))) OR
    (s.family IN ('comparison', 'sentence-hunt') AND
      NEW.policy_kind = 'discoveryThreshold' AND
      NEW.threshold_percent BETWEEN 1 AND 100)
  )
)''';

const String _exposureFamilyCondition = '''
EXISTS (SELECT 1 FROM learning_scopes AS s
  WHERE s.id = NEW.scope_id AND s.family = NEW.family AND
    s.family IN ('course', 'sentence-hunt'))''';

const String _outboxAccountCourseCondition = '''
EXISTS (
  SELECT 1 FROM learning_scopes AS s
  WHERE s.id = NEW.scope_id AND s.owner_kind = 'account' AND
    s.family = 'course' AND s.owner_id = NEW.user_id AND
    s.course_id = NEW.course_id
)''';

List<String> _pairedTriggers({
  required String name,
  required String table,
  required String condition,
}) => <String>[
  _triggerStatement(
    name: '${name}_insert',
    operation: 'INSERT',
    table: table,
    condition: condition,
  ),
  _triggerStatement(
    name: '${name}_update',
    operation: 'UPDATE',
    table: table,
    condition: condition,
  ),
];

String _triggerStatement({
  required String name,
  required String operation,
  required String table,
  required String condition,
}) =>
    '''CREATE TRIGGER $name BEFORE $operation ON $table
WHEN NOT ($condition)
BEGIN
  SELECT RAISE(ABORT, '$name rejected row');
END''';

final List<String> _triggerStatements = <String>[
  ..._pairedTriggers(
    name: 'trg_learning_content_bindings_scope_family',
    table: 'learning_content_bindings',
    condition: _contentBindingFamilyCondition,
  ),
  ..._pairedTriggers(
    name: 'trg_learning_runs_scope_binding_family',
    table: 'learning_runs',
    condition: _runFamilyCondition,
  ),
  ..._pairedTriggers(
    name: 'trg_learning_attempts_scope_family',
    table: 'learning_attempts',
    condition: _attemptFamilyCondition,
  ),
  ..._pairedTriggers(
    name: 'trg_learning_attempt_values_scope_family',
    table: 'learning_attempt_values',
    condition: _attemptValueFamilyCondition,
  ),
  ..._pairedTriggers(
    name: 'trg_learning_attempt_evidence_scope_family',
    table: 'learning_attempt_evidence',
    condition: _attemptEvidenceFamilyCondition,
  ),
  ..._pairedTriggers(
    name: 'trg_learning_mistakes_scope_family',
    table: 'learning_mistakes',
    condition: _mistakeFamilyCondition,
  ),
  ..._pairedTriggers(
    name: 'trg_learning_summaries_scope_family',
    table: 'learning_summaries',
    condition: _summaryFamilyCondition,
  ),
  ..._pairedTriggers(
    name: 'trg_learning_completions_scope_family',
    table: 'learning_completions',
    condition: _completionFamilyCondition,
  ),
  ..._pairedTriggers(
    name: 'trg_learning_exposure_scope_family',
    table: 'learning_exposure',
    condition: _exposureFamilyCondition,
  ),
  ..._pairedTriggers(
    name: 'trg_supported_sync_outbox_account_course',
    table: 'supported_sync_outbox',
    condition: _outboxAccountCourseCondition,
  ),
  '''CREATE TRIGGER trg_learning_scopes_identity_immutable_update
BEFORE UPDATE OF owner_kind, owner_id, course_id, family ON learning_scopes
WHEN OLD.owner_kind IS NOT NEW.owner_kind OR OLD.owner_id IS NOT NEW.owner_id OR
  OLD.course_id IS NOT NEW.course_id OR OLD.family IS NOT NEW.family
BEGIN
  SELECT RAISE(ABORT, 'learning scope identity is immutable');
END''',
];

@DriftDatabase(
  tables: <Type>[
    LearningScopes,
    LearningContentBindings,
    LearningRuns,
    LearningAttempts,
    LearningAttemptValues,
    LearningAttemptEvidence,
    LearningCommandReceipts,
    LearningMistakes,
    LearningSummaries,
    LearningCompletions,
    LearningExposure,
    LearningBestScores,
    SupportedSyncOutbox,
  ],
)
class LearningDatabase extends _$LearningDatabase {
  LearningDatabase(super.connection)
    : _targetSchemaVersion = 1,
      _migrationRunner = _rejectUnsupportedMigration;

  LearningDatabase.forTesting(
    super.connection, {
    required int targetSchemaVersion,
    required LearningMigrationRunner migrationRunner,
  }) : _targetSchemaVersion = targetSchemaVersion,
       _migrationRunner = migrationRunner {
    if (targetSchemaVersion < 1) {
      throw ArgumentError.value(targetSchemaVersion, 'targetSchemaVersion');
    }
  }

  final int _targetSchemaVersion;
  final LearningMigrationRunner _migrationRunner;

  @override
  int get schemaVersion => _targetSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: _createSchemaV1,
    onUpgrade: (Migrator migrator, int from, int to) =>
        transaction(() => _migrationRunner(migrator, from, to)),
    beforeOpen: _beforeOpen,
  );

  Future<void> _createSchemaV1(Migrator migrator) => transaction(() async {
    final version = (await customSelect(
      'PRAGMA user_version',
    ).getSingle()).read<int>('user_version');
    if (version != 0) {
      throw LearningUnsupportedVersionException(
        'Cannot create schema v1 over user_version=$version.',
      );
    }

    final existingObjects = await customSelect(
      "SELECT name FROM sqlite_schema WHERE name NOT LIKE 'sqlite_%' "
      "AND type IN ('table', 'index', 'trigger', 'view')",
    ).get();
    if (existingObjects.isNotEmpty) {
      throw const LearningUnsupportedVersionException(
        'Version-zero database is not empty.',
      );
    }

    await migrator.createAll();
    for (final statement in _indexStatements) {
      await customStatement(statement);
    }
    for (final statement in _triggerStatements) {
      await customStatement(statement);
    }
  });

  Future<void> _beforeOpen(OpeningDetails details) async {
    await customStatement('PRAGMA foreign_keys = ON');
    if (_targetSchemaVersion != 1) return;
    if (details.versionNow != 1 ||
        (!details.wasCreated && details.versionBefore != 1)) {
      throw LearningUnsupportedVersionException(
        'Unsupported learning database schema ${details.versionBefore} -> '
        '${details.versionNow}.',
      );
    }
    await _validateSchemaV1();
  }

  String _expectedCreateTableStatement(TableInfo<Table, Object?> table) {
    // Drift keeps Migrator._writeCreateTable private. Mirror its pinned
    // construction from TableInfo so validation covers the complete definition.
    final context = GenerationContext.fromDb(this);
    context.buffer.write(
      'CREATE TABLE IF NOT EXISTS '
      '${context.identifier(table.aliasedName)} (',
    );

    var hasAutoIncrement = false;
    for (var index = 0; index < table.$columns.length; index++) {
      final column = table.$columns[index];
      hasAutoIncrement |= column.hasAutoIncrement;
      column.writeColumnDefinition(context);
      if (index < table.$columns.length - 1) context.buffer.write(', ');
    }

    final dslTable = table.asDslTable;
    if (!dslTable.dontWriteConstraints) {
      if (table.$primaryKey.isNotEmpty && !hasAutoIncrement) {
        final primaryKey = table.$primaryKey.toList(growable: false);
        context.buffer.write(', PRIMARY KEY (');
        for (var index = 0; index < primaryKey.length; index++) {
          context.buffer.write(
            primaryKey[index].escapedNameFor(context.dialect),
          );
          if (index < primaryKey.length - 1) context.buffer.write(', ');
        }
        context.buffer.write(')');
      }

      for (final uniqueKey in table.uniqueKeys) {
        context.buffer.write(', UNIQUE (');
        final columns = uniqueKey.toList(growable: false);
        for (var index = 0; index < columns.length; index++) {
          context.buffer.write(columns[index].escapedNameFor(context.dialect));
          if (index < columns.length - 1) context.buffer.write(', ');
        }
        context.buffer.write(')');
      }
    }

    for (final constraint in dslTable.customConstraints) {
      context.buffer
        ..write(', ')
        ..write(constraint);
    }
    context.buffer.write(')');

    final options = <String>[
      if (dslTable.withoutRowId) 'WITHOUT ROWID',
      if (dslTable.isStrict) 'STRICT',
    ].join(', ');
    if (options.isNotEmpty) {
      context.buffer
        ..write(' ')
        ..write(options);
    }
    context.buffer.write(';');
    return context.sql;
  }

  Future<void> _validateSchemaV1() async {
    final tables = await _schemaNames('table');
    if (!_sameNames(tables, _tableNames)) {
      throw const LearningCorruptException('Learning schema v1 tables differ.');
    }

    final tableSql = await _schemaSqlByName('table');
    final tablesByName = <String, TableInfo<Table, Object?>>{
      for (final table in allTables) table.actualTableName: table,
    };
    for (final entry in _columnNames.entries) {
      final expectedTableSql = _expectedCreateTableStatement(
        tablesByName[entry.key]!,
      );
      final actualTableSql = tableSql[entry.key];
      if (actualTableSql == null ||
          _normalizeCreateTableSql(actualTableSql) !=
              _normalizeCreateTableSql(expectedTableSql)) {
        throw LearningCorruptException(
          'Learning schema v1 table definition differs in ${entry.key}.',
        );
      }

      final rows = await customSelect('PRAGMA table_info(${entry.key})').get();
      final columns = rows.map((row) => row.read<String>('name')).toList();
      if (!_sameNames(columns, entry.value)) {
        throw LearningCorruptException(
          'Learning schema v1 columns differ in ${entry.key}.',
        );
      }
      for (final row in rows) {
        final name = row.read<String>('name');
        final expectedType = _integerColumns.contains(name)
            ? 'INTEGER'
            : 'TEXT';
        final isPrimaryIntegerId = name == 'id';
        final isNullable = _nullableColumns[entry.key]!.contains(name);
        if (row.read<String>('type') != expectedType ||
            (!isPrimaryIntegerId &&
                row.read<int>('notnull') != (isNullable ? 0 : 1))) {
          throw LearningCorruptException(
            'Learning schema v1 column ${entry.key}.$name differs.',
          );
        }
        if (isPrimaryIntegerId && row.read<int>('pk') != 1) {
          throw LearningCorruptException(
            'Learning schema v1 primary key ${entry.key}.$name differs.',
          );
        }
      }

      final actualPrimaryKeyRows =
          rows.where((row) => row.read<int>('pk') > 0).toList()..sort(
            (left, right) =>
                left.read<int>('pk').compareTo(right.read<int>('pk')),
          );
      final actualPrimaryKey = actualPrimaryKeyRows
          .map((row) => row.read<String>('name'))
          .toList();
      final expectedPrimaryKey = tablesByName[entry.key]!.$primaryKey
          .map((column) => column.name)
          .toList();
      if (!_sameSequence(actualPrimaryKey, expectedPrimaryKey)) {
        throw LearningCorruptException(
          'Learning schema v1 primary key differs in ${entry.key}.',
        );
      }

      final expectedChecks = tablesByName[entry.key]!.customConstraints
          .where(_startsWithCheck)
          .map(_normalizeSql)
          .toList();
      final actualChecks = _splitTableDefinitions(
        tableSql[entry.key]!,
      ).where(_startsWithCheck).map(_normalizeSql).toList();
      if (!_sameNames(actualChecks, expectedChecks)) {
        throw LearningCorruptException(
          'Learning schema v1 CHECK constraints differ in ${entry.key}.',
        );
      }
    }

    final expectedIndexes = <String>[
      for (final statement in _indexStatements) _indexName(statement),
    ];
    if (!_sameNames(await _schemaNames('index'), expectedIndexes)) {
      throw const LearningCorruptException(
        'Learning schema v1 indexes differ.',
      );
    }
    final indexSql = await _schemaSqlByName('index');
    for (final statement in _indexStatements) {
      final definition = _parseIndexDefinition(statement);
      if (_normalizeSql(indexSql[definition.name] ?? '') !=
          _normalizeSql(statement)) {
        throw LearningCorruptException(
          'Learning schema v1 index ${definition.name} differs.',
        );
      }

      final indexList = await customSelect(
        'PRAGMA index_list(${definition.table})',
      ).get();
      final index = indexList.firstWhere(
        (row) => row.read<String>('name') == definition.name,
      );
      if (index.read<int>('unique') != (definition.unique ? 1 : 0) ||
          index.read<String>('origin') != 'c' ||
          index.read<int>('partial') != 0) {
        throw LearningCorruptException(
          'Learning schema v1 index metadata differs for ${definition.name}.',
        );
      }

      final indexColumns = await customSelect(
        'PRAGMA index_xinfo(${definition.name})',
      ).get();
      final keyColumns =
          indexColumns.where((row) => row.read<int>('key') == 1).toList()..sort(
            (left, right) =>
                left.read<int>('seqno').compareTo(right.read<int>('seqno')),
          );
      if (keyColumns.length != definition.terms.length) {
        throw LearningCorruptException(
          'Learning schema v1 index columns differ for ${definition.name}.',
        );
      }
      for (var index = 0; index < keyColumns.length; index++) {
        final actual = keyColumns[index];
        final expectedTerm = _withoutIndexDirection(definition.terms[index]);
        final expectedDescending = _isDescending(definition.terms[index]);
        final simpleColumn = RegExp(
          r'^[A-Za-z_][A-Za-z_0-9]*$',
        ).hasMatch(expectedTerm);
        final actualName = actual.data['name'] as String?;
        final actualCid = actual.read<int>('cid');
        if ((simpleColumn && (actualName != expectedTerm || actualCid < 0)) ||
            (!simpleColumn && actualCid != -2) ||
            actual.read<int>('desc') != (expectedDescending ? 1 : 0)) {
          throw LearningCorruptException(
            'Learning schema v1 index term differs for ${definition.name}.',
          );
        }
      }
    }

    final expectedTriggers = <String>[
      for (final statement in _triggerStatements) _triggerName(statement),
    ];
    if (!_sameNames(await _schemaNames('trigger'), expectedTriggers)) {
      throw const LearningCorruptException(
        'Learning schema v1 triggers differ.',
      );
    }
    final triggerSql = await _schemaSqlByName('trigger');
    for (final statement in _triggerStatements) {
      final name = _triggerName(statement);
      if (_normalizeSql(triggerSql[name] ?? '') != _normalizeSql(statement)) {
        throw LearningCorruptException(
          'Learning schema v1 trigger $name differs.',
        );
      }
    }

    for (final table in _tableNames) {
      final rows = await customSelect('PRAGMA foreign_key_list($table)').get();
      final groups = <int, List<QueryRow>>{};
      for (final row in rows) {
        groups.putIfAbsent(row.read<int>('id'), () => <QueryRow>[]).add(row);
      }
      final actualForeignKeys = <String>[];
      for (final group in groups.values) {
        group.sort(
          (left, right) =>
              left.read<int>('seq').compareTo(right.read<int>('seq')),
        );
        final first = group.first;
        actualForeignKeys.add(
          '${first.read<String>('table')}|'
          '${group.map((row) => row.read<String>('from')).join(',')}|'
          '${group.map((row) => row.read<String>('to')).join(',')}|'
          '${first.read<String>('on_update')}|'
          '${first.read<String>('on_delete')}|'
          '${first.read<String>('match')}',
        );
      }
      if (!_sameNames(
        actualForeignKeys,
        _expectedForeignKeySignatures[table]!,
      )) {
        throw LearningCorruptException(
          'Learning schema v1 foreign keys differ in $table.',
        );
      }
    }

    final foreignKeyViolations = await customSelect(
      'PRAGMA foreign_key_check',
    ).get();
    if (foreignKeyViolations.isNotEmpty) {
      throw const LearningCorruptException(
        'Learning schema v1 contains foreign-key violations.',
      );
    }
  }

  Future<List<String>> _schemaNames(String type) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_schema WHERE type = ? AND name NOT LIKE 'sqlite_%' "
      'ORDER BY name',
      variables: <Variable<Object>>[Variable<String>(type)],
    ).get();
    return rows.map((row) => row.read<String>('name')).toList();
  }

  Future<Map<String, String>> _schemaSqlByName(String type) async {
    final rows = await customSelect(
      'SELECT name, sql FROM sqlite_schema WHERE type = ? '
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      variables: <Variable<Object>>[Variable<String>(type)],
    ).get();
    return <String, String>{
      for (final row in rows) row.read<String>('name'): row.read<String>('sql'),
    };
  }

  bool _sameNames(List<String> actual, List<String> expected) {
    final sortedActual = actual.toList()..sort();
    final sortedExpected = expected.toList()..sort();
    if (sortedActual.length != sortedExpected.length) return false;
    for (var index = 0; index < sortedActual.length; index++) {
      if (sortedActual[index] != sortedExpected[index]) return false;
    }
    return true;
  }

  bool _sameSequence(List<String> actual, List<String> expected) {
    if (actual.length != expected.length) return false;
    for (var index = 0; index < actual.length; index++) {
      if (actual[index] != expected[index]) return false;
    }
    return true;
  }
}

bool _startsWithCheck(String constraint) =>
    RegExp(r'^CHECK\b', caseSensitive: false).hasMatch(constraint.trimLeft());

String _normalizeSql(String sql) {
  final normalized = StringBuffer();
  String? quote;
  var needsSpace = false;
  var previous = '';
  for (var index = 0; index < sql.length; index++) {
    final character = sql[index];
    if (quote != null) {
      normalized.write(character);
      if (character == quote) {
        if (index + 1 < sql.length && sql[index + 1] == quote) {
          normalized.write(sql[++index]);
        } else {
          quote = null;
        }
      }
      previous = character;
      continue;
    }
    if (character == "'" || character == '"' || character == '`') {
      if (needsSpace && _isWordCharacter(previous)) normalized.write(' ');
      needsSpace = false;
      quote = character;
      normalized.write(character);
      previous = character;
    } else if (character.trim().isEmpty) {
      needsSpace = true;
    } else {
      if (needsSpace &&
          _isWordCharacter(previous) &&
          _isWordCharacter(character)) {
        normalized.write(' ');
      }
      needsSpace = false;
      final lowered = character.toLowerCase();
      normalized.write(lowered);
      previous = lowered;
    }
  }
  var result = normalized.toString().trim();
  if (result.endsWith(';')) result = result.substring(0, result.length - 1);
  return result;
}

String _normalizeCreateTableSql(String sql) => _normalizeSql(
  sql.replaceFirst(
    RegExp(r'^CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\b', caseSensitive: false),
    'CREATE TABLE',
  ),
);

bool _isWordCharacter(String character) =>
    character.isNotEmpty && RegExp(r'[A-Za-z_0-9]').hasMatch(character);

List<String> _splitTableDefinitions(String sql) {
  final opening = sql.indexOf('(');
  if (opening < 0) return const <String>[];
  return _splitSqlList(sql, opening);
}

List<String> _splitSqlList(String sql, int opening) {
  final values = <String>[];
  var depth = 1;
  var start = opening + 1;
  String? quote;
  for (var index = opening + 1; index < sql.length; index++) {
    final character = sql[index];
    if (quote != null) {
      if (character == quote) {
        if (index + 1 < sql.length && sql[index + 1] == quote) {
          index++;
        } else {
          quote = null;
        }
      }
      continue;
    }
    if (character == "'" || character == '"' || character == '`') {
      quote = character;
    } else if (character == '(') {
      depth++;
    } else if (character == ')') {
      depth--;
      if (depth == 0) {
        values.add(sql.substring(start, index).trim());
        return values;
      }
    } else if (character == ',' && depth == 1) {
      values.add(sql.substring(start, index).trim());
      start = index + 1;
    }
  }
  return const <String>[];
}

String _indexName(String statement) => _parseIndexDefinition(statement).name;

({String name, String table, bool unique, List<String> terms})
_parseIndexDefinition(String statement) {
  final match = RegExp(
    r'^CREATE\s+(UNIQUE\s+)?INDEX\s+([^\s]+)\s+ON\s+([^\s(]+)\s*\(',
    caseSensitive: false,
  ).firstMatch(statement);
  if (match == null) {
    throw FormatException('Invalid learning index statement: $statement');
  }
  final terms = _splitSqlList(statement, match.end - 1);
  if (terms.isEmpty) {
    throw FormatException('Learning index has no terms: $statement');
  }
  return (
    name: match.group(2)!,
    table: match.group(3)!,
    unique: match.group(1) != null,
    terms: terms,
  );
}

String _triggerName(String statement) {
  final match = RegExp(
    r'^CREATE\s+TRIGGER\s+([^\s]+)',
    caseSensitive: false,
  ).firstMatch(statement);
  if (match == null) {
    throw FormatException('Invalid learning trigger statement: $statement');
  }
  return match.group(1)!;
}

String _withoutIndexDirection(String term) =>
    term.replaceFirst(RegExp(r'\s+(?:ASC|DESC)\s*$', caseSensitive: false), '');

bool _isDescending(String term) =>
    RegExp(r'\s+DESC\s*$', caseSensitive: false).hasMatch(term);

Future<void> _rejectUnsupportedMigration(
  Migrator migrator,
  int from,
  int to,
) async {
  throw LearningUnsupportedVersionException(
    'No production learning migration is available from $from to $to.',
  );
}

class LearningDatabaseHandle {
  LearningDatabaseHandle({required Future<LearningDatabase> Function() open})
    : _openConfigured = open;

  final Future<LearningDatabase> Function() _openConfigured;
  LearningDatabase? _database;
  Future<LearningDatabase>? _opening;
  Future<LearningDatabase>? _openingAfterClose;
  Future<void>? _closing;

  Future<LearningDatabase> open() {
    final closing = _closing;
    if (closing != null) return _openAfterClose(closing);

    final pending = _opening;
    if (pending != null) return pending;

    final current = _database;
    if (current != null) return Future<LearningDatabase>.value(current);

    final completer = Completer<LearningDatabase>();
    final shared = completer.future;
    _opening = shared;
    Future<LearningDatabase>.sync(() async {
      return _openConfigured();
    }).then(
      (LearningDatabase database) {
        if (identical(_opening, shared)) {
          _database = database;
          _opening = null;
        }
        completer.complete(database);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_opening, shared)) _opening = null;
        completer.completeError(error, stackTrace);
      },
    );
    return shared;
  }

  Future<LearningDatabase> _openAfterClose(Future<void> closing) {
    final pending = _openingAfterClose;
    if (pending != null) return pending;

    final completer = Completer<LearningDatabase>();
    final shared = completer.future;
    _openingAfterClose = shared;
    Future<void>.sync(() async {
      try {
        await closing;
        if (identical(_openingAfterClose, shared)) {
          _openingAfterClose = null;
        }
        completer.complete(await open());
      } on Object catch (error, stackTrace) {
        if (identical(_openingAfterClose, shared)) {
          _openingAfterClose = null;
        }
        completer.completeError(error, stackTrace);
      }
    });
    return shared;
  }

  Future<LearningDatabase> reopen() async {
    await close();
    return open();
  }

  Future<void> close() {
    final pendingClose = _closing;
    if (pendingClose != null) return pendingClose;

    final completer = Completer<void>();
    final shared = completer.future;
    _closing = shared;
    final Future<LearningDatabase>? opening = _opening;
    Future<void>.sync(() async {
      if (opening != null) {
        try {
          await opening;
        } on Object {
          // Opening errors have already reached open() callers; close is safe.
        }
      }
      final database = _database;
      _database = null;
      if (database != null) await database.close();
    }).then(
      (_) {
        if (identical(_closing, shared)) _closing = null;
        completer.complete();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_closing, shared)) _closing = null;
        completer.completeError(error, stackTrace);
      },
    );
    return shared;
  }
}
