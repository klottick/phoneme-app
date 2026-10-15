import 'dart:async';
import 'dart:math';

import 'course_attempt.dart';
import 'course_learning_command.dart';
import 'course_learning_error.dart';
import 'course_learning_persistence.dart';
import 'course_learning_state.dart';
import 'course_learning_sync.dart';
import 'course_learning_transition.dart';

abstract class CourseLearningStore {
  LearningScope get scope;
  Future<CourseLearningState> load();
  Future<CourseLearningState> retryLoad();
  LearningCommand prepare(
      {required CourseLearningState state,
      required String activityId,
      required LearningAction action});
  Future<LearningCommit> submit(LearningCommand command);
  Future<SupportedSyncResult> sync();
}

class LearningCommit {
  const LearningCommit(
      {required this.state, required this.slot, required this.duplicate});
  final CourseLearningState state;
  final ActivitySlot slot;
  final bool duplicate;
}

class CourseLearningRepository implements CourseLearningStore {
  CourseLearningRepository({
    required this.scope,
    required this.authGeneration,
    required this.currentAuth,
    required this.backendOwner,
    required this.persistence,
    required this.transitions,
    required this.clock,
    required this.newToken,
    required this.random,
    this.cloud,
    this.onCommitted,
    this.historyLimit = 2000,
  }) {
    if (historyLimit < 1) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
  }

  @override
  final LearningScope scope;
  final int authGeneration;
  final LearningAuthScope Function() currentAuth;
  final LearningOwner Function() backendOwner;
  final LearningPersistence persistence;
  final LearningTransitionEngine transitions;
  final LearningCloudTransport? cloud;
  final void Function()? onCommitted;
  final DateTime Function() clock;
  final String Function() newToken;
  final Random random;
  final int historyLimit;
  static final _coordinator = _LearningCoordinator();
  static const _codec = LearningDocumentCodec();
  String? _committedRaw;
  CourseLearningState? _committed;

  @override
  Future<CourseLearningState> load() =>
      _coordinator.run(scope.storageKey, () async {
        _ensureAvailable();
        return _loadCommitted();
      });

  @override
  Future<CourseLearningState> retryLoad() =>
      _coordinator.run(scope.storageKey, () async {
        final known = _coordinator.blocked.contains(scope.storageKey)
            ? _coordinator.known[scope.storageKey]
            : _committedRaw;
        if (_coordinator.blocked.contains(scope.storageKey)) {
          await persistence.restore(scope.storageKey, known);
          await persistence.reload();
          final reread = await persistence.read(scope.storageKey);
          if (reread != known) throw const LearningUnavailableException();
          _coordinator.blocked.remove(scope.storageKey);
          _committedRaw = reread;
          _committed = reread == null
              ? CourseLearningState.empty(scope)
              : _codec.decode(reread, scope);
          return _committed!;
        }
        return _loadCommitted();
      });

  @override
  LearningCommand prepare(
      {required CourseLearningState state,
      required String activityId,
      required LearningAction action}) {
    _checkAuth();
    return transitions.prepare(
        state: state,
        authGeneration: authGeneration,
        activityId: activityId,
        action: action,
        token: newToken(),
        submittedAt: clock().toUtc(),
        random: random);
  }

  @override
  Future<LearningCommit> submit(LearningCommand command) =>
      _coordinator.run(scope.storageKey, () async {
        _ensureAvailable();
        final before = await _loadCommitted();
        _checkAuth();
        if (command.scope != scope ||
            command.authGeneration != authGeneration) {
          throw const LearningOwnerChangedException();
        }
        final fingerprint = _codec.canonicalCommand(command);
        final slot = before.activities[command.activityId];
        final latest = slot?.latestReceipt;
        if (latest != null && latest.token == command.token) {
          if (latest.canonicalCommand != fingerprint) {
            throw const LearningInvalidCommandException();
          }
          return LearningCommit(state: before, slot: slot!, duplicate: true);
        }
        final retained = before.history
            .where((b) =>
                b.activityId == command.activityId &&
                b.generation == command.expected.generation &&
                b.sequence == command.expected.sequence + 1 &&
                b.token == command.token)
            .firstOrNull;
        if (retained != null) {
          if (retained.canonicalCommand != fingerprint) {
            throw const LearningInvalidCommandException();
          }
          final current = before.activities[command.activityId];
          if (current != null &&
              current.cursor.generation == command.expected.generation) {
            return LearningCommit(
                state: before, slot: current, duplicate: true);
          }
          throw const LearningConflictException();
        }
        if (slot != null &&
            (command.expected.generation != slot.cursor.generation ||
                command.expected.sequence != slot.cursor.sequence ||
                command.expected.revision != slot.cursor.revision)) {
          throw const LearningConflictException();
        }
        if (slot == null &&
            (command.expected.generation != 0 ||
                command.expected.sequence != 0 ||
                command.expected.revision != 0)) {
          throw const LearningConflictException();
        }
        final isStart = command.action is StartLearningRun;
        if (slot == null && !isStart) {
          throw const LearningInvalidCommandException();
        }
        if (before.revision >= 9007199254740991 ||
            before.commitOrdinal >= 9007199254740991) {
          throw const LearningInvalidCommandException();
        }
        final transition = transitions.evaluate(
            state: before, command: command, committedAt: clock().toUtc());
        final events = const SupportedProgressProjector()
            .project(before: before, transition: transition, command: command);
        final history = [...before.history];
        if (transition.attempts.isNotEmpty) {
          history.add(AttemptBatch(
              activityId: command.activityId,
              generation: transition.slot.cursor.generation,
              sequence: transition.slot.cursor.sequence,
              token: command.token,
              canonicalCommand: fingerprint,
              attempts: transition.attempts));
          while (history.fold<int>(0, (n, b) => n + b.attempts.length) >
                  historyLimit &&
              history.length > 1) {
            history.removeAt(0);
          }
        }
        final pending = [...before.pending, ...events];
        final next = CourseLearningState(
            scope: scope,
            revision: before.revision + 1,
            commitOrdinal: before.commitOrdinal + 1,
            history: history,
            activities: {
              ...before.activities,
              command.activityId: transition.slot
            },
            mistakes: transition.mistakes,
            summaries: transition.summaries,
            completions: transition.completions,
            bestScores: transition.bestScores,
            pending: pending);
        final encoded = _codec.encode(next);
        _checkAuth();
        try {
          await persistence.write(scope.storageKey, encoded);
        } catch (error) {
          try {
            await persistence.restore(scope.storageKey, _committedRaw);
            await persistence.reload();
            final restored = await persistence.read(scope.storageKey);
            if (restored != _committedRaw) {
              throw StateError('rollback mismatch');
            }
          } catch (_) {
            _coordinator.blocked.add(scope.storageKey);
            _coordinator.known[scope.storageKey] = _committedRaw;
          }
          throw LearningSaveException(error);
        }
        _committed = next;
        _committedRaw = encoded;
        // Persistence has committed. Observer failures cannot turn that durable
        // acknowledgment into an apparent save failure or prompt a duplicate.
        try {
          onCommitted?.call();
        } catch (_) {
          // Commit notifications are best-effort; storage failures above remain
          // visible to the caller through the normal rollback path.
        }
        return LearningCommit(
            state: next, slot: transition.slot, duplicate: false);
      });

  @override
  Future<SupportedSyncResult> sync() async {
    final state = await _coordinator.run(scope.storageKey, () async {
      _ensureAvailable();
      return _loadCommitted();
    });
    if (scope.owner.isGuest) {
      return const SupportedSyncResult(
          status: SupportedSyncStatus.guest, remainingEvents: 0);
    }
    if (!_isCurrent()) {
      return SupportedSyncResult(
          status: SupportedSyncStatus.ownerChanged,
          remainingEvents: state.pending.length);
    }
    if (state.pending.isEmpty) {
      return const SupportedSyncResult(
          status: SupportedSyncStatus.synced, remainingEvents: 0);
    }
    if (cloud == null) {
      return SupportedSyncResult(
          status: SupportedSyncStatus.pending,
          remainingEvents: state.pending.length);
    }
    return SupportedProgressSync(
      scope: scope,
      authGeneration: authGeneration,
      transport: cloud!,
      isCurrent: _isCurrent,
      readPending: () => _coordinator.run(scope.storageKey, () async {
        _ensureAvailable();
        return (await _loadCommitted()).pending;
      }),
      // Unlike readPending, this is deliberately count-only and reads only the
      // latest known committed snapshot, so a quarantined scope remains blocked
      // while sync can still report its retained event count.
      knownPendingCount: () =>
          _committed?.pending.length ?? state.pending.length,
      acknowledge: _acknowledge,
    ).run();
  }

  Future<void> _acknowledge(Set<String> ids) =>
      _coordinator.run(scope.storageKey, () async {
        _ensureAvailable();
        final current = await _loadCommitted();
        _checkAuth();
        final pending = current.pending
            .where((event) => !ids.contains(event.id))
            .toList(growable: false);
        if (pending.length == current.pending.length) return;
        final next = CourseLearningState(
            scope: scope,
            revision: current.revision + 1,
            commitOrdinal: current.commitOrdinal,
            history: current.history,
            activities: current.activities,
            mistakes: current.mistakes,
            summaries: current.summaries,
            completions: current.completions,
            bestScores: current.bestScores,
            pending: pending);
        final encoded = _codec.encode(next);
        _checkAuth();
        try {
          await persistence.write(scope.storageKey, encoded);
        } catch (error) {
          try {
            await persistence.restore(scope.storageKey, _committedRaw);
            await persistence.reload();
            final restored = await persistence.read(scope.storageKey);
            if (restored != _committedRaw) {
              throw StateError('rollback mismatch');
            }
          } catch (_) {
            _coordinator.blocked.add(scope.storageKey);
            _coordinator.known[scope.storageKey] = _committedRaw;
          }
          throw LearningSaveException(error);
        }
        _committed = next;
        _committedRaw = encoded;
      });

  Future<CourseLearningState> _loadCommitted() async {
    // Repository instances may have been preloaded before another instance
    // committed. Refresh the adapter's cache/image inside the process-wide
    // coordinator before using this document as a merge base.
    await persistence.reload();
    final raw = await persistence.read(scope.storageKey);
    final state = raw == null
        ? CourseLearningState.empty(scope)
        : _codec.decode(raw, scope);
    _committedRaw = raw;
    _committed = state;
    return state;
  }

  void _ensureAvailable() {
    if (_coordinator.blocked.contains(scope.storageKey)) {
      throw const LearningUnavailableException();
    }
  }

  bool _isCurrent() {
    final auth = currentAuth();
    return auth.ready &&
        auth.owner == scope.owner &&
        auth.generation == authGeneration &&
        backendOwner() == scope.owner;
  }

  void _checkAuth() {
    if (!_isCurrent()) {
      throw const LearningOwnerChangedException();
    }
  }
}

class _LearningCoordinator {
  Future<void> _tail = Future.value();
  final Set<String> blocked = {};
  final Map<String, String?> known = {};
  Future<T> run<T>(String key, Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
