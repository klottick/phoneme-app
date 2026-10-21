import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_command_codec.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase;
import 'package:linguist/src/core/course/storage/comparison_learning_sql_repository.dart';

import '../support/course_learning_widget_store.dart'
    show ComparisonLearningSqlTestHarness;

void main() {
  test('comparison legacy scope keys remain exact stable identities', () {
    expect(
      ComparisonProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.guest(),
      ).storageKey,
      'course.learning.comparison.v1.ZW4tZnI.g',
    );
    expect(
      ComparisonProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.account('French/User:7'),
      ).storageKey,
      'course.learning.comparison.v1.ZW4tZnI.a.RnJlbmNoL1VzZXI6Nw',
    );
  });

  test(
    'SQL comparison commit retries exact identity without a second write',
    () async {
      final owner = LearningOwner.account('comparison-store-test');
      final auth = LearningAuthScope(owner: owner, generation: 4, ready: true);
      var notifications = 0;
      final harness = ComparisonLearningSqlTestHarness(
        catalogue: loadFrenchComparisonCatalogue(),
        currentAuth: () => auth,
        backendOwner: () => owner,
      );
      addTearDown(harness.dispose);
      final SqliteComparisonLearningRepository repository = harness
          .createRepository(
            owner: owner,
            generation: auth.generation,
            onCommitted: () => notifications++,
          );

      final empty = await repository.load();
      final command = repository.prepare(
        state: empty,
        activityId: comparisonActivityId,
        action: StartComparisonRun(
          sessionId: 'store-run',
          policy: LessonPolicy(),
        ),
      );
      final committed = await repository.submit(command);
      final database = await repository.database.open();
      final writesAfterCommit = await database
          .customSelect(
            'SELECT COUNT(*) AS row_count FROM learning_command_receipts',
          )
          .getSingle()
          .then((row) => row.read<int>('row_count'));
      final duplicate = await repository.submit(command);

      expect(committed.duplicate, isFalse);
      expect(committed.state.revision, 1);
      expect(committed.state.commitOrdinal, 1);
      expect(duplicate.duplicate, isTrue);
      expect(duplicate.state.revision, 1);
      expect(duplicate.state.commitOrdinal, 1);
      expect(notifications, 1);
      expect(
        await database
            .customSelect(
              'SELECT COUNT(*) AS row_count FROM learning_command_receipts',
            )
            .getSingle()
            .then((row) => row.read<int>('row_count')),
        writesAfterCommit,
      );

      final changed = ComparisonLearningCommand(
        scope: command.scope,
        authGeneration: command.authGeneration,
        activityId: command.activityId,
        expected: command.expected,
        expectedScopeRevision: command.expectedScopeRevision,
        token: command.token,
        submittedAt: command.submittedAt,
        action: StartComparisonRun(
          sessionId: 'changed-payload',
          policy: LessonPolicy(),
        ),
      );
      await expectLater(
        repository.submit(changed),
        throwsA(isA<LearningInvalidCommandException>()),
      );
      expect((await repository.load()).revision, 1);
      expect(notifications, 1);
    },
  );

  test(
    'SQL retained receipts win stale cursors across reopen and run restart',
    () async {
      final owner = LearningOwner.account('comparison-restart-receipt-test');
      var auth = LearningAuthScope(owner: owner, generation: 4, ready: true);
      var notifications = 0;
      final catalogue = loadFrenchComparisonCatalogue();
      final harness = ComparisonLearningSqlTestHarness(
        catalogue: catalogue,
        currentAuth: () => auth,
        backendOwner: () => owner,
      );
      addTearDown(harness.dispose);
      final repository = harness.createRepository(
        owner: owner,
        generation: auth.generation,
        onCommitted: () => notifications++,
      );

      var state = await repository.load();
      state = (await repository.submit(
        repository.prepare(
          state: state,
          activityId: comparisonActivityId,
          action: StartComparisonRun(
            sessionId: 'receipt-restart-run-1',
            policy: LessonPolicy(),
          ),
        ),
      )).state;
      final answerCommand = repository.prepare(
        state: state,
        activityId: comparisonActivityId,
        action: AnswerComparisonPair(
          _answerForState(repository, state, catalogue, correct: false),
        ),
      );
      state = (await repository.submit(answerCommand)).state;
      state = (await repository.submit(
        repository.prepare(
          state: state,
          activityId: comparisonActivityId,
          action: const AdvanceComparisonPair(),
        ),
      )).state;

      final distinctStale = ComparisonLearningCommand(
        scope: answerCommand.scope,
        authGeneration: answerCommand.authGeneration,
        activityId: answerCommand.activityId,
        expected: answerCommand.expected,
        expectedScopeRevision: answerCommand.expectedScopeRevision,
        token: 'BBBBBBBBBBBBBBBBBBBBBB',
        submittedAt: answerCommand.submittedAt,
        action: answerCommand.action,
      );

      await harness.database.reopen();
      final afterProcessRestart = await repository.load();
      final beforeDuplicate = await _captureComparisonSqlRows(harness, owner);
      final notificationsBeforeDuplicate = notifications;
      final duplicate = await repository.submit(answerCommand);
      expect(duplicate.duplicate, isTrue);
      expect(duplicate.state.revision, afterProcessRestart.revision);
      expect(duplicate.state.commitOrdinal, afterProcessRestart.commitOrdinal);
      expect(duplicate.state.slot!.cursor, afterProcessRestart.slot!.cursor);
      expect(
        duplicate.state.slot!.checkpoint.sessionId,
        'receipt-restart-run-1',
      );
      expect(notifications, notificationsBeforeDuplicate);
      expect(await _captureComparisonSqlRows(harness, owner), beforeDuplicate);

      final originalAction = answerCommand.action as AnswerComparisonPair;
      final changedAnswer = ComparePhonemesAnswer(
        selectedRelation:
            originalAction.answer.selectedRelation == PhonemeRelation.same
            ? PhonemeRelation.different
            : PhonemeRelation.same,
        expectedRelationSnapshot:
            originalAction.answer.expectedRelationSnapshot,
        observations: originalAction.answer.observations,
      );
      final changedPayload = ComparisonLearningCommand(
        scope: answerCommand.scope,
        authGeneration: answerCommand.authGeneration,
        activityId: answerCommand.activityId,
        expected: answerCommand.expected,
        expectedScopeRevision: answerCommand.expectedScopeRevision,
        token: answerCommand.token,
        submittedAt: answerCommand.submittedAt,
        action: AnswerComparisonPair(changedAnswer),
      );
      await expectLater(
        repository.submit(changedPayload),
        throwsA(isA<LearningInvalidCommandException>()),
      );
      expect(notifications, notificationsBeforeDuplicate);
      expect(await _captureComparisonSqlRows(harness, owner), beforeDuplicate);

      final restart = await repository.submit(
        repository.prepare(
          state: afterProcessRestart,
          activityId: comparisonActivityId,
          action: StartComparisonRun(
            sessionId: 'receipt-restart-run-2',
            policy: LessonPolicy(),
          ),
        ),
      );
      expect(restart.state.slot!.cursor.generation, 2);
      final beforeRestartDuplicate = await _captureComparisonSqlRows(
        harness,
        owner,
      );
      final notificationsAfterRestart = notifications;
      final replayAfterRunRestart = await repository.submit(answerCommand);
      expect(replayAfterRunRestart.duplicate, isTrue);
      expect(replayAfterRunRestart.state.revision, restart.state.revision);
      expect(
        replayAfterRunRestart.state.commitOrdinal,
        restart.state.commitOrdinal,
      );
      expect(
        replayAfterRunRestart.state.slot!.cursor,
        restart.state.slot!.cursor,
      );
      expect(replayAfterRunRestart.state.slot!.cursor.generation, 2);
      expect(notifications, notificationsAfterRestart);
      expect(
        await _captureComparisonSqlRows(harness, owner),
        beforeRestartDuplicate,
      );

      await expectLater(
        repository.submit(distinctStale),
        throwsA(isA<LearningConflictException>()),
      );
      await expectLater(
        repository.submit(changedPayload),
        throwsA(isA<LearningInvalidCommandException>()),
      );
      expect(notifications, notificationsAfterRestart);
      expect(
        await _captureComparisonSqlRows(harness, owner),
        beforeRestartDuplicate,
      );

      auth = LearningAuthScope(owner: owner, generation: 5, ready: true);
      await expectLater(
        repository.submit(answerCommand),
        throwsA(isA<LearningOwnerChangedException>()),
      );
      expect(notifications, notificationsAfterRestart);
      expect(
        await _captureComparisonSqlRows(harness, owner),
        beforeRestartDuplicate,
      );
    },
  );

  test(
    'SQL rejects a forged checkpoint after reopening without repair',
    () async {
      final owner = LearningOwner.account('comparison-forged-checkpoint');
      final catalogue = loadFrenchComparisonCatalogue();
      final harness = ComparisonLearningSqlTestHarness(
        catalogue: catalogue,
        currentAuth: () =>
            LearningAuthScope(owner: owner, generation: 4, ready: true),
        backendOwner: () => owner,
      );
      addTearDown(harness.dispose);
      var notifications = 0;
      final repository = harness.createRepository(
        owner: owner,
        generation: 4,
        onCommitted: () => notifications++,
      );
      final state = await repository.load();
      await repository.submit(
        repository.prepare(
          state: state,
          activityId: comparisonActivityId,
          action: StartComparisonRun(
            sessionId: 'forged-checkpoint-session',
            policy: LessonPolicy(),
          ),
        ),
      );
      final forged = LessonSectionSession(
        itemIds: catalogue.exercises.map((exercise) => exercise.id).toList(),
        sessionId: 'forged-checkpoint-session',
        contentRevision: catalogue.contentRevision,
      )..submit(true);
      final database = await harness.database.open();
      final scopeId = await _comparisonScopeId(database, owner);
      await database.customStatement(
        'UPDATE learning_runs SET checkpoint_json = ? '
        'WHERE scope_id = ? AND activity_id = ?',
        [jsonEncode(forged.toJson()), scopeId, comparisonActivityId],
      );

      await _expectComparisonCorruptReadOnly(harness, repository, owner);
      expect(notifications, 1);
    },
  );

  test(
    'SQL checkpoint session version is corrupt, not a storage-schema upgrade',
    () async {
      final owner = LearningOwner.account('comparison-checkpoint-version');
      final catalogue = loadFrenchComparisonCatalogue();
      final harness = ComparisonLearningSqlTestHarness(
        catalogue: catalogue,
        currentAuth: () =>
            LearningAuthScope(owner: owner, generation: 4, ready: true),
        backendOwner: () => owner,
      );
      addTearDown(harness.dispose);
      var notifications = 0;
      final repository = harness.createRepository(
        owner: owner,
        generation: 4,
        onCommitted: () => notifications++,
      );
      final initial = await repository.load();
      await repository.submit(
        repository.prepare(
          state: initial,
          activityId: comparisonActivityId,
          action: StartComparisonRun(
            sessionId: 'checkpoint-version-session',
            policy: LessonPolicy(),
          ),
        ),
      );
      final database = await harness.database.open();
      final scopeId = await _comparisonScopeId(database, owner);
      final run = await database
          .customSelect(
            'SELECT checkpoint_json FROM learning_runs WHERE scope_id = ? '
            'AND activity_id = ?',
            variables: [
              Variable<int>(scopeId),
              const Variable<String>(comparisonActivityId),
            ],
          )
          .getSingle();
      final checkpoint =
          jsonDecode(run.read<String>('checkpoint_json'))
              as Map<String, dynamic>;
      checkpoint['version'] = 99;
      await database.customStatement(
        'UPDATE learning_runs SET checkpoint_json = ? '
        'WHERE scope_id = ? AND activity_id = ?',
        [jsonEncode(checkpoint), scopeId, comparisonActivityId],
      );

      await _expectComparisonCorruptReadOnly(harness, repository, owner);
      expect(notifications, 1);
    },
  );

  test(
    'SQL receipt action must agree with retained attempt and checkpoint facts',
    () async {
      final owner = LearningOwner.account('comparison-forged-receipt-action');
      final catalogue = loadFrenchComparisonCatalogue();
      final harness = ComparisonLearningSqlTestHarness(
        catalogue: catalogue,
        currentAuth: () =>
            LearningAuthScope(owner: owner, generation: 4, ready: true),
        backendOwner: () => owner,
      );
      addTearDown(harness.dispose);
      var notifications = 0;
      final repository = harness.createRepository(
        owner: owner,
        generation: 4,
        onCommitted: () => notifications++,
      );
      var state = await repository.load();
      state = (await repository.submit(
        repository.prepare(
          state: state,
          activityId: comparisonActivityId,
          action: StartComparisonRun(
            sessionId: 'receipt-action-session',
            policy: LessonPolicy(),
          ),
        ),
      )).state;
      final command = repository.prepare(
        state: state,
        activityId: comparisonActivityId,
        action: AnswerComparisonPair(
          _answerForState(repository, state, catalogue, correct: false),
        ),
      );
      await repository.submit(command);

      final database = await harness.database.open();
      final scopeId = await _comparisonScopeId(database, owner);
      final receipt = await database
          .customSelect(
            'SELECT canonical_payload FROM learning_command_receipts '
            'WHERE scope_id = ? AND token = ?',
            variables: [
              Variable<int>(scopeId),
              Variable<String>(command.token),
            ],
          )
          .getSingle();
      final payload =
          jsonDecode(receipt.read<String>('canonical_payload'))
              as Map<String, dynamic>;
      final action = payload['action'] as Map<String, dynamic>;
      final selected = action['selectedRelation'] as String;
      action['selectedRelation'] = selected == PhonemeRelation.same.name
          ? PhonemeRelation.different.name
          : PhonemeRelation.same.name;
      final forgedPayload = jsonEncode(payload);
      final decoded = ComparisonLearningCommandCodec.decodeCanonicalCommand(
        forgedPayload,
        scope: repository.scope,
        catalogue: catalogue,
      );
      expect(
        ComparisonLearningCommandCodec.canonicalCommand(decoded),
        forgedPayload,
      );
      await database.customStatement(
        'UPDATE learning_command_receipts SET canonical_payload = ? '
        'WHERE scope_id = ? AND token = ?',
        [forgedPayload, scopeId, command.token],
      );
      await database.customStatement(
        'UPDATE learning_runs SET latest_receipt_payload = ? '
        'WHERE scope_id = ? AND activity_id = ?',
        [forgedPayload, scopeId, comparisonActivityId],
      );

      await _expectComparisonCorruptReadOnly(harness, repository, owner);
      expect(notifications, 2);
    },
  );

  test(
    'SQL rejects an attempt row forged away from its retained proof',
    () async {
      final owner = LearningOwner.account('comparison-forged-attempt-facts');
      final catalogue = loadFrenchComparisonCatalogue();
      final harness = ComparisonLearningSqlTestHarness(
        catalogue: catalogue,
        currentAuth: () =>
            LearningAuthScope(owner: owner, generation: 4, ready: true),
        backendOwner: () => owner,
      );
      addTearDown(harness.dispose);
      var notifications = 0;
      final repository = harness.createRepository(
        owner: owner,
        generation: 4,
        onCommitted: () => notifications++,
      );
      var state = await repository.load();
      state = (await repository.submit(
        repository.prepare(
          state: state,
          activityId: comparisonActivityId,
          action: StartComparisonRun(
            sessionId: 'attempt-facts-session',
            policy: LessonPolicy(),
          ),
        ),
      )).state;
      final command = repository.prepare(
        state: state,
        activityId: comparisonActivityId,
        action: AnswerComparisonPair(
          _answerForState(repository, state, catalogue, correct: false),
        ),
      );
      await repository.submit(command);

      final database = await harness.database.open();
      final scopeId = await _comparisonScopeId(database, owner);
      final attempt = await database
          .customSelect(
            'SELECT attempt_id FROM learning_attempts WHERE scope_id = ? '
            'AND command_sequence = 2',
            variables: [Variable<int>(scopeId)],
          )
          .getSingle();
      final attemptId = attempt.read<String>('attempt_id');
      await database.customStatement(
        'UPDATE learning_attempts SET selected_relation = ?, correct = 1 '
        'WHERE scope_id = ? AND attempt_id = ?',
        [
          _oppositeRelation(catalogue.exercises.first.expectedRelation).name,
          scopeId,
          attemptId,
        ],
      );
      await database.customStatement(
        'UPDATE learning_summaries SET correct = 1 WHERE scope_id = ? '
        'AND family = ? AND activity_id = ? AND pair_id = ? AND bucket = ?',
        [
          scopeId,
          'comparison',
          comparisonActivityId,
          catalogue.exercises.first.id,
          'firstInRun',
        ],
      );
      await database.customStatement(
        'DELETE FROM learning_mistakes WHERE scope_id = ? AND family = ? '
        'AND activity_id = ? AND pair_id = ?',
        [
          scopeId,
          'comparison',
          comparisonActivityId,
          catalogue.exercises.first.id,
        ],
      );

      await _expectComparisonCorruptReadOnly(harness, repository, owner);
      expect(notifications, 2);
    },
  );

  test('SQL rejects a phantom completion after only a Start receipt', () async {
    final owner = LearningOwner.account('comparison-phantom-completion');
    final catalogue = loadFrenchComparisonCatalogue();
    final harness = ComparisonLearningSqlTestHarness(
      catalogue: catalogue,
      currentAuth: () =>
          LearningAuthScope(owner: owner, generation: 4, ready: true),
      backendOwner: () => owner,
    );
    addTearDown(harness.dispose);
    var notifications = 0;
    final repository = harness.createRepository(
      owner: owner,
      generation: 4,
      onCommitted: () => notifications++,
    );
    final state = await repository.load();
    await repository.submit(
      repository.prepare(
        state: state,
        activityId: comparisonActivityId,
        action: StartComparisonRun(
          sessionId: 'phantom-completion-session',
          policy: LessonPolicy(),
        ),
      ),
    );
    final database = await harness.database.open();
    final scopeId = await _comparisonScopeId(database, owner);
    await _insertForgedCompletion(database, scopeId, catalogue);

    await _expectComparisonCorruptReadOnly(harness, repository, owner);
    expect(notifications, 1);
  });

  test(
    'SQL completion threshold must match its recorded Finish proof',
    () async {
      final owner = LearningOwner.account('comparison-mismatched-completion');
      final catalogue = loadFrenchComparisonCatalogue();
      final harness = ComparisonLearningSqlTestHarness(
        catalogue: catalogue,
        currentAuth: () =>
            LearningAuthScope(owner: owner, generation: 4, ready: true),
        backendOwner: () => owner,
      );
      addTearDown(harness.dispose);
      var notifications = 0;
      final repository = harness.createRepository(
        owner: owner,
        generation: 4,
        onCommitted: () => notifications++,
      );
      var state = await repository.load();
      state = await _startAndCompleteFirstPass(
        repository,
        state,
        catalogue,
        sessionId: 'mismatched-completion-session',
      );
      state = (await repository.submit(
        repository.prepare(
          state: state,
          activityId: comparisonActivityId,
          action: const FinishComparisonRun(recordCompletion: true),
        ),
      )).state;
      expect(state.completions, hasLength(1));
      final database = await harness.database.open();
      final scopeId = await _comparisonScopeId(database, owner);
      await database.customStatement(
        'UPDATE learning_completions SET threshold_percent = 90 '
        'WHERE scope_id = ? AND activity_id = ?',
        [scopeId, comparisonActivityId],
      );

      await _expectComparisonCorruptReadOnly(harness, repository, owner);
      expect(notifications, catalogue.exercises.length * 2 + 2);
    },
  );

  test('SQL Finish-false history cannot justify a completion row', () async {
    final owner = LearningOwner.account('comparison-finish-false-completion');
    final catalogue = loadFrenchComparisonCatalogue();
    final harness = ComparisonLearningSqlTestHarness(
      catalogue: catalogue,
      currentAuth: () =>
          LearningAuthScope(owner: owner, generation: 4, ready: true),
      backendOwner: () => owner,
    );
    addTearDown(harness.dispose);
    var notifications = 0;
    final repository = harness.createRepository(
      owner: owner,
      generation: 4,
      onCommitted: () => notifications++,
    );
    var state = await repository.load();
    state = await _startAndCompleteFirstPass(
      repository,
      state,
      catalogue,
      sessionId: 'finish-false-session',
    );
    state = (await repository.submit(
      repository.prepare(
        state: state,
        activityId: comparisonActivityId,
        action: const FinishComparisonRun(recordCompletion: false),
      ),
    )).state;
    expect(state.completions, isEmpty);
    final database = await harness.database.open();
    final scopeId = await _comparisonScopeId(database, owner);
    await _insertForgedCompletion(database, scopeId, catalogue);

    await _expectComparisonCorruptReadOnly(harness, repository, owner);
    expect(notifications, catalogue.exercises.length * 2 + 2);
  });
}

const List<String> _comparisonSnapshotTables = <String>[
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

Future<int> _comparisonScopeId(
  LearningDatabase database,
  LearningOwner owner,
) async {
  final row = await database
      .customSelect(
        'SELECT id FROM learning_scopes WHERE owner_kind = ? AND owner_id = ? '
        'AND course_id = ? AND family = ?',
        variables: <Variable<Object>>[
          const Variable<String>('account'),
          Variable<String>(owner.userId!),
          const Variable<String>('en-fr'),
          const Variable<String>('comparison'),
        ],
      )
      .getSingle();
  return row.read<int>('id');
}

Future<String> _captureComparisonSqlRows(
  ComparisonLearningSqlTestHarness harness,
  LearningOwner owner,
) async {
  final database = await harness.database.open();
  final scopeId = await _comparisonScopeId(database, owner);
  final rowsByTable = <String, List<Map<String, Object?>>>{};
  for (final table in _comparisonSnapshotTables) {
    final rows = await database
        .customSelect(
          table == 'learning_scopes'
              ? 'SELECT * FROM learning_scopes WHERE id = ? ORDER BY rowid'
              : 'SELECT * FROM $table WHERE scope_id = ? ORDER BY rowid',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    rowsByTable[table] = [
      for (final row in rows) Map<String, Object?>.from(row.data),
    ];
  }
  return jsonEncode(rowsByTable);
}

Future<void> _expectComparisonCorruptReadOnly(
  ComparisonLearningSqlTestHarness harness,
  SqliteComparisonLearningRepository repository,
  LearningOwner owner,
) async {
  final before = await _captureComparisonSqlRows(harness, owner);
  await harness.database.reopen();
  await expectLater(
    repository.load(),
    throwsA(isA<LearningCorruptException>()),
  );
  expect(await _captureComparisonSqlRows(harness, owner), before);
}

Future<ComparisonLearningState> _startAndCompleteFirstPass(
  SqliteComparisonLearningRepository repository,
  ComparisonLearningState state,
  ComparisonCatalogue catalogue, {
  required String sessionId,
}) async {
  state = (await repository.submit(
    repository.prepare(
      state: state,
      activityId: comparisonActivityId,
      action: StartComparisonRun(sessionId: sessionId, policy: LessonPolicy()),
    ),
  )).state;
  for (var index = 0; index < catalogue.exercises.length; index++) {
    state = (await repository.submit(
      repository.prepare(
        state: state,
        activityId: comparisonActivityId,
        action: AnswerComparisonPair(
          _answerForState(repository, state, catalogue, correct: true),
        ),
      ),
    )).state;
    state = (await repository.submit(
      repository.prepare(
        state: state,
        activityId: comparisonActivityId,
        action: const AdvanceComparisonPair(),
      ),
    )).state;
  }
  return state;
}

ComparePhonemesAnswer _answerForState(
  SqliteComparisonLearningRepository repository,
  ComparisonLearningState state,
  ComparisonCatalogue catalogue, {
  required bool correct,
}) {
  final slot = state.slot!;
  final session = LessonSectionSession.fromJson(
    Map<String, dynamic>.from(slot.checkpoint.sessionJson),
    itemIds: catalogue.exercises.map((exercise) => exercise.id).toList(),
    contentRevision: catalogue.contentRevision,
  );
  final pairId = session.currentItemId!;
  final exercise = catalogue.exercise(pairId);
  return ComparePhonemesAnswer(
    selectedRelation: correct
        ? exercise.expectedRelation
        : _oppositeRelation(exercise.expectedRelation),
    expectedRelationSnapshot: exercise.expectedRelation,
    observations: [
      for (final sample in [exercise.sampleA, exercise.sampleB])
        ComparisonPlaybackObservation(
          slot: sample.slot,
          referenceId: sample.referenceId,
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.unverifiedRecording,
          activityId: comparisonActivityId,
          runGeneration: slot.cursor.generation,
          round: session.round,
          pairId: pairId,
          profile: repository.scope,
          uiGeneration: state.revision + 100,
        ),
    ],
  );
}

PhonemeRelation _oppositeRelation(PhonemeRelation relation) =>
    relation == PhonemeRelation.same
    ? PhonemeRelation.different
    : PhonemeRelation.same;

Future<void> _insertForgedCompletion(
  LearningDatabase database,
  int scopeId,
  ComparisonCatalogue catalogue,
) => database.customStatement(
  'INSERT INTO learning_completions '
  '(scope_id, activity_id, content_revision, policy_kind, policy_revision, '
  'threshold_percent, committed_at_us) '
  "VALUES (?, ?, ?, 'discoveryThreshold', 1, 80, ?)",
  [
    scopeId,
    catalogue.activityId,
    catalogue.contentRevision,
    DateTime.utc(2026, 10, 20).microsecondsSinceEpoch,
  ],
);
