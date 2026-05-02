import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused }

class TtsService {
  final FlutterTts _tts = FlutterTts();
  TtsState _state = TtsState.stopped;

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.4);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _state = TtsState.stopped;
    });

    _tts.setCancelHandler(() {
      _state = TtsState.stopped;
    });

    _tts.setErrorHandler((msg) {
      _state = TtsState.stopped;
    });
  }

  Future<void> speak(String text, {String? languageCode}) async {
    if (languageCode != null) {
      await _tts.setLanguage(_mapToTtsLanguage(languageCode));
    }
    _state = TtsState.playing;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _state = TtsState.stopped;
  }

  Future<void> pause() async {
    await _tts.pause();
    _state = TtsState.paused;
  }

  bool get isPlaying => _state == TtsState.playing;

  String _mapToTtsLanguage(String code) {
    const map = {
      'en': 'en-US',
      'fr': 'fr-FR',
      'ja': 'ja-JP',
      'es': 'es-ES',
      'de': 'de-DE',
      'zh': 'zh-CN',
      'ko': 'ko-KR',
    };
    return map[code] ?? 'en-US';
  }

  void dispose() {
    _tts.stop();
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
});