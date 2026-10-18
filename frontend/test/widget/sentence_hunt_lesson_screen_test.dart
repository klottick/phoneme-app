import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_store.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt_controller.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt_lesson_screen.dart';
import '../support/sentence_hunt_harness.dart';

void main() {
  testWidgets('pending section is local-unavailable with no learner load',
      (WidgetTester tester) async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig(reviewed: false);
    final ProviderContainer container = rig.providerContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: SentenceHuntLessonScreen(sectionId: rig.sectionId),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('unavailable until its content and audio'),
        findsOneWidget);
    expect(find.text('Retry validation'), findsOneWidget);
    expect(find.textContaining('Synthetic test note'), findsNothing);
    expect(rig.persistence.reads, 0);
    expect(rig.persistence.writes, 0);
    expect(rig.audio.requests, isEmpty);
    expect(rig.audio.speakCalls, 0);
  });

  testWidgets(
      'screen retries providers and fences reviewed playback across lifecycle',
      (WidgetTester tester) async {
    final SentenceHuntTestRig rig = SentenceHuntTestRig();
    final LearningAuthTracker authTracker = LearningAuthTracker(
      owner: LearningOwner.guest(),
      ready: true,
    );
    var catalogueAcquisitions = 0;
    var storeAcquisitions = 0;
    final ProviderContainer container = rig.providerContainer(
      authTracker: authTracker,
      acquireCatalogue: () async {
        catalogueAcquisitions++;
        if (catalogueAcquisitions == 1) {
          throw StateError('private content provider failure');
        }
        return rig.catalogue;
      },
      acquireStore: () async {
        storeAcquisitions++;
        if (storeAcquisitions == 1) {
          throw StateError('private provider failure');
        }
        return rig.store;
      },
    );
    addTearDown(container.dispose);
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: SentenceHuntLessonScreen(sectionId: rig.sectionId),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Sentence-hunt content could not be checked.'),
      findsOneWidget,
    );
    expect(find.text('Retry validation'), findsOneWidget);
    expect(
        find.textContaining('private content provider failure'), findsNothing);
    await tester.tap(find.text('Retry validation'));
    await tester.pumpAndSettle();
    expect(find.text('Saved sentence-hunt progress could not be loaded.'),
        findsOneWidget);
    expect(find.text('Retry loading'), findsOneWidget);
    expect(find.textContaining('private provider failure'), findsNothing);
    await tester.tap(find.text('Retry loading'));
    await tester.pumpAndSettle();

    expect(storeAcquisitions, 2);
    expect(catalogueAcquisitions, 2);
    expect(find.bySemanticsLabel('Word 1 of 5: Tu'), findsOneWidget);
    expect(find.textContaining('Synthetic test note'), findsNothing);
    expect(find.textContaining('Words with target:'), findsNothing);
    await tester.tap(find.text('Play sentence'));
    await tester.pump();
    expect(find.text('Playing sentence…'), findsOneWidget);
    expect(rig.audio.requests, hasLength(1));
    final ControlledSentenceHuntPlayback staleRequest =
        rig.audio.requests.single;
    expect(staleRequest.use, CourseAudioUse.reviewedOnly);
    expect(staleRequest.allowPracticeTts, isFalse);

    navigatorKey.currentState!.push<void>(MaterialPageRoute<void>(
      builder: (BuildContext context) => const Scaffold(body: Text('Cover')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(rig.audio.stopCalls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Cover'), findsOneWidget);
    staleRequest.complete();
    await tester.pump();

    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Word 1 of 5: Tu'), findsOneWidget);
    expect(find.text('Resume exercise'), findsOneWidget,
        reason: 'revealing a suspended route requires explicit safe recovery');
    expect(rig.audio.requests, hasLength(1));
    final Finder prerecoveryPlay =
        find.widgetWithText(OutlinedButton, 'Play sentence');
    final Finder prerecoveryWord = find
        .byKey(const ValueKey<String>('sentence-word-fr08-vowel-01-token-01'));
    expect(tester.widget<OutlinedButton>(prerecoveryPlay).onPressed, isNull,
        reason: 'playback is unavailable until explicit recovery');
    expect(
      tester
          .getSemantics(prerecoveryWord)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
      reason: 'word selection semantics use the same recovery gate',
    );
    expect(
      tester
          .getSemantics(prerecoveryWord)
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .name,
      'isFalse',
    );
    final Finder prerecoverySubmit =
        find.widgetWithText(FilledButton, 'Submit answer');
    expect(tester.widget<FilledButton>(prerecoverySubmit).onPressed, isNull);
    await tester.tap(prerecoveryPlay);
    await tester.tap(prerecoveryWord);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(rig.audio.requests, hasLength(1),
        reason:
            'pointer and keyboard activation cannot restart stale playback');
    expect(
      tester
          .getSemantics(prerecoveryWord)
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .name,
      'isFalse',
      reason: 'prerecovery input cannot alter local selection state',
    );
    expect(
        rig.store.submitted.where((SentenceHuntCommand command) =>
            command.action is AnswerSentenceHuntItem),
        isEmpty);
    await tester.ensureVisible(find.text('Resume exercise'));
    await tester.tap(find.text('Resume exercise'));
    await tester.pumpAndSettle();
    expect(find.text('Resume exercise'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit answer'))
          .onPressed,
      isNull,
      reason: 'app resume and route reveal cannot revive the retired grant',
    );
    expect(
        rig.store.submitted.where((SentenceHuntCommand command) =>
            command.action is AnswerSentenceHuntItem),
        isEmpty);
    expect(find.textContaining('Synthetic test note'), findsNothing);

    await tester.tap(find.text('Play sentence'));
    await tester.pump();
    expect(rig.audio.requests, hasLength(2));
    final ControlledSentenceHuntPlayback currentRequest =
        rig.audio.requests.last;
    expect(currentRequest.use, CourseAudioUse.reviewedOnly);
    expect(currentRequest.allowPracticeTts, isFalse);
    currentRequest.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit answer'))
          .onPressed,
      isNotNull,
    );

    final Finder word = find.bySemanticsLabel('Word 1 of 5: Tu');
    await tester.ensureVisible(word);
    await tester.tap(word);
    await tester.pump();
    await tester.tap(find.text('Submit answer'));
    await tester.pumpAndSettle();
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(
      rig.store.submitted.where((SentenceHuntCommand command) =>
          command.action is AnswerSentenceHuntItem),
      hasLength(1),
    );
    expect(rig.persistence.writes, greaterThan(1));
    expect(rig.audio.speakCalls, 0);

    final int readsBeforeAuthPause = rig.persistence.reads;
    final int writesBeforeAuthPause = rig.persistence.writes;
    final int commandsBeforeAuthPause = rig.store.submitted.length;
    authTracker.observe(owner: LearningOwner.guest(), ready: false);
    await tester.pump();
    expect(find.textContaining('paused while this screen'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);

    authTracker.observe(owner: LearningOwner.guest(), ready: true);
    await tester.pump();
    expect(find.text('Resume exercise'), findsOneWidget);
    expect(find.text('Continue'), findsNothing,
        reason: 'auth readiness does not resume the owner implicitly');
    expect(rig.persistence.reads, readsBeforeAuthPause);
    expect(rig.persistence.writes, writesBeforeAuthPause);
    expect(rig.store.submitted, hasLength(commandsBeforeAuthPause));

    await tester.tap(find.text('Resume exercise'));
    await tester.pumpAndSettle();
    expect(find.text('Resume exercise'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    expect(rig.persistence.reads, readsBeforeAuthPause,
        reason: 'safe recovery retains the already-acknowledged session');
    expect(rig.persistence.writes, writesBeforeAuthPause);
    expect(rig.store.submitted, hasLength(commandsBeforeAuthPause));

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    for (final double scale in <double>[2, 3]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pump();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final int priorAudioRequests = rig.audio.requests.length;
      await tester.ensureVisible(find.text('Play sentence'));
      await tester.tap(find.text('Play sentence'));
      await tester.pump();
      rig.audio.requests.last.fail();
      await tester.pumpAndSettle();
      expect(
          find.textContaining('recording could not be played'), findsOneWidget,
          reason: 'audio retry remains visible at text scale $scale');
      await tester.ensureVisible(find.text('Retry audio'));
      await tester.tap(find.text('Retry audio'));
      await tester.pump();
      expect(rig.audio.requests, hasLength(priorAudioRequests + 2));
      rig.audio.requests.last.complete();
      await tester.pumpAndSettle();

      rig.persistence.holdNextWrite(failure: StateError('quota rejected'));
      await tester.ensureVisible(find.text('Submit answer'));
      await tester.tap(find.text('Submit answer'));
      for (var turn = 0; turn < 12; turn++) {
        await tester.pump();
      }
      await rig.persistence.writeEntered;
      rig.persistence.releaseWrite();
      await tester.pumpAndSettle();
      expect(find.text('Retry saving'), findsOneWidget,
          reason: 'save retry remains visible at text scale $scale');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Resume exercise'), findsOneWidget);
      expect(find.text('Retry saving'), findsNothing,
          reason: 'a pending answer cannot retry before explicit recovery');
      await tester.ensureVisible(find.text('Resume exercise'));
      await tester.tap(find.text('Resume exercise'));
      await tester.pump();
      expect(find.text('Retry saving'), findsOneWidget);
      await tester.ensureVisible(find.text('Retry saving'));
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(rig.audio.requests, hasLength(priorAudioRequests + 2),
          reason:
              'a save retry does not acquire new audio at text scale $scale');
      expect(tester.takeException(), isNull,
          reason: 'the screen remains usable at text scale $scale');
    }

    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Play sentence'));
    await tester.tap(find.text('Play sentence'));
    await tester.pump();
    final ControlledSentenceHuntPlayback sectionStaleRequest =
        rig.audio.requests.last;
    final int stopsBeforeSectionChange = rig.audio.stopCalls;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: SentenceHuntLessonScreen(
          sectionId: 'en-fr-sentence-hunt-consonants',
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Word 1 of 5: Zoé'), findsOneWidget);
    expect(rig.audio.stopCalls, stopsBeforeSectionChange + 1,
        reason: 'changing section retires its active audio owner');

    await tester.ensureVisible(find.text('Play sentence'));
    await tester.tap(find.text('Play sentence'));
    await tester.pump();
    final ControlledSentenceHuntPlayback currentSectionRequest =
        rig.audio.requests.last;
    sectionStaleRequest.complete();
    await tester.pump();
    expect(find.text('Playing sentence…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit answer'))
          .onPressed,
      isNull,
      reason: 'old-section success cannot grant the new section answer',
    );
    currentSectionRequest.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit answer'))
          .onPressed,
      isNotNull,
    );
    expect(rig.audio.speakCalls, 0);

    await _interruptedCatalogueAcquisition(tester);
    await _interruptedStoreAcquisition(tester);
    await _failedInitialStartIsRecoverableAtScale(tester, 2);
    await _failedInitialStartIsRecoverableAtScale(tester, 3);
    await _savedDebriefActionsWaitForResume(tester);
  });
}

Future<void> _clearMountedScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _interruptedCatalogueAcquisition(WidgetTester tester) async {
  await _clearMountedScreen(tester);
  final SentenceHuntTestRig rig = SentenceHuntTestRig();
  final LearningAuthTracker authTracker = LearningAuthTracker(
    owner: LearningOwner.guest(),
    ready: true,
  );
  final Completer<SentenceHuntCatalogue> staleCatalogue =
      Completer<SentenceHuntCatalogue>();
  final Completer<SentenceHuntCatalogue> currentCatalogue =
      Completer<SentenceHuntCatalogue>();
  var acquisitions = 0;
  final ProviderContainer container = rig.providerContainer(
    authTracker: authTracker,
    acquireCatalogue: () {
      acquisitions++;
      return acquisitions == 1
          ? staleCatalogue.future
          : currentCatalogue.future;
    },
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: SentenceHuntLessonScreen(sectionId: rig.sectionId),
    ),
  ));
  await tester.pump();
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  authTracker.observe(owner: LearningOwner.guest(), ready: false);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  authTracker.observe(owner: LearningOwner.guest(), ready: true);
  await tester.pump();

  expect(find.text('Resume exercise'), findsOneWidget,
      reason: 'a stale provider await must not strand the screen on a spinner');
  expect(find.byType(CircularProgressIndicator), findsNothing);

  container.invalidate(sentenceHuntCatalogueProvider);
  await tester.ensureVisible(find.text('Resume exercise'));
  await tester.tap(find.text('Resume exercise'));
  await tester.pump();
  expect(acquisitions, 2);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  staleCatalogue.completeError(StateError('stale catalogue failure'));
  await tester.pump();
  await tester.pump();
  expect(find.byType(CircularProgressIndicator), findsOneWidget,
      reason: 'the old failure cannot clear the current acquisition spinner');
  expect(find.textContaining('stale catalogue failure'), findsNothing);

  currentCatalogue.complete(rig.catalogue);
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Word 1 of 5: Tu'), findsOneWidget);
  expect(find.text('Resume exercise'), findsNothing);
  expect(rig.persistence.writes, 1,
      reason: 'only the recovered owner may start the learner run');
  await _clearMountedScreen(tester);
}

Future<void> _interruptedStoreAcquisition(WidgetTester tester) async {
  await _clearMountedScreen(tester);
  final SentenceHuntTestRig rig = SentenceHuntTestRig();
  final Completer<SentenceHuntLearningStore> staleStore =
      Completer<SentenceHuntLearningStore>();
  final Completer<SentenceHuntLearningStore> currentStore =
      Completer<SentenceHuntLearningStore>();
  var acquisitions = 0;
  final ProviderContainer container = rig.providerContainer(
    acquireStore: () {
      acquisitions++;
      return acquisitions == 1 ? staleStore.future : currentStore.future;
    },
  );
  addTearDown(container.dispose);
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      navigatorKey: navigatorKey,
      home: SentenceHuntLessonScreen(sectionId: rig.sectionId),
    ),
  ));
  await tester.pump();
  await tester.pump();
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  navigatorKey.currentState!.push<void>(MaterialPageRoute<void>(
    builder: (BuildContext context) => const Scaffold(body: Text('Cover')),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  navigatorKey.currentState!.pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  expect(find.text('Resume exercise'), findsOneWidget,
      reason: 'route reveal must expose recovery after store acquisition');
  expect(find.byType(CircularProgressIndicator), findsNothing);
  container.invalidate(sentenceHuntLearningStoreProvider);
  await tester.ensureVisible(find.text('Resume exercise'));
  await tester.tap(find.text('Resume exercise'));
  await tester.pump();
  expect(acquisitions, 2);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  staleStore.complete(rig.store);
  await tester.pump();
  await tester.pump();
  expect(find.byType(CircularProgressIndicator), findsOneWidget,
      reason: 'the old store cannot clear the newer acquisition spinner');
  currentStore.complete(rig.store);
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Word 1 of 5: Tu'), findsOneWidget);
  expect(rig.persistence.writes, 1,
      reason: 'a stale store completion must not start a run');
  await _clearMountedScreen(tester);
}

Future<void> _failedInitialStartIsRecoverableAtScale(
  WidgetTester tester,
  double scale,
) async {
  await _clearMountedScreen(tester);
  final SentenceHuntTestRig rig = SentenceHuntTestRig();
  final ProviderContainer container = rig.providerContainer();
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  rig.persistence.holdNextWrite(failure: StateError('quota rejected'));
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: SentenceHuntLessonScreen(sectionId: rig.sectionId),
    ),
  ));
  await tester.pump();
  await rig.persistence.writeEntered;
  rig.persistence.releaseWrite();
  await tester.pumpAndSettle();

  expect(find.textContaining('This change could not be saved.'), findsOneWidget,
      reason: 'the pre-prompt frozen Start failure is explained at $scale×');
  expect(find.text('Retry saving'), findsOneWidget,
      reason: 'the initial Start command remains retryable at $scale×');
  expect(find.textContaining('Words with target:'), findsNothing,
      reason: 'a failed Start does not reveal key or teaching metadata');

  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  expect(find.text('Resume exercise'), findsOneWidget);
  expect(find.text('Retry saving'), findsNothing,
      reason: 'a frozen save cannot retry before explicit lifecycle recovery');
  await tester.ensureVisible(find.text('Resume exercise'));
  await tester.tap(find.text('Resume exercise'));
  await tester.pump();
  expect(find.text('Retry saving'), findsOneWidget);

  rig.persistence.holdNextWrite(failure: StateError('quota rejected again'));
  await tester.ensureVisible(find.text('Retry saving'));
  await tester.tap(find.text('Retry saving'));
  await tester.pump();
  await rig.persistence.writeEntered;
  rig.persistence.releaseWrite();
  await tester.pumpAndSettle();
  expect(find.text('Retry saving'), findsOneWidget,
      reason: 'a repeated quota failure preserves the same recovery action');

  await tester.ensureVisible(find.text('Retry saving'));
  await tester.tap(find.text('Retry saving'));
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Word 1 of 5: Tu'), findsOneWidget,
      reason: 'the acknowledged exact Start retry publishes its first prompt');
  final List<SentenceHuntCommand> starts = rig.store.submitted
      .where((SentenceHuntCommand command) =>
          command.action is StartSentenceHuntRun)
      .toList();
  expect(starts, hasLength(3));
  expect(identical(starts[0], starts[1]), isTrue);
  expect(identical(starts[1], starts[2]), isTrue);
  expect(rig.persistence.writes, 3);
  final SentenceHuntState saved = await rig.store.load();
  expect(saved.slots, hasLength(1),
      reason: 'only one initial run slot is durably started');
  expect(saved.completions, isEmpty,
      reason: 'a Start retry cannot fabricate a completion receipt');
  expect(tester.takeException(), isNull,
      reason: 'save recovery remains reachable at $scale× in 360×640');
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  tester.platformDispatcher.clearTextScaleFactorTestValue();
  await _clearMountedScreen(tester);
}

Future<void> _savedDebriefActionsWaitForResume(WidgetTester tester) async {
  await _clearMountedScreen(tester);
  final SentenceHuntTestRig rig = SentenceHuntTestRig();
  final SentenceHuntController seeded = rig.controller();
  await seeded.load();
  for (var index = 0; index < 5; index++) {
    final SentenceHuntItem item = rig.catalogue.item(
      rig.sectionId,
      'fr08-vowel-0${index + 1}',
    );
    final Future<void> playback = seeded.play();
    rig.audio.requests.last.complete();
    await playback;
    final List<String> selection = index == 0
        ? <String>[item.selectableTokenIds[1]]
        : item.expectedTokenIds;
    for (final String id in selection) {
      seeded.toggleToken(id);
    }
    await seeded.submit();
    await seeded.advance();
  }
  expect(seeded.state.phase, SentenceHuntPhase.debrief);
  seeded.dispose();

  final ProviderContainer container = rig.providerContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: SentenceHuntLessonScreen(sectionId: rig.sectionId),
    ),
  ));
  await tester.pumpAndSettle();
  expect(find.text('Sentence hunt debrief'), findsOneWidget);

  rig.persistence.holdNextWrite(failure: StateError('quota rejected'));
  await tester.ensureVisible(find.text('Finish'));
  await tester.tap(find.text('Finish'));
  await tester.pump();
  await rig.persistence.writeEntered;
  rig.persistence.releaseWrite();
  await tester.pumpAndSettle();
  expect(find.text('Retry saving'), findsOneWidget);

  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  expect(find.text('Resume exercise'), findsOneWidget);
  final Finder retry = find.widgetWithText(TextButton, 'Retry saving');
  expect(tester.widget<TextButton>(retry).onPressed, isNull,
      reason: 'debrief save retry waits for safe lifecycle recovery');
  expect(
    tester.getSemantics(retry).getSemanticsData().hasAction(
          SemanticsAction.tap,
        ),
    isFalse,
  );
  final Finder finish = find.widgetWithText(FilledButton, 'Finish');
  expect(tester.widget<FilledButton>(finish).onPressed, isNull);
  expect(find.text('Review mistakes'), findsNothing);
  final int commandsBeforeKey = rig.store.submitted.length;
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
  expect(rig.store.submitted, hasLength(commandsBeforeKey),
      reason: 'keyboard activation cannot submit another debrief action');

  await tester.ensureVisible(find.text('Resume exercise'));
  await tester.tap(find.text('Resume exercise'));
  await tester.pump();
  expect(tester.widget<TextButton>(retry).onPressed, isNotNull);
  await tester.ensureVisible(retry);
  await tester.tap(retry);
  await tester.pumpAndSettle();
  expect(find.text('Retry saving'), findsNothing);
  final SentenceHuntState saved = await rig.store.load();
  expect(saved.completions, hasLength(1));
  expect(
    rig.store.submitted.where((SentenceHuntCommand command) =>
        command.action is FinishSentenceHuntRun),
    hasLength(2),
  );
  await _clearMountedScreen(tester);
}
