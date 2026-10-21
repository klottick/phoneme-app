import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/spaced_repetition_service.dart';
import '../../core/providers/app_providers.dart';

class ProgressAnalyticsScreen extends ConsumerWidget {
  const ProgressAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(legacyBackendAvailableProvider)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Progress Analytics')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This legacy view is unavailable without a configured backend.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Back to home'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    ref.watch(srsProvider);
    final analytics = ref.read(srsProvider.notifier).getAnalytics();

    return Scaffold(
      appBar: AppBar(title: const Text('Progress Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOverviewCard(context, analytics),
          const SizedBox(height: 16),
          _buildMasteryCard(context, analytics),
          const SizedBox(height: 16),
          _buildStreakCard(context, ref),
          const SizedBox(height: 16),
          _buildPerformanceCard(context, ref),
          const SizedBox(height: 16),
          _buildRecommendationsCard(context, analytics),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    Map<String, dynamic> analytics,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Total',
                  value: '${analytics['total']}',
                  icon: Icons.layers,
                  color: Colors.blue,
                ),
                _StatItem(
                  label: 'Due Today',
                  value: '${analytics['dueNow']}',
                  icon: Icons.today,
                  color: Colors.orange,
                ),
                _StatItem(
                  label: 'Mastered',
                  value: '${analytics['mastered']}',
                  icon: Icons.star,
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasteryCard(
    BuildContext context,
    Map<String, dynamic> analytics,
  ) {
    final total = (analytics['total'] as int?) ?? 1;
    final mastered = (analytics['mastered'] as int?) ?? 0;
    final learning = (analytics['learning'] as int?) ?? 0;
    final newItems = (analytics['new'] as int?) ?? 0;

    final masteryPercent = total > 0 ? mastered / total : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mastery Progress',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: masteryPercent,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(masteryPercent * 100).toInt()}% mastered',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LegendItem(color: Colors.green, label: 'Mastered ($mastered)'),
                _LegendItem(color: Colors.blue, label: 'Learning ($learning)'),
                _LegendItem(color: Colors.grey, label: 'New ($newItems)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(BuildContext context, WidgetRef ref) {
    final currentStreak = ref.watch(streakServiceProvider).getCurrentStreak();
    final longestStreak = ref.watch(streakServiceProvider).getLongestStreak();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Practice Streaks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      size: 48,
                      color: Colors.orange,
                    ),
                    Text(
                      '$currentStreak',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Current Streak'),
                  ],
                ),
                Column(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 48,
                      color: Colors.amber,
                    ),
                    Text(
                      '$longestStreak',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Best Streak'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Performance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Performance totals are not measured in this view.'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard(
    BuildContext context,
    Map<String, dynamic> analytics,
  ) {
    final dueNow = (analytics['dueNow'] as int?) ?? 0;
    final learning = (analytics['learning'] as int?) ?? 0;

    String recommendation = 'Start a practice session!';
    IconData icon = Icons.play_arrow;

    if (dueNow > 10) {
      recommendation =
          'You have $dueNow phonemes due for review. Time to practice!';
      icon = Icons.priority_high;
    } else if (dueNow > 0) {
      recommendation =
          '$dueNow phonemes ready for review. Keep your streak going!';
      icon = Icons.local_fire_department;
    } else if (learning > 0) {
      recommendation = 'Great progress! $learning phonemes in progress.';
      icon = Icons.trending_up;
    } else {
      recommendation = 'All caught up! Add new phonemes to learn.';
      icon = Icons.celebration;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(icon, color: Colors.teal, size: 32),
              title: Text(recommendation),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
