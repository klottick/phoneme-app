import 'dart:math';

import 'course_attempt.dart';
import 'course_learning_command.dart';
import 'course_learning_error.dart';
import 'course_learning_persistence.dart';
import 'course_learning_state.dart';
import 'course_learning_sync.dart';
import 'course_learning_transaction.dart';
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
    _transactions = LearningTransactionCoordinator(
        adapter: _V2LearningProfileAdapter(
            scope: scope,
            codec: _codec,
            transitions: transitions,
            historyLimit: historyLimit),
        persistence: persistence,
        authGeneration: authGeneration,
        currentAuth: currentAuth,
        backendOwner: backendOwner,
        clock: clock,
        onCommitted: onCommitted);
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
  static const _codec = LearningDocumentCodec();
  late final LearningTransactionCoordinator<LearningScope, CourseLearningState,
      LearningCommand, LearningCommit> _transactions;

  @override
  Future<CourseLearningState> load() async =>
      (await _transactions.load()).payload;

  @override
  Future<CourseLearningState> retryLoad() async =>
      (await _transactions.retryLoad()).payload;

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
      _transactions.submit(command);

  @override
  Future<SupportedSyncResult> sync() async {
    final state = (await _transactions.load()).payload;
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
      readPending: () async => (await _transactions.load()).payload.pending,
      knownPendingCount: () => _transactions.knownCommittedCount(
          (payload) => payload.pending.length,
          fallback: state),
      acknowledge: _acknowledge,
    ).run();
  }

  Future<void> _acknowledge(Set<String> ids) => _transactions.acknowledge(ids, (
          {required current,
          required receiptIds,
          required nextRevision,
          required currentCommitOrdinal}) {
        final state = current.payload;
        final pending = state.pending
            .where((event) => !receiptIds.contains(event.id))
            .toList(growable: false);
        if (pending.length == state.pending.length) return current;
        final nextState = CourseLearningState(
            scope: scope,
            revision: nextRevision,
            commitOrdinal: currentCommitOrdinal,
            history: state.history,
            activities: state.activities,
            mistakes: state.mistakes,
            summaries: state.summaries,
            completions: state.completions,
            bestScores: state.bestScores,
            pending: pending);
        return _v2Envelope(nextState);
      });

  bool _isCurrent() {
    final auth = currentAuth();
    return auth.ready &&
        auth.owner == scope.owner &&
        auth.generation == authGeneration &&
        backendOwner() == scope.owner;
  }

  void _checkAuth() {
    if (!_isCurrent()) throw const LearningOwnerChangedException();
  }
}

const _v2DocumentFamily = LearningDocumentFamily('course-learning-v2');

LearningCursorPosition _v2Cursor(SlotCursor cursor) => LearningCursorPosition(
    generation: cursor.generation,
    sequence: cursor.sequence,
    revision: cursor.revision);

LearningDocumentEnvelope<LearningScope, CourseLearningState> _v2Envelope(
        CourseLearningState state) =>
    LearningDocumentEnvelope(
        scope: state.scope,
        family: _v2DocumentFamily,
        revision: state.revision,
        commitOrdinal: state.commitOrdinal,
        payload: state);

final class _V2LearningProfileAdapter
    implements
        LearningProfileAdapter<LearningScope, CourseLearningState,
            LearningCommand, LearningCommit> {
  const _V2LearningProfileAdapter(
      {required this.scope,
      required this.codec,
      required this.transitions,
      required this.historyLimit});

  @override
  final LearningScope scope;
  final LearningDocumentCodec codec;
  final LearningTransitionEngine transitions;
  final int historyLimit;

  @override
  LearningOwner get owner => scope.owner;
  @override
  String get courseId => scope.courseId;
  @override
  LearningDocumentFamily get family => _v2DocumentFamily;
  @override
  String get storageKey => scope.storageKey;

  @override
  LearningDocumentEnvelope<LearningScope, CourseLearningState>
      emptyDocument() => _v2Envelope(CourseLearningState.empty(scope));

  @override
  LearningDocumentEnvelope<LearningScope, CourseLearningState> decodeDocument(
          String raw) =>
      _v2Envelope(codec.decode(raw, scope));

  @override
  String encodePayload(
      LearningDocumentEnvelope<LearningScope, CourseLearningState> document) {
    final state = document.payload;
    if (document.scope != scope ||
        document.family != family ||
        state.scope != scope ||
        state.revision != document.revision ||
        state.commitOrdinal != document.commitOrdinal) {
      throw const LearningInvalidCommandException();
    }
    return codec.encode(state);
  }

  @override
  LearningScope commandScope(LearningCommand command) => command.scope;
  @override
  int commandAuthGeneration(LearningCommand command) => command.authGeneration;
  @override
  String commandToken(LearningCommand command) => command.token;
  @override
  String commandFingerprint(LearningCommand command) =>
      codec.canonicalCommand(command);
  @override
  String commandActivityId(LearningCommand command) => command.activityId;
  @override
  LearningCursorPosition commandExpected(LearningCommand command) =>
      _v2Cursor(command.expected);

  @override
  LearningCursorPosition? currentCursor(
          CourseLearningState payload, String activityId) =>
      payload.activities[activityId] == null
          ? null
          : _v2Cursor(payload.activities[activityId]!.cursor);

  @override
  LearningReceiptIdentity? latestReceipt(
      CourseLearningState payload, String activityId) {
    final receipt = payload.activities[activityId]?.latestReceipt;
    if (receipt == null) return null;
    return LearningReceiptIdentity(
        activityId: activityId,
        token: receipt.token,
        canonicalCommand: receipt.canonicalCommand,
        before: _v2Cursor(receipt.before),
        after: _v2Cursor(receipt.after),
        commitOrdinal: receipt.commitOrdinal);
  }

  @override
  LearningRetainedReceiptIdentity? retainedReceipt(CourseLearningState payload,
      String activityId, LearningCursorPosition after, String token) {
    for (final batch in payload.history) {
      if (batch.activityId == activityId &&
          batch.generation == after.generation &&
          batch.sequence == after.sequence &&
          batch.token == token) {
        return LearningRetainedReceiptIdentity(
            activityId: batch.activityId,
            token: batch.token,
            canonicalCommand: batch.canonicalCommand,
            generation: batch.generation,
            sequence: batch.sequence);
      }
    }
    return null;
  }

  @override
  bool isStart(LearningCommand command) => command.action is StartLearningRun;

  @override
  LearningTransactionTransition<LearningScope, CourseLearningState,
          LearningCommit>
      evaluate(
          {required LearningDocumentEnvelope<LearningScope, CourseLearningState>
              before,
          required LearningCommand command,
          required int nextRevision,
          required int nextCommitOrdinal,
          required DateTime committedAt}) {
    final transition = transitions.evaluate(
        state: before.payload, command: command, committedAt: committedAt);
    final events = const SupportedProgressProjector().project(
        before: before.payload, transition: transition, command: command);
    final history = [...before.payload.history];
    if (transition.attempts.isNotEmpty) {
      history.add(AttemptBatch(
          activityId: command.activityId,
          generation: transition.slot.cursor.generation,
          sequence: transition.slot.cursor.sequence,
          token: command.token,
          canonicalCommand: commandFingerprint(command),
          attempts: transition.attempts));
      while (history.fold<int>(0, (n, batch) => n + batch.attempts.length) >
              historyLimit &&
          history.length > 1) {
        history.removeAt(0);
      }
    }
    final state = before.payload;
    final next = CourseLearningState(
        scope: scope,
        revision: nextRevision,
        commitOrdinal: nextCommitOrdinal,
        history: history,
        activities: {...state.activities, command.activityId: transition.slot},
        mistakes: transition.mistakes,
        summaries: transition.summaries,
        completions: transition.completions,
        bestScores: transition.bestScores,
        pending: [...state.pending, ...events]);
    return LearningTransactionTransition(
        nextDocument: _v2Envelope(next),
        result: LearningCommit(
            state: next, slot: transition.slot, duplicate: false));
  }

  @override
  LearningCommit duplicateResult(
      {required LearningDocumentEnvelope<LearningScope, CourseLearningState>
          current,
      required LearningCommand command}) {
    final slot = current.payload.activities[command.activityId]!;
    return LearningCommit(state: current.payload, slot: slot, duplicate: true);
  }
}
