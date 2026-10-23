import 'dart:convert';

import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_command_codec.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/learning_storage_scope.dart';
import '../support/course_learning_widget_store.dart'
    show ComparisonLearningSqlTestHarness;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final warnAboutMultipleDatabases =
      driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  setUpAll(() {
    // Each temporary file harness owns a fresh executor; Drift's process-wide
    // database-class counter otherwise reports these independent instances.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases =
        warnAboutMultipleDatabases;
  });

  group('registry-backed comparison SQLite adapter', () {
    test('harness requires exactly one catalogue or registry', () {
      final owner = LearningOwner.guest();
      LearningAuthScope auth() =>
          LearningAuthScope(owner: owner, generation: 17, ready: true);
      LearningOwner backendOwner() => owner;
      final catalogue = loadFrenchComparisonCatalogue();
      final registry = _availableRegistry();

      expect(
        () => ComparisonLearningSqlTestHarness(
          catalogue: catalogue,
          registry: registry,
          currentAuth: auth,
          backendOwner: backendOwner,
        ),
        throwsArgumentError,
      );
      final legacyHarness = ComparisonLearningSqlTestHarness(
        catalogue: catalogue,
        currentAuth: auth,
        backendOwner: backendOwner,
      );
      expect(legacyHarness.catalogue.activityId, comparisonActivityId);
      expect(
        () => ComparisonLearningSqlTestHarness(
          currentAuth: auth,
          backendOwner: backendOwner,
        ),
        throwsArgumentError,
      );
    });

    test(
      'interleaved_activity_commands_keep_independent_sql_slots_and_scope_fence',
      () async {
        final fixture = _Fixture();
        final repository = fixture.repository;
        var state = await repository.load();
        final scopeId = await fixture.scopeId;

        state = (await _commit(
          repository,
          state,
          comparisonActivityId,
          StartComparisonRun(
            sessionId: 'mixed-interleaved',
            policy: LessonPolicy(),
          ),
        ));
        final mixedCheckpoint = await _checkpointJson(
          fixture.harness.database,
          scopeId,
          comparisonActivityId,
        );
        final staleMixedCommand = repository.prepare(
          state: state,
          activityId: comparisonActivityId,
          action: StartComparisonRun(
            sessionId: 'stale-mixed-restart',
            policy: LessonPolicy(),
          ),
        );

        state = await _commit(
          repository,
          state,
          uyDemoComparisonActivityId,
          StartComparisonRun(
            sessionId: 'uy-interleaved',
            policy: LessonPolicy(),
          ),
        );
        final dedicatedCheckpoint = await _checkpointJson(
          fixture.harness.database,
          scopeId,
          uyDemoComparisonActivityId,
        );
        expect(
          await _checkpointJson(
            fixture.harness.database,
            scopeId,
            comparisonActivityId,
          ),
          mixedCheckpoint,
          reason: 'starting the sibling run must not rewrite its checkpoint',
        );
        await expectLater(
          repository.submit(staleMixedCommand),
          throwsA(isA<LearningConflictException>()),
        );

        state = await repository.load();
        expect(
          state.slots.keys,
          containsAll([comparisonActivityId, uyDemoComparisonActivityId]),
        );
        expect(state.revision, 2);
        expect(state.commitOrdinal, 2);

        state = await _finishAndReview(
          fixture,
          repository,
          state,
          comparisonActivityId,
        );
        expect(
          await _checkpointJson(
            fixture.harness.database,
            scopeId,
            uyDemoComparisonActivityId,
          ),
          dedicatedCheckpoint,
          reason: 'a mixed write must not replace the dedicated checkpoint',
        );
        state = await _finishAndReview(
          fixture,
          repository,
          state,
          uyDemoComparisonActivityId,
        );

        expect(
          state.completions.map((completion) => completion.activityId),
          containsAll([comparisonActivityId, uyDemoComparisonActivityId]),
        );
        expect(
          state.attempts
              .where((attempt) => attempt.afterDebrief)
              .map((attempt) => attempt.activityId)
              .toSet(),
          {comparisonActivityId, uyDemoComparisonActivityId},
        );
        expect(
          state.commitOrdinal,
          greaterThan(
            state.slots[comparisonActivityId]!.latestReceipt.commitOrdinal,
          ),
          reason: 'the scope ordinal advances beyond a sibling slot receipt',
        );
        expect(
          state.slots[uyDemoComparisonActivityId]!.latestReceipt.commitOrdinal,
          state.commitOrdinal,
        );
        expect(state.receipts.last.commitOrdinal, state.commitOrdinal);

        final db = await fixture.harness.database.open();
        final rows = await db
            .customSelect(
              'SELECT activity_id, checkpoint_json FROM learning_runs '
              'WHERE scope_id = ? ORDER BY activity_id',
              variables: [Variable<int>(scopeId)],
            )
            .get();
        expect(rows.map((row) => row.read<String>('activity_id')).toList(), [
          comparisonActivityId,
          uyDemoComparisonActivityId,
        ]);
        final uniqueIndex = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type = 'index' "
              "AND name = 'ux_learning_runs_scope_activity'",
            )
            .get();
        expect(uniqueIndex, hasLength(1));
        expect(
          uniqueIndex.single.read<String>('sql'),
          contains('(scope_id, activity_id)'),
        );
        expect(rows.first.read<String>('checkpoint_json'), isNotEmpty);
        expect(rows.last.read<String>('checkpoint_json'), isNotEmpty);
        expect(state.commitOrdinal, state.revision);
      },
    );

    test(
      'failed_frozen_command_retries_once_and_ack_survives_reopen_for_each_activity',
      () async {
        final fixture = _Fixture();
        final repository = fixture.repository;
        var state = await repository.load();
        final scopeId = await fixture.scopeId;
        state = await _commit(
          repository,
          state,
          comparisonActivityId,
          StartComparisonRun(sessionId: 'retry-mixed', policy: LessonPolicy()),
        );
        state = await _commit(
          repository,
          state,
          uyDemoComparisonActivityId,
          StartComparisonRun(sessionId: 'retry-uy', policy: LessonPolicy()),
        );

        for (final activityId in [
          comparisonActivityId,
          uyDemoComparisonActivityId,
        ]) {
          state = await repository.load();
          final command = repository.prepare(
            state: state,
            activityId: activityId,
            action: StartComparisonRun(
              sessionId: 'retry-again-$activityId',
              policy: LessonPolicy(),
            ),
          );
          final frozenPayload = ComparisonLearningCommandCodec.canonicalCommand(
            command,
          );
          final siblingId = activityId == comparisonActivityId
              ? uyDemoComparisonActivityId
              : comparisonActivityId;
          final siblingCheckpoint = await _checkpointJson(
            fixture.harness.database,
            scopeId,
            siblingId,
          );
          final beforeFailure = await _snapshot(
            fixture.harness.database,
            scopeId,
          );

          await fixture.harness.rejectNextReceiptInsert();
          await expectLater(
            repository.submit(command),
            throwsA(isA<LearningSaveException>()),
          );
          expect(
            await _snapshot(fixture.harness.database, scopeId),
            beforeFailure,
            reason: 'the failed transaction must leave every row/byte intact',
          );
          await fixture.harness.clearWriteFailure();

          final committed = await repository.submit(command);
          expect(committed.duplicate, isFalse);
          expect(
            await _receiptPayload(
              fixture.harness.database,
              scopeId,
              command.token,
            ),
            frozenPayload,
          );
          expect(
            await _checkpointJson(fixture.harness.database, scopeId, siblingId),
            siblingCheckpoint,
          );

          await fixture.harness.database.close();
          await fixture.harness.database.reopen();
          final duplicate = await repository.submit(command);
          expect(duplicate.duplicate, isTrue);
          expect(
            duplicate.state.slots.keys,
            containsAll([comparisonActivityId, uyDemoComparisonActivityId]),
          );
          expect(
            await _checkpointJson(fixture.harness.database, scopeId, siblingId),
            siblingCheckpoint,
          );
          state = duplicate.state;
        }
        expect(state.slots, hasLength(2));
      },
    );

    test(
      'preupgrade_mixed_rows_and_canonical_bytes_load_without_rewrite',
      () async {
        final fixture = _Fixture(legacyMixedOnly: true);
        final legacyRepository = fixture.repository;
        var state = await legacyRepository.load();
        final scopeId = await fixture.scopeId;
        final startCommand = legacyRepository.prepare(
          state: state,
          activityId: comparisonActivityId,
          action: StartComparisonRun(
            sessionId: 'preupgrade-mixed',
            policy: LessonPolicy(),
          ),
        );
        state = (await legacyRepository.submit(startCommand)).state;
        final session = fixture.session(state, comparisonActivityId);
        final answerCommand = legacyRepository.prepare(
          state: state,
          activityId: comparisonActivityId,
          action: AnswerComparisonPair(
            fixture.answer(
              comparisonActivityId,
              state.slots[comparisonActivityId]!.cursor.generation,
              session.round,
              session.currentItemId!,
              correct: true,
            ),
          ),
        );
        state = (await legacyRepository.submit(answerCommand)).state;

        final before = await _snapshot(fixture.harness.database, scopeId);
        final startBytes = await _receiptPayload(
          fixture.harness.database,
          scopeId,
          startCommand.token,
        );
        final answerBytes = await _receiptPayload(
          fixture.harness.database,
          scopeId,
          answerCommand.token,
        );
        expect(
          startBytes,
          ComparisonLearningCommandCodec.canonicalCommand(startCommand),
        );
        expect(
          answerBytes,
          ComparisonLearningCommandCodec.canonicalCommand(answerCommand),
        );
        expect(
          (jsonDecode(answerBytes) as Map).containsKey('expectedScopeRevision'),
          isTrue,
        );

        final upgradedRepository = fixture.repositoryWithRegistry(
          _availableRegistry(),
        );
        await fixture.harness.database.close();
        await fixture.harness.database.reopen();
        final reloaded = await upgradedRepository.load();

        expect(reloaded.slots.keys, [comparisonActivityId]);
        expect(
          reloaded.slots[comparisonActivityId]!.checkpoint.sessionJson,
          state.slots[comparisonActivityId]!.checkpoint.sessionJson,
        );
        expect(await _snapshot(fixture.harness.database, scopeId), before);
        expect(
          await _receiptPayload(
            fixture.harness.database,
            scopeId,
            startCommand.token,
          ),
          startBytes,
        );
        expect(
          await _receiptPayload(
            fixture.harness.database,
            scopeId,
            answerCommand.token,
          ),
          answerBytes,
        );
      },
    );

    test('unknown_comparison_row_fails_closed_without_mutation', () async {
      final fixture = _Fixture();
      final repository = fixture.repository;
      var state = await repository.load();
      final scopeId = await fixture.scopeId;
      state = await _commit(
        repository,
        state,
        comparisonActivityId,
        StartComparisonRun(
          sessionId: 'unknown-corruption',
          policy: LessonPolicy(),
        ),
      );
      final db = await fixture.harness.database.open();
      await db.customStatement(
        'INSERT INTO learning_completions '
        '(scope_id, activity_id, content_revision, policy_kind, '
        'policy_revision, threshold_percent, committed_at_us) '
        "VALUES (?, ?, 1, 'discoveryThreshold', 1, 80, ?)",
        [
          scopeId,
          'unknown-comparison-activity',
          DateTime.utc(2026, 10, 23).microsecondsSinceEpoch,
        ],
      );
      final corrupted = await _snapshot(fixture.harness.database, scopeId);

      await expectLater(
        repository.load(),
        throwsA(isA<LearningCorruptException>()),
      );
      expect(
        await _snapshot(fixture.harness.database, scopeId),
        corrupted,
        reason: 'unknown comparison data must remain byte-for-byte preserved',
      );
    });

    test('unavailable_registration_empty_vs_persisted_binding', () async {
      final unavailableRegistry = _unavailableUyRegistry();
      final emptyFixture = _Fixture(registry: unavailableRegistry);
      final emptyRepository = emptyFixture.repository;
      final emptyState = await emptyRepository.load();
      final emptyScopeId = await emptyFixture.scopeId;
      final emptyRows = await _snapshot(
        emptyFixture.harness.database,
        emptyScopeId,
      );

      expect(emptyState.slots, isEmpty);
      expect(emptyState.revision, 0);
      expect(
        () => emptyRepository.prepare(
          state: emptyState,
          activityId: uyDemoComparisonActivityId,
          action: StartComparisonRun(
            sessionId: 'unavailable-empty',
            policy: LessonPolicy(),
          ),
        ),
        throwsA(isA<StateError>()),
        reason: 'unavailable activity must fail before command creation',
      );
      expect(emptyState.slots, isEmpty);
      expect(emptyState.revision, 0);
      expect(
        await _snapshot(emptyFixture.harness.database, emptyScopeId),
        emptyRows,
        reason: 'prepare must not write SQLite for unavailable activity',
      );

      final persistedFixture = _Fixture();
      final persistedRepository = persistedFixture.repository;
      final state = await persistedRepository.load();
      final persistedScopeId = await persistedFixture.scopeId;
      await _commit(
        persistedRepository,
        state,
        uyDemoComparisonActivityId,
        StartComparisonRun(
          sessionId: 'unavailable-persisted',
          policy: LessonPolicy(),
        ),
      );
      final persistedRows = await _snapshot(
        persistedFixture.harness.database,
        persistedScopeId,
      );
      final unavailableRepository = persistedFixture.repositoryWithRegistry(
        unavailableRegistry,
      );

      await expectLater(
        unavailableRepository.load(),
        throwsA(isA<LearningContentChangedException>()),
        reason:
            'registered unavailable data is content-changed, not generic corruption',
      );
      expect(
        await _snapshot(persistedFixture.harness.database, persistedScopeId),
        persistedRows,
      );
    });

    test('comparison slots remain isolated by owner', () async {
      final fixture = _Fixture();
      final ownerARepository = fixture.repository;
      var ownerAState = await ownerARepository.load();
      ownerAState = await _commit(
        ownerARepository,
        ownerAState,
        comparisonActivityId,
        StartComparisonRun(sessionId: 'owner-a-mixed', policy: LessonPolicy()),
      );
      ownerAState = await _commit(
        ownerARepository,
        ownerAState,
        uyDemoComparisonActivityId,
        StartComparisonRun(sessionId: 'owner-a-uy', policy: LessonPolicy()),
      );

      final ownerB = LearningOwner.account('comparison-owner-b');
      final ownerBRepository = fixture.repositoryFor(ownerB);
      final ownerBEmpty = await ownerBRepository.load();
      expect(ownerBEmpty.slots, isEmpty);
      final ownerBState = await _commit(
        ownerBRepository,
        ownerBEmpty,
        uyDemoComparisonActivityId,
        StartComparisonRun(sessionId: 'owner-b-uy', policy: LessonPolicy()),
      );

      expect(ownerAState.slots, hasLength(2));
      expect(ownerBState.slots.keys, [uyDemoComparisonActivityId]);
      final rows = await (await fixture.harness.database.open())
          .customSelect(
            'SELECT s.owner_id, r.activity_id FROM learning_runs r '
            'JOIN learning_scopes s ON s.id = r.scope_id '
            'WHERE r.activity_id = ? ORDER BY s.owner_id',
            variables: [const Variable<String>(uyDemoComparisonActivityId)],
          )
          .get();
      expect(rows.map((row) => row.read<String>('owner_id')).toSet(), {
        fixture.owner.userId,
        ownerB.userId,
      });
      expect(rows, hasLength(2));
    });
  });
}

final class _Fixture {
  _Fixture({
    ComparisonCatalogueRegistry? registry,
    bool legacyMixedOnly = false,
  }) : owner = LearningOwner.account('comparison-multi-user') {
    final resolvedRegistry =
        registry ??
        (legacyMixedOnly
            ? ComparisonCatalogueRegistry.single(
                loadFrenchComparisonCatalogue(),
              )
            : _availableRegistry());
    harness = ComparisonLearningSqlTestHarness(
      registry: resolvedRegistry,
      currentAuth: () =>
          LearningAuthScope(owner: owner, generation: 17, ready: true),
      backendOwner: () => owner,
    );
    repository = harness.createRepository(owner: owner, generation: 17);
  }

  final LearningOwner owner;
  late final ComparisonLearningSqlTestHarness harness;
  late final SqliteComparisonLearningRepository repository;
  int _tokenCounter = 0;
  int _uiGeneration = 0;

  Future<int> get scopeId => _scopeIdFor(harness.database, owner);

  ComparisonProfileScope get profileScope =>
      ComparisonProfileScope(courseId: 'en-fr', owner: owner);

  SqliteComparisonLearningRepository repositoryWithRegistry(
    ComparisonCatalogueRegistry registry,
  ) => _repositoryFor(owner, registry);

  SqliteComparisonLearningRepository repositoryFor(LearningOwner owner) =>
      _repositoryFor(owner, harness.registry);

  SqliteComparisonLearningRepository _repositoryFor(
    LearningOwner owner,
    ComparisonCatalogueRegistry registry,
  ) => SqliteComparisonLearningRepository(
    database: harness.database,
    scope: ComparisonProfileScope(courseId: 'en-fr', owner: owner),
    authGeneration: 17,
    currentAuth: () =>
        LearningAuthScope(owner: owner, generation: 17, ready: true),
    backendOwner: () => owner,
    transitions: ComparisonLearningTransitionEngine(registry: registry),
    clock: () => DateTime.utc(2026, 10, 23),
    newToken: () => (++_tokenCounter).toRadixString(36).padLeft(22, '0'),
  );

  LessonSectionSession session(
    ComparisonLearningState state,
    String activityId,
  ) => LessonSectionSession.fromJson(
    Map<String, dynamic>.from(state.slots[activityId]!.checkpoint.sessionJson),
    itemIds: catalogue(
      activityId,
    ).exercises.map((exercise) => exercise.id).toList(),
    contentRevision: catalogue(activityId).contentRevision,
  );

  ComparisonCatalogue catalogue(String activityId) =>
      harness.registry.requireAvailable(activityId);

  ComparePhonemesAnswer answer(
    String activityId,
    int generation,
    int round,
    String pairId, {
    required bool correct,
  }) {
    final exercise = catalogue(activityId).exercise(pairId);
    final selected = correct
        ? exercise.expectedRelation
        : exercise.expectedRelation == PhonemeRelation.same
        ? PhonemeRelation.different
        : PhonemeRelation.same;
    final uiGeneration = ++_uiGeneration;
    return ComparePhonemesAnswer(
      selectedRelation: selected,
      expectedRelationSnapshot: exercise.expectedRelation,
      observations: [
        for (final sample in [exercise.sampleA, exercise.sampleB])
          ComparisonPlaybackObservation(
            slot: sample.slot,
            referenceId: sample.referenceId,
            outcome: CourseAudioOutcome.completed,
            source: CourseAudioSource.unverifiedRecording,
            activityId: activityId,
            runGeneration: generation,
            round: round,
            pairId: pairId,
            profile: profileScope,
            uiGeneration: uiGeneration,
          ),
      ],
    );
  }
}

ComparisonCatalogueRegistry _availableRegistry() =>
    ComparisonCatalogueRegistry([
      ComparisonCatalogueRegistration.available(
        loadFrenchComparisonCatalogue(),
      ),
      ComparisonCatalogueRegistration.available(
        loadFrenchUyDemoComparisonCatalogue(),
      ),
    ]);

ComparisonCatalogueRegistry _unavailableUyRegistry() =>
    ComparisonCatalogueRegistry([
      ComparisonCatalogueRegistration.available(
        loadFrenchComparisonCatalogue(),
      ),
      ComparisonCatalogueRegistration.unavailable(
        activityId: uyDemoComparisonActivityId,
        cause: const FormatException('invalid demo catalogue'),
      ),
    ]);

Future<ComparisonLearningState> _commit(
  SqliteComparisonLearningRepository repository,
  ComparisonLearningState state,
  String activityId,
  ComparisonAction action,
) async {
  final command = repository.prepare(
    state: state,
    activityId: activityId,
    action: action,
  );
  return (await repository.submit(command)).state;
}

Future<ComparisonLearningState> _finishAndReview(
  _Fixture fixture,
  SqliteComparisonLearningRepository repository,
  ComparisonLearningState state,
  String activityId,
) async {
  for (
    var index = 0;
    index < fixture.catalogue(activityId).exercises.length;
    index++
  ) {
    final session = fixture.session(state, activityId);
    final pairId = session.currentItemId!;
    state = await _commit(
      repository,
      state,
      activityId,
      AnswerComparisonPair(
        fixture.answer(
          activityId,
          state.slots[activityId]!.cursor.generation,
          session.round,
          pairId,
          correct: index != 0,
        ),
      ),
    );
    state = await _commit(
      repository,
      state,
      activityId,
      const AdvanceComparisonPair(),
    );
  }
  state = await _commit(
    repository,
    state,
    activityId,
    const FinishComparisonRun(recordCompletion: true),
  );
  state = await _commit(
    repository,
    state,
    activityId,
    const ReviewComparisonPairs(),
  );
  final review = fixture.session(state, activityId);
  final reviewPair = review.currentItemId!;
  state = await _commit(
    repository,
    state,
    activityId,
    AnswerComparisonPair(
      fixture.answer(
        activityId,
        state.slots[activityId]!.cursor.generation,
        review.round,
        reviewPair,
        correct: true,
      ),
    ),
  );
  return _commit(
    repository,
    state,
    activityId,
    const FinishComparisonRun(recordCompletion: false),
  );
}

Future<int> _scopeIdFor(
  LearningDatabaseHandle handle,
  LearningOwner owner,
) async {
  final scope = LearningStorageScope(
    owner: owner,
    courseId: 'en-fr',
    family: LearningFamily.comparison,
  );
  final rows = await (await handle.open())
      .customSelect(
        'SELECT id FROM learning_scopes WHERE owner_kind = ? AND owner_id = ? '
        'AND course_id = ? AND family = ?',
        variables: [
          Variable<String>(scope.ownerKind),
          Variable<String>(scope.ownerId),
          Variable<String>(scope.courseId),
          Variable<String>(scope.databaseFamily),
        ],
      )
      .get();
  return rows.single.read<int>('id');
}

Future<String> _checkpointJson(
  LearningDatabaseHandle handle,
  int scopeId,
  String activityId,
) async {
  final rows = await (await handle.open())
      .customSelect(
        'SELECT checkpoint_json FROM learning_runs '
        'WHERE scope_id = ? AND activity_id = ?',
        variables: [Variable<int>(scopeId), Variable<String>(activityId)],
      )
      .get();
  return rows.single.read<String>('checkpoint_json');
}

Future<String> _receiptPayload(
  LearningDatabaseHandle handle,
  int scopeId,
  String token,
) async {
  final rows = await (await handle.open())
      .customSelect(
        'SELECT canonical_payload FROM learning_command_receipts '
        'WHERE scope_id = ? AND token = ?',
        variables: [Variable<int>(scopeId), Variable<String>(token)],
      )
      .get();
  return rows.single.read<String>('canonical_payload');
}

Future<String> _snapshot(LearningDatabaseHandle handle, int scopeId) async {
  final db = await handle.open();
  final queries = <String, String>{
    'scope': 'SELECT * FROM learning_scopes WHERE id = ?',
    'runs':
        'SELECT * FROM learning_runs WHERE scope_id = ? ORDER BY activity_id',
    'bindings':
        'SELECT * FROM learning_content_bindings WHERE scope_id = ? ORDER BY activity_id, content_revision',
    'receipts':
        'SELECT * FROM learning_command_receipts WHERE scope_id = ? ORDER BY commit_ordinal, activity_id',
    'attempts':
        'SELECT * FROM learning_attempts WHERE scope_id = ? ORDER BY commit_ordinal, activity_id, run_generation, command_sequence',
    'evidence':
        'SELECT * FROM learning_attempt_evidence WHERE scope_id = ? ORDER BY attempt_id, evidence_index',
    'mistakes':
        'SELECT * FROM learning_mistakes WHERE scope_id = ? ORDER BY family, activity_id, pair_id',
    'summaries':
        'SELECT * FROM learning_summaries WHERE scope_id = ? ORDER BY family, activity_id, pair_id, bucket',
    'completions':
        'SELECT * FROM learning_completions WHERE scope_id = ? ORDER BY activity_id, content_revision, policy_kind, policy_revision, threshold_percent',
  };
  final result = <String, List<Map<String, Object?>>>{};
  for (final entry in queries.entries) {
    final rows = await db
        .customSelect(entry.value, variables: [Variable<int>(scopeId)])
        .get();
    result[entry.key] = [
      for (final row in rows) Map<String, Object?>.from(row.data),
    ];
  }
  return jsonEncode(result);
}
