import 'dart:convert';

import 'package:drift/drift.dart' show QueryRow, Variable;

import '../course_audio_contract.dart';
import '../course_attempt.dart';
import '../course_learning_error.dart';
import '../french_uy_demo_spelling_content.dart';
import '../learning_storage_types.dart';
import '../lesson_policy.dart';
import '../spelling_learning_command.dart' as domain;
import '../spelling_learning_state.dart';
import '../spelling_learning_store.dart' show SpellingCommit;
import '../spelling_learning_transition.dart';
import '../spelling_learning_validator.dart';
import 'learning_database.dart' show LearningDatabase;
import 'learning_sql_transaction.dart';
import 'learning_storage_scope.dart';
import 'learning_tables.dart'
    show learningMaxCheckpointBytes, learningMaxSafeInteger;
import 'spelling_learning_checkpoint_codec.dart';
import 'spelling_learning_command_codec.dart';

/// Family-owned normalized-row mapping for the shared SQLite command protocol.
/// All durable serialization and compare-and-swap remain in the coordinator.
final class SpellingLearningSqlAdapter
    implements
        SqliteLearningProfileAdapter<
          SpellingLearningState,
          domain.SpellingLearningCommand,
          SpellingCommit
        > {
  SpellingLearningSqlAdapter({
    required SpellingProfileScope scope,
    required this.authGeneration,
    required this.transitions,
    required this.historyLimit,
  }) : _domainScope = scope,
       scope = scope.toStorageScope() {
    if (historyLimit < 1 || historyLimit > spellingMaxRetainedAttempts) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
  }

  final SpellingProfileScope _domainScope;
  @override
  final LearningStorageScope scope;
  final int authGeneration;
  final SpellingLearningTransitionEngine transitions;
  final int historyLimit;
  final SpellingLearningCheckpointCodec _checkpointCodec =
      const SpellingLearningCheckpointCodec();
  final SpellingLearningCommandCodec _commandCodec =
      const SpellingLearningCommandCodec();

  FrenchUyDemoSpellingCatalogue get catalogue => transitions.catalogue;

  int get _retainedHistoryLimit => historyLimit > spellingMaxRetainedReceipts
      ? spellingMaxRetainedReceipts
      : historyLimit;

  @override
  String commandActivityId(domain.SpellingLearningCommand command) =>
      command.activityId;

  @override
  String commandToken(domain.SpellingLearningCommand command) => command.token;

  @override
  String commandCanonicalPayload(domain.SpellingLearningCommand command) =>
      _commandCodec.encode(command);

  @override
  int commandAuthGeneration(domain.SpellingLearningCommand command) =>
      command.authGeneration;

  @override
  int commandExpectedScopeRevision(domain.SpellingLearningCommand command) =>
      command.expectedScopeRevision;

  @override
  LearningCursorPosition commandExpectedCursor(
    domain.SpellingLearningCommand command,
  ) => _storageCursor(command.expected);

  @override
  bool isStart(domain.SpellingLearningCommand command) =>
      command.action is domain.StartSpellingPractice ||
      command.action is domain.StartSpellingReviewOnly;

  @override
  LearningCursorPosition? cursorFor(
    SpellingLearningState state,
    String activityId,
  ) {
    final cursor = state.slots[activityId]?.cursor;
    return cursor == null ? null : _storageCursor(cursor);
  }

  @override
  Future<SpellingLearningState> loadState(
    LearningDatabase db,
    int scopeId, {
    required int revision,
    required int commitOrdinal,
  }) async {
    try {
      if (_domainScope.courseId != scope.courseId ||
          _domainScope.owner != scope.owner ||
          scope.family != LearningFamily.spelling ||
          revision < 0 ||
          revision > learningMaxSafeInteger ||
          commitOrdinal != revision) {
        throw const LearningCorruptException();
      }

      final runRows = await db
          .customSelect(
            'SELECT r.scope_id, r.activity_id, r.activity_kind, r.run_generation, '
            'r.sequence, r.cursor_revision, r.content_binding_id, r.run_mode, '
            'r.finished, r.session_id, r.policy_revision, r.threshold_percent, '
            'r.run_start_round, r.checkpoint_json, r.latest_receipt_token, '
            'r.latest_receipt_payload, r.latest_receipt_before_generation, '
            'r.latest_receipt_before_sequence, r.latest_receipt_before_cursor_revision, '
            'r.latest_receipt_commit_ordinal, b.activity_id AS binding_activity_id, '
            'b.content_revision AS binding_content_revision, '
            'b.policy_kind AS binding_policy_kind, '
            'b.policy_revision AS binding_policy_revision, '
            'b.catalogue_fingerprint AS binding_catalogue_fingerprint, '
            'b.section_fingerprint AS binding_section_fingerprint, '
            'b.annotation_hash AS binding_annotation_hash, '
            'b.annotation_revision AS binding_annotation_revision '
            'FROM learning_runs r LEFT JOIN learning_content_bindings b '
            'ON b.id = r.content_binding_id AND b.scope_id = r.scope_id '
            'WHERE r.scope_id = ? ORDER BY r.activity_id',
            variables: <Variable<Object>>[Variable<int>(scopeId)],
          )
          .get();
      if (runRows.length > 1) throw const LearningCorruptException();

      await _requireNoRows(
        db,
        'SELECT 1 AS present FROM learning_best_scores WHERE scope_id = ? LIMIT 1',
        scopeId,
      );
      await _requireNoRows(
        db,
        'SELECT 1 AS present FROM supported_sync_outbox WHERE scope_id = ? LIMIT 1',
        scopeId,
      );
      await _requireOnlyActivityBinding(
        db,
        scopeId,
        hasRun: runRows.isNotEmpty,
      );

      final history = await _readHistoryReceipts(
        db,
        scopeId,
        revision: revision,
        commitOrdinal: commitOrdinal,
      );
      final SpellingSlot? slot;
      if (runRows.isEmpty) {
        if (commitOrdinal != 0 || history.isNotEmpty) {
          throw const LearningCorruptException();
        }
        slot = null;
      } else {
        final run = await _readRunRow(
          runRows.single,
          scopeId,
          revision: revision,
          commitOrdinal: commitOrdinal,
        );
        if (commitOrdinal == 0 ||
            history.isEmpty ||
            !_sameStoredReceipt(
              history.last.stored,
              run.latestReceipt.stored,
            )) {
          throw const LearningCorruptException();
        }
        slot = run.slot;
      }

      final receiptByCursor = <String, _SqlReceipt>{
        for (final receipt in history)
          _cursorKey(receipt.stored.activityId, receipt.stored.after): receipt,
      };
      final attempts = await _readAttempts(
        db,
        scopeId,
        commitOrdinal,
        receiptByCursor,
      );
      final mistakes = await _readMistakes(db, scopeId);
      final summaries = await _readSummaries(db, scopeId);
      final completions = await _readCompletions(db, scopeId);
      final exposures = await _readExposure(db, scopeId);
      final receipts = <SpellingReceipt>[
        for (final receipt in history) receipt.domainReceipt,
      ];
      final state = SpellingLearningState(
        scope: _domainScope,
        revision: revision,
        commitOrdinal: commitOrdinal,
        slots: slot == null
            ? const <String, SpellingSlot>{}
            : <String, SpellingSlot>{slot.activityId: slot},
        attempts: attempts,
        receipts: receipts,
        mistakes: mistakes,
        summaries: summaries,
        exposures: exposures,
        completions: completions,
      );
      SpellingLearningStateValidator.validate(state, catalogue);
      return state;
    } on LearningContentChangedException {
      rethrow;
    } on LearningCorruptException {
      rethrow;
    } on Object catch (error) {
      throw LearningCorruptException(error);
    }
  }

  @override
  Future<LearningStoredReceipt?> findReceipt(
    LearningDatabase db,
    int scopeId,
    String token,
  ) async {
    try {
      final header = await _currentScopeHeader(db, scopeId);
      final historyRows = await db
          .customSelect(
            'SELECT activity_id, token, canonical_payload, before_generation, '
            'before_sequence, before_cursor_revision, after_generation, after_sequence, '
            'after_cursor_revision, commit_ordinal, result_activity_id, result_generation, '
            'result_sequence, result_cursor_revision FROM learning_command_receipts '
            'WHERE scope_id = ? AND token = ?',
            variables: <Variable<Object>>[
              Variable<int>(scopeId),
              Variable<String>(token),
            ],
          )
          .get();
      final latestRows = await db
          .customSelect(
            'SELECT activity_id, latest_receipt_token, latest_receipt_payload, '
            'latest_receipt_before_generation, latest_receipt_before_sequence, '
            'latest_receipt_before_cursor_revision, latest_receipt_commit_ordinal, '
            'run_generation, sequence, cursor_revision FROM learning_runs '
            'WHERE scope_id = ? AND latest_receipt_token = ?',
            variables: <Variable<Object>>[
              Variable<int>(scopeId),
              Variable<String>(token),
            ],
          )
          .get();
      if (historyRows.length > 1 || latestRows.length > 1) {
        throw const LearningCorruptException();
      }
      final found = <_SqlReceipt>[
        if (historyRows.isNotEmpty)
          _readHistoryReceipt(
            historyRows.single,
            revision: header.revision,
            commitOrdinal: header.commitOrdinal,
          ),
        if (latestRows.isNotEmpty)
          _readLatestReceipt(
            latestRows.single,
            revision: header.revision,
            commitOrdinal: header.commitOrdinal,
          ),
      ];
      if (found.isEmpty) return null;
      for (final receipt in found.skip(1)) {
        if (!_sameStoredReceipt(receipt.stored, found.first.stored)) {
          throw const LearningCorruptException();
        }
      }
      return found.first.stored;
    } on LearningContentChangedException {
      rethrow;
    } on LearningCorruptException {
      rethrow;
    } on Object catch (error) {
      throw LearningCorruptException(error);
    }
  }

  @override
  LearningSqlTransition<SpellingLearningState, SpellingCommit> evaluate({
    required SpellingLearningState before,
    required domain.SpellingLearningCommand command,
    required int nextRevision,
    required int nextCommitOrdinal,
    required DateTime committedAt,
  }) {
    try {
      SpellingLearningStateValidator.validate(before, catalogue);
      if (command.scope != _domainScope ||
          command.activityId != catalogue.activityId ||
          command.expectedScopeRevision != before.revision ||
          nextRevision != before.revision + 1 ||
          nextCommitOrdinal != before.commitOrdinal + 1) {
        throw const LearningInvalidCommandException();
      }
      final transition = transitions.evaluate(
        state: before,
        command: command,
        committedAt: committedAt,
      );
      final reduced = transition.nextState;
      final attempts = _latest(<SpellingAttempt>[
        ...before.attempts,
        ...transition.attempts,
      ], _retainedHistoryLimit);
      final receipts = _latest(reduced.receipts, _retainedHistoryLimit);
      if (reduced.mistakes.length > catalogue.rows.length ||
          reduced.summaries.length > catalogue.rows.length ||
          reduced.exposures.length > catalogue.rows.length ||
          reduced.completions.length > 1 ||
          attempts.length > spellingMaxRetainedAttempts ||
          receipts.length > spellingMaxRetainedReceipts) {
        throw const LearningInvalidCommandException();
      }
      final state = SpellingLearningState(
        scope: _domainScope,
        revision: nextRevision,
        commitOrdinal: nextCommitOrdinal,
        slots: reduced.slots,
        attempts: attempts,
        receipts: receipts,
        mistakes: reduced.mistakes,
        summaries: reduced.summaries,
        exposures: reduced.exposures,
        completions: reduced.completions,
      );
      SpellingLearningStateValidator.validate(state, catalogue);
      final slot = state.slots[command.activityId];
      if (slot == null) throw const LearningInvalidCommandException();
      return LearningSqlTransition(
        state: state,
        result: SpellingCommit(state: state, slot: slot, duplicate: false),
      );
    } on LearningInvalidCommandException {
      rethrow;
    } on LearningContentChangedException {
      rethrow;
    } on Object catch (error) {
      throw LearningInvalidCommandException(error);
    }
  }

  @override
  Future<void> persist(
    LearningDatabase db,
    int scopeId,
    SpellingLearningState before,
    domain.SpellingLearningCommand command,
    SpellingLearningState after,
  ) async {
    SpellingLearningStateValidator.validate(before, catalogue);
    SpellingLearningStateValidator.validate(after, catalogue);
    final slot = after.slots[command.activityId];
    if (slot == null ||
        slot.latestReceipt.token != command.token ||
        after.revision != before.revision + 1 ||
        after.commitOrdinal != before.commitOrdinal + 1) {
      throw const LearningInvalidCommandException();
    }
    final bindingId = await _ensureBinding(db, scopeId, slot);
    await _writeRun(db, scopeId, bindingId, command, slot, after);
    await _writeReceipt(db, scopeId, command, slot, after);
    await _writeAttemptChanges(db, scopeId, before, after, command);
    await _pruneReceipts(db, scopeId, after.commitOrdinal);
    await _writeMistakes(db, scopeId, after.mistakes);
    await _writeSummaries(db, scopeId, after.summaries);
    await _writeCompletions(db, scopeId, after.completions);
    await _writeExposure(db, scopeId, after.exposures);
  }

  @override
  SpellingCommit duplicateResult({
    required SpellingLearningState current,
    required domain.SpellingLearningCommand command,
  }) {
    SpellingLearningStateValidator.validate(current, catalogue);
    final slot = current.slots[command.activityId];
    if (slot == null) throw const LearningConflictException();
    return SpellingCommit(state: current, slot: slot, duplicate: true);
  }

  Future<void> _requireOnlyActivityBinding(
    LearningDatabase db,
    int scopeId, {
    required bool hasRun,
  }) async {
    final rows = await db
        .customSelect(
          'SELECT activity_id FROM learning_content_bindings WHERE scope_id = ?',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    if (rows.any(
          (row) => row.read<String>('activity_id') != catalogue.activityId,
        ) ||
        rows.length > 1) {
      throw const LearningCorruptException();
    }
    if (rows.length != (hasRun ? 1 : 0)) {
      throw const LearningContentChangedException();
    }
  }

  Future<({int revision, int commitOrdinal})> _currentScopeHeader(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT owner_kind, owner_id, course_id, family, schema_version, '
          'revision, commit_ordinal, availability_state FROM learning_scopes '
          'WHERE id = ?',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    if (rows.length != 1) throw const LearningCorruptException();
    final row = rows.single;
    final schemaVersion = row.read<int>('schema_version');
    if (schemaVersion != 1) {
      throw LearningUnsupportedVersionException(schemaVersion);
    }
    final revision = row.read<int>('revision');
    final commitOrdinal = row.read<int>('commit_ordinal');
    if (row.read<String>('owner_kind') != scope.ownerKind ||
        row.read<String>('owner_id') != scope.ownerId ||
        row.read<String>('course_id') != scope.courseId ||
        row.read<String>('family') != scope.databaseFamily ||
        row.read<String>('availability_state') != 'available' ||
        revision < 0 ||
        revision > learningMaxSafeInteger ||
        commitOrdinal != revision) {
      throw const LearningCorruptException();
    }
    return (revision: revision, commitOrdinal: commitOrdinal);
  }

  Future<List<_SqlReceipt>> _readHistoryReceipts(
    LearningDatabase db,
    int scopeId, {
    required int revision,
    required int commitOrdinal,
  }) async {
    final rows = await db
        .customSelect(
          'SELECT activity_id, token, canonical_payload, before_generation, '
          'before_sequence, before_cursor_revision, after_generation, after_sequence, '
          'after_cursor_revision, commit_ordinal, result_activity_id, result_generation, '
          'result_sequence, result_cursor_revision FROM learning_command_receipts '
          'WHERE scope_id = ? ORDER BY commit_ordinal',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final expectedCount = commitOrdinal < _retainedHistoryLimit
        ? commitOrdinal
        : _retainedHistoryLimit;
    if (rows.length != expectedCount) throw const LearningCorruptException();
    final firstOrdinal = commitOrdinal - rows.length + 1;
    final receipts = <_SqlReceipt>[];
    final tokens = <String>{};
    final cursors = <String>{};
    for (var index = 0; index < rows.length; index++) {
      final receipt = _readHistoryReceipt(
        rows[index],
        revision: revision,
        commitOrdinal: commitOrdinal,
      );
      if (receipt.stored.commitOrdinal != firstOrdinal + index ||
          !tokens.add(receipt.stored.token) ||
          !cursors.add(
            _cursorKey(receipt.stored.activityId, receipt.stored.after),
          )) {
        throw const LearningCorruptException();
      }
      receipts.add(receipt);
    }
    return receipts;
  }

  _SqlReceipt _readHistoryReceipt(
    QueryRow row, {
    required int revision,
    required int commitOrdinal,
  }) {
    return _readSqlReceipt(
      activityId: _requiredText(row.read<String>('activity_id')),
      token: row.read<String>('token'),
      payload: row.read<String>('canonical_payload'),
      before: _cursor(
        row.read<int>('before_generation'),
        row.read<int>('before_sequence'),
        row.read<int>('before_cursor_revision'),
      ),
      after: _cursor(
        row.read<int>('after_generation'),
        row.read<int>('after_sequence'),
        row.read<int>('after_cursor_revision'),
      ),
      commitOrdinal: row.read<int>('commit_ordinal'),
      resultActivityId: _requiredText(row.read<String>('result_activity_id')),
      result: _cursor(
        row.read<int>('result_generation'),
        row.read<int>('result_sequence'),
        row.read<int>('result_cursor_revision'),
      ),
      revision: revision,
      scopeCommitOrdinal: commitOrdinal,
    );
  }

  _SqlReceipt _readLatestReceipt(
    QueryRow row, {
    required int revision,
    required int commitOrdinal,
  }) {
    final activityId = _requiredText(row.read<String>('activity_id'));
    final after = _cursor(
      row.read<int>('run_generation'),
      row.read<int>('sequence'),
      row.read<int>('cursor_revision'),
    );
    return _readSqlReceipt(
      activityId: activityId,
      token: row.read<String>('latest_receipt_token'),
      payload: row.read<String>('latest_receipt_payload'),
      before: _cursor(
        row.read<int>('latest_receipt_before_generation'),
        row.read<int>('latest_receipt_before_sequence'),
        row.read<int>('latest_receipt_before_cursor_revision'),
      ),
      after: after,
      commitOrdinal: row.read<int>('latest_receipt_commit_ordinal'),
      resultActivityId: activityId,
      result: after,
      revision: revision,
      scopeCommitOrdinal: commitOrdinal,
    );
  }

  _SqlReceipt _readSqlReceipt({
    required String activityId,
    required String token,
    required String payload,
    required LearningCursorPosition before,
    required LearningCursorPosition after,
    required int commitOrdinal,
    required String resultActivityId,
    required LearningCursorPosition result,
    required int revision,
    required int scopeCommitOrdinal,
  }) {
    final command = _commandCodec.decode(payload);
    if (command.scope != _domainScope ||
        command.activityId != activityId ||
        command.token != token ||
        _storageCursor(command.expected) != before ||
        command.expectedScopeRevision != commitOrdinal - 1 ||
        command.expectedScopeRevision >= revision ||
        resultActivityId != activityId ||
        result != after ||
        !_reachable(command.action, before, after) ||
        commitOrdinal < 1 ||
        commitOrdinal > scopeCommitOrdinal) {
      throw const LearningCorruptException();
    }
    final domainReceipt = SpellingReceipt(
      scope: _domainScope,
      activityId: activityId,
      generation: after.generation,
      sequence: after.sequence,
      token: token,
      canonicalCommand: payload,
      before: _domainCursor(before),
      after: _domainCursor(after),
      commitOrdinal: commitOrdinal,
    );
    return _SqlReceipt(
      stored: LearningStoredReceipt(
        activityId: activityId,
        token: token,
        canonicalPayload: payload,
        before: before,
        after: after,
        commitOrdinal: commitOrdinal,
        resultActivityId: resultActivityId,
      ),
      command: command,
      domainReceipt: domainReceipt,
    );
  }

  Future<_ReadRun> _readRunRow(
    QueryRow row,
    int scopeId, {
    required int revision,
    required int commitOrdinal,
  }) async {
    final activityId = _requiredText(row.read<String>('activity_id'));
    if (row.read<int>('scope_id') != scopeId ||
        activityId != catalogue.activityId ||
        row.read<String>('activity_kind') != 'spelling' ||
        row.readNullable<String>('binding_activity_id') != activityId) {
      throw const LearningCorruptException();
    }
    if (row.readNullable<int>('binding_content_revision') !=
        catalogue.contentRevision) {
      throw const LearningContentChangedException();
    }
    if (row.readNullable<String>('binding_policy_kind') !=
            'discoveryThreshold' ||
        row.readNullable<int>('binding_policy_revision') != 1 ||
        row.readNullable<String>('binding_catalogue_fingerprint') !=
            _spellingCatalogueFingerprint ||
        row.readNullable<String>('binding_section_fingerprint') != null ||
        row.readNullable<String>('binding_annotation_hash') != null ||
        row.readNullable<int>('binding_annotation_revision') != null) {
      throw const LearningContentChangedException();
    }
    final mode = _mode(row.readNullable<String>('run_mode'));
    final finished = _boolFromInt(row.read<int>('finished'));
    final policyRevision = row.readNullable<int>('policy_revision');
    final threshold = row.readNullable<int>('threshold_percent');
    final runStartRound = row.readNullable<int>('run_start_round');
    if (policyRevision != 1 || threshold != 80) {
      throw const LearningContentChangedException();
    }
    if (runStartRound == null ||
        runStartRound < 1 ||
        runStartRound > learningMaxSafeInteger) {
      throw const LearningCorruptException();
    }
    final cursor = _cursor(
      row.read<int>('run_generation'),
      row.read<int>('sequence'),
      row.read<int>('cursor_revision'),
    );
    if (cursor.generation < 1 || cursor.sequence < 1) {
      throw const LearningCorruptException();
    }
    final checkpointJson = row.read<String>('checkpoint_json');
    if (utf8.encode(checkpointJson).length > learningMaxCheckpointBytes) {
      throw const LearningCorruptException();
    }
    final sessionId = _requiredText(row.readNullable<String>('session_id'));
    final policy = LessonPolicy(completionThresholdPercent: 80);
    final checkpoint = _checkpointCodec.decode(
      checkpointJson,
      scope: _domainScope,
      catalogue: catalogue,
      policy: policy,
    );
    if (checkpoint.sessionId != sessionId ||
        checkpoint.contentRevision != catalogue.contentRevision ||
        checkpoint.mode != mode ||
        checkpoint.finished != finished ||
        checkpoint.policy.completionThresholdPercent != threshold ||
        checkpoint.runStartRound != runStartRound) {
      throw const LearningCorruptException();
    }
    final latestReceipt = _readLatestReceipt(
      row,
      revision: revision,
      commitOrdinal: commitOrdinal,
    );
    if (latestReceipt.stored.commitOrdinal != commitOrdinal ||
        latestReceipt.stored.after != cursor) {
      throw const LearningCorruptException();
    }
    final slot = SpellingSlot(
      scope: _domainScope,
      activityId: activityId,
      cursor: _domainCursor(cursor),
      checkpoint: checkpoint,
      latestReceipt: latestReceipt.domainReceipt,
    );
    return _ReadRun(slot: slot, latestReceipt: latestReceipt);
  }

  Future<List<SpellingAttempt>> _readAttempts(
    LearningDatabase db,
    int scopeId,
    int commitOrdinal,
    Map<String, _SqlReceipt> receiptByCursor,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT attempt_id, activity_id, run_generation, command_sequence, '
          'batch_index, item_id, item_occurrence, content_revision, commit_ordinal, '
          'answered_at_us, committed_at_us, answer_kind, correct, skill, origin, '
          'presentation, assistance_mask, content_state, audio_source, round, '
          'after_debrief, teaching_exposed, selected_relation, expected_relation, '
          'section_id, sentence_id, annotation_hash, annotation_revision '
          'FROM learning_attempts WHERE scope_id = ? '
          'ORDER BY commit_ordinal, activity_id, run_generation, command_sequence, batch_index',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    if (rows.length > _retainedHistoryLimit) {
      throw const LearningCorruptException();
    }
    final valueRows = await db
        .customSelect(
          'SELECT attempt_id, field, ordinal, value_type, text_value, int_value, bool_value '
          'FROM learning_attempt_values WHERE scope_id = ? '
          'ORDER BY attempt_id, field, ordinal',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final valuesByAttempt = <String, Map<String, List<String>>>{};
    for (final value in valueRows) {
      final attemptId = _requiredText(value.read<String>('attempt_id'));
      final field = value.read<String>('field');
      if (!const <String>{
        'choice',
        'selected_option_id',
        'expected_option_id',
        'word_id',
        'target_sound',
      }.contains(field)) {
        throw const LearningCorruptException();
      }
      final lists = valuesByAttempt.putIfAbsent(
        attemptId,
        () => <String, List<String>>{},
      );
      final fieldValues = lists.putIfAbsent(field, () => <String>[]);
      if (value.read<String>('value_type') != 'text' ||
          value.readNullable<int>('int_value') != null ||
          value.readNullable<int>('bool_value') != null ||
          value.read<int>('ordinal') != fieldValues.length) {
        throw const LearningCorruptException();
      }
      fieldValues.add(_requiredText(value.readNullable<String>('text_value')));
    }

    final evidenceRows = await db
        .customSelect(
          'SELECT attempt_id, evidence_index, evidence_kind, slot, reference_id, '
          'outcome, source, activity_id, run_generation, round, pair_id, ui_generation, '
          'section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
          'annotation_revision, content_revision FROM learning_attempt_evidence '
          'WHERE scope_id = ? ORDER BY attempt_id, evidence_index',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final evidenceByAttempt = <String, List<QueryRow>>{};
    for (final row in evidenceRows) {
      final attemptId = _requiredText(row.read<String>('attempt_id'));
      evidenceByAttempt.putIfAbsent(attemptId, () => <QueryRow>[]).add(row);
    }

    final result = <SpellingAttempt>[];
    final ids = <String>{};
    for (final row in rows) {
      final attemptId = _requiredText(row.read<String>('attempt_id'));
      final activityId = _requiredText(row.read<String>('activity_id'));
      final generation = row.read<int>('run_generation');
      final sequence = row.read<int>('command_sequence');
      final round = row.readNullable<int>('round');
      final contentRevision = row.read<int>('content_revision');
      final itemId = _requiredText(row.readNullable<String>('item_id'));
      final authoredRows = catalogue.rows.where(
        (candidate) => candidate.exercise.id == itemId,
      );
      if (authoredRows.length != 1) throw const LearningCorruptException();
      final authored = authoredRows.single;
      final attemptValues = valuesByAttempt.remove(attemptId);
      if (attemptValues == null ||
          attemptValues.keys.toSet().difference(const <String>{
            'choice',
            'selected_option_id',
            'expected_option_id',
            'word_id',
            'target_sound',
          }).isNotEmpty ||
          attemptValues.length != 5 ||
          !_equalStrings(attemptValues['choice'], const <String>['u', 'ou']) ||
          attemptValues['selected_option_id']?.length != 1 ||
          attemptValues['expected_option_id']?.length != 1 ||
          attemptValues['word_id']?.length != 1 ||
          attemptValues['target_sound']?.length != 1) {
        throw const LearningCorruptException();
      }
      final selected = attemptValues['selected_option_id']!.single;
      final expected = attemptValues['expected_option_id']!.single;
      if (!const <String>{'u', 'ou'}.contains(selected) ||
          expected != authored.exercise.correctOptionId ||
          attemptValues['word_id']!.single != authored.exercise.wordId ||
          attemptValues['target_sound']!.single !=
              authored.exercise.targetSound) {
        throw const LearningCorruptException();
      }
      final evidence =
          evidenceByAttempt.remove(attemptId) ?? const <QueryRow>[];
      if (evidence.length != 1 || round == null) {
        throw const LearningCorruptException();
      }
      final playback = _readPlaybackEvidence(
        evidence.single,
        activityId: activityId,
        generation: generation,
        round: round,
        itemId: itemId,
        contentRevision: contentRevision,
      );
      final correct = _boolFromInt(row.read<int>('correct'));
      final cursorKey = _cursorKey(
        activityId,
        _cursor(generation, sequence, 0),
      );
      final receipt = receiptByCursor[cursorKey];
      final observation = SpellingPlaybackObservation(
        profile: _domainScope,
        authGeneration: receipt?.command.authGeneration ?? authGeneration,
        activityId: activityId,
        contentRevision: contentRevision,
        runGeneration: generation,
        round: round,
        itemId: itemId,
        referenceId: playback.referenceId,
        promptEpoch: playback.promptEpoch,
        outcome: CourseAudioOutcome.completed,
        source: CourseAudioSource.unverifiedRecording,
      );
      if (!ids.add(attemptId) ||
          activityId != catalogue.activityId ||
          generation < 1 ||
          sequence < 1 ||
          row.read<int>('batch_index') != 0 ||
          row.readNullable<int>('item_occurrence') != null ||
          contentRevision != catalogue.contentRevision ||
          row.read<int>('commit_ordinal') < 1 ||
          row.read<int>('commit_ordinal') > commitOrdinal ||
          !_tokenPattern.hasMatch(attemptId) ||
          row.read<String>('answer_kind') != 'spellingChoice' ||
          row.readNullable<String>('skill') != 'spelling' ||
          row.readNullable<String>('origin') != 'practice' ||
          row.readNullable<String>('presentation') !=
              (round == 1 ? 'firstInRun' : 'repeatInRun') ||
          row.readNullable<int>('assistance_mask') != (round == 1 ? 0 : 13) ||
          row.readNullable<String>('content_state') != 'pending' ||
          row.readNullable<String>('audio_source') != 'pendingRecording' ||
          row.readNullable<int>('after_debrief') != (round > 1 ? 1 : 0) ||
          row.readNullable<int>('teaching_exposed') != null ||
          row.readNullable<String>('selected_relation') != null ||
          row.readNullable<String>('expected_relation') != null ||
          row.readNullable<String>('section_id') != null ||
          row.readNullable<String>('sentence_id') != null ||
          row.readNullable<String>('annotation_hash') != null ||
          row.readNullable<int>('annotation_revision') != null ||
          correct != (selected == expected)) {
        throw const LearningCorruptException();
      }
      _dateFromMicros(row.read<int>('answered_at_us'));
      final attempt = SpellingAttempt(
        scope: _domainScope,
        attemptId: attemptId,
        activityId: activityId,
        generation: generation,
        sequence: sequence,
        itemId: itemId,
        round: round,
        contentRevision: contentRevision,
        selectedOptionId: selected,
        expectedOptionId: expected,
        correct: correct,
        presentation: round == 1
            ? AttemptPresentation.firstInRun
            : AttemptPresentation.repeatInRun,
        afterDebrief: round > 1,
        teachingExposed: round > 1,
        audioSource: AttemptAudioSource.pendingRecording,
        playback: observation,
        committedAt: _dateFromMicros(row.read<int>('committed_at_us')),
      );
      if (receipt != null) _validateAttemptReceipt(attempt, receipt);
      result.add(attempt);
    }
    if (valuesByAttempt.isNotEmpty || evidenceByAttempt.isNotEmpty) {
      throw const LearningCorruptException();
    }
    return result;
  }

  _PlaybackEvidence _readPlaybackEvidence(
    QueryRow row, {
    required String activityId,
    required int generation,
    required int round,
    required String itemId,
    required int contentRevision,
  }) {
    final authored = catalogue.rows.singleWhere(
      (candidate) => candidate.exercise.id == itemId,
    );
    final reference = _requiredText(row.readNullable<String>('reference_id'));
    if (row.read<int>('evidence_index') != 0 ||
        row.read<String>('evidence_kind') != 'spellingPlayback' ||
        row.readNullable<String>('slot') != null ||
        row.readNullable<String>('outcome') !=
            CourseAudioOutcome.completed.name ||
        row.readNullable<String>('source') !=
            CourseAudioSource.unverifiedRecording.name ||
        row.readNullable<String>('activity_id') != activityId ||
        row.readNullable<int>('run_generation') != generation ||
        row.readNullable<int>('round') != round ||
        row.readNullable<String>('pair_id') != null ||
        row.readNullable<int>('ui_generation') == null ||
        row.readNullable<int>('ui_generation')! < 0 ||
        row.readNullable<String>('section_id') != null ||
        row.readNullable<String>('item_id') != itemId ||
        row.readNullable<String>('sentence_id') != null ||
        row.readNullable<String>('audio_ref_id') != null ||
        row.readNullable<String>('annotation_hash') != null ||
        row.readNullable<int>('annotation_revision') != null ||
        row.readNullable<int>('content_revision') != contentRevision ||
        contentRevision != catalogue.contentRevision ||
        reference != authored.exercise.audioRefId ||
        !reference.startsWith('fr-word-')) {
      throw const LearningCorruptException();
    }
    return _PlaybackEvidence(
      referenceId: reference,
      promptEpoch: row.read<int>('ui_generation'),
    );
  }

  void _validateAttemptReceipt(SpellingAttempt attempt, _SqlReceipt receipt) {
    final action = receipt.command.action;
    if (action is! domain.AnswerSpellingChoice ||
        receipt.command.token != attempt.attemptId ||
        action.itemId != attempt.itemId ||
        action.contentRevision != attempt.contentRevision ||
        action.selectedOptionId != attempt.selectedOptionId ||
        action.expectedOptionIdSnapshot != attempt.expectedOptionId ||
        !_samePlayback(action.playback, attempt.playback) ||
        receipt.stored.after.generation != attempt.generation ||
        receipt.stored.after.sequence != attempt.sequence) {
      throw const LearningCorruptException();
    }
  }

  Future<Map<SpellingMistakeKey, SpellingMistake>> _readMistakes(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT family, activity_id, item_id, target_sound, skill, pair_id, '
          'section_id, sentence_id, audio_ref_id, annotation_hash, annotation_revision, '
          'content_revision, first_wrong_attempt_id, latest_wrong_attempt_id, '
          'first_wrong_at_us, latest_wrong_at_us, failure_count, last_run_generation '
          'FROM learning_mistakes WHERE scope_id = ? ORDER BY item_id, content_revision',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    if (rows.length > catalogue.rows.length) {
      throw const LearningCorruptException();
    }
    final result = <SpellingMistakeKey, SpellingMistake>{};
    for (final row in rows) {
      final itemId = _requiredText(row.readNullable<String>('item_id'));
      final authored = _rowFor(itemId);
      final firstPointer = row.readNullable<String>('first_wrong_attempt_id');
      final latestPointer = row.readNullable<String>('latest_wrong_attempt_id');
      if (row.read<String>('family') != 'spelling' ||
          row.readNullable<String>('activity_id') != catalogue.activityId ||
          row.readNullable<String>('target_sound') !=
              authored.exercise.targetSound ||
          row.readNullable<String>('skill') != 'spelling' ||
          row.readNullable<String>('pair_id') != null ||
          row.readNullable<String>('section_id') != null ||
          row.readNullable<String>('sentence_id') != null ||
          row.readNullable<String>('audio_ref_id') != null ||
          row.readNullable<String>('annotation_hash') != null ||
          row.readNullable<int>('annotation_revision') != null ||
          row.read<int>('content_revision') != catalogue.contentRevision ||
          firstPointer != null && !_tokenPattern.hasMatch(firstPointer) ||
          latestPointer != null && !_tokenPattern.hasMatch(latestPointer) ||
          row.readNullable<int>('last_run_generation') != null) {
        throw const LearningCorruptException();
      }
      final key = SpellingMistakeKey(
        scope: _domainScope,
        activityId: catalogue.activityId,
        itemId: itemId,
        targetSound: authored.exercise.targetSound,
        contentRevision: catalogue.contentRevision,
      );
      if (result.containsKey(key)) throw const LearningCorruptException();
      result[key] = SpellingMistake(
        key: key,
        firstWrongAt: _dateFromMicros(row.read<int>('first_wrong_at_us')),
        latestWrongAt: _dateFromMicros(row.read<int>('latest_wrong_at_us')),
        failureCount: row.read<int>('failure_count'),
      );
    }
    return result;
  }

  Future<Map<SpellingSummaryKey, SpellingSummary>> _readSummaries(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT family, activity_id, sound, skill, origin, presentation, assistance_mask, '
          'pair_id, section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
          'annotation_revision, content_revision, bucket, correct, total '
          'FROM learning_summaries WHERE scope_id = ? ORDER BY item_id, bucket',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    if (rows.length > catalogue.rows.length * 2) {
      throw const LearningCorruptException();
    }
    final buckets = <SpellingSummaryKey, Map<String, SpellingCount>>{};
    for (final row in rows) {
      final itemId = _requiredText(row.readNullable<String>('item_id'));
      final authored = _rowFor(itemId);
      final key = SpellingSummaryKey(
        scope: _domainScope,
        activityId: catalogue.activityId,
        itemId: itemId,
        sound: authored.exercise.targetSound,
        contentRevision: catalogue.contentRevision,
      );
      final bucket = row.read<String>('bucket');
      if (row.read<String>('family') != 'spelling' ||
          row.readNullable<String>('activity_id') != catalogue.activityId ||
          row.readNullable<String>('sound') != authored.exercise.targetSound ||
          row.readNullable<String>('skill') != 'spelling' ||
          row.readNullable<String>('origin') != 'practice' ||
          row.readNullable<String>('presentation') != null ||
          row.readNullable<int>('assistance_mask') != null ||
          row.readNullable<String>('pair_id') != null ||
          row.readNullable<String>('section_id') != null ||
          row.readNullable<String>('sentence_id') != null ||
          row.readNullable<String>('audio_ref_id') != null ||
          row.readNullable<String>('annotation_hash') != null ||
          row.readNullable<int>('annotation_revision') != null ||
          row.readNullable<int>('content_revision') !=
              catalogue.contentRevision ||
          !const <String>{'firstInRun', 'afterDebrief'}.contains(bucket)) {
        throw const LearningCorruptException();
      }
      final byBucket = buckets.putIfAbsent(
        key,
        () => <String, SpellingCount>{},
      );
      if (byBucket.containsKey(bucket)) throw const LearningCorruptException();
      byBucket[bucket] = SpellingCount(
        correct: row.read<int>('correct'),
        total: row.read<int>('total'),
      );
    }
    final result = <SpellingSummaryKey, SpellingSummary>{};
    for (final entry in buckets.entries) {
      if (entry.value.length != 2 ||
          !entry.value.containsKey('firstInRun') ||
          !entry.value.containsKey('afterDebrief')) {
        throw const LearningCorruptException();
      }
      result[entry.key] = SpellingSummary(
        key: entry.key,
        firstInRun: entry.value['firstInRun']!,
        afterDebrief: entry.value['afterDebrief']!,
      );
    }
    return result;
  }

  Future<List<SpellingCompletion>> _readCompletions(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT activity_id, content_revision, policy_kind, policy_revision, '
          'threshold_percent, committed_at_us FROM learning_completions '
          'WHERE scope_id = ? ORDER BY activity_id, content_revision, policy_revision, threshold_percent',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    if (rows.length > 1) throw const LearningCorruptException();
    final result = <SpellingCompletion>[];
    for (final row in rows) {
      if (row.read<String>('activity_id') != catalogue.activityId ||
          row.read<int>('content_revision') != catalogue.contentRevision ||
          row.read<String>('policy_kind') != 'discoveryThreshold' ||
          row.read<int>('policy_revision') != 1 ||
          row.read<int>('threshold_percent') != 80) {
        throw const LearningCorruptException();
      }
      result.add(
        SpellingCompletion(
          scope: _domainScope,
          activityId: catalogue.activityId,
          contentRevision: catalogue.contentRevision,
          policyKind: CompletionPolicyKind.discoveryThreshold,
          policyRevision: 1,
          thresholdPercent: 80,
          committedAt: _dateFromMicros(row.read<int>('committed_at_us')),
        ),
      );
    }
    return result;
  }

  Future<Map<SpellingExposureKey, SpellingExposure>> _readExposure(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT family, activity_id, item_id, target_sound, section_id, '
          'content_revision, presentations, assistance_mask FROM learning_exposure '
          'WHERE scope_id = ? ORDER BY item_id, content_revision',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    if (rows.length > catalogue.rows.length) {
      throw const LearningCorruptException();
    }
    final result = <SpellingExposureKey, SpellingExposure>{};
    for (final row in rows) {
      final itemId = _requiredText(row.readNullable<String>('item_id'));
      final authored = _rowFor(itemId);
      if (row.read<String>('family') != 'spelling' ||
          row.readNullable<String>('activity_id') != catalogue.activityId ||
          row.readNullable<String>('target_sound') !=
              authored.exercise.targetSound ||
          row.readNullable<String>('section_id') != null ||
          row.readNullable<int>('content_revision') !=
              catalogue.contentRevision) {
        throw const LearningCorruptException();
      }
      final key = SpellingExposureKey(
        scope: _domainScope,
        activityId: catalogue.activityId,
        itemId: itemId,
        targetSound: authored.exercise.targetSound,
        contentRevision: catalogue.contentRevision,
      );
      if (result.containsKey(key)) throw const LearningCorruptException();
      result[key] = SpellingExposure(
        key: key,
        presentations: row.read<int>('presentations'),
        assistanceMask: row.read<int>('assistance_mask'),
      );
    }
    return result;
  }

  Future<int> _ensureBinding(
    LearningDatabase db,
    int scopeId,
    SpellingSlot slot,
  ) async {
    if (slot.activityId != catalogue.activityId ||
        slot.checkpoint.contentRevision != catalogue.contentRevision) {
      throw const LearningContentChangedException();
    }
    await db.customStatement(
      'INSERT INTO learning_content_bindings '
      '(scope_id, activity_id, content_revision, policy_kind, policy_revision, '
      'catalogue_fingerprint, section_fingerprint, annotation_hash, annotation_revision) '
      "VALUES (?, ?, 1, 'discoveryThreshold', 1, 'uy-demo-spelling-v1', NULL, NULL, NULL) "
      'ON CONFLICT DO NOTHING',
      [scopeId, catalogue.activityId],
    );
    final rows = await db
        .customSelect(
          'SELECT id FROM learning_content_bindings WHERE scope_id = ? '
          'AND activity_id = ? AND content_revision = 1 '
          "AND policy_kind = 'discoveryThreshold' AND policy_revision = 1 "
          "AND catalogue_fingerprint = 'uy-demo-spelling-v1' "
          'AND section_fingerprint IS NULL '
          'AND annotation_hash IS NULL AND annotation_revision IS NULL',
          variables: <Variable<Object>>[
            Variable<int>(scopeId),
            Variable<String>(catalogue.activityId),
          ],
        )
        .get();
    if (rows.length != 1) throw const LearningCorruptException();
    return rows.single.read<int>('id');
  }

  Future<void> _writeRun(
    LearningDatabase db,
    int scopeId,
    int bindingId,
    domain.SpellingLearningCommand command,
    SpellingSlot slot,
    SpellingLearningState after,
  ) async {
    await db.customStatement(
      'INSERT INTO learning_runs '
      '(scope_id, activity_id, activity_kind, run_generation, sequence, cursor_revision, '
      'content_binding_id, run_mode, finished, session_id, policy_revision, threshold_percent, '
      'run_start_round, checkpoint_json, latest_receipt_token, latest_receipt_payload, '
      'latest_receipt_before_generation, latest_receipt_before_sequence, '
      'latest_receipt_before_cursor_revision, latest_receipt_commit_ordinal) '
      "VALUES (?, ?, 'spelling', ?, ?, ?, ?, ?, ?, ?, 1, 80, ?, ?, ?, ?, ?, ?, ?, ?) "
      'ON CONFLICT(scope_id, activity_id) DO UPDATE SET '
      "activity_kind = 'spelling', run_generation = excluded.run_generation, "
      'sequence = excluded.sequence, cursor_revision = excluded.cursor_revision, '
      'content_binding_id = excluded.content_binding_id, run_mode = excluded.run_mode, '
      'finished = excluded.finished, session_id = excluded.session_id, '
      'policy_revision = excluded.policy_revision, threshold_percent = excluded.threshold_percent, '
      'run_start_round = excluded.run_start_round, checkpoint_json = excluded.checkpoint_json, '
      'latest_receipt_token = excluded.latest_receipt_token, '
      'latest_receipt_payload = excluded.latest_receipt_payload, '
      'latest_receipt_before_generation = excluded.latest_receipt_before_generation, '
      'latest_receipt_before_sequence = excluded.latest_receipt_before_sequence, '
      'latest_receipt_before_cursor_revision = excluded.latest_receipt_before_cursor_revision, '
      'latest_receipt_commit_ordinal = excluded.latest_receipt_commit_ordinal',
      [
        scopeId,
        catalogue.activityId,
        slot.cursor.generation,
        slot.cursor.sequence,
        slot.cursor.revision,
        bindingId,
        slot.checkpoint.mode.name,
        slot.checkpoint.finished ? 1 : 0,
        slot.checkpoint.sessionId,
        slot.checkpoint.runStartRound,
        _checkpointCodec.encode(slot.checkpoint),
        command.token,
        _commandCodec.encode(command),
        command.expected.generation,
        command.expected.sequence,
        command.expected.revision,
        after.commitOrdinal,
      ],
    );
  }

  Future<void> _writeReceipt(
    LearningDatabase db,
    int scopeId,
    domain.SpellingLearningCommand command,
    SpellingSlot slot,
    SpellingLearningState after,
  ) async {
    await db.customStatement(
      'INSERT INTO learning_command_receipts '
      '(scope_id, activity_id, token, canonical_payload, before_generation, before_sequence, '
      'before_cursor_revision, after_generation, after_sequence, after_cursor_revision, '
      'commit_ordinal, result_activity_id, result_generation, result_sequence, result_cursor_revision) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        scopeId,
        command.activityId,
        command.token,
        _commandCodec.encode(command),
        command.expected.generation,
        command.expected.sequence,
        command.expected.revision,
        slot.cursor.generation,
        slot.cursor.sequence,
        slot.cursor.revision,
        after.commitOrdinal,
        command.activityId,
        slot.cursor.generation,
        slot.cursor.sequence,
        slot.cursor.revision,
      ],
    );
  }

  Future<void> _pruneReceipts(
    LearningDatabase db,
    int scopeId,
    int latestCommitOrdinal,
  ) async {
    final cutoff = latestCommitOrdinal - _retainedHistoryLimit + 1;
    if (cutoff > 1) {
      await db.customStatement(
        'DELETE FROM learning_command_receipts WHERE scope_id = ? AND commit_ordinal < ?',
        [scopeId, cutoff],
      );
    }
  }

  Future<void> _writeAttemptChanges(
    LearningDatabase db,
    int scopeId,
    SpellingLearningState before,
    SpellingLearningState after,
    domain.SpellingLearningCommand command,
  ) async {
    final beforeById = <String, SpellingAttempt>{
      for (final attempt in before.attempts) attempt.attemptId: attempt,
    };
    final afterById = <String, SpellingAttempt>{
      for (final attempt in after.attempts) attempt.attemptId: attempt,
    };
    for (final attempt in before.attempts) {
      if (afterById.containsKey(attempt.attemptId)) continue;
      await db.customStatement(
        'DELETE FROM learning_attempt_values WHERE scope_id = ? AND attempt_id = ?',
        [scopeId, attempt.attemptId],
      );
      await db.customStatement(
        'DELETE FROM learning_attempt_evidence WHERE scope_id = ? AND attempt_id = ?',
        [scopeId, attempt.attemptId],
      );
      await db.customStatement(
        'DELETE FROM learning_attempts WHERE scope_id = ? AND attempt_id = ?',
        [scopeId, attempt.attemptId],
      );
    }
    final added = after.attempts
        .where((attempt) => !beforeById.containsKey(attempt.attemptId))
        .toList(growable: false);
    if (command.action is domain.AnswerSpellingChoice) {
      if (added.length != 1) throw const LearningInvalidCommandException();
    } else if (added.isNotEmpty) {
      throw const LearningInvalidCommandException();
    }
    for (final attempt in added) {
      final action = command.action;
      if (action is! domain.AnswerSpellingChoice ||
          command.activityId != attempt.activityId ||
          command.expected.generation != attempt.generation ||
          attempt.sequence != command.expected.sequence + 1 ||
          attempt.attemptId != command.token ||
          action.itemId != attempt.itemId ||
          action.selectedOptionId != attempt.selectedOptionId ||
          action.expectedOptionIdSnapshot != attempt.expectedOptionId ||
          !_samePlayback(action.playback, attempt.playback)) {
        throw const LearningInvalidCommandException();
      }
      await _insertAttempt(db, scopeId, attempt, after.commitOrdinal, command);
    }
  }

  Future<void> _insertAttempt(
    LearningDatabase db,
    int scopeId,
    SpellingAttempt attempt,
    int commitOrdinal,
    domain.SpellingLearningCommand command,
  ) async {
    final authored = _rowFor(attempt.itemId);
    await db.customStatement(
      'INSERT INTO learning_attempts '
      '(scope_id, attempt_id, activity_id, run_generation, command_sequence, batch_index, '
      'item_id, item_occurrence, content_revision, commit_ordinal, answered_at_us, '
      'committed_at_us, answer_kind, correct, skill, origin, presentation, assistance_mask, '
      'content_state, audio_source, round, after_debrief, teaching_exposed, selected_relation, '
      'expected_relation, section_id, sentence_id, annotation_hash, annotation_revision) '
      "VALUES (?, ?, ?, ?, ?, 0, ?, NULL, ?, ?, ?, ?, 'spellingChoice', ?, 'spelling', "
      "'practice', ?, ?, 'pending', 'pendingRecording', ?, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL)",
      [
        scopeId,
        attempt.attemptId,
        attempt.activityId,
        attempt.generation,
        attempt.sequence,
        attempt.itemId,
        attempt.contentRevision,
        commitOrdinal,
        _dateMicros(command.submittedAt),
        _dateMicros(attempt.committedAt),
        attempt.correct ? 1 : 0,
        attempt.presentation.name,
        attempt.afterDebrief ? 13 : 0,
        attempt.round,
        attempt.afterDebrief ? 1 : 0,
      ],
    );
    for (final value in <(String, int, String)>[
      ('choice', 0, 'u'),
      ('choice', 1, 'ou'),
      ('selected_option_id', 0, attempt.selectedOptionId),
      ('expected_option_id', 0, attempt.expectedOptionId),
      ('word_id', 0, authored.exercise.wordId),
      ('target_sound', 0, authored.exercise.targetSound),
    ]) {
      await db.customStatement(
        'INSERT INTO learning_attempt_values '
        '(scope_id, attempt_id, field, ordinal, value_type, text_value, int_value, bool_value) '
        "VALUES (?, ?, ?, ?, 'text', ?, NULL, NULL)",
        [scopeId, attempt.attemptId, value.$1, value.$2, value.$3],
      );
    }
    final playback = attempt.playback;
    await db.customStatement(
      'INSERT INTO learning_attempt_evidence '
      '(scope_id, attempt_id, evidence_index, evidence_kind, slot, reference_id, outcome, '
      'source, activity_id, run_generation, round, pair_id, ui_generation, section_id, '
      'item_id, sentence_id, audio_ref_id, annotation_hash, annotation_revision, content_revision) '
      "VALUES (?, ?, 0, 'spellingPlayback', NULL, ?, 'completed', 'unverifiedRecording', "
      '?, ?, ?, NULL, ?, NULL, ?, NULL, NULL, NULL, NULL, ?)',
      [
        scopeId,
        attempt.attemptId,
        playback.referenceId,
        attempt.activityId,
        attempt.generation,
        attempt.round,
        playback.promptEpoch,
        attempt.itemId,
        attempt.contentRevision,
      ],
    );
  }

  Future<void> _writeMistakes(
    LearningDatabase db,
    int scopeId,
    Map<SpellingMistakeKey, SpellingMistake> mistakes,
  ) async {
    await db.customStatement(
      "DELETE FROM learning_mistakes WHERE scope_id = ? AND family = 'spelling'",
      [scopeId],
    );
    for (final mistake in mistakes.values) {
      final key = mistake.key;
      await db.customStatement(
        'INSERT INTO learning_mistakes '
        '(scope_id, family, activity_id, item_id, target_sound, skill, pair_id, section_id, '
        'sentence_id, audio_ref_id, annotation_hash, annotation_revision, content_revision, '
        'first_wrong_attempt_id, latest_wrong_attempt_id, first_wrong_at_us, latest_wrong_at_us, '
        'failure_count, last_run_generation) '
        "VALUES (?, 'spelling', ?, ?, ?, 'spelling', NULL, NULL, NULL, NULL, NULL, NULL, 1, "
        'NULL, NULL, ?, ?, ?, NULL)',
        [
          scopeId,
          key.activityId,
          key.itemId,
          key.targetSound,
          _dateMicros(mistake.firstWrongAt),
          _dateMicros(mistake.latestWrongAt),
          mistake.failureCount,
        ],
      );
    }
  }

  Future<void> _writeSummaries(
    LearningDatabase db,
    int scopeId,
    Map<SpellingSummaryKey, SpellingSummary> summaries,
  ) async {
    await db.customStatement(
      "DELETE FROM learning_summaries WHERE scope_id = ? AND family = 'spelling'",
      [scopeId],
    );
    for (final summary in summaries.values) {
      for (final bucket in <(String, SpellingCount)>[
        ('firstInRun', summary.firstInRun),
        ('afterDebrief', summary.afterDebrief),
      ]) {
        await db.customStatement(
          'INSERT INTO learning_summaries '
          '(scope_id, family, activity_id, sound, skill, origin, presentation, assistance_mask, '
          'pair_id, section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
          'annotation_revision, content_revision, bucket, correct, total) '
          "VALUES (?, 'spelling', ?, ?, 'spelling', 'practice', NULL, NULL, NULL, NULL, ?, "
          'NULL, NULL, NULL, NULL, 1, ?, ?, ?)',
          [
            scopeId,
            summary.key.activityId,
            summary.key.sound,
            summary.key.itemId,
            bucket.$1,
            bucket.$2.correct,
            bucket.$2.total,
          ],
        );
      }
    }
  }

  Future<void> _writeCompletions(
    LearningDatabase db,
    int scopeId,
    List<SpellingCompletion> completions,
  ) async {
    for (final completion in completions) {
      await db.customStatement(
        'INSERT INTO learning_completions '
        '(scope_id, activity_id, content_revision, policy_kind, policy_revision, '
        'threshold_percent, committed_at_us) '
        "VALUES (?, ?, 1, 'discoveryThreshold', 1, 80, ?) ON CONFLICT DO NOTHING",
        [scopeId, completion.activityId, _dateMicros(completion.committedAt)],
      );
    }
  }

  Future<void> _writeExposure(
    LearningDatabase db,
    int scopeId,
    Map<SpellingExposureKey, SpellingExposure> exposures,
  ) async {
    await db.customStatement(
      "DELETE FROM learning_exposure WHERE scope_id = ? AND family = 'spelling'",
      [scopeId],
    );
    for (final exposure in exposures.values) {
      final key = exposure.key;
      await db.customStatement(
        'INSERT INTO learning_exposure '
        '(scope_id, family, activity_id, item_id, target_sound, section_id, '
        'content_revision, presentations, assistance_mask) '
        "VALUES (?, 'spelling', ?, ?, ?, NULL, 1, ?, ?)",
        [
          scopeId,
          key.activityId,
          key.itemId,
          key.targetSound,
          exposure.presentations,
          exposure.assistanceMask,
        ],
      );
    }
  }

  UyDemoSpellingRow _rowFor(String itemId) => catalogue.rows.singleWhere(
    (row) => row.exercise.id == itemId,
    orElse: () => throw const LearningCorruptException(),
  );
}

final class _ReadRun {
  const _ReadRun({required this.slot, required this.latestReceipt});

  final SpellingSlot slot;
  final _SqlReceipt latestReceipt;
}

final class _SqlReceipt {
  const _SqlReceipt({
    required this.stored,
    required this.command,
    required this.domainReceipt,
  });

  final LearningStoredReceipt stored;
  final domain.SpellingLearningCommand command;
  final SpellingReceipt domainReceipt;
}

final class _PlaybackEvidence {
  const _PlaybackEvidence({
    required this.referenceId,
    required this.promptEpoch,
  });

  final String referenceId;
  final int promptEpoch;
}

List<T> _latest<T>(List<T> values, int limit) =>
    values.length <= limit ? values : values.sublist(values.length - limit);

LearningCursorPosition _cursor(int generation, int sequence, int revision) =>
    LearningCursorPosition(
      generation: generation,
      sequence: sequence,
      revision: revision,
    );

LearningCursorPosition _storageCursor(SpellingCursor cursor) =>
    _cursor(cursor.generation, cursor.sequence, cursor.revision);

SpellingCursor _domainCursor(LearningCursorPosition cursor) => SpellingCursor(
  generation: cursor.generation,
  sequence: cursor.sequence,
  revision: cursor.revision,
);

String _cursorKey(String activityId, LearningCursorPosition cursor) =>
    jsonEncode([activityId, cursor.generation, cursor.sequence]);

bool _reachable(
  domain.SpellingAction action,
  LearningCursorPosition before,
  LearningCursorPosition after,
) {
  if (action is domain.StartSpellingPractice ||
      action is domain.StartSpellingReviewOnly) {
    return after.generation == before.generation + 1 &&
        after.sequence == before.sequence + 1 &&
        after.revision == 0;
  }
  return before.generation > 0 &&
      after.generation == before.generation &&
      after.sequence == before.sequence + 1 &&
      after.revision == before.revision + 1;
}

bool _sameStoredReceipt(
  LearningStoredReceipt left,
  LearningStoredReceipt right,
) =>
    left.activityId == right.activityId &&
    left.token == right.token &&
    left.canonicalPayload == right.canonicalPayload &&
    left.before == right.before &&
    left.after == right.after &&
    left.commitOrdinal == right.commitOrdinal &&
    left.resultActivityId == right.resultActivityId;

bool _samePlayback(
  SpellingPlaybackObservation left,
  SpellingPlaybackObservation right,
) =>
    left.profile == right.profile &&
    left.authGeneration == right.authGeneration &&
    left.activityId == right.activityId &&
    left.contentRevision == right.contentRevision &&
    left.runGeneration == right.runGeneration &&
    left.round == right.round &&
    left.itemId == right.itemId &&
    left.referenceId == right.referenceId &&
    left.promptEpoch == right.promptEpoch &&
    left.outcome == right.outcome &&
    left.source == right.source;

bool _equalStrings(List<String>? left, List<String> right) =>
    left != null &&
    left.length == right.length &&
    List<bool>.generate(
      left.length,
      (index) => left[index] == right[index],
    ).every((same) => same);

Future<void> _requireNoRows(
  LearningDatabase db,
  String sql,
  int scopeId,
) async {
  final rows = await db
      .customSelect(sql, variables: <Variable<Object>>[Variable<int>(scopeId)])
      .get();
  if (rows.isNotEmpty) throw const LearningCorruptException();
}

String _requiredText(String? value) {
  if (value == null || value.trim().isEmpty) {
    throw const LearningCorruptException();
  }
  return value;
}

bool _boolFromInt(int value) => switch (value) {
  0 => false,
  1 => true,
  _ => throw const LearningCorruptException(),
};

SpellingRunMode _mode(String? value) => switch (value) {
  'practice' => SpellingRunMode.practice,
  'reviewOnly' => SpellingRunMode.reviewOnly,
  _ => throw const LearningCorruptException(),
};

int _dateMicros(DateTime value) {
  if (!value.isUtc) throw const LearningInvalidCommandException();
  final micros = value.microsecondsSinceEpoch;
  if (micros < 0 || micros > learningMaxSafeInteger) {
    throw const LearningInvalidCommandException();
  }
  return micros;
}

DateTime _dateFromMicros(int value) {
  if (value < 0 || value > learningMaxSafeInteger) {
    throw const LearningCorruptException();
  }
  return DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);
}

final RegExp _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{22}$');

const String _spellingCatalogueFingerprint = 'uy-demo-spelling-v1';
