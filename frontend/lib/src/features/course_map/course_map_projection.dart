import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/course/comparison_content.dart';
import '../../core/course/comparison_learning_state.dart';
import '../../core/course/course_attempt.dart';
import '../../core/course/course_learning_registry.dart';
import '../../core/course/course_learning_checkpoint.dart';
import '../../core/course/course_learning_state.dart';
import '../../core/course/french_uy_demo_spelling_content.dart';
import '../../core/course/lesson_section_session.dart';
import '../../core/course/sentence_hunt_content.dart';
import '../../core/course/sentence_hunt_learning_state.dart';
import '../../core/course/spelling_learning_state.dart';
import '../../core/course/spelling_learning_validator.dart';
import '../course/comparison_progress_summary.dart';
import '../course/course_completion_summary.dart';
import '../course/sentence_hunt_progress_summary.dart';
import 'course_map_catalogue.dart';
import 'course_map_state.dart';

CourseMapState projectCourseMap({
  required MapSystemDefinition system,
  required LearningAuthScope auth,
  required LearningRegistry registry,
  required AsyncValue<CourseLearningState> course,
  required AsyncValue<ComparisonLearningState> comparison,
  required AsyncValue<ComparisonCatalogue> comparisonCatalogue,
  AsyncValue<ComparisonCatalogueRegistry>? comparisonCatalogueRegistry,
  required AsyncValue<SentenceHuntLearningState> sentences,
  required AsyncValue<SentenceHuntCatalogue> sentenceCatalogue,
  AsyncValue<SpellingLearningState> spelling =
      const AsyncLoading<SpellingLearningState>(),
  AsyncValue<FrenchUyDemoSpellingCatalogue> spellingCatalogue =
      const AsyncLoading<FrenchUyDemoSpellingCatalogue>(),
}) {
  final bool courseFailurePresent = course.hasError;
  final bool spellingLoading =
      spelling.isLoading ||
      spelling.isRefreshing ||
      spellingCatalogue.isLoading ||
      spellingCatalogue.isRefreshing;
  final bool spellingFailure = spelling.hasError || spellingCatalogue.hasError;
  final SpellingLearningState? spellingValue = _hasCurrentValue(spelling)
      ? spelling.value
      : null;
  final FrenchUyDemoSpellingCatalogue? spellingContent =
      _hasCurrentValue(spellingCatalogue) ? spellingCatalogue.value : null;
  final bool spellingScopeReady =
      auth.ready &&
      spellingValue != null &&
      spellingValue.scope.courseId == 'en-fr' &&
      spellingValue.scope.owner == auth.owner;
  final bool comparisonRegistryLoading =
      comparisonCatalogueRegistry != null &&
      (comparisonCatalogueRegistry.isLoading ||
          comparisonCatalogueRegistry.isRefreshing);
  final bool comparisonRegistryFailed =
      comparisonCatalogueRegistry?.hasError ?? false;
  final ComparisonCatalogueRegistry? comparisonRegistry =
      comparisonCatalogueRegistry != null &&
          _hasCurrentValue(comparisonCatalogueRegistry)
      ? comparisonCatalogueRegistry.value
      : null;
  final ComparisonLearningState? comparisonState = _hasCurrentValue(comparison)
      ? comparison.value
      : null;
  final bool comparisonScopeReady =
      auth.ready &&
      comparisonState != null &&
      comparisonState.scope.courseId == 'en-fr' &&
      comparisonState.scope.owner == auth.owner;
  final ComparisonCatalogueRegistration? dedicatedRegistration =
      comparisonRegistry?.registrationFor(uyDemoComparisonActivityId);
  final ComparisonCatalogue? dedicatedCatalogue =
      dedicatedRegistration?.catalogue;
  final bool dedicatedRegistrationInvalid =
      comparisonCatalogueRegistry != null &&
      !comparisonRegistryLoading &&
      !comparisonRegistryFailed &&
      comparisonRegistry != null &&
      (dedicatedRegistration == null ||
          dedicatedCatalogue == null ||
          dedicatedCatalogue.activityId != uyDemoComparisonActivityId);
  final bool dedicatedBindingPersisted =
      comparisonState?.slots.containsKey(uyDemoComparisonActivityId) ?? false;
  final ComparisonSlot? dedicatedSlot =
      comparisonState?.slots[uyDemoComparisonActivityId];
  final bool dedicatedSlotInvalid =
      comparisonScopeReady &&
      dedicatedSlot != null &&
      dedicatedCatalogue != null &&
      !_validComparisonSlot(dedicatedSlot, dedicatedCatalogue);
  final bool comparisonFamilyFailure =
      comparison.hasError ||
      comparisonCatalogue.hasError ||
      comparisonRegistryFailed ||
      (comparisonScopeReady &&
          dedicatedRegistrationInvalid &&
          dedicatedBindingPersisted) ||
      dedicatedSlotInvalid;
  final bool courseReady =
      auth.ready &&
      _exact(
        course,
        (s) => s.scope.courseId == 'en-fr' && s.scope.owner == auth.owner,
      );
  final CourseLearningState? courseState = courseReady ? course.value : null;
  CourseCompletionSummary? completion;
  Object? courseFailure = courseFailurePresent ? course.error : null;
  try {
    if (courseState != null) {
      completion = CourseCompletionSummary.fromState(
        state: courseState,
        registry: registry,
      );
    }
  } on Object catch (error) {
    courseFailure = error;
  }

  final List<MapBodyState> projected = [];
  bool mainUnknown =
      !courseReady || courseState == null || courseFailure != null;
  for (final body in system.bodies) {
    if (body.planned) {
      projected.add(
        MapBodyState(
          definition: body,
          readiness: MapReadiness.planned,
          progress: MapProgress.unknown,
          recommended: false,
          explanation: 'Coming soon.',
          launch: null,
        ),
      );
      continue;
    }
    if (body.target == MapTarget.discovery) {
      if (courseFailure != null) {
        projected.add(
          _unavailable(
            body,
            'Discovery progress is unavailable: $courseFailure. Retry to check saved progress.',
          ),
        );
      } else if (!courseReady || courseState == null) {
        projected.add(
          MapBodyState(
            definition: body,
            readiness: MapReadiness.loading,
            progress: MapProgress.unknown,
            recommended: false,
            explanation: 'Progress is loading or unavailable.',
            launch: null,
          ),
        );
      } else {
        final slot = courseState.activities[body.activityId];
        final bool completed = completion!.discoveryComplete;
        final bool validSlot =
            slot != null &&
            slot.kind == LearningActivityKind.discovery &&
            slot.contentRevision ==
                registry.require(body.activityId!).contentRevision &&
            slot.snapshot is DiscoveryCheckpoint &&
            _validDiscoverySession(
              (slot.snapshot as DiscoveryCheckpoint).session,
              registry.require(body.activityId!),
            );
        final bool resumable = validSlot && !completed;
        final MapProgress progress = completed
            ? MapProgress.completed
            : resumable
            ? MapProgress.resumable
            : slot == null
            ? MapProgress.notStarted
            : MapProgress.unknown;
        projected.add(
          MapBodyState(
            definition: body,
            readiness: MapReadiness.alpha,
            progress: progress,
            recommended: resumable || !completed,
            explanation: completed
                ? 'Current discovery completion saved.'
                : resumable
                ? 'Continue the saved discovery session.'
                : slot == null
                ? 'Start discovery.'
                : 'Saved session needs recovery.',
            launch: completed
                ? MapLaunch.review
                : resumable
                ? MapLaunch.resume
                : slot == null
                ? MapLaunch.start
                : null,
          ),
        );
        mainUnknown = false;
      }
    } else if (body.target == MapTarget.dedicatedSpelling) {
      if (spellingFailure) {
        projected.add(
          _spellingUnavailable(
            body,
            'Spelling progress or content is unavailable. Retry validation or open its recovery route.',
          ),
        );
      } else if (!auth.ready ||
          spellingLoading ||
          !spellingScopeReady ||
          spellingContent == null) {
        projected.add(
          MapBodyState(
            definition: body,
            readiness: MapReadiness.loading,
            progress: MapProgress.unknown,
            recommended: false,
            explanation: 'Spelling availability is loading.',
            launch: null,
          ),
        );
      } else {
        try {
          validateFrenchUyDemoSpellingCatalogue(spellingContent);
          if (body.activityId != uyDemoSpellingActivityId ||
              spellingContent.activityId != body.activityId) {
            throw const FormatException(
              'Spelling activity binding does not match its catalogue.',
            );
          }
          SpellingLearningStateValidator.validate(
            spellingValue,
            spellingContent,
          );
          final SpellingSlot? slot = spellingValue.slots[body.activityId];
          final bool completed = spellingValue.completions.any(
            (completion) =>
                completion.scope == spellingValue.scope &&
                completion.activityId == body.activityId &&
                completion.contentRevision == spellingContent.contentRevision,
          );
          final bool resumable = slot != null && !completed;
          projected.add(
            MapBodyState(
              definition: body,
              readiness: MapReadiness.alpha,
              progress: completed
                  ? MapProgress.completed
                  : resumable
                  ? MapProgress.resumable
                  : MapProgress.notStarted,
              recommended: false,
              explanation: completed
                  ? 'Current spelling completion saved.'
                  : resumable
                  ? 'Continue the saved spelling practice.'
                  : 'Start spelling practice.',
              launch: completed
                  ? MapLaunch.review
                  : resumable
                  ? MapLaunch.resume
                  : MapLaunch.start,
            ),
          );
        } on Object catch (error) {
          projected.add(
            _spellingUnavailable(
              body,
              'Spelling progress is unavailable: $error. Retry validation or open its recovery route.',
            ),
          );
        }
      }
    } else if (body.target == MapTarget.mixedComparison) {
      final bool comparisonLoaded = _hasCurrentValue(comparison);
      final bool catalogueLoaded = _hasCurrentValue(comparisonCatalogue);
      final value = comparisonLoaded ? comparison.value : null;
      final cat = catalogueLoaded ? comparisonCatalogue.value : null;
      final ok =
          auth.ready &&
          comparisonLoaded &&
          catalogueLoaded &&
          !comparisonRegistryLoading &&
          !comparisonFamilyFailure &&
          value != null &&
          cat != null &&
          value.scope.courseId == 'en-fr' &&
          value.scope.owner == auth.owner;
      if (!ok) {
        projected.add(
          _familyUnavailable(
            body,
            comparisonFamilyFailure,
            'Mixed comparison practice is unavailable; retry or open its existing recovery route.',
          ),
        );
      } else {
        final ComparisonProgressSummary summary;
        try {
          summary = ComparisonProgressSummary.fromState(
            state: value,
            catalogue: cat,
          );
        } on Object catch (error) {
          projected.add(
            _unavailable(
              body,
              'Mixed comparison progress is unavailable: $error. Retry to check saved progress.',
            ),
          );
          continue;
        }
        projected.add(
          MapBodyState(
            definition: body,
            readiness: MapReadiness.alpha,
            progress: summary.hasCurrentRevisionCompletion
                ? MapProgress.completed
                : value.slot != null
                ? MapProgress.resumable
                : MapProgress.notStarted,
            recommended: false,
            explanation: 'Optional mixed-sound comparison practice.',
            launch: summary.hasCurrentRevisionCompletion
                ? MapLaunch.review
                : MapLaunch.open,
            evidenceLabels: [
              summary.practiceLabel,
              summary.pairsLabel,
              summary.answersLabel,
              summary.afterDebriefLabel,
              summary.completionLabel,
              summary.unresolvedLabel,
            ],
          ),
        );
      }
    } else if (body.target == MapTarget.dedicatedComparison) {
      if (comparisonFamilyFailure) {
        projected.add(
          _dedicatedUnavailable(
            body,
            'Comparison-family progress is unavailable. Retry or open its recovery route.',
            retry: true,
          ),
        );
      } else if (!auth.ready ||
          !comparisonScopeReady ||
          comparisonRegistryLoading ||
          (comparisonCatalogueRegistry != null && comparisonRegistry == null)) {
        projected.add(
          MapBodyState(
            definition: body,
            readiness: MapReadiness.loading,
            progress: MapProgress.unknown,
            recommended: false,
            explanation: 'Dedicated comparison availability is loading.',
            launch: null,
          ),
        );
      } else if (comparisonCatalogueRegistry == null) {
        projected.add(
          _dedicatedUnavailable(
            body,
            'Dedicated comparison availability was not supplied.',
            retry: false,
          ),
        );
      } else if (dedicatedRegistration == null ||
          dedicatedCatalogue == null ||
          dedicatedCatalogue.activityId != uyDemoComparisonActivityId) {
        projected.add(
          _dedicatedUnavailable(
            body,
            'Dedicated /u/–/y/ comparison content is unavailable. Retry validation or open its recovery route.',
            retry: true,
          ),
        );
      } else {
        final ComparisonProgressSummary summary;
        try {
          summary = ComparisonProgressSummary.fromState(
            state: comparisonState,
            catalogue: dedicatedCatalogue,
          );
        } on Object catch (error) {
          projected.add(
            _dedicatedUnavailable(
              body,
              'Dedicated comparison progress is unavailable: $error.',
              retry: true,
            ),
          );
          continue;
        }
        final bool completed = summary.hasCurrentRevisionCompletion;
        final bool resumable = dedicatedSlot != null && !completed;
        projected.add(
          MapBodyState(
            definition: body,
            readiness: MapReadiness.alpha,
            progress: completed
                ? MapProgress.completed
                : resumable
                ? MapProgress.resumable
                : MapProgress.notStarted,
            recommended: false,
            explanation: completed
                ? 'Current /u/–/y/ comparison completion saved.'
                : resumable
                ? 'Continue the saved /u/–/y/ comparison.'
                : 'Start /u/–/y/ comparison practice.',
            launch: completed
                ? MapLaunch.review
                : resumable
                ? MapLaunch.resume
                : MapLaunch.start,
            evidenceLabels: [
              summary.practiceLabel,
              summary.pairsLabel,
              summary.answersLabel,
              summary.afterDebriefLabel,
              summary.completionLabel,
              summary.unresolvedLabel,
            ],
          ),
        );
      }
    } else if (body.target == MapTarget.sentenceSections) {
      final bool sentencesLoaded = _hasCurrentValue(sentences);
      final bool catalogueLoaded = _hasCurrentValue(sentenceCatalogue);
      final value = sentencesLoaded ? sentences.value : null;
      final cat = catalogueLoaded ? sentenceCatalogue.value : null;
      final ok =
          auth.ready &&
          sentencesLoaded &&
          catalogueLoaded &&
          value != null &&
          cat != null &&
          value.scope.courseId == 'en-fr' &&
          value.scope.owner == auth.owner;
      if (!ok) {
        projected.add(
          _familyUnavailable(
            body,
            sentences.hasError || sentenceCatalogue.hasError,
            'Sentence practice availability is unavailable; retry or open its existing recovery route.',
          ),
        );
      } else {
        final SentenceHuntProgressSummary summary;
        try {
          summary = SentenceHuntProgressSummary.fromState(
            state: value,
            catalogue: cat,
          );
        } on Object catch (error) {
          projected.add(
            _unavailable(
              body,
              'Sentence progress is unavailable: $error. Retry to check qualification.',
            ),
          );
          continue;
        }
        final qualified = summary.sections.any(
          (section) => section.status != SentenceHuntSectionStatus.unavailable,
        );
        projected.add(
          MapBodyState(
            definition: body,
            readiness: qualified
                ? MapReadiness.alpha
                : MapReadiness.qualificationBlocked,
            progress: MapProgress.unknown,
            recommended: false,
            explanation: qualified
                ? 'Choose a section; qualification is checked by the existing activity.'
                : 'Sentence sections require qualification and review; no playable section is currently available.',
            launch: MapLaunch.open,
            evidenceLabels: [summary.practiceLabel],
          ),
        );
      }
    } else {
      projected.add(
        MapBodyState(
          definition: body,
          readiness: MapReadiness.alpha,
          progress: MapProgress.unknown,
          recommended: false,
          explanation: body.description,
          launch: MapLaunch.open,
        ),
      );
    }
  }
  // Only authored main bodies participate in recommendation and completion.
  final recommendedId =
      system.mainOrder
          .map((id) => projected.where((b) => b.definition.id == id).first)
          .where(
            (b) =>
                b.readiness == MapReadiness.alpha &&
                b.progress == MapProgress.resumable,
          )
          .map((b) => b.definition.id)
          .firstOrNull ??
      system.mainOrder
          .map((id) => projected.where((b) => b.definition.id == id).first)
          .where(
            (b) =>
                b.readiness == MapReadiness.alpha &&
                b.progress != MapProgress.completed &&
                b.progress != MapProgress.unknown,
          )
          .map((b) => b.definition.id)
          .firstOrNull;
  final mainBodies = system.mainOrder
      .map((id) => projected.firstWhere((b) => b.definition.id == id))
      .toList(growable: false);
  final bool allAvailableMainComplete =
      mainBodies.isNotEmpty &&
      mainBodies.every(
        (body) =>
            body.readiness == MapReadiness.alpha &&
            body.progress == MapProgress.completed,
      );
  final discovery = projected
      .where((body) => body.definition.target == MapTarget.discovery)
      .firstOrNull;
  final continuation =
      mainBodies
          .where(
            (body) =>
                body.readiness == MapReadiness.alpha &&
                body.progress == MapProgress.resumable,
          )
          .firstOrNull ??
      mainBodies
          .where(
            (body) =>
                body.readiness == MapReadiness.alpha &&
                body.progress != MapProgress.completed &&
                body.progress != MapProgress.unknown,
          )
          .firstOrNull;
  final currentBodyId = mainUnknown
      ? null
      : discovery != null && discovery.readiness == MapReadiness.alpha
      ? discovery.definition.id
      : continuation?.definition.id ?? mainBodies.firstOrNull?.definition.id;
  final bodies = projected
      .map(
        (b) => MapBodyState(
          definition: b.definition,
          readiness: b.readiness,
          progress: b.progress,
          recommended: b.definition.id == recommendedId,
          explanation: b.explanation,
          launch: b.launch,
          evidenceLabels: b.evidenceLabels,
        ),
      )
      .toList();
  return CourseMapState(
    systemId: system.id,
    bodies: bodies,
    currentBodyId: currentBodyId,
    allAvailableMainComplete: !mainUnknown && allAvailableMainComplete,
    completedLegacyLessonIds: completion?.completedExistingLessonIds,
  );
}

bool _exact<T>(AsyncValue<T> value, bool Function(T) valid) =>
    !value.isLoading &&
    !value.isRefreshing &&
    !value.hasError &&
    value.value != null &&
    valid(value.value as T);

bool _hasCurrentValue<T>(AsyncValue<T> value) =>
    !value.isLoading &&
    !value.isRefreshing &&
    !value.hasError &&
    value.value != null;

bool _validDiscoverySession(
  LessonSectionSession session,
  LearningActivityDefinition activity,
) {
  final expectedIds = activity.items
      .map((item) => item.sessionAlias)
      .whereType<String>()
      .toList(growable: false);
  if (expectedIds.isEmpty) return false;
  try {
    LessonSectionSession.fromJson(
      session.toJson(),
      itemIds: expectedIds,
      contentRevision: activity.contentRevision,
    );
    return true;
  } on Object {
    return false;
  }
}

bool _validComparisonSlot(ComparisonSlot slot, ComparisonCatalogue catalogue) {
  if (slot.activityId != catalogue.activityId ||
      slot.checkpoint.contentRevision != catalogue.contentRevision ||
      slot.scope != slot.checkpoint.scope ||
      slot.scope != slot.latestReceipt.scope ||
      slot.activityId != slot.latestReceipt.activityId ||
      slot.cursor != slot.latestReceipt.after) {
    return false;
  }
  try {
    LessonSectionSession.fromJson(
      Map<String, dynamic>.from(slot.checkpoint.sessionJson),
      itemIds: catalogue.exercises.map((exercise) => exercise.id).toList(),
      contentRevision: catalogue.contentRevision,
    );
    return true;
  } on Object {
    return false;
  }
}

MapBodyState _familyUnavailable(
  MapBodyDefinition body,
  bool failed,
  String explanation,
) => MapBodyState(
  definition: body,
  readiness: failed ? MapReadiness.unavailable : MapReadiness.loading,
  progress: MapProgress.unknown,
  recommended: false,
  explanation: explanation,
  launch: MapLaunch.open,
);

MapBodyState _unavailable(MapBodyDefinition body, String reason) =>
    MapBodyState(
      definition: body,
      readiness: MapReadiness.unavailable,
      progress: MapProgress.unknown,
      recommended: false,
      explanation: reason,
      launch: null,
    );

MapBodyState _dedicatedUnavailable(
  MapBodyDefinition body,
  String reason, {
  required bool retry,
}) => MapBodyState(
  definition: body,
  readiness: MapReadiness.unavailable,
  progress: MapProgress.unknown,
  recommended: false,
  explanation: reason,
  launch: retry ? MapLaunch.start : null,
);

MapBodyState _spellingUnavailable(MapBodyDefinition body, String reason) =>
    MapBodyState(
      definition: body,
      readiness: MapReadiness.unavailable,
      progress: MapProgress.unknown,
      recommended: false,
      explanation: reason,
      launch: MapLaunch.start,
    );
