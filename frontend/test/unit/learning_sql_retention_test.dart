import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/french_course.dart' show wordByText;
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_sql_repository.dart';
import 'package:linguist/src/features/arcade/word_match_engine.dart';
import '../../integration_test/support/learning_database_workload.dart';
import '../support/sentence_hunt_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final String? retainedFixturePath =
      Platform.environment['TASK9_RETAINED_FIXTURE'];

  test('small_course_history_prunes_whole_sql_answer_batches', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'sqlite-learning-small-prune-',
    );
    final File file = File('${directory.path}/learning.sqlite');
    LearningDatabaseHandle handle = _fileHandle(file);
    try {
      final _CoursePruneFixture fixture = _CoursePruneFixture(handle);
      CourseLearningState state = await fixture.repository.load();
      state = await fixture.startWordRun(state);
      state = await fixture.linkFourWordTiles(state);
      final AttemptBatch evictedBatch = state.history.single;
      expect(evictedBatch.attempts, hasLength(4));

      state = await fixture.startWordRun(state);
      state = await fixture.linkFourWordTiles(state);
      final AttemptBatch survivingBatch = state.history.single;
      expect(survivingBatch.token, isNot(evictedBatch.token));
      expect(survivingBatch.attempts, hasLength(4));
      expect(
        survivingBatch.attempts.map(
          (CourseAttempt attempt) => attempt.batchIndex,
        ),
        <int>[0, 1, 2, 3],
      );

      final LearningDatabase database = await handle.open();
      final QueryRow scopeRow = await database
          .customSelect(
            'SELECT id FROM learning_scopes WHERE owner_kind = ? AND owner_id = ? '
            'AND course_id = ? AND family = ?',
            variables: <Variable<Object>>[
              const Variable<String>('account'),
              Variable<String>(fixture.owner.userId!),
              const Variable<String>('en-fr'),
              const Variable<String>('course'),
            ],
          )
          .getSingle();
      final List<QueryRow> sqlAttempts = await database
          .customSelect(
            'SELECT attempt_id, batch_index FROM learning_attempts '
            'WHERE scope_id = ? AND activity_id = ? ORDER BY commit_ordinal, batch_index',
            variables: <Variable<Object>>[
              Variable<int>(scopeRow.read<int>('id')),
              const Variable<String>('arcade:word'),
            ],
          )
          .get();
      final List<String> sqlAttemptIds = <String>[
        for (final QueryRow row in sqlAttempts) row.read<String>('attempt_id'),
      ];
      final List<String> expectedSurvivors = survivingBatch.attempts
          .map((CourseAttempt attempt) => attempt.submissionId)
          .toList(growable: false);
      expect(sqlAttemptIds, expectedSurvivors);
      expect(
        sqlAttemptIds,
        isNot(contains(evictedBatch.attempts.first.submissionId)),
      );
      expect(
        sqlAttempts.map((QueryRow row) => row.read<int>('batch_index')),
        <int>[0, 1, 2, 3],
      );

      await handle.close();
      handle = _fileHandle(file);
      final CourseLearningState afterReopen = await _CoursePruneFixture(
        handle,
      ).repository.load();
      expect(afterReopen.history, hasLength(1));
      expect(afterReopen.history.single.token, survivingBatch.token);
      expect(afterReopen.history.single.attempts, hasLength(4));
    } finally {
      await handle.close();
      await directory.delete(recursive: true);
    }
  });

  test('bounded_family_pruning_preserves_receipt_and_aggregate_values', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'sqlite-learning-bounded-proof-',
    );
    final LearningDatabaseHandle handle = _fileHandle(
      File('${directory.path}/learning.sqlite'),
    );
    try {
      await seedLearningAtRetentionLimits(
        handle,
        runId: 'bounded-proof',
        historyLimit: 20,
      );
      final LearningWorkloadReport report =
          await verifyLearningAtRetentionLimits(
            handle,
            runId: 'bounded-proof',
            historyLimit: 20,
          );
      for (final String family in <String>[
        'course',
        'comparison',
        'sentence-hunt',
      ]) {
        final Map<String, Object?> evidence =
            report.postCapPruneEvidenceByFamily[family]!;
        expect(evidence['receiptIdentitiesBefore'], isNotEmpty);
        expect(evidence['receiptIdentitiesAfter'], isNotEmpty);
        expect(evidence['expectedNewCommandReceiptIdentities'], isNotEmpty);
        expect(
          evidence['receiptIdentitiesAfter'],
          evidence['expectedRetainedReceiptIdentities'],
          reason: '$family exact prepared-command receipt identities',
        );
        expect(
          evidence['receiptCommitOrdinalDelta'],
          (evidence['expectedNewCommandReceiptIdentities']! as List).length,
        );
        expect(evidence['receiptExpectedIdentityMatch'], isTrue);
        expect(evidence['receiptOrdinalsConsecutive'], isTrue);
        expect(
          evidence['receiptPrunePreservedExpectedIdentities'],
          isTrue,
          reason: '$family receipt identity/ordinal pruning',
        );
        expect(evidence['currentRunLatestReceiptPersisted'], isTrue);
        expect(evidence['aggregateSqlMatchesExpected'], isTrue);
        expect(evidence['aggregateSqlMatchesTypedBefore'], isTrue);
        expect(evidence['aggregateSqlMatchesTypedExpectedAfter'], isTrue);
        expect(evidence['aggregateUnaffectedRowsPreserved'], isTrue);
        expect(evidence['aggregatePreservedIdentityCount'], greaterThan(0));
        expect(evidence['aggregateExpectedBeforeRows'], isNotEmpty);
        expect(evidence['aggregateExpectedAfterRows'], isNotEmpty);
        expect(evidence['aggregateNegativeControlsRejected'], isTrue);
        final Map<String, Object?> projectionByTable =
            evidence['aggregateProjectionByTable']! as Map<String, Object?>;
        final Map<String, Object?> tableProof =
            projectionByTable['tableValueProof']! as Map<String, Object?>;
        expect(tableProof, isNotEmpty);
        for (final MapEntry<String, Object?> table in tableProof.entries) {
          final Map<String, Object?> proof =
              table.value! as Map<String, Object?>;
          expect(
            proof['beforeMatchesTyped'],
            isTrue,
            reason: '$family ${table.key} BEFORE',
          );
          expect(
            proof['afterMatchesTypedTransition'],
            isTrue,
            reason: '$family ${table.key} AFTER',
          );
          expect(
            proof['beforeRowCount'],
            greaterThan(0),
            reason: '$family ${table.key} baseline',
          );
        }
          // ignore: avoid_print
          print(
          'TASK9 AGGREGATE family=$family proof=${jsonEncode(<String, Object?>{'sqlBefore': evidence['aggregateSqlBefore'], 'typedBefore': evidence['aggregateExpectedBeforeRows'], 'sqlAfter': evidence['aggregateSqlAfter'], 'typedExpectedAfter': evidence['aggregateExpectedAfterRows'], 'tableProof': tableProof, 'unaffectedRowsPreserved': evidence['aggregateUnaffectedRowsPreserved'], 'preservedIdentityCount': evidence['aggregatePreservedIdentityCount'], 'negativeControlsRejected': evidence['aggregateNegativeControlsRejected']})}',
        );
        expect(evidence['aggregateBefore'], isNotEmpty);
        expect(evidence['aggregateExpectedAfter'], isNotEmpty);
        expect(
          evidence['aggregateReloadedAfter'],
          evidence['aggregateExpectedAfter'],
        );
        final Map<String, List<String>> sqlBefore =
            evidence['aggregateSqlBefore']! as Map<String, List<String>>;
        final Map<String, List<String>> sqlAfter =
            evidence['aggregateSqlAfter']! as Map<String, List<String>>;
        expect(sqlBefore['learning_summaries'], isNotEmpty);
        expect(sqlAfter['learning_summaries'], isNotEmpty);
        expect(sqlBefore['learning_mistakes'], isNotEmpty);
        expect(sqlAfter['learning_mistakes'], isNotEmpty);
        expect(sqlBefore['learning_completions'], isNotEmpty);
        expect(sqlAfter['learning_completions'], isNotEmpty);
        final Map<String, int> expected =
            (evidence['aggregateSqlExpectedAfter'] ??
                    evidence['aggregateExpectedAfter'])!
                as Map<String, int>;
        final Map<String, int> sqlValues =
            evidence['aggregateSqlValuesAfter']! as Map<String, int>;
        expect(sqlValues['summaryIdentities'], expected['summaryIdentities']);
        expect(
          sqlValues['summaryTotal'],
          expected['summaryTotal'],
          reason: '$family direct SQL summary total vs typed transition',
        );
        expect(
          sqlValues['summaryCorrect'],
          expected['summaryCorrect'],
          reason: '$family direct SQL summary correct vs typed transition',
        );
      }
    } finally {
      await handle.close();
      await directory.delete(recursive: true);
    }
  });

  test('all_families_reopen_at_limits_without_summary_drift', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'sqlite-learning-retention-',
    );
    final File file = File('${directory.path}/learning.sqlite');
    LearningDatabaseHandle handle = _fileHandle(file);
    try {
      await seedLearningAtRetentionLimits(handle, runId: 'retention-test');
      final LearningWorkloadReport beforeClose =
          await verifyLearningAtRetentionLimits(
            handle,
            runId: 'retention-test',
          );
      await handle.close();

      handle = _fileHandle(file);
      final LearningWorkloadReport afterReopen =
          await verifyLearningAtRetentionLimits(
            handle,
            runId: 'retention-test',
          );

      for (final String family in <String>[
        'course',
        'comparison',
        'sentence-hunt',
      ]) {
        final Map<String, Object?> pruneEvidence =
            afterReopen.postCapPruneEvidenceByFamily[family]!;
        expect(pruneEvidence['observed'], isTrue);
        expect(pruneEvidence['attemptCountBefore'], 2000);
        expect(pruneEvidence['receiptCountBefore'], 2000);
        expect(pruneEvidence['attemptCountAfter'], lessThanOrEqualTo(2000));
        expect(pruneEvidence['receiptCountAfter'], 2000);
        expect(pruneEvidence['newAttemptIds'], isNotEmpty);
        expect(pruneEvidence['evictedAttemptIds'], isNotEmpty);
        expect(pruneEvidence['survivingAttemptIds'], isNotEmpty);
        expect(pruneEvidence['sqlRowsMatchReloadedState'], isTrue);
        expect(
          (pruneEvidence['newAttemptIds']! as List).length,
          pruneEvidence['expectedNewAttemptCount'],
        );
        expect(
          pruneEvidence['attemptIdsAfter'],
          pruneEvidence['sqlAttemptIdsAfter'],
        );
        expect(pruneEvidence['sqlRowsMatchExpectedRetainedIds'], isTrue);
        expect(
          afterReopen.rowCountsByFamily[family]?['attempts'],
          pruneEvidence['attemptCountAfter'],
        );
        expect(afterReopen.rowCountsByFamily[family]?['receipts'], 2000);
        expect(
          beforeClose.rowCountsByFamily[family]?['attempts'],
          afterReopen.rowCountsByFamily[family]?['attempts'],
        );
        expect(beforeClose.rowCountsByFamily[family]?['receipts'], 2000);
        expect(
          afterReopen.rowCountsByFamily[family],
          beforeClose.rowCountsByFamily[family],
        );
        expect(
          afterReopen.summaryValuesByFamily[family],
          beforeClose.summaryValuesByFamily[family],
        );
        expect(
          afterReopen.latestReceiptByFamily[family],
          beforeClose.latestReceiptByFamily[family],
        );
        expect(
          afterReopen.rowCountsByFamily[family]?['summaries'],
          greaterThan(0),
        );
        expect(
          afterReopen.rowCountsByFamily[family]?['completions'],
          greaterThan(0),
        );
        expect(
          afterReopen.summaryValuesByFamily[family]?['summaryTotal'],
          greaterThanOrEqualTo(2000),
        );
        expect(
          afterReopen.pruneResultByFamily[family],
          contains('OBSERVED post-cap write/prune'),
        );
      }
      final Map<String, Object?> coursePrune =
          afterReopen.postCapPruneEvidenceByFamily['course']!;
      expect(coursePrune['completeCourseBatches'], isTrue);
      expect(coursePrune['completeEvictedBatches'], isTrue);
      expect(coursePrune['evictedBatchTokens'], isNotEmpty);
      expect(coursePrune['survivingBatchTokens'], isNotEmpty);
      expect(coursePrune['evictedBatchAttemptIds'], everyElement(isNotEmpty));
      expect(coursePrune['survivingBatchAttemptIds'], everyElement(isNotEmpty));
      expect(
        afterReopen.rowCountsByFamily['course']?['mistakes'],
        greaterThan(0),
      );
      expect(
        afterReopen.rowCountsByFamily['course']?['exposure'],
        greaterThan(0),
      );
      expect(
        afterReopen.rowCountsByFamily['comparison']?['mistakes'],
        greaterThan(0),
      );
      expect(
        afterReopen.rowCountsByFamily['sentence-hunt']?['mistakes'],
        greaterThan(0),
      );
      expect(afterReopen.rowCountsByFamily['sentence-hunt']?['exposure'], 3);
      expect(afterReopen.logicalPageBytesByFamily.values.toSet(), hasLength(1));
      // ignore: avoid_print
      print('TASK9 RETENTION ${afterReopen.toJson()}');
    } finally {
      await handle.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 90)));

  test(
    'bounded_retained_fixture_performance_diagnostic',
    () async {
      final Map<String, Object?> evidence =
          await _diagnoseRetainedSentenceHuntFixture(retainedFixturePath!);
      expect(evidence['attemptCountBefore'], 786);
      expect(evidence['receiptCountBefore'], 1887);
      expect(evidence['receiptPayloadBytesBefore'], greaterThan(12000000));
      expect(evidence['copiedFileBytes'], evidence['sourceFileBytes']);
      expect(evidence['answerWasSubmitted'], isTrue);
      expect(
        evidence['totalDiagnosticMilliseconds'],
        lessThanOrEqualTo(120000),
      );
      // ignore: avoid_print
      print('TASK9 RETAINED FIXTURE PERFORMANCE ${jsonEncode(evidence)}');
    },
    skip: retainedFixturePath == null
        ? 'Set TASK9_RETAINED_FIXTURE to a retained fixture path.'
        : false,
    timeout: const Timeout(Duration(seconds: 120)),
  );
}

LearningDatabaseHandle _fileHandle(File file) => LearningDatabaseHandle(
  open: () async => LearningDatabase(DatabaseConnection(NativeDatabase(file))),
);

Future<Map<String, Object?>> _diagnoseRetainedSentenceHuntFixture(
  String sourcePath,
) async {
  final Stopwatch totalWatch = Stopwatch()..start();
  final File source = File(sourcePath);
  expect(await source.exists(), isTrue);
  final Directory copyDirectory = await Directory.systemTemp.createTemp(
    'sqlite-learning-retained-diagnostic-',
  );
  final File copy = File('${copyDirectory.path}/learning-copy.sqlite');
  await source.copy(copy.path);
  final int sourceBytes = await source.length();
  final int copyBytes = await copy.length();
  expect(copyBytes, sourceBytes);

  final LearningDatabaseHandle handle = _fileHandle(copy);
  try {
    final LearningDatabase database = await handle.open();
    final QueryRow scopeRow = await database
        .customSelect(
          'SELECT id, owner_id FROM learning_scopes WHERE family = ? '
          'ORDER BY id LIMIT 1',
          variables: const <Variable<String>>[
            Variable<String>('sentence-hunt'),
          ],
        )
        .getSingle();
    final int scopeId = scopeRow.read<int>('id');
    final LearningOwner owner = LearningOwner.account(
      scopeRow.read<String>('owner_id'),
    );
    final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: owner,
    );
    final SentenceHuntCatalogue catalogue = syntheticSentenceCatalogue(
      reviewed: true,
    );
    var tokenCounter = 0;
    var clockCounter = 0;
    var uiGeneration = 0;
    final SqliteSentenceHuntLearningRepository repository =
        SqliteSentenceHuntLearningRepository(
          database: handle,
          scope: scope,
          authGeneration: 17,
          currentAuth: () =>
              LearningAuthScope(owner: owner, generation: 17, ready: true),
          backendOwner: () => owner,
          transitions: SentenceHuntTransitionEngine(catalogue: catalogue),
          clock: () =>
              DateTime.utc(2026, 10, 20).add(Duration(seconds: clockCounter++)),
          newToken: () => 'diagnostic${(++tokenCounter).toRadixString(36)}'
              .padLeft(22, '0'),
        );
    final QueryRow sourceCounts = await database
        .customSelect(
          'SELECT '
          '(SELECT COUNT(*) FROM learning_attempts WHERE scope_id = ?) AS attempts, '
          '(SELECT COUNT(*) FROM learning_command_receipts WHERE scope_id = ?) AS receipts, '
          '(SELECT COALESCE(SUM(length(CAST(canonical_payload AS BLOB))), 0) '
          'FROM learning_command_receipts WHERE scope_id = ?) AS receipt_payload_bytes',
          variables: <Variable<Object>>[
            Variable<int>(scopeId),
            Variable<int>(scopeId),
            Variable<int>(scopeId),
          ],
        )
        .getSingle();
    final Stopwatch loadWatch = Stopwatch()..start();
    SentenceHuntLearningState state = await repository.load();
    loadWatch.stop();
    final int attemptsBefore = state.attempts.length;
    final SentenceHuntSection section = catalogue.sections.first;

    final Stopwatch startPrepareWatch = Stopwatch()..start();
    final SentenceHuntLearningCommand startCommand = repository.prepare(
      state: state,
      sectionId: section.id,
      action: StartSentenceHuntRun(
        sessionId: 'task9-diagnostic-${copyDirectory.path.hashCode.abs()}',
        policy: section.policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );
    startPrepareWatch.stop();
    final Stopwatch startSubmitWatch = Stopwatch()..start();
    state = (await repository.submit(startCommand)).state;
    startSubmitWatch.stop();

    final LessonSectionSession session = LessonSectionSession.fromJson(
      Map<String, dynamic>.from(
        state.slots[section.id]!.checkpoint.sessionJson,
      ),
      itemIds: section.items
          .map((SentenceHuntItem item) => item.identity.itemId)
          .toList(growable: false),
      contentRevision: section.contentRevision,
    );
    final SentenceHuntItem item = catalogue.item(
      section.id,
      session.currentItemId!,
    );
    final SentenceHuntAnswer answer = SentenceHuntAnswer(
      content: item.identity,
      selectedTokenIds: item.expectedTokenIds,
      expectedTokenIdsSnapshot: item.expectedTokenIds,
      playback: SentenceHuntPlaybackObservation(
        scope: scope,
        content: item.identity,
        runGeneration: state.slots[section.id]!.cursor.generation,
        round: session.round,
        uiGeneration: uiGeneration++,
        referenceId: item.identity.audioRefId,
        outcome: CourseAudioOutcome.completed,
        source: CourseAudioSource.reviewedRecording,
      ),
    );
    final Stopwatch answerPrepareWatch = Stopwatch()..start();
    final SentenceHuntLearningCommand answerCommand = repository.prepare(
      state: state,
      sectionId: section.id,
      action: AnswerSentenceHuntItem(answer),
    );
    answerPrepareWatch.stop();
    final Stopwatch answerSubmitWatch = Stopwatch()..start();
    state = (await repository.submit(answerCommand)).state;
    answerSubmitWatch.stop();

    final int attemptsAfter =
        (await database
                .customSelect(
                  'SELECT COUNT(*) AS count FROM learning_attempts WHERE scope_id = ?',
                  variables: <Variable<Object>>[Variable<int>(scopeId)],
                )
                .getSingle())
            .read<int>('count');
    final int receiptsAfter =
        (await database
                .customSelect(
                  'SELECT COUNT(*) AS count FROM learning_command_receipts WHERE scope_id = ?',
                  variables: <Variable<Object>>[Variable<int>(scopeId)],
                )
                .getSingle())
            .read<int>('count');
    totalWatch.stop();
    if (totalWatch.elapsed > const Duration(seconds: 120)) {
      throw TimeoutException(
        'Retained fixture diagnostic exceeded 120 seconds.',
        totalWatch.elapsed,
      );
    }
    return <String, Object?>{
      'sourcePath': source.absolute.path,
      'copiedFixturePath': copy.absolute.path,
      'sourceFileBytes': sourceBytes,
      'copiedFileBytes': copyBytes,
      'attemptCountBefore': sourceCounts.read<int>('attempts'),
      'receiptCountBefore': sourceCounts.read<int>('receipts'),
      'receiptPayloadBytesBefore': sourceCounts.read<int>(
        'receipt_payload_bytes',
      ),
      'attemptCountAfterOneValidAnswer': attemptsAfter,
      'receiptCountAfterTwoCommits': receiptsAfter,
      'repositoryLoadMilliseconds': loadWatch.elapsedMilliseconds,
      'startPrepareMilliseconds': startPrepareWatch.elapsedMilliseconds,
      'startSubmitMilliseconds': startSubmitWatch.elapsedMilliseconds,
      'answerPrepareMilliseconds': answerPrepareWatch.elapsedMilliseconds,
      'answerSubmitMilliseconds': answerSubmitWatch.elapsedMilliseconds,
      'totalDiagnosticMilliseconds': totalWatch.elapsedMilliseconds,
      'scopeRevisionAfter': state.revision,
      'commitOrdinalAfter': state.commitOrdinal,
      'answerWasSubmitted': state.attempts.length == attemptsBefore + 1,
      'interpretation':
          'Bounded stage timings on a retained-fixture copy only; not a full-retention PASS.',
    };
  } finally {
    await handle.close();
  }
}

final class _CoursePruneFixture {
  _CoursePruneFixture(this.database)
    : owner = LearningOwner.account('task9-small-history-prune'),
      scope = LearningScope(
        courseId: 'en-fr',
        owner: LearningOwner.account('task9-small-history-prune'),
      ) {
    final LearningRegistry registry = LearningRegistry.french();
    repository = SqliteCourseLearningRepository(
      database: database,
      scope: scope,
      authGeneration: 17,
      currentAuth: () =>
          LearningAuthScope(owner: owner, generation: 17, ready: true),
      backendOwner: () => owner,
      transitions: LearningTransitionEngine(registry),
      clock: () => DateTime.utc(
        2026,
        10,
        19,
        12,
      ).add(Duration(seconds: _clockSequence++)),
      newToken: () => (++_tokenSequence).toRadixString(36).padLeft(22, '0'),
      random: Random(991),
      historyLimit: 4,
    );
  }

  final LearningDatabaseHandle database;
  final LearningOwner owner;
  final LearningScope scope;
  late final SqliteCourseLearningRepository repository;
  int _tokenSequence = 0;
  int _clockSequence = 0;

  Future<CourseLearningState> startWordRun(CourseLearningState state) async {
    state = await _submit(state, StartLearningRun(options: RunOptions()));
    return _submit(state, CheckpointArcade(elapsedSeconds: 0, paused: false));
  }

  Future<CourseLearningState> linkFourWordTiles(
    CourseLearningState state,
  ) async {
    final WordGameCheckpoint checkpoint =
        state.activities['arcade:word']!.snapshot as WordGameCheckpoint;
    final WordMatchEngine game = WordMatchEngine.fromState(
      checkpoint.board,
      random: Random(991),
    );
    final List<int> chain = _wordPath(game, 4);
    return _submit(state, LinkWordTiles(indices: chain, elapsedSeconds: 0));
  }

  Future<CourseLearningState> _submit(
    CourseLearningState state,
    LearningAction action,
  ) async {
    final LearningCommand command = repository.prepare(
      state: state,
      activityId: 'arcade:word',
      action: action,
    );
    return (await repository.submit(command)).state;
  }
}

List<int> _wordPath(WordMatchEngine game, int length) {
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
  throw StateError('Small pruning fixture needs a four-tile answer path.');
}
