import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_transaction.dart'
    show
        LearningDocumentEnvelope,
        LearningDocumentFamily,
        LearningProfileAdapter,
        LearningTransactionCoordinator,
        LearningTransactionTransition;
import 'package:linguist/src/core/course/learning_storage_types.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_codec.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';

export 'sentence_hunt_learning_state.dart'
    show SentenceHuntCapacityException, SentenceHuntUnavailableException;

abstract interface class SentenceHuntLearningStore {
  SentenceHuntProfileScope get scope;
  Future<SentenceHuntState> load();
  Future<SentenceHuntState> retryLoad();
  SentenceHuntCommand prepare({
    required SentenceHuntState state,
    required String sectionId,
    required SentenceHuntAction action,
  });
  Future<SentenceHuntCommit> submit(SentenceHuntCommand command);
}

final class SentenceHuntCommit {
  const SentenceHuntCommit({
    required this.state,
    required this.slot,
    required this.duplicate,
  });

  final SentenceHuntState state;
  final SentenceHuntSlot slot;
  final bool duplicate;
}

final class SentenceHuntProfileAdapter
    implements
        LearningProfileAdapter<SentenceHuntProfileScope, SentenceHuntState,
            SentenceHuntCommand, SentenceHuntCommit> {
  SentenceHuntProfileAdapter({
    required this.scope,
    required this.transitions,
    this.historyLimit = 2000,
  }) {
    if (historyLimit < 1) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
  }

  final SentenceHuntTransitionEngine transitions;
  final int historyLimit;

  @override
  final SentenceHuntProfileScope scope;

  int get _historyLimit {
    var limit = historyLimit;
    if (limit > sentenceHuntMaxAttempts) limit = sentenceHuntMaxAttempts;
    if (limit > transitions.limits.maxAttempts) {
      limit = transitions.limits.maxAttempts;
    }
    if (limit > transitions.limits.maxReceipts) {
      limit = transitions.limits.maxReceipts;
    }
    return limit;
  }

  late final SentenceHuntLearningCodec codec = SentenceHuntLearningCodec(
    limits: SentenceHuntLearningLimits(
      maxAttempts: _historyLimit,
      maxReceipts: _historyLimit,
      maxAggregateEntries: transitions.limits.maxAggregateEntries,
      maxDocumentBytes: transitions.limits.maxDocumentBytes,
    ),
  );

  @override
  LearningOwner get owner => scope.owner;

  @override
  String get courseId => scope.courseId;

  @override
  LearningDocumentFamily get family => _sentenceHuntDocumentFamily;

  @override
  String get storageKey => codec.keyFor(scope);

  @override
  LearningDocumentEnvelope<SentenceHuntProfileScope, SentenceHuntState>
      emptyDocument() => _envelope(SentenceHuntState.empty(scope));

  @override
  LearningDocumentEnvelope<SentenceHuntProfileScope, SentenceHuntState>
      decodeDocument(String raw) =>
          _envelope(codec.decode(raw, scope, transitions.catalogue));

  @override
  String encodePayload(
      LearningDocumentEnvelope<SentenceHuntProfileScope, SentenceHuntState>
          document) {
    final SentenceHuntState state = document.payload;
    if (document.scope != scope ||
        document.family != family ||
        state.scope != scope ||
        document.revision != state.revision ||
        document.commitOrdinal != state.commitOrdinal) {
      throw const LearningInvalidCommandException();
    }
    return codec.encode(state);
  }

  @override
  SentenceHuntProfileScope commandScope(SentenceHuntCommand command) =>
      command.scope;

  @override
  int commandAuthGeneration(SentenceHuntCommand command) =>
      command.authGeneration;

  @override
  String commandToken(SentenceHuntCommand command) => command.token;

  @override
  String commandFingerprint(SentenceHuntCommand command) =>
      codec.canonicalCommand(command);

  @override
  String commandActivityId(SentenceHuntCommand command) => command.sectionId;

  @override
  LearningCursorPosition commandExpected(SentenceHuntCommand command) =>
      command.expected;

  @override
  LearningCursorPosition? currentCursor(
          SentenceHuntState payload, String activityId) =>
      payload.slots[activityId]?.cursor;

  @override
  LearningReceiptIdentity? latestReceipt(
      SentenceHuntState payload, String activityId) {
    final SentenceHuntReceipt? receipt =
        payload.slots[activityId]?.latestReceipt;
    if (receipt == null) return null;
    return LearningReceiptIdentity(
      activityId: receipt.sectionId,
      token: receipt.token,
      canonicalCommand: receipt.canonicalCommand,
      before: receipt.before,
      after: receipt.after,
      commitOrdinal: receipt.commitOrdinal,
    );
  }

  @override
  LearningRetainedReceiptIdentity? retainedReceipt(
    SentenceHuntState payload,
    String activityId,
    LearningCursorPosition after,
    String token,
  ) {
    for (final SentenceHuntReceipt receipt in payload.receipts) {
      if (receipt.sectionId == activityId &&
          receipt.generation == after.generation &&
          receipt.sequence == after.sequence &&
          receipt.token == token) {
        return LearningRetainedReceiptIdentity(
          activityId: receipt.sectionId,
          token: receipt.token,
          canonicalCommand: receipt.canonicalCommand,
          generation: receipt.generation,
          sequence: receipt.sequence,
        );
      }
    }
    return null;
  }

  @override
  bool isStart(SentenceHuntCommand command) =>
      command.action is StartSentenceHuntRun;

  @override
  LearningTransactionTransition<SentenceHuntProfileScope, SentenceHuntState,
      SentenceHuntCommit> evaluate({
    required LearningDocumentEnvelope<SentenceHuntProfileScope,
            SentenceHuntState>
        before,
    required SentenceHuntCommand command,
    required int nextRevision,
    required int nextCommitOrdinal,
    required DateTime committedAt,
  }) {
    if (before.scope != scope || before.family != family) {
      throw const LearningInvalidCommandException();
    }
    final SentenceHuntTransition transition = transitions.evaluate(
      state: before.payload,
      command: command,
      committedAt: committedAt,
    );
    final SentenceHuntState reduced = transition.nextState;
    final SentenceHuntState nextState = SentenceHuntState(
      scope: scope,
      revision: nextRevision,
      commitOrdinal: nextCommitOrdinal,
      slots: reduced.slots,
      attempts: _latest(
        <SentenceHuntAttempt>[
          ...before.payload.attempts,
          ...transition.attempts,
        ],
        _historyLimit,
      ),
      receipts: _latest(reduced.receipts, _historyLimit),
      mistakes: reduced.mistakes,
      summaries: reduced.summaries,
      completions: reduced.completions,
      teachingExposure: reduced.teachingExposure,
    );
    final SentenceHuntSlot changedSlot = nextState.slots[command.sectionId]!;
    return LearningTransactionTransition(
      nextDocument: _envelope(nextState),
      result: SentenceHuntCommit(
        state: nextState,
        slot: changedSlot,
        duplicate: false,
      ),
    );
  }

  @override
  SentenceHuntCommit duplicateResult({
    required LearningDocumentEnvelope<SentenceHuntProfileScope,
            SentenceHuntState>
        current,
    required SentenceHuntCommand command,
  }) {
    final SentenceHuntSlot? slot = current.payload.slots[command.sectionId];
    if (slot == null) throw const LearningConflictException();
    return SentenceHuntCommit(
      state: current.payload,
      slot: slot,
      duplicate: true,
    );
  }

  LearningDocumentEnvelope<SentenceHuntProfileScope, SentenceHuntState>
      _envelope(SentenceHuntState state) =>
          LearningDocumentEnvelope<SentenceHuntProfileScope, SentenceHuntState>(
            scope: scope,
            family: family,
            revision: state.revision,
            commitOrdinal: state.commitOrdinal,
            payload: state,
          );
}

final class SentenceHuntLearningRepository
    implements SentenceHuntLearningStore {
  SentenceHuntLearningRepository({
    required this.scope,
    required this.authGeneration,
    required this.currentAuth,
    required this.backendOwner,
    required this.persistence,
    required this.transitions,
    required this.clock,
    required this.newToken,
    this.onCommitted,
    this.historyLimit = 2000,
  }) {
    if (historyLimit < 1) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
    _transactions = LearningTransactionCoordinator(
      adapter: SentenceHuntProfileAdapter(
        scope: scope,
        transitions: transitions,
        historyLimit: historyLimit,
      ),
      persistence: persistence,
      authGeneration: authGeneration,
      currentAuth: currentAuth,
      backendOwner: backendOwner,
      clock: clock,
      onCommitted: onCommitted,
    );
  }

  @override
  final SentenceHuntProfileScope scope;
  final int authGeneration;
  final LearningAuthScope Function() currentAuth;
  final LearningOwner Function() backendOwner;
  final LearningPersistence persistence;
  final SentenceHuntTransitionEngine transitions;
  final DateTime Function() clock;
  final String Function() newToken;
  final void Function()? onCommitted;
  final int historyLimit;
  late final LearningTransactionCoordinator<SentenceHuntProfileScope,
      SentenceHuntState, SentenceHuntCommand, SentenceHuntCommit> _transactions;

  @override
  Future<SentenceHuntState> load() async =>
      (await _transactions.load()).payload;

  @override
  Future<SentenceHuntState> retryLoad() async =>
      (await _transactions.retryLoad()).payload;

  @override
  SentenceHuntCommand prepare({
    required SentenceHuntState state,
    required String sectionId,
    required SentenceHuntAction action,
  }) {
    _checkAuth();
    if (state.scope != scope) throw const LearningOwnerChangedException();
    return transitions.prepare(
      state: state,
      sectionId: sectionId,
      action: action,
      authGeneration: authGeneration,
      token: newToken(),
      submittedAt: clock().toUtc(),
    );
  }

  @override
  Future<SentenceHuntCommit> submit(SentenceHuntCommand command) =>
      _transactions.submit(command);

  void _checkAuth() {
    final LearningAuthScope auth = currentAuth();
    if (!auth.ready ||
        auth.owner != scope.owner ||
        auth.generation != authGeneration ||
        backendOwner() != scope.owner) {
      throw const LearningOwnerChangedException();
    }
  }
}

const LearningDocumentFamily _sentenceHuntDocumentFamily =
    LearningDocumentFamily('sentence-hunt');

List<T> _latest<T>(List<T> values, int limit) =>
    values.length <= limit ? values : values.sublist(values.length - limit);
