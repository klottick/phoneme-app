import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_sync.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RecordingTransport implements LearningCloudTransport {
  final List<List<SupportedCloudEvent>> batches = [];
  Object? failure;
  void Function()? onSend;
  Completer<void>? entered;
  Completer<void>? release;

  @override
  Future<void> send(List<SupportedCloudEvent> events) async {
    batches.add(List.unmodifiable(events));
    onSend?.call();
    if (entered != null && !entered!.isCompleted) entered!.complete();
    if (release != null) await release!.future;
    if (failure case final error?) throw error;
  }
}

class _MemoryPersistence implements LearningPersistence {
  final Map<String, String> documents = {};
  bool failNextWrite = false;
  bool holdNextWrite = false;
  bool failRestore = false;
  Completer<void>? writeEntered;
  Completer<bool>? writeGate;
  @override
  Future<String?> read(String key) async => documents[key];
  @override
  Future<void> write(String key, String value) async {
    documents[key] = value;
    if (holdNextWrite) {
      holdNextWrite = false;
      writeEntered!.complete();
      if (!await writeGate!.future) throw StateError('write rejected');
    }
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('write rejected');
    }
  }

  @override
  Future<void> restore(String key, String? lastCommitted) async {
    if (failRestore) throw StateError('restore unavailable');
    if (lastCommitted == null) {
      documents.remove(key);
    } else {
      documents[key] = lastCommitted;
    }
  }

  @override
  Future<void> reload() async {}
}

class _TrackingLearningPersistence implements LearningPersistence {
  _TrackingLearningPersistence(this.delegate);
  final LearningPersistence delegate;
  final reads = <String>[];
  final writes = <String>[];

  @override
  Future<String?> read(String key) {
    reads.add(key);
    return delegate.read(key);
  }

  @override
  Future<void> write(String key, String value) {
    writes.add(key);
    return delegate.write(key, value);
  }

  @override
  Future<void> restore(String key, String? lastCommitted) {
    writes.add(key);
    return delegate.restore(key, lastCommitted);
  }

  @override
  Future<void> reload() => delegate.reload();
}

void main() {
  final owner = LearningOwner.account('sync-user');
  final scope = LearningScope(courseId: 'en-fr', owner: owner);
  var generation = 0;
  var authOwner = owner;
  var backend = owner;
  LearningAuthScope currentAuth() =>
      LearningAuthScope(owner: authOwner, generation: generation, ready: true);

  CourseLearningState stateWith(List<SupportedCloudEvent> pending,
          {int revision = 0, int commitOrdinal = 0}) =>
      CourseLearningState(
          scope: scope,
          revision: revision,
          commitOrdinal: commitOrdinal,
          history: const [],
          activities: const {},
          mistakes: const {},
          summaries: const {},
          completions: const [],
          bestScores: const {},
          pending: pending);

  SupportedCloudEvent event(int i) => SupportedCloudEvent(
      id: 'event-$i',
      userId: owner.userId!,
      courseId: scope.courseId,
      payload: CloudAnswer(
          sound: 'u',
          skill: LearningSkill.listening,
          correct: true,
          activity: 'lesson:en-fr-u-y'));

  CourseLearningRepository repository(
      _MemoryPersistence persistence, LearningCloudTransport transport,
      {void Function()? onCommitted}) {
    var tokenCounter = 0;
    return CourseLearningRepository(
        scope: scope,
        authGeneration: generation,
        currentAuth: currentAuth,
        backendOwner: () => backend,
        persistence: persistence,
        transitions: LearningTransitionEngine(LearningRegistry.french()),
        clock: () => DateTime.utc(2026),
        newToken: () =>
            'AAAAAAAAAAAAAAAAAAAA${(++tokenCounter).toRadixString(16).padLeft(2, '0')}',
        random: Random(1),
        cloud: transport,
        onCommitted: onCommitted);
  }

  test('offline guest learning requires no backend', () async {
    final guest =
        LearningScope(courseId: 'en-fr', owner: LearningOwner.guest());
    final persistence = _MemoryPersistence();
    final store = CourseLearningRepository(
        scope: guest,
        authGeneration: 0,
        currentAuth: () =>
            LearningAuthScope(owner: guest.owner, generation: 0, ready: true),
        backendOwner: LearningOwner.guest,
        persistence: persistence,
        transitions: LearningTransitionEngine(LearningRegistry.french()),
        clock: () => DateTime.utc(2026),
        newToken: () => 'AAAAAAAAAAAAAAAAAAAAAA',
        random: Random(1));
    expect((await store.load()).pending, isEmpty);
    expect((await store.sync()).status, SupportedSyncStatus.guest);
  });

  test('account sync never reads or sends literal legacy outbox events',
      () async {
    const oldCourseKey = 'course.v1.en-fr';
    const oldArcadeKey = 'arcade.v1.en-fr.sound';
    const oldCourse =
        '{"lessons":["en-fr-u-y"],"evidence":{"listening:u":{"attempts":8,"correct":7}},"pending":[{"id":"legacy-outbox-event-7","event":"legacy"}]}';
    const oldArcade = '{"session":{"remaining":17,"score":91}}';
    SharedPreferences.setMockInitialValues({
      oldCourseKey: oldCourse,
      oldArcadeKey: oldArcade,
      'profile.name': 'keep-profile',
    });
    final preferences = await SharedPreferences.getInstance();
    final owner = LearningOwner.account('legacy-outbox-user');
    final scope = LearningScope(courseId: 'en-fr', owner: owner);
    final auth = LearningAuthScope(owner: owner, generation: 0, ready: true);
    final persistence = _TrackingLearningPersistence(
      PreferencesLearningPersistence(
          preferences: SharedPreferences.getInstance),
    );
    final transport = _RecordingTransport();
    var tokenCounter = 0;
    final store = CourseLearningRepository(
      scope: scope,
      authGeneration: 0,
      currentAuth: () => auth,
      backendOwner: () => owner,
      persistence: persistence,
      transitions: LearningTransitionEngine(LearningRegistry.french()),
      clock: () => DateTime.utc(2026, 10, 15),
      newToken: () => (++tokenCounter).toRadixString(36).padLeft(22, '0'),
      random: Random(41),
      cloud: transport,
    );

    expect((await store.load()).pending, isEmpty);
    expect((await store.sync()).status, SupportedSyncStatus.synced);
    expect(transport.batches, isEmpty,
        reason: 'legacy pending data is not a supported typed event');
    expect(persistence.reads, isNot(contains(oldCourseKey)));
    expect(persistence.reads, isNot(contains(oldArcadeKey)));

    var committed = await store.load();
    committed = (await store.submit(store.prepare(
      state: committed,
      activityId: 'lesson:en-fr-u-y',
      action: StartLearningRun(options: RunOptions()),
    )))
        .state;
    await store.submit(store.prepare(
      state: committed,
      activityId: 'lesson:en-fr-u-y',
      action: ChooseSound(
        selectedSound: 'y',
        audioSource: AttemptAudioSource.pendingRecording,
      ),
    ));
    expect((await store.load()).pending, hasLength(1));
    final synced = await store.sync();
    expect(synced.status, SupportedSyncStatus.synced);
    final sentIds = transport.batches.expand((batch) => batch.map((e) => e.id));
    expect(sentIds, hasLength(1));
    expect(sentIds.single, startsWith('fr04.c0.'));
    expect(sentIds, isNot(contains('legacy-outbox-event-7')));
    expect(persistence.reads, isNot(contains(oldCourseKey)));
    expect(persistence.reads, isNot(contains(oldArcadeKey)));
    expect(persistence.writes, isNot(contains(oldCourseKey)));
    expect(persistence.writes, isNot(contains(oldArcadeKey)));
    expect(preferences.getString(oldCourseKey), oldCourse);
    expect(preferences.getString(oldArcadeKey), oldArcade);
    expect(preferences.getString('profile.name'), 'keep-profile');
  });

  test('201 committed events deliver in batches of at most 100', () async {
    final persistence = _MemoryPersistence();
    persistence.documents[scope.storageKey] = const LearningDocumentCodec()
        .encode(stateWith(List.generate(201, event)));
    final transport = _RecordingTransport();
    final store = repository(persistence, transport);
    final result = await store.sync();
    expect(transport.batches.map((b) => b.length).toList(), [100, 100, 1]);
    expect(result.status, SupportedSyncStatus.synced);
    expect(result.remainingEvents, 0);
    expect((await store.load()).pending, isEmpty);
  });

  test('failed send and acknowledgment retain stable pending ids', () async {
    final persistence = _MemoryPersistence();
    final pending = [event(1), event(2)];
    persistence.documents[scope.storageKey] =
        const LearningDocumentCodec().encode(stateWith(pending));
    final transport = _RecordingTransport()..failure = StateError('offline');
    final store = repository(persistence, transport);
    final failed = await store.sync();
    expect(failed.status, SupportedSyncStatus.pending);
    expect(failed.remainingEvents, 2);
    expect(
        (await store.load()).pending.map((e) => e.id), ['event-1', 'event-2']);
    transport.failure = null;
    final retry = await store.sync();
    expect(transport.batches.last.map((e) => e.id), ['event-1', 'event-2']);
    expect(retry.remainingEvents, 0);
  });

  test('cloud ack advances revision only and does not notify commit observers',
      () async {
    final persistence = _MemoryPersistence();
    persistence.documents[scope.storageKey] = const LearningDocumentCodec()
        .encode(stateWith([event(41)], revision: 7, commitOrdinal: 3));
    var notifications = 0;
    final transport = _RecordingTransport();
    final store =
        repository(persistence, transport, onCommitted: () => notifications++);
    final result = await store.sync();
    final acknowledged = await store.load();
    expect(result.status, SupportedSyncStatus.synced);
    expect(acknowledged.pending, isEmpty);
    expect(acknowledged.revision, 8);
    expect(acknowledged.commitOrdinal, 3);
    expect(acknowledged.history, isEmpty);
    expect(acknowledged.activities, isEmpty);
    expect(notifications, 0);
  });

  test('held send failure reports latest committed count through quarantine',
      () async {
    final persistence = _MemoryPersistence();
    final transport = _RecordingTransport()
      ..entered = Completer<void>()
      ..release = Completer<void>();
    final store = repository(persistence, transport);
    const activity = 'lesson:en-fr-u-y';
    final definition = LearningRegistry.french().require(activity);
    var state = await store.load();
    state = (await store.submit(store.prepare(
      state: state,
      activityId: activity,
      action: StartLearningRun(options: RunOptions()),
    )))
        .state;

    Future<CourseLearningState> answerAt(CourseLearningRepository writer,
        CourseLearningState current, int index) async {
      final item = definition.items[index];
      return (await writer.submit(writer.prepare(
        state: current,
        activityId: activity,
        action: ChooseSound(
          selectedSound: item.expectedChoice!,
          audioSource: AttemptAudioSource.pendingRecording,
        ),
      )))
          .state;
    }

    state = await answerAt(store, state, 0);
    final firstCommittedIds = state.pending.map((event) => event.id).toList();
    final writer = repository(persistence, transport);
    final syncing = store.sync();
    await transport.entered!.future;

    state = await writer.load();
    state = (await writer.submit(writer.prepare(
      state: state,
      activityId: activity,
      action: const AdvanceLesson(),
    )))
        .state;
    state = await answerAt(writer, state, 1);
    final latestCommittedIds = state.pending.map((event) => event.id).toList();
    expect(latestCommittedIds, hasLength(2));
    expect(latestCommittedIds.first, firstCommittedIds.single);

    state = (await writer.submit(writer.prepare(
      state: state,
      activityId: activity,
      action: const AdvanceLesson(),
    )))
        .state;
    final thirdItem = definition.items[2];
    final rejected = writer.prepare(
      state: state,
      activityId: activity,
      action: ChooseSound(
        selectedSound: thirdItem.expectedChoice!,
        audioSource: AttemptAudioSource.pendingRecording,
      ),
    );
    persistence
      ..failNextWrite = true
      ..failRestore = true;
    await expectLater(
      writer.submit(rejected),
      throwsA(isA<LearningSaveException>()),
    );
    expect(
        const LearningDocumentCodec()
            .decode(persistence.documents[scope.storageKey]!, scope)
            .pending,
        hasLength(3),
        reason: 'the failing platform write left an optimistic third event');

    transport
      ..failure = StateError('transport disconnected')
      ..release!.complete();
    final outcome = await syncing.then<Object?>(
      (result) => result,
      onError: (Object error, StackTrace _) => error,
    );
    if (outcome is! SupportedSyncResult) {
      persistence.failRestore = false;
      await store.retryLoad();
      expect(outcome, isA<SupportedSyncResult>(),
          reason: 'send failure must return its retained pending result');
    }
    final result = outcome as SupportedSyncResult;
    expect(result.status, SupportedSyncStatus.pending);
    expect(result.remainingEvents, 2,
        reason:
            'only the two committed events count; optimistic failed bytes do not');
    expect(transport.batches, hasLength(1),
        reason: 'the failed send does not advance to another batch');
    await expectLater(
        store.sync(), throwsA(isA<LearningUnavailableException>()));
    expect(transport.batches, hasLength(1),
        reason: 'no resend is allowed while the owner scope is quarantined');

    persistence.failRestore = false;
    final restored = await store.retryLoad();
    expect(restored.pending.map((event) => event.id), latestCommittedIds);
    transport.failure = null;
    final retried = await store.sync();
    expect(retried.status, SupportedSyncStatus.synced);
    expect(transport.batches.last.map((event) => event.id), latestCommittedIds);
  });

  test('acknowledgment failure rolls back and retries the same event id',
      () async {
    final persistence = _MemoryPersistence();
    final pending = [event(9)];
    persistence.documents[scope.storageKey] =
        const LearningDocumentCodec().encode(stateWith(pending));
    final transport = _RecordingTransport()
      ..onSend = () => persistence.failNextWrite = true;
    final store = repository(persistence, transport);
    final result = await store.sync();
    expect(result.status, SupportedSyncStatus.pending);
    expect(result.remainingEvents, 1);
    expect((await store.load()).pending.single.id, 'event-9');
    transport.onSend = null;
    final retry = await store.sync();
    expect(transport.batches.map((batch) => batch.single.id),
        ['event-9', 'event-9']);
    expect(retry.remainingEvents, 0);
  });

  test('held failed local candidate never reaches transport', () async {
    final persistence = _MemoryPersistence();
    final transport = _RecordingTransport();
    final store = repository(persistence, transport);
    final initial = await store.load();
    final started = await store.submit(store.prepare(
        state: initial,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions())));
    final answer = store.prepare(
        state: started.state,
        activityId: 'lesson:en-fr-u-y',
        action: ChooseSound(
            selectedSound: 'u',
            audioSource: AttemptAudioSource.pendingRecording));
    persistence
      ..holdNextWrite = true
      ..writeEntered = Completer<void>()
      ..writeGate = Completer<bool>();
    final failedWrite = store.submit(answer);
    await persistence.writeEntered!.future;
    final syncing = store.sync();
    persistence.writeGate!.complete(false);
    await expectLater(failedWrite, throwsA(isA<Exception>()));
    final result = await syncing;
    expect(transport.batches, isEmpty);
    expect(result.remainingEvents, 0);
  });

  test('same-scope activity committed during send survives acknowledgment',
      () async {
    final persistence = _MemoryPersistence();
    persistence.documents[scope.storageKey] =
        const LearningDocumentCodec().encode(stateWith([event(1)]));
    final transport = _RecordingTransport()
      ..entered = Completer<void>()
      ..release = Completer<void>();
    final store = repository(persistence, transport);
    final syncing = store.sync();
    await transport.entered!.future;
    // Simulate a second committed event using the exact same persisted document
    // image while the transport request is outstanding.
    const codec = LearningDocumentCodec();
    final current =
        codec.decode(persistence.documents[scope.storageKey]!, scope);
    persistence.documents[scope.storageKey] = codec.encode(stateWith(
        [...current.pending, event(2)],
        revision: current.revision + 1));
    transport.release!.complete();
    final result = await syncing;
    expect(result.remainingEvents, 1);
    expect((await store.load()).pending.map((e) => e.id), ['event-2']);
  });

  test(
      'failed ack rollback reports committed count and quarantines until repair',
      () async {
    final persistence = _MemoryPersistence();
    persistence.documents[scope.storageKey] =
        const LearningDocumentCodec().encode(stateWith([event(1)]));
    final transport = _RecordingTransport()
      ..entered = Completer<void>()
      ..release = Completer<void>();
    final store = repository(persistence, transport);
    final syncing = store.sync();
    await transport.entered!.future;

    // Model another valid committed event arriving while the cloud request is
    // outstanding. Ack must merge against this latest committed image.
    const codec = LearningDocumentCodec();
    final latest =
        codec.decode(persistence.documents[scope.storageKey]!, scope);
    persistence.documents[scope.storageKey] = codec.encode(stateWith(
        [...latest.pending, event(2)],
        revision: latest.revision + 1));
    persistence
      ..failNextWrite = true
      ..failRestore = true;
    transport.release!.complete();

    final result = await syncing;

    expect(result.status, SupportedSyncStatus.pending);
    expect(result.remainingEvents, 2);
    expect(persistence.documents[scope.storageKey], isNotNull);
    await expectLater(
        store.load(), throwsA(isA<LearningUnavailableException>()));
    final callsAfterFailure = transport.batches.length;
    await expectLater(
        store.sync(), throwsA(isA<LearningUnavailableException>()));
    expect(transport.batches, hasLength(callsAfterFailure));

    persistence.failRestore = false;
    final repaired = await store.retryLoad();
    expect(repaired.pending.map((e) => e.id), ['event-1', 'event-2']);
    transport
      ..entered = null
      ..release = null;
    final retry = await store.sync();
    expect(transport.batches.last.map((e) => e.id), ['event-1', 'event-2']);
    expect(retry.status, SupportedSyncStatus.synced);
    expect(retry.remainingEvents, 0);
  });

  test('sync coalesces same scope but isolates guest and another account',
      () async {
    final persistence = _MemoryPersistence();
    persistence.documents[scope.storageKey] =
        const LearningDocumentCodec().encode(stateWith([event(10)]));
    final otherOwner = LearningOwner.account('another-user');
    final otherScope = LearningScope(courseId: 'en-fr', owner: otherOwner);
    final otherPersistence = _MemoryPersistence();
    otherPersistence.documents[otherScope.storageKey] =
        const LearningDocumentCodec().encode(CourseLearningState(
            scope: otherScope,
            revision: 0,
            commitOrdinal: 0,
            history: const [],
            activities: const {},
            mistakes: const {},
            summaries: const {},
            completions: const [],
            bestScores: const {},
            pending: [
          SupportedCloudEvent(
              id: 'other-event',
              userId: 'another-user',
              courseId: 'en-fr',
              payload: CloudAnswer(
                  sound: 'u',
                  skill: LearningSkill.listening,
                  correct: true,
                  activity: 'lesson:en-fr-u-y'))
        ]));
    final transport = _RecordingTransport()
      ..entered = Completer<void>()
      ..release = Completer<void>();
    final first = repository(persistence, transport);
    final peer = repository(persistence, transport);
    final firstSync = first.sync();
    await transport.entered!.future;
    final peerSync = peer.sync();
    final other = CourseLearningRepository(
        scope: otherScope,
        authGeneration: 0,
        currentAuth: () =>
            LearningAuthScope(owner: otherOwner, generation: 0, ready: true),
        backendOwner: () => otherOwner,
        persistence: otherPersistence,
        transitions: LearningTransitionEngine(LearningRegistry.french()),
        clock: () => DateTime.utc(2026),
        newToken: () => 'AAAAAAAAAAAAAAAAAAAAAA',
        random: Random(2),
        cloud: transport);
    final otherSync = other.sync();
    final guest =
        LearningScope(courseId: 'en-fr', owner: LearningOwner.guest());
    final guestStore = CourseLearningRepository(
        scope: guest,
        authGeneration: 0,
        currentAuth: () =>
            LearningAuthScope(owner: guest.owner, generation: 0, ready: true),
        backendOwner: LearningOwner.guest,
        persistence: _MemoryPersistence(),
        transitions: LearningTransitionEngine(LearningRegistry.french()),
        clock: () => DateTime.utc(2026),
        newToken: () => 'AAAAAAAAAAAAAAAAAAAAAA',
        random: Random(3),
        cloud: transport);
    expect((await guestStore.sync()).status, SupportedSyncStatus.guest);
    await Future<void>.delayed(Duration.zero);
    expect(transport.batches, hasLength(2));
    expect(transport.batches.map((batch) => batch.single.id),
        containsAll(['event-10', 'other-event']));
    transport.release!.complete();
    await Future.wait([firstSync, peerSync, otherSync]);
  });

  test('auth change prevents later batches and acknowledgment', () async {
    final persistence = _MemoryPersistence();
    persistence.documents[scope.storageKey] = const LearningDocumentCodec()
        .encode(stateWith(List.generate(201, event)));
    final transport = _RecordingTransport()
      ..entered = Completer<void>()
      ..release = Completer<void>();
    final store = repository(persistence, transport);
    final syncing = store.sync();
    await transport.entered!.future;
    authOwner = LearningOwner.account('other');
    generation++;
    backend = authOwner;
    transport.release!.complete();
    final result = await syncing;
    expect(transport.batches, hasLength(1));
    expect(result.status, SupportedSyncStatus.ownerChanged);
    expect(result.remainingEvents, 201);
    expect(
        (const LearningDocumentCodec()
                .decode(persistence.documents[scope.storageKey]!, scope))
            .pending,
        hasLength(201));
  });

  test('A to B to A during send cannot revive the captured generation',
      () async {
    generation = 20;
    authOwner = owner;
    backend = owner;
    final persistence = _MemoryPersistence();
    persistence.documents[scope.storageKey] =
        const LearningDocumentCodec().encode(stateWith([event(3)]));
    final transport = _RecordingTransport()
      ..entered = Completer<void>()
      ..release = Completer<void>();
    final store = repository(persistence, transport);
    final syncing = store.sync();
    await transport.entered!.future;
    generation++;
    authOwner = LearningOwner.account('other');
    generation++;
    authOwner = owner;
    backend = owner;
    transport.release!.complete();
    final result = await syncing;
    expect(result.status, SupportedSyncStatus.ownerChanged);
    expect(result.remainingEvents, 1);
    expect((await store.load()).pending.single.id, 'event-3');
  });

  test('legacy RPC adapter sends exact event wire payload', () async {
    final received = <Map<String, dynamic>>[];
    final client =
        SupabaseClient('https://course.example.invalid', 'public-test-key',
            httpClient: MockClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/record_course_events');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.keys, ['events']);
      received.addAll((body['events'] as List).cast<Map<String, dynamic>>());
      return http.Response('', 204, request: request);
    }));
    addTearDown(client.dispose);
    await SupabaseLearningCloudTransport(client).send([event(7)]);
    expect(received.single, {
      'id': 'event-7',
      'user_id': 'sync-user',
      'course_id': 'en-fr',
      'kind': 'answer',
      'sound': 'u',
      'skill': 'listening',
      'correct': true,
      'activity': 'lesson:en-fr-u-y',
    });
  });
}
