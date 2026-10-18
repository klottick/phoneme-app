import 'dart:convert';

/// Synthetic records used only by FR08 unit tests. They intentionally do not
/// reproduce the pending production sentence packet or assert any real review.
final class SentenceHuntPackageFixture {
  SentenceHuntPackageFixture({
    required this.manifest,
    required this.provenance,
    required this.annotations,
    required this.sourceEvidence,
  });

  final Map<String, dynamic> manifest;
  final Map<String, dynamic> provenance;
  final Map<String, dynamic> annotations;
  final Map<String, dynamic> sourceEvidence;

  String get manifestJson => jsonEncode(manifest);
  String get provenanceJson => jsonEncode(provenance);
  String get annotationsJson => jsonEncode(annotations);
  String get sourceEvidenceJson => jsonEncode(sourceEvidence);

  SentenceHuntPackageFixture copy() => SentenceHuntPackageFixture(
        manifest: _copyMap(manifest),
        provenance: _copyMap(provenance),
        annotations: _copyMap(annotations),
        sourceEvidence: _copyMap(sourceEvidence),
      );
}

const List<String> fixtureSectionIds = <String>[
  'en-fr-sentence-hunt-vowels',
  'en-fr-sentence-hunt-consonants',
  'en-fr-sentence-hunt-mixed',
];

const List<List<String>> fixtureItemIds = <List<String>>[
  <String>[
    'fr08-vowel-01',
    'fr08-vowel-02',
    'fr08-vowel-03',
    'fr08-vowel-04',
    'fr08-vowel-05',
  ],
  <String>[
    'fr08-consonant-01',
    'fr08-consonant-02',
    'fr08-consonant-03',
    'fr08-consonant-04',
    'fr08-consonant-05',
  ],
  <String>[
    'fr08-mixed-01',
    'fr08-mixed-02',
    'fr08-mixed-03',
    'fr08-mixed-04',
    'fr08-mixed-05',
  ],
];

const List<List<String>> fixtureTargetSounds = <List<String>>[
  <String>['ɑ̃', 'y', 'u', 'ɛ̃', 'œ̃'],
  <String>['z', 'ʃ', 'v', 'm', 'p'],
  <String>['ɑ̃', 'y', 'z', 'ʃ', 'v'],
];

SentenceHuntPackageFixture syntheticSentencePackage({
  bool reviewed = true,
  List<Map<String, dynamic>> historicalSections =
      const <Map<String, dynamic>>[],
}) {
  final List<Map<String, dynamic>> sections = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> provenanceEntries = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> annotationEntries = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> evidenceEntries = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'fixture-dataset',
      'url': 'https://example.test/dataset',
      'retrievedAt': '2026-01-01T00:00:00Z',
      'sha256': _sha('d'),
      'text': 'Synthetic dataset note; not production review evidence.',
      'scope': 'dataset',
      'itemIds': <String>[],
    },
  ];

  int ordinal = 0;
  for (int sectionIndex = 0;
      sectionIndex < fixtureSectionIds.length;
      sectionIndex++) {
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    for (int itemIndex = 0;
        itemIndex < fixtureItemIds[sectionIndex].length;
        itemIndex++) {
      final String itemId = fixtureItemIds[sectionIndex][itemIndex];
      final String sound = fixtureTargetSounds[sectionIndex][itemIndex];
      final String sentenceId = '$itemId-sentence';
      final String audioRefId = '$itemId-audio';
      final String annotationHash = _sha('c');
      final String originalSha = _sha(_hexDigit(ordinal + 1));
      final String clipSha = _sha(_hexDigit(ordinal + 17));
      const String text = 'Tu vois tout, tu souris.';
      final String firstTokenId = '$itemId-token-01';
      final String secondTokenId = '$itemId-token-02';
      final String distractorTokenId = '$itemId-token-03';
      final String repeatedTokenId = '$itemId-token-04';
      final String finalTokenId = '$itemId-token-05';
      final List<Map<String, dynamic>> tokens = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': firstTokenId,
          'text': 'Tu',
          'phonemes': <String>['t', sound],
        },
        <String, dynamic>{
          'id': secondTokenId,
          'text': 'vois',
          'phonemes': <String>[
            for (final String phoneme in <String>['v', 'w', 'a'])
              if (phoneme != sound) phoneme,
          ],
        },
        <String, dynamic>{
          'id': distractorTokenId,
          'text': 'tout',
          'phonemes': <String>['t', 'i'],
        },
        <String, dynamic>{
          'id': repeatedTokenId,
          'text': 'tu',
          'phonemes': <String>['t', sound],
        },
        <String, dynamic>{
          'id': finalTokenId,
          'text': 'souris',
          'phonemes': <String>[
            for (final String phoneme in <String>['s', 'u', 'ʁ', 'i'])
              if (phoneme != sound) phoneme,
          ],
        },
      ];
      final List<String> expectedTokenIds = <String>[
        firstTokenId,
        repeatedTokenId,
      ];
      final Map<String, dynamic> frenchReview = _review(
        reviewed: reviewed,
        originalSha: originalSha,
        clipSha: clipSha,
        annotationHash: annotationHash,
        evidenceId: 'fixture-item-$itemId',
        reviewer: 'Synthetic fixture reviewer',
      );
      final Map<String, dynamic> rightsReview = _review(
        reviewed: reviewed,
        originalSha: originalSha,
        clipSha: clipSha,
        annotationHash: annotationHash,
        evidenceId: 'fixture-item-$itemId',
        reviewer: 'Synthetic fixture rights reviewer',
      );
      final String evidenceId = 'fixture-item-$itemId';
      evidenceEntries.add(<String, dynamic>{
        'id': evidenceId,
        'url': 'https://example.test/items/$itemId',
        'retrievedAt': '2026-01-01T00:00:00Z',
        'sha256': _sha(_hexDigit(ordinal + 1)),
        'text': 'Synthetic test evidence only.',
        'scope': 'item',
        'itemIds': <String>[itemId],
      });

      items.add(<String, dynamic>{
        'id': itemId,
        'sentenceId': sentenceId,
        'audioRefId': audioRefId,
        'purpose': 'practice',
        'reviewState': reviewed ? 'reviewed' : 'pending',
        'targetSound': sound,
        'targetLabel':
            'French ${_targetRole(sectionIndex, itemIndex)} /$sound/',
        'text': text,
        'debriefNote': 'Synthetic test note for $itemId.',
        'annotationRevision': 1,
        'annotationHash': annotationHash,
        'tokens': tokens,
        'expectedTokenIds': expectedTokenIds,
        'originalPath': 'originals/$itemId.wav',
        'clipPath': 'clips/$itemId.wav',
        'originalSha256': originalSha,
        'clipSha256': clipSha,
      });

      annotationEntries.add(<String, dynamic>{
        'itemId': itemId,
        'annotationRevision': 1,
        'annotationHash': annotationHash,
        'tool': <String, dynamic>{
          'name': 'synthetic-fixture',
          'version': '1',
          'settings': <String>['test-only'],
          'inputSha256': _sha('e'),
        },
        'rawSentenceIpa': 'synthetic test phonemes',
        'draftTokenPhonemes': <Map<String, dynamic>>[
          for (final Map<String, dynamic> token in tokens)
            <String, dynamic>{
              'tokenId': token['id'],
              'phonemes': List<String>.of(token['phonemes'] as List<String>),
            },
        ],
        'corrections': <Map<String, dynamic>>[],
        'frenchAudioReview': frenchReview,
      });

      provenanceEntries.add(<String, dynamic>{
        'itemId': itemId,
        'source': <String, dynamic>{
          'repository': 'fixture/synthetic',
          'revision': 'fixture-revision',
          'config': 'fr_fr',
          'split': 'test',
          'rowId': '$ordinal',
          'audioPath': '$itemId.wav',
          'retrievalUrl': 'https://example.test/retrieve/$itemId',
          'retrievedAt': '2026-01-01T00:00:00Z',
          'rawTranscription': text,
          'transcription': text.toLowerCase(),
          'rawTsvRecord': '$ordinal\t$itemId\t$text',
        },
        'original': _measurement(
          path: 'originals/$itemId.wav',
          hash: originalSha,
          byteLength: 128,
          sampleWidth: 4,
          encoding: 'ieee-float32le',
        ),
        'clip': _measurement(
          path: 'clips/$itemId.wav',
          hash: clipSha,
          byteLength: 64,
          sampleWidth: 2,
          encoding: 'pcm-s16le',
        ),
        'derivation': <String, dynamic>{
          'startFrame': 0,
          'endFrame': 32,
          'conversionPolicy': 'pcm16-v1',
          'tool': 'synthetic fixture tool',
          'version': '1',
          'settings': <String>['synthetic only'],
          'changes': <String>['synthetic conversion for tests'],
          'transcriptCorrectionRationale': 'Synthetic fixture transcript.',
        },
        'credit': <String, dynamic>{
          'creator': 'Synthetic fixture source',
          'attribution': 'Synthetic test attribution only.',
          'licenseId': 'CC-BY-4.0',
          'licenseUrl': 'https://creativecommons.org/licenses/by/4.0/',
          'licenseTextPath': 'licenses/CC-BY-4.0.txt',
          'notices': <String>[
            'Synthetic test credit; not production evidence.'
          ],
          'evidenceIds': <String>['fixture-dataset', evidenceId],
        },
        'rightsReview': rightsReview,
      });
      ordinal++;
    }
    final String sectionId = fixtureSectionIds[sectionIndex];
    sections.add(<String, dynamic>{
      'id': sectionId,
      'kind': <String>['vowels', 'consonants', 'mixed'][sectionIndex],
      'title': 'Synthetic ${<String>[
        'vowel',
        'consonant',
        'mixed'
      ][sectionIndex]} section',
      'contentRevision': 1,
      'policyRevision': 1,
      'completionThresholdPercent': 80,
      'items': items,
    });
  }

  return SentenceHuntPackageFixture(
    manifest: <String, dynamic>{
      'schemaVersion': 1,
      'language': 'fr',
      'courseId': 'en-fr',
      'sections': sections,
      'historicalSections': <Map<String, dynamic>>[
        for (final Map<String, dynamic> descriptor in historicalSections)
          _copyMap(descriptor),
      ],
    },
    provenance: <String, dynamic>{
      'schemaVersion': 1,
      'entries': provenanceEntries,
    },
    annotations: <String, dynamic>{
      'schemaVersion': 1,
      'entries': annotationEntries,
    },
    sourceEvidence: <String, dynamic>{
      'schemaVersion': 1,
      'entries': evidenceEntries,
    },
  );
}

Map<String, dynamic> _review({
  required bool reviewed,
  required String originalSha,
  required String clipSha,
  required String annotationHash,
  required String evidenceId,
  required String reviewer,
}) =>
    <String, dynamic>{
      'status': reviewed ? 'accepted' : 'pending',
      'reviewer': reviewed ? reviewer : null,
      'qualification': reviewed ? 'Synthetic test qualification' : null,
      'reviewedAt': reviewed ? '2026-01-01T00:00:00Z' : null,
      'originalSha256': originalSha,
      'clipSha256': clipSha,
      'annotationHash': annotationHash,
      'evidenceIds':
          reviewed ? <String>['fixture-dataset', evidenceId] : <String>[],
      'notes': reviewed
          ? 'Synthetic accepted test decision.'
          : 'Synthetic pending test decision.',
    };

Map<String, dynamic> _measurement({
  required String path,
  required String hash,
  required int byteLength,
  required int sampleWidth,
  required String encoding,
}) =>
    <String, dynamic>{
      'path': path,
      'sha256': hash,
      'byteLength': byteLength,
      'sampleRate': 16000,
      'channels': 1,
      'sampleWidth': sampleWidth,
      'sampleEncoding': encoding,
      'frameCount': 32,
      'durationSeconds': 0.002,
    };

String _targetRole(int sectionIndex, int itemIndex) {
  if (sectionIndex == 0 || (sectionIndex == 2 && itemIndex < 2)) return 'vowel';
  return 'consonant';
}

String _hexDigit(int index) {
  const String digits = '0123456789abcdef';
  return digits[index % digits.length];
}

String _sha(String digit) => List<String>.filled(64, digit).join();

Map<String, dynamic> _copyMap(Map<String, dynamic> source) => <String, dynamic>{
      for (final MapEntry<String, dynamic> entry in source.entries)
        entry.key: _deepCopy(entry.value),
    };

Object? _deepCopy(Object? value) {
  if (value is Map<String, dynamic>) return _copyMap(value);
  if (value is List) {
    return <Object?>[for (final Object? item in value) _deepCopy(item)];
  }
  return value;
}
