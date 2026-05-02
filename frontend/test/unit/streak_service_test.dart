import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/services/streak_service.dart';

void main() {
  group('StreakService', () {
    late StreakService streakService;

    setUp(() {
      streakService = StreakService();
    });

    test('getCurrentStreak returns an integer', () async {
      final streak = await streakService.getCurrentStreak();
      expect(streak, isA<int>());
    });

    test('getLongestStreak returns an integer', () async {
      final streak = await streakService.getLongestStreak();
      expect(streak, isA<int>());
    });

    test('getLastPracticeDate returns DateTime or null', () async {
      final date = await streakService.getLastPracticeDate();
      expect(date == null || date is DateTime, isTrue);
    });

    test('shouldEncourage returns a boolean', () async {
      final shouldEncourage = await streakService.shouldEncourage();
      expect(shouldEncourage, isA<bool>());
    });

    test('recordPractice updates streak', () async {
      await streakService.recordPractice();
      
      final streak = await streakService.getCurrentStreak();
      expect(streak, greaterThanOrEqualTo(1));
    });
  });
}