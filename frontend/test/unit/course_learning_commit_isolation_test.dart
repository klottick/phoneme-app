import 'dart:async';
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
