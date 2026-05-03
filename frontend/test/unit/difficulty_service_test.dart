import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/services/difficulty_service.dart';

void main() {
  group('DifficultyLevel', () {
    test('levels have correct count', () {
      expect(DifficultyService.levels.length, 5);
    });

    test('first level is beginner', () {
      expect(DifficultyService.levels.first.name, 'Beginner');
    });

    test('last level is expert', () {
      expect(DifficultyService.levels.last.name, 'Expert');
    });

    test('levels have increasing multipliers', () {
      const levels = DifficultyService.levels;
      for (var i = 1; i < levels.length; i++) {
        expect(levels[i].multiplier, greaterThan(levels[i - 1].multiplier));
      }
    });

    test('levels have increasing minCorrect', () {
      const levels = DifficultyService.levels;
      for (var i = 1; i < levels.length; i++) {
        expect(levels[i].minCorrect, greaterThan(levels[i - 1].minCorrect));
      }
    });
  });

  group('DifficultyService', () {
    test('getLevel returns beginner for low correctCount', () {
      final level = DifficultyService.getLevel(0);
      expect(level.name, 'Beginner');
    });

    test('getLevel returns correct level for mid range', () {
      final level = DifficultyService.getLevel(25);
      expect(level.name, 'Medium');
    });

    test('getLevel returns expert for high correctCount', () {
      final level = DifficultyService.getLevel(100);
      expect(level.name, 'Expert');
    });

    test('getXPForDifficulty returns correct XP', () {
      final level = DifficultyService.levels.first;
      final xp = DifficultyService.getXPForDifficulty(level);
      expect(xp, greaterThan(0));
    });

    test('getEncouragement returns string', () {
      final level = DifficultyService.levels.first;
      final encouragement = DifficultyService.getEncouragement(level, 3);
      expect(encouragement, isNotEmpty);
    });
  });
}