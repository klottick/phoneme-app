import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/comparison_learning_store.dart'
    show ComparisonCommit;
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_command_codec.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/learning_storage_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('inactive comparison SQLite adapter', () {
    late Directory directory;
    late _Fixture fixture;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('comparison-sqlite-');
      fixture = _Fixture(File('${directory.path}/learning.sqlite'));
    });

    tearDown(() async {
      await fixture.close();
      await directory.delete(recursive: true);
    });

    test(
      'comparison_answer_evidence_and_checkpoint_reopen_from_rows',
      () async {
        final repository = fixture.repository();
        var state = await repository.load();
        final started = await fixture.commit(
          repository,
          state,
          StartComparisonRun(
            sessionId: 'comparison-session',
            policy: LessonPolicy(),
          ),
        );
        state = started.state;

        ComparisonLearningCommand? firstAnswerCommand;
        for (
          var index = 0;
          index < fixture.catalogue.exercises.length;
          index++
        ) {
          final session = fixture.session(state);
          final pairId = session.currentItemId!;
          final exercise = fixture.catalogue.exercise(pairId);
          final answer = _answerFor(
            fixture,
            pairId: pairId,
            runGeneration: state.slot!.cursor.generation,
            round: session.round,
            correct: index != 0,
          );
          final command = repository.prepare(
            state: state,
            activityId: comparisonActivityId,
            action: AnswerComparisonPair(answer),
          );
          if (index == 0) {
            firstAnswerCommand = command;
            expect(command.expectedScopeRevision, state.revision);
            expect(
              jsonDecode(
                ComparisonLearningCommandCodec.canonicalCommand(command),
              )['expectedScopeRevision'],
              state.revision,
            );
          }
          expect(answer.expectedRelationSnapshot, exercise.expectedRelation);
          state = (await repository.submit(command)).state;
          state = (await fixture.commit(
            repository,
            state,
            const AdvanceComparisonPair(),
          )).state;
        }

        state = (await fixture.commit(
          repository,
          state,
          const FinishComparisonRun(recordCompletion: true),
        )).state;
        state = (await fixture.commit(
          repository,
          state,
          const ReviewComparisonPairs(),
        )).state;
        final reviewedSession = fixture.session(state);
        final reviewedPair = reviewedSession.currentItemId!;
        expect(reviewedPair, 'fr07b-pair-01');
        final latestAnswerCommand = repository.prepare(
          state: state,
          activityId: comparisonActivityId,
          action: AnswerComparisonPair(
            _answerFor(
              fixture,
              pairId: reviewedPair,
              runGeneration: state.slot!.cursor.generation,
              round: reviewedSession.round,
              correct: false,
            ),
          ),
        );
        state = (await repository.submit(latestAnswerCommand)).state;

        expect(firstAnswerCommand, isNotNull);
        final sqlPayload = await _receiptPayload(
          fixture.handle,
          fixture.storageScope,
          firstAnswerCommand!.token,
        );
        expect(
          jsonDecode(sqlPayload)['expectedScopeRevision'],
          firstAnswerCommand.expectedScopeRevision,
        );

        await fixture.handle.close();
        await fixture.handle.reopen();
        final reopened = await repository.load();
        final attempts = reopened.attempts
            .where((attempt) => attempt.pairId == 'fr07b-pair-01')
            .toList();
        expect(attempts, hasLength(2));
        final first = attempts.first;
        final exercise = fixture.catalogue.exercise('fr07b-pair-01');
        expect(first.selectedRelation, PhonemeRelation.same);
        expect(first.expectedRelation, PhonemeRelation.different);
        expect(first.correct, isFalse);
        expect(first.observations.map((observation) => observation.slot), [
          ComparisonSample.a,
          ComparisonSample.b,
        ]);
        expect(
          first.observations.map((observation) => observation.referenceId),
          [exercise.sampleA.referenceId, exercise.sampleB.referenceId],
        );
        for (final observation in first.observations) {
          expect(observation.outcome, CourseAudioOutcome.completed);
          expect(observation.source, CourseAudioSource.unverifiedRecording);
          expect(observation.activityId, comparisonActivityId);
          expect(observation.runGeneration, 1);
          expect(observation.round, 1);
          expect(observation.pairId, 'fr07b-pair-01');
          expect(
            observation.uiGeneration,
            first.observations.first.uiGeneration,
          );
        }
        expect(attempts.last.round, 2);
        expect(attempts.last.presentation, AttemptPresentation.repeatInRun);
        expect(attempts.last.afterDebrief, isTrue);

        final checkpointSession = fixture.session(reopened);
        expect(checkpointSession.sessionId, 'comparison-session');
        expect(checkpointSession.round, 2);
        expect(checkpointSession.currentItemId, 'fr07b-pair-01');
        expect(checkpointSession.answered, isTrue);
        expect(checkpointSession.attemptCount, 11);
        expect(checkpointSession.latestAnswers['fr07b-pair-01'], isFalse);

        final mistake = reopened.mistakes.values.single;
        expect(mistake.key.pairId, 'fr07b-pair-01');
        expect(mistake.failureCount, 2);
        final summary = reopened.summaries.entries
            .singleWhere((entry) => entry.key.pairId == 'fr07b-pair-01')
            .value;
        expect(summary.firstInRun.total, 1);
        expect(summary.firstInRun.correct, 0);
        expect(summary.repeatInRun.total, 1);
        expect(summary.repeatInRun.correct, 0);
        expect(summary.afterDebrief.total, 1);
        expect(summary.afterDebrief.correct, 0);
        expect(reopened.completions, hasLength(1));
        expect(
          reopened.slot!.latestReceipt.canonicalCommand,
          comparisonCanonicalCommand(latestAnswerCommand),
        );
      },
    );

    test(
      'comparison_evidence_rows_are_checked_against_authored_A_B_refs',
      () async {
        final repository = fixture.repository();
        var state = await repository.load();
        state = (await fixture.commit(
          repository,
          state,
          StartComparisonRun(
            sessionId: 'corrupt-evidence-session',
            policy: LessonPolicy(),
          ),
        )).state;
        final session = fixture.session(state);
        final command = repository.prepare(
          state: state,
          activityId: comparisonActivityId,
          action: AnswerComparisonPair(
            _answerFor(
              fixture,
              pairId: session.currentItemId!,
              runGeneration: state.slot!.cursor.generation,
              round: session.round,
              correct: true,
            ),
          ),
        );
        final committed = await repository.submit(command);
        final db = await fixture.handle.open();
        final scopeId = await fixture.scopeId(db);
        final attemptId =
            (await db
                    .customSelect(
                      'SELECT attempt_id FROM learning_attempts WHERE scope_id = ? '
                      'AND command_sequence = ?',
                      variables: [
                        Variable<int>(scopeId),
                        const Variable<int>(2),
                      ],
                    )
                    .getSingle())
                .read<String>('attempt_id');
        await db.customStatement(
          'UPDATE learning_attempt_evidence SET reference_id = ? '
          'WHERE scope_id = ? AND attempt_id = ? AND evidence_index = 0',
          ['not-the-authored-reference', scopeId, attemptId],
        );

        final corruptedReference = await _evidenceReference(
          fixture.handle,
          scopeId,
          attemptId,
          0,
        );
        expect(corruptedReference, 'not-the-authored-reference');
        await expectLater(
          repository.load(),
          throwsA(isA<LearningCorruptException>()),
        );
        expect(
          await _evidenceReference(fixture.handle, scopeId, attemptId, 0),
          corruptedReference,
        );
        expect(committed.state.attempts, hasLength(1));
      },
    );

    test(
      'detail_pruning_preserves_aggregates_and_latest_receipt_retry',
      () async {
        final repository = fixture.repository(historyLimit: 2);
        var state = await repository.load();
        state = (await fixture.commit(
          repository,
          state,
          StartComparisonRun(
            sessionId: 'retention-session',
            policy: LessonPolicy(),
          ),
        )).state;
        for (
          var index = 0;
          index < fixture.catalogue.exercises.length;
          index++
        ) {
          final session = fixture.session(state);
          state = (await fixture.commit(
            repository,
            state,
            AnswerComparisonPair(
              _answerFor(
                fixture,
                pairId: session.currentItemId!,
                runGeneration: state.slot!.cursor.generation,
                round: session.round,
                correct: index != 0,
              ),
            ),
          )).state;
          state = (await fixture.commit(
            repository,
            state,
            const AdvanceComparisonPair(),
          )).state;
        }
        final finishCommand = repository.prepare(
          state: state,
          activityId: comparisonActivityId,
          action: const FinishComparisonRun(recordCompletion: true),
        );
        state = (await repository.submit(finishCommand)).state;
        expect(state.attempts, hasLength(2));
        expect(state.receipts, hasLength(2));

        final db = await fixture.handle.open();
        final scopeId = await fixture.scopeId(db);
        await db.customStatement(
          'DELETE FROM learning_command_receipts WHERE scope_id = ? AND token = ?',
          [scopeId, finishCommand.token],
        );
        final beforeRetry = await _detailCounts(fixture.handle, scopeId);
        final notificationsBeforeRetry = fixture.notifications;

        await fixture.handle.close();
        await fixture.handle.reopen();
        final reopened = await repository.load();
        expect(reopened.attempts, hasLength(2));
        expect(reopened.receipts, hasLength(2));
        expect(reopened.mistakes.values.single.failureCount, 1);
        expect(reopened.summaries, hasLength(10));
        final firstSummary = reopened.summaries.entries
            .singleWhere((entry) => entry.key.pairId == 'fr07b-pair-01')
            .value;
        expect(firstSummary.firstInRun.total, 1);
        expect(firstSummary.firstInRun.correct, 0);
        expect(reopened.completions, hasLength(1));
        expect(
          reopened.slot!.latestReceipt.canonicalCommand,
          comparisonCanonicalCommand(finishCommand),
        );

        final duplicate = await repository.submit(finishCommand);
        expect(duplicate.duplicate, isTrue);
        expect(await _detailCounts(fixture.handle, scopeId), beforeRetry);
        expect(fixture.notifications, notificationsBeforeRetry);
      },
    );

    test(
      'latest_receipt_scope_revision_must_precede_current_on_load_and_lookup',
      () async {
        final repository = fixture.repository();
        final initial = await repository.load();
        final startCommand = repository.prepare(
          state: initial,
          activityId: comparisonActivityId,
          action: StartComparisonRun(
            sessionId: 'revision-check-session',
            policy: LessonPolicy(),
          ),
        );
        await repository.submit(startCommand);
        final db = await fixture.handle.open();
        final scopeId = await fixture.scopeId(db);
        final payload = await _latestReceiptPayload(fixture.handle, scopeId);
        final staleProof = Map<String, Object?>.from(jsonDecode(payload) as Map)
          ..['expectedScopeRevision'] = 1;
        await db.customStatement(
          'UPDATE learning_runs SET latest_receipt_payload = ? '
          'WHERE scope_id = ? AND activity_id = ?',
          [jsonEncode(staleProof), scopeId, comparisonActivityId],
        );
        final persisted = await _latestReceiptPayload(fixture.handle, scopeId);
        expect(jsonDecode(persisted)['expectedScopeRevision'], 1);

        await expectLater(
          repository.load(),
          throwsA(isA<LearningCorruptException>()),
        );
        await expectLater(
          repository.submit(startCommand),
          throwsA(isA<LearningCorruptException>()),
        );
        expect(await _latestReceiptPayload(fixture.handle, scopeId), persisted);
      },
    );
  });
}

final class _Fixture {
  _Fixture(this.file)
    : owner = LearningOwner.account('comparison-user'),
      scope = ComparisonProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.account('comparison-user'),
      ),
      storageScope = LearningStorageScope(
        owner: LearningOwner.account('comparison-user'),
        courseId: 'en-fr',
        family: LearningFamily.comparison,
      ) {
    catalogue = loadFrenchComparisonCatalogue();
    transitions = ComparisonLearningTransitionEngine(catalogue: catalogue);
    handle = LearningDatabaseHandle(
      open: () async =>
          LearningDatabase(DatabaseConnection(NativeDatabase(file))),
    );
  }

  final File file;
  final LearningOwner owner;
  final ComparisonProfileScope scope;
  final LearningStorageScope storageScope;
  late final ComparisonCatalogue catalogue;
  late final ComparisonLearningTransitionEngine transitions;
  late final LearningDatabaseHandle handle;
  int _tokenCounter = 0;
  int _clockCounter = 0;
  int notifications = 0;

  LearningAuthScope get auth =>
      LearningAuthScope(owner: owner, generation: 17, ready: true);

  SqliteComparisonLearningRepository repository({int historyLimit = 2000}) =>
      SqliteComparisonLearningRepository(
        database: handle,
        scope: scope,
        authGeneration: 17,
        currentAuth: () => auth,
        backendOwner: () => owner,
        transitions: transitions,
        clock: _now,
        newToken: _newToken,
        historyLimit: historyLimit,
        onCommitted: () => notifications++,
      );

  Future<ComparisonCommit> commit(
    SqliteComparisonLearningRepository repository,
    ComparisonLearningState state,
    ComparisonAction action,
  ) => repository.submit(
    repository.prepare(
      state: state,
      activityId: comparisonActivityId,
      action: action,
    ),
  );

  LessonSectionSession session(ComparisonLearningState state) =>
      LessonSectionSession.fromJson(
        Map<String, dynamic>.from(state.slot!.checkpoint.sessionJson),
        itemIds: catalogue.exercises.map((exercise) => exercise.id).toList(),
        contentRevision: catalogue.contentRevision,
      );

  DateTime _now() =>
      DateTime.utc(2026, 10, 19, 12).add(Duration(seconds: _clockCounter++));

  String _newToken() => (++_tokenCounter).toRadixString(36).padLeft(22, '0');

  Future<int> scopeId(LearningDatabase db) async =>
      (await db
              .customSelect(
                'SELECT id FROM learning_scopes WHERE owner_kind = ? AND owner_id = ? '
                'AND course_id = ? AND family = ?',
                variables: [
                  const Variable<String>('account'),
                  Variable<String>(owner.userId!),
                  const Variable<String>('en-fr'),
                  const Variable<String>('comparison'),
                ],
              )
              .getSingle())
          .read<int>('id');

  Future<void> close() => handle.close();
}

ComparePhonemesAnswer _answerFor(
  _Fixture fixture, {
  required String pairId,
  required int runGeneration,
  required int round,
  required bool correct,
}) {
  final exercise = fixture.catalogue.exercise(pairId);
  final observedAt = DateTime.utc(
    2026,
    10,
    19,
    12,
  ).add(Duration(seconds: fixture._clockCounter++));
  final selected = correct
      ? exercise.expectedRelation
      : exercise.expectedRelation == PhonemeRelation.same
      ? PhonemeRelation.different
      : PhonemeRelation.same;
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
          activityId: comparisonActivityId,
          runGeneration: runGeneration,
          round: round,
          pairId: pairId,
          profile: fixture.scope,
          uiGeneration: observedAt.millisecondsSinceEpoch,
        ),
    ],
  );
}

Future<String> _receiptPayload(
  LearningDatabaseHandle handle,
  LearningStorageScope scope,
  String token,
) async {
  final db = await handle.open();
  final scopeId =
      (await db
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
              .getSingle())
          .read<int>('id');
  return (await db
          .customSelect(
            'SELECT canonical_payload FROM learning_command_receipts '
            'WHERE scope_id = ? AND token = ?',
            variables: [Variable<int>(scopeId), Variable<String>(token)],
          )
          .getSingle())
      .read<String>('canonical_payload');
}

Future<String> _latestReceiptPayload(
  LearningDatabaseHandle handle,
  int scopeId,
) async {
  final db = await handle.open();
  return (await db
          .customSelect(
            'SELECT latest_receipt_payload FROM learning_runs '
            'WHERE scope_id = ? AND activity_id = ?',
            variables: [
              Variable<int>(scopeId),
              const Variable<String>(comparisonActivityId),
            ],
          )
          .getSingle())
      .read<String>('latest_receipt_payload');
}

Future<String> _evidenceReference(
  LearningDatabaseHandle handle,
  int scopeId,
  String attemptId,
  int index,
) async {
  final db = await handle.open();
  return (await db
          .customSelect(
            'SELECT reference_id FROM learning_attempt_evidence WHERE scope_id = ? '
            'AND attempt_id = ? AND evidence_index = ?',
            variables: [
              Variable<int>(scopeId),
              Variable<String>(attemptId),
              Variable<int>(index),
            ],
          )
          .getSingle())
      .read<String>('reference_id');
}

Future<Map<String, int>> _detailCounts(
  LearningDatabaseHandle handle,
  int scopeId,
) async {
  final db = await handle.open();
  final attempts =
      (await db
              .customSelect(
                'SELECT count(*) AS count FROM learning_attempts WHERE scope_id = ?',
                variables: [Variable<int>(scopeId)],
              )
              .getSingle())
          .read<int>('count');
  final receipts =
      (await db
              .customSelect(
                'SELECT count(*) AS count FROM learning_command_receipts WHERE scope_id = ?',
                variables: [Variable<int>(scopeId)],
              )
              .getSingle())
          .read<int>('count');
  final summaries =
      (await db
              .customSelect(
                'SELECT count(*) AS count FROM learning_summaries WHERE scope_id = ? '
                'AND family = ?',
                variables: [
                  Variable<int>(scopeId),
                  const Variable<String>('comparison'),
                ],
              )
              .getSingle())
          .read<int>('count');
  final completions =
      (await db
              .customSelect(
                'SELECT count(*) AS count FROM learning_completions WHERE scope_id = ?',
                variables: [Variable<int>(scopeId)],
              )
              .getSingle())
          .read<int>('count');
  return {
    'attempts': attempts,
    'receipts': receipts,
    'summaries': summaries,
    'completions': completions,
  };
}
