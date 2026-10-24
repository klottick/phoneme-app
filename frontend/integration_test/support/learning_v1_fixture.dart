import 'package:drift/drift.dart'
    show DatabaseConnection, OpeningDetails, QueryExecutor, QueryExecutorUser;
import 'package:linguist/src/core/course/storage/learning_database_v1_schema.dart'
    show publishedLearningV1SchemaStatements;

typedef LearningFixtureExecute =
    Future<void> Function(String sql, [List<Object?>? args]);

// These literal sqlite_schema statements were captured from published v1
// commit 9207b20139a92750e20dbb428f83de86f92e6fdd. They contain 13 tables,
// 20 indexes, and 21 triggers, and are independent of LearningDatabase and the
// generated v2 model.

const List<_FixtureStatement> _publishedV1SeedStatements = <_FixtureStatement>[
  _FixtureStatement(
    'INSERT INTO learning_scopes '
    '(id, owner_kind, owner_id, course_id, family, schema_version, '
    'revision, commit_ordinal, availability_state) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      1,
      'account',
      'account-42',
      'en-fr',
      'course',
      1,
      3,
      3,
      'available',
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_scopes '
    '(id, owner_kind, owner_id, course_id, family, schema_version, '
    'revision, commit_ordinal, availability_state) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[2, 'guest', '', 'en-fr', 'comparison', 1, 2, 2, 'available'],
  ),
  _FixtureStatement(
    'INSERT INTO learning_scopes '
    '(id, owner_kind, owner_id, course_id, family, schema_version, '
    'revision, commit_ordinal, availability_state) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      3,
      'account',
      'account-compare',
      'en-fr',
      'comparison',
      1,
      1,
      1,
      'available',
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_scopes '
    '(id, owner_kind, owner_id, course_id, family, schema_version, '
    'revision, commit_ordinal, availability_state) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[4, 'guest', '', 'en-fr', 'sentence-hunt', 1, 1, 1, 'available'],
  ),
  _FixtureStatement(
    'INSERT INTO learning_content_bindings '
    '(id, scope_id, activity_id, content_revision, policy_kind, '
    'policy_revision, catalogue_fingerprint, section_fingerprint, '
    'annotation_hash, annotation_revision) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      101,
      1,
      'course-a',
      1,
      null,
      null,
      'catalogue-course-a',
      null,
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_content_bindings '
    '(id, scope_id, activity_id, content_revision, policy_kind, '
    'policy_revision, catalogue_fingerprint, section_fingerprint, '
    'annotation_hash, annotation_revision) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      102,
      1,
      'course-b',
      1,
      null,
      null,
      'catalogue-course-b',
      null,
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_content_bindings '
    '(id, scope_id, activity_id, content_revision, policy_kind, '
    'policy_revision, catalogue_fingerprint, section_fingerprint, '
    'annotation_hash, annotation_revision) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      201,
      2,
      'en-fr-phoneme-comparison',
      1,
      'discoveryThreshold',
      1,
      null,
      'comparison-mixed-v1',
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_content_bindings '
    '(id, scope_id, activity_id, content_revision, policy_kind, '
    'policy_revision, catalogue_fingerprint, section_fingerprint, '
    'annotation_hash, annotation_revision) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      301,
      3,
      'en-fr-u-y-comparison',
      1,
      'discoveryThreshold',
      1,
      null,
      'comparison-dedicated-v1',
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_content_bindings '
    '(id, scope_id, activity_id, content_revision, policy_kind, '
    'policy_revision, catalogue_fingerprint, section_fingerprint, '
    'annotation_hash, annotation_revision) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      401,
      4,
      'section-1',
      1,
      'discoveryThreshold',
      1,
      null,
      'sentence-section-v1',
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_runs '
    '(scope_id, activity_id, activity_kind, run_generation, sequence, '
    'cursor_revision, content_binding_id, run_mode, finished, session_id, '
    'policy_revision, threshold_percent, run_start_round, checkpoint_json, '
    'latest_receipt_token, latest_receipt_payload, '
    'latest_receipt_before_generation, latest_receipt_before_sequence, '
    'latest_receipt_before_cursor_revision, latest_receipt_commit_ordinal) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      1,
      'course-a',
      'discovery',
      1,
      2,
      0,
      101,
      null,
      0,
      null,
      null,
      null,
      null,
      '{"kind":"discovery","session":{"sessionId":"course-session-v1"}}',
      'AAAAAAAAAAAAAAAAAAAAAA',
      '{"activityId":"course-a","expectedScopeRevision":2}',
      1,
      1,
      0,
      2,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_runs '
    '(scope_id, activity_id, activity_kind, run_generation, sequence, '
    'cursor_revision, content_binding_id, run_mode, finished, session_id, '
    'policy_revision, threshold_percent, run_start_round, checkpoint_json, '
    'latest_receipt_token, latest_receipt_payload, '
    'latest_receipt_before_generation, latest_receipt_before_sequence, '
    'latest_receipt_before_cursor_revision, latest_receipt_commit_ordinal) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      2,
      'en-fr-phoneme-comparison',
      'comparison',
      1,
      2,
      0,
      201,
      null,
      0,
      'mixed-comparison-session-v1',
      1,
      80,
      null,
      '{"kind":"comparison","sessionId":"mixed-comparison-session-v1"}',
      'BBBBBBBBBBBBBBBBBBBBBB',
      '{"activityId":"en-fr-phoneme-comparison","expectedScopeRevision":1}',
      1,
      1,
      0,
      2,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_runs '
    '(scope_id, activity_id, activity_kind, run_generation, sequence, '
    'cursor_revision, content_binding_id, run_mode, finished, session_id, '
    'policy_revision, threshold_percent, run_start_round, checkpoint_json, '
    'latest_receipt_token, latest_receipt_payload, '
    'latest_receipt_before_generation, latest_receipt_before_sequence, '
    'latest_receipt_before_cursor_revision, latest_receipt_commit_ordinal) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      3,
      'en-fr-u-y-comparison',
      'comparison',
      1,
      2,
      0,
      301,
      null,
      0,
      'dedicated-comparison-session-v1',
      1,
      80,
      null,
      '{"kind":"comparison","sessionId":"dedicated-comparison-session-v1"}',
      'CCCCCCCCCCCCCCCCCCCCCC',
      '{"activityId":"en-fr-u-y-comparison","expectedScopeRevision":0}',
      1,
      1,
      0,
      2,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_runs '
    '(scope_id, activity_id, activity_kind, run_generation, sequence, '
    'cursor_revision, content_binding_id, run_mode, finished, session_id, '
    'policy_revision, threshold_percent, run_start_round, checkpoint_json, '
    'latest_receipt_token, latest_receipt_payload, '
    'latest_receipt_before_generation, latest_receipt_before_sequence, '
    'latest_receipt_before_cursor_revision, latest_receipt_commit_ordinal) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      4,
      'section-1',
      'sentence-hunt',
      1,
      2,
      0,
      401,
      'practice',
      0,
      'sentence-session-v1',
      1,
      80,
      1,
      '{"kind":"sentence-hunt","sessionId":"sentence-session-v1"}',
      'DDDDDDDDDDDDDDDDDDDDDD',
      '{"activityId":"section-1","expectedScopeRevision":0}',
      1,
      1,
      0,
      2,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempts '
    '(scope_id, attempt_id, activity_id, run_generation, command_sequence, '
    'batch_index, item_id, item_occurrence, content_revision, commit_ordinal, '
    'answered_at_us, committed_at_us, answer_kind, correct, skill, origin, '
    'presentation, assistance_mask, content_state, audio_source, round, '
    'after_debrief, teaching_exposed, selected_relation, expected_relation, '
    'section_id, sentence_id, annotation_hash, annotation_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      1,
      'attempt-course-v1',
      'course-a',
      1,
      2,
      0,
      'course-item-v1',
      1,
      1,
      2,
      100,
      101,
      'soundChoice',
      0,
      'listening',
      'practice',
      'firstInRun',
      0,
      'reviewed',
      'pendingRecording',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempts '
    '(scope_id, attempt_id, activity_id, run_generation, command_sequence, '
    'batch_index, item_id, item_occurrence, content_revision, commit_ordinal, '
    'answered_at_us, committed_at_us, answer_kind, correct, skill, origin, '
    'presentation, assistance_mask, content_state, audio_source, round, '
    'after_debrief, teaching_exposed, selected_relation, expected_relation, '
    'section_id, sentence_id, annotation_hash, annotation_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      2,
      'attempt-comparison-v1',
      'en-fr-phoneme-comparison',
      1,
      2,
      0,
      'pair-v1',
      null,
      1,
      2,
      200,
      201,
      'comparisonPair',
      1,
      null,
      null,
      'firstInRun',
      null,
      null,
      null,
      1,
      0,
      null,
      'same',
      'same',
      null,
      null,
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempts '
    '(scope_id, attempt_id, activity_id, run_generation, command_sequence, '
    'batch_index, item_id, item_occurrence, content_revision, commit_ordinal, '
    'answered_at_us, committed_at_us, answer_kind, correct, skill, origin, '
    'presentation, assistance_mask, content_state, audio_source, round, '
    'after_debrief, teaching_exposed, selected_relation, expected_relation, '
    'section_id, sentence_id, annotation_hash, annotation_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      3,
      'attempt-comparison-dedicated-v1',
      'en-fr-u-y-comparison',
      1,
      2,
      0,
      'pair-dedicated-v1',
      null,
      1,
      2,
      300,
      301,
      'comparisonPair',
      1,
      null,
      null,
      'firstInRun',
      null,
      null,
      null,
      1,
      0,
      null,
      'different',
      'different',
      null,
      null,
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempts '
    '(scope_id, attempt_id, activity_id, run_generation, command_sequence, '
    'batch_index, item_id, item_occurrence, content_revision, commit_ordinal, '
    'answered_at_us, committed_at_us, answer_kind, correct, skill, origin, '
    'presentation, assistance_mask, content_state, audio_source, round, '
    'after_debrief, teaching_exposed, selected_relation, expected_relation, '
    'section_id, sentence_id, annotation_hash, annotation_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      4,
      'attempt-sentence-v1',
      'section-1',
      1,
      2,
      0,
      'sentence-item-v1',
      null,
      1,
      2,
      400,
      401,
      'sentenceHunt',
      1,
      null,
      null,
      'firstInRun',
      null,
      null,
      null,
      1,
      null,
      0,
      null,
      null,
      'section-1',
      'sentence-v1',
      'annotation-v1',
      1,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempt_values '
    '(scope_id, attempt_id, field, ordinal, value_type, text_value, int_value, bool_value) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      1,
      'attempt-course-v1',
      'selected_sound',
      0,
      'text',
      'ɛ',
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempt_values '
    '(scope_id, attempt_id, field, ordinal, value_type, text_value, int_value, bool_value) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      1,
      'attempt-course-v1',
      'expected_sound',
      0,
      'text',
      'e',
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempt_values '
    '(scope_id, attempt_id, field, ordinal, value_type, text_value, int_value, bool_value) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      4,
      'attempt-sentence-v1',
      'selected_token_id',
      0,
      'text',
      'sentence-token-v1',
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempt_values '
    '(scope_id, attempt_id, field, ordinal, value_type, text_value, int_value, bool_value) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      4,
      'attempt-sentence-v1',
      'expected_token_id',
      0,
      'text',
      'sentence-token-v1',
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempt_evidence '
    '(scope_id, attempt_id, evidence_index, evidence_kind, slot, reference_id, '
    'outcome, source, activity_id, run_generation, round, pair_id, ui_generation, '
    'section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
    'annotation_revision, content_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      2,
      'attempt-comparison-v1',
      0,
      'comparisonPlayback',
      'a',
      'reference-a-v1',
      'completed',
      'unverifiedRecording',
      'en-fr-phoneme-comparison',
      1,
      1,
      'pair-v1',
      0,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempt_evidence '
    '(scope_id, attempt_id, evidence_index, evidence_kind, slot, reference_id, '
    'outcome, source, activity_id, run_generation, round, pair_id, ui_generation, '
    'section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
    'annotation_revision, content_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      2,
      'attempt-comparison-v1',
      1,
      'comparisonPlayback',
      'b',
      'reference-b-v1',
      'completed',
      'unverifiedRecording',
      'en-fr-phoneme-comparison',
      1,
      1,
      'pair-v1',
      0,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempt_evidence '
    '(scope_id, attempt_id, evidence_index, evidence_kind, slot, reference_id, '
    'outcome, source, activity_id, run_generation, round, pair_id, ui_generation, '
    'section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
    'annotation_revision, content_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      3,
      'attempt-comparison-dedicated-v1',
      0,
      'comparisonPlayback',
      'a',
      'dedicated-reference-a-v1',
      'completed',
      'unverifiedRecording',
      'en-fr-u-y-comparison',
      1,
      1,
      'pair-dedicated-v1',
      0,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempt_evidence '
    '(scope_id, attempt_id, evidence_index, evidence_kind, slot, reference_id, '
    'outcome, source, activity_id, run_generation, round, pair_id, ui_generation, '
    'section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
    'annotation_revision, content_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      3,
      'attempt-comparison-dedicated-v1',
      1,
      'comparisonPlayback',
      'b',
      'dedicated-reference-b-v1',
      'completed',
      'unverifiedRecording',
      'en-fr-u-y-comparison',
      1,
      1,
      'pair-dedicated-v1',
      0,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempt_evidence '
    '(scope_id, attempt_id, evidence_index, evidence_kind, slot, reference_id, '
    'outcome, source, activity_id, run_generation, round, pair_id, ui_generation, '
    'section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
    'annotation_revision, content_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      4,
      'attempt-sentence-v1',
      0,
      'sentencePlayback',
      null,
      'sentence-audio-v1',
      'completed',
      'unverifiedRecording',
      'section-1',
      1,
      1,
      null,
      0,
      'section-1',
      'sentence-item-v1',
      'sentence-v1',
      'sentence-audio-v1',
      'annotation-v1',
      1,
      1,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_attempt_evidence '
    '(scope_id, attempt_id, evidence_index, evidence_kind, slot, reference_id, '
    'outcome, source, activity_id, run_generation, round, pair_id, ui_generation, '
    'section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
    'annotation_revision, content_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      4,
      'attempt-sentence-v1',
      1,
      'sentenceContent',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      'section-1',
      'sentence-item-v1',
      'sentence-v1',
      'sentence-audio-v1',
      'annotation-v1',
      1,
      1,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_command_receipts '
    '(scope_id, activity_id, token, canonical_payload, before_generation, '
    'before_sequence, before_cursor_revision, after_generation, after_sequence, '
    'after_cursor_revision, commit_ordinal, result_activity_id, result_generation, '
    'result_sequence, result_cursor_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      1,
      'course-a',
      'AAAAAAAAAAAAAAAAAAAAAA',
      '{"schemaVersion":1,"activityId":"course-a","expectedScopeRevision":2,"action":{"kind":"answer","itemId":"course-item-v1","selectedSound":"ɛ"}}',
      1,
      1,
      0,
      1,
      2,
      0,
      2,
      'course-a',
      1,
      2,
      0,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_command_receipts '
    '(scope_id, activity_id, token, canonical_payload, before_generation, '
    'before_sequence, before_cursor_revision, after_generation, after_sequence, '
    'after_cursor_revision, commit_ordinal, result_activity_id, result_generation, '
    'result_sequence, result_cursor_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      2,
      'en-fr-phoneme-comparison',
      'BBBBBBBBBBBBBBBBBBBBBB',
      '{"schemaVersion":1,"activityId":"en-fr-phoneme-comparison","expectedScopeRevision":1,"action":{"kind":"answer","pairId":"pair-v1","selectedRelation":"same"}}',
      1,
      1,
      0,
      1,
      2,
      0,
      2,
      'en-fr-phoneme-comparison',
      1,
      2,
      0,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_command_receipts '
    '(scope_id, activity_id, token, canonical_payload, before_generation, '
    'before_sequence, before_cursor_revision, after_generation, after_sequence, '
    'after_cursor_revision, commit_ordinal, result_activity_id, result_generation, '
    'result_sequence, result_cursor_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      3,
      'en-fr-u-y-comparison',
      'CCCCCCCCCCCCCCCCCCCCCC',
      '{"schemaVersion":1,"activityId":"en-fr-u-y-comparison","expectedScopeRevision":0,"action":{"kind":"answer","pairId":"pair-dedicated-v1","selectedRelation":"different"}}',
      1,
      1,
      0,
      1,
      2,
      0,
      2,
      'en-fr-u-y-comparison',
      1,
      2,
      0,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_command_receipts '
    '(scope_id, activity_id, token, canonical_payload, before_generation, '
    'before_sequence, before_cursor_revision, after_generation, after_sequence, '
    'after_cursor_revision, commit_ordinal, result_activity_id, result_generation, '
    'result_sequence, result_cursor_revision) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      4,
      'section-1',
      'DDDDDDDDDDDDDDDDDDDDDD',
      '{"schemaVersion":1,"activityId":"section-1","expectedScopeRevision":0,"action":{"kind":"answer","itemId":"sentence-item-v1","tokenId":"sentence-token-v1"}}',
      1,
      1,
      0,
      1,
      2,
      0,
      2,
      'section-1',
      1,
      2,
      0,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_mistakes '
    '(scope_id, family, activity_id, item_id, target_sound, skill, pair_id, '
    'section_id, sentence_id, audio_ref_id, annotation_hash, annotation_revision, '
    'content_revision, first_wrong_attempt_id, latest_wrong_attempt_id, '
    'first_wrong_at_us, latest_wrong_at_us, failure_count, last_run_generation) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      1,
      'course',
      'course-a',
      'course-item-v1',
      'ɛ',
      'listening',
      null,
      null,
      null,
      null,
      null,
      null,
      1,
      'attempt-course-v1',
      'attempt-course-v1',
      100,
      101,
      1,
      1,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_mistakes '
    '(scope_id, family, activity_id, item_id, target_sound, skill, pair_id, '
    'section_id, sentence_id, audio_ref_id, annotation_hash, annotation_revision, '
    'content_revision, first_wrong_attempt_id, latest_wrong_attempt_id, '
    'first_wrong_at_us, latest_wrong_at_us, failure_count, last_run_generation) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      2,
      'comparison',
      'en-fr-phoneme-comparison',
      null,
      null,
      null,
      'pair-v1',
      null,
      null,
      null,
      null,
      null,
      1,
      'attempt-comparison-v1',
      'attempt-comparison-v1',
      200,
      201,
      1,
      1,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_mistakes '
    '(scope_id, family, activity_id, item_id, target_sound, skill, pair_id, '
    'section_id, sentence_id, audio_ref_id, annotation_hash, annotation_revision, '
    'content_revision, first_wrong_attempt_id, latest_wrong_attempt_id, '
    'first_wrong_at_us, latest_wrong_at_us, failure_count, last_run_generation) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      4,
      'sentence-hunt',
      null,
      'sentence-item-v1',
      null,
      null,
      null,
      'section-1',
      'sentence-v1',
      'sentence-audio-v1',
      'annotation-v1',
      1,
      1,
      'attempt-sentence-v1',
      'attempt-sentence-v1',
      400,
      401,
      1,
      1,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_summaries '
    '(scope_id, family, activity_id, sound, skill, origin, presentation, '
    'assistance_mask, pair_id, section_id, item_id, sentence_id, audio_ref_id, '
    'annotation_hash, annotation_revision, content_revision, bucket, correct, total) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      1,
      'course',
      null,
      'ɛ',
      'listening',
      'practice',
      'firstInRun',
      0,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      'all',
      0,
      1,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_summaries '
    '(scope_id, family, activity_id, sound, skill, origin, presentation, '
    'assistance_mask, pair_id, section_id, item_id, sentence_id, audio_ref_id, '
    'annotation_hash, annotation_revision, content_revision, bucket, correct, total) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      2,
      'comparison',
      'en-fr-phoneme-comparison',
      null,
      null,
      null,
      null,
      null,
      'pair-v1',
      null,
      null,
      null,
      null,
      null,
      null,
      1,
      'firstInRun',
      1,
      1,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_summaries '
    '(scope_id, family, activity_id, sound, skill, origin, presentation, '
    'assistance_mask, pair_id, section_id, item_id, sentence_id, audio_ref_id, '
    'annotation_hash, annotation_revision, content_revision, bucket, correct, total) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      4,
      'sentence-hunt',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      'section-1',
      'sentence-item-v1',
      'sentence-v1',
      'sentence-audio-v1',
      'annotation-v1',
      1,
      1,
      'firstTeachingExposed',
      1,
      1,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_completions '
    '(scope_id, activity_id, content_revision, policy_kind, policy_revision, '
    'threshold_percent, committed_at_us) VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[1, 'course-a', 1, 'discoveryThreshold', 1, 80, 1000],
  ),
  _FixtureStatement(
    'INSERT INTO learning_completions '
    '(scope_id, activity_id, content_revision, policy_kind, policy_revision, '
    'threshold_percent, committed_at_us) VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      2,
      'en-fr-phoneme-comparison',
      1,
      'discoveryThreshold',
      1,
      80,
      2000,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO learning_completions '
    '(scope_id, activity_id, content_revision, policy_kind, policy_revision, '
    'threshold_percent, committed_at_us) VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[4, 'section-1', 1, 'discoveryThreshold', 1, 80, 4000],
  ),
  _FixtureStatement(
    'INSERT INTO learning_exposure '
    '(scope_id, family, activity_id, item_id, target_sound, section_id, '
    'content_revision, presentations, assistance_mask) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[1, 'course', 'course-a', 'course-item-v1', 'ɛ', null, null, 2, 1],
  ),
  _FixtureStatement(
    'INSERT INTO learning_exposure '
    '(scope_id, family, activity_id, item_id, target_sound, section_id, '
    'content_revision, presentations, assistance_mask) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[4, 'sentence-hunt', null, null, null, 'section-1', 1, null, null],
  ),
  _FixtureStatement(
    'INSERT INTO learning_best_scores (scope_id, activity_id, score) '
    'VALUES (?, ?, ?)',
    <Object?>[1, 'discovery', 7],
  ),
  _FixtureStatement(
    'INSERT INTO supported_sync_outbox '
    '(scope_id, event_id, enqueue_commit_ordinal, enqueue_event_index, '
    'user_id, course_id, kind, sound, skill, correct, activity, lesson_id, game, score) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      1,
      'outbox-v1-answer',
      1,
      0,
      'account-42',
      'en-fr',
      'answer',
      'ɛ',
      'listening',
      1,
      'discovery',
      null,
      null,
      null,
    ],
  ),
  _FixtureStatement(
    'INSERT INTO supported_sync_outbox '
    '(scope_id, event_id, enqueue_commit_ordinal, enqueue_event_index, '
    'user_id, course_id, kind, sound, skill, correct, activity, lesson_id, game, score) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      1,
      'outbox-v1-score',
      2,
      0,
      'account-42',
      'en-fr',
      'score',
      null,
      null,
      null,
      null,
      null,
      'sound-match',
      7,
    ],
  ),
];

/// Seeds the published v1 schema and representative synthetic legacy rows.
/// The call order and canonical JSON bytes are frozen fixture data.
Future<void> createPublishedLearningV1Fixture(
  LearningFixtureExecute execute,
) async {
  if (publishedLearningV1SchemaStatements.length != 54) {
    throw StateError('Frozen v1 schema object count changed.');
  }
  for (final statement in publishedLearningV1SchemaStatements) {
    await execute(statement);
  }

  await execute('PRAGMA foreign_keys = ON');
  for (final statement in _publishedV1SeedStatements) {
    await execute(statement.sql, statement.args);
  }
  await execute('PRAGMA user_version = 1');
}

/// Opens a fresh executor without invoking LearningDatabase schema creation,
/// verifies its empty v0 state, and installs the literal published-v1 fixture.
Future<void> openPublishedLearningV1Fixture(
  DatabaseConnection connection,
) async {
  await connection.executor.ensureOpen(_PublishedV1FixtureQueryExecutorUser());
  final versionRows = await connection.runSelect(
    'PRAGMA user_version',
    const [],
  );
  final schemaRows = await connection.runSelect(
    "SELECT name FROM sqlite_schema WHERE name NOT GLOB 'sqlite_*' "
    "AND type IN ('table', 'index', 'trigger', 'view')",
    const [],
  );
  if (versionRows.length != 1 ||
      versionRows.single['user_version'] != 0 ||
      schemaRows.isNotEmpty) {
    throw StateError('Published v1 fixture requires an empty v0 database.');
  }
  await createPublishedLearningV1Fixture(connection.runCustom);
}

class _PublishedV1FixtureQueryExecutorUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

class _FixtureStatement {
  const _FixtureStatement(this.sql, this.args);

  final String sql;
  final List<Object?> args;
}
