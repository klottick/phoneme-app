/// FR-03 Task 3: ownership-aware reference facade and bounded practice
/// speech over the published Task 1–2 contracts.
///
/// [FrenchReferenceAudio] coordinates one active reference request at a time
/// on an ownership token: a newer request, [stop], or [dispose] invalidates
/// the current ownership *synchronously* before any platform work, and the
/// invalidated request's terminal is exactly one `cancelled` result —
/// delivered promptly, never after a raw settlement, and never twice.
///
/// Selection policy:
/// * Unknown reference IDs fail (`unknownReference`) and never become
///   text-derived TTS.
/// * `reviewedOnly` denies every current pending candidate (and TTS) before
///   any engine factory is called.
/// * A declared but unrecorded word is `missingAsset`; a recorded normal
///   with a requested slow take is `unavailableVariant`. Explicit
///   `allowPracticeTts` (alpha practice only) permits TTS of the exact
///   authored text — and only then.
/// * A declared recording, once selected, is the source even if it fails:
///   recording failures never silently substitute TTS.
///
/// Deadlines are injected and validated at construction; the applied bounds
/// are `setup` for catalogue load, preparation, and start, `recordingCompletion`
/// for playback, `setup + ttsUtterance` as the facade's total speech
/// allowance (a speech timeout is therefore a completion-timeout failure),
/// and `cleanup` for the next-owner retirement gate. Timeouts never establish
/// quiescence: a retirement that cannot settle within the cleanup allowance
/// fails the replacement (`cleanupFailed`) rather than overlapping audio, and
/// a retirement that fails durably blocks new audible ownership with its
/// original cause.
///
/// The legacy [CourseAudio] bridge resolves `speak` only for Completed:
/// Failed raises [CourseAudioException], Cancelled raises the distinct
/// [CourseAudioCancelledException] so success continuations cannot mark the
/// word heard.
library;

import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;

import 'course_audio_catalog.dart';
import 'course_audio_contract.dart';
import 'course_exercise.dart';
import 'course_recording_backend.dart';

final class FrenchReferenceAudio implements CourseReferenceAudio {
  FrenchReferenceAudio({
    required Future<CourseAudioCatalog> Function() loadCatalog,
    required CourseRecordingSession Function() recordingFactory,
    required CoursePracticeSpeechSession Function() speechFactory,
    CourseAudioDeadlines deadlines = const CourseAudioDeadlines(),
  })  : _loadCatalog = loadCatalog,
        _recordingFactory = recordingFactory,
        _speechFactory = speechFactory,
        _deadlines = deadlines {
    deadlines.validate();
  }

  final Future<CourseAudioCatalog> Function() _loadCatalog;
  final CourseRecordingSession Function() _recordingFactory;
  final CoursePracticeSpeechSession Function() _speechFactory;
  final CourseAudioDeadlines _deadlines;

  /// Monotonically increasing ownership token; every terminal, stop, or
  /// new request invalidates the current one.
  int _owner = 0;
  bool _disposed = false;

  /// The active engine of the current request (at most one of each).
  CourseRecordingSession? _activeRecording;
  CoursePracticeSpeechSession? _activeSpeech;

  /// The current request's terminal completer (at most one unsettled).
  Completer<CourseAudioResult>? _pending;
  String? _pendingId;

  /// Retirements in flight (success or failure still to be learned).
  final List<Future<void>> _pendingRetirements = <Future<void>>[];
  /// Retirements that failed: durable, and a permanent block on admitting
  /// another audible owner.
  final List<Object> _retirementFailures = <Object>[];

  // -------------------------------------------------------------------
  // Ownership
  // -------------------------------------------------------------------

  bool _owns(int token) => token == _owner && !_disposed;

  void _requireUsable() {
    if (_disposed) {
      throw StateError(
          'FrenchReferenceAudio is disposed; construct a new instance');
    }
  }

  /// Invalidates the current ownership synchronously: the pending request
  /// (if any) receives its one `cancelled` terminal now, and the active
  /// engine — if any — is retired (its outcome is tracked).
  void _invalidate() {
    final Completer<CourseAudioResult>? pending = _pending;
    final String? id = _pendingId;
    _pending = null;
    _pendingId = null;
    _owner++;
    final CourseRecordingSession? recording = _activeRecording;
    _activeRecording = null;
    if (recording != null) {
      _trackRetirement(recording.stop());
    }
    final CoursePracticeSpeechSession? speechSession = _activeSpeech;
    _activeSpeech = null;
    if (speechSession != null) {
      _trackRetirement(speechSession.dispose());
    }
    if (pending != null && !pending.isCompleted) {
      pending.complete(CourseAudioResult.cancelled(referenceId: id));
    }
  }

  void _trackRetirement(Future<void> retirement) {
    _pendingRetirements.add(retirement);
    unawaited(retirement.then<void>(
      (Object? value) {
        _pendingRetirements.remove(retirement);
      },
      onError: (Object error) {
        if (_pendingRetirements.remove(retirement)) {
          _retirementFailures.add(error);
        }
      },
    ));
  }

  /// The next-owner gate: a failed retirement blocks immediately and
  /// durably; a pending retirement is awaited up to the cleanup allowance,
  /// after which the replacement fails rather than overlap audio. Returns
  /// the blocking failure, or null when quiescence is confirmed.
  Future<CourseAudioFailure?> _retirementBlocker() async {
    if (_retirementFailures.isNotEmpty) {
      return CourseAudioFailure(
        reason: CourseAudioFailureReason.cleanupFailed,
        cause: _retirementFailures.first,
      );
    }
    if (_pendingRetirements.isEmpty) {
      return null;
    }
    final List<Future<void>> snapshot =
        List<Future<void>>.of(_pendingRetirements);
    try {
      await Future.wait<void>(snapshot, eagerError: false)
          .timeout(_deadlines.cleanup);
    } on TimeoutException catch (error) {
      return CourseAudioFailure(
        reason: CourseAudioFailureReason.cleanupFailed,
        cause: error,
      );
    } on Object catch (error) {
      return CourseAudioFailure(
        reason: CourseAudioFailureReason.cleanupFailed,
        cause: error,
      );
    }
    if (_retirementFailures.isNotEmpty) {
      return CourseAudioFailure(
        reason: CourseAudioFailureReason.cleanupFailed,
        cause: _retirementFailures.first,
      );
    }
    return null;
  }

  // -------------------------------------------------------------------
  // Registration (one terminal exactly)
  // -------------------------------------------------------------------

  /// Registers [run] as the current request. The core encodes all failures
  /// as values and never throws; the defensive error path keeps the
  /// terminal honest regardless.
  Future<CourseAudioResult> _register(
    int token,
    String id,
    Future<CourseAudioResult> run,
  ) {
    final Completer<CourseAudioResult> completer =
        Completer<CourseAudioResult>();
    _pending = completer;
    _pendingId = id;
    unawaited(run.then(
      (CourseAudioResult result) {
        if (token != _owner) {
          return; // Superseded: its `cancelled` terminal was already given.
        }
        // This terminal is final: no later stale event may act on it.
        _owner++;
        if (_pending == completer) {
          _pending = null;
          _pendingId = null;
        }
        if (!completer.isCompleted) {
          completer.complete(result);
        }
        // Release/retire the engine still owned by this (now retired)
        // request; a superseded engine was already retired in _invalidate.
        final CourseRecordingSession? recording = _activeRecording;
        _activeRecording = null;
        if (recording != null) {
          _trackRetirement(recording.stop());
        }
        final CoursePracticeSpeechSession? speechSession = _activeSpeech;
        _activeSpeech = null;
        if (speechSession != null) {
          _trackRetirement(speechSession.dispose());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (token != _owner) {
          return;
        }
        _owner++;
        if (_pending == completer) {
          _pending = null;
          _pendingId = null;
        }
        if (!completer.isCompleted) {
          completer.complete(CourseAudioResult.failed(
            referenceId: id,
            source: null,
            failure: CourseAudioFailure(
              reason: CourseAudioFailureReason.unsupportedPlayback,
              cause: error,
              stackTrace: stackTrace,
            ),
          ));
        }
      },
    ));
    return completer.future;
  }

  // -------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------

  @override
  Future<CourseAudioResult> playReference(
    String referenceId, {
    CourseAudioUse use = CourseAudioUse.alphaPractice,
    CourseAudioVariant variant = CourseAudioVariant.normal,
    bool allowPracticeTts = false,
  }) {
    _requireUsable();
    _invalidate(); // a newer request supersedes the current ownership
    final int token = _owner;
    return _register(
      token,
      referenceId,
      _corePlay(token, referenceId, use, variant, allowPracticeTts),
    );
  }

  @override
  Future<void> speak(String word) {
    _requireUsable();
    _invalidate();
    final int token = _owner;
    final Future<CourseAudioResult> terminal =
        _register(token, word, _coreSpeak(token, word));
    // Legacy bridge: resolve only for Completed; everything else must be
    // visible to the caller's error handling — never a quiet completion.
    final Future<void> delivery = terminal.then<void>(
        (CourseAudioResult result) {
      if (result.outcome == CourseAudioOutcome.completed) {
        return;
      }
      if (result.outcome == CourseAudioOutcome.cancelled) {
        throw const CourseAudioCancelledException();
      }
      throw CourseAudioException(result.failure!);
    });
    // A synchronous observer guarantees this delivery failure is "handled"
    // at the moment it is recorded, even when a caller's listener attaches
    // across an event boundary (zone unhandled-error reporting); every
    // caller listener still receives the exact exception itself — verified
    // A/B against an unobserved bridge.
    unawaited(delivery.then<void>(
        (Object? value) {}, onError: (Object error) {}));
    return delivery;
  }

  @override
  Future<void> stop() {
    if (_disposed) {
      return Future<void>.value();
    }
    // Prompt cancellation: ownership is invalidated now; the retirement
    // outcome is tracked for the next owner, not awaited here.
    _invalidate();
    return Future<void>.value();
  }

  @override
  Future<void> dispose() {
    if (_disposed) {
      return Future<void>.value();
    }
    _disposed = true;
    _invalidate();
    return Future<void>.value();
  }

  // -------------------------------------------------------------------
  // Request cores (all failures encoded; never throw)
  // -------------------------------------------------------------------

  Future<CourseAudioResult> _corePlay(
    int token,
    String id,
    CourseAudioUse use,
    CourseAudioVariant variant,
    bool allowPracticeTts,
  ) async {
    final CourseAudioFailure? blocker = await _retirementBlocker();
    if (blocker != null) {
      return CourseAudioResult.failed(
          referenceId: id, source: null, failure: blocker);
    }
    if (!_owns(token)) {
      return CourseAudioResult.cancelled(referenceId: id);
    }

    CourseAudioCatalog catalog;
    try {
      catalog = await _loadedCatalogue();
    } on TimeoutException catch (error, stackTrace) {
      if (!_owns(token)) {
        return CourseAudioResult.cancelled(referenceId: id);
      }
      return CourseAudioResult.failed(
        referenceId: id,
        source: null,
        failure: CourseAudioFailure(
          reason: CourseAudioFailureReason.startupTimeout,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on Object catch (error) {
      if (!_owns(token)) {
        return CourseAudioResult.cancelled(referenceId: id);
      }
      if (error is CourseAudioException) {
        return CourseAudioResult.failed(
            referenceId: id, source: null, failure: error.failure);
      }
      return CourseAudioResult.failed(
        referenceId: id,
        source: null,
        failure: _classify(error, null, null),
      );
    }
    if (!_owns(token)) {
      return CourseAudioResult.cancelled(referenceId: id);
    }

    final CourseAudioReference? reference = catalog.referenceById(id);
    if (reference == null) {
      return CourseAudioResult.failed(
        referenceId: id,
        source: null,
        failure: const CourseAudioFailure(
          reason: CourseAudioFailureReason.unknownReference,
        ),
      );
    }
    final CourseAudioEntry? entry = _entryFor(catalog, reference);
    final CourseAudioRecording? recording = entry?.recordings[variant];

    if (use == CourseAudioUse.reviewedOnly) {
      // A source gate evaluated before any engine exists. Current shipped
      // recordings are all pending candidates; no reviewed recording
      // currently exists, so this always denies.
      if (recording != null &&
          recording.source == CourseAudioSource.reviewedRecording) {
        return _runRecording(token, id, recording);
      }
      return CourseAudioResult.failed(
        referenceId: id,
        source: recording?.source,
        failure: const CourseAudioFailure(
          reason: CourseAudioFailureReason.unreviewedSource,
        ),
      );
    }

    if (recording == null) {
      if (allowPracticeTts) {
        // Explicit practice fallback: speak the exact authored text.
        return _runSpeech(token, id, reference.spokenText);
      }
      final CourseAudioFailureReason reason = (variant ==
              CourseAudioVariant.slow &&
          entry != null)
          ? CourseAudioFailureReason.unavailableVariant
          : CourseAudioFailureReason.missingAsset;
      return CourseAudioResult.failed(
        referenceId: id,
        source: null,
        failure: CourseAudioFailure(reason: reason),
      );
    }

    return _runRecording(token, id, recording);
  }

  Future<CourseAudioResult> _coreSpeak(int token, String word) async {
    final CourseAudioFailure? blocker = await _retirementBlocker();
    if (blocker != null) {
      return CourseAudioResult.failed(
          referenceId: word, source: null, failure: blocker);
    }
    if (!_owns(token)) {
      return CourseAudioResult.cancelled(referenceId: word);
    }

    CourseAudioCatalog? catalog;
    try {
      catalog = await _loadedCatalogue();
    } on Object {
      // Legacy tolerance: the practice bridge must keep working when the
      // catalogue cannot be read. An unreadable catalogue cannot prove
      // coverage, so the exact text is spoken as practice speech — the
      // legacy path. This is not a recording-failure substitution.
      return _runSpeech(token, word, word);
    }
    if (!_owns(token)) {
      return CourseAudioResult.cancelled(referenceId: word);
    }

    final CourseAudioReference? reference = catalog.wordReferenceByText(word);
    if (reference == null) {
      // Unmapped legacy text: practice speech of the exact text.
      return _runSpeech(token, word, word);
    }
    final CourseAudioEntry? entry = _entryFor(catalog, reference);
    final CourseAudioRecording? recording =
        entry?.recordings[CourseAudioVariant.normal];
    if (recording == null) {
      // A declared word without a bundled recording: practice speech of the
      // exact authored text.
      return _runSpeech(token, word, reference.spokenText);
    }
    // Covered words play the bundled recording by default; a failure of a
    // declared recording is a typed failure, never a TTS substitution.
    return _runRecording(token, word, recording);
  }

  Future<CourseAudioResult> _runSpeech(
      int token, String id, String text) async {
    final CoursePracticeSpeechSession session;
    try {
      session = _speechFactory();
    } on Object catch (error, stackTrace) {
      if (!_owns(token)) {
        return CourseAudioResult.cancelled(referenceId: id);
      }
      return CourseAudioResult.failed(
        referenceId: id,
        source: CourseAudioSource.practiceTts,
        failure: _classify(error, stackTrace, CourseAudioSource.practiceTts),
      );
    }
    _activeSpeech = session;

    final Future<void> speakFuture;
    try {
      speakFuture = session.speak(text);
    } on Object catch (error, stackTrace) {
      if (!_owns(token)) {
        return CourseAudioResult.cancelled(referenceId: id);
      }
      return CourseAudioResult.failed(
        referenceId: id,
        source: CourseAudioSource.practiceTts,
        failure: _classify(error, stackTrace, CourseAudioSource.practiceTts),
      );
    }
    // The facade can lose this request after dispatch (stop, replacement,
    // dispose): an abandonment settlement must drain quietly.
    unawaited(speakFuture.then<void>((Object? value) {},
        onError: (Object error) {}));

    // The total facade speech allowance (setup + utterance). A well-behaved
    // session reports its own phase timeout first; the facade's bound is
    // the backstop and classifies as a completion timeout.
    try {
      await speakFuture
          .timeout(_deadlines.setup + _deadlines.ttsUtterance);
    } on TimeoutException catch (error, stackTrace) {
      if (!_owns(token)) {
        return CourseAudioResult.cancelled(referenceId: id);
      }
      return CourseAudioResult.failed(
        referenceId: id,
        source: CourseAudioSource.practiceTts,
        failure: CourseAudioFailure(
          reason: CourseAudioFailureReason.completionTimeout,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!_owns(token)) {
        return CourseAudioResult.cancelled(referenceId: id);
      }
      return CourseAudioResult.failed(
        referenceId: id,
        source: CourseAudioSource.practiceTts,
        failure: _classify(error, stackTrace, CourseAudioSource.practiceTts),
      );
    }
    if (!_owns(token)) {
      return CourseAudioResult.cancelled(referenceId: id);
    }
    return CourseAudioResult.completed(
      referenceId: id,
      source: CourseAudioSource.practiceTts,
    );
  }

  Future<CourseAudioResult> _runRecording(
      int token, String id, CourseAudioRecording recording) async {
    final CourseRecordingSession session;
    try {
      session = _recordingFactory();
    } on Object catch (error, stackTrace) {
      if (!_owns(token)) {
        return CourseAudioResult.cancelled(referenceId: id);
      }
      return CourseAudioResult.failed(
        referenceId: id,
        source: recording.source,
        failure: _classify(error, stackTrace, recording.source),
      );
    }
    _activeRecording = session;

    final Completer<CourseAudioResult> terminal =
        Completer<CourseAudioResult>();
    late final StreamSubscription<CourseRecordingEvent> events;
    // Event observation is attached before any dispatch, per the contract:
    // the session's terminal events must be observable for every outcome.
    events = session.events.listen(
      (CourseRecordingEvent event) {
        if (!_owns(token)) {
          return; // Stale identity: the event must not act.
        }
        if (event != CourseRecordingEvent.completed) {
          return;
        }
        if (!terminal.isCompleted) {
          terminal.complete(CourseAudioResult.completed(
              referenceId: id, source: recording.source));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_owns(token)) {
          return;
        }
        if (!terminal.isCompleted) {
          terminal.complete(CourseAudioResult.failed(
            referenceId: id,
            source: recording.source,
            failure:
                _classify(error, stackTrace, recording.source),
          ));
        }
      },
    );

    try {
      await session.prepare(recording).timeout(_deadlines.setup);
    } on TimeoutException catch (error, stackTrace) {
      events.cancel();
      return _setupFailure(token, id, recording, error, stackTrace,
          timedOut: true);
    } on Object catch (error, stackTrace) {
      events.cancel();
      return _setupFailure(token, id, recording, error, stackTrace,
          timedOut: false);
    }
    if (!_owns(token)) {
      events.cancel();
      return CourseAudioResult.cancelled(referenceId: id);
    }

    try {
      await session.start().timeout(_deadlines.setup);
    } on TimeoutException catch (error, stackTrace) {
      events.cancel();
      return _setupFailure(token, id, recording, error, stackTrace,
          timedOut: true);
    } on Object catch (error, stackTrace) {
      events.cancel();
      return _setupFailure(token, id, recording, error, stackTrace,
          timedOut: false);
    }
    if (!_owns(token)) {
      events.cancel();
      return CourseAudioResult.cancelled(referenceId: id);
    }

    // Completion: only the session's actual completion event counts
    // success; the applied bound is max(floor, duration + slack) after the
    // resume dispatch. Elapsed time, stop, disposal, and timeout are not
    // completion.
    try {
      await terminal.future
          .timeout(_deadlines.recordingCompletion(recording.duration));
    } on TimeoutException catch (error, stackTrace) {
      events.cancel();
      if (!_owns(token)) {
        return CourseAudioResult.cancelled(referenceId: id);
      }
      return CourseAudioResult.failed(
        referenceId: id,
        source: recording.source,
        failure: CourseAudioFailure(
          reason: CourseAudioFailureReason.completionTimeout,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
    events.cancel();
    // The terminal holds the event's value (completed or a typed failure);
    // a late event after this settle cannot double-record because the
    // token is invalidated with this terminal.
    return terminal.future;
  }

  CourseAudioResult _setupFailure(
    int token,
    String id,
    CourseAudioRecording recording,
    Object error,
    StackTrace? stackTrace, {
    required bool timedOut,
  }) {
    if (!_owns(token)) {
      return CourseAudioResult.cancelled(referenceId: id);
    }
    final CourseAudioFailure failure = timedOut
        ? CourseAudioFailure(
            reason: CourseAudioFailureReason.startupTimeout,
            cause: error,
            stackTrace: stackTrace,
          )
        : _classify(error, stackTrace, recording.source);
    return CourseAudioResult.failed(
        referenceId: id, source: recording.source, failure: failure);
  }

  // -------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------

  /// Loads the catalogue within the setup allowance, with a quiet observer
  /// so an invalidated load never leaves an unhandled settlement.
  Future<CourseAudioCatalog> _loadedCatalogue() {
    final Future<CourseAudioCatalog> load = _loadCatalog();
    unawaited(
        load.then<void>((Object? value) {}, onError: (Object error) {}));
    return load.timeout(_deadlines.setup);
  }

  CourseAudioEntry? _entryFor(
      CourseAudioCatalog catalog, CourseAudioReference reference) {
    for (final CourseAudioEntry entry in catalog.entries) {
      if (entry.reference.id == reference.id) {
        return entry;
      }
    }
    return null;
  }

  /// Normalizes a failure for the *selected* source, preserving the
  /// diagnostic cause: recognizable browser gesture rejections and
  /// French-voice unavailability (TTS only) get their stable reasons;
  /// everything else stays generic — unknown causes never become invented
  /// voice or permission diagnoses.
  CourseAudioFailure _classify(
    Object error,
    StackTrace? stackTrace,
    CourseAudioSource? selectedSource,
  ) {
    if (error is CourseAudioException) {
      return error.failure;
    }
    if (error is TimeoutException) {
      // A stray timeout (phase timeouts are classified at the boundary).
      return CourseAudioFailure(
        reason: CourseAudioFailureReason.completionTimeout,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (_isBrowserGestureRejection(error)) {
      return CourseAudioFailure(
        reason: CourseAudioFailureReason.userGestureRequired,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (selectedSource == CourseAudioSource.practiceTts &&
        error is StateError &&
        error.toString().contains('French voice')) {
      return CourseAudioFailure(
        reason: CourseAudioFailureReason.unavailableVoice,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return CourseAudioFailure(
      reason: CourseAudioFailureReason.unsupportedPlayback,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// Conservative recognition of browser autoplay/gesture rejection, the
  /// standard `NotAllowedError` family. Actual platform behavior must be
  /// verified on a real browser; this only stabilizes the classification.
  bool _isBrowserGestureRejection(Object error) {
    if (error is! PlatformException) {
      return false;
    }
    final String code = error.code.toLowerCase();
    if (code.contains('notallowed') || code.contains('gesture')) {
      return true;
    }
    final String message = (error.message ?? '').toLowerCase();
    return message.contains('not allowed') ||
        message.contains('user activation') ||
        message.contains('user-activated') ||
        message.contains('gesture');
  }
}
