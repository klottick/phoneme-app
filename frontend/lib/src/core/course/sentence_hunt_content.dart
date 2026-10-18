import 'dart:convert';

import 'course_audio_catalog.dart';
import 'course_exercise.dart';
import 'french_sentence_exercises.dart';
import 'lesson_policy.dart';

/// Sentence-section kinds are deliberately separate from the frozen
/// identification curriculum's phoneme inventory/readiness model.
enum SentenceHuntSectionKind { vowels, consonants, mixed }

/// Stable identity for an item's scored content and its authored sentence.
final class SentenceHuntContentIdentity {
  const SentenceHuntContentIdentity({
    required this.sectionId,
    required this.itemId,
    required this.sentenceId,
    required this.audioRefId,
    required this.annotationHash,
    required this.contentRevision,
    required this.annotationRevision,
  });

  final String sectionId;
  final String itemId;
  final String sentenceId;
  final String audioRefId;
  final String annotationHash;
  final int contentRevision;
  final int annotationRevision;

  @override
  bool operator ==(Object other) =>
      other is SentenceHuntContentIdentity &&
      other.sectionId == sectionId &&
      other.itemId == itemId &&
      other.sentenceId == sentenceId &&
      other.audioRefId == audioRefId &&
      other.annotationHash == annotationHash &&
      other.contentRevision == contentRevision &&
      other.annotationRevision == annotationRevision;

  @override
  int get hashCode => Object.hash(
        sectionId,
        itemId,
        sentenceId,
        audioRefId,
        annotationHash,
        contentRevision,
        annotationRevision,
      );
}

/// One validated exercise's learner-facing projection.
///
/// Source evidence and review notes are not included in this presentation
/// model. Collections are detached and immutable.
final class SentenceHuntItem {
  SentenceHuntItem({
    required this.identity,
    required this.exercise,
    required this.sentence,
    required this.reference,
    required this.targetLabel,
    required this.debriefNote,
    required List<String> selectableTokenIds,
    required List<String> expectedTokenIds,
  })  : selectableTokenIds = List<String>.unmodifiable(selectableTokenIds),
        expectedTokenIds = List<String>.unmodifiable(expectedTokenIds);

  final SentenceHuntContentIdentity identity;
  final SentenceHuntExercise exercise;
  final CourseSentence sentence;
  final CourseAudioReference reference;
  final String targetLabel;
  final String debriefNote;
  final List<String> selectableTokenIds;
  final List<String> expectedTokenIds;
}

/// An immutable current section. Its item list is the authored five-item
/// shape even while review is pending; availability is a separate gate.
final class SentenceHuntSection {
  SentenceHuntSection({
    required this.id,
    required this.title,
    required this.sectionFingerprint,
    required this.kind,
    required this.contentRevision,
    required this.policyRevision,
    required this.policy,
    required List<SentenceHuntItem> items,
  }) : items = List<SentenceHuntItem>.unmodifiable(items);

  final String id;
  final String title;

  /// Canonical UTF-8 JSON content identity, not a digest.
  final String sectionFingerprint;

  final SentenceHuntSectionKind kind;
  final int contentRevision;
  final int policyRevision;
  final LessonPolicy policy;
  final List<SentenceHuntItem> items;
}

/// Stable, deterministic validation feedback.
final class SentenceHuntDiagnostic {
  const SentenceHuntDiagnostic({
    required this.code,
    required this.recordId,
    required this.message,
  });

  final String code;
  final String recordId;
  final String message;
}

/// Retained older identity for Task5 persistence decoding.
///
/// The fingerprint is the complete canonical section-content string used when
/// that revision was current. It is intentionally retained verbatim.
final class SentenceHuntHistoricalDescriptor {
  const SentenceHuntHistoricalDescriptor({
    required this.sectionId,
    required this.kind,
    required this.contentRevision,
    required this.policyRevision,
    required this.completionThresholdPercent,
    required this.sectionFingerprint,
  });

  final String sectionId;
  final SentenceHuntSectionKind kind;
  final int contentRevision;
  final int policyRevision;
  final int completionThresholdPercent;
  final String sectionFingerprint;

  @override
  bool operator ==(Object other) =>
      other is SentenceHuntHistoricalDescriptor &&
      other.sectionId == sectionId &&
      other.kind == kind &&
      other.contentRevision == contentRevision &&
      other.policyRevision == policyRevision &&
      other.completionThresholdPercent == completionThresholdPercent &&
      other.sectionFingerprint == sectionFingerprint;

  @override
  int get hashCode => Object.hash(
        sectionId,
        kind,
        contentRevision,
        policyRevision,
        completionThresholdPercent,
        sectionFingerprint,
      );
}

/// Validated audio facts kept separately from the learner-facing item.
///
/// The package loader consumes these only after the entire section qualifies.
final class SentenceHuntRecordingMetadata {
  const SentenceHuntRecordingMetadata({
    required this.assetKey,
    required this.byteLength,
    required this.duration,
    required this.credit,
  });

  final String assetKey;
  final int byteLength;
  final Duration duration;
  final CourseAudioCredit credit;
}

/// The immutable validated projection of the four independent package files.
final class SentenceHuntCatalogue {
  SentenceHuntCatalogue._({
    required List<SentenceHuntSection> sections,
    required List<SentenceHuntDiagnostic> diagnostics,
    required List<SentenceHuntHistoricalDescriptor> historicalSections,
    required this.hasValidRoot,
    required Map<String, bool> availability,
    required Map<String, List<SentenceHuntDiagnostic>> diagnosticsBySection,
    required Map<String, SentenceHuntRecordingMetadata> recordingsByReference,
    required Set<String> knownSectionIds,
  })  : sections = List<SentenceHuntSection>.unmodifiable(sections),
        diagnostics = List<SentenceHuntDiagnostic>.unmodifiable(diagnostics),
        historicalSections =
            List<SentenceHuntHistoricalDescriptor>.unmodifiable(
                historicalSections),
        _availability = Map<String, bool>.unmodifiable(availability),
        _diagnosticsBySection = <String, List<SentenceHuntDiagnostic>>{
          for (final MapEntry<String, List<SentenceHuntDiagnostic>> entry
              in diagnosticsBySection.entries)
            entry.key: List<SentenceHuntDiagnostic>.unmodifiable(entry.value),
        },
        _recordingsByReference =
            Map<String, SentenceHuntRecordingMetadata>.unmodifiable(
                recordingsByReference),
        _knownSectionIds = Set<String>.unmodifiable(knownSectionIds),
        _sectionsById = <String, SentenceHuntSection>{
          for (final SentenceHuntSection section in sections)
            section.id: section,
        };

  final List<SentenceHuntSection> sections;
  final List<SentenceHuntDiagnostic> diagnostics;
  final List<SentenceHuntHistoricalDescriptor> historicalSections;

  /// Whether all package-level roots and global evidence are structurally valid.
  /// Local section/item faults do not change this value.
  final bool hasValidRoot;

  final Map<String, bool> _availability;
  final Map<String, List<SentenceHuntDiagnostic>> _diagnosticsBySection;
  final Map<String, SentenceHuntRecordingMetadata> _recordingsByReference;
  final Set<String> _knownSectionIds;
  final Map<String, SentenceHuntSection> _sectionsById;

  /// Looks up a structurally complete current section.
  ///
  /// Unknown identities throw [ArgumentError]. A known identity whose local
  /// shape is malformed throws [StateError], never returning a shortened
  /// session.
  SentenceHuntSection section(String sectionId) {
    if (!_knownSectionIds.contains(sectionId)) {
      throw ArgumentError.value(sectionId, 'sectionId', 'is not authored');
    }
    final SentenceHuntSection? section = _sectionsById[sectionId];
    if (section == null) {
      throw StateError('Sentence-hunt section "$sectionId" is malformed');
    }
    return section;
  }

  SentenceHuntItem item(String sectionId, String itemId) {
    final SentenceHuntSection selectedSection = section(sectionId);
    for (final SentenceHuntItem item in selectedSection.items) {
      if (item.identity.itemId == itemId) return item;
    }
    throw ArgumentError.value(itemId, 'itemId', 'is not in "$sectionId"');
  }

  /// Diagnostics for one section, in root/section then item-authored order.
  List<SentenceHuntDiagnostic> diagnosticsFor(String sectionId) =>
      List<SentenceHuntDiagnostic>.unmodifiable(
        _diagnosticsBySection[sectionId] ?? const <SentenceHuntDiagnostic>[],
      );

  /// Only full five-item sections with accepted evidence are available.
  bool isAvailable(String sectionId) => _availability[sectionId] ?? false;

  /// The reviewed recording metadata for an item in an available section.
  /// Unavailable, pending, and rejected items always return null.
  SentenceHuntRecordingMetadata? recordingMetadataFor(String referenceId) =>
      _recordingsByReference[referenceId];
}

/// Returns a canonical, immutable learner selection in authored token order.
/// Unknown, duplicate, punctuation, and otherwise nonselectable IDs are errors.
List<String> canonicalSentenceSelection(
  SentenceHuntItem item,
  Iterable<String> ids,
) {
  final Set<String> selectable = item.selectableTokenIds.toSet();
  final Set<String> requested = <String>{};
  for (final String id in ids) {
    if (!selectable.contains(id)) {
      throw ArgumentError.value(
          id, 'ids', 'is not a selectable sentence token');
    }
    if (!requested.add(id)) {
      throw ArgumentError.value(id, 'ids', 'must not contain duplicates');
    }
  }
  return List<String>.unmodifiable(
    item.selectableTokenIds.where(requested.contains),
  );
}

/// Scores one exact set selection. Empty is valid input and is wrong unless
/// the authored key is empty (valid package keys are never empty).
bool scoreSentenceSelection(SentenceHuntItem item, Iterable<String> ids) {
  final Set<String> selected = canonicalSentenceSelection(item, ids).toSet();
  return selected.length == item.expectedTokenIds.length &&
      selected.containsAll(item.expectedTokenIds);
}

/// Strictly decodes the four files in the shared sentence-package schema.
///
/// This parser verifies declarations and cross-file binding. It deliberately
/// does not compute SHA-256: the offline package verifier owns the actual
/// binary and annotation digests.
SentenceHuntCatalogue decodeFrenchSentencePackage({
  required String manifestJson,
  required String provenanceJson,
  required String annotationsJson,
  required String sourceEvidenceJson,
}) {
  final List<SentenceHuntDiagnostic> rootDiagnostics =
      <SentenceHuntDiagnostic>[];
  final _DecodedRoot manifestRoot = _decodeRoot(
    manifestJson,
    rootId: 'manifest',
    fields: const <String>[
      'schemaVersion',
      'language',
      'courseId',
      'sections',
      'historicalSections',
    ],
    diagnostics: rootDiagnostics,
  );
  final _DecodedRoot provenanceRoot = _decodeRoot(
    provenanceJson,
    rootId: 'provenance',
    fields: const <String>['schemaVersion', 'entries'],
    diagnostics: rootDiagnostics,
  );
  final _DecodedRoot annotationRoot = _decodeRoot(
    annotationsJson,
    rootId: 'annotations',
    fields: const <String>['schemaVersion', 'entries'],
    diagnostics: rootDiagnostics,
  );
  final _DecodedRoot evidenceRoot = _decodeRoot(
    sourceEvidenceJson,
    rootId: 'source-evidence',
    fields: const <String>['schemaVersion', 'entries'],
    diagnostics: rootDiagnostics,
  );

  final Set<String> knownSectionIds = <String>{
    for (final SentenceHuntSectionSpecification spec
        in sentenceHuntSectionSpecifications)
      spec.id,
  };
  final List<SentenceHuntHistoricalDescriptor> historical =
      <SentenceHuntHistoricalDescriptor>[];
  bool rootValid = manifestRoot.valid &&
      provenanceRoot.valid &&
      annotationRoot.valid &&
      evidenceRoot.valid;

  if (manifestRoot.map == null ||
      provenanceRoot.map == null ||
      annotationRoot.map == null ||
      evidenceRoot.map == null) {
    return _emptyCatalogue(
      rootDiagnostics,
      knownSectionIds,
      historical,
    );
  }

  final Map<String, dynamic> manifest = manifestRoot.map!;
  final Map<String, dynamic> provenance = provenanceRoot.map!;
  final Map<String, dynamic> annotations = annotationRoot.map!;
  final Map<String, dynamic> sourceEvidence = evidenceRoot.map!;

  rootValid = _validatePackageRoot(
        manifest,
        rootId: 'manifest',
        language: 'fr',
        courseId: 'en-fr',
        diagnostics: rootDiagnostics,
      ) &&
      rootValid;
  rootValid = _validateRecordRoot(
        provenance,
        rootId: 'provenance',
        diagnostics: rootDiagnostics,
      ) &&
      rootValid;
  rootValid = _validateRecordRoot(
        annotations,
        rootId: 'annotations',
        diagnostics: rootDiagnostics,
      ) &&
      rootValid;
  rootValid = _validateRecordRoot(
        sourceEvidence,
        rootId: 'source-evidence',
        diagnostics: rootDiagnostics,
      ) &&
      rootValid;

  final List<SentenceHuntHistoricalDescriptor>? parsedHistorical =
      _parseHistoricalSections(
    manifest['historicalSections'],
    manifest['sections'],
    diagnostics: rootDiagnostics,
  );
  if (parsedHistorical == null) {
    rootValid = false;
  } else {
    historical.addAll(parsedHistorical);
  }
  if (!rootValid) {
    return _emptyCatalogue(rootDiagnostics, knownSectionIds, historical);
  }

  final Object? rawSections = manifest['sections'];
  if (rawSections is! List) {
    _addDiagnostic(
      rootDiagnostics,
      'manifest_sections',
      'manifest',
      'manifest.sections must be an ordered JSON list',
    );
    return _emptyCatalogue(rootDiagnostics, knownSectionIds, historical);
  }

  bool sectionOrderValid =
      rawSections.length == sentenceHuntSectionSpecifications.length;
  if (!sectionOrderValid) {
    _addDiagnostic(
      rootDiagnostics,
      'section_order',
      'manifest',
      'manifest.sections must contain exactly three authored sections',
    );
  }
  for (int i = 0;
      i < sentenceHuntSectionSpecifications.length && i < rawSections.length;
      i++) {
    final Object? row = rawSections[i];
    final String? actualId = row is Map<String, dynamic> && row['id'] is String
        ? row['id'] as String
        : null;
    if (actualId != sentenceHuntSectionSpecifications[i].id) {
      sectionOrderValid = false;
      _addDiagnostic(
        rootDiagnostics,
        'section_order',
        'manifest',
        'manifest.sections[$i].id must be "'
            '${sentenceHuntSectionSpecifications[i].id}" in authored order',
      );
    }
  }

  final _RecordIndex provenanceIndex = _indexRecords(
    provenance['entries'],
    rootId: 'provenance',
    expectedIds: _allItemIds,
    diagnostics: rootDiagnostics,
  );
  final _RecordIndex annotationIndex = _indexRecords(
    annotations['entries'],
    rootId: 'annotations',
    expectedIds: _allItemIds,
    diagnostics: rootDiagnostics,
  );
  final _RecordIndex evidenceIndex = _indexRecords(
    sourceEvidence['entries'],
    rootId: 'source-evidence',
    expectedIds: null,
    idField: 'id',
    diagnostics: rootDiagnostics,
  );
  final Set<String> referencedEvidenceIds = _referencedEvidenceIds(
    annotationIndex,
    provenanceIndex,
  );
  for (final MapEntry<String, Map<String, dynamic>> entry
      in evidenceIndex.byId.entries) {
    if (referencedEvidenceIds.contains(entry.key)) continue;
    if (!_validateEvidenceRecord(
      entry.value,
      expectedId: entry.key,
      diagnostics: rootDiagnostics,
    )) {
      rootValid = false;
    }
  }
  if (!provenanceIndex.rootValid ||
      !annotationIndex.rootValid ||
      !evidenceIndex.rootValid) {
    rootValid = false;
  }
  if (!rootValid) {
    return _emptyCatalogue(rootDiagnostics, knownSectionIds, historical);
  }

  final List<Map<String, dynamic>?> sectionRows =
      _indexSectionRows(rawSections, rootDiagnostics);
  final List<SentenceHuntSection> sections = <SentenceHuntSection>[];
  final Map<String, List<SentenceHuntDiagnostic>> diagnosticsBySection =
      <String, List<SentenceHuntDiagnostic>>{};
  final Map<String, bool> availability = <String, bool>{};
  final List<_SectionParseResult> parsedSections = <_SectionParseResult>[];

  for (int sectionIndex = 0;
      sectionIndex < sentenceHuntSectionSpecifications.length;
      sectionIndex++) {
    final SentenceHuntSectionSpecification spec =
        sentenceHuntSectionSpecifications[sectionIndex];
    final List<SentenceHuntDiagnostic> local = <SentenceHuntDiagnostic>[];
    final Map<String, dynamic>? sectionRow =
        sectionIndex < sectionRows.length ? sectionRows[sectionIndex] : null;
    final _SectionParseResult result = _parseSection(
      spec,
      sectionRow,
      provenanceIndex,
      annotationIndex,
      evidenceIndex,
      diagnostics: local,
    );
    parsedSections.add(result);
    if (result.section != null) sections.add(result.section!);
    final bool available = rootValid &&
        sectionOrderValid &&
        result.structurallyComplete &&
        result.items.length == spec.items.length &&
        result.items.every((item) => item.contentValid && item.qualifies);
    availability[spec.id] = available;
    diagnosticsBySection[spec.id] = List<SentenceHuntDiagnostic>.of(local);
  }

  _validateMixedRevisits(
    parsedSections,
    diagnosticsBySection,
    availability,
    rootValid && sectionOrderValid,
  );

  final Map<String, SentenceHuntRecordingMetadata> recordings =
      <String, SentenceHuntRecordingMetadata>{};
  for (final _SectionParseResult section in parsedSections) {
    if (availability[section.spec.id] != true) continue;
    for (final _ItemParseResult item in section.items) {
      final SentenceHuntRecordingMetadata? metadata = item.recording;
      if (metadata != null) {
        recordings[item.referenceId] = metadata;
      }
    }
  }

  final List<SentenceHuntDiagnostic> allDiagnostics =
      List<SentenceHuntDiagnostic>.of(rootDiagnostics);
  for (final SentenceHuntSectionSpecification spec
      in sentenceHuntSectionSpecifications) {
    allDiagnostics.addAll(
        diagnosticsBySection[spec.id] ?? const <SentenceHuntDiagnostic>[]);
  }

  return SentenceHuntCatalogue._(
    sections: sections,
    diagnostics: allDiagnostics,
    historicalSections: historical,
    hasValidRoot: rootValid && sectionOrderValid,
    availability: availability,
    diagnosticsBySection: diagnosticsBySection,
    recordingsByReference: recordings,
    knownSectionIds: knownSectionIds,
  );
}

SentenceHuntCatalogue _emptyCatalogue(
  List<SentenceHuntDiagnostic> diagnostics,
  Set<String> knownSectionIds,
  List<SentenceHuntHistoricalDescriptor> historical,
) =>
    SentenceHuntCatalogue._(
      sections: const <SentenceHuntSection>[],
      diagnostics: diagnostics,
      historicalSections: historical,
      hasValidRoot: false,
      availability: <String, bool>{
        for (final String id in knownSectionIds) id: false,
      },
      diagnosticsBySection: <String, List<SentenceHuntDiagnostic>>{
        for (final String id in knownSectionIds)
          id: List<SentenceHuntDiagnostic>.of(diagnostics),
      },
      recordingsByReference: const <String, SentenceHuntRecordingMetadata>{},
      knownSectionIds: knownSectionIds,
    );

Set<String> get _allItemIds => <String>{
      for (final SentenceHuntSectionSpecification section
          in sentenceHuntSectionSpecifications)
        for (final SentenceHuntItemSpecification item in section.items) item.id,
    };

void _addDiagnostic(
  List<SentenceHuntDiagnostic> diagnostics,
  String code,
  String recordId,
  String message,
) {
  diagnostics.add(SentenceHuntDiagnostic(
    code: code,
    recordId: recordId,
    message: message,
  ));
}

final RegExp _wordPattern = RegExp(
  r"[A-Za-zÀ-ÖØ-öø-ÿŒœÆæ]+(?:['’ʼ\-‐‑][A-Za-zÀ-ÖØ-öø-ÿŒœÆæ]+)*",
);

const Set<String> _vowelPhonemes = <String>{
  'i',
  'y',
  'u',
  'e',
  'ø',
  'o',
  'ɛ',
  'œ',
  'ɔ',
  'a',
  'ɑ',
  'ə',
  'ɛ̃',
  'œ̃',
  'ɑ̃',
  'ɔ̃',
};

const Set<String> _consonantPhonemes = <String>{
  'p',
  'b',
  't',
  'd',
  'k',
  'ɡ',
  'f',
  'v',
  's',
  'z',
  'ʃ',
  'ʒ',
  'm',
  'n',
  'ɲ',
  'ŋ',
  'l',
  'ʁ',
  'j',
  'ɥ',
  'w',
};

const Set<String> _allPhonemes = <String>{
  ..._vowelPhonemes,
  ..._consonantPhonemes,
};

final class _DecodedRoot {
  const _DecodedRoot(this.map, this.valid);

  final Map<String, dynamic>? map;
  final bool valid;
}

_DecodedRoot _decodeRoot(
  String json, {
  required String rootId,
  required List<String> fields,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException catch (error) {
    _addDiagnostic(
      diagnostics,
      'invalid_json',
      rootId,
      '$rootId is not valid JSON: ${error.message}',
    );
    return const _DecodedRoot(null, false);
  }
  if (decoded is! Map<String, dynamic>) {
    _addDiagnostic(
      diagnostics,
      'invalid_root',
      rootId,
      '$rootId root must be a JSON object',
    );
    return const _DecodedRoot(null, false);
  }
  final bool exact = _hasExactFields(
    decoded,
    fields,
    recordId: rootId,
    diagnostics: diagnostics,
  );
  return _DecodedRoot(decoded, exact);
}

bool _hasExactFields(
  Map<String, dynamic> value,
  List<String> fields, {
  required String recordId,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  final Set<String> expected = fields.toSet();
  final List<String> missing = <String>[
    for (final String field in fields)
      if (!value.containsKey(field)) field,
  ];
  final List<String> unknown = value.keys
      .where((String key) => !expected.contains(key))
      .toList(growable: false)
    ..sort();
  if (missing.isEmpty && unknown.isEmpty) return true;
  final List<String> problems = <String>[];
  if (missing.isNotEmpty) problems.add('missing ${missing.join(', ')}');
  if (unknown.isNotEmpty) problems.add('unknown ${unknown.join(', ')}');
  _addDiagnostic(
    diagnostics,
    'schema_fields',
    recordId,
    '$recordId has ${problems.join('; ')}',
  );
  return false;
}

bool _validatePackageRoot(
  Map<String, dynamic> manifest, {
  required String rootId,
  required String language,
  required String courseId,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  bool valid = true;
  if (!_isExactInt(manifest['schemaVersion'], 1)) {
    _addDiagnostic(diagnostics, 'root_field', rootId,
        'manifest.schemaVersion must be the integer 1');
    valid = false;
  }
  if (manifest['language'] != language) {
    _addDiagnostic(diagnostics, 'root_field', rootId,
        'manifest.language must be "$language"');
    valid = false;
  }
  if (manifest['courseId'] != courseId) {
    _addDiagnostic(diagnostics, 'root_field', rootId,
        'manifest.courseId must be "$courseId"');
    valid = false;
  }
  return valid;
}

bool _validateRecordRoot(
  Map<String, dynamic> root, {
  required String rootId,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  if (!_isExactInt(root['schemaVersion'], 1)) {
    _addDiagnostic(diagnostics, 'root_field', rootId,
        '$rootId.schemaVersion must be the integer 1');
    return false;
  }
  if (root['entries'] is! List) {
    _addDiagnostic(diagnostics, 'root_field', rootId,
        '$rootId.entries must be an ordered JSON list');
    return false;
  }
  return true;
}

bool _isExactInt(Object? value, int expected) =>
    value is int && value == expected;

List<SentenceHuntHistoricalDescriptor>? _parseHistoricalSections(
  Object? raw,
  Object? currentSections, {
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  if (raw is! List) {
    _addDiagnostic(diagnostics, 'historical_schema', 'manifest',
        'manifest.historicalSections must be a JSON list');
    return null;
  }
  final Map<String, Map<String, dynamic>> currentById =
      <String, Map<String, dynamic>>{};
  if (currentSections is List) {
    for (final Object? row in currentSections) {
      if (row is Map<String, dynamic> && row['id'] is String) {
        currentById[row['id'] as String] = row;
      }
    }
  }
  final List<SentenceHuntHistoricalDescriptor> descriptors =
      <SentenceHuntHistoricalDescriptor>[];
  final Set<String> identities = <String>{};
  bool valid = true;
  for (int index = 0; index < raw.length; index++) {
    final Object? value = raw[index];
    final String recordId = 'historicalSections[$index]';
    if (value is! Map<String, dynamic>) {
      _addDiagnostic(diagnostics, 'historical_schema', 'manifest',
          '$recordId must be a JSON object');
      valid = false;
      continue;
    }
    bool descriptorValid = _hasExactFields(
      value,
      const <String>[
        'sectionId',
        'kind',
        'contentRevision',
        'policyRevision',
        'completionThresholdPercent',
        'sectionFingerprint',
      ],
      recordId: 'manifest',
      diagnostics: diagnostics,
    );
    final String? sectionId = _readString(
      value,
      'sectionId',
      recordId: 'manifest',
      diagnostics: diagnostics,
      code: 'historical_schema',
    );
    final String? kindValue = _readString(
      value,
      'kind',
      recordId: 'manifest',
      diagnostics: diagnostics,
      code: 'historical_schema',
    );
    final SentenceHuntSectionKind? kind =
        kindValue == null ? null : _sectionKind(kindValue);
    if (kindValue != null && kind == null) {
      _addDiagnostic(diagnostics, 'historical_schema', 'manifest',
          '$recordId.kind is not a sentence-hunt section kind');
      descriptorValid = false;
    }
    final int? contentRevision = _readPositiveInt(
      value,
      'contentRevision',
      recordId: 'manifest',
      diagnostics: diagnostics,
      code: 'historical_schema',
    );
    final int? policyRevision = _readPositiveInt(
      value,
      'policyRevision',
      recordId: 'manifest',
      diagnostics: diagnostics,
      code: 'historical_schema',
    );
    final int? threshold = _readIntRange(
      value,
      'completionThresholdPercent',
      minimum: 1,
      maximum: 100,
      recordId: 'manifest',
      diagnostics: diagnostics,
      code: 'historical_schema',
    );
    if (policyRevision == 1 && threshold != null && threshold != 80) {
      _addDiagnostic(
        diagnostics,
        'historical_policy_threshold',
        'manifest',
        '$recordId policy revision 1 must retain the 80-percent threshold',
      );
      descriptorValid = false;
    }
    final String? fingerprint = _readString(
      value,
      'sectionFingerprint',
      recordId: 'manifest',
      diagnostics: diagnostics,
      code: 'historical_schema',
    );
    if (fingerprint != null && !_isCanonicalJsonObject(fingerprint)) {
      _addDiagnostic(diagnostics, 'historical_schema', 'manifest',
          '$recordId.sectionFingerprint must be a canonical JSON object string');
      descriptorValid = false;
    }
    final SentenceHuntSectionSpecification? spec =
        sectionId == null ? null : _specificationForSection(sectionId);
    final Map<String, dynamic>? current =
        sectionId == null ? null : currentById[sectionId];
    if (spec == null || current == null || kind != _sectionKind(spec.kind)) {
      _addDiagnostic(diagnostics, 'historical_schema', 'manifest',
          '$recordId must identify an authored historical section');
      descriptorValid = false;
    }
    if (contentRevision != null &&
        policyRevision != null &&
        current != null &&
        ((current['contentRevision'] is int &&
                contentRevision > (current['contentRevision'] as int)) ||
            (current['policyRevision'] is int &&
                policyRevision > (current['policyRevision'] as int)) ||
            (current['contentRevision'] == contentRevision &&
                current['policyRevision'] == policyRevision))) {
      _addDiagnostic(diagnostics, 'historical_revision', 'manifest',
          '$recordId must be older than its current content or policy revision');
      descriptorValid = false;
    }
    if (sectionId != null &&
        contentRevision != null &&
        policyRevision != null &&
        fingerprint != null &&
        !identities.add('$sectionId\u0000$contentRevision\u0000'
            '$policyRevision\u0000$fingerprint')) {
      _addDiagnostic(diagnostics, 'historical_duplicate', 'manifest',
          '$recordId duplicates a retained historical identity');
      descriptorValid = false;
    }
    if (descriptorValid &&
        sectionId != null &&
        kind != null &&
        contentRevision != null &&
        policyRevision != null &&
        threshold != null &&
        fingerprint != null) {
      descriptors.add(SentenceHuntHistoricalDescriptor(
        sectionId: sectionId,
        kind: kind,
        contentRevision: contentRevision,
        policyRevision: policyRevision,
        completionThresholdPercent: threshold,
        sectionFingerprint: fingerprint,
      ));
    } else {
      valid = false;
    }
  }
  return valid ? descriptors : null;
}

bool _isCanonicalJsonObject(String value) {
  try {
    final Object? decoded = jsonDecode(value);
    return decoded is Map<String, dynamic> && _canonicalJson(decoded) == value;
  } on FormatException {
    return false;
  }
}

SentenceHuntSectionSpecification? _specificationForSection(String id) {
  for (final SentenceHuntSectionSpecification spec
      in sentenceHuntSectionSpecifications) {
    if (spec.id == id) return spec;
  }
  return null;
}

SentenceHuntSectionKind? _sectionKind(String value) => switch (value) {
      'vowels' => SentenceHuntSectionKind.vowels,
      'consonants' => SentenceHuntSectionKind.consonants,
      'mixed' => SentenceHuntSectionKind.mixed,
      _ => null,
    };

final class _RecordIndex {
  const _RecordIndex({
    required this.byId,
    required this.duplicateIds,
    required this.rootValid,
  });

  final Map<String, Map<String, dynamic>> byId;
  final Set<String> duplicateIds;
  final bool rootValid;
}

Set<String> _referencedEvidenceIds(
  _RecordIndex annotations,
  _RecordIndex provenance,
) {
  final Set<String> ids = <String>{};
  void collect(Object? value) {
    if (value is! Map<String, dynamic>) return;
    final Object? rawIds = value['evidenceIds'];
    if (rawIds is List) {
      ids.addAll(rawIds.whereType<String>());
    }
  }

  for (final Map<String, dynamic> annotation in annotations.byId.values) {
    collect(annotation['frenchAudioReview']);
  }
  for (final Map<String, dynamic> record in provenance.byId.values) {
    collect(record['rightsReview']);
    collect(record['credit']);
  }
  return ids;
}

_RecordIndex _indexRecords(
  Object? raw, {
  required String rootId,
  required Set<String>? expectedIds,
  String idField = 'itemId',
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  if (raw is! List) {
    _addDiagnostic(diagnostics, 'record_list', rootId,
        '$rootId.entries must be a JSON list');
    return const _RecordIndex(
      byId: <String, Map<String, dynamic>>{},
      duplicateIds: <String>{},
      rootValid: false,
    );
  }
  bool rootValid = true;
  if (expectedIds != null && raw.length != expectedIds.length) {
    _addDiagnostic(diagnostics, 'record_count', rootId,
        '$rootId.entries must contain ${expectedIds.length} records');
  }
  final Map<String, Map<String, dynamic>> byId =
      <String, Map<String, dynamic>>{};
  final Set<String> duplicates = <String>{};
  for (int index = 0; index < raw.length; index++) {
    final Object? row = raw[index];
    if (row is! Map<String, dynamic>) {
      _addDiagnostic(diagnostics, 'record_shape', rootId,
          '$rootId.entries[$index] must be a JSON object');
      rootValid = false;
      continue;
    }
    final Object? rawId = row[idField];
    if (rawId is! String || rawId.trim().isEmpty) {
      _addDiagnostic(diagnostics, 'record_id', rootId,
          '$rootId.entries[$index].$idField must be a nonblank string');
      rootValid = false;
      continue;
    }
    final String id = rawId;
    if (expectedIds != null && !expectedIds.contains(id)) {
      _addDiagnostic(diagnostics, 'unexpected_record', rootId,
          '$rootId contains unexpected record "$id"');
      rootValid = false;
    }
    if (byId.containsKey(id)) {
      duplicates.add(id);
      byId.remove(id);
      _addDiagnostic(diagnostics, 'duplicate_record', rootId,
          '$rootId contains duplicate record "$id"');
      continue;
    }
    if (!duplicates.contains(id)) byId[id] = row;
  }
  return _RecordIndex(
    byId: Map<String, Map<String, dynamic>>.unmodifiable(byId),
    duplicateIds: Set<String>.unmodifiable(duplicates),
    rootValid: rootValid,
  );
}

List<Map<String, dynamic>?> _indexSectionRows(
  List raw,
  List<SentenceHuntDiagnostic> diagnostics,
) {
  final List<Map<String, dynamic>?> result = <Map<String, dynamic>?>[];
  final Set<String> seen = <String>{};
  for (int index = 0; index < raw.length; index++) {
    final Object? row = raw[index];
    if (row is! Map<String, dynamic>) {
      _addDiagnostic(diagnostics, 'section_shape', 'manifest',
          'manifest.sections[$index] must be a JSON object');
      result.add(null);
      continue;
    }
    final Object? id = row['id'];
    if (id is! String || id.trim().isEmpty) {
      _addDiagnostic(diagnostics, 'section_id', 'manifest',
          'manifest.sections[$index].id must be a nonblank string');
      result.add(null);
      continue;
    }
    if (!seen.add(id)) {
      _addDiagnostic(diagnostics, 'duplicate_section', 'manifest',
          'manifest section "$id" is duplicated');
    }
    result.add(row);
  }
  return result;
}

final class _SectionParseResult {
  const _SectionParseResult({
    required this.spec,
    required this.section,
    required this.items,
    required this.structurallyComplete,
  });

  final SentenceHuntSectionSpecification spec;
  final SentenceHuntSection? section;
  final List<_ItemParseResult> items;
  final bool structurallyComplete;
}

final class _ItemParseResult {
  const _ItemParseResult({
    required this.spec,
    required this.item,
    required this.contentValid,
    required this.qualifies,
    required this.targetSound,
    required this.recording,
    required this.originalSha,
    required this.clipSha,
  });

  final SentenceHuntItemSpecification spec;
  final SentenceHuntItem? item;
  final bool contentValid;
  final bool qualifies;
  final String? targetSound;
  final SentenceHuntRecordingMetadata? recording;
  final String? originalSha;
  final String? clipSha;

  String get referenceId => spec.audioRefId;
}

_SectionParseResult _parseSection(
  SentenceHuntSectionSpecification spec,
  Map<String, dynamic>? row,
  _RecordIndex provenance,
  _RecordIndex annotations,
  _RecordIndex evidence, {
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  bool sectionValid = row != null;
  if (row == null) {
    _addDiagnostic(diagnostics, 'missing_section', spec.id,
        'manifest is missing section "${spec.id}"');
    return _SectionParseResult(
      spec: spec,
      section: null,
      items: const <_ItemParseResult>[],
      structurallyComplete: false,
    );
  }
  sectionValid = _hasExactFields(
        row,
        const <String>[
          'id',
          'kind',
          'title',
          'contentRevision',
          'policyRevision',
          'completionThresholdPercent',
          'items',
        ],
        recordId: spec.id,
        diagnostics: diagnostics,
      ) &&
      sectionValid;
  final String? id = _readString(
    row,
    'id',
    recordId: spec.id,
    diagnostics: diagnostics,
  );
  final String? kindValue = _readString(
    row,
    'kind',
    recordId: spec.id,
    diagnostics: diagnostics,
  );
  final String? title = _readString(
    row,
    'title',
    recordId: spec.id,
    diagnostics: diagnostics,
  );
  final int? contentRevision = _readPositiveInt(
    row,
    'contentRevision',
    recordId: spec.id,
    diagnostics: diagnostics,
  );
  final int? policyRevision = _readPositiveInt(
    row,
    'policyRevision',
    recordId: spec.id,
    diagnostics: diagnostics,
  );
  final int? threshold = _readIntRange(
    row,
    'completionThresholdPercent',
    minimum: 1,
    maximum: 100,
    recordId: spec.id,
    diagnostics: diagnostics,
  );
  if (policyRevision == 1 && threshold != null && threshold != 80) {
    _addDiagnostic(
      diagnostics,
      'policy_threshold',
      spec.id,
      'policy revision 1 must use the initial 80-percent threshold',
    );
    sectionValid = false;
  }
  final SentenceHuntSectionKind expectedKind = _sectionKind(spec.kind)!;
  if (id != spec.id) {
    _addDiagnostic(diagnostics, 'section_identity', spec.id,
        'section id must be "${spec.id}"');
    sectionValid = false;
  }
  if (kindValue != spec.kind) {
    _addDiagnostic(diagnostics, 'section_kind', spec.id,
        'section kind must be "${spec.kind}"');
    sectionValid = false;
  }
  final Object? rawItems = row['items'];
  if (rawItems is! List) {
    _addDiagnostic(diagnostics, 'section_items', spec.id,
        'section.items must be an ordered JSON list');
    sectionValid = false;
  }
  final List<_ItemParseResult> parsedItems = <_ItemParseResult>[];
  if (rawItems is List) {
    for (int index = 0; index < spec.items.length; index++) {
      final SentenceHuntItemSpecification itemSpec = spec.items[index];
      final Object? rawItem = index < rawItems.length ? rawItems[index] : null;
      final Map<String, dynamic>? itemRow =
          rawItem is Map<String, dynamic> ? rawItem : null;
      if (rawItem != null && itemRow == null) {
        _addDiagnostic(diagnostics, 'item_shape', itemSpec.id,
            '${spec.id}.items[$index] must be a JSON object');
      }
      parsedItems.add(_parseItem(
        spec,
        itemSpec,
        itemRow,
        provenance,
        annotations,
        evidence,
        contentRevision: contentRevision,
        diagnostics: diagnostics,
      ));
    }
    if (rawItems.length != spec.items.length) {
      _addDiagnostic(diagnostics, 'item_count', spec.id,
          'section "${spec.id}" must contain exactly five authored items');
      sectionValid = false;
    }
  }

  final List<SentenceHuntItem> models = <SentenceHuntItem>[
    for (final _ItemParseResult parsed in parsedItems)
      if (parsed.item != null) parsed.item!,
  ];
  final bool completeItems = parsedItems.length == spec.items.length &&
      models.length == spec.items.length;
  if (!completeItems) sectionValid = false;

  final SentenceHuntSection? section = title != null &&
          contentRevision != null &&
          policyRevision != null &&
          threshold != null &&
          completeItems
      ? SentenceHuntSection(
          id: spec.id,
          title: title,
          sectionFingerprint: _sectionFingerprint(
            row,
            parsedItems,
            spec: spec,
            kind: expectedKind,
          ),
          kind: expectedKind,
          contentRevision: contentRevision,
          policyRevision: policyRevision,
          policy: LessonPolicy(
            completionThresholdPercent: threshold,
          ),
          items: models,
        )
      : null;
  return _SectionParseResult(
    spec: spec,
    section: section,
    items: List<_ItemParseResult>.unmodifiable(parsedItems),
    structurallyComplete: sectionValid && section != null,
  );
}

_ItemParseResult _parseItem(
  SentenceHuntSectionSpecification sectionSpec,
  SentenceHuntItemSpecification itemSpec,
  Map<String, dynamic>? row,
  _RecordIndex provenanceIndex,
  _RecordIndex annotationIndex,
  _RecordIndex evidenceIndex, {
  required int? contentRevision,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  bool contentValid = row != null;
  if (row == null) {
    _addDiagnostic(diagnostics, 'missing_item', itemSpec.id,
        'manifest is missing item "${itemSpec.id}"');
    return _ItemParseResult(
      spec: itemSpec,
      item: null,
      contentValid: false,
      qualifies: false,
      targetSound: null,
      recording: null,
      originalSha: null,
      clipSha: null,
    );
  }
  contentValid = _hasExactFields(
        row,
        const <String>[
          'id',
          'sentenceId',
          'audioRefId',
          'purpose',
          'reviewState',
          'targetSound',
          'targetLabel',
          'text',
          'debriefNote',
          'annotationRevision',
          'annotationHash',
          'tokens',
          'expectedTokenIds',
          'originalPath',
          'clipPath',
          'originalSha256',
          'clipSha256',
        ],
        recordId: itemSpec.id,
        diagnostics: diagnostics,
      ) &&
      contentValid;

  final String? id =
      _readString(row, 'id', recordId: itemSpec.id, diagnostics: diagnostics);
  final String? sentenceId = _readString(row, 'sentenceId',
      recordId: itemSpec.id, diagnostics: diagnostics);
  final String? audioRefId = _readString(row, 'audioRefId',
      recordId: itemSpec.id, diagnostics: diagnostics);
  final String? purpose = _readString(row, 'purpose',
      recordId: itemSpec.id, diagnostics: diagnostics);
  final String? reviewState = _readString(row, 'reviewState',
      recordId: itemSpec.id, diagnostics: diagnostics);
  final String? targetSound = _readString(row, 'targetSound',
      recordId: itemSpec.id, diagnostics: diagnostics);
  final String? targetLabel = _readString(row, 'targetLabel',
      recordId: itemSpec.id, diagnostics: diagnostics);
  final String? text =
      _readString(row, 'text', recordId: itemSpec.id, diagnostics: diagnostics);
  final String? debriefNote = _readString(row, 'debriefNote',
      recordId: itemSpec.id, diagnostics: diagnostics);
  final int? annotationRevision = _readPositiveInt(
    row,
    'annotationRevision',
    recordId: itemSpec.id,
    diagnostics: diagnostics,
  );
  final String? annotationHash = _readString(row, 'annotationHash',
      recordId: itemSpec.id, diagnostics: diagnostics);
  final String? originalPath = _readString(row, 'originalPath',
      recordId: itemSpec.id, diagnostics: diagnostics);
  final String? clipPath = _readString(row, 'clipPath',
      recordId: itemSpec.id, diagnostics: diagnostics);
  final String? originalSha = _readString(row, 'originalSha256',
      recordId: itemSpec.id, diagnostics: diagnostics);
  final String? clipSha = _readString(row, 'clipSha256',
      recordId: itemSpec.id, diagnostics: diagnostics);

  final bool fieldsPresent = <String?>[
        id,
        sentenceId,
        audioRefId,
        purpose,
        reviewState,
        targetSound,
        targetLabel,
        text,
        debriefNote,
        annotationHash,
        originalPath,
        clipPath,
        originalSha,
        clipSha,
      ].every((String? value) => value != null && value.trim().isNotEmpty) &&
      annotationRevision != null &&
      contentRevision != null;
  if (!fieldsPresent) contentValid = false;

  if (id != itemSpec.id) {
    _addDiagnostic(diagnostics, 'item_identity', itemSpec.id,
        'item id must be "${itemSpec.id}"');
    contentValid = false;
  }
  if (sentenceId != itemSpec.sentenceId) {
    _addDiagnostic(diagnostics, 'item_identity', itemSpec.id,
        'sentenceId must be "${itemSpec.sentenceId}"');
    contentValid = false;
  }
  if (audioRefId != itemSpec.audioRefId) {
    _addDiagnostic(diagnostics, 'item_identity', itemSpec.id,
        'audioRefId must be "${itemSpec.audioRefId}"');
    contentValid = false;
  }
  if (purpose != 'practice') {
    _addDiagnostic(diagnostics, 'item_purpose', itemSpec.id,
        'item purpose must be "practice"');
    contentValid = false;
  }
  if (reviewState != 'pending' && reviewState != 'reviewed') {
    _addDiagnostic(diagnostics, 'review_state', itemSpec.id,
        'reviewState must be "pending" or "reviewed"');
    contentValid = false;
  }
  if (targetSound != null) {
    final bool roleMatches = itemSpec.targetRole == SentenceHuntTargetRole.vowel
        ? _vowelPhonemes.contains(targetSound)
        : _consonantPhonemes.contains(targetSound);
    if (!roleMatches) {
      _addDiagnostic(
          diagnostics,
          'target_role',
          itemSpec.id,
          'targetSound "$targetSound" is not an authored '
              '${itemSpec.targetRole.name} phoneme');
      contentValid = false;
    }
    final String roleName = itemSpec.targetRole == SentenceHuntTargetRole.vowel
        ? 'vowel'
        : 'consonant';
    if (targetLabel != 'French $roleName /$targetSound/') {
      _addDiagnostic(diagnostics, 'target_label', itemSpec.id,
          'targetLabel must exactly identify French $roleName /$targetSound/');
      contentValid = false;
    }
  }
  if (originalPath != 'originals/${itemSpec.id}.wav' ||
      clipPath != 'clips/${itemSpec.id}.wav') {
    _addDiagnostic(diagnostics, 'audio_path', itemSpec.id,
        'originalPath and clipPath must stay on this item’s authored package paths');
    contentValid = false;
  }
  if (originalSha != null && !_isSha256(originalSha)) {
    _addDiagnostic(diagnostics, 'hash_shape', itemSpec.id,
        'originalSha256 must be lowercase 64-character SHA-256 hex');
    contentValid = false;
  }
  if (clipSha != null && !_isSha256(clipSha)) {
    _addDiagnostic(diagnostics, 'hash_shape', itemSpec.id,
        'clipSha256 must be lowercase 64-character SHA-256 hex');
    contentValid = false;
  }
  if (annotationHash != null && !_isSha256(annotationHash)) {
    _addDiagnostic(diagnostics, 'hash_shape', itemSpec.id,
        'annotationHash must be lowercase 64-character SHA-256 hex');
    contentValid = false;
  }

  final _TokenParseResult tokenResult = _parseTokens(
    row['tokens'],
    itemId: itemSpec.id,
    diagnostics: diagnostics,
  );
  final List<SentenceToken>? tokens = tokenResult.tokens;
  contentValid = tokenResult.valid && contentValid;
  final _StringListResult expectedResult = _readStringList(
    row['expectedTokenIds'],
    field: 'expectedTokenIds',
    recordId: itemSpec.id,
    diagnostics: diagnostics,
    unique: true,
  );
  final List<String>? expectedTokenIds = expectedResult.values;
  contentValid = expectedResult.valid && contentValid;

  if (text != null && tokens != null) {
    final List<String> words = _wordPattern
        .allMatches(text)
        .map((RegExpMatch match) => match.group(0)!)
        .toList(growable: false);
    final List<String> tokenTexts =
        tokens.map((SentenceToken token) => token.text).toList(growable: false);
    if (!_sameList(words, tokenTexts)) {
      _addDiagnostic(diagnostics, 'tokenization', itemSpec.id,
          'tokens must be exactly the ordered written-word units in text');
      contentValid = false;
    }
  }
  if (targetSound != null && tokens != null && expectedTokenIds != null) {
    final List<String> allTargetTokens = tokens
        .where((SentenceToken token) => token.phonemes.contains(targetSound))
        .map((SentenceToken token) => token.id)
        .toList(growable: false);
    if (allTargetTokens.isEmpty ||
        !_sameList(allTargetTokens, expectedTokenIds)) {
      _addDiagnostic(diagnostics, 'expected_token_set', itemSpec.id,
          'expectedTokenIds must exactly cover every authored $targetSound token');
      contentValid = false;
    }
  }

  final Map<String, dynamic>? annotation = _recordFor(
    annotationIndex,
    itemSpec.id,
    rootId: 'annotations',
    diagnostics: diagnostics,
  );
  final _AnnotationResult annotationResult = _parseAnnotation(
    itemSpec.id,
    annotation,
    tokens,
    annotationRevision: annotationRevision,
    annotationHash: annotationHash,
    originalSha: originalSha,
    clipSha: clipSha,
    evidence: evidenceIndex,
    diagnostics: diagnostics,
  );
  contentValid = annotationResult.valid && contentValid;

  final Map<String, dynamic>? provenanceRecord = _recordFor(
    provenanceIndex,
    itemSpec.id,
    rootId: 'provenance',
    diagnostics: diagnostics,
  );
  final _ProvenanceResult provenanceResult = _parseProvenance(
    itemSpec.id,
    provenanceRecord,
    text: text,
    originalPath: originalPath,
    clipPath: clipPath,
    originalSha: originalSha,
    clipSha: clipSha,
    annotationHash: annotationHash,
    evidence: evidenceIndex,
    diagnostics: diagnostics,
  );
  contentValid = provenanceResult.valid && contentValid;

  final _ValidatedReview? frenchReview = annotationResult.review;
  final _ValidatedReview? rightsReview = provenanceResult.review;
  final bool bothAccepted =
      frenchReview?.status == 'accepted' && rightsReview?.status == 'accepted';
  bool qualifies = reviewState == 'reviewed' &&
      bothAccepted &&
      frenchReview?.valid == true &&
      rightsReview?.valid == true &&
      contentValid;

  if (frenchReview?.status == 'rejected') {
    _addDiagnostic(diagnostics, 'review_rejected', itemSpec.id,
        'French/audio review rejected: ${frenchReview!.notes}');
  }
  if (rightsReview?.status == 'rejected') {
    _addDiagnostic(diagnostics, 'review_rejected', itemSpec.id,
        'Rights review rejected: ${rightsReview!.notes}');
  }
  if (reviewState == 'reviewed' &&
      (frenchReview?.status != 'accepted' ||
          rightsReview?.status != 'accepted' ||
          frenchReview?.valid != true ||
          rightsReview?.valid != true)) {
    _addDiagnostic(diagnostics, 'review_conflict', itemSpec.id,
        'reviewState is reviewed but both accepted review records are not valid');
    contentValid = false;
    qualifies = false;
  }
  if (reviewState == 'pending' &&
      bothAccepted &&
      frenchReview?.valid == true &&
      rightsReview?.valid == true) {
    _addDiagnostic(diagnostics, 'publication_pending', itemSpec.id,
        'both decisions are accepted, but publication reviewState remains pending');
  } else if (reviewState == 'pending') {
    if (frenchReview?.status == 'pending') {
      _addDiagnostic(diagnostics, 'review_pending', itemSpec.id,
          'French/audio review is pending');
    }
    if (rightsReview?.status == 'pending') {
      _addDiagnostic(diagnostics, 'review_pending', itemSpec.id,
          'rights review is pending');
    }
  }

  final bool modelable = fieldsPresent &&
      tokens != null &&
      expectedTokenIds != null &&
      targetSound != null &&
      text != null &&
      annotationHash != null;
  SentenceHuntItem? model;
  if (modelable) {
    final ContentReviewState modelReview =
        qualifies ? ContentReviewState.reviewed : ContentReviewState.pending;
    model = SentenceHuntItem(
      identity: SentenceHuntContentIdentity(
        sectionId: sectionSpec.id,
        itemId: itemSpec.id,
        sentenceId: itemSpec.sentenceId,
        audioRefId: itemSpec.audioRefId,
        annotationHash: annotationHash,
        contentRevision: contentRevision,
        annotationRevision: annotationRevision,
      ),
      exercise: SentenceHuntExercise(
        id: itemSpec.id,
        sectionId: sectionSpec.id,
        audioRefId: itemSpec.audioRefId,
        purpose: ContentPurpose.practice,
        reviewState: modelReview,
        sentenceId: itemSpec.sentenceId,
        targetSound: targetSound,
      ),
      sentence: CourseSentence(
        id: itemSpec.sentenceId,
        text: text,
        audioRefId: itemSpec.audioRefId,
        tokens: tokens,
        reviewState: modelReview,
      ),
      reference: CourseAudioReference(
        id: itemSpec.audioRefId,
        kind: AudioReferenceKind.sentence,
        spokenText: text,
      ),
      targetLabel: targetLabel!,
      debriefNote: debriefNote!,
      selectableTokenIds:
          tokens.map((SentenceToken token) => token.id).toList(),
      expectedTokenIds: expectedTokenIds,
    );
  }

  return _ItemParseResult(
    spec: itemSpec,
    item: model,
    contentValid: contentValid,
    qualifies: qualifies,
    targetSound: targetSound,
    recording: provenanceResult.recording,
    originalSha: originalSha,
    clipSha: clipSha,
  );
}

Map<String, dynamic>? _recordFor(
  _RecordIndex index,
  String id, {
  required String rootId,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  if (index.duplicateIds.contains(id)) {
    _addDiagnostic(diagnostics, 'duplicate_record', id,
        '$rootId contains duplicate record "$id"');
    return null;
  }
  final Map<String, dynamic>? record = index.byId[id];
  if (record == null) {
    _addDiagnostic(
        diagnostics, 'missing_record', id, '$rootId is missing record "$id"');
  }
  return record;
}

final class _TokenParseResult {
  const _TokenParseResult({required this.tokens, required this.valid});

  final List<SentenceToken>? tokens;
  final bool valid;
}

_TokenParseResult _parseTokens(
  Object? raw, {
  required String itemId,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  if (raw is! List) {
    _addDiagnostic(diagnostics, 'token_shape', itemId,
        'tokens must be an ordered JSON list');
    return const _TokenParseResult(tokens: null, valid: false);
  }
  if (raw.isEmpty) {
    _addDiagnostic(diagnostics, 'token_shape', itemId,
        'tokens must contain at least one written word');
    return const _TokenParseResult(tokens: null, valid: false);
  }
  bool valid = true;
  bool modelable = true;
  final Set<String> ids = <String>{};
  final List<SentenceToken> tokens = <SentenceToken>[];
  for (int index = 0; index < raw.length; index++) {
    final Object? value = raw[index];
    if (value is! Map<String, dynamic>) {
      _addDiagnostic(diagnostics, 'token_shape', itemId,
          'tokens[$index] must be a JSON object');
      valid = false;
      modelable = false;
      continue;
    }
    bool tokenValid = _hasExactFields(
      value,
      const <String>['id', 'text', 'phonemes'],
      recordId: itemId,
      diagnostics: diagnostics,
    );
    final String? id = _readString(
      value,
      'id',
      recordId: itemId,
      diagnostics: diagnostics,
      code: 'token_field',
    );
    final String? text = _readString(
      value,
      'text',
      recordId: itemId,
      diagnostics: diagnostics,
      code: 'token_field',
    );
    final _StringListResult phonemeResult = _readStringList(
      value['phonemes'],
      field: 'tokens[$index].phonemes',
      recordId: itemId,
      diagnostics: diagnostics,
      unique: true,
      allowEmpty: false,
      code: 'token_phoneme',
    );
    final List<String>? phonemes = phonemeResult.values;
    tokenValid = tokenValid &&
        id != null &&
        text != null &&
        phonemes != null &&
        phonemeResult.valid;
    if (id != null && !ids.add(id)) {
      _addDiagnostic(diagnostics, 'duplicate_token_id', itemId,
          'token id "$id" is duplicated');
      tokenValid = false;
    }
    if (phonemes != null) {
      for (final String phoneme in phonemes) {
        if (!_allPhonemes.contains(phoneme)) {
          _addDiagnostic(diagnostics, 'unknown_phoneme', itemId,
              'token phoneme "$phoneme" is not in the sentence-local IPA table');
          tokenValid = false;
        }
      }
    }
    if (tokenValid && id != null && text != null && phonemes != null) {
      tokens.add(SentenceToken(id: id, text: text, phonemes: phonemes));
    } else {
      valid = false;
      if (id == null || text == null || phonemes == null) modelable = false;
    }
  }
  if (!valid) {
    // Relationship faults (e.g. duplicate IDs or an unknown phoneme) do not
    // make the word tokens unconstructable; malformed fields do.
    final bool allRowsModelable = raw.every((Object? value) {
      if (value is! Map<String, dynamic>) return false;
      return value['id'] is String &&
          (value['id'] as String).trim().isNotEmpty &&
          value['text'] is String &&
          (value['text'] as String).trim().isNotEmpty &&
          value['phonemes'] is List &&
          (value['phonemes'] as List).every((Object? phoneme) =>
              phoneme is String && phoneme.trim().isNotEmpty);
    });
    modelable = modelable && allRowsModelable;
  }
  if (modelable && tokens.length != raw.length) {
    // Keep otherwise constructible tokens for diagnostics/fingerprinting.
    tokens.clear();
    for (final Object? value in raw) {
      final Map<String, dynamic> token = value as Map<String, dynamic>;
      tokens.add(SentenceToken(
        id: token['id'] as String,
        text: token['text'] as String,
        phonemes: List<String>.of((token['phonemes'] as List).cast<String>()),
      ));
    }
  }
  return _TokenParseResult(
    tokens: modelable ? List<SentenceToken>.unmodifiable(tokens) : null,
    valid: valid,
  );
}

final class _StringListResult {
  const _StringListResult({required this.values, required this.valid});

  final List<String>? values;
  final bool valid;
}

_StringListResult _readStringList(
  Object? raw, {
  required String field,
  required String recordId,
  required List<SentenceHuntDiagnostic> diagnostics,
  required bool unique,
  bool allowEmpty = true,
  String code = 'invalid_field',
}) {
  if (raw is! List) {
    _addDiagnostic(diagnostics, code, recordId,
        '$recordId.$field must be a JSON list of strings');
    return const _StringListResult(values: null, valid: false);
  }
  bool valid = true;
  final List<String> values = <String>[];
  final Set<String> seen = <String>{};
  for (int index = 0; index < raw.length; index++) {
    final Object? value = raw[index];
    if (value is! String || value.trim().isEmpty) {
      _addDiagnostic(diagnostics, code, recordId,
          '$recordId.$field[$index] must be a nonblank string');
      valid = false;
      continue;
    }
    if (unique && !seen.add(value)) {
      _addDiagnostic(diagnostics, code, recordId,
          '$recordId.$field contains duplicate "$value"');
      valid = false;
    }
    values.add(value);
  }
  if (!allowEmpty && values.isEmpty) {
    _addDiagnostic(
        diagnostics, code, recordId, '$recordId.$field must not be empty');
    valid = false;
  }
  return _StringListResult(
    values:
        valid || values.isNotEmpty ? List<String>.unmodifiable(values) : null,
    valid: valid,
  );
}

String? _readString(
  Map<String, dynamic> row,
  String field, {
  required String recordId,
  required List<SentenceHuntDiagnostic> diagnostics,
  String code = 'invalid_field',
}) {
  final Object? raw = row[field];
  if (raw is! String) {
    _addDiagnostic(
        diagnostics, code, recordId, '$recordId.$field must be a string');
    return null;
  }
  if (raw.trim().isEmpty) {
    _addDiagnostic(diagnostics, code, recordId,
        '$recordId.$field must be a nonblank string');
    return null;
  }
  return raw;
}

int? _readPositiveInt(
  Map<String, dynamic> row,
  String field, {
  required String recordId,
  required List<SentenceHuntDiagnostic> diagnostics,
  String code = 'invalid_field',
}) =>
    _readIntRange(
      row,
      field,
      minimum: 1,
      maximum: 0x7fffffff,
      recordId: recordId,
      diagnostics: diagnostics,
      code: code,
    );

int? _readIntRange(
  Map<String, dynamic> row,
  String field, {
  required int minimum,
  required int maximum,
  required String recordId,
  required List<SentenceHuntDiagnostic> diagnostics,
  String code = 'invalid_field',
}) {
  final Object? raw = row[field];
  if (raw is! int || raw < minimum || raw > maximum) {
    _addDiagnostic(diagnostics, code, recordId,
        '$recordId.$field must be an integer in $minimum-$maximum');
    return null;
  }
  return raw;
}

bool _isSha256(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

final RegExp _utcTimestampPattern = RegExp(
  r'^([0-9]{4})-([0-9]{2})-([0-9]{2})[Tt ]'
  r'([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:[.,]([0-9]+))?)?'
  r'(Z|\+00:00)$',
);

bool _isUtcTimestamp(String value) {
  final RegExpMatch? match = _utcTimestampPattern.firstMatch(value);
  if (match == null) return false;

  final int year = int.parse(match[1]!);
  final int month = int.parse(match[2]!);
  final int day = int.parse(match[3]!);
  final int hour = int.parse(match[4]!);
  final int minute = int.parse(match[5]!);
  final int second = int.tryParse(match[6] ?? '') ?? 0;
  final String fraction = match[7] ?? '';
  final String microsecondDigits = fraction.length >= 6
      ? fraction.substring(0, 6)
      : fraction.padRight(6, '0');
  final int microseconds = fraction.isEmpty ? 0 : int.parse(microsecondDigits);
  if (year == 0 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31 ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return false;
  }

  final DateTime calendar = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    microseconds ~/ Duration.microsecondsPerMillisecond,
    microseconds % Duration.microsecondsPerMillisecond,
  );
  return calendar.year == year &&
      calendar.month == month &&
      calendar.day == day &&
      calendar.hour == hour &&
      calendar.minute == minute &&
      calendar.second == second;
}

bool _sameList<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (int index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

final class _ValidatedReview {
  const _ValidatedReview({
    required this.status,
    required this.valid,
    required this.notes,
  });

  final String? status;
  final bool valid;
  final String notes;
}

final class _AnnotationResult {
  const _AnnotationResult({required this.valid, required this.review});

  final bool valid;
  final _ValidatedReview? review;
}

_AnnotationResult _parseAnnotation(
  String itemId,
  Map<String, dynamic>? row,
  List<SentenceToken>? tokens, {
  required int? annotationRevision,
  required String? annotationHash,
  required String? originalSha,
  required String? clipSha,
  required _RecordIndex evidence,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  if (row == null) return const _AnnotationResult(valid: false, review: null);
  bool valid = _hasExactFields(
    row,
    const <String>[
      'itemId',
      'annotationRevision',
      'annotationHash',
      'tool',
      'rawSentenceIpa',
      'draftTokenPhonemes',
      'corrections',
      'frenchAudioReview',
    ],
    recordId: itemId,
    diagnostics: diagnostics,
  );
  final String? actualItemId = _readString(
    row,
    'itemId',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'annotation_field',
  );
  final int? actualRevision = _readPositiveInt(
    row,
    'annotationRevision',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'annotation_field',
  );
  final String? actualHash = _readString(
    row,
    'annotationHash',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'annotation_field',
  );
  final String? rawSentenceIpa = _readString(
    row,
    'rawSentenceIpa',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'annotation_field',
  );
  if (actualItemId != itemId ||
      actualRevision != annotationRevision ||
      actualHash != annotationHash) {
    _addDiagnostic(diagnostics, 'annotation_binding', itemId,
        'annotation identity, revision, and hash must match the manifest item');
    valid = false;
  }
  if (actualHash != null && !_isSha256(actualHash)) {
    _addDiagnostic(diagnostics, 'hash_shape', itemId,
        'annotations.annotationHash must be lowercase SHA-256 hex');
    valid = false;
  }
  if (rawSentenceIpa == null) valid = false;

  final Object? rawTool = row['tool'];
  if (rawTool is! Map<String, dynamic>) {
    _addDiagnostic(diagnostics, 'annotation_tool', itemId,
        'annotations.tool must be a JSON object');
    valid = false;
  } else {
    valid = _validateAnnotationTool(
          rawTool,
          itemId: itemId,
          diagnostics: diagnostics,
        ) &&
        valid;
  }

  final Set<String>? tokenIds =
      tokens?.map((SentenceToken token) => token.id).toSet();
  final Object? rawDrafts = row['draftTokenPhonemes'];
  final _TokenPhonemeMapResult draftResult = _parseDrafts(
    rawDrafts,
    itemId: itemId,
    tokenIds: tokenIds,
    diagnostics: diagnostics,
  );
  final Map<String, List<String>>? draftMap = draftResult.values;
  valid = draftResult.valid && valid;
  if (draftMap == null) {
    valid = false;
  } else if (tokens == null || draftMap.length != tokens.length) {
    _addDiagnostic(diagnostics, 'annotation_tokens', itemId,
        'draftTokenPhonemes must cover all and only the manifest tokens');
    valid = false;
  }

  final Object? rawCorrections = row['corrections'];
  final _CorrectedPhonemeMapResult correctionResult = _applyCorrections(
    rawCorrections,
    draftMap,
    itemId: itemId,
    tokenIds: tokenIds,
    diagnostics: diagnostics,
  );
  final Map<String, List<String>>? corrected = correctionResult.values;
  valid = correctionResult.valid && valid;
  if (corrected == null) {
    valid = false;
  } else if (tokens != null) {
    if (corrected.length != tokens.length) {
      _addDiagnostic(diagnostics, 'annotation_tokens', itemId,
          'corrected annotations must cover all and only the manifest tokens');
      valid = false;
    }
    for (final SentenceToken token in tokens) {
      final List<String>? actual = corrected[token.id];
      if (actual == null || !_sameList(actual, token.phonemes)) {
        _addDiagnostic(diagnostics, 'annotation_tokens', itemId,
            'annotation phonemes for token "${token.id}" do not match manifest');
        valid = false;
      }
    }
  }

  final Object? rawReview = row['frenchAudioReview'];
  final _ValidatedReview? review;
  if (rawReview is! Map<String, dynamic>) {
    _addDiagnostic(diagnostics, 'review_shape', itemId,
        'frenchAudioReview must be a JSON object');
    valid = false;
    review = null;
  } else {
    review = _validateReview(
      rawReview,
      reviewName: 'frenchAudioReview',
      itemId: itemId,
      expectedOriginalSha: originalSha,
      expectedClipSha: clipSha,
      expectedAnnotationHash: annotationHash,
      evidence: evidence,
      diagnostics: diagnostics,
    );
    valid = review.valid && valid;
  }
  return _AnnotationResult(valid: valid, review: review);
}

bool _validateAnnotationTool(
  Map<String, dynamic> tool, {
  required String itemId,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  bool valid = _hasExactFields(
    tool,
    const <String>['name', 'version', 'settings', 'inputSha256'],
    recordId: itemId,
    diagnostics: diagnostics,
  );
  for (final String field in <String>['name', 'version']) {
    if (_readString(
          tool,
          field,
          recordId: itemId,
          diagnostics: diagnostics,
          code: 'annotation_tool',
        ) ==
        null) {
      valid = false;
    }
  }
  final _StringListResult settings = _readStringList(
    tool['settings'],
    field: 'tool.settings',
    recordId: itemId,
    diagnostics: diagnostics,
    unique: false,
    allowEmpty: false,
    code: 'annotation_tool',
  );
  valid = settings.valid && valid;
  final String? inputHash = _readString(
    tool,
    'inputSha256',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'annotation_tool',
  );
  if (inputHash == null || !_isSha256(inputHash)) {
    _addDiagnostic(diagnostics, 'hash_shape', itemId,
        'tool.inputSha256 must be lowercase 64-character SHA-256 hex');
    valid = false;
  }
  return valid;
}

final class _TokenPhonemeMapResult {
  const _TokenPhonemeMapResult({required this.values, required this.valid});

  final Map<String, List<String>>? values;
  final bool valid;
}

_TokenPhonemeMapResult _parseDrafts(
  Object? raw, {
  required String itemId,
  required Set<String>? tokenIds,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  if (raw is! List) {
    _addDiagnostic(diagnostics, 'annotation_tokens', itemId,
        'draftTokenPhonemes must be a JSON list');
    return const _TokenPhonemeMapResult(values: null, valid: false);
  }
  bool valid = true;
  final Map<String, List<String>> byId = <String, List<String>>{};
  for (int index = 0; index < raw.length; index++) {
    final Object? value = raw[index];
    if (value is! Map<String, dynamic>) {
      _addDiagnostic(diagnostics, 'annotation_tokens', itemId,
          'draftTokenPhonemes[$index] must be a JSON object');
      valid = false;
      continue;
    }
    valid = _hasExactFields(
          value,
          const <String>['tokenId', 'phonemes'],
          recordId: itemId,
          diagnostics: diagnostics,
        ) &&
        valid;
    final String? tokenId = _readString(
      value,
      'tokenId',
      recordId: itemId,
      diagnostics: diagnostics,
      code: 'annotation_tokens',
    );
    final _StringListResult phonemes = _readStringList(
      value['phonemes'],
      field: 'draftTokenPhonemes[$index].phonemes',
      recordId: itemId,
      diagnostics: diagnostics,
      unique: true,
      allowEmpty: false,
      code: 'annotation_tokens',
    );
    if (tokenId == null || phonemes.values == null) {
      valid = false;
      continue;
    }
    if (tokenIds != null && !tokenIds.contains(tokenId)) {
      _addDiagnostic(diagnostics, 'annotation_tokens', itemId,
          'draftTokenPhonemes tokenId "$tokenId" is not a manifest token');
      valid = false;
    }
    for (final String phoneme in phonemes.values!) {
      if (!_allPhonemes.contains(phoneme)) {
        _addDiagnostic(diagnostics, 'unknown_phoneme', itemId,
            'draft phoneme "$phoneme" is not in the sentence-local IPA table');
        valid = false;
      }
    }
    if (!phonemes.valid || byId.containsKey(tokenId)) {
      _addDiagnostic(diagnostics, 'annotation_tokens', itemId,
          'draftTokenPhonemes token IDs must be unique');
      valid = false;
    } else {
      byId[tokenId] = phonemes.values!;
    }
  }
  return _TokenPhonemeMapResult(
    values: Map<String, List<String>>.unmodifiable(byId),
    valid: valid,
  );
}

final class _CorrectedPhonemeMapResult {
  const _CorrectedPhonemeMapResult({
    required this.values,
    required this.valid,
  });

  final Map<String, List<String>>? values;
  final bool valid;
}

_CorrectedPhonemeMapResult _applyCorrections(
  Object? raw,
  Map<String, List<String>>? drafts, {
  required String itemId,
  required Set<String>? tokenIds,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  if (raw is! List) {
    _addDiagnostic(diagnostics, 'annotation_corrections', itemId,
        'corrections must be a JSON list');
    return const _CorrectedPhonemeMapResult(values: null, valid: false);
  }
  if (drafts == null) {
    return const _CorrectedPhonemeMapResult(values: null, valid: false);
  }
  final Map<String, List<String>> corrected = <String, List<String>>{
    for (final MapEntry<String, List<String>> entry in drafts.entries)
      entry.key: List<String>.of(entry.value),
  };
  bool valid = true;
  for (int index = 0; index < raw.length; index++) {
    final Object? value = raw[index];
    if (value is! Map<String, dynamic>) {
      _addDiagnostic(diagnostics, 'annotation_corrections', itemId,
          'corrections[$index] must be a JSON object');
      valid = false;
      continue;
    }
    valid = _hasExactFields(
          value,
          const <String>['tokenId', 'before', 'after', 'rationale'],
          recordId: itemId,
          diagnostics: diagnostics,
        ) &&
        valid;
    final String? tokenId = _readString(
      value,
      'tokenId',
      recordId: itemId,
      diagnostics: diagnostics,
      code: 'annotation_corrections',
    );
    final String? rationale = _readString(
      value,
      'rationale',
      recordId: itemId,
      diagnostics: diagnostics,
      code: 'annotation_corrections',
    );
    final _StringListResult before = _readStringList(
      value['before'],
      field: 'corrections[$index].before',
      recordId: itemId,
      diagnostics: diagnostics,
      unique: true,
      allowEmpty: false,
      code: 'annotation_corrections',
    );
    final _StringListResult after = _readStringList(
      value['after'],
      field: 'corrections[$index].after',
      recordId: itemId,
      diagnostics: diagnostics,
      unique: true,
      allowEmpty: false,
      code: 'annotation_corrections',
    );
    if (tokenId == null ||
        rationale == null ||
        before.values == null ||
        after.values == null) {
      valid = false;
      continue;
    }
    valid = before.valid && after.valid && valid;
    if (tokenIds != null && !tokenIds.contains(tokenId)) {
      _addDiagnostic(diagnostics, 'annotation_corrections', itemId,
          'correction[$index].tokenId is not a manifest token');
      valid = false;
    }
    final List<String>? current = corrected[tokenId];
    if (current == null || !_sameList(current, before.values!)) {
      _addDiagnostic(diagnostics, 'annotation_corrections', itemId,
          'correction[$index].before does not match token "$tokenId"');
      valid = false;
    }
    for (final String phoneme in <String>[
      ...before.values!,
      ...after.values!
    ]) {
      if (!_allPhonemes.contains(phoneme)) {
        _addDiagnostic(diagnostics, 'unknown_phoneme', itemId,
            'correction phoneme "$phoneme" is not in the sentence-local IPA table');
        valid = false;
      }
    }
    if (current != null) corrected[tokenId] = after.values!;
  }
  return _CorrectedPhonemeMapResult(
    values: Map<String, List<String>>.unmodifiable(corrected),
    valid: valid,
  );
}

_ValidatedReview _validateReview(
  Map<String, dynamic> row, {
  required String reviewName,
  required String itemId,
  required String? expectedOriginalSha,
  required String? expectedClipSha,
  required String? expectedAnnotationHash,
  required _RecordIndex evidence,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  bool valid = _hasExactFields(
    row,
    const <String>[
      'status',
      'reviewer',
      'qualification',
      'reviewedAt',
      'originalSha256',
      'clipSha256',
      'annotationHash',
      'evidenceIds',
      'notes',
    ],
    recordId: itemId,
    diagnostics: diagnostics,
  );
  final String? status = _readString(
    row,
    'status',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'review_field',
  );
  final String? notes = _readString(
    row,
    'notes',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'review_field',
  );
  if (status != 'pending' && status != 'accepted' && status != 'rejected') {
    _addDiagnostic(diagnostics, 'review_status', itemId,
        '$reviewName.status must be pending, accepted, or rejected');
    valid = false;
  }
  for (final ({String name, String? expected}) binding
      in <({String name, String? expected})>[
    (name: 'originalSha256', expected: expectedOriginalSha),
    (name: 'clipSha256', expected: expectedClipSha),
    (name: 'annotationHash', expected: expectedAnnotationHash),
  ]) {
    final String? actual = _readString(
      row,
      binding.name,
      recordId: itemId,
      diagnostics: diagnostics,
      code: 'review_hash',
    );
    if (actual == null || !_isSha256(actual)) {
      _addDiagnostic(diagnostics, 'hash_shape', itemId,
          '$reviewName.${binding.name} must be lowercase SHA-256 hex');
      valid = false;
    }
    if (binding.expected == null || actual != binding.expected) {
      _addDiagnostic(diagnostics, 'hash_binding', itemId,
          '$reviewName.${binding.name} must match the current content identity');
      valid = false;
    }
  }

  final Object? reviewer = row['reviewer'];
  final Object? qualification = row['qualification'];
  final Object? reviewedAt = row['reviewedAt'];
  if (status == 'pending') {
    if (reviewer != null || qualification != null || reviewedAt != null) {
      _addDiagnostic(diagnostics, 'pending_review_fields', itemId,
          '$reviewName pending reviewer, qualification, and reviewedAt must be null');
      valid = false;
    }
  } else if (status == 'accepted' || status == 'rejected') {
    if (reviewer is! String || reviewer.trim().isEmpty) {
      _addDiagnostic(diagnostics, 'review_evidence', itemId,
          '$reviewName.$status requires a nonblank reviewer');
      valid = false;
    }
    if (qualification is! String || qualification.trim().isEmpty) {
      _addDiagnostic(diagnostics, 'review_evidence', itemId,
          '$reviewName.$status requires a nonblank qualification');
      valid = false;
    }
    if (reviewedAt is! String || !_isUtcTimestamp(reviewedAt)) {
      _addDiagnostic(diagnostics, 'review_evidence', itemId,
          '$reviewName.$status requires an explicit valid UTC reviewedAt');
      valid = false;
    }
  }

  final _StringListResult evidenceIds = _readStringList(
    row['evidenceIds'],
    field: '$reviewName.evidenceIds',
    recordId: itemId,
    diagnostics: diagnostics,
    unique: true,
    allowEmpty: status == 'pending',
    code: 'review_evidence',
  );
  valid = evidenceIds.valid && valid;
  if (status == 'pending' && evidenceIds.values?.isNotEmpty == true) {
    _addDiagnostic(diagnostics, 'pending_review_fields', itemId,
        '$reviewName pending evidenceIds must be empty');
    valid = false;
  }
  if ((status == 'accepted' || status == 'rejected') &&
      (evidenceIds.values == null || evidenceIds.values!.isEmpty)) {
    _addDiagnostic(diagnostics, 'review_evidence', itemId,
        '$reviewName.$status requires nonempty evidenceIds');
    valid = false;
  }
  for (final String evidenceId in evidenceIds.values ?? const <String>[]) {
    final Map<String, dynamic>? evidenceRow = _recordFor(
      evidence,
      evidenceId,
      rootId: 'source-evidence',
      diagnostics: diagnostics,
    );
    if (evidenceRow == null ||
        !_validateEvidenceRecord(
          evidenceRow,
          expectedId: evidenceId,
          itemId: itemId,
          diagnostics: diagnostics,
        )) {
      valid = false;
    }
  }
  if (notes == null) valid = false;
  return _ValidatedReview(
    status: status,
    valid: valid,
    notes: notes ?? '',
  );
}

bool _validateEvidenceRecord(
  Map<String, dynamic> row, {
  required String expectedId,
  String? itemId,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  bool valid = _hasExactFields(
    row,
    const <String>[
      'id',
      'url',
      'retrievedAt',
      'sha256',
      'text',
      'scope',
      'itemIds',
    ],
    recordId: expectedId,
    diagnostics: diagnostics,
  );
  final String? id = _readString(
    row,
    'id',
    recordId: expectedId,
    diagnostics: diagnostics,
    code: 'evidence_record',
  );
  final String? url = _readString(
    row,
    'url',
    recordId: expectedId,
    diagnostics: diagnostics,
    code: 'evidence_record',
  );
  final String? retrievedAt = _readString(
    row,
    'retrievedAt',
    recordId: expectedId,
    diagnostics: diagnostics,
    code: 'evidence_record',
  );
  final String? sha = _readString(
    row,
    'sha256',
    recordId: expectedId,
    diagnostics: diagnostics,
    code: 'evidence_record',
  );
  final String? text = _readString(
    row,
    'text',
    recordId: expectedId,
    diagnostics: diagnostics,
    code: 'evidence_record',
  );
  final String? scope = _readString(
    row,
    'scope',
    recordId: expectedId,
    diagnostics: diagnostics,
    code: 'evidence_record',
  );
  if (id != expectedId) {
    _addDiagnostic(diagnostics, 'evidence_record', expectedId,
        'source-evidence id does not match its index');
    valid = false;
  }
  if (url == null || !_isAbsoluteHttpsUrl(url)) {
    _addDiagnostic(diagnostics, 'evidence_record', expectedId,
        'source-evidence.url must be an absolute https URL without credentials');
    valid = false;
  }
  if (retrievedAt == null || !_isUtcTimestamp(retrievedAt)) {
    _addDiagnostic(diagnostics, 'evidence_record', expectedId,
        'source-evidence.retrievedAt must be an explicit UTC timestamp');
    valid = false;
  }
  if (sha == null || !_isSha256(sha)) {
    _addDiagnostic(diagnostics, 'evidence_record', expectedId,
        'source-evidence.sha256 must be lowercase SHA-256 hex');
    valid = false;
  }
  if (text == null) valid = false;
  final _StringListResult itemIds = _readStringList(
    row['itemIds'],
    field: 'source-evidence.itemIds',
    recordId: expectedId,
    diagnostics: diagnostics,
    unique: true,
    code: 'evidence_record',
  );
  valid = itemIds.valid && valid;
  for (final String assignedItemId in itemIds.values ?? const <String>[]) {
    if (!_allItemIds.contains(assignedItemId)) {
      _addDiagnostic(diagnostics, 'evidence_record', expectedId,
          'source-evidence.itemIds contains unknown item "$assignedItemId"');
      valid = false;
    }
  }
  if (scope != 'dataset' && scope != 'tool' && scope != 'item') {
    _addDiagnostic(diagnostics, 'evidence_record', expectedId,
        'source-evidence.scope must be dataset, tool, or item');
    valid = false;
  }
  if ((scope == 'dataset' || scope == 'tool') &&
      itemIds.values?.isNotEmpty == true) {
    _addDiagnostic(diagnostics, 'evidence_record', expectedId,
        'dataset and tool evidence itemIds must be empty');
    valid = false;
  }
  if (scope == 'item' && (itemIds.values?.isEmpty ?? true)) {
    _addDiagnostic(diagnostics, 'evidence_record', expectedId,
        'item-scoped evidence must identify at least one item');
    valid = false;
  }
  if (itemId != null &&
      scope != 'dataset' &&
      !(scope == 'item' && itemIds.values?.contains(itemId) == true)) {
    _addDiagnostic(diagnostics, 'evidence_coverage', itemId,
        'evidence "$expectedId" does not cover this item or its dataset');
    valid = false;
  }
  return valid;
}

final class _ProvenanceResult {
  const _ProvenanceResult({
    required this.valid,
    required this.review,
    required this.recording,
  });

  final bool valid;
  final _ValidatedReview? review;
  final SentenceHuntRecordingMetadata? recording;
}

final class _AudioMeasurement {
  const _AudioMeasurement({
    required this.path,
    required this.sha256,
    required this.byteLength,
    required this.sampleRate,
    required this.channels,
    required this.sampleWidth,
    required this.sampleEncoding,
    required this.frameCount,
    required this.durationSeconds,
  });

  final String path;
  final String sha256;
  final int byteLength;
  final int sampleRate;
  final int channels;
  final int sampleWidth;
  final String sampleEncoding;
  final int frameCount;
  final double durationSeconds;
}

_ProvenanceResult _parseProvenance(
  String itemId,
  Map<String, dynamic>? row, {
  required String? text,
  required String? originalPath,
  required String? clipPath,
  required String? originalSha,
  required String? clipSha,
  required String? annotationHash,
  required _RecordIndex evidence,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  if (row == null) {
    return const _ProvenanceResult(
      valid: false,
      review: null,
      recording: null,
    );
  }
  bool valid = _hasExactFields(
    row,
    const <String>[
      'itemId',
      'source',
      'original',
      'clip',
      'derivation',
      'credit',
      'rightsReview',
    ],
    recordId: itemId,
    diagnostics: diagnostics,
  );
  final String? actualItemId = _readString(
    row,
    'itemId',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'provenance_field',
  );
  if (actualItemId != itemId) {
    _addDiagnostic(diagnostics, 'provenance_binding', itemId,
        'provenance itemId must match the authored item');
    valid = false;
  }

  final Object? rawSource = row['source'];
  final _SourceRecord? source;
  if (rawSource is! Map<String, dynamic>) {
    _addDiagnostic(diagnostics, 'provenance_source', itemId,
        'provenance.source must be a JSON object');
    source = null;
    valid = false;
  } else {
    final _SourceParseResult result = _parseSource(
      rawSource,
      itemId: itemId,
      expectedText: text,
      diagnostics: diagnostics,
    );
    source = result.source;
    valid = result.valid && valid;
  }

  final Object? rawOriginal = row['original'];
  final _AudioMeasurement? original;
  if (rawOriginal is! Map<String, dynamic>) {
    _addDiagnostic(diagnostics, 'measurement_shape', itemId,
        'provenance.original must be a JSON object');
    original = null;
    valid = false;
  } else {
    final _MeasurementParseResult result = _parseMeasurement(
      rawOriginal,
      name: 'original',
      itemId: itemId,
      diagnostics: diagnostics,
    );
    original = result.measurement;
    valid = result.valid && valid;
  }
  final Object? rawClip = row['clip'];
  final _AudioMeasurement? clip;
  if (rawClip is! Map<String, dynamic>) {
    _addDiagnostic(diagnostics, 'measurement_shape', itemId,
        'provenance.clip must be a JSON object');
    clip = null;
    valid = false;
  } else {
    final _MeasurementParseResult result = _parseMeasurement(
      rawClip,
      name: 'clip',
      itemId: itemId,
      diagnostics: diagnostics,
    );
    clip = result.measurement;
    valid = result.valid && valid;
  }

  if (original != null && clip != null) {
    if (original.path != originalPath ||
        clip.path != clipPath ||
        original.sha256 != originalSha ||
        clip.sha256 != clipSha) {
      _addDiagnostic(diagnostics, 'audio_hash_binding', itemId,
          'manifest audio paths and hashes must match provenance measurements');
      valid = false;
    }
  }

  final Object? rawDerivation = row['derivation'];
  final _DerivationRecord? derivation;
  if (rawDerivation is! Map<String, dynamic>) {
    _addDiagnostic(diagnostics, 'derivation_shape', itemId,
        'provenance.derivation must be a JSON object');
    derivation = null;
    valid = false;
  } else {
    final _DerivationParseResult result = _parseDerivation(
      rawDerivation,
      itemId: itemId,
      diagnostics: diagnostics,
    );
    derivation = result.derivation;
    valid = result.valid && valid;
  }
  if (original != null && clip != null && derivation != null) {
    if (derivation.startFrame < 0 ||
        derivation.endFrame <= derivation.startFrame ||
        derivation.endFrame > original.frameCount ||
        clip.frameCount != derivation.endFrame - derivation.startFrame ||
        clip.sampleRate != original.sampleRate ||
        clip.channels != original.channels ||
        (original.durationSeconds - original.frameCount / original.sampleRate)
                .abs() >
            0.000001 ||
        (clip.durationSeconds - clip.frameCount / clip.sampleRate).abs() >
            0.000001) {
      _addDiagnostic(diagnostics, 'audio_measurement_binding', itemId,
          'clip measurements must agree with the recorded derivation frame range');
      valid = false;
    }
    if (original.sampleEncoding != 'ieee-float32le' ||
        original.sampleWidth != 4 ||
        clip.sampleEncoding != 'pcm-s16le' ||
        clip.sampleWidth != 2 ||
        derivation.conversionPolicy != 'pcm16-v1') {
      _addDiagnostic(diagnostics, 'audio_conversion', itemId,
          'audio conversion must declare the measured pcm16-v1 delivery');
      valid = false;
    }
  }

  final Object? rawCredit = row['credit'];
  final _CreditRecord? credit;
  if (rawCredit is! Map<String, dynamic>) {
    _addDiagnostic(diagnostics, 'credit_shape', itemId,
        'provenance.credit must be a JSON object');
    credit = null;
    valid = false;
  } else {
    final _CreditParseResult result = _parseCredit(
      rawCredit,
      itemId: itemId,
      evidence: evidence,
      diagnostics: diagnostics,
    );
    credit = result.credit;
    valid = result.valid && valid;
  }

  final Object? rawReview = row['rightsReview'];
  final _ValidatedReview? rightsReview;
  if (rawReview is! Map<String, dynamic>) {
    _addDiagnostic(diagnostics, 'review_shape', itemId,
        'rightsReview must be a JSON object');
    rightsReview = null;
    valid = false;
  } else {
    rightsReview = _validateReview(
      rawReview,
      reviewName: 'rightsReview',
      itemId: itemId,
      expectedOriginalSha: originalSha,
      expectedClipSha: clipSha,
      expectedAnnotationHash: annotationHash,
      evidence: evidence,
      diagnostics: diagnostics,
    );
    valid = rightsReview.valid && valid;
  }

  SentenceHuntRecordingMetadata? recording;
  if (clip != null && credit != null && source != null && derivation != null) {
    final List<String> notices = <String>[
      ...credit.notices,
      ...derivation.changes,
    ];
    final CourseAudioCredit courseCredit = CourseAudioCredit(
      referenceId: '$itemId-audio',
      spokenText: text ?? '',
      creator: credit.creator,
      sourceUrl: source.retrievalUrl,
      auditedRevisionUrl: source.retrievalUrl,
      licenseId: credit.licenseId,
      licenseUrl: credit.licenseUrl,
      licenseTextAssetKey:
          'assets/audio/fr-sentences/${credit.licenseTextPath}',
      attribution: credit.attribution,
      notices: notices,
      unchanged: false,
    );
    recording = SentenceHuntRecordingMetadata(
      assetKey: 'assets/audio/fr-sentences/${clip.path}',
      byteLength: clip.byteLength,
      duration: Duration(
        microseconds:
            (clip.durationSeconds * Duration.microsecondsPerSecond).round(),
      ),
      credit: courseCredit,
    );
  }
  return _ProvenanceResult(
    valid: valid,
    review: rightsReview,
    recording: recording,
  );
}

final class _SourceRecord {
  const _SourceRecord({
    required this.retrievalUrl,
    required this.retrievedAt,
    required this.rawTranscription,
  });

  final String retrievalUrl;
  final String retrievedAt;
  final String rawTranscription;
}

final class _SourceParseResult {
  const _SourceParseResult({required this.source, required this.valid});

  final _SourceRecord? source;
  final bool valid;
}

_SourceParseResult _parseSource(
  Map<String, dynamic> row, {
  required String itemId,
  required String? expectedText,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  bool valid = _hasExactFields(
    row,
    const <String>[
      'repository',
      'revision',
      'config',
      'split',
      'rowId',
      'audioPath',
      'retrievalUrl',
      'retrievedAt',
      'rawTranscription',
      'transcription',
      'rawTsvRecord',
    ],
    recordId: itemId,
    diagnostics: diagnostics,
  );
  final Map<String, String?> strings = <String, String?>{};
  for (final String field in <String>[
    'repository',
    'revision',
    'config',
    'split',
    'rowId',
    'audioPath',
    'retrievalUrl',
    'retrievedAt',
    'rawTranscription',
    'transcription',
    'rawTsvRecord',
  ]) {
    strings[field] = _readString(
      row,
      field,
      recordId: itemId,
      diagnostics: diagnostics,
      code: 'source_field',
    );
  }
  if (strings.values.any((String? value) => value == null)) valid = false;
  final String? retrievalUrl = strings['retrievalUrl'];
  if (retrievalUrl == null || !retrievalUrl.startsWith('https://')) {
    _addDiagnostic(diagnostics, 'source_url', itemId,
        'source.retrievalUrl must be an https URL');
    valid = false;
  }
  final String? retrievedAt = strings['retrievedAt'];
  if (retrievedAt == null || !_isUtcTimestamp(retrievedAt)) {
    _addDiagnostic(diagnostics, 'source_timestamp', itemId,
        'source.retrievedAt must be an explicit UTC timestamp');
    valid = false;
  }
  final String? rawTranscription = strings['rawTranscription'];
  if (rawTranscription != expectedText) {
    _addDiagnostic(diagnostics, 'transcript_binding', itemId,
        'source.rawTranscription must exactly equal the sentence text');
    valid = false;
  }
  if (retrievalUrl == null || retrievedAt == null || rawTranscription == null) {
    return const _SourceParseResult(source: null, valid: false);
  }
  return _SourceParseResult(
    source: _SourceRecord(
      retrievalUrl: retrievalUrl,
      retrievedAt: retrievedAt,
      rawTranscription: rawTranscription,
    ),
    valid: valid,
  );
}

final class _MeasurementParseResult {
  const _MeasurementParseResult({
    required this.measurement,
    required this.valid,
  });

  final _AudioMeasurement? measurement;
  final bool valid;
}

_MeasurementParseResult _parseMeasurement(
  Map<String, dynamic> row, {
  required String name,
  required String itemId,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  bool valid = _hasExactFields(
    row,
    const <String>[
      'path',
      'sha256',
      'byteLength',
      'sampleRate',
      'channels',
      'sampleWidth',
      'sampleEncoding',
      'frameCount',
      'durationSeconds',
    ],
    recordId: itemId,
    diagnostics: diagnostics,
  );
  final String? path = _readString(
    row,
    'path',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'measurement_field',
  );
  final String? sha = _readString(
    row,
    'sha256',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'measurement_field',
  );
  final int? byteLength = _readPositiveInt(
    row,
    'byteLength',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'measurement_field',
  );
  final int? sampleRate = _readPositiveInt(
    row,
    'sampleRate',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'measurement_field',
  );
  final int? channels = _readPositiveInt(
    row,
    'channels',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'measurement_field',
  );
  final int? sampleWidth = _readPositiveInt(
    row,
    'sampleWidth',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'measurement_field',
  );
  final String? sampleEncoding = _readString(
    row,
    'sampleEncoding',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'measurement_field',
  );
  final int? frameCount = _readPositiveInt(
    row,
    'frameCount',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'measurement_field',
  );
  final Object? rawDuration = row['durationSeconds'];
  double? duration;
  if (rawDuration is num && rawDuration.isFinite && rawDuration > 0) {
    duration = rawDuration.toDouble();
  } else {
    _addDiagnostic(diagnostics, 'measurement_field', itemId,
        '$name.durationSeconds must be a finite positive number');
    valid = false;
  }
  if (sha == null || !_isSha256(sha)) {
    _addDiagnostic(diagnostics, 'hash_shape', itemId,
        '$name.sha256 must be lowercase 64-character SHA-256 hex');
    valid = false;
  }
  if (path == null || !_isSafeRelativePath(path)) {
    _addDiagnostic(diagnostics, 'measurement_path', itemId,
        '$name.path must be a safe relative package path');
    valid = false;
  }
  if (path == null ||
      sha == null ||
      byteLength == null ||
      sampleRate == null ||
      channels == null ||
      sampleWidth == null ||
      sampleEncoding == null ||
      frameCount == null ||
      duration == null) {
    return const _MeasurementParseResult(measurement: null, valid: false);
  }
  return _MeasurementParseResult(
    measurement: _AudioMeasurement(
      path: path,
      sha256: sha,
      byteLength: byteLength,
      sampleRate: sampleRate,
      channels: channels,
      sampleWidth: sampleWidth,
      sampleEncoding: sampleEncoding,
      frameCount: frameCount,
      durationSeconds: duration,
    ),
    valid: valid,
  );
}

final class _DerivationRecord {
  const _DerivationRecord({
    required this.startFrame,
    required this.endFrame,
    required this.conversionPolicy,
    required this.changes,
  });

  final int startFrame;
  final int endFrame;
  final String conversionPolicy;
  final List<String> changes;
}

final class _DerivationParseResult {
  const _DerivationParseResult({
    required this.derivation,
    required this.valid,
  });

  final _DerivationRecord? derivation;
  final bool valid;
}

_DerivationParseResult _parseDerivation(
  Map<String, dynamic> row, {
  required String itemId,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  bool valid = _hasExactFields(
    row,
    const <String>[
      'startFrame',
      'endFrame',
      'conversionPolicy',
      'tool',
      'version',
      'settings',
      'changes',
      'transcriptCorrectionRationale',
    ],
    recordId: itemId,
    diagnostics: diagnostics,
  );
  final int? startFrame = _readIntRange(
    row,
    'startFrame',
    minimum: 0,
    maximum: 0x7fffffff,
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'derivation_field',
  );
  final int? endFrame = _readPositiveInt(
    row,
    'endFrame',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'derivation_field',
  );
  final String? conversionPolicy = _readString(
    row,
    'conversionPolicy',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'derivation_field',
  );
  if (conversionPolicy != 'pcm16-v1') {
    _addDiagnostic(diagnostics, 'conversion_policy', itemId,
        'derivation.conversionPolicy must be "pcm16-v1"');
    valid = false;
  }
  for (final String field in <String>[
    'tool',
    'version',
    'transcriptCorrectionRationale',
  ]) {
    if (_readString(
          row,
          field,
          recordId: itemId,
          diagnostics: diagnostics,
          code: 'derivation_field',
        ) ==
        null) {
      valid = false;
    }
  }
  final _StringListResult settings = _readStringList(
    row['settings'],
    field: 'derivation.settings',
    recordId: itemId,
    diagnostics: diagnostics,
    unique: false,
    allowEmpty: false,
    code: 'derivation_field',
  );
  final _StringListResult changes = _readStringList(
    row['changes'],
    field: 'derivation.changes',
    recordId: itemId,
    diagnostics: diagnostics,
    unique: false,
    allowEmpty: false,
    code: 'derivation_field',
  );
  valid = settings.valid && changes.valid && valid;
  if (startFrame == null ||
      endFrame == null ||
      conversionPolicy == null ||
      changes.values == null) {
    return const _DerivationParseResult(derivation: null, valid: false);
  }
  if (endFrame <= startFrame) {
    _addDiagnostic(diagnostics, 'derivation_range', itemId,
        'derivation.endFrame must be greater than startFrame');
    valid = false;
  }
  return _DerivationParseResult(
    derivation: _DerivationRecord(
      startFrame: startFrame,
      endFrame: endFrame,
      conversionPolicy: conversionPolicy,
      changes: changes.values!,
    ),
    valid: valid,
  );
}

final class _CreditRecord {
  const _CreditRecord({
    required this.creator,
    required this.attribution,
    required this.licenseId,
    required this.licenseUrl,
    required this.licenseTextPath,
    required this.notices,
  });

  final String creator;
  final String attribution;
  final String licenseId;
  final String licenseUrl;
  final String licenseTextPath;
  final List<String> notices;
}

final class _CreditParseResult {
  const _CreditParseResult({required this.credit, required this.valid});

  final _CreditRecord? credit;
  final bool valid;
}

_CreditParseResult _parseCredit(
  Map<String, dynamic> row, {
  required String itemId,
  required _RecordIndex evidence,
  required List<SentenceHuntDiagnostic> diagnostics,
}) {
  bool valid = _hasExactFields(
    row,
    const <String>[
      'creator',
      'attribution',
      'licenseId',
      'licenseUrl',
      'licenseTextPath',
      'notices',
      'evidenceIds',
    ],
    recordId: itemId,
    diagnostics: diagnostics,
  );
  final String? creator = _readString(
    row,
    'creator',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'credit_field',
  );
  final String? attribution = _readString(
    row,
    'attribution',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'credit_field',
  );
  final String? licenseId = _readString(
    row,
    'licenseId',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'credit_field',
  );
  final String? licenseUrl = _readString(
    row,
    'licenseUrl',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'credit_field',
  );
  final String? licenseTextPath = _readString(
    row,
    'licenseTextPath',
    recordId: itemId,
    diagnostics: diagnostics,
    code: 'credit_field',
  );
  if (licenseUrl == null || !licenseUrl.startsWith('https://')) {
    _addDiagnostic(diagnostics, 'credit_license', itemId,
        'credit.licenseUrl must be an https URL');
    valid = false;
  }
  if (licenseTextPath == null ||
      !_isSafeRelativePath(licenseTextPath) ||
      !licenseTextPath.startsWith('licenses/')) {
    _addDiagnostic(diagnostics, 'credit_license', itemId,
        'credit.licenseTextPath must be a safe packaged licenses path');
    valid = false;
  }
  final _StringListResult notices = _readStringList(
    row['notices'],
    field: 'credit.notices',
    recordId: itemId,
    diagnostics: diagnostics,
    unique: false,
    allowEmpty: false,
    code: 'credit_field',
  );
  final _StringListResult evidenceIds = _readStringList(
    row['evidenceIds'],
    field: 'credit.evidenceIds',
    recordId: itemId,
    diagnostics: diagnostics,
    unique: true,
    allowEmpty: false,
    code: 'credit_evidence',
  );
  valid = notices.valid && evidenceIds.valid && valid;
  for (final String evidenceId in evidenceIds.values ?? const <String>[]) {
    final Map<String, dynamic>? evidenceRow = _recordFor(
      evidence,
      evidenceId,
      rootId: 'source-evidence',
      diagnostics: diagnostics,
    );
    if (evidenceRow == null ||
        !_validateEvidenceRecord(
          evidenceRow,
          expectedId: evidenceId,
          itemId: itemId,
          diagnostics: diagnostics,
        )) {
      valid = false;
    }
  }
  if (creator == null ||
      attribution == null ||
      licenseId == null ||
      licenseUrl == null ||
      licenseTextPath == null ||
      notices.values == null) {
    return const _CreditParseResult(credit: null, valid: false);
  }
  return _CreditParseResult(
    credit: _CreditRecord(
      creator: creator,
      attribution: attribution,
      licenseId: licenseId,
      licenseUrl: licenseUrl,
      licenseTextPath: licenseTextPath,
      notices: notices.values!,
    ),
    valid: valid,
  );
}

bool _isSafeRelativePath(String path) =>
    path.isNotEmpty &&
    !path.startsWith('/') &&
    !path.contains('\\') &&
    !path.contains('://') &&
    !path.split('/').any((String segment) =>
        segment.isEmpty || segment == '.' || segment == '..');

bool _isAbsoluteHttpsUrl(String value) {
  final Uri? uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

void _validateMixedRevisits(
  List<_SectionParseResult> sections,
  Map<String, List<SentenceHuntDiagnostic>> diagnosticsBySection,
  Map<String, bool> availability,
  bool canCompare,
) {
  if (!canCompare || sections.length != 3) return;
  final Set<String> vowelTargets = <String>{
    for (final _ItemParseResult item in sections[0].items)
      if (item.targetSound != null) item.targetSound!,
  };
  final Set<String> consonantTargets = <String>{
    for (final _ItemParseResult item in sections[1].items)
      if (item.targetSound != null) item.targetSound!,
  };
  bool valid = true;
  for (final _ItemParseResult item in sections[2].items) {
    final _SectionParseResult primarySection =
        item.spec.targetRole == SentenceHuntTargetRole.vowel
            ? sections[0]
            : sections[1];
    final Set<String> priorTargets =
        item.spec.targetRole == SentenceHuntTargetRole.vowel
            ? vowelTargets
            : consonantTargets;
    if (item.targetSound == null || !priorTargets.contains(item.targetSound)) {
      diagnosticsBySection[sections[2].spec.id]!.add(SentenceHuntDiagnostic(
        code: 'mixed_target_revisit',
        recordId: item.spec.id,
        message: 'mixed target must revisit a prior vowel or consonant target',
      ));
      valid = false;
    }
    final String? mixedText = item.item?.sentence.text;
    if (mixedText != null &&
        primarySection.items.any((_ItemParseResult primary) =>
            primary.targetSound == item.targetSound &&
            primary.item?.sentence.text == mixedText)) {
      diagnosticsBySection[sections[2].spec.id]!.add(SentenceHuntDiagnostic(
        code: 'mixed_target_context',
        recordId: item.spec.id,
        message: 'mixed target must use text distinct from its primary context',
      ));
      valid = false;
    }
  }
  if (vowelTargets.isEmpty || consonantTargets.isEmpty) valid = false;
  if (!valid) availability[sections[2].spec.id] = false;
}

String _sectionFingerprint(
  Map<String, dynamic> sectionRow,
  List<_ItemParseResult> parsedItems, {
  required SentenceHuntSectionSpecification spec,
  required SentenceHuntSectionKind kind,
}) {
  final int contentRevision = sectionRow['contentRevision'] as int;
  final int policyRevision = sectionRow['policyRevision'] as int;
  final int threshold = sectionRow['completionThresholdPercent'] as int;
  final List<Map<String, Object?>> itemProjection = <Map<String, Object?>>[];
  for (final _ItemParseResult parsed in parsedItems) {
    final SentenceHuntItem item = parsed.item!;
    itemProjection.add(<String, Object?>{
      'id': item.identity.itemId,
      'sentenceId': item.identity.sentenceId,
      'audioRefId': item.identity.audioRefId,
      'purpose': item.exercise.purpose.name,
      'targetSound': item.exercise.targetSound,
      'targetLabel': item.targetLabel,
      'text': item.sentence.text,
      'debriefNote': item.debriefNote,
      'annotationRevision': item.identity.annotationRevision,
      'annotationHash': item.identity.annotationHash,
      'tokens': <Map<String, Object?>>[
        for (final SentenceToken token in item.sentence.tokens)
          <String, Object?>{
            'id': token.id,
            'text': token.text,
            'phonemes': token.phonemes,
          },
      ],
      'expectedTokenIds': item.expectedTokenIds,
      'originalSha256': parsed.originalSha,
      'clipSha256': parsed.clipSha,
    });
  }
  return _canonicalJson(<String, Object?>{
    'section': <String, Object?>{
      'id': spec.id,
      'kind': kind.name,
      'contentRevision': contentRevision,
      'policyRevision': policyRevision,
      'completionThresholdPercent': threshold,
    },
    'items': itemProjection,
  });
}

String _canonicalJson(Object? value) => jsonEncode(_canonicalValue(value));

Object? _canonicalValue(Object? value) {
  if (value is Map) {
    final List<String> keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final String key in keys) key: _canonicalValue(value[key]),
    };
  }
  if (value is List) {
    return <Object?>[for (final Object? item in value) _canonicalValue(item)];
  }
  return value;
}
