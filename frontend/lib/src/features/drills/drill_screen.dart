import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';

class DrillScreen extends ConsumerStatefulWidget {
  const DrillScreen({super.key});

  @override
  ConsumerState<DrillScreen> createState() => _DrillScreenState();
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
