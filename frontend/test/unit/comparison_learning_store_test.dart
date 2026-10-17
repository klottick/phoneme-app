import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_codec.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_store.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import '../support/course_learning_fixtures.dart';
import '../support/course_learning_persistence_fakes.dart';

final class _HeldComparisonPreferences extends InMemorySharedPreferencesStore {
  _HeldComparisonPreferences() : super.withData({});
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

void main() {
  const activity = comparisonActivityId;
  final catalogue = loadFrenchComparisonCatalogue();
  final owner = LearningOwner.account('comparison-store-test');
  final initialAuth =
      LearningAuthScope(owner: owner, generation: 4, ready: true);
  var tokenNumber = 0;

  ComparisonLearningRepository comparisonRepository(
    FakeLearningPersistence persistence, {
    LearningAuthScope Function()? currentAuth,
    LearningOwner Function()? backendOwner,
    int historyLimit = 2000,
    void Function()? onCommitted,
  }) =>
      ComparisonLearningRepository(
        scope: ComparisonProfileScope(courseId: 'en-fr', owner: owner),
        authGeneration: 4,
        currentAuth: currentAuth ?? () => initialAuth,
        backendOwner: backendOwner ?? () => owner,
        persistence: persistence,
        transitions: ComparisonLearningTransitionEngine(catalogue: catalogue),
        clock: () => fixedTime,
        newToken: () => 'cmp${(++tokenNumber).toString().padLeft(19, '0')}',
        onCommitted: onCommitted,
        historyLimit: historyLimit,
      );

  setUp(() => tokenNumber = 0);

  test(
      'real comparison repository commits typed state and exact duplicate once',
      () async {
    final persistence = FakeLearningPersistence();
    var notifications = 0;
    final store =
        comparisonRepository(persistence, onCommitted: () => notifications++);
    final empty = await store.load();
    final start = store.prepare(
        state: empty,
        activityId: activity,
        action:
            StartComparisonRun(sessionId: 'store-run', policy: LessonPolicy()));
    final committed = await store.submit(start);
    expect(committed.duplicate, isFalse);
    expect(committed.state.revision, 1);
    expect(committed.state.commitOrdinal, 1);
    expect(notifications, 1);
    final writes = persistence.writeCount;
    final duplicate = await store.submit(start);
    expect(duplicate.duplicate, isTrue);
    expect(duplicate.state.revision, 1);
    expect(persistence.writeCount, writes);
    expect(notifications, 1);
    expect(
        const ComparisonLearningCodec()
            .decode(persistence.platform[store.scope.storageKey]!, store.scope,
                catalogue)
            .slot,
        isNotNull);
    final changedFingerprint = ComparisonLearningCommand(
        scope: start.scope,
        authGeneration: start.authGeneration,
        activityId: start.activityId,
        expected: start.expected,
        token: start.token,
        submittedAt: start.submittedAt,
        action:
            StartComparisonRun(sessionId: 'different', policy: LessonPolicy()));
    await expectLater(store.submit(changedFingerprint),
        throwsA(isA<LearningInvalidCommandException>()));
  });

  test('held comparison write keeps loaded state unchanged until ACK',
      () async {
    final persistence = FakeLearningPersistence();
    final store = comparisonRepository(persistence);
    final loaded = await store.load();
    final command = store.prepare(
        state: loaded,
        activityId: activity,
        action: StartComparisonRun(sessionId: 'held', policy: LessonPolicy()));
    persistence.holdNextWrite();
    final pending = store.submit(command);
    await persistence.writeEntered;
    var queuedLoadFinished = false;
    final queuedLoad = store.load().then((state) {
      queuedLoadFinished = true;
      return state;
    });
    try {
      expect(loaded.slot, isNull);
      expect(loaded.revision, 0);
      await Future<void>.delayed(Duration.zero);
      expect(queuedLoadFinished, isFalse);
    } finally {
      persistence.releaseWrite(persist: true);
    }
    final result = await pending;
    final reread = await queuedLoad;
    expect(result.state.slot, isNotNull);
    expect(loaded.slot, isNull);
    expect(reread.revision, 1);
  });

  test('held answer adds attempt and durable counts only after ACK', () async {
    final persistence = FakeLearningPersistence();
    final store = comparisonRepository(persistence);
    final loaded = await store.load();
    final started = await store.submit(store.prepare(
        state: loaded,
        activityId: activity,
        action: StartComparisonRun(
            sessionId: 'answer-held', policy: LessonPolicy())));
    final before = started.state;
    final answer = store.prepare(
        state: before,
        activityId: activity,
        action: _wrongPairOne(before, store.scope, catalogue));
    persistence.holdNextWrite();
    final pending = store.submit(answer);
    await persistence.writeEntered;
    try {
      expect(before.attempts, isEmpty);
      expect(before.mistakes, isEmpty);
      expect(before.summaries, isEmpty);
      expect(before.commitOrdinal, 1);
    } finally {
      persistence.releaseWrite(persist: true);
    }
    final acknowledged = await pending;
    expect(acknowledged.state.attempts, hasLength(1));
    expect(acknowledged.state.mistakes, hasLength(1));
    expect(acknowledged.state.commitOrdinal, 2);
  });

  test(
      'history limit trims only attempts and receipts, not checkpoint or summary',
      () async {
    final persistence = FakeLearningPersistence();
    final store = comparisonRepository(persistence, historyLimit: 1);
    var state = await store.load();
    await store.submit(store.prepare(
        state: state,
        activityId: activity,
        action:
            StartComparisonRun(sessionId: 'bounded', policy: LessonPolicy())));
    state = await store.load();
    await store.submit(store.prepare(
        state: state,
        activityId: activity,
        action: _answerCurrent(state, store.scope, catalogue)));
    state = await store.load();
    await store.submit(store.prepare(
        state: state,
        activityId: activity,
        action: const AdvanceComparisonPair()));
    state = await store.load();
    final before = state.checkpoint!.sessionJson;
    final second = await store.submit(store.prepare(
        state: state,
        activityId: activity,
        action: _answerCurrent(state, store.scope, catalogue)));
    expect(second.state.attempts, hasLength(1));
    expect(second.state.receipts, hasLength(1));
    expect(
        second.state.summaries.values
            .fold<int>(0, (total, summary) => total + summary.firstInRun.total),
        2);
    expect(second.state.checkpoint!.sessionJson, isNot(before));
    expect(second.state.slot!.latestReceipt.token,
        second.state.receipts.single.token);
  });

  test('failed write restores exact bytes and same frozen command retries once',
      () async {
    final persistence = FakeLearningPersistence();
    final store = comparisonRepository(persistence);
    final empty = await store.load();
    final start = store.prepare(
        state: empty,
        activityId: activity,
        action: StartComparisonRun(sessionId: 'retry', policy: LessonPolicy()));
    final rawBefore = persistence.platform[store.scope.storageKey];
    persistence.holdNextWrite();
    final saving = store.submit(start);
    await persistence.writeEntered;
    persistence.releaseWrite(persist: false);
    await expectLater(saving, throwsA(isA<LearningSaveException>()));
    expect(persistence.platform[store.scope.storageKey], rawBefore);
    expect(persistence.cache[store.scope.storageKey], rawBefore);
    final writeCountAfterFailure = persistence.writeCount;
    final retry = await store.submit(start);
    expect(retry.duplicate, isFalse);
    expect(retry.state.revision, 1);
    expect(persistence.writeCount, writeCountAfterFailure + 1);
    final writes = persistence.writeCount;
    expect((await store.submit(start)).duplicate, isTrue);
    expect(persistence.writeCount, writes);
  });

  test('one actual persistence isolates real v2 and comparison families',
      () async {
    final persistence = FakeLearningPersistence();
    final comparison = comparisonRepository(persistence);
    final v2Scope = LearningScope(courseId: 'en-fr', owner: owner);
    final v2Auth = initialAuth;
    final v2 = CourseLearningRepository(
      scope: v2Scope,
      authGeneration: 4,
      currentAuth: () => v2Auth,
      backendOwner: () => owner,
      persistence: persistence,
      transitions: LearningTransitionEngine(LearningRegistry.french()),
      clock: () => fixedTime,
      newToken: () => 'abcdefghijklmnopqrstuv',
      random: Random(4),
    );
    final v2Initial = await v2.load();
    final comparisonInitial = await comparison.load();
    const token = 'abcdefghijklmnopqrstuv';
    final v2Start = v2.prepare(
        state: v2Initial,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()));
    final comparisonStart = ComparisonLearningCommand(
        scope: comparison.scope,
        authGeneration: 4,
        activityId: activity,
        expected: comparisonInitial.slot?.cursor ??
            ComparisonCursor(generation: 0, sequence: 0, revision: 0),
        token: token,
        submittedAt: fixedTime,
        action: StartComparisonRun(
            sessionId: 'shared-token', policy: LessonPolicy()));
    final sameTokenV2 = _withV2Token(v2Start, token);
    final v2Commit = await v2.submit(sameTokenV2);
    final v2Bytes = persistence.platform[v2.scope.storageKey]!;
    final comparisonCommit = await comparison.submit(comparisonStart);
    final comparisonBytes = persistence.platform[comparison.scope.storageKey]!;
    expect(v2Commit.duplicate, isFalse);
    expect(comparisonCommit.duplicate, isFalse);
    expect(v2Commit.state.revision, 1);
    expect(comparisonCommit.state.revision, 1);
    final writeCount = persistence.writeCount;
    expect((await v2.submit(sameTokenV2)).duplicate, isTrue);
    expect((await comparison.submit(comparisonStart)).duplicate, isTrue);
    expect(persistence.writeCount, writeCount);
    expect(persistence.platform[v2.scope.storageKey], v2Bytes);
    expect(persistence.platform[comparison.scope.storageKey], comparisonBytes);
    expect(v2.scope.storageKey, isNot(comparison.scope.storageKey));
  });

  test(
      'comparison answers and completion leave real v2 evidence bytes untouched',
      () async {
    final persistence = FakeLearningPersistence();
    final comparison = comparisonRepository(persistence);
    final v2Scope = LearningScope(courseId: 'en-fr', owner: owner);
    final v2 = CourseLearningRepository(
        scope: v2Scope,
        authGeneration: 4,
        currentAuth: () => initialAuth,
        backendOwner: () => owner,
        persistence: persistence,
        transitions: LearningTransitionEngine(LearningRegistry.french()),
        clock: () => fixedTime,
        newToken: () => 'abcdefghijklmnopqrstuv',
        random: Random(15));
    final v2Initial = await v2.load();
    await v2.submit(v2.prepare(
        state: v2Initial,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions())));
    final originalV2Bytes = persistence.platform[v2Scope.storageKey]!;
    var state = await comparison.load();
    await comparison.submit(comparison.prepare(
        state: state,
        activityId: activity,
        action:
            StartComparisonRun(sessionId: 'isolated', policy: LessonPolicy())));
    for (var i = 0; i < catalogue.exercises.length; i++) {
      state = await comparison.load();
      await comparison.submit(comparison.prepare(
          state: state,
          activityId: activity,
          action: _answerCurrent(state, comparison.scope, catalogue)));
      state = await comparison.load();
      await comparison.submit(comparison.prepare(
          state: state,
          activityId: activity,
          action: const AdvanceComparisonPair()));
    }
    state = await comparison.load();
    final finished = await comparison.submit(comparison.prepare(
        state: state,
        activityId: activity,
        action: const FinishComparisonRun(recordCompletion: true)));
    expect(finished.state.completions, hasLength(1));
    expect(finished.state.attempts, hasLength(10));
    expect(persistence.platform[v2Scope.storageKey], originalV2Bytes);
    final decodedV2 =
        const LearningDocumentCodec().decode(originalV2Bytes, v2Scope);
    expect(decodedV2.history, isEmpty);
    expect(decodedV2.pending, isEmpty);
    expect(decodedV2.summaries, isEmpty);
  });

  test('shared process tail blocks comparison load behind held real v2 write',
      () async {
    final persistence = FakeLearningPersistence();
    final comparison = comparisonRepository(persistence);
    final v2Scope = LearningScope(courseId: 'en-fr', owner: owner);
    final v2 = CourseLearningRepository(
      scope: v2Scope,
      authGeneration: 4,
      currentAuth: () => initialAuth,
      backendOwner: () => owner,
      persistence: persistence,
      transitions: LearningTransitionEngine(LearningRegistry.french()),
      clock: () => fixedTime,
      newToken: () => 'abcdefghijklmnopqrstuv',
      random: Random(8),
    );
    final initial = await v2.load();
    final command = v2.prepare(
        state: initial,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()));
    persistence.holdNextWrite();
    final saving = v2.submit(command);
    await persistence.writeEntered;
    var finished = false;
    final loading = comparison.load().then((value) {
      finished = true;
      return value;
    });
    try {
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
    } finally {
      persistence.releaseWrite(persist: true);
    }
    await saving;
    await loading;
    expect(finished, isTrue);
  });

  test('owner generation change before duplicate rejects A to B to A replay',
      () async {
    final persistence = FakeLearningPersistence();
    var auth = initialAuth;
    final store = comparisonRepository(persistence, currentAuth: () => auth);
    final initial = await store.load();
    final start = store.prepare(
        state: initial,
        activityId: activity,
        action: StartComparisonRun(sessionId: 'owner', policy: LessonPolicy()));
    await store.submit(start);
    auth = LearningAuthScope(
        owner: LearningOwner.account('B'), generation: 5, ready: true);
    auth = LearningAuthScope(owner: owner, generation: 6, ready: true);
    await expectLater(
        store.submit(start), throwsA(isA<LearningOwnerChangedException>()));
  });

  test('write already entered ACKs captured profile after auth changes',
      () async {
    final persistence = FakeLearningPersistence();
    var auth = initialAuth;
    final store = comparisonRepository(persistence, currentAuth: () => auth);
    final empty = await store.load();
    final command = store.prepare(
        state: empty,
        activityId: activity,
        action:
            StartComparisonRun(sessionId: 'captured', policy: LessonPolicy()));
    persistence.holdNextWrite();
    final saving = store.submit(command);
    await persistence.writeEntered;
    late Future<ComparisonCommit> stale;
    try {
      auth = LearningAuthScope(
          owner: LearningOwner.account('B'), generation: 5, ready: true);
      auth = LearningAuthScope(owner: owner, generation: 6, ready: true);
      stale = store.submit(command);
    } finally {
      persistence.releaseWrite(persist: true);
    }
    final committed = await saving;
    expect(committed.state.revision, 1);
    await expectLater(stale, throwsA(isA<LearningOwnerChangedException>()));
    expect(persistence.platform[store.scope.storageKey], isNotNull);
    expect(persistence.writeCount, 1);
  });

  test(
      'stale cursor conflicts, same-generation replay deduplicates, restart fences',
      () async {
    final persistence = FakeLearningPersistence();
    final store = comparisonRepository(persistence);
    final initial = await store.load();
    final start = store.prepare(
        state: initial,
        activityId: activity,
        action:
            StartComparisonRun(sessionId: 'replay', policy: LessonPolicy()));
    await store.submit(start);
    final stale = ComparisonLearningCommand(
        scope: store.scope,
        authGeneration: 4,
        activityId: activity,
        expected: start.expected,
        token: 'stale-token-0000000000',
        submittedAt: fixedTime,
        action: StartComparisonRun(sessionId: 'other', policy: LessonPolicy()));
    await expectLater(
        store.submit(stale), throwsA(isA<LearningConflictException>()));
    final started = await store.load();
    final answer = store.prepare(
        state: started,
        activityId: activity,
        action: _wrongPairOne(started, store.scope, catalogue));
    await store.submit(answer);
    final state = await store.load();
    await store.submit(store.prepare(
        state: state,
        activityId: activity,
        action: const AdvanceComparisonPair()));
    expect((await store.submit(answer)).duplicate, isTrue);
    final afterReplay = await store.load();
    final restart = store.prepare(
        state: afterReplay,
        activityId: activity,
        action:
            StartComparisonRun(sessionId: 'restart', policy: LessonPolicy()));
    await store.submit(restart);
    await expectLater(
        store.submit(answer), throwsA(isA<LearningConflictException>()));
  });

  test(
      'failed rollback quarantines only comparison key and verified retry repairs',
      () async {
    final persistence = FakeLearningPersistence();
    final comparison = comparisonRepository(persistence);
    final v2Scope = LearningScope(courseId: 'en-fr', owner: owner);
    final v2 = CourseLearningRepository(
        scope: v2Scope,
        authGeneration: 4,
        currentAuth: () => initialAuth,
        backendOwner: () => owner,
        persistence: persistence,
        transitions: LearningTransitionEngine(LearningRegistry.french()),
        clock: () => fixedTime,
        newToken: () => 'abcdefghijklmnopqrstuv',
        random: Random(9));
    await v2.load();
    final comparisonEmpty = await comparison.load();
    final v2Start = v2.prepare(
        state: await v2.load(),
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()));
    await v2.submit(v2Start);
    final v2Raw = persistence.platform[v2Scope.storageKey];
    final start = comparison.prepare(
        state: comparisonEmpty,
        activityId: activity,
        action: StartComparisonRun(
            sessionId: 'quarantine', policy: LessonPolicy()));
    persistence.restoreFailure = StateError('restore failed');
    persistence.holdNextWrite();
    final failed = comparison.submit(start);
    await persistence.writeEntered;
    persistence.releaseWrite(persist: false);
    await expectLater(failed, throwsA(isA<LearningSaveException>()));
    await expectLater(
        comparison.load(), throwsA(isA<LearningUnavailableException>()));
    expect((await v2.load()).revision, 1);
    expect(persistence.platform[v2Scope.storageKey], v2Raw);
    persistence.restoreFailure = null;
    final repaired = await comparison.retryLoad();
    expect(repaired.revision, 0);
    expect(repaired.slot, isNull);
  });

  test('unsupported comparison raw remains unchanged while v2 sibling loads',
      () async {
    final persistence = FakeLearningPersistence();
    final comparison = comparisonRepository(persistence);
    final v2Scope = LearningScope(courseId: 'en-fr', owner: owner);
    final v2 = CourseLearningRepository(
        scope: v2Scope,
        authGeneration: 4,
        currentAuth: () => initialAuth,
        backendOwner: () => owner,
        persistence: persistence,
        transitions: LearningTransitionEngine(LearningRegistry.french()),
        clock: () => fixedTime,
        newToken: () => 'abcdefghijklmnopqrstuv',
        random: Random(10));
    final v2Initial = await v2.load();
    await v2.submit(v2.prepare(
        state: v2Initial,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions())));
    final v2Raw = persistence.platform[v2Scope.storageKey]!;
    const unsupported = '{"schemaVersion":2,"keep":"opaque"}';
    persistence.cache[comparison.scope.storageKey] = unsupported;
    persistence.platform[comparison.scope.storageKey] = unsupported;
    await expectLater(
        comparison.load(), throwsA(isA<ComparisonUnavailableException>()));
    expect(persistence.platform[comparison.scope.storageKey], unsupported);
    expect((await v2.load()).revision, 1);
    expect(persistence.platform[v2Scope.storageKey], v2Raw);
  });

  test(
      'repository loads valid latest slot with pruned receipts without rewriting',
      () async {
    final persistence = FakeLearningPersistence();
    final store = comparisonRepository(persistence);
    final empty = await store.load();
    await store.submit(store.prepare(
        state: empty,
        activityId: activity,
        action: StartComparisonRun(
            sessionId: 'pruned-slot', policy: LessonPolicy())));
    final document = jsonDecode(persistence.platform[store.scope.storageKey]!)
        as Map<String, Object?>;
    document['receipts'] = <Object?>[];
    final prunedRaw = jsonEncode(document);
    persistence.cache[store.scope.storageKey] = prunedRaw;
    persistence.platform[store.scope.storageKey] = prunedRaw;
    final reads = persistence.reads.length;
    final writes = persistence.writeCount;
    final loaded = await store.load();
    expect(loaded.receipts, isEmpty);
    expect(loaded.slot!.latestReceipt.token, isNotEmpty);
    expect(persistence.writeCount, writes);
    expect(persistence.reads.length, greaterThan(reads));
    expect(persistence.platform[store.scope.storageKey], prunedRaw);

    final invalidDocument = jsonDecode(prunedRaw) as Map<String, Object?>;
    ((invalidDocument['slot'] as Map<String, Object?>)['latestReceipt']
        as Map<String, Object?>)['activityId'] = 'foreign-activity';
    final invalidRaw = jsonEncode(invalidDocument);
    persistence.cache[store.scope.storageKey] = invalidRaw;
    persistence.platform[store.scope.storageKey] = invalidRaw;
    await expectLater(
        store.load(), throwsA(isA<ComparisonUnavailableException>()));
    expect(persistence.platform[store.scope.storageKey], invalidRaw);
    expect(persistence.writeCount, writes);
  });

  test('preferences optimistic write failure repairs cache before reload',
      () async {
    final platform = _HeldComparisonPreferences();
    SharedPreferencesStorePlatform.instance = platform;
    SharedPreferences.resetStatic();
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final persistence = PreferencesLearningPersistence();
    final adapter = ComparisonLearningRepository(
        scope: ComparisonProfileScope(courseId: 'en-fr', owner: owner),
        authGeneration: 4,
        currentAuth: () => initialAuth,
        backendOwner: () => owner,
        persistence: persistence,
        transitions: ComparisonLearningTransitionEngine(catalogue: catalogue),
        clock: () => fixedTime,
        newToken: () => 'pref${(++tokenNumber).toString().padLeft(18, '0')}');
    final empty = await adapter.load();
    final start = adapter.prepare(
        state: empty,
        activityId: activity,
        action: StartComparisonRun(sessionId: 'prefs', policy: LessonPolicy()));
    final key = adapter.scope.storageKey;
    final preferences = await SharedPreferences.getInstance();
    final committed = preferences.getString(key);
    platform.begin();
    final saving = adapter.submit(start);
    await platform.entered!.future;
    expect(preferences.getString(key), isNot(committed));
    platform.release(false);
    await expectLater(saving, throwsA(isA<LearningSaveException>()));
    expect(preferences.getString(key), committed);
    expect((await adapter.load()).revision, 0);
  });
}

LearningCommand _withV2Token(LearningCommand command, String token) =>
    LearningCommand(
        scope: command.scope,
        authGeneration: command.authGeneration,
        activityId: command.activityId,
        expected: command.expected,
        token: token,
        submittedAt: command.submittedAt,
        action: command.action,
        draws: command.draws,
        candidate: command.candidate,
        feedback: command.feedback);

AnswerComparisonPair _wrongPairOne(ComparisonLearningState state,
    ComparisonProfileScope scope, ComparisonCatalogue catalogue) {
  final pair = catalogue.exercise('fr07b-pair-01');
  final observations = [
    for (final sample in [pair.sampleA, pair.sampleB])
      ComparisonPlaybackObservation(
          slot: sample.slot,
          referenceId: sample.referenceId,
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.unverifiedRecording,
          activityId: catalogue.activityId,
          runGeneration: state.slot!.cursor.generation,
          round: 1,
          pairId: pair.id,
          profile: scope,
          uiGeneration: 91)
  ];
  return AnswerComparisonPair(ComparePhonemesAnswer(
      selectedRelation: PhonemeRelation.same,
      expectedRelationSnapshot: pair.expectedRelation,
      observations: observations));
}

AnswerComparisonPair _answerCurrent(ComparisonLearningState state,
    ComparisonProfileScope scope, ComparisonCatalogue catalogue) {
  final session = LessonSectionSession.fromJson(
      _mutableJson(state.checkpoint!.sessionJson),
      itemIds: catalogue.exercises.map((item) => item.id).toList(),
      contentRevision: catalogue.contentRevision);
  final pair = catalogue.exercise(session.currentItemId!);
  final observations = [
    for (final sample in [pair.sampleA, pair.sampleB])
      ComparisonPlaybackObservation(
          slot: sample.slot,
          referenceId: sample.referenceId,
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.unverifiedRecording,
          activityId: catalogue.activityId,
          runGeneration: state.slot!.cursor.generation,
          round: session.round,
          pairId: pair.id,
          profile: scope,
          uiGeneration: 92)
  ];
  return AnswerComparisonPair(ComparePhonemesAnswer(
      selectedRelation: pair.expectedRelation,
      expectedRelationSnapshot: pair.expectedRelation,
      observations: observations));
}

Map<String, dynamic> _mutableJson(Map<String, Object?> value) {
  Object? copy(Object? entry) {
    if (entry is Map) {
      return <String, dynamic>{
        for (final item in entry.entries) item.key as String: copy(item.value)
      };
    }
    if (entry is List) return entry.map(copy).toList();
    return entry;
  }

  return copy(value) as Map<String, dynamic>;
}
