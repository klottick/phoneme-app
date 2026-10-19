import 'dart:convert';

import 'package:drift/drift.dart' show QueryRow, Variable;

import '../comparison_content.dart';
import '../comparison_learning_command.dart' as domain;
import '../comparison_learning_state.dart';
import '../comparison_learning_transition.dart';
import '../course_audio_contract.dart';
import '../lesson_policy.dart';
import '../lesson_section_session.dart';
import '../course_learning_error.dart';
import '../comparison_learning_store.dart' show ComparisonCommit;
import 'comparison_learning_checkpoint_codec.dart';
import 'comparison_learning_command_codec.dart';
import 'comparison_learning_storage_validator.dart';
import 'learning_database.dart' show LearningDatabase;
import 'learning_sql_transaction.dart';
import 'learning_storage_scope.dart';
import '../learning_storage_types.dart';
import 'learning_tables.dart'
    show learningMaxCheckpointBytes, learningMaxSafeInteger;

/// Typed normalized-row mapper for the inactive comparison SQLite repository.
/// The domain transition engine remains the only comparison reducer.
final class ComparisonLearningSqlAdapter
    implements
        SqliteLearningProfileAdapter<
          ComparisonLearningState,
          domain.ComparisonLearningCommand,
          ComparisonCommit
        > {
  ComparisonLearningSqlAdapter({
    required ComparisonProfileScope scope,
    required this.transitions,
    required this.historyLimit,
  }) : _domainScope = scope,
       scope = LearningStorageScope(
         owner: scope.owner,
         courseId: scope.courseId,
         family: LearningFamily.comparison,
       ) {
    if (historyLimit < 1 || historyLimit > 2000) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
  }

  final ComparisonProfileScope _domainScope;
  @override
  final LearningStorageScope scope;
  final ComparisonLearningTransitionEngine transitions;
  final int historyLimit;
  final ComparisonLearningCheckpointCodec _checkpointCodec =
      const ComparisonLearningCheckpointCodec();

  ComparisonCatalogue get catalogue => transitions.catalogue;

  @override
  String commandActivityId(domain.ComparisonLearningCommand command) =>
      command.activityId;

  @override
  String commandToken(domain.ComparisonLearningCommand command) =>
      command.token;

  @override
  String commandCanonicalPayload(domain.ComparisonLearningCommand command) =>
      ComparisonLearningCommandCodec.canonicalCommand(command);

  @override
  int commandAuthGeneration(domain.ComparisonLearningCommand command) =>
      command.authGeneration;

  @override
  int commandExpectedScopeRevision(domain.ComparisonLearningCommand command) =>
      command.expectedScopeRevision;

  @override
  LearningCursorPosition commandExpectedCursor(
    domain.ComparisonLearningCommand command,
  ) => _toStorageCursor(command.expected);

  @override
  bool isStart(domain.ComparisonLearningCommand command) =>
      command.action is domain.StartComparisonRun;

  @override
  LearningCursorPosition? cursorFor(
    ComparisonLearningState state,
    String activityId,
  ) => state.slot?.activityId == activityId
      ? _toStorageCursor(state.slot!.cursor)
      : null;

  @override
  Future<ComparisonLearningState> loadState(
    LearningDatabase db,
    int scopeId, {
    required int revision,
    required int commitOrdinal,
  }) async {
    try {
      if (_domainScope.courseId != scope.courseId ||
          _domainScope.owner != scope.owner ||
          scope.family != LearningFamily.comparison ||
          revision < 0 ||
          revision > learningMaxSafeInteger ||
          commitOrdinal < 0 ||
          commitOrdinal > revision) {
        throw const LearningCorruptException();
      }

      final runRows = await db
          .customSelect(
            'SELECT r.scope_id, r.activity_id, r.activity_kind, r.run_generation, '
            'r.sequence, r.cursor_revision, r.content_binding_id, r.run_mode, '
            'r.finished, r.session_id, r.policy_revision, r.threshold_percent, '
            'r.run_start_round, r.checkpoint_json, r.latest_receipt_token, '
            'r.latest_receipt_payload, r.latest_receipt_before_generation, '
            'r.latest_receipt_before_sequence, '
            'r.latest_receipt_before_cursor_revision, '
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

      _requireNoRows(
        await db
            .customSelect(
              'SELECT 1 AS present FROM learning_attempt_values WHERE scope_id = ? LIMIT 1',
              variables: <Variable<Object>>[Variable<int>(scopeId)],
            )
            .get(),
      );
      _requireNoRows(
        await db
            .customSelect(
              'SELECT 1 AS present FROM learning_exposure WHERE scope_id = ? LIMIT 1',
              variables: <Variable<Object>>[Variable<int>(scopeId)],
            )
            .get(),
      );
      _requireNoRows(
        await db
            .customSelect(
              'SELECT 1 AS present FROM learning_best_scores WHERE scope_id = ? LIMIT 1',
              variables: <Variable<Object>>[Variable<int>(scopeId)],
            )
            .get(),
      );
      _requireNoRows(
        await db
            .customSelect(
              'SELECT 1 AS present FROM supported_sync_outbox WHERE scope_id = ? LIMIT 1',
              variables: <Variable<Object>>[Variable<int>(scopeId)],
            )
            .get(),
      );

      final historyReceipts = await _readHistoryReceipts(
        db,
        scopeId,
        revision: revision,
        commitOrdinal: commitOrdinal,
      );
      _SqlReceipt? latestReceipt;
      _PendingSlot? pendingSlot;
      if (runRows.isNotEmpty) {
        final read = _readRunRow(
          runRows.single,
          scopeId,
          revision: revision,
          commitOrdinal: commitOrdinal,
        );
        latestReceipt = read.latestReceipt;
        pendingSlot = read.slot;
      } else if (commitOrdinal != 0 || historyReceipts.isNotEmpty) {
        throw const LearningCorruptException();
      }

      final byToken = <String, _SqlReceipt>{};
      final byCursor = <String, _SqlReceipt>{};
      final byOrdinal = <int, _SqlReceipt>{};
      for (final receipt in historyReceipts) {
        _addReceipt(byToken, byCursor, byOrdinal, receipt);
      }
      if (latestReceipt != null) {
        _addReceipt(byToken, byCursor, byOrdinal, latestReceipt);
      }

      final attempts = await _readAttempts(
        db,
        scopeId,
        commitOrdinal,
        byCursor,
      );
      _validateAttemptReceiptLinks(attempts, byCursor);
      final mistakes = await _readMistakes(db, scopeId);
      final summaries = await _readSummaries(db, scopeId);
      final completions = await _readCompletions(db, scopeId);

      ComparisonSlot? slot;
      if (pendingSlot != null && latestReceipt != null) {
        final run = pendingSlot;
        slot = ComparisonSlot(
          scope: _domainScope,
          activityId: run.activityId,
          cursor: run.cursor,
          checkpoint: run.checkpoint,
          latestReceipt: latestReceipt.domainReceipt,
        );
      }

      final latestIsInHistory =
          latestReceipt != null &&
          historyReceipts.any(
            (receipt) => receipt.stored.token == latestReceipt!.stored.token,
          );
      final projectedReceipts = latestReceipt == null
          ? <ComparisonReceipt>[]
          : _latest(<ComparisonReceipt>[
              ...historyReceipts.map((receipt) => receipt.domainReceipt),
              if (!latestIsInHistory) latestReceipt.domainReceipt,
            ], 2000);
      final state = ComparisonLearningState(
        scope: _domainScope,
        revision: revision,
        commitOrdinal: commitOrdinal,
        slot: slot,
        attempts: attempts,
        receipts: projectedReceipts,
        mistakes: mistakes,
        summaries: summaries,
        completions: completions,
      );
      ComparisonLearningStateValidator.validate(state, catalogue);
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
            'before_sequence, before_cursor_revision, after_generation, '
            'after_sequence, after_cursor_revision, commit_ordinal, '
            'result_activity_id, result_generation, result_sequence, '
            'result_cursor_revision FROM learning_command_receipts '
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
    } on LearningCorruptException {
      rethrow;
    } on LearningContentChangedException {
      rethrow;
    } on Object catch (error) {
      throw LearningCorruptException(error);
    }
  }

  @override
  LearningSqlTransition<ComparisonLearningState, ComparisonCommit> evaluate({
    required ComparisonLearningState before,
    required domain.ComparisonLearningCommand command,
    required int nextRevision,
    required int nextCommitOrdinal,
    required DateTime committedAt,
  }) {
    try {
      ComparisonLearningStateValidator.validate(before, catalogue);
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
      final raw = transition.nextState;
      final attempts = _latest(<ComparisonPairAttempt>[
        ...before.attempts,
        ...transition.attempts,
      ], historyLimit);
      final receipts = _latest(raw.receipts, historyLimit);
      if (raw.mistakes.length > 4096 ||
          raw.summaries.length > 4096 ||
          raw.completions.length > 4096 ||
          attempts.length > 2000 ||
          receipts.length > 2000) {
        throw const LearningInvalidCommandException();
      }
      final state = ComparisonLearningState(
        scope: _domainScope,
        revision: nextRevision,
        commitOrdinal: nextCommitOrdinal,
        slot: transition.slot,
        attempts: attempts,
        receipts: receipts,
        mistakes: raw.mistakes,
        summaries: raw.summaries,
        completions: raw.completions,
      );
      ComparisonLearningStateValidator.validate(state, catalogue);
      return LearningSqlTransition(
        state: state,
        result: ComparisonCommit(
          state: state,
          slot: transition.slot,
          duplicate: false,
        ),
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
    ComparisonLearningState before,
    domain.ComparisonLearningCommand command,
    ComparisonLearningState after,
  ) async {
    try {
      ComparisonLearningStateValidator.validate(before, catalogue);
      ComparisonLearningStateValidator.validate(after, catalogue);
    } on FormatException catch (error) {
      throw LearningInvalidCommandException(error);
    }
    final slot = after.slot;
    if (slot == null ||
        slot.activityId != command.activityId ||
        slot.latestReceipt.token != command.token ||
        after.revision != before.revision + 1 ||
        after.commitOrdinal != before.commitOrdinal + 1) {
      throw const LearningInvalidCommandException();
    }

    final bindingId = await _ensureBinding(db, scopeId);
    await _writeRun(db, scopeId, bindingId, slot, command, after);
    await _writeReceipt(db, scopeId, command, slot, after);
    await _writeAttemptChanges(db, scopeId, before, after, command);
    await _pruneReceipts(db, scopeId, after.commitOrdinal);
    await _writeMistakes(db, scopeId, after.mistakes);
    await _writeSummaries(db, scopeId, after.summaries);
    await _writeCompletions(db, scopeId, after.completions);
  }

  @override
  ComparisonCommit duplicateResult({
    required ComparisonLearningState current,
    required domain.ComparisonLearningCommand command,
  }) {
    ComparisonLearningStateValidator.validate(current, catalogue);
    final slot = current.slot;
    if (slot == null || slot.activityId != command.activityId) {
      throw const LearningCorruptException();
    }
    return ComparisonCommit(state: current, slot: slot, duplicate: true);
  }

  Future<int> _ensureBinding(LearningDatabase db, int scopeId) async {
    final fingerprint = _catalogueFingerprint(catalogue);
    await db.customStatement(
      'INSERT INTO learning_content_bindings '
      '(scope_id, activity_id, content_revision, policy_kind, policy_revision, '
      'catalogue_fingerprint, section_fingerprint, annotation_hash, annotation_revision) '
      "VALUES (?, ?, ?, 'discoveryThreshold', 1, NULL, ?, NULL, NULL) "
      'ON CONFLICT DO NOTHING',
      [scopeId, catalogue.activityId, catalogue.contentRevision, fingerprint],
    );
    final rows = await db
        .customSelect(
          'SELECT id FROM learning_content_bindings WHERE scope_id = ? '
          'AND activity_id = ? AND content_revision = ? '
          "AND policy_kind = 'discoveryThreshold' AND policy_revision = 1 "
          'AND catalogue_fingerprint IS NULL AND section_fingerprint = ? '
          'AND annotation_hash IS NULL AND annotation_revision IS NULL',
          variables: <Variable<Object>>[
            Variable<int>(scopeId),
            Variable<String>(catalogue.activityId),
            Variable<int>(catalogue.contentRevision),
            Variable<String>(fingerprint),
          ],
        )
        .get();
    if (rows.length != 1) throw const LearningCorruptException();
    return rows.single.read<int>('id');
  }

  _ReadRun _readRunRow(
    QueryRow row,
    int scopeId, {
    required int revision,
    required int commitOrdinal,
  }) {
    final activityId = _requiredText(row.read<String>('activity_id'));
    if (row.read<int>('scope_id') != scopeId ||
        activityId != catalogue.activityId ||
        row.read<String>('activity_kind') != 'comparison' ||
        row.readNullable<String>('binding_activity_id') != activityId) {
      throw const LearningCorruptException();
    }
    if (row.readNullable<int>('binding_content_revision') !=
            catalogue.contentRevision ||
        row.readNullable<String>('binding_policy_kind') !=
            'discoveryThreshold' ||
        row.readNullable<int>('binding_policy_revision') != 1 ||
        row.readNullable<String>('binding_catalogue_fingerprint') != null ||
        row.readNullable<String>('binding_section_fingerprint') !=
            _catalogueFingerprint(catalogue) ||
        row.readNullable<String>('binding_annotation_hash') != null ||
        row.readNullable<int>('binding_annotation_revision') != null) {
      throw const LearningContentChangedException();
    }
    if (row.readNullable<String>('run_mode') != null ||
        row.readNullable<int>('run_start_round') != null ||
        row.read<int>('finished') != 0 ||
        row.read<int>('policy_revision') != 1) {
      throw const LearningCorruptException();
    }
    final threshold = row.read<int>('threshold_percent');
    if (threshold < 1 || threshold > 100) {
      throw const LearningCorruptException();
    }
    final policy = LessonPolicy(completionThresholdPercent: threshold);
    final cursor = ComparisonCursor(
      generation: row.read<int>('run_generation'),
      sequence: row.read<int>('sequence'),
      revision: row.read<int>('cursor_revision'),
    );
    final checkpointJson = row.read<String>('checkpoint_json');
    if (utf8.encode(checkpointJson).length > learningMaxCheckpointBytes) {
      throw const LearningCorruptException();
    }
    final checkpoint = _checkpointCodec.decode(
      checkpointJson,
      scope: _domainScope,
      activityId: activityId,
      catalogue: catalogue,
      policy: policy,
    );
    if (row.readNullable<String>('session_id') != checkpoint.sessionId) {
      throw const LearningCorruptException();
    }

    final before = ComparisonCursor(
      generation: row.read<int>('latest_receipt_before_generation'),
      sequence: row.read<int>('latest_receipt_before_sequence'),
      revision: row.read<int>('latest_receipt_before_cursor_revision'),
    );
    final receipt = _readSqlReceipt(
      activityId: activityId,
      token: row.read<String>('latest_receipt_token'),
      payload: row.read<String>('latest_receipt_payload'),
      before: before,
      after: cursor,
      commitOrdinal: row.read<int>('latest_receipt_commit_ordinal'),
      resultActivityId: activityId,
      result: cursor,
      revision: revision,
      scopeCommitOrdinal: commitOrdinal,
    );
    if (receipt.domainReceipt.commitOrdinal != commitOrdinal ||
        receipt.stored.commitOrdinal > commitOrdinal) {
      throw const LearningCorruptException();
    }
    return _ReadRun(
      slot: _PendingSlot(
        activityId: activityId,
        cursor: cursor,
        checkpoint: checkpoint,
      ),
      latestReceipt: receipt,
    );
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
          'before_sequence, before_cursor_revision, after_generation, '
          'after_sequence, after_cursor_revision, commit_ordinal, '
          'result_activity_id, result_generation, result_sequence, '
          'result_cursor_revision FROM learning_command_receipts '
          'WHERE scope_id = ? '
          'ORDER BY commit_ordinal, activity_id, after_generation, after_sequence',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    if (rows.length > 2000) throw const LearningCorruptException();
    final result = <_SqlReceipt>[];
    final tokens = <String>{};
    final cursors = <String>{};
    final ordinals = <int>{};
    for (final row in rows) {
      final receipt = _readHistoryReceipt(
        row,
        revision: revision,
        commitOrdinal: commitOrdinal,
      );
      if (!tokens.add(receipt.stored.token) ||
          !cursors.add(
            _cursorKey(
              receipt.stored.activityId,
              _fromStorageCursor(receipt.stored.after),
            ),
          ) ||
          !ordinals.add(receipt.stored.commitOrdinal)) {
        throw const LearningCorruptException();
      }
      if (result.isNotEmpty) {
        final previous = result.last.domainReceipt;
        if (receipt.domainReceipt.commitOrdinal != previous.commitOrdinal + 1 ||
            receipt.domainReceipt.before != previous.after) {
          throw const LearningCorruptException();
        }
      }
      result.add(receipt);
    }
    return result;
  }

  _SqlReceipt _readHistoryReceipt(
    QueryRow row, {
    required int revision,
    required int commitOrdinal,
  }) {
    final activityId = _requiredText(row.read<String>('activity_id'));
    final before = ComparisonCursor(
      generation: row.read<int>('before_generation'),
      sequence: row.read<int>('before_sequence'),
      revision: row.read<int>('before_cursor_revision'),
    );
    final after = ComparisonCursor(
      generation: row.read<int>('after_generation'),
      sequence: row.read<int>('after_sequence'),
      revision: row.read<int>('after_cursor_revision'),
    );
    return _readSqlReceipt(
      activityId: activityId,
      token: row.read<String>('token'),
      payload: row.read<String>('canonical_payload'),
      before: before,
      after: after,
      commitOrdinal: row.read<int>('commit_ordinal'),
      resultActivityId: _requiredText(row.read<String>('result_activity_id')),
      result: ComparisonCursor(
        generation: row.read<int>('result_generation'),
        sequence: row.read<int>('result_sequence'),
        revision: row.read<int>('result_cursor_revision'),
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
    final after = ComparisonCursor(
      generation: row.read<int>('run_generation'),
      sequence: row.read<int>('sequence'),
      revision: row.read<int>('cursor_revision'),
    );
    return _readSqlReceipt(
      activityId: activityId,
      token: row.read<String>('latest_receipt_token'),
      payload: row.read<String>('latest_receipt_payload'),
      before: ComparisonCursor(
        generation: row.read<int>('latest_receipt_before_generation'),
        sequence: row.read<int>('latest_receipt_before_sequence'),
        revision: row.read<int>('latest_receipt_before_cursor_revision'),
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
    required ComparisonCursor before,
    required ComparisonCursor after,
    required int commitOrdinal,
    required String resultActivityId,
    required ComparisonCursor result,
    required int revision,
    required int scopeCommitOrdinal,
  }) {
    final command = ComparisonLearningCommandCodec.decodeCanonicalCommand(
      payload,
      scope: _domainScope,
      catalogue: catalogue,
    );
    if (command.scope != _domainScope ||
        command.activityId != activityId ||
        command.token != token ||
        command.expected != before ||
        command.expectedScopeRevision >= revision ||
        command.expectedScopeRevision > learningMaxSafeInteger ||
        resultActivityId != activityId ||
        result != after ||
        commitOrdinal < 1 ||
        commitOrdinal > scopeCommitOrdinal) {
      throw const LearningCorruptException();
    }
    final domainReceipt = ComparisonReceipt(
      scope: _domainScope,
      activityId: activityId,
      generation: after.generation,
      sequence: after.sequence,
      token: token,
      canonicalCommand: ComparisonLearningCommandCodec.legacyCanonicalCommand(
        command,
      ),
      before: before,
      after: after,
      commitOrdinal: commitOrdinal,
    );
    return _SqlReceipt(
      stored: LearningStoredReceipt(
        activityId: activityId,
        token: token,
        canonicalPayload: payload,
        before: _toStorageCursor(before),
        after: _toStorageCursor(after),
        commitOrdinal: commitOrdinal,
        resultActivityId: resultActivityId,
      ),
      command: command,
      domainReceipt: domainReceipt,
    );
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
        commitOrdinal < 0 ||
        commitOrdinal > revision) {
      throw const LearningCorruptException();
    }
    return (revision: revision, commitOrdinal: commitOrdinal);
  }

  void _addReceipt(
    Map<String, _SqlReceipt> byToken,
    Map<String, _SqlReceipt> byCursor,
    Map<int, _SqlReceipt> byOrdinal,
    _SqlReceipt receipt,
  ) {
    final tokenReceipt = byToken[receipt.stored.token];
    if (tokenReceipt != null &&
        !_sameStoredReceipt(tokenReceipt.stored, receipt.stored)) {
      throw const LearningCorruptException();
    }
    final cursorKey = _cursorKey(
      receipt.stored.activityId,
      _fromStorageCursor(receipt.stored.after),
    );
    final cursorReceipt = byCursor[cursorKey];
    if (cursorReceipt != null &&
        !_sameStoredReceipt(cursorReceipt.stored, receipt.stored)) {
      throw const LearningCorruptException();
    }
    final ordinalReceipt = byOrdinal[receipt.stored.commitOrdinal];
    if (ordinalReceipt != null &&
        !_sameStoredReceipt(ordinalReceipt.stored, receipt.stored)) {
      throw const LearningCorruptException();
    }
    byToken[receipt.stored.token] = receipt;
    byCursor[cursorKey] = receipt;
    byOrdinal[receipt.stored.commitOrdinal] = receipt;
  }

  Future<List<ComparisonPairAttempt>> _readAttempts(
    LearningDatabase db,
    int scopeId,
    int commitOrdinal,
    Map<String, _SqlReceipt> byCursor,
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
    if (rows.length > 2000) throw const LearningCorruptException();

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

    final attemptIds = <String>{};
    final attempts = <ComparisonPairAttempt>[];
    for (final row in rows) {
      final attemptId = _requiredText(row.read<String>('attempt_id'));
      if (!attemptIds.add(attemptId)) throw const LearningCorruptException();
      final activityId = _requiredText(row.read<String>('activity_id'));
      final pairId = _requiredText(row.readNullable<String>('item_id'));
      final generation = row.read<int>('run_generation');
      final sequence = row.read<int>('command_sequence');
      final attemptCommitOrdinal = row.read<int>('commit_ordinal');
      final round = row.read<int>('round');
      if (row.read<int>('batch_index') != 0 ||
          row.readNullable<int>('item_occurrence') != null ||
          row.read<int>('content_revision') != catalogue.contentRevision ||
          attemptCommitOrdinal < 1 ||
          attemptCommitOrdinal > commitOrdinal ||
          row.read<String>('answer_kind') != 'comparisonPair' ||
          row.readNullable<String>('skill') != null ||
          row.readNullable<String>('origin') != null ||
          row.readNullable<int>('assistance_mask') != null ||
          row.readNullable<String>('content_state') != null ||
          row.readNullable<String>('audio_source') != null ||
          row.readNullable<int>('teaching_exposed') != null ||
          row.readNullable<String>('section_id') != null ||
          row.readNullable<String>('sentence_id') != null ||
          row.readNullable<String>('annotation_hash') != null ||
          row.readNullable<int>('annotation_revision') != null ||
          activityId != catalogue.activityId) {
        throw const LearningCorruptException();
      }
      final correct = _boolFromInt(row.read<int>('correct'));
      final afterDebrief = _boolFromInt(row.read<int>('after_debrief'));
      final selected = _enumByName(
        PhonemeRelation.values,
        row.readNullable<String>('selected_relation'),
      );
      final expected = _enumByName(
        PhonemeRelation.values,
        row.readNullable<String>('expected_relation'),
      );
      final presentation = _enumByName(
        AttemptPresentation.values,
        row.readNullable<String>('presentation'),
      );
      final receiptKey = _cursorKey(
        activityId,
        ComparisonCursor(
          generation: generation,
          sequence: sequence,
          revision: 0,
        ),
      );
      _validateAttemptRowIdentity(
        attemptId,
        _domainScope.storageKey,
        activityId,
        generation,
        sequence,
        byCursor[receiptKey],
      );
      final linkedReceipt = byCursor[receiptKey];
      if (linkedReceipt != null &&
          linkedReceipt.stored.commitOrdinal != attemptCommitOrdinal) {
        throw const LearningCorruptException();
      }
      final evidence =
          evidenceByAttempt.remove(attemptId) ?? const <QueryRow>[];
      if (evidence.length != 2) throw const LearningCorruptException();
      final observations = <ComparisonPlaybackObservation>[
        for (var index = 0; index < evidence.length; index++)
          _readEvidence(
            evidence[index],
            index,
            activityId,
            generation,
            round,
            pairId,
          ),
      ];
      attempts.add(
        ComparisonPairAttempt(
          scope: _domainScope,
          activityId: activityId,
          pairId: pairId,
          contentRevision: catalogue.contentRevision,
          runGeneration: generation,
          round: round,
          sequence: sequence,
          selectedRelation: selected,
          expectedRelation: expected,
          correct: correct,
          presentation: presentation,
          afterDebrief: afterDebrief,
          observations: observations,
          answeredAt: _dateFromMicros(row.read<int>('answered_at_us')),
          committedAt: _dateFromMicros(row.read<int>('committed_at_us')),
        ),
      );
    }
    if (evidenceByAttempt.isNotEmpty) throw const LearningCorruptException();
    return attempts;
  }

  ComparisonPlaybackObservation _readEvidence(
    QueryRow row,
    int index,
    String activityId,
    int generation,
    int round,
    String pairId,
  ) {
    final slot = index == 0 ? ComparisonSample.a : ComparisonSample.b;
    if (row.read<int>('evidence_index') != index ||
        row.read<String>('evidence_kind') != 'comparisonPlayback' ||
        row.readNullable<String>('slot') != slot.name ||
        row.readNullable<String>('outcome') !=
            CourseAudioOutcome.completed.name ||
        row.readNullable<String>('source') !=
            CourseAudioSource.unverifiedRecording.name ||
        row.readNullable<String>('activity_id') != activityId ||
        row.readNullable<int>('run_generation') != generation ||
        row.readNullable<int>('round') != round ||
        row.readNullable<String>('pair_id') != pairId ||
        row.readNullable<String>('section_id') != null ||
        row.readNullable<String>('item_id') != null ||
        row.readNullable<String>('sentence_id') != null ||
        row.readNullable<String>('audio_ref_id') != null ||
        row.readNullable<String>('annotation_hash') != null ||
        row.readNullable<int>('annotation_revision') != null ||
        row.readNullable<int>('content_revision') != null) {
      throw const LearningCorruptException();
    }
    final referenceId = _requiredText(row.readNullable<String>('reference_id'));
    final exercise = catalogue.exercise(pairId);
    final expectedReference = index == 0
        ? exercise.sampleA.referenceId
        : exercise.sampleB.referenceId;
    if (referenceId != expectedReference) {
      throw const LearningCorruptException();
    }
    return ComparisonPlaybackObservation(
      slot: slot,
      referenceId: referenceId,
      outcome: CourseAudioOutcome.completed,
      source: CourseAudioSource.unverifiedRecording,
      activityId: activityId,
      runGeneration: generation,
      round: round,
      pairId: pairId,
      profile: _domainScope,
      uiGeneration: row.read<int>('ui_generation'),
    );
  }

  void _validateAttemptReceiptLinks(
    List<ComparisonPairAttempt> attempts,
    Map<String, _SqlReceipt> byCursor,
  ) {
    for (final attempt in attempts) {
      final key = _cursorKey(
        attempt.activityId,
        ComparisonCursor(
          generation: attempt.runGeneration,
          sequence: attempt.sequence,
          revision: 0,
        ),
      );
      final receipt = byCursor[key];
      if (receipt == null) continue;
      final command = receipt.command;
      if (command.action is! domain.AnswerComparisonPair) {
        throw const LearningCorruptException();
      }
      final answer = (command.action as domain.AnswerComparisonPair).answer;
      if (command.submittedAt != attempt.answeredAt ||
          answer.selectedRelation != attempt.selectedRelation ||
          answer.expectedRelationSnapshot != attempt.expectedRelation ||
          !_sameObservations(answer.observations, attempt.observations)) {
        throw const LearningCorruptException();
      }
    }
  }

  Future<Map<ComparisonPairMistakeKey, ComparisonPairMistake>> _readMistakes(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT family, activity_id, item_id, target_sound, skill, pair_id, '
          'section_id, sentence_id, audio_ref_id, annotation_hash, annotation_revision, '
          'content_revision, first_wrong_attempt_id, latest_wrong_attempt_id, '
          'first_wrong_at_us, latest_wrong_at_us, failure_count, last_run_generation '
          'FROM learning_mistakes WHERE scope_id = ? ORDER BY activity_id, pair_id',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final result = <ComparisonPairMistakeKey, ComparisonPairMistake>{};
    for (final row in rows) {
      if (row.read<String>('family') != 'comparison' ||
          row.readNullable<String>('item_id') != null ||
          row.readNullable<String>('target_sound') != null ||
          row.readNullable<String>('skill') != null ||
          row.readNullable<String>('section_id') != null ||
          row.readNullable<String>('sentence_id') != null ||
          row.readNullable<String>('audio_ref_id') != null ||
          row.readNullable<String>('annotation_hash') != null ||
          row.readNullable<int>('annotation_revision') != null ||
          row.readNullable<String>('first_wrong_attempt_id') != null ||
          row.readNullable<String>('latest_wrong_attempt_id') != null ||
          row.readNullable<int>('last_run_generation') != null) {
        throw const LearningCorruptException();
      }
      final key = ComparisonPairMistakeKey(
        scope: _domainScope,
        activityId: _requiredText(row.readNullable<String>('activity_id')),
        pairId: _requiredText(row.readNullable<String>('pair_id')),
        contentRevision: row.read<int>('content_revision'),
      );
      final mistake = ComparisonPairMistake(
        scope: _domainScope,
        key: key,
        firstWrongAt: _dateFromMicros(row.read<int>('first_wrong_at_us')),
        latestWrongAt: _dateFromMicros(row.read<int>('latest_wrong_at_us')),
        failureCount: row.read<int>('failure_count'),
      );
      if (result.containsKey(key)) throw const LearningCorruptException();
      result[key] = mistake;
    }
    return result;
  }

  Future<Map<ComparisonSummaryKey, ComparisonPairSummary>> _readSummaries(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT family, activity_id, sound, skill, origin, presentation, assistance_mask, '
          'pair_id, section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
          'annotation_revision, content_revision, bucket, correct, total '
          'FROM learning_summaries WHERE scope_id = ? ORDER BY activity_id, pair_id, bucket',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final buckets = <ComparisonSummaryKey, Map<String, ComparisonCount>>{};
    for (final row in rows) {
      if (row.read<String>('family') != 'comparison' ||
          row.readNullable<String>('sound') != null ||
          row.readNullable<String>('skill') != null ||
          row.readNullable<String>('origin') != null ||
          row.readNullable<String>('presentation') != null ||
          row.readNullable<int>('assistance_mask') != null ||
          row.readNullable<String>('section_id') != null ||
          row.readNullable<String>('item_id') != null ||
          row.readNullable<String>('sentence_id') != null ||
          row.readNullable<String>('audio_ref_id') != null ||
          row.readNullable<String>('annotation_hash') != null ||
          row.readNullable<int>('annotation_revision') != null) {
        throw const LearningCorruptException();
      }
      final key = ComparisonSummaryKey(
        scope: _domainScope,
        activityId: _requiredText(row.readNullable<String>('activity_id')),
        pairId: _requiredText(row.readNullable<String>('pair_id')),
        contentRevision:
            row.readNullable<int>('content_revision') ??
            (throw const LearningCorruptException()),
      );
      final bucket = row.read<String>('bucket');
      if (!const {
        'firstInRun',
        'repeatInRun',
        'afterDebrief',
      }.contains(bucket)) {
        throw const LearningCorruptException();
      }
      final count = ComparisonCount(
        correct: row.read<int>('correct'),
        total: row.read<int>('total'),
      );
      final byBucket = buckets.putIfAbsent(
        key,
        () => <String, ComparisonCount>{},
      );
      if (byBucket.containsKey(bucket)) throw const LearningCorruptException();
      byBucket[bucket] = count;
    }
    return <ComparisonSummaryKey, ComparisonPairSummary>{
      for (final entry in buckets.entries)
        entry.key: ComparisonPairSummary(
          key: entry.key,
          firstInRun:
              entry.value['firstInRun'] ??
              ComparisonCount(correct: 0, total: 0),
          repeatInRun:
              entry.value['repeatInRun'] ??
              ComparisonCount(correct: 0, total: 0),
          afterDebrief:
              entry.value['afterDebrief'] ??
              ComparisonCount(correct: 0, total: 0),
        ),
    };
  }

  Future<List<ComparisonCompletion>> _readCompletions(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT activity_id, content_revision, policy_kind, policy_revision, '
          'threshold_percent, committed_at_us FROM learning_completions '
          'WHERE scope_id = ? ORDER BY activity_id, content_revision, policy_kind, '
          'policy_revision, threshold_percent',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final result = <ComparisonCompletion>[];
    for (final row in rows) {
      if (row.read<String>('activity_id') != catalogue.activityId ||
          row.read<int>('content_revision') != catalogue.contentRevision ||
          row.read<String>('policy_kind') != 'discoveryThreshold' ||
          row.read<int>('policy_revision') != 1) {
        throw const LearningCorruptException();
      }
      result.add(
        ComparisonCompletion(
          scope: _domainScope,
          activityId: catalogue.activityId,
          contentRevision: catalogue.contentRevision,
          policyRevision: 1,
          thresholdPercent: row.read<int>('threshold_percent'),
          committedAt: _dateFromMicros(row.read<int>('committed_at_us')),
        ),
      );
    }
    if (result.length > 4096) throw const LearningCorruptException();
    return result;
  }

  Future<void> _writeRun(
    LearningDatabase db,
    int scopeId,
    int bindingId,
    ComparisonSlot slot,
    domain.ComparisonLearningCommand command,
    ComparisonLearningState after,
  ) async {
    final session = LessonSectionSession.fromJson(
      Map<String, dynamic>.from(slot.checkpoint.sessionJson),
      itemIds: catalogue.exercises.map((exercise) => exercise.id).toList(),
      contentRevision: catalogue.contentRevision,
    );
    final checkpointJson = _checkpointCodec.encode(slot.checkpoint);
    final payload = ComparisonLearningCommandCodec.canonicalCommand(command);
    await db.customStatement(
      'INSERT INTO learning_runs '
      '(scope_id, activity_id, activity_kind, run_generation, sequence, cursor_revision, '
      'content_binding_id, run_mode, finished, session_id, policy_revision, '
      'threshold_percent, run_start_round, checkpoint_json, latest_receipt_token, '
      'latest_receipt_payload, latest_receipt_before_generation, '
      'latest_receipt_before_sequence, latest_receipt_before_cursor_revision, '
      'latest_receipt_commit_ordinal) '
      "VALUES (?, ?, 'comparison', ?, ?, ?, ?, NULL, 0, ?, 1, ?, NULL, ?, ?, ?, ?, ?, ?, ?) "
      'ON CONFLICT(scope_id, activity_id) DO UPDATE SET '
      'activity_kind = excluded.activity_kind, run_generation = excluded.run_generation, '
      'sequence = excluded.sequence, cursor_revision = excluded.cursor_revision, '
      'content_binding_id = excluded.content_binding_id, run_mode = NULL, finished = 0, '
      'session_id = excluded.session_id, policy_revision = 1, '
      'threshold_percent = excluded.threshold_percent, run_start_round = NULL, '
      'checkpoint_json = excluded.checkpoint_json, '
      'latest_receipt_token = excluded.latest_receipt_token, '
      'latest_receipt_payload = excluded.latest_receipt_payload, '
      'latest_receipt_before_generation = excluded.latest_receipt_before_generation, '
      'latest_receipt_before_sequence = excluded.latest_receipt_before_sequence, '
      'latest_receipt_before_cursor_revision = excluded.latest_receipt_before_cursor_revision, '
      'latest_receipt_commit_ordinal = excluded.latest_receipt_commit_ordinal',
      [
        scopeId,
        slot.activityId,
        slot.cursor.generation,
        slot.cursor.sequence,
        slot.cursor.revision,
        bindingId,
        slot.checkpoint.sessionId,
        session.policy.completionThresholdPercent,
        checkpointJson,
        command.token,
        payload,
        slot.latestReceipt.before.generation,
        slot.latestReceipt.before.sequence,
        slot.latestReceipt.before.revision,
        after.commitOrdinal,
      ],
    );
  }

  Future<void> _writeReceipt(
    LearningDatabase db,
    int scopeId,
    domain.ComparisonLearningCommand command,
    ComparisonSlot slot,
    ComparisonLearningState after,
  ) async {
    await db.customStatement(
      'INSERT INTO learning_command_receipts '
      '(scope_id, activity_id, token, canonical_payload, before_generation, '
      'before_sequence, before_cursor_revision, after_generation, after_sequence, '
      'after_cursor_revision, commit_ordinal, result_activity_id, result_generation, '
      'result_sequence, result_cursor_revision) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        scopeId,
        command.activityId,
        command.token,
        ComparisonLearningCommandCodec.canonicalCommand(command),
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
    final cutoff = latestCommitOrdinal - historyLimit + 1;
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
    ComparisonLearningState before,
    ComparisonLearningState after,
    domain.ComparisonLearningCommand command,
  ) async {
    final beforeKeys = before.attempts.map(_attemptKey).toSet();
    final afterByKey = <String, ComparisonPairAttempt>{
      for (final attempt in after.attempts) _attemptKey(attempt): attempt,
    };
    for (final attempt in before.attempts) {
      final key = _attemptKey(attempt);
      if (afterByKey.containsKey(key)) continue;
      final rows = await db
          .customSelect(
            'SELECT attempt_id FROM learning_attempts WHERE scope_id = ? '
            'AND activity_id = ? AND run_generation = ? AND command_sequence = ?',
            variables: <Variable<Object>>[
              Variable<int>(scopeId),
              Variable<String>(attempt.activityId),
              Variable<int>(attempt.runGeneration),
              Variable<int>(attempt.sequence),
            ],
          )
          .get();
      if (rows.length > 1) throw const LearningCorruptException();
      if (rows.isNotEmpty) {
        final attemptId = rows.single.read<String>('attempt_id');
        await db.customStatement(
          'DELETE FROM learning_attempt_evidence WHERE scope_id = ? AND attempt_id = ?',
          [scopeId, attemptId],
        );
        await db.customStatement(
          'DELETE FROM learning_attempts WHERE scope_id = ? AND attempt_id = ?',
          [scopeId, attemptId],
        );
      }
    }
    for (final entry in afterByKey.entries) {
      if (beforeKeys.contains(entry.key)) continue;
      if (command.action is! domain.AnswerComparisonPair ||
          command.activityId != entry.value.activityId ||
          command.expected.generation != entry.value.runGeneration ||
          entry.value.sequence != command.expected.sequence + 1) {
        throw const LearningInvalidCommandException();
      }
      await _insertAttempt(
        db,
        scopeId,
        _attemptId(
          _domainScope.storageKey,
          command.activityId,
          entry.value.runGeneration,
          entry.value.sequence,
          command.token,
        ),
        entry.value,
        after.commitOrdinal,
      );
    }
  }

  Future<void> _insertAttempt(
    LearningDatabase db,
    int scopeId,
    String attemptId,
    ComparisonPairAttempt attempt,
    int commitOrdinal,
  ) async {
    await db.customStatement(
      'INSERT INTO learning_attempts '
      '(scope_id, attempt_id, activity_id, run_generation, command_sequence, batch_index, '
      'item_id, item_occurrence, content_revision, commit_ordinal, answered_at_us, '
      'committed_at_us, answer_kind, correct, skill, origin, presentation, assistance_mask, '
      'content_state, audio_source, round, after_debrief, teaching_exposed, selected_relation, '
      'expected_relation, section_id, sentence_id, annotation_hash, annotation_revision) '
      "VALUES (?, ?, ?, ?, ?, 0, ?, NULL, ?, ?, ?, ?, 'comparisonPair', ?, NULL, NULL, ?, NULL, NULL, NULL, ?, ?, NULL, ?, ?, NULL, NULL, NULL, NULL)",
      [
        scopeId,
        attemptId,
        attempt.activityId,
        attempt.runGeneration,
        attempt.sequence,
        attempt.pairId,
        attempt.contentRevision,
        commitOrdinal,
        _dateMicros(attempt.answeredAt),
        _dateMicros(attempt.committedAt),
        attempt.correct ? 1 : 0,
        attempt.presentation.name,
        attempt.round,
        attempt.afterDebrief ? 1 : 0,
        attempt.selectedRelation.name,
        attempt.expectedRelation.name,
      ],
    );
    for (var index = 0; index < attempt.observations.length; index++) {
      final observation = attempt.observations[index];
      await db.customStatement(
        'INSERT INTO learning_attempt_evidence '
        '(scope_id, attempt_id, evidence_index, evidence_kind, slot, reference_id, '
        'outcome, source, activity_id, run_generation, round, pair_id, ui_generation, '
        'section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
        'annotation_revision, content_revision) '
        "VALUES (?, ?, ?, 'comparisonPlayback', ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL)",
        [
          scopeId,
          attemptId,
          index,
          observation.slot.name,
          observation.referenceId,
          observation.outcome.name,
          observation.source?.name,
          observation.activityId,
          observation.runGeneration,
          observation.round,
          observation.pairId,
          observation.uiGeneration,
        ],
      );
    }
  }

  Future<void> _writeMistakes(
    LearningDatabase db,
    int scopeId,
    Map<ComparisonPairMistakeKey, ComparisonPairMistake> mistakes,
  ) async {
    await db.customStatement(
      "DELETE FROM learning_mistakes WHERE scope_id = ? AND family = 'comparison'",
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
        "VALUES (?, 'comparison', ?, NULL, NULL, NULL, ?, NULL, NULL, NULL, NULL, NULL, ?, NULL, NULL, ?, ?, ?, NULL)",
        [
          scopeId,
          key.activityId,
          key.pairId,
          key.contentRevision,
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
    Map<ComparisonSummaryKey, ComparisonPairSummary> summaries,
  ) async {
    await db.customStatement(
      "DELETE FROM learning_summaries WHERE scope_id = ? AND family = 'comparison'",
      [scopeId],
    );
    for (final entry in summaries.entries) {
      for (final bucket in <(String, ComparisonCount)>[
        ('firstInRun', entry.value.firstInRun),
        ('repeatInRun', entry.value.repeatInRun),
        ('afterDebrief', entry.value.afterDebrief),
      ]) {
        await db.customStatement(
          'INSERT INTO learning_summaries '
          '(scope_id, family, activity_id, sound, skill, origin, presentation, assistance_mask, '
          'pair_id, section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
          'annotation_revision, content_revision, bucket, correct, total) '
          "VALUES (?, 'comparison', ?, NULL, NULL, NULL, NULL, NULL, ?, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?, ?, ?)",
          [
            scopeId,
            entry.key.activityId,
            entry.key.pairId,
            entry.key.contentRevision,
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
    List<ComparisonCompletion> completions,
  ) async {
    for (final completion in completions) {
      await db.customStatement(
        'INSERT INTO learning_completions '
        '(scope_id, activity_id, content_revision, policy_kind, policy_revision, '
        'threshold_percent, committed_at_us) '
        "VALUES (?, ?, ?, 'discoveryThreshold', ?, ?, ?) ON CONFLICT DO NOTHING",
        [
          scopeId,
          completion.activityId,
          completion.contentRevision,
          completion.policyRevision,
          completion.thresholdPercent,
          _dateMicros(completion.committedAt),
        ],
      );
    }
  }
}

final class _ReadRun {
  const _ReadRun({required this.slot, required this.latestReceipt});
  final _PendingSlot slot;
  final _SqlReceipt latestReceipt;
}

final class _PendingSlot {
  const _PendingSlot({
    required this.activityId,
    required this.cursor,
    required this.checkpoint,
  });
  final String activityId;
  final ComparisonCursor cursor;
  final ComparisonCheckpoint checkpoint;
}

final class _SqlReceipt {
  const _SqlReceipt({
    required this.stored,
    required this.command,
    required this.domainReceipt,
  });
  final LearningStoredReceipt stored;
  final domain.ComparisonLearningCommand command;
  final ComparisonReceipt domainReceipt;
}

List<T> _latest<T>(List<T> values, int limit) =>
    values.length <= limit ? values : values.sublist(values.length - limit);

String _attemptKey(ComparisonPairAttempt attempt) =>
    jsonEncode([attempt.activityId, attempt.runGeneration, attempt.sequence]);

String _attemptId(
  String storageKey,
  String activityId,
  int generation,
  int sequence,
  String token,
) => jsonEncode([storageKey, activityId, generation, sequence, token]);

String _cursorKey(String activityId, ComparisonCursor cursor) =>
    jsonEncode([activityId, cursor.generation, cursor.sequence]);

LearningCursorPosition _toStorageCursor(ComparisonCursor cursor) =>
    LearningCursorPosition(
      generation: cursor.generation,
      sequence: cursor.sequence,
      revision: cursor.revision,
    );

ComparisonCursor _fromStorageCursor(LearningCursorPosition cursor) =>
    ComparisonCursor(
      generation: cursor.generation,
      sequence: cursor.sequence,
      revision: cursor.revision,
    );

void _validateAttemptRowIdentity(
  String attemptId,
  String storageKey,
  String activityId,
  int generation,
  int sequence,
  _SqlReceipt? receipt,
) {
  final decoded = jsonDecode(attemptId);
  if (decoded is! List ||
      decoded.length != 5 ||
      decoded[0] is! String ||
      decoded[0] != storageKey ||
      decoded[1] != activityId ||
      decoded[2] != generation ||
      decoded[3] != sequence ||
      decoded[4] is! String ||
      !RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(decoded[4] as String) ||
      jsonEncode(decoded) != attemptId ||
      (receipt != null && decoded[4] != receipt.stored.token)) {
    throw const LearningCorruptException();
  }
}

void _requireNoRows(List<QueryRow> rows) {
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

T _enumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null) throw const LearningCorruptException();
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw const LearningCorruptException();
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

bool _sameObservations(
  List<ComparisonPlaybackObservation> left,
  List<ComparisonPlaybackObservation> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    final a = left[index];
    final b = right[index];
    if (a.slot != b.slot ||
        a.referenceId != b.referenceId ||
        a.outcome != b.outcome ||
        a.source != b.source ||
        a.activityId != b.activityId ||
        a.runGeneration != b.runGeneration ||
        a.round != b.round ||
        a.pairId != b.pairId ||
        a.uiGeneration != b.uiGeneration ||
        a.profile != b.profile) {
      return false;
    }
  }
  return true;
}

String _catalogueFingerprint(ComparisonCatalogue catalogue) {
  final content = jsonEncode([
    catalogue.activityId,
    catalogue.sectionId,
    catalogue.contentRevision,
    for (final exercise in catalogue.exercises)
      [
        exercise.id,
        exercise.activityId,
        exercise.sectionId,
        exercise.contentRevision,
        exercise.purpose.name,
        exercise.reviewState.name,
        exercise.instruction,
        [
          exercise.sampleA.slot.name,
          exercise.sampleA.referenceId,
          exercise.sampleA.target.phonemeId,
          exercise.sampleA.target.phonemeOrdinal,
        ],
        [
          exercise.sampleB.slot.name,
          exercise.sampleB.referenceId,
          exercise.sampleB.target.phonemeId,
          exercise.sampleB.target.phonemeOrdinal,
        ],
        exercise.expectedRelation.name,
        exercise.debriefNote,
      ],
  ]);
  var first = 0x811c9dc5;
  var second = 0x9e3779b9;
  for (final byte in utf8.encode(content)) {
    first = ((first ^ byte) * 0x01000193) & 0xffffffff;
    second = ((second ^ (byte + 0x51)) * 0x01000193) & 0xffffffff;
  }
  return 'comparison-v1-${first.toRadixString(16).padLeft(8, '0')}'
      '${second.toRadixString(16).padLeft(8, '0')}';
}
