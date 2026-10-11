import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/course/course_progress.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/lesson_section_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regression suite for F5: stored entry metadata (processedSessionId,
/// processedAttemptCount) must be validated against the canonical saved
/// checkpoint at load and before save/answer/completion, and a corrupt
/// entry must never cause a new answer to be acknowledged as a duplicate.
const String lessonId = 'en-fr-u-y';
const String accountUserId = '10000000-0000-4000-8000-000000000001';

class _SeedPrefs extends SharedPreferencesStorePlatform {
  final Map<String, Object> data = <String, Object>{};

  @override
  Future<bool> remove(String key) async => data.remove(key) != null;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    data[key] = value;
    return true;
  }

  @override
  Future<bool> clear() async {
    data.clear();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async => Map<String, Object>.of(data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _SeedPrefs prefs;

  setUp(() {
    courseBackend = null;
    final seed = _SeedPrefs();
    SharedPreferencesStorePlatform.instance = seed;
    SharedPreferences.resetStatic();
    prefs = seed;
  });

  void seedEntry(
    Map<String, dynamic> entry, {
    List<String> lessons = const [],
    Map<String, dynamic> evidence = const {},
    Map<String, dynamic> scores = const {},
    Map<String, dynamic> siblings = const {},
    Object? unknown = 'kept-unknown',
  }) {
    prefs.data['flutter.course.v1.${frenchCourse.id}'] = jsonEncode({
      'lessons': lessons,
      'evidence': evidence,
      'scores': scores,
      if (unknown != null) 'unknownLegacy': unknown,
      'sections': <String, dynamic>{
        ...siblings,
        lessonId: entry
      }
    });
    SharedPreferences.resetStatic();
  }

  LessonSectionSession fresh(String sessionId) => LessonSectionSession(
      itemIds: frenchUySection.items.map((item) => item.id).toList(),
      sessionId: sessionId);

  group('corrupt processed metadata is never trusted', () {
    test('an inflated attempt count is recovered, never a silent duplicate',
        () async {
      final session = fresh('metadata');
      seedEntry({
        'checkpoint': session.toJson(),
        'processedSessionId': session.sessionId,
        'processedAttemptCount': 100,
      });
      final store = CourseProgressStore(frenchCourse.id);
      final answered = fresh('metadata')..submit(true);
      await store.recordLessonSectionAnswer(
          lessonId, answered.toJson(), sound: 'u', correct: true);
      final data = await store.load();
      expect((data['evidence']['listening:u'] as Map)['attempts'], 1,
          reason: 'a new answer must be recorded, not acknowledged as an '
              'already-comitted duplicate of an inflated counter');
      final entry = (data['sections'] as Map)[lessonId] as Map;
      expect(entry['processedAttemptCount'], 1);
      expect(entry['processedSessionId'], 'metadata');
    });

    test('a mismatched session id plus inflated count is recovered', () async {
      final session = fresh('metadata2');
      seedEntry({
        'checkpoint': session.toJson(),
        'processedSessionId': 'some-other-session',
        'processedAttemptCount': 100,
      });
      final store = CourseProgressStore(frenchCourse.id);
      final answered = fresh('metadata2')..submit(true);
      await store.recordLessonSectionAnswer(
          lessonId, answered.toJson(), sound: 'u', correct: true);
      final data = await store.load();
      expect((data['evidence']['listening:u'] as Map)['attempts'], 1);
      final entry = (data['sections'] as Map)[lessonId] as Map;
      expect(entry['processedSessionId'], 'metadata2');
      expect(entry['processedAttemptCount'], 1);
    });

    test('a negative attempt count is recovered, not a gap rejection',
        () async {
      final session = fresh('metadata-neg');
      seedEntry({
        'checkpoint': session.toJson(),
        'processedSessionId': session.sessionId,
        'processedAttemptCount': -1,
      });
      final store = CourseProgressStore(frenchCourse.id);
      final answered = fresh('metadata-neg')..submit(true);
      await store.recordLessonSectionAnswer(
          lessonId, answered.toJson(), sound: 'u', correct: true);
      expect(((await store.load())['evidence']['listening:u'] as Map)
              ['attempts'],
          1,
          reason: 'a negative counter must not masquerade as a gap '
              'rejection for a genuinely new answer');
    });

    test('wrong-typed or missing metadata does not block the first answer',
        () async {
      final store = CourseProgressStore(frenchCourse.id);
      for (final Object? count in ['100', 1.5, null]) {
        final session = fresh('metadata-type');
        prefs.data['flutter.course.v1.${frenchCourse.id}'] = jsonEncode({
          'lessons': <String>[],
          'evidence': <String, dynamic>{},
          'scores': <String, dynamic>{},
          'sections': {
            lessonId: {
              'checkpoint': session.toJson(),
              if (count != null) 'processedSessionId': session.sessionId,
              if (count != null) 'processedAttemptCount': count
            }
          }
        });
        SharedPreferences.resetStatic();
        final answered = fresh('metadata-type')..submit(true);
        await store.recordLessonSectionAnswer(
            lessonId, answered.toJson(), sound: 'u', correct: true);
        // The re-seed replaces the whole document, so each recovery records
        // its answer exactly once on a fresh committed state.
        final data = await store.load();
        expect((data['evidence']['listening:u'] as Map)['attempts'], 1);
      }
      final data = await store.load();
      expect((data['evidence']['listening:u'] as Map)['attempts'], 1,
          reason: 'each corrupted entry is recovered by its own next valid '
              'write and recorded exactly once');
    });

    test('recovery does not weaken validation of fabricated progress',
        () async {
      final session = fresh('metadata-gap');
      seedEntry({
        'checkpoint': session.toJson(),
        'processedSessionId': session.sessionId,
        'processedAttemptCount': 100,
      });
      final store = CourseProgressStore(frenchCourse.id);
      final jumped = fresh('metadata-gap')
        ..submit(true)
        ..advance()
        ..submit(true)
        ..advance()
        ..submit(true);
      await expectLater(
          store.recordLessonSectionAnswer(
              lessonId, jumped.toJson(), sound: 'u', correct: true),
          throwsStateError);
      final data = await store.load();
      expect((data['evidence'] as Map), isEmpty,
          reason: 'recovered corruption must not let fabricated progress land');
      expect(prefs.data.containsKey('flutter.course.v1.${frenchCourse.id}'),
          isTrue,
          reason: 'existing data is preserved, not deleted');
      final storedEntry =
          (jsonDecode(prefs.data['flutter.course.v1.${frenchCourse.id}'] as String)
                  as Map)['sections'] as Map;
      expect((storedEntry[lessonId] as Map)['processedAttemptCount'], 100,
          reason: 'a rejected write must not mutate the entry');
    });

    test('a fresh save repairs a corrupt entry and preserves legacy plus '
        'sibling entries', () async {
      final session = fresh('metadata-repair');
      seedEntry(
        {
          'checkpoint': session.toJson(),
          'processedSessionId': 'someone-else',
          'processedAttemptCount': 50,
        },
        lessons: ['en-fr-vowels'],
        evidence: {
          'listening:i': {'sound': 'i', 'attempts': 3, 'correct': 2}
        },
        scores: {'arcade': 55},
        siblings: {
          'other-lesson': {
            'checkpoint': 'kept-sibling',
            'processedSessionId': 'x',
            'processedAttemptCount': 0
          }
        },
      );
      final store = CourseProgressStore(frenchCourse.id);
      final started = fresh('metadata-repair');
      await store.saveLessonSection(lessonId, started.toJson());
      final data = await store.load();
      expect(data['lessons'], ['en-fr-vowels']);
      expect((data['evidence'] as Map)['listening:i'],
          isA<Map>().having((map) => map['attempts'], 'attempts', 3));
      expect((data['scores'] as Map)['arcade'], 55);
      expect(data['unknownLegacy'], 'kept-unknown');
      final sections = data['sections'] as Map;
      expect((sections[lessonId] as Map)['processedSessionId'],
          'metadata-repair');
      expect(sections['other-lesson']['checkpoint'], 'kept-sibling');
    });
  });

  group('load reports unusable entries with the corruption contract', () {
    test('loads null for absent entries and non-snapshot checkpoints',
        () async {
      final store = CourseProgressStore(frenchCourse.id);
      expect(await store.loadLessonSection(lessonId), isNull);
      prefs.data['flutter.course.v1.${frenchCourse.id}'] = jsonEncode({
        'lessons': <String>[],
        'evidence': <String, dynamic>{},
        'scores': <String, dynamic>{},
        'sections': {lessonId: {'checkpoint': 'not-a-snapshot'}}
      });
      SharedPreferences.resetStatic();
      expect(await CourseProgressStore(frenchCourse.id)
          .loadLessonSection(lessonId), isNull);
    });

    for (final (String label, Map<String, dynamic> Function(LessonSectionSession s) entry) in [
      ('an inflated attempt count',
          (s) => {'processedSessionId': s.sessionId, 'processedAttemptCount': 100}),
      ('a mismatched processed session id',
          (s) => {'processedSessionId': 'someone-else', 'processedAttemptCount': 0}),
      ('a wrong-typed attempt count',
          (s) => {'processedSessionId': s.sessionId, 'processedAttemptCount': '0'}),
      ('a negative attempt count',
          (s) => {'processedSessionId': s.sessionId, 'processedAttemptCount': -1}),
      ('missing metadata', (s) => <String, dynamic>{}),
    ]) {
      test('throws FormatException for $label', () async {
        final s = fresh('contract-$label'.replaceAll(' ', '-'));
        seedEntry({'checkpoint': s.toJson(), ...entry(s)});
        final store = CourseProgressStore(frenchCourse.id);
        await expectLater(store.loadLessonSection(lessonId),
            throwsFormatException,
            reason: 'an unusable entry surfaces the same FormatException '
                'contract as an unusable checkpoint');
      });
    }

    test('returns a consistent checkpoint unchanged', () async {
      final s = fresh('contract-ok');
      seedEntry({
        'checkpoint': s.toJson(),
        'processedSessionId': s.sessionId,
        'processedAttemptCount': 0
      });
      final store = CourseProgressStore(frenchCourse.id);
      expect(await store.loadLessonSection(lessonId), equals(s.toJson()));
    });
  });

  group('typed conflicts without weakening validation', () {
    test('LessonSectionConflictException stays a StateError', () {
      expect(LessonSectionConflictException('conflict'), isA<StateError>());
    });

    test('a valid save for a different session is a typed conflict', () async {
      final store = CourseProgressStore(frenchCourse.id);
      final saved = fresh('sess-a');
      await store.saveLessonSection(lessonId, saved.toJson());
      final savedAnswered = fresh('sess-a')..submit(true);
      await store.recordLessonSectionAnswer(
          lessonId, savedAnswered.toJson(), sound: 'u', correct: true);

      final other = fresh('sess-b')..submit(true);
      await expectLater(
          store.saveLessonSection(lessonId, other.toJson()),
          throwsA(isA<LessonSectionConflictException>()));
      // Storage unchanged: the conflicting snapshot is rejected.
      expect(await store.loadLessonSection(lessonId),
          equals(savedAnswered.toJson()));
    });

    test('a valid record for a different session is a typed conflict',
        () async {
      final store = CourseProgressStore(frenchCourse.id);
      final saved = fresh('sess-c');
      await store.saveLessonSection(lessonId, saved.toJson());
      final savedAnswered = fresh('sess-c')..submit(true);
      await store.recordLessonSectionAnswer(
          lessonId, savedAnswered.toJson(), sound: 'u', correct: true);

      final other = fresh('sess-d')..submit(true);
      await expectLater(
          store.recordLessonSectionAnswer(
              lessonId, other.toJson(), sound: 'u', correct: true),
          throwsA(isA<LessonSectionConflictException>()));
      expect(((await store.load())['evidence']['listening:u'] as Map)
              ['attempts'],
          1);
    });

    test('a checkpoint ahead of the stored session is a typed conflict',
        () async {
      final store = CourseProgressStore(frenchCourse.id);
      final saved = fresh('sess-ahead');
      await store.saveLessonSection(lessonId, saved.toJson());
      final savedAnswered = fresh('sess-ahead')..submit(true);
      await store.recordLessonSectionAnswer(
          lessonId, savedAnswered.toJson(), sound: 'u', correct: true);

      // A genuinely new continuation captured before the store advanced.
      final stale = fresh('sess-ahead')
        ..submit(true)
        ..advance()
        ..submit(true)
        ..advance()
        ..submit(true);
      await expectLater(
          store.recordLessonSectionAnswer(
              lessonId, stale.toJson(), sound: 'u', correct: true),
          throwsA(isA<LessonSectionConflictException>()));
      expect(((await store.load())['evidence']['listening:u'] as Map)
              ['attempts'],
          1,
          reason: 'the stale continuation must not be recorded');
    });

    test('a stale save behind the stored session is a typed conflict',
        () async {
      final store = CourseProgressStore(frenchCourse.id);
      final saved = fresh('sess-stale');
      await store.saveLessonSection(lessonId, saved.toJson());
      final savedAnswered = fresh('sess-stale')..submit(true);
      await store.recordLessonSectionAnswer(
          lessonId, savedAnswered.toJson(), sound: 'u', correct: true);

      // An instance that still sees the zero-attempt state saves it again.
      final stale = fresh('sess-stale').toJson();
      await expectLater(
          store.saveLessonSection(lessonId, stale),
          throwsA(isA<LessonSectionConflictException>()));
      expect(await store.loadLessonSection(lessonId),
          equals(savedAnswered.toJson()));
    });

    test('ownership failures are not mislabeled as conflicts', () async {
      final guest = CourseProgressStore(frenchCourse.id);
      final guestAnswered = fresh('sess-guest')..submit(true);
      final token =
          '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
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
        return http.Response('offline', 503, request: request);
      }));
      await client.auth.signInWithPassword(
          email: 'test@example.invalid', password: 'test');
      courseBackend = client;
      addTearDown(() async {
        courseBackend = null;
        await client.dispose();
      });

      await expectLater(guest.recordLessonSectionAnswer(
              lessonId, guestAnswered.toJson(), sound: 'u', correct: true),
          throwsA((Object error) =>
              error is StateError && error is! LessonSectionConflictException));
    });

    test('invalid input is rejected without conflict typing', () async {
      final store = CourseProgressStore(frenchCourse.id);
      final saved = fresh('sess-invalid');
      await store.saveLessonSection(lessonId, saved.toJson());
      final unrecorded = fresh('sess-invalid')..submit(true);
      await expectLater(
          store.saveLessonSection(lessonId, unrecorded.toJson()),
          throwsA((Object error) =>
              error is StateError && error is! LessonSectionConflictException));
    });
  });
}
