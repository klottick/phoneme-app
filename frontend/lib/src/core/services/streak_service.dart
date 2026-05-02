import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  static const _lastPracticeKey = 'last_practice_date';
  static const _currentStreakKey = 'current_streak';
  static const _longestStreakKey = 'longest_streak';

  Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentStreakKey) ?? 0;
  }

  Future<int> getLongestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_longestStreakKey) ?? 0;
  }

  Future<DateTime?> getLastPracticeDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_lastPracticeKey);
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  Future<void> recordPractice() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastDateStr = prefs.getString(_lastPracticeKey);
    final lastDate = lastDateStr != null ? DateTime.tryParse(lastDateStr) : null;

    if (lastDate == null) {
      await prefs.setInt(_currentStreakKey, 1);
      await prefs.setInt(_longestStreakKey, 1);
    } else {
      final lastDateDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final difference = today.difference(lastDateDay).inDays;

      if (difference == 0) {
        return;
      } else if (difference == 1) {
        final current = prefs.getInt(_currentStreakKey) ?? 0;
        final newStreak = current + 1;
        await prefs.setInt(_currentStreakKey, newStreak);

        final longest = prefs.getInt(_longestStreakKey) ?? 0;
        if (newStreak > longest) {
          await prefs.setInt(_longestStreakKey, newStreak);
        }
      } else {
        await prefs.setInt(_currentStreakKey, 1);
      }
    }

    await prefs.setString(_lastPracticeKey, today.toIso8601String());
  }

  Future<bool> shouldEncourage() async {
    final lastDate = await getLastPracticeDate();
    if (lastDate == null) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays;

    return difference >= 1;
  }

  Future<void> resetStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentStreakKey, 0);
  }
}

final streakServiceProvider = Provider<StreakService>((ref) => StreakService());