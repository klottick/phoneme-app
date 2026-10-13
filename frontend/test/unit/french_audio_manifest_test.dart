import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_content_validator.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/french_course.dart';

import '../support/french_audio_candidate_checks.dart';

Map<String, dynamic> _loadManifest() => jsonDecode(
      File('assets/audio/fr/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;

/// Clones the loaded real manifest through JSON encode/decode so every
/// mutation works on a copy and the original stays unchanged.
Map<String, dynamic> _clone(Map<String, dynamic> manifest) =>
    jsonDecode(jsonEncode(manifest)) as Map<String, dynamic>;

List<dynamic> _entriesOf(Map<String, dynamic> manifest) =>
    manifest['entries']! as List<dynamic>;

Map<String, dynamic> _entryOf(Map<String, dynamic> manifest, int index) =>
    _entriesOf(manifest)[index] as Map<String, dynamic>;

Map<String, dynamic> _mappingOf(Map<String, dynamic> manifest, int index) =>
    _entryOf(manifest, index)['mapping']! as Map<String, dynamic>;

Map<String, dynamic> _speakerOf(Map<String, dynamic> manifest, int index) =>
    _entryOf(manifest, index)['speaker']! as Map<String, dynamic>;

Map<String, dynamic> _reviewOf(Map<String, dynamic> manifest, int index) =>
    _entryOf(manifest, index)['review']! as Map<String, dynamic>;

/// Curated word index within `frenchWords` (and hence in entry order).
int _wordIndex(String text) =>
    frenchWords.indexWhere((word) => word.text == text);

/// One mutation subcase on a fresh clone of [manifest]: mutate exactly one
/// condition, then require the parity helper to reject the result with a
/// `TestFailure`.
void _expectsRejection(
  Map<String, dynamic> manifest,
  void Function(Map<String, dynamic> mutated) mutate,
) {
  final Map<String, dynamic> mutated = _clone(manifest);
  mutate(mutated);
  expect(
    () => expectFrenchAudioCandidateParity(mutated),
    throwsA(isA<TestFailure>()),
  );
}

void main() {
  group('FR-02 French word-audio candidates (pending review)', () {
    final Map<String, dynamic> manifest = _loadManifest();

    test('real candidate package matches the authored catalogue', () {
      expect(manifest['schemaVersion'], 1);
      expect(manifest['catalogueStatus'], 'candidate');
      expect(manifest['language'], 'fr');
      expectFrenchAudioCandidateParity(manifest);
    });

    test('rejects coverage and reference drift', () {
      // Omitted entry.
      _expectsRejection(manifest, (m) {
        _entriesOf(m).removeAt(0);
      });
      // Extra entry whose identity is not part of the curated catalogue.
      _expectsRejection(manifest, (m) {
        _entriesOf(m).add(<String, dynamic>{
          'id': 'fr-word-extra',
          'kind': 'word',
          'spokenText': 'extra',
        });
      });
      // Duplicate of the first entry.
      _expectsRejection(manifest, (m) {
        _entriesOf(m).add(Map.of(_entryOf(m, 0)));
      });
      // Reordered entries.
      _expectsRejection(manifest, (m) {
        final entries = _entriesOf(m);
        final first = entries[0];
        entries[0] = entries[1];
        entries[1] = first;
      });
      // Wrong spokenText.
      _expectsRejection(manifest, (m) {
        _entryOf(m, 0)['spokenText'] = 'toutt';
      });
      // Wrong kind.
      _expectsRejection(manifest, (m) {
        _entryOf(m, 0)['kind'] = 'sentence';
      });
      // Wrong id.
      _expectsRejection(manifest, (m) {
        _entryOf(m, 0)['id'] = 'fr-word-toutt';
      });
      // ASCII-normalised île.
      _expectsRejection(manifest, (m) {
        _entryOf(m, _wordIndex('île'))['spokenText'] = 'ile';
      });
      // Decomposed île: combining circumflex detached from its base letter.
      _expectsRejection(manifest, (m) {
        _entryOf(m, _wordIndex('île'))['spokenText'] = 'i\u0302le';
      });
    });

    test('rejects mapping drift', () {
      final bonIndex = _wordIndex('bon');
      final bancIndex = _wordIndex('banc');
      final murIndex = _wordIndex('mur');

      // Wrong expectedIpa.
      _expectsRejection(manifest, (m) {
        _mappingOf(m, 0)['expectedIpa'] = 'tœ';
      });
      // Reordered phonemes.
      _expectsRejection(manifest, (m) {
        _mappingOf(m, 0)['phonemes'] = <String>['u', 't'];
      });
      // Character-split ɔ̃ nasal-vowel symbol.
      _expectsRejection(manifest, (m) {
        _mappingOf(m, bonIndex)['phonemes'] = <String>['b', 'ɔ', '\u0303'];
      });
      // Character-split ɑ̃ nasal-vowel symbol.
      _expectsRejection(manifest, (m) {
        _mappingOf(m, bancIndex)['phonemes'] = <String>['b', 'ɑ', '\u0303'];
      });
      // Incorrect teachingTargets.
      _expectsRejection(manifest, (m) {
        _mappingOf(m, 0)['teachingTargets'] = <String>['y'];
      });
      // Duplicated teachingTargets.
      _expectsRejection(manifest, (m) {
        _mappingOf(m, 0)['teachingTargets'] = <String>['u', 'u'];
      });
      // Out-of-order teachingTargets.
      _expectsRejection(manifest, (m) {
        _mappingOf(m, murIndex)['teachingTargets'] = <String>['ʁ', 'y'];
      });
    });

    test('rejects candidate promotion', () {
      // Reviewed status.
      _expectsRejection(manifest, (m) {
        _reviewOf(m, 0)['status'] = 'reviewed';
      });
      // Invented reviewer.
      _expectsRejection(manifest, (m) {
        _reviewOf(m, 0)['reviewer'] = 'Invented Reviewer';
      });
      // Invented review date.
      _expectsRejection(manifest, (m) {
        _reviewOf(m, 0)['reviewedAt'] = '2026-10-13T00:00:00Z';
      });
      // Invented review evidence.
      _expectsRejection(manifest, (m) {
        _reviewOf(m, 0)['evidence'] = <String>['invented-evidence'];
      });
      // Speaker qualification claim.
      _expectsRejection(manifest, (m) {
        _speakerOf(m, 0)['qualificationStatus'] = 'verified';
      });
      // Speaker accent claim.
      _expectsRejection(manifest, (m) {
        _speakerOf(m, 0)['accent'] = 'france';
      });
      // Nonempty changes.
      _expectsRejection(manifest, (m) {
        _entryOf(m, 0)['changes'] = <String>['normalized'];
      });
    });

    test('rejects path identity drift', () {
      // Different word basename for the first entry.
      _expectsRejection(manifest, (m) {
        _entryOf(m, 0)['assetPath'] =
            'frontend/assets/audio/fr/words/toutt.wav';
      });
      // ASCII ile.wav for île: rejection is an identity decision, not a file
      // existence probe — no ile.wav is created for this mutation, and the
      // path must still be rejected even if one existed.
      _expectsRejection(manifest, (m) {
        _entryOf(m, _wordIndex('île'))['assetPath'] =
            'frontend/assets/audio/fr/words/ile.wav';
      });
    });

    test('candidate package leaves production readiness unchanged', () {
      // Reading the real package first: the candidate under review must still
      // be the pending package.
      expectFrenchAudioCandidateParity(manifest);

      // Every declared audio resource stays the practice-TTS fallback; no
      // candidate is promoted to a reviewed recording.
      expect(
        frenchAudioResources.length,
        frenchWords.length,
        reason: 'each curated word keeps its declared resource status',
      );
      expect(
        frenchAudioResources.values
            .every((status) => status == AudioResourceStatus.practiceTts),
        isTrue,
        reason: 'no pending candidate may be declared review-ready',
      );

      // Structure stays valid with exactly the 35 known readiness items.
      expect(frenchCurriculumValidation.errors, isEmpty);
      final readiness = frenchCurriculumValidation.readinessIssues;
      expect(readiness.length, 35);
      expect(
        readiness.where((issue) => issue.code == 'plannedNode').length,
        6,
      );
      expect(
        readiness.where((issue) => issue.code == 'plannedPhoneme').length,
        5,
      );
      final missingAudio = readiness
          .where((issue) => issue.code == 'missingReviewedAudio')
          .toList();
      expect(missingAudio.length, 24);
      expect(
        missingAudio.every((issue) => issue.use == ContentPurpose.assessment),
        isTrue,
        reason: 'all missing-audio readiness items remain assessment-scoped',
      );
      expect(
        missingAudio.map((issue) => issue.recordId).toList(),
        [
          for (final reference in frenchCurriculum.audioReferences) reference.id
        ],
        reason: 'exactly the actual word-audio reference IDs stay unserved',
      );

      // The curriculum revision does not move. The ten saved pilot IDs and
      // their order are pinned by the existing regression suite
      // (test/unit/lesson_section_curriculum_test.dart, "the production pilot
      // bridge stays unchanged and pilot-only") and re-run in the full
      // focused-suite pass rather than duplicated here.
      expect(frenchCurriculum.revision, 1);
    });
  });
}
