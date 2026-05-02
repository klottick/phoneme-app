import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<String?> startRecording(String sessionId) async {
    if (!await hasPermission()) return null;

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/recordings/$sessionId.wav';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav),
      path: path,
    );
    return path;
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    return path;
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  Future<void> cancel() async {
    await _recorder.stop();
  }

  void dispose() {
    _recorder.dispose();
  }
}

final recordingServiceProvider = Provider<RecordingService>((ref) {
  final service = RecordingService();
  ref.onDispose(() => service.dispose());
  return service;
});