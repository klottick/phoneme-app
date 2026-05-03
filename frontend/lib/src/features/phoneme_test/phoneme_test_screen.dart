import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/tts_service.dart';

class PhonemeTestScreen extends ConsumerStatefulWidget {
  const PhonemeTestScreen({super.key});

  @override
  ConsumerState<PhonemeTestScreen> createState() => _PhonemeTestScreenState();
}

class _PhonemeTestScreenState extends ConsumerState<PhonemeTestScreen> {
  int _index = 0;
  int _correct = 0;
  int _total = 0;
  bool _isRecording = false;
  bool _hasRecording = false;
  bool _showHint = false;
  String? _recordingPath;
  String? _assessmentResult;

  @override
  Widget build(BuildContext context) {
    final phonemes = ref.watch(phonemesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phoneme Test'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_correct / $_total',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: phonemes.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No phonemes available.'));
          }

          final current = items[_index % items.length];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  'Say this phoneme:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Text(
                          current.ipaSymbol,
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          current.descriptor,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filled(
                              icon: const Icon(Icons.volume_up),
                              iconSize: 32,
                              onPressed: () => _playPhoneme(current.ipaSymbol),
                              tooltip: 'Listen',
                            ),
                            const SizedBox(width: 16),
                            TextButton(
                              onPressed: () => setState(() => _showHint = !_showHint),
                              child: Text(_showHint ? 'Hide Hint' : 'Show Hint'),
                            ),
                          ],
                        ),
                        if (_showHint) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              current.descriptor,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
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
                          ? 'Recording saved!'
                          : 'Tap to say the phoneme',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_hasRecording && !_isRecording) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: _assessRecording,
                        child: const Text('Check'),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _hasRecording = false;
                            _recordingPath = null;
                            _assessmentResult = null;
                          });
                        },
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ],
                if (_assessmentResult != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _assessmentResult!.startsWith('✓')
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _assessmentResult!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _assessmentResult!.startsWith('✓') ? Colors.green : Colors.orange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _nextPhoneme,
                    child: const Text('Next Phoneme'),
                  ),
                ],
              ],
            ),
          );
        },
        error: (error, _) => Center(child: Text('Failed: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _playPhoneme(String phoneme) async {
    final tts = ref.read(ttsServiceProvider);
    await tts.speak(phoneme);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final recorder = ref.read(recordingServiceProvider);
    
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/phoneme_test_${DateTime.now().millisecondsSinceEpoch}.m4a';
    
    await recorder.startRecording(path);
    
    setState(() {
      _isRecording = true;
      _hasRecording = false;
      _assessmentResult = null;
    });
  }

  Future<void> _stopRecording() async {
    final recorder = ref.read(recordingServiceProvider);
    
    await recorder.stopRecording();
    
    final dir = await getApplicationDocumentsDirectory();
    _recordingPath = '${dir.path}/phoneme_test_${DateTime.now().millisecondsSinceEpoch}.m4a';
    
    setState(() {
      _isRecording = false;
      _hasRecording = true;
    });
  }

  Future<void> _assessRecording() async {
    if (_recordingPath == null) return;
    
    final file = File(_recordingPath!);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording file not found')),
      );
      return;
    }
    
    final pairs = ref.read(phonemesProvider).valueOrNull ?? [];
    final currentPair = pairs.isNotEmpty ? pairs[_index % pairs.length] : null;
    final expectedPhoneme = currentPair?.ipaSymbol ?? 'æ';
    final languageCode = ref.read(selectedLanguageCodeProvider);
    
    final analyzer = ref.read(phonemeAssessmentServiceProvider);
    final assessment = await analyzer.analyze(
      recordingPath: _recordingPath!,
      expectedPhoneme: expectedPhoneme,
      languageCode: languageCode,
    );
    
    setState(() {
      _total++;
      if (assessment.isCorrect) _correct++;
      _assessmentResult = '${assessment.score.toInt()}% - ${assessment.feedback}';
    });
  }

  void _nextPhoneme() {
    setState(() {
      _index++;
      _hasRecording = false;
      _recordingPath = null;
      _assessmentResult = null;
      _showHint = false;
    });
  }
}