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
/// answers from overwriting one another. Legacy language-only data is
/// untouched. Public reads and outbox delivery are serialized on the same
/// chain, so they expose only committed documents: the shared_preferences
/// package updates its in-process cache before a platform write resolves,
/// and an uncoordinated read would otherwise surface (and `sync()` could
/// even upload) a write that is still in flight or already rejected.
class CourseProgressStore implements LessonSectionStore {
  CourseProgressStore(this.courseId)
      : userId = courseBackend?.auth.currentUser?.id;
  final String courseId;
  final String? userId;
  static Future<void>? _writes;
  String get storageScope => userId == null ? courseId : '$courseId.$userId';
  String get key => 'course.v1.$storageScope';
  static Future<void>? _syncing;

  /// Runs [task] serially with every other read or write.
  ///
  /// The caller's future rethrows [task]'s failure; the chain itself
  /// continues. A reader queued on the chain waits out in-flight writers —
  /// each failed write has repaired the in-process cache before it settles —
  /// and no writer can run until a queued reader has finished. Writers never
  /// await backend delivery, and readers never await writers beyond the
  /// chain, so nothing in here can deadlock or stall on the network.
  Future<T> _serialize<T>(FutureOr<T> Function() task) {
    final Future<T> operation =
        (_writes ?? Future<void>.value()).then<T>((_) => task());
    final Future<void> tail =
        operation.then<void>((_) {}, onError: (Object _) {});
    _writes = tail;
    tail.then<void>((_) {
      if (identical(_writes, tail)) _writes = null;
    });
    return operation;
  }

  /// Reads the progress document without chain coordination. Writers use
  /// this from inside the chain; public reads must go through [load], which
  /// is serialized with the writers.
  Future<Map<String, dynamic>> _read() async {
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

  /// Committed-only progress document: serialized on the writer chain so the
  /// caller never observes an in-flight or later-rejected preferences
  /// document.
  Future<Map<String, dynamic>> load() {
    return _serialize<Map<String, dynamic>>(_read);
  }

  Future<void> _update(void Function(Map<String, dynamic>) change) {
    return _serialize<void>(() async {
      final data = await _read();
      final prefs = await SharedPreferences.getInstance();
      final String? lastCommitted = prefs.getString(key);
      change(data);
      var committed = false;
      try {
        if (!await prefs.setString(key, jsonEncode(data))) {
          throw StateError('Could not save progress');
        }
        committed = true;
      } finally {
        if (!committed) {
          // The legacy preferences API records its in-process cache before
          // the platform write resolves, so a rejected write would otherwise
          // keep reading back as saved for the rest of this process. Restore
          // the last committed state before releasing the serialized writer.
          try {
            final Future repair = lastCommitted == null
                ? prefs.remove(key)
                : prefs.setString(key, lastCommitted);
            await repair;
          } catch (_) {
            // Even if the platform rejects the repair write, the cache
            // itself was already restored to the last committed state.
          }
        }
      }
    });
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

  /// Retryable, idempotent cloud delivery. A failed request retains its
  /// outbox. The outbox state is read only after any in-flight write has
  /// committed or been repaired, so an in-flight optimistic event is never
  /// delivered; backend delivery itself happens outside the writer chain.
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
    final entry =
        Map<String, dynamic>.from(evidence['$skill:$sound'] as Map? ?? {});
    final attempts = (entry['attempts'] as int? ?? 0) + 1;
    final hits = (entry['correct'] as int? ?? 0) + (correct ? 1 : 0);
    evidence['$skill:$sound'] = {
      'sound': sound,
      'skill': skill,
      'attempts': attempts,
      'correct': hits,
      'due':
          DateTime.now().add(Duration(days: correct ? 1 : 0)).toIso8601String(),
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
      throw ArgumentError.value(lessonId, 'lessonId',
          'No discovery section is supported for this lesson.');
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

  /// Whether the entry's processed metadata is canonical for [stored]:
  /// `processedSessionId` must be the checkpoint's own session and
  /// `processedAttemptCount` exactly the checkpoint's attempt count (the
  /// writers maintain this invariant, so any other value — mismatched,
  /// missing, wrong-typed, negative, or inflated — is corrupt).
  bool _canonicalMetadata(
      LessonSectionSession stored, Map<String, dynamic> entry) {
    final Object? sessionId = entry['processedSessionId'];
    if (sessionId is! String || sessionId.isEmpty) {
      return false;
    }
    if (sessionId != stored.sessionId) {
      return false;
    }
    final Object? count = entry['processedAttemptCount'];
    if (count is! int) {
      return false; // Missing, wrong-type, or negative: all non-canonical.
    }
    return count == stored.attemptCount;
  }

  /// A stored entry is usable only when its checkpoint parses and its
  /// processed metadata is canonical for that checkpoint. A corrupt entry is
  /// treated as if no session were saved: writers apply the new-session
  /// rules and the first valid write replaces the entry, preserving legacy
  /// data and sibling entries. This is what keeps a corrupted counter from
  /// ever swallowing a genuinely new answer as a "duplicate".
  LessonSectionSession? _usableStored(
      LessonSection section, Map<String, dynamic>? entry) {
    final stored = _storedSection(section, entry);
    if (stored == null || entry == null) {
      return null;
    }
    if (!_canonicalMetadata(stored, entry)) {
      return null;
    }
    return stored;
  }

  /// Reports an unusable stored entry with the same [FormatException]
  /// contract as an unusable checkpoint; the screen starts a fresh session
  /// with the recover-notice and the next valid save replaces the entry.
  void _requireCanonicalEntry(
      LessonSection section, Map<String, dynamic> entry) {
    final Object? checkpoint = entry['checkpoint'];
    if (checkpoint is Map) {
      final stored = _parseSnapshot(
          section, checkpoint.cast<String, dynamic>()); // May throw.
      if (!_canonicalMetadata(stored, entry)) {
        throw FormatException(
            'The stored processed metadata does not match the saved '
            'checkpoint (processedSessionId: ${entry['processedSessionId']}, '
            'processedAttemptCount: ${entry['processedAttemptCount']}).');
      }
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

  /// Applies one section entry. The incoming `sections` value must already be
  /// a map; a corrupt (non-map) value is replaced wholesale by the new entry,
  /// a valid map is extended so that sibling entries survive. [checkpoint]
  /// must be the frozen canonical snapshot from a validated session.
  void _writeSection(Map<String, dynamic> data, String lessonId,
      Map<String, dynamic> checkpoint, String sessionId, int attemptCount) {
    final existing = data['sections'];
    final Map<String, dynamic> sections = existing is Map
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    data['sections'] = sections;
    sections[lessonId] = {
      'checkpoint': checkpoint,
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
      if (_deepEquals((_parseSnapshot(section, raw)..advance()).toJson(),
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
    final entry = _sectionEntry(data, lessonId);
    final checkpoint = entry?['checkpoint'];
    if (checkpoint is! Map) {
      return null;
    }
    final section = sectionForLesson(lessonId);
    if (section != null && entry != null) {
      // An unusable entry — an unparseable checkpoint or non-canonical
      // processed metadata — is reported with the same FormatException
      // contract as an unusable snapshot; the caller starts a fresh session
      // and the next valid save replaces the entry.
      _requireCanonicalEntry(section, entry);
    }
    return checkpoint.cast<String, dynamic>();
  }

  @override
  Future<void> saveLessonSection(
      String lessonId, Map<String, dynamic> checkpoint) async {
    final section = _requireSection(lessonId);
    final candidate = _parseSnapshot(section, checkpoint);
    // Freeze the validated snapshot at call time: the mutable caller map is
    // never persisted, and unknown raw payload keys cannot be smuggled in.
    final frozen = candidate.toJson();
    return _update((data) {
      _ensureCurrentOwner();
      final entry = _sectionEntry(data, lessonId);
      final stored = _usableStored(section, entry);
      if (stored == null) {
        if (candidate.attemptCount != 0) {
          throw StateError(
              'The first saved state of a section must be a fresh, '
              'zero-attempt session.');
        }
        _writeSection(data, lessonId, frozen, candidate.sessionId, 0);
        return;
      }
      if (_deepEquals(stored.toJson(), candidate.toJson())) {
        return; // Re-saving the same state is a no-op.
      }
      if (candidate.sessionId != stored.sessionId) {
        if (candidate.attemptCount != 0) {
          throw LessonSectionConflictException(
              'A new session starts at attempt zero; switching session IDs '
              'mid-answer is rejected.');
        }
        _writeSection(data, lessonId, frozen, candidate.sessionId, 0);
        return;
      }
      if (!_reachesFrom(section, entry, candidate, reviewAllowed: true)) {
        if (candidate.attemptCount <= stored.attemptCount) {
          // A valid snapshot from the stored session at or behind the
          // stored state: either a stale same-owner instance, or an equal
          // count it diverged at (another instance committed a different
          // outcome for the same attempt and advanced). Both are reloadable
          // conflicts, not fabrications.
          throw LessonSectionConflictException(
              'This snapshot is behind the stored session or a state it '
              'diverged from at the same attempt count; it is a stale '
              'same-owner instance, not a valid save.');
        }
        throw StateError(
            'This snapshot is not a valid save from the stored session; '
            'unrecorded answers and changed outcomes are rejected.');
      }
      _writeSection(
          data, lessonId, frozen, stored.sessionId, stored.attemptCount);
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
    // Freeze the validated snapshot at call time: the mutable caller map is
    // never persisted, and unknown raw payload keys cannot be smuggled in.
    final frozen = candidate.toJson();
    return _change((data) {
      _ensureCurrentOwner();
      final entry = _sectionEntry(data, lessonId);
      final stored = _usableStored(section, entry);
      final Object? rawStored = entry?['checkpoint'];
      if (stored == null || rawStored is! Map) {
        // A session's first answer replays as exactly one submit on the
        // implicit fresh first pass carrying this session's own identity,
        // policy, and round.
        final implicit = LessonSectionSession(
          itemIds: section.items.map((item) => item.id).toList(),
          sessionId: candidate.sessionId,
          contentRevision: section.contentRevision,
          policy: candidate.policy,
        )..submit(candidate.lastCorrect!);
        if (!_deepEquals(implicit.toJson(), candidate.toJson())) {
          throw StateError(
              'A new session may only record its first answer on a fresh '
              'first pass.');
        }
        _recordSectionAnswer(
            data, lessonId, frozen, candidate.sessionId, 1, sound, correct);
        return;
      }
      if (candidate.sessionId != stored.sessionId) {
        throw LessonSectionConflictException(
            'Refusing to record for a different session on a started lesson.');
      }
      // Counters are canonical for a usable entry: the checkpoint's session
      // and its attempt count. A corrupt entry is unusable (above), so a new
      // answer can never be swallowed as a duplicate of inflated metadata.
      final processed = stored.attemptCount;
      if (candidate.attemptCount <= processed) {
        return; // Duplicate or older checkpoint: no-op, never a revert.
      }
      if (candidate.attemptCount != processed + 1) {
        throw LessonSectionConflictException(
            'Answer checkpoints must continue the session with no gaps.');
      }
      // The incoming checkpoint must be the stored state with exactly one
      // submit applied: this is what pins the previous outcomes, the policy,
      // the queue/phase/round, and the answered item, not just the count.
      LessonSectionSession replay;
      try {
        replay = _parseSnapshot(section, rawStored.cast<String, dynamic>())
          ..submit(candidate.lastCorrect!);
      } on StateError {
        throw StateError(
            'The stored session cannot accept another answer in its '
            'current state.');
      }
      if (!_deepEquals(replay.toJson(), candidate.toJson())) {
        throw StateError(
            'This checkpoint is not the stored session with exactly one new '
            'answer; rewritten outcomes, changed policy, position, queue, or '
            'phase are rejected.');
      }
      _recordSectionAnswer(data, lessonId, frozen, stored.sessionId,
          candidate.attemptCount, sound, correct);
    });
  }

  void _recordSectionAnswer(
      Map<String, dynamic> data,
      String lessonId,
      Map<String, dynamic> checkpoint,
      String sessionId,
      int attemptCount,
      String sound,
      bool correct) {
    _applyAnswer(data, sound, 'listening', correct);
    _queue(data, {
      'kind': 'answer',
      'sound': sound,
      'skill': 'listening',
      'correct': correct,
      'activity': 'discovery-section'
    });
    _writeSection(data, lessonId, checkpoint, sessionId, attemptCount);
  }

  @override
  Future<void> completeLessonSection(
      String lessonId, Map<String, dynamic> checkpoint) async {
    final section = _requireSection(lessonId);
    final candidate = _parseSnapshot(section, checkpoint);
    if (!candidate.canComplete) {
      throw StateError('The section has not met its completion policy yet.');
    }
    // Freeze the validated snapshot at call time; the mutable caller map and
    // any unknown raw payload keys are never persisted.
    final frozen = candidate.toJson();
    return _change((data) {
      _ensureCurrentOwner();
      final entry = _sectionEntry(data, lessonId);
      final stored = _usableStored(section, entry);
      if (stored == null) {
        throw StateError(
            'Completing requires a saved session for this lesson.');
      }
      if (candidate.sessionId != stored.sessionId) {
        throw LessonSectionConflictException(
            'Refusing to complete a session that is not the stored one.');
      }
      final processed = stored.attemptCount;
      if (candidate.attemptCount > processed) {
        throw StateError(
            'Completing requires the last recorded state; unrecorded '
            'answers are rejected.');
      }
      if (candidate.attemptCount < processed) {
        throw LessonSectionConflictException(
            'Completing requires the last recorded state; a checkpoint '
            'behind the stored one is a stale instance, not a completion.');
      }
      final storedState = _deepEquals(stored.toJson(), candidate.toJson());
      if (!storedState &&
          !_reachesFrom(section, entry, candidate, reviewAllowed: false)) {
        // Reaching this check, the candidate is at the stored attempt count
        // and is a valid state of the same session that the store has not
        // accepted: a stale or divergent same-owner instance (for example
        // one where a different outcome was committed for the last
        // attempt). It is reloadable, not a fabrication.
        throw LessonSectionConflictException(
            'This snapshot does not match the stored session at the same '
            'attempt count; it is a stale or divergent same-owner '
            'instance, not a valid completion state.');
      }
      _writeSection(data, lessonId, frozen, stored.sessionId, processed);
      final lessons = data['lessons'] as List;
      if (!lessons.contains(lessonId)) {
        lessons.add(lessonId);
        _queue(data, {'kind': 'lesson', 'lesson_id': lessonId});
      }
    });
  }
}
