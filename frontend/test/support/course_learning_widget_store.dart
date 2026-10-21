import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_command_codec.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_sync.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabaseHandle;
import 'package:flutter_test/flutter_test.dart' show addTearDown;

import 'sqlite_learning_test_harness.dart' show openFileLearningTestDatabase;

/// File-backed course repository shared by tests that exercise persisted
/// behavior. The in-memory [CourseLearningWidgetStore] below is for UI-only
/// command/acknowledgment presentation tests.
final class CourseLearningSqlTestHarness {
  CourseLearningSqlTestHarness({
    LearningOwner? owner,
    LearningRegistry? registry,
    this.cloud,
    this.historyLimit = 2000,
  }) : owner = owner ?? LearningOwner.guest(),
       scope = LearningScope(
         courseId: 'en-fr',
         owner: owner ?? LearningOwner.guest(),
       ),
       auth = LearningAuthScope(
         owner: owner ?? LearningOwner.guest(),
         generation: 0,
         ready: true,
       ) {
    directory = Directory.systemTemp.createTempSync('course-learning-test-');
    database = LearningDatabaseHandle(
      open: () => openFileLearningTestDatabase(
        File('${directory.path}/learning.sqlite'),
      ),
    );
    transitions = LearningTransitionEngine(
      registry ?? LearningRegistry.french(),
    );
    store = createRepository();
    addTearDown(dispose);
  }

  final LearningOwner owner;
  final LearningCloudTransport? cloud;
  final int historyLimit;
  final LearningScope scope;
  final LearningAuthScope auth;
  late final Directory directory;
  late final LearningDatabaseHandle database;
  late final LearningTransitionEngine transitions;
  late final SqliteCourseLearningRepository store;
  int _tokenCounter = 0;

  SqliteCourseLearningRepository createRepository() =>
      SqliteCourseLearningRepository(
        database: database,
        scope: scope,
        authGeneration: 0,
        currentAuth: () => auth,
        backendOwner: () => scope.owner,
        transitions: transitions,
        clock: () => DateTime.utc(2026, 10, 15),
        newToken: () => _token(++_tokenCounter),
        random: Random(1),
        cloud: cloud,
        historyLimit: historyLimit,
      );

  Future<LearningCommit> start(String activityId) async => store.submit(
    store.prepare(
      state: await store.load(),
      activityId: activityId,
      action: StartLearningRun(options: RunOptions()),
    ),
  );

  Future<LearningCommit> answerPilot(String sound) async => store.submit(
    store.prepare(
      state: await store.load(),
      activityId: 'lesson:en-fr-u-y',
      action: ChooseSound(
        selectedSound: sound,
        audioSource: AttemptAudioSource.pendingRecording,
      ),
    ),
  );

  Future<void> rejectNextInsertInto(String table) async {
    const tables = <String>{
      'learning_runs',
      'learning_attempts',
      'learning_command_receipts',
      'learning_summaries',
      'learning_completions',
      'supported_sync_outbox',
    };
    if (!tables.contains(table)) throw ArgumentError.value(table, 'table');
    final db = await database.open();
    await db.customStatement('''
      CREATE TRIGGER task10_test_reject_insert
      BEFORE INSERT ON $table
      BEGIN SELECT RAISE(ABORT, 'task10 injected SQL failure'); END
    ''');
  }

  Future<void> clearWriteFailure() async {
    final db = await database.open();
    await db.customStatement(
      'DROP TRIGGER IF EXISTS task10_test_reject_insert',
    );
  }

  Future<void> dispose() async {
    await database.close();
    if (directory.existsSync()) await directory.delete(recursive: true);
  }
}

String _token(int value) => value.toRadixString(16).padLeft(22, '0');

/// File-backed comparison repository factory for widget flows. Callers may
/// wrap the typed store to control UI timing; all successful writes still use
/// the real SQL repository.
final class ComparisonLearningSqlTestHarness {
  ComparisonLearningSqlTestHarness({
    required this.catalogue,
    required this.currentAuth,
    required this.backendOwner,
  }) {
    directory = Directory.systemTemp.createTempSync(
      'comparison-learning-test-',
    );
    database = LearningDatabaseHandle(
      open: () => openFileLearningTestDatabase(
        File('${directory.path}/learning.sqlite'),
      ),
    );
    addTearDown(dispose);
  }

  final ComparisonCatalogue catalogue;
  final LearningAuthScope Function() currentAuth;
  final LearningOwner Function() backendOwner;
  late final Directory directory;
  late final LearningDatabaseHandle database;
  int _tokenCounter = 0;

  SqliteComparisonLearningRepository createRepository({
    required LearningOwner owner,
    required int generation,
    LearningAuthScope Function()? currentAuth,
    LearningOwner Function()? backendOwner,
    void Function()? onCommitted,
  }) {
    final scope = ComparisonProfileScope(courseId: 'en-fr', owner: owner);
    return SqliteComparisonLearningRepository(
      database: database,
      scope: scope,
      authGeneration: generation,
      currentAuth: currentAuth ?? this.currentAuth,
      backendOwner: backendOwner ?? this.backendOwner,
      transitions: ComparisonLearningTransitionEngine(catalogue: catalogue),
      clock: () => DateTime.utc(2026, 10, 17),
      newToken: () => (++_tokenCounter).toString().padLeft(22, '0'),
      onCommitted: onCommitted,
    );
  }

  Future<void> rejectNextReceiptInsert() async {
    final db = await database.open();
    await db.customStatement('''
      CREATE TRIGGER task10_comparison_test_reject_receipt
      BEFORE INSERT ON learning_command_receipts
      BEGIN SELECT RAISE(ABORT, 'task10 injected comparison SQL failure'); END
    ''');
  }

  Future<void> clearWriteFailure() async {
    final db = await database.open();
    await db.customStatement(
      'DROP TRIGGER IF EXISTS task10_comparison_test_reject_receipt',
    );
  }

  Future<void> dispose() async {
    await database.close();
    if (directory.existsSync()) await directory.delete(recursive: true);
  }
}

/// Complete typed widget fake. Transitions use the production engine; tests
/// can inject load/submit failures or hold either operation at a deterministic
/// gate without weakening command identity or acknowledgement semantics.
class CourseLearningWidgetStore implements CourseLearningStore {
  CourseLearningWidgetStore({
    LearningScope? scope,
    LearningRegistry? registry,
    CourseLearningState? initialState,
  }) : scope =
           scope ??
           LearningScope(courseId: 'en-fr', owner: LearningOwner.guest()),
       _transitions = LearningTransitionEngine(
         registry ?? LearningRegistry.french(),
       ),
       _state =
           initialState ??
           CourseLearningState.empty(
             scope ??
                 LearningScope(courseId: 'en-fr', owner: LearningOwner.guest()),
           );

  @override
  final LearningScope scope;
  final LearningTransitionEngine _transitions;
  CourseLearningState _state;
  int _tokenCounter = 0;

  bool failLoad = false;
  bool failSubmit = false;
  Object? loadFailure;
  Object? submitFailure;
  Completer<void>? loadGate;
  Completer<void>? submitGate;
  Future<CourseLearningState> Function(int call)? loadHandler;
  final Map<Type, Completer<void>> actionGates = {};
  final Set<Type> failingActions = {};
  final Map<Type, Object> actionFailures = {};
  int loadCalls = 0;
  int retryLoadCalls = 0;
  int prepareCalls = 0;
  int submitCalls = 0;
  final List<LearningCommand> prepared = [];
  final List<LearningCommand> submitted = [];

  CourseLearningState get committedState => _state;

  LessonSectionSession? get discoverySession {
    final snapshot = _state.activities['lesson:en-fr-u-y']?.snapshot;
    return snapshot is DiscoveryCheckpoint ? snapshot.session : null;
  }

  void seedSession(LessonSectionSession session) {
    final previous = _state.activities['lesson:en-fr-u-y'];
    final sequence = session.attemptCount + 1;
    final token = 'seedtoken'.padLeft(22, '0');
    final cursor = SlotCursor(
      generation: 1,
      sequence: sequence,
      revision: sequence - 1,
    );
    final receipt = CommandReceipt(
      token: token,
      canonicalCommand: 'typed-test-seed',
      before: sequence == 1
          ? SlotCursor(generation: 0, sequence: 0, revision: 0)
          : SlotCursor(
              generation: 1,
              sequence: sequence - 1,
              revision: sequence - 2,
            ),
      after: cursor,
      commitOrdinal: sequence,
    );
    final aliases = LearningRegistry.french()
        .require('lesson:en-fr-u-y')
        .items
        .where((item) => session.latestAnswers.containsKey(item.sessionAlias))
        .toList();
    final exposures = <ItemContextKey, ItemExposure>{
      for (final item in aliases)
        ItemContextKey(itemId: item.id, targetSound: item.targetSounds.single):
            ItemExposure(presentations: 1, assistance: const {}),
    };
    final slot = ActivitySlot(
      activityId: 'lesson:en-fr-u-y',
      kind: LearningActivityKind.discovery,
      contentRevision: session.contentRevision,
      cursor: cursor,
      options: RunOptions(policy: session.policy),
      snapshot: DiscoveryCheckpoint(session: session),
      exposures: {...?previous?.exposures, ...exposures},
      latestReceipt: receipt,
    );
    _state = CourseLearningState(
      scope: scope,
      revision: sequence,
      commitOrdinal: sequence,
      history: _state.history,
      activities: {..._state.activities, slot.activityId: slot},
      mistakes: _state.mistakes,
      summaries: _state.summaries,
      completions: _state.completions,
      bestScores: _state.bestScores,
      pending: _state.pending,
    );
  }

  void seedCommittedState(CourseLearningState state) {
    if (state.scope != scope) throw ArgumentError('Scope mismatch.');
    _state = state;
  }

  @override
  Future<CourseLearningState> load() async {
    loadCalls++;
    final handler = loadHandler;
    if (handler != null) return handler(loadCalls);
    await loadGate?.future;
    if (failLoad) {
      throw loadFailure ?? const LearningUnavailableException();
    }
    return _state;
  }

  @override
  Future<CourseLearningState> retryLoad() async {
    retryLoadCalls++;
    failLoad = false;
    return load();
  }

  @override
  LearningCommand prepare({
    required CourseLearningState state,
    required String activityId,
    required LearningAction action,
  }) {
    prepareCalls++;
    _tokenCounter++;
    final token = _tokenCounter.toRadixString(36).padLeft(22, '0');
    final command = _transitions.prepare(
      state: state,
      authGeneration: 0,
      activityId: activityId,
      action: action,
      token: token,
      submittedAt: DateTime.utc(2026, 10, 15),
      random: Random(1),
    );
    prepared.add(command);
    return command;
  }

  @override
  Future<LearningCommit> submit(LearningCommand command) async {
    submitCalls++;
    submitted.add(command);
    await actionGates[command.action.runtimeType]?.future;
    await submitGate?.future;
    if (failSubmit ||
        failingActions.contains(command.action.runtimeType) ||
        submitFailure != null ||
        actionFailures.containsKey(command.action.runtimeType)) {
      throw actionFailures[command.action.runtimeType] ??
          submitFailure ??
          const LearningSaveException();
    }
    final currentSlot = _state.activities[command.activityId];
    if (currentSlot?.latestReceipt.token == command.token) {
      if (currentSlot!.latestReceipt.canonicalCommand !=
          CourseLearningCommandCodec.legacyCanonicalCommand(command)) {
        throw const LearningInvalidCommandException();
      }
      return LearningCommit(state: _state, slot: currentSlot, duplicate: true);
    }
    if (currentSlot != null &&
        (currentSlot.cursor.generation != command.expected.generation ||
            currentSlot.cursor.sequence != command.expected.sequence ||
            currentSlot.cursor.revision != command.expected.revision)) {
      throw const LearningConflictException();
    }
    final transition = _transitions.evaluate(
      state: _state,
      command: command,
      committedAt: DateTime.utc(2026, 10, 15),
    );
    _state = CourseLearningState(
      scope: _state.scope,
      revision: _state.revision + 1,
      commitOrdinal: _state.commitOrdinal + 1,
      history: transition.attempts.isEmpty
          ? _state.history
          : [
              ..._state.history,
              AttemptBatch(
                activityId: command.activityId,
                generation: transition.slot.cursor.generation,
                sequence: transition.slot.cursor.sequence,
                token: command.token,
                canonicalCommand:
                    transition.slot.latestReceipt.canonicalCommand,
                attempts: transition.attempts,
              ),
            ],
      activities: {..._state.activities, command.activityId: transition.slot},
      mistakes: transition.mistakes,
      summaries: transition.summaries,
      completions: transition.completions,
      bestScores: transition.bestScores,
      pending: _state.pending,
    );
    return LearningCommit(
      state: _state,
      slot: transition.slot,
      duplicate: false,
    );
  }

  @override
  Future<SupportedSyncResult> sync() async => const SupportedSyncResult(
    status: SupportedSyncStatus.guest,
    remainingEvents: 0,
  );
}
