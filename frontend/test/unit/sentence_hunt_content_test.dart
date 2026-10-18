import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/french_sentence_exercises.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';

import '../support/sentence_hunt_fixtures.dart';

void main() {
  group('French sentence package validation', () {
    test('pins the three sections, fifteen item identities, and target roles',
        () {
      expect(sentenceHuntGroupId, 'en-fr-sentence-hunt');
      expect(
        sentenceHuntSectionSpecifications.map((spec) => spec.id),
        fixtureSectionIds,
      );
      for (int sectionIndex = 0;
          sectionIndex < sentenceHuntSectionSpecifications.length;
          sectionIndex++) {
        final SentenceHuntSectionSpecification spec =
            sentenceHuntSectionSpecifications[sectionIndex];
        expect(spec.items, hasLength(5));
        expect(spec.items.map((item) => item.id), fixtureItemIds[sectionIndex]);
        expect(
          spec.items.map((item) => item.sentenceId),
          fixtureItemIds[sectionIndex].map((itemId) => '$itemId-sentence'),
        );
        expect(
          spec.items.map((item) => item.audioRefId),
          fixtureItemIds[sectionIndex].map((itemId) => '$itemId-audio'),
        );
        expect(
          spec.items
              .map((item) => item.targetRole.name)
              .toList(growable: false),
          <String>[
            for (int i = 0; i < 5; i++)
              if (sectionIndex == 0 || (sectionIndex == 2 && i < 2))
                'vowel'
              else
                'consonant',
          ],
        );
      }
    });

    test('accepts the synthetic 15-item packet in exact authored order', () {
      final SentenceHuntCatalogue catalogue = _decode(
        syntheticSentencePackage(),
      );

      expect(
        catalogue.sections.map((section) => section.id),
        fixtureSectionIds,
      );
      expect(
        catalogue.sections.map((section) => section.items.length),
        <int>[5, 5, 5],
      );
      expect(
        catalogue.sections
            .every((section) => catalogue.isAvailable(section.id)),
        isTrue,
        reason: catalogue.diagnostics
            .map((diagnostic) =>
                '${diagnostic.code}/${diagnostic.recordId}: ${diagnostic.message}')
            .join('\n'),
      );
      expect(
        catalogue.sections.expand((section) => section.items).length,
        15,
      );
      expect(catalogue.hasValidRoot, isTrue);
      for (int mixedIndex = 0; mixedIndex < 5; mixedIndex++) {
        final SentenceHuntItem mixed =
            catalogue.section(fixtureSectionIds[2]).items[mixedIndex];
        final SentenceHuntSection primary = catalogue.section(
          fixtureSectionIds[mixedIndex < 2 ? 0 : 1],
        );
        expect(
          primary.items
              .where((SentenceHuntItem item) =>
                  item.exercise.targetSound == mixed.exercise.targetSound)
              .every((SentenceHuntItem item) =>
                  item.sentence.text != mixed.sentence.text),
          isTrue,
          reason: '${mixed.identity.itemId} must use a new literal context',
        );
      }
    });

    test('keeps repeated written words as separate selectable occurrences', () {
      final SentenceHuntCatalogue catalogue = _decode(
        syntheticSentencePackage(),
      );
      final SentenceHuntItem item =
          catalogue.item(fixtureSectionIds[0], fixtureItemIds[0][0]);

      expect(item.sentence.text, 'Tu vois tout, tu souris.');
      expect(item.sentence.tokens.map((token) => token.text),
          <String>['Tu', 'vois', 'tout', 'tu', 'souris']);
      expect(item.expectedTokenIds, <String>[
        item.selectableTokenIds[0],
        item.selectableTokenIds[3],
      ]);
      expect(item.selectableTokenIds.toSet(), hasLength(5));
    });

    test('keeps internal apostrophes and hyphens within exact word units', () {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
      final Map<String, dynamic> item = _manifestItem(
        fixture,
        fixtureItemIds[0][0],
      );
      final String firstId = '${item['id']}-token-01';
      final String secondId = '${item['id']}-token-02';
      final String thirdId = '${item['id']}-token-03';
      item['text'] = "L'ami est-il là ?";
      item['tokens'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': firstId,
          'text': "L'ami",
          'phonemes': <String>['l', 'a', 'm', 'ɑ̃', 'i'],
        },
        <String, dynamic>{
          'id': secondId,
          'text': 'est-il',
          'phonemes': <String>['e', 's', 't', 'i', 'l'],
        },
        <String, dynamic>{
          'id': thirdId,
          'text': 'là',
          'phonemes': <String>['l', 'a'],
        },
      ];
      item['expectedTokenIds'] = <String>[firstId];
      _syncAnnotationTokens(fixture, item);
      _syncSourceText(fixture, item);

      final SentenceHuntItem decoded =
          _decode(fixture).item(fixtureSectionIds[0], fixtureItemIds[0][0]);

      expect(decoded.sentence.text, "L'ami est-il là ?");
      expect(decoded.sentence.tokens.map((token) => token.text),
          <String>["L'ami", 'est-il', 'là']);
      expect(decoded.selectableTokenIds, <String>[firstId, secondId, thirdId]);
      expect(decoded.expectedTokenIds, <String>[firstId]);
    });

    test(
        'reports a missing required root field without making content available',
        () {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
      fixture.manifest.remove('courseId');

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.sections, isEmpty);
      expect(catalogue.hasValidRoot, isFalse);
      expect(
          fixtureSectionIds.every((id) => !catalogue.isAvailable(id)), isTrue);
      expect(catalogue.diagnostics, isNotEmpty);
      expect(catalogue.diagnostics.first.recordId, 'manifest');
    });

    test('rejects duplicate item ids locally and leaves valid siblings intact',
        () {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
      final List<dynamic> items =
          _manifestSection(fixture, fixtureSectionIds[0])['items'] as List;
      (items[1] as Map<String, dynamic>)['id'] = fixtureItemIds[0][0];

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse);
      expect(catalogue.hasValidRoot, isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
      expect(catalogue.diagnosticsFor(fixtureSectionIds[0]), isNotEmpty);
    });

    test(
        'rejects missing item fields, unknown aliases, and duplicate token ids',
        () {
      final List<SentenceHuntPackageFixture Function()> mutations =
          <SentenceHuntPackageFixture Function()>[
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          _manifestItem(fixture, fixtureItemIds[0][0]).remove('purpose');
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          _manifestItem(fixture, fixtureItemIds[0][0])['legacyItemId'] =
              fixtureItemIds[0][0];
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          final Map<String, dynamic> item =
              _manifestItem(fixture, fixtureItemIds[0][0]);
          final List<Map<String, dynamic>> tokens =
              (item['tokens'] as List).cast<Map<String, dynamic>>();
          tokens[1]['id'] = tokens[0]['id'];
          _syncAnnotationTokens(fixture, item);
          return fixture;
        },
      ];

      for (final SentenceHuntPackageFixture Function() mutate in mutations) {
        final SentenceHuntCatalogue catalogue = _decode(mutate());
        expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse);
        expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
        expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
      }
    });

    test('rejects nonmatching mixed targets without disabling siblings', () {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
      final Map<String, dynamic> item =
          _manifestItem(fixture, fixtureItemIds[2][0]);
      item['targetSound'] = 'ɑ';
      item['targetLabel'] = 'French vowel /ɑ/';
      final List<Map<String, dynamic>> tokens =
          (item['tokens'] as List).cast<Map<String, dynamic>>();
      for (final Map<String, dynamic> token in <Map<String, dynamic>>[
        tokens[0],
        tokens[3],
      ]) {
        final List<String> phonemes =
            (token['phonemes'] as List).cast<String>();
        phonemes[phonemes.indexOf('ɑ̃')] = 'ɑ';
      }
      _syncAnnotationTokens(fixture, item);

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.isAvailable(fixtureSectionIds[0]), isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[2]), isFalse);
      expect(
        _codes(catalogue, fixtureSectionIds[2]),
        contains('mixed_target_revisit'),
      );
    });

    test('rejects blank labels, wrong kind, and text/provenance disagreement',
        () {
      final List<SentenceHuntPackageFixture Function()> mutations =
          <SentenceHuntPackageFixture Function()>[
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          _manifestSection(fixture, fixtureSectionIds[0])['title'] = '  ';
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          _manifestSection(fixture, fixtureSectionIds[0])['kind'] = 'mixed';
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          _manifestItem(fixture, fixtureItemIds[0][0])['text'] =
              'Changed transcript.';
          return fixture;
        },
      ];

      for (final SentenceHuntPackageFixture Function() mutate in mutations) {
        final SentenceHuntCatalogue catalogue = _decode(mutate());
        expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse);
        expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
        expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
      }
    });

    test(
        'rejects unknown phonemes, punctuation keys, and mismatched token text',
        () {
      final List<SentenceHuntPackageFixture Function()> mutations =
          <SentenceHuntPackageFixture Function()>[
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          final Map<String, dynamic> token =
              (_manifestItem(fixture, fixtureItemIds[0][0])['tokens'] as List)
                  .first as Map<String, dynamic>;
          (token['phonemes'] as List<String>)[0] = 'not-ipa';
          _syncAnnotationTokens(
            fixture,
            _manifestItem(fixture, fixtureItemIds[0][0]),
          );
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          _manifestItem(fixture, fixtureItemIds[0][0])['expectedTokenIds'] =
              <String>['.'];
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          final Map<String, dynamic> item =
              _manifestItem(fixture, fixtureItemIds[0][0]);
          (item['tokens'] as List).first['text'] = 'Tu!';
          _syncAnnotationTokens(fixture, item);
          return fixture;
        },
      ];

      for (final SentenceHuntPackageFixture Function() mutate in mutations) {
        final SentenceHuntCatalogue catalogue = _decode(mutate());
        expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse);
        expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
        expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
      }
    });

    test('a source draft that disagrees with displayed phonemes fails locally',
        () {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
      final Map<String, dynamic> annotation =
          _annotation(fixture, fixtureItemIds[0][0]);
      ((annotation['draftTokenPhonemes'] as List).first
          as Map<String, dynamic>)['phonemes'] = <String>['t'];

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse);
      expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
    });

    test('mixed items repeat neither primary text nor reviewed availability',
        () {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
      final Map<String, dynamic> primary =
          _manifestItem(fixture, fixtureItemIds[0][0]);
      final Map<String, dynamic> mixed =
          _manifestItem(fixture, fixtureItemIds[2][0]);
      mixed['text'] = primary['text'];
      final List<Map<String, dynamic>> mixedTokens =
          (mixed['tokens'] as List).cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> primaryTokens =
          (primary['tokens'] as List).cast<Map<String, dynamic>>();
      for (int index = 0; index < mixedTokens.length; index++) {
        mixedTokens[index]['text'] = primaryTokens[index]['text'];
      }
      _syncAnnotationTokens(fixture, mixed);
      _syncSourceText(fixture, mixed);

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.isAvailable(fixtureSectionIds[0]), isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[2]), isFalse);
      expect(
        _codes(catalogue, fixtureSectionIds[2]),
        contains('mixed_target_context'),
      );
      expect(
        fixtureItemIds[2].every((String itemId) =>
            catalogue.recordingMetadataFor('$itemId-audio') == null),
        isTrue,
      );
    });

    test('validates every unreferenced source-evidence record fail-closed', () {
      final List<void Function(SentenceHuntPackageFixture)> mutations =
          <void Function(SentenceHuntPackageFixture)>[
        (SentenceHuntPackageFixture fixture) {
          _evidence(fixture, 'fixture-orphan')['unexpected'] = true;
        },
        (SentenceHuntPackageFixture fixture) {
          _evidence(fixture, 'fixture-orphan').remove('url');
        },
        (SentenceHuntPackageFixture fixture) {
          _evidence(fixture, 'fixture-orphan')['url'] = 'http://example.test/';
        },
        (SentenceHuntPackageFixture fixture) {
          _evidence(fixture, 'fixture-orphan')['retrievedAt'] = 'not-utc';
        },
        (SentenceHuntPackageFixture fixture) {
          _evidence(fixture, 'fixture-orphan')['sha256'] = 'bad';
        },
        (SentenceHuntPackageFixture fixture) {
          _evidence(fixture, 'fixture-orphan')['scope'] = 'unknown';
        },
        (SentenceHuntPackageFixture fixture) {
          final Map<String, dynamic> evidence =
              _evidence(fixture, 'fixture-orphan');
          evidence['scope'] = 'item';
          evidence['itemIds'] = <String>['not-an-authored-item'];
        },
      ];

      for (final void Function(SentenceHuntPackageFixture) mutate
          in mutations) {
        final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
        (fixture.sourceEvidence['entries'] as List).add(<String, dynamic>{
          'id': 'fixture-orphan',
          'url': 'https://example.test/orphan',
          'retrievedAt': '2026-01-01T00:00:00Z',
          'sha256': List<String>.filled(64, 'a').join(),
          'text': 'Complete but unreferenced synthetic evidence.',
          'scope': 'dataset',
          'itemIds': <String>[],
        });
        mutate(fixture);

        final SentenceHuntCatalogue catalogue = _decode(fixture);

        expect(catalogue.sections, isEmpty);
        expect(catalogue.hasValidRoot, isFalse);
        expect(
          fixtureSectionIds.every((String id) => !catalogue.isAvailable(id)),
          isTrue,
        );
        expect(
          catalogue.diagnostics.any((SentenceHuntDiagnostic diagnostic) =>
              diagnostic.recordId == 'fixture-orphan'),
          isTrue,
        );
      }
    });

    test(
        'unreferenced duplicate evidence IDs invalidate the root regardless of order or count',
        () {
      const String duplicateId = 'fixture-unreferenced-duplicate';
      Map<String, dynamic> evidenceRecord({
        required String url,
        required String shaDigit,
        required String text,
      }) =>
          <String, dynamic>{
            'id': duplicateId,
            'url': url,
            'retrievedAt': '2026-01-01T00:00:00Z',
            'sha256': List<String>.filled(64, shaDigit).join(),
            'text': text,
            'scope': 'dataset',
            'itemIds': <String>[],
          };
      final Map<String, dynamic> first = evidenceRecord(
        url: 'https://example.test/evidence-first',
        shaDigit: 'a',
        text: 'First conflicting unreferenced evidence record.',
      );
      final Map<String, dynamic> second = evidenceRecord(
        url: 'https://example.test/evidence-second',
        shaDigit: 'b',
        text: 'Second conflicting unreferenced evidence record.',
      );
      final Map<String, dynamic> third = evidenceRecord(
        url: 'https://example.test/evidence-third',
        shaDigit: 'c',
        text: 'Third conflicting unreferenced evidence record.',
      );
      final List<List<Map<String, dynamic>>> duplicateLayouts =
          <List<Map<String, dynamic>>>[
        <Map<String, dynamic>>[first, second],
        <Map<String, dynamic>>[second, first],
        <Map<String, dynamic>>[third, first, second],
      ];

      for (final List<Map<String, dynamic>> duplicates in duplicateLayouts) {
        final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
        (fixture.sourceEvidence['entries'] as List).addAll(duplicates);

        final SentenceHuntCatalogue catalogue = _decode(fixture);

        expect(catalogue.hasValidRoot, isFalse);
        expect(catalogue.sections, isEmpty);
        expect(
          fixtureSectionIds.every((String id) => !catalogue.isAvailable(id)),
          isTrue,
        );
        expect(
          fixtureItemIds.expand((List<String> itemIds) => itemIds).every(
              (String itemId) =>
                  catalogue.recordingMetadataFor('$itemId-audio') == null),
          isTrue,
        );
        final List<SentenceHuntDiagnostic> duplicateDiagnostics = catalogue
            .diagnostics
            .where((SentenceHuntDiagnostic diagnostic) =>
                diagnostic.code == 'duplicate_record' &&
                diagnostic.recordId == 'source-evidence')
            .toList(growable: false);
        expect(duplicateDiagnostics, hasLength(1));
        expect(duplicateDiagnostics.single.message, contains(duplicateId));
      }
    });

    test('accepts a unique valid unreferenced source-evidence record', () {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
      (fixture.sourceEvidence['entries'] as List).add(<String, dynamic>{
        'id': 'fixture-unique-unused',
        'url': 'https://example.test/unique-unused',
        'retrievedAt': '2026-01-01T00:00:00Z',
        'sha256': List<String>.filled(64, 'a').join(),
        'text': 'A unique valid unreferenced record remains legal.',
        'scope': 'dataset',
        'itemIds': <String>[],
      });

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.hasValidRoot, isTrue);
      expect(catalogue.sections, hasLength(3));
      expect(
        fixtureSectionIds.every((String id) => catalogue.isAvailable(id)),
        isTrue,
      );
      expect(
        catalogue.diagnostics.any((SentenceHuntDiagnostic diagnostic) =>
            diagnostic.code == 'duplicate_record'),
        isFalse,
      );
    });

    test('keeps duplicate referenced evidence local without choosing a row',
        () {
      final List<List<int>> duplicateOrders = <List<int>>[
        <int>[0, 1, 2],
        <int>[1, 2, 0],
        <int>[2, 0, 1],
      ];

      for (final List<int> order in duplicateOrders) {
        final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
        final String evidenceId = 'fixture-item-${fixtureItemIds[0][0]}';
        final Map<String, dynamic> original = _evidence(fixture, evidenceId);
        final Map<String, dynamic> malformed = <String, dynamic>{
          ...original,
          'url': 'http://example.test/conflicting-duplicate',
          'text': 'Conflicting malformed synthetic duplicate record.',
        };
        final Map<String, dynamic> conflicting = <String, dynamic>{
          ...original,
          'url': 'https://example.test/conflicting-duplicate',
          'text': 'Conflicting but structurally valid synthetic duplicate.',
          'sha256': List<String>.filled(64, 'f').join(),
        };
        final List<Map<String, dynamic>> variants = <Map<String, dynamic>>[
          original,
          malformed,
          conflicting,
        ];
        final List<dynamic> evidenceEntries =
            fixture.sourceEvidence['entries'] as List;
        evidenceEntries.remove(original);
        evidenceEntries.insertAll(
          evidenceEntries.indexWhere((Object? entry) =>
                  entry is Map && entry['id'] == 'fixture-dataset') +
              1,
          <Map<String, dynamic>>[
            for (final int index in order) variants[index],
          ],
        );

        final SentenceHuntCatalogue catalogue = _decode(fixture);

        expect(catalogue.hasValidRoot, isTrue);
        expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse);
        expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
        expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
        expect(
          fixtureItemIds[0].every((String itemId) =>
              catalogue.recordingMetadataFor('$itemId-audio') == null),
          isTrue,
        );
        expect(
          catalogue.diagnosticsFor(fixtureSectionIds[0]).any(
              (SentenceHuntDiagnostic diagnostic) =>
                  diagnostic.code == 'duplicate_record' &&
                  diagnostic.recordId == evidenceId),
          isTrue,
        );
      }
    });

    test('keeps malformed referenced evidence local to its item section', () {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
      _evidence(fixture, 'fixture-item-${fixtureItemIds[0][0]}')['url'] =
          'http://example.test/item';

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse);
      expect(catalogue.hasValidRoot, isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
      expect(
        catalogue.diagnosticsFor(fixtureSectionIds[0]).any(
            (SentenceHuntDiagnostic diagnostic) =>
                diagnostic.recordId == 'fixture-item-${fixtureItemIds[0][0]}'),
        isTrue,
      );
    });

    test('initial policy revision requires the declared eighty-percent target',
        () {
      for (final int threshold in <int>[79, 100]) {
        final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
        _manifestSection(
                fixture, fixtureSectionIds[0])['completionThresholdPercent'] =
            threshold;

        final SentenceHuntCatalogue catalogue = _decode(fixture);

        expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse);
        expect(catalogue.section(fixtureSectionIds[0]).items, hasLength(5));
        expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
        expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
        expect(
          _codes(catalogue, fixtureSectionIds[0]),
          contains('policy_threshold'),
        );
      }
    });

    test('revision one history also retains eighty-percent threshold', () {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage(
        historicalSections: <Map<String, dynamic>>[
          <String, dynamic>{
            'sectionId': fixtureSectionIds[0],
            'kind': 'vowels',
            'contentRevision': 1,
            'policyRevision': 1,
            'completionThresholdPercent': 79,
            'sectionFingerprint': '{"historical":true}',
          },
        ],
      );
      _manifestSection(fixture, fixtureSectionIds[0])['policyRevision'] = 2;

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.sections, isEmpty);
      expect(
        fixtureSectionIds.every((String id) => !catalogue.isAvailable(id)),
        isTrue,
      );
      expect(
        catalogue.diagnostics.map((SentenceHuntDiagnostic value) => value.code),
        contains('historical_policy_threshold'),
      );
    });

    test('versioned threshold changes and their retained history stay bound',
        () {
      final SentenceHuntPackageFixture baseline = syntheticSentencePackage();
      final String baselineFingerprint =
          _decode(baseline).section(fixtureSectionIds[0]).sectionFingerprint;
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage(
        historicalSections: <Map<String, dynamic>>[
          <String, dynamic>{
            'sectionId': fixtureSectionIds[0],
            'kind': 'vowels',
            'contentRevision': 1,
            'policyRevision': 2,
            'completionThresholdPercent': 75,
            'sectionFingerprint': '{"historical":true}',
          },
        ],
      );
      final Map<String, dynamic> section =
          _manifestSection(fixture, fixtureSectionIds[0]);
      section['policyRevision'] = 3;
      section['completionThresholdPercent'] = 85;

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.isAvailable(fixtureSectionIds[0]), isTrue);
      expect(
        catalogue
            .section(fixtureSectionIds[0])
            .policy
            .completionThresholdPercent,
        85,
      );
      expect(
        catalogue.section(fixtureSectionIds[0]).sectionFingerprint,
        isNot(baselineFingerprint),
      );
      expect(catalogue.historicalSections.single.policyRevision, 2);
      expect(
          catalogue.historicalSections.single.completionThresholdPercent, 75);
    });

    test('rejects impossible UTC calendar and clock values without rollover',
        () {
      const List<String> invalidTimestamps = <String>[
        '2026-02-31T00:00:00Z',
        '2026-13-01T00:00:00Z',
        '2025-02-29T00:00:00Z',
        '2026-01-01T24:00:00Z',
        '2026-01-01T12:60:00Z',
        '2026-01-01T12:00:60Z',
        '2026-01-01T12:00:00+01:00',
        '0000-01-01T00:00:00Z',
      ];

      for (final String timestamp in invalidTimestamps) {
        final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
        (_annotation(fixture, fixtureItemIds[0][0])['frenchAudioReview']
            as Map<String, dynamic>)['reviewedAt'] = timestamp;

        final SentenceHuntCatalogue catalogue = _decode(fixture);

        expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse,
            reason: timestamp);
        expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue,
            reason: timestamp);
        expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue,
            reason: timestamp);
        expect(
          fixtureItemIds[0].every((String itemId) =>
              catalogue.recordingMetadataFor('$itemId-audio') == null),
          isTrue,
          reason: timestamp,
        );
      }
    });

    test('strict UTC calendar validation covers review, source, and evidence',
        () {
      final List<void Function(SentenceHuntPackageFixture)> mutations =
          <void Function(SentenceHuntPackageFixture)>[
        (SentenceHuntPackageFixture fixture) {
          (_annotation(fixture, fixtureItemIds[0][0])['frenchAudioReview']
              as Map<String, dynamic>)['reviewedAt'] = '2026-02-31T00:00:00Z';
        },
        (SentenceHuntPackageFixture fixture) {
          (_provenance(fixture, fixtureItemIds[0][0])['rightsReview']
              as Map<String, dynamic>)['reviewedAt'] = '2026-02-31T00:00:00Z';
        },
        (SentenceHuntPackageFixture fixture) {
          (_provenance(fixture, fixtureItemIds[0][0])['source']
              as Map<String, dynamic>)['retrievedAt'] = '2026-02-31T00:00:00Z';
        },
        (SentenceHuntPackageFixture fixture) {
          _evidence(fixture, 'fixture-item-${fixtureItemIds[0][0]}')[
              'retrievedAt'] = '2026-02-31T00:00:00Z';
        },
      ];

      for (final void Function(SentenceHuntPackageFixture) mutate
          in mutations) {
        final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
        mutate(fixture);

        final SentenceHuntCatalogue catalogue = _decode(fixture);

        expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse);
        expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
        expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
      }
    });

    test('accepts valid UTC leap day, precision, and zero-offset forms', () {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
      (_annotation(fixture, fixtureItemIds[0][0])['frenchAudioReview']
              as Map<String, dynamic>)['reviewedAt'] =
          '2024-02-29T23:59:59.1234567Z';
      (_provenance(fixture, fixtureItemIds[0][0])['rightsReview']
          as Map<String, dynamic>)['reviewedAt'] = '2024-02-29T23:59:59+00:00';
      (_provenance(fixture, fixtureItemIds[0][0])['source']
              as Map<String, dynamic>)['retrievedAt'] =
          '2024-02-29T23:59:59.1+00:00';
      _evidence(
              fixture, 'fixture-item-${fixtureItemIds[0][0]}')['retrievedAt'] =
          '2024-02-29T23:59:59Z';

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.isAvailable(fixtureSectionIds[0]), isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
    });

    test(
        'malformed annotation drafts and corrections gate the whole reviewed section',
        () {
      final List<SentenceHuntPackageFixture Function()> mutations =
          <SentenceHuntPackageFixture Function()>[
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          final Map<String, dynamic> annotation =
              _annotation(fixture, fixtureItemIds[0][0]);
          final List<Map<String, dynamic>> drafts =
              (annotation['draftTokenPhonemes'] as List)
                  .cast<Map<String, dynamic>>();
          drafts.first['unexpected'] = true;
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          final Map<String, dynamic> annotation =
              _annotation(fixture, fixtureItemIds[0][0]);
          final List<Map<String, dynamic>> drafts =
              (annotation['draftTokenPhonemes'] as List)
                  .cast<Map<String, dynamic>>();
          drafts.first['tokenId'] = 'not-a-manifest-token';
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          final Map<String, dynamic> annotation =
              _annotation(fixture, fixtureItemIds[0][0]);
          final List<Map<String, dynamic>> drafts =
              (annotation['draftTokenPhonemes'] as List)
                  .cast<Map<String, dynamic>>();
          drafts[1]['tokenId'] = drafts[0]['tokenId'];
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          final Map<String, dynamic> annotation =
              _annotation(fixture, fixtureItemIds[0][0]);
          final List<Map<String, dynamic>> drafts =
              (annotation['draftTokenPhonemes'] as List)
                  .cast<Map<String, dynamic>>();
          final Map<String, dynamic> first = drafts.first;
          (first['phonemes'] as List<String>)[0] = 'not-ipa';
          annotation['corrections'] = <Map<String, dynamic>>[
            <String, dynamic>{
              'tokenId': first['tokenId'],
              'before': <String>['not-ipa', 'ɑ̃'],
              'after': <String>['t', 'ɑ̃'],
              'rationale': 'Synthetic repair for the regression fixture.',
            },
          ];
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          _annotation(fixture, fixtureItemIds[0][0])['corrections'] =
              <Map<String, dynamic>>[
            <String, dynamic>{
              'tokenId': '${fixtureItemIds[0][0]}-token-01',
              'before': <String>['t', '', 'ɑ̃'],
              'after': <String>['t', 'ɑ̃'],
              'rationale': 'Malformed before list with matching parsed values.',
            },
          ];
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          _annotation(fixture, fixtureItemIds[0][0])['corrections'] =
              <Map<String, dynamic>>[
            <String, dynamic>{
              'tokenId': '${fixtureItemIds[0][0]}-token-01',
              'before': <String>['t', 'ɑ̃'],
              'after': <String>['t', '', 'ɑ̃'],
              'rationale': 'Malformed after list with matching parsed values.',
            },
          ];
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          _annotation(fixture, fixtureItemIds[0][0])['corrections'] =
              <Map<String, dynamic>>[
            <String, dynamic>{
              'tokenId': 'not-a-manifest-token',
              'before': <String>['t', 'ɑ̃'],
              'after': <String>['t', 'ɑ̃'],
              'rationale': 'Synthetic unknown correction ID.',
            },
          ];
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          final Map<String, dynamic> annotation =
              _annotation(fixture, fixtureItemIds[0][0]);
          final Map<String, dynamic> firstCorrection = <String, dynamic>{
            'tokenId': '${fixtureItemIds[0][0]}-token-01',
            'before': <String>['d', 'ɑ̃'],
            'after': <String>['t', 'ɑ̃'],
            'rationale': 'The declared before value is intentionally wrong.',
          };
          annotation['corrections'] = <Map<String, dynamic>>[firstCorrection];
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          final Map<String, dynamic> annotation =
              _annotation(fixture, fixtureItemIds[0][0]);
          annotation['corrections'] = <Map<String, dynamic>>[
            <String, dynamic>{
              'tokenId': '${fixtureItemIds[0][0]}-token-01',
              'before': <String>['t', 'ɑ̃'],
              'after': <String>['t', 'ɑ̃'],
              'rationale': '',
            },
          ];
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          final Map<String, dynamic> annotation =
              _annotation(fixture, fixtureItemIds[0][0]);
          annotation['corrections'] = <Map<String, dynamic>>[
            <String, dynamic>{
              'tokenId': '${fixtureItemIds[0][0]}-token-01',
              'before': <String>['t', 'ɑ̃'],
              'after': <String>['t', 'ɑ̃'],
              'rationale': 'Synthetic correction with an unknown field.',
              'unexpected': true,
            },
          ];
          return fixture;
        },
      ];

      for (final SentenceHuntPackageFixture Function() mutate in mutations) {
        final SentenceHuntCatalogue catalogue = _decode(mutate());

        expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse);
        expect(
          fixtureItemIds[0].every((String itemId) =>
              catalogue.recordingMetadataFor('$itemId-audio') == null),
          isTrue,
        );
        expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
        expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
      }
    });

    test('accepts a valid correction whose final mapping matches the manifest',
        () {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
      final String itemId = fixtureItemIds[0][0];
      final Map<String, dynamic> item = _manifestItem(fixture, itemId);
      final List<Map<String, dynamic>> tokens =
          (item['tokens'] as List).cast<Map<String, dynamic>>();
      (tokens.first['phonemes'] as List<String>)[0] = 'd';
      _annotation(fixture, itemId)['corrections'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'tokenId': tokens.first['id'],
          'before': <String>['t', 'ɑ̃'],
          'after': <String>['d', 'ɑ̃'],
          'rationale': 'Synthetic retained correction for the fixture.',
        },
      ];

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.isAvailable(fixtureSectionIds[0]), isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
      expect(
        catalogue.recordingMetadataFor('$itemId-audio'),
        isNotNull,
      );
    });

    test('requires hash binding, accepted reviewer/date, and covering evidence',
        () {
      final List<SentenceHuntPackageFixture Function()> mutations =
          <SentenceHuntPackageFixture Function()>[
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          _annotation(fixture, fixtureItemIds[0][0])['annotationHash'] = 'bad';
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          _annotation(fixture, fixtureItemIds[0][0])['frenchAudioReview']
              ['reviewer'] = ' ';
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          _annotation(fixture, fixtureItemIds[0][0])['frenchAudioReview']
              ['reviewedAt'] = '2026-01-01T00:00:00';
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          final Map<String, dynamic> review = _annotation(
            fixture,
            fixtureItemIds[0][0],
          )['frenchAudioReview'] as Map<String, dynamic>;
          review['evidenceIds'] = <String>[
            'fixture-item-${fixtureItemIds[0][1]}'
          ];
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          (_annotation(fixture, fixtureItemIds[0][0])['frenchAudioReview']
                  as Map<String, dynamic>)
              .remove('evidenceIds');
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          _provenance(fixture, fixtureItemIds[0][0])['rightsReview']
              ['clipSha256'] = List<String>.filled(64, 'f').join();
          return fixture;
        },
        () {
          final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
          (_provenance(fixture, fixtureItemIds[0][0])['rightsReview']
                  as Map<String, dynamic>)
              .remove('clipSha256');
          return fixture;
        },
      ];

      for (final SentenceHuntPackageFixture Function() mutate in mutations) {
        final SentenceHuntCatalogue catalogue = _decode(mutate());
        expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse);
        expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
        expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
      }
    });

    test(
        'qualifies only both accepted reviews under an explicitly reviewed item',
        () {
      final List<({String french, String rights, String publication})> cases =
          <({String french, String rights, String publication})>[
        (french: 'accepted', rights: 'accepted', publication: 'reviewed'),
        (french: 'accepted', rights: 'accepted', publication: 'pending'),
        (french: 'accepted', rights: 'pending', publication: 'pending'),
        (french: 'pending', rights: 'accepted', publication: 'pending'),
        (french: 'rejected', rights: 'accepted', publication: 'pending'),
        (french: 'accepted', rights: 'rejected', publication: 'pending'),
      ];

      for (final ({String french, String rights, String publication}) row
          in cases) {
        final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
        _setReviews(
          fixture,
          fixtureItemIds[0][0],
          french: row.french,
          rights: row.rights,
          publication: row.publication,
        );
        final SentenceHuntCatalogue catalogue = _decode(fixture);
        expect(
          catalogue.isAvailable(fixtureSectionIds[0]),
          row.french == 'accepted' &&
              row.rights == 'accepted' &&
              row.publication == 'reviewed',
          reason: '${row.french} × ${row.rights} / ${row.publication}',
        );
        expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
        expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
        if (row.publication == 'pending' &&
            row.french == 'accepted' &&
            row.rights == 'accepted') {
          expect(
            _codes(catalogue, fixtureSectionIds[0]),
            contains('publication_pending'),
          );
        }
        if (row.french == 'rejected' || row.rights == 'rejected') {
          final List<SentenceHuntDiagnostic> diagnostics =
              catalogue.diagnosticsFor(fixtureSectionIds[0]);
          expect(diagnostics.map((diagnostic) => diagnostic.code),
              contains('review_rejected'));
          expect(
            diagnostics.any((diagnostic) =>
                diagnostic.message.contains('Synthetic rejected')),
            isTrue,
          );
        }
      }
    });

    test('a reviewed declaration with a pending review is contradictory', () {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
      _setReviews(
        fixture,
        fixtureItemIds[0][0],
        french: 'accepted',
        rights: 'pending',
        publication: 'reviewed',
      );

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse);
      expect(
          _codes(catalogue, fixtureSectionIds[0]), contains('review_conflict'));
    });

    test('one invalid item disables its complete section, not valid siblings',
        () {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
      _manifestItem(fixture, fixtureItemIds[0][3])['expectedTokenIds'] =
          <String>[];

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.isAvailable(fixtureSectionIds[0]), isFalse);
      expect(catalogue.isAvailable(fixtureSectionIds[1]), isTrue);
      expect(catalogue.isAvailable(fixtureSectionIds[2]), isTrue);
    });

    test('section fingerprints bind scored content and exclude review metadata',
        () {
      final SentenceHuntPackageFixture base =
          syntheticSentencePackage(reviewed: false);
      final String baseFingerprint =
          _decode(base).section(fixtureSectionIds[0]).sectionFingerprint;
      expect(baseFingerprint, _sentenceHuntSectionFingerprintGolden());

      final SentenceHuntPackageFixture punctuation = base.copy();
      _manifestItem(punctuation, fixtureItemIds[0][0])['text'] =
          'Tu vois tout, tu souris!';
      _syncSourceText(
          punctuation, _manifestItem(punctuation, fixtureItemIds[0][0]));
      final String changedText =
          _decode(punctuation).section(fixtureSectionIds[0]).sectionFingerprint;
      expect(changedText, isNot(baseFingerprint));

      final SentenceHuntPackageFixture key = base.copy();
      _manifestItem(key, fixtureItemIds[0][0])['expectedTokenIds'] = <String>[
        '${fixtureItemIds[0][0]}-token-01'
      ];
      final String changedKey =
          _decode(key).section(fixtureSectionIds[0]).sectionFingerprint;
      expect(changedKey, isNot(baseFingerprint));

      final SentenceHuntPackageFixture phonemes = base.copy();
      final Map<String, dynamic> phonemeItem =
          _manifestItem(phonemes, fixtureItemIds[0][0]);
      final List<Map<String, dynamic>> phonemeTokens =
          (phonemeItem['tokens'] as List).cast<Map<String, dynamic>>();
      (phonemeTokens[0]['phonemes'] as List)[0] = 'd';
      _syncAnnotationTokens(phonemes, phonemeItem);
      final String changedPhonemes =
          _decode(phonemes).section(fixtureSectionIds[0]).sectionFingerprint;
      expect(changedPhonemes, isNot(baseFingerprint));

      final SentenceHuntPackageFixture audioHash = base.copy();
      final String itemId = fixtureItemIds[0][0];
      final String nextHash = List<String>.filled(64, 'f').join();
      _manifestItem(audioHash, itemId)['clipSha256'] = nextHash;
      _provenance(audioHash, itemId)['clip']['sha256'] = nextHash;
      _setBoundHash(audioHash, itemId, 'clipSha256', nextHash);
      final String changedAudio =
          _decode(audioHash).section(fixtureSectionIds[0]).sectionFingerprint;
      expect(changedAudio, isNot(baseFingerprint));

      final SentenceHuntPackageFixture reviewOnly = base.copy();
      _setReviews(
        reviewOnly,
        itemId,
        french: 'rejected',
        rights: 'accepted',
        publication: 'pending',
      );
      final Map<String, dynamic> review =
          _annotation(reviewOnly, itemId)['frenchAudioReview']
              as Map<String, dynamic>;
      review['notes'] = 'Different decision timestamp/status only.';
      review['reviewedAt'] = '2026-02-03T04:05:06Z';
      final String unchangedReview =
          _decode(reviewOnly).section(fixtureSectionIds[0]).sectionFingerprint;
      expect(unchangedReview, baseFingerprint);
    });

    test('retains immutable historical revision descriptors for consumers', () {
      const Map<String, dynamic> historical = <String, dynamic>{
        'sectionId': 'en-fr-sentence-hunt-vowels',
        'kind': 'vowels',
        'contentRevision': 1,
        'policyRevision': 1,
        'completionThresholdPercent': 80,
        'sectionFingerprint': '{"historical":true}',
      };
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage(
        historicalSections: <Map<String, dynamic>>[historical],
      );
      _manifestSection(fixture, fixtureSectionIds[0])['contentRevision'] = 2;

      final SentenceHuntCatalogue catalogue = _decode(fixture);

      expect(catalogue.historicalSections, hasLength(1));
      final SentenceHuntHistoricalDescriptor descriptor =
          catalogue.historicalSections.single;
      expect(descriptor.sectionId, fixtureSectionIds[0]);
      expect(descriptor.contentRevision, 1);
      expect(descriptor.policyRevision, 1);
      expect(descriptor.sectionFingerprint, '{"historical":true}');
      expect(
          () => catalogue.historicalSections.clear(), throwsUnsupportedError);
      expect(
        () => catalogue.historicalSections.add(descriptor),
        throwsUnsupportedError,
      );
    });

    test('pins the Task1A cross-language annotation identity golden literally',
        () {
      const String canonical = '{"annotationRevision":2,"audioRefId":"audio-a",'
          '"expectedTokenIds":["t1","t2"],"sentenceId":"fr-1",'
          '"text":"Un été.","tokens":[{"id":"t1",'
          '"phonemes":["œ̃"],"text":"Un"},{"id":"t2",'
          '"phonemes":["e","t","e"],"text":"été."}]}';
      const String digest =
          '42cb8ee6b048a8e4f69e924c3b10645ae407a85918b9f5ac3ecefb112cba5d2a';
      const Map<String, Object?> projection = <String, Object?>{
        'sentenceId': 'fr-1',
        'audioRefId': 'audio-a',
        'text': 'Un été.',
        'annotationRevision': 2,
        'tokens': <Map<String, Object?>>[
          <String, Object?>{
            'id': 't1',
            'text': 'Un',
            'phonemes': <String>['œ̃']
          },
          <String, Object?>{
            'id': 't2',
            'text': 'été.',
            'phonemes': <String>['e', 't', 'e'],
          },
        ],
        'expectedTokenIds': <String>['t1', 't2'],
      };

      expect(jsonDecode(canonical), projection);
      expect(
          canonical,
          _referenceCanonicalJson(<String, Object?>{
            'annotationRevision': 2,
            'audioRefId': 'audio-a',
            'expectedTokenIds': <String>['t1', 't2'],
            'sentenceId': 'fr-1',
            'text': 'Un été.',
            'tokens': projection['tokens'],
          }));
      expect(digest, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(
        digest,
        '42cb8ee6b048a8e4f69e924c3b10645ae407a85918b9f5ac3ecefb112cba5d2a',
      );
    });

    test('actual pending fifteen-item packet keeps all five-item sections', () {
      const String base = 'assets/audio/fr-sentences';
      final SentenceHuntCatalogue catalogue = decodeFrenchSentencePackage(
        manifestJson: File('$base/manifest.json').readAsStringSync(),
        provenanceJson: File('$base/provenance.json').readAsStringSync(),
        annotationsJson: File('$base/annotations.json').readAsStringSync(),
        sourceEvidenceJson:
            File('$base/source-evidence.json').readAsStringSync(),
      );

      expect(
          catalogue.sections.map((section) => section.id), fixtureSectionIds);
      expect(catalogue.sections.map((section) => section.items.length),
          <int>[5, 5, 5]);
      expect(
          catalogue.sections
              .every((section) => !catalogue.isAvailable(section.id)),
          isTrue);
      expect(catalogue.hasValidRoot, isTrue);
      expect(
          catalogue.sections.expand((section) => section.items), hasLength(15));
      for (int mixedIndex = 0; mixedIndex < 5; mixedIndex++) {
        final SentenceHuntItem mixed =
            catalogue.section(fixtureSectionIds[2]).items[mixedIndex];
        final SentenceHuntSection primary = catalogue.section(
          fixtureSectionIds[mixedIndex < 2 ? 0 : 1],
        );
        expect(
          primary.items
              .where((SentenceHuntItem item) =>
                  item.exercise.targetSound == mixed.exercise.targetSound)
              .every((SentenceHuntItem item) =>
                  item.sentence.text != mixed.sentence.text),
          isTrue,
          reason:
              'Pending packet ${mixed.identity.itemId} must retain a new context',
        );
      }
      expect(
        _codes(catalogue, fixtureSectionIds[2]),
        isNot(contains('mixed_target_context')),
      );
    });
  });
}

SentenceHuntCatalogue _decode(SentenceHuntPackageFixture fixture) =>
    decodeFrenchSentencePackage(
      manifestJson: fixture.manifestJson,
      provenanceJson: fixture.provenanceJson,
      annotationsJson: fixture.annotationsJson,
      sourceEvidenceJson: fixture.sourceEvidenceJson,
    );

Map<String, dynamic> _manifestSection(
  SentenceHuntPackageFixture fixture,
  String sectionId,
) =>
    (fixture.manifest['sections'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((section) => section['id'] == sectionId);

Map<String, dynamic> _manifestItem(
  SentenceHuntPackageFixture fixture,
  String itemId,
) =>
    ((fixture.manifest['sections'] as List).cast<Map<String, dynamic>>().expand(
            (section) =>
                (section['items'] as List).cast<Map<String, dynamic>>()))
        .singleWhere((item) => item['id'] == itemId);

Map<String, dynamic> _annotation(
  SentenceHuntPackageFixture fixture,
  String itemId,
) =>
    (fixture.annotations['entries'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((entry) => entry['itemId'] == itemId);

Map<String, dynamic> _provenance(
  SentenceHuntPackageFixture fixture,
  String itemId,
) =>
    (fixture.provenance['entries'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((entry) => entry['itemId'] == itemId);

Map<String, dynamic> _evidence(
  SentenceHuntPackageFixture fixture,
  String evidenceId,
) =>
    (fixture.sourceEvidence['entries'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((entry) => entry['id'] == evidenceId);

void _syncAnnotationTokens(
  SentenceHuntPackageFixture fixture,
  Map<String, dynamic> item,
) {
  _annotation(fixture, item['id'] as String)['draftTokenPhonemes'] =
      <Map<String, dynamic>>[
    for (final Map<String, dynamic> token
        in (item['tokens'] as List).cast<Map<String, dynamic>>())
      <String, dynamic>{
        'tokenId': token['id'],
        'phonemes': List<String>.of(
          (token['phonemes'] as List).cast<String>(),
        ),
      },
  ];
}

void _syncSourceText(
  SentenceHuntPackageFixture fixture,
  Map<String, dynamic> item,
) {
  final Map<String, dynamic> source = _provenance(
    fixture,
    item['id'] as String,
  )['source'] as Map<String, dynamic>;
  source['rawTranscription'] = item['text'];
  source['transcription'] = (item['text'] as String).toLowerCase();
}

void _setReviews(
  SentenceHuntPackageFixture fixture,
  String itemId, {
  required String french,
  required String rights,
  required String publication,
}) {
  final Map<String, dynamic> item = _manifestItem(fixture, itemId);
  item['reviewState'] = publication;
  final Map<String, dynamic> audioReview =
      _annotation(fixture, itemId)['frenchAudioReview'] as Map<String, dynamic>;
  final Map<String, dynamic> rightsReview =
      _provenance(fixture, itemId)['rightsReview'] as Map<String, dynamic>;
  _setReviewStatus(audioReview, french, itemId);
  _setReviewStatus(rightsReview, rights, itemId);
}

void _setReviewStatus(
  Map<String, dynamic> review,
  String status,
  String itemId,
) {
  review['status'] = status;
  if (status == 'pending') {
    review['reviewer'] = null;
    review['qualification'] = null;
    review['reviewedAt'] = null;
    review['evidenceIds'] = <String>[];
    review['notes'] = 'Synthetic pending test decision.';
  } else {
    review['reviewer'] = 'Synthetic $status reviewer';
    review['qualification'] = 'Synthetic test qualification';
    review['reviewedAt'] = '2026-01-01T00:00:00Z';
    review['evidenceIds'] = <String>[
      'fixture-dataset',
      'fixture-item-$itemId',
    ];
    review['notes'] = 'Synthetic $status decision.';
  }
}

void _setBoundHash(
  SentenceHuntPackageFixture fixture,
  String itemId,
  String field,
  String value,
) {
  _annotation(fixture, itemId)['frenchAudioReview'][field] = value;
  _provenance(fixture, itemId)['rightsReview'][field] = value;
}

List<String> _codes(SentenceHuntCatalogue catalogue, String sectionId) =>
    catalogue
        .diagnosticsFor(sectionId)
        .map((diagnostic) => diagnostic.code)
        .toList(growable: false);

String _sentenceHuntSectionFingerprintGolden() {
  const List<String> itemIds = <String>[
    'fr08-vowel-01',
    'fr08-vowel-02',
    'fr08-vowel-03',
    'fr08-vowel-04',
    'fr08-vowel-05',
  ];
  const List<String> targetSounds = <String>['ɑ̃', 'y', 'u', 'ɛ̃', 'œ̃'];
  final Map<String, Object?> projection = <String, Object?>{
    'section': <String, Object?>{
      'id': 'en-fr-sentence-hunt-vowels',
      'kind': 'vowels',
      'contentRevision': 1,
      'policyRevision': 1,
      'completionThresholdPercent': 80,
    },
    'items': <Map<String, Object?>>[
      for (int index = 0; index < itemIds.length; index++)
        _referenceVowelItem(itemIds[index], targetSounds[index], index),
    ],
  };
  return _referenceCanonicalJson(projection);
}

Map<String, Object?> _referenceVowelItem(
  String itemId,
  String targetSound,
  int index,
) {
  const List<String> texts = <String>[
    'Tu vois tout, tu souris.',
    'Elle chante avec un ami.',
    'Nous avons deux chats noirs.',
    'Il mange une pomme verte.',
    'Vous aimez ce grand jardin.',
  ];
  const List<List<String>> tokenTexts = <List<String>>[
    <String>['Tu', 'vois', 'tout', 'tu', 'souris'],
    <String>['Elle', 'chante', 'avec', 'un', 'ami'],
    <String>['Nous', 'avons', 'deux', 'chats', 'noirs'],
    <String>['Il', 'mange', 'une', 'pomme', 'verte'],
    <String>['Vous', 'aimez', 'ce', 'grand', 'jardin'],
  ];
  final List<String> ids = <String>[
    for (int tokenIndex = 0; tokenIndex < 5; tokenIndex++)
      '$itemId-token-${(tokenIndex + 1).toString().padLeft(2, '0')}',
  ];
  final String hashDigit = '12345'[index];
  final String clipHashDigit = '12345'[index];
  final List<String> finalTokenPhonemes = <String>['s', 'u', 'ʁ', 'i']
    ..remove(targetSound);
  return <String, Object?>{
    'id': itemId,
    'sentenceId': '$itemId-sentence',
    'audioRefId': '$itemId-audio',
    'purpose': 'practice',
    'targetSound': targetSound,
    'targetLabel': 'French vowel /$targetSound/',
    'text': texts[index],
    'debriefNote': 'Synthetic test note for $itemId.',
    'annotationRevision': 1,
    'annotationHash': List<String>.filled(64, 'c').join(),
    'tokens': <Map<String, Object?>>[
      for (int tokenIndex = 0; tokenIndex < 5; tokenIndex++)
        <String, Object?>{
          'id': ids[tokenIndex],
          'text': tokenTexts[index][tokenIndex],
          'phonemes': switch (tokenIndex) {
            0 || 3 => <String>['t', targetSound],
            1 => <String>['v', 'w', 'a'],
            2 => <String>['t', 'i'],
            4 => finalTokenPhonemes,
            _ => throw RangeError.index(tokenIndex, const <int>[0, 1, 2, 3, 4]),
          },
        },
    ],
    'expectedTokenIds': <String>[ids[0], ids[3]],
    'originalSha256': List<String>.filled(64, hashDigit).join(),
    'clipSha256': List<String>.filled(64, clipHashDigit).join(),
  };
}

String _referenceCanonicalJson(Object? value) =>
    jsonEncode(_referenceCanonicalValue(value));

Object? _referenceCanonicalValue(Object? value) {
  if (value is Map) {
    final List<String> keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final String key in keys) key: _referenceCanonicalValue(value[key]),
    };
  }
  if (value is List) {
    return <Object?>[
      for (final Object? item in value) _referenceCanonicalValue(item),
    ];
  }
  return value;
}
