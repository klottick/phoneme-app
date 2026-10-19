import 'dart:math';

import '../course_attempt.dart';
import '../course_learning_command.dart';
import '../course_learning_error.dart';
import '../course_learning_state.dart';
import 'course_learning_state_validator.dart';
import '../course_learning_store.dart';
import '../course_learning_sync.dart';
import 'course_learning_sql_adapter.dart';
import '../course_learning_transition.dart';
import 'learning_database.dart' show LearningDatabaseHandle;
import 'learning_sql_transaction.dart';

/// Course repository over normalized SQLite records.
///
/// This implementation is intentionally not wired into production providers;
/// callers opt into it directly while the preferences repository remains the
/// active store.
final class SqliteCourseLearningRepository implements CourseLearningStore {
  SqliteCourseLearningRepository({
    required this.database,
    required this.scope,
    required this.authGeneration,
    required this.currentAuth,
    required this.backendOwner,
    required this.transitions,
    required this.clock,
    required this.newToken,
    required this.random,
    this.cloud,
    this.onCommitted,
    this.historyLimit = 2000,
  }) {
    if (historyLimit < 1 || historyLimit > 2000) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
    _adapter = CourseLearningSqlAdapter(
      scope: scope,
      transitions: transitions,
      historyLimit: historyLimit,
    );
    _coordinator =
        SqliteLearningCommandCoordinator<
          CourseLearningState,
          LearningCommand,
          LearningCommit
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
  final LearningScope scope;
  final int authGeneration;
  final LearningAuthScope Function() currentAuth;
  final LearningOwner Function() backendOwner;
  final LearningTransitionEngine transitions;
  final DateTime Function() clock;
  final String Function() newToken;
  final Random random;
  final LearningCloudTransport? cloud;
  final void Function()? onCommitted;
  final int historyLimit;

  late final CourseLearningSqlAdapter _adapter;
  late final SqliteLearningCommandCoordinator<
    CourseLearningState,
    LearningCommand,
    LearningCommit
  >
  _coordinator;

  @override
  Future<CourseLearningState> load() => _coordinator.load();

  @override
  Future<CourseLearningState> retryLoad() => _coordinator.retryLoad();

  @override
  LearningCommand prepare({
    required CourseLearningState state,
    required String activityId,
    required LearningAction action,
  }) {
    _checkAuth();
    if (state.scope != scope) throw const LearningInvalidCommandException();
    CourseLearningStateValidator.validate(state, transitions.registry);
    return transitions.prepare(
      state: state,
      authGeneration: authGeneration,
      activityId: activityId,
      action: action,
      token: newToken(),
      submittedAt: clock().toUtc(),
      random: random,
    );
  }

  @override
  Future<LearningCommit> submit(LearningCommand command) =>
      _coordinator.submit(command);

  @override
  Future<SupportedSyncResult> sync() async {
    final state = await _coordinator.load();
    if (scope.owner.isGuest) {
      return const SupportedSyncResult(
        status: SupportedSyncStatus.guest,
        remainingEvents: 0,
      );
    }
    if (!_isCurrent()) {
      return SupportedSyncResult(
        status: SupportedSyncStatus.ownerChanged,
        remainingEvents: state.pending.length,
      );
    }
    if (state.pending.isEmpty) {
      return const SupportedSyncResult(
        status: SupportedSyncStatus.synced,
        remainingEvents: 0,
      );
    }
    if (cloud == null) {
      return SupportedSyncResult(
        status: SupportedSyncStatus.pending,
        remainingEvents: state.pending.length,
      );
    }
    return SupportedProgressSync(
      scope: scope,
      authGeneration: authGeneration,
      transport: cloud!,
      isCurrent: _isCurrent,
      readPending: () async => (await _coordinator.load()).pending,
      knownPendingCount: () => state.pending.length,
      acknowledge: _coordinator.acknowledgeSupportedCourseEvents,
    ).run();
  }

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
