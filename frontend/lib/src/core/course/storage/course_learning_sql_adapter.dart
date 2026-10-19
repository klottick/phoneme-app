import 'dart:convert';

import 'package:drift/drift.dart';

import '../course_attempt.dart';
import '../course_learning_checkpoint.dart';
import 'course_learning_checkpoint_codec.dart';
import '../course_learning_command.dart';
import '../course_learning_command_codec.dart';
import '../course_learning_error.dart';
import '../course_learning_registry.dart';
import '../course_learning_state.dart';
import 'course_learning_state_validator.dart';
import '../course_learning_store.dart' show LearningCommit;
import '../course_learning_sync.dart';
import '../course_learning_transition.dart';
import '../course_skill_summary.dart';
import '../learning_storage_types.dart';
import '../lesson_policy.dart';
import 'learning_database.dart' show LearningDatabase;
import 'learning_sql_transaction.dart';
import 'learning_storage_scope.dart';
import 'learning_tables.dart';

/// Maps course learning commands and state to the shared normalized SQL
/// transaction protocol. This adapter is independent of the active
/// preferences-backed repository.
final class CourseLearningSqlAdapter
    implements
        SqliteLearningProfileAdapter<
          CourseLearningState,
          LearningCommand,
          LearningCommit
        > {
  CourseLearningSqlAdapter({
    required LearningScope scope,
    required this.transitions,
    required this.historyLimit,
  }) : _domainScope = scope,
       scope = LearningStorageScope(
         owner: scope.owner,
         courseId: scope.courseId,
         family: LearningFamily.course,
       ) {
    if (historyLimit < 1 || historyLimit > 2000) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
  }

  final LearningScope _domainScope;
  @override
  final LearningStorageScope scope;
  final LearningTransitionEngine transitions;
  final int historyLimit;
  final CourseLearningCheckpointCodec _checkpointCodec =
      const CourseLearningCheckpointCodec();
  final SupportedProgressProjector _projector =
      const SupportedProgressProjector();

  LearningRegistry get registry => transitions.registry;

  @override
  String commandActivityId(LearningCommand command) => command.activityId;

  @override
  String commandToken(LearningCommand command) => command.token;

  @override
  String commandCanonicalPayload(LearningCommand command) =>
      CourseLearningCommandCodec.canonicalCommand(command);

  @override
  int commandAuthGeneration(LearningCommand command) => command.authGeneration;

  @override
  int commandExpectedScopeRevision(LearningCommand command) =>
      command.expectedScopeRevision;

  @override
  LearningCursorPosition commandExpectedCursor(LearningCommand command) =>
      _cursor(command.expected);

  @override
  bool isStart(LearningCommand command) => command.action is StartLearningRun;

  @override
  LearningCursorPosition? cursorFor(
    CourseLearningState state,
    String activityId,
  ) {
    final slot = state.activities[activityId];
    return slot == null ? null : _cursor(slot.cursor);
  }

  @override
  Future<CourseLearningState> loadState(
    LearningDatabase db,
    int scopeId, {
    required int revision,
    required int commitOrdinal,
  }) async {
    try {
      if (_domainScope.courseId != scope.courseId ||
          _domainScope.owner != scope.owner ||
          scope.family != LearningFamily.course ||
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
            'b.catalogue_fingerprint AS binding_catalogue_fingerprint '
            'FROM learning_runs r LEFT JOIN learning_content_bindings b '
            'ON b.id = r.content_binding_id AND b.scope_id = r.scope_id '
            'WHERE r.scope_id = ? ORDER BY r.activity_id',
            variables: <Variable<Object>>[Variable<int>(scopeId)],
          )
          .get();

      final pendingSlots = <String, _PendingSlot>{};
      final latestReceipts = <String, _SqlReceipt>{};
      for (final row in runRows) {
        final pending = _readRunRow(row, scopeId, revision, commitOrdinal);
        if (pendingSlots.containsKey(pending.activityId)) {
          throw const LearningCorruptException();
        }
        pendingSlots[pending.activityId] = pending;
        latestReceipts[pending.activityId] = pending.latestReceipt;
      }

      final historyReceipts = await _readHistoryReceipts(
        db,
        scopeId,
        revision: revision,
        commitOrdinal: commitOrdinal,
      );
      final receiptsByToken = <String, _SqlReceipt>{};
      final receiptsByCursor = <String, _SqlReceipt>{};
      for (final receipt in historyReceipts) {
        _addReceipt(receiptsByToken, receiptsByCursor, receipt);
      }
      for (final receipt in latestReceipts.values) {
        _addReceipt(receiptsByToken, receiptsByCursor, receipt);
      }

      final exposures = await _readExposures(db, scopeId);
      final activities = <String, ActivitySlot>{};
      for (final pending in pendingSlots.values) {
        final latest = latestReceipts[pending.activityId]!;
        final slot = ActivitySlot(
          activityId: pending.activityId,
          kind: pending.kind,
          contentRevision: pending.contentRevision,
          cursor: pending.cursor,
          options: pending.options,
          snapshot: pending.snapshot,
          exposures:
              exposures.remove(pending.activityId) ??
              const <ItemContextKey, ItemExposure>{},
          latestReceipt: CommandReceipt(
            token: latest.stored.token,
            canonicalCommand: latest.legacyCanonical,
            before: _slotCursor(latest.stored.before),
            after: _slotCursor(latest.stored.after),
            commitOrdinal: latest.stored.commitOrdinal,
          ),
        );
        activities[pending.activityId] = slot;
      }
      if (exposures.isNotEmpty) throw const LearningCorruptException();

      final history = await _readAttemptHistory(
        db,
        scopeId,
        receiptsByCursor,
        commitOrdinal: commitOrdinal,
      );
      final mistakes = await _readMistakes(db, scopeId);
      final summaries = await _readSummaries(db, scopeId);
      final completions = await _readCompletions(db, scopeId);
      final bestScores = await _readBestScores(db, scopeId);
      final pending = await _readOutbox(
        db,
        scopeId,
        commitOrdinal: commitOrdinal,
      );

      final state = CourseLearningState(
        scope: _domainScope,
        revision: revision,
        commitOrdinal: commitOrdinal,
        history: history,
        activities: activities,
        mistakes: mistakes,
        summaries: summaries,
        completions: completions,
        bestScores: bestScores,
        pending: pending,
      );
      CourseLearningStateValidator.validate(state, registry);
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
      final currentHeader = await _currentScopeHeader(db, scopeId);
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
            'run_generation, sequence, cursor_revision '
            'FROM learning_runs WHERE scope_id = ? AND latest_receipt_token = ?',
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
            revision: currentHeader.revision,
          ),
        if (latestRows.isNotEmpty)
          _readLatestReceipt(
            latestRows.single,
            revision: currentHeader.revision,
            commitOrdinal: currentHeader.commitOrdinal,
          ),
      ];
      if (found.isEmpty) return null;
      for (final receipt in found.skip(1)) {
        if (!_sameReceipt(receipt.stored, found.first.stored)) {
          throw const LearningCorruptException();
        }
      }
      return found.first.stored;
    } on LearningCorruptException {
      rethrow;
    } on Object catch (error) {
      throw LearningCorruptException(error);
    }
  }

  @override
  LearningSqlTransition<CourseLearningState, LearningCommit> evaluate({
    required CourseLearningState before,
    required LearningCommand command,
    required int nextRevision,
    required int nextCommitOrdinal,
    required DateTime committedAt,
  }) {
    try {
      CourseLearningStateValidator.validate(before, registry);
      if (command.scope != _domainScope ||
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
      final activities = <String, ActivitySlot>{
        ...before.activities,
        command.activityId: transition.slot,
      };
      final eventList = _projector.project(
        before: before,
        transition: transition,
        command: command,
      );
      final history = List<AttemptBatch>.of(before.history);
      if (transition.attempts.isNotEmpty) {
        history.add(
          AttemptBatch(
            activityId: command.activityId,
            generation: transition.slot.cursor.generation,
            sequence: transition.slot.cursor.sequence,
            token: command.token,
            canonicalCommand: CourseLearningCommandCodec.legacyCanonicalCommand(
              command,
            ),
            attempts: transition.attempts,
          ),
        );
      }

      final receiptCutoff = nextCommitOrdinal - historyLimit + 1;
      history.removeWhere((batch) {
        final latest = activities[batch.activityId]?.latestReceipt;
        return batch.attempts.first.commitOrdinal < receiptCutoff &&
            latest?.token != batch.token;
      });
      while (_attemptCount(history) > historyLimit && history.length > 1) {
        history.removeAt(0);
      }
      if (_attemptCount(history) > historyLimit ||
          transition.mistakes.length > 4096 ||
          transition.summaries.length > 4096 ||
          transition.completions.length > 4096 ||
          activities.values.fold<int>(
                0,
                (count, slot) => count + slot.exposures.length,
              ) >
              4096 ||
          transition.bestScores.length > 4096) {
        throw const LearningInvalidCommandException();
      }

      final state = CourseLearningState(
        scope: _domainScope,
        revision: nextRevision,
        commitOrdinal: nextCommitOrdinal,
        history: history,
        activities: activities,
        mistakes: transition.mistakes,
        summaries: transition.summaries,
        completions: transition.completions,
        bestScores: transition.bestScores,
        pending: [...before.pending, ...eventList],
      );
      CourseLearningStateValidator.validate(state, registry);
      return LearningSqlTransition(
        state: state,
        result: LearningCommit(
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
    CourseLearningState before,
    LearningCommand command,
    CourseLearningState after,
  ) async {
    try {
      CourseLearningStateValidator.validate(before, registry);
      CourseLearningStateValidator.validate(after, registry);
    } on FormatException catch (error) {
      throw LearningInvalidCommandException(error);
    }
    final slot = after.activities[command.activityId];
    if (slot == null || slot.latestReceipt.token != command.token) {
      throw const LearningInvalidCommandException();
    }
    final definition = _registered(registry, command.activityId);
    final bindingId = await _ensureBinding(db, scopeId, definition);
    await _writeRun(db, scopeId, bindingId, slot, command);
    await _writeReceipt(db, scopeId, command, slot, after);
    await _writeAttemptChanges(db, scopeId, before, after);
    await _pruneReceipts(db, scopeId, after.commitOrdinal);
    await _writeMistakes(db, scopeId, before.mistakes, after.mistakes);
    await _writeSummaries(db, scopeId, after.summaries);
    await _writeCompletions(db, scopeId, after.completions);
    await _writeExposure(db, scopeId, slot);
    await _writeBestScores(db, scopeId, after.bestScores);
    await _writeOutbox(db, scopeId, before, after);
  }

  @override
  LearningCommit duplicateResult({
    required CourseLearningState current,
    required LearningCommand command,
  }) {
    CourseLearningStateValidator.validate(current, registry);
    final slot = current.activities[command.activityId];
    if (slot == null) throw const LearningCorruptException();
    return LearningCommit(state: current, slot: slot, duplicate: true);
  }

  _PendingSlot _readRunRow(
    QueryRow row,
    int scopeId,
    int revision,
    int commitOrdinal,
  ) {
    if (row.read<int>('scope_id') != scopeId) {
      throw const LearningCorruptException();
    }
    final activityId = _requiredText(row.read<String>('activity_id'));
    final definition = _registered(registry, activityId);
    final kind = _activityKind(row.read<String>('activity_kind'));
    if (kind != definition.kind ||
        row.readNullable<String>('binding_activity_id') != activityId) {
      throw const LearningCorruptException();
    }
    final bindingRevision = row.readNullable<int>('binding_content_revision');
    if (bindingRevision != definition.contentRevision) {
      throw const LearningContentChangedException();
    }
    final expectedPolicyKind = _bindingPolicyKind(kind);
    final storedPolicyKind = row.readNullable<String>('binding_policy_kind');
    final storedPolicyRevision = row.readNullable<int>(
      'binding_policy_revision',
    );
    if (storedPolicyKind != expectedPolicyKind ||
        (expectedPolicyKind == null
            ? storedPolicyRevision != null
            : storedPolicyRevision != 1)) {
      throw const LearningContentChangedException();
    }
    final fingerprint = row.readNullable<String>(
      'binding_catalogue_fingerprint',
    );
    if (fingerprint != _catalogueFingerprint(definition)) {
      throw const LearningContentChangedException();
    }
    if (row.readNullable<String>('run_mode') != null ||
        row.readNullable<int>('run_start_round') != null) {
      throw const LearningCorruptException();
    }
    final policyRevision = row.readNullable<int>('policy_revision');
    final threshold = row.readNullable<int>('threshold_percent');
    if (policyRevision != 1 ||
        threshold == null ||
        threshold < 1 ||
        threshold > 100) {
      throw const LearningCorruptException();
    }
    final options = RunOptions(
      policy: LessonPolicy(completionThresholdPercent: threshold),
    );
    final cursor = SlotCursor(
      generation: row.read<int>('run_generation'),
      sequence: row.read<int>('sequence'),
      revision: row.read<int>('cursor_revision'),
    );
    final checkpointJson = row.read<String>('checkpoint_json');
    final snapshot = _checkpointCodec.decode(
      checkpointJson,
      kind: kind,
      definition: definition,
      options: options,
    );
    final expectedSessionId = snapshot is DiscoveryCheckpoint
        ? snapshot.session.sessionId
        : null;
    if (row.readNullable<String>('session_id') != expectedSessionId ||
        row.read<int>('finished') != _finished(snapshot)) {
      throw const LearningCorruptException();
    }
    final before = LearningCursorPosition(
      generation: row.read<int>('latest_receipt_before_generation'),
      sequence: row.read<int>('latest_receipt_before_sequence'),
      revision: row.read<int>('latest_receipt_before_cursor_revision'),
    );
    final after = _cursor(cursor);
    final token = row.read<String>('latest_receipt_token');
    final payload = row.read<String>('latest_receipt_payload');
    final receiptOrdinal = row.read<int>('latest_receipt_commit_ordinal');
    final command = _decodeCommand(payload);
    if (command.activityId != activityId ||
        command.token != token ||
        _cursor(command.expected) != before ||
        command.expectedScopeRevision >= revision ||
        command.expectedScopeRevision > learningMaxSafeInteger ||
        receiptOrdinal < 1 ||
        receiptOrdinal > commitOrdinal ||
        _checkpointCodec.encode(command.candidate) != checkpointJson) {
      throw const LearningCorruptException();
    }
    final latestReceipt = _SqlReceipt(
      stored: LearningStoredReceipt(
        activityId: activityId,
        token: token,
        canonicalPayload: payload,
        before: before,
        after: after,
        commitOrdinal: receiptOrdinal,
        resultActivityId: activityId,
      ),
      command: command,
      legacyCanonical: CourseLearningCommandCodec.legacyCanonicalCommand(
        command,
      ),
    );
    return _PendingSlot(
      activityId: activityId,
      kind: kind,
      contentRevision: definition.contentRevision,
      cursor: cursor,
      options: options,
      snapshot: snapshot,
      latestReceipt: latestReceipt,
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
          'result_cursor_revision FROM learning_command_receipts WHERE scope_id = ? '
          'ORDER BY commit_ordinal, activity_id, after_generation, after_sequence',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final receipts = <_SqlReceipt>[];
    final tokens = <String>{};
    final cursors = <String>{};
    for (final row in rows) {
      final receipt = _readHistoryReceipt(row, revision: revision);
      final stored = receipt.stored;
      if (!tokens.add(stored.token) ||
          !cursors.add(_receiptCursorKey(stored.activityId, stored.after)) ||
          stored.commitOrdinal > commitOrdinal) {
        throw const LearningCorruptException();
      }
      receipts.add(receipt);
    }
    return receipts;
  }

  _SqlReceipt _readHistoryReceipt(QueryRow row, {required int revision}) {
    final activityId = _requiredText(row.read<String>('activity_id'));
    final token = _requiredText(row.read<String>('token'));
    final payload = row.read<String>('canonical_payload');
    final before = LearningCursorPosition(
      generation: row.read<int>('before_generation'),
      sequence: row.read<int>('before_sequence'),
      revision: row.read<int>('before_cursor_revision'),
    );
    final after = LearningCursorPosition(
      generation: row.read<int>('after_generation'),
      sequence: row.read<int>('after_sequence'),
      revision: row.read<int>('after_cursor_revision'),
    );
    final commit = row.read<int>('commit_ordinal');
    final resultActivityId = _requiredText(
      row.read<String>('result_activity_id'),
    );
    final result = LearningCursorPosition(
      generation: row.read<int>('result_generation'),
      sequence: row.read<int>('result_sequence'),
      revision: row.read<int>('result_cursor_revision'),
    );
    final command = _decodeCommand(payload);
    if (command.activityId != activityId ||
        command.token != token ||
        command.scope != _domainScope ||
        _cursor(command.expected) != before ||
        resultActivityId != activityId ||
        result != after ||
        commit < 1 ||
        command.expectedScopeRevision >= revision) {
      throw const LearningCorruptException();
    }
    return _SqlReceipt(
      stored: LearningStoredReceipt(
        activityId: activityId,
        token: token,
        canonicalPayload: payload,
        before: before,
        after: after,
        commitOrdinal: commit,
        resultActivityId: resultActivityId,
      ),
      command: command,
      legacyCanonical: CourseLearningCommandCodec.legacyCanonicalCommand(
        command,
      ),
    );
  }

  _SqlReceipt _readLatestReceipt(
    QueryRow row, {
    required int revision,
    required int commitOrdinal,
  }) {
    final activityId = _requiredText(row.read<String>('activity_id'));
    final token = _requiredText(row.read<String>('latest_receipt_token'));
    final payload = row.read<String>('latest_receipt_payload');
    final before = LearningCursorPosition(
      generation: row.read<int>('latest_receipt_before_generation'),
      sequence: row.read<int>('latest_receipt_before_sequence'),
      revision: row.read<int>('latest_receipt_before_cursor_revision'),
    );
    final after = LearningCursorPosition(
      generation: row.read<int>('run_generation'),
      sequence: row.read<int>('sequence'),
      revision: row.read<int>('cursor_revision'),
    );
    final receiptOrdinal = row.read<int>('latest_receipt_commit_ordinal');
    final command = _decodeCommand(payload);
    if (command.activityId != activityId ||
        command.token != token ||
        command.scope != _domainScope ||
        _cursor(command.expected) != before ||
        command.expectedScopeRevision >= revision ||
        receiptOrdinal < 1 ||
        receiptOrdinal > commitOrdinal) {
      throw const LearningCorruptException();
    }
    return _SqlReceipt(
      stored: LearningStoredReceipt(
        activityId: activityId,
        token: token,
        canonicalPayload: payload,
        before: before,
        after: after,
        commitOrdinal: receiptOrdinal,
        resultActivityId: activityId,
      ),
      command: command,
      legacyCanonical: CourseLearningCommandCodec.legacyCanonicalCommand(
        command,
      ),
    );
  }

  Future<({int revision, int commitOrdinal})> _currentScopeHeader(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT owner_kind, owner_id, course_id, family, revision, '
          'commit_ordinal FROM learning_scopes WHERE id = ?',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    if (rows.length != 1) throw const LearningCorruptException();
    final row = rows.single;
    final revision = row.read<int>('revision');
    final commitOrdinal = row.read<int>('commit_ordinal');
    if (row.read<String>('owner_kind') != scope.ownerKind ||
        row.read<String>('owner_id') != scope.ownerId ||
        row.read<String>('course_id') != scope.courseId ||
        row.read<String>('family') != scope.databaseFamily ||
        revision < 0 ||
        revision > learningMaxSafeInteger ||
        commitOrdinal < 0 ||
        commitOrdinal > revision) {
      throw const LearningCorruptException();
    }
    return (revision: revision, commitOrdinal: commitOrdinal);
  }

  LearningCommand _decodeCommand(String payload) {
    try {
      final command = CourseLearningCommandCodec.decodeCanonicalCommand(
        payload,
        scope: _domainScope,
      );
      if (CourseLearningCommandCodec.canonicalCommand(command) != payload) {
        throw const LearningCorruptException();
      }
      return command;
    } on LearningCorruptException {
      rethrow;
    } on Object catch (error) {
      throw LearningCorruptException(error);
    }
  }

  void _addReceipt(
    Map<String, _SqlReceipt> byToken,
    Map<String, _SqlReceipt> byCursor,
    _SqlReceipt receipt,
  ) {
    final oldToken = byToken[receipt.stored.token];
    if (oldToken != null && !_sameReceipt(oldToken.stored, receipt.stored)) {
      throw const LearningCorruptException();
    }
    final cursorKey = _receiptCursorKey(
      receipt.stored.activityId,
      receipt.stored.after,
    );
    final oldCursor = byCursor[cursorKey];
    if (oldCursor != null && !_sameReceipt(oldCursor.stored, receipt.stored)) {
      throw const LearningCorruptException();
    }
    byToken[receipt.stored.token] = receipt;
    byCursor[cursorKey] = receipt;
  }

  Future<Map<String, Map<ItemContextKey, ItemExposure>>> _readExposures(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT family, activity_id, item_id, target_sound, presentations, assistance_mask '
          'FROM learning_exposure WHERE scope_id = ? ORDER BY activity_id, item_id, target_sound',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final result = <String, Map<ItemContextKey, ItemExposure>>{};
    for (final row in rows) {
      if (row.read<String>('family') != 'course') {
        throw const LearningCorruptException();
      }
      final activityId = _requiredText(row.readNullable<String>('activity_id'));
      final key = ItemContextKey(
        itemId: _requiredText(row.readNullable<String>('item_id')),
        targetSound: _requiredText(row.readNullable<String>('target_sound')),
      );
      final exposure = ItemExposure(
        presentations: row.read<int>('presentations'),
        assistance: _flagsFromMask(row.read<int>('assistance_mask')),
      );
      final activity = result.putIfAbsent(activityId, () => {});
      if (activity.containsKey(key)) throw const LearningCorruptException();
      activity[key] = exposure;
    }
    return result;
  }

  Future<List<AttemptBatch>> _readAttemptHistory(
    LearningDatabase db,
    int scopeId,
    Map<String, _SqlReceipt> receiptsByCursor, {
    required int commitOrdinal,
  }) async {
    final attemptRows = await db
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
    final valueRows = await db
        .customSelect(
          'SELECT attempt_id, field, ordinal, value_type, text_value, int_value, bool_value '
          'FROM learning_attempt_values WHERE scope_id = ? ORDER BY attempt_id, field, ordinal',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final values = <String, Map<String, List<_StoredValue>>>{};
    for (final row in valueRows) {
      final id = _requiredText(row.read<String>('attempt_id'));
      final field = _requiredText(row.read<String>('field'));
      final value = _StoredValue(
        ordinal: row.read<int>('ordinal'),
        type: row.read<String>('value_type'),
        text: row.readNullable<String>('text_value'),
        integer: row.readNullable<int>('int_value'),
        boolean: row.readNullable<int>('bool_value'),
      );
      final fields = values.putIfAbsent(id, () => {});
      final entries = fields.putIfAbsent(field, () => []);
      if (value.ordinal != entries.length) {
        throw const LearningCorruptException();
      }
      entries.add(value);
    }

    final attemptById = <String, CourseAttempt>{};
    final batches = <String, _AttemptGroup>{};
    for (final row in attemptRows) {
      final attempt = _readAttemptRow(row, values);
      if (attempt.commitOrdinal > commitOrdinal ||
          attemptById.containsKey(attempt.submissionId)) {
        throw const LearningCorruptException();
      }
      attemptById[attempt.submissionId] = attempt;
      final key = _cursorKey(
        attempt.activityId,
        attempt.runGeneration,
        attempt.commandSequence,
      );
      final group = batches.putIfAbsent(
        key,
        () => _AttemptGroup(
          activityId: attempt.activityId,
          generation: attempt.runGeneration,
          sequence: attempt.commandSequence,
          commitOrdinal: attempt.commitOrdinal,
        ),
      );
      if (group.commitOrdinal != attempt.commitOrdinal ||
          attempt.batchIndex != group.attempts.length) {
        throw const LearningCorruptException();
      }
      group.attempts.add(attempt);
    }
    if (values.keys.any((id) => !attemptById.containsKey(id))) {
      throw const LearningCorruptException();
    }

    final result = <AttemptBatch>[];
    final groups = batches.values.toList()
      ..sort((a, b) => a.commitOrdinal.compareTo(b.commitOrdinal));
    for (final group in groups) {
      final receipt =
          receiptsByCursor[_receiptCursorKey(
            group.activityId,
            LearningCursorPosition(
              generation: group.generation,
              sequence: group.sequence,
              revision: 0,
            ),
          )];
      final resolvedReceipt =
          receipt ??
          _findReceiptBySequence(
            receiptsByCursor,
            group.activityId,
            group.generation,
            group.sequence,
          );
      if (resolvedReceipt == null ||
          resolvedReceipt.stored.commitOrdinal != group.commitOrdinal ||
          resolvedReceipt.stored.after.generation != group.generation ||
          resolvedReceipt.stored.after.sequence != group.sequence) {
        throw const LearningCorruptException();
      }
      for (final attempt in group.attempts) {
        final expectedId =
            '${_domainScope.storageKey}.${group.activityId}.${group.generation}.${group.sequence}.${resolvedReceipt.stored.token}.a${attempt.batchIndex}';
        if (attempt.submissionId != expectedId) {
          throw const LearningCorruptException();
        }
      }
      result.add(
        AttemptBatch(
          activityId: group.activityId,
          generation: group.generation,
          sequence: group.sequence,
          token: resolvedReceipt.stored.token,
          canonicalCommand: resolvedReceipt.legacyCanonical,
          attempts: group.attempts,
        ),
      );
    }
    return result;
  }

  _SqlReceipt? _findReceiptBySequence(
    Map<String, _SqlReceipt> receiptsByCursor,
    String activityId,
    int generation,
    int sequence,
  ) {
    for (final receipt in receiptsByCursor.values) {
      if (receipt.stored.activityId == activityId &&
          receipt.stored.after.generation == generation &&
          receipt.stored.after.sequence == sequence) {
        return receipt;
      }
    }
    return null;
  }

  CourseAttempt _readAttemptRow(
    QueryRow row,
    Map<String, Map<String, List<_StoredValue>>> values,
  ) {
    final attemptId = _requiredText(row.read<String>('attempt_id'));
    final answerKind = row.read<String>('answer_kind');
    final rawValues = values.remove(attemptId) ?? const {};
    final targetSounds = _readTextValues(rawValues, 'target_sound');
    if (targetSounds.isEmpty ||
        row.readNullable<int>('round') != null ||
        row.readNullable<int>('after_debrief') != null ||
        row.readNullable<int>('teaching_exposed') != null ||
        row.readNullable<String>('selected_relation') != null ||
        row.readNullable<String>('expected_relation') != null ||
        row.readNullable<String>('section_id') != null ||
        row.readNullable<String>('sentence_id') != null ||
        row.readNullable<String>('annotation_hash') != null ||
        row.readNullable<int>('annotation_revision') != null) {
      throw const LearningCorruptException();
    }
    final AttemptAnswer answer;
    final Set<String> answerFields = <String>{'target_sound'};
    switch (answerKind) {
      case 'soundChoice':
        answerFields.addAll({'selected_sound', 'expected_sound', 'choice'});
        answer = SoundChoiceAnswer(
          selectedSound: _singleText(rawValues, 'selected_sound'),
          expectedSound: _singleText(rawValues, 'expected_sound'),
          choices: _readTextValues(rawValues, 'choice'),
        );
      case 'drillChoice':
        answerFields.addAll({
          'selected_word',
          'expected_word',
          'pair_id',
          'choice',
        });
        answer = DrillChoiceAnswer(
          selectedWord: _singleText(rawValues, 'selected_word'),
          expectedWord: _singleText(rawValues, 'expected_word'),
          pairId: _singleText(rawValues, 'pair_id'),
          choices: _readTextValues(rawValues, 'choice'),
        );
      case 'soundCue':
        answerFields.addAll({'selected_family', 'expected_family', 'word_id'});
        answer = SoundCueAnswer(
          selectedFamily: _singleText(rawValues, 'selected_family'),
          expectedFamily: _singleText(rawValues, 'expected_family'),
          wordId: _singleText(rawValues, 'word_id'),
        );
      case 'wordTile':
        answerFields.addAll({
          'word_id',
          'tile_index',
          'target_sound',
          'expected_membership',
        });
        answer = WordTileAnswer(
          wordId: _singleText(rawValues, 'word_id'),
          tileIndex: _singleInteger(rawValues, 'tile_index'),
          targetSound: _singleText(rawValues, 'target_sound'),
          expectedMembership: _singleBoolean(rawValues, 'expected_membership'),
        );
      default:
        throw const LearningCorruptException();
    }
    if (rawValues.keys.toSet().difference(answerFields).isNotEmpty ||
        answerFields.difference(rawValues.keys.toSet()).isNotEmpty) {
      throw const LearningCorruptException();
    }
    final skill = _enumByName(LearningSkill.values, row.read<String>('skill'));
    final origin = _enumByName(
      AttemptOrigin.values,
      row.read<String>('origin'),
    );
    final presentation = _enumByName(
      AttemptPresentation.values,
      row.read<String>('presentation'),
    );
    final contentState = _enumByName(
      AttemptContentState.values,
      row.read<String>('content_state'),
    );
    final audioSource = _enumByName(
      AttemptAudioSource.values,
      row.read<String>('audio_source'),
    );
    final mask = row.read<int>('assistance_mask');
    return CourseAttempt(
      scope: _domainScope,
      submissionId: attemptId,
      activityId: _requiredText(row.read<String>('activity_id')),
      runGeneration: row.read<int>('run_generation'),
      commandSequence: row.read<int>('command_sequence'),
      batchIndex: row.read<int>('batch_index'),
      itemId: _requiredText(row.readNullable<String>('item_id')),
      itemOccurrence: row.read<int>('item_occurrence'),
      contentRevision: row.read<int>('content_revision'),
      commitOrdinal: row.read<int>('commit_ordinal'),
      answeredAt: _dateFromMicros(row.read<int>('answered_at_us')),
      committedAt: _dateFromMicros(row.read<int>('committed_at_us')),
      skill: skill,
      targetSounds: targetSounds,
      answer: answer,
      origin: origin,
      presentation: presentation,
      assistance: _flagsFromMask(mask),
      contentState: contentState,
      audioSource: audioSource,
      correct: _booleanInt(row.read<int>('correct')),
    );
  }

  Future<Map<MistakeKey, LearningMistake>> _readMistakes(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT family, activity_id, item_id, target_sound, skill, content_revision, '
          'first_wrong_attempt_id, latest_wrong_attempt_id, first_wrong_at_us, '
          'latest_wrong_at_us, failure_count, last_run_generation '
          'FROM learning_mistakes WHERE scope_id = ? ORDER BY activity_id, item_id, target_sound, skill',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final result = <MistakeKey, LearningMistake>{};
    for (final row in rows) {
      if (row.read<String>('family') != 'course') {
        throw const LearningCorruptException();
      }
      final key = MistakeKey(
        activityId: _requiredText(row.readNullable<String>('activity_id')),
        itemId: _requiredText(row.readNullable<String>('item_id')),
        targetSound: _requiredText(row.readNullable<String>('target_sound')),
        skill: _enumByName(
          LearningSkill.values,
          row.readNullable<String>('skill'),
        ),
        contentRevision: row.read<int>('content_revision'),
      );
      final value = LearningMistake(
        key: key,
        firstWrongId: _requiredText(
          row.readNullable<String>('first_wrong_attempt_id'),
        ),
        firstWrongAt: _dateFromMicros(row.read<int>('first_wrong_at_us')),
        latestWrongId: _requiredText(
          row.readNullable<String>('latest_wrong_attempt_id'),
        ),
        latestWrongAt: _dateFromMicros(row.read<int>('latest_wrong_at_us')),
        failureCount: row.read<int>('failure_count'),
        lastRunGeneration:
            row.readNullable<int>('last_run_generation') ??
            (throw const LearningCorruptException()),
      );
      if (result.containsKey(key)) throw const LearningCorruptException();
      result[key] = value;
    }
    return result;
  }

  Future<Map<SummaryKey, SkillCount>> _readSummaries(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT family, activity_id, sound, skill, origin, presentation, assistance_mask, '
          'bucket, correct, total FROM learning_summaries WHERE scope_id = ? ORDER BY sound, skill, origin, presentation, assistance_mask',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final result = <SummaryKey, SkillCount>{};
    for (final row in rows) {
      if (row.read<String>('family') != 'course' ||
          row.readNullable<String>('activity_id') != null ||
          row.read<String>('bucket') != 'all') {
        throw const LearningCorruptException();
      }
      final key = SummaryKey(
        sound: _requiredText(row.readNullable<String>('sound')),
        skill: _enumByName(
          LearningSkill.values,
          row.readNullable<String>('skill'),
        ),
        origin: _enumByName(
          AttemptOrigin.values,
          row.readNullable<String>('origin'),
        ),
        presentation: _enumByName(
          AttemptPresentation.values,
          row.readNullable<String>('presentation'),
        ),
        assistance: _flagsFromMask(row.read<int>('assistance_mask')),
      );
      final value = SkillCount(
        total: row.read<int>('total'),
        correct: row.read<int>('correct'),
      );
      if (result.containsKey(key)) throw const LearningCorruptException();
      result[key] = value;
    }
    return result;
  }

  Future<List<LearningCompletion>> _readCompletions(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT activity_id, content_revision, policy_kind, policy_revision, '
          'threshold_percent, committed_at_us FROM learning_completions '
          'WHERE scope_id = ? ORDER BY activity_id, content_revision, policy_kind, policy_revision, threshold_percent',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final result = <LearningCompletion>[];
    for (final row in rows) {
      final threshold = row.read<int>('threshold_percent');
      final policyKind = switch (row.read<String>('policy_kind')) {
        'discoveryThreshold' => CompletionPolicyKind.discoveryThreshold,
        'legacyOnePass' => CompletionPolicyKind.legacyOnePass,
        _ => throw const LearningCorruptException(),
      };
      result.add(
        LearningCompletion(
          lessonId: _lessonId(row.read<String>('activity_id')),
          contentRevision: row.read<int>('content_revision'),
          policyKind: policyKind,
          policyRevision: row.read<int>('policy_revision'),
          thresholdPercent: threshold == -1 ? null : threshold,
          committedAt: _dateFromMicros(row.read<int>('committed_at_us')),
        ),
      );
    }
    return result;
  }

  Future<Map<String, int>> _readBestScores(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT activity_id, score FROM learning_best_scores WHERE scope_id = ? ORDER BY activity_id',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    return {
      for (final row in rows)
        _requiredText(row.read<String>('activity_id')): row.read<int>('score'),
    };
  }

  Future<List<SupportedCloudEvent>> _readOutbox(
    LearningDatabase db,
    int scopeId, {
    required int commitOrdinal,
  }) async {
    final rows = await db
        .customSelect(
          'SELECT event_id, enqueue_commit_ordinal, enqueue_event_index, user_id, '
          'course_id, kind, sound, skill, correct, activity, lesson_id, game, score '
          'FROM supported_sync_outbox WHERE scope_id = ? '
          'ORDER BY enqueue_commit_ordinal ASC, enqueue_event_index ASC',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final result = <SupportedCloudEvent>[];
    for (final row in rows) {
      if (row.read<int>('enqueue_commit_ordinal') > commitOrdinal) {
        throw const LearningCorruptException();
      }
      final userId = row.read<String>('user_id');
      final courseId = row.read<String>('course_id');
      if (scope.owner.isGuest ||
          userId != scope.owner.userId ||
          courseId != scope.courseId) {
        throw const LearningCorruptException();
      }
      final kind = row.read<String>('kind');
      final SupportedCloudPayload payload = switch (kind) {
        'answer' => _readAnswerPayload(row),
        'lesson' => _readLessonPayload(row),
        'score' => _readScorePayload(row),
        _ => throw const LearningCorruptException(),
      };
      result.add(
        SupportedCloudEvent(
          id: _requiredText(row.read<String>('event_id')),
          userId: userId,
          courseId: courseId,
          payload: payload,
        ),
      );
    }
    return result;
  }

  SupportedCloudPayload _readAnswerPayload(QueryRow row) {
    if (row.readNullable<String>('lesson_id') != null ||
        row.readNullable<String>('game') != null ||
        row.readNullable<int>('score') != null) {
      throw const LearningCorruptException();
    }
    return CloudAnswer(
      sound: _requiredText(row.readNullable<String>('sound')),
      skill: _enumByName(
        LearningSkill.values,
        row.readNullable<String>('skill'),
      ),
      correct: _booleanInt(row.read<int>('correct')),
      activity: _requiredText(row.readNullable<String>('activity')),
    );
  }

  SupportedCloudPayload _readLessonPayload(QueryRow row) {
    if (row.readNullable<String>('sound') != null ||
        row.readNullable<String>('skill') != null ||
        row.readNullable<int>('correct') != null ||
        row.readNullable<String>('activity') != null ||
        row.readNullable<String>('game') != null ||
        row.readNullable<int>('score') != null) {
      throw const LearningCorruptException();
    }
    return CloudLesson(
      lessonId: _requiredText(row.readNullable<String>('lesson_id')),
    );
  }

  SupportedCloudPayload _readScorePayload(QueryRow row) {
    if (row.readNullable<String>('sound') != null ||
        row.readNullable<String>('skill') != null ||
        row.readNullable<int>('correct') != null ||
        row.readNullable<String>('activity') != null ||
        row.readNullable<String>('lesson_id') != null) {
      throw const LearningCorruptException();
    }
    return CloudScore(
      game: _requiredText(row.readNullable<String>('game')),
      score: row.read<int>('score'),
    );
  }

  Future<int> _ensureBinding(
    LearningDatabase db,
    int scopeId,
    LearningActivityDefinition definition,
  ) async {
    final policyKind = _bindingPolicyKind(definition.kind);
    final policyRevision = policyKind == null ? null : 1;
    final fingerprint = _catalogueFingerprint(definition);
    await db.customStatement(
      'INSERT INTO learning_content_bindings '
      '(scope_id, activity_id, content_revision, policy_kind, policy_revision, '
      'catalogue_fingerprint, section_fingerprint, annotation_hash, annotation_revision) '
      'VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, NULL) ON CONFLICT DO NOTHING',
      [
        scopeId,
        definition.id,
        definition.contentRevision,
        policyKind,
        policyRevision,
        fingerprint,
      ],
    );
    final policyKindClause = policyKind == null ? 'IS NULL' : 'IS ?';
    final policyRevisionClause = policyRevision == null ? 'IS NULL' : 'IS ?';
    final variables = <Variable<Object>>[
      Variable<int>(scopeId),
      Variable<String>(definition.id),
      Variable<int>(definition.contentRevision),
      if (policyKind != null) Variable<String>(policyKind),
      if (policyRevision != null) Variable<int>(policyRevision),
      Variable<String>(fingerprint),
    ];
    final rows = await db
        .customSelect(
          'SELECT id FROM learning_content_bindings WHERE scope_id = ? '
          'AND activity_id = ? AND content_revision = ? '
          'AND policy_kind $policyKindClause AND policy_revision $policyRevisionClause '
          'AND catalogue_fingerprint IS ? AND section_fingerprint IS NULL '
          'AND annotation_hash IS NULL AND annotation_revision IS NULL',
          variables: variables,
        )
        .get();
    if (rows.length != 1) throw const LearningCorruptException();
    return rows.single.read<int>('id');
  }

  Future<void> _writeRun(
    LearningDatabase db,
    int scopeId,
    int bindingId,
    ActivitySlot slot,
    LearningCommand command,
  ) async {
    final sqlPayload = CourseLearningCommandCodec.canonicalCommand(command);
    final sessionId = slot.snapshot is DiscoveryCheckpoint
        ? (slot.snapshot as DiscoveryCheckpoint).session.sessionId
        : null;
    await db.customStatement(
      'INSERT INTO learning_runs '
      '(scope_id, activity_id, activity_kind, run_generation, sequence, cursor_revision, '
      'content_binding_id, run_mode, finished, session_id, policy_revision, '
      'threshold_percent, run_start_round, checkpoint_json, latest_receipt_token, '
      'latest_receipt_payload, latest_receipt_before_generation, '
      'latest_receipt_before_sequence, latest_receipt_before_cursor_revision, '
      'latest_receipt_commit_ordinal) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, 1, ?, NULL, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(scope_id, activity_id) DO UPDATE SET '
      'activity_kind = excluded.activity_kind, run_generation = excluded.run_generation, '
      'sequence = excluded.sequence, cursor_revision = excluded.cursor_revision, '
      'content_binding_id = excluded.content_binding_id, run_mode = NULL, '
      'finished = excluded.finished, session_id = excluded.session_id, '
      'policy_revision = excluded.policy_revision, threshold_percent = excluded.threshold_percent, '
      'run_start_round = NULL, checkpoint_json = excluded.checkpoint_json, '
      'latest_receipt_token = excluded.latest_receipt_token, '
      'latest_receipt_payload = excluded.latest_receipt_payload, '
      'latest_receipt_before_generation = excluded.latest_receipt_before_generation, '
      'latest_receipt_before_sequence = excluded.latest_receipt_before_sequence, '
      'latest_receipt_before_cursor_revision = excluded.latest_receipt_before_cursor_revision, '
      'latest_receipt_commit_ordinal = excluded.latest_receipt_commit_ordinal',
      [
        scopeId,
        slot.activityId,
        slot.kind.name,
        slot.cursor.generation,
        slot.cursor.sequence,
        slot.cursor.revision,
        bindingId,
        _finished(slot.snapshot),
        sessionId,
        slot.options.policy.completionThresholdPercent,
        _checkpointCodec.encode(slot.snapshot),
        command.token,
        sqlPayload,
        slot.latestReceipt.before.generation,
        slot.latestReceipt.before.sequence,
        slot.latestReceipt.before.revision,
        slot.latestReceipt.commitOrdinal,
      ],
    );
  }

  Future<void> _writeReceipt(
    LearningDatabase db,
    int scopeId,
    LearningCommand command,
    ActivitySlot slot,
    CourseLearningState after,
  ) async {
    final payload = CourseLearningCommandCodec.canonicalCommand(command);
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
        payload,
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
    CourseLearningState before,
    CourseLearningState after,
  ) async {
    final afterKeys = after.history.map(_batchKey).toSet();
    for (final batch in before.history) {
      if (!afterKeys.contains(_batchKey(batch))) {
        for (final attempt in batch.attempts) {
          await db.customStatement(
            'DELETE FROM learning_attempt_values WHERE scope_id = ? AND attempt_id = ?',
            [scopeId, attempt.submissionId],
          );
          await db.customStatement(
            'DELETE FROM learning_attempts WHERE scope_id = ? AND attempt_id = ?',
            [scopeId, attempt.submissionId],
          );
        }
      }
    }
    final beforeKeys = before.history.map(_batchKey).toSet();
    for (final batch in after.history) {
      if (beforeKeys.contains(_batchKey(batch))) continue;
      for (final attempt in batch.attempts) {
        await _insertAttempt(db, scopeId, attempt);
      }
    }
  }

  Future<void> _insertAttempt(
    LearningDatabase db,
    int scopeId,
    CourseAttempt attempt,
  ) async {
    final answerKind = switch (attempt.answer) {
      SoundChoiceAnswer() => 'soundChoice',
      DrillChoiceAnswer() => 'drillChoice',
      SoundCueAnswer() => 'soundCue',
      WordTileAnswer() => 'wordTile',
    };
    await db.customStatement(
      'INSERT INTO learning_attempts '
      '(scope_id, attempt_id, activity_id, run_generation, command_sequence, batch_index, '
      'item_id, item_occurrence, content_revision, commit_ordinal, answered_at_us, '
      'committed_at_us, answer_kind, correct, skill, origin, presentation, assistance_mask, '
      'content_state, audio_source, round, after_debrief, teaching_exposed, selected_relation, '
      'expected_relation, section_id, sentence_id, annotation_hash, annotation_revision) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL)',
      [
        scopeId,
        attempt.submissionId,
        attempt.activityId,
        attempt.runGeneration,
        attempt.commandSequence,
        attempt.batchIndex,
        attempt.itemId,
        attempt.itemOccurrence,
        attempt.contentRevision,
        attempt.commitOrdinal,
        _dateMicros(attempt.answeredAt),
        _dateMicros(attempt.committedAt),
        answerKind,
        attempt.correct ? 1 : 0,
        attempt.skill.name,
        attempt.origin.name,
        attempt.presentation.name,
        _flagsToMask(attempt.assistance),
        attempt.contentState.name,
        attempt.audioSource.name,
      ],
    );
    if (attempt.answer is! WordTileAnswer) {
      for (var index = 0; index < attempt.targetSounds.length; index++) {
        await _insertAttemptValue(
          db,
          scopeId,
          attempt.submissionId,
          'target_sound',
          index,
          text: attempt.targetSounds[index],
        );
      }
    }
    switch (attempt.answer) {
      case final SoundChoiceAnswer answer:
        await _insertAttemptValue(
          db,
          scopeId,
          attempt.submissionId,
          'selected_sound',
          0,
          text: answer.selectedSound,
        );
        await _insertAttemptValue(
          db,
          scopeId,
          attempt.submissionId,
          'expected_sound',
          0,
          text: answer.expectedSound,
        );
        await _insertTextList(
          db,
          scopeId,
          attempt.submissionId,
          'choice',
          answer.choices,
        );
      case final DrillChoiceAnswer answer:
        await _insertAttemptValue(
          db,
          scopeId,
          attempt.submissionId,
          'selected_word',
          0,
          text: answer.selectedWord,
        );
        await _insertAttemptValue(
          db,
          scopeId,
          attempt.submissionId,
          'expected_word',
          0,
          text: answer.expectedWord,
        );
        await _insertAttemptValue(
          db,
          scopeId,
          attempt.submissionId,
          'pair_id',
          0,
          text: answer.pairId,
        );
        await _insertTextList(
          db,
          scopeId,
          attempt.submissionId,
          'choice',
          answer.choices,
        );
      case final SoundCueAnswer answer:
        await _insertAttemptValue(
          db,
          scopeId,
          attempt.submissionId,
          'selected_family',
          0,
          text: answer.selectedFamily,
        );
        await _insertAttemptValue(
          db,
          scopeId,
          attempt.submissionId,
          'expected_family',
          0,
          text: answer.expectedFamily,
        );
        await _insertAttemptValue(
          db,
          scopeId,
          attempt.submissionId,
          'word_id',
          0,
          text: answer.wordId,
        );
      case final WordTileAnswer answer:
        await _insertAttemptValue(
          db,
          scopeId,
          attempt.submissionId,
          'word_id',
          0,
          text: answer.wordId,
        );
        await _insertAttemptValue(
          db,
          scopeId,
          attempt.submissionId,
          'tile_index',
          0,
          integer: answer.tileIndex,
        );
        await _insertAttemptValue(
          db,
          scopeId,
          attempt.submissionId,
          'target_sound',
          0,
          text: answer.targetSound,
        );
        await _insertAttemptValue(
          db,
          scopeId,
          attempt.submissionId,
          'expected_membership',
          0,
          boolean: answer.expectedMembership,
        );
    }
  }

  Future<void> _insertTextList(
    LearningDatabase db,
    int scopeId,
    String attemptId,
    String field,
    List<String> values,
  ) async {
    for (var index = 0; index < values.length; index++) {
      await _insertAttemptValue(
        db,
        scopeId,
        attemptId,
        field,
        index,
        text: values[index],
      );
    }
  }

  Future<void> _insertAttemptValue(
    LearningDatabase db,
    int scopeId,
    String attemptId,
    String field,
    int ordinal, {
    String? text,
    int? integer,
    bool? boolean,
  }) async {
    final present =
        (text != null ? 1 : 0) +
        (integer != null ? 1 : 0) +
        (boolean != null ? 1 : 0);
    if (present != 1) throw const LearningInvalidCommandException();
    await db.customStatement(
      'INSERT INTO learning_attempt_values '
      '(scope_id, attempt_id, field, ordinal, value_type, text_value, int_value, bool_value) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        scopeId,
        attemptId,
        field,
        ordinal,
        text != null
            ? 'text'
            : integer != null
            ? 'int'
            : 'bool',
        text,
        integer,
        boolean == null
            ? null
            : boolean
            ? 1
            : 0,
      ],
    );
  }

  Future<void> _writeMistakes(
    LearningDatabase db,
    int scopeId,
    Map<MistakeKey, LearningMistake> before,
    Map<MistakeKey, LearningMistake> after,
  ) async {
    for (final key in before.keys) {
      if (!after.containsKey(key)) {
        await db.customStatement(
          "DELETE FROM learning_mistakes WHERE scope_id = ? AND family = 'course' "
          'AND activity_id = ? AND item_id = ? AND target_sound = ? AND skill = ? AND content_revision = ?',
          [
            scopeId,
            key.activityId,
            key.itemId,
            key.targetSound,
            key.skill.name,
            key.contentRevision,
          ],
        );
      }
    }
    for (final mistake in after.values) {
      final key = mistake.key;
      await db.customStatement(
        'INSERT INTO learning_mistakes '
        '(scope_id, family, activity_id, item_id, target_sound, skill, pair_id, section_id, '
        'sentence_id, audio_ref_id, annotation_hash, annotation_revision, content_revision, '
        'first_wrong_attempt_id, latest_wrong_attempt_id, first_wrong_at_us, latest_wrong_at_us, '
        'failure_count, last_run_generation) '
        "VALUES (?, 'course', ?, ?, ?, ?, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?, ?, ?, ?, ?, ?) "
        'ON CONFLICT DO UPDATE SET first_wrong_attempt_id = excluded.first_wrong_attempt_id, '
        'latest_wrong_attempt_id = excluded.latest_wrong_attempt_id, first_wrong_at_us = excluded.first_wrong_at_us, '
        'latest_wrong_at_us = excluded.latest_wrong_at_us, failure_count = excluded.failure_count, '
        'last_run_generation = excluded.last_run_generation',
        [
          scopeId,
          key.activityId,
          key.itemId,
          key.targetSound,
          key.skill.name,
          key.contentRevision,
          mistake.firstWrongId,
          mistake.latestWrongId,
          _dateMicros(mistake.firstWrongAt),
          _dateMicros(mistake.latestWrongAt),
          mistake.failureCount,
          mistake.lastRunGeneration,
        ],
      );
    }
  }

  Future<void> _writeSummaries(
    LearningDatabase db,
    int scopeId,
    Map<SummaryKey, SkillCount> summaries,
  ) async {
    for (final entry in summaries.entries) {
      await db.customStatement(
        'INSERT INTO learning_summaries '
        '(scope_id, family, activity_id, sound, skill, origin, presentation, assistance_mask, '
        'pair_id, section_id, item_id, sentence_id, audio_ref_id, annotation_hash, annotation_revision, '
        'content_revision, bucket, correct, total) '
        "VALUES (?, 'course', NULL, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'all', ?, ?) "
        'ON CONFLICT DO UPDATE SET correct = excluded.correct, total = excluded.total',
        [
          scopeId,
          entry.key.sound,
          entry.key.skill.name,
          entry.key.origin.name,
          entry.key.presentation.name,
          _flagsToMask(entry.key.assistance),
          entry.value.correct,
          entry.value.total,
        ],
      );
    }
  }

  Future<void> _writeCompletions(
    LearningDatabase db,
    int scopeId,
    List<LearningCompletion> completions,
  ) async {
    for (final completion in completions) {
      await db.customStatement(
        'INSERT INTO learning_completions '
        '(scope_id, activity_id, content_revision, policy_kind, policy_revision, threshold_percent, committed_at_us) '
        'VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT DO NOTHING',
        [
          scopeId,
          'lesson:${completion.lessonId}',
          completion.contentRevision,
          completion.policyKind == CompletionPolicyKind.discoveryThreshold
              ? 'discoveryThreshold'
              : 'legacyOnePass',
          completion.policyRevision,
          completion.thresholdPercent ?? -1,
          _dateMicros(completion.committedAt),
        ],
      );
    }
  }

  Future<void> _writeExposure(
    LearningDatabase db,
    int scopeId,
    ActivitySlot slot,
  ) async {
    await db.customStatement(
      "DELETE FROM learning_exposure WHERE scope_id = ? AND family = 'course' AND activity_id = ?",
      [scopeId, slot.activityId],
    );
    for (final entry in slot.exposures.entries) {
      await db.customStatement(
        'INSERT INTO learning_exposure '
        '(scope_id, family, activity_id, item_id, target_sound, section_id, content_revision, presentations, assistance_mask) '
        "VALUES (?, 'course', ?, ?, ?, NULL, NULL, ?, ?) ON CONFLICT DO UPDATE SET presentations = excluded.presentations, assistance_mask = excluded.assistance_mask",
        [
          scopeId,
          slot.activityId,
          entry.key.itemId,
          entry.key.targetSound,
          entry.value.presentations,
          _flagsToMask(entry.value.assistance),
        ],
      );
    }
  }

  Future<void> _writeBestScores(
    LearningDatabase db,
    int scopeId,
    Map<String, int> scores,
  ) async {
    for (final entry in scores.entries) {
      await db.customStatement(
        'INSERT INTO learning_best_scores (scope_id, activity_id, score) VALUES (?, ?, ?) '
        'ON CONFLICT(scope_id, activity_id) DO UPDATE SET score = excluded.score',
        [scopeId, entry.key, entry.value],
      );
    }
  }

  Future<void> _writeOutbox(
    LearningDatabase db,
    int scopeId,
    CourseLearningState before,
    CourseLearningState after,
  ) async {
    final oldIds = before.pending.map((event) => event.id).toSet();
    final added = after.pending.where((event) => !oldIds.contains(event.id));
    var index = 0;
    for (final event in added) {
      if (event.userId != scope.owner.userId ||
          event.courseId != scope.courseId) {
        throw const LearningInvalidCommandException();
      }
      final fields = switch (event.payload) {
        final CloudAnswer payload => <Object?>[
          'answer',
          payload.sound,
          payload.skill.name,
          payload.correct ? 1 : 0,
          payload.activity,
          null,
          null,
          null,
        ],
        final CloudLesson payload => <Object?>[
          'lesson',
          null,
          null,
          null,
          null,
          payload.lessonId,
          null,
          null,
        ],
        final CloudScore payload => <Object?>[
          'score',
          null,
          null,
          null,
          null,
          null,
          payload.game,
          payload.score,
        ],
      };
      await db.customStatement(
        'INSERT INTO supported_sync_outbox '
        '(scope_id, event_id, enqueue_commit_ordinal, enqueue_event_index, user_id, course_id, kind, '
        'sound, skill, correct, activity, lesson_id, game, score) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          scopeId,
          event.id,
          after.commitOrdinal,
          index++,
          event.userId,
          event.courseId,
          ...fields,
        ],
      );
    }
  }
}

final class _PendingSlot {
  const _PendingSlot({
    required this.activityId,
    required this.kind,
    required this.contentRevision,
    required this.cursor,
    required this.options,
    required this.snapshot,
    required this.latestReceipt,
  });
  final String activityId;
  final LearningActivityKind kind;
  final int contentRevision;
  final SlotCursor cursor;
  final RunOptions options;
  final ActivitySnapshot snapshot;
  final _SqlReceipt latestReceipt;
}

final class _SqlReceipt {
  const _SqlReceipt({
    required this.stored,
    required this.command,
    required this.legacyCanonical,
  });
  final LearningStoredReceipt stored;
  final LearningCommand command;
  final String legacyCanonical;
}

final class _AttemptGroup {
  _AttemptGroup({
    required this.activityId,
    required this.generation,
    required this.sequence,
    required this.commitOrdinal,
  });
  final String activityId;
  final int generation;
  final int sequence;
  final int commitOrdinal;
  final List<CourseAttempt> attempts = [];
}

final class _StoredValue {
  const _StoredValue({
    required this.ordinal,
    required this.type,
    required this.text,
    required this.integer,
    required this.boolean,
  });
  final int ordinal;
  final String type;
  final String? text;
  final int? integer;
  final int? boolean;
}

LearningCursorPosition _cursor(SlotCursor cursor) => LearningCursorPosition(
  generation: cursor.generation,
  sequence: cursor.sequence,
  revision: cursor.revision,
);

SlotCursor _slotCursor(LearningCursorPosition cursor) => SlotCursor(
  generation: cursor.generation,
  sequence: cursor.sequence,
  revision: cursor.revision,
);

String _cursorKey(String activityId, int generation, int sequence) =>
    jsonEncode([activityId, generation, sequence]);

String _receiptCursorKey(String activityId, LearningCursorPosition after) =>
    _cursorKey(activityId, after.generation, after.sequence);

bool _sameReceipt(LearningStoredReceipt a, LearningStoredReceipt b) =>
    a.activityId == b.activityId &&
    a.token == b.token &&
    a.canonicalPayload == b.canonicalPayload &&
    a.before == b.before &&
    a.after == b.after &&
    a.commitOrdinal == b.commitOrdinal &&
    a.resultActivityId == b.resultActivityId;

String _batchKey(AttemptBatch batch) => jsonEncode([
  batch.activityId,
  batch.generation,
  batch.sequence,
  batch.token,
]);

int _attemptCount(List<AttemptBatch> batches) =>
    batches.fold<int>(0, (total, batch) => total + batch.attempts.length);

LearningActivityKind _activityKind(String value) =>
    _enumByName(LearningActivityKind.values, value);

T _enumByName<T extends Enum>(List<T> values, String? value) {
  if (value == null) throw const LearningCorruptException();
  for (final entry in values) {
    if (entry.name == value) return entry;
  }
  throw const LearningCorruptException();
}

String _requiredText(String? value) {
  if (value == null || value.trim().isEmpty) {
    throw const LearningCorruptException();
  }
  return value;
}

bool _booleanInt(int? value) => switch (value) {
  0 => false,
  1 => true,
  _ => throw const LearningCorruptException(),
};

DateTime _dateFromMicros(int value) {
  if (value < 0 || value > learningMaxSafeInteger) {
    throw const LearningCorruptException();
  }
  return DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);
}

int _dateMicros(DateTime value) {
  final micros = value.toUtc().microsecondsSinceEpoch;
  if (micros < 0 || micros > learningMaxSafeInteger) {
    throw const LearningInvalidCommandException();
  }
  return micros;
}

Set<AssistanceFlag> _flagsFromMask(int? value) {
  if (value == null || value < 0 || value > 15) {
    throw const LearningCorruptException();
  }
  return {
    for (final flag in AssistanceFlag.values)
      if ((value & (1 << flag.index)) != 0) flag,
  };
}

int _flagsToMask(Set<AssistanceFlag> flags) =>
    flags.fold<int>(0, (mask, flag) => mask | (1 << flag.index));

List<String> _readTextValues(
  Map<String, List<_StoredValue>> values,
  String field,
) {
  final entries = values[field];
  if (entries == null || entries.isEmpty) {
    throw const LearningCorruptException();
  }
  return [
    for (var index = 0; index < entries.length; index++)
      if (entries[index].ordinal != index ||
          entries[index].type != 'text' ||
          entries[index].text == null ||
          entries[index].integer != null ||
          entries[index].boolean != null)
        (throw const LearningCorruptException())
      else
        _requiredText(entries[index].text),
  ];
}

String _singleText(Map<String, List<_StoredValue>> values, String field) {
  final entries = _readTextValues(values, field);
  if (entries.length != 1) throw const LearningCorruptException();
  return entries.single;
}

int _singleInteger(Map<String, List<_StoredValue>> values, String field) {
  final entries = values[field];
  if (entries == null ||
      entries.length != 1 ||
      entries.single.ordinal != 0 ||
      entries.single.type != 'int' ||
      entries.single.text != null ||
      entries.single.integer == null ||
      entries.single.boolean != null) {
    throw const LearningCorruptException();
  }
  return entries.single.integer!;
}

bool _singleBoolean(Map<String, List<_StoredValue>> values, String field) {
  final entries = values[field];
  if (entries == null ||
      entries.length != 1 ||
      entries.single.ordinal != 0 ||
      entries.single.type != 'bool' ||
      entries.single.text != null ||
      entries.single.integer != null) {
    throw const LearningCorruptException();
  }
  return _booleanInt(entries.single.boolean);
}

int _finished(ActivitySnapshot snapshot) => switch (snapshot) {
  LegacyLessonCheckpoint(:final finished) => finished ? 1 : 0,
  DrillCheckpoint(:final ended) => ended ? 1 : 0,
  _ => 0,
};

String? _bindingPolicyKind(LearningActivityKind kind) => switch (kind) {
  LearningActivityKind.discovery => 'discoveryThreshold',
  LearningActivityKind.legacyLesson => 'legacyOnePass',
  _ => null,
};

String _lessonId(String activityId) {
  const prefix = 'lesson:';
  if (!activityId.startsWith(prefix) || activityId.length == prefix.length) {
    throw const LearningCorruptException();
  }
  return activityId.substring(prefix.length);
}

LearningActivityDefinition _registered(
  LearningRegistry registry,
  String activityId,
) {
  try {
    return registry.require(activityId);
  } on Object catch (error) {
    throw LearningCorruptException(error);
  }
}

String _catalogueFingerprint(LearningActivityDefinition definition) {
  final content = jsonEncode([
    definition.id,
    definition.kind.name,
    definition.contentRevision,
    for (final item in definition.items)
      [
        item.id,
        item.sessionAlias,
        item.audioText,
        item.choices,
        item.expectedChoice,
        item.targetSounds,
        item.contentState.name,
      ],
  ]);
  final bytes = utf8.encode(content);
  // A stable, local FNV-1a digest keeps catalogue details out of SQLite while
  // detecting content changes between process versions.
  var first = 0x811c9dc5;
  var second = 0x9e3779b9;
  for (final byte in bytes) {
    first = ((first ^ byte) * 0x01000193) & 0xffffffff;
    second = ((second ^ (byte + 0x51)) * 0x01000193) & 0xffffffff;
  }
  return 'course-v1-${first.toRadixString(16).padLeft(8, '0')}${second.toRadixString(16).padLeft(8, '0')}';
}
