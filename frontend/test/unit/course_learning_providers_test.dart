import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart'
    show GetAllParameters;
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_sync.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_sql_repository.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../support/sqlite_learning_test_harness.dart';

class _AuthNotifier extends AuthController {
  _AuthNotifier() : super(null) {
    emit(const AppAuthState(isLoading: true));
  }
  void emit(AppAuthState value) => state = value;
}

class _MemoryPersistence implements LearningPersistence {
  final Map<String, String> values = {};
  final Map<String, int> readsByKey = {};
  bool holdNextWrite = false;
  bool failNextWrite = false;
  Completer<void>? writeEntered;
  Completer<bool>? writeGate;
  @override
  Future<String?> read(String key) async {
    readsByKey.update(key, (count) => count + 1, ifAbsent: () => 1);
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (holdNextWrite) {
      holdNextWrite = false;
      writeEntered!.complete();
      if (!await writeGate!.future) throw StateError('held write rejected');
    }
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('write rejected');
    }
    values[key] = value;
  }

  @override
  Future<void> restore(String key, String? lastCommitted) async {
    if (lastCommitted == null) {
      values.remove(key);
    } else {
      values[key] = lastCommitted;
    }
  }

  @override
  Future<void> reload() async {}
}

User _user(String id) => User.fromJson({
      'id': id,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    })!;

SupabaseClient _backendClient() => SupabaseClient(
  'https://learning.example.invalid',
  'public-test-key',
        httpClient: MockClient((request) async {
      final email = (jsonDecode(request.body) as Map)['email'] as String;
      final id = email.split('@').first;
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
        '${base64Url.encode(utf8.encode(jsonEncode({'sub': id, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';
      return http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'test-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': id,
              'aud': 'authenticated',
              'app_metadata': <String, dynamic>{},
              'user_metadata': <String, dynamic>{},
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
          200,
          request: request,
      headers: {'content-type': 'application/json'},
    );
  }),
);

Future<void> _signIn(SupabaseClient client, String id) async {
  await client.auth.signInWithPassword(
    email: '$id@example.invalid',
    password: 'test-password',
  );
}

void main() {
  test('all_three_repositories_share_one_app_database_handle', () async {
    const legacyLearningSentinelKey = 'course.learning.v2.sentinel';
    const legacyLearningSentinelValue = '{leave-this-value-alone}';
    final preferencesStore = _RecordingPreferencesStore(<String, Object>{
      'flutter.theme': 'dark',
      'flutter.$legacyLearningSentinelKey': legacyLearningSentinelValue,
    });
    SharedPreferencesStorePlatform.instance = preferencesStore;
    SharedPreferences.resetStatic();

    final tempDir = await Directory.systemTemp.createTemp(
      'learning-sqlite-test-',
    );
    final file = File('${tempDir.path}/phoneme_learning.sqlite');
    final db = await openFileLearningTestDatabase(file);
    var testDatabaseOpenCount = 0;
    final testHandle = LearningDatabaseHandle(
      open: () async {
        testDatabaseOpenCount++;
        return db;
      },
    );
    final auth = _AuthNotifier();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        learningDatabaseHandleProvider.overrideWithValue(testHandle),
        learningCloudTransportProvider.overrideWithValue(null),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await testHandle.close();
      await tempDir.delete(recursive: true);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      courseBackend = null;
    });

    container.read(learningAuthScopeProvider);
    auth.emit(const AppAuthState());
    await Future<void>.delayed(Duration.zero);
    final handle = container.read(learningDatabaseHandleProvider);
    final course = container.read(courseLearningStoreProvider);
    final comparison = container.read(comparisonLearningStoreProvider);
    final sentenceHunt = await container.read(
      sentenceHuntLearningStoreProvider.future,
    );
    await Future.wait(<Future<void>>[
      course.load().then<void>((_) {}),
      comparison.load().then<void>((_) {}),
      sentenceHunt.load().then<void>((_) {}),
    ]);

    expect((course as SqliteCourseLearningRepository).database, same(handle));
    expect(
      (comparison as SqliteComparisonLearningRepository).database,
      same(handle),
    );
    expect(
      (sentenceHunt as SqliteSentenceHuntLearningRepository).database,
      same(handle),
    );
    expect(testDatabaseOpenCount, 1);
    final families = await db
        .customSelect(
          'SELECT family FROM learning_scopes WHERE owner_kind = ? AND '
          'owner_id = ? AND course_id = ? ORDER BY family',
          variables: <Variable<Object>>[
            const Variable<String>('guest'),
            const Variable<String>(''),
            const Variable<String>('en-fr'),
          ],
        )
        .get();
    expect(families.map((row) => row.read<String>('family')).toSet(), <String>{
      'course',
      'comparison',
      'sentence-hunt',
    });
    expect(
      preferencesStore.readCalls,
      0,
      reason: 'the production provider graph must not read preferences',
    );
    expect(
      preferencesStore.writeCalls,
      0,
      reason: 'the production provider graph must not write preferences',
    );

    final unrelatedPreferences = await SharedPreferences.getInstance();
    expect(unrelatedPreferences.getString('theme'), 'dark');
    expect(
      unrelatedPreferences.getString(legacyLearningSentinelKey),
      legacyLearningSentinelValue,
    );
  });

  test(
    'provider rebuild tracks owner epoch, not only equal final id',
    () async {
      final database = await _newFileDatabase();
      final auth = _AuthNotifier();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => auth),
          learningDatabaseHandleProvider.overrideWithValue(database.handle),
          learningCloudTransportProvider.overrideWithValue(null),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
    final tracker = container.read(learningAuthScopeProvider.notifier);
    final initial = tracker.current;
    expect(initial.ready, isFalse);
    auth.emit(AppAuthState(user: _user('A')));
    await Future<void>.delayed(Duration.zero);
    final originalStore = container.read(courseLearningStoreProvider);
    final firstEpoch = tracker.current.generation;
    auth.emit(AppAuthState(user: _user('B')));
    await Future<void>.delayed(Duration.zero);
    auth.emit(AppAuthState(user: _user('A')));
    await Future<void>.delayed(Duration.zero);
    final returnedStore = container.read(courseLearningStoreProvider);
    expect(tracker.current.owner.userId, 'A');
    expect(tracker.current.generation, firstEpoch + 2);
    expect(identical(returnedStore, originalStore), isFalse);
    final returnedEpoch = tracker.current.generation;
    auth.emit(AppAuthState(user: _user('A'), isLoading: true));
    await Future<void>.delayed(Duration.zero);
    auth.emit(AppAuthState(user: _user('A'), error: 'temporary auth error'));
    await Future<void>.delayed(Duration.zero);
    expect(tracker.current.generation, returnedEpoch);
    expect(tracker.current.ready, isFalse);
    },
  );

  test('initial loading cannot save into guest scope', () async {
    final database = await _newFileDatabase();
    final container = ProviderContainer(
      overrides: [
      authControllerProvider.overrideWith((ref) => _AuthNotifier()),
        learningDatabaseHandleProvider.overrideWithValue(database.handle),
      learningCloudTransportProvider.overrideWithValue(null),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    final store = container.read(courseLearningStoreProvider);
    expect(store.scope.owner.isGuest, isTrue);
    await expectLater(
      store.load(),
      throwsA(isA<LearningOwnerChangedException>()),
    );
    expect(
      database.openCalls,
      0,
      reason: 'an unready auth scope cannot access the learning database',
    );
  });

  test(
    'throwing observer cannot fail an already committed repository write',
      () async {
    final owner = LearningOwner.account('callback-owner');
    final scope = LearningScope(courseId: 'en-fr', owner: owner);
    final persistence = _MemoryPersistence();
    final store = CourseLearningRepository(
        scope: scope,
        authGeneration: 0,
        currentAuth: () =>
            LearningAuthScope(owner: owner, generation: 0, ready: true),
        backendOwner: () => owner,
        persistence: persistence,
        transitions: LearningTransitionEngine(LearningRegistry.french()),
        clock: () => DateTime.utc(2026),
        newToken: () => 'AAAAAAAAAAAAAAAAAAAAAA',
        random: Random(1),
        onCommitted: () => throw StateError('observer failed'),
      );
    final state = await store.load();
    final command = store.prepare(
        state: state,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()),
      );

    final committed = await store.submit(command);

    expect(committed.state.activities, contains('lesson:en-fr-u-y'));
    expect((await store.load()).activities, contains('lesson:en-fr-u-y'));
    },
  );

  test(
    'old provider commit after owner rebuild stays on captured scope',
      () async {
    final client = _backendClient();
    courseBackend = client;
    await _signIn(client, 'old-owner');
    addTearDown(() async {
      courseBackend = null;
      await client.dispose();
    });
      final barrier = _ProviderSqlCommitBarrier();
      final database = await _newFileDatabase(barrier: barrier);
    final auth = _AuthNotifier();
      final container = ProviderContainer(
        overrides: [
      authControllerProvider.overrideWith((ref) => auth),
          learningDatabaseHandleProvider.overrideWithValue(database.handle),
      learningCloudTransportProvider.overrideWithValue(null),
        ],
      );
      addTearDown(() async {
        container.dispose();
        barrier.releaseCommit();
        await database.close();
      });
    container.read(learningAuthScopeProvider);
    auth.emit(AppAuthState(user: _user('old-owner')));
    await Future<void>.delayed(Duration.zero);
    final oldStore = container.read(courseLearningStoreProvider);
    final oldState = await oldStore.load();
    final command = oldStore.prepare(
        state: oldState,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()),
      );
    var stateNotifications = 0;
    final stateSubscription = container.listen(
        courseLearningStateProvider,
        (_, __) => stateNotifications++,
        fireImmediately: true,
      );
    addTearDown(stateSubscription.close);
    await container.read(courseLearningStateProvider.future);

      barrier.holdNextCommit();
    final oldCommit = oldStore.submit(command);
      await barrier.commitEntered;
    await _signIn(client, 'new-owner');
    auth.emit(AppAuthState(user: _user('new-owner')));
    await Future<void>.delayed(Duration.zero);
    final newStore = container.read(courseLearningStoreProvider);
    expect(newStore.scope.owner.userId, 'new-owner');
      barrier.releaseCommit();
      await expectLater(
        oldCommit,
        throwsA(isA<LearningOwnerChangedException>()),
        reason:
            'the real commit is durable in its captured scope but not ACKed',
      );
    final newState = await container.read(courseLearningStateProvider.future);
    expect(newState.activities, isEmpty);
      final db = await database.handle.open();
      expect(await _revision(db, 'old-owner'), 1);
      expect(await _revision(db, 'new-owner'), 0);
      expect(
        stateNotifications,
        greaterThan(0),
        reason: 'the replacement owner still receives its own initial load',
      );
    },
  );

  test(
    'live commit refreshes state provider but failed write does not',
      () async {
    final client = _backendClient();
    courseBackend = client;
    await _signIn(client, 'live-owner');
    addTearDown(() async {
      courseBackend = null;
      await client.dispose();
    });
      final database = await _newFileDatabase();
    final auth = _AuthNotifier();
      final container = ProviderContainer(
        overrides: [
      authControllerProvider.overrideWith((ref) => auth),
          learningDatabaseHandleProvider.overrideWithValue(database.handle),
      learningCloudTransportProvider.overrideWithValue(null),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
    container.read(learningAuthScopeProvider);
    auth.emit(AppAuthState(user: _user('live-owner')));
    await Future<void>.delayed(Duration.zero);
    final store = container.read(courseLearningStoreProvider);
    var notifications = 0;
    final subscription = container.listen(
        courseLearningStateProvider,
        (_, __) => notifications++,
        fireImmediately: true,
      );
    addTearDown(subscription.close);
    final initial = await container.read(courseLearningStateProvider.future);
    final initialNotifications = notifications;
    final command = store.prepare(
        state: initial,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()),
      );
      final db = await database.handle.open();
      await db.customStatement('PRAGMA query_only = ON');

    await expectLater(store.submit(command), throwsA(isA<Exception>()));
      await db.customStatement('PRAGMA query_only = OFF');
    expect(notifications, initialNotifications);

    final retry = store.prepare(
        state: await store.load(),
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()),
      );
    await store.submit(retry);
      final refreshed = await container.read(
        courseLearningStateProvider.future,
      );
    expect(refreshed.activities, contains('lesson:en-fr-u-y'));
    expect(notifications, greaterThan(initialNotifications));
    },
  );

  test('same-owner auth readiness updates do not change generation', () {
    final tracker = LearningAuthTracker(
      owner: LearningOwner.account('A'),
      ready: true,
    );
    final generation = tracker.current.generation;
    tracker.observe(owner: LearningOwner.account('A'), ready: false);
    tracker.observe(owner: LearningOwner.account('A'), ready: true);
    expect(tracker.current.generation, generation);
    expect(tracker.current.ready, isTrue);
    tracker.dispose();
  });

  test('supported synced status does not claim detailed history backup', () {
    const result = SupportedSyncResult(
      status: SupportedSyncStatus.synced,
      remainingEvents: 0,
    );
    expect(result.status, SupportedSyncStatus.synced);
    expect(result.remainingEvents, 0);
  });
}

final class _FileDatabaseHarness {
  _FileDatabaseHarness(this.directory, this.file, this.barrier);

  final Directory directory;
  final File file;
  final _ProviderSqlCommitBarrier? barrier;
  int openCalls = 0;

  late final LearningDatabaseHandle handle = LearningDatabaseHandle(
    open: () async {
      openCalls++;
      final barrier = this.barrier;
      if (barrier == null) return openFileLearningTestDatabase(file);
      return LearningDatabase(
        DatabaseConnection(NativeDatabase(file).interceptWith(barrier)),
      );
    },
  );

  Future<void> close() async {
    await handle.close();
    await directory.delete(recursive: true);
  }
}

Future<_FileDatabaseHarness> _newFileDatabase({
  _ProviderSqlCommitBarrier? barrier,
}) async {
  final directory = await Directory.systemTemp.createTemp(
    'learning-provider-test-',
  );
  final file = File('${directory.path}/phoneme_learning.sqlite');
  return _FileDatabaseHarness(directory, file, barrier);
}

Future<int> _revision(LearningDatabase db, String userId) async =>
    (await db
            .customSelect(
              'SELECT revision FROM learning_scopes WHERE owner_kind = ? AND '
              'owner_id = ? AND course_id = ? AND family = ?',
              variables: <Variable<Object>>[
                const Variable<String>('account'),
                Variable<String>(userId),
                const Variable<String>('en-fr'),
                const Variable<String>('course'),
              ],
            )
            .getSingle())
        .read<int>('revision');

final class _ProviderSqlCommitBarrier extends QueryInterceptor {
  bool _holdCommit = false;
  bool _learnerWritePendingCommit = false;
  Completer<void>? _entered;
  Completer<void>? _release;

  Future<void> get commitEntered => _entered!.future;

  void holdNextCommit() {
    _holdCommit = true;
    _entered = Completer<void>();
    _release = Completer<void>();
  }

  void releaseCommit() {
    final release = _release;
    if (release != null && !release.isCompleted) release.complete();
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('UPDATE learning_scopes SET revision = revision')) {
      _learnerWritePendingCommit = true;
    }
    return executor.runCustom(statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('UPDATE learning_scopes SET revision = revision')) {
      _learnerWritePendingCommit = true;
    }
    return executor.runUpdate(statement, args);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await inner.send();
    if (!_holdCommit || !_learnerWritePendingCommit) return;
    _holdCommit = false;
    _learnerWritePendingCommit = false;
    _entered!.complete();
    await _release!.future;
  }
}

final class _RecordingPreferencesStore extends InMemorySharedPreferencesStore {
  _RecordingPreferencesStore(super.data) : super.withData();

  int readCalls = 0;
  int writeCalls = 0;

  @override
  Future<Map<String, Object>> getAll() {
    readCalls++;
    return super.getAll();
  }

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) {
    readCalls++;
    return super.getAllWithParameters(parameters);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    writeCalls++;
    return super.setValue(valueType, key, value);
  }
}
