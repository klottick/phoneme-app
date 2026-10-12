import 'course_curriculum.dart';
import 'course_exercise.dart';
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

  /// Projects one authored lesson of [curriculum] into the stable
  /// [LessonSection] shape used at runtime.
  ///
  /// The lesson must be an authored hear-stage lesson that owns exactly one
  /// section of practice listening choices. Item identity, word, teaching
  /// target, shared ordered choices, title, explanation and content revision
  /// are all read from the catalogue — the saved item ID is the exercise's
  /// legacy alias, never its namespaced catalogue ID. Missing or ambiguous
  /// records (including repeated section or exercise listings, which never
  /// collapse), selected-branch reverse-ownership disagreements (a section
  /// claimed by a second node, an unlisted section claiming the selected
  /// lesson, an exercise listed by a second section, or an unlisted
  /// exercise claiming the selected section), non-hear stages, non-practice
  /// purposes, unsupported kinds, count mismatches, missing or duplicated
  /// aliases, disagreeing choices, blank or duplicated choice labels, fewer
  /// than two distinct choices, or an expected sound that is not exactly
  /// one of the shared choices throw [StateError]; there is no partial
  /// projection or fallback to any other content. Only the selected branch
  /// is examined; unrelated catalogue branches are never touched.
  factory LessonSection.fromCurriculum(
    CourseCurriculum curriculum, {
    required String lessonId,
  }) {
    final CourseNode? node = curriculum.nodeById(lessonId);
    if (node == null) {
      throw StateError('No unique lesson node is declared for "$lessonId"; the '
          'projection requires exactly one authored lesson.');
    }
    if (node.kind != CourseNodeKind.lesson) {
      throw StateError(
          'Node "$lessonId" has kind ${node.kind.name}, which cannot '
          'project a practice listening section.');
    }
    if (node.status != ContentStatus.authored) {
      throw StateError(
          'Node "$lessonId" is ${node.status.name} content; only authored '
          'lessons project a practicing section.');
    }
    if (node.stage != CourseStage.hear) {
      throw StateError(
          'Node "$lessonId" is ${node.stage.name} content; only hear-stage '
          'lessons project a practice listening section.');
    }
    final Set<String> listedSectionIds = <String>{};
    final List<CourseSection> owned = <CourseSection>[];
    for (final String sectionId in node.sectionIds) {
      if (!listedSectionIds.add(sectionId)) {
        throw StateError(
            'Node "$lessonId" lists section "$sectionId" more than once; '
            'a repeated listing is an ambiguous shape, not a membership to '
            'silently collapse.');
      }
      final CourseSection? section = curriculum.sectionById(sectionId);
      if (section == null) {
        throw StateError('Node "$lessonId" lists the absent section '
            '"$sectionId".');
      }
      if (section.nodeId != node.id) {
        throw StateError(
            'Section "${section.id}" declares owner node "${section.nodeId}", '
            'not node "${node.id}".');
      }
      owned.add(section);
    }
    if (owned.length != 1) {
      throw StateError(
          'Node "$lessonId" owns ${owned.length} sections; the projection '
          'supports exactly one.');
    }
    final CourseSection section = owned.single;

    // Reverse ownership on the selected branch, in both directions: each
    // selected record is owned by exactly this branch, and nothing else may
    // claim or list it. Only the selected branch is examined; unrelated
    // catalogue branches stay out of scope for this projection helper.
    for (final CourseNode other in curriculum.nodes) {
      if (other.id != node.id && other.sectionIds.contains(section.id)) {
        throw StateError(
            'Section "${section.id}" is listed by node "${other.id}" as '
            'well as node "${node.id}"; the selected section has exactly '
            'one listing parent.');
      }
    }
    for (final CourseSection candidate in curriculum.sections) {
      if (candidate.nodeId != node.id ||
          node.sectionIds.contains(candidate.id)) {
        continue;
      }
      throw StateError(
          'Section "${candidate.id}" declares owner node "${node.id}" but '
          'the node never lists it; a selected-branch record cannot be '
          'silently dropped from the projection.');
    }
    for (final String exerciseId in section.exerciseIds) {
      for (final CourseSection other in curriculum.sections) {
        if (other.id != section.id && other.exerciseIds.contains(exerciseId)) {
          throw StateError(
              'Exercise "$exerciseId" is listed by section "${other.id}" '
              'as well as section "${section.id}"; the selected exercise '
              'has exactly one listing section.');
        }
      }
    }
    for (final CourseExercise candidate in curriculum.exercises) {
      if (candidate.sectionId != section.id ||
          section.exerciseIds.contains(candidate.id)) {
        continue;
      }
      throw StateError('Exercise "${candidate.id}" declares owner section '
          '"${section.id}" but the section never lists it; a selected-'
          'branch record cannot be silently dropped from the projection.');
    }

    final Set<String> listedExerciseIds = <String>{};
    final List<ListeningChoiceExercise> listening = <ListeningChoiceExercise>[];
    for (final String exerciseId in section.exerciseIds) {
      if (!listedExerciseIds.add(exerciseId)) {
        throw StateError(
            'Section "${section.id}" lists exercise "$exerciseId" more '
            'than once; a repeated listing is an ambiguous shape, not a '
            'membership to silently collapse.');
      }
      final CourseExercise? exercise = curriculum.exerciseById(exerciseId);
      if (exercise == null) {
        throw StateError('Section "${section.id}" lists the absent exercise '
            '"$exerciseId".');
      }
      if (exercise.sectionId != section.id) {
        throw StateError('Exercise "${exercise.id}" declares owner section '
            '"${exercise.sectionId}", not section "${section.id}".');
      }
      final ListeningChoiceExercise item;
      if (exercise is! ListeningChoiceExercise) {
        throw StateError(
            'Exercise "${exercise.id}" is a ${exercise.kind.name}, which '
            'the pilot projection does not support.');
      }
      item = exercise;
      if (item.purpose != ContentPurpose.practice) {
        throw StateError(
            'Exercise "${item.id}" has purpose ${item.purpose.name}; only '
            'practice items project into a live practice section.');
      }
      listening.add(item);
    }
    if (listening.isEmpty) {
      throw StateError(
          'Section "${section.id}" declares no listening records to '
          'project.');
    }
    if (section.requiredItemCount != listening.length) {
      throw StateError(
          'Section "${section.id}" requires ${section.requiredItemCount} '
          'items but declares ${listening.length}.');
    }
    final Set<String> aliases = <String>{};
    for (final exercise in listening) {
      final String? alias = exercise.legacyItemId;
      if (alias == null) {
        throw StateError(
            'Exercise "${exercise.id}" has no legacy item ID alias; the '
            'saved session identity requires it.');
      }
      if (!aliases.add(alias)) {
        throw StateError('Legacy item ID "$alias" is declared by more than one '
            'exercise in section "${section.id}".');
      }
    }
    final List<String> choices = listening.first.choices;
    for (final exercise in listening) {
      if (!_sameOrder(exercise.choices, choices)) {
        throw StateError(
            'Exercises in section "${section.id}" must share one ordered '
            'choice list; "${exercise.id}" declares '
            '${exercise.choices.join(' / ')} but the section choices are '
            '${choices.join(' / ')}.');
      }
    }
    // Supported practice-listening shape: at least two distinct nonblank
    // labels with exactly one expected choice. Anything else is an
    // unambiguous-key violation and must not project.
    if (choices.any((String label) => label.trim().isEmpty)) {
      throw StateError(
          'Section "${section.id}" uses a blank choice label; supported '
          'listening shapes need distinct nonblank labels.');
    }
    if (choices.toSet().length != choices.length || choices.length < 2) {
      throw StateError('Section "${section.id}" uses the choice labels '
          '${choices.join(' / ')}; supported listening shapes need at '
          'least two distinct labels with no duplicates, including '
          'duplicated non-expected distractors.');
    }
    for (final exercise in listening) {
      final int expectedCount = exercise.choices
          .where((String label) => label == exercise.expectedSound)
          .length;
      if (expectedCount != 1) {
        throw StateError('Exercise "${exercise.id}" expects sound '
            '${exercise.expectedSound}, which occurs $expectedCount '
            'times in its choices '
            '${exercise.choices.join(' / ')}; the expected sound must '
            'be exactly one of the shared choices.');
      }
    }
    return LessonSection(
      lessonId: node.id,
      title: section.title,
      explanation: section.explanation,
      contentRevision: section.contentRevision,
      items: [
        for (final exercise in listening)
          LessonSectionItem(
            id: exercise.legacyItemId!,
            word: exercise.wordId,
            expectedSound: exercise.expectedSound,
          ),
      ],
      sounds: List.of(choices),
    );
  }
}

bool _sameOrder(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

LessonSection _buildFrenchUySection() {
  // The catalogue is the sole author of the pilot content: publish only a
  // structurally valid projection, never a fallback to other literals.
  if (!frenchCurriculumValidation.isStructurallyValid) {
    throw StateError(
        'The French curriculum is structurally invalid; refusing to '
        'publish the pilot projection.');
  }
  return LessonSection.fromCurriculum(
    frenchCurriculum,
    lessonId: 'en-fr-u-y',
  );
}

/// The authored pilot section for /u/ versus /y/, projected from
/// [frenchCurriculum].
///
/// Reuses the existing `en-fr-u-y` lesson title, explanation, and the
/// curated French words from [frenchWords]; only the ten pilot words are in
/// scope and their saved item IDs keep the legacy word identity.
final LessonSection frenchUySection = _buildFrenchUySection();

final Map<String, LessonSection> _sectionsByLesson = <String, LessonSection>{
  frenchUySection.lessonId: frenchUySection,
};

/// Returns the authored discovery section mapped to [lessonId].
///
/// Only the pilot lesson `en-fr-u-y` has a section; every non-pilot lesson
/// (including other course lessons and unknown IDs) maps to null, so existing
/// lesson behavior is unchanged.
LessonSection? sectionForLesson(String lessonId) => _sectionsByLesson[lessonId];
