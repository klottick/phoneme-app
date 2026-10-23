import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:linguist/src/core/course/course_audio_catalog.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/french_uy_demo_spelling_content.dart';

const _expectedRows =
    <(String, String, String, String, int, int, int, String, String)>[
      (
        'uy-demo-spelling-01',
        'tout',
        'fr-word-tout',
        'u',
        1,
        1,
        3,
        'ou',
        'In tout, ou represents the authored target /u/.',
      ),
      (
        'uy-demo-spelling-02',
        'tu',
        'fr-word-tu',
        'y',
        1,
        1,
        2,
        'u',
        'In tu, u represents the authored target /y/.',
      ),
      (
        'uy-demo-spelling-03',
        'rue',
        'fr-word-rue',
        'y',
        1,
        1,
        2,
        'u',
        'In rue, u represents the authored target /y/.',
      ),
      (
        'uy-demo-spelling-04',
        'rouge',
        'fr-word-rouge',
        'u',
        1,
        1,
        3,
        'ou',
        'In rouge, ou represents the authored target /u/.',
      ),
      (
        'uy-demo-spelling-05',
        'loup',
        'fr-word-loup',
        'u',
        1,
        1,
        3,
        'ou',
        'In loup, ou represents the authored target /u/.',
      ),
      (
        'uy-demo-spelling-06',
        'lune',
        'fr-word-lune',
        'y',
        1,
        1,
        2,
        'u',
        'In lune, u represents the authored target /y/.',
      ),
      (
        'uy-demo-spelling-07',
        'doux',
        'fr-word-doux',
        'u',
        1,
        1,
        3,
        'ou',
        'In doux, ou represents the authored target /u/.',
      ),
      (
        'uy-demo-spelling-08',
        'jus',
        'fr-word-jus',
        'y',
        1,
        1,
        2,
        'u',
        'In jus, u represents the authored target /y/.',
      ),
      (
        'uy-demo-spelling-09',
        'plume',
        'fr-word-plume',
        'y',
        2,
        2,
        3,
        'u',
        'In plume, u represents the authored target /y/.',
      ),
      (
        'uy-demo-spelling-10',
        'vous',
        'fr-word-vous',
        'u',
        1,
        1,
        3,
        'ou',
        'In vous, ou represents the authored target /u/.',
      ),
    ];

UyDemoSpellingRow _copyRow(
  UyDemoSpellingRow row, {
  String? id,
  String? sectionId,
  ContentPurpose? purpose,
  ContentReviewState? reviewState,
  String? wordId,
  String? audioRefId,
  String? targetSound,
  List<SpellingOption>? options,
  String? correctOptionId,
  int? targetOrdinal,
  int? graphemeStart,
  int? graphemeEnd,
  String? note,
}) {
  final exercise = row.exercise;
  return UyDemoSpellingRow(
    exercise: SpellingChoiceExercise(
      id: id ?? exercise.id,
      sectionId: sectionId ?? exercise.sectionId,
      audioRefId: audioRefId ?? exercise.audioRefId,
      purpose: purpose ?? exercise.purpose,
      reviewState: reviewState ?? exercise.reviewState,
      wordId: wordId ?? exercise.wordId,
      targetSound: targetSound ?? exercise.targetSound,
      options: options ?? exercise.options,
      correctOptionId: correctOptionId ?? exercise.correctOptionId,
    ),
    targetOrdinal: targetOrdinal ?? row.targetOrdinal,
    graphemeStart: graphemeStart ?? row.graphemeStart,
    graphemeEnd: graphemeEnd ?? row.graphemeEnd,
    note: note ?? row.note,
  );
}

FrenchUyDemoSpellingCatalogue _copyCatalogue(
  FrenchUyDemoSpellingCatalogue catalogue, {
  String? activityId,
  String? sectionId,
  int? contentRevision,
  List<UyDemoSpellingRow>? rows,
}) => FrenchUyDemoSpellingCatalogue(
  activityId: activityId ?? catalogue.activityId,
  sectionId: sectionId ?? catalogue.sectionId,
  contentRevision: contentRevision ?? catalogue.contentRevision,
  rows: rows ?? catalogue.rows,
);

void _expectInvalid(FrenchUyDemoSpellingCatalogue catalogue) {
  expect(
    () => validateFrenchUyDemoSpellingCatalogue(catalogue),
    throwsA(isA<FrenchUyDemoSpellingCatalogueValidationException>()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uy_demo_spelling_catalogue_matches_approved_inventory', () {
    final catalogue = loadFrenchUyDemoSpellingCatalogue();

    expect(catalogue.activityId, 'en-fr-u-y-spelling');
    expect(catalogue.sectionId, 'en-fr-u-y-spelling');
    expect(catalogue.contentRevision, 1);
    expect(uyDemoSpellingActivityId, 'en-fr-u-y-spelling');
    expect(uyDemoSpellingContentRevision, 1);
    expect(
      catalogue.rows.map((row) => row.exercise.id),
      _expectedRows.map((row) => row.$1),
    );
    expect(
      catalogue.rows.map(
        (row) => (
          row.exercise.id,
          row.exercise.wordId,
          row.exercise.audioRefId,
          row.exercise.targetSound,
          row.targetOrdinal,
          row.graphemeStart,
          row.graphemeEnd,
          row.exercise.correctOptionId,
          row.note,
        ),
      ),
      _expectedRows,
    );
    for (final row in catalogue.rows) {
      expect(row.exercise.sectionId, 'en-fr-u-y-spelling');
      expect(row.exercise.purpose, ContentPurpose.practice);
      expect(row.exercise.reviewState, ContentReviewState.pending);
      expect(row.exercise.options.map((option) => (option.id, option.text)), [
        ('u', 'u'),
        ('ou', 'ou'),
      ]);
    }
    expect(catalogue.rows.map((row) => row.exercise.id).toSet(), hasLength(10));
    expect(
      catalogue.rows.map((row) => row.exercise.audioRefId).toSet(),
      hasLength(10),
    );

    expect(catalogue.rows.first.exercise.wordId, 'tout');
    expect(catalogue.rows.first.exercise.correctOptionId, 'ou');
    expect(catalogue.rows.first.graphemeStart, 1);
    expect(catalogue.rows.first.graphemeEnd, 3);
    expect(catalogue.rows[8].exercise.wordId, 'plume');
    expect(catalogue.rows[8].targetOrdinal, 2);
  });

  test('malformed_row_rejects_complete_catalogue_without_fallback', () {
    final catalogue = loadFrenchUyDemoSpellingCatalogue();
    void rejectRows(List<UyDemoSpellingRow> rows) =>
        _expectInvalid(_copyCatalogue(catalogue, rows: rows));
    List<UyDemoSpellingRow> changed(int index, UyDemoSpellingRow row) =>
        [...catalogue.rows]..[index] = row;

    rejectRows(
      changed(
        1,
        _copyRow(catalogue.rows[1], id: catalogue.rows.first.exercise.id),
      ),
    );
    rejectRows(changed(1, _copyRow(catalogue.rows[1], id: 'missing-item')));
    rejectRows([...catalogue.rows, catalogue.rows.last]);
    rejectRows(
      changed(0, _copyRow(catalogue.rows.first, audioRefId: 'fr-word-tous')),
    );
    rejectRows(changed(8, _copyRow(catalogue.rows[8], targetOrdinal: 1)));
    rejectRows(changed(0, _copyRow(catalogue.rows.first, graphemeEnd: 99)));
    rejectRows(
      changed(
        0,
        _copyRow(catalogue.rows.first, graphemeStart: 1, graphemeEnd: 2),
      ),
    );
    rejectRows(
      changed(0, _copyRow(catalogue.rows.first, correctOptionId: 'u')),
    );
    rejectRows(changed(0, _copyRow(catalogue.rows.first, note: '  ')));
    rejectRows(
      changed(0, _copyRow(catalogue.rows.first, note: 'In tout, ou is /u/.')),
    );
    rejectRows(
      changed(0, _copyRow(catalogue.rows.first, sectionId: 'another-section')),
    );
    rejectRows(
      changed(
        0,
        _copyRow(catalogue.rows.first, purpose: ContentPurpose.assessment),
      ),
    );
    rejectRows(
      changed(
        0,
        _copyRow(
          catalogue.rows.first,
          reviewState: ContentReviewState.reviewed,
        ),
      ),
    );
    rejectRows(
      changed(
        0,
        _copyRow(
          catalogue.rows.first,
          options: catalogue.rows.first.exercise.options.reversed.toList(),
        ),
      ),
    );
    _expectInvalid(_copyCatalogue(catalogue, contentRevision: 2));

    final unbalanced = changed(
      0,
      _copyRow(
        catalogue.rows.first,
        correctOptionId: 'u',
        graphemeStart: 2,
        graphemeEnd: 3,
      ),
    );
    try {
      validateFrenchUyDemoSpellingCatalogue(
        _copyCatalogue(catalogue, rows: unbalanced),
      );
      fail('an unbalanced authored key distribution must be rejected');
    } on FrenchUyDemoSpellingCatalogueValidationException catch (error) {
      expect(error.violations, contains('catalogue.optionBalance'));
    }
  });

  test('valid_catalogue_is_detached_and_unmodifiable', () {
    final loaded = loadFrenchUyDemoSpellingCatalogue();
    final inputRows = [...loaded.rows];
    final catalogue = FrenchUyDemoSpellingCatalogue(
      activityId: loaded.activityId,
      sectionId: loaded.sectionId,
      contentRevision: loaded.contentRevision,
      rows: inputRows,
    );

    inputRows.clear();
    expect(catalogue.rows, hasLength(10));
    expect(() => catalogue.rows.clear(), throwsUnsupportedError);
    validateFrenchUyDemoSpellingCatalogue(catalogue);
  });

  test(
    'all_authored_word_references_have_covered_pending_recordings',
    () async {
      final catalogue = loadFrenchUyDemoSpellingCatalogue();
      final audioCatalogue = await CourseAudioCatalogLoader(
        bundle: rootBundle,
        references: frenchCurriculum.audioReferences,
      ).load();

      for (final row in catalogue.rows) {
        final reference = audioCatalogue.referenceById(row.exercise.audioRefId);
        expect(reference, isNotNull, reason: row.exercise.audioRefId);
        expect(reference!.kind, AudioReferenceKind.word);
        expect(reference.spokenText, row.exercise.wordId);
        final recording = audioCatalogue.recordingFor(
          row.exercise.audioRefId,
          CourseAudioVariant.normal,
        );
        expect(recording, isNotNull, reason: row.exercise.audioRefId);
        expect(recording!.source, CourseAudioSource.unverifiedRecording);
      }
    },
  );
}
