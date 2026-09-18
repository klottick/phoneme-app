import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'french_course.dart';
import 'backend.dart';
import '../services/auth_service.dart';

final courseProgressProvider = FutureProvider<Map<String, dynamic>>((ref) {
  ref.watch(authControllerProvider.select((state) => state.user?.id));
  return CourseProgressStore(frenchCourse.id).load();
});

/// Local-first course data. One serialized writer prevents concurrent game
/// answers from overwriting one another. Legacy language-only data is untouched.
class CourseProgressStore {
  CourseProgressStore(this.courseId)
      : userId = courseBackend?.auth.currentUser?.id;
  final String courseId;
  final String? userId;
  static Future<void>? _writes;
  String get storageScope => userId == null ? courseId : '$courseId.$userId';
  String get key => 'course.v1.$storageScope';
  static Future<void>? _syncing;

  Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['lessons'] is List &&
            data['evidence'] is Map &&
            data['scores'] is Map) {
          return data;
        }
      } on FormatException {
        /* Keep the original data for recovery. */
      } on TypeError {/* Fall back without overwriting until a new action. */}
    }
    return {
      'lessons': <String>[],
      'evidence': <String, dynamic>{},
      'scores': <String, dynamic>{}
    };
  }

  Future<void> _update(void Function(Map<String, dynamic>) change) {
    final operation = (_writes ?? Future<void>.value()).then((_) async {
      final data = await load();
      change(data);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, jsonEncode(data))) {
        throw StateError('Could not save progress');
      }
    });
    final tail = operation.catchError((Object _) {});
    _writes = tail;
    tail.then((_) {
      if (identical(_writes, tail)) _writes = null;
    });
    return operation;
  }

  void _queue(Map<String, dynamic> data, Map<String, dynamic> event) {
    final user = courseBackend?.auth.currentUser;
    if (user == null || user.id != userId) {
      return; // Guest practice stays on this device.
    }
    final pending = data.putIfAbsent('pending', () => <dynamic>[]) as List;
    pending.add({
      ...event,
      'id':
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
      'user_id': user.id,
      'course_id': courseId
    });
  }

  /// Retryable, idempotent cloud delivery. A failed request retains its outbox.
  Future<bool> sync() async {
    final client = courseBackend;
    final user = client?.auth.currentUser;
    if (client == null || user == null || user.id != userId) return false;
    if (_syncing != null) await _syncing;
    var success = false;
    final operation = () async {
      final data = await load();
      final pending = (data['pending'] as List? ?? [])
          .cast<Map>()
          .where((e) => e['user_id'] == user.id)
          .toList();
      if (pending.isEmpty) {
        success = true;
        return;
      }
      for (var start = 0; start < pending.length; start += 100) {
        final batch = pending.skip(start).take(100).toList();
        await client.rpc('record_course_events', params: {'events': batch});
        final ids = batch.map((e) => e['id']).toSet();
        await _update((current) => (current['pending'] as List?)
            ?.removeWhere((e) => ids.contains(e['id'])));
      }
      success = true;
    }();
    _syncing = operation.catchError((Object _) {});
    try {
      await operation;
    } catch (_) {
      return false;
    } finally {
      _syncing = null;
    }
    return success;
  }

  Future<void> _change(void Function(Map<String, dynamic>) change) async {
    await _update(change);
    unawaited(sync());
  }

  Future<void> completeLesson(String id) => _change((data) {
        if (!(data['lessons'] as List).contains(id)) data['lessons'].add(id);
        _queue(data, {'kind': 'lesson', 'lesson_id': id});
      });

  Future<void> record(String sound, String skill, bool correct,
          {String activity = 'lesson'}) =>
      _change((data) {
        final evidence = data['evidence'] as Map;
        final entry =
            Map<String, dynamic>.from(evidence['$skill:$sound'] as Map? ?? {});
        final attempts = (entry['attempts'] as int? ?? 0) + 1;
        final hits = (entry['correct'] as int? ?? 0) + (correct ? 1 : 0);
        evidence['$skill:$sound'] = {
          'sound': sound,
          'skill': skill,
          'attempts': attempts,
          'correct': hits,
          'due': DateTime.now()
              .add(Duration(days: correct ? 1 : 0))
              .toIso8601String(),
        };
        _queue(data, {
          'kind': 'answer',
          'sound': sound,
          'skill': skill,
          'correct': correct,
          'activity': activity
        });
      });

  Future<void> saveScore(String game, int score) => _change((data) {
        final previous = data['scores'][game] as int? ?? 0;
        if (score > previous) data['scores'][game] = score;
        _queue(data, {'kind': 'score', 'game': game, 'score': score});
      });
}
