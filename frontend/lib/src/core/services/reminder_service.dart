import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReminderSchedule {
  final int hour;
  final int minute;
  final List<ReminderDay> days;

  const ReminderSchedule({
    required this.hour,
    required this.minute,
    required this.days,
  });

  String get formattedTime {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  }
}

enum ReminderDay { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

class LocalNotificationService {
  static Future<void> scheduleReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    debugPrint('Notification scheduled: $title at $hour:$minute');
  }

  static Future<void> cancelAllReminders() async {
    debugPrint('All reminders cancelled');
  }

  static Future<void> showTestNotification({
    required String title,
    required String body,
  }) async {
    debugPrint('Test notification: $title - $body');
  }
}

class ReminderSettingsNotifier extends StateNotifier<Map<String, bool>> {
  ReminderSettingsNotifier() : super({
    'morning': true,
    'evening': true,
    'streak': true,
  });

  void toggle(String key) {
    state = {...state, key: !(state[key] ?? true)};
  }
}

final reminderSettingsProvider = StateNotifierProvider<ReminderSettingsNotifier, Map<String, bool>>((ref) {
  return ReminderSettingsNotifier();
});

class ReminderSettingsScreen extends ConsumerWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(reminderSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Practice Reminders')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Morning Reminder'),
            subtitle: const Text('9:00 AM - Start your day with practice'),
            value: settings['morning'] ?? false,
            onChanged: (_) => ref.read(reminderSettingsProvider.notifier).toggle('morning'),
          ),
          SwitchListTile(
            title: const Text('Evening Reminder'),
            subtitle: const Text('7:00 PM - Evening review session'),
            value: settings['evening'] ?? false,
            onChanged: (_) => ref.read(reminderSettingsProvider.notifier).toggle('evening'),
          ),
          SwitchListTile(
            title: const Text('Streak Alert'),
            subtitle: const Text('Remind if you\'re about to break your streak'),
            value: settings['streak'] ?? false,
            onChanged: (_) => ref.read(reminderSettingsProvider.notifier).toggle('streak'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Test Notification'),
            subtitle: const Text('Tap to test your notifications'),
            onTap: () {
              LocalNotificationService.showTestNotification(
                title: 'Linguist Reminder',
                body: 'Time to practice your phonemes!',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Test notification sent!')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class PracticeReminderCard extends StatelessWidget {
  const PracticeReminderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.alarm, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Practice Reminders',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Set daily reminders to stay consistent:'),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              children: [
                Chip(
                  avatar: Icon(Icons.wb_sunny, size: 16),
                  label: Text('9:00 AM'),
                ),
                Chip(
                  avatar: Icon(Icons.nights_stay, size: 16),
                  label: Text('7:00 PM'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReminderSettingsScreen()),
              ),
              icon: const Icon(Icons.settings),
              label: const Text('Customize'),
            ),
          ],
        ),
      ),
    );
  }
}