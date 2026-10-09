import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettings {
  final bool practiceReminder;
  final int reminderHour;
  final int reminderMinute;
  final bool streakReminder;
  final bool achievementReminder;

  const NotificationSettings({
    this.practiceReminder = true,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.streakReminder = true,
    this.achievementReminder = true,
  });

  NotificationSettings copyWith({
    bool? practiceReminder,
    int? reminderHour,
    int? reminderMinute,
    bool? streakReminder,
    bool? achievementReminder,
  }) {
    return NotificationSettings(
      practiceReminder: practiceReminder ?? this.practiceReminder,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      streakReminder: streakReminder ?? this.streakReminder,
      achievementReminder: achievementReminder ?? this.achievementReminder,
    );
  }
}

class NotificationService {
  static const String _key = 'notification_settings';

  Future<NotificationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationSettings(
      practiceReminder: prefs.getBool('$_key.practice') ?? true,
      reminderHour: prefs.getInt('$_key.hour') ?? 9,
      reminderMinute: prefs.getInt('$_key.minute') ?? 0,
      streakReminder: prefs.getBool('$_key.streak') ?? true,
      achievementReminder: prefs.getBool('$_key.achievement') ?? true,
    );
  }

  Future<void> save(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_key.practice', settings.practiceReminder);
    await prefs.setInt('$_key.hour', settings.reminderHour);
    await prefs.setInt('$_key.minute', settings.reminderMinute);
    await prefs.setBool('$_key.streak', settings.streakReminder);
    await prefs.setBool('$_key.achievement', settings.achievementReminder);
  }

  String formatTime(int hour, int minute) {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  }

  String getNextReminderText(NotificationSettings settings) {
    final now = DateTime.now();
    var scheduledHour = settings.reminderHour;
    final scheduledMinute = settings.reminderMinute;

    if (scheduledHour < now.hour ||
        (scheduledHour == now.hour && scheduledMinute <= now.minute)) {
      scheduledHour += 24;
    }

    final diff = (scheduledHour * 60 + scheduledMinute) - (now.hour * 60 + now.minute);
    final hours = diff ~/ 60;
    final minutes = diff % 60;

    if (hours > 24) {
      final days = hours ~/ 24;
      return 'Tomorrow at ${formatTime(scheduledHour % 24, scheduledMinute)} ($days days)';
    } else if (hours > 0) {
      return 'In $hours hours, $minutes minutes';
    } else {
      return 'In $minutes minutes';
    }
  }
}

class NotificationNotifier extends StateNotifier<NotificationSettings> {
  NotificationNotifier() : super(const NotificationSettings()) {
    _load();
  }

  final NotificationService _service = NotificationService();

  Future<void> _load() async {
    state = await _service.load();
  }

  Future<void> togglePracticeReminder() async {
    state = state.copyWith(practiceReminder: !state.practiceReminder);
    await _service.save(state);
  }

  Future<void> setReminderTime(int hour, int minute) async {
    state = state.copyWith(reminderHour: hour, reminderMinute: minute);
    await _service.save(state);
  }

  Future<void> toggleStreakReminder() async {
    state = state.copyWith(streakReminder: !state.streakReminder);
    await _service.save(state);
  }

  Future<void> toggleAchievementReminder() async {
    state = state.copyWith(achievementReminder: !state.achievementReminder);
    await _service.save(state);
  }

  String get nextReminderText => _service.getNextReminderText(state);
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationSettings>((ref) {
  return NotificationNotifier();
});

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationProvider);
    final notifier = ref.read(notificationProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Daily Practice Reminder'),
            subtitle: Text(
              settings.practiceReminder
                  ? 'Next: ${notifier.nextReminderText}'
                  : 'Disabled',
            ),
            value: settings.practiceReminder,
            onChanged: (_) => notifier.togglePracticeReminder(),
          ),
          if (settings.practiceReminder) ...[
            ListTile(
              title: const Text('Reminder Time'),
              subtitle: Text(_formatTime(settings.reminderHour, settings.reminderMinute)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTimePicker(context, ref),
            ),
          ],
          const Divider(),
          SwitchListTile(
            title: const Text('Streak Reminder'),
            subtitle: const Text('Get reminded to maintain your streak'),
            value: settings.streakReminder,
            onChanged: (_) => notifier.toggleStreakReminder(),
          ),
          SwitchListTile(
            title: const Text('Achievement Notifications'),
            subtitle: const Text('Share when you unlock achievements'),
            value: settings.achievementReminder,
            onChanged: (_) => notifier.toggleAchievementReminder(),
          ),
        ],
      ),
    );
  }

  String _formatTime(int hour, int minute) {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _showTimePicker(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(notificationProvider);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      ),
    );

    if (time != null) {
      ref.read(notificationProvider.notifier).setReminderTime(time.hour, time.minute);
    }
  }
}
