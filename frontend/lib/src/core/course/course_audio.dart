import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract class CourseAudio {
  Future<void> speak(String word);
  Future<void> stop();
}

class FrenchWordAudio implements CourseAudio {
  final FlutterTts _tts = FlutterTts();
  @override
  Future<void> speak(String word) async {
    if (await _tts.isLanguageAvailable('fr-FR') != true) {
      throw StateError(
          'Install a French voice in your device speech settings.');
    }
    await _tts.stop();
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.4);
    await _tts.awaitSpeakCompletion(true);
    final result = await _tts.speak(word).timeout(const Duration(seconds: 12));
    // With awaitSpeakCompletion enabled, web resolves with null on completion;
    // native implementations return 1. Explicit failure codes still fail, and
    // platform exceptions or missing completion still propagate above.
    if (result != null && result != 1) {
      throw StateError('French audio could not be played.');
    }
  }

  @override
  Future<void> stop() async {
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
