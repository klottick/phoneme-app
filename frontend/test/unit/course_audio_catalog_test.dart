import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_audio_catalog.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/french_course.dart';

const String _manifestKey = 'assets/audio/fr/manifest.json';
const String _provenanceKey = 'assets/audio/fr/provenance.json';

Map<String, dynamic> _realManifest() =>
    jsonDecode(File('assets/audio/fr/manifest.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _realProvenance() =>
    jsonDecode(File('assets/audio/fr/provenance.json').readAsStringSync())
        as Map<String, dynamic>;

List<dynamic> _entries(Map<String, dynamic> manifest) =>
    manifest['entries']! as List<dynamic>;

Map<String, dynamic> _entry(Map<String, dynamic> manifest, int index) =>
    _entries(manifest)[index] as Map<String, dynamic>;

/// Test-only fake asset bundle (the asset boundary). It counts real bundle
/// reads and can fail its first reads on purpose. It is the only mock in
/// these tests; expected values are hand-derived from the shipped files.
class _CountingBundle extends AssetBundle {
  _CountingBundle({required this.files, this.failingLoads = 0});

  final Map<String, String> files;
  final int failingLoads;

  int manifestReads = 0;
  int provenanceReads = 0;
  int emittedFailures = 0;

  @override
  Future<ByteData> load(String key) async {
    if (key == _manifestKey) {
      manifestReads++;
    } else if (key == _provenanceKey) {
      provenanceReads++;
    }
    if (emittedFailures < failingLoads) {
      emittedFailures++;
      throw FlutterError('injected bundle read failure: $key');
    }
    final String? content = files[key];
    if (content == null) {
      throw FlutterError('no such test asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

List<int> _bytes(ByteData data) => data.buffer
    .asUint8List(data.offsetInBytes, data.lengthInBytes)
    .toList();

/// Runs [mutate] on fresh copies of the real manifest/provenance, loads
/// through a real [CourseAudioCatalogLoader] over an injected bundle and
/// requires an `invalidCatalogue` rejection.
Future<void> _expectInvalidCatalogue(
  void Function(
    Map<String, dynamic> manifest,
    Map<String, dynamic> provenance,
  ) mutate, {
  List<CourseAudioReference>? references,
}) async {
  final Map<String, dynamic> manifest = jsonDecode(jsonEncode(_realManifest()));
  final Map<String, dynamic> provenance = jsonDecode(jsonEncode(_realProvenance()));
  mutate(manifest, provenance);
  final loader = CourseAudioCatalogLoader(
    bundle: _CountingBundle(
      files: {
        _manifestKey: jsonEncode(manifest),
        _provenanceKey: jsonEncode(provenance),
      },
    ),
    references: references ?? List.of(frenchCurriculum.audioReferences),
  );
  await expectLater(
    loader.load(),
    throwsA(isA<CourseAudioException>().having(
          (CourseAudioException e) => e.failure.reason,
          'failure.reason',
          CourseAudioFailureReason.invalidCatalogue,
        )),
  );
}

/// Same as [_expectInvalidCatalogue], but injects a raw manifest JSON
/// mutation (for values JSON encoding cannot represent, such as literal
/// `NaN`/`Infinity`).
Future<void> _expectRawInvalidCatalogue(
  String Function(String) mutateManifestJson,
) async {
  final loader = CourseAudioCatalogLoader(
    bundle: _CountingBundle(
      files: {
        _manifestKey:
            mutateManifestJson(File('assets/audio/fr/manifest.json').readAsStringSync()),
        _provenanceKey: File('assets/audio/fr/provenance.json').readAsStringSync(),
      },
    ),
    references: List.of(frenchCurriculum.audioReferences),
  );
  await expectLater(
    loader.load(),
    throwsA(isA<CourseAudioException>().having(
          (CourseAudioException e) => e.failure.reason,
          'failure.reason',
          CourseAudioFailureReason.invalidCatalogue,
        )),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final references = frenchCurriculum.audioReferences;
  late CourseAudioCatalogLoader loader;

  setUp(() {
    loader = CourseAudioCatalogLoader(bundle: rootBundle, references: references);
  });

  group('pending bundled catalogue', () {
    test('bundled catalogue preserves exact pending word identities', () async {
      final catalog = await loader.load();
      expect(catalog.entries.length, 24);
      expect(catalog.wordReferenceByText('île')!.id, 'fr-word-île');
      expect(catalog.wordReferenceByText('ile'), isNull);
      expect(catalog.recordingFor('fr-word-tout', CourseAudioVariant.normal)!.source,
          CourseAudioSource.unverifiedRecording);
      expect(catalog.recordingFor('fr-word-tout', CourseAudioVariant.slow), isNull);
    });

    test('entries resolve exactly by id, text and variant', () async {
      final catalog = await loader.load();
      expect(catalog.referenceById('fr-word-île'), isNotNull);
      expect(catalog.referenceById('fr-word-il\u0302e'), isNull);
      expect(catalog.wordReferenceByText('tout')!.id, 'fr-word-tout');
      expect(catalog.recordingFor('fr-word-nope', CourseAudioVariant.normal), isNull);
      // The bundled normal recording is the unchanged pending candidate.
      expect(catalog.recordingFor('fr-word-tout', CourseAudioVariant.normal)!.assetKey,
          'assets/audio/fr/words/tout.wav');
      expect(catalog.recordingFor('fr-word-tout', CourseAudioVariant.normal)!.byteLength,
          66836);
    });

    test('credits carry the exact per-file associations', () async {
      final catalog = await loader.load();
      final tout = catalog.entries[0];
      expect(tout.reference.id, 'fr-word-tout');
      expect(tout.credit.referenceId, 'fr-word-tout');
      expect(tout.credit.spokenText, 'tout');
      expect(tout.credit.creator, 'LoquaxFR');
      expect(tout.credit.sourceUrl,
          'https://commons.wikimedia.org/wiki/File:LL-Q150_(fra)-LoquaxFR-tout.wav');
      expect(tout.credit.auditedRevisionUrl,
          'https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-tout.wav&oldid=995917835');
      expect(tout.credit.licenseId, 'CC-BY-SA-4.0');
      expect(tout.credit.licenseUrl, 'https://creativecommons.org/licenses/by-sa/4.0/');
      expect(tout.credit.licenseTextAssetKey, 'assets/audio/fr/licenses/CC-BY-SA-4.0.txt');
      expect(
          tout.credit.attribution,
          "LoquaxFR (speaker and recorder), 'LL-Q150_(fra)-LoquaxFR-tout.wav', via Wikimedia Commons (CC BY SA 4.0)");
      expect(tout.credit.unchanged, isTrue);
      expect(tout.credit.notices, [
        'attribution – You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.',
        'share alike – If you remix, transform, or build upon the material, you must distribute your contributions under the same or compatible license as the original.',
      ]);

      final sans = catalog.entries[catalog.entries.length - 1];
      expect(sans.reference.id, 'fr-word-sans');
      expect(sans.credit.licenseId, 'CC-BY-4.0');
      expect(sans.credit.licenseTextAssetKey, 'assets/audio/fr/licenses/CC-BY-4.0.txt');
      expect(sans.credit.unchanged, isTrue);

      // Archived mur keeps a faithful caveat; no other entry does.
      final murIndex = catalog.entries.indexWhere((e) => e.reference.id == 'fr-word-mur');
      expect(catalog.entries[murIndex].credit.provenanceCaveat, isNotNull);
      expect(
          catalog.entries
              .where((e) => e.credit.provenanceCaveat != null)
              .map((e) => e.reference.id)
              .toList(),
          ['fr-word-mur']);
    });

    test('registered bytes match originals', () async {
      final manifest = jsonDecode(await rootBundle.loadString(_manifestKey))
          as Map<String, dynamic>;

      // Registration coverage: the bundled loader above already proved
      // manifest/provenance are registered. Under `flutter test` (dev mode)
      // the AssetManifest file is deliberately empty, so coverage of each
      // registered asset is proven by the real rootBundle serving it —
      // unregistered keys would fail with "Unable to load asset".
      final entries = _entries(manifest);
      expect(entries.length, 24);
      for (final dynamic element in entries) {
        final Map<String, dynamic> entry = element;
        final String repositoryPath = entry['assetPath'] as String;
        final String assetKey = repositoryPath.substring('frontend/'.length);
        final List<int> bundled = _bytes(await rootBundle.load(assetKey));
        // The test working directory is `frontend/`, so the shipped original
        // lives at the same once-converted path on disk.
        expect(bundled, File(assetKey).readAsBytesSync(), reason: assetKey);
      }

      // Both complete legal texts are registered and byte-identical.
      for (final String legal in [
        'assets/audio/fr/licenses/CC-BY-4.0.txt',
        'assets/audio/fr/licenses/CC-BY-SA-4.0.txt',
      ]) {
        final List<int> bundled = _bytes(await rootBundle.load(legal));
        expect(bundled, File(legal).readAsBytesSync(), reason: legal);
      }
    });
  });

  group('loader behaviour', () {
    test('failed load is retryable and successful concurrent loads coalesce',
        () async {
      final files = {
        _manifestKey: File('assets/audio/fr/manifest.json').readAsStringSync(),
        _provenanceKey:
            File('assets/audio/fr/provenance.json').readAsStringSync(),
      };

      // A failed load must not poison Retry: a second bundle read happens.
      final failing = _CountingBundle(files: files, failingLoads: 1);
      final failingLoader =
          CourseAudioCatalogLoader(bundle: failing, references: references);
      await expectLater(
        failingLoader.load(),
        throwsA(isA<CourseAudioException>().having(
              (CourseAudioException e) => e.failure.reason,
              'failure.reason',
              CourseAudioFailureReason.invalidCatalogue,
            )),
      );
      final retried = await failingLoader.load();
      expect(retried.entries.length, 24);
      expect(failing.manifestReads, 2,
          reason: 'Retry must perform a new bundle read, not reuse a failed cache');

      // Concurrent successful loads share exactly one read of each asset.
      final shared = _CountingBundle(files: files);
      final sharedLoader =
          CourseAudioCatalogLoader(bundle: shared, references: references);
      final first = sharedLoader.load();
      final second = sharedLoader.load();
      final catalogs = await Future.wait([first, second]);
      expect(catalogs[1], same(catalogs[0]));
      expect(shared.manifestReads, 1);
      expect(shared.provenanceReads, 1);

      // The successful load stays cached, without extra reads.
      await sharedLoader.load();
      expect(shared.manifestReads, 1);
      expect(shared.provenanceReads, 1);
    });
  });

  group('metadata validation (pending schema)', () {
    test('rejects a missing or wrong JSON root', () async {
      await _expectInvalidCatalogue((manifest, provenance) {
        manifest
          ..clear()
          ..['bogus'] = true;
      });
      final wrongRoot = CourseAudioCatalogLoader(
        bundle: _CountingBundle(
          files: {
            _manifestKey: '[]',
            _provenanceKey: jsonEncode(_realProvenance()),
          },
        ),
        references: List.of(frenchCurriculum.audioReferences),
      );
      await expectLater(
        wrongRoot.load(),
        throwsA(isA<CourseAudioException>().having(
              (CourseAudioException e) => e.failure.reason,
              'failure.reason',
              CourseAudioFailureReason.invalidCatalogue,
            )),
      );
    });

    test('rejects an unsupported schema version', () async {
      await _expectInvalidCatalogue((manifest, provenance) {
        manifest['schemaVersion'] = 2;
      });
    });

    test('rejects an unsupported language', () async {
      await _expectInvalidCatalogue((manifest, provenance) {
        manifest['language'] = 'en';
      });
    });

    test('rejects a non-pending catalogue status', () async {
      await _expectInvalidCatalogue((manifest, provenance) {
        manifest['catalogueStatus'] = 'reviewed';
      });
    });

    test('rejects a wrong reference kind or spoken text', () async {
      await _expectInvalidCatalogue((manifest, provenance) {
        _entry(manifest, 0)['kind'] = 'sentence';
      });
      await _expectInvalidCatalogue((manifest, provenance) {
        _entry(manifest, 0)['spokenText'] = 'toutt';
      });
      // ASCII-normalised île is a different identity, not the same word.
      await _expectInvalidCatalogue((manifest, provenance) {
        final index = (manifest['entries'] as List<dynamic>)
            .indexWhere((e) => (e as Map<String, dynamic>)['id'] == 'fr-word-île');
        _entry(manifest, index)['spokenText'] = 'ile';
      });
    });

    test('rejects duplicate reference IDs', () async {
      final Map<String, dynamic> duplicate =
          jsonDecode(jsonEncode(_entry(_realManifest(), 0)));
      await _expectInvalidCatalogue((manifest, provenance) {
        _entries(manifest)[1] = duplicate;
      }, references: [
        CourseAudioReference(
            id: 'fr-word-tout',
            kind: AudioReferenceKind.word,
            spokenText: 'tout'),
        CourseAudioReference(
            id: 'fr-word-tout',
            kind: AudioReferenceKind.word,
            spokenText: 'tout'),
      ]);
    });

    test('rejects duplicate asset paths', () async {
      Map<String, dynamic> clone(String id, String text) {
        final entry = jsonDecode(jsonEncode(_entry(_realManifest(), 0)))
            as Map<String, dynamic>;
        entry['id'] = id;
        entry['spokenText'] = text;
        entry['assetPath'] = 'frontend/assets/audio/fr/words/$text.wav';
        return entry;
      }

      await _expectInvalidCatalogue((manifest, provenance) {
        final first = clone('fr-word-a', 'a');
        final second = clone('fr-word-b', 'b');
        second['assetPath'] = first['assetPath'];
        _entries(manifest)[0] = first;
        _entries(manifest)[1] = second;
      }, references: [
        CourseAudioReference(
            id: 'fr-word-a', kind: AudioReferenceKind.word, spokenText: 'a'),
        CourseAudioReference(
            id: 'fr-word-b', kind: AudioReferenceKind.word, spokenText: 'b'),
      ]);
    });

    test('rejects unsafe and remote asset paths', () async {
      await _expectInvalidCatalogue((manifest, provenance) {
        _entry(manifest, 0)['assetPath'] =
            'frontend/assets/audio/fr/../../secrets.wav';
      });
      await _expectInvalidCatalogue((manifest, provenance) {
        _entry(manifest, 0)['assetPath'] =
            'https://commons.wikimedia.org/wiki/File:LL-Q150_(fra)-LoquaxFR-tout.wav';
      });
      await _expectInvalidCatalogue((manifest, provenance) {
        _entry(manifest, 0)['assetPath'] = '/etc/passwd';
      });
    });

    test('rejects boolean, nonfinite or nonpositive audio properties', () async {
      await _expectInvalidCatalogue((manifest, provenance) {
        (_entry(manifest, 0)['audio'] as Map<String, dynamic>)['channels'] = true;
      });
      // Nonfinite values cannot survive jsonEncode; inject the raw NaN /
      // Infinity literals a bad producer could actually ship.
      await _expectRawInvalidCatalogue(
          (json) => json.replaceAll('0.7572789115646259', 'NaN'));
      await _expectRawInvalidCatalogue(
          (json) => json.replaceAll('0.7572789115646259', 'Infinity'));
      await _expectInvalidCatalogue((manifest, provenance) {
        (_entry(manifest, 0)['audio'] as Map<String, dynamic>)['durationSeconds'] = 0;
      });
      await _expectInvalidCatalogue((manifest, provenance) {
        (_entry(manifest, 0)['audio'] as Map<String, dynamic>)['sampleRateHz'] = -1;
      });
    });

    test('rejects an unknown review status or invented review data', () async {
      await _expectInvalidCatalogue((manifest, provenance) {
        (_entry(manifest, 0)['review'] as Map<String, dynamic>)['status'] = 'reviewed';
      });
      await _expectInvalidCatalogue((manifest, provenance) {
        (_entry(manifest, 0)['review'] as Map<String, dynamic>)['reviewer'] =
            'Invented Reviewer';
      });
      await _expectInvalidCatalogue((manifest, provenance) {
        (_entry(manifest, 0)['review'] as Map<String, dynamic>)['evidence'] =
            <String>['invented'];
      });
    });

    test('rejects mismatched provenance, licence or credit associations',
        () async {
      // Provenance licence disagrees with the manifest licence.
      await _expectInvalidCatalogue((manifest, provenance) {
        ((provenance['entries'] as List<dynamic>)[0] as Map<String, dynamic>)[
                'licenseEvidence']
            ['spdxId'] = 'CC-BY-4.0';
      });
      // Provenance hash disagrees with the manifest hash.
      await _expectInvalidCatalogue((manifest, provenance) {
        ((provenance['entries'] as List<dynamic>)[0] as Map<String, dynamic>)[
            'sha256'] = 'd' * 64;
      });
      // Attribution invented on the manifest side.
      await _expectInvalidCatalogue((manifest, provenance) {
        (_entry(manifest, 0)['license'] as Map<String, dynamic>)['attribution'] =
            'Invented attribution';
      });
      // Wrong retained legal text for the declared licence.
      await _expectInvalidCatalogue((manifest, provenance) {
        (_entry(manifest, 0)['license'] as Map<String, dynamic>)['textPath'] =
            'frontend/assets/audio/fr/licenses/CC-BY-4.0.txt';
      });
      // Provenance transcription disagrees with the spoken text.
      await _expectInvalidCatalogue((manifest, provenance) {
        ((provenance['entries'] as List<dynamic>)[0] as Map<String, dynamic>)[
            'sourceTranscription'] = 'toutt';
      });
      // Notices dropped on the manifest side.
      await _expectInvalidCatalogue((manifest, provenance) {
        (_entry(manifest, 0)['license'] as Map<String, dynamic>)['notices'] =
            <String>[];
      });
    });

    test('rejects a provenance record that belongs to a different word',
        () async {
      await _expectInvalidCatalogue((manifest, provenance) {
        _entry(manifest, 0)['provenanceId'] = 'prov-fr-word-rouge';
      });
      // A missing provenance record at all.
      await _expectInvalidCatalogue((manifest, provenance) {
        _entry(manifest, 0)['provenanceId'] = 'prov-fr-word-nope';
      });
    });

    test('rejects missing or extra coverage against the authored order',
        () async {
      await _expectInvalidCatalogue((manifest, provenance) {
        _entries(manifest).removeAt(0);
      });
      await _expectInvalidCatalogue((manifest, provenance) {
        _entries(manifest).add(jsonDecode(jsonEncode(_entry(_realManifest(), 0))));
      });
      final first = _entries(_realManifest())[0];
      await _expectInvalidCatalogue((m, provenance) {
        final entries = _entries(m);
        entries[0] = entries[1];
        entries[1] = first;
      });
    });
  });

  group('shared audio contract', () {
    test('terminal outcomes are fixed at construction', () {
      const completed = CourseAudioResult.completed(
        referenceId: 'fr-word-tout',
        source: CourseAudioSource.unverifiedRecording,
      );
      expect(completed.outcome, CourseAudioOutcome.completed);
      expect(completed.referenceId, 'fr-word-tout');
      expect(completed.source, CourseAudioSource.unverifiedRecording);
      expect(completed.failure, isNull);

      const cancelled = CourseAudioResult.cancelled();
      expect(cancelled.outcome, CourseAudioOutcome.cancelled);
      expect(cancelled.referenceId, isNull);
      expect(cancelled.source, isNull);
      expect(cancelled.failure, isNull);

      const failed = CourseAudioResult.failed(
        referenceId: 'fr-word-mur',
        source: CourseAudioSource.unverifiedRecording,
        failure: CourseAudioFailure(
            reason: CourseAudioFailureReason.unavailableVariant),
      );
      expect(failed.outcome, CourseAudioOutcome.failed);
      expect(failed.failure!.reason, CourseAudioFailureReason.unavailableVariant);
    });

    test('failures keep their reason and diagnostic cause', () {
      final Object cause = StateError('diagnostic');
      final failure =
          CourseAudioFailure(reason: CourseAudioFailureReason.missingAsset, cause: cause);
      expect(failure.reason, CourseAudioFailureReason.missingAsset);
      expect(failure.cause, same(cause));

      const exception = CourseAudioException(CourseAudioFailure(
          reason: CourseAudioFailureReason.invalidCatalogue));
      expect(exception.failure.reason,
          CourseAudioFailureReason.invalidCatalogue);
      expect(const CourseAudioCancelledException(),
          isNot(isA<CourseAudioException>()));
    });

    test('deadlines bound recorded playback by derived maximums', () {
      const deadlines = CourseAudioDeadlines();
      // Defaults are the alpha bounds from the approved spec.
      expect(deadlines.setup, const Duration(seconds: 10));
      expect(deadlines.cleanup, const Duration(seconds: 5));
      expect(deadlines.ttsUtterance, const Duration(seconds: 12));
      // max(10 s floor, declared duration + 5 s slack).
      expect(deadlines.recordingCompletion(const Duration(seconds: 90)),
          const Duration(seconds: 95));
      expect(deadlines.recordingCompletion(const Duration(milliseconds: 100)),
          const Duration(seconds: 10));
      const custom = CourseAudioDeadlines(
        completionFloor: Duration(seconds: 2),
        completionSlack: Duration(seconds: 1),
      );
      expect(custom.recordingCompletion(const Duration(seconds: 1)),
          const Duration(seconds: 2));
      expect(custom.recordingCompletion(const Duration(seconds: 4)),
          const Duration(seconds: 5));
    });

    test('deadline validate() rejects nonpositive injection', () {
      expect(
          () => const CourseAudioDeadlines(setup: Duration.zero).validate(),
          throwsArgumentError);
      expect(
          () => const CourseAudioDeadlines(cleanup: Duration(milliseconds: -1))
                  .validate(),
          throwsArgumentError);
      expect(() => const CourseAudioDeadlines().validate(), returnsNormally);
    });

    test('a bundled recording can never be a remote source or TTS', () {
      expect(
        () => CourseAudioRecording(
          assetKey: 'assets/audio/fr/words/tout.wav',
          byteLength: 66836,
          duration: const Duration(milliseconds: 757),
          source: CourseAudioSource.practiceTts,
        ),
        throwsStateError,
      );
      expect(
        () => CourseAudioRecording(
          assetKey: 'https://upload.wikimedia.org/wikipedia/commons/tout.wav',
          byteLength: 66836,
          duration: const Duration(milliseconds: 757),
          source: CourseAudioSource.unverifiedRecording,
        ),
        throwsStateError,
      );
      final bundled = CourseAudioRecording(
        assetKey: 'assets/audio/fr/words/tout.wav',
        byteLength: 66836,
        duration: const Duration(milliseconds: 757),
        source: CourseAudioSource.unverifiedRecording,
      );
      expect(bundled.assetKey, 'assets/audio/fr/words/tout.wav');
      expect(bundled.byteLength, 66836);
    });
  });
}
