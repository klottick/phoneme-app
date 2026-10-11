import 'french_course.dart';

/// A single listen-and-discriminate item of a discovery section.
///
/// [id] is the stable item identifier; in the pilot section it is the word
/// text so that answers and progress keep referring to the same identity.
class LessonSectionItem {
  const LessonSectionItem({
    required this.id,
    required this.word,
    required this.expectedSound,
  });

  /// Stable identifier of the item.
  final String id;

  /// Word spoken during the active listening puzzle.
  final String word;

  /// Expected sound label (for example `u` or `y`).
  final String expectedSound;

  @override
  bool operator ==(Object other) =>
      other is LessonSectionItem &&
      other.id == id &&
      other.word == word &&
      other.expectedSound == expectedSound;

  @override
  int get hashCode => Object.hash(id, word, expectedSound);

  @override
  String toString() =>
      'LessonSectionItem(id: $id, word: $word, expectedSound: $expectedSound)';
}

/// Immutable authored content for a discovery listening section.
///
/// [contentRevision] identifies this authored revision of the section content;
/// a saved session is only compatible with a section of the same revision.
class LessonSection {
  LessonSection({
    required this.lessonId,
    required this.title,
    required this.explanation,
    required this.contentRevision,
    required List<LessonSectionItem> items,
    required List<String> sounds,
  })  : items = List.unmodifiable(items),
        sounds = List.unmodifiable(sounds);

  /// Existing lesson ID reused from the course content (`en-fr-u-y`).
  final String lessonId;

  /// Section title shown to the learner.
  final String title;

  /// Teaching explanation shown at the debrief, reused verbatim from the
  /// existing lesson.
  final String explanation;

  /// Authored content revision; integer, from 1 upward.
  final int contentRevision;

  /// The items in fixed order; item IDs are unique.
  final List<LessonSectionItem> items;

  /// The sound choices to discriminate (for example `['u', 'y']`).
  final List<String> sounds;
}

LessonSection _buildFrenchUySection() {
  final CourseLesson lesson = frenchLessons.firstWhere(
    (CourseLesson candidate) => candidate.id == 'en-fr-u-y',
    orElse: () =>
        throw StateError('The pilot lesson en-fr-u-y is missing from the course.'),
  );
  const List<LessonSectionItem> items = <LessonSectionItem>[
    LessonSectionItem(id: 'tout', word: 'tout', expectedSound: 'u'),
    LessonSectionItem(id: 'tu', word: 'tu', expectedSound: 'y'),
    LessonSectionItem(id: 'rouge', word: 'rouge', expectedSound: 'u'),
    LessonSectionItem(id: 'rue', word: 'rue', expectedSound: 'y'),
    LessonSectionItem(id: 'vous', word: 'vous', expectedSound: 'u'),
    LessonSectionItem(id: 'lune', word: 'lune', expectedSound: 'y'),
    LessonSectionItem(id: 'doux', word: 'doux', expectedSound: 'u'),
    LessonSectionItem(id: 'jus', word: 'jus', expectedSound: 'y'),
    LessonSectionItem(id: 'loup', word: 'loup', expectedSound: 'u'),
    LessonSectionItem(id: 'mur', word: 'mur', expectedSound: 'y'),
  ];
  return LessonSection(
    lessonId: lesson.id,
    title: lesson.title,
    explanation: lesson.explanation,
    contentRevision: 1,
    items: items,
    sounds: const ['u', 'y'],
  );
}

/// The authored pilot section for /u/ versus /y/.
///
/// Reuses the existing `en-fr-u-y` lesson title, explanation, and the curated
/// French words from [frenchWords]; only the ten pilot words are in scope.
final LessonSection frenchUySection = _buildFrenchUySection();

final Map<String, LessonSection> _sectionsByLesson = <String, LessonSection>{
  frenchUySection.lessonId: frenchUySection,
};

/// Returns the authored discovery section mapped to [lessonId].
///
/// Only the pilot lesson `en-fr-u-y` has a section; every non-pilot lesson
/// (including other course lessons and unknown IDs) maps to null, so existing
/// lesson behavior is unchanged.
LessonSection? sectionForLesson(String lessonId) =>
    _sectionsByLesson[lessonId];
