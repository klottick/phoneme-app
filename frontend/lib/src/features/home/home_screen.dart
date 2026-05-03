import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/supported_languages.dart';
import '../../core/providers/app_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(selectedLanguageCodeProvider);
    final languageLabel = supportedLanguages
        .firstWhere((l) => l.code == code, orElse: () => supportedLanguages.first)
        .label;

    return Scaffold(
      appBar: AppBar(title: const Text('Linguist')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
children: <Widget>[
            FutureBuilder<List<int>>(
              future: Future.wait([
                ref.read(streakServiceProvider).getCurrentStreak(),
                ref.read(streakServiceProvider).getLongestStreak(),
              ]),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return _buildStreakCard(snapshot.data![0], snapshot.data![1]);
                }
                return const Card(child: ListTile(title: Text('Loading streak...')));
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Current track: $languageLabel',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Today\'s Plan',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• 3 minimal-pair listening drills'),
            const Text('• 1 quick IPA review set'),
            const Text('• 1 adaptive weak-sound review'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(onPressed: () => context.push('/profile'), child: const Text('Profile')),
                FilledButton(onPressed: () => context.push('/settings'), child: const Text('Settings')),
                FilledButton(onPressed: () => context.push('/speak'), child: const Text('Speaking')),
                FilledButton(onPressed: () => context.push('/ipa'), child: const Text('IPA Explorer')),
                FilledButton(onPressed: () => context.push('/drill'), child: const Text('Listening Drill')),
                FilledButton(onPressed: () => context.push('/phoneme-id'), child: const Text('Phoneme ID')),
                FilledButton(onPressed: () => context.push('/phoneme-test'), child: const Text('Phoneme Test')),
                FilledButton(onPressed: () => context.push('/compare'), child: const Text('Audio Compare')),
                FilledButton(onPressed: () => context.push('/lessons'), child: const Text('Lessons')),
                FilledButton(onPressed: () => context.push('/analytics'), child: const Text('Analytics')),
                FilledButton(onPressed: () => context.push('/insights'), child: const Text('Insights')),
                FilledButton(onPressed: () => context.push('/modes'), child: const Text('Challenge')),
                FilledButton(onPressed: () => context.push('/custom'), child: const Text('Custom')),
                FilledButton(onPressed: () => context.push('/export'), child: const Text('Export')),
                FilledButton(onPressed: () => context.push('/review'), child: const Text('Due Review')),
                FilledButton(onPressed: () => context.push('/progress'), child: const Text('Progress')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(int currentStreak, int longestStreak) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text('Current', style: TextStyle(color: Colors.grey)),
                Text('$currentStreak', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('day streak'),
              ],
            ),
            Column(
              children: [
                const Text('Longest', style: TextStyle(color: Colors.grey)),
                Text('$longestStreak', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('day streak'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
