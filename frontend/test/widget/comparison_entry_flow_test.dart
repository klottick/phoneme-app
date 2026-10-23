import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/comparison_learning_store.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_skill_summary.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabaseHandle;
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/features/course/comparison_lesson_screen.dart';
import 'package:linguist/src/features/course_map/course_map_screen.dart';
import 'package:linguist/src/features/course/comparison_progress_summary.dart';
import 'package:linguist/src/features/course/course_progress_screen.dart';
import 'package:linguist/src/features/course/course_lesson_screen.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/features/audio/audio_compare_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/course_learning_widget_store.dart';
import '../support/map_motion_test_support.dart';
import '../support/sentence_hunt_fixtures.dart';
import '../support/sqlite_learning_test_harness.dart';

void main() {
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'}),
  );

  testWidgets('comparison_retry_contains_catalogue_factory_failure', (
    tester,
  ) async {
    disableMapMotion(tester);
    final tempDir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('comparison-error-'),
    ))!;
    var databaseOpenCalls = 0;
    final trackedHandle = LearningDatabaseHandle(
      open: () async {
        databaseOpenCalls++;
        return openFileLearningTestDatabase(
          File('${tempDir.path}/learning.sqlite'),
        );
      },
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await trackedHandle.close();
      await tempDir.delete(recursive: true);
    });
    final v2State = _nonemptyV2State();
    final v2Store = CourseLearningWidgetStore(initialState: v2State);
    final tracker = LearningAuthTracker(
      owner: LearningOwner.guest(),
      ready: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(v2Store),
          courseLearningStateProvider.overrideWith((ref) async => v2State),
          learningAuthScopeProvider.overrideWith((ref) => tracker),
          learningDatabaseHandleProvider.overrideWithValue(trackedHandle),
          comparisonCatalogueProvider.overrideWith(
            (ref) => throw const ComparisonUnavailableException(
              FormatException('invalid comparison catalogue'),
            ),
          ),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CourseMapScreen), findsOneWidget);
    await _inspectMixedComparison(tester);
    expect(find.textContaining('Destination unavailable'), findsOneWidget);
    expect(
      find.textContaining('Discovery lessons:'),
      findsNothing,
      reason: 'foreign discovery state remains unknown, not a fabricated zero',
    );

    await tester.tap(find.byTooltip('Progress'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Retry comparison progress'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Retry comparison progress'));
    await tester.pump();
    expect(find.text('Retry comparison progress'), findsOneWidget);
    expect(
      find.text('Retry comparison progress').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
    expect(find.text('Retry loading progress'), findsNothing);
    expect(databaseOpenCalls, 0);
    await tester.tap(find.text('Retry comparison progress'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Retry comparison progress'), findsOneWidget);
    expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
    expect(databaseOpenCalls, 0);
    expect(v2Store.committedState, same(v2State));
    expect(v2Store.prepareCalls, 0);
    expect(v2Store.submitCalls, 0);

    final router = GoRouter.of(
      tester.element(find.text('Retry comparison progress')),
    );
    router.go('/home');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open discovery recovery'));
    await tester.tap(find.text('Open discovery recovery'));
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryLessonScreen), findsOneWidget);
    expect(databaseOpenCalls, 0);
  });

  testWidgets(
    'reopened_comparison_has_no_restored_hearing_and_stale_snapshot_reloads',
    (tester) async {
      disableMapMotion(tester);
      final tempDir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('comparison-reopen-'),
      ))!;
      courseBackend = null;
      final file = File('${tempDir.path}/phoneme_learning.sqlite');
      final catalogue = loadFrenchComparisonCatalogue();
      final scope = ComparisonProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.guest(),
      );
      final seedTracker = LearningAuthTracker(owner: scope.owner, ready: true);
      final seedHandle = LearningDatabaseHandle(
        open: () => openFileLearningTestDatabase(file),
      );
      final seedContainer = ProviderContainer(
        overrides: [
          learningAuthScopeProvider.overrideWith((ref) => seedTracker),
          learningDatabaseHandleProvider.overrideWithValue(seedHandle),
          comparisonCatalogueProvider.overrideWithValue(catalogue),
        ],
      );
      final seedStore = seedContainer.read(comparisonLearningStoreProvider);
      final empty = await seedStore.load();
      await seedStore.submit(
        seedStore.prepare(
          state: empty,
          activityId: comparisonActivityId,
          action: StartComparisonRun(
            sessionId: 'reopened-comparison-run',
            policy: LessonPolicy(),
          ),
        ),
      );
      seedContainer.dispose();
      await seedHandle.close();

      final tracker = LearningAuthTracker(owner: scope.owner, ready: true);
      final handle = LearningDatabaseHandle(
        open: () => openFileLearningTestDatabase(file),
      );
      final audio = _EntryReferenceAudio();
      final container = ProviderContainer(
        overrides: [
          learningAuthScopeProvider.overrideWith((ref) => tracker),
          learningDatabaseHandleProvider.overrideWithValue(handle),
          courseLearningStoreProvider.overrideWithValue(
            CourseLearningWidgetStore(),
          ),
          sentenceHuntLearningStateProvider.overrideWith(
            (ref) async => SentenceHuntLearningState.empty(
              SentenceHuntProfileScope(
                courseId: 'en-fr',
                owner: LearningOwner.guest(),
              ),
            ),
          ),
          sentenceHuntCatalogueProvider.overrideWith(
            (ref) async => syntheticSentenceCatalogue(),
          ),
          comparisonCatalogueProvider.overrideWithValue(catalogue),
          courseReferenceAudioProvider.overrideWithValue(audio),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await handle.close();
        await tempDir.delete(recursive: true);
        courseBackend = null;
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LinguistApp(),
        ),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(CourseMapScreen)));
      router.go('/course-comparison/$comparisonActivityId');
      await tester.pumpAndSettle();
      expect(find.text('Listen to sample A'), findsOneWidget);
      expect(
        audio.requests,
        isEmpty,
        reason:
            'a saved checkpoint must not restore playback or hearing grants',
      );
      final sameButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Same'),
      );
      expect(
        sameButton.onPressed,
        isNull,
        reason: 'both comparison samples require fresh hearing',
      );
      expect(find.textContaining('Microphone'), findsNothing);
      expect(find.textContaining('timer'), findsNothing);

      var peerToken = 0;
      final peer = SqliteComparisonLearningRepository(
        database: handle,
        scope: scope,
        authGeneration: tracker.current.generation,
        currentAuth: () => tracker.current,
        backendOwner: () => LearningOwner.guest(),
        transitions: ComparisonLearningTransitionEngine(catalogue: catalogue),
        clock: () => DateTime.utc(2026, 10, 19),
        newToken: () => (++peerToken).toString().padLeft(22, '0'),
      );
      final peerState = await peer.load();
      final peerCommit = await peer.submit(
        peer.prepare(
          state: peerState,
          activityId: comparisonActivityId,
          action: StartComparisonRun(
            sessionId: 'concurrent-winner',
            policy: LessonPolicy(),
          ),
        ),
      );
      expect(peerCommit.state.revision, 2);

      await tester.tap(find.text('Listen to sample A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to sample B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Same'));
      await tester.pumpAndSettle();
      expect(
        find.text('Saved comparison progress changed. Reload to continue.'),
        findsOneWidget,
      );
      expect(find.text('Reload saved progress'), findsOneWidget);

      await tester.tap(find.text('Reload saved progress'));
      await tester.pumpAndSettle();
      expect(
        find.text('Saved comparison progress changed. Reload to continue.'),
        findsNothing,
      );
      final reloaded = await peer.load();
      expect(reloaded.revision, peerCommit.state.revision);
      expect(
        reloaded.attempts,
        isEmpty,
        reason: 'the stale answer is a conflict, not credited progress',
      );
      final sameButtonAfterReload = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Same'),
      );
      expect(
        sameButtonAfterReload.onPressed,
        isNull,
        reason: 'reloading the current checkpoint requires fresh hearing',
      );
    },
  );

  test('comparison_summary_counts_only_current_committed_evidence', () {
    final d = _Driver();
    final empty = ComparisonProgressSummary.fromState(
      state: d.state,
      catalogue: d.catalogue,
    );
    expect(empty.completedRuns, 0);
    expect(empty.hasCurrentRevisionCompletion, isFalse);
    d.start(); // an active draft/checkpoint is not committed completion.
    final draft = ComparisonProgressSummary.fromState(
      state: d.state,
      catalogue: d.catalogue,
    );
    expect(draft.completedRuns, 0);
    expect(draft.hasCurrentRevisionCompletion, isFalse);
    d.answer(true);
    final base = d.state;
    ComparisonCompletion completion(
      int threshold,
      int revision,
      String activity,
    ) => ComparisonCompletion(
      scope: d.scope,
      activityId: activity,
      contentRevision: revision,
      policyRevision: 1,
      thresholdPercent: threshold,
      committedAt: DateTime.utc(2026),
    );
    final state = ComparisonLearningState(
      scope: d.scope,
      revision: base.revision,
      commitOrdinal: base.commitOrdinal,
      slot: base.slot,
      attempts: const [],
      receipts: base.receipts,
      mistakes: {
        ...base.mistakes,
        ComparisonPairMistakeKey(
          scope: d.scope,
          activityId: comparisonActivityId,
          pairId: 'fr07b-pair-04',
          contentRevision: 1,
        ): ComparisonPairMistake(
          scope: d.scope,
          key: ComparisonPairMistakeKey(
            scope: d.scope,
            activityId: comparisonActivityId,
            pairId: 'fr07b-pair-04',
            contentRevision: 1,
          ),
          firstWrongAt: DateTime.utc(2026),
          latestWrongAt: DateTime.utc(2026, 1, 2),
          failureCount: 2,
        ),
        ComparisonPairMistakeKey(
          scope: d.scope,
          activityId: comparisonActivityId,
          pairId: 'fr07b-pair-05',
          contentRevision: 2,
        ): ComparisonPairMistake(
          scope: d.scope,
          key: ComparisonPairMistakeKey(
            scope: d.scope,
            activityId: comparisonActivityId,
            pairId: 'fr07b-pair-05',
            contentRevision: 2,
          ),
          firstWrongAt: DateTime.utc(2026),
          latestWrongAt: DateTime.utc(2026),
          failureCount: 1,
        ),
      },
      summaries: {
        ...base.summaries,
        ComparisonSummaryKey(
          scope: d.scope,
          activityId: comparisonActivityId,
          pairId: 'fr07b-pair-02',
          contentRevision: 1,
        ): ComparisonPairSummary(
          key: ComparisonSummaryKey(
            scope: d.scope,
            activityId: comparisonActivityId,
            pairId: 'fr07b-pair-02',
            contentRevision: 1,
          ),
          firstInRun: ComparisonCount(correct: 2, total: 3),
          repeatInRun: ComparisonCount(correct: 1, total: 2),
          afterDebrief: ComparisonCount(correct: 1, total: 2),
        ),
      },
      completions: [
        completion(80, 1, comparisonActivityId),
        completion(70, 1, comparisonActivityId),
        completion(80, 2, comparisonActivityId),
        completion(80, 1, 'future-activity'),
      ],
    );
    final summary = ComparisonProgressSummary.fromState(
      state: state,
      catalogue: d.catalogue,
    );
    expect(
      summary.uniqueAttemptedPairs,
      2,
    ); // summary survives bounded attempt pruning
    expect(summary.correctAnswers, 4);
    expect(summary.totalAnswers, 6);
    expect(summary.afterDebriefAnswers, 2); // overlapping, not added twice
    expect(summary.completedRuns, 2);
    expect(summary.hasCurrentRevisionCompletion, isTrue);
    expect(summary.unresolvedPairCount, 1);
    expect(summary.unresolvedMistakes.single.key.pairId, 'fr07b-pair-04');
    expect(summary.practiceLabel, 'Comparison practice, not phoneme mastery');
    expect(summary.pairsLabel, 'Comparison pairs attempted: 2/10');
    expect(summary.answersLabel, 'Comparison answers: 4/6');
    expect(summary.afterDebriefLabel, 'After-debrief comparison answers: 2');
    expect(summary.completionLabel, 'Comparison completion policies: 2');
    expect(summary.unresolvedLabel, 'Unresolved comparison pairs: 1');
    expect(() => summary.unresolvedMistakes.clear(), throwsUnsupportedError);
    expect(
      () => ComparisonLearningState(
        scope: d.scope,
        revision: base.revision,
        commitOrdinal: base.commitOrdinal,
        slot: base.slot,
        attempts: const [],
        receipts: base.receipts,
        mistakes: base.mistakes,
        summaries: base.summaries,
        completions: [
          completion(80, 1, comparisonActivityId),
          completion(80, 1, comparisonActivityId),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => ComparisonCompletion(
        scope: d.scope,
        activityId: comparisonActivityId,
        contentRevision: 1,
        policyRevision: 2,
        thresholdPercent: 80,
        committedAt: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
  });

  testWidgets('comparison_entry_is_additive_and_unknown_is_local', (
    tester,
  ) async {
    disableMapMotion(tester);
    final fixture = await _repositoryFixture(tester);
    final homeLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = homeLoadAck;
    await tester.pumpWidget(
      ProviderScope(
        overrides: _repositoryOverrides(fixture),
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => homeLoadAck.future);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CourseMapScreen), findsOneWidget);
    await _inspectMixedComparison(tester);
    expect(find.text('Open destination'), findsOneWidget);
    final screenLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = screenLoadAck;
    final startAck = await _runRealAsync(tester, () async => Completer<void>());
    fixture.store.nextSubmitAck = startAck;
    GoRouter.of(tester.element(find.byType(CourseMapScreen))).go(
      '/course-comparison/en-fr-phoneme-comparison?review=false&pairId=fr07b-pair-01',
    );
    for (var i = 0; i < 20 && fixture.store.loadCalls < 2; i++) {
      await tester.pump();
    }
    expect(fixture.store.loadCalls, 2);
    await tester.runAsync(() => screenLoadAck.future);
    await tester.pump();
    for (
      var i = 0;
      i < 20 &&
          fixture.store.commands
              .where((c) => c.action is StartComparisonRun)
              .isEmpty;
      i++
    ) {
      await tester.pump();
    }
    expect(
      fixture.store.commands.where((c) => c.action is StartComparisonRun),
      hasLength(1),
    );
    await tester.runAsync(() => startAck.future);
    await tester.pump();
    await _runRealAsync(tester, fixture.store.snapshot);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    final router = GoRouter.of(
      tester.element(find.byType(ComparisonLessonScreen)),
    );
    final commandsBeforeInvalidRoutes = fixture.store.commands.length;
    for (final uri in [
      '/course-comparison/not-a-comparison',
      '/course-comparison/en-fr-phoneme-comparison?review=maybe',
      '/course-comparison/en-fr-phoneme-comparison?review=',
      '/course-comparison/en-fr-phoneme-comparison?review=1',
      '/course-comparison/en-fr-phoneme-comparison?other=x',
      '/course-comparison/en-fr-phoneme-comparison?review=true&review=false',
      '/course-comparison/en-fr-phoneme-comparison?pairId=fr07b-pair-01&pairId=fr07b-pair-02',
      '/course-comparison/en-fr-phoneme-comparison?pairId=unknown',
      '/course-comparison/en-fr-phoneme-comparison?pairId=',
    ]) {
      router.go(uri);
      await tester.pumpAndSettle();
      expect(
        find.text('This comparison activity is unavailable.'),
        findsOneWidget,
        reason: uri,
      );
    }
    expect(fixture.store.commands.length, commandsBeforeInvalidRoutes);
  });

  testWidgets('comparison_home_entry_survives_independent_progress_error', (
    tester,
  ) async {
    disableMapMotion(tester);
    final discovery = CourseLearningWidgetStore()..failLoad = true;
    final comparisonScope = ComparisonProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(discovery),
          comparisonLearningStateProvider.overrideWith(
            (ref) async => ComparisonLearningState.empty(comparisonScope),
          ),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CourseMapScreen), findsOneWidget);
    expect(find.text('Retry loading progress'), findsOneWidget);
  });

  testWidgets('invalid_comparison_route_rejects_before_profile_store_factory', (
    tester,
  ) async {
    disableMapMotion(tester);
    var factories = 0;
    var catalogueFactories = 0;
    final scope = ComparisonProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(
            CourseLearningWidgetStore(),
          ),
          comparisonLearningStateProvider.overrideWith(
            (ref) async => ComparisonLearningState.empty(scope),
          ),
          comparisonCatalogueProvider.overrideWith((ref) {
            catalogueFactories++;
            return loadFrenchComparisonCatalogue();
          }),
          comparisonLearningStoreProvider.overrideWith((ref) {
            factories++;
            throw StateError('profile store must not be constructed');
          }),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CourseMapScreen), findsOneWidget);
    final catalogueFactoryCount = catalogueFactories;
    final router = GoRouter.of(tester.element(find.byType(CourseMapScreen)));
    for (final uri in [
      '/course-comparison/unknown',
      '/course-comparison/en-fr-phoneme-comparison?review=maybe',
      '/course-comparison/en-fr-phoneme-comparison?review=',
      '/course-comparison/en-fr-phoneme-comparison?review=1',
      '/course-comparison/en-fr-phoneme-comparison?review=True',
      '/course-comparison/en-fr-phoneme-comparison?unknown=value',
      '/course-comparison/en-fr-phoneme-comparison?review=true&review=false',
      '/course-comparison/en-fr-phoneme-comparison?pairId=x&pairId=y',
      '/course-comparison/en-fr-phoneme-comparison?pairId=unknown',
      '/course-comparison/en-fr-phoneme-comparison?pairId=',
    ]) {
      router.go(uri);
      await tester.pumpAndSettle();
      expect(
        find.text('This comparison activity is unavailable.'),
        findsOneWidget,
        reason: uri,
      );
      expect(factories, 0, reason: 'profile store not constructed for $uri');
      expect(
        catalogueFactories,
        catalogueFactoryCount,
        reason: 'invalid activity/query must not construct catalogue for $uri',
      );
    }
  });

  testWidgets(
    'invalid_activity_and_query_precede_catalogue_and_profile_access',
    (tester) async {
      disableMapMotion(tester);
      var catalogueFactories = 0;
      var profileFactories = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseLearningStoreProvider.overrideWithValue(
              CourseLearningWidgetStore(),
            ),
            comparisonLearningStateProvider.overrideWith(
              (ref) => Completer<ComparisonLearningState>().future,
            ),
            comparisonCatalogueProvider.overrideWith((ref) {
              catalogueFactories++;
              return loadFrenchComparisonCatalogue();
            }),
            comparisonLearningStoreProvider.overrideWith((ref) {
              profileFactories++;
              throw StateError('profile must not be constructed');
            }),
          ],
          child: const LinguistApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CourseMapScreen), findsOneWidget);
      final homeCatalogueFactoryCount = catalogueFactories;
      final router = GoRouter.of(tester.element(find.byType(CourseMapScreen)));
      for (final uri in [
        '/course-comparison/not-the-activity',
        '/course-comparison/en-fr-phoneme-comparison?unknown=value',
        '/course-comparison/en-fr-phoneme-comparison?review=maybe',
        '/course-comparison/en-fr-phoneme-comparison?review=true&review=false',
      ]) {
        router.go(uri);
        await tester.pumpAndSettle();
        expect(
          find.text('This comparison activity is unavailable.'),
          findsOneWidget,
          reason: uri,
        );
        expect(
          catalogueFactories,
          homeCatalogueFactoryCount,
          reason: 'invalid route must not add catalogue construction: $uri',
        );
        expect(profileFactories, 0, reason: 'profile before guard: $uri');
      }
    },
  );

  testWidgets('corrupt_comparison_catalogue_is_local_unavailable', (
    tester,
  ) async {
    disableMapMotion(tester);
    final v2State = _nonemptyV2State();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(
            CourseLearningWidgetStore(),
          ),
          courseLearningStateProvider.overrideWith((ref) async => v2State),
          comparisonLearningStateProvider.overrideWith(
            (ref) async => ComparisonLearningState.empty(
              ComparisonProfileScope(
                courseId: 'en-fr',
                owner: LearningOwner.guest(),
              ),
            ),
          ),
          comparisonCatalogueProvider.overrideWith(
            (ref) => throw ComparisonContentValidationException([]),
          ),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CourseMapScreen), findsOneWidget);
    var router = GoRouter.of(tester.element(find.byType(CourseMapScreen)));
    router.go('/course-progress');
    await tester.pumpAndSettle();
    expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
    expect(
      find.text('Existing lessons (includes discovery pilot): 0/5 complete'),
      findsOneWidget,
    );
    expect(find.text('Comparison practice, not phoneme mastery'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Unavailable'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Unavailable'), findsOneWidget);
    expect(
      find.text(
        'Supported backup is pending; local commits remain saved on this device.',
      ),
      findsOneWidget,
    );
    router = GoRouter.of(tester.element(find.byType(CourseProgressScreen)));
    router.go('/course-review');
    await tester.pumpAndSettle();
    expect(find.text('/i/ · Listening'), findsOneWidget);
    expect(find.text('Unresolved · 2 incorrect answers'), findsOneWidget);
    router = GoRouter.of(tester.element(find.byType(CourseProgressScreen)));
    router.go('/course-progress');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Unavailable'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Comparison pairs attempted: 0/10'), findsNothing);
    router = GoRouter.of(tester.element(find.byType(CourseProgressScreen)));
    router.go(
      '/course-comparison/en-fr-phoneme-comparison?pairId=fr07b-pair-01',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('This comparison activity is unavailable.'),
      findsOneWidget,
    );
  });

  testWidgets('comparison_state_error_keeps_entry_and_recovery_action', (
    tester,
  ) async {
    disableMapMotion(tester);
    final fixture = await _repositoryFixture(tester);
    final discoveryStore = CourseLearningWidgetStore();
    fixture.persistence.failNextRead = true;
    final initialLoad = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = initialLoad;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(discoveryStore),
          learningAuthScopeProvider.overrideWith(
            (ref) =>
                LearningAuthTracker(owner: fixture.scope.owner, ready: true),
          ),
          comparisonCatalogueProvider.overrideWithValue(fixture.catalogue),
          comparisonLearningStoreProvider.overrideWithValue(fixture.store),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => initialLoad.future);
    await tester.pumpAndSettle();
    expect(find.byType(CourseMapScreen), findsOneWidget);
    await _inspectMixedComparison(tester);
    expect(find.textContaining('Destination unavailable'), findsOneWidget);
    await tester.ensureVisible(find.text('Open mixed comparison recovery'));
    final retryAck = await _runRealAsync(tester, () async => Completer<void>());
    fixture.store.nextLoadAck = retryAck;
    final recoveryStartAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextSubmitAck = recoveryStartAck;
    await tester.tap(find.text('Open mixed comparison recovery'));
    await tester.pump();
    await tester.runAsync(() => retryAck.future);
    await tester.pump();
    for (
      var i = 0;
      i < 20 &&
          fixture.store.commands
              .where((c) => c.action is StartComparisonRun)
              .isEmpty;
      i++
    ) {
      await tester.pump();
    }
    expect(
      fixture.store.commands.where((c) => c.action is StartComparisonRun),
      hasLength(1),
    );
    await tester.runAsync(() => recoveryStartAck.future);
    await tester.pump();
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    expect(find.text('Listen to sample A'), findsOneWidget);
    expect(discoveryStore.loadCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('v2_failure_does_not_hide_comparison_entry_or_count', (
    tester,
  ) async {
    disableMapMotion(tester);
    final scope = ComparisonProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(
            CourseLearningWidgetStore()..failLoad = true,
          ),
          comparisonLearningStateProvider.overrideWith(
            (ref) async => ComparisonLearningState.empty(scope),
          ),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CourseMapScreen), findsOneWidget);
    await _inspectMixedComparison(tester);
    expect(find.text('Open destination'), findsOneWidget);
    expect(find.text('Retry loading progress'), findsOneWidget);
  });

  testWidgets('home_offers_review_only_for_committed_current_completion', (
    tester,
  ) async {
    disableMapMotion(tester);
    final driver = _Driver()..start();
    driver.answer(true);
    final state = driver.state;
    final committed = ComparisonLearningState(
      scope: state.scope,
      revision: state.revision,
      commitOrdinal: state.commitOrdinal,
      slot: state.slot,
      attempts: state.attempts,
      receipts: state.receipts,
      mistakes: state.mistakes,
      summaries: state.summaries,
      completions: [
        ComparisonCompletion(
          scope: state.scope,
          activityId: comparisonActivityId,
          contentRevision: 1,
          policyRevision: 1,
          thresholdPercent: 80,
          committedAt: DateTime.utc(2026),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(
            CourseLearningWidgetStore(),
          ),
          comparisonLearningStateProvider.overrideWith(
            (ref) async => committed,
          ),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _inspectMixedComparison(tester);
    expect(find.text('Review comparison'), findsOneWidget);
    expect(find.text('Open comparison practice'), findsOneWidget);
    expect(find.text('Practise again'), findsNothing);
  });

  testWidgets('home_continue_resumes_active_draft_without_mutation', (
    tester,
  ) async {
    disableMapMotion(tester);
    final fixture = await _repositoryFixture(tester);
    final seeded = await _seedActiveDraft(tester, fixture.store);
    final before = await _runRealAsync(tester, fixture.store.snapshot);
    expect(before.checkpoint!.sessionJson, seeded.checkpoint!.sessionJson);
    expect(before.completions, isEmpty);
    final commandsBefore = fixture.store.commands.length;
    final homeLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = homeLoadAck;
    await tester.pumpWidget(
      ProviderScope(
        overrides: _repositoryOverrides(fixture),
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => homeLoadAck.future);
    await tester.pump();
    await tester.pump();
    await _inspectMixedComparison(tester);
    expect(find.text('Open destination'), findsOneWidget);
    final homeLoadCalls = fixture.store.loadCalls;
    final screenLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = screenLoadAck;
    await tester.ensureVisible(find.text('Open destination'));
    final continueButton = find.widgetWithText(
      FilledButton,
      'Open destination',
    );
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
    await tester.tap(continueButton);
    await tester.pump();
    await _waitForLoadCall(tester, fixture.store, homeLoadCalls + 1);
    await tester.runAsync(() => screenLoadAck.future);
    await tester.pump();
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    expect(
      GoRouterState.of(
        tester.element(find.byType(ComparisonLessonScreen)),
      ).uri.toString(),
      '/course-comparison/en-fr-phoneme-comparison',
    );
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    final after = await _runRealAsync(tester, fixture.store.snapshot);
    expect(after.checkpoint!.sessionJson, before.checkpoint!.sessionJson);
    expect(after.completions, isEmpty);
    expect(fixture.store.commands.length, commandsBefore);
  });

  testWidgets('home_review_and_practice_doorway_preserve_completed_debrief', (
    tester,
  ) async {
    disableMapMotion(tester);
    final fixture = await _repositoryFixture(tester);
    final completed = await _seedCompletedRun(
      tester,
      fixture.store,
      fixture.catalogue,
    );
    expect(completed.completions, hasLength(1));
    final completedJson = completed.checkpoint!.sessionJson;
    final commandsBefore = fixture.store.commands.length;
    final homeLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = homeLoadAck;
    await tester.pumpWidget(
      ProviderScope(
        overrides: _repositoryOverrides(fixture),
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => homeLoadAck.future);
    await tester.pump();
    await tester.pump();
    await _inspectMixedComparison(tester);
    expect(find.text('Review comparison'), findsOneWidget);
    expect(find.text('Open comparison practice'), findsOneWidget);
    expect(find.text('Practise again'), findsNothing);
    late GoRouter router;

    var loadAck = await _runRealAsync(tester, () async => Completer<void>());
    fixture.store.nextLoadAck = loadAck;
    final reviewLoadCalls = fixture.store.loadCalls;
    await tester.ensureVisible(find.text('Review comparison'));
    await tester.tap(find.widgetWithText(FilledButton, 'Review comparison'));
    await tester.pump();
    await _waitForLoadCall(tester, fixture.store, reviewLoadCalls + 1);
    await tester.runAsync(() => loadAck.future);
    await tester.pump();
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    router = GoRouter.of(tester.element(find.byType(ComparisonLessonScreen)));
    expect(
      GoRouterState.of(
        tester.element(find.byType(ComparisonLessonScreen)),
      ).uri.toString(),
      '/course-comparison/en-fr-phoneme-comparison?review=true',
    );
    expect(find.text('Comparison debrief'), findsOneWidget);
    var after = await _runRealAsync(tester, fixture.store.snapshot);
    expect(after.checkpoint!.sessionJson, completedJson);
    expect(after.completions, hasLength(1));
    expect(
      after.completions.single.policyRevision,
      completed.completions.single.policyRevision,
    );
    expect(
      after.completions.single.thresholdPercent,
      completed.completions.single.thresholdPercent,
    );
    expect(
      fixture.store.commands.length,
      commandsBefore,
      reason: 'Review entry must not automatically start another run',
    );

    router.pop();
    await tester.pumpAndSettle();
    loadAck = await _runRealAsync(tester, () async => Completer<void>());
    fixture.store.nextLoadAck = loadAck;
    final practiceDoorwayLoadCalls = fixture.store.loadCalls;
    await tester.ensureVisible(find.text('Open comparison practice'));
    await tester.tap(find.text('Open comparison practice'));
    await tester.pump();
    await _waitForLoadCall(tester, fixture.store, practiceDoorwayLoadCalls + 1);
    await tester.runAsync(() => loadAck.future);
    await tester.pump();
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    router = GoRouter.of(tester.element(find.byType(ComparisonLessonScreen)));
    expect(
      GoRouterState.of(
        tester.element(find.byType(ComparisonLessonScreen)),
      ).uri.toString(),
      '/course-comparison/en-fr-phoneme-comparison',
    );
    expect(find.text('Comparison debrief'), findsOneWidget);
    after = await _runRealAsync(tester, fixture.store.snapshot);
    expect(after.checkpoint!.sessionJson, completedJson);
    expect(after.completions, hasLength(1));
    expect(
      after.completions.single.policyRevision,
      completed.completions.single.policyRevision,
    );
    expect(
      after.completions.single.thresholdPercent,
      completed.completions.single.thresholdPercent,
    );
    expect(
      fixture.store.commands.length,
      commandsBefore,
      reason: 'the map doorway must preserve the saved debrief without a write',
    );
    final screenPractiseAgain = find.descendant(
      of: find.byType(ComparisonLessonScreen),
      matching: find.text('Practise again'),
    );
    expect(screenPractiseAgain, findsOneWidget);

    final restartAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextSubmitAck = restartAck;
    await tester.ensureVisible(screenPractiseAgain);
    await tester.tap(screenPractiseAgain);
    await tester.pump();
    await _waitForCommandCount(tester, fixture.store, commandsBefore + 1);
    expect(fixture.store.commands.last.action, isA<StartComparisonRun>());
    await tester.runAsync(() => restartAck.future);
    await tester.pump();

    final restarted = await _runRealAsync(tester, fixture.store.snapshot);
    final restartedSession = LessonSectionSession.fromJson(
      Map<String, dynamic>.from(restarted.checkpoint!.sessionJson),
      itemIds: fixture.catalogue.exercises
          .map((exercise) => exercise.id)
          .toList(),
      contentRevision: fixture.catalogue.contentRevision,
    );
    expect(restartedSession.phase, LessonSectionPhase.exercise);
    expect(restarted.completions, hasLength(1));
    expect(fixture.store.commands.length, commandsBefore + 1);
  });

  testWidgets('comparison_and_discovery_load_failures_are_independent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
    );
    final courseScope = LearningScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    final courseState = CourseLearningState.empty(courseScope);
    final driver = _Driver()..start();
    driver.answer(true);
    final comparisonState = driver.state;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(
            CourseLearningWidgetStore(),
          ),
          courseLearningStateProvider.overrideWith(
            (ref) async => throw StateError('v2 unavailable'),
          ),
          comparisonLearningStateProvider.overrideWith(
            (ref) async => comparisonState,
          ),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Course progress'), findsOneWidget);
    expect(find.text('Retry loading progress'), findsOneWidget);
    const labels = [
      'Comparison practice, not phoneme mastery',
      'Comparison pairs attempted: 1/10',
      'Comparison answers: 1/1',
      'After-debrief comparison answers: 0',
      'Comparison completion policies: 0',
      'Unresolved comparison pairs: 0',
    ];
    for (final scale in [2.0, 3.0]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpAndSettle();
      for (final label in labels) {
        await tester.ensureVisible(find.text(label));
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'scale $scale: $label',
        );
        expect(tester.takeException(), isNull, reason: 'scale $scale');
      }
    }
    expect(courseState.commitOrdinal, 0);
  });

  testWidgets('home_primary_legacy_and_audio_compare_keep_real_destinations', (
    tester,
  ) async {
    disableMapMotion(tester);
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(
            CourseLearningWidgetStore(),
          ),
          comparisonLearningStateProvider.overrideWith(
            (ref) async => ComparisonLearningState.empty(
              ComparisonProfileScope(
                courseId: 'en-fr',
                owner: LearningOwner.guest(),
              ),
            ),
          ),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(CourseMapScreen)));
    await openMapDiscoveryAction(tester, action: 'Start lesson');
    expect(find.byType(DiscoveryLessonScreen), findsOneWidget);

    const legacy = <(String, String)>[
      ('Keep French vowels steady', 'en-fr-vowels'),
      ('Let vowels resonate', 'en-fr-nasal'),
      ('Meet the French R', 'en-fr-r'),
      ('Mix your new sounds', 'en-fr-mix'),
    ];
    for (final (title, id) in legacy) {
      router.pop();
      await tester.pumpAndSettle();
      final legacyDisclosure = find.text('Legacy practice');
      if (find.text(title).evaluate().isEmpty) {
        await tester.ensureVisible(legacyDisclosure);
        await tester.tap(legacyDisclosure);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byType(CourseLessonScreen), findsOneWidget, reason: title);
      expect(
        tester
            .widget<CourseLessonScreen>(find.byType(CourseLessonScreen))
            .lessonId,
        id,
      );
    }

    router.pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Practice tools'));
    await tester.tap(find.text('Practice tools'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Audio Compare'));
    await tester.tap(find.text('Audio Compare'));
    await tester.pumpAndSettle();
    expect(find.byType(AudioCompareScreen), findsOneWidget);
  });

  testWidgets('comparison_pair_review_preserves_finite_queue_context', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await _repositoryFixture(tester);
    final audio = _EntryReferenceAudio();
    final seeded = await _seedDebrief(
      tester,
      fixture.store,
      fixture.catalogue,
      wrongIndexes: {0, 3},
    );
    final seededSession = LessonSectionSession.fromJson(
      Map<String, dynamic>.from(seeded.checkpoint!.sessionJson),
      itemIds: fixture.catalogue.exercises.map((e) => e.id).toList(),
      contentRevision: 1,
    );
    expect(seededSession.unresolvedItemIds, ['fr07b-pair-01', 'fr07b-pair-04']);
    final initialCommands = fixture.store.commands.length;
    final loadAck = await _runRealAsync(tester, () async => Completer<void>());
    fixture.store.nextLoadAck = loadAck;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._repositoryOverrides(fixture),
          courseReferenceAudioProvider.overrideWithValue(audio),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => loadAck.future);
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(CourseMapScreen)));
    router.go('/course-progress');
    await tester.pumpAndSettle();
    final mistake = find.text('Comparison pair fr07b-pair-04');
    await tester.ensureVisible(mistake);
    expect(mistake, findsOneWidget);
    final screenLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = screenLoadAck;
    await tester.tap(mistake);
    await tester.pump();
    await tester.runAsync(() => screenLoadAck.future);
    await tester.pumpAndSettle();
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    expect(find.text('Requested pair: fr07b-pair-04'), findsOneWidget);
    expect(find.text('Comparison debrief'), findsOneWidget);
    final unchanged = await _runRealAsync(tester, fixture.store.snapshot);
    expect(unchanged.checkpoint!.sessionJson, seeded.checkpoint!.sessionJson);
    expect(
      fixture.store.commands.length,
      initialCommands,
      reason: 'opening pair context must not start or mutate a run',
    );

    final reviewAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextSubmitAck = reviewAck;
    await tester.ensureVisible(find.text('Review unresolved pairs'));
    await tester.tap(find.text('Review unresolved pairs'));
    await tester.pump();
    await tester.runAsync(() => reviewAck.future);
    await tester.pumpAndSettle();
    final active = await _runRealAsync(tester, fixture.store.snapshot);
    final session = LessonSectionSession.fromJson(
      Map<String, dynamic>.from(active.checkpoint!.sessionJson),
      itemIds: fixture.catalogue.exercises.map((e) => e.id).toList(),
      contentRevision: 1,
    );
    expect(session.queue, ['fr07b-pair-01', 'fr07b-pair-04']);
    expect(session.position, 0);
    expect(session.currentItemId, 'fr07b-pair-01');
    expect(fixture.store.commands.length, initialCommands + 1);

    final unchangedActiveJson = active.checkpoint!.sessionJson;
    final resumeAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = resumeAck;
    router.go(
      '/course-comparison/en-fr-phoneme-comparison?pairId=fr07b-pair-04&review=true',
    );
    await tester.pump();
    await tester.runAsync(() => resumeAck.future);
    await tester.pumpAndSettle();
    final resumed = await _runRealAsync(tester, fixture.store.snapshot);
    expect(
      resumed.checkpoint!.sessionJson,
      unchangedActiveJson,
      reason: 'deep link must resume, not reorder or advance active checkpoint',
    );
    expect(find.text('Listen to sample A'), findsOneWidget);
    expect(fixture.store.commands.length, initialCommands + 1);

    for (var queueIndex = 0; queueIndex < 2; queueIndex++) {
      final pairId = ['fr07b-pair-01', 'fr07b-pair-04'][queueIndex];
      final exercise = fixture.catalogue.exercise(pairId);
      await tester.tap(find.text('Listen to sample A'));
      await tester.pump();
      expect(audio.requests.last, exercise.sampleA.referenceId);
      await tester.tap(find.text('Listen to sample B'));
      await tester.pump();
      expect(audio.requests.last, exercise.sampleB.referenceId);
      expect(find.text('Same'), findsOneWidget);
      expect(find.text('Different'), findsOneWidget);
      final answerAck = await _runRealAsync(
        tester,
        () async => Completer<void>(),
      );
      fixture.store.nextSubmitAck = answerAck;
      await tester.tap(
        find.text(
          exercise.expectedRelation == PhonemeRelation.same
              ? 'Same'
              : 'Different',
        ),
      );
      await tester.pump();
      await tester.runAsync(() => answerAck.future);
      await tester.pump();
      final current = await _runRealAsync(tester, fixture.store.snapshot);
      final currentSession = LessonSectionSession.fromJson(
        Map<String, dynamic>.from(current.checkpoint!.sessionJson),
        itemIds: fixture.catalogue.exercises.map((e) => e.id).toList(),
        contentRevision: 1,
      );
      expect(currentSession.currentItemId, pairId);
      final advanceAck = await _runRealAsync(
        tester,
        () async => Completer<void>(),
      );
      fixture.store.nextSubmitAck = advanceAck;
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.runAsync(() => advanceAck.future);
      await tester.pump();
      final advanced = await _runRealAsync(tester, fixture.store.snapshot);
      final advancedSession = LessonSectionSession.fromJson(
        Map<String, dynamic>.from(advanced.checkpoint!.sessionJson),
        itemIds: fixture.catalogue.exercises.map((e) => e.id).toList(),
        contentRevision: 1,
      );
      if (queueIndex == 0) {
        expect(advancedSession.currentItemId, 'fr07b-pair-04');
        expect(advancedSession.queue, ['fr07b-pair-01', 'fr07b-pair-04']);
      } else {
        expect(advancedSession.phase, LessonSectionPhase.debrief);
      }
    }
    final afterQueue = await _runRealAsync(tester, fixture.store.snapshot);
    final completedSession = LessonSectionSession.fromJson(
      Map<String, dynamic>.from(afterQueue.checkpoint!.sessionJson),
      itemIds: fixture.catalogue.exercises.map((e) => e.id).toList(),
      contentRevision: 1,
    );
    expect(completedSession.phase, LessonSectionPhase.debrief);
    expect(completedSession.queue, ['fr07b-pair-01', 'fr07b-pair-04']);
    expect(
      fixture.store.commands.where((c) => c.action is AnswerComparisonPair),
      hasLength(12),
    );
    expect(
      fixture.store.commands.where((c) => c.action is AdvanceComparisonPair),
      hasLength(12),
    );
  });

  testWidgets('comparison_finish_ack_retry_and_duplicate_receipt_are_durable', (
    tester,
  ) async {
    disableMapMotion(tester);
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await _repositoryFixture(tester);
    const sentinel = 'v2-owned-sentinel-9c8d';
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('course.learning.v2.sentinel', sentinel);
    final v2State = _nonemptyV2State();
    final v2Store = CourseLearningWidgetStore(initialState: v2State);
    final audio = _EntryReferenceAudio();
    final homeLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = homeLoadAck;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._progressRepositoryOverrides(fixture, v2Store, v2State),
          courseReferenceAudioProvider.overrideWithValue(audio),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => homeLoadAck.future);
    await tester.pump();
    await tester.pump();
    final router = GoRouter.of(tester.element(find.byType(CourseMapScreen)));
    var popCount = 0;
    var previousDepth =
        router.routerDelegate.currentConfiguration.matches.length;
    void recordPop() {
      final depth = router.routerDelegate.currentConfiguration.matches.length;
      if (depth < previousDepth) popCount += previousDepth - depth;
      previousDepth = depth;
    }

    router.routerDelegate.addListener(recordPop);
    addTearDown(() => router.routerDelegate.removeListener(recordPop));

    final screenLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    final startAck = await _runRealAsync(tester, () async => Completer<void>());
    fixture.store.nextLoadAck = screenLoadAck;
    fixture.store.nextSubmitAck = startAck;
    await _inspectMixedComparison(tester);
    await tester.ensureVisible(find.text('Open destination'));
    await tester.tap(find.widgetWithText(FilledButton, 'Open destination'));
    await tester.pump();
    await _waitForLoadCall(tester, fixture.store, 2);
    await tester.runAsync(() => screenLoadAck.future);
    await tester.pump();
    await _waitForCommandCount(tester, fixture.store, 1);
    expect(fixture.store.commands.single.action, isA<StartComparisonRun>());
    await tester.runAsync(() => startAck.future);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);

    final v2ObjectBefore = v2Store.committedState;
    final v2PrepareBefore = v2Store.prepareCalls;
    final v2SubmitBefore = v2Store.submitCalls;
    for (var index = 0; index < fixture.catalogue.exercises.length; index++) {
      final exercise = fixture.catalogue.exercises[index];
      await tester.tap(find.text('Listen to sample A'));
      await tester.pump();
      expect(audio.requests.last, exercise.sampleA.referenceId);
      await tester.tap(find.text('Listen to sample B'));
      await tester.pump();
      expect(audio.requests.last, exercise.sampleB.referenceId);
      final answerAck = await _runRealAsync(
        tester,
        () async => Completer<void>(),
      );
      final continueAck = await _runRealAsync(
        tester,
        () async => Completer<void>(),
      );
      fixture.store.nextSubmitAck = answerAck;
      await tester.tap(
        find.text(
          exercise.expectedRelation == PhonemeRelation.same
              ? 'Same'
              : 'Different',
        ),
      );
      await tester.pump();
      await tester.runAsync(() => answerAck.future);
      await tester.pump();
      fixture.store.nextSubmitAck = continueAck;
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.runAsync(() => continueAck.future);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Comparison debrief'), findsOneWidget);
    expect(find.text('Finish comparison'), findsOneWidget);
    final terminal = await _runRealAsync(tester, fixture.store.snapshot);
    expect(terminal.completions, isEmpty);
    expect(v2Store.committedState, same(v2ObjectBefore));
    expect(v2Store.prepareCalls, v2PrepareBefore);
    expect(v2Store.submitCalls, v2SubmitBefore);
    expect(preferences.getString('course.learning.v2.sentinel'), sentinel);

    final rawBefore = await _comparisonSqlCounts(fixture.harness);
    final provider = ProviderScope.containerOf(
      tester.element(find.byType(ComparisonLessonScreen)),
    );
    final providerCommittedBefore = provider
        .read(comparisonLearningStateProvider)
        .value!;
    final committedBefore = terminal;
    final completionIdentity = fixture.tracker.current;
    var notificationScopeAlive = true;
    addTearDown(() => notificationScopeAlive = false);
    fixture.commitNotification.listener = () {
      final current = fixture.tracker.current;
      if (!notificationScopeAlive ||
          current.owner != completionIdentity.owner ||
          current.generation != completionIdentity.generation) {
        return;
      }
      provider.invalidate(comparisonLearningStateProvider);
    };
    final prewriteSession = LessonSectionSession.fromJson(
      Map<String, dynamic>.from(committedBefore.slot!.checkpoint.sessionJson),
      itemIds: fixture.catalogue.exercises.map((e) => e.id).toList(),
      contentRevision: 1,
    );
    expect(prewriteSession.phase, LessonSectionPhase.debrief);
    expect(providerCommittedBefore.completions, isEmpty);
    final firstGate = await _newPersistenceWriteGate(tester, fail: true);
    addTearDown(() => firstGate.releaseIfHeld());
    fixture.persistence.nextWriteGate = firstGate;
    final firstAck = await _runRealAsync(tester, () async => Completer<void>());
    fixture.store.nextSubmitAck = firstAck;
    await tester.tap(find.text('Finish comparison'));
    await tester.pump();
    await tester.runAsync(() => firstGate.entered.future);
    final firstCommand = fixture.store.commands.last;
    expect(
      firstCommand.action,
      isA<FinishComparisonRun>().having(
        (a) => a.recordCompletion,
        'recordCompletion',
        true,
      ),
    );
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    expect(popCount, 0);
    expect(committedBefore.completions, isEmpty);
    final firstHeldProviderState = provider
        .read(comparisonLearningStateProvider)
        .value!;
    expect(firstHeldProviderState.completions, isEmpty);
    expect(
      ComparisonProgressSummary.fromState(
        state: firstHeldProviderState,
        catalogue: fixture.catalogue,
      ).completedRuns,
      0,
    );
    expect(
      ComparisonProgressSummary.fromState(
        state: committedBefore,
        catalogue: fixture.catalogue,
      ).completedRuns,
      0,
    );
    expect(await _comparisonSqlCounts(fixture.harness), rawBefore);
    expect(v2Store.committedState, same(v2ObjectBefore));
    expect(v2Store.prepareCalls, v2PrepareBefore);
    expect(v2Store.submitCalls, v2SubmitBefore);
    await _releasePersistenceWrite(tester, firstGate);
    await tester.runAsync(() => firstAck.future);
    await tester.pump();
    expect(find.text('Retry saving'), findsOneWidget);
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    expect(popCount, 0);
    expect(
      provider.read(comparisonLearningStateProvider).value!.completions,
      isEmpty,
    );
    final afterFailure = await _runRealAsync(tester, fixture.store.snapshot);
    expect(afterFailure.completions, isEmpty);

    final retryGate = await _newPersistenceWriteGate(tester);
    addTearDown(() => retryGate.releaseIfHeld());
    fixture.persistence.nextWriteGate = retryGate;
    final retryAck = await _runRealAsync(tester, () async => Completer<void>());
    fixture.store.nextSubmitAck = retryAck;
    await tester.tap(find.text('Retry saving'));
    await tester.pump();
    await tester.runAsync(() => retryGate.entered.future);
    expect(fixture.store.commands.last, same(firstCommand));
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    expect(popCount, 0);
    final retryHeldProviderState = provider
        .read(comparisonLearningStateProvider)
        .value!;
    expect(retryHeldProviderState.completions, isEmpty);
    expect(
      ComparisonProgressSummary.fromState(
        state: retryHeldProviderState,
        catalogue: fixture.catalogue,
      ).completedRuns,
      0,
    );
    expect(await _comparisonSqlCounts(fixture.harness), rawBefore);
    final refreshReadGate = await _newPersistenceReadGate(
      tester,
      key: fixture.scope.storageKey,
    );
    addTearDown(() => refreshReadGate.releaseIfHeld());
    fixture.persistence.readGates[fixture.scope.storageKey] = refreshReadGate;
    final loadsBeforeRefresh = fixture.store.loadCalls;
    await _releasePersistenceWrite(tester, retryGate);
    await tester.runAsync(() => retryAck.future);
    for (var frame = 0; frame < 30 && popCount == 0; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(popCount, 1);
    for (
      var frame = 0;
      frame < 30 && find.byType(ComparisonLessonScreen).evaluate().isNotEmpty;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(ComparisonLessonScreen), findsNothing);
    expect(find.byType(CourseMapScreen), findsOneWidget);
    expect(popCount, 1);
    await _waitForLoadCall(tester, fixture.store, loadsBeforeRefresh + 1);
    await tester.runAsync(() => refreshReadGate.entered.future);
    await tester.pump();
    expect(
      find.text('Comparison completion policies: 1'),
      findsNothing,
      reason: 'the ACK-triggered reload is still held',
    );
    final refreshLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = refreshLoadAck;
    await _releasePersistenceRead(tester, refreshReadGate);
    await tester.runAsync(() => refreshLoadAck.future);
    await tester.pumpAndSettle();
    expect(find.text('Comparison completion policies: 1'), findsOneWidget);
    final durable = await _runRealAsync(tester, fixture.store.snapshot);
    expect(durable.completions, hasLength(1));
    final durableSummary = ComparisonProgressSummary.fromState(
      state: durable,
      catalogue: fixture.catalogue,
    );
    expect(durableSummary.completedRuns, 1);
    expect(durableSummary.completionLabel, 'Comparison completion policies: 1');
    expect(v2Store.committedState, same(v2ObjectBefore));
    expect(v2Store.prepareCalls, v2PrepareBefore);
    expect(v2Store.submitCalls, v2SubmitBefore);
    expect(preferences.getString('course.learning.v2.sentinel'), sentinel);

    router.go('/course-progress');
    await tester.pumpAndSettle();
    expect(find.text('Comparison completion policies: 1'), findsOneWidget);

    final receiptCount = durable.receipts.length;
    final duplicate = await _runRealAsync(
      tester,
      () => fixture.store.submit(firstCommand),
    );
    expect(duplicate.state.completions, hasLength(1));
    expect(duplicate.state.receipts, hasLength(receiptCount));
    expect(
      ComparisonProgressSummary.fromState(
        state: duplicate.state,
        catalogue: fixture.catalogue,
      ).completedRuns,
      1,
    );
    await tester.pump();
    expect(
      popCount,
      1,
      reason: 'duplicate receipt does not cause another route pop',
    );
    expect(find.text('Comparison completion policies: 1'), findsOneWidget);
  });

  testWidgets('comparison_review_finish_never_adds_completion', (tester) async {
    disableMapMotion(tester);
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await _repositoryFixture(tester);
    final terminal = await _seedDebrief(
      tester,
      fixture.store,
      fixture.catalogue,
      wrongIndexes: {0, 3},
    );
    final firstFinish = fixture.store.prepare(
      state: terminal,
      activityId: comparisonActivityId,
      action: const FinishComparisonRun(recordCompletion: true),
    );
    final committed = await _runRealAsync(
      tester,
      () async => (await fixture.store.submit(firstFinish)).state,
    );
    expect(committed.completions, hasLength(1));
    final homeLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = homeLoadAck;
    final audio = _EntryReferenceAudio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._repositoryOverrides(fixture),
          courseReferenceAudioProvider.overrideWithValue(audio),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => homeLoadAck.future);
    await tester.pump();
    await tester.pump();
    await _inspectMixedComparison(tester);
    expect(find.text('Review comparison'), findsOneWidget);
    final router = GoRouter.of(tester.element(find.byType(CourseMapScreen)));
    var popCount = 0;
    var previousDepth =
        router.routerDelegate.currentConfiguration.matches.length;
    void recordPop() {
      final depth = router.routerDelegate.currentConfiguration.matches.length;
      if (depth < previousDepth) popCount += previousDepth - depth;
      previousDepth = depth;
    }

    router.routerDelegate.addListener(recordPop);
    addTearDown(() => router.routerDelegate.removeListener(recordPop));
    final reviewLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = reviewLoadAck;
    await tester.ensureVisible(find.text('Review comparison'));
    await tester.tap(find.widgetWithText(FilledButton, 'Review comparison'));
    await tester.pump();
    await _waitForLoadCall(tester, fixture.store, 2);
    await tester.runAsync(() => reviewLoadAck.future);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Comparison debrief'), findsOneWidget);
    final reviewAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextSubmitAck = reviewAck;
    await tester.tap(find.text('Review unresolved pairs'));
    await tester.pump();
    await tester.runAsync(() => reviewAck.future);
    await tester.pumpAndSettle();
    final reviewState = await _runRealAsync(tester, fixture.store.snapshot);
    final reviewSession = LessonSectionSession.fromJson(
      Map<String, dynamic>.from(reviewState.checkpoint!.sessionJson),
      itemIds: fixture.catalogue.exercises.map((e) => e.id).toList(),
      contentRevision: 1,
    );
    expect(reviewSession.queue, ['fr07b-pair-01', 'fr07b-pair-04']);
    expect(reviewSession.position, 0);
    expect(reviewSession.currentItemId, 'fr07b-pair-01');
    final resumeAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = resumeAck;
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ComparisonLessonScreen), findsNothing);
    await _inspectMixedComparison(tester);
    await tester.ensureVisible(find.text('Review comparison'));
    await tester.tap(find.widgetWithText(FilledButton, 'Review comparison'));
    await tester.pump();
    await _waitForLoadCall(tester, fixture.store, 3);
    await tester.runAsync(() => resumeAck.future);
    await tester.pumpAndSettle();
    for (var index = 0; index < reviewSession.queue.length; index++) {
      final current = await _runRealAsync(tester, fixture.store.snapshot);
      final currentSession = LessonSectionSession.fromJson(
        Map<String, dynamic>.from(current.checkpoint!.sessionJson),
        itemIds: fixture.catalogue.exercises.map((e) => e.id).toList(),
        contentRevision: 1,
      );
      final exercise = fixture.catalogue.exercise(
        currentSession.currentItemId!,
      );
      await tester.tap(find.text('Listen to sample A'));
      await tester.pump();
      expect(audio.requests.last, exercise.sampleA.referenceId);
      await tester.tap(find.text('Listen to sample B'));
      await tester.pump();
      expect(audio.requests.last, exercise.sampleB.referenceId);
      final answerAck = await _runRealAsync(
        tester,
        () async => Completer<void>(),
      );
      fixture.store.nextSubmitAck = answerAck;
      await tester.tap(
        find.text(
          exercise.expectedRelation == PhonemeRelation.same
              ? 'Same'
              : 'Different',
        ),
      );
      await tester.pump();
      await tester.runAsync(() => answerAck.future);
      await tester.pumpAndSettle();
      final advanceAck = await _runRealAsync(
        tester,
        () async => Completer<void>(),
      );
      fixture.store.nextSubmitAck = advanceAck;
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.runAsync(() => advanceAck.future);
      await tester.pumpAndSettle();
    }
    expect(find.text('Comparison debrief'), findsOneWidget);
    final beforeReviewFinish = await _runRealAsync(
      tester,
      fixture.store.snapshot,
    );
    expect(beforeReviewFinish.completions, hasLength(1));
    final popsBeforeReviewFinish = popCount;
    final reviewFinishAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextSubmitAck = reviewFinishAck;
    await tester.tap(find.text('Finish comparison'));
    await tester.pump();
    await tester.runAsync(() => reviewFinishAck.future);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(ComparisonLessonScreen), findsNothing);
    expect(find.byType(CourseMapScreen), findsOneWidget);
    expect(popCount, popsBeforeReviewFinish + 1);
    final afterReviewFinish = await _runRealAsync(
      tester,
      fixture.store.snapshot,
    );
    expect(afterReviewFinish.completions, hasLength(1));
    expect(
      afterReviewFinish.completions.single.activityId,
      committed.completions.single.activityId,
    );
    expect(
      afterReviewFinish.completions.single.contentRevision,
      committed.completions.single.contentRevision,
    );
    expect(
      afterReviewFinish.completions.single.thresholdPercent,
      committed.completions.single.thresholdPercent,
    );
    expect(
      afterReviewFinish.completions.single.committedAt,
      committed.completions.single.committedAt,
    );
    final finishCommand = fixture.store.commands.last;
    expect(
      finishCommand.action,
      isA<FinishComparisonRun>().having(
        (a) => a.recordCompletion,
        'recordCompletion',
        false,
      ),
    );
  });

  testWidgets('comparison_owner_refresh_a_to_b_to_a_isolation', (tester) async {
    disableMapMotion(tester);
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ownerA = LearningOwner.account('task6-owner-a');
    final ownerB = LearningOwner.account('task6-owner-b');
    final tracker = LearningAuthTracker(owner: ownerA, ready: true);
    final ownerFixture = await _newOwnerRefreshFixture(tester, tracker);
    final seedA = await _runRealAsync(
      tester,
      () async => ownerFixture.createStore(ownerA, 0),
    );
    final completedA = await _seedCompletedRun(
      tester,
      seedA,
      ownerFixture.catalogue,
    );
    expect(completedA.completions, hasLength(1));

    tracker.observe(owner: ownerB, ready: true);
    final seedB = await _runRealAsync(
      tester,
      () async => ownerFixture.createStore(ownerB, 1),
    );
    final evidenceB = await _seedFirstOwnerAnswer(
      tester,
      seedB,
      ownerFixture.catalogue,
    );
    expect(evidenceB.completions, isEmpty);
    expect(evidenceB.summaries.values.single.firstInRun.total, 1);
    tracker.observe(owner: ownerA, ready: true);

    final v2State = _nonemptyV2State();
    final v2Store = CourseLearningWidgetStore(initialState: v2State);
    final initialAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    ownerFixture.pendingLoadAcks[(ownerA.userId!, 2)] = initialAck;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(v2Store),
          courseLearningStateProvider.overrideWith((ref) async => v2State),
          learningAuthScopeProvider.overrideWith((ref) => tracker),
          learningDatabaseHandleProvider.overrideWithValue(
            ownerFixture.harness.database,
          ),
          comparisonCatalogueProvider.overrideWithValue(ownerFixture.catalogue),
          comparisonLearningStoreProvider.overrideWith((ref) {
            final identity = ref.watch(
              learningAuthScopeProvider.select(
                (auth) => (owner: auth.owner, generation: auth.generation),
              ),
            );
            var isAlive = true;
            ref.onDispose(() => isAlive = false);
            return ownerFixture.createStore(
              identity.owner,
              identity.generation,
              onCommitted: () {
                final current = tracker.current;
                if (!isAlive ||
                    current.owner != identity.owner ||
                    current.generation != identity.generation) {
                  return;
                }
                ref.invalidate(comparisonLearningStateProvider);
              },
            );
          }),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    final storeA2 = ownerFixture.storeFor(ownerA, 2);
    await tester.runAsync(() => initialAck.future);
    await tester.pumpAndSettle();
    await _inspectMixedComparison(tester);
    expect(find.text('Comparison pairs attempted: 10/10'), findsOneWidget);
    expect(find.text('Comparison completion policies: 1'), findsOneWidget);
    expect(find.text('Review comparison'), findsOneWidget);
    expect(find.text('Open destination'), findsNothing);
    expect(
      find.textContaining('Discovery lessons:'),
      findsNothing,
      reason: 'foreign V2 state remains unknown for the current owner',
    );

    final gateB = await _newPersistenceReadGate(
      tester,
      key: ComparisonProfileScope(courseId: 'en-fr', owner: ownerB).storageKey,
    );
    addTearDown(() => gateB.releaseIfHeld());
    ownerFixture.persistence.readGates[gateB.key] = gateB;
    tracker.observe(owner: ownerB, ready: true);
    await tester.pump();
    await tester.runAsync(() => gateB.entered.future);
    await _inspectMixedComparison(tester);
    expect(find.byType(CourseMapScreen), findsOneWidget);
    expect(find.text('Comparison completion policies: 1'), findsNothing);
    expect(find.text('Comparison pairs attempted: 10/10'), findsNothing);
    expect(
      find.textContaining('Discovery lessons:'),
      findsNothing,
      reason: 'foreign V2 state remains unknown for the current owner',
    );
    final storeB3 = ownerFixture.storeFor(ownerB, 3);
    final bLoadAck = await _runRealAsync(tester, () async => Completer<void>());
    storeB3.nextLoadAck = bLoadAck;
    await _releasePersistenceRead(tester, gateB);
    await tester.runAsync(() => bLoadAck.future);
    await tester.pumpAndSettle();
    await _inspectMixedComparison(tester);
    expect(find.text('Comparison pairs attempted: 1/10'), findsOneWidget);
    expect(find.text('Comparison answers: 1/1'), findsOneWidget);
    expect(find.text('Comparison completion policies: 0'), findsOneWidget);
    expect(find.text('Open destination'), findsOneWidget);
    expect(completedA.completions, hasLength(1));
    expect(evidenceB.completions, isEmpty);

    final router = GoRouter.of(tester.element(find.byType(CourseMapScreen)));
    router.go('/course-progress');
    await tester.pumpAndSettle();
    expect(find.text('Comparison pairs attempted: 1/10'), findsOneWidget);
    expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
    final gateA = await _newPersistenceReadGate(
      tester,
      key: ComparisonProfileScope(courseId: 'en-fr', owner: ownerA).storageKey,
    );
    addTearDown(() => gateA.releaseIfHeld());
    ownerFixture.persistence.readGates[gateA.key] = gateA;
    tracker.observe(owner: ownerA, ready: true);
    await tester.pump();
    await tester.runAsync(() => gateA.entered.future);
    expect(find.text('Comparison pairs attempted: 1/10'), findsNothing);
    expect(find.text('Comparison completion policies: 0'), findsNothing);
    expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
    final storeA4 = ownerFixture.storeFor(ownerA, 4);
    final aReturnAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    storeA4.nextLoadAck = aReturnAck;
    await _releasePersistenceRead(tester, gateA);
    await tester.runAsync(() => aReturnAck.future);
    await tester.pumpAndSettle();
    router.go('/home');
    await tester.pumpAndSettle();
    await _inspectMixedComparison(tester);
    expect(find.text('Comparison pairs attempted: 10/10'), findsOneWidget);
    expect(find.text('Comparison completion policies: 1'), findsOneWidget);
    expect(
      find.textContaining('Discovery lessons:'),
      findsNothing,
      reason: 'foreign V2 state remains unknown for the current owner',
    );

    final failedBRead = await _newPersistenceReadGate(
      tester,
      key: ComparisonProfileScope(courseId: 'en-fr', owner: ownerB).storageKey,
      fail: true,
    );
    addTearDown(() => failedBRead.releaseIfHeld());
    ownerFixture.persistence.readGates[failedBRead.key] = failedBRead;
    tracker.observe(owner: ownerB, ready: true);
    await tester.pump();
    await tester.runAsync(() => failedBRead.entered.future);
    await _inspectMixedComparison(tester);
    expect(find.text('Comparison pairs attempted: 10/10'), findsNothing);
    expect(find.text('Comparison completion policies: 1'), findsNothing);
    expect(
      find.textContaining('Discovery lessons:'),
      findsNothing,
      reason: 'foreign V2 state remains unknown for the current owner',
    );
    final storeB5 = ownerFixture.storeFor(ownerB, 5);
    final failedLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    storeB5.nextLoadAck = failedLoadAck;
    await _releasePersistenceRead(tester, failedBRead);
    await tester.runAsync(() => failedLoadAck.future);
    await tester.pumpAndSettle();
    await _inspectMixedComparison(tester);
    expect(find.text('Open mixed comparison recovery'), findsOneWidget);
    expect(find.text('Comparison pairs attempted: 10/10'), findsNothing);
    expect(find.text('Comparison pairs attempted: 1/10'), findsNothing);
    expect(
      find.textContaining('Discovery lessons:'),
      findsNothing,
      reason: 'foreign V2 state remains unknown for the current owner',
    );
    router.go('/course-progress');
    await tester.pumpAndSettle();
    expect(find.text('Retry comparison progress'), findsOneWidget);
    expect(find.text('Comparison completion policies: 1'), findsNothing);
    expect(
      find.text(
        'Supported backup is pending; local commits remain saved on this device.',
      ),
      findsOneWidget,
    );

    router.go('/home');
    await tester.pumpAndSettle();
    await _inspectMixedComparison(tester);
    expect(find.byType(CourseMapScreen), findsOneWidget);
    expect(find.textContaining('Destination unavailable'), findsOneWidget);
    expect(find.text('Comparison completion policies: 1'), findsNothing);
    expect(find.text('Comparison completion policies: 0'), findsNothing);
    expect(find.text('Review lesson'), findsNothing);
    expect(find.text('Open destination'), findsNothing);
    expect(
      find.textContaining('Discovery lessons:'),
      findsNothing,
      reason: 'foreign V2 state remains unknown for the current owner',
    );
    router.go('/course-progress');
    await tester.pumpAndSettle();
    expect(find.text('Retry comparison progress'), findsOneWidget);
    expect(find.text('Comparison completion policies: 1'), findsNothing);

    final retryAck = await _runRealAsync(tester, () async => Completer<void>());
    final recoveredAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    storeB5.nextRetryAck = retryAck;
    storeB5.nextLoadAck = recoveredAck;
    final loadsBeforeRetry = storeB5.loadCalls;
    await tester.ensureVisible(find.text('Retry comparison progress'));
    await tester.tap(find.text('Retry comparison progress'));
    await tester.pump();
    await tester.runAsync(() => retryAck.future);
    await _waitForLoadCall(tester, storeB5, loadsBeforeRetry + 1);
    await tester.runAsync(() => recoveredAck.future);
    await tester.pumpAndSettle();
    expect(find.text('Comparison pairs attempted: 1/10'), findsOneWidget);
    expect(find.text('Comparison completion policies: 0'), findsOneWidget);
    expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);

    router.go('/home');
    await tester.pumpAndSettle();
    await _inspectMixedComparison(tester);
    expect(find.text('Comparison pairs attempted: 1/10'), findsOneWidget);
    expect(find.text('Open destination'), findsOneWidget);
    expect(
      find.textContaining('Discovery lessons:'),
      findsNothing,
      reason: 'foreign V2 state remains unknown for the current owner',
    );
    expect(completedA.completions, hasLength(1));
    expect(evidenceB.summaries.values.single.firstInRun.total, 1);
    expect(storeA2.commands, isEmpty);
    expect(storeB3.commands, isEmpty);
    expect(storeA4.commands, isEmpty);
    expect(storeB5.commands, isEmpty);
    expect(v2Store.committedState, same(v2State));
    expect(v2Store.prepareCalls, 0);
    expect(v2Store.submitCalls, 0);
  });

  testWidgets('comparison_progress_retry_is_independent_from_v2_retry', (
    tester,
  ) async {
    final fixture = await _repositoryFixture(tester);
    fixture.persistence.failNextRead = true;
    final initialLoad = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = initialLoad;
    final v2Store = CourseLearningWidgetStore()..failLoad = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(v2Store),
          learningAuthScopeProvider.overrideWith(
            (ref) =>
                LearningAuthTracker(owner: fixture.scope.owner, ready: true),
          ),
          comparisonCatalogueProvider.overrideWithValue(fixture.catalogue),
          comparisonLearningStoreProvider.overrideWithValue(fixture.store),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => initialLoad.future);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Retry loading progress'), findsOneWidget);
    expect(find.text('Retry comparison progress'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CourseProgressScreen)),
    );
    expect(
      identical(container.read(comparisonLearningStoreProvider), fixture.store),
      isTrue,
    );
    final retryLoadCompleted = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextRetryAck = retryLoadCompleted;
    await tester.tap(find.text('Retry comparison progress'));
    await tester.pump();
    await tester.runAsync(() => retryLoadCompleted.future);
    await tester.pump();
    await _runRealAsync(tester, fixture.store.snapshot);
    await tester.pump();
    await _runRealAsync(tester, fixture.store.snapshot);
    await tester.pump();
    expect(fixture.store.retryLoadCalls, 1);
    expect(fixture.store.retryFailure, isNull);
    expect(v2Store.retryLoadCalls, 0);
    await tester.scrollUntilVisible(
      find.text('Comparison pairs attempted: 0/10'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Comparison pairs attempted: 0/10'), findsOneWidget);
    expect(find.text('Retry loading progress'), findsOneWidget);
    await tester.tap(find.text('Retry loading progress'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(v2Store.retryLoadCalls, 1);
    expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Comparison pairs attempted: 0/10'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Comparison pairs attempted: 0/10'), findsOneWidget);
  });

  for (final scale in [2.0, 3.0]) {
    testWidgets(
      'v2_data_comparison_error_retry_and_pair_link_are_reachable_at_${scale}x',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(
          () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
        );

        final fixture = await _repositoryFixture(tester);
        final seeded = await _seedDebrief(
          tester,
          fixture.store,
          fixture.catalogue,
          wrongIndexes: {0, 3},
        );
        final before = await _runRealAsync(tester, fixture.store.snapshot);
        final initialCommands = fixture.store.commands.length;
        fixture.persistence.failNextRead = true;
        final v2Store = CourseLearningWidgetStore();
        final homeLoadAck = await _runRealAsync(
          tester,
          () async => Completer<void>(),
        );
        fixture.store.nextLoadAck = homeLoadAck;
        await tester.pumpWidget(
          ProviderScope(
            overrides: _progressRepositoryOverrides(
              fixture,
              v2Store,
              _nonemptyV2State(),
            ),
            child: const LinguistApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() => homeLoadAck.future);
        await tester.pump();
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byType(CourseMapScreen),
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byTooltip('Progress'));
        await tester.pumpAndSettle();
        expect(find.byType(CourseProgressScreen), findsOneWidget);

        expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
        expect(
          find.text(
            'Existing lessons (includes discovery pilot): 0/5 complete',
          ),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.textContaining('1 correct / 2 answers'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('1 correct / 2 answers'), findsOneWidget);
        expect(
          find.textContaining(
            'Supported backup covers scores and answer totals.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Supported backup is pending; local commits remain saved on this device.',
          ),
          findsOneWidget,
        );
        var router = GoRouter.of(
          tester.element(find.byType(CourseProgressScreen)),
        );
        router.go('/course-review');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Unresolved · 2 incorrect answers'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('/i/ · Listening'), findsOneWidget);
        expect(find.text('Unresolved · 2 incorrect answers'), findsOneWidget);
        final v2Mistake = find.text('/i/ · Listening');
        final mistakeScrollable = find
            .ancestor(of: v2Mistake, matching: find.byType(Scrollable))
            .first;
        await tester.scrollUntilVisible(
          v2Mistake,
          160,
          scrollable: mistakeScrollable,
          maxScrolls: 100,
        );
        await tester.pump();
        final mistakeRect = tester.getRect(v2Mistake);
        expect(mistakeRect.bottom, greaterThan(56));
        expect(mistakeRect.top, lessThan(640));
        await tester.tap(v2Mistake);
        await tester.pumpAndSettle();
        expect(find.byType(CourseLessonScreen), findsOneWidget);
        expect(
          GoRouterState.of(
            tester.element(find.byType(CourseLessonScreen)),
          ).uri.toString(),
          '/course-lesson/en-fr-vowels?review=true',
        );
        router = GoRouter.of(tester.element(find.byType(CourseLessonScreen)));
        router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(CourseProgressScreen), findsOneWidget);
        router = GoRouter.of(tester.element(find.byType(CourseProgressScreen)));
        router.go('/course-progress');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Retry comparison progress'),
          160,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 120,
        );
        await tester.pump();
        expect(find.text('Retry comparison progress'), findsOneWidget);
        expect(
          find.text('Comparison practice, not phoneme mastery'),
          findsOneWidget,
          reason: 'practice disclaimer remains honest in unavailable state',
        );
        expect(find.text('Comparison pairs attempted: 10/10'), findsNothing);

        final retryAck = await _runRealAsync(
          tester,
          () async => Completer<void>(),
        );
        final recoveredLoadAck = await _runRealAsync(
          tester,
          () async => Completer<void>(),
        );
        fixture.store.nextRetryAck = retryAck;
        fixture.store.nextLoadAck = recoveredLoadAck;
        final loadsBeforeRetry = fixture.store.loadCalls;
        final v2RetryBefore = v2Store.retryLoadCalls;
        final v2PrepareBefore = v2Store.prepareCalls;
        final v2SubmitBefore = v2Store.submitCalls;
        await tester.scrollUntilVisible(
          find.text('Retry comparison progress'),
          160,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 120,
        );
        await tester.pump();
        await tester.tap(find.text('Retry comparison progress'));
        await tester.pump();
        await tester.runAsync(() => retryAck.future);
        await _waitForLoadCall(tester, fixture.store, loadsBeforeRetry + 1);
        await tester.runAsync(() => recoveredLoadAck.future);
        await tester.pump();
        await _runRealAsync(tester, fixture.store.snapshot);
        await tester.pump();
        expect(fixture.store.retryLoadCalls, 1);
        expect(v2Store.retryLoadCalls, v2RetryBefore);
        expect(v2Store.prepareCalls, v2PrepareBefore);
        expect(v2Store.submitCalls, v2SubmitBefore);
        expect(find.text('Retry loading progress'), findsNothing);

        router.go('/home');
        await tester.pumpAndSettle();
        await _inspectMixedComparison(tester);
        const labels = [
          'Comparison practice, not phoneme mastery',
          'Comparison pairs attempted: 10/10',
          'Comparison answers: 8/10',
          'After-debrief comparison answers: 0',
          'Comparison completion policies: 0',
          'Unresolved comparison pairs: 2',
        ];
        for (final label in labels) {
          await tester.ensureVisible(find.text(label));
          expect(
            find.text(label),
            findsOneWidget,
            reason: 'scale $scale: $label',
          );
          expect(tester.takeException(), isNull, reason: 'scale $scale');
        }
        router.go('/course-progress');
        await tester.pumpAndSettle();
        final pair04 = find.text('Comparison pair fr07b-pair-04');
        await tester.scrollUntilVisible(
          pair04,
          160,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 120,
        );
        await tester.pump();
        expect(pair04, findsOneWidget);
        final screenLoadAck = await _runRealAsync(
          tester,
          () async => Completer<void>(),
        );
        fixture.store.nextLoadAck = screenLoadAck;
        final loadsBeforeLink = fixture.store.loadCalls;
        await tester.tap(pair04);
        await tester.pump();
        await _waitForLoadCall(tester, fixture.store, loadsBeforeLink + 1);
        await tester.runAsync(() => screenLoadAck.future);
        await tester.pump();
        expect(find.byType(ComparisonLessonScreen), findsOneWidget);
        expect(
          GoRouterState.of(
            tester.element(find.byType(ComparisonLessonScreen)),
          ).uri.toString(),
          '/course-comparison/en-fr-phoneme-comparison?pairId=fr07b-pair-04&review=true',
        );
        expect(find.text('Requested pair: fr07b-pair-04'), findsOneWidget);
        expect(find.text('Comparison debrief'), findsOneWidget);
        final after = await _runRealAsync(tester, fixture.store.snapshot);
        expect(after.checkpoint!.sessionJson, before.checkpoint!.sessionJson);
        expect(after.completions, seeded.completions);
        expect(fixture.store.commands.length, initialCommands);
        expect(tester.takeException(), isNull, reason: 'scale $scale');
      },
    );
  }

  testWidgets('comparison_data_and_pair_link_survive_v2_progress_error', (
    tester,
  ) async {
    final fixture = await _repositoryFixture(tester);
    final seeded = await _seedDebrief(
      tester,
      fixture.store,
      fixture.catalogue,
      wrongIndexes: {0, 3},
    );
    final before = await _runRealAsync(tester, fixture.store.snapshot);
    final commandsBefore = fixture.store.commands.length;
    final homeLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = homeLoadAck;
    final v2Store = CourseLearningWidgetStore()..failLoad = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(v2Store),
          learningAuthScopeProvider.overrideWith(
            (ref) =>
                LearningAuthTracker(owner: fixture.scope.owner, ready: true),
          ),
          comparisonCatalogueProvider.overrideWithValue(fixture.catalogue),
          comparisonLearningStoreProvider.overrideWithValue(fixture.store),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => homeLoadAck.future);
    await tester.pump();
    await tester.tap(find.byTooltip('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Retry loading progress'), findsOneWidget);
    expect(
      find.text('Discovery lessons: 0/1 complete'),
      findsNothing,
      reason: 'do not show stale v2 counts after its load error',
    );
    const labels = [
      'Comparison practice, not phoneme mastery',
      'Comparison pairs attempted: 10/10',
      'Comparison answers: 8/10',
      'After-debrief comparison answers: 0',
      'Comparison completion policies: 0',
      'Unresolved comparison pairs: 2',
    ];
    for (final label in labels) {
      await tester.scrollUntilVisible(
        find.text(label),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsOneWidget, reason: label);
    }
    final pair04 = find.text('Comparison pair fr07b-pair-04');
    await tester.scrollUntilVisible(
      pair04,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    final screenLoadAck = await _runRealAsync(
      tester,
      () async => Completer<void>(),
    );
    fixture.store.nextLoadAck = screenLoadAck;
    final loadsBeforeLink = fixture.store.loadCalls;
    await tester.tap(pair04);
    await tester.pump();
    await _waitForLoadCall(tester, fixture.store, loadsBeforeLink + 1);
    await tester.runAsync(() => screenLoadAck.future);
    await tester.pump();
    expect(find.byType(ComparisonLessonScreen), findsOneWidget);
    expect(find.text('Requested pair: fr07b-pair-04'), findsOneWidget);
    final after = await _runRealAsync(tester, fixture.store.snapshot);
    expect(after.checkpoint!.sessionJson, before.checkpoint!.sessionJson);
    expect(after.completions, seeded.completions);
    expect(fixture.store.commands.length, commandsBefore);
  });
}

Future<void> _inspectMixedComparison(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final disclosure = find.byKey(const ValueKey('destination-list-disclosure'));
  if (disclosure.evaluate().isNotEmpty) {
    await tester.ensureVisible(disclosure);
    await tester.tap(disclosure);
    await tester.pumpAndSettle();
  }
  final destination = find.text('Mixed comparison practice');
  await tester.ensureVisible(destination);
  await tester.tap(destination);
  await tester.pumpAndSettle();
}

final class _Driver {
  _Driver()
    : catalogue = loadFrenchComparisonCatalogue(),
      scope = ComparisonProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.guest(),
      ) {
    engine = ComparisonLearningTransitionEngine(catalogue: catalogue);
    state = ComparisonLearningState.empty(scope);
  }
  final ComparisonCatalogue catalogue;
  final ComparisonProfileScope scope;
  late final ComparisonLearningTransitionEngine engine;
  late ComparisonLearningState state;
  int n = 0;
  DateTime now() => DateTime.utc(2026).add(Duration(seconds: n));
  String token() => 'token${(++n).toString().padLeft(17, '0')}';
  void act(ComparisonAction action) {
    final command = engine.prepare(
      state: state,
      activityId: comparisonActivityId,
      action: action,
      authGeneration: 0,
      token: token(),
      submittedAt: now(),
    );
    state = engine
        .evaluate(state: state, command: command, committedAt: now())
        .nextState;
  }

  void start() => act(
    StartComparisonRun(sessionId: 'test-session', policy: LessonPolicy()),
  );
  void answer(bool correct) {
    final json = state.checkpoint!.sessionJson;
    final id = json['currentItemId'] as String? ?? 'fr07b-pair-01';
    final exercise = catalogue.exercise(id);
    final session = LessonSectionSession.fromJson(
      json as Map<String, dynamic>,
      itemIds: catalogue.exercises.map((e) => e.id).toList(),
      contentRevision: 1,
    );
    final answer = correct
        ? exercise.expectedRelation
        : (exercise.expectedRelation == PhonemeRelation.same
              ? PhonemeRelation.different
              : PhonemeRelation.same);
    final time = now();
    final observations = [
      for (final sample in [exercise.sampleA, exercise.sampleB])
        ComparisonPlaybackObservation(
          slot: sample.slot,
          referenceId: sample.referenceId,
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.unverifiedRecording,
          activityId: comparisonActivityId,
          runGeneration: state.slot!.cursor.generation,
          round: session.round,
          pairId: id,
          profile: scope,
          uiGeneration: time.millisecondsSinceEpoch,
        ),
    ];
    act(
      AnswerComparisonPair(
        ComparePhonemesAnswer(
          selectedRelation: answer,
          expectedRelationSnapshot: exercise.expectedRelation,
          observations: observations,
        ),
      ),
    );
  }
}

Future<T> _runRealAsync<T>(
  WidgetTester tester,
  Future<T> Function() task,
) async {
  final result = await tester.runAsync(task);
  if (result == null) throw StateError('real async operation returned null');
  return result;
}

final class _ComparisonStoreControls {
  final readGates = <String, _PersistenceReadGate>{};
  int readCalls = 0;
  int writeCalls = 0;
  bool failNextRead = false;
  _PersistenceWriteGate? nextWriteGate;
}

final class _PersistenceReadGate {
  _PersistenceReadGate({required this.key, required this.fail});
  final String key;
  final bool fail;
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();
  void releaseIfHeld() {
    if (!release.isCompleted) release.complete();
  }
}

Future<_PersistenceReadGate> _newPersistenceReadGate(
  WidgetTester tester, {
  required String key,
  bool fail = false,
}) => _runRealAsync(
  tester,
  () async => _PersistenceReadGate(key: key, fail: fail),
);

Future<void> _releasePersistenceRead(
  WidgetTester tester,
  _PersistenceReadGate gate,
) async {
  await _runRealAsync(tester, () async {
    gate.releaseIfHeld();
    return true;
  });
}

final class _PersistenceWriteGate {
  _PersistenceWriteGate({required this.fail});
  final bool fail;
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();
  void releaseIfHeld() {
    if (!release.isCompleted) release.complete();
  }
}

Future<_PersistenceWriteGate> _newPersistenceWriteGate(
  WidgetTester tester, {
  bool fail = false,
}) => _runRealAsync(tester, () async => _PersistenceWriteGate(fail: fail));

Future<void> _releasePersistenceWrite(
  WidgetTester tester,
  _PersistenceWriteGate gate,
) async {
  await _runRealAsync(tester, () async {
    gate.releaseIfHeld();
    return true;
  });
}

final class _RepositoryComparisonStore implements ComparisonLearningStore {
  _RepositoryComparisonStore(
    this.delegate,
    this.controls,
    this.database,
    this.zone,
  );
  final ComparisonLearningStore delegate;
  final _ComparisonStoreControls controls;
  final LearningDatabaseHandle database;
  final Zone zone;
  Completer<void>? nextLoadAck;
  Completer<void>? nextSubmitAck;
  Completer<void>? nextRetryAck;
  int loadCalls = 0;
  int retryLoadCalls = 0;
  Object? retryFailure;
  final commands = <ComparisonLearningCommand>[];
  Future<T> _stable<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    zone.runGuarded(() {
      Future<T>.sync(operation).then(
        result.complete,
        onError: (Object error, StackTrace stack) =>
            result.completeError(error, stack),
      );
    });
    return result.future;
  }

  Future<void> _beforeRead() async {
    controls.readCalls++;
    final gate = controls.readGates.remove(scope.storageKey);
    if (gate != null) {
      gate.entered.complete();
      await gate.release.future;
      if (gate.fail) throw const ComparisonUnavailableException();
    }
    if (controls.failNextRead) {
      controls.failNextRead = false;
      throw const ComparisonUnavailableException();
    }
  }

  @override
  ComparisonProfileScope get scope => delegate.scope;
  @override
  Future<ComparisonLearningState> load() {
    loadCalls++;
    return _stable(() async {
      try {
        await _beforeRead();
        final value = await delegate.load();
        nextLoadAck?.complete();
        nextLoadAck = null;
        return value;
      } catch (_) {
        nextLoadAck?.complete();
        nextLoadAck = null;
        rethrow;
      }
    });
  }

  @override
  Future<ComparisonLearningState> retryLoad() {
    retryLoadCalls++;
    return _stable(() async {
      try {
        await _beforeRead();
        return await delegate.retryLoad();
      } catch (error) {
        retryFailure = error;
        rethrow;
      } finally {
        final ack = nextRetryAck;
        nextRetryAck = null;
        if (ack != null && !ack.isCompleted) ack.complete();
      }
    });
  }

  @override
  ComparisonLearningCommand prepare({
    required ComparisonLearningState state,
    required String activityId,
    required ComparisonAction action,
  }) => delegate.prepare(state: state, activityId: activityId, action: action);
  @override
  Future<ComparisonCommit> submit(ComparisonLearningCommand command) {
    commands.add(command);
    return _stable(() async {
      controls.writeCalls++;
      final gate = controls.nextWriteGate;
      controls.nextWriteGate = null;
      var triggerInstalled = false;
      try {
        if (gate != null) {
          gate.entered.complete();
          await gate.release.future;
          if (gate.fail) {
            final db = await database.open();
            await db.customStatement('''
              CREATE TRIGGER task10_comparison_test_reject_receipt
              BEFORE INSERT ON learning_command_receipts
              BEGIN SELECT RAISE(ABORT, 'task10 injected comparison SQL failure'); END
            ''');
            triggerInstalled = true;
          }
        }
        return await delegate.submit(command);
      } finally {
        if (triggerInstalled) {
          final db = await database.open();
          await db.customStatement(
            'DROP TRIGGER IF EXISTS task10_comparison_test_reject_receipt',
          );
        }
        nextSubmitAck?.complete();
        nextSubmitAck = null;
      }
    });
  }

  Future<ComparisonLearningState> snapshot() => _stable(delegate.load);
}

final class _RepositoryFixture {
  _RepositoryFixture(
    this.catalogue,
    this.scope,
    this.persistence,
    this.harness,
    this.store,
    this.tracker,
    this.commitNotification,
  );
  final ComparisonCatalogue catalogue;
  final ComparisonProfileScope scope;
  final _ComparisonStoreControls persistence;
  final ComparisonLearningSqlTestHarness harness;
  final _RepositoryComparisonStore store;
  final LearningAuthTracker tracker;
  final _CommitNotification commitNotification;
}

final class _CommitNotification {
  void Function()? listener;
  void notify() => listener?.call();
}

final class _OwnerRefreshFixture {
  _OwnerRefreshFixture(
    this.tracker,
    this.persistence,
    this.harness,
    this.catalogue,
    this.stableZone,
  );
  final LearningAuthTracker tracker;
  final _ComparisonStoreControls persistence;
  final ComparisonLearningSqlTestHarness harness;
  final ComparisonCatalogue catalogue;
  final Zone stableZone;
  final stores = <(String, int), _RepositoryComparisonStore>{};
  final pendingLoadAcks = <(String, int), Completer<void>>{};

  _RepositoryComparisonStore createStore(
    LearningOwner owner,
    int generation, {
    void Function()? onCommitted,
  }) {
    final identity = (owner.isGuest ? 'guest' : owner.userId!, generation);
    final cached = stores[identity];
    if (cached != null) return cached;
    final repository = harness.createRepository(
      owner: owner,
      generation: generation,
      onCommitted: onCommitted,
    );
    final store = _RepositoryComparisonStore(
      repository,
      persistence,
      harness.database,
      stableZone,
    );
    store.nextLoadAck = pendingLoadAcks.remove(identity);
    stores[identity] = store;
    return store;
  }

  _RepositoryComparisonStore storeFor(LearningOwner owner, int generation) {
    final identity = (owner.isGuest ? 'guest' : owner.userId!, generation);
    final store = stores[identity];
    if (store == null) {
      throw StateError('No owner repository for $identity');
    }
    return store;
  }
}

Future<_OwnerRefreshFixture> _newOwnerRefreshFixture(
  WidgetTester tester,
  LearningAuthTracker tracker,
) => _runRealAsync(tester, () async {
  final catalogue = loadFrenchComparisonCatalogue();
  final controls = _ComparisonStoreControls();
  final harness = ComparisonLearningSqlTestHarness(
    catalogue: catalogue,
    currentAuth: () => tracker.current,
    backendOwner: () => tracker.current.owner,
  );
  return _OwnerRefreshFixture(
    tracker,
    controls,
    harness,
    catalogue,
    Zone.current,
  );
});

final class _EntryReferenceAudio implements CourseReferenceAudio {
  final requests = <String>[];
  @override
  Future<CourseAudioResult> playReference(
    String referenceId, {
    CourseAudioUse use = CourseAudioUse.alphaPractice,
    CourseAudioVariant variant = CourseAudioVariant.normal,
    bool allowPracticeTts = false,
  }) async {
    requests.add(referenceId);
    return CourseAudioResult.completed(
      referenceId: referenceId,
      source: CourseAudioSource.unverifiedRecording,
    );
  }

  @override
  Future<void> speak(String word) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

Future<_RepositoryFixture> _repositoryFixture(WidgetTester tester) =>
    _runRealAsync(tester, () async {
      final catalogue = loadFrenchComparisonCatalogue();
      final scope = ComparisonProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.guest(),
      );
      final tracker = LearningAuthTracker(owner: scope.owner, ready: true);
      final controls = _ComparisonStoreControls();
      final commitNotification = _CommitNotification();
      final harness = ComparisonLearningSqlTestHarness(
        catalogue: catalogue,
        currentAuth: () => tracker.current,
        backendOwner: () => tracker.current.owner,
      );
      final repository = harness.createRepository(
        owner: scope.owner,
        generation: 0,
        onCommitted: commitNotification.notify,
      );
      return _RepositoryFixture(
        catalogue,
        scope,
        controls,
        harness,
        _RepositoryComparisonStore(
          repository,
          controls,
          harness.database,
          Zone.current,
        ),
        tracker,
        commitNotification,
      );
    });

Future<Map<String, int>> _comparisonSqlCounts(
  ComparisonLearningSqlTestHarness harness,
) async {
  final db = await harness.database.open();
  final counts = <String, int>{};
  for (final table in <String>[
    'learning_scopes',
    'learning_runs',
    'learning_attempts',
    'learning_command_receipts',
    'learning_summaries',
    'learning_completions',
  ]) {
    final row = await db
        .customSelect('SELECT COUNT(*) AS row_count FROM $table')
        .getSingle();
    counts[table] = row.read<int>('row_count');
  }
  return counts;
}

Future<ComparisonLearningState> _seedDebrief(
  WidgetTester tester,
  _RepositoryComparisonStore store,
  ComparisonCatalogue catalogue, {
  Set<int> wrongIndexes = const {},
}) => _runRealAsync(tester, () async {
  var state = await store.load();
  var command = store.prepare(
    state: state,
    activityId: comparisonActivityId,
    action: StartComparisonRun(
      sessionId: 'task6-b-seed',
      policy: LessonPolicy(),
    ),
  );
  state = (await store.submit(command)).state;
  for (var index = 0; index < catalogue.exercises.length; index++) {
    final slot = state.slot!;
    final session = LessonSectionSession.fromJson(
      Map<String, dynamic>.from(slot.checkpoint.sessionJson),
      itemIds: catalogue.exercises.map((e) => e.id).toList(),
      contentRevision: 1,
    );
    final exercise = catalogue.exercise(session.currentItemId!);
    final correct = !wrongIndexes.contains(index);
    final selected = correct
        ? exercise.expectedRelation
        : exercise.expectedRelation == PhonemeRelation.same
        ? PhonemeRelation.different
        : PhonemeRelation.same;
    final observations = [
      for (final sample in [exercise.sampleA, exercise.sampleB])
        ComparisonPlaybackObservation(
          slot: sample.slot,
          referenceId: sample.referenceId,
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.unverifiedRecording,
          activityId: comparisonActivityId,
          runGeneration: slot.cursor.generation,
          round: session.round,
          pairId: exercise.id,
          profile: slot.scope,
          uiGeneration: 1,
        ),
    ];
    command = store.prepare(
      state: state,
      activityId: comparisonActivityId,
      action: AnswerComparisonPair(
        ComparePhonemesAnswer(
          selectedRelation: selected,
          expectedRelationSnapshot: exercise.expectedRelation,
          observations: observations,
        ),
      ),
    );
    state = (await store.submit(command)).state;
    command = store.prepare(
      state: state,
      activityId: comparisonActivityId,
      action: const AdvanceComparisonPair(),
    );
    state = (await store.submit(command)).state;
  }
  return state;
});

Future<ComparisonLearningState> _seedFirstOwnerAnswer(
  WidgetTester tester,
  _RepositoryComparisonStore store,
  ComparisonCatalogue catalogue,
) => _runRealAsync(tester, () async {
  var state = await store.load();
  var command = store.prepare(
    state: state,
    activityId: comparisonActivityId,
    action: StartComparisonRun(
      sessionId: 'task6-owner-b-evidence',
      policy: LessonPolicy(),
    ),
  );
  state = (await store.submit(command)).state;
  final slot = state.slot!;
  final session = LessonSectionSession.fromJson(
    Map<String, dynamic>.from(slot.checkpoint.sessionJson),
    itemIds: catalogue.exercises.map((e) => e.id).toList(),
    contentRevision: 1,
  );
  final exercise = catalogue.exercise(session.currentItemId!);
  final observations = [
    for (final sample in [exercise.sampleA, exercise.sampleB])
      ComparisonPlaybackObservation(
        slot: sample.slot,
        referenceId: sample.referenceId,
        outcome: CourseAudioOutcome.completed,
        source: CourseAudioSource.unverifiedRecording,
        activityId: comparisonActivityId,
        runGeneration: slot.cursor.generation,
        round: session.round,
        pairId: exercise.id,
        profile: slot.scope,
        uiGeneration: 1,
      ),
  ];
  command = store.prepare(
    state: state,
    activityId: comparisonActivityId,
    action: AnswerComparisonPair(
      ComparePhonemesAnswer(
        selectedRelation: exercise.expectedRelation,
        expectedRelationSnapshot: exercise.expectedRelation,
        observations: observations,
      ),
    ),
  );
  state = (await store.submit(command)).state;
  command = store.prepare(
    state: state,
    activityId: comparisonActivityId,
    action: const AdvanceComparisonPair(),
  );
  return (await store.submit(command)).state;
});

Future<ComparisonLearningState> _seedActiveDraft(
  WidgetTester tester,
  _RepositoryComparisonStore store,
) => _runRealAsync(tester, () async {
  final state = await store.load();
  final command = store.prepare(
    state: state,
    activityId: comparisonActivityId,
    action: StartComparisonRun(
      sessionId: 'task6-b1-active-home',
      policy: LessonPolicy(),
    ),
  );
  return (await store.submit(command)).state;
});

Future<ComparisonLearningState> _seedCompletedRun(
  WidgetTester tester,
  _RepositoryComparisonStore store,
  ComparisonCatalogue catalogue,
) => _seedDebrief(tester, store, catalogue).then(
  (terminal) => _runRealAsync(tester, () async {
    final finish = store.prepare(
      state: terminal,
      activityId: comparisonActivityId,
      action: const FinishComparisonRun(recordCompletion: true),
    );
    return (await store.submit(finish)).state;
  }),
);

Future<void> _waitForLoadCall(
  WidgetTester tester,
  _RepositoryComparisonStore store,
  int expected,
) async {
  for (var frame = 0; frame < 30 && store.loadCalls < expected; frame++) {
    await tester.pump();
  }
  expect(store.loadCalls, greaterThanOrEqualTo(expected));
}

Future<void> _waitForCommandCount(
  WidgetTester tester,
  _RepositoryComparisonStore store,
  int expected,
) async {
  for (var frame = 0; frame < 30 && store.commands.length < expected; frame++) {
    await tester.pump();
  }
  expect(store.commands.length, greaterThanOrEqualTo(expected));
}

List<Override> _repositoryOverrides(_RepositoryFixture fixture) => [
  courseLearningStoreProvider.overrideWithValue(CourseLearningWidgetStore()),
  learningAuthScopeProvider.overrideWith((ref) => fixture.tracker),
  comparisonCatalogueProvider.overrideWithValue(fixture.catalogue),
  comparisonLearningStoreProvider.overrideWithValue(fixture.store),
];

List<Override> _progressRepositoryOverrides(
  _RepositoryFixture fixture,
  CourseLearningWidgetStore v2Store,
  CourseLearningState v2State,
) => [
  courseLearningStoreProvider.overrideWithValue(v2Store),
  courseLearningStateProvider.overrideWith((ref) async => v2State),
  learningAuthScopeProvider.overrideWith((ref) => fixture.tracker),
  comparisonCatalogueProvider.overrideWithValue(fixture.catalogue),
  comparisonLearningStoreProvider.overrideWithValue(fixture.store),
];

CourseLearningState _nonemptyV2State() {
  const userId = 'progress-v2-user';
  final scope = LearningScope(
    courseId: 'en-fr',
    owner: LearningOwner.account(userId),
  );
  final registry = LearningRegistry.french();
  final activity = registry.require('lesson:en-fr-vowels');
  final item = activity.items.firstWhere(
    (candidate) => candidate.targetSounds.contains('i'),
  );
  final mistakeKey = MistakeKey(
    activityId: activity.id,
    itemId: item.id,
    contentRevision: activity.contentRevision,
    skill: LearningSkill.listening,
    targetSound: 'i',
  );
  return CourseLearningState(
    scope: scope,
    revision: 2,
    commitOrdinal: 1,
    history: const [],
    activities: const {},
    mistakes: {
      mistakeKey: LearningMistake(
        key: mistakeKey,
        firstWrongId: 'wrong-v2-first',
        firstWrongAt: DateTime.utc(2026, 10, 16),
        latestWrongId: 'wrong-v2-latest',
        latestWrongAt: DateTime.utc(2026, 10, 17),
        failureCount: 2,
        lastRunGeneration: 1,
      ),
    },
    summaries: {
      SummaryKey(
        sound: 'i',
        skill: LearningSkill.listening,
        origin: AttemptOrigin.practice,
        presentation: AttemptPresentation.firstInRun,
        assistance: const {},
      ): SkillCount(
        total: 2,
        correct: 1,
      ),
    },
    completions: const [],
    bestScores: const {'arcade:sound': 37, 'arcade:word': 19},
    pending: [
      SupportedCloudEvent(
        id: 'pending-v2-progress',
        userId: userId,
        courseId: 'en-fr',
        payload: CloudAnswer(
          sound: 'i',
          skill: LearningSkill.listening,
          correct: true,
          activity: activity.id,
        ),
      ),
    ],
  );
}
