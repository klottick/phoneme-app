import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/lesson_section.dart';

void main() {
  const expectedWords = [
    'tout',
    'tu',
    'rouge',
    'rue',
    'vous',
    'lune',
    'doux',
    'jus',
    'loup',
    'mur',
  ];
  const expectedSounds = ['u', 'y', 'u', 'y', 'u', 'y', 'u', 'y', 'u', 'y'];

  group('frenchUySection', () {
    test('maps the pilot lesson en-fr-u-y to the /u/ versus /y/ sounds', () {
      expect(frenchUySection.lessonId, 'en-fr-u-y');
      expect(frenchUySection.sounds, ['u', 'y']);
      expect(frenchUySection.contentRevision, 1);
      expect(frenchUySection.contentRevision, isA<int>());
    });

    test(
        'lists the ten pilot words in order with alternating expected sounds '
        'and item IDs equal to the word texts', () {
      expect(frenchUySection.items.map((i) => i.word).toList(), expectedWords);
      expect(frenchUySection.items.map((i) => i.id).toList(), expectedWords);
      expect(
          frenchUySection.items.map((i) => i.expectedSound).toList(),
          expectedSounds);
    });

    test('reuses only words already curated in the French word list', () {
      final curatedWords = frenchWords.map((w) => w.text).toSet();
      for (final item in frenchUySection.items) {
        expect(curatedWords, contains(item.word),
            reason: '${item.word} is missing from the curated French words');
      }
    });

    test('keeps the original title and explanation of the existing lesson', () {
      final lesson = frenchLessons.firstWhere((l) => l.id == 'en-fr-u-y');
      expect(frenchUySection.title, lesson.title);
      expect(frenchUySection.explanation, lesson.explanation);
      expect(frenchUySection.title, isNotEmpty);
      expect(frenchUySection.explanation, isNotEmpty);
    });

    test('exposes collection views that callers cannot mutate', () {
      expect(
          () => frenchUySection.items
              .add(const LessonSectionItem(id: 'x', word: 'x', expectedSound: 'u')),
          throwsUnsupportedError);
      expect(() => frenchUySection.sounds.removeAt(0), throwsUnsupportedError);
    });
  });

  group('sectionForLesson', () {
    test('returns the pilot section for en-fr-u-y', () {
      expect(sectionForLesson('en-fr-u-y'), same(frenchUySection));
    });

    test('returns null for every non-pilot lesson', () {
      for (final lesson in frenchLessons) {
        if (lesson.id == 'en-fr-u-y') {
          continue;
        }
        expect(sectionForLesson(lesson.id), isNull, reason: lesson.id);
      }
      expect(sectionForLesson('en-fr-u-y-extra'), isNull);
      expect(sectionForLesson('EN-FR-U-Y'), isNull);
      expect(sectionForLesson(''), isNull);
    });
  });
}
