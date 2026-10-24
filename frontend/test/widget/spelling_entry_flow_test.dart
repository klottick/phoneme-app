import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/spelling_learning_command.dart';
import 'package:linguist/src/core/course/spelling_learning_providers.dart';
import 'package:linguist/src/core/course/spelling_learning_state.dart';
import 'package:linguist/src/core/course/spelling_learning_store.dart';
import 'package:linguist/src/core/course/french_uy_demo_spelling_content.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabaseHandle;
import 'package:linguist/src/core/theme/space_course_theme.dart';
import 'package:linguist/src/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/course_learning_widget_store.dart';
import '../support/map_motion_test_support.dart';
import '../support/sentence_hunt_fixtures.dart';

const _activityId = 'en-fr-u-y-spelling';
const _prompt = 'Listen, then choose how the vowel is written.';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'});
  });

  testWidgets('exact_spelling_route_opens_the_authored_prompt', (tester) async {
    final app = await _mountRouteProbe(tester);
    final router = app.router;
    addTearDown(() async {
      await app.dispose(tester);
    });

    router.go('/course-spelling/en-fr-u-y-spelling');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Listen, then choose how the vowel is written.'),
      findsOneWidget,
    );
  });

  testWidgets('non_spelling_unmatched_route_uses_go_router_default_fallback', (
    tester,
  ) async {
    final app = await _mountRouteProbe(tester);
    addTearDown(() => app.dispose(tester));

    app.router.go('/arbitrary-unmatched-route');
    await tester.pumpAndSettle();

    expect(find.text('Page Not Found'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    // GoRouter 14.8.1's MaterialApp default is a MaterialErrorScreen. This
    // distinguishes the actual fallback from the app's visually similar copy.
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget.runtimeType.toString() == 'MaterialErrorScreen',
      ),
      findsOneWidget,
    );
  });

  testWidgets('route_guards_precede_store_sqlite_audio', (tester) async {
    final app = await _mountRouteProbe(tester);
    addTearDown(() => app.dispose(tester));

    const invalidLocations = <String>[
      '/course-spelling/not-spelling',
      '/course-spelling/en-fr-u-y-spelling?review=maybe',
      '/course-spelling/en-fr-u-y-spelling?review=',
      '/course-spelling/en-fr-u-y-spelling?review=True',
      '/course-spelling/en-fr-u-y-spelling?review=true&review=false',
      '/course-spelling/en-fr-u-y-spelling?unknown=x',
      '/course-spelling/en-fr-u-y-spelling?unknown=x&unknown=y',
      '/course-spelling/en-fr-u-y-spelling?review=true&unknown=x',
      '/course-spelling/en-fr-u-y-spelling/uy-demo-spelling-01',
    ];
    for (final location in invalidLocations) {
      app.router.go(location);
      await tester.pumpAndSettle();
      expect(
        find.text('This spelling activity is unavailable.'),
        findsOneWidget,
        reason: '$location must fail closed before acquisition',
      );
      expect(find.byType(SpaceCourseTheme), findsOneWidget, reason: location);
      expect(app.counters.catalogue, 0, reason: location);
      expect(app.counters.store, 0, reason: location);
      expect(app.counters.database, 0, reason: location);
      expect(app.counters.audio, 0, reason: location);
      expect(app.counters.state, 0, reason: location);
    }
  });

  testWidgets('valid_spelling_route_query_shapes_are_accepted', (tester) async {
    final app = await _mountRouteProbe(tester);
    addTearDown(() => app.dispose(tester));

    for (final location in <String>[
      '/course-spelling/$_activityId',
      '/course-spelling/$_activityId?review=false',
      '/course-spelling/$_activityId?review=true',
    ]) {
      app.router.go(location);
      await tester.pumpAndSettle();
      expect(find.text(_prompt), findsOneWidget, reason: location);
    }
  });
}

final class _RouteCounters {
  int catalogue = 0;
  int store = 0;
  int database = 0;
  int audio = 0;
  int state = 0;
}

final class _MountedRouteProbe {
  const _MountedRouteProbe(this.container, this.router, this.counters);
  final ProviderContainer container;
  final GoRouter router;
  final _RouteCounters counters;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
  }
}

Future<_MountedRouteProbe> _mountRouteProbe(WidgetTester tester) async {
  disableMapMotion(tester);
  final counters = _RouteCounters();
  final owner = LearningOwner.guest();
  final auth = LearningAuthTracker(owner: owner, ready: true);
  final courseStore = CourseLearningWidgetStore();
  final audio = _ProbeAudio();
  final scope = SpellingProfileScope(courseId: 'en-fr', owner: owner);
  final container = ProviderContainer(
    overrides: [
      courseLearningStoreProvider.overrideWithValue(courseStore),
      courseLearningStateProvider.overrideWith(
        (ref) async => courseStore.committedState,
      ),
      comparisonLearningStateProvider.overrideWith(
        (ref) async => ComparisonLearningState.empty(
          ComparisonProfileScope(courseId: 'en-fr', owner: owner),
        ),
      ),
      sentenceHuntCatalogueProvider.overrideWith(
        (ref) async => syntheticSentenceCatalogue(),
      ),
      sentenceHuntLearningStateProvider.overrideWith(
        (ref) async => SentenceHuntState.empty(
          SentenceHuntProfileScope(courseId: 'en-fr', owner: owner),
        ),
      ),
      learningAuthScopeProvider.overrideWith((ref) => auth),
      learningDatabaseHandleProvider.overrideWith((ref) {
        counters.database++;
        return LearningDatabaseHandle(
          open: () async => throw StateError('unexpected database open'),
        );
      }),
      spellingCatalogueProvider.overrideWith((ref) {
        counters.catalogue++;
        return loadFrenchUyDemoSpellingCatalogue();
      }),
      spellingLearningStoreProvider.overrideWith((ref) {
        counters.store++;
        ref.watch(learningDatabaseHandleProvider);
        ref.watch(spellingCatalogueProvider);
        return _ProbeStore(scope);
      }),
      spellingLearningStateProvider.overrideWith((ref) async {
        counters.state++;
        return SpellingLearningState.empty(scope);
      }),
      courseAudioProvider.overrideWithValue(audio),
      courseReferenceAudioProvider.overrideWith((ref) {
        counters.audio++;
        return audio;
      }),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const LinguistApp()),
  );
  await tester.pumpAndSettle();
  final router = container.read(appRouterProvider);
  return _MountedRouteProbe(container, router, counters);
}

final class _ProbeStore implements SpellingLearningStore {
  const _ProbeStore(this.scope);
  @override
  final SpellingProfileScope scope;
  @override
  Future<SpellingLearningState> load() async =>
      SpellingLearningState.empty(scope);
  @override
  Future<SpellingLearningState> retryLoad() => load();
  @override
  SpellingLearningCommand prepare({
    required SpellingLearningState state,
    required SpellingAction action,
  }) => throw StateError('route probe store must not prepare');
  @override
  Future<SpellingCommit> submit(SpellingLearningCommand command) =>
      throw StateError('route probe store must not submit');
}

final class _ProbeAudio implements CourseReferenceAudio {
  @override
  Future<CourseAudioResult> playReference(
    String referenceId, {
    CourseAudioUse use = CourseAudioUse.alphaPractice,
    CourseAudioVariant variant = CourseAudioVariant.normal,
    bool allowPracticeTts = false,
  }) async => CourseAudioResult.completed(
    referenceId: referenceId,
    source: CourseAudioSource.unverifiedRecording,
  );
  @override
  Future<void> speak(String word) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
