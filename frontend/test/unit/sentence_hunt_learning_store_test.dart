import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_sql_repository.dart';

import '../support/sentence_hunt_fixtures.dart';
import '../support/sqlite_learning_test_harness.dart'
    show openFileLearningTestDatabase;

final class _SentenceSqlHarness {
  _SentenceSqlHarness()
    : owner = LearningOwner.account('sentence-hunt-store-test'),
      catalogue = syntheticSentenceCatalogue() {
    directory = Directory.systemTemp.createTempSync('sentence-hunt-store-');
    database = LearningDatabaseHandle(
      open: () => openFileLearningTestDatabase(
        File('${directory.path}/learning.sqlite'),
      ),
    );
    final auth = LearningAuthScope(owner: owner, generation: 0, ready: true);
    store = SqliteSentenceHuntLearningRepository(
      database: database,
      scope: SentenceHuntProfileScope(courseId: 'en-fr', owner: owner),
      authGeneration: 0,
      currentAuth: () => auth,
      backendOwner: () => owner,
      transitions: SentenceHuntTransitionEngine(catalogue: catalogue),
      clock: () => DateTime.utc(2026, 10, 18, 12),
      newToken: () => 'sentence${(++_token).toString().padLeft(14, '0')}',
    );
    addTearDown(close);
  }

  final LearningOwner owner;
  final SentenceHuntCatalogue catalogue;
  late final Directory directory;
  late final LearningDatabaseHandle database;
  late final SqliteSentenceHuntLearningRepository store;
  int _token = 0;

  SentenceHuntCommand startCommand(String sectionId, String sessionId) {
    final state = SentenceHuntLearningState.empty(store.scope);
    return store.prepare(
      state: state,
      sectionId: sectionId,
      action: StartSentenceHuntRun(
        sessionId: sessionId,
        policy: catalogue.section(sectionId).policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );
  }

  Future<void> rejectNextStart() async {
    final db = await database.open();
    await db.customStatement('''
      CREATE TRIGGER task10_sentence_store_reject_start
      BEFORE INSERT ON learning_runs
      BEGIN SELECT RAISE(ABORT, 'task10 sentence store test failure'); END
    ''');
  }

  Future<void> allowStart() async {
    final db = await database.open();
    await db.customStatement(
      'DROP TRIGGER IF EXISTS task10_sentence_store_reject_start',
    );
  }

  Future<int> count(String table) async {
    final db = await database.open();
    return (await db
            .customSelect('SELECT COUNT(*) AS row_count FROM $table')
            .getSingle())
        .read<int>('row_count');
  }

  Future<void> close() async {
    await database.close();
    if (directory.existsSync()) await directory.delete(recursive: true);
  }
}

void main() {
  test(
    'SQL sentence-hunt start retries exact identity without a second write',
    () async {
      final harness = _SentenceSqlHarness();
      final sectionId = fixtureSectionIds.first;
      final command = harness.startCommand(sectionId, 'dedupe-start');

      final committed = await harness.store.submit(command);
      final rowsAfterCommit = await harness.count('learning_command_receipts');
      final duplicate = await harness.store.submit(command);

      expect(committed.duplicate, isFalse);
      expect(committed.state.revision, 1);
      expect(committed.state.commitOrdinal, 1);
      expect(committed.slot.sectionId, sectionId);
      expect(duplicate.duplicate, isTrue);
      expect(duplicate.state.revision, 1);
      expect(await harness.count('learning_command_receipts'), rowsAfterCommit);

      final changed = SentenceHuntLearningCommand(
        scope: command.scope,
        authGeneration: command.authGeneration,
        sectionId: command.sectionId,
        sectionFingerprint: command.sectionFingerprint,
        expected: command.expected,
        expectedScopeRevision: command.expectedScopeRevision,
        token: command.token,
        submittedAt: command.submittedAt,
        action: StartSentenceHuntRun(
          sessionId: 'changed-payload',
          policy: harness.catalogue.section(sectionId).policy,
          mode: SentenceHuntRunMode.practice,
        ),
      );
      await expectLater(
        harness.store.submit(changed),
        throwsA(isA<LearningInvalidCommandException>()),
      );
      expect((await harness.store.load()).revision, 1);
    },
  );

  test(
    'SQL start failure rolls back and the frozen command retries once',
    () async {
      final harness = _SentenceSqlHarness();
      final sectionId = fixtureSectionIds.first;
      await harness.store.load();
      final command = harness.startCommand(sectionId, 'retry-start');
      await harness.rejectNextStart();

      await expectLater(
        harness.store.submit(command),
        throwsA(isA<LearningSaveException>()),
      );
      expect((await harness.store.load()).revision, 0);
      expect(await harness.count('learning_runs'), 0);
      expect(await harness.count('learning_command_receipts'), 0);

      await harness.allowStart();
      final retry = await harness.store.submit(command);
      expect(retry.duplicate, isFalse);
      expect(retry.state.revision, 1);
      expect(retry.state.commitOrdinal, 1);
      expect(await harness.count('learning_runs'), 1);
      expect(await harness.count('learning_command_receipts'), 1);
    },
  );
}
