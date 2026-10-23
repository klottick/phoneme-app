import 'comparison_content.dart';
import 'course_exercise.dart';
import 'french_course.dart';

Map<String, List<String>> _frenchWordReferencePhonemes() {
  final referencePhonemes = <String, List<String>>{};
  for (final reference in frenchCurriculum.audioReferences) {
    if (!reference.id.startsWith('fr-word-')) continue;
    final wordText = reference.id.substring('fr-word-'.length);
    if (reference.spokenText != wordText) continue;
    final phonemes = frenchCitationPhonemes[wordText];
    if (phonemes != null) referencePhonemes[reference.id] = phonemes;
  }
  return referencePhonemes;
}

ComparisonCatalogue loadFrenchComparisonCatalogue() {
  final referencePhonemes = _frenchWordReferencePhonemes();

  const rows = <({
    String id,
    String wordA,
    int ordinalA,
    String phonemeA,
    String wordB,
    int ordinalB,
    String phonemeB,
    String instruction,
    String note,
    PhonemeRelation relation
  })>[
    (
      id: 'fr07b-pair-01',
      wordA: 'tout',
      ordinalA: 1,
      phonemeA: 'u',
      wordB: 'tu',
      ordinalB: 1,
      phonemeB: 'y',
      instruction: 'Compare the vowel in each sample.',
      relation: PhonemeRelation.different,
      note:
          'The vowel targets are `/u/` in A and `/y/` in B; the designated sounds differ.'
    ),
    (
      id: 'fr07b-pair-02',
      wordA: 'rue',
      ordinalA: 0,
      phonemeA: 'ʁ',
      wordB: 'rouge',
      ordinalB: 0,
      phonemeB: 'ʁ',
      instruction: 'Compare the first consonant in each sample.',
      relation: PhonemeRelation.same,
      note: 'Both designated first consonants are `/ʁ/`.'
    ),
    (
      id: 'fr07b-pair-03',
      wordA: 'tout',
      ordinalA: 1,
      phonemeA: 'u',
      wordB: 'vous',
      ordinalB: 1,
      phonemeB: 'u',
      instruction: 'Compare the vowel in each sample.',
      relation: PhonemeRelation.same,
      note: 'Both designated vowels are `/u/`.'
    ),
    (
      id: 'fr07b-pair-04',
      wordA: 'tu',
      ordinalA: 0,
      phonemeA: 't',
      wordB: 'doux',
      ordinalB: 0,
      phonemeB: 'd',
      instruction: 'Compare the first consonant in each sample.',
      relation: PhonemeRelation.different,
      note: 'The designated first consonants are `/t/` and `/d/`; they differ.'
    ),
    (
      id: 'fr07b-pair-05',
      wordA: 'loup',
      ordinalA: 0,
      phonemeA: 'l',
      wordB: 'rue',
      ordinalB: 0,
      phonemeB: 'ʁ',
      instruction: 'Compare the first consonant in each sample.',
      relation: PhonemeRelation.different,
      note: 'The designated first consonants are `/l/` and `/ʁ/`; they differ.'
    ),
    (
      id: 'fr07b-pair-06',
      wordA: 'rue',
      ordinalA: 1,
      phonemeA: 'y',
      wordB: 'lune',
      ordinalB: 1,
      phonemeB: 'y',
      instruction: 'Compare the vowel in each sample.',
      relation: PhonemeRelation.same,
      note: 'Both designated vowels are `/y/`.'
    ),
    (
      id: 'fr07b-pair-07',
      wordA: 'beau',
      ordinalA: 1,
      phonemeA: 'o',
      wordB: 'bon',
      ordinalB: 1,
      phonemeB: 'ɔ̃',
      instruction: 'Compare the vowel in each sample.',
      relation: PhonemeRelation.different,
      note: 'The designated vowels are `/o/` and `/ɔ̃/`; they differ.'
    ),
    (
      id: 'fr07b-pair-08',
      wordA: 'lit',
      ordinalA: 1,
      phonemeA: 'i',
      wordB: 'vite',
      ordinalB: 1,
      phonemeB: 'i',
      instruction: 'Compare the vowel in each sample.',
      relation: PhonemeRelation.same,
      note: 'Both designated vowels are `/i/`.'
    ),
    (
      id: 'fr07b-pair-09',
      wordA: 'tu',
      ordinalA: 0,
      phonemeA: 't',
      wordB: 'tout',
      ordinalB: 0,
      phonemeB: 't',
      instruction: 'Compare the first consonant in each sample.',
      relation: PhonemeRelation.same,
      note: 'Both designated first consonants are `/t/`.'
    ),
    (
      id: 'fr07b-pair-10',
      wordA: 'mur',
      ordinalA: 1,
      phonemeA: 'y',
      wordB: 'rouge',
      ordinalB: 1,
      phonemeB: 'u',
      instruction: 'Compare the vowel in each sample.',
      relation: PhonemeRelation.different,
      note: 'The designated vowels are `/y/` and `/u/`; they differ.'
    ),
  ];
  final drafts = [
    for (final row in rows)
      ComparisonExerciseDraft(
        id: row.id,
        activityId: comparisonActivityId,
        sectionId: comparisonActivityId,
        contentRevision: 1,
        purpose: ContentPurpose.practice,
        reviewState: ContentReviewState.pending,
        instruction: row.instruction,
        sampleA: ComparisonSampleDraft(
            slot: ComparisonSample.a,
            referenceId: 'fr-word-${row.wordA}',
            target: ComparisonTargetDraft(
                phonemeId: row.phonemeA, phonemeOrdinal: row.ordinalA)),
        sampleB: ComparisonSampleDraft(
            slot: ComparisonSample.b,
            referenceId: 'fr-word-${row.wordB}',
            target: ComparisonTargetDraft(
                phonemeId: row.phonemeB, phonemeOrdinal: row.ordinalB)),
        expectedRelation: row.relation,
        debriefNote: row.note,
      )
  ];
  return ComparisonCatalogue.fromDrafts(
    activityId: comparisonActivityId,
    sectionId: comparisonActivityId,
    contentRevision: 1,
    exercises: drafts,
    referencePhonemes: referencePhonemes,
  );
}
ComparisonCatalogue loadFrenchUyDemoComparisonCatalogue() {
  final referencePhonemes = _frenchWordReferencePhonemes();

  const rows =
      <
        ({
          String id,
          String wordA,
          String phonemeA,
          String wordB,
          String phonemeB,
          PhonemeRelation relation,
          String note,
        })
      >[
        (
          id: 'uy-demo-pair-01',
          wordA: 'tout',
          phonemeA: 'u',
          wordB: 'tu',
          phonemeB: 'y',
          relation: PhonemeRelation.different,
          note:
              'The designated vowels are `/u/` in A and `/y/` in B; they differ.',
        ),
        (
          id: 'uy-demo-pair-02',
          wordA: 'rouge',
          phonemeA: 'u',
          wordB: 'vous',
          phonemeB: 'u',
          relation: PhonemeRelation.same,
          note: 'Both designated vowels are `/u/`.',
        ),
        (
          id: 'uy-demo-pair-03',
          wordA: 'soupe',
          phonemeA: 'u',
          wordB: 'doux',
          phonemeB: 'u',
          relation: PhonemeRelation.same,
          note: 'Both designated vowels are `/u/`.',
        ),
        (
          id: 'uy-demo-pair-04',
          wordA: 'tu',
          phonemeA: 'y',
          wordB: 'loup',
          phonemeB: 'u',
          relation: PhonemeRelation.different,
          note:
              'The designated vowels are `/y/` in A and `/u/` in B; they differ.',
        ),
        (
          id: 'uy-demo-pair-05',
          wordA: 'rue',
          phonemeA: 'y',
          wordB: 'lune',
          phonemeB: 'y',
          relation: PhonemeRelation.same,
          note: 'Both designated vowels are `/y/`.',
        ),
        (
          id: 'uy-demo-pair-06',
          wordA: 'jus',
          phonemeA: 'y',
          wordB: 'tout',
          phonemeB: 'u',
          relation: PhonemeRelation.different,
          note:
              'The designated vowels are `/y/` in A and `/u/` in B; they differ.',
        ),
        (
          id: 'uy-demo-pair-07',
          wordA: 'loup',
          phonemeA: 'u',
          wordB: 'soupe',
          phonemeB: 'u',
          relation: PhonemeRelation.same,
          note: 'Both designated vowels are `/u/`.',
        ),
        (
          id: 'uy-demo-pair-08',
          wordA: 'tu',
          phonemeA: 'y',
          wordB: 'jus',
          phonemeB: 'y',
          relation: PhonemeRelation.same,
          note: 'Both designated vowels are `/y/`.',
        ),
        (
          id: 'uy-demo-pair-09',
          wordA: 'doux',
          phonemeA: 'u',
          wordB: 'lune',
          phonemeB: 'y',
          relation: PhonemeRelation.different,
          note:
              'The designated vowels are `/u/` in A and `/y/` in B; they differ.',
        ),
        (
          id: 'uy-demo-pair-10',
          wordA: 'vous',
          phonemeA: 'u',
          wordB: 'rue',
          phonemeB: 'y',
          relation: PhonemeRelation.different,
          note:
              'The designated vowels are `/u/` in A and `/y/` in B; they differ.',
        ),
      ];
  final drafts = [
    for (final row in rows)
      ComparisonExerciseDraft(
        id: row.id,
        activityId: uyDemoComparisonActivityId,
        sectionId: uyDemoComparisonActivityId,
        contentRevision: 1,
        purpose: ContentPurpose.practice,
        reviewState: ContentReviewState.pending,
        instruction: 'Compare the vowel in each sample.',
        sampleA: ComparisonSampleDraft(
          slot: ComparisonSample.a,
          referenceId: 'fr-word-${row.wordA}',
          target: ComparisonTargetDraft(
            phonemeId: row.phonemeA,
            phonemeOrdinal: 1,
          ),
        ),
        sampleB: ComparisonSampleDraft(
          slot: ComparisonSample.b,
          referenceId: 'fr-word-${row.wordB}',
          target: ComparisonTargetDraft(
            phonemeId: row.phonemeB,
            phonemeOrdinal: 1,
          ),
        ),
        expectedRelation: row.relation,
        debriefNote: row.note,
      ),
  ];
  return ComparisonCatalogue.fromDrafts(
    activityId: uyDemoComparisonActivityId,
    sectionId: uyDemoComparisonActivityId,
    contentRevision: 1,
    exercises: drafts,
    referencePhonemes: referencePhonemes,
  );
}
