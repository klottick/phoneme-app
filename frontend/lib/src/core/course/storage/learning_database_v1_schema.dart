// Frozen SQL captured from published learning schema v1 commit
// 9207b20139a92750e20dbb428f83de86f92e6fdd. Keep independent of the current
// generated Drift model so v1 files can be strictly validated before migration.
const List<String> publishedLearningV1SchemaStatements = <String>[
  r'''    CREATE TABLE "learning_attempt_evidence" ("scope_id" INTEGER NOT NULL REFERENCES learning_scopes (id) ON DELETE
    RESTRICT, "attempt_id" TEXT NOT NULL, "evidence_index" INTEGER NOT NULL, "evidence_kind" TEXT NOT NULL, "slot"
    TEXT NULL, "reference_id" TEXT NULL, "outcome" TEXT NULL, "source" TEXT NULL, "activity_id" TEXT NULL, "run_generation"
    INTEGER NULL, "round" INTEGER NULL, "pair_id" TEXT NULL, "ui_generation" INTEGER NULL, "section_id" TEXT NULL,
    "item_id" TEXT NULL, "sentence_id" TEXT NULL, "audio_ref_id" TEXT NULL, "annotation_hash" TEXT NULL, "annotation_revision"
    INTEGER NULL, "content_revision" INTEGER NULL, PRIMARY KEY ("scope_id", "attempt_id", "evidence_index"), FOREIGN
    KEY (scope_id, attempt_id) REFERENCES learning_attempts(scope_id, attempt_id) ON DELETE RESTRICT, CHECK(typeof(scope_id)
    = 'integer' AND typeof(attempt_id) = 'text' AND typeof(evidence_index) = 'integer' AND typeof(evidence_kind)
    = 'text' AND (slot IS NULL OR typeof(slot) = 'text') AND (reference_id IS NULL OR typeof(reference_id) = 'text')
    AND (outcome IS NULL OR typeof(outcome) = 'text') AND (source IS NULL OR typeof(source) = 'text') AND (activity_id
    IS NULL OR typeof(activity_id) = 'text') AND (run_generation IS NULL OR typeof(run_generation) = 'integer') AND
    (round IS NULL OR typeof(round) = 'integer') AND (pair_id IS NULL OR typeof(pair_id) = 'text') AND (ui_generation
    IS NULL OR typeof(ui_generation) = 'integer') AND (section_id IS NULL OR typeof(section_id) = 'text') AND (item_id
    IS NULL OR typeof(item_id) = 'text') AND (sentence_id IS NULL OR typeof(sentence_id) = 'text') AND (audio_ref_id
    IS NULL OR typeof(audio_ref_id) = 'text') AND (annotation_hash IS NULL OR typeof(annotation_hash) = 'text') AND
    (annotation_revision IS NULL OR typeof(annotation_revision) = 'integer') AND (content_revision IS NULL OR typeof(content_revision)
    = 'integer')), CHECK(length(trim(attempt_id)) > 0), CHECK(evidence_kind IN ('comparisonPlayback', 'sentencePlayback',
    'sentenceContent')), CHECK(evidence_index BETWEEN 0 AND 9007199254740991), CHECK(slot IS NULL OR slot IN ('a',
    'b')), CHECK(reference_id IS NULL OR length(trim(reference_id)) > 0), CHECK(outcome IS NULL OR outcome IN ('completed',
    'cancelled', 'failed')), CHECK(source IS NULL OR source IN ('unverifiedRecording', 'reviewedRecording', 'practiceTts')),
    CHECK(activity_id IS NULL OR length(trim(activity_id)) > 0), CHECK(run_generation IS NULL OR run_generation BETWEEN
    1 AND 9007199254740991), CHECK(round IS NULL OR round BETWEEN 1 AND 9007199254740991), CHECK(pair_id IS NULL
    OR length(trim(pair_id)) > 0), CHECK(ui_generation IS NULL OR ui_generation BETWEEN 0 AND 9007199254740991),
    CHECK(section_id IS NULL OR length(trim(section_id)) > 0), CHECK(item_id IS NULL OR length(trim(item_id)) > 0),
    CHECK(sentence_id IS NULL OR length(trim(sentence_id)) > 0), CHECK(audio_ref_id IS NULL OR length(trim(audio_ref_id))
    > 0), CHECK(annotation_hash IS NULL OR length(trim(annotation_hash)) > 0), CHECK(annotation_revision IS NULL
    OR annotation_revision BETWEEN 1 AND 9007199254740991), CHECK(content_revision IS NULL OR content_revision BETWEEN
    1 AND 9007199254740991));''',
  r'''    CREATE TABLE "learning_attempt_values" ("scope_id" INTEGER NOT NULL REFERENCES learning_scopes (id) ON DELETE
    RESTRICT, "attempt_id" TEXT NOT NULL, "field" TEXT NOT NULL, "ordinal" INTEGER NOT NULL, "value_type" TEXT NOT
    NULL, "text_value" TEXT NULL, "int_value" INTEGER NULL, "bool_value" INTEGER NULL, PRIMARY KEY ("scope_id", "attempt_id",
    "field", "ordinal"), FOREIGN KEY (scope_id, attempt_id) REFERENCES learning_attempts(scope_id, attempt_id) ON
    DELETE RESTRICT, CHECK(typeof(scope_id) = 'integer' AND typeof(attempt_id) = 'text' AND typeof(field) = 'text'
    AND typeof(ordinal) = 'integer' AND typeof(value_type) = 'text' AND (text_value IS NULL OR typeof(text_value)
    = 'text') AND (int_value IS NULL OR typeof(int_value) = 'integer') AND (bool_value IS NULL OR typeof(bool_value)
    = 'integer')), CHECK(length(trim(attempt_id)) > 0), CHECK(field IN ('selected_sound', 'expected_sound', 'choice',
    'selected_word', 'expected_word', 'pair_id', 'selected_family', 'expected_family', 'word_id', 'tile_index', 'target_sound',
    'expected_membership', 'selected_token_id', 'expected_token_id')), CHECK(ordinal BETWEEN 0 AND 9007199254740991),
    CHECK((value_type = 'text' AND text_value IS NOT NULL AND length(trim(text_value)) > 0 AND int_value IS NULL
    AND bool_value IS NULL) OR (value_type = 'int' AND text_value IS NULL AND int_value IS NOT NULL AND int_value
    BETWEEN 0 AND 9007199254740991 AND bool_value IS NULL) OR (value_type = 'bool' AND text_value IS NULL AND int_value
    IS NULL AND bool_value IS NOT NULL AND bool_value IN (0, 1))), CHECK((field = 'expected_membership' AND value_type
    = 'bool' AND bool_value IS NOT NULL) OR (field = 'tile_index' AND value_type = 'int' AND int_value IS NOT NULL
    AND int_value BETWEEN 0 AND 15) OR (field IN ('selected_sound', 'expected_sound', 'choice', 'selected_word',
    'expected_word', 'pair_id', 'selected_family', 'expected_family', 'word_id', 'target_sound', 'selected_token_id',
    'expected_token_id') AND value_type = 'text' AND text_value IS NOT NULL)));''',
  r'''    CREATE TABLE "learning_attempts" ("scope_id" INTEGER NOT NULL REFERENCES learning_scopes (id) ON DELETE RESTRICT,
    "attempt_id" TEXT NOT NULL, "activity_id" TEXT NOT NULL, "run_generation" INTEGER NOT NULL, "command_sequence"
    INTEGER NOT NULL, "batch_index" INTEGER NOT NULL, "item_id" TEXT NULL, "item_occurrence" INTEGER NULL, "content_revision"
    INTEGER NOT NULL, "commit_ordinal" INTEGER NOT NULL, "answered_at_us" INTEGER NOT NULL, "committed_at_us" INTEGER
    NOT NULL, "answer_kind" TEXT NOT NULL, "correct" INTEGER NOT NULL, "skill" TEXT NULL, "origin" TEXT NULL, "presentation"
    TEXT NULL, "assistance_mask" INTEGER NULL, "content_state" TEXT NULL, "audio_source" TEXT NULL, "round" INTEGER
    NULL, "after_debrief" INTEGER NULL, "teaching_exposed" INTEGER NULL, "selected_relation" TEXT NULL, "expected_relation"
    TEXT NULL, "section_id" TEXT NULL, "sentence_id" TEXT NULL, "annotation_hash" TEXT NULL, "annotation_revision"
    INTEGER NULL, CHECK(typeof(scope_id) = 'integer' AND typeof(attempt_id) = 'text' AND typeof(activity_id) = 'text'
    AND typeof(run_generation) = 'integer' AND typeof(command_sequence) = 'integer' AND typeof(batch_index) = 'integer'
    AND (item_id IS NULL OR typeof(item_id) = 'text') AND (item_occurrence IS NULL OR typeof(item_occurrence) = 'integer')
    AND typeof(content_revision) = 'integer' AND typeof(commit_ordinal) = 'integer' AND typeof(answered_at_us) =
    'integer' AND typeof(committed_at_us) = 'integer' AND typeof(answer_kind) = 'text' AND typeof(correct) = 'integer'
    AND (skill IS NULL OR typeof(skill) = 'text') AND (origin IS NULL OR typeof(origin) = 'text') AND (presentation
    IS NULL OR typeof(presentation) = 'text') AND (assistance_mask IS NULL OR typeof(assistance_mask) = 'integer')
    AND (content_state IS NULL OR typeof(content_state) = 'text') AND (audio_source IS NULL OR typeof(audio_source)
    = 'text') AND (round IS NULL OR typeof(round) = 'integer') AND (after_debrief IS NULL OR typeof(after_debrief)
    = 'integer') AND (teaching_exposed IS NULL OR typeof(teaching_exposed) = 'integer') AND (selected_relation IS
    NULL OR typeof(selected_relation) = 'text') AND (expected_relation IS NULL OR typeof(expected_relation) = 'text')
    AND (section_id IS NULL OR typeof(section_id) = 'text') AND (sentence_id IS NULL OR typeof(sentence_id) = 'text')
    AND (annotation_hash IS NULL OR typeof(annotation_hash) = 'text') AND (annotation_revision IS NULL OR typeof(annotation_revision)
    = 'integer')), CHECK(length(trim(attempt_id)) > 0), CHECK(length(trim(activity_id)) > 0), CHECK(run_generation
    BETWEEN 1 AND 9007199254740991), CHECK(command_sequence BETWEEN 1 AND 9007199254740991), CHECK(batch_index BETWEEN
    0 AND 9007199254740991), CHECK(item_id IS NULL OR length(trim(item_id)) > 0), CHECK(item_occurrence IS NULL OR
    item_occurrence BETWEEN 1 AND 9007199254740991), CHECK(content_revision BETWEEN 1 AND 9007199254740991), CHECK(commit_ordinal
    BETWEEN 1 AND 9007199254740991), CHECK(answered_at_us BETWEEN 0 AND 9007199254740991), CHECK(committed_at_us
    BETWEEN 0 AND 9007199254740991), CHECK(answer_kind IN ('soundChoice', 'drillChoice', 'soundCue', 'wordTile',
    'comparisonPair', 'sentenceHunt')), CHECK(correct IN (0, 1)), CHECK(skill IS NULL OR skill IN ('listening', 'spelling')),
    CHECK(origin IS NULL OR origin IN ('practice', 'game')), CHECK(presentation IS NULL OR presentation IN ('firstInRun',
    'repeatInRun')), CHECK(assistance_mask IS NULL OR assistance_mask BETWEEN 0 AND 15), CHECK(content_state IS NULL
    OR content_state IN ('existingCurated', 'pending', 'reviewed')), CHECK(audio_source IS NULL OR audio_source IN
    ('pendingRecording', 'practiceSpeech', 'notApplicable')), CHECK(round IS NULL OR round BETWEEN 1 AND 9007199254740991),
    CHECK(after_debrief IS NULL OR after_debrief IN (0, 1)), CHECK(teaching_exposed IS NULL OR teaching_exposed IN
    (0, 1)), CHECK(selected_relation IS NULL OR selected_relation IN ('same', 'different')), CHECK(expected_relation
    IS NULL OR expected_relation IN ('same', 'different')), CHECK(section_id IS NULL OR length(trim(section_id))
    > 0), CHECK(sentence_id IS NULL OR length(trim(sentence_id)) > 0), CHECK(annotation_hash IS NULL OR length(trim(annotation_hash))
    > 0), CHECK(annotation_revision IS NULL OR annotation_revision BETWEEN 1 AND 9007199254740991));''',
  r'''    CREATE TABLE "learning_best_scores" ("scope_id" INTEGER NOT NULL REFERENCES learning_scopes (id) ON DELETE RESTRICT,
    "activity_id" TEXT NOT NULL, "score" INTEGER NOT NULL, PRIMARY KEY ("scope_id", "activity_id"), CHECK(typeof(scope_id)
    = 'integer' AND typeof(activity_id) = 'text' AND typeof(score) = 'integer'), CHECK(length(trim(activity_id))
    > 0), CHECK(score BETWEEN 0 AND 9007199254740991));''',
  r'''    CREATE TABLE "learning_command_receipts" ("scope_id" INTEGER NOT NULL REFERENCES learning_scopes (id) ON DELETE
    RESTRICT, "activity_id" TEXT NOT NULL, "token" TEXT NOT NULL, "canonical_payload" TEXT NOT NULL, "before_generation"
    INTEGER NOT NULL, "before_sequence" INTEGER NOT NULL, "before_cursor_revision" INTEGER NOT NULL, "after_generation"
    INTEGER NOT NULL, "after_sequence" INTEGER NOT NULL, "after_cursor_revision" INTEGER NOT NULL, "commit_ordinal"
    INTEGER NOT NULL, "result_activity_id" TEXT NOT NULL, "result_generation" INTEGER NOT NULL, "result_sequence"
    INTEGER NOT NULL, "result_cursor_revision" INTEGER NOT NULL, CHECK(typeof(scope_id) = 'integer' AND typeof(activity_id)
    = 'text' AND typeof(token) = 'text' AND typeof(canonical_payload) = 'text' AND typeof(before_generation) = 'integer'
    AND typeof(before_sequence) = 'integer' AND typeof(before_cursor_revision) = 'integer' AND typeof(after_generation)
    = 'integer' AND typeof(after_sequence) = 'integer' AND typeof(after_cursor_revision) = 'integer' AND typeof(commit_ordinal)
    = 'integer' AND typeof(result_activity_id) = 'text' AND typeof(result_generation) = 'integer' AND typeof(result_sequence)
    = 'integer' AND typeof(result_cursor_revision) = 'integer'), CHECK(length(trim(activity_id)) > 0), CHECK(length(token)
    = 22 AND token NOT GLOB '*[^A-Za-z0-9_-]*'), CHECK(json_valid(canonical_payload) AND json_type(canonical_payload)
    = 'object'), CHECK(json_type(canonical_payload, '$.activityId') IS 'text' AND json_extract(canonical_payload,
    '$.activityId') = activity_id), CHECK(json_type(canonical_payload, '$.expectedScopeRevision') IS 'integer' AND
    json_extract(canonical_payload, '$.expectedScopeRevision') BETWEEN 0 AND 9007199254740991), CHECK(before_generation
    BETWEEN 0 AND 9007199254740991), CHECK(before_sequence BETWEEN 0 AND 9007199254740991), CHECK(before_cursor_revision
    BETWEEN 0 AND 9007199254740991), CHECK(after_generation BETWEEN 1 AND 9007199254740991), CHECK(after_sequence
    BETWEEN 1 AND 9007199254740991), CHECK(after_cursor_revision BETWEEN 0 AND 9007199254740991), CHECK(commit_ordinal
    BETWEEN 1 AND 9007199254740991), CHECK(length(trim(result_activity_id)) > 0), CHECK(result_activity_id = activity_id),
    CHECK(result_generation BETWEEN 1 AND 9007199254740991), CHECK(result_sequence BETWEEN 1 AND 9007199254740991),
    CHECK(result_cursor_revision BETWEEN 0 AND 9007199254740991), CHECK(result_generation = after_generation AND
    result_sequence = after_sequence AND result_cursor_revision = after_cursor_revision));''',
  r'''    CREATE TABLE "learning_completions" ("scope_id" INTEGER NOT NULL REFERENCES learning_scopes (id) ON DELETE RESTRICT,
    "activity_id" TEXT NOT NULL, "content_revision" INTEGER NOT NULL, "policy_kind" TEXT NOT NULL, "policy_revision"
    INTEGER NOT NULL, "threshold_percent" INTEGER NOT NULL, "committed_at_us" INTEGER NOT NULL, CHECK(typeof(scope_id)
    = 'integer' AND typeof(activity_id) = 'text' AND typeof(content_revision) = 'integer' AND typeof(policy_kind)
    = 'text' AND typeof(policy_revision) = 'integer' AND typeof(threshold_percent) = 'integer' AND typeof(committed_at_us)
    = 'integer'), CHECK(length(trim(activity_id)) > 0), CHECK(content_revision BETWEEN 1 AND 9007199254740991), CHECK(policy_kind
    IN ('discoveryThreshold', 'legacyOnePass')), CHECK(policy_revision BETWEEN 1 AND 9007199254740991), CHECK(threshold_percent
    = -1 OR threshold_percent BETWEEN 1 AND 100), CHECK(committed_at_us BETWEEN 0 AND 9007199254740991));''',
  r'''    CREATE TABLE "learning_content_bindings" ("id" INTEGER NULL, "scope_id" INTEGER NOT NULL REFERENCES learning_scopes
    (id) ON DELETE RESTRICT, "activity_id" TEXT NOT NULL, "content_revision" INTEGER NOT NULL, "policy_kind" TEXT
    NULL, "policy_revision" INTEGER NULL, "catalogue_fingerprint" TEXT NULL, "section_fingerprint" TEXT NULL, "annotation_hash"
    TEXT NULL, "annotation_revision" INTEGER NULL, PRIMARY KEY (id), CHECK((id IS NULL OR typeof(id) = 'integer')
    AND typeof(scope_id) = 'integer' AND typeof(activity_id) = 'text' AND typeof(content_revision) = 'integer' AND
    (policy_kind IS NULL OR typeof(policy_kind) = 'text') AND (policy_revision IS NULL OR typeof(policy_revision)
    = 'integer') AND (catalogue_fingerprint IS NULL OR typeof(catalogue_fingerprint) = 'text') AND (section_fingerprint
    IS NULL OR typeof(section_fingerprint) = 'text') AND (annotation_hash IS NULL OR typeof(annotation_hash) = 'text')
    AND (annotation_revision IS NULL OR typeof(annotation_revision) = 'integer')), CHECK(length(trim(activity_id))
    > 0), CHECK(content_revision BETWEEN 1 AND 9007199254740991), CHECK(policy_kind IS NULL OR policy_kind IN ('discoveryThreshold',
    'legacyOnePass')), CHECK(policy_revision IS NULL OR policy_revision BETWEEN 1 AND 9007199254740991), CHECK((policy_kind
    IS NULL) = (policy_revision IS NULL)), CHECK(catalogue_fingerprint IS NULL OR length(trim(catalogue_fingerprint))
    > 0), CHECK(section_fingerprint IS NULL OR length(trim(section_fingerprint)) > 0), CHECK(annotation_hash IS NULL
    OR length(trim(annotation_hash)) > 0), CHECK(annotation_revision IS NULL OR annotation_revision BETWEEN 1 AND
    9007199254740991), CHECK((annotation_hash IS NULL) = (annotation_revision IS NULL)));''',
  r'''    CREATE TABLE "learning_exposure" ("scope_id" INTEGER NOT NULL REFERENCES learning_scopes (id) ON DELETE RESTRICT,
    "family" TEXT NOT NULL, "activity_id" TEXT NULL, "item_id" TEXT NULL, "target_sound" TEXT NULL, "section_id"
    TEXT NULL, "content_revision" INTEGER NULL, "presentations" INTEGER NULL, "assistance_mask" INTEGER NULL, CHECK(typeof(scope_id)
    = 'integer' AND typeof(family) = 'text' AND (activity_id IS NULL OR typeof(activity_id) = 'text') AND (item_id
    IS NULL OR typeof(item_id) = 'text') AND (target_sound IS NULL OR typeof(target_sound) = 'text') AND (section_id
    IS NULL OR typeof(section_id) = 'text') AND (content_revision IS NULL OR typeof(content_revision) = 'integer')
    AND (presentations IS NULL OR typeof(presentations) = 'integer') AND (assistance_mask IS NULL OR typeof(assistance_mask)
    = 'integer')), CHECK((family = 'course' AND activity_id IS NOT NULL AND item_id IS NOT NULL AND target_sound
    IS NOT NULL AND section_id IS NULL AND content_revision IS NULL AND presentations IS NOT NULL AND presentations
    BETWEEN 0 AND 9007199254740991 AND assistance_mask IS NOT NULL AND assistance_mask BETWEEN 0 AND 15) OR (family
    = 'sentence-hunt' AND activity_id IS NULL AND item_id IS NULL AND target_sound IS NULL AND section_id IS NOT
    NULL AND content_revision IS NOT NULL AND content_revision BETWEEN 1 AND 9007199254740991 AND presentations IS
    NULL AND assistance_mask IS NULL)), CHECK(activity_id IS NULL OR length(trim(activity_id)) > 0), CHECK(item_id
    IS NULL OR length(trim(item_id)) > 0), CHECK(target_sound IS NULL OR length(trim(target_sound)) > 0), CHECK(section_id
    IS NULL OR length(trim(section_id)) > 0));''',
  r'''    CREATE TABLE "learning_mistakes" ("scope_id" INTEGER NOT NULL REFERENCES learning_scopes (id) ON DELETE RESTRICT,
    "family" TEXT NOT NULL, "activity_id" TEXT NULL, "item_id" TEXT NULL, "target_sound" TEXT NULL, "skill" TEXT
    NULL, "pair_id" TEXT NULL, "section_id" TEXT NULL, "sentence_id" TEXT NULL, "audio_ref_id" TEXT NULL, "annotation_hash"
    TEXT NULL, "annotation_revision" INTEGER NULL, "content_revision" INTEGER NOT NULL, "first_wrong_attempt_id"
    TEXT NULL, "latest_wrong_attempt_id" TEXT NULL, "first_wrong_at_us" INTEGER NOT NULL, "latest_wrong_at_us" INTEGER
    NOT NULL, "failure_count" INTEGER NOT NULL, "last_run_generation" INTEGER NULL, CHECK(typeof(scope_id) = 'integer'
    AND typeof(family) = 'text' AND (activity_id IS NULL OR typeof(activity_id) = 'text') AND (item_id IS NULL OR
    typeof(item_id) = 'text') AND (target_sound IS NULL OR typeof(target_sound) = 'text') AND (skill IS NULL OR typeof(skill)
    = 'text') AND (pair_id IS NULL OR typeof(pair_id) = 'text') AND (section_id IS NULL OR typeof(section_id) = 'text')
    AND (sentence_id IS NULL OR typeof(sentence_id) = 'text') AND (audio_ref_id IS NULL OR typeof(audio_ref_id) =
    'text') AND (annotation_hash IS NULL OR typeof(annotation_hash) = 'text') AND (annotation_revision IS NULL OR
    typeof(annotation_revision) = 'integer') AND typeof(content_revision) = 'integer' AND (first_wrong_attempt_id
    IS NULL OR typeof(first_wrong_attempt_id) = 'text') AND (latest_wrong_attempt_id IS NULL OR typeof(latest_wrong_attempt_id)
    = 'text') AND typeof(first_wrong_at_us) = 'integer' AND typeof(latest_wrong_at_us) = 'integer' AND typeof(failure_count)
    = 'integer' AND (last_run_generation IS NULL OR typeof(last_run_generation) = 'integer')), CHECK(family IN ('course',
    'comparison', 'sentence-hunt')), CHECK(activity_id IS NULL OR length(trim(activity_id)) > 0), CHECK(item_id IS
    NULL OR length(trim(item_id)) > 0), CHECK(target_sound IS NULL OR length(trim(target_sound)) > 0), CHECK(skill
    IS NULL OR skill IN ('listening', 'spelling')), CHECK(pair_id IS NULL OR length(trim(pair_id)) > 0), CHECK(section_id
    IS NULL OR length(trim(section_id)) > 0), CHECK(sentence_id IS NULL OR length(trim(sentence_id)) > 0), CHECK(audio_ref_id
    IS NULL OR length(trim(audio_ref_id)) > 0), CHECK(annotation_hash IS NULL OR length(trim(annotation_hash)) >
    0), CHECK(annotation_revision IS NULL OR annotation_revision BETWEEN 1 AND 9007199254740991), CHECK(content_revision
    BETWEEN 1 AND 9007199254740991), CHECK(first_wrong_attempt_id IS NULL OR length(trim(first_wrong_attempt_id))
    > 0), CHECK(latest_wrong_attempt_id IS NULL OR length(trim(latest_wrong_attempt_id)) > 0), CHECK(first_wrong_at_us
    BETWEEN 0 AND 9007199254740991), CHECK(latest_wrong_at_us BETWEEN first_wrong_at_us AND 9007199254740991), CHECK(failure_count
    BETWEEN 1 AND 9007199254740991), CHECK(last_run_generation IS NULL OR last_run_generation BETWEEN 1 AND 9007199254740991),
    CHECK((family = 'course' AND activity_id IS NOT NULL AND item_id IS NOT NULL AND target_sound IS NOT NULL AND
    skill IS NOT NULL AND pair_id IS NULL AND section_id IS NULL AND sentence_id IS NULL AND audio_ref_id IS NULL
    AND annotation_hash IS NULL AND annotation_revision IS NULL) OR (family = 'comparison' AND activity_id IS NOT
    NULL AND pair_id IS NOT NULL AND content_revision > 0 AND item_id IS NULL AND target_sound IS NULL AND skill
    IS NULL AND section_id IS NULL AND sentence_id IS NULL AND audio_ref_id IS NULL AND annotation_hash IS NULL AND
    annotation_revision IS NULL) OR (family = 'sentence-hunt' AND section_id IS NOT NULL AND item_id IS NOT NULL
    AND sentence_id IS NOT NULL AND audio_ref_id IS NOT NULL AND annotation_hash IS NOT NULL AND annotation_revision
    IS NOT NULL AND activity_id IS NULL AND target_sound IS NULL AND skill IS NULL AND pair_id IS NULL)));''',
  r'''    CREATE TABLE "learning_runs" ("scope_id" INTEGER NOT NULL REFERENCES learning_scopes (id) ON DELETE RESTRICT,
    "activity_id" TEXT NOT NULL, "activity_kind" TEXT NOT NULL, "run_generation" INTEGER NOT NULL, "sequence" INTEGER
    NOT NULL, "cursor_revision" INTEGER NOT NULL, "content_binding_id" INTEGER NOT NULL REFERENCES learning_content_bindings
    (id) ON DELETE RESTRICT, "run_mode" TEXT NULL, "finished" INTEGER NOT NULL, "session_id" TEXT NULL, "policy_revision"
    INTEGER NULL, "threshold_percent" INTEGER NULL, "run_start_round" INTEGER NULL, "checkpoint_json" TEXT NOT NULL,
    "latest_receipt_token" TEXT NOT NULL, "latest_receipt_payload" TEXT NOT NULL, "latest_receipt_before_generation"
    INTEGER NOT NULL, "latest_receipt_before_sequence" INTEGER NOT NULL, "latest_receipt_before_cursor_revision"
    INTEGER NOT NULL, "latest_receipt_commit_ordinal" INTEGER NOT NULL, CHECK(typeof(scope_id) = 'integer' AND typeof(activity_id)
    = 'text' AND typeof(activity_kind) = 'text' AND typeof(run_generation) = 'integer' AND typeof(sequence) = 'integer'
    AND typeof(cursor_revision) = 'integer' AND typeof(content_binding_id) = 'integer' AND (run_mode IS NULL OR typeof(run_mode)
    = 'text') AND typeof(finished) = 'integer' AND (session_id IS NULL OR typeof(session_id) = 'text') AND (policy_revision
    IS NULL OR typeof(policy_revision) = 'integer') AND (threshold_percent IS NULL OR typeof(threshold_percent) =
    'integer') AND (run_start_round IS NULL OR typeof(run_start_round) = 'integer') AND typeof(checkpoint_json) =
    'text' AND typeof(latest_receipt_token) = 'text' AND typeof(latest_receipt_payload) = 'text' AND typeof(latest_receipt_before_generation)
    = 'integer' AND typeof(latest_receipt_before_sequence) = 'integer' AND typeof(latest_receipt_before_cursor_revision)
    = 'integer' AND typeof(latest_receipt_commit_ordinal) = 'integer'), CHECK(length(trim(activity_id)) > 0), CHECK(activity_kind
    IN ('discovery', 'legacyLesson', 'drill', 'soundGame', 'wordGame', 'comparison', 'sentence-hunt')), CHECK(run_generation
    BETWEEN 1 AND 9007199254740991), CHECK(sequence BETWEEN 1 AND 9007199254740991), CHECK(cursor_revision BETWEEN
    0 AND 9007199254740991), CHECK(finished IN (0, 1)), CHECK(run_mode IS NULL OR run_mode IN ('practice', 'reviewOnly')),
    CHECK(session_id IS NULL OR length(trim(session_id)) > 0), CHECK(policy_revision IS NULL OR policy_revision BETWEEN
    1 AND 9007199254740991), CHECK(threshold_percent IS NULL OR threshold_percent BETWEEN 1 AND 100), CHECK(run_start_round
    IS NULL OR run_start_round BETWEEN 1 AND 9007199254740991), CHECK(json_valid(checkpoint_json) AND json_type(checkpoint_json)
    = 'object'), CHECK(length(checkpoint_json) > 1), CHECK(length(CAST(checkpoint_json AS BLOB)) <= 1048576), CHECK(length(latest_receipt_token)
    = 22 AND latest_receipt_token NOT GLOB '*[^A-Za-z0-9_-]*'), CHECK(json_valid(latest_receipt_payload) AND json_type(latest_receipt_payload)
    = 'object'), CHECK(json_type(latest_receipt_payload, '$.activityId') IS 'text' AND json_extract(latest_receipt_payload,
    '$.activityId') = activity_id), CHECK(json_type(latest_receipt_payload, '$.expectedScopeRevision') IS 'integer'
    AND json_extract(latest_receipt_payload, '$.expectedScopeRevision') BETWEEN 0 AND 9007199254740991), CHECK(latest_receipt_before_generation
    BETWEEN 0 AND 9007199254740991), CHECK(latest_receipt_before_sequence BETWEEN 0 AND 9007199254740991), CHECK(latest_receipt_before_cursor_revision
    BETWEEN 0 AND 9007199254740991), CHECK(latest_receipt_commit_ordinal BETWEEN 1 AND 9007199254740991));''',
  r'''    CREATE TABLE "learning_scopes" ("id" INTEGER NULL, "owner_kind" TEXT NOT NULL, "owner_id" TEXT NOT NULL, "course_id"
    TEXT NOT NULL, "family" TEXT NOT NULL, "schema_version" INTEGER NOT NULL, "revision" INTEGER NOT NULL, "commit_ordinal"
    INTEGER NOT NULL, "availability_state" TEXT NOT NULL, PRIMARY KEY (id), CHECK((id IS NULL OR typeof(id) = 'integer')
    AND typeof(owner_kind) = 'text' AND typeof(owner_id) = 'text' AND typeof(course_id) = 'text' AND typeof(family)
    = 'text' AND typeof(schema_version) = 'integer' AND typeof(revision) = 'integer' AND typeof(commit_ordinal) =
    'integer' AND typeof(availability_state) = 'text'), CHECK(owner_kind IN ('guest', 'account')), CHECK((owner_kind='guest'
    AND owner_id='') OR (owner_kind='account' AND length(trim(owner_id))>0)), CHECK(length(trim(course_id)) > 0),
    CHECK(family IN ('course', 'comparison', 'sentence-hunt')), CHECK(schema_version BETWEEN 1 AND 9007199254740991),
    CHECK(revision BETWEEN 0 AND 9007199254740991), CHECK(commit_ordinal BETWEEN 0 AND 9007199254740991), CHECK(commit_ordinal
    <= revision), CHECK(availability_state IN ('available', 'unavailable')));''',
  r'''    CREATE TABLE "learning_summaries" ("scope_id" INTEGER NOT NULL REFERENCES learning_scopes (id) ON DELETE RESTRICT,
    "family" TEXT NOT NULL, "activity_id" TEXT NULL, "sound" TEXT NULL, "skill" TEXT NULL, "origin" TEXT NULL, "presentation"
    TEXT NULL, "assistance_mask" INTEGER NULL, "pair_id" TEXT NULL, "section_id" TEXT NULL, "item_id" TEXT NULL,
    "sentence_id" TEXT NULL, "audio_ref_id" TEXT NULL, "annotation_hash" TEXT NULL, "annotation_revision" INTEGER
    NULL, "content_revision" INTEGER NULL, "bucket" TEXT NOT NULL, "correct" INTEGER NOT NULL, "total" INTEGER NOT
    NULL, CHECK(typeof(scope_id) = 'integer' AND typeof(family) = 'text' AND (activity_id IS NULL OR typeof(activity_id)
    = 'text') AND (sound IS NULL OR typeof(sound) = 'text') AND (skill IS NULL OR typeof(skill) = 'text') AND (origin
    IS NULL OR typeof(origin) = 'text') AND (presentation IS NULL OR typeof(presentation) = 'text') AND (assistance_mask
    IS NULL OR typeof(assistance_mask) = 'integer') AND (pair_id IS NULL OR typeof(pair_id) = 'text') AND (section_id
    IS NULL OR typeof(section_id) = 'text') AND (item_id IS NULL OR typeof(item_id) = 'text') AND (sentence_id IS
    NULL OR typeof(sentence_id) = 'text') AND (audio_ref_id IS NULL OR typeof(audio_ref_id) = 'text') AND (annotation_hash
    IS NULL OR typeof(annotation_hash) = 'text') AND (annotation_revision IS NULL OR typeof(annotation_revision)
    = 'integer') AND (content_revision IS NULL OR typeof(content_revision) = 'integer') AND typeof(bucket) = 'text'
    AND typeof(correct) = 'integer' AND typeof(total) = 'integer'), CHECK(family IN ('course', 'comparison', 'sentence-hunt')),
    CHECK(activity_id IS NULL OR length(trim(activity_id)) > 0), CHECK(sound IS NULL OR length(trim(sound)) > 0),
    CHECK(skill IS NULL OR skill IN ('listening', 'spelling')), CHECK(origin IS NULL OR origin IN ('practice', 'game')),
    CHECK(presentation IS NULL OR presentation IN ('firstInRun', 'repeatInRun')), CHECK(assistance_mask IS NULL OR
    assistance_mask BETWEEN 0 AND 15), CHECK(pair_id IS NULL OR length(trim(pair_id)) > 0), CHECK(section_id IS NULL
    OR length(trim(section_id)) > 0), CHECK(item_id IS NULL OR length(trim(item_id)) > 0), CHECK(sentence_id IS NULL
    OR length(trim(sentence_id)) > 0), CHECK(audio_ref_id IS NULL OR length(trim(audio_ref_id)) > 0), CHECK(annotation_hash
    IS NULL OR length(trim(annotation_hash)) > 0), CHECK(annotation_revision IS NULL OR annotation_revision BETWEEN
    1 AND 9007199254740991), CHECK(content_revision IS NULL OR content_revision BETWEEN 1 AND 9007199254740991),
    CHECK(correct BETWEEN 0 AND 9007199254740991), CHECK(total BETWEEN 0 AND 9007199254740991 AND correct <= total),
    CHECK((family = 'course' AND sound IS NOT NULL AND skill IS NOT NULL AND origin IS NOT NULL AND presentation
    IS NOT NULL AND assistance_mask IS NOT NULL AND activity_id IS NULL AND content_revision IS NULL AND pair_id
    IS NULL AND section_id IS NULL AND item_id IS NULL AND sentence_id IS NULL AND audio_ref_id IS NULL AND annotation_hash
    IS NULL AND annotation_revision IS NULL AND bucket = 'all') OR (family = 'comparison' AND activity_id IS NOT
    NULL AND pair_id IS NOT NULL AND content_revision IS NOT NULL AND sound IS NULL AND skill IS NULL AND origin
    IS NULL AND presentation IS NULL AND assistance_mask IS NULL AND section_id IS NULL AND item_id IS NULL AND sentence_id
    IS NULL AND audio_ref_id IS NULL AND annotation_hash IS NULL AND annotation_revision IS NULL AND bucket IN ('firstInRun',
    'repeatInRun', 'afterDebrief')) OR (family = 'sentence-hunt' AND section_id IS NOT NULL AND item_id IS NOT NULL
    AND sentence_id IS NOT NULL AND audio_ref_id IS NOT NULL AND annotation_hash IS NOT NULL AND annotation_revision
    IS NOT NULL AND content_revision IS NOT NULL AND activity_id IS NULL AND sound IS NULL AND skill IS NULL AND
    origin IS NULL AND presentation IS NULL AND assistance_mask IS NULL AND pair_id IS NULL AND bucket IN ('firstInRun',
    'repeatInRun', 'firstTeachingExposed', 'repeatTeachingExposed'))) );''',
  r'''    CREATE TABLE "supported_sync_outbox" ("scope_id" INTEGER NOT NULL REFERENCES learning_scopes (id) ON DELETE RESTRICT,
    "event_id" TEXT NOT NULL, "enqueue_commit_ordinal" INTEGER NOT NULL, "enqueue_event_index" INTEGER NOT NULL,
    "user_id" TEXT NOT NULL, "course_id" TEXT NOT NULL, "kind" TEXT NOT NULL, "sound" TEXT NULL, "skill" TEXT NULL,
    "correct" INTEGER NULL, "activity" TEXT NULL, "lesson_id" TEXT NULL, "game" TEXT NULL, "score" INTEGER NULL,
    CHECK(typeof(scope_id) = 'integer' AND typeof(event_id) = 'text' AND typeof(enqueue_commit_ordinal) = 'integer'
    AND typeof(enqueue_event_index) = 'integer' AND typeof(user_id) = 'text' AND typeof(course_id) = 'text' AND typeof(kind)
    = 'text' AND (sound IS NULL OR typeof(sound) = 'text') AND (skill IS NULL OR typeof(skill) = 'text') AND (correct
    IS NULL OR typeof(correct) = 'integer') AND (activity IS NULL OR typeof(activity) = 'text') AND (lesson_id IS
    NULL OR typeof(lesson_id) = 'text') AND (game IS NULL OR typeof(game) = 'text') AND (score IS NULL OR typeof(score)
    = 'integer')), CHECK(length(trim(event_id)) > 0), CHECK(enqueue_commit_ordinal BETWEEN 1 AND 9007199254740991),
    CHECK(enqueue_event_index BETWEEN 0 AND 9007199254740991), CHECK(length(trim(user_id)) > 0), CHECK(length(trim(course_id))
    > 0), CHECK(kind IN ('answer', 'lesson', 'score')), CHECK(sound IS NULL OR length(trim(sound)) > 0), CHECK(skill
    IS NULL OR skill IN ('listening', 'spelling')), CHECK(correct IS NULL OR correct IN (0, 1)), CHECK(activity IS
    NULL OR length(trim(activity)) > 0), CHECK(lesson_id IS NULL OR length(trim(lesson_id)) > 0), CHECK(game IS NULL
    OR length(trim(game)) > 0), CHECK(score IS NULL OR score BETWEEN 0 AND 9007199254740991), CHECK((kind = 'answer'
    AND sound IS NOT NULL AND skill IS NOT NULL AND correct IS NOT NULL AND activity IS NOT NULL AND lesson_id IS
    NULL AND game IS NULL AND score IS NULL) OR (kind = 'lesson' AND sound IS NULL AND skill IS NULL AND correct
    IS NULL AND activity IS NULL AND lesson_id IS NOT NULL AND game IS NULL AND score IS NULL) OR (kind = 'score'
    AND sound IS NULL AND skill IS NULL AND correct IS NULL AND activity IS NULL AND lesson_id IS NULL AND game IS
    NOT NULL AND score IS NOT NULL)));''',
  r'''    CREATE INDEX ix_learning_attempts_scope_commit_batch ON learning_attempts(scope_id, commit_ordinal, activity_id,
    run_generation, command_sequence, batch_index);''',
  r'''    CREATE INDEX ix_learning_receipts_scope_commit_ordinal ON learning_command_receipts(scope_id, commit_ordinal,
    activity_id, after_generation, after_sequence);''',
  r'''    CREATE INDEX ix_learning_runs_scope_cursor ON learning_runs(scope_id, activity_id, run_generation, sequence,
    cursor_revision);''',
  r'''    CREATE UNIQUE INDEX ux_learning_attempt_evidence_attempt_index ON learning_attempt_evidence(scope_id, attempt_id,
    evidence_index);''',
  r'''    CREATE UNIQUE INDEX ux_learning_attempt_values_attempt_field_ordinal ON learning_attempt_values(scope_id, attempt_id,
    field, ordinal);''',
  r'''    CREATE UNIQUE INDEX ux_learning_attempts_command_batch ON learning_attempts(scope_id, activity_id, run_generation,
    command_sequence, batch_index);''',
  r'''    CREATE UNIQUE INDEX ux_learning_attempts_scope_attempt ON learning_attempts(scope_id, attempt_id);''',
  r'''    CREATE UNIQUE INDEX ux_learning_best_scores_scope_activity ON learning_best_scores(scope_id, activity_id);''',
  r'''    CREATE UNIQUE INDEX ux_learning_command_receipts_activity_cursor ON learning_command_receipts(scope_id, activity_id,
    after_generation, after_sequence);''',
  r'''    CREATE UNIQUE INDEX ux_learning_command_receipts_scope_token ON learning_command_receipts(scope_id, token);''',
  r'''    CREATE UNIQUE INDEX ux_learning_completions_identity ON learning_completions(scope_id, activity_id, content_revision,
    policy_kind, policy_revision, threshold_percent);''',
  r'''    CREATE UNIQUE INDEX ux_learning_content_bindings_identity ON learning_content_bindings(scope_id, activity_id,
    content_revision, COALESCE(policy_kind, ''), COALESCE(policy_revision, -1), COALESCE(catalogue_fingerprint, ''),
    COALESCE(section_fingerprint, ''), COALESCE(annotation_hash, ''), COALESCE(annotation_revision, -1));''',
  r'''    CREATE UNIQUE INDEX ux_learning_exposure_identity ON learning_exposure(scope_id, family, COALESCE(activity_id,
    ''), COALESCE(item_id, ''), COALESCE(target_sound, ''), COALESCE(section_id, ''), COALESCE(content_revision,
    -1));''',
  r'''    CREATE UNIQUE INDEX ux_learning_mistakes_identity ON learning_mistakes(scope_id, family, COALESCE(activity_id,
    ''), COALESCE(item_id, ''), COALESCE(target_sound, ''), COALESCE(skill, ''), COALESCE(pair_id, ''), COALESCE(section_id,
    ''), COALESCE(sentence_id, ''), COALESCE(audio_ref_id, ''), COALESCE(annotation_hash, ''), COALESCE(annotation_revision,
    -1), content_revision);''',
  r'''    CREATE UNIQUE INDEX ux_learning_runs_scope_activity ON learning_runs(scope_id, activity_id);''',
  r'''    CREATE UNIQUE INDEX ux_learning_runs_scope_latest_receipt_token ON learning_runs(scope_id, latest_receipt_token);''',
  r'''    CREATE UNIQUE INDEX ux_learning_scopes_owner_course_family ON learning_scopes(owner_kind, owner_id, course_id,
    family);''',
  r'''    CREATE UNIQUE INDEX ux_learning_summaries_identity_bucket ON learning_summaries(scope_id, family, bucket, COALESCE(activity_id,
    ''), COALESCE(sound, ''), COALESCE(skill, ''), COALESCE(origin, ''), COALESCE(presentation, ''), COALESCE(assistance_mask,
    -1), COALESCE(pair_id, ''), COALESCE(section_id, ''), COALESCE(item_id, ''), COALESCE(sentence_id, ''), COALESCE(audio_ref_id,
    ''), COALESCE(annotation_hash, ''), COALESCE(annotation_revision, -1), COALESCE(content_revision, -1));''',
  r'''    CREATE UNIQUE INDEX ux_supported_sync_outbox_scope_enqueue_order ON supported_sync_outbox(scope_id, enqueue_commit_ordinal,
    enqueue_event_index);''',
  r'''    CREATE UNIQUE INDEX ux_supported_sync_outbox_scope_event ON supported_sync_outbox(scope_id, event_id);''',
  r'''    CREATE TRIGGER trg_learning_attempt_evidence_scope_family_insert BEFORE INSERT ON learning_attempt_evidence WHEN
    NOT (EXISTS (   SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND (     (s.family = 'comparison'
    AND NEW.evidence_kind = 'comparisonPlayback' AND       ((NEW.evidence_index = 0 AND NEW.slot = 'a') OR
     (NEW.evidence_index = 1 AND NEW.slot = 'b')) AND       NEW.reference_id IS NOT NULL AND NEW.outcome = 'completed'
    AND       NEW.source = 'unverifiedRecording' AND NEW.activity_id IS NOT NULL AND       NEW.run_generation IS
    NOT NULL AND NEW.round IS NOT NULL AND       NEW.pair_id IS NOT NULL AND NEW.ui_generation IS NOT NULL AND
        NEW.section_id IS NULL AND NEW.item_id IS NULL AND       NEW.sentence_id IS NULL AND NEW.audio_ref_id IS
    NULL AND       NEW.annotation_hash IS NULL AND NEW.annotation_revision IS NULL AND       NEW.content_revision
    IS NULL) OR     (s.family = 'sentence-hunt' AND       NEW.evidence_kind = 'sentencePlayback' AND NEW.evidence_index
    = 0 AND       NEW.slot IS NULL AND NEW.reference_id IS NOT NULL AND       NEW.outcome IS NOT NULL AND NEW.source
    IS NOT NULL AND       NEW.activity_id IS NOT NULL AND NEW.run_generation IS NOT NULL AND       NEW.round IS NOT
    NULL AND NEW.pair_id IS NULL AND       NEW.ui_generation IS NOT NULL AND NEW.section_id IS NOT NULL AND
     NEW.item_id IS NOT NULL AND NEW.sentence_id IS NOT NULL AND       NEW.audio_ref_id IS NOT NULL AND NEW.annotation_hash
    IS NOT NULL AND       NEW.annotation_revision IS NOT NULL AND NEW.content_revision IS NOT NULL) OR     (s.family
    = 'sentence-hunt' AND       NEW.evidence_kind = 'sentenceContent' AND NEW.evidence_index = 1 AND       NEW.slot
    IS NULL AND NEW.reference_id IS NULL AND NEW.outcome IS NULL AND       NEW.source IS NULL AND NEW.activity_id
    IS NULL AND       NEW.run_generation IS NULL AND NEW.round IS NULL AND       NEW.pair_id IS NULL AND NEW.ui_generation
    IS NULL AND       NEW.section_id IS NOT NULL AND NEW.item_id IS NOT NULL AND       NEW.sentence_id IS NOT NULL
    AND NEW.audio_ref_id IS NOT NULL AND       NEW.annotation_hash IS NOT NULL AND NEW.annotation_revision IS NOT
    NULL AND       NEW.content_revision IS NOT NULL)   ) )) BEGIN   SELECT RAISE(ABORT, 'trg_learning_attempt_evidence_scope_family_insert rejected row');
    END;''',
  r'''    CREATE TRIGGER trg_learning_attempt_evidence_scope_family_update BEFORE UPDATE ON learning_attempt_evidence WHEN
    NOT (EXISTS (   SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND (     (s.family = 'comparison'
    AND NEW.evidence_kind = 'comparisonPlayback' AND       ((NEW.evidence_index = 0 AND NEW.slot = 'a') OR
     (NEW.evidence_index = 1 AND NEW.slot = 'b')) AND       NEW.reference_id IS NOT NULL AND NEW.outcome = 'completed'
    AND       NEW.source = 'unverifiedRecording' AND NEW.activity_id IS NOT NULL AND       NEW.run_generation IS
    NOT NULL AND NEW.round IS NOT NULL AND       NEW.pair_id IS NOT NULL AND NEW.ui_generation IS NOT NULL AND
        NEW.section_id IS NULL AND NEW.item_id IS NULL AND       NEW.sentence_id IS NULL AND NEW.audio_ref_id IS
    NULL AND       NEW.annotation_hash IS NULL AND NEW.annotation_revision IS NULL AND       NEW.content_revision
    IS NULL) OR     (s.family = 'sentence-hunt' AND       NEW.evidence_kind = 'sentencePlayback' AND NEW.evidence_index
    = 0 AND       NEW.slot IS NULL AND NEW.reference_id IS NOT NULL AND       NEW.outcome IS NOT NULL AND NEW.source
    IS NOT NULL AND       NEW.activity_id IS NOT NULL AND NEW.run_generation IS NOT NULL AND       NEW.round IS NOT
    NULL AND NEW.pair_id IS NULL AND       NEW.ui_generation IS NOT NULL AND NEW.section_id IS NOT NULL AND
     NEW.item_id IS NOT NULL AND NEW.sentence_id IS NOT NULL AND       NEW.audio_ref_id IS NOT NULL AND NEW.annotation_hash
    IS NOT NULL AND       NEW.annotation_revision IS NOT NULL AND NEW.content_revision IS NOT NULL) OR     (s.family
    = 'sentence-hunt' AND       NEW.evidence_kind = 'sentenceContent' AND NEW.evidence_index = 1 AND       NEW.slot
    IS NULL AND NEW.reference_id IS NULL AND NEW.outcome IS NULL AND       NEW.source IS NULL AND NEW.activity_id
    IS NULL AND       NEW.run_generation IS NULL AND NEW.round IS NULL AND       NEW.pair_id IS NULL AND NEW.ui_generation
    IS NULL AND       NEW.section_id IS NOT NULL AND NEW.item_id IS NOT NULL AND       NEW.sentence_id IS NOT NULL
    AND NEW.audio_ref_id IS NOT NULL AND       NEW.annotation_hash IS NOT NULL AND NEW.annotation_revision IS NOT
    NULL AND       NEW.content_revision IS NOT NULL)   ) )) BEGIN   SELECT RAISE(ABORT, 'trg_learning_attempt_evidence_scope_family_update rejected row');
    END;''',
  r'''    CREATE TRIGGER trg_learning_attempt_values_scope_family_insert BEFORE INSERT ON learning_attempt_values WHEN
    NOT (EXISTS (   SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND (     (s.family = 'course'
    AND NEW.field IN       ('selected_sound', 'expected_sound', 'choice', 'selected_word',        'expected_word',
    'pair_id', 'selected_family', 'expected_family',        'word_id', 'tile_index', 'target_sound', 'expected_membership'))
    OR     (s.family = 'sentence-hunt' AND NEW.field IN       ('selected_token_id', 'expected_token_id'))   ) ))
    BEGIN   SELECT RAISE(ABORT, 'trg_learning_attempt_values_scope_family_insert rejected row'); END;''',
  r'''    CREATE TRIGGER trg_learning_attempt_values_scope_family_update BEFORE UPDATE ON learning_attempt_values WHEN
    NOT (EXISTS (   SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND (     (s.family = 'course'
    AND NEW.field IN       ('selected_sound', 'expected_sound', 'choice', 'selected_word',        'expected_word',
    'pair_id', 'selected_family', 'expected_family',        'word_id', 'tile_index', 'target_sound', 'expected_membership'))
    OR     (s.family = 'sentence-hunt' AND NEW.field IN       ('selected_token_id', 'expected_token_id'))   ) ))
    BEGIN   SELECT RAISE(ABORT, 'trg_learning_attempt_values_scope_family_update rejected row'); END;''',
  r'''    CREATE TRIGGER trg_learning_attempts_scope_family_insert BEFORE INSERT ON learning_attempts WHEN NOT (EXISTS
    (   SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND (     (s.family = 'course' AND NEW.item_id
    IS NOT NULL AND       NEW.item_occurrence IS NOT NULL AND NEW.answer_kind IN         ('soundChoice', 'drillChoice',
    'soundCue', 'wordTile') AND       NEW.skill IS NOT NULL AND NEW.origin IS NOT NULL AND       NEW.presentation
    IS NOT NULL AND NEW.assistance_mask IS NOT NULL AND       NEW.content_state IS NOT NULL AND NEW.audio_source
    IS NOT NULL AND       NEW.round IS NULL AND NEW.after_debrief IS NULL AND       NEW.teaching_exposed IS NULL
    AND NEW.selected_relation IS NULL AND       NEW.expected_relation IS NULL AND NEW.section_id IS NULL AND
      NEW.sentence_id IS NULL AND NEW.annotation_hash IS NULL AND       NEW.annotation_revision IS NULL) OR     (s.family
    = 'comparison' AND NEW.item_id IS NOT NULL AND       NEW.item_occurrence IS NULL AND NEW.answer_kind = 'comparisonPair'
    AND       NEW.skill IS NULL AND NEW.origin IS NULL AND       NEW.presentation IS NOT NULL AND NEW.assistance_mask
    IS NULL AND       NEW.content_state IS NULL AND NEW.audio_source IS NULL AND       NEW.round IS NOT NULL AND
    NEW.after_debrief IS NOT NULL AND       NEW.teaching_exposed IS NULL AND NEW.selected_relation IS NOT NULL AND
          NEW.expected_relation IS NOT NULL AND NEW.section_id IS NULL AND       NEW.sentence_id IS NULL AND NEW.annotation_hash
    IS NULL AND       NEW.annotation_revision IS NULL) OR     (s.family = 'sentence-hunt' AND NEW.item_id IS NOT
    NULL AND       NEW.item_occurrence IS NULL AND NEW.answer_kind = 'sentenceHunt' AND       NEW.skill IS NULL AND
    NEW.origin IS NULL AND       NEW.presentation IS NOT NULL AND NEW.assistance_mask IS NULL AND       NEW.content_state
    IS NULL AND NEW.audio_source IS NULL AND       NEW.round IS NOT NULL AND NEW.after_debrief IS NULL AND
    NEW.teaching_exposed IS NOT NULL AND NEW.selected_relation IS NULL AND       NEW.expected_relation IS NULL AND
    NEW.section_id IS NOT NULL AND       NEW.activity_id = NEW.section_id AND NEW.sentence_id IS NOT NULL AND
       NEW.annotation_hash IS NOT NULL AND NEW.annotation_revision IS NOT NULL)   ) )) BEGIN   SELECT RAISE(ABORT,
    'trg_learning_attempts_scope_family_insert rejected row'); END;''',
  r'''    CREATE TRIGGER trg_learning_attempts_scope_family_update BEFORE UPDATE ON learning_attempts WHEN NOT (EXISTS
    (   SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND (     (s.family = 'course' AND NEW.item_id
    IS NOT NULL AND       NEW.item_occurrence IS NOT NULL AND NEW.answer_kind IN         ('soundChoice', 'drillChoice',
    'soundCue', 'wordTile') AND       NEW.skill IS NOT NULL AND NEW.origin IS NOT NULL AND       NEW.presentation
    IS NOT NULL AND NEW.assistance_mask IS NOT NULL AND       NEW.content_state IS NOT NULL AND NEW.audio_source
    IS NOT NULL AND       NEW.round IS NULL AND NEW.after_debrief IS NULL AND       NEW.teaching_exposed IS NULL
    AND NEW.selected_relation IS NULL AND       NEW.expected_relation IS NULL AND NEW.section_id IS NULL AND
      NEW.sentence_id IS NULL AND NEW.annotation_hash IS NULL AND       NEW.annotation_revision IS NULL) OR     (s.family
    = 'comparison' AND NEW.item_id IS NOT NULL AND       NEW.item_occurrence IS NULL AND NEW.answer_kind = 'comparisonPair'
    AND       NEW.skill IS NULL AND NEW.origin IS NULL AND       NEW.presentation IS NOT NULL AND NEW.assistance_mask
    IS NULL AND       NEW.content_state IS NULL AND NEW.audio_source IS NULL AND       NEW.round IS NOT NULL AND
    NEW.after_debrief IS NOT NULL AND       NEW.teaching_exposed IS NULL AND NEW.selected_relation IS NOT NULL AND
          NEW.expected_relation IS NOT NULL AND NEW.section_id IS NULL AND       NEW.sentence_id IS NULL AND NEW.annotation_hash
    IS NULL AND       NEW.annotation_revision IS NULL) OR     (s.family = 'sentence-hunt' AND NEW.item_id IS NOT
    NULL AND       NEW.item_occurrence IS NULL AND NEW.answer_kind = 'sentenceHunt' AND       NEW.skill IS NULL AND
    NEW.origin IS NULL AND       NEW.presentation IS NOT NULL AND NEW.assistance_mask IS NULL AND       NEW.content_state
    IS NULL AND NEW.audio_source IS NULL AND       NEW.round IS NOT NULL AND NEW.after_debrief IS NULL AND
    NEW.teaching_exposed IS NOT NULL AND NEW.selected_relation IS NULL AND       NEW.expected_relation IS NULL AND
    NEW.section_id IS NOT NULL AND       NEW.activity_id = NEW.section_id AND NEW.sentence_id IS NOT NULL AND
       NEW.annotation_hash IS NOT NULL AND NEW.annotation_revision IS NOT NULL)   ) )) BEGIN   SELECT RAISE(ABORT,
    'trg_learning_attempts_scope_family_update rejected row'); END;''',
  r'''    CREATE TRIGGER trg_learning_completions_scope_family_insert BEFORE INSERT ON learning_completions WHEN NOT (EXISTS
    (   SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND (     (s.family = 'course' AND       ((NEW.policy_kind
    = 'legacyOnePass' AND NEW.threshold_percent = -1) OR        (NEW.policy_kind = 'discoveryThreshold' AND
       NEW.threshold_percent BETWEEN 1 AND 100))) OR     (s.family IN ('comparison', 'sentence-hunt') AND       NEW.policy_kind
    = 'discoveryThreshold' AND       NEW.threshold_percent BETWEEN 1 AND 100)   ) )) BEGIN   SELECT RAISE(ABORT,
    'trg_learning_completions_scope_family_insert rejected row'); END;''',
  r'''    CREATE TRIGGER trg_learning_completions_scope_family_update BEFORE UPDATE ON learning_completions WHEN NOT (EXISTS
    (   SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND (     (s.family = 'course' AND       ((NEW.policy_kind
    = 'legacyOnePass' AND NEW.threshold_percent = -1) OR        (NEW.policy_kind = 'discoveryThreshold' AND
       NEW.threshold_percent BETWEEN 1 AND 100))) OR     (s.family IN ('comparison', 'sentence-hunt') AND       NEW.policy_kind
    = 'discoveryThreshold' AND       NEW.threshold_percent BETWEEN 1 AND 100)   ) )) BEGIN   SELECT RAISE(ABORT,
    'trg_learning_completions_scope_family_update rejected row'); END;''',
  r'''    CREATE TRIGGER trg_learning_content_bindings_scope_family_insert BEFORE INSERT ON learning_content_bindings WHEN
    NOT (EXISTS (   SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND (     (s.family = 'course'
    AND NEW.section_fingerprint IS NULL AND       NEW.annotation_hash IS NULL AND NEW.annotation_revision IS NULL)
    OR     (s.family = 'comparison' AND NEW.catalogue_fingerprint IS NULL AND       NEW.annotation_hash IS NULL AND
    NEW.annotation_revision IS NULL) OR     (s.family = 'sentence-hunt' AND NEW.catalogue_fingerprint IS NULL AND
          NEW.section_fingerprint IS NOT NULL AND NEW.annotation_hash IS NULL AND       NEW.annotation_revision IS
    NULL)   ) )) BEGIN   SELECT RAISE(ABORT, 'trg_learning_content_bindings_scope_family_insert rejected row'); END;''',
  r'''    CREATE TRIGGER trg_learning_content_bindings_scope_family_update BEFORE UPDATE ON learning_content_bindings WHEN
    NOT (EXISTS (   SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND (     (s.family = 'course'
    AND NEW.section_fingerprint IS NULL AND       NEW.annotation_hash IS NULL AND NEW.annotation_revision IS NULL)
    OR     (s.family = 'comparison' AND NEW.catalogue_fingerprint IS NULL AND       NEW.annotation_hash IS NULL AND
    NEW.annotation_revision IS NULL) OR     (s.family = 'sentence-hunt' AND NEW.catalogue_fingerprint IS NULL AND
          NEW.section_fingerprint IS NOT NULL AND NEW.annotation_hash IS NULL AND       NEW.annotation_revision IS
    NULL)   ) )) BEGIN   SELECT RAISE(ABORT, 'trg_learning_content_bindings_scope_family_update rejected row'); END;''',
  r'''    CREATE TRIGGER trg_learning_exposure_scope_family_insert BEFORE INSERT ON learning_exposure WHEN NOT (EXISTS
    (SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND s.family = NEW.family AND     s.family IN
    ('course', 'sentence-hunt'))) BEGIN   SELECT RAISE(ABORT, 'trg_learning_exposure_scope_family_insert rejected row');
    END;''',
  r'''    CREATE TRIGGER trg_learning_exposure_scope_family_update BEFORE UPDATE ON learning_exposure WHEN NOT (EXISTS
    (SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND s.family = NEW.family AND     s.family IN
    ('course', 'sentence-hunt'))) BEGIN   SELECT RAISE(ABORT, 'trg_learning_exposure_scope_family_update rejected row');
    END;''',
  r'''    CREATE TRIGGER trg_learning_mistakes_scope_family_insert BEFORE INSERT ON learning_mistakes WHEN NOT (EXISTS
    (SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND s.family = NEW.family)) BEGIN   SELECT RAISE(ABORT,
    'trg_learning_mistakes_scope_family_insert rejected row'); END;''',
  r'''    CREATE TRIGGER trg_learning_mistakes_scope_family_update BEFORE UPDATE ON learning_mistakes WHEN NOT (EXISTS
    (SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND s.family = NEW.family)) BEGIN   SELECT RAISE(ABORT,
    'trg_learning_mistakes_scope_family_update rejected row'); END;''',
  r'''    CREATE TRIGGER trg_learning_runs_scope_binding_family_insert BEFORE INSERT ON learning_runs WHEN NOT (EXISTS
    (   SELECT 1 FROM learning_scopes AS s   JOIN learning_content_bindings AS b     ON b.scope_id = s.id AND b.id
    = NEW.content_binding_id   WHERE s.id = NEW.scope_id AND b.activity_id = NEW.activity_id AND (     (s.family
    = 'course' AND NEW.activity_kind IN       ('discovery', 'legacyLesson', 'drill', 'soundGame', 'wordGame') AND
          NEW.run_mode IS NULL AND NEW.run_start_round IS NULL) OR     (s.family = 'comparison' AND NEW.activity_kind
    = 'comparison' AND       NEW.run_mode IS NULL AND NEW.session_id IS NOT NULL AND       NEW.policy_revision IS
    NOT NULL AND NEW.threshold_percent IS NOT NULL AND       NEW.run_start_round IS NULL) OR     (s.family = 'sentence-hunt'
    AND NEW.activity_kind = 'sentence-hunt' AND       NEW.run_mode IN ('practice', 'reviewOnly') AND       NEW.session_id
    IS NOT NULL AND NEW.policy_revision IS NOT NULL AND       NEW.threshold_percent IS NOT NULL AND NEW.run_start_round
    IS NOT NULL)   ) )) BEGIN   SELECT RAISE(ABORT, 'trg_learning_runs_scope_binding_family_insert rejected row');
    END;''',
  r'''    CREATE TRIGGER trg_learning_runs_scope_binding_family_update BEFORE UPDATE ON learning_runs WHEN NOT (EXISTS
    (   SELECT 1 FROM learning_scopes AS s   JOIN learning_content_bindings AS b     ON b.scope_id = s.id AND b.id
    = NEW.content_binding_id   WHERE s.id = NEW.scope_id AND b.activity_id = NEW.activity_id AND (     (s.family
    = 'course' AND NEW.activity_kind IN       ('discovery', 'legacyLesson', 'drill', 'soundGame', 'wordGame') AND
          NEW.run_mode IS NULL AND NEW.run_start_round IS NULL) OR     (s.family = 'comparison' AND NEW.activity_kind
    = 'comparison' AND       NEW.run_mode IS NULL AND NEW.session_id IS NOT NULL AND       NEW.policy_revision IS
    NOT NULL AND NEW.threshold_percent IS NOT NULL AND       NEW.run_start_round IS NULL) OR     (s.family = 'sentence-hunt'
    AND NEW.activity_kind = 'sentence-hunt' AND       NEW.run_mode IN ('practice', 'reviewOnly') AND       NEW.session_id
    IS NOT NULL AND NEW.policy_revision IS NOT NULL AND       NEW.threshold_percent IS NOT NULL AND NEW.run_start_round
    IS NOT NULL)   ) )) BEGIN   SELECT RAISE(ABORT, 'trg_learning_runs_scope_binding_family_update rejected row');
    END;''',
  r'''    CREATE TRIGGER trg_learning_scopes_identity_immutable_update BEFORE UPDATE OF owner_kind, owner_id, course_id,
    family ON learning_scopes WHEN OLD.owner_kind IS NOT NEW.owner_kind OR OLD.owner_id IS NOT NEW.owner_id OR
    OLD.course_id IS NOT NEW.course_id OR OLD.family IS NOT NEW.family BEGIN   SELECT RAISE(ABORT, 'learning scope identity is immutable');
    END;''',
  r'''    CREATE TRIGGER trg_learning_summaries_scope_family_insert BEFORE INSERT ON learning_summaries WHEN NOT (EXISTS
    (SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND s.family = NEW.family)) BEGIN   SELECT RAISE(ABORT,
    'trg_learning_summaries_scope_family_insert rejected row'); END;''',
  r'''    CREATE TRIGGER trg_learning_summaries_scope_family_update BEFORE UPDATE ON learning_summaries WHEN NOT (EXISTS
    (SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND s.family = NEW.family)) BEGIN   SELECT RAISE(ABORT,
    'trg_learning_summaries_scope_family_update rejected row'); END;''',
  r'''    CREATE TRIGGER trg_supported_sync_outbox_account_course_insert BEFORE INSERT ON supported_sync_outbox WHEN NOT
    (EXISTS (   SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND s.owner_kind = 'account' AND
       s.family = 'course' AND s.owner_id = NEW.user_id AND     s.course_id = NEW.course_id )) BEGIN   SELECT RAISE(ABORT,
    'trg_supported_sync_outbox_account_course_insert rejected row'); END;''',
  r'''    CREATE TRIGGER trg_supported_sync_outbox_account_course_update BEFORE UPDATE ON supported_sync_outbox WHEN NOT
    (EXISTS (   SELECT 1 FROM learning_scopes AS s   WHERE s.id = NEW.scope_id AND s.owner_kind = 'account' AND
       s.family = 'course' AND s.owner_id = NEW.user_id AND     s.course_id = NEW.course_id )) BEGIN   SELECT RAISE(ABORT,
    'trg_supported_sync_outbox_account_course_update rejected row'); END;''',
];
