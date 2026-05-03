import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/achievements_service.dart';

class SocialSharingService {
  Future<void> shareAchievement(Achievement achievement) async {
    await Share.share(
      '🎉 I just unlocked "${achievement.title}" in Linguist!\n\n${achievement.description}\n\n#LinguistApp #LanguageLearning',
    );
  }

  Future<void> shareStreak(int currentStreak, int longestStreak) async {
    await Share.share(
      '🔥 I\'m on a $currentStreak-day streak in Linguist!\n\nMy best streak: $longestStreak days\n\n#LinguistApp #LanguageLearning',
    );
  }

  Future<void> shareProgress({
    required int masteredPhonemes,
    required int totalPhonemes,
    required int correctAnswers,
    required int totalAttempts,
  }) async {
    final accuracy = totalAttempts > 0 ? (correctAnswers / totalAttempts * 100).round() : 0;
    await Share.share(
      '📊 My Linguist Progress:\n\n• $masteredPhonemes / $totalPhonemes phonemes mastered\n• $accuracy% accuracy\n\n#LinguistApp #LanguageLearning',
    );
  }

  Future<void> shareLessonComplete(String lessonTitle, int correctAnswers, int totalQuestions) async {
    final accuracy = (correctAnswers / totalQuestions * 100).round();
    await Share.share(
      '🎓 Just completed "$lessonTitle" on Linguist!\n\nScore: $accuracy%\n($correctAnswers / $totalQuestions)\n\n#LinguistApp #LanguageLearning',
    );
  }

  Future<void> shareInvite() async {
    await Share.share(
      '📱 Improve your pronunciation with Linguist!\n\nA fun way to master phonemes for any language.\n\nGet it on iOS/Android!',
    );
  }
}

class SocialShareNotifier extends StateNotifier<bool> {
  SocialShareNotifier() : super(false);

  final SocialSharingService _service = SocialSharingService();

  Future<void> shareAchievement(Achievement achievement) async {
    state = true;
    await _service.shareAchievement(achievement);
    state = false;
  }

  Future<void> shareStreak(int currentStreak, int longestStreak) async {
    state = true;
    await _service.shareStreak(currentStreak, longestStreak);
    state = false;
  }

  Future<void> shareInvite() async {
    state = true;
    await _service.shareInvite();
    state = false;
  }
}

final socialShareProvider = StateNotifierProvider<SocialShareNotifier, bool>((ref) {
  return SocialShareNotifier();
});

class ShareScreen extends ConsumerWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakService = ref.watch(streakServiceProvider);
    final achievements = ref.watch(achievementsProvider);
    final isSharing = ref.watch(socialShareProvider);
    final unlockedAchievements = achievements.where((a) => a.isUnlocked).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Share')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<int>(
            future: streakService.getCurrentStreak(),
            builder: (context, snapshot) {
              final current = snapshot.data ?? 0;
              return FutureBuilder<int>(
                future: streakService.getLongestStreak(),
                builder: (context, longestSnap) {
                  final longest = longestSnap.data ?? 0;
                  return _ShareCard(
                    icon: Icons.local_fire_department,
                    title: 'Share Streak',
                    subtitle: 'Current: $current days | Best: $longest days',
                    isSharing: isSharing,
                    onTap: () => ref.read(socialShareProvider.notifier).shareStreak(current, longest),
                  );
                },
              );
            },
          ),
          if (unlockedAchievements.isNotEmpty)
            _ShareCard(
              icon: Icons.emoji_events,
              title: 'Share Achievements',
              subtitle: '${unlockedAchievements.length} achievements unlocked',
              isSharing: isSharing,
              onTap: () => _showAchievementsShare(context, ref, unlockedAchievements),
            ),
          _ShareCard(
            icon: Icons.person_add,
            title: 'Invite Friend',
            subtitle: 'Share Linguist with friends',
            isSharing: isSharing,
            onTap: () => ref.read(socialShareProvider.notifier).shareInvite(),
          ),
        ],
      ),
    );
  }

  void _showAchievementsShare(BuildContext context, WidgetRef ref, List<Achievement> achievements) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Share Achievement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...achievements.map((a) => ListTile(
                leading: Text(a.icon, style: const TextStyle(fontSize: 24)),
                title: Text(a.title),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(socialShareProvider.notifier).shareAchievement(a);
                },
              )),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSharing;
  final VoidCallback onTap;

  const _ShareCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSharing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: isSharing ? const SizedBox(width: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.share),
        onTap: isSharing ? null : onTap,
      ),
    );
  }
}