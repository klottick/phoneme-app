/// Shared immutable fixtures for the FR-01 curriculum graph tests.
///
/// Test-only support. Pure Dart: no production `copyWith`, no French content
/// or provider imports. A `null` helper argument uses the documented default
/// list; a supplied empty list stays empty.
library;

import 'package:linguist/src/core/course/course_content_validator.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/course_curriculum.dart';

/// Authored required hear lesson.
CourseNode _defaultNode() => CourseNode(
      id: 'test-listen',
      title: 'Hear the u and y sounds',
      kind: CourseNodeKind.lesson,
      stage: CourseStage.hear,
      status: ContentStatus.authored,
      optional: false,
      prerequisiteIds: const [],
      sectionIds: const ['test-section'],
      targetSounds: const ['u'],
    );

/// Authored section owning the default practice exercise.
CourseSection _defaultSection() => CourseSection(
      id: 'test-section',
      nodeId: 'test-listen',
      title: 'u and y practice',
      explanation: 'Section-end explanation for the u and y practice.',
      contentRevision: 1,
      exerciseIds: const ['test-u'],
      requiredItemCount: 1,
    );

/// Practice existing-curated listening exercise on the word `tout`.
ListeningChoiceExercise _defaultExercise() => ListeningChoiceExercise(
      id: 'test-u',
      sectionId: 'test-section',
      audioRefId: 'fr-word-tout',
      purpose: ContentPurpose.practice,
      reviewState: ContentReviewState.existingCurated,
      wordId: 'tout',
      expectedSound: 'u',
      choices: const ['u', 'y'],
      legacyItemId: 'tout',
    );

/// Word audio reference with the declared spoken text `tout`.
CourseAudioReference _defaultAudioReference() => CourseAudioReference(
      id: 'fr-word-tout',
      kind: AudioReferenceKind.word,
      spokenText: 'tout',
    );

/// Coverage order u, y: u is authored on the default exercise, y planned.
List<PhonemeCoverage> _defaultCoverage() => [
      PhonemeCoverage(
        sound: 'u',
        discoveryStatus: ContentStatus.authored,
        practiceExerciseIds: const ['test-u'],
      ),
      PhonemeCoverage(
        sound: 'y',
        discoveryStatus: ContentStatus.planned,
        practiceExerciseIds: const [],
      ),
    ];

/// The shared listening fixture.
///
/// Defaults: courseId `test-course`, revision 1; authored required hear lesson
/// `test-listen`, section `test-section`, requiredItemCount 1; practice
/// existingCurated exercise `test-u`, word and alias `tout`, expected `u`,
/// choices `u`/`y`, audio `fr-word-tout`; coverage `u` authored referencing
/// `test-u`, `y` planned empty. Null arguments use those defaults; supplied
/// empty lists stay empty.
CourseCurriculum listeningFixture({
  List<CourseNode>? nodes,
  List<CourseSection>? sections,
  List<CourseExercise>? exercises,
  List<CourseSentence>? sentences,
  List<CourseAudioReference>? audioReferences,
  List<PhonemeCoverage>? phonemeCoverage,
}) =>
    CourseCurriculum(
      courseId: 'test-course',
      revision: 1,
      nodes: nodes ?? [_defaultNode()],
      sections: sections ?? [_defaultSection()],
      exercises: exercises ?? [_defaultExercise()],
      sentences: sentences ?? const <CourseSentence>[],
      audioReferences: audioReferences ?? [_defaultAudioReference()],
      phonemeCoverage: phonemeCoverage ?? _defaultCoverage(),
    );

/// Citation phonemes: `tout:[t,u]`, `tu:[t,y]`, synthetic `new-u:[n,u]`.
const Map<String, List<String>> fixtureCitations = {
  'tout': ['t', 'u'],
  'tu': ['t', 'y'],
  'new-u': ['n', 'u'],
};

/// Exposed word IDs: `tout`, `tu`.
const Set<String> fixtureExposure = {'tout', 'tu'};

/// Declared audio resources: `fr-word-tout` has the practice-TTS fallback.
const Map<String, AudioResourceStatus> fixtureAudioResources = {
  'fr-word-tout': AudioResourceStatus.practiceTts,
};
