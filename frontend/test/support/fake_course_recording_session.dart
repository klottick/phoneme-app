/// Deterministic [CourseRecordingSession] double for Task 3 facade tests.
///
/// Test-only support: mirrors the session interface and retirement
/// semantics with controllable `prepareGate`, `startGate` and `stopGate`
/// (each releasable with success or an error), a `calls` log,
/// `Future<void> waitForStart()` that resolves on start dispatch, and
/// `emitCompleted()`/`emitError(Object)` injectors. No plugin or device is
/// touched, and it is not a replacement for the real adapter tests.
library;

import 'dart:async';

import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_recording_backend.dart';

final class FakeCourseRecordingSession implements CourseRecordingSession {
  final List<String> calls = [];
  final StreamController<CourseRecordingEvent> _events =
      StreamController<CourseRecordingEvent>.broadcast();

  bool _retired = false;
  CourseAudioRecording? _prepared;
  final Completer<void> _startDispatched = Completer<void>();

  /// `prepare` awaits this gate before dispatching; completing it with an
  /// error releases the held operation as a failure.
  Future<void>? prepareGate;

  /// `start` awaits this gate before dispatching; completing it with an
  /// error releases the held operation as a failure.
  Future<void>? startGate;

  /// `stop` awaits this gate before settling.
  Future<void>? stopGate;

  /// The recording most recently prepared, if any.
  CourseAudioRecording? get preparedRecording => _prepared;

  @override
  Stream<CourseRecordingEvent> get events => _events.stream;

  /// Resolves when `start` is dispatched, after any `startGate` releases.
  Future<void> waitForStart() => _startDispatched.future;

  /// Emits the terminal success event on [events].
  void emitCompleted() => _events.add(CourseRecordingEvent.completed);

  /// Emits an error with its diagnostic cause on [events].
  void emitError(Object error) => _events.addError(error);

  @override
  Future<void> prepare(CourseAudioRecording recording) async {
    _requireActive();
    calls.add('prepare');
    final Future<void>? gate = prepareGate;
    if (gate != null) await gate;
    _requireActive();
    _prepared = recording;
  }

  @override
  Future<void> start() async {
    _requireActive();
    if (_prepared == null) {
      throw StateError('start() requires a prepared source');
    }
    calls.add('start');
    final Future<void>? gate = startGate;
    if (gate != null) await gate;
    _requireActive();
    if (!_startDispatched.isCompleted) _startDispatched.complete();
  }

  @override
  Future<void> stop() async {
    if (_retired) return;
    _retired = true;
    calls.add('stop');
    final Future<void>? gate = stopGate;
    if (gate != null) await gate;
  }

  @override
  Future<void> dispose() async {
    _retired = true;
    calls.add('dispose');
    if (!_events.isClosed) await _events.close();
  }

  void _requireActive() {
    if (_retired) {
      throw StateError('recording session is retired; construct a new session');
    }
  }
}
