import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_sql_repository.dart';
import 'package:linguist/src/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../support/sentence_hunt_fixtures.dart';

final _catalogue = syntheticSentenceCatalogue();

final class _ProviderAuth extends AuthController {
  _ProviderAuth() : super(null) {
    emit(const AppAuthState(isLoading: true));
  }

  void emit(AppAuthState value) => state = value;
}

final class _Harness {
  _Harness(this.auth, this.database, this.container);

  final _ProviderAuth auth;
  final _ProviderDatabase database;
  final ProviderContainer container;
  bool _containerDisposed = false;

  void disposeContainer() {
    if (_containerDisposed) return;
    _containerDisposed = true;
    container.dispose();
  }

  Future<void> close() async {
    disposeContainer();
    await database.close();
    courseBackend = null;
  }
}

Future<_Harness> _harness({
  AppAuthState initialAuth = const AppAuthState(),
  SupabaseClient? backend,
  Future<SentenceHuntCatalogue> Function()? catalogue,
}) async {
  courseBackend = backend;
  final auth = _ProviderAuth();
  final database = await _newProviderDatabase();
  final container = ProviderContainer(
    overrides: <Override>[
    authControllerProvider.overrideWith((ref) => auth),
      learningDatabaseHandleProvider.overrideWithValue(database.handle),
    sentenceHuntCatalogueProvider.overrideWith(
      (ref) =>
            catalogue?.call() ??
            Future<SentenceHuntCatalogue>.value(_catalogue),
    ),
    ],
  );
  container.read(learningAuthScopeProvider);
  auth.emit(initialAuth);
  await Future<void>.delayed(Duration.zero);
  return _Harness(auth, database, container);
}

void main() {
  test(
    'store provider stays loading until async sentence catalogue resolves',
      () async {
    final completer = Completer<SentenceHuntCatalogue>();
    final h = await _harness(catalogue: () => completer.future);
      addTearDown(h.close);
      final acquisition = h.container.read(
        sentenceHuntLearningStoreProvider.future,
      );

    expect(
        h.container.read(sentenceHuntLearningStoreProvider).isLoading,
        isTrue,
      );
    completer.complete(_catalogue);
      final SqliteSentenceHuntLearningRepository store =
          await acquisition as SqliteSentenceHuntLearningRepository;

    expect(store.scope.owner.isGuest, isTrue);
      expect(
        h.database.openCalls,
        0,
        reason: 'store construction is lazy with respect to SQLite',
      );
    },
  );

  test(
    'state provider awaits store acquisition and loads only after catalogue',
      () async {
    final completer = Completer<SentenceHuntCatalogue>();
    final h = await _harness(catalogue: () => completer.future);
      addTearDown(h.close);
      final Future<SentenceHuntState> loading = h.container.read(
        sentenceHuntLearningStateProvider.future,
      );
    await Future<void>.delayed(Duration.zero);
    expect(
        h.database.openCalls,
        0,
        reason: 'the state provider must wait for catalogue acquisition',
      );
      expect(
        h.container.read(sentenceHuntLearningStateProvider).isLoading,
        isTrue,
      );

    completer.complete(_catalogue);
    final state = await loading;
    expect(state.revision, 0);
    expect(state.slots, isEmpty);
      expect(h.database.openCalls, 1);
    },
  );

  test(
    'catalogue acquisition errors can be retried by provider invalidation',
      () async {
    var failCatalogue = true;
      final h = await _harness(
        catalogue: () async {
      if (failCatalogue) throw StateError('synthetic catalogue failure');
      return _catalogue;
        },
      );
      addTearDown(h.close);

    await expectLater(
      h.container.read(sentenceHuntLearningStoreProvider.future),
      throwsA(isA<StateError>()),
    );
      expect(h.database.openCalls, 0);
    failCatalogue = false;
    h.container.invalidate(sentenceHuntCatalogueProvider);
    h.container.invalidate(sentenceHuntLearningStoreProvider);

      final store = await h.container.read(
        sentenceHuntLearningStoreProvider.future,
      );
    expect(store.scope.owner.isGuest, isTrue);
      expect(
        h.database.openCalls,
        0,
        reason: 'constructing the retried store must not open SQLite',
      );
    },
  );

  test(
    'readiness loss during async acquisition cannot publish a store',
      () async {
    final completer = Completer<SentenceHuntCatalogue>();
    final h = await _harness(catalogue: () => completer.future);
      addTearDown(h.close);
      final staleAcquisition = h.container.read(
        sentenceHuntLearningStoreProvider.future,
      );
      unawaited(
        staleAcquisition.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
        ),
      );
    h.auth.emit(const AppAuthState(isLoading: true));
    await Future<void>.delayed(Duration.zero);
    completer.complete(_catalogue);

    await expectLater(
      h.container.read(sentenceHuntLearningStoreProvider.future),
      throwsA(isA<LearningOwnerChangedException>()),
    );
      expect(h.database.openCalls, 0);

    h.auth.emit(const AppAuthState());
    await Future<void>.delayed(Duration.zero);
      final current = await h.container.read(
        sentenceHuntLearningStoreProvider.future,
      );
    expect(current.scope.owner.isGuest, isTrue);
      expect(h.database.openCalls, 0);
    },
  );

  test(
    'A-B-A during catalogue await acquires only the current auth generation',
      () async {
    final client = _backendClient();
    await _signIn(client, 'account-a');
    final completer = Completer<SentenceHuntCatalogue>();
    final h = await _harness(
      initialAuth: AppAuthState(user: _userFor('account-a')),
      backend: client,
      catalogue: () => completer.future,
    );
    addTearDown(() async {
        await h.close();
      await client.dispose();
    });
      final staleAcquisition = h.container.read(
        sentenceHuntLearningStoreProvider.future,
      );

    await _signIn(client, 'account-b');
    h.auth.emit(AppAuthState(user: _userFor('account-b')));
    await Future<void>.delayed(Duration.zero);
    await _signIn(client, 'account-a');
    h.auth.emit(AppAuthState(user: _userFor('account-a')));
    await Future<void>.delayed(Duration.zero);
    final identity = h.container.read(learningAuthScopeProvider);
    expect(identity.owner, LearningOwner.account('account-a'));
    expect(identity.generation, 2);
    completer.complete(_catalogue);

      final current = await h.container.read(
        sentenceHuntLearningStoreProvider.future,
      );
    expect(current.scope.owner, LearningOwner.account('account-a'));
      expect(
        (current as SqliteSentenceHuntLearningRepository).authGeneration,
        2,
      );
    final staleFutureValue = await staleAcquisition;
    expect(
        (staleFutureValue as SqliteSentenceHuntLearningRepository)
            .authGeneration,
        2,
        reason: 'a Future observed before A-B-A must never emit the old epoch',
      );
    expect(identical(staleFutureValue, current), isTrue);
      expect(h.database.openCalls, 0);
    },
  );

  test(
      'ACK refreshes the current state provider; failed and duplicate writes do not',
      () async {
    final h = await _harness();
      addTearDown(h.close);
      final db = await h.database.handle.open();
      final store = await h.container.read(
        sentenceHuntLearningStoreProvider.future,
      );
      var notifications = 0;
    final subscription = h.container.listen(
        sentenceHuntLearningStateProvider,
        (_, __) => notifications++,
        fireImmediately: true,
      );
    addTearDown(subscription.close);
    await h.container.read(sentenceHuntLearningStateProvider.future);
    final state = await store.load();
    final command = store.prepare(
      state: state,
      sectionId: fixtureSectionIds.first,
      action: StartSentenceHuntRun(
        sessionId: 'provider-ack',
        policy: _catalogue.section(fixtureSectionIds.first).policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );

      final beforeFailureNotifications = notifications;
      h.database.barrier.failNextLearningWrite();
      await expectLater(
        store.submit(command),
        throwsA(isA<LearningSaveException>()),
      );
      expect(
        notifications,
        beforeFailureNotifications,
        reason: 'failed writes do not invalidate state',
      );
      expect(await _scopeRevision(db, owner: store.scope.owner), 0);

    final saved = await store.submit(command);
    expect(saved.duplicate, isFalse);
      final refreshed = await h.container.read(
        sentenceHuntLearningStateProvider.future,
      );
    expect(refreshed.revision, 1);
      expect(notifications, greaterThan(beforeFailureNotifications));
      final afterCommitNotifications = notifications;
    expect((await store.submit(command)).duplicate, isTrue);
    await Future<void>.delayed(Duration.zero);
      expect(
        notifications,
        afterCommitNotifications,
        reason: 'idempotent replay does not produce an ACK notification',
      );
      expect(await _scopeRevision(db, owner: store.scope.owner), 1);
    },
  );

  test(
    'A-B-A held-write callback cannot refresh a stale captured owner epoch',
      () async {
    final client = _backendClient();
    await _signIn(client, 'callback-a');
    final h = await _harness(
      initialAuth: AppAuthState(user: _userFor('callback-a')),
      backend: client,
    );
    addTearDown(() async {
        await h.close();
      await client.dispose();
    });
    final oldStore =
          await h.container.read(sentenceHuntLearningStoreProvider.future)
              as SqliteSentenceHuntLearningRepository;
      final db = await h.database.handle.open();
      var notifications = 0;
    final subscription = h.container.listen(
        sentenceHuntLearningStateProvider,
        (_, __) => notifications++,
        fireImmediately: true,
      );
    addTearDown(subscription.close);
      final empty = await h.container.read(
        sentenceHuntLearningStateProvider.future,
      );
    final command = oldStore.prepare(
      state: empty,
      sectionId: fixtureSectionIds.first,
      action: StartSentenceHuntRun(
        sessionId: 'captured-a',
        policy: _catalogue.section(fixtureSectionIds.first).policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );
      h.database.barrier.holdNextCommit();
    final saving = oldStore.submit(command);
      await h.database.barrier.commitEntered;

    await _signIn(client, 'callback-b');
    h.auth.emit(AppAuthState(user: _userFor('callback-b')));
    await Future<void>.delayed(Duration.zero);
    await _signIn(client, 'callback-a');
    h.auth.emit(AppAuthState(user: _userFor('callback-a')));
    await Future<void>.delayed(Duration.zero);
    final currentIdentity = h.container.read(learningAuthScopeProvider);
    expect(currentIdentity.generation, 2);

      final Future<SentenceHuntState> currentLoad = h.container.read(
        sentenceHuntLearningStateProvider.future,
      );
      h.database.barrier.releaseCommit();
      await expectLater(saving, throwsA(isA<LearningOwnerChangedException>()));
    expect((await currentLoad).revision, 1);
      final afterCurrentLoadNotifications = notifications;
      oldStore.onCommitted!.call();
    await Future<void>.delayed(Duration.zero);
      expect(
        notifications,
        afterCurrentLoadNotifications,
        reason:
            'old A generation callback cannot start another current-owner load',
      );
      final currentStore = await h.container.read(
        sentenceHuntLearningStoreProvider.future,
      );
      expect(
        (currentStore as SqliteSentenceHuntLearningRepository).authGeneration,
        2,
      );
    expect(currentStore.scope.owner, LearningOwner.account('callback-a'));
      expect(await _scopeRevision(db, owner: oldStore.scope.owner), 1);
    },
  );

  test(
    'readiness loss suppresses ACK publication while keeping durable commit',
      () async {
    final h = await _harness();
      addTearDown(h.close);
      final db = await h.database.handle.open();
      final store = await h.container.read(
        sentenceHuntLearningStoreProvider.future,
      );
      final empty = await h.container.read(
        sentenceHuntLearningStateProvider.future,
      );
    final command = store.prepare(
      state: empty,
      sectionId: fixtureSectionIds.first,
      action: StartSentenceHuntRun(
        sessionId: 'readiness-loss',
        policy: _catalogue.section(fixtureSectionIds.first).policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );
      var notifications = 0;
      final subscription = h.container.listen(
        sentenceHuntLearningStateProvider,
        (_, __) => notifications++,
      );
      addTearDown(subscription.close);
      h.database.barrier.holdNextCommit();
    final saving = store.submit(command);
      await h.database.barrier.commitEntered;
    h.auth.emit(const AppAuthState(isLoading: true));
    await Future<void>.delayed(Duration.zero);
      final notificationsBeforeRelease = notifications;
      h.database.barrier.releaseCommit();
      await expectLater(saving, throwsA(isA<LearningOwnerChangedException>()));
    await Future<void>.delayed(Duration.zero);
      expect(
        notifications,
        notificationsBeforeRelease,
        reason: 'readiness loss must not publish a stale progress refresh',
      );
      expect(
        await _scopeRevision(db, owner: store.scope.owner),
        1,
        reason:
            'an already-committed captured write remains durable without ACK',
      );
    },
  );

  test(
    'disposed store provider cannot publish from an already-entered write',
      () async {
    final h = await _harness();
      addTearDown(h.close);
      final db = await h.database.handle.open();
      final store = await h.container.read(
        sentenceHuntLearningStoreProvider.future,
      );
    final state = await store.load();
    final command = store.prepare(
      state: state,
      sectionId: fixtureSectionIds.first,
      action: StartSentenceHuntRun(
        sessionId: 'disposed-provider',
        policy: _catalogue.section(fixtureSectionIds.first).policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );
      h.database.barrier.holdNextCommit();
    final saving = store.submit(command);
      await h.database.barrier.commitEntered;
      h.disposeContainer();
      h.database.barrier.releaseCommit();

    expect((await saving).state.revision, 1);
      expect(await _scopeRevision(db, owner: store.scope.owner), 1);
    },
  );
}

User _userFor(String id) => User.fromJson(<String, Object?>{
      'id': id,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    })!;

SupabaseClient _backendClient() => SupabaseClient(
      'https://sentence-providers.example.invalid',
      'public-test-key',
      httpClient: MockClient((request) async {
    final String email =
        (jsonDecode(request.body) as Map<String, Object?>)['email'] as String;
        final String id = email.split('@').first;
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

Future<void> _signIn(SupabaseClient client, String id) async {
  await client.auth.signInWithPassword(
    email: '$id@example.invalid',
    password: 'test-password',
  );
}

final class _ProviderDatabase {
  _ProviderDatabase(this.directory, this.barrier);

  final Directory directory;
  final _ProviderSqlCommitBarrier barrier;
  int openCalls = 0;

  late final LearningDatabaseHandle handle = LearningDatabaseHandle(
    open: () async {
      openCalls++;
      final file = File('${directory.path}/learning.sqlite');
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

final class _ProviderSqlCommitBarrier extends QueryInterceptor {
  bool _holdCommit = false;
  bool _learningWritePendingCommit = false;
  bool _failNextLearningWrite = false;
  Completer<void>? _entered;
  Completer<void>? _release;

  Future<void> get commitEntered => _entered!.future;

  void holdNextCommit() {
    _holdCommit = true;
    _entered = Completer<void>();
    _release = Completer<void>();
  }

  void failNextLearningWrite() {
    _failNextLearningWrite = true;
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
    if (_isLearningWrite(statement) && _failNextLearningWrite) {
      _failNextLearningWrite = false;
      return Future<void>.error(StateError('test SQL write rejected'));
    }
    if (statement.contains('UPDATE learning_scopes SET revision = revision')) {
      _learningWritePendingCommit = true;
    }
    return executor.runCustom(statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (_isLearningWrite(statement) && _failNextLearningWrite) {
      _failNextLearningWrite = false;
      return Future<int>.error(StateError('test SQL write rejected'));
    }
    if (statement.contains('UPDATE learning_scopes SET revision = revision')) {
      _learningWritePendingCommit = true;
    }
    return executor.runUpdate(statement, args);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await inner.send();
    final shouldHold = _holdCommit && _learningWritePendingCommit;
    _learningWritePendingCommit = false;
    if (!shouldHold) return;
    _holdCommit = false;
    _entered!.complete();
    await _release!.future;
  }

  bool _isLearningWrite(String statement) =>
      statement.contains('UPDATE learning_scopes SET revision = revision');
}

Future<_ProviderDatabase> _newProviderDatabase() async {
  final directory = await Directory.systemTemp.createTemp(
    'sentence-provider-test-',
  );
  return _ProviderDatabase(directory, _ProviderSqlCommitBarrier());
}

Future<int?> _scopeRevision(
  LearningDatabase db, {
  required LearningOwner owner,
}) async {
  final rows = await db
      .customSelect(
        'SELECT revision FROM learning_scopes WHERE owner_kind = ? AND '
        'owner_id = ? AND course_id = ? AND family = ?',
        variables: <Variable<Object>>[
          Variable<String>(owner.isGuest ? 'guest' : 'account'),
          Variable<String>(owner.userId ?? ''),
          const Variable<String>('en-fr'),
          const Variable<String>('sentence-hunt'),
        ],
      )
      .get();
  return rows.isEmpty ? null : rows.single.read<int>('revision');
}
