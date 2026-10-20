// Progress and evidence output is retained in the qualification run logs.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_learning_command_codec.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/course_skill_summary.dart';
import 'package:linguist/src/core/course/comparison_learning_store.dart'
    show ComparisonCommit;
import 'package:linguist/src/core/course/french_course.dart' show wordByText;
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_store.dart'
    show SentenceHuntCommit;
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_command_codec.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_adapter.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/learning_sql_transaction.dart';
import 'package:linguist/src/core/course/storage/learning_storage_scope.dart';
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_command_codec.dart';
import 'package:linguist/src/features/arcade/word_match_engine.dart';

import '../../test/support/sentence_hunt_fixtures.dart';

const int _retainedRows = 2000;
const String _courseActivityId = 'lesson:en-fr-u-y';
const String _courseGameActivityId = 'arcade:word';
const int learningQualificationAuthGeneration = 17;

const Map<String, String>
learningOverflowQualificationStatusByFamily = <String, String>{
  'course':
      'OPEN — SQL-backed 4,096/4,097 atomicity is not qualified. '
      'Validator-only synthetic tests cover activities, mistakes, '
      'summaries, completions, best scores, and exposure; they do not '
      'persist rows or prove SQLite overflow rollback. A repository-backed '
      'proof needs thousands of valid transitions because the public '
      'command path has no multi-identity seed operation; the prior 2,000 '
      'course fixture took 249,343 ms, so that route was not safely bounded '
      'for this unit.',
  'comparison':
      'OPEN — the public comparison catalogue requires exactly 10 '
      'exercises, so a valid 4,097th pair identity cannot be constructed '
      'without changing production content or validation. Its constructor '
      'is private and the public validator rejects non-10 catalogues. SQL '
      'overflow atomicity is not demonstrated; the controller must resolve '
      'this acceptance conflict.',
  'sentence-hunt':
      'OPEN — SQL-backed 4,096/4,097 atomicity is not qualified. Synthetic '
      'validator and SQL-adapter evaluation tests exercise valid aggregate '
      'identities in memory but do not persist rows or prove SQLite '
      'overflow rollback. The current valid synthetic catalogue has 15 '
      'items; a SQL proof needs a validator-accepted 4,097-identity fixture '
      'and thousands of repository answer commits. One valid answer submit '
      'on the retained 786-attempt copy took 2,299 ms, so that route was '
      'not safely bounded for this unit.',
};

final Map<String, Map<String, int>> _lastSeedDurations =
    <String, Map<String, int>>{};
final Map<String, Map<String, Map<String, Object?>>>
_postCapPruneEvidenceByRun = <String, Map<String, Map<String, Object?>>>{};

final class LearningWorkloadReport {
  const LearningWorkloadReport({
    required this.rowCountsByFamily,
    required this.summaryValuesByFamily,
    required this.latestReceiptByFamily,
    required this.cursorValuesByFamily,
    required this.logicalPageBytesByFamily,
    required this.durationsMillisecondsByFamily,
    required this.pruneResultByFamily,
    required this.overflowResultByFamily,
    required this.postCapPruneEvidenceByFamily,
  });

  final Map<String, Map<String, int>> rowCountsByFamily;
  final Map<String, Map<String, int>> summaryValuesByFamily;
  final Map<String, String> latestReceiptByFamily;
  final Map<String, Object?> cursorValuesByFamily;
  final Map<String, int> logicalPageBytesByFamily;
  final Map<String, Map<String, int>> durationsMillisecondsByFamily;
  final Map<String, String> pruneResultByFamily;
  final Map<String, String> overflowResultByFamily;
  final Map<String, Map<String, Object?>> postCapPruneEvidenceByFamily;

  Map<String, Object?> toJson() => <String, Object?>{
    'rowCountsByFamily': rowCountsByFamily,
    'summaryValuesByFamily': summaryValuesByFamily,
    'latestReceiptByFamily': latestReceiptByFamily,
    'cursorValuesByFamily': cursorValuesByFamily,
    'logicalPageBytesByFamily': logicalPageBytesByFamily,
    'durationsMillisecondsByFamily': durationsMillisecondsByFamily,
    'pruneResultByFamily': pruneResultByFamily,
    'overflowResultByFamily': overflowResultByFamily,
    'postCapPruneEvidenceByFamily': postCapPruneEvidenceByFamily,
  };
}

/// Shared exact gate for per-family `observed` and default report status.
bool learningPostCapPruneObservedFromEvidence(Map<String, Object?>? evidence) =>
    evidence != null &&
    evidence['basePrunePredicatesPassed'] == true &&
    evidence['receiptExpectedIdentityMatch'] == true &&
    evidence['receiptPrunePreservedExpectedIdentities'] == true &&
    evidence['currentRunLatestReceiptPersisted'] == true;

final class LearningRecoveryEvidence {
  const LearningRecoveryEvidence({
    required this.failedWritesRolledBack,
    required this.rowValuesBeforeFailureByFamily,
    required this.rowValuesAfterRollbackByFamily,
    required this.duplicateReplayDidNotAddAttempts,
    required this.attemptCountAfterFirstCommit,
    required this.outboxRowsAfterReplay,
    required this.frozenCommandPayloads,
    required this.canonicalPayloadBytesIdenticalByFamily,
    required this.replayedWithDecodedCommandByFamily,
    required this.normalizedRowsAfterFirstCommitByFamily,
    required this.normalizedRowsAfterReplayByFamily,
    required this.normalizedRowCountsAfterFirstCommitByFamily,
    required this.normalizedRowCountsAfterReplayByFamily,
  });

  final Map<String, bool> failedWritesRolledBack;
  final Map<String, String> rowValuesBeforeFailureByFamily;
  final Map<String, String> rowValuesAfterRollbackByFamily;
  final Map<String, bool> duplicateReplayDidNotAddAttempts;
  final Map<String, int> attemptCountAfterFirstCommit;
  final int outboxRowsAfterReplay;
  final Map<String, String> frozenCommandPayloads;
  final Map<String, bool> canonicalPayloadBytesIdenticalByFamily;
  final Map<String, bool> replayedWithDecodedCommandByFamily;
  final Map<String, String> normalizedRowsAfterFirstCommitByFamily;
  final Map<String, String> normalizedRowsAfterReplayByFamily;
  final Map<String, Map<String, int>>
  normalizedRowCountsAfterFirstCommitByFamily;
  final Map<String, Map<String, int>> normalizedRowCountsAfterReplayByFamily;

  Map<String, Object?> toJson() => <String, Object?>{
    'failedWritesRolledBack': failedWritesRolledBack,
    'rowValuesBeforeFailureByFamily': rowValuesBeforeFailureByFamily,
    'rowValuesAfterRollbackByFamily': rowValuesAfterRollbackByFamily,
    'duplicateReplayDidNotAddAttempts': duplicateReplayDidNotAddAttempts,
    'attemptCountAfterFirstCommit': attemptCountAfterFirstCommit,
    'outboxRowsAfterReplay': outboxRowsAfterReplay,
    'frozenCommandPayloads': frozenCommandPayloads,
    'canonicalPayloadBytesIdenticalByFamily':
        canonicalPayloadBytesIdenticalByFamily,
    'replayedWithDecodedCommandByFamily': replayedWithDecodedCommandByFamily,
    'normalizedRowsAfterFirstCommitByFamily':
        normalizedRowsAfterFirstCommitByFamily,
    'normalizedRowsAfterReplayByFamily': normalizedRowsAfterReplayByFamily,
    'normalizedRowCountsAfterFirstCommitByFamily':
        normalizedRowCountsAfterFirstCommitByFamily,
    'normalizedRowCountsAfterReplayByFamily':
        normalizedRowCountsAfterReplayByFamily,
  };
}

final class LearningRecoveryControlEvidence {
  const LearningRecoveryControlEvidence({
    required this.changedPayloadRejected,
    required this.changedPayloadDidNotRewrite,
    required this.changedContentRejectedWithoutRewrite,
    required this.changedPolicyRejectedWithoutRewrite,
    required this.unknownVersionRejectedWithoutRewrite,
    required this.unknownAckDidNotWrite,
  });

  final bool changedPayloadRejected;
  final bool changedPayloadDidNotRewrite;
  final bool changedContentRejectedWithoutRewrite;
  final bool changedPolicyRejectedWithoutRewrite;
  final bool unknownVersionRejectedWithoutRewrite;
  final bool unknownAckDidNotWrite;
}

/// Shared deterministic workload for file tests, native/web integration tests,
/// and the test-only same-origin qualification app.
Future<void> seedLearningAtRetentionLimits(
  LearningDatabaseHandle handle, {
  required String runId,
  int historyLimit = _retainedRows,
}) async {
  final _WorkloadHarness harness = _WorkloadHarness(
    runId,
    historyLimit: historyLimit,
  );
  await _seedCourse(handle, harness);
  await _seedComparison(handle, harness);
  await _seedSentenceHunt(handle, harness);
  _postCapPruneEvidenceByRun[runId] = await _exercisePostCapPruning(
    handle,
    harness,
  );
}

/// Loads every family through its production repository and reports normalized
/// row counts and typed aggregate values. Page bytes are database-wide logical
/// SQLite page size × page count, not a quota or device-capacity guarantee.
Future<LearningWorkloadReport> verifyLearningAtRetentionLimits(
  LearningDatabaseHandle handle, {
  required String runId,
  int historyLimit = _retainedRows,
}) async {
  final _WorkloadHarness harness = _WorkloadHarness(
    runId,
    historyLimit: historyLimit,
  );
  final Stopwatch openWatch = Stopwatch()..start();
  final LearningDatabase database = await handle.open();
  openWatch.stop();

  final Map<String, Map<String, int>> rowCounts = <String, Map<String, int>>{};
  final Map<String, Map<String, int>> summaryValues =
      <String, Map<String, int>>{};
  final Map<String, String> latestReceipts = <String, String>{};
  final Map<String, Object?> cursorValues = <String, Object?>{};
  final Map<String, int> loadMilliseconds = <String, int>{};

  final Stopwatch courseLoad = Stopwatch()..start();
  final CourseLearningState courseState = await harness
      .courseRepository(handle)
      .load();
  courseLoad.stop();
  loadMilliseconds['course'] = courseLoad.elapsedMilliseconds;
  final LearningStorageScope courseScope = harness.courseStorageScope;
  rowCounts['course'] = await _readRowCounts(
    database,
    courseScope,
    family: 'course',
  );
  summaryValues['course'] = _courseSummaryValues(courseState);
  latestReceipts['course'] = _courseLatestReceipt(courseState);
  cursorValues['course'] = _courseCursorValues(courseState);

  final Stopwatch comparisonLoad = Stopwatch()..start();
  final ComparisonLearningState comparisonState = await harness
      .comparisonRepository(handle)
      .load();
  comparisonLoad.stop();
  loadMilliseconds['comparison'] = comparisonLoad.elapsedMilliseconds;
  rowCounts['comparison'] = await _readRowCounts(
    database,
    harness.comparisonStorageScope,
    family: 'comparison',
  );
  summaryValues['comparison'] = _comparisonSummaryValues(comparisonState);
  latestReceipts['comparison'] =
      comparisonState.slot?.latestReceipt.token ?? 'missing';
  cursorValues['comparison'] = _comparisonCursorValues(comparisonState);

  final Stopwatch sentenceLoad = Stopwatch()..start();
  final SentenceHuntLearningState sentenceState = await harness
      .sentenceHuntRepository(handle)
      .load();
  sentenceLoad.stop();
  loadMilliseconds['sentence-hunt'] = sentenceLoad.elapsedMilliseconds;
  rowCounts['sentence-hunt'] = await _readRowCounts(
    database,
    harness.sentenceStorageScope,
    family: 'sentence-hunt',
  );
  summaryValues['sentence-hunt'] = _sentenceSummaryValues(sentenceState);
  latestReceipts['sentence-hunt'] = _sentenceLatestReceipt(sentenceState);
  cursorValues['sentence-hunt'] = _sentenceCursorValues(sentenceState);

  final int pageBytes = await _logicalPageBytes(database);
  final Map<String, int> databaseOpenDurations = <String, int>{
    for (final String family in _families)
      family: openWatch.elapsedMilliseconds,
  };
  final Map<String, int> pageBytesByFamily = <String, int>{
    for (final String family in _families) family: pageBytes,
  };
  final Map<String, Map<String, int>> durations = <String, Map<String, int>>{
    for (final String family in _families)
      family: <String, int>{
        'openMilliseconds': databaseOpenDurations[family]!,
        'loadMilliseconds': loadMilliseconds[family]!,
        'writeMilliseconds': _lastSeedDurations[runId]?['$family-write'] ?? -1,
      },
  };

  final Map<String, Map<String, Object?>>? postCapEvidence =
      _postCapPruneEvidenceByRun[runId];
  final Map<String, String> pruneResults = <String, String>{
    for (final String family in _families)
      family: learningPostCapPruneObservedFromEvidence(postCapEvidence?[family])
          ? 'OBSERVED post-cap write/prune '
                'attempts before/after='
                '${postCapEvidence![family]!['attemptCountBefore']}/'
                '${postCapEvidence[family]!['attemptCountAfter']}; '
                'retained attempts=${rowCounts[family]!['attempts']}, '
                'retained receipts=${rowCounts[family]!['receipts']}, '
                'typed summaries/mistakes/completions/exposure reloaded; '
                'latest receipt proof=${latestReceipts[family]}'
          : postCapEvidence?[family] == null
          ? 'OPEN — post-cap prune was not observed in this process/run; '
                'retained attempts=${rowCounts[family]!['attempts']}, '
                'retained receipts=${rowCounts[family]!['receipts']}, '
                'latest receipt proof=${latestReceipts[family]}'
          : 'OPEN — post-cap evidence exists but exact receipt or aggregate '
                'proof is incomplete; latest receipt proof=${latestReceipts[family]}',
  };
  return LearningWorkloadReport(
    rowCountsByFamily: rowCounts,
    summaryValuesByFamily: summaryValues,
    latestReceiptByFamily: latestReceipts,
    cursorValuesByFamily: cursorValues,
    logicalPageBytesByFamily: pageBytesByFamily,
    durationsMillisecondsByFamily: durations,
    pruneResultByFamily: pruneResults,
    overflowResultByFamily: learningOverflowQualificationStatusByFamily,
    postCapPruneEvidenceByFamily:
        postCapEvidence ?? const <String, Map<String, Object?>>{},
  );
}

Future<Map<String, Map<String, Object?>>> _exercisePostCapPruning(
  LearningDatabaseHandle handle,
  _WorkloadHarness harness,
) async => <String, Map<String, Object?>>{
  'course': await _exerciseCoursePostCapPrune(handle, harness),
  'comparison': await _exerciseComparisonPostCapPrune(handle, harness),
  'sentence-hunt': await _exerciseSentencePostCapPrune(handle, harness),
};

Future<Map<String, Object?>> _exerciseCoursePostCapPrune(
  LearningDatabaseHandle handle,
  _WorkloadHarness harness,
) async {
  final SqliteCourseLearningRepository repository = harness.courseRepository(
    handle,
  );
  final CourseLearningState beforeState = await repository.load();
  final LearningDatabase database = await handle.open();
  final int attemptCountBefore = await _rowCount(
    database,
    'learning_attempts',
    harness.courseStorageScope,
  );
  final int receiptCountBefore = await _rowCount(
    database,
    'learning_command_receipts',
    harness.courseStorageScope,
  );
  final List<String> receiptIdsBefore = await _receiptIdentities(
    database,
    harness.courseStorageScope,
  );
  final Map<String, int> aggregateBefore = _courseSummaryValues(beforeState);
  final Map<String, List<String>> aggregateSqlBefore = await _aggregateSqlRows(
    database,
    harness.courseStorageScope,
  );
  final List<Map<String, Object?>> sqlBefore = await _attemptRows(
    database,
    harness.courseStorageScope,
  );
  final List<String> expectedNewCommandReceipts = <String>[];
  var state = await _startCourseWordGame(
    repository,
    beforeState,
    receiptTrace: expectedNewCommandReceipts,
  );
  List<int>? chain;
  for (var restart = 0; restart < 100 && chain == null; restart++) {
    final WordGameCheckpoint checkpoint =
        state.activities[_courseGameActivityId]!.snapshot as WordGameCheckpoint;
    final WordMatchEngine game = WordMatchEngine.fromState(
      checkpoint.board,
      random: Random(991),
    );
    for (final int size in <int>[3, 4, 5]) {
      chain = _targetPath(game, size);
      if (chain != null) break;
    }
    if (chain == null) {
      state = await _startCourseWordGame(
        repository,
        state,
        receiptTrace: expectedNewCommandReceipts,
      );
    }
  }
  if (chain == null) {
    throw StateError('Could not prepare a valid post-cap course answer.');
  }
  final CourseLearningState afterCommit = await _submitCourse(
    repository,
    state,
    _courseGameActivityId,
    LinkWordTiles(indices: chain, elapsedSeconds: 0),
    receiptTrace: expectedNewCommandReceipts,
  );
  final CourseLearningState afterState = await repository.load();
  final int attemptCountAfter = await _rowCount(
    database,
    'learning_attempts',
    harness.courseStorageScope,
  );
  final int receiptCountAfter = await _rowCount(
    database,
    'learning_command_receipts',
    harness.courseStorageScope,
  );
  final List<String> receiptIdsAfter = await _receiptIdentities(
    database,
    harness.courseStorageScope,
  );
  final Map<String, List<String>> aggregateSqlAfter = await _aggregateSqlRows(
    database,
    harness.courseStorageScope,
  );
  final Map<String, List<String>> aggregateExpectedBeforeRows =
      _typedAggregateRows('course', beforeState);
  final Map<String, List<String>> aggregateExpectedAfterRows =
      _typedAggregateRows('course', afterCommit);
  final Map<String, Object?> aggregateProjectionProof =
      _aggregateProjectionProof(
        'course',
        aggregateSqlBefore,
        aggregateSqlAfter,
        aggregateExpectedBeforeRows,
        aggregateExpectedAfterRows,
      );
  final bool aggregateSqlMatchesExpected =
      aggregateProjectionProof['matchesTypedBefore']! as bool &&
      aggregateProjectionProof['matchesExpectedAfter']! as bool &&
      aggregateProjectionProof['meaningfulNonemptyBaselines']! as bool &&
      aggregateProjectionProof['unaffectedRowsPreserved']! as bool;
  final List<Map<String, Object?>> sqlAfter = await _attemptRows(
    database,
    harness.courseStorageScope,
  );
  final List<AttemptBatch> beforeBatches = beforeState.history;
  final List<AttemptBatch> afterBatches = afterState.history;
  final Set<String> afterTokens = <String>{
    for (final AttemptBatch batch in afterBatches) batch.token,
  };
  final List<AttemptBatch> evictedBatches = beforeBatches
      .where((AttemptBatch batch) => !afterTokens.contains(batch.token))
      .toList(growable: false);
  final Set<String> beforeIds = <String>{
    for (final AttemptBatch batch in beforeBatches)
      for (final CourseAttempt attempt in batch.attempts) attempt.submissionId,
  };
  final Set<String> afterIds = <String>{
    for (final AttemptBatch batch in afterBatches)
      for (final CourseAttempt attempt in batch.attempts) attempt.submissionId,
  };
  final Set<String> sqlAfterIds = <String>{
    for (final Map<String, Object?> row in sqlAfter)
      row['attempt_id']! as String,
  };
  final bool eachBatchWasKeptOrEvicted = beforeBatches.every((
    AttemptBatch batch,
  ) {
    final int retained = batch.attempts
        .where(
          (CourseAttempt attempt) => afterIds.contains(attempt.submissionId),
        )
        .length;
    return retained == 0 || retained == batch.attempts.length;
  });
  final bool sqlRetainedOnlyCompleteBatches = _hasCompleteSqlBatches(sqlAfter);
  final List<String> newlyAddedIds = afterIds.difference(beforeIds).toList()
    ..sort();
  final List<String> evictedIds = beforeIds.difference(afterIds).toList()
    ..sort();
  final Map<String, Object?> receiptIdentityEvidence = _expectedReceiptEvidence(
    before: receiptIdsBefore,
    after: receiptIdsAfter,
    tracedNewCommands: expectedNewCommandReceipts,
    ordinalDelta: afterState.commitOrdinal - beforeState.commitOrdinal,
    limit: harness.historyLimit,
  );
  final bool receiptPrunePreservedExpectedIdentities = _receiptPrunePreserved(
    receiptIdsBefore,
    receiptIdsAfter,
    harness.historyLimit,
    expectedNewReceipts: afterState.commitOrdinal - beforeState.commitOrdinal,
  );
  final bool currentRunLatestReceiptPersisted = _receiptContainsLatest(
    receiptIdsAfter,
    _courseLatestReceipt(afterState),
  );
  final bool basePrunePredicatesPassed =
      attemptCountBefore == harness.historyLimit &&
      receiptCountBefore == harness.historyLimit &&
      attemptCountAfter <= harness.historyLimit &&
      receiptCountAfter == harness.historyLimit &&
      evictedBatches.isNotEmpty &&
      newlyAddedIds.length == chain.length &&
      evictedIds.isNotEmpty &&
      eachBatchWasKeptOrEvicted &&
      sqlRetainedOnlyCompleteBatches &&
      afterIds.length == attemptCountAfter &&
      afterState.history.length == afterCommit.history.length &&
      _sameStringIds(sqlAfterIds, afterIds) &&
      aggregateSqlMatchesExpected;
  final bool observed =
      learningPostCapPruneObservedFromEvidence(<String, Object?>{
        'basePrunePredicatesPassed': basePrunePredicatesPassed,
        ...receiptIdentityEvidence,
        'receiptPrunePreservedExpectedIdentities':
            receiptPrunePreservedExpectedIdentities,
        'currentRunLatestReceiptPersisted': currentRunLatestReceiptPersisted,
      });
  if (!observed) {
    throw StateError('Post-cap course prune failed its identity invariants.');
  }
  return <String, Object?>{
    ..._postCapIdentityEvidence(
      attemptCountBefore: attemptCountBefore,
      attemptCountAfter: attemptCountAfter,
      receiptCountBefore: receiptCountBefore,
      receiptCountAfter: receiptCountAfter,
      beforeIds: beforeIds,
      afterIds: afterIds,
      sqlAfterIds: sqlAfterIds,
      expectedNewAttemptCount: chain.length,
    ),
    'observed': observed,
    'completeCourseBatches': sqlRetainedOnlyCompleteBatches,
    'completeEvictedBatches': eachBatchWasKeptOrEvicted,
    'evictedBatchTokens': <String>[
      for (final AttemptBatch batch in evictedBatches) batch.token,
    ],
    'evictedBatchAttemptIds': <List<String>>[
      for (final AttemptBatch batch in evictedBatches)
        <String>[
          for (final CourseAttempt attempt in batch.attempts)
            attempt.submissionId,
        ],
    ],
    'survivingBatchTokens': <String>[
      for (final AttemptBatch batch in afterBatches) batch.token,
    ],
    'survivingBatchAttemptIds': <List<String>>[
      for (final AttemptBatch batch in afterBatches)
        <String>[
          for (final CourseAttempt attempt in batch.attempts)
            attempt.submissionId,
        ],
    ],
    'sqlRowsMatchReloadedState': _sameStringIds(sqlAfterIds, afterIds),
    'attemptIdsBefore': beforeIds.toList()..sort(),
    'attemptIdsAfter': afterIds.toList()..sort(),
    'newAttemptIds': newlyAddedIds,
    'evictedAttemptIds': evictedIds,
    'survivingAttemptIds': afterIds.toList()..sort(),
    'basePrunePredicatesPassed': basePrunePredicatesPassed,
    'receiptPruneObserved':
        receiptCountBefore == harness.historyLimit &&
        receiptCountAfter == harness.historyLimit,
    'receiptIdentitiesBefore': receiptIdsBefore,
    'receiptIdentitiesAfter': receiptIdsAfter,
    ...receiptIdentityEvidence,
    'receiptPrunePreservedExpectedIdentities':
        receiptPrunePreservedExpectedIdentities,
    'currentRunLatestReceiptPersisted': currentRunLatestReceiptPersisted,
    'aggregateBefore': aggregateBefore,
    'aggregateExpectedAfter': _courseSummaryValues(afterCommit),
    'aggregateReloadedAfter': _courseSummaryValues(afterState),
    'aggregateSqlBefore': aggregateSqlBefore,
    'aggregateSqlAfter': aggregateSqlAfter,
    'aggregateSqlValuesAfter': _aggregateSqlValues(aggregateSqlAfter),
    'aggregateSqlMatchesExpected': aggregateSqlMatchesExpected,
    'aggregateSqlMatchesTypedBefore':
        aggregateProjectionProof['matchesTypedBefore'],
    'aggregateSqlMatchesTypedExpectedAfter': aggregateSqlMatchesExpected,
    'aggregateUnaffectedRowsPreserved':
        aggregateProjectionProof['unaffectedRowsPreserved'],
    'aggregatePreservedIdentityCount':
        aggregateProjectionProof['preservedIdentityCount'],
    'aggregateExpectedBeforeRows': aggregateExpectedBeforeRows,
    'aggregateExpectedAfterRows': aggregateExpectedAfterRows,
    'aggregateNegativeControlsRejected': _aggregateNegativeControlsRejected(
      aggregateExpectedAfterRows,
    ),
    'aggregateProjectionByTable': aggregateProjectionProof,
    'answerBatchSize': chain.length,
    'sqlAttemptRowsBefore': sqlBefore.length,
  };
}

Future<Map<String, Object?>> _exerciseComparisonPostCapPrune(
  LearningDatabaseHandle handle,
  _WorkloadHarness harness,
) async {
  final SqliteComparisonLearningRepository repository = harness
      .comparisonRepository(handle);
  final ComparisonLearningState beforeState = await repository.load();
  final LearningDatabase database = await handle.open();
  final int attemptCountBefore = await _rowCount(
    database,
    'learning_attempts',
    harness.comparisonStorageScope,
  );
  final int receiptCountBefore = await _rowCount(
    database,
    'learning_command_receipts',
    harness.comparisonStorageScope,
  );
  final List<String> receiptIdsBefore = await _receiptIdentities(
    database,
    harness.comparisonStorageScope,
  );
  final Map<String, int> aggregateBefore = _comparisonSummaryValues(
    beforeState,
  );
  final Map<String, List<String>> aggregateSqlBefore = await _aggregateSqlRows(
    database,
    harness.comparisonStorageScope,
  );
  final List<Map<String, Object?>> sqlBefore = await _attemptRows(
    database,
    harness.comparisonStorageScope,
  );
  final List<String> expectedNewCommandReceipts = <String>[];
  var state = (await harness.commitComparison(
    repository,
    beforeState,
    StartComparisonRun(
      sessionId: 'task9-post-cap-${harness.runId}-comparison',
      policy: LessonPolicy(),
    ),
    receiptTrace: expectedNewCommandReceipts,
  )).state;
  final LessonSectionSession session = _comparisonSession(
    state,
    harness.catalogue,
  );
  final ComparisonExercise exercise = harness.catalogue.exercise(
    session.currentItemId!,
  );
  state = (await harness.commitComparison(
    repository,
    state,
    AnswerComparisonPair(
      _comparisonAnswer(
        harness,
        exercise,
        runGeneration: state.slot!.cursor.generation,
        round: session.round,
        correct: true,
      ),
    ),
    receiptTrace: expectedNewCommandReceipts,
  )).state;
  final ComparisonLearningState afterState = await repository.load();
  final int attemptCountAfter = await _rowCount(
    database,
    'learning_attempts',
    harness.comparisonStorageScope,
  );
  final int receiptCountAfter = await _rowCount(
    database,
    'learning_command_receipts',
    harness.comparisonStorageScope,
  );
  final List<String> receiptIdsAfter = await _receiptIdentities(
    database,
    harness.comparisonStorageScope,
  );
  final Map<String, List<String>> aggregateSqlAfter = await _aggregateSqlRows(
    database,
    harness.comparisonStorageScope,
  );
  final Map<String, List<String>> aggregateExpectedBeforeRows =
      _typedAggregateRows('comparison', beforeState);
  final Map<String, List<String>> aggregateExpectedAfterRows =
      _typedAggregateRows('comparison', state);
  final Map<String, Object?> aggregateProjectionProof =
      _aggregateProjectionProof(
        'comparison',
        aggregateSqlBefore,
        aggregateSqlAfter,
        aggregateExpectedBeforeRows,
        aggregateExpectedAfterRows,
      );
  final bool aggregateSqlMatchesExpected =
      aggregateProjectionProof['matchesTypedBefore']! as bool &&
      aggregateProjectionProof['matchesExpectedAfter']! as bool &&
      aggregateProjectionProof['meaningfulNonemptyBaselines']! as bool &&
      aggregateProjectionProof['unaffectedRowsPreserved']! as bool;
  final List<Map<String, Object?>> sqlAfter = await _attemptRows(
    database,
    harness.comparisonStorageScope,
  );
  final List<String> beforeIds = <String>[
    for (final Map<String, Object?> row in sqlBefore)
      row['attempt_id']! as String,
  ];
  final List<String> afterIds = <String>[
    for (final Map<String, Object?> row in sqlAfter)
      row['attempt_id']! as String,
  ];
  final Set<String> beforeStateKeys = <String>{
    for (final ComparisonPairAttempt attempt in beforeState.attempts)
      jsonEncode(<Object?>[
        attempt.activityId,
        attempt.runGeneration,
        attempt.sequence,
      ]),
  };
  final Set<String> afterStateKeys = <String>{
    for (final ComparisonPairAttempt attempt in afterState.attempts)
      jsonEncode(<Object?>[
        attempt.activityId,
        attempt.runGeneration,
        attempt.sequence,
      ]),
  };
  final Set<String> beforeSqlKeys = _attemptRowKeys(sqlBefore);
  final Set<String> afterSqlKeys = _attemptRowKeys(sqlAfter);
  final bool sqlMatchesReloadedState =
      _sameStringIds(beforeStateKeys, beforeSqlKeys) &&
      _sameStringIds(afterStateKeys, afterSqlKeys);
  final Map<String, Object?> evidence = _postCapIdentityEvidence(
    attemptCountBefore: attemptCountBefore,
    attemptCountAfter: attemptCountAfter,
    receiptCountBefore: receiptCountBefore,
    receiptCountAfter: receiptCountAfter,
    beforeIds: beforeIds.toSet(),
    afterIds: afterIds.toSet(),
    sqlAfterIds: afterIds.toSet(),
    expectedNewAttemptCount: 1,
  );
  final Map<String, Object?> receiptIdentityEvidence = _expectedReceiptEvidence(
    before: receiptIdsBefore,
    after: receiptIdsAfter,
    tracedNewCommands: expectedNewCommandReceipts,
    ordinalDelta: afterState.commitOrdinal - beforeState.commitOrdinal,
    limit: harness.historyLimit,
  );
  final bool receiptPrunePreservedExpectedIdentities = _receiptPrunePreserved(
    receiptIdsBefore,
    receiptIdsAfter,
    harness.historyLimit,
    expectedNewReceipts: afterState.commitOrdinal - beforeState.commitOrdinal,
  );
  final String latestReceiptToken = afterState.receipts
      .reduce(
        (left, right) =>
            left.commitOrdinal > right.commitOrdinal ? left : right,
      )
      .token;
  final bool currentRunLatestReceiptPersisted = _receiptContainsLatest(
    receiptIdsAfter,
    latestReceiptToken,
  );
  final bool basePrunePredicatesPassed =
      attemptCountBefore == harness.historyLimit &&
      receiptCountBefore == harness.historyLimit &&
      attemptCountAfter <= harness.historyLimit &&
      receiptCountAfter == harness.historyLimit &&
      (evidence['newAttemptIds']! as List).length == 1 &&
      (evidence['evictedAttemptIds']! as List).isNotEmpty &&
      afterState.attempts.length == attemptCountAfter &&
      sqlMatchesReloadedState &&
      aggregateSqlMatchesExpected;
  final bool observed =
      learningPostCapPruneObservedFromEvidence(<String, Object?>{
        'basePrunePredicatesPassed': basePrunePredicatesPassed,
        ...receiptIdentityEvidence,
        'receiptPrunePreservedExpectedIdentities':
            receiptPrunePreservedExpectedIdentities,
        'currentRunLatestReceiptPersisted': currentRunLatestReceiptPersisted,
      });
  if (!observed) {
    throw StateError(
      'Post-cap comparison prune failed its identity invariants.',
    );
  }
  return <String, Object?>{
    ...evidence,
    'observed': observed,
    'basePrunePredicatesPassed': basePrunePredicatesPassed,
    'sqlRowsMatchReloadedState': sqlMatchesReloadedState,
    'typedAttemptKeysBefore': beforeStateKeys.toList()..sort(),
    'typedAttemptKeysAfter': afterStateKeys.toList()..sort(),
    'sqlAttemptKeysBefore': beforeSqlKeys.toList()..sort(),
    'sqlAttemptKeysAfter': afterSqlKeys.toList()..sort(),
    'receiptPruneObserved':
        receiptCountBefore == harness.historyLimit &&
        receiptCountAfter == harness.historyLimit,
    'receiptIdentitiesBefore': receiptIdsBefore,
    'receiptIdentitiesAfter': receiptIdsAfter,
    ...receiptIdentityEvidence,
    'receiptPrunePreservedExpectedIdentities':
        receiptPrunePreservedExpectedIdentities,
    'currentRunLatestReceiptPersisted': currentRunLatestReceiptPersisted,
    'aggregateBefore': aggregateBefore,
    'aggregateExpectedAfter': _comparisonSummaryValues(state),
    'aggregateReloadedAfter': _comparisonSummaryValues(afterState),
    'aggregateSqlExpectedAfter': _comparisonPersistedSummaryValues(state),
    'aggregateSqlBefore': aggregateSqlBefore,
    'aggregateSqlAfter': aggregateSqlAfter,
    'aggregateSqlValuesAfter': _aggregateSqlValues(aggregateSqlAfter),
    'aggregateSqlMatchesExpected': aggregateSqlMatchesExpected,
    'aggregateSqlMatchesTypedBefore':
        aggregateProjectionProof['matchesTypedBefore'],
    'aggregateSqlMatchesTypedExpectedAfter': aggregateSqlMatchesExpected,
    'aggregateUnaffectedRowsPreserved':
        aggregateProjectionProof['unaffectedRowsPreserved'],
    'aggregatePreservedIdentityCount':
        aggregateProjectionProof['preservedIdentityCount'],
    'aggregateExpectedBeforeRows': aggregateExpectedBeforeRows,
    'aggregateExpectedAfterRows': aggregateExpectedAfterRows,
    'aggregateNegativeControlsRejected': _aggregateNegativeControlsRejected(
      aggregateExpectedAfterRows,
    ),
    'aggregateProjectionByTable': aggregateProjectionProof,
    'sqlAttemptRowsBefore': sqlBefore.length,
  };
}

Future<Map<String, Object?>> _exerciseSentencePostCapPrune(
  LearningDatabaseHandle handle,
  _WorkloadHarness harness,
) async {
  final SqliteSentenceHuntLearningRepository repository = harness
      .sentenceHuntRepository(handle);
  final SentenceHuntLearningState beforeState = await repository.load();
  final LearningDatabase database = await handle.open();
  final int attemptCountBefore = await _rowCount(
    database,
    'learning_attempts',
    harness.sentenceStorageScope,
  );
  final int receiptCountBefore = await _rowCount(
    database,
    'learning_command_receipts',
    harness.sentenceStorageScope,
  );
  final List<String> receiptIdsBefore = await _receiptIdentities(
    database,
    harness.sentenceStorageScope,
  );
  final Map<String, int> aggregateBefore = _sentenceSummaryValues(beforeState);
  final Map<String, List<String>> aggregateSqlBefore = await _aggregateSqlRows(
    database,
    harness.sentenceStorageScope,
  );
  final List<Map<String, Object?>> sqlBefore = await _attemptRows(
    database,
    harness.sentenceStorageScope,
  );
  final SentenceHuntSection section = harness.sentenceCatalogue.sections.first;
  final List<String> expectedNewCommandReceipts = <String>[];
  var state = (await harness.commitSentence(
    repository,
    beforeState,
    section.id,
    StartSentenceHuntRun(
      sessionId: 'task9-post-cap-${harness.runId}-sentence',
      policy: section.policy,
      mode: SentenceHuntRunMode.practice,
    ),
    receiptTrace: expectedNewCommandReceipts,
  )).state;
  final LessonSectionSession session = _sentenceSession(state, section);
  final SentenceHuntItem item = harness.sentenceCatalogue.item(
    section.id,
    session.currentItemId!,
  );
  state = (await harness.commitSentence(
    repository,
    state,
    section.id,
    AnswerSentenceHuntItem(
      _sentenceAnswer(
        harness,
        item,
        runGeneration: state.slots[section.id]!.cursor.generation,
        round: session.round,
        correct: true,
      ),
    ),
    receiptTrace: expectedNewCommandReceipts,
  )).state;
  final SentenceHuntLearningState afterState = await repository.load();
  final int attemptCountAfter = await _rowCount(
    database,
    'learning_attempts',
    harness.sentenceStorageScope,
  );
  final int receiptCountAfter = await _rowCount(
    database,
    'learning_command_receipts',
    harness.sentenceStorageScope,
  );
  final List<String> receiptIdsAfter = await _receiptIdentities(
    database,
    harness.sentenceStorageScope,
  );
  final Map<String, List<String>> aggregateSqlAfter = await _aggregateSqlRows(
    database,
    harness.sentenceStorageScope,
  );
  final Map<String, List<String>> aggregateExpectedBeforeRows =
      _typedAggregateRows('sentence-hunt', beforeState);
  final Map<String, List<String>> aggregateExpectedAfterRows =
      _typedAggregateRows('sentence-hunt', state);
  final Map<String, Object?> aggregateProjectionProof =
      _aggregateProjectionProof(
        'sentence-hunt',
        aggregateSqlBefore,
        aggregateSqlAfter,
        aggregateExpectedBeforeRows,
        aggregateExpectedAfterRows,
      );
  final bool aggregateSqlMatchesExpected =
      aggregateProjectionProof['matchesTypedBefore']! as bool &&
      aggregateProjectionProof['matchesExpectedAfter']! as bool &&
      aggregateProjectionProof['meaningfulNonemptyBaselines']! as bool &&
      aggregateProjectionProof['unaffectedRowsPreserved']! as bool;
  final List<Map<String, Object?>> sqlAfter = await _attemptRows(
    database,
    harness.sentenceStorageScope,
  );
  final List<String> beforeIds = <String>[
    for (final Map<String, Object?> row in sqlBefore)
      row['attempt_id']! as String,
  ];
  final List<String> afterIds = <String>[
    for (final Map<String, Object?> row in sqlAfter)
      row['attempt_id']! as String,
  ];
  final Set<String> beforeStateKeys = <String>{
    for (final SentenceHuntAttempt attempt in beforeState.attempts)
      jsonEncode(<Object?>[
        attempt.content.sectionId,
        attempt.runGeneration,
        attempt.sequence,
      ]),
  };
  final Set<String> afterStateKeys = <String>{
    for (final SentenceHuntAttempt attempt in afterState.attempts)
      jsonEncode(<Object?>[
        attempt.content.sectionId,
        attempt.runGeneration,
        attempt.sequence,
      ]),
  };
  final Set<String> beforeSqlKeys = _attemptRowKeys(sqlBefore);
  final Set<String> afterSqlKeys = _attemptRowKeys(sqlAfter);
  final bool sqlMatchesReloadedState =
      _sameStringIds(beforeStateKeys, beforeSqlKeys) &&
      _sameStringIds(afterStateKeys, afterSqlKeys);
  final Map<String, Object?> evidence = _postCapIdentityEvidence(
    attemptCountBefore: attemptCountBefore,
    attemptCountAfter: attemptCountAfter,
    receiptCountBefore: receiptCountBefore,
    receiptCountAfter: receiptCountAfter,
    beforeIds: beforeIds.toSet(),
    afterIds: afterIds.toSet(),
    sqlAfterIds: afterIds.toSet(),
    expectedNewAttemptCount: 1,
  );
  final Map<String, Object?> receiptIdentityEvidence = _expectedReceiptEvidence(
    before: receiptIdsBefore,
    after: receiptIdsAfter,
    tracedNewCommands: expectedNewCommandReceipts,
    ordinalDelta: afterState.commitOrdinal - beforeState.commitOrdinal,
    limit: harness.historyLimit,
  );
  final bool receiptPrunePreservedExpectedIdentities = _receiptPrunePreserved(
    receiptIdsBefore,
    receiptIdsAfter,
    harness.historyLimit,
    expectedNewReceipts: afterState.commitOrdinal - beforeState.commitOrdinal,
  );
  final bool currentRunLatestReceiptPersisted = _receiptContainsLatest(
    receiptIdsAfter,
    _sentenceLatestReceipt(afterState),
  );
  final bool basePrunePredicatesPassed =
      attemptCountBefore == harness.historyLimit &&
      receiptCountBefore == harness.historyLimit &&
      attemptCountAfter <= harness.historyLimit &&
      receiptCountAfter == harness.historyLimit &&
      (evidence['newAttemptIds']! as List).length == 1 &&
      (evidence['evictedAttemptIds']! as List).isNotEmpty &&
      afterState.attempts.length == attemptCountAfter &&
      sqlMatchesReloadedState &&
      aggregateSqlMatchesExpected;
  final bool observed =
      learningPostCapPruneObservedFromEvidence(<String, Object?>{
        'basePrunePredicatesPassed': basePrunePredicatesPassed,
        ...receiptIdentityEvidence,
        'receiptPrunePreservedExpectedIdentities':
            receiptPrunePreservedExpectedIdentities,
        'currentRunLatestReceiptPersisted': currentRunLatestReceiptPersisted,
      });
  if (!observed) {
    throw StateError(
      'Post-cap sentence-hunt prune failed its identity invariants.',
    );
  }
  return <String, Object?>{
    ...evidence,
    'observed': observed,
    'basePrunePredicatesPassed': basePrunePredicatesPassed,
    'sqlRowsMatchReloadedState': sqlMatchesReloadedState,
    'typedAttemptKeysBefore': beforeStateKeys.toList()..sort(),
    'typedAttemptKeysAfter': afterStateKeys.toList()..sort(),
    'sqlAttemptKeysBefore': beforeSqlKeys.toList()..sort(),
    'sqlAttemptKeysAfter': afterSqlKeys.toList()..sort(),
    'receiptPruneObserved':
        receiptCountBefore == harness.historyLimit &&
        receiptCountAfter == harness.historyLimit,
    'receiptIdentitiesBefore': receiptIdsBefore,
    'receiptIdentitiesAfter': receiptIdsAfter,
    ...receiptIdentityEvidence,
    'receiptPrunePreservedExpectedIdentities':
        receiptPrunePreservedExpectedIdentities,
    'currentRunLatestReceiptPersisted': currentRunLatestReceiptPersisted,
    'aggregateBefore': aggregateBefore,
    'aggregateExpectedAfter': _sentenceSummaryValues(state),
    'aggregateReloadedAfter': _sentenceSummaryValues(afterState),
    'aggregateSqlExpectedAfter': _sentencePersistedSummaryValues(state),
    'aggregateSqlBefore': aggregateSqlBefore,
    'aggregateSqlAfter': aggregateSqlAfter,
    'aggregateSqlValuesAfter': _aggregateSqlValues(aggregateSqlAfter),
    'aggregateSqlMatchesExpected': aggregateSqlMatchesExpected,
    'aggregateSqlMatchesTypedBefore':
        aggregateProjectionProof['matchesTypedBefore'],
    'aggregateSqlMatchesTypedExpectedAfter': aggregateSqlMatchesExpected,
    'aggregateUnaffectedRowsPreserved':
        aggregateProjectionProof['unaffectedRowsPreserved'],
    'aggregatePreservedIdentityCount':
        aggregateProjectionProof['preservedIdentityCount'],
    'aggregateExpectedBeforeRows': aggregateExpectedBeforeRows,
    'aggregateExpectedAfterRows': aggregateExpectedAfterRows,
    'aggregateNegativeControlsRejected': _aggregateNegativeControlsRejected(
      aggregateExpectedAfterRows,
    ),
    'aggregateProjectionByTable': aggregateProjectionProof,
    'sqlAttemptRowsBefore': sqlBefore.length,
  };
}

Map<String, Object?> _postCapIdentityEvidence({
  required int attemptCountBefore,
  required int attemptCountAfter,
  required int receiptCountBefore,
  required int receiptCountAfter,
  required Set<String> beforeIds,
  required Set<String> afterIds,
  required Set<String> sqlAfterIds,
  required int expectedNewAttemptCount,
}) {
  final List<String> sortedBefore = beforeIds.toList()..sort();
  final List<String> sortedAfter = afterIds.toList()..sort();
  final List<String> sortedSqlAfter = sqlAfterIds.toList()..sort();
  final List<String> addedIds = afterIds.difference(beforeIds).toList()..sort();
  final List<String> evictedIds = beforeIds.difference(afterIds).toList()
    ..sort();
  return <String, Object?>{
    'attemptCountBefore': attemptCountBefore,
    'attemptCountAfter': attemptCountAfter,
    'receiptCountBefore': receiptCountBefore,
    'receiptCountAfter': receiptCountAfter,
    'attemptIdsBefore': sortedBefore,
    'attemptIdsAfter': sortedAfter,
    'newAttemptIds': addedIds,
    'evictedAttemptIds': evictedIds,
    'survivingAttemptIds': sortedAfter,
    'expectedNewAttemptCount': expectedNewAttemptCount,
    'sqlAttemptIdsAfter': sortedSqlAfter,
    'sqlRowsMatchExpectedRetainedIds': _sameStringIds(sqlAfterIds, afterIds),
  };
}

Future<List<Map<String, Object?>>> _attemptRows(
  LearningDatabase database,
  LearningStorageScope scope,
) async {
  final int scopeId = await _scopeId(database, scope);
  final List<QueryRow> rows = await database
      .customSelect(
        'SELECT attempt_id, activity_id, run_generation, command_sequence, '
        'batch_index FROM learning_attempts WHERE scope_id = ? '
        'ORDER BY commit_ordinal, batch_index',
        variables: <Variable<Object>>[Variable<int>(scopeId)],
      )
      .get();
  return <Map<String, Object?>>[
    for (final QueryRow row in rows)
      <String, Object?>{
        'attempt_id': row.read<String>('attempt_id'),
        'activity_id': row.read<String>('activity_id'),
        'run_generation': row.read<int>('run_generation'),
        'command_sequence': row.read<int>('command_sequence'),
        'batch_index': row.read<int>('batch_index'),
      },
  ];
}

Future<List<String>> _receiptIdentities(
  LearningDatabase database,
  LearningStorageScope scope,
) async {
  final List<QueryRow> rows = await database
      .customSelect(
        'SELECT token, canonical_payload, commit_ordinal FROM learning_command_receipts '
        'WHERE scope_id = ? ORDER BY commit_ordinal, token',
        variables: <Variable<Object>>[
          Variable<int>(await _scopeId(database, scope)),
        ],
      )
      .get();
  return <String>[
    for (final QueryRow row in rows)
      jsonEncode(<Object?>[
        row.read<String>('token'),
        row.read<String>('canonical_payload'),
        row.read<int>('commit_ordinal'),
      ]),
  ];
}

Future<Map<String, List<String>>> _aggregateSqlRows(
  LearningDatabase database,
  LearningStorageScope scope,
) async {
  final int scopeId = await _scopeId(database, scope);
  final Map<String, List<String>> result = <String, List<String>>{};
  for (final String table in <String>[
    'learning_summaries',
    'learning_mistakes',
    'learning_completions',
    'learning_exposure',
    'learning_best_scores',
  ]) {
    final List<QueryRow> rows = await database
        .customSelect(
          'SELECT * FROM $table WHERE scope_id = ? ORDER BY rowid',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    result[table] = <String>[
      for (final QueryRow row in rows)
        jsonEncode(_sortedAggregateRow(row.data)..remove('scope_id')),
    ];
  }
  return result;
}

Map<String, Object?> _sortedAggregateRow(Map<String, Object?> row) =>
    Map<String, Object?>.fromEntries(
      row.entries.toList()..sort(
        (MapEntry<String, Object?> a, MapEntry<String, Object?> b) =>
            a.key.compareTo(b.key),
      ),
    );

String _aggregateRowJson(Map<String, Object?> row) =>
    jsonEncode(_sortedAggregateRow(row));

/// Exact order-independent comparison used by the pruning proof and its
/// negative controls. Rows are canonical JSON maps with technical scope IDs
/// omitted; semantic keys and every persisted value remain in the projection.
bool learningAggregateProjectionMatches(
  Map<String, List<String>> actual,
  Map<String, List<String>> expected,
) {
  if (actual.keys.toSet().difference(expected.keys.toSet()).isNotEmpty ||
      expected.keys.toSet().difference(actual.keys.toSet()).isNotEmpty) {
    return false;
  }
  return expected.entries.every(
    (MapEntry<String, List<String>> entry) =>
        actual[entry.key]!.length == entry.value.length &&
        actual[entry.key]!.toSet().length == actual[entry.key]!.length &&
        _sameStringIds(actual[entry.key]!.toSet(), entry.value.toSet()),
  );
}

Map<String, List<String>> _typedAggregateRows(String family, Object state) {
  final Map<String, List<Map<String, Object?>>> rows =
      <String, List<Map<String, Object?>>>{
        'learning_summaries': <Map<String, Object?>>[],
        'learning_mistakes': <Map<String, Object?>>[],
        'learning_completions': <Map<String, Object?>>[],
        'learning_exposure': <Map<String, Object?>>[],
        'learning_best_scores': <Map<String, Object?>>[],
      };
  switch (family) {
    case 'course':
      final CourseLearningState typed = state as CourseLearningState;
      for (final MapEntry<SummaryKey, SkillCount> entry
          in typed.summaries.entries) {
        rows['learning_summaries']!.add(<String, Object?>{
          'family': 'course',
          'activity_id': null,
          'sound': entry.key.sound,
          'skill': entry.key.skill.name,
          'origin': entry.key.origin.name,
          'presentation': entry.key.presentation.name,
          'assistance_mask': _assistanceMask(entry.key.assistance),
          'pair_id': null,
          'section_id': null,
          'item_id': null,
          'sentence_id': null,
          'audio_ref_id': null,
          'annotation_hash': null,
          'annotation_revision': null,
          'content_revision': null,
          'bucket': 'all',
          'correct': entry.value.correct,
          'total': entry.value.total,
        });
      }
      for (final LearningMistake mistake in typed.mistakes.values) {
        final MistakeKey key = mistake.key;
        rows['learning_mistakes']!.add(<String, Object?>{
          'family': 'course',
          'activity_id': key.activityId,
          'item_id': key.itemId,
          'target_sound': key.targetSound,
          'skill': key.skill.name,
          'pair_id': null,
          'section_id': null,
          'sentence_id': null,
          'audio_ref_id': null,
          'annotation_hash': null,
          'annotation_revision': null,
          'content_revision': key.contentRevision,
          'first_wrong_attempt_id': mistake.firstWrongId,
          'latest_wrong_attempt_id': mistake.latestWrongId,
          'first_wrong_at_us': _utcMicros(mistake.firstWrongAt),
          'latest_wrong_at_us': _utcMicros(mistake.latestWrongAt),
          'failure_count': mistake.failureCount,
          'last_run_generation': mistake.lastRunGeneration,
        });
      }
      for (final LearningCompletion completion in typed.completions) {
        rows['learning_completions']!.add(<String, Object?>{
          'activity_id': 'lesson:${completion.lessonId}',
          'content_revision': completion.contentRevision,
          'policy_kind':
              completion.policyKind == CompletionPolicyKind.discoveryThreshold
              ? 'discoveryThreshold'
              : 'legacyOnePass',
          'policy_revision': completion.policyRevision,
          'threshold_percent': completion.thresholdPercent ?? -1,
          'committed_at_us': _utcMicros(completion.committedAt),
        });
      }
      for (final ActivitySlot slot in typed.activities.values) {
        for (final MapEntry<ItemContextKey, ItemExposure> entry
            in slot.exposures.entries) {
          rows['learning_exposure']!.add(<String, Object?>{
            'family': 'course',
            'activity_id': slot.activityId,
            'item_id': entry.key.itemId,
            'target_sound': entry.key.targetSound,
            'section_id': null,
            'content_revision': null,
            'presentations': entry.value.presentations,
            'assistance_mask': _assistanceMask(entry.value.assistance),
          });
        }
      }
      for (final MapEntry<String, int> score in typed.bestScores.entries) {
        rows['learning_best_scores']!.add(<String, Object?>{
          'activity_id': score.key,
          'score': score.value,
        });
      }
    case 'comparison':
      final ComparisonLearningState typed = state as ComparisonLearningState;
      for (final ComparisonPairSummary summary in typed.summaries.values) {
        for (final (String, ComparisonCount) bucket
            in <(String, ComparisonCount)>[
              ('firstInRun', summary.firstInRun),
              ('repeatInRun', summary.repeatInRun),
              ('afterDebrief', summary.afterDebrief),
            ]) {
          rows['learning_summaries']!.add(<String, Object?>{
            'family': 'comparison',
            'activity_id': summary.key.activityId,
            'sound': null,
            'skill': null,
            'origin': null,
            'presentation': null,
            'assistance_mask': null,
            'pair_id': summary.key.pairId,
            'section_id': null,
            'item_id': null,
            'sentence_id': null,
            'audio_ref_id': null,
            'annotation_hash': null,
            'annotation_revision': null,
            'content_revision': summary.key.contentRevision,
            'bucket': bucket.$1,
            'correct': bucket.$2.correct,
            'total': bucket.$2.total,
          });
        }
      }
      for (final ComparisonPairMistake mistake in typed.mistakes.values) {
        rows['learning_mistakes']!.add(<String, Object?>{
          'family': 'comparison',
          'activity_id': mistake.key.activityId,
          'item_id': null,
          'target_sound': null,
          'skill': null,
          'pair_id': mistake.key.pairId,
          'section_id': null,
          'sentence_id': null,
          'audio_ref_id': null,
          'annotation_hash': null,
          'annotation_revision': null,
          'content_revision': mistake.key.contentRevision,
          'first_wrong_attempt_id': null,
          'latest_wrong_attempt_id': null,
          'first_wrong_at_us': _utcMicros(mistake.firstWrongAt),
          'latest_wrong_at_us': _utcMicros(mistake.latestWrongAt),
          'failure_count': mistake.failureCount,
          'last_run_generation': null,
        });
      }
      for (final ComparisonCompletion completion in typed.completions) {
        rows['learning_completions']!.add(<String, Object?>{
          'activity_id': completion.activityId,
          'content_revision': completion.contentRevision,
          'policy_kind': 'discoveryThreshold',
          'policy_revision': completion.policyRevision,
          'threshold_percent': completion.thresholdPercent,
          'committed_at_us': _utcMicros(completion.committedAt),
        });
      }
    case 'sentence-hunt':
      final SentenceHuntLearningState typed =
          state as SentenceHuntLearningState;
      for (final SentenceHuntSummary summary in typed.summaries.values) {
        final SentenceHuntContentIdentity content = summary.content;
        for (final (String, SentenceHuntCounts) bucket
            in <(String, SentenceHuntCounts)>[
              ('firstInRun', summary.firstInRun),
              ('repeatInRun', summary.repeatInRun),
              ('firstTeachingExposed', summary.firstTeachingExposed),
              ('repeatTeachingExposed', summary.repeatTeachingExposed),
            ]) {
          rows['learning_summaries']!.add(<String, Object?>{
            'family': 'sentence-hunt',
            'activity_id': null,
            'sound': null,
            'skill': null,
            'origin': null,
            'presentation': null,
            'assistance_mask': null,
            'pair_id': null,
            'section_id': content.sectionId,
            'item_id': content.itemId,
            'sentence_id': content.sentenceId,
            'audio_ref_id': content.audioRefId,
            'annotation_hash': content.annotationHash,
            'annotation_revision': content.annotationRevision,
            'content_revision': content.contentRevision,
            'bucket': bucket.$1,
            'correct': bucket.$2.correct,
            'total': bucket.$2.total,
          });
        }
      }
      for (final SentenceHuntMistake mistake in typed.mistakes.values) {
        final SentenceHuntContentIdentity content = mistake.content;
        rows['learning_mistakes']!.add(<String, Object?>{
          'family': 'sentence-hunt',
          'activity_id': null,
          'item_id': content.itemId,
          'target_sound': null,
          'skill': null,
          'pair_id': null,
          'section_id': content.sectionId,
          'sentence_id': content.sentenceId,
          'audio_ref_id': content.audioRefId,
          'annotation_hash': content.annotationHash,
          'annotation_revision': content.annotationRevision,
          'content_revision': content.contentRevision,
          'first_wrong_attempt_id': null,
          'latest_wrong_attempt_id': null,
          'first_wrong_at_us': _utcMicros(mistake.firstWrongAt),
          'latest_wrong_at_us': _utcMicros(mistake.latestWrongAt),
          'failure_count': mistake.failureCount,
          'last_run_generation': null,
        });
      }
      for (final SentenceHuntCompletion completion in typed.completions) {
        rows['learning_completions']!.add(<String, Object?>{
          'activity_id': completion.sectionId,
          'content_revision': completion.contentRevision,
          'policy_kind': 'discoveryThreshold',
          'policy_revision': completion.policyRevision,
          'threshold_percent': completion.thresholdPercent,
          'committed_at_us': _utcMicros(completion.committedAt),
        });
      }
      for (final SentenceHuntExposureKey exposure in typed.teachingExposure) {
        rows['learning_exposure']!.add(<String, Object?>{
          'family': 'sentence-hunt',
          'activity_id': null,
          'item_id': null,
          'target_sound': null,
          'section_id': exposure.sectionId,
          'content_revision': exposure.contentRevision,
          'presentations': null,
          'assistance_mask': null,
        });
      }
    default:
      throw ArgumentError.value(family, 'family');
  }
  return <String, List<String>>{
    for (final MapEntry<String, List<Map<String, Object?>>> table
        in rows.entries)
      table.key: <String>[
        for (final Map<String, Object?> row in table.value)
          _aggregateRowJson(row),
      ],
  };
}

int _utcMicros(DateTime value) => value.toUtc().microsecondsSinceEpoch;

int _assistanceMask(Set<AssistanceFlag> flags) => flags.fold<int>(
  0,
  (int mask, AssistanceFlag flag) => mask | (1 << flag.index),
);

Set<String> _aggregateApplicableTables(String family) => switch (family) {
  'course' => <String>{
    'learning_summaries',
    'learning_mistakes',
    'learning_completions',
    'learning_exposure',
    'learning_best_scores',
  },
  'comparison' => <String>{
    'learning_summaries',
    'learning_mistakes',
    'learning_completions',
  },
  'sentence-hunt' => <String>{
    'learning_summaries',
    'learning_mistakes',
    'learning_completions',
    'learning_exposure',
  },
  _ => throw ArgumentError.value(family, 'family'),
};

Map<String, Object?> _aggregateProjectionProof(
  String family,
  Map<String, List<String>> actualBefore,
  Map<String, List<String>> actualAfter,
  Map<String, List<String>> expectedBefore,
  Map<String, List<String>> expectedAfter,
) {
  final Set<String> tables = _aggregateApplicableTables(family);
  final Map<String, List<String>> before = <String, List<String>>{
    for (final String table in tables) table: actualBefore[table]!,
  };
  final Map<String, List<String>> after = <String, List<String>>{
    for (final String table in tables) table: actualAfter[table]!,
  };
  final Map<String, List<String>> typedBefore = <String, List<String>>{
    for (final String table in tables) table: expectedBefore[table]!,
  };
  final Map<String, List<String>> typedAfter = <String, List<String>>{
    for (final String table in tables) table: expectedAfter[table]!,
  };
  final bool beforeMatches = learningAggregateProjectionMatches(
    before,
    typedBefore,
  );
  final bool afterMatches = learningAggregateProjectionMatches(
    after,
    typedAfter,
  );
  final Map<String, int> preservedByTable = <String, int>{};
  for (final String table in tables) {
    final Map<String, String> oldExpected = _rowsByAggregateIdentity(
      expectedBefore[table]!,
    );
    final Map<String, String> newExpected = _rowsByAggregateIdentity(
      expectedAfter[table]!,
    );
    final Set<String> unchanged = <String>{
      for (final String identity in oldExpected.keys)
        if (oldExpected[identity] == newExpected[identity]) identity,
    };
    final Map<String, String> oldActual = _rowsByAggregateIdentity(
      actualBefore[table]!,
    );
    final Map<String, String> newActual = _rowsByAggregateIdentity(
      actualAfter[table]!,
    );
    preservedByTable[table] = unchanged
        .where(
          (String identity) =>
              oldActual[identity] == oldExpected[identity] &&
              newActual[identity] == newExpected[identity] &&
              oldActual[identity] == newActual[identity],
        )
        .length;
  }
  final int preservedCount = preservedByTable.values.fold<int>(
    0,
    (a, b) => a + b,
  );
  final bool meaningfulBaselines = tables.every(
    (String table) =>
        expectedBefore[table]!.isNotEmpty && expectedAfter[table]!.isNotEmpty,
  );
  return <String, Object?>{
    'family': family,
    'applicableTables': tables.toList()..sort(),
    'matchesTypedBefore': beforeMatches,
    'matchesExpectedAfter': afterMatches,
    'meaningfulNonemptyBaselines': meaningfulBaselines,
    'preservedIdentityCountByTable': preservedByTable,
    'preservedIdentityCount': preservedCount,
    'unaffectedRowsPreserved':
        preservedCount > 0 &&
        preservedByTable.values.any((int count) => count > 0),
    'tableValueProof': <String, Object?>{
      for (final String table in tables)
        table: <String, Object?>{
          'beforeMatchesTyped': learningAggregateProjectionMatches(
            <String, List<String>>{table: actualBefore[table]!},
            <String, List<String>>{table: expectedBefore[table]!},
          ),
          'afterMatchesTypedTransition': learningAggregateProjectionMatches(
            <String, List<String>>{table: actualAfter[table]!},
            <String, List<String>>{table: expectedAfter[table]!},
          ),
          'beforeRowCount': actualBefore[table]!.length,
          'expectedAfterRowCount': expectedAfter[table]!.length,
          'unaffectedRowsPreserved': preservedByTable[table],
        },
    },
  };
}

Map<String, String> _rowsByAggregateIdentity(List<String> encodedRows) {
  final Map<String, String> result = <String, String>{};
  for (final String encoded in encodedRows) {
    final Map<String, Object?> row = Map<String, Object?>.from(
      jsonDecode(encoded) as Map,
    );
    final String table = switch (row['family']) {
      'course' when row.containsKey('bucket') => 'learning_summaries',
      'comparison' when row.containsKey('bucket') => 'learning_summaries',
      'sentence-hunt' when row.containsKey('bucket') => 'learning_summaries',
      'course' when row.containsKey('first_wrong_at_us') => 'learning_mistakes',
      'comparison' when row.containsKey('first_wrong_at_us') =>
        'learning_mistakes',
      'sentence-hunt' when row.containsKey('first_wrong_at_us') =>
        'learning_mistakes',
      'course'
          when row.containsKey('presentations') ||
              row.containsKey('section_id') =>
        'learning_exposure',
      'sentence-hunt'
          when row.containsKey('content_revision') &&
              row.containsKey('presentations') =>
        'learning_exposure',
      _ when row.containsKey('committed_at_us') => 'learning_completions',
      _ when row.containsKey('score') => 'learning_best_scores',
      _ => throw StateError('Cannot infer aggregate table for row: $row'),
    };
    final String identity = jsonEncode(switch (table) {
      'learning_summaries' => <Object?>[
        for (final String key in <String>[
          'family',
          'activity_id',
          'sound',
          'skill',
          'origin',
          'presentation',
          'assistance_mask',
          'pair_id',
          'section_id',
          'item_id',
          'sentence_id',
          'audio_ref_id',
          'annotation_hash',
          'annotation_revision',
          'content_revision',
          'bucket',
        ])
          row[key],
      ],
      'learning_mistakes' => <Object?>[
        for (final String key in <String>[
          'family',
          'activity_id',
          'item_id',
          'target_sound',
          'skill',
          'pair_id',
          'section_id',
          'sentence_id',
          'audio_ref_id',
          'annotation_hash',
          'annotation_revision',
          'content_revision',
        ])
          row[key],
      ],
      'learning_completions' => <Object?>[
        for (final String key in <String>[
          'activity_id',
          'content_revision',
          'policy_kind',
          'policy_revision',
          'threshold_percent',
        ])
          row[key],
      ],
      'learning_exposure' => <Object?>[
        for (final String key in <String>[
          'family',
          'activity_id',
          'item_id',
          'target_sound',
          'section_id',
          'content_revision',
        ])
          row[key],
      ],
      'learning_best_scores' => <Object?>[row['activity_id']],
      _ => throw StateError('Unknown aggregate table $table'),
    });
    if (result.containsKey(identity)) {
      throw StateError('Duplicate aggregate identity in $table.');
    }
    result[identity] = encoded;
  }
  return result;
}

bool _aggregateNegativeControlsRejected(Map<String, List<String>> expected) {
  final Map<String, List<Map<String, Object?>>> controls =
      <String, List<Map<String, Object?>>>{
        'learning_summaries': <Map<String, Object?>>[
          <String, Object?>{
            'family': 'course',
            'sound': 'a',
            'skill': 'listening',
            'origin': 'practice',
            'presentation': 'firstInRun',
            'assistance_mask': 0,
            'bucket': 'all',
            'correct': 5,
            'total': 8,
          },
          <String, Object?>{
            'family': 'course',
            'sound': 'b',
            'skill': 'listening',
            'origin': 'practice',
            'presentation': 'firstInRun',
            'assistance_mask': 0,
            'bucket': 'all',
            'correct': 2,
            'total': 3,
          },
        ],
        'learning_mistakes': <Map<String, Object?>>[
          <String, Object?>{
            'family': 'course',
            'activity_id': 'lesson:a',
            'item_id': 'x',
            'content_revision': 1,
            'first_wrong_attempt_id': 'first',
            'latest_wrong_attempt_id': 'latest',
            'first_wrong_at_us': 100,
            'latest_wrong_at_us': 200,
            'failure_count': 2,
            'last_run_generation': 1,
          },
        ],
        'learning_completions': <Map<String, Object?>>[
          <String, Object?>{
            'activity_id': 'lesson:a',
            'content_revision': 1,
            'policy_kind': 'discoveryThreshold',
            'policy_revision': 1,
            'threshold_percent': 80,
            'committed_at_us': 300,
          },
        ],
        'learning_exposure': <Map<String, Object?>>[
          <String, Object?>{
            'family': 'course',
            'activity_id': 'arcade:a',
            'item_id': 'x',
            'target_sound': 'u',
            'presentations': 1,
            'assistance_mask': 1,
          },
        ],
        'learning_best_scores': <Map<String, Object?>>[
          <String, Object?>{'activity_id': 'arcade:a', 'score': 100},
          <String, Object?>{'activity_id': 'arcade:b', 'score': 80},
        ],
      };
  final Map<String, List<String>> encoded = <String, List<String>>{
    for (final MapEntry<String, List<Map<String, Object?>>> entry
        in controls.entries)
      entry.key: <String>[
        for (final Map<String, Object?> row in entry.value)
          _aggregateRowJson(row),
      ],
  };
  final bool summaryIdentityAlterationIsCaught = () {
    final List<String> changed = List<String>.of(
      encoded['learning_summaries']!,
    );
    final Map<String, Object?> first = Map<String, Object?>.from(
      jsonDecode(changed[0]) as Map,
    )..['sound'] = 'b';
    final Map<String, Object?> second = Map<String, Object?>.from(
      jsonDecode(changed[1]) as Map,
    )..['sound'] = 'a';
    changed[0] = _aggregateRowJson(first);
    changed[1] = _aggregateRowJson(second);
    final Map<String, List<String>> altered = <String, List<String>>{
      ...encoded,
      'learning_summaries': changed,
    };
    final Map<String, int> typedSummaryTotals = _aggregateSqlValues(encoded);
    return !learningAggregateProjectionMatches(
          <String, List<String>>{'learning_summaries': changed},
          <String, List<String>>{
            'learning_summaries': encoded['learning_summaries']!,
          },
        ) &&
        _summarySqlMatches(altered, typedSummaryTotals);
  }();
  bool alteredValueRejected(String table, String field) {
    final List<String> changed = List<String>.of(encoded[table]!);
    final Map<String, Object?> row = Map<String, Object?>.from(
      jsonDecode(changed.last) as Map,
    );
    row[field] = (row[field]! as int) + 1;
    changed[changed.length - 1] = _aggregateRowJson(row);
    final Map<String, List<String>> altered = <String, List<String>>{
      ...encoded,
      table: changed,
    };
    return !learningAggregateProjectionMatches(
          <String, List<String>>{table: changed},
          <String, List<String>>{table: encoded[table]!},
        ) &&
        _summarySqlMatches(altered, _aggregateSqlValues(encoded));
  }

  return summaryIdentityAlterationIsCaught &&
      alteredValueRejected('learning_mistakes', 'latest_wrong_at_us') &&
      alteredValueRejected('learning_completions', 'committed_at_us') &&
      alteredValueRejected('learning_exposure', 'assistance_mask') &&
      alteredValueRejected('learning_best_scores', 'score') &&
      expected.isNotEmpty;
}

Map<String, int> _aggregateSqlValues(Map<String, List<String>> rows) {
  final List<Map<String, Object?>> summaries = <Map<String, Object?>>[
    for (final String encoded in rows['learning_summaries']!)
      Map<String, Object?>.from(jsonDecode(encoded) as Map),
  ];
  return <String, int>{
    'summaryIdentities': summaries.length,
    'summaryTotal': summaries.fold<int>(
      0,
      (int total, Map<String, Object?> row) => total + (row['total']! as int),
    ),
    'summaryCorrect': summaries.fold<int>(
      0,
      (int total, Map<String, Object?> row) => total + (row['correct']! as int),
    ),
    'mistakeFailures':
        <Map<String, Object?>>[
          for (final String encoded in rows['learning_mistakes']!)
            Map<String, Object?>.from(jsonDecode(encoded) as Map),
        ].fold<int>(
          0,
          (int total, Map<String, Object?> row) =>
              total + (row['failure_count']! as int),
        ),
    'completions': rows['learning_completions']!.length,
    'exposureRows': rows['learning_exposure']!.length,
    'bestScoreMax':
        <Map<String, Object?>>[
          for (final String encoded in rows['learning_best_scores']!)
            Map<String, Object?>.from(jsonDecode(encoded) as Map),
        ].fold<int>(
          0,
          (int maximum, Map<String, Object?> row) =>
              maximum > (row['score']! as int) ? maximum : row['score']! as int,
        ),
  };
}

bool _summarySqlMatches(
  Map<String, List<String>> rows,
  Map<String, int> expected,
) {
  final Map<String, int> actual = _aggregateSqlValues(rows);
  return actual['summaryIdentities'] == expected['summaryIdentities'] &&
      actual['summaryTotal'] == expected['summaryTotal'] &&
      actual['summaryCorrect'] == expected['summaryCorrect'];
}

bool _receiptPrunePreserved(
  List<String> before,
  List<String> after,
  int limit, {
  required int expectedNewReceipts,
}) {
  final Set<String> beforeSet = before.toSet();
  final List<String> added = after
      .where((String row) => !beforeSet.contains(row))
      .toList();
  if (added.length != expectedNewReceipts ||
      before.length != limit ||
      after.length != limit) {
    return false;
  }
  final List<String> expected = <String>[...before, ...added]
    ..sort((String left, String right) {
      final int leftOrdinal = (jsonDecode(left) as List<Object?>)[2]! as int;
      final int rightOrdinal = (jsonDecode(right) as List<Object?>)[2]! as int;
      return leftOrdinal.compareTo(rightOrdinal);
    });
  final int latestOldOrdinal = before
      .map((String row) => (jsonDecode(row) as List<Object?>)[2]! as int)
      .reduce((int left, int right) => left > right ? left : right);
  final List<int> newOrdinals =
      added
          .map((String row) => (jsonDecode(row) as List<Object?>)[2]! as int)
          .toList()
        ..sort();
  return _sameStringIds(
        after.toSet(),
        expected.skip(expected.length - limit).toSet(),
      ) &&
      newOrdinals.first == latestOldOrdinal + 1 &&
      newOrdinals.last == latestOldOrdinal + expectedNewReceipts;
}

Map<String, Object?> _expectedReceiptEvidence({
  required List<String> before,
  required List<String> after,
  required List<String> tracedNewCommands,
  required int ordinalDelta,
  required int limit,
}) {
  final List<String> expected = <String>[...before, ...tracedNewCommands]
    ..sort((String left, String right) {
      final int leftOrdinal = (jsonDecode(left) as List<Object?>)[2]! as int;
      final int rightOrdinal = (jsonDecode(right) as List<Object?>)[2]! as int;
      return leftOrdinal.compareTo(rightOrdinal);
    });
  final List<String> retained = expected.length <= limit
      ? expected
      : expected.sublist(expected.length - limit);
  final List<int> ordinals = <int>[
    for (final String row in retained)
      (jsonDecode(row) as List<Object?>)[2]! as int,
  ];
  final bool consecutive =
      ordinals.length < 2 ||
      List<int>.generate(
        ordinals.length - 1,
        (int index) => index,
      ).every((int index) => ordinals[index + 1] == ordinals[index] + 1);
  return <String, Object?>{
    'expectedNewCommandReceiptIdentities': tracedNewCommands,
    'expectedRetainedReceiptIdentities': retained,
    'receiptCommitOrdinalDelta': ordinalDelta,
    'receiptNewCommandCount': tracedNewCommands.length,
    'receiptOrdinalsConsecutive': consecutive,
    'receiptExpectedIdentityMatch':
        jsonEncode(after) == jsonEncode(retained) &&
        tracedNewCommands.length == ordinalDelta &&
        consecutive,
  };
}

bool _receiptContainsLatest(List<String> identities, String latestToken) =>
    identities.any(
      (String identity) =>
          (jsonDecode(identity) as List<Object?>).first == latestToken,
    );

Set<String> _attemptRowKeys(List<Map<String, Object?>> rows) => <String>{
  for (final Map<String, Object?> row in rows)
    jsonEncode(<Object?>[
      row['activity_id'],
      row['run_generation'],
      row['command_sequence'],
    ]),
};

bool _hasCompleteSqlBatches(List<Map<String, Object?>> rows) {
  final Map<String, List<int>> batches = <String, List<int>>{};
  for (final Map<String, Object?> row in rows) {
    final String key =
        '${row['activity_id']}:${row['run_generation']}:'
        '${row['command_sequence']}';
    batches.putIfAbsent(key, () => <int>[]).add(row['batch_index']! as int);
  }
  return batches.values.every((List<int> indices) {
    indices.sort();
    return indices.asMap().entries.every(
      (MapEntry<int, int> entry) => entry.key == entry.value,
    );
  });
}

bool _sameStringIds(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

/// Injects a family-specific failure after an answer's normalized row has
/// started to persist, verifies the complete file snapshot is unchanged after
/// reopening, then commits the same frozen command while dropping its result.
/// Exact replay through a second NativeDatabase connection must be a duplicate.
Future<LearningRecoveryEvidence> qualifyLearningRecovery(
  LearningDatabaseHandle firstConnection,
  LearningDatabaseHandle independentConnection, {
  required String runId,
}) async {
  final _WorkloadHarness harness = _WorkloadHarness('$runId-recovery');
  final Map<String, bool> rolledBack = <String, bool>{};
  final Map<String, String> beforeValues = <String, String>{};
  final Map<String, String> afterValues = <String, String>{};
  final Map<String, bool> duplicateReplay = <String, bool>{};
  final Map<String, int> attemptCounts = <String, int>{};
  final Map<String, String> frozenPayloads = <String, String>{};
  final Map<String, bool> canonicalBytesIdentical = <String, bool>{};
  final Map<String, bool> replayedWithDecodedCommand = <String, bool>{};
  final Map<String, String> rowsAfterFirstCommit = <String, String>{};
  final Map<String, String> rowsAfterReplay = <String, String>{};
  final Map<String, Map<String, int>> countsAfterFirstCommit =
      <String, Map<String, int>>{};
  final Map<String, Map<String, int>> countsAfterReplay =
      <String, Map<String, int>>{};
  var courseOutboxRows = 0;

  final LearningDatabase firstDb = await firstConnection.open();
  final LearningDatabase independentDb = await independentConnection.open();
  if (identical(firstDb, independentDb)) {
    throw StateError(
      'Recovery connections must be independent database objects.',
    );
  }

  final _RecoveryCourse course = await _prepareCourseRecovery(
    harness,
    firstConnection,
  );
  final String coursePayload = CourseLearningCommandCodec.canonicalCommand(
    course.command,
  );
  frozenPayloads['course'] = coursePayload;
  final LearningCommand firstCourseCommand =
      CourseLearningCommandCodec.decodeCanonicalCommand(
        coursePayload,
        scope: harness.courseDomainScope,
      );
  final LearningCommand replayCourseCommand =
      CourseLearningCommandCodec.decodeCanonicalCommand(
        coursePayload,
        scope: harness.courseDomainScope,
      );
  canonicalBytesIdentical['course'] = _sameUtf8Bytes(
    coursePayload,
    CourseLearningCommandCodec.canonicalCommand(replayCourseCommand),
  );
  replayedWithDecodedCommand['course'] = !identical(
    course.command,
    replayCourseCommand,
  );
  final LearningDatabase courseDb = await firstConnection.open();
  final String courseSnapshotBefore = await _scopeSnapshot(
    courseDb,
    harness.courseStorageScope,
  );
  beforeValues['course'] = courseSnapshotBefore;
  await courseDb.customStatement('''
    CREATE TRIGGER task9_reject_course_attempt_value
    BEFORE INSERT ON learning_attempt_values
    BEGIN SELECT RAISE(ABORT, 'task9 injected course failure'); END
  ''');
  final bool courseFailure = await _failsWithSaveError(
    course.repository.submit(firstCourseCommand),
  );
  await courseDb.customStatement(
    'DROP TRIGGER task9_reject_course_attempt_value',
  );
  await firstConnection.reopen();
  final String courseSnapshotAfter = await _scopeSnapshot(
    await firstConnection.open(),
    harness.courseStorageScope,
  );
  afterValues['course'] = courseSnapshotAfter;
  rolledBack['course'] =
      courseFailure && courseSnapshotBefore == courseSnapshotAfter;
  await course.repository.submit(firstCourseCommand); // Intentional lost ACK.
  final _ScopedSnapshot courseFirstCommit = await _readScopedSnapshot(
    independentDb,
    harness.courseStorageScope,
  );
  rowsAfterFirstCommit['course'] = courseFirstCommit.rows;
  countsAfterFirstCommit['course'] = courseFirstCommit.counts;
  attemptCounts['course'] = courseFirstCommit.counts['learning_attempts']!;
  final LearningCommit courseReplay = await harness
      .courseRepository(independentConnection)
      .submit(replayCourseCommand);
  final _ScopedSnapshot courseAfterReplay = await _readScopedSnapshot(
    independentDb,
    harness.courseStorageScope,
  );
  rowsAfterReplay['course'] = courseAfterReplay.rows;
  countsAfterReplay['course'] = courseAfterReplay.counts;
  duplicateReplay['course'] =
      courseReplay.duplicate &&
      courseAfterReplay.rows == courseFirstCommit.rows &&
      _sameCounts(courseAfterReplay.counts, courseFirstCommit.counts) &&
      courseAfterReplay.counts['learning_attempts'] == attemptCounts['course'];
  courseOutboxRows = await _rowCount(
    independentDb,
    'supported_sync_outbox',
    harness.courseStorageScope,
  );

  final _RecoveryComparison comparison = await _prepareComparisonRecovery(
    harness,
    firstConnection,
  );
  final String comparisonPayload =
      ComparisonLearningCommandCodec.canonicalCommand(comparison.command);
  frozenPayloads['comparison'] = comparisonPayload;
  final ComparisonLearningCommand firstComparisonCommand =
      ComparisonLearningCommandCodec.decodeCanonicalCommand(
        comparisonPayload,
        scope: harness.comparisonDomainScope,
        catalogue: harness.catalogue,
      );
  final ComparisonLearningCommand replayComparisonCommand =
      ComparisonLearningCommandCodec.decodeCanonicalCommand(
        comparisonPayload,
        scope: harness.comparisonDomainScope,
        catalogue: harness.catalogue,
      );
  canonicalBytesIdentical['comparison'] = _sameUtf8Bytes(
    comparisonPayload,
    ComparisonLearningCommandCodec.canonicalCommand(replayComparisonCommand),
  );
  replayedWithDecodedCommand['comparison'] = !identical(
    comparison.command,
    replayComparisonCommand,
  );
  final LearningDatabase comparisonDb = await firstConnection.open();
  final String comparisonSnapshotBefore = await _scopeSnapshot(
    comparisonDb,
    harness.comparisonStorageScope,
  );
  beforeValues['comparison'] = comparisonSnapshotBefore;
  await comparisonDb.customStatement('''
    CREATE TRIGGER task9_reject_comparison_evidence
    BEFORE INSERT ON learning_attempt_evidence
    BEGIN SELECT RAISE(ABORT, 'task9 injected comparison failure'); END
  ''');
  final bool comparisonFailure = await _failsWithSaveError(
    comparison.repository.submit(firstComparisonCommand),
  );
  await comparisonDb.customStatement(
    'DROP TRIGGER task9_reject_comparison_evidence',
  );
  await firstConnection.reopen();
  final String comparisonSnapshotAfter = await _scopeSnapshot(
    await firstConnection.open(),
    harness.comparisonStorageScope,
  );
  afterValues['comparison'] = comparisonSnapshotAfter;
  rolledBack['comparison'] =
      comparisonFailure && comparisonSnapshotBefore == comparisonSnapshotAfter;
  await comparison.repository.submit(
    firstComparisonCommand,
  ); // Intentional lost ACK.
  final _ScopedSnapshot comparisonFirstCommit = await _readScopedSnapshot(
    independentDb,
    harness.comparisonStorageScope,
  );
  rowsAfterFirstCommit['comparison'] = comparisonFirstCommit.rows;
  countsAfterFirstCommit['comparison'] = comparisonFirstCommit.counts;
  attemptCounts['comparison'] =
      comparisonFirstCommit.counts['learning_attempts']!;
  final ComparisonCommit comparisonReplay = await harness
      .comparisonRepository(independentConnection)
      .submit(replayComparisonCommand);
  final _ScopedSnapshot comparisonAfterReplay = await _readScopedSnapshot(
    independentDb,
    harness.comparisonStorageScope,
  );
  rowsAfterReplay['comparison'] = comparisonAfterReplay.rows;
  countsAfterReplay['comparison'] = comparisonAfterReplay.counts;
  duplicateReplay['comparison'] =
      comparisonReplay.duplicate &&
      comparisonAfterReplay.rows == comparisonFirstCommit.rows &&
      _sameCounts(comparisonAfterReplay.counts, comparisonFirstCommit.counts) &&
      comparisonAfterReplay.counts['learning_attempts'] ==
          attemptCounts['comparison'];

  final _RecoverySentence sentence = await _prepareSentenceRecovery(
    harness,
    firstConnection,
  );
  final String sentencePayload = SentenceHuntCommandCodec.canonicalCommand(
    sentence.command,
  );
  frozenPayloads['sentence-hunt'] = sentencePayload;
  final SentenceHuntLearningCommand firstSentenceCommand =
      SentenceHuntCommandCodec.decodeCanonicalCommand(
        sentencePayload,
        scope: harness.sentenceDomainScope,
        catalogue: harness.sentenceCatalogue,
      );
  final SentenceHuntLearningCommand replaySentenceCommand =
      SentenceHuntCommandCodec.decodeCanonicalCommand(
        sentencePayload,
        scope: harness.sentenceDomainScope,
        catalogue: harness.sentenceCatalogue,
      );
  canonicalBytesIdentical['sentence-hunt'] = _sameUtf8Bytes(
    sentencePayload,
    SentenceHuntCommandCodec.canonicalCommand(replaySentenceCommand),
  );
  replayedWithDecodedCommand['sentence-hunt'] = !identical(
    sentence.command,
    replaySentenceCommand,
  );
  final LearningDatabase sentenceDb = await firstConnection.open();
  final String sentenceSnapshotBefore = await _scopeSnapshot(
    sentenceDb,
    harness.sentenceStorageScope,
  );
  beforeValues['sentence-hunt'] = sentenceSnapshotBefore;
  await sentenceDb.customStatement('''
    CREATE TRIGGER task9_reject_sentence_evidence
    BEFORE INSERT ON learning_attempt_evidence
    BEGIN SELECT RAISE(ABORT, 'task9 injected sentence failure'); END
  ''');
  final bool sentenceFailure = await _failsWithSaveError(
    sentence.repository.submit(firstSentenceCommand),
  );
  await sentenceDb.customStatement(
    'DROP TRIGGER task9_reject_sentence_evidence',
  );
  await firstConnection.reopen();
  final String sentenceSnapshotAfter = await _scopeSnapshot(
    await firstConnection.open(),
    harness.sentenceStorageScope,
  );
  afterValues['sentence-hunt'] = sentenceSnapshotAfter;
  rolledBack['sentence-hunt'] =
      sentenceFailure && sentenceSnapshotBefore == sentenceSnapshotAfter;
  await sentence.repository.submit(
    firstSentenceCommand,
  ); // Intentional lost ACK.
  final _ScopedSnapshot sentenceFirstCommit = await _readScopedSnapshot(
    independentDb,
    harness.sentenceStorageScope,
  );
  rowsAfterFirstCommit['sentence-hunt'] = sentenceFirstCommit.rows;
  countsAfterFirstCommit['sentence-hunt'] = sentenceFirstCommit.counts;
  attemptCounts['sentence-hunt'] =
      sentenceFirstCommit.counts['learning_attempts']!;
  final SentenceHuntCommit sentenceReplay = await harness
      .sentenceHuntRepository(independentConnection)
      .submit(replaySentenceCommand);
  final _ScopedSnapshot sentenceAfterReplay = await _readScopedSnapshot(
    independentDb,
    harness.sentenceStorageScope,
  );
  rowsAfterReplay['sentence-hunt'] = sentenceAfterReplay.rows;
  countsAfterReplay['sentence-hunt'] = sentenceAfterReplay.counts;
  duplicateReplay['sentence-hunt'] =
      sentenceReplay.duplicate &&
      sentenceAfterReplay.rows == sentenceFirstCommit.rows &&
      _sameCounts(sentenceAfterReplay.counts, sentenceFirstCommit.counts) &&
      sentenceAfterReplay.counts['learning_attempts'] ==
          attemptCounts['sentence-hunt'];

  return LearningRecoveryEvidence(
    failedWritesRolledBack: rolledBack,
    rowValuesBeforeFailureByFamily: beforeValues,
    rowValuesAfterRollbackByFamily: afterValues,
    duplicateReplayDidNotAddAttempts: duplicateReplay,
    attemptCountAfterFirstCommit: attemptCounts,
    outboxRowsAfterReplay: courseOutboxRows,
    frozenCommandPayloads: frozenPayloads,
    canonicalPayloadBytesIdenticalByFamily: canonicalBytesIdentical,
    replayedWithDecodedCommandByFamily: replayedWithDecodedCommand,
    normalizedRowsAfterFirstCommitByFamily: rowsAfterFirstCommit,
    normalizedRowsAfterReplayByFamily: rowsAfterReplay,
    normalizedRowCountsAfterFirstCommitByFamily: countsAfterFirstCommit,
    normalizedRowCountsAfterReplayByFamily: countsAfterReplay,
  );
}

/// Exercises token/payload invalidation, content and policy fences, unsupported
/// schema versions, and unknown ACK no-op behavior against production adapters.
Future<LearningRecoveryControlEvidence> qualifyLearningRecoveryControls(
  LearningDatabaseHandle handle, {
  required String runId,
}) async {
  final _WorkloadHarness harness = _WorkloadHarness('$runId-controls');

  final _RecoveryCourse course = await _prepareCourseRecovery(harness, handle);
  final LearningDatabase database = await handle.open();
  await course.repository.submit(course.command);
  final String beforeChangedPayload = await _scopeSnapshot(
    database,
    harness.courseStorageScope,
  );
  final LearningCommand changedPayload = _differentCoursePayload(
    course.command,
    harness.registry.require(_courseActivityId),
  );
  final bool changedPayloadRejected = await _failsWithInvalidCommand(
    course.repository.submit(changedPayload),
  );
  final String afterChangedPayload = await _scopeSnapshot(
    database,
    harness.courseStorageScope,
  );
  final bool changedPayloadDidNotRewrite =
      beforeChangedPayload == afterChangedPayload;

  final int courseScopeId = await _scopeId(
    database,
    harness.courseStorageScope,
  );
  final String courseDataBeforeContentChange = await _attemptAndCompletionRows(
    database,
    courseScopeId,
  );
  await database.customStatement(
    'UPDATE learning_content_bindings SET content_revision = content_revision + 1 '
    'WHERE scope_id = ? AND activity_id = ?',
    <Object?>[courseScopeId, _courseActivityId],
  );
  final bool changedContentRejected = await _failsWithContentChanged(
    course.repository.load(),
  );
  final bool contentRowsUnchanged =
      courseDataBeforeContentChange ==
      await _attemptAndCompletionRows(database, courseScopeId);

  final _WorkloadHarness comparisonHarness = _WorkloadHarness('$runId-policy');
  final SqliteComparisonLearningRepository comparisonRepository =
      comparisonHarness.comparisonRepository(handle);
  ComparisonLearningState comparisonState = await comparisonRepository.load();
  comparisonState = (await comparisonRepository.submit(
    comparisonRepository.prepare(
      state: comparisonState,
      activityId: comparisonHarness.catalogue.activityId,
      action: StartComparisonRun(
        sessionId: 'task9-policy-control',
        policy: LessonPolicy(),
      ),
    ),
  )).state;
  for (final ComparisonExercise exercise
      in comparisonHarness.catalogue.exercises) {
    final LessonSectionSession session = _comparisonSession(
      comparisonState,
      comparisonHarness.catalogue,
    );
    final ComparePhonemesAnswer answer = _comparisonAnswer(
      comparisonHarness,
      exercise,
      runGeneration: comparisonState.slot!.cursor.generation,
      round: session.round,
      correct: true,
    );
    comparisonState = (await comparisonHarness.commitComparison(
      comparisonRepository,
      comparisonState,
      AnswerComparisonPair(answer),
    )).state;
    comparisonState = (await comparisonHarness.commitComparison(
      comparisonRepository,
      comparisonState,
      const AdvanceComparisonPair(),
    )).state;
  }
  comparisonState = (await comparisonHarness.commitComparison(
    comparisonRepository,
    comparisonState,
    const FinishComparisonRun(recordCompletion: true),
  )).state;
  final int comparisonScopeId = await _scopeId(
    database,
    comparisonHarness.comparisonStorageScope,
  );
  final String comparisonDataBeforePolicyChange =
      await _attemptAndCompletionRows(database, comparisonScopeId);
  await database.customStatement(
    'UPDATE learning_content_bindings SET policy_revision = policy_revision + 1 '
    'WHERE scope_id = ? AND activity_id = ?',
    <Object?>[comparisonScopeId, comparisonHarness.catalogue.activityId],
  );
  final bool changedPolicyRejected = await _failsWithContentChanged(
    comparisonRepository.load(),
  );
  final bool policyRowsUnchanged =
      comparisonDataBeforePolicyChange ==
      await _attemptAndCompletionRows(database, comparisonScopeId);

  final _WorkloadHarness versionHarness = _WorkloadHarness('$runId-version');
  final SqliteSentenceHuntLearningRepository sentenceRepository = versionHarness
      .sentenceHuntRepository(handle);
  await sentenceRepository.load();
  final int sentenceScopeId = await _scopeId(
    database,
    versionHarness.sentenceStorageScope,
  );
  final String sentenceDataBeforeVersionChange = await _scopeSnapshot(
    database,
    versionHarness.sentenceStorageScope,
  );
  await database.customStatement(
    'UPDATE learning_scopes SET schema_version = 99 WHERE id = ?',
    <Object?>[sentenceScopeId],
  );
  final bool unknownVersionRejected = await _failsWithUnsupportedVersion(
    sentenceRepository.load(),
  );
  final String sentenceDataAfterVersionChange = await _scopeSnapshot(
    database,
    versionHarness.sentenceStorageScope,
  );
  final bool versionRowsUnchanged =
      _withoutSchemaVersion(sentenceDataBeforeVersionChange) ==
      _withoutSchemaVersion(sentenceDataAfterVersionChange);

  final _WorkloadHarness ackHarness = _WorkloadHarness('$runId-ack');
  final CourseLearningState emptyCourseState = await ackHarness
      .courseRepository(handle)
      .load();
  final SqliteLearningCommandCoordinator<
    CourseLearningState,
    LearningCommand,
    LearningCommit
  >
  coordinator = SqliteLearningCommandCoordinator(
    database: handle,
    adapter: CourseLearningSqlAdapter(
      scope: ackHarness.courseDomainScope,
      transitions: ackHarness.transitions,
      historyLimit: harness.historyLimit,
    ),
    authGeneration: ackHarness.authGeneration,
    currentAuth: () => ackHarness.auth,
    backendOwner: () => ackHarness.owner,
    clock: ackHarness.now,
  );
  if (emptyCourseState.revision != 0) {
    throw StateError('Unknown-ACK control expected a new scope.');
  }
  final int changesBeforeUnknownAck = await _totalChanges(database);
  final int revisionBeforeUnknownAck = await _scopeRevision(
    database,
    ackHarness.courseStorageScope,
  );
  final int ordinalBeforeUnknownAck = await _scopeCommitOrdinal(
    database,
    ackHarness.courseStorageScope,
  );
  await coordinator.acknowledgeSupportedCourseEvents(<String>{
    'task9-no-such-outbox-event',
  });
  final bool unknownAckDidNotWrite =
      changesBeforeUnknownAck == await _totalChanges(database) &&
      revisionBeforeUnknownAck ==
          await _scopeRevision(database, ackHarness.courseStorageScope) &&
      ordinalBeforeUnknownAck ==
          await _scopeCommitOrdinal(database, ackHarness.courseStorageScope);

  return LearningRecoveryControlEvidence(
    changedPayloadRejected: changedPayloadRejected,
    changedPayloadDidNotRewrite: changedPayloadDidNotRewrite,
    changedContentRejectedWithoutRewrite:
        changedContentRejected && contentRowsUnchanged,
    changedPolicyRejectedWithoutRewrite:
        changedPolicyRejected && policyRowsUnchanged,
    unknownVersionRejectedWithoutRewrite:
        unknownVersionRejected && versionRowsUnchanged,
    unknownAckDidNotWrite: unknownAckDidNotWrite,
  );
}

/// Prepares two divergent course commands from the shared scope state. The
/// namespace must be unique per tab/call so exact-token reuse is not mistaken
/// for a replay of another command.
Future<LearningCommand> prepareCourseCommandProbe(
  LearningDatabaseHandle handle, {
  required String runId,
  required String commandNamespace,
  required bool correct,
}) async {
  final _WorkloadHarness harness = _WorkloadHarness(
    runId,
    tokenNamespace: commandNamespace,
  );
  final SqliteCourseLearningRepository repository = harness.courseRepository(
    handle,
  );
  CourseLearningState state = await repository.load();
  if (!state.activities.containsKey(_courseActivityId)) {
    state = (await repository.submit(
      repository.prepare(
        state: state,
        activityId: _courseActivityId,
        action: StartLearningRun(options: RunOptions()),
      ),
    )).state;
  }
  final LearningActivityDefinition definition = harness.registry.require(
    _courseActivityId,
  );
  final LearningSourceItem item = definition.items.first;
  final String selected = correct
      ? item.expectedChoice!
      : item.choices.firstWhere((String value) => value != item.expectedChoice);
  return repository.prepare(
    state: state,
    activityId: _courseActivityId,
    action: ChooseSound(
      selectedSound: selected,
      audioSource:
          authoredAudioSource(item) ?? AttemptAudioSource.practiceSpeech,
    ),
  );
}

String frozenCourseCommandPayload(LearningCommand command) =>
    CourseLearningCommandCodec.canonicalCommand(command);

LearningCommand decodeFrozenCourseCommand(
  String payload, {
  required LearningOwner owner,
}) => CourseLearningCommandCodec.decodeCanonicalCommand(
  payload,
  scope: LearningScope(courseId: 'en-fr', owner: owner),
);

Future<bool> submitFrozenCourseCommand(
  LearningDatabaseHandle handle,
  String payload, {
  required String runId,
}) async {
  final _WorkloadHarness harness = _WorkloadHarness(runId);
  final LearningCommand command = decodeFrozenCourseCommand(
    payload,
    owner: harness.owner,
  );
  final LearningCommit commit = await harness
      .courseRepository(handle)
      .submit(command);
  return commit.duplicate;
}

/// Reads persisted course attempt/receipt counts and the production repository's
/// current cursors for the qualification owner.
Future<Map<String, Object?>> inspectCourseQualificationState(
  LearningDatabaseHandle handle, {
  required String runId,
}) async {
  final _WorkloadHarness harness = _WorkloadHarness(runId);
  final CourseLearningState state = await harness
      .courseRepository(handle)
      .load();
  final LearningDatabase database = await handle.open();
  final Map<String, int> counts = await _readRowCounts(
    database,
    harness.courseStorageScope,
    family: 'course',
  );
  return <String, Object?>{
    'attempts': counts['attempts'],
    'receipts': counts['receipts'],
    'scopeRevision': state.revision,
    'commitOrdinal': state.commitOrdinal,
    'cursors': _courseCursorValues(state),
  };
}

const List<String> _families = <String>[
  'course',
  'comparison',
  'sentence-hunt',
];

Future<Map<String, int>> _readRowCounts(
  LearningDatabase database,
  LearningStorageScope scope, {
  required String family,
}) async {
  final int scopeId = await _scopeId(database, scope);
  final Map<String, String> tables = switch (family) {
    'course' => <String, String>{
      'attempts': 'learning_attempts',
      'receipts': 'learning_command_receipts',
      'attempt-values': 'learning_attempt_values',
      'attempt-evidence': 'learning_attempt_evidence',
      'mistakes': 'learning_mistakes',
      'summaries': 'learning_summaries',
      'completions': 'learning_completions',
      'exposure': 'learning_exposure',
      'outbox': 'supported_sync_outbox',
      'runs': 'learning_runs',
      'bindings': 'learning_content_bindings',
    },
    'comparison' => <String, String>{
      'attempts': 'learning_attempts',
      'receipts': 'learning_command_receipts',
      'attempt-values': 'learning_attempt_values',
      'attempt-evidence': 'learning_attempt_evidence',
      'mistakes': 'learning_mistakes',
      'summaries': 'learning_summaries',
      'completions': 'learning_completions',
      'exposure': 'learning_exposure',
      'outbox': 'supported_sync_outbox',
      'runs': 'learning_runs',
      'bindings': 'learning_content_bindings',
    },
    _ => <String, String>{
      'attempts': 'learning_attempts',
      'receipts': 'learning_command_receipts',
      'attempt-values': 'learning_attempt_values',
      'attempt-evidence': 'learning_attempt_evidence',
      'mistakes': 'learning_mistakes',
      'summaries': 'learning_summaries',
      'completions': 'learning_completions',
      'exposure': 'learning_exposure',
      'outbox': 'supported_sync_outbox',
      'runs': 'learning_runs',
      'bindings': 'learning_content_bindings',
    },
  };
  final Map<String, int> counts = <String, int>{};
  for (final MapEntry<String, String> entry in tables.entries) {
    counts[entry.key] = await _rowCountById(database, entry.value, scopeId);
  }
  return counts;
}

Future<int> _scopeId(
  LearningDatabase database,
  LearningStorageScope scope,
) async =>
    (await database
            .customSelect(
              'SELECT id FROM learning_scopes WHERE owner_kind = ? AND owner_id = ? '
              'AND course_id = ? AND family = ?',
              variables: <Variable<Object>>[
                Variable<String>(scope.ownerKind),
                Variable<String>(scope.ownerId),
                Variable<String>(scope.courseId),
                Variable<String>(scope.databaseFamily),
              ],
            )
            .getSingle())
        .read<int>('id');

Future<int> _rowCount(
  LearningDatabase database,
  String table,
  LearningStorageScope scope,
) async => _rowCountById(database, table, await _scopeId(database, scope));

Future<int> _rowCountById(
  LearningDatabase database,
  String table,
  int scopeId,
) async =>
    (await database
            .customSelect(
              'SELECT COUNT(*) AS row_count FROM $table WHERE scope_id = ?',
              variables: <Variable<Object>>[Variable<int>(scopeId)],
            )
            .getSingle())
        .read<int>('row_count');

final class _ScopedSnapshot {
  const _ScopedSnapshot(this.rows, this.counts);

  final String rows;
  final Map<String, int> counts;
}

Future<_ScopedSnapshot> _readScopedSnapshot(
  LearningDatabase database,
  LearningStorageScope scope,
) async {
  final String rows = await _scopeSnapshot(database, scope);
  final List<Object?> tables = jsonDecode(rows) as List<Object?>;
  final Map<String, int> counts = <String, int>{};
  for (final Object? tableValue in tables) {
    final Map<String, dynamic> table = tableValue as Map<String, dynamic>;
    counts[table['table']! as String] = (table['rows']! as List).length;
  }
  return _ScopedSnapshot(rows, counts);
}

bool _sameCounts(Map<String, int> left, Map<String, int> right) =>
    left.length == right.length &&
    left.entries.every(
      (MapEntry<String, int> entry) => right[entry.key] == entry.value,
    );

bool _sameUtf8Bytes(String frozen, String recanonicalized) {
  final List<int> frozenBytes = utf8.encode(frozen);
  final List<int> recanonicalizedBytes = utf8.encode(recanonicalized);
  if (frozenBytes.length != recanonicalizedBytes.length) return false;
  for (var index = 0; index < frozenBytes.length; index++) {
    if (frozenBytes[index] != recanonicalizedBytes[index]) return false;
  }
  return true;
}

Future<int> _logicalPageBytes(LearningDatabase database) async {
  final QueryRow pageCount = await database
      .customSelect('PRAGMA page_count')
      .getSingle();
  final QueryRow pageSize = await database
      .customSelect('PRAGMA page_size')
      .getSingle();
  return pageCount.read<int>('page_count') * pageSize.read<int>('page_size');
}

Map<String, int> _courseSummaryValues(CourseLearningState state) {
  final Iterable<SkillCount> summaries = state.summaries.values;
  return <String, int>{
    'typedAttempts': state.history.fold<int>(
      0,
      (int total, AttemptBatch batch) => total + batch.attempts.length,
    ),
    'summaryIdentities': state.summaries.length,
    'summaryTotal': summaries.fold<int>(
      0,
      (int total, SkillCount value) => total + value.total,
    ),
    'summaryCorrect': summaries.fold<int>(
      0,
      (int total, SkillCount value) => total + value.correct,
    ),
    'mistakes': state.mistakes.length,
    'completions': state.completions.length,
    'exposureIdentities': state.activities.values.fold<int>(
      0,
      (int total, ActivitySlot slot) => total + slot.exposures.length,
    ),
    'pendingOutbox': state.pending.length,
  };
}

Map<String, Object?> _courseCursorValues(
  CourseLearningState state,
) => <String, Object?>{
  'scopeRevision': state.revision,
  'commitOrdinal': state.commitOrdinal,
  'activities': <String, Object?>{
    for (final MapEntry<String, ActivitySlot> entry in state.activities.entries)
      entry.key: _cursorValues(
        generation: entry.value.cursor.generation,
        sequence: entry.value.cursor.sequence,
        revision: entry.value.cursor.revision,
      ),
  },
};

Map<String, Object?> _comparisonCursorValues(ComparisonLearningState state) =>
    <String, Object?>{
      'scopeRevision': state.revision,
      'commitOrdinal': state.commitOrdinal,
      'activity': state.slot?.activityId,
      'cursor': state.slot == null
          ? null
          : _cursorValues(
              generation: state.slot!.cursor.generation,
              sequence: state.slot!.cursor.sequence,
              revision: state.slot!.cursor.revision,
            ),
    };

Map<String, Object?> _sentenceCursorValues(
  SentenceHuntLearningState state,
) => <String, Object?>{
  'scopeRevision': state.revision,
  'commitOrdinal': state.commitOrdinal,
  'sections': <String, Object?>{
    for (final MapEntry<String, SentenceHuntSlot> entry in state.slots.entries)
      entry.key: _cursorValues(
        generation: entry.value.cursor.generation,
        sequence: entry.value.cursor.sequence,
        revision: entry.value.cursor.revision,
      ),
  },
};

Map<String, int> _cursorValues({
  required int generation,
  required int sequence,
  required int revision,
}) => <String, int>{
  'generation': generation,
  'sequence': sequence,
  'revision': revision,
};

Map<String, int> _comparisonSummaryValues(ComparisonLearningState state) {
  final Iterable<ComparisonPairSummary> summaries = state.summaries.values;
  return <String, int>{
    'typedAttempts': state.attempts.length,
    'typedReceipts': state.receipts.length,
    'summaryIdentities': state.summaries.length,
    'summaryTotal': summaries.fold<int>(
      0,
      (int total, ComparisonPairSummary value) =>
          total + value.firstInRun.total + value.repeatInRun.total,
    ),
    'summaryCorrect': summaries.fold<int>(
      0,
      (int total, ComparisonPairSummary value) =>
          total + value.firstInRun.correct + value.repeatInRun.correct,
    ),
    'mistakes': state.mistakes.length,
    'completions': state.completions.length,
  };
}

Map<String, int> _comparisonPersistedSummaryValues(
  ComparisonLearningState state,
) {
  final Iterable<ComparisonPairSummary> summaries = state.summaries.values;
  return <String, int>{
    'summaryIdentities': state.summaries.length * 3,
    'summaryTotal': summaries.fold<int>(
      0,
      (int total, ComparisonPairSummary value) =>
          total +
          value.firstInRun.total +
          value.repeatInRun.total +
          value.afterDebrief.total,
    ),
    'summaryCorrect': summaries.fold<int>(
      0,
      (int total, ComparisonPairSummary value) =>
          total +
          value.firstInRun.correct +
          value.repeatInRun.correct +
          value.afterDebrief.correct,
    ),
  };
}

Map<String, int> _sentencePersistedSummaryValues(
  SentenceHuntLearningState state,
) {
  final Iterable<SentenceHuntSummary> summaries = state.summaries.values;
  return <String, int>{
    'summaryIdentities': state.summaries.length * 4,
    'summaryTotal': summaries.fold<int>(
      0,
      (int total, SentenceHuntSummary value) =>
          total +
          value.firstInRun.total +
          value.repeatInRun.total +
          value.firstTeachingExposed.total +
          value.repeatTeachingExposed.total,
    ),
    'summaryCorrect': summaries.fold<int>(
      0,
      (int total, SentenceHuntSummary value) =>
          total +
          value.firstInRun.correct +
          value.repeatInRun.correct +
          value.firstTeachingExposed.correct +
          value.repeatTeachingExposed.correct,
    ),
  };
}

Map<String, int> _sentenceSummaryValues(SentenceHuntLearningState state) {
  final Iterable<SentenceHuntSummary> summaries = state.summaries.values;
  return <String, int>{
    'typedAttempts': state.attempts.length,
    'typedReceipts': state.receipts.length,
    'summaryIdentities': state.summaries.length,
    'summaryTotal': summaries.fold<int>(
      0,
      (int total, SentenceHuntSummary value) =>
          total + value.firstInRun.total + value.repeatInRun.total,
    ),
    'summaryCorrect': summaries.fold<int>(
      0,
      (int total, SentenceHuntSummary value) =>
          total + value.firstInRun.correct + value.repeatInRun.correct,
    ),
    'mistakes': state.mistakes.length,
    'completions': state.completions.length,
    'teachingExposure': state.teachingExposure.length,
    'slots': state.slots.length,
  };
}

String _courseLatestReceipt(CourseLearningState state) {
  final ActivitySlot latest = state.activities.values.reduce(
    (ActivitySlot left, ActivitySlot right) =>
        left.latestReceipt.commitOrdinal >= right.latestReceipt.commitOrdinal
        ? left
        : right,
  );
  return latest.latestReceipt.token;
}

String _sentenceLatestReceipt(SentenceHuntLearningState state) {
  final SentenceHuntSlot latest = state.slots.values.reduce(
    (SentenceHuntSlot left, SentenceHuntSlot right) =>
        left.latestReceipt.commitOrdinal >= right.latestReceipt.commitOrdinal
        ? left
        : right,
  );
  return latest.latestReceipt.token;
}

Future<void> _seedCourse(
  LearningDatabaseHandle handle,
  _WorkloadHarness harness,
) async {
  final Stopwatch writeWatch = Stopwatch()..start();
  final Stopwatch openWatch = Stopwatch()..start();
  await handle.open();
  openWatch.stop();
  final SqliteCourseLearningRepository repository = harness.courseRepository(
    handle,
  );
  final Stopwatch loadWatch = Stopwatch()..start();
  CourseLearningState state = await repository.load();
  loadWatch.stop();

  final LearningActivityDefinition legacyLesson = harness.registry.require(
    'lesson:en-fr-vowels',
  );
  state = await _submitCourse(
    repository,
    state,
    legacyLesson.id,
    StartLearningRun(options: RunOptions()),
  );
  for (var index = 0; index < legacyLesson.items.length; index++) {
    final LearningSourceItem item = legacyLesson.items[index];
    final String selected = index == 0
        ? item.choices.firstWhere(
            (String choice) => choice != item.expectedChoice,
          )
        : item.expectedChoice!;
    state = await _submitCourse(
      repository,
      state,
      legacyLesson.id,
      ChooseSound(
        selectedSound: selected,
        audioSource:
            authoredAudioSource(item) ?? AttemptAudioSource.practiceSpeech,
      ),
    );
    state = await _submitCourse(
      repository,
      state,
      legacyLesson.id,
      const AdvanceLesson(),
    );
  }
  state = await _submitCourse(
    repository,
    state,
    legacyLesson.id,
    const FinishLearningActivity(recordCompletion: true),
  );

  var retainedAttempts = _courseAttemptCount(state);
  state = await _startCourseWordGame(repository, state);
  var nextAttemptProgress = 250;
  var boardRestarts = 0;
  while (retainedAttempts < harness.historyLimit) {
    final int remaining = harness.historyLimit - retainedAttempts;
    final ActivitySlot slot = state.activities[_courseGameActivityId]!;
    final WordGameCheckpoint checkpoint = slot.snapshot as WordGameCheckpoint;
    final WordMatchEngine game = WordMatchEngine.fromState(
      checkpoint.board,
      random: Random(991),
    );
    final List<int> chain = _courseChainForRemaining(game, remaining);
    if (chain.isEmpty) {
      state = await _startCourseWordGame(repository, state);
      boardRestarts++;
      if (boardRestarts % 100 == 0) {
        print('TASK9 WORKLOAD course board restarts=$boardRestarts');
      }
      continue;
    }
    final int oldCount = _courseAttemptCount(state);
    state = await _submitCourse(
      repository,
      state,
      _courseGameActivityId,
      LinkWordTiles(indices: chain, elapsedSeconds: 0),
    );
    retainedAttempts = _courseAttemptCount(state);
    if (retainedAttempts - oldCount != chain.length) {
      throw StateError(
        'Course game fixture expected ${chain.length} rows; '
        'persisted ${retainedAttempts - oldCount}.',
      );
    }
    if (retainedAttempts >= nextAttemptProgress) {
      print(
        'TASK9 WORKLOAD course attempts=$retainedAttempts/${harness.historyLimit} '
        'elapsedMs=${writeWatch.elapsedMilliseconds}',
      );
      nextAttemptProgress += 250;
    }
  }

  final LearningDatabase database = await handle.open();
  final LearningStorageScope scope = harness.courseStorageScope;
  final int currentReceiptRows = await _rowCount(
    database,
    'learning_command_receipts',
    scope,
  );
  var receipts = currentReceiptRows;
  while (receipts < harness.historyLimit) {
    state = await _submitCourse(
      repository,
      state,
      _courseGameActivityId,
      StartLearningRun(options: RunOptions()),
    );
    receipts++;
    if (receipts % 250 == 0) {
      print(
        'TASK9 WORKLOAD course receipts=$receipts/${harness.historyLimit} '
        'elapsedMs=${writeWatch.elapsedMilliseconds}',
      );
    }
  }
  writeWatch.stop();
  _lastSeedDurations.putIfAbsent(harness.runId, () => <String, int>{})
    ..['course-open'] = openWatch.elapsedMilliseconds
    ..['course-load'] = loadWatch.elapsedMilliseconds
    ..['course-write'] = writeWatch.elapsedMilliseconds;
  print(
    'TASK9 WORKLOAD course complete attempts=$retainedAttempts '
    'receipts=$receipts elapsedMs=${writeWatch.elapsedMilliseconds}',
  );
}

List<int> _courseChainForRemaining(WordMatchEngine game, int remaining) {
  if (remaining < 3) {
    throw StateError('Course answer batches cannot finish with fewer than 3.');
  }
  final List<int> sizes = switch (remaining % 3) {
    0 => <int>[3],
    1 => <int>[4],
    _ => <int>[5, 4],
  };
  for (final int size in sizes) {
    if (size > remaining) continue;
    final List<int>? path = _targetPath(game, size);
    if (path != null) return path;
  }
  return <int>[];
}

List<int>? _targetPath(WordMatchEngine game, int length) {
  final List<int> eligible = <int>[
    for (var index = 0; index < game.board.length; index++)
      if (wordByText(game.board[index]).contains(game.target)) index,
  ];
  List<int>? visit(List<int> path) {
    if (path.length == length) return List<int>.of(path);
    for (final int next in eligible) {
      if (path.contains(next) || !game.adjacent(path.last, next)) continue;
      final List<int>? found = visit(<int>[...path, next]);
      if (found != null) return found;
    }
    return null;
  }

  for (final int start in eligible) {
    final List<int>? found = visit(<int>[start]);
    if (found != null) return found;
  }
  return null;
}

Future<CourseLearningState> _submitCourse(
  SqliteCourseLearningRepository repository,
  CourseLearningState state,
  String activityId,
  LearningAction action, {
  List<String>? receiptTrace,
}) async {
  final LearningCommand command = repository.prepare(
    state: state,
    activityId: activityId,
    action: action,
  );
  final String preparedToken = command.token;
  final String preparedCanonicalSqlPayload =
      CourseLearningCommandCodec.canonicalCommand(command);
  final LearningCommit commit = await repository.submit(command);
  receiptTrace?.add(
    jsonEncode(<Object?>[
      preparedToken,
      preparedCanonicalSqlPayload,
      commit.state.commitOrdinal,
    ]),
  );
  return commit.state;
}

int _courseAttemptCount(CourseLearningState state) => state.history.fold<int>(
  0,
  (int total, AttemptBatch batch) => total + batch.attempts.length,
);

Future<CourseLearningState> _startCourseWordGame(
  SqliteCourseLearningRepository repository,
  CourseLearningState state, {
  List<String>? receiptTrace,
}) async {
  final CourseLearningState started = await _submitCourse(
    repository,
    state,
    _courseGameActivityId,
    StartLearningRun(options: RunOptions()),
    receiptTrace: receiptTrace,
  );
  return _submitCourse(
    repository,
    started,
    _courseGameActivityId,
    CheckpointArcade(elapsedSeconds: 0, paused: false),
    receiptTrace: receiptTrace,
  );
}

Future<void> _seedComparison(
  LearningDatabaseHandle handle,
  _WorkloadHarness harness,
) async {
  final Stopwatch writeWatch = Stopwatch()..start();
  final Stopwatch openWatch = Stopwatch()..start();
  await handle.open();
  openWatch.stop();
  final SqliteComparisonLearningRepository repository = harness
      .comparisonRepository(handle);
  final Stopwatch loadWatch = Stopwatch()..start();
  ComparisonLearningState state = await repository.load();
  loadWatch.stop();
  var attempts = 0;
  var nextAttemptProgress = 250;
  while (attempts < harness.historyLimit) {
    state = (await harness.commitComparison(
      repository,
      state,
      StartComparisonRun(
        sessionId: 'task9-comparison-${(attempts ~/ 10)}',
        policy: LessonPolicy(),
      ),
    )).state;
    for (var indexInRun = 0; indexInRun < 10; indexInRun++) {
      final LessonSectionSession session = _comparisonSession(
        state,
        harness.catalogue,
      );
      final ComparisonExercise exercise = harness.catalogue.exercise(
        session.currentItemId!,
      );
      state = (await harness.commitComparison(
        repository,
        state,
        AnswerComparisonPair(
          _comparisonAnswer(
            harness,
            exercise,
            runGeneration: state.slot!.cursor.generation,
            round: session.round,
            correct: attempts != harness.historyLimit - 1,
          ),
        ),
      )).state;
      attempts++;
      if (attempts >= nextAttemptProgress) {
        print(
          'TASK9 WORKLOAD comparison attempts=$attempts/${harness.historyLimit} '
          'elapsedMs=${writeWatch.elapsedMilliseconds}',
        );
        nextAttemptProgress += 250;
      }
      state = (await harness.commitComparison(
        repository,
        state,
        const AdvanceComparisonPair(),
      )).state;
    }
    state = (await harness.commitComparison(
      repository,
      state,
      const FinishComparisonRun(recordCompletion: true),
    )).state;
  }
  writeWatch.stop();
  _lastSeedDurations.putIfAbsent(harness.runId, () => <String, int>{})
    ..['comparison-open'] = openWatch.elapsedMilliseconds
    ..['comparison-load'] = loadWatch.elapsedMilliseconds
    ..['comparison-write'] = writeWatch.elapsedMilliseconds;
  print(
    'TASK9 WORKLOAD comparison complete attempts=$attempts '
    'elapsedMs=${writeWatch.elapsedMilliseconds}',
  );
}

LessonSectionSession _comparisonSession(
  ComparisonLearningState state,
  ComparisonCatalogue catalogue,
) => LessonSectionSession.fromJson(
  Map<String, dynamic>.from(state.slot!.checkpoint.sessionJson),
  itemIds: catalogue.exercises
      .map((ComparisonExercise exercise) => exercise.id)
      .toList(growable: false),
  contentRevision: catalogue.contentRevision,
);

ComparePhonemesAnswer _comparisonAnswer(
  _WorkloadHarness harness,
  ComparisonExercise exercise, {
  required int runGeneration,
  required int round,
  required bool correct,
}) {
  final DateTime observedAt = harness.now();
  final PhonemeRelation selected = correct
      ? exercise.expectedRelation
      : exercise.expectedRelation == PhonemeRelation.same
      ? PhonemeRelation.different
      : PhonemeRelation.same;
  return ComparePhonemesAnswer(
    selectedRelation: selected,
    expectedRelationSnapshot: exercise.expectedRelation,
    observations: <ComparisonPlaybackObservation>[
      for (final ComparisonSampleContent sample in <ComparisonSampleContent>[
        exercise.sampleA,
        exercise.sampleB,
      ])
        ComparisonPlaybackObservation(
          slot: sample.slot,
          referenceId: sample.referenceId,
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.unverifiedRecording,
          activityId: exercise.activityId,
          runGeneration: runGeneration,
          round: round,
          pairId: exercise.id,
          profile: harness.comparisonDomainScope,
          uiGeneration: observedAt.millisecondsSinceEpoch,
        ),
    ],
  );
}

Future<void> _seedSentenceHunt(
  LearningDatabaseHandle handle,
  _WorkloadHarness harness,
) async {
  final Stopwatch writeWatch = Stopwatch()..start();
  final Stopwatch openWatch = Stopwatch()..start();
  await handle.open();
  openWatch.stop();
  final SqliteSentenceHuntLearningRepository repository = harness
      .sentenceHuntRepository(handle);
  final Stopwatch loadWatch = Stopwatch()..start();
  SentenceHuntLearningState state = await repository.load();
  loadWatch.stop();
  var attempts = 0;
  var nextAttemptProgress = 250;
  var run = 0;
  while (attempts < harness.historyLimit) {
    final SentenceHuntSection section = harness
        .sentenceCatalogue
        .sections[run % harness.sentenceCatalogue.sections.length];
    state = (await harness.commitSentence(
      repository,
      state,
      section.id,
      StartSentenceHuntRun(
        sessionId: 'task9-sentence-$run',
        policy: section.policy,
        mode: SentenceHuntRunMode.practice,
      ),
    )).state;
    for (var indexInRun = 0; indexInRun < section.items.length; indexInRun++) {
      final LessonSectionSession session = _sentenceSession(state, section);
      final SentenceHuntItem item = harness.sentenceCatalogue.item(
        section.id,
        session.currentItemId!,
      );
      final bool correct = attempts != harness.historyLimit - 1;
      state = (await harness.commitSentence(
        repository,
        state,
        section.id,
        AnswerSentenceHuntItem(
          _sentenceAnswer(
            harness,
            item,
            runGeneration: state.slots[section.id]!.cursor.generation,
            round: session.round,
            correct: correct,
          ),
        ),
      )).state;
      attempts++;
      if (attempts >= nextAttemptProgress) {
        print(
          'TASK9 WORKLOAD sentence-hunt attempts=$attempts/${harness.historyLimit} '
          'elapsedMs=${writeWatch.elapsedMilliseconds}',
        );
        nextAttemptProgress += 250;
      }
      state = (await harness.commitSentence(
        repository,
        state,
        section.id,
        const AdvanceSentenceHuntItem(),
      )).state;
    }
    state = (await harness.commitSentence(
      repository,
      state,
      section.id,
      const FinishSentenceHuntRun(),
    )).state;
    run++;
  }
  writeWatch.stop();
  _lastSeedDurations.putIfAbsent(harness.runId, () => <String, int>{})
    ..['sentence-hunt-open'] = openWatch.elapsedMilliseconds
    ..['sentence-hunt-load'] = loadWatch.elapsedMilliseconds
    ..['sentence-hunt-write'] = writeWatch.elapsedMilliseconds;
  print(
    'TASK9 WORKLOAD sentence-hunt complete attempts=$attempts '
    'elapsedMs=${writeWatch.elapsedMilliseconds}',
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

SentenceHuntAnswer _sentenceAnswer(
  _WorkloadHarness harness,
  SentenceHuntItem item, {
  required int runGeneration,
  required int round,
  required bool correct,
}) {
  final List<String> selected = correct
      ? item.expectedTokenIds
      : <String>[
          item.selectableTokenIds.firstWhere(
            (String id) => !item.expectedTokenIds.contains(id),
          ),
        ];
  return SentenceHuntAnswer(
    content: item.identity,
    selectedTokenIds: selected,
    expectedTokenIdsSnapshot: item.expectedTokenIds,
    playback: SentenceHuntPlaybackObservation(
      scope: harness.sentenceDomainScope,
      content: item.identity,
      runGeneration: runGeneration,
      round: round,
      uiGeneration: harness.clockCounter,
      referenceId: item.identity.audioRefId,
      outcome: CourseAudioOutcome.completed,
      source: CourseAudioSource.reviewedRecording,
    ),
  );
}

final class _RecoveryCourse {
  const _RecoveryCourse(this.repository, this.command);

  final SqliteCourseLearningRepository repository;
  final LearningCommand command;
}

final class _RecoveryComparison {
  const _RecoveryComparison(this.repository, this.command);

  final SqliteComparisonLearningRepository repository;
  final ComparisonLearningCommand command;
}

final class _RecoverySentence {
  const _RecoverySentence(this.repository, this.command);

  final SqliteSentenceHuntLearningRepository repository;
  final SentenceHuntLearningCommand command;
}

Future<_RecoveryCourse> _prepareCourseRecovery(
  _WorkloadHarness harness,
  LearningDatabaseHandle handle,
) async {
  final SqliteCourseLearningRepository repository = harness.courseRepository(
    handle,
  );
  CourseLearningState state = await repository.load();
  state = (await repository.submit(
    repository.prepare(
      state: state,
      activityId: _courseActivityId,
      action: StartLearningRun(options: RunOptions()),
    ),
  )).state;
  final LearningActivityDefinition definition = harness.registry.require(
    _courseActivityId,
  );
  final LearningSourceItem item = definition.items.first;
  final LearningCommand command = repository.prepare(
    state: state,
    activityId: _courseActivityId,
    action: ChooseSound(
      selectedSound: item.expectedChoice!,
      audioSource:
          authoredAudioSource(item) ?? AttemptAudioSource.practiceSpeech,
    ),
  );
  return _RecoveryCourse(repository, command);
}

Future<_RecoveryComparison> _prepareComparisonRecovery(
  _WorkloadHarness harness,
  LearningDatabaseHandle handle,
) async {
  final SqliteComparisonLearningRepository repository = harness
      .comparisonRepository(handle);
  ComparisonLearningState state = await repository.load();
  state = (await harness.commitComparison(
    repository,
    state,
    StartComparisonRun(
      sessionId: 'task9-recovery-comparison',
      policy: LessonPolicy(),
    ),
  )).state;
  final LessonSectionSession session = _comparisonSession(
    state,
    harness.catalogue,
  );
  final ComparisonExercise exercise = harness.catalogue.exercise(
    session.currentItemId!,
  );
  final ComparisonLearningCommand command = repository.prepare(
    state: state,
    activityId: harness.catalogue.activityId,
    action: AnswerComparisonPair(
      _comparisonAnswer(
        harness,
        exercise,
        runGeneration: state.slot!.cursor.generation,
        round: session.round,
        correct: true,
      ),
    ),
  );
  return _RecoveryComparison(repository, command);
}

Future<_RecoverySentence> _prepareSentenceRecovery(
  _WorkloadHarness harness,
  LearningDatabaseHandle handle,
) async {
  final SqliteSentenceHuntLearningRepository repository = harness
      .sentenceHuntRepository(handle);
  SentenceHuntLearningState state = await repository.load();
  final SentenceHuntSection section = harness.sentenceCatalogue.sections.first;
  state = (await harness.commitSentence(
    repository,
    state,
    section.id,
    StartSentenceHuntRun(
      sessionId: 'task9-recovery-sentence',
      policy: section.policy,
      mode: SentenceHuntRunMode.practice,
    ),
  )).state;
  final LessonSectionSession session = _sentenceSession(state, section);
  final SentenceHuntItem item = harness.sentenceCatalogue.item(
    section.id,
    session.currentItemId!,
  );
  final SentenceHuntLearningCommand command = repository.prepare(
    state: state,
    sectionId: section.id,
    action: AnswerSentenceHuntItem(
      _sentenceAnswer(
        harness,
        item,
        runGeneration: state.slots[section.id]!.cursor.generation,
        round: session.round,
        correct: true,
      ),
    ),
  );
  return _RecoverySentence(repository, command);
}

LearningCommand _differentCoursePayload(
  LearningCommand command,
  LearningActivityDefinition definition,
) {
  final LearningSourceItem item = definition.items.first;
  final String selected = item.choices.firstWhere(
    (String value) => value != item.expectedChoice,
  );
  final LearningCommand changed = LearningCommand(
    scope: command.scope,
    authGeneration: command.authGeneration,
    activityId: command.activityId,
    expected: command.expected,
    expectedScopeRevision: command.expectedScopeRevision,
    token: command.token,
    submittedAt: command.submittedAt,
    action: ChooseSound(
      selectedSound: selected,
      audioSource:
          authoredAudioSource(item) ?? AttemptAudioSource.practiceSpeech,
    ),
    draws: command.draws,
    candidate: command.candidate,
    feedback: command.feedback,
  );
  // The changed value is carried by a different token payload, not a mocked
  // repository result. The receipt lookup rejects it before state evaluation.
  return changed;
}

Future<bool> _failsWithSaveError(Future<Object?> operation) async {
  try {
    await operation;
  } on LearningSaveException {
    return true;
  } on Object {
    return false;
  }
  return false;
}

Future<bool> _failsWithInvalidCommand(Future<Object?> operation) async {
  try {
    await operation;
  } on LearningInvalidCommandException {
    return true;
  } on Object {
    return false;
  }
  return false;
}

Future<bool> _failsWithContentChanged(Future<Object?> operation) async {
  try {
    await operation;
  } on LearningContentChangedException {
    return true;
  } on Object {
    return false;
  }
  return false;
}

Future<bool> _failsWithUnsupportedVersion(Future<Object?> operation) async {
  try {
    await operation;
  } on LearningUnsupportedVersionException {
    return true;
  } on Object {
    return false;
  }
  return false;
}

Future<String> _scopeSnapshot(
  LearningDatabase database,
  LearningStorageScope scope,
) async {
  final int id = await _scopeId(database, scope);
  final List<Map<String, Object?>> snapshot = <Map<String, Object?>>[];
  final QueryRow scopeRow = await database
      .customSelect(
        'SELECT * FROM learning_scopes WHERE id = ?',
        variables: <Variable<Object>>[Variable<int>(id)],
      )
      .getSingle();
  snapshot.add(<String, Object?>{
    'table': 'learning_scopes',
    'rows': <Map<String, Object?>>[_stableRow(scopeRow)],
  });
  for (final String table in <String>[
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
  ]) {
    final List<QueryRow> rows = await database
        .customSelect(
          'SELECT * FROM $table WHERE scope_id = ? ORDER BY rowid',
          variables: <Variable<Object>>[Variable<int>(id)],
        )
        .get();
    snapshot.add(<String, Object?>{
      'table': table,
      'rows': rows.map(_stableRow).toList(growable: false),
    });
  }
  return jsonEncode(snapshot);
}

Map<String, Object?> _stableRow(QueryRow row) {
  final List<String> keys = row.data.keys.toList()..sort();
  return <String, Object?>{for (final String key in keys) key: row.data[key]};
}

Future<String> _attemptAndCompletionRows(
  LearningDatabase database,
  int scopeId,
) async {
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  for (final String table in <String>[
    'learning_attempts',
    'learning_attempt_values',
    'learning_attempt_evidence',
    'learning_completions',
  ]) {
    final List<QueryRow> result = await database
        .customSelect(
          'SELECT * FROM $table WHERE scope_id = ? ORDER BY rowid',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    rows.add(<String, Object?>{
      'table': table,
      'rows': result.map(_stableRow).toList(growable: false),
    });
  }
  return jsonEncode(rows);
}

String _withoutSchemaVersion(String snapshot) {
  final List<Object?> rows = jsonDecode(snapshot) as List<Object?>;
  final Map<String, Object?> scopeEntry = Map<String, Object?>.from(
    rows.first as Map,
  );
  final List<Object?> scopeRows = scopeEntry['rows'] as List<Object?>;
  final Map<String, Object?> scopeRow = Map<String, Object?>.from(
    scopeRows.single as Map,
  )..remove('schema_version');
  scopeEntry['rows'] = <Map<String, Object?>>[scopeRow];
  rows[0] = scopeEntry;
  return jsonEncode(rows);
}

Future<int> _totalChanges(LearningDatabase database) async =>
    (await database.customSelect('SELECT total_changes() AS value').getSingle())
        .read<int>('value');

Future<int> _scopeRevision(
  LearningDatabase database,
  LearningStorageScope scope,
) async =>
    (await database
            .customSelect(
              'SELECT revision FROM learning_scopes WHERE id = ?',
              variables: <Variable<Object>>[
                Variable<int>(await _scopeId(database, scope)),
              ],
            )
            .getSingle())
        .read<int>('revision');

Future<int> _scopeCommitOrdinal(
  LearningDatabase database,
  LearningStorageScope scope,
) async =>
    (await database
            .customSelect(
              'SELECT commit_ordinal FROM learning_scopes WHERE id = ?',
              variables: <Variable<Object>>[
                Variable<int>(await _scopeId(database, scope)),
              ],
            )
            .getSingle())
        .read<int>('commit_ordinal');

final class _WorkloadHarness {
  _WorkloadHarness(
    this.runId, {
    String? tokenNamespace,
    this.historyLimit = _retainedRows,
  }) : tokenNamespace = tokenNamespace ?? runId,
       owner = LearningOwner.account('sqlite-qualification-$runId'),
       courseDomainScope = LearningScope(
         courseId: 'en-fr',
         owner: LearningOwner.account('sqlite-qualification-$runId'),
       ),
       comparisonDomainScope = ComparisonProfileScope(
         courseId: 'en-fr',
         owner: LearningOwner.account('sqlite-qualification-$runId'),
       ),
       sentenceDomainScope = SentenceHuntProfileScope(
         courseId: 'en-fr',
         owner: LearningOwner.account('sqlite-qualification-$runId'),
       ),
       courseStorageScope = LearningStorageScope(
         owner: LearningOwner.account('sqlite-qualification-$runId'),
         courseId: 'en-fr',
         family: LearningFamily.course,
       ),
       comparisonStorageScope = LearningStorageScope(
         owner: LearningOwner.account('sqlite-qualification-$runId'),
         courseId: 'en-fr',
         family: LearningFamily.comparison,
       ),
       sentenceStorageScope = LearningStorageScope(
         owner: LearningOwner.account('sqlite-qualification-$runId'),
         courseId: 'en-fr',
         family: LearningFamily.sentenceHunt,
       ) {
    registry = LearningRegistry.french();
    transitions = LearningTransitionEngine(registry);
    catalogue = loadFrenchComparisonCatalogue();
    comparisonTransitions = ComparisonLearningTransitionEngine(
      catalogue: catalogue,
    );
    sentenceCatalogue = syntheticSentenceCatalogue(reviewed: true);
    sentenceTransitions = SentenceHuntTransitionEngine(
      catalogue: sentenceCatalogue,
    );
  }

  final String runId;
  final int historyLimit;
  final String tokenNamespace;
  final LearningOwner owner;
  final int authGeneration = learningQualificationAuthGeneration;
  final LearningScope courseDomainScope;
  final ComparisonProfileScope comparisonDomainScope;
  final SentenceHuntProfileScope sentenceDomainScope;
  final LearningStorageScope courseStorageScope;
  final LearningStorageScope comparisonStorageScope;
  final LearningStorageScope sentenceStorageScope;
  late final LearningRegistry registry;
  late final LearningTransitionEngine transitions;
  late final ComparisonCatalogue catalogue;
  late final ComparisonLearningTransitionEngine comparisonTransitions;
  late final SentenceHuntCatalogue sentenceCatalogue;
  late final SentenceHuntTransitionEngine sentenceTransitions;
  int _tokenCounter = 0;
  int clockCounter = 0;
  Random get random => Random(991);

  LearningAuthScope get auth =>
      LearningAuthScope(owner: owner, generation: authGeneration, ready: true);

  DateTime now() =>
      DateTime.utc(2026, 10, 19).add(Duration(seconds: clockCounter++));

  String nextToken() {
    final int namespaceHash = tokenNamespace.hashCode.abs();
    final String token =
        '${namespaceHash.toRadixString(36)}${(++_tokenCounter).toRadixString(36)}';
    if (token.length > 22) {
      throw StateError('Qualification token namespace is unexpectedly long.');
    }
    return token.padLeft(22, '0');
  }

  SqliteCourseLearningRepository courseRepository(
    LearningDatabaseHandle handle,
  ) => SqliteCourseLearningRepository(
    database: handle,
    scope: courseDomainScope,
    authGeneration: authGeneration,
    currentAuth: () => auth,
    backendOwner: () => owner,
    transitions: transitions,
    clock: now,
    newToken: nextToken,
    random: random,
    historyLimit: historyLimit,
  );

  SqliteComparisonLearningRepository comparisonRepository(
    LearningDatabaseHandle handle,
  ) => SqliteComparisonLearningRepository(
    database: handle,
    scope: comparisonDomainScope,
    authGeneration: authGeneration,
    currentAuth: () => auth,
    backendOwner: () => owner,
    transitions: comparisonTransitions,
    clock: now,
    newToken: nextToken,
    historyLimit: historyLimit,
  );

  SqliteSentenceHuntLearningRepository sentenceHuntRepository(
    LearningDatabaseHandle handle,
  ) => SqliteSentenceHuntLearningRepository(
    database: handle,
    scope: sentenceDomainScope,
    authGeneration: authGeneration,
    currentAuth: () => auth,
    backendOwner: () => owner,
    transitions: sentenceTransitions,
    clock: now,
    newToken: nextToken,
    historyLimit: historyLimit,
  );

  Future<ComparisonCommit> commitComparison(
    SqliteComparisonLearningRepository repository,
    ComparisonLearningState state,
    ComparisonAction action, {
    List<String>? receiptTrace,
  }) async {
    final ComparisonLearningCommand command = repository.prepare(
      state: state,
      activityId: catalogue.activityId,
      action: action,
    );
    final String preparedToken = command.token;
    final String preparedCanonicalSqlPayload =
        ComparisonLearningCommandCodec.canonicalCommand(command);
    final ComparisonCommit commit = await repository.submit(command);
    receiptTrace?.add(
      jsonEncode(<Object?>[
        preparedToken,
        preparedCanonicalSqlPayload,
        commit.state.commitOrdinal,
      ]),
    );
    return commit;
  }

  Future<SentenceHuntCommit> commitSentence(
    SqliteSentenceHuntLearningRepository repository,
    SentenceHuntLearningState state,
    String sectionId,
    SentenceHuntAction action, {
    List<String>? receiptTrace,
  }) async {
    final SentenceHuntLearningCommand command = repository.prepare(
      state: state,
      sectionId: sectionId,
      action: action,
    );
    final String preparedToken = command.token;
    final String preparedCanonicalSqlPayload =
        SentenceHuntCommandCodec.canonicalCommand(command);
    final SentenceHuntCommit commit = await repository.submit(command);
    receiptTrace?.add(
      jsonEncode(<Object?>[
        preparedToken,
        preparedCanonicalSqlPayload,
        commit.state.commitOrdinal,
      ]),
    );
    return commit;
  }
}
