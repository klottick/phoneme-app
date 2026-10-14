import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'course_audio_catalog.dart';
import 'course_audio_contract.dart';
import 'course_recording_backend.dart';
import 'course_reference_audio.dart';

export 'course_audio_contract.dart';

/// French TTS adapter (raw, direct).
///
/// Each adapter instance tracks a monotonically increasing ownership token
/// ([_current]). A [speak] becomes the owner; [stop] invalidates the current
/// one before awaiting the platform stop.
///
/// The setup+utterance pipeline (availability → stop → language → rate →
/// await-completion → utterance) crosses many asynchronous platform-channel
/// boundaries, and any of them can settle with a value, with an error, or
/// only later via a timeout. Ownership is therefore checked on both outcome
/// paths of the whole pipeline:
///
/// * Success boundaries: after every await, an abandoned request returns
///   quietly, so it never runs later setup, starts an utterance, or stops a
///   newer utterance.
/// * Error boundary: after the pipeline settles with a failure (a platform
///   error on any method, the availability/explicit-failure StateError, or a
///   bound timeout), an abandoned request drains the failure quietly while
///   the *current* owner rethrows the same error with its original stack
///   trace, preserving the unavailable-voice, explicit-failure, platform-
///   error and timeout semantics. An active failure also invalidates its
///   token, so a late-settling setup phase cannot run later work after the
///   request has already failed.
///
/// Overlapping [speak] calls always converge on the newest request.
/// [deadlines] bound the setup phase ([CourseAudioDeadlines.setup]) and the
/// utterance ([CourseAudioDeadlines.ttsUtterance]); direct callers keep the
/// tested quiet stale-cancellation semantics.
///
/// Approved alpha override ("Option 1"): a real speech-error platform
/// callback is NOT an outcome source on any path. The locked flutter_tts
/// delivers `speak.onError` identity-free over one global,
/// last-constructed-wins channel; this adapter installs no error handler, so
/// the callback is drained by the locked global handler with zero side
/// effects and can neither complete, fail, nor count as heard playback.
/// The request settles only from the raw method future or from this adapter's
/// own typed deadline (created on `onTimeout`). The isolated
/// `FrenchPracticeSpeechSession` enforces a genuine one-attempt guard before
/// init/dispatch (permanently consumed even when the first attempt fails),
/// so no attempt can ever inherit a predecessor's callback. The unresolved
/// raw utterance stays fenced for [quiesce] on every path.
///
/// [quiesce] settles once every dispatched raw platform operation has
/// settled — the practice-session wrapper uses it to fence raw work before
/// reporting quiescence.
class FrenchWordAudio implements CourseAudio {
  FrenchWordAudio([
    CourseAudioDeadlines deadlines = const CourseAudioDeadlines(),
    FlutterTts? flutterTts,
  ])  : _deadlines = deadlines,
        _tts = flutterTts ?? FlutterTts() {
    _deadlines.validate();
    // Approved alpha override ("Option 1"): NO error handler is installed.
    // The locked flutter_tts routes `speak.onError` to the last-constructed
    // engine's handler; with none set, the identity-free callback is drained
    // by the locked global handler with zero side effects and is never a
    // source of a request outcome. The raw method future (or this adapter's
    // own typed deadline) is the only settlement path.
  }

  final FlutterTts _tts;
  final CourseAudioDeadlines _deadlines;

  /// Raw platform operations dispatched and not yet settled, tracked
  /// separately from any bounded public future so retirement can fence them.
  final List<Future<Object?>> _rawOps = <Future<Object?>>[];

  /// Ownership token: each [speak] increments it to claim the request, and
  /// [stop] increments it to invalidate the current setup and utterance.
  int _current = 0;

  /// Every dispatched raw operation has settled (success or failure). A
  /// failed operation's caller owns its original cause; quiescence tracks
  /// settlement only.
  Future<void> quiesce() async {
    final List<Future<Object?>> pending = List<Future<Object?>>.of(_rawOps);
    try {
      await Future.wait<void>(pending, eagerError: false);
    } on Object {
      // A caller owns each operation's cause; quiescence means only that
      // every dispatched raw operation settled.
    }
  }

  void _track(Future<Object?> op) {
    _rawOps.add(op);
    // Observe quietly so a discarded raw operation can never become an
    // unhandled async failure.
    unawaited(op.then<void>(
      (Object? value) {},
      onError: (Object error) {},
    ));
  }

  /// The raw setup phase (availability → replacement stop → language → rate →
  /// completion), ownership-checked after every boundary: a superseded phase
  /// settles quietly and dispatches nothing further.
  Future<void> _runSetup(int mine) async {
    final Future<Object?> availability = _tts.isLanguageAvailable('fr-FR');
    _track(availability);
    if (await availability != true) {
      if (mine != _current) return;
      throw StateError(canonicalFrenchVoiceUnavailableMessage);
    }
    if (mine != _current) return; // Abandoned before running setup.

    final Future<Object?> replace = _tts.stop();
    _track(replace);
    await replace;
    if (mine != _current) return;

    final Future<Object?> language = _tts.setLanguage('fr-FR');
    _track(language);
    await language;
    if (mine != _current) return;

    final Future<Object?> rate = _tts.setSpeechRate(0.4);
    _track(rate);
    await rate;
    if (mine != _current) return;

    final Future<Object?> completion = _tts.awaitSpeakCompletion(true);
    _track(completion);
    await completion;
    // Do not start an abandoned utterance even though completion is set.
    if (mine != _current) return;
  }

  @override
  Future<void> speak(String word) async {
    final mine = ++_current;
    try {
      // The setup allowance bounds the whole setup phase. The phase error is
      // created only on THIS adapter's own setup-timer expiry (onTimeout): a
      // source TimeoutException that settles before the allowance passes
      // through unchanged for the direct caller and the stable facade failure,
      // and is never relabelled as an expired phase of this adapter.
      await _runSetup(mine).timeout(
        _deadlines.setup,
        onTimeout: () {
          throw PhaseTimeoutException(
              CourseAudioFailureReason.startupTimeout,
              'The setup phase deadline was exceeded.',
              _deadlines.setup);
        },
      );
      if (mine != _current) return;

      // Approved alpha override ("Option 1"): the utterance settles only
      // from its raw method future or this adapter's own typed utterance
      // bound (created on onTimeout). An identity-free `speak.onError`
      // callback is drained by the locked global handler and is never an
      // outcome source: it cannot complete, fail, or count as heard
      // playback. A superseded utterance drains quietly below.
      final Future<Object?> utterance = _tts.speak(word);
      _track(utterance);
      // A source error — including a source TimeoutException that settles
      // before the allowance — passes through to the caller unchanged; the
      // phase error exists only on this adapter's own timer expiry.
      final dynamic result = await utterance
          .timeout(
            _deadlines.ttsUtterance,
            onTimeout: () {
              throw PhaseTimeoutException(
                  CourseAudioFailureReason.completionTimeout,
                  'The utterance phase deadline was exceeded.',
                  _deadlines.ttsUtterance);
            },
          );
      // The outer catch owns staleness: an abandoned request drains any
      // failure quietly; an active failure invalidates its token and
      // rethrows the same error with its original stack trace.
      // Superseded mid-utterance: do not act on the stale result.
      if (mine != _current) return;

      // With awaitSpeakCompletion enabled, web resolves with null on
      // completion; native implementations return 1. Explicit failure codes
      // still fail, and platform exceptions or a missing completion fail
      // below.
      if (result != null && result != 1) {
        throw StateError('French audio could not be played.');
      }
    } on Object catch (error, stackTrace) {
      if (mine != _current) {
        return; // Abandoned/superseded: a stale failure drains quietly.
      }
      // An active failure terminates this request: invalidate ownership so a
      // late-settling setup phase cannot dispatch further platform work after
      // the failure, then rethrow the exact error with its original trace.
      _current++;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> stop() async {
    // Invalidate the current setup before touching the platform, so a queued
    // setup cannot start speaking once it resumes.
    _current++;
    final Future<Object?> stop = _tts.stop();
    _track(stop);
    await stop;
  }
}

/// The exact alpha audio disclosure shown on every listening and practice
/// surface. One shared constant so no surface drifts from the wording: the
/// bundled recordings are linguistically unverified alpha material, and
/// device speech is practice-only.
const String alphaAudioDisclosure =
    'Alpha audio: recordings are unverified; device speech is practice-only.';

/// The shared reference-audio player for the alpha. This provider [owns]
/// the one [FrenchReferenceAudio] instance: construction is lazy (no
/// catalogue load, no recording engine, no speech engine until a request
/// selects one), covered words select the bundled unverified recordings
/// first, only uncovered legacy text may fall back to practice speech, and
/// provider disposal retires any active request idempotently.
final courseReferenceAudioProvider = Provider<CourseReferenceAudio>((ref) {
  final CourseAudioCatalogLoader loader =
      ref.watch(courseAudioCatalogLoaderProvider);
  final FrenchReferenceAudio audio = FrenchReferenceAudio(
    loadCatalog: loader.load,
    recordingFactory: createCourseRecordingSession,
    speechFactory: createFrenchPracticeSpeechSession,
    deadlines: const CourseAudioDeadlines(),
  );
  ref.onDispose(() {
    unawaited(audio.dispose().catchError((Object _) {}));
  });
  return audio;
});

/// The existing legacy provider now serves the shared alpha player instead
/// of a raw TTS adapter: `speak(word)` plays the bundled recording for
/// covered words and keeps practice speech only for uncovered legacy text.
/// The two-method [CourseAudio] contract is unchanged, so existing
/// `implements CourseAudio` mocks and
/// `courseAudioProvider.overrideWithValue(...)` overrides compile and run
/// untouched.
final courseAudioProvider = Provider<CourseAudio>((ref) {
  return ref.watch(courseReferenceAudioProvider);
});

/// Bounded [CoursePracticeSpeechSession] over [FrenchWordAudio].
///
/// The adapter is constructed lazily — a `stop` or `dispose` with no
/// utterance never initializes the TTS engine. The session is a genuine
/// single-attempt object (approved alpha override, "Option 1"): [speak] is
/// accepted exactly once per session instance — the attempt is permanently
/// consumed before init/dispatch and even if the first attempt fails — so a
/// second attempt can never inherit a predecessor's identity-free callback
/// or an armed sink. After retirement, [speak] throws. Retirement is shared:
/// every `stop`/`dispose` caller awaits the same outcome — success or the
/// original cleanup failure — and that outcome is reached only after the
/// pending raw pipeline has settled (success or failure), never on the mere
/// settlement of a timed-out public future.
final class FrenchPracticeSpeechSession implements CoursePracticeSpeechSession {
  FrenchPracticeSpeechSession(CourseAudioDeadlines deadlines)
      : _deadlines = deadlines {
    _deadlines.validate();
  }

  final CourseAudioDeadlines _deadlines;

  /// The lazy adapter: constructed only by the first [speak].
  FrenchWordAudio? _audio;
  bool _retired = false;

  /// The one-attempt guard (approved alpha override, "Option 1"): set at the
  /// first [speak] before init/dispatch and never cleared — a failed first
  /// attempt does not reopen the session.
  bool _attempted = false;
  Future<void>? _retirement;

  @override
  Future<void> speak(String text) async {
    // An `async` body so a retired/consumed session's throw is delivered as
    // a failed returned future (the contract: "speak throws"), not a
    // synchronous escape around a caller's `expect(..., throwsA(...))`.
    if (_retired) {
      throw StateError(
          'practice speech session is retired; construct a new session');
    }
    if (_attempted) {
      // A real one-attempt guard before init/dispatch: a second attempt is
      // rejected — never re-dispatched against the same engine, where an
      // identity-free callback or a replayed signal could fail it.
      throw StateError(
          'practice speech session is single-attempt and already consumed; '
          'construct a new session for a new attempt');
    }
    _attempted = true;
    final FrenchWordAudio audio = _audio ??= FrenchWordAudio(_deadlines);
    final Future<void> speakFuture = audio.speak(text);
    // Observe quietly: an abandonment settlement (stop/dispose/replacement)
    // must never become an unhandled async failure.
    unawaited(speakFuture.then<void>(
      (Object? value) {},
      onError: (Object error) {},
    ));
    return speakFuture;
  }

  @override
  Future<void> stop() {
    _retired = true;
    return _retire();
  }

  @override
  Future<void> dispose() {
    _retired = true;
    return _retire();
  }

  /// Shared retirement: whichever of `stop`/`dispose` starts it first owns
  /// the fence; every later caller awaits the same outcome — success or the
  /// original cleanup cause — instead of observing an early quiescence.
  Future<void> _retire() {
    final Future<void>? existing = _retirement;
    if (existing != null) return existing;
    _retirement = _runRetirement();
    return _retirement!;
  }

  Future<void> _runRetirement() async {
    final FrenchWordAudio? audio = _audio;
    // Lazy guarantee: no utterance was ever requested → no engine exists →
    // nothing to quiesce, and nothing is initialized to check.
    if (audio == null) return;
    Object? cleanupFailure;
    StackTrace? cleanupStackTrace;
    try {
      // Invalidation plus the raw platform stop, both settling.
      await audio.stop();
      // Quiescence of every other dispatched raw operation (a held setup
      // phase or utterance), success or failure.
      await audio.quiesce();
    } on Object catch (error, stackTrace) {
      cleanupFailure = error;
      cleanupStackTrace = stackTrace;
    }
    if (cleanupFailure != null) {
      // A failed retirement is shared by every caller and is never evidence
      // of quiescence; the rethrow keeps the original throw site.
      if (cleanupStackTrace != null) {
        Error.throwWithStackTrace(cleanupFailure, cleanupStackTrace);
      }
      throw cleanupFailure;
    }
  }
}

/// Factory for the bounded practice-speech session. Constructing a session
/// never initializes the TTS engine.
CoursePracticeSpeechSession createFrenchPracticeSpeechSession({
  CourseAudioDeadlines deadlines = const CourseAudioDeadlines(),
}) {
  return FrenchPracticeSpeechSession(deadlines);
}
