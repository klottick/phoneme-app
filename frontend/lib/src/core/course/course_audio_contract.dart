/// FR-03 alpha shared reference-audio contract (Task 1).
///
/// Holds the shared enums, the reference-player interface, typed
/// results/failures, the legacy-bridge exceptions and the injectable
/// deadlines. The legacy [CourseAudio] interface is moved here unchanged;
/// `course_audio.dart` re-exports it so existing imports keep compiling.
///
/// No audio engine is constructed anywhere in this file; validation of
/// injected deadlines ([CourseAudioDeadlines.validate]) happens at
/// facade/speech-factory construction before the values are used.
library;

import 'dart:async';

/// How a reference request may be used (alpha practice vs reviewed-only).
enum CourseAudioUse { alphaPractice, reviewedOnly }

/// A requested recorded variant; `slow` requires a separately recorded slow
/// take and is never produced by rate manipulation.
enum CourseAudioVariant { normal, slow }

/// The audio source selected by a request.
enum CourseAudioSource { unverifiedRecording, reviewedRecording, practiceTts }

/// Exactly one terminal outcome per reference request.
enum CourseAudioOutcome { completed, cancelled, failed }

/// Stable, retryable-or-alternative failure classifications for the UI and
/// tests. These are not wrong-answer outcomes.
enum CourseAudioFailureReason {
  unknownReference,
  unavailableVariant,
  missingAsset,
  invalidCatalogue,
  unreviewedSource,
  unsupportedPlayback,
  userGestureRequired,
  unavailableVoice,
  startupTimeout,
  completionTimeout,
  cleanupFailed,
}

/// Legacy TTS audio interface.
///
/// Kept byte-for-byte the same two-method contract; existing
/// `implements CourseAudio` mocks and provider overrides compile unchanged.
abstract class CourseAudio {
  Future<void> speak(String word);
  Future<void> stop();
}

/// A bounded practice-speech session over the French TTS engine (Task 3).
///
/// The session wraps raw platform work: [speak] runs the setup/utterance
/// pipeline with bounded allowances, while [stop] and [dispose] establish
/// quiescence of every dispatched raw operation — settlement of a timed-out
/// public future is never quiescence. A session is permanently single-use:
/// after retirement, [speak] throws. Constructing a session never
/// initializes the TTS engine.
abstract interface class CoursePracticeSpeechSession {
  /// Speaks [text]; resolves on actual utterance completion and throws the
  /// original cause on failure (voice unavailability, platform error,
  /// bounded setup or utterance).
  Future<void> speak(String text);

  /// Retires the session: invalidates in-flight work and establishes raw
  /// quiescence. Every repeated caller awaits the same shared retirement
  /// outcome, including its failure.
  Future<void> stop();

  /// Permanently releases the session; idempotent and shares the same
  /// retirement outcome as [stop].
  Future<void> dispose();
}

/// Typed reference-player interface, added alongside the legacy
/// [CourseAudio] rather than adding required methods to every existing
/// implementation.
abstract interface class CourseReferenceAudio implements CourseAudio {
  /// Plays the exact bundled recording for [referenceId] under [use] and
  /// [variant]; [allowPracticeTts] is an explicit practice-fallback policy.
  Future<CourseAudioResult> playReference(String referenceId, {
    CourseAudioUse use = CourseAudioUse.alphaPractice,
    CourseAudioVariant variant = CourseAudioVariant.normal,
    bool allowPracticeTts = false,
  });

  /// Invalidates ownership and schedules guarded cleanup; disposal never
  /// yields a successful [CourseAudioOutcome.completed].
  Future<void> dispose();
}

/// A stable failure classification with the underlying diagnostic cause
/// preserved for debugging.
final class CourseAudioFailure {
  const CourseAudioFailure({
    required this.reason,
    this.cause,
    this.stackTrace,
  });

  final CourseAudioFailureReason reason;
  final Object? cause;
  final StackTrace? stackTrace;
}

/// The single terminal outcome of a reference request.
///
/// Exactly one of the named constructors builds the result, so invalid
/// terminal-field combinations (e.g. a completed result with a failure, or a
/// failed result without one) cannot be constructed.
final class CourseAudioResult {
  const CourseAudioResult._(
      this.outcome, this.referenceId, this.source, this.failure);

  const CourseAudioResult.completed({
    required String? referenceId,
    required CourseAudioSource source,
  }) : this._(
          CourseAudioOutcome.completed,
          referenceId,
          source,
          null,
        );

  const CourseAudioResult.cancelled({
    String? referenceId,
    CourseAudioSource? source,
  }) : this._(
          CourseAudioOutcome.cancelled,
          referenceId,
          source,
          null,
        );

  const CourseAudioResult.failed({
    String? referenceId,
    CourseAudioSource? source,
    required CourseAudioFailure failure,
  }) : this._(CourseAudioOutcome.failed, referenceId, source, failure);

  final CourseAudioOutcome outcome;
  final String? referenceId;
  final CourseAudioSource? source;
  final CourseAudioFailure? failure;
}

/// Typed failure for reference playback and catalogue loading.
final class CourseAudioException implements Exception {
  const CourseAudioException(this.failure);

  final CourseAudioFailure failure;

  @override
  String toString() => 'CourseAudioException(${failure.reason})';
}

/// Distinct cancellation signal for the legacy bridge so existing success
/// continuations cannot mark the word heard.
final class CourseAudioCancelledException implements Exception {
  const CourseAudioCancelledException();

  @override
  String toString() => 'CourseAudioCancelledException()';
}

/// The canonical voice-unavailability diagnostic the practice-speech
/// adapter throws when no French voice is installed. The classification
/// recognizes this exact diagnostic (or a typed cause) — never a substring
/// resemblance — so unrelated StateErrors stay generic.
const String canonicalFrenchVoiceUnavailableMessage =
    'Install a French voice in your device speech settings.';

/// A bounded practice-speech pipeline phase whose allowance expired.
///
/// Stays a [TimeoutException], so existing `on TimeoutException` catchers
/// and `isA<TimeoutException>()` expectations keep working, and carries the
/// phase that expired so the caller classifies the failure from the typed
/// cause instead of guessing which bounded phase timed out.
final class PhaseTimeoutException extends TimeoutException {
  PhaseTimeoutException(
    this.phase, [
    String? message,
    Duration? duration,
  ]) : super(message ?? 'Practice speech phase deadline.', duration);

  /// Which phase's allowance expired:
  /// [CourseAudioFailureReason.startupTimeout] for the setup phase,
  /// [CourseAudioFailureReason.completionTimeout] for the utterance phase.
  final CourseAudioFailureReason phase;
}

/// Injectable playback bounds. Defaults come from the approved spec; [validate]
/// rejects any nonpositive injection before the values are used.
final class CourseAudioDeadlines {
  const CourseAudioDeadlines({
    this.setup = const Duration(seconds: 10),
    this.cleanup = const Duration(seconds: 5),
    this.completionFloor = const Duration(seconds: 10),
    this.completionSlack = const Duration(seconds: 5),
    this.ttsUtterance = const Duration(seconds: 12),
  });

  /// Catalogue/setup allowance before starting audio.
  final Duration setup;

  /// Stop/cleanup allowance.
  final Duration cleanup;

  /// Fixed minimum recording-completion bound.
  final Duration completionFloor;

  /// Slack added to the declared duration for the completion bound.
  final Duration completionSlack;

  /// Existing TTS utterance bound.
  final Duration ttsUtterance;

  /// Recording completion bound: `max(completionFloor, declared duration +
  /// completionSlack)` after resume dispatch.
  Duration recordingCompletion(Duration duration) {
    final withSlack = duration + completionSlack;
    return withSlack > completionFloor ? withSlack : completionFloor;
  }

  /// Every injected deadline must be positive. Called at facade/speech-factory
  /// construction before the deadlines are used, without constructing an
  /// engine.
  void validate() {
    if (setup <= Duration.zero) {
      throw ArgumentError.value(setup, 'setup', 'must be positive');
    }
    if (cleanup <= Duration.zero) {
      throw ArgumentError.value(cleanup, 'cleanup', 'must be positive');
    }
    if (completionFloor <= Duration.zero) {
      throw ArgumentError.value(
          completionFloor, 'completionFloor', 'must be positive');
    }
    if (completionSlack <= Duration.zero) {
      throw ArgumentError.value(
          completionSlack, 'completionSlack', 'must be positive');
    }
    if (ttsUtterance <= Duration.zero) {
      throw ArgumentError.value(
          ttsUtterance, 'ttsUtterance', 'must be positive');
    }
  }
}

/// One already validated bundled recording; never a remote source or TTS.
final class CourseAudioRecording {
  CourseAudioRecording({
    required this.assetKey,
    required this.byteLength,
    required this.duration,
    required this.source,
  }) {
    if (source == CourseAudioSource.practiceTts) {
      throw StateError(
          'a bundled recording must never be a remote source or TTS');
    }
    if (assetKey.contains('://')) {
      throw StateError(
          'a bundled recording must reference a packaged asset, not a URL');
    }
  }

  /// The packaged asset key after the repository-to-asset conversion.
  final String assetKey;
  final int byteLength;
  final Duration duration;
  final CourseAudioSource source;
}
