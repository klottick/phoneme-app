import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/learning_storage_types.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_codec.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';
import '../support/sentence_hunt_fixtures.dart';

void main() {
  test('sentence profile has the exact isolated storage key and value identity',
      () {
    final guest = SentenceHuntProfileScope(
        courseId: 'en-fr', owner: LearningOwner.guest());
    final account = SentenceHuntProfileScope(
        courseId: 'en-fr', owner: LearningOwner.account('acct-1'));

    expect(guest.storageKey, 'course.learning.sentence-hunt.v1.ZW4tZnI.g');
    expect(account.storageKey,
        'course.learning.sentence-hunt.v1.ZW4tZnI.a.YWNjdC0x');
    expect(
        guest,
        equals(SentenceHuntProfileScope(
            courseId: 'en-fr', owner: LearningOwner.guest())));
    expect(guest, isNot(account));
  });

  test('contracted SentenceHuntState and SentenceHuntCommand aliases work', () {
    final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    final SentenceHuntState empty = SentenceHuntState.empty(scope);
    final SentenceHuntState constructed = SentenceHuntState(
      scope: scope,
      revision: empty.revision,
      commitOrdinal: empty.commitOrdinal,
      slots: empty.slots,
      attempts: empty.attempts,
      receipts: empty.receipts,
      mistakes: empty.mistakes,
      summaries: empty.summaries,
      completions: empty.completions,
      teachingExposure: empty.teachingExposure,
    );
    final SentenceHuntCatalogue catalogue = syntheticSentenceCatalogue();
    final SentenceHuntTransitionEngine engine =
        SentenceHuntTransitionEngine(catalogue: catalogue);
    final SentenceHuntCommand prepared = engine.prepare(
      state: empty,
      sectionId: fixtureSectionIds.first,
      action: StartSentenceHuntRun(
        sessionId: 'contract-api-run',
        policy: catalogue.section(fixtureSectionIds.first).policy,
        mode: SentenceHuntRunMode.practice,
      ),
      authGeneration: 0,
      token: 'contractprepared000000',
      submittedAt: DateTime.utc(2026),
    );
    final SentenceHuntCommand direct = SentenceHuntCommand(
      scope: scope,
      authGeneration: 0,
      sectionId: fixtureSectionIds.first,
      sectionFingerprint:
          catalogue.section(fixtureSectionIds.first).sectionFingerprint,
      expected:
          const LearningCursorPosition(generation: 0, sequence: 0, revision: 0),
      expectedScopeRevision: 0,
      token: 'contractdirect00000000',
      submittedAt: DateTime.utc(2026),
      action: StartSentenceHuntRun(
        sessionId: 'contract-api-direct',
        policy: catalogue.section(fixtureSectionIds.first).policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    expect(codec.canonicalCommand(prepared), isNotEmpty);
    expect(codec.canonicalCommand(direct), isNotEmpty);
    expect(codec.encode(constructed), codec.encode(empty));

    final SentenceHuntTransition transition = engine.evaluate(
      state: empty,
      command: direct,
      committedAt: DateTime.utc(2026),
    );
    final SentenceHuntState next = transition.nextState;
    final String raw = codec.encode(next);
    final SentenceHuntState restored = codec.decode(raw, scope, catalogue);
    expect(restored.slots.values.single.checkpoint.sessionId,
        'contract-api-direct');
    expect(codec.encode(restored), raw);
  });

  test('sentence_hunt_command_captures_scope_revision', () {
    final _Driver driver = _Driver();
    final String sectionId = fixtureSectionIds.first;
    driver.start(0);
    driver.answerCurrent(sectionId);
    final SentenceHuntLearningState state = driver.state;
    final SentenceHuntSection section = driver.catalogue.section(sectionId);
    final SentenceHuntLearningCommand command = driver.engine.prepare(
      state: state,
      sectionId: sectionId,
      action: const AdvanceSentenceHuntItem(),
      authGeneration: 0,
      token: 'abcdefghijklmnopqrstuv',
      submittedAt: DateTime.utc(2026)
    );

    expect(command.expectedScopeRevision, state.revision);
    final canonical =
        jsonDecode(sentenceHuntLearningSqlCanonicalCommand(command))
            as Map<String, dynamic>;
    expect(canonical['activityId'], command.sectionId);
    expect(canonical['expectedScopeRevision'], state.revision);
    SentenceHuntLearningCommand withScopeRevision(int revision) =>
        SentenceHuntLearningCommand(
          scope: command.scope,
          authGeneration: command.authGeneration,
          sectionId: command.sectionId,
          sectionFingerprint: command.sectionFingerprint,
          expected: command.expected,
          expectedScopeRevision: revision,
          token: command.token,
          submittedAt: command.submittedAt,
          action: command.action
        );
    expect(withScopeRevision(0).expectedScopeRevision, 0);
    expect(
      withScopeRevision(9007199254740991).expectedScopeRevision,
      9007199254740991
    );
    expect(() => withScopeRevision(-1), throwsArgumentError);
    expect(() => withScopeRevision(9007199254740992), throwsArgumentError);
    expect(
      sentenceHuntLearningSqlCanonicalCommand(
        withScopeRevision(state.revision + 1)
      ),
      isNot(sentenceHuntLearningSqlCanonicalCommand(command))
    );

    final legacy = sentenceHuntCanonicalCommand(command);
    expect(
      sentenceHuntCanonicalCommand(withScopeRevision(state.revision + 1)),
      legacy
    );
    expect(
      legacy,
      '{"schemaVersion":1,"family":"sentence-hunt","courseId":"en-fr",'
      '"owner":{"kind":"guest","userId":null},"authGeneration":0,'
      '"sectionId":"$sectionId",'
      '"sectionFingerprint":${jsonEncode(section.sectionFingerprint)},'
      '"generation":1,"sequence":2,"revision":1,'
      '"token":"abcdefghijklmnopqrstuv",'
      '"submittedAt":"2026-01-01T00:00:00.000Z",'
      '"action":{"kind":"advance"}}'
    );
    final legacyFields = (jsonDecode(legacy) as Map<String, dynamic>).keys;
    expect(legacyFields, contains('sectionId'));
    expect(legacyFields, isNot(contains('expectedScopeRevision')));
    expect(legacyFields, isNot(contains('activityId')));
  });

  test('sentence_start_creates_only_registered_independent_slot', () {
    final _Driver driver = _Driver();
    driver.start(0);

    expect(driver.state.slots.keys, <String>[fixtureSectionIds.first]);
    final SentenceHuntSlot slot = driver.state.slots.values.single;
    expect(slot.cursor.generation, 1);
    expect(slot.cursor.sequence, 1);
    expect(slot.cursor.revision, 0);
    expect(slot.checkpoint.sessionId, 'run-0');
    expect(slot.checkpoint.mode, SentenceHuntRunMode.practice);
    expect(slot.checkpoint.finished, isFalse);
  });

  test(
      'sentence_practice_start_requires_registered_policy_for_prepare_and_evaluate',
      () {
    final _Driver driver = _Driver();
    final SentenceHuntLearningState empty = driver.state;
    final StartSentenceHuntRun forgedStart = StartSentenceHuntRun(
      sessionId: 'forged-policy',
      policy: LessonPolicy(completionThresholdPercent: 1),
      mode: SentenceHuntRunMode.practice,
    );

    final bool prepareRejected = _throwsArgumentError(
      () => driver.engine.prepare(
        state: empty,
        sectionId: fixtureSectionIds.first,
        action: forgedStart,
        authGeneration: 0,
        token: 'policy0000000000000000',
        submittedAt: driver.now(),
      ),
    );
    final bool evaluateRejected = _throwsArgumentError(
      () => driver.engine.evaluate(
        state: empty,
        command: driver.command(
          sectionId: fixtureSectionIds.first,
          action: forgedStart,
        ),
        committedAt: driver.now(),
      ),
    );
    expect(identical(driver.state, empty), isTrue);
    expect(_stateSnapshot(driver.state), _stateSnapshot(empty));
    expect(<bool>[prepareRejected, evaluateRejected], everyElement(isTrue));
  });

  test('sentence_versioned_registered_policy_remains_finishable', () {
    final SentenceHuntCatalogue versioned = _catalogueWithVersionedPolicy();
    expect(versioned.section(fixtureSectionIds.first).policyRevision, 2);
    expect(
        versioned
            .section(fixtureSectionIds.first)
            .policy
            .completionThresholdPercent,
        70);
    final _Driver versionedDriver = _Driver(catalogue: versioned);
    versionedDriver.start(0);
    for (var index = 0; index < 5; index++) {
      versionedDriver.answerCurrent(fixtureSectionIds.first,
          correct: index < 4);
      versionedDriver.advance(fixtureSectionIds.first);
    }
    versionedDriver.act(fixtureSectionIds.first, const FinishSentenceHuntRun());
    expect(versionedDriver.state.completions, hasLength(1));
    expect(versionedDriver.state.completions.single.policyRevision, 2);
    expect(versionedDriver.state.completions.single.thresholdPercent, 70);
  });

  test('sentence_practice_start_cannot_replace_stale_finished_or_active_slot',
      () {
    final List<String> failures = <String>[];
    for (final String checkpointStatus in <String>['unfinished', 'finished']) {
      final _Driver original = _Driver();
      original.start(0);
      if (checkpointStatus == 'finished') {
        for (var index = 0; index < 5; index++) {
          original.answerCurrent(fixtureSectionIds.first);
          original.advance(fixtureSectionIds.first);
        }
        original.act(fixtureSectionIds.first, const FinishSentenceHuntRun());
      }
      final SentenceHuntLearningState prior = original.state;
      final String before = _stateSnapshot(prior);

      for (final String identityChange in <String>[
        'key',
        'context',
        'annotation',
        'asset',
      ]) {
        final SentenceHuntCatalogue changed =
            _catalogueWithFingerprintMutation(identityChange);
        final SentenceHuntSection oldSection =
            original.catalogue.section(fixtureSectionIds.first);
        final SentenceHuntSection newSection =
            changed.section(fixtureSectionIds.first);
        expect(changed.isAvailable(fixtureSectionIds.first), isTrue,
            reason: identityChange);
        expect(newSection.contentRevision, oldSection.contentRevision,
            reason: identityChange);
        expect(
            newSection.sectionFingerprint, isNot(oldSection.sectionFingerprint),
            reason: identityChange);
        final StartSentenceHuntRun replacement = StartSentenceHuntRun(
          sessionId: 'replacement-$identityChange',
          policy: newSection.policy,
          mode: SentenceHuntRunMode.practice,
          replaceExisting: true,
        );
        final SentenceHuntTransitionEngine changedEngine =
            SentenceHuntTransitionEngine(catalogue: changed);

        if (!_throwsStateError(
          () => changedEngine.prepare(
            state: prior,
            sectionId: fixtureSectionIds.first,
            action: replacement,
            authGeneration: 0,
            token: 'staleprep${identityChange.padRight(13, '0')}',
            submittedAt: DateTime.utc(2026),
          ),
        )) {
          failures.add('$checkpointStatus/$identityChange prepare accepted');
        }
        if (!_throwsStateError(
          () => changedEngine.evaluate(
            state: prior,
            command: original.command(
              sectionId: fixtureSectionIds.first,
              action: replacement,
              sectionFingerprint: newSection.sectionFingerprint,
              tokenOverride: 'staleeval${identityChange.padRight(13, '0')}',
            ),
            committedAt: DateTime.utc(2026),
          ),
        )) {
          failures.add('$checkpointStatus/$identityChange evaluate accepted');
        }
        expect(identical(original.state, prior), isTrue);
        expect(_stateSnapshot(prior), before);
      }
    }

    expect(failures, isEmpty);

    final _Driver current = _Driver();
    current.start(0);
    final SentenceHuntLearningState prior = current.state;
    final SentenceHuntTransition replaced = current.act(
      fixtureSectionIds.first,
      StartSentenceHuntRun(
        sessionId: 'same-identity-replacement',
        policy: current.catalogue.section(fixtureSectionIds.first).policy,
        mode: SentenceHuntRunMode.practice,
        replaceExisting: true,
      ),
    );
    expect(replaced.slot.checkpoint.sessionId, 'same-identity-replacement');
    expect(replaced.slot.cursor.generation,
        prior.slots.values.single.cursor.generation + 1);
    expect(replaced.nextState.attempts, prior.attempts);
  });

  test('sentence_answer_prepare_and_direct_evaluate_reject_forged_matrix', () {
    final _Driver driver = _Driver();
    driver.start(0);
    final String sectionId = fixtureSectionIds.first;
    final SentenceHuntSlot slot = driver.state.slots[sectionId]!;
    final SentenceHuntItem item =
        driver.catalogue.item(sectionId, driver.session(slot).currentItemId!);
    final SentenceHuntContentIdentity wrongAnnotation = _copyIdentity(
        item.identity,
        annotationHash: List<String>.filled(64, 'a').join());
    final SentenceHuntContentIdentity wrongSection =
        _copyIdentity(item.identity, sectionId: fixtureSectionIds[1]);
    final SentenceHuntPlaybackObservation goodPlayback =
        driver.playback(slot, item);
    final List<({String name, SentenceHuntAnswer answer})> forged =
        <({String name, SentenceHuntAnswer answer})>[
      (
        name: 'unknown selection',
        answer: driver
            .answer(item, slot, selected: <String>['not-a-selectable-token']),
      ),
      (
        name: 'non-word selection',
        answer: driver
            .answer(item, slot, selected: <String>[item.identity.sentenceId]),
      ),
      (
        name: 'duplicate selection',
        answer: driver.answer(item, slot, selected: <String>[
          item.expectedTokenIds.first,
          item.expectedTokenIds.first,
        ]),
      ),
      (
        name: 'wrong item identity',
        answer: driver.answer(item, slot, content: wrongSection),
      ),
      (
        name: 'wrong annotation key',
        answer: driver.answer(item, slot, content: wrongAnnotation),
      ),
      (
        name: 'wrong expected-key snapshot',
        answer: driver.answer(item, slot,
            expectedSnapshot: item.expectedTokenIds.take(1).toList()),
      ),
      (
        name: 'wrong audio reference',
        answer: driver.answer(item, slot,
            playback: driver.playback(slot, item, referenceId: 'other-audio')),
      ),
      (
        name: 'cancelled playback',
        answer: driver.answer(item, slot,
            playback: driver.playback(slot, item,
                outcome: CourseAudioOutcome.cancelled)),
      ),
      (
        name: 'failed playback',
        answer: driver.answer(item, slot,
            playback: driver.playback(slot, item,
                outcome: CourseAudioOutcome.failed)),
      ),
      (
        name: 'unverified source',
        answer: driver.answer(item, slot,
            playback: driver.playback(slot, item,
                source: CourseAudioSource.unverifiedRecording)),
      ),
      (
        name: 'practice TTS source',
        answer: driver.answer(item, slot,
            playback: driver.playback(slot, item,
                source: CourseAudioSource.practiceTts)),
      ),
      (
        name: 'playback scope mismatch',
        answer: driver.answer(item, slot,
            playback: driver.playback(
              slot,
              item,
              scope: SentenceHuntProfileScope(
                  courseId: 'en-fr', owner: LearningOwner.account('other')),
            )),
      ),
      (
        name: 'playback run mismatch',
        answer: driver.answer(item, slot,
            playback: driver.playback(slot, item,
                runGeneration: slot.cursor.generation + 1)),
      ),
      (
        name: 'playback round mismatch',
        answer: driver.answer(item, slot,
            playback: driver.playback(slot, item,
                round: driver.session(slot).round + 1)),
      ),
    ];

    final SentenceHuntLearningState validBefore = driver.state;
    final String validSnapshot = _stateSnapshot(validBefore);
    final SentenceHuntLearningCommand validCommand = driver.engine.prepare(
      state: validBefore,
      sectionId: sectionId,
      action: AnswerSentenceHuntItem(driver.answer(item, slot)),
      authGeneration: 0,
      token: driver.token(),
      submittedAt: driver.now(),
    );
    expect(validCommand.action, isA<AnswerSentenceHuntItem>());
    expect(identical(driver.state, validBefore), isTrue);
    expect(_stateSnapshot(validBefore), validSnapshot,
        reason: 'prepare must leave the source snapshot unchanged');
    final SentenceHuntTransition validTransition = driver.engine.evaluate(
      state: validBefore,
      command: validCommand,
      committedAt: driver.now(),
    );
    expect(validTransition.attempts.single.correct, isTrue);
    expect(identical(driver.state, validBefore), isTrue);
    expect(_stateSnapshot(validBefore), validSnapshot,
        reason: 'evaluate must leave the source snapshot unchanged');

    for (final ({String name, SentenceHuntAnswer answer}) row in forged) {
      final SentenceHuntLearningState before = driver.state;
      final String snapshot = _stateSnapshot(before);
      expect(
        () => driver.engine.prepare(
          state: before,
          sectionId: sectionId,
          action: AnswerSentenceHuntItem(row.answer),
          authGeneration: 0,
          token: 'forgedprep${forged.indexOf(row).toString().padLeft(12, '0')}',
          submittedAt: driver.now(),
        ),
        throwsA(isA<ArgumentError>()),
        reason: '${row.name} prepare',
      );
      expect(
        () => driver.engine.evaluate(
          state: before,
          command: driver.command(
            sectionId: sectionId,
            action: AnswerSentenceHuntItem(row.answer),
            tokenOverride:
                'forgedeval${forged.indexOf(row).toString().padLeft(12, '0')}',
          ),
          committedAt: driver.now(),
        ),
        throwsA(isA<ArgumentError>()),
        reason: '${row.name} direct evaluate',
      );
      expect(identical(driver.state, before), isTrue, reason: row.name);
      expect(_stateSnapshot(before), snapshot, reason: row.name);
    }

    final SentenceHuntLearningState beforeScopeMismatch = driver.state;
    expect(
      () => driver.engine.evaluate(
        state: beforeScopeMismatch,
        command: driver.command(
          sectionId: sectionId,
          action: AnswerSentenceHuntItem(driver.answer(item, slot)),
          commandScope: SentenceHuntProfileScope(
              courseId: 'en-fr', owner: LearningOwner.account('other')),
        ),
        committedAt: driver.now(),
      ),
      throwsArgumentError,
      reason: 'command owner/scope mismatch is rejected by evaluate',
    );
    expect(identical(driver.state, beforeScopeMismatch), isTrue);

    final SentenceHuntLearningCommand staleCursor = driver.command(
      sectionId: sectionId,
      action: AnswerSentenceHuntItem(driver.answer(item, slot)),
      expected:
          const LearningCursorPosition(generation: 0, sequence: 0, revision: 0),
    );
    expect(
      () => driver.engine.evaluate(
        state: beforeScopeMismatch,
        command: staleCursor,
        committedAt: driver.now(),
      ),
      throwsArgumentError,
      reason: 'stale expected cursor is rejected by evaluate',
    );
    final SentenceHuntLearningCommand staleFingerprint = driver.command(
      sectionId: sectionId,
      action: AnswerSentenceHuntItem(driver.answer(item, slot)),
      sectionFingerprint: 'stale-content-fingerprint',
    );
    expect(
      () => driver.engine.evaluate(
        state: beforeScopeMismatch,
        command: staleFingerprint,
        committedAt: driver.now(),
      ),
      throwsArgumentError,
      reason: 'stale current content fingerprint is rejected by evaluate',
    );
    expect(
      () => SentenceHuntProfileScope(
          courseId: 'fr-fr', owner: LearningOwner.guest()),
      throwsArgumentError,
      reason: 'a foreign course identity cannot be constructed',
    );
    expect(
      () => SentenceHuntPlaybackObservation(
        scope: driver.scope,
        content: item.identity,
        runGeneration: slot.cursor.generation,
        round: driver.session(slot).round,
        uiGeneration: -1,
        referenceId: item.identity.audioRefId,
        outcome: CourseAudioOutcome.completed,
        source: CourseAudioSource.reviewedRecording,
      ),
      throwsArgumentError,
      reason: 'UI generation remains domain-bounded',
    );
    expect(
      () => driver.command(
        sectionId: sectionId,
        action: AnswerSentenceHuntItem(driver.answer(item, slot)),
        authGeneration: -1,
      ),
      throwsArgumentError,
      reason: 'auth generation remains domain-bounded',
    );

    final SentenceHuntTransition emptySelection = driver.engine.evaluate(
      state: beforeScopeMismatch,
      command: driver.command(
        sectionId: sectionId,
        action: AnswerSentenceHuntItem(
          driver.answer(item, slot, selected: const <String>[]),
        ),
      ),
      committedAt: driver.now(),
    );
    expect(emptySelection.attempts, hasLength(1));
    expect(emptySelection.attempts.single.correct, isFalse);

    final SentenceHuntTransition valid = driver.engine.evaluate(
      state: beforeScopeMismatch,
      command: driver.command(
        sectionId: sectionId,
        action: AnswerSentenceHuntItem(
          driver.answer(item, slot,
              selected: item.expectedTokenIds, playback: goodPlayback),
        ),
      ),
      committedAt: driver.now(),
    );
    expect(valid.attempts, hasLength(1));
    expect(valid.attempts.single.correct, isTrue);
    expect(valid.nextState.attempts, hasLength(1));

    final SentenceHuntTransition answered = valid;
    final SentenceHuntLearningState answeredState = answered.nextState;
    final String answeredSnapshot = _stateSnapshot(answeredState);
    final SentenceHuntLearningCommand reanswer = driver.command(
      sectionId: sectionId,
      action: AnswerSentenceHuntItem(driver.answer(item, slot)),
      expected: answeredState.slots[sectionId]!.cursor,
    );
    expect(
      () => driver.engine.evaluate(
        state: answeredState,
        command: reanswer,
        committedAt: driver.now(),
      ),
      throwsStateError,
      reason: 'the same already-answered item cannot be answered twice',
    );
    expect(_stateSnapshot(answeredState), answeredSnapshot);
  });

  test('sentence_exact_set_answer_derives_one_attempt', () {
    final _Driver driver = _Driver();
    driver.start(0);
    final SentenceHuntSlot slot = driver.state.slots[fixtureSectionIds.first]!;
    final SentenceHuntItem item = driver.catalogue
        .item(slot.sectionId, driver.session(slot).currentItemId!);
    final List<String> reversed = item.expectedTokenIds.reversed.toList();
    final SentenceHuntLearningCommand first = driver.answerCommand(
      slot,
      item,
      selected: reversed,
      tokenOverride: 'csel000000000000000000',
      submittedAt: DateTime.utc(2026),
    );
    final SentenceHuntLearningCommand second = driver.answerCommand(
      slot,
      item,
      selected: item.expectedTokenIds,
      tokenOverride: 'csel000000000000000000',
      submittedAt: DateTime.utc(2026),
    );

    expect(sentenceHuntCanonicalCommand(first),
        sentenceHuntCanonicalCommand(second));
    expect(first.action, isA<AnswerSentenceHuntItem>());
    final SentenceHuntAnswer normalized =
        (first.action as AnswerSentenceHuntItem).answer;
    expect(normalized.selectedTokenIds, item.expectedTokenIds);
    final SentenceHuntTransition result = driver.engine.evaluate(
        state: driver.state, command: first, committedAt: driver.now());
    expect(result.nextState.attempts, hasLength(1));
    expect(result.nextState.attempts.single.correct, isTrue);
    expect(result.nextState.attempts.single.selectedTokenIds,
        item.expectedTokenIds);

    expect(
        () => driver.answerCommand(
              slot,
              item,
              selected: <String>[
                item.expectedTokenIds.first,
                item.expectedTokenIds.first
              ],
            ),
        throwsArgumentError);
  });

  test('sentence_three_slots_preserve_unfinished_siblings', () {
    final _Driver driver = _Driver();
    for (var section = 0; section < fixtureSectionIds.length; section++) {
      driver.start(section);
    }
    final Map<String, String> initialSnapshots = <String, String>{
      for (final SentenceHuntSlot slot in driver.state.slots.values)
        slot.sectionId: jsonEncode(slot.checkpoint.sessionJson),
    };
    for (final String sectionId in fixtureSectionIds) {
      driver.answerCurrent(sectionId);
      driver.advance(sectionId);
    }

    expect(driver.state.slots.keys.toSet(), fixtureSectionIds.toSet());
    expect(driver.state.commitOrdinal, 9);
    for (final String sectionId in fixtureSectionIds) {
      final SentenceHuntSlot slot = driver.state.slots[sectionId]!;
      expect(slot.cursor.generation, 1);
      expect(slot.cursor.sequence, 3);
      expect(slot.cursor.revision, 2);
      final LessonSectionSession restored = driver.session(slot);
      expect(restored.currentItemId,
          fixtureItemIds[fixtureSectionIds.indexOf(sectionId)][1]);
      expect(jsonEncode(restored.toJson()), isNot(initialSnapshots[sectionId]));
    }
  });

  test('sentence_finite_remediation_can_earn_practice_completion', () {
    final _Driver driver = _Driver();
    driver.start(0);
    for (var item = 0; item < 5; item++) {
      driver.answerCurrent(fixtureSectionIds.first, correct: item >= 2);
      driver.advance(fixtureSectionIds.first);
    }
    SentenceHuntSlot slot = driver.state.slots[fixtureSectionIds.first]!;
    expect(driver.session(slot).correctCount, 3);
    expect(driver.session(slot).canComplete, isFalse);
    expect(driver.state.completions, isEmpty);

    driver.act(fixtureSectionIds.first, const ReviewSentenceHuntMistakes());
    slot = driver.state.slots[fixtureSectionIds.first]!;
    expect(driver.session(slot).queue, fixtureItemIds.first.take(2));
    driver.answerCurrent(fixtureSectionIds.first, correct: true);
    driver.advance(fixtureSectionIds.first);
    driver.answerCurrent(fixtureSectionIds.first, correct: false);
    expect(driver.session(driver.state.slots[fixtureSectionIds.first]!).queue,
        fixtureItemIds.first.take(2));
    driver.advance(fixtureSectionIds.first);
    slot = driver.state.slots[fixtureSectionIds.first]!;
    expect(driver.session(slot).phase, LessonSectionPhase.debrief);
    expect(driver.session(slot).correctCount, 4);
    expect(driver.session(slot).canComplete, isTrue);
    driver.act(fixtureSectionIds.first, const FinishSentenceHuntRun());
    expect(driver.state.completions, hasLength(1));
    expect(driver.state.slots[fixtureSectionIds.first]!.checkpoint.finished,
        isTrue);
    expect(
        driver.state.slots[fixtureSectionIds.first]!.checkpoint
            .sessionJson['phase'],
        'debrief');
  });

  test('sentence_review_only_reconstructs_real_finished_debrief', () {
    final _Driver driver = _Driver();
    driver.start(0);
    for (var item = 0; item < 5; item++) {
      driver.answerCurrent(fixtureSectionIds.first, correct: item >= 2);
      driver.advance(fixtureSectionIds.first);
    }
    driver.act(fixtureSectionIds.first, const FinishSentenceHuntRun());
    final SentenceHuntSlot finished =
        driver.state.slots[fixtureSectionIds.first]!;
    final String beforeJson = jsonEncode(finished.checkpoint.sessionJson);
    final Map<String, Object?> priorSession =
        _deepMutable(finished.checkpoint.sessionJson) as Map<String, Object?>;
    final int oldAttempts = driver.state.attempts.length;

    driver.act(
      fixtureSectionIds.first,
      StartSentenceHuntRun(
        sessionId: 'review-only-run',
        policy: finished.checkpoint.policy,
        mode: SentenceHuntRunMode.reviewOnly,
      ),
    );

    final SentenceHuntSlot review =
        driver.state.slots[fixtureSectionIds.first]!;
    expect(jsonEncode(finished.checkpoint.sessionJson), beforeJson);
    expect(priorSession['sessionId'], finished.checkpoint.sessionId);
    expect(review.checkpoint.sessionId, 'review-only-run');
    expect(review.checkpoint.mode, SentenceHuntRunMode.reviewOnly);
    expect(review.checkpoint.finished, isFalse);
    expect(review.cursor.generation, finished.cursor.generation + 1);
    expect(driver.session(review).round, 2);
    expect(driver.session(review).queue, fixtureItemIds.first.take(2));
    expect(driver.state.attempts, hasLength(oldAttempts));

    for (var index = 0; index < 2; index++) {
      driver.answerCurrent(fixtureSectionIds.first, correct: true);
      driver.advance(fixtureSectionIds.first);
    }
    expect(
        driver
            .session(driver.state.slots[fixtureSectionIds.first]!)
            .canComplete,
        isTrue);
    driver.act(fixtureSectionIds.first, const FinishSentenceHuntRun());
    expect(driver.state.slots[fixtureSectionIds.first]!.checkpoint.mode,
        SentenceHuntRunMode.reviewOnly);
    expect(driver.state.completions, isEmpty);
  });

  test('sentence_teaching_exposure_survives_new_run', () {
    final _Driver driver = _Driver();
    driver.start(0);
    for (var item = 0; item < 5; item++) {
      driver.answerCurrent(fixtureSectionIds.first);
      driver.advance(fixtureSectionIds.first);
    }
    final SentenceHuntExposureKey exposure = SentenceHuntExposureKey(
      scope: driver.scope,
      sectionId: fixtureSectionIds.first,
      contentRevision: 1,
    );
    expect(driver.state.teachingExposure, contains(exposure));
    driver.act(fixtureSectionIds.first, const FinishSentenceHuntRun());
    driver.act(
      fixtureSectionIds.first,
      StartSentenceHuntRun(
        sessionId: 'second-run',
        policy: LessonPolicy(),
        mode: SentenceHuntRunMode.practice,
      ),
    );
    final SentenceHuntTransition answer =
        driver.answerCurrent(fixtureSectionIds.first);
    expect(answer.attempts.single.presentation, AttemptPresentation.firstInRun);
    expect(answer.attempts.single.teachingExposed, isTrue);
    final SentenceHuntSummary summary =
        answer.nextState.summaries.values.firstWhere(
      (SentenceHuntSummary value) =>
          value.content.itemId == fixtureItemIds.first.first,
    );
    expect(summary.firstInRun.total, 2);
    expect(summary.firstTeachingExposed.total, 1);
  });

  test('sentence_unfinished_run_requires_explicit_replacement', () {
    final _Driver driver = _Driver();
    driver.start(0);
    expect(
      () => driver.act(
        fixtureSectionIds.first,
        StartSentenceHuntRun(
          sessionId: 'replacement',
          policy: LessonPolicy(),
          mode: SentenceHuntRunMode.reviewOnly,
        ),
      ),
      throwsStateError,
    );
    expect(driver.state.slots[fixtureSectionIds.first]!.checkpoint.sessionId,
        'run-0');
  });
}

final class _Driver {
  _Driver({SentenceHuntCatalogue? catalogue})
      : catalogue = catalogue ?? syntheticSentenceCatalogue(),
        scope = SentenceHuntProfileScope(
            courseId: 'en-fr', owner: LearningOwner.guest()) {
    engine = SentenceHuntTransitionEngine(catalogue: this.catalogue);
    state = SentenceHuntLearningState.empty(scope);
  }

  final SentenceHuntCatalogue catalogue;
  final SentenceHuntProfileScope scope;
  late final SentenceHuntTransitionEngine engine;
  late SentenceHuntLearningState state;
  int _counter = 0;

  DateTime now() => DateTime.utc(2026).add(Duration(seconds: _counter));

  String token() => 'shunt${(++_counter).toString().padLeft(17, '0')}';

  SentenceHuntTransition act(String sectionId, SentenceHuntAction action) {
    final SentenceHuntLearningCommand command = engine.prepare(
      state: state,
      sectionId: sectionId,
      action: action,
      authGeneration: 0,
      token: token(),
      submittedAt: now(),
    );
    final SentenceHuntTransition transition = engine.evaluate(
      state: state,
      command: command,
      committedAt: now(),
    );
    state = transition.nextState;
    return transition;
  }

  SentenceHuntTransition answerCurrent(String sectionId,
      {bool correct = true}) {
    final SentenceHuntSlot slot = state.slots[sectionId]!;
    final LessonSectionSession saved = session(slot);
    final SentenceHuntItem item =
        catalogue.item(sectionId, saved.currentItemId!);
    final List<String> selected = correct
        ? item.expectedTokenIds
        : <String>[
            item.selectableTokenIds
                .firstWhere((String id) => !item.expectedTokenIds.contains(id)),
          ];
    final SentenceHuntPlaybackObservation playback =
        SentenceHuntPlaybackObservation(
      scope: scope,
      content: item.identity,
      runGeneration: slot.cursor.generation,
      round: saved.round,
      uiGeneration: _counter,
      referenceId: item.identity.audioRefId,
      outcome: CourseAudioOutcome.completed,
      source: CourseAudioSource.reviewedRecording,
    );
    return act(
      sectionId,
      AnswerSentenceHuntItem(SentenceHuntAnswer(
        content: item.identity,
        selectedTokenIds: selected,
        expectedTokenIdsSnapshot: item.expectedTokenIds,
        playback: playback,
      )),
    );
  }

  SentenceHuntTransition advance(String sectionId) =>
      act(sectionId, const AdvanceSentenceHuntItem());

  void start(int sectionIndex) {
    final String sectionId = fixtureSectionIds[sectionIndex];
    act(
      sectionId,
      StartSentenceHuntRun(
        sessionId: 'run-$sectionIndex',
        policy: catalogue.section(sectionId).policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );
  }

  LessonSectionSession session(SentenceHuntSlot slot) =>
      LessonSectionSession.fromJson(
        _deepMutable(slot.checkpoint.sessionJson) as Map<String, dynamic>,
        itemIds: catalogue
            .section(slot.sectionId)
            .items
            .map((SentenceHuntItem item) => item.identity.itemId)
            .toList(),
        contentRevision: slot.checkpoint.contentRevision,
      );

  SentenceHuntLearningCommand answerCommand(
    SentenceHuntSlot slot,
    SentenceHuntItem item, {
    required List<String> selected,
    String? tokenOverride,
    DateTime? submittedAt,
  }) {
    final LessonSectionSession session = this.session(slot);
    final SentenceHuntPlaybackObservation playback =
        SentenceHuntPlaybackObservation(
      scope: scope,
      content: item.identity,
      runGeneration: slot.cursor.generation,
      round: session.round,
      uiGeneration: 17,
      referenceId: item.identity.audioRefId,
      outcome: CourseAudioOutcome.completed,
      source: CourseAudioSource.reviewedRecording,
    );
    return engine.prepare(
      state: state,
      sectionId: slot.sectionId,
      action: AnswerSentenceHuntItem(SentenceHuntAnswer(
        content: item.identity,
        selectedTokenIds: selected,
        expectedTokenIdsSnapshot: item.expectedTokenIds,
        playback: playback,
      )),
      authGeneration: 0,
      token: tokenOverride ?? token(),
      submittedAt: submittedAt ?? now(),
    );
  }

  SentenceHuntPlaybackObservation playback(
    SentenceHuntSlot slot,
    SentenceHuntItem item, {
    SentenceHuntProfileScope? scope,
    SentenceHuntContentIdentity? content,
    int? runGeneration,
    int? round,
    int uiGeneration = 17,
    String? referenceId,
    CourseAudioOutcome outcome = CourseAudioOutcome.completed,
    CourseAudioSource source = CourseAudioSource.reviewedRecording,
  }) {
    final LessonSectionSession restored = session(slot);
    return SentenceHuntPlaybackObservation(
      scope: scope ?? this.scope,
      content: content ?? item.identity,
      runGeneration: runGeneration ?? slot.cursor.generation,
      round: round ?? restored.round,
      uiGeneration: uiGeneration,
      referenceId: referenceId ?? item.identity.audioRefId,
      outcome: outcome,
      source: source,
    );
  }

  SentenceHuntAnswer answer(
    SentenceHuntItem item,
    SentenceHuntSlot slot, {
    List<String>? selected,
    List<String>? expectedSnapshot,
    SentenceHuntContentIdentity? content,
    SentenceHuntPlaybackObservation? playback,
  }) =>
      SentenceHuntAnswer(
        content: content ?? item.identity,
        selectedTokenIds: selected ?? item.expectedTokenIds,
        expectedTokenIdsSnapshot: expectedSnapshot ?? item.expectedTokenIds,
        playback: playback ?? this.playback(slot, item, content: content),
      );

  SentenceHuntLearningCommand command({
    required String sectionId,
    required SentenceHuntAction action,
    SentenceHuntProfileScope? commandScope,
    String? sectionFingerprint,
    LearningCursorPosition? expected,
    String? tokenOverride,
    int authGeneration = 0,
  }) {
    final SentenceHuntSlot? slot = state.slots[sectionId];
    return SentenceHuntLearningCommand(
      scope: commandScope ?? scope,
      authGeneration: authGeneration,
      sectionId: sectionId,
      sectionFingerprint:
          sectionFingerprint ?? catalogue.section(sectionId).sectionFingerprint,
      expected: expected ??
          slot?.cursor ??
          const LearningCursorPosition(generation: 0, sequence: 0, revision: 0),
      expectedScopeRevision: state.revision,
      token: tokenOverride ?? token(),
      submittedAt: now(),
      action: action,
    );
  }
}

SentenceHuntContentIdentity _copyIdentity(
  SentenceHuntContentIdentity identity, {
  String? sectionId,
  String? annotationHash,
}) =>
    SentenceHuntContentIdentity(
      sectionId: sectionId ?? identity.sectionId,
      itemId: identity.itemId,
      sentenceId: identity.sentenceId,
      audioRefId: identity.audioRefId,
      annotationHash: annotationHash ?? identity.annotationHash,
      contentRevision: identity.contentRevision,
      annotationRevision: identity.annotationRevision,
    );

SentenceHuntCatalogue _catalogueWithVersionedPolicy() {
  final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
  final Map<String, dynamic> section =
      (fixture.manifest['sections'] as List<Map<String, dynamic>>).first;
  section['policyRevision'] = 2;
  section['completionThresholdPercent'] = 70;
  return decodeFrenchSentencePackage(
    manifestJson: fixture.manifestJson,
    provenanceJson: fixture.provenanceJson,
    annotationsJson: fixture.annotationsJson,
    sourceEvidenceJson: fixture.sourceEvidenceJson,
  );
}

SentenceHuntCatalogue _catalogueWithFingerprintMutation(String change) {
  final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
  final Map<String, dynamic> section =
      (fixture.manifest['sections'] as List<Map<String, dynamic>>).first;
  final Map<String, dynamic> item =
      (section['items'] as List<Map<String, dynamic>>).first;
  final String itemId = item['id'] as String;
  final Map<String, dynamic> annotation =
      (fixture.annotations['entries'] as List<Map<String, dynamic>>)
          .firstWhere((Map<String, dynamic> row) => row['itemId'] == itemId);
  final Map<String, dynamic> provenance =
      (fixture.provenance['entries'] as List<Map<String, dynamic>>)
          .firstWhere((Map<String, dynamic> row) => row['itemId'] == itemId);

  switch (change) {
    case 'key':
      final List<Map<String, dynamic>> tokens =
          (item['tokens'] as List<Map<String, dynamic>>);
      final String sound = item['targetSound'] as String;
      tokens[0]['phonemes'] = <String>['t'];
      tokens[1]['phonemes'] = <String>['v', sound];
      final List<String> expected = <String>[
        tokens[1]['id'] as String,
        tokens[3]['id'] as String,
      ];
      item['expectedTokenIds'] = expected;
      final List<Map<String, dynamic>> drafts =
          annotation['draftTokenPhonemes'] as List<Map<String, dynamic>>;
      drafts[0]['phonemes'] = <String>['t'];
      drafts[1]['phonemes'] = <String>['v', sound];
      break;
    case 'context':
      item['debriefNote'] = 'Updated synthetic context for fingerprint test.';
      break;
    case 'annotation':
      const String changedHash =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      item['annotationHash'] = changedHash;
      annotation['annotationHash'] = changedHash;
      (annotation['frenchAudioReview']
          as Map<String, dynamic>)['annotationHash'] = changedHash;
      (provenance['rightsReview'] as Map<String, dynamic>)['annotationHash'] =
          changedHash;
      break;
    case 'asset':
      const String changedHash =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      item['clipSha256'] = changedHash;
      (provenance['clip'] as Map<String, dynamic>)['sha256'] = changedHash;
      (annotation['frenchAudioReview'] as Map<String, dynamic>)['clipSha256'] =
          changedHash;
      (provenance['rightsReview'] as Map<String, dynamic>)['clipSha256'] =
          changedHash;
      break;
    default:
      throw ArgumentError.value(change, 'change');
  }

  return decodeFrenchSentencePackage(
    manifestJson: fixture.manifestJson,
    provenanceJson: fixture.provenanceJson,
    annotationsJson: fixture.annotationsJson,
    sourceEvidenceJson: fixture.sourceEvidenceJson,
  );
}

String _stateSnapshot(SentenceHuntLearningState state) => jsonEncode(
      <String, Object?>{
        'revision': state.revision,
        'commitOrdinal': state.commitOrdinal,
        'slots': <String, Object?>{
          for (final MapEntry<String, SentenceHuntSlot> entry
              in state.slots.entries)
            entry.key: <String, Object?>{
              'cursor': <int>[
                entry.value.cursor.generation,
                entry.value.cursor.sequence,
                entry.value.cursor.revision,
              ],
              'session': jsonEncode(entry.value.checkpoint.sessionJson),
              'latestReceipt': entry.value.latestReceipt.commitOrdinal,
            },
        },
        'attempts': state.attempts
            .map((SentenceHuntAttempt attempt) => <Object?>[
                  attempt.content.itemId,
                  attempt.sequence,
                  attempt.selectedTokenIds,
                  attempt.correct,
                ])
            .toList(),
        'receipts': state.receipts
            .map((SentenceHuntReceipt receipt) => receipt.commitOrdinal)
            .toList(),
        'mistakes': state.mistakes.length,
        'summaries': state.summaries.length,
        'completions': state.completions.length,
        'exposure': state.teachingExposure.length,
      },
    );

bool _throwsArgumentError(void Function() action) {
  try {
    action();
  } on ArgumentError {
    return true;
  } catch (_) {
    return false;
  }
  return false;
}

bool _throwsStateError(void Function() action) {
  try {
    action();
  } on StateError {
    return true;
  } catch (_) {
    return false;
  }
  return false;
}

Object? _deepMutable(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        entry.key as String: _deepMutable(entry.value),
    };
  }
  if (value is List) {
    final List<Object?> result =
        value.map<Object?>((Object? child) => _deepMutable(child)).toList();
    if (result.every((Object? child) => child is String)) {
      return result.cast<String>();
    }
    return result;
  }
  return value;
}
