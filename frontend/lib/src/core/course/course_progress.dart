import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'french_course.dart';
import 'backend.dart';
import 'lesson_section.dart';
import 'lesson_section_session.dart';
import 'lesson_section_store.dart';
import '../services/auth_service.dart';

final courseProgressProvider = FutureProvider<Map<String, dynamic>>((ref) {
  ref.watch(authControllerProvider.select((state) => state.user?.id));
  return CourseProgressStore(frenchCourse.id).load();
});

/// Discovery section store bound to the current account, rebuilt whenever the
/// signed-in user changes (same wiring as [courseProgressProvider]).
final lessonSectionStoreProvider = Provider<LessonSectionStore>((ref) {
  ref.watch(authControllerProvider.select((state) => state.user?.id));
  return CourseProgressStore(frenchCourse.id);
});

/// Local-first course data. One serialized writer prevents concurrent game
/// answers from overwriting one another. Legacy language-only data is untouched.
class CourseProgressStore implements LessonSectionStore {
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

  void _applyAnswer(
      Map<String, dynamic> data, String sound, String skill, bool correct) {
    final evidence = data['evidence'] as Map;
    final entry = Map<String, dynamic>.from(evidence['$skill:$sound'] as Map? ?? {});
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
  }

  Future<void> record(String sound, String skill, bool correct,
          {String activity = 'lesson'}) =>
      _change((data) {
        _applyAnswer(data, sound, skill, correct);
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

  // ------------------------------ Discovery section ------------------------
  //
  // The section state lives under `sections.<lessonId>` of the same
  // `course.v1.<scope>` document as the legacy data. Each entry carries the
  // last saved checkpoint plus the processed session counters, and every
  // write is validated against the stored state inside the single serialized
  // writer, so stale captures, fabricated answers, and account switches are
  // rejected without mutating preferences.

  LessonSection _requireSection(String lessonId) {
    final section = sectionForLesson(lessonId);
    if (section == null) {
      throw ArgumentError.value(
          lessonId, 'lessonId', 'No discovery section is supported for this lesson.');
    }
    return section;
  }

  LessonSectionSession _parseSnapshot(
          LessonSection section, Map<String, dynamic> json) =>
      LessonSectionSession.fromJson(
        json,
        itemIds: section.items.map((item) => item.id).toList(),
        contentRevision: section.contentRevision,
      );

  Map<String, dynamic>? _sectionEntry(
      Map<String, dynamic> data, String lessonId) {
    final sections = data['sections'];
    if (sections is! Map) {
      return null;
    }
    final entry = sections[lessonId];
    if (entry is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(entry);
  }

  LessonSectionSession? _storedSection(
      LessonSection section, Map<String, dynamic>? entry) {
    if (entry == null) {
      return null;
    }
    final checkpoint = entry['checkpoint'];
    if (checkpoint is! Map) {
      return null;
    }
    try {
      return _parseSnapshot(section, checkpoint.cast<String, dynamic>());
    } on FormatException {
      // A corrupt stored snapshot is never restored: a new saved action
      // replaces it explicitly.
      return null;
    }
  }

  void _ensureCurrentOwner() {
    final user = courseBackend?.auth.currentUser;
    if (user == null) {
      if (userId != null) {
        throw StateError(
            'This store is bound to an account that is no longer signed in.');
      }
    } else if (user.id != userId) {
      throw StateError(
          'The signed-in account changed; this captured store is stale.');
    }
  }

  void _writeSection(Map<String, dynamic> data, String lessonId,
      Map<String, dynamic> checkpoint, String sessionId, int attemptCount) {
    final sections =
        data.putIfAbsent('sections', () => <String, dynamic>{}) as Map;
    sections[lessonId] = {
      'checkpoint': Map<String, dynamic>.from(
          jsonDecode(jsonEncode(checkpoint)) as Map),
      'processedSessionId': sessionId,
      'processedAttemptCount': attemptCount,
    };
  }

  bool _deepEquals(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) {
        return false;
      }
      for (final Object? key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) {
          return false;
        }
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) {
        return false;
      }
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) {
          return false;
        }
      }
      return true;
    }
    return a == b;
  }

  /// True when [candidate] is exactly one valid transition from the stored
  /// snapshot: an `advance`, and (unless [reviewAllowed] is false) a
  /// `reviewMistakes` round start.
  bool _reachesFrom(
    LessonSection section,
    Map<String, dynamic>? entry,
    LessonSectionSession candidate, {
    required bool reviewAllowed,
  }) {
    final checkpoint = entry?['checkpoint'];
    if (checkpoint is! Map) {
      return false;
    }
    final raw = checkpoint.cast<String, dynamic>();
    try {
      if (_deepEquals(
          (_parseSnapshot(section, raw)..advance()).toJson(),
          candidate.toJson())) {
        return true;
      }
    } on StateError {
      // The stored state cannot advance.
    }
    if (reviewAllowed) {
      try {
        if (_deepEquals(
            (_parseSnapshot(section, raw)..reviewMistakes()).toJson(),
            candidate.toJson())) {
          return true;
        }
      } on StateError {
        // The stored state cannot start a review round.
      }
    }
    return false;
  }

  @override
  Future<Map<String, dynamic>?> loadLessonSection(String lessonId) async {
    final data = await load();
    final checkpoint = _sectionEntry(data, lessonId)?['checkpoint'];
    if (checkpoint is! Map) {
      return null;
    }
    return checkpoint.cast<String, dynamic>();
  }

  @override
  Future<void> saveLessonSection(
      String lessonId, Map<String, dynamic> checkpoint) async {
    final section = _requireSection(lessonId);
    final candidate = _parseSnapshot(section, checkpoint);
    return _update((data) {
      _ensureCurrentOwner();
      final entry = _sectionEntry(data, lessonId);
      final stored = _storedSection(section, entry);
      if (stored == null) {
        if (candidate.attemptCount != 0) {
          throw StateError(
              'The first saved state of a section must be a fresh, '
              'zero-attempt session.');
        }
        _writeSection(data, lessonId, checkpoint, candidate.sessionId, 0);
        return;
      }
      if (_deepEquals(stored.toJson(), candidate.toJson())) {
        return; // Re-saving the same state is a no-op.
      }
      if (candidate.sessionId != stored.sessionId) {
        if (candidate.attemptCount != 0) {
          throw StateError(
              'A new session starts at attempt zero; switching session IDs '
              'mid-answer is rejected.');
        }
        _writeSection(data, lessonId, checkpoint, candidate.sessionId, 0);
        return;
      }
      if (!_reachesFrom(
          section, entry, candidate,
          reviewAllowed: true)) {
        throw StateError(
            'This snapshot is not a valid save from the stored session; '
            'unrecorded answers and changed outcomes are rejected.');
      }
      final processed =
          (entry?['processedAttemptCount'] as int?) ?? stored.attemptCount;
      _writeSection(
          data, lessonId, checkpoint, stored.sessionId, processed);
    });
  }

  @override
  Future<void> recordLessonSectionAnswer(
    String lessonId,
    Map<String, dynamic> checkpoint, {
    required String sound,
    required bool correct,
  }) async {
    final section = _requireSection(lessonId);
    final candidate = _parseSnapshot(section, checkpoint);
    if (!candidate.answered) {
      throw StateError('The checkpoint is not a submitted answer.');
    }
    if (candidate.lastCorrect != correct) {
      throw StateError('The correctness does not match the checkpoint.');
    }
    final expectedSound = section.items
        .where((item) => item.id == candidate.currentItemId)
        .first
        .expectedSound;
    if (expectedSound != sound) {
      throw StateError(
          'The sound does not match the answered item of the checkpoint.');
    }
    return _change((data) {
      _ensureCurrentOwner();
      final entry = _sectionEntry(data, lessonId);
      final stored = _storedSection(section, entry);
      if (stored == null) {
        if (candidate.attemptCount != 1) {
          throw StateError(
              'A new session records its first answer at attempt one.');
        }
        _recordSectionAnswer(data, lessonId, checkpoint, candidate.sessionId,
            1, sound, correct);
        return;
      }
      if (candidate.sessionId != stored.sessionId) {
        throw StateError(
            'Refusing to record for a different session on a started lesson.');
      }
      final processed =
          (entry?['processedAttemptCount'] as int?) ?? stored.attemptCount;
      if (candidate.attemptCount <= processed) {
        return; // Duplicate or older checkpoint: no-op, never a revert.
      }
      if (candidate.attemptCount != processed + 1) {
        throw StateError(
            'Answer checkpoints must continue the session with no gaps.');
      }
      _recordSectionAnswer(data, lessonId, checkpoint, stored.sessionId,
          candidate.attemptCount, sound, correct);
    });
  }

  void _recordSectionAnswer(Map<String, dynamic> data, String lessonId,
      Map<String, dynamic> checkpoint, String sessionId, int attemptCount,
      String sound, bool correct) {
    _applyAnswer(data, sound, 'listening', correct);
    _queue(data, {
      'kind': 'answer',
      'sound': sound,
      'skill': 'listening',
      'correct': correct,
      'activity': 'discovery-section'
    });
    _writeSection(
        data, lessonId, checkpoint, sessionId, attemptCount);
  }

  @override
  Future<void> completeLessonSection(
      String lessonId, Map<String, dynamic> checkpoint) async {
    final section = _requireSection(lessonId);
    final candidate = _parseSnapshot(section, checkpoint);
    if (!candidate.canComplete) {
      throw StateError(
          'The section has not met its completion policy yet.');
    }
    return _change((data) {
      _ensureCurrentOwner();
      final entry = _sectionEntry(data, lessonId);
      final stored = _storedSection(section, entry);
      if (stored == null) {
        throw StateError(
            'Completing requires a saved session for this lesson.');
      }
      if (candidate.sessionId != stored.sessionId) {
        throw StateError(
            'Refusing to complete a session that is not the stored one.');
      }
      final processed =
          (entry?['processedAttemptCount'] as int?) ?? stored.attemptCount;
      if (candidate.attemptCount != processed) {
        throw StateError(
            'Completing requires the last recorded state; unrecorded '
            'answers are rejected.');
      }
      final storedState = _deepEquals(stored.toJson(), candidate.toJson());
      if (!storedState &&
          !_reachesFrom(section, entry, candidate, reviewAllowed: false)) {
        throw StateError(
            'This snapshot is not a valid completion state of the stored '
            'session.');
      }
      _writeSection(
          data, lessonId, checkpoint, stored.sessionId, processed);
      final lessons = data['lessons'] as List;
      if (!lessons.contains(lessonId)) {
        lessons.add(lessonId);
        _queue(data, {'kind': 'lesson', 'lesson_id': lessonId});
      }
    });
  }
}
