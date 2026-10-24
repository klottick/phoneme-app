import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/french_uy_demo_spelling_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/spelling_learning_command.dart';
import 'package:linguist/src/core/course/spelling_learning_state.dart';
import 'package:linguist/src/core/course/spelling_learning_transition.dart';
import 'package:linguist/src/core/course/storage/learning_storage_scope.dart';
import 'package:linguist/src/core/course/storage/spelling_learning_checkpoint_codec.dart';

void main() {
  late FrenchUyDemoSpellingCatalogue catalogue;
  late SpellingProfileScope scope;
  late SpellingLearningTransitionEngine engine;
  late SpellingLearningState state;
  var commandNumber = 0;

  DateTime time(int n) =>
      DateTime.utc(2026, 10, 24).add(Duration(microseconds: n));

  String token(int n) => 'token${n.toString().padLeft(17, '0')}';

  SpellingLearningTransition dispatch(SpellingAction action) {
    final now = time(commandNumber);
    final command = engine.prepare(
      state: state,
      action: action,
      authGeneration: 7,
      token: token(commandNumber),
      submittedAt: now,
    );
    commandNumber += 1;
    final transition = engine.evaluate(
      state: state,
      command: command,
      committedAt: now,
    );
    state = transition.nextState;
    return transition;
  }

  LessonSectionSession session() {
    final checkpoint = state.slots[uyDemoSpellingActivityId]!.checkpoint;
    return LessonSectionSession.fromJson(
      Map<String, dynamic>.from(checkpoint.sessionJson),
      itemIds: catalogue.rows.map((row) => row.exercise.id).toList(),
      contentRevision: catalogue.contentRevision,
    );
  }

  SpellingPlaybackObservation playback({
    String? itemId,
    SpellingProfileScope? profile,
    int authGeneration = 7,
    int? runGeneration,
    int? round,
    String? referenceId,
    int promptEpoch = 3,
  }) {
    final current = session().currentItemId!;
    final id = itemId ?? current;
    final row = catalogue.rows.singleWhere((row) => row.exercise.id == id);
    final slot = state.slots[uyDemoSpellingActivityId]!;
    return SpellingPlaybackObservation(
      profile: profile ?? scope,
      authGeneration: authGeneration,
      activityId: uyDemoSpellingActivityId,
      contentRevision: catalogue.contentRevision,
      runGeneration: runGeneration ?? slot.cursor.generation,
      round: round ?? session().round,
      itemId: id,
      referenceId: referenceId ?? row.exercise.audioRefId,
      promptEpoch: promptEpoch,
      outcome: CourseAudioOutcome.completed,
      source: CourseAudioSource.unverifiedRecording,
    );
  }

  SpellingLearningTransition answer({
    required bool correct,
    SpellingPlaybackObservation? observation,
  }) {
    final id = session().currentItemId!;
    final row = catalogue.rows.singleWhere((row) => row.exercise.id == id);
    final expected = row.exercise.correctOptionId;
    final wrong = row.exercise.options
        .singleWhere((option) => option.id != expected)
        .id;
    return dispatch(
      AnswerSpellingChoice(
        itemId: id,
        contentRevision: catalogue.contentRevision,
        selectedOptionId: correct ? expected : wrong,
        expectedOptionIdSnapshot: expected,
        playback: observation ?? playback(),
      ),
    );
  }

  void answerAndAdvance({bool correct = true}) {
    answer(correct: correct);
    dispatch(const AdvanceSpellingItem());
  }

  void startPractice([String id = 'practice-1']) {
    dispatch(StartSpellingPractice(sessionId: id, policy: LessonPolicy()));
  }

  void completeFirstPass({String firstItem = 'uy-demo-spelling-01'}) {
    startPractice();
    for (final row in catalogue.rows) {
      answerAndAdvance(correct: row.exercise.id != firstItem);
    }
  }

  setUp(() {
    catalogue = loadFrenchUyDemoSpellingCatalogue();
    scope = SpellingProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    engine = SpellingLearningTransitionEngine(catalogue: catalogue);
    state = SpellingLearningState.empty(scope);
    commandNumber = 0;
  });

  test(
    'spelling uses its own storage family without changing old families',
    () {
      expect(LearningFamily.course.databaseValue, 'course');
      expect(LearningFamily.comparison.databaseValue, 'comparison');
      expect(LearningFamily.sentenceHunt.databaseValue, 'sentence-hunt');
      expect(scope.toStorageScope().family, LearningFamily.spelling);
      expect(scope.toStorageScope().courseId, 'en-fr');
    },
  );

  test('practice pins the default policy and immutable first-pass prefix', () {
    expect(LessonPolicy().requiredCorrect(10), 8);
    startPractice();
    final initial = state.slots[uyDemoSpellingActivityId]!;
    expect(
      initial.cursor,
      SpellingCursor(generation: 1, sequence: 1, revision: 0),
    );
    expect(initial.checkpoint.sessionJson['round'], 1);
    expect(initial.checkpoint.finished, isFalse);

    answer(correct: false);

    final slot = state.slots[uyDemoSpellingActivityId]!;
    expect(slot.cursor.generation, 1);
    expect(slot.cursor.sequence, 2);
    expect(slot.cursor.revision, 1);
    expect(slot.checkpoint.policy.completionThresholdPercent, 80);
    expect(slot.checkpoint.firstAttemptAnswers, {'uy-demo-spelling-01': false});
    expect(slot.checkpoint.sessionJson['round'], 1);
    expect(slot.checkpoint.sessionJson['latestAnswers'], {
      'uy-demo-spelling-01': false,
    });
    expect(
      () => slot.checkpoint.firstAttemptAnswers['uy-demo-spelling-02'] = true,
      throwsUnsupportedError,
    );
  });

  test('practice retry improves latest score but not the first score', () {
    completeFirstPass();
    final first = Map<String, bool>.of(
      state.slots[uyDemoSpellingActivityId]!.checkpoint.firstAttemptAnswers,
    );
    expect(first, hasLength(10));
    expect(first['uy-demo-spelling-01'], isFalse);
    expect(session().canComplete, isTrue);

    dispatch(const ReviewSpellingMistakes());
    final retry = answer(correct: true);
    expect(retry.attempts.single.presentation, AttemptPresentation.repeatInRun);
    expect(retry.attempts.single.afterDebrief, isTrue);
    expect(retry.attempts.single.teachingExposed, isTrue);
    dispatch(const AdvanceSpellingItem());

    final checkpoint = state.slots[uyDemoSpellingActivityId]!.checkpoint;
    expect(checkpoint.firstAttemptAnswers, first);
    expect(checkpoint.sessionJson['latestAnswers'], {
      for (final row in catalogue.rows) row.exercise.id: true,
    });
    expect(
      state.slots[uyDemoSpellingActivityId]!.checkpoint.sessionJson['round'],
      2,
    );
    expect(state.attempts, hasLength(11));
  });

  test('review-only start carries the full finished practice baseline', () {
    completeFirstPass();
    final source = state.slots[uyDemoSpellingActivityId]!;
    final sourceFirst = Map<String, bool>.of(
      source.checkpoint.firstAttemptAnswers,
    );
    final sourceLatest = Map<String, bool>.of(
      Map<String, bool>.from(
        source.checkpoint.sessionJson['latestAnswers']! as Map,
      ),
    );
    dispatch(const FinishSpellingRun(recordCompletion: true));
    expect(state.slots[uyDemoSpellingActivityId]!.checkpoint.finished, isTrue);
    expect(state.completions, hasLength(1));
    final finishedPractice = state.slots[uyDemoSpellingActivityId]!;

    final review = dispatch(
      const StartSpellingReviewOnly(sessionId: 'review-only-1'),
    );
    final slot = review.slot;
    expect(slot.cursor.generation, source.cursor.generation + 1);
    expect(slot.cursor.sequence, finishedPractice.cursor.sequence + 1);
    expect(slot.cursor.revision, 0);
    expect(slot.checkpoint.mode, SpellingRunMode.reviewOnly);
    expect(slot.checkpoint.finished, isFalse);
    expect(slot.checkpoint.sessionId, 'review-only-1');
    expect(slot.checkpoint.runStartRound, 2);
    expect(slot.checkpoint.sessionJson['round'], 2);
    expect(slot.checkpoint.sessionJson['queue'], ['uy-demo-spelling-01']);
    expect(slot.checkpoint.firstAttemptAnswers, sourceFirst);
    expect(
      slot.checkpoint.baseline!.sourceGeneration,
      source.cursor.generation,
    );
    expect(slot.checkpoint.baseline!.sourceSessionId, 'practice-1');
    expect(slot.checkpoint.baseline!.sourceContentRevision, 1);
    expect(slot.checkpoint.baseline!.sourceRound, 1);
    expect(slot.checkpoint.baseline!.latestPracticeAnswers, sourceLatest);
    expect(state.attempts, hasLength(10));
    expect(state.completions, hasLength(1));

    const codec = SpellingLearningCheckpointCodec();
    final encoded = codec.encode(slot.checkpoint);
    final checkpointJson = jsonDecode(encoded) as Map<String, dynamic>;
    expect((checkpointJson['baseline'] as Map).keys, [
      'sourceGeneration',
      'sourceSessionId',
      'sourceContentRevision',
      'sourceRound',
      'firstAttemptAnswers',
      'latestPracticeAnswers',
      'policy',
    ]);
    final restored = codec.decode(
      encoded,
      scope: scope,
      catalogue: catalogue,
      policy: slot.checkpoint.policy,
    );
    expect(codec.encode(restored), encoded);
  });

  test('review-only answers do not rewrite its carried practice scores', () {
    completeFirstPass();
    dispatch(const StartSpellingReviewOnly(sessionId: 'review-only-1'));
    final before = state.slots[uyDemoSpellingActivityId]!.checkpoint;
    final first = Map<String, bool>.of(before.firstAttemptAnswers);
    final baselineLatest = Map<String, bool>.of(
      before.baseline!.latestPracticeAnswers,
    );

    final retry = answer(correct: true);
    expect(retry.attempts.single.presentation, AttemptPresentation.repeatInRun);
    expect(retry.attempts.single.afterDebrief, isTrue);
    dispatch(const AdvanceSpellingItem());

    final checkpoint = state.slots[uyDemoSpellingActivityId]!.checkpoint;
    expect(checkpoint.firstAttemptAnswers, first);
    expect(checkpoint.baseline!.firstAttemptAnswers, first);
    expect(checkpoint.baseline!.latestPracticeAnswers, baselineLatest);
    expect(checkpoint.sessionJson['latestAnswers'], {
      for (final row in catalogue.rows) row.exercise.id: true,
    });
    expect(state.completions, isEmpty);
  });

  test('stale playback observations are rejected without a transition', () {
    startPractice();
    final before = state;
    final otherOwner = SpellingProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.account('another-user'),
    );
    final wrongReference = playback(referenceId: 'fr-word-not-current');
    final wrongRound = playback(round: 2);
    final wrongItem = playback(itemId: 'uy-demo-spelling-02');
    final wrongOwner = playback(profile: otherOwner);
    final oldAuth = playback(authGeneration: 6);

    for (final observation in [
      wrongReference,
      wrongRound,
      wrongItem,
      wrongOwner,
      oldAuth,
    ]) {
      final id = session().currentItemId!;
      final row = catalogue.rows.singleWhere((row) => row.exercise.id == id);
      expect(
        () => engine.prepare(
          state: state,
          action: AnswerSpellingChoice(
            itemId: id,
            contentRevision: catalogue.contentRevision,
            selectedOptionId: row.exercise.correctOptionId,
            expectedOptionIdSnapshot: row.exercise.correctOptionId,
            playback: observation,
          ),
          authGeneration: 7,
          token: token(100 + commandNumber++),
          submittedAt: time(100 + commandNumber),
        ),
        throwsA(
          anyOf(
            isA<ArgumentError>(),
            isA<StateError>(),
            isA<FormatException>(),
          ),
        ),
      );
    }
    expect(() => playback(promptEpoch: -1), throwsArgumentError);
    expect(state, same(before));
    expect(state.attempts, isEmpty);
  });

  test('finished practice requires an explicit new generation', () {
    startPractice();
    for (var index = 0; index < catalogue.rows.length; index += 1) {
      answerAndAdvance(correct: true);
    }
    final finish = engine.prepare(
      state: state,
      action: const FinishSpellingRun(recordCompletion: true),
      authGeneration: 7,
      token: token(90),
      submittedAt: time(90),
    );
    final finished = engine.evaluate(
      state: state,
      command: finish,
      committedAt: time(90),
    );
    state = finished.nextState;
    expect(finished.slot.checkpoint.finished, isTrue);
    expect(state.completions, hasLength(1));
    final duplicate = engine.evaluate(
      state: state,
      command: finish,
      committedAt: time(90),
    );
    expect(duplicate.duplicate, isTrue);
    expect(duplicate.nextState, same(state));

    expect(
      () => dispatch(const AdvanceSpellingItem()),
      throwsA(anyOf(isA<ArgumentError>(), isA<StateError>())),
    );
    final beforeRestart = state.slots[uyDemoSpellingActivityId]!;
    final restart = dispatch(
      StartSpellingPractice(sessionId: 'practice-2', policy: LessonPolicy()),
    );
    expect(restart.slot.cursor.generation, 2);
    expect(restart.slot.cursor.sequence, beforeRestart.cursor.sequence + 1);
    expect(restart.slot.cursor.revision, 0);
    expect(restart.slot.checkpoint.finished, isFalse);
    expect(restart.slot.checkpoint.firstAttemptAnswers, isEmpty);
    expect(state.completions, hasLength(1));
  });

  test('practice rejects a threshold other than the saved default', () {
    expect(
      () => dispatch(
        StartSpellingPractice(
          sessionId: 'non-default',
          policy: LessonPolicy(completionThresholdPercent: 75),
        ),
      ),
      throwsArgumentError,
    );
    expect(state.revision, 0);
  });

  test('review-only finish cannot create practice completion', () {
    completeFirstPass();
    dispatch(const StartSpellingReviewOnly(sessionId: 'review-only-1'));
    answer(correct: true);
    dispatch(const AdvanceSpellingItem());
    expect(
      () => dispatch(const FinishSpellingRun(recordCompletion: true)),
      throwsA(
        anyOf(isA<ArgumentError>(), isA<StateError>(), isA<FormatException>()),
      ),
    );
    expect(state.completions, isEmpty);
    final finished = dispatch(const FinishSpellingRun(recordCompletion: false));
    expect(finished.slot.checkpoint.finished, isTrue);
    expect(state.completions, isEmpty);
  });
}
