import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'course_audio_catalog.dart';
import 'course_audio_contract.dart';
import 'course_exercise.dart';
import 'french_sentence_exercises.dart';
import 'sentence_hunt_content.dart';

const String _manifestAsset = 'assets/audio/fr-sentences/manifest.json';
const String _provenanceAsset = 'assets/audio/fr-sentences/provenance.json';
const String _annotationsAsset = 'assets/audio/fr-sentences/annotations.json';
const String _sourceEvidenceAsset =
    'assets/audio/fr-sentences/source-evidence.json';

/// Loads the independent FR08 package without touching the word catalogue.
///
/// Concurrent reads share one future; only a successful immutable catalogue
/// is cached. Failed reads/decode attempts clear their in-flight future so a
/// subsequent explicit call retries all four assets with `cache: false`.
final class FrenchSentencePackageLoader {
  FrenchSentencePackageLoader({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  SentenceHuntCatalogue? _cached;
  Future<SentenceHuntCatalogue>? _inFlight;

  Future<SentenceHuntCatalogue> load() {
    final SentenceHuntCatalogue? cached = _cached;
    if (cached != null) return Future<SentenceHuntCatalogue>.value(cached);
    final Future<SentenceHuntCatalogue>? inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final Future<SentenceHuntCatalogue> pending = _readAndDecode();
    _inFlight = pending;
    return pending.then((SentenceHuntCatalogue catalogue) {
      _cached = catalogue;
      return catalogue;
    }).whenComplete(() {
      _inFlight = null;
    });
  }

  /// Returns the five-reference catalogue for the section owning
  /// [referenceId]. A pending or otherwise unqualified section retains all five
  /// references but has no recording entries. A malformed section fails
  /// locally; no sibling section's availability is affected.
  Future<CourseAudioCatalog> loadAudioForReference(String referenceId) async {
    final SentenceHuntItemSpecification? itemSpec =
        _itemSpecificationForReference(referenceId);
    if (itemSpec == null) {
      throw const CourseAudioException(CourseAudioFailure(
        reason: CourseAudioFailureReason.unknownReference,
      ));
    }
    final SentenceHuntSectionSpecification sectionSpec =
        _sectionSpecificationForItem(itemSpec.id)!;
    final SentenceHuntCatalogue catalogue = await load();
    final SentenceHuntSection section;
    try {
      section = catalogue.section(sectionSpec.id);
    } on Object catch (error, stackTrace) {
      throw CourseAudioException(CourseAudioFailure(
        reason: CourseAudioFailureReason.invalidCatalogue,
        cause: error,
        stackTrace: stackTrace,
      ));
    }
    if (section.items.length != 5 ||
        section.items.any((SentenceHuntItem item) =>
            item.identity.sectionId != sectionSpec.id)) {
      throw CourseAudioException(CourseAudioFailure(
        reason: CourseAudioFailureReason.invalidCatalogue,
        cause: StateError('section must retain its exact five-item shape'),
      ));
    }
    final List<CourseAudioReference> references = <CourseAudioReference>[
      for (final SentenceHuntItem item in section.items) item.reference,
    ];

    if (!catalogue.isAvailable(sectionSpec.id)) {
      return CourseAudioCatalog(
        references: references,
        entries: const <CourseAudioEntry>[],
      );
    }

    final List<SentenceHuntRecordingMetadata?> metadata =
        <SentenceHuntRecordingMetadata?>[
      for (final SentenceHuntItem item in section.items)
        catalogue.recordingMetadataFor(item.reference.id),
    ];
    if (metadata.any((SentenceHuntRecordingMetadata? value) => value == null)) {
      // Availability and evidence are atomic at the section boundary. A
      // missing individual metadata projection must never expose four of five.
      return CourseAudioCatalog(
        references: references,
        entries: const <CourseAudioEntry>[],
      );
    }
    final List<CourseAudioEntry> entries = <CourseAudioEntry>[];
    for (int index = 0; index < section.items.length; index++) {
      final SentenceHuntItem item = section.items[index];
      final SentenceHuntRecordingMetadata recording = metadata[index]!;
      entries.add(CourseAudioEntry(
        reference: item.reference,
        recordings: <CourseAudioVariant, CourseAudioRecording>{
          CourseAudioVariant.normal: CourseAudioRecording(
            assetKey: recording.assetKey,
            byteLength: recording.byteLength,
            duration: recording.duration,
            source: CourseAudioSource.reviewedRecording,
          ),
        },
        credit: recording.credit,
      ));
    }
    return CourseAudioCatalog(references: references, entries: entries);
  }

  Future<SentenceHuntCatalogue> _readAndDecode() async {
    try {
      final List<String> files = await Future.wait<String>(<Future<String>>[
        _bundle.loadString(_manifestAsset, cache: false),
        _bundle.loadString(_provenanceAsset, cache: false),
        _bundle.loadString(_annotationsAsset, cache: false),
        _bundle.loadString(_sourceEvidenceAsset, cache: false),
      ]);
      return decodeFrenchSentencePackage(
        manifestJson: files[0],
        provenanceJson: files[1],
        annotationsJson: files[2],
        sourceEvidenceJson: files[3],
      );
    } on CourseAudioException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw CourseAudioException(CourseAudioFailure(
        reason: CourseAudioFailureReason.invalidCatalogue,
        cause: error,
        stackTrace: stackTrace,
      ));
    }
  }
}

SentenceHuntItemSpecification? _itemSpecificationForReference(
  String referenceId,
) {
  for (final SentenceHuntSectionSpecification section
      in sentenceHuntSectionSpecifications) {
    for (final SentenceHuntItemSpecification item in section.items) {
      if (item.audioRefId == referenceId) return item;
    }
  }
  return null;
}

SentenceHuntSectionSpecification? _sectionSpecificationForItem(String itemId) {
  for (final SentenceHuntSectionSpecification section
      in sentenceHuntSectionSpecifications) {
    if (section.items
        .any((SentenceHuntItemSpecification item) => item.id == itemId)) {
      return section;
    }
  }
  return null;
}

/// The independent sentence loader; this provider does not read or depend on
/// the existing word-only catalogue loader.
final sentencePackageLoaderProvider = Provider<FrenchSentencePackageLoader>(
  (ref) => FrenchSentencePackageLoader(),
);

/// Async access to the validated package catalogue.
final sentenceHuntCatalogueProvider = FutureProvider<SentenceHuntCatalogue>(
  (ref) => ref.watch(sentencePackageLoaderProvider).load(),
);
