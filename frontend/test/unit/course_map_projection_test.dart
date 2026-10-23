import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/features/course_map/course_map_projection.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';

void main() {
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

  test('refresh_does_not_retain_progress', () {
    final owner = LearningOwner.account('learner-a');
    final scope = LearningScope(courseId: 'en-fr', owner: owner);
    final previous = CourseLearningState.empty(scope);
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

  test('scope_mismatch_is_unknown', () {
    final owner = LearningOwner.account('learner-a');
    final state = projectCourseMap(
      system: frenchSpaceSystems.first,
      auth: LearningAuthScope(owner: owner, generation: 2, ready: true),
      registry: LearningRegistry.french(),
      course: AsyncData(
        CourseLearningState.empty(
          LearningScope(
            courseId: 'en-fr',
            owner: LearningOwner.account('learner-b'),
          ),
        ),
      ),
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
}
