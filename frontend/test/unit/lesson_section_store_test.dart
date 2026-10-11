import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/course/course_progress.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/lesson_section_store.dart';
import 'package:linguist/src/core/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String lessonId = 'en-fr-u-y';
const String accountUserId = '10000000-0000-4000-8000-000000000001';

/// In-memory preferences platform with controllable write failures and a
/// gate that can hold any read/write mid-flight.
class _FakePrefs extends SharedPreferencesStorePlatform {
  final Map<String, Object> data = <String, Object>{};
  bool failWrites = false;
  Completer<void>? hold;
  int gateWaits = 0;

  @override
  Future<bool> remove(String key) async => data.remove(key) != null;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final gate = hold;
    if (gate != null) {
      gateWaits += 1;
      await gate.future;
    }
    if (failWrites) {
      return false;
    }
    data[key] = value;
    return true;
  }

  @override
  Future<bool> clear() async {
    data.clear();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async {
    final gate = hold;
    if (gate != null) {
      gateWaits += 1;
      await gate.future;
    }
    return Map<String, Object>.of(data);
  }
}

/// An offline signed-in backend: token exchange succeeds, delivery fails.
Future<SupabaseClient> signedInClient() async {
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
    return http.Response('{"message":"offline"}', 503, request: request);
  }));
  await client.auth.signInWithPassword(
      email: 'test@example.invalid', password: 'test-password');
  return client;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakePrefs prefs;

  setUp(() {
    prefs = _FakePrefs();
    SharedPreferencesStorePlatform.instance = prefs;
    SharedPreferences.resetStatic();
    courseBackend = null;
  });

  List<String> itemIds() =>
      frenchUySection.items.map((item) => item.id).toList();

  LessonSectionSession fresh({String sessionId = 'session-a'}) =>
      LessonSectionSession(itemIds: itemIds(), sessionId: sessionId);

  LessonSectionSession cloneOf(LessonSectionSession session) =>
      LessonSectionSession.fromJson(
        session.toJson(),
        itemIds: itemIds(),
        contentRevision: frenchUySection.contentRevision,
      );

  String soundOf(String itemId) => frenchUySection.items
      .firstWhere((item) => item.id == itemId)
      .expectedSound;

  CourseProgressStore progressStore() => CourseProgressStore(frenchCourse.id);

  /// Saves [fresh] and then drives [outcomes] through the store's
  /// record/save transitions, returning the last saved state.
  Future<LessonSectionSession> runFirstPass(
    CourseProgressStore store,
    List<bool> outcomes, {
    String sessionId = 'session-a',
  }) async {
    final started = fresh(sessionId: sessionId);
    await store.saveLessonSection(lessonId, started.toJson());
    var current = started;
    for (final correct in outcomes) {
      final answered = cloneOf(current)..submit(correct);
      await store.recordLessonSectionAnswer(
        lessonId,
        answered.toJson(),
        sound: soundOf(answered.currentItemId!),
        correct: correct,
      );
      current = cloneOf(answered)..advance();
      await store.saveLessonSection(lessonId, current.toJson());
    }
    return current;
  }

  group('initial save and load', () {
    test('stores the exact snapshot and preserves legacy plus unknown keys',
        () async {
      prefs.data['flutter.course.v1.${frenchCourse.id}'] = jsonEncode({
        'lessons': ['en-fr-vowels'],
        'evidence': {
          'listening:i': {
            'sound': 'i',
            'skill': 'listening',
            'attempts': 3,
            'correct': 2,
            'due': '2026-01-02T00:00:00.000',
          }
        },
        'scores': {'arcade': 55},
        'unknownLegacy': ['kept']
      });
      SharedPreferences.resetStatic();

      final started = fresh(sessionId: 'sess-init');
      final snapshot = Map<String, dynamic>.from(started.toJson());
      await progressStore().saveLessonSection(lessonId, snapshot);

      final data = await progressStore().load();
      expect(data['lessons'], ['en-fr-vowels']);
      expect(
          (data['evidence'] as Map)['listening:i'],
          isA<Map>()
              .having((map) => map['attempts'], 'attempts', 3));
      expect(data['scores'], {'arcade': 55});
      expect(data['unknownLegacy'], ['kept']);

      final entry = (data['sections'] as Map)[lessonId] as Map;
      expect(entry['processedSessionId'], 'sess-init');
      expect(entry['processedAttemptCount'], 0);
      expect(await progressStore().loadLessonSection(lessonId), equals(snapshot));
    });

    test('loads null without state or with garbage stored values', () async {
      expect(await progressStore().loadLessonSection(lessonId), isNull);
      prefs.data['flutter.course.v1.${frenchCourse.id}'] = jsonEncode({
        'lessons': <String>[],
        'evidence': <String, dynamic>{},
        'scores': <String, dynamic>{},
        'sections': {lessonId: {'checkpoint': 'not-a-snapshot'}}
      });
      SharedPreferences.resetStatic();
      expect(await progressStore().loadLessonSection(lessonId), isNull);
    });

    test('writes require a supported section', () async {
      final started = fresh(sessionId: 's');
      await expectLater(
          progressStore().saveLessonSection('en-fr-vowels', started.toJson()),
          throwsArgumentError);
      await expectLater(
          progressStore().recordLessonSectionAnswer('en-fr-vowels', started.toJson(),
              sound: 'u', correct: true),
          throwsArgumentError);
      await expectLater(
          progressStore().completeLessonSection('en-fr-vowels', started.toJson()),
          throwsArgumentError);
      expect(await progressStore().loadLessonSection('en-fr-vowels'), isNull);
      expect(prefs.data.keys, isEmpty);
    });

    test('the first save must be a zero-attempt session', () async {
      final started = fresh(sessionId: 's')..submit(true);
      await expectLater(
          progressStore().saveLessonSection(lessonId, started.toJson()),
          throwsStateError);
      expect(await progressStore().loadLessonSection(lessonId), isNull);
    });
  });

  group('advance and review saves', () {
    test('stores advance and review checkpoints exactly', () async {
      final store = progressStore();
      final outcomes = [true, false, true, true, true, false, true, true, true, true];
      final debrief = await runFirstPass(store, outcomes, sessionId: 'snap');
      expect(await store.loadLessonSection(lessonId), equals(debrief.toJson()));

      final reviewed = cloneOf(debrief)..reviewMistakes();
      await store.saveLessonSection(lessonId, reviewed.toJson());
      expect(await store.loadLessonSection(lessonId), equals(reviewed.toJson()));
      expect((await store.load())['sections'][lessonId]['processedAttemptCount'],
          10);

      final rerun = cloneOf(reviewed)..submit(true); // the first mistake, fixed
      await store.recordLessonSectionAnswer(
          lessonId, rerun.toJson(), sound: soundOf('tu'), correct: true);
      expect(await store.loadLessonSection(lessonId), equals(rerun.toJson()));

      final past = cloneOf(rerun)..advance();
      await store.saveLessonSection(lessonId, past.toJson());
      expect(await store.loadLessonSection(lessonId), equals(past.toJson()));
      expect((await store.load())['sections'][lessonId]['processedAttemptCount'],
          11);
    });

    test('cannot fabricate an unrecorded answer', () async {
      final store = progressStore();
      final started = fresh(sessionId: 'fab');
      await store.saveLessonSection(lessonId, started.toJson());
      final unrecorded = cloneOf(started)..submit(true);
      await expectLater(
          store.saveLessonSection(lessonId, unrecorded.toJson()),
          throwsStateError);
      expect(
          await store.loadLessonSection(lessonId), equals(started.toJson()));
    });

    test('rejects outcome, policy, or session-id changes at unchanged counts',
        () async {
      final store = progressStore();
      final started = fresh(sessionId: 'flip');
      await store.saveLessonSection(lessonId, started.toJson());
      final answered = cloneOf(started)..submit(true);
      await store.recordLessonSectionAnswer(lessonId, answered.toJson(),
          sound: soundOf('tout'), correct: true);

      // Wrong outcome at the same attempt number.
      final flipped = cloneOf(started)..submit(false);
      await expectLater(
          store.saveLessonSection(lessonId, flipped.toJson()),
          throwsStateError);

      // A different policy at the same attempt number.
      final policyShift =
          Map<String, dynamic>.from((await progressStore().loadLessonSection(lessonId))!);
      policyShift['policy'] =
          LessonPolicy(completionThresholdPercent: 40).toJson();
      await expectLater(
          store.saveLessonSection(lessonId, policyShift), throwsStateError);

      // A different session with recorded attempts.
      final otherSession = fresh(sessionId: 'other')..submit(true);
      await expectLater(
          store.saveLessonSection(lessonId, otherSession.toJson()),
          throwsStateError);

      final stored = await store.loadLessonSection(lessonId);
      expect((stored!['latestAnswers'] as Map)['tout'], isTrue);
      expect(
          (stored['policy'] as Map)['completionThresholdPercent'], 80);
    });

    test('a fresh zero-attempt save may replace the saved session', () async {
      final store = progressStore();
      final started = fresh(sessionId: 'old');
      await store.saveLessonSection(lessonId, started.toJson());
      final answered = cloneOf(started)..submit(true);
      await store.recordLessonSectionAnswer(lessonId, answered.toJson(),
          sound: soundOf('tout'), correct: true);

      // A restart under a new session id is a zero-attempt save.
      final restarted = fresh(sessionId: 'fresh');
      await store.saveLessonSection(lessonId, restarted.toJson());
      expect(
          (await progressStore().load())['sections'][lessonId]['processedSessionId'],
          'fresh');

      // Writes from the abandoned session are now stale.
      await expectLater(store.saveLessonSection(
              lessonId, (cloneOf(answered)..advance()).toJson()),
          throwsStateError);
      expect(
          await store.loadLessonSection(lessonId),
          equals(restarted.toJson()));
    });
  });

  group('recorded answers', () {
    test('records one answer exactly once across retries', () async {
      final store = progressStore();
      final started = fresh(sessionId: 'once');
      await store.saveLessonSection(lessonId, started.toJson());
      final answered = cloneOf(started)..submit(true);
      await store.recordLessonSectionAnswer(lessonId, answered.toJson(),
          sound: soundOf('tout'), correct: true);
      // Two retries of the same submitted checkpoint.
      await store.recordLessonSectionAnswer(lessonId, answered.toJson(),
          sound: soundOf('tout'), correct: true);
      await store.recordLessonSectionAnswer(lessonId, answered.toJson(),
          sound: soundOf('tout'), correct: true);

      final data = await store.load();
      expect(
          data['evidence']['listening:u'],
          {
            'sound': 'u',
            'skill': 'listening',
            'attempts': 1,
            'correct': 1,
            'due': isA<String>()
          });
      expect(await store.loadLessonSection(lessonId), equals(answered.toJson()));
      expect((await store.load())['pending'], isNull); // guest: on-device only
    });

    test('an older duplicate cannot revert a newer checkpoint', () async {
      final store = progressStore();
      final started = fresh(sessionId: 'revert');
      await store.saveLessonSection(lessonId, started.toJson());
      final first = cloneOf(started)..submit(true);
      await store.recordLessonSectionAnswer(lessonId, first.toJson(),
          sound: soundOf('tout'), correct: true);
      final past = cloneOf(first)..advance();
      await store.saveLessonSection(lessonId, past.toJson());
      final second = cloneOf(past)..submit(true);
      await store.recordLessonSectionAnswer(lessonId, second.toJson(),
          sound: soundOf('tu'), correct: true);

      // The first attempt again, this time wrong.
      final stale = cloneOf(started)..submit(false);
      await store.recordLessonSectionAnswer(lessonId, stale.toJson(),
          sound: 'u', correct: false);

      final data = await store.load();
      expect((data['evidence']['listening:u'] as Map)['attempts'], 1);
      expect((data['evidence']['listening:y'] as Map)['attempts'], 1);
      final stored = await store.loadLessonSection(lessonId);
      expect((stored!['latestAnswers'] as Map)['tout'], isTrue);
      expect((stored['latestAnswers'] as Map)['tu'], isTrue);
    });

    test('rejects gaps and answer injection into a recorded session', () async {
      final store = progressStore();
      final started = fresh(sessionId: 'gap');
      await store.saveLessonSection(lessonId, started.toJson());
      final first = cloneOf(started)..submit(true);
      await store.recordLessonSectionAnswer(lessonId, first.toJson(),
          sound: soundOf('tout'), correct: true);

      final ahead = cloneOf(first)
        ..advance()
        ..submit(true)
        ..advance()
        ..submit(true);
      await expectLater(store.recordLessonSectionAnswer(
              lessonId, ahead.toJson(), sound: 'u', correct: true),
          throwsStateError);
      expect(((await store.load())['evidence'] as Map)['listening:u'] as Map,
          isA<Map>()
              .having((map) => map['attempts'], 'attempts', 1));
      expect(await store.loadLessonSection(lessonId), equals(first.toJson()));
    });

    test('rejects unsubmitted, wrong-sound, or wrong-correctness saves',
        () async {
      final store = progressStore();
      final started = fresh(sessionId: 'invalid');
      await store.saveLessonSection(lessonId, started.toJson());
      final answered = cloneOf(started)..submit(true);

      await expectLater(store.recordLessonSectionAnswer(
              lessonId, started.toJson(), sound: 'u', correct: true),
          throwsStateError);
      await expectLater(
          store.recordLessonSectionAnswer(
              lessonId, answered.toJson(), sound: 'y', correct: true),
          throwsStateError);
      await expectLater(store.recordLessonSectionAnswer(
              lessonId, answered.toJson(), sound: 'u', correct: false),
          throwsStateError);
      expect(await store.loadLessonSection(lessonId), equals(started.toJson()));
      expect(((await store.load())['evidence'] as Map).keys, isEmpty);
    });

    test('a new session must record from attempt one', () async {
      final store = progressStore();
      final injected = fresh(sessionId: 'inject')
        ..submit(true)
        ..advance()
        ..submit(false)
        ..advance()
        ..submit(true);
      await expectLater(
          store.recordLessonSectionAnswer(
              lessonId, injected.toJson(), sound: 'u', correct: true),
          throwsStateError);
      expect(await store.loadLessonSection(lessonId), isNull);
      expect(((await store.load())['evidence'] as Map).keys, isEmpty);
    });

    test('keeps wrong items unresolved even when the sound is learned',
        () async {
      final store = progressStore();
      final outcomes = [true, false, true, false, true, true, true, true, true, true];
      final debrief = await runFirstPass(store, outcomes, sessionId: 'keep');
      final stored = await store.loadLessonSection(lessonId);
      expect((stored!['latestAnswers'] as Map)['tu'], isFalse);
      expect((stored['latestAnswers'] as Map)['rue'], isFalse);
      expect((stored['latestAnswers'] as Map)['lune'], isTrue);
      expect((stored['latestAnswers'] as Map)['jus'], isTrue);
      final evidence = (await store.load())['evidence'] as Map;
      expect((evidence['listening:y'] as Map)['attempts'], 5);
      expect((evidence['listening:y'] as Map)['correct'], 3);
      expect((evidence['listening:u'] as Map)['attempts'], 5);
      expect((evidence['listening:u'] as Map)['correct'], 5);
      expect(debrief.canComplete, isTrue); // 8 of 10 still passes
    });
  });

  group('completion', () {
    test('completes once and queues the compatible lesson event only once',
        () async {
      final client = await signedInClient();
      courseBackend = client;
      addTearDown(() async {
        courseBackend = null;
        await client.dispose();
      });
      final store = CourseProgressStore(frenchCourse.id);
      final outcomes = [true, false, true, true, true, false, true, true, true, true];
      final debrief = await runFirstPass(store, outcomes, sessionId: 'comp');
      await store.completeLessonSection(lessonId, debrief.toJson());

      var data = await store.load();
      expect((data['lessons'] as List), equals([lessonId]));
      var events = (data['pending'] as List)
          .cast<Map>()
          .where((event) => event['kind'] == 'lesson')
          .toList();
      expect(events, hasLength(1));
      expect(events.single['lesson_id'], lessonId);
      final answers = (data['pending'] as List)
          .cast<Map>()
          .where((event) => event['kind'] == 'answer')
          .toList();
      expect(answers, hasLength(10));

      // Completing again must not double-queue the lesson event.
      await store.completeLessonSection(lessonId, debrief.toJson());
      data = await store.load();
      expect((data['lessons'] as List).where((id) => id == lessonId).length, 1);
      events = (data['pending'] as List)
          .cast<Map>()
          .where((event) => event['kind'] == 'lesson')
          .toList();
      expect(events, hasLength(1));
      expect(await store.loadLessonSection(lessonId), equals(debrief.toJson()));
    });

    test('rejects completion below the threshold without mutating data',
        () async {
      final store = progressStore();
      final debrief = await runFirstPass(
        store,
        [false, false, false, true, true, true, true, true, true, true],
        sessionId: 'fail',
      );
      expect(debrief.canComplete, isFalse);
      await expectLater(
          store.completeLessonSection(lessonId, debrief.toJson()),
          throwsStateError);
      final data = await store.load();
      expect((data['lessons'] as List), isEmpty);
      expect(data['pending'], isNull);
      expect(await store.loadLessonSection(lessonId), equals(debrief.toJson()));
    });

    test('rejects completion without saved progress', () async {
      final store = progressStore();
      final session = fresh(sessionId: 'ghost');
      for (var i = 0; i < itemIds().length; i++) {
        session.submit(true);
        session.advance();
      }
      expect(session.canComplete, isTrue);
      await expectLater(
          store.completeLessonSection(lessonId, session.toJson()),
          throwsStateError);
      final data = await store.load();
      expect((data['lessons'] as List), isEmpty);
      expect(data['sections'], isNull);
    });
  });

  group('accounts', () {
    test('a signed-in answer queues one compatible event per submission',
        () async {
      final client = await signedInClient();
      courseBackend = client;
      addTearDown(() async {
        courseBackend = null;
        await client.dispose();
      });
      final store = CourseProgressStore(frenchCourse.id);
      final started = fresh(sessionId: 'event');
      final answered = cloneOf(started)..submit(true);
      await store.recordLessonSectionAnswer(lessonId, answered.toJson(),
          sound: soundOf('tout'), correct: true);

      final data = await store.load();
      expect(
          data['evidence']['listening:u'],
          {
            'sound': 'u',
            'skill': 'listening',
            'attempts': 1,
            'correct': 1,
            'due': isA<String>()
          });
      final events = (data['pending'] as List)
          .cast<Map>()
          .where((event) => event['kind'] == 'answer')
          .toList();
      expect(events, hasLength(1));
      final event = events.single;
      expect(event['sound'], 'u');
      expect(event['skill'], 'listening');
      expect(event['correct'], isTrue);
      expect(event['activity'], 'discovery-section');
      expect(event['course_id'], frenchCourse.id);
      expect(event['user_id'], accountUserId);
      expect(event.containsKey('checkpoint'), isFalse);
      expect(event.containsKey('recording'), isFalse);
      expect(event.containsKey('audio'), isFalse);
    });

    test('keeps guest and account scopes separate and rejects stale stores',
        () async {
      final guest = CourseProgressStore(frenchCourse.id);
      final guestSession = fresh(sessionId: 'guest-session');
      await guest.saveLessonSection(lessonId, guestSession.toJson());
      final guestAnswered = cloneOf(guestSession)..submit(true);
      await guest.recordLessonSectionAnswer(lessonId, guestAnswered.toJson(),
          sound: soundOf('tout'), correct: true);
      expect(prefs.data.containsKey('flutter.course.v1.${frenchCourse.id}'),
          isTrue);
      expect(
          prefs.data.containsKey(
              'flutter.course.v1.${frenchCourse.id}.$accountUserId'),
          isFalse);

      final client = await signedInClient();
      courseBackend = client;
      addTearDown(() async {
        courseBackend = null;
        await client.dispose();
      });
      final account = CourseProgressStore(frenchCourse.id);
      final accountSession = fresh(sessionId: 'account-session');
      final accountAnswered = cloneOf(accountSession)..submit(true);
      await account.saveLessonSection(lessonId, accountSession.toJson());
      await account.recordLessonSectionAnswer(
          lessonId, accountAnswered.toJson(), sound: soundOf('tout'),
          correct: true);
      expect(
          prefs.data.containsKey(
              'flutter.course.v1.${frenchCourse.id}.$accountUserId'),
          isTrue);

      // Guest scope intact; the captured guest store is now stale.
      expect(await guest.loadLessonSection(lessonId),
          equals(guestAnswered.toJson()));
      await expectLater(guest.saveLessonSection(
              lessonId, (cloneOf(guestAnswered)..advance()).toJson()),
          throwsStateError);
      final guestNext = cloneOf(guestAnswered)..advance()..submit(true);
      await expectLater(
          guest.recordLessonSectionAnswer(
              lessonId, guestNext.toJson(), sound: 'y', correct: true),
          throwsStateError);
      expect(await guest.loadLessonSection(lessonId),
          equals(guestAnswered.toJson()));
      expect(await account.loadLessonSection(lessonId),
          equals(accountAnswered.toJson()));
    });

    test('rejects queued writes from a store whose account signed out',
        () async {
      final client = await signedInClient();
      courseBackend = client;
      addTearDown(() async {
        courseBackend = null;
        await client.dispose();
      });
      final account = CourseProgressStore(frenchCourse.id);
      final started = fresh(sessionId: 'stale');
      final answered = cloneOf(started)..submit(true);

      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) {
          gate.complete();
        }
      });
      prefs.hold = gate;
      final pending = account.recordLessonSectionAnswer(
          lessonId, answered.toJson(), sound: soundOf('tout'), correct: true);
      // Let the in-flight write reach the (held) preferences before the
      // account signs out, so the rejection happens inside the serialized
      // writer, not before it was queued.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(prefs.gateWaits, greaterThan(0));
      try {
        await client.auth.signOut();
      } catch (_) {
        // Offline logout delivery fails, but the local session is already
        // cleared, which is what the store's owner check observes.
      }
      expect(client.auth.currentUser, isNull);
      gate.complete();
      await expectLater(pending, throwsStateError);

      expect(
          prefs.data.containsKey(
              'flutter.course.v1.${frenchCourse.id}.$accountUserId'),
          isFalse);
    });
  });

  group('persistence failures and wiring', () {
    test('a failed preferences write rejects; a retry persists exactly once',
        () async {
      final store = progressStore();
      final started = fresh(sessionId: 'retry');
      final answered = cloneOf(started)..submit(true);
      prefs.failWrites = true;
      await expectLater(store.recordLessonSectionAnswer(
              lessonId, answered.toJson(), sound: soundOf('tout'),
              correct: true),
          throwsStateError);
      // Nothing was persisted by the failed write.
      expect(
          prefs.data.containsKey('flutter.course.v1.${frenchCourse.id}'),
          isFalse);

      // A fresh process sees the pre-failure store; the retry applies once.
      SharedPreferences.resetStatic();
      prefs.failWrites = false;
      await store.recordLessonSectionAnswer(lessonId, answered.toJson(),
          sound: soundOf('tout'), correct: true);
      final data = await store.load();
      expect(
          (data['evidence'] as Map)['listening:u'],
          isA<Map>()
              .having((map) => map['attempts'], 'attempts', 1));
      expect(await store.loadLessonSection(lessonId), equals(answered.toJson()));
      expect(data['pending'], isNull); // guest: no outbox
    });

    test('lessonSectionStoreProvider follows the signed-in account', () async {
      final client = await signedInClient();
      addTearDown(() async {
        courseBackend = null;
        await client.dispose();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final guestStore = container.read(lessonSectionStoreProvider);
      expect(guestStore, isA<LessonSectionStore>());
      expect((guestStore as CourseProgressStore).storageScope,
          frenchCourse.id);

      courseBackend = client;
      container.read(authControllerProvider.notifier).state =
          AppAuthState(user: client.auth.currentUser);
      final accountStore = container.read(lessonSectionStoreProvider);
      expect(identical(accountStore, guestStore), isFalse);
      expect((accountStore as CourseProgressStore).storageScope,
          '${frenchCourse.id}.$accountUserId');
    });

    test('concurrent arcade and section writes all persist', () async {
      final store = progressStore();
      final started = fresh(sessionId: 'concurrent');
      final answered = cloneOf(started)..submit(true);
      await Future.wait<dynamic>([
        for (var i = 0; i < 10; i++) store.record('u', 'listening', true),
        store.saveLessonSection(lessonId, started.toJson()),
        store.recordLessonSectionAnswer(
            lessonId, answered.toJson(), sound: soundOf('tout'),
            correct: true)
      ]);
      final data = await store.load();
      expect((data['evidence']['listening:u'] as Map)['attempts'], 11);
      expect((data['evidence']['listening:u'] as Map)['correct'], 11);
      expect(await store.loadLessonSection(lessonId), equals(answered.toJson()));
    });
  });
}
