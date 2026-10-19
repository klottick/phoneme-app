import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show DatabaseConnection, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_command_codec.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_sync.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_adapter.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/course_learning_state_validator.dart';
import 'package:linguist/src/core/course/storage/course_learning_checkpoint_codec.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/learning_sql_transaction.dart';
import 'package:linguist/src/core/course/storage/learning_storage_scope.dart';
import 'package:linguist/src/features/arcade/sound_match_engine.dart';
import 'package:linguist/src/features/arcade/word_match_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('inactive course SQLite adapter', () {
    late Directory directory;
    late _Fixture fixture;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('course-sqlite-');
      fixture = _Fixture(File('${directory.path}/learning.sqlite'));
    });

    tearDown(() async {
      await fixture.close();
      await directory.delete(recursive: true);
    });

    test(
      'course_answer_checkpoint_aggregates_and_outbox_reopen_together',
      () async {
        final repository = fixture.repository();
        final initial = await repository.load();
        const activityId = 'lesson:en-fr-vowels';
        final definition = fixture.registry.require(activityId);

        final started = await repository.submit(
          repository.prepare(
            state: initial,
            activityId: activityId,
            action: StartLearningRun(options: RunOptions()),
          ),
        );
        final item = definition.items.first;
        final selected = item.choices.firstWhere(
          (choice) => choice != item.expectedChoice,
        );
        final answerCommand = repository.prepare(
          state: started.state,
          activityId: activityId,
          action: ChooseSound(
            selectedSound: selected,
            audioSource: authoredAudioSource(item)!,
          ),
        );
        expect(answerCommand.expectedScopeRevision, started.state.revision);
        expect(answerCommand.expectedScopeRevision, greaterThan(0));

        final committed = await repository.submit(answerCommand);
        final beforeReplay = await _outboxIdentityRows(
          fixture.handle,
          fixture.storageScope,
        );
        expect(beforeReplay, hasLength(1));
        expect(
          beforeReplay.single.enqueueCommitOrdinal,
          committed.state.commitOrdinal,
        );
        expect(beforeReplay.single.enqueueEventIndex, 0);

        final sqlReceipt = await _receiptPayload(
          fixture.handle,
          fixture.storageScope,
          answerCommand.token,
        );
        expect(
          jsonDecode(sqlReceipt)['expectedScopeRevision'],
          answerCommand.expectedScopeRevision,
        );
        expect(
          committed
              .state
              .activities[activityId]!
              .latestReceipt
              .canonicalCommand,
          CourseLearningCommandCodec.legacyCanonicalCommand(answerCommand),
        );
        final checkpoint = await _checkpointJson(
          fixture.handle,
          fixture.storageScope,
          activityId,
        );
        expect(
          (jsonDecode(checkpoint) as Map<String, dynamic>).containsKey(
            'expectedScopeRevision',
          ),
          isFalse,
        );

        final replay = await repository.submit(answerCommand);
        expect(replay.duplicate, isTrue);
        expect(
          await _outboxIdentityRows(fixture.handle, fixture.storageScope),
          beforeReplay,
        );

        await fixture.handle.close();
        await fixture.handle.reopen();
        final reopened = await repository.load();
        final slot = reopened.activities[activityId]!;
        expect(slot.cursor.generation, 1);
        expect(slot.cursor.sequence, 2);
        expect(slot.cursor.revision, 1);
        expect(
          (slot.snapshot as LegacyLessonCheckpoint).selectedSound,
          selected,
        );
        expect(await _answerValueRows(fixture.handle, fixture.storageScope), {
          'selected_sound': [selected],
          'expected_sound': [item.expectedChoice],
          'choice': item.choices,
          'target_sound': item.targetSounds,
        });
        final summary = reopened.summaries.entries.singleWhere(
          (entry) => entry.key.sound == item.targetSounds.first,
        );
        expect(summary.value.total, 1);
        expect(summary.value.correct, 0);
        expect(reopened.mistakes, hasLength(1));
        expect(reopened.mistakes.keys.single.itemId, item.id);
        expect(reopened.mistakes.values.single.failureCount, 1);
        final afterReopen = await _outboxIdentityRows(
          fixture.handle,
          fixture.storageScope,
        );
        expect(afterReopen, beforeReplay);
        expect(afterReopen.single.kind, 'answer');
        expect(afterReopen.single.correct, 0);
        expect(afterReopen.single.sound, item.targetSounds.first);
        expect(afterReopen.single.activity, activityId);
      },
    );

    for (final retention in [(1, 'latest-only-pruned'), (2000, 'retained')]) {
      for (final invalidRevision in [3, 4]) {
        test(
          'load rejects ${retention.$2} receipt expected revision $invalidRevision',
          () async {
            final scenario = await _corruptReceiptScenario(
              fixture,
              historyLimit: retention.$1,
            );
            final before = await _receiptCopies(
              fixture.handle,
              fixture.storageScope,
              scenario.answerCommand.token,
              scenario.activityId,
            );
            expect(before.historyPayload != null, retention.$1 > 1);
            final corruptPayload = _receiptPayloadWithRevision(
              before.latestPayload!,
              invalidRevision,
              fixture.scope,
            );
            await _mutateReceiptCopies(scenario, corruptPayload);
            final mutated = await _receiptCopies(
              fixture.handle,
              fixture.storageScope,
              scenario.answerCommand.token,
              scenario.activityId,
            );
            expect(mutated.latestPayload, corruptPayload);
            expect(
              mutated.historyPayload,
              retention.$1 > 1 ? corruptPayload : null,
            );

            await expectLater(
              scenario.repository.load(),
              throwsA(isA<LearningCorruptException>()),
            );
            await _expectReceiptCorruptionDidNotWrite(
              fixture,
              scenario,
              mutated,
              notifications: 3,
            );
          },
        );

        test(
          'scope-wide findReceipt rejects ${retention.$2} revision $invalidRevision before load',
          () async {
            final scenario = await _corruptReceiptScenario(
              fixture,
              historyLimit: retention.$1,
            );
            final before = await _receiptCopies(
              fixture.handle,
              fixture.storageScope,
              scenario.answerCommand.token,
              scenario.activityId,
            );
            final corruptPayload = _receiptPayloadWithRevision(
              before.latestPayload!,
              invalidRevision,
              fixture.scope,
            );
            await _mutateReceiptCopies(scenario, corruptPayload);
            final database = await fixture.handle.open();
            final adapter = CourseLearningSqlAdapter(
              scope: fixture.scope,
              transitions: fixture.transitions,
              historyLimit: retention.$1,
            );

            await expectLater(
              adapter.findReceipt(
                database,
                scenario.scopeId,
                scenario.answerCommand.token,
              ),
              throwsA(isA<LearningCorruptException>()),
            );
            final mutated = await _receiptCopies(
              fixture.handle,
              fixture.storageScope,
              scenario.answerCommand.token,
              scenario.activityId,
            );
            await _expectReceiptCorruptionDidNotWrite(
              fixture,
              scenario,
              mutated,
              notifications: 3,
            );
          },
        );

        test(
          'submit rejects ${retention.$2} receipt revision $invalidRevision without replay or repair',
          () async {
            final scenario = await _corruptReceiptScenario(
              fixture,
              historyLimit: retention.$1,
            );
            final before = await _receiptCopies(
              fixture.handle,
              fixture.storageScope,
              scenario.answerCommand.token,
              scenario.activityId,
            );
            final corruptPayload = _receiptPayloadWithRevision(
              before.latestPayload!,
              invalidRevision,
              fixture.scope,
            );
            final corruptedCommand =
                CourseLearningCommandCodec.decodeCanonicalCommand(
                  corruptPayload,
                  scope: fixture.scope,
                );
            expect(corruptedCommand.expectedScopeRevision, invalidRevision);
            await _mutateReceiptCopies(scenario, corruptPayload);
            final mutated = await _receiptCopies(
              fixture.handle,
              fixture.storageScope,
              scenario.answerCommand.token,
              scenario.activityId,
            );
            final outboxBefore = await _outboxIdentityRows(
              fixture.handle,
              fixture.storageScope,
            );

            await expectLater(
              scenario.repository.submit(corruptedCommand),
              throwsA(isA<LearningCorruptException>()),
            );
            await _expectReceiptCorruptionDidNotWrite(
              fixture,
              scenario,
              mutated,
              notifications: scenario.notifications.count,
            );
            expect(
              await _outboxIdentityRows(fixture.handle, fixture.storageScope),
              outboxBefore,
            );
          },
        );
      }
    }

    test(
      'valid exact retry survives ACK and retained-history pruning',
      () async {
        var notifications = 0;
        final repository = fixture.repository(
          historyLimit: 1,
          onCommitted: () => notifications++,
        );
        const activityId = 'lesson:en-fr-vowels';
        final initial = await repository.load();
        final started = await repository.submit(
          repository.prepare(
            state: initial,
            activityId: activityId,
            action: StartLearningRun(options: RunOptions()),
          ),
        );
        final item = fixture.registry.require(activityId).items.first;
        final answerCommand = repository.prepare(
          state: started.state,
          activityId: activityId,
          action: ChooseSound(
            selectedSound: item.choices.firstWhere(
              (choice) => choice != item.expectedChoice,
            ),
            audioSource: authoredAudioSource(item)!,
          ),
        );
        final answered = await repository.submit(answerCommand);
        final coordinator = fixture.coordinator(historyLimit: 1);
        final events = await coordinator.readSupportedCourseEvents();
        expect(events, hasLength(1));
        await coordinator.acknowledgeSupportedCourseEvents({events.single.id});
        expect(
          await _outboxIdentityRows(fixture.handle, fixture.storageScope),
          isEmpty,
        );

        final afterAck = await repository.load();
        await repository.submit(
          repository.prepare(
            state: afterAck,
            activityId: 'lesson:en-fr-nasal',
            action: StartLearningRun(options: RunOptions()),
          ),
        );
        final copies = await _receiptCopies(
          fixture.handle,
          fixture.storageScope,
          answerCommand.token,
          activityId,
        );
        expect(copies.historyPayload, isNull);
        expect(copies.latestPayload, isNotNull);
        final current = await repository.load();

        final replay = await repository.submit(answerCommand);
        expect(replay.duplicate, isTrue);
        expect(replay.state.revision, current.revision);
        expect(replay.state.commitOrdinal, current.commitOrdinal);
        expect(
          await _outboxIdentityRows(fixture.handle, fixture.storageScope),
          isEmpty,
        );
        expect(notifications, 3);
        expect(answered.state.commitOrdinal, 2);
      },
    );

    test(
      'course_exposure_is_activity_scoped_and_independent_after_reopen',
      () async {
        final registry = fixture.registry;
        final transitions = LearningTransitionEngine(registry);
        final repository = fixture.repository(transitions: transitions);
        const activityA = 'lesson:en-fr-vowels';
        const activityB = 'lesson:en-fr-nasal';
        const sharedItemId = 'beau';
        const sharedSound = 'o';
        final definitionA = registry.require(activityA);
        final definitionB = registry.require(activityB);
        expect(definitionA.kind, LearningActivityKind.legacyLesson);
        expect(definitionB.kind, LearningActivityKind.legacyLesson);
        expect(
          definitionA.items.any(
            (item) =>
                item.id == sharedItemId &&
                item.targetSounds.contains(sharedSound),
          ),
          isTrue,
        );
        expect(
          definitionB.items.any(
            (item) =>
                item.id == sharedItemId &&
                item.targetSounds.contains(sharedSound),
          ),
          isTrue,
        );

        Future<LearningCommit> submitAction(
          String activityId,
          LearningAction action,
        ) async {
          final state = await repository.load();
          return repository.submit(
            repository.prepare(
              state: state,
              activityId: activityId,
              action: action,
            ),
          );
        }

        await submitAction(activityA, StartLearningRun(options: RunOptions()));
        await submitAction(activityB, StartLearningRun(options: RunOptions()));
        await submitAction(
          activityB,
          ChooseSound(
            selectedSound: sharedSound,
            audioSource: AttemptAudioSource.pendingRecording,
          ),
        );
        await submitAction(
          activityB,
          ObserveAssistance(
            items: {
              ItemContextKey(itemId: sharedItemId, targetSound: sharedSound),
            },
            flags: {AssistanceFlag.graphemeHint},
          ),
        );

        final key = ItemContextKey(
          itemId: sharedItemId,
          targetSound: sharedSound,
        );
        await fixture.handle.close();
        final firstReopen = await fixture.handle.reopen();
        final beforeRestart = await repository.load();
        final exposureA = beforeRestart.activities[activityA]!.exposures[key]!;
        final exposureB = beforeRestart.activities[activityB]!.exposures[key]!;
        expect(exposureA.presentations, 0);
        expect(exposureA.assistance, {AssistanceFlag.explanationVisible});
        expect(exposureB.presentations, 1);
        expect(exposureB.assistance, {
          AssistanceFlag.explanationVisible,
          AssistanceFlag.graphemeHint,
        });
        expect(
          await _exposureActivityIds(firstReopen, fixture.storageScope, key),
          unorderedEquals([activityA, activityB]),
        );

        final restartedA = await submitAction(
          activityA,
          StartLearningRun(options: RunOptions()),
        );
        final expectedA =
            restartedA.state.activities[activityA]!.exposures[key];
        expect(expectedA, isNotNull);
        expect(expectedA!.presentations, 0);
        expect(expectedA.assistance, {AssistanceFlag.explanationVisible});

        await fixture.handle.close();
        final finalReopen = await fixture.handle.reopen();
        final reopenedState = await repository.load();
        final restartedExposureA =
            reopenedState.activities[activityA]!.exposures[key];
        expect(restartedExposureA, isNotNull);
        expect(restartedExposureA!.presentations, 0);
        expect(restartedExposureA.assistance, {
          AssistanceFlag.explanationVisible,
        });
        final reopenedExposureB =
            reopenedState.activities[activityB]!.exposures[key]!;
        expect(reopenedExposureB.presentations, exposureB.presentations);
        expect(reopenedExposureB.assistance, exposureB.assistance);
        expect(
          await _exposureActivityIds(finalReopen, fixture.storageScope, key),
          unorderedEquals([activityA, activityB]),
        );
      },
    );

    test(
      'course_outbox_fifo_survives_reopen_failed_send_partial_ack_and_retry',
      () async {
        const ownerId = 'fifo-user';
        final fifoOwner = LearningOwner.account(ownerId);
        final fifoScope = LearningScope(courseId: 'en-fr', owner: fifoOwner);
        final fifoStorageScope = LearningStorageScope(
          owner: fifoOwner,
          courseId: 'en-fr',
          family: LearningFamily.course,
        );
        fixture.setIdentity(fifoScope, fifoStorageScope);
        final transport = _RpcFixtureTransport();
        addTearDown(transport.client.dispose);
        final repository = fixture.repository(cloud: transport);
        final database = await fixture.handle.open();
        final scopeId = await database.ensureScope(fifoStorageScope);
        await database.customStatement(
          'UPDATE learning_scopes SET revision = 51, commit_ordinal = 51 WHERE id = ?',
          [scopeId],
        );

        final expectedIds = List.generate(
          102,
          (index) => 'event-${(101 - index).toString().padLeft(3, '0')}',
        );
        for (var index = 0; index < expectedIds.length; index++) {
          final sound = 'sound-$index';
          await database.customStatement(
            'INSERT INTO supported_sync_outbox '
            '(scope_id, event_id, enqueue_commit_ordinal, enqueue_event_index, '
            'user_id, course_id, kind, sound, skill, correct, activity, lesson_id, game, score) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL)',
            [
              scopeId,
              expectedIds[index],
              1 + index ~/ 2,
              index % 2,
              ownerId,
              'en-fr',
              'answer',
              sound,
              'listening',
              index.isEven ? 1 : 0,
              'lesson:en-fr-vowels',
            ],
          );
        }

        final coordinator = fixture.coordinator();
        final seededRows = await _outboxOrderRows(database, fifoStorageScope);
        expect(seededRows, [
          for (var index = 0; index < 102; index++)
            (1 + index ~/ 2, index % 2, expectedIds[index]),
        ]);
        expect(
          (await coordinator.readSupportedCourseEvents()).map(
            (event) => event.id,
          ),
          expectedIds,
        );
        expect(
          (await repository.load()).pending.map((event) => event.id),
          expectedIds,
        );

        final first = await repository.sync();
        expect(first.status, SupportedSyncStatus.pending);
        expect(first.remainingEvents, 102);
        await fixture.handle.reopen();
        final partial = await repository.sync();
        expect(partial.status, SupportedSyncStatus.pending);
        expect(partial.remainingEvents, 2);
        await fixture.handle.reopen();
        final reopenedForTail = await fixture.handle.open();
        final tail = expectedIds.skip(100).toList();
        expect(
          (await repository.load()).pending.map((event) => event.id),
          tail,
        );
        expect(await _outboxOrderRows(reopenedForTail, fifoStorageScope), [
          (51, 0, expectedIds[100]),
          (51, 1, expectedIds[101]),
        ]);
        final completed = await repository.sync();
        expect(completed.status, SupportedSyncStatus.synced);
        expect(completed.remainingEvents, 0);
        expect((await repository.load()).pending, isEmpty);
        expect(transport.batchIds, [
          expectedIds.take(100).toList(),
          expectedIds.take(100).toList(),
          tail,
          tail,
        ]);

        final expectedWireBatches = [
          expectedIds
              .take(100)
              .map((id) => _wireEvent(id, expectedIds.indexOf(id)))
              .toList(),
          expectedIds
              .take(100)
              .map((id) => _wireEvent(id, expectedIds.indexOf(id)))
              .toList(),
          tail.map((id) => _wireEvent(id, expectedIds.indexOf(id))).toList(),
          tail.map((id) => _wireEvent(id, expectedIds.indexOf(id))).toList(),
        ];
        expect(transport.wireBatches, expectedWireBatches);
        for (final batch in transport.wireBatches) {
          for (final event in batch) {
            expect(event.keys.toSet(), {
              'id',
              'user_id',
              'course_id',
              'kind',
              'sound',
              'skill',
              'correct',
              'activity',
            });
            expect(event, isNot(contains('enqueue_commit_ordinal')));
            expect(event, isNot(contains('enqueue_event_index')));
          }
        }
      },
    );

    test('checkpoint_codec_rejects_untyped_or_content_mismatched_snapshots', () {
      const codec = CourseLearningCheckpointCodec();
      final definition = fixture.registry.require('lesson:en-fr-vowels');
      final options = RunOptions();
      const snapshot = LegacyLessonCheckpoint(
        wordIndex: 0,
        selectedSound: null,
        finished: false,
      );
      final json = codec.encode(snapshot);
      expect(
        codec.decode(
          json,
          kind: definition.kind,
          definition: definition,
          options: options,
        ),
        isA<LegacyLessonCheckpoint>(),
      );
      expect(
        () => codec.decode(
          '{"kind":"legacyLesson","wordIndex":0,"selectedSound":null,"finished":false,"extra":true}',
          kind: definition.kind,
          definition: definition,
          options: options,
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decode(
          '{"kind":"legacyLesson","wordIndex":999999,"selectedSound":null,"finished":false}',
          kind: definition.kind,
          definition: definition,
          options: options,
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decode(
          json,
          kind: LearningActivityKind.discovery,
          definition: definition,
          options: options,
        ),
        throwsFormatException,
      );
      final oversized = SoundGameCheckpoint(
        board: SoundBoardState(
          board: List<String>.filled(36, 'x' * 30000),
          stars: const <int>{},
        ),
        clock: ArcadeClockState(
          remaining: 60,
          round: 1,
          score: 0,
          paused: true,
        ),
      );
      expect(() => codec.encode(oversized), throwsArgumentError);
    });

    test('checkpoint codec accepts repeated game-board tiles', () {
      const codec = CourseLearningCheckpointCodec();
      final registry = fixture.registry;
      final soundBoard = SoundMatchEngine(random: Random(31)).snapshot();
      final wordBoard = WordMatchEngine(random: Random(32)).snapshot();
      expect(
        soundBoard.board.toSet().length,
        lessThan(soundBoard.board.length),
      );
      expect(wordBoard.board.toSet().length, lessThan(wordBoard.board.length));
      final clock = ArcadeClockState(
        remaining: 60,
        round: 1,
        score: 0,
        paused: true,
      );
      final soundSnapshot = SoundGameCheckpoint(
        board: soundBoard,
        clock: clock,
      );
      final wordSnapshot = WordGameCheckpoint(board: wordBoard, clock: clock);

      expect(
        codec.decode(
          codec.encode(soundSnapshot),
          kind: LearningActivityKind.soundGame,
          definition: registry.require('arcade:sound'),
          options: RunOptions(),
        ),
        isA<SoundGameCheckpoint>(),
      );
      expect(
        codec.decode(
          codec.encode(wordSnapshot),
          kind: LearningActivityKind.wordGame,
          definition: registry.require('arcade:word'),
          options: RunOptions(),
        ),
        isA<WordGameCheckpoint>(),
      );
    });

    test('state_validator_checks_activity_exposure_content_identity', () {
      final registry = fixture.registry;
      final transitions = LearningTransitionEngine(registry);
      final definition = registry.require('lesson:en-fr-vowels');
      final empty = CourseLearningState.empty(fixture.scope);
      final command = transitions.prepare(
        state: empty,
        authGeneration: fixture.generation,
        activityId: definition.id,
        action: StartLearningRun(options: RunOptions()),
        token: '0000000000000000000001',
        submittedAt: DateTime.utc(2026, 10, 19),
        random: Random(1),
      );
      final transition = transitions.evaluate(
        state: empty,
        command: command,
        committedAt: DateTime.utc(2026, 10, 19),
      );
      final valid = CourseLearningState(
        scope: fixture.scope,
        revision: 1,
        commitOrdinal: 1,
        history: const [],
        activities: {definition.id: transition.slot},
        mistakes: const {},
        summaries: const {},
        completions: const [],
        bestScores: const {},
        pending: const [],
      );
      CourseLearningStateValidator.validate(valid, registry);

      final invalidSlot = ActivitySlot(
        activityId: transition.slot.activityId,
        kind: transition.slot.kind,
        contentRevision: transition.slot.contentRevision,
        cursor: transition.slot.cursor,
        options: transition.slot.options,
        snapshot: transition.slot.snapshot,
        exposures: {
          ItemContextKey(itemId: 'not-in-the-catalogue', targetSound: 'o'):
              ItemExposure(presentations: 0, assistance: const {}),
        },
        latestReceipt: transition.slot.latestReceipt,
      );
      final invalid = CourseLearningState(
        scope: fixture.scope,
        revision: 1,
        commitOrdinal: 1,
        history: const [],
        activities: {definition.id: invalidSlot},
        mistakes: const {},
        summaries: const {},
        completions: const [],
        bestScores: const {},
        pending: const [],
      );
      expect(
        () => CourseLearningStateValidator.validate(invalid, registry),
        throwsA(anything),
      );
    });

    test('stored sound cue rejects unsupported selected family', () async {
      final repository = fixture.repository();
      final attempt = await _persistIncorrectSoundAttempt(
        fixture,
        repository,
        expectedWordId: 'rouge',
        expectedSound: 'u',
      );
      final valid = (await repository.load()).history
          .expand((batch) => batch.attempts)
          .singleWhere((value) => value.submissionId == attempt.submissionId);
      final validAnswer = valid.answer as SoundCueAnswer;
      expect(SoundMatchEngine.families, contains(validAnswer.selectedFamily));
      expect(validAnswer.expectedFamily, 'u');
      expect(valid.correct, isFalse);

      final database = await fixture.handle.open();
      final scopeId = await database.ensureScope(fixture.storageScope);
      await database.customStatement(
        'UPDATE learning_attempt_values SET text_value = ? '
        'WHERE scope_id = ? AND attempt_id = ? AND field = ?',
        ['ʁ', scopeId, attempt.submissionId, 'selected_family'],
      );
      final mutatedRows = await _rawAttemptRows(
        fixture.handle,
        fixture.storageScope,
      );

      await expectLater(
        repository.load(),
        throwsA(isA<LearningCorruptException>()),
      );
      expect(
        await _rawAttemptRows(fixture.handle, fixture.storageScope),
        mutatedRows,
      );
    });

    test('stored sound cue rejects unsupported expected family', () async {
      final repository = fixture.repository();
      final attempt = await _persistIncorrectSoundAttempt(
        fixture,
        repository,
        expectedWordId: 'rouge',
        expectedSound: 'u',
      );
      final valid = (await repository.load()).history
          .expand((batch) => batch.attempts)
          .singleWhere((value) => value.submissionId == attempt.submissionId);
      final validAnswer = valid.answer as SoundCueAnswer;
      expect(valid.itemId, 'rouge');
      expect(validAnswer.expectedFamily, 'u');
      expect(valid.targetSounds, ['u']);
      expect(valid.correct, isFalse);

      final database = await fixture.handle.open();
      final scopeId = await database.ensureScope(fixture.storageScope);
      await database.customStatement(
        'UPDATE learning_attempt_values SET text_value = ? '
        'WHERE scope_id = ? AND attempt_id = ? AND field IN (?, ?)',
        ['ʁ', scopeId, attempt.submissionId, 'expected_family', 'target_sound'],
      );
      await database.customStatement(
        'UPDATE learning_mistakes SET target_sound = ? '
        'WHERE scope_id = ? AND activity_id = ? AND item_id = ? '
        'AND target_sound = ? AND latest_wrong_attempt_id = ?',
        [
          'ʁ',
          scopeId,
          attempt.activityId,
          attempt.itemId,
          'u',
          attempt.submissionId,
        ],
      );
      await database.customStatement(
        'UPDATE learning_summaries SET sound = ? '
        'WHERE scope_id = ? AND family = ? AND sound = ? AND skill = ? '
        'AND origin = ?',
        ['ʁ', scopeId, 'course', 'u', 'listening', 'game'],
      );
      final mutatedRows = await _rawAttemptRows(
        fixture.handle,
        fixture.storageScope,
      );

      await expectLater(
        repository.load(),
        throwsA(isA<LearningCorruptException>()),
      );
      expect(
        await _rawAttemptRows(fixture.handle, fixture.storageScope),
        mutatedRows,
      );
    });

    test(
      'stored sound cue rejects audio outside authored provenance',
      () async {
        final repository = fixture.repository();
        final attempt = await _persistIncorrectSoundAttempt(
          fixture,
          repository,
        );
        final valid = (await repository.load()).history
            .expand((batch) => batch.attempts)
            .singleWhere((value) => value.submissionId == attempt.submissionId);
        final item = fixture.registry
            .require(valid.activityId)
            .items
            .singleWhere((value) => value.id == valid.itemId);
        expect(valid.audioSource, authoredAudioSource(item));

        final database = await fixture.handle.open();
        final scopeId = await database.ensureScope(fixture.storageScope);
        final wrongSource = AttemptAudioSource.values.firstWhere(
          (source) => source != authoredAudioSource(item),
        );
        await database.customStatement(
          'UPDATE learning_attempts SET audio_source = ? '
          'WHERE scope_id = ? AND attempt_id = ?',
          [wrongSource.name, scopeId, attempt.submissionId],
        );
        final mutatedRows = await _rawAttemptRows(
          fixture.handle,
          fixture.storageScope,
        );

        await expectLater(
          repository.load(),
          throwsA(isA<LearningCorruptException>()),
        );
        expect(
          await _rawAttemptRows(fixture.handle, fixture.storageScope),
          mutatedRows,
        );
      },
    );

    test('stored word tile requires notApplicable audio', () async {
      final repository = fixture.repository();
      final attempts = await _persistWordTileAttempts(fixture, repository);
      final valid = await repository.load();
      final validAttempts = valid.history
          .expand((batch) => batch.attempts)
          .where(
            (attempt) => attempts.any(
              (created) => created.submissionId == attempt.submissionId,
            ),
          )
          .toList();
      expect(validAttempts, isNotEmpty);
      expect(
        validAttempts.every(
          (attempt) =>
              attempt.answer is WordTileAnswer &&
              attempt.audioSource == AttemptAudioSource.notApplicable,
        ),
        isTrue,
      );
      final incorrect = validAttempts.singleWhere(
        (attempt) => !attempt.correct,
      );
      expect((incorrect.answer as WordTileAnswer).expectedMembership, isFalse);

      final database = await fixture.handle.open();
      final scopeId = await database.ensureScope(fixture.storageScope);
      await database.customStatement(
        'UPDATE learning_attempts SET audio_source = ? '
        'WHERE scope_id = ? AND attempt_id = ?',
        ['practiceSpeech', scopeId, incorrect.submissionId],
      );
      final mutatedRows = await _rawAttemptRows(
        fixture.handle,
        fixture.storageScope,
      );

      await expectLater(
        repository.load(),
        throwsA(isA<LearningCorruptException>()),
      );
      expect(
        await _rawAttemptRows(fixture.handle, fixture.storageScope),
        mutatedRows,
      );
    });
  });
}

class _Fixture {
  _Fixture(this.file)
    : owner = LearningOwner.account('course-user'),
      scope = LearningScope(
        courseId: 'en-fr',
        owner: LearningOwner.account('course-user'),
      ),
      storageScope = LearningStorageScope(
        owner: LearningOwner.account('course-user'),
        courseId: 'en-fr',
        family: LearningFamily.course,
      ) {
    registry = LearningRegistry.french();
    transitions = LearningTransitionEngine(registry);
    handle = LearningDatabaseHandle(
      open: () async =>
          LearningDatabase(DatabaseConnection(NativeDatabase(file))),
    );
  }

  final File file;
  final LearningOwner owner;
  LearningScope scope;
  LearningStorageScope storageScope;
  final int generation = 17;
  late LearningRegistry registry;
  late LearningTransitionEngine transitions;
  late LearningDatabaseHandle handle;
  int tokenCounter = 0;
  LearningAuthScope get auth => LearningAuthScope(
    owner: scope.owner,
    generation: generation,
    ready: true,
  );

  void setIdentity(
    LearningScope newScope,
    LearningStorageScope newStorageScope,
  ) {
    scope = newScope;
    storageScope = newStorageScope;
  }

  SqliteCourseLearningRepository repository({
    LearningTransitionEngine? transitions,
    LearningCloudTransport? cloud,
    int historyLimit = 2000,
    void Function()? onCommitted,
  }) => SqliteCourseLearningRepository(
    database: handle,
    scope: scope,
    authGeneration: generation,
    currentAuth: () => auth,
    backendOwner: () => scope.owner,
    transitions: transitions ?? this.transitions,
    clock: () => DateTime.utc(2026, 10, 19, 12),
    newToken: () => (++tokenCounter).toRadixString(36).padLeft(22, '0'),
    random: Random(7),
    cloud: cloud,
    onCommitted: onCommitted,
    historyLimit: historyLimit,
  );

  SqliteLearningCommandCoordinator<
    CourseLearningState,
    LearningCommand,
    LearningCommit
  >
  coordinator({int historyLimit = 2000}) => SqliteLearningCommandCoordinator(
    database: handle,
    adapter: CourseLearningSqlAdapter(
      scope: scope,
      transitions: transitions,
      historyLimit: historyLimit,
    ),
    authGeneration: generation,
    currentAuth: () => auth,
    backendOwner: () => scope.owner,
    clock: () => DateTime.utc(2026, 10, 19, 12),
  );

  Future<void> close() => handle.close();
}

final class _NotificationCounter {
  int count = 0;

  void notify() => count++;
}

final class _ReceiptScenario {
  const _ReceiptScenario({
    required this.repository,
    required this.answerCommand,
    required this.activityId,
    required this.historyLimit,
    required this.scopeId,
    required this.revision,
    required this.commitOrdinal,
    required this.notifications,
    required this.outboxRows,
  });

  final SqliteCourseLearningRepository repository;
  final LearningCommand answerCommand;
  final String activityId;
  final int historyLimit;
  final int scopeId;
  final int revision;
  final int commitOrdinal;
  final _NotificationCounter notifications;
  final List<_OutboxIdentity> outboxRows;
}

Future<_ReceiptScenario> _corruptReceiptScenario(
  _Fixture fixture, {
  required int historyLimit,
}) async {
  final notifications = _NotificationCounter();
  final repository = fixture.repository(
    historyLimit: historyLimit,
    onCommitted: notifications.notify,
  );
  const activityId = 'lesson:en-fr-vowels';
  final initial = await repository.load();
  final started = await repository.submit(
    repository.prepare(
      state: initial,
      activityId: activityId,
      action: StartLearningRun(options: RunOptions()),
    ),
  );
  final item = fixture.registry.require(activityId).items.first;
  final answerCommand = repository.prepare(
    state: started.state,
    activityId: activityId,
    action: ChooseSound(
      selectedSound: item.choices.firstWhere(
        (choice) => choice != item.expectedChoice,
      ),
      audioSource: authoredAudioSource(item)!,
    ),
  );
  final answered = await repository.submit(answerCommand);
  final afterOtherActivity = await repository.submit(
    repository.prepare(
      state: answered.state,
      activityId: 'lesson:en-fr-nasal',
      action: StartLearningRun(options: RunOptions()),
    ),
  );
  final database = await fixture.handle.open();
  final scopeId = await database.ensureScope(fixture.storageScope);
  return _ReceiptScenario(
    repository: repository,
    answerCommand: answerCommand,
    activityId: activityId,
    historyLimit: historyLimit,
    scopeId: scopeId,
    revision: afterOtherActivity.state.revision,
    commitOrdinal: afterOtherActivity.state.commitOrdinal,
    notifications: notifications,
    outboxRows: await _outboxIdentityRows(fixture.handle, fixture.storageScope),
  );
}

Future<({String? historyPayload, String? latestPayload})> _receiptCopies(
  LearningDatabaseHandle handle,
  LearningStorageScope scope,
  String token,
  String activityId,
) async {
  final database = await handle.open();
  final scopeRows = await database
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
  final scopeId = scopeRows.single.read<int>('id');
  final historyRows = await database
      .customSelect(
        'SELECT canonical_payload FROM learning_command_receipts '
        'WHERE scope_id = ? AND token = ?',
        variables: [Variable<int>(scopeId), Variable<String>(token)],
      )
      .get();
  final latestRows = await database
      .customSelect(
        'SELECT latest_receipt_payload FROM learning_runs '
        'WHERE scope_id = ? AND activity_id = ? AND latest_receipt_token = ?',
        variables: [
          Variable<int>(scopeId),
          Variable<String>(activityId),
          Variable<String>(token),
        ],
      )
      .get();
  if (historyRows.length > 1 || latestRows.length != 1) {
    throw StateError('Expected one latest and at most one history receipt.');
  }
  return (
    historyPayload: historyRows.isEmpty
        ? null
        : historyRows.single.read<String>('canonical_payload'),
    latestPayload: latestRows.single.read<String>('latest_receipt_payload'),
  );
}

String _receiptPayloadWithRevision(
  String payload,
  int revision,
  LearningScope scope,
) {
  final updated = payload.replaceFirst(
    RegExp(r'"expectedScopeRevision":\d+'),
    '"expectedScopeRevision":$revision',
  );
  if (updated == payload) throw StateError('No expected revision in receipt.');
  final decoded = CourseLearningCommandCodec.decodeCanonicalCommand(
    updated,
    scope: scope,
  );
  if (decoded.expectedScopeRevision != revision ||
      CourseLearningCommandCodec.canonicalCommand(decoded) != updated) {
    throw StateError('Mutated receipt is not canonical.');
  }
  return updated;
}

Future<void> _mutateReceiptCopies(
  _ReceiptScenario scenario,
  String payload,
) async {
  final database = await scenario.repository.database.open();
  await database.customStatement(
    'UPDATE learning_runs SET latest_receipt_payload = ? '
    'WHERE scope_id = ? AND activity_id = ?',
    [payload, scenario.scopeId, scenario.activityId],
  );
  if (scenario.historyLimit > 1) {
    await database.customStatement(
      'UPDATE learning_command_receipts SET canonical_payload = ? '
      'WHERE scope_id = ? AND token = ?',
      [payload, scenario.scopeId, scenario.answerCommand.token],
    );
  }
}

Future<(int, int)> _scopeRevisionAndOrdinal(
  LearningDatabaseHandle handle,
  int scopeId,
) async {
  final database = await handle.open();
  final row = await database
      .customSelect(
        'SELECT revision, commit_ordinal FROM learning_scopes WHERE id = ?',
        variables: [Variable<int>(scopeId)],
      )
      .getSingle();
  return (row.read<int>('revision'), row.read<int>('commit_ordinal'));
}

Future<void> _expectReceiptCorruptionDidNotWrite(
  _Fixture fixture,
  _ReceiptScenario scenario,
  ({String? historyPayload, String? latestPayload}) mutated, {
  required int notifications,
}) async {
  expect(
    await _receiptCopies(
      fixture.handle,
      fixture.storageScope,
      scenario.answerCommand.token,
      scenario.activityId,
    ),
    mutated,
  );
  expect(await _scopeRevisionAndOrdinal(fixture.handle, scenario.scopeId), (
    scenario.revision,
    scenario.commitOrdinal,
  ));
  expect(
    await _outboxIdentityRows(fixture.handle, fixture.storageScope),
    scenario.outboxRows,
  );
  expect(scenario.notifications.count, notifications);
}

LearningCommand _prepareWithSeed(
  _Fixture fixture,
  CourseLearningState state,
  String activityId,
  LearningAction action,
  int seed,
) => fixture.transitions.prepare(
  state: state,
  authGeneration: fixture.generation,
  activityId: activityId,
  action: action,
  token: (++fixture.tokenCounter).toRadixString(36).padLeft(22, '0'),
  submittedAt: DateTime.utc(2026, 10, 19, 12),
  random: Random(seed),
);

Future<CourseAttempt> _persistIncorrectSoundAttempt(
  _Fixture fixture,
  SqliteCourseLearningRepository repository, {
  String? expectedWordId,
  String? expectedSound,
}) async {
  const activityId = 'arcade:sound';
  final definition = fixture.registry.require(activityId);
  for (var seed = 1; seed <= 256; seed++) {
    final current = await repository.load();
    final started = await _submitDebug(
      repository,
      _prepareWithSeed(
        fixture,
        current,
        activityId,
        StartLearningRun(options: RunOptions()),
        seed,
      ),
      'sound start seed $seed',
    );
    final board =
        (started.state.activities[activityId]!.snapshot as SoundGameCheckpoint)
            .board;
    final game = SoundMatchEngine.fromState(board, random: Random(seed));
    final available = game.availableFamilies();
    ({
      int first,
      int second,
      String selected,
      String target,
      LearningSourceItem item,
    })?
    candidate;
    for (final move in game.legalMoves()) {
      final families = _swapSoundFamilies(board.board, move.$1, move.$2);
      if (families.length != 1) continue;
      final selected = families.single;
      for (final item in definition.items) {
        if (expectedWordId != null && item.id != expectedWordId) continue;
        for (final target in item.targetSounds) {
          if (!SoundMatchEngine.families.contains(target) ||
              !available.contains(target) ||
              target == selected ||
              (expectedSound != null && target != expectedSound)) {
            continue;
          }
          candidate ??= (
            first: move.$1,
            second: move.$2,
            selected: selected,
            target: target,
            item: item,
          );
        }
      }
    }
    if (candidate == null) continue;

    final resumed = await _submitDebug(
      repository,
      _prepareWithSeed(
        fixture,
        started.state,
        activityId,
        CheckpointArcade(elapsedSeconds: 0, paused: false),
        seed + 1000,
      ),
      'sound resume seed $seed',
    );
    final action = SwapSoundTiles(
      first: candidate.first,
      second: candidate.second,
      cue: HeardSoundCue(
        wordId: candidate.item.id,
        targetSound: candidate.target,
        audioSource: authoredAudioSource(candidate.item)!,
      ),
    );
    final committed = await _submitDebug(
      repository,
      _prepareWithSeed(fixture, resumed.state, activityId, action, seed + 2000),
      'sound move seed $seed',
    );
    final attempts = committed.state.history
        .expand((batch) => batch.attempts)
        .where(
          (attempt) => attempt.commitOrdinal == committed.state.commitOrdinal,
        )
        .toList();
    if (attempts.length != 1 || attempts.single.correct) {
      throw StateError(
        'Expected a retained incorrect single-cue game attempt.',
      );
    }
    return attempts.single;
  }
  throw StateError('Could not generate an incorrect supported sound cue.');
}

Future<List<CourseAttempt>> _persistWordTileAttempts(
  _Fixture fixture,
  SqliteCourseLearningRepository repository,
) async {
  const activityId = 'arcade:word';
  final initial = await repository.load();
  final started = await _submitDebug(
    repository,
    _prepareWithSeed(
      fixture,
      initial,
      activityId,
      StartLearningRun(options: RunOptions()),
      9101,
    ),
    'word start',
  );
  final resumed = await _submitDebug(
    repository,
    _prepareWithSeed(
      fixture,
      started.state,
      activityId,
      CheckpointArcade(elapsedSeconds: 0, paused: false),
      9102,
    ),
    'word resume',
  );
  final board =
      (resumed.state.activities[activityId]!.snapshot as WordGameCheckpoint)
          .board;
  final game = WordMatchEngine.fromState(board, random: Random(9103));
  final chain = _incorrectWordChain(game);
  if (chain.isEmpty) {
    throw StateError('Expected a connected chain containing a wrong tile.');
  }
  final committed = await _submitDebug(
    repository,
    _prepareWithSeed(
      fixture,
      resumed.state,
      activityId,
      LinkWordTiles(indices: chain),
      9104,
    ),
    'word link',
  );
  return committed.state.history
      .expand((batch) => batch.attempts)
      .where(
        (attempt) => attempt.commitOrdinal == committed.state.commitOrdinal,
      )
      .toList();
}

Future<LearningCommit> _submitDebug(
  SqliteCourseLearningRepository repository,
  LearningCommand command,
  String label,
) async {
  try {
    return await repository.submit(command);
  } on LearningInvalidCommandException catch (error) {
    throw StateError('$label rejected: ${error.cause}');
  }
}

Set<String> _swapSoundFamilies(List<String> source, int first, int second) {
  final board = List<String>.of(source);
  final value = board[first];
  board[first] = board[second];
  board[second] = value;
  final families = <String>{};
  for (var index = 0; index < 36; index++) {
    if (index % 6 <= 3 &&
        board[index] == board[index + 1] &&
        board[index] == board[index + 2]) {
      families.add(board[index]);
    }
    if (index ~/ 6 <= 3 &&
        board[index] == board[index + 6] &&
        board[index] == board[index + 12]) {
      families.add(board[index]);
    }
  }
  return families;
}

List<int> _incorrectWordChain(WordMatchEngine game) {
  for (var first = 0; first < game.board.length; first++) {
    for (var second = 0; second < game.board.length; second++) {
      if (!game.adjacent(first, second)) continue;
      for (var third = 0; third < game.board.length; third++) {
        if (third == first || !game.adjacent(second, third)) continue;
        final words = [
          game.board[first],
          game.board[second],
          game.board[third],
        ];
        if (words.any((word) => !wordByText(word).contains(game.target))) {
          return [first, second, third];
        }
      }
    }
  }
  return const [];
}

Future<List<String>> _rawAttemptRows(
  LearningDatabaseHandle handle,
  LearningStorageScope scope,
) async {
  final database = await handle.open();
  final rows = await database
      .customSelect(
        'SELECT a.attempt_id, a.answer_kind, a.item_id, a.audio_source, '
        'a.correct, v.field, v.ordinal, v.value_type, v.text_value, '
        'v.int_value, v.bool_value FROM learning_attempts a '
        'LEFT JOIN learning_attempt_values v ON v.scope_id = a.scope_id '
        'AND v.attempt_id = a.attempt_id WHERE a.scope_id = '
        '(SELECT id FROM learning_scopes WHERE owner_kind = ? AND owner_id = ? '
        'AND course_id = ? AND family = ?) ORDER BY a.attempt_id, v.field, v.ordinal',
        variables: [
          Variable<String>(scope.ownerKind),
          Variable<String>(scope.ownerId),
          Variable<String>(scope.courseId),
          Variable<String>(scope.databaseFamily),
        ],
      )
      .get();
  return rows
      .map(
        (row) => jsonEncode([
          row.read<String>('attempt_id'),
          row.read<String>('answer_kind'),
          row.readNullable<String>('item_id'),
          row.read<String>('audio_source'),
          row.read<int>('correct'),
          row.readNullable<String>('field'),
          row.readNullable<int>('ordinal'),
          row.readNullable<String>('value_type'),
          row.readNullable<String>('text_value'),
          row.readNullable<int>('int_value'),
          row.readNullable<int>('bool_value'),
        ]),
      )
      .toList();
}

final class _OutboxIdentity {
  const _OutboxIdentity({
    required this.eventId,
    required this.enqueueCommitOrdinal,
    required this.enqueueEventIndex,
    required this.kind,
    required this.sound,
    required this.correct,
    required this.activity,
  });
  final String eventId;
  final int enqueueCommitOrdinal;
  final int enqueueEventIndex;
  final String kind;
  final String? sound;
  final int? correct;
  final String? activity;

  @override
  bool operator ==(Object other) =>
      other is _OutboxIdentity &&
      eventId == other.eventId &&
      enqueueCommitOrdinal == other.enqueueCommitOrdinal &&
      enqueueEventIndex == other.enqueueEventIndex &&
      kind == other.kind &&
      sound == other.sound &&
      correct == other.correct &&
      activity == other.activity;

  @override
  int get hashCode => Object.hash(
    eventId,
    enqueueCommitOrdinal,
    enqueueEventIndex,
    kind,
    sound,
    correct,
    activity,
  );
}

Future<List<_OutboxIdentity>> _outboxIdentityRows(
  LearningDatabaseHandle handle,
  LearningStorageScope scope,
) async {
  final db = await handle.open();
  final scopeRows = await db
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
  final scopeId = scopeRows.single.read<int>('id');
  final rows = await db
      .customSelect(
        'SELECT event_id, enqueue_commit_ordinal, enqueue_event_index, kind, sound, correct, activity '
        'FROM supported_sync_outbox WHERE scope_id = ? '
        'ORDER BY enqueue_commit_ordinal, enqueue_event_index',
        variables: [Variable<int>(scopeId)],
      )
      .get();
  return rows
      .map(
        (row) => _OutboxIdentity(
          eventId: row.read<String>('event_id'),
          enqueueCommitOrdinal: row.read<int>('enqueue_commit_ordinal'),
          enqueueEventIndex: row.read<int>('enqueue_event_index'),
          kind: row.read<String>('kind'),
          sound: row.readNullable<String>('sound'),
          correct: row.readNullable<int>('correct'),
          activity: row.readNullable<String>('activity'),
        ),
      )
      .toList();
}

Future<List<(int, int, String)>> _outboxOrderRows(
  LearningDatabase db,
  LearningStorageScope scope,
) async {
  final rows = await db
      .customSelect(
        'SELECT event_id, enqueue_commit_ordinal, enqueue_event_index '
        'FROM supported_sync_outbox WHERE scope_id = '
        '(SELECT id FROM learning_scopes WHERE owner_kind = ? AND owner_id = ? '
        'AND course_id = ? AND family = ?) '
        'ORDER BY enqueue_commit_ordinal, enqueue_event_index',
        variables: [
          Variable<String>(scope.ownerKind),
          Variable<String>(scope.ownerId),
          Variable<String>(scope.courseId),
          Variable<String>(scope.databaseFamily),
        ],
      )
      .get();
  return rows
      .map(
        (row) => (
          row.read<int>('enqueue_commit_ordinal'),
          row.read<int>('enqueue_event_index'),
          row.read<String>('event_id'),
        ),
      )
      .toList();
}

Future<List<String>> _exposureActivityIds(
  LearningDatabase db,
  LearningStorageScope scope,
  ItemContextKey key,
) async {
  final rows = await db
      .customSelect(
        'SELECT activity_id FROM learning_exposure WHERE scope_id = '
        '(SELECT id FROM learning_scopes WHERE owner_kind = ? AND owner_id = ? '
        'AND course_id = ? AND family = ?) AND family = \'course\' '
        'AND item_id = ? AND target_sound = ? ORDER BY activity_id',
        variables: [
          Variable<String>(scope.ownerKind),
          Variable<String>(scope.ownerId),
          Variable<String>(scope.courseId),
          Variable<String>(scope.databaseFamily),
          Variable<String>(key.itemId),
          Variable<String>(key.targetSound),
        ],
      )
      .get();
  return rows.map((row) => row.read<String>('activity_id')).toList();
}

Future<Map<String, List<String>>> _answerValueRows(
  LearningDatabaseHandle handle,
  LearningStorageScope scope,
) async {
  final db = await handle.open();
  final rows = await db
      .customSelect(
        'SELECT v.field, v.ordinal, v.text_value FROM learning_attempt_values v '
        'JOIN learning_attempts a ON a.scope_id = v.scope_id AND a.attempt_id = v.attempt_id '
        'WHERE a.scope_id = (SELECT id FROM learning_scopes WHERE owner_kind = ? '
        'AND owner_id = ? AND course_id = ? AND family = ?) '
        'ORDER BY v.field, v.ordinal',
        variables: [
          Variable<String>(scope.ownerKind),
          Variable<String>(scope.ownerId),
          Variable<String>(scope.courseId),
          Variable<String>(scope.databaseFamily),
        ],
      )
      .get();
  final values = <String, List<String>>{};
  for (final row in rows) {
    values
        .putIfAbsent(row.read<String>('field'), () => [])
        .add(row.read<String>('text_value'));
  }
  return values;
}

Future<String> _receiptPayload(
  LearningDatabaseHandle handle,
  LearningStorageScope scope,
  String token,
) async {
  final db = await handle.open();
  final row = await db
      .customSelect(
        'SELECT canonical_payload FROM learning_command_receipts WHERE token = ? '
        'AND scope_id = (SELECT id FROM learning_scopes WHERE owner_kind = ? '
        'AND owner_id = ? AND course_id = ? AND family = ?)',
        variables: [
          Variable<String>(token),
          Variable<String>(scope.ownerKind),
          Variable<String>(scope.ownerId),
          Variable<String>(scope.courseId),
          Variable<String>(scope.databaseFamily),
        ],
      )
      .getSingle();
  return row.read<String>('canonical_payload');
}

Future<String> _checkpointJson(
  LearningDatabaseHandle handle,
  LearningStorageScope scope,
  String activityId,
) async {
  final db = await handle.open();
  final row = await db
      .customSelect(
        'SELECT checkpoint_json FROM learning_runs WHERE activity_id = ? '
        'AND scope_id = (SELECT id FROM learning_scopes WHERE owner_kind = ? '
        'AND owner_id = ? AND course_id = ? AND family = ?)',
        variables: [
          Variable<String>(activityId),
          Variable<String>(scope.ownerKind),
          Variable<String>(scope.ownerId),
          Variable<String>(scope.courseId),
          Variable<String>(scope.databaseFamily),
        ],
      )
      .getSingle();
  return row.read<String>('checkpoint_json');
}

final class _RpcFixtureTransport implements LearningCloudTransport {
  _RpcFixtureTransport() {
    client = SupabaseClient(
      'https://course.example.invalid',
      'public-test-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/record_course_events');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys, ['events']);
        final events = (body['events'] as List).cast<Map<String, dynamic>>();
        wireBatches.add(events);
        requestCount++;
        if (requestCount == 1 || requestCount == 3) {
          return http.Response('fixture failure', 500, request: request);
        }
        return http.Response('', 204, request: request);
      }),
    );
    delegate = SupabaseLearningCloudTransport(client);
  }

  late final SupabaseClient client;
  late final SupabaseLearningCloudTransport delegate;
  final List<List<String>> batchIds = [];
  final List<List<Map<String, dynamic>>> wireBatches = [];
  int requestCount = 0;

  @override
  Future<void> send(List<SupportedCloudEvent> events) async {
    batchIds.add(events.map((event) => event.id).toList());
    await delegate.send(events);
  }
}

Map<String, dynamic> _wireEvent(String id, int index) => {
  'id': id,
  'user_id': 'fifo-user',
  'course_id': 'en-fr',
  'kind': 'answer',
  'sound': 'sound-$index',
  'skill': 'listening',
  'correct': index.isEven,
  'activity': 'lesson:en-fr-vowels',
};
