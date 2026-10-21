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
              const Card(
                child: ListTile(
                  title: Text('Daily Goal'),
                  subtitle: Text('Daily goal tracking is not available.'),
                ),
              ),
              const SizedBox(height: 12),
              ...items.map(
                (p) => Card(
                  child: ListTile(
                    title: Text(p.ipaSymbol),
                    subtitle: Text(p.descriptor),
                    trailing: const Text('Mastery not measured'),
                  ),
                ),
              ),
            ],
          );
        },
        error: (error, _) =>
            Center(child: Text('Failed to load progress: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
