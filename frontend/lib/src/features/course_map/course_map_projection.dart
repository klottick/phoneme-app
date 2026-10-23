import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/course/comparison_content.dart';
import '../../core/course/comparison_learning_state.dart';
import '../../core/course/course_attempt.dart';
import '../../core/course/course_learning_registry.dart';
import '../../core/course/course_learning_checkpoint.dart';
import '../../core/course/course_learning_state.dart';
import '../../core/course/sentence_hunt_content.dart';
import '../../core/course/sentence_hunt_learning_state.dart';
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
  required AsyncValue<SentenceHuntLearningState> sentences,
  required AsyncValue<SentenceHuntCatalogue> sentenceCatalogue,
}) {
  final bool courseReady =
      auth.ready &&
      _exact(
        course,
        (s) => s.scope.courseId == 'en-fr' && s.scope.owner == auth.owner,
      );
  final CourseLearningState? courseState = courseReady ? course.value : null;
  CourseCompletionSummary? completion;
  Object? courseFailure;
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
  bool mainComplete = false;
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
        projected.add(_unavailable(body, '$courseFailure'));
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
            (slot.snapshot as DiscoveryCheckpoint).session.contentRevision ==
                registry.require(body.activityId!).contentRevision;
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
        mainComplete = completed;
      }
    } else if (body.target == MapTarget.mixedComparison) {
      final value = comparison.value;
      final cat = comparisonCatalogue.value;
      final ok =
          auth.ready &&
          !comparison.isLoading &&
          !comparison.isRefreshing &&
          !comparison.hasError &&
          value != null &&
          cat != null &&
          value.scope.courseId == 'en-fr' &&
          value.scope.owner == auth.owner;
      if (!ok) {
        projected.add(
          _unavailable(
            body,
            'Mixed comparison practice is unavailable; retry or open its existing recovery route.',
          ),
        );
      } else {
        final summary = ComparisonProgressSummary.fromState(
          state: value,
          catalogue: cat,
        );
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
            launch: MapLaunch.open,
            evidenceLabels: [summary.practiceLabel, summary.answersLabel],
          ),
        );
      }
    } else if (body.target == MapTarget.sentenceSections) {
      final value = sentences.value;
      final cat = sentenceCatalogue.value;
      final ok =
          auth.ready &&
          !sentences.isLoading &&
          !sentences.isRefreshing &&
          !sentences.hasError &&
          value != null &&
          cat != null &&
          value.scope.courseId == 'en-fr' &&
          value.scope.owner == auth.owner;
      if (!ok) {
        projected.add(
          _unavailable(
            body,
            'Sentence practice availability is unavailable; retry or open its existing recovery route.',
          ),
        );
      } else {
        final summary = SentenceHuntProgressSummary.fromState(
          state: value,
          catalogue: cat,
        );
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
    currentBodyId: mainUnknown ? null : system.mainOrder.firstOrNull,
    allAvailableMainComplete: !mainUnknown && mainComplete,
    completedLegacyLessonIds: completion?.completedExistingLessonIds,
  );
}

bool _exact<T>(AsyncValue<T> value, bool Function(T) valid) =>
    !value.isLoading &&
    !value.isRefreshing &&
    !value.hasError &&
    value.value != null &&
    valid(value.value as T);

MapBodyState _unavailable(MapBodyDefinition body, String reason) =>
    MapBodyState(
      definition: body,
      readiness: MapReadiness.unavailable,
      progress: MapProgress.unknown,
      recommended: false,
      explanation: reason,
      launch: null,
    );
