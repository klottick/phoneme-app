import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_store.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/services/auth_service.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _ProviderAuth extends AuthController {
  _ProviderAuth() : super(null) {
    emit(const AppAuthState(isLoading: true));
  }
  void emit(AppAuthState value) => state = value;
}

final class _OverridableCurrentTracker extends LearningAuthTracker {
  _OverridableCurrentTracker()
      : super(owner: LearningOwner.guest(), ready: true);
  LearningAuthScope? currentOverride;
  @override
  LearningAuthScope get current => currentOverride ?? super.current;
}

final class _ProviderPersistence implements LearningPersistence {
  final Map<String, String> values = {};
  final Map<String, int> reads = {};
  Completer<void>? entered;
  Completer<bool>? gate;
  bool holdNext = false;
  bool failNext = false;
  @override
  Future<String?> read(String key) async {
    reads.update(key, (value) => value + 1, ifAbsent: () => 1);
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (holdNext) {
      holdNext = false;
      entered!.complete();
      if (!await gate!.future) throw StateError('held write rejected');
    }
    if (failNext) {
      failNext = false;
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

final class _Harness {
  _Harness(this.auth, this.persistence, this.container);
  final _ProviderAuth auth;
  final _ProviderPersistence persistence;
  final ProviderContainer container;
}

Future<_Harness> _harness({
  List<Override> extraOverrides = const [],
}) async {
  courseBackend = null;
  final auth = _ProviderAuth();
  final persistence = _ProviderPersistence();
  final container = ProviderContainer(overrides: [
    authControllerProvider.overrideWith((ref) => auth),
    learningPersistenceProvider.overrideWithValue(persistence),
    ...extraOverrides,
  ]);
  container.read(learningAuthScopeProvider);
  auth.emit(const AppAuthState());
  await Future<void>.delayed(Duration.zero);
  return _Harness(auth, persistence, container);
}

void main() {
  const activity = comparisonActivityId;

  test('comparison provider declarations are lazy until read', () async {
    var catalogueCalls = 0;
    final h = await _harness(extraOverrides: [
      comparisonCatalogueProvider.overrideWith((ref) {
        catalogueCalls++;
        return loadFrenchComparisonCatalogue();
      }),
    ]);
    addTearDown(h.container.dispose);
    expect(catalogueCalls, 0);
    expect(h.persistence.reads, isEmpty);
    final store = h.container.read(comparisonLearningStoreProvider)
        as ComparisonLearningRepository;
    expect(catalogueCalls, 1);
    expect(store, isA<ComparisonLearningRepository>());
    expect(h.persistence.reads, isEmpty,
        reason: 'constructing the real store must not load persistence');
  });

  test('catalogue failure precedes persistence access', () async {
    final h = await _harness(extraOverrides: [
      comparisonCatalogueProvider
          .overrideWith((ref) => throw StateError('catalogue invalid')),
    ]);
    addTearDown(h.container.dispose);
    expect(() => h.container.read(comparisonLearningStoreProvider),
        throwsA(isA<StateError>()));
    expect(h.persistence.reads, isEmpty);
    expect(h.persistence.values, isEmpty);
  });

  test('comparison commits without constructing cloud transport', () async {
    final h = await _harness(extraOverrides: [
      learningCloudTransportProvider
          .overrideWith((ref) => throw StateError('cloud must not be read')),
    ]);
    addTearDown(h.container.dispose);
    final store = h.container.read(comparisonLearningStoreProvider);
    final state = await store.load();
    final command = store.prepare(
        state: state,
        activityId: activity,
        action:
            StartComparisonRun(sessionId: 'no-cloud', policy: LessonPolicy()));
    expect((await store.submit(command)).state.slot, isNotNull);
    expect(h.persistence.values.keys, contains(store.scope.storageKey));
  });

  test('readiness changes preserve provider identity and fence prepare',
      () async {
    final h = await _harness();
    addTearDown(h.container.dispose);
    final store = h.container.read(comparisonLearningStoreProvider);
    final generation = h.container.read(learningAuthScopeProvider).generation;
    h.auth.emit(const AppAuthState(isLoading: true));
    await Future<void>.delayed(Duration.zero);
    expect(h.container.read(learningAuthScopeProvider).generation, generation);
    expect(identical(h.container.read(comparisonLearningStoreProvider), store),
        isTrue);
    final state = await store.load();
    expect(
        () => store.prepare(
            state: state,
            activityId: activity,
            action: StartComparisonRun(
                sessionId: 'blocked', policy: LessonPolicy())),
        throwsA(isA<LearningOwnerChangedException>()));
    h.auth.emit(const AppAuthState());
    await Future<void>.delayed(Duration.zero);
    expect(identical(h.container.read(comparisonLearningStoreProvider), store),
        isTrue);
  });

  test('comparison and v2 state providers refresh only their own family',
      () async {
    final h = await _harness();
    addTearDown(h.container.dispose);
    final comparison = h.container.read(comparisonLearningStoreProvider);
    final v2 = h.container.read(courseLearningStoreProvider);
    final comparisonSubscription = h.container.listen(
        comparisonLearningStateProvider, (_, __) {},
        fireImmediately: true);
    final v2Subscription = h.container
        .listen(courseLearningStateProvider, (_, __) {}, fireImmediately: true);
    addTearDown(comparisonSubscription.close);
    addTearDown(v2Subscription.close);
    await h.container.read(comparisonLearningStateProvider.future);
    await h.container.read(courseLearningStateProvider.future);
    final ck = comparison.scope.storageKey;
    final vk = v2.scope.storageKey;
    final cState = await comparison.load();
    await comparison.submit(comparison.prepare(
        state: cState,
        activityId: activity,
        action: StartComparisonRun(
            sessionId: 'refresh-c', policy: LessonPolicy())));
    await h.container.read(comparisonLearningStateProvider.future);
    final cReadsAfterComparisonCommit = h.persistence.reads[ck]!;
    final vReadsBeforeV2Commit = h.persistence.reads[vk]!;
    expect(cReadsAfterComparisonCommit, greaterThan(1));
    final vState = await v2.load();
    await v2.submit(v2.prepare(
        state: vState,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions())));
    await h.container.read(courseLearningStateProvider.future);
    expect(h.persistence.reads[vk], vReadsBeforeV2Commit + 3,
        reason: 'manual load, submit read, and its provider refresh');
    expect(h.persistence.reads[ck], cReadsAfterComparisonCommit,
        reason: 'v2 commit must not publish or reload comparison state');
  });

  test('duplicate and rejected comparison writes do not refresh state provider',
      () async {
    final h = await _harness();
    addTearDown(h.container.dispose);
    final store = h.container.read(comparisonLearningStoreProvider);
    var notifications = 0;
    final sub = h.container.listen(
        comparisonLearningStateProvider, (_, __) => notifications++,
        fireImmediately: true);
    addTearDown(sub.close);
    await h.container.read(comparisonLearningStateProvider.future);
    final beforeFailureNotifications = notifications;
    final empty = await store.load();
    final reads = h.persistence.reads[store.scope.storageKey]!;
    final start = store.prepare(
        state: empty,
        activityId: activity,
        action: StartComparisonRun(
            sessionId: 'no-refresh', policy: LessonPolicy()));
    h.persistence.failNext = true;
    await expectLater(
        store.submit(start), throwsA(isA<LearningSaveException>()));
    expect(notifications, beforeFailureNotifications);
    expect(h.persistence.reads[store.scope.storageKey], reads + 2,
        reason: 'load plus rollback verification, no provider notification');
    final retry = await store.submit(start);
    expect(retry.duplicate, isFalse);
    final afterCommit = h.persistence.reads[store.scope.storageKey]!;
    await h.container.read(comparisonLearningStateProvider.future);
    expect(h.persistence.reads[store.scope.storageKey], afterCommit + 1);
    final afterCommitNotifications = notifications;
    expect(afterCommitNotifications, greaterThan(beforeFailureNotifications));
    await store.submit(start);
    final afterDuplicate = h.persistence.reads[store.scope.storageKey]!;
    await Future<void>.delayed(Duration.zero);
    expect(h.persistence.reads[store.scope.storageKey], afterDuplicate);
    expect(notifications, afterCommitNotifications);
  });

  test('corrupt comparison state does not block valid v2 state, and reverse',
      () async {
    final h = await _harness();
    addTearDown(h.container.dispose);
    final comparison = h.container.read(comparisonLearningStoreProvider);
    final v2 = h.container.read(courseLearningStoreProvider);
    final v2Empty = await v2.load();
    h.persistence.values[v2.scope.storageKey] =
        const LearningDocumentCodec().encode(v2Empty);
    const badComparison = '{"schemaVersion":2,"raw":"untouched"}';
    h.persistence.values[comparison.scope.storageKey] = badComparison;
    h.container.invalidate(comparisonLearningStateProvider);
    h.container.invalidate(courseLearningStateProvider);
    await expectLater(h.container.read(comparisonLearningStateProvider.future),
        throwsA(isA<ComparisonUnavailableException>()));
    expect(
        (await h.container.read(courseLearningStateProvider.future)).revision,
        0);
    expect(h.persistence.values[comparison.scope.storageKey], badComparison);

    h.persistence.values.remove(comparison.scope.storageKey);
    final compEmpty = await comparison.load();
    await comparison.submit(comparison.prepare(
        state: compEmpty,
        activityId: activity,
        action:
            StartComparisonRun(sessionId: 'valid-c', policy: LessonPolicy())));
    h.persistence.values[v2.scope.storageKey] = '{bad v2';
    h.container.invalidate(comparisonLearningStateProvider);
    h.container.invalidate(courseLearningStateProvider);
    expect(
        (await h.container.read(comparisonLearningStateProvider.future))
            .revision,
        1);
    await expectLater(h.container.read(courseLearningStateProvider.future),
        throwsA(isA<Exception>()));
  });

  test('captured comparison write ACKs after auth epoch change without refresh',
      () async {
    final h = await _harness();
    addTearDown(h.container.dispose);
    final store = h.container.read(comparisonLearningStoreProvider);
    final sub = h.container.listen(comparisonLearningStateProvider, (_, __) {},
        fireImmediately: true);
    addTearDown(sub.close);
    await h.container.read(comparisonLearningStateProvider.future);
    final state = await store.load();
    final command = store.prepare(
        state: state,
        activityId: activity,
        action: StartComparisonRun(
            sessionId: 'epoch-held', policy: LessonPolicy()));
    final before = h.persistence.reads[store.scope.storageKey]!;
    h.persistence
      ..holdNext = true
      ..entered = Completer<void>()
      ..gate = Completer<bool>();
    final save = store.submit(command);
    await h.persistence.entered!.future;
    h.auth.emit(AppAuthState(user: _userFor('B')));
    await Future<void>.delayed(Duration.zero);
    final beforeRelease = h.persistence.reads[store.scope.storageKey]!;
    try {
      h.persistence.gate!.complete(true);
    } finally {
      if (!h.persistence.gate!.isCompleted) h.persistence.gate!.complete(false);
    }
    final committed = await save;
    expect(committed.state.scope, store.scope);
    expect(h.persistence.values[store.scope.storageKey], isNotNull);
    final newKey = ComparisonProfileScope(
            courseId: 'en-fr', owner: LearningOwner.account('B'))
        .storageKey;
    expect(h.persistence.values, isNot(contains(newKey)));
    await Future<void>.delayed(Duration.zero);
    expect(h.persistence.reads[store.scope.storageKey], beforeRelease);
    expect(beforeRelease, greaterThan(before));
  });

  test('tracker owner epoch guard suppresses callback independently', () async {
    final h = await _harness();
    addTearDown(h.container.dispose);
    final store = h.container.read(comparisonLearningStoreProvider);
    final sub = h.container.listen(comparisonLearningStateProvider, (_, __) {},
        fireImmediately: true);
    addTearDown(sub.close);
    await h.container.read(comparisonLearningStateProvider.future);
    final state = await store.load();
    final command = store.prepare(
        state: state,
        activityId: activity,
        action: StartComparisonRun(
            sessionId: 'tracker-guard', policy: LessonPolicy()));
    h.persistence
      ..holdNext = true
      ..entered = Completer<void>()
      ..gate = Completer<bool>();
    final save = store.submit(command);
    await h.persistence.entered!.future;
    h.auth.emit(AppAuthState(user: _userFor('B')));
    h.auth.emit(const AppAuthState());
    final reads = h.persistence.reads[store.scope.storageKey]!;
    try {
      h.persistence.gate!.complete(true);
    } finally {
      if (!h.persistence.gate!.isCompleted) h.persistence.gate!.complete(false);
    }
    await save;
    await Future<void>.delayed(Duration.zero);
    expect(h.container.read(learningAuthScopeProvider).owner.isGuest, isTrue);
    expect(h.container.read(learningAuthScopeProvider).generation, 2);
    expect(h.persistence.reads[store.scope.storageKey], reads + 1,
        reason:
            'only the new owner-epoch provider load; old callback adds none');
  });

  test('captured provider callback ignores stale tracker identity', () async {
    final h = await _harness();
    addTearDown(h.container.dispose);
    final store = h.container.read(comparisonLearningStoreProvider)
        as ComparisonLearningRepository;
    final subscription = h.container.listen(
        comparisonLearningStateProvider, (_, __) {},
        fireImmediately: true);
    addTearDown(subscription.close);
    await h.container.read(comparisonLearningStateProvider.future);
    h.auth.emit(AppAuthState(user: _userFor('B')));
    store.onCommitted!.call();
    final accountKey = ComparisonProfileScope(
            courseId: 'en-fr', owner: LearningOwner.account('B'))
        .storageKey;
    await h.container.read(comparisonLearningStateProvider.future);
    expect(h.persistence.reads[accountKey], 1,
        reason:
            'only the new identity load; stale captured callback adds none');
  });

  test('tracker guard independently fences a stale current snapshot', () async {
    final tracker = _OverridableCurrentTracker();
    final persistence = _ProviderPersistence();
    final container = ProviderContainer(overrides: [
      learningAuthScopeProvider.overrideWith((ref) => tracker),
      learningPersistenceProvider.overrideWithValue(persistence),
      learningCloudTransportProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    final store = container.read(comparisonLearningStoreProvider)
        as ComparisonLearningRepository;
    final subscription = container.listen(
        comparisonLearningStateProvider, (_, __) {},
        fireImmediately: true);
    addTearDown(subscription.close);
    await container.read(comparisonLearningStateProvider.future);
    final reads = persistence.reads[store.scope.storageKey]!;
    tracker.currentOverride = LearningAuthScope(
        owner: LearningOwner.account('stale'), generation: 1, ready: true);
    store.onCommitted!.call();
    await container.read(comparisonLearningStateProvider.future);
    expect(persistence.reads[store.scope.storageKey], reads,
        reason:
            'only tracker.current differs; provider identity/aliveness do not');
  });

  test('backend-only owner mismatch suppresses comparison callback', () async {
    final client = _backendClient();
    await client.auth.signInWithPassword(
        email: 'backend-owner@example.invalid', password: 'test-password');
    final h = await _harness();
    addTearDown(() async {
      h.container.dispose();
      courseBackend = null;
      await client.dispose();
    });
    final store = h.container.read(comparisonLearningStoreProvider);
    final originalAuth = h.container.read(learningAuthScopeProvider);
    final sub = h.container.listen(comparisonLearningStateProvider, (_, __) {},
        fireImmediately: true);
    addTearDown(sub.close);
    await h.container.read(comparisonLearningStateProvider.future);
    final state = await store.load();
    final command = store.prepare(
        state: state,
        activityId: activity,
        action: StartComparisonRun(
            sessionId: 'backend-guard', policy: LessonPolicy()));
    h.persistence
      ..holdNext = true
      ..entered = Completer<void>()
      ..gate = Completer<bool>();
    final save = store.submit(command);
    await h.persistence.entered!.future;
    courseBackend = client;
    final reads = h.persistence.reads[store.scope.storageKey]!;
    try {
      h.persistence.gate!.complete(true);
    } finally {
      if (!h.persistence.gate!.isCompleted) h.persistence.gate!.complete(false);
    }
    await save;
    await Future<void>.delayed(Duration.zero);
    expect(h.container.read(learningAuthScopeProvider).owner.isGuest, isTrue);
    expect(h.container.read(learningAuthScopeProvider).generation,
        originalAuth.generation);
    expect(h.persistence.reads[store.scope.storageKey], reads);
  });

  test(
      'disposed comparison provider suppresses callback before notifier access',
      () async {
    final h = await _harness();
    final store = h.container.read(comparisonLearningStoreProvider);
    final state = await store.load();
    final command = store.prepare(
        state: state,
        activityId: activity,
        action:
            StartComparisonRun(sessionId: 'disposed', policy: LessonPolicy()));
    h.persistence
      ..holdNext = true
      ..entered = Completer<void>()
      ..gate = Completer<bool>();
    final save = store.submit(command);
    await h.persistence.entered!.future;
    h.container.dispose();
    try {
      h.persistence.gate!.complete(true);
    } finally {
      if (!h.persistence.gate!.isCompleted) h.persistence.gate!.complete(false);
    }
    expect((await save).state.revision, 1);
  });

  test('throwing comparison onCommitted cannot undo durable acknowledgment',
      () async {
    final persistence = _ProviderPersistence();
    final owner = LearningOwner.guest();
    final store = ComparisonLearningRepository(
        scope: ComparisonProfileScope(courseId: 'en-fr', owner: owner),
        authGeneration: 0,
        currentAuth: () =>
            LearningAuthScope(owner: owner, generation: 0, ready: true),
        backendOwner: () => owner,
        persistence: persistence,
        transitions: ComparisonLearningTransitionEngine(
            catalogue: loadFrenchComparisonCatalogue()),
        clock: () => DateTime.utc(2026),
        newToken: () => 'abcdefghijklmnopqrstuv',
        onCommitted: () => throw StateError('observer failed'));
    final empty = await store.load();
    final command = store.prepare(
        state: empty,
        activityId: activity,
        action:
            StartComparisonRun(sessionId: 'throwing', policy: LessonPolicy()));
    expect((await store.submit(command)).state.revision, 1);
    expect((await store.load()).revision, 1);
  });
}

User _userFor(String id) => User.fromJson({
      'id': id,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    })!;

SupabaseClient _backendClient() =>
    SupabaseClient('https://providers.example.invalid', 'public-test-key',
        httpClient: MockClient((request) async {
      final email = (jsonDecode(request.body) as Map)['email'] as String;
      final id = email.split('@').first;
      final payload = jsonEncode({
        'sub': id,
        'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      });
      final token = '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
          '${base64Url.encode(utf8.encode(payload))}.signature';
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
