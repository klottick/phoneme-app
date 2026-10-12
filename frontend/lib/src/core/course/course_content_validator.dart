/// Structural catalogue validation and honest resource-readiness reporting
/// for the FR-01 curriculum graph.
///
/// Pure Dart: imports only [course_exercise.dart] and [course_curriculum.dart],
/// never French content, providers, storage, widgets or plugins.
///
/// Covers the structural namespace, identity, graph, ownership and pool rules,
/// the exercise/sentence payload rules, the coverage rules, and the readiness
/// phases — all on the frozen revision 1 [validateCourseContent] signature.
///
/// Reports are deterministic: structural phases run in contract order —
/// namespaces (nodes, sections, exercises, sentences, audio references), then
/// nodes, sections, exercises, sentences and coverage, each in authored order —
/// then readiness nodes, coverage, exercises/sentences and audio references.
/// Absent or ambiguous records are reported without arbitrary selection, and
/// unrelated independent issues are retained.
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

/// The outcome of validating one curriculum: structural errors plus honest
/// readiness issues, both immutable and deterministic.
final class CourseValidationReport {
  CourseValidationReport({
    required List<CourseContentDiagnostic> errors,
    required List<CourseContentDiagnostic> readinessIssues,
  })  : errors = List.unmodifiable(errors),
        readinessIssues = List.unmodifiable(readinessIssues);

  /// Structural errors; `use` is always `null` on these.
  final List<CourseContentDiagnostic> errors;

  /// Honest incomplete-resource issues; each identifies its affected use.
  final List<CourseContentDiagnostic> readinessIssues;

  /// True while the catalogue is structurally usable.
  bool get isStructurallyValid => errors.isEmpty;
}

/// Deterministic validation of one [curriculum]: structural errors in
/// contract phase order, then readiness issues in contract phase order.
///
/// [citationPhonemes] validates word exercises only; sentence targets use
/// their own reviewed contextual annotations, never a citation guess.
/// [exposedWordIds] is unioned with the practice word-exercise IDs so caller
/// omission cannot convert authored practice words into held-out content.
/// [audioResources] are injected declarations, never device or file probes;
/// keys that match no reference are ignored rather than manufactured.
CourseValidationReport validateCourseContent(
  CourseCurriculum curriculum, {
  required Map<String, List<String>> citationPhonemes,
  required Set<String> exposedWordIds,
  required Map<String, AudioResourceStatus> audioResources,
}) {
  final inventory = _coverageSoundInventory(curriculum);
  // Structural phases in contract order: namespaces, nodes, sections,
  // exercises, sentences and coverage, each in authored order. Exercise
  // records emit per-record ownership then payload diagnostics so later
  // records cannot precede earlier payloads; section-keyed link checks
  // follow in authored section order.
  final List<CourseContentDiagnostic> errors = [
    ..._findDuplicateIdErrors(curriculum),
    ..._findNodeErrors(curriculum, inventory),
    ..._findSectionErrors(curriculum),
    ..._findExerciseRecordErrors(
        curriculum, inventory, citationPhonemes, exposedWordIds),
    ..._findExerciseSectionLinkErrors(curriculum),
    ..._findSentenceErrors(curriculum),
    ..._findCoverageErrors(curriculum),
  ];
  // Readiness phases in contract order: nodes, coverage, exercises/sentences
  // and audio references, each in authored order.
  final List<CourseContentDiagnostic> readinessIssues = [
    ..._findNodeReadinessIssues(curriculum),
    ..._findCoverageReadinessIssues(curriculum),
    ..._findExerciseReadinessIssues(curriculum, audioResources),
    ..._findReferenceReadinessIssues(curriculum, audioResources),
  ];
  return CourseValidationReport(
    errors: errors,
    readinessIssues: readinessIssues,
  );
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

CourseContentDiagnostic _readinessDiagnostic(
  String code,
  String recordId,
  String message,
  ContentPurpose use,
) =>
    CourseContentDiagnostic(
      code: code,
      recordId: recordId,
      message: message,
      use: use,
    );

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

/// Node-level rules, authored order: membership, references, kinds, payload
/// targets, then the prerequisite cycle pass last.
List<CourseContentDiagnostic> _findNodeErrors(
  CourseCurriculum curriculum,
  Set<String> inventory,
) {
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
    // Target label rules: duplicate labels, empty labels, and labels absent
    // from the declared coverage inventory.
    for (final label in _repeatedInOrder(node.targetSounds)) {
      errors.add(_diagnostic(
        'invalidTargets',
        node.id,
        "node '${node.id}' lists target sound '$label' more than once",
      ));
    }
    if (node.targetSounds.any((label) => label.trim().isEmpty)) {
      errors.add(_diagnostic(
        'invalidTargets',
        node.id,
        "node '${node.id}' declares an empty target sound label",
      ));
    }
    for (final label in _distinctInOrder(node.targetSounds)) {
      if (label.trim().isEmpty) continue; // Already reported as an empty label.
      if (!inventory.contains(label)) {
        errors.add(_diagnostic(
          'invalidTargets',
          node.id,
          "node '${node.id}' targets undeclared sound '$label' absent from the coverage inventory",
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

/// Exercise records, authored order. Each exercise emits its ownership
/// diagnostics (owner absence, claim mismatch, unowned record) and then its
/// payload diagnostics, as one unit: independent issues on a later exercise
/// can therefore never precede an earlier exercise's payload diagnostics.
List<CourseContentDiagnostic> _findExerciseRecordErrors(
  CourseCurriculum curriculum,
  Set<String> inventory,
  Map<String, List<String>> citationPhonemes,
  Set<String> exposedWordIds,
) {
  final errors = <CourseContentDiagnostic>[];
  final listedByAnySection = <String>{};
  for (final section in curriculum.sections) {
    for (final id in section.exerciseIds) {
      listedByAnySection.add(id);
    }
  }
  final practiceAudioRefIds = <String>{
    for (final exercise in curriculum.exercises)
      if (exercise.purpose == ContentPurpose.practice) exercise.audioRefId,
  };
  final effectiveExposedWordIds = <String>{...exposedWordIds};
  for (final exercise in curriculum.exercises) {
    if (exercise.purpose != ContentPurpose.practice) continue;
    final wordId = _wordIdOf(exercise);
    if (wordId != null) {
      effectiveExposedWordIds.add(wordId);
    }
  }

  for (final exercise in curriculum.exercises) {
    // Ownership for this record: absence, then claim, then listing.
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
    if (!listedByAnySection.contains(exercise.id)) {
      errors.add(_diagnostic(
        'unownedRecord',
        exercise.id,
        "exercise '${exercise.id}' is in the catalogue but appears in no section's exercises",
      ));
    }
    // Payload for this record. Node-dependent checks are skipped when the
    // owner chain is absent or ambiguous (already reported above); intrinsic
    // target checks never need the owner.
    final node = owner == null ? null : curriculum.nodeById(owner.nodeId);
    if (node != null) {
      errors.addAll(_findPlacementErrors(exercise, node));
    }
    errors.addAll(_findIntrinsicTargetErrors(exercise, inventory));
    if (node != null) {
      errors.addAll(_findNodeTargetContainmentErrors(exercise, node));
    }
    if (exercise is ListeningChoiceExercise) {
      errors.addAll(_findListeningChoiceErrors(exercise, inventory));
      errors.addAll(_findWordErrors(
        exercise,
        wordId: exercise.wordId,
        targetSound: exercise.expectedSound,
        citationPhonemes: citationPhonemes,
      ));
      final reference = curriculum.audioReferenceById(exercise.audioRefId);
      errors.addAll(_findReferenceErrors(exercise, reference,
          (ref) => ref.spokenText != exercise.wordId ? 'word' : null));
    } else if (exercise is SpellingChoiceExercise) {
      errors.addAll(_findSpellingOptionErrors(exercise));
      errors.addAll(_findWordErrors(
        exercise,
        wordId: exercise.wordId,
        targetSound: exercise.targetSound,
        citationPhonemes: citationPhonemes,
      ));
      final reference = curriculum.audioReferenceById(exercise.audioRefId);
      errors.addAll(_findReferenceErrors(exercise, reference,
          (ref) => ref.spokenText != exercise.wordId ? 'word' : null));
    } else if (exercise is SentenceHuntExercise) {
      final reference = curriculum.audioReferenceById(exercise.audioRefId);
      errors.addAll(_findReferenceErrors(exercise, reference, null));
      final sentence = curriculum.sentenceById(exercise.sentenceId);
      if (sentence == null) {
        errors.add(_diagnostic(
          'missingReference',
          exercise.id,
          "exercise '${exercise.id}' references absent or duplicated sentence ID '${exercise.sentenceId}'",
        ));
      } else {
        errors.addAll(_findSentenceTargetErrors(exercise, sentence));
        if (exercise.audioRefId != sentence.audioRefId) {
          errors.add(_diagnostic(
            'sentenceAudioMismatch',
            exercise.id,
            "hunt '${exercise.id}' uses audio '${exercise.audioRefId}' while sentence '${sentence.id}' declares '${sentence.audioRefId}'",
          ));
        }
      }
    } else if (exercise is ReadAloudExercise) {
      final reference = curriculum.audioReferenceById(exercise.audioRefId);
      errors.addAll(_findReferenceErrors(
          exercise,
          reference,
          (ref) =>
              ref.spokenText != exercise.promptText ? 'promptText' : null));
    }
    if (exercise.purpose == ContentPurpose.assessment) {
      final wordId = _wordIdOf(exercise);
      if (wordId != null && effectiveExposedWordIds.contains(wordId)) {
        errors.add(_diagnostic(
          'exposedAssessmentWord',
          exercise.id,
          "assessment '${exercise.id}' reuses exposed word '$wordId'",
        ));
      }
      if (practiceAudioRefIds.contains(exercise.audioRefId)) {
        errors.add(_diagnostic(
          'exposedAssessmentAudio',
          exercise.id,
          "assessment '${exercise.id}' reuses audio reference '${exercise.audioRefId}' referenced by practice",
        ));
      }
    }
  }
  return errors;
}

/// Section-keyed link checks after all exercise records, authored section
/// order: listed exercises must claim back their lister, and distinct
/// listening exercises in one section must not share a legacy alias (the
/// same alias across sections stays allowed).
List<CourseContentDiagnostic> _findExerciseSectionLinkErrors(
  CourseCurriculum curriculum,
) {
  final errors = <CourseContentDiagnostic>[];
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

/// A Unicode-letter word contains at least one letter; punctuation alone does
/// not form a believable distractor.
final RegExp _unicodeLetterPattern = RegExp(r'\p{L}', unicode: true);

/// A whitespace gap character; token gaps may contain whitespace only.
final RegExp _whitespaceGapPattern = RegExp(r'\s', unicode: true);

/// The stage a purpose-practice exercise of each kind belongs to. Read-aloud
/// carries no stage rule in this revision; its node-kind rule is separate.
const Map<ExerciseKind, CourseStage> _practiceStageByKind = {
  ExerciseKind.listeningChoice: CourseStage.hear,
  ExerciseKind.sentenceHunt: CourseStage.find,
  ExerciseKind.spellingChoice: CourseStage.spell,
};

/// Read-aloud is allowed in optional articulation or assessment nodes only.
const Set<CourseNodeKind> _readAloudAllowedNodeKinds = {
  CourseNodeKind.articulation,
  CourseNodeKind.assessment,
};

/// The declared coverage sound inventory for target membership checks.
Set<String> _coverageSoundInventory(CourseCurriculum curriculum) {
  final inventory = <String>{};
  for (final coverage in curriculum.phonemeCoverage) {
    inventory.add(coverage.sound);
  }
  return inventory;
}

/// Placement: purpose versus node kind, assessment stage fit, practice stage
/// per kind, and read-aloud node-kind allowance. Each violated condition is
/// reported independently in deterministic order.
List<CourseContentDiagnostic> _findPlacementErrors(
  CourseExercise exercise,
  CourseNode node,
) {
  final errors = <CourseContentDiagnostic>[];
  final expectedPurpose = node.kind == CourseNodeKind.assessment
      ? ContentPurpose.assessment
      : ContentPurpose.practice;
  if (exercise.purpose != expectedPurpose) {
    errors.add(_diagnostic(
      'invalidExercisePlacement',
      exercise.id,
      "exercise '${exercise.id}' has purpose ${exercise.purpose.name} in ${node.kind.name} node '${node.id}' where ${expectedPurpose.name} belongs",
    ));
  }
  if (exercise.purpose == ContentPurpose.assessment &&
      node.kind == CourseNodeKind.assessment &&
      node.stage != CourseStage.assess) {
    errors.add(_diagnostic(
      'invalidExercisePlacement',
      exercise.id,
      "assessment exercise '${exercise.id}' sits in ${node.kind.name} node '${node.id}' on stage ${node.stage.name} instead of assess",
    ));
  }
  final practiceStage = _practiceStageByKind[exercise.kind];
  if (exercise.purpose == ContentPurpose.practice &&
      practiceStage != null &&
      node.stage != practiceStage) {
    errors.add(_diagnostic(
      'invalidExercisePlacement',
      exercise.id,
      "practice ${exercise.kind.name} exercise '${exercise.id}' belongs to stage $practiceStage but node '${node.id}' is ${node.stage.name}",
    ));
  }
  if (exercise is ReadAloudExercise &&
      !_readAloudAllowedNodeKinds.contains(node.kind)) {
    errors.add(_diagnostic(
      'invalidExercisePlacement',
      exercise.id,
      "read-aloud exercise '${exercise.id}' is not allowed in ${node.kind.name} node '${node.id}' in this revision",
    ));
  }
  return errors;
}

/// The teaching target sounds of an exercise, in authored order.
List<String> _teachingTargets(CourseExercise exercise) {
  if (exercise is ReadAloudExercise) return exercise.targetSounds;
  if (exercise is ListeningChoiceExercise) return [exercise.expectedSound];
  if (exercise is SpellingChoiceExercise) return [exercise.targetSound];
  if (exercise is SentenceHuntExercise) return [exercise.targetSound];
  return const [];
}

/// Target defects that no owner is needed to see: read-aloud targets must be
/// nonempty with distinct labels, and every teaching target must be declared
/// in the coverage inventory. These report even when the owner chain is
/// absent or ambiguous.
List<CourseContentDiagnostic> _findIntrinsicTargetErrors(
  CourseExercise exercise,
  Set<String> inventory,
) {
  final errors = <CourseContentDiagnostic>[];
  if (exercise is ReadAloudExercise) {
    if (exercise.targetSounds.isEmpty) {
      errors.add(_diagnostic(
        'invalidTargets',
        exercise.id,
        "read-aloud exercise '${exercise.id}' declares no target sounds",
      ));
    }
    for (final label in _repeatedInOrder(exercise.targetSounds)) {
      errors.add(_diagnostic(
        'invalidTargets',
        exercise.id,
        "read-aloud exercise '${exercise.id}' lists target sound '$label' more than once",
      ));
    }
  }
  for (final sound in _distinctInOrder(_teachingTargets(exercise))) {
    if (!inventory.contains(sound)) {
      errors.add(_diagnostic(
        'invalidTargets',
        exercise.id,
        "exercise '${exercise.id}' targets undeclared sound '$sound' absent from the coverage inventory",
      ));
    }
  }
  return errors;
}

/// Every teaching target must be contained in the owner node's targets; this
/// needs a resolvable owner, so it runs only when the owner chain resolves.
List<CourseContentDiagnostic> _findNodeTargetContainmentErrors(
  CourseExercise exercise,
  CourseNode node,
) {
  final errors = <CourseContentDiagnostic>[];
  for (final sound in _distinctInOrder(_teachingTargets(exercise))) {
    if (!node.targetSounds.contains(sound)) {
      errors.add(_diagnostic(
        'invalidTargets',
        exercise.id,
        "exercise '${exercise.id}' targets '$sound' outside node '${node.id}' targets ${node.targetSounds.join(', ')}",
      ));
    }
  }
  return errors;
}

/// At least two distinct choices, no duplicate labels, the expected sound
/// exactly once, and every choice within the declared inventory.
List<CourseContentDiagnostic> _findListeningChoiceErrors(
  ListeningChoiceExercise exercise,
  Set<String> inventory,
) {
  final errors = <CourseContentDiagnostic>[];
  if (_distinctInOrder(exercise.choices).length < 2) {
    errors.add(_diagnostic(
      'invalidListeningChoices',
      exercise.id,
      "listening exercise '${exercise.id}' offers fewer than two distinct choices",
    ));
  }
  for (final label in _repeatedInOrder(exercise.choices)) {
    errors.add(_diagnostic(
      'invalidListeningChoices',
      exercise.id,
      "listening exercise '${exercise.id}' repeats choice label '$label'",
    ));
  }
  final expectedCount = exercise.choices
      .where((choice) => choice == exercise.expectedSound)
      .length;
  if (expectedCount != 1) {
    errors.add(_diagnostic(
      'invalidListeningChoices',
      exercise.id,
      "listening exercise '${exercise.id}' expected sound '${exercise.expectedSound}' occurs $expectedCount times in its choices",
    ));
  }
  for (final choice in _distinctInOrder(exercise.choices)) {
    if (!inventory.contains(choice)) {
      errors.add(_diagnostic(
        'invalidListeningChoices',
        exercise.id,
        "listening exercise '${exercise.id}' offers undeclared choice '$choice' absent from the coverage inventory",
      ));
    }
  }
  return errors;
}

/// At least two options, distinct option IDs and texts, and exactly one
/// referenced correct option.
List<CourseContentDiagnostic> _findSpellingOptionErrors(
  SpellingChoiceExercise exercise,
) {
  final errors = <CourseContentDiagnostic>[];
  final optionIds = [for (final option in exercise.options) option.id];
  final optionTexts = [for (final option in exercise.options) option.text];
  if (exercise.options.length < 2) {
    errors.add(_diagnostic(
      'invalidSpellingOptions',
      exercise.id,
      "spelling exercise '${exercise.id}' offers fewer than two options",
    ));
  }
  for (final id in _repeatedInOrder(optionIds)) {
    errors.add(_diagnostic(
      'invalidSpellingOptions',
      exercise.id,
      "spelling exercise '${exercise.id}' repeats option ID '$id'",
    ));
  }
  for (final text in _repeatedInOrder(optionTexts)) {
    errors.add(_diagnostic(
      'invalidSpellingOptions',
      exercise.id,
      "spelling exercise '${exercise.id}' repeats option text '$text'",
    ));
  }
  if (!_distinctInOrder(optionIds).contains(exercise.correctOptionId)) {
    errors.add(_diagnostic(
      'invalidSpellingOptions',
      exercise.id,
      "spelling exercise '${exercise.id}' correct option ID '${exercise.correctOptionId}' references no option",
    ));
  }
  return errors;
}

/// The word ID of a word exercise, or null for sentence and read-aloud.
String? _wordIdOf(CourseExercise exercise) {
  if (exercise is ListeningChoiceExercise) return exercise.wordId;
  if (exercise is SpellingChoiceExercise) return exercise.wordId;
  return null;
}

/// Word-exercise rules: the word must be curated, and the explicit target
/// must occur among that word's curated citation phonemes. Sentence targets
/// never use this path; they rely on their own contextual annotations.
List<CourseContentDiagnostic> _findWordErrors(
  CourseExercise exercise, {
  required String wordId,
  required String targetSound,
  required Map<String, List<String>> citationPhonemes,
}) {
  final errors = <CourseContentDiagnostic>[];
  final curated = citationPhonemes[wordId];
  if (curated == null) {
    errors.add(_diagnostic(
      'unknownWord',
      exercise.id,
      "word exercise '${exercise.id}' uses word '$wordId' absent from the curated citation phonemes",
    ));
    return errors;
  }
  if (!curated.contains(targetSound)) {
    errors.add(_diagnostic(
      'citationTargetMismatch',
      exercise.id,
      "word exercise '${exercise.id}' target '$targetSound' is not among curated phonemes for word '$wordId'",
    ));
  }
  return errors;
}

/// Audio-reference rules for one exercise: absent or ambiguous reference,
/// mismatched declared kind, and spoken-text disagreement.
List<CourseContentDiagnostic> _findReferenceErrors(
  CourseExercise exercise,
  CourseAudioReference? reference,
  String? Function(CourseAudioReference reference)? mismatchOf,
) {
  final errors = <CourseContentDiagnostic>[];
  if (reference == null) {
    errors.add(_diagnostic(
      'missingReference',
      exercise.id,
      "exercise '${exercise.id}' references absent or duplicated audio ID '${exercise.audioRefId}'",
    ));
    return errors;
  }
  final expectedKind = switch (exercise.kind) {
    ExerciseKind.listeningChoice ||
    ExerciseKind.spellingChoice =>
      AudioReferenceKind.word,
    ExerciseKind.sentenceHunt => AudioReferenceKind.sentence,
    ExerciseKind.readAloud => AudioReferenceKind.paragraph,
  };
  if (reference.kind != expectedKind) {
    errors.add(_diagnostic(
      'invalidAudioKind',
      exercise.id,
      "exercise '${exercise.id}' (${exercise.kind.name}) references ${reference.kind.name}-kind audio '${reference.id}' instead of $expectedKind",
    ));
  }
  final mismatch = mismatchOf != null ? mismatchOf(reference) : null;
  if (mismatch != null) {
    errors.add(_diagnostic(
      'audioTextMismatch',
      exercise.id,
      "exercise '${exercise.id}' ${mismatch == 'promptText' ? 'prompt' : 'word'} disagrees with spokenText '${reference.spokenText}' of audio '${reference.id}'",
    ));
  }
  return errors;
}

/// Hunt answer-key rules from the referenced sentence's reviewed
/// contextual annotations: at least one token carrying the target sound and
/// at least one non-target word token; punctuation alone is not a
/// distractor.
List<CourseContentDiagnostic> _findSentenceTargetErrors(
  SentenceHuntExercise exercise,
  CourseSentence sentence,
) {
  final errors = <CourseContentDiagnostic>[];
  final tokens = sentence.tokens;
  final targetTokens = [
    for (final token in tokens)
      if (token.phonemes.contains(exercise.targetSound)) token,
  ];
  if (targetTokens.isEmpty) {
    errors.add(_diagnostic(
      'invalidSentenceTargets',
      exercise.id,
      "hunt '${exercise.id}' has no token in sentence '${sentence.id}' annotated with target sound '${exercise.targetSound}'",
    ));
  }
  final hasWordDistractor = tokens.any((token) =>
      !token.phonemes.contains(exercise.targetSound) &&
      _unicodeLetterPattern.hasMatch(token.text));
  if (!hasWordDistractor) {
    errors.add(_diagnostic(
      'invalidSentenceTargets',
      exercise.id,
      "hunt '${exercise.id}' has no non-target word distractor in sentence '${sentence.id}'; punctuation alone is not believable",
    ));
  }
  return errors;
}

/// Sentence records, authored order: audio reference resolution, kind and
/// spoken-text agreement, then token integrity and exact ordered text
/// coverage permitting whitespace gaps only.
List<CourseContentDiagnostic> _findSentenceErrors(CourseCurriculum curriculum) {
  final errors = <CourseContentDiagnostic>[];
  for (final sentence in curriculum.sentences) {
    final reference = curriculum.audioReferenceById(sentence.audioRefId);
    if (reference == null) {
      errors.add(_diagnostic(
        'missingReference',
        sentence.id,
        "sentence '${sentence.id}' references absent or duplicated audio ID '${sentence.audioRefId}'",
      ));
    } else {
      if (reference.kind != AudioReferenceKind.sentence) {
        errors.add(_diagnostic(
          'invalidAudioKind',
          sentence.id,
          "sentence '${sentence.id}' references ${reference.kind.name}-kind audio '${reference.id}' instead of sentence",
        ));
      }
      if (reference.spokenText != sentence.text) {
        errors.add(_diagnostic(
          'audioTextMismatch',
          sentence.id,
          "sentence '${sentence.id}' text '${sentence.text}' disagrees with spokenText '${reference.spokenText}' of audio '${reference.id}'",
        ));
      }
    }
    if (sentence.tokens.isEmpty) {
      errors.add(_diagnostic(
        'invalidSentenceTokens',
        sentence.id,
        "sentence '${sentence.id}' declares no tokens",
      ));
      continue;
    }
    final tokenIds = [for (final token in sentence.tokens) token.id];
    for (final id in _repeatedInOrder(tokenIds)) {
      errors.add(_diagnostic(
        'invalidSentenceTokens',
        sentence.id,
        "sentence '${sentence.id}' repeats token ID '$id'",
      ));
    }
    for (final token in sentence.tokens) {
      if (_repeatedInOrder(token.phonemes).isNotEmpty) {
        errors.add(_diagnostic(
          'invalidSentenceTokens',
          sentence.id,
          "sentence '${sentence.id}' token '${token.id}' repeats phoneme labels within its annotations",
        ));
      }
      if (token.phonemes.any((label) => label.trim().isEmpty)) {
        errors.add(_diagnostic(
          'invalidSentenceTokens',
          sentence.id,
          "sentence '${sentence.id}' token '${token.id}' declares a blank phoneme label; blank labels are not contextual annotations",
        ));
      }
    }
    if (!_tokensCoverText(sentence)) {
      errors.add(_diagnostic(
        'invalidSentenceTokens',
        sentence.id,
        "sentence '${sentence.id}' tokens do not exactly cover its text in order with whitespace-only gaps",
      ));
    }
  }
  return errors;
}

/// Exact ordered token coverage: the authored token texts, concatenated in
/// order with whitespace-only gaps, must reproduce the sentence text
/// exactly. Token text is matched verbatim — never trimmed or normalized —
/// so a token may itself carry whitespace, while gaps must be whitespace.
bool _tokensCoverText(CourseSentence sentence) =>
    _coverSentenceText(sentence.text, sentence.tokens, 0, 0);

bool _coverSentenceText(
  String text,
  List<SentenceToken> tokens,
  int position,
  int index,
) {
  if (position == tokens.length) {
    return _remainderIsWhitespaceOnly(text, index);
  }
  final word = tokens[position].text;
  if (word.isEmpty) return false;
  var start = index;
  while (true) {
    if (text.startsWith(word, start) &&
        _coverSentenceText(text, tokens, position + 1, start + word.length)) {
      return true;
    }
    // Uncovered text before the next token may only be whitespace.
    if (start == text.length || !_whitespaceGapPattern.hasMatch(text[start])) {
      return false;
    }
    start++;
  }
}

bool _remainderIsWhitespaceOnly(String text, int index) {
  for (var i = index; i < text.length; i++) {
    if (!_whitespaceGapPattern.hasMatch(text[i])) return false;
  }
  return true;
}

/// Coverage rules, authored coverage order: unique sound labels, empty
/// authored or populated planned coverage, and references limited to
/// distinct practice exercises that actually teach the sound.
List<CourseContentDiagnostic> _findCoverageErrors(CourseCurriculum curriculum) {
  final errors = <CourseContentDiagnostic>[];
  final sounds = [
    for (final coverage in curriculum.phonemeCoverage) coverage.sound
  ];
  for (final sound in _repeatedInOrder(sounds)) {
    errors.add(_diagnostic(
      'invalidCoverage',
      sound,
      "sound '$sound' is declared in the coverage more than once",
    ));
  }
  for (final coverage in curriculum.phonemeCoverage) {
    if (coverage.discoveryStatus == ContentStatus.authored &&
        coverage.practiceExerciseIds.isEmpty) {
      errors.add(_diagnostic(
        'invalidCoverage',
        coverage.sound,
        "authored coverage for sound '${coverage.sound}' references no practice exercises",
      ));
    }
    if (coverage.discoveryStatus == ContentStatus.planned &&
        coverage.practiceExerciseIds.isNotEmpty) {
      errors.add(_diagnostic(
        'invalidCoverage',
        coverage.sound,
        "planned coverage for sound '${coverage.sound}' lists practice exercises",
      ));
    }
    for (final id in _repeatedInOrder(coverage.practiceExerciseIds)) {
      errors.add(_diagnostic(
        'invalidCoverage',
        coverage.sound,
        "coverage for sound '${coverage.sound}' references exercise '$id' more than once",
      ));
    }
    for (final id in _distinctInOrder(coverage.practiceExerciseIds)) {
      final exercise = curriculum.exerciseById(id);
      if (exercise == null) {
        errors.add(_diagnostic(
          'invalidCoverage',
          coverage.sound,
          "coverage for sound '${coverage.sound}' references absent or duplicated exercise '$id'",
        ));
      } else if (exercise.purpose != ContentPurpose.practice) {
        errors.add(_diagnostic(
          'invalidCoverage',
          coverage.sound,
          "coverage for sound '${coverage.sound}' references ${exercise.purpose.name} exercise '$id' instead of practice",
        ));
      } else if (!_exerciseTeaches(exercise, coverage.sound)) {
        errors.add(_diagnostic(
          'invalidCoverage',
          coverage.sound,
          "coverage for sound '${coverage.sound}' references exercise '$id' whose teaching target is not '${coverage.sound}'",
        ));
      }
    }
  }
  return errors;
}

/// Whether an exercise teaches [sound]: the explicit teaching target equals
/// the sound. Incidental phonemes in the practiced word never establish
/// coverage, and spelling is never inferred.
bool _exerciseTeaches(CourseExercise exercise, String sound) {
  if (exercise is ListeningChoiceExercise) {
    return exercise.expectedSound == sound;
  }
  if (exercise is SpellingChoiceExercise) {
    return exercise.targetSound == sound;
  }
  if (exercise is SentenceHuntExercise) {
    return exercise.targetSound == sound;
  }
  if (exercise is ReadAloudExercise) {
    return exercise.targetSounds.contains(sound);
  }
  return false;
}

/// Planned nodes are readiness blockers, never structural failures: a
/// planned assess node blocks assessment use, any other planned slot blocks
/// practice use.
List<CourseContentDiagnostic> _findNodeReadinessIssues(
  CourseCurriculum curriculum,
) {
  final issues = <CourseContentDiagnostic>[];
  for (final node in curriculum.nodes) {
    if (node.status != ContentStatus.planned) continue;
    final use = node.kind == CourseNodeKind.assessment
        ? ContentPurpose.assessment
        : ContentPurpose.practice;
    issues.add(_readinessDiagnostic(
      'plannedNode',
      node.id,
      "node '${node.id}' is still a planned payload slot",
      use,
    ));
  }
  return issues;
}

/// Planned discovery coverage blocks practice readiness for that sound.
List<CourseContentDiagnostic> _findCoverageReadinessIssues(
  CourseCurriculum curriculum,
) {
  final issues = <CourseContentDiagnostic>[];
  for (final coverage in curriculum.phonemeCoverage) {
    if (coverage.discoveryStatus != ContentStatus.planned) continue;
    issues.add(_readinessDiagnostic(
      'plannedPhoneme',
      coverage.sound,
      "sound '${coverage.sound}' discovery content is still planned",
      ContentPurpose.practice,
    ));
  }
  return issues;
}

/// Exercise-level readiness, authored order: pending review keeps the
/// exercise's purpose; assessed content requires reviewed exercise (and,
/// for hunts, reviewed sentence); a declared practice resource must exist;
/// read-aloud never carries a validated speaking evaluator in FR-01.
List<CourseContentDiagnostic> _findExerciseReadinessIssues(
  CourseCurriculum curriculum,
  Map<String, AudioResourceStatus> audioResources,
) {
  final issues = <CourseContentDiagnostic>[];
  for (final exercise in curriculum.exercises) {
    final sentence = exercise is SentenceHuntExercise
        ? curriculum.sentenceById(exercise.sentenceId)
        : null;
    if (exercise.reviewState == ContentReviewState.pending ||
        (sentence != null &&
            sentence.reviewState == ContentReviewState.pending)) {
      issues.add(_readinessDiagnostic(
        'pendingContentReview',
        exercise.id,
        sentence != null
            ? "exercise '${exercise.id}' or its sentence '${sentence.id}' is pending content review"
            : "exercise '${exercise.id}' is pending content review",
        exercise.purpose,
      ));
    }
    if (exercise.purpose == ContentPurpose.assessment &&
        (exercise.reviewState != ContentReviewState.reviewed ||
            (sentence != null &&
                sentence.reviewState != ContentReviewState.reviewed))) {
      issues.add(_readinessDiagnostic(
        'unreviewedAssessmentContent',
        exercise.id,
        sentence != null
            ? "assessed exercise '${exercise.id}' and/or sentence '${sentence.id}' lacks a reviewed answer key"
            : "assessed exercise '${exercise.id}' lacks a reviewed answer key",
        ContentPurpose.assessment,
      ));
    }
    if (exercise.purpose == ContentPurpose.practice) {
      final status = audioResources[exercise.audioRefId];
      if (status == null || status == AudioResourceStatus.missing) {
        issues.add(_readinessDiagnostic(
          'missingPracticeAudio',
          exercise.id,
          "practice exercise '${exercise.id}' has no declared usable audio resource for '${exercise.audioRefId}'",
          ContentPurpose.practice,
        ));
      }
    }
    if (exercise is ReadAloudExercise) {
      issues.add(_readinessDiagnostic(
        'speakingUnassessed',
        exercise.id,
        "read-aloud exercise '${exercise.id}' has no validated speaking evaluator in FR-01",
        ContentPurpose.assessment,
      ));
    }
  }
  return issues;
}

/// Audio-reference readiness, authored reference order. Every declared word
/// reference needs a reviewed recording for assessed use; sentence and
/// paragraph resources need one only when assessment references them.
/// Unknown map keys never manufacture or repair a reference.
List<CourseContentDiagnostic> _findReferenceReadinessIssues(
  CourseCurriculum curriculum,
  Map<String, AudioResourceStatus> audioResources,
) {
  final issues = <CourseContentDiagnostic>[];
  final assessedReferenceIds = _assessedReferenceIds(curriculum);
  for (final reference in curriculum.audioReferences) {
    final status = audioResources[reference.id];
    final needsReviewedRecording = reference.kind == AudioReferenceKind.word ||
        assessedReferenceIds.contains(reference.id);
    if (needsReviewedRecording &&
        status != AudioResourceStatus.reviewedRecording) {
      issues.add(_readinessDiagnostic(
        'missingReviewedAudio',
        reference.id,
        "audio reference '${reference.id}' has no declared reviewed recording",
        ContentPurpose.assessment,
      ));
    }
  }
  return issues;
}

/// References reachable from assessed exercises, directly or through the
/// assessments' reviewed sentences.
Set<String> _assessedReferenceIds(CourseCurriculum curriculum) {
  final ids = <String>{};
  for (final exercise in curriculum.exercises) {
    if (exercise.purpose != ContentPurpose.assessment) continue;
    ids.add(exercise.audioRefId);
    if (exercise is SentenceHuntExercise) {
      final sentence = curriculum.sentenceById(exercise.sentenceId);
      if (sentence != null) {
        ids.add(sentence.audioRefId);
      }
    }
  }
  return ids;
}
