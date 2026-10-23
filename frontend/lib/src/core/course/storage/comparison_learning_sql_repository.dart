import '../comparison_learning_command.dart';
import '../comparison_learning_state.dart';
import '../comparison_learning_transition.dart';
import '../course_attempt.dart';
import '../course_learning_error.dart';
import '../comparison_learning_store.dart';
import 'comparison_learning_sql_adapter.dart';
import 'comparison_learning_storage_validator.dart';
import 'learning_database.dart' show LearningDatabaseHandle;
import 'learning_sql_transaction.dart';

/// Opt-in comparison repository over normalized SQLite rows.
///
/// Production providers continue to use the preferences-backed repository.
final class SqliteComparisonLearningRepository
    implements ComparisonLearningStore {
  SqliteComparisonLearningRepository({
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
    _adapter = ComparisonLearningSqlAdapter(
      scope: scope,
      transitions: transitions,
      historyLimit: historyLimit,
    );
    _coordinator =
        SqliteLearningCommandCoordinator<
          ComparisonLearningState,
          ComparisonLearningCommand,
          ComparisonCommit
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
  final ComparisonProfileScope scope;
  final int authGeneration;
  final LearningAuthScope Function() currentAuth;
  final LearningOwner Function() backendOwner;
  final ComparisonLearningTransitionEngine transitions;
  final DateTime Function() clock;
  final String Function() newToken;
  final void Function()? onCommitted;
  final int historyLimit;

  late final ComparisonLearningSqlAdapter _adapter;
  late final SqliteLearningCommandCoordinator<
    ComparisonLearningState,
    ComparisonLearningCommand,
    ComparisonCommit
  >
  _coordinator;

  @override
  Future<ComparisonLearningState> load() => _coordinator.load();

  @override
  Future<ComparisonLearningState> retryLoad() => _coordinator.retryLoad();

  @override
  ComparisonLearningCommand prepare({
    required ComparisonLearningState state,
    required String activityId,
    required ComparisonAction action,
  }) {
    _checkAuth();
    if (state.scope != scope) throw const LearningOwnerChangedException();
    try {
      ComparisonLearningStateValidator.validateRegistered(
        state,
        transitions.registry,
      );
    } on FormatException catch (error) {
      throw LearningInvalidCommandException(error);
    }
    return transitions.prepare(
      state: state,
      activityId: activityId,
      action: action,
      authGeneration: authGeneration,
      token: newToken(),
      submittedAt: clock().toUtc(),
    );
  }

  @override
  Future<ComparisonCommit> submit(ComparisonLearningCommand command) =>
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
