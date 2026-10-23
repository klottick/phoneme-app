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

const _uyRows =
    <(String, String, String, String, String, PhonemeRelation, String)>[
      (
        'uy-demo-pair-01',
        'fr-word-tout',
        'u',
        'fr-word-tu',
        'y',
        PhonemeRelation.different,
        'The designated vowels are `/u/` in A and `/y/` in B; they differ.',
      ),
      (
        'uy-demo-pair-02',
        'fr-word-rouge',
        'u',
        'fr-word-vous',
        'u',
        PhonemeRelation.same,
        'Both designated vowels are `/u/`.',
      ),
      (
        'uy-demo-pair-03',
        'fr-word-soupe',
        'u',
        'fr-word-doux',
        'u',
        PhonemeRelation.same,
        'Both designated vowels are `/u/`.',
      ),
      (
        'uy-demo-pair-04',
        'fr-word-tu',
        'y',
        'fr-word-loup',
        'u',
        PhonemeRelation.different,
        'The designated vowels are `/y/` in A and `/u/` in B; they differ.',
      ),
      (
        'uy-demo-pair-05',
        'fr-word-rue',
        'y',
        'fr-word-lune',
        'y',
        PhonemeRelation.same,
        'Both designated vowels are `/y/`.',
      ),
      (
        'uy-demo-pair-06',
        'fr-word-jus',
        'y',
        'fr-word-tout',
        'u',
        PhonemeRelation.different,
        'The designated vowels are `/y/` in A and `/u/` in B; they differ.',
      ),
      (
        'uy-demo-pair-07',
        'fr-word-loup',
        'u',
        'fr-word-soupe',
        'u',
        PhonemeRelation.same,
        'Both designated vowels are `/u/`.',
      ),
      (
        'uy-demo-pair-08',
        'fr-word-tu',
        'y',
        'fr-word-jus',
        'y',
        PhonemeRelation.same,
        'Both designated vowels are `/y/`.',
      ),
      (
        'uy-demo-pair-09',
        'fr-word-doux',
        'u',
        'fr-word-lune',
        'y',
        PhonemeRelation.different,
        'The designated vowels are `/u/` in A and `/y/` in B; they differ.',
      ),
      (
        'uy-demo-pair-10',
        'fr-word-vous',
        'u',
        'fr-word-rue',
        'y',
        PhonemeRelation.different,
        'The designated vowels are `/u/` in A and `/y/` in B; they differ.',
      ),
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

ComparisonExerciseDraft _copyDraft(ComparisonExerciseDraft source,
        {ComparisonSampleDraft? sampleA,
        bool replaceSampleA = false,
        ComparisonSampleDraft? sampleB,
        bool replaceSampleB = false,
        ContentPurpose? purpose,
        bool replacePurpose = false,
        ContentReviewState? reviewState,
        bool replaceReviewState = false,
        PhonemeRelation? relation,
        String? note}) =>
    ComparisonExerciseDraft(
      id: source.id,
      activityId: source.activityId,
      sectionId: source.sectionId,
      contentRevision: source.contentRevision,
      purpose: replacePurpose ? purpose : source.purpose,
      reviewState: replaceReviewState ? reviewState : source.reviewState,
      instruction: source.instruction,
      sampleA: replaceSampleA ? sampleA : source.sampleA,
      sampleB: replaceSampleB ? sampleB : source.sampleB,
      expectedRelation: relation ?? source.expectedRelation,
      debriefNote: note ?? source.debriefNote,
    );

({List<ComparisonExerciseDraft> drafts, Map<String, List<String>> phonemes})
_uyValidationFixture() {
  final catalogue = loadFrenchUyDemoComparisonCatalogue();
  return (
    drafts: [
      for (final exercise in catalogue.exercises)
        ComparisonExerciseDraft(
          id: exercise.id,
          activityId: exercise.activityId,
          sectionId: exercise.sectionId,
          contentRevision: exercise.contentRevision,
          purpose: exercise.purpose,
          reviewState: exercise.reviewState,
          instruction: exercise.instruction,
          sampleA: ComparisonSampleDraft(
            slot: ComparisonSample.a,
            referenceId: exercise.sampleA.referenceId,
            target: ComparisonTargetDraft(
              phonemeId: exercise.sampleA.target.phonemeId,
              phonemeOrdinal: exercise.sampleA.target.phonemeOrdinal,
            ),
          ),
          sampleB: ComparisonSampleDraft(
            slot: ComparisonSample.b,
            referenceId: exercise.sampleB.referenceId,
            target: ComparisonTargetDraft(
              phonemeId: exercise.sampleB.target.phonemeId,
              phonemeOrdinal: exercise.sampleB.target.phonemeOrdinal,
            ),
          ),
          expectedRelation: exercise.expectedRelation,
          debriefNote: exercise.debriefNote,
        ),
    ],
    phonemes: {
      'fr-word-tout': ['t', 'u'],
      'fr-word-tu': ['t', 'y'],
      'fr-word-rouge': ['ʁ', 'u', 'ʒ'],
      'fr-word-vous': ['v', 'u'],
      'fr-word-soupe': ['s', 'u', 'p'],
      'fr-word-doux': ['d', 'u'],
      'fr-word-loup': ['l', 'u'],
      'fr-word-rue': ['ʁ', 'y'],
      'fr-word-lune': ['l', 'y', 'n'],
      'fr-word-jus': ['ʒ', 'y', 's'],
    },
  );
}

List<String> _uyValidationCodes(
  List<ComparisonExerciseDraft> drafts,
  Map<String, List<String>> phonemes,
) => validateComparisonCatalogue(
  activityId: uyDemoComparisonActivityId,
  sectionId: uyDemoComparisonActivityId,
  contentRevision: 1,
  exercises: drafts,
  referencePhonemes: phonemes,
).map((diagnostic) => diagnostic.code).toList();

void main() {
  test('uy_demo_catalogue_matches_spec_inventory_and_validates_ordinals', () {
    final catalogue = loadFrenchUyDemoComparisonCatalogue();
    expect(catalogue.activityId, uyDemoComparisonActivityId);
    expect(catalogue.sectionId, uyDemoComparisonActivityId);
    expect(catalogue.contentRevision, 1);
    expect(
      catalogue.exercises.map((e) => e.id),
      List.generate(
        10,
        (i) => 'uy-demo-pair-${(i + 1).toString().padLeft(2, '0')}',
      ),
    );
    expect(
      catalogue.exercises.map(
        (e) => (
          e.id,
          e.sampleA.referenceId,
          e.sampleA.target.phonemeId,
          e.sampleB.referenceId,
          e.sampleB.target.phonemeId,
          e.expectedRelation,
          e.debriefNote,
        ),
      ),
      _uyRows,
    );
    expect(
      catalogue.exercises.every(
        (e) =>
            e.sampleA.target.phonemeOrdinal == 1 &&
            e.sampleB.target.phonemeOrdinal == 1 &&
            e.purpose == ContentPurpose.practice &&
            e.reviewState == ContentReviewState.pending,
      ),
      isTrue,
    );
    expect(catalogue.exercises.map((e) => e.id).toSet(), hasLength(10));
    expect(
      catalogue.exercises.where(
        (e) => e.expectedRelation == PhonemeRelation.same,
      ),
      hasLength(5),
    );
    expect(
      catalogue.exercises.where(
        (e) => e.expectedRelation == PhonemeRelation.different,
      ),
      hasLength(5),
    );
  });

  test(
    'uy_demo_relation_key_mismatch_is_rejected_with_balanced_key_counts',
    () {
      final fixture = _uyValidationFixture();
      final drafts = [...fixture.drafts];
      drafts[0] = _copyDraft(drafts[0], relation: PhonemeRelation.same);
      drafts[1] = _copyDraft(drafts[1], relation: PhonemeRelation.different);

      expect(
        drafts.where((draft) => draft.expectedRelation == PhonemeRelation.same),
        hasLength(5),
      );
      expect(
        drafts.where(
          (draft) => draft.expectedRelation == PhonemeRelation.different,
        ),
        hasLength(5),
      );
      expect(_uyValidationCodes(drafts, fixture.phonemes), [
        'exercise.relation.mismatch',
        'exercise.relation.mismatch',
      ]);
    },
  );

  test('uy_demo_valid_relations_with_unbalanced_keys_report_balance_only', () {
    final fixture = _uyValidationFixture();
    final drafts = [...fixture.drafts];
    drafts[0] = _copyDraft(
      drafts[0],
      sampleB: const ComparisonSampleDraft(
        slot: ComparisonSample.b,
        referenceId: 'fr-word-vous',
        target: ComparisonTargetDraft(phonemeId: 'u', phonemeOrdinal: 1),
      ),
      replaceSampleB: true,
      relation: PhonemeRelation.same,
      note: 'Both designated vowels are `/u/`.',
    );

    expect(
      drafts.where((draft) => draft.expectedRelation == PhonemeRelation.same),
      hasLength(6),
    );
    expect(
      _uyValidationCodes(drafts, fixture.phonemes),
      ['catalogue.balance'],
    );
  });

  test(
    'uy_demo_invalid_reference_ordinal_target_duplicate_or_count_rejects_catalogue',
    () {
      final catalogue = loadFrenchUyDemoComparisonCatalogue();
      final phonemes = <String, List<String>>{
        'fr-word-tout': ['t', 'u'],
        'fr-word-tu': ['t', 'y'],
        'fr-word-rouge': ['ʁ', 'u', 'ʒ'],
        'fr-word-vous': ['v', 'u'],
        'fr-word-soupe': ['s', 'u', 'p'],
        'fr-word-doux': ['d', 'u'],
        'fr-word-loup': ['l', 'u'],
        'fr-word-rue': ['ʁ', 'y'],
        'fr-word-lune': ['l', 'y', 'n'],
        'fr-word-jus': ['ʒ', 'y', 's'],
      };
      List<ComparisonExerciseDraft> drafts() => [
        for (final e in catalogue.exercises)
          ComparisonExerciseDraft(
            id: e.id,
            activityId: e.activityId,
            sectionId: e.sectionId,
            contentRevision: e.contentRevision,
            purpose: e.purpose,
            reviewState: e.reviewState,
            instruction: e.instruction,
            sampleA: ComparisonSampleDraft(
              slot: ComparisonSample.a,
              referenceId: e.sampleA.referenceId,
              target: ComparisonTargetDraft(
                phonemeId: e.sampleA.target.phonemeId,
                phonemeOrdinal: e.sampleA.target.phonemeOrdinal,
              ),
            ),
            sampleB: ComparisonSampleDraft(
              slot: ComparisonSample.b,
              referenceId: e.sampleB.referenceId,
              target: ComparisonTargetDraft(
                phonemeId: e.sampleB.target.phonemeId,
                phonemeOrdinal: e.sampleB.target.phonemeOrdinal,
              ),
            ),
            expectedRelation: e.expectedRelation,
            debriefNote: e.debriefNote,
          ),
      ];
      void rejects(
        List<ComparisonExerciseDraft> rows, [
        Map<String, List<String>>? refs,
      ]) {
        expect(
          () => ComparisonCatalogue.fromDrafts(
            activityId: uyDemoComparisonActivityId,
            sectionId: uyDemoComparisonActivityId,
            contentRevision: 1,
            exercises: rows,
            referencePhonemes: refs ?? phonemes,
          ),
          throwsA(isA<ComparisonContentValidationException>()),
        );
      }

      var rows = drafts()
        ..[0] = const ComparisonExerciseDraft(
          id: 'uy-demo-pair-01',
          activityId: uyDemoComparisonActivityId,
          sectionId: uyDemoComparisonActivityId,
          contentRevision: 1,
          purpose: ContentPurpose.practice,
          reviewState: ContentReviewState.pending,
          instruction: 'Compare the vowel in each sample.',
          sampleA: ComparisonSampleDraft(
            slot: ComparisonSample.a,
            referenceId: 'missing',
            target: ComparisonTargetDraft(phonemeId: 'u', phonemeOrdinal: 1),
          ),
          sampleB: ComparisonSampleDraft(
            slot: ComparisonSample.b,
            referenceId: 'fr-word-tu',
            target: ComparisonTargetDraft(phonemeId: 'y', phonemeOrdinal: 1),
          ),
          expectedRelation: PhonemeRelation.different,
          debriefNote: 'note',
        );
      rejects(rows);
      rows = drafts()
        ..[0] = _copyDraft(
          drafts().first,
          sampleA: const ComparisonSampleDraft(
            slot: ComparisonSample.a,
            referenceId: 'fr-word-tout',
            target: ComparisonTargetDraft(phonemeId: 't', phonemeOrdinal: 1),
          ),
          replaceSampleA: true,
        );
      rejects(rows);
      rows = drafts()
        ..[0] = const ComparisonExerciseDraft(
          id: 'uy-demo-pair-01',
          activityId: uyDemoComparisonActivityId,
          sectionId: uyDemoComparisonActivityId,
          contentRevision: 1,
          purpose: ContentPurpose.practice,
          reviewState: ContentReviewState.pending,
          instruction: 'Compare the vowel in each sample.',
          sampleA: ComparisonSampleDraft(
            slot: ComparisonSample.a,
            referenceId: 'fr-word-tout',
            target: ComparisonTargetDraft(phonemeId: 'u', phonemeOrdinal: 9),
          ),
          sampleB: ComparisonSampleDraft(
            slot: ComparisonSample.b,
            referenceId: 'fr-word-tu',
            target: ComparisonTargetDraft(phonemeId: 'y', phonemeOrdinal: 1),
          ),
          expectedRelation: PhonemeRelation.different,
          debriefNote: 'note',
        );
      rejects(rows);
      rows = drafts()..[9] = drafts().first;
      rejects(rows);
      rejects(drafts().take(9).toList());
    },
  );


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

  test(
      'wrong phoneme identity at a valid ordinal is rejected independently for A and B',
      () {
    final validTen = List.generate(10, _draft);
    final cases = [
      (ComparisonSample.a, 'exercise.sampleA.target.phoneme'),
      (ComparisonSample.b, 'exercise.sampleB.target.phoneme'),
    ];
    for (final (slot, expectedCode) in cases) {
      final base = validTen.first;
      final original =
          slot == ComparisonSample.a ? base.sampleA! : base.sampleB!;
      final badTarget = ComparisonTargetDraft(
          phonemeId: 'not-the-source-phoneme',
          phonemeOrdinal: original.target!.phonemeOrdinal);
      final badSample = ComparisonSampleDraft(
          slot: slot, referenceId: original.referenceId, target: badTarget);
      final invalid = [...validTen]..[0] = _copyDraft(base,
          sampleA: badSample,
          replaceSampleA: slot == ComparisonSample.a,
          sampleB: badSample,
          replaceSampleB: slot == ComparisonSample.b);
      expect(_validate(invalid).map((d) => d.code), [expectedCode],
          reason: '$slot mismatch');
      expect(
          () => ComparisonCatalogue.fromDrafts(
              activityId: 'act',
              sectionId: 'sec',
              contentRevision: 1,
              exercises: invalid,
              referencePhonemes: _fixturePhonemes),
          throwsA(isA<ComparisonContentValidationException>()));
    }
  });

  test('missing targets suppress relation and balance and reject factory', () {
    final validTen = List.generate(10, _draft);
    for (final slot in ComparisonSample.values) {
      final base = validTen.first;
      final missing = ComparisonSampleDraft(
          slot: slot,
          referenceId: slot == ComparisonSample.a
              ? base.sampleA!.referenceId
              : base.sampleB!.referenceId,
          target: null);
      final invalid = [...validTen]..[0] = _copyDraft(base,
          sampleA: missing,
          replaceSampleA: slot == ComparisonSample.a,
          sampleB: missing,
          replaceSampleB: slot == ComparisonSample.b);
      expect(
          _validate(invalid).map((d) => d.code),
          [
            'exercise.sample${slot == ComparisonSample.a ? 'A' : 'B'}.target.missing'
          ],
          reason: '$slot target missing');
      expect(
          () => ComparisonCatalogue.fromDrafts(
              activityId: 'act',
              sectionId: 'sec',
              contentRevision: 1,
              exercises: invalid,
              referencePhonemes: _fixturePhonemes),
          throwsA(isA<ComparisonContentValidationException>()));
    }
  });

  test('null purpose and review state have their own diagnostics', () {
    final validTen = List.generate(10, _draft);
    final row = validTen.first;
    for (final (purpose, review, expected) in [
      (null, ContentReviewState.pending, 'exercise.purpose'),
      (ContentPurpose.practice, null, 'exercise.reviewState'),
    ]) {
      final invalid = [...validTen]..[0] = _copyDraft(row,
          purpose: purpose,
          replacePurpose: expected == 'exercise.purpose',
          reviewState: review,
          replaceReviewState: expected == 'exercise.reviewState');
      expect(_validate(invalid).map((d) => d.code), [expected]);
    }
  });

  test(
      'null and negative ordinals suppress relation and balance on both samples',
      () {
    final validTen = List.generate(10, _draft);
    for (final slot in ComparisonSample.values) {
      for (final ordinal in <int?>[null, -1]) {
        final base = validTen.first;
        final source =
            slot == ComparisonSample.a ? base.sampleA! : base.sampleB!;
        final invalidSample = ComparisonSampleDraft(
            slot: slot,
            referenceId: source.referenceId,
            target: ComparisonTargetDraft(
                phonemeId: source.target!.phonemeId, phonemeOrdinal: ordinal));
        final invalid = [...validTen]..[0] = _copyDraft(base,
            sampleA: invalidSample,
            replaceSampleA: slot == ComparisonSample.a,
            sampleB: invalidSample,
            replaceSampleB: slot == ComparisonSample.b);
        expect(
            _validate(invalid).map((d) => d.code),
            [
              'exercise.sample${slot == ComparisonSample.a ? 'A' : 'B'}.target.ordinal'
            ],
            reason: '$slot ordinal $ordinal');
      }
    }
  });

  test('relation mismatch is checked symmetrically for target A and B', () {
    final validTen = List.generate(10, _draft);
    for (final slot in ComparisonSample.values) {
      final base = validTen.first;
      const sameSourceTarget =
          ComparisonTargetDraft(phonemeId: 'x', phonemeOrdinal: 0);
      final invalidPair = _copyDraft(base,
          sampleA: ComparisonSampleDraft(
              slot: ComparisonSample.a,
              referenceId:
                  slot == ComparisonSample.a ? 'same-a' : 'different-a',
              target: slot == ComparisonSample.a
                  ? sameSourceTarget
                  : const ComparisonTargetDraft(
                      phonemeId: 'x', phonemeOrdinal: 0)),
          replaceSampleA: true,
          sampleB: ComparisonSampleDraft(
              slot: ComparisonSample.b,
              referenceId:
                  slot == ComparisonSample.b ? 'same-b' : 'different-b',
              target: slot == ComparisonSample.b
                  ? sameSourceTarget
                  : const ComparisonTargetDraft(
                      phonemeId: 'x', phonemeOrdinal: 0)),
          replaceSampleB: true);
      final invalid = [...validTen]..[0] = ComparisonExerciseDraft(
          id: invalidPair.id,
          activityId: invalidPair.activityId,
          sectionId: invalidPair.sectionId,
          contentRevision: invalidPair.contentRevision,
          purpose: invalidPair.purpose,
          reviewState: invalidPair.reviewState,
          instruction: invalidPair.instruction,
          sampleA: invalidPair.sampleA,
          sampleB: invalidPair.sampleB,
          expectedRelation: PhonemeRelation.different,
          debriefNote: invalidPair.debriefNote);
      final refs = {
        ..._fixturePhonemes,
        'same-a': ['x'],
        'same-b': ['x'],
        'different-a': ['x'],
        'different-b': ['x']
      };
      expect(
          validateComparisonCatalogue(
                  activityId: 'act',
                  sectionId: 'sec',
                  contentRevision: 1,
                  exercises: invalid,
                  referencePhonemes: refs)
              .map((d) => d.code),
          ['exercise.relation.mismatch'],
          reason: '$slot relation mismatch');
    }
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
