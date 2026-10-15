import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/providers/app_providers.dart';

void main() {
  test('registry retains pilot canonical ids aliases order and ten items', () {
    final registry = LearningRegistry.french();
    final pilot = registry.require('lesson:en-fr-u-y');

    expect(pilot.kind, LearningActivityKind.discovery);
    expect(pilot.contentRevision, 1);
    expect(pilot.items, hasLength(10));
    expect(pilot.items.map((item) => item.id), [
      'en-fr-u-y-listening-tout',
      'en-fr-u-y-listening-tu',
      'en-fr-u-y-listening-rouge',
      'en-fr-u-y-listening-rue',
      'en-fr-u-y-listening-vous',
      'en-fr-u-y-listening-lune',
      'en-fr-u-y-listening-doux',
      'en-fr-u-y-listening-jus',
      'en-fr-u-y-listening-loup',
      'en-fr-u-y-listening-mur',
    ]);
    expect(pilot.items.map((item) => item.sessionAlias), [
      'tout',
      'tu',
      'rouge',
      'rue',
      'vous',
      'lune',
      'doux',
      'jus',
      'loup',
      'mur'
    ]);
    expect(pilot.items.map((item) => item.expectedChoice),
        ['u', 'y', 'u', 'y', 'u', 'y', 'u', 'y', 'u', 'y']);
    expect(() => registry.require('lesson:not-a-lesson'),
        throwsA(isA<LearningInvalidCommandException>()));
    final activities = registry.activities.toList();
    expect(activities.map((activity) => activity.id), [
      'lesson:en-fr-vowels',
      'lesson:en-fr-u-y',
      'lesson:en-fr-nasal',
      'lesson:en-fr-r',
      'lesson:en-fr-mix',
      'drill:minimal-pairs',
      'arcade:sound',
      'arcade:word',
    ]);
    for (final lessonId in [
      'lesson:en-fr-vowels',
      'lesson:en-fr-nasal',
      'lesson:en-fr-r',
      'lesson:en-fr-mix',
    ]) {
      final legacy = registry.require(lessonId);
      expect(legacy.kind, LearningActivityKind.legacyLesson);
      expect(legacy.items, isNotEmpty);
      expect(
          legacy.items.every((item) =>
              item.expectedChoice != null &&
              item.choices.contains(item.expectedChoice) &&
              item.targetSounds.length == 1),
          isTrue);
    }
    final drill = registry.require('drill:minimal-pairs');
    expect(drill.kind, LearningActivityKind.drill);
    expect(drill.items.map((item) => item.id),
        ['en-fr-tu-tout', 'en-fr-rue-roue', 'en-fr-beau-bon']);
    for (final gameId in ['arcade:sound', 'arcade:word']) {
      final game = registry.require(gameId);
      expect(game.items.map((item) => item.id),
          frenchWords.map((word) => word.text));
      expect(game.items.every((item) => item.expectedChoice == null), isTrue);
    }
  });

  test('drill extraction is value identical', () async {
    expect(frenchDrillPairs.map((pair) => pair.toJson()), [
      {
        'id': 'en-fr-tu-tout',
        'word_a': 'tu',
        'word_b': 'tout',
        'phoneme_a': '/y/',
        'phoneme_b': '/u/'
      },
      {
        'id': 'en-fr-rue-roue',
        'word_a': 'rue',
        'word_b': 'roue',
        'phoneme_a': '/y/',
        'phoneme_b': '/u/'
      },
      {
        'id': 'en-fr-beau-bon',
        'word_a': 'beau',
        'word_b': 'bon',
        'phoneme_a': '/o/',
        'phoneme_b': '/ɔ̃/'
      },
    ]);
    final container = ProviderContainer(overrides: [
      selectedCourseProvider.overrideWithValue(frenchCourse),
    ]);
    addTearDown(container.dispose);
    final provided = await container.read(minimalPairsProvider.future);
    expect(provided.map((pair) => pair.toJson()),
        frenchDrillPairs.map((pair) => pair.toJson()));
  });
}
