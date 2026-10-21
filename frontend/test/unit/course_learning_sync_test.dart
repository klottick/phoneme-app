import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_sync.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../support/sqlite_learning_test_harness.dart'
    show insertRow, openFileLearningTestDatabase;

final class _RecordingTransport implements LearningCloudTransport {
  final List<List<SupportedCloudEvent>> batches = [];
  Object? failure;
  void Function()? onSend;
  Completer<void>? entered;
  Completer<void>? release;

  @override
  Future<void> send(List<SupportedCloudEvent> events) async {
    batches.add(List.unmodifiable(events));
    onSend?.call();
    final signal = entered;
    if (signal != null && !signal.isCompleted) signal.complete();
    final gate = release;
    if (gate != null) await gate.future;
    if (failure case final error?) throw error;
  }
}

final class _SyncFixture {
  _SyncFixture() {
    directory = Directory.systemTemp.createTempSync('course-sync-test-');
    database = LearningDatabaseHandle(
      open: () => openFileLearningTestDatabase(
        File('${directory.path}/learning.sqlite'),
      ),
    );
    addTearDown(dispose);
  }

  late final Directory directory;
  late final LearningDatabaseHandle database;
  int _tokenCounter = 0;

  SqliteCourseLearningRepository repository({
    required LearningOwner owner,
    required LearningCloudTransport? transport,
    int generation = 0,
    LearningAuthScope Function()? currentAuth,
    LearningOwner Function()? backendOwner,
    void Function()? onCommitted,
  }) => SqliteCourseLearningRepository(
    database: database,
    scope: LearningScope(courseId: 'en-fr', owner: owner),
    authGeneration: generation,
    currentAuth:
        currentAuth ??
        () => LearningAuthScope(
          owner: owner,
          generation: generation,
          ready: true,
        ),
    backendOwner: backendOwner ?? () => owner,
    transitions: LearningTransitionEngine(LearningRegistry.french()),
    clock: () => DateTime.utc(2026),
    newToken: () =>
        'AAAAAAAAAAAAAAAAAAAA${(++_tokenCounter).toRadixString(16).padLeft(2, '0')}',
    random: Random(1),
    cloud: transport,
    onCommitted: onCommitted,
  );

  Future<int> _scopeId(
    LearningDatabase db,
    SqliteCourseLearningRepository repository,
  ) async {
    final owner = repository.scope.owner;
    final row = await db
        .customSelect(
          'SELECT id FROM learning_scopes '
          'WHERE owner_kind = ? AND owner_id = ? AND course_id = ? AND family = ?',
          variables: [
            Variable<String>(owner.isGuest ? 'guest' : 'account'),
            Variable<String>(owner.userId ?? ''),
            Variable<String>(repository.scope.courseId),
            const Variable<String>('course'),
          ],
        )
        .getSingle();
    return row.read<int>('id');
  }

  Future<void> seedPending(
    SqliteCourseLearningRepository repository,
    List<SupportedCloudEvent> events,
  ) async {
    if (events.isEmpty) return;
    final db = await database.open();
    final state = await repository.load();
    final scopeId = await _scopeId(db, repository);
    final ordinal = state.commitOrdinal + 1;
    await db.customStatement(
      'UPDATE learning_scopes SET revision = ?, commit_ordinal = ? WHERE id = ?',
      [ordinal, ordinal, scopeId],
    );
    for (var index = 0; index < events.length; index++) {
      final event = events[index];
      await insertRow(db, 'supported_sync_outbox', <String, Object?>{
        'scope_id': scopeId,
        'event_id': event.id,
        'enqueue_commit_ordinal': ordinal,
        'enqueue_event_index': index,
        'user_id': event.userId,
        'course_id': event.courseId,
        ...switch (event.payload) {
          CloudAnswer(
            :final sound,
            :final skill,
            :final correct,
            :final activity,
          ) =>
            {
              'kind': 'answer',
              'sound': sound,
              'skill': skill.name,
              'correct': correct ? 1 : 0,
              'activity': activity,
              'lesson_id': null,
              'game': null,
              'score': null,
            },
          CloudLesson(:final lessonId) => {
            'kind': 'lesson',
            'sound': null,
            'skill': null,
            'correct': null,
            'activity': null,
            'lesson_id': lessonId,
            'game': null,
            'score': null,
          },
          CloudScore(:final game, :final score) => {
            'kind': 'score',
            'sound': null,
            'skill': null,
            'correct': null,
            'activity': null,
            'lesson_id': null,
            'game': game,
            'score': score,
          },
        },
      });
    }
  }

  Future<void> rejectNextOutboxInsert() async {
    final db = await database.open();
    await db.customStatement('''
      CREATE TRIGGER task10_sync_reject_outbox_insert
      BEFORE INSERT ON supported_sync_outbox
      BEGIN SELECT RAISE(ABORT, 'task10 sync test insert failure'); END
    ''');
  }

  Future<void> rejectOutboxDelete() async {
    final db = await database.open();
    await db.customStatement('''
      CREATE TRIGGER task10_sync_reject_outbox_delete
      BEFORE DELETE ON supported_sync_outbox
      BEGIN SELECT RAISE(ABORT, 'task10 sync test ack failure'); END
    ''');
  }

  Future<void> clearFailures() async {
    final db = await database.open();
    await db.customStatement(
      'DROP TRIGGER IF EXISTS task10_sync_reject_outbox_insert',
    );
    await db.customStatement(
      'DROP TRIGGER IF EXISTS task10_sync_reject_outbox_delete',
    );
  }

  Future<int> outboxCount(SqliteCourseLearningRepository repository) async {
    final db = await database.open();
    final scopeId = await _scopeId(db, repository);
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS row_count FROM supported_sync_outbox '
          'WHERE scope_id = ?',
          variables: [Variable<int>(scopeId)],
        )
        .getSingle();
    return row.read<int>('row_count');
  }

  Future<void> dispose() async {
    await database.close();
    if (directory.existsSync()) await directory.delete(recursive: true);
  }
}

SupportedCloudEvent _event(LearningOwner owner, int index) =>
    SupportedCloudEvent(
      id: 'event-$index',
      userId: owner.userId!,
      courseId: 'en-fr',
      payload: CloudAnswer(
        sound: 'u',
        skill: LearningSkill.listening,
        correct: true,
        activity: 'lesson:en-fr-u-y',
      ),
    );

void main() {
  final owner = LearningOwner.account('sync-user');

  test('offline guest learning requires no backend', () async {
    final fixture = _SyncFixture();
    final guest = LearningOwner.guest();
    final store = fixture.repository(owner: guest, transport: null);

    expect((await store.load()).pending, isEmpty);
    expect((await store.sync()).status, SupportedSyncStatus.guest);
    expect(await fixture.outboxCount(store), 0);
  });

  test(
    'account sync ignores and preserves literal legacy preference data',
    () async {
      const oldCourseKey = 'course.v1.en-fr';
      const oldArcadeKey = 'arcade.v1.en-fr.sound';
      const oldCourse =
          '{"lessons":["en-fr-u-y"],"pending":[{"id":"legacy-outbox-event-7"}]}';
      const oldArcade = '{"session":{"remaining":17,"score":91}}';
      SharedPreferences.setMockInitialValues({
        oldCourseKey: oldCourse,
        oldArcadeKey: oldArcade,
        'profile.name': 'keep-profile',
      });
      final preferences = await SharedPreferences.getInstance();
      final fixture = _SyncFixture();
      final transport = _RecordingTransport();
      final store = fixture.repository(owner: owner, transport: transport);

      expect((await store.load()).pending, isEmpty);
      expect((await store.sync()).status, SupportedSyncStatus.synced);
      expect(transport.batches, isEmpty);
      await fixture.seedPending(store, [_event(owner, 7)]);
      final synced = await store.sync();
      expect(synced.status, SupportedSyncStatus.synced);
      final sentIds = transport.batches.expand(
        (batch) => batch.map((e) => e.id),
      );
      expect(sentIds, ['event-7']);
      expect(sentIds, isNot(contains('legacy-outbox-event-7')));
      expect(preferences.getString(oldCourseKey), oldCourse);
      expect(preferences.getString(oldArcadeKey), oldArcade);
      expect(preferences.getString('profile.name'), 'keep-profile');
    },
  );

  test('201 committed events deliver in batches of at most 100', () async {
    final fixture = _SyncFixture();
    final transport = _RecordingTransport();
    final store = fixture.repository(owner: owner, transport: transport);
    await fixture.seedPending(
      store,
      List.generate(201, (i) => _event(owner, i)),
    );

    final result = await store.sync();

    expect(transport.batches.map((batch) => batch.length), [100, 100, 1]);
    expect(result.status, SupportedSyncStatus.synced);
    expect(result.remainingEvents, 0);
    expect((await store.load()).pending, isEmpty);
    expect(await fixture.outboxCount(store), 0);
  });

  test('failed send retains stable pending ids for retry', () async {
    final fixture = _SyncFixture();
    final transport = _RecordingTransport()..failure = StateError('offline');
    final store = fixture.repository(owner: owner, transport: transport);
    await fixture.seedPending(store, [_event(owner, 1), _event(owner, 2)]);

    final failed = await store.sync();
    expect(failed.status, SupportedSyncStatus.pending);
    expect(failed.remainingEvents, 2);
    expect((await store.load()).pending.map((event) => event.id), [
      'event-1',
      'event-2',
    ]);

    transport.failure = null;
    final retry = await store.sync();
    expect(transport.batches.last.map((event) => event.id), [
      'event-1',
      'event-2',
    ]);
    expect(retry.remainingEvents, 0);
  });

  test(
    'cloud ACK advances revision only and does not notify commit observers',
    () async {
      final fixture = _SyncFixture();
      final transport = _RecordingTransport();
      var notifications = 0;
      final store = fixture.repository(
        owner: owner,
        transport: transport,
        onCommitted: () => notifications++,
      );
      await fixture.seedPending(store, [_event(owner, 41)]);
      final before = await store.load();

      final result = await store.sync();
      final acknowledged = await store.load();

      expect(result.status, SupportedSyncStatus.synced);
      expect(acknowledged.pending, isEmpty);
      expect(acknowledged.revision, before.revision + 1);
      expect(acknowledged.commitOrdinal, before.commitOrdinal);
      expect(acknowledged.history, isEmpty);
      expect(acknowledged.activities, isEmpty);
      expect(notifications, 0);
    },
  );

  test(
    'send failure reports events committed while transport was held',
    () async {
      final fixture = _SyncFixture();
      final transport = _RecordingTransport()
        ..entered = Completer<void>()
        ..release = Completer<void>()
        ..failure = StateError('transport disconnected');
      final store = fixture.repository(owner: owner, transport: transport);
      await fixture.seedPending(store, [_event(owner, 1)]);

      final syncing = store.sync();
      await transport.entered!.future;
      await fixture.seedPending(store, [_event(owner, 2)]);
      transport.release!.complete();

      final result = await syncing;
      expect(result.status, SupportedSyncStatus.pending);
      expect(result.remainingEvents, 2);
      expect(transport.batches, hasLength(1));
      expect((await store.load()).pending.map((event) => event.id), [
        'event-1',
        'event-2',
      ]);
      transport.failure = null;
      expect((await store.sync()).status, SupportedSyncStatus.synced);
    },
  );

  test('failed SQL ACK rolls back and retries the same event id', () async {
    final fixture = _SyncFixture();
    final transport = _RecordingTransport();
    final store = fixture.repository(owner: owner, transport: transport);
    await fixture.seedPending(store, [_event(owner, 9)]);
    await fixture.rejectOutboxDelete();

    final failed = await store.sync();
    expect(failed.status, SupportedSyncStatus.pending);
    expect(failed.remainingEvents, 1);
    expect((await store.load()).pending.single.id, 'event-9');
    expect(await fixture.outboxCount(store), 1);

    await fixture.clearFailures();
    final retry = await store.sync();
    expect(transport.batches.map((batch) => batch.single.id), [
      'event-9',
      'event-9',
    ]);
    expect(retry.remainingEvents, 0);
    expect(await fixture.outboxCount(store), 0);
  });

  test('failed local candidate never reaches transport', () async {
    final fixture = _SyncFixture();
    final transport = _RecordingTransport();
    final store = fixture.repository(owner: owner, transport: transport);
    var state = await store.load();
    state = (await store.submit(
      store.prepare(
        state: state,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()),
      ),
    )).state;
    final item = LearningRegistry.french()
        .require('lesson:en-fr-u-y')
        .items
        .first;
    final answer = store.prepare(
      state: state,
      activityId: 'lesson:en-fr-u-y',
      action: ChooseSound(
        selectedSound: item.expectedChoice!,
        audioSource: AttemptAudioSource.pendingRecording,
      ),
    );
    await fixture.rejectNextOutboxInsert();

    await expectLater(
      store.submit(answer),
      throwsA(isA<LearningSaveException>()),
    );
    final result = await store.sync();
    expect(transport.batches, isEmpty);
    expect(result.remainingEvents, 0);
    expect(await fixture.outboxCount(store), 0);
    await fixture.clearFailures();
  });

  test('same-scope event committed during send survives first ACK', () async {
    final fixture = _SyncFixture();
    final transport = _RecordingTransport()
      ..entered = Completer<void>()
      ..release = Completer<void>();
    final store = fixture.repository(owner: owner, transport: transport);
    await fixture.seedPending(store, [_event(owner, 1)]);

    final syncing = store.sync();
    await transport.entered!.future;
    await fixture.seedPending(store, [_event(owner, 2)]);
    transport.release!.complete();

    final result = await syncing;
    expect(result.remainingEvents, 1);
    expect((await store.load()).pending.map((event) => event.id), ['event-2']);
  });

  test(
    'failed SQL ACK preserves the latest count and retries both event ids',
    () async {
      final fixture = _SyncFixture();
      final transport = _RecordingTransport()
        ..entered = Completer<void>()
        ..release = Completer<void>();
      final store = fixture.repository(owner: owner, transport: transport);
      await fixture.seedPending(store, [_event(owner, 1)]);

      final syncing = store.sync();
      await transport.entered!.future;
      await fixture.seedPending(store, [_event(owner, 2)]);
      await fixture.rejectOutboxDelete();
      transport.release!.complete();

      final failed = await syncing;
      expect(failed.status, SupportedSyncStatus.pending);
      expect(failed.remainingEvents, 2);
      expect(await fixture.outboxCount(store), 2);
      expect((await store.load()).pending.map((event) => event.id), [
        'event-1',
        'event-2',
      ]);

      await fixture.clearFailures();
      transport
        ..entered = null
        ..release = null;
      final retry = await store.sync();
      expect(transport.batches.last.map((event) => event.id), [
        'event-1',
        'event-2',
      ]);
      expect(retry.status, SupportedSyncStatus.synced);
      expect(retry.remainingEvents, 0);
      expect(await fixture.outboxCount(store), 0);
    },
  );

  test(
    'sync coalesces same scope but isolates guest and another account',
    () async {
      final fixture = _SyncFixture();
      final otherOwner = LearningOwner.account('another-user');
      final transport = _RecordingTransport()
        ..entered = Completer<void>()
        ..release = Completer<void>();
      final first = fixture.repository(owner: owner, transport: transport);
      final peer = fixture.repository(owner: owner, transport: transport);
      final other = fixture.repository(owner: otherOwner, transport: transport);
      final guest = fixture.repository(
        owner: LearningOwner.guest(),
        transport: transport,
      );
      await fixture.seedPending(first, [_event(owner, 10)]);
      await fixture.seedPending(other, [
        SupportedCloudEvent(
          id: 'other-event',
          userId: otherOwner.userId!,
          courseId: 'en-fr',
          payload: CloudAnswer(
            sound: 'u',
            skill: LearningSkill.listening,
            correct: true,
            activity: 'lesson:en-fr-u-y',
          ),
        ),
      ]);

      final firstSync = first.sync();
      await transport.entered!.future;
      final peerSync = peer.sync();
      final otherSync = other.sync();
      expect((await guest.sync()).status, SupportedSyncStatus.guest);
      await Future<void>.delayed(Duration.zero);
      expect(transport.batches, hasLength(2));
      expect(
        transport.batches.map((batch) => batch.single.id),
        containsAll(['event-10', 'other-event']),
      );
      transport.release!.complete();
      await Future.wait([firstSync, peerSync, otherSync]);
    },
  );

  test(
    'auth change prevents later batches and leaves all events pending',
    () async {
      var currentOwner = owner;
      var generation = 0;
      final pending = List<SupportedCloudEvent>.generate(
        201,
        (index) => _event(owner, index),
      );
      LearningAuthScope currentAuth() => LearningAuthScope(
        owner: currentOwner,
        generation: generation,
        ready: true,
      );
      final transport = _RecordingTransport()
        ..entered = Completer<void>()
        ..release = Completer<void>();
      final sync = SupportedProgressSync(
        scope: LearningScope(courseId: 'en-fr', owner: owner),
        authGeneration: generation,
        transport: transport,
        readPending: () async => List.unmodifiable(pending),
        acknowledge: (ids) async =>
            pending.removeWhere((event) => ids.contains(event.id)),
        isCurrent: () =>
            currentAuth().ready &&
            currentAuth().owner == owner &&
            currentAuth().generation == 0,
      );

      final syncing = sync.run();
      await transport.entered!.future;
      currentOwner = LearningOwner.account('other');
      generation++;
      transport.release!.complete();

      final result = await syncing;
      expect(result.status, SupportedSyncStatus.ownerChanged);
      expect(transport.batches, hasLength(1));
      expect(result.remainingEvents, 201);
      expect(pending, hasLength(201));
    },
  );

  test(
    'A to B to A during send cannot revive the captured generation',
    () async {
      var currentOwner = owner;
      var generation = 20;
      final pending = <SupportedCloudEvent>[_event(owner, 3)];
      LearningAuthScope currentAuth() => LearningAuthScope(
        owner: currentOwner,
        generation: generation,
        ready: true,
      );
      final transport = _RecordingTransport()
        ..entered = Completer<void>()
        ..release = Completer<void>();
      final sync = SupportedProgressSync(
        scope: LearningScope(courseId: 'en-fr', owner: owner),
        authGeneration: generation,
        transport: transport,
        readPending: () async => List.unmodifiable(pending),
        acknowledge: (ids) async =>
            pending.removeWhere((event) => ids.contains(event.id)),
        isCurrent: () =>
            currentAuth().ready &&
            currentAuth().owner == owner &&
            currentAuth().generation == 20,
      );

      final syncing = sync.run();
      await transport.entered!.future;
      generation++;
      currentOwner = LearningOwner.account('other');
      generation++;
      currentOwner = owner;
      transport.release!.complete();

      final result = await syncing;
      expect(result.status, SupportedSyncStatus.ownerChanged);
      expect(result.remainingEvents, 1);
      expect(pending, hasLength(1));
    },
  );

  test('legacy RPC adapter sends exact event wire payload', () async {
    final received = <Map<String, dynamic>>[];
    final client = SupabaseClient(
      'https://course.example.invalid',
      'public-test-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/record_course_events');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys, ['events']);
        received.addAll((body['events'] as List).cast<Map<String, dynamic>>());
        return http.Response('', 204, request: request);
      }),
    );
    addTearDown(client.dispose);

    await SupabaseLearningCloudTransport(client).send([_event(owner, 7)]);

    expect(received.single, {
      'id': 'event-7',
      'user_id': 'sync-user',
      'course_id': 'en-fr',
      'kind': 'answer',
      'sound': 'u',
      'skill': 'listening',
      'correct': true,
      'activity': 'lesson:en-fr-u-y',
    });
  });
}
