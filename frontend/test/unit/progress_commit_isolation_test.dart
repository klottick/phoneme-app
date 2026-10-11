import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/course/course_progress.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regression suite for F1: public reads and outbox delivery must expose
/// only committed preferences documents, even while a platform write is
/// in flight (the shared_preferences package updates its in-process cache
/// before the platform write resolves).
const String lessonId = 'en-fr-u-y';
const String accountUserId = '10000000-0000-4000-8000-000000000001';

/// In-memory preferences platform that can hold its first platform write
/// mid-flight and then release it as success, clean failure, or a throw.
///
/// The real SharedPreferences singleton still applies its optimistic
/// in-process cache update before [setValue] resolves, so holding a write
/// here models the production interleaving exactly.
class HeldWritePrefs extends InMemorySharedPreferencesStore {
  HeldWritePrefs() : super.withData({});

  Completer<void>? _entered;
  Completer<bool>? _gate;
  bool holding = false;
  int heldWrites = 0;

  void beginHold() {
    holding = true;
    _entered = Completer<void>();
    _gate = Completer<bool>();
  }

  /// Resolves the held write. [persist] true commits it; false rejects it.
  void release({bool persist = true}) {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) {
      gate.complete(persist);
    }
    holding = false;
    _entered = null;
    _gate = null;
  }

  /// Resolves the held write with an error (platform write throws).
  void releaseWith(Object error) {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) {
      gate.completeError(error);
    }
    holding = false;
    _entered = null;
    _gate = null;
  }

  /// Completes once a platform write has entered the hold.
  Future<void> get entered {
    final gate = _entered;
    if (gate != null) {
      return gate.future;
    }
    return Future<void>.value();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (holding) {
      heldWrites += 1;
      final entered = _entered;
      if (entered != null && !entered.isCompleted) {
        entered.complete();
      }
      final bool persist = await _gate!.future; // May complete with an error.
      if (!persist) {
        return false;
      }
      return super.setValue(valueType, key, value);
    }
    return super.setValue(valueType, key, value);
  }
}

LessonSectionSession freshSection(String sessionId) => LessonSectionSession(
    itemIds: frenchUySection.items.map((item) => item.id).toList(),
    sessionId: sessionId);

SupabaseClient signedInUploadClient(List<String> uploadedIds,
    {Completer<void>? firstUpload}) {
  final token = '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
      '${base64Url.encode(utf8.encode(jsonEncode({
        'sub': accountUserId,
        'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
      })))}.signature';
  return SupabaseClient('https://course.example.invalid', 'public-test-key',
      httpClient: MockClient((request) async {
    if (request.url.path.endsWith('/token')) {
      return http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'test-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': accountUserId,
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z'
            },
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'});
    }
    expect(request.url.path, '/rest/v1/rpc/record_course_events');
    if (firstUpload != null && !firstUpload.isCompleted) {
      firstUpload.complete();
    }
    final events = (jsonDecode(request.body) as Map)['events'] as List;
    for (final event in events) {
      uploadedIds.add((event as Map)['id'] as String);
    }
    return http.Response('', 204, request: request);
  }));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    courseBackend = null;
  });

  group('committed-only section reads', () {
    test('load waits out an in-flight write and returns the committed state '
        'after a rejection', () async {
      final prefs = HeldWritePrefs();
      SharedPreferencesStorePlatform.instance = prefs;
      SharedPreferences.resetStatic();
      addTearDown(() async {
        SharedPreferences.setMockInitialValues({});
      });

      final store = CourseProgressStore(frenchCourse.id);
      final session = freshSection('held-read');
      await store.saveLessonSection(lessonId, session.toJson());
      session.submit(true);

      prefs.beginHold();
      final pendingWrite = store.recordLessonSectionAnswer(
          lessonId, session.toJson(), sound: 'u', correct: true);
      // Verify the actual held write entry before reading: the write is
      // genuinely in flight, not a timed race.
      await prefs.entered;
      expect(prefs.heldWrites, greaterThan(0));

      final loaded =
          store.loadLessonSection(lessonId); // Must wait for the write.
      prefs.release(persist: false);
      await expectLater(pendingWrite, throwsStateError);

      final checkpoint = (await loaded)!;
      expect(checkpoint['attemptCount'], 0,
          reason: 'a same-process read surfaced the '
              'platform-rejected optimistic answer');
      expect((checkpoint['latestAnswers'] as Map), isEmpty);
      final data = await store.load();
      expect((data['evidence'] as Map), isEmpty);
    });

    test('load waiting on an in-flight write returns the committed state '
        'after a delayed success', () async {
      final prefs = HeldWritePrefs();
      SharedPreferencesStorePlatform.instance = prefs;
      SharedPreferences.resetStatic();
      addTearDown(() async {
        SharedPreferences.setMockInitialValues({});
      });

      final store = CourseProgressStore(frenchCourse.id);
      final session = freshSection('held-success');
      await store.saveLessonSection(lessonId, session.toJson());
      session.submit(true);

      prefs.beginHold();
      final pendingWrite = store.recordLessonSectionAnswer(
          lessonId, session.toJson(), sound: 'u', correct: true);
      await prefs.entered;
      expect(prefs.heldWrites, greaterThan(0));

      final loaded = store.loadLessonSection(lessonId);
      prefs.release(persist: true);
      await pendingWrite;

      final checkpoint = (await loaded)!;
      expect(checkpoint['attemptCount'], 1);
      expect((checkpoint['latestAnswers'] as Map)['tout'], isTrue);
      final data = await store.load();
      expect((data['evidence']['listening:u'] as Map)['attempts'], 1);
    });

    test('an in-flight write that throws still leaves readers on the '
        'last committed state', () async {
      final prefs = HeldWritePrefs();
      SharedPreferencesStorePlatform.instance = prefs;
      SharedPreferences.resetStatic();
      addTearDown(() async {
        SharedPreferences.setMockInitialValues({});
      });

      final store = CourseProgressStore(frenchCourse.id);
      final session = freshSection('held-throw');
      await store.saveLessonSection(lessonId, session.toJson());
      session.submit(true);

      prefs.beginHold();
      final pendingWrite = store.recordLessonSectionAnswer(
          lessonId, session.toJson(), sound: 'u', correct: true);
      await prefs.entered;
      expect(prefs.heldWrites, greaterThan(0));

      final loaded = store.loadLessonSection(lessonId);
      prefs.releaseWith(StateError('platform write failed'));
      await expectLater(pendingWrite, throwsStateError);

      final checkpoint = (await loaded)!;
      expect(checkpoint['attemptCount'], 0,
          reason: 'a read must not surface an answer whose platform '
              'write threw');
      expect((await store.load())['evidence'], isEmpty);
    });

    test('a write queued by a second store is based on the first store\'s '
        'repaired state', () async {
      final prefs = HeldWritePrefs();
      SharedPreferencesStorePlatform.instance = prefs;
      SharedPreferences.resetStatic();
      addTearDown(() async {
        SharedPreferences.setMockInitialValues({});
      });

      final storeA = CourseProgressStore(frenchCourse.id);
      final storeB = CourseProgressStore(frenchCourse.id);
      final session = freshSection('cross-store');
      await storeA.saveLessonSection(lessonId, session.toJson());
      session.submit(true);

      prefs.beginHold();
      final writeA = storeA.recordLessonSectionAnswer(
          lessonId, session.toJson(), sound: 'u', correct: true);
      await prefs.entered;
      expect(prefs.heldWrites, greaterThan(0));

      // Queued behind store A's in-flight write on the shared writer.
      final writeB = storeB.saveScore('arcade', 42);
      prefs.release(persist: false);
      await expectLater(writeA, throwsStateError);
      await writeB;

      final data = await storeB.load();
      expect((data['scores'] as Map)['arcade'], 42);
      expect((data['evidence'] as Map), isEmpty,
          reason: 'a queued writer must not resurrect the rejected '
              'optimistic answer of another instance');
      expect((data['sections'][lessonId]['checkpoint'] as Map)['attemptCount'],
          0);
    });
  });

  group('committed-only outbox delivery', () {
    test('sync never uploads an in-flight outbox entry; retry yields one '
        'unique cloud event', () async {
      final uploadedIds = <String>[];
      final firstUpload = Completer<void>();
      final client = signedInUploadClient(uploadedIds, firstUpload: firstUpload);
      await client.auth.signInWithPassword(
          email: 'test@example.invalid', password: 'test');
      courseBackend = client;
      final prefs = HeldWritePrefs();
      SharedPreferencesStorePlatform.instance = prefs;
      SharedPreferences.resetStatic();
      addTearDown(() async {
        courseBackend = null;
        await client.dispose();
        SharedPreferences.setMockInitialValues({});
      });

      final store = CourseProgressStore(frenchCourse.id);
      final session = freshSection('sync-race');
      await store.saveLessonSection(lessonId, session.toJson());
      session.submit(true);

      prefs.beginHold();
      final pendingAnswer = store.recordLessonSectionAnswer(
          lessonId, session.toJson(), sound: 'u', correct: true);
      // Verify the actual held write entry before asserting sync discipline.
      await prefs.entered;
      expect(prefs.heldWrites, greaterThan(0));
      addTearDown(() {
        if (prefs.holding) {
          prefs.release(persist: false);
        }
      });

      // Sync starts while the answer write is still in flight.
      final racingSync = store.sync();
      // Let a buggy (uncoordinated) delivery get a chance to read the
      // optimistic outbox and dispatch it before we assert. The fixed
      // implementation structurally cannot: its read waits for the write.
      Object? earlyFailure;
      try {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(firstUpload.isCompleted, isFalse,
            reason: 'sync delivered an outbox captured from an in-flight '
                'write');
        expect(uploadedIds, isEmpty);
      } catch (error) {
        earlyFailure = error;
      } finally {
        prefs.release(persist: false);
      }

      // Release the held write as a failure and let it settle first.
      await expectLater(pendingAnswer, throwsStateError);
      await racingSync;
      if (earlyFailure != null) {
        throw earlyFailure is TestFailure
            ? earlyFailure
            : StateError('early failure: $earlyFailure');
      }
      expect(uploadedIds, isEmpty,
          reason: 'the rejected local write must never reach the cloud');
      expect((await store.load())['evidence'], isEmpty,
          reason: 'the local attempt is absent after the rejection');

      // Retry the same answer: exactly one local attempt and exactly one
      // unique cloud event id.
      await store.recordLessonSectionAnswer(
          lessonId, session.toJson(), sound: 'u', correct: true);
      await store.sync();
      expect(uploadedIds, hasLength(1));
      expect(uploadedIds.toSet(), hasLength(1),
          reason: 'one local attempt is one unique cloud event id '
              '(server ID deduplication cannot merge two distinct ids)');
      final data = await store.load();
      expect((data['evidence']['listening:u'] as Map)['attempts'], 1);
    });

    test('an in-flight sync does not hold the persistence writer', () async {
      final uploadGate = Completer<void>();
      var uploads = 0;
      final token = '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
          '${base64Url.encode(utf8.encode(jsonEncode({
            'sub': accountUserId,
            'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
          })))}.signature';
      final client = SupabaseClient('https://course.example.invalid',
          'public-test-key',
          httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          return http.Response(
              jsonEncode({
                'access_token': token,
                'refresh_token': 'test-refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': {
                  'id': accountUserId,
                  'aud': 'authenticated',
                  'app_metadata': {},
                  'user_metadata': {},
                  'created_at': '2026-01-01T00:00:00Z'
                },
              }),
              200,
              request: request,
              headers: {'content-type': 'application/json'});
        }
        uploads += 1;
        await uploadGate.future;
        return http.Response('', 204, request: request);
      }));
      await client.auth.signInWithPassword(
          email: 'test@example.invalid', password: 'test');
      courseBackend = client;
      final prefs = HeldWritePrefs();
      SharedPreferencesStorePlatform.instance = prefs;
      SharedPreferences.resetStatic();
      addTearDown(() async {
        if (!uploadGate.isCompleted) {
          uploadGate.complete();
        }
        courseBackend = null;
        await client.dispose();
        SharedPreferences.setMockInitialValues({});
      });

      final store = CourseProgressStore(frenchCourse.id);
      // Queues one answer event and starts a sync that hangs on the network.
      final session = freshSection('net-isolation');
      await store.saveLessonSection(lessonId, session.toJson());
      session.submit(true);
      await store.recordLessonSectionAnswer(
          lessonId, session.toJson(), sound: 'u', correct: true);
      final hangingSync = store.sync();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(uploads, greaterThan(0), reason: 'sync must have started');

      // A local write must complete while the backend delivery is pending.
      var written = false;
      final localWrite =
          store.saveScore('arcade', 7).then((_) => written = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(written, isTrue,
          reason: 'the persistence writer must not be held while waiting '
              'on backend network delivery');
      await localWrite;
      expect(((await store.load())['scores'] as Map)['arcade'], 7);

      uploadGate.complete();
      await hangingSync;
      final data = await store.load();
      expect((data['scores'] as Map)['arcade'], 7);
    });
  });
}
