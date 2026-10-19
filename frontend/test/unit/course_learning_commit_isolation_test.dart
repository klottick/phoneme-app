import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_sync.dart';
import 'package:linguist/src/core/course/course_learning_transaction.dart'
    show
        LearningDocumentEnvelope,
        LearningDocumentFamily,
        LearningProfileAdapter,
        LearningTransactionCoordinator,
        LearningTransactionKernel,
        LearningTransactionTransition;
import 'package:linguist/src/core/course/learning_storage_types.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../support/course_learning_fixtures.dart';
import '../support/course_learning_persistence_fakes.dart';

class _HeldPreferences extends InMemorySharedPreferencesStore {
  _HeldPreferences() : super.withData({});
  Completer<void>? entered;
  Completer<bool>? gate;
  bool holding = false;
  void begin() {
    holding = true;
    entered = Completer<void>();
    gate = Completer<bool>();
  }

  void release(bool accepted) {
    if (!gate!.isCompleted) gate!.complete(accepted);
    holding = false;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (holding) {
      entered!.complete();
      if (!await gate!.future) return false;
    }
    return super.setValue(valueType, key, value);
  }
}

class _NoopCloud implements LearningCloudTransport {
  @override
  Future<void> send(List<SupportedCloudEvent> events) async {}
}

void main() {
  test('typed coordinator replays an exact latest command without writing',
      () async {
    final persistence = FakeLearningPersistence();
    final adapter = _TransactionTestAdapter();
    final coordinator = _testCoordinator(adapter, persistence);
    final command = _TransactionTestCommand(
        scope: adapter.scope,
        authGeneration: 3,
        token: 'same-token',
        fingerprint: 'canonical-one',
        activityId: 'activity',
        expected: const LearningCursorPosition(
            generation: 0, sequence: 0, revision: 0),
        start: true);

    final first = await coordinator.submit(command);
    final writes = persistence.writeCount;
    final duplicate = await coordinator.submit(command);

    expect(first.wasDuplicate, isFalse);
    expect(duplicate.wasDuplicate, isTrue);
    expect(duplicate.revision, first.revision);
    expect(duplicate.commitOrdinal, first.commitOrdinal);
    expect(persistence.writeCount, writes);
  });

  test(
      'typed coordinator rejects latest-token fingerprint and cursor conflicts',
      () async {
    final persistence = FakeLearningPersistence();
    final adapter = _TransactionTestAdapter();
    final coordinator = _testCoordinator(adapter, persistence);
    final start = _transactionCommand(adapter);
    await coordinator.submit(start);
    final writes = persistence.writeCount;

    await expectLater(
        coordinator.submit(
            _transactionCommand(adapter, fingerprint: 'changed-fingerprint')),
        throwsA(isA<LearningInvalidCommandException>()));
    await expectLater(
        coordinator.submit(_TransactionTestCommand(
            scope: adapter.scope,
            authGeneration: 3,
            token: 'different-token',
            fingerprint: 'different-command',
            activityId: 'activity',
            expected: const LearningCursorPosition(
                generation: 0, sequence: 0, revision: 0),
            start: true)),
        throwsA(isA<LearningConflictException>()));
    expect(persistence.writeCount, writes);
  });

  test(
      'typed coordinator fences stale command generation before duplicate lookup',
      () async {
    final persistence = FakeLearningPersistence();
    final adapter = _TransactionTestAdapter();
    final coordinator = _testCoordinator(adapter, persistence);
    await coordinator.submit(_transactionCommand(adapter));
    final writes = persistence.writeCount;
    await expectLater(
        coordinator.submit(_transactionCommand(adapter, authGeneration: 4)),
        throwsA(isA<LearningOwnerChangedException>()));
    expect(persistence.writeCount, writes);
  });

  test(
      'typed coordinator uses retained receipt fingerprint and active generation',
      () async {
    final persistence = FakeLearningPersistence();
    final adapter = _TransactionTestAdapter();
    final coordinator = _testCoordinator(adapter, persistence);
    await coordinator.submit(_transactionCommand(adapter));
    adapter.retained = const LearningRetainedReceiptIdentity(
        activityId: 'activity',
        token: 'retained-token',
        canonicalCommand: 'retained-fingerprint',
        generation: 1,
        sequence: 2);
    final retained = _transactionCommand(adapter,
        token: 'retained-token',
        fingerprint: 'retained-fingerprint',
        expected: const LearningCursorPosition(
            generation: 1, sequence: 1, revision: 1),
        start: false);
    final writes = persistence.writeCount;
    expect((await coordinator.submit(retained)).wasDuplicate, isTrue);
    expect(persistence.writeCount, writes);
    await expectLater(
        coordinator.submit(_transactionCommand(adapter,
            token: 'retained-token',
            fingerprint: 'not-retained-fingerprint',
            expected: const LearningCursorPosition(
                generation: 1, sequence: 1, revision: 1),
            start: false)),
        throwsA(isA<LearningInvalidCommandException>()));
  });

  test('typed coordinator acknowledgement revises without ordinal or observer',
      () async {
    final persistence = FakeLearningPersistence();
    final adapter = _TransactionTestAdapter();
    var notifications = 0;
    final coordinator = _testCoordinator(adapter, persistence,
        onCommitted: () => notifications++);
    final command = _transactionCommand(adapter);
    final committed = await coordinator.submit(command);
    expect(notifications, 1);
    final current = await coordinator.load();
    final writes = persistence.writeCount;
    await coordinator.acknowledge(
        const {'receipt'},
        (
                {required current,
                required receiptIds,
                required nextRevision,
                required currentCommitOrdinal}) =>
            current);
    expect(persistence.writeCount, writes);
    await coordinator.acknowledge(
        const {'receipt'},
        (
                {required current,
                required receiptIds,
                required nextRevision,
                required currentCommitOrdinal}) =>
            LearningDocumentEnvelope(
                scope: current.scope,
                family: current.family,
                revision: nextRevision,
                commitOrdinal: currentCommitOrdinal,
                payload: current.payload));
    final acknowledged = await coordinator.load();
    expect(acknowledged.revision, current.revision + 1);
    expect(acknowledged.commitOrdinal, committed.commitOrdinal);
    expect(notifications, 1);
  });

  test('acknowledgement without removals at max revision remains a no-op',
      () async {
    final persistence = FakeLearningPersistence();
    final adapter = _TransactionTestAdapter();
    const max = 9007199254740991;
    persistence.platform[adapter.storageKey] = jsonEncode({
      'revision': max,
      'ordinal': max,
      'generation': 1,
      'sequence': 1,
      'cursorRevision': 1,
      'receipt': {
        'activityId': 'activity',
        'token': 'stored-token',
        'fingerprint': 'stored-fingerprint',
        'beforeGeneration': 0,
        'beforeSequence': 0,
        'beforeRevision': 0
      }
    });
    persistence.cache.addAll(persistence.platform);
    var notifications = 0;
    final coordinator = _testCoordinator(adapter, persistence,
        onCommitted: () => notifications++);
    final beforeWrites = persistence.writeCount;
    await coordinator.acknowledge(
        const {'not-present'},
        (
                {required current,
                required receiptIds,
                required nextRevision,
                required currentCommitOrdinal}) =>
            current);
    expect(persistence.writeCount, beforeWrites);
    expect(notifications, 0);
    final loaded = await coordinator.load();
    expect(loaded.revision, max);
    expect(loaded.commitOrdinal, max);
  });

  test('typed coordinators serialize different keys on the process tail',
      () async {
    final firstPersistence = FakeLearningPersistence();
    final secondPersistence = FakeLearningPersistence();
    final firstAdapter = _TransactionTestAdapter();
    final secondAdapter = _TransactionTestAdapter()
      ..storageKey = 'other.test.key';
    final first = _testCoordinator(firstAdapter, firstPersistence);
    final second = _testCoordinator(secondAdapter, secondPersistence);
    firstPersistence.holdNextWrite();
    final writing = first.submit(_transactionCommand(firstAdapter));
    await firstPersistence.writeEntered;
    var secondFinished = false;
    final reading = second.load().then((value) {
      secondFinished = true;
      return value;
    });
    try {
      await Future<void>.delayed(Duration.zero);
      expect(secondFinished, isFalse);
    } finally {
      firstPersistence.releaseWrite(persist: true);
    }
    await writing;
    await reading;
    expect(secondFinished, isTrue);
  });

  test('real v2 repository and typed profile share one process tail', () async {
    final v2Persistence = FakeLearningPersistence();
    final owner = LearningOwner.account('v2-global-tail');
    final scope = LearningScope(courseId: 'en-fr', owner: owner);
    final auth = LearningAuthScope(owner: owner, generation: 0, ready: true);
    final repository = CourseLearningRepository(
        scope: scope,
        authGeneration: 0,
        currentAuth: () => auth,
        backendOwner: () => owner,
        persistence: v2Persistence,
        transitions: LearningTransitionEngine(LearningRegistry.french()),
        clock: () => fixedTime,
        newToken: () => tokenFor(12),
        random: Random(12));
    final initial = await repository.load();
    final command = repository.prepare(
        state: initial,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()));
    final comparisonPersistence = FakeLearningPersistence();
    final comparison = _testCoordinator(
        _TransactionTestAdapter()..storageKey = 'comparison.global-tail.key',
        comparisonPersistence);
    v2Persistence.holdNextWrite();
    final saving = repository.submit(command);
    await v2Persistence.writeEntered;
    var comparisonFinished = false;
    final loading = comparison.load().then((document) {
      comparisonFinished = true;
      return document;
    });
    try {
      await Future<void>.delayed(Duration.zero);
      expect(comparisonFinished, isFalse);
    } finally {
      v2Persistence.releaseWrite(persist: true);
    }
    await saving;
    await loading;
    expect(comparisonFinished, isTrue);
  });

  test(
      'held write acknowledges captured scope while queued stale command is fenced',
      () async {
    final persistence = FakeLearningPersistence();
    final adapter = _TransactionTestAdapter();
    final ownerA = adapter.owner;
    var auth = LearningAuthScope(owner: ownerA, generation: 3, ready: true);
    final coordinator =
        _testCoordinator(adapter, persistence, currentAuth: () => auth);
    final command = _transactionCommand(adapter);
    persistence.holdNextWrite();
    final saving = coordinator.submit(command);
    await persistence.writeEntered;
    late Future<_TransactionTestResult> queued;
    try {
      auth = LearningAuthScope(
          owner: LearningOwner.account('B'), generation: 4, ready: true);
      auth = LearningAuthScope(owner: ownerA, generation: 5, ready: true);
      queued = coordinator.submit(command);
    } finally {
      persistence.releaseWrite(persist: true);
    }
    await saving;
    await expectLater(queued, throwsA(isA<LearningOwnerChangedException>()));
    expect(persistence.platform[adapter.storageKey], isNotNull);
    expect(persistence.writeCount, 1);
  });

  test('typed coordinator rejects a transition envelope from another family',
      () async {
    final persistence = FakeLearningPersistence();
    final adapter = _TransactionTestAdapter()..wrongFamily = true;
    final coordinator = _testCoordinator(adapter, persistence);
    await expectLater(coordinator.submit(_transactionCommand(adapter)),
        throwsA(isA<LearningInvalidCommandException>()));
    expect(persistence.writeCount, 0);
  });

  test('typed coordinator validates encoded document before writing', () async {
    final persistence = FakeLearningPersistence();
    final adapter = _TransactionTestAdapter()..wrongDecodedFamily = true;
    final coordinator = _testCoordinator(adapter, persistence);
    await expectLater(coordinator.submit(_transactionCommand(adapter)),
        throwsA(isA<LearningInvalidCommandException>()));
    expect(persistence.writeCount, 0);
  });

  test('typed coordinator validates initial envelope identity and zero headers',
      () async {
    final persistence = FakeLearningPersistence();
    final adapter = _TransactionTestAdapter()..wrongEmptyFamily = true;
    final coordinator = _testCoordinator(adapter, persistence);
    await expectLater(
        coordinator.load(), throwsA(isA<LearningInvalidCommandException>()));
    expect(persistence.writeCount, 0);
  });

  test('distinct typed profile signatures stay isolated by family and key',
      () async {
    final v2Persistence = FakeLearningPersistence();
    final comparisonPersistence = FakeLearningPersistence();
    final v2Adapter = _TransactionTestAdapter();
    final comparisonAdapter = _ComparisonTestAdapter();
    final v2 = _testCoordinator(v2Adapter, v2Persistence);
    final comparison = LearningTransactionCoordinator<int, String,
            _ComparisonTestCommand, _ComparisonTestResult>(
        adapter: comparisonAdapter,
        persistence: comparisonPersistence,
        authGeneration: 3,
        currentAuth: () => LearningAuthScope(
            owner: comparisonAdapter.owner, generation: 3, ready: true),
        backendOwner: () => comparisonAdapter.owner,
        clock: () => fixedTime);
    final v2Command = _transactionCommand(v2Adapter);
    const comparisonCommand = _ComparisonTestCommand(
        scope: 17,
        authGeneration: 3,
        token: 'same-token',
        fingerprint: 'canonical-one',
        activityId: 'activity',
        expected:
            LearningCursorPosition(generation: 0, sequence: 0, revision: 0),
        start: true);
    expect(v2Adapter.commandScope(v2Command), v2Adapter.scope);
    expect(v2Adapter.commandAuthGeneration(v2Command), 3);
    expect(comparisonAdapter.commandScope(comparisonCommand), 17);
    expect(comparisonAdapter.commandAuthGeneration(comparisonCommand), 3);

    Future<_TransactionTestResult> submitV2(_TransactionTestCommand command) =>
        v2.submit(command);
    Future<_ComparisonTestResult> submitComparison(
            _ComparisonTestCommand command) =>
        comparison.submit(command);
    final firstV2 = await submitV2(v2Command);
    final firstComparison = await submitComparison(comparisonCommand);
    expect(firstV2.wasDuplicate, isFalse);
    expect(firstComparison.wasDuplicate, isFalse);
    expect(v2Adapter.storageKey, isNot(comparisonAdapter.storageKey));
    expect(v2Adapter.family, isNot(comparisonAdapter.family));
  });

  test(
      'typed coordinator quarantines failed rollback by full key and counts synchronously',
      () async {
    final persistence = FakeLearningPersistence();
    final adapter = _TransactionTestAdapter();
    final coordinator = _testCoordinator(adapter, persistence);
    await coordinator.submit(_transactionCommand(adapter));
    final committedRaw = persistence.platform[adapter.storageKey]!;
    final readsBeforeCount = persistence.reads.length;
    final writesBeforeFailure = persistence.writeCount;
    persistence.restoreFailure = StateError('restore failed');
    persistence.holdNextWrite();
    final failed = coordinator.submit(_transactionCommand(adapter,
        token: 'next-token',
        fingerprint: 'next-fingerprint',
        expected: const LearningCursorPosition(
            generation: 1, sequence: 1, revision: 1),
        start: false));
    await persistence.writeEntered;
    persistence.releaseWrite(persist: false);
    await expectLater(failed, throwsA(isA<LearningSaveException>()));
    expect(LearningTransactionKernel.instance.isBlocked(adapter.storageKey),
        isTrue);
    expect(LearningTransactionKernel.instance.knownBytes(adapter.storageKey),
        committedRaw);
    final count = coordinator.knownCommittedCount(
        (payload) => payload.cursor.sequence,
        fallback: const _TransactionTestPayload(
            cursor:
                LearningCursorPosition(generation: 9, sequence: 9, revision: 9),
            receipt: null));
    expect(count, 1);
    expect(persistence.reads.length, readsBeforeCount + 1,
        reason: 'only failure rollback verification may read storage');
    expect(persistence.writeCount, writesBeforeFailure + 1);
    persistence.restoreFailure = null;
    expect((await coordinator.retryLoad()).revision, 1);
    expect(LearningTransactionKernel.instance.isBlocked(adapter.storageKey),
        isFalse);
  });

  test('old namespaces are neither read nor changed', () async {
    final persistence = FakeLearningPersistence();
    persistence.cache['course.v1.en-fr'] = 'old-progress';
    persistence.cache['arcade.v1.sound'] = 'old-board';
    persistence.platform.addAll(persistence.cache);
    final scope =
        LearningScope(courseId: 'en-fr', owner: LearningOwner.guest());
    final store = CourseLearningRepository(
        scope: scope,
        authGeneration: 0,
        currentAuth: () =>
            LearningAuthScope(owner: scope.owner, generation: 0, ready: true),
        backendOwner: () => scope.owner,
        persistence: persistence,
        transitions: LearningTransitionEngine(LearningRegistry.french()),
        clock: () => fixedTime,
        newToken: () => tokenFor(1),
        random: Random(1));
    await store.load();
    expect(persistence.reads, [scope.storageKey]);
    expect(persistence.platform['course.v1.en-fr'], 'old-progress');
    expect(persistence.platform['arcade.v1.sound'], 'old-board');
  });

  test('real preferences optimistic cache is hidden from peer reads and sync',
      () async {
    final platform = _HeldPreferences();
    SharedPreferencesStorePlatform.instance = platform;
    SharedPreferences.resetStatic();
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final owner = LearningOwner.account('account/a');
    final scope = LearningScope(courseId: 'en-fr', owner: owner);
    final persistence = PreferencesLearningPersistence();
    var token = 0;
    final auth = LearningAuthScope(owner: owner, generation: 0, ready: true);
    CourseLearningRepository make() => CourseLearningRepository(
        scope: scope,
        authGeneration: 0,
        currentAuth: () => auth,
        backendOwner: () => owner,
        persistence: persistence,
        transitions: LearningTransitionEngine(LearningRegistry.french()),
        clock: () => fixedTime,
        newToken: () => tokenFor(++token),
        random: Random(1),
        cloud: _NoopCloud());
    final writer = make();
    final empty = await writer.load();
    final start = writer.prepare(
        state: empty,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()));
    final started = await writer.submit(start);
    final answer = writer.prepare(
        state: started.state,
        activityId: 'lesson:en-fr-u-y',
        action: ChooseSound(
            selectedSound: 'u',
            audioSource: AttemptAudioSource.pendingRecording));
    final key = scope.storageKey;
    final prefs = await SharedPreferences.getInstance();
    final committedImage = prefs.getString(key);
    platform.begin();
    final saving = writer.submit(answer);
    await platform.entered!.future;
    expect(prefs.getString(key), isNot(committedImage),
        reason: 'plugin cache optimistically contains candidate');
    final peer = make();
    final peerRead = peer.load();
    final peerSync = peer.sync();
    platform.release(false);
    await expectLater(saving, throwsA(isA<LearningSaveException>()));
    expect((await peerRead).history, isEmpty);
    expect((await peerSync).remainingEvents, 0);
    expect(prefs.getString(key), committedImage);
  });

  test('separate real preferences adapters merge preloaded peer commits',
      () async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final owner = LearningOwner.account('independent-adapters');
    final scope = LearningScope(courseId: 'en-fr', owner: owner);
    final auth = LearningAuthScope(owner: owner, generation: 0, ready: true);
    var token = 0;
    CourseLearningRepository make(LearningPersistence persistence) =>
        CourseLearningRepository(
            scope: scope,
            authGeneration: 0,
            currentAuth: () => auth,
            backendOwner: () => owner,
            persistence: persistence,
            transitions: LearningTransitionEngine(LearningRegistry.french()),
            clock: () => fixedTime,
            newToken: () => tokenFor(++token),
            random: Random(3));
    final firstAdapter = PreferencesLearningPersistence();
    final peerAdapter = PreferencesLearningPersistence();
    final first = make(firstAdapter);
    final peer = make(peerAdapter);
    final firstInitial = await first.load();
    final peerInitial = await peer.load();
    final peerStart = peer.prepare(
        state: peerInitial,
        activityId: 'lesson:en-fr-vowels',
        action: StartLearningRun(options: RunOptions()));
    final started = await first.submit(first.prepare(
        state: firstInitial,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions())));
    final expected = LearningTransitionEngine(LearningRegistry.french())
        .registry
        .require('lesson:en-fr-u-y')
        .items
        .first
        .expectedChoice!;
    await first.submit(first.prepare(
        state: started.state,
        activityId: 'lesson:en-fr-u-y',
        action: ChooseSound(
            selectedSound: expected == 'u' ? 'y' : 'u',
            audioSource: AttemptAudioSource.pendingRecording)));
    final observed = await peer.load();
    expect(observed.activities.containsKey('lesson:en-fr-u-y'), isTrue);
    expect(observed.history, hasLength(1));
    final merged = await peer.submit(peerStart);
    expect(merged.state.activities.keys,
        containsAll(['lesson:en-fr-u-y', 'lesson:en-fr-vowels']));
    expect(merged.state.history, hasLength(1));
  });

  test('backend owner mismatch and queued A to B to A generation change reject',
      () async {
    final persistence = FakeLearningPersistence();
    final owner = LearningOwner.account('A');
    var backend = LearningOwner.account('B');
    var auth = LearningAuthScope(owner: owner, generation: 0, ready: true);
    final scope = LearningScope(courseId: 'en-fr', owner: owner);
    final repo = CourseLearningRepository(
        scope: scope,
        authGeneration: 0,
        currentAuth: () => auth,
        backendOwner: () => backend,
        persistence: persistence,
        transitions: LearningTransitionEngine(LearningRegistry.french()),
        clock: () => fixedTime,
        newToken: () => tokenFor(4),
        random: Random(2));
    await expectLater(
        () => repo.prepare(
            state: CourseLearningState.empty(scope),
            activityId: 'lesson:en-fr-u-y',
            action: StartLearningRun(options: RunOptions())),
        throwsA(isA<LearningOwnerChangedException>()));
    expect(persistence.writeCount, 0,
        reason: 'backend auth is checked before provider lag catches up');

    backend = owner;
    final command = repo.prepare(
        state: await repo.load(),
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()));
    persistence.holdNextWrite();
    final saving = repo.submit(command);
    await persistence.writeEntered;
    auth = LearningAuthScope(
        owner: LearningOwner.account('B'), generation: 1, ready: true);
    backend = LearningOwner.account('B');
    auth = LearningAuthScope(
        owner: LearningOwner.account('A'), generation: 2, ready: true);
    backend = owner;
    final queued = repo.submit(command);
    persistence.releaseWrite(persist: true);
    await saving; // captured-scope in-flight success stays in owner A's key
    await expectLater(queued, throwsA(isA<LearningOwnerChangedException>()));
    expect(persistence.platform[scope.storageKey], isNotNull);
    expect(persistence.writeCount, 1);
  });

  test('supported sync coalesces read/send attempts per scope', () async {
    final scope =
        LearningScope(courseId: 'en-fr', owner: LearningOwner.account('sync'));
    final pending = Completer<List<SupportedCloudEvent>>();
    var reads = 0;
    final sync = SupportedProgressSync(
        scope: scope,
        authGeneration: 5,
        transport: _NoopCloud(),
        readPending: () {
          reads++;
          return pending.future;
        },
        acknowledge: (_) async {},
        isCurrent: () => true);
    final one = sync.run();
    final two = sync.run();
    expect(identical(one, two), isTrue);
    expect(reads, 1);
    pending.complete(const []);
    expect((await one).status, SupportedSyncStatus.pending);
  });
}

LearningTransactionCoordinator<String, _TransactionTestPayload,
    _TransactionTestCommand, _TransactionTestResult> _testCoordinator(
        _TransactionTestAdapter adapter, LearningPersistence persistence,
        {void Function()? onCommitted,
        LearningAuthScope Function()? currentAuth}) =>
    LearningTransactionCoordinator(
        adapter: adapter,
        persistence: persistence,
        authGeneration: 3,
        currentAuth: currentAuth ??
            () => LearningAuthScope(
                owner: adapter.owner, generation: 3, ready: true),
        backendOwner: () => adapter.owner,
        clock: () => fixedTime,
        onCommitted: onCommitted);

_TransactionTestCommand _transactionCommand(_TransactionTestAdapter adapter,
        {String token = 'same-token',
        String fingerprint = 'canonical-one',
        int authGeneration = 3,
        LearningCursorPosition expected = const LearningCursorPosition(
            generation: 0, sequence: 0, revision: 0),
        bool start = true}) =>
    _TransactionTestCommand(
        scope: adapter.scope,
        authGeneration: authGeneration,
        token: token,
        fingerprint: fingerprint,
        activityId: 'activity',
        expected: expected,
        start: start);

final class _TransactionTestCommand {
  const _TransactionTestCommand(
      {required this.scope,
      required this.authGeneration,
      required this.token,
      required this.fingerprint,
      required this.activityId,
      required this.expected,
      required this.start});
  final String scope;
  final int authGeneration;
  final String token;
  final String fingerprint;
  final String activityId;
  final LearningCursorPosition expected;
  final bool start;
}

final class _TransactionTestPayload {
  const _TransactionTestPayload({required this.cursor, required this.receipt});
  final LearningCursorPosition cursor;
  final LearningReceiptIdentity? receipt;
}

final class _TransactionTestResult {
  const _TransactionTestResult(
      {required this.wasDuplicate,
      required this.revision,
      required this.commitOrdinal});
  final bool wasDuplicate;
  final int revision;
  final int commitOrdinal;
}

final class _TransactionTestAdapter
    implements
        LearningProfileAdapter<String, _TransactionTestPayload,
            _TransactionTestCommand, _TransactionTestResult> {
  @override
  String storageKey = 'test.transaction.key';
  bool wrongFamily = false;
  bool wrongEmptyFamily = false;
  bool wrongDecodedFamily = false;
  LearningRetainedReceiptIdentity? retained;
  @override
  String get scope => 'test-scope';
  @override
  LearningOwner get owner => LearningOwner.guest();
  @override
  String get courseId => 'test-course';
  @override
  LearningDocumentFamily get family => const LearningDocumentFamily('test');
  LearningDocumentEnvelope<String, _TransactionTestPayload> _envelope(
          int revision, int ordinal, _TransactionTestPayload payload) =>
      LearningDocumentEnvelope(
          scope: scope,
          family: family,
          revision: revision,
          commitOrdinal: ordinal,
          payload: payload);

  @override
  LearningDocumentEnvelope<String, _TransactionTestPayload> emptyDocument() =>
      LearningDocumentEnvelope(
          scope: scope,
          family: wrongEmptyFamily
              ? const LearningDocumentFamily('wrong-empty')
              : family,
          revision: 0,
          commitOrdinal: 0,
          payload: const _TransactionTestPayload(
              cursor: LearningCursorPosition(
                  generation: 0, sequence: 0, revision: 0),
              receipt: null));

  @override
  LearningDocumentEnvelope<String, _TransactionTestPayload> decodeDocument(
      String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final cursor = LearningCursorPosition(
        generation: map['generation'] as int,
        sequence: map['sequence'] as int,
        revision: map['cursorRevision'] as int);
    final receiptMap = map['receipt'] as Map<String, dynamic>?;
    final receipt = receiptMap == null
        ? null
        : LearningReceiptIdentity(
            activityId: receiptMap['activityId'] as String,
            token: receiptMap['token'] as String,
            canonicalCommand: receiptMap['fingerprint'] as String,
            before: LearningCursorPosition(
                generation: receiptMap['beforeGeneration'] as int,
                sequence: receiptMap['beforeSequence'] as int,
                revision: receiptMap['beforeRevision'] as int),
            after: cursor,
            commitOrdinal: map['ordinal'] as int);
    final document = _envelope(map['revision'] as int, map['ordinal'] as int,
        _TransactionTestPayload(cursor: cursor, receipt: receipt));
    return wrongDecodedFamily
        ? LearningDocumentEnvelope(
            scope: document.scope,
            family: const LearningDocumentFamily('wrong-decoded'),
            revision: document.revision,
            commitOrdinal: document.commitOrdinal,
            payload: document.payload)
        : document;
  }

  @override
  String encodePayload(
      LearningDocumentEnvelope<String, _TransactionTestPayload> document) {
    final receipt = document.payload.receipt;
    return jsonEncode({
      'revision': document.revision,
      'ordinal': document.commitOrdinal,
      'generation': document.payload.cursor.generation,
      'sequence': document.payload.cursor.sequence,
      'cursorRevision': document.payload.cursor.revision,
      'receipt': receipt == null
          ? null
          : {
              'activityId': receipt.activityId,
              'token': receipt.token,
              'fingerprint': receipt.canonicalCommand,
              'beforeGeneration': receipt.before.generation,
              'beforeSequence': receipt.before.sequence,
              'beforeRevision': receipt.before.revision
            }
    });
  }

  @override
  String commandScope(_TransactionTestCommand command) => command.scope;
  @override
  int commandAuthGeneration(_TransactionTestCommand command) =>
      command.authGeneration;
  @override
  String commandToken(_TransactionTestCommand command) => command.token;
  @override
  String commandFingerprint(_TransactionTestCommand command) =>
      command.fingerprint;
  @override
  String commandActivityId(_TransactionTestCommand command) =>
      command.activityId;
  @override
  LearningCursorPosition commandExpected(_TransactionTestCommand command) =>
      command.expected;
  @override
  LearningCursorPosition? currentCursor(
          _TransactionTestPayload payload, String activityId) =>
      payload.receipt?.activityId == activityId ? payload.cursor : null;
  @override
  LearningReceiptIdentity? latestReceipt(
          _TransactionTestPayload payload, String activityId) =>
      payload.receipt?.activityId == activityId ? payload.receipt : null;
  @override
  LearningRetainedReceiptIdentity? retainedReceipt(_TransactionTestPayload p,
          String activityId, LearningCursorPosition after, String token) =>
      retained?.activityId == activityId &&
              retained?.generation == after.generation &&
              retained?.sequence == after.sequence &&
              retained?.token == token
          ? retained
          : null;
  @override
  bool isStart(_TransactionTestCommand command) => command.start;
  @override
  LearningTransactionTransition<String, _TransactionTestPayload,
          _TransactionTestResult>
      evaluate(
          {required LearningDocumentEnvelope<String, _TransactionTestPayload>
              before,
          required _TransactionTestCommand command,
          required int nextRevision,
          required int nextCommitOrdinal,
          required DateTime committedAt}) {
    final after = LearningCursorPosition(
        generation: command.expected.generation + 1,
        sequence: command.expected.sequence + 1,
        revision: command.expected.revision + 1);
    final next = LearningDocumentEnvelope<String, _TransactionTestPayload>(
        scope: scope,
        family: wrongFamily ? const LearningDocumentFamily('wrong') : family,
        revision: nextRevision,
        commitOrdinal: nextCommitOrdinal,
        payload: _TransactionTestPayload(
            cursor: after,
            receipt: LearningReceiptIdentity(
                activityId: command.activityId,
                token: command.token,
                canonicalCommand: command.fingerprint,
                before: command.expected,
                after: after,
                commitOrdinal: nextCommitOrdinal)));
    return LearningTransactionTransition(
        nextDocument: next,
        result: _TransactionTestResult(
            wasDuplicate: false,
            revision: nextRevision,
            commitOrdinal: nextCommitOrdinal));
  }

  @override
  _TransactionTestResult duplicateResult(
          {required LearningDocumentEnvelope<String, _TransactionTestPayload>
              current,
          required _TransactionTestCommand command}) =>
      _TransactionTestResult(
          wasDuplicate: true,
          revision: current.revision,
          commitOrdinal: current.commitOrdinal);
}

final class _ComparisonTestCommand {
  const _ComparisonTestCommand(
      {required this.scope,
      required this.authGeneration,
      required this.token,
      required this.fingerprint,
      required this.activityId,
      required this.expected,
      required this.start});
  final int scope;
  final int authGeneration;
  final String token;
  final String fingerprint;
  final String activityId;
  final LearningCursorPosition expected;
  final bool start;
}

final class _ComparisonTestResult {
  const _ComparisonTestResult(this.revision, this.commitOrdinal,
      {this.wasDuplicate = false});
  final int revision;
  final int commitOrdinal;
  final bool wasDuplicate;
}

final class _ComparisonTestAdapter
    implements
        LearningProfileAdapter<int, String, _ComparisonTestCommand,
            _ComparisonTestResult> {
  @override
  int get scope => 17;
  @override
  LearningOwner get owner => LearningOwner.guest();
  @override
  String get courseId => 'en-fr';
  @override
  LearningDocumentFamily get family =>
      const LearningDocumentFamily('comparison');
  @override
  String get storageKey => 'comparison.test.key';
  @override
  LearningDocumentEnvelope<int, String> emptyDocument() =>
      const LearningDocumentEnvelope(
          scope: 17,
          family: LearningDocumentFamily('comparison'),
          revision: 0,
          commitOrdinal: 0,
          payload: 'empty');
  @override
  LearningDocumentEnvelope<int, String> decodeDocument(String raw) =>
      LearningDocumentEnvelope(
          scope: 17,
          family: family,
          revision: 1,
          commitOrdinal: 1,
          payload: raw);
  @override
  String encodePayload(LearningDocumentEnvelope<int, String> document) =>
      document.payload;
  @override
  int commandScope(_ComparisonTestCommand command) => command.scope;
  @override
  int commandAuthGeneration(_ComparisonTestCommand command) =>
      command.authGeneration;
  @override
  String commandToken(_ComparisonTestCommand command) => command.token;
  @override
  String commandFingerprint(_ComparisonTestCommand command) =>
      command.fingerprint;
  @override
  String commandActivityId(_ComparisonTestCommand command) =>
      command.activityId;
  @override
  LearningCursorPosition commandExpected(_ComparisonTestCommand command) =>
      command.expected;
  @override
  LearningCursorPosition? currentCursor(String payload, String activityId) =>
      null;
  @override
  LearningReceiptIdentity? latestReceipt(String payload, String activityId) =>
      null;
  @override
  LearningRetainedReceiptIdentity? retainedReceipt(String payload,
          String activityId, LearningCursorPosition after, String token) =>
      null;
  @override
  bool isStart(_ComparisonTestCommand command) => command.start;
  @override
  LearningTransactionTransition<int, String, _ComparisonTestResult> evaluate(
          {required LearningDocumentEnvelope<int, String> before,
          required _ComparisonTestCommand command,
          required int nextRevision,
          required int nextCommitOrdinal,
          required DateTime committedAt}) =>
      LearningTransactionTransition(
          nextDocument: LearningDocumentEnvelope(
              scope: scope,
              family: family,
              revision: nextRevision,
              commitOrdinal: nextCommitOrdinal,
              payload: command.fingerprint),
          result: _ComparisonTestResult(nextRevision, nextCommitOrdinal));
  @override
  _ComparisonTestResult duplicateResult(
          {required LearningDocumentEnvelope<int, String> current,
          required _ComparisonTestCommand command}) =>
      _ComparisonTestResult(current.revision, current.commitOrdinal,
          wasDuplicate: true);
}
