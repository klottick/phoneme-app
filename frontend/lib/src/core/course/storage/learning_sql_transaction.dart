import 'package:drift/drift.dart';

import '../course_attempt.dart';
import '../course_learning_error.dart';
import '../course_learning_state.dart';
import 'learning_database.dart';
import 'learning_storage_scope.dart';
import '../learning_storage_types.dart';

/// A durable command receipt, combining its complete replay identity with the
/// cursor and commit position recorded by SQLite.
final class LearningStoredReceipt {
  const LearningStoredReceipt({
    required this.activityId,
    required this.token,
    required this.canonicalPayload,
    required this.before,
    required this.after,
    required this.commitOrdinal,
    required this.resultActivityId,
  });

  final String activityId;
  final String token;
  final String canonicalPayload;
  final LearningCursorPosition before;
  final LearningCursorPosition after;
  final int commitOrdinal;
  final String resultActivityId;
}

/// The typed state/result produced by evaluating one SQLite command.
final class LearningSqlTransition<S, R> {
  const LearningSqlTransition({required this.state, required this.result});

  final S state;
  final R result;
}

/// Family-owned decoding/evaluation/persistence behind the shared SQL
/// transaction and receipt protocol.
abstract interface class SqliteLearningProfileAdapter<S, C, R> {
  LearningStorageScope get scope;

  String commandActivityId(C command);
  String commandToken(C command);

  /// Complete identity bytes must bind both activity ID and required scope
  /// revision, not just the profile-specific action.
  String commandCanonicalPayload(C command);

  int commandAuthGeneration(C command);
  int commandExpectedScopeRevision(C command);
  LearningCursorPosition commandExpectedCursor(C command);
  bool isStart(C command);

  /// Rebuilds every normalized relation from one supplied SQLite snapshot.
  /// Course pending rows are ordered by enqueue commit ordinal then event index.
  Future<S> loadState(
    LearningDatabase db,
    int scopeId, {
    required int revision,
    required int commitOrdinal,
  });

  /// Looks up one token across retained history and every activity's latest
  /// receipt. Implementations reject inconsistent or multiply-claimed rows.
  Future<LearningStoredReceipt?> findReceipt(
    LearningDatabase db,
    int scopeId,
    String token,
  );

  LearningCursorPosition? cursorFor(S state, String activityId);

  LearningSqlTransition<S, R> evaluate({
    required S before,
    required C command,
    required int nextRevision,
    required int nextCommitOrdinal,
    required DateTime committedAt,
  });

  Future<void> persist(
    LearningDatabase db,
    int scopeId,
    S before,
    C command,
    S after,
  );

  R duplicateResult({required S current, required C command});
}

/// Coordinates typed learner commands directly against normalized SQLite
/// rows. SQLite write locks and scope compare-and-swap provide cross-connection
/// serialization; this object deliberately has no process-local queue.
final class SqliteLearningCommandCoordinator<S, C, R> {
  SqliteLearningCommandCoordinator({
    required this.database,
    required this.adapter,
    required this.authGeneration,
    required this.currentAuth,
    required this.backendOwner,
    required this.clock,
    this.onCommitted,
  }) : _scope = adapter.scope;

  final LearningDatabaseHandle database;
  final SqliteLearningProfileAdapter<S, C, R> adapter;
  final int authGeneration;
  final LearningAuthScope Function() currentAuth;
  final LearningOwner Function() backendOwner;
  final DateTime Function() clock;
  final void Function()? onCommitted;
  final LearningStorageScope _scope;

  Future<S> load() async {
    _checkAuth();
    final db = await _openDatabase();
    final scopeId = await _ensureScope(db);
    try {
      final state = await _readSnapshot(db, () async {
        _checkAuth();
        final header = await _readScopeHeader(db, scopeId);
        _checkAuth();
        final current = await adapter.loadState(
          db,
          scopeId,
          revision: header.revision,
          commitOrdinal: header.commitOrdinal,
        );
        _checkAuth();
        return current;
      });
      _checkAuth();
      return state;
    } on Object catch (error, stackTrace) {
      _throwReadFailure(error, stackTrace);
    }
  }

  /// Reopens the same configured database and retries the typed read. There is
  /// no delete/reset/blank-state fallback for I/O or SQL failures.
  Future<S> retryLoad() async {
    _checkAuth();
    try {
      await database.reopen();
    } on Object catch (error, stackTrace) {
      _throwReadFailure(error, stackTrace);
    }
    _checkAuth();
    return load();
  }

  Future<R> submit(C command) async {
    _checkAuth();
    final commandGeneration = adapter.commandAuthGeneration(command);
    final activityId = adapter.commandActivityId(command);
    final token = adapter.commandToken(command);
    final canonicalPayload = adapter.commandCanonicalPayload(command);
    final expectedScopeRevision = adapter.commandExpectedScopeRevision(command);
    final expectedCursor = adapter.commandExpectedCursor(command);
    final start = adapter.isStart(command);
    _checkAuth(commandGeneration: commandGeneration);

    final db = await _openDatabase();
    final scopeId = await _ensureScope(db);
    var writeStarted = false;
    try {
      final outcome = await db.transaction(() async {
        _checkAuth(commandGeneration: commandGeneration);

        // This no-op UPDATE is deliberately the first SQL operation in every
        // learner write transaction. It serializes writers across connections.
        writeStarted = true;
        final lockedRows = await db.acquireLearningScopeWriteLock(scopeId);
        _checkAuth(commandGeneration: commandGeneration);
        if (lockedRows != 1) {
          throw const LearningCorruptException();
        }

        final header = await _readScopeHeader(db, scopeId);
        _checkAuth(commandGeneration: commandGeneration);
        final receipt = await adapter.findReceipt(db, scopeId, token);
        _checkAuth(commandGeneration: commandGeneration);
        if (receipt != null) {
          if (receipt.token != token ||
              receipt.resultActivityId != receipt.activityId) {
            throw const LearningCorruptException();
          }
          if (receipt.activityId != activityId ||
              receipt.canonicalPayload != canonicalPayload) {
            throw const LearningInvalidCommandException();
          }
          final current = await adapter.loadState(
            db,
            scopeId,
            revision: header.revision,
            commitOrdinal: header.commitOrdinal,
          );
          _checkAuth(commandGeneration: commandGeneration);
          final duplicate = adapter.duplicateResult(
            current: current,
            command: command,
          );
          _checkAuth(commandGeneration: commandGeneration);
          return _SqlCommandOutcome<R>(result: duplicate, committed: false);
        }

        if (expectedScopeRevision != header.revision) {
          throw const LearningConflictException();
        }
        final before = await adapter.loadState(
          db,
          scopeId,
          revision: header.revision,
          commitOrdinal: header.commitOrdinal,
        );
        _checkAuth(commandGeneration: commandGeneration);

        final currentCursor = adapter.cursorFor(before, activityId);
        if (currentCursor != null) {
          if (currentCursor != expectedCursor) {
            throw const LearningConflictException();
          }
        } else if (expectedCursor.generation != 0 ||
            expectedCursor.sequence != 0 ||
            expectedCursor.revision != 0) {
          throw const LearningConflictException();
        } else if (!start) {
          throw const LearningInvalidCommandException();
        }

        if (header.revision >= 9007199254740991 ||
            header.commitOrdinal >= 9007199254740991) {
          throw const LearningInvalidCommandException();
        }
        final nextRevision = header.revision + 1;
        final nextCommitOrdinal = header.commitOrdinal + 1;
        final committedAt = clock().toUtc();
        final transition = adapter.evaluate(
          before: before,
          command: command,
          nextRevision: nextRevision,
          nextCommitOrdinal: nextCommitOrdinal,
          committedAt: committedAt,
        );
        _checkAuth(commandGeneration: commandGeneration);

        await adapter.persist(db, scopeId, before, command, transition.state);
        _checkAuth(commandGeneration: commandGeneration);
        final updatedRows = await db.compareAndSwapLearningScope(
          scopeId: scopeId,
          expectedRevision: header.revision,
          expectedCommitOrdinal: header.commitOrdinal,
          nextRevision: nextRevision,
          nextCommitOrdinal: nextCommitOrdinal,
        );
        _checkAuth(commandGeneration: commandGeneration);
        if (updatedRows != 1) {
          throw const LearningConflictException();
        }
        return _SqlCommandOutcome<R>(
          result: transition.result,
          committed: true,
        );
      });

      if (outcome.committed) _notifyCommitted();
      _checkAuth(commandGeneration: commandGeneration);
      return outcome.result;
    } on Object catch (error, stackTrace) {
      _checkAuth(commandGeneration: commandGeneration);
      if (_isTypedLearningError(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (writeStarted) throw LearningSaveException(error);
      throw LearningUnavailableException(error);
    }
  }

  Future<List<SupportedCloudEvent>> readSupportedCourseEvents() async {
    _checkAuth();
    _requireCourseScope();
    final db = await _openDatabase();
    try {
      final events = await _readSnapshot(db, () async {
        _checkAuth();
        final scopeId = await _findExistingScopeId(db);
        _checkAuth();
        if (scopeId == null) return const <SupportedCloudEvent>[];
        await _readScopeHeader(db, scopeId);
        _checkAuth();
        final rows =
            await (db.select(db.supportedSyncOutbox)
                  ..where((row) => row.scopeId.equals(scopeId))
                  ..orderBy([
                    (row) => OrderingTerm.asc(row.enqueueCommitOrdinal),
                    (row) => OrderingTerm.asc(row.enqueueEventIndex),
                  ]))
                .get();
        _checkAuth();
        return rows.map(_supportedEvent).toList(growable: false);
      });
      _checkAuth();
      return events;
    } on Object catch (error, stackTrace) {
      _throwReadFailure(error, stackTrace);
    }
  }

  Future<void> acknowledgeSupportedCourseEvents(Set<String> ids) async {
    _checkAuth();
    _requireCourseScope();
    if (ids.isEmpty) {
      _checkAuth();
      return;
    }

    final db = await _openDatabase();
    late final int? foundScopeId;
    try {
      foundScopeId = await _readSnapshot(db, () async {
        _checkAuth();
        final existingScopeId = await _findExistingScopeId(db);
        _checkAuth();
        if (existingScopeId != null) {
          await _readScopeHeader(db, existingScopeId);
          _checkAuth();
        }
        return existingScopeId;
      });
    } on Object catch (error, stackTrace) {
      _throwReadFailure(error, stackTrace);
    }
    _checkAuth();
    final scopeId = foundScopeId;
    if (scopeId == null) {
      _checkAuth();
      return;
    }
    late final List<String> initiallyPending;
    try {
      initiallyPending = await _matchingEventIds(db, scopeId, ids);
    } on Object catch (error, stackTrace) {
      _throwReadFailure(error, stackTrace);
    }
    _checkAuth();
    if (initiallyPending.isEmpty) {
      _checkAuth();
      return;
    }

    var writeStarted = false;
    try {
      await db.transaction(() async {
        _checkAuth();

        // Keep the same first-write serialization fence as learner commands.
        writeStarted = true;
        final lockedRows = await db.acquireLearningScopeWriteLock(scopeId);
        _checkAuth();
        if (lockedRows != 1) {
          throw const LearningCorruptException();
        }
        final header = await _readScopeHeader(db, scopeId);
        _checkAuth();
        final pending = await _matchingEventIds(db, scopeId, ids);
        _checkAuth();
        if (pending.isEmpty) return;
        if (header.revision >= 9007199254740991) {
          throw const LearningInvalidCommandException();
        }

        var deletedRows = 0;
        for (final chunk in _chunks(pending)) {
          final placeholders = List<String>.filled(
            chunk.length,
            '?',
          ).join(', ');
          final variables = <Variable<Object>>[
            Variable<int>(scopeId),
            for (final id in chunk) Variable<String>(id),
          ];
          deletedRows += await db.customUpdate(
            'DELETE FROM supported_sync_outbox WHERE scope_id = ? '
            'AND event_id IN ($placeholders)',
            variables: variables,
            updates: <TableInfo>{db.supportedSyncOutbox},
          );
        }
        _checkAuth();
        if (deletedRows != pending.length) {
          throw const LearningConflictException();
        }
        final updatedRows = await db.compareAndSwapLearningScope(
          scopeId: scopeId,
          expectedRevision: header.revision,
          expectedCommitOrdinal: header.commitOrdinal,
          nextRevision: header.revision + 1,
          nextCommitOrdinal: header.commitOrdinal,
        );
        _checkAuth();
        if (updatedRows != 1) {
          throw const LearningConflictException();
        }
      });
      _checkAuth();
    } on Object catch (error, stackTrace) {
      _checkAuth();
      if (_isTypedLearningError(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (writeStarted) throw LearningSaveException(error);
      throw LearningUnavailableException(error);
    }
  }

  Future<LearningDatabase> _openDatabase() async {
    _checkAuth();
    try {
      final db = await database.open();
      _checkAuth();
      return db;
    } on Object catch (error, stackTrace) {
      _throwReadFailure(error, stackTrace);
    }
  }

  /// Drift's native transaction delegate uses `BEGIN IMMEDIATE`, which blocks
  /// a second connection from committing while a reader is assembling state.
  /// Use a deferred SQLite read snapshot instead, while holding Drift's local
  /// executor lock so operations on this connection cannot interleave.
  Future<T> _readSnapshot<T>(LearningDatabase db, Future<T> Function() read) =>
      db.exclusively(() async {
        var transactionStarted = false;
        try {
          await db.customStatement('BEGIN DEFERRED TRANSACTION');
          transactionStarted = true;
          final result = await read();
          await db.customStatement('COMMIT');
          transactionStarted = false;
          return result;
        } on Object catch (error, stackTrace) {
          if (transactionStarted) {
            try {
              await db.customStatement('ROLLBACK');
            } on Object {
              // Preserve the original read/commit failure; callers receive an
              // explicit typed unavailable error rather than a partial state.
            }
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      });

  Future<int> _ensureScope(LearningDatabase db) async {
    _checkAuth();
    try {
      final scopeId = await db.transaction(() async {
        _checkAuth();
        final ensuredScopeId = await db.ensureScope(_scope);
        _checkAuth();
        return ensuredScopeId;
      });
      _checkAuth();
      return scopeId;
    } on Object catch (error, stackTrace) {
      _throwReadFailure(error, stackTrace);
    }
  }

  Future<({int revision, int commitOrdinal})> _readScopeHeader(
    LearningDatabase db,
    int scopeId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT owner_kind, owner_id, course_id, family, schema_version, '
          'revision, commit_ordinal, availability_state '
          'FROM learning_scopes WHERE id = ?',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    if (rows.length != 1) {
      throw const LearningCorruptException();
    }
    final row = rows.single;
    if (row.read<String>('owner_kind') != _scope.ownerKind ||
        row.read<String>('owner_id') != _scope.ownerId ||
        row.read<String>('course_id') != _scope.courseId ||
        row.read<String>('family') != _scope.databaseFamily) {
      throw const LearningCorruptException();
    }
    final schemaVersion = row.read<int>('schema_version');
    if (schemaVersion != 1) {
      throw LearningUnsupportedVersionException(schemaVersion);
    }
    final availability = row.read<String>('availability_state');
    if (availability == 'unavailable') {
      throw const LearningUnavailableException();
    }
    if (availability != 'available') {
      throw const LearningCorruptException();
    }
    final revision = row.read<int>('revision');
    final commitOrdinal = row.read<int>('commit_ordinal');
    if (revision < 0 ||
        revision > 9007199254740991 ||
        commitOrdinal < 0 ||
        commitOrdinal > revision) {
      throw const LearningCorruptException();
    }
    return (revision: revision, commitOrdinal: commitOrdinal);
  }

  Future<int?> _findExistingScopeId(LearningDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT id FROM learning_scopes WHERE owner_kind = ? AND owner_id = ? '
          'AND course_id = ? AND family = ?',
          variables: <Variable<Object>>[
            Variable<String>(_scope.ownerKind),
            Variable<String>(_scope.ownerId),
            Variable<String>(_scope.courseId),
            Variable<String>(_scope.databaseFamily),
          ],
        )
        .get();
    if (rows.isEmpty) return null;
    if (rows.length != 1) throw const LearningCorruptException();
    return rows.single.read<int>('id');
  }

  Future<List<String>> _matchingEventIds(
    LearningDatabase db,
    int scopeId,
    Set<String> ids,
  ) async {
    final requested = ids.toList(growable: false);
    final matching = <String>{};
    for (final chunk in _chunks(requested)) {
      final placeholders = List<String>.filled(chunk.length, '?').join(', ');
      final rows = await db
          .customSelect(
            'SELECT event_id FROM supported_sync_outbox WHERE scope_id = ? '
            'AND event_id IN ($placeholders)',
            variables: <Variable<Object>>[
              Variable<int>(scopeId),
              for (final id in chunk) Variable<String>(id),
            ],
          )
          .get();
      matching.addAll(rows.map((row) => row.read<String>('event_id')));
    }
    return matching.toList(growable: false);
  }

  Iterable<List<T>> _chunks<T>(List<T> values) sync* {
    const int chunkSize = 900;
    for (var start = 0; start < values.length; start += chunkSize) {
      final end = start + chunkSize < values.length
          ? start + chunkSize
          : values.length;
      yield values.sublist(start, end);
    }
  }

  SupportedCloudEvent _supportedEvent(SupportedSyncOutboxData row) {
    final userId = _scope.owner.userId;
    if (userId == null ||
        row.userId != userId ||
        row.courseId != _scope.courseId) {
      throw const LearningCorruptException();
    }
    final SupportedCloudPayload payload = switch (row.kind) {
      'answer' => _answerPayload(row),
      'lesson' => _lessonPayload(row),
      'score' => _scorePayload(row),
      _ => throw const LearningCorruptException(),
    };
    try {
      return SupportedCloudEvent(
        id: row.eventId,
        userId: row.userId,
        courseId: row.courseId,
        payload: payload,
      );
    } on ArgumentError catch (error) {
      throw LearningCorruptException(error);
    }
  }

  CloudAnswer _answerPayload(SupportedSyncOutboxData row) {
    if (row.lessonId != null || row.game != null || row.score != null) {
      throw const LearningCorruptException();
    }
    final skill = switch (row.skill) {
      'listening' => LearningSkill.listening,
      'spelling' => LearningSkill.spelling,
      _ => throw const LearningCorruptException(),
    };
    final correct = switch (row.correct) {
      0 => false,
      1 => true,
      _ => throw const LearningCorruptException(),
    };
    return CloudAnswer(
      sound: _requiredOutboxText(row.sound),
      skill: skill,
      correct: correct,
      activity: _requiredOutboxText(row.activity),
    );
  }

  CloudLesson _lessonPayload(SupportedSyncOutboxData row) {
    if (row.sound != null ||
        row.skill != null ||
        row.correct != null ||
        row.activity != null ||
        row.game != null ||
        row.score != null) {
      throw const LearningCorruptException();
    }
    return CloudLesson(lessonId: _requiredOutboxText(row.lessonId));
  }

  CloudScore _scorePayload(SupportedSyncOutboxData row) {
    if (row.sound != null ||
        row.skill != null ||
        row.correct != null ||
        row.activity != null ||
        row.lessonId != null ||
        row.score == null ||
        row.score! < 0 ||
        row.score! > 9007199254740991) {
      throw const LearningCorruptException();
    }
    return CloudScore(game: _requiredOutboxText(row.game), score: row.score!);
  }

  String _requiredOutboxText(String? value) {
    if (value == null || value.trim().isEmpty) {
      throw const LearningCorruptException();
    }
    return value;
  }

  void _requireCourseScope() {
    _checkAuth();
    if (_scope.family != LearningFamily.course) {
      throw const LearningInvalidCommandException();
    }
  }

  void _checkAuth({int? commandGeneration}) {
    final auth = currentAuth();
    if (adapter.scope != _scope ||
        !auth.ready ||
        auth.owner != _scope.owner ||
        auth.generation != authGeneration ||
        backendOwner() != _scope.owner ||
        (commandGeneration != null && commandGeneration != authGeneration)) {
      throw const LearningOwnerChangedException();
    }
  }

  void _notifyCommitted() {
    try {
      onCommitted?.call();
    } on Object {
      // Observers run only after the durable command commit.
    }
  }

  Never _throwReadFailure(Object error, StackTrace stackTrace) {
    _checkAuth();
    if (_isTypedLearningError(error)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    throw LearningUnavailableException(error);
  }

  bool _isTypedLearningError(Object error) =>
      error is LearningUnavailableException ||
      error is LearningSaveException ||
      error is LearningConflictException ||
      error is LearningOwnerChangedException ||
      error is LearningInvalidCommandException ||
      error is LearningCorruptException ||
      error is LearningUnsupportedVersionException ||
      error is LearningContentChangedException;
}

final class _SqlCommandOutcome<R> {
  const _SqlCommandOutcome({required this.result, required this.committed});

  final R result;
  final bool committed;
}
