import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_codec.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_store.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';
import 'package:linguist/src/features/course/sentence_hunt_progress_section.dart';
import 'package:linguist/src/features/course/sentence_hunt_progress_summary.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt_lesson_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/course_learning_widget_store.dart';
import '../support/sentence_hunt_fixtures.dart';
import '../support/sentence_hunt_harness.dart';

void main() {
  setUp(() =>
      SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'}));

  testWidgets('loading_sentence_progress_stays_unknown_until_state_loads',
      (tester) async {
    final Completer<SentenceHuntState> pendingState =
        Completer<SentenceHuntState>();
    final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
        courseId: 'en-fr', owner: LearningOwner.guest());
    await tester.pumpWidget(ProviderScope(
        overrides: [
          learningAuthScopeProvider.overrideWith(
              (ref) => LearningAuthTracker(owner: scope.owner, ready: true)),
          sentenceHuntCatalogueProvider
              .overrideWith((ref) async => syntheticSentenceCatalogue()),
          sentenceHuntLearningStateProvider
              .overrideWith((ref) => pendingState.future),
        ],
        child: const MaterialApp(
            home: Scaffold(body: SentenceHuntProgressSection()))));
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

  testWidgets('sentence_progress_retry_is_reachable_at_large_text_scales',
      (tester) async {
    for (final double scale in <double>[2, 3]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
          courseId: 'en-fr', owner: LearningOwner.guest());
      await tester.pumpWidget(ProviderScope(
          overrides: [
            learningAuthScopeProvider.overrideWith(
                (ref) => LearningAuthTracker(owner: scope.owner, ready: true)),
            sentenceHuntCatalogueProvider
                .overrideWith((ref) async => syntheticSentenceCatalogue()),
            sentenceHuntLearningStateProvider.overrideWith((ref) async {
              throw const FormatException('synthetic unavailable progress');
            }),
          ],
          child: MaterialApp(
              home: Scaffold(
                  body: ListView(children: const <Widget>[
            SizedBox(height: 1000),
            SentenceHuntProgressSection(),
          ])))));
      await tester.pumpAndSettle();
      final Finder retry = find.text('Retry sentence progress');
      await tester.scrollUntilVisible(retry, 160,
          scrollable: find.byType(Scrollable).first);
      expect(retry, findsOneWidget);
      await tester.pumpAndSettle();
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      expect(retry.hitTestable(), findsOneWidget,
          reason: 'sentence progress retry stays reachable at $scale× scale');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('home_offers_additive_sentence_sound_hunt_entry', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      courseLearningStoreProvider
          .overrideWithValue(CourseLearningWidgetStore()),
      comparisonLearningStateProvider.overrideWith((ref) async =>
          ComparisonLearningState.empty(ComparisonProfileScope(
              courseId: 'en-fr', owner: LearningOwner.guest()))),
      sentenceHuntLearningStateProvider.overrideWith((ref) async =>
          SentenceHuntLearningState.empty(SentenceHuntProfileScope(
              courseId: 'en-fr', owner: LearningOwner.guest()))),
    ], child: const LinguistApp()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Sentence sound hunt'), 160,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Sentence sound hunt'), findsOneWidget);
  });

  testWidgets('pending_sections_stay_visible_and_do_not_start', (tester) async {
    final catalogue = syntheticSentenceCatalogue(reviewed: false);
    var storeFactories = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      courseLearningStoreProvider
          .overrideWithValue(CourseLearningWidgetStore()),
      comparisonLearningStateProvider.overrideWith((ref) async =>
          ComparisonLearningState.empty(ComparisonProfileScope(
              courseId: 'en-fr', owner: LearningOwner.guest()))),
      sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
      sentenceHuntLearningStateProvider.overrideWith((ref) async =>
          SentenceHuntLearningState.empty(SentenceHuntProfileScope(
              courseId: 'en-fr', owner: LearningOwner.guest()))),
      sentenceHuntLearningStoreProvider.overrideWith((ref) async {
        storeFactories++;
        throw StateError('pending sections must not acquire a store');
      }),
    ], child: const LinguistApp()));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('Continue discovery')));
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
            'Content not yet available: French/audio or rights review is pending.'),
        findsNWidgets(3));
    expect(find.textContaining('Start '), findsNothing);
    expect(storeFactories, 0);
  });

  testWidgets('available_section_runs_while_pending_siblings_stay_local',
      (tester) async {
    final catalogue = _catalogueWithVowelsOnlyAvailable();
    expect(catalogue.isAvailable(fixtureSectionIds[0]), isTrue);
    expect(catalogue.isAvailable(fixtureSectionIds[1]), isFalse);
    expect(catalogue.isAvailable(fixtureSectionIds[2]), isFalse);

    final audio = ControlledSentenceHuntAudio();
    final scope = SentenceHuntProfileScope(
        courseId: 'en-fr', owner: LearningOwner.guest());
    final auth = LearningAuthTracker(owner: scope.owner, ready: true);
    final store =
        _InMemorySentenceHuntStore(scope: scope, catalogue: catalogue);
    await tester.pumpWidget(ProviderScope(overrides: [
      courseLearningStoreProvider
          .overrideWithValue(CourseLearningWidgetStore()),
      comparisonLearningStateProvider.overrideWith((ref) async =>
          ComparisonLearningState.empty(ComparisonProfileScope(
              courseId: 'en-fr', owner: LearningOwner.guest()))),
      learningAuthScopeProvider.overrideWith((ref) => auth),
      sentenceHuntLearningStoreProvider.overrideWith((ref) async => store),
      sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
      courseReferenceAudioProvider.overrideWithValue(audio),
    ], child: const LinguistApp()));
    await tester.pump();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(LinguistApp)));
    container.read(courseLearningStateProvider);
    container.read(comparisonLearningStateProvider);
    container.read(sentenceHuntLearningStateProvider);
    container.read(sentenceHuntCatalogueProvider);
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => container.read(sentenceHuntLearningStateProvider.future));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('Continue discovery')));
    router.go('/course-sentence-hunt');
    await tester.pumpAndSettle();
    expect(find.text('Start Vowels'), findsOneWidget);
    expect(find.text('Unavailable'), findsNWidgets(2));
    expect(find.text('Start Consonants'), findsNothing);
    expect(find.text('Start Mixed review'), findsNothing);

    router.go('/course-sentence-hunt/${fixtureSectionIds[1]}');
    await tester.pumpAndSettle();
    expect(find.textContaining('unavailable until its content and audio'),
        findsOneWidget);
    expect(find.byType(SentenceHuntLessonScreen), findsNothing);

    router.go('/course-sentence-hunt/${fixtureSectionIds[0]}');
    await tester.pumpAndSettle();
    expect(find.byType(SentenceHuntLessonScreen), findsOneWidget);
    await _answerUiItem(
        tester, audio, catalogue, fixtureSectionIds[0], fixtureItemIds[0][0],
        correct: true);
    expect(find.text('Correct'), findsOneWidget);
    expect(store.state.slots.containsKey(fixtureSectionIds[0]), isTrue);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('sentence_hunt_routes_reject_invalid_queries_before_acquisition',
      (tester) async {
    final catalogue = syntheticSentenceCatalogue(reviewed: false);
    var catalogueFactories = 0;
    var storeFactories = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      courseLearningStoreProvider
          .overrideWithValue(CourseLearningWidgetStore()),
      comparisonLearningStateProvider.overrideWith((ref) async =>
          ComparisonLearningState.empty(ComparisonProfileScope(
              courseId: 'en-fr', owner: LearningOwner.guest()))),
      sentenceHuntCatalogueProvider.overrideWith((ref) async {
        catalogueFactories++;
        return catalogue;
      }),
      sentenceHuntLearningStateProvider.overrideWith((ref) async =>
          SentenceHuntLearningState.empty(SentenceHuntProfileScope(
              courseId: 'en-fr', owner: LearningOwner.guest()))),
      sentenceHuntLearningStoreProvider.overrideWith((ref) async {
        storeFactories++;
        throw StateError('invalid routes must not acquire a store');
      }),
    ], child: const LinguistApp()));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Continue discovery')));
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
          find.text('This sentence-hunt route is unavailable.'), findsOneWidget,
          reason: uri);
      expect(catalogueFactories, catalogueCountBeforeInvalidRoutes,
          reason:
              'invalid route must be rejected before content acquisition: $uri');
      expect(storeFactories, 0,
          reason:
              'invalid route must be rejected before store acquisition: $uri');
    }
  });

  testWidgets('valid_item_route_keeps_exact_section_and_item_intent',
      (tester) async {
    final catalogue = syntheticSentenceCatalogue();
    var storeFactories = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      courseLearningStoreProvider
          .overrideWithValue(CourseLearningWidgetStore()),
      comparisonLearningStateProvider.overrideWith((ref) async =>
          ComparisonLearningState.empty(ComparisonProfileScope(
              courseId: 'en-fr', owner: LearningOwner.guest()))),
      sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
      sentenceHuntLearningStateProvider.overrideWith((ref) async =>
          SentenceHuntLearningState.empty(SentenceHuntProfileScope(
              courseId: 'en-fr', owner: LearningOwner.guest()))),
      sentenceHuntLearningStoreProvider.overrideWith((ref) async {
        storeFactories++;
        throw StateError('accepted content test store is intentionally absent');
      }),
    ], child: const LinguistApp()));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Continue discovery')));
    const path =
        '/course-sentence-hunt/en-fr-sentence-hunt-vowels?review=false&itemId=fr08-vowel-01';
    router.go(path);
    await tester.pumpAndSettle();
    expect(find.byType(SentenceHuntLessonScreen), findsOneWidget);
    expect(
        GoRouterState.of(tester.element(find.byType(SentenceHuntLessonScreen)))
            .uri
            .toString(),
        path);
    expect(find.textContaining('unavailable until its content and audio'),
        findsNothing);
    expect(storeFactories, 1);
  });

  testWidgets('pending_item_route_stays_local_before_store_acquisition',
      (tester) async {
    final catalogue = syntheticSentenceCatalogue(reviewed: false);
    var storeFactories = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      courseLearningStoreProvider
          .overrideWithValue(CourseLearningWidgetStore()),
      comparisonLearningStateProvider.overrideWith((ref) async =>
          ComparisonLearningState.empty(ComparisonProfileScope(
              courseId: 'en-fr', owner: LearningOwner.guest()))),
      sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
      sentenceHuntLearningStateProvider.overrideWith((ref) async =>
          SentenceHuntLearningState.empty(SentenceHuntProfileScope(
              courseId: 'en-fr', owner: LearningOwner.guest()))),
      sentenceHuntLearningStoreProvider.overrideWith((ref) async {
        storeFactories++;
        throw StateError('pending content must not acquire a store');
      }),
    ], child: const LinguistApp()));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Continue discovery')));
    const path =
        '/course-sentence-hunt/en-fr-sentence-hunt-vowels?review=false&itemId=fr08-vowel-01';
    router.go(path);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.toString(), path);
    expect(find.textContaining('unavailable until its content and audio'),
        findsOneWidget);
    expect(find.byType(SentenceHuntLessonScreen), findsNothing);
    expect(find.text('Start'), findsNothing);
    expect(storeFactories, 0);
  });

  testWidgets('sentence_retry_is_fenced_across_owner_A_to_B_to_A',
      (tester) async {
    final catalogue = syntheticSentenceCatalogue();
    final auth = LearningAuthTracker(owner: LearningOwner.guest(), ready: true);
    final scope = SentenceHuntProfileScope(
        courseId: 'en-fr', owner: LearningOwner.guest());
    final store = _HeldSentenceStore(scope);
    var stateLoads = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      courseLearningStoreProvider
          .overrideWithValue(CourseLearningWidgetStore()),
      comparisonLearningStateProvider.overrideWith((ref) async =>
          ComparisonLearningState.empty(ComparisonProfileScope(
              courseId: 'en-fr', owner: LearningOwner.guest()))),
      learningAuthScopeProvider.overrideWith((ref) => auth),
      sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
      sentenceHuntLearningStoreProvider.overrideWith((ref) async => store),
      sentenceHuntLearningStateProvider.overrideWith((ref) async {
        ref.watch(learningAuthScopeProvider);
        stateLoads++;
        throw StateError('sentence state unavailable');
      }),
    ], child: const LinguistApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Progress'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Retry sentence progress'), 160,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Retry sentence progress'), findsOneWidget);
    await tester.tap(find.text('Retry sentence progress'));
    await tester.pump();
    await tester.runAsync(() => store.retryEntered.future);

    auth.observe(owner: LearningOwner.account('owner-b'), ready: true);
    await tester.pump();
    auth.observe(owner: LearningOwner.guest(), ready: true);
    await tester.pumpAndSettle();
    expect(find.text('Retry sentence progress'), findsOneWidget,
        reason:
            'the current owner can recover while the earlier retry is held');
    final loadsForReturnedOwner = stateLoads;

    store.releaseRetry();
    await tester.runAsync(() => store.retryFinished.future);
    await tester.pumpAndSettle();
    expect(stateLoads, loadsForReturnedOwner,
        reason: 'the stale retry must not invalidate the A-again provider');
    expect(find.text('Retry sentence progress'), findsOneWidget,
        reason: 'stale finally must not clear or overwrite current-owner UI');
    expect(store.retryCalls, 1);
  });

  testWidgets('sentence_finish_ack_publishes_current_provider_once',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
        () => tester.platformDispatcher.clearTextScaleFactorTestValue());

    await _exerciseCorruptSentenceRecovery(tester);

    final catalogue = syntheticSentenceCatalogue();
    final scope = SentenceHuntProfileScope(
        courseId: 'en-fr', owner: LearningOwner.guest());
    final persistence = _GateLearningPersistence();
    final audio = ControlledSentenceHuntAudio();
    final auth = LearningAuthTracker(owner: scope.owner, ready: true);
    await tester.pumpWidget(ProviderScope(overrides: [
      courseLearningStoreProvider
          .overrideWithValue(CourseLearningWidgetStore()),
      comparisonLearningStateProvider.overrideWith((ref) async =>
          ComparisonLearningState.empty(ComparisonProfileScope(
              courseId: 'en-fr', owner: LearningOwner.guest()))),
      learningAuthScopeProvider.overrideWith((ref) => auth),
      learningPersistenceProvider.overrideWithValue(persistence),
      sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
      courseReferenceAudioProvider.overrideWithValue(audio),
    ], child: const LinguistApp()));
    await tester.pump();
    final appContainer =
        ProviderScope.containerOf(tester.element(find.byType(LinguistApp)));
    appContainer.read(courseLearningStateProvider);
    appContainer.read(comparisonLearningStateProvider);
    appContainer.read(sentenceHuntLearningStateProvider);
    appContainer.read(sentenceHuntCatalogueProvider);
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => appContainer.read(sentenceHuntLearningStateProvider.future));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('Continue discovery')));
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
    final container = ProviderScope.containerOf(
        tester.element(find.byType(SentenceHuntLessonScreen)));
    final rawBeforeFinish = Map<String, String>.from(persistence.values);
    final beforeFinish = const SentenceHuntLearningCodec()
        .decode(rawBeforeFinish[scope.storageKey]!, scope, catalogue);
    expect(beforeFinish.completions, isEmpty);
    expect(
        SentenceHuntProgressSummary.fromState(
                state: beforeFinish, catalogue: catalogue)
            .completedSectionCount,
        0);

    for (final scale in <double>[2, 3]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Finish'));
      expect(find.text('Finish').hitTestable(), findsOneWidget,
          reason: 'Finish stays reachable at $scale× text scale');
      expect(tester.takeException(), isNull,
          reason: 'debrief remains usable at $scale× text scale');
    }

    var finishPublicationCount = 0;
    var sentenceProviderNotificationCount = 0;
    final publication = container.listen(
      sentenceHuntLearningStateProvider,
      (previous, next) {
        sentenceProviderNotificationCount++;
        if (next.asData?.value.revision == beforeFinish.revision + 1) {
          finishPublicationCount++;
        }
      },
    );
    addTearDown(publication.close);
    final failedFinishGate = persistence.holdNextWrite(
        failure: StateError('injected sentence Finish storage failure'));
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.runAsync(() => failedFinishGate.entered.future);
    await tester.pump();
    expect(find.byType(SentenceHuntLessonScreen), findsOneWidget);
    expect(persistence.values, rawBeforeFinish);
    expect(finishPublicationCount, 0);
    expect(
        SentenceHuntProgressSummary.fromState(
                state: const SentenceHuntLearningCodec().decode(
                    persistence.values[scope.storageKey]!, scope, catalogue),
                catalogue: catalogue)
            .completedSectionCount,
        0,
        reason: 'held Finish is not visible before persistence ACK');
    final failedFinishBytes = persistence.writeAttempts.last.value;
    failedFinishGate.release();
    await tester.pumpAndSettle();
    expect(find.text('Retry saving'), findsOneWidget);
    expect(persistence.values, rawBeforeFinish,
        reason: 'failed Finish restores the acknowledged raw document');
    expect(finishPublicationCount, 0);
    expect(
        const SentenceHuntLearningCodec()
            .decode(persistence.values[scope.storageKey]!, scope, catalogue)
            .completions,
        isEmpty);

    for (final scale in <double>[2, 3]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retry saving'));
      expect(find.text('Retry saving').hitTestable(), findsOneWidget,
          reason: 'Finish retry stays reachable at $scale× text scale');
    }
    final retryGate = persistence.holdNextWrite();
    await tester.tap(find.text('Retry saving'));
    await tester.pump();
    await tester.runAsync(() => retryGate.entered.future);
    final String retryCandidateBytes = persistence.writeAttempts.last.value;
    expect(persistence.values, rawBeforeFinish);
    expect(finishPublicationCount, 0);
    expect(
        const SentenceHuntLearningCodec()
            .decode(persistence.values[scope.storageKey]!, scope, catalogue)
            .completions,
        isEmpty,
        reason: 'retry remains private until its persistence ACK');
    final SentenceHuntState retryCandidate = _expectFinishRetryCandidatesMatch(
      beforeFinish: beforeFinish,
      beforeFinishBytes: rawBeforeFinish[scope.storageKey]!,
      failedCandidateBytes: failedFinishBytes,
      retryCandidateBytes: retryCandidateBytes,
      scope: scope,
      catalogue: catalogue,
      sectionId: sectionId,
    );

    retryGate.release();
    await tester.runAsync(() => retryGate.completed.future);
    await tester.pumpAndSettle();
    final SentenceHuntState publishedState = (await tester.runAsync(
        () => container.read(sentenceHuntLearningStateProvider.future)))!;
    await tester.pumpAndSettle();
    expect(publishedState.revision, beforeFinish.revision + 1,
        reason: 'the actual provider refresh follows the persistence ACK');
    expect(finishPublicationCount, 1,
        reason: 'the real repository publishes its ACKed Finish once');
    final afterFinish = const SentenceHuntLearningCodec()
        .decode(persistence.values[scope.storageKey]!, scope, catalogue);
    expect(persistence.values[scope.storageKey], retryCandidateBytes,
        reason: 'the acknowledged retry candidate is the committed document');
    expect(afterFinish.revision, retryCandidate.revision);
    expect(afterFinish.completions, hasLength(1));
    expect(
        SentenceHuntProgressSummary.fromState(
                state: afterFinish, catalogue: catalogue)
            .completedSectionCount,
        1);

    final SentenceHuntReceipt finishReceipt =
        afterFinish.slots[sectionId]!.latestReceipt;
    final Map<String, dynamic> finishCommandJson =
        jsonDecode(finishReceipt.canonicalCommand) as Map<String, dynamic>;
    final SentenceHuntCommand duplicateFinish = SentenceHuntCommand(
      scope: scope,
      authGeneration: finishCommandJson['authGeneration'] as int,
      sectionId: finishReceipt.sectionId,
      sectionFingerprint: finishCommandJson['sectionFingerprint'] as String,
      expected: finishReceipt.before,
      token: finishReceipt.token,
      submittedAt:
          DateTime.parse(finishCommandJson['submittedAt'] as String).toUtc(),
      action: const FinishSentenceHuntRun(),
    );
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    expect(codec.canonicalCommand(duplicateFinish),
        finishReceipt.canonicalCommand);
    final SentenceHuntLearningStore store =
        await container.read(sentenceHuntLearningStoreProvider.future);
    final int writesBeforeDuplicate = persistence.writeCalls;
    final String bytesBeforeDuplicate = persistence.values[scope.storageKey]!;
    final int notificationsBeforeDuplicate = sentenceProviderNotificationCount;
    final SentenceHuntCommit duplicateResult =
        await store.submit(duplicateFinish);
    await tester.pumpAndSettle();
    expect(duplicateResult.duplicate, isTrue);
    expect(persistence.writeCalls, writesBeforeDuplicate,
        reason: 'an acknowledged duplicate Finish performs no write');
    expect(persistence.values[scope.storageKey], bytesBeforeDuplicate,
        reason: 'an acknowledged duplicate Finish preserves committed bytes');
    expect(sentenceProviderNotificationCount, notificationsBeforeDuplicate,
        reason: 'an acknowledged duplicate Finish publishes no refresh');
    expect(finishPublicationCount, 1);

    router.go('/home');
    await tester.pumpAndSettle();
    await tester
        .runAsync(() => container.read(courseLearningStateProvider.future));
    await tester.runAsync(
        () => container.read(sentenceHuntLearningStateProvider.future));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Sentence sections completed: 1/3'), 160,
        scrollable: find.byType(Scrollable).first, maxScrolls: 100);
    expect(find.text('Sentence sections completed: 1/3'), findsOneWidget,
        reason: 'Home reflects the provider notification without invalidation');
    await tester.scrollUntilVisible(find.text('Continue discovery'), -160,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Continue discovery'), findsOneWidget);
    router.go('/course-progress');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Sentence sections completed: 1/3'), 160,
        scrollable: find.byType(Scrollable).first, maxScrolls: 100);
    expect(find.text('Sentence sections completed: 1/3'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Discovery lessons: 0/1 complete'), -160,
        scrollable: find.byType(Scrollable).first, maxScrolls: 100);
    expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
    expect(
        find.text('Existing lessons (includes discovery pilot): 0/5 complete'),
        findsOneWidget);

    const mistakeLabel = 'Sentence item fr08-vowel-05';
    for (final scale in <double>[2, 3]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(mistakeLabel), 180,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text(mistakeLabel));
      await tester.pumpAndSettle();
      expect(find.text(mistakeLabel).hitTestable(), findsOneWidget,
          reason: 'mistake link stays reachable at $scale× text scale');
    }
    await tester.tap(find.text(mistakeLabel));
    await tester.pumpAndSettle();
    final mistakeUri =
        GoRouterState.of(tester.element(find.byType(SentenceHuntLessonScreen)))
            .uri;
    expect(mistakeUri.path, '/course-sentence-hunt/$sectionId');
    expect(mistakeUri.queryParameters, <String, String>{
      'review': 'true',
      'itemId': 'fr08-vowel-05',
    });
    expect(find.bySemanticsLabel('Word 1 of 5: Vous'), findsOneWidget,
        reason: 'the review link opens the exact saved mistake item');
  });
}

SentenceHuntCatalogue _catalogueWithVowelsOnlyAvailable() {
  final SentenceHuntPackageFixture fixture = syntheticSentencePackage().copy();
  final Set<String> pendingItemIds =
      fixtureItemIds.skip(1).expand((List<String> itemIds) => itemIds).toSet();

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
  final SentenceHuntProfileScope scope =
      SentenceHuntProfileScope(courseId: 'en-fr', owner: LearningOwner.guest());
  final _GateLearningPersistence persistence = _GateLearningPersistence()
    ..values[scope.storageKey] = '{corrupt sentence document';
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  await tester.pumpWidget(ProviderScope(overrides: [
    courseLearningStoreProvider.overrideWithValue(CourseLearningWidgetStore()),
    comparisonLearningStateProvider.overrideWith((ref) async =>
        ComparisonLearningState.empty(ComparisonProfileScope(
            courseId: 'en-fr', owner: LearningOwner.guest()))),
    learningAuthScopeProvider.overrideWith((ref) =>
        LearningAuthTracker(owner: LearningOwner.guest(), ready: true)),
    learningPersistenceProvider.overrideWithValue(persistence),
    sentenceHuntCatalogueProvider.overrideWith((ref) async => catalogue),
  ], child: const LinguistApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Progress'));
  await tester.pumpAndSettle();

  expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
  expect(find.text('Existing lessons (includes discovery pilot): 0/5 complete'),
      findsOneWidget);
  await tester.scrollUntilVisible(
      find.text('Comparison practice, not phoneme mastery'), 160,
      scrollable: find.byType(Scrollable).first);
  expect(find.text('Comparison practice, not phoneme mastery'), findsOneWidget);
  await tester.scrollUntilVisible(
      find.text('Sentence practice, not phoneme mastery'), 160,
      scrollable: find.byType(Scrollable).first);
  expect(find.text('Sentence practice, not phoneme mastery'), findsOneWidget);
  expect(
      find.textContaining('Sentence progress is unavailable'), findsOneWidget);
  await tester.scrollUntilVisible(find.text('Retry sentence progress'), 160,
      scrollable: find.byType(Scrollable).first);
  expect(find.text('Retry sentence progress'), findsOneWidget);
  expect(find.text('Retry sentence progress').hitTestable(), findsOneWidget,
      reason: 'sentence progress retry stays reachable at '
          '$textScaleFactor× scale');
  expect(find.text('Retry loading progress'), findsNothing);
  expect(persistence.values[scope.storageKey], '{corrupt sentence document');

  final int readsBeforeRetry = persistence.readCalls;
  await tester.ensureVisible(find.text('Retry sentence progress'));
  await tester.tap(find.text('Retry sentence progress'));
  await tester.pumpAndSettle();
  expect(persistence.readCalls, greaterThan(readsBeforeRetry));
  expect(persistence.writeCalls, 0);
  expect(persistence.values[scope.storageKey], '{corrupt sentence document');
  expect(find.text('Discovery lessons: 0/1 complete'), findsOneWidget);
  expect(find.text('Comparison practice, not phoneme mastery'), findsOneWidget);
  expect(find.text('Retry sentence progress'), findsOneWidget,
      reason: 'failed recovery returns to its retryable state');

  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  tester.platformDispatcher.clearTextScaleFactorTestValue();
}

SentenceHuntState _expectFinishRetryCandidatesMatch({
  required SentenceHuntState beforeFinish,
  required String beforeFinishBytes,
  required String failedCandidateBytes,
  required String retryCandidateBytes,
  required SentenceHuntProfileScope scope,
  required SentenceHuntCatalogue catalogue,
  required String sectionId,
}) {
  const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
  final SentenceHuntState previous =
      codec.decode(beforeFinishBytes, scope, catalogue);
  final SentenceHuntState failedCandidate =
      codec.decode(failedCandidateBytes, scope, catalogue);
  final SentenceHuntState retryCandidate =
      codec.decode(retryCandidateBytes, scope, catalogue);

  expect(previous.scope, scope);
  expect(failedCandidate.scope, scope);
  expect(retryCandidate.scope, scope);
  expect(failedCandidate.revision, previous.revision + 1);
  expect(retryCandidate.revision, failedCandidate.revision);
  expect(failedCandidate.commitOrdinal, previous.commitOrdinal + 1);
  expect(retryCandidate.commitOrdinal, failedCandidate.commitOrdinal);
  expect(retryCandidate.slots.keys, failedCandidate.slots.keys);

  final SentenceHuntSlot previousSlot = previous.slots[sectionId]!;
  final SentenceHuntReceipt failedReceipt =
      failedCandidate.slots[sectionId]!.latestReceipt;
  final SentenceHuntReceipt retryReceipt =
      retryCandidate.slots[sectionId]!.latestReceipt;
  expect(failedReceipt.scope, scope);
  expect(retryReceipt.scope, scope);
  expect(failedReceipt.sectionId, sectionId);
  expect(retryReceipt.sectionId, failedReceipt.sectionId);
  expect(failedReceipt.token, retryReceipt.token);
  expect(failedReceipt.canonicalCommand, retryReceipt.canonicalCommand);
  expect(failedReceipt.before, previousSlot.cursor);
  expect(retryReceipt.before, failedReceipt.before);
  expect(retryReceipt.after, failedReceipt.after);
  expect(failedReceipt.after, failedCandidate.slots[sectionId]!.cursor);
  expect(retryReceipt.after, retryCandidate.slots[sectionId]!.cursor);
  expect(failedReceipt.commitOrdinal, previous.commitOrdinal + 1);
  expect(retryReceipt.commitOrdinal, failedReceipt.commitOrdinal);

  final Map<String, dynamic> failedCommand =
      jsonDecode(failedReceipt.canonicalCommand) as Map<String, dynamic>;
  final Map<String, dynamic> retryCommand =
      jsonDecode(retryReceipt.canonicalCommand) as Map<String, dynamic>;
  expect(retryCommand, failedCommand);
  expect(failedCommand['courseId'], scope.courseId);
  expect(failedCommand['owner'], <String, Object?>{
    'kind': scope.owner.isGuest ? 'guest' : 'account',
    'userId': scope.owner.userId,
  });
  expect(failedCommand['sectionId'], sectionId);
  expect(failedCommand['sectionFingerprint'],
      previousSlot.checkpoint.sectionFingerprint);
  expect(failedCommand['generation'], failedReceipt.before.generation);
  expect(failedCommand['sequence'], failedReceipt.before.sequence);
  expect(failedCommand['revision'], failedReceipt.before.revision);
  expect(failedCommand['token'], failedReceipt.token);
  expect(failedCommand['submittedAt'], retryCommand['submittedAt']);
  expect(failedCommand['action'], <String, String>{'kind': 'finish'});

  expect(previous.completions, isEmpty,
      reason: 'the saved 4/5 debrief had no committed completion');
  expect(failedCandidate.completions, hasLength(1));
  expect(retryCandidate.completions, hasLength(1));
  final SentenceHuntCompletion failedCompletion =
      failedCandidate.completions.single;
  final SentenceHuntCompletion retryCompletion =
      retryCandidate.completions.single;
  expect(failedCompletion.scope, scope);
  expect(retryCompletion.scope, failedCompletion.scope);
  expect(retryCompletion.sectionId, failedCompletion.sectionId);
  expect(retryCompletion.contentRevision, failedCompletion.contentRevision);
  expect(retryCompletion.policyRevision, failedCompletion.policyRevision);
  expect(retryCompletion.thresholdPercent, failedCompletion.thresholdPercent);
  expect(failedCompletion.sectionId, sectionId);

  final Map<String, dynamic> previousDocument =
      jsonDecode(beforeFinishBytes) as Map<String, dynamic>;
  final Map<String, dynamic> failedDocument =
      jsonDecode(failedCandidateBytes) as Map<String, dynamic>;
  final Map<String, dynamic> retryDocument =
      jsonDecode(retryCandidateBytes) as Map<String, dynamic>;
  for (final String field in <String>[
    'attempts',
    'mistakes',
    'summaries',
    'teachingExposure',
  ]) {
    expect(failedDocument[field], previousDocument[field],
        reason: 'Finish preserves previously acknowledged $field');
    expect(retryDocument[field], previousDocument[field],
        reason: 'retry preserves previously acknowledged $field');
  }
  final List<dynamic> previousReceipts =
      previousDocument['receipts'] as List<dynamic>;
  expect(
      (failedDocument['receipts'] as List<dynamic>)
          .take(previousReceipts.length)
          .toList(),
      previousReceipts);
  expect(
      (retryDocument['receipts'] as List<dynamic>)
          .take(previousReceipts.length)
          .toList(),
      previousReceipts);
  final List<dynamic> previousCompletions =
      previousDocument['completions'] as List<dynamic>;
  expect(
      (failedDocument['completions'] as List<dynamic>)
          .take(previousCompletions.length)
          .toList(),
      previousCompletions);
  expect(
      (retryDocument['completions'] as List<dynamic>)
          .take(previousCompletions.length)
          .toList(),
      previousCompletions);

  final Map<String, dynamic> failedComparable =
      Map<String, dynamic>.from(failedDocument);
  final Map<String, dynamic> retryComparable =
      Map<String, dynamic>.from(retryDocument);
  failedComparable['completions'] = <dynamic>[
    for (final dynamic completion
        in failedDocument['completions'] as List<dynamic>)
      Map<String, dynamic>.from(completion as Map),
  ];
  retryComparable['completions'] = <dynamic>[
    for (final dynamic completion
        in retryDocument['completions'] as List<dynamic>)
      Map<String, dynamic>.from(completion as Map),
  ];
  (failedComparable['completions'] as List<dynamic>).single['committedAt'] =
      '<new completion commit time>';
  (retryComparable['completions'] as List<dynamic>).single['committedAt'] =
      '<new completion commit time>';
  expect(retryComparable, failedComparable,
      reason: 'only the new completion committedAt may differ across retries');

  return retryCandidate;
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
  final selected =
      correct ? item.expectedTokenIds : <String>[item.selectableTokenIds.last];
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

final class _GateLearningPersistence implements LearningPersistence {
  final Map<String, String> values = <String, String>{};
  final List<_WriteAttempt> writeAttempts = <_WriteAttempt>[];
  int readCalls = 0;
  int writeCalls = 0;
  _WriteGate? _nextWriteGate;

  _WriteGate holdNextWrite({Object? failure}) {
    final gate = _WriteGate(failure: failure);
    _nextWriteGate = gate;
    return gate;
  }

  @override
  Future<String?> read(String key) async {
    readCalls++;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writeCalls++;
    writeAttempts.add(_WriteAttempt(key, value));
    final gate = _nextWriteGate;
    _nextWriteGate = null;
    if (gate != null) {
      gate.entered.complete();
      await gate.released.future;
      if (gate.failure != null) throw gate.failure!;
    }
    values[key] = value;
    if (gate != null && !gate.completed.isCompleted) {
      gate.completed.complete();
    }
  }

  @override
  Future<void> restore(String key, String? lastCommitted) async {
    if (lastCommitted == null) {
      values.remove(key);
    } else {
      values[key] = lastCommitted;
    }
  }

  @override
  Future<void> reload() async {}
}

final class _WriteAttempt {
  const _WriteAttempt(this.key, this.value);

  final String key;
  final String value;
}

final class _WriteGate {
  _WriteGate({this.failure});

  final Object? failure;
  final Completer<void> entered = Completer<void>();
  final Completer<void> released = Completer<void>();
  final Completer<void> completed = Completer<void>();

  void release() {
    if (!released.isCompleted) released.complete();
  }
}

final class _InMemorySentenceHuntStore implements SentenceHuntLearningStore {
  _InMemorySentenceHuntStore({
    required this.scope,
    required SentenceHuntCatalogue catalogue,
  })  : _transitions = SentenceHuntTransitionEngine(catalogue: catalogue),
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
  }) =>
      _transitions.prepare(
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
  }) =>
      throw UnimplementedError();

  @override
  Future<SentenceHuntCommit> submit(SentenceHuntCommand command) =>
      throw UnimplementedError();
}
