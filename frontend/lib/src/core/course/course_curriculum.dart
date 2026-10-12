/// Immutable curriculum structure contracts for the FR-01 catalogue.
///
/// This module is pure Dart: it imports only [course_exercise.dart], never
/// French content, providers, storage, widgets or plugins. Only local scalar
/// misuse throws `ArgumentError` (blank required strings, nonpositive
/// revisions/counts); relationship rules belong to the content validator, so
/// invalid fixtures remain constructible. Collections are detached from
/// caller state and exposed unmodifiable.
library;

import 'course_exercise.dart';

/// The stage order: hear, then find, then spell, then assess.
enum CourseStage { hear, find, spell, assess }

/// The catalogue role of a node.
enum CourseNodeKind { lesson, review, game, articulation, assessment }

/// Whether catalogue content is authored or still planned.
enum ContentStatus { authored, planned }

/// Rejects empty and all-whitespace strings without touching valid ones.
String _nonblank(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must be a nonblank string');
  }
  return value;
}

/// Rejects nonpositive revisions and counts.
int _positive(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'must be positive');
  }
  return value;
}

/// One authored or planned catalogue node, in authored order.
class CourseNode {
  CourseNode({
    required String id,
    required String title,
    required this.kind,
    required this.stage,
    required this.status,
    required this.optional,
    required List<String> prerequisiteIds,
    required List<String> sectionIds,
    required List<String> targetSounds,
  })  : id = _nonblank(id, 'id'),
        title = _nonblank(title, 'title'),
        prerequisiteIds = List.unmodifiable(prerequisiteIds),
        sectionIds = List.unmodifiable(sectionIds),
        targetSounds = List.unmodifiable(targetSounds);

  /// The content identity of this node, not a URL.
  final String id;
  final String title;
  final CourseNodeKind kind;
  final CourseStage stage;
  final ContentStatus status;

  /// Optional side-quest nodes that can never become prerequisites of
  /// required main nodes.
  final bool optional;

  /// Ordered prerequisite node ids; planned nodes may list none.
  final List<String> prerequisiteIds;

  /// Ordered ids of this node's sections; planned nodes may list none.
  final List<String> sectionIds;

  /// Phoneme labels this node teaches, all within the coverage inventory.
  final List<String> targetSounds;
}

/// One authored section owning its ordered exercises.
class CourseSection {
  CourseSection({
    required String id,
    required String nodeId,
    required String title,
    required String explanation,
    required int contentRevision,
    required List<String> exerciseIds,
    required int requiredItemCount,
  })  : id = _nonblank(id, 'id'),
        nodeId = _nonblank(nodeId, 'nodeId'),
        title = _nonblank(title, 'title'),
        explanation = _nonblank(explanation, 'explanation'),
        contentRevision = _positive(contentRevision, 'contentRevision'),
        exerciseIds = List.unmodifiable(exerciseIds),
        requiredItemCount =
            _positive(requiredItemCount, 'requiredItemCount');

  final String id;

  /// The single owning node id; membership is validated downstream.
  final String nodeId;
  final String title;

  /// Section-end content, never per-attempt help.
  final String explanation;

  /// Positive content revision.
  final int contentRevision;

  /// The section's ordered distinct exercise ids.
  final List<String> exerciseIds;

  /// Positive count of distinct first-pass required items.
  final int requiredItemCount;
}

/// Catalogue coverage for one phoneme; not a learner score.
class PhonemeCoverage {
  PhonemeCoverage({
    required String sound,
    required this.discoveryStatus,
    required List<String> practiceExerciseIds,
  })  : sound = _nonblank(sound, 'sound'),
        practiceExerciseIds = List.unmodifiable(practiceExerciseIds);

  /// The coverage sound label, within the seven teaching targets.
  final String sound;

  /// Whether discovery content for this sound is authored or planned.
  final ContentStatus discoveryStatus;

  /// Ordered practice exercises covering this sound; planned sounds list
  /// none.
  final List<String> practiceExerciseIds;
}

/// The immutable authored curriculum and its ordered record collections.
class CourseCurriculum {
  CourseCurriculum({
    required String courseId,
    required int revision,
    required List<CourseNode> nodes,
    required List<CourseSection> sections,
    required List<CourseExercise> exercises,
    required List<CourseSentence> sentences,
    required List<CourseAudioReference> audioReferences,
    required List<PhonemeCoverage> phonemeCoverage,
  })  : courseId = _nonblank(courseId, 'courseId'),
        revision = _positive(revision, 'revision'),
        nodes = List.unmodifiable(nodes),
        sections = List.unmodifiable(sections),
        exercises = List.unmodifiable(exercises),
        sentences = List.unmodifiable(sentences),
        audioReferences = List.unmodifiable(audioReferences),
        phonemeCoverage = List.unmodifiable(phonemeCoverage);

  /// The stable course identity.
  final String courseId;

  /// Positive curriculum revision.
  final int revision;

  /// Authored node order.
  final List<CourseNode> nodes;

  /// Authored section order.
  final List<CourseSection> sections;

  /// Authored exercise order.
  final List<CourseExercise> exercises;

  /// Authored sentence order.
  final List<CourseSentence> sentences;

  /// Authored audio-reference order.
  final List<CourseAudioReference> audioReferences;

  /// Coverage order: u, y, i, o, ɔ̃, ɑ̃, ʁ.
  final List<PhonemeCoverage> phonemeCoverage;

  /// The unique node with [id], or null when absent or duplicated.
  CourseNode? nodeById(String id) => _uniqueById(nodes, (node) => node.id, id);

  /// The unique section with [id], or null when absent or duplicated.
  CourseSection? sectionById(String id) =>
      _uniqueById(sections, (section) => section.id, id);

  /// The unique exercise with [id], or null when absent or duplicated.
  CourseExercise? exerciseById(String id) =>
      _uniqueById(exercises, (exercise) => exercise.id, id);

  /// The unique sentence with [id], or null when absent or duplicated.
  CourseSentence? sentenceById(String id) =>
      _uniqueById(sentences, (sentence) => sentence.id, id);

  /// The unique audio reference with [id], or null when absent or duplicated.
  CourseAudioReference? audioReferenceById(String id) =>
      _uniqueById(audioReferences, (reference) => reference.id, id);

  /// Bounded unique-or-null scan; duplicates stay visible in the list.
  T? _uniqueById<T extends Object>(
    List<T> records,
    String Function(T) idOf,
    String id,
  ) {
    T? match;
    for (final record in records) {
      if (idOf(record) == id) {
        if (match != null) return null; // Ambiguous: absent or duplicate.
        match = record;
      }
    }
    return match;
  }
}
