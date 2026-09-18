import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/tts_service.dart';
import '../../core/course/french_course.dart';

class IpaExplorerScreen extends ConsumerWidget {
  const IpaExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPhonemes = ref.watch(phonemesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('IPA Explorer')),
      body: asyncPhonemes.when(
        data: (phonemes) {
          if (phonemes.isEmpty) {
            return const Center(child: Text('No phonemes available yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: phonemes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = phonemes[index];
              return Card(
                child: ListTile(
                  title: Text(item.ipaSymbol,
                      style: const TextStyle(fontSize: 24)),
                  subtitle: Text(item.descriptor),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.volume_up),
                        tooltip: 'Play with TTS',
                        onPressed: () =>
                            _speakPhoneme(ref, item.ipaSymbol, item.descriptor),
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        tooltip: 'Play audio',
                        onPressed: () => _playAudio(ref, item),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        error: (error, _) =>
            Center(child: Text('Failed to load phonemes: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _speakPhoneme(
      WidgetRef ref, String ipaSymbol, String descriptor) async {
    final tts = ref.read(ttsServiceProvider);
    final word = frenchWords.firstWhere((w) => w.contains(ipaSymbol));
    await tts.speak(word.text, languageCode: 'fr');
  }

  Future<void> _playAudio(WidgetRef ref, dynamic phoneme) async {
    await _speakPhoneme(ref, phoneme.ipaSymbol, phoneme.descriptor);
  }
}
