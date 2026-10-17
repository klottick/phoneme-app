import 'comparison_learning_codec.dart';
import 'comparison_learning_command.dart';
import 'comparison_learning_state.dart';
import 'comparison_learning_transition.dart';
import 'course_attempt.dart';
import 'course_learning_error.dart';
import 'course_learning_persistence.dart';
import 'course_learning_transaction.dart';

export 'comparison_learning_codec.dart' show ComparisonUnavailableException;

abstract interface class ComparisonLearningStore {
  ComparisonProfileScope get scope;
  Future<ComparisonLearningState> load();
  Future<ComparisonLearningState> retryLoad();
  ComparisonLearningCommand prepare({
    required ComparisonLearningState state,
    required String activityId,
    required ComparisonAction action,
  });
  Future<ComparisonCommit> submit(ComparisonLearningCommand command);
}

final class ComparisonCommit {
  const ComparisonCommit(
      {required this.state, required this.slot, required this.duplicate});
  final ComparisonLearningState state;
  final ComparisonSlot slot;
  final bool duplicate;
}

final class ComparisonProfileAdapter
    implements
        LearningProfileAdapter<ComparisonProfileScope, ComparisonLearningState,
            ComparisonLearningCommand, ComparisonCommit> {
  ComparisonProfileAdapter({
    required this.scope,
    required this.codec,
    required this.transitions,
    this.historyLimit = 2000,
  }) {
    if (historyLimit < 1) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
  }

  final ComparisonLearningCodec codec;
  final ComparisonLearningTransitionEngine transitions;
  final int historyLimit;

  @override
  final ComparisonProfileScope scope;
  @override
  LearningOwner get owner => scope.owner;
  @override
  String get courseId => scope.courseId;
  @override
  LearningDocumentFamily get family => _comparisonDocumentFamily;
  @override
  String get storageKey => codec.keyFor(scope);

  @override
  LearningDocumentEnvelope<ComparisonProfileScope, ComparisonLearningState>
      emptyDocument() => _envelope(ComparisonLearningState.empty(scope));

  @override
  LearningDocumentEnvelope<ComparisonProfileScope, ComparisonLearningState>
      decodeDocument(String raw) =>
          _envelope(codec.decode(raw, scope, transitions.catalogue));

  @override
  String encodePayload(
      LearningDocumentEnvelope<ComparisonProfileScope, ComparisonLearningState>
          document) {
    final state = document.payload;
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
  ComparisonProfileScope commandScope(ComparisonLearningCommand command) =>
      command.scope;
  @override
  int commandAuthGeneration(ComparisonLearningCommand command) =>
      command.authGeneration;
  @override
  String commandToken(ComparisonLearningCommand command) => command.token;
  @override
  String commandFingerprint(ComparisonLearningCommand command) =>
      codec.canonicalCommand(command);
  @override
  String commandActivityId(ComparisonLearningCommand command) =>
      command.activityId;
  @override
  LearningCursorPosition commandExpected(ComparisonLearningCommand command) =>
      _learningCursor(command.expected);

  @override
  LearningCursorPosition? currentCursor(
          ComparisonLearningState payload, String activityId) =>
      payload.slot?.activityId == activityId
          ? _learningCursor(payload.slot!.cursor)
          : null;

  @override
  LearningReceiptIdentity? latestReceipt(
      ComparisonLearningState payload, String activityId) {
    final slot = payload.slot;
    if (slot == null || slot.activityId != activityId) return null;
    final receipt = slot.latestReceipt;
    return LearningReceiptIdentity(
        activityId: receipt.activityId,
        token: receipt.token,
        canonicalCommand: receipt.canonicalCommand,
        before: _learningCursor(receipt.before),
        after: _learningCursor(receipt.after),
        commitOrdinal: receipt.commitOrdinal);
  }

  @override
  LearningRetainedReceiptIdentity? retainedReceipt(
      ComparisonLearningState payload,
      String activityId,
      LearningCursorPosition after,
      String token) {
    for (final receipt in payload.receipts) {
      if (receipt.activityId == activityId &&
          receipt.generation == after.generation &&
          receipt.sequence == after.sequence &&
          receipt.token == token) {
        return LearningRetainedReceiptIdentity(
            activityId: receipt.activityId,
            token: receipt.token,
            canonicalCommand: receipt.canonicalCommand,
            generation: receipt.generation,
            sequence: receipt.sequence);
      }
    }
    return null;
  }

  @override
  bool isStart(ComparisonLearningCommand command) =>
      command.action is StartComparisonRun;

  @override
  LearningTransactionTransition<ComparisonProfileScope, ComparisonLearningState,
      ComparisonCommit> evaluate({
    required LearningDocumentEnvelope<ComparisonProfileScope,
            ComparisonLearningState>
        before,
    required ComparisonLearningCommand command,
    required int nextRevision,
    required int nextCommitOrdinal,
    required DateTime committedAt,
  }) {
    if (before.scope != scope || before.family != family) {
      throw const LearningInvalidCommandException();
    }
    final transition = transitions.evaluate(
        state: before.payload, command: command, committedAt: committedAt);
    final state = transition.nextState;
    final attempts = _latest(
        [...before.payload.attempts, ...transition.attempts], _historyLimit);
    final receipts = _latest(state.receipts, _historyLimit);
    final nextState = ComparisonLearningState(
        scope: scope,
        revision: nextRevision,
        commitOrdinal: nextCommitOrdinal,
        slot: transition.slot,
        attempts: attempts,
        receipts: receipts,
        mistakes: transition.nextState.mistakes,
        summaries: transition.nextState.summaries,
        completions: transition.nextState.completions);
    return LearningTransactionTransition(
        nextDocument: _envelope(nextState),
        result: ComparisonCommit(
            state: nextState, slot: transition.slot, duplicate: false));
  }

  int get _historyLimit => historyLimit < 2000 ? historyLimit : 2000;

  @override
  ComparisonCommit duplicateResult({
    required LearningDocumentEnvelope<ComparisonProfileScope,
            ComparisonLearningState>
        current,
    required ComparisonLearningCommand command,
  }) {
    final slot = current.payload.slot;
    if (slot == null || slot.activityId != command.activityId) {
      throw const LearningConflictException();
    }
    return ComparisonCommit(
        state: current.payload, slot: slot, duplicate: true);
  }

  LearningDocumentEnvelope<ComparisonProfileScope, ComparisonLearningState>
      _envelope(ComparisonLearningState state) => LearningDocumentEnvelope(
          scope: scope,
          family: family,
          revision: state.revision,
          commitOrdinal: state.commitOrdinal,
          payload: state);

  static LearningCursorPosition _learningCursor(ComparisonCursor cursor) =>
      LearningCursorPosition(
          generation: cursor.generation,
          sequence: cursor.sequence,
          revision: cursor.revision);
}

List<T> _latest<T>(List<T> values, int limit) =>
    values.length <= limit ? values : values.sublist(values.length - limit);

const _comparisonDocumentFamily = LearningDocumentFamily('comparison');

final class ComparisonLearningRepository implements ComparisonLearningStore {
  ComparisonLearningRepository({
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
        adapter: ComparisonProfileAdapter(
            scope: scope,
            codec: const ComparisonLearningCodec(),
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
  final ComparisonProfileScope scope;
  final int authGeneration;
  final LearningAuthScope Function() currentAuth;
  final LearningOwner Function() backendOwner;
  final LearningPersistence persistence;
  final ComparisonLearningTransitionEngine transitions;
  final DateTime Function() clock;
  final String Function() newToken;
  final void Function()? onCommitted;
  final int historyLimit;
  late final LearningTransactionCoordinator<
      ComparisonProfileScope,
      ComparisonLearningState,
      ComparisonLearningCommand,
      ComparisonCommit> _transactions;

  @override
  Future<ComparisonLearningState> load() async =>
      (await _transactions.load()).payload;

  @override
  Future<ComparisonLearningState> retryLoad() async =>
      (await _transactions.retryLoad()).payload;

  @override
  ComparisonLearningCommand prepare({
    required ComparisonLearningState state,
    required String activityId,
    required ComparisonAction action,
  }) {
    _checkAuth();
    if (state.scope != scope) throw const LearningOwnerChangedException();
    return transitions.prepare(
        state: state,
        activityId: activityId,
        action: action,
        authGeneration: authGeneration,
        token: newToken(),
        submittedAt: clock().toUtc());
  }

  @override
  Future<ComparisonCommit> submit(ComparisonLearningCommand command) =>
      _transactions.submit(command);

  void _checkAuth() {
    final auth = currentAuth();
    if (!auth.ready ||
        auth.owner != scope.owner ||
        auth.generation != authGeneration ||
        backendOwner() != scope.owner) {
      throw const LearningOwnerChangedException();
    }
  }
}
