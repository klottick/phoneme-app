import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioService {
  final Map<String, AudioPlayer> _players = {};

  Future<void> playPhoneme(String phonemeId, String audioUrl) async {
    await _play(phonemeId, audioUrl);
  }

  Future<void> playMinimalPair(String pairId, String audioUrl) async {
    await _play(pairId, audioUrl);
  }

  Future<void> _play(String id, String url) async {
    final player = _players.putIfAbsent(id, () => AudioPlayer());
    await player.stop();
    await player.play(UrlSource(url));
  }

  Future<void> stopAll() async {
    for (final player in _players.values) {
      await player.stop();
    }
  }

  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});