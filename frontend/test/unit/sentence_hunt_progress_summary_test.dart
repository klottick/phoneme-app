import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_sql_repository.dart';
import 'package:linguist/src/features/course/sentence_hunt_progress_summary.dart';
import '../support/sentence_hunt_fixtures.dart';
import '../support/sqlite_learning_test_harness.dart'
    show openFileLearningTestDatabase;

void main() {
  test(
    'summary_distinguishes_known_empty_from_a_saved_four_of_five_run',
    () async {
      final driver = _SentenceHuntDriver(syntheticSentenceCatalogue());
      await driver.load();
      final empty = SentenceHuntProgressSummary.fromState(
        state: driver.state,
        catalogue: driver.catalogue,
      );
      expect(empty.completedSectionCount, 0);
      expect(empty.completionLabel, 'Sentence sections completed: 0/3');
      expect(empty.practiceLabel, 'Sentence practice, not phoneme mastery');
      expect(empty.sections[0].status, SentenceHuntSectionStatus.notStarted);
      expect(empty.sections[0].latestCorrectCount, 0);
      expect(empty.sections[0].latestAnsweredItemCount, 0);

      await driver.start(fixtureSectionIds[0]);
      await driver.answerAuthoredRun(
        fixtureSectionIds[0],
        wrongItemIds: {fixtureItemIds[0].last},
      );
      final beforeFinish = SentenceHuntProgressSummary.fromState(
        state: driver.state,
        catalogue: driver.catalogue,
      );
      final vowelsBeforeFinish = beforeFinish.sections[0];
      expect(
        beforeFinish.completedSectionCount,
        0,
        reason: 'a saved debrief is not a completion until Finish is ACKed',
      );
      expect(vowelsBeforeFinish.status, SentenceHuntSectionStatus.resumable);
      expect(vowelsBeforeFinish.latestCorrectCount, 4);
      expect(vowelsBeforeFinish.latestAnsweredItemCount, 5);
      expect(vowelsBeforeFinish.mistakes, hasLength(1));
      expect(vowelsBeforeFinish.mistakes.single.itemId, fixtureItemIds[0].last);
      expect(vowelsBeforeFinish.mistakes.single.failureCount, 1);

      await driver.finish(fixtureSectionIds[0]);
      final completed = SentenceHuntProgressSummary.fromState(
        state: driver.state,
        catalogue: driver.catalogue,
      );
      expect(completed.completedSectionCount, 1);
      expect(completed.completionLabel, 'Sentence sections completed: 1/3');
      expect(completed.sections[0].status, SentenceHuntSectionStatus.completed);
      expect(completed.sections[0].items, hasLength(5));
      expect(completed.sections[0].items.first.firstInRunTotal, 1);
      expect(completed.sections[0].items.first.firstInRunCorrect, 1);
      expect(completed.sections[0].items.last.firstInRunCorrect, 0);
      expect(completed.totalAnswers, 5);
      expect(completed.correctAnswers, 4);
    },
  );

  test(
    'only_distinct_current_section_revision_and_policy_completions_count',
    () async {
      final driver = _SentenceHuntDriver(syntheticSentenceCatalogue());
      await driver.load();
      for (final sectionId in fixtureSectionIds) {
        await driver.start(sectionId);
        await driver.answerAuthoredRun(sectionId);
        await driver.finish(sectionId);
      }
      await driver.start(fixtureSectionIds[0], sessionId: 'repeat-run');
      await driver.answerAuthoredRun(fixtureSectionIds[0]);
      await driver.finish(fixtureSectionIds[0]);

      final current = driver.state;
      expect(
        current.completions,
        hasLength(3),
        reason: 'repeating a qualifying run does not add another identity',
      );
      final staleIdentities = <SentenceHuntCompletion>[
        _completion(
          driver.scope,
          fixtureSectionIds[0],
          contentRevision: 2,
          policyRevision: 1,
          threshold: 80,
        ),
        _completion(
          driver.scope,
          fixtureSectionIds[0],
          contentRevision: 1,
          policyRevision: 2,
          threshold: 80,
        ),
        _completion(
          driver.scope,
          fixtureSectionIds[0],
          contentRevision: 1,
          policyRevision: 1,
          threshold: 70,
        ),
      ];
      final withHistoricalRows = _copyState(
        current,
        completions: [...current.completions, ...staleIdentities],
      );
      final summary = SentenceHuntProgressSummary.fromState(
        state: withHistoricalRows,
        catalogue: driver.catalogue,
      );
      expect(summary.completedSectionCount, 3);
      expect(summary.completionLabel, 'Sentence sections completed: 3/3');
      expect(
        summary.sections.map((section) => section.status),
        everyElement(SentenceHuntSectionStatus.completed),
      );
    },
  );

  test('review_only_and_teaching_exposed_new_runs_remain_labeled', () async {
    final driver = _SentenceHuntDriver(syntheticSentenceCatalogue());
    await driver.load();
    final sectionId = fixtureSectionIds.first;
    await driver.start(sectionId);
    await driver.answerAuthoredRun(
      sectionId,
      wrongItemIds: {fixtureItemIds.first.last},
    );
    await driver.finish(sectionId);
    expect(driver.state.completions, hasLength(1));

    await driver.start(
      sectionId,
      mode: SentenceHuntRunMode.reviewOnly,
      sessionId: 'review-only',
    );
    await driver.answerCurrentQueue(sectionId, correctAll: true);
    await driver.finish(sectionId);
    expect(
      driver.state.completions,
      hasLength(1),
      reason: 'review-only Finish never adds a completion identity',
    );

    await driver.start(sectionId, sessionId: 'teaching-exposed-new-run');
    await driver.answerAuthoredRun(sectionId);
    await driver.finish(sectionId);
    final summary = SentenceHuntProgressSummary.fromState(
      state: driver.state,
      catalogue: driver.catalogue,
    );
    final item = summary.sections.first.items.last;
    expect(item.firstInRunTotal, 3);
    expect(item.firstTeachingExposedTotal, greaterThan(0));
    expect(summary.sections.first.exposedAnswerCount, greaterThan(0));
    expect(summary.completedSectionCount, 1);
  });
}

SentenceHuntCompletion _completion(
  SentenceHuntProfileScope scope,
  String sectionId, {
  required int contentRevision,
  required int policyRevision,
  required int threshold,
}) => SentenceHuntCompletion(
  scope: scope,
  sectionId: sectionId,
  contentRevision: contentRevision,
  policyRevision: policyRevision,
  thresholdPercent: threshold,
  committedAt: DateTime.utc(2026, 10, 18),
);

SentenceHuntState _copyState(
  SentenceHuntState state, {
  List<SentenceHuntCompletion>? completions,
  Map<SentenceHuntSummaryKey, SentenceHuntSummary>? summaries,
}) => SentenceHuntState(
  scope: state.scope,
  revision: state.revision,
  commitOrdinal: state.commitOrdinal,
  slots: state.slots,
  attempts: state.attempts,
  receipts: state.receipts,
  mistakes: state.mistakes,
  summaries: summaries ?? state.summaries,
  completions: completions ?? state.completions,
  teachingExposure: state.teachingExposure,
);

final class _SentenceHuntDriver {
  _SentenceHuntDriver(this.catalogue)
    : scope = SentenceHuntProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.guest(),
      ) {
    _directory = Directory.systemTemp.createTempSync(
      'sentence-hunt-progress-summary-test-',
    );
    _database = LearningDatabaseHandle(
      open: () => openFileLearningTestDatabase(
        File('${_directory.path}/learning.sqlite'),
      ),
    );
    _store = SqliteSentenceHuntLearningRepository(
      database: _database,
      scope: scope,
      authGeneration: 0,
      currentAuth: () => LearningAuthScope(
        owner: LearningOwner.guest(),
        generation: 0,
        ready: true,
      ),
      backendOwner: () => LearningOwner.guest(),
      transitions: SentenceHuntTransitionEngine(catalogue: catalogue),
      clock: () => DateTime.utc(2026, 10, 18, 12, 0, _tick++),
      newToken: () => (++_token).toString().padLeft(22, '0'),
    );
    addTearDown(dispose);
  }

  final SentenceHuntCatalogue catalogue;
  final SentenceHuntProfileScope scope;
  late final Directory _directory;
  late final LearningDatabaseHandle _database;
  late final SqliteSentenceHuntLearningRepository _store;
  late SentenceHuntState state;
  int _token = 0;
  int _tick = 0;

  Future<void> load() async => state = await _store.load();

  Future<void> dispose() async {
    await _database.close();
    if (_directory.existsSync()) await _directory.delete(recursive: true);
  }

  Future<void> start(
    String sectionId, {
    SentenceHuntRunMode mode = SentenceHuntRunMode.practice,
    String? sessionId,
  }) async {
    final section = catalogue.section(sectionId);
    await _submit(
      sectionId,
      StartSentenceHuntRun(
        sessionId: sessionId ?? 'session-${_token + 1}',
        policy: section.policy,
        mode: mode,
      ),
    );
  }

  Future<void> answerAuthoredRun(
    String sectionId, {
    Set<String> wrongItemIds = const <String>{},
  }) async {
    for (final item in catalogue.section(sectionId).items) {
      await _answerCurrent(
        sectionId,
        correct: !wrongItemIds.contains(item.identity.itemId),
      );
      await _submit(sectionId, const AdvanceSentenceHuntItem());
    }
  }

  Future<void> answerCurrentQueue(
    String sectionId, {
    required bool correctAll,
  }) async {
    while (true) {
      final session = _session(sectionId);
      final itemId = session.currentItemId;
      if (itemId == null) return;
      await _answerCurrent(sectionId, correct: correctAll);
      await _submit(sectionId, const AdvanceSentenceHuntItem());
    }
  }

  Future<void> _answerCurrent(String sectionId, {required bool correct}) async {
    final session = _session(sectionId);
    final item = catalogue.item(sectionId, session.currentItemId!);
    final slot = state.slots[sectionId]!;
    final selected = correct
        ? item.expectedTokenIds
        : <String>[item.selectableTokenIds.last];
    final playback = SentenceHuntPlaybackObservation(
      scope: scope,
      content: item.identity,
      runGeneration: slot.cursor.generation,
      round: session.round,
      uiGeneration: 0,
      referenceId: item.reference.id,
      outcome: CourseAudioOutcome.completed,
      source: CourseAudioSource.reviewedRecording,
    );
    await _submit(
      sectionId,
      AnswerSentenceHuntItem(
        SentenceHuntAnswer(
          content: item.identity,
          selectedTokenIds: selected,
          expectedTokenIdsSnapshot: item.expectedTokenIds,
          playback: playback,
        ),
      ),
    );
  }

  LessonSectionSession _session(String sectionId) {
    final section = catalogue.section(sectionId);
    return LessonSectionSession.fromJson(
      Map<String, dynamic>.from(state.slots[sectionId]!.checkpoint.sessionJson),
      itemIds: section.items
          .map((item) => item.identity.itemId)
          .toList(growable: false),
      contentRevision: section.contentRevision,
    );
  }

  Future<void> finish(String sectionId) async =>
      _submit(sectionId, const FinishSentenceHuntRun());

  Future<void> _submit(String sectionId, SentenceHuntAction action) async {
    final command = _store.prepare(
      state: state,
      sectionId: sectionId,
      action: action,
    );
    state = (await _store.submit(command)).state;
  }
}
