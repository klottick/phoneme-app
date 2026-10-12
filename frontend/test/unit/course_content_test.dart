// FR-01 Task 4 unit oracle for the authored French catalogue.
//
// Asserts the exact pilot exercise definitions, the legacy word/lesson parity
// (literal values from the baseline fixture), the seven-phoneme coverage
// statuses, the structural-valid-but-honestly-incomplete validation report,
// the unmodifiable exported maps/sets, and the exact optional/planned graph.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_content_validator.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/course_curriculum.dart';
import 'package:linguist/src/core/course/french_course.dart';

/// The ten pilot words with their expected sounds, in authored order:
/// expected sounds alternate u/y.
const List<(String, String)> _pilotWords = [
  ('tout', 'u'),
  ('tu', 'y'),
  ('rouge', 'u'),
  ('rue', 'y'),
  ('vous', 'u'),
  ('lune', 'y'),
  ('doux', 'u'),
  ('jus', 'y'),
  ('loup', 'u'),
  ('mur', 'y'),
];

/// The declared coverage inventory order: u, y, i, o, ɔ̃, ɑ̃, ʁ.
const List<String> _coverageOrder = ['u', 'y', 'i', 'o', 'ɔ̃', 'ɑ̃', 'ʁ'];

/// The frozen literal baseline fixture (provenance a500651).
Map<String, dynamic> _fixture() => jsonDecode(
      File('test/fixtures/course_curriculum_legacy_sessions.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;

/// One readiness issue as a stable `code:recordId:use` triple.
String _diag(CourseContentDiagnostic d) =>
    '${d.code}:${d.recordId}:${d.use?.name ?? 'structural'}';

void main() {
  group('frenchCurriculum identity and pilot content', () {
    test('course id and revision are the approved production values', () {
      expect(frenchCurriculum.courseId, 'en-fr');
      expect(frenchCurriculum.revision, 1);
    });

    test(
        'exactly ten practice listening exercises with exact ids, '
        'aliases, words, targets and choices', () {
      final List<CourseExercise> exercises = frenchCurriculum.exercises;
      expect(exercises.length, 10);
      for (var i = 0; i < 10; i++) {
        final (String word, String sound) = _pilotWords[i];
        final ListeningChoiceExercise exercise;
        if (exercises[i] is! ListeningChoiceExercise) {
          fail('exercise $i must be a listening choice');
        }
        exercise = exercises[i] as ListeningChoiceExercise;
        expect(exercise.id, 'en-fr-u-y-listening-$word');
        expect(exercise.sectionId, 'en-fr-u-y-listening');
        expect(exercise.audioRefId, 'fr-word-$word');
        expect(exercise.purpose, ContentPurpose.practice);
        expect(exercise.reviewState, ContentReviewState.existingCurated);
        expect(exercise.wordId, word);
        expect(exercise.expectedSound, sound);
        expect(exercise.choices, ['u', 'y']);
        expect(exercise.legacyItemId, word);
        expect(exercise.kind, ExerciseKind.listeningChoice);
        expect(exercise.skill, SkillDimension.listening);
      }
    });

    test('the pilot node and section carry the exact approved shape', () {
      final CourseNode node = frenchCurriculum.nodeById('en-fr-u-y')!;
      final CourseLesson lesson =
          frenchLessons.firstWhere((l) => l.id == 'en-fr-u-y');
      expect(node.kind, CourseNodeKind.lesson);
      expect(node.stage, CourseStage.hear);
      expect(node.status, ContentStatus.authored);
      expect(node.optional, isFalse);
      expect(node.prerequisiteIds, isEmpty);
      expect(node.sectionIds, ['en-fr-u-y-listening']);
      expect(node.targetSounds, ['u', 'y']);
      expect(node.title, lesson.title);

      final CourseSection section =
          frenchCurriculum.sectionById('en-fr-u-y-listening')!;
      expect(section.nodeId, 'en-fr-u-y');
      expect(section.title, lesson.title);
      expect(section.explanation, lesson.explanation);
      expect(section.contentRevision, 1);
      expect(section.requiredItemCount, 10);
      expect(
        section.exerciseIds,
        [
          for (final (word, _) in _pilotWords) 'en-fr-u-y-listening-$word',
        ],
      );
    });

    test('no sentences and no assessment exercises are authored', () {
      expect(frenchCurriculum.sentences, isEmpty);
      for (final exercise in frenchCurriculum.exercises) {
        expect(exercise.purpose, ContentPurpose.practice,
            reason: 'no held-out or assessed content in FR-01 Task 4');
      }
    });
  });

  group('legacy content parity (literal baseline values)', () {
    test('frenchCourse matches the frozen baseline course', () {
      final Map<String, dynamic> course =
          _fixture()['parity']['course'] as Map<String, dynamic>;
      expect(frenchCourse.id, course['id']);
      expect(frenchCourse.sourceLanguage, course['sourceLanguage']);
      expect(frenchCourse.targetLanguage, course['targetLanguage']);
      expect(frenchCourse.title, course['title']);
    });

    test(
        'all twenty-four legacy words keep exact text, meaning, IPA, '
        'membership and hints in order', () {
      final List<dynamic> words = _fixture()['parity']['words'] as List;
      expect(frenchWords.length, words.length);
      for (var i = 0; i < words.length; i++) {
        final Map<String, dynamic> word = words[i] as Map<String, dynamic>;
        expect(frenchWords[i].text, word['text']);
        expect(frenchWords[i].meaning, word['meaning']);
        expect(frenchWords[i].ipa, word['ipa']);
        expect(frenchWords[i].sounds, (word['sounds'] as List).cast<String>());
        expect(frenchWords[i].hint, word['hint']);
      }
      // Membership helper preserves its legacy behavior.
      expect(wordByText('tout').contains('u'), isTrue);
      expect(wordByText('lit').contains('i'), isTrue);
    });

    test(
        'all five legacy lessons keep exact ids, titles, explanations, '
        'sounds and words in order', () {
      final List<dynamic> lessons = _fixture()['parity']['lessons'] as List;
      expect(frenchLessons.length, lessons.length);
      for (var i = 0; i < lessons.length; i++) {
        final Map<String, dynamic> lesson = lessons[i] as Map<String, dynamic>;
        expect(frenchLessons[i].id, lesson['id']);
        expect(frenchLessons[i].title, lesson['title']);
        expect(frenchLessons[i].explanation, lesson['explanation']);
        expect(
            frenchLessons[i].sounds, (lesson['sounds'] as List).cast<String>());
        expect(
            frenchLessons[i].words, (lesson['words'] as List).cast<String>());
      }
    });
  });

  group('seven-phoneme coverage statuses', () {
    test('coverage order, statuses and practice lists are exact', () {
      final List<PhonemeCoverage> coverage = frenchCurriculum.phonemeCoverage;
      expect([for (final c in coverage) c.sound], _coverageOrder);
      expect(
        [for (final c in coverage) c.discoveryStatus],
        [
          ContentStatus.authored, // u
          ContentStatus.authored, // y
          ContentStatus.planned, // i
          ContentStatus.planned, // o
          ContentStatus.planned, // ɔ̃
          ContentStatus.planned, // ɑ̃
          ContentStatus.planned, // ʁ
        ],
      );
      final List<CourseExercise> exercises = frenchCurriculum.exercises;
      expect(
        coverage[0].practiceExerciseIds,
        [
          for (var i = 0; i < 10; i += 2) exercises[i].id,
        ],
        reason: 'u coverage lists exactly its five pilot exercises in order',
      );
      expect(
        coverage[1].practiceExerciseIds,
        [
          for (var i = 1; i < 10; i += 2) exercises[i].id,
        ],
        reason: 'y coverage lists exactly its five pilot exercises in order',
      );
      for (var i = 2; i < coverage.length; i++) {
        expect(coverage[i].practiceExerciseIds, isEmpty,
            reason: 'planned coverage for ${coverage[i].sound} lists none');
      }
      // A word containing /ʁ/ (rouge, rue, mur) never establishes an
      // authored /ʁ/ discrimination exercise.
      expect(coverage.last.sound, 'ʁ');
      expect(coverage.last.practiceExerciseIds, isEmpty,
          reason: 'a word containing /ʁ/ does not establish an authored '
              '/ʁ/ discrimination exercise');
    });
  });

  group('audio references, citation and exposure exports', () {
    test('every legacy word declares one word-kind audio reference', () {
      final List<CourseAudioReference> references =
          frenchCurriculum.audioReferences;
      expect(references.length, frenchWords.length);
      for (var i = 0; i < frenchWords.length; i++) {
        expect(references[i].id, 'fr-word-${frenchWords[i].text}');
        expect(references[i].kind, AudioReferenceKind.word);
        expect(references[i].spokenText, frenchWords[i].text);
      }
      // Pilot exercises resolve to those references; nothing else is
      // referenced by the authored pilot.
      for (final reference in references) {
        expect(frenchCurriculum.audioReferenceById(reference.id), reference);
      }
    });

    test(
        'citation phonemes, exposed word ids and audio resources match '
        'the legacy vocabulary exactly', () {
      expect(frenchCitationPhonemes.length, frenchWords.length);
      for (final word in frenchWords) {
        expect(frenchCitationPhonemes[word.text], word.sounds);
      }
      expect(frenchExposedWordIds, {for (final word in frenchWords) word.text});
      expect(frenchAudioResources.length, frenchWords.length);
      for (final word in frenchWords) {
        expect(
          frenchAudioResources['fr-word-${word.text}'],
          AudioResourceStatus.practiceTts,
          reason: 'each legacy word declares only its labeled practice-TTS '
              'fallback, never a device voice claim',
        );
      }
    });

    test('all new French maps and sets forbid mutation', () {
      expect(() => frenchCitationPhonemes['probe'] = const ['q'],
          throwsA(isA<UnsupportedError>()));
      expect(() => frenchCitationPhonemes.remove('tout'),
          throwsA(isA<UnsupportedError>()));
      expect(() => frenchCitationPhonemes['tout']!.add('q'),
          throwsA(isA<UnsupportedError>()));
      expect(() => frenchExposedWordIds.add('probe'),
          throwsA(isA<UnsupportedError>()));
      expect(
          () => frenchAudioResources['probe-ref'] = AudioResourceStatus.missing,
          throwsA(isA<UnsupportedError>()));
      expect(
          () => frenchAudioResources['fr-word-tout'] =
              AudioResourceStatus.missing,
          throwsA(isA<UnsupportedError>()));
      // The catalogue's own collections are detached and unmodifiable as
      // well.
      final CourseCurriculum curriculum = frenchCurriculum;
      expect(
          () => curriculum.nodes.add(CourseNode(
                id: 'ghost',
                title: 'ghost',
                kind: CourseNodeKind.lesson,
                stage: CourseStage.hear,
                status: ContentStatus.planned,
                optional: false,
                prerequisiteIds: const [],
                sectionIds: const [],
                targetSounds: const [],
              )),
          throwsA(isA<UnsupportedError>()));
      expect(
          () => curriculum.phonemeCoverage[0].practiceExerciseIds.add('ghost'),
          throwsA(isA<UnsupportedError>()));
    });
  });

  group('optional and planned graph exactly as specified', () {
    test('node array order and every node field are exact', () {
      const allSeven = ['u', 'y', 'i', 'o', 'ɔ̃', 'ɑ̃', 'ʁ'];
      expect([
        for (final n in frenchCurriculum.nodes) n.id
      ], [
        'en-fr-u-y',
        'en-fr-targeted-review',
        'en-fr-games',
        'en-fr-articulation',
        'en-fr-find-sounds',
        'en-fr-connect-spellings',
        'en-fr-checkpoint',
      ]);
      final List<CourseNode> nodes = frenchCurriculum.nodes;
      expect(nodes[0], isNotNull);
      // Optional planned nodes: target all seven sounds, no prerequisites.
      const expectedOptional = [
        // (id, kind, stage, title)
        ('en-fr-targeted-review', 'Targeted review'),
        ('en-fr-games', 'Games'),
        ('en-fr-articulation', 'Articulation coaching'),
      ];
      const expectedOptionalKinds = [
        CourseNodeKind.review,
        CourseNodeKind.game,
        CourseNodeKind.articulation,
      ];
      for (var i = 0; i < 3; i++) {
        final CourseNode node = nodes[1 + i];
        expect(node.id, expectedOptional[i].$1);
        expect(node.title, expectedOptional[i].$2);
        expect(node.kind, expectedOptionalKinds[i]);
        expect(node.stage, CourseStage.hear,
            reason: '${node.id} is a planned hear-stage optional node');
        expect(node.status, ContentStatus.planned);
        expect(node.optional, isTrue);
        expect(node.prerequisiteIds, isEmpty);
        expect(node.sectionIds, isEmpty);
        expect(node.targetSounds, allSeven);
      }
      // Planned required main nodes with the specified prerequisite chain.
      const expectedMain = [
        // (id, kind, stage, title, prerequisite)
        (
          'en-fr-find-sounds',
          CourseStage.find,
          'Find sounds in context',
          'en-fr-u-y'
        ),
        (
          'en-fr-connect-spellings',
          CourseStage.spell,
          'Connect sounds and spellings',
          'en-fr-find-sounds'
        ),
        (
          'en-fr-checkpoint',
          CourseStage.assess,
          'Check your progress',
          'en-fr-connect-spellings'
        ),
      ];
      for (var i = 0; i < 3; i++) {
        final CourseNode node = nodes[4 + i];
        expect(node.id, expectedMain[i].$1);
        expect(node.title, expectedMain[i].$3);
        expect(node.kind,
            i < 2 ? CourseNodeKind.lesson : CourseNodeKind.assessment);
        expect(node.stage, expectedMain[i].$2);
        expect(node.status, ContentStatus.planned);
        expect(node.optional, isFalse);
        expect(node.prerequisiteIds, [expectedMain[i].$4]);
        expect(node.sectionIds, isEmpty,
            reason: 'planned nodes carry no sections in FR-01');
        expect(node.targetSounds, allSeven,
            reason: '${node.id} targets the whole declared inventory');
      }
      // Uniqueness: every authored id resolves, duplicates do not.
      for (final node in nodes) {
        expect(frenchCurriculum.nodeById(node.id), node);
      }
      expect(frenchCurriculum.nodeById('ghost-node'), isNull);
    });
  });

  group('validation report for the authored catalogue', () {
    test(
        'no structural errors; readiness issues are exactly the '
        'planned slots and missing reviewed recordings', () {
      final CourseValidationReport report = frenchCurriculumValidation;
      expect(report.isStructurallyValid, isTrue,
          reason: 'the authored pilot catalogue must be structurally valid');
      expect(
        report.errors,
        isEmpty,
        reason: 'every declared word reference resolves; structural '
            'dangling references are not readiness issues',
      );
      expect(
        [for (final d in report.readinessIssues) _diag(d)],
        [
          'plannedNode:en-fr-targeted-review:practice',
          'plannedNode:en-fr-games:practice',
          'plannedNode:en-fr-articulation:practice',
          'plannedNode:en-fr-find-sounds:practice',
          'plannedNode:en-fr-connect-spellings:practice',
          'plannedNode:en-fr-checkpoint:assessment',
          'plannedPhoneme:i:practice',
          'plannedPhoneme:o:practice',
          'plannedPhoneme:ɔ̃:practice',
          'plannedPhoneme:ɑ̃:practice',
          'plannedPhoneme:ʁ:practice',
          for (final word in frenchWords)
            'missingReviewedAudio:fr-word-${word.text}:assessment',
        ],
      );
      // Readiness never blocks practice: no practice-use missing audio.
      expect(
        report.readinessIssues
            .where((d) => d.code == 'missingPracticeAudio')
            .length,
        0,
        reason: 'the declared labeled practice-TTS fallback keeps '
            'practice ready',
      );
    });
  });
}
