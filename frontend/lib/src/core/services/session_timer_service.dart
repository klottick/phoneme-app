import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionTimer {
  final int elapsedSeconds;
  final bool isRunning;
  final DateTime? startTime;

  const SessionTimer({
    this.elapsedSeconds = 0,
    this.isRunning = false,
    this.startTime,
  });

  String get formatted {
    final hours = elapsedSeconds ~/ 3600;
    final minutes = (elapsedSeconds % 3600) ~/ 60;
    final seconds = elapsedSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  SessionTimer copyWith({
    int? elapsedSeconds,
    bool? isRunning,
    DateTime? startTime,
  }) {
    return SessionTimer(
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isRunning: isRunning ?? this.isRunning,
      startTime: startTime ?? this.startTime,
    );
  }
}

class SessionTimerNotifier extends StateNotifier<SessionTimer> {
  Timer? _timer;

  SessionTimerNotifier() : super(const SessionTimer());

  void start() {
    if (state.isRunning) return;
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
    
    state = state.copyWith(isRunning: true, startTime: DateTime.now());
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(isRunning: false);
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    state = const SessionTimer();
  }

  Future<void> save() async {
    if (state.elapsedSeconds > 0) {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('session_history') ?? [];
      final session = '${DateTime.now().toIso8601String()},${state.elapsedSeconds}';
      history.add(session);
      await prefs.setStringList('session_history', history);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sessionTimerProvider = StateNotifierProvider<SessionTimerNotifier, SessionTimer>((ref) {
  return SessionTimerNotifier();
});

class SessionHistory {
  final DateTime date;
  final int durationSeconds;

  const SessionHistory({required this.date, required this.durationSeconds});

  factory SessionHistory.fromString(String data) {
    try {
      final parts = data.split(',');
      if (parts.length != 2) {
        return SessionHistory(date: DateTime.now(), durationSeconds: 0);
      }
      return SessionHistory(
        date: DateTime.parse(parts[0]),
        durationSeconds: int.tryParse(parts[1]) ?? 0,
      );
    } catch (e) {
      return SessionHistory(date: DateTime.now(), durationSeconds: 0);
    }
  }

  String get formatted {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class SessionHistoryNotifier extends StateNotifier<List<SessionHistory>> {
  SessionHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('session_history') ?? [];
    state = history.map((s) => SessionHistory.fromString(s)).toList();
  }

  Future<void> addSession(int durationSeconds) async {
    final newSession = SessionHistory(
      date: DateTime.now(),
      durationSeconds: durationSeconds,
    );
    state = [newSession, ...state];
    
    final prefs = await SharedPreferences.getInstance();
    final history = state.map((s) => '${s.date.toIso8601String()},${s.durationSeconds}').toList();
    await prefs.setStringList('session_history', history);
  }

  int get totalMinutesToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return state
        .where((s) => s.date.isAfter(today))
        .fold(0, (sum, s) => sum + s.durationSeconds) ~/ 60;
  }

  int get totalSessionsThisWeek {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return state.where((s) => s.date.isAfter(weekAgo)).length;
  }

  double get averageSessionLength {
    if (state.isEmpty) return 0;
    final total = state.fold(0, (sum, s) => sum + s.durationSeconds);
    return total / state.length / 60;
  }
}

final sessionHistoryProvider = StateNotifierProvider<SessionHistoryNotifier, List<SessionHistory>>((ref) {
  return SessionHistoryNotifier();
});

class SessionTimerWidget extends ConsumerWidget {
  const SessionTimerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sessionTimerProvider);
    final notifier = ref.read(sessionTimerProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              timer.formatted,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: timer.isRunning ? null : () => notifier.start(),
                  icon: const Icon(Icons.play_arrow),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: timer.isRunning ? () => notifier.pause() : null,
                  icon: const Icon(Icons.pause),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: timer.elapsedSeconds > 0
                      ? () async {
                          await notifier.save();
                          notifier.reset();
                        }
                      : null,
                  icon: const Icon(Icons.stop),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}