import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';

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
                  title: Text(item.ipaSymbol, style: const TextStyle(fontSize: 24)),
                  subtitle: Text(item.descriptor),
                  trailing: FilledButton.tonal(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Audio play planned for ${item.ipaSymbol}')),
                      );
                    },
                    child: const Text('Play'),
                  ),
                ),
              );
            },
          );
        },
        error: (error, _) => Center(child: Text('Failed to load phonemes: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
