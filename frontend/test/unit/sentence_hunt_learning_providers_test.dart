import 'dart:async';
import 'dart:convert';

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
import 'package:linguist/src/core/course/sentence_hunt_learning_store.dart';
import 'package:linguist/src/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../support/course_learning_persistence_fakes.dart';
import '../support/sentence_hunt_fixtures.dart';

final _catalogue = syntheticSentenceCatalogue();

final class _ProviderAuth extends AuthController {
  _ProviderAuth() : super(null) {
    emit(const AppAuthState(isLoading: true));
  }

  void emit(AppAuthState value) => state = value;
}

final class _Harness {
  const _Harness(this.auth, this.persistence, this.container);

  final _ProviderAuth auth;
  final FakeLearningPersistence persistence;
  final ProviderContainer container;
}

Future<_Harness> _harness({
  AppAuthState initialAuth = const AppAuthState(),
  SupabaseClient? backend,
  Future<SentenceHuntCatalogue> Function()? catalogue,
}) async {
  courseBackend = backend;
  final auth = _ProviderAuth();
  final persistence = FakeLearningPersistence();
  final container = ProviderContainer(overrides: <Override>[
    authControllerProvider.overrideWith((ref) => auth),
    learningPersistenceProvider.overrideWithValue(persistence),
    sentenceHuntCatalogueProvider.overrideWith(
      (ref) =>
          catalogue?.call() ?? Future<SentenceHuntCatalogue>.value(_catalogue),
    ),
  ]);
  container.read(learningAuthScopeProvider);
  auth.emit(initialAuth);
  await Future<void>.delayed(Duration.zero);
  return _Harness(auth, persistence, container);
}

void main() {
  test('store provider stays loading until async sentence catalogue resolves',
      () async {
    final completer = Completer<SentenceHuntCatalogue>();
    final h = await _harness(catalogue: () => completer.future);
    addTearDown(() {
      h.container.dispose();
      courseBackend = null;
    });
    final acquisition =
        h.container.read(sentenceHuntLearningStoreProvider.future);

    expect(
        h.container.read(sentenceHuntLearningStoreProvider).isLoading, isTrue);
    expect(h.persistence.reads, isEmpty);
    completer.complete(_catalogue);
    final SentenceHuntLearningRepository store =
        await acquisition as SentenceHuntLearningRepository;

    expect(store.scope.owner.isGuest, isTrue);
    expect(h.persistence.reads, isEmpty,
        reason: 'store construction is lazy with respect to persistence');
  });

  test('state provider awaits store acquisition and loads only after catalogue',
      () async {
    final completer = Completer<SentenceHuntCatalogue>();
    final h = await _harness(catalogue: () => completer.future);
    addTearDown(() {
      h.container.dispose();
      courseBackend = null;
    });
    final Future<SentenceHuntState> loading =
        h.container.read(sentenceHuntLearningStateProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(h.persistence.reads, isEmpty);
    expect(
        h.container.read(sentenceHuntLearningStateProvider).isLoading, isTrue);

    completer.complete(_catalogue);
    final state = await loading;
    expect(state.revision, 0);
    expect(state.slots, isEmpty);
    expect(h.persistence.reads, hasLength(1));
  });

  test('catalogue acquisition errors can be retried by provider invalidation',
      () async {
    var failCatalogue = true;
    final h = await _harness(catalogue: () async {
      if (failCatalogue) throw StateError('synthetic catalogue failure');
      return _catalogue;
    });
    addTearDown(() {
      h.container.dispose();
      courseBackend = null;
    });

    await expectLater(
      h.container.read(sentenceHuntLearningStoreProvider.future),
      throwsA(isA<StateError>()),
    );
    expect(h.persistence.reads, isEmpty);
    failCatalogue = false;
    h.container.invalidate(sentenceHuntCatalogueProvider);
    h.container.invalidate(sentenceHuntLearningStoreProvider);

    final store =
        await h.container.read(sentenceHuntLearningStoreProvider.future);
    expect(store.scope.owner.isGuest, isTrue);
    expect(h.persistence.reads, isEmpty);
  });

  test('readiness loss during async acquisition cannot publish a store',
      () async {
    final completer = Completer<SentenceHuntCatalogue>();
    final h = await _harness(catalogue: () => completer.future);
    addTearDown(() {
      h.container.dispose();
      courseBackend = null;
    });
    final staleAcquisition =
        h.container.read(sentenceHuntLearningStoreProvider.future);
    unawaited(staleAcquisition.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    ));
    h.auth.emit(const AppAuthState(isLoading: true));
    await Future<void>.delayed(Duration.zero);
    completer.complete(_catalogue);

    await expectLater(
      h.container.read(sentenceHuntLearningStoreProvider.future),
      throwsA(isA<LearningOwnerChangedException>()),
    );
    expect(h.persistence.reads, isEmpty);

    h.auth.emit(const AppAuthState());
    await Future<void>.delayed(Duration.zero);
    final current =
        await h.container.read(sentenceHuntLearningStoreProvider.future);
    expect(current.scope.owner.isGuest, isTrue);
    expect(h.persistence.reads, isEmpty);
  });

  test('A-B-A during catalogue await acquires only the current auth generation',
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
      h.container.dispose();
      courseBackend = null;
      await client.dispose();
    });
    final staleAcquisition =
        h.container.read(sentenceHuntLearningStoreProvider.future);

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

    final current =
        await h.container.read(sentenceHuntLearningStoreProvider.future);
    expect(current.scope.owner, LearningOwner.account('account-a'));
    expect((current as SentenceHuntLearningRepository).authGeneration, 2);
    final staleFutureValue = await staleAcquisition;
    expect(
        (staleFutureValue as SentenceHuntLearningRepository).authGeneration, 2,
        reason: 'a Future observed before A-B-A must never emit the old epoch');
    expect(identical(staleFutureValue, current), isTrue);
    expect(h.persistence.reads, isEmpty);
  });

  test(
      'ACK refreshes the current state provider; failed and duplicate writes do not',
      () async {
    final h = await _harness();
    addTearDown(() {
      h.container.dispose();
      courseBackend = null;
    });
    final store =
        await h.container.read(sentenceHuntLearningStoreProvider.future);
    final subscription = h.container.listen(
        sentenceHuntLearningStateProvider, (_, __) {},
        fireImmediately: true);
    addTearDown(subscription.close);
    await h.container.read(sentenceHuntLearningStateProvider.future);
    final int readsBefore = h.persistence.reads.length;
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

    h.persistence.holdNextWrite();
    final saving = store.submit(command);
    await h.persistence.writeEntered;
    final readsWhileHeld = h.persistence.reads.length;
    await Future<void>.delayed(Duration.zero);
    expect(h.persistence.reads.length, readsWhileHeld);
    h.persistence.releaseWrite(persist: false);
    await expectLater(saving, throwsA(isA<LearningSaveException>()));
    final readsAfterFailure = h.persistence.reads.length;
    await Future<void>.delayed(Duration.zero);
    expect(h.persistence.reads.length, readsAfterFailure,
        reason: 'failed writes do not invalidate state');

    final saved = await store.submit(command);
    expect(saved.duplicate, isFalse);
    final refreshed =
        await h.container.read(sentenceHuntLearningStateProvider.future);
    expect(refreshed.revision, 1);
    final readsAfterAck = h.persistence.reads.length;
    expect(readsAfterAck, greaterThan(readsBefore));
    final readsBeforeDuplicate = h.persistence.reads.length;
    expect((await store.submit(command)).duplicate, isTrue);
    final readsAfterDuplicate = h.persistence.reads.length;
    expect(readsAfterDuplicate, readsBeforeDuplicate + 1,
        reason: 'the coordinator reads once to identify an exact duplicate');
    await Future<void>.delayed(Duration.zero);
    expect(h.persistence.reads.length, readsAfterDuplicate,
        reason: 'idempotent replay does not produce an ACK notification');
  });

  test('A-B-A held-write callback cannot refresh a stale captured owner epoch',
      () async {
    final client = _backendClient();
    await _signIn(client, 'callback-a');
    final h = await _harness(
      initialAuth: AppAuthState(user: _userFor('callback-a')),
      backend: client,
    );
    addTearDown(() async {
      h.container.dispose();
      courseBackend = null;
      await client.dispose();
    });
    final oldStore =
        await h.container.read(sentenceHuntLearningStoreProvider.future);
    final subscription = h.container.listen(
        sentenceHuntLearningStateProvider, (_, __) {},
        fireImmediately: true);
    addTearDown(subscription.close);
    final empty =
        await h.container.read(sentenceHuntLearningStateProvider.future);
    final command = oldStore.prepare(
      state: empty,
      sectionId: fixtureSectionIds.first,
      action: StartSentenceHuntRun(
        sessionId: 'captured-a',
        policy: _catalogue.section(fixtureSectionIds.first).policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );
    h.persistence.holdNextWrite();
    final saving = oldStore.submit(command);
    await h.persistence.writeEntered;

    await _signIn(client, 'callback-b');
    h.auth.emit(AppAuthState(user: _userFor('callback-b')));
    await Future<void>.delayed(Duration.zero);
    await _signIn(client, 'callback-a');
    h.auth.emit(AppAuthState(user: _userFor('callback-a')));
    await Future<void>.delayed(Duration.zero);
    final currentIdentity = h.container.read(learningAuthScopeProvider);
    expect(currentIdentity.generation, 2);

    final Future<SentenceHuntState> currentLoad =
        h.container.read(sentenceHuntLearningStateProvider.future);
    h.persistence.releaseWrite(persist: true);
    expect((await saving).state.revision, 1);
    expect((await currentLoad).revision, 1);
    final int readsAfterCurrentLoad = h.persistence.reads.length;
    await Future<void>.delayed(Duration.zero);
    expect(h.persistence.reads.length, readsAfterCurrentLoad,
        reason:
            'old A generation callback cannot start another current-owner load');
    final currentStore =
        await h.container.read(sentenceHuntLearningStoreProvider.future);
    expect((currentStore as SentenceHuntLearningRepository).authGeneration, 2);
    expect(currentStore.scope.owner, LearningOwner.account('callback-a'));
  });

  test('readiness loss suppresses ACK publication while keeping durable commit',
      () async {
    final h = await _harness();
    addTearDown(() {
      h.container.dispose();
      courseBackend = null;
    });
    final store =
        await h.container.read(sentenceHuntLearningStoreProvider.future);
    final empty =
        await h.container.read(sentenceHuntLearningStateProvider.future);
    final command = store.prepare(
      state: empty,
      sectionId: fixtureSectionIds.first,
      action: StartSentenceHuntRun(
        sessionId: 'readiness-loss',
        policy: _catalogue.section(fixtureSectionIds.first).policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );
    h.persistence.holdNextWrite();
    final saving = store.submit(command);
    await h.persistence.writeEntered;
    h.auth.emit(const AppAuthState(isLoading: true));
    await Future<void>.delayed(Duration.zero);
    final readsWhileNotReady = h.persistence.reads.length;
    h.persistence.releaseWrite(persist: true);
    expect((await saving).state.revision, 1);
    await Future<void>.delayed(Duration.zero);
    expect(h.persistence.reads.length, readsWhileNotReady,
        reason: 'readiness loss must not publish a stale progress refresh');
    expect(h.persistence.platform[store.scope.storageKey], isNotNull,
        reason:
            'an already-entered captured write may still receive durable ACK');
  });

  test('disposed store provider cannot publish from an already-entered write',
      () async {
    final h = await _harness();
    final store =
        await h.container.read(sentenceHuntLearningStoreProvider.future);
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
    h.persistence.holdNextWrite();
    final saving = store.submit(command);
    await h.persistence.writeEntered;
    h.container.dispose();
    h.persistence.releaseWrite(persist: true);

    expect((await saving).state.revision, 1);
    expect(h.persistence.platform[store.scope.storageKey], isNotNull);
    courseBackend = null;
  });
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
        final String email = (jsonDecode(request.body)
            as Map<String, Object?>)['email'] as String;
        final String id = email.split('@').first;
        final payload = jsonEncode(<String, Object?>{
          'sub': id,
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        });
        final token = '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
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
      email: '$id@example.invalid', password: 'test-password');
}
