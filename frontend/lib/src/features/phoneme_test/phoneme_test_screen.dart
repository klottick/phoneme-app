import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/providers/app_providers.dart';
import '../../core/course/french_course.dart';
import '../../core/services/recording_service.dart'
    hide recordingServiceProvider;
import '../../core/services/tts_service.dart';
import '../../core/services/phoneme_assessment_service.dart';

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
  bool _wordMode = false;
  String? _sampleWord;
  String? _wordRecordingPath;
  String? _wordAssessmentResult;
  bool _hasWordRecording = false;

  String? _getSampleWord(String phoneme) {
    final words = frenchWords
        .where((w) => w.contains(phoneme))
        .map((w) => w.text)
        .toList();
    if (words.isNotEmpty) {
      words.shuffle();
      return words.first;
    }
    return null;
  }

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
                  _wordMode ? 'Say this word:' : 'Say this phoneme:',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Text(
                          _wordMode && _sampleWord != null
                              ? _sampleWord!
                              : current.ipaSymbol,
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          current.descriptor,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filled(
                              icon: Icon(
                                  _isRecording ? Icons.stop : Icons.volume_up),
                              iconSize: 32,
                              onPressed: _isRecording
                                  ? null
                                  : () => _playPhoneme(current.ipaSymbol),
                              tooltip: 'Listen',
                            ),
                            const SizedBox(width: 16),
                            if (_wordMode) ...[
                              IconButton.filled(
                                icon: Icon(_isRecording
                                    ? Icons.stop
                                    : Icons.volume_down),
                                iconSize: 32,
                                onPressed: _isRecording
                                    ? null
                                    : () => _playWord(_sampleWord),
                                tooltip: 'Listen Word',
                              ),
                            ],
                            const SizedBox(width: 16),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _showHint = !_showHint),
                              child:
                                  Text(_showHint ? 'Hide Hint' : 'Show Hint'),
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
                    if (_wordMode) ...[
                      const SizedBox(width: 16),
                      FloatingActionButton.large(
                        heroTag: 'record_word',
                        onPressed: (_isRecording || !_wordMode)
                            ? null
                            : _toggleWordRecording,
                        backgroundColor:
                            _isRecording && _wordMode ? Colors.red : null,
                        child: Icon(
                          _isRecording && _wordMode
                              ? Icons.stop
                              : Icons.record_voice_over,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _isRecording
                      ? 'Recording...'
                      : _hasRecording
                          ? 'Recording saved!'
                          : _wordMode
                              ? 'Tap to say the word "$_sampleWord"'
                              : 'Tap to say the phoneme',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_hasRecording && !_isRecording) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton(
                        onPressed:
                            _wordMode ? _assessWordRecording : _assessRecording,
                        child: const Text('Check'),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _hasRecording = false;
                            _recordingPath = null;
                            _assessmentResult = null;
                            _hasWordRecording = false;
                            _wordRecordingPath = null;
                            _wordAssessmentResult = null;
                          });
                        },
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ],
                if (_assessmentResult != null ||
                    _wordAssessmentResult != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (_assessmentResult ?? _wordAssessmentResult)!
                              .startsWith('✓')
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _wordMode ? _wordAssessmentResult! : _assessmentResult!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: (_assessmentResult ?? _wordAssessmentResult)!
                                .startsWith('✓')
                            ? Colors.green
                            : Colors.orange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _nextPhoneme,
                    child: const Text('Next'),
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
    await tts.speak(_getSampleWord(phoneme) ?? 'tout', languageCode: 'fr');
  }

  Future<void> _playWord(String? word) async {
    if (word == null) return;
    final tts = ref.read(ttsServiceProvider);
    await tts.speak(word, languageCode: 'fr');
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
    _recordingPath =
        '${dir.path}/phoneme_test_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await recorder.startRecording(_recordingPath!);

    setState(() {
      _isRecording = true;
      _hasRecording = false;
      _assessmentResult = null;
    });
  }

  Future<void> _stopRecording() async {
    final recorder = ref.read(recordingServiceProvider);
    await recorder.stopRecording();

    setState(() {
      _isRecording = false;
      _hasRecording = true;
    });
  }

  Future<void> _toggleWordRecording() async {
    if (_isRecording) {
      await _stopWordRecording();
    } else {
      await _startWordRecording();
    }
  }

  Future<void> _startWordRecording() async {
    final word = _getSampleWord(
      ref
          .read(phonemesProvider)
          .asData!
          .value[_index % ref.read(phonemesProvider).asData!.value.length]
          .ipaSymbol,
    );
    if (word == null) return;

    final recorder = ref.read(recordingServiceProvider);
    final dir = await getApplicationDocumentsDirectory();
    _wordRecordingPath =
        '${dir.path}/phoneme_word_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await recorder.startRecording(_wordRecordingPath!);
    _sampleWord = word;

    setState(() {
      _isRecording = true;
      _wordMode = true;
      _hasWordRecording = false;
      _wordAssessmentResult = null;
    });
  }

  Future<void> _stopWordRecording() async {
    final recorder = ref.read(recordingServiceProvider);
    await recorder.stopRecording();

    setState(() {
      _isRecording = false;
      _hasWordRecording = true;
    });
  }

  Future<void> _assessRecording() async {
    if (_recordingPath == null) return;

    final file = File(_recordingPath!);
    if (!await file.exists()) {
      if (!mounted) return;
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
      _assessmentResult =
          '${assessment.score.toInt()}% - ${assessment.feedback}';
    });
  }

  Future<void> _assessWordRecording() async {
    if (_wordRecordingPath == null) return;

    final file = File(_wordRecordingPath!);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording file not found')),
      );
      return;
    }

    final phonemes = ref.read(phonemesProvider).valueOrNull ?? [];
    final current =
        phonemes.isNotEmpty ? phonemes[_index % phonemes.length] : null;
    final expectedPhoneme = current?.ipaSymbol ?? 'æ';
    final languageCode = ref.read(selectedLanguageCodeProvider);

    final analyzer = ref.read(phonemeAssessmentServiceProvider);
    final assessment = await analyzer.analyze(
      recordingPath: _wordRecordingPath!,
      expectedPhoneme: expectedPhoneme,
      languageCode: languageCode,
    );

    setState(() {
      _total++;
      if (assessment.isCorrect) _correct++;
      _wordAssessmentResult =
          '${assessment.score.toInt()}% - ${assessment.feedback} (Word: $_sampleWord)';
    });
  }

  void _nextPhoneme() {
    setState(() {
      _index++;
      _hasRecording = false;
      _recordingPath = null;
      _assessmentResult = null;
      _showHint = false;
      _wordMode = false;
      _sampleWord = null;
      _hasWordRecording = false;
      _wordRecordingPath = null;
      _wordAssessmentResult = null;
    });
  }
}
