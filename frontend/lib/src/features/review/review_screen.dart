import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(dueReviewItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Due Review')),
      body: items.when(
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('No due items. Great consistency.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final item = rows[index];
              return Card(
                child: ListTile(
                  title: Text('${item.ipaSymbol} (${item.languageCode})'),
                  subtitle: Text(item.descriptor),
                  trailing: Text(item.dueAt.toLocal().toString().split('.').first),
                ),
              );
            },
          );
        },
        error: (error, _) => Center(child: Text('Failed to load reviews: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
