import 'course_learning_error.dart';
import 'course_attempt.dart';
import 'course_learning_persistence.dart';

/// Process-wide serialization and recovery metadata shared by all document
/// families. Payloads are deliberately never stored here.
final class LearningTransactionKernel {
  LearningTransactionKernel._();

  static final LearningTransactionKernel instance =
      LearningTransactionKernel._();

  Future<void> _tail = Future<void>.value();
  final Set<String> _blocked = <String>{};
  final Map<String, String?> _known = <String, String?>{};

  Future<T> run<T>(String storageKey, Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  bool isBlocked(String storageKey) => _blocked.contains(storageKey);
  bool hasKnownBytes(String storageKey) => _known.containsKey(storageKey);
  String? knownBytes(String storageKey) => _known[storageKey];
  void block(String storageKey, String? committedBytes) {
    _blocked.add(storageKey);
    _known[storageKey] = committedBytes;
  }

  void unblock(String storageKey) {
    _blocked.remove(storageKey);
    _known.remove(storageKey);
  }
}

final class LearningDocumentFamily {
  const LearningDocumentFamily(this.name);
  final String name;

  @override
  bool operator ==(Object other) =>
      other is LearningDocumentFamily && other.name == name;
  @override
  int get hashCode => name.hashCode;
}

final class LearningCursorPosition {
  const LearningCursorPosition(
      {required this.generation,
      required this.sequence,
      required this.revision});
  final int generation;
  final int sequence;
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is LearningCursorPosition &&
      other.generation == generation &&
      other.sequence == sequence &&
      other.revision == revision;
  @override
  int get hashCode => Object.hash(generation, sequence, revision);
}

final class LearningReceiptIdentity {
  const LearningReceiptIdentity(
      {required this.activityId,
      required this.token,
      required this.canonicalCommand,
      required this.before,
      required this.after,
      required this.commitOrdinal});
  final String activityId;
  final String token;
  final String canonicalCommand;
  final LearningCursorPosition before;
  final LearningCursorPosition after;
  final int commitOrdinal;
}

/// Historical v2 attempts do not persist receipt header fields.
final class LearningRetainedReceiptIdentity {
  const LearningRetainedReceiptIdentity(
      {required this.activityId,
      required this.token,
      required this.canonicalCommand,
      required this.generation,
      required this.sequence});
  final String activityId;
  final String token;
  final String canonicalCommand;
  final int generation;
  final int sequence;
}

final class LearningDocumentEnvelope<P, S> {
  const LearningDocumentEnvelope(
      {required this.scope,
      required this.family,
      required this.revision,
      required this.commitOrdinal,
      required this.payload});
  final P scope;
  final LearningDocumentFamily family;
  final int revision;
  final int commitOrdinal;
  final S payload;
}

final class LearningTransactionTransition<P, S, R> {
  const LearningTransactionTransition(
      {required this.nextDocument, required this.result});
  final LearningDocumentEnvelope<P, S> nextDocument;
  final R result;
}

abstract interface class LearningProfileAdapter<P, S, C, R> {
  P get scope;
  LearningOwner get owner;
  String get courseId;
  LearningDocumentFamily get family;
  String get storageKey;
  LearningDocumentEnvelope<P, S> emptyDocument();
  LearningDocumentEnvelope<P, S> decodeDocument(String raw);
  String encodePayload(LearningDocumentEnvelope<P, S> document);
  P commandScope(C command);
  int commandAuthGeneration(C command);
  String commandToken(C command);
  String commandFingerprint(C command);
  String commandActivityId(C command);
  LearningCursorPosition commandExpected(C command);
  LearningCursorPosition? currentCursor(S payload, String activityId);
  LearningReceiptIdentity? latestReceipt(S payload, String activityId);
  LearningRetainedReceiptIdentity? retainedReceipt(
      S payload, String activityId, LearningCursorPosition after, String token);
  bool isStart(C command);
  LearningTransactionTransition<P, S, R> evaluate(
      {required LearningDocumentEnvelope<P, S> before,
      required C command,
      required int nextRevision,
      required int nextCommitOrdinal,
      required DateTime committedAt});
  R duplicateResult(
      {required LearningDocumentEnvelope<P, S> current, required C command});
}

/// Shared read/commit/recovery plumbing. Profile-specific duplicate and
/// transition policy is supplied by the strongly typed adapter.
final class LearningTransactionCoordinator<P, S, C, R> {
  LearningTransactionCoordinator(
      {required this.adapter,
      required this.persistence,
      required this.authGeneration,
      required this.currentAuth,
      required this.backendOwner,
      required this.clock,
      this.onCommitted});

  final LearningProfileAdapter<P, S, C, R> adapter;
  final LearningPersistence persistence;
  final int authGeneration;
  final LearningAuthScope Function() currentAuth;
  final LearningOwner Function() backendOwner;
  final DateTime Function() clock;
  final void Function()? onCommitted;
  String? _committedRaw;
  S? _committedPayload;

  Future<LearningDocumentEnvelope<P, S>> load() =>
      LearningTransactionKernel.instance.run(adapter.storageKey, () async {
        _ensureAvailable();
        return _loadCommitted();
      });

  Future<LearningDocumentEnvelope<P, S>> retryLoad() =>
      LearningTransactionKernel.instance.run(adapter.storageKey, () async {
        final kernel = LearningTransactionKernel.instance;
        if (!kernel.isBlocked(adapter.storageKey)) return _loadCommitted();
        final known = kernel.knownBytes(adapter.storageKey);
        await persistence.restore(adapter.storageKey, known);
        await persistence.reload();
        final reread = await persistence.read(adapter.storageKey);
        if (reread != known) throw const LearningUnavailableException();
        _committedRaw = reread;
        final document = _decode(reread);
        kernel.unblock(adapter.storageKey);
        _committedPayload = document.payload;
        return document;
      });

  Future<R> submit(C command) =>
      LearningTransactionKernel.instance.run(adapter.storageKey, () async {
        _ensureAvailable();
        final before = await _loadCommitted();
        _checkAuth();
        if (adapter.commandScope(command) != adapter.scope ||
            adapter.commandAuthGeneration(command) != authGeneration) {
          throw const LearningOwnerChangedException();
        }
        final fingerprint = adapter.commandFingerprint(command);
        final activityId = adapter.commandActivityId(command);
        final expected = adapter.commandExpected(command);
        final latest = adapter.latestReceipt(before.payload, activityId);
        if (latest != null && latest.token == adapter.commandToken(command)) {
          if (latest.canonicalCommand != fingerprint) {
            throw const LearningInvalidCommandException();
          }
          return adapter.duplicateResult(current: before, command: command);
        }
        final retained = adapter.retainedReceipt(
            before.payload,
            activityId,
            LearningCursorPosition(
                generation: expected.generation,
                sequence: expected.sequence + 1,
                revision: expected.revision),
            adapter.commandToken(command));
        if (retained != null) {
          if (retained.canonicalCommand != fingerprint) {
            throw const LearningInvalidCommandException();
          }
          final currentCursor =
              adapter.currentCursor(before.payload, activityId);
          if (currentCursor != null &&
              currentCursor.generation == expected.generation) {
            return adapter.duplicateResult(current: before, command: command);
          }
          throw const LearningConflictException();
        }
        final currentCursor = adapter.currentCursor(before.payload, activityId);
        if (currentCursor != null) {
          if (expected != currentCursor) {
            throw const LearningConflictException();
          }
        } else if (expected.generation != 0 ||
            expected.sequence != 0 ||
            expected.revision != 0) {
          throw const LearningConflictException();
        } else if (!adapter.isStart(command)) {
          throw const LearningInvalidCommandException();
        }
        if (before.revision >= 9007199254740991 ||
            before.commitOrdinal >= 9007199254740991) {
          throw const LearningInvalidCommandException();
        }
        final result = adapter.evaluate(
            before: before,
            command: command,
            nextRevision: before.revision + 1,
            nextCommitOrdinal: before.commitOrdinal + 1,
            committedAt: clock().toUtc());
        final next = result.nextDocument;
        _validateEnvelope(next,
            expectedRevision: before.revision + 1,
            expectedCommitOrdinal: before.commitOrdinal + 1);
        await _write(next, notify: true);
        return result.result;
      });

  int knownCommittedCount(int Function(S payload) count,
      {required S fallback}) {
    final kernel = LearningTransactionKernel.instance;
    if (kernel.isBlocked(adapter.storageKey)) {
      if (!kernel.hasKnownBytes(adapter.storageKey)) {
        return count(adapter.emptyDocument().payload);
      }
      final raw = kernel.knownBytes(adapter.storageKey);
      return count(
          raw == null ? adapter.emptyDocument().payload : _decode(raw).payload);
    }
    return count(_committedPayload ?? fallback);
  }

  Future<void> acknowledge(
          Set<String> receiptIds,
          LearningDocumentEnvelope<P, S> Function(
                  {required LearningDocumentEnvelope<P, S> current,
                  required Set<String> receiptIds,
                  required int nextRevision,
                  required int currentCommitOrdinal})
              removeAcknowledged) =>
      LearningTransactionKernel.instance.run(adapter.storageKey, () async {
        _ensureAvailable();
        final current = await _loadCommitted();
        _checkAuth();
        final next = removeAcknowledged(
            current: current,
            receiptIds: receiptIds,
            nextRevision: current.revision + 1,
            currentCommitOrdinal: current.commitOrdinal);
        if (identical(next, current)) return;
        if (current.revision >= 9007199254740991) {
          throw const LearningInvalidCommandException();
        }
        _validateEnvelope(next,
            expectedRevision: current.revision + 1,
            expectedCommitOrdinal: current.commitOrdinal);
        await _write(next);
      });

  Future<LearningDocumentEnvelope<P, S>> _loadCommitted() async {
    await persistence.reload();
    final raw = await persistence.read(adapter.storageKey);
    final document = _decode(raw);
    _committedRaw = raw;
    _committedPayload = document.payload;
    return document;
  }

  Future<void> _write(LearningDocumentEnvelope<P, S> next,
      {bool notify = false}) async {
    final encoded = adapter.encodePayload(next);
    final verified = adapter.decodeDocument(encoded);
    _validateEnvelope(verified,
        expectedRevision: next.revision,
        expectedCommitOrdinal: next.commitOrdinal);
    _checkAuth();
    try {
      await persistence.write(adapter.storageKey, encoded);
    } catch (error) {
      try {
        await persistence.restore(adapter.storageKey, _committedRaw);
        await persistence.reload();
        if (await persistence.read(adapter.storageKey) != _committedRaw) {
          throw StateError('rollback mismatch');
        }
      } catch (_) {
        LearningTransactionKernel.instance
            .block(adapter.storageKey, _committedRaw);
      }
      throw LearningSaveException(error);
    }
    _committedRaw = encoded;
    _committedPayload = next.payload;
    if (notify) {
      try {
        onCommitted?.call();
      } catch (_) {
        // Durable acknowledgment must not be undone by observer failures.
      }
    }
  }

  LearningDocumentEnvelope<P, S> _decode(String? raw) {
    final document =
        raw == null ? adapter.emptyDocument() : adapter.decodeDocument(raw);
    _validateEnvelope(document,
        expectedRevision: raw == null ? 0 : document.revision,
        expectedCommitOrdinal: raw == null ? 0 : document.commitOrdinal);
    return document;
  }

  void _validateEnvelope(LearningDocumentEnvelope<P, S> document,
      {required int expectedRevision, required int expectedCommitOrdinal}) {
    if (document.scope != adapter.scope ||
        document.family != adapter.family ||
        document.revision != expectedRevision ||
        document.commitOrdinal != expectedCommitOrdinal ||
        document.revision < 0 ||
        document.revision > 9007199254740991 ||
        document.commitOrdinal < 0 ||
        document.commitOrdinal > document.revision) {
      throw const LearningInvalidCommandException();
    }
  }

  void _ensureAvailable() {
    if (LearningTransactionKernel.instance.isBlocked(adapter.storageKey)) {
      throw const LearningUnavailableException();
    }
  }

  void _checkAuth() {
    final auth = currentAuth();
    if (!auth.ready ||
        auth.owner != adapter.owner ||
        auth.generation != authGeneration ||
        backendOwner() != adapter.owner) {
      throw const LearningOwnerChangedException();
    }
  }
}
