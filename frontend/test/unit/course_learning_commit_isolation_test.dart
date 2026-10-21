import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart'
    show
        ApplyInterceptor,
        DatabaseConnection,
        QueryExecutor,
        QueryInterceptor,
        TransactionExecutor,
        Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _AbaAuthNotifier extends AuthController {
  _AbaAuthNotifier() : super(null) {
    emit(const AppAuthState(isLoading: true));
  }

  void emit(AppAuthState value) => state = value;
}

final class _AbaSqlBarrier extends QueryInterceptor {
  Completer<void>? _readEntered;
  Completer<void>? _readRelease;
  Completer<void>? _commitEntered;
  Completer<void>? _commitRelease;
  bool _holdHeaderRead = false;
  bool _holdCommit = false;
  bool _learnerWritePendingCommit = false;
  final Map<String, int> _headerReads = <String, int>{};

  Future<void> get readEntered => _readEntered!.future;
  Future<void> get commitEntered => _commitEntered!.future;

  void holdNextHeaderRead() {
    _holdHeaderRead = true;
    _readEntered = Completer<void>();
    _readRelease = Completer<void>();
  }

  void releaseRead() {
    if (!_readRelease!.isCompleted) _readRelease!.complete();
  }

  void holdNextCommit() {
    _holdCommit = true;
    _commitEntered = Completer<void>();
    _commitRelease = Completer<void>();
  }

  void releaseCommit() {
    if (!_commitRelease!.isCompleted) _commitRelease!.complete();
  }

  int headerReadsFor(String ownerKind, String ownerId) =>
      _headerReads['$ownerKind:$ownerId'] ?? 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(statement, args);
    if (statement.contains('SELECT owner_kind, owner_id, course_id, family') &&
        rows.isNotEmpty) {
      final row = rows.single;
      final key = '${row['owner_kind']}:${row['owner_id']}';
      _headerReads.update(key, (count) => count + 1, ifAbsent: () => 1);
      if (_holdHeaderRead) {
        _holdHeaderRead = false;
        _readEntered!.complete();
        await _readRelease!.future;
      }
    }
    return rows;
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
    _commitEntered!.complete();
    await _commitRelease!.future;
  }
}

User _abaUser(String id) => User.fromJson(<String, Object?>{
  'id': id,
  'aud': 'authenticated',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
  'created_at': '2026-01-01T00:00:00Z',
})!;

SupabaseClient _abaBackendClient() => SupabaseClient(
  'https://aba-learning.example.invalid',
  'public-test-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((request) async {
    if (request.url.path.endsWith('/logout')) {
      return http.Response('{}', 200, request: request);
    }
    final email =
        (jsonDecode(request.body) as Map<String, Object?>)['email'] as String;
    final id = email.split('@').first;
    final payload = jsonEncode(<String, Object?>{
      'sub': id,
      'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    });
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
        '${base64Url.encode(utf8.encode(payload))}.signature';
    return http.Response(
      jsonEncode(<String, Object?>{
        'access_token': token,
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': <String, Object?>{
          'id': id,
          'aud': 'authenticated',
          'app_metadata': <String, Object?>{},
          'user_metadata': <String, Object?>{},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
      200,
      request: request,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }),
);

Future<void> _abaSignIn(SupabaseClient client, String id) async {
  await client.auth.signInWithPassword(
    email: '$id@example.invalid',
    password: 'test-password',
  );
}

void main() {
  test('aba_write_stays_in_captured_scope', () async {
    final tempDir = await Directory.systemTemp.createTemp('learning-aba-');
    final file = File('${tempDir.path}/phoneme_learning.sqlite');
    final barrier = _AbaSqlBarrier();
    final handle = LearningDatabaseHandle(
      open: () async => LearningDatabase(
        DatabaseConnection(NativeDatabase(file).interceptWith(barrier)),
      ),
    );
    final client = _abaBackendClient();
    courseBackend = client;
    await _abaSignIn(client, 'aba-a');
    final auth = _AbaAuthNotifier();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        learningDatabaseHandleProvider.overrideWithValue(handle),
        learningCloudTransportProvider.overrideWithValue(null),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await handle.close();
      courseBackend = null;
      await client.dispose();
      await tempDir.delete(recursive: true);
    });

    container.read(learningAuthScopeProvider);
    auth.emit(AppAuthState(user: _abaUser('aba-a')));
    await Future<void>.delayed(Duration.zero);
    final capturedA = container.read(courseLearningStoreProvider);
    expect((await capturedA.load()).revision, 0);

    barrier.holdNextHeaderRead();
    final heldRead = capturedA.load();
    await barrier.readEntered;
    await _abaSignIn(client, 'aba-b');
    auth.emit(AppAuthState(user: _abaUser('aba-b')));
    await Future<void>.delayed(Duration.zero);
    await _abaSignIn(client, 'aba-a');
    auth.emit(AppAuthState(user: _abaUser('aba-a')));
    await Future<void>.delayed(Duration.zero);
    barrier.releaseRead();
    await expectLater(heldRead, throwsA(isA<LearningOwnerChangedException>()));

    var currentA = container.read(courseLearningStoreProvider);
    expect((await currentA.load()).revision, 0);
    await _abaSignIn(client, 'aba-b');
    auth.emit(AppAuthState(user: _abaUser('aba-b')));
    await Future<void>.delayed(Duration.zero);
    expect(
      (await container.read(courseLearningStoreProvider).load()).revision,
      0,
    );
    await _abaSignIn(client, 'aba-a');
    auth.emit(AppAuthState(user: _abaUser('aba-a')));
    await Future<void>.delayed(Duration.zero);
    currentA = container.read(courseLearningStoreProvider);
    final subscription = container.listen(
      courseLearningStateProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final stateA = await container.read(courseLearningStateProvider.future);
    final command = currentA.prepare(
      state: stateA,
      activityId: 'lesson:en-fr-u-y',
      action: StartLearningRun(options: RunOptions()),
    );

    barrier.holdNextCommit();
    final heldWrite = currentA.submit(command);
    await barrier.commitEntered;
    await _abaSignIn(client, 'aba-b');
    auth.emit(AppAuthState(user: _abaUser('aba-b')));
    await Future<void>.delayed(Duration.zero);
    await _abaSignIn(client, 'aba-a');
    auth.emit(AppAuthState(user: _abaUser('aba-a')));
    await Future<void>.delayed(Duration.zero);
    await client.auth.signOut();
    auth.emit(const AppAuthState());
    await Future<void>.delayed(Duration.zero);
    final guestStateFuture = container.read(courseLearningStateProvider.future);
    barrier.releaseCommit();
    await expectLater(
      heldWrite,
      throwsA(isA<LearningOwnerChangedException>()),
      reason:
          'a real SQLite commit survives a later sign-out, but is not ACKed',
    );
    expect((await guestStateFuture).revision, 0);

    final db = await handle.open();
    Future<int> revisionFor(String ownerKind, String ownerId) async =>
        (await db
                .customSelect(
                  'SELECT revision FROM learning_scopes WHERE owner_kind = ? AND '
                  'owner_id = ? AND course_id = ? AND family = ?',
                  variables: <Variable<Object>>[
                    Variable<String>(ownerKind),
                    Variable<String>(ownerId),
                    const Variable<String>('en-fr'),
                    const Variable<String>('course'),
                  ],
                )
                .getSingle())
            .read<int>('revision');
    expect(await revisionFor('account', 'aba-a'), 1);
    expect(await revisionFor('account', 'aba-b'), 0);
    expect(await revisionFor('guest', ''), 0);
    final runRows = await db
        .customSelect(
          'SELECT s.owner_kind, s.owner_id, COUNT(r.activity_id) AS run_count '
          'FROM learning_scopes AS s LEFT JOIN learning_runs AS r '
          'ON r.scope_id = s.id WHERE s.course_id = ? AND s.family = ? '
          'GROUP BY s.owner_kind, s.owner_id ORDER BY s.owner_kind, s.owner_id',
          variables: <Variable<Object>>[
            const Variable<String>('en-fr'),
            const Variable<String>('course'),
          ],
        )
        .get();
    expect(
      runRows.map(
        (row) =>
            '${row.read<String>('owner_kind')}:${row.read<String>('owner_id')}='
            '${row.read<int>('run_count')}',
      ),
      containsAll(<String>['account:aba-a=1', 'account:aba-b=0', 'guest:=0']),
    );

    var stateNotifications = 0;
    final notificationSubscription = container.listen(
      courseLearningStateProvider,
      (_, __) => stateNotifications++,
      fireImmediately: true,
    );
    addTearDown(notificationSubscription.close);
    await container.read(courseLearningStateProvider.future);
    final guestHeaderReads = barrier.headerReadsFor('guest', '');
    final notificationsBeforeStaleCallback = stateNotifications;
    (currentA as SqliteCourseLearningRepository).onCommitted!.call();
    await container.read(courseLearningStateProvider.future);
    expect(
      barrier.headerReadsFor('guest', ''),
      guestHeaderReads,
      reason: 'a retired provider callback cannot reload the replacement',
    );
    expect(
      stateNotifications,
      notificationsBeforeStaleCallback,
      reason: 'a stale callback cannot notify the signed-out provider',
    );
  });
}
