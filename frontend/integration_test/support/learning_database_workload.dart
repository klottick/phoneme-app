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
import 'package:linguist/src/core/course/storage/course_learning_sql_adapter.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/learning_sql_transaction.dart';
import 'package:linguist/src/core/course/storage/learning_storage_scope.dart';
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_sql_repository.dart';
import 'package:linguist/src/features/arcade/word_match_engine.dart';

import '../../test/support/sentence_hunt_fixtures.dart';

const int _retainedRows = 2000;
const String _courseActivityId = 'lesson:en-fr-u-y';
const String _courseGameActivityId = 'arcade:word';
const int learningQualificationAuthGeneration = 17;

const Map<String, String> learningOverflowQualificationStatusByFamily =
    <String, String>{
      'course':
          'OPEN — SQL-backed 4,096/4,097 atomicity is not qualified. '
          'Validator-only synthetic tests cover activities, mistakes, '
          'summaries, completions, best scores, and exposure; they do not '
          'persist rows or prove SQLite overflow rollback.',
      'comparison':
          'OPEN — the public comparison catalogue requires exactly 10 '
          'exercises, so a valid 4,097th pair identity cannot be constructed '
          'without changing production content or validation. SQL overflow '
          'atomicity is not demonstrated.',
      'sentence-hunt':
          'OPEN — SQL-backed 4,096/4,097 atomicity is not qualified. Synthetic '
          'validator and SQL-adapter evaluation tests exercise valid aggregate '
          'identities in memory but do not persist rows or prove SQLite '
          'overflow rollback.',
    };

final Map<String, Map<String, int>> _lastSeedDurations =
    <String, Map<String, int>>{};

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
  });

  final Map<String, Map<String, int>> rowCountsByFamily;
  final Map<String, Map<String, int>> summaryValuesByFamily;
  final Map<String, String> latestReceiptByFamily;
  final Map<String, Object?> cursorValuesByFamily;
  final Map<String, int> logicalPageBytesByFamily;
  final Map<String, Map<String, int>> durationsMillisecondsByFamily;
  final Map<String, String> pruneResultByFamily;
  final Map<String, String> overflowResultByFamily;

  Map<String, Object?> toJson() => <String, Object?>{
    'rowCountsByFamily': rowCountsByFamily,
    'summaryValuesByFamily': summaryValuesByFamily,
    'latestReceiptByFamily': latestReceiptByFamily,
    'cursorValuesByFamily': cursorValuesByFamily,
    'logicalPageBytesByFamily': logicalPageBytesByFamily,
    'durationsMillisecondsByFamily': durationsMillisecondsByFamily,
    'pruneResultByFamily': pruneResultByFamily,
    'overflowResultByFamily': overflowResultByFamily,
  };
}

final class LearningRecoveryEvidence {
  const LearningRecoveryEvidence({
    required this.failedWritesRolledBack,
    required this.rowValuesBeforeFailureByFamily,
    required this.rowValuesAfterRollbackByFamily,
    required this.duplicateReplayDidNotAddAttempts,
    required this.attemptCountAfterFirstCommit,
    required this.outboxRowsAfterReplay,
    required this.frozenCommandPayloads,
  });

  final Map<String, bool> failedWritesRolledBack;
  final Map<String, String> rowValuesBeforeFailureByFamily;
  final Map<String, String> rowValuesAfterRollbackByFamily;
  final Map<String, bool> duplicateReplayDidNotAddAttempts;
  final Map<String, int> attemptCountAfterFirstCommit;
  final int outboxRowsAfterReplay;
  final Map<String, String> frozenCommandPayloads;

  Map<String, Object?> toJson() => <String, Object?>{
    'failedWritesRolledBack': failedWritesRolledBack,
    'rowValuesBeforeFailureByFamily': rowValuesBeforeFailureByFamily,
    'rowValuesAfterRollbackByFamily': rowValuesAfterRollbackByFamily,
    'duplicateReplayDidNotAddAttempts': duplicateReplayDidNotAddAttempts,
    'attemptCountAfterFirstCommit': attemptCountAfterFirstCommit,
    'outboxRowsAfterReplay': outboxRowsAfterReplay,
    'frozenCommandPayloads': frozenCommandPayloads,
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
}) async {
  final _WorkloadHarness harness = _WorkloadHarness(runId);
  await _seedCourse(handle, harness);
  await _seedComparison(handle, harness);
  await _seedSentenceHunt(handle, harness);
}

/// Loads every family through its production repository and reports normalized
/// row counts and typed aggregate values. Page bytes are database-wide logical
/// SQLite page size × page count, not a quota or device-capacity guarantee.
Future<LearningWorkloadReport> verifyLearningAtRetentionLimits(
  LearningDatabaseHandle handle, {
  required String runId,
}) async {
  final _WorkloadHarness harness = _WorkloadHarness(runId);
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

  final Map<String, String> pruneResults = <String, String>{
    for (final String family in _families)
      family:
          'retained attempts=${rowCounts[family]!['attempts']}, '
          'retained receipts=${rowCounts[family]!['receipts']}, '
          'typed summaries/mistakes/completions/exposure reloaded; '
          'latest receipt proof=${latestReceipts[family]}',
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
  );
}

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
    course.repository.submit(course.command),
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
  await course.repository.submit(course.command); // Intentional lost ACK.
  attemptCounts['course'] = await _rowCount(
    independentDb,
    'learning_attempts',
    harness.courseStorageScope,
  );
  frozenPayloads['course'] = CourseLearningCommandCodec.canonicalCommand(
    course.command,
  );
  final LearningCommit courseReplay = await harness
      .courseRepository(independentConnection)
      .submit(course.command);
  duplicateReplay['course'] =
      courseReplay.duplicate &&
      await _rowCount(
            independentDb,
            'learning_attempts',
            harness.courseStorageScope,
          ) ==
          attemptCounts['course'];
  courseOutboxRows = await _rowCount(
    independentDb,
    'supported_sync_outbox',
    harness.courseStorageScope,
  );

  final _RecoveryComparison comparison = await _prepareComparisonRecovery(
    harness,
    firstConnection,
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
    comparison.repository.submit(comparison.command),
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
    comparison.command,
  ); // Intentional lost ACK.
  attemptCounts['comparison'] = await _rowCount(
    independentDb,
    'learning_attempts',
    harness.comparisonStorageScope,
  );
  frozenPayloads['comparison'] = comparisonLearningSqlCanonicalCommand(
    comparison.command,
  );
  final ComparisonCommit comparisonReplay = await harness
      .comparisonRepository(independentConnection)
      .submit(comparison.command);
  duplicateReplay['comparison'] =
      comparisonReplay.duplicate &&
      await _rowCount(
            independentDb,
            'learning_attempts',
            harness.comparisonStorageScope,
          ) ==
          attemptCounts['comparison'];

  final _RecoverySentence sentence = await _prepareSentenceRecovery(
    harness,
    firstConnection,
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
    sentence.repository.submit(sentence.command),
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
  await sentence.repository.submit(sentence.command); // Intentional lost ACK.
  attemptCounts['sentence-hunt'] = await _rowCount(
    independentDb,
    'learning_attempts',
    harness.sentenceStorageScope,
  );
  frozenPayloads['sentence-hunt'] = sentenceHuntLearningSqlCanonicalCommand(
    sentence.command,
  );
  final SentenceHuntCommit sentenceReplay = await harness
      .sentenceHuntRepository(independentConnection)
      .submit(sentence.command);
  duplicateReplay['sentence-hunt'] =
      sentenceReplay.duplicate &&
      await _rowCount(
            independentDb,
            'learning_attempts',
            harness.sentenceStorageScope,
          ) ==
          attemptCounts['sentence-hunt'];

  return LearningRecoveryEvidence(
    failedWritesRolledBack: rolledBack,
    rowValuesBeforeFailureByFamily: beforeValues,
    rowValuesAfterRollbackByFamily: afterValues,
    duplicateReplayDidNotAddAttempts: duplicateReplay,
    attemptCountAfterFirstCommit: attemptCounts,
    outboxRowsAfterReplay: courseOutboxRows,
    frozenCommandPayloads: frozenPayloads,
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
      historyLimit: _retainedRows,
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
  while (retainedAttempts < _retainedRows) {
    final int remaining = _retainedRows - retainedAttempts;
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
        'TASK9 WORKLOAD course attempts=$retainedAttempts/$_retainedRows '
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
  while (receipts < _retainedRows) {
    state = await _submitCourse(
      repository,
      state,
      _courseGameActivityId,
      StartLearningRun(options: RunOptions()),
    );
    receipts++;
    if (receipts % 250 == 0) {
      print(
        'TASK9 WORKLOAD course receipts=$receipts/$_retainedRows '
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
  LearningAction action,
) async => (await repository.submit(
  repository.prepare(state: state, activityId: activityId, action: action),
)).state;

int _courseAttemptCount(CourseLearningState state) => state.history.fold<int>(
  0,
  (int total, AttemptBatch batch) => total + batch.attempts.length,
);

Future<CourseLearningState> _startCourseWordGame(
  SqliteCourseLearningRepository repository,
  CourseLearningState state,
) async {
  final CourseLearningState started = await _submitCourse(
    repository,
    state,
    _courseGameActivityId,
    StartLearningRun(options: RunOptions()),
  );
  return _submitCourse(
    repository,
    started,
    _courseGameActivityId,
    CheckpointArcade(elapsedSeconds: 0, paused: false),
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
  while (attempts < _retainedRows) {
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
            correct: attempts != _retainedRows - 1,
          ),
        ),
      )).state;
      attempts++;
      if (attempts >= nextAttemptProgress) {
        print(
          'TASK9 WORKLOAD comparison attempts=$attempts/$_retainedRows '
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
  while (attempts < _retainedRows) {
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
      final bool correct = attempts != _retainedRows - 1;
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
          'TASK9 WORKLOAD sentence-hunt attempts=$attempts/$_retainedRows '
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
  _WorkloadHarness(this.runId, {String? tokenNamespace})
    : tokenNamespace = tokenNamespace ?? runId,
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
  );

  Future<ComparisonCommit> commitComparison(
    SqliteComparisonLearningRepository repository,
    ComparisonLearningState state,
    ComparisonAction action,
  ) => repository.submit(
    repository.prepare(
      state: state,
      activityId: catalogue.activityId,
      action: action,
    ),
  );

  Future<SentenceHuntCommit> commitSentence(
    SqliteSentenceHuntLearningRepository repository,
    SentenceHuntLearningState state,
    String sectionId,
    SentenceHuntAction action,
  ) => repository.submit(
    repository.prepare(state: state, sectionId: sectionId, action: action),
  );
}
