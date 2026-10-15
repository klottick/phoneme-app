import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

SupabaseClient _backendClient() =>
    SupabaseClient('https://learning.example.invalid', 'public-test-key',
        httpClient: MockClient((request) async {
      final email = (jsonDecode(request.body) as Map)['email'] as String;
      final id = email.split('@').first;
      final token = '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
          '${base64Url.encode(utf8.encode(jsonEncode({
            'sub': id,
            'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          })))}.signature';
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
          headers: {'content-type': 'application/json'});
    }));

Future<void> _signIn(SupabaseClient client, String id) async {
  await client.auth.signInWithPassword(
      email: '$id@example.invalid', password: 'test-password');
}

void main() {
  test('provider rebuild tracks owner epoch, not only equal final id',
      () async {
    final persistence = _MemoryPersistence();
    final auth = _AuthNotifier();
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith((ref) => auth),
      learningPersistenceProvider.overrideWithValue(persistence),
      learningCloudTransportProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
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
  });

  test('initial loading cannot save into guest scope', () async {
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith((ref) => _AuthNotifier()),
      learningPersistenceProvider.overrideWithValue(_MemoryPersistence()),
      learningCloudTransportProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    final store = container.read(courseLearningStoreProvider);
    expect(store.scope.owner.isGuest, isTrue);
    final state = await store.load();
    expect(
        () => store.prepare(
            state: state,
            activityId: 'lesson:en-fr-u-y',
            action: StartLearningRun(options: RunOptions())),
        throwsA(isA<LearningOwnerChangedException>()));
  });

  test('throwing observer cannot fail an already committed repository write',
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
        onCommitted: () => throw StateError('observer failed'));
    final state = await store.load();
    final command = store.prepare(
        state: state,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()));

    final committed = await store.submit(command);

    expect(committed.state.activities, contains('lesson:en-fr-u-y'));
    expect((await store.load()).activities, contains('lesson:en-fr-u-y'));
  });

  test('old provider commit after owner rebuild stays on captured scope',
      () async {
    final client = _backendClient();
    courseBackend = client;
    await _signIn(client, 'old-owner');
    addTearDown(() async {
      courseBackend = null;
      await client.dispose();
    });
    final persistence = _MemoryPersistence();
    final auth = _AuthNotifier();
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith((ref) => auth),
      learningPersistenceProvider.overrideWithValue(persistence),
      learningCloudTransportProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    container.read(learningAuthScopeProvider);
    auth.emit(AppAuthState(user: _user('old-owner')));
    await Future<void>.delayed(Duration.zero);
    final oldStore = container.read(courseLearningStoreProvider);
    final oldState = await oldStore.load();
    final oldKey = oldStore.scope.storageKey;
    final command = oldStore.prepare(
        state: oldState,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()));
    var stateNotifications = 0;
    final stateSubscription = container.listen(
        courseLearningStateProvider, (_, __) => stateNotifications++,
        fireImmediately: true);
    addTearDown(stateSubscription.close);
    await container.read(courseLearningStateProvider.future);

    persistence
      ..holdNextWrite = true
      ..writeEntered = Completer<void>()
      ..writeGate = Completer<bool>();
    final oldCommit = oldStore.submit(command);
    await persistence.writeEntered!.future;
    await _signIn(client, 'new-owner');
    auth.emit(AppAuthState(user: _user('new-owner')));
    await Future<void>.delayed(Duration.zero);
    final newStore = container.read(courseLearningStoreProvider);
    expect(newStore.scope.owner.userId, 'new-owner');
    final newKey = newStore.scope.storageKey;
    expect(persistence.readsByKey[newKey] ?? 0, 0);
    final notificationsBeforeOldCompletion = stateNotifications;

    persistence.writeGate!.complete(true);
    final commit = await oldCommit;
    await container.read(courseLearningStateProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(commit.state.scope.storageKey, oldKey);
    expect(commit.state.activities, contains('lesson:en-fr-u-y'));
    expect(persistence.values, contains(oldKey));
    expect(persistence.values, isNot(contains(newKey)));
    final newState = await container.read(courseLearningStateProvider.future);
    expect(newState.activities, isEmpty);
    expect(persistence.readsByKey[newKey], 1);
    expect(stateNotifications, greaterThan(notificationsBeforeOldCompletion));
  });

  test('live commit refreshes state provider but failed write does not',
      () async {
    final client = _backendClient();
    courseBackend = client;
    await _signIn(client, 'live-owner');
    addTearDown(() async {
      courseBackend = null;
      await client.dispose();
    });
    final persistence = _MemoryPersistence();
    final auth = _AuthNotifier();
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith((ref) => auth),
      learningPersistenceProvider.overrideWithValue(persistence),
      learningCloudTransportProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    container.read(learningAuthScopeProvider);
    auth.emit(AppAuthState(user: _user('live-owner')));
    await Future<void>.delayed(Duration.zero);
    final store = container.read(courseLearningStoreProvider);
    var notifications = 0;
    final subscription = container.listen(
        courseLearningStateProvider, (_, __) => notifications++,
        fireImmediately: true);
    addTearDown(subscription.close);
    final initial = await container.read(courseLearningStateProvider.future);
    final initialNotifications = notifications;
    final command = store.prepare(
        state: initial,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()));
    persistence.failNextWrite = true;

    await expectLater(store.submit(command), throwsA(isA<Exception>()));
    await Future<void>.delayed(Duration.zero);
    expect(notifications, initialNotifications);

    final retry = store.prepare(
        state: await store.load(),
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()));
    await store.submit(retry);
    await Future<void>.delayed(Duration.zero);
    final refreshed = await container.read(courseLearningStateProvider.future);
    expect(refreshed.activities, contains('lesson:en-fr-u-y'));
    expect(notifications, greaterThan(initialNotifications));
  });

  test('same-owner auth readiness updates do not change generation', () {
    final tracker =
        LearningAuthTracker(owner: LearningOwner.account('A'), ready: true);
    final generation = tracker.current.generation;
    tracker.observe(owner: LearningOwner.account('A'), ready: false);
    tracker.observe(owner: LearningOwner.account('A'), ready: true);
    expect(tracker.current.generation, generation);
    expect(tracker.current.ready, isTrue);
    tracker.dispose();
  });

  test('supported synced status does not claim detailed history backup', () {
    const result = SupportedSyncResult(
        status: SupportedSyncStatus.synced, remainingEvents: 0);
    expect(result.status, SupportedSyncStatus.synced);
    expect(result.remainingEvents, 0);
  });
}
