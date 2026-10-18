import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
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
import 'package:linguist/src/core/course/course_learning_transaction.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_store.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../support/course_learning_persistence_fakes.dart';
import '../support/sentence_hunt_fixtures.dart';

final _time = DateTime.utc(2026, 10, 18, 12);
const _ownerId = 'sentence-hunt-store-test';
final _catalogue = syntheticSentenceCatalogue();

var _tokenNumber = 0;

void main() {
  setUp(() => _tokenNumber = 0);

  test('real adapter commits an exact Start once and rejects a changed payload',
      () async {
    final persistence = FakeLearningPersistence();
    final store = _repository(persistence);
    final state = await store.load();
    final start = _prepareStart(store, state, fixtureSectionIds.first,
        sessionId: 'dedupe-start');

    final committed = await store.submit(start);
    final writes = persistence.writeCount;
    final duplicate = await store.submit(start);

    expect(committed.duplicate, isFalse);
    expect(committed.state.revision, 1);
    expect(committed.state.commitOrdinal, 1);
    expect(committed.slot.sectionId, fixtureSectionIds.first);
    expect(duplicate.duplicate, isTrue);
    expect(duplicate.state.revision, 1);
    expect(persistence.writeCount, writes);

    final changed = SentenceHuntLearningCommand(
      scope: start.scope,
      authGeneration: start.authGeneration,
      sectionId: start.sectionId,
      sectionFingerprint: start.sectionFingerprint,
      expected: start.expected,
      token: start.token,
      submittedAt: start.submittedAt,
      action: StartSentenceHuntRun(
        sessionId: 'changed-payload',
        policy: _catalogue.section(start.sectionId).policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );
    await expectLater(
        store.submit(changed), throwsA(isA<LearningInvalidCommandException>()));
    expect(persistence.writeCount, writes);
  });

  test('held Start, answer, debrief advance, and Finish publish only after ACK',
      () async {
    for (final _HeldStage stage in _HeldStage.values) {
      final persistence = FakeLearningPersistence();
      var notifications = 0;
      final store = _repository(
        persistence,
        onCommitted: () => notifications++,
      );
      final _PreparedStage prepared = await _prepareStage(store, stage);
      final before = prepared.state;
      final beforeBytes = persistence.platform[store.scope.storageKey];
      final beforeNotifications = notifications;
      persistence.holdNextWrite();

      final saving = store.submit(prepared.command);
      await persistence.writeEntered;
      expect(before.attempts.length, prepared.attemptsBefore);
      expect(before.completions.length, prepared.completionsBefore);
      expect(notifications, beforeNotifications);
      var queuedLoadCompleted = false;
      final queuedLoad = store.load().then((SentenceHuntState value) {
        queuedLoadCompleted = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(queuedLoadCompleted, isFalse,
          reason: '${stage.name} must remain serialized until write ACK');
      expect(before.revision, prepared.state.revision,
          reason: 'candidate construction must not mutate loaded state');
      expect(beforeBytes, persistence.platform[store.scope.storageKey],
          reason: 'the prior durable image is visible until ACK');

      persistence.releaseWrite(persist: true);
      final result = await saving;
      final reread = await queuedLoad;
      expect(result.duplicate, isFalse);
      expect(result.state.revision, before.revision + 1);
      expect(reread.revision, before.revision + 1);
      expect(notifications, beforeNotifications + 1);
      if (stage == _HeldStage.answer) {
        expect(before.attempts, isEmpty);
        expect(result.state.attempts, hasLength(1));
      }
      if (stage == _HeldStage.advanceToDebrief) {
        expect(
            before.slots[prepared.command.sectionId]!.checkpoint
                .sessionJson['phase'],
            isNot(LessonSectionPhase.debrief.name));
        expect(result.slot.checkpoint.sessionJson['phase'],
            LessonSectionPhase.debrief.name);
      }
      if (stage == _HeldStage.finish) {
        expect(before.completions, isEmpty);
        expect(result.state.completions, hasLength(1));
      }
      await store.retryLoad();
    }
  });

  test(
      'failed Start, answer, debrief advance, and Finish restore exact bytes and retry the frozen command once',
      () async {
    for (final _HeldStage stage in _HeldStage.values) {
      final persistence = FakeLearningPersistence();
      final store = _repository(persistence);
      final _PreparedStage prepared = await _prepareStage(store, stage);
      final String? oldPlatform = persistence.platform[store.scope.storageKey];
      final String? oldCache = persistence.cache[store.scope.storageKey];
      final int writesBefore = persistence.writeCount;
      persistence.holdNextWrite();

      final failedSave = store.submit(prepared.command);
      await persistence.writeEntered;
      expect(prepared.state.attempts.length, prepared.attemptsBefore);
      expect(prepared.state.completions.length, prepared.completionsBefore);
      persistence.releaseWrite(persist: false);
      await expectLater(failedSave, throwsA(isA<LearningSaveException>()));

      expect(persistence.platform[store.scope.storageKey], oldPlatform);
      expect(persistence.cache[store.scope.storageKey], oldCache);
      final SentenceHuntState afterFailure = await store.load();
      expect(afterFailure.revision, prepared.state.revision);
      expect(afterFailure.attempts.length, prepared.attemptsBefore);
      expect(afterFailure.completions.length, prepared.completionsBefore);

      final retry = await store.submit(prepared.command);
      expect(retry.duplicate, isFalse);
      expect(retry.state.revision, prepared.state.revision + 1);
      expect(persistence.writeCount, writesBefore + 2,
          reason: 'one rejected platform attempt and one exact retry');
      if (stage == _HeldStage.answer) {
        final answer =
            (prepared.command.action as AnswerSentenceHuntItem).answer;
        expect(retry.state.attempts.single.playback, same(answer.playback),
            reason:
                'the frozen acknowledged recording observation is reused; no replay is required');
        expect(retry.state.attempts, hasLength(1));
      }
      final int writesAfterRetry = persistence.writeCount;
      expect((await store.submit(prepared.command)).duplicate, isTrue);
      expect(persistence.writeCount, writesAfterRetry);
    }
  });

  test(
      'each section latest receipt survives history trimming and sibling commits',
      () async {
    final persistence = FakeLearningPersistence();
    final store = _repository(persistence, historyLimit: 1);
    final Map<String, SentenceHuntCommand> starts =
        <String, SentenceHuntCommand>{};
    for (final String sectionId in fixtureSectionIds) {
      final state = await store.load();
      final start = _prepareStart(store, state, sectionId,
          sessionId: 'slot-${sectionId.split('-').last}');
      starts[sectionId] = start;
      await store.submit(start);
    }

    var state = await store.load();
    expect(state.slots, hasLength(3));
    expect(state.revision, 3);
    expect(state.commitOrdinal, 3);
    expect(state.receipts, hasLength(1));
    for (final String sectionId in fixtureSectionIds) {
      expect(state.slots[sectionId]!.latestReceipt.token,
          starts[sectionId]!.token);
      expect(state.slots[sectionId]!.cursor,
          const LearningCursorPosition(generation: 1, sequence: 1, revision: 0),
          reason:
              'section cursors remain independent of global document revisions');
    }
    final int writes = persistence.writeCount;
    for (final String sectionId in fixtureSectionIds) {
      final duplicate = await store.submit(starts[sectionId]!);
      expect(duplicate.duplicate, isTrue);
      expect(duplicate.slot.sectionId, sectionId);
      expect(duplicate.slot.latestReceipt.token, starts[sectionId]!.token);
    }
    expect(persistence.writeCount, writes,
        reason: 'all three per-section retries are no-write duplicates');

    // Finish a different section and then commit a sibling. The finished
    // section's latest receipt is now absent from the one-entry global tail.
    final String finishedSection = fixtureSectionIds.first;
    final SentenceHuntCommand finish = await _finishCommand(
      store,
      sectionId: finishedSection,
      alreadyStarted: true,
    );
    final SentenceHuntCommit finished = await store.submit(finish);
    expect(finished.state.receipts, hasLength(1));
    expect(finished.state.attempts, hasLength(1));
    expect(
        finished.state.summaries.values.fold<int>(
            0,
            (int total, SentenceHuntSummary summary) =>
                total + summary.firstInRun.total),
        5,
        reason: 'bounded attempt history does not trim durable summary counts');
    final String sibling = fixtureSectionIds[1];
    final siblingState = await store.load();
    await store.submit(_answerCommand(store, siblingState, sibling));
    state = await store.load();
    expect(state.receipts.single.sectionId, sibling);
    expect(state.slots[finishedSection]!.latestReceipt.token, finish.token);
    expect(state.slots[finishedSection]!.checkpoint.finished, isTrue);
    final int writesAfterSibling = persistence.writeCount;
    final int attemptsBeforeDuplicate = state.attempts.length;
    final int completionsBeforeDuplicate = state.completions.length;
    final duplicateFinish = await store.submit(finish);
    expect(duplicateFinish.duplicate, isTrue);
    expect(duplicateFinish.slot.sectionId, finishedSection,
        reason:
            'duplicateResult must return the command section, not global tail');
    expect(duplicateFinish.slot.latestReceipt.token, finish.token);
    expect(persistence.writeCount, writesAfterSibling);
    expect(duplicateFinish.state.attempts.length, attemptsBeforeDuplicate);
    expect(
        duplicateFinish.state.completions.length, completionsBeforeDuplicate);
    expect(state.slots[sibling]!.latestReceipt.sectionId, sibling);
  });

  test('aggregate capacity rejects without trimming or writing a candidate',
      () async {
    final persistence = FakeLearningPersistence();
    const limits = SentenceHuntLearningLimits(maxAggregateEntries: 1);
    final store = _repository(persistence, limits: limits);
    final started = await _start(store, fixtureSectionIds.first);
    var state = await store.load();
    await store.submit(_answerCommand(store, state, fixtureSectionIds.first));
    state = await store.load();
    await store.submit(_prepare(store, state, fixtureSectionIds.first,
        const AdvanceSentenceHuntItem()));
    state = await store.load();
    final String? bytesBefore = persistence.platform[store.scope.storageKey];
    final int writesBefore = persistence.writeCount;

    expect(
      () => _answerCommand(store, state, fixtureSectionIds.first),
      throwsA(isA<SentenceHuntCapacityException>()),
    );

    final reread = await store.load();
    expect(reread.revision, state.revision);
    expect(reread.commitOrdinal, state.commitOrdinal);
    expect(reread.summaries, hasLength(1));
    expect(persistence.writeCount, writesBefore);
    expect(persistence.platform[store.scope.storageKey], bytesBefore);
    expect(started.state.revision, 1);
  });

  test('injected codec byte limit rejects before persistence write', () async {
    final persistence = FakeLearningPersistence();
    final store = _repository(
      persistence,
      limits: const SentenceHuntLearningLimits(maxDocumentBytes: 128),
    );
    final state = await store.load();
    final start = _prepareStart(store, state, fixtureSectionIds.first,
        sessionId: 'too-large-for-injected-codec');
    final int writesBefore = persistence.writeCount;

    await expectLater(
        store.submit(start), throwsA(isA<SentenceHuntUnavailableException>()));

    expect(persistence.writeCount, writesBefore);
    expect(persistence.platform, isEmpty);
    expect(persistence.cache, isEmpty);
  });

  test(
      'unsupported and corrupt sentence bytes stay exact while real v2 and comparison siblings load',
      () async {
    final persistence = FakeLearningPersistence();
    final owner = LearningOwner.account(_ownerId);
    final auth = LearningAuthScope(owner: owner, generation: 4, ready: true);
    final sentence = _repository(persistence);
    final v2 = CourseLearningRepository(
      scope: LearningScope(courseId: 'en-fr', owner: owner),
      authGeneration: auth.generation,
      currentAuth: () => auth,
      backendOwner: () => owner,
      persistence: persistence,
      transitions: LearningTransitionEngine(LearningRegistry.french()),
      clock: () => _time,
      newToken: _nextToken,
      random: _random(),
    );
    final comparison = ComparisonLearningRepository(
      scope: ComparisonProfileScope(courseId: 'en-fr', owner: owner),
      authGeneration: auth.generation,
      currentAuth: () => auth,
      backendOwner: () => owner,
      persistence: persistence,
      transitions: ComparisonLearningTransitionEngine(
          catalogue: loadFrenchComparisonCatalogue()),
      clock: () => _time,
      newToken: _nextToken,
    );
    final v2Initial = await v2.load();
    await v2.submit(v2.prepare(
        state: v2Initial,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions())));
    final comparisonInitial = await comparison.load();
    await comparison.submit(comparison.prepare(
        state: comparisonInitial,
        activityId: comparisonActivityId,
        action: StartComparisonRun(
            sessionId: 'real-comparison-sibling', policy: LessonPolicy())));
    final String v2Key = v2.scope.storageKey;
    final String comparisonKey = comparison.scope.storageKey;
    final String v2Bytes = persistence.platform[v2Key]!;
    final String comparisonBytes = persistence.platform[comparisonKey]!;

    for (final String unavailable in <String>[
      '{"schemaVersion":2,"opaque":"do-not-rewrite"}',
      '{not-json-and-must-remain-byte-identical',
    ]) {
      persistence
        ..platform[sentence.scope.storageKey] = unavailable
        ..cache[sentence.scope.storageKey] = unavailable;
      await expectLater(
          sentence.load(), throwsA(isA<SentenceHuntUnavailableException>()));
      expect(persistence.platform[sentence.scope.storageKey], unavailable);
      expect(persistence.cache[sentence.scope.storageKey], unavailable);
      expect((await v2.load()).revision, 1);
      expect((await comparison.load()).revision, 1);
      expect(persistence.platform[v2Key], v2Bytes);
      expect(persistence.platform[comparisonKey], comparisonBytes);
    }
    expect(
        persistence.platform.keys.toSet(),
        <String>{
          sentence.scope.storageKey,
          v2Key,
          comparisonKey,
        },
        reason: 'no outbox or extra family key is created');
  });

  test('unknown checkpoint identity and oversized input remain byte-identical',
      () async {
    final persistence = FakeLearningPersistence();
    final store = _repository(persistence);
    final empty = await store.load();
    await store.submit(_prepareStart(store, empty, fixtureSectionIds.first,
        sessionId: 'unknown-checkpoint'));
    final raw = persistence.platform[store.scope.storageKey]!;
    final Map<String, dynamic> document =
        jsonDecode(raw) as Map<String, dynamic>;
    final Map<String, dynamic> slots =
        document['slots'] as Map<String, dynamic>;
    final Map<String, dynamic> slot =
        slots[fixtureSectionIds.first] as Map<String, dynamic>;
    final Map<String, dynamic> checkpoint =
        slot['checkpoint'] as Map<String, dynamic>;
    checkpoint['sectionFingerprint'] = '{"unknown":"descriptor"}';
    final String unknownIdentityBytes = jsonEncode(document);
    persistence
      ..platform[store.scope.storageKey] = unknownIdentityBytes
      ..cache[store.scope.storageKey] = unknownIdentityBytes;

    await expectLater(
        store.load(), throwsA(isA<SentenceHuntUnavailableException>()));
    expect(persistence.platform[store.scope.storageKey], unknownIdentityBytes);
    expect(persistence.cache[store.scope.storageKey], unknownIdentityBytes);

    final smallCodecStore = _repository(
      persistence,
      limits: const SentenceHuntLearningLimits(maxDocumentBytes: 128),
    );
    final String oversized = List<String>.filled(129, 'x').join();
    persistence
      ..platform[smallCodecStore.scope.storageKey] = oversized
      ..cache[smallCodecStore.scope.storageKey] = oversized;
    await expectLater(smallCodecStore.load(),
        throwsA(isA<SentenceHuntUnavailableException>()));
    expect(persistence.platform[smallCodecStore.scope.storageKey], oversized);
    expect(persistence.cache[smallCodecStore.scope.storageKey], oversized);
  });

  test(
      'shared persistence serializes families and an old held scope writes only its captured owner',
      () async {
    final persistence = FakeLearningPersistence();
    final ownerA = LearningOwner.account('sentence-owner-a');
    var auth = LearningAuthScope(owner: ownerA, generation: 4, ready: true);
    var backendOwner = ownerA;
    final sentence = _repository(
      persistence,
      owner: ownerA,
      auth: () => auth,
      backendOwner: () => backendOwner,
    );
    final v2 = CourseLearningRepository(
      scope: LearningScope(courseId: 'en-fr', owner: ownerA),
      authGeneration: 4,
      currentAuth: () => auth,
      backendOwner: () => backendOwner,
      persistence: persistence,
      transitions: LearningTransitionEngine(LearningRegistry.french()),
      clock: () => _time,
      newToken: _nextToken,
      random: _random(),
    );
    final comparison = ComparisonLearningRepository(
      scope: ComparisonProfileScope(courseId: 'en-fr', owner: ownerA),
      authGeneration: 4,
      currentAuth: () => auth,
      backendOwner: () => backendOwner,
      persistence: persistence,
      transitions: ComparisonLearningTransitionEngine(
          catalogue: loadFrenchComparisonCatalogue()),
      clock: () => _time,
      newToken: _nextToken,
    );
    final v2Initial = await v2.load();
    await v2.submit(v2.prepare(
        state: v2Initial,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions())));
    final comparisonInitial = await comparison.load();
    await comparison.submit(comparison.prepare(
        state: comparisonInitial,
        activityId: comparisonActivityId,
        action: StartComparisonRun(
            sessionId: 'serial-comparison', policy: LessonPolicy())));
    final state = await sentence.load();
    final command = _prepareStart(sentence, state, fixtureSectionIds.first,
        sessionId: 'captured-owner-a');
    persistence.holdNextWrite();
    final saving = sentence.submit(command);
    await persistence.writeEntered;
    var v2LoadCompleted = false;
    var comparisonLoadCompleted = false;
    final v2Load = v2.load().then((CourseLearningState value) {
      v2LoadCompleted = true;
      return value;
    });
    final comparisonLoad = comparison.load().then((value) {
      comparisonLoadCompleted = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(v2LoadCompleted, isFalse,
        reason:
            'sentence and v2 documents use the process-global transaction tail');
    expect(comparisonLoadCompleted, isFalse,
        reason: 'comparison joins the same process-global transaction tail');

    final ownerB = LearningOwner.account('sentence-owner-b');
    auth = LearningAuthScope(owner: ownerB, generation: 5, ready: true);
    backendOwner = ownerB;
    persistence.releaseWrite(persist: true);
    final committed = await saving;
    expect((await v2Load).revision, 1);
    expect((await comparisonLoad).revision, 1);
    expect(committed.state.scope.owner, ownerA);
    expect(persistence.platform, contains(storeKey(ownerA)));
    expect(persistence.platform, isNot(contains(storeKey(ownerB))));
    expect(persistence.platform, contains(v2.scope.storageKey));
  });

  test('stale section cursors and auth owners cannot commit', () async {
    final persistence = FakeLearningPersistence();
    final owner = LearningOwner.account(_ownerId);
    var auth = LearningAuthScope(owner: owner, generation: 4, ready: true);
    final store = _repository(persistence, auth: () => auth);
    final empty = await store.load();
    final start = _prepareStart(store, empty, fixtureSectionIds.first,
        sessionId: 'cursor-guard');
    await store.submit(start);

    final stale = SentenceHuntLearningCommand(
      scope: store.scope,
      authGeneration: 4,
      sectionId: start.sectionId,
      sectionFingerprint: start.sectionFingerprint,
      expected: start.expected,
      token: _nextToken(),
      submittedAt: _time,
      action: const AdvanceSentenceHuntItem(),
    );
    await expectLater(
        store.submit(stale), throwsA(isA<LearningConflictException>()));
    final wrongOwner = SentenceHuntLearningCommand(
      scope: SentenceHuntProfileScope(
          courseId: 'en-fr', owner: LearningOwner.account('wrong-owner')),
      authGeneration: 4,
      sectionId: start.sectionId,
      sectionFingerprint: start.sectionFingerprint,
      expected:
          const LearningCursorPosition(generation: 0, sequence: 0, revision: 0),
      token: _nextToken(),
      submittedAt: _time,
      action: StartSentenceHuntRun(
          sessionId: 'wrong-owner',
          policy: _catalogue.section(start.sectionId).policy,
          mode: SentenceHuntRunMode.practice),
    );
    await expectLater(store.submit(wrongOwner),
        throwsA(isA<LearningOwnerChangedException>()));
    auth = LearningAuthScope(owner: owner, generation: 5, ready: true);
    await expectLater(
        store.submit(start), throwsA(isA<LearningOwnerChangedException>()));
    expect(persistence.writeCount, 1);
  });

  test('restore failure quarantines only this key until verified retryLoad',
      () async {
    final persistence = FakeLearningPersistence();
    final store = _repository(persistence);
    final owner = LearningOwner.account(_ownerId);
    final auth = LearningAuthScope(owner: owner, generation: 4, ready: true);
    final v2 = CourseLearningRepository(
      scope: LearningScope(courseId: 'en-fr', owner: owner),
      authGeneration: auth.generation,
      currentAuth: () => auth,
      backendOwner: () => owner,
      persistence: persistence,
      transitions: LearningTransitionEngine(LearningRegistry.french()),
      clock: () => _time,
      newToken: _nextToken,
      random: _random(),
    );
    final v2Initial = await v2.load();
    await v2.submit(v2.prepare(
        state: v2Initial,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions())));
    final started = await _start(store, fixtureSectionIds.first);
    final state = await store.load();
    final answer = _answerCommand(store, state, fixtureSectionIds.first);
    final String committedBytes = persistence.platform[store.scope.storageKey]!;
    persistence
      ..restoreFailure = StateError('restore rejected')
      ..holdNextWrite();
    final saving = store.submit(answer);
    await persistence.writeEntered;
    persistence.releaseWrite(persist: false);
    await expectLater(saving, throwsA(isA<LearningSaveException>()));
    await expectLater(
        store.load(), throwsA(isA<LearningUnavailableException>()));
    expect(persistence.platform[store.scope.storageKey], committedBytes);
    expect((await v2.load()).revision, 1,
        reason: 'quarantine is scoped to the sentence document key');

    persistence.restoreFailure = null;
    final recovered = await store.retryLoad();
    expect(recovered.revision, started.state.revision);
    expect(recovered.attempts, isEmpty);
    expect(persistence.cache[store.scope.storageKey], committedBytes);
    expect(persistence.platform[store.scope.storageKey], committedBytes);
  });

  test('PreferencesLearningPersistence round-trips through the plugin mock',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(
        () => SharedPreferences.setMockInitialValues(<String, Object>{}));
    final owner = LearningOwner.account('preferences-plugin-mock');
    final first = _preferencesRepository(owner);
    final initial = await first.load();
    final committed = await first.submit(_prepareStart(
        first, initial, fixtureSectionIds.first,
        sessionId: 'plugin-mock-roundtrip'));
    final raw = (await SharedPreferences.getInstance())
        .getString(first.scope.storageKey);
    expect(raw, isNotNull);

    final peer = _preferencesRepository(owner);
    final reloaded = await peer.load();
    expect(reloaded.revision, committed.state.revision);
    expect(reloaded.slots.keys, contains(fixtureSectionIds.first));
    expect(raw, isNotEmpty);
  });

  test(
      'false and throwing SharedPreferences quota writes restore optimistic cache',
      () async {
    for (final _QuotaFailure failure in _QuotaFailure.values) {
      final platform = _QuotaPreferences();
      SharedPreferencesStorePlatform.instance = platform;
      SharedPreferences.resetStatic();
      addTearDown(
          () => SharedPreferences.setMockInitialValues(<String, Object>{}));
      final owner = LearningOwner.account('quota-${failure.name}');
      final store = _preferencesRepository(owner);
      final started = await _start(store, fixtureSectionIds.first);
      final state = await store.load();
      final answer = _answerCommand(store, state, fixtureSectionIds.first);
      final String key = store.scope.storageKey;
      final String oldBytes =
          (await SharedPreferences.getInstance()).getString(key)!;
      platform.begin(failure);

      final saving = store.submit(answer);
      await platform.entered!.future;
      final String optimistic =
          (await SharedPreferences.getInstance()).getString(key)!;
      expect(optimistic, isNot(oldBytes),
          reason:
              'SharedPreferences mutates its plugin cache before platform ACK');
      platform.release();
      await expectLater(saving, throwsA(isA<LearningSaveException>()));

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(key), oldBytes);
      await preferences.reload();
      expect(preferences.getString(key), oldBytes);
      expect((await store.load()).revision, started.state.revision);
      expect((await store.load()).attempts, isEmpty);
    }
  });
}

enum _HeldStage { start, answer, advanceToDebrief, finish }

enum _QuotaFailure { falseResult, throws }

final class _PreparedStage {
  const _PreparedStage({
    required this.state,
    required this.command,
    required this.attemptsBefore,
    required this.completionsBefore,
  });

  final SentenceHuntState state;
  final SentenceHuntCommand command;
  final int attemptsBefore;
  final int completionsBefore;
}

Future<_PreparedStage> _prepareStage(
    SentenceHuntLearningStore store, _HeldStage stage) async {
  final String sectionId = fixtureSectionIds.first;
  switch (stage) {
    case _HeldStage.start:
      final state = await store.load();
      return _PreparedStage(
        state: state,
        command:
            _prepareStart(store, state, sectionId, sessionId: 'held-start'),
        attemptsBefore: state.attempts.length,
        completionsBefore: state.completions.length,
      );
    case _HeldStage.answer:
      await _start(store, sectionId);
      final state = await store.load();
      return _PreparedStage(
        state: state,
        command: _answerCommand(store, state, sectionId),
        attemptsBefore: state.attempts.length,
        completionsBefore: state.completions.length,
      );
    case _HeldStage.advanceToDebrief:
      final state = await _stateBeforeDebriefAdvance(store, sectionId);
      return _PreparedStage(
        state: state,
        command:
            _prepare(store, state, sectionId, const AdvanceSentenceHuntItem()),
        attemptsBefore: state.attempts.length,
        completionsBefore: state.completions.length,
      );
    case _HeldStage.finish:
      final state = await _stateAtDebrief(store, sectionId);
      return _PreparedStage(
        state: state,
        command:
            _prepare(store, state, sectionId, const FinishSentenceHuntRun()),
        attemptsBefore: state.attempts.length,
        completionsBefore: state.completions.length,
      );
  }
}

Future<SentenceHuntCommit> _start(
    SentenceHuntLearningStore store, String sectionId) async {
  final state = await store.load();
  return store.submit(_prepareStart(store, state, sectionId,
      sessionId: 'run-${sectionId.split('-').last}'));
}

Future<SentenceHuntState> _stateBeforeDebriefAdvance(
    SentenceHuntLearningStore store, String sectionId) async {
  await _start(store, sectionId);
  for (var index = 0; index < 5; index++) {
    var state = await store.load();
    await store.submit(_answerCommand(store, state, sectionId));
    state = await store.load();
    if (index == 4) return state;
    await store.submit(
        _prepare(store, state, sectionId, const AdvanceSentenceHuntItem()));
  }
  throw StateError('unreachable');
}

Future<SentenceHuntState> _stateAtDebrief(
    SentenceHuntLearningStore store, String sectionId,
    {bool startRun = true}) async {
  if (startRun) await _start(store, sectionId);
  for (var index = 0; index < 5; index++) {
    var state = await store.load();
    await store.submit(_answerCommand(store, state, sectionId));
    state = await store.load();
    await store.submit(
        _prepare(store, state, sectionId, const AdvanceSentenceHuntItem()));
  }
  return store.load();
}

Future<SentenceHuntCommand> _finishCommand(
  SentenceHuntLearningStore store, {
  required String sectionId,
  required bool alreadyStarted,
}) async {
  final state =
      await _stateAtDebrief(store, sectionId, startRun: !alreadyStarted);
  return _prepare(store, state, sectionId, const FinishSentenceHuntRun());
}

SentenceHuntCommand _prepareStart(
  SentenceHuntLearningStore store,
  SentenceHuntState state,
  String sectionId, {
  required String sessionId,
}) =>
    store.prepare(
      state: state,
      sectionId: sectionId,
      action: StartSentenceHuntRun(
        sessionId: sessionId,
        policy: _catalogue.section(sectionId).policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );

SentenceHuntCommand _answerCommand(
  SentenceHuntLearningStore store,
  SentenceHuntState state,
  String sectionId,
) {
  final SentenceHuntSlot slot = state.slots[sectionId]!;
  final List<Object?> itemIds =
      slot.checkpoint.sessionJson['itemIds']! as List<Object?>;
  final int position = slot.checkpoint.sessionJson['position']! as int;
  final SentenceHuntItem item =
      _catalogue.item(sectionId, itemIds[position]! as String);
  final int round = slot.checkpoint.sessionJson['round']! as int;
  final SentenceHuntPlaybackObservation playback =
      SentenceHuntPlaybackObservation(
    scope: store.scope,
    content: item.identity,
    runGeneration: slot.cursor.generation,
    round: round,
    uiGeneration: 7,
    referenceId: item.identity.audioRefId,
    outcome: CourseAudioOutcome.completed,
    source: CourseAudioSource.reviewedRecording,
  );
  return _prepare(
    store,
    state,
    sectionId,
    AnswerSentenceHuntItem(SentenceHuntAnswer(
      content: item.identity,
      selectedTokenIds: item.expectedTokenIds,
      expectedTokenIdsSnapshot: item.expectedTokenIds,
      playback: playback,
    )),
  );
}

SentenceHuntCommand _prepare(
  SentenceHuntLearningStore store,
  SentenceHuntState state,
  String sectionId,
  SentenceHuntAction action,
) =>
    store.prepare(state: state, sectionId: sectionId, action: action);

SentenceHuntLearningRepository _repository(
  LearningPersistence persistence, {
  LearningOwner? owner,
  LearningAuthScope Function()? auth,
  LearningOwner Function()? backendOwner,
  int historyLimit = 2000,
  SentenceHuntLearningLimits limits = const SentenceHuntLearningLimits(),
  void Function()? onCommitted,
}) {
  final LearningOwner selectedOwner = owner ?? LearningOwner.account(_ownerId);
  final LearningAuthScope selectedAuth =
      LearningAuthScope(owner: selectedOwner, generation: 4, ready: true);
  return SentenceHuntLearningRepository(
    scope: SentenceHuntProfileScope(courseId: 'en-fr', owner: selectedOwner),
    authGeneration: 4,
    currentAuth: auth ?? () => selectedAuth,
    backendOwner: backendOwner ?? () => selectedOwner,
    persistence: persistence,
    transitions:
        SentenceHuntTransitionEngine(catalogue: _catalogue, limits: limits),
    clock: () => _time,
    newToken: _nextToken,
    onCommitted: onCommitted,
    historyLimit: historyLimit,
  );
}

SentenceHuntLearningRepository _preferencesRepository(LearningOwner owner) =>
    _repository(PreferencesLearningPersistence(), owner: owner);

String _nextToken() =>
    'sht${(++_tokenNumber).toRadixString(36).padLeft(19, '0')}';

Random _random() => Random(41);

String storeKey(LearningOwner owner) =>
    SentenceHuntProfileScope(courseId: 'en-fr', owner: owner).storageKey;

final class _QuotaPreferences extends InMemorySharedPreferencesStore {
  _QuotaPreferences() : super.withData(<String, Object>{});

  Completer<void>? entered;
  Completer<void>? gate;
  _QuotaFailure? failure;

  void begin(_QuotaFailure selected) {
    failure = selected;
    entered = Completer<void>();
    gate = Completer<void>();
  }

  void release() {
    if (!gate!.isCompleted) gate!.complete();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final selected = failure;
    if (selected != null) {
      failure = null;
      entered!.complete();
      await gate!.future;
      if (selected == _QuotaFailure.falseResult) return false;
      throw StateError('simulated SharedPreferences QuotaExceededError');
    }
    return super.setValue(valueType, key, value);
  }
}
