import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phonemes = ref.watch(phonemesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: phonemes.when(
        data: (items) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Daily Goal'),
                  subtitle: const Text('Complete 10 discrimination items'),
                  trailing: const Text('2 / 10'),
                ),
              ),
              const SizedBox(height: 12),
              ...items.map(
                (p) => Card(
                  child: ListTile(
                    title: Text(p.ipaSymbol),
                    subtitle: Text(p.descriptor),
                    trailing: const Text('Mastery 0.00'),
                  ),
                ),
              ),
            ],
          );
        },
        error: (error, _) => Center(child: Text('Failed to load progress: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
