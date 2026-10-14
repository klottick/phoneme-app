import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'course_audio_contract.dart';

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
/// tested quiet stale-cancellation semantics. [quiesce] settles once every
/// dispatched raw platform operation has settled — the practice-session
/// wrapper uses it to fence raw work before reporting quiescence.
class FrenchWordAudio implements CourseAudio {
  FrenchWordAudio(
      [CourseAudioDeadlines deadlines = const CourseAudioDeadlines()])
      : _deadlines = deadlines {
    _deadlines.validate();
  }

  final FlutterTts _tts = FlutterTts();
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
      throw StateError(
          'Install a French voice in your device speech settings.');
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
      // The setup allowance bounds the whole setup phase; the utterance is
      // bounded by the existing 12-second allowance by default.
      await _runSetup(mine).timeout(_deadlines.setup);
      if (mine != _current) return;

      final Future<dynamic> utterance = _tts.speak(word);
      _track(utterance);
      final dynamic result = await utterance.timeout(_deadlines.ttsUtterance);
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

final courseAudioProvider = Provider<CourseAudio>((ref) {
  final audio = FrenchWordAudio();
  ref.onDispose(() {
    audio.stop().catchError((Object _) {});
  });
  return audio;
});

/// Bounded [CoursePracticeSpeechSession] over [FrenchWordAudio].
///
/// The adapter is constructed lazily — a `stop` or `dispose` with no
/// utterance never initializes the TTS engine. Each session speaks at most
/// one request at a time and is permanently single-use: after retirement,
/// [speak] throws. Retirement is shared: every `stop`/`dispose` caller
/// awaits the same outcome — success or the original cleanup failure — and
/// that outcome is reached only after the pending raw pipeline has settled
/// (success or failure), never on the mere settlement of a timed-out public
/// future.
final class FrenchPracticeSpeechSession implements CoursePracticeSpeechSession {
  FrenchPracticeSpeechSession(CourseAudioDeadlines deadlines)
      : _deadlines = deadlines {
    _deadlines.validate();
  }

  final CourseAudioDeadlines _deadlines;

  /// The lazy adapter: constructed only by the first [speak].
  FrenchWordAudio? _audio;
  bool _retired = false;
  Future<void>? _retirement;

  @override
  Future<void> speak(String text) async {
    // An `async` body so a retired session's throw is delivered as a failed
    // returned future (the contract: "speak throws"), not a synchronous
    // escape around a caller's `expect(..., throwsA(...))`.
    if (_retired) {
      throw StateError(
          'practice speech session is retired; construct a new session');
    }
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
    try {
      // Invalidation plus the raw platform stop, both settling.
      await audio.stop();
      // Quiescence of every other dispatched raw operation (a held setup
      // phase or utterance), success or failure.
      await audio.quiesce();
    } on Object catch (error) {
      cleanupFailure = error;
    }
    if (cleanupFailure != null) {
      // A failed retirement is shared by every caller and is never evidence
      // of quiescence.
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
