import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/tts_service.dart';

class AudioCompareScreen extends ConsumerStatefulWidget {
  const AudioCompareScreen({super.key});

  @override
  ConsumerState<AudioCompareScreen> createState() => _AudioCompareScreenState();
}

class _AudioCompareScreenState extends ConsumerState<AudioCompareScreen> {
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isPlayingUser = false;
  String? _userRecordingPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Comparison')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Compare your pronunciation with the reference',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 32),
            _buildReferenceCard(context),
            const SizedBox(height: 24),
            _buildUserRecordingCard(context),
            const SizedBox(height: 24),
            _buildComparisonCard(context),
            const SizedBox(height: 24),
            _buildInstructions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.volume_up, size: 48, color: Colors.blue),
            const SizedBox(height: 12),
            Text(
              'French reference: tu /ty/ (TTS)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isPlaying ? null : _playReference,
              icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
              label: Text(
                _isPlaying ? 'Reference audio is playing' : 'Play Reference',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRecordingCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.mic, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              'Your Recording',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (_userRecordingPath != null) ...[
              FilledButton.icon(
                onPressed: _isPlayingUser ? null : _playUserRecording,
                icon: Icon(_isPlayingUser ? Icons.stop : Icons.play_arrow),
                label:
                    Text(
                      _isPlayingUser
                          ? 'Your recording is playing'
                          : 'Play Your Recording',
                    ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _clearRecording,
                icon: const Icon(Icons.delete),
                label: const Text('Clear'),
              ),
            ] else ...[
              FloatingActionButton.large(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                tooltip: _isRecording
                    ? 'Stop recording your pronunciation'
                    : 'Record your pronunciation',
                backgroundColor: _isRecording ? Colors.red : null,
                child: Icon(_isRecording ? Icons.stop : Icons.mic),
              ),
              const SizedBox(height: 12),
              Text(_isRecording ? 'Recording...' : 'Tap to record'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard(BuildContext context) {
    if (_userRecordingPath == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.compare_arrows, size: 48, color: Colors.green),
            const SizedBox(height: 12),
            Text(
              'Side-by-Side Comparison',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _playBoth,
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Play Both'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions(BuildContext context) {
    return Card(
      color: Colors.teal.withValues(alpha: 0.1),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to use:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Play the reference to hear the correct pronunciation'),
            Text('2. Record yourself saying the same phoneme/word'),
            Text('3. Play both recordings to compare'),
            Text('4. Listen for differences in clarity and tone'),
          ],
        ),
      ),
    );
  }

  Future<void> _playReference() async {
    setState(() => _isPlaying = true);
    final tts = ref.read(ttsServiceProvider);
    await tts.speak('tu', languageCode: 'fr');
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _playUserRecording() async {
    if (_userRecordingPath == null) return;
    setState(() => _isPlayingUser = true);
    final audio = ref.read(audioServiceProvider);
    await audio.play(_userRecordingPath!);
    if (mounted) {
      setState(() => _isPlayingUser = false);
    }
  }

  Future<void> _playBoth() async {
    setState(() => _isPlaying = true);
    final tts = ref.read(ttsServiceProvider);
    await tts.speak('tu', languageCode: 'fr');
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _isPlaying = false);
    setState(() => _isPlayingUser = true);
    final audio = ref.read(audioServiceProvider);
    await audio.play(_userRecordingPath!);
    if (mounted) {
      setState(() => _isPlayingUser = false);
    }
  }

  Future<void> _startRecording() async {
    final recorder = ref.read(recordingServiceProvider);
    final path =
        '/storage/emulated/0/linguist/compare_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await recorder.startRecording(path);
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    final recorder = ref.read(recordingServiceProvider);
    await recorder.stopRecording();
    setState(() {
      _isRecording = false;
      _userRecordingPath =
          '/storage/emulated/0/linguist/compare_${DateTime.now().millisecondsSinceEpoch}.m4a';
    });
  }

  void _clearRecording() {
    setState(() => _userRecordingPath = null);
  }
}
