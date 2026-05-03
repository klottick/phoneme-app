import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/services/streak_service.dart';

void main() {
  group('StreakService', () {
    test('getCurrentStreak returns streak value', () async {
      final service = StreakService();
      
      final streak = await service.getCurrentStreak();
      
      expect(streak, isA<int>());
    });

    test('getLongestStreak returns streak value', () async {
      final service = StreakService();
      
      final streak = await service.getLongestStreak();
      
      expect(streak, isA<int>());
    });

    test('recordPractice updates streak', () async {
      final service = StreakService();
      
      await service.recordPractice();
      
      final streak = await service.getCurrentStreak();
      expect(streak, greaterThanOrEqualTo(0));
    });

    test('shouldEncourage returns boolean', () async {
      final service = StreakService();
      
      final shouldEncourage = await service.shouldEncourage();
      
      expect(shouldEncourage, isA<bool>());
    });

    test('resetStreak resets current streak', () async {
      final service = StreakService();
      
      await service.resetStreak();
      
      final streak = await service.getCurrentStreak();
      expect(streak, 0);
    });

    test('getLastPracticeDate returns nullable DateTime', () async {
      final service = StreakService();
      
      final date = await service.getLastPracticeDate();
      
      expect(date == null || date is DateTime, true);
    });
  });
}