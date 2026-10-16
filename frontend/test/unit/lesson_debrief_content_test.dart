import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/lesson_debrief_content.dart';
import 'package:linguist/src/core/course/french_lesson_teaching.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/course_curriculum.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/lesson_section.dart';

void main() {
  test('teaching_validates_complete_pilot_and_detaches', () {
    final notes = frenchPilotTeachingNotes.toList();
    final content = LessonDebriefContent.fromCurriculum(
      frenchCurriculum,
      lessonId: 'en-fr-u-y',
      notes: notes,
    );
    expect(content.contentRevision, 1);
    expect(content.entries.map((entry) => entry.itemId), [
      'tout',
      'tu',
      'rouge',
      'rue',
      'vous',
      'lune',
      'doux',
      'jus',
      'loup',
      'mur'
    ]);
    expect(content.entries.map((entry) => entry.text), [
      'French /u/ in tout is close to the vowel in English “food”, but keep it steady.',
      'For /y/ in tu, hold your tongue as for /i/ and round your lips.',
      'French /u/ in tout is close to the vowel in English “food”, but keep it steady.',
      'For /y/ in tu, hold your tongue as for /i/ and round your lips.',
      'French /u/ in tout is close to the vowel in English “food”, but keep it steady.',
      'For /y/ in tu, hold your tongue as for /i/ and round your lips.',
      'French /u/ in tout is close to the vowel in English “food”, but keep it steady.',
      'For /y/ in tu, hold your tongue as for /i/ and round your lips.',
      'French /u/ in tout is close to the vowel in English “food”, but keep it steady.',
      'For /y/ in tu, hold your tongue as for /i/ and round your lips.',
    ]);
    expect(content.forUnresolved(['mur', 'tout']).map((e) => e.itemId),
        ['tout', 'mur']);
    expect(content.forUnresolved([]), isEmpty);
    expect(() => content.entries.add(content.entries.first),
        throwsUnsupportedError);
    expect(
        () => content.forUnresolved(['tout']).clear(), throwsUnsupportedError);
    expect(() => content.entries.clear(), throwsUnsupportedError);
    notes.clear();
    expect(content.entries, hasLength(10));
  });

  test('teaching_rejects_ambiguous_bindings_and_unknown_aliases', () {
    final valid = frenchPilotTeachingNotes;
    final missing = valid.sublist(1);
    expect(
        () => LessonDebriefContent.fromCurriculum(
              frenchCurriculum,
              lessonId: 'en-fr-u-y',
              notes: missing,
            ),
        throwsA(isA<LessonTeachingValidationException>()));
    expect(() => loadFrenchPilotDebriefContent().forUnresolved(['missing']),
        throwsArgumentError);
    expect(
        () => loadFrenchPilotDebriefContent().forUnresolved(['tout', 'tout']),
        throwsArgumentError);
    final diagnostics = validateLessonDebriefContent(
      frenchCurriculum,
      lessonId: 'en-fr-u-y',
      notes: [valid.first, valid.first],
    );
    expect(diagnostics.map((d) => [d.code, d.recordId]), [
      ['note.duplicate', 'en-fr-u-y-listening-tout'],
      ['note.missing', 'en-fr-u-y-listening-tu'],
      ['note.missing', 'en-fr-u-y-listening-rouge'],
      ['note.missing', 'en-fr-u-y-listening-rue'],
      ['note.missing', 'en-fr-u-y-listening-vous'],
      ['note.missing', 'en-fr-u-y-listening-lune'],
      ['note.missing', 'en-fr-u-y-listening-doux'],
      ['note.missing', 'en-fr-u-y-listening-jus'],
      ['note.missing', 'en-fr-u-y-listening-loup'],
      ['note.missing', 'en-fr-u-y-listening-mur'],
    ]);
    expect(() => diagnostics.clear(), throwsUnsupportedError);
    final mutableDiagnostics = <LessonTeachingDiagnostic>[
      const LessonTeachingDiagnostic(code: 'note.blank', recordId: 'fixture'),
    ];
    final exception = LessonTeachingValidationException(mutableDiagnostics);
    mutableDiagnostics.clear();
    expect(exception.diagnostics, hasLength(1));
    expect(() => exception.diagnostics.clear(), throwsUnsupportedError);
  });

  test('invalid supplied notes report every code in deterministic order', () {
    final sample = frenchPilotTeachingNotes.first;
    final cases = <({List<LessonTeachingNote> notes, List<List<String>> want})>[
      (
        notes: frenchPilotTeachingNotes
            .where((n) => n.exerciseId != sample.exerciseId)
            .toList(),
        want: [
          ['note.missing', 'en-fr-u-y-listening-tout'],
        ]
      ),
      (
        notes: [...frenchPilotTeachingNotes, sample],
        want: [
          ['note.duplicate', sample.exerciseId],
        ]
      ),
      (
        notes: [
          ...frenchPilotTeachingNotes
              .where((n) => n.exerciseId != sample.exerciseId),
          LessonTeachingNote(
              sectionId: sample.sectionId,
              exerciseId: sample.exerciseId,
              text: ' ')
        ],
        want: [
          ['note.blank', sample.exerciseId],
        ]
      ),
      (
        notes: [
          ...frenchPilotTeachingNotes
              .where((n) => n.exerciseId != sample.exerciseId),
          const LessonTeachingNote(
              sectionId: 'en-fr-u-y-listening',
              exerciseId: 'unknown',
              text: 'note')
        ],
        want: [
          ['note.unknownExercise', 'unknown'],
          ['note.missing', 'en-fr-u-y-listening-tout'],
        ]
      ),
      (
        notes: [
          ...frenchPilotTeachingNotes
              .where((n) => n.exerciseId != sample.exerciseId),
          LessonTeachingNote(
              sectionId: 'wrong-section',
              exerciseId: sample.exerciseId,
              text: 'note')
        ],
        want: [
          ['note.sectionMismatch', sample.exerciseId],
        ]
      ),
    ];
    for (final fixture in cases) {
      final diagnostics = validateLessonDebriefContent(frenchCurriculum,
          lessonId: 'en-fr-u-y', notes: fixture.notes);
      expect(diagnostics.map((d) => [d.code, d.recordId]), fixture.want);
      expect(
          () => LessonDebriefContent.fromCurriculum(frenchCurriculum,
              lessonId: 'en-fr-u-y', notes: fixture.notes),
          throwsA(isA<LessonTeachingValidationException>()));
    }
  });

  test(
      'selected branch ignores unrelated malformed content and duplicate aliases',
      () {
    final sample = frenchPilotTeachingNotes.toList();
    final unrelated = ListeningChoiceExercise(
      id: 'unrelated-duplicate-alias',
      sectionId: 'planned-section',
      audioRefId: 'missing-audio',
      purpose: ContentPurpose.practice,
      reviewState: ContentReviewState.pending,
      wordId: 'not-a-pilot-item',
      expectedSound: 'consonant',
      choices: const ['consonant', 'other'],
      legacyItemId: 'tout',
    );
    final curriculum = CourseCurriculum(
      courseId: frenchCurriculum.courseId,
      revision: frenchCurriculum.revision,
      nodes: frenchCurriculum.nodes,
      sections: frenchCurriculum.sections,
      exercises: [unrelated, ...frenchCurriculum.exercises],
      sentences: frenchCurriculum.sentences,
      audioReferences: frenchCurriculum.audioReferences,
      phonemeCoverage: frenchCurriculum.phonemeCoverage,
    );
    expect(
        LessonDebriefContent.fromCurriculum(curriculum,
                lessonId: 'en-fr-u-y', notes: sample)
            .entries
            .first
            .word,
        'tout');
    final projected =
        LessonSection.fromCurriculum(frenchCurriculum, lessonId: 'en-fr-u-y');
    expect(projected.items, hasLength(10));
  });

  test('selected source projection failure is a sole deterministic diagnostic',
      () {
    final section = frenchCurriculum.sections.single;
    final badSection = CourseSection(
        id: section.id,
        nodeId: section.nodeId,
        title: section.title,
        explanation: section.explanation,
        contentRevision: section.contentRevision,
        exerciseIds: [...section.exerciseIds, section.exerciseIds.first],
        requiredItemCount: section.requiredItemCount);
    final invalid = CourseCurriculum(
        courseId: frenchCurriculum.courseId,
        revision: frenchCurriculum.revision,
        nodes: frenchCurriculum.nodes,
        sections: [badSection],
        exercises: frenchCurriculum.exercises,
        sentences: frenchCurriculum.sentences,
        audioReferences: frenchCurriculum.audioReferences,
        phonemeCoverage: frenchCurriculum.phonemeCoverage);
    expect(
        validateLessonDebriefContent(invalid,
                lessonId: 'en-fr-u-y', notes: frenchPilotTeachingNotes)
            .map((d) => [d.code, d.recordId]),
        [
          ['source.invalid', 'en-fr-u-y']
        ]);
  });

  test(
      'selected catalogue alias and ownership ambiguity is rejected atomically',
      () {
    final exercises =
        frenchCurriculum.exercises.cast<ListeningChoiceExercise>();
    final first = exercises.first;
    final second = exercises[1];
    final cases = <CourseCurriculum>[
      _withExercises([
        ...exercises,
        _copyExercise(first),
      ]),
      _withExercises([
        _copyExercise(first),
        _copyExercise(second, legacyItemId: first.legacyItemId),
        ...exercises.skip(2),
      ]),
      _withExercises([
        _copyExercise(first, sectionId: 'wrong-owner'),
        ...exercises.skip(1),
      ]),
    ];

    for (final invalid in cases) {
      final diagnostics = validateLessonDebriefContent(invalid,
          lessonId: 'en-fr-u-y', notes: frenchPilotTeachingNotes);
      expect(diagnostics.map((d) => [d.code, d.recordId]), [
        ['source.invalid', 'en-fr-u-y'],
      ]);
      expect(
        () => LessonDebriefContent.fromCurriculum(invalid,
            lessonId: 'en-fr-u-y', notes: frenchPilotTeachingNotes),
        throwsA(isA<LessonTeachingValidationException>()),
      );
    }
  });

  test('opaque sound labels and multi-choice structure are supported', () {
    final curriculum = CourseCurriculum(
      courseId: 'synthetic',
      revision: 1,
      nodes: [
        CourseNode(
            id: 'synthetic-lesson',
            title: 'Synthetic',
            kind: CourseNodeKind.lesson,
            stage: CourseStage.hear,
            status: ContentStatus.authored,
            optional: false,
            prerequisiteIds: const [],
            sectionIds: const ['synthetic-section'],
            targetSounds: const ['consonant'])
      ],
      sections: [
        CourseSection(
            id: 'synthetic-section',
            nodeId: 'synthetic-lesson',
            title: 'Synthetic',
            explanation: 'Structural fixture',
            contentRevision: 7,
            exerciseIds: const ['synthetic-exercise'],
            requiredItemCount: 1)
      ],
      exercises: [
        ListeningChoiceExercise(
            id: 'synthetic-exercise',
            sectionId: 'synthetic-section',
            audioRefId: 'synthetic-audio',
            purpose: ContentPurpose.practice,
            reviewState: ContentReviewState.existingCurated,
            wordId: 'fixture',
            expectedSound: 'consonant',
            choices: const ['consonant', 'vowel', 'other'],
            legacyItemId: 'opaque-alias')
      ],
      sentences: const [],
      audioReferences: [
        CourseAudioReference(
            id: 'synthetic-audio',
            kind: AudioReferenceKind.word,
            spokenText: 'fixture')
      ],
      phonemeCoverage: const [],
    );
    final projected = LessonDebriefContent.fromCurriculum(curriculum,
        lessonId: 'synthetic-lesson',
        notes: const [
          LessonTeachingNote(
              sectionId: 'synthetic-section',
              exerciseId: 'synthetic-exercise',
              text: 'opaque label')
        ]);
    expect(projected.entries.single.itemId, 'opaque-alias');
    expect(projected.entries.single.text, 'opaque label');
    expect(projected.contentRevision, 7);
  });
}

CourseCurriculum _withExercises(List<ListeningChoiceExercise> exercises) =>
    CourseCurriculum(
      courseId: frenchCurriculum.courseId,
      revision: frenchCurriculum.revision,
      nodes: frenchCurriculum.nodes,
      sections: frenchCurriculum.sections,
      exercises: exercises,
      sentences: frenchCurriculum.sentences,
      audioReferences: frenchCurriculum.audioReferences,
      phonemeCoverage: frenchCurriculum.phonemeCoverage,
    );

ListeningChoiceExercise _copyExercise(ListeningChoiceExercise source,
        {String? legacyItemId, String? sectionId}) =>
    ListeningChoiceExercise(
      id: source.id,
      sectionId: sectionId ?? source.sectionId,
      audioRefId: source.audioRefId,
      purpose: source.purpose,
      reviewState: source.reviewState,
      wordId: source.wordId,
      expectedSound: source.expectedSound,
      choices: source.choices,
      legacyItemId: legacyItemId ?? source.legacyItemId,
    );
