import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/learning_storage_types.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_store.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_command_codec.dart';
import 'package:linguist/src/core/course/storage/sentence_hunt_learning_sql_repository.dart';
import 'package:linguist/src/features/course/sentence_hunt_progress_section.dart';
import 'package:linguist/src/features/course/sentence_hunt_progress_summary.dart';
import 'package:linguist/src/features/course_map/course_map_screen.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt_lesson_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/course_learning_widget_store.dart';
import '../support/sentence_hunt_fixtures.dart';
import '../support/sentence_hunt_harness.dart';
import '../support/sqlite_learning_test_harness.dart';

void main() {
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'}),
  );

  testWidgets('loading_sentence_progress_stays_unknown_until_state_loads', (
    tester,
  ) async {
    final Completer<SentenceHuntState> pendingState =
        Completer<SentenceHuntState>();
    final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learningAuthScopeProvider.overrideWith(
            (ref) => LearningAuthTracker(owner: scope.owner, ready: true),
          ),
          sentenceHuntCatalogueProvider.overrideWith(
            (ref) async => syntheticSentenceCatalogue(),
          ),
          sentenceHuntLearningStateProvider.overrideWith(
            (ref) => pendingState.future,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SentenceHuntProgressSection()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sentence progress is loading.'), findsOneWidget);
    expect(find.text('Sentence sections completed: 0/3'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    pendingState.complete(SentenceHuntState.empty(scope));
    await tester.pumpAndSettle();
    expect(find.text('Sentence sections completed: 0/3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('reopened_sentence_run_restores_no_playback_or_hearing_grants', (
    tester,
  ) async {
    final tempDir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('sentence-reopen-'),
    ))!;
    final file = File('${tempDir.path}/phoneme_learning.sqlite');
    final catalogue = syntheticSentenceCatalogue();
    final scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    final tracker = LearningAuthTracker(owner: scope.owner, ready: true);
    final seedHandle = LearningDatabaseHandle(
      open: () => openFileLearningTestDatabase(file),
    );
    final seedContainer = ProviderContainer(
      overrides: [
        learningAuthScopeProvider.overrideWith((ref) => tracker),
        learningDatabaseHandleProvider.overrideWithValue(seedHandle),
        sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
      ],
    );
    final seedStore = await seedContainer.read(
      sentenceHuntLearningStoreProvider.future,
    );
    final empty = await seedStore.load();
    await seedStore.submit(
      seedStore.prepare(
        state: empty,
        sectionId: fixtureSectionIds.first,
        action: StartSentenceHuntRun(
          sessionId: 'reopened-sentence-run',
          policy: catalogue.section(fixtureSectionIds.first).policy,
          mode: SentenceHuntRunMode.practice,
        ),
      ),
    );
    seedContainer.dispose();
    await seedHandle.close();

    final audio = ControlledSentenceHuntAudio();
    final handle = LearningDatabaseHandle(
      open: () => openFileLearningTestDatabase(file),
    );
    final container = ProviderContainer(
      overrides: [
        learningAuthScopeProvider.overrideWith(
          (ref) => LearningAuthTracker(owner: scope.owner, ready: true),
        ),
        learningDatabaseHandleProvider.overrideWithValue(handle),
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
        sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
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
    final router = _routerFromMap(tester);
    router.go('/course-sentence-hunt/${fixtureSectionIds.first}');
    await tester.pumpAndSettle();

    expect(find.byType(SentenceHuntLessonScreen), findsOneWidget);
    expect(find.textContaining('Listen to the sentence'), findsOneWidget);
    expect(
      audio.requests,
      isEmpty,
      reason: 'reopening a saved checkpoint must not autoplay its recording',
    );
    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit answer'),
    );
    expect(
      submit.onPressed,
      isNull,
      reason: 'a hearing grant must be earned again after reopening',
    );
    expect(find.textContaining('Microphone'), findsNothing);
    expect(find.textContaining('timer'), findsNothing);
  });

  testWidgets('sentence_progress_retry_is_reachable_at_large_text_scales', (
    tester,
  ) async {
    for (final double scale in <double>[2, 3]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.guest(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learningAuthScopeProvider.overrideWith(
              (ref) => LearningAuthTracker(owner: scope.owner, ready: true),
            ),
            sentenceHuntCatalogueProvider.overrideWith(
              (ref) async => syntheticSentenceCatalogue(),
            ),
            sentenceHuntLearningStateProvider.overrideWith((ref) async {
              throw const FormatException('synthetic unavailable progress');
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: const <Widget>[
                  SizedBox(height: 1000),
                  SentenceHuntProgressSection(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Finder retry = find.text('Retry sentence progress');
      await tester.scrollUntilVisible(
        retry,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(retry, findsOneWidget);
      await tester.pumpAndSettle();
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      expect(
        retry.hitTestable(),
        findsOneWidget,
        reason: 'sentence progress retry stays reachable at $scale× scale',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('home_offers_additive_sentence_sound_hunt_entry', (tester) async {
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
          sentenceHuntLearningStateProvider.overrideWith(
            (ref) async => SentenceHuntLearningState.empty(
              SentenceHuntProfileScope(
                courseId: 'en-fr',
                owner: LearningOwner.guest(),
              ),
            ),
          ),
          sentenceHuntCatalogueProvider.overrideWith(
            (ref) async => syntheticSentenceCatalogue(reviewed: false),
          ),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CourseMapScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('destination-picker')));
    await tester.pumpAndSettle();
    final sentenceStation = find.widgetWithText(ListTile, 'Sentence practice');
    expect(sentenceStation, findsOneWidget);
    await tester.ensureVisible(sentenceStation);
    await tester.pumpAndSettle();
    await tester.tap(sentenceStation);
    await tester.pumpAndSettle();
    final viewSections = find.text('View sections');
    expect(viewSections, findsOneWidget);
    await tester.ensureVisible(viewSections);
    await tester.pumpAndSettle();
    expect(viewSections.hitTestable(), findsOneWidget);
    await tester.tap(viewSections);
    await tester.pumpAndSettle();
    expect(find.text('Sentence sections'), findsOneWidget);
  });

  testWidgets('pending_sections_stay_visible_and_do_not_start', (tester) async {
    final catalogue = syntheticSentenceCatalogue(reviewed: false);
    var storeFactories = 0;
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
          sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
          sentenceHuntLearningStateProvider.overrideWith(
            (ref) async => SentenceHuntLearningState.empty(
              SentenceHuntProfileScope(
                courseId: 'en-fr',
                owner: LearningOwner.guest(),
              ),
            ),
          ),
          sentenceHuntLearningStoreProvider.overrideWith((ref) async {
            storeFactories++;
            throw StateError('pending sections must not acquire a store');
          }),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = _routerFromMap(tester);
    router.go('/course-sentence-hunt');
    await tester.pumpAndSettle();
    expect(find.text('Sentence sections'), findsOneWidget);
    expect(find.text('Vowels'), findsOneWidget);
    expect(find.text('Consonants'), findsOneWidget);
    expect(find.text('Mixed review'), findsOneWidget);
    expect(find.text('Sentence sections completed: 0/3'), findsOneWidget);
    expect(find.text('Unavailable'), findsNWidgets(3));
    expect(find.text('5 items'), findsNWidgets(3));
    expect(find.textContaining('not yet available'), findsNWidgets(3));
    expect(
      find.text(
        'Content not yet available: French/audio or rights review is pending.',
      ),
      findsNWidgets(3),
    );
    expect(find.textContaining('Start '), findsNothing);
    expect(storeFactories, 0);
  });

  testWidgets('available_section_runs_while_pending_siblings_stay_local', (
    tester,
  ) async {
    final catalogue = _catalogueWithVowelsOnlyAvailable();
    expect(catalogue.isAvailable(fixtureSectionIds[0]), isTrue);
    expect(catalogue.isAvailable(fixtureSectionIds[1]), isFalse);
    expect(catalogue.isAvailable(fixtureSectionIds[2]), isFalse);

    final audio = ControlledSentenceHuntAudio();
    final scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    final auth = LearningAuthTracker(owner: scope.owner, ready: true);
    final store = _InMemorySentenceHuntStore(
      scope: scope,
      catalogue: catalogue,
    );
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
          learningAuthScopeProvider.overrideWith((ref) => auth),
          sentenceHuntLearningStoreProvider.overrideWith((ref) async => store),
          sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
          courseReferenceAudioProvider.overrideWithValue(audio),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LinguistApp)),
    );
    container.read(courseLearningStateProvider);
    container.read(comparisonLearningStateProvider);
    container.read(sentenceHuntLearningStateProvider);
    container.read(sentenceHuntCatalogueProvider);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => container.read(sentenceHuntLearningStateProvider.future),
    );
    await tester.pumpAndSettle();

    final router = _routerFromMap(tester);
    router.go('/course-sentence-hunt');
    await tester.pumpAndSettle();
    expect(find.text('Start Vowels'), findsOneWidget);
    expect(find.text('Unavailable'), findsNWidgets(2));
    expect(find.text('Start Consonants'), findsNothing);
    expect(find.text('Start Mixed review'), findsNothing);

    router.go('/course-sentence-hunt/${fixtureSectionIds[1]}');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('unavailable until its content and audio'),
      findsOneWidget,
    );
    expect(find.byType(SentenceHuntLessonScreen), findsNothing);

    router.go('/course-sentence-hunt/${fixtureSectionIds[0]}');
    await tester.pumpAndSettle();
    expect(find.byType(SentenceHuntLessonScreen), findsOneWidget);
    await _answerUiItem(
      tester,
      audio,
      catalogue,
      fixtureSectionIds[0],
      fixtureItemIds[0][0],
      correct: true,
    );
    expect(find.text('Correct'), findsOneWidget);
    expect(store.state.slots.containsKey(fixtureSectionIds[0]), isTrue);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('sentence_hunt_routes_reject_invalid_queries_before_acquisition', (
    tester,
  ) async {
    final catalogue = syntheticSentenceCatalogue(reviewed: false);
    var catalogueFactories = 0;
    var storeFactories = 0;
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
          sentenceHuntCatalogueProvider.overrideWith((ref) async {
            catalogueFactories++;
            return catalogue;
          }),
          sentenceHuntLearningStateProvider.overrideWith(
            (ref) async => SentenceHuntLearningState.empty(
              SentenceHuntProfileScope(
                courseId: 'en-fr',
                owner: LearningOwner.guest(),
              ),
            ),
          ),
          sentenceHuntLearningStoreProvider.overrideWith((ref) async {
            storeFactories++;
            throw StateError('invalid routes must not acquire a store');
          }),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = _routerFromMap(tester);
    final int catalogueCountBeforeInvalidRoutes = catalogueFactories;
    for (final uri in <String>[
      '/course-sentence-hunt?review=true',
      '/course-sentence-hunt?unknown=x',
      '/course-sentence-hunt/not-a-section',
      '/course-sentence-hunt/en-fr-sentence-hunt-vowels?review=maybe',
      '/course-sentence-hunt/en-fr-sentence-hunt-vowels?review=',
      '/course-sentence-hunt/en-fr-sentence-hunt-vowels?review=True',
      '/course-sentence-hunt/en-fr-sentence-hunt-vowels?review=true&review=false',
      '/course-sentence-hunt/en-fr-sentence-hunt-vowels?itemId=',
      '/course-sentence-hunt/en-fr-sentence-hunt-vowels?itemId=fr08-vowel-01&itemId=fr08-vowel-02',
      '/course-sentence-hunt/en-fr-sentence-hunt-vowels?itemId=unknown',
      '/course-sentence-hunt/en-fr-sentence-hunt-vowels?itemId=fr08-consonant-01',
      '/course-sentence-hunt/en-fr-sentence-hunt-vowels?extra=x',
    ]) {
      router.go(uri);
      await tester.pumpAndSettle();
      expect(
        find.text('This sentence-hunt route is unavailable.'),
        findsOneWidget,
        reason: uri,
      );
      expect(
        catalogueFactories,
        catalogueCountBeforeInvalidRoutes,
        reason:
            'invalid route must be rejected before content acquisition: $uri',
      );
      expect(
        storeFactories,
        0,
        reason: 'invalid route must be rejected before store acquisition: $uri',
      );
    }
  });

  testWidgets('valid_item_route_keeps_exact_section_and_item_intent', (
    tester,
  ) async {
    final catalogue = syntheticSentenceCatalogue();
    var storeFactories = 0;
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
          sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
          sentenceHuntLearningStateProvider.overrideWith(
            (ref) async => SentenceHuntLearningState.empty(
              SentenceHuntProfileScope(
                courseId: 'en-fr',
                owner: LearningOwner.guest(),
              ),
            ),
          ),
          sentenceHuntLearningStoreProvider.overrideWith((ref) async {
            storeFactories++;
            throw StateError(
              'accepted content test store is intentionally absent',
            );
          }),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = _routerFromMap(tester);
    const path =
        '/course-sentence-hunt/en-fr-sentence-hunt-vowels?review=false&itemId=fr08-vowel-01';
    router.go(path);
    await tester.pumpAndSettle();
    expect(find.byType(SentenceHuntLessonScreen), findsOneWidget);
    expect(
      GoRouterState.of(
        tester.element(find.byType(SentenceHuntLessonScreen)),
      ).uri.toString(),
      path,
    );
    expect(
      find.textContaining('unavailable until its content and audio'),
      findsNothing,
    );
    expect(storeFactories, 1);
  });

  testWidgets('pending_item_route_stays_local_before_store_acquisition', (
    tester,
  ) async {
    final catalogue = syntheticSentenceCatalogue(reviewed: false);
    var storeFactories = 0;
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
          sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
          sentenceHuntLearningStateProvider.overrideWith(
            (ref) async => SentenceHuntLearningState.empty(
              SentenceHuntProfileScope(
                courseId: 'en-fr',
                owner: LearningOwner.guest(),
              ),
            ),
          ),
          sentenceHuntLearningStoreProvider.overrideWith((ref) async {
            storeFactories++;
            throw StateError('pending content must not acquire a store');
          }),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = _routerFromMap(tester);
    const path =
        '/course-sentence-hunt/en-fr-sentence-hunt-vowels?review=false&itemId=fr08-vowel-01';
    router.go(path);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.toString(), path);
    expect(
      find.textContaining('unavailable until its content and audio'),
      findsOneWidget,
    );
    expect(find.byType(SentenceHuntLessonScreen), findsNothing);
    expect(find.text('Start'), findsNothing);
    expect(storeFactories, 0);
  });

  testWidgets('sentence_retry_is_fenced_across_owner_A_to_B_to_A', (
    tester,
  ) async {
    final catalogue = syntheticSentenceCatalogue();
    final auth = LearningAuthTracker(owner: LearningOwner.guest(), ready: true);
    final scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    final store = _HeldSentenceStore(scope);
    var stateLoads = 0;
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
          learningAuthScopeProvider.overrideWith((ref) => auth),
          sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
          sentenceHuntLearningStoreProvider.overrideWith((ref) async => store),
          sentenceHuntLearningStateProvider.overrideWith((ref) async {
            ref.watch(learningAuthScopeProvider);
            stateLoads++;
            throw StateError('sentence state unavailable');
          }),
        ],
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Progress'));
    await tester.pumpAndSettle();
    expect(
      GoRouter.of(
        tester.element(find.byType(NavigationBar)),
      ).routeInformationProvider.value.uri.path,
      '/course-progress',
      reason: 'the retry is exercised in the real Progress root route',
    );
    await tester.scrollUntilVisible(
      find.text('Retry sentence progress'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    final retry = find.text('Retry sentence progress');
    expect(retry, findsOneWidget);
    await tester.pumpAndSettle();
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    final retryRect = tester.getRect(retry);
    final navigationRect = tester.getRect(find.byType(NavigationBar));
    expect(
      retryRect.bottom,
      lessThanOrEqualTo(navigationRect.top),
      reason: 'sentence retry must remain above the root navigation bar',
    );
    expect(
      retry.hitTestable(),
      findsOneWidget,
      reason: 'sentence retry has current visible geometry after scrolling',
    );
    await tester.tap(retry);
    await tester.pump();
    await tester.runAsync(() => store.retryEntered.future);

    auth.observe(owner: LearningOwner.account('owner-b'), ready: true);
    await tester.pump();
    auth.observe(owner: LearningOwner.guest(), ready: true);
    await tester.pumpAndSettle();
    expect(
      find.text('Retry sentence progress'),
      findsOneWidget,
      reason: 'the current owner can recover while the earlier retry is held',
    );
    final loadsForReturnedOwner = stateLoads;

    store.releaseRetry();
    await tester.runAsync(() => store.retryFinished.future);
    await tester.pumpAndSettle();
    expect(
      stateLoads,
      loadsForReturnedOwner,
      reason: 'the stale retry must not invalidate the A-again provider',
    );
    expect(
      find.text('Retry sentence progress'),
      findsOneWidget,
      reason: 'stale finally must not clear or overwrite current-owner UI',
    );
    expect(store.retryCalls, 1);
  });

  testWidgets('sentence_finish_ack_publishes_current_provider_once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
    );

    await _exerciseCorruptSentenceRecovery(tester);

    final catalogue = syntheticSentenceCatalogue();
    final scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    final fixture = await _newSqliteSentenceFixture(tester);
    final LearningDatabase observerDb = await openFileLearningTestDatabase(
      fixture.file,
    );
    final audio = ControlledSentenceHuntAudio();
    final auth = LearningAuthTracker(owner: scope.owner, ready: true);
    late ProviderContainer container;
    var tokenNumber = 0;
    final SqliteSentenceHuntLearningRepository repository =
        SqliteSentenceHuntLearningRepository(
          database: fixture.handle,
          scope: scope,
          authGeneration: 0,
          currentAuth: () => auth.current,
          backendOwner: () => LearningOwner.guest(),
          transitions: SentenceHuntTransitionEngine(catalogue: catalogue),
          clock: () => DateTime.utc(2026, 10, 19),
          newToken: () => (++tokenNumber).toString().padLeft(22, '0'),
          onCommitted: () =>
              container.invalidate(sentenceHuntLearningStateProvider),
        );
    final _RecordingSentenceHuntStore recordingStore =
        _RecordingSentenceHuntStore(repository);
    container = ProviderContainer(
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
        learningAuthScopeProvider.overrideWith((ref) => auth),
        learningDatabaseHandleProvider.overrideWithValue(fixture.handle),
        sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
        sentenceHuntLearningStoreProvider.overrideWith(
          (ref) async => recordingStore,
        ),
        courseReferenceAudioProvider.overrideWithValue(audio),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await observerDb.close();
      await fixture.close();
      courseBackend = null;
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LinguistApp(),
      ),
    );
    await tester.pump();
    container.read(courseLearningStateProvider);
    container.read(comparisonLearningStateProvider);
    container.read(sentenceHuntLearningStateProvider);
    container.read(sentenceHuntCatalogueProvider);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => container.read(sentenceHuntLearningStateProvider.future),
    );
    await tester.pumpAndSettle();

    final router = _routerFromMap(tester);
    router.go('/course-sentence-hunt/en-fr-sentence-hunt-vowels');
    await tester.pumpAndSettle();
    expect(find.byType(SentenceHuntLessonScreen), findsOneWidget);
    final sectionId = fixtureSectionIds.first;
    final items = catalogue.section(sectionId).items;
    for (var index = 0; index < items.length; index++) {
      await _answerUiItem(
        tester,
        audio,
        catalogue,
        sectionId,
        items[index].identity.itemId,
        correct: index != items.length - 1,
      );
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    expect(find.text('You got 4 of 5 correct.'), findsOneWidget);
    final SentenceHuntState beforeFinish = (await tester.runAsync(
      () => container.read(sentenceHuntLearningStateProvider.future),
    ))!;
    final Map<String, int> countsBeforeFinish = await _sentenceTableCounts(
      observerDb,
      scope,
    );
    final Map<String, List<Map<String, Object?>>> sqlRowsBeforeFinish =
        await _sentenceScopedRowSnapshots(observerDb, scope);
    final int revisionBeforeFinish = await _sentenceScopeRevision(
      observerDb,
      scope,
    );
    expect(beforeFinish.revision, revisionBeforeFinish);
    expect(beforeFinish.completions, isEmpty);
    expect(
      SentenceHuntProgressSummary.fromState(
        state: beforeFinish,
        catalogue: catalogue,
      ).completedSectionCount,
      0,
    );

    for (final scale in <double>[2, 3]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Finish'));
      expect(
        find.text('Finish').hitTestable(),
        findsOneWidget,
        reason: 'Finish stays reachable at $scale× text scale',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'debrief remains usable at $scale× text scale',
      );
    }

    var finishPublicationCount = 0;
    var sentenceProviderNotificationCount = 0;
    final publication = container.listen(sentenceHuntLearningStateProvider, (
      previous,
      next,
    ) {
      sentenceProviderNotificationCount++;
      if (next.asData?.value.revision == beforeFinish.revision + 1) {
        finishPublicationCount++;
      }
    });
    addTearDown(publication.close);
    final _SqliteWriteGate failedFinishGate = fixture.interceptor
        .holdNextLearningWrite(fail: true);
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.runAsync(() => failedFinishGate.entered.future);
    await tester.pump();
    expect(find.byType(SentenceHuntLessonScreen), findsOneWidget);
    _expectSentenceSqlSnapshotsEqual(
      sqlRowsBeforeFinish,
      await _sentenceScopedRowSnapshots(observerDb, scope),
      reason: 'a held failed Finish leaves saved SQL row values unchanged',
    );
    expect(await _sentenceTableCounts(observerDb, scope), countsBeforeFinish);
    expect(
      await _sentenceScopeRevision(observerDb, scope),
      revisionBeforeFinish,
    );
    expect(finishPublicationCount, 0);
    expect(
      container.read(sentenceHuntLearningStateProvider).asData?.value.revision,
      revisionBeforeFinish,
      reason: 'a failed SQL transaction does not publish a Finish candidate',
    );
    final SentenceHuntCommand failedFinishCommand =
        recordingStore.submittedCommands.last;
    failedFinishGate.release();
    await tester.runAsync(() => failedFinishGate.completed.future);
    await tester.pumpAndSettle();
    expect(find.text('Retry saving'), findsOneWidget);
    _expectSentenceSqlSnapshotsEqual(
      sqlRowsBeforeFinish,
      await _sentenceScopedRowSnapshots(observerDb, scope),
      reason: 'failed Finish preserves every previously saved SQL row value',
    );
    expect(
      await _sentenceTableCounts(observerDb, scope),
      countsBeforeFinish,
      reason: 'failed Finish leaves every scoped SQL relation unchanged',
    );
    expect(
      await _sentenceScopeRevision(observerDb, scope),
      revisionBeforeFinish,
    );
    expect(finishPublicationCount, 0);

    for (final scale in <double>[2, 3]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retry saving'));
      expect(
        find.text('Retry saving').hitTestable(),
        findsOneWidget,
        reason: 'Finish retry stays reachable at $scale× text scale',
      );
    }
    fixture.interceptor.holdNextCommit();
    await tester.tap(find.text('Retry saving'));
    await tester.pump();
    await tester.runAsync(() => fixture.interceptor.commitEntered);
    final SentenceHuntCommand retryCommand =
        recordingStore.submittedCommands.last;
    _expectFinishRetryCommandsMatch(
      beforeFinish: beforeFinish,
      failedCommand: failedFinishCommand,
      retryCommand: retryCommand,
      scope: scope,
      sectionId: sectionId,
    );
    final SentenceHuntState finishCandidate =
        SentenceHuntTransitionEngine(catalogue: catalogue)
            .evaluate(
              state: beforeFinish,
              command: retryCommand,
              committedAt: retryCommand.submittedAt,
            )
            .nextState;
    expect(finishCandidate.revision, beforeFinish.revision + 1);
    expect(finishCandidate.completions, hasLength(1));
    expect(finishPublicationCount, 0);
    expect(
      container.read(sentenceHuntLearningStateProvider).asData?.value.revision,
      revisionBeforeFinish,
      reason: 'the provider keeps its acknowledged snapshot until SQL ACK',
    );
    expect(
      await _sentenceScopeRevision(observerDb, scope),
      revisionBeforeFinish + 1,
      reason: 'the commit is durable before its provider ACK callback',
    );
    final Map<String, List<Map<String, Object?>>> sqlRowsAfterDurableCommit =
        await _sentenceScopedRowSnapshots(observerDb, scope);
    _expectPriorSentenceSqlRowsPreserved(
      sqlRowsBeforeFinish,
      sqlRowsAfterDurableCommit,
      reason: 'Finish preserves values in every pre-existing SQL row',
    );
    await _expectNewFinishSqlValues(
      db: observerDb,
      scope: scope,
      rows: sqlRowsAfterDurableCommit,
      expectedReceipt: finishCandidate.slots[sectionId]!.latestReceipt,
      expectedCompletion: finishCandidate.completions.single,
      expectedCommand: retryCommand,
    );
    expect(await _sentenceCompletionCount(observerDb, scope), 1);
    final Map<String, int> countsAfterDurableCommit =
        await _sentenceTableCounts(observerDb, scope);
    for (final String table in <String>[
      'learning_attempts',
      'learning_attempt_values',
      'learning_attempt_evidence',
      'learning_mistakes',
      'learning_summaries',
      'learning_exposure',
    ]) {
      expect(
        countsAfterDurableCommit[table],
        countsBeforeFinish[table],
        reason: 'Finish does not rewrite previously saved $table',
      );
    }

    fixture.interceptor.releaseCommit();
    await tester.runAsync(() => fixture.interceptor.commitCompleted);
    await tester.pumpAndSettle();
    final SentenceHuntState publishedState = (await tester.runAsync(
      () => container.read(sentenceHuntLearningStateProvider.future),
    ))!;
    await tester.pumpAndSettle();
    expect(
      publishedState.revision,
      beforeFinish.revision + 1,
      reason: 'the actual provider refresh follows the persistence ACK',
    );
    expect(
      finishPublicationCount,
      1,
      reason: 'the real repository publishes its ACKed Finish once',
    );
    final SentenceHuntState afterFinish = publishedState;
    expect(
      _sentenceHuntStateValues(afterFinish),
      _sentenceHuntStateValues(finishCandidate),
      reason: 'reloaded Finish state matches every typed transition value',
    );
    _expectPriorSentenceHuntValuesPreserved(beforeFinish, afterFinish);
    final SentenceHuntCompletion expectedCompletion =
        finishCandidate.completions.single;
    final SentenceHuntCompletion actualCompletion =
        afterFinish.completions.single;
    expect(actualCompletion.scope, expectedCompletion.scope);
    expect(actualCompletion.sectionId, expectedCompletion.sectionId);
    expect(
      actualCompletion.contentRevision,
      expectedCompletion.contentRevision,
    );
    expect(actualCompletion.policyRevision, expectedCompletion.policyRevision);
    expect(
      actualCompletion.thresholdPercent,
      expectedCompletion.thresholdPercent,
    );
    expect(actualCompletion.committedAt, expectedCompletion.committedAt);
    expect(
      SentenceHuntProgressSummary.fromState(
        state: afterFinish,
        catalogue: catalogue,
      ).completedSectionCount,
      1,
    );

    final SentenceHuntReceipt finishReceipt =
        afterFinish.slots[sectionId]!.latestReceipt;
    final SentenceHuntCommand duplicateFinish = retryCommand;
    expect(
      SentenceHuntCommandCodec.legacyCanonicalCommand(duplicateFinish),
      finishReceipt.canonicalCommand,
    );
    final SentenceHuntLearningStore store = (await tester.runAsync(
      () => container.read(sentenceHuntLearningStoreProvider.future),
    ))!;
    final Map<String, int> countsBeforeDuplicate = await _sentenceTableCounts(
      observerDb,
      scope,
    );
    final int revisionBeforeDuplicate = await _sentenceScopeRevision(
      observerDb,
      scope,
    );
    final int notificationsBeforeDuplicate = sentenceProviderNotificationCount;
    final SentenceHuntCommit duplicateResult = await store.submit(
      duplicateFinish,
    );
    await tester.pumpAndSettle();
    expect(duplicateResult.duplicate, isTrue);
    expect(
      await _sentenceTableCounts(observerDb, scope),
      countsBeforeDuplicate,
      reason: 'an acknowledged duplicate Finish performs no SQL write',
    );
    expect(
      await _sentenceScopeRevision(observerDb, scope),
      revisionBeforeDuplicate,
    );
    expect(
      sentenceProviderNotificationCount,
      notificationsBeforeDuplicate,
      reason: 'an acknowledged duplicate Finish publishes no refresh',
    );
    expect(finishPublicationCount, 1);
    final Map<String, List<Map<String, Object?>>> sqlRowsBeforeDuplicateCheck =
        await _sentenceScopedRowSnapshots(observerDb, scope);
    _expectSentenceSqlSnapshotsEqual(
      sqlRowsAfterDurableCommit,
      sqlRowsBeforeDuplicateCheck,
      reason: 'duplicate Finish has not altered any scoped SQL row values',
    );

    // A count-preserving timestamp mutation must fail the same complete value
    // comparison used above; restore the durable row immediately afterward.
    final int scopeId = await _sentenceScopeId(observerDb, scope);
    final int expectedCommittedAtUs =
        expectedCompletion.committedAt.microsecondsSinceEpoch;
    await observerDb.customStatement(
      'UPDATE learning_completions SET committed_at_us = committed_at_us + 1 '
      'WHERE scope_id = ? AND activity_id = ? AND content_revision = ?',
      <Object?>[
        scopeId,
        expectedCompletion.sectionId,
        expectedCompletion.contentRevision,
      ],
    );
    expect(await _sentenceCompletionCount(observerDb, scope), 1);
    try {
      final SentenceHuntState mutatedState = await store.load();
      expect(
        _sentenceHuntStateValues(mutatedState),
        isNot(equals(_sentenceHuntStateValues(finishCandidate))),
        reason: 'a count-preserving completion timestamp mutation is detected',
      );
    } finally {
      await observerDb.customStatement(
        'UPDATE learning_completions SET committed_at_us = ? '
        'WHERE scope_id = ? AND activity_id = ? AND content_revision = ?',
        <Object?>[
          expectedCommittedAtUs,
          scopeId,
          expectedCompletion.sectionId,
          expectedCompletion.contentRevision,
        ],
      );
    }
    expect(
      _sentenceHuntStateValues(await store.load()),
      _sentenceHuntStateValues(finishCandidate),
      reason: 'the timestamp mutation control restores the original SQL row',
    );
    _expectSentenceSqlSnapshotsEqual(
      sqlRowsBeforeDuplicateCheck,
      await _sentenceScopedRowSnapshots(observerDb, scope),
      reason: 'the timestamp mutation control leaves no persisted change',
    );

    router.go('/home');
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => container.read(courseLearningStateProvider.future),
    );
    await tester.runAsync(
      () => container.read(sentenceHuntLearningStateProvider.future),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CourseMapScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('destination-picker')));
    await tester.pumpAndSettle();
    final sentenceStation = find.widgetWithText(ListTile, 'Sentence practice');
    expect(sentenceStation, findsOneWidget);
    await tester.ensureVisible(sentenceStation);
    await tester.pumpAndSettle();
    await tester.tap(sentenceStation);
    await tester.pumpAndSettle();
    final openSections = find.text('Open destination');
    expect(openSections, findsOneWidget);
    await tester.ensureVisible(openSections);
    await tester.pumpAndSettle();
    expect(openSections.hitTestable(), findsOneWidget);
    await tester.tap(openSections);
    await tester.pumpAndSettle();
    expect(find.text('Sentence sections'), findsOneWidget);
    router.go('/course-progress');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sentence sections completed: 1/3'),
      160,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
    expect(find.text('Sentence sections completed: 1/3'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Discovery lessons: 0/1 complete'),
      -160,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
    expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
    expect(
      find.text('Existing lessons (includes discovery pilot): 0/5 complete'),
      findsOneWidget,
    );

    const mistakeLabel = 'Sentence item fr08-vowel-05';
    for (final scale in <double>[2, 3]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(mistakeLabel),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text(mistakeLabel));
      await tester.pumpAndSettle();
      expect(
        find.text(mistakeLabel).hitTestable(),
        findsOneWidget,
        reason: 'mistake link stays reachable at $scale× text scale',
      );
    }
    await tester.tap(find.text(mistakeLabel));
    await tester.pumpAndSettle();
    final mistakeUri = GoRouterState.of(
      tester.element(find.byType(SentenceHuntLessonScreen)),
    ).uri;
    expect(mistakeUri.path, '/course-sentence-hunt/$sectionId');
    expect(mistakeUri.queryParameters, <String, String>{
      'review': 'true',
      'itemId': 'fr08-vowel-05',
    });
    expect(
      find.bySemanticsLabel('Word 1 of 5: Vous'),
      findsOneWidget,
      reason: 'the review link opens the exact saved mistake item',
    );
  });

  testWidgets(
    'sentence_progress_retry_does_not_duplicate_pending_acquisition',
    (tester) async {
      final SentenceHuntCatalogue catalogue = syntheticSentenceCatalogue();
      final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.guest(),
      );
      final Completer<SentenceHuntLearningStore> pendingAcquisition =
          Completer<SentenceHuntLearningStore>();
      final _HeldSentenceStore store = _HeldSentenceStore(scope)
        ..releaseRetry();
      var storeFactories = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learningAuthScopeProvider.overrideWith(
              (ref) => LearningAuthTracker(
                owner: LearningOwner.guest(),
                ready: true,
              ),
            ),
            sentenceHuntCatalogueProvider.overrideWith(
              (ref) async => catalogue,
            ),
            sentenceHuntLearningStoreProvider.overrideWith((ref) async {
              storeFactories++;
              return pendingAcquisition.future;
            }),
            sentenceHuntLearningStateProvider.overrideWith((ref) async {
              throw StateError('synthetic sentence state unavailable');
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SentenceHuntProgressSection()),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Retry sentence progress'), findsOneWidget);
      final TextButton initialRetryButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Retry sentence progress'),
          matching: find.byType(TextButton),
        ),
      );
      final VoidCallback retryAgain = initialRetryButton.onPressed!;

      await tester.tap(find.text('Retry sentence progress'));
      await tester.pumpAndSettle();
      expect(storeFactories, 1);
      expect(find.text('Retrying sentence progress…'), findsOneWidget);
      final TextButton retryButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Retrying sentence progress…'),
          matching: find.byType(TextButton),
        ),
      );
      expect(
        retryButton.onPressed,
        isNull,
        reason: 'a pending acquisition cannot start a second retry',
      );
      retryAgain();
      await tester.pump();
      expect(
        storeFactories,
        1,
        reason: 'a duplicate tap must not reacquire a pending store',
      );

      pendingAcquisition.complete(store);
      await tester.pumpAndSettle();
      await tester.runAsync(() => store.retryFinished.future);
      await tester.pumpAndSettle();
      expect(storeFactories, 1);
      expect(store.retryCalls, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('sentence_retry_disposal_fences_pending_store_acquisition', (
    tester,
  ) async {
    final SentenceHuntCatalogue catalogue = syntheticSentenceCatalogue();
    final LearningAuthTracker auth = LearningAuthTracker(
      owner: LearningOwner.guest(),
      ready: true,
    );
    final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    final Completer<void> acquisitionEntered = Completer<void>();
    final Completer<SentenceHuntLearningStore> acquisition =
        Completer<SentenceHuntLearningStore>();
    final _HeldSentenceStore store = _HeldSentenceStore(scope);
    var storeFactories = 0;
    var stateBuilds = 0;
    final ProviderContainer container = ProviderContainer(
      overrides: [
        learningAuthScopeProvider.overrideWith((ref) => auth),
        sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
        sentenceHuntLearningStoreProvider.overrideWith((ref) async {
          storeFactories++;
          if (storeFactories == 1) {
            throw StateError('initial store acquisition failure');
          }
          acquisitionEntered.complete();
          return acquisition.future;
        }),
        sentenceHuntLearningStateProvider.overrideWith((ref) async {
          stateBuilds++;
          await ref.watch(sentenceHuntLearningStoreProvider.future);
          throw StateError('sentence state remains unavailable');
        }),
      ],
    );
    final ProviderSubscription<AsyncValue<SentenceHuntState>>
    stateSubscription = container.listen(
      sentenceHuntLearningStateProvider,
      (_, __) {},
    );
    addTearDown(() {
      stateSubscription.close();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SentenceHuntProgressSection()),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Sentence progress is unavailable.'), findsOneWidget);
    expect(storeFactories, 1);

    await tester.tap(find.text('Retry sentence progress'));
    await tester.pump();
    await tester.runAsync(() => acquisitionEntered.future);
    await tester.pump();
    expect(storeFactories, 2);
    expect(find.text('Sentence progress is loading.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    final int stateBuildsAtDisposal = stateBuilds;
    acquisition.complete(store);
    await tester.runAsync(() => acquisition.future);
    await tester.pumpAndSettle();

    expect(
      store.retryCalls,
      0,
      reason: 'a disposed retry must not advance into store repair',
    );
    expect(
      stateBuilds,
      stateBuildsAtDisposal,
      reason: 'a disposed retry must not invalidate progress state',
    );
  });

  testWidgets(
    'sentence_progress_retry_reacquires_repeated_failed_store_acquisitions',
    (tester) async {
      final SentenceHuntCatalogue catalogue = syntheticSentenceCatalogue();
      final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.guest(),
      );
      final _HeldSentenceStore store = _HeldSentenceStore(scope)
        ..releaseRetry();
      final Completer<void> pendingAcquisitionEntered = Completer<void>();
      final Completer<SentenceHuntLearningStore> pendingAcquisition =
          Completer<SentenceHuntLearningStore>();
      var storeFactories = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learningAuthScopeProvider.overrideWith(
              (ref) => LearningAuthTracker(
                owner: LearningOwner.guest(),
                ready: true,
              ),
            ),
            sentenceHuntCatalogueProvider.overrideWith(
              (ref) async => catalogue,
            ),
            sentenceHuntLearningStoreProvider.overrideWith((ref) async {
              storeFactories++;
              if (storeFactories < 3) {
                throw StateError('transient store acquisition $storeFactories');
              }
              pendingAcquisitionEntered.complete();
              return pendingAcquisition.future;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SentenceHuntProgressSection()),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Sentence progress is unavailable.'), findsOneWidget);
      expect(storeFactories, 1);

      await tester.tap(find.text('Retry sentence progress'));
      await tester.pumpAndSettle();
      expect(
        storeFactories,
        2,
        reason: 'explicit retry must reacquire after a failed store future',
      );
      expect(find.text('Sentence progress is unavailable.'), findsOneWidget);

      await tester.tap(find.text('Retry sentence progress'));
      await tester.pump();
      await tester.runAsync(() => pendingAcquisitionEntered.future);
      await tester.pump();
      expect(storeFactories, 3);
      expect(
        find.text('Sentence progress is loading.'),
        findsOneWidget,
        reason: 'a pending retry acquisition remains unknown',
      );

      pendingAcquisition.complete(store);
      await tester.runAsync(() => store.retryFinished.future);
      await tester.pumpAndSettle();
      expect(
        storeFactories,
        3,
        reason: 'a successful store acquisition is reused',
      );
      expect(store.retryCalls, 1);
      expect(
        find.text('Sentence sections completed: 0/3'),
        findsOneWidget,
        reason: 'the real state provider loads the reacquired store state',
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

GoRouter _routerFromMap(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(CourseMapScreen)));

SentenceHuntCatalogue _catalogueWithVowelsOnlyAvailable() {
  final SentenceHuntPackageFixture fixture = syntheticSentencePackage().copy();
  final Set<String> pendingItemIds = fixtureItemIds
      .skip(1)
      .expand((List<String> itemIds) => itemIds)
      .toSet();

  for (final dynamic rawSection
      in fixture.manifest['sections'] as List<dynamic>) {
    final Map<String, dynamic> section = rawSection as Map<String, dynamic>;
    for (final dynamic rawItem in section['items'] as List<dynamic>) {
      final Map<String, dynamic> item = rawItem as Map<String, dynamic>;
      if (pendingItemIds.contains(item['id'])) {
        item['reviewState'] = 'pending';
      }
    }
  }
  for (final dynamic rawEntry
      in fixture.annotations['entries'] as List<dynamic>) {
    final Map<String, dynamic> entry = rawEntry as Map<String, dynamic>;
    if (pendingItemIds.contains(entry['itemId'])) {
      _markReviewPending(entry['frenchAudioReview'] as Map<String, dynamic>);
    }
  }
  for (final dynamic rawEntry
      in fixture.provenance['entries'] as List<dynamic>) {
    final Map<String, dynamic> entry = rawEntry as Map<String, dynamic>;
    if (pendingItemIds.contains(entry['itemId'])) {
      _markReviewPending(entry['rightsReview'] as Map<String, dynamic>);
    }
  }

  return decodeFrenchSentencePackage(
    manifestJson: fixture.manifestJson,
    provenanceJson: fixture.provenanceJson,
    annotationsJson: fixture.annotationsJson,
    sourceEvidenceJson: fixture.sourceEvidenceJson,
  );
}

void _markReviewPending(Map<String, dynamic> review) {
  review['status'] = 'pending';
  review['reviewer'] = null;
  review['qualification'] = null;
  review['reviewedAt'] = null;
  review['evidenceIds'] = <String>[];
  review['notes'] = 'Synthetic pending test decision.';
}

Future<void> _exerciseCorruptSentenceRecovery(
  WidgetTester tester, {
  double textScaleFactor = 1,
}) async {
  final SentenceHuntCatalogue catalogue = syntheticSentenceCatalogue();
  final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
    courseId: 'en-fr',
    owner: LearningOwner.guest(),
  );
  final _SqliteSentenceFixture fixture = await _newSqliteSentenceFixture(
    tester,
  );
  final LearningDatabase db = await fixture.handle.open();
  await insertScope(
    db,
    id: 1,
    ownerKind: 'guest',
    ownerId: '',
    courseId: 'en-fr',
    family: 'sentence-hunt',
    schemaVersion: 99,
  );
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
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
        learningAuthScopeProvider.overrideWith(
          (ref) =>
              LearningAuthTracker(owner: LearningOwner.guest(), ready: true),
        ),
        learningDatabaseHandleProvider.overrideWithValue(fixture.handle),
        sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
      ],
      child: const LinguistApp(),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await fixture.close();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Progress'));
  await tester.pumpAndSettle();
  expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
  expect(
    find.text('Existing lessons (includes discovery pilot): 0/5 complete'),
    findsOneWidget,
  );
  await tester.scrollUntilVisible(
    find.text('Comparison practice, not phoneme mastery'),
    160,
    scrollable: find.byType(Scrollable).first,
  );
  expect(find.text('Comparison practice, not phoneme mastery'), findsOneWidget);
  await tester.scrollUntilVisible(
    find.text('Sentence practice, not phoneme mastery'),
    160,
    scrollable: find.byType(Scrollable).first,
  );
  expect(find.text('Sentence practice, not phoneme mastery'), findsOneWidget);
  expect(
    find.textContaining('Sentence progress is unavailable'),
    findsOneWidget,
  );
  await tester.scrollUntilVisible(
    find.text('Retry sentence progress'),
    160,
    scrollable: find.byType(Scrollable).first,
  );
  expect(find.text('Retry sentence progress'), findsOneWidget);
  expect(
    find.text('Retry sentence progress').hitTestable(),
    findsOneWidget,
    reason:
        'sentence progress retry stays reachable at '
        '$textScaleFactor× scale',
  );
  expect(find.text('Retry loading progress'), findsNothing);
  expect(await _sentenceScopeRevision(db, scope), 0);
  final int opensBeforeRetry = fixture.openCalls;
  await tester.ensureVisible(find.text('Retry sentence progress'));
  await tester.tap(find.text('Retry sentence progress'));
  await tester.pumpAndSettle();
  expect(
    fixture.openCalls,
    greaterThan(opensBeforeRetry),
    reason: 'retry must reopen the same configured SQLite handle',
  );
  final LearningDatabase reopenedDb = await fixture.handle.open();
  final int scopeId = await _sentenceScopeId(reopenedDb, scope);
  final int schemaVersion =
      (await reopenedDb
              .customSelect(
                'SELECT schema_version FROM learning_scopes WHERE id = ?',
                variables: <drift.Variable<Object>>[
                  drift.Variable<int>(scopeId),
                ],
              )
              .getSingle())
          .read<int>('schema_version');
  expect(
    schemaVersion,
    99,
    reason: 'retry must not reset or overwrite unsupported stored state',
  );
  expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
  expect(find.text('Comparison practice, not phoneme mastery'), findsOneWidget);
  expect(
    find.text('Retry sentence progress'),
    findsOneWidget,
    reason: 'failed recovery returns to its retryable state',
  );

  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

const List<String> _sentenceFinishUnchangedSqlTables = <String>[
  'learning_content_bindings',
  'learning_attempts',
  'learning_attempt_values',
  'learning_attempt_evidence',
  'learning_mistakes',
  'learning_summaries',
  'learning_exposure',
  'learning_best_scores',
  'supported_sync_outbox',
];

const List<String> _sentenceFinishAppendOnlySqlTables = <String>[
  'learning_command_receipts',
  'learning_completions',
];

Future<Map<String, List<Map<String, Object?>>>> _sentenceScopedRowSnapshots(
  LearningDatabase db,
  SentenceHuntProfileScope scope,
) async {
  final int scopeId = await _sentenceScopeId(db, scope);
  final Map<String, List<Map<String, Object?>>> snapshots =
      <String, List<Map<String, Object?>>>{};
  for (final String table in <String>[
    ..._sentenceFinishUnchangedSqlTables,
    ..._sentenceFinishAppendOnlySqlTables,
  ]) {
    final List<drift.QueryRow> rows = await db
        .customSelect(
          'SELECT rowid AS __rowid, * FROM $table '
          'WHERE scope_id = ? ORDER BY rowid',
          variables: <drift.Variable<Object>>[drift.Variable<int>(scopeId)],
        )
        .get();
    snapshots[table] = rows
        .map((drift.QueryRow row) => Map<String, Object?>.from(row.data))
        .toList();
  }
  return snapshots;
}

void _expectSentenceSqlSnapshotsEqual(
  Map<String, List<Map<String, Object?>>> expected,
  Map<String, List<Map<String, Object?>>> actual, {
  required String reason,
}) {
  expect(actual, expected, reason: reason);
}

void _expectPriorSentenceSqlRowsPreserved(
  Map<String, List<Map<String, Object?>>> before,
  Map<String, List<Map<String, Object?>>> after, {
  required String reason,
}) {
  for (final String table in _sentenceFinishUnchangedSqlTables) {
    expect(after[table], before[table], reason: '$reason: $table');
  }
  for (final String table in _sentenceFinishAppendOnlySqlTables) {
    final List<Map<String, Object?>> priorRows = before[table]!;
    final Set<Object?> priorRowIds = priorRows
        .map((Map<String, Object?> row) => row['__rowid'])
        .toSet();
    final List<Map<String, Object?>> retainedRows = after[table]!
        .where(
          (Map<String, Object?> row) => priorRowIds.contains(row['__rowid']),
        )
        .toList();
    expect(retainedRows, priorRows, reason: '$reason: existing $table values');
    expect(
      after[table],
      hasLength(priorRows.length + 1),
      reason: 'Finish adds exactly one $table row',
    );
  }
}

Future<void> _expectNewFinishSqlValues({
  required LearningDatabase db,
  required SentenceHuntProfileScope scope,
  required Map<String, List<Map<String, Object?>>> rows,
  required SentenceHuntReceipt expectedReceipt,
  required SentenceHuntCompletion expectedCompletion,
  required SentenceHuntCommand expectedCommand,
}) async {
  final int scopeId = await _sentenceScopeId(db, scope);
  final List<Map<String, Object?>> receiptRows =
      rows['learning_command_receipts']!
          .where(
            (Map<String, Object?> row) => row['token'] == expectedReceipt.token,
          )
          .toList();
  expect(receiptRows, hasLength(1));
  final Map<String, Object?> actualReceiptValues = Map<String, Object?>.from(
    receiptRows.single,
  )..remove('__rowid');
  expect(actualReceiptValues, <String, Object?>{
    'scope_id': scopeId,
    'activity_id': expectedReceipt.sectionId,
    'token': expectedReceipt.token,
    'canonical_payload': SentenceHuntCommandCodec.canonicalCommand(
      expectedCommand,
    ),
    'before_generation': expectedReceipt.before.generation,
    'before_sequence': expectedReceipt.before.sequence,
    'before_cursor_revision': expectedReceipt.before.revision,
    'after_generation': expectedReceipt.after.generation,
    'after_sequence': expectedReceipt.after.sequence,
    'after_cursor_revision': expectedReceipt.after.revision,
    'commit_ordinal': expectedReceipt.commitOrdinal,
    'result_activity_id': expectedReceipt.sectionId,
    'result_generation': expectedReceipt.after.generation,
    'result_sequence': expectedReceipt.after.sequence,
    'result_cursor_revision': expectedReceipt.after.revision,
  }, reason: 'the durable retry receipt retains every expected SQL value');

  final List<Map<String, Object?>> completionRows =
      rows['learning_completions']!
          .where(
            (Map<String, Object?> row) =>
                row['activity_id'] == expectedCompletion.sectionId &&
                row['content_revision'] == expectedCompletion.contentRevision,
          )
          .toList();
  expect(completionRows, hasLength(1));
  final Map<String, Object?> actualCompletionValues = Map<String, Object?>.from(
    completionRows.single,
  )..remove('__rowid');
  expect(actualCompletionValues, <String, Object?>{
    'scope_id': scopeId,
    'activity_id': expectedCompletion.sectionId,
    'content_revision': expectedCompletion.contentRevision,
    'policy_kind': 'discoveryThreshold',
    'policy_revision': expectedCompletion.policyRevision,
    'threshold_percent': expectedCompletion.thresholdPercent,
    'committed_at_us': expectedCompletion.committedAt.microsecondsSinceEpoch,
  }, reason: 'the durable completion retains its exact typed metadata');
}

void _expectPriorSentenceHuntValuesPreserved(
  SentenceHuntState before,
  SentenceHuntState after,
) {
  expect(
    after.attempts.map(_sentenceHuntAttemptValues).toList(),
    before.attempts.map(_sentenceHuntAttemptValues).toList(),
    reason: 'Finish preserves every prior attempt value',
  );
  expect(
    _sentenceHuntMistakeValues(after),
    _sentenceHuntMistakeValues(before),
    reason: 'Finish preserves every prior mistake value',
  );
  expect(
    _sentenceHuntSummaryValues(after),
    _sentenceHuntSummaryValues(before),
    reason: 'Finish preserves every prior summary value',
  );
  expect(
    _sentenceHuntExposureValues(after),
    _sentenceHuntExposureValues(before),
    reason: 'Finish preserves every prior teaching-exposure value',
  );
  expect(after.receipts, hasLength(before.receipts.length + 1));
  expect(
    after.receipts
        .take(before.receipts.length)
        .map(_sentenceHuntReceiptValues)
        .toList(),
    before.receipts.map(_sentenceHuntReceiptValues).toList(),
    reason: 'Finish preserves every prior receipt value',
  );
  expect(after.completions, hasLength(before.completions.length + 1));
  expect(
    after.completions
        .take(before.completions.length)
        .map(_sentenceHuntCompletionValues)
        .toList(),
    before.completions.map(_sentenceHuntCompletionValues).toList(),
    reason: 'Finish preserves every prior completion value',
  );
}

List<Object?> _sentenceHuntStateValues(SentenceHuntState state) {
  final List<MapEntry<String, SentenceHuntSlot>> slots =
      state.slots.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  return <Object?>[
    state.schemaVersion,
    _sentenceHuntScopeValues(state.scope),
    state.revision,
    state.commitOrdinal,
    slots
        .map(
          (MapEntry<String, SentenceHuntSlot> entry) => <Object?>[
            entry.key,
            _sentenceHuntCheckpointValues(entry.value.checkpoint),
            _sentenceHuntCursorValues(entry.value.cursor),
            _sentenceHuntReceiptValues(entry.value.latestReceipt),
          ],
        )
        .toList(),
    state.attempts.map(_sentenceHuntAttemptValues).toList(),
    state.receipts.map(_sentenceHuntReceiptValues).toList(),
    _sentenceHuntMistakeValues(state),
    _sentenceHuntSummaryValues(state),
    state.completions.map(_sentenceHuntCompletionValues).toList(),
    _sentenceHuntExposureValues(state),
  ];
}

List<Object?> _sentenceHuntScopeValues(SentenceHuntProfileScope scope) =>
    <Object?>[
      scope.courseId,
      scope.owner.isGuest ? 'guest' : 'account',
      scope.owner.userId,
    ];

List<Object?> _sentenceHuntContentValues(SentenceHuntContentIdentity content) =>
    <Object?>[
      content.sectionId,
      content.itemId,
      content.sentenceId,
      content.audioRefId,
      content.annotationHash,
      content.contentRevision,
      content.annotationRevision,
    ];

String _sentenceHuntContentSortKey(SentenceHuntContentIdentity content) =>
    '${content.sectionId}\u0000${content.itemId}\u0000${content.sentenceId}'
    '\u0000${content.contentRevision}\u0000${content.annotationRevision}';

List<Object?> _sentenceHuntCursorValues(LearningCursorPosition cursor) =>
    <Object?>[cursor.generation, cursor.sequence, cursor.revision];

List<Object?> _sentenceHuntCheckpointValues(
  SentenceHuntCheckpoint checkpoint,
) => <Object?>[
  _sentenceHuntScopeValues(checkpoint.scope),
  checkpoint.sessionId,
  checkpoint.sectionFingerprint,
  checkpoint.contentRevision,
  checkpoint.mode,
  checkpoint.finished,
  checkpoint.policy.completionThresholdPercent,
  checkpoint.sessionJson,
  checkpoint.runStartRound,
];

List<Object?> _sentenceHuntReceiptValues(SentenceHuntReceipt receipt) =>
    <Object?>[
      _sentenceHuntScopeValues(receipt.scope),
      receipt.sectionId,
      receipt.token,
      receipt.canonicalCommand,
      _sentenceHuntCursorValues(receipt.before),
      _sentenceHuntCursorValues(receipt.after),
      receipt.commitOrdinal,
    ];

List<Object?> _sentenceHuntAttemptValues(SentenceHuntAttempt attempt) =>
    <Object?>[
      _sentenceHuntScopeValues(attempt.scope),
      _sentenceHuntContentValues(attempt.content),
      attempt.runGeneration,
      attempt.round,
      attempt.sequence,
      attempt.selectedTokenIds,
      attempt.expectedTokenIds,
      attempt.correct,
      attempt.presentation,
      attempt.teachingExposed,
      <Object?>[
        _sentenceHuntScopeValues(attempt.playback.scope),
        _sentenceHuntContentValues(attempt.playback.content),
        attempt.playback.runGeneration,
        attempt.playback.round,
        attempt.playback.uiGeneration,
        attempt.playback.referenceId,
        attempt.playback.outcome,
        attempt.playback.source,
      ],
      attempt.answeredAt,
      attempt.committedAt,
    ];

List<Object?> _sentenceHuntMistakeValues(SentenceHuntState state) {
  final List<SentenceHuntMistake> mistakes = state.mistakes.values.toList()
    ..sort(
      (a, b) => _sentenceHuntContentSortKey(
        a.content,
      ).compareTo(_sentenceHuntContentSortKey(b.content)),
    );
  return mistakes
      .map(
        (SentenceHuntMistake mistake) => <Object?>[
          _sentenceHuntScopeValues(mistake.scope),
          _sentenceHuntContentValues(mistake.content),
          mistake.firstWrongAt,
          mistake.latestWrongAt,
          mistake.failureCount,
        ],
      )
      .toList();
}

List<Object?> _sentenceHuntSummaryValues(SentenceHuntState state) {
  final List<SentenceHuntSummary> summaries = state.summaries.values.toList()
    ..sort(
      (a, b) => _sentenceHuntContentSortKey(
        a.content,
      ).compareTo(_sentenceHuntContentSortKey(b.content)),
    );
  return summaries
      .map(
        (SentenceHuntSummary summary) => <Object?>[
          _sentenceHuntScopeValues(summary.scope),
          _sentenceHuntContentValues(summary.content),
          <int>[summary.firstInRun.correct, summary.firstInRun.total],
          <int>[summary.repeatInRun.correct, summary.repeatInRun.total],
          <int>[
            summary.firstTeachingExposed.correct,
            summary.firstTeachingExposed.total,
          ],
          <int>[
            summary.repeatTeachingExposed.correct,
            summary.repeatTeachingExposed.total,
          ],
        ],
      )
      .toList();
}

List<Object?> _sentenceHuntCompletionValues(
  SentenceHuntCompletion completion,
) => <Object?>[
  _sentenceHuntScopeValues(completion.scope),
  completion.sectionId,
  completion.contentRevision,
  completion.policyRevision,
  completion.thresholdPercent,
  completion.committedAt,
];

List<Object?> _sentenceHuntExposureValues(SentenceHuntState state) {
  final List<SentenceHuntExposureKey> exposure = state.teachingExposure.toList()
    ..sort((a, b) {
      final int sectionOrder = a.sectionId.compareTo(b.sectionId);
      return sectionOrder != 0
          ? sectionOrder
          : a.contentRevision.compareTo(b.contentRevision);
    });
  return exposure
      .map(
        (SentenceHuntExposureKey key) => <Object?>[
          _sentenceHuntScopeValues(key.scope),
          key.sectionId,
          key.contentRevision,
        ],
      )
      .toList();
}

void _expectFinishRetryCommandsMatch({
  required SentenceHuntState beforeFinish,
  required SentenceHuntCommand failedCommand,
  required SentenceHuntCommand retryCommand,
  required SentenceHuntProfileScope scope,
  required String sectionId,
}) {
  expect(failedCommand.scope, scope);
  expect(retryCommand.scope, scope);
  expect(failedCommand.sectionId, sectionId);
  expect(retryCommand.sectionId, sectionId);
  expect(failedCommand.expectedScopeRevision, beforeFinish.revision);
  expect(
    retryCommand.expectedScopeRevision,
    failedCommand.expectedScopeRevision,
  );
  expect(retryCommand.expected, failedCommand.expected);
  expect(retryCommand.token, failedCommand.token);
  expect(retryCommand.submittedAt, failedCommand.submittedAt);
  expect(retryCommand.sectionFingerprint, failedCommand.sectionFingerprint);
  expect(retryCommand.action, isA<FinishSentenceHuntRun>());
  expect(
    SentenceHuntCommandCodec.legacyCanonicalCommand(retryCommand),
    SentenceHuntCommandCodec.legacyCanonicalCommand(failedCommand),
  );
  expect(
    beforeFinish.completions,
    isEmpty,
    reason: 'the saved 4/5 debrief has no committed completion',
  );
}

Future<void> _answerUiItem(
  WidgetTester tester,
  ControlledSentenceHuntAudio audio,
  SentenceHuntCatalogue catalogue,
  String sectionId,
  String itemId, {
  required bool correct,
}) async {
  final item = catalogue.item(sectionId, itemId);
  await tester.ensureVisible(find.text('Play sentence'));
  await tester.tap(find.text('Play sentence'));
  await tester.pump();
  expect(audio.requests, isNotEmpty);
  audio.requests.last.complete();
  await tester.pumpAndSettle();
  final selected = correct
      ? item.expectedTokenIds
      : <String>[item.selectableTokenIds.last];
  for (final tokenId in selected) {
    final word = find.byKey(ValueKey<String>('sentence-word-$tokenId'));
    await tester.ensureVisible(word);
    await tester.tap(word);
  }
  await tester.ensureVisible(find.text('Submit answer'));
  await tester.tap(find.text('Submit answer'));
  await tester.pumpAndSettle();
  expect(find.text(correct ? 'Correct' : 'Not yet'), findsOneWidget);
}

final class _SqliteSentenceFixture {
  _SqliteSentenceFixture(this.directory, this.interceptor);

  final Directory directory;
  final _SentenceSqlInterceptor interceptor;
  late final File file = File('${directory.path}/learning.sqlite');
  int openCalls = 0;

  late final LearningDatabaseHandle handle = LearningDatabaseHandle(
    open: () async {
      openCalls++;
      return LearningDatabase(
        drift.DatabaseConnection(
          NativeDatabase(file).interceptWith(interceptor),
        ),
      );
    },
  );

  Future<void> close() async {
    await handle.close();
    await directory.delete(recursive: true);
  }
}

final class _SentenceSqlInterceptor extends drift.QueryInterceptor {
  bool _holdNextCommit = false;
  bool _learningWritePendingCommit = false;
  _SqliteWriteGate? _nextWriteGate;
  Completer<void>? _commitEntered;
  Completer<void>? _releaseCommit;
  Completer<void>? _commitCompleted;

  Future<void> get commitEntered => _commitEntered!.future;
  Future<void> get commitCompleted => _commitCompleted!.future;

  _SqliteWriteGate holdNextLearningWrite({required bool fail}) {
    final _SqliteWriteGate gate = _SqliteWriteGate(fail: fail);
    _nextWriteGate = gate;
    return gate;
  }

  void holdNextCommit() {
    _holdNextCommit = true;
    _commitEntered = Completer<void>();
    _releaseCommit = Completer<void>();
    _commitCompleted = Completer<void>();
  }

  void releaseCommit() {
    final Completer<void>? release = _releaseCommit;
    if (release != null && !release.isCompleted) release.complete();
  }

  @override
  Future<void> runCustom(
    drift.QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (_isLearningWrite(statement)) await _waitForWriteGate();
    await executor.runCustom(statement, args);
    if (_isLearningWrite(statement)) _learningWritePendingCommit = true;
  }

  @override
  Future<int> runUpdate(
    drift.QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (_isLearningWrite(statement)) await _waitForWriteGate();
    final int result = await executor.runUpdate(statement, args);
    if (_isLearningWrite(statement)) _learningWritePendingCommit = true;
    return result;
  }

  @override
  Future<void> commitTransaction(drift.TransactionExecutor inner) async {
    await inner.send();
    final bool shouldHold = _holdNextCommit && _learningWritePendingCommit;
    _learningWritePendingCommit = false;
    if (!shouldHold) return;
    _holdNextCommit = false;
    _commitEntered!.complete();
    try {
      await _releaseCommit!.future;
    } finally {
      if (!_commitCompleted!.isCompleted) _commitCompleted!.complete();
    }
  }

  Future<void> _waitForWriteGate() async {
    final _SqliteWriteGate? gate = _nextWriteGate;
    _nextWriteGate = null;
    if (gate == null) return;
    gate.entered.complete();
    try {
      await gate.released.future;
      if (gate.fail) throw StateError('injected sentence SQL write failure');
    } finally {
      if (!gate.completed.isCompleted) gate.completed.complete();
    }
  }

  bool _isLearningWrite(String statement) => statement.contains(
    'UPDATE learning_scopes SET revision = revision WHERE id = ?',
  );
}

final class _SqliteWriteGate {
  _SqliteWriteGate({required this.fail});

  final bool fail;
  final Completer<void> entered = Completer<void>();
  final Completer<void> released = Completer<void>();
  final Completer<void> completed = Completer<void>();

  void release() {
    if (!released.isCompleted) released.complete();
  }
}

Future<_SqliteSentenceFixture> _newSqliteSentenceFixture(
  WidgetTester tester,
) async {
  final Directory directory = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('sentence-sqlite-widget-'),
  ))!;
  return _SqliteSentenceFixture(directory, _SentenceSqlInterceptor());
}

Future<int> _sentenceScopeId(
  LearningDatabase db,
  SentenceHuntProfileScope scope,
) async =>
    (await db
            .customSelect(
              'SELECT id FROM learning_scopes WHERE owner_kind = ? AND '
              'owner_id = ? AND course_id = ? AND family = ?',
              variables: <drift.Variable<Object>>[
                drift.Variable<String>(
                  scope.owner.isGuest ? 'guest' : 'account',
                ),
                drift.Variable<String>(scope.owner.userId ?? ''),
                drift.Variable<String>(scope.courseId),
                const drift.Variable<String>('sentence-hunt'),
              ],
            )
            .getSingle())
        .read<int>('id');

Future<int> _sentenceScopeRevision(
  LearningDatabase db,
  SentenceHuntProfileScope scope,
) async =>
    (await db
            .customSelect(
              'SELECT revision FROM learning_scopes WHERE id = ?',
              variables: <drift.Variable<Object>>[
                drift.Variable<int>(await _sentenceScopeId(db, scope)),
              ],
            )
            .getSingle())
        .read<int>('revision');

Future<int> _sentenceCompletionCount(
  LearningDatabase db,
  SentenceHuntProfileScope scope,
) async {
  final int scopeId = await _sentenceScopeId(db, scope);
  return (await db
          .customSelect(
            'SELECT COUNT(*) AS row_count FROM learning_completions '
            'WHERE scope_id = ?',
            variables: <drift.Variable<Object>>[drift.Variable<int>(scopeId)],
          )
          .getSingle())
      .read<int>('row_count');
}

Future<Map<String, int>> _sentenceTableCounts(
  LearningDatabase db,
  SentenceHuntProfileScope scope,
) async {
  final int scopeId = await _sentenceScopeId(db, scope);
  final Map<String, int> counts = <String, int>{};
  for (final String table in <String>[
    'learning_content_bindings',
    'learning_runs',
    'learning_attempts',
    'learning_attempt_values',
    'learning_attempt_evidence',
    'learning_command_receipts',
    'learning_mistakes',
    'learning_summaries',
    'learning_completions',
    'learning_exposure',
    'learning_best_scores',
    'supported_sync_outbox',
  ]) {
    counts[table] =
        (await db
                .customSelect(
                  'SELECT COUNT(*) AS row_count FROM $table WHERE scope_id = ?',
                  variables: <drift.Variable<Object>>[
                    drift.Variable<int>(scopeId),
                  ],
                )
                .getSingle())
            .read<int>('row_count');
  }
  return counts;
}

final class _RecordingSentenceHuntStore implements SentenceHuntLearningStore {
  _RecordingSentenceHuntStore(this.delegate);

  final SentenceHuntLearningStore delegate;
  final List<SentenceHuntCommand> submittedCommands = <SentenceHuntCommand>[];

  @override
  SentenceHuntProfileScope get scope => delegate.scope;

  @override
  Future<SentenceHuntState> load() => delegate.load();

  @override
  Future<SentenceHuntState> retryLoad() => delegate.retryLoad();

  @override
  SentenceHuntCommand prepare({
    required SentenceHuntState state,
    required String sectionId,
    required SentenceHuntAction action,
  }) => delegate.prepare(state: state, sectionId: sectionId, action: action);

  @override
  Future<SentenceHuntCommit> submit(SentenceHuntCommand command) {
    submittedCommands.add(command);
    return delegate.submit(command);
  }
}

final class _InMemorySentenceHuntStore implements SentenceHuntLearningStore {
  _InMemorySentenceHuntStore({
    required this.scope,
    required SentenceHuntCatalogue catalogue,
  }) : _transitions = SentenceHuntTransitionEngine(catalogue: catalogue),
       state = SentenceHuntState.empty(scope);

  @override
  final SentenceHuntProfileScope scope;
  final SentenceHuntTransitionEngine _transitions;
  SentenceHuntState state;
  int _token = 0;
  int _clock = 0;

  DateTime _now() => DateTime.utc(2026, 10, 18, 12, 0, _clock++);

  @override
  Future<SentenceHuntState> load() async => state;

  @override
  Future<SentenceHuntState> retryLoad() async => state;

  @override
  SentenceHuntCommand prepare({
    required SentenceHuntState state,
    required String sectionId,
    required SentenceHuntAction action,
  }) => _transitions.prepare(
    state: state,
    sectionId: sectionId,
    action: action,
    authGeneration: 0,
    token: (++_token).toString().padLeft(22, '0'),
    submittedAt: _now(),
  );

  @override
  Future<SentenceHuntCommit> submit(SentenceHuntCommand command) async {
    final SentenceHuntTransition transition = _transitions.evaluate(
      state: state,
      command: command,
      committedAt: _now(),
    );
    state = transition.nextState;
    return SentenceHuntCommit(
      state: state,
      slot: transition.slot,
      duplicate: transition.duplicate,
    );
  }
}

final class _HeldSentenceStore implements SentenceHuntLearningStore {
  _HeldSentenceStore(this.scope) : state = SentenceHuntState.empty(scope);

  @override
  final SentenceHuntProfileScope scope;
  final SentenceHuntState state;
  final Completer<void> retryEntered = Completer<void>();
  final Completer<void> retryGate = Completer<void>();
  final Completer<void> retryFinished = Completer<void>();
  int retryCalls = 0;

  void releaseRetry() {
    if (!retryGate.isCompleted) retryGate.complete();
  }

  @override
  Future<SentenceHuntState> load() async => state;

  @override
  Future<SentenceHuntState> retryLoad() async {
    retryCalls++;
    retryEntered.complete();
    await retryGate.future;
    retryFinished.complete();
    return state;
  }

  @override
  SentenceHuntCommand prepare({
    required SentenceHuntState state,
    required String sectionId,
    required SentenceHuntAction action,
  }) => throw UnimplementedError();

  @override
  Future<SentenceHuntCommit> submit(SentenceHuntCommand command) =>
      throw UnimplementedError();
}
