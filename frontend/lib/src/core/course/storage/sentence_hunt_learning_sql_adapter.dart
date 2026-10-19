import 'dart:convert';

import 'package:drift/drift.dart' show QueryRow, Variable;

import '../course_audio_contract.dart';
import '../course_learning_error.dart';
import '../learning_storage_types.dart';
import '../lesson_policy.dart';
import '../sentence_hunt_content.dart';
import '../sentence_hunt_learning_command.dart' as domain;
import '../sentence_hunt_learning_state.dart';
import '../sentence_hunt_learning_store.dart' show SentenceHuntCommit;
import '../sentence_hunt_learning_transition.dart';
import 'learning_database.dart' show LearningDatabase;
import 'learning_sql_transaction.dart';
import 'learning_storage_scope.dart';
import 'learning_tables.dart'
    show learningMaxCheckpointBytes, learningMaxSafeInteger;
import 'sentence_hunt_learning_checkpoint_codec.dart';
import 'sentence_hunt_learning_command_codec.dart';
import 'sentence_hunt_learning_storage_validator.dart';

/// Typed normalized-row adapter for the inactive sentence-hunt repository.
/// The existing transition engine remains the only sentence reducer.
final class SentenceHuntLearningSqlAdapter
    implements
        SqliteLearningProfileAdapter<
          SentenceHuntLearningState,
          domain.SentenceHuntLearningCommand,
          SentenceHuntCommit
        > {
  SentenceHuntLearningSqlAdapter({
    required SentenceHuntProfileScope scope,
    required this.transitions,
    required this.historyLimit,
  }) : _domainScope = scope,
       scope = LearningStorageScope(
         owner: scope.owner,
         courseId: scope.courseId,
         family: LearningFamily.sentenceHunt,
       ) {
    if (historyLimit < 1 || historyLimit > sentenceHuntMaxAttempts) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
  }

  final SentenceHuntProfileScope _domainScope;
  @override
  final LearningStorageScope scope;
  final SentenceHuntTransitionEngine transitions;
  final int historyLimit;
  final SentenceHuntCheckpointCodec _checkpointCodec =
      const SentenceHuntCheckpointCodec();

  SentenceHuntCatalogue get catalogue => transitions.catalogue;

  int get _retainedHistoryLimit {
    var limit = historyLimit;
    if (limit > transitions.limits.maxAttempts) {
      limit = transitions.limits.maxAttempts;
    }
    if (limit > transitions.limits.maxReceipts) {
      limit = transitions.limits.maxReceipts;
    }
    return limit;
  }

  @override
  String commandActivityId(domain.SentenceHuntLearningCommand command) =>
      command.sectionId;

  @override
  String commandToken(domain.SentenceHuntLearningCommand command) =>
      command.token;

  @override
  String commandCanonicalPayload(domain.SentenceHuntLearningCommand command) =>
      SentenceHuntCommandCodec.canonicalCommand(command);

  @override
  int commandAuthGeneration(domain.SentenceHuntLearningCommand command) =>
      command.authGeneration;

  @override
  int commandExpectedScopeRevision(
    domain.SentenceHuntLearningCommand command,
  ) => command.expectedScopeRevision;

  @override
  LearningCursorPosition commandExpectedCursor(
    domain.SentenceHuntLearningCommand command,
  ) => command.expected;

  @override
  bool isStart(domain.SentenceHuntLearningCommand command) =>
      command.action is domain.StartSentenceHuntRun;

  @override
  LearningCursorPosition? cursorFor(
    SentenceHuntLearningState state,
    String activityId,
  ) => state.slots[activityId]?.cursor;

  @override
  Future<SentenceHuntLearningState> loadState(
    LearningDatabase db,
    int scopeId, {
    required int revision,
    required int commitOrdinal,
  }) async {
    try {
      if (_domainScope.courseId != scope.courseId ||
          _domainScope.owner != scope.owner ||
          scope.family != LearningFamily.sentenceHunt ||
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
      if (runRows.length > sentenceHuntMaxSlots) {
        throw const LearningCorruptException();
      }
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
      final slots = <String, SentenceHuntSlot>{};
      final latestReceipts = <_SqlReceipt>[];
      for (final row in runRows) {
        final read = _readRunRow(
          row,
          scopeId,
          revision: revision,
          commitOrdinal: commitOrdinal,
        );
        if (slots.containsKey(read.slot.sectionId)) {
          throw const LearningCorruptException();
        }
        slots[read.slot.sectionId] = SentenceHuntSlot(
          sectionId: read.slot.sectionId,
          checkpoint: read.slot.checkpoint,
          cursor: read.slot.cursor,
          latestReceipt: read.latestReceipt.domainReceipt,
        );
        latestReceipts.add(read.latestReceipt);
      }
      if (commitOrdinal == 0 &&
          (runRows.isNotEmpty || historyReceipts.isNotEmpty)) {
        throw const LearningCorruptException();
      }

      final byToken = <String, _SqlReceipt>{};
      final byCursor = <String, _SqlReceipt>{};
      final byOrdinal = <int, _SqlReceipt>{};
      for (final receipt in historyReceipts) {
        _addReceipt(byToken, byCursor, byOrdinal, receipt);
      }
      for (final receipt in latestReceipts) {
        _addReceipt(byToken, byCursor, byOrdinal, receipt);
      }

      final attempts = await _readAttempts(
        db,
        scopeId,
        commitOrdinal,
        byCursor,
      );
      final projectedReceipts = <SentenceHuntReceipt>[
        for (final receipt in historyReceipts) receipt.domainReceipt,
      ];
      final latestScopeReceipts = latestReceipts
          .where((receipt) => receipt.stored.commitOrdinal == commitOrdinal)
          .toList(growable: false);
      if (commitOrdinal > 0 && latestScopeReceipts.length != 1) {
        throw const LearningCorruptException();
      }
      if (latestScopeReceipts.isNotEmpty &&
          !projectedReceipts.any(
            (receipt) =>
                receipt.token == latestScopeReceipts.single.stored.token,
          )) {
        projectedReceipts.add(latestScopeReceipts.single.domainReceipt);
      }
      final retainedReceipts = _latest(
        projectedReceipts,
        sentenceHuntMaxReceipts,
      );
      final mistakes = await _readMistakes(db, scopeId);
      final summaries = await _readSummaries(db, scopeId);
      final completions = await _readCompletions(db, scopeId);
      final exposure = await _readExposure(db, scopeId);
      final state = SentenceHuntLearningState(
        scope: _domainScope,
        revision: revision,
        commitOrdinal: commitOrdinal,
        slots: slots,
        attempts: attempts,
        receipts: retainedReceipts,
        mistakes: mistakes,
        summaries: summaries,
        completions: completions,
        teachingExposure: exposure,
      );
      SentenceHuntLearningStateValidator.validate(state, catalogue);
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
  LearningSqlTransition<SentenceHuntLearningState, SentenceHuntCommit>
  evaluate({
    required SentenceHuntLearningState before,
    required domain.SentenceHuntLearningCommand command,
    required int nextRevision,
    required int nextCommitOrdinal,
    required DateTime committedAt,
  }) {
    try {
      SentenceHuntLearningStateValidator.validate(before, catalogue);
      if (command.scope != _domainScope ||
          command.sectionId != catalogue.section(command.sectionId).id ||
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
      final attempts = _latest(<SentenceHuntAttempt>[
        ...before.attempts,
        ...transition.attempts,
      ], _retainedHistoryLimit);
      final receipts = _latest(reduced.receipts, _retainedHistoryLimit);
      if (reduced.mistakes.length > sentenceHuntMaxAggregateEntries ||
          reduced.summaries.length > sentenceHuntMaxAggregateEntries ||
          reduced.completions.length > sentenceHuntMaxAggregateEntries ||
          reduced.teachingExposure.length > sentenceHuntMaxAggregateEntries ||
          attempts.length > sentenceHuntMaxAttempts ||
          receipts.length > sentenceHuntMaxReceipts) {
        throw const LearningInvalidCommandException();
      }
      final state = SentenceHuntLearningState(
        scope: _domainScope,
        revision: nextRevision,
        commitOrdinal: nextCommitOrdinal,
        slots: reduced.slots,
        attempts: attempts,
        receipts: receipts,
        mistakes: reduced.mistakes,
        summaries: reduced.summaries,
        completions: reduced.completions,
        teachingExposure: reduced.teachingExposure,
      );
      SentenceHuntLearningStateValidator.validate(state, catalogue);
      final slot = state.slots[command.sectionId];
      if (slot == null) throw const LearningInvalidCommandException();
      return LearningSqlTransition(
        state: state,
        result: SentenceHuntCommit(state: state, slot: slot, duplicate: false),
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
    SentenceHuntLearningState before,
    domain.SentenceHuntLearningCommand command,
    SentenceHuntLearningState after,
  ) async {
    try {
      SentenceHuntLearningStateValidator.validate(before, catalogue);
      SentenceHuntLearningStateValidator.validate(after, catalogue);
    } on FormatException catch (error) {
      throw LearningInvalidCommandException(error);
    }
    final slot = after.slots[command.sectionId];
    if (slot == null ||
        slot.latestReceipt.token != command.token ||
        after.revision != before.revision + 1 ||
        after.commitOrdinal != before.commitOrdinal + 1) {
      throw const LearningInvalidCommandException();
    }
    final bindingId = await _ensureBinding(db, scopeId, slot);
    await _writeRun(db, scopeId, bindingId, slot, command, after);
    await _writeReceipt(db, scopeId, command, slot, after);
    await _writeAttemptChanges(db, scopeId, before, after, command);
    await _pruneReceipts(db, scopeId, after.commitOrdinal);
    await _writeMistakes(db, scopeId, after.mistakes);
    await _writeSummaries(db, scopeId, after.summaries);
    await _writeCompletions(db, scopeId, after.completions);
    await _writeExposure(db, scopeId, after.teachingExposure);
  }

  @override
  SentenceHuntCommit duplicateResult({
    required SentenceHuntLearningState current,
    required domain.SentenceHuntLearningCommand command,
  }) {
    SentenceHuntLearningStateValidator.validate(current, catalogue);
    final slot = current.slots[command.sectionId];
    if (slot == null) throw const LearningConflictException();
    return SentenceHuntCommit(state: current, slot: slot, duplicate: true);
  }

  Future<({int revision, int commitOrdinal})> _currentScopeHeader(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT owner_kind, owner_id, course_id, family, schema_version, '
          'revision, commit_ordinal, availability_state FROM learning_scopes WHERE id = ?',
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
    if (rows.length > sentenceHuntMaxReceipts) {
      throw const LearningCorruptException();
    }
    final receipts = <_SqlReceipt>[];
    final tokens = <String>{};
    final ordinals = <int>{};
    for (final row in rows) {
      final receipt = _readHistoryReceipt(
        row,
        revision: revision,
        commitOrdinal: commitOrdinal,
      );
      if (!tokens.add(receipt.stored.token) ||
          !ordinals.add(receipt.stored.commitOrdinal)) {
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
    final activityId = _requiredText(row.read<String>('activity_id'));
    return _readSqlReceipt(
      activityId: activityId,
      token: row.read<String>('token'),
      payload: row.read<String>('canonical_payload'),
      before: LearningCursorPosition(
        generation: row.read<int>('before_generation'),
        sequence: row.read<int>('before_sequence'),
        revision: row.read<int>('before_cursor_revision'),
      ),
      after: LearningCursorPosition(
        generation: row.read<int>('after_generation'),
        sequence: row.read<int>('after_sequence'),
        revision: row.read<int>('after_cursor_revision'),
      ),
      commitOrdinal: row.read<int>('commit_ordinal'),
      resultActivityId: _requiredText(row.read<String>('result_activity_id')),
      result: LearningCursorPosition(
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
    final after = LearningCursorPosition(
      generation: row.read<int>('run_generation'),
      sequence: row.read<int>('sequence'),
      revision: row.read<int>('cursor_revision'),
    );
    return _readSqlReceipt(
      activityId: activityId,
      token: row.read<String>('latest_receipt_token'),
      payload: row.read<String>('latest_receipt_payload'),
      before: LearningCursorPosition(
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
    required LearningCursorPosition before,
    required LearningCursorPosition after,
    required int commitOrdinal,
    required String resultActivityId,
    required LearningCursorPosition result,
    required int revision,
    required int scopeCommitOrdinal,
  }) {
    final command = SentenceHuntCommandCodec.decodeCanonicalCommand(
      payload,
      scope: _domainScope,
      catalogue: catalogue,
    );
    if (command.scope != _domainScope ||
        command.sectionId != activityId ||
        command.token != token ||
        command.expected != before ||
        command.expectedScopeRevision >= revision ||
        command.expectedScopeRevision != commitOrdinal - 1 ||
        resultActivityId != activityId ||
        result != after ||
        commitOrdinal < 1 ||
        commitOrdinal > scopeCommitOrdinal ||
        after.generation < 1 ||
        after.sequence < 1) {
      throw const LearningCorruptException();
    }
    final receipt = SentenceHuntReceipt(
      scope: _domainScope,
      sectionId: activityId,
      token: token,
      canonicalCommand: SentenceHuntCommandCodec.legacyCanonicalCommand(
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
        before: before,
        after: after,
        commitOrdinal: commitOrdinal,
        resultActivityId: resultActivityId,
      ),
      command: command,
      domainReceipt: receipt,
    );
  }

  _ReadRun _readRunRow(
    QueryRow row,
    int scopeId, {
    required int revision,
    required int commitOrdinal,
  }) {
    final sectionId = _requiredText(row.read<String>('activity_id'));
    if (row.read<int>('scope_id') != scopeId ||
        row.read<String>('activity_kind') != 'sentence-hunt' ||
        row.readNullable<String>('binding_activity_id') != sectionId) {
      throw const LearningCorruptException();
    }
    final SentenceHuntSection section;
    try {
      section = catalogue.section(sectionId);
    } on Object catch (error) {
      throw LearningContentChangedException(error);
    }
    if (!catalogue.isAvailable(sectionId) ||
        row.readNullable<int>('binding_content_revision') !=
            section.contentRevision ||
        row.readNullable<String>('binding_section_fingerprint') !=
            section.sectionFingerprint) {
      throw const LearningContentChangedException();
    }
    if (row.readNullable<String>('binding_policy_kind') !=
            'discoveryThreshold' ||
        row.readNullable<int>('binding_policy_revision') !=
            section.policyRevision ||
        row.readNullable<String>('binding_catalogue_fingerprint') != null ||
        row.readNullable<String>('binding_annotation_hash') != null ||
        row.readNullable<int>('binding_annotation_revision') != null) {
      throw const LearningCorruptException();
    }
    final mode = _enumByName(
      SentenceHuntRunMode.values,
      row.readNullable<String>('run_mode'),
    );
    final finished = _boolFromInt(row.read<int>('finished'));
    final policyRevision = row.readNullable<int>('policy_revision');
    final threshold = row.readNullable<int>('threshold_percent');
    final runStartRound = row.readNullable<int>('run_start_round');
    if (policyRevision != section.policyRevision ||
        threshold != section.policy.completionThresholdPercent ||
        runStartRound == null ||
        runStartRound < 1 ||
        runStartRound > learningMaxSafeInteger) {
      throw const LearningContentChangedException();
    }
    final cursor = LearningCursorPosition(
      generation: row.read<int>('run_generation'),
      sequence: row.read<int>('sequence'),
      revision: row.read<int>('cursor_revision'),
    );
    final checkpointJson = row.read<String>('checkpoint_json');
    if (utf8.encode(checkpointJson).length > learningMaxCheckpointBytes) {
      throw const LearningCorruptException();
    }
    final sessionId = _requiredText(row.readNullable<String>('session_id'));
    final policy = LessonPolicy(completionThresholdPercent: threshold!);
    final checkpoint = _checkpointCodec.decode(
      checkpointJson,
      scope: _domainScope,
      sectionId: sectionId,
      catalogue: catalogue,
      mode: mode,
      finished: finished,
      policy: policy,
      runStartRound: runStartRound,
    );
    if (checkpoint.sessionId != sessionId ||
        checkpoint.contentRevision != section.contentRevision ||
        checkpoint.sectionFingerprint != section.sectionFingerprint) {
      throw const LearningCorruptException();
    }
    final receipt = _readSqlReceipt(
      activityId: sectionId,
      token: row.read<String>('latest_receipt_token'),
      payload: row.read<String>('latest_receipt_payload'),
      before: LearningCursorPosition(
        generation: row.read<int>('latest_receipt_before_generation'),
        sequence: row.read<int>('latest_receipt_before_sequence'),
        revision: row.read<int>('latest_receipt_before_cursor_revision'),
      ),
      after: cursor,
      commitOrdinal: row.read<int>('latest_receipt_commit_ordinal'),
      resultActivityId: sectionId,
      result: cursor,
      revision: revision,
      scopeCommitOrdinal: commitOrdinal,
    );
    return _ReadRun(
      slot: _PendingSlot(
        sectionId: sectionId,
        cursor: cursor,
        checkpoint: checkpoint,
      ),
      latestReceipt: receipt,
    );
  }

  void _addReceipt(
    Map<String, _SqlReceipt> byToken,
    Map<String, _SqlReceipt> byCursor,
    Map<int, _SqlReceipt> byOrdinal,
    _SqlReceipt receipt,
  ) {
    final oldToken = byToken[receipt.stored.token];
    final oldCursor =
        byCursor[_cursorKey(receipt.stored.activityId, receipt.stored.after)];
    final oldOrdinal = byOrdinal[receipt.stored.commitOrdinal];
    for (final old in [oldToken, oldCursor, oldOrdinal]) {
      if (old != null && !_sameStoredReceipt(old.stored, receipt.stored)) {
        throw const LearningCorruptException();
      }
    }
    byToken[receipt.stored.token] = receipt;
    byCursor[_cursorKey(receipt.stored.activityId, receipt.stored.after)] =
        receipt;
    byOrdinal[receipt.stored.commitOrdinal] = receipt;
  }

  Future<List<SentenceHuntAttempt>> _readAttempts(
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
    if (rows.length > sentenceHuntMaxAttempts) {
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
    final emptySelections = <String>{};
    for (final row in valueRows) {
      final attemptId = _requiredText(row.read<String>('attempt_id'));
      final field = row.read<String>('field');
      if (field != 'selected_token_id' && field != 'expected_token_id') {
        throw const LearningCorruptException();
      }
      final ordinal = row.read<int>('ordinal');
      final valueType = row.read<String>('value_type');
      final textValue = row.readNullable<String>('text_value');
      final intValue = row.readNullable<int>('int_value');
      final boolValue = row.readNullable<int>('bool_value');
      final fields = valuesByAttempt.putIfAbsent(
        attemptId,
        () => <String, List<String>>{},
      );
      if (field == 'selected_token_id' &&
          ordinal == learningMaxSafeInteger &&
          valueType == 'text' &&
          textValue == _emptySelectionMarker &&
          intValue == null &&
          boolValue == null) {
        if (!emptySelections.add(attemptId) ||
            fields['selected_token_id']?.isNotEmpty == true) {
          throw const LearningCorruptException();
        }
        continue;
      }
      if (valueType != 'text' ||
          intValue != null ||
          boolValue != null ||
          emptySelections.contains(attemptId)) {
        throw const LearningCorruptException();
      }
      final values = fields.putIfAbsent(field, () => <String>[]);
      if (ordinal != values.length) throw const LearningCorruptException();
      final text = _requiredText(textValue);
      values.add(text);
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

    final result = <SentenceHuntAttempt>[];
    final attemptIds = <String>{};
    for (final row in rows) {
      final attemptId = _requiredText(row.read<String>('attempt_id'));
      final evidence =
          evidenceByAttempt.remove(attemptId) ?? const <QueryRow>[];
      if (evidence.length != 2) throw const LearningCorruptException();
      final sectionId = _requiredText(row.read<String>('section_id'));
      final activityId = _requiredText(row.read<String>('activity_id'));
      final itemId = _requiredText(row.readNullable<String>('item_id'));
      final generation = row.read<int>('run_generation');
      final sequence = row.read<int>('command_sequence');
      final round = row.read<int>('round');
      final ordinal = row.read<int>('commit_ordinal');
      final content = SentenceHuntContentIdentity(
        sectionId: sectionId,
        itemId: itemId,
        sentenceId: _requiredText(row.readNullable<String>('sentence_id')),
        audioRefId: _requiredText(
          evidence[1].readNullable<String>('audio_ref_id'),
        ),
        annotationHash: _requiredText(
          row.readNullable<String>('annotation_hash'),
        ),
        contentRevision: row.read<int>('content_revision'),
        annotationRevision: row.read<int>('annotation_revision'),
      );
      if (!attemptIds.add(attemptId) ||
          activityId != sectionId ||
          row.read<int>('batch_index') != 0 ||
          row.readNullable<int>('item_occurrence') != null ||
          row.read<String>('answer_kind') != 'sentenceHunt' ||
          row.readNullable<String>('skill') != null ||
          row.readNullable<String>('origin') != null ||
          row.readNullable<int>('assistance_mask') != null ||
          row.readNullable<String>('content_state') != null ||
          row.readNullable<String>('audio_source') != null ||
          row.readNullable<int>('after_debrief') != null ||
          row.readNullable<String>('selected_relation') != null ||
          row.readNullable<String>('expected_relation') != null ||
          ordinal < 1 ||
          ordinal > commitOrdinal ||
          !RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(
            _attemptToken(
              attemptId,
              _domainScope.storageKey,
              sectionId,
              generation,
              sequence,
            ),
          )) {
        throw const LearningCorruptException();
      }
      final proof =
          byCursor[_cursorKey(
            sectionId,
            LearningCursorPosition(
              generation: generation,
              sequence: sequence,
              revision: 0,
            ),
          )];
      if (proof != null && proof.stored.commitOrdinal != ordinal) {
        throw const LearningCorruptException();
      }
      _validateAttemptId(
        attemptId,
        _domainScope.storageKey,
        sectionId,
        generation,
        sequence,
        proof?.stored.token,
      );
      final values =
          valuesByAttempt.remove(attemptId) ?? <String, List<String>>{};
      final expected = values.remove('expected_token_id');
      final selected = values.remove('selected_token_id');
      final emptySelection = emptySelections.remove(attemptId);
      if (values.isNotEmpty || expected == null || expected.isEmpty) {
        throw const LearningCorruptException();
      }
      final List<String> selectedIds;
      if (selected == null) {
        if (emptySelection ||
            proof?.command.action is domain.AnswerSentenceHuntItem &&
                (proof!.command.action as domain.AnswerSentenceHuntItem)
                    .answer
                    .selectedTokenIds
                    .isEmpty) {
          selectedIds = const <String>[];
        } else {
          throw const LearningCorruptException();
        }
      } else {
        if (emptySelection) throw const LearningCorruptException();
        selectedIds = selected;
      }
      final playback = _readPlaybackEvidence(
        evidence[0],
        content,
        generation,
        round,
      );
      _readContentEvidence(evidence[1], content);
      final correct = _boolFromInt(row.read<int>('correct'));
      result.add(
        SentenceHuntAttempt(
          scope: _domainScope,
          content: content,
          runGeneration: generation,
          round: round,
          sequence: sequence,
          selectedTokenIds: selectedIds,
          expectedTokenIds: expected,
          correct: correct,
          presentation: _enumByName(
            AttemptPresentation.values,
            row.readNullable<String>('presentation'),
          ),
          teachingExposed: _boolFromInt(row.read<int>('teaching_exposed')),
          playback: playback,
          answeredAt: _dateFromMicros(row.read<int>('answered_at_us')),
          committedAt: _dateFromMicros(row.read<int>('committed_at_us')),
        ),
      );
    }
    if (valuesByAttempt.isNotEmpty ||
        evidenceByAttempt.isNotEmpty ||
        emptySelections.isNotEmpty) {
      throw const LearningCorruptException();
    }
    return result;
  }

  SentenceHuntPlaybackObservation _readPlaybackEvidence(
    QueryRow row,
    SentenceHuntContentIdentity content,
    int generation,
    int round,
  ) {
    if (row.read<int>('evidence_index') != 0 ||
        row.read<String>('evidence_kind') != 'sentencePlayback' ||
        row.readNullable<String>('slot') != null ||
        row.readNullable<String>('outcome') !=
            CourseAudioOutcome.completed.name ||
        row.readNullable<String>('source') !=
            CourseAudioSource.reviewedRecording.name ||
        row.readNullable<String>('activity_id') != content.sectionId ||
        row.readNullable<int>('run_generation') != generation ||
        row.readNullable<int>('round') != round ||
        row.readNullable<String>('pair_id') != null ||
        row.readNullable<int>('ui_generation') == null ||
        row.readNullable<String>('section_id') != content.sectionId ||
        row.readNullable<String>('item_id') != content.itemId ||
        row.readNullable<String>('sentence_id') != content.sentenceId ||
        row.readNullable<String>('audio_ref_id') != content.audioRefId ||
        row.readNullable<String>('annotation_hash') != content.annotationHash ||
        row.readNullable<int>('annotation_revision') !=
            content.annotationRevision ||
        row.readNullable<int>('content_revision') != content.contentRevision) {
      throw const LearningCorruptException();
    }
    final referenceId = _requiredText(row.readNullable<String>('reference_id'));
    if (referenceId != content.audioRefId) {
      throw const LearningCorruptException();
    }
    return SentenceHuntPlaybackObservation(
      scope: _domainScope,
      content: content,
      runGeneration: generation,
      round: round,
      uiGeneration: row.read<int>('ui_generation'),
      referenceId: referenceId,
      outcome: CourseAudioOutcome.completed,
      source: CourseAudioSource.reviewedRecording,
    );
  }

  void _readContentEvidence(QueryRow row, SentenceHuntContentIdentity content) {
    if (row.read<int>('evidence_index') != 1 ||
        row.read<String>('evidence_kind') != 'sentenceContent' ||
        row.readNullable<String>('slot') != null ||
        row.readNullable<String>('reference_id') != null ||
        row.readNullable<String>('outcome') != null ||
        row.readNullable<String>('source') != null ||
        row.readNullable<String>('activity_id') != null ||
        row.readNullable<int>('run_generation') != null ||
        row.readNullable<int>('round') != null ||
        row.readNullable<String>('pair_id') != null ||
        row.readNullable<int>('ui_generation') != null ||
        row.readNullable<String>('section_id') != content.sectionId ||
        row.readNullable<String>('item_id') != content.itemId ||
        row.readNullable<String>('sentence_id') != content.sentenceId ||
        row.readNullable<String>('audio_ref_id') != content.audioRefId ||
        row.readNullable<String>('annotation_hash') != content.annotationHash ||
        row.readNullable<int>('annotation_revision') !=
            content.annotationRevision ||
        row.readNullable<int>('content_revision') != content.contentRevision) {
      throw const LearningCorruptException();
    }
  }

  Future<Map<SentenceHuntMistakeKey, SentenceHuntMistake>> _readMistakes(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT family, activity_id, item_id, target_sound, skill, pair_id, '
          'section_id, sentence_id, audio_ref_id, annotation_hash, annotation_revision, '
          'content_revision, first_wrong_attempt_id, latest_wrong_attempt_id, '
          'first_wrong_at_us, latest_wrong_at_us, failure_count, last_run_generation '
          'FROM learning_mistakes WHERE scope_id = ? AND family = ? '
          'ORDER BY section_id, item_id, content_revision',
          variables: <Variable<Object>>[
            Variable<int>(scopeId),
            const Variable<String>('sentence-hunt'),
          ],
        )
        .get();
    if (rows.length > sentenceHuntMaxAggregateEntries) {
      throw const LearningCorruptException();
    }
    final result = <SentenceHuntMistakeKey, SentenceHuntMistake>{};
    for (final row in rows) {
      if (row.read<String>('family') != 'sentence-hunt' ||
          row.readNullable<String>('activity_id') != null ||
          row.readNullable<String>('target_sound') != null ||
          row.readNullable<String>('skill') != null ||
          row.readNullable<String>('pair_id') != null ||
          row.readNullable<String>('first_wrong_attempt_id') != null ||
          row.readNullable<String>('latest_wrong_attempt_id') != null ||
          row.readNullable<int>('last_run_generation') != null) {
        throw const LearningCorruptException();
      }
      final content = _rowContentIdentity(row);
      final key = SentenceHuntMistakeKey(scope: _domainScope, content: content);
      final mistake = SentenceHuntMistake(
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

  Future<Map<SentenceHuntSummaryKey, SentenceHuntSummary>> _readSummaries(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT family, activity_id, sound, skill, origin, presentation, assistance_mask, '
          'pair_id, section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
          'annotation_revision, content_revision, bucket, correct, total '
          'FROM learning_summaries WHERE scope_id = ? AND family = ? '
          'ORDER BY section_id, item_id, content_revision, bucket',
          variables: <Variable<Object>>[
            Variable<int>(scopeId),
            const Variable<String>('sentence-hunt'),
          ],
        )
        .get();
    final buckets = <SentenceHuntSummaryKey, Map<String, SentenceHuntCounts>>{};
    for (final row in rows) {
      if (row.read<String>('family') != 'sentence-hunt' ||
          row.readNullable<String>('activity_id') != null ||
          row.readNullable<String>('sound') != null ||
          row.readNullable<String>('skill') != null ||
          row.readNullable<String>('origin') != null ||
          row.readNullable<String>('presentation') != null ||
          row.readNullable<int>('assistance_mask') != null ||
          row.readNullable<String>('pair_id') != null) {
        throw const LearningCorruptException();
      }
      final content = _rowContentIdentity(row);
      final key = SentenceHuntSummaryKey(scope: _domainScope, content: content);
      final bucket = row.read<String>('bucket');
      if (!const <String>{
        'firstInRun',
        'repeatInRun',
        'firstTeachingExposed',
        'repeatTeachingExposed',
      }.contains(bucket)) {
        throw const LearningCorruptException();
      }
      final counts = buckets.putIfAbsent(
        key,
        () => <String, SentenceHuntCounts>{},
      );
      if (counts.containsKey(bucket)) throw const LearningCorruptException();
      counts[bucket] = SentenceHuntCounts(
        correct: row.read<int>('correct'),
        total: row.read<int>('total'),
      );
    }
    if (buckets.length > sentenceHuntMaxAggregateEntries) {
      throw const LearningCorruptException();
    }
    final result = <SentenceHuntSummaryKey, SentenceHuntSummary>{};
    for (final entry in buckets.entries) {
      final values = entry.value;
      if (values.length != 4 ||
          !values.containsKey('firstInRun') ||
          !values.containsKey('repeatInRun') ||
          !values.containsKey('firstTeachingExposed') ||
          !values.containsKey('repeatTeachingExposed')) {
        throw const LearningCorruptException();
      }
      result[entry.key] = SentenceHuntSummary(
        key: entry.key,
        firstInRun: values['firstInRun']!,
        repeatInRun: values['repeatInRun']!,
        firstTeachingExposed: values['firstTeachingExposed']!,
        repeatTeachingExposed: values['repeatTeachingExposed']!,
      );
    }
    return result;
  }

  Future<List<SentenceHuntCompletion>> _readCompletions(
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
    if (rows.length > sentenceHuntMaxAggregateEntries) {
      throw const LearningCorruptException();
    }
    final result = <SentenceHuntCompletion>[];
    final keys = <String>{};
    for (final row in rows) {
      final sectionId = _requiredText(row.read<String>('activity_id'));
      final contentRevision = row.read<int>('content_revision');
      final policyRevision = row.read<int>('policy_revision');
      final threshold = row.read<int>('threshold_percent');
      if (row.read<String>('policy_kind') != 'discoveryThreshold' ||
          threshold < 1 ||
          threshold > 100 ||
          !_completionIsRegistered(
            sectionId,
            contentRevision,
            policyRevision,
            threshold,
          ) ||
          !keys.add(
            jsonEncode([sectionId, contentRevision, policyRevision, threshold]),
          )) {
        throw const LearningCorruptException();
      }
      result.add(
        SentenceHuntCompletion(
          scope: _domainScope,
          sectionId: sectionId,
          contentRevision: contentRevision,
          policyRevision: policyRevision,
          thresholdPercent: threshold,
          committedAt: _dateFromMicros(row.read<int>('committed_at_us')),
        ),
      );
    }
    return result;
  }

  Future<Set<SentenceHuntExposureKey>> _readExposure(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT family, activity_id, item_id, target_sound, section_id, '
          'content_revision, presentations, assistance_mask FROM learning_exposure '
          'WHERE scope_id = ? ORDER BY section_id, content_revision',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    if (rows.length > sentenceHuntMaxAggregateEntries) {
      throw const LearningCorruptException();
    }
    final result = <SentenceHuntExposureKey>{};
    for (final row in rows) {
      if (row.read<String>('family') != 'sentence-hunt' ||
          row.readNullable<String>('activity_id') != null ||
          row.readNullable<String>('item_id') != null ||
          row.readNullable<String>('target_sound') != null ||
          row.readNullable<int>('presentations') != null ||
          row.readNullable<int>('assistance_mask') != null) {
        throw const LearningCorruptException();
      }
      final key = SentenceHuntExposureKey(
        scope: _domainScope,
        sectionId: _requiredText(row.readNullable<String>('section_id')),
        contentRevision: row.read<int>('content_revision'),
      );
      if (!result.add(key)) throw const LearningCorruptException();
    }
    return result;
  }

  SentenceHuntContentIdentity _rowContentIdentity(QueryRow row) =>
      SentenceHuntContentIdentity(
        sectionId: _requiredText(row.readNullable<String>('section_id')),
        itemId: _requiredText(row.readNullable<String>('item_id')),
        sentenceId: _requiredText(row.readNullable<String>('sentence_id')),
        audioRefId: _requiredText(row.readNullable<String>('audio_ref_id')),
        annotationHash: _requiredText(
          row.readNullable<String>('annotation_hash'),
        ),
        contentRevision: row.read<int>('content_revision'),
        annotationRevision: row.read<int>('annotation_revision'),
      );

  bool _completionIsRegistered(
    String sectionId,
    int contentRevision,
    int policyRevision,
    int threshold,
  ) {
    try {
      final section = catalogue.section(sectionId);
      if (section.contentRevision == contentRevision &&
          section.policyRevision == policyRevision &&
          section.policy.completionThresholdPercent == threshold) {
        return true;
      }
    } on Object {
      // Check retained historical descriptors below.
    }
    return catalogue.historicalSections.any(
      (descriptor) =>
          descriptor.sectionId == sectionId &&
          descriptor.contentRevision == contentRevision &&
          descriptor.policyRevision == policyRevision &&
          descriptor.completionThresholdPercent == threshold,
    );
  }

  Future<int> _ensureBinding(
    LearningDatabase db,
    int scopeId,
    SentenceHuntSlot slot,
  ) async {
    final section = catalogue.section(slot.sectionId);
    if (slot.checkpoint.sectionFingerprint != section.sectionFingerprint ||
        slot.checkpoint.contentRevision != section.contentRevision) {
      throw const LearningContentChangedException();
    }
    await db.customStatement(
      'INSERT INTO learning_content_bindings '
      '(scope_id, activity_id, content_revision, policy_kind, policy_revision, '
      'catalogue_fingerprint, section_fingerprint, annotation_hash, annotation_revision) '
      "VALUES (?, ?, ?, 'discoveryThreshold', ?, NULL, ?, NULL, NULL) "
      'ON CONFLICT DO NOTHING',
      [
        scopeId,
        slot.sectionId,
        section.contentRevision,
        section.policyRevision,
        section.sectionFingerprint,
      ],
    );
    final rows = await db
        .customSelect(
          'SELECT id FROM learning_content_bindings WHERE scope_id = ? '
          'AND activity_id = ? AND content_revision = ? '
          "AND policy_kind = 'discoveryThreshold' AND policy_revision = ? "
          'AND catalogue_fingerprint IS NULL AND section_fingerprint = ? '
          'AND annotation_hash IS NULL AND annotation_revision IS NULL',
          variables: <Variable<Object>>[
            Variable<int>(scopeId),
            Variable<String>(slot.sectionId),
            Variable<int>(section.contentRevision),
            Variable<int>(section.policyRevision),
            Variable<String>(section.sectionFingerprint),
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
    SentenceHuntSlot slot,
    domain.SentenceHuntLearningCommand command,
    SentenceHuntLearningState after,
  ) async {
    final section = catalogue.section(slot.sectionId);
    final checkpointJson = _checkpointCodec.encode(slot.checkpoint);
    final payload = SentenceHuntCommandCodec.canonicalCommand(command);
    await db.customStatement(
      'INSERT INTO learning_runs '
      '(scope_id, activity_id, activity_kind, run_generation, sequence, cursor_revision, '
      'content_binding_id, run_mode, finished, session_id, policy_revision, threshold_percent, '
      'run_start_round, checkpoint_json, latest_receipt_token, latest_receipt_payload, '
      'latest_receipt_before_generation, latest_receipt_before_sequence, '
      'latest_receipt_before_cursor_revision, latest_receipt_commit_ordinal) '
      "VALUES (?, ?, 'sentence-hunt', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
      'ON CONFLICT(scope_id, activity_id) DO UPDATE SET '
      "activity_kind = 'sentence-hunt', run_generation = excluded.run_generation, "
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
        slot.sectionId,
        slot.cursor.generation,
        slot.cursor.sequence,
        slot.cursor.revision,
        bindingId,
        slot.checkpoint.mode.name,
        slot.checkpoint.finished ? 1 : 0,
        slot.checkpoint.sessionId,
        section.policyRevision,
        slot.checkpoint.policy.completionThresholdPercent,
        slot.checkpoint.runStartRound,
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
    domain.SentenceHuntLearningCommand command,
    SentenceHuntSlot slot,
    SentenceHuntLearningState after,
  ) async {
    await db.customStatement(
      'INSERT INTO learning_command_receipts '
      '(scope_id, activity_id, token, canonical_payload, before_generation, before_sequence, '
      'before_cursor_revision, after_generation, after_sequence, after_cursor_revision, '
      'commit_ordinal, result_activity_id, result_generation, result_sequence, result_cursor_revision) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        scopeId,
        command.sectionId,
        command.token,
        SentenceHuntCommandCodec.canonicalCommand(command),
        command.expected.generation,
        command.expected.sequence,
        command.expected.revision,
        slot.cursor.generation,
        slot.cursor.sequence,
        slot.cursor.revision,
        after.commitOrdinal,
        command.sectionId,
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
    SentenceHuntLearningState before,
    SentenceHuntLearningState after,
    domain.SentenceHuntLearningCommand command,
  ) async {
    final beforeKeys = before.attempts.map(_attemptKey).toSet();
    final afterByKey = <String, SentenceHuntAttempt>{
      for (final attempt in after.attempts) _attemptKey(attempt): attempt,
    };
    for (final attempt in before.attempts) {
      final key = _attemptKey(attempt);
      if (afterByKey.containsKey(key)) continue;
      final rows = await db
          .customSelect(
            'SELECT attempt_id FROM learning_attempts WHERE scope_id = ? '
            'AND activity_id = ? AND run_generation = ? AND command_sequence = ? '
            'AND batch_index = 0',
            variables: <Variable<Object>>[
              Variable<int>(scopeId),
              Variable<String>(attempt.content.sectionId),
              Variable<int>(attempt.runGeneration),
              Variable<int>(attempt.sequence),
            ],
          )
          .get();
      if (rows.length > 1) throw const LearningCorruptException();
      if (rows.isNotEmpty) {
        final attemptId = rows.single.read<String>('attempt_id');
        await db.customStatement(
          'DELETE FROM learning_attempt_values WHERE scope_id = ? AND attempt_id = ?',
          [scopeId, attemptId],
        );
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
      final attempt = entry.value;
      if (command.action is! domain.AnswerSentenceHuntItem ||
          command.sectionId != attempt.content.sectionId ||
          command.expected.generation != attempt.runGeneration ||
          attempt.sequence != command.expected.sequence + 1 ||
          command.submittedAt != attempt.answeredAt) {
        throw const LearningInvalidCommandException();
      }
      final attemptId = _attemptId(
        _domainScope.storageKey,
        command.sectionId,
        attempt.runGeneration,
        attempt.sequence,
        command.token,
      );
      await _insertAttempt(
        db,
        scopeId,
        attemptId,
        attempt,
        after.commitOrdinal,
      );
    }
  }

  Future<void> _insertAttempt(
    LearningDatabase db,
    int scopeId,
    String attemptId,
    SentenceHuntAttempt attempt,
    int commitOrdinal,
  ) async {
    await db.customStatement(
      'INSERT INTO learning_attempts '
      '(scope_id, attempt_id, activity_id, run_generation, command_sequence, batch_index, '
      'item_id, item_occurrence, content_revision, commit_ordinal, answered_at_us, '
      'committed_at_us, answer_kind, correct, skill, origin, presentation, assistance_mask, '
      'content_state, audio_source, round, after_debrief, teaching_exposed, selected_relation, '
      'expected_relation, section_id, sentence_id, annotation_hash, annotation_revision) '
      "VALUES (?, ?, ?, ?, ?, 0, ?, NULL, ?, ?, ?, ?, 'sentenceHunt', ?, NULL, NULL, ?, "
      'NULL, NULL, NULL, ?, NULL, ?, NULL, NULL, ?, ?, ?, ?)',
      [
        scopeId,
        attemptId,
        attempt.content.sectionId,
        attempt.runGeneration,
        attempt.sequence,
        attempt.content.itemId,
        attempt.content.contentRevision,
        commitOrdinal,
        _dateMicros(attempt.answeredAt),
        _dateMicros(attempt.committedAt),
        attempt.correct ? 1 : 0,
        attempt.presentation.name,
        attempt.round,
        attempt.teachingExposed ? 1 : 0,
        attempt.content.sectionId,
        attempt.content.sentenceId,
        attempt.content.annotationHash,
        attempt.content.annotationRevision,
      ],
    );
    if (attempt.selectedTokenIds.isEmpty) {
      // Reserve the maximal ordinal for the empty-list marker; authored token
      // positions are bounded by each section's finite token list.
      await _insertTextValue(
        db,
        scopeId,
        attemptId,
        'selected_token_id',
        learningMaxSafeInteger,
        _emptySelectionMarker,
      );
    } else {
      for (var index = 0; index < attempt.selectedTokenIds.length; index++) {
        await _insertTextValue(
          db,
          scopeId,
          attemptId,
          'selected_token_id',
          index,
          attempt.selectedTokenIds[index],
        );
      }
    }
    for (var index = 0; index < attempt.expectedTokenIds.length; index++) {
      await _insertTextValue(
        db,
        scopeId,
        attemptId,
        'expected_token_id',
        index,
        attempt.expectedTokenIds[index],
      );
    }
    final playback = attempt.playback;
    await db.customStatement(
      'INSERT INTO learning_attempt_evidence '
      '(scope_id, attempt_id, evidence_index, evidence_kind, slot, reference_id, outcome, '
      'source, activity_id, run_generation, round, pair_id, ui_generation, section_id, '
      'item_id, sentence_id, audio_ref_id, annotation_hash, annotation_revision, content_revision) '
      "VALUES (?, ?, 0, 'sentencePlayback', NULL, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?)",
      [
        scopeId,
        attemptId,
        playback.referenceId,
        playback.outcome.name,
        playback.source.name,
        attempt.content.sectionId,
        attempt.runGeneration,
        attempt.round,
        playback.uiGeneration,
        attempt.content.sectionId,
        attempt.content.itemId,
        attempt.content.sentenceId,
        attempt.content.audioRefId,
        attempt.content.annotationHash,
        attempt.content.annotationRevision,
        attempt.content.contentRevision,
      ],
    );
    await db.customStatement(
      'INSERT INTO learning_attempt_evidence '
      '(scope_id, attempt_id, evidence_index, evidence_kind, slot, reference_id, outcome, '
      'source, activity_id, run_generation, round, pair_id, ui_generation, section_id, '
      'item_id, sentence_id, audio_ref_id, annotation_hash, annotation_revision, content_revision) '
      "VALUES (?, ?, 1, 'sentenceContent', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?, ?, ?, ?, ?, ?)",
      [
        scopeId,
        attemptId,
        attempt.content.sectionId,
        attempt.content.itemId,
        attempt.content.sentenceId,
        attempt.content.audioRefId,
        attempt.content.annotationHash,
        attempt.content.annotationRevision,
        attempt.content.contentRevision,
      ],
    );
  }

  Future<void> _insertTextValue(
    LearningDatabase db,
    int scopeId,
    String attemptId,
    String field,
    int ordinal,
    String value,
  ) async {
    await db.customStatement(
      'INSERT INTO learning_attempt_values '
      '(scope_id, attempt_id, field, ordinal, value_type, text_value, int_value, bool_value) '
      "VALUES (?, ?, ?, ?, 'text', ?, NULL, NULL)",
      [scopeId, attemptId, field, ordinal, value],
    );
  }

  Future<void> _writeMistakes(
    LearningDatabase db,
    int scopeId,
    Map<SentenceHuntMistakeKey, SentenceHuntMistake> mistakes,
  ) async {
    await db.customStatement(
      "DELETE FROM learning_mistakes WHERE scope_id = ? AND family = 'sentence-hunt'",
      [scopeId],
    );
    for (final mistake in mistakes.values) {
      final content = mistake.content;
      await db.customStatement(
        'INSERT INTO learning_mistakes '
        '(scope_id, family, activity_id, item_id, target_sound, skill, pair_id, section_id, '
        'sentence_id, audio_ref_id, annotation_hash, annotation_revision, content_revision, '
        'first_wrong_attempt_id, latest_wrong_attempt_id, first_wrong_at_us, latest_wrong_at_us, '
        'failure_count, last_run_generation) '
        "VALUES (?, 'sentence-hunt', NULL, ?, NULL, NULL, NULL, ?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?, ?, NULL)",
        [
          scopeId,
          content.itemId,
          content.sectionId,
          content.sentenceId,
          content.audioRefId,
          content.annotationHash,
          content.annotationRevision,
          content.contentRevision,
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
    Map<SentenceHuntSummaryKey, SentenceHuntSummary> summaries,
  ) async {
    await db.customStatement(
      "DELETE FROM learning_summaries WHERE scope_id = ? AND family = 'sentence-hunt'",
      [scopeId],
    );
    for (final entry in summaries.entries) {
      final content = entry.key.content;
      for (final bucket in <(String, SentenceHuntCounts)>[
        ('firstInRun', entry.value.firstInRun),
        ('repeatInRun', entry.value.repeatInRun),
        ('firstTeachingExposed', entry.value.firstTeachingExposed),
        ('repeatTeachingExposed', entry.value.repeatTeachingExposed),
      ]) {
        await db.customStatement(
          'INSERT INTO learning_summaries '
          '(scope_id, family, activity_id, sound, skill, origin, presentation, assistance_mask, '
          'pair_id, section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
          'annotation_revision, content_revision, bucket, correct, total) '
          "VALUES (?, 'sentence-hunt', NULL, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          [
            scopeId,
            content.sectionId,
            content.itemId,
            content.sentenceId,
            content.audioRefId,
            content.annotationHash,
            content.annotationRevision,
            content.contentRevision,
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
    List<SentenceHuntCompletion> completions,
  ) async {
    for (final completion in completions) {
      await db.customStatement(
        'INSERT INTO learning_completions '
        '(scope_id, activity_id, content_revision, policy_kind, policy_revision, '
        'threshold_percent, committed_at_us) '
        "VALUES (?, ?, ?, 'discoveryThreshold', ?, ?, ?) ON CONFLICT DO NOTHING",
        [
          scopeId,
          completion.sectionId,
          completion.contentRevision,
          completion.policyRevision,
          completion.thresholdPercent,
          _dateMicros(completion.committedAt),
        ],
      );
    }
  }

  Future<void> _writeExposure(
    LearningDatabase db,
    int scopeId,
    Set<SentenceHuntExposureKey> exposure,
  ) async {
    await db.customStatement(
      "DELETE FROM learning_exposure WHERE scope_id = ? AND family = 'sentence-hunt'",
      [scopeId],
    );
    for (final key in exposure) {
      await db.customStatement(
        'INSERT INTO learning_exposure '
        '(scope_id, family, activity_id, item_id, target_sound, section_id, '
        'content_revision, presentations, assistance_mask) '
        "VALUES (?, 'sentence-hunt', NULL, NULL, NULL, ?, ?, NULL, NULL)",
        [scopeId, key.sectionId, key.contentRevision],
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
    required this.sectionId,
    required this.cursor,
    required this.checkpoint,
  });

  final String sectionId;
  final LearningCursorPosition cursor;
  final SentenceHuntCheckpoint checkpoint;
}

final class _SqlReceipt {
  const _SqlReceipt({
    required this.stored,
    required this.command,
    required this.domainReceipt,
  });

  final LearningStoredReceipt stored;
  final domain.SentenceHuntLearningCommand command;
  final SentenceHuntReceipt domainReceipt;
}

List<T> _latest<T>(List<T> values, int limit) =>
    values.length <= limit ? values : values.sublist(values.length - limit);

String _attemptKey(SentenceHuntAttempt attempt) => jsonEncode([
  attempt.content.sectionId,
  attempt.runGeneration,
  attempt.sequence,
]);

String _attemptId(
  String storageKey,
  String sectionId,
  int generation,
  int sequence,
  String token,
) => jsonEncode([storageKey, sectionId, generation, sequence, token]);

String _cursorKey(String sectionId, LearningCursorPosition cursor) =>
    jsonEncode([sectionId, cursor.generation, cursor.sequence]);

String _attemptToken(
  String attemptId,
  String storageKey,
  String sectionId,
  int generation,
  int sequence,
) {
  final decoded = jsonDecode(attemptId);
  if (decoded is! List ||
      decoded.length != 5 ||
      decoded[0] != storageKey ||
      decoded[1] != sectionId ||
      decoded[2] != generation ||
      decoded[3] != sequence ||
      decoded[4] is! String ||
      !RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(decoded[4] as String) ||
      jsonEncode(decoded) != attemptId) {
    throw const LearningCorruptException();
  }
  return decoded[4] as String;
}

void _validateAttemptId(
  String attemptId,
  String storageKey,
  String sectionId,
  int generation,
  int sequence,
  String? receiptToken,
) {
  final token = _attemptToken(
    attemptId,
    storageKey,
    sectionId,
    generation,
    sequence,
  );
  if (receiptToken != null && token != receiptToken) {
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

const String _emptySelectionMarker = '__sentence_hunt_empty_selection__';
