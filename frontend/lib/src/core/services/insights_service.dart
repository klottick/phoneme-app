import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daily_goals_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearningInsights {
  final int? totalSessions;
  final int? totalMinutes;
  final double? averageAccuracy;
  final int? longestSession;
  final String? mostPracticedPhoneme;
  final String? hardestPhoneme;
  final Map<String, int> weakAreas;
  final List<DailyStats> weeklyStats;

  const LearningInsights({
    required this.totalSessions,
    required this.totalMinutes,
    required this.averageAccuracy,
    required this.longestSession,
    required this.mostPracticedPhoneme,
    required this.hardestPhoneme,
    required this.weakAreas,
    required this.weeklyStats,
  });
}

class DailyStats {
  final DateTime date;
  final int sessions;
  final int minutes;
  final int correct;
  final int total;

  const DailyStats({
    required this.date,
    required this.sessions,
    required this.minutes,
    required this.correct,
    required this.total,
  });

  double get accuracy => total > 0 ? correct / total : 0;
}

class InsightsService {
  static const String _key = 'learning_insights';

  Future<LearningInsights> getInsights() async {
    return const LearningInsights(
      totalSessions: null,
      totalMinutes: null,
      averageAccuracy: null,
      longestSession: null,
      mostPracticedPhoneme: null,
      hardestPhoneme: null,
      weakAreas: {},
      weeklyStats: [],
    );
  }

  Future<void> recordSession({
    required int durationMinutes,
    required int correct,
    required int total,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final sessions = (prefs.getInt('$_key.sessions') ?? 0) + 1;
    final minutes = (prefs.getInt('$_key.minutes') ?? 0) + durationMinutes;
    final accuracy = (correct / total);
    final avgAccuracy = prefs.getDouble('$_key.accuracy') ?? 0.7;
    final newAvg = (avgAccuracy * (sessions - 1) + accuracy) / sessions;

    await prefs.setInt('$_key.sessions', sessions);
    await prefs.setInt('$_key.minutes', minutes);
    await prefs.setDouble('$_key.accuracy', newAvg);

    if (durationMinutes > (prefs.getInt('$_key.longest_session') ?? 0)) {
      await prefs.setInt('$_key.longest_session', durationMinutes);
    }
  }
}

final insightsProvider = FutureProvider<LearningInsights>((ref) async {
  final service = InsightsService();
  return service.getInsights();
});

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Learning Insights')),
      body: insightsAsync.when(
        data: (insights) => _InsightsContent(insights: insights),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _InsightsContent extends StatelessWidget {
  final LearningInsights insights;

  const _InsightsContent({required this.insights});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatsOverview(insights: insights),
        const SizedBox(height: 16),
        _WeeklyChart(insights: insights),
        const SizedBox(height: 16),
        _WeakAreas(insights: insights),
      ],
    );
  }
}

class _StatsOverview extends StatelessWidget {
  final LearningInsights insights;

  const _StatsOverview({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.repeat,
                    value: insights.totalSessions?.toString() ?? 'Not measured',
                    label: 'Sessions',
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.timer,
                    value: insights.totalMinutes?.toString() ?? 'Not measured',
                    label: 'Minutes',
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.check_circle,
                    value: insights.averageAccuracy == null
                        ? 'Not measured'
                        : '${(insights.averageAccuracy! * 100).round()}%',
                    label: 'Accuracy',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.teal),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final LearningInsights insights;

  const _WeeklyChart({required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.weeklyStats.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This Week',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text('Activity is not measured in this view.'),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This Week',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: insights.weeklyStats.map((stat) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          width: 24,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${(stat.accuracy * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ['M', 'T', 'W', 'T', 'F', 'S', 'S'][stat.date.weekday -
                            1],
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeakAreas extends StatelessWidget {
  final LearningInsights insights;

  const _WeakAreas({required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.weakAreas.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Areas to Improve',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: insights.weakAreas.entries
                  .map(
                    (e) => Chip(
                      label: Text('${e.key}: ${e.value} errors'),
                      backgroundColor: Colors.orange[50],
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickPracticeWidget extends ConsumerWidget {
  const QuickPracticeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(dailyGoalsProvider);

    return Card(
      color: goals.isComplete ? Colors.green[50] : Colors.teal[50],
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/phoneme-id'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: goals.isComplete ? Colors.green : Colors.teal,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  goals.isComplete ? Icons.check : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goals.isComplete
                          ? 'Daily Goal Complete!'
                          : 'Quick Practice',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      goals.isComplete
                          ? 'Great work today!'
                          : '${goals.targetPhonemes - goals.completedPhonemes} phonemes to go',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
