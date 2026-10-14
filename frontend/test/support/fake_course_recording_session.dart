/// Deterministic [CourseRecordingSession] double for Task 3 facade tests.
///
/// Test-only support. Models the raw-quiescence contract of the real
/// adapter without any plugin or device:
///
/// * `prepareGate` holds `prepare` before its dispatch (pre-dispatch);
/// * `startGate` holds the `start` acknowledgement AFTER the dispatch is
///   recorded — [waitForStart] resolves on the recorded dispatch itself,
///   so a caller can deterministically stop after dispatch, before the
///   ack;
/// * `stopGate` holds the shared retirement settlement.
///
/// Every gate is releasable with success or an error: a gate failure
/// fails the held operation (or the shared retirement) with that exact
/// cause, but the stop fence still settles — quiescence means every
/// dispatched operation settled, whatever its outcome. `stop` and
/// `dispose` share one retirement outcome, including its failure, exactly
/// like the adapter's shared teardown. No plugin or device is touched,
/// and this double is not a replacement for the real adapter tests.
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

  /// Raw operations dispatched and not yet acknowledged/settled; fenced
  /// by the retirement settlement.
  final List<Future<void>> _rawOps = [];

  /// Shared retirement outcome (success or failure), held by every
  /// `stop`/`dispose` caller.
  Future<void>? _retirement;

  /// `prepare` awaits this gate before dispatching; completing it with an
  /// error releases the held operation as a failure.
  Future<void>? prepareGate;

  /// `start` records its dispatch (resolving [waitForStart]) and then
  /// awaits this acknowledgement gate; completing it with an error
  /// releases the held operation as a failure.
  Future<void>? startGate;

  /// The shared `stop`/`dispose` settlement awaits this gate; completing
  /// it with an error fails the shared retirement for every caller.
  Future<void>? stopGate;

  /// The recording most recently prepared, if any.
  CourseAudioRecording? get preparedRecording => _prepared;

  @override
  Stream<CourseRecordingEvent> get events => _events.stream;

  /// Resolves when `start` has been dispatched, before any `startGate`
  /// releases the held acknowledgement.
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
    final Future<void> op = () async {
      if (gate != null) await gate;
      // A late acknowledgement after retirement is still represented
      // (success or the gate failure); only the side effect is blocked.
      if (!_retired) {
        _prepared = recording;
      }
    }();
    _trackRaw(op);
    return op;
  }

  @override
  Future<void> start() async {
    _requireActive();
    if (_prepared == null) {
      throw StateError('start() requires a prepared source');
    }
    calls.add('start');
    if (!_startDispatched.isCompleted) _startDispatched.complete();
    final Future<void>? gate = startGate;
    // The dispatched work's acknowledgement: a late ack after retirement
    // still settles (success or the gate failure) and is fenced by the
    // retirement; it never throws retirement after dispatch.
    final Future<void> op = () async {
      if (gate != null) await gate;
    }();
    _trackRaw(op);
    return op;
  }

  @override
  Future<void> stop() async {
    _retired = true;
    calls.add('stop');
    await _retire();
  }

  @override
  Future<void> dispose() async {
    _retired = true;
    calls.add('dispose');
    try {
      await _retire();
    } finally {
      if (!_events.isClosed) {
        await _events.close();
      }
    }
  }

  /// Shared retirement: whichever of `stop`/`dispose` starts it first
  /// owns the fence; every later caller awaits the same outcome —
  /// success or failure — instead of observing an early quiescence.
  Future<void> _retire() {
    final Future<void>? existing = _retirement;
    if (existing != null) return existing;
    _retirement = _runRetirement();
    return _retirement!;
  }

  Future<void> _runRetirement() async {
    // Fence: every dispatched raw operation settles (success or failure)
    // before the retirement settles — quiescence, whatever the outcome.
    final List<Future<void>> pending = List.of(_rawOps);
    _rawOps.clear();
    if (pending.isNotEmpty) {
      try {
        await Future.wait<void>(pending, eagerError: false);
      } on Object catch (_) {
        // Each op's caller owns the original cause; the fence tracks only
        // that every dispatched op settled.
      }
    }
    // The shared settlement gate: releasable with success or failure; a
    // failure is the shared retirement outcome for every caller.
    final Future<void>? gate = stopGate;
    if (gate != null) await gate;
  }

  void _trackRaw(Future<void> op) {
    _rawOps.add(op);
    // The caller owns the op's outcome; observe it quietly so an
    // abandoned op can never become an unhandled async failure.
    // ignore: unawaited_futures
    unawaited(op.then<void>(_quietlySettled, onError: _quietlySettled));
  }

  static void _quietlySettled(Object? value) {}

  void _requireActive() {
    if (_retired) {
      throw StateError('recording session is retired; construct a new session');
    }
  }
}
