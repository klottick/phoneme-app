import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import '../support/course_learning_fixtures.dart';

void main() {
  late LearningTransitionEngine engine;
  late CourseLearningState state;
  const activity = 'lesson:en-fr-u-y';

  setUp(() {
    engine = LearningTransitionEngine(LearningRegistry.french());
    state = CourseLearningState.empty(guestScope);
  });

  LearningTransition apply(LearningAction action, int token) {
    final command = engine.prepare(
      state: state,
      authGeneration: 0,
      activityId: activity,
      action: action,
      token: tokenFor(token),
      submittedAt: fixedTime.add(Duration(seconds: token)),
      random: _NoDrawRandom(),
    );
    final transition = engine.evaluate(
      state: state,
      command: command,
      committedAt: fixedTime.add(Duration(seconds: token)),
    );
    state = stateAfter(state, transition);
    return transition;
  }

  LearningTransition applyTo(
      String activityId, LearningAction action, int token) {
    final command = engine.prepare(
      state: state,
      authGeneration: 0,
      activityId: activityId,
      action: action,
      token: tokenFor(token),
      submittedAt: fixedTime.add(Duration(seconds: token)),
      random: _NoDrawRandom(),
    );
    final transition = engine.evaluate(
      state: state,
      command: command,
      committedAt: fixedTime.add(Duration(seconds: token)),
    );
    state = stateAfter(state, transition);
    return transition;
  }

  void start() => apply(StartLearningRun(options: RunOptions()), 1);

  LearningCommand prepare(LearningAction action, int token) => engine.prepare(
        state: state,
        authGeneration: 0,
        activityId: activity,
        action: action,
        token: tokenFor(token),
        submittedAt: fixedTime.add(Duration(seconds: token)),
        random: _NoDrawRandom(),
      );

  test('first start and restart keep sequence monotone and reset run revision',
      () {
    final first = apply(StartLearningRun(options: RunOptions()), 1).slot;
    expect(first.latestReceipt.before.generation, 0);
    expect(first.latestReceipt.before.sequence, 0);
    expect(first.latestReceipt.before.revision, 0);
    expect(first.cursor.generation, 1);
    expect(first.cursor.sequence, 1);
    expect(first.cursor.revision, 0);
    final restarted = apply(StartLearningRun(options: RunOptions()), 2).slot;
    expect(restarted.latestReceipt.before.generation, 1);
    expect(restarted.latestReceipt.before.sequence, 1);
    expect(restarted.latestReceipt.before.revision, 0);
    expect(restarted.cursor.generation, 2);
    expect(restarted.cursor.sequence, 2);
    expect(restarted.cursor.revision, 0);
  });

  void answerAndAdvance(int token, {bool correct = true}) {
    final slot = state.activities[activity]!;
    final session = (slot.snapshot as DiscoveryCheckpoint).session;
    final current = session.currentItemId!;
    final item = frenchUySection.items.firstWhere((x) => x.id == current);
    final selected =
        correct ? item.expectedSound : (item.expectedSound == 'u' ? 'y' : 'u');
    apply(
        ChooseSound(
          selectedSound: selected,
          audioSource: AttemptAudioSource.practiceSpeech,
        ),
        token);
    if ((state.activities[activity]!.snapshot as DiscoveryCheckpoint)
        .session
        .answered) {
      apply(const AdvanceLesson(), token + 100);
    }
  }

  test('invalid selected choice cannot create evidence', () {
    start();
    final before = state;
    expect(
      () => engine.prepare(
        state: before,
        authGeneration: 0,
        activityId: activity,
        action: ChooseSound(
          selectedSound: 'not-a-choice',
          audioSource: AttemptAudioSource.practiceSpeech,
        ),
        token: tokenFor(2),
        submittedAt: fixedTime,
        random: _NoDrawRandom(),
      ),
      throwsA(isA<LearningInvalidCommandException>()),
    );
    expect(before.history, isEmpty);
    expect(before.activities[activity]!.exposures, isEmpty);
  });

  test('prepare does not mutate the caller-owned discovery checkpoint', () {
    start();
    final original = state.activities[activity]!;
    final originalSession = (original.snapshot as DiscoveryCheckpoint).session;
    expect(originalSession.answered, isFalse);
    engine.prepare(
      state: state,
      authGeneration: 0,
      activityId: activity,
      action: ChooseSound(
        selectedSound: 'u',
        audioSource: AttemptAudioSource.practiceSpeech,
      ),
      token: tokenFor(19),
      submittedAt: fixedTime,
      random: _NoDrawRandom(),
    );
    expect(originalSession.answered, isFalse);
    expect(originalSession.attemptCount, 0);
    expect(state.activities[activity]!.cursor, original.cursor);
    expect(state.history, isEmpty);
  });

  test('prepare rejects illegal discovery advance and review as typed commands',
      () {
    start();
    final originalSlot = state.activities[activity]!;
    final originalSession =
        (originalSlot.snapshot as DiscoveryCheckpoint).session.toJson();

    expect(
      () => prepare(const AdvanceLesson(), 20),
      throwsA(isA<LearningInvalidCommandException>()),
    );
    expect(
      () => prepare(const ReviewDiscoveryMistakes(), 21),
      throwsA(isA<LearningInvalidCommandException>()),
    );
    expect(state.activities[activity]!.cursor, originalSlot.cursor);
    expect(
      (state.activities[activity]!.snapshot as DiscoveryCheckpoint)
          .session
          .toJson(),
      originalSession,
    );
    expect(state.history, isEmpty);
    expect(state.activities[activity]!.exposures, isEmpty);
  });

  test('prepare rejects review at debrief when there are no mistakes', () {
    start();
    for (var i = 0; i < frenchUySection.items.length; i++) {
      answerAndAdvance(i + 30);
    }
    final originalSlot = state.activities[activity]!;
    final originalSession =
        (originalSlot.snapshot as DiscoveryCheckpoint).session.toJson();
    expect(
      () => prepare(const ReviewDiscoveryMistakes(), 50),
      throwsA(isA<LearningInvalidCommandException>()),
    );
    expect(state.activities[activity]!.cursor, originalSlot.cursor);
    expect(
      (state.activities[activity]!.snapshot as DiscoveryCheckpoint)
          .session
          .toJson(),
      originalSession,
    );
    expect(state.history, hasLength(frenchUySection.items.length));
  });

  test('prepare keeps legal discovery advance and mistake review candidates',
      () {
    start();
    apply(
      ChooseSound(
        selectedSound: 'y',
        audioSource: AttemptAudioSource.practiceSpeech,
      ),
      22,
    );
    final beforeAdvance = state.activities[activity]!;
    final advance = prepare(const AdvanceLesson(), 23);
    expect(
      (advance.candidate as DiscoveryCheckpoint).session.position,
      1,
    );
    expect(
      (beforeAdvance.snapshot as DiscoveryCheckpoint).session.position,
      0,
    );
    apply(const AdvanceLesson(), 24);

    for (var i = 1; i < frenchUySection.items.length; i++) {
      answerAndAdvance(i + 40, correct: true);
    }
    final beforeReview = state.activities[activity]!;
    final review = prepare(const ReviewDiscoveryMistakes(), 60);
    final candidate = (review.candidate as DiscoveryCheckpoint).session;
    expect(candidate.round, 2);
    expect(candidate.queue, ['tout']);
    final saved = (beforeReview.snapshot as DiscoveryCheckpoint).session;
    expect(saved.phase, LessonSectionPhase.debrief);
    expect(saved.round, 1);
  });

  test('discovery evidence derives canonical content from registry', () {
    start();
    final before = state;
    final submitted = apply(
        ChooseSound(
          selectedSound: 'u',
          audioSource: AttemptAudioSource.practiceSpeech,
        ),
        210);
    final attempt = submitted.attempts.single;
    expect(attempt.itemId, 'en-fr-u-y-listening-tout');
    expect(attempt.answer, isA<SoundChoiceAnswer>());
    final answer = attempt.answer as SoundChoiceAnswer;
    expect(answer.choices, ['u', 'y']);
    expect(answer.expectedSound, 'u');
    expect(attempt.targetSounds, ['u']);
    expect(attempt.contentRevision, 1);
    expect(attempt.correct, isTrue);
    expect(before.history, isEmpty);
    expect(before.activities[activity]!.exposures, isEmpty);
  });

  test('assistance context and audio source cannot invent evidence metadata',
      () {
    start();
    expect(
      () => engine.prepare(
        state: state,
        authGeneration: 0,
        activityId: activity,
        action: ObserveAssistance(
          items: {ItemContextKey(itemId: 'invented', targetSound: 'u')},
          flags: const {AssistanceFlag.explanationVisible},
        ),
        token: tokenFor(211),
        submittedAt: fixedTime,
        random: _NoDrawRandom(),
      ),
      throwsA(isA<LearningInvalidCommandException>()),
    );
    expect(
      () => engine.prepare(
        state: state,
        authGeneration: 0,
        activityId: activity,
        action: ChooseSound(
          selectedSound: 'u',
          audioSource: AttemptAudioSource.pendingRecording,
        ),
        token: tokenFor(212),
        submittedAt: fixedTime,
        random: _NoDrawRandom(),
      ),
      throwsA(isA<LearningInvalidCommandException>()),
    );
    expect(state.activities[activity]!.exposures, isEmpty);
    expect(state.history, isEmpty);
  });

  test('lesson feedback retains the current discovery and legacy messages', () {
    start();
    final discovery = engine.prepare(
      state: state,
      authGeneration: 0,
      activityId: activity,
      action: ChooseSound(
        selectedSound: 'y',
        audioSource: AttemptAudioSource.practiceSpeech,
      ),
      token: tokenFor(213),
      submittedAt: fixedTime,
      random: _NoDrawRandom(),
    );
    expect(discovery.feedback.message, 'Not yet');

    const legacy = 'lesson:en-fr-vowels';
    applyTo(legacy, StartLearningRun(options: RunOptions()), 214);
    final legacyFeedback = engine.prepare(
      state: state,
      authGeneration: 0,
      activityId: legacy,
      action: ChooseSound(
        selectedSound: 'i',
        audioSource: AttemptAudioSource.practiceSpeech,
      ),
      token: tokenFor(215),
      submittedAt: fixedTime,
      random: _NoDrawRandom(),
    );
    expect(legacyFeedback.feedback.message, 'Yes! lit /li/ — bed');
    final wrongLegacyFeedback = engine.prepare(
      state: state,
      authGeneration: 0,
      activityId: legacy,
      action: ChooseSound(
        selectedSound: 'o',
        audioSource: AttemptAudioSource.practiceSpeech,
      ),
      token: tokenFor(216),
      submittedAt: fixedTime,
      random: _NoDrawRandom(),
    );
    expect(
        wrongLegacyFeedback.feedback.message, 'Listen again: lit /li/ — bed');
  });

  test('eight of ten reaches saved 80 percent only at debrief', () {
    start();
    for (var i = 0; i < 8; i++) {
      answerAndAdvance(i + 2);
    }
    expect(
        (state.activities[activity]!.snapshot as DiscoveryCheckpoint)
            .session
            .canComplete,
        isFalse);
    for (var i = 8; i < 10; i++) {
      answerAndAdvance(i + 2, correct: false);
    }
    final slot = state.activities[activity]!;
    expect((slot.snapshot as DiscoveryCheckpoint).session.canComplete, isTrue);
    expect(state.completions, isEmpty);
    final transition = apply(const FinishLearningActivity(), 50);
    expect(transition.completions, hasLength(1));
    expect(transition.completions.single.thresholdPercent, 80);
  });

  test('completion idempotency includes the saved threshold policy', () {
    start();
    for (var i = 0; i < 10; i++) {
      answerAndAdvance(i + 10);
    }
    apply(const FinishLearningActivity(), 20);
    expect(state.completions, hasLength(1));
    expect(state.completions.single.thresholdPercent, 80);

    final threshold100 = RunOptions(
      policy: LessonPolicy(completionThresholdPercent: 100),
    );
    apply(StartLearningRun(options: threshold100), 21);
    for (var i = 0; i < 10; i++) {
      answerAndAdvance(i + 30);
    }
    apply(const FinishLearningActivity(), 41);
    expect(state.completions, hasLength(2));
    expect(state.completions.last.thresholdPercent, 100);

    apply(StartLearningRun(options: threshold100), 42);
    for (var i = 0; i < 10; i++) {
      answerAndAdvance(i + 50);
    }
    apply(const FinishLearningActivity(), 61);
    expect(state.completions, hasLength(2));
  });

  test('unseen item cannot be replaced by repeated correct word', () {
    start();
    answerAndAdvance(2, correct: true);
    final slot = state.activities[activity]!;
    expect((slot.snapshot as DiscoveryCheckpoint).session.currentItemId, 'tu');
    expect(slot.exposures.keys.map((key) => key.itemId),
        ['en-fr-u-y-listening-tout']);
  });

  test('review round contains only unresolved items in authored order', () {
    start();
    for (var i = 0; i < 10; i++) {
      answerAndAdvance(i + 2, correct: i != 1 && i != 5);
    }
    apply(const ReviewDiscoveryMistakes(), 60);
    final session =
        (state.activities[activity]!.snapshot as DiscoveryCheckpoint).session;
    expect(session.queue, ['tu', 'lune']);
  });

  test('same sound different item cannot resolve mistake', () {
    start();
    for (var i = 0; i < 10; i++) {
      answerAndAdvance(i + 2, correct: i != 1 && i != 3);
    }
    final wrong = state.history
        .expand((batch) => batch.attempts)
        .firstWhere((a) => !a.correct && a.itemId.endsWith('-rue'));
    final wrongItemKey =
        state.mistakes.keys.singleWhere((key) => key.itemId.endsWith('-rue'));
    apply(const ReviewDiscoveryMistakes(), 70);
    answerAndAdvance(71, correct: true);
    final afterCorrectOther = state;
    expect(afterCorrectOther.mistakes.containsKey(wrongItemKey), isTrue);
    // Continue to the same source item; its correct review resolves the exact context.
    answerAndAdvance(72, correct: true);
    final afterCorrectSame = state;
    expect(afterCorrectSame.mistakes.containsKey(wrongItemKey), isFalse);
    expect(
        (afterCorrectSame.activities[activity]!.snapshot as DiscoveryCheckpoint)
            .session
            .round,
        2);
    expect(wrong.itemId, 'en-fr-u-y-listening-rue');
    expect(
        afterCorrectSame.history
            .expand((batch) => batch.attempts)
            .any((attempt) => attempt.submissionId == wrong.submissionId),
        isTrue);
  });

  test('new run preserves unresolved mistakes', () {
    start();
    answerAndAdvance(2, correct: false);
    final oldMistakes = Map.of(state.mistakes);
    final oldSummaries = Map.of(state.summaries);
    apply(StartLearningRun(options: RunOptions()), 3);
    expect(state.mistakes, oldMistakes);
    expect(state.summaries, oldSummaries);
    expect(state.activities[activity]!.cursor.generation, 2);
    expect(state.activities[activity]!.cursor.revision, 0);
  });

  test('legacy run starts with explanation assistance for every context', () {
    const legacy = 'lesson:en-fr-vowels';
    final started =
        applyTo(legacy, StartLearningRun(options: RunOptions()), 80).slot;
    expect(started.exposures, hasLength(4));
    for (final exposure in started.exposures.values) {
      expect(exposure.presentations, 0);
      expect(exposure.assistance, {AssistanceFlag.explanationVisible});
    }

    final firstAnswer = applyTo(
      legacy,
      ChooseSound(
        selectedSound: 'i',
        audioSource: AttemptAudioSource.practiceSpeech,
      ),
      81,
    );
    expect(firstAnswer.attempts.single.assistance,
        {AssistanceFlag.explanationVisible});
    final firstSummary = firstAnswer.summaries.entries.singleWhere((entry) =>
        entry.key.sound == 'i' &&
        entry.key.presentation == AttemptPresentation.firstInRun);
    expect(firstSummary.key.assistance, {AssistanceFlag.explanationVisible});

    final restarted =
        applyTo(legacy, StartLearningRun(options: RunOptions()), 82).slot;
    expect(restarted.exposures, hasLength(4));
    expect(
      restarted.exposures.values.every((exposure) =>
          exposure.presentations == 0 &&
          exposure.assistance.length == 1 &&
          exposure.assistance.contains(AssistanceFlag.explanationVisible)),
      isTrue,
    );
    expect(
      state.history.expand((batch) => batch.attempts).first.assistance,
      {AssistanceFlag.explanationVisible},
    );
  });

  test('legacy opened reference assistance persists and summarizes exactly',
      () {
    const legacy = 'lesson:en-fr-vowels';
    applyTo(legacy, StartLearningRun(options: RunOptions()), 90);
    final explain = engine.prepare(
        state: state,
        authGeneration: 0,
        activityId: legacy,
        action: ObserveAssistance(items: {
          ItemContextKey(itemId: 'lit', targetSound: 'i'),
        }, flags: {
          AssistanceFlag.answerRevealed,
        }),
        token: tokenFor(91),
        submittedAt: fixedTime,
        random: _NoDrawRandom());
    final t =
        engine.evaluate(state: state, command: explain, committedAt: fixedTime);
    state = stateAfter(state, t);
    final answer = applyTo(
        legacy,
        ChooseSound(
          selectedSound: 'i',
          audioSource: AttemptAudioSource.practiceSpeech,
        ),
        92);
    expect(answer.attempts.single.assistance,
        {AssistanceFlag.explanationVisible, AssistanceFlag.answerRevealed});
    final summary = answer.summaries.entries.singleWhere((entry) =>
        entry.key.sound == 'i' &&
        entry.key.presentation == AttemptPresentation.firstInRun &&
        entry.key.assistance.contains(AssistanceFlag.answerRevealed));
    expect(summary.key.assistance,
        {AssistanceFlag.explanationVisible, AssistanceFlag.answerRevealed});

    applyTo(legacy, const AdvanceLesson(), 93);
    final next = applyTo(
      legacy,
      ChooseSound(
        selectedSound: 'u',
        audioSource: AttemptAudioSource.practiceSpeech,
      ),
      94,
    );
    expect(
        next.attempts.single.assistance, {AssistanceFlag.explanationVisible});
    final saved = state.activities[legacy]!;
    expect(
      saved.exposures[ItemContextKey(itemId: 'lit', targetSound: 'i')]
          ?.assistance,
      {AssistanceFlag.explanationVisible, AssistanceFlag.answerRevealed},
    );
  });

  test('legacy rejects discovery-only after-debrief assistance', () {
    const legacy = 'lesson:en-fr-vowels';
    applyTo(legacy, StartLearningRun(options: RunOptions()), 100);
    expect(
      () => engine.prepare(
        state: state,
        authGeneration: 0,
        activityId: legacy,
        action: ObserveAssistance(items: {
          ItemContextKey(itemId: 'lit', targetSound: 'i'),
        }, flags: {
          AssistanceFlag.afterDebrief,
        }),
        token: tokenFor(101),
        submittedAt: fixedTime,
        random: _NoDrawRandom(),
      ),
      throwsA(isA<LearningInvalidCommandException>()),
    );
  });

  test('discovery run starts without assistance', () {
    start();
    expect(state.activities[activity]!.exposures, isEmpty);
  });

  test('closing help and pruning detail cannot make repeated item first', () {
    start();
    final firstWrong = apply(
      ChooseSound(
        selectedSound: 'y',
        audioSource: AttemptAudioSource.practiceSpeech,
      ),
      2,
    );
    final firstBucket = firstWrong.summaries.entries.singleWhere((entry) =>
        entry.key.sound == 'u' &&
        entry.key.presentation == AttemptPresentation.firstInRun);
    expect([firstBucket.value.correct, firstBucket.value.total], [0, 1]);
    apply(const AdvanceLesson(), 102);
    for (var i = 1; i < 10; i++) {
      answerAndAdvance(i + 3, correct: true);
    }
    apply(const ReviewDiscoveryMistakes(), 120);
    state = CourseLearningState(
      scope: state.scope,
      revision: state.revision,
      commitOrdinal: state.commitOrdinal,
      history: const [],
      activities: state.activities,
      mistakes: state.mistakes,
      summaries: state.summaries,
      completions: state.completions,
      bestScores: state.bestScores,
      pending: state.pending,
    );
    answerAndAdvance(121, correct: true);
    final slot = state.activities[activity]!;
    final exposure = slot.exposures[
        ItemContextKey(itemId: 'en-fr-u-y-listening-tout', targetSound: 'u')];
    expect(exposure!.presentations, 2);
    expect(exposure.assistance, contains(AssistanceFlag.afterDebrief));
    expect(state.history.expand((batch) => batch.attempts).single.presentation,
        AttemptPresentation.repeatInRun);
    expect(
        state.history.expand((batch) => batch.attempts).single.itemOccurrence,
        2);
    final repeat = state.summaries.entries.singleWhere((entry) =>
        entry.key.sound == 'u' &&
        entry.key.presentation == AttemptPresentation.repeatInRun);
    expect([repeat.value.total, repeat.value.correct], [1, 1]);
  });

  test('review only finish never completes lesson', () {
    start();
    for (var i = 0; i < 10; i++) {
      answerAndAdvance(i + 2);
    }
    apply(const FinishLearningActivity(recordCompletion: false), 90);
    expect(state.completions, isEmpty);
  });

  test('lesson finish is rejected until the saved policy is eligible', () {
    start();
    expect(
      () => engine.prepare(
        state: state,
        authGeneration: 0,
        activityId: activity,
        action: const FinishLearningActivity(),
        token: tokenFor(135),
        submittedAt: fixedTime,
        random: _NoDrawRandom(),
      ),
      throwsA(isA<LearningInvalidCommandException>()),
    );
    expect(state.completions, isEmpty);
  });

  test('legacy lessons keep one-pass progression and complete only on Finish',
      () {
    const legacy = 'lesson:en-fr-vowels';
    final definition = engine.registry.require(legacy);
    applyTo(legacy, StartLearningRun(options: RunOptions()), 140);
    for (var i = 0; i < definition.items.length; i++) {
      final item = definition.items[i];
      final selected = i == 0
          ? item.choices.firstWhere((choice) => choice != item.expectedChoice)
          : item.expectedChoice!;
      final answer = applyTo(
        legacy,
        ChooseSound(
          selectedSound: selected,
          audioSource: AttemptAudioSource.practiceSpeech,
        ),
        141 + i,
      );
      expect(answer.attempts.single.itemId, item.id);
      expect(answer.attempts.single.correct, selected == item.expectedChoice);
      expect(state.completions, isEmpty);
      applyTo(legacy, const AdvanceLesson(), 151 + i);
    }
    final completion = applyTo(legacy, const FinishLearningActivity(), 161);
    expect(
        (completion.slot.snapshot as LegacyLessonCheckpoint).finished, isTrue);
    expect(completion.completions.single.lessonId, 'en-fr-vowels');
    expect(completion.completions.single.policyKind,
        CompletionPolicyKind.legacyOnePass);
    expect(completion.completions.single.thresholdPercent, isNull);
  });

  test('drill derives correctness and increments only the committed candidate',
      () {
    const drill = 'drill:minimal-pairs';
    applyTo(drill, StartLearningRun(options: RunOptions()), 130);
    final wrong = applyTo(
      drill,
      ChooseDrillWord(
        selectedWord: 'tout',
        audioSource: AttemptAudioSource.practiceSpeech,
      ),
      131,
    );
    expect(wrong.attempts.single.correct, isFalse);
    expect(wrong.attempts.single.answer, isA<DrillChoiceAnswer>());
    expect((wrong.slot.snapshot as DrillCheckpoint).correct, 0);

    final correct = applyTo(
      drill,
      ChooseDrillWord(
        selectedWord: 'rue',
        audioSource: AttemptAudioSource.practiceSpeech,
      ),
      132,
    );
    expect(correct.attempts.single.correct, isTrue);
    expect((correct.slot.snapshot as DrillCheckpoint).correct, 1);
    final end = applyTo(drill, const EndDrill(), 133);
    expect((end.slot.snapshot as DrillCheckpoint).ended, isTrue);
    expect(end.attempts, isEmpty);
    expect(state.completions, isEmpty);
  });

  test('game actions remain invalid until the game transition task', () {
    expect(
      () => engine.prepare(
        state: state,
        authGeneration: 0,
        activityId: 'arcade:sound',
        action: StartLearningRun(options: RunOptions()),
        token: tokenFor(134),
        submittedAt: fixedTime,
        random: _NoDrawRandom(),
      ),
      throwsA(isA<LearningInvalidCommandException>()),
    );
  });

  test('content mismatch requires explicit new run', () {
    start();
    final current = state.activities[activity]!;
    final staleSlot = ActivitySlot(
      activityId: activity,
      kind: current.kind,
      contentRevision: 2,
      cursor: current.cursor,
      options: current.options,
      snapshot: current.snapshot,
      exposures: current.exposures,
      latestReceipt: current.latestReceipt,
    );
    state = CourseLearningState(
      scope: state.scope,
      revision: state.revision,
      commitOrdinal: state.commitOrdinal,
      history: state.history,
      activities: {...state.activities, activity: staleSlot},
      mistakes: state.mistakes,
      summaries: state.summaries,
      completions: state.completions,
      bestScores: state.bestScores,
      pending: state.pending,
    );
    expect(
        () => engine.prepare(
            state: state,
            authGeneration: 0,
            activityId: activity,
            action: ChooseSound(
                selectedSound: 'u',
                audioSource: AttemptAudioSource.practiceSpeech),
            token: tokenFor(99),
            submittedAt: fixedTime,
            random: _NoDrawRandom()),
        throwsA(isA<LearningContentChangedException>()));
    final newRun = apply(StartLearningRun(options: RunOptions()), 100);
    expect(newRun.slot.contentRevision, 1);
    expect(newRun.slot.cursor.generation, 2);
    expect(newRun.slot.cursor.sequence, 2);
    expect(newRun.slot.cursor.revision, 0);
  });

  test('caller-supplied feedback and candidate are replayed, not trusted', () {
    start();
    final command = engine.prepare(
        state: state,
        authGeneration: 0,
        activityId: activity,
        action: ChooseSound(
            selectedSound: 'u', audioSource: AttemptAudioSource.practiceSpeech),
        token: tokenFor(201),
        submittedAt: fixedTime,
        random: _NoDrawRandom());
    final tampered = LearningCommand(
      scope: command.scope,
      authGeneration: command.authGeneration,
      activityId: command.activityId,
      expected: command.expected,
      token: command.token,
      submittedAt: command.submittedAt,
      action: command.action,
      draws: command.draws,
      candidate: DiscoveryCheckpoint(
          session: LessonSectionSession(
        itemIds: frenchUySection.items.map((item) => item.id).toList(),
        sessionId: 'tampered',
      )),
      feedback: LearningFeedback(
          message: 'forged', points: 999, cascades: 0, bonus: 0, correct: true),
    );
    expect(
        () => engine.evaluate(
            state: state, command: tampered, committedAt: fixedTime),
        throwsA(isA<LearningInvalidCommandException>()));
  });
}

class _NoDrawRandom implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}
