import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/tts_service.dart';

class PhonemeIdentifyScreen extends ConsumerStatefulWidget {
  const PhonemeIdentifyScreen({super.key});

  @override
  ConsumerState<PhonemeIdentifyScreen> createState() => _PhonemeIdentifyScreenState();
}

class _PhonemeIdentifyScreenState extends ConsumerState<PhonemeIdentifyScreen> {
  int _index = 0;
  int _correct = 0;
  int _total = 0;
  bool _isPlaying = false;
  String? _lastResult;
  bool _answered = false;

  @override
  Widget build(BuildContext context) {
    final phonemes = ref.watch(phonemesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phoneme Identification'),
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
          final allPhonemes = items.map((p) => p.ipaSymbol).toList()..shuffle(Random());
          final options = (allPhonemes.take(4).toList()..add(current.ipaSymbol)).toSet().take(4).toList()..shuffle(Random());

          final displayOptions = options.length >= 4 ? options : allPhonemes.take(4).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  'Listen and select the phoneme you hear:',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        IconButton.filled(
                          icon: Icon(_isPlaying ? Icons.stop : Icons.volume_up),
                          iconSize: 48,
                          onPressed: _isPlaying ? null : () => _playPhoneme(current.ipaSymbol),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tap to play',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2,
                    children: displayOptions.map((phoneme) {
                      final isSelected = _lastResult != null && phoneme == current.ipaSymbol;
                      final isCorrect = phoneme == current.ipaSymbol;
                      
                      Color? bgColor;
                      if (_lastResult != null) {
                        if (isCorrect) {
                          bgColor = Colors.green;
                        } else if (isSelected && !isCorrect) {
                          bgColor = Colors.red;
                        }
                      }
                                            
                      return FilledButton.tonal(
                        onPressed: _answered ? null : () => _handleAnswer(phoneme, current.ipaSymbol),
                        style: FilledButton.styleFrom(
                          backgroundColor: bgColor,
                        ),
                        child: Text(
                          phoneme,
                          style: const TextStyle(fontSize: 24),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (_lastResult != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _lastResult!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _lastResult!.startsWith('✓') ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _nextQuestion,
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
    setState(() => _isPlaying = true);
    
    final tts = ref.read(ttsServiceProvider);
    await tts.speak(phoneme);
    
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  void _handleAnswer(String selected, String correct) async {
    final isCorrect = selected == correct;
    setState(() {
      _total++;
      if (isCorrect) _correct++;
      _lastResult = isCorrect ? '✓ Correct: $correct' : '✗ It was: $correct';
      _answered = true;
    });
  }

  void _nextQuestion() {
    setState(() {
      _index++;
      _lastResult = null;
      _answered = false;
    });
  }
}