
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyGoal {
  final int targetPhonemes;
  final int completedPhonemes;
  final int targetMinutes;
  final int completedMinutes;
  final DateTime date;

  const DailyGoal({
    required this.targetPhonemes,
    required this.completedPhonemes,
    required this.targetMinutes,
    required this.completedMinutes,
    required this.date,
  });

  double get phonemeProgress => targetPhonemes > 0 ? completedPhonemes / targetPhonemes : 0;
  double get minuteProgress => targetMinutes > 0 ? completedMinutes / targetMinutes : 0;
  bool get isComplete => completedPhonemes >= targetPhonemes;

  DailyGoal copyWith({
    int? targetPhonemes,
    int? completedPhonemes,
    int? targetMinutes,
    int? completedMinutes,
    DateTime? date,
  }) {
    return DailyGoal(
      targetPhonemes: targetPhonemes ?? this.targetPhonemes,
      completedPhonemes: completedPhonemes ?? this.completedPhonemes,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      completedMinutes: completedMinutes ?? this.completedMinutes,
      date: date ?? this.date,
    );
  }
}

class DailyGoalsService {
  static const String _key = 'daily_goals';
  static const int defaultTargetPhonemes = 10;
  static const int defaultTargetMinutes = 15;

  Future<DailyGoal> getTodayGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final targetP = prefs.getInt('$_key.target_phonemes') ?? defaultTargetPhonemes;
    final targetM = prefs.getInt('$_key.target_minutes') ?? defaultTargetMinutes;
    final completedP = prefs.getInt('$_key.completed_phonemes') ?? 0;
    final completedM = prefs.getInt('$_key.completed_minutes') ?? 0;
    final lastDate = prefs.getString('$_key.date');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastDate != null && DateTime.parse(lastDate) != today) {
      await prefs.setInt('$_key.completed_phonemes', 0);
      await prefs.setInt('$_key.completed_minutes', 0);
      await prefs.setString('$_key.date', today.toIso8601String());
      return DailyGoal(
        targetPhonemes: targetP,
        completedPhonemes: 0,
        targetMinutes: targetM,
        completedMinutes: 0,
        date: today,
      );
    }

    return DailyGoal(
      targetPhonemes: targetP,
      completedPhonemes: completedP,
      targetMinutes: targetM,
      completedMinutes: completedM,
      date: today,
    );
  }

  Future<void> incrementProgress({int phonemes = 1, int minutes = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final completedP = prefs.getInt('$_key.completed_phonemes') ?? 0;
    final completedM = prefs.getInt('$_key.completed_minutes') ?? 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await prefs.setInt('$_key.completed_phonemes', completedP + phonemes);
    await prefs.setInt('$_key.completed_minutes', completedM + minutes);
    await prefs.setString('$_key.date', today.toIso8601String());
  }

  Future<void> setTargets({int? phonemes, int? minutes}) async {
    final prefs = await SharedPreferences.getInstance();
    if (phonemes != null) await prefs.setInt('$_key.target_phonemes', phonemes);
    if (minutes != null) await prefs.setInt('$_key.target_minutes', minutes);
  }
}

class DailyGoalsNotifier extends StateNotifier<DailyGoal> {
  DailyGoalsNotifier() : super(DailyGoal(
    targetPhonemes: DailyGoalsService.defaultTargetPhonemes,
    completedPhonemes: 0,
    targetMinutes: DailyGoalsService.defaultTargetMinutes,
    completedMinutes: 0,
    date: DateTime.now(),
  )) {
    _load();
  }

  final DailyGoalsService _service = DailyGoalsService();

  Future<void> _load() async {
    state = await _service.getTodayGoal();
  }

  Future<void> recordProgress({int phonemes = 1, int minutes = 0}) async {
    await _service.incrementProgress(phonemes: phonemes, minutes: minutes);
    await _load();
  }

  Future<void> updateTargets({int? phonemes, int? minutes}) async {
    await _service.setTargets(phonemes: phonemes, minutes: minutes);
    await _load();
  }
}

final dailyGoalsProvider = StateNotifierProvider<DailyGoalsNotifier, DailyGoal>((ref) {
  return DailyGoalsNotifier();
});

class DailyGoalWidget extends ConsumerWidget {
  const DailyGoalWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(dailyGoalsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Goal",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (goal.isComplete)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 12),
            _GoalProgress(
              label: 'Phonemes',
              current: goal.completedPhonemes,
              target: goal.targetPhonemes,
              color: Colors.teal,
            ),
            const SizedBox(height: 8),
            _GoalProgress(
              label: 'Minutes',
              current: goal.completedMinutes,
              target: goal.targetMinutes,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalProgress extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  final Color color;

  const _GoalProgress({
    required this.label,
    required this.current,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? current / target : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text('$label:'),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                progress >= 1 ? Colors.green : color,
              ),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$current / $target',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class StreakCalendar extends ConsumerWidget {
  const StreakCalendar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Streak Calendar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _CalendarGrid(),
          ],
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  static const int _daysToShow = 28;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(_daysToShow, (i) {
      final date = now.subtract(Duration(days: _daysToShow - 1 - i));
      return date;
    });

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => SizedBox(
            width: 32,
            child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          )).toList(),
        ),
        const SizedBox(height: 4),
        ...List.generate((_daysToShow / 7).ceil(), (week) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: days.skip(week * 7).take(7).map((date) => _DayCircle(date: date)).toList(),
            ),
          );
        }),
      ],
    );
  }
}

class _DayCircle extends StatelessWidget {
  final DateTime date;

  const _DayCircle({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    
    final isToday = dateDay == today;
    final isPast = dateDay.isBefore(today);
    
    Color color;
    if (isToday) {
      color = Colors.teal;
    } else if (isPast) {
      color = dateDay.day % 2 == 0 ? Colors.green[200]! : Colors.grey[300]!;
    } else {
      color = Colors.grey[100]!;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: isToday ? Border.all(color: Colors.teal, width: 2) : null,
      ),
      child: Center(child: Text('${date.day}', style: TextStyle(fontSize: 12, color: isToday ? Colors.white : Colors.black))),
    );
  }
}