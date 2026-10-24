import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/french_uy_demo_spelling_content.dart';
import 'package:linguist/src/core/course/spelling_learning_providers.dart';
import 'package:linguist/src/core/course/spelling_learning_state.dart';
import 'package:linguist/src/core/services/audio_service.dart';
import 'package:linguist/src/features/course_map/course_map_providers.dart';
import 'package:linguist/src/features/course_map/course_map_state.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';

import '../support/course_learning_fixtures.dart';
import '../support/course_learning_widget_store.dart';

CourseLearningState _completionState(LearningScope scope, bool completed) =>
    CourseLearningState(
      scope: scope,
      revision: completed ? 1 : 0,
      commitOrdinal: completed ? 1 : 0,
      history: const [],
      activities: const {},
      mistakes: const {},
      summaries: const {},
      completions: completed
          ? [
              LearningCompletion(
                lessonId: 'en-fr-u-y',
                contentRevision: LearningRegistry.french()
                    .require('lesson:en-fr-u-y')
                    .contentRevision,
                policyKind: CompletionPolicyKind.discoveryThreshold,
                policyRevision: 1,
                thresholdPercent: 80,
                committedAt: DateTime.utc(2026),
              ),
            ]
          : const [],
      bestScores: const {},
      pending: const [],
    );

SpellingLearningState _emptySpellingState(LearningOwner owner) =>
    SpellingLearningState.empty(
      SpellingProfileScope(courseId: 'en-fr', owner: owner),
    );

List<Override> _spellingProviderOverrides() => <Override>[
  spellingCatalogueProvider.overrideWithValue(
    loadFrenchUyDemoSpellingCatalogue(),
  ),
  spellingLearningStateProvider.overrideWith((ref) async {
    final LearningOwner owner = ref.watch(learningAuthScopeProvider).owner;
    return _emptySpellingState(owner);
  }),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guest_A_B_A_discards_late_results', () async {
    final tracker = LearningAuthTracker(owner: guestScope.owner, ready: true);
    final stores = <int, CourseLearningWidgetStore>{};
    final pending = <int, Completer<CourseLearningState>>{};
    final container = ProviderContainer(
      overrides: [
        ..._spellingProviderOverrides(),
        learningAuthScopeProvider.overrideWith((ref) => tracker),
        courseLearningStoreProvider.overrideWith((ref) {
          final auth = ref.watch(learningAuthScopeProvider);
          return stores.putIfAbsent(auth.generation, () {
            final scope = LearningScope(courseId: 'en-fr', owner: auth.owner);
            final store = CourseLearningWidgetStore(
              scope: scope,
              initialState: CourseLearningState.empty(scope),
            );
            final gate = pending.putIfAbsent(auth.generation, Completer.new);
            store.loadHandler = (_) => gate.future;
            return store;
          });
        }),
        comparisonLearningStateProvider.overrideWith((ref) async {
          final owner = ref.watch(learningAuthScopeProvider).owner;
          return ComparisonLearningState.empty(
            ComparisonProfileScope(courseId: 'en-fr', owner: owner),
          );
        }),
        sentenceHuntLearningStateProvider.overrideWith((ref) async {
          final owner = ref.watch(learningAuthScopeProvider).owner;
          return SentenceHuntLearningState.empty(
            SentenceHuntProfileScope(courseId: 'en-fr', owner: owner),
          );
        }),
        sentenceHuntCatalogueProvider.overrideWith(
          (ref) => Completer<Never>().future,
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      courseMapStateProvider(frenchUySystemId),
      (_, __) {},
    );
    addTearDown(subscription.close);
    container.read(courseMapStateProvider(frenchUySystemId));
    await Future<void>.delayed(Duration.zero);

    Future<void> switchTo(LearningOwner owner) async {
      tracker.observe(owner: owner, ready: true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final changing = container.read(courseMapStateProvider(frenchUySystemId));
      expect(
        changing.bodies
            .singleWhere((body) => body.definition.id == 'discovery')
            .progress,
        MapProgress.unknown,
      );

      expect(changing.currentBodyId, isNull);
      expect(changing.completedLegacyLessonIds, isNull);
    }

    await switchTo(LearningOwner.account('account/a'));
    await switchTo(LearningOwner.account('account/b'));
    await switchTo(LearningOwner.account('account/a'));
    expect(stores.keys, containsAll([0, 1, 2, 3]));

    final aScope = LearningScope(
      courseId: 'en-fr',
      owner: LearningOwner.account('account/a'),
    );
    pending[3]!.complete(_completionState(aScope, false));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(
      container
          .read(courseMapStateProvider(frenchUySystemId))
          .bodies
          .singleWhere((body) => body.definition.id == 'discovery')
          .progress,
      MapProgress.notStarted,
    );

    pending[1]!.complete(_completionState(aScope, true));
    pending[2]!.complete(
      _completionState(
        LearningScope(
          courseId: 'en-fr',
          owner: LearningOwner.account('account/b'),
        ),
        true,
      ),
    );
    pending[0]!.complete(_completionState(guestScope, true));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final state = container.read(courseMapStateProvider(frenchUySystemId));
    expect(
      state.bodies
          .singleWhere((body) => body.definition.id == 'discovery')
          .progress,
      MapProgress.notStarted,
    );
    expect(state.currentBodyId, 'discovery');
    expect(state.completedLegacyLessonIds, isEmpty);
  });

  test('projection_never_writes_or_starts_audio', () async {
    final tracker = LearningAuthTracker(owner: guestScope.owner, ready: true);
    final store = CourseLearningWidgetStore(scope: guestScope);
    var audioProviderReads = 0;
    var spellingStoreAcquisitions = 0;
    var spellingAudioReads = 0;
    final container = ProviderContainer(
      overrides: [
        ..._spellingProviderOverrides(),
        learningAuthScopeProvider.overrideWith((ref) => tracker),
        courseLearningStoreProvider.overrideWith((ref) => store),
        comparisonLearningStateProvider.overrideWith(
          (ref) async => ComparisonLearningState.empty(
            ComparisonProfileScope(
              courseId: 'en-fr',
              owner: tracker.state.owner,
            ),
          ),
        ),
        sentenceHuntLearningStateProvider.overrideWith(
          (ref) async => SentenceHuntLearningState.empty(
            SentenceHuntProfileScope(
              courseId: 'en-fr',
              owner: tracker.state.owner,
            ),
          ),
        ),
        sentenceHuntCatalogueProvider.overrideWith(
          (ref) => Completer<Never>().future,
        ),
        spellingLearningStoreProvider.overrideWith((ref) {
          spellingStoreAcquisitions++;
          throw StateError('map projection must not acquire a spelling store');
        }),
        courseReferenceAudioProvider.overrideWith((ref) {
          spellingAudioReads++;
          throw StateError('map projection must not initialize spelling audio');
        }),
        audioServiceProvider.overrideWith((ref) {
          audioProviderReads++;
          throw StateError('projection must not initialize audio');
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(courseMapStateProvider(frenchUySystemId), (_, __) {});
    container.read(courseMapStateProvider(frenchUySystemId));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(store.loadCalls, 1);
    expect(store.prepareCalls, 0);
    expect(store.submitCalls, 0);
    expect(audioProviderReads, 0);
    expect(spellingStoreAcquisitions, 0);
    expect(spellingAudioReads, 0);
    final dedicated = container
        .read(courseMapStateProvider(frenchUySystemId))
        .bodies
        .singleWhere((body) => body.definition.id == 'comparison');
    expect(dedicated.definition.target?.name, 'dedicatedComparison');
    expect(dedicated.readiness, MapReadiness.alpha);
    expect(dedicated.progress, MapProgress.notStarted);
    expect(dedicated.launch, MapLaunch.start);
  });

  test('invalid_dedicated_registration_is_local_on_an_empty_profile', () async {
    final tracker = LearningAuthTracker(owner: guestScope.owner, ready: true);
    final store = CourseLearningWidgetStore(scope: guestScope);
    final registry = ComparisonCatalogueRegistry([
      ComparisonCatalogueRegistration.available(
        loadFrenchComparisonCatalogue(),
      ),
      ComparisonCatalogueRegistration.unavailable(
        activityId: uyDemoComparisonActivityId,
        cause: StateError('dedicated catalogue is invalid'),
      ),
    ]);
    final container = ProviderContainer(
      overrides: [
        ..._spellingProviderOverrides(),
        learningAuthScopeProvider.overrideWith((ref) => tracker),
        courseLearningStoreProvider.overrideWithValue(store),
        comparisonCatalogueRegistryProvider.overrideWithValue(registry),
        comparisonLearningStateProvider.overrideWith(
          (ref) async => ComparisonLearningState.empty(
            ComparisonProfileScope(
              courseId: 'en-fr',
              owner: tracker.state.owner,
            ),
          ),
        ),
        sentenceHuntLearningStateProvider.overrideWith(
          (ref) async => SentenceHuntLearningState.empty(
            SentenceHuntProfileScope(
              courseId: 'en-fr',
              owner: tracker.state.owner,
            ),
          ),
        ),
        sentenceHuntCatalogueProvider.overrideWith(
          (ref) => Completer<Never>().future,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(courseMapStateProvider(frenchUySystemId), (_, __) {});
    await container.read(comparisonLearningStateProvider.future);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(courseMapStateProvider(frenchUySystemId));
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
    expect(store.loadCalls, 1);
    expect(store.prepareCalls, 0);
    expect(store.submitCalls, 0);
  });

  test('auth_unready_does_not_read_guest_store', () {
    final tracker = LearningAuthTracker(owner: guestScope.owner, ready: false);
    var storeReads = 0;
    var spellingStateReads = 0;
    var spellingStoreReads = 0;
    final container = ProviderContainer(
      overrides: [
        spellingCatalogueProvider.overrideWithValue(
          loadFrenchUyDemoSpellingCatalogue(),
        ),
        spellingLearningStateProvider.overrideWith((ref) async {
          spellingStateReads++;
          return _emptySpellingState(guestScope.owner);
        }),
        spellingLearningStoreProvider.overrideWith((ref) {
          spellingStoreReads++;
          throw StateError('unready auth must not acquire spelling storage');
        }),
        learningAuthScopeProvider.overrideWith((ref) => tracker),
        courseLearningStoreProvider.overrideWith((ref) {
          storeReads++;
          throw StateError('unready auth must not read guest profile');
        }),
      ],
    );
    addTearDown(container.dispose);
    final state = container.read(courseMapStateProvider(frenchUySystemId));
    expect(
      state.bodies
          .singleWhere((body) => body.definition.id == 'discovery')
          .progress,
      MapProgress.unknown,
    );
    expect(state.currentBodyId, isNull);
    expect(storeReads, 0);
    expect(spellingStateReads, 0);
    expect(spellingStoreReads, 0);
  });

  test('registry_failure_is_explanatory_unavailable', () {
    final tracker = LearningAuthTracker(owner: guestScope.owner, ready: true);
    final container = ProviderContainer(
      overrides: [
        ..._spellingProviderOverrides(),
        learningAuthScopeProvider.overrideWith((ref) => tracker),
        learningRegistryProvider.overrideWith(
          (ref) => throw StateError('registry corrupt'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final state = container.read(courseMapStateProvider(frenchUySystemId));
    final discovery = state.bodies.singleWhere(
      (body) => body.definition.id == 'discovery',
    );
    expect(discovery.readiness, MapReadiness.unavailable);
    expect(discovery.explanation, contains('registry corrupt'));
    expect(state.completedLegacyLessonIds, isNull);
  });

  test('synchronous_comparison_catalogue_failure_is_local', () async {
    final tracker = LearningAuthTracker(owner: guestScope.owner, ready: true);
    final store = CourseLearningWidgetStore(scope: guestScope);
    final container = ProviderContainer(
      overrides: [
        ..._spellingProviderOverrides(),
        learningAuthScopeProvider.overrideWith((ref) => tracker),
        courseLearningStoreProvider.overrideWith((ref) => store),
        comparisonCatalogueProvider.overrideWith(
          (ref) => throw StateError('comparison content corrupt'),
        ),
        comparisonLearningStateProvider.overrideWith(
          (ref) async => ComparisonLearningState.empty(
            ComparisonProfileScope(
              courseId: 'en-fr',
              owner: tracker.state.owner,
            ),
          ),
        ),
        sentenceHuntLearningStateProvider.overrideWith(
          (ref) async => SentenceHuntLearningState.empty(
            SentenceHuntProfileScope(
              courseId: 'en-fr',
              owner: tracker.state.owner,
            ),
          ),
        ),
        sentenceHuntCatalogueProvider.overrideWith(
          (ref) => Completer<Never>().future,
        ),
      ],
    );
    addTearDown(container.dispose);
    final state = container.read(courseMapStateProvider(frenchUySystemId));
    expect(
      state.bodies
          .singleWhere((body) => body.definition.id == 'discovery')
          .readiness,
      MapReadiness.loading,
    );
    final comparison = state.bodies.singleWhere(
      (body) => body.definition.id == 'mixed-comparison',
    );
    expect(comparison.readiness, MapReadiness.unavailable);
    expect(comparison.launch, MapLaunch.open);
  });
}
