import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/features/course_map/course_map_projection.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';
import '../support/course_learning_widget_store.dart';

void main() {
  final registry = LearningRegistry.french();

  Future<CourseLearningState> runDiscovery({
    LearningOwner? owner,
    int? wrongIndex,
    int? maxItems,
    bool finish = false,
    bool reviewMistakes = false,
    bool failFinish = false,
    Future<void> Function(CourseLearningState)? onFinishHeld,
  }) async {
    final scope = LearningScope(
      courseId: 'en-fr',
      owner: owner ?? LearningOwner.guest(),
    );
    final store = CourseLearningWidgetStore(scope: scope, registry: registry);
    Future<void> apply(LearningAction action) async {
      final state = await store.load();
      await store.submit(
        store.prepare(
          state: state,
          activityId: 'lesson:en-fr-u-y',
          action: action,
        ),
      );
    }

    await apply(StartLearningRun(options: RunOptions()));
    final activity = registry.require('lesson:en-fr-u-y');
    for (var index = 0; index < activity.items.length; index++) {
      if (maxItems != null && index >= maxItems) break;
      final state = store.committedState;
      final session =
          (state.activities['lesson:en-fr-u-y']!.snapshot
                  as DiscoveryCheckpoint)
              .session;
      final item = activity.items.singleWhere(
        (item) => item.sessionAlias == session.currentItemId,
      );
      await apply(
        ChooseSound(
          selectedSound: index == wrongIndex
              ? (item.expectedChoice == 'u' ? 'y' : 'u')
              : item.expectedChoice!,
          audioSource: authoredAudioSource(item)!,
        ),
      );
      await apply(const AdvanceLesson());
    }
    if (reviewMistakes) {
      await apply(const ReviewDiscoveryMistakes());
    }
    if (finish) {
      store.failSubmit = failFinish;
      if (onFinishHeld != null) {
        final gate = Completer<void>();
        store.actionGates[FinishLearningActivity] = gate;
        final finishing = apply(const FinishLearningActivity());
        await onFinishHeld(store.committedState);
        gate.complete();
        try {
          await finishing;
        } on Object {
          if (!failFinish) rethrow;
        }
        return store.committedState;
      }
      try {
        await apply(const FinishLearningActivity());
      } on Object {
        if (!failFinish) rethrow;
      }
    }
    return store.committedState;
  }

  CourseMapState projectCourseState(CourseLearningState state) {
    final owner = state.scope.owner;
    return projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: LearningAuthScope(owner: owner, generation: 0, ready: true),
      registry: registry,
      course: AsyncData(state),
      comparison: const AsyncLoading(),
      comparisonCatalogue: const AsyncLoading(),
      sentences: const AsyncLoading(),
      sentenceCatalogue: const AsyncLoading(),
    );
  }

  test('unknown_is_not_empty', () {
    final auth = LearningAuthScope(
      owner: LearningOwner.guest(),
      generation: 0,
      ready: false,
    );
    final registry = LearningRegistry.french();
    final state = projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: auth,
      registry: registry,
      course: const AsyncLoading<CourseLearningState>(),
      comparison: const AsyncLoading<ComparisonLearningState>(),
      comparisonCatalogue: const AsyncLoading(),
      sentences: const AsyncLoading<SentenceHuntLearningState>(),
      sentenceCatalogue: const AsyncLoading(),
    );
    expect(
      state.bodies.singleWhere((b) => b.definition.id == 'discovery').progress,
      MapProgress.unknown,
    );
    expect(state.currentBodyId, isNull);
  });

  test('refresh_does_not_retain_progress', () async {
    final owner = LearningOwner.account('learner-a');
    final previous = await runDiscovery(
      owner: owner,
      wrongIndex: 8,
      finish: true,
    );
    expect(projectCourseState(previous).allAvailableMainComplete, isTrue);
    final state = projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: LearningAuthScope(owner: owner, generation: 1, ready: true),
      registry: LearningRegistry.french(),
      course: const AsyncLoading<CourseLearningState>().copyWithPrevious(
        AsyncData(previous),
      ),
      comparison: const AsyncLoading(),
      comparisonCatalogue: AsyncData(loadFrenchComparisonCatalogue()),
      sentences: const AsyncLoading(),
      sentenceCatalogue: const AsyncLoading(),
    );
    final discovery = state.bodies.singleWhere(
      (b) => b.definition.id == 'discovery',
    );
    expect(discovery.progress, MapProgress.unknown);
    expect(state.currentBodyId, isNull);
  });

  test('scope_mismatch_is_unknown', () async {
    final owner = LearningOwner.account('learner-a');
    final foreignCompleted = await runDiscovery(wrongIndex: 8, finish: true);
    final state = projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: LearningAuthScope(owner: owner, generation: 2, ready: true),
      registry: LearningRegistry.french(),
      course: AsyncData(foreignCompleted),
      comparison: const AsyncLoading(),
      comparisonCatalogue: const AsyncLoading<ComparisonCatalogue>(),
      sentences: const AsyncLoading(),
      sentenceCatalogue: const AsyncLoading(),
    );
    expect(
      state.bodies.singleWhere((b) => b.definition.id == 'discovery').progress,
      MapProgress.unknown,
    );
    expect(state.currentBodyId, isNull);
  });

  test('comparison_failure_is_local', () {
    final owner = LearningOwner.guest();
    final state = projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: LearningAuthScope(owner: owner, generation: 0, ready: true),
      registry: LearningRegistry.french(),
      course: AsyncData(
        CourseLearningState.empty(
          LearningScope(courseId: 'en-fr', owner: owner),
        ),
      ),
      comparison:
          AsyncError<ComparisonLearningState>(
            StateError('comparison unavailable'),
            StackTrace.current,
          ).copyWithPrevious(
            AsyncData(
              ComparisonLearningState.empty(
                ComparisonProfileScope(courseId: 'en-fr', owner: owner),
              ),
            ),
          ),
      comparisonCatalogue: AsyncError<ComparisonCatalogue>(
        StateError('old catalogue error'),
        StackTrace.current,
      ).copyWithPrevious(AsyncData(loadFrenchComparisonCatalogue())),
      sentences: const AsyncLoading(),
      sentenceCatalogue: const AsyncLoading(),
    );
    expect(
      state.bodies.singleWhere((b) => b.definition.id == 'discovery').progress,
      MapProgress.notStarted,
    );
    expect(
      state.bodies
          .singleWhere((b) => b.definition.id == 'mixed-comparison')
          .readiness,
      MapReadiness.unavailable,
    );
    expect(
      state.bodies
          .singleWhere((b) => b.definition.id == 'mixed-comparison')
          .evidenceLabels,
      isEmpty,
    );
  });

  test('comparison_refresh_and_foreign_scope_hide_stale_evidence', () {
    final owner = LearningOwner.guest();
    final previous = ComparisonLearningState.empty(
      ComparisonProfileScope(courseId: 'en-fr', owner: owner),
    );
    CourseMapState project({
      required AsyncValue<ComparisonLearningState> comparison,
    }) => projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: LearningAuthScope(owner: owner, generation: 1, ready: true),
      registry: LearningRegistry.french(),
      course: AsyncData(
        CourseLearningState.empty(
          LearningScope(courseId: 'en-fr', owner: owner),
        ),
      ),
      comparison: comparison,
      comparisonCatalogue: AsyncData(loadFrenchComparisonCatalogue()),
      sentences: const AsyncLoading(),
      sentenceCatalogue: const AsyncLoading(),
    );

    final refreshing = project(
      comparison: const AsyncLoading<ComparisonLearningState>()
          .copyWithPrevious(AsyncData(previous)),
    ).bodies.singleWhere((body) => body.definition.id == 'mixed-comparison');
    expect(refreshing.readiness, MapReadiness.loading);
    expect(refreshing.evidenceLabels, isEmpty);

    final foreign = project(
      comparison: AsyncData(
        ComparisonLearningState.empty(
          ComparisonProfileScope(
            courseId: 'en-fr',
            owner: LearningOwner.account('foreign-learner'),
          ),
        ),
      ),
    ).bodies.singleWhere((body) => body.definition.id == 'mixed-comparison');
    expect(foreign.readiness, MapReadiness.loading);
    expect(foreign.evidenceLabels, isEmpty);
  });

  test('comparison_body_projects_complete_committed_evidence_summary', () {
    final owner = LearningOwner.guest();
    final comparisonState = ComparisonLearningState.empty(
      ComparisonProfileScope(courseId: 'en-fr', owner: owner),
    );
    final state = projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: LearningAuthScope(owner: owner, generation: 0, ready: true),
      registry: LearningRegistry.french(),
      course: AsyncData(
        CourseLearningState.empty(
          LearningScope(courseId: 'en-fr', owner: owner),
        ),
      ),
      comparison: AsyncData(comparisonState),
      comparisonCatalogue: AsyncData(loadFrenchComparisonCatalogue()),
      sentences: const AsyncLoading(),
      sentenceCatalogue: const AsyncLoading(),
    );
    final comparison = state.bodies.singleWhere(
      (body) => body.definition.id == 'mixed-comparison',
    );

    expect(comparison.evidenceLabels, [
      'Comparison practice, not phoneme mastery',
      'Comparison pairs attempted: 0/10',
      'Comparison answers: 0/0',
      'After-debrief comparison answers: 0',
      'Comparison completion policies: 0',
      'Unresolved comparison pairs: 0',
    ]);
  });

  test('sentence_catalogue_refresh_does_not_retain_qualification', () async {
    final owner = LearningOwner.guest();
    final previousCatalogue = await FrenchSentencePackageLoader().load();
    final state = projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: LearningAuthScope(owner: owner, generation: 0, ready: true),
      registry: LearningRegistry.french(),
      course: AsyncData(
        CourseLearningState.empty(
          LearningScope(courseId: 'en-fr', owner: owner),
        ),
      ),
      comparison: const AsyncLoading(),
      comparisonCatalogue: const AsyncLoading(),
      sentences: const AsyncLoading(),
      sentenceCatalogue: const AsyncLoading<SentenceHuntCatalogue>()
          .copyWithPrevious(AsyncData(previousCatalogue)),
    );
    final station = state.bodies.singleWhere(
      (b) => b.definition.id == 'sentence-practice',
    );
    expect(station.readiness, MapReadiness.loading);
    expect(station.progress, MapProgress.unknown);
    expect(station.launch, MapLaunch.open);
  });

  test('course_failure_is_unavailable_not_loading', () async {
    final owner = LearningOwner.guest();
    final staleCompletion = await runDiscovery(wrongIndex: 8, finish: true);
    final state = projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: LearningAuthScope(owner: owner, generation: 0, ready: true),
      registry: LearningRegistry.french(),
      course: AsyncError<CourseLearningState>(
        StateError('course read failed'),
        StackTrace.current,
      ).copyWithPrevious(AsyncData(staleCompletion)),
      comparison: const AsyncLoading(),
      comparisonCatalogue: const AsyncLoading(),
      sentences: const AsyncLoading(),
      sentenceCatalogue: const AsyncLoading(),
    );
    expect(
      state.bodies.singleWhere((b) => b.definition.id == 'discovery').readiness,
      MapReadiness.unavailable,
    );
    expect(
      state.bodies
          .singleWhere((b) => b.definition.id == 'discovery')
          .explanation,
      contains('Retry'),
    );
  });

  test('resume_preserves_exercise_debrief_and_review', () async {
    final exercise = await runDiscovery(maxItems: 2);
    final debrief = await runDiscovery(finish: false);
    final review = await runDiscovery(wrongIndex: 2, reviewMistakes: true);
    expect(
      (exercise.activities['lesson:en-fr-u-y']!.snapshot as DiscoveryCheckpoint)
          .session
          .phase
          .name,
      'exercise',
    );
    expect(
      (debrief.activities['lesson:en-fr-u-y']!.snapshot as DiscoveryCheckpoint)
          .session
          .phase
          .name,
      'debrief',
    );
    expect(
      (review.activities['lesson:en-fr-u-y']!.snapshot as DiscoveryCheckpoint)
          .session
          .phase
          .name,
      'exercise',
    );
    for (final saved in [exercise, debrief, review]) {
      final before =
          (saved.activities['lesson:en-fr-u-y']!.snapshot
                  as DiscoveryCheckpoint)
              .session
              .toJson();
      final map = projectCourseState(saved);
      final body = map.bodies.singleWhere(
        (b) => b.definition.id == 'discovery',
      );
      expect(body.progress, MapProgress.resumable);
      expect(body.launch, MapLaunch.resume);
      expect(
        (saved.activities['lesson:en-fr-u-y']!.snapshot as DiscoveryCheckpoint)
            .session
            .toJson(),
        before,
      );
    }
  });

  test('only_current_discovery_threshold_completes', () async {
    var observedHeld = false;
    final held = await runDiscovery(
      wrongIndex: 8,
      failFinish: true,
      finish: true,
      onFinishHeld: (state) async {
        observedHeld = true;
        expect(state.completions, isEmpty);
        expect(projectCourseState(state).allAvailableMainComplete, isFalse);
      },
    );
    expect(observedHeld, isTrue);
    expect(held.completions, isEmpty);
    final heldMap = projectCourseState(held);
    expect(
      heldMap.bodies
          .singleWhere((b) => b.definition.id == 'discovery')
          .progress,
      MapProgress.resumable,
    );
    expect(heldMap.allAvailableMainComplete, isFalse);

    final completed = await runDiscovery(wrongIndex: 8, finish: true);
    final completeMap = projectCourseState(completed);
    expect(
      completeMap.bodies
          .singleWhere((b) => b.definition.id == 'discovery')
          .progress,
      MapProgress.completed,
    );
    expect(
      completeMap.bodies
          .singleWhere((b) => b.definition.id == 'discovery')
          .launch,
      MapLaunch.review,
    );
    expect(completeMap.currentBodyId, 'discovery');
    expect(completeMap.allAvailableMainComplete, isTrue);

    final completion = completed.completions.single;
    final historical = CourseLearningState(
      scope: completed.scope,
      revision: completed.revision,
      commitOrdinal: completed.commitOrdinal,
      history: completed.history,
      activities: completed.activities,
      mistakes: completed.mistakes,
      summaries: completed.summaries,
      completions: [
        LearningCompletion(
          lessonId: completion.lessonId,
          contentRevision: completion.contentRevision + 1,
          policyKind: completion.policyKind,
          policyRevision: completion.policyRevision,
          thresholdPercent: completion.thresholdPercent,
          committedAt: completion.committedAt,
        ),
      ],
      bestScores: completed.bestScores,
      pending: completed.pending,
    );
    final historicalMap = projectCourseState(historical);
    expect(historicalMap.allAvailableMainComplete, isFalse);
    expect(
      historicalMap.bodies
          .singleWhere((body) => body.definition.id == 'discovery')
          .progress,
      MapProgress.resumable,
    );
    final legacy = CourseLearningState(
      scope: completed.scope,
      revision: completed.revision,
      commitOrdinal: completed.commitOrdinal,
      history: completed.history,
      activities: completed.activities,
      mistakes: completed.mistakes,
      summaries: completed.summaries,
      completions: [
        LearningCompletion(
          lessonId: completion.lessonId,
          contentRevision: completion.contentRevision,
          policyKind: CompletionPolicyKind.legacyOnePass,
          policyRevision: completion.policyRevision,
          thresholdPercent: null,
          committedAt: completion.committedAt,
        ),
      ],
      bestScores: completed.bestScores,
      pending: completed.pending,
    );
    final legacyMap = projectCourseState(legacy);
    expect(legacyMap.allAvailableMainComplete, isFalse);
    expect(
      legacyMap.bodies
          .singleWhere((body) => body.definition.id == 'discovery')
          .progress,
      MapProgress.resumable,
    );
  });

  test('sentence_qualification_dominates_progress', () async {
    final owner = LearningOwner.guest();
    final catalogue = await FrenchSentencePackageLoader().load();
    expect(
      catalogue.sections.every((section) => !catalogue.isAvailable(section.id)),
      isTrue,
    );
    final state = projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: LearningAuthScope(owner: owner, generation: 0, ready: true),
      registry: registry,
      course: AsyncData(
        CourseLearningState.empty(
          LearningScope(courseId: 'en-fr', owner: owner),
        ),
      ),
      comparison: const AsyncLoading(),
      comparisonCatalogue: const AsyncLoading(),
      sentences: AsyncData(
        SentenceHuntLearningState.empty(
          SentenceHuntProfileScope(courseId: 'en-fr', owner: owner),
        ),
      ),
      sentenceCatalogue: AsyncData(catalogue),
    );
    final station = state.bodies.singleWhere(
      (body) => body.definition.id == 'sentence-practice',
    );
    expect(station.readiness, MapReadiness.qualificationBlocked);
    expect(
      station.launch,
      MapLaunch.open,
      reason: 'the section selector is reachable, but no exercise is exposed',
    );
    expect(station.progress, MapProgress.unknown);
  });

  test('recommendation_uses_authored_order_not_orbit', () {
    final owner = LearningOwner.guest();
    final state = projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: LearningAuthScope(owner: owner, generation: 0, ready: true),
      registry: registry,
      course: AsyncData(
        CourseLearningState.empty(
          LearningScope(courseId: 'en-fr', owner: owner),
        ),
      ),
      comparison: const AsyncLoading(),
      comparisonCatalogue: const AsyncLoading(),
      sentences: const AsyncLoading(),
      sentenceCatalogue: const AsyncLoading(),
    );
    expect(
      state.bodies
          .singleWhere((body) => body.definition.id == 'discovery')
          .recommended,
      isTrue,
    );
    expect(
      state.bodies
          .where((body) => body.definition.id != 'discovery')
          .where((body) => body.recommended),
      isEmpty,
    );
    expect(state.currentBodyId, 'discovery');
  });
}
