import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt_controller.dart';
import 'package:linguist/src/features/course/exercises/listening_exercise_contract.dart';
import '../support/sentence_hunt_harness.dart';

void main() {
  test('pending section does not load, start, or play', () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig(reviewed: false);
    final SentenceHuntController controller = rig.controller();

    await controller.load();

    expect(controller.state.error, isNotNull);
    expect(rig.persistence.reads, 0);
    expect(rig.persistence.writes, 0);
    expect(rig.audio.requests, isEmpty);
    expect(rig.audio.speakCalls, 0);
    controller.dispose();
  });

  test(
      'unregistered explicit policy cannot silently start with the section default',
      () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final SentenceHuntController controller = rig.controller(
      policy: LessonPolicy(completionThresholdPercent: 70),
    );

    await controller.load();

    expect(controller.state.loadFailed, isTrue);
    expect(controller.state.session, isNull);
    expect(
      rig.store.submitted
          .where((command) => command.action is StartSentenceHuntRun),
      isEmpty,
      reason: 'an unregistered route policy is rejected instead of ignored',
    );
    expect((await rig.store.load()).slots, isEmpty);
    controller.dispose();
  });

  test('sentence_owner_fences_exact_reviewed_audio_before_answer_permission',
      () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final SentenceHuntController controller = rig.controller();
    await controller.load();

    final Future<void> playback = controller.play();
    final ControlledSentenceHuntPlayback request = rig.audio.requests.single;
    expect(request.referenceId, 'fr08-vowel-01-audio');
    expect(request.use, CourseAudioUse.reviewedOnly);
    expect(request.variant, CourseAudioVariant.normal);
    expect(request.allowPracticeTts, isFalse);
    request.complete(source: CourseAudioSource.unverifiedRecording);
    await playback;

    expect(controller.state.canSubmit, isFalse);
    expect(controller.state.audioError, isNotNull);
    expect(rig.audio.speakCalls, 0);
    controller.dispose();
  });

  test('empty whole-answer submission freezes once and retries only its save',
      () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final SentenceHuntController controller = rig.controller();
    await controller.load();
    final Future<void> playback = controller.play();
    rig.audio.requests.single.complete();
    await playback;
    expect(controller.state.canSubmit, isTrue);

    final Map<String, String> durableBeforeAnswer =
        Map<String, String>.of(rig.persistence.durable);
    rig.persistence.holdNextWrite(failure: StateError('quota rejected'));
    final Future<void> firstSubmit = controller.submit();
    final Future<void> duplicateSubmit = controller.submit();
    expect(controller.state.feedback, ListeningFeedback.notYet);
    expect(controller.state.canAdvance, isFalse);
    expect(controller.state.canSubmit, isFalse,
        reason: 'claiming the answer retires its playback grant');
    expect(controller.state.session?.attemptCount, 0,
        reason: 'immediate feedback is not a committed attempt');
    expect(
      rig.store.submitted
          .where((command) => command.action is AnswerSentenceHuntItem),
      hasLength(1),
      reason:
          'the synchronously claimed answer reaches the real repository once',
    );
    for (var turn = 0; turn < 12; turn++) {
      await Future<void>.value();
    }
    expect(rig.persistence.writes, 2,
        reason: 'save must reach persistence; reads=${rig.persistence.reads}, '
            'savePending=${controller.state.savePending}, '
            'error=${controller.state.error}');
    await rig.persistence.writeEntered;
    final List<SentenceHuntCommand> answerCommands = rig.store.prepared
        .where((command) => command.action is AnswerSentenceHuntItem)
        .toList();
    expect(answerCommands, hasLength(1));
    final SentenceHuntCommand frozen = answerCommands.single;
    final SentenceHuntAnswer answer =
        (frozen.action as AnswerSentenceHuntItem).answer;
    expect(answer.selectedTokenIds, isEmpty);
    expect(answer.playback.scope, rig.store.scope);
    expect(answer.playback.content.itemId, 'fr08-vowel-01');
    expect(answer.playback.referenceId, 'fr08-vowel-01-audio');
    expect(answer.playback.outcome, CourseAudioOutcome.completed);
    expect(answer.playback.source, CourseAudioSource.reviewedRecording);
    expect(controller.state.session?.attemptCount, 0);
    expect(rig.persistence.durable, durableBeforeAnswer,
        reason: 'the held answer write is not durable before acknowledgement');
    rig.persistence.releaseWrite();
    await firstSubmit;
    await duplicateSubmit;

    expect(controller.state.canAdvance, isFalse);
    expect(controller.state.error, isNotNull);
    expect(controller.state.session?.attemptCount, 0);
    expect(rig.persistence.durable, durableBeforeAnswer,
        reason: 'a failed answer save cannot publish durable attempt count');
    expect(rig.audio.requests, hasLength(1));
    await controller.retrySave();
    final List<SentenceHuntCommand> submittedAnswers = rig.store.submitted
        .where((command) => command.action is AnswerSentenceHuntItem)
        .toList();
    expect(submittedAnswers, hasLength(2));
    expect(identical(submittedAnswers[0], submittedAnswers[1]), isTrue);
    expect(controller.state.session?.attemptCount, 1);
    expect(controller.state.canAdvance, isTrue);
    expect(rig.audio.requests, hasLength(1));

    await controller.advance();
    expect(controller.state.prompt?.itemId, 'fr08-vowel-02');
    expect(controller.state.selectedTokenIds, isEmpty);
    controller.dispose();
  });

  test('unanswered restore clears unsaved choices and requires fresh hearing',
      () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final SentenceHuntController first = rig.controller();
    await first.load();
    final Future<void> playback = first.play();
    rig.audio.requests.single.complete();
    await playback;
    first.toggleToken('fr08-vowel-01-token-01');
    expect(first.state.selectedTokenIds, contains('fr08-vowel-01-token-01'));
    first.dispose();

    final SentenceHuntController restored = rig.controller();
    await restored.load();

    expect(restored.state.prompt?.itemId, 'fr08-vowel-01');
    expect(restored.state.selectedTokenIds, isEmpty,
        reason: 'a local, unsubmitted choice is not reconstructed');
    expect(restored.state.canSubmit, isFalse,
        reason: 'restored progress does not restore a playback grant');
    expect(rig.audio.requests, hasLength(1),
        reason: 'restore never autoplays the reviewed recording');
    await restored.submit();
    expect(
      rig.store.submitted
          .where((command) => command.action is AnswerSentenceHuntItem),
      isEmpty,
    );

    final Future<void> freshPlayback = restored.play();
    rig.audio.requests.last.complete();
    await freshPlayback;
    expect(restored.state.canSubmit, isTrue);
    expect(rig.audio.requests, hasLength(2));
    restored.dispose();
  });

  test('save retry preserves the normalized answer and its exact observation',
      () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final SentenceHuntController controller = rig.controller();
    await controller.load();
    final Future<void> playback = controller.play();
    rig.audio.requests.single.complete();
    await playback;
    final SentenceHuntItem item =
        rig.catalogue.item(rig.sectionId, 'fr08-vowel-01');
    for (final String id in item.expectedTokenIds.reversed) {
      controller.toggleToken(id);
    }

    rig.persistence.holdNextWrite(failure: StateError('quota rejected'));
    final Future<void> submit = controller.submit();
    for (var turn = 0; turn < 12; turn++) {
      await Future<void>.value();
    }
    await rig.persistence.writeEntered;
    final SentenceHuntCommand frozen = rig.store.prepared.singleWhere(
      (SentenceHuntCommand command) => command.action is AnswerSentenceHuntItem,
    );
    final SentenceHuntAnswer frozenAnswer =
        (frozen.action as AnswerSentenceHuntItem).answer;
    expect(frozenAnswer.selectedTokenIds, item.expectedTokenIds,
        reason: 'the answer is normalized to authored token order');
    expect(frozenAnswer.playback.referenceId, item.identity.audioRefId);
    expect(frozenAnswer.playback.content, item.identity);
    expect(frozenAnswer.playback.outcome, CourseAudioOutcome.completed);
    expect(frozenAnswer.playback.source, CourseAudioSource.reviewedRecording);
    rig.persistence.releaseWrite();
    await submit;
    expect(controller.state.error, isNotNull);
    await controller.retrySave();

    final List<SentenceHuntCommand> answers = rig.store.submitted
        .where((SentenceHuntCommand command) =>
            command.action is AnswerSentenceHuntItem)
        .toList();
    expect(answers, hasLength(2));
    expect(identical(answers[0], answers[1]), isTrue);
    expect(rig.audio.requests, hasLength(1),
        reason: 'save retry does not require or request another recording');
    expect(controller.state.feedback, ListeningFeedback.correct);
    controller.dispose();
  });

  test('post-suspension exact Start retry publishes the initial prompt once',
      () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final SentenceHuntController controller = rig.controller();
    rig.persistence.holdNextWrite();
    final Future<void> loading = controller.load();
    await rig.persistence.writeEntered;

    expect(controller.state.prompt, isNull);
    expect(controller.state.savePending, isTrue);
    final SentenceHuntCommand startCommand = rig.store.submitted.single;
    expect(startCommand.action, isA<StartSentenceHuntRun>());
    final String sessionId =
        (startCommand.action as StartSentenceHuntRun).sessionId;
    controller.suspend();
    rig.persistence.releaseWrite();
    await loading;

    expect(controller.state.prompt, isNull,
        reason: 'an acknowledgement owned by the suspended epoch is not UI');
    expect(controller.state.savePending, isTrue);
    controller.resume();
    await controller.retrySave();

    final List<SentenceHuntCommand> starts = rig.store.submitted
        .where((SentenceHuntCommand command) =>
            command.action is StartSentenceHuntRun)
        .toList();
    expect(starts, hasLength(2));
    expect(identical(starts[0], starts[1]), isTrue,
        reason: 'recovery retries the frozen Start token, not a new run');
    expect(controller.state.prompt?.itemId, 'fr08-vowel-01');
    expect(controller.state.session?.sessionId, sessionId);
    expect(controller.state.savePending, isFalse);
    expect(rig.audio.requests, isEmpty);
    controller.dispose();
  });

  test('disposed owner cannot publish a held Start acknowledgement', () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    var ownerNotifications = 0;
    final SentenceHuntController retired = rig.controller(
      onStateChanged: () => ownerNotifications++,
    );
    rig.persistence.holdNextWrite();
    final Future<void> loading = retired.load();
    await rig.persistence.writeEntered;
    retired.dispose();
    final int notificationsAtRetirement = ownerNotifications;
    rig.persistence.releaseWrite();
    await loading;

    expect(ownerNotifications, notificationsAtRetirement,
        reason: 'a retired owner cannot publish an old asynchronous ACK');
    final SentenceHuntController current = rig.controller();
    await current.load();
    expect(current.state.prompt?.itemId, 'fr08-vowel-01');
    expect(
      rig.store.submitted.where((SentenceHuntCommand command) =>
          command.action is StartSentenceHuntRun),
      hasLength(1),
      reason:
          'the successor restores the saved run rather than starting A again',
    );
    current.dispose();
  });

  test('post-suspension failed answer retries its frozen observation exactly',
      () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final SentenceHuntController controller = rig.controller();
    await controller.load();
    final SentenceHuntItem item =
        rig.catalogue.item(rig.sectionId, 'fr08-vowel-01');
    final Future<void> playback = controller.play();
    rig.audio.requests.single.complete();
    await playback;
    for (final String id in item.expectedTokenIds.reversed) {
      controller.toggleToken(id);
    }

    rig.persistence.holdNextWrite(failure: StateError('quota rejected'));
    final Future<void> submit = controller.submit();
    await rig.persistence.writeEntered;
    final SentenceHuntCommand frozen = rig.store.submitted.last;
    final SentenceHuntAnswer frozenAnswer =
        (frozen.action as AnswerSentenceHuntItem).answer;
    controller.suspend();
    rig.persistence.releaseWrite();
    await submit;

    expect(controller.state.session?.attemptCount, 0,
        reason: 'the failed suspended attempt is not published');
    expect(controller.state.savePending, isTrue);
    expect(rig.audio.requests, hasLength(1));
    controller.resume();
    await controller.retrySave();

    final List<SentenceHuntCommand> answers = rig.store.submitted
        .where((SentenceHuntCommand command) =>
            command.action is AnswerSentenceHuntItem)
        .toList();
    expect(answers, hasLength(2));
    expect(identical(answers[0], answers[1]), isTrue);
    final SentenceHuntAnswer retriedAnswer =
        (answers[1].action as AnswerSentenceHuntItem).answer;
    expect(retriedAnswer.selectedTokenIds, frozenAnswer.selectedTokenIds);
    expect(retriedAnswer.playback, frozenAnswer.playback);
    expect(controller.state.session?.attemptCount, 1);
    expect(controller.state.feedback, ListeningFeedback.correct);
    expect(controller.state.canAdvance, isTrue);
    expect(rig.audio.requests, hasLength(1),
        reason: 'saving a frozen answer never needs another hearing');
    controller.dispose();
  });

  test('suspended advance review and finish publish only their exact retries',
      () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final SentenceHuntController controller = rig.controller();
    await controller.load();

    for (var index = 0; index < 5; index++) {
      final SentenceHuntItem item = rig.catalogue.item(
        rig.sectionId,
        'fr08-vowel-0${index + 1}',
      );
      final Future<void> playback = controller.play();
      rig.audio.requests.last.complete();
      await playback;
      final List<String> selection = index == 0
          ? <String>[item.selectableTokenIds[1]]
          : item.expectedTokenIds;
      for (final String id in selection) {
        controller.toggleToken(id);
      }
      await controller.submit();

      if (index < 4) {
        await controller.advance();
        continue;
      }

      rig.persistence.holdNextWrite();
      final Future<void> advance = controller.advance();
      await rig.persistence.writeEntered;
      final SentenceHuntCommand advanceCommand = rig.store.submitted.last;
      expect(advanceCommand.action, isA<AdvanceSentenceHuntItem>());
      controller.suspend();
      rig.persistence.releaseWrite();
      await advance;
      expect(controller.state.phase, SentenceHuntPhase.exercise,
          reason: 'debrief waits for an acknowledged current-owner retry');
      expect(controller.state.savePending, isTrue);
      controller.resume();
      await controller.retrySave();
      expect(controller.state.phase, SentenceHuntPhase.debrief);
      final List<SentenceHuntCommand> advances = rig.store.submitted
          .where((SentenceHuntCommand command) =>
              command.action is AdvanceSentenceHuntItem)
          .toList();
      expect(identical(advances.last, advanceCommand), isTrue);
      expect(controller.state.debriefAttempts, hasLength(5));
    }

    final int attemptsBeforeReview = controller.state.session!.attemptCount;
    rig.persistence.holdNextWrite(failure: StateError('quota rejected'));
    final Future<void> review = controller.reviewMistakes();
    await rig.persistence.writeEntered;
    final SentenceHuntCommand reviewCommand = rig.store.submitted.last;
    expect(reviewCommand.action, isA<ReviewSentenceHuntMistakes>());
    controller.suspend();
    rig.persistence.releaseWrite();
    await review;
    expect(controller.state.phase, SentenceHuntPhase.debrief,
        reason: 'a failed suspended Review cannot publish the mistake round');
    expect(controller.state.savePending, isTrue);
    controller.resume();
    await controller.retrySave();
    expect(controller.state.prompt?.itemId, 'fr08-vowel-01');
    expect(controller.state.session?.round, 2);
    expect(controller.state.session?.attemptCount, attemptsBeforeReview);
    final List<SentenceHuntCommand> reviews = rig.store.submitted
        .where((SentenceHuntCommand command) =>
            command.action is ReviewSentenceHuntMistakes)
        .toList();
    expect(reviews, hasLength(2));
    expect(identical(reviews[0], reviews[1]), isTrue);

    final SentenceHuntItem reviewItem =
        rig.catalogue.item(rig.sectionId, 'fr08-vowel-01');
    final Future<void> reviewPlayback = controller.play();
    rig.audio.requests.last.complete();
    await reviewPlayback;
    for (final String id in reviewItem.expectedTokenIds) {
      controller.toggleToken(id);
    }
    await controller.submit();
    await controller.advance();
    expect(controller.state.canFinish, isTrue);

    rig.persistence.holdNextWrite();
    final Future<void> finish = controller.finish();
    await rig.persistence.writeEntered;
    final SentenceHuntCommand finishCommand = rig.store.submitted.last;
    expect(finishCommand.action, isA<FinishSentenceHuntRun>());
    controller.suspend();
    rig.persistence.releaseWrite();
    await finish;
    expect(controller.state.finished, isFalse,
        reason: 'Finish is not shown before current-owner acknowledgement');
    expect(controller.state.savePending, isTrue);
    controller.resume();
    await controller.retrySave();
    expect(controller.state.finished, isTrue);
    final List<SentenceHuntCommand> finishes = rig.store.submitted
        .where((SentenceHuntCommand command) =>
            command.action is FinishSentenceHuntRun)
        .toList();
    expect(finishes, hasLength(2));
    expect(identical(finishes[0], finishes[1]), isTrue);
    final SentenceHuntState durable = await rig.store.load();
    expect(durable.completions, hasLength(1),
        reason: 'a Finish retry creates one completion receipt');
    expect(rig.audio.requests, hasLength(6),
        reason: 'only the five initial and one review recording are heard');
    controller.dispose();
  });

  test('answered restore shows saved feedback without guessed choices or audio',
      () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final SentenceHuntController first = rig.controller();
    await first.load();
    final Future<void> playback = first.play();
    rig.audio.requests.single.complete();
    await playback;
    final SentenceHuntItem item =
        rig.catalogue.item(rig.sectionId, 'fr08-vowel-01');
    for (final String id in item.expectedTokenIds) {
      first.toggleToken(id);
    }
    await first.submit();
    expect(first.state.feedback, ListeningFeedback.correct);
    first.dispose();

    final SentenceHuntController restored = rig.controller();
    await restored.load();

    expect(restored.state.feedback, ListeningFeedback.correct);
    expect(restored.state.selectedTokenIds, isEmpty,
        reason: 'the correct answer is not replayed as a selection');
    expect(restored.state.canAdvance, isTrue);
    expect(restored.state.canSubmit, isFalse);
    expect(rig.audio.requests, hasLength(1),
        reason: 'answer restoration does not autoplay');
    await restored.play();
    expect(rig.audio.requests, hasLength(1),
        reason: 'an answered saved item cannot request a replay');
    restored.dispose();
  });

  test('cancelled and failed recordings never grant an answer or use speech',
      () async {
    for (final bool cancel in <bool>[true, false]) {
      final SentenceHuntTestRig rig = SentenceHuntTestRig();
      final SentenceHuntController controller = rig.controller();
      await controller.load();
      final Future<void> playback = controller.play();
      final ControlledSentenceHuntPlayback request = rig.audio.requests.single;
      if (cancel) {
        request.cancel();
      } else {
        request.fail();
      }
      await playback;

      expect(controller.state.canSubmit, isFalse);
      await controller.submit();
      expect(
        rig.store.submitted
            .where((command) => command.action is AnswerSentenceHuntItem),
        isEmpty,
      );
      expect(rig.audio.speakCalls, 0);
      controller.dispose();
    }
  });

  test('retired playback completion cannot stop or grant its successor',
      () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final SentenceHuntController retired = rig.controller();
    await retired.load();
    final Future<void> stalePlayback = retired.play();
    final ControlledSentenceHuntPlayback staleRequest = rig.audio.requests[0];
    retired.retireOwner();
    expect(rig.audio.stopCalls, 1);

    final SentenceHuntController current = rig.controller();
    await current.load();
    final Future<void> currentPlayback = current.play();
    final ControlledSentenceHuntPlayback currentRequest = rig.audio.requests[1];
    staleRequest.complete();
    await stalePlayback;
    expect(current.state.playing, isTrue);
    expect(current.state.canSubmit, isFalse);
    expect(rig.audio.stopCalls, 1,
        reason: 'stale completion cannot stop the newer shared player');

    currentRequest.complete();
    await currentPlayback;
    expect(current.state.canSubmit, isTrue);
    expect(rig.audio.stopCalls, 1);
    current.dispose();
  });

  test(
      'practice remediation can reach four of five and finish on acknowledgement',
      () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final SentenceHuntController controller = rig.controller();
    await controller.load();
    for (var index = 0; index < 5; index++) {
      await _answerAndAdvance(controller, rig, correct: index >= 2);
    }
    expect(controller.state.session?.correctCount, 3);
    expect(controller.state.completionEligible, isFalse);
    expect(controller.state.canReview, isTrue);
    expect(controller.state.canFinish, isFalse);
    expect(controller.state.debriefAttempts, hasLength(5));
    final SentenceHuntAttempt firstPassAttempt =
        controller.state.debriefAttempts!.firstWhere(
      (SentenceHuntAttempt attempt) =>
          attempt.content.itemId == 'fr08-vowel-01',
    );
    expect(firstPassAttempt.round, 1);
    expect(
        firstPassAttempt.selectedTokenIds, <String>['fr08-vowel-01-token-02']);
    final int beforeFinish = rig.store.submitted.length;
    await controller.finish();
    expect(rig.store.submitted, hasLength(beforeFinish),
        reason: 'three of five cannot claim completion');

    await controller.reviewMistakes();
    expect(controller.state.prompt?.itemId, 'fr08-vowel-01');
    await _answerAndAdvance(controller, rig, correct: true);
    await _answerAndAdvance(controller, rig, correct: false);

    expect(controller.state.phase, SentenceHuntPhase.debrief);
    expect(controller.state.session?.correctCount, 4);
    expect(controller.state.completionEligible, isTrue);
    expect(controller.state.canFinish, isTrue);
    final SentenceHuntAttempt reviewedAttempt =
        controller.state.debriefAttempts!.firstWhere(
      (SentenceHuntAttempt attempt) =>
          attempt.content.itemId == 'fr08-vowel-01',
    );
    expect(reviewedAttempt.round, 2);
    expect(reviewedAttempt.selectedTokenIds,
        <String>['fr08-vowel-01-token-01', 'fr08-vowel-01-token-04']);
    await controller.finish();
    expect(controller.state.finished, isTrue);
    expect(controller.state.canFinish, isFalse);
    final int submittedAfterFinish = rig.store.submitted.length;
    await controller.finish();
    expect(rig.store.submitted, hasLength(submittedAfterFinish),
        reason: 'a saved finished run cannot submit another Finish command');
    controller.dispose();
  });

  test('unfinished practice cannot be replaced by a review-only entry mode',
      () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final SentenceHuntController practice = rig.controller();
    await practice.load();
    final String originalSession = practice.state.session!.sessionId;
    final int originalGeneration =
        (await rig.store.load()).slots[rig.sectionId]!.cursor.generation;
    practice.dispose();

    final SentenceHuntController reviewOnly = rig.controller(
      entryMode: SentenceHuntEntryMode.reviewOnly,
    );
    await reviewOnly.load();

    final SentenceHuntSlot saved =
        (await rig.store.load()).slots[rig.sectionId]!;
    expect(reviewOnly.state.modeMismatch, isTrue);
    expect(reviewOnly.state.reviewOnly, isFalse,
        reason: 'the unfinished saved slot remains a practice run');
    expect(reviewOnly.state.session?.sessionId, originalSession);
    expect(saved.cursor.generation, originalGeneration);
    expect(saved.checkpoint.mode, SentenceHuntRunMode.practice);
    expect(
      rig.store.submitted
          .where((command) => command.action is StartSentenceHuntRun),
      hasLength(1),
    );
    reviewOnly.dispose();
  });

  test('review-only mistake round can finish but never adds completion',
      () async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final SentenceHuntController practice = rig.controller();
    await practice.load();
    for (var index = 0; index < 5; index++) {
      await _answerAndAdvance(practice, rig, correct: index != 0);
    }
    expect(practice.state.session?.correctCount, 4);
    expect(practice.state.canFinish, isTrue);
    await practice.finish();
    expect(practice.state.finished, isTrue);
    practice.dispose();

    final SentenceHuntController reviewOnly = rig.controller(
      entryMode: SentenceHuntEntryMode.reviewOnly,
    );
    await reviewOnly.load();
    expect(reviewOnly.state.reviewOnly, isTrue);
    expect(reviewOnly.state.session?.queue, <String>['fr08-vowel-01']);
    expect(reviewOnly.state.completionEligible, isFalse);
    await _answerAndAdvance(reviewOnly, rig, correct: true);
    expect(reviewOnly.state.phase, SentenceHuntPhase.debrief);
    expect(reviewOnly.state.canFinish, isTrue);
    expect(reviewOnly.state.completionEligible, isFalse);
    await reviewOnly.finish();
    expect(reviewOnly.state.finished, isTrue);
    expect(reviewOnly.state.completionEligible, isFalse);
    final SentenceHuntState saved = await rig.store.load();
    expect(saved.completions, hasLength(1),
        reason: 'review-only finish cannot create a course completion');
    reviewOnly.dispose();
  });
}

Future<void> _answerAndAdvance(
  SentenceHuntController controller,
  SentenceHuntTestRig rig, {
  required bool correct,
}) async {
  final SentenceHuntItem item =
      rig.catalogue.item(rig.sectionId, controller.state.prompt!.itemId);
  final Future<void> playback = controller.play();
  rig.audio.requests.last.complete();
  await playback;
  final List<String> selection =
      correct ? item.expectedTokenIds : <String>[item.selectableTokenIds[1]];
  for (final String id in selection) {
    controller.toggleToken(id);
  }
  await controller.submit();
  await controller.advance();
}
