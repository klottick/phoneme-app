import 'course_exercise.dart';
import 'french_course.dart';

const String uyDemoSpellingActivityId = 'en-fr-u-y-spelling';
const int uyDemoSpellingContentRevision = 1;

typedef _AuthoredUyDemoSpellingRow = ({
  String id,
  String wordId,
  String audioRefId,
  String targetSound,
  int targetOrdinal,
  int graphemeStart,
  int graphemeEnd,
  String correctOptionId,
  String note,
});

const List<_AuthoredUyDemoSpellingRow> _authoredRows =
    <_AuthoredUyDemoSpellingRow>[
      (
        id: 'uy-demo-spelling-01',
        wordId: 'tout',
        audioRefId: 'fr-word-tout',
        targetSound: 'u',
        targetOrdinal: 1,
        graphemeStart: 1,
        graphemeEnd: 3,
        correctOptionId: 'ou',
        note: 'In tout, ou represents the authored target /u/.',
      ),
      (
        id: 'uy-demo-spelling-02',
        wordId: 'tu',
        audioRefId: 'fr-word-tu',
        targetSound: 'y',
        targetOrdinal: 1,
        graphemeStart: 1,
        graphemeEnd: 2,
        correctOptionId: 'u',
        note: 'In tu, u represents the authored target /y/.',
      ),
      (
        id: 'uy-demo-spelling-03',
        wordId: 'rue',
        audioRefId: 'fr-word-rue',
        targetSound: 'y',
        targetOrdinal: 1,
        graphemeStart: 1,
        graphemeEnd: 2,
        correctOptionId: 'u',
        note: 'In rue, u represents the authored target /y/.',
      ),
      (
        id: 'uy-demo-spelling-04',
        wordId: 'rouge',
        audioRefId: 'fr-word-rouge',
        targetSound: 'u',
        targetOrdinal: 1,
        graphemeStart: 1,
        graphemeEnd: 3,
        correctOptionId: 'ou',
        note: 'In rouge, ou represents the authored target /u/.',
      ),
      (
        id: 'uy-demo-spelling-05',
        wordId: 'loup',
        audioRefId: 'fr-word-loup',
        targetSound: 'u',
        targetOrdinal: 1,
        graphemeStart: 1,
        graphemeEnd: 3,
        correctOptionId: 'ou',
        note: 'In loup, ou represents the authored target /u/.',
      ),
      (
        id: 'uy-demo-spelling-06',
        wordId: 'lune',
        audioRefId: 'fr-word-lune',
        targetSound: 'y',
        targetOrdinal: 1,
        graphemeStart: 1,
        graphemeEnd: 2,
        correctOptionId: 'u',
        note: 'In lune, u represents the authored target /y/.',
      ),
      (
        id: 'uy-demo-spelling-07',
        wordId: 'doux',
        audioRefId: 'fr-word-doux',
        targetSound: 'u',
        targetOrdinal: 1,
        graphemeStart: 1,
        graphemeEnd: 3,
        correctOptionId: 'ou',
        note: 'In doux, ou represents the authored target /u/.',
      ),
      (
        id: 'uy-demo-spelling-08',
        wordId: 'jus',
        audioRefId: 'fr-word-jus',
        targetSound: 'y',
        targetOrdinal: 1,
        graphemeStart: 1,
        graphemeEnd: 2,
        correctOptionId: 'u',
        note: 'In jus, u represents the authored target /y/.',
      ),
      (
        id: 'uy-demo-spelling-09',
        wordId: 'plume',
        audioRefId: 'fr-word-plume',
        targetSound: 'y',
        targetOrdinal: 2,
        graphemeStart: 2,
        graphemeEnd: 3,
        correctOptionId: 'u',
        note: 'In plume, u represents the authored target /y/.',
      ),
      (
        id: 'uy-demo-spelling-10',
        wordId: 'vous',
        audioRefId: 'fr-word-vous',
        targetSound: 'u',
        targetOrdinal: 1,
        graphemeStart: 1,
        graphemeEnd: 3,
        correctOptionId: 'ou',
        note: 'In vous, ou represents the authored target /u/.',
      ),
    ];

/// One spelling exercise plus its authored target position and note.
///
/// The exercise and its option collection are immutable. Validation of the
/// relationships between these values belongs to
/// [validateFrenchUyDemoSpellingCatalogue].
final class UyDemoSpellingRow {
  const UyDemoSpellingRow({
    required this.exercise,
    required this.targetOrdinal,
    required this.graphemeStart,
    required this.graphemeEnd,
    required this.note,
  });

  final SpellingChoiceExercise exercise;
  final int targetOrdinal;
  final int graphemeStart;
  final int graphemeEnd;
  final String note;
}

/// An immutable ordered collection of authored U/Y spelling rows.
final class FrenchUyDemoSpellingCatalogue {
  FrenchUyDemoSpellingCatalogue({
    required this.activityId,
    required this.sectionId,
    required this.contentRevision,
    required List<UyDemoSpellingRow> rows,
  }) : rows = List<UyDemoSpellingRow>.unmodifiable(rows);

  final String activityId;
  final String sectionId;
  final int contentRevision;
  final List<UyDemoSpellingRow> rows;
}

/// A whole-catalogue validation failure. [violations] is detached and ordered.
final class FrenchUyDemoSpellingCatalogueValidationException
    implements Exception {
  FrenchUyDemoSpellingCatalogueValidationException(List<String> violations)
    : violations = List<String>.unmodifiable(violations);

  final List<String> violations;

  @override
  String toString() =>
      'FrenchUyDemoSpellingCatalogueValidationException($violations)';
}

/// Returns the complete authored spelling catalogue after validating it.
FrenchUyDemoSpellingCatalogue loadFrenchUyDemoSpellingCatalogue() {
  final catalogue = FrenchUyDemoSpellingCatalogue(
    activityId: uyDemoSpellingActivityId,
    sectionId: uyDemoSpellingActivityId,
    contentRevision: uyDemoSpellingContentRevision,
    rows: <UyDemoSpellingRow>[
      for (final row in _authoredRows)
        UyDemoSpellingRow(
          exercise: SpellingChoiceExercise(
            id: row.id,
            sectionId: uyDemoSpellingActivityId,
            audioRefId: row.audioRefId,
            purpose: ContentPurpose.practice,
            reviewState: ContentReviewState.pending,
            wordId: row.wordId,
            targetSound: row.targetSound,
            options: <SpellingOption>[
              SpellingOption(id: 'u', text: 'u'),
              SpellingOption(id: 'ou', text: 'ou'),
            ],
            correctOptionId: row.correctOptionId,
          ),
          targetOrdinal: row.targetOrdinal,
          graphemeStart: row.graphemeStart,
          graphemeEnd: row.graphemeEnd,
          note: row.note,
        ),
    ],
  );
  validateFrenchUyDemoSpellingCatalogue(catalogue);
  return catalogue;
}

/// Validates the entire catalogue against the approved literal inventory.
///
/// Throws [FrenchUyDemoSpellingCatalogueValidationException] on any mismatch;
/// it never reorders, repairs, or returns a partial catalogue.
void validateFrenchUyDemoSpellingCatalogue(
  FrenchUyDemoSpellingCatalogue catalogue,
) {
  final violations = <String>[];
  void reject(String code) => violations.add(code);

  if (catalogue.activityId != uyDemoSpellingActivityId) {
    reject('catalogue.activityId');
  }
  if (catalogue.sectionId != uyDemoSpellingActivityId) {
    reject('catalogue.sectionId');
  }
  if (catalogue.contentRevision != uyDemoSpellingContentRevision) {
    reject('catalogue.contentRevision');
  }
  if (catalogue.rows.length != _authoredRows.length) {
    reject('catalogue.rowCount');
  }

  final seenIds = <String>{};
  var uKeyCount = 0;
  var ouKeyCount = 0;
  for (var index = 0; index < catalogue.rows.length; index++) {
    final row = catalogue.rows[index];
    final exercise = row.exercise;
    final id = exercise.id;
    if (!seenIds.add(id)) reject('row.$index.id.duplicate');
    if (exercise.correctOptionId == 'u') uKeyCount++;
    if (exercise.correctOptionId == 'ou') ouKeyCount++;

    if (index >= _authoredRows.length) {
      reject('row.$index.unexpected');
      continue;
    }
    final expected = _authoredRows[index];

    if (id != expected.id) reject('row.$index.id');
    if (exercise.sectionId != uyDemoSpellingActivityId) {
      reject('row.$index.sectionId');
    }
    if (exercise.purpose != ContentPurpose.practice) {
      reject('row.$index.purpose');
    }
    if (exercise.reviewState != ContentReviewState.pending) {
      reject('row.$index.reviewState');
    }
    if (exercise.wordId != expected.wordId) reject('row.$index.wordId');
    if (!frenchWords.any((word) => word.text == expected.wordId)) {
      reject('row.$index.word.missing');
    }

    if (exercise.audioRefId != expected.audioRefId) {
      reject('row.$index.audioRefId');
    }
    final matchingReferences = frenchCurriculum.audioReferences
        .where((reference) => reference.id == expected.audioRefId)
        .toList();
    if (matchingReferences.length != 1 ||
        matchingReferences.single.kind != AudioReferenceKind.word ||
        matchingReferences.single.spokenText != expected.wordId) {
      reject('row.$index.audioReference');
    }

    if (exercise.targetSound != expected.targetSound) {
      reject('row.$index.targetSound');
    }
    if (row.targetOrdinal != expected.targetOrdinal) {
      reject('row.$index.targetOrdinal');
    }
    final citationPhonemes = frenchCitationPhonemes[expected.wordId];
    if (citationPhonemes == null ||
        row.targetOrdinal < 0 ||
        row.targetOrdinal >= citationPhonemes.length ||
        citationPhonemes[row.targetOrdinal] != expected.targetSound) {
      reject('row.$index.citationTarget');
    }

    final options = exercise.options;
    if (options.length != 2 ||
        options[0].id != 'u' ||
        options[0].text != 'u' ||
        options[1].id != 'ou' ||
        options[1].text != 'ou') {
      reject('row.$index.options');
    }
    if (exercise.correctOptionId != expected.correctOptionId) {
      reject('row.$index.correctOptionId');
    }
    final matchingKeys = options
        .where((option) => option.id == exercise.correctOptionId)
        .toList();
    if (matchingKeys.length != 1) reject('row.$index.correctOptionMissing');

    if (row.graphemeStart != expected.graphemeStart ||
        row.graphemeEnd != expected.graphemeEnd) {
      reject('row.$index.graphemeRange');
    }
    final word = exercise.wordId;
    if (row.graphemeStart < 0 ||
        row.graphemeEnd <= row.graphemeStart ||
        row.graphemeEnd > word.length) {
      reject('row.$index.graphemeBounds');
    } else if (matchingKeys.length == 1 &&
        word.substring(row.graphemeStart, row.graphemeEnd) !=
            matchingKeys.single.text) {
      reject('row.$index.graphemeText');
    }

    if (row.note.trim().isEmpty) reject('row.$index.note.blank');
    if (row.note != expected.note) reject('row.$index.note');
  }

  if (uKeyCount != 5 || ouKeyCount != 5) {
    reject('catalogue.optionBalance');
  }
  if (violations.isNotEmpty) {
    throw FrenchUyDemoSpellingCatalogueValidationException(violations);
  }
}
