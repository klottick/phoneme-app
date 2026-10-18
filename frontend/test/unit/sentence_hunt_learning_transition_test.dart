import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
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
  _Driver()
      : catalogue = syntheticSentenceCatalogue(),
        scope = SentenceHuntProfileScope(
            courseId: 'en-fr', owner: LearningOwner.guest()) {
    engine = SentenceHuntTransitionEngine(catalogue: catalogue);
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
