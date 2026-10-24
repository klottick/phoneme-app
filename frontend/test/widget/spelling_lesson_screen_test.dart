import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/french_uy_demo_spelling_content.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/spelling_learning_command.dart';
import 'package:linguist/src/core/course/spelling_learning_providers.dart';
import 'package:linguist/src/core/course/spelling_learning_state.dart';
import 'package:linguist/src/core/course/spelling_learning_store.dart';
import 'package:linguist/src/core/course/spelling_learning_transition.dart';
import 'package:linguist/src/core/providers/app_providers.dart';
import 'package:linguist/src/features/course/spelling_lesson_screen.dart';
import 'package:linguist/src/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/course_learning_widget_store.dart';
import '../support/map_motion_test_support.dart';
import '../support/sentence_hunt_fixtures.dart';

const _activityId = 'en-fr-u-y-spelling';
const _prompt = 'Listen, then choose how the vowel is written.';
const _alphaDisclosure =
    'Alpha audio: recordings are unverified; device speech is practice-only.';
const _practiceDisclosure =
    'Demo practice: this authored spelling content has not had qualified French review. It is practice, not an assessment.';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'});
    courseBackend = null;
  });

  testWidgets(
    'spelling_prompt_and_disclosures_are_exact_and_options_wait_for_audio',
    (tester) async {
      final store = _HeldSpellingStore();
      final audio = _ControlledSpellingAudio();
      final app = await _mountSpelling(tester, store, audio);
      addTearDown(() => app.dispose(tester));

      expect(find.text(_prompt), findsOneWidget);
      expect(find.text(_alphaDisclosure), findsOneWidget);
      expect(find.text(_practiceDisclosure), findsOneWidget);
      expect(find.text('u'), findsOneWidget);
      expect(find.text('ou'), findsOneWidget);
      expect(_option(tester, 'u').onPressed, isNull);
      expect(_option(tester, 'ou').onPressed, isNull);
      expect(store.submissions, isEmpty, reason: 'entry must not auto-start');

      await tester.tap(find.text('Start practice'));
      await tester.pumpAndSettle();
      expect(store.submissions, hasLength(1));
      expect(store.submissions.single.action, isA<StartSpellingPractice>());

      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      expect(audio.requests, hasLength(1));
      expect(audio.requests.single.referenceId, 'fr-word-tout');
      expect(audio.requests.single.use, CourseAudioUse.alphaPractice);
      expect(audio.requests.single.allowPracticeTts, isFalse);
      expect(_option(tester, 'u').onPressed, isNull);
      audio.requests.single.complete();
      await tester.pump();
      await tester.pump();
      expect(_option(tester, 'u').onPressed, isNotNull);
      expect(_option(tester, 'ou').onPressed, isNotNull);
    },
  );

  testWidgets('held_answer_save_stays_secret_until_durable_ack', (
    tester,
  ) async {
    final store = _HeldSpellingStore();
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(tester, store, audio);
    addTearDown(() => app.dispose(tester));

    await _startAndHearFirst(tester, store, audio);
    store.holdNext = true;
    await tester.tap(find.text('ou'));
    await tester.pump();
    expect(find.text('Saving your answer…'), findsOneWidget);
    expect(find.text('tout'), findsNothing);
    expect(
      find.text('In tout, ou represents the authored target /u/.'),
      findsNothing,
    );
    expect(find.text('/u/'), findsNothing);
    expect(find.text('Correct spelling: ou'), findsNothing);
    expect(_option(tester, 'u').onPressed, isNull);
    expect(_option(tester, 'ou').onPressed, isNull);
    expect(_spellingSemantics(tester), isNot(contains('tout')));
    expect(
      _spellingSemantics(tester),
      isNot(contains('In tout, ou represents the authored target /u/.')),
    );
    expect(store.pendingSubmissions, hasLength(1));

    store.completeNext();
    await tester.pump();
    await tester.pump();
    expect(find.text('tout'), findsOneWidget);
    expect(
      find.text('In tout, ou represents the authored target /u/.'),
      findsOneWidget,
    );
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    final Text highlightedWord = tester.widget<Text>(
      find.byKey(const ValueKey<String>('spelling-feedback-word')),
    );
    final TextSpan highlighted =
        (highlightedWord.textSpan! as TextSpan).children![1] as TextSpan;
    expect(highlighted.text, 'ou');
    expect(highlighted.style?.decoration, TextDecoration.underline);
  });

  testWidgets('failed_or_stale_replay_cannot_reuse_previous_grant', (
    tester,
  ) async {
    final store = _HeldSpellingStore();
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(tester, store, audio);
    addTearDown(() => app.dispose(tester));

    await _startAndHearFirst(tester, store, audio);
    expect(_option(tester, 'u').onPressed, isNotNull);

    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    expect(audio.requests, hasLength(2));
    expect(_option(tester, 'u').onPressed, isNull);
    expect(_option(tester, 'ou').onPressed, isNull);
    audio.requests.last.fail();
    await tester.pump();
    await tester.pump();

    expect(_option(tester, 'u').onPressed, isNull);
    expect(_option(tester, 'ou').onPressed, isNull);
    expect(
      store.submissions.where(
        (command) => command.action is AnswerSpellingChoice,
      ),
      isEmpty,
    );
    expect(find.text('tout'), findsNothing);
    expect(
      find.text('In tout, ou represents the authored target /u/.'),
      findsNothing,
    );
  });

  testWidgets('cancelled_replay_cannot_reuse_previous_grant', (tester) async {
    final store = _HeldSpellingStore();
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(tester, store, audio);
    addTearDown(() => app.dispose(tester));

    await _startAndHearFirst(tester, store, audio);
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    audio.requests.last.cancel();
    await tester.pump();
    await tester.pump();

    expect(_option(tester, 'u').onPressed, isNull);
    expect(_option(tester, 'ou').onPressed, isNull);
    expect(
      store.submissions.where(
        (command) => command.action is AnswerSpellingChoice,
      ),
      isEmpty,
    );
    expect(find.text('tout'), findsNothing);
  });

  testWidgets('stale_replay_completion_cannot_restore_a_retired_grant', (
    tester,
  ) async {
    final store = _HeldSpellingStore();
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(tester, store, audio);
    addTearDown(() => app.dispose(tester));

    await _startAndHearFirst(tester, store, audio);
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    expect(audio.requests, hasLength(2));
    expect(_option(tester, 'u').onPressed, isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    audio.requests.last.complete();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(_option(tester, 'u').onPressed, isNull);
    expect(_option(tester, 'ou').onPressed, isNull);
    expect(find.text('tout'), findsNothing);
    expect(
      store.submissions.where(
        (command) => command.action is AnswerSpellingChoice,
      ),
      isEmpty,
    );
  });

  testWidgets('route_exit_retires_inflight_audio_completion', (tester) async {
    final store = _HeldSpellingStore();
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(tester, store, audio);
    addTearDown(() => app.dispose(tester));
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to the word'));
    await tester.pump();

    app.router.go('/home');
    await tester.pumpAndSettle();
    expect(audio.stopCalls, greaterThan(0));
    audio.requests.single.complete();
    await tester.pump();
    await tester.pump();

    expect(
      store.submissions.where(
        (command) => command.action is AnswerSpellingChoice,
      ),
      isEmpty,
    );
  });

  testWidgets('failed_save_retries_the_exact_frozen_command', (tester) async {
    final store = _HeldSpellingStore();
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(tester, store, audio);
    addTearDown(() => app.dispose(tester));

    await _startAndHearFirst(tester, store, audio);
    store.holdNext = true;
    await tester.tap(find.text('ou'));
    await tester.pump();
    final frozen = store.pendingSubmissions.single.command;
    store.failNext();
    await tester.pump();
    await tester.pump();
    expect(find.text('Retry saving'), findsOneWidget);
    expect(find.text('tout'), findsNothing);
    expect(
      find.text('In tout, ou represents the authored target /u/.'),
      findsNothing,
    );

    await tester.tap(find.text('Retry saving'));
    await tester.pumpAndSettle();
    expect(store.submissions, hasLength(3));
    expect(identical(store.submissions[1], frozen), isTrue);
    expect(identical(store.submissions[2], frozen), isTrue);
    expect(store.committedState.attempts, hasLength(1));
    expect(find.text('tout'), findsOneWidget);
    expect(
      find.text('In tout, ou represents the authored target /u/.'),
      findsOneWidget,
    );
  });

  testWidgets('lost_ack_reloads_the_same_saved_receipt_without_resubmitting', (
    tester,
  ) async {
    final store = _HeldSpellingStore();
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(tester, store, audio);
    addTearDown(() => app.dispose(tester));

    await _startAndHearFirst(tester, store, audio);
    store.loseNextAckAfterCommit = true;
    await tester.tap(find.text('ou'));
    await tester.pumpAndSettle();

    expect(store.retryLoadCalls, 1);
    expect(store.submissions, hasLength(2));
    expect(store.committedState.attempts, hasLength(1));
    expect(find.text('tout'), findsOneWidget);
    expect(
      find.text('In tout, ou represents the authored target /u/.'),
      findsOneWidget,
    );
  });

  testWidgets('duplicate_ack_is_idempotent_for_saved_feedback', (tester) async {
    final store = _HeldSpellingStore();
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(tester, store, audio);
    addTearDown(() => app.dispose(tester));

    await _startAndHearFirst(tester, store, audio);
    store.duplicateNextAck = true;
    await tester.tap(find.text('ou'));
    await tester.pumpAndSettle();

    expect(store.committedState.attempts, hasLength(1));
    expect(
      store.submissions.where(
        (command) => command.action is AnswerSpellingChoice,
      ),
      hasLength(1),
    );
    expect(find.text('tout'), findsOneWidget);
    expect(
      find.text('In tout, ou represents the authored target /u/.'),
      findsOneWidget,
    );
  });

  testWidgets('saved_feedback_restores_without_replay_or_new_answer', (
    tester,
  ) async {
    final seed = _HeldSpellingStore();
    await seed.perform(
      StartSpellingPractice(
        sessionId: 'restored-practice-run',
        policy: LessonPolicy(),
      ),
    );
    final row = seed.catalogue.rows.first;
    await seed.perform(
      AnswerSpellingChoice(
        itemId: row.exercise.id,
        contentRevision: seed.catalogue.contentRevision,
        selectedOptionId: row.exercise.correctOptionId,
        expectedOptionIdSnapshot: row.exercise.correctOptionId,
        playback: _observation(seed, row, promptEpoch: 1),
      ),
    );
    final state = seed.committedState;
    final store = _HeldSpellingStore(initialState: state);
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(tester, store, audio);
    addTearDown(() => app.dispose(tester));

    expect(audio.requests, isEmpty);
    expect(store.submissions, isEmpty);
    expect(store.loadCalls, 1);
    expect(find.text('tout'), findsOneWidget);
    expect(
      find.text('In tout, ou represents the authored target /u/.'),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets(
    'canonical_review_url_finishes_review_then_explicitly_starts_practice',
    (tester) async {
      final seed = _HeldSpellingStore();
      await _practiceDebrief(seed, firstItemWrong: true);
      await seed.perform(const FinishSpellingRun(recordCompletion: true));
      final reviewState = seed.committedState;
      final sourceSlot = reviewState.slots[_activityId]!;
      final sourceFirstAnswers = Map<String, bool>.of(
        sourceSlot.checkpoint.firstAttemptAnswers,
      );
      final completionsBeforeReview = List<SpellingCompletion>.of(
        reviewState.completions,
      );
      expect(completionsBeforeReview, hasLength(1));
      final store = _HeldSpellingStore(initialState: reviewState);
      final audio = _ControlledSpellingAudio();
      final app = await _mountSpelling(
        tester,
        store,
        audio,
        location: '/course-spelling/$_activityId?review=true',
      );
      addTearDown(() => app.dispose(tester));

      expect(store.submissions, isEmpty);
      expect(audio.requests, isEmpty);
      expect(find.text('Start review-only'), findsOneWidget);
      expect(find.text('Finish practice'), findsNothing);
      expect(find.text('First attempt in this run: 9/10'), findsOneWidget);
      expect(find.text('Latest practice score: 9/10'), findsOneWidget);
      expect(
        app.router.routeInformationProvider.value.uri.queryParameters['review'],
        'true',
      );

      await tester.tap(find.text('Start review-only'));
      await tester.pumpAndSettle();
      expect(
        find.text('Saved spelling progress could not be loaded.'),
        findsNothing,
      );
      expect(store.prepareCalls, 1);
      expect(store.submissions, hasLength(1));
      expect(store.submissions.single.action, isA<StartSpellingReviewOnly>());
      expect(
        store.committedState.slots[_activityId]!.checkpoint.mode,
        SpellingRunMode.reviewOnly,
      );
      expect(
        app.router.routeInformationProvider.value.uri.queryParameters['review'],
        'true',
      );

      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      audio.requests.last.complete();
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('ou'));
      await tester.pumpAndSettle();
      expect(store.committedState.attempts.length, 11);
      expect(store.committedState.completions, completionsBeforeReview);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Section debrief'), findsOneWidget);
      expect(
        find.text('Finish review'),
        findsOneWidget,
        reason:
            'an explicitly started review-only run can finish on its canonical review URL',
      );
      expect(
        app.router.routeInformationProvider.value.uri.queryParameters['review'],
        'true',
      );
      await tester.tap(find.text('Finish review'));
      await tester.pumpAndSettle();
      expect(store.submissions.last.action, isA<FinishSpellingRun>());
      expect(
        (store.submissions.last.action as FinishSpellingRun).recordCompletion,
        isFalse,
      );
      expect(store.committedState.completions, completionsBeforeReview);
      expect(find.text('Review run complete.'), findsOneWidget);
      expect(
        find.text('Start new practice'),
        findsOneWidget,
        reason:
            'a finished review-only generation needs an explicit new-practice action',
      );
      expect(
        store.committedState.slots[_activityId]!.checkpoint.firstAttemptAnswers,
        sourceFirstAnswers,
      );
      final finishedReviewSlot = store.committedState.slots[_activityId]!;
      final reviewBaseline = finishedReviewSlot.checkpoint.baseline!;
      expect(reviewBaseline.sourceGeneration, sourceSlot.cursor.generation);
      expect(reviewBaseline.sourceSessionId, sourceSlot.checkpoint.sessionId);
      expect(reviewBaseline.firstAttemptAnswers, sourceFirstAnswers);
      expect(
        reviewBaseline.latestPracticeAnswers,
        sourceSlot.checkpoint.firstAttemptAnswers,
      );
      final int finishedReviewGeneration = finishedReviewSlot.cursor.generation;
      final int submissionsBeforeInspection = store.submissions.length;

      app.router.go('/course-spelling/$_activityId');
      await tester.pumpAndSettle();
      expect(store.submissions, hasLength(submissionsBeforeInspection));
      expect(
        store.committedState.slots[_activityId]!.checkpoint.mode,
        SpellingRunMode.reviewOnly,
      );
      expect(
        store.committedState.slots[_activityId]!.checkpoint.finished,
        isTrue,
      );
      expect(find.text('Start new practice'), findsOneWidget);
      expect(audio.requests, hasLength(1));

      await tester.tap(find.text('Start new practice'));
      await tester.pumpAndSettle();
      expect(store.submissions, hasLength(submissionsBeforeInspection + 1));
      expect(store.submissions.last.action, isA<StartSpellingPractice>());
      final newPracticeSlot = store.committedState.slots[_activityId]!;
      expect(newPracticeSlot.checkpoint.mode, SpellingRunMode.practice);
      expect(newPracticeSlot.checkpoint.finished, isFalse);
      expect(newPracticeSlot.cursor.generation, finishedReviewGeneration + 1);
      expect(newPracticeSlot.checkpoint.firstAttemptAnswers, isEmpty);
      expect(store.committedState.attempts, hasLength(11));
      expect(store.committedState.completions, completionsBeforeReview);
      expect(
        audio.requests,
        hasLength(1),
        reason: 'new practice must not auto-play audio',
      );
    },
  );

  testWidgets(
    'finished_review_only_route_requires_explicit_new_practice_action',
    (tester) async {
      final seed = _HeldSpellingStore();
      await _practiceDebrief(seed, firstItemWrong: true);
      await seed.perform(const FinishSpellingRun(recordCompletion: true));
      await seed.perform(
        const StartSpellingReviewOnly(sessionId: 'finished-review-route'),
      );
      final row = seed.catalogue.rows.first;
      await seed.perform(
        AnswerSpellingChoice(
          itemId: row.exercise.id,
          contentRevision: seed.catalogue.contentRevision,
          selectedOptionId: row.exercise.correctOptionId,
          expectedOptionIdSnapshot: row.exercise.correctOptionId,
          playback: _observation(seed, row, promptEpoch: 11, round: 2),
        ),
      );
      await seed.perform(const AdvanceSpellingItem());
      await seed.perform(const FinishSpellingRun(recordCompletion: false));
      final int finishedGeneration =
          seed.committedState.slots[_activityId]!.cursor.generation;
      final List<SpellingCompletion> completions = List<SpellingCompletion>.of(
        seed.committedState.completions,
      );
      expect(completions, hasLength(1));
      final store = _HeldSpellingStore(initialState: seed.committedState);
      final audio = _ControlledSpellingAudio();
      final app = await _mountSpelling(
        tester,
        store,
        audio,
        location: '/course-spelling/$_activityId?review=true',
      );
      addTearDown(() => app.dispose(tester));

      expect(
        store.submissions,
        isEmpty,
        reason: 'inspection is not a new generation',
      );
      expect(audio.requests, isEmpty);
      expect(find.text('Review run complete.'), findsOneWidget);
      expect(find.text('Start new practice'), findsOneWidget);

      app.router.go('/course-spelling/$_activityId');
      await tester.pumpAndSettle();
      expect(
        store.submissions,
        isEmpty,
        reason: 'query removal is not a new generation',
      );
      expect(
        store.committedState.slots[_activityId]!.checkpoint.mode,
        SpellingRunMode.reviewOnly,
      );
      expect(
        store.committedState.slots[_activityId]!.checkpoint.finished,
        isTrue,
      );
      expect(store.committedState.completions, completions);
      expect(find.text('Start new practice'), findsOneWidget);

      await tester.tap(find.text('Start new practice'));
      await tester.pumpAndSettle();
      expect(store.submissions, hasLength(1));
      expect(store.submissions.single.action, isA<StartSpellingPractice>());
      expect(
        store.committedState.slots[_activityId]!.cursor.generation,
        finishedGeneration + 1,
      );
      expect(
        store.committedState.slots[_activityId]!.checkpoint.mode,
        SpellingRunMode.practice,
      );
      expect(store.committedState.completions, completions);
      expect(audio.requests, isEmpty);
    },
  );

  testWidgets('initial_load_completed_while_paused_recovers_on_resume', (
    tester,
  ) async {
    final store = _HeldSpellingStore();
    final load = Completer<SpellingLearningState>();
    store.heldLoad = load;
    final audio = _ControlledSpellingAudio();
    final auth = LearningAuthTracker(owner: store.scope.owner, ready: true);
    final container = ProviderContainer(
      overrides: [
        spellingCatalogueProvider.overrideWithValue(store.catalogue),
        spellingLearningStoreProvider.overrideWithValue(store),
        learningAuthScopeProvider.overrideWith((ref) => auth),
        courseAudioProvider.overrideWithValue(audio),
        courseReferenceAudioProvider.overrideWithValue(audio),
      ],
    );
    await _pumpStandaloneSpelling(tester, container);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });

    expect(store.loadCalls, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    load.complete(store.committedState);
    await tester.pump();
    expect(find.text('Start practice'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Start practice'),
      findsOneWidget,
      reason:
          'a load completed during pause must be installed or reloaded on resume',
    );
    expect(store.loadCalls, 2);
    expect(
      store.submissions,
      isEmpty,
      reason: 'resume must not start practice',
    );
    expect(audio.requests, isEmpty, reason: 'resume must not replay audio');
  });

  testWidgets('paused_initial_load_cannot_restore_a_stale_owner', (
    tester,
  ) async {
    final seed = _HeldSpellingStore();
    final staleOwnerState = await _practiceDebrief(seed, firstItemWrong: true);
    final staleLoad = Completer<SpellingLearningState>();
    final staleStore = _HeldSpellingStore(initialState: staleOwnerState)
      ..heldLoad = staleLoad;
    final currentStore = _HeldSpellingStore(
      owner: LearningOwner.account('current-owner'),
    );
    final audio = _ControlledSpellingAudio();
    final auth = LearningAuthTracker(
      owner: staleStore.scope.owner,
      ready: true,
    );
    final activeStoreProvider = StateProvider<SpellingLearningStore>(
      (ref) => staleStore,
    );
    final container = ProviderContainer(
      overrides: [
        spellingCatalogueProvider.overrideWithValue(staleStore.catalogue),
        spellingLearningStoreProvider.overrideWith(
          (ref) => ref.watch(activeStoreProvider),
        ),
        learningAuthScopeProvider.overrideWith((ref) => auth),
        courseAudioProvider.overrideWithValue(audio),
        courseReferenceAudioProvider.overrideWithValue(audio),
      ],
    );
    await _pumpStandaloneSpelling(tester, container);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    auth.observe(owner: currentStore.scope.owner, ready: true);
    container.read(activeStoreProvider.notifier).state = currentStore;
    await tester.pump();
    staleLoad.complete(staleOwnerState);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Start practice'), findsOneWidget);
    expect(find.text('First attempt in this run: 9/10'), findsNothing);
    expect(find.text('Start review-only'), findsNothing);
    expect(staleStore.submissions, isEmpty);
    expect(currentStore.submissions, isEmpty);
    expect(audio.requests, isEmpty);
  });

  testWidgets('owner_change_retires_a_pending_recording_completion', (
    tester,
  ) async {
    final store = _HeldSpellingStore();
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(tester, store, audio);
    addTearDown(() => app.dispose(tester));
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listen to the word'));
    await tester.pump();
    app.auth.observe(owner: LearningOwner.account('new-owner'), ready: true);
    await tester.pump();
    audio.requests.single.complete();
    await tester.pump();
    await tester.pump();

    expect(audio.stopCalls, greaterThan(0));
    expect(_option(tester, 'u').onPressed, isNull);
    expect(_option(tester, 'ou').onPressed, isNull);
    expect(
      store.submissions.where(
        (command) => command.action is AnswerSpellingChoice,
      ),
      isEmpty,
    );
  });

  testWidgets('backgrounding_retires_the_current_playback_grant', (
    tester,
  ) async {
    final store = _HeldSpellingStore();
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(tester, store, audio);
    addTearDown(() => app.dispose(tester));
    await _startAndHearFirst(tester, store, audio);
    expect(_option(tester, 'u').onPressed, isNotNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(audio.stopCalls, greaterThan(0));
    expect(_option(tester, 'u').onPressed, isNull);
    expect(_option(tester, 'ou').onPressed, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_option(tester, 'u').onPressed, isNull);
    expect(
      store.submissions.where(
        (command) => command.action is AnswerSpellingChoice,
      ),
      isEmpty,
    );
  });

  testWidgets('pending_answer_remains_blocked_after_background_recovery', (
    tester,
  ) async {
    final store = _HeldSpellingStore();
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(tester, store, audio);
    addTearDown(() => app.dispose(tester));
    await _startAndHearFirst(tester, store, audio);
    store.holdNext = true;
    await tester.tap(find.text('ou'));
    await tester.pump();
    expect(store.pendingSubmissions, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Retry saving'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Listen to the word'),
          )
          .onPressed,
      isNull,
      reason: 'an unresolved frozen command blocks a second answer cycle',
    );
    store.completeNext();
    await tester.pumpAndSettle();
  });

  testWidgets('incomplete_review_route_is_read_only_with_continue_link', (
    tester,
  ) async {
    final store = _HeldSpellingStore();
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(
      tester,
      store,
      audio,
      location: '/course-spelling/$_activityId?review=true',
    );
    addTearDown(() => app.dispose(tester));

    expect(
      find.text('Saved spelling practice is unavailable in this review view.'),
      findsOneWidget,
    );
    expect(find.text('Continue practice'), findsOneWidget);
    expect(store.submissions, isEmpty);
    expect(audio.requests, isEmpty);
    await tester.tap(find.text('Continue practice'));
    await tester.pumpAndSettle();
    expect(find.text('Start practice'), findsOneWidget);
    expect(store.submissions, isEmpty, reason: 'query removal is not a start');
  });

  testWidgets('review_debrief_without_misses_remains_read_only', (
    tester,
  ) async {
    final seed = _HeldSpellingStore();
    final complete = await _practiceDebrief(seed, firstItemWrong: false);
    final store = _HeldSpellingStore(initialState: complete);
    final audio = _ControlledSpellingAudio();
    final app = await _mountSpelling(
      tester,
      store,
      audio,
      location: '/course-spelling/$_activityId?review=true',
    );
    addTearDown(() => app.dispose(tester));

    expect(
      find.text('This saved debrief has no mistakes to review.'),
      findsOneWidget,
    );
    expect(find.text('Start review-only'), findsNothing);
    expect(find.text('Finish practice'), findsNothing);
    expect(store.submissions, isEmpty);
    expect(audio.requests, isEmpty);
  });
}

final class _MountedSpellingApp {
  const _MountedSpellingApp(this.container, this.router, this.auth);
  final ProviderContainer container;
  final GoRouter router;
  final LearningAuthTracker auth;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
  }
}

Future<_MountedSpellingApp> _mountSpelling(
  WidgetTester tester,
  _HeldSpellingStore store,
  _ControlledSpellingAudio audio, {
  String location = '/course-spelling/$_activityId',
}) async {
  disableMapMotion(tester);
  final owner = store.scope.owner;
  final auth = LearningAuthTracker(owner: owner, ready: true);
  final courseStore = CourseLearningWidgetStore();
  final container = ProviderContainer(
    overrides: [
      courseLearningStoreProvider.overrideWithValue(courseStore),
      courseLearningStateProvider.overrideWith(
        (ref) async => courseStore.committedState,
      ),
      comparisonLearningStateProvider.overrideWith(
        (ref) async => ComparisonLearningState.empty(
          ComparisonProfileScope(courseId: 'en-fr', owner: owner),
        ),
      ),
      sentenceHuntCatalogueProvider.overrideWith(
        (ref) async => syntheticSentenceCatalogue(),
      ),
      sentenceHuntLearningStateProvider.overrideWith(
        (ref) async => SentenceHuntState.empty(
          SentenceHuntProfileScope(courseId: 'en-fr', owner: owner),
        ),
      ),
      spellingCatalogueProvider.overrideWithValue(store.catalogue),
      spellingLearningStoreProvider.overrideWithValue(store),
      spellingLearningStateProvider.overrideWith((ref) => store.load()),
      learningAuthScopeProvider.overrideWith((ref) => auth),
      courseAudioProvider.overrideWithValue(audio),
      courseReferenceAudioProvider.overrideWithValue(audio),
    ],
  );
  await _waitForOnboardingReady(tester, container);
  expect(container.read(onboardingControllerProvider).isReady, isTrue);
  expect(container.read(onboardingControllerProvider).courseId, 'en-fr');
  expect(auth.current.ready, isTrue);
  final router = container.read(appRouterProvider);
  router.go(location);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const LinguistApp()),
  );
  await tester.pumpAndSettle();
  return _MountedSpellingApp(container, router, auth);
}

Future<void> _pumpStandaloneSpelling(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SpellingLessonScreen(review: false)),
    ),
  );
  await tester.pump();
}

Future<void> _waitForOnboardingReady(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final ready = Completer<void>();
  final subscription = container.listen(onboardingControllerProvider, (
    _,
    state,
  ) {
    if (state.isReady && !ready.isCompleted) ready.complete();
  }, fireImmediately: true);
  try {
    await tester.runAsync(
      () => ready.future.timeout(const Duration(seconds: 5)),
    );
  } finally {
    subscription.close();
  }
}

OutlinedButton _option(WidgetTester tester, String option) =>
    tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, option));

String _spellingSemantics(WidgetTester tester) {
  final scaffold = find
      .ancestor(of: find.text(_prompt), matching: find.byType(Scaffold))
      .last;
  return tester.getSemantics(scaffold).toStringDeep();
}

Future<void> _startAndHearFirst(
  WidgetTester tester,
  _HeldSpellingStore store,
  _ControlledSpellingAudio audio,
) async {
  await tester.tap(find.text('Start practice'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Listen to the word'));
  await tester.pump();
  expect(audio.requests, isNotEmpty);
  audio.requests.last.complete();
  await tester.pump();
  await tester.pump();
}

SpellingPlaybackObservation _observation(
  _HeldSpellingStore store,
  UyDemoSpellingRow row, {
  required int promptEpoch,
  int round = 1,
}) {
  final slot = store.committedState.slots[_activityId];
  return SpellingPlaybackObservation(
    profile: store.scope,
    authGeneration: 0,
    activityId: _activityId,
    contentRevision: store.catalogue.contentRevision,
    runGeneration: slot?.cursor.generation ?? 1,
    round: round,
    itemId: row.exercise.id,
    referenceId: row.exercise.audioRefId,
    promptEpoch: promptEpoch,
    outcome: CourseAudioOutcome.completed,
    source: CourseAudioSource.unverifiedRecording,
  );
}

Future<SpellingLearningState> _practiceDebrief(
  _HeldSpellingStore store, {
  required bool firstItemWrong,
}) async {
  await store.perform(
    StartSpellingPractice(
      sessionId: 'review-source-run',
      policy: LessonPolicy(),
    ),
  );
  for (var index = 0; index < store.catalogue.rows.length; index++) {
    final row = store.catalogue.rows[index];
    final correct = !(firstItemWrong && index == 0);
    final selected = correct
        ? row.exercise.correctOptionId
        : row.exercise.options
              .firstWhere((option) => option.id != row.exercise.correctOptionId)
              .id;
    await store.perform(
      AnswerSpellingChoice(
        itemId: row.exercise.id,
        contentRevision: store.catalogue.contentRevision,
        selectedOptionId: selected,
        expectedOptionIdSnapshot: row.exercise.correctOptionId,
        playback: _observation(store, row, promptEpoch: index + 1),
      ),
    );
    await store.perform(const AdvanceSpellingItem());
  }
  return store.committedState;
}

final class _HeldSubmission {
  _HeldSubmission(this.command, this.completer);
  final SpellingLearningCommand command;
  final Completer<SpellingCommit> completer;
}

final class _HeldSpellingStore implements SpellingLearningStore {
  _HeldSpellingStore({
    SpellingLearningState? initialState,
    LearningOwner? owner,
  }) : catalogue = loadFrenchUyDemoSpellingCatalogue(),
       scope = SpellingProfileScope(
         courseId: 'en-fr',
         owner: owner ?? LearningOwner.guest(),
       ),
       _state =
           initialState ??
           SpellingLearningState.empty(
             SpellingProfileScope(
               courseId: 'en-fr',
               owner: owner ?? LearningOwner.guest(),
             ),
           ) {
    _engine = SpellingLearningTransitionEngine(catalogue: catalogue);
    if (_state.scope != scope) throw ArgumentError('seed scope mismatch');
    _tokenCounter = _state.commitOrdinal;
  }

  final FrenchUyDemoSpellingCatalogue catalogue;
  @override
  final SpellingProfileScope scope;
  late final SpellingLearningTransitionEngine _engine;
  SpellingLearningState _state;
  int _tokenCounter = 0;
  int prepareCalls = 0;
  bool holdNext = false;
  bool loseNextAckAfterCommit = false;
  bool duplicateNextAck = false;
  Completer<SpellingLearningState>? heldLoad;
  int loadCalls = 0;
  int retryLoadCalls = 0;
  final List<SpellingLearningCommand> submissions = [];
  final List<_HeldSubmission> pendingSubmissions = [];

  SpellingLearningState get committedState => _state;

  @override
  Future<SpellingLearningState> load() async {
    loadCalls++;
    if (heldLoad != null) return heldLoad!.future;
    return _state;
  }

  @override
  Future<SpellingLearningState> retryLoad() async {
    retryLoadCalls++;
    return _state;
  }

  @override
  SpellingLearningCommand prepare({
    required SpellingLearningState state,
    required SpellingAction action,
  }) {
    prepareCalls++;
    return _engine.prepare(
      state: state,
      action: action,
      authGeneration: 0,
      token: 'spelling${(++_tokenCounter).toString().padLeft(14, '0')}',
      submittedAt: DateTime.utc(
        2026,
        10,
        24,
      ).add(Duration(microseconds: _tokenCounter)),
    );
  }

  @override
  Future<SpellingCommit> submit(SpellingLearningCommand command) async {
    submissions.add(command);
    if (holdNext) {
      holdNext = false;
      final completer = Completer<SpellingCommit>();
      pendingSubmissions.add(_HeldSubmission(command, completer));
      return completer.future;
    }
    final commit = _apply(command);
    if (duplicateNextAck) {
      duplicateNextAck = false;
      final SpellingLearningTransition duplicate = _engine.evaluate(
        state: _state,
        command: command,
        committedAt: command.submittedAt.add(const Duration(seconds: 2)),
      );
      return SpellingCommit(
        state: duplicate.nextState,
        slot: duplicate.slot,
        duplicate: duplicate.duplicate,
      );
    }
    if (loseNextAckAfterCommit) {
      loseNextAckAfterCommit = false;
      throw StateError('simulated lost acknowledgement');
    }
    return commit;
  }

  Future<SpellingCommit> perform(SpellingAction action) =>
      submit(prepare(state: _state, action: action));

  void completeNext() {
    final held = pendingSubmissions.removeAt(0);
    held.completer.complete(_apply(held.command));
  }

  void failNext() {
    final held = pendingSubmissions.removeAt(0);
    held.completer.completeError(StateError('injected save failure'));
  }

  SpellingCommit _apply(SpellingLearningCommand command) {
    final transition = _engine.evaluate(
      state: _state,
      command: command,
      committedAt: command.submittedAt.add(const Duration(seconds: 1)),
    );
    _state = transition.nextState;
    return SpellingCommit(
      state: transition.nextState,
      slot: transition.slot,
      duplicate: transition.duplicate,
    );
  }
}

final class _ControlledSpellingAudio implements CourseReferenceAudio {
  final List<_SpellingAudioRequest> requests = [];
  int stopCalls = 0;

  @override
  Future<CourseAudioResult> playReference(
    String referenceId, {
    CourseAudioUse use = CourseAudioUse.alphaPractice,
    CourseAudioVariant variant = CourseAudioVariant.normal,
    bool allowPracticeTts = false,
  }) {
    final request = _SpellingAudioRequest(referenceId, use, allowPracticeTts);
    requests.add(request);
    return request.future;
  }

  @override
  Future<void> speak(String word) async =>
      throw StateError('spelling must not use device speech');

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {}
}

final class _SpellingAudioRequest {
  _SpellingAudioRequest(this.referenceId, this.use, this.allowPracticeTts);
  final String referenceId;
  final CourseAudioUse use;
  final bool allowPracticeTts;
  final Completer<CourseAudioResult> _completer =
      Completer<CourseAudioResult>();
  Future<CourseAudioResult> get future => _completer.future;

  void complete() => _completer.complete(
    CourseAudioResult.completed(
      referenceId: referenceId,
      source: CourseAudioSource.unverifiedRecording,
    ),
  );

  void fail() => _completer.complete(
    CourseAudioResult.failed(
      referenceId: referenceId,
      failure: const CourseAudioFailure(
        reason: CourseAudioFailureReason.unsupportedPlayback,
      ),
    ),
  );

  void cancel() => _completer.complete(
    CourseAudioResult.cancelled(referenceId: referenceId),
  );
}
