import 'package:flutter_test/flutter_test.dart';

import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/french_course.dart';

/// Test-only helper: FR-02 pending-review candidate manifest checks
/// evaluated against the current live Dart catalogue.
///
/// Used exclusively by tests. Production code under `frontend/lib/` must
/// never import this file.
///
/// Scope per the approved plan: the candidate root markers and coverage
/// identity (one entry per curated word in authored `frenchWords` order,
/// each carrying the declared word-audio reference's id, kind and
/// spokenText), the live-catalogue mapping (IPA, ordered unsplit phonemes,
/// teachingTargets as the inventory-ordered intersection, and the recorded
/// mapping origin), the exact repository-relative word-path identity, and
/// the spec-exact pending review/speaker/changes values. Invalid mutations
/// fail with `TestFailure`; nothing here is a runtime consumer or a
/// linguistic/platform approval.
void expectFrenchAudioCandidateParity(Map<String, dynamic> manifest) {
  // Candidate root markers. These are the offline candidate schema's
  // independent identity, never the app's persisted version or revision.
  expect(
    manifest['schemaVersion'],
    1,
    reason: 'candidate schemaVersion must be exactly 1',
  );
  expect(
    manifest['catalogueStatus'],
    'candidate',
    reason: 'the package catalogueStatus must stay "candidate"',
  );
  expect(manifest['language'], 'fr');

  expect(
    manifest['entries'],
    isA<List<dynamic>>(),
    reason: 'entries must be an ordered JSON list',
  );
  final List<dynamic> entries = manifest['entries']!;

  // Coverage identity: exact authored order and count of frenchWords.
  expect(
    entries.length,
    frenchWords.length,
    reason: 'one candidate entry per curated word, no omissions or extras',
  );

  // The declared word-audio references are authoritative for the
  // id/kind/spokenText identity of each entry, in the same order.
  final List<CourseAudioReference> references =
      frenchCurriculum.audioReferences;
  expect(
    references.length,
    frenchWords.length,
    reason: 'every curated word must have a declared word-audio reference',
  );

  // The teaching inventory is the live coverage inventory in its declared
  // order (u, y, i, o, ɔ̃, ɑ̃, ʁ); the helper never hardcodes it.
  final List<String> inventory = [
    for (final coverage in frenchCurriculum.phonemeCoverage) coverage.sound,
  ];

  for (var index = 0; index < frenchWords.length; index++) {
    final CourseWord word = frenchWords[index];
    final CourseAudioReference reference = references[index];

    expect(
      entries[index],
      isA<Map<String, dynamic>>(),
      reason: 'entry #$index must be a JSON object',
    );
    final Map<String, dynamic> record = entries[index] as Map<String, dynamic>;

    expect(
      record['id'],
      reference.id,
      reason: 'entry #$index id must match the declared reference '
          'for "${word.text}"',
    );
    expect(
      record['kind'],
      'word',
      reason: 'entry #$index kind must remain the declared word kind',
    );
    expect(
      record['spokenText'],
      reference.spokenText,
      reason: 'entry #$index spokenText must match the declared reference '
          'for "${word.text}"',
    );

    // Asset identity: the exact repository-relative path bound to this
    // word's own basename (Unicode preserved). This is an identity
    // decision, not a file-existence probe, so a stray "ile.wav" cannot
    // serve as an "île" asset.
    expect(
      record['assetPath'],
      'frontend/assets/audio/fr/words/${word.text}.wav',
      reason: 'entry "${word.text}" must bind exactly its own word basename',
    );

    // Mapping: the live catalogue is the independent oracle for expected
    // IPA, ordered unsplit phonemes, and the teaching-target intersection.
    expect(
      record['mapping'],
      isA<Map<String, dynamic>>(),
      reason: 'entry "${word.text}" must carry a mapping record',
    );
    final Map<String, dynamic> mapping =
        record['mapping']! as Map<String, dynamic>;
    expect(
      mapping['expectedIpa'],
      word.ipa,
      reason: 'entry "${word.text}" expectedIpa must exactly match the '
          'current CourseWord IPA string',
    );
    expect(
      mapping['phonemes'],
      word.sounds,
      reason: 'entry "${word.text}" phonemes must match its ordered '
          'sounds list without splitting nasal-vowel symbols',
    );
    expect(
      mapping['teachingTargets'],
      [
        for (final sound in inventory)
          if (word.sounds.contains(sound)) sound
      ],
      reason: 'entry "${word.text}" teachingTargets must be the inventory-'
          'ordered intersection, with no duplicates or reordering',
    );

    // Mapping origin: the recorded source of the lexical mapping.
    expect(
      mapping['origin'],
      isA<Map<String, dynamic>>(),
      reason: 'entry "${word.text}" mapping must record its origin',
    );
    final Map<String, dynamic> origin =
        mapping['origin'] as Map<String, dynamic>;
    expect(
      origin['path'],
      'frontend/lib/src/core/course/french_course.dart',
      reason: 'entry "${word.text}" origin.path must identify the catalogue '
          'file',
    );
    expect(
      origin['symbol'],
      'frenchWords',
      reason: 'entry "${word.text}" origin.symbol must identify '
          'frenchWords',
    );
    expect(
      origin['status'],
      'existingCuratedNotRecordingReviewed',
      reason: 'entry "${word.text}" origin.status must stay the pending '
          'candidate status',
    );
    expect(
      origin['revision'],
      matches(RegExp(r'^[0-9a-f]{40}$')),
      reason: 'entry "${word.text}" origin.revision must pin the full '
          'Git revision the mapping was read from',
    );

    // Speaker: the source name is preserved verbatim, and the pending
    // candidate never claims a qualification or accent.
    expect(
      record['speaker'],
      isA<Map<String, dynamic>>(),
      reason: 'entry "${word.text}" must carry a speaker record',
    );
    final Map<String, dynamic> speaker =
        record['speaker']! as Map<String, dynamic>;
    expect(
      speaker['sourceName'],
      'LoquaxFR',
      reason: 'entry "${word.text}" speaker.sourceName must stay the '
          'source-named speaker',
    );
    expect(
      speaker['qualificationStatus'],
      'unverified',
      reason: 'entry "${word.text}" must not claim speaker qualification',
    );
    expect(
      speaker['accent'],
      isNull,
      reason: 'entry "${word.text}" must not claim a speaker accent',
    );

    // The candidate stays pending: original bytes unchanged, and every
    // review/sign-off field exactly at its pending value.
    expect(
      record['changes'],
      isEmpty,
      reason: 'entry "${word.text}" changes must stay empty (original '
          'bytes unchanged)',
    );
    expect(
      record['review'],
      isA<Map<String, dynamic>>(),
      reason: 'entry "${word.text}" must carry a review record',
    );
    final Map<String, dynamic> review =
        record['review']! as Map<String, dynamic>;
    expect(
      review['status'],
      'pending',
      reason: 'entry "${word.text}" review.status must stay pending',
    );
    expect(
      review['reviewer'],
      isNull,
      reason: 'entry "${word.text}" review.reviewer must stay unset',
    );
    expect(
      review['reviewedAt'],
      isNull,
      reason: 'entry "${word.text}" review.reviewedAt must stay unset',
    );
    expect(
      review['evidence'],
      isEmpty,
      reason: 'entry "${word.text}" review.evidence must stay empty',
    );
  }
}
