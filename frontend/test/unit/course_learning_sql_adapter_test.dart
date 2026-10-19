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
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_sync.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_adapter.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/course_learning_state_validator.dart';
import 'package:linguist/src/core/course/storage/course_learning_checkpoint_codec.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/learning_sql_transaction.dart';
import 'package:linguist/src/core/course/storage/learning_storage_scope.dart';
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
  );

  SqliteLearningCommandCoordinator<
    CourseLearningState,
    LearningCommand,
    LearningCommit
  >
  coordinator() => SqliteLearningCommandCoordinator(
    database: handle,
    adapter: CourseLearningSqlAdapter(
      scope: scope,
      transitions: transitions,
      historyLimit: 2000,
    ),
    authGeneration: generation,
    currentAuth: () => auth,
    backendOwner: () => scope.owner,
    clock: () => DateTime.utc(2026, 10, 19, 12),
  );

  Future<void> close() => handle.close();
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
