import 'dart:collection';
import 'course_exercise.dart';

const comparisonActivityId = 'en-fr-phoneme-comparison';
const String uyDemoComparisonActivityId = 'en-fr-u-y-comparison';

final class ComparisonCatalogueRegistration {
  ComparisonCatalogueRegistration._({
    required this.activityId,
    required this.catalogue,
    this.cause,
  });

  factory ComparisonCatalogueRegistration.available(
    ComparisonCatalogue catalogue,
  ) => ComparisonCatalogueRegistration._(
    activityId: catalogue.activityId,
    catalogue: catalogue,
  );

  factory ComparisonCatalogueRegistration.unavailable({
    required String activityId,
    required Object cause,
  }) {
    if (activityId.trim().isEmpty) {
      throw const FormatException(
        'Registration activity ID must not be blank.',
      );
    }
    return ComparisonCatalogueRegistration._(
      activityId: activityId,
      catalogue: null,
      cause: cause,
    );
  }

  final String activityId;
  final ComparisonCatalogue? catalogue;
  final Object? cause;
}

final class ComparisonCatalogueRegistry {
  ComparisonCatalogueRegistry(
    Iterable<ComparisonCatalogueRegistration> registrations,
  ) : byActivityId = _registrationsById(registrations);

  static Map<String, ComparisonCatalogueRegistration> _registrationsById(
    Iterable<ComparisonCatalogueRegistration> registrations,
  ) {
    final result = <String, ComparisonCatalogueRegistration>{};
    for (final registration in registrations) {
      if (registration.catalogue != null &&
          registration.catalogue!.activityId != registration.activityId) {
        throw const FormatException(
          'Registration activity ID does not match catalogue.',
        );
      }
      if (result.containsKey(registration.activityId)) {
        throw const FormatException('Duplicate catalogue registration.');
      }
      result[registration.activityId] = registration;
    }
    return UnmodifiableMapView(result);
  }

  final Map<String, ComparisonCatalogueRegistration> byActivityId;

  ComparisonCatalogueRegistration? registrationFor(String activityId) =>
      byActivityId[activityId];

  ComparisonCatalogue requireAvailable(String activityId) {
    final registration = registrationFor(activityId);
    if (registration == null) {
      throw StateError('Unknown comparison activity: $activityId');
    }
    final catalogue = registration.catalogue;
    if (catalogue == null) {
      throw StateError('Comparison activity is unavailable: $activityId');
    }
    return catalogue;
  }

  factory ComparisonCatalogueRegistry.single(ComparisonCatalogue catalogue) =>
      ComparisonCatalogueRegistry([
        ComparisonCatalogueRegistration.available(catalogue),
      ]);
}

enum ComparisonSample { a, b }

enum PhonemeRelation { same, different }

final class ComparisonTarget {
  const ComparisonTarget({
    required this.phonemeId,
    required this.phonemeOrdinal,
  });
  final String phonemeId;
  final int phonemeOrdinal;
}

final class ComparisonSampleContent {
  const ComparisonSampleContent({
    required this.slot,
    required this.referenceId,
    required this.target,
  });
  final ComparisonSample slot;
  final String referenceId;
  final ComparisonTarget target;
}

final class ComparisonExercise {
  const ComparisonExercise({
    required this.id,
    required this.activityId,
    required this.sectionId,
    required this.contentRevision,
    required this.purpose,
    required this.reviewState,
    required this.instruction,
    required this.sampleA,
    required this.sampleB,
    required this.expectedRelation,
    required this.debriefNote,
  });
  final String id, activityId, sectionId, instruction, debriefNote;
  final int contentRevision;
  final ContentPurpose purpose;
  final ContentReviewState reviewState;
  final ComparisonSampleContent sampleA, sampleB;
  final PhonemeRelation expectedRelation;
}

final class ComparisonTargetDraft {
  const ComparisonTargetDraft({
    required this.phonemeId,
    required this.phonemeOrdinal,
  });
  final String? phonemeId;
  final int? phonemeOrdinal;
}

final class ComparisonSampleDraft {
  const ComparisonSampleDraft({
    required this.slot,
    required this.referenceId,
    required this.target,
  });
  final ComparisonSample? slot;
  final String? referenceId;
  final ComparisonTargetDraft? target;
}

final class ComparisonExerciseDraft {
  const ComparisonExerciseDraft({
    required this.id,
    required this.activityId,
    required this.sectionId,
    required this.contentRevision,
    required this.purpose,
    required this.reviewState,
    required this.instruction,
    required this.sampleA,
    required this.sampleB,
    required this.expectedRelation,
    required this.debriefNote,
  });
  final String? id, activityId, sectionId, instruction, debriefNote;
  final int? contentRevision;
  final ContentPurpose? purpose;
  final ContentReviewState? reviewState;
  final ComparisonSampleDraft? sampleA, sampleB;
  final PhonemeRelation? expectedRelation;
}

final class ComparisonContentDiagnostic {
  const ComparisonContentDiagnostic({
    required this.code,
    required this.recordId,
  });
  final String code, recordId;
}

final class ComparisonContentValidationException implements Exception {
  ComparisonContentValidationException(
    List<ComparisonContentDiagnostic> diagnostics,
  ) : diagnostics = List.unmodifiable(diagnostics);
  final List<ComparisonContentDiagnostic> diagnostics;
}

List<ComparisonContentDiagnostic> validateComparisonCatalogue({
  required String activityId,
  required String sectionId,
  required int contentRevision,
  required List<ComparisonExerciseDraft> exercises,
  required Map<String, List<String>> referencePhonemes,
}) {
  final out = <ComparisonContentDiagnostic>[];
  void add(String code, String id) =>
      out.add(ComparisonContentDiagnostic(code: code, recordId: id));
  if (activityId.trim().isEmpty) add('catalogue.activity', '');
  if (sectionId.trim().isEmpty) add('catalogue.section', '');
  if (contentRevision < 1) add('catalogue.revision', '');
  final headersValid =
      activityId.trim().isNotEmpty &&
      sectionId.trim().isNotEmpty &&
      contentRevision >= 1;
  final ids = <String>{};
  var allRecordsValid = true;
  var hasDuplicateId = false;
  final validRelations = <PhonemeRelation>[];
  for (final e in exercises) {
    final id = e.id ?? '';
    var recordValid = true;
    if (id.trim().isEmpty) {
      add('exercise.id.blank', id);
      recordValid = false;
    } else if (!ids.add(id)) {
      add('exercise.id.duplicate', id);
      recordValid = false;
      hasDuplicateId = true;
    }
    if (e.activityId != activityId ||
        e.activityId == null ||
        e.activityId!.trim().isEmpty) {
      add('exercise.activity', id);
      recordValid = false;
    }
    if (e.sectionId != sectionId ||
        e.sectionId == null ||
        e.sectionId!.trim().isEmpty) {
      add('exercise.section', id);
      recordValid = false;
    }
    if (e.contentRevision != contentRevision ||
        e.contentRevision == null ||
        e.contentRevision! < 1) {
      add('exercise.revision', id);
      recordValid = false;
    }
    if (e.purpose != ContentPurpose.practice) {
      add('exercise.purpose', id);
      recordValid = false;
    }
    if (e.reviewState != ContentReviewState.pending) {
      add('exercise.reviewState', id);
      recordValid = false;
    }
    if (e.instruction == null || e.instruction!.trim().isEmpty) {
      add('exercise.instruction', id);
      recordValid = false;
    }
    final targets = <ComparisonTargetDraft?>[];
    final sampleValid = <bool>[];
    for (final pair in [
      ('sampleA', e.sampleA, ComparisonSample.a),
      ('sampleB', e.sampleB, ComparisonSample.b),
    ]) {
      final name = pair.$1;
      final s = pair.$2;
      final slot = pair.$3;
      if (s == null) {
        add('exercise.$name.missing', id);
        targets.add(null);
        sampleValid.add(false);
        recordValid = false;
        continue;
      }
      var thisSampleValid = true;
      if (s.slot != slot) {
        add('exercise.$name.slot', id);
        thisSampleValid = false;
      }
      final seq = s.referenceId == null
          ? null
          : referencePhonemes[s.referenceId];
      if (s.referenceId == null || seq == null) {
        add('exercise.$name.reference', id);
        thisSampleValid = false;
      }
      if (s.target == null) {
        add('exercise.$name.target.missing', id);
        targets.add(null);
        sampleValid.add(false);
        recordValid = false;
        continue;
      }
      final t = s.target!;
      targets.add(t);
      final phonemeBlank = t.phonemeId == null || t.phonemeId!.trim().isEmpty;
      if (phonemeBlank) {
        add('exercise.$name.target.phoneme', id);
        thisSampleValid = false;
      }
      final ordinalInvalid =
          t.phonemeOrdinal == null ||
          t.phonemeOrdinal! < 0 ||
          (seq != null && t.phonemeOrdinal! >= seq.length);
      if (ordinalInvalid) {
        add('exercise.$name.target.ordinal', id);
        thisSampleValid = false;
      } else if (!phonemeBlank &&
          seq != null &&
          seq[t.phonemeOrdinal!] != t.phonemeId) {
        add('exercise.$name.target.phoneme', id);
        thisSampleValid = false;
      }
      sampleValid.add(thisSampleValid);
      if (!thisSampleValid) recordValid = false;
    }
    if (e.debriefNote == null || e.debriefNote!.trim().isEmpty) {
      add('exercise.note', id);
      recordValid = false;
    }
    if (e.expectedRelation == null) {
      add('exercise.relation.missing', id);
      recordValid = false;
    } else if (sampleValid.length == 2 &&
        sampleValid.every((valid) => valid) &&
        (e.expectedRelation == PhonemeRelation.same) !=
            (targets[0]!.phonemeId == targets[1]!.phonemeId)) {
      add('exercise.relation.mismatch', id);
      recordValid = false;
    } else if (recordValid) {
      validRelations.add(e.expectedRelation!);
    }
    if (!recordValid) allRecordsValid = false;
  }
  if (exercises.length != 10 && !hasDuplicateId) {
    add('catalogue.count', '');
  }
  if (headersValid &&
      exercises.length == 10 &&
      ids.length == 10 &&
      allRecordsValid &&
      validRelations.length == 10 &&
      validRelations.where((r) => r == PhonemeRelation.same).length != 5) {
    add('catalogue.balance', '');
  }
  return List.unmodifiable(out);
}

final class ComparisonCatalogue {
  ComparisonCatalogue._(
    this.activityId,
    this.sectionId,
    this.contentRevision,
    List<ComparisonExercise> exercises,
  ) : exercises = List.unmodifiable(exercises),
      byId = UnmodifiableMapView({for (final e in exercises) e.id: e});
  factory ComparisonCatalogue.fromDrafts({
    required String activityId,
    required String sectionId,
    required int contentRevision,
    required List<ComparisonExerciseDraft> exercises,
    required Map<String, List<String>> referencePhonemes,
  }) {
    final errors = validateComparisonCatalogue(
      activityId: activityId,
      sectionId: sectionId,
      contentRevision: contentRevision,
      exercises: exercises,
      referencePhonemes: referencePhonemes,
    );
    if (errors.isNotEmpty) throw ComparisonContentValidationException(errors);
    return ComparisonCatalogue._(activityId, sectionId, contentRevision, [
      for (final e in exercises)
        ComparisonExercise(
          id: e.id!,
          activityId: e.activityId!,
          sectionId: e.sectionId!,
          contentRevision: e.contentRevision!,
          purpose: e.purpose!,
          reviewState: e.reviewState!,
          instruction: e.instruction!,
          sampleA: _sample(e.sampleA!, ComparisonSample.a),
          sampleB: _sample(e.sampleB!, ComparisonSample.b),
          expectedRelation: e.expectedRelation!,
          debriefNote: e.debriefNote!,
        ),
    ]);
  }
  static ComparisonSampleContent _sample(
    ComparisonSampleDraft s,
    ComparisonSample slot,
  ) => ComparisonSampleContent(
    slot: slot,
    referenceId: s.referenceId!,
    target: ComparisonTarget(
      phonemeId: s.target!.phonemeId!,
      phonemeOrdinal: s.target!.phonemeOrdinal!,
    ),
  );
  final String activityId, sectionId;
  final int contentRevision;
  final List<ComparisonExercise> exercises;
  final Map<String, ComparisonExercise> byId;
  ComparisonExercise exercise(String id) =>
      byId[id] ?? (throw ArgumentError.value(id, 'id'));
  String noteFor(String pairId) => exercise(pairId).debriefNote;
  List<String> notesFor(Iterable<String> pairIds) {
    final ids = pairIds.toList();
    if (ids.toSet().length != ids.length) throw ArgumentError('duplicate IDs');
    for (final id in ids) {
      if (!byId.containsKey(id)) throw ArgumentError.value(id, 'pairId');
    }
    return List.unmodifiable([
      for (final e in exercises)
        if (ids.contains(e.id)) e.debriefNote,
    ]);
  }
}
