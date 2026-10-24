import '../course_attempt.dart';
import '../course_learning_error.dart';
import '../spelling_learning_command.dart';
import '../spelling_learning_state.dart';
import '../spelling_learning_store.dart';
import '../spelling_learning_transition.dart';
import '../spelling_learning_validator.dart';
import 'learning_database.dart' show LearningDatabaseHandle;
import 'learning_sql_transaction.dart';
import 'spelling_learning_sql_adapter.dart';

final class SqliteSpellingLearningRepository implements SpellingLearningStore {
  SqliteSpellingLearningRepository({
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
    if (historyLimit < 1 || historyLimit > 2000) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
    _adapter = SpellingLearningSqlAdapter(
      scope: scope,
      authGeneration: authGeneration,
      transitions: transitions,
      historyLimit: historyLimit,
    );
    _coordinator =
        SqliteLearningCommandCoordinator<
          SpellingLearningState,
          SpellingLearningCommand,
          SpellingCommit
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
  final SpellingProfileScope scope;
  final int authGeneration;
  final LearningAuthScope Function() currentAuth;
  final LearningOwner Function() backendOwner;
  final SpellingLearningTransitionEngine transitions;
  final DateTime Function() clock;
  final String Function() newToken;
  final void Function()? onCommitted;
  final int historyLimit;

  late final SpellingLearningSqlAdapter _adapter;
  late final SqliteLearningCommandCoordinator<
    SpellingLearningState,
    SpellingLearningCommand,
    SpellingCommit
  >
  _coordinator;

  @override
  Future<SpellingLearningState> load() => _coordinator.load();

  @override
  Future<SpellingLearningState> retryLoad() => _coordinator.retryLoad();

  @override
  SpellingLearningCommand prepare({
    required SpellingLearningState state,
    required SpellingAction action,
  }) {
    _checkAuth();
    if (state.scope != scope) throw const LearningOwnerChangedException();
    try {
      SpellingLearningStateValidator.validate(state, transitions.catalogue);
    } on FormatException catch (error) {
      throw LearningInvalidCommandException(error);
    }
    try {
      return transitions.prepare(
        state: state,
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
  Future<SpellingCommit> submit(SpellingLearningCommand command) =>
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
