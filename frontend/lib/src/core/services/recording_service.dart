import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

class RecordingService {
  AudioRecorder? _recorder;

  Future<bool> hasPermission() async {
    final recorder = _recorder ?? AudioRecorder();
    return await recorder.hasPermission();
  }

  Future<void> startRecording(String path) async {
    _recorder = AudioRecorder();
    if (await hasPermission()) {
      await _recorder!.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );
    }
  }

  Future<String?> stopRecording() async {
    if (_recorder != null) {
      final path = await _recorder!.stop();
      return path;
    }
    return null;
  }

  Future<bool> isRecording() async {
    if (_recorder != null) {
      return await _recorder!.isRecording();
    }
    return false;
  }

  Future<void> cancel() async {
    if (_recorder != null) {
      await _recorder!.stop();
    }
  }

  void dispose() {
    _recorder?.dispose();
  }
}

final recordingServiceProvider = Provider<RecordingService>((ref) {
  final service = RecordingService();
  ref.onDispose(() => service.dispose());
  return service;
});