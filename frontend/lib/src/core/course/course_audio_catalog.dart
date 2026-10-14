import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'course_audio_contract.dart';
import 'course_exercise.dart';
import 'french_course.dart';

/// One per-file audio credit for a bundled recording.
///
/// All fields are immutable; [notices] is copied on construction so callers
/// cannot mutate the catalogue's data. [provenanceCaveat] carries a faithful
/// archive caveat for the approved historical `mur` original and is otherwise
/// null.
final class CourseAudioCredit {
  // ignore: prefer_initializing_formals — [notices] is deliberately copied
  // into an unmodifiable view so callers cannot mutate catalogue data.
  CourseAudioCredit({
    required this.referenceId,
    required this.spokenText,
    required this.creator,
    required this.sourceUrl,
    required this.auditedRevisionUrl,
    required this.licenseId,
    required this.licenseUrl,
    required this.licenseTextAssetKey,
    required this.attribution,
    required List<String> notices,
    required this.unchanged,
    this.provenanceCaveat,
  }) : notices = List<String>.unmodifiable(notices);

  final String referenceId;
  final String spokenText;
  final String creator;
  final String sourceUrl;
  final String auditedRevisionUrl;
  final String licenseId;
  final String licenseUrl;
  final String licenseTextAssetKey;
  final String attribution;

  /// An immutable copy of the per-file licence notices.
  final List<String> notices;

  /// True when the bundled binary is the unchanged original.
  final bool unchanged;

  /// A faithful provenance caveat (e.g. the archived `mur` original), or null.
  final String? provenanceCaveat;
}

/// One catalogue entry: a reference, its recordings and its credit.
///
/// Field copies are immutable so a [CourseAudioCatalog] cannot be mutated
/// through its entries.
final class CourseAudioEntry {
  CourseAudioEntry({
    required this.reference,
    required Map<CourseAudioVariant, CourseAudioRecording> recordings,
    required this.credit,
  }) : recordings = Map<CourseAudioVariant, CourseAudioRecording>.unmodifiable(
            recordings);

  final CourseAudioReference reference;
  final Map<CourseAudioVariant, CourseAudioRecording> recordings;
  final CourseAudioCredit credit;
}

/// The bundled, validated pending-reference catalogue.
///
/// Indices are built over the immutable, unique references/entries. Text
/// lookup is exact (byte-for-byte Unicode) equality over `word` references
/// only; no alternate slugs, case-folding, or derived identifiers are used.
final class CourseAudioCatalog {
  CourseAudioCatalog._({
    required this.references,
    required this.entries,
  })  : _byId = {
          for (final CourseAudioReference reference in references) reference.id: reference,
        },
        _byText = {
          // Only word identities participate in the text index; a sound or
          // sentence sharing a word's exact text never displaces it.
          for (final CourseAudioReference reference in references)
            if (reference.kind == AudioReferenceKind.word)
              reference.spokenText: reference,
        };

  /// A shared, independently injected catalogue.
  ///
  /// [references] and [entries] are defensively copied so the caller's
  /// collections cannot mutate the catalogue afterwards, and the exposed
  /// lists are unmodifiable. A reference may represent a missing recording
  /// (no matching entry) and future reference kinds may be mixed in, so
  /// policy tests do not need the shipped manifest. Reference identities
  /// must be unique exactly as authored; two `word` identities may not share
  /// an exact spoken text (that would make word lookup arbitrary); and each
  /// entry must pair with a reference that appears at most once. Throws a
  /// [CourseAudioException] with
  /// [CourseAudioFailureReason.invalidCatalogue] on any violation.
  factory CourseAudioCatalog({
    required List<CourseAudioReference> references,
    required List<CourseAudioEntry> entries,
  }) {
    _validateReferences(references);
    final Set<String> referenceIds = <String>{};
    for (final CourseAudioReference reference in references) {
      referenceIds.add(reference.id);
    }
    final Set<String> entryReferenceIds = <String>{};
    for (final CourseAudioEntry entry in entries) {
      if (!referenceIds.contains(entry.reference.id)) {
        throw _invalid(
            'every entry needs a matching reference; '
            '"${entry.reference.id}" is unknown');
      }
      if (!entryReferenceIds.add(entry.reference.id)) {
        throw _invalid('each reference may own one entry; '
            '"${entry.reference.id}" repeats');
      }
    }
    return CourseAudioCatalog._(
      references: List<CourseAudioReference>.unmodifiable(references),
      entries: List<CourseAudioEntry>.unmodifiable(entries),
    );
  }

  /// Validates the current pending-schema [manifest] against the supplied
  /// [references] (in authored order) and cross-checks the [provenance]
  /// associations. Throws a [CourseAudioException] with
  /// [CourseAudioFailureReason.invalidCatalogue] on any bad metadata.
  factory CourseAudioCatalog.fromJson(
    Map<String, dynamic> manifest,
    Map<String, dynamic> provenance, {
    required List<CourseAudioReference> references,
  }) {
    _validateReferences(references);
    _validateRoot(manifest, 'catalogue manifest');

    final Object? rawEntries = manifest['entries'];
    if (rawEntries is! List) {
      throw _invalid('manifest.entries must be an ordered JSON list');
    }
    final List entries = rawEntries.cast<dynamic>();
    if (entries.length != references.length) {
      throw _invalid(
          'the loader requires exactly ${references.length} word entries in '
          'the authored order, found ${entries.length}');
    }

    final Map<String, Map<String, dynamic>> provenanceById =
        _validateProvenanceRoot(provenance);

    final List<CourseAudioEntry> builtEntries = <CourseAudioEntry>[];
    final Set<String> seenAssetKeys = <String>{};

    for (int i = 0; i < entries.length; i++) {
      final Object? rawEntry = entries[i];
      if (rawEntry is! Map<String, dynamic>) {
        throw _invalid('manifest.entries[$i] must be a JSON object');
      }
      final CourseAudioReference reference = references[i];

      final Object? id = rawEntry['id'];
      if (id != reference.id) {
        throw _invalid(
            'manifest.entries[$i].id is "$id" but the authored reference is '
            '"${reference.id}"');
      }
      final Object? kind = rawEntry['kind'];
      if (kind is! String || kind != reference.kind.name) {
        throw _invalid(
            'manifest.entries[$i].kind must be "${reference.kind.name}"');
      }
      final Object? spokenText = rawEntry['spokenText'];
      if (spokenText is! String || spokenText != reference.spokenText) {
        throw _invalid(
            'manifest.entries[$i].spokenText must exactly equal the authored '
            'text "${reference.spokenText}"');
      }

      builtEntries.add(_buildEntry(
        rawEntry,
        reference,
        provenanceById,
        seenAssetKeys,
      ));
    }

    return CourseAudioCatalog._(
      references: List<CourseAudioReference>.unmodifiable(references),
      entries: List<CourseAudioEntry>.unmodifiable(builtEntries),
    );
  }

  final List<CourseAudioReference> references;
  final List<CourseAudioEntry> entries;

  final Map<String, CourseAudioReference> _byId;
  final Map<String, CourseAudioReference> _byText;

  /// Exact reference-ID lookup (no derivation, no normalization).
  CourseAudioReference? referenceById(String id) => _byId[id];

  /// Exact spoken-text lookup; ASCII-normalised or case-folded spelling
  /// (e.g. `ile` for `île`) does not match.
  CourseAudioReference? wordReferenceByText(String text) => _byText[text];

  /// The bundled recording for [referenceId] and [variant], or null when
  /// that variant was not separately recorded (e.g. `slow`).
  CourseAudioRecording? recordingFor(String referenceId, CourseAudioVariant variant) {
    final CourseAudioReference? reference = _byId[referenceId];
    if (reference == null) return null;
    for (final CourseAudioEntry entry in entries) {
      if (entry.reference.id == reference.id) {
        return entry.recordings[variant];
      }
    }
    return null;
  }

  // ------------------------------------------------------------------
  // Construction / validation helpers (pure, no I/O).
  // ------------------------------------------------------------------

  static CourseAudioException _invalid(String message) =>
      CourseAudioException(CourseAudioFailure(
        reason: CourseAudioFailureReason.invalidCatalogue,
        cause: StateError(message),
      ));

  /// Reference-level invariants shared by the public constructor and the
  /// strict JSON loader: unique identities and unique exact word texts.
  /// Checked before any per-entry work so an identity violation is never
  /// masked by an unrelated entry rejection.
  static void _validateReferences(List<CourseAudioReference> references) {
    final Set<String> seenIds = <String>{};
    final Set<String> seenWordTexts = <String>{};
    for (final CourseAudioReference reference in references) {
      if (!seenIds.add(reference.id)) {
        throw _invalid(
            'reference ids must be unique; "${reference.id}" repeats');
      }
      if (reference.kind == AudioReferenceKind.word &&
          !seenWordTexts.add(reference.spokenText)) {
        throw _invalid(
            'word references must have unique spoken text; '
            '"${reference.spokenText}" repeats');
      }
    }
  }

  static void _validateRoot(Map<String, dynamic> manifest, String label) {
    final Object? schemaVersion = manifest['schemaVersion'];
    if (schemaVersion is! int || schemaVersion != 1) {
      throw _invalid('$label.schemaVersion must be exactly 1');
    }
    if (manifest['catalogueStatus'] != 'candidate') {
      throw _invalid('$label.catalogueStatus must stay "candidate"');
    }
    if (manifest['language'] != 'fr') {
      throw _invalid('$label.language must be "fr"');
    }
  }

  static Map<String, Map<String, dynamic>> _validateProvenanceRoot(
      Map<String, dynamic> provenance) {
    final Object? schemaVersion = provenance['schemaVersion'];
    if (schemaVersion is! int || schemaVersion != 1) {
      throw _invalid('provenance.schemaVersion must be exactly 1');
    }
    final Object? rawEntries = provenance['entries'];
    if (rawEntries is! List) {
      throw _invalid('provenance.entries must be a JSON list');
    }
    final Map<String, Map<String, dynamic>> byId = <String, Map<String, dynamic>>{};
    for (final Object? raw in rawEntries) {
      if (raw is! Map<String, dynamic>) {
        throw _invalid('provenance.entries must hold JSON objects');
      }
      final Object? id = raw['id'];
      if (id is! String || byId.containsKey(id)) {
        throw _invalid('provenance entries must have unique string ids');
      }
      byId[id] = raw;
    }
    return byId;
  }

  static CourseAudioEntry _buildEntry(
    Map<String, dynamic> entry,
    CourseAudioReference reference,
    Map<String, Map<String, dynamic>> provenanceById,
    Set<String> seenAssetKeys,
  ) {
    // --- asset path: safe, registered, then converted exactly once -------
    final Object? rawAssetPath = entry['assetPath'];
    final String assetRepoPath = _validatedAssetPath(rawAssetPath);
    final String assetKey = _stripFrontend(assetRepoPath);
    if (!seenAssetKeys.add(assetKey)) {
      throw _invalid('asset keys must be unique; "$assetKey" repeats');
    }

    // --- required runtime field types ------------------------------------
    final Object? sha256 = entry['sha256'];
    if (sha256 is! String) throw _invalid('entry.sha256 must be a string');
    final Object? byteLength = entry['byteLength'];
    if (byteLength is! int || byteLength <= 0) {
      throw _invalid('entry.byteLength must be a positive integer');
    }

    final Object? rawAudio = entry['audio'];
    if (rawAudio is! Map<String, dynamic>) {
      throw _invalid('entry.audio must be a JSON object');
    }
    _validateAudioProperties(rawAudio);
    final Duration duration = _validatedDuration(rawAudio['durationSeconds']);

    // --- pending review / speaker / changes ------------------------------
    final Object? rawReview = entry['review'];
    if (rawReview is! Map<String, dynamic>) {
      throw _invalid('entry.review must be a JSON object');
    }
    _validatePendingReview(rawReview);

    if (entry['speaker'] is! Map<String, dynamic>) {
      throw _invalid('entry.speaker must be a JSON object');
    }
    final String speakerName =
        _validatedSpeaker(entry['speaker'] as Map<String, dynamic>);
    final Object? rawChanges = entry['changes'];
    if (rawChanges is! List) throw _invalid('entry.changes must be a list');

    // --- licence (manifest side) ----------------------------------------
    final Object? rawLicense = entry['license'];
    if (rawLicense is! Map<String, dynamic>) {
      throw _invalid('entry.license must be a JSON object');
    }
    final Map<String, dynamic> license = rawLicense;
    final String licenseId = _validatedLicenseId(license['spdxId']);
    final String licenseUrl = _validatedLicenseUrl(
        license['url'], licenseId);
    final String licenseTextKey = _validatedLicenseTextPath(
        license['textPath'], licenseId);
    final Object? attribution = license['attribution'];
    if (attribution is! String || attribution.isEmpty) {
      throw _invalid('entry.license.attribution must be a non-empty string');
    }
    final List<String> notices = _validatedNotices(license['notices']);

    // --- provenance association -----------------------------------------
    final Object? provenanceId = entry['provenanceId'];
    if (provenanceId is! String) {
      throw _invalid('entry.provenanceId must be a string');
    }
    final Map<String, dynamic>? record = provenanceById[provenanceId];
    if (record == null) {
      throw _invalid(
          'provenance record "$provenanceId" is missing for this entry');
    }
    final CourseAudioCredit credit = _buildCredit(entry, license, licenseId,
        licenseUrl, licenseTextKey, attribution, notices, record,
        reference, speakerName);

    // --- recordings (normal only; slow must be separately recorded) -----
    final CourseAudioRecording normal = CourseAudioRecording(
      assetKey: assetKey,
      byteLength: byteLength,
      duration: duration,
      source: CourseAudioSource.unverifiedRecording,
    );

    return CourseAudioEntry(
      reference: reference,
      recordings: <CourseAudioVariant, CourseAudioRecording>{
        CourseAudioVariant.normal: normal,
      },
      credit: credit,
    );
  }

  static String _validatedAssetPath(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      throw _invalid('entry.assetPath must be a non-empty string');
    }
    if (raw.contains('://') || raw.startsWith('http://') || raw.startsWith('https://')) {
      throw _invalid('entry.assetPath must be a packaged asset, not a remote URL');
    }
    if (raw.contains('..')) {
      throw _invalid('entry.assetPath must not traverse directories');
    }
    if (raw.startsWith('/')) {
      throw _invalid('entry.assetPath must be repository-relative');
    }
    const String allowedPrefix = 'frontend/assets/audio/fr/words/';
    if (!raw.startsWith(allowedPrefix)) {
      throw _invalid('entry.assetPath must stay within the registered '
          'frontend/assets/audio/fr/words directory');
    }
    return raw;
  }

  /// Removes the repository `frontend/` prefix exactly once.
  static String _stripFrontend(String repositoryPath) {
    const String prefix = 'frontend/';
    if (repositoryPath.startsWith(prefix)) {
      return repositoryPath.substring(prefix.length);
    }
    return repositoryPath;
  }

  static Duration _validatedDuration(Object? raw) {
    final bool integral = raw is int;
    final bool fractional = raw is double;
    if (!integral && !fractional) {
      throw _invalid('audio.durationSeconds must be a finite positive number');
    }
    final num value = raw as num;
    if (value.isNaN) throw _invalid('audio.durationSeconds must be finite');
    if (value.isInfinite) throw _invalid('audio.durationSeconds must be finite');
    if (value <= 0) throw _invalid('audio.durationSeconds must be positive');
    return Duration(microseconds: (value * 1000000).round());
  }

  /// Validates the required runtime audio field types: integers (which in
  /// JSON never include booleans) and a finite positive duration.
  static void _validateAudioProperties(Map<String, dynamic> audio) {
    if (audio['container'] != 'wav') {
      throw _invalid('audio.container must be "wav"');
    }
    if (audio['encoding'] != 'pcm') {
      throw _invalid('audio.encoding must be "pcm"');
    }
    for (final String field in <String>[
      'sampleRateHz',
      'channels',
      'bitsPerSample',
      'frameCount',
    ]) {
      final Object? value = audio[field];
      if (value is! int || value <= 0) {
        throw _invalid('audio.$field must be a positive integer');
      }
    }
    _validatedDuration(audio['durationSeconds']);
  }

  /// The pending schema requires a nonempty source name and the current
  /// unverified qualification; any other value would be an upgraded claim.
  static String _validatedSpeaker(Map<String, dynamic> speaker) {
    final Object? name = speaker['sourceName'];
    if (name is! String || name.isEmpty) {
      throw _invalid('entry.speaker.sourceName must be a non-empty string');
    }
    if (speaker['qualificationStatus'] != 'unverified') {
      throw _invalid(
          'entry.speaker.qualificationStatus must stay "unverified"');
    }
    return name;
  }

  static void _validatePendingReview(Map<String, dynamic> review) {
    if (review['status'] != 'pending') {
      throw _invalid('review.status must stay "pending"');
    }
    if (review['reviewer'] != null) {
      throw _invalid('review.reviewer must be null while review is pending');
    }
    if (review['reviewedAt'] != null) {
      throw _invalid('review.reviewedAt must be null while review is pending');
    }
    final Object? evidence = review['evidence'];
    if (evidence is! List || evidence.isNotEmpty) {
      throw _invalid('review.evidence must be empty while review is pending');
    }
  }

  static String _validatedLicenseId(Object? raw) {
    if (raw is! String) throw _invalid('license.spdxId must be a string');
    final String id = raw;
    const Set<String> allowed = {'CC-BY-SA-4.0', 'CC-BY-4.0'};
    if (!allowed.contains(id)) {
      throw _invalid('license.spdxId "$id" is not a current pending licence');
    }
    return id;
  }

  static String _validatedLicenseUrl(Object? raw, String licenseId) {
    if (raw is! String) {
      throw _invalid('license.url must be a string');
    }
    final String url = raw;
    final Map<String, String> expected = {
      'CC-BY-SA-4.0': 'https://creativecommons.org/licenses/by-sa/4.0/',
      'CC-BY-4.0': 'https://creativecommons.org/licenses/by/4.0/',
    };
    final String? expectedUrl = expected[licenseId];
    if (url != expectedUrl) {
      throw _invalid('license.url does not match licence $licenseId');
    }
    return url;
  }

  static String _validatedLicenseTextPath(Object? raw, String licenseId) {
    if (raw is! String) throw _invalid('license.textPath must be a string');
    final String path = raw;
    if (path.contains('://') || path.contains('..') || path.startsWith('/')) {
      throw _invalid('license.textPath must be a packaged asset path');
    }
    if (!path.startsWith('frontend/assets/audio/fr/licenses/')) {
      throw _invalid('license.textPath must stay within the registered '
          'frontend/assets/audio/fr/licenses directory');
    }
    final String assetKey = _stripFrontend(path);
    const Map<String, String> expected = {
      'CC-BY-SA-4.0': 'assets/audio/fr/licenses/CC-BY-SA-4.0.txt',
      'CC-BY-4.0': 'assets/audio/fr/licenses/CC-BY-4.0.txt',
    };
    if (assetKey != expected[licenseId]) {
      throw _invalid('license.textPath does not match licence $licenseId');
    }
    return assetKey;
  }

  static List<String> _validatedNotices(Object? raw) {
    if (raw is! List) throw _invalid('license.notices must be a list');
    final List<String> notices = <String>[];
    for (final Object? notice in raw) {
      if (notice is! String || notice.isEmpty) {
        throw _invalid('license.notices must hold non-empty strings');
      }
      notices.add(notice);
    }
    if (notices.isEmpty) {
      throw _invalid('license.notices must not be empty');
    }
    return notices;
  }

  static CourseAudioCredit _buildCredit(
    Map<String, dynamic> entry,
    Map<String, dynamic> license,
    String licenseId,
    String licenseUrl,
    String licenseTextKey,
    String attribution,
    List<String> notices,
    Map<String, dynamic> provenance,
    CourseAudioReference reference,
    String speakerName,
  ) {
    // The provenance record must agree with the entry and the manifest
    // licence; any drift is an association error, not a silent fallback.
    final Object? transcription = provenance['sourceTranscription'];
    if (transcription != reference.spokenText) {
      throw _invalid('provenance.sourceTranscription must equal the spoken '
          'text "${reference.spokenText}"');
    }
    // [speakerName] is a required non-empty string (see [_validatedSpeaker],
    // called by the caller), so this consistency check always applies: a
    // missing provenance speaker can no longer slip past a missing entry
    // speaker.
    if (provenance['sourceSpeaker'] != speakerName) {
      throw _invalid('provenance.sourceSpeaker must match the entry speaker');
    }
    final Object? provenanceSha = provenance['sha256'];
    final Object? entrySha = entry['sha256'];
    if (provenanceSha != entrySha) {
      throw _invalid('provenance.sha256 must equal the entry sha256');
    }

    _validateLicenseEvidence(
        provenance, licenseId, licenseUrl, attribution, notices);

    final String creator = _validatedCreator(provenance['creditedCreators'],
        speakerName);

    final bool unchanged =
        (entry['changes'] as List).isEmpty;

    // The approved archived `mur` original is recognised by its archived
    // download URL; the caveat is faithful to that record and applied only
    // where the data actually is archival — never invented elsewhere.
    final String? provenanceCaveat = _archiveCaveatIfArchived(provenance);

    return CourseAudioCredit(
      referenceId: reference.id,
      spokenText: reference.spokenText,
      creator: creator,
      sourceUrl: _validatedHttpUrl(provenance['sourcePageUrl']),
      auditedRevisionUrl: _validatedHttpUrl(provenance['descriptionRevisionUrl']),
      licenseId: licenseId,
      licenseUrl: licenseUrl,
      licenseTextAssetKey: licenseTextKey,
      attribution: attribution,
      notices: notices,
      unchanged: unchanged,
      provenanceCaveat: provenanceCaveat,
    );
  }

  static String _validatedCreator(Object? raw, Object? entrySpeaker) {
    if (raw is! List || raw.isEmpty) {
      throw _invalid('provenance.creditedCreators must be a non-empty list');
    }
    final List<String> creators = <String>[];
    for (final Object? creator in raw) {
      if (creator is! String || creator.isEmpty) {
        throw _invalid('provenance.creditedCreators must hold non-empty strings');
      }
      creators.add(creator);
    }
    if (entrySpeaker != null && creators.first != entrySpeaker) {
      throw _invalid(
          'the credited creator must match the entry speaker name');
    }
    return creators.join(', ');
  }

  static String _validatedHttpUrl(Object? raw) {
    if (raw is! String || !raw.startsWith('https://')) {
      throw _invalid('source/licence URLs must be https');
    }
    return raw;
  }

  static void _validateLicenseEvidence(
    Map<String, dynamic> provenance,
    String manifestLicenseId,
    String manifestLicenseUrl,
    String manifestAttribution,
    List<String> manifestNotices,
  ) {
    final Object? raw = provenance['licenseEvidence'];
    if (raw is! Map<String, dynamic>) {
      throw _invalid('provenance.licenseEvidence must be a JSON object');
    }
    final Map<String, dynamic> evidence = raw;
    if (evidence['spdxId'] != manifestLicenseId) {
      throw _invalid('provenance licence id differs from the manifest licence');
    }
    if (evidence['url'] != manifestLicenseUrl) {
      throw _invalid('provenance licence url differs from the manifest licence');
    }
    if (evidence['creditText'] != manifestAttribution) {
      throw _invalid(
          'provenance credit text differs from the manifest attribution');
    }
    final Object? evidenceNotices = evidence['notices'];
    if (evidenceNotices is! List || evidenceNotices.length != manifestNotices.length) {
      throw _invalid('provenance notices differ from the manifest notices');
    }
    for (int i = 0; i < manifestNotices.length; i++) {
      if (evidenceNotices[i] != manifestNotices[i]) {
        throw _invalid('provenance notices differ from the manifest notices');
      }
    }
  }

  /// Builds a faithful archive caveat for the approved archived original
  /// (the historical `mur`) from its own provenance record, or null when the
  /// record is not archival. The wording is data-faithful and makes no new
  /// historical claim.
  static String? _archiveCaveatIfArchived(Map<String, dynamic> provenance) {
    final Object? downloadUrl = provenance['originalDownloadUrl'];
    if (downloadUrl is! String || !downloadUrl.contains('/commons/archive/')) {
      return null;
    }
    final Object? revisionId = provenance['descriptionRevisionId'];
    if (revisionId is! int) return null;

    // Year from the archived media timestamp, e.g. 2020-01-01T… -> 2020.
    final Object? media = provenance['mediaTimestamp'];
    String year = 'the recorded';
    if (media is String && media.length >= 4) {
      final String candidate = media.substring(0, 4);
      if (candidate.codeUnits.every(
          (int u) => u >= 48 && u <= 57)) {
        year = '$candidate original';
      }
    }
    String? date;
    final Object? retrieved = provenance['retrievedAt'];
    if (retrieved is String && retrieved.length >= 10) {
      final String candidate = retrieved.substring(0, 10);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(candidate)) {
        date = candidate;
      }
    }
    if (date == null) {
      throw _invalid('an archived provenance record needs a retrieved date');
    }

    return 'Provenance caveat: archived original upload (description '
        'revision $revisionId, $year, retrieved $date). The Commons '
        'description shows recorded, unresolved licence conflicts; this is '
        'source provenance, not a current grant.';
  }
}

/// Loads the bundled manifest + provenance through an injectable
/// [AssetBundle], coalesces concurrent loads, caches a successful catalogue,
/// and clears failed in-flight work so a Retry re-reads the assets.
///
/// Constructing the loader does not touch any audio engine.
final class CourseAudioCatalogLoader {
  CourseAudioCatalogLoader({
    required AssetBundle bundle,
    required List<CourseAudioReference> references,
  })  : _bundle = bundle,
        _references = List<CourseAudioReference>.unmodifiable(references);

  final AssetBundle _bundle;
  final List<CourseAudioReference> _references;

  /// The asset bundle backing this loader (for e.g. legal-text reads).
  AssetBundle get bundle => _bundle;

  CourseAudioCatalog? _cached;
  Future<CourseAudioCatalog>? _inFlight;

  Future<CourseAudioCatalog> load() {
    final CourseAudioCatalog? cached = _cached;
    if (cached != null) {
      return Future<CourseAudioCatalog>.value(cached);
    }
    final Future<CourseAudioCatalog>? inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final Future<CourseAudioCatalog> future = _doLoad()
        .whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<CourseAudioCatalog> _doLoad() async {
    try {
      final String manifestRaw = await _bundle.loadString(
          'assets/audio/fr/manifest.json');
      final String provenanceRaw = await _bundle.loadString(
          'assets/audio/fr/provenance.json');

      dynamic manifestJson;
      dynamic provenanceJson;
      try {
        manifestJson = jsonDecode(manifestRaw);
        provenanceJson = jsonDecode(provenanceRaw);
      } on FormatException catch (error, stackTrace) {
        // Keep the actual JSON decode failure as the diagnostic cause
        // instead of replacing it with a generic message.
        throw CourseAudioException(CourseAudioFailure(
          reason: CourseAudioFailureReason.invalidCatalogue,
          cause: error,
          stackTrace: stackTrace,
        ));
      }
      if (manifestJson is! Map<String, dynamic> ||
          provenanceJson is! Map<String, dynamic>) {
        throw CourseAudioException(CourseAudioFailure(
          reason: CourseAudioFailureReason.invalidCatalogue,
          cause: StateError('manifest/provenance root must be a JSON object'),
        ));
      }
      final CourseAudioCatalog catalog = CourseAudioCatalog.fromJson(
        manifestJson,
        provenanceJson,
        references: _references,
      );
      _cached = catalog;
      return catalog;
    } on CourseAudioException {
      rethrow;
    } catch (error, stackTrace) {
      throw CourseAudioException(CourseAudioFailure(
        reason: CourseAudioFailureReason.invalidCatalogue,
        cause: error,
        stackTrace: stackTrace,
      ));
    }
  }
}

/// Provides the pending-catalogue loader using the app's [rootBundle] and the
/// authored [frenchCurriculum.audioReferences]. Constructing this provider
/// does not initialise any audio engine; playback selection is a later task.
final courseAudioCatalogLoaderProvider =
    Provider<CourseAudioCatalogLoader>((ref) {
  return CourseAudioCatalogLoader(
    bundle: rootBundle,
    references: frenchCurriculum.audioReferences,
  );
});
