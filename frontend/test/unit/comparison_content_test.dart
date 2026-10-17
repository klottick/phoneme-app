import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';

const _phrases = <String>[
  'Compare the vowel in each sample.',
  'Compare the first consonant in each sample.',
  'Compare the vowel in each sample.',
  'Compare the first consonant in each sample.',
  'Compare the first consonant in each sample.',
  'Compare the vowel in each sample.',
  'Compare the vowel in each sample.',
  'Compare the vowel in each sample.',
  'Compare the first consonant in each sample.',
  'Compare the vowel in each sample.',
];
const _notes = <String>[
  'The vowel targets are `/u/` in A and `/y/` in B; the designated sounds differ.',
  'Both designated first consonants are `/ʁ/`.',
  'Both designated vowels are `/u/`.',
  'The designated first consonants are `/t/` and `/d/`; they differ.',
  'The designated first consonants are `/l/` and `/ʁ/`; they differ.',
  'Both designated vowels are `/y/`.',
  'The designated vowels are `/o/` and `/ɔ̃/`; they differ.',
  'Both designated vowels are `/i/`.',
  'Both designated first consonants are `/t/`.',
  'The designated vowels are `/y/` and `/u/`; they differ.',
];
const _targets = <(String, int, String, String, int, String)>[
  ('tout', 1, 'u', 'tu', 1, 'y'),
  ('rue', 0, 'ʁ', 'rouge', 0, 'ʁ'),
  ('tout', 1, 'u', 'vous', 1, 'u'),
  ('tu', 0, 't', 'doux', 0, 'd'),
  ('loup', 0, 'l', 'rue', 0, 'ʁ'),
  ('rue', 1, 'y', 'lune', 1, 'y'),
  ('beau', 1, 'o', 'bon', 1, 'ɔ̃'),
  ('lit', 1, 'i', 'vite', 1, 'i'),
  ('tu', 0, 't', 'tout', 0, 't'),
  ('mur', 1, 'y', 'rouge', 1, 'u'),
];
const _relations = <PhonemeRelation>[
  PhonemeRelation.different,
  PhonemeRelation.same,
  PhonemeRelation.same,
  PhonemeRelation.different,
  PhonemeRelation.different,
  PhonemeRelation.same,
  PhonemeRelation.different,
  PhonemeRelation.same,
  PhonemeRelation.same,
  PhonemeRelation.different,
];

ComparisonExerciseDraft _draft(
  int i, {
  String? id,
  String? activity,
  String? section,
  int? revision,
  ContentPurpose? purpose,
  ContentReviewState? review,
  String? instruction,
  ComparisonSampleDraft? a,
  ComparisonSampleDraft? b,
  PhonemeRelation? relation,
  String? note,
}) {
  final t = _targets[i];
  ComparisonSampleDraft sample(
          ComparisonSample slot, String word, int ordinal, String phoneme) =>
      ComparisonSampleDraft(
          slot: slot,
          referenceId: 'ref-$word',
          target: ComparisonTargetDraft(
              phonemeId: phoneme, phonemeOrdinal: ordinal));
  return ComparisonExerciseDraft(
      id: id ?? 'pair-$i',
      activityId: activity ?? 'act',
      sectionId: section ?? 'sec',
      contentRevision: revision ?? 1,
      purpose: purpose ?? ContentPurpose.practice,
      reviewState: review ?? ContentReviewState.pending,
      instruction: instruction ?? 'Compare targets.',
      sampleA: a ?? sample(ComparisonSample.a, t.$1, t.$2, t.$3),
      sampleB: b ?? sample(ComparisonSample.b, t.$4, t.$5, t.$6),
      expectedRelation: relation ?? _relations[i],
      debriefNote: note ?? 'Note $i');
}

final _fixturePhonemes = <String, List<String>>{
  'ref-tout': ['t', 'u'],
  'ref-tu': ['t', 'y'],
  'ref-rue': ['ʁ', 'y'],
  'ref-rouge': ['ʁ', 'u', 'ʒ'],
  'ref-vous': ['v', 'u'],
  'ref-doux': ['d', 'u'],
  'ref-loup': ['l', 'u'],
  'ref-lune': ['l', 'y', 'n'],
  'ref-beau': ['b', 'o'],
  'ref-bon': ['b', 'ɔ̃'],
  'ref-lit': ['l', 'i'],
  'ref-vite': ['v', 'i', 't'],
  'ref-mur': ['m', 'y', 'ʁ'],
};

List<ComparisonContentDiagnostic> _validate(List<ComparisonExerciseDraft> rows,
        {String activity = 'act', String section = 'sec', int revision = 1}) =>
    validateComparisonCatalogue(
        activityId: activity,
        sectionId: section,
        contentRevision: revision,
        exercises: rows,
        referencePhonemes: _fixturePhonemes);

void main() {
  test('french_comparison_inventory_matches_approved_spec', () {
    final catalogue = loadFrenchComparisonCatalogue();
    expect(catalogue.exercises.map((e) => e.id), [
      for (var i = 1; i <= 10; i++) 'fr07b-pair-${i.toString().padLeft(2, '0')}'
    ]);
    expect(catalogue.exercises.map((e) => e.expectedRelation), _relations);
    expect(
        catalogue.exercises.map((e) => [
              e.sampleA.referenceId,
              e.sampleA.target.phonemeOrdinal,
              e.sampleA.target.phonemeId,
              e.sampleB.referenceId,
              e.sampleB.target.phonemeOrdinal,
              e.sampleB.target.phonemeId
            ]),
        [
          for (final t in _targets)
            ['fr-word-${t.$1}', t.$2, t.$3, 'fr-word-${t.$4}', t.$5, t.$6]
        ]);
    expect(catalogue.exercises.map((e) => e.instruction), _phrases);
    expect(catalogue.exercises.map((e) => e.debriefNote), _notes);
    expect(catalogue.exercises.length, 10);
    expect(_relations.where((r) => r == PhonemeRelation.same).length, 5);
    expect(_relations.where((r) => r == PhonemeRelation.different).length, 5);
    expect(_targets.where((t) => t.$2 == 1 && t.$5 == 1).length, 6);
    expect(_targets.where((t) => t.$2 == 0 && t.$5 == 0).length, 4);
    expect(
        catalogue.exercises.expand((e) => [e.sampleA, e.sampleB]).length, 20);
    expect(
        catalogue.exercises
            .expand((e) => [e.sampleA.referenceId, e.sampleB.referenceId])
            .toSet()
            .length,
        13);
    expect(
        catalogue.exercises.every((e) =>
            e.sampleA.slot == ComparisonSample.a &&
            e.sampleB.slot == ComparisonSample.b &&
            e.purpose == ContentPurpose.practice &&
            e.reviewState == ContentReviewState.pending &&
            e.activityId == comparisonActivityId &&
            e.sectionId == comparisonActivityId &&
            e.contentRevision == 1),
        isTrue);
    expect(catalogue.notesFor(['fr07b-pair-03', 'fr07b-pair-01']),
        [_notes[0], _notes[2]]);
    expect(() => catalogue.notesFor(['fr07b-pair-01', 'fr07b-pair-01']),
        throwsArgumentError);
    expect(() => catalogue.notesFor(['not-known']), throwsArgumentError);
    expect(catalogue.exercise('fr07b-pair-01'),
        same(catalogue.byId['fr07b-pair-01']));
    expect(() => catalogue.exercises.clear(), throwsUnsupportedError);
    expect(() => catalogue.byId.clear(), throwsUnsupportedError);
    expect(() => catalogue.notesFor(['fr07b-pair-01']).clear(),
        throwsUnsupportedError);
  });

  test('comparison_catalogue_rejects_incomplete_duplicate_and_unknown_content',
      () {
    final ten = List.generate(10, _draft);
    final duplicate = [...ten]..[9] = _draft(9, id: 'pair-0');
    expect(_validate(duplicate).map((d) => d.code), ['exercise.id.duplicate']);
    final first = ten.first;
    final badSamples = [...ten]..[0] = ComparisonExerciseDraft(
        id: first.id,
        activityId: first.activityId,
        sectionId: first.sectionId,
        contentRevision: first.contentRevision,
        purpose: first.purpose,
        reviewState: first.reviewState,
        instruction: first.instruction,
        sampleA: null,
        sampleB: const ComparisonSampleDraft(
            slot: ComparisonSample.b,
            referenceId: 'unknown',
            target: ComparisonTargetDraft(phonemeId: 'u', phonemeOrdinal: 0)),
        expectedRelation: first.expectedRelation,
        debriefNote: ' ');
    expect(_validate(badSamples).map((d) => d.code), [
      'exercise.sampleA.missing',
      'exercise.sampleB.reference',
      'exercise.note'
    ]);
    expect(_validate(ten.take(9).toList()).map((d) => d.code),
        ['catalogue.count']);
    final mismatched = [...ten]
      ..[0] = _draft(0, relation: PhonemeRelation.same)
      ..[2] = _draft(2, relation: PhonemeRelation.different);
    expect(_validate(mismatched).map((d) => d.code),
        ['exercise.relation.mismatch', 'exercise.relation.mismatch']);
    final fourSix = [...ten];
    final row = ten[1];
    fourSix[1] = ComparisonExerciseDraft(
        id: row.id,
        activityId: row.activityId,
        sectionId: row.sectionId,
        contentRevision: row.contentRevision,
        purpose: row.purpose,
        reviewState: row.reviewState,
        instruction: row.instruction,
        sampleA: const ComparisonSampleDraft(
            slot: ComparisonSample.a,
            referenceId: 'custom-a',
            target: ComparisonTargetDraft(phonemeId: 'a', phonemeOrdinal: 0)),
        sampleB: const ComparisonSampleDraft(
            slot: ComparisonSample.b,
            referenceId: 'custom-b',
            target: ComparisonTargetDraft(phonemeId: 'b', phonemeOrdinal: 0)),
        expectedRelation: PhonemeRelation.different,
        debriefNote: row.debriefNote);
    final fourSixPhonemes = {
      ..._fixturePhonemes,
      'custom-a': ['a'],
      'custom-b': ['b']
    };
    expect(
        validateComparisonCatalogue(
                activityId: 'act',
                sectionId: 'sec',
                contentRevision: 1,
                exercises: fourSix,
                referencePhonemes: fourSixPhonemes)
            .map((d) => d.code),
        ['catalogue.balance']);
    expect(
        () => ComparisonCatalogue.fromDrafts(
            activityId: 'act',
            sectionId: 'sec',
            contentRevision: 1,
            exercises: badSamples,
            referencePhonemes: _fixturePhonemes),
        throwsA(isA<ComparisonContentValidationException>()));
  });

  test(
      'catalogue diagnostics validate required declarations and suppress dependent checks',
      () {
    final ten = List.generate(10, _draft);
    final first = ten.first;
    final invalid = [...ten]..[0] = ComparisonExerciseDraft(
        id: ' ',
        activityId: null,
        sectionId: ' ',
        contentRevision: null,
        purpose: ContentPurpose.assessment,
        reviewState: ContentReviewState.reviewed,
        instruction: ' ',
        sampleA: const ComparisonSampleDraft(
            slot: ComparisonSample.b,
            referenceId: 'ref-tout',
            target: ComparisonTargetDraft(phonemeId: '', phonemeOrdinal: 9)),
        sampleB: first.sampleB,
        expectedRelation: null,
        debriefNote: ' ');
    expect(_validate(invalid).map((d) => d.code), [
      'exercise.id.blank',
      'exercise.activity',
      'exercise.section',
      'exercise.revision',
      'exercise.purpose',
      'exercise.reviewState',
      'exercise.instruction',
      'exercise.sampleA.slot',
      'exercise.sampleA.target.phoneme',
      'exercise.sampleA.target.ordinal',
      'exercise.note',
      'exercise.relation.missing'
    ]);
    final wrongHeader = _validate([], activity: ' ', section: ' ', revision: 0);
    expect(wrongHeader.map((d) => d.code), [
      'catalogue.activity',
      'catalogue.section',
      'catalogue.revision',
      'catalogue.count'
    ]);
  });

  test('same phoneme identity across distinct references is valid', () {
    const row = ComparisonExerciseDraft(
        id: 'same-cross-ref',
        activityId: 'act',
        sectionId: 'sec',
        contentRevision: 1,
        purpose: ContentPurpose.practice,
        reviewState: ContentReviewState.pending,
        instruction: 'Compare.',
        sampleA: ComparisonSampleDraft(
            slot: ComparisonSample.a,
            referenceId: 'x-a',
            target: ComparisonTargetDraft(phonemeId: 'x', phonemeOrdinal: 0)),
        sampleB: ComparisonSampleDraft(
            slot: ComparisonSample.b,
            referenceId: 'x-b',
            target: ComparisonTargetDraft(phonemeId: 'x', phonemeOrdinal: 0)),
        expectedRelation: PhonemeRelation.same,
        debriefNote: 'Same.');
    expect(
        validateComparisonCatalogue(
            activityId: 'act',
            sectionId: 'sec',
            contentRevision: 1,
            exercises: [
              row
            ],
            referencePhonemes: {
              'x-a': ['x'],
              'x-b': ['x']
            }).map((d) => d.code),
        ['catalogue.count']);
  });

  test('validation exception detaches and protects diagnostics', () {
    final original = <ComparisonContentDiagnostic>[
      const ComparisonContentDiagnostic(code: 'bad', recordId: 'pair')
    ];
    final error = ComparisonContentValidationException(original);
    original.clear();
    expect(error.diagnostics.map((d) => d.code), ['bad']);
    expect(() => error.diagnostics.clear(), throwsUnsupportedError);
  });

  test('catalogue projections are detached and notes retain authored order',
      () {
    final input = List.generate(10, _draft);
    final catalogue = ComparisonCatalogue.fromDrafts(
        activityId: 'act',
        sectionId: 'sec',
        contentRevision: 1,
        exercises: input,
        referencePhonemes: _fixturePhonemes);
    input.clear();
    expect(catalogue.exercises.length, 10);
    expect(catalogue.notesFor(['pair-3', 'pair-1']), ['Note 1', 'Note 3']);
    expect(
        () => catalogue.notesFor(['pair-1', 'missing']), throwsArgumentError);
    expect(() => catalogue.notesFor(['pair-1', 'pair-1']), throwsArgumentError);
  });
}
