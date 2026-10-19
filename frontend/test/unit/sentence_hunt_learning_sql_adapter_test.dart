import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_store.dart'
    show SentenceHuntCommit;
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/learning_storage_scope.dart';
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_command_codec.dart';
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_sql_repository.dart';
import '../support/sentence_hunt_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('inactive sentence-hunt SQLite adapter', () {
    late Directory directory;
    late _Fixture fixture;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('sentence-sqlite-');
      fixture = _Fixture(File('${directory.path}/learning.sqlite'));
    });

    tearDown(() async {
      await fixture.close();
      await directory.delete(recursive: true);
    });

    test(
      'sentence_answer_values_playback_identity_and_checkpoint_reopen_together',
      () async {
        final repository = fixture.repository();
        final empty = await repository.load();
        final db = await fixture.handle.open();
        final scopeId = await fixture.scopeId(db);
        final headerBefore = await fixture.scopeHeader(db, scopeId);
        final rowsBefore = await fixture.rowCounts(db, scopeId);
        final notificationsBefore = fixture.notifications;
        expect(headerBefore['revision'], 0);
        expect(headerBefore['commit_ordinal'], 0);
        expect(rowsBefore, {'attempts': 0, 'receipts': 0, 'runs': 0});
        expect(notificationsBefore, 0);

        final sectionId = fixture.catalogue.sections.first.id;
        var state = (await fixture.commit(
          repository,
          empty,
          sectionId,
          StartSentenceHuntRun(
            sessionId: 'sqlite-sentence-session',
            policy: fixture.catalogue.section(sectionId).policy,
            mode: SentenceHuntRunMode.practice,
          ),
        )).state;

        final session = fixture.session(state, sectionId);
        final itemId = session.currentItemId!;
        final item = fixture.catalogue.item(sectionId, itemId);
        final answerCommand = repository.prepare(
          state: state,
          sectionId: sectionId,
          action: AnswerSentenceHuntItem(
            SentenceHuntAnswer(
              content: item.identity,
              selectedTokenIds: [item.selectableTokenIds[1]],
              expectedTokenIdsSnapshot: item.expectedTokenIds,
              playback: SentenceHuntPlaybackObservation(
                scope: fixture.scope,
                content: item.identity,
                runGeneration: state.slots[sectionId]!.cursor.generation,
                round: session.round,
                uiGeneration: 73,
                referenceId: item.identity.audioRefId,
                outcome: CourseAudioOutcome.completed,
                source: CourseAudioSource.reviewedRecording,
              ),
            ),
          ),
        );
        expect(answerCommand.expectedScopeRevision, state.revision);
        final sqlCommand =
            jsonDecode(SentenceHuntCommandCodec.canonicalCommand(answerCommand))
                as Map<String, dynamic>;
        expect(sqlCommand['expectedScopeRevision'], state.revision);

        state = (await repository.submit(answerCommand)).state;
        await fixture.handle.close();
        await fixture.handle.reopen();
        final reopened = await repository.load();

        final attempt = reopened.attempts.single;
        expect(attempt.content.sectionId, sectionId);
        expect(attempt.content.itemId, 'fr08-vowel-01');
        expect(attempt.content.sentenceId, 'fr08-vowel-01-sentence');
        expect(attempt.content.audioRefId, 'fr08-vowel-01-audio');
        expect(attempt.content.annotationHash, 'c' * 64);
        expect(attempt.content.contentRevision, 1);
        expect(attempt.content.annotationRevision, 1);
        expect(attempt.selectedTokenIds, ['fr08-vowel-01-token-02']);
        expect(attempt.expectedTokenIds, [
          'fr08-vowel-01-token-01',
          'fr08-vowel-01-token-04',
        ]);
        expect(attempt.correct, isFalse);
        expect(attempt.playback.referenceId, 'fr08-vowel-01-audio');
        expect(attempt.playback.outcome, CourseAudioOutcome.completed);
        expect(attempt.playback.source, CourseAudioSource.reviewedRecording);
        expect(attempt.playback.content, attempt.content);
        expect(attempt.playback.runGeneration, 1);
        expect(attempt.playback.round, 1);
        expect(attempt.playback.uiGeneration, 73);

        final reopenedSession = fixture.session(reopened, sectionId);
        expect(reopenedSession.sessionId, 'sqlite-sentence-session');
        expect(reopenedSession.position, 0);
        expect(reopenedSession.answered, isTrue);
        expect(reopenedSession.latestAnswers[itemId], isFalse);
        final summary = reopened.summaries.values.single;
        expect(summary.firstInRun.total, 1);
        expect(summary.firstInRun.correct, 0);
        expect(summary.repeatInRun.total, 0);
        expect(summary.firstTeachingExposed.total, 0);
        expect(reopened.mistakes.values.single.content, attempt.content);
        expect(reopened.mistakes.values.single.failureCount, 1);
        expect(reopened.slots[sectionId]!.cursor.sequence, 2);
        expect(reopened.slots[sectionId]!.checkpoint.runStartRound, 1);
        expect(reopened.revision, state.revision);

        final savedHeader = await fixture.scopeHeader(
          await fixture.handle.open(),
          scopeId,
        );
        expect(savedHeader['revision'], 2);
        expect(savedHeader['commit_ordinal'], 2);
        expect(fixture.notifications, notificationsBefore + 2);
        final persistedCommand = await fixture.receiptPayload(
          await fixture.handle.open(),
          scopeId,
          answerCommand.token,
        );
        expect(
          jsonDecode(persistedCommand)['expectedScopeRevision'],
          answerCommand.expectedScopeRevision,
        );
      },
    );

    test('empty_selection_survives_receipt_pruning_and_reopen', () async {
      final repository = fixture.repository(historyLimit: 1);
      final sectionId = fixture.catalogue.sections.first.id;
      var state = await repository.load();
      state = (await fixture.commit(
        repository,
        state,
        sectionId,
        StartSentenceHuntRun(
          sessionId: 'empty-selection-session',
          policy: fixture.catalogue.section(sectionId).policy,
          mode: SentenceHuntRunMode.practice,
        ),
      )).state;

      final session = fixture.session(state, sectionId);
      final item = fixture.catalogue.item(sectionId, session.currentItemId!);
      final answer = repository.prepare(
        state: state,
        sectionId: sectionId,
        action: AnswerSentenceHuntItem(
          SentenceHuntAnswer(
            content: item.identity,
            selectedTokenIds: const <String>[],
            expectedTokenIdsSnapshot: item.expectedTokenIds,
            playback: SentenceHuntPlaybackObservation(
              scope: fixture.scope,
              content: item.identity,
              runGeneration: state.slots[sectionId]!.cursor.generation,
              round: session.round,
              uiGeneration: 91,
              referenceId: item.identity.audioRefId,
              outcome: CourseAudioOutcome.completed,
              source: CourseAudioSource.reviewedRecording,
            ),
          ),
        ),
      );
      state = (await repository.submit(answer)).state;
      state = (await fixture.commit(
        repository,
        state,
        sectionId,
        const AdvanceSentenceHuntItem(),
      )).state;
      expect(state.attempts.single.selectedTokenIds, isEmpty);

      final db = await fixture.handle.open();
      final scopeId = await fixture.scopeId(db);
      final answerReceipt = await db
          .customSelect(
            'SELECT count(*) AS count FROM learning_command_receipts '
            'WHERE scope_id = ? AND token = ?',
            variables: [Variable<int>(scopeId), Variable<String>(answer.token)],
          )
          .getSingle();
      expect(answerReceipt.read<int>('count'), 0);

      await fixture.handle.close();
      await fixture.handle.reopen();
      final reopened = await repository.load();
      expect(reopened.attempts.single.selectedTokenIds, isEmpty);
      expect(reopened.attempts.single.correct, isFalse);
      expect(
        reopened.slots[sectionId]!.latestReceipt.token,
        isNot(answer.token),
      );
    });

    test(
      'corrupt_latest_receipt_scope_revision_is_rejected_without_repair',
      () async {
        final repository = fixture.repository();
        final empty = await repository.load();
        final sectionId = fixture.catalogue.sections.first.id;
        final startCommand = repository.prepare(
          state: empty,
          sectionId: sectionId,
          action: StartSentenceHuntRun(
            sessionId: 'corrupt-receipt-session',
            policy: fixture.catalogue.section(sectionId).policy,
            mode: SentenceHuntRunMode.practice,
          ),
        );
        await repository.submit(startCommand);

        final db = await fixture.handle.open();
        final scopeId = await fixture.scopeId(db);
        final payload = await fixture.latestReceiptPayload(db, scopeId);
        final invalidProof = Map<String, Object?>.from(
          jsonDecode(payload) as Map,
        )..['expectedScopeRevision'] = 1;
        await db.customStatement(
          'UPDATE learning_runs SET latest_receipt_payload = ? WHERE scope_id = ?',
          [jsonEncode(invalidProof), scopeId],
        );
        final persisted = await fixture.latestReceiptPayload(db, scopeId);
        expect(jsonDecode(persisted)['expectedScopeRevision'], 1);

        final headerBefore = await fixture.scopeHeader(db, scopeId);
        final rowsBefore = await fixture.rowCounts(db, scopeId);
        final notificationsBefore = fixture.notifications;
        await expectLater(
          repository.load(),
          throwsA(isA<LearningCorruptException>()),
        );
        expect(await fixture.latestReceiptPayload(db, scopeId), persisted);
        expect(await fixture.scopeHeader(db, scopeId), headerBefore);
        expect(await fixture.rowCounts(db, scopeId), rowsBefore);
        expect(fixture.notifications, notificationsBefore);

        await expectLater(
          repository.submit(startCommand),
          throwsA(isA<LearningCorruptException>()),
        );
        expect(await fixture.latestReceiptPayload(db, scopeId), persisted);
        expect(await fixture.scopeHeader(db, scopeId), headerBefore);
        expect(await fixture.rowCounts(db, scopeId), rowsBefore);
        expect(fixture.notifications, notificationsBefore);
      },
    );

    test('corrupt_attempt_commit_ordinal_is_rejected_without_repair', () async {
      final repository = fixture.repository();
      final sectionId = fixture.catalogue.sections.first.id;
      var state = await repository.load();
      state = (await fixture.commit(
        repository,
        state,
        sectionId,
        StartSentenceHuntRun(
          sessionId: 'corrupt-attempt-session',
          policy: fixture.catalogue.section(sectionId).policy,
          mode: SentenceHuntRunMode.practice,
        ),
      )).state;
      await repository.submit(
        repository.prepare(
          state: state,
          sectionId: sectionId,
          action: fixture.answerCurrent(state, sectionId, uiGeneration: 81),
        ),
      );

      final db = await fixture.handle.open();
      final scopeId = await fixture.scopeId(db);
      final attemptRow = await db
          .customSelect(
            'SELECT attempt_id, commit_ordinal FROM learning_attempts '
            'WHERE scope_id = ?',
            variables: [Variable<int>(scopeId)],
          )
          .getSingle();
      final attemptId = attemptRow.read<String>('attempt_id');
      expect(attemptRow.read<int>('commit_ordinal'), 2);
      await db.customStatement(
        'UPDATE learning_attempts SET commit_ordinal = 1 '
        'WHERE scope_id = ? AND attempt_id = ?',
        [scopeId, attemptId],
      );

      final headerBefore = await fixture.scopeHeader(db, scopeId);
      final rowsBefore = await fixture.rowCounts(db, scopeId);
      final notificationsBefore = fixture.notifications;
      await expectLater(
        repository.load(),
        throwsA(isA<LearningCorruptException>()),
      );
      final corruptedOrdinal = await db
          .customSelect(
            'SELECT commit_ordinal FROM learning_attempts '
            'WHERE scope_id = ? AND attempt_id = ?',
            variables: [Variable<int>(scopeId), Variable<String>(attemptId)],
          )
          .getSingle();
      expect(corruptedOrdinal.read<int>('commit_ordinal'), 1);
      expect(await fixture.scopeHeader(db, scopeId), headerBefore);
      expect(await fixture.rowCounts(db, scopeId), rowsBefore);
      expect(fixture.notifications, notificationsBefore);
    });

    test(
      'bounded_detail_retention_preserves_aggregates_and_latest_receipt_proof',
      () async {
        final repository = fixture.repository(historyLimit: 2);
        final sectionId = fixture.catalogue.sections.first.id;
        var state = await repository.load();
        state = (await fixture.commit(
          repository,
          state,
          sectionId,
          StartSentenceHuntRun(
            sessionId: 'retention-session',
            policy: fixture.catalogue.section(sectionId).policy,
            mode: SentenceHuntRunMode.practice,
          ),
        )).state;

        final firstItem = fixture.catalogue.item(
          sectionId,
          fixture.session(state, sectionId).currentItemId!,
        );
        SentenceHuntLearningCommand? latestAnswer;
        for (var index = 0; index < 3; index++) {
          final command = repository.prepare(
            state: state,
            sectionId: sectionId,
            action: fixture.answerCurrent(
              state,
              sectionId,
              uiGeneration: 100 + index,
            ),
          );
          latestAnswer = command;
          state = (await repository.submit(command)).state;
          if (index < 2) {
            state = (await fixture.commit(
              repository,
              state,
              sectionId,
              const AdvanceSentenceHuntItem(),
            )).state;
          }
        }

        expect(state.attempts, hasLength(2));
        expect(state.receipts, hasLength(2));
        final db = await fixture.handle.open();
        final scopeId = await fixture.scopeId(db);
        expect(await fixture.rowCounts(db, scopeId), {
          'attempts': 2,
          'receipts': 2,
          'runs': 1,
        });

        await fixture.handle.close();
        await fixture.handle.reopen();
        final reopened = await repository.load();
        final reopenedDb = await fixture.handle.open();
        expect(reopened.attempts, hasLength(2));
        expect(reopened.receipts, hasLength(2));
        expect(reopened.mistakes, hasLength(3));
        expect(reopened.summaries, hasLength(3));
        expect(
          reopened.attempts.any(
            (attempt) => attempt.content == firstItem.identity,
          ),
          isFalse,
        );
        final firstSummary = reopened.summaries.entries
            .singleWhere((entry) => entry.key.content == firstItem.identity)
            .value;
        expect(firstSummary.firstInRun.total, 1);
        expect(firstSummary.firstInRun.correct, 0);
        expect(
          reopened.slots[sectionId]!.latestReceipt.token,
          latestAnswer!.token,
        );

        final retainedCommand = latestAnswer;
        final latestHistoryRows = await reopenedDb
            .customSelect(
              'SELECT count(*) AS count FROM learning_command_receipts '
              'WHERE scope_id = ? AND token = ?',
              variables: [
                Variable<int>(scopeId),
                Variable<String>(retainedCommand.token),
              ],
            )
            .getSingle();
        expect(latestHistoryRows.read<int>('count'), 1);
        await reopenedDb.customStatement(
          'DELETE FROM learning_command_receipts WHERE scope_id = ? AND token = ?',
          [scopeId, retainedCommand.token],
        );

        final headerBeforeRetry = await fixture.scopeHeader(
          reopenedDb,
          scopeId,
        );
        final rowsBeforeRetry = await fixture.rowCounts(reopenedDb, scopeId);
        final notificationsBeforeRetry = fixture.notifications;
        final duplicate = await repository.submit(retainedCommand);
        expect(duplicate.duplicate, isTrue);
        expect(
          await fixture.scopeHeader(reopenedDb, scopeId),
          headerBeforeRetry,
        );
        expect(await fixture.rowCounts(reopenedDb, scopeId), rowsBeforeRetry);
        expect(fixture.notifications, notificationsBeforeRetry);
        expect(duplicate.slot.latestReceipt.token, retainedCommand.token);
      },
    );
  });
}

final class _Fixture {
  _Fixture(this.file)
    : owner = LearningOwner.account('sentence-user'),
      scope = SentenceHuntProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.account('sentence-user'),
      ),
      storageScope = LearningStorageScope(
        owner: LearningOwner.account('sentence-user'),
        courseId: 'en-fr',
        family: LearningFamily.sentenceHunt,
      ) {
    catalogue = syntheticSentenceCatalogue();
    transitions = SentenceHuntTransitionEngine(catalogue: catalogue);
    handle = LearningDatabaseHandle(
      open: () async =>
          LearningDatabase(DatabaseConnection(NativeDatabase(file))),
    );
  }

  final File file;
  final LearningOwner owner;
  final SentenceHuntProfileScope scope;
  final LearningStorageScope storageScope;
  late final SentenceHuntCatalogue catalogue;
  late final SentenceHuntTransitionEngine transitions;
  late final LearningDatabaseHandle handle;
  int _tokenCounter = 0;
  int _clockCounter = 0;
  int notifications = 0;

  LearningAuthScope get auth =>
      LearningAuthScope(owner: owner, generation: 29, ready: true);

  SqliteSentenceHuntLearningRepository repository({int historyLimit = 2000}) =>
      SqliteSentenceHuntLearningRepository(
        database: handle,
        scope: scope,
        authGeneration: 29,
        currentAuth: () => auth,
        backendOwner: () => owner,
        transitions: transitions,
        clock: _now,
        newToken: _newToken,
        historyLimit: historyLimit,
        onCommitted: () => notifications++,
      );

  Future<SentenceHuntCommit> commit(
    SqliteSentenceHuntLearningRepository repository,
    SentenceHuntLearningState state,
    String sectionId,
    SentenceHuntAction action,
  ) => repository.submit(
    repository.prepare(state: state, sectionId: sectionId, action: action),
  );

  AnswerSentenceHuntItem answerCurrent(
    SentenceHuntLearningState state,
    String sectionId, {
    required int uiGeneration,
  }) {
    final currentSession = session(state, sectionId);
    final item = catalogue.item(sectionId, currentSession.currentItemId!);
    final selectedTokenIds = [
      item.selectableTokenIds.firstWhere(
        (tokenId) => !item.expectedTokenIds.contains(tokenId),
      ),
    ];
    return AnswerSentenceHuntItem(
      SentenceHuntAnswer(
        content: item.identity,
        selectedTokenIds: selectedTokenIds,
        expectedTokenIdsSnapshot: item.expectedTokenIds,
        playback: SentenceHuntPlaybackObservation(
          scope: scope,
          content: item.identity,
          runGeneration: state.slots[sectionId]!.cursor.generation,
          round: currentSession.round,
          uiGeneration: uiGeneration,
          referenceId: item.identity.audioRefId,
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.reviewedRecording,
        ),
      ),
    );
  }

  LessonSectionSession session(
    SentenceHuntLearningState state,
    String sectionId,
  ) => LessonSectionSession.fromJson(
    Map<String, dynamic>.from(state.slots[sectionId]!.checkpoint.sessionJson),
    itemIds: catalogue
        .section(sectionId)
        .items
        .map((item) => item.identity.itemId)
        .toList(),
    contentRevision: catalogue.section(sectionId).contentRevision,
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
                  const Variable<String>('sentence-hunt'),
                ],
              )
              .getSingle())
          .read<int>('id');

  Future<String> latestReceiptPayload(LearningDatabase db, int scopeId) async =>
      (await db
              .customSelect(
                'SELECT latest_receipt_payload FROM learning_runs '
                'WHERE scope_id = ?',
                variables: [Variable<int>(scopeId)],
              )
              .getSingle())
          .read<String>('latest_receipt_payload');

  Future<Map<String, Object>> scopeHeader(
    LearningDatabase db,
    int scopeId,
  ) async {
    final row = await db
        .customSelect(
          'SELECT revision, commit_ordinal FROM learning_scopes WHERE id = ?',
          variables: [Variable<int>(scopeId)],
        )
        .getSingle();
    return {
      'revision': row.read<int>('revision'),
      'commit_ordinal': row.read<int>('commit_ordinal'),
    };
  }

  Future<Map<String, int>> rowCounts(LearningDatabase db, int scopeId) async {
    final rows = <String, int>{};
    for (final table in const [
      'learning_attempts',
      'learning_command_receipts',
      'learning_runs',
    ]) {
      final row = await db
          .customSelect(
            'SELECT count(*) AS count FROM $table WHERE scope_id = ?',
            variables: [Variable<int>(scopeId)],
          )
          .getSingle();
      rows[table] = row.read<int>('count');
    }
    return {
      'attempts': rows['learning_attempts']!,
      'receipts': rows['learning_command_receipts']!,
      'runs': rows['learning_runs']!,
    };
  }

  Future<String> receiptPayload(
    LearningDatabase db,
    int scopeId,
    String token,
  ) async =>
      (await db
              .customSelect(
                'SELECT canonical_payload FROM learning_command_receipts '
                'WHERE scope_id = ? AND token = ?',
                variables: [Variable<int>(scopeId), Variable<String>(token)],
              )
              .getSingle())
          .read<String>('canonical_payload');

  Future<void> close() => handle.close();
}
