import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';

void main() {
  group('LessonPolicy constructor', () {
    test('defaults to an 80 percent threshold', () {
      expect(LessonPolicy().completionThresholdPercent, 80);
    });

    test('accepts a configured threshold within 1-100', () {
      expect(LessonPolicy(completionThresholdPercent: 1).completionThresholdPercent,
          1);
      expect(
          LessonPolicy(completionThresholdPercent: 99).completionThresholdPercent,
          99);
      expect(LessonPolicy(completionThresholdPercent: 100).completionThresholdPercent,
          100);
    });

    test('rejects percentage 0 with an ArgumentError', () {
      expect(() => LessonPolicy(completionThresholdPercent: 0),
          throwsArgumentError);
    });

    test('rejects percentage 101 with an ArgumentError', () {
      expect(() => LessonPolicy(completionThresholdPercent: 101),
          throwsArgumentError);
    });

    test('rejects negative percentages with an ArgumentError', () {
      expect(() => LessonPolicy(completionThresholdPercent: -20),
          throwsArgumentError);
    });
  });

  group('requiredCorrect', () {
    test('requires 8 of 10 at the default 80 percent', () {
      expect(LessonPolicy().requiredCorrect(10), 8);
    });

    test('requires 7 of 8 at the default 80 percent (ceiling of 6.4)', () {
      expect(LessonPolicy().requiredCorrect(8), 7);
    });

    test('requires 6 of 8 at 75 percent', () {
      expect(LessonPolicy(completionThresholdPercent: 75).requiredCorrect(8), 6);
    });

    test('requires 10 of 10 at 100 percent', () {
      expect(LessonPolicy(completionThresholdPercent: 100).requiredCorrect(10),
          10);
    });

    test('rounds up so 1 of 2 is required at 25 percent', () {
      expect(LessonPolicy(completionThresholdPercent: 25).requiredCorrect(2), 1);
    });

    test('rejects a zero item count with an ArgumentError', () {
      expect(() => LessonPolicy().requiredCorrect(0), throwsArgumentError);
    });

    test('rejects a negative item count with an ArgumentError', () {
      expect(() => LessonPolicy().requiredCorrect(-3), throwsArgumentError);
    });
  });

  group('isPassing', () {
    test('passes at the exact 80 percent boundary of 10 items', () {
      expect(
          LessonPolicy()
              .isPassing(correct: 8, total: 10),
          isTrue);
    });

    test('fails one below the 80 percent boundary of 10 items', () {
      expect(
          LessonPolicy()
              .isPassing(correct: 7, total: 10),
          isFalse);
    });

    test('passes at the exact 75 percent boundary of 8 items', () {
      expect(
          LessonPolicy(completionThresholdPercent: 75)
              .isPassing(correct: 6, total: 8),
          isTrue);
    });

    test('fails one below the 75 percent boundary of 8 items', () {
      expect(
          LessonPolicy(completionThresholdPercent: 75)
              .isPassing(correct: 5, total: 8),
          isFalse);
    });

    test('zero correct answers is valid but never passing', () {
      expect(
          LessonPolicy()
              .isPassing(correct: 0, total: 10),
          isFalse);
    });

    test('rejects a zero total with an ArgumentError', () {
      expect(() => LessonPolicy().isPassing(correct: 0, total: 0),
          throwsArgumentError);
    });

    test('rejects a negative total with an ArgumentError', () {
      expect(() => LessonPolicy().isPassing(correct: 0, total: -1),
          throwsArgumentError);
    });

    test('rejects a negative correct count with an ArgumentError', () {
      expect(() => LessonPolicy().isPassing(correct: -1, total: 10),
          throwsArgumentError);
    });

    test('rejects more correct than total with an ArgumentError', () {
      expect(() => LessonPolicy().isPassing(correct: 11, total: 10),
          throwsArgumentError);
    });
  });

  group('serialization', () {
    test('toJson uses exactly completionThresholdPercent', () {
      expect(LessonPolicy().toJson(),
          const {'completionThresholdPercent': 80});
      expect(LessonPolicy(completionThresholdPercent: 75).toJson(),
          const {'completionThresholdPercent': 75});
    });

    test('fromJson accepts an integer percentage', () {
      expect(
          LessonPolicy.fromJson(const {'completionThresholdPercent': 75})
              .completionThresholdPercent,
          75);
    });

    test('fromJson accepts an integer-valued number from JSON decoding', () {
      expect(
          LessonPolicy.fromJson(const {'completionThresholdPercent': 80.0})
              .completionThresholdPercent,
          80);
    });

    test('fromJson rejects a missing percentage with a FormatException', () {
      expect(() => LessonPolicy.fromJson(const {}), throwsFormatException);
    });

    test('fromJson rejects a string percentage with a FormatException', () {
      expect(
          () => LessonPolicy.fromJson(
              const {'completionThresholdPercent': '80'}),
          throwsFormatException);
    });

    test('fromJson rejects a fractional percentage with a FormatException',
        () {
      expect(
          () => LessonPolicy.fromJson(
              const {'completionThresholdPercent': 75.5}),
          throwsFormatException);
    });

    test('fromJson rejects out-of-range percentages with a FormatException',
        () {
      expect(
          () => LessonPolicy.fromJson(
              const {'completionThresholdPercent': 0}),
          throwsFormatException);
      expect(
          () => LessonPolicy.fromJson(
              const {'completionThresholdPercent': 101}),
          throwsFormatException);
    });

    test('round trip preserves the configured percentage', () {
      final configured = LessonPolicy(completionThresholdPercent: 67);
      final restored = LessonPolicy.fromJson(configured.toJson());
      expect(restored.completionThresholdPercent, 67);
      expect(restored.toJson(), configured.toJson());
    });
  });
}
