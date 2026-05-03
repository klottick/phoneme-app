import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class DifficultyLevel {
  final int level;
  final String name;
  final String description;
  final double multiplier;
  final int minCorrect;
  final IconData icon;

  const DifficultyLevel({
    required this.level,
    required this.name,
    required this.description,
    required this.multiplier,
    required this.minCorrect,
    required this.icon,
  });
}

class DifficultyService {
  static const List<DifficultyLevel> levels = [
    DifficultyLevel(
      level: 1,
      name: 'Beginner',
      description: 'Easy phonemes, lots of time',
      multiplier: 1.0,
      minCorrect: 0,
      icon: Icons.school,
    ),
    DifficultyLevel(
      level: 2,
      name: 'Easy',
      description: 'Straightforward phonemes',
      multiplier: 1.2,
      minCorrect: 10,
      icon: Icons.trending_up,
    ),
    DifficultyLevel(
      level: 3,
      name: 'Medium',
      description: 'Mixed difficulty',
      multiplier: 1.5,
      minCorrect: 25,
      icon: Icons.balance,
    ),
    DifficultyLevel(
      level: 4,
      name: 'Hard',
      description: 'Challenging phonemes',
      multiplier: 1.8,
      minCorrect: 50,
      icon: Icons.local_fire_department,
    ),
    DifficultyLevel(
      level: 5,
      name: 'Expert',
      description: 'Most difficult phonemes',
      multiplier: 2.0,
      minCorrect: 100,
      icon: Icons.emoji_events,
    ),
  ];

  static DifficultyLevel getLevel(int correctCount) {
    for (final level in levels.reversed) {
      if (correctCount >= level.minCorrect) {
        return level;
      }
    }
    return levels.first;
  }

  static int getXPForDifficulty(DifficultyLevel level) {
    return 10 * level.multiplier.round();
  }

  static int getStreakBonus(int streakDays) {
    if (streakDays >= 30) return 50;
    if (streakDays >= 14) return 30;
    if (streakDays >= 7) return 20;
    if (streakDays >= 3) return 10;
    return 0;
  }

  static int calculateScore({
    required DifficultyLevel difficulty,
    required bool isCorrect,
    required int streakDays,
    required int timeMs,
  }) {
    if (!isCorrect) return 0;

    int score = getXPForDifficulty(difficulty);
    score += getStreakBonus(streakDays);

    if (timeMs < 2000) {
      score += 5;
    } else if (timeMs < 5000) {
      score += 2;
    }

    return score;
  }

  static String getEncouragement(DifficultyLevel current, int correctStreak) {
    if (correctStreak >= 5) {
      return 'Outstanding! Ready for a challenge boost?';
    }
    if (correctStreak >= 3) {
      return 'Great flow! Keep it going!';
    }
    return "You're doing well. Stay focused!";
  }
}

class DifficultyNotifier extends StateNotifier<DifficultyLevel> {
  DifficultyNotifier() : super(DifficultyService.levels.first);

  void updateForPerformance(int totalCorrect, int recentCorrect, int recentTotal) {
    final newLevel = DifficultyService.getLevel(totalCorrect);
    
    if (recentTotal > 0) {
      final accuracy = recentCorrect / recentTotal;
      if (accuracy >= 0.9 && totalCorrect >= newLevel.minCorrect) {
        if (state.level < 5) {
          final nextIndex = DifficultyService.levels.indexOf(state) + 1;
          if (nextIndex < DifficultyService.levels.length) {
            state = DifficultyService.levels[nextIndex];
          }
        }
      }
    }
  }

  void downgrade() {
    if (state.level > 1) {
      final prevIndex = DifficultyService.levels.indexOf(state) - 1;
      if (prevIndex >= 0) {
        state = DifficultyService.levels[prevIndex];
      }
    }
  }
}

final difficultyProvider =
    StateNotifierProvider<DifficultyNotifier, DifficultyLevel>((ref) {
  return DifficultyNotifier();
});