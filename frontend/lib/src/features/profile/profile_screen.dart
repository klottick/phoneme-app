import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/auth_service.dart';
import '../../core/providers/app_providers.dart';
import '../../core/constants/supported_languages.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final languageCode = ref.watch(selectedLanguageCodeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    child: Text(
                      user?.email?.substring(0, 1).toUpperCase() ?? '?',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.email ?? 'Not signed in',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 4),
                    Chip(
                      label: const Text('Verified'),
                      backgroundColor: Colors.green.shade100,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<int>>(
            future: Future.wait([
              ref.read(streakServiceProvider).getCurrentStreak(),
              ref.read(streakServiceProvider).getLongestStreak(),
              _getTotalPracticeCount(ref),
            ]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Card(
                  child: ListTile(
                    title: Text('Loading stats...'),
                  ),
                );
              }

              final currentStreak = snapshot.data![0];
              final longestStreak = snapshot.data![1];
              final totalPractice = snapshot.data![2];

              return Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            context,
                            '🔥',
                            '$currentStreak',
                            'Day Streak',
                          ),
                          _buildStatItem(
                            context,
                            '🏆',
                            '$longestStreak',
                            'Best',
                          ),
                          _buildStatItem(
                            context,
                            '📚',
                            '$totalPractice',
                            'Sessions',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (user != null) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Learning'),
                subtitle: Text(
                  supportedLanguages
                      .firstWhere((l) => l.code == languageCode,
                          orElse: () => supportedLanguages.first)
                      .label,
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign Out?'),
                      content: const Text('Your progress will be saved.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref.read(authControllerProvider.notifier).signOut();
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context, String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<int> _getTotalPracticeCount(WidgetRef ref) async {
    try {
      return 0;
    } catch (_) {
      return 0;
    }
  }
}
