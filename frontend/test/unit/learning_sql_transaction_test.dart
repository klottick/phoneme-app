import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/learning_storage_types.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart';
import 'package:linguist/src/core/course/storage/learning_sql_transaction.dart';
import 'package:linguist/src/core/course/storage/learning_storage_scope.dart';

import '../support/sqlite_learning_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SQLite learning command coordinator', () {
    late Directory tempDirectory;
    late File file;
    late _Harness harness;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'sqlite-learning-coordinator-',
      );
      file = File('${tempDirectory.path}/learning.sqlite');
      harness = _Harness(file);
    });

    tearDown(() async {
      await harness.close();
      await tempDirectory.delete(recursive: true);
    });

    test(
      'receipt_retry_precedes_stale_scope_revision_and_changed_payload_is_invalid',
      () async {
        final coordinator = harness.coordinator();
        final command = _command();
        final first = await coordinator.submit(command);
        expect(first.duplicate, isFalse);

        final replay = await coordinator.submit(command);
        expect(replay.duplicate, isTrue);
        expect(replay.state.revision, first.state.revision);
        expect(replay.state.commitOrdinal, first.state.commitOrdinal);

        final changedPayload = _command(value: 'changed');
        await expectLater(
          coordinator.submit(changedPayload),
          throwsA(isA<LearningInvalidCommandException>()),
        );
        final db = await harness.handleFor(coordinator).open();
        expect(await _count(db, 'learning_attempts'), 1);
        expect(await _count(db, 'learning_command_receipts'), 1);
      },
    );

    test(
      'retry_load_reopens_the_same_file_and_preserves_committed_state',
      () async {
        final coordinator = harness.coordinator();
        final committed = await coordinator.submit(_command());

        final recovered = await coordinator.retryLoad();

        expect(recovered.revision, committed.state.revision);
        expect(recovered.commitOrdinal, committed.state.commitOrdinal);
        expect(recovered.cursors['activity-A']?.sequence, 1);
        final db = await harness.handleFor(coordinator).open();
        expect(await _count(db, 'learning_attempts'), 1);
        expect(await _count(db, 'learning_command_receipts'), 1);
      },
    );

    test(
      'duplicate_retry_after_ack_uses_current_state_without_outbox_or_notification',
      () async {
        final coordinator = harness.coordinator();
        final committed = await coordinator.submit(_command());
        final event = (await coordinator.readSupportedCourseEvents()).single;
        expect(event.id, 'answer-event');
        expect(harness.notifications, 1);

        await coordinator.acknowledgeSupportedCourseEvents(<String>{event.id});
        final currentAfterAck = await coordinator.load();
        expect(currentAfterAck.revision, greaterThan(committed.state.revision));
        expect(currentAfterAck.commitOrdinal, committed.state.commitOrdinal);
        expect(currentAfterAck.pendingIds, isEmpty);

        final db = await harness.handleFor(coordinator).open();
        final attemptsBeforeReplay = await _count(db, 'learning_attempts');
        final receiptsBeforeReplay = await _count(
          db,
          'learning_command_receipts',
        );
        final notificationsBeforeReplay = harness.notifications;

        final replay = await coordinator.submit(_command());
        expect(replay.duplicate, isTrue);
        expect(replay.state.revision, currentAfterAck.revision);
        expect(replay.state.commitOrdinal, currentAfterAck.commitOrdinal);
        expect(replay.state.pendingIds, isEmpty);
        expect(await coordinator.readSupportedCourseEvents(), isEmpty);
        expect(await _count(db, 'learning_attempts'), attemptsBeforeReplay);
        expect(
          await _count(db, 'learning_command_receipts'),
          receiptsBeforeReplay,
        );
        expect(harness.notifications, notificationsBeforeReplay);
        expect(
          harness.adapter.duplicateStates.last.revision,
          currentAfterAck.revision,
        );
      },
    );

    test(
      'scope_token_reuse_for_different_activity_is_invalid_in_retained_history',
      () async {
        final coordinator = harness.coordinator();
        await coordinator.submit(_command());
        final db = await harness.handleFor(coordinator).open();
        final attemptsBefore = await _count(db, 'learning_attempts');
        final receiptsBefore = await _count(db, 'learning_command_receipts');
        final otherActivity = _command(
          activityId: 'activity-B',
          token: _sharedToken,
          scopeRevision: 1,
          eventId: 'other-event',
        );
        expect(
          harness.adapter.commandCanonicalPayload(_command()),
          isNot(harness.adapter.commandCanonicalPayload(otherActivity)),
        );

        await expectLater(
          coordinator.submit(otherActivity),
          throwsA(isA<LearningInvalidCommandException>()),
        );
        expect(await _count(db, 'learning_attempts'), attemptsBefore);
        expect(await _count(db, 'learning_command_receipts'), receiptsBefore);
      },
    );

    test(
      'scope_token_reuse_for_different_activity_is_invalid_after_history_pruning',
      () async {
        final coordinator = harness.coordinator();
        await coordinator.submit(_command());
        final db = await harness.handleFor(coordinator).open();
        await db.customStatement(
          'DELETE FROM learning_command_receipts WHERE scope_id = ? AND token = ?',
          <Object?>[1, _sharedToken],
        );
        expect(
          (await db
                  .customSelect(
                    'SELECT latest_receipt_token FROM learning_runs '
                    'WHERE scope_id = ? AND activity_id = ?',
                    variables: <Variable<Object>>[
                      const Variable<int>(1),
                      const Variable<String>('activity-A'),
                    ],
                  )
                  .getSingle())
              .read<String>('latest_receipt_token'),
          _sharedToken,
        );
        final attemptsBefore = await _count(db, 'learning_attempts');
        final receiptsBefore = await _count(db, 'learning_command_receipts');

        await expectLater(
          coordinator.submit(
            _command(
              activityId: 'activity-B',
              token: _sharedToken,
              scopeRevision: 1,
              eventId: 'other-event',
            ),
          ),
          throwsA(isA<LearningInvalidCommandException>()),
        );
        expect(await _count(db, 'learning_attempts'), attemptsBefore);
        expect(await _count(db, 'learning_command_receipts'), receiptsBefore);
      },
    );

    test(
      'scope_token_with_all_proof_pruned_conflicts_on_stale_revision',
      () async {
        final coordinator = harness.coordinator();
        await coordinator.submit(_command());
        final db = await harness.handleFor(coordinator).open();
        await db.customStatement(
          'DELETE FROM learning_command_receipts WHERE scope_id = ? AND token = ?',
          <Object?>[1, _sharedToken],
        );
        await db.customStatement(
          'UPDATE learning_runs SET latest_receipt_token = ?, '
          'latest_receipt_payload = ? WHERE scope_id = ? AND activity_id = ?',
          <Object?>[
            _fourthToken,
            jsonEncode(<String, Object?>{
              'activityId': 'activity-A',
              'expectedScopeRevision': 1,
              'answer': 'replacement',
            }),
            1,
            'activity-A',
          ],
        );
        final attemptsBefore = await _count(db, 'learning_attempts');
        final receiptsBefore = await _count(db, 'learning_command_receipts');

        await expectLater(
          coordinator.submit(_command()),
          throwsA(isA<LearningConflictException>()),
        );
        expect(await _count(db, 'learning_attempts'), attemptsBefore);
        expect(await _count(db, 'learning_command_receipts'), receiptsBefore);
      },
    );

    test(
      'multiple_activity_latest_receipts_claiming_a_token_are_corrupt',
      () async {
        final coordinator = harness.coordinator();
        await coordinator.submit(_command());
        final db = await harness.handleFor(coordinator).open();
        await db.customStatement(
          'DROP INDEX ux_learning_runs_scope_latest_receipt_token',
        );
        await insertBinding(
          db,
          id: 200,
          scopeId: 1,
          activityId: 'activity-B',
          catalogueFingerprint: 'test-catalogue-B',
        );
        await insertRow(db, 'learning_runs', <String, Object?>{
          'scope_id': 1,
          'activity_id': 'activity-B',
          'activity_kind': 'discovery',
          'run_generation': 1,
          'sequence': 1,
          'cursor_revision': 0,
          'content_binding_id': 200,
          'run_mode': null,
          'finished': 0,
          'session_id': null,
          'policy_revision': null,
          'threshold_percent': null,
          'run_start_round': null,
          'checkpoint_json': '{}',
          'latest_receipt_token': _sharedToken,
          'latest_receipt_payload': jsonEncode(<String, Object?>{
            'activityId': 'activity-B',
            'expectedScopeRevision': 0,
            'answer': 'other',
          }),
          'latest_receipt_before_generation': 0,
          'latest_receipt_before_sequence': 0,
          'latest_receipt_before_cursor_revision': 0,
          'latest_receipt_commit_ordinal': 1,
        });
        final attemptsBefore = await _count(db, 'learning_attempts');

        await expectLater(
          coordinator.submit(_command()),
          throwsA(isA<LearningCorruptException>()),
        );
        expect(await _count(db, 'learning_attempts'), attemptsBefore);
      },
    );

    test('inconsistent_retained_and_latest_receipt_is_corrupt', () async {
      final coordinator = harness.coordinator();
      await coordinator.submit(_command());
      final db = await harness.handleFor(coordinator).open();
      await db.customStatement(
        'UPDATE learning_runs SET latest_receipt_payload = ? '
        'WHERE scope_id = ? AND activity_id = ?',
        <Object?>[
          jsonEncode(<String, Object?>{
            'activityId': 'activity-A',
            'expectedScopeRevision': 0,
            'answer': 'tampered',
          }),
          1,
          'activity-A',
        ],
      );
      final attemptsBefore = await _count(db, 'learning_attempts');
      final receiptsBefore = await _count(db, 'learning_command_receipts');

      await expectLater(
        coordinator.submit(_command()),
        throwsA(isA<LearningCorruptException>()),
      );
      expect(await _count(db, 'learning_attempts'), attemptsBefore);
      expect(await _count(db, 'learning_command_receipts'), receiptsBefore);
    });

    test('independent_connections_commit_one_divergent_command', () async {
      final leftAdapter = harness.adapter;
      final leftCoordinator = harness.coordinator(adapter: leftAdapter);
      final leftGate = _PersistGate();
      leftAdapter.persistGate = leftGate;
      final leftSubmit = leftCoordinator.submit(_command());
      await leftGate.entered.future;

      final rightAdapter = harness.newAdapter();
      final rightObserved = Completer<void>();
      rightAdapter.onAuthGenerationRead = rightObserved.complete;
      final rightCoordinator = harness.coordinator(adapter: rightAdapter);
      final rightSubmit = rightCoordinator.submit(
        _command(token: _rightToken, eventId: 'right-event'),
      );
      await rightObserved.future;
      leftGate.release.complete();

      final committed = await leftSubmit;
      expect(committed.duplicate, isFalse);
      await expectLater(rightSubmit, throwsA(isA<LearningConflictException>()));
      final leftDb = await harness.handleFor(leftCoordinator).open();
      final rightDb = await harness.handleFor(rightCoordinator).open();
      expect(identical(leftDb, rightDb), isFalse);
      expect(await _count(leftDb, 'learning_command_receipts'), 1);
      expect(await _count(rightDb, 'learning_attempts'), 1);
    });

    test('load_reads_one_consistent_normalized_snapshot', () async {
      harness.useWal = true;
      final coordinator = harness.coordinator();
      await coordinator.load();
      final leftDb = await harness.handleFor(coordinator).open();
      expect(
        (await leftDb.customSelect('PRAGMA journal_mode').getSingle())
            .read<String>('journal_mode'),
        'wal',
      );

      final readGate = _LoadGate();
      harness.adapter.loadGate = readGate;
      final loading = coordinator.load();
      await readGate.entered.future;

      final writerAdapter = harness.newAdapter();
      final writerAttempted = Completer<void>();
      writerAdapter.onAuthGenerationRead = writerAttempted.complete;
      final writer = harness.coordinator(adapter: writerAdapter);
      final committing = writer.submit(_command());
      await writerAttempted.future;
      final committed = await committing;
      expect(committed.state.revision, 1);
      readGate.release.complete();

      final loaded = await loading;
      expect(loaded.revision, 0);
      expect(loaded.commitOrdinal, 0);
      expect(loaded.cursors, isEmpty);
      expect((await writer.load()).cursors['activity-A']?.sequence, 1);
    });

    test('sql_trigger_failure_rolls_back_all_rows', () async {
      final coordinator = harness.coordinator();
      await coordinator.load();
      final db = await harness.handleFor(coordinator).open();
      await db.customStatement('''
        CREATE TRIGGER task4_reject_attempt BEFORE INSERT ON learning_attempts
        BEGIN SELECT RAISE(ABORT, 'task4 injected failure'); END
      ''');

      await expectLater(
        coordinator.submit(_command()),
        throwsA(isA<LearningSaveException>()),
      );
      expect(await _count(db, 'learning_content_bindings'), 0);
      expect(await _count(db, 'learning_runs'), 0);
      expect(await _count(db, 'learning_attempts'), 0);
      expect(await _count(db, 'learning_command_receipts'), 0);
      expect(await _count(db, 'supported_sync_outbox'), 0);
      expect(await _scopeRevision(db), 0);
    });

    test(
      'oversize_checkpoint_fails_atomically_without_fallback_or_truncate',
      () async {
        final coordinator = harness.coordinator();
        await coordinator.load();
        harness.adapter.checkpointOverride = '{"data":"${'x' * 1048576}"}';
        final db = await harness.handleFor(coordinator).open();

        await expectLater(
          coordinator.submit(_command()),
          throwsA(isA<LearningSaveException>()),
        );
        expect(await _count(db, 'learning_content_bindings'), 0);
        expect(await _count(db, 'learning_runs'), 0);
        expect(await _count(db, 'learning_attempts'), 0);
        expect(await _count(db, 'learning_command_receipts'), 0);
        expect(await _count(db, 'supported_sync_outbox'), 0);
        expect(await _scopeRevision(db), 0);
      },
    );

    test(
      'outbox_ack_revision_conflicts_stale_snapshot_then_reloaded_command_succeeds',
      () async {
        final coordinator = harness.coordinator();
        final first = await coordinator.submit(_command());
        final event = (await coordinator.readSupportedCourseEvents()).single;
        await coordinator.acknowledgeSupportedCourseEvents(<String>{event.id});

        await expectLater(
          coordinator.submit(
            _command(
              token: _nextToken,
              scopeRevision: first.state.revision,
              cursor: first.state.cursors['activity-A']!,
              start: false,
              eventId: 'stale-event',
            ),
          ),
          throwsA(isA<LearningConflictException>()),
        );
        final fresh = await coordinator.load();
        expect(fresh.revision, first.state.revision + 1);
        expect(fresh.commitOrdinal, first.state.commitOrdinal);
        final next = await coordinator.submit(
          _command(
            token: _nextToken,
            scopeRevision: fresh.revision,
            cursor: fresh.cursors['activity-A']!,
            start: false,
            eventId: 'fresh-event',
          ),
        );
        expect(next.duplicate, isFalse);
        expect(next.state.revision, fresh.revision + 1);
        expect(next.state.commitOrdinal, fresh.commitOrdinal + 1);
      },
    );

    test('unknown_ack_is_a_write_free_no_op', () async {
      final coordinator = harness.coordinator();
      await coordinator.load();
      final db = await harness.handleFor(coordinator).open();
      final beforeChanges = await _totalChanges(db);
      final beforeRevision = await _scopeRevision(db);
      final beforeOrdinal = await _scopeCommitOrdinal(db);

      await coordinator.acknowledgeSupportedCourseEvents(<String>{
        'not-pending-event',
      });

      expect(await _totalChanges(db), beforeChanges);
      expect(await _scopeRevision(db), beforeRevision);
      expect(await _scopeCommitOrdinal(db), beforeOrdinal);
    });

    test('outbox_fifo_uses_enqueue_ordinal_and_index_not_event_id', () async {
      final coordinator = harness.coordinator();
      await coordinator.submit(_command(eventId: 'z-first'));
      final db = await harness.handleFor(coordinator).open();
      await insertRow(db, 'supported_sync_outbox', <String, Object?>{
        'scope_id': 1,
        'event_id': 'a-index-1',
        'enqueue_commit_ordinal': 1,
        'enqueue_event_index': 1,
        'user_id': 'account-42',
        'course_id': 'en-fr',
        'kind': 'lesson',
        'sound': null,
        'skill': null,
        'correct': null,
        'activity': null,
        'lesson_id': 'lesson-a',
        'game': null,
        'score': null,
      });
      final secondCursor = (await coordinator.load()).cursors['activity-A']!;
      await coordinator.submit(
        _command(
          token: _nextToken,
          scopeRevision: 1,
          cursor: secondCursor,
          start: false,
          eventId: 'a-second',
        ),
      );
      final thirdCursor = (await coordinator.load()).cursors['activity-A']!;
      await coordinator.submit(
        _command(
          token: _thirdToken,
          scopeRevision: 2,
          cursor: thirdCursor,
          start: false,
          eventId: 'm-third',
        ),
      );
      final events = await coordinator.readSupportedCourseEvents();
      expect(events.map((event) => event.id), <String>[
        'z-first',
        'a-index-1',
        'a-second',
        'm-third',
      ]);
      expect((await coordinator.load()).pendingIds, <String>[
        'z-first',
        'a-index-1',
        'a-second',
        'm-third',
      ]);

      await coordinator.acknowledgeSupportedCourseEvents(<String>{'a-second'});
      final remaining = await coordinator.readSupportedCourseEvents();
      expect(remaining.map((event) => event.id), <String>[
        'z-first',
        'a-index-1',
        'm-third',
      ]);
      expect((await coordinator.load()).pendingIds, <String>[
        'z-first',
        'a-index-1',
        'm-third',
      ]);
      final orderRows = await db
          .customSelect(
            'SELECT event_id, enqueue_commit_ordinal, enqueue_event_index '
            'FROM supported_sync_outbox WHERE scope_id = ? '
            'ORDER BY enqueue_commit_ordinal ASC, enqueue_event_index ASC',
            variables: <Variable<Object>>[const Variable<int>(1)],
          )
          .get();
      expect(
        orderRows.map((row) => row.read<int>('enqueue_commit_ordinal')),
        <int>[1, 1, 3],
      );
    });

    test(
      'ensure_scope_preserves_exact_owner_course_and_family_identity',
      () async {
        final exactOwner = LearningOwner.account(' account:42 ');
        final exactScope = LearningStorageScope(
          owner: exactOwner,
          courseId: 'en-fr:course ',
          family: LearningFamily.course,
        );
        harness.changeAuth(exactOwner, generation: 7);
        final coordinator = harness.coordinator(scope: exactScope);
        final first = await coordinator.load();
        final second = await coordinator.load();
        expect(first.revision, 0);
        expect(second.revision, 0);
        final db = await harness.handleFor(coordinator).open();
        final scopeRow = await db
            .customSelect(
              'SELECT owner_kind, owner_id, course_id, family, revision, commit_ordinal '
              'FROM learning_scopes',
            )
            .getSingle();
        expect(scopeRow.read<String>('owner_kind'), 'account');
        expect(scopeRow.read<String>('owner_id'), ' account:42 ');
        expect(scopeRow.read<String>('course_id'), 'en-fr:course ');
        expect(scopeRow.read<String>('family'), 'course');
        expect(scopeRow.read<int>('revision'), 0);
        expect(scopeRow.read<int>('commit_ordinal'), 0);
      },
    );

    test(
      'auth_change_while_opening_does_not_create_or_return_old_scope',
      () async {
        final opened = Completer<LearningDatabase>();
        final opening = Completer<void>();
        final handle = LearningDatabaseHandle(
          open: () {
            opening.complete();
            return opened.future;
          },
        );
        harness.handles.add(handle);
        final coordinator = harness.coordinator(handle: handle);
        final loading = coordinator.load();
        await opening.future;
        harness.changeAuth(LearningOwner.account('new-account'), generation: 8);
        opened.complete(await openFileLearningTestDatabase(file));

        await expectLater(
          loading,
          throwsA(isA<LearningOwnerChangedException>()),
        );
        final inspection = await openFileLearningTestDatabase(file);
        expect(await _count(inspection, 'learning_scopes'), 0);
        await inspection.close();
      },
    );

    test('auth_change_during_scope_creation_rolls_back_scope_insert', () async {
      final gate = _ScopeCreationGate();
      final handle = LearningDatabaseHandle(
        open: () async => _ScopeCreationBarrierDatabase(
          DatabaseConnection(NativeDatabase(file)),
          gate,
        ),
      );
      harness.handles.add(handle);
      final coordinator = harness.coordinator(handle: handle);
      final loading = coordinator.load();
      await gate.entered.future;
      harness.changeAuth(LearningOwner.account('new-account'), generation: 8);
      gate.release.complete();

      await expectLater(loading, throwsA(isA<LearningOwnerChangedException>()));
      final inspection = await openFileLearningTestDatabase(file);
      expect(await _count(inspection, 'learning_scopes'), 0);
      await inspection.close();
    });

    test(
      'auth_change_during_command_persistence_cannot_return_old_owner_success',
      () async {
        final coordinator = harness.coordinator();
        await coordinator.load();
        final gate = _PersistGate();
        harness.adapter.persistGate = gate;
        final submitting = coordinator.submit(_command());
        await gate.entered.future;
        harness.changeAuth(LearningOwner.account('new-account'), generation: 8);
        gate.release.complete();

        await expectLater(
          submitting,
          throwsA(isA<LearningOwnerChangedException>()),
        );
        final db = await harness.handleFor(coordinator).open();
        expect(await _count(db, 'learning_attempts'), 0);
        expect(await _count(db, 'learning_command_receipts'), 0);
        expect(await _count(db, 'supported_sync_outbox'), 0);
        expect(await _scopeRevision(db), 0);
        expect(harness.notifications, 0);
      },
    );

    test(
      'auth_change_after_sql_commit_before_transaction_returns_does_not_notify',
      () async {
        final commitBarrier = _SqlCommitBarrier();
        final handle = LearningDatabaseHandle(
          open: () async => LearningDatabase(
            DatabaseConnection(
              NativeDatabase(file).interceptWith(commitBarrier),
            ),
          ),
        );
        harness.handles.add(handle);
        final coordinator = harness.coordinator(handle: handle);
        await coordinator.load();

        final persistGate = _PersistGate();
        harness.adapter.persistGate = persistGate;
        final submitting = coordinator.submit(_command());
        await persistGate.entered.future;
        commitBarrier.arm();
        persistGate.release.complete();

        // QueryInterceptor releases the real SQLite COMMIT before pausing the
        // transaction future, so this auth change is strictly post-commit.
        await commitBarrier.committed.future;
        harness.changeAuth(LearningOwner.account('new-account'), generation: 8);
        commitBarrier.release.complete();

        await expectLater(
          submitting,
          throwsA(isA<LearningOwnerChangedException>()),
        );
        expect(harness.notifications, 0);

        final db = await handle.open();
        final scopeRow = await db
            .customSelect(
              'SELECT owner_kind, owner_id, course_id, family, revision, '
              'commit_ordinal FROM learning_scopes',
            )
            .getSingle();
        expect(scopeRow.read<String>('owner_kind'), 'account');
        expect(scopeRow.read<String>('owner_id'), 'account-42');
        expect(scopeRow.read<String>('course_id'), 'en-fr');
        expect(scopeRow.read<String>('family'), 'course');
        expect(scopeRow.read<int>('revision'), 1);
        expect(scopeRow.read<int>('commit_ordinal'), 1);
        expect(await _count(db, 'learning_attempts'), 1);
        expect(await _count(db, 'learning_command_receipts'), 1);
        expect(await _count(db, 'supported_sync_outbox'), 1);
      },
    );

    test('auth_change_inside_observer_still_prevents_submit_success', () async {
      final coordinator = harness.coordinator(
        onCommitted: () => harness.changeAuth(
          LearningOwner.account('new-account'),
          generation: 8,
        ),
      );

      await expectLater(
        coordinator.submit(_command()),
        throwsA(isA<LearningOwnerChangedException>()),
      );
      expect(harness.notifications, 1);
      final db = await harness.handleFor(coordinator).open();
      expect(await _count(db, 'learning_attempts'), 1);
      expect(await _scopeRevision(db), 1);
    });

    test('observer_error_does_not_undo_or_hide_a_stable_auth_commit', () async {
      final coordinator = harness.coordinator(
        onCommitted: () => throw StateError('observer failure'),
      );

      final result = await coordinator.submit(_command());

      expect(result.duplicate, isFalse);
      expect(harness.notifications, 1);
      final db = await harness.handleFor(coordinator).open();
      expect(await _count(db, 'learning_attempts'), 1);
      expect(await _scopeRevision(db), 1);
    });

    test(
      'supported_course_events_decode_only_existing_payload_variants',
      () async {
        final coordinator = harness.coordinator();
        await coordinator.load();
        final db = await harness.handleFor(coordinator).open();
        await insertRow(db, 'supported_sync_outbox', <String, Object?>{
          'scope_id': 1,
          'event_id': 'lesson-event',
          'enqueue_commit_ordinal': 1,
          'enqueue_event_index': 0,
          'user_id': 'account-42',
          'course_id': 'en-fr',
          'kind': 'lesson',
          'sound': null,
          'skill': null,
          'correct': null,
          'activity': null,
          'lesson_id': 'lesson-a',
          'game': null,
          'score': null,
        });
        await insertRow(db, 'supported_sync_outbox', <String, Object?>{
          'scope_id': 1,
          'event_id': 'score-event',
          'enqueue_commit_ordinal': 2,
          'enqueue_event_index': 0,
          'user_id': 'account-42',
          'course_id': 'en-fr',
          'kind': 'score',
          'sound': null,
          'skill': null,
          'correct': null,
          'activity': null,
          'lesson_id': null,
          'game': 'sound-game',
          'score': 8,
        });

        final events = await coordinator.readSupportedCourseEvents();
        expect(events.map((event) => event.id), <String>[
          'lesson-event',
          'score-event',
        ]);
        expect(events[0].payload, isA<CloudLesson>());
        expect((events[0].payload as CloudLesson).lessonId, 'lesson-a');
        expect(events[1].payload, isA<CloudScore>());
        expect((events[1].payload as CloudScore).score, 8);
      },
    );

    test('course_event_apis_reject_non_course_scope', () async {
      final comparisonScope = LearningStorageScope(
        owner: harness.owner,
        courseId: 'en-fr',
        family: LearningFamily.comparison,
      );
      final coordinator = harness.coordinator(scope: comparisonScope);

      await expectLater(
        coordinator.readSupportedCourseEvents(),
        throwsA(isA<LearningInvalidCommandException>()),
      );
      await expectLater(
        coordinator.acknowledgeSupportedCourseEvents(<String>{'unknown'}),
        throwsA(isA<LearningInvalidCommandException>()),
      );
    });
  });
}

const String _sharedToken = 'AAAAAAAAAAAAAAAAAAAAAA';
const String _rightToken = 'BBBBBBBBBBBBBBBBBBBBBB';
const String _nextToken = 'CCCCCCCCCCCCCCCCCCCCCC';
const String _thirdToken = 'DDDDDDDDDDDDDDDDDDDDDD';
const String _fourthToken = 'EEEEEEEEEEEEEEEEEEEEEE';

_Command _command({
  String activityId = 'activity-A',
  String token = _sharedToken,
  int scopeRevision = 0,
  LearningCursorPosition cursor = const LearningCursorPosition(
    generation: 0,
    sequence: 0,
    revision: 0,
  ),
  int authGeneration = 7,
  bool start = true,
  String value = 'answer',
  String eventId = 'answer-event',
}) => _Command(
  activityId: activityId,
  token: token,
  scopeRevision: scopeRevision,
  cursor: cursor,
  authGeneration: authGeneration,
  start: start,
  value: value,
  eventId: eventId,
);

class _Command {
  const _Command({
    required this.activityId,
    required this.token,
    required this.scopeRevision,
    required this.cursor,
    required this.authGeneration,
    required this.start,
    required this.value,
    required this.eventId,
  });

  final String activityId;
  final String token;
  final int scopeRevision;
  final LearningCursorPosition cursor;
  final int authGeneration;
  final bool start;
  final String value;
  final String eventId;

  String get canonicalPayload => jsonEncode(<String, Object?>{
    'activityId': activityId,
    'expectedScopeRevision': scopeRevision,
    'answer': value,
  });
}

class _TestState {
  const _TestState({
    required this.revision,
    required this.commitOrdinal,
    required this.cursors,
    required this.pendingIds,
  });

  final int revision;
  final int commitOrdinal;
  final Map<String, LearningCursorPosition> cursors;
  final List<String> pendingIds;
}

class _TestResult {
  const _TestResult({required this.state, required this.duplicate});

  final _TestState state;
  final bool duplicate;
}

class _PersistGate {
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();
}

class _LoadGate {
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();
}

class _ScopeCreationGate {
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();
}

class _SqlCommitBarrier extends QueryInterceptor {
  final Completer<void> committed = Completer<void>();
  final Completer<void> release = Completer<void>();
  bool _armed = false;

  void arm() => _armed = true;

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await inner.send();
    if (!_armed) return;
    _armed = false;
    committed.complete();
    await release.future;
  }
}

class _ScopeCreationBarrierDatabase extends LearningDatabase {
  _ScopeCreationBarrierDatabase(super.connection, this.gate);

  final _ScopeCreationGate gate;

  @override
  Future<int> ensureScope(LearningStorageScope scope) async {
    gate.entered.complete();
    await gate.release.future;
    return super.ensureScope(scope);
  }
}

class _Harness {
  _Harness(this.file)
    : owner = LearningOwner.account('account-42'),
      scope = LearningStorageScope(
        owner: LearningOwner.account('account-42'),
        courseId: 'en-fr',
        family: LearningFamily.course,
      ) {
    auth = LearningAuthScope(owner: owner, generation: 7, ready: true);
    backend = owner;
    adapter = newAdapter();
  }

  final File file;
  final LearningOwner owner;
  final LearningStorageScope scope;
  final List<LearningDatabaseHandle> handles = <LearningDatabaseHandle>[];
  late LearningAuthScope auth;
  late LearningOwner backend;
  late _TestAdapter adapter;
  int notifications = 0;
  bool useWal = false;

  _TestAdapter newAdapter({LearningStorageScope? scope}) =>
      _TestAdapter(scope: scope ?? this.scope);

  LearningDatabaseHandle _newHandle() {
    final enableWal = useWal;
    useWal = false;
    final handle = LearningDatabaseHandle(
      open: () => enableWal
          ? openWalFileLearningTestDatabase(file)
          : openFileLearningTestDatabase(file),
    );
    handles.add(handle);
    return handle;
  }

  SqliteLearningCommandCoordinator<_TestState, _Command, _TestResult>
  coordinator({
    _TestAdapter? adapter,
    LearningDatabaseHandle? handle,
    LearningStorageScope? scope,
    void Function()? onCommitted,
  }) {
    final selectedAdapter =
        adapter ?? (scope == null ? this.adapter : newAdapter(scope: scope));
    final selectedHandle = handle ?? _newHandle();
    if (handle != null && !handles.contains(handle)) handles.add(handle);
    return SqliteLearningCommandCoordinator<_TestState, _Command, _TestResult>(
      database: selectedHandle,
      adapter: selectedAdapter,
      authGeneration: 7,
      currentAuth: () => auth,
      backendOwner: () => backend,
      clock: () => DateTime.utc(2026, 10, 19),
      onCommitted: () {
        notifications++;
        onCommitted?.call();
      },
    );
  }

  LearningDatabaseHandle handleFor(
    SqliteLearningCommandCoordinator<_TestState, _Command, _TestResult>
    coordinator,
  ) => handles.firstWhere(
    (handle) => identical(handle, _handleFor(coordinator)),
  );

  LearningDatabaseHandle _handleFor(
    SqliteLearningCommandCoordinator<_TestState, _Command, _TestResult>
    coordinator,
  ) => coordinator.database;

  void changeAuth(LearningOwner nextOwner, {required int generation}) {
    auth = LearningAuthScope(
      owner: nextOwner,
      generation: generation,
      ready: true,
    );
    backend = nextOwner;
  }

  Future<void> close() async {
    for (final handle in handles) {
      await handle.close();
    }
  }
}

class _TestAdapter
    implements SqliteLearningProfileAdapter<_TestState, _Command, _TestResult> {
  _TestAdapter({required this.scope});

  @override
  LearningStorageScope scope;
  _PersistGate? persistGate;
  _LoadGate? loadGate;
  String? checkpointOverride;
  void Function()? onAuthGenerationRead;
  final List<_TestState> duplicateStates = <_TestState>[];

  @override
  String commandActivityId(_Command command) => command.activityId;

  @override
  String commandToken(_Command command) => command.token;

  @override
  String commandCanonicalPayload(_Command command) => command.canonicalPayload;

  @override
  int commandAuthGeneration(_Command command) {
    onAuthGenerationRead?.call();
    return command.authGeneration;
  }

  @override
  int commandExpectedScopeRevision(_Command command) => command.scopeRevision;

  @override
  LearningCursorPosition commandExpectedCursor(_Command command) =>
      command.cursor;

  @override
  bool isStart(_Command command) => command.start;

  @override
  Future<_TestState> loadState(
    LearningDatabase db,
    int scopeId, {
    required int revision,
    required int commitOrdinal,
  }) async {
    final gate = loadGate;
    if (gate != null) {
      loadGate = null;
      gate.entered.complete();
      await gate.release.future;
    }
    final runRows = await db
        .customSelect(
          'SELECT activity_id, run_generation, sequence, cursor_revision '
          'FROM learning_runs WHERE scope_id = ? '
          'ORDER BY activity_id ASC',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    final cursors = <String, LearningCursorPosition>{
      for (final row in runRows)
        row.read<String>('activity_id'): LearningCursorPosition(
          generation: row.read<int>('run_generation'),
          sequence: row.read<int>('sequence'),
          revision: row.read<int>('cursor_revision'),
        ),
    };
    final pendingRows = await db
        .customSelect(
          'SELECT event_id FROM supported_sync_outbox WHERE scope_id = ? '
          'ORDER BY enqueue_commit_ordinal ASC, enqueue_event_index ASC',
          variables: <Variable<Object>>[Variable<int>(scopeId)],
        )
        .get();
    return _TestState(
      revision: revision,
      commitOrdinal: commitOrdinal,
      cursors: cursors,
      pendingIds: pendingRows
          .map((row) => row.read<String>('event_id'))
          .toList(),
    );
  }

  @override
  Future<LearningStoredReceipt?> findReceipt(
    LearningDatabase db,
    int scopeId,
    String token,
  ) async {
    final historyRows = await db
        .customSelect(
          'SELECT activity_id, token, canonical_payload, before_generation, '
          'before_sequence, before_cursor_revision, after_generation, after_sequence, '
          'after_cursor_revision, commit_ordinal, result_activity_id '
          'FROM learning_command_receipts WHERE scope_id = ? AND token = ?',
          variables: <Variable<Object>>[
            Variable<int>(scopeId),
            Variable<String>(token),
          ],
        )
        .get();
    final latestRows = await db
        .customSelect(
          'SELECT activity_id, latest_receipt_token, latest_receipt_payload, '
          'latest_receipt_before_generation, latest_receipt_before_sequence, '
          'latest_receipt_before_cursor_revision, run_generation, sequence, '
          'cursor_revision, latest_receipt_commit_ordinal '
          'FROM learning_runs WHERE scope_id = ? AND latest_receipt_token = ?',
          variables: <Variable<Object>>[
            Variable<int>(scopeId),
            Variable<String>(token),
          ],
        )
        .get();
    if (historyRows.length > 1 || latestRows.length > 1) {
      throw const LearningCorruptException();
    }
    final history = historyRows.isEmpty
        ? null
        : _historyReceipt(historyRows.single);
    final latest = latestRows.isEmpty
        ? null
        : _latestReceipt(latestRows.single);
    if (history != null && latest != null && !_sameReceipt(history, latest)) {
      throw const LearningCorruptException();
    }
    return history ?? latest;
  }

  LearningStoredReceipt _historyReceipt(QueryRow row) => LearningStoredReceipt(
    activityId: row.read<String>('activity_id'),
    token: row.read<String>('token'),
    canonicalPayload: row.read<String>('canonical_payload'),
    before: LearningCursorPosition(
      generation: row.read<int>('before_generation'),
      sequence: row.read<int>('before_sequence'),
      revision: row.read<int>('before_cursor_revision'),
    ),
    after: LearningCursorPosition(
      generation: row.read<int>('after_generation'),
      sequence: row.read<int>('after_sequence'),
      revision: row.read<int>('after_cursor_revision'),
    ),
    commitOrdinal: row.read<int>('commit_ordinal'),
    resultActivityId: row.read<String>('result_activity_id'),
  );

  LearningStoredReceipt _latestReceipt(QueryRow row) {
    final activityId = row.read<String>('activity_id');
    return LearningStoredReceipt(
      activityId: activityId,
      token: row.read<String>('latest_receipt_token'),
      canonicalPayload: row.read<String>('latest_receipt_payload'),
      before: LearningCursorPosition(
        generation: row.read<int>('latest_receipt_before_generation'),
        sequence: row.read<int>('latest_receipt_before_sequence'),
        revision: row.read<int>('latest_receipt_before_cursor_revision'),
      ),
      after: LearningCursorPosition(
        generation: row.read<int>('run_generation'),
        sequence: row.read<int>('sequence'),
        revision: row.read<int>('cursor_revision'),
      ),
      commitOrdinal: row.read<int>('latest_receipt_commit_ordinal'),
      resultActivityId: activityId,
    );
  }

  bool _sameReceipt(LearningStoredReceipt left, LearningStoredReceipt right) =>
      left.activityId == right.activityId &&
      left.token == right.token &&
      left.canonicalPayload == right.canonicalPayload &&
      left.before == right.before &&
      left.after == right.after &&
      left.commitOrdinal == right.commitOrdinal &&
      left.resultActivityId == right.resultActivityId;

  @override
  LearningCursorPosition? cursorFor(_TestState state, String activityId) =>
      state.cursors[activityId];

  @override
  LearningSqlTransition<_TestState, _TestResult> evaluate({
    required _TestState before,
    required _Command command,
    required int nextRevision,
    required int nextCommitOrdinal,
    required DateTime committedAt,
  }) {
    final current = before.cursors[command.activityId];
    final after = current == null
        ? const LearningCursorPosition(generation: 1, sequence: 1, revision: 0)
        : LearningCursorPosition(
            generation: current.generation,
            sequence: current.sequence + 1,
            revision: current.revision,
          );
    final cursors = <String, LearningCursorPosition>{
      ...before.cursors,
      command.activityId: after,
    };
    final state = _TestState(
      revision: nextRevision,
      commitOrdinal: nextCommitOrdinal,
      cursors: cursors,
      pendingIds: <String>[...before.pendingIds, command.eventId],
    );
    return LearningSqlTransition<_TestState, _TestResult>(
      state: state,
      result: _TestResult(state: state, duplicate: false),
    );
  }

  @override
  Future<void> persist(
    LearningDatabase db,
    int scopeId,
    _TestState before,
    _Command command,
    _TestState after,
  ) async {
    final checkpointJson = checkpointOverride ?? '{}';
    checkpointOverride = null;
    final gate = persistGate;
    if (gate != null) {
      persistGate = null;
      gate.entered.complete();
      await gate.release.future;
    }
    final bindingRows = await db
        .customSelect(
          'SELECT id FROM learning_content_bindings '
          'WHERE scope_id = ? AND activity_id = ?',
          variables: <Variable<Object>>[
            Variable<int>(scopeId),
            Variable<String>(command.activityId),
          ],
        )
        .get();
    var bindingId = 0;
    if (bindingRows.isEmpty) {
      await db.customStatement(
        'INSERT INTO learning_content_bindings '
        '(scope_id, activity_id, content_revision, catalogue_fingerprint) '
        'VALUES (?, ?, 1, ?)',
        <Object?>[scopeId, command.activityId, 'test-catalogue'],
      );
      final insertedBinding = await db
          .customSelect(
            'SELECT id FROM learning_content_bindings '
            'WHERE scope_id = ? AND activity_id = ?',
            variables: <Variable<Object>>[
              Variable<int>(scopeId),
              Variable<String>(command.activityId),
            ],
          )
          .getSingle();
      bindingId = insertedBinding.read<int>('id');
    } else {
      bindingId = bindingRows.single.read<int>('id');
    }

    final beforeCursor = before.cursors[command.activityId] ?? command.cursor;
    final afterCursor = after.cursors[command.activityId]!;
    final existingRunRows = await db
        .customSelect(
          'SELECT activity_id FROM learning_runs '
          'WHERE scope_id = ? AND activity_id = ?',
          variables: <Variable<Object>>[
            Variable<int>(scopeId),
            Variable<String>(command.activityId),
          ],
        )
        .get();
    if (existingRunRows.isEmpty) {
      await db.customStatement(
        'INSERT INTO learning_runs '
        '(scope_id, activity_id, activity_kind, run_generation, sequence, '
        'cursor_revision, content_binding_id, run_mode, finished, session_id, '
        'policy_revision, threshold_percent, run_start_round, checkpoint_json, '
        'latest_receipt_token, latest_receipt_payload, '
        'latest_receipt_before_generation, latest_receipt_before_sequence, '
        'latest_receipt_before_cursor_revision, latest_receipt_commit_ordinal) '
        'VALUES (?, ?, \'discovery\', ?, ?, ?, ?, NULL, 0, NULL, NULL, NULL, '
        'NULL, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          scopeId,
          command.activityId,
          afterCursor.generation,
          afterCursor.sequence,
          afterCursor.revision,
          bindingId,
          checkpointJson,
          command.token,
          command.canonicalPayload,
          beforeCursor.generation,
          beforeCursor.sequence,
          beforeCursor.revision,
          after.commitOrdinal,
        ],
      );
    } else {
      await db.customStatement(
        'UPDATE learning_runs SET run_generation = ?, sequence = ?, '
        'cursor_revision = ?, checkpoint_json = ?, latest_receipt_token = ?, '
        'latest_receipt_payload = ?, latest_receipt_before_generation = ?, '
        'latest_receipt_before_sequence = ?, '
        'latest_receipt_before_cursor_revision = ?, '
        'latest_receipt_commit_ordinal = ? '
        'WHERE scope_id = ? AND activity_id = ?',
        <Object?>[
          afterCursor.generation,
          afterCursor.sequence,
          afterCursor.revision,
          checkpointJson,
          command.token,
          command.canonicalPayload,
          beforeCursor.generation,
          beforeCursor.sequence,
          beforeCursor.revision,
          after.commitOrdinal,
          scopeId,
          command.activityId,
        ],
      );
    }

    final attemptId = 'attempt-${command.token}';
    final attempt =
        courseAttemptRow(
            scopeId: scopeId,
            attemptId: attemptId,
            activityId: command.activityId,
          )
          ..['run_generation'] = afterCursor.generation
          ..['command_sequence'] = afterCursor.sequence
          ..['content_revision'] = 1
          ..['commit_ordinal'] = after.commitOrdinal
          ..['answered_at_us'] = after.commitOrdinal * 100
          ..['committed_at_us'] = after.commitOrdinal * 100 + 1;
    await insertRow(db, 'learning_attempts', attempt);

    await insertRow(db, 'learning_command_receipts', <String, Object?>{
      'scope_id': scopeId,
      'activity_id': command.activityId,
      'token': command.token,
      'canonical_payload': command.canonicalPayload,
      'before_generation': beforeCursor.generation,
      'before_sequence': beforeCursor.sequence,
      'before_cursor_revision': beforeCursor.revision,
      'after_generation': afterCursor.generation,
      'after_sequence': afterCursor.sequence,
      'after_cursor_revision': afterCursor.revision,
      'commit_ordinal': after.commitOrdinal,
      'result_activity_id': command.activityId,
      'result_generation': afterCursor.generation,
      'result_sequence': afterCursor.sequence,
      'result_cursor_revision': afterCursor.revision,
    });

    if (scope.owner.userId != null) {
      await insertRow(db, 'supported_sync_outbox', <String, Object?>{
        'scope_id': scopeId,
        'event_id': command.eventId,
        'enqueue_commit_ordinal': after.commitOrdinal,
        'enqueue_event_index': 0,
        'user_id': scope.owner.userId,
        'course_id': scope.courseId,
        'kind': 'answer',
        'sound': 'ɛ',
        'skill': 'listening',
        'correct': 1,
        'activity': command.activityId,
        'lesson_id': null,
        'game': null,
        'score': null,
      });
    }
  }

  @override
  _TestResult duplicateResult({
    required _TestState current,
    required _Command command,
  }) {
    duplicateStates.add(current);
    return _TestResult(state: current, duplicate: true);
  }
}

Future<int> _count(LearningDatabase db, String table) async =>
    (await db.customSelect('SELECT COUNT(*) AS count FROM $table').getSingle())
        .read<int>('count');

Future<int> _scopeRevision(LearningDatabase db) async =>
    (await db.customSelect('SELECT revision FROM learning_scopes').getSingle())
        .read<int>('revision');

Future<int> _scopeCommitOrdinal(LearningDatabase db) async =>
    (await db
            .customSelect('SELECT commit_ordinal FROM learning_scopes')
            .getSingle())
        .read<int>('commit_ordinal');

Future<int> _totalChanges(LearningDatabase db) async =>
    (await db.customSelect('SELECT total_changes() AS count').getSingle())
        .read<int>('count');
