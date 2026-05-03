import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/services/session_timer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('SessionTimer', () {
    test('creates with default values', () {
      const timer = SessionTimer();

      expect(timer.elapsedSeconds, 0);
      expect(timer.isRunning, false);
    });

    test('copyWith updates values', () {
      const timer = SessionTimer(elapsedSeconds: 100, isRunning: true);
      final updated = timer.copyWith(elapsedSeconds: 200);

      expect(updated.elapsedSeconds, 200);
      expect(updated.isRunning, true);
    });

    test('formatted returns correct format', () {
      const timer = SessionTimer(elapsedSeconds: 65);
      expect(timer.formatted, '1m 5s');

      const timer2 = SessionTimer(elapsedSeconds: 3665);
      expect(timer2.formatted, '1h 1m');
    });
  });

  group('SessionHistory', () {
    test('creates with required fields', () {
      final history = SessionHistory(
        date: DateTime(2024, 1, 15),
        durationSeconds: 1800,
      );

      expect(history.date, isA<DateTime>());
      expect(history.durationSeconds, 1800);
    });

    test('factory fromString parses correctly', () {
      final history = SessionHistory.fromString('2024-01-15T10:00:00.000,1800');

      expect(history.durationSeconds, 1800);
    });

    test('formatted returns correct format', () {
      final history = SessionHistory(
        date: DateTime(2024, 1, 15),
        durationSeconds: 3600,
      );

      expect(history.formatted, '1h 0m');
    });
  });

  group('SessionTimerNotifier', () {
    test('initial state is not running', () {
      final notifier = SessionTimerNotifier();

      expect(notifier.state.isRunning, false);
      expect(notifier.state.elapsedSeconds, 0);
    });

    test('start sets running state', () {
      final notifier = SessionTimerNotifier();

      notifier.start();

      expect(notifier.state.isRunning, true);
    });

    test('pause stops the timer', () {
      final notifier = SessionTimerNotifier();

      notifier.start();
      notifier.pause();

      expect(notifier.state.isRunning, false);
    });

    test('reset clears time', () {
      final notifier = SessionTimerNotifier();

      notifier.start();
      notifier.reset();

      expect(notifier.state.elapsedSeconds, 0);
      expect(notifier.state.isRunning, false);
    });
  });
}