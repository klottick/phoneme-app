import 'package:drift/drift.dart';

const int learningMaxSafeInteger = 9007199254740991;

class LearningScopes extends Table {
  @override
  bool get dontWriteConstraints => true;

  @override
  Set<Column> get primaryKey => <Column>{id};

  IntColumn get id => integer().nullable()();
  TextColumn get ownerKind => text()();
  TextColumn get ownerId => text()();
  TextColumn get courseId => text()();
  TextColumn get family => text()();
  IntColumn get schemaVersion => integer()();
  IntColumn get revision => integer()();
  IntColumn get commitOrdinal => integer()();
  TextColumn get availabilityState => text()();

  @override
  List<String> get customConstraints => const <String>[
    'PRIMARY KEY (id)',
    "CHECK((id IS NULL OR typeof(id) = 'integer') AND typeof(owner_kind) = 'text' AND typeof(owner_id) = 'text' AND typeof(course_id) = 'text' AND typeof(family) = 'text' AND typeof(schema_version) = 'integer' AND typeof(revision) = 'integer' AND typeof(commit_ordinal) = 'integer' AND typeof(availability_state) = 'text')",
    "CHECK(owner_kind IN ('guest', 'account'))",
    "CHECK((owner_kind='guest' AND owner_id='') OR "
        "(owner_kind='account' AND length(trim(owner_id))>0))",
    'CHECK(length(trim(course_id)) > 0)',
    "CHECK(family IN ('course', 'comparison', 'sentence-hunt'))",
    'CHECK(schema_version BETWEEN 1 AND 9007199254740991)',
    'CHECK(revision BETWEEN 0 AND 9007199254740991)',
    'CHECK(commit_ordinal BETWEEN 0 AND 9007199254740991)',
    'CHECK(commit_ordinal <= revision)',
    "CHECK(availability_state IN ('available', 'unavailable'))",
  ];
}

class LearningContentBindings extends Table {
  @override
  bool get dontWriteConstraints => true;

  @override
  Set<Column> get primaryKey => <Column>{id};

  IntColumn get id => integer().nullable()();
  IntColumn get scopeId =>
      integer().references(LearningScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get activityId => text()();
  IntColumn get contentRevision => integer()();
  TextColumn get policyKind => text().nullable()();
  IntColumn get policyRevision => integer().nullable()();
  TextColumn get catalogueFingerprint => text().nullable()();
  TextColumn get sectionFingerprint => text().nullable()();
  TextColumn get annotationHash => text().nullable()();
  IntColumn get annotationRevision => integer().nullable()();

  @override
  List<String> get customConstraints => const <String>[
    'PRIMARY KEY (id)',
    "CHECK((id IS NULL OR typeof(id) = 'integer') AND typeof(scope_id) = 'integer' AND typeof(activity_id) = 'text' AND typeof(content_revision) = 'integer' AND (policy_kind IS NULL OR typeof(policy_kind) = 'text') AND (policy_revision IS NULL OR typeof(policy_revision) = 'integer') AND (catalogue_fingerprint IS NULL OR typeof(catalogue_fingerprint) = 'text') AND (section_fingerprint IS NULL OR typeof(section_fingerprint) = 'text') AND (annotation_hash IS NULL OR typeof(annotation_hash) = 'text') AND (annotation_revision IS NULL OR typeof(annotation_revision) = 'integer'))",
    'CHECK(length(trim(activity_id)) > 0)',
    'CHECK(content_revision BETWEEN 1 AND 9007199254740991)',
    'CHECK(policy_kind IS NULL OR policy_kind IN '
        "('discoveryThreshold', 'legacyOnePass'))",
    'CHECK(policy_revision IS NULL OR policy_revision BETWEEN 1 AND 9007199254740991)',
    'CHECK((policy_kind IS NULL) = (policy_revision IS NULL))',
    'CHECK(catalogue_fingerprint IS NULL OR length(trim(catalogue_fingerprint)) > 0)',
    'CHECK(section_fingerprint IS NULL OR length(trim(section_fingerprint)) > 0)',
    'CHECK(annotation_hash IS NULL OR length(trim(annotation_hash)) > 0)',
    'CHECK(annotation_revision IS NULL OR annotation_revision BETWEEN 1 AND 9007199254740991)',
    'CHECK((annotation_hash IS NULL) = (annotation_revision IS NULL))',
  ];
}

class LearningRuns extends Table {
  IntColumn get scopeId =>
      integer().references(LearningScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get activityId => text()();
  TextColumn get activityKind => text()();
  IntColumn get runGeneration => integer()();
  IntColumn get sequence => integer()();
  IntColumn get cursorRevision => integer()();
  IntColumn get contentBindingId => integer().references(
    LearningContentBindings,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get runMode => text().nullable()();
  IntColumn get finished => integer()();
  TextColumn get sessionId => text().nullable()();
  IntColumn get policyRevision => integer().nullable()();
  IntColumn get thresholdPercent => integer().nullable()();
  IntColumn get runStartRound => integer().nullable()();
  TextColumn get checkpointJson => text()();
  TextColumn get latestReceiptToken => text()();
  TextColumn get latestReceiptPayload => text()();
  IntColumn get latestReceiptBeforeGeneration => integer()();
  IntColumn get latestReceiptBeforeSequence => integer()();
  IntColumn get latestReceiptBeforeCursorRevision => integer()();
  IntColumn get latestReceiptCommitOrdinal => integer()();

  @override
  List<String> get customConstraints => const <String>[
    "CHECK(typeof(scope_id) = 'integer' AND typeof(activity_id) = 'text' AND typeof(activity_kind) = 'text' AND typeof(run_generation) = 'integer' AND typeof(sequence) = 'integer' AND typeof(cursor_revision) = 'integer' AND typeof(content_binding_id) = 'integer' AND (run_mode IS NULL OR typeof(run_mode) = 'text') AND typeof(finished) = 'integer' AND (session_id IS NULL OR typeof(session_id) = 'text') AND (policy_revision IS NULL OR typeof(policy_revision) = 'integer') AND (threshold_percent IS NULL OR typeof(threshold_percent) = 'integer') AND (run_start_round IS NULL OR typeof(run_start_round) = 'integer') AND typeof(checkpoint_json) = 'text' AND typeof(latest_receipt_token) = 'text' AND typeof(latest_receipt_payload) = 'text' AND typeof(latest_receipt_before_generation) = 'integer' AND typeof(latest_receipt_before_sequence) = 'integer' AND typeof(latest_receipt_before_cursor_revision) = 'integer' AND typeof(latest_receipt_commit_ordinal) = 'integer')",
    'CHECK(length(trim(activity_id)) > 0)',
    "CHECK(activity_kind IN ('discovery', 'legacyLesson', 'drill', 'soundGame', 'wordGame', 'comparison', 'sentence-hunt'))",
    'CHECK(run_generation BETWEEN 1 AND 9007199254740991)',
    'CHECK(sequence BETWEEN 1 AND 9007199254740991)',
    'CHECK(cursor_revision BETWEEN 0 AND 9007199254740991)',
    'CHECK(finished IN (0, 1))',
    "CHECK(run_mode IS NULL OR run_mode IN ('practice', 'reviewOnly'))",
    'CHECK(session_id IS NULL OR length(trim(session_id)) > 0)',
    'CHECK(policy_revision IS NULL OR policy_revision BETWEEN 1 AND 9007199254740991)',
    'CHECK(threshold_percent IS NULL OR threshold_percent BETWEEN 1 AND 100)',
    'CHECK(run_start_round IS NULL OR run_start_round BETWEEN 1 AND 9007199254740991)',
    'CHECK(json_valid(checkpoint_json) AND json_type(checkpoint_json) = \'object\')',
    'CHECK(length(checkpoint_json) > 1)',
    'CHECK(length(latest_receipt_token) = 22 AND latest_receipt_token NOT GLOB \'*[^A-Za-z0-9_-]*\')',
    "CHECK(json_valid(latest_receipt_payload) AND json_type(latest_receipt_payload) = 'object')",
    r"CHECK(json_type(latest_receipt_payload, '$.activityId') IS 'text' AND json_extract(latest_receipt_payload, '$.activityId') = activity_id)",
    "CHECK(json_type(latest_receipt_payload, '\$.expectedScopeRevision') IS 'integer' AND json_extract(latest_receipt_payload, '\$.expectedScopeRevision') BETWEEN 0 AND $learningMaxSafeInteger)",
    'CHECK(latest_receipt_before_generation BETWEEN 0 AND 9007199254740991)',
    'CHECK(latest_receipt_before_sequence BETWEEN 0 AND 9007199254740991)',
    'CHECK(latest_receipt_before_cursor_revision BETWEEN 0 AND 9007199254740991)',
    'CHECK(latest_receipt_commit_ordinal BETWEEN 1 AND 9007199254740991)',
  ];
}

class LearningAttempts extends Table {
  IntColumn get scopeId =>
      integer().references(LearningScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get attemptId => text()();
  TextColumn get activityId => text()();
  IntColumn get runGeneration => integer()();
  IntColumn get commandSequence => integer()();
  IntColumn get batchIndex => integer()();
  TextColumn get itemId => text().nullable()();
  IntColumn get itemOccurrence => integer().nullable()();
  IntColumn get contentRevision => integer()();
  IntColumn get commitOrdinal => integer()();
  IntColumn get answeredAtUs => integer()();
  IntColumn get committedAtUs => integer()();
  TextColumn get answerKind => text()();
  IntColumn get correct => integer()();
  TextColumn get skill => text().nullable()();
  TextColumn get origin => text().nullable()();
  TextColumn get presentation => text().nullable()();
  IntColumn get assistanceMask => integer().nullable()();
  TextColumn get contentState => text().nullable()();
  TextColumn get audioSource => text().nullable()();
  IntColumn get round => integer().nullable()();
  IntColumn get afterDebrief => integer().nullable()();
  IntColumn get teachingExposed => integer().nullable()();
  TextColumn get selectedRelation => text().nullable()();
  TextColumn get expectedRelation => text().nullable()();
  TextColumn get sectionId => text().nullable()();
  TextColumn get sentenceId => text().nullable()();
  TextColumn get annotationHash => text().nullable()();
  IntColumn get annotationRevision => integer().nullable()();

  @override
  List<String> get customConstraints => const <String>[
    "CHECK(typeof(scope_id) = 'integer' AND typeof(attempt_id) = 'text' AND typeof(activity_id) = 'text' AND typeof(run_generation) = 'integer' AND typeof(command_sequence) = 'integer' AND typeof(batch_index) = 'integer' AND (item_id IS NULL OR typeof(item_id) = 'text') AND (item_occurrence IS NULL OR typeof(item_occurrence) = 'integer') AND typeof(content_revision) = 'integer' AND typeof(commit_ordinal) = 'integer' AND typeof(answered_at_us) = 'integer' AND typeof(committed_at_us) = 'integer' AND typeof(answer_kind) = 'text' AND typeof(correct) = 'integer' AND (skill IS NULL OR typeof(skill) = 'text') AND (origin IS NULL OR typeof(origin) = 'text') AND (presentation IS NULL OR typeof(presentation) = 'text') AND (assistance_mask IS NULL OR typeof(assistance_mask) = 'integer') AND (content_state IS NULL OR typeof(content_state) = 'text') AND (audio_source IS NULL OR typeof(audio_source) = 'text') AND (round IS NULL OR typeof(round) = 'integer') AND (after_debrief IS NULL OR typeof(after_debrief) = 'integer') AND (teaching_exposed IS NULL OR typeof(teaching_exposed) = 'integer') AND (selected_relation IS NULL OR typeof(selected_relation) = 'text') AND (expected_relation IS NULL OR typeof(expected_relation) = 'text') AND (section_id IS NULL OR typeof(section_id) = 'text') AND (sentence_id IS NULL OR typeof(sentence_id) = 'text') AND (annotation_hash IS NULL OR typeof(annotation_hash) = 'text') AND (annotation_revision IS NULL OR typeof(annotation_revision) = 'integer'))",
    'CHECK(length(trim(attempt_id)) > 0)',
    'CHECK(length(trim(activity_id)) > 0)',
    'CHECK(run_generation BETWEEN 1 AND 9007199254740991)',
    'CHECK(command_sequence BETWEEN 1 AND 9007199254740991)',
    'CHECK(batch_index BETWEEN 0 AND 9007199254740991)',
    'CHECK(item_id IS NULL OR length(trim(item_id)) > 0)',
    'CHECK(item_occurrence IS NULL OR item_occurrence BETWEEN 1 AND 9007199254740991)',
    'CHECK(content_revision BETWEEN 1 AND 9007199254740991)',
    'CHECK(commit_ordinal BETWEEN 1 AND 9007199254740991)',
    'CHECK(answered_at_us BETWEEN 0 AND 9007199254740991)',
    'CHECK(committed_at_us BETWEEN 0 AND 9007199254740991)',
    "CHECK(answer_kind IN ('soundChoice', 'drillChoice', 'soundCue', 'wordTile', 'comparisonPair', 'sentenceHunt'))",
    'CHECK(correct IN (0, 1))',
    "CHECK(skill IS NULL OR skill IN ('listening', 'spelling'))",
    "CHECK(origin IS NULL OR origin IN ('practice', 'game'))",
    "CHECK(presentation IS NULL OR presentation IN ('firstInRun', 'repeatInRun'))",
    'CHECK(assistance_mask IS NULL OR assistance_mask BETWEEN 0 AND 15)',
    "CHECK(content_state IS NULL OR content_state IN ('existingCurated', 'pending', 'reviewed'))",
    "CHECK(audio_source IS NULL OR audio_source IN ('pendingRecording', 'practiceSpeech', 'notApplicable'))",
    'CHECK(round IS NULL OR round BETWEEN 1 AND 9007199254740991)',
    'CHECK(after_debrief IS NULL OR after_debrief IN (0, 1))',
    'CHECK(teaching_exposed IS NULL OR teaching_exposed IN (0, 1))',
    "CHECK(selected_relation IS NULL OR selected_relation IN ('same', 'different'))",
    "CHECK(expected_relation IS NULL OR expected_relation IN ('same', 'different'))",
    'CHECK(section_id IS NULL OR length(trim(section_id)) > 0)',
    'CHECK(sentence_id IS NULL OR length(trim(sentence_id)) > 0)',
    'CHECK(annotation_hash IS NULL OR length(trim(annotation_hash)) > 0)',
    'CHECK(annotation_revision IS NULL OR annotation_revision BETWEEN 1 AND 9007199254740991)',
  ];
}

class LearningAttemptValues extends Table {
  IntColumn get scopeId =>
      integer().references(LearningScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get attemptId => text()();
  TextColumn get field => text()();
  IntColumn get ordinal => integer()();
  TextColumn get valueType => text()();
  TextColumn get textValue => text().nullable()();
  IntColumn get intValue => integer().nullable()();
  IntColumn get boolValue => integer().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{scopeId, attemptId, field, ordinal};

  @override
  List<String> get customConstraints => const <String>[
    'FOREIGN KEY (scope_id, attempt_id) REFERENCES learning_attempts(scope_id, attempt_id) ON DELETE RESTRICT',
    "CHECK(typeof(scope_id) = 'integer' AND typeof(attempt_id) = 'text' AND typeof(field) = 'text' AND typeof(ordinal) = 'integer' AND typeof(value_type) = 'text' AND (text_value IS NULL OR typeof(text_value) = 'text') AND (int_value IS NULL OR typeof(int_value) = 'integer') AND (bool_value IS NULL OR typeof(bool_value) = 'integer'))",
    'CHECK(length(trim(attempt_id)) > 0)',
    "CHECK(field IN ('selected_sound', 'expected_sound', 'choice', 'selected_word', 'expected_word', 'pair_id', 'selected_family', 'expected_family', 'word_id', 'tile_index', 'target_sound', 'expected_membership', 'selected_token_id', 'expected_token_id'))",
    'CHECK(ordinal BETWEEN 0 AND 9007199254740991)',
    "CHECK((value_type = 'text' AND text_value IS NOT NULL AND length(trim(text_value)) > 0 AND int_value IS NULL AND bool_value IS NULL) OR "
        "(value_type = 'int' AND text_value IS NULL AND int_value IS NOT NULL AND int_value BETWEEN 0 AND $learningMaxSafeInteger AND bool_value IS NULL) OR "
        "(value_type = 'bool' AND text_value IS NULL AND int_value IS NULL AND bool_value IS NOT NULL AND bool_value IN (0, 1)))",
    "CHECK((field = 'expected_membership' AND value_type = 'bool' AND bool_value IS NOT NULL) OR "
        "(field = 'tile_index' AND value_type = 'int' AND int_value IS NOT NULL AND int_value BETWEEN 0 AND 15) OR "
        "(field IN ('selected_sound', 'expected_sound', 'choice', 'selected_word', 'expected_word', 'pair_id', 'selected_family', 'expected_family', 'word_id', 'target_sound', 'selected_token_id', 'expected_token_id') AND value_type = 'text' AND text_value IS NOT NULL))",
  ];
}

class LearningAttemptEvidence extends Table {
  IntColumn get scopeId =>
      integer().references(LearningScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get attemptId => text()();
  IntColumn get evidenceIndex => integer()();
  TextColumn get evidenceKind => text()();
  TextColumn get slot => text().nullable()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get outcome => text().nullable()();
  TextColumn get source => text().nullable()();
  TextColumn get activityId => text().nullable()();
  IntColumn get runGeneration => integer().nullable()();
  IntColumn get round => integer().nullable()();
  TextColumn get pairId => text().nullable()();
  IntColumn get uiGeneration => integer().nullable()();
  TextColumn get sectionId => text().nullable()();
  TextColumn get itemId => text().nullable()();
  TextColumn get sentenceId => text().nullable()();
  TextColumn get audioRefId => text().nullable()();
  TextColumn get annotationHash => text().nullable()();
  IntColumn get annotationRevision => integer().nullable()();
  IntColumn get contentRevision => integer().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{scopeId, attemptId, evidenceIndex};

  @override
  List<String> get customConstraints => const <String>[
    'FOREIGN KEY (scope_id, attempt_id) REFERENCES learning_attempts(scope_id, attempt_id) ON DELETE RESTRICT',
    "CHECK(typeof(scope_id) = 'integer' AND typeof(attempt_id) = 'text' AND typeof(evidence_index) = 'integer' AND typeof(evidence_kind) = 'text' AND (slot IS NULL OR typeof(slot) = 'text') AND (reference_id IS NULL OR typeof(reference_id) = 'text') AND (outcome IS NULL OR typeof(outcome) = 'text') AND (source IS NULL OR typeof(source) = 'text') AND (activity_id IS NULL OR typeof(activity_id) = 'text') AND (run_generation IS NULL OR typeof(run_generation) = 'integer') AND (round IS NULL OR typeof(round) = 'integer') AND (pair_id IS NULL OR typeof(pair_id) = 'text') AND (ui_generation IS NULL OR typeof(ui_generation) = 'integer') AND (section_id IS NULL OR typeof(section_id) = 'text') AND (item_id IS NULL OR typeof(item_id) = 'text') AND (sentence_id IS NULL OR typeof(sentence_id) = 'text') AND (audio_ref_id IS NULL OR typeof(audio_ref_id) = 'text') AND (annotation_hash IS NULL OR typeof(annotation_hash) = 'text') AND (annotation_revision IS NULL OR typeof(annotation_revision) = 'integer') AND (content_revision IS NULL OR typeof(content_revision) = 'integer'))",
    'CHECK(length(trim(attempt_id)) > 0)',
    "CHECK(evidence_kind IN ('comparisonPlayback', 'sentencePlayback', 'sentenceContent'))",
    'CHECK(evidence_index BETWEEN 0 AND 9007199254740991)',
    "CHECK(slot IS NULL OR slot IN ('a', 'b'))",
    'CHECK(reference_id IS NULL OR length(trim(reference_id)) > 0)',
    "CHECK(outcome IS NULL OR outcome IN ('completed', 'cancelled', 'failed'))",
    "CHECK(source IS NULL OR source IN ('unverifiedRecording', 'reviewedRecording', 'practiceTts'))",
    'CHECK(activity_id IS NULL OR length(trim(activity_id)) > 0)',
    'CHECK(run_generation IS NULL OR run_generation BETWEEN 1 AND 9007199254740991)',
    'CHECK(round IS NULL OR round BETWEEN 1 AND 9007199254740991)',
    'CHECK(pair_id IS NULL OR length(trim(pair_id)) > 0)',
    'CHECK(ui_generation IS NULL OR ui_generation BETWEEN 0 AND 9007199254740991)',
    'CHECK(section_id IS NULL OR length(trim(section_id)) > 0)',
    'CHECK(item_id IS NULL OR length(trim(item_id)) > 0)',
    'CHECK(sentence_id IS NULL OR length(trim(sentence_id)) > 0)',
    'CHECK(audio_ref_id IS NULL OR length(trim(audio_ref_id)) > 0)',
    'CHECK(annotation_hash IS NULL OR length(trim(annotation_hash)) > 0)',
    'CHECK(annotation_revision IS NULL OR annotation_revision BETWEEN 1 AND 9007199254740991)',
    'CHECK(content_revision IS NULL OR content_revision BETWEEN 1 AND 9007199254740991)',
  ];
}

class LearningCommandReceipts extends Table {
  IntColumn get scopeId =>
      integer().references(LearningScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get activityId => text()();
  TextColumn get token => text()();
  TextColumn get canonicalPayload => text()();
  IntColumn get beforeGeneration => integer()();
  IntColumn get beforeSequence => integer()();
  IntColumn get beforeCursorRevision => integer()();
  IntColumn get afterGeneration => integer()();
  IntColumn get afterSequence => integer()();
  IntColumn get afterCursorRevision => integer()();
  IntColumn get commitOrdinal => integer()();
  TextColumn get resultActivityId => text()();
  IntColumn get resultGeneration => integer()();
  IntColumn get resultSequence => integer()();
  IntColumn get resultCursorRevision => integer()();

  @override
  List<String> get customConstraints => const <String>[
    "CHECK(typeof(scope_id) = 'integer' AND typeof(activity_id) = 'text' AND typeof(token) = 'text' AND typeof(canonical_payload) = 'text' AND typeof(before_generation) = 'integer' AND typeof(before_sequence) = 'integer' AND typeof(before_cursor_revision) = 'integer' AND typeof(after_generation) = 'integer' AND typeof(after_sequence) = 'integer' AND typeof(after_cursor_revision) = 'integer' AND typeof(commit_ordinal) = 'integer' AND typeof(result_activity_id) = 'text' AND typeof(result_generation) = 'integer' AND typeof(result_sequence) = 'integer' AND typeof(result_cursor_revision) = 'integer')",
    'CHECK(length(trim(activity_id)) > 0)',
    'CHECK(length(token) = 22 AND token NOT GLOB \'*[^A-Za-z0-9_-]*\')',
    "CHECK(json_valid(canonical_payload) AND json_type(canonical_payload) = 'object')",
    r"CHECK(json_type(canonical_payload, '$.activityId') IS 'text' AND json_extract(canonical_payload, '$.activityId') = activity_id)",
    "CHECK(json_type(canonical_payload, '\$.expectedScopeRevision') IS 'integer' AND json_extract(canonical_payload, '\$.expectedScopeRevision') BETWEEN 0 AND $learningMaxSafeInteger)",
    'CHECK(before_generation BETWEEN 0 AND 9007199254740991)',
    'CHECK(before_sequence BETWEEN 0 AND 9007199254740991)',
    'CHECK(before_cursor_revision BETWEEN 0 AND 9007199254740991)',
    'CHECK(after_generation BETWEEN 1 AND 9007199254740991)',
    'CHECK(after_sequence BETWEEN 1 AND 9007199254740991)',
    'CHECK(after_cursor_revision BETWEEN 0 AND 9007199254740991)',
    'CHECK(commit_ordinal BETWEEN 1 AND 9007199254740991)',
    'CHECK(length(trim(result_activity_id)) > 0)',
    'CHECK(result_activity_id = activity_id)',
    'CHECK(result_generation BETWEEN 1 AND 9007199254740991)',
    'CHECK(result_sequence BETWEEN 1 AND 9007199254740991)',
    'CHECK(result_cursor_revision BETWEEN 0 AND 9007199254740991)',
    'CHECK(result_generation = after_generation AND result_sequence = after_sequence AND result_cursor_revision = after_cursor_revision)',
  ];
}

class LearningMistakes extends Table {
  IntColumn get scopeId =>
      integer().references(LearningScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get family => text()();
  TextColumn get activityId => text().nullable()();
  TextColumn get itemId => text().nullable()();
  TextColumn get targetSound => text().nullable()();
  TextColumn get skill => text().nullable()();
  TextColumn get pairId => text().nullable()();
  TextColumn get sectionId => text().nullable()();
  TextColumn get sentenceId => text().nullable()();
  TextColumn get audioRefId => text().nullable()();
  TextColumn get annotationHash => text().nullable()();
  IntColumn get annotationRevision => integer().nullable()();
  IntColumn get contentRevision => integer()();
  TextColumn get firstWrongAttemptId => text().nullable()();
  TextColumn get latestWrongAttemptId => text().nullable()();
  IntColumn get firstWrongAtUs => integer()();
  IntColumn get latestWrongAtUs => integer()();
  IntColumn get failureCount => integer()();
  IntColumn get lastRunGeneration => integer().nullable()();

  @override
  List<String> get customConstraints => const <String>[
    "CHECK(typeof(scope_id) = 'integer' AND typeof(family) = 'text' AND (activity_id IS NULL OR typeof(activity_id) = 'text') AND (item_id IS NULL OR typeof(item_id) = 'text') AND (target_sound IS NULL OR typeof(target_sound) = 'text') AND (skill IS NULL OR typeof(skill) = 'text') AND (pair_id IS NULL OR typeof(pair_id) = 'text') AND (section_id IS NULL OR typeof(section_id) = 'text') AND (sentence_id IS NULL OR typeof(sentence_id) = 'text') AND (audio_ref_id IS NULL OR typeof(audio_ref_id) = 'text') AND (annotation_hash IS NULL OR typeof(annotation_hash) = 'text') AND (annotation_revision IS NULL OR typeof(annotation_revision) = 'integer') AND typeof(content_revision) = 'integer' AND (first_wrong_attempt_id IS NULL OR typeof(first_wrong_attempt_id) = 'text') AND (latest_wrong_attempt_id IS NULL OR typeof(latest_wrong_attempt_id) = 'text') AND typeof(first_wrong_at_us) = 'integer' AND typeof(latest_wrong_at_us) = 'integer' AND typeof(failure_count) = 'integer' AND (last_run_generation IS NULL OR typeof(last_run_generation) = 'integer'))",
    "CHECK(family IN ('course', 'comparison', 'sentence-hunt'))",
    'CHECK(activity_id IS NULL OR length(trim(activity_id)) > 0)',
    'CHECK(item_id IS NULL OR length(trim(item_id)) > 0)',
    'CHECK(target_sound IS NULL OR length(trim(target_sound)) > 0)',
    "CHECK(skill IS NULL OR skill IN ('listening', 'spelling'))",
    'CHECK(pair_id IS NULL OR length(trim(pair_id)) > 0)',
    'CHECK(section_id IS NULL OR length(trim(section_id)) > 0)',
    'CHECK(sentence_id IS NULL OR length(trim(sentence_id)) > 0)',
    'CHECK(audio_ref_id IS NULL OR length(trim(audio_ref_id)) > 0)',
    'CHECK(annotation_hash IS NULL OR length(trim(annotation_hash)) > 0)',
    'CHECK(annotation_revision IS NULL OR annotation_revision BETWEEN 1 AND 9007199254740991)',
    'CHECK(content_revision BETWEEN 1 AND 9007199254740991)',
    'CHECK(first_wrong_attempt_id IS NULL OR length(trim(first_wrong_attempt_id)) > 0)',
    'CHECK(latest_wrong_attempt_id IS NULL OR length(trim(latest_wrong_attempt_id)) > 0)',
    'CHECK(first_wrong_at_us BETWEEN 0 AND 9007199254740991)',
    'CHECK(latest_wrong_at_us BETWEEN first_wrong_at_us AND 9007199254740991)',
    'CHECK(failure_count BETWEEN 1 AND 9007199254740991)',
    'CHECK(last_run_generation IS NULL OR last_run_generation BETWEEN 1 AND 9007199254740991)',
    "CHECK((family = 'course' AND activity_id IS NOT NULL AND item_id IS NOT NULL AND target_sound IS NOT NULL AND skill IS NOT NULL AND pair_id IS NULL AND section_id IS NULL AND sentence_id IS NULL AND audio_ref_id IS NULL AND annotation_hash IS NULL AND annotation_revision IS NULL) OR (family = 'comparison' AND activity_id IS NOT NULL AND pair_id IS NOT NULL AND content_revision > 0 AND item_id IS NULL AND target_sound IS NULL AND skill IS NULL AND section_id IS NULL AND sentence_id IS NULL AND audio_ref_id IS NULL AND annotation_hash IS NULL AND annotation_revision IS NULL) OR (family = 'sentence-hunt' AND section_id IS NOT NULL AND item_id IS NOT NULL AND sentence_id IS NOT NULL AND audio_ref_id IS NOT NULL AND annotation_hash IS NOT NULL AND annotation_revision IS NOT NULL AND activity_id IS NULL AND target_sound IS NULL AND skill IS NULL AND pair_id IS NULL))",
  ];
}

class LearningSummaries extends Table {
  IntColumn get scopeId =>
      integer().references(LearningScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get family => text()();
  TextColumn get activityId => text().nullable()();
  TextColumn get sound => text().nullable()();
  TextColumn get skill => text().nullable()();
  TextColumn get origin => text().nullable()();
  TextColumn get presentation => text().nullable()();
  IntColumn get assistanceMask => integer().nullable()();
  TextColumn get pairId => text().nullable()();
  TextColumn get sectionId => text().nullable()();
  TextColumn get itemId => text().nullable()();
  TextColumn get sentenceId => text().nullable()();
  TextColumn get audioRefId => text().nullable()();
  TextColumn get annotationHash => text().nullable()();
  IntColumn get annotationRevision => integer().nullable()();
  IntColumn get contentRevision => integer().nullable()();
  TextColumn get bucket => text()();
  IntColumn get correct => integer()();
  IntColumn get total => integer()();

  @override
  List<String> get customConstraints => const <String>[
    "CHECK(typeof(scope_id) = 'integer' AND typeof(family) = 'text' AND (activity_id IS NULL OR typeof(activity_id) = 'text') AND (sound IS NULL OR typeof(sound) = 'text') AND (skill IS NULL OR typeof(skill) = 'text') AND (origin IS NULL OR typeof(origin) = 'text') AND (presentation IS NULL OR typeof(presentation) = 'text') AND (assistance_mask IS NULL OR typeof(assistance_mask) = 'integer') AND (pair_id IS NULL OR typeof(pair_id) = 'text') AND (section_id IS NULL OR typeof(section_id) = 'text') AND (item_id IS NULL OR typeof(item_id) = 'text') AND (sentence_id IS NULL OR typeof(sentence_id) = 'text') AND (audio_ref_id IS NULL OR typeof(audio_ref_id) = 'text') AND (annotation_hash IS NULL OR typeof(annotation_hash) = 'text') AND (annotation_revision IS NULL OR typeof(annotation_revision) = 'integer') AND (content_revision IS NULL OR typeof(content_revision) = 'integer') AND typeof(bucket) = 'text' AND typeof(correct) = 'integer' AND typeof(total) = 'integer')",
    "CHECK(family IN ('course', 'comparison', 'sentence-hunt'))",
    'CHECK(activity_id IS NULL OR length(trim(activity_id)) > 0)',
    'CHECK(sound IS NULL OR length(trim(sound)) > 0)',
    "CHECK(skill IS NULL OR skill IN ('listening', 'spelling'))",
    "CHECK(origin IS NULL OR origin IN ('practice', 'game'))",
    "CHECK(presentation IS NULL OR presentation IN ('firstInRun', 'repeatInRun'))",
    'CHECK(assistance_mask IS NULL OR assistance_mask BETWEEN 0 AND 15)',
    'CHECK(pair_id IS NULL OR length(trim(pair_id)) > 0)',
    'CHECK(section_id IS NULL OR length(trim(section_id)) > 0)',
    'CHECK(item_id IS NULL OR length(trim(item_id)) > 0)',
    'CHECK(sentence_id IS NULL OR length(trim(sentence_id)) > 0)',
    'CHECK(audio_ref_id IS NULL OR length(trim(audio_ref_id)) > 0)',
    'CHECK(annotation_hash IS NULL OR length(trim(annotation_hash)) > 0)',
    'CHECK(annotation_revision IS NULL OR annotation_revision BETWEEN 1 AND 9007199254740991)',
    'CHECK(content_revision IS NULL OR content_revision BETWEEN 1 AND 9007199254740991)',
    'CHECK(correct BETWEEN 0 AND 9007199254740991)',
    'CHECK(total BETWEEN 0 AND 9007199254740991 AND correct <= total)',
    "CHECK((family = 'course' AND sound IS NOT NULL AND skill IS NOT NULL AND origin IS NOT NULL AND presentation IS NOT NULL AND assistance_mask IS NOT NULL AND activity_id IS NULL AND content_revision IS NULL AND pair_id IS NULL AND section_id IS NULL AND item_id IS NULL AND sentence_id IS NULL AND audio_ref_id IS NULL AND annotation_hash IS NULL AND annotation_revision IS NULL AND bucket = 'all') OR (family = 'comparison' AND activity_id IS NOT NULL AND pair_id IS NOT NULL AND content_revision IS NOT NULL AND sound IS NULL AND skill IS NULL AND origin IS NULL AND presentation IS NULL AND assistance_mask IS NULL AND section_id IS NULL AND item_id IS NULL AND sentence_id IS NULL AND audio_ref_id IS NULL AND annotation_hash IS NULL AND annotation_revision IS NULL AND bucket IN ('firstInRun', 'repeatInRun', 'afterDebrief')) OR (family = 'sentence-hunt' AND section_id IS NOT NULL AND item_id IS NOT NULL AND sentence_id IS NOT NULL AND audio_ref_id IS NOT NULL AND annotation_hash IS NOT NULL AND annotation_revision IS NOT NULL AND content_revision IS NOT NULL AND activity_id IS NULL AND sound IS NULL AND skill IS NULL AND origin IS NULL AND presentation IS NULL AND assistance_mask IS NULL AND pair_id IS NULL AND bucket IN ('firstInRun', 'repeatInRun', 'firstTeachingExposed', 'repeatTeachingExposed'))) ",
  ];
}

class LearningCompletions extends Table {
  IntColumn get scopeId =>
      integer().references(LearningScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get activityId => text()();
  IntColumn get contentRevision => integer()();
  TextColumn get policyKind => text()();
  IntColumn get policyRevision => integer()();
  IntColumn get thresholdPercent => integer()();
  IntColumn get committedAtUs => integer()();

  @override
  List<String> get customConstraints => const <String>[
    "CHECK(typeof(scope_id) = 'integer' AND typeof(activity_id) = 'text' AND typeof(content_revision) = 'integer' AND typeof(policy_kind) = 'text' AND typeof(policy_revision) = 'integer' AND typeof(threshold_percent) = 'integer' AND typeof(committed_at_us) = 'integer')",
    'CHECK(length(trim(activity_id)) > 0)',
    'CHECK(content_revision BETWEEN 1 AND 9007199254740991)',
    "CHECK(policy_kind IN ('discoveryThreshold', 'legacyOnePass'))",
    'CHECK(policy_revision BETWEEN 1 AND 9007199254740991)',
    'CHECK(threshold_percent = -1 OR threshold_percent BETWEEN 1 AND 100)',
    'CHECK(committed_at_us BETWEEN 0 AND 9007199254740991)',
  ];
}

class LearningExposure extends Table {
  IntColumn get scopeId =>
      integer().references(LearningScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get family => text()();
  TextColumn get activityId => text().nullable()();
  TextColumn get itemId => text().nullable()();
  TextColumn get targetSound => text().nullable()();
  TextColumn get sectionId => text().nullable()();
  IntColumn get contentRevision => integer().nullable()();
  IntColumn get presentations => integer().nullable()();
  IntColumn get assistanceMask => integer().nullable()();

  @override
  List<String> get customConstraints => const <String>[
    "CHECK(typeof(scope_id) = 'integer' AND typeof(family) = 'text' AND (activity_id IS NULL OR typeof(activity_id) = 'text') AND (item_id IS NULL OR typeof(item_id) = 'text') AND (target_sound IS NULL OR typeof(target_sound) = 'text') AND (section_id IS NULL OR typeof(section_id) = 'text') AND (content_revision IS NULL OR typeof(content_revision) = 'integer') AND (presentations IS NULL OR typeof(presentations) = 'integer') AND (assistance_mask IS NULL OR typeof(assistance_mask) = 'integer'))",
    "CHECK((family = 'course' AND activity_id IS NOT NULL AND item_id IS NOT NULL AND target_sound IS NOT NULL AND section_id IS NULL AND content_revision IS NULL AND presentations IS NOT NULL AND presentations BETWEEN 0 AND $learningMaxSafeInteger AND assistance_mask IS NOT NULL AND assistance_mask BETWEEN 0 AND 15) OR "
        "(family = 'sentence-hunt' AND activity_id IS NULL AND item_id IS NULL AND target_sound IS NULL AND section_id IS NOT NULL AND content_revision IS NOT NULL AND content_revision BETWEEN 1 AND $learningMaxSafeInteger AND presentations IS NULL AND assistance_mask IS NULL))",
    'CHECK(activity_id IS NULL OR length(trim(activity_id)) > 0)',
    'CHECK(item_id IS NULL OR length(trim(item_id)) > 0)',
    'CHECK(target_sound IS NULL OR length(trim(target_sound)) > 0)',
    'CHECK(section_id IS NULL OR length(trim(section_id)) > 0)',
  ];
}

class LearningBestScores extends Table {
  IntColumn get scopeId =>
      integer().references(LearningScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get activityId => text()();
  IntColumn get score => integer()();

  @override
  Set<Column> get primaryKey => <Column>{scopeId, activityId};

  @override
  List<String> get customConstraints => const <String>[
    "CHECK(typeof(scope_id) = 'integer' AND typeof(activity_id) = 'text' AND typeof(score) = 'integer')",
    'CHECK(length(trim(activity_id)) > 0)',
    'CHECK(score BETWEEN 0 AND 9007199254740991)',
  ];
}

class SupportedSyncOutbox extends Table {
  IntColumn get scopeId =>
      integer().references(LearningScopes, #id, onDelete: KeyAction.restrict)();
  TextColumn get eventId => text()();
  IntColumn get enqueueCommitOrdinal => integer()();
  IntColumn get enqueueEventIndex => integer()();
  TextColumn get userId => text()();
  TextColumn get courseId => text()();
  TextColumn get kind => text()();
  TextColumn get sound => text().nullable()();
  TextColumn get skill => text().nullable()();
  IntColumn get correct => integer().nullable()();
  TextColumn get activity => text().nullable()();
  TextColumn get lessonId => text().nullable()();
  TextColumn get game => text().nullable()();
  IntColumn get score => integer().nullable()();

  @override
  List<String> get customConstraints => const <String>[
    "CHECK(typeof(scope_id) = 'integer' AND typeof(event_id) = 'text' AND typeof(enqueue_commit_ordinal) = 'integer' AND typeof(enqueue_event_index) = 'integer' AND typeof(user_id) = 'text' AND typeof(course_id) = 'text' AND typeof(kind) = 'text' AND (sound IS NULL OR typeof(sound) = 'text') AND (skill IS NULL OR typeof(skill) = 'text') AND (correct IS NULL OR typeof(correct) = 'integer') AND (activity IS NULL OR typeof(activity) = 'text') AND (lesson_id IS NULL OR typeof(lesson_id) = 'text') AND (game IS NULL OR typeof(game) = 'text') AND (score IS NULL OR typeof(score) = 'integer'))",
    'CHECK(length(trim(event_id)) > 0)',
    'CHECK(enqueue_commit_ordinal BETWEEN 1 AND 9007199254740991)',
    'CHECK(enqueue_event_index BETWEEN 0 AND 9007199254740991)',
    'CHECK(length(trim(user_id)) > 0)',
    'CHECK(length(trim(course_id)) > 0)',
    "CHECK(kind IN ('answer', 'lesson', 'score'))",
    'CHECK(sound IS NULL OR length(trim(sound)) > 0)',
    "CHECK(skill IS NULL OR skill IN ('listening', 'spelling'))",
    'CHECK(correct IS NULL OR correct IN (0, 1))',
    'CHECK(activity IS NULL OR length(trim(activity)) > 0)',
    'CHECK(lesson_id IS NULL OR length(trim(lesson_id)) > 0)',
    'CHECK(game IS NULL OR length(trim(game)) > 0)',
    'CHECK(score IS NULL OR score BETWEEN 0 AND 9007199254740991)',
    "CHECK((kind = 'answer' AND sound IS NOT NULL AND skill IS NOT NULL AND correct IS NOT NULL AND activity IS NOT NULL AND lesson_id IS NULL AND game IS NULL AND score IS NULL) OR (kind = 'lesson' AND sound IS NULL AND skill IS NULL AND correct IS NULL AND activity IS NULL AND lesson_id IS NOT NULL AND game IS NULL AND score IS NULL) OR (kind = 'score' AND sound IS NULL AND skill IS NULL AND correct IS NULL AND activity IS NULL AND lesson_id IS NULL AND game IS NOT NULL AND score IS NOT NULL))",
  ];
}
