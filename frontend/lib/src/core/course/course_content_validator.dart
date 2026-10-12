/// Structural catalogue validation for the FR-01 curriculum graph.
///
/// Pure Dart: imports only [course_exercise.dart] and [course_curriculum.dart],
/// never French content, providers, storage, widgets or plugins.
///
/// This phase covers the structural namespace, identity, graph, ownership and
/// pool rules of the approved design. The sentence and coverage phases and all
/// readiness reporting are a follow-up on this same public API and
/// intentionally emit no diagnostics yet; the resource inputs of
/// [validateCourseContent] remain part of the frozen revision 1 signature.
///
/// Reports are deterministic: structural namespaces (nodes, sections,
/// exercises, sentences, audio references), then nodes, sections and exercises
/// each in authored order; absent or ambiguous records are reported without
/// arbitrary selection, and unrelated independent issues are retained.
library;

import 'course_exercise.dart';
import 'course_curriculum.dart';

/// Declared availability of an audio content identity; not a runtime voice
/// availability claim and does not manufacture catalogue references.
enum AudioResourceStatus { missing, practiceTts, reviewedRecording }

/// One stable authoring diagnostic, never a learner-facing string.
///
/// Structural errors carry [use] `null`; follow-up readiness issues identify
/// the affected [ContentPurpose].
final class CourseContentDiagnostic {
  CourseContentDiagnostic({
    required String code,
    required String recordId,
    required String message,
    this.use,
  })  : code = _nonblank(code, 'code'),
        recordId = _nonblank(recordId, 'recordId'),
        message = _nonblank(message, 'message');

  /// Frozen rule code, stable across message rewordings.
  final String code;

  /// The catalogue record the rule applies to.
  final String recordId;

  /// Developer-facing explanation.
  final String message;

  /// Affected use; `null` on structural errors.
  final ContentPurpose? use;
}

/// The outcome of validating one curriculum: structural errors plus follow-up
/// readiness issues, both immutable and deterministic.
final class CourseValidationReport {
  CourseValidationReport({
    required List<CourseContentDiagnostic> errors,
    required List<CourseContentDiagnostic> readinessIssues,
  })  : errors = List.unmodifiable(errors),
        readinessIssues = List.unmodifiable(readinessIssues);

  /// Structural errors; `use` is always `null` on these.
  final List<CourseContentDiagnostic> errors;

  /// Honest incomplete-resource issues; empty until the readiness phase.
  final List<CourseContentDiagnostic> readinessIssues;

  /// True while the catalogue is structurally usable.
  bool get isStructurallyValid => errors.isEmpty;
}

/// Deterministic structural validation of one [curriculum].
///
/// The citation, exposure and audio resource inputs are part of the frozen
/// revision 1 signature; the follow-up payload/readiness phases consume them,
/// and this phase intentionally reads no relationship from them.
CourseValidationReport validateCourseContent(
  CourseCurriculum curriculum, {
  required Map<String, List<String>> citationPhonemes,
  required Set<String> exposedWordIds,
  required Map<String, AudioResourceStatus> audioResources,
}) {
  // Structural phases in contract order: namespaces, then nodes, sections and
  // exercises in authored order. The sentence and coverage phases emit no
  // structural diagnostics in this phase, and readiness issues arrive with
  // the follow-up phase.
  final List<CourseContentDiagnostic> errors = [
    ..._findDuplicateIdErrors(curriculum),
    ..._findNodeErrors(curriculum),
    ..._findSectionErrors(curriculum),
    ..._findExerciseErrors(curriculum),
  ];
  return CourseValidationReport(errors: errors, readinessIssues: const []);
}

String _nonblank(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must be a nonblank string');
  }
  return value;
}

CourseContentDiagnostic _diagnostic(
  String code,
  String recordId,
  String message,
) =>
    CourseContentDiagnostic(code: code, recordId: recordId, message: message);

/// Values that occur more than once, in first-appearance authored order.
List<String> _repeatedInOrder(List<String> values) {
  final seen = <String>{};
  final repeated = <String>[];
  for (final value in values) {
    if (seen.contains(value)) {
      if (!repeated.contains(value)) {
        repeated.add(value);
      }
    } else {
      seen.add(value);
    }
  }
  return repeated;
}

/// First-appearance deduplication preserving authored order.
List<String> _distinctInOrder(List<String> values) {
  final seen = <String>{};
  final distinct = <String>[];
  for (final value in values) {
    if (seen.add(value)) {
      distinct.add(value);
    }
  }
  return distinct;
}

const Set<CourseNodeKind> _optionalOnlyKinds = {
  CourseNodeKind.review,
  CourseNodeKind.game,
  CourseNodeKind.articulation,
};

const Set<CourseNodeKind> _sectionRequiringKinds = {
  CourseNodeKind.lesson,
  CourseNodeKind.assessment,
};

const Map<CourseStage, int> _stageRank = {
  CourseStage.hear: 0,
  CourseStage.find: 1,
  CourseStage.spell: 2,
  CourseStage.assess: 3,
};

/// Duplicate IDs per lookup namespace, detected before any reference is
/// resolved so lookups stay absent-or-duplicate, never a silent pick.
List<CourseContentDiagnostic> _findDuplicateIdErrors(
  CourseCurriculum curriculum,
) {
  final errors = <CourseContentDiagnostic>[];
  void namespace(String label, List<String> ids) {
    for (final id in _repeatedInOrder(ids)) {
      errors.add(_diagnostic(
        'duplicateId',
        id,
        "ID '$id' is declared more than once in the $label namespace",
      ));
    }
  }

  namespace('nodes', [for (final node in curriculum.nodes) node.id]);
  namespace(
      'sections', [for (final section in curriculum.sections) section.id]);
  namespace(
    'exercises',
    [for (final exercise in curriculum.exercises) exercise.id],
  );
  namespace(
      'sentences', [for (final sentence in curriculum.sentences) sentence.id]);
  namespace(
    'audio references',
    [for (final reference in curriculum.audioReferences) reference.id],
  );
  return errors;
}

/// Node-level rules, authored order, with the prerequisite cycle pass last.
List<CourseContentDiagnostic> _findNodeErrors(CourseCurriculum curriculum) {
  final errors = <CourseContentDiagnostic>[];
  for (final node in curriculum.nodes) {
    for (final id in _repeatedInOrder(node.prerequisiteIds)) {
      errors.add(_diagnostic(
        'duplicateMembership',
        node.id,
        "node '${node.id}' lists prerequisite ID '$id' more than once",
      ));
    }
    for (final id in _repeatedInOrder(node.sectionIds)) {
      errors.add(_diagnostic(
        'duplicateMembership',
        node.id,
        "node '${node.id}' lists section ID '$id' more than once",
      ));
    }
    for (final id in _distinctInOrder(node.prerequisiteIds)) {
      if (curriculum.nodeById(id) == null) {
        errors.add(_diagnostic(
          'missingReference',
          node.id,
          "node '${node.id}' references absent or duplicated prerequisite ID '$id'",
        ));
      }
    }
    for (final id in _distinctInOrder(node.sectionIds)) {
      if (curriculum.sectionById(id) == null) {
        errors.add(_diagnostic(
          'missingReference',
          node.id,
          "node '${node.id}' references absent or duplicated section ID '$id'",
        ));
      }
    }
    if (node.kind == CourseNodeKind.assessment &&
        node.stage != CourseStage.assess) {
      errors.add(_diagnostic(
        'invalidNodeKind',
        node.id,
        "node '${node.id}' is an assessment but stage ${node.stage.name} is not assess",
      ));
    }
    if (_optionalOnlyKinds.contains(node.kind) && !node.optional) {
      errors.add(_diagnostic(
        'invalidNodeKind',
        node.id,
        "node '${node.id}' with kind ${node.kind.name} must be optional",
      ));
    }
    if (node.status == ContentStatus.planned && node.sectionIds.isNotEmpty) {
      errors.add(_diagnostic(
        'plannedPayload',
        node.id,
        "planned node '${node.id}' declares sections; planned nodes carry no sections in FR-01",
      ));
    }
    if (node.status == ContentStatus.authored &&
        _sectionRequiringKinds.contains(node.kind) &&
        node.sectionIds.isEmpty) {
      errors.add(_diagnostic(
        'missingSection',
        node.id,
        "authored ${node.kind.name} node '${node.id}' declares no sections",
      ));
    }
    for (final id in _distinctInOrder(node.prerequisiteIds)) {
      final prerequisite = curriculum.nodeById(id);
      if (prerequisite == null) continue;
      if (!node.optional && prerequisite.optional) {
        errors.add(_diagnostic(
          'optionalPrerequisite',
          node.id,
          "required node '${node.id}' depends on optional node '$id'",
        ));
      }
      if (!node.optional &&
          !prerequisite.optional &&
          _stageRank[node.stage]! < _stageRank[prerequisite.stage]!) {
        errors.add(_diagnostic(
          'backwardStage',
          node.id,
          "main node '${node.id}' (${node.stage.name}) depends on later main node '$id' (${prerequisite.stage.name})",
        ));
      }
    }
  }
  errors.addAll(_findCycleErrors(curriculum));
  return errors;
}

/// Deterministic depth-first walk in authored order over resolvable
/// prerequisite edges only; each encountered back edge is reported once, and
/// absent or ambiguous targets are skipped rather than recursed into.
List<CourseContentDiagnostic> _findCycleErrors(CourseCurriculum curriculum) {
  final errors = <CourseContentDiagnostic>[];
  final black = <String>{};
  final gray = <String>{};
  for (final root in curriculum.nodes) {
    if (black.contains(root.id)) continue;
    gray.add(root.id);
    final stack = <_PrerequisiteFrame>[_PrerequisiteFrame(root)];
    while (stack.isNotEmpty) {
      final frame = stack.last;
      var descended = false;
      while (frame.next < frame.edges.length) {
        final prerequisiteId = frame.edges[frame.next];
        frame.next++;
        final prerequisite = curriculum.nodeById(prerequisiteId);
        if (prerequisite == null) continue;
        if (gray.contains(prerequisiteId)) {
          errors.add(_diagnostic(
            'cyclicPrerequisite',
            frame.node.id,
            "node '${frame.node.id}' lists prerequisite '$prerequisiteId' that is still on the current prerequisite path",
          ));
          continue;
        }
        if (black.contains(prerequisiteId)) continue;
        gray.add(prerequisiteId);
        stack.add(_PrerequisiteFrame(prerequisite));
        descended = true;
        break;
      }
      if (!descended) {
        gray.remove(frame.node.id);
        black.add(frame.node.id);
        stack.removeLast();
      }
    }
  }
  return errors;
}

class _PrerequisiteFrame {
  _PrerequisiteFrame(this.node)
      : edges = _distinctInOrder(node.prerequisiteIds);

  final CourseNode node;
  final List<String> edges;
  int next = 0;
}

/// Section-level rules, authored order, then reverse ownership and unowned
/// sections.
List<CourseContentDiagnostic> _findSectionErrors(CourseCurriculum curriculum) {
  final errors = <CourseContentDiagnostic>[];
  final listedByAnyNode = <String>{};
  for (final node in curriculum.nodes) {
    for (final id in node.sectionIds) {
      listedByAnyNode.add(id);
    }
  }
  for (final section in curriculum.sections) {
    for (final id in _repeatedInOrder(section.exerciseIds)) {
      errors.add(_diagnostic(
        'duplicateMembership',
        section.id,
        "section '${section.id}' lists exercise ID '$id' more than once",
      ));
    }
    final owner = curriculum.nodeById(section.nodeId);
    if (owner == null) {
      errors.add(_diagnostic(
        'missingReference',
        section.id,
        "section '${section.id}' declares absent or duplicated owner node ID '${section.nodeId}'",
      ));
    } else if (!owner.sectionIds.contains(section.id)) {
      errors.add(_diagnostic(
        'ownershipMismatch',
        section.id,
        "section '${section.id}' claims owner node '${owner.id}' whose sections do not include '${section.id}'",
      ));
    }
    for (final id in _distinctInOrder(section.exerciseIds)) {
      if (curriculum.exerciseById(id) == null) {
        errors.add(_diagnostic(
          'missingReference',
          section.id,
          "section '${section.id}' references absent or duplicated exercise ID '$id'",
        ));
      }
    }
    final distinctCount = _distinctInOrder(section.exerciseIds).length;
    if (distinctCount != section.requiredItemCount) {
      errors.add(_diagnostic(
        'poolSizeMismatch',
        section.id,
        "section '${section.id}' links $distinctCount distinct exercises but requires ${section.requiredItemCount} items",
      ));
    }
  }
  // Exact owner both directions: a listed section must claim back its lister.
  for (final node in curriculum.nodes) {
    for (final id in _distinctInOrder(node.sectionIds)) {
      final section = curriculum.sectionById(id);
      if (section != null && section.nodeId != node.id) {
        errors.add(_diagnostic(
          'ownershipMismatch',
          node.id,
          "node '${node.id}' lists section '$id' which declares a different owner",
        ));
      }
    }
  }
  for (final section in curriculum.sections) {
    if (!listedByAnyNode.contains(section.id)) {
      errors.add(_diagnostic(
        'unownedRecord',
        section.id,
        "section '${section.id}' is in the catalogue but appears in no node's sections",
      ));
    }
  }
  return errors;
}

/// Exercise-level rules, authored order, then reverse ownership, unowned
/// exercises and per-section legacy alias duplicates.
List<CourseContentDiagnostic> _findExerciseErrors(
  CourseCurriculum curriculum,
) {
  final errors = <CourseContentDiagnostic>[];
  final listedByAnySection = <String>{};
  for (final section in curriculum.sections) {
    for (final id in section.exerciseIds) {
      listedByAnySection.add(id);
    }
  }
  for (final exercise in curriculum.exercises) {
    final owner = curriculum.sectionById(exercise.sectionId);
    if (owner == null) {
      errors.add(_diagnostic(
        'missingReference',
        exercise.id,
        "exercise '${exercise.id}' declares absent or duplicated owner section ID '${exercise.sectionId}'",
      ));
    } else if (!owner.exerciseIds.contains(exercise.id)) {
      errors.add(_diagnostic(
        'ownershipMismatch',
        exercise.id,
        "exercise '${exercise.id}' claims owner section '${owner.id}' whose exercises do not include '${exercise.id}'",
      ));
    }
  }
  // Exact owner both directions: a listed exercise must claim back its lister.
  for (final section in curriculum.sections) {
    for (final id in _distinctInOrder(section.exerciseIds)) {
      final exercise = curriculum.exerciseById(id);
      if (exercise != null && exercise.sectionId != section.id) {
        errors.add(_diagnostic(
          'ownershipMismatch',
          section.id,
          "section '${section.id}' lists exercise '$id' which declares a different owner",
        ));
      }
    }
  }
  for (final exercise in curriculum.exercises) {
    if (!listedByAnySection.contains(exercise.id)) {
      errors.add(_diagnostic(
        'unownedRecord',
        exercise.id,
        "exercise '${exercise.id}' is in the catalogue but appears in no section's exercises",
      ));
    }
  }
  // Distinct listening exercises in one section must not share a legacy
  // compatibility alias; the same alias across sections stays allowed.
  for (final section in curriculum.sections) {
    final firstOwners = <String, String>{};
    for (final id in _distinctInOrder(section.exerciseIds)) {
      final exercise = curriculum.exerciseById(id);
      if (exercise is! ListeningChoiceExercise) continue;
      final legacyItemId = exercise.legacyItemId;
      if (legacyItemId == null) continue;
      final firstOwner = firstOwners[legacyItemId];
      if (firstOwner == null) {
        firstOwners[legacyItemId] = id;
      } else {
        errors.add(_diagnostic(
          'duplicateLegacyItemId',
          section.id,
          "section '${section.id}' declares legacy item ID '$legacyItemId' for distinct exercises '$firstOwner' and '$id'",
        ));
      }
    }
  }
  return errors;
}
