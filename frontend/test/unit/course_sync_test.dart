import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/course/course_progress.dart';

void main() {
  test(
      'signed-in outbox survives failure and retries without mixing guest data',
      () async {
    final guest = CourseProgressStore('en-fr');
    await guest.completeLesson('en-fr-vowels');
    var offline = true;
    final delivered = <Map<String, dynamic>>[];
    const userId = '10000000-0000-4000-8000-000000000001';
    final token = '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
        '${base64Url.encode(utf8.encode(jsonEncode({
          'sub': userId,
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
        })))}.signature';
    final client =
        SupabaseClient('https://course.example.invalid', 'public-test-key',
            httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/token')) {
        return http.Response(
            jsonEncode({
              'access_token': token,
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': userId,
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
      if (offline) {
        return http.Response('{"message":"offline"}', 503, request: request);
      }
      final body = jsonDecode(request.body) as Map;
      delivered.addAll((body['events'] as List).cast<Map<String, dynamic>>());
      return http.Response('', 204, request: request);
    }));
    courseBackend = client;
    addTearDown(() async {
      courseBackend = null;
      await client.dispose();
    });
    await client.auth.signInWithPassword(
        email: 'test@example.invalid', password: 'test-password');
    final account = CourseProgressStore('en-fr');
    expect((await account.load())['lessons'], isEmpty);
    await account.record('u', 'listening', true, activity: 'sound');
    expect(await account.sync(), isFalse);
    final pending = (await account.load())['pending'] as List;
    expect(pending, hasLength(1));
    final id = pending.single['id'];
    offline = false;
    expect(await account.sync(), isTrue);
    expect((await account.load())['pending'], isEmpty);
    expect(delivered.single['id'], id);
    expect(delivered.single['course_id'], 'en-fr');
    expect(delivered.single['user_id'], userId);
    expect((await guest.load())['lessons'], ['en-fr-vowels']);
  });
}
