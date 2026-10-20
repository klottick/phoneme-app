import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_store.dart'
    show LearningCommit;
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/course_skill_summary.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/course_learning_sql_adapter.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/course_learning_state_validator.dart';
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_sql_adapter.dart';
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_storage_validator.dart';
import 'package:linguist/src/features/arcade/word_match_engine.dart';
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
      final Map<String, Object?> recoveryJson = evidence.toJson();
      expect(
        recoveryJson['canonicalPayloadBytesIdenticalByFamily'],
        <String, bool>{
          'course': true,
          'comparison': true,
          'sentence-hunt': true,
        },
      );
      expect(recoveryJson['replayedWithDecodedCommandByFamily'], <String, bool>{
        'course': true,
        'comparison': true,
        'sentence-hunt': true,
      });
      final Map<String, String> rowsAfterFirstCommit = Map<String, String>.from(
        recoveryJson['normalizedRowsAfterFirstCommitByFamily'] as Map,
      );
      final Map<String, String> rowsAfterReplay = Map<String, String>.from(
        recoveryJson['normalizedRowsAfterReplayByFamily'] as Map,
      );
      final Map<String, Map<String, int>> countsAfterFirstCommit =
          (recoveryJson['normalizedRowCountsAfterFirstCommitByFamily'] as Map)
              .map(
                (Object? key, Object? value) =>
                    MapEntry<String, Map<String, int>>(
                      key! as String,
                      Map<String, int>.from(value! as Map),
                    ),
              );
      final Map<String, Map<String, int>> countsAfterReplay =
          (recoveryJson['normalizedRowCountsAfterReplayByFamily'] as Map).map(
            (Object? key, Object? value) => MapEntry<String, Map<String, int>>(
              key! as String,
              Map<String, int>.from(value! as Map),
            ),
          );
      expect(rowsAfterReplay, rowsAfterFirstCommit);
      expect(countsAfterReplay, countsAfterFirstCommit);
      expect(rowsAfterFirstCommit.keys, hasLength(3));
      for (final String family in <String>[
        'course',
        'comparison',
        'sentence-hunt',
      ]) {
        final List<dynamic> snapshot =
            jsonDecode(rowsAfterFirstCommit[family]!) as List<dynamic>;
        expect(
          countsAfterFirstCommit[family]!.values.fold<int>(
            0,
            (int total, int count) => total + count,
          ),
          greaterThan(0),
        );
        final Set<String> tableNames = <String>{
          for (final dynamic entry in snapshot)
            (entry as Map<String, dynamic>)['table']! as String,
        };
        expect(
          tableNames,
          containsAll(<String>[
            'learning_scopes',
            'learning_content_bindings',
            'learning_runs',
            'learning_attempts',
            'learning_attempt_values',
            'learning_attempt_evidence',
            'learning_command_receipts',
            'learning_mistakes',
            'learning_summaries',
            'learning_completions',
            'learning_exposure',
            'learning_best_scores',
            'supported_sync_outbox',
          ]),
        );
      }
      expect(countsAfterFirstCommit['course']?['supported_sync_outbox'], 1);
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

  test('retention_report_marks_comparison_4096_boundary_unreachable', () async {
    const String runId = 'comparison-overflow-report-test';
    final Directory directory = await Directory.systemTemp.createTemp(
      'sqlite-learning-overflow-report-',
    );
    final File file = File('${directory.path}/learning.sqlite');
    final LearningDatabaseHandle handle = _fileHandle(file);
    final LearningDatabaseHandle independentHandle = _fileHandle(file);
    try {
      await qualifyLearningRecovery(handle, independentHandle, runId: runId);
      final LearningWorkloadReport report =
          await verifyLearningAtRetentionLimits(
            handle,
            runId: '$runId-recovery',
          );
      final Map<String, String> overflow = Map<String, String>.from(
        report.toJson()['overflowResultByFamily'] as Map,
      );
      expect(overflow['course'], contains('OPEN'));
      expect(overflow['course'], contains('Validator-only'));
      expect(overflow['course'], contains('SQL-backed'));
      expect(overflow['comparison'], contains('UNREACHABLE / NOT RUN'));
      expect(overflow['comparison'], contains('4,096→4,097'));
      expect(overflow['comparison'], contains('exact 10'));
      expect(overflow['comparison'], contains('10 mistake identities'));
      expect(overflow['comparison'], contains('10 typed summary identities'));
      expect(overflow['comparison'], contains('30 SQL bucket rows'));
      expect(overflow['comparison'], contains('100 completion thresholds'));
      expect(overflow['comparison'], contains('one slot'));
      expect(overflow['comparison'], isNot(contains('PASS')));
      expect(overflow['sentence-hunt'], contains('OPEN'));
      expect(overflow['sentence-hunt'], contains('SQL-adapter evaluation'));
    } finally {
      await handle.close();
      await independentHandle.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'comparison_reachable_aggregate_bounds_roundtrip_and_reject_extras_write_free',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'sqlite-comparison-reachable-bounds-',
      );
      final LearningDatabaseHandle handle = _fileHandle(
        File('${directory.path}/learning.sqlite'),
      );
      try {
        final Map<String, Object?> evidence =
            await qualifyComparisonReachableBounds(
              handle,
              runId: 'reachable-comparison-bounds-test',
            );
        expect(evidence['pureTransitionCommands'], 2220);
        expect(evidence['typedMistakeIdentities'], 10);
        expect(evidence['typedSummaryIdentities'], 10);
        expect(evidence['sqlSummaryBucketRows'], 30);
        expect(evidence['typedCompletionIdentities'], 100);
        expect(
          evidence['completionThresholds'],
          List<int>.generate(100, (int index) => index + 1),
        );
        expect(evidence['currentSlots'], 1);
        expect(evidence['currentRunGeneration'], 101);
        expect(evidence['commitOrdinalAtPersistedBoundary'], 2220);
        expect(evidence['latestReceiptOrdinalAtBoundary'], 2220);
        expect(evidence['sqlMistakeRows'], 10);
        expect(evidence['sqlCompletionRows'], 100);
        expect(evidence['sqlRunRows'], 1);
        expect(evidence['aggregateSqlMatchesTypedState'], isTrue);
        expect(evidence['actualSqlRepositoryCommandCommitted'], isTrue);
        expect(evidence['actualSqlRepositoryCommandCommitOrdinal'], 2221);
        expect(evidence['extraMistakeRejected'], isTrue);
        expect(evidence['extraSummaryRejected'], isTrue);
        expect(evidence['normalizedSnapshotUnchangedAfterReopen'], isTrue);
        expect(
          evidence['normalizedRowCountsBeforeRejectedOperation'],
          evidence['normalizedRowCountsAfterReopen'],
        );
      } finally {
        await handle.close();
        await directory.delete(recursive: true);
      }
    },
  );

  for (final String aggregate in <String>[
    'activities',
    'mistakes',
    'summaries',
    'completions',
    'bestScores',
    'exposure',
  ]) {
    test('course_sql_${aggregate}_4096_to_4097_rejects_write_free', () async {
      final Map<String, Object?> evidence = await _qualifyCourseSqlOverflow(
        aggregate,
      );
      expect(evidence['controlCommittedBelowCap'], isTrue);
      expect(evidence['loadedTypedIdentitiesBeforeOverflow'], 4096);
      expect(evidence['sqlRowsBeforeOverflow'], 4096);
      expect(evidence['typedCapacityRejected'], isTrue);
      expect(
        evidence['normalizedSnapshotUnchangedAfterIndependentReopen'],
        isTrue,
      );
    }, timeout: const Timeout(Duration(seconds: 90)));
  }

  for (final String aggregate in <String>[
    'mistakes',
    'summaries',
    'completions',
    'teachingExposure',
  ]) {
    test(
      'sentence_hunt_sql_${aggregate}_4096_to_4097_rejects_write_free',
      () async {
        final Map<String, Object?> evidence =
            await _qualifySentenceHuntSqlOverflow(aggregate);
        expect(evidence['controlCommittedBelowCap'], isTrue);
        expect(evidence['loadedTypedIdentitiesBeforeOverflow'], 4096);
        expect(
          evidence['sqlRowsBeforeOverflow'],
          aggregate == 'summaries' ? 16384 : 4096,
        );
        expect(evidence['typedCapacityRejected'], isTrue);
        expect(
          evidence['normalizedSnapshotUnchangedAfterIndependentReopen'],
          isTrue,
        );
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );
  }

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

const List<String> _sqlOverflowTables = <String>[
  'learning_scopes',
  'learning_content_bindings',
  'learning_runs',
  'learning_attempts',
  'learning_attempt_values',
  'learning_attempt_evidence',
  'learning_command_receipts',
  'learning_mistakes',
  'learning_summaries',
  'learning_completions',
  'learning_exposure',
  'learning_best_scores',
  'supported_sync_outbox',
];

final class _SqlScopedSnapshot {
  const _SqlScopedSnapshot({
    required this.rowCounts,
    required this.normalizedRows,
    required this.header,
  });

  final Map<String, int> rowCounts;
  final String normalizedRows;
  final Map<String, Object?> header;
}

Future<_SqlScopedSnapshot> _captureSqlScopedSnapshot(
  LearningDatabase database,
  int scopeId,
) async {
  final Map<String, List<Map<String, Object?>>> rowsByTable =
      <String, List<Map<String, Object?>>>{};
  for (final String table in _sqlOverflowTables) {
    final String sql = table == 'learning_scopes'
        ? 'SELECT * FROM learning_scopes WHERE id = ? ORDER BY rowid'
        : 'SELECT * FROM $table WHERE scope_id = ? ORDER BY rowid';
    final List<QueryRow> rows = await database
        .customSelect(
          sql,
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    rowsByTable[table] = <Map<String, Object?>>[
      for (final QueryRow row in rows) Map<String, Object?>.from(row.data),
    ];
  }
  final List<Map<String, Object?>> scopeRows = rowsByTable['learning_scopes']!;
  if (scopeRows.length != 1) {
    throw StateError('Expected exactly one scoped SQLite header row.');
  }
  return _SqlScopedSnapshot(
    rowCounts: <String, int>{
      for (final String table in _sqlOverflowTables)
        table: rowsByTable[table]!.length,
    },
    normalizedRows: jsonEncode(rowsByTable),
    header: scopeRows.single,
  );
}

Future<Map<String, Object?>> _qualifyCourseSqlOverflow(String aggregate) async {
  if (aggregate == 'activities') {
    return _qualifyCourseActivitySqlOverflow();
  }

  final Directory directory = await Directory.systemTemp.createTemp(
    'sqlite-course-$aggregate-overflow-',
  );
  final File file = File('${directory.path}/learning.sqlite');
  final LearningDatabaseHandle primary = _fileHandle(file);
  final LearningDatabaseHandle independent = _fileHandle(file);
  try {
    final _CourseOverflowFixture controlFixture = await _seedCourseOverflow(
      primary,
      aggregate: aggregate,
      count: 4095,
      label: 'control',
    );
    await primary.reopen();
    final SqliteCourseLearningRepository controlRepository =
        _courseOverflowRepository(primary, controlFixture);
    CourseLearningState controlState = await controlRepository.load();
    CourseLearningStateValidator.validate(
      controlState,
      controlFixture.registry,
    );
    expect(_courseAggregateCount(controlState, aggregate), 4095);
    final _SqlScopedSnapshot controlSeedSnapshot =
        await _captureSqlScopedSnapshot(
          await primary.open(),
          controlFixture.scopeId,
        );
    expect(
      controlSeedSnapshot.rowCounts[_courseSqlTableFor(aggregate)],
      _expectedCourseSqlRows(aggregate, 4095),
    );
    final LearningCommand controlCommand = _courseOverflowCommand(
      controlRepository,
      controlFixture,
      controlState,
    );
    final LearningCommit controlCommit = await controlRepository.submit(
      controlCommand,
    );
    controlState = controlCommit.state;
    CourseLearningStateValidator.validate(
      controlState,
      controlFixture.registry,
    );
    expect(_courseAggregateCount(controlState, aggregate), 4096);
    await primary.reopen();
    controlState = await controlRepository.load();
    CourseLearningStateValidator.validate(
      controlState,
      controlFixture.registry,
    );
    expect(_courseAggregateCount(controlState, aggregate), 4096);
    final _SqlScopedSnapshot controlSnapshot = await _captureSqlScopedSnapshot(
      await primary.open(),
      controlFixture.scopeId,
    );
    final int collectionRows =
        controlSnapshot.rowCounts[_courseSqlTableFor(aggregate)]!;
    expect(collectionRows, _expectedCourseSqlRows(aggregate, 4096));

    final _CourseOverflowFixture overflowFixture = await _seedCourseOverflow(
      primary,
      aggregate: aggregate,
      count: 4096,
      label: 'overflow',
    );
    await primary.reopen();
    final SqliteCourseLearningRepository overflowRepository =
        _courseOverflowRepository(primary, overflowFixture);
    final CourseLearningState loaded = await overflowRepository.load();
    CourseLearningStateValidator.validate(loaded, overflowFixture.registry);
    expect(_courseAggregateCount(loaded, aggregate), 4096);
    final _SqlScopedSnapshot before = await _captureSqlScopedSnapshot(
      await primary.open(),
      overflowFixture.scopeId,
    );
    expect(
      before.rowCounts[_courseSqlTableFor(aggregate)],
      _expectedCourseSqlRows(aggregate, 4096),
    );
    final LearningCommand overflowCommand = _courseOverflowCommand(
      overflowRepository,
      overflowFixture,
      loaded,
    );
    late final LearningInvalidCommandException typedError;
    try {
      await overflowRepository.submit(overflowCommand);
      fail('A valid distinct 4097th $aggregate identity must be rejected.');
    } on LearningInvalidCommandException catch (error) {
      typedError = error;
    }
    if (aggregate == 'activities') {
      expect(typedError.cause, isA<FormatException>());
    } else {
      expect(typedError.cause == null, isTrue);
    }

    await primary.close();
    await independent.reopen();
    final SqliteCourseLearningRepository reopenedRepository =
        _courseOverflowRepository(independent, overflowFixture);
    final CourseLearningState reopened = await reopenedRepository.load();
    CourseLearningStateValidator.validate(reopened, overflowFixture.registry);
    final _SqlScopedSnapshot after = await _captureSqlScopedSnapshot(
      await independent.open(),
      overflowFixture.scopeId,
    );
    final bool unchanged = before.normalizedRows == after.normalizedRows;
    expect(unchanged, isTrue);
    expect(_courseAggregateCount(reopened, aggregate), 4096);
    expect(
      after.rowCounts[_courseSqlTableFor(aggregate)],
      _expectedCourseSqlRows(aggregate, 4096),
    );

    final Map<String, Object?> evidence = <String, Object?>{
      'family': 'course',
      'collection': aggregate,
      'controlSeedTypedIdentities': 4095,
      'controlSeedSqlRows':
          controlSeedSnapshot.rowCounts[_courseSqlTableFor(aggregate)],
      'controlCommittedBelowCap': true,
      'controlLoadedTypedIdentitiesAfterCommit': _courseAggregateCount(
        controlState,
        aggregate,
      ),
      'controlSqlRowsAfterCommit': collectionRows,
      'controlCommand': <String, Object?>{
        'action': controlCommand.action.runtimeType.toString(),
        'activityId': controlCommand.activityId,
        'expectedScopeRevision': controlCommand.expectedScopeRevision,
        'token': controlCommand.token,
      },
      'controlSeedHeader': <String, Object?>{
        'revision': controlSeedSnapshot.header['revision'],
        'commitOrdinal': controlSeedSnapshot.header['commit_ordinal'],
      },
      'controlHeaderAfterCommit': <String, Object?>{
        'revision': controlSnapshot.header['revision'],
        'commitOrdinal': controlSnapshot.header['commit_ordinal'],
      },
      'loadedTypedIdentitiesBeforeOverflow': _courseAggregateCount(
        loaded,
        aggregate,
      ),
      'sqlRowsBeforeOverflow': before.rowCounts[_courseSqlTableFor(aggregate)],
      'overflowIdentity': _courseOverflowIdentity(aggregate, overflowFixture),
      'overflowCommand': <String, Object?>{
        'action': overflowCommand.action.runtimeType.toString(),
        'activityId': overflowCommand.activityId,
        'expectedScopeRevision': overflowCommand.expectedScopeRevision,
        'token': overflowCommand.token,
      },
      'typedError': typedError.runtimeType.toString(),
      'typedErrorCause': typedError.cause?.runtimeType.toString(),
      'typedCapacityRejected': true,
      'normalizedRowCountsBefore': before.rowCounts,
      'normalizedRowCountsAfterIndependentReopen': after.rowCounts,
      'headerBefore': <String, Object?>{
        'revision': before.header['revision'],
        'commitOrdinal': before.header['commit_ordinal'],
      },
      'headerAfter': <String, Object?>{
        'revision': after.header['revision'],
        'commitOrdinal': after.header['commit_ordinal'],
      },
      'normalizedSnapshotBytes': utf8.encode(before.normalizedRows).length,
      'normalizedSnapshotUnchangedAfterIndependentReopen': unchanged,
    };
    // ignore: avoid_print
    print('TASK9 SQL OVERFLOW ${jsonEncode(evidence)}');
    return evidence;
  } finally {
    await primary.close();
    await independent.close();
    await directory.delete(recursive: true);
  }
}

Future<Map<String, Object?>> _qualifyCourseActivitySqlOverflow() async {
  final Directory directory = await Directory.systemTemp.createTemp(
    'sqlite-course-activities-overflow-',
  );
  final File file = File('${directory.path}/learning.sqlite');
  final LearningDatabaseHandle primary = _fileHandle(file);
  final LearningDatabaseHandle independent = _fileHandle(file);
  try {
    final LearningScope scope = _courseOverflowScope('activities');
    final _SyntheticCourseRegistry registry =
        _SyntheticCourseRegistry(<LearningActivityDefinition>[
          for (int index = 0; index < 4097; index++)
            LearningActivityDefinition(
              id: _courseActivityIdentity(index),
              kind: LearningActivityKind.legacyLesson,
              contentRevision: 1,
              items: const <LearningSourceItem>[],
            ),
        ]);
    final LearningTransitionEngine transitions = LearningTransitionEngine(
      registry,
    );
    final int scopeId = await _seedCourseActivitySlots(
      primary,
      scope: scope,
      transitions: transitions,
      count: 4095,
    );
    final _CourseOverflowFixture fixture = _CourseOverflowFixture(
      scope: scope,
      scopeId: scopeId,
      registry: registry,
      transitions: transitions,
      aggregate: 'activities',
      activeActivityId: _courseActivityIdentity(4095),
      capCount: 4095,
    );
    await primary.reopen();
    final SqliteCourseLearningRepository repository = _courseOverflowRepository(
      primary,
      fixture,
    );
    final CourseLearningState beforeControl = await repository.load();
    CourseLearningStateValidator.validate(beforeControl, registry);
    expect(beforeControl.activities, hasLength(4095));
    final _SqlScopedSnapshot seedSnapshot = await _captureSqlScopedSnapshot(
      await primary.open(),
      scopeId,
    );
    expect(seedSnapshot.rowCounts['learning_runs'], 4095);
    final LearningCommand controlCommand = _courseOverflowCommand(
      repository,
      fixture,
      beforeControl,
    );
    final LearningCommit controlCommit = await repository.submit(
      controlCommand,
    );
    expect(controlCommit.state.activities, hasLength(4096));
    await primary.reopen();
    final CourseLearningState loaded = await repository.load();
    CourseLearningStateValidator.validate(loaded, registry);
    expect(loaded.activities, hasLength(4096));
    final _SqlScopedSnapshot before = await _captureSqlScopedSnapshot(
      await primary.open(),
      scopeId,
    );
    expect(before.rowCounts['learning_runs'], 4096);

    final _CourseOverflowFixture overflowFixture = _CourseOverflowFixture(
      scope: scope,
      scopeId: scopeId,
      registry: registry,
      transitions: transitions,
      aggregate: 'activities',
      activeActivityId: _courseActivityIdentity(4096),
      capCount: 4096,
    );
    final LearningCommand overflowCommand = _courseOverflowCommand(
      repository,
      overflowFixture,
      loaded,
    );
    late final LearningInvalidCommandException typedError;
    try {
      await repository.submit(overflowCommand);
      fail('A valid distinct 4097th activity identity must be rejected.');
    } on LearningInvalidCommandException catch (error) {
      typedError = error;
    }
    expect(typedError.cause, isA<FormatException>());

    await primary.close();
    await independent.reopen();
    final SqliteCourseLearningRepository reopenedRepository =
        _courseOverflowRepository(independent, fixture);
    final CourseLearningState reopened = await reopenedRepository.load();
    CourseLearningStateValidator.validate(reopened, registry);
    final _SqlScopedSnapshot after = await _captureSqlScopedSnapshot(
      await independent.open(),
      scopeId,
    );
    final bool unchanged = before.normalizedRows == after.normalizedRows;
    expect(unchanged, isTrue);
    expect(reopened.activities, hasLength(4096));
    expect(after.rowCounts['learning_runs'], 4096);

    final Map<String, Object?> evidence = <String, Object?>{
      'family': 'course',
      'collection': 'activities',
      'seededTypedIdentities': 4095,
      'seededSqlRunRows': 4095,
      'controlCommittedBelowCap': true,
      'controlLoadedTypedIdentitiesAfterCommit': 4096,
      'controlSqlRunRowsAfterCommit': 4096,
      'loadedTypedIdentitiesBeforeOverflow': loaded.activities.length,
      'sqlRowsBeforeOverflow': before.rowCounts['learning_runs'],
      'overflowIdentity': _courseActivityIdentity(4096),
      'controlCommand': <String, Object?>{
        'action': controlCommand.action.runtimeType.toString(),
        'activityId': controlCommand.activityId,
        'expectedScopeRevision': controlCommand.expectedScopeRevision,
        'token': controlCommand.token,
      },
      'overflowCommand': <String, Object?>{
        'action': overflowCommand.action.runtimeType.toString(),
        'activityId': overflowCommand.activityId,
        'expectedScopeRevision': overflowCommand.expectedScopeRevision,
        'token': overflowCommand.token,
      },
      'typedError': typedError.runtimeType.toString(),
      'typedErrorCause': typedError.cause.runtimeType.toString(),
      'typedCapacityRejected': true,
      'seedHeader': <String, Object?>{
        'revision': seedSnapshot.header['revision'],
        'commitOrdinal': seedSnapshot.header['commit_ordinal'],
      },
      'controlHeaderAfterCommit': <String, Object?>{
        'revision': before.header['revision'],
        'commitOrdinal': before.header['commit_ordinal'],
      },
      'normalizedRowCountsBefore': before.rowCounts,
      'normalizedRowCountsAfterIndependentReopen': after.rowCounts,
      'headerBefore': <String, Object?>{
        'revision': before.header['revision'],
        'commitOrdinal': before.header['commit_ordinal'],
      },
      'headerAfter': <String, Object?>{
        'revision': after.header['revision'],
        'commitOrdinal': after.header['commit_ordinal'],
      },
      'normalizedSnapshotBytes': utf8.encode(before.normalizedRows).length,
      'normalizedSnapshotUnchangedAfterIndependentReopen': unchanged,
    };
    // ignore: avoid_print
    print('TASK9 SQL OVERFLOW ${jsonEncode(evidence)}');
    return evidence;
  } finally {
    await primary.close();
    await independent.close();
    await directory.delete(recursive: true);
  }
}

final class _CourseOverflowFixture {
  const _CourseOverflowFixture({
    required this.scope,
    required this.scopeId,
    required this.registry,
    required this.transitions,
    required this.aggregate,
    required this.activeActivityId,
    required this.capCount,
  });

  final LearningScope scope;
  final int scopeId;
  final _SyntheticCourseRegistry registry;
  final LearningTransitionEngine transitions;
  final String aggregate;
  final String activeActivityId;
  final int capCount;
}

LearningScope _courseOverflowScope(String suffix) => LearningScope(
  courseId: 'en-fr',
  owner: LearningOwner.account('task9-course-sql-$suffix'),
);

String _courseActivityIdentity(int index) =>
    'lesson:task9-synthetic-activity-$index';

String _courseToken(int ordinal, {String prefix = 's'}) =>
    '$prefix${ordinal.toString().padLeft(21, '0')}';

Future<int> _seedCourseActivitySlots(
  LearningDatabaseHandle handle, {
  required LearningScope scope,
  required LearningTransitionEngine transitions,
  required int count,
}) async {
  final LearningDatabase database = await handle.open();
  final CourseLearningSqlAdapter adapter = CourseLearningSqlAdapter(
    scope: scope,
    transitions: transitions,
    historyLimit: 2000,
  );
  final int scopeId = await database.ensureScope(adapter.scope);
  await database.transaction(() async {
    for (int index = 0; index < count; index++) {
      final int revision = index;
      // Starts target distinct empty legacy lessons. Omitting unrelated prior
      // slots from this seed-only projection keeps per-slot validation bounded;
      // the SQL rows still receive monotonically CAS-committed authentic start
      // commands and are validated together by the typed repository after load.
      final CourseLearningState before = CourseLearningState(
        scope: scope,
        revision: revision,
        commitOrdinal: revision,
        history: const <AttemptBatch>[],
        activities: const <String, ActivitySlot>{},
        mistakes: const <MistakeKey, LearningMistake>{},
        summaries: const <SummaryKey, SkillCount>{},
        completions: const <LearningCompletion>[],
        bestScores: const <String, int>{},
        pending: const <SupportedCloudEvent>[],
      );
      final LearningCommand command = transitions.prepare(
        state: before,
        authGeneration: 0,
        activityId: _courseActivityIdentity(index),
        action: StartLearningRun(options: RunOptions()),
        token: _courseToken(index + 1),
        submittedAt: DateTime.utc(
          2026,
          10,
          19,
          1,
        ).add(Duration(microseconds: index)),
        random: Random(index),
      );
      final CourseLearningState after = adapter
          .evaluate(
            before: before,
            command: command,
            nextRevision: revision + 1,
            nextCommitOrdinal: revision + 1,
            committedAt: DateTime.utc(
              2026,
              10,
              19,
              1,
            ).add(Duration(microseconds: index)),
          )
          .state;
      await adapter.persist(database, scopeId, before, command, after);
      final int updatedRows = await database.compareAndSwapLearningScope(
        scopeId: scopeId,
        expectedRevision: revision,
        expectedCommitOrdinal: revision,
        nextRevision: revision + 1,
        nextCommitOrdinal: revision + 1,
      );
      expect(updatedRows, 1);
    }
  });
  return scopeId;
}

Future<_CourseOverflowFixture> _seedCourseOverflow(
  LearningDatabaseHandle handle, {
  required String aggregate,
  required int count,
  required String label,
}) async {
  final LearningScope scope = _courseOverflowScope('$aggregate-$label');
  final String activityId = _courseActiveActivityId(aggregate, count);
  final _SyntheticCourseRegistry registry = _courseOverflowRegistry(
    aggregate,
    activeActivityId: activityId,
  );
  final LearningTransitionEngine transitions = LearningTransitionEngine(
    registry,
  );
  final LearningDatabase database = await handle.open();
  final CourseLearningSqlAdapter adapter = CourseLearningSqlAdapter(
    scope: scope,
    transitions: transitions,
    historyLimit: 2000,
  );
  final int scopeId = await database.ensureScope(adapter.scope);
  final CourseLearningState before = CourseLearningState.empty(scope);
  if (aggregate == 'completions') {
    await database.transaction(() async {
      CourseLearningState state = before;
      final LearningCommand startCommand = transitions.prepare(
        state: state,
        authGeneration: 0,
        activityId: activityId,
        action: StartLearningRun(options: RunOptions()),
        token: _courseToken(1),
        submittedAt: DateTime.utc(2026, 10, 19, 1),
        random: Random(17),
      );
      CourseLearningState after = adapter
          .evaluate(
            before: state,
            command: startCommand,
            nextRevision: 1,
            nextCommitOrdinal: 1,
            committedAt: startCommand.submittedAt,
          )
          .state;
      await _persistCourseSeedTransition(
        database,
        adapter,
        scopeId,
        state,
        startCommand,
        after,
      );
      state = after;

      final LearningSourceItem item = registry.require(activityId).items.single;
      final LearningCommand answerCommand = transitions.prepare(
        state: state,
        authGeneration: 0,
        activityId: activityId,
        action: ChooseSound(
          selectedSound: item.expectedChoice!,
          audioSource: authoredAudioSource(item)!,
        ),
        token: _courseToken(2),
        submittedAt: DateTime.utc(2026, 10, 19, 1, 0, 0, 1),
        random: Random(18),
      );
      after = adapter
          .evaluate(
            before: state,
            command: answerCommand,
            nextRevision: 2,
            nextCommitOrdinal: 2,
            committedAt: answerCommand.submittedAt,
          )
          .state;
      await _persistCourseSeedTransition(
        database,
        adapter,
        scopeId,
        state,
        answerCommand,
        after,
      );
      state = after;

      final LearningCommand advanceCommand = transitions.prepare(
        state: state,
        authGeneration: 0,
        activityId: activityId,
        action: const AdvanceLesson(),
        token: _courseToken(3),
        submittedAt: DateTime.utc(2026, 10, 19, 1, 0, 0, 2),
        random: Random(19),
      );
      after = adapter
          .evaluate(
            before: state,
            command: advanceCommand,
            nextRevision: 3,
            nextCommitOrdinal: 3,
            committedAt: advanceCommand.submittedAt,
          )
          .state;
      final CourseLearningState capped = _withCourseAggregate(
        after,
        aggregate: aggregate,
        count: count,
        activeActivityId: activityId,
        registry: registry,
      );
      CourseLearningStateValidator.validate(capped, registry);
      await _persistCourseSeedTransition(
        database,
        adapter,
        scopeId,
        state,
        advanceCommand,
        capped,
      );
    });
    return _CourseOverflowFixture(
      scope: scope,
      scopeId: scopeId,
      registry: registry,
      transitions: transitions,
      aggregate: aggregate,
      activeActivityId: activityId,
      capCount: count,
    );
  }
  if (aggregate == 'bestScores') {
    await database.transaction(() async {
      final LearningCommand startCommand = transitions.prepare(
        state: before,
        authGeneration: 0,
        activityId: activityId,
        action: StartLearningRun(options: RunOptions()),
        token: _courseToken(1),
        submittedAt: DateTime.utc(2026, 10, 19, 1),
        random: Random(17),
      );
      final CourseLearningState state = adapter
          .evaluate(
            before: before,
            command: startCommand,
            nextRevision: 1,
            nextCommitOrdinal: 1,
            committedAt: startCommand.submittedAt,
          )
          .state;
      await _persistCourseSeedTransition(
        database,
        adapter,
        scopeId,
        before,
        startCommand,
        state,
      );
      final LearningCommand resumeCommand = transitions.prepare(
        state: state,
        authGeneration: 0,
        activityId: activityId,
        action: CheckpointArcade(elapsedSeconds: 0, paused: false),
        token: _courseToken(2),
        submittedAt: DateTime.utc(2026, 10, 19, 1, 0, 0, 1),
        random: Random(18),
      );
      final CourseLearningState resumed = adapter
          .evaluate(
            before: state,
            command: resumeCommand,
            nextRevision: 2,
            nextCommitOrdinal: 2,
            committedAt: resumeCommand.submittedAt,
          )
          .state;
      final CourseLearningState capped = _withCourseAggregate(
        resumed,
        aggregate: aggregate,
        count: count,
        activeActivityId: activityId,
        registry: registry,
      );
      CourseLearningStateValidator.validate(capped, registry);
      await _persistCourseSeedTransition(
        database,
        adapter,
        scopeId,
        state,
        resumeCommand,
        capped,
      );
    });
    return _CourseOverflowFixture(
      scope: scope,
      scopeId: scopeId,
      registry: registry,
      transitions: transitions,
      aggregate: aggregate,
      activeActivityId: activityId,
      capCount: count,
    );
  }

  final LearningCommand startCommand = transitions.prepare(
    state: before,
    authGeneration: 0,
    activityId: activityId,
    action: StartLearningRun(options: RunOptions()),
    token: _courseToken(1),
    submittedAt: DateTime.utc(2026, 10, 19, 1),
    random: Random(17),
  );
  final CourseLearningState started = adapter
      .evaluate(
        before: before,
        command: startCommand,
        nextRevision: 1,
        nextCommitOrdinal: 1,
        committedAt: DateTime.utc(2026, 10, 19, 1),
      )
      .state;
  final CourseLearningState after = _withCourseAggregate(
    started,
    aggregate: aggregate,
    count: count,
    activeActivityId: activityId,
    registry: registry,
  );
  CourseLearningStateValidator.validate(after, registry);
  await database.transaction(() async {
    await _persistCourseSeedTransition(
      database,
      adapter,
      scopeId,
      before,
      startCommand,
      after,
    );
  });
  return _CourseOverflowFixture(
    scope: scope,
    scopeId: scopeId,
    registry: registry,
    transitions: transitions,
    aggregate: aggregate,
    activeActivityId: activityId,
    capCount: count,
  );
}

Future<void> _persistCourseSeedTransition(
  LearningDatabase database,
  CourseLearningSqlAdapter adapter,
  int scopeId,
  CourseLearningState before,
  LearningCommand command,
  CourseLearningState after,
) async {
  await adapter.persist(database, scopeId, before, command, after);
  final int changedRows = await database.compareAndSwapLearningScope(
    scopeId: scopeId,
    expectedRevision: before.revision,
    expectedCommitOrdinal: before.commitOrdinal,
    nextRevision: after.revision,
    nextCommitOrdinal: after.commitOrdinal,
  );
  expect(changedRows, 1);
}

String _courseActiveActivityId(String aggregate, int count) =>
    switch (aggregate) {
      'completions' => _legacyCourseActivityId(count),
      'bestScores' => _syntheticWordGameId(count),
      'activities' => _courseActivityIdentity(count),
      _ => 'lesson:task9-course-sql-active-$aggregate-$count',
    };

_SyntheticCourseRegistry _courseOverflowRegistry(
  String aggregate, {
  required String activeActivityId,
}) {
  if (aggregate == 'activities') {
    return _SyntheticCourseRegistry(<LearningActivityDefinition>[
      for (int index = 0; index < 4097; index++)
        LearningActivityDefinition(
          id: _courseActivityIdentity(index),
          kind: LearningActivityKind.legacyLesson,
          contentRevision: 1,
          items: const <LearningSourceItem>[],
        ),
    ]);
  }
  if (aggregate == 'mistakes') {
    final LearningActivityDefinition active = _courseLegacyDefinition(
      activityId: activeActivityId,
      item: _courseOverflowItem(
        'task9-course-active-item',
        _syntheticSound(4096),
      ),
    );
    return _SyntheticCourseRegistry(<LearningActivityDefinition>[
      _syntheticCourseRegistry(4097).activities.single,
      active,
    ]);
  }
  if (aggregate == 'summaries') {
    final LearningActivityDefinition active = _courseLegacyDefinition(
      activityId: activeActivityId,
      item: _courseOverflowItem(
        'task9-course-summary-active-item',
        _syntheticSound(32),
      ),
    );
    return _SyntheticCourseRegistry(<LearningActivityDefinition>[
      _syntheticCourseRegistry(33).activities.single,
      active,
    ]);
  }
  if (aggregate == 'completions') {
    return _SyntheticCourseRegistry(<LearningActivityDefinition>[
      for (int index = 0; index < 4097; index++) _legacyCourseDefinition(index),
    ]);
  }
  if (aggregate == 'bestScores') {
    final List<LearningSourceItem> gameItems = _wordGameItems();
    return _SyntheticCourseRegistry(<LearningActivityDefinition>[
      for (int index = 0; index < 4097; index++)
        _syntheticWordGameDefinition(
          index,
          items: _syntheticWordGameId(index) == activeActivityId
              ? gameItems
              : const <LearningSourceItem>[],
        ),
    ]);
  }
  if (aggregate == 'exposure') {
    final List<LearningSourceItem> items = _syntheticDiscoveryItems(4097);
    return _SyntheticCourseRegistry(<LearningActivityDefinition>[
      LearningActivityDefinition(
        id: activeActivityId,
        kind: LearningActivityKind.discovery,
        contentRevision: 1,
        items: items,
      ),
    ]);
  }
  throw ArgumentError.value(aggregate, 'aggregate');
}

LearningActivityDefinition _courseLegacyDefinition({
  required String activityId,
  required LearningSourceItem item,
}) => LearningActivityDefinition(
  id: activityId,
  kind: LearningActivityKind.legacyLesson,
  contentRevision: 1,
  items: <LearningSourceItem>[item],
);

LearningSourceItem _courseOverflowItem(String itemId, String sound) =>
    LearningSourceItem(
      id: itemId,
      sessionAlias: null,
      audioText: 'tout',
      choices: const <String>['u', 'y'],
      expectedChoice: 'u',
      targetSounds: <String>[sound],
      contentState: AttemptContentState.existingCurated,
    );

List<LearningSourceItem> _wordGameItems() => <LearningSourceItem>[
  for (final word in WordMatchEngine(random: Random(13)).pool)
    LearningSourceItem(
      id: word.text,
      sessionAlias: null,
      audioText: null,
      choices: const <String>[],
      expectedChoice: null,
      targetSounds: const <String>['u', 'y'],
      contentState: AttemptContentState.existingCurated,
    ),
];

CourseLearningState _withCourseAggregate(
  CourseLearningState state, {
  required String aggregate,
  required int count,
  required String activeActivityId,
  required _SyntheticCourseRegistry registry,
}) {
  Map<MistakeKey, LearningMistake> mistakes = state.mistakes;
  Map<SummaryKey, SkillCount> summaries = state.summaries;
  List<LearningCompletion> completions = state.completions;
  Map<String, int> bestScores = state.bestScores;
  Map<String, ActivitySlot> activities = state.activities;
  switch (aggregate) {
    case 'mistakes':
      mistakes = <MistakeKey, LearningMistake>{
        for (int index = 0; index < count; index++)
          _courseMistake(
            index: index,
            timestamp: DateTime.utc(2026, 10, 19),
          ).key: _courseMistake(
            index: index,
            timestamp: DateTime.utc(2026, 10, 19),
          ).value,
      };
      break;
    case 'summaries':
      summaries = Map<SummaryKey, SkillCount>.fromEntries(
        _courseSummaryIdentities(32).entries.take(count),
      );
      break;
    case 'completions':
      completions = <LearningCompletion>[
        for (int index = 0; index < count; index++)
          _legacyCourseCompletion(index, DateTime.utc(2026, 10, 19)),
      ];
      break;
    case 'bestScores':
      bestScores = <String, int>{
        for (int index = 0; index < count; index++)
          _syntheticWordGameId(index): 0,
      };
      break;
    case 'exposure':
      final LearningActivityDefinition definition = registry.require(
        activeActivityId,
      );
      final List<LearningSourceItem> items = definition.items;
      final int firstIndex = items.length - count;
      final ActivitySlot slot = state.activities[activeActivityId]!;
      activities = <String, ActivitySlot>{
        ...state.activities,
        activeActivityId: ActivitySlot(
          activityId: slot.activityId,
          kind: slot.kind,
          contentRevision: slot.contentRevision,
          cursor: slot.cursor,
          options: slot.options,
          snapshot: slot.snapshot,
          exposures: <ItemContextKey, ItemExposure>{
            for (int index = firstIndex; index < items.length; index++)
              ItemContextKey(
                itemId: items[index].id,
                targetSound: items[index].targetSounds.single,
              ): ItemExposure(
                presentations: 0,
                assistance: const <AssistanceFlag>{},
              ),
          },
          latestReceipt: slot.latestReceipt,
        ),
      };
      break;
  }
  return _copyCourseState(
    state,
    activities: activities,
    mistakes: mistakes,
    summaries: summaries,
    completions: completions,
    bestScores: bestScores,
  );
}

CourseLearningState _copyCourseState(
  CourseLearningState state, {
  Map<String, ActivitySlot>? activities,
  Map<MistakeKey, LearningMistake>? mistakes,
  Map<SummaryKey, SkillCount>? summaries,
  List<LearningCompletion>? completions,
  Map<String, int>? bestScores,
}) => CourseLearningState(
  schemaVersion: state.schemaVersion,
  scope: state.scope,
  revision: state.revision,
  commitOrdinal: state.commitOrdinal,
  history: state.history,
  activities: activities ?? state.activities,
  mistakes: mistakes ?? state.mistakes,
  summaries: summaries ?? state.summaries,
  completions: completions ?? state.completions,
  bestScores: bestScores ?? state.bestScores,
  pending: state.pending,
);

int _courseAggregateCount(CourseLearningState state, String aggregate) =>
    switch (aggregate) {
      'activities' => state.activities.length,
      'mistakes' => state.mistakes.length,
      'summaries' => state.summaries.length,
      'completions' => state.completions.length,
      'bestScores' => state.bestScores.length,
      'exposure' => state.activities.values.fold<int>(
        0,
        (int total, ActivitySlot slot) => total + slot.exposures.length,
      ),
      _ => throw ArgumentError.value(aggregate, 'aggregate'),
    };

String _courseSqlTableFor(String aggregate) => switch (aggregate) {
  'activities' => 'learning_runs',
  'mistakes' => 'learning_mistakes',
  'summaries' => 'learning_summaries',
  'completions' => 'learning_completions',
  'bestScores' => 'learning_best_scores',
  'exposure' => 'learning_exposure',
  _ => throw ArgumentError.value(aggregate, 'aggregate'),
};

int _expectedCourseSqlRows(String aggregate, int typedIdentities) =>
    switch (aggregate) {
      'activities' ||
      'mistakes' ||
      'summaries' ||
      'completions' ||
      'bestScores' ||
      'exposure' => typedIdentities,
      _ => throw ArgumentError.value(aggregate, 'aggregate'),
    };

int _expectedSentenceSqlRows(String aggregate, int typedIdentities) =>
    switch (aggregate) {
      // Sentence summaries persist one row for each of four typed buckets.
      'summaries' => typedIdentities * 4,
      'mistakes' || 'completions' || 'teachingExposure' => typedIdentities,
      _ => throw ArgumentError.value(aggregate, 'aggregate'),
    };

String _courseOverflowIdentity(
  String aggregate,
  _CourseOverflowFixture fixture,
) => switch (aggregate) {
  'activities' => fixture.activeActivityId,
  'mistakes' => '${fixture.activeActivityId}/task9-course-active-item',
  'summaries' => _syntheticSound(32),
  'completions' => fixture.activeActivityId,
  'bestScores' => fixture.activeActivityId,
  'exposure' => 'task9-synthetic-discovery-item-0',
  _ => throw ArgumentError.value(aggregate, 'aggregate'),
};

LearningCommand _courseOverflowCommand(
  SqliteCourseLearningRepository repository,
  _CourseOverflowFixture fixture,
  CourseLearningState state,
) {
  final String activityId = fixture.activeActivityId;
  final LearningAction action = switch (fixture.aggregate) {
    'activities' => StartLearningRun(options: RunOptions()),
    'mistakes' || 'summaries' => _wrongCourseAnswer(
      fixture.registry.require(activityId).items.single,
    ),
    'completions' => const FinishLearningActivity(),
    'bestScores' => LinkWordTiles(
      indices: _wordGameScoringChain(state, activityId),
    ),
    'exposure' => ObserveAssistance(
      items: <ItemContextKey>{
        ItemContextKey(
          itemId: 'task9-synthetic-discovery-item-0',
          targetSound: _syntheticSound(0),
        ),
      },
      flags: const <AssistanceFlag>{AssistanceFlag.explanationVisible},
    ),
    _ => throw ArgumentError.value(fixture.aggregate, 'aggregate'),
  };
  return repository.prepare(
    state: state,
    activityId: activityId,
    action: action,
  );
}

LearningAction _wrongCourseAnswer(LearningSourceItem item) => ChooseSound(
  selectedSound: item.choices.firstWhere(
    (String choice) => choice != item.expectedChoice,
  ),
  audioSource: authoredAudioSource(item)!,
);

List<int> _wordGameScoringChain(CourseLearningState state, String activityId) {
  final WordGameCheckpoint checkpoint =
      state.activities[activityId]!.snapshot as WordGameCheckpoint;
  final List<int> chain = WordMatchEngine.fromState(
    checkpoint.board,
    random: Random(19),
  ).findChain();
  if (chain.length < 3) {
    throw StateError('Synthetic word-game board has no scoring chain.');
  }
  return chain;
}

SqliteCourseLearningRepository _courseOverflowRepository(
  LearningDatabaseHandle handle,
  _CourseOverflowFixture fixture,
) {
  var tokenCounter = 0;
  return SqliteCourseLearningRepository(
    database: handle,
    scope: fixture.scope,
    authGeneration: 0,
    currentAuth: () => LearningAuthScope(
      owner: fixture.scope.owner,
      generation: 0,
      ready: true,
    ),
    backendOwner: () => fixture.scope.owner,
    transitions: fixture.transitions,
    clock: () => DateTime.utc(2026, 10, 19, 12),
    newToken: () => _courseToken(++tokenCounter, prefix: 'r'),
    random: Random(23),
  );
}

Future<Map<String, Object?>> _qualifySentenceHuntSqlOverflow(
  String aggregate,
) async {
  final Directory directory = await Directory.systemTemp.createTemp(
    'sqlite-sentence-$aggregate-overflow-',
  );
  final File file = File('${directory.path}/learning.sqlite');
  final LearningDatabaseHandle primary = _fileHandle(file);
  final LearningDatabaseHandle independent = _fileHandle(file);
  try {
    final _SyntheticSentenceAggregateFixture fixture =
        _syntheticSentenceAggregateFixture();
    final _SentenceOverflowFixture controlFixture = await _seedSentenceOverflow(
      primary,
      catalogue: fixture.catalogue,
      aggregate: aggregate,
      count: 4095,
      label: 'control',
    );
    await primary.reopen();
    final SqliteSentenceHuntLearningRepository controlRepository =
        _sentenceOverflowRepository(primary, controlFixture);
    final SentenceHuntLearningState controlBefore = await controlRepository
        .load();
    SentenceHuntLearningStateValidator.validate(
      controlBefore,
      controlFixture.catalogue,
    );
    expect(_sentenceAggregateCount(controlBefore, aggregate), 4095);
    final _SqlScopedSnapshot controlSeedSnapshot =
        await _captureSqlScopedSnapshot(
          await primary.open(),
          controlFixture.scopeId,
        );
    expect(
      controlSeedSnapshot.rowCounts[_sentenceSqlTableFor(aggregate)],
      _expectedSentenceSqlRows(aggregate, 4095),
    );
    final SentenceHuntAction controlAction = _sentenceOverflowAction(
      controlBefore,
      controlFixture,
    );
    final SentenceHuntLearningCommand controlCommand = controlRepository
        .prepare(
          state: controlBefore,
          sectionId: controlFixture.sectionId,
          action: controlAction,
        );
    await controlRepository.submit(controlCommand);
    await primary.reopen();
    final SentenceHuntLearningState controlAfter = await controlRepository
        .load();
    SentenceHuntLearningStateValidator.validate(
      controlAfter,
      controlFixture.catalogue,
    );
    expect(_sentenceAggregateCount(controlAfter, aggregate), 4096);
    final _SqlScopedSnapshot controlSnapshot = await _captureSqlScopedSnapshot(
      await primary.open(),
      controlFixture.scopeId,
    );
    expect(
      controlSnapshot.rowCounts[_sentenceSqlTableFor(aggregate)],
      _expectedSentenceSqlRows(aggregate, 4096),
    );

    final _SentenceOverflowFixture overflowFixture =
        await _seedSentenceOverflow(
          primary,
          catalogue: fixture.catalogue,
          aggregate: aggregate,
          count: 4096,
          label: 'overflow',
        );
    await primary.reopen();
    final SqliteSentenceHuntLearningRepository overflowRepository =
        _sentenceOverflowRepository(primary, overflowFixture);
    final SentenceHuntLearningState loaded = await overflowRepository.load();
    SentenceHuntLearningStateValidator.validate(
      loaded,
      overflowFixture.catalogue,
    );
    expect(_sentenceAggregateCount(loaded, aggregate), 4096);
    final _SqlScopedSnapshot before = await _captureSqlScopedSnapshot(
      await primary.open(),
      overflowFixture.scopeId,
    );
    expect(
      before.rowCounts[_sentenceSqlTableFor(aggregate)],
      _expectedSentenceSqlRows(aggregate, 4096),
    );
    final SentenceHuntAction overflowAction = _sentenceOverflowAction(
      loaded,
      overflowFixture,
    );
    final SentenceHuntLearningCommand overflowCommand = _sentenceCommand(
      overflowFixture.catalogue,
      overflowFixture.scope,
      loaded,
      overflowFixture.sectionId,
      overflowAction,
    );
    late final LearningInvalidCommandException typedError;
    try {
      await overflowRepository.submit(overflowCommand);
      fail('A valid distinct 4097th $aggregate identity must be rejected.');
    } on LearningInvalidCommandException catch (error) {
      typedError = error;
    }
    expect(typedError.cause, isA<SentenceHuntCapacityException>());
    final SentenceHuntCapacityException capacity =
        typedError.cause! as SentenceHuntCapacityException;
    expect(capacity.aggregate, aggregate);
    expect(capacity.limit, 4096);

    await primary.close();
    await independent.reopen();
    final SqliteSentenceHuntLearningRepository reopenedRepository =
        _sentenceOverflowRepository(independent, overflowFixture);
    final SentenceHuntLearningState reopened = await reopenedRepository.load();
    SentenceHuntLearningStateValidator.validate(
      reopened,
      overflowFixture.catalogue,
    );
    final _SqlScopedSnapshot after = await _captureSqlScopedSnapshot(
      await independent.open(),
      overflowFixture.scopeId,
    );
    final bool unchanged = before.normalizedRows == after.normalizedRows;
    expect(unchanged, isTrue);
    expect(_sentenceAggregateCount(reopened, aggregate), 4096);
    expect(
      after.rowCounts[_sentenceSqlTableFor(aggregate)],
      _expectedSentenceSqlRows(aggregate, 4096),
    );

    final Map<String, Object?> evidence = <String, Object?>{
      'family': 'sentence-hunt',
      'collection': aggregate,
      'controlSeedTypedIdentities': 4095,
      'controlSeedSqlRows':
          controlSeedSnapshot.rowCounts[_sentenceSqlTableFor(aggregate)],
      'controlCommittedBelowCap': true,
      'controlLoadedTypedIdentitiesAfterCommit': _sentenceAggregateCount(
        controlAfter,
        aggregate,
      ),
      'controlSqlRowsAfterCommit':
          controlSnapshot.rowCounts[_sentenceSqlTableFor(aggregate)],
      'controlCommand': <String, Object?>{
        'action': controlCommand.action.runtimeType.toString(),
        'sectionId': controlCommand.sectionId,
        'expectedScopeRevision': controlCommand.expectedScopeRevision,
        'expectedCursor': <String, int>{
          'generation': controlCommand.expected.generation,
          'sequence': controlCommand.expected.sequence,
          'revision': controlCommand.expected.revision,
        },
        'token': controlCommand.token,
      },
      'controlSeedHeader': <String, Object?>{
        'revision': controlSeedSnapshot.header['revision'],
        'commitOrdinal': controlSeedSnapshot.header['commit_ordinal'],
      },
      'controlHeaderAfterCommit': <String, Object?>{
        'revision': controlSnapshot.header['revision'],
        'commitOrdinal': controlSnapshot.header['commit_ordinal'],
      },
      'loadedTypedIdentitiesBeforeOverflow': _sentenceAggregateCount(
        loaded,
        aggregate,
      ),
      'sqlRowsBeforeOverflow':
          before.rowCounts[_sentenceSqlTableFor(aggregate)],
      'overflowIdentity': _sentenceOverflowIdentity(aggregate, overflowFixture),
      'overflowCommand': <String, Object?>{
        'action': overflowCommand.action.runtimeType.toString(),
        'sectionId': overflowCommand.sectionId,
        'expectedScopeRevision': overflowCommand.expectedScopeRevision,
        'expectedCursor': <String, int>{
          'generation': overflowCommand.expected.generation,
          'sequence': overflowCommand.expected.sequence,
          'revision': overflowCommand.expected.revision,
        },
        'token': overflowCommand.token,
      },
      'typedError': typedError.runtimeType.toString(),
      'typedErrorCause': capacity.runtimeType.toString(),
      'capacityAggregate': capacity.aggregate,
      'capacityLimit': capacity.limit,
      'typedCapacityRejected': true,
      'normalizedRowCountsBefore': before.rowCounts,
      'normalizedRowCountsAfterIndependentReopen': after.rowCounts,
      'headerBefore': <String, Object?>{
        'revision': before.header['revision'],
        'commitOrdinal': before.header['commit_ordinal'],
      },
      'headerAfter': <String, Object?>{
        'revision': after.header['revision'],
        'commitOrdinal': after.header['commit_ordinal'],
      },
      'normalizedSnapshotBytes': utf8.encode(before.normalizedRows).length,
      'normalizedSnapshotUnchangedAfterIndependentReopen': unchanged,
    };
    // ignore: avoid_print
    print('TASK9 SQL OVERFLOW ${jsonEncode(evidence)}');
    return evidence;
  } finally {
    await primary.close();
    await independent.close();
    await directory.delete(recursive: true);
  }
}

final class _SentenceOverflowFixture {
  const _SentenceOverflowFixture({
    required this.scope,
    required this.scopeId,
    required this.catalogue,
    required this.transitions,
    required this.aggregate,
    required this.count,
    required this.sectionId,
  });

  final SentenceHuntProfileScope scope;
  final int scopeId;
  final SentenceHuntCatalogue catalogue;
  final SentenceHuntTransitionEngine transitions;
  final String aggregate;
  final int count;
  final String sectionId;
}

SentenceHuntProfileScope _sentenceOverflowScope(
  String aggregate,
  String label,
) => SentenceHuntProfileScope(
  courseId: 'en-fr',
  owner: LearningOwner.account('task9-sentence-sql-$aggregate-$label'),
);

Future<_SentenceOverflowFixture> _seedSentenceOverflow(
  LearningDatabaseHandle handle, {
  required SentenceHuntCatalogue catalogue,
  required String aggregate,
  required int count,
  required String label,
}) async {
  final String sectionId = catalogue.sections.first.id;
  final SentenceHuntProfileScope scope = _sentenceOverflowScope(
    aggregate,
    label,
  );
  final SentenceHuntTransitionEngine transitions = SentenceHuntTransitionEngine(
    catalogue: catalogue,
  );
  final SentenceHuntLearningSqlAdapter adapter = SentenceHuntLearningSqlAdapter(
    scope: scope,
    transitions: transitions,
    historyLimit: 2000,
  );
  final LearningDatabase database = await handle.open();
  final int scopeId = await database.ensureScope(adapter.scope);
  var state = SentenceHuntLearningState.empty(scope);

  await database.transaction(() async {
    final SentenceHuntLearningCommand startCommand = _prepareSentenceSqlSeed(
      transitions,
      state,
      sectionId,
      StartSentenceHuntRun(
        sessionId: 'task9-sql-$aggregate-$label-start',
        policy: catalogue.section(sectionId).policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );
    SentenceHuntLearningState started = _evaluateSentenceCommand(
      transitions,
      state,
      startCommand,
    );
    if (aggregate == 'mistakes' || aggregate == 'summaries') {
      started = _sentenceStateAtSingleAggregateLimit(
        started,
        _SyntheticSentenceAggregateFixture(catalogue, sectionId),
        aggregate,
        identityCount: count,
      );
      await _persistSentenceSeedTransition(
        database,
        adapter,
        scopeId,
        state,
        startCommand,
        started,
      );
      state = started;
    } else {
      await _persistSentenceSeedTransition(
        database,
        adapter,
        scopeId,
        state,
        startCommand,
        started,
      );
      state = started;
      final SentenceHuntSection section = catalogue.section(sectionId);
      for (int index = 0; index < section.items.length; index++) {
        final LessonSectionSession session = _sentenceSession(state, section);
        final SentenceHuntItem item = catalogue.item(
          sectionId,
          session.currentItemId!,
        );
        final SentenceHuntCommandAndState answer = _sentenceSeedTransition(
          transitions,
          state,
          sectionId,
          AnswerSentenceHuntItem(
            _sentenceAnswer(item, state, session, correct: true),
          ),
        );
        SentenceHuntLearningState answerAfter = answer.state;
        if (aggregate == 'teachingExposure' &&
            index == section.items.length - 1) {
          answerAfter = _sentenceStateAtSingleAggregateLimit(
            answerAfter,
            _SyntheticSentenceAggregateFixture(catalogue, sectionId),
            aggregate,
            identityCount: count,
          );
        }
        await _persistSentenceSeedTransition(
          database,
          adapter,
          scopeId,
          state,
          answer.command,
          answerAfter,
        );
        state = answerAfter;
        if (index < section.items.length - 1) {
          final SentenceHuntCommandAndState advance = _sentenceSeedTransition(
            transitions,
            state,
            sectionId,
            const AdvanceSentenceHuntItem(),
          );
          await _persistSentenceSeedTransition(
            database,
            adapter,
            scopeId,
            state,
            advance.command,
            advance.state,
          );
          state = advance.state;
        }
      }
      if (aggregate == 'completions') {
        final SentenceHuntCommandAndState debrief = _sentenceSeedTransition(
          transitions,
          state,
          sectionId,
          const AdvanceSentenceHuntItem(),
        );
        final SentenceHuntLearningState capped =
            _sentenceStateAtSingleAggregateLimit(
              debrief.state,
              _SyntheticSentenceAggregateFixture(catalogue, sectionId),
              aggregate,
              identityCount: count,
            );
        await _persistSentenceSeedTransition(
          database,
          adapter,
          scopeId,
          state,
          debrief.command,
          capped,
        );
        state = capped;
      }
    }
    SentenceHuntLearningStateValidator.validate(state, catalogue);
  });

  return _SentenceOverflowFixture(
    scope: scope,
    scopeId: scopeId,
    catalogue: catalogue,
    transitions: transitions,
    aggregate: aggregate,
    count: count,
    sectionId: sectionId,
  );
}

final class SentenceHuntCommandAndState {
  const SentenceHuntCommandAndState(this.command, this.state);

  final SentenceHuntLearningCommand command;
  final SentenceHuntLearningState state;
}

SentenceHuntCommandAndState _sentenceSeedTransition(
  SentenceHuntTransitionEngine transitions,
  SentenceHuntLearningState before,
  String sectionId,
  SentenceHuntAction action,
) {
  final SentenceHuntLearningCommand command = _prepareSentenceSqlSeed(
    transitions,
    before,
    sectionId,
    action,
  );
  return SentenceHuntCommandAndState(
    command,
    _evaluateSentenceCommand(transitions, before, command),
  );
}

SentenceHuntLearningCommand _prepareSentenceSqlSeed(
  SentenceHuntTransitionEngine transitions,
  SentenceHuntLearningState state,
  String sectionId,
  SentenceHuntAction action,
) => transitions.prepare(
  state: state,
  sectionId: sectionId,
  action: action,
  authGeneration: 0,
  token: _sentenceToken(state.commitOrdinal + 1),
  submittedAt: _sentenceTime(state.commitOrdinal + 1),
);

SentenceHuntLearningState _evaluateSentenceCommand(
  SentenceHuntTransitionEngine transitions,
  SentenceHuntLearningState state,
  SentenceHuntLearningCommand command,
) => transitions
    .evaluate(state: state, command: command, committedAt: command.submittedAt)
    .nextState;

Future<void> _persistSentenceSeedTransition(
  LearningDatabase database,
  SentenceHuntLearningSqlAdapter adapter,
  int scopeId,
  SentenceHuntLearningState before,
  SentenceHuntLearningCommand command,
  SentenceHuntLearningState after,
) async {
  await adapter.persist(database, scopeId, before, command, after);
  final int changedRows = await database.compareAndSwapLearningScope(
    scopeId: scopeId,
    expectedRevision: before.revision,
    expectedCommitOrdinal: before.commitOrdinal,
    nextRevision: after.revision,
    nextCommitOrdinal: after.commitOrdinal,
  );
  expect(changedRows, 1);
}

SentenceHuntLearningState _copySentenceState(
  SentenceHuntLearningState state, {
  Map<SentenceHuntMistakeKey, SentenceHuntMistake>? mistakes,
  Map<SentenceHuntSummaryKey, SentenceHuntSummary>? summaries,
  List<SentenceHuntCompletion>? completions,
  Set<SentenceHuntExposureKey>? teachingExposure,
}) => SentenceHuntLearningState(
  scope: state.scope,
  revision: state.revision,
  commitOrdinal: state.commitOrdinal,
  slots: state.slots,
  attempts: state.attempts,
  receipts: state.receipts,
  mistakes: mistakes ?? state.mistakes,
  summaries: summaries ?? state.summaries,
  completions: completions ?? state.completions,
  teachingExposure: teachingExposure ?? state.teachingExposure,
);

int _sentenceAggregateCount(
  SentenceHuntLearningState state,
  String aggregate,
) => switch (aggregate) {
  'mistakes' => state.mistakes.length,
  'summaries' => state.summaries.length,
  'completions' => state.completions.length,
  'teachingExposure' => state.teachingExposure.length,
  _ => throw ArgumentError.value(aggregate, 'aggregate'),
};

String _sentenceSqlTableFor(String aggregate) => switch (aggregate) {
  'mistakes' => 'learning_mistakes',
  'summaries' => 'learning_summaries',
  'completions' => 'learning_completions',
  'teachingExposure' => 'learning_exposure',
  _ => throw ArgumentError.value(aggregate, 'aggregate'),
};

String _sentenceOverflowIdentity(
  String aggregate,
  _SentenceOverflowFixture fixture,
) => switch (aggregate) {
  'mistakes' || 'summaries' =>
    '${fixture.sectionId}/${fixture.catalogue.sections.first.items.first.identity.itemId}/4097',
  'completions' => '${fixture.sectionId}/4097/1/80',
  'teachingExposure' => '${fixture.sectionId}/4097',
  _ => throw ArgumentError.value(aggregate, 'aggregate'),
};

SentenceHuntAction _sentenceOverflowAction(
  SentenceHuntLearningState state,
  _SentenceOverflowFixture fixture,
) => switch (fixture.aggregate) {
  'mistakes' || 'summaries' => _wrongAnswerAction(
    fixture.catalogue,
    state,
    fixture.sectionId,
  ),
  'completions' => const FinishSentenceHuntRun(),
  'teachingExposure' => const AdvanceSentenceHuntItem(),
  _ => throw ArgumentError.value(fixture.aggregate, 'aggregate'),
};

SqliteSentenceHuntLearningRepository _sentenceOverflowRepository(
  LearningDatabaseHandle handle,
  _SentenceOverflowFixture fixture,
) {
  var tokenCounter = 0;
  return SqliteSentenceHuntLearningRepository(
    database: handle,
    scope: fixture.scope,
    authGeneration: 0,
    currentAuth: () => LearningAuthScope(
      owner: fixture.scope.owner,
      generation: 0,
      ready: true,
    ),
    backendOwner: () => fixture.scope.owner,
    transitions: fixture.transitions,
    clock: () => DateTime.utc(2026, 10, 19, 12),
    newToken: () => _sentenceToken(++tokenCounter + 900000),
  );
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

LearningActivityDefinition _syntheticWordGameDefinition(
  int index, {
  List<LearningSourceItem> items = const <LearningSourceItem>[],
}) => LearningActivityDefinition(
  id: _syntheticWordGameId(index),
  kind: LearningActivityKind.wordGame,
  contentRevision: 1,
  items: items,
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
  String aggregate, {
  int identityCount = 4096,
}) {
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

  for (int revision = 1; revision <= identityCount; revision++) {
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

  return _copySentenceState(
    state,
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
