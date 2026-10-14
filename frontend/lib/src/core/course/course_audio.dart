import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'course_audio_contract.dart';

export 'course_audio_contract.dart';

/// French TTS adapter.
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
///   timeout), an abandoned request drains the failure quietly while the
///   *current* owner rethrows the same error with its original stack trace,
///   preserving the unavailable-voice, explicit-failure, platform-error and
///   timeout semantics.
///
/// Overlapping [speak] calls always converge on the newest request.
class FrenchWordAudio implements CourseAudio {
  final FlutterTts _tts = FlutterTts();

  /// Ownership token: each [speak] increments it to claim the request, and
  /// [stop] increments it to invalidate the current setup and utterance.
  int _current = 0;

  @override
  Future<void> speak(String word) async {
    final mine = ++_current;
    try {
      if (await _tts.isLanguageAvailable('fr-FR') != true) {
        if (mine != _current) return; // Abandoned: drain the failure quietly.
        throw StateError(
            'Install a French voice in your device speech settings.');
      }
      if (mine != _current) return; // Abandoned before running setup.

      // Replace any utterance still in progress (owner only).
      await _tts.stop();
      if (mine != _current) return;

      await _tts.setLanguage('fr-FR');
      if (mine != _current) return;

      await _tts.setSpeechRate(0.4);
      if (mine != _current) return;

      await _tts.awaitSpeakCompletion(true);
      // Do not start an abandoned utterance even though completion is set.
      if (mine != _current) return;

      final result =
          await _tts.speak(word).timeout(const Duration(seconds: 12));
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
      // Current owner: keep the exact error and original stack trace.
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> stop() async {
    // Invalidate the current setup before touching the platform, so a queued
    // setup cannot start speaking once it resumes.
    _current++;
    await _tts.stop();
  }
}

final courseAudioProvider = Provider<CourseAudio>((ref) {
  final audio = FrenchWordAudio();
  ref.onDispose(() {
    audio.stop().catchError((Object _) {});
  });
  return audio;
});
