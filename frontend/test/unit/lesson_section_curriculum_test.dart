// FR-01 Task 4 unit oracle for the LessonSection curriculum projection.
//
// Proves LessonSection.fromCurriculum derives items, metadata and revision
// from the injected (synthetic) catalogue rather than production literals,
// rejects unsupported projection shapes with StateError, and that the
// production bridge (frenchUySection / sectionForLesson) stays pilot-only
// with unchanged public values.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_content_validator.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/course_curriculum.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/lesson_section.dart';

/// One synthetic catalogue item, in the section's declared order.
class _Entry {
  _Entry({
    required this.id,
    required this.word,
    required this.sound,
    this.alias,
    this.sectionId,
    this.choices,
  });

  final String id;
  final String word;
  final String sound;
  final String? alias;
  final String? sectionId;
  final List<String>? choices;
}

/// Builds one small synthetic listening catalogue. Words, targets, aliases,
/// the ordered choices and the section metadata all differ from the
/// production pilot, so a hard-coded fallback would fail these tests.
CourseCurriculum _synthetic({
  String nodeId = 'syn-listen',
  required List<_Entry> entries,
  String title = 'Synthetic listen',
  String explanation = 'Synthetic section-end explanation.',
  int revision = 7,
  List<String> choices = const ['y', 'u'],
  String sectionId = 'syn-section',
  List<String>? nodeIds,
  bool twoSections = false,
  int requiredItemCount = 0,
  bool spelling = false,
  ContentPurpose purpose = ContentPurpose.practice,
  CourseStage stage = CourseStage.hear,
  List<String>? nodeSectionIds,
  List<String>? sectionExerciseIds,
}) {
  final List<CourseExercise> exercises = spelling
      ? [
          SpellingChoiceExercise(
            id: 'syn-spell',
            sectionId: sectionId,
            audioRefId: 'fr-word-alpha',
            purpose: purpose,
            reviewState: ContentReviewState.existingCurated,
            wordId: 'alpha',
            targetSound: 'y',
            options: [
              SpellingOption(id: 'opt-a', text: 'ue'),
              SpellingOption(id: 'opt-b', text: 'ou'),
            ],
            correctOptionId: 'opt-a',
          ),
        ]
      : [
          for (final e in entries)
            ListeningChoiceExercise(
              id: e.id,
              sectionId: e.sectionId ?? sectionId,
              audioRefId: 'fr-word-${e.word}',
              purpose: purpose,
              reviewState: ContentReviewState.existingCurated,
              wordId: e.word,
              expectedSound: e.sound,
              choices: e.choices ?? choices,
              legacyItemId: e.alias,
            ),
        ];
  final List<CourseSection> sections = [
    CourseSection(
      id: sectionId,
      nodeId: nodeId,
      title: title,
      explanation: explanation,
      contentRevision: revision,
      exerciseIds: spelling
          ? const ['syn-spell']
          : (sectionExerciseIds ?? [for (final e in entries) e.id]),
      requiredItemCount: spelling
          ? 1
          : (requiredItemCount == 0 ? entries.length : requiredItemCount),
    ),
    if (twoSections)
      CourseSection(
        id: 'syn-second',
        nodeId: nodeId,
        title: 'Synthetic second',
        explanation: 'A second section the node also lists.',
        contentRevision: revision,
        exerciseIds: const <String>[],
        requiredItemCount: 1,
      ),
  ];
  final List<CourseNode> nodes = [
    for (final id in (nodeIds ?? [nodeId]))
      CourseNode(
        id: id,
        title: title,
        kind: CourseNodeKind.lesson,
        stage: stage,
        status: ContentStatus.authored,
        optional: false,
        prerequisiteIds: const <String>[],
        sectionIds: nodeSectionIds ??
            (twoSections ? [sectionId, 'syn-second'] : [sectionId]),
        targetSounds: const <String>['u', 'y'],
      ),
  ];
  return CourseCurriculum(
    courseId: 'syn-course',
    revision: 1,
    nodes: nodes,
    sections: sections,
    exercises: exercises,
    sentences: const <CourseSentence>[],
    audioReferences: [
      for (final e in entries)
        CourseAudioReference(
          id: 'fr-word-${e.word}',
          kind: AudioReferenceKind.word,
          spokenText: e.word,
        ),
      if (spelling)
        CourseAudioReference(
          id: 'fr-word-alpha',
          kind: AudioReferenceKind.word,
          spokenText: 'alpha',
        ),
    ],
    phonemeCoverage: [
      // Coverage follows the actual practice exercises so the positive
      // baseline stays structurally valid: each teaching sound references
      // exactly the distinct practice exercises that teach it.
      for (final String sound in ['u', 'y'])
        PhonemeCoverage(
          sound: sound,
          discoveryStatus: ContentStatus.authored,
          practiceExerciseIds: [
            for (final CourseExercise exercise in exercises)
              if (exercise is ListeningChoiceExercise &&
                  exercise.expectedSound == sound)
                exercise.id
              else if (exercise is SpellingChoiceExercise &&
                  exercise.targetSound == sound)
                exercise.id,
          ],
        ),
    ],
  );
}

CourseCurriculum _validTwoItems() => _synthetic(entries: [
      _Entry(id: 'syn-beta', word: 'beta', sound: 'u', alias: 'old-b'),
      _Entry(id: 'syn-alpha', word: 'alpha', sound: 'y', alias: 'old-a'),
    ]);

List<({String id, String word, String expectedSound})> _items(
        LessonSection section) =>
    [
      for (final item in section.items)
        (id: item.id, word: item.word, expectedSound: item.expectedSound)
    ];

void main() {
  group('fromCurriculum derives the projection from the injected catalogue',
      () {
    test(
        'item order, words, targets, metadata and revision come from the '
        'catalogue', () {
      final LessonSection section = LessonSection.fromCurriculum(
        _validTwoItems(),
        lessonId: 'syn-listen',
      );
      expect(section.lessonId, 'syn-listen');
      expect(section.title, 'Synthetic listen');
      expect(section.explanation, 'Synthetic section-end explanation.');
      expect(section.contentRevision, 7,
          reason: 'metadata and revision are copied, not defaulted');
      expect(section.sounds, ['y', 'u'],
          reason: 'the shared ordered choices come from the catalogue');
      expect(
        _items(section),
        [
          (id: 'old-b', word: 'beta', expectedSound: 'u'),
          (id: 'old-a', word: 'alpha', expectedSound: 'y'),
        ],
        reason: 'aliases, words and targets are read from the '
            'catalogue exercises in declared order',
      );
    });

    test('changing the injected item order changes the projection order', () {
      final LessonSection section = LessonSection.fromCurriculum(
        _synthetic(entries: [
          _Entry(id: 'syn-alpha', word: 'alpha', sound: 'y', alias: 'old-a'),
          _Entry(id: 'syn-beta', word: 'beta', sound: 'u', alias: 'old-b'),
        ]),
        lessonId: 'syn-listen',
      );
      expect(
        _items(section),
        [
          (id: 'old-a', word: 'alpha', expectedSound: 'y'),
          (id: 'old-b', word: 'beta', expectedSound: 'u'),
        ],
      );
    });

    test(
        'the retained caller lists used to build the injected catalogue '
        'cannot affect the projection once constructed, and the projected '
        'item/sound lists reject mutation', () {
      // These mutable lists are the actual caller inputs the injected
      // catalogue is constructed from — not stand-ins built afterward.
      final List<ListeningChoiceExercise> retainedExercises = [
        ListeningChoiceExercise(
          id: 'syn-beta',
          sectionId: 'syn-section',
          audioRefId: 'fr-word-beta',
          purpose: ContentPurpose.practice,
          reviewState: ContentReviewState.existingCurated,
          wordId: 'beta',
          expectedSound: 'u',
          choices: const ['y', 'u'],
          legacyItemId: 'old-b',
        ),
        ListeningChoiceExercise(
          id: 'syn-alpha',
          sectionId: 'syn-section',
          audioRefId: 'fr-word-alpha',
          purpose: ContentPurpose.practice,
          reviewState: ContentReviewState.existingCurated,
          wordId: 'alpha',
          expectedSound: 'y',
          choices: const ['y', 'u'],
          legacyItemId: 'old-a',
        ),
      ];
      final List<String> retainedSectionExerciseIds = [
        'syn-beta',
        'syn-alpha',
      ];
      final List<String> retainedNodeSectionIds = ['syn-section'];
      final CourseSection syntheticSection = CourseSection(
        id: 'syn-section',
        nodeId: 'syn-listen',
        title: 'Synthetic listen',
        explanation: 'Synthetic section-end explanation.',
        contentRevision: 7,
        exerciseIds: retainedSectionExerciseIds,
        requiredItemCount: retainedSectionExerciseIds.length,
      );
      final CourseNode syntheticNode = CourseNode(
        id: 'syn-listen',
        title: 'Synthetic listen',
        kind: CourseNodeKind.lesson,
        stage: CourseStage.hear,
        status: ContentStatus.authored,
        optional: false,
        prerequisiteIds: const <String>[],
        sectionIds: retainedNodeSectionIds,
        targetSounds: const <String>['u', 'y'],
      );
      final CourseCurriculum catalogue = CourseCurriculum(
        courseId: 'syn-course',
        revision: 1,
        nodes: [syntheticNode],
        sections: [syntheticSection],
        exercises: retainedExercises,
        sentences: const <CourseSentence>[],
        audioReferences: [
          CourseAudioReference(
            id: 'fr-word-beta',
            kind: AudioReferenceKind.word,
            spokenText: 'beta',
          ),
          CourseAudioReference(
            id: 'fr-word-alpha',
            kind: AudioReferenceKind.word,
            spokenText: 'alpha',
          ),
        ],
        phonemeCoverage: [
          PhonemeCoverage(
            sound: 'u',
            discoveryStatus: ContentStatus.authored,
            practiceExerciseIds: const ['syn-beta'],
          ),
          PhonemeCoverage(
            sound: 'y',
            discoveryStatus: ContentStatus.authored,
            practiceExerciseIds: const ['syn-alpha'],
          ),
        ],
      );
      final LessonSection section =
          LessonSection.fromCurriculum(catalogue, lessonId: 'syn-listen');
      final List<({String id, String word, String expectedSound})> itemsBefore =
          _items(section);
      final List<String> soundsBefore = List.of(section.sounds);

      // Mutate every retained caller list the catalogue was built from.
      retainedExercises.add(ListeningChoiceExercise(
        id: 'syn-ghost',
        sectionId: 'syn-section',
        audioRefId: 'fr-word-ghost',
        purpose: ContentPurpose.practice,
        reviewState: ContentReviewState.existingCurated,
        wordId: 'ghost',
        expectedSound: 'u',
        choices: const ['y', 'u'],
        legacyItemId: 'old-ghost',
      ));
      retainedSectionExerciseIds.add('syn-ghost');
      retainedNodeSectionIds.add('syn-second');
      retainedExercises.removeAt(0);
      retainedSectionExerciseIds.removeLast();
      retainedNodeSectionIds.removeLast();

      expect(_items(section), itemsBefore,
          reason: 'the projection is detached from every retained caller '
              'list: adding, dropping and reordering the inputs after '
              'construction cannot change it');
      expect(section.sounds, soundsBefore,
          reason: 'the shared choice list is copied, not retained');
      expect(
          () => section.items.add(
                const LessonSectionItem(
                    id: 'ghost', word: 'ghost', expectedSound: 'u'),
              ),
          throwsA(isA<UnsupportedError>()),
          reason: 'the projected item list rejects mutation');
      expect(
          () => section.sounds.add('ghost'), throwsA(isA<UnsupportedError>()),
          reason: 'the projected sound list rejects mutation');
      expect(section.sounds.toSet(), {'u', 'y'});
    });
  });

  group('the positive synthetic baseline is structurally valid', () {
    test(
        'the generic validator accepts the injected baseline with synthetic '
        'citation and audio inputs', () {
      final CourseValidationReport reviewed = validateCourseContent(
        _validTwoItems(),
        citationPhonemes: const {
          'beta': ['u'],
          'alpha': ['y']
        },
        exposedWordIds: const {'beta', 'alpha'},
        audioResources: const {
          'fr-word-beta': AudioResourceStatus.reviewedRecording,
          'fr-word-alpha': AudioResourceStatus.reviewedRecording,
        },
      );
      expect(reviewed.errors, isEmpty,
          reason: '_validTwoItems is a structurally valid injected catalogue, '
              'not just a projection-shaped one');
      expect(reviewed.isStructurallyValid, isTrue);
      expect(reviewed.readinessIssues, isEmpty,
          reason: 'reviewed recordings plus curated citations leave the '
              'baseline fully ready');

      // The French production catalogue shape (practice-TTS recordings) must
      // stay structurally valid too, with only the honest readiness issue.
      final CourseValidationReport practiceTts = validateCourseContent(
        _validTwoItems(),
        citationPhonemes: const {
          'beta': ['u'],
          'alpha': ['y']
        },
        exposedWordIds: const {'beta', 'alpha'},
        audioResources: const {
          'fr-word-beta': AudioResourceStatus.practiceTts,
          'fr-word-alpha': AudioResourceStatus.practiceTts,
        },
      );
      expect(practiceTts.isStructurallyValid, isTrue,
          reason: 'declared practice-TTS resources are readiness, not '
              'structure');
      expect(
          practiceTts.readinessIssues
              .map((CourseContentDiagnostic issue) => issue.code)
              .toSet(),
          {'missingReviewedAudio'},
          reason: 'word references without reviewed recordings report the '
              'honest readiness issue');
      expect(practiceTts.readinessIssues.length, 2,
          reason: 'one honest issue per declared word reference');
    });
  });

  group('production pilot bridge stays unchanged and pilot-only', () {
    test('frenchUySection exposes the legacy pilot values exactly', () {
      final LessonSection section = frenchUySection;
      expect(section.lessonId, 'en-fr-u-y');
      final CourseLesson lesson =
          frenchLessons.firstWhere((l) => l.id == 'en-fr-u-y');
      expect(section.title, lesson.title);
      expect(section.explanation, lesson.explanation);
      expect(section.contentRevision, 1);
      expect(section.sounds, ['u', 'y']);
      expect(
        _items(section),
        [
          (id: 'tout', word: 'tout', expectedSound: 'u'),
          (id: 'tu', word: 'tu', expectedSound: 'y'),
          (id: 'rouge', word: 'rouge', expectedSound: 'u'),
          (id: 'rue', word: 'rue', expectedSound: 'y'),
          (id: 'vous', word: 'vous', expectedSound: 'u'),
          (id: 'lune', word: 'lune', expectedSound: 'y'),
          (id: 'doux', word: 'doux', expectedSound: 'u'),
          (id: 'jus', word: 'jus', expectedSound: 'y'),
          (id: 'loup', word: 'loup', expectedSound: 'u'),
          (id: 'mur', word: 'mur', expectedSound: 'y'),
        ],
      );
    });

    test(
        'sectionForLesson returns the cached pilot instance and null for '
        'every other lesson id', () {
      expect(identical(sectionForLesson('en-fr-u-y'), frenchUySection), isTrue,
          reason: 'the same cached instance is returned');
      for (final String other in [
        'en-fr-vowels',
        'en-fr-nasal',
        'en-fr-r',
        'en-fr-mix',
        'en-fr-u-y-listening',
        'en-fr-targeted-review',
        'en-fr-find-sounds',
        'en-fr-checkpoint',
        'ghost',
        'en-fr'
      ]) {
        expect(sectionForLesson(other), isNull,
            reason: 'non-pilot lesson $other has no section');
      }
      expect(sectionForLesson(''), isNull);
    });

    test('the production projection equals the catalogue-derived section', () {
      final LessonSection projected = LessonSection.fromCurriculum(
        frenchCurriculum,
        lessonId: 'en-fr-u-y',
      );
      expect(projected.lessonId, frenchUySection.lessonId);
      expect(projected.title, frenchUySection.title);
      expect(projected.explanation, frenchUySection.explanation);
      expect(projected.contentRevision, frenchUySection.contentRevision);
      expect(projected.sounds, frenchUySection.sounds);
      expect(_items(projected), _items(frenchUySection));
      // Saved identity stays legacy: words come from the existing
      // vocabulary and the item ID keeps the legacy alias.
      for (final item in projected.items) {
        expect(frenchWords.any((word) => word.text == item.word), isTrue,
            reason: 'projected words must be existing curated words');
        for (final word in frenchWords) {
          if (item.word == word.text && item.id != word.text) {
            fail('item ${item.id} must keep the legacy alias as its saved id');
          }
        }
      }
    });

    test('LessonSectionItem equality remains value-based', () {
      const LessonSectionItem a =
          LessonSectionItem(id: 'x', word: 'x', expectedSound: 'u');
      const LessonSectionItem b =
          LessonSectionItem(id: 'x', word: 'x', expectedSound: 'u');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
          a,
          isNot(
              const LessonSectionItem(id: 'y', word: 'y', expectedSound: 'u')));
    });
  });

  group('projection failure is explicit and never partial', () {
    void expectUnsupported(Object? Function() action) {
      expect(action, throwsA(isA<StateError>()));
    }

    test('missing node', () {
      expectUnsupported(() =>
          LessonSection.fromCurriculum(_validTwoItems(), lessonId: 'ghost'));
    });

    test('duplicated (ambiguous) node id', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(
                entries: const [],
                nodeIds: const ['syn-listen', 'syn-listen'],
                requiredItemCount: 1),
            lessonId: 'syn-listen',
          ));
    });

    test(
        'a duplicated section listing is ambiguous and cannot silently '
        'collapse', () {
      // Required count equals the distinct section count, so the count check
      // cannot hide the duplicate: only an explicit ambiguity rejection can.
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(
              entries: [
                _Entry(
                    id: 'syn-beta', word: 'beta', sound: 'u', alias: 'old-b'),
              ],
              nodeSectionIds: const ['syn-section', 'syn-section'],
              requiredItemCount: 1,
            ),
            lessonId: 'syn-listen',
          ));
    });

    test(
        'a duplicated exercise listing is ambiguous and cannot silently '
        'collapse', () {
      // Required count equals the distinct exercise count, so the count
      // check cannot hide the duplicate; distinctness must be rejected.
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(
              entries: [
                _Entry(
                    id: 'syn-beta', word: 'beta', sound: 'u', alias: 'old-b'),
              ],
              sectionExerciseIds: const ['syn-beta', 'syn-beta'],
              requiredItemCount: 1,
            ),
            lessonId: 'syn-listen',
          ));
    });

    test(
        'an assessment-purpose item cannot project into a live practice '
        'section', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(
              entries: [
                _Entry(
                    id: 'syn-beta', word: 'beta', sound: 'u', alias: 'old-b'),
              ],
              purpose: ContentPurpose.assessment,
            ),
            lessonId: 'syn-listen',
          ));
    });

    test(
        'a non-hear lesson stage cannot project a practice listening '
        'section', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(
              entries: [
                _Entry(
                    id: 'syn-beta', word: 'beta', sound: 'u', alias: 'old-b'),
              ],
              stage: CourseStage.find,
            ),
            lessonId: 'syn-listen',
          ));
    });

    test('a single choice label is not the supported unambiguous key', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(
              entries: [
                _Entry(
                    id: 'syn-beta', word: 'beta', sound: 'u', alias: 'old-b'),
              ],
              choices: const ['u'],
            ),
            lessonId: 'syn-listen',
          ));
    });

    test('a repeated expected choice is not the supported unambiguous key', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(
              entries: [
                _Entry(
                    id: 'syn-beta', word: 'beta', sound: 'u', alias: 'old-b'),
              ],
              choices: const ['u', 'u'],
            ),
            lessonId: 'syn-listen',
          ));
    });

    test('blank choice labels cannot project', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(
              entries: [
                _Entry(
                    id: 'syn-beta', word: 'beta', sound: 'u', alias: 'old-b'),
              ],
              choices: const ['u', ' '],
            ),
            lessonId: 'syn-listen',
          ));
    });

    test('a non-lesson node cannot project', () {
      final CourseCurriculum base = _validTwoItems();
      final CourseCurriculum broken = CourseCurriculum(
        courseId: 'syn-course',
        revision: 1,
        nodes: [
          CourseNode(
            id: 'syn-listen',
            title: 'Review',
            kind: CourseNodeKind.review,
            stage: CourseStage.hear,
            status: ContentStatus.authored,
            optional: true,
            prerequisiteIds: const [],
            sectionIds: const ['syn-section'],
            targetSounds: const ['u', 'y'],
          ),
        ],
        sections: base.sections,
        exercises: base.exercises,
        sentences: base.sentences,
        audioReferences: base.audioReferences,
        phonemeCoverage: base.phonemeCoverage,
      );
      expectUnsupported(
          () => LessonSection.fromCurriculum(broken, lessonId: 'syn-listen'));
    });

    test('unsupported exercise kind', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(entries: const [], spelling: true),
            lessonId: 'syn-listen',
          ));
    });

    test('exercise with the wrong owning section', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(entries: [
              _Entry(
                  id: 'syn-beta',
                  word: 'beta',
                  sound: 'u',
                  alias: 'old-b',
                  sectionId: 'other-section'),
              _Entry(
                  id: 'syn-alpha', word: 'alpha', sound: 'y', alias: 'old-a'),
            ]),
            lessonId: 'syn-listen',
          ));
    });

    test('a node owning two sections has no single projection', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(
              entries: [
                _Entry(
                    id: 'syn-beta', word: 'beta', sound: 'u', alias: 'old-b'),
                _Entry(
                    id: 'syn-alpha', word: 'alpha', sound: 'y', alias: 'old-a'),
              ],
              twoSections: true,
            ),
            lessonId: 'syn-listen',
          ));
    });

    test('required-count mismatch', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(
              entries: [
                _Entry(
                    id: 'syn-beta', word: 'beta', sound: 'u', alias: 'old-b'),
              ],
              requiredItemCount: 2,
            ),
            lessonId: 'syn-listen',
          ));
    });

    test('a node with no projectable records', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(entries: const [], requiredItemCount: 1),
            lessonId: 'syn-listen',
          ));
    });

    test('missing legacy alias', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(entries: [
              _Entry(id: 'syn-beta', word: 'beta', sound: 'u', alias: null),
              _Entry(
                  id: 'syn-alpha', word: 'alpha', sound: 'y', alias: 'old-a'),
            ]),
            lessonId: 'syn-listen',
          ));
    });

    test('duplicated legacy aliases', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(entries: [
              _Entry(id: 'syn-beta', word: 'beta', sound: 'u', alias: 'same'),
              _Entry(id: 'syn-alpha', word: 'alpha', sound: 'y', alias: 'same'),
            ]),
            lessonId: 'syn-listen',
          ));
    });

    test('differently ordered choices across exercises', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(entries: [
              _Entry(id: 'syn-beta', word: 'beta', sound: 'u', alias: 'old-b'),
              _Entry(
                  id: 'syn-alpha',
                  word: 'alpha',
                  sound: 'y',
                  alias: 'old-a',
                  choices: const ['u', 'y']),
            ]),
            lessonId: 'syn-listen',
          ));
    });

    test('expected sound absent from its choices', () {
      expectUnsupported(() => LessonSection.fromCurriculum(
            _synthetic(entries: [
              _Entry(id: 'syn-beta', word: 'beta', sound: 'o', alias: 'old-b'),
              _Entry(
                  id: 'syn-alpha', word: 'alpha', sound: 'y', alias: 'old-a'),
            ]),
            lessonId: 'syn-listen',
          ));
    });
  });
}
