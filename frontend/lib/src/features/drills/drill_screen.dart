import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/streak_service.dart';

class DrillScreen extends ConsumerStatefulWidget {
  const DrillScreen({super.key});

  @override
  ConsumerState<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends ConsumerState<DrillScreen> {
  int _index = 0;
  int _correct = 0;
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final pairs = ref.watch(minimalPairsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minimal Pair Drill'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_correct / ${_index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: pairs.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No drill items yet.'));
          }

          final current = items[_index % items.length];
          final options = <String>[current.wordA, current.wordB]..shuffle(Random());

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item ${_index + 1}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Listen and choose the word you hear.'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '${current.phonemeA} vs ${current.phonemeB}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                      iconSize: 36,
                      tooltip: 'Play audio',
                      onPressed: () => _playAudio(current),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                for (final option in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () => _handleAnswer(option, current.wordA, current, items),
                        child: Text(option, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                const Spacer(),
                Center(
                  child: TextButton(
                    onPressed: _endSession,
                    child: const Text('End Session'),
                  ),
                ),
              ],
            ),
          );
        },
        error: (error, _) => Center(child: Text('Failed to load drills: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _playAudio(dynamic currentPair) async {
    setState(() => _isPlaying = true);
    final audio = ref.read(audioServiceProvider);
    
    // TODO: Use real Supabase storage URL when audio assets are uploaded
    // For now, show instruction to user
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audio playback: Connect audio files in Supabase Storage to enable'),
        duration: Duration(seconds: 2),
      ),
    );
    
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _handleAnswer(
    String selected,
    String correct,
    dynamic currentPair,
    List items,
  ) async {
    final isCorrect = selected == correct;
    if (isCorrect) {
      _correct++;
    }

    final phonemes = await ref.read(phonemesProvider.future);
    final phonemeId = phonemes.isNotEmpty ? phonemes.first.id : 'placeholder-phoneme';

    await ref.read(progressRepositoryProvider).submitAttempt(
      lessonId: 'lesson-minimal-pairs',
      phonemeId: phonemeId,
      minimalPairId: currentPair.id,
      isCorrect: isCorrect,
      responseTimeMs: 900,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isCorrect ? '✓ Correct' : '✗ Try: $correct'),
        backgroundColor: isCorrect ? Colors.green : Colors.orange,
      ),
    );

    setState(() {
      _index++;
    });
  }

  Future<void> _endSession() async {
    await ref.read(streakServiceProvider).recordPractice();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Session complete! $_correct / ${_index + 1} correct'),
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _DrillScreenState extends ConsumerState<DrillScreen> {
  int _index = 0;
  int _correct = 0;

  @override
  Widget build(BuildContext context) {
    final pairs = ref.watch(minimalPairsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Minimal Pair Drill')),
      body: pairs.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No drill items yet.'));
          }

          final current = items[_index % items.length];
          final options = <String>[current.wordA, current.wordB]..shuffle(Random());

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Item ${_index + 1}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Listen and choose the word you hear.'),
                const SizedBox(height: 16),
                Text('${current.phonemeA} vs ${current.phonemeB}',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                for (final option in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FilledButton.tonal(
                      onPressed: () async {
                        final isCorrect = option == current.wordA;
                        if (isCorrect) {
                          _correct += 1;
                        }

                        final phonemes = await ref.read(phonemesProvider.future);
                        final phonemeId = phonemes.isNotEmpty ? phonemes.first.id : 'placeholder-phoneme';

                        await ref.read(progressRepositoryProvider).submitAttempt(
                              lessonId: 'lesson-minimal-pairs',
                              phonemeId: phonemeId,
                              minimalPairId: current.id,
                              isCorrect: isCorrect,
                              responseTimeMs: 900,
                            );

                        if (!mounted) {
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isCorrect ? 'Correct' : 'Try again')),
                        );

                        setState(() {
                          _index += 1;
                        });
                      },
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(option, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                const Spacer(),
                Text('Correct so far: $_correct / ${_index + 1}'),
              ],
            ),
          );
        },
        error: (error, _) => Center(child: Text('Failed to load drills: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
