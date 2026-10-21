import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/learning_storage_types.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';

import '../support/sentence_hunt_fixtures.dart';

void main() {
  test('sentence_hunt_command_byte_geometry_probe', () {
    const String packagePath = 'assets/audio/fr-sentences';
    final SentenceHuntCatalogue pending = decodeFrenchSentencePackage(
      manifestJson: File('$packagePath/manifest.json').readAsStringSync(),
      provenanceJson: File('$packagePath/provenance.json').readAsStringSync(),
      annotationsJson: File('$packagePath/annotations.json').readAsStringSync(),
      sourceEvidenceJson: File(
        '$packagePath/source-evidence.json',
      ).readAsStringSync(),
    );
    final SentenceHuntCatalogue synthetic = syntheticSentenceCatalogue();
    const int largeGeometryWords = 13;
    final SentenceHuntCatalogue largeSynthetic = syntheticSentenceCatalogue(
      wordsPerSentence: largeGeometryWords,
    );
    expect(pending.hasValidRoot, isTrue);
    expect(
      pending.sections.every(
        (SentenceHuntSection section) => !pending.isAvailable(section.id),
      ),
      isTrue,
    );
    final int largestPendingFingerprintBytes = pending.sections
        .map(
          (SentenceHuntSection section) =>
              utf8.encode(section.sectionFingerprint).length,
        )
        .reduce((int a, int b) => a > b ? a : b);
    final List<SentenceHuntItem> pendingItems = pending.sections
        .expand((SentenceHuntSection section) => section.items)
        .toList(growable: false);
    final int largestPendingTextBytes = pendingItems
        .map((SentenceHuntItem item) => utf8.encode(item.sentence.text).length)
        .reduce((int a, int b) => a > b ? a : b);
    final int largestPendingTokenCount = pendingItems
        .map((SentenceHuntItem item) => item.sentence.tokens.length)
        .reduce((int a, int b) => a > b ? a : b);
    final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    String canonicalAdvance(String sectionId, String fingerprint) =>
        sentenceHuntCanonicalCommand(
          SentenceHuntLearningCommand(
            scope: scope,
            authGeneration: 0,
            sectionId: sectionId,
            sectionFingerprint: fingerprint,
            expected: const LearningCursorPosition(
              generation: 0,
              sequence: 0,
              revision: 0,
            ),
            expectedScopeRevision: 0,
            token: '0000000000000000000000',
            submittedAt: DateTime.utc(2026),
            action: const AdvanceSentenceHuntItem(),
          ),
        );
    final List<SentenceHuntItem> largeSyntheticItems = largeSynthetic.sections
        .expand((SentenceHuntSection section) => section.items)
        .toList(growable: false);
    expect(largeSynthetic.hasValidRoot, isTrue);
    expect(
      largeSynthetic.sections.every(
        (SentenceHuntSection section) => largeSynthetic.isAvailable(section.id),
      ),
      isTrue,
      reason: largeSynthetic.diagnostics
          .map(
            (SentenceHuntDiagnostic diagnostic) =>
                '${diagnostic.code}/${diagnostic.recordId}: '
                '${diagnostic.message}',
          )
          .join('\n'),
    );
    expect(
      largeSynthetic.sections.every(
        (SentenceHuntSection section) =>
            utf8.encode(section.sectionFingerprint).length >=
            largestPendingFingerprintBytes,
      ),
      isTrue,
    );
    expect(
      largeSyntheticItems.every(
        (SentenceHuntItem item) =>
            item.sentence.tokens.length >= largestPendingTokenCount &&
            utf8.encode(item.sentence.text).length >= largestPendingTextBytes,
      ),
      isTrue,
    );
    for (final (String label, SentenceHuntCatalogue catalogue)
        in <(String, SentenceHuntCatalogue)>[
          ('synthetic', synthetic),
          ('synthetic-large-geometry', largeSynthetic),
          ('production-pending-read-only', pending),
        ]) {
      for (final SentenceHuntSection section in catalogue.sections) {
        final List<int> textBytes = section.items
            .map(
              (SentenceHuntItem item) => utf8.encode(item.sentence.text).length,
            )
            .toList(growable: false);
        final List<int> tokenCounts = section.items
            .map((SentenceHuntItem item) => item.sentence.tokens.length)
            .toList(growable: false);
        final String fingerprint = section.sectionFingerprint;
        final int fingerprintBytes = utf8.encode(fingerprint).length;
        final int commandFieldBytes = utf8
            .encode(jsonEncode(fingerprint))
            .length;
        final String command = canonicalAdvance(section.id, fingerprint);
        final String baselineCommand = canonicalAdvance(section.id, '{}');
        final int commandFingerprintBytes =
            utf8.encode(command).length - utf8.encode(baselineCommand).length;
        final int receiptFingerprintBytes =
            utf8.encode(jsonEncode(command)).length -
            utf8.encode(jsonEncode(baselineCommand)).length;
        final int commandBytes = utf8.encode(command).length;
        final int receiptCommandBytes = utf8.encode(jsonEncode(command)).length;
        // ignore: avoid_print
        print(
          'BYTEBOUND $label ${section.id}: '
          'fingerprintUtf8=$fingerprintBytes '
          'fingerprintJsonStringUtf8=$commandFieldBytes '
          'canonicalCommandUtf8=$commandBytes '
          'receiptCanonicalCommandUtf8=$receiptCommandBytes '
          'canonicalCommandFingerprintDeltaUtf8=$commandFingerprintBytes '
          'receiptCommandFingerprintDeltaUtf8=$receiptFingerprintBytes '
          'textUtf8ByItem=$textBytes tokenCountsByItem=$tokenCounts',
        );
      }
    }
  });
}
