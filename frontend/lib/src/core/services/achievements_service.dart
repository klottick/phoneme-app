import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AchievementType {
  firstSession,
  streak3,
  streak7,
  streak30,
  mastered10,
  mastered25,
  mastered50,
  perfectSession,
  earlyBird,
  nightOwl,
  consistent3,
  consistent7,
  practice100,
  practice500,
  practice1000,
  phonemeCollector,
  speedster,
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final AchievementType type;
  final int target;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
    this.unlockedAt,
    required this.type,
    this.target = 0,
  });

  Achievement unlock() => Achievement(
        id: id,
        title: title,
        description: description,
        icon: icon,
        isUnlocked: true,
        unlockedAt: DateTime.now(),
        type: type,
        target: target,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
        'isUnlocked': isUnlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'type': type.name,
        'target': target,
      };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        icon: json['icon'] as String,
        isUnlocked: json['isUnlocked'] as bool? ?? false,
        unlockedAt: json['unlockedAt'] != null
            ? DateTime.parse(json['unlockedAt'] as String)
            : null,
        type: AchievementType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => AchievementType.firstSession,
        ),
        target: json['target'] as int? ?? 0,
      );
}

class AchievementsService {
  static List<Achievement> get allAchievements => [
        const Achievement(
          id: 'first_session',
          title: 'First Steps',
          description: 'Complete your first practice session',
          icon: '🎯',
          type: AchievementType.firstSession,
        ),
        const Achievement(
          id: 'streak_3',
          title: 'Getting Started',
          description: 'Maintain a 3-day practice streak',
          icon: '🔥',
          type: AchievementType.streak3,
          target: 3,
        ),
        const Achievement(
          id: 'streak_7',
          title: 'Week Warrior',
          description: 'Maintain a 7-day practice streak',
          icon: '💪',
          type: AchievementType.streak7,
          target: 7,
        ),
        const Achievement(
          id: 'streak_30',
          title: 'Monthly Master',
          description: 'Maintain a 30-day practice streak',
          icon: '👑',
          type: AchievementType.streak30,
          target: 30,
        ),
        const Achievement(
          id: 'mastered_10',
          title: 'Phoneme Explorer',
          description: 'Master 10 phonemes',
          icon: '⭐',
          type: AchievementType.mastered10,
          target: 10,
        ),
        const Achievement(
          id: 'mastered_25',
          title: 'Phoneme Scholar',
          description: 'Master 25 phonemes',
          icon: '🌟',
          type: AchievementType.mastered25,
          target: 25,
        ),
        const Achievement(
          id: 'mastered_50',
          title: 'Phoneme Expert',
          description: 'Master 50 phonemes',
          icon: '🏆',
          type: AchievementType.mastered50,
          target: 50,
        ),
        const Achievement(
          id: 'perfect_session',
          title: 'Perfect!',
          description: 'Correctly identify all phonemes in a session',
          icon: '💯',
          type: AchievementType.perfectSession,
        ),
        const Achievement(
          id: 'early_bird',
          title: 'Early Bird',
          description: 'Practice before 7 AM',
          icon: '🌅',
          type: AchievementType.earlyBird,
        ),
        const Achievement(
          id: 'night_owl',
          title: 'Night Owl',
          description: 'Practice after 10 PM',
          icon: '🦉',
          type: AchievementType.nightOwl,
        ),
        const Achievement(
          id: 'consistent_3',
          title: 'Dedicated',
          description: 'Practice 3 days in a row',
          icon: '📈',
          type: AchievementType.consistent3,
          target: 3,
        ),
        const Achievement(
          id: 'consistent_7',
          title: 'Reliable',
          description: 'Practice 7 days in a row',
          icon: '📊',
          type: AchievementType.consistent7,
          target: 7,
        ),
        const Achievement(
          id: 'practice_100',
          title: 'Century Club',
          description: 'Complete 100 practice attempts',
          icon: '💯',
          type: AchievementType.practice100,
          target: 100,
        ),
        const Achievement(
          id: 'practice_500',
          title: 'Half Grand',
          description: 'Complete 500 practice attempts',
          icon: '🏅',
          type: AchievementType.practice500,
          target: 500,
        ),
        const Achievement(
          id: 'practice_1000',
          title: 'Grand Master',
          description: 'Complete 1000 practice attempts',
          icon: '🎖️',
          type: AchievementType.practice1000,
          target: 1000,
        ),
      ];

  static List<Achievement> checkAchievements({
    required int currentStreak,
    required int longestStreak,
    required int totalAttempts,
    required int masteredPhonemes,
    required int correctToday,
    required int totalToday,
  }) {
    final unlocked = <Achievement>[];

    if (totalAttempts >= 1) {
      final a = allAchievements.firstWhere((a) => a.type == AchievementType.firstSession);
      unlocked.add(a.unlock());
    }

    if (currentStreak >= 3) {
      final a = allAchievements.firstWhere((a) => a.type == AchievementType.streak3);
      unlocked.add(a.unlock());
    }

    if (currentStreak >= 7) {
      final a = allAchievements.firstWhere((a) => a.type == AchievementType.streak7);
      unlocked.add(a.unlock());
    }

    if (currentStreak >= 30) {
      final a = allAchievements.firstWhere((a) => a.type == AchievementType.streak30);
      unlocked.add(a.unlock());
    }

    if (masteredPhonemes >= 10) {
      final a = allAchievements.firstWhere((a) => a.type == AchievementType.mastered10);
      unlocked.add(a.unlock());
    }

    if (masteredPhonemes >= 25) {
      final a = allAchievements.firstWhere((a) => a.type == AchievementType.mastered25);
      unlocked.add(a.unlock());
    }

    if (masteredPhonemes >= 50) {
      final a = allAchievements.firstWhere((a) => a.type == AchievementType.mastered50);
      unlocked.add(a.unlock());
    }

    if (totalToday > 0 && totalToday == correctToday) {
      final a = allAchievements.firstWhere((a) => a.type == AchievementType.perfectSession);
      unlocked.add(a.unlock());
    }

    if (totalAttempts >= 100) {
      final a = allAchievements.firstWhere((a) => a.type == AchievementType.practice100);
      unlocked.add(a.unlock());
    }

    if (totalAttempts >= 500) {
      final a = allAchievements.firstWhere((a) => a.type == AchievementType.practice500);
      unlocked.add(a.unlock());
    }

    if (totalAttempts >= 1000) {
      final a = allAchievements.firstWhere((a) => a.type == AchievementType.practice1000);
      unlocked.add(a.unlock());
    }

    final hour = DateTime.now().hour;
    if (hour < 7) {
      final a = allAchievements.firstWhere((a) => a.type == AchievementType.earlyBird);
      unlocked.add(a.unlock());
    }

    if (hour >= 22) {
      final a = allAchievements.firstWhere((a) => a.type == AchievementType.nightOwl);
      unlocked.add(a.unlock());
    }

    return unlocked;
  }
}

class AchievementsNotifier extends StateNotifier<List<Achievement>> {
  static const String _storageKey = 'achievements';

  AchievementsNotifier() : super(AchievementsService.allAchievements);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      try {
        final decoded = jsonDecode(data) as List<dynamic>;
        state = decoded
            .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        state = AchievementsService.allAchievements;
      }
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = state.map((a) => a.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> checkAndUnlock({
    required int currentStreak,
    required int longestStreak,
    required int totalAttempts,
    required int masteredPhonemes,
    required int correctToday,
    required int totalToday,
  }) async {
    final newAchievements = AchievementsService.checkAchievements(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalAttempts: totalAttempts,
      masteredPhonemes: masteredPhonemes,
      correctToday: correctToday,
      totalToday: totalToday,
    );

    final newUnlocked = newAchievements.where((a) => !state.any((s) => s.id == a.id && s.isUnlocked));

    if (newUnlocked.isNotEmpty) {
      state = [
        ...state.map((a) {
          final newA = newUnlocked.where((n) => n.id == a.id).firstOrNull;
          return newA != null ? a.unlock() : a;
        }),
      ];
      await save();
    }
  }

  int get unlockCount => state.where((a) => a.isUnlocked).length;

  double get progressPercent {
    if (state.isEmpty) return 0;
    return unlockCount / state.length;
  }
}

final achievementsProvider =
    StateNotifierProvider<AchievementsNotifier, List<Achievement>>((ref) {
  return AchievementsNotifier();
});