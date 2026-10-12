import 'package:flutter_test/flutter_test.dart';

import 'package:linguist/src/core/course/course_content_validator.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/course_curriculum.dart';

import '../support/course_curriculum_fixtures.dart';

/// Builds the documented default node with overrides for one structural rule.
CourseNode _node({
  String id = 'test-listen',
  CourseNodeKind kind = CourseNodeKind.lesson,
  CourseStage stage = CourseStage.hear,
  ContentStatus status = ContentStatus.authored,
  bool optional = false,
  List<String> prerequisiteIds = const [],
  List<String> sectionIds = const ['test-section'],
  List<String> targetSounds = const ['u'],
}) =>
    CourseNode(
      id: id,
      title: 'Override node $id',
      kind: kind,
      stage: stage,
      status: status,
      optional: optional,
      prerequisiteIds: prerequisiteIds,
      sectionIds: sectionIds,
      targetSounds: targetSounds,
    );

/// Builds the documented default section with overrides for one rule.
CourseSection _section({
  String id = 'test-section',
  String nodeId = 'test-listen',
  List<String> exerciseIds = const ['test-u'],
  int requiredItemCount = 1,
}) =>
    CourseSection(
      id: id,
      nodeId: nodeId,
      title: 'Override section $id',
      explanation: 'Override section-end explanation for $id.',
      contentRevision: 1,
      exerciseIds: exerciseIds,
      requiredItemCount: requiredItemCount,
    );

/// Builds the documented default listening exercise with overrides.
ListeningChoiceExercise _listening({
  String id = 'test-u',
  String sectionId = 'test-section',
  String audioRefId = 'fr-word-tout',
  String wordId = 'tout',
  String expectedSound = 'u',
  List<String> choices = const ['u', 'y'],
  String legacyItemId = 'tout',
}) =>
    ListeningChoiceExercise(
      id: id,
      sectionId: sectionId,
      audioRefId: audioRefId,
      purpose: ContentPurpose.practice,
      reviewState: ContentReviewState.existingCurated,
      wordId: wordId,
      expectedSound: expectedSound,
      choices: choices,
      legacyItemId: legacyItemId,
    );

/// Builds the documented default word audio reference with overrides.
CourseAudioReference _audio({
  String id = 'fr-word-tout',
  String spokenText = 'tout',
}) =>
    CourseAudioReference(
      id: id,
      kind: AudioReferenceKind.word,
      spokenText: spokenText,
    );

CourseValidationReport _validate(CourseCurriculum curriculum) =>
    validateCourseContent(
      curriculum,
      citationPhonemes: fixtureCitations,
      exposedWordIds: fixtureExposure,
      audioResources: fixtureAudioResources,
    );

/// (code, recordId, use) expectation per structural error.
typedef DiagnosticExpectation = (
  String code,
  String recordId,
  ContentPurpose? use
);

List<DiagnosticExpectation> _errors(CourseValidationReport report) => [
      for (final diagnostic in report.errors)
        (diagnostic.code, diagnostic.recordId, diagnostic.use),
    ];

void _expectRule({
  required String label,
  required CourseCurriculum Function() build,
  required List<DiagnosticExpectation> expected,
}) {
  test(label, () {
    final report = _validate(build());
    expect(
      _errors(report),
      expected,
      reason: 'structural rule $label',
    );
  });
}

/// The full deterministic diagnostic sequence, ready for exact comparison.
List<(String, String, ContentPurpose?, String)> _diagnosticSequence(
  CourseValidationReport report,
) =>
    [
      for (final diagnostic in report.errors)
        (
          diagnostic.code,
          diagnostic.recordId,
          diagnostic.use,
          diagnostic.message,
        ),
      for (final diagnostic in report.readinessIssues)
        (
          diagnostic.code,
          diagnostic.recordId,
          diagnostic.use,
          diagnostic.message,
        ),
    ];

void main() {
  group('fixture support', () {
    test('listeningFixture builds the documented valid defaults', () {
      final curriculum = listeningFixture();
      expect(curriculum.courseId, 'test-course');
      expect(curriculum.revision, 1);
      final node = curriculum.nodes.single;
      expect(node.id, 'test-listen');
      expect(node.kind, CourseNodeKind.lesson);
      expect(node.stage, CourseStage.hear);
      expect(node.status, ContentStatus.authored);
      expect(node.optional, isFalse);
      expect(node.prerequisiteIds, isEmpty);
      expect(node.sectionIds, ['test-section']);
      expect(node.targetSounds, ['u']);
      final section = curriculum.sections.single;
      expect(section.id, 'test-section');
      expect(section.nodeId, 'test-listen');
      expect(section.requiredItemCount, 1);
      expect(section.exerciseIds, ['test-u']);
      final exercise = curriculum.exercises.single;
      expect(exercise, isA<ListeningChoiceExercise>());
      final listening = exercise as ListeningChoiceExercise;
      expect(listening.id, 'test-u');
      expect(listening.sectionId, 'test-section');
      expect(listening.audioRefId, 'fr-word-tout');
      expect(listening.purpose, ContentPurpose.practice);
      expect(listening.reviewState, ContentReviewState.existingCurated);
      expect(listening.wordId, 'tout');
      expect(listening.expectedSound, 'u');
      expect(listening.choices, ['u', 'y']);
      expect(listening.legacyItemId, 'tout');
      expect(curriculum.sentences, isEmpty);
      final audio = curriculum.audioReferences.single;
      expect(audio.id, 'fr-word-tout');
      expect(audio.kind, AudioReferenceKind.word);
      expect(audio.spokenText, 'tout');
      final coverage = curriculum.phonemeCoverage;
      expect(coverage.map((c) => c.sound).toList(), ['u', 'y']);
      expect(coverage.first.discoveryStatus, ContentStatus.authored);
      expect(coverage.first.practiceExerciseIds, ['test-u']);
      expect(coverage.last.discoveryStatus, ContentStatus.planned);
      expect(coverage.last.practiceExerciseIds, isEmpty);
    });

    test('listeningFixture keeps supplied empty lists empty', () {
      final curriculum = listeningFixture(
        nodes: const [],
        sections: const [],
        exercises: const [],
        sentences: const [],
        audioReferences: const [],
        phonemeCoverage: const [],
      );
      expect(curriculum.courseId, 'test-course');
      expect(curriculum.revision, 1);
      expect(curriculum.nodes, isEmpty);
      expect(curriculum.sections, isEmpty);
      expect(curriculum.exercises, isEmpty);
      expect(curriculum.sentences, isEmpty);
      expect(curriculum.audioReferences, isEmpty);
      expect(curriculum.phonemeCoverage, isEmpty);
    });

    test('exposed fixture inputs are immutable as specified', () {
      expect(
        fixtureCitations,
        {
          'tout': ['t', 'u'],
          'tu': ['t', 'y'],
          'new-u': ['n', 'u']
        },
      );
      expect(fixtureExposure, {'tout', 'tu'});
      expect(
        fixtureAudioResources,
        {'fr-word-tout': AudioResourceStatus.practiceTts},
      );
      expect(
        () => fixtureCitations['tout']!.add('probe'),
        throwsUnsupportedError,
        reason: 'citation lists must be immutable',
      );
      expect(
        () => fixtureCitations['probe'] = const ['q'],
        throwsUnsupportedError,
        reason: 'citation map must be immutable',
      );
      expect(
        () => fixtureExposure.add('probe-word'),
        throwsUnsupportedError,
        reason: 'exposure set must be immutable',
      );
      expect(
        () => fixtureAudioResources['probe'] = AudioResourceStatus.missing,
        throwsUnsupportedError,
        reason: 'audio resource map must be immutable',
      );
    });
  });

  group('baseline behavior', () {
    test(
        'valid baseline is structurally valid with exactly the baseline readiness',
        () {
      final report = _validate(listeningFixture());
      expect(report.errors, isEmpty);
      expect(report.isStructurallyValid, isTrue);
      // Readiness now reports the planned y discovery slot and the word
      // reference that lacks a reviewed recording.
      expect(
        [
          for (final diagnostic in report.readinessIssues)
            (
              diagnostic.code,
              diagnostic.recordId,
              diagnostic.use,
            ),
        ],
        [
          ('plannedPhoneme', 'y', ContentPurpose.practice),
          ('missingReviewedAudio', 'fr-word-tout', ContentPurpose.assessment),
        ],
      );
    });

    test('exposed report collections are immutable', () {
      final report = _validate(listeningFixture());
      expect(
        () => report.errors.add(
          CourseContentDiagnostic(
            code: 'duplicateId',
            recordId: 'x',
            message: 'probe',
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => report.readinessIssues.clear(),
        throwsUnsupportedError,
      );
    });
  });

  group('duplicateId across the five lookup namespaces', () {
    _expectRule(
      label: 'duplicate node ID also blocks node lookups',
      build: () => listeningFixture(
        nodes: [
          _node(id: 'test-listen'),
          _node(),
        ],
      ),
      expected: [
        ('duplicateId', 'test-listen', null),
        ('missingReference', 'test-section', null),
      ],
    );
    _expectRule(
      label: 'duplicate section ID also blocks section lookups',
      build: () => listeningFixture(
        sections: [
          _section(id: 'test-section'),
          _section(),
        ],
      ),
      expected: [
        ('duplicateId', 'test-section', null),
        ('missingReference', 'test-listen', null),
        ('missingReference', 'test-u', null),
      ],
    );
    _expectRule(
      label: 'duplicate exercise ID also blocks exercise lookups',
      build: () => listeningFixture(exercises: [_listening(), _listening()]),
      expected: [
        ('duplicateId', 'test-u', null),
        ('missingReference', 'test-section', null),
        ('invalidCoverage', 'u', null),
      ],
    );
    _expectRule(
      label: 'duplicate sentence ID',
      build: () => listeningFixture(
        sentences: [
          CourseSentence(
            id: 's-1',
            text: 'Tout est tout.',
            audioRefId: 'fr-s-1',
            tokens: const [],
            reviewState: ContentReviewState.existingCurated,
          ),
          CourseSentence(
            id: 's-1',
            text: 'Second copy.',
            audioRefId: 'fr-s-1',
            tokens: const [],
            reviewState: ContentReviewState.existingCurated,
          ),
        ],
      ),
      expected: [
        ('duplicateId', 's-1', null),
        ('missingReference', 's-1', null),
        ('invalidSentenceTokens', 's-1', null),
        ('missingReference', 's-1', null),
        ('invalidSentenceTokens', 's-1', null),
      ],
    );
    _expectRule(
      label: 'duplicate audio reference ID',
      build: () => listeningFixture(audioReferences: [_audio(), _audio()]),
      expected: [
        ('duplicateId', 'fr-word-tout', null),
        ('missingReference', 'test-u', null),
      ],
    );
  });

  group('duplicateMembership in prerequisite, section and exercise lists', () {
    _expectRule(
      label: 'repeated prerequisite ID',
      build: () => listeningFixture(
        nodes: [
          _node(prerequisiteIds: const ['n-a', 'n-a'])
        ],
      ),
      expected: [
        ('duplicateMembership', 'test-listen', null),
        ('missingReference', 'test-listen', null),
      ],
    );
    _expectRule(
      label: 'repeated section ID in the owning node',
      build: () => listeningFixture(
        nodes: [
          _node(sectionIds: const ['test-section', 'test-section'])
        ],
      ),
      expected: [
        ('duplicateMembership', 'test-listen', null),
      ],
    );
    _expectRule(
      label: 'repeated exercise ID in the owning section',
      build: () => listeningFixture(
        sections: [
          _section(exerciseIds: const ['test-u', 'test-u'])
        ],
      ),
      expected: [
        ('duplicateMembership', 'test-section', null),
      ],
    );
  });

  group('missingReference for absent or ambiguous links', () {
    _expectRule(
      label: 'node prerequisite points to an absent node',
      build: () => listeningFixture(
        nodes: [
          _node(prerequisiteIds: const ['ghost-node'])
        ],
      ),
      expected: [
        ('missingReference', 'test-listen', null),
      ],
    );
    _expectRule(
      label: 'node section link points to an absent section',
      build: () => listeningFixture(
        nodes: [
          _node(sectionIds: const ['ghost-section'])
        ],
      ),
      expected: [
        ('missingReference', 'test-listen', null),
        ('ownershipMismatch', 'test-section', null),
        ('unownedRecord', 'test-section', null),
      ],
    );
    _expectRule(
      label: 'section owner points to an absent node',
      build: () => listeningFixture(
        sections: [_section(nodeId: 'ghost-node')],
      ),
      expected: [
        ('missingReference', 'test-section', null),
        ('ownershipMismatch', 'test-listen', null),
      ],
    );
    _expectRule(
      label: 'section exercise link points to an absent exercise',
      build: () => listeningFixture(
        sections: [
          _section(exerciseIds: const ['ghost-u'])
        ],
        exercises: const [],
      ),
      expected: [
        ('missingReference', 'test-section', null),
        ('invalidCoverage', 'u', null),
      ],
    );
    _expectRule(
      label: 'exercise owner points to an absent section',
      build: () => listeningFixture(
        exercises: [_listening(sectionId: 'ghost-section')],
      ),
      expected: [
        ('missingReference', 'test-u', null),
        ('ownershipMismatch', 'test-section', null),
      ],
    );
  });

  group('cyclicPrerequisite', () {
    _expectRule(
      label: 'self prerequisite edge',
      build: () => listeningFixture(
        nodes: [
          _node(prerequisiteIds: const ['test-listen'])
        ],
      ),
      expected: [
        ('cyclicPrerequisite', 'test-listen', null),
      ],
    );
    _expectRule(
      label: 'two-node A to B to A cycle is reported once',
      build: () => listeningFixture(
        nodes: [
          _node(
            id: 'opt-a',
            kind: CourseNodeKind.game,
            optional: true,
            prerequisiteIds: const ['opt-b'],
            sectionIds: const [],
            targetSounds: const [],
          ),
          _node(
            id: 'opt-b',
            kind: CourseNodeKind.game,
            optional: true,
            prerequisiteIds: const ['opt-a'],
            sectionIds: const [],
            targetSounds: const [],
          ),
        ],
        sections: const [],
        exercises: const [],
      ),
      expected: [
        ('cyclicPrerequisite', 'opt-b', null),
        ('invalidCoverage', 'u', null),
      ],
    );
  });

  group('optionalPrerequisite', () {
    _expectRule(
      label: 'required lesson depends on an optional game',
      build: () => listeningFixture(
        nodes: [
          _node(prerequisiteIds: const ['opt-game']),
          _node(
            id: 'opt-game',
            kind: CourseNodeKind.game,
            optional: true,
            sectionIds: const [],
            targetSounds: const [],
          ),
        ],
      ),
      expected: [
        ('optionalPrerequisite', 'test-listen', null),
      ],
    );
  });

  group('backwardStage', () {
    _expectRule(
      label: 'hear main node depends on spell main node',
      build: () => listeningFixture(
        nodes: [
          _node(
            id: 'hear-main',
            prerequisiteIds: const ['spell-main'],
            sectionIds: const ['s-hear'],
          ),
          _node(
            id: 'spell-main',
            stage: CourseStage.spell,
            sectionIds: const ['s-spell'],
          ),
        ],
        sections: [
          _section(
              id: 's-hear', nodeId: 'hear-main', exerciseIds: const ['e-hear']),
          _section(
              id: 's-spell',
              nodeId: 'spell-main',
              exerciseIds: const ['e-spell']),
        ],
        exercises: [
          _listening(id: 'e-hear', sectionId: 's-hear', audioRefId: 'a-hear'),
          _listening(
            id: 'e-spell',
            sectionId: 's-spell',
            audioRefId: 'a-spell',
            wordId: 'tu',
            expectedSound: 'y',
            legacyItemId: 'tu',
          ),
        ],
        audioReferences: [
          _audio(id: 'a-hear'),
          _audio(id: 'a-spell', spokenText: 'tu'),
        ],
      ),
      expected: [
        ('backwardStage', 'hear-main', null),
        ('invalidExercisePlacement', 'e-spell', null),
        ('invalidTargets', 'e-spell', null),
        ('invalidCoverage', 'u', null),
      ],
    );
  });

  group('invalidNodeKind', () {
    _expectRule(
      label: 'assessment declared outside the assess stage',
      build: () => listeningFixture(
        nodes: [
          _node(
            id: 'assess-early',
            kind: CourseNodeKind.assessment,
            sectionIds: const ['s-1'],
          ),
        ],
        sections: [
          _section(
              id: 's-1', nodeId: 'assess-early', exerciseIds: const ['e-1']),
        ],
        exercises: [_listening(id: 'e-1', sectionId: 's-1', audioRefId: 'a-1')],
        audioReferences: [_audio(id: 'a-1')],
      ),
      expected: [
        ('invalidNodeKind', 'assess-early', null),
        ('invalidExercisePlacement', 'e-1', null),
        ('invalidCoverage', 'u', null),
      ],
    );
    _expectRule(
      label: 'review declared required',
      build: () => listeningFixture(
        nodes: [
          _node(
            id: 'review-main',
            kind: CourseNodeKind.review,
            sectionIds: const [],
            targetSounds: const [],
          ),
        ],
        sections: const [],
        exercises: const [],
      ),
      expected: [
        ('invalidNodeKind', 'review-main', null),
        ('invalidCoverage', 'u', null),
      ],
    );
    _expectRule(
      label: 'game declared required',
      build: () => listeningFixture(
        nodes: [
          _node(
            id: 'game-main',
            kind: CourseNodeKind.game,
            sectionIds: const [],
            targetSounds: const [],
          ),
        ],
        sections: const [],
        exercises: const [],
      ),
      expected: [
        ('invalidNodeKind', 'game-main', null),
        ('invalidCoverage', 'u', null),
      ],
    );
    _expectRule(
      label: 'articulation declared required',
      build: () => listeningFixture(
        nodes: [
          _node(
            id: 'articulation-main',
            kind: CourseNodeKind.articulation,
            sectionIds: const [],
            targetSounds: const [],
          ),
        ],
        sections: const [],
        exercises: const [],
      ),
      expected: [
        ('invalidNodeKind', 'articulation-main', null),
        ('invalidCoverage', 'u', null),
      ],
    );
  });

  group('ownershipMismatch in both directions', () {
    _expectRule(
      label: 'section claims a node that does not list it',
      build: () => listeningFixture(
        nodes: [
          _node(id: 'owner-a', sectionIds: const ['owned-b']),
          _node(
            id: 'owner-b',
            kind: CourseNodeKind.game,
            optional: true,
            sectionIds: const [],
            targetSounds: const [],
          ),
        ],
        sections: [
          _section(
            id: 'owned-b',
            nodeId: 'owner-b',
            exerciseIds: const ['ex-b'],
          ),
        ],
        exercises: [
          _listening(id: 'ex-b', sectionId: 'owned-b', audioRefId: 'a-b')
        ],
        audioReferences: [_audio(id: 'a-b')],
      ),
      expected: [
        ('ownershipMismatch', 'owned-b', null),
        ('ownershipMismatch', 'owner-a', null),
        ('invalidTargets', 'ex-b', null),
        ('invalidCoverage', 'u', null),
      ],
    );
    _expectRule(
      label: 'exercise claims a section that does not list it',
      build: () => listeningFixture(
        nodes: [
          _node(id: 'owner-a', sectionIds: const ['s-1', 's-2'])
        ],
        sections: [
          _section(
            id: 's-1',
            nodeId: 'owner-a',
            exerciseIds: const ['e-1', 'e-2'],
            requiredItemCount: 2,
          ),
          _section(id: 's-2', nodeId: 'owner-a', exerciseIds: const ['e-2']),
        ],
        exercises: [
          _listening(id: 'e-1', sectionId: 's-2', audioRefId: 'a-1'),
          _listening(
            id: 'e-2',
            sectionId: 's-1',
            audioRefId: 'a-2',
            wordId: 'tu',
            expectedSound: 'y',
            legacyItemId: 'tu',
          ),
        ],
        audioReferences: [
          _audio(id: 'a-1'),
          _audio(id: 'a-2', spokenText: 'tu'),
        ],
      ),
      expected: [
        ('ownershipMismatch', 'e-1', null),
        ('ownershipMismatch', 's-1', null),
        ('ownershipMismatch', 's-2', null),
        ('invalidTargets', 'e-2', null),
        ('invalidCoverage', 'u', null),
      ],
    );
  });

  group('unownedRecord', () {
    _expectRule(
      label: 'section in the catalogue in no node list',
      build: () => listeningFixture(
        sections: [
          _section(),
          _section(id: 'extra-section', exerciseIds: const []),
        ],
      ),
      expected: [
        ('ownershipMismatch', 'extra-section', null),
        ('poolSizeMismatch', 'extra-section', null),
        ('unownedRecord', 'extra-section', null),
      ],
    );
    _expectRule(
      label: 'exercise in the catalogue in no section list',
      build: () => listeningFixture(
        exercises: [
          _listening(),
          _listening(
            id: 'extra-u',
            wordId: 'tu',
            expectedSound: 'y',
            legacyItemId: 'tu',
            audioRefId: 'fr-word-tu',
          ),
        ],
        audioReferences: [
          _audio(),
          _audio(id: 'fr-word-tu', spokenText: 'tu'),
        ],
      ),
      expected: [
        ('ownershipMismatch', 'extra-u', null),
        ('unownedRecord', 'extra-u', null),
        ('invalidTargets', 'extra-u', null),
      ],
    );
  });

  group('poolSizeMismatch', () {
    _expectRule(
      label: 'one distinct linked exercise against a required count of two',
      build: () => listeningFixture(
        sections: [_section(requiredItemCount: 2)],
      ),
      expected: [
        ('poolSizeMismatch', 'test-section', null),
      ],
    );
    _expectRule(
      label: 'distinct linked exercises exceeding the required count',
      build: () => listeningFixture(
        sections: [
          _section(exerciseIds: const ['test-u', 'test-v']),
        ],
        exercises: [
          _listening(),
          _listening(
            id: 'test-v',
            wordId: 'tu',
            expectedSound: 'y',
            legacyItemId: 'tu',
            audioRefId: 'fr-word-tu',
          ),
        ],
        audioReferences: [
          _audio(),
          _audio(id: 'fr-word-tu', spokenText: 'tu'),
        ],
      ),
      expected: [
        ('poolSizeMismatch', 'test-section', null),
        ('invalidTargets', 'test-v', null),
      ],
    );
  });

  group('duplicateLegacyItemId', () {
    _expectRule(
      label: 'two distinct listening exercises share an alias in one section',
      build: () => listeningFixture(
        nodes: [
          _node(targetSounds: const ['u', 'y']),
        ],
        sections: [
          _section(
              exerciseIds: const ['test-u', 'test-v'], requiredItemCount: 2),
        ],
        exercises: [
          _listening(),
          _listening(
            id: 'test-v',
            wordId: 'tu',
            expectedSound: 'y',
            legacyItemId: 'tout',
            audioRefId: 'fr-word-tu',
          ),
        ],
        audioReferences: [
          _audio(),
          _audio(id: 'fr-word-tu', spokenText: 'tu'),
        ],
      ),
      expected: [
        ('duplicateLegacyItemId', 'test-section', null),
      ],
    );
    _expectRule(
      label: 'the same alias across different sections stays clean',
      build: () => listeningFixture(
        nodes: [
          _node(
              id: 'n-cross',
              sectionIds: const ['s-a', 's-b'],
              targetSounds: const ['u', 'y']),
        ],
        phonemeCoverage: [
          PhonemeCoverage(
            sound: 'u',
            discoveryStatus: ContentStatus.authored,
            practiceExerciseIds: const ['e-a'],
          ),
          PhonemeCoverage(
            sound: 'y',
            discoveryStatus: ContentStatus.authored,
            practiceExerciseIds: const ['e-b'],
          ),
        ],
        sections: [
          _section(id: 's-a', nodeId: 'n-cross', exerciseIds: const ['e-a']),
          _section(id: 's-b', nodeId: 'n-cross', exerciseIds: const ['e-b']),
        ],
        exercises: [
          _listening(id: 'e-a', sectionId: 's-a', audioRefId: 'a-a'),
          _listening(
            id: 'e-b',
            sectionId: 's-b',
            audioRefId: 'a-b',
            wordId: 'tu',
            expectedSound: 'y',
            legacyItemId: 'tout',
          ),
        ],
        audioReferences: [
          _audio(id: 'a-a'),
          _audio(id: 'a-b', spokenText: 'tu'),
        ],
      ),
      expected: const [],
    );
  });

  group('plannedPayload', () {
    _expectRule(
      label: 'planned node declares a section',
      build: () => listeningFixture(
        nodes: [_node(status: ContentStatus.planned)],
      ),
      expected: [
        ('plannedPayload', 'test-listen', null),
      ],
    );
    _expectRule(
      label: 'planned node without sections stays clean',
      build: () => listeningFixture(
        nodes: [
          _node(
              status: ContentStatus.planned,
              sectionIds: const [],
              targetSounds: const [])
        ],
        sections: const [],
        exercises: const [],
        phonemeCoverage: const [],
      ),
      expected: const [],
    );
  });

  group('missingSection', () {
    _expectRule(
      label: 'authored lesson with zero sections',
      build: () => listeningFixture(
        nodes: [_node(sectionIds: const [], targetSounds: const [])],
        sections: const [],
        exercises: const [],
        phonemeCoverage: const [],
      ),
      expected: [
        ('missingSection', 'test-listen', null),
      ],
    );
    _expectRule(
      label: 'authored assessment with zero sections',
      build: () => listeningFixture(
        nodes: [
          _node(
            id: 'assess-empty',
            kind: CourseNodeKind.assessment,
            stage: CourseStage.assess,
            sectionIds: const [],
            targetSounds: const [],
          ),
        ],
        sections: const [],
        exercises: const [],
        phonemeCoverage: const [],
      ),
      expected: [
        ('missingSection', 'assess-empty', null),
      ],
    );
  });

  group('combined malformed fixture', () {
    CourseCurriculum buildCombined() => listeningFixture(
          nodes: [
            _node(prerequisiteIds: const ['test-listen'], sectionIds: const []),
          ],
          sections: const [],
          exercises: const [],
          audioReferences: [_audio(), _audio()],
        );

    test('reports missing section, duplicated audio ID and cycle together', () {
      final report = _validate(buildCombined());
      expect(
        _errors(report),
        [
          ('duplicateId', 'fr-word-tout', null),
          ('missingSection', 'test-listen', null),
          ('cyclicPrerequisite', 'test-listen', null),
          ('invalidCoverage', 'u', null),
        ],
      );
      expect(report.isStructurallyValid, isFalse);
      // Structural errors never carry a use.
      expect(
          report.errors.every((diagnostic) => diagnostic.use == null), isTrue);
      // Readiness phases: planned y slot, then the duplicated word reference
      // copies each lacking a reviewed recording.
      expect(
        [
          for (final diagnostic in report.readinessIssues)
            (diagnostic.code, diagnostic.recordId, diagnostic.use),
        ],
        [
          ('plannedPhoneme', 'y', ContentPurpose.practice),
          ('missingReviewedAudio', 'fr-word-tout', ContentPurpose.assessment),
          ('missingReviewedAudio', 'fr-word-tout', ContentPurpose.assessment),
        ],
      );
    });

    test('repeated validation gives an identical diagnostic sequence', () {
      final first = _validate(buildCombined());
      final second = _validate(buildCombined());
      expect(_diagnosticSequence(first), _diagnosticSequence(second));
    });

    test('validation reads and never mutates caller collections', () {
      final prerequisiteIds = <String>['test-listen'];
      final sectionIds = <String>['test-section'];
      final prerequisiteNode = _node(
        prerequisiteIds: prerequisiteIds,
        sectionIds: sectionIds,
      );
      final defaultSection = _section();
      final defaultExercise = _listening();
      final nodes = <CourseNode>[prerequisiteNode];
      final sections = <CourseSection>[defaultSection];
      final exercises = <CourseExercise>[defaultExercise];
      final firstAudio = _audio();
      final secondAudio = _audio();
      final audioReferences = <CourseAudioReference>[firstAudio, secondAudio];
      final fixture = listeningFixture(
        nodes: nodes,
        sections: sections,
        exercises: exercises,
        audioReferences: audioReferences,
      );

      _validate(fixture);

      expect(prerequisiteIds, ['test-listen']);
      expect(sectionIds, ['test-section']);
      expect(nodes, [prerequisiteNode]);
      expect(sections, [defaultSection]);
      expect(exercises, [defaultExercise]);
      expect(audioReferences, [firstAudio, secondAudio]);
      // Caller collections remain mutable; the fixture only detached copies.
      prerequisiteIds.add('probe');
      expect(prerequisiteIds, ['test-listen', 'probe']);
      prerequisiteIds.removeLast();
    });
  });
}
