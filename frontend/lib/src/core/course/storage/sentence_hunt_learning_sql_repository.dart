import '../course_attempt.dart';
import '../course_learning_error.dart';
import '../sentence_hunt_learning_command.dart';
import '../sentence_hunt_learning_state.dart';
import '../sentence_hunt_learning_store.dart';
import '../sentence_hunt_learning_transition.dart';
import 'learning_database.dart' show LearningDatabaseHandle;
import 'learning_sql_transaction.dart';
import 'sentence_hunt_learning_sql_adapter.dart';
import 'sentence_hunt_learning_storage_validator.dart';

/// Opt-in sentence-hunt repository over normalized SQLite rows.
///
/// Production providers remain on the preferences-backed repository.
final class SqliteSentenceHuntLearningRepository
    implements SentenceHuntLearningStore {
  SqliteSentenceHuntLearningRepository({
    required this.database,
    required this.scope,
    required this.authGeneration,
    required this.currentAuth,
    required this.backendOwner,
    required this.transitions,
    required this.clock,
    required this.newToken,
    this.onCommitted,
    this.historyLimit = 2000,
  }) {
    if (historyLimit < 1 || historyLimit > sentenceHuntMaxAttempts) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
    _adapter = SentenceHuntLearningSqlAdapter(
      scope: scope,
      transitions: transitions,
      historyLimit: historyLimit,
    );
    _coordinator =
        SqliteLearningCommandCoordinator<
          SentenceHuntLearningState,
          SentenceHuntLearningCommand,
          SentenceHuntCommit
        >(
          database: database,
          adapter: _adapter,
          authGeneration: authGeneration,
          currentAuth: currentAuth,
          backendOwner: backendOwner,
          clock: clock,
          onCommitted: onCommitted,
        );
  }

  final LearningDatabaseHandle database;
  @override
  final SentenceHuntProfileScope scope;
  final int authGeneration;
  final LearningAuthScope Function() currentAuth;
  final LearningOwner Function() backendOwner;
  final SentenceHuntTransitionEngine transitions;
  final DateTime Function() clock;
  final String Function() newToken;
  final void Function()? onCommitted;
  final int historyLimit;

  late final SentenceHuntLearningSqlAdapter _adapter;
  late final SqliteLearningCommandCoordinator<
    SentenceHuntLearningState,
    SentenceHuntLearningCommand,
    SentenceHuntCommit
  >
  _coordinator;

  @override
  Future<SentenceHuntLearningState> load() => _coordinator.load();

  @override
  Future<SentenceHuntLearningState> retryLoad() => _coordinator.retryLoad();

  @override
  SentenceHuntLearningCommand prepare({
    required SentenceHuntLearningState state,
    required String sectionId,
    required SentenceHuntAction action,
  }) {
    _checkAuth();
    if (state.scope != scope) throw const LearningOwnerChangedException();
    try {
      SentenceHuntLearningStateValidator.validate(state, transitions.catalogue);
    } on FormatException catch (error) {
      throw LearningInvalidCommandException(error);
    }
    try {
      return transitions.prepare(
        state: state,
        sectionId: sectionId,
        action: action,
        authGeneration: authGeneration,
        token: newToken(),
        submittedAt: clock().toUtc(),
      );
    } on LearningInvalidCommandException {
      rethrow;
    } on Object catch (error) {
      throw LearningInvalidCommandException(error);
    }
  }

  @override
  Future<SentenceHuntCommit> submit(SentenceHuntLearningCommand command) =>
      _coordinator.submit(command);

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
