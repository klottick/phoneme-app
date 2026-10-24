import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/course/comparison_content.dart';
import '../../core/course/course_learning_providers.dart';
import '../../core/course/course_learning_registry.dart';
import '../../core/course/french_uy_demo_spelling_content.dart';
import '../../core/course/sentence_hunt_learning_providers.dart';
import '../../core/course/french_sentence_package.dart';
import '../../core/course/spelling_learning_providers.dart';
import 'course_map_catalogue.dart';
import 'course_map_projection.dart';
import 'course_map_state.dart';
import 'french_space_map.dart';

final courseMapStateProvider = Provider.family<CourseMapState, String>((
  ref,
  systemId,
) {
  final system = findSpaceSystem(systemId);
  if (system == null || system.planned) {
    return CourseMapState(
      systemId: systemId,
      bodies: const [],
      currentBodyId: null,
      allAvailableMainComplete: false,
      completedLegacyLessonIds: null,
    );
  }
  final auth = ref.watch(learningAuthScopeProvider);
  if (!auth.ready) {
    return CourseMapState(
      systemId: systemId,
      bodies: [
        for (final body in system.bodies)
          MapBodyState(
            definition: body,
            readiness: body.planned
                ? MapReadiness.planned
                : MapReadiness.loading,
            progress: MapProgress.unknown,
            recommended: false,
            explanation: body.planned
                ? 'Coming soon.'
                : 'Learning profile is unavailable until authentication is ready.',
            launch: null,
          ),
      ],
      currentBodyId: null,
      allAvailableMainComplete: false,
      completedLegacyLessonIds: null,
    );
  }
  final LearningRegistry registry;
  try {
    registry = ref.watch(learningRegistryProvider);
    validateMapSystem(system, registry: registry);
  } on Object catch (error) {
    return CourseMapState(
      systemId: systemId,
      bodies: [
        for (final body in system.bodies)
          MapBodyState(
            definition: body,
            readiness: body.planned
                ? MapReadiness.planned
                : MapReadiness.unavailable,
            progress: MapProgress.unknown,
            recommended: false,
            explanation: body.planned
                ? 'Coming soon.'
                : 'Map content is unavailable: $error',
            launch: null,
          ),
      ],
      currentBodyId: null,
      allAvailableMainComplete: false,
      completedLegacyLessonIds: null,
    );
  }
  AsyncValue<ComparisonCatalogue> readComparisonCatalogue() {
    try {
      return AsyncData(ref.watch(comparisonCatalogueProvider));
    } on Object catch (error) {
      return AsyncError(error, StackTrace.current);
    }
  }

  AsyncValue<ComparisonCatalogueRegistry> readComparisonCatalogueRegistry() {
    try {
      return AsyncData(ref.watch(comparisonCatalogueRegistryProvider));
    } on Object catch (error) {
      return AsyncError(error, StackTrace.current);
    }
  }

  AsyncValue<FrenchUyDemoSpellingCatalogue> readSpellingCatalogue() {
    try {
      return AsyncData(ref.watch(spellingCatalogueProvider));
    } on Object catch (error) {
      return AsyncError(error, StackTrace.current);
    }
  }

  final comparisonContent = readComparisonCatalogue();
  final comparisonRegistry = readComparisonCatalogueRegistry();
  return projectCourseMap(
    system: system,
    auth: auth,
    registry: registry,
    course: ref.watch(courseLearningStateProvider),
    comparison: ref.watch(comparisonLearningStateProvider),
    comparisonCatalogue: comparisonContent,
    comparisonCatalogueRegistry: comparisonRegistry,
    sentences: ref.watch(sentenceHuntLearningStateProvider),
    sentenceCatalogue: ref.watch(sentenceHuntCatalogueProvider),
    spelling: ref.watch(spellingLearningStateProvider),
    spellingCatalogue: readSpellingCatalogue(),
  );
});
