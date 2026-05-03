import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/providers/app_providers.dart';

class SpeakScreen extends ConsumerStatefulWidget {
  const SpeakScreen({super.key});

  @override
  ConsumerState<SpeakScreen> createState() => _SpeakScreenState();
}

class _SpeakScreenState extends ConsumerState<SpeakScreen> {
  bool _isRecording = false;
  bool _hasRecording = false;
  String? _recordingPath;
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final pairs = ref.watch(minimalPairsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Speaking Practice')),
      body: pairs.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No practice items yet.'));
          }

          final index = DateTime.now().millisecondsSinceEpoch % items.length;
          final current = items[index];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Say this word:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          current.wordA,
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '(${current.phonemeA})',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton.large(
                      heroTag: 'record',
                      onPressed: _toggleRecording,
                      backgroundColor: _isRecording ? Colors.red : null,
                      child: Icon(_isRecording ? Icons.stop : Icons.mic),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _isRecording
                      ? 'Recording...'
                      : _hasRecording
                          ? 'Recording saved'
                          : 'Tap to record',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_hasRecording && !_isRecording) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                        iconSize: 32,
                        onPressed: _togglePlayback,
                      ),
                      const SizedBox(width: 16),
                      IconButton.filled(
                        icon: const Icon(Icons.refresh),
                        iconSize: 32,
                        onPressed: () {
                          setState(() {
                            _hasRecording = false;
                            _recordingPath = null;
                          });
                        },
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                if (!_isRecording) ...[
                  FilledButton(
                    onPressed: _hasRecording ? _nextWord : null,
                    child: const Text('Next Word'),
                  ),
                ],
              ],
            ),
          );
        },
        error: (error, _) => Center(child: Text('Failed to load: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    final recorder = ref.read(recordingServiceProvider);

    if (_isRecording) {
      final path = await recorder.stopRecording();
      setState(() {
        _isRecording = false;
        _hasRecording = path != null;
        _recordingPath = path;
      });
    } else {
      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/practice_${DateTime.now().millisecondsSinceEpoch}.wav';
      await recorder.startRecording(path);
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _togglePlayback() async {
    // TODO: Implement playback of recorded audio
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  Future<void> _nextWord() async {
    await ref.read(streakServiceProvider).recordPractice();
    setState(() {
      _hasRecording = false;
      _recordingPath = null;
    });
  }
}