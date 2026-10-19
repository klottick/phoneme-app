import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_skill_summary.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/course_learning_state_validator.dart';
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_sql_adapter.dart';
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_storage_validator.dart';
import 'package:linguist/src/core/course/learning_storage_types.dart'
    show LearningCursorPosition;
import '../../integration_test/support/learning_database_workload.dart';
import '../support/sentence_hunt_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('injected_sql_failure_rolls_back_and_lost_ack_retry_is_once', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'sqlite-learning-recovery-',
    );
    final File file = File('${directory.path}/learning.sqlite');
    final LearningDatabaseHandle firstConnection = _fileHandle(file);
    final LearningDatabaseHandle independentConnection = _fileHandle(file);
    try {
      final LearningRecoveryEvidence evidence = await qualifyLearningRecovery(
        firstConnection,
        independentConnection,
        runId: 'recovery-test',
      );

      expect(evidence.failedWritesRolledBack, <String, bool>{
        'course': true,
        'comparison': true,
        'sentence-hunt': true,
      });
      expect(
        evidence.rowValuesAfterRollbackByFamily,
        evidence.rowValuesBeforeFailureByFamily,
      );
      expect(evidence.duplicateReplayDidNotAddAttempts, <String, bool>{
        'course': true,
        'comparison': true,
        'sentence-hunt': true,
      });
      expect(evidence.attemptCountAfterFirstCommit, <String, int>{
        'course': 1,
        'comparison': 1,
        'sentence-hunt': 1,
      });
      expect(evidence.outboxRowsAfterReplay, 1);
      expect(evidence.frozenCommandPayloads, hasLength(3));
      for (final String payload in evidence.frozenCommandPayloads.values) {
        expect(jsonDecode(payload), isA<Map<String, dynamic>>());
      }
      final LearningWorkloadReport report =
          await verifyLearningAtRetentionLimits(
            firstConnection,
            runId: 'recovery-test-recovery',
          );
      final Object? cursors = report.toJson()['cursorValuesByFamily'];
      expect(cursors, isA<Map<String, dynamic>>());
      final Map<String, dynamic> cursorsByFamily =
          cursors! as Map<String, dynamic>;
      expect(
        cursorsByFamily.keys,
        containsAll(<String>['course', 'comparison', 'sentence-hunt']),
      );
      expect(
        (cursorsByFamily['course'] as Map<String, dynamic>).containsKey(
          'activities',
        ),
        isTrue,
      );
      expect(
        (cursorsByFamily['comparison'] as Map<String, dynamic>).containsKey(
          'cursor',
        ),
        isTrue,
      );
      expect(
        (cursorsByFamily['sentence-hunt'] as Map<String, dynamic>).containsKey(
          'sections',
        ),
        isTrue,
      );
      // ignore: avoid_print
      print('TASK9 RECOVERY ${jsonEncode(evidence.toJson())}');
    } finally {
      await firstConnection.close();
      await independentConnection.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'changed_payload_checkpoint_version_and_unknown_ack_are_write_free',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'sqlite-learning-recovery-controls-',
      );
      final File file = File('${directory.path}/learning.sqlite');
      final LearningDatabaseHandle handle = _fileHandle(file);
      try {
        final LearningRecoveryControlEvidence evidence =
            await qualifyLearningRecoveryControls(
              handle,
              runId: 'recovery-controls-test',
            );
        expect(evidence.changedPayloadRejected, isTrue);
        expect(evidence.changedPayloadDidNotRewrite, isTrue);
        expect(evidence.changedContentRejectedWithoutRewrite, isTrue);
        expect(evidence.changedPolicyRejectedWithoutRewrite, isTrue);
        expect(evidence.unknownVersionRejectedWithoutRewrite, isTrue);
        expect(evidence.unknownAckDidNotWrite, isTrue);
      } finally {
        await handle.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('retention_report_separates_validator_and_sql_overflow_evidence', () {
    const Map<String, String> overflow =
        learningOverflowQualificationStatusByFamily;
    expect(overflow['course'], contains('OPEN'));
    expect(overflow['course'], contains('Validator-only'));
    expect(overflow['course'], contains('SQL-backed'));
    expect(overflow['comparison'], contains('OPEN'));
    expect(overflow['comparison'], contains('exactly 10'));
    expect(overflow['sentence-hunt'], contains('OPEN'));
    expect(overflow['sentence-hunt'], contains('SQL-adapter evaluation'));
  });

  test(
    'sentence_hunt_valid_synthetic_aggregate_identities_enforce_4096_cap',
    () {
      final _SyntheticSentenceAggregateFixture fixture =
          _syntheticSentenceAggregateFixture();
      final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.account('task9-synthetic-aggregate-cap'),
      );
      final SentenceHuntTransitionEngine transitions =
          SentenceHuntTransitionEngine(catalogue: fixture.catalogue);
      final String sectionId = fixture.catalogue.sections.first.id;
      final SentenceHuntLearningState started = _startSyntheticSentenceRun(
        transitions,
        scope,
        sectionId,
      );

      for (final String aggregate in <String>[
        'mistakes',
        'summaries',
        'completions',
        'teachingExposure',
      ]) {
        final SentenceHuntLearningState actionState = switch (aggregate) {
          'completions' => _sentenceAtDebrief(transitions, started, sectionId),
          'teachingExposure' => _sentenceBeforeFinalAdvance(
            transitions,
            started,
            sectionId,
          ),
          _ => started,
        };
        final SentenceHuntLearningState aggregateState =
            _sentenceStateAtSingleAggregateLimit(
              actionState,
              fixture,
              aggregate,
            );
        expect(_aggregateLength(aggregateState, aggregate), 4096);
        SentenceHuntLearningStateValidator.validate(
          aggregateState,
          fixture.catalogue,
        );
        final SentenceHuntAction action = switch (aggregate) {
          'mistakes' || 'summaries' => _wrongAnswerAction(
            fixture.catalogue,
            aggregateState,
            sectionId,
          ),
          'completions' => const FinishSentenceHuntRun(),
          _ => const AdvanceSentenceHuntItem(),
        };
        final SentenceHuntLearningSqlAdapter adapter =
            SentenceHuntLearningSqlAdapter(
              scope: scope,
              transitions: transitions,
              historyLimit: 2000,
            );
        final SentenceHuntLearningCommand command = _sentenceCommand(
          fixture.catalogue,
          scope,
          aggregateState,
          sectionId,
          action,
        );

        try {
          adapter.evaluate(
            before: aggregateState,
            command: command,
            nextRevision: aggregateState.revision + 1,
            nextCommitOrdinal: aggregateState.commitOrdinal + 1,
            committedAt: DateTime.utc(2026, 10, 19, 1),
          );
          fail('$aggregate should reject a valid 4097th identity.');
        } on LearningInvalidCommandException catch (error) {
          expect(error.cause, isA<SentenceHuntCapacityException>());
          final SentenceHuntCapacityException capacity =
              error.cause! as SentenceHuntCapacityException;
          expect(capacity.aggregate, aggregate);
          expect(capacity.limit, 4096);
        }
      }
    },
  );

  test('course_synthetic_registry_summary_cap_accepts_4096_rejects_4097', () {
    final _SyntheticCourseRegistry registry = _syntheticCourseRegistry(33);
    final LearningScope scope = LearningScope(
      courseId: 'en-fr',
      owner: LearningOwner.account('task9-course-summary-cap'),
    );
    final Map<SummaryKey, SkillCount> cappedSummaries =
        _courseSummaryIdentities(registry.soundCount - 1);
    expect(cappedSummaries, hasLength(4096));

    final CourseLearningState cappedState = _courseState(
      scope: scope,
      summaries: cappedSummaries,
    );
    CourseLearningStateValidator.validate(cappedState, registry);

    final SummaryKey overflowKey = SummaryKey(
      sound: _syntheticSound(registry.soundCount - 1),
      skill: LearningSkill.listening,
      origin: AttemptOrigin.practice,
      presentation: AttemptPresentation.firstInRun,
      assistance: const <AssistanceFlag>{},
    );
    final CourseLearningState overflowState = _courseState(
      scope: scope,
      summaries: <SummaryKey, SkillCount>{
        ...cappedSummaries,
        overflowKey: SkillCount(total: 0, correct: 0),
      },
    );
    CourseLearningStateValidator.validate(
      _courseState(
        scope: scope,
        summaries: <SummaryKey, SkillCount>{
          overflowKey: SkillCount(total: 0, correct: 0),
        },
      ),
      registry,
    );
    expect(
      () => CourseLearningStateValidator.validate(overflowState, registry),
      throwsFormatException,
    );
  });

  test('course_synthetic_registry_mistake_cap_accepts_4096_rejects_4097', () {
    final _SyntheticCourseRegistry registry = _syntheticCourseRegistry(4097);
    final LearningScope scope = LearningScope(
      courseId: 'en-fr',
      owner: LearningOwner.account('task9-course-mistake-cap'),
    );
    final DateTime timestamp = DateTime.utc(2026, 10, 19);
    final Map<MistakeKey, LearningMistake> cappedMistakes =
        <MistakeKey, LearningMistake>{};
    for (int index = 0; index < 4096; index++) {
      final MapEntry<MistakeKey, LearningMistake> entry = _courseMistake(
        index: index,
        timestamp: timestamp,
      );
      cappedMistakes[entry.key] = entry.value;
    }
    expect(cappedMistakes, hasLength(4096));

    final CourseLearningState cappedState = _courseState(
      scope: scope,
      mistakes: cappedMistakes,
    );
    CourseLearningStateValidator.validate(cappedState, registry);

    final MapEntry<MistakeKey, LearningMistake> overflowMistake =
        _courseMistake(index: 4096, timestamp: timestamp);
    CourseLearningStateValidator.validate(
      _courseState(
        scope: scope,
        mistakes: <MistakeKey, LearningMistake>{
          overflowMistake.key: overflowMistake.value,
        },
      ),
      registry,
    );
    final CourseLearningState overflowState = _courseState(
      scope: scope,
      mistakes: <MistakeKey, LearningMistake>{
        ...cappedMistakes,
        overflowMistake.key: overflowMistake.value,
      },
    );
    expect(
      () => CourseLearningStateValidator.validate(overflowState, registry),
      throwsFormatException,
    );
  });

  test('course_synthetic_completion_cap_accepts_4096_rejects_4097', () {
    final _SyntheticCourseRegistry registry = _SyntheticCourseRegistry(
      <LearningActivityDefinition>[
        for (int index = 0; index < 4097; index++)
          _legacyCourseDefinition(index),
      ],
    );
    final LearningScope scope = LearningScope(
      courseId: 'en-fr',
      owner: LearningOwner.account('task9-course-completion-cap'),
    );
    final DateTime committedAt = DateTime.utc(2026, 10, 19);
    final List<LearningCompletion> cappedCompletions = <LearningCompletion>[
      for (int index = 0; index < 4096; index++)
        _legacyCourseCompletion(index, committedAt),
    ];
    final CourseLearningState cappedState = _courseState(
      scope: scope,
      completions: cappedCompletions,
    );
    CourseLearningStateValidator.validate(cappedState, registry);

    final CourseLearningState overflowState = _courseState(
      scope: scope,
      completions: <LearningCompletion>[
        ...cappedCompletions,
        _legacyCourseCompletion(4096, committedAt),
      ],
    );
    CourseLearningStateValidator.validate(
      _courseState(
        scope: scope,
        completions: <LearningCompletion>[
          _legacyCourseCompletion(4096, committedAt),
        ],
      ),
      registry,
    );
    expect(
      () => CourseLearningStateValidator.validate(overflowState, registry),
      throwsFormatException,
    );
  });

  test('course_synthetic_best_score_cap_accepts_4096_rejects_4097', () {
    final _SyntheticCourseRegistry registry = _SyntheticCourseRegistry(
      <LearningActivityDefinition>[
        for (int index = 0; index < 4097; index++)
          _syntheticWordGameDefinition(index),
      ],
    );
    final LearningScope scope = LearningScope(
      courseId: 'en-fr',
      owner: LearningOwner.account('task9-course-best-score-cap'),
    );
    final Map<String, int> cappedScores = <String, int>{
      for (int index = 0; index < 4096; index++) _syntheticWordGameId(index): 0,
    };
    final CourseLearningState cappedState = _courseState(
      scope: scope,
      bestScores: cappedScores,
    );
    CourseLearningStateValidator.validate(cappedState, registry);

    final CourseLearningState overflowState = _courseState(
      scope: scope,
      bestScores: <String, int>{...cappedScores, _syntheticWordGameId(4096): 0},
    );
    CourseLearningStateValidator.validate(
      _courseState(
        scope: scope,
        bestScores: <String, int>{_syntheticWordGameId(4096): 0},
      ),
      registry,
    );
    expect(
      () => CourseLearningStateValidator.validate(overflowState, registry),
      throwsFormatException,
    );
  });

  test('course_synthetic_activity_cap_accepts_4096_rejects_4097', () {
    final _SyntheticCourseRegistry registry = _SyntheticCourseRegistry(
      <LearningActivityDefinition>[
        for (int index = 0; index < 4097; index++)
          _legacyCourseDefinition(index),
      ],
    );
    final LearningScope scope = LearningScope(
      courseId: 'en-fr',
      owner: LearningOwner.account('task9-course-activity-cap'),
    );
    final Map<String, ActivitySlot> cappedActivities = <String, ActivitySlot>{
      for (int index = 0; index < 4096; index++)
        _legacyCourseActivityId(index): _legacyCourseActivitySlot(
          index,
          index + 1,
        ),
    };
    final CourseLearningState cappedState = _courseState(
      scope: scope,
      revision: 4096,
      commitOrdinal: 4096,
      activities: cappedActivities,
    );
    CourseLearningStateValidator.validate(cappedState, registry);

    final CourseLearningState overflowState = _courseState(
      scope: scope,
      revision: 4097,
      commitOrdinal: 4097,
      activities: <String, ActivitySlot>{
        ...cappedActivities,
        _legacyCourseActivityId(4096): _legacyCourseActivitySlot(4096, 4097),
      },
    );
    CourseLearningStateValidator.validate(
      _courseState(
        scope: scope,
        revision: 1,
        commitOrdinal: 1,
        activities: <String, ActivitySlot>{
          _legacyCourseActivityId(4096): _legacyCourseActivitySlot(4096, 1),
        },
      ),
      registry,
    );
    expect(
      () => CourseLearningStateValidator.validate(overflowState, registry),
      throwsFormatException,
    );
  });

  test('course_synthetic_exposure_cap_accepts_4096_rejects_4097', () {
    const String activityId = 'lesson:task9-synthetic-exposure';
    final List<LearningSourceItem> items = _syntheticDiscoveryItems(4097);
    final LearningActivityDefinition definition = LearningActivityDefinition(
      id: activityId,
      kind: LearningActivityKind.discovery,
      contentRevision: 1,
      items: items,
    );
    final _SyntheticCourseRegistry registry = _SyntheticCourseRegistry(
      <LearningActivityDefinition>[definition],
    );
    final LearningScope scope = LearningScope(
      courseId: 'en-fr',
      owner: LearningOwner.account('task9-course-exposure-cap'),
    );
    final LessonSectionSession session = LessonSectionSession(
      itemIds: items
          .map((LearningSourceItem item) => item.sessionAlias!)
          .toList(growable: false),
      sessionId: 'task9-synthetic-exposure-session',
      contentRevision: 1,
    );
    final Map<ItemContextKey, ItemExposure> cappedExposures =
        <ItemContextKey, ItemExposure>{
          for (int index = 1; index < items.length; index++)
            ItemContextKey(
              itemId: items[index].id,
              targetSound: items[index].targetSounds.single,
            ): ItemExposure(
              presentations: 0,
              assistance: const <AssistanceFlag>{},
            ),
        };
    final ActivitySlot cappedSlot = _discoveryCourseActivitySlot(
      definition: definition,
      session: session,
      exposures: cappedExposures,
    );
    final CourseLearningState cappedState = _courseState(
      scope: scope,
      revision: 1,
      commitOrdinal: 1,
      activities: <String, ActivitySlot>{activityId: cappedSlot},
    );
    CourseLearningStateValidator.validate(cappedState, registry);

    final ActivitySlot overflowSlot = _discoveryCourseActivitySlot(
      definition: definition,
      session: session,
      exposures: <ItemContextKey, ItemExposure>{
        ...cappedExposures,
        ItemContextKey(
          itemId: items.first.id,
          targetSound: items.first.targetSounds.single,
        ): ItemExposure(
          presentations: 0,
          assistance: const <AssistanceFlag>{},
        ),
      },
    );
    final CourseLearningState overflowState = _courseState(
      scope: scope,
      revision: 1,
      commitOrdinal: 1,
      activities: <String, ActivitySlot>{activityId: overflowSlot},
    );
    final ActivitySlot oneExposureSlot = _discoveryCourseActivitySlot(
      definition: definition,
      session: session,
      exposures: <ItemContextKey, ItemExposure>{
        ItemContextKey(
          itemId: items.first.id,
          targetSound: items.first.targetSounds.single,
        ): ItemExposure(
          presentations: 0,
          assistance: const <AssistanceFlag>{},
        ),
      },
    );
    CourseLearningStateValidator.validate(
      _courseState(
        scope: scope,
        revision: 1,
        commitOrdinal: 1,
        activities: <String, ActivitySlot>{activityId: oneExposureSlot},
      ),
      registry,
    );
    expect(
      () => CourseLearningStateValidator.validate(overflowState, registry),
      throwsFormatException,
    );
  });
}

MapEntry<MistakeKey, LearningMistake> _courseMistake({
  required int index,
  required DateTime timestamp,
}) {
  final MistakeKey key = MistakeKey(
    activityId: 'lesson:task9-synthetic-registry',
    itemId: 'task9-synthetic-item-$index',
    contentRevision: 1,
    skill: LearningSkill.listening,
    targetSound: _syntheticSound(index),
  );
  return MapEntry<MistakeKey, LearningMistake>(
    key,
    LearningMistake(
      key: key,
      firstWrongId: 'task9-first-wrong-$index',
      firstWrongAt: timestamp,
      latestWrongId: 'task9-latest-wrong-$index',
      latestWrongAt: timestamp,
      failureCount: 1,
      lastRunGeneration: 1,
    ),
  );
}

CourseLearningState _courseState({
  required LearningScope scope,
  int revision = 0,
  int commitOrdinal = 0,
  Map<String, ActivitySlot> activities = const <String, ActivitySlot>{},
  Map<SummaryKey, SkillCount> summaries = const <SummaryKey, SkillCount>{},
  Map<MistakeKey, LearningMistake> mistakes =
      const <MistakeKey, LearningMistake>{},
  List<LearningCompletion> completions = const <LearningCompletion>[],
  Map<String, int> bestScores = const <String, int>{},
}) => CourseLearningState(
  scope: scope,
  revision: revision,
  commitOrdinal: commitOrdinal,
  history: const <AttemptBatch>[],
  activities: activities,
  mistakes: mistakes,
  summaries: summaries,
  completions: completions,
  bestScores: bestScores,
  pending: const <SupportedCloudEvent>[],
);

LearningActivityDefinition _legacyCourseDefinition(int index) =>
    LearningActivityDefinition(
      id: _legacyCourseActivityId(index),
      kind: LearningActivityKind.legacyLesson,
      contentRevision: 1,
      items: <LearningSourceItem>[
        LearningSourceItem(
          id: 'task9-synthetic-lesson-item-$index',
          sessionAlias: null,
          audioText: 'tout',
          choices: const <String>['u', 'y'],
          expectedChoice: 'u',
          targetSounds: const <String>['u'],
          contentState: AttemptContentState.existingCurated,
        ),
      ],
    );

String _legacyCourseActivityId(int index) =>
    'lesson:task9-synthetic-legacy-$index';

LearningCompletion _legacyCourseCompletion(int index, DateTime committedAt) =>
    LearningCompletion(
      lessonId: 'task9-synthetic-legacy-$index',
      contentRevision: 1,
      policyKind: CompletionPolicyKind.legacyOnePass,
      policyRevision: 1,
      thresholdPercent: null,
      committedAt: committedAt,
    );

LearningActivityDefinition _syntheticWordGameDefinition(int index) =>
    LearningActivityDefinition(
      id: _syntheticWordGameId(index),
      kind: LearningActivityKind.wordGame,
      contentRevision: 1,
      items: const <LearningSourceItem>[],
    );

String _syntheticWordGameId(int index) => 'arcade:task9-synthetic-game-$index';

ActivitySlot _legacyCourseActivitySlot(int index, int commitOrdinal) {
  final LearningActivityDefinition definition = _legacyCourseDefinition(index);
  final SlotCursor before = SlotCursor(generation: 0, sequence: 0, revision: 0);
  final SlotCursor cursor = SlotCursor(generation: 1, sequence: 1, revision: 0);
  return ActivitySlot(
    activityId: definition.id,
    kind: definition.kind,
    contentRevision: definition.contentRevision,
    cursor: cursor,
    options: RunOptions(),
    snapshot: const LegacyLessonCheckpoint(
      wordIndex: 0,
      selectedSound: null,
      finished: false,
    ),
    exposures: const <ItemContextKey, ItemExposure>{},
    latestReceipt: CommandReceipt(
      token: commitOrdinal.toString().padLeft(22, '0'),
      canonicalCommand: 'task9-synthetic-start-$index',
      before: before,
      after: cursor,
      commitOrdinal: commitOrdinal,
    ),
  );
}

ActivitySlot _discoveryCourseActivitySlot({
  required LearningActivityDefinition definition,
  required LessonSectionSession session,
  required Map<ItemContextKey, ItemExposure> exposures,
}) {
  final SlotCursor before = SlotCursor(generation: 0, sequence: 0, revision: 0);
  final SlotCursor cursor = SlotCursor(generation: 1, sequence: 1, revision: 0);
  return ActivitySlot(
    activityId: definition.id,
    kind: definition.kind,
    contentRevision: definition.contentRevision,
    cursor: cursor,
    options: RunOptions(),
    snapshot: DiscoveryCheckpoint(session: session),
    exposures: exposures,
    latestReceipt: CommandReceipt(
      token: '0000000000000000000001',
      canonicalCommand: 'task9-synthetic-discovery-start',
      before: before,
      after: cursor,
      commitOrdinal: 1,
    ),
  );
}

List<LearningSourceItem> _syntheticDiscoveryItems(int count) =>
    <LearningSourceItem>[
      for (int index = 0; index < count; index++)
        LearningSourceItem(
          id: 'task9-synthetic-discovery-item-$index',
          sessionAlias: 'task9-synthetic-discovery-alias-$index',
          audioText: 'tout',
          choices: const <String>['u', 'y'],
          expectedChoice: 'u',
          targetSounds: <String>[_syntheticSound(index)],
          contentState: AttemptContentState.existingCurated,
        ),
    ];

Map<SummaryKey, SkillCount> _courseSummaryIdentities(int soundCount) => {
  for (int soundIndex = 0; soundIndex < soundCount; soundIndex++)
    for (final LearningSkill skill in LearningSkill.values)
      for (final AttemptOrigin origin in AttemptOrigin.values)
        for (final AttemptPresentation presentation
            in AttemptPresentation.values)
          for (int mask = 0; mask < (1 << AssistanceFlag.values.length); mask++)
            SummaryKey(
              sound: _syntheticSound(soundIndex),
              skill: skill,
              origin: origin,
              presentation: presentation,
              assistance: <AssistanceFlag>{
                for (int bit = 0; bit < AssistanceFlag.values.length; bit++)
                  if (mask & (1 << bit) != 0) AssistanceFlag.values[bit],
              },
            ): SkillCount(
              total: 0,
              correct: 0,
            ),
};

String _syntheticSound(int index) => 'task9-synthetic-sound-$index';

_SyntheticCourseRegistry _syntheticCourseRegistry(int soundCount) {
  final List<LearningSourceItem> items = <LearningSourceItem>[
    for (int index = 0; index < soundCount; index++)
      LearningSourceItem(
        id: 'task9-synthetic-item-$index',
        sessionAlias: null,
        audioText: 'tout',
        choices: const <String>['u', 'y'],
        expectedChoice: 'u',
        targetSounds: <String>[_syntheticSound(index)],
        contentState: AttemptContentState.existingCurated,
      ),
  ];
  final LearningActivityDefinition definition = LearningActivityDefinition(
    id: 'lesson:task9-synthetic-registry',
    kind: LearningActivityKind.legacyLesson,
    contentRevision: 1,
    items: items,
  );
  return _SyntheticCourseRegistry(<LearningActivityDefinition>[definition]);
}

final class _SyntheticCourseRegistry implements LearningRegistry {
  _SyntheticCourseRegistry(List<LearningActivityDefinition> definitions)
    : _definitions = List<LearningActivityDefinition>.unmodifiable(definitions),
      _definitionsById = <String, LearningActivityDefinition>{
        for (final LearningActivityDefinition definition in definitions)
          definition.id: definition,
      };

  final List<LearningActivityDefinition> _definitions;
  final Map<String, LearningActivityDefinition> _definitionsById;

  int get soundCount => _definitions.single.items.length;

  @override
  Iterable<LearningActivityDefinition> get activities => _definitions;

  @override
  LearningActivityDefinition require(String activityId) =>
      _definitionsById[activityId] ??
      (throw const LearningInvalidCommandException());
}

final class _SyntheticSentenceAggregateFixture {
  const _SyntheticSentenceAggregateFixture(this.catalogue, this.sectionId);

  final SentenceHuntCatalogue catalogue;
  final String sectionId;

  SentenceHuntContentIdentity historicalIdentity(int revision) {
    final SentenceHuntContentIdentity current = catalogue
        .section(sectionId)
        .items
        .first
        .identity;
    return SentenceHuntContentIdentity(
      sectionId: current.sectionId,
      itemId: current.itemId,
      sentenceId: current.sentenceId,
      audioRefId: current.audioRefId,
      annotationHash: current.annotationHash,
      contentRevision: revision,
      annotationRevision: current.annotationRevision,
    );
  }
}

_SyntheticSentenceAggregateFixture _syntheticSentenceAggregateFixture() {
  const int currentRevision = 4097;
  final SentenceHuntCatalogue base = syntheticSentenceCatalogue();
  final String sectionId = base.sections.first.id;
  final Map<String, dynamic> baseFingerprint =
      jsonDecode(base.sections.first.sectionFingerprint)
          as Map<String, dynamic>;
  final Map<String, dynamic> baseSection = Map<String, dynamic>.from(
    baseFingerprint['section'] as Map,
  );
  final List<Map<String, dynamic>> historicalSections =
      <Map<String, dynamic>>[];
  for (int revision = 1; revision < currentRevision; revision++) {
    final Map<String, dynamic> fingerprintSection = Map<String, dynamic>.from(
      baseSection,
    )..['contentRevision'] = revision;
    final Map<String, dynamic> fingerprint = <String, dynamic>{
      'items': baseFingerprint['items'],
      'section': fingerprintSection,
    };
    historicalSections.add(<String, dynamic>{
      'sectionId': sectionId,
      'kind': 'vowels',
      'contentRevision': revision,
      'policyRevision': 1,
      'completionThresholdPercent': 80,
      'sectionFingerprint': jsonEncode(fingerprint),
    });
  }

  final SentenceHuntPackageFixture package = syntheticSentencePackage(
    historicalSections: historicalSections,
  );
  final List<dynamic> currentSections =
      package.manifest['sections'] as List<dynamic>;
  (currentSections.first as Map<String, dynamic>)['contentRevision'] =
      currentRevision;
  final SentenceHuntCatalogue catalogue = decodeFrenchSentencePackage(
    manifestJson: package.manifestJson,
    provenanceJson: package.provenanceJson,
    annotationsJson: package.annotationsJson,
    sourceEvidenceJson: package.sourceEvidenceJson,
  );
  expect(catalogue.hasValidRoot, isTrue);
  expect(catalogue.historicalSections, hasLength(currentRevision - 1));
  return _SyntheticSentenceAggregateFixture(catalogue, sectionId);
}

SentenceHuntLearningState _startSyntheticSentenceRun(
  SentenceHuntTransitionEngine transitions,
  SentenceHuntProfileScope scope,
  String sectionId,
) {
  final SentenceHuntLearningState empty = SentenceHuntLearningState.empty(
    scope,
  );
  return _evaluateSentenceAction(
    transitions,
    empty,
    sectionId,
    StartSentenceHuntRun(
      sessionId: 'task9-synthetic-start',
      policy: transitions.catalogue.section(sectionId).policy,
      mode: SentenceHuntRunMode.practice,
    ),
  );
}

SentenceHuntLearningState _sentenceBeforeFinalAdvance(
  SentenceHuntTransitionEngine transitions,
  SentenceHuntLearningState started,
  String sectionId,
) {
  SentenceHuntLearningState state = started;
  final int itemCount = transitions.catalogue.section(sectionId).items.length;
  for (int index = 0; index < itemCount; index++) {
    final LessonSectionSession session = _sentenceSession(
      state,
      transitions.catalogue.section(sectionId),
    );
    final SentenceHuntItem item = transitions.catalogue.item(
      sectionId,
      session.currentItemId!,
    );
    state = _evaluateSentenceAction(
      transitions,
      state,
      sectionId,
      AnswerSentenceHuntItem(
        _sentenceAnswer(item, state, session, correct: true),
      ),
    );
    if (index < itemCount - 1) {
      state = _evaluateSentenceAction(
        transitions,
        state,
        sectionId,
        const AdvanceSentenceHuntItem(),
      );
    }
  }
  return state;
}

SentenceHuntLearningState _sentenceAtDebrief(
  SentenceHuntTransitionEngine transitions,
  SentenceHuntLearningState started,
  String sectionId,
) => _evaluateSentenceAction(
  transitions,
  _sentenceBeforeFinalAdvance(transitions, started, sectionId),
  sectionId,
  const AdvanceSentenceHuntItem(),
);

SentenceHuntLearningState _evaluateSentenceAction(
  SentenceHuntTransitionEngine transitions,
  SentenceHuntLearningState state,
  String sectionId,
  SentenceHuntAction action,
) {
  final DateTime submittedAt = _sentenceTime(state.commitOrdinal + 1);
  final SentenceHuntLearningCommand command = transitions.prepare(
    state: state,
    sectionId: sectionId,
    action: action,
    authGeneration: 0,
    token: _sentenceToken(state.commitOrdinal + 1),
    submittedAt: submittedAt,
  );
  return transitions
      .evaluate(state: state, command: command, committedAt: submittedAt)
      .nextState;
}

SentenceHuntAnswer _sentenceAnswer(
  SentenceHuntItem item,
  SentenceHuntLearningState state,
  LessonSectionSession session, {
  required bool correct,
}) {
  final List<String> selectedTokenIds = correct
      ? item.expectedTokenIds
      : <String>[
          item.selectableTokenIds.firstWhere(
            (String id) => !item.expectedTokenIds.contains(id),
          ),
        ];
  final SentenceHuntContentIdentity content = item.identity;
  final int generation =
      state.slots[item.identity.sectionId]!.cursor.generation;
  return SentenceHuntAnswer(
    content: content,
    selectedTokenIds: selectedTokenIds,
    expectedTokenIdsSnapshot: item.expectedTokenIds,
    playback: SentenceHuntPlaybackObservation(
      scope: state.scope,
      content: content,
      runGeneration: generation,
      round: session.round,
      uiGeneration: 0,
      referenceId: content.audioRefId,
      outcome: CourseAudioOutcome.completed,
      source: CourseAudioSource.reviewedRecording,
    ),
  );
}

LessonSectionSession _sentenceSession(
  SentenceHuntLearningState state,
  SentenceHuntSection section,
) => LessonSectionSession.fromJson(
  Map<String, dynamic>.from(state.slots[section.id]!.checkpoint.sessionJson),
  itemIds: section.items
      .map((SentenceHuntItem item) => item.identity.itemId)
      .toList(growable: false),
  contentRevision: section.contentRevision,
);

SentenceHuntAction _wrongAnswerAction(
  SentenceHuntCatalogue catalogue,
  SentenceHuntLearningState state,
  String sectionId,
) {
  final SentenceHuntSection section = catalogue.section(sectionId);
  final LessonSectionSession session = _sentenceSession(state, section);
  final SentenceHuntItem item = catalogue.item(
    sectionId,
    session.currentItemId!,
  );
  return AnswerSentenceHuntItem(
    _sentenceAnswer(item, state, session, correct: false),
  );
}

SentenceHuntLearningState _sentenceStateAtSingleAggregateLimit(
  SentenceHuntLearningState state,
  _SyntheticSentenceAggregateFixture fixture,
  String aggregate,
) {
  final Map<SentenceHuntMistakeKey, SentenceHuntMistake> mistakes =
      Map<SentenceHuntMistakeKey, SentenceHuntMistake>.of(state.mistakes);
  final Map<SentenceHuntSummaryKey, SentenceHuntSummary> summaries =
      Map<SentenceHuntSummaryKey, SentenceHuntSummary>.of(state.summaries);
  final List<SentenceHuntCompletion> completions =
      List<SentenceHuntCompletion>.of(state.completions);
  final Set<SentenceHuntExposureKey> exposure = Set<SentenceHuntExposureKey>.of(
    state.teachingExposure,
  );
  final DateTime timestamp = DateTime.utc(2026, 10, 19);

  for (int revision = 1; revision <= 4096; revision++) {
    final SentenceHuntContentIdentity content = fixture.historicalIdentity(
      revision,
    );
    switch (aggregate) {
      case 'mistakes':
        final SentenceHuntMistakeKey key = SentenceHuntMistakeKey(
          scope: state.scope,
          content: content,
        );
        mistakes[key] = SentenceHuntMistake(
          key: key,
          firstWrongAt: timestamp,
          latestWrongAt: timestamp,
          failureCount: 1,
        );
        break;
      case 'summaries':
        final SentenceHuntSummaryKey key = SentenceHuntSummaryKey(
          scope: state.scope,
          content: content,
        );
        final SentenceHuntCounts empty = SentenceHuntCounts(
          correct: 0,
          total: 0,
        );
        summaries[key] = SentenceHuntSummary(
          key: key,
          firstInRun: empty,
          repeatInRun: empty,
          firstTeachingExposed: empty,
          repeatTeachingExposed: empty,
        );
        break;
      case 'completions':
        completions.add(
          SentenceHuntCompletion(
            scope: state.scope,
            sectionId: fixture.sectionId,
            contentRevision: revision,
            policyRevision: 1,
            thresholdPercent: 80,
            committedAt: timestamp,
          ),
        );
        break;
      case 'teachingExposure':
        exposure.add(
          SentenceHuntExposureKey(
            scope: state.scope,
            sectionId: fixture.sectionId,
            contentRevision: revision,
          ),
        );
        break;
      default:
        throw ArgumentError.value(aggregate, 'aggregate');
    }
  }

  return SentenceHuntLearningState(
    scope: state.scope,
    revision: state.revision,
    commitOrdinal: state.commitOrdinal,
    slots: state.slots,
    attempts: state.attempts,
    receipts: state.receipts,
    mistakes: mistakes,
    summaries: summaries,
    completions: completions,
    teachingExposure: exposure,
  );
}

int _aggregateLength(SentenceHuntLearningState state, String aggregate) =>
    switch (aggregate) {
      'mistakes' => state.mistakes.length,
      'summaries' => state.summaries.length,
      'completions' => state.completions.length,
      'teachingExposure' => state.teachingExposure.length,
      _ => throw ArgumentError.value(aggregate, 'aggregate'),
    };

SentenceHuntLearningCommand _sentenceCommand(
  SentenceHuntCatalogue catalogue,
  SentenceHuntProfileScope scope,
  SentenceHuntLearningState state,
  String sectionId,
  SentenceHuntAction action,
) {
  final SentenceHuntSlot? slot = state.slots[sectionId];
  final int nextOrdinal = state.commitOrdinal + 1;
  return SentenceHuntLearningCommand(
    scope: scope,
    authGeneration: 0,
    sectionId: sectionId,
    sectionFingerprint: catalogue.section(sectionId).sectionFingerprint,
    expected:
        slot?.cursor ??
        const LearningCursorPosition(generation: 0, sequence: 0, revision: 0),
    expectedScopeRevision: state.revision,
    token: _sentenceToken(nextOrdinal),
    submittedAt: _sentenceTime(nextOrdinal),
    action: action,
  );
}

String _sentenceToken(int ordinal) => ordinal.toString().padLeft(22, '0');

DateTime _sentenceTime(int ordinal) =>
    DateTime.utc(2026, 10, 19).add(Duration(microseconds: ordinal));

LearningDatabaseHandle _fileHandle(File file) => LearningDatabaseHandle(
  open: () async => LearningDatabase(DatabaseConnection(NativeDatabase(file))),
);
