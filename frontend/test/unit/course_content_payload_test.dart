import 'package:flutter_test/flutter_test.dart';

import 'package:linguist/src/core/course/course_content_validator.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/course_curriculum.dart';

import '../support/course_curriculum_fixtures.dart';

/// Builds a node with one-override defaults for a single payload rule.
CourseNode _node({
  String id = 'n-1',
  CourseNodeKind kind = CourseNodeKind.lesson,
  CourseStage stage = CourseStage.hear,
  ContentStatus status = ContentStatus.authored,
  bool optional = false,
  List<String> sectionIds = const ['s-1'],
  List<String> targetSounds = const ['u'],
}) =>
    CourseNode(
      id: id,
      title: 'Payload node $id',
      kind: kind,
      stage: stage,
      status: status,
      optional: optional,
      prerequisiteIds: const [],
      sectionIds: sectionIds,
      targetSounds: targetSounds,
    );

/// Builds a section owning the default exercise list.
CourseSection _section({
  String id = 's-1',
  String nodeId = 'n-1',
  List<String> exerciseIds = const ['e-1'],
  int requiredItemCount = 1,
}) =>
    CourseSection(
      id: id,
      nodeId: nodeId,
      title: 'Payload section $id',
      explanation: 'Section-end explanation for $id.',
      contentRevision: 1,
      exerciseIds: exerciseIds,
      requiredItemCount: requiredItemCount,
    );

/// Practice-or-assessment listening exercise with one-override defaults.
ListeningChoiceExercise _listening({
  String id = 'e-1',
  String sectionId = 's-1',
  String audioRefId = 'a-word',
  ContentPurpose purpose = ContentPurpose.practice,
  ContentReviewState reviewState = ContentReviewState.existingCurated,
  String wordId = 'tout',
  String expectedSound = 'u',
  List<String> choices = const ['u', 'y'],
}) =>
    ListeningChoiceExercise(
      id: id,
      sectionId: sectionId,
      audioRefId: audioRefId,
      purpose: purpose,
      reviewState: reviewState,
      wordId: wordId,
      expectedSound: expectedSound,
      choices: choices,
    );

SpellingChoiceExercise _spelling({
  String id = 'e-1',
  String sectionId = 's-1',
  String audioRefId = 'a-word',
  ContentPurpose purpose = ContentPurpose.practice,
  ContentReviewState reviewState = ContentReviewState.existingCurated,
  String wordId = 'tout',
  String targetSound = 'u',
  List<SpellingOption>? options,
  String correctOptionId = 'opt-1',
}) =>
    SpellingChoiceExercise(
      id: id,
      sectionId: sectionId,
      audioRefId: audioRefId,
      purpose: purpose,
      reviewState: reviewState,
      wordId: wordId,
      targetSound: targetSound,
      options: options ??
          [
            SpellingOption(id: 'opt-1', text: 'tout'),
            SpellingOption(id: 'opt-2', text: 'totu'),
          ],
      correctOptionId: correctOptionId,
    );

SentenceHuntExercise _hunt({
  String id = 'e-1',
  String sectionId = 's-1',
  String audioRefId = 'a-sentence',
  ContentPurpose purpose = ContentPurpose.practice,
  ContentReviewState reviewState = ContentReviewState.existingCurated,
  String sentenceId = 's-x',
  String targetSound = 'u',
}) =>
    SentenceHuntExercise(
      id: id,
      sectionId: sectionId,
      audioRefId: audioRefId,
      purpose: purpose,
      reviewState: reviewState,
      sentenceId: sentenceId,
      targetSound: targetSound,
    );

ReadAloudExercise _readAloud({
  String id = 'e-1',
  String sectionId = 's-1',
  String audioRefId = 'a-paragraph',
  ContentPurpose purpose = ContentPurpose.practice,
  ContentReviewState reviewState = ContentReviewState.existingCurated,
  String promptText = 'tout',
  List<String> targetSounds = const ['u'],
}) =>
    ReadAloudExercise(
      id: id,
      sectionId: sectionId,
      audioRefId: audioRefId,
      purpose: purpose,
      reviewState: reviewState,
      promptText: promptText,
      targetSounds: targetSounds,
    );

CourseAudioReference _wordRef({
  String id = 'a-word',
  String spokenText = 'tout',
}) =>
    CourseAudioReference(
      id: id,
      kind: AudioReferenceKind.word,
      spokenText: spokenText,
    );

CourseAudioReference _sentenceRef({
  String id = 'a-sentence',
  String spokenText = 'tout tu tout.',
}) =>
    CourseAudioReference(
      id: id,
      kind: AudioReferenceKind.sentence,
      spokenText: spokenText,
    );

CourseAudioReference _paragraphRef({
  String id = 'a-paragraph',
  String spokenText = 'tout',
}) =>
    CourseAudioReference(
      id: id,
      kind: AudioReferenceKind.paragraph,
      spokenText: spokenText,
    );

PhonemeCoverage _cov(
  String sound, {
  ContentStatus status = ContentStatus.authored,
  List<String> practiceExerciseIds = const ['e-1'],
}) =>
    PhonemeCoverage(
      sound: sound,
      discoveryStatus: status,
      practiceExerciseIds: practiceExerciseIds,
    );

CourseCurriculum _curriculum({
  List<CourseNode> nodes = const [],
  List<CourseSection> sections = const [],
  List<CourseExercise> exercises = const [],
  List<CourseSentence> sentences = const [],
  List<CourseAudioReference> audioReferences = const [],
  List<PhonemeCoverage> phonemeCoverage = const [],
}) =>
    CourseCurriculum(
      courseId: 'test-course',
      revision: 1,
      nodes: nodes,
      sections: sections,
      exercises: exercises,
      sentences: sentences,
      audioReferences: audioReferences,
      phonemeCoverage: phonemeCoverage,
    );

const Map<String, List<String>> _citations = {
  'tout': ['t', 'u'],
  'tu': ['t', 'y'],
  'new-u': ['n', 'u'],
};

CourseValidationReport _v(
  CourseCurriculum curriculum, {
  Map<String, List<String>> citationPhonemes = _citations,
  Set<String> exposedWordIds = const {},
  Map<String, AudioResourceStatus> audioResources = const {},
}) =>
    validateCourseContent(
      curriculum,
      citationPhonemes: citationPhonemes,
      exposedWordIds: exposedWordIds,
      audioResources: audioResources,
    );

/// (code, recordId) per structural error; structural errors never carry use.
List<(String, String)> _errors(CourseValidationReport report) => [
      for (final diagnostic in report.errors)
        (diagnostic.code, diagnostic.recordId),
    ];

List<(String, String, ContentPurpose?)> _readiness(
  CourseValidationReport report,
) =>
    [
      for (final diagnostic in report.readinessIssues)
        (
          diagnostic.code,
          diagnostic.recordId,
          diagnostic.use,
        ),
    ];

void _expectRule({
  required String label,
  required CourseCurriculum Function() build,
  required List<(String, String)> expectedErrors,
  Map<String, List<String>> citations = _citations,
  Set<String> exposedWordIds = const {},
  Map<String, AudioResourceStatus> audioResources = const {},
}) {
  test(label, () {
    final report = _v(
      build(),
      citationPhonemes: citations,
      exposedWordIds: exposedWordIds,
      audioResources: audioResources,
    );
    expect(
      _errors(report),
      expectedErrors,
      reason: 'rule $label',
    );
  });
}

void main() {
  group('invalidExercisePlacement', () {
    _expectRule(
      label: 'practice listening outside the hear stage',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.find)],
        sections: [_section()],
        exercises: [_listening()],
        audioReferences: [_wordRef()],
        phonemeCoverage: [
          _cov('u'),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('invalidExercisePlacement', 'e-1')],
    );
    _expectRule(
      label: 'practice spelling outside the spell stage',
      build: () => _curriculum(
        nodes: [
          _node(stage: CourseStage.hear, targetSounds: const ['u'])
        ],
        sections: [_section()],
        exercises: [_spelling()],
        audioReferences: [_wordRef()],
        phonemeCoverage: [_cov('u')],
      ),
      expectedErrors: [('invalidExercisePlacement', 'e-1')],
    );
    _expectRule(
      label: 'practice sentence hunt outside the find stage',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.spell)],
        sections: [_section()],
        exercises: [_hunt()],
        sentences: [sentenceFixture(id: 's-x', audioRefId: 'a-sentence')],
        audioReferences: [_sentenceRef(id: 'a-sentence')],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const [])
        ],
      ),
      expectedErrors: [('invalidExercisePlacement', 'e-1')],
    );
    _expectRule(
      label: 'assessment-purpose exercise in a lesson node',
      build: () => _curriculum(
        nodes: [_node()],
        sections: [_section()],
        exercises: [
          _listening(
            purpose: ContentPurpose.assessment,
            wordId: 'new-u',
            audioRefId: 'a-new',
          ),
        ],
        audioReferences: [_wordRef(id: 'a-new', spokenText: 'new-u')],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('invalidExercisePlacement', 'e-1')],
    );
    _expectRule(
      label:
          'practice exercise in an assessment node breaks both purpose and stage',
      build: () => _curriculum(
        nodes: [
          _node(
              id: 'n-a',
              kind: CourseNodeKind.assessment,
              stage: CourseStage.assess),
        ],
        sections: [_section(nodeId: 'n-a')],
        exercises: [_listening()],
        audioReferences: [_wordRef()],
        phonemeCoverage: [
          _cov('u'),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [
        ('invalidExercisePlacement', 'e-1'),
        ('invalidExercisePlacement', 'e-1'),
      ],
    );
    _expectRule(
      label: 'assessment exercise in an assessment node on the wrong stage',
      build: () => _curriculum(
        nodes: [
          _node(
            id: 'n-a',
            kind: CourseNodeKind.assessment,
            stage: CourseStage.hear,
          ),
        ],
        sections: [_section(nodeId: 'n-a')],
        exercises: [
          _listening(
            purpose: ContentPurpose.assessment,
            wordId: 'new-u',
            audioRefId: 'a-new',
          ),
        ],
        audioReferences: [_wordRef(id: 'a-new', spokenText: 'new-u')],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [
        ('invalidNodeKind', 'n-a'),
        ('invalidExercisePlacement', 'e-1'),
      ],
    );
    _expectRule(
      label: 'read-aloud in a lesson node',
      build: () => _curriculum(
        nodes: [_node()],
        sections: [_section()],
        exercises: [_readAloud()],
        audioReferences: [_paragraphRef()],
        phonemeCoverage: [_cov('u')],
      ),
      expectedErrors: [('invalidExercisePlacement', 'e-1')],
    );
    _expectRule(
      label: 'read-aloud in a non-articulation non-assessment node',
      build: () => _curriculum(
        nodes: [
          _node(kind: CourseNodeKind.game, optional: true),
        ],
        sections: [_section()],
        exercises: [_readAloud()],
        audioReferences: [_paragraphRef()],
        phonemeCoverage: [_cov('u')],
      ),
      expectedErrors: [('invalidExercisePlacement', 'e-1')],
    );
    test('read-aloud is valid in an optional articulation node', () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(kind: CourseNodeKind.articulation, optional: true),
          ],
          sections: [_section()],
          exercises: [_readAloud()],
          audioReferences: [_paragraphRef()],
          phonemeCoverage: [_cov('u')],
        ),
        audioResources: const {'a-paragraph': AudioResourceStatus.practiceTts},
      );
      expect(_errors(report), isEmpty, reason: 'articulation read-aloud');
      expect(
        _readiness(report),
        [('speakingUnassessed', 'e-1', ContentPurpose.assessment)],
        reason: 'read-aloud never implies a scored evaluator in FR-01',
      );
    });
    test('read-aloud is valid in an assessment node with assessment purpose',
        () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(
              id: 'n-a',
              kind: CourseNodeKind.assessment,
              stage: CourseStage.assess,
            ),
          ],
          sections: [_section(nodeId: 'n-a')],
          exercises: [
            _readAloud(
              purpose: ContentPurpose.assessment,
              reviewState: ContentReviewState.reviewed,
              audioRefId: 'a-para-a',
            ),
          ],
          audioReferences: [
            _paragraphRef(id: 'a-para-a'),
          ],
          phonemeCoverage: [
            _cov('u',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
        audioResources: const {
          'a-para-a': AudioResourceStatus.reviewedRecording
        },
      );
      expect(_errors(report), isEmpty, reason: 'assessment read-aloud');
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'u', ContentPurpose.practice),
          ('speakingUnassessed', 'e-1', ContentPurpose.assessment),
        ],
        reason: 'assessment read-aloud is still unassessed in FR-01',
      );
    });
  });

  group('invalidTargets', () {
    _expectRule(
      label: 'duplicate node target labels',
      build: () => _curriculum(
        nodes: [
          _node(targetSounds: const ['u', 'u'])
        ],
        sections: [_section()],
        exercises: [_listening()],
        audioReferences: [_wordRef()],
        phonemeCoverage: [
          _cov('u'),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('invalidTargets', 'n-1')],
    );
    _expectRule(
      label: 'empty node target label',
      build: () => _curriculum(
        nodes: [
          _node(targetSounds: const ['u', ''])
        ],
        sections: [_section()],
        exercises: [_listening()],
        audioReferences: [_wordRef()],
        phonemeCoverage: [
          _cov('u'),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('invalidTargets', 'n-1')],
    );
    _expectRule(
      label:
          'exercise target outside the declared inventory then outside node targets',
      build: () => _curriculum(
        nodes: [
          _node(targetSounds: const ['u'])
        ],
        sections: [_section()],
        exercises: [
          _listening(expectedSound: 't', choices: const ['t', 'u']),
        ],
        audioReferences: [_wordRef()],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [
        ('invalidTargets', 'e-1'),
        ('invalidTargets', 'e-1'),
        ('invalidListeningChoices', 'e-1'),
      ],
    );
    _expectRule(
      label: 'declared exercise target that its node does not teach',
      build: () => _curriculum(
        nodes: [
          _node(targetSounds: const ['u'])
        ],
        sections: [_section()],
        exercises: [
          _listening(
            wordId: 'tu',
            expectedSound: 'y',
            choices: const ['u', 'y'],
            audioRefId: 'a-tu',
          ),
        ],
        audioReferences: [_wordRef(id: 'a-tu', spokenText: 'tu')],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('invalidTargets', 'e-1')],
    );
    _expectRule(
      label: 'empty read-aloud targets',
      build: () => _curriculum(
        nodes: [
          _node(kind: CourseNodeKind.articulation, optional: true),
        ],
        sections: [_section()],
        exercises: [_readAloud(targetSounds: const [])],
        audioReferences: [_paragraphRef()],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('invalidTargets', 'e-1')],
    );
    _expectRule(
      label: 'read-aloud target undeclared and outside node targets',
      build: () => _curriculum(
        nodes: [
          _node(
              kind: CourseNodeKind.articulation,
              optional: true,
              targetSounds: const ['u'])
        ],
        sections: [_section()],
        exercises: [
          _readAloud(targetSounds: const ['i'])
        ],
        audioReferences: [_paragraphRef()],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [
        ('invalidTargets', 'e-1'),
        ('invalidTargets', 'e-1'),
      ],
    );
    _expectRule(
      label:
          'read-aloud undeclared target is reported despite a dangling owner',
      build: () => _curriculum(
        exercises: [
          _readAloud(sectionId: 'ghost-section', targetSounds: const ['i'])
        ],
        audioReferences: [_paragraphRef()],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [
        ('missingReference', 'e-1'),
        ('unownedRecord', 'e-1'),
        ('invalidTargets', 'e-1'),
      ],
    );
    _expectRule(
      label: 'read-aloud empty targets are reported despite a dangling owner',
      build: () => _curriculum(
        exercises: [
          _readAloud(sectionId: 'ghost-section', targetSounds: const [])
        ],
        audioReferences: [_paragraphRef()],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [
        ('missingReference', 'e-1'),
        ('unownedRecord', 'e-1'),
        ('invalidTargets', 'e-1'),
      ],
    );
    _expectRule(
      label: 'repeated read-aloud target labels are invalid even when declared',
      build: () => _curriculum(
        nodes: [
          _node(
              kind: CourseNodeKind.articulation,
              optional: true,
              targetSounds: const ['u'])
        ],
        sections: [_section()],
        exercises: [
          _readAloud(targetSounds: const ['u', 'u'])
        ],
        audioReferences: [_paragraphRef()],
        phonemeCoverage: [
          _cov('u', practiceExerciseIds: const ['e-1']),
        ],
      ),
      expectedErrors: [
        ('invalidTargets', 'e-1'),
      ],
    );
  });

  group('invalidListeningChoices', () {
    _expectRule(
      label: 'fewer than two distinct choices',
      build: () => _curriculum(
        nodes: [_node()],
        sections: [_section()],
        exercises: [
          _listening(choices: const ['u'])
        ],
        audioReferences: [_wordRef()],
        phonemeCoverage: [_cov('u')],
      ),
      expectedErrors: [('invalidListeningChoices', 'e-1')],
    );
    _expectRule(
      label: 'duplicate choice labels',
      build: () => _curriculum(
        nodes: [
          _node(targetSounds: const ['u', 'y'])
        ],
        sections: [_section()],
        exercises: [
          _listening(choices: const ['u', 'u'])
        ],
        audioReferences: [_wordRef()],
        phonemeCoverage: [
          _cov('u'),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [
        ('invalidListeningChoices', 'e-1'),
        ('invalidListeningChoices', 'e-1'),
        ('invalidListeningChoices', 'e-1'),
      ],
    );
    _expectRule(
      label: 'expected sound absent from the choices',
      build: () => _curriculum(
        nodes: [
          _node(targetSounds: const ['u', 'i', 'o'])
        ],
        sections: [_section()],
        exercises: [
          _listening(choices: const ['i', 'o'])
        ],
        audioReferences: [_wordRef()],
        phonemeCoverage: [
          _cov('u'),
          _cov('i',
              status: ContentStatus.planned, practiceExerciseIds: const []),
          _cov('o',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('invalidListeningChoices', 'e-1')],
    );
    _expectRule(
      label: 'expected sound repeated among the choices',
      build: () => _curriculum(
        nodes: [
          _node(targetSounds: const ['u', 'y'])
        ],
        sections: [_section()],
        exercises: [
          _listening(choices: const ['u', 'u', 'y'])
        ],
        audioReferences: [_wordRef()],
        phonemeCoverage: [
          _cov('u'),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [
        ('invalidListeningChoices', 'e-1'),
        ('invalidListeningChoices', 'e-1'),
      ],
    );
    _expectRule(
      label: 'choice outside the declared inventory',
      build: () => _curriculum(
        nodes: [
          _node(targetSounds: const ['u', 'y'])
        ],
        sections: [_section()],
        exercises: [
          _listening(choices: const ['u', 'q'])
        ],
        audioReferences: [_wordRef()],
        phonemeCoverage: [
          _cov('u'),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('invalidListeningChoices', 'e-1')],
    );
  });

  group('invalidSpellingOptions', () {
    _expectRule(
      label: 'fewer than two options',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.spell)],
        sections: [_section()],
        exercises: [
          _spelling(
            options: [SpellingOption(id: 'opt-1', text: 'tout')],
          ),
        ],
        audioReferences: [_wordRef()],
        phonemeCoverage: [_cov('u')],
      ),
      expectedErrors: [('invalidSpellingOptions', 'e-1')],
    );
    _expectRule(
      label: 'duplicate option IDs',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.spell)],
        sections: [_section()],
        exercises: [
          _spelling(
            options: [
              SpellingOption(id: 'opt-1', text: 'tout'),
              SpellingOption(id: 'opt-1', text: 'totu'),
            ],
          ),
        ],
        audioReferences: [_wordRef()],
        phonemeCoverage: [_cov('u')],
      ),
      expectedErrors: [('invalidSpellingOptions', 'e-1')],
    );
    _expectRule(
      label: 'duplicate option texts',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.spell)],
        sections: [_section()],
        exercises: [
          _spelling(
            options: [
              SpellingOption(id: 'opt-1', text: 'tout'),
              SpellingOption(id: 'opt-2', text: 'tout'),
            ],
          ),
        ],
        audioReferences: [_wordRef()],
        phonemeCoverage: [_cov('u')],
      ),
      expectedErrors: [('invalidSpellingOptions', 'e-1')],
    );
    _expectRule(
      label: 'correct option absent from the options',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.spell)],
        sections: [_section()],
        exercises: [
          _spelling(correctOptionId: 'opt-9'),
        ],
        audioReferences: [_wordRef()],
        phonemeCoverage: [_cov('u')],
      ),
      expectedErrors: [('invalidSpellingOptions', 'e-1')],
    );
    _expectRule(
      label: 'two distinct options with a referenced correct option stay clean',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.spell)],
        sections: [_section()],
        exercises: [_spelling()],
        audioReferences: [_wordRef()],
        phonemeCoverage: [_cov('u')],
      ),
      expectedErrors: const [],
    );
  });

  group('unknownWord', () {
    _expectRule(
      label: 'listening word absent from the citation map',
      build: () => _curriculum(
        nodes: [_node()],
        sections: [_section()],
        exercises: [_listening(wordId: 'ghost')],
        audioReferences: [_wordRef(spokenText: 'ghost')],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('unknownWord', 'e-1')],
    );
    _expectRule(
      label: 'spelling word absent from the citation map',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.spell)],
        sections: [_section()],
        exercises: [_spelling(wordId: 'ghost', audioRefId: 'a-ghost')],
        audioReferences: [_wordRef(id: 'a-ghost', spokenText: 'ghost')],
        phonemeCoverage: [_cov('u')],
      ),
      expectedErrors: [('unknownWord', 'e-1')],
    );
  });

  group('citationTargetMismatch', () {
    _expectRule(
      label: 'listening expected sound absent from the curated word phonemes',
      build: () => _curriculum(
        nodes: [
          _node(targetSounds: const ['u', 'y'])
        ],
        sections: [_section()],
        exercises: [
          _listening(expectedSound: 'y', choices: const ['u', 'y'])
        ],
        audioReferences: [_wordRef()],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('citationTargetMismatch', 'e-1')],
    );
    _expectRule(
      label: 'spelling target sound absent from the curated word phonemes',
      build: () => _curriculum(
        nodes: [
          _node(stage: CourseStage.spell, targetSounds: const ['y'])
        ],
        sections: [_section()],
        exercises: [_spelling(targetSound: 'y')],
        audioReferences: [_wordRef()],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('citationTargetMismatch', 'e-1')],
    );
  });

  group('invalidAudioKind', () {
    _expectRule(
      label: 'listening referencing sentence-kind audio',
      build: () => _curriculum(
        nodes: [_node()],
        sections: [_section()],
        exercises: [_listening(audioRefId: 'a-sent')],
        audioReferences: [_sentenceRef(id: 'a-sent', spokenText: 'tout')],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('invalidAudioKind', 'e-1')],
    );
    _expectRule(
      label: 'spelling referencing paragraph-kind audio',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.spell)],
        sections: [_section()],
        exercises: [_spelling(audioRefId: 'a-para')],
        audioReferences: [_paragraphRef(id: 'a-para')],
        phonemeCoverage: [_cov('u')],
      ),
      expectedErrors: [('invalidAudioKind', 'e-1')],
    );
    _expectRule(
      label: 'sentence hunt referencing word-kind audio',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.find)],
        sections: [_section()],
        exercises: [_hunt(audioRefId: 'a-word')],
        sentences: [sentenceFixture(id: 's-x', audioRefId: 'a-word')],
        audioReferences: [
          _wordRef(spokenText: 'tout tu tout.'),
        ],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const [])
        ],
      ),
      expectedErrors: [
        ('invalidAudioKind', 'e-1'),
        ('invalidAudioKind', 's-x'),
      ],
    );
    _expectRule(
      label: 'read-aloud referencing word-kind audio',
      build: () => _curriculum(
        nodes: [_node(kind: CourseNodeKind.articulation, optional: true)],
        sections: [_section()],
        exercises: [_readAloud(audioRefId: 'a-word')],
        audioReferences: [_wordRef()],
        phonemeCoverage: [_cov('u')],
      ),
      expectedErrors: [('invalidAudioKind', 'e-1')],
    );
    _expectRule(
      label: 'sentence declaring word-kind audio',
      build: () => _curriculum(
        sentences: [
          sentenceFixture(
            id: 's-x',
            text: 'tout.',
            audioRefId: 'a-word',
            tokens: [
              SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
              SentenceToken(id: 't-2', text: '.', phonemes: []),
            ],
          ),
        ],
        audioReferences: [
          _wordRef(spokenText: 'tout.'),
        ],
      ),
      expectedErrors: [('invalidAudioKind', 's-x')],
    );
  });

  group('audioTextMismatch', () {
    _expectRule(
      label: 'word reference spoken text disagrees with the word',
      build: () => _curriculum(
        nodes: [_node()],
        sections: [_section()],
        exercises: [_listening(audioRefId: 'a-word')],
        audioReferences: [_wordRef(spokenText: 'totu')],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('audioTextMismatch', 'e-1')],
    );
    _expectRule(
      label: 'sentence reference spoken text disagrees with the sentence text',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.find)],
        sections: [_section()],
        exercises: [_hunt(audioRefId: 'a-sentence')],
        sentences: [sentenceFixture(id: 's-x', audioRefId: 'a-sentence')],
        audioReferences: [
          _sentenceRef(id: 'a-sentence', spokenText: 'tout tu.'),
        ],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const [])
        ],
      ),
      expectedErrors: [('audioTextMismatch', 's-x')],
    );
    _expectRule(
      label: 'read-aloud reference spoken text disagrees with the prompt',
      build: () => _curriculum(
        nodes: [_node(kind: CourseNodeKind.articulation, optional: true)],
        sections: [_section()],
        exercises: [_readAloud(audioRefId: 'a-para')],
        audioReferences: [_paragraphRef(id: 'a-para', spokenText: 'touts')],
        phonemeCoverage: [_cov('u')],
      ),
      expectedErrors: [('audioTextMismatch', 'e-1')],
    );
  });

  group('invalidSentenceTokens', () {
    _expectRule(
      label: 'empty token list',
      build: () => _curriculum(
        sentences: [
          sentenceFixture(
              id: 's-x', text: 'tout.', audioRefId: 'a-sent', tokens: []),
        ],
        audioReferences: [_sentenceRef(id: 'a-sent', spokenText: 'tout.')],
      ),
      expectedErrors: [('invalidSentenceTokens', 's-x')],
    );
    _expectRule(
      label: 'duplicate token IDs',
      build: () => _curriculum(
        sentences: [
          sentenceFixture(
            id: 's-x',
            text: 'tout tout.',
            audioRefId: 'a-sent',
            tokens: [
              SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
              SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
              SentenceToken(id: 't-2', text: '.', phonemes: []),
            ],
          ),
        ],
        audioReferences: [_sentenceRef(id: 'a-sent', spokenText: 'tout tout.')],
      ),
      expectedErrors: [('invalidSentenceTokens', 's-x')],
    );
    _expectRule(
      label: 'repeated phoneme labels within one token',
      build: () => _curriculum(
        sentences: [
          sentenceFixture(
            id: 's-x',
            text: 'tout.',
            audioRefId: 'a-sent',
            tokens: [
              SentenceToken(id: 't-1', text: 'tout', phonemes: ['u', 'u']),
              SentenceToken(id: 't-2', text: '.', phonemes: []),
            ],
          ),
        ],
        audioReferences: [_sentenceRef(id: 'a-sent', spokenText: 'tout.')],
      ),
      expectedErrors: [('invalidSentenceTokens', 's-x')],
    );
    _expectRule(
      label: 'uncovered text between ordered tokens',
      build: () => _curriculum(
        sentences: [
          sentenceFixture(
            id: 's-x',
            text: 'tout x tout.',
            audioRefId: 'a-sent',
            tokens: [
              SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
              SentenceToken(id: 't-2', text: 'tout', phonemes: ['t', 'u']),
              SentenceToken(id: 't-3', text: '.', phonemes: []),
            ],
          ),
        ],
        audioReferences: [
          _sentenceRef(id: 'a-sent', spokenText: 'tout x tout.')
        ],
      ),
      expectedErrors: [('invalidSentenceTokens', 's-x')],
    );
    _expectRule(
      label: 'token text that never appears in the sentence text',
      build: () => _curriculum(
        sentences: [
          sentenceFixture(
            id: 's-x',
            text: 'tout tout.',
            audioRefId: 'a-sent',
            tokens: [
              SentenceToken(id: 't-1', text: 'touttt', phonemes: ['t', 'u']),
              SentenceToken(id: 't-2', text: '.', phonemes: []),
            ],
          ),
        ],
        audioReferences: [_sentenceRef(id: 'a-sent', spokenText: 'tout tout.')],
      ),
      expectedErrors: [('invalidSentenceTokens', 's-x')],
    );
    test('whitespace gaps alone are acceptable between tokens', () {
      final report = _v(
        _curriculum(
          sentences: [
            sentenceFixture(
              text: 'tout  tu tout.',
              audioRefId: 'a-sent',
              tokens: [
                SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
                SentenceToken(id: 't-2', text: 'tu', phonemes: ['t', 'y']),
                SentenceToken(id: 't-3', text: 'tout', phonemes: ['t', 'u']),
                SentenceToken(id: 't-4', text: '.', phonemes: []),
              ],
            ),
          ],
          audioReferences: [
            _sentenceRef(id: 'a-sent', spokenText: 'tout  tu tout.'),
          ],
        ),
      );
      expect(_errors(report), isEmpty, reason: 'whitespace gaps only');
    });
    test('an isolated valid punctuation token is acceptable', () {
      final report = _v(
        _curriculum(
          sentences: [
            sentenceFixture(
              text: '...',
              audioRefId: 'a-sent',
              tokens: [
                SentenceToken(id: 't-1', text: '...', phonemes: []),
              ],
            ),
          ],
          audioReferences: [
            _sentenceRef(id: 'a-sent', spokenText: '...'),
          ],
        ),
      );
      expect(_errors(report), isEmpty, reason: 'punctuation token');
    });
    test('the canonical sentence keeps two matched tout occurrences', () {
      final report = _v(
        _curriculum(
          nodes: [_node(stage: CourseStage.find)],
          sections: [_section()],
          exercises: [_hunt()],
          sentences: [sentenceFixture(id: 's-x', audioRefId: 'a-sentence')],
          audioReferences: [_sentenceRef(id: 'a-sentence')],
          phonemeCoverage: [
            _cov('u',
                status: ContentStatus.planned, practiceExerciseIds: const [])
          ],
        ),
      );
      expect(
        _errors(report),
        isEmpty,
        reason: 'two distinct tout tokens both match target u',
      );
    });
    test('a 100000-token stream stays valid with no recursion depth limit', () {
      const depth = 100000;
      final text = List.filled(depth, 'tu').join(' ');
      final report = _v(
        _curriculum(
          sentences: [
            sentenceFixture(
              id: 'long',
              text: text,
              audioRefId: 'a-sent',
              tokens: [
                for (var i = 0; i < depth; i++)
                  SentenceToken(id: 't$i', text: 'tu', phonemes: ['t', 'y']),
              ],
            ),
          ],
          audioReferences: [_sentenceRef(id: 'a-sent', spokenText: text)],
        ),
      );
      expect(
        _errors(report),
        isEmpty,
        reason: 'exact long coverage is valid and iterative',
      );
    });
    test('a malformed 100000-token stream reports one issue without exceptions',
        () {
      const depth = 100000;
      final text = List.filled(depth, 'tu').join(' ');
      final report = _v(
        _curriculum(
          sentences: [
            sentenceFixture(
              id: 'long',
              text: text,
              audioRefId: 'a-sent',
              tokens: [
                for (var i = 0; i < depth - 1; i++)
                  SentenceToken(id: 't$i', text: 'tu', phonemes: ['t', 'y']),
                SentenceToken(id: 't-last', text: 'tz', phonemes: ['t', 's']),
              ],
            ),
          ],
          audioReferences: [_sentenceRef(id: 'a-sent', spokenText: text)],
        ),
      );
      expect(
        _errors(report),
        [('invalidSentenceTokens', 'long')],
        reason: 'deep failure unwinds iteratively',
      );
    });
    test('a token carrying its leading whitespace is preserved verbatim', () {
      final report = _v(
        _curriculum(
          sentences: [
            sentenceFixture(
              id: 's-x',
              text: 'tout tu',
              audioRefId: 'a-sent',
              tokens: [
                SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
                SentenceToken(id: 't-2', text: ' tu', phonemes: ['t', 'y']),
              ],
            ),
          ],
          audioReferences: [_sentenceRef(id: 'a-sent', spokenText: 'tout tu')],
        ),
      );
      expect(
        _errors(report),
        isEmpty,
        reason: 'token text is matched exactly; no gap normalization',
      );
    });
    test('whitespace-only gaps stay acceptable around verbatim tokens', () {
      final report = _v(
        _curriculum(
          sentences: [
            sentenceFixture(
              id: 's-x',
              text: ' tout  tu.',
              audioRefId: 'a-sent',
              tokens: [
                SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
                SentenceToken(id: 't-2', text: 'tu', phonemes: ['t', 'y']),
                SentenceToken(id: 't-3', text: '.', phonemes: []),
              ],
            ),
          ],
          audioReferences: [
            _sentenceRef(id: 'a-sent', spokenText: ' tout  tu.')
          ],
        ),
      );
      expect(
        _errors(report),
        isEmpty,
        reason: 'whitespace gaps only; nonblank token text exact',
      );
    });
    test('blank phoneme labels are not contextual annotations', () {
      final report = _v(
        _curriculum(
          sentences: [
            sentenceFixture(
              id: 's-x',
              text: 'tout.',
              audioRefId: 'a-sent',
              tokens: [
                SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', ' ']),
                SentenceToken(id: 't-2', text: '.', phonemes: []),
              ],
            ),
          ],
          audioReferences: [_sentenceRef(id: 'a-sent', spokenText: 'tout.')],
        ),
      );
      expect(
        _errors(report),
        [('invalidSentenceTokens', 's-x')],
        reason: 'empty annotation lists stay valid; blank labels do not',
      );
    });
    test(
        'non-inventory consonants and empty punctuation annotations stay valid',
        () {
      final report = _v(
        _curriculum(
          sentences: [
            sentenceFixture(
              id: 's-x',
              text: 'tout.',
              audioRefId: 'a-sent',
              tokens: [
                SentenceToken(
                    id: 't-1', text: 'tout', phonemes: ['t', 'u', 'k']),
                SentenceToken(id: 't-2', text: '.', phonemes: []),
              ],
            ),
          ],
          audioReferences: [_sentenceRef(id: 'a-sent', spokenText: 'tout.')],
        ),
      );
      expect(
        _errors(report),
        isEmpty,
        reason: 'contextual annotations are never constrained to the '
            'teaching inventory, and no pronunciation is inferred',
      );
    });
  });

  group('invalidSentenceTargets', () {
    _expectRule(
      label: 'hunt with zero matching target tokens',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.find)],
        sections: [_section()],
        exercises: [_hunt(audioRefId: 'a-sent')],
        sentences: [
          sentenceFixture(
            id: 's-x',
            text: 'tu tu.',
            audioRefId: 'a-sent',
            tokens: [
              SentenceToken(id: 't-1', text: 'tu', phonemes: ['t', 'y']),
              SentenceToken(id: 't-2', text: 'tu', phonemes: ['t', 'y']),
              SentenceToken(id: 't-3', text: '.', phonemes: []),
            ],
          ),
        ],
        audioReferences: [
          _sentenceRef(id: 'a-sent', spokenText: 'tu tu.'),
        ],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const [])
        ],
      ),
      expectedErrors: [('invalidSentenceTargets', 'e-1')],
    );
    _expectRule(
      label: 'punctuation alone is not a word distractor',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.find)],
        sections: [_section()],
        exercises: [_hunt(audioRefId: 'a-sent')],
        sentences: [
          sentenceFixture(
            id: 's-x',
            text: 'tout tout.',
            audioRefId: 'a-sent',
            tokens: [
              SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
              SentenceToken(id: 't-2', text: 'tout', phonemes: ['t', 'u']),
              SentenceToken(id: 't-3', text: '.', phonemes: []),
            ],
          ),
        ],
        audioReferences: [
          _sentenceRef(id: 'a-sent', spokenText: 'tout tout.'),
        ],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const [])
        ],
      ),
      expectedErrors: [('invalidSentenceTargets', 'e-1')],
    );
    _expectRule(
      label: 'punctuation-only sentence lacks target and distractor',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.find)],
        sections: [_section()],
        exercises: [_hunt(audioRefId: 'a-sent')],
        sentences: [
          sentenceFixture(
            id: 's-x',
            text: '...',
            audioRefId: 'a-sent',
            tokens: [
              SentenceToken(id: 't-1', text: '...', phonemes: []),
            ],
          ),
        ],
        audioReferences: [
          _sentenceRef(id: 'a-sent', spokenText: '...'),
        ],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const [])
        ],
      ),
      expectedErrors: [
        ('invalidSentenceTargets', 'e-1'),
        ('invalidSentenceTargets', 'e-1'),
      ],
    );
    test(
        'context annotations drive the hunt even when they differ from citations',
        () {
      // The annotations deliberately disagree with the curated citation
      // phonemes: tout carries y and tu carries u. Acceptance follows the
      // reviewed contextual annotations only, never a citation guess.
      final report = _v(
        _curriculum(
          nodes: [
            _node(stage: CourseStage.find, targetSounds: const ['y'])
          ],
          sections: [_section()],
          exercises: [
            _hunt(audioRefId: 'a-sent', targetSound: 'y'),
          ],
          sentences: [
            sentenceFixture(
              id: 's-x',
              text: 'tout tu.',
              audioRefId: 'a-sent',
              tokens: [
                SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'y']),
                SentenceToken(id: 't-2', text: 'tu', phonemes: ['t', 'u']),
                SentenceToken(id: 't-3', text: '.', phonemes: []),
              ],
            ),
          ],
          audioReferences: [
            _sentenceRef(id: 'a-sent', spokenText: 'tout tu.'),
          ],
          phonemeCoverage: [
            _cov('u',
                status: ContentStatus.planned, practiceExerciseIds: const []),
            _cov('y',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
      );
      expect(
        _errors(report),
        isEmpty,
        reason: 'no citation/unknown-word inference for contextual hunts',
      );
    });
    _expectRule(
      label: 'hunt sentence reference absent',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.find)],
        sections: [_section()],
        exercises: [_hunt(audioRefId: 'a-sent', sentenceId: 'ghost-s')],
        sentences: [
          sentenceFixture(
              id: 'other',
              text: 'tout',
              audioRefId: 'a-sent',
              tokens: [
                SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
              ]),
        ],
        audioReferences: [
          _sentenceRef(id: 'a-sent', spokenText: 'tout'),
        ],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const [])
        ],
      ),
      expectedErrors: [('missingReference', 'e-1')],
    );
    _expectRule(
      label: 'hunt sentence reference ambiguous',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.find)],
        sections: [_section()],
        exercises: [_hunt(audioRefId: 'a-sent', sentenceId: 's-amb')],
        sentences: [
          sentenceFixture(
            id: 's-amb',
            text: 'tout',
            audioRefId: 'a-sent',
            tokens: [
              SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
            ],
          ),
          sentenceFixture(
            id: 's-amb',
            text: 'tout',
            audioRefId: 'a-sent',
            tokens: [
              SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
            ],
          ),
        ],
        audioReferences: [_sentenceRef(id: 'a-sent', spokenText: 'tout')],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const [])
        ],
      ),
      expectedErrors: [
        ('duplicateId', 's-amb'),
        ('missingReference', 'e-1'),
      ],
    );
  });

  group('sentenceAudioMismatch', () {
    _expectRule(
      label: 'hunt audio reference differs from the sentence audio reference',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.find)],
        sections: [_section()],
        exercises: [_hunt(audioRefId: 'a-1')],
        sentences: [
          sentenceFixture(
            id: 's-x',
            text: 'tout tu.',
            audioRefId: 'a-2',
            tokens: [
              SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
              SentenceToken(id: 't-2', text: 'tu', phonemes: ['t', 'y']),
              SentenceToken(id: 't-3', text: '.', phonemes: []),
            ],
          ),
        ],
        audioReferences: [
          _sentenceRef(id: 'a-1', spokenText: 'tout tu.'),
          _sentenceRef(id: 'a-2', spokenText: 'tout tu.'),
        ],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const [])
        ],
      ),
      expectedErrors: [('sentenceAudioMismatch', 'e-1')],
    );
    _expectRule(
      label:
          'missing hunt audio reference still reports the mismatch independently',
      build: () => _curriculum(
        nodes: [_node(stage: CourseStage.find)],
        sections: [_section()],
        exercises: [_hunt(audioRefId: 'ghost-a')],
        sentences: [
          sentenceFixture(
            id: 's-x',
            text: 'tout tu.',
            audioRefId: 'a-sent',
            tokens: [
              SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
              SentenceToken(id: 't-2', text: 'tu', phonemes: ['t', 'y']),
              SentenceToken(id: 't-3', text: '.', phonemes: []),
            ],
          ),
        ],
        audioReferences: [
          _sentenceRef(id: 'a-sent', spokenText: 'tout tu.'),
        ],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const [])
        ],
      ),
      expectedErrors: [
        ('missingReference', 'e-1'),
        ('sentenceAudioMismatch', 'e-1'),
      ],
    );
  });

  group('invalidCoverage', () {
    _expectRule(
      label: 'duplicate coverage sound labels',
      build: () => _curriculum(
        nodes: [_node()],
        sections: [_section()],
        exercises: [_listening()],
        audioReferences: [_wordRef()],
        phonemeCoverage: [
          _cov('u'),
          _cov('u'),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('invalidCoverage', 'u')],
    );
    _expectRule(
      label: 'authored coverage with no practice exercises',
      build: () => _curriculum(
        phonemeCoverage: [
          _cov('u', practiceExerciseIds: const []),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('invalidCoverage', 'u')],
    );
    _expectRule(
      label: 'planned coverage listing exercises',
      build: () => _curriculum(
        nodes: [
          _node(targetSounds: const ['u', 'y'])
        ],
        sections: [
          _section(exerciseIds: const ['e-u', 'e-y'], requiredItemCount: 2),
        ],
        exercises: [
          _listening(id: 'e-u'),
          _listening(
            id: 'e-y',
            wordId: 'tu',
            expectedSound: 'y',
            audioRefId: 'a-y',
          ),
        ],
        audioReferences: [
          _wordRef(),
          _wordRef(id: 'a-y', spokenText: 'tu'),
        ],
        phonemeCoverage: [
          _cov('u', practiceExerciseIds: const ['e-u']),
          _cov('y',
              status: ContentStatus.planned,
              practiceExerciseIds: const ['e-y']),
        ],
      ),
      expectedErrors: [('invalidCoverage', 'y')],
    );
    _expectRule(
      label: 'duplicate practice exercise references in one coverage',
      build: () => _curriculum(
        nodes: [_node()],
        sections: [_section()],
        exercises: [_listening()],
        audioReferences: [_wordRef()],
        phonemeCoverage: [
          _cov('u', practiceExerciseIds: const ['e-1', 'e-1']),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('invalidCoverage', 'u')],
    );
    _expectRule(
      label: 'coverage referencing an absent exercise',
      build: () => _curriculum(
        phonemeCoverage: [
          _cov('u', practiceExerciseIds: const ['ghost-e']),
        ],
      ),
      expectedErrors: [('invalidCoverage', 'u')],
    );
    _expectRule(
      label: 'coverage referencing a non-practice exercise',
      build: () => _curriculum(
        nodes: [
          _node(
            id: 'n-a',
            kind: CourseNodeKind.assessment,
            stage: CourseStage.assess,
          ),
        ],
        sections: [_section(nodeId: 'n-a')],
        exercises: [
          _listening(
            purpose: ContentPurpose.assessment,
            wordId: 'new-u',
            audioRefId: 'a-new',
          ),
        ],
        audioReferences: [_wordRef(id: 'a-new', spokenText: 'new-u')],
        phonemeCoverage: [
          _cov('u', practiceExerciseIds: const ['e-1']),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('invalidCoverage', 'u')],
    );
    _expectRule(
      label: 'coverage referencing an exercise that does not teach the sound',
      build: () => _curriculum(
        nodes: [
          _node(targetSounds: const ['u', 'y'])
        ],
        sections: [_section()],
        exercises: [
          _listening(wordId: 'tu', expectedSound: 'y', audioRefId: 'a-y'),
        ],
        audioReferences: [_wordRef(id: 'a-y', spokenText: 'tu')],
        phonemeCoverage: [
          _cov('u'),
          _cov('y', practiceExerciseIds: const ['e-1']),
        ],
      ),
      expectedErrors: [('invalidCoverage', 'u')],
    );
  });

  group('exposedAssessmentWord', () {
    _expectRule(
      label:
          'assessment reusing a practice word despite omitted caller exposure',
      build: () => _curriculum(
        nodes: [
          _node(id: 'n-p', sectionIds: const ['s-p']),
          _node(
            id: 'n-a',
            kind: CourseNodeKind.assessment,
            stage: CourseStage.assess,
            sectionIds: const ['s-a'],
          ),
        ],
        sections: [
          _section(id: 's-p', nodeId: 'n-p', exerciseIds: const ['e-p']),
          _section(id: 's-a', nodeId: 'n-a', exerciseIds: const ['e-a']),
        ],
        exercises: [
          _listening(id: 'e-p', sectionId: 's-p', audioRefId: 'a-p'),
          _listening(
            id: 'e-a',
            sectionId: 's-a',
            purpose: ContentPurpose.assessment,
            audioRefId: 'a-a',
          ),
        ],
        audioReferences: [
          _wordRef(id: 'a-p', spokenText: 'tout'),
          _wordRef(id: 'a-a', spokenText: 'tout'),
        ],
        phonemeCoverage: [
          _cov('u', practiceExerciseIds: const ['e-p']),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [('exposedAssessmentWord', 'e-a')],
    );
    _expectRule(
      label: 'assessment reusing a caller-supplied exposed word',
      build: () => _curriculum(
        nodes: [
          _node(
            id: 'n-a',
            kind: CourseNodeKind.assessment,
            stage: CourseStage.assess,
          ),
        ],
        sections: [_section(nodeId: 'n-a')],
        exercises: [
          _listening(
            purpose: ContentPurpose.assessment,
            wordId: 'new-u',
            audioRefId: 'a-new',
          ),
        ],
        audioReferences: [_wordRef(id: 'a-new', spokenText: 'new-u')],
        phonemeCoverage: [
          _cov('u',
              status: ContentStatus.planned, practiceExerciseIds: const []),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      exposedWordIds: const {'new-u'},
      expectedErrors: [('exposedAssessmentWord', 'e-1')],
    );
    _expectRule(
      label: 'assessment spelling reusing a practice word',
      build: () => _curriculum(
        nodes: [
          _node(id: 'n-p', stage: CourseStage.spell, sectionIds: const ['s-p']),
          _node(
            id: 'n-a',
            kind: CourseNodeKind.assessment,
            stage: CourseStage.assess,
            sectionIds: const ['s-a'],
          ),
        ],
        sections: [
          _section(id: 's-p', nodeId: 'n-p', exerciseIds: const ['e-p']),
          _section(id: 's-a', nodeId: 'n-a', exerciseIds: const ['e-a']),
        ],
        exercises: [
          _spelling(id: 'e-p', sectionId: 's-p', audioRefId: 'a-p'),
          _spelling(
            id: 'e-a',
            sectionId: 's-a',
            purpose: ContentPurpose.assessment,
            audioRefId: 'a-a',
          ),
        ],
        audioReferences: [
          _wordRef(id: 'a-p', spokenText: 'tout'),
          _wordRef(id: 'a-a', spokenText: 'tout'),
        ],
        phonemeCoverage: [
          _cov('u', practiceExerciseIds: const ['e-p']),
        ],
      ),
      expectedErrors: [('exposedAssessmentWord', 'e-a')],
    );
  });

  group('exposedAssessmentAudio', () {
    _expectRule(
      label: 'assessment reusing a practice audio reference',
      build: () => _curriculum(
        nodes: [
          _node(id: 'n-p', sectionIds: const ['s-p']),
          _node(
            id: 'n-a',
            kind: CourseNodeKind.assessment,
            stage: CourseStage.assess,
            sectionIds: const ['s-a'],
          ),
        ],
        sections: [
          _section(id: 's-p', nodeId: 'n-p', exerciseIds: const ['e-p']),
          _section(id: 's-a', nodeId: 'n-a', exerciseIds: const ['e-a']),
        ],
        exercises: [
          _listening(id: 'e-p', sectionId: 's-p', audioRefId: 'a-shared'),
          _listening(
            id: 'e-a',
            sectionId: 's-a',
            purpose: ContentPurpose.assessment,
            wordId: 'new-u',
            audioRefId: 'a-shared',
          ),
        ],
        audioReferences: [
          _wordRef(id: 'a-shared', spokenText: 'tout'),
        ],
        phonemeCoverage: [
          _cov('u', practiceExerciseIds: const ['e-p']),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      expectedErrors: [
        ('audioTextMismatch', 'e-a'),
        ('exposedAssessmentAudio', 'e-a'),
      ],
    );
  });

  group('authored record order', () {
    test('later exercise ownership cannot precede earlier exercise payloads',
        () {
      CourseCurriculum fixture() => _curriculum(
            nodes: [
              _node(sectionIds: const ['s-1'])
            ],
            sections: [_section()],
            exercises: [
              _listening(id: 'e-1', choices: const ['u']),
              _listening(
                  id: 'e-2', sectionId: 'ghost-section', audioRefId: 'a-2'),
            ],
            audioReferences: [_wordRef(), _wordRef(id: 'a-2')],
            phonemeCoverage: [
              _cov('u', practiceExerciseIds: const ['e-1']),
              _cov('y',
                  status: ContentStatus.planned, practiceExerciseIds: const []),
            ],
          );
      final report = _v(fixture());
      expect(
        [for (final d in report.errors) d.recordId],
        containsAllInOrder(['e-1', 'e-2']),
        reason: 'exercise records keep authored order across ownership and '
            'payload diagnostics',
      );
      final again = _v(fixture());
      expect(
        [for (final d in again.errors) (d.code, d.recordId, d.use)],
        [for (final d in report.errors) (d.code, d.recordId, d.use)],
        reason: 'repeat fingerprint: identical diagnostic sequence',
      );
    });
  });
}
