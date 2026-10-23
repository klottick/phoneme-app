import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_storage_validator.dart';

void main() {
  test('profile storage keys encode guest and account independently', () {
    expect(
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest())
            .storageKey,
        'course.learning.comparison.v1.ZW4tZnI.g');
    expect(
        ComparisonProfileScope(
                courseId: 'en-fr', owner: LearningOwner.account('acct-1'))
            .storageKey,
        'course.learning.comparison.v1.ZW4tZnI.a.YWNjdC0x');
    expect(
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest())
            .storageKey,
        isNot(LearningScope(courseId: 'en-fr', owner: LearningOwner.guest())
            .storageKey));
  });

  test('scope cursor and key have value equality and bounded counters', () {
    final s =
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest());
    expect(
        s,
        equals(ComparisonProfileScope(
            courseId: 'en-fr', owner: LearningOwner.guest())));
    expect(
        s.hashCode,
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest())
            .hashCode);
    expect(ComparisonCursor(generation: 1, sequence: 2, revision: 3),
        equals(ComparisonCursor(generation: 1, sequence: 2, revision: 3)));
    final k = ComparisonPairMistakeKey(
        scope: s, activityId: 'a', pairId: 'p', contentRevision: 1);
    expect(
        k,
        equals(ComparisonPairMistakeKey(
            scope: s, activityId: 'a', pairId: 'p', contentRevision: 1)));
    expect(
        () => ComparisonCursor(
            generation: 9007199254740992, sequence: 0, revision: 0),
        throwsArgumentError);
  });

  test('checkpoint recursively detaches nested session JSON', () {
    final scope =
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest());
    final child = <Object?>['saved'];
    final input = <String, Object?>{
      'sessionId': 's',
      'contentRevision': 1,
      'policy': {'completionThresholdPercent': 80},
      'nested': {'items': child}
    };
    final c = ComparisonCheckpoint(
        scope: scope,
        sessionId: 's',
        contentRevision: 1,
        policy: LessonPolicy(),
        sessionJson: input);
    child[0] = 'changed';
    expect(((c.sessionJson['nested'] as Map)['items'] as List).single, 'saved');
    expect(() => ((c.sessionJson['nested'] as Map)['items'] as List).add('x'),
        throwsUnsupportedError);
    expect(
        () => ComparisonCheckpoint(
                scope: scope,
                sessionId: 's',
                contentRevision: 1,
                policy: LessonPolicy(),
                sessionJson: {
                  'sessionId': 'other',
                  'contentRevision': 1,
                  'policy': {'completionThresholdPercent': 80}
                }),
        throwsArgumentError);
  });

  test('receipt enforces reachable cursor headers and owner scope', () {
    final s =
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest());
    final zero = ComparisonCursor(generation: 0, sequence: 0, revision: 0),
        start = ComparisonCursor(generation: 1, sequence: 1, revision: 0);
    ComparisonReceipt(
        scope: s,
        activityId: 'en-fr-phoneme-comparison',
        generation: 1,
        sequence: 1,
        token: 'abcdefghijklmnopqrstuv',
        canonicalCommand: '{}',
        before: zero,
        after: start,
        commitOrdinal: 1);
    expect(
        () => ComparisonReceipt(
            scope: s,
            activityId: 'en-fr-phoneme-comparison',
            generation: 2,
            sequence: 1,
            token: 'abcdefghijklmnopqrstuv',
            canonicalCommand: '{}',
            before: zero,
            after: start,
            commitOrdinal: 1),
        throwsArgumentError);
  });

  test('attempt detaches observations and rejects inconsistent correctness',
      () {
    final s =
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest());
    final input = <ComparisonPlaybackObservation>[
      ComparisonPlaybackObservation(
          slot: ComparisonSample.a,
          referenceId: 'a',
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.unverifiedRecording,
          activityId: 'en-fr-phoneme-comparison',
          runGeneration: 1,
          round: 1,
          pairId: 'p',
          profile: s,
          uiGeneration: 1),
      ComparisonPlaybackObservation(
          slot: ComparisonSample.b,
          referenceId: 'b',
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.unverifiedRecording,
          activityId: 'en-fr-phoneme-comparison',
          runGeneration: 1,
          round: 1,
          pairId: 'p',
          profile: s,
          uiGeneration: 1),
    ];
    final attempt = ComparisonPairAttempt(
        scope: s,
        activityId: 'en-fr-phoneme-comparison',
        pairId: 'p',
        contentRevision: 1,
        runGeneration: 1,
        round: 1,
        sequence: 1,
        selectedRelation: PhonemeRelation.same,
        expectedRelation: PhonemeRelation.different,
        correct: false,
        presentation: AttemptPresentation.firstInRun,
        afterDebrief: false,
        observations: input,
        answeredAt: DateTime.utc(2026),
        committedAt: DateTime.utc(2026));
    input.clear();
    expect(attempt.observations, hasLength(2));
    expect(
        () => ComparisonPairAttempt(
            scope: s,
            activityId: 'en-fr-phoneme-comparison',
            pairId: 'p',
            contentRevision: 1,
            runGeneration: 1,
            round: 1,
            sequence: 1,
            selectedRelation: PhonemeRelation.same,
            expectedRelation: PhonemeRelation.different,
            correct: true,
            presentation: AttemptPresentation.firstInRun,
            afterDebrief: false,
            observations: attempt.observations,
            answeredAt: DateTime.utc(2026),
            committedAt: DateTime.utc(2026)),
        throwsArgumentError);
  });

  test('state rejects mismatched map key and value identities', () {
    final s =
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest());
    final key = ComparisonPairMistakeKey(
            scope: s, activityId: 'a', pairId: 'p', contentRevision: 1),
        other = ComparisonPairMistakeKey(
            scope: s, activityId: 'a', pairId: 'q', contentRevision: 1);
    final m = ComparisonPairMistake(
        scope: s,
        key: other,
        firstWrongAt: DateTime.utc(2026),
        latestWrongAt: DateTime.utc(2026),
        failureCount: 1);
    expect(
        () => ComparisonLearningState(
            scope: s,
            revision: 0,
            commitOrdinal: 0,
            slot: null,
            attempts: const [],
            receipts: const [],
            mistakes: {key: m},
            summaries: const {},
            completions: const []),
        throwsArgumentError);
  });

  test('command canonical identity includes ordered schema and auth generation',
      () {
    final s =
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest());
    final command = ComparisonLearningCommand(
        scope: s,
        authGeneration: 4,
        activityId: 'en-fr-phoneme-comparison',
        expected: ComparisonCursor(generation: 0, sequence: 0, revision: 0),
        expectedScopeRevision: 0,
        token: 'abcdefghijklmnopqrstuv',
        submittedAt: DateTime.utc(2026),
        action: const AdvanceComparisonPair());
    final encoded = comparisonCanonicalCommand(command);
    expect(encoded.indexOf('"schemaVersion"'),
        lessThan(encoded.indexOf('"family"')));
    expect(encoded, contains('"authGeneration":4'));
    expect(encoded, contains('"kind":"advance"'));
    expect(
        () => ComparisonLearningCommand(
            scope: s,
            authGeneration: 9007199254740992,
            activityId: 'en-fr-phoneme-comparison',
            expected: ComparisonCursor(generation: 0, sequence: 0, revision: 0),
            expectedScopeRevision: 0,
            token: 'abcdefghijklmnopqrstuv',
            submittedAt: DateTime.utc(2026),
            action: const AdvanceComparisonPair()),
        throwsArgumentError
      );
    }
  );

  test('comparison_command_captures_scope_revision', () {
    final driver = _Driver();
    driver.start();
    driver.answerCurrent(true);
    final state = driver.state;
    final command = driver.engine.prepare(
      state: state,
      activityId: comparisonActivityId,
      action: const AdvanceComparisonPair(),
      authGeneration: 0,
      token: 'abcdefghijklmnopqrstuv',
      submittedAt: DateTime.utc(2026)
    );

    expect(command.expectedScopeRevision, state.revision);
    final canonical =
        jsonDecode(comparisonLearningSqlCanonicalCommand(command))
            as Map<String, dynamic>;
    expect(canonical['activityId'], command.activityId);
    expect(canonical['expectedScopeRevision'], state.revision);
    ComparisonLearningCommand withScopeRevision(int revision) =>
        ComparisonLearningCommand(
          scope: command.scope,
          authGeneration: command.authGeneration,
          activityId: command.activityId,
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
      comparisonLearningSqlCanonicalCommand(
        withScopeRevision(state.revision + 1)
      ),
      isNot(comparisonLearningSqlCanonicalCommand(command))
    );

    final legacy = comparisonCanonicalCommand(command);
    expect(
      comparisonCanonicalCommand(withScopeRevision(state.revision + 1)),
      legacy
    );
    expect(
      legacy,
      '{"schemaVersion":1,"family":"comparison","courseId":"en-fr",'
      '"owner":{"kind":"guest","userId":null},"authGeneration":0,'
      '"activityId":"en-fr-phoneme-comparison","generation":1,'
      '"sequence":2,"revision":1,"token":"abcdefghijklmnopqrstuv",'
      '"submittedAt":"2026-01-01T00:00:00.000Z",'
      '"action":{"kind":"advance"}}'
    );
    final legacyFields = (jsonDecode(legacy) as Map<String, dynamic>).keys;
    expect(legacyFields, contains('activityId'));
    expect(legacyFields, isNot(contains('expectedScopeRevision')));
  });

  test('registered answers derive correctness and pair-only evidence', () {
    final driver = _Driver();
    driver.start();
    final wrong = driver.answer(PhonemeRelation.same);
    expect(wrong.attempts.single.pairId, 'fr07b-pair-01');
    expect(wrong.attempts.single.correct, isFalse);
    expect(wrong.attempts.single.expectedRelation, PhonemeRelation.different);
    expect(wrong.nextState.attempts, hasLength(1));
    expect(wrong.nextState.mistakes.keys.single.pairId, 'fr07b-pair-01');
    expect(wrong.nextState.summaries.values.single.firstInRun.total, 1);
    driver.state = wrong.nextState;
    driver.act(const AdvanceComparisonPair());
    final right = driver.answer(PhonemeRelation.same);
    expect(right.attempts.single.correct, isTrue);
    expect(right.attempts.single.pairId, 'fr07b-pair-02');
    expect(right.nextState.attempts, hasLength(2));
    expect(right.nextState.mistakes, hasLength(1));
  });

  test('prepare and evaluate reject invalid A/B provenance without mutation',
      () {
    final driver = _Driver();
    driver.start();
    final before = driver.state;
    final invalid = driver.observations(referenceB: 'swapped');
    expect(
        () => driver.engine.prepare(
            state: before,
            activityId: comparisonActivityId,
            action: AnswerComparisonPair(ComparePhonemesAnswer(
                selectedRelation: PhonemeRelation.same,
                expectedRelationSnapshot: driver.exercise.expectedRelation,
                observations: invalid)),
            authGeneration: 0,
            token: driver.token(),
            submittedAt: driver.now()),
        throwsArgumentError);
    final direct = ComparisonLearningCommand(
        scope: driver.scope,
        authGeneration: 0,
        activityId: comparisonActivityId,
        expected: before.slot!.cursor,
        expectedScopeRevision: before.revision,
        token: driver.token(),
        submittedAt: driver.now(),
        action: AnswerComparisonPair(ComparePhonemesAnswer(
            selectedRelation: PhonemeRelation.same,
            expectedRelationSnapshot: driver.exercise.expectedRelation,
            observations: invalid)));
    expect(
        () => driver.engine.evaluate(
            state: before, command: direct, committedAt: driver.now()),
        throwsArgumentError);
    expect(before.slot!.checkpoint.sessionJson['attemptCount'], 0);
    expect(before.attempts, isEmpty);
  });

  test(
      'prepare rejects playback lifecycle and cursor guards before command creation',
      () {
    final d = _Driver();
    d.start();
    final good = d.observations(run: 1, round: 1);
    final cases = <List<ComparisonPlaybackObservation>>[
      [
        good[0],
        _copyObservation(good[1], outcome: CourseAudioOutcome.cancelled)
      ],
      [good[0], _copyObservation(good[1], outcome: CourseAudioOutcome.failed)],
      [
        good[0],
        _copyObservation(good[1], source: CourseAudioSource.practiceTts)
      ],
      [
        good[0],
        _copyObservation(good[1], source: CourseAudioSource.reviewedRecording)
      ],
      [good[0], _copyObservation(good[1], source: null, clearSource: true)],
      [good[0], _copyObservation(good[1], activityId: 'other')],
      [
        good[0],
        _copyObservation(good[1],
            profile: ComparisonProfileScope(
                courseId: 'en-fr', owner: LearningOwner.account('other')))
      ],
      [good[0], _copyObservation(good[1], runGeneration: 2)],
      [good[0], _copyObservation(good[1], round: 2)],
      [good[0], _copyObservation(good[1], pairId: 'other')],
      [
        good[0],
        _copyObservation(good[1], uiGeneration: good[1].uiGeneration + 1)
      ],
      [good[0], _copyObservation(good[1], uiGeneration: -1)],
    ];
    expect(
        () => ComparePhonemesAnswer(
            selectedRelation: PhonemeRelation.same,
            expectedRelationSnapshot: PhonemeRelation.different,
            observations: [good[1], good[0]]),
        throwsArgumentError);
    expect(
        () => ComparePhonemesAnswer(
            selectedRelation: PhonemeRelation.same,
            expectedRelationSnapshot: PhonemeRelation.different,
            observations: [good.first]),
        throwsArgumentError);
    expect(
        () => ComparePhonemesAnswer(
            selectedRelation: PhonemeRelation.same,
            expectedRelationSnapshot: PhonemeRelation.different,
            observations: [good.first, good.first]),
        throwsArgumentError);
    for (final observations in cases) {
      final action = AnswerComparisonPair(ComparePhonemesAnswer(
          selectedRelation: PhonemeRelation.same,
          expectedRelationSnapshot:
              d.catalogue.exercise('fr07b-pair-01').expectedRelation,
          observations: observations));
      expect(
          () => d.engine.prepare(
              state: d.state,
              activityId: comparisonActivityId,
              action: action,
              authGeneration: 0,
              token: d.token(),
              submittedAt: d.now()),
          throwsArgumentError);
      final frozen = ComparisonLearningCommand(
          scope: d.scope,
          authGeneration: 0,
          activityId: comparisonActivityId,
          expected: d.state.slot!.cursor,
          expectedScopeRevision: d.state.revision,
          token: d.token(),
          submittedAt: d.now(),
          action: action);
      expect(
          () => d.engine
              .evaluate(state: d.state, command: frozen, committedAt: d.now()),
          throwsArgumentError);
    }
    final stale = ComparisonLearningCommand(
        scope: d.scope,
        authGeneration: 0,
        activityId: comparisonActivityId,
        expected: ComparisonCursor(generation: 0, sequence: 0, revision: 0),
        expectedScopeRevision: d.state.revision,
        token: d.token(),
        submittedAt: d.now(),
        action: AnswerComparisonPair(ComparePhonemesAnswer(
            selectedRelation: PhonemeRelation.same,
            expectedRelationSnapshot:
                d.catalogue.exercise('fr07b-pair-01').expectedRelation,
            observations: good)));
    expect(
        () => d.engine
            .evaluate(state: d.state, command: stale, committedAt: d.now()),
        throwsArgumentError);
    final wrongSnapshot = AnswerComparisonPair(ComparePhonemesAnswer(
        selectedRelation: PhonemeRelation.same,
        expectedRelationSnapshot: PhonemeRelation.same,
        observations: good));
    expect(
        () => d.engine.prepare(
            state: d.state,
            activityId: comparisonActivityId,
            action: wrongSnapshot,
            authGeneration: 0,
            token: d.token(),
            submittedAt: d.now()),
        throwsArgumentError);
  });

  test('after-debrief subset also bounds wrong exposures', () {
    final key = ComparisonSummaryKey(
        scope: ComparisonProfileScope(
            courseId: 'en-fr', owner: LearningOwner.guest()),
        activityId: comparisonActivityId,
        pairId: 'p',
        contentRevision: 1);
    expect(
        () => ComparisonPairSummary(
            key: key,
            firstInRun: ComparisonCount(correct: 1, total: 1),
            repeatInRun: ComparisonCount(correct: 0, total: 1),
            afterDebrief: ComparisonCount(correct: 0, total: 2)),
        throwsArgumentError);
  });

  test(
      'finite session preserves threshold and limits review to unresolved items',
      () {
    final d = _Driver();
    d.start();
    expect(() => d.act(const ReviewComparisonPairs()), throwsStateError);
    expect(() => d.act(const FinishComparisonRun(recordCompletion: true)),
        throwsStateError);
    for (var i = 0; i < 10; i++) {
      d.answerCurrent(i < 8);
      d.act(const AdvanceComparisonPair());
    }
    expect(d.session.canComplete, isTrue);
    final finish = d.engine.prepare(
        state: d.state,
        activityId: comparisonActivityId,
        action: const FinishComparisonRun(recordCompletion: true),
        authGeneration: 0,
        token: d.token(),
        submittedAt: d.now());
    expect(
        d.engine
            .evaluate(state: d.state, command: finish, committedAt: d.now())
            .nextState
            .completions,
        hasLength(1));
    d.act(const ReviewComparisonPairs());
    expect(d.session.queue, ['fr07b-pair-09', 'fr07b-pair-10']);
    d.answerCurrent(false);
    d.act(const AdvanceComparisonPair());
    expect(d.session.currentItemId, 'fr07b-pair-10');
    expect(d.session.round, 2);
    d.answerCurrent(false);
    d.act(const AdvanceComparisonPair());
    expect(d.session.phase, LessonSectionPhase.debrief);
    d.act(const ReviewComparisonPairs());
    expect(d.session.round, 3);
    expect(d.session.queue, ['fr07b-pair-09', 'fr07b-pair-10']);
  });

  test('non-recording finish never creates a completion', () {
    final d = _Driver();
    d.start();
    final result = d.act(const FinishComparisonRun(recordCompletion: false));
    expect(result.nextState.completions, isEmpty);
  });

  test('new run resets only checkpoint and retains history', () {
    final d = _Driver();
    d.start();
    d.answerCurrent(false);
    final prior = d.state;
    d.act(StartComparisonRun(
        sessionId: 'second',
        policy: LessonPolicy(completionThresholdPercent: 70)));
    expect(d.session.sessionId, 'second');
    expect(d.session.answeredItemCount, 0);
    expect(d.state.attempts, hasLength(1));
    expect(prior.attempts, hasLength(1));
    expect(d.state.slot!.cursor.generation, 2);
    expect(d.state.slot!.cursor.sequence, 3);
    expect(d.state.slot!.cursor.revision, 0);
    expect(d.state.checkpoint!.policy.completionThresholdPercent, 70);
  });

  test('review repeats pair attribution and a new run starts first-in-run', () {
    final d = _Driver();
    d.start();
    for (var i = 0; i < 10; i++) {
      d.answerCurrent(i != 0);
      d.act(const AdvanceComparisonPair());
    }
    d.act(const FinishComparisonRun(recordCompletion: true));
    d.act(const ReviewComparisonPairs());
    final reviewed = d.answerCurrent(false);
    expect(
        reviewed.attempts.single.presentation, AttemptPresentation.repeatInRun);
    expect(reviewed.attempts.single.afterDebrief, isTrue);
    expect(
        reviewed.nextState.summaries.entries
            .singleWhere((e) => e.key.pairId == 'fr07b-pair-01')
            .value
            .afterDebrief
            .total,
        1);
    d.act(StartComparisonRun(sessionId: 'fresh', policy: LessonPolicy()));
    final fresh = d.answerCurrent(false);
    expect(fresh.attempts.single.presentation, AttemptPresentation.firstInRun);
    expect(
        fresh.nextState.mistakes.keys.where((k) => k.pairId == 'fr07b-pair-01'),
        hasLength(1));
  });

  test('completion requires threshold and may finish after finite remediation',
      () {
    final d = _Driver();
    d.start();
    for (var i = 0; i < 10; i++) {
      d.answerCurrent(i >= 3);
      d.act(const AdvanceComparisonPair());
    }
    expect(d.session.canComplete, isFalse);
    d.act(const ReviewComparisonPairs());
    d.answerCurrent(true);
    d.act(const AdvanceComparisonPair());
    d.answerCurrent(true);
    d.act(const AdvanceComparisonPair());
    d.answerCurrent(true);
    d.act(const AdvanceComparisonPair());
    expect(d.session.canComplete, isTrue);
    final c = d.engine.prepare(
        state: d.state,
        activityId: comparisonActivityId,
        action: const FinishComparisonRun(recordCompletion: true),
        authGeneration: 0,
        token: d.token(),
        submittedAt: d.now());
    expect(
        d.engine
            .evaluate(state: d.state, command: c, committedAt: d.now())
            .nextState
            .completions,
        hasLength(1));
  });

  test('pure history pruning retains latest answers and durable counts', () {
    final d = _Driver();
    d.start();
    for (var i = 0; i < 10; i++) {
      d.answerCurrent(i != 0);
      d.act(const AdvanceComparisonPair());
    }
    d.act(const FinishComparisonRun(recordCompletion: true));
    d.act(const ReviewComparisonPairs());
    for (var i = 0; i < 2000; i++) {
      d.answerCurrent(false);
      if (i < 1999) {
        d.act(const AdvanceComparisonPair());
        d.act(const ReviewComparisonPairs());
      }
    }
    expect(d.state.attempts, hasLength(2000));
    expect(d.state.receipts, hasLength(2000));
    expect(d.state.attempts.first.sequence, greaterThan(1));
    expect(d.state.attempts.last.sequence, d.state.slot!.cursor.sequence);
    expect(
        d.state.summaries.values.fold<int>(
            0, (n, s) => n + s.firstInRun.total + s.repeatInRun.total),
        2010);
    expect(d.session.attemptCount, 2010);
    expect(d.state.mistakes.values.single.failureCount, 2001);
    expect(d.state.completions, hasLength(1));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('interleaved_domain_slots_keep_activity_cursors_and_scope_ordinals', () {
    final driver = _RegisteredDriver();
    final initial = driver.state;
    final mixedStart = driver.engine.prepare(
      state: initial,
      activityId: comparisonActivityId,
      action: StartComparisonRun(
        sessionId: 'mixed-start',
        policy: LessonPolicy(),
      ),
      authGeneration: 0,
      token: driver.token(),
      submittedAt: driver.now(),
    );
    final dedicatedStart = driver.engine.prepare(
      state: initial,
      activityId: uyDemoComparisonActivityId,
      action: StartComparisonRun(
        sessionId: 'dedicated-start',
        policy: LessonPolicy(),
      ),
      authGeneration: 0,
      token: driver.token(),
      submittedAt: driver.now(),
    );

    expect(
      mixedStart.expected,
      ComparisonCursor(generation: 0, sequence: 0, revision: 0),
    );
    expect(
      dedicatedStart.expected,
      ComparisonCursor(generation: 0, sequence: 0, revision: 0),
    );
    expect(mixedStart.expectedScopeRevision, 0);
    expect(dedicatedStart.expectedScopeRevision, 0);

    driver.commit(mixedStart);
    final afterMixed = driver.state;
    expect(afterMixed.revision, 1);
    expect(afterMixed.slots.keys, contains(comparisonActivityId));
    expect(afterMixed.slot, same(afterMixed.slots[comparisonActivityId]));
    expect(afterMixed.checkpoint, same(afterMixed.slot!.checkpoint));
    expect(initial.slots, isEmpty);
    expect(
      () => driver.engine.evaluate(
        state: afterMixed,
        command: dedicatedStart,
        committedAt: driver.now(),
      ),
      throwsArgumentError,
    );

    driver.commit(
      driver.engine.prepare(
        state: driver.state,
        activityId: uyDemoComparisonActivityId,
        action: StartComparisonRun(
          sessionId: 'dedicated-start',
          policy: LessonPolicy(),
        ),
        authGeneration: 0,
        token: driver.token(),
        submittedAt: driver.now(),
      ),
    );

    expect(driver.state.revision, 2);
    expect(
      driver.state.slots.keys,
      containsAll([comparisonActivityId, uyDemoComparisonActivityId]),
    );
    expect(driver.state.slots[comparisonActivityId], same(afterMixed.slot));
    expect(driver.state.slot, same(driver.state.slots[comparisonActivityId]));
    expect(
      driver.state.slots.values.map((slot) => slot.cursor).toList(),
      everyElement(ComparisonCursor(generation: 1, sequence: 1, revision: 0)),
    );
    expect(driver.state.receipts.map((receipt) => receipt.commitOrdinal), [
      1,
      2,
    ]);
    expect(
      driver.state.slots[comparisonActivityId]!.latestReceipt.commitOrdinal,
      1,
    );
    expect(
      driver
          .state
          .slots[uyDemoComparisonActivityId]!
          .latestReceipt
          .commitOrdinal,
      2,
    );
    expect(() => driver.state.slots.clear(), throwsUnsupportedError);
    ComparisonLearningStateValidator.validateRegistered(
      driver.state,
      driver.registry,
    );

    final source = driver.state;
    final suppliedSlots = Map<String, ComparisonSlot>.of(source.slots);
    ComparisonLearningState copyState({
      Map<String, ComparisonSlot>? slots,
      ComparisonSlot? slot,
    }) => ComparisonLearningState(
      scope: source.scope,
      revision: source.revision,
      commitOrdinal: source.commitOrdinal,
      slot: slot,
      slots: slots,
      attempts: source.attempts,
      receipts: source.receipts,
      mistakes: source.mistakes,
      summaries: source.summaries,
      completions: source.completions,
    );
    final detached = copyState(slots: suppliedSlots);
    suppliedSlots.clear();
    expect(
      detached.slots.keys,
      containsAll([comparisonActivityId, uyDemoComparisonActivityId]),
    );
    expect(
      () => copyState(slot: source.slot, slots: source.slots),
      throwsArgumentError,
    );
  });

  test(
    'registered activities keep independent evidence across restart and review',
    () {
      final driver = _RegisteredDriver();
      final initial = driver.state;
      driver.act(
        comparisonActivityId,
        StartComparisonRun(sessionId: 'mixed', policy: LessonPolicy()),
      );
      driver.act(
        uyDemoComparisonActivityId,
        StartComparisonRun(
          sessionId: 'dedicated-first',
          policy: LessonPolicy(),
        ),
      );
      final mixedSlot = driver.state.slots[comparisonActivityId]!;
      final mixedCheckpoint = jsonEncode(mixedSlot.checkpoint.sessionJson);

      driver.answerCurrent(uyDemoComparisonActivityId, correct: false);
      expect(
        driver.state.attempts.single.activityId,
        uyDemoComparisonActivityId,
      );
      expect(
        driver.state.mistakes.keys.single.activityId,
        uyDemoComparisonActivityId,
      );
      driver.act(
        uyDemoComparisonActivityId,
        StartComparisonRun(
          sessionId: 'dedicated-second',
          policy: LessonPolicy(),
        ),
      );
      expect(driver.state.slots[comparisonActivityId], same(mixedSlot));
      expect(
        jsonEncode(
          driver.state.slots[comparisonActivityId]!.checkpoint.sessionJson,
        ),
        mixedCheckpoint,
      );
      expect(driver.state.attempts, hasLength(1));
      expect(
        driver.state.slots[uyDemoComparisonActivityId]!.cursor,
        ComparisonCursor(generation: 2, sequence: 3, revision: 0),
      );
      expect(
        driver
            .state
            .slots[uyDemoComparisonActivityId]!
            .checkpoint
            .contentRevision,
        driver.catalogue(uyDemoComparisonActivityId).contentRevision,
      );

      for (var index = 0; index < 10; index++) {
        driver.answerCurrent(uyDemoComparisonActivityId, correct: index != 1);
        driver.act(uyDemoComparisonActivityId, const AdvanceComparisonPair());
      }
      driver.act(
        uyDemoComparisonActivityId,
        const FinishComparisonRun(recordCompletion: true),
      );
      expect(driver.state.completions, hasLength(1));
      expect(
        driver.state.completions.single.activityId,
        uyDemoComparisonActivityId,
      );
      expect(
        driver.state.completions.single.contentRevision,
        driver.catalogue(uyDemoComparisonActivityId).contentRevision,
      );
      expect(
        driver.state.slots[comparisonActivityId]!.latestReceipt.commitOrdinal,
        lessThan(driver.state.commitOrdinal),
      );

      driver.act(uyDemoComparisonActivityId, const ReviewComparisonPairs());
      driver.answerCurrent(uyDemoComparisonActivityId, correct: true);
      driver.act(uyDemoComparisonActivityId, const AdvanceComparisonPair());
      driver.act(
        uyDemoComparisonActivityId,
        const FinishComparisonRun(recordCompletion: false),
      );

      expect(driver.state.attempts, hasLength(12));
      expect(
        driver.state.attempts.every(
          (attempt) => attempt.activityId == uyDemoComparisonActivityId,
        ),
        isTrue,
      );
      expect(driver.state.mistakes, isEmpty);
      expect(
        driver.state.summaries.keys.every(
          (key) => key.activityId == uyDemoComparisonActivityId,
        ),
        isTrue,
      );
      expect(driver.state.completions, hasLength(1));
      expect(driver.state.slots[comparisonActivityId], same(mixedSlot));
      expect(initial.slots, isEmpty);
      expect(
        driver.state.receipts.map((receipt) => receipt.commitOrdinal),
        List<int>.generate(driver.state.commitOrdinal, (index) => index + 1),
      );
      expect(
        driver
            .state
            .slots[uyDemoComparisonActivityId]!
            .latestReceipt
            .commitOrdinal,
        driver.state.commitOrdinal,
      );
      ComparisonLearningStateValidator.validateRegistered(
        driver.state,
        driver.registry,
      );
    },
  );
}

final class _Driver {
  _Driver()
      : catalogue = loadFrenchComparisonCatalogue(),
        scope = ComparisonProfileScope(
            courseId: 'en-fr', owner: LearningOwner.guest()) {
    engine = ComparisonLearningTransitionEngine(catalogue: catalogue);
    state = ComparisonLearningState.empty(scope);
  }
  final ComparisonCatalogue catalogue;
  final ComparisonProfileScope scope;
  late final ComparisonLearningTransitionEngine engine;
  late ComparisonLearningState state;
  int n = 0;
  DateTime now() => DateTime.utc(2026).add(Duration(seconds: n));
  LessonSectionSession get session => LessonSectionSession.fromJson(
      _deepMutable(state.checkpoint!.sessionJson) as Map<String, dynamic>,
      itemIds: catalogue.exercises.map((e) => e.id).toList(),
      contentRevision: catalogue.contentRevision);
  String token() => 'token${(++n).toString().padLeft(17, '0')}';
  ComparisonExercise get exercise => catalogue.exercise(
      state.slot!.checkpoint.sessionJson['currentItemId'] as String? ??
          'fr07b-pair-01');
  List<ComparisonPlaybackObservation> observations(
      {String? referenceB,
      int run = 1,
      int round = 1,
      String pair = 'fr07b-pair-01',
      String? activity}) {
    final e = catalogue.exercise(pair);
    final t = now();
    return [
      ComparisonPlaybackObservation(
          slot: ComparisonSample.a,
          referenceId: e.sampleA.referenceId,
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.unverifiedRecording,
          activityId: activity ?? comparisonActivityId,
          runGeneration: run,
          round: round,
          pairId: pair,
          profile: scope,
          uiGeneration: t.millisecondsSinceEpoch),
      ComparisonPlaybackObservation(
          slot: ComparisonSample.b,
          referenceId: referenceB ?? e.sampleB.referenceId,
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.unverifiedRecording,
          activityId: activity ?? comparisonActivityId,
          runGeneration: run,
          round: round,
          pairId: pair,
          profile: scope,
          uiGeneration: t.millisecondsSinceEpoch)
    ];
  }

  ComparisonLearningTransition act(ComparisonAction action) {
    final c = engine.prepare(
        state: state,
        activityId: comparisonActivityId,
        action: action,
        authGeneration: 0,
        token: token(),
        submittedAt: now());
    final result =
        engine.evaluate(state: state, command: c, committedAt: now());
    state = result.nextState;
    return result;
  }

  void start() =>
      act(StartComparisonRun(sessionId: 'session', policy: LessonPolicy()));
  ComparisonLearningTransition answerCurrent(bool correct) {
    final s = session;
    final pair = s.currentItemId!;
    final ex = catalogue.exercise(pair);
    final selected = correct
        ? ex.expectedRelation
        : (ex.expectedRelation == PhonemeRelation.same
            ? PhonemeRelation.different
            : PhonemeRelation.same);
    return act(AnswerComparisonPair(ComparePhonemesAnswer(
        selectedRelation: selected,
        expectedRelationSnapshot: ex.expectedRelation,
        observations: observations(
            pair: pair, run: state.slot!.cursor.generation, round: s.round))));
  }

  ComparisonLearningTransition answer(PhonemeRelation relation) {
    final e = state.slot!.checkpoint.sessionJson;
    final pair = (e['queue'] as List)[e['position'] as int] as String;
    final ex = catalogue.exercise(pair);
    return act(AnswerComparisonPair(ComparePhonemesAnswer(
        selectedRelation: relation,
        expectedRelationSnapshot: ex.expectedRelation,
        observations: observations(
            pair: pair, run: state.slot!.cursor.generation, round: 1))));
  }
}

Object? _deepMutable(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final e in value.entries) e.key as String: _deepMutable(e.value)
    };
  }
  if (value is List) {
    final converted = value.map(_deepMutable).toList();
    if (converted.every((item) => item is String)) {
      return converted.cast<String>();
    }
    return converted;
  }
  return value;
}

ComparisonPlaybackObservation _copyObservation(ComparisonPlaybackObservation o,
        {CourseAudioOutcome? outcome,
        CourseAudioSource? source,
        String? activityId,
        int? runGeneration,
        int? round,
        String? pairId,
        int? uiGeneration,
        ComparisonProfileScope? profile,
        bool clearSource = false}) =>
    ComparisonPlaybackObservation(
        slot: o.slot,
        referenceId: o.referenceId,
        outcome: outcome ?? o.outcome,
        source: clearSource ? null : source ?? o.source,
        activityId: activityId ?? o.activityId,
        runGeneration: runGeneration ?? o.runGeneration,
        round: round ?? o.round,
        pairId: pairId ?? o.pairId,
        profile: profile ?? o.profile,
        uiGeneration: uiGeneration ?? o.uiGeneration);

final class _RegisteredDriver {
  _RegisteredDriver()
    : mixedCatalogue = loadFrenchComparisonCatalogue(),
      dedicatedCatalogue = loadFrenchUyDemoComparisonCatalogue(),
      scope = ComparisonProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.guest(),
      ) {
    registry = ComparisonCatalogueRegistry([
      ComparisonCatalogueRegistration.available(mixedCatalogue),
      ComparisonCatalogueRegistration.available(dedicatedCatalogue),
    ]);
    engine = ComparisonLearningTransitionEngine(registry: registry);
    state = ComparisonLearningState.empty(scope);
  }

  final ComparisonCatalogue mixedCatalogue;
  final ComparisonCatalogue dedicatedCatalogue;
  final ComparisonProfileScope scope;
  late final ComparisonCatalogueRegistry registry;
  late final ComparisonLearningTransitionEngine engine;
  late ComparisonLearningState state;
  int _counter = 0;

  ComparisonCatalogue catalogue(String activityId) =>
      registry.requireAvailable(activityId);

  DateTime now() => DateTime.utc(2026, 10, 23).add(Duration(seconds: _counter));

  String token() => 'token${(++_counter).toString().padLeft(17, '0')}';

  ComparisonLearningTransition commit(ComparisonLearningCommand command) {
    final transition = engine.evaluate(
      state: state,
      command: command,
      committedAt: now(),
    );
    state = transition.nextState;
    return transition;
  }

  ComparisonLearningTransition act(String activityId, ComparisonAction action) {
    final command = engine.prepare(
      state: state,
      activityId: activityId,
      action: action,
      authGeneration: 0,
      token: token(),
      submittedAt: now(),
    );
    return commit(command);
  }

  LessonSectionSession session(String activityId) {
    final current = state.slots[activityId]!;
    final content = catalogue(activityId);
    return LessonSectionSession.fromJson(
      Map<String, dynamic>.from(current.checkpoint.sessionJson),
      itemIds: content.exercises.map((exercise) => exercise.id).toList(),
      contentRevision: content.contentRevision,
    );
  }

  ComparisonLearningTransition answerCurrent(
    String activityId, {
    required bool correct,
  }) {
    final current = state.slots[activityId]!;
    final run = session(activityId);
    final exercise = catalogue(activityId).exercise(run.currentItemId!);
    final relation = correct
        ? exercise.expectedRelation
        : exercise.expectedRelation == PhonemeRelation.same
        ? PhonemeRelation.different
        : PhonemeRelation.same;
    return act(
      activityId,
      AnswerComparisonPair(
        ComparePhonemesAnswer(
          selectedRelation: relation,
          expectedRelationSnapshot: exercise.expectedRelation,
          observations: [
            for (final sample in [exercise.sampleA, exercise.sampleB])
              ComparisonPlaybackObservation(
                slot: sample.slot,
                referenceId: sample.referenceId,
                outcome: CourseAudioOutcome.completed,
                source: CourseAudioSource.unverifiedRecording,
                activityId: activityId,
                runGeneration: current.cursor.generation,
                round: run.round,
                pairId: exercise.id,
                profile: scope,
                uiGeneration: _counter,
              ),
          ],
        ),
      ),
    );
  }
}
