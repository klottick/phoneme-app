/// Deterministic [CoursePracticeSpeechSession] double for Task 3 facade tests.
///
/// Test-only support. Models the raw-quiescence contract of the bounded TTS
/// adapter without any plugin or device:
///
/// * `speakGate` holds the utterance future AFTER dispatch is recorded —
///   the call log marks dispatch itself, so a caller can deterministically
///   stop after dispatch, before the utterance settles;
/// * `stopGate` holds the shared retirement settlement.
///
/// A gate failure fails the held operation (or the shared retirement) with
/// that exact diagnostic cause. Retiring fences the pending utterance
/// (success or its release error) before settling on the captured gate, so
/// quiescence means every dispatched operation settled, whatever its
/// outcome — exactly like the adapter's fence. No plugin or device is
/// touched, and this double is not a replacement for the real adapter tests.
library;

import 'dart:async';

import 'package:linguist/src/core/course/course_audio_contract.dart';

final class FakeCourseSpeechSession implements CoursePracticeSpeechSession {
  /// Call log: `speak:<text>` on dispatch, `stop`, `dispose`.
  final List<String> calls = <String>[];

  bool _retired = false;
  Future<void>? _retirement;

  /// The pending utterance (a completer so a superseding speech or a
  /// retirement can settle it quietly, like the real adapter's abandoned
  /// pipeline).
  Completer<void>? _activeSpeak;

  bool get retired => _retired;

  /// When assigned before [speak], the returned utterance future is held
  /// until this future settles; release with success or with the exact
  /// diagnostic error to fail the held utterance.
  Future<void>? speakGate;

  /// When assigned before the first [stop]/[dispose], the shared retirement
  /// settlement is held until this future settles; completing it with an
  /// error fails the shared retirement for every caller with that exact
  /// cause.
  Future<void>? stopGate;

  @override
  Future<void> speak(String text) {
    if (_retired) {
      throw StateError('speech session is retired; construct a new session');
    }
    calls.add('speak:$text');
    // A new utterance supersedes a pending one: the abandoned settlement
    // must not hang, and the original cause (if any) is already owned by
    // that caller's observation.
    final Completer<void>? previous = _activeSpeak;
    if (previous != null && !previous.isCompleted) {
      previous.complete();
    }
    final Completer<void> completer = Completer<void>();
    _activeSpeak = completer;
    final Future<void>? gate = speakGate;
    if (gate == null) {
      completer.complete();
      return completer.future;
    }
    // Observe before returning: a release error must never become an
    // uncaught async failure when the caller stops following the future.
    // ignore: unawaited_futures
    unawaited(gate.then<void>(
      (Object? value) {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
    ));
    return completer.future;
  }

  @override
  Future<void> stop() {
    _retired = true;
    calls.add('stop');
    return _retire();
  }

  @override
  Future<void> dispose() {
    _retired = true;
    calls.add('dispose');
    return _retire();
  }

  /// Shared retirement: whichever of `stop`/`dispose` starts it first owns
  /// the fence; every later caller awaits the same settlement — success or
  /// the original gate failure — instead of observing an early quiescence.
  Future<void> _retire() {
    final Future<void>? existing = _retirement;
    if (existing != null) return existing;
    _retirement = _runRetirement();
    return _retirement!;
  }

  Future<void> _runRetirement() async {
    final Future<void>? gate = stopGate;
    if (gate != null) {
      // Capture and observe at retirement entry — a release error while the
      // utterance is still pending must already be observed (never an
      // uncaught async failure), and the gate is fixed at retirement entry.
      // ignore: unawaited_futures
      unawaited(gate.then<void>(_quietlySettled, onError: _quietlySettled));
    }
    // Fence first: quiescence means the dispatched utterance settled
    // (success or its release error) before the settlement resolves.
    final Completer<void>? active = _activeSpeak;
    if (active != null && !active.isCompleted) {
      try {
        await active.future;
      } on Object {
        // The abandoned utterance's caller owns the original cause; the
        // fence only tracks that every dispatched operation settled.
      }
    }
    if (gate != null) await gate;
  }

  static void _quietlySettled(Object? value) {}
}
