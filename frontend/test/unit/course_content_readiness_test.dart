import 'package:flutter_test/flutter_test.dart';

import 'package:linguist/src/core/course/course_content_validator.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/course_curriculum.dart';

import '../support/course_curriculum_fixtures.dart';

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
      title: 'Readiness node $id',
      kind: kind,
      stage: stage,
      status: status,
      optional: optional,
      prerequisiteIds: const [],
      sectionIds: sectionIds,
      targetSounds: targetSounds,
    );

CourseSection _section({
  String id = 's-1',
  String nodeId = 'n-1',
  List<String> exerciseIds = const ['e-1'],
  int requiredItemCount = 1,
}) =>
    CourseSection(
      id: id,
      nodeId: nodeId,
      title: 'Readiness section $id',
      explanation: 'Section-end explanation for $id.',
      contentRevision: 1,
      exerciseIds: exerciseIds,
      requiredItemCount: requiredItemCount,
    );

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

SentenceHuntExercise _hunt({
  String id = 'e-1',
  String sectionId = 's-1',
  String audioRefId = 'a-sentence',
  ContentPurpose purpose = ContentPurpose.practice,
  ContentReviewState reviewState = ContentReviewState.existingCurated,
  String sentenceId = 's-1',
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
  String spokenText = 'tout tu.',
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

CourseAudioReference _soundRef({String id = 'a-sound'}) => CourseAudioReference(
      id: id,
      kind: AudioReferenceKind.sound,
      spokenText: 'u',
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

void main() {
  group('plannedNode', () {
    test('planned non-assessment payload slot reports practice readiness', () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(
              id: 'n-planned',
              status: ContentStatus.planned,
              sectionIds: const [],
              targetSounds: const [],
            ),
          ],
        ),
      );
      expect(report.isStructurallyValid, isTrue, reason: 'readiness only');
      expect(
        _readiness(report),
        [('plannedNode', 'n-planned', ContentPurpose.practice)],
      );
    });
    test('planned assessment node reports assessment readiness', () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(
              id: 'n-planned-a',
              kind: CourseNodeKind.assessment,
              stage: CourseStage.assess,
              status: ContentStatus.planned,
              sectionIds: const [],
              targetSounds: const [],
            ),
          ],
        ),
      );
      expect(report.isStructurallyValid, isTrue);
      expect(
        _readiness(report),
        [('plannedNode', 'n-planned-a', ContentPurpose.assessment)],
      );
    });
    test('planned readiness coexists with the plannedPayload error', () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(status: ContentStatus.planned),
          ],
        ),
      );
      expect(
        [for (final d in report.errors) d.code],
        contains('plannedPayload'),
        reason: 'planned node with sections is still structurally invalid',
      );
      expect(
        _readiness(report),
        [('plannedNode', 'n-1', ContentPurpose.practice)],
      );
    });
    test('planned nodes report in authored order with distinct uses', () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(
              id: 'n-first',
              status: ContentStatus.planned,
              sectionIds: const [],
              targetSounds: const [],
            ),
            _node(
              id: 'n-second',
              kind: CourseNodeKind.assessment,
              stage: CourseStage.assess,
              status: ContentStatus.planned,
              sectionIds: const [],
              targetSounds: const [],
            ),
          ],
        ),
      );
      expect(
        _readiness(report),
        [
          ('plannedNode', 'n-first', ContentPurpose.practice),
          ('plannedNode', 'n-second', ContentPurpose.assessment),
        ],
      );
    });
  });

  group('plannedPhoneme', () {
    test('planned discovery coverage reports practice readiness in order', () {
      final report = _v(
        _curriculum(
          nodes: [_node()],
          sections: [_section()],
          exercises: [_listening()],
          audioReferences: [_wordRef()],
          phonemeCoverage: [
            _cov('u'),
            _cov('y',
                status: ContentStatus.planned, practiceExerciseIds: const []),
            _cov('i',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
        audioResources: const {'a-word': AudioResourceStatus.practiceTts},
      );
      expect(report.isStructurallyValid, isTrue, reason: 'readiness only');
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'y', ContentPurpose.practice),
          ('plannedPhoneme', 'i', ContentPurpose.practice),
          ('missingReviewedAudio', 'a-word', ContentPurpose.assessment),
        ],
      );
    });
    test('authored coverage adds no phoneme readiness', () {
      final report = _v(
        _curriculum(
          nodes: [_node()],
          sections: [_section()],
          exercises: [_listening()],
          audioReferences: [_wordRef(spokenText: 'tout')],
          phonemeCoverage: [
            _cov('u'),
            _cov('y',
                status: ContentStatus.planned, practiceExerciseIds: const [])
          ],
        ),
        audioResources: const {'a-word': AudioResourceStatus.reviewedRecording},
      );
      expect(
        _readiness(report),
        [('plannedPhoneme', 'y', ContentPurpose.practice)],
      );
    });
  });

  group('pendingContentReview', () {
    test('pending practice exercise keeps its practice use', () {
      final report = _v(
        _curriculum(
          nodes: [_node()],
          sections: [_section()],
          exercises: [_listening(reviewState: ContentReviewState.pending)],
          audioReferences: [_wordRef()],
          phonemeCoverage: [
            _cov('u'),
            _cov('y',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
        audioResources: const {'a-word': AudioResourceStatus.practiceTts},
      );
      expect(report.isStructurallyValid, isTrue);
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'y', ContentPurpose.practice),
          ('pendingContentReview', 'e-1', ContentPurpose.practice),
          ('missingReviewedAudio', 'a-word', ContentPurpose.assessment),
        ],
      );
    });
    test('pending assessment exercise also stays unreviewed assessment content',
        () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(
              kind: CourseNodeKind.assessment,
              stage: CourseStage.assess,
            ),
          ],
          sections: [_section()],
          exercises: [
            _listening(
              purpose: ContentPurpose.assessment,
              wordId: 'new-u',
              audioRefId: 'a-new',
              reviewState: ContentReviewState.pending,
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
        audioResources: const {'a-new': AudioResourceStatus.reviewedRecording},
      );
      expect(report.isStructurallyValid, isTrue);
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'u', ContentPurpose.practice),
          ('plannedPhoneme', 'y', ContentPurpose.practice),
          ('pendingContentReview', 'e-1', ContentPurpose.assessment),
          ('unreviewedAssessmentContent', 'e-1', ContentPurpose.assessment),
        ],
      );
    });
    test('a referenced pending sentence flags the exercise with its purpose',
        () {
      final report = _v(
        _curriculum(
          nodes: [_node(stage: CourseStage.find)],
          sections: [_section()],
          exercises: [_hunt(audioRefId: 'a-sentence')],
          sentences: [
            sentenceFixture(
              id: 's-1',
              text: 'tout tu.',
              audioRefId: 'a-sentence',
              tokens: [
                SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
                SentenceToken(id: 't-2', text: 'tu', phonemes: ['t', 'y']),
                SentenceToken(id: 't-3', text: '.', phonemes: []),
              ],
              reviewState: ContentReviewState.pending,
            ),
          ],
          audioReferences: [_sentenceRef(id: 'a-sentence')],
          phonemeCoverage: [
            _cov('u',
                status: ContentStatus.planned, practiceExerciseIds: const []),
            _cov('y',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
        audioResources: const {
          'a-sentence': AudioResourceStatus.practiceTts,
        },
      );
      expect(report.isStructurallyValid, isTrue);
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'u', ContentPurpose.practice),
          ('plannedPhoneme', 'y', ContentPurpose.practice),
          ('pendingContentReview', 'e-1', ContentPurpose.practice),
        ],
      );
    });
    test('an existingCurated sentence does not flag pending review', () {
      final report = _v(
        _curriculum(
          nodes: [_node(stage: CourseStage.find)],
          sections: [_section()],
          exercises: [_hunt(audioRefId: 'a-sentence')],
          sentences: [
            sentenceFixture(
              id: 's-1',
              text: 'tout tu.',
              audioRefId: 'a-sentence',
              tokens: [
                SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
                SentenceToken(id: 't-2', text: 'tu', phonemes: ['t', 'y']),
              ],
            ),
          ],
          audioReferences: [_sentenceRef(id: 'a-sentence')],
          phonemeCoverage: [
            _cov('u',
                status: ContentStatus.planned, practiceExerciseIds: const []),
            _cov('y',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
        audioResources: const {
          'a-sentence': AudioResourceStatus.practiceTts,
        },
      );
      expect(
        _readiness(report).map((r) => r.$1),
        isNot(contains('pendingContentReview')),
      );
    });
  });

  group('unreviewedAssessmentContent', () {
    test('existingCurated assessment content is never ready by recording alone',
        () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(
              kind: CourseNodeKind.assessment,
              stage: CourseStage.assess,
            ),
          ],
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
        audioResources: const {'a-new': AudioResourceStatus.reviewedRecording},
      );
      expect(report.isStructurallyValid, isTrue);
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'u', ContentPurpose.practice),
          ('plannedPhoneme', 'y', ContentPurpose.practice),
          ('unreviewedAssessmentContent', 'e-1', ContentPurpose.assessment),
        ],
        reason: 'reviewed recording never repairs an unreviewed key',
      );
    });
    test('an assessed sentence existingCurated flags the assessed exercise',
        () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(
              kind: CourseNodeKind.assessment,
              stage: CourseStage.assess,
            ),
          ],
          sections: [_section()],
          exercises: [
            _hunt(
              purpose: ContentPurpose.assessment,
              audioRefId: 'a-sentence',
              reviewState: ContentReviewState.reviewed,
            ),
          ],
          sentences: [
            sentenceFixture(
              id: 's-1',
              text: 'tout tu.',
              audioRefId: 'a-sentence',
              tokens: [
                SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
                SentenceToken(id: 't-2', text: 'tu', phonemes: ['t', 'y']),
                SentenceToken(id: 't-3', text: '.', phonemes: []),
              ],
            ),
            // existingCurated default: assessed answer key not reviewed.
          ],
          audioReferences: [_sentenceRef(id: 'a-sentence')],
          phonemeCoverage: [
            _cov('u',
                status: ContentStatus.planned, practiceExerciseIds: const []),
            _cov('y',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
        audioResources: const {
          'a-sentence': AudioResourceStatus.reviewedRecording,
        },
      );
      expect(report.isStructurallyValid, isTrue);
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'u', ContentPurpose.practice),
          ('plannedPhoneme', 'y', ContentPurpose.practice),
          ('unreviewedAssessmentContent', 'e-1', ContentPurpose.assessment),
        ],
      );
    });
    test('reviewed assessed content with a reviewed recording is ready', () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(
              kind: CourseNodeKind.assessment,
              stage: CourseStage.assess,
            ),
          ],
          sections: [_section()],
          exercises: [
            _listening(
              purpose: ContentPurpose.assessment,
              wordId: 'new-u',
              audioRefId: 'a-new',
              reviewState: ContentReviewState.reviewed,
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
        audioResources: const {'a-new': AudioResourceStatus.reviewedRecording},
      );
      expect(report.isStructurallyValid, isTrue);
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'u', ContentPurpose.practice),
          ('plannedPhoneme', 'y', ContentPurpose.practice),
        ],
        reason: 'reviewed key + recording',
      );
    });
  });

  group('missingPracticeAudio', () {
    test('absent practice resource declaration reports practice readiness', () {
      final report = _v(
        _curriculum(
          nodes: [_node()],
          sections: [_section()],
          exercises: [_listening()],
          audioReferences: [_wordRef()],
          phonemeCoverage: [
            _cov('u'),
            _cov('y',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
      );
      expect(report.isStructurallyValid, isTrue);
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'y', ContentPurpose.practice),
          ('missingPracticeAudio', 'e-1', ContentPurpose.practice),
          ('missingReviewedAudio', 'a-word', ContentPurpose.assessment),
        ],
      );
    });
    test('status missing reports practice readiness', () {
      final report = _v(
        _curriculum(
          nodes: [_node()],
          sections: [_section()],
          exercises: [_listening()],
          audioReferences: [_wordRef()],
          phonemeCoverage: [_cov('u')],
        ),
        audioResources: const {'a-word': AudioResourceStatus.missing},
      );
      expect(
        _readiness(report),
        [
          ('missingPracticeAudio', 'e-1', ContentPurpose.practice),
          ('missingReviewedAudio', 'a-word', ContentPurpose.assessment),
        ],
      );
    });
    test('labeled practice TTS is usable and adds no practice audio issue', () {
      final report = _v(
        _curriculum(
          nodes: [_node()],
          sections: [_section()],
          exercises: [_listening()],
          audioReferences: [_wordRef()],
          phonemeCoverage: [_cov('u')],
        ),
        audioResources: const {'a-word': AudioResourceStatus.practiceTts},
      );
      expect(
        _readiness(report).map((r) => r.$1),
        isNot(contains('missingPracticeAudio')),
        reason: 'practice TTS is available',
      );
      expect(
        _readiness(report),
        [('missingReviewedAudio', 'a-word', ContentPurpose.assessment)],
        reason: 'a word reference without a reviewed recording stays an '
            'assess-use warning',
      );
    });
    test('assessment use never gets a practice audio issue', () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(
              kind: CourseNodeKind.assessment,
              stage: CourseStage.assess,
            ),
          ],
          sections: [_section()],
          exercises: [
            _listening(
              purpose: ContentPurpose.assessment,
              wordId: 'new-u',
              audioRefId: 'a-new',
              reviewState: ContentReviewState.reviewed,
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
      );
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'u', ContentPurpose.practice),
          ('plannedPhoneme', 'y', ContentPurpose.practice),
          ('missingReviewedAudio', 'a-new', ContentPurpose.assessment),
        ],
      );
    });
  });

  group('missingReviewedAudio', () {
    test('any declared word reference without a reviewed recording is flagged',
        () {
      final report = _v(
        _curriculum(
          audioReferences: [_wordRef(id: 'fr-word-lune', spokenText: 'lune')],
        ),
      );
      expect(
        _readiness(report),
        [('missingReviewedAudio', 'fr-word-lune', ContentPurpose.assessment)],
      );
    });
    test('assessed sentence resource without a reviewed recording is flagged',
        () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(
              kind: CourseNodeKind.assessment,
              stage: CourseStage.assess,
            ),
          ],
          sections: [_section()],
          exercises: [
            _hunt(
              purpose: ContentPurpose.assessment,
              audioRefId: 'a-sentence',
              reviewState: ContentReviewState.reviewed,
            ),
          ],
          sentences: [
            sentenceFixture(
              id: 's-1',
              text: 'tout tu.',
              audioRefId: 'a-sentence',
              tokens: [
                SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
                SentenceToken(id: 't-2', text: 'tu', phonemes: ['t', 'y']),
              ],
              reviewState: ContentReviewState.reviewed,
            ),
          ],
          audioReferences: [_sentenceRef(id: 'a-sentence')],
          phonemeCoverage: [
            _cov('u',
                status: ContentStatus.planned, practiceExerciseIds: const []),
            _cov('y',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
        audioResources: const {
          'a-sentence': AudioResourceStatus.practiceTts,
        },
      );
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'u', ContentPurpose.practice),
          ('plannedPhoneme', 'y', ContentPurpose.practice),
          ('missingReviewedAudio', 'a-sentence', ContentPurpose.assessment)
        ],
      );
    });
    test('practice-use sentence resource is not an assessed requirement', () {
      final report = _v(
        _curriculum(
          nodes: [_node(stage: CourseStage.find)],
          sections: [_section()],
          exercises: [_hunt(audioRefId: 'a-sentence')],
          sentences: [
            sentenceFixture(
              id: 's-1',
              text: 'tout tu.',
              audioRefId: 'a-sentence',
              tokens: [
                SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
                SentenceToken(id: 't-2', text: 'tu', phonemes: ['t', 'y']),
              ],
            ),
          ],
          audioReferences: [_sentenceRef(id: 'a-sentence')],
          phonemeCoverage: [
            _cov('u',
                status: ContentStatus.planned, practiceExerciseIds: const []),
            _cov('y',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
        audioResources: const {
          'a-sentence': AudioResourceStatus.practiceTts,
        },
      );
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'u', ContentPurpose.practice),
          ('plannedPhoneme', 'y', ContentPurpose.practice),
        ],
        reason: 'declared practice TTS satisfies practice; not assessed',
      );
    });
    test('unknown resource-map keys never repair a dangling reference', () {
      final report = _v(
        _curriculum(
          nodes: [_node()],
          sections: [_section()],
          exercises: [_listening()],
          audioReferences: [_wordRef()],
          phonemeCoverage: [_cov('u')],
        ),
        audioResources: const {
          'ghost-reference': AudioResourceStatus.reviewedRecording,
        },
      );
      expect(
        _readiness(report),
        [
          ('missingPracticeAudio', 'e-1', ContentPurpose.practice),
          ('missingReviewedAudio', 'a-word', ContentPurpose.assessment),
        ],
      );
    });
    test('sound-kind references are reserved, not word or assessed resources',
        () {
      final report = _v(
        _curriculum(
          audioReferences: [_soundRef(id: 'a-sound')],
        ),
      );
      expect(report.isStructurallyValid, isTrue);
      expect(_readiness(report), isEmpty);
    });
  });

  group('speakingUnassessed', () {
    test('practice read-aloud never implies a validated evaluator', () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(kind: CourseNodeKind.articulation, optional: true),
          ],
          sections: [_section()],
          exercises: [_readAloud()],
          audioReferences: [_paragraphRef()],
          phonemeCoverage: [
            _cov('u',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
        audioResources: const {'a-paragraph': AudioResourceStatus.practiceTts},
      );
      expect(report.isStructurallyValid, isTrue);
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'u', ContentPurpose.practice),
          ('speakingUnassessed', 'e-1', ContentPurpose.assessment),
        ],
      );
    });
    test(
        'assessment read-aloud stays unassessed and its paragraph resource is assessed',
        () {
      final report = _v(
        _curriculum(
          nodes: [
            _node(
              kind: CourseNodeKind.assessment,
              stage: CourseStage.assess,
            ),
          ],
          sections: [_section()],
          exercises: [
            _readAloud(
              purpose: ContentPurpose.assessment,
              reviewState: ContentReviewState.reviewed,
              audioRefId: 'a-para-a',
            ),
          ],
          audioReferences: [_paragraphRef(id: 'a-para-a')],
          phonemeCoverage: [
            _cov('u',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
      );
      expect(report.isStructurallyValid, isTrue);
      expect(
        _readiness(report),
        [
          ('plannedPhoneme', 'u', ContentPurpose.practice),
          ('speakingUnassessed', 'e-1', ContentPurpose.assessment),
          ('missingReviewedAudio', 'a-para-a', ContentPurpose.assessment),
        ],
      );
    });
  });

  group('unexposed synthetic assessment word', () {
    test('new-u with reviewed key and recording has no assessment issues', () {
      final report = _v(
        _curriculum(
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
              wordId: 'new-u',
              audioRefId: 'a-a',
              reviewState: ContentReviewState.reviewed,
            ),
          ],
          audioReferences: [
            _wordRef(id: 'a-p', spokenText: 'tout'),
            _wordRef(id: 'a-a', spokenText: 'new-u'),
          ],
          phonemeCoverage: [
            _cov('u', practiceExerciseIds: const ['e-p']),
            _cov('y',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
        audioResources: const {
          'a-p': AudioResourceStatus.reviewedRecording,
          'a-a': AudioResourceStatus.reviewedRecording,
        },
      );
      expect(report.errors, isEmpty);
      expect(
        _readiness(report),
        [('plannedPhoneme', 'y', ContentPurpose.practice)],
        reason: 'only the planned y phoneme keeps the baseline from ready',
      );

      final exposed = _v(
        _curriculum(
          nodes: [
            _node(
                id: 'n-a',
                kind: CourseNodeKind.assessment,
                stage: CourseStage.assess),
          ],
          sections: [_section(nodeId: 'n-a')],
          exercises: [
            _listening(
              purpose: ContentPurpose.assessment,
              wordId: 'new-u',
              audioRefId: 'a-a',
              reviewState: ContentReviewState.reviewed,
            ),
          ],
          audioReferences: [_wordRef(id: 'a-a', spokenText: 'new-u')],
          phonemeCoverage: [
            _cov('u',
                status: ContentStatus.planned, practiceExerciseIds: const []),
            _cov('y',
                status: ContentStatus.planned, practiceExerciseIds: const []),
          ],
        ),
        exposedWordIds: const {'new-u'},
        audioResources: const {'a-a': AudioResourceStatus.reviewedRecording},
      );
      expect(
        [for (final d in exposed.errors) d.code],
        ['exposedAssessmentWord'],
        reason: 'adding it to exposure is an error',
      );
    });
  });

  test('readiness matrix reports in contract phase order', () {
    final report = _v(
      _curriculum(
        nodes: [
          _node(
            id: 'n-planned',
            status: ContentStatus.planned,
            sectionIds: const [],
            targetSounds: const [],
          ),
          _node(
            id: 'n-planned-a',
            kind: CourseNodeKind.assessment,
            stage: CourseStage.assess,
            status: ContentStatus.planned,
            sectionIds: const [],
            targetSounds: const [],
          ),
          _node(id: 'n-lesson', sectionIds: const ['s-1']),
          _node(
            id: 'n-find',
            stage: CourseStage.find,
            sectionIds: const ['s-2'],
          ),
          _node(
            id: 'n-artic',
            kind: CourseNodeKind.articulation,
            optional: true,
            sectionIds: const ['s-3'],
          ),
          _node(
            id: 'n-assess',
            kind: CourseNodeKind.assessment,
            stage: CourseStage.assess,
            sectionIds: const ['s-4'],
          ),
        ],
        sections: [
          _section(id: 's-1', nodeId: 'n-lesson', exerciseIds: const ['e-p']),
          _section(id: 's-2', nodeId: 'n-find', exerciseIds: const ['e-h']),
          _section(id: 's-3', nodeId: 'n-artic', exerciseIds: const ['e-r']),
          _section(id: 's-4', nodeId: 'n-assess', exerciseIds: const ['e-a']),
        ],
        exercises: [
          _listening(
            id: 'e-p',
            sectionId: 's-1',
            audioRefId: 'ref-p',
            reviewState: ContentReviewState.pending,
          ),
          _hunt(
            id: 'e-h',
            sectionId: 's-2',
            audioRefId: 'ref-h',
            sentenceId: 's-h',
          ),
          _readAloud(
            id: 'e-r',
            sectionId: 's-3',
            audioRefId: 'ref-r',
            reviewState: ContentReviewState.reviewed,
          ),
          _listening(
            id: 'e-a',
            sectionId: 's-4',
            purpose: ContentPurpose.assessment,
            wordId: 'new-u',
            audioRefId: 'ref-a',
          ),
        ],
        sentences: [
          sentenceFixture(
            id: 's-h',
            text: 'tout tu.',
            audioRefId: 'ref-h',
            tokens: [
              SentenceToken(id: 't-1', text: 'tout', phonemes: ['t', 'u']),
              SentenceToken(id: 't-2', text: 'tu', phonemes: ['t', 'y']),
              SentenceToken(id: 't-3', text: '.', phonemes: []),
            ],
          ),
        ],
        audioReferences: [
          _wordRef(id: 'ref-p', spokenText: 'tout'),
          _sentenceRef(id: 'ref-h', spokenText: 'tout tu.'),
          _paragraphRef(id: 'ref-r'),
          _wordRef(id: 'ref-a', spokenText: 'new-u'),
        ],
        phonemeCoverage: [
          _cov('u', practiceExerciseIds: const ['e-p']),
          _cov('y',
              status: ContentStatus.planned, practiceExerciseIds: const []),
        ],
      ),
      audioResources: const {
        'ref-p': AudioResourceStatus.practiceTts,
        'ref-h': AudioResourceStatus.practiceTts,
        'ref-r': AudioResourceStatus.practiceTts,
        'ref-a': AudioResourceStatus.reviewedRecording,
      },
    );

    expect(report.errors, isEmpty,
        reason: 'all readiness, no structural error');
    expect(
      _readiness(report),
      [
        ('plannedNode', 'n-planned', ContentPurpose.practice),
        ('plannedNode', 'n-planned-a', ContentPurpose.assessment),
        ('plannedPhoneme', 'y', ContentPurpose.practice),
        ('pendingContentReview', 'e-p', ContentPurpose.practice),
        ('speakingUnassessed', 'e-r', ContentPurpose.assessment),
        ('unreviewedAssessmentContent', 'e-a', ContentPurpose.assessment),
        ('missingReviewedAudio', 'ref-p', ContentPurpose.assessment),
      ],
      reason: 'nodes, coverage, exercises/sentences, audio references',
    );
  });
}
