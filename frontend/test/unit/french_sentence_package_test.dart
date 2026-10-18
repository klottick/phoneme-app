import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio_catalog.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/french_sentence_exercises.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';

import '../support/sentence_hunt_fixtures.dart';

void main() {
  group('French sentence package loader', () {
    test('coalesces concurrent reads and caches only a successful catalogue',
        () async {
      final _FixtureBundle bundle = _FixtureBundle(
        syntheticSentencePackage(),
        gate: Completer<void>(),
      );
      final FrenchSentencePackageLoader loader =
          FrenchSentencePackageLoader(bundle: bundle);

      final Future<SentenceHuntCatalogue> first = loader.load();
      final Future<SentenceHuntCatalogue> second = loader.load();
      await Future<void>.delayed(Duration.zero);
      expect(bundle.loads, hasLength(4));
      expect(bundle.loads.every((load) => !load.cache), isTrue);

      bundle.gate!.complete();
      final List<SentenceHuntCatalogue> loaded = await Future.wait(
        <Future<SentenceHuntCatalogue>>[first, second],
      );
      expect(identical(loaded[0], loaded[1]), isTrue);

      final SentenceHuntCatalogue cached = await loader.load();
      expect(identical(cached, loaded[0]), isTrue);
      expect(bundle.loads, hasLength(4));
    });

    test('a failed asset read is cleared and an explicit retry succeeds',
        () async {
      final _FixtureBundle bundle = _FixtureBundle(
        syntheticSentencePackage(),
        failFirstRead: true,
      );
      final FrenchSentencePackageLoader loader =
          FrenchSentencePackageLoader(bundle: bundle);

      await expectLater(loader.load(), throwsA(isA<Object>()));
      final int failedReadCount = bundle.loads.length;
      final SentenceHuntCatalogue retried = await loader.load();

      expect(retried.sections, hasLength(3));
      expect(bundle.loads.length, failedReadCount + 4);
      expect(bundle.loads.every((load) => !load.cache), isTrue);
    });

    test(
        'returns five references and five reviewed entries for a valid section',
        () async {
      final _FixtureBundle bundle = _FixtureBundle(
        syntheticSentencePackage(),
      );
      final FrenchSentencePackageLoader loader =
          FrenchSentencePackageLoader(bundle: bundle);

      final CourseAudioCatalog catalog = await loader.loadAudioForReference(
        sentenceHuntSectionSpecifications[0].items[0].audioRefId,
      );

      expect(catalog.references, hasLength(5));
      expect(catalog.entries, hasLength(5));
      expect(
        catalog.references.map((reference) => reference.id),
        sentenceHuntSectionSpecifications[0]
            .items
            .map((item) => item.audioRefId),
      );
      for (final CourseAudioEntry entry in catalog.entries) {
        expect(entry.recordings, contains(CourseAudioVariant.normal));
        expect(entry.recordings, isNot(contains(CourseAudioVariant.slow)));
        expect(entry.recordings[CourseAudioVariant.normal]!.source,
            CourseAudioSource.reviewedRecording);
        expect(entry.credit.unchanged, isFalse);
        expect(entry.credit.creator, contains('Synthetic fixture source'));
        expect(
            entry.credit.notices, contains('synthetic conversion for tests'));
      }
    });

    test('one pending member atomically removes all section recording entries',
        () async {
      final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
      _setOneItemPending(fixture, fixtureItemIds[0][2]);
      final FrenchSentencePackageLoader loader = FrenchSentencePackageLoader(
        bundle: _FixtureBundle(fixture),
      );

      final CourseAudioCatalog vowels = await loader.loadAudioForReference(
        sentenceHuntSectionSpecifications[0].items[0].audioRefId,
      );
      final CourseAudioCatalog consonants = await loader.loadAudioForReference(
        sentenceHuntSectionSpecifications[1].items[0].audioRefId,
      );

      expect(vowels.references, hasLength(5));
      expect(vowels.entries, isEmpty);
      expect(
          vowels.references.map((reference) => reference.id),
          sentenceHuntSectionSpecifications[0]
              .items
              .map((item) => item.audioRefId));
      expect(consonants.references, hasLength(5));
      expect(consonants.entries, hasLength(5));
    });

    test('pending reviews expose no reviewed audio and never shrink references',
        () async {
      final SentenceHuntPackageFixture fixture =
          syntheticSentencePackage(reviewed: false);
      final FrenchSentencePackageLoader loader = FrenchSentencePackageLoader(
        bundle: _FixtureBundle(fixture),
      );

      for (final SentenceHuntSectionSpecification section
          in sentenceHuntSectionSpecifications) {
        final CourseAudioCatalog catalog = await loader.loadAudioForReference(
          section.items.first.audioRefId,
        );
        expect(catalog.references, hasLength(5));
        expect(catalog.entries, isEmpty);
        expect(
          catalog.entries.any((entry) => entry.recordings.values.any(
              (recording) =>
                  recording.source == CourseAudioSource.reviewedRecording)),
          isFalse,
        );
      }
    });

    test('rejects an unknown reference locally', () async {
      final FrenchSentencePackageLoader loader = FrenchSentencePackageLoader(
        bundle: _FixtureBundle(syntheticSentencePackage()),
      );

      await expectLater(
        loader.loadAudioForReference('not-a-sentence-reference'),
        throwsA(
          isA<CourseAudioException>().having(
            (error) => error.failure.reason,
            'reason',
            CourseAudioFailureReason.unknownReference,
          ),
        ),
      );
    });

    test('provider exposes the coalesced catalogue loader and catalogue',
        () async {
      final FrenchSentencePackageLoader loader = FrenchSentencePackageLoader(
        bundle: _FixtureBundle(syntheticSentencePackage()),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          sentencePackageLoaderProvider.overrideWithValue(loader),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(sentencePackageLoaderProvider), same(loader));
      final SentenceHuntCatalogue catalogue =
          await container.read(sentenceHuntCatalogueProvider.future);
      expect(catalogue.sections, hasLength(3));
    });

    test('the actual pending packet creates five refs but no recording entries',
        () async {
      final FrenchSentencePackageLoader loader = FrenchSentencePackageLoader(
        bundle: _FileAssetBundle(),
      );

      for (final SentenceHuntSectionSpecification section
          in sentenceHuntSectionSpecifications) {
        final CourseAudioCatalog catalog = await loader.loadAudioForReference(
          section.items.first.audioRefId,
        );
        expect(catalog.references, hasLength(5));
        expect(catalog.entries, isEmpty);
      }
    });
  });
}

final class _FixtureBundle extends AssetBundle {
  _FixtureBundle(
    SentenceHuntPackageFixture fixture, {
    this.gate,
    this.failFirstRead = false,
  }) : _contents = <String, String>{
          'assets/audio/fr-sentences/manifest.json': fixture.manifestJson,
          'assets/audio/fr-sentences/provenance.json': fixture.provenanceJson,
          'assets/audio/fr-sentences/annotations.json': fixture.annotationsJson,
          'assets/audio/fr-sentences/source-evidence.json':
              fixture.sourceEvidenceJson,
        };

  final Map<String, String> _contents;
  final Completer<void>? gate;
  final bool failFirstRead;
  final List<({String key, bool cache})> loads = <({String key, bool cache})>[];
  bool _hasFailed = false;

  @override
  Future<ByteData> load(String key) =>
      Future<ByteData>.error(UnsupportedError('loadString-only test bundle'));

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loads.add((key: key, cache: cache));
    if (failFirstRead && !_hasFailed) {
      _hasFailed = true;
      throw StateError('synthetic first read failure');
    }
    await gate?.future;
    final String? value = _contents[key];
    if (value == null) throw StateError('unknown test asset $key');
    return value;
  }
}

final class _FileAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future<ByteData>.error(UnsupportedError('loadString-only test bundle'));

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
}

void _setOneItemPending(SentenceHuntPackageFixture fixture, String itemId) {
  final Map<String, dynamic> item =
      (fixture.manifest['sections'] as List<Map<String, dynamic>>)
          .expand((section) => section['items'] as List<Map<String, dynamic>>)
          .singleWhere((candidate) => candidate['id'] == itemId);
  item['reviewState'] = 'pending';
  final Map<String, dynamic> annotation =
      (fixture.annotations['entries'] as List<Map<String, dynamic>>)
          .singleWhere((entry) => entry['itemId'] == itemId);
  _pending(annotation['frenchAudioReview'] as Map<String, dynamic>);
  final Map<String, dynamic> provenance =
      (fixture.provenance['entries'] as List<Map<String, dynamic>>)
          .singleWhere((entry) => entry['itemId'] == itemId);
  _pending(provenance['rightsReview'] as Map<String, dynamic>);
}

void _pending(Map<String, dynamic> review) {
  review['status'] = 'pending';
  review['reviewer'] = null;
  review['qualification'] = null;
  review['reviewedAt'] = null;
  review['evidenceIds'] = <String>[];
  review['notes'] = 'Synthetic pending test decision.';
}
