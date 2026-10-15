import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_sync.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import '../support/course_learning_fixtures.dart';
import '../support/course_learning_persistence_fakes.dart';

void main() {
  late FakeLearningPersistence persistence;
  late LearningOwner owner;
  late LearningAuthScope auth;
  late CourseLearningRepository store;
  late LearningTransitionEngine engine;
  var tokenCounter = 1;
  const activity = 'lesson:en-fr-u-y';

  CourseLearningRepository repository({int historyLimit = 2000}) =>
      CourseLearningRepository(
        scope: LearningScope(courseId: 'en-fr', owner: owner),
        authGeneration: auth.generation,
        currentAuth: () => auth,
        backendOwner: () => owner,
        persistence: persistence,
        transitions: engine,
        clock: () => fixedTime,
        newToken: () => tokenFor(tokenCounter++),
        random: Random(1),
        historyLimit: historyLimit,
      );

  setUp(() {
    persistence = FakeLearningPersistence();
    owner = LearningOwner.guest();
    auth = LearningAuthScope(owner: owner, generation: 0, ready: true);
    engine = LearningTransitionEngine(LearningRegistry.french());
    tokenCounter = 1;
    store = repository();
  });

  test('lost initial start acknowledgment returns same generation', () async {
    final command = store.prepare(
      state: await store.load(),
      activityId: activity,
      action: StartLearningRun(options: RunOptions()),
    );
    final saved = await store.submit(command);
    final retry = await store.submit(command);
    expect(retry.duplicate, isTrue);
    expect(retry.state.commitOrdinal, saved.state.commitOrdinal);
    expect(retry.slot.cursor.generation, 1);
  });

  test('same token payload retry is a no-op and returns current handle',
      () async {
    await store.submit(store.prepare(
        state: await store.load(),
        activityId: activity,
        action: StartLearningRun(options: RunOptions())));
    final command = store.prepare(
        state: await store.load(),
        activityId: activity,
        action: ChooseSound(
            selectedSound: 'u',
            audioSource: AttemptAudioSource.pendingRecording));
    final first = await store.submit(command);
    final duplicate = await store.submit(command);
    expect(duplicate.duplicate, isTrue);
    expect(duplicate.state.revision, first.state.revision);
    expect(duplicate.slot.cursor.generation, first.slot.cursor.generation);
    expect(duplicate.slot.cursor.sequence, first.slot.cursor.sequence);
    expect(duplicate.slot.cursor.revision, first.slot.cursor.revision);
  });

  test('different token at same next sequence conflicts', () async {
    final start = store.prepare(
        state: await store.load(),
        activityId: activity,
        action: StartLearningRun(options: RunOptions()));
    await store.submit(start);
    final answer = store.prepare(
        state: await store.load(),
        activityId: activity,
        action: ChooseSound(
            selectedSound: 'u',
            audioSource: AttemptAudioSource.pendingRecording));
    final competing = LearningCommand(
        scope: answer.scope,
        authGeneration: answer.authGeneration,
        activityId: answer.activityId,
        expected: answer.expected,
        token: tokenFor(99),
        submittedAt: answer.submittedAt,
        action: answer.action,
        draws: answer.draws,
        candidate: answer.candidate,
        feedback: answer.feedback);
    await store.submit(answer);
    await expectLater(
        store.submit(competing), throwsA(isA<LearningConflictException>()));
  });

  test('same retained identity with changed payload is invalid', () async {
    await store.submit(store.prepare(
        state: await store.load(),
        activityId: activity,
        action: StartLearningRun(options: RunOptions())));
    final answer = store.prepare(
        state: await store.load(),
        activityId: activity,
        action: ChooseSound(
            selectedSound: 'u',
            audioSource: AttemptAudioSource.pendingRecording));
    await store.submit(answer);
    final changed = LearningCommand(
        scope: answer.scope,
        authGeneration: answer.authGeneration,
        activityId: answer.activityId,
        expected: answer.expected,
        token: answer.token,
        submittedAt: answer.submittedAt,
        action: ChooseSound(
            selectedSound: 'y',
            audioSource: AttemptAudioSource.pendingRecording),
        draws: answer.draws,
        candidate: answer.candidate,
        feedback: answer.feedback);
    await expectLater(
        store.submit(changed), throwsA(isA<LearningInvalidCommandException>()));
  });

  test('older retained receipt returns current slot without rewinding',
      () async {
    await store.submit(store.prepare(
        state: await store.load(),
        activityId: activity,
        action: StartLearningRun(options: RunOptions())));
    final first = store.prepare(
        state: await store.load(),
        activityId: activity,
        action: ChooseSound(
            selectedSound: 'u',
            audioSource: AttemptAudioSource.pendingRecording));
    await store.submit(first);
    final advance = store.prepare(
        state: await store.load(),
        activityId: activity,
        action: const AdvanceLesson());
    await store.submit(advance);
    final latest = await store.submit(store.prepare(
        state: await store.load(),
        activityId: activity,
        action: ChooseSound(
            selectedSound: 'u',
            audioSource: AttemptAudioSource.pendingRecording)));
    final replay = await store.submit(first);
    expect(replay.duplicate, isTrue);
    expect(replay.slot.cursor.sequence, latest.slot.cursor.sequence);
    expect(replay.state.revision, latest.state.revision);
  });

  test('old generations and pruned proofs are stale', () async {
    store = repository(historyLimit: 1);
    await store.submit(store.prepare(
        state: await store.load(),
        activityId: activity,
        action: StartLearningRun(options: RunOptions())));
    final first = store.prepare(
        state: await store.load(),
        activityId: activity,
        action: ChooseSound(
            selectedSound: 'u',
            audioSource: AttemptAudioSource.pendingRecording));
    await store.submit(first);
    await store.submit(store.prepare(
        state: await store.load(),
        activityId: activity,
        action: const AdvanceLesson()));
    final second = store.prepare(
        state: await store.load(),
        activityId: activity,
        action: ChooseSound(
            selectedSound: 'u',
            audioSource: AttemptAudioSource.pendingRecording));
    await store.submit(second);
    await expectLater(
        store.submit(first), throwsA(isA<LearningConflictException>()));
    await store.submit(store.prepare(
        state: await store.load(),
        activityId: activity,
        action: StartLearningRun(options: RunOptions())));
    await expectLater(
        store.submit(second), throwsA(isA<LearningConflictException>()));
  });

  test('answer cannot implicitly create a fresh run', () async {
    expect(
        () => store.prepare(
            state: CourseLearningState.empty(
                LearningScope(courseId: 'en-fr', owner: owner)),
            activityId: activity,
            action: ChooseSound(
                selectedSound: 'u',
                audioSource: AttemptAudioSource.pendingRecording)),
        throwsA(isA<LearningInvalidCommandException>()));
    expect(persistence.writeCount, 0);
  });

  test('unrelated prepared activities merge against latest document', () async {
    final initial = await store.load();
    final first = store.prepare(
        state: initial,
        activityId: activity,
        action: StartLearningRun(options: RunOptions()));
    final second = store.prepare(
        state: initial,
        activityId: 'lesson:en-fr-vowels',
        action: StartLearningRun(options: RunOptions()));
    await store.submit(first);
    final merged = await store.submit(second);
    expect(merged.state.activities.keys,
        containsAll([activity, 'lesson:en-fr-vowels']));
  });

  test('account answer commit queues only supported compact event', () async {
    owner = LearningOwner.account('French/User:7');
    auth = LearningAuthScope(owner: owner, generation: 4, ready: true);
    store = repository();
    final initial = await store.load();
    final started = await store.submit(store.prepare(
        state: initial,
        activityId: activity,
        action: StartLearningRun(options: RunOptions())));
    final committed = await store.submit(store.prepare(
        state: started.state,
        activityId: activity,
        action: ChooseSound(
            selectedSound: 'u',
            audioSource: AttemptAudioSource.pendingRecording)));
    expect(committed.state.pending, hasLength(1));
    final event = committed.state.pending.single;
    expect(event.userId, owner.userId);
    expect(event.payload, isA<CloudAnswer>());
    expect(event.id, startsWith('fr04.c0.l1.1.2.'));
    expect(event.id.length, lessThan(128));
    expect(event.id, contains('.a0'));
    final wire =
        (jsonDecode(const LearningDocumentCodec().encode(committed.state))
            as Map<String, dynamic>)['pending'] as List<dynamic>;
    final wireEvent = wire.single as Map<String, dynamic>;
    expect(wireEvent.keys.toSet(), {'id', 'userId', 'courseId', 'payload'});
    expect((wireEvent['payload'] as Map<String, dynamic>).keys.toSet(),
        {'kind', 'sound', 'skill', 'correct', 'activity'});
    expect(committed.state.history.single.attempts.single.audioSource,
        AttemptAudioSource.pendingRecording);
  });

  test(
      'projector allowlists lesson and game events and rejects unknown activity',
      () async {
    owner = LearningOwner.account('projector-user');
    auth = LearningAuthScope(owner: owner, generation: 2, ready: true);
    store = repository();
    final scope = LearningScope(courseId: 'en-fr', owner: owner);
    final before = await store.load();
    final started = await store.submit(store.prepare(
        state: before,
        activityId: activity,
        action: StartLearningRun(options: RunOptions())));
    final state = started.state;
    final command = store.prepare(
        state: state,
        activityId: activity,
        action: ChooseSound(
            selectedSound: 'u',
            audioSource: AttemptAudioSource.pendingRecording));
    final transition =
        engine.evaluate(state: state, command: command, committedAt: fixedTime);
    LearningCommand asActivity(String id) => LearningCommand(
        scope: scope,
        authGeneration: command.authGeneration,
        activityId: id,
        expected: command.expected,
        token: command.token,
        submittedAt: command.submittedAt,
        action: command.action,
        draws: command.draws,
        candidate: command.candidate,
        feedback: command.feedback);
    const projector = SupportedProgressProjector();
    expect(
        projector.project(
            before: state,
            transition: transition,
            command: asActivity('lesson:unregistered')),
        isEmpty);
    final normal = projector.project(
        before: state, transition: transition, command: command);
    expect(normal, hasLength(1));
    final completion = LearningCompletion(
        lessonId: 'en-fr-u-y',
        contentRevision: 1,
        policyKind: CompletionPolicyKind.legacyOnePass,
        policyRevision: 1,
        thresholdPercent: null,
        committedAt: fixedTime);
    final withCompletion = LearningTransition(
        slot: transition.slot,
        attempts: const [],
        mistakes: transition.mistakes,
        summaries: transition.summaries,
        completions: [completion],
        bestScores: transition.bestScores);
    final lessonEvents = projector.project(
        before: state, transition: withCompletion, command: command);
    expect(lessonEvents.single.payload, isA<CloudLesson>());
    expect(lessonEvents.single.id, isNot(normal.single.id));
    final withScore = LearningTransition(
        slot: transition.slot,
        attempts: const [],
        mistakes: transition.mistakes,
        summaries: transition.summaries,
        completions: const [],
        bestScores: const {'arcade:sound': 19});
    final gameEvents = projector.project(
        before: state,
        transition: withScore,
        command: asActivity('arcade:sound'));
    expect(gameEvents.single.payload, isA<CloudScore>());
    expect(gameEvents.single.id.length, lessThan(128));
    expect(
        projector.project(
            before: state,
            transition: withScore,
            command: asActivity('arcade:unknown')),
        isEmpty);
  });

  test('preloaded peer load sees another repository latest committed image',
      () async {
    owner = LearningOwner.account('peer-load');
    auth = LearningAuthScope(owner: owner, generation: 9, ready: true);
    store = repository();
    final peer = repository();
    final firstLoaded = await store.load();
    await peer.load();
    final started = await store.submit(store.prepare(
        state: firstLoaded,
        activityId: activity,
        action: StartLearningRun(options: RunOptions())));
    final expected =
        engine.registry.require(activity).items.first.expectedChoice!;
    final answered = await store.submit(store.prepare(
        state: started.state,
        activityId: activity,
        action: ChooseSound(
            selectedSound: expected == 'u' ? 'y' : 'u',
            audioSource: AttemptAudioSource.pendingRecording)));
    final peerImage = await peer.load();
    expect(peerImage.revision, answered.state.revision);
    expect(peerImage.history, hasLength(1));
    expect(peerImage.mistakes, hasLength(1));
    expect(peerImage.pending, hasLength(1));
  });

  test('preloaded peer commit merges its unrelated activity over latest state',
      () async {
    owner = LearningOwner.account('peer-submit');
    auth = LearningAuthScope(owner: owner, generation: 10, ready: true);
    store = repository();
    final peer = repository();
    final aInitial = await store.load();
    final bInitial = await peer.load();
    final bCommand = peer.prepare(
        state: bInitial,
        activityId: 'lesson:en-fr-vowels',
        action: StartLearningRun(options: RunOptions()));
    final aStarted = await store.submit(store.prepare(
        state: aInitial,
        activityId: activity,
        action: StartLearningRun(options: RunOptions())));
    final expected =
        engine.registry.require(activity).items.first.expectedChoice!;
    final aCommitted = await store.submit(store.prepare(
        state: aStarted.state,
        activityId: activity,
        action: ChooseSound(
            selectedSound: expected == 'u' ? 'y' : 'u',
            audioSource: AttemptAudioSource.pendingRecording)));
    final peerCommit = await peer.submit(bCommand);
    expect(peerCommit.state.activities.keys,
        containsAll([activity, 'lesson:en-fr-vowels']));
    expect(peerCommit.state.revision, aCommitted.state.revision + 1);
    expect(peerCommit.state.history, hasLength(1));
    expect(peerCommit.state.summaries.values.single.total, 1);
    expect(peerCommit.state.mistakes, hasLength(1));
    expect(peerCommit.state.pending, hasLength(1));
  });

  test('preloaded same-slot contender conflicts instead of overwriting',
      () async {
    final initial = await store.load();
    final peer = repository();
    final peerInitial = await peer.load();
    final competing = peer.prepare(
        state: peerInitial,
        activityId: activity,
        action: StartLearningRun(options: RunOptions()));
    final winner = store.prepare(
        state: initial,
        activityId: activity,
        action: StartLearningRun(options: RunOptions()));
    await store.submit(winner);
    await expectLater(
        peer.submit(competing), throwsA(isA<LearningConflictException>()));
    expect((await store.load()).activities[activity]!.cursor.generation, 1);
  });

  test('preloaded peer duplicate retry returns current state and slot',
      () async {
    final initial = await store.load();
    final peer = repository();
    await peer.load();
    final started = await store.submit(store.prepare(
        state: initial,
        activityId: activity,
        action: StartLearningRun(options: RunOptions())));
    final expected =
        engine.registry.require(activity).items.first.expectedChoice!;
    final answer = store.prepare(
        state: started.state,
        activityId: activity,
        action: ChooseSound(
            selectedSound: expected == 'u' ? 'y' : 'u',
            audioSource: AttemptAudioSource.pendingRecording));
    final answerCommit = await store.submit(answer);
    final advanced = await store.submit(store.prepare(
        state: answerCommit.state,
        activityId: activity,
        action: const AdvanceLesson()));
    final retry = await peer.submit(answer);
    expect(retry.duplicate, isTrue);
    expect(retry.state.revision, advanced.state.revision);
    expect(retry.slot.cursor.sequence, advanced.slot.cursor.sequence);
    expect(retry.state.activities.keys, contains(activity));
  });

  test('rejected optimistic write is invisible to a queued reader', () async {
    final before = await store.load();
    persistence.holdNextWrite();
    final command = store.prepare(
        state: before,
        activityId: activity,
        action: StartLearningRun(options: RunOptions()));
    final saving = store.submit(command);
    await persistence.writeEntered;
    final second = repository();
    final reading = second.load();
    expect(persistence.platformValue, isNull);
    persistence.releaseWrite(persist: false);
    await expectLater(saving, throwsA(isA<LearningSaveException>()));
    expect((await reading).activities, isEmpty);
  });

  test('failed rollback quarantines scope until retryLoad verifies known bytes',
      () async {
    persistence.restoreFailure = StateError('repair unavailable');
    final before = await store.load();
    persistence.holdNextWrite();
    final command = store.prepare(
        state: before,
        activityId: activity,
        action: StartLearningRun(options: RunOptions()));
    final saving = store.submit(command);
    await persistence.writeEntered;
    persistence.releaseWrite(persist: false);
    await expectLater(saving, throwsA(isA<LearningSaveException>()));
    await expectLater(
        store.load(), throwsA(isA<LearningUnavailableException>()));
    persistence.restoreFailure = null;
    expect((await store.retryLoad()).activities, isEmpty);
  });

  test('corrupt source bytes are not replaced with empty state', () async {
    final key = LearningScope(courseId: 'en-fr', owner: owner).storageKey;
    const bytes = '{not-learning-json';
    persistence.cache[key] = bytes;
    persistence.platform[key] = bytes;
    await expectLater(store.load(), throwsA(isA<LearningCorruptException>()));
    expect(persistence.platform[key], bytes);
  });

  test('future schema bytes remain exact and unsupported', () async {
    final key = LearningScope(courseId: 'en-fr', owner: owner).storageKey;
    const bytes = '{"schemaVersion":99,"unknown":[1,2]}';
    persistence.cache[key] = bytes;
    persistence.platform[key] = bytes;
    await expectLater(
        store.load(), throwsA(isA<LearningUnsupportedVersionException>()));
    expect(persistence.platform[key], bytes);
    expect(persistence.writeCount, 0);
  });

  test('portable document counter overflow is rejected before write', () async {
    const maximum = 9007199254740991;
    final scope = LearningScope(courseId: 'en-fr', owner: owner);
    final exhausted = CourseLearningState(
        scope: scope,
        revision: maximum,
        commitOrdinal: maximum,
        history: const [],
        activities: const {},
        mistakes: const {},
        summaries: const {},
        completions: const [],
        bestScores: const {},
        pending: const []);
    persistence.cache[scope.storageKey] =
        const LearningDocumentCodec().encode(exhausted);
    persistence.platform[scope.storageKey] =
        persistence.cache[scope.storageKey]!;
    final command = store.prepare(
        state: await store.load(),
        activityId: activity,
        action: StartLearningRun(options: RunOptions()));
    await expectLater(
        store.submit(command), throwsA(isA<LearningInvalidCommandException>()));
    expect(persistence.writeCount, 0);
  });
}
