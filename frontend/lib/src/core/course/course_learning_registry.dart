import '../models/minimal_pair.dart';
import 'course_attempt.dart';
import 'course_learning_error.dart';
import 'french_course.dart';
import 'lesson_section.dart';

final List<MinimalPair> frenchDrillPairs = List.unmodifiable([
  const MinimalPair(
      id: 'en-fr-tu-tout',
      wordA: 'tu',
      wordB: 'tout',
      phonemeA: '/y/',
      phonemeB: '/u/'),
  const MinimalPair(
      id: 'en-fr-rue-roue',
      wordA: 'rue',
      wordB: 'roue',
      phonemeA: '/y/',
      phonemeB: '/u/'),
  const MinimalPair(
      id: 'en-fr-beau-bon',
      wordA: 'beau',
      wordB: 'bon',
      phonemeA: '/o/',
      phonemeB: '/ɔ̃/'),
]);

class LearningSourceItem {
  LearningSourceItem({
    required this.id,
    required this.sessionAlias,
    required this.audioText,
    required List<String> choices,
    required this.expectedChoice,
    required List<String> targetSounds,
    required this.contentState,
  })  : choices = List.unmodifiable(choices),
        targetSounds = List.unmodifiable(targetSounds);

  final String id;
  final String? sessionAlias;
  final String? audioText;
  final List<String> choices;
  final String? expectedChoice;
  final List<String> targetSounds;
  final AttemptContentState contentState;
}

class LearningActivityDefinition {
  LearningActivityDefinition({
    required this.id,
    required this.kind,
    required this.contentRevision,
    required List<LearningSourceItem> items,
  }) : items = List.unmodifiable(items);

  final String id;
  final LearningActivityKind kind;
  final int contentRevision;
  final List<LearningSourceItem> items;
}

class LearningRegistry {
  LearningRegistry._(List<LearningActivityDefinition> activities)
      : _activities = List.unmodifiable(activities),
        _byId =
            Map.unmodifiable({for (final item in activities) item.id: item});

  factory LearningRegistry.french() {
    final pilot = frenchUySection;
    final definitions = <LearningActivityDefinition>[
      for (final lesson in frenchLessons)
        if (lesson.id == pilot.lessonId)
          LearningActivityDefinition(
            id: 'lesson:${pilot.lessonId}',
            kind: LearningActivityKind.discovery,
            contentRevision: pilot.contentRevision,
            items: [
              for (final item in pilot.items)
                LearningSourceItem(
                  id: 'en-fr-u-y-listening-${item.id}',
                  sessionAlias: item.id,
                  audioText: item.word,
                  choices: pilot.sounds,
                  expectedChoice: item.expectedSound,
                  targetSounds: [item.expectedSound],
                  contentState: AttemptContentState.existingCurated,
                ),
            ],
          )
        else
          LearningActivityDefinition(
            id: 'lesson:${lesson.id}',
            kind: LearningActivityKind.legacyLesson,
            contentRevision: 1,
            items: [
              for (final wordId in lesson.words) _legacyItem(lesson, wordId),
            ],
          ),
      LearningActivityDefinition(
        id: 'drill:minimal-pairs',
        kind: LearningActivityKind.drill,
        contentRevision: 1,
        items: [
          for (final pair in frenchDrillPairs)
            LearningSourceItem(
              id: pair.id,
              sessionAlias: null,
              audioText: pair.wordA,
              choices: [pair.wordA, pair.wordB],
              expectedChoice: pair.wordA,
              targetSounds: [
                pair.phonemeA.replaceAll('/', ''),
                pair.phonemeB.replaceAll('/', ''),
              ],
              contentState: AttemptContentState.existingCurated,
            ),
        ],
      ),
      for (final game in [
        ('arcade:sound', LearningActivityKind.soundGame),
        ('arcade:word', LearningActivityKind.wordGame),
      ])
        LearningActivityDefinition(
          id: game.$1,
          kind: game.$2,
          contentRevision: 1,
          items: [
            for (final word in frenchWords)
              LearningSourceItem(
                id: word.text,
                sessionAlias: null,
                audioText: word.text,
                choices: const [],
                expectedChoice: null,
                targetSounds: word.sounds,
                contentState: AttemptContentState.existingCurated,
              ),
          ],
        ),
    ];
    return LearningRegistry._(definitions);
  }

  final List<LearningActivityDefinition> _activities;
  final Map<String, LearningActivityDefinition> _byId;
  Iterable<LearningActivityDefinition> get activities => _activities;

  LearningActivityDefinition require(String activityId) =>
      _byId[activityId] ?? (throw const LearningInvalidCommandException());
}

LearningSourceItem _legacyItem(CourseLesson lesson, String wordId) {
  final word = wordByText(wordId);
  final expected = lesson.sounds.firstWhere(word.contains);
  final choices = <String>[
    expected,
    ...['u', 'y', 'i', 'o', 'ɔ̃', 'ɑ̃', 'ʁ']
        .where((sound) => !word.contains(sound))
        .take(3),
  ]..sort();
  return LearningSourceItem(
    id: wordId,
    sessionAlias: null,
    audioText: wordId,
    choices: choices,
    expectedChoice: expected,
    targetSounds: [expected],
    contentState: AttemptContentState.existingCurated,
  );
}
