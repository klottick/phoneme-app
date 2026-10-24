import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/french_uy_demo_spelling_content.dart';
import 'package:linguist/src/core/course/spelling_learning_command.dart';
import 'package:linguist/src/core/course/spelling_learning_state.dart';
import 'package:linguist/src/core/course/spelling_learning_transition.dart';
import 'package:linguist/src/features/course_map/course_map_projection.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';

import '../support/course_learning_widget_store.dart';

ComparisonCatalogueRegistry _comparisonRegistry({
  bool dedicatedAvailable = true,
}) => ComparisonCatalogueRegistry([
  ComparisonCatalogueRegistration.available(loadFrenchComparisonCatalogue()),
  if (dedicatedAvailable)
    ComparisonCatalogueRegistration.available(
      loadFrenchUyDemoComparisonCatalogue(),
    )
  else
    ComparisonCatalogueRegistration.unavailable(
      activityId: uyDemoComparisonActivityId,
      cause: StateError('dedicated catalogue is invalid'),
    ),
]);

ComparisonLearningState _comparisonState({
  required ComparisonCatalogueRegistry registry,
  List<String> started = const [],
  Map<String, int> completedRevisions = const {},
}) {
  final scope = ComparisonProfileScope(
    courseId: 'en-fr',
    owner: LearningOwner.guest(),
  );
  final engine = ComparisonLearningTransitionEngine(registry: registry);
  var state = ComparisonLearningState.empty(scope);
  var sequence = 0;
  for (final activityId in started) {
    final at = DateTime.utc(2026, 10, 23, 0, 0, sequence);
    final token = (++sequence).toString().padLeft(22, '0');
    final command = engine.prepare(
      state: state,
      activityId: activityId,
      action: StartComparisonRun(
        sessionId: 'map-projection-$activityId',
        policy: LessonPolicy(),
      ),
      authGeneration: 0,
      token: token,
      submittedAt: at,
    );
    state = engine
        .evaluate(state: state, command: command, committedAt: at)
        .nextState;
  }
  if (completedRevisions.isNotEmpty) {
    state = ComparisonLearningState(
      scope: scope,
      revision: state.revision,
      commitOrdinal: state.commitOrdinal,
      slots: state.slots,
      attempts: state.attempts,
      receipts: state.receipts,
      mistakes: state.mistakes,
      summaries: state.summaries,
      completions: [
        ...state.completions,
        for (final completion in completedRevisions.entries)
          ComparisonCompletion(
            scope: scope,
            activityId: completion.key,
            contentRevision: completion.value,
            policyRevision: 1,
            thresholdPercent: 80,
            committedAt: DateTime.utc(2026, 10, 23),
          ),
      ],
    );
  }
  return state;
}

CourseMapState _projectWithComparisonRegistry({
  required AsyncValue<CourseLearningState> course,
  required AsyncValue<ComparisonLearningState> comparison,
  required ComparisonCatalogueRegistry? comparisonCatalogueRegistry,
}) {
  final named = <Symbol, Object?>{
    #system: frenchSpaceSystems.first,
    #auth: LearningAuthScope(
      owner: LearningOwner.guest(),
      generation: 0,
      ready: true,
    ),
    #registry: LearningRegistry.french(),
    #course: course,
    #comparison: comparison,
    #comparisonCatalogue: AsyncData(loadFrenchComparisonCatalogue()),
    #sentences: const AsyncLoading<SentenceHuntLearningState>(),
    #sentenceCatalogue: const AsyncLoading<SentenceHuntCatalogue>(),
    if (comparisonCatalogueRegistry != null)
      #comparisonCatalogueRegistry: AsyncData(comparisonCatalogueRegistry),
  };
  try {
    return Function.apply(projectCourseMap, const [], named) as CourseMapState;
  } on NoSuchMethodError {
    // Keep the pre-interface RED behavioral: legacy projection leaves the
    // dedicated body planned rather than failing compilation on a new name.
    return projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: LearningAuthScope(
        owner: LearningOwner.guest(),
        generation: 0,
        ready: true,
      ),
      registry: LearningRegistry.french(),
      course: course,
      comparison: comparison,
      comparisonCatalogue: AsyncData(loadFrenchComparisonCatalogue()),
      sentences: const AsyncLoading(),
      sentenceCatalogue: const AsyncLoading(),
    );
  }
}

SpellingLearningState _spellingState({
  required LearningOwner owner,
  bool started = false,
  bool completed = false,
}) {
  final FrenchUyDemoSpellingCatalogue catalogue =
      loadFrenchUyDemoSpellingCatalogue();
  final SpellingProfileScope scope = SpellingProfileScope(
    courseId: 'en-fr',
    owner: owner,
  );
  final SpellingLearningTransitionEngine engine =
      SpellingLearningTransitionEngine(catalogue: catalogue);
  SpellingLearningState state = SpellingLearningState.empty(scope);
  var commandNumber = 0;

  void dispatch(SpellingAction action) {
    final DateTime now = DateTime.utc(
      2026,
      10,
      24,
    ).add(Duration(seconds: commandNumber));
    final String token = 'map${commandNumber.toString().padLeft(19, '0')}';
    final SpellingLearningCommand command = engine.prepare(
      state: state,
      action: action,
      authGeneration: 0,
      token: token,
      submittedAt: now,
    );
    commandNumber++;
    state = engine
        .evaluate(state: state, command: command, committedAt: now)
        .nextState;
  }

  if (!started && !completed) return state;
  dispatch(
    StartSpellingPractice(
      sessionId: 'map-spelling-run',
      policy: LessonPolicy(),
    ),
  );
  if (completed) {
    for (var index = 0; index < catalogue.rows.length; index++) {
      final UyDemoSpellingRow row = catalogue.rows[index];
      final SpellingSlot slot = state.slots[catalogue.activityId]!;
      final LessonSectionSession session = LessonSectionSession.fromJson(
        Map<String, dynamic>.from(slot.checkpoint.sessionJson),
        itemIds: catalogue.rows
            .map((UyDemoSpellingRow item) => item.exercise.id)
            .toList(growable: false),
        contentRevision: catalogue.contentRevision,
      );
      dispatch(
        AnswerSpellingChoice(
          itemId: row.exercise.id,
          contentRevision: catalogue.contentRevision,
          selectedOptionId: row.exercise.correctOptionId,
          expectedOptionIdSnapshot: row.exercise.correctOptionId,
          playback: SpellingPlaybackObservation(
            profile: scope,
            authGeneration: 0,
            activityId: catalogue.activityId,
            contentRevision: catalogue.contentRevision,
            runGeneration: slot.cursor.generation,
            round: session.round,
            itemId: row.exercise.id,
            referenceId: row.exercise.audioRefId,
            promptEpoch: index + 1,
            outcome: CourseAudioOutcome.completed,
            source: CourseAudioSource.unverifiedRecording,
          ),
        ),
      );
      dispatch(const AdvanceSpellingItem());
    }
    dispatch(const FinishSpellingRun(recordCompletion: true));
  }
  return state;
}

CourseMapState _projectWithSpelling({
  required LearningAuthScope auth,
  required AsyncValue<CourseLearningState> course,
  required AsyncValue<ComparisonLearningState> comparison,
  required AsyncValue<ComparisonCatalogue> comparisonCatalogue,
  ComparisonCatalogueRegistry? comparisonCatalogueRegistry,
  required AsyncValue<SpellingLearningState> spelling,
  required AsyncValue<FrenchUyDemoSpellingCatalogue> spellingCatalogue,
}) {
  final Map<Symbol, Object?> named = <Symbol, Object?>{
    #system: frenchSpaceSystems.first,
    #auth: auth,
    #registry: LearningRegistry.french(),
    #course: course,
    #comparison: comparison,
    #comparisonCatalogue: comparisonCatalogue,
    if (comparisonCatalogueRegistry != null)
      #comparisonCatalogueRegistry: AsyncData(comparisonCatalogueRegistry),
    #sentences: const AsyncLoading<SentenceHuntLearningState>(),
    #sentenceCatalogue: const AsyncLoading<SentenceHuntCatalogue>(),
    #spelling: spelling,
    #spellingCatalogue: spellingCatalogue,
  };
  try {
    return Function.apply(projectCourseMap, const <Object?>[], named)
        as CourseMapState;
  } on NoSuchMethodError {
    // Keep the pre-interface RED behavioral: the old projection leaves the
    // spelling body planned instead of failing on a new named argument.
    return projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: auth,
      registry: LearningRegistry.french(),
      course: course,
      comparison: comparison,
      comparisonCatalogue: comparisonCatalogue,
      sentences: const AsyncLoading(),
      sentenceCatalogue: const AsyncLoading(),
    );
  }
}

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
    expect(projectCourseState(previous).allAvailableMainComplete, isFalse);
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
    expect(
      state.bodies
          .singleWhere((b) => b.definition.id == 'comparison')
          .readiness,
      MapReadiness.unavailable,
    );
  });

  test(
    'dedicated_registration_failure_is_local_only_without_a_saved_binding',
    () {
      final invalidRegistry = _comparisonRegistry(dedicatedAvailable: false);
      final empty = ComparisonLearningState.empty(
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest()),
      );
      final state = _projectWithComparisonRegistry(
        course: AsyncData(
          CourseLearningState.empty(
            LearningScope(courseId: 'en-fr', owner: LearningOwner.guest()),
          ),
        ),
        comparison: AsyncData(empty),
        comparisonCatalogueRegistry: invalidRegistry,
      );
      final dedicated = state.bodies.singleWhere(
        (body) => body.definition.id == 'comparison',
      );
      final mixed = state.bodies.singleWhere(
        (body) => body.definition.id == 'mixed-comparison',
      );
      expect(dedicated.readiness, MapReadiness.unavailable);
      expect(dedicated.launch, MapLaunch.start);
      expect(mixed.readiness, MapReadiness.alpha);
      expect(mixed.launch, MapLaunch.open);
      expect(
        state.bodies
            .singleWhere((body) => body.definition.id == 'discovery')
            .progress,
        MapProgress.notStarted,
      );

      final validRegistry = _comparisonRegistry();
      final persistedBinding = _comparisonState(
        registry: validRegistry,
        started: [uyDemoComparisonActivityId],
      );
      final failClosed = _projectWithComparisonRegistry(
        course: AsyncData(
          CourseLearningState.empty(
            LearningScope(courseId: 'en-fr', owner: LearningOwner.guest()),
          ),
        ),
        comparison: AsyncData(persistedBinding),
        comparisonCatalogueRegistry: invalidRegistry,
      );
      expect(
        failClosed.bodies
            .singleWhere((body) => body.definition.id == 'comparison')
            .readiness,
        MapReadiness.unavailable,
      );
      expect(
        failClosed.bodies
            .singleWhere((body) => body.definition.id == 'mixed-comparison')
            .readiness,
        MapReadiness.unavailable,
        reason: 'an unvalidatable saved binding fails the shared family closed',
      );
      expect(
        failClosed.bodies
            .singleWhere((body) => body.definition.id == 'discovery')
            .progress,
        MapProgress.notStarted,
      );
    },
  );

  test(
    'dedicated_progress_uses_its_own_slot_and_current_revision_completion',
    () {
      final catalogueRegistry = _comparisonRegistry();
      final course = AsyncData(
        CourseLearningState.empty(
          LearningScope(courseId: 'en-fr', owner: LearningOwner.guest()),
        ),
      );

      CourseMapState project(ComparisonLearningState comparison) =>
          _projectWithComparisonRegistry(
            course: course,
            comparison: AsyncData(comparison),
            comparisonCatalogueRegistry: catalogueRegistry,
          );

      final siblingOnly = _comparisonState(
        registry: catalogueRegistry,
        started: [comparisonActivityId],
        completedRevisions: {comparisonActivityId: 1},
      );
      final siblingProjection = project(siblingOnly);
      final siblingPlanet = siblingProjection.bodies.singleWhere(
        (body) => body.definition.id == 'comparison',
      );
      expect(siblingPlanet.readiness, MapReadiness.alpha);
      expect(siblingPlanet.progress, MapProgress.notStarted);
      expect(siblingPlanet.launch, MapLaunch.start);
      expect(
        siblingPlanet.evidenceLabels,
        contains('/u/–/y/ comparison pairs attempted: 0/10'),
      );
      expect(
        siblingProjection.bodies
            .singleWhere((body) => body.definition.id == 'mixed-comparison')
            .progress,
        MapProgress.completed,
      );

      final resumable = _comparisonState(
        registry: catalogueRegistry,
        started: [uyDemoComparisonActivityId],
      );
      final resumablePlanet = project(
        resumable,
      ).bodies.singleWhere((body) => body.definition.id == 'comparison');
      expect(resumablePlanet.progress, MapProgress.resumable);
      expect(resumablePlanet.launch, MapLaunch.resume);

      final historicalCompletion = _comparisonState(
        registry: catalogueRegistry,
        started: [uyDemoComparisonActivityId],
        completedRevisions: {uyDemoComparisonActivityId: 2},
      );
      final historicalPlanet = project(
        historicalCompletion,
      ).bodies.singleWhere((body) => body.definition.id == 'comparison');
      expect(historicalPlanet.progress, MapProgress.resumable);
      expect(historicalPlanet.launch, MapLaunch.resume);

      final completed = _comparisonState(
        registry: catalogueRegistry,
        started: [uyDemoComparisonActivityId],
        completedRevisions: {uyDemoComparisonActivityId: 1},
      );
      final completedPlanet = project(
        completed,
      ).bodies.singleWhere((body) => body.definition.id == 'comparison');
      expect(completedPlanet.progress, MapProgress.completed);
      expect(completedPlanet.launch, MapLaunch.review);
    },
  );

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
    expect(
      completeMap.allAvailableMainComplete,
      isFalse,
      reason: 'discovery completion does not complete the dedicated comparison',
    );

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

  test(
    'spelling_projects_its_own_current_completion_and_authored_order',
    () async {
      final LearningOwner owner = LearningOwner.guest();
      final ComparisonCatalogueRegistry comparisonRegistry =
          _comparisonRegistry();
      final ComparisonLearningState comparisonState = _comparisonState(
        registry: comparisonRegistry,
        started: <String>[uyDemoComparisonActivityId],
        completedRevisions: <String, int>{uyDemoComparisonActivityId: 1},
      );
      final CourseLearningState discoveryState = await runDiscovery(
        finish: true,
      );
      final FrenchUyDemoSpellingCatalogue spellingCatalogue =
          loadFrenchUyDemoSpellingCatalogue();
      final SpellingLearningState completedSpelling = _spellingState(
        owner: owner,
        completed: true,
      );

      CourseMapState project(SpellingLearningState spelling) =>
          _projectWithSpelling(
            auth: LearningAuthScope(owner: owner, generation: 0, ready: true),
            course: AsyncData(discoveryState),
            comparison: AsyncData(comparisonState),
            comparisonCatalogue: AsyncData(loadFrenchComparisonCatalogue()),
            comparisonCatalogueRegistry: comparisonRegistry,
            spelling: AsyncData(spelling),
            spellingCatalogue: AsyncData(spellingCatalogue),
          );

      final CourseMapState allThree = project(completedSpelling);
      final MapBodyState spellingBody = allThree.bodies.singleWhere(
        (MapBodyState body) => body.definition.id == 'spelling',
      );
      expect(spellingBody.readiness, MapReadiness.alpha);
      expect(spellingBody.progress, MapProgress.completed);
      expect(spellingBody.launch, MapLaunch.review);
      expect(spellingBody.recommended, isFalse);
      expect(
        allThree.bodies.where((MapBodyState body) => body.recommended),
        isEmpty,
      );
      expect(allThree.allAvailableMainComplete, isTrue);

      final CourseMapState partial = project(
        _spellingState(owner: owner, started: true),
      );
      final MapBodyState recommended = partial.bodies.singleWhere(
        (MapBodyState body) => body.recommended,
      );
      expect(recommended.definition.id, 'spelling');
      expect(recommended.progress, MapProgress.resumable);
      expect(recommended.launch, MapLaunch.resume);
      expect(partial.allAvailableMainComplete, isFalse);

      final CourseMapState unavailable = _projectWithSpelling(
        auth: LearningAuthScope(owner: owner, generation: 0, ready: true),
        course: AsyncData(discoveryState),
        comparison: AsyncData(comparisonState),
        comparisonCatalogue: AsyncData(loadFrenchComparisonCatalogue()),
        comparisonCatalogueRegistry: comparisonRegistry,
        spelling: AsyncError<SpellingLearningState>(
          StateError('saved spelling state is corrupt'),
          StackTrace.current,
        ).copyWithPrevious(AsyncData(completedSpelling)),
        spellingCatalogue: AsyncData(spellingCatalogue),
      );
      final MapBodyState unavailableBody = unavailable.bodies.singleWhere(
        (MapBodyState body) => body.definition.id == 'spelling',
      );
      expect(unavailableBody.readiness, MapReadiness.unavailable);
      expect(unavailableBody.progress, MapProgress.unknown);
      expect(unavailableBody.recommended, isFalse);
      expect(unavailable.allAvailableMainComplete, isFalse);

      final SpellingLearningState foreignSpelling = _spellingState(
        owner: LearningOwner.account('another-learner'),
        completed: true,
      );
      final CourseMapState foreign = _projectWithSpelling(
        auth: LearningAuthScope(owner: owner, generation: 1, ready: true),
        course: AsyncData(discoveryState),
        comparison: AsyncData(comparisonState),
        comparisonCatalogue: AsyncData(loadFrenchComparisonCatalogue()),
        comparisonCatalogueRegistry: comparisonRegistry,
        spelling: AsyncData(foreignSpelling),
        spellingCatalogue: AsyncData(spellingCatalogue),
      );
      final MapBodyState foreignBody = foreign.bodies.singleWhere(
        (MapBodyState body) => body.definition.id == 'spelling',
      );
      expect(foreignBody.progress, MapProgress.unknown);
      expect(foreignBody.recommended, isFalse);
      expect(foreign.allAvailableMainComplete, isFalse);
    },
  );

  test('spelling_refresh_does_not_retain_a_previous_completion', () async {
    final LearningOwner owner = LearningOwner.guest();
    final ComparisonCatalogueRegistry comparisonRegistry =
        _comparisonRegistry();
    final CourseLearningState discoveryState = await runDiscovery(finish: true);
    final ComparisonLearningState comparisonState = _comparisonState(
      registry: comparisonRegistry,
      started: <String>[uyDemoComparisonActivityId],
      completedRevisions: <String, int>{uyDemoComparisonActivityId: 1},
    );
    final FrenchUyDemoSpellingCatalogue spellingCatalogue =
        loadFrenchUyDemoSpellingCatalogue();
    final SpellingLearningState previousCompletion = _spellingState(
      owner: owner,
      completed: true,
    );

    final CourseMapState state = _projectWithSpelling(
      auth: LearningAuthScope(owner: owner, generation: 1, ready: true),
      course: AsyncData(discoveryState),
      comparison: AsyncData(comparisonState),
      comparisonCatalogue: AsyncData(loadFrenchComparisonCatalogue()),
      comparisonCatalogueRegistry: comparisonRegistry,
      spelling: const AsyncLoading<SpellingLearningState>().copyWithPrevious(
        AsyncData(previousCompletion),
      ),
      spellingCatalogue: AsyncData(spellingCatalogue),
    );
    final MapBodyState spelling = state.bodies.singleWhere(
      (MapBodyState body) => body.definition.id == 'spelling',
    );

    expect(spelling.readiness, MapReadiness.loading);
    expect(spelling.progress, MapProgress.unknown);
    expect(spelling.recommended, isFalse);
    expect(
      state.bodies.where((MapBodyState body) => body.recommended),
      isEmpty,
    );
    expect(state.allAvailableMainComplete, isFalse);
  });
}
