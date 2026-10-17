import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_store.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/features/course/comparison_lesson_screen.dart';
import 'package:linguist/src/features/course/exercises/sound_comparison.dart';
import 'package:linguist/src/features/course/exercises/listening_exercise_contract.dart';

final class _ControlledCourseReferenceAudio implements CourseReferenceAudio {
  final requests = <({
    String referenceId,
    CourseAudioUse use,
    CourseAudioVariant variant,
    bool allowPracticeTts
  })>[];
  final pending = <Completer<CourseAudioResult>>[];
  int speakCalls = 0;
  int stopCalls = 0;
  bool throwNextPlayback = false;
  @override
  Future<CourseAudioResult> playReference(String referenceId,
      {CourseAudioUse use = CourseAudioUse.alphaPractice,
      CourseAudioVariant variant = CourseAudioVariant.normal,
      bool allowPracticeTts = false}) {
    requests.add((
      referenceId: referenceId,
      use: use,
      variant: variant,
      allowPracticeTts: allowPracticeTts
    ));
    if (throwNextPlayback) {
      throwNextPlayback = false;
      throw StateError('playback failed');
    }
    final completer = Completer<CourseAudioResult>();
    pending.add(completer);
    return completer.future;
  }

  void completeNext(CourseAudioResult result) =>
      pending.removeAt(0).complete(result);
  @override
  Future<void> speak(String word) async {
    speakCalls++;
    throw StateError('TTS forbidden');
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {}
}

Future<T> _runRealAsync<T>(
    WidgetTester tester, Future<T> Function() operation) async {
  final value = await tester.runAsync(operation);
  if (value == null) {
    throw StateError('Real-async test operation returned null');
  }
  return value;
}

ComparisonCatalogue _copyCatalogue(
  ComparisonCatalogue catalogue, {
  int revision = 1,
  bool reverse = false,
  String? firstInstruction,
  String? firstNote,
  bool changeFirstTarget = false,
  bool changeFirstSlot = false,
  bool changeSection = false,
}) {
  final records = [
    for (final exercise in catalogue.exercises)
      ComparisonExerciseDraft(
        id: exercise.id,
        activityId: exercise.activityId,
        sectionId: changeSection ? 'changed-section' : exercise.sectionId,
        contentRevision: revision,
        purpose: exercise.purpose,
        reviewState: exercise.reviewState,
        instruction: exercise.id == catalogue.exercises.first.id &&
                firstInstruction != null
            ? firstInstruction
            : exercise.instruction,
        sampleA: ComparisonSampleDraft(
          slot: changeFirstSlot && exercise.id == catalogue.exercises.first.id
              ? ComparisonSample.b
              : exercise.sampleA.slot,
          referenceId: exercise.sampleA.referenceId,
          target: ComparisonTargetDraft(
            phonemeId:
                changeFirstTarget && exercise.id == catalogue.exercises.first.id
                    ? 't'
                    : exercise.sampleA.target.phonemeId,
            phonemeOrdinal:
                changeFirstTarget && exercise.id == catalogue.exercises.first.id
                    ? 0
                    : exercise.sampleA.target.phonemeOrdinal,
          ),
        ),
        sampleB: ComparisonSampleDraft(
          slot: changeFirstSlot && exercise.id == catalogue.exercises.first.id
              ? ComparisonSample.a
              : exercise.sampleB.slot,
          referenceId: exercise.sampleB.referenceId,
          target: ComparisonTargetDraft(
            phonemeId: exercise.sampleB.target.phonemeId,
            phonemeOrdinal: exercise.sampleB.target.phonemeOrdinal,
          ),
        ),
        expectedRelation: exercise.expectedRelation,
        debriefNote:
            exercise.id == catalogue.exercises.first.id && firstNote != null
                ? firstNote
                : exercise.debriefNote,
      ),
  ];
  if (reverse) {
    final reversed = records.reversed.toList();
    return ComparisonCatalogue.fromDrafts(
      activityId: catalogue.activityId,
      sectionId: catalogue.sectionId,
      contentRevision: revision,
      exercises: reversed,
      referencePhonemes: {
        for (final entry in frenchCitationPhonemes.entries)
          'fr-word-${entry.key}': entry.value,
      },
    );
  }
  return ComparisonCatalogue.fromDrafts(
    activityId: catalogue.activityId,
    sectionId: catalogue.sectionId,
    contentRevision: revision,
    exercises: records,
    referencePhonemes: {
      for (final entry in frenchCitationPhonemes.entries)
        'fr-word-${entry.key}': entry.value,
    },
  );
}

_ComparisonWidgetStore _createComparisonStore({
  required ComparisonCatalogue catalogue,
  required _Persistence persistence,
  required LearningAuthScope auth,
  required Zone asyncZone,
  LearningAuthScope Function()? currentAuth,
  LearningOwner Function()? backendOwner,
}) =>
    _ComparisonWidgetStore(catalogue, persistence, auth,
        asyncZone: asyncZone,
        currentAuth: currentAuth,
        backendOwner: backendOwner);

final class _Persistence implements LearningPersistence {
  final values = <String, String>{};
  int reads = 0, writes = 0;
  bool failNextWrite = false;
  bool failRestore = false;
  Object? nextWriteError;
  Completer<void>? holdNextWrite;
  Completer<void>? holdNextRead;
  Completer<void>? readEntered;
  Completer<void>? writeEntered;
  Object? failAfterHeldWrite;
  @override
  Future<String?> read(String key) async {
    reads++;
    if (readEntered case final signal?) {
      readEntered = null;
      if (!signal.isCompleted) signal.complete();
    }
    final hold = holdNextRead;
    if (hold != null) {
      holdNextRead = null;
      await hold.future;
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (writeEntered case final signal?) {
      writeEntered = null;
      if (!signal.isCompleted) signal.complete();
    }
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('test write rejected');
    }
    final error = nextWriteError;
    if (error != null) {
      nextWriteError = null;
      throw error;
    }
    final hold = holdNextWrite;
    if (hold != null) {
      holdNextWrite = null;
      await hold.future;
    }
    final heldFailure = failAfterHeldWrite;
    if (heldFailure != null) {
      failAfterHeldWrite = null;
      throw heldFailure;
    }
    values[key] = value;
  }

  @override
  Future<void> restore(String key, String? lastCommitted) async {
    if (failRestore) throw StateError('test rollback unavailable');
    if (lastCommitted == null) {
      values.remove(key);
    } else {
      values[key] = lastCommitted;
    }
  }

  @override
  Future<void> reload() async {}
}

final class _ComparisonWidgetStore implements ComparisonLearningStore {
  static int _tokenNumber = 0;
  _ComparisonWidgetStore(this.catalogue, this.persistence, this.auth,
      {required Zone asyncZone,
      LearningAuthScope Function()? currentAuth,
      LearningOwner Function()? backendOwner})
      : _asyncZone = asyncZone,
        _delegate = ComparisonLearningRepository(
          scope: ComparisonProfileScope(courseId: 'en-fr', owner: auth.owner),
          authGeneration: auth.generation,
          currentAuth: currentAuth ?? () => auth,
          backendOwner: backendOwner ?? () => auth.owner,
          persistence: persistence,
          transitions: ComparisonLearningTransitionEngine(catalogue: catalogue),
          clock: () => DateTime.utc(2026, 1, 1),
          newToken: () => (++_tokenNumber).toRadixString(16).padLeft(22, 'A'),
        );
  final ComparisonCatalogue catalogue;
  final _Persistence persistence;
  final LearningAuthScope auth;
  final ComparisonLearningRepository _delegate;
  final Zone _asyncZone;
  int loadCalls = 0, prepareCalls = 0, submitCalls = 0;
  final prepared = <ComparisonLearningCommand>[];
  final submitted = <ComparisonLearningCommand>[];
  Future<T> _runInStableAsyncZone<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _asyncZone.runGuarded(() {
      Future<T>.sync(operation).then(
        result.complete,
        onError: (Object error, StackTrace stackTrace) {
          result.completeError(error, stackTrace);
        },
      );
    });
    return result.future;
  }

  @override
  ComparisonProfileScope get scope => _delegate.scope;
  @override
  Future<ComparisonLearningState> load() {
    loadCalls++;
    return _runInStableAsyncZone(_delegate.load);
  }

  @override
  Future<ComparisonLearningState> retryLoad() =>
      _runInStableAsyncZone(_delegate.retryLoad);
  @override
  ComparisonLearningCommand prepare(
      {required ComparisonLearningState state,
      required String activityId,
      required ComparisonAction action}) {
    prepareCalls++;
    final command =
        _delegate.prepare(state: state, activityId: activityId, action: action);
    prepared.add(command);
    return command;
  }

  @override
  Future<ComparisonCommit> submit(ComparisonLearningCommand command) {
    submitCalls++;
    submitted.add(command);
    return _runInStableAsyncZone(() => _delegate.submit(command));
  }

  Future<ComparisonLearningState> readSnapshot() =>
      _runInStableAsyncZone(_delegate.load);
}

Future<ComparisonLearningState> _readSnapshot(
        WidgetTester tester, _ComparisonWidgetStore store) =>
    _runRealAsync(tester, store.readSnapshot);

Future<ProviderContainer> _mountComparison(
  WidgetTester tester, {
  required _ComparisonWidgetStore store,
  required _ControlledCourseReferenceAudio audio,
  required ComparisonCatalogue catalogue,
  bool review = false,
  LessonPolicy? policy,
  String? pairId,
  String activityId = comparisonActivityId,
  ComparisonCatalogue Function()? loader,
  VoidCallback? onStoreFactory,
  VoidCallback? onCatalogueFactory,
  VoidCallback? onStateFactory,
  VoidCallback? onAudioFactory,
  GoRouter? router,
  bool pumpInitialReadBarrier = true,
  LearningAuthTracker? authTracker,
  _ComparisonWidgetStore Function(LearningAuthScope auth)? storeForAuth,
  Key? screenKey,
}) async {
  final container = ProviderContainer(overrides: [
    learningAuthScopeProvider.overrideWith((ref) =>
        authTracker ??
        LearningAuthTracker(owner: store.scope.owner, ready: true)),
    comparisonCatalogueProvider.overrideWith((ref) {
      onCatalogueFactory?.call();
      return catalogue;
    }),
    comparisonLearningStoreProvider.overrideWith((ref) {
      onStoreFactory?.call();
      if (storeForAuth != null) {
        ref.watch(learningAuthScopeProvider
            .select((auth) => (auth.owner, auth.generation)));
        return storeForAuth(ref.read(learningAuthScopeProvider));
      }
      return store;
    }),
    comparisonLearningStateProvider.overrideWith((ref) {
      onStateFactory?.call();
      return Future<ComparisonLearningState>.error(StateError('unused state'));
    }),
    courseReferenceAudioProvider.overrideWith((ref) {
      onAudioFactory?.call();
      return audio;
    }),
    courseAudioProvider
        .overrideWith((ref) => throw StateError('legacy audio forbidden')),
  ]);
  final screen = ComparisonLessonScreen(
    key: screenKey,
    activityId: activityId,
    review: review,
    policy: policy,
    pairId: pairId,
    catalogueLoader: loader ?? () => catalogue,
  );
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: router == null
          ? MaterialApp(home: screen)
          : MaterialApp.router(routerConfig: router)));
  for (var i = 0; i < 20; i++) {
    if (find.text('Listen to sample A').evaluate().isNotEmpty ||
        find.text('Comparison debrief').evaluate().isNotEmpty ||
        find.text('Comparison complete.').evaluate().isNotEmpty ||
        find
            .text('This comparison activity is unavailable.')
            .evaluate()
            .isNotEmpty) {
      break;
    }
    if (pumpInitialReadBarrier &&
        find
            .text('This comparison activity is unavailable.')
            .evaluate()
            .isEmpty) {
      await tester.runAsync(store.readSnapshot);
    }
    await tester.pump();
  }
  if (find.text('Listen to sample A').evaluate().isNotEmpty) {
    // Drain the acknowledged start's known widget/future continuations before
    // the test ends and its owner is disposed.
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }
  return container;
}

Future<ComparisonLearningState> _seedFirstPass(
  WidgetTester tester,
  _ComparisonWidgetStore store, {
  required ComparisonCatalogue catalogue,
  required LessonPolicy policy,
  Set<int> wrongIndexes = const {},
}) =>
    _runRealAsync(
        tester,
        () => _seedFirstPassWork(store,
            catalogue: catalogue, policy: policy, wrongIndexes: wrongIndexes));

Future<ComparisonLearningState> _seedFirstPassWork(
  _ComparisonWidgetStore store, {
  required ComparisonCatalogue catalogue,
  required LessonPolicy policy,
  Set<int> wrongIndexes = const {},
}) async {
  var state = await store.load();
  var command = store.prepare(
      state: state,
      activityId: comparisonActivityId,
      action:
          StartComparisonRun(sessionId: 'seeded-finite-run', policy: policy));
  state = (await store.submit(command)).state;
  for (var i = 0; i < catalogue.exercises.length; i++) {
    final slot = state.slot!;
    final session = LessonSectionSession.fromJson(
      Map<String, dynamic>.from(slot.checkpoint.sessionJson),
      itemIds: catalogue.exercises.map((e) => e.id).toList(),
      contentRevision: catalogue.contentRevision,
    );
    final exercise = catalogue.exercise(session.currentItemId!);
    final correct = !wrongIndexes.contains(i);
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
          uiGeneration: 0,
        ),
    ];
    command = store.prepare(
      state: state,
      activityId: comparisonActivityId,
      action: AnswerComparisonPair(ComparePhonemesAnswer(
          selectedRelation: selected,
          expectedRelationSnapshot: exercise.expectedRelation,
          observations: observations)),
    );
    state = (await store.submit(command)).state;
    command = store.prepare(
        state: state,
        activityId: comparisonActivityId,
        action: const AdvanceComparisonPair());
    state = (await store.submit(command)).state;
  }
  return state;
}

Future<ComparisonLearningState> _seedAnsweredFirst(WidgetTester tester,
        _ComparisonWidgetStore store, ComparisonCatalogue catalogue) =>
    _runRealAsync(tester, () => _seedAnsweredFirstWork(store, catalogue));

Future<ComparisonLearningState> _seedAnsweredFirstWork(
    _ComparisonWidgetStore store, ComparisonCatalogue catalogue) async {
  var state = await store.load();
  var command = store.prepare(
      state: state,
      activityId: comparisonActivityId,
      action: StartComparisonRun(
          sessionId: 'seeded-answered-run', policy: LessonPolicy()));
  state = (await store.submit(command)).state;
  final slot = state.slot!;
  final exercise = catalogue.exercises.first;
  final observations = [
    for (final sample in [exercise.sampleA, exercise.sampleB])
      ComparisonPlaybackObservation(
        slot: sample.slot,
        referenceId: sample.referenceId,
        outcome: CourseAudioOutcome.completed,
        source: CourseAudioSource.unverifiedRecording,
        activityId: comparisonActivityId,
        runGeneration: slot.cursor.generation,
        round: 1,
        pairId: exercise.id,
        profile: slot.scope,
        uiGeneration: 0,
      ),
  ];
  command = store.prepare(
      state: state,
      activityId: comparisonActivityId,
      action: AnswerComparisonPair(ComparePhonemesAnswer(
          selectedRelation: exercise.expectedRelation,
          expectedRelationSnapshot: exercise.expectedRelation,
          observations: observations)));
  return (await store.submit(command)).state;
}

Future<void> _answerVisiblePair(
  WidgetTester tester,
  _ComparisonWidgetStore store,
  _ControlledCourseReferenceAudio audio,
  ComparisonCatalogue catalogue, {
  required int exerciseIndex,
  required bool correct,
}) async {
  final exercise = catalogue.exercises[exerciseIndex];
  await tester.tap(find.text('Listen to sample A'));
  audio.completeNext(CourseAudioResult.completed(
      referenceId: exercise.sampleA.referenceId,
      source: CourseAudioSource.unverifiedRecording));
  await tester.pump();
  await tester.tap(find.text('Listen to sample B'));
  audio.completeNext(CourseAudioResult.completed(
      referenceId: exercise.sampleB.referenceId,
      source: CourseAudioSource.unverifiedRecording));
  await tester.pump();
  final relation = correct
      ? exercise.expectedRelation
      : exercise.expectedRelation == PhonemeRelation.same
          ? PhonemeRelation.different
          : PhonemeRelation.same;
  await tester
      .tap(find.text(relation == PhonemeRelation.same ? 'Same' : 'Different'));
  await _readSnapshot(tester, store);
  await tester.pump();
  for (var i = 0; i < 20 && find.text('Continue').evaluate().isEmpty; i++) {
    await tester.pump();
  }
  await tester.tap(find.text('Continue'));
  await _readSnapshot(tester, store);
  await tester.pump();
  for (var i = 0;
      i < 40 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
      i++) {
    await tester.pump();
  }
  await tester.pump();
}

void main() {
  final catalogue = loadFrenchComparisonCatalogue();
  var ownerNumber = 0;
  Future<
      ({
        _Persistence persistence,
        LearningAuthScope auth,
        _ComparisonWidgetStore store,
        _ControlledCourseReferenceAudio audio
      })> harness(WidgetTester tester) async {
    late final Zone asyncZone;
    await tester.runAsync(() async {
      asyncZone = Zone.current;
    });
    final persistence = _Persistence();
    final auth = LearningAuthScope(
        owner: LearningOwner.account('comparison-test-${++ownerNumber}'),
        generation: 0,
        ready: true);
    return (
      persistence: persistence,
      auth: auth,
      store: _ComparisonWidgetStore(catalogue, persistence, auth,
          asyncZone: asyncZone),
      audio: _ControlledCourseReferenceAudio(),
    );
  }

  void cleanup(
      ProviderContainer container, _ControlledCourseReferenceAudio audio) {
    for (final pending in audio.pending) {
      if (!pending.isCompleted) {
        pending.complete(const CourseAudioResult.cancelled());
      }
    }
    container.dispose();
  }

  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
      await tester.pump();
    }
  }

  testWidgets('comparison_view_is_neutral_and_accessible', (tester) async {
    final semantics = tester.ensureSemantics();
    final h = await harness(tester);
    final neutralCatalogue = _copyCatalogue(
      catalogue,
      firstNote: 'HIDDEN-NOTE-SENTINEL-9F4C',
    );
    final store = _createComparisonStore(
        catalogue: neutralCatalogue,
        persistence: h.persistence,
        auth: h.auth,
        asyncZone: h.store._asyncZone);
    final container = await _mountComparison(tester,
        store: store, audio: h.audio, catalogue: neutralCatalogue);
    addTearDown(() => cleanup(container, h.audio));
    expect(find.text('Compare the vowel in each sample.'), findsOneWidget);
    expect(find.text('Listen to sample A'), findsOneWidget);
    expect(find.text('Listen to sample B'), findsOneWidget);
    expect(find.text('Same'), findsOneWidget);
    expect(find.text('Different'), findsOneWidget);
    for (final sentinel in [
      'HIDDEN-NOTE-SENTINEL-9F4C',
      'fr07b-pair-01',
      'fr-word-tout',
      'tout',
      '/u/',
      'meaning',
    ]) {
      expect(find.textContaining(sentinel), findsNothing, reason: sentinel);
      expect(find.byTooltip(sentinel), findsNothing, reason: sentinel);
      expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(sentinel))), findsNothing,
          reason: sentinel);
    }
    final semanticNodes = <SemanticsNode>[];
    void visitSemantics(SemanticsNode node) {
      semanticNodes.add(node);
      node.visitChildren((child) {
        visitSemantics(child);
        return true;
      });
    }

    visitSemantics(tester
        .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    final semanticStrings = semanticNodes
        .expand((node) => [
              node.getSemanticsData().label,
              node.getSemanticsData().value,
              node.getSemanticsData().hint,
              node.getSemanticsData().tooltip,
            ])
        .join('\n');
    for (final sentinel in [
      'HIDDEN-NOTE-SENTINEL-9F4C',
      'fr07b-pair-01',
      'fr-word-tout',
      'tout',
      '/u/',
    ]) {
      expect(semanticStrings, isNot(contains(sentinel)), reason: sentinel);
    }
    expect(tester.getSemantics(find.text('Listen to sample A')).label,
        'Listen to sample A');
    expect(tester.getSemantics(find.text('Listen to sample B')).label,
        'Listen to sample B');
    for (final relation in ['Same', 'Different']) {
      final semanticButton = find.bySemanticsLabel(relation);
      expect(semanticButton, findsOneWidget);
      expect(
          tester
              .getSemantics(semanticButton)
              .getSemanticsData()
              .flagsCollection
              .isEnabled
              .name,
          'isFalse');
    }
    expect(
        find.text(
            'Alpha audio: recordings are unverified; device speech is practice-only.'),
        findsOneWidget);
    semantics.dispose();
  });

  testWidgets('comparison active and debrief scale and scroll matrix',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    for (final scale in [2.0, 3.0]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final h = await harness(tester);
      final container = await _mountComparison(tester,
          store: h.store, audio: h.audio, catalogue: catalogue);
      expect(find.text('Compare the vowel in each sample.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in [
        'Listen to sample A',
        'Listen to sample B',
        'Same',
        'Different',
      ]) {
        await tester.ensureVisible(find.text(label));
        expect(find.text(label), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Listen to sample A'));
      await tester.tap(find.text('Listen to sample A'));
      h.audio.completeNext(const CourseAudioResult.completed(
          referenceId: 'fr-word-tout',
          source: CourseAudioSource.unverifiedRecording));
      await tester.pump();
      await tester.ensureVisible(find.text('Listen to sample B'));
      await tester.tap(find.text('Listen to sample B'));
      h.audio.completeNext(const CourseAudioResult.completed(
          referenceId: 'fr-word-tu',
          source: CourseAudioSource.unverifiedRecording));
      await tester.pump();
      await tester.ensureVisible(find.text('Same'));
      await tester.tap(find.text('Same'));
      await _readSnapshot(tester, h.store);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(find.text('Not yet'), findsOneWidget);
      await tester.ensureVisible(find.text('Continue'));
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'active layout at text scale $scale');
      await tester.pumpWidget(const SizedBox.shrink());
      cleanup(container, h.audio);
      final debriefHarness = await harness(tester);
      final debriefCatalogue = _copyCatalogue(catalogue,
          firstNote: 'HIDDEN-REVIEW-NOTE-SENTINEL-C31A');
      final debriefStore = _createComparisonStore(
          catalogue: debriefCatalogue,
          persistence: debriefHarness.persistence,
          auth: debriefHarness.auth,
          asyncZone: debriefHarness.store._asyncZone);
      await _seedFirstPass(tester, debriefStore,
          catalogue: debriefCatalogue,
          policy: LessonPolicy(),
          wrongIndexes: {0});
      final debriefContainer = await _mountComparison(tester,
          store: debriefStore,
          audio: debriefHarness.audio,
          catalogue: debriefCatalogue);
      addTearDown(() => cleanup(debriefContainer, debriefHarness.audio));
      expect(find.text('Comparison debrief'), findsOneWidget);
      expect(
          find.text(
              'Compare only the designated sound in each sample. Same means those two target phonemes are identical; Different means they are not. Ignore the rest of the word.'),
          findsOneWidget);
      for (final label in [
        'Review unresolved pairs',
        'Finish comparison',
        'Practise again',
      ]) {
        if (find.text(label).evaluate().isNotEmpty) {
          await tester.ensureVisible(find.text(label));
        }
      }
      expect(find.text('Review unresolved pairs'), findsOneWidget);
      expect(find.text('Finish comparison'), findsOneWidget);
      expect(find.text('Practise again'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'debrief layout at text scale $scale');
      await tester.ensureVisible(find.text('Review unresolved pairs'));
      await tester.tap(find.text('Review unresolved pairs'));
      await _readSnapshot(tester, debriefStore);
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      expect(find.text('Comparison debrief'), findsNothing);
      expect(find.textContaining('HIDDEN-REVIEW-NOTE-SENTINEL-C31A'),
          findsNothing);
      final reviewRoot = tester
          .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;
      final reviewNodes = <SemanticsNode>[];
      void visitReview(SemanticsNode node) {
        reviewNodes.add(node);
        node.visitChildren((child) {
          visitReview(child);
          return true;
        });
      }

      visitReview(reviewRoot);
      final reviewSemantics = reviewNodes
          .expand((node) => [
                node.getSemanticsData().label,
                node.getSemanticsData().value,
                node.getSemanticsData().hint,
                node.getSemanticsData().tooltip,
              ])
          .join('\n');
      expect(
          reviewSemantics, isNot(contains('HIDDEN-REVIEW-NOTE-SENTINEL-C31A')));
      expect(reviewSemantics,
          isNot(contains('Compare only the designated sound')));
      await tester.pumpWidget(const SizedBox.shrink());
      cleanup(debriefContainer, debriefHarness.audio);
    }
  });

  testWidgets('keyboard hearing and relation activation claims once',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final h = await harness(tester);
    final gate = await _runRealAsync(tester, () async => Completer<void>());
    final entered = await _runRealAsync(tester, () async => Completer<void>());
    ProviderContainer? container;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      if (container != null) cleanup(container, h.audio);
    });
    container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    h.persistence.holdNextWrite = gate;
    h.persistence.writeEntered = entered;

    Future<void> focusControl(String label) async {
      for (var i = 0; i < 20; i++) {
        final finder = find.bySemanticsLabel(label);
        if (finder.evaluate().isNotEmpty &&
            tester
                    .getSemantics(finder)
                    .getSemanticsData()
                    .flagsCollection
                    .isFocused ==
                Tristate.isTrue) {
          return;
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      fail('Tab did not focus $label');
    }

    Future<void> activate() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
    }

    tester.binding.focusManager.primaryFocus?.unfocus();
    await focusControl('Listen to sample A');
    await activate();
    expect(h.audio.requests.single.referenceId, 'fr-word-tout');
    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tout',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    await focusControl('Listen to sample B');
    await activate();
    expect(h.audio.requests.last.referenceId, 'fr-word-tu');
    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tu',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    await focusControl('Different');
    final preparesBefore = h.store.prepareCalls;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.runAsync(() => entered.future);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(h.store.prepareCalls, preparesBefore + 1);
    expect(h.store.submitted.where((c) => c.action is AnswerComparisonPair),
        hasLength(1));
    expect(find.text('Playback in progress'), findsNothing);
    expect(tester.takeException(), isNull);
    gate.complete();
    await _readSnapshot(tester, h.store);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    semantics.dispose();
  });

  testWidgets('same owner unready then ready fences and recovers in place',
      (tester) async {
    final h = await harness(tester);
    final tracker = LearningAuthTracker(owner: h.auth.owner, ready: true);
    final store = _createComparisonStore(
        catalogue: catalogue,
        persistence: h.persistence,
        auth: tracker.current,
        asyncZone: h.store._asyncZone,
        currentAuth: () => tracker.current,
        backendOwner: () => tracker.current.owner);
    final container = await _mountComparison(tester,
        store: store,
        audio: h.audio,
        catalogue: catalogue,
        authTracker: tracker,
        screenKey: const ValueKey('auth-readiness'));
    addTearDown(() => cleanup(container, h.audio));
    await tester.tap(find.text('Listen to sample A'));
    expect(h.audio.pending, hasLength(1));
    tracker.observe(owner: h.auth.owner, ready: false);
    await tester.pump();
    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tout',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        isEmpty);
    tracker.observe(owner: h.auth.owner, ready: true);
    await tester.pump();
    expect(find.text('Listen to sample A'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(h.audio.requests, hasLength(1));
    expect(h.store.prepared.where((c) => c.action is AnswerComparisonPair),
        isEmpty);
    await tester.tap(find.text('Listen to sample A'));
    expect(h.audio.requests, hasLength(2));
  });

  testWidgets(
      'same keyed context rebuild is stable and invalid pair is neutral',
      (tester) async {
    final h = await harness(tester);
    const key = ValueKey('comparison-context');
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue, screenKey: key);
    addTearDown(() => cleanup(container, h.audio));
    final initialLoads = h.store.loadCalls;
    for (final sample in [
      ('Listen to sample A', 'fr-word-tout'),
      ('Listen to sample B', 'fr-word-tu'),
    ]) {
      await tester.tap(find.text(sample.$1));
      h.audio.completeNext(CourseAudioResult.completed(
          referenceId: sample.$2,
          source: CourseAudioSource.unverifiedRecording));
      await tester.pump();
    }
    expect(h.store.loadCalls, initialLoads);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: ComparisonLessonScreen(
                key: key,
                activityId: comparisonActivityId,
                catalogueLoader: () => catalogue))));
    await tester.pump();
    expect(h.store.loadCalls, initialLoads);
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        {ComparisonSample.a, ComparisonSample.b});

    await tester.tap(find.text('Listen to sample A'));
    expect(h.audio.pending, hasLength(1));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: ComparisonLessonScreen(
                key: key,
                activityId: comparisonActivityId,
                pairId: 'fr07b-pair-99',
                catalogueLoader: () => catalogue))));
    await tester.pump();
    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tout',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    expect(
        find.text('This comparison activity is unavailable.'), findsOneWidget);
    expect(h.store.loadCalls, initialLoads);
    expect(h.store.prepareCalls, 1);
    expect(h.audio.stopCalls, greaterThanOrEqualTo(1));
    expect(find.text('Listen to sample A'), findsNothing);
  });

  testWidgets('same keyed invalid activity retires context before store access',
      (tester) async {
    final h = await harness(tester);
    const key = ValueKey('invalid-activity-context');
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue, screenKey: key);
    addTearDown(() => cleanup(container, h.audio));
    final reads = h.store.loadCalls;
    final prepares = h.store.prepareCalls;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: ComparisonLessonScreen(
                key: key,
                activityId: 'not-the-comparison-activity',
                catalogueLoader: () => catalogue))));
    await tester.pump();
    expect(
        find.text('This comparison activity is unavailable.'), findsOneWidget);
    expect(h.store.loadCalls, reads);
    expect(h.store.prepareCalls, prepares);
    expect(find.text('Listen to sample A'), findsNothing);
  });

  testWidgets('content changed save claim requires explicit reload',
      (tester) async {
    final h = await harness(tester);
    final screen = ComparisonLessonScreen(
        activityId: comparisonActivityId, catalogueLoader: () => catalogue);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, state) => const Text('Home'),
          routes: [
            GoRoute(path: 'compare', builder: (context, state) => screen),
            GoRoute(
                path: 'other',
                builder: (context, state) => const Text('Covered route')),
          ]),
    ], initialLocation: '/compare');
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue, router: router);
    addTearDown(() {
      cleanup(container, h.audio);
      router.dispose();
    });
    for (final sample in [
      ('Listen to sample A', 'fr-word-tout'),
      ('Listen to sample B', 'fr-word-tu'),
    ]) {
      await tester.tap(find.text(sample.$1));
      h.audio.completeNext(CourseAudioResult.completed(
          referenceId: sample.$2,
          source: CourseAudioSource.unverifiedRecording));
      await tester.pump();
    }
    h.persistence.nextWriteError = const LearningContentChangedException();
    await tester.tap(find.text('Different'));
    await _readSnapshot(tester, h.store);
    await tester.pump();
    expect(find.text('Reload saved progress'), findsOneWidget);
    expect(find.text('Retry saving'), findsNothing);
    final count = h.store.submitCalls;
    router.push('/other');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Covered route'), findsOneWidget);
    expect(find.text('Retry saving'), findsNothing);
    router.pop();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Reload saved progress'), findsOneWidget);
    expect(h.store.submitCalls, count);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final pausedRequests = h.audio.requests.length;
    await tester.tap(find.text('Listen to sample A'), warnIfMissed: false);
    expect(h.audio.requests, hasLength(pausedRequests));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(h.store.submitCalls, count);
  });

  testWidgets('A to B to A ignores old audio and uses shared auth generation',
      (tester) async {
    final h = await harness(tester);
    final tracker = LearningAuthTracker(owner: h.auth.owner, ready: true);
    final stores = <(LearningOwner, int), _ComparisonWidgetStore>{};
    _ComparisonWidgetStore storeFor(LearningAuthScope auth) =>
        stores.putIfAbsent(
            (auth.owner, auth.generation),
            () => _createComparisonStore(
                catalogue: catalogue,
                persistence: h.persistence,
                auth: auth,
                asyncZone: h.store._asyncZone,
                currentAuth: () => tracker.current,
                backendOwner: () => tracker.current.owner));
    final initial = storeFor(tracker.current);
    final container = await _mountComparison(tester,
        store: initial,
        audio: h.audio,
        catalogue: catalogue,
        authTracker: tracker,
        storeForAuth: storeFor);
    addTearDown(() => cleanup(container, h.audio));
    await tester.tap(find.text('Listen to sample A'));
    expect(h.audio.pending, hasLength(1));

    final ownerB = LearningOwner.account('comparison-owner-b-${ownerNumber++}');
    tracker.observe(owner: ownerB, ready: true);
    final storeB = storeFor(tracker.current);
    await _readSnapshot(tester, storeB);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    tracker.observe(owner: h.auth.owner, ready: true);
    expect(tracker.current.generation, 2);
    final storeAAgain = storeFor(tracker.current);
    await _readSnapshot(tester, storeAAgain);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await _readSnapshot(tester, storeAAgain);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(find.text('Listen to sample A'), findsOneWidget);
    await tester.tap(find.text('Listen to sample A'));
    expect(h.audio.pending, hasLength(2));
    final stopsBeforeOldResult = h.audio.stopCalls;
    h.audio.completeNext(const CourseAudioResult.failed(
      referenceId: 'fr-word-tout',
      failure: CourseAudioFailure(
          reason: CourseAudioFailureReason.unsupportedPlayback),
    ));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(h.audio.stopCalls, stopsBeforeOldResult);
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        isEmpty);
    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tout',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        {ComparisonSample.a});
    expect(stores.keys, contains((h.auth.owner, 0)));
    expect(stores.keys, contains((ownerB, 1)));
    expect(stores.keys, contains((h.auth.owner, 2)));
  });

  testWidgets('A to B to A held old load cannot prevent exactly one new Start',
      (tester) async {
    final h = await harness(tester);
    final tracker = LearningAuthTracker(owner: h.auth.owner, ready: true);
    final stores = <(LearningOwner, int), _ComparisonWidgetStore>{};
    _ComparisonWidgetStore storeFor(LearningAuthScope auth) =>
        stores.putIfAbsent(
            (auth.owner, auth.generation),
            () => _createComparisonStore(
                catalogue: catalogue,
                persistence: h.persistence,
                auth: auth,
                asyncZone: h.store._asyncZone,
                currentAuth: () => tracker.current,
                backendOwner: () => tracker.current.owner));
    final initial = storeFor(tracker.current);
    final gates = await _runRealAsync<(Completer<void>, Completer<void>)>(
      tester,
      () async => (Completer<void>(), Completer<void>()),
    );
    final (oldRead, oldReadEntered) = gates;
    h.persistence.holdNextRead = oldRead;
    h.persistence.readEntered = oldReadEntered;
    ProviderContainer? container;
    addTearDown(() {
      if (!oldRead.isCompleted) oldRead.complete();
      final mounted = container;
      if (mounted != null) cleanup(mounted, h.audio);
    });
    // Signal the real persistence boundary; the fixture's initial-load pump is
    // disabled so it cannot accidentally release or await this held read.
    container = await _mountComparison(tester,
        store: initial,
        audio: h.audio,
        catalogue: catalogue,
        authTracker: tracker,
        storeForAuth: storeFor,
        pumpInitialReadBarrier: false);
    await tester.runAsync(() => oldReadEntered.future);
    tracker.observe(
        owner: LearningOwner.account('comparison-held-b-${ownerNumber++}'),
        ready: true);
    storeFor(tracker.current);
    await tester.pump();
    tracker.observe(owner: h.auth.owner, ready: true);
    final returnedA = storeFor(tracker.current);
    await tester.pump();
    oldRead.complete();
    await _readSnapshot(tester, returnedA);
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(returnedA.submitCalls, 1,
        reason: 'the current A generation must submit one Start');
    final beforeAck = returnedA.submitted.single;
    expect(beforeAck.action, isA<StartComparisonRun>());
    expect(h.persistence.writes, 0,
        reason: 'the Start must still be unacknowledged before the barrier');
    final acked = await _readSnapshot(tester, returnedA);
    expect(acked.slot, isNotNull,
        reason: 'the post-submit read must wait for the Start ACK');
    expect(h.persistence.writes, 1);
    for (var i = 0; i < 20; i++) {
      await tester.pump();
    }
    expect(initial.submitCalls, 0, reason: 'the stale load must not Start');
    expect(returnedA.submitCalls, 1,
        reason: 'the current A generation must Start exactly once');
    expect(find.text('Listen to sample A'), findsOneWidget,
        reason: 'the current prompt must publish after the ACK');
  });

  testWidgets('A to B to A entered Finish ACK persists without old UI effects',
      (tester) async {
    final h = await harness(tester);
    final tracker = LearningAuthTracker(owner: h.auth.owner, ready: true);
    final stores = <(LearningOwner, int), _ComparisonWidgetStore>{};
    _ComparisonWidgetStore storeFor(LearningAuthScope auth) =>
        stores.putIfAbsent(
            (auth.owner, auth.generation),
            () => _createComparisonStore(
                catalogue: catalogue,
                persistence: h.persistence,
                auth: auth,
                asyncZone: h.store._asyncZone,
                currentAuth: () => tracker.current,
                backendOwner: () => tracker.current.owner));
    final initial = storeFor(tracker.current);
    await _seedFirstPass(tester, initial,
        catalogue: catalogue, policy: LessonPolicy());
    final storageKey = initial.scope.storageKey;
    final bytesBefore = h.persistence.values[storageKey];
    final gate = Completer<void>();
    final entered = Completer<void>();
    h.persistence.holdNextWrite = gate;
    h.persistence.writeEntered = entered;
    final screen = ComparisonLessonScreen(
        activityId: comparisonActivityId, catalogueLoader: () => catalogue);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, state) => const Text('Home'),
          routes: [
            GoRoute(path: 'compare', builder: (context, state) => screen),
          ]),
    ], initialLocation: '/compare');
    ProviderContainer? container;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      final mounted = container;
      if (mounted != null) cleanup(mounted, h.audio);
      router.dispose();
    });
    container = await _mountComparison(tester,
        store: initial,
        audio: h.audio,
        catalogue: catalogue,
        router: router,
        authTracker: tracker,
        storeForAuth: storeFor);
    await tester.tap(find.text('Finish comparison'));
    for (var i = 0; i < 10 && !entered.isCompleted; i++) {
      await tester.pump();
    }
    await _runRealAsync(tester, () async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return true;
    });
    final frozenFinish = initial.submitted.last;
    expect(frozenFinish.action, isA<FinishComparisonRun>());
    await tester.runAsync(() => entered.future);
    tracker.observe(
        owner: LearningOwner.account('comparison-finish-b-${ownerNumber++}'),
        ready: true);
    tracker.observe(owner: h.auth.owner, ready: true);
    final returnedA = storeFor(tracker.current);
    final stopsBeforeOldAck = h.audio.stopCalls;
    gate.complete();
    await _runRealAsync(tester, () async {
      await Future<void>.delayed(Duration.zero);
      return true;
    });
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    final durable = await _readSnapshot(tester, returnedA);
    expect(h.persistence.values[storageKey], isNot(bytesBefore));
    expect(durable.completions, hasLength(1));
    expect(
        (frozenFinish.action as FinishComparisonRun).recordCompletion, isTrue);
    expect(identical(initial.submitted.last, frozenFinish), isTrue);
    expect(h.audio.stopCalls, stopsBeforeOldAck);
    expect(router.routeInformationProvider.value.uri.path, '/compare');
    expect(find.text('Comparison complete.'), findsNothing);
    expect(find.text('Retry saving'), findsNothing);
  });

  testWidgets(
      'same keyed review change during entered Finish keeps old ACK inert',
      (tester) async {
    final h = await harness(tester);
    final gate = await _runRealAsync<Completer<void>>(
        tester, () async => Completer<void>());
    final entered = await _runRealAsync<Completer<void>>(
        tester, () async => Completer<void>());
    final store = h.store;
    await _seedFirstPass(tester, store,
        catalogue: catalogue, policy: LessonPolicy());
    final storageKey = store.scope.storageKey;
    final bytesBefore = h.persistence.values[storageKey];
    h.persistence.holdNextWrite = gate;
    h.persistence.writeEntered = entered;
    const key = ValueKey('review-context-during-finish');
    ProviderContainer? container;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      final mounted = container;
      if (mounted != null) cleanup(mounted, h.audio);
    });
    container = await _mountComparison(tester,
        store: store, audio: h.audio, catalogue: catalogue, screenKey: key);
    await tester.tap(find.text('Finish comparison'));
    await tester.runAsync(() => entered.future);
    final frozen = store.submitted.last;
    expect(frozen.action, isA<FinishComparisonRun>());
    expect((frozen.action as FinishComparisonRun).recordCompletion, isTrue);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: ComparisonLessonScreen(
                key: key,
                activityId: comparisonActivityId,
                review: true,
                catalogueLoader: () => catalogue))));
    gate.complete();
    final durable = await _readSnapshot(tester, store);
    expect(durable.completions, hasLength(1));
    expect(h.persistence.values[storageKey], isNot(bytesBefore));
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }
    expect(find.text('Comparison complete.'), findsNothing);
    expect(find.text('Comparison debrief'), findsOneWidget,
        reason: 'the new review context stays on its usable debrief');
    expect(find.text('Finish comparison'), findsOneWidget);
    expect(identical(store.submitted.last, frozen), isTrue);
  });

  testWidgets('auth changes while paused and covered coalesce to one recovery',
      (tester) async {
    final h = await harness(tester);
    final tracker = LearningAuthTracker(owner: h.auth.owner, ready: true);
    final stores = <(LearningOwner, int), _ComparisonWidgetStore>{};
    _ComparisonWidgetStore storeFor(LearningAuthScope auth) =>
        stores.putIfAbsent(
            (auth.owner, auth.generation),
            () => _createComparisonStore(
                catalogue: catalogue,
                persistence: h.persistence,
                auth: auth,
                asyncZone: h.store._asyncZone,
                currentAuth: () => tracker.current,
                backendOwner: () => tracker.current.owner));
    final initial = storeFor(tracker.current);
    final screen = ComparisonLessonScreen(
        activityId: comparisonActivityId, catalogueLoader: () => catalogue);
    final router = GoRouter(routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(
              path: '/compare',
              pageBuilder: (context, state) => NoTransitionPage(child: screen)),
          GoRoute(
              path: '/other',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: Text('Covered route'))),
        ],
      ),
    ], initialLocation: '/compare');
    final container = await _mountComparison(tester,
        store: initial,
        audio: h.audio,
        catalogue: catalogue,
        router: router,
        authTracker: tracker,
        storeForAuth: storeFor);
    addTearDown(() {
      cleanup(container, h.audio);
      router.dispose();
    });
    final startCount = initial.submitted
        .where((command) => command.action is StartComparisonRun)
        .length;
    final playbackCount = h.audio.requests.length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    router.push('/other');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final ownerB =
        LearningOwner.account('comparison-paused-b-${ownerNumber++}');
    tracker.observe(owner: ownerB, ready: true);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    tracker.observe(owner: h.auth.owner, ready: true);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final returnedA = storeFor(tracker.current);
    expect(returnedA.loadCalls, 0);
    expect(returnedA.submitCalls, 0);
    expect(h.audio.requests, hasLength(playbackCount));
    expect(router.routeInformationProvider.value.uri.path, '/other');
    router.go('/compare');
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await _readSnapshot(tester, returnedA);
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(returnedA.loadCalls, 1,
        reason: 'resume and uncover should coalesce to one restore');
    expect(returnedA.prepared.where((c) => c.action is StartComparisonRun),
        isEmpty,
        reason: 'restored saved run must not gain a hidden duplicate Start');
    expect(returnedA.submitCalls, 0);
    expect(h.audio.requests, hasLength(playbackCount));
    expect(find.text('Listen to sample A'), findsOneWidget);
    expect(
        initial.submitted
            .where((command) => command.action is StartComparisonRun),
        hasLength(startCount));
  });

  for (final rawCase in ['malformed JSON', 'future schema']) {
    testWidgets('raw $rawCase remains untouched and retry is read-only',
        (tester) async {
      final h = await harness(tester);
      final key = h.store.scope.storageKey;
      if (rawCase == 'malformed JSON') {
        h.persistence.values[key] = '{not-json';
      } else {
        await _seedFirstPass(tester, h.store,
            catalogue: catalogue, policy: LessonPolicy());
        final document =
            jsonDecode(h.persistence.values[key]!) as Map<String, dynamic>;
        document['schemaVersion'] = 2;
        h.persistence.values[key] = jsonEncode(document);
      }
      final rawBefore = h.persistence.values[key]!;
      const siblingKey = 'course.learning.v2.sibling-sentinel';
      h.persistence.values[siblingKey] = '{"keep":"exact-v2-bytes"}';
      final siblingBefore = h.persistence.values[siblingKey];
      final writesBefore = h.persistence.writes;
      final preparesBefore = h.store.prepareCalls;
      final submitsBefore = h.store.submitCalls;
      final initialReadEntered =
          await _runRealAsync(tester, () async => Completer<void>());
      h.persistence.readEntered = initialReadEntered;
      final container = await _mountComparison(tester,
          store: h.store,
          audio: h.audio,
          catalogue: catalogue,
          pumpInitialReadBarrier: false);
      addTearDown(() => cleanup(container, h.audio));
      await tester.runAsync(() => initialReadEntered.future);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(
          find.text(
              'Saved comparison progress is unavailable. Reload to continue.'),
          findsOneWidget);
      expect(find.text('Retry loading'), findsOneWidget);
      expect(h.store.prepareCalls, preparesBefore);
      expect(h.store.submitCalls, submitsBefore);
      expect(h.audio.requests, isEmpty);
      final retryReadEntered =
          await _runRealAsync(tester, () async => Completer<void>());
      h.persistence.readEntered = retryReadEntered;
      await tester.tap(find.text('Retry loading'));
      await tester.runAsync(() => retryReadEntered.future);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(h.persistence.values[key], rawBefore);
      expect(h.persistence.values[siblingKey], siblingBefore);
      expect(h.persistence.writes, writesBefore);
      expect(h.store.prepareCalls, preparesBefore);
      expect(h.store.submitCalls, submitsBefore);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(h.persistence.values[key], rawBefore);
      expect(h.persistence.values[siblingKey], siblingBefore);
    });
  }

  testWidgets('unavailable bytes during answer require explicit reload',
      (tester) async {
    final h = await harness(tester);
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    for (final sample in [
      ('Listen to sample A', 'fr-word-tout'),
      ('Listen to sample B', 'fr-word-tu'),
    ]) {
      await tester.tap(find.text(sample.$1));
      h.audio.completeNext(CourseAudioResult.completed(
          referenceId: sample.$2,
          source: CourseAudioSource.unverifiedRecording));
      await tester.pump();
    }
    final rawBefore = h.persistence.values[h.store.scope.storageKey]!;
    h.persistence.values[h.store.scope.storageKey] = '{corrupt-mid-run';
    final malformed = h.persistence.values[h.store.scope.storageKey]!;
    final readEntered =
        await _runRealAsync(tester, () async => Completer<void>());
    h.persistence.readEntered = readEntered;
    final writesBefore = h.persistence.writes;
    final submitsBefore = h.store.submitCalls;
    await tester.tap(find.text('Different'));
    await tester.runAsync(() => readEntered.future);
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.text('Retry saving'), findsNothing);
    expect(find.text('Reload saved progress'), findsOneWidget);
    expect(find.text('Retry loading'), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(h.persistence.values[h.store.scope.storageKey], malformed);
    expect(h.persistence.writes, writesBefore);
    expect(h.store.prepareCalls, greaterThan(1));
    expect(h.store.submitted.last.action, isA<AnswerComparisonPair>());
    await tester.tap(find.text('Reload saved progress'));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(h.persistence.values[h.store.scope.storageKey], malformed);
    expect(h.persistence.writes, writesBefore);
    expect(h.store.submitCalls, submitsBefore + 1);
    expect(h.store.submitted.where((c) => c.action is AdvanceComparisonPair),
        isEmpty);
    expect(rawBefore, isNot(malformed));
  });

  testWidgets('blocked rollback fails closed and recovery is explicit',
      (tester) async {
    final h = await harness(tester);
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    for (final sample in [
      ('Listen to sample A', 'fr-word-tout'),
      ('Listen to sample B', 'fr-word-tu'),
    ]) {
      await tester.tap(find.text(sample.$1));
      h.audio.completeNext(CourseAudioResult.completed(
          referenceId: sample.$2,
          source: CourseAudioSource.unverifiedRecording));
      await tester.pump();
    }
    final key = h.store.scope.storageKey;
    final committed = h.persistence.values[key]!;
    h.persistence.failNextWrite = true;
    h.persistence.failRestore = true;
    final entered = await _runRealAsync(tester, () async => Completer<void>());
    h.persistence.writeEntered = entered;
    await tester.tap(find.text('Different'));
    await tester.runAsync(() => entered.future);
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.text('Retry saving'), findsOneWidget);
    final staleRetry = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Retry saving'))
        .onPressed!;
    await tester.tap(find.text('Retry saving'));
    await _runRealAsync(tester, () async {
      try {
        await h.store.readSnapshot();
      } catch (_) {
        // A blocked owner may reject the read; completion of this real
        // repository barrier is still the relevant boundary.
      }
      return true;
    });
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }
    expect(find.text('Reload saved progress'), findsOneWidget);
    expect(find.text('Retry saving'), findsNothing);
    expect(h.persistence.values[key], committed);
    final submissions = h.store.submitCalls;
    staleRetry();
    await tester.pump();
    expect(h.store.submitCalls, submissions);
    expect(h.persistence.values[key], committed);
  });

  testWidgets(
      'comparison_audio_requires_both_exact_successes_and_replay_revokes',
      (tester) async {
    final h = await harness(tester);
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    await tester.tap(find.text('Listen to sample A'));
    expect(h.audio.requests.single, (
      referenceId: 'fr-word-tout',
      use: CourseAudioUse.alphaPractice,
      variant: CourseAudioVariant.normal,
      allowPracticeTts: false,
    ));
    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tout',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Same'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        {ComparisonSample.a});
    await tester.tap(find.text('Listen to sample B'));
    expect(h.audio.requests.last.referenceId, 'fr-word-tu');
    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tu',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Same'))
            .onPressed,
        isNotNull);
    await tester.tap(find.text('Listen to sample A'));
    h.audio.completeNext(const CourseAudioResult.failed(
      referenceId: 'fr-word-tout',
      failure: CourseAudioFailure(
          reason: CourseAudioFailureReason.unsupportedPlayback),
    ));
    await tester.pump();
    expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Same'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        {ComparisonSample.b});
    expect(h.audio.speakCalls, 0);
  });

  testWidgets('app pause revokes both comparison hearing grants',
      (tester) async {
    final h = await harness(tester);
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    for (final sample in [
      ('Listen to sample A', 'fr-word-tout'),
      ('Listen to sample B', 'fr-word-tu'),
    ]) {
      await tester.tap(find.text(sample.$1));
      h.audio.completeNext(CourseAudioResult.completed(
          referenceId: sample.$2,
          source: CourseAudioSource.unverifiedRecording));
      await tester.pump();
    }
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        {ComparisonSample.a, ComparisonSample.b});

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        isEmpty);
    expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Same'))
            .onPressed,
        isNull);
    expect(h.store.prepared.where((c) => c.action is AnswerComparisonPair),
        isEmpty);
  });

  testWidgets('late playback after resume cannot clear newer audio busy state',
      (tester) async {
    final h = await harness(tester);
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    await tester.tap(find.text('Listen to sample A'));
    expect(h.audio.pending, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.text('Listen to sample A'));
    expect(h.audio.pending, hasLength(2));

    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tout',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        isEmpty);
    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tout',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        {ComparisonSample.a});
  });

  testWidgets(
      'comparison_audio_accepts_reverse_order_and_only_exact_unverified_results',
      (tester) async {
    final h = await harness(tester);
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    final bResults = <CourseAudioResult>[
      const CourseAudioResult.completed(
          referenceId: 'wrong-reference',
          source: CourseAudioSource.unverifiedRecording),
      const CourseAudioResult.completed(
          referenceId: null, source: CourseAudioSource.unverifiedRecording),
      const CourseAudioResult.completed(
          referenceId: 'fr-word-tu',
          source: CourseAudioSource.reviewedRecording),
      const CourseAudioResult.completed(
          referenceId: 'fr-word-tu', source: CourseAudioSource.practiceTts),
      const CourseAudioResult.cancelled(referenceId: 'fr-word-tu'),
      const CourseAudioResult.failed(
          referenceId: 'fr-word-tu',
          failure: CourseAudioFailure(
              reason: CourseAudioFailureReason.unsupportedPlayback)),
    ];
    for (final result in bResults) {
      await tester.tap(find.text('Listen to sample B'));
      expect(h.audio.requests.last, (
        referenceId: 'fr-word-tu',
        use: CourseAudioUse.alphaPractice,
        variant: CourseAudioVariant.normal,
        allowPracticeTts: false,
      ));
      h.audio.completeNext(result);
      await tester.pump();
      expect(
          tester
              .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Same'))
              .onPressed,
          isNull);
      expect(h.store.prepared.where((c) => c.action is AnswerComparisonPair),
          isEmpty);
    }
    await tester.tap(find.text('Listen to sample B'));
    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tu',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        {ComparisonSample.b});
    await tester.tap(find.text('Listen to sample A'));
    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tout',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Same'))
            .onPressed,
        isNotNull);
    expect(h.audio.speakCalls, 0);
  });

  testWidgets('audio provider throw never unlocks or prepares answer',
      (tester) async {
    final h = await harness(tester);
    var providerReads = 0;
    final container = await _mountComparison(tester,
        store: h.store,
        audio: h.audio,
        catalogue: catalogue, onAudioFactory: () {
      providerReads++;
      throw StateError('audio provider unavailable');
    });
    addTearDown(() => cleanup(container, h.audio));
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    expect(providerReads, 1);
    expect(h.store.prepared.where((c) => c.action is AnswerComparisonPair),
        isEmpty);
    expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Same'))
            .onPressed,
        isNull);
    expect(h.audio.speakCalls, 0);
  });

  testWidgets('playback throw never unlocks or prepares answer',
      (tester) async {
    final h = await harness(tester);
    h.audio.throwNextPlayback = true;
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    expect(h.audio.requests, hasLength(1));
    expect(h.audio.pending, isEmpty);
    expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Same'))
            .onPressed,
        isNull);
    expect(
        h.store.prepared
            .where((command) => command.action is AnswerComparisonPair),
        isEmpty);
  });

  testWidgets(
      'first answer is acknowledgement gated and frozen retry preserves provenance',
      (tester) async {
    final h = await harness(tester);
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    for (final sample in [
      ('Listen to sample A', 'fr-word-tout'),
      ('Listen to sample B', 'fr-word-tu'),
    ]) {
      await tester.tap(find.text(sample.$1));
      h.audio.completeNext(CourseAudioResult.completed(
          referenceId: sample.$2,
          source: CourseAudioSource.unverifiedRecording));
      await tester.pump();
    }
    h.persistence.failNextWrite = true;
    await tester.tap(find.text('Different'));
    await _readSnapshot(tester, h.store);
    await tester.pump();
    await pumpUntil(tester, find.text('Retry saving'));
    expect(find.text('Retry saving'), findsOneWidget);
    expect(find.text('Retry loading'), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(h.store.prepared.where((c) => c.action is AnswerComparisonPair),
        hasLength(1));
    final answer = h.store.submitted.last;
    final action = answer.action as AnswerComparisonPair;
    expect(action.answer.observations.map((o) => o.slot),
        [ComparisonSample.a, ComparisonSample.b]);
    expect(action.answer.observations.map((o) => o.referenceId),
        ['fr-word-tout', 'fr-word-tu']);
    final attempt = action.answer.observations;
    expect(
        attempt.map((o) => o.activityId), everyElement(comparisonActivityId));
    expect(attempt.map((o) => o.runGeneration), everyElement(1));
    expect(attempt.map((o) => o.round), everyElement(1));
    expect(attempt.map((o) => o.pairId), everyElement('fr07b-pair-01'));
    expect(attempt.map((o) => o.profile), everyElement(h.store.scope));
    expect(attempt[0].uiGeneration, attempt[1].uiGeneration);
    expect(attempt[0].uiGeneration, 0);
    expect(
        attempt.every((o) =>
            o.outcome == CourseAudioOutcome.completed &&
            o.source == CourseAudioSource.unverifiedRecording),
        isTrue);
    final persisted = await _readSnapshot(tester, h.store);
    final savedJson = persisted.slot!.checkpoint.sessionJson;
    expect(savedJson['answered'], isFalse);
    expect(savedJson['latestAnswers'], isEmpty);
    expect(persisted.completions, isEmpty);
    final preparesBeforeRetry = h.store.prepareCalls;
    await tester.tap(find.text('Retry saving'));
    await _readSnapshot(tester, h.store);
    await tester.pump();
    await pumpUntil(tester, find.text('Continue'));
    expect(find.text('Continue'), findsOneWidget);
    expect(h.store.submitCalls, 3);
    expect(identical(h.store.submitted[1], h.store.submitted[2]), isTrue);
    expect(h.store.prepareCalls, preparesBeforeRetry);
    expect(h.audio.requests, hasLength(2));
    await _readSnapshot(tester, h.store);
  });

  testWidgets('comparison_catalogue_failure_precedes_profile_load',
      (tester) async {
    final h = await harness(tester);
    var storeFactories = 0, stateFactories = 0, audioFactories = 0;
    final container = await _mountComparison(tester,
        store: h.store,
        audio: h.audio,
        catalogue: catalogue,
        onStoreFactory: () => storeFactories++,
        onStateFactory: () => stateFactories++,
        onAudioFactory: () => audioFactories++,
        loader: () => throw ComparisonContentValidationException([
              const ComparisonContentDiagnostic(
                  code: 'invalid', recordId: 'hidden-sentinel'),
            ]));
    await tester.pump();
    addTearDown(() => cleanup(container, h.audio));
    expect(
        find.text('This comparison activity is unavailable.'), findsOneWidget);
    expect(h.store.loadCalls, 0);
    expect(h.store.prepareCalls, 0);
    expect(h.store.submitCalls, 0);
    expect(h.persistence.reads, 0);
    expect(h.audio.requests, isEmpty);
    expect(storeFactories, 0);
    expect(stateFactories, 0);
    expect(audioFactories, 0);
  });

  testWidgets('invalid context precedes catalogue and profile factories',
      (tester) async {
    final h = await harness(tester);
    var catalogueFactories = 0, storeFactories = 0, loaderCalls = 0;
    final container = await _mountComparison(tester,
        store: h.store,
        audio: h.audio,
        catalogue: catalogue,
        activityId: 'not-the-comparison-activity',
        onCatalogueFactory: () => catalogueFactories++,
        onStoreFactory: () => storeFactories++,
        loader: () {
          loaderCalls++;
          return catalogue;
        });
    addTearDown(() => cleanup(container, h.audio));
    expect(
        find.text('This comparison activity is unavailable.'), findsOneWidget);
    expect(catalogueFactories, 0);
    expect(loaderCalls, 0);
    expect(storeFactories, 0);
    expect(h.persistence.reads, 0);
  });

  testWidgets(
      'validation failure has visible retry and clears after valid retry',
      (tester) async {
    final h = await harness(tester);
    var valid = false;
    var storeFactories = 0;
    final container = await _mountComparison(tester,
        store: h.store,
        audio: h.audio,
        catalogue: catalogue,
        onStoreFactory: () => storeFactories++,
        loader: () {
          if (!valid) {
            throw ComparisonContentValidationException([
              const ComparisonContentDiagnostic(
                  code: 'invalid', recordId: 'private-content'),
            ]);
          }
          return catalogue;
        });
    addTearDown(() => cleanup(container, h.audio));
    expect(
        find.text('This comparison activity is unavailable.'), findsOneWidget);
    expect(storeFactories, 0);
    valid = true;
    await tester.tap(find.text('Retry validation'));
    await _readSnapshot(tester, h.store);
    await tester.pump();
    for (var i = 0;
        i < 20 && find.text('Listen to sample A').evaluate().isEmpty;
        i++) {
      await _readSnapshot(tester, h.store);
      await tester.pump();
    }
    expect(find.text('Listen to sample A'), findsOneWidget);
    expect(storeFactories, 1);
  });

  testWidgets('equivalent validated catalogue clone is accepted',
      (tester) async {
    final h = await harness(tester);
    final clone = _copyCatalogue(catalogue);
    expect(identical(clone, catalogue), isFalse);
    var storeFactories = 0;
    final container = await _mountComparison(tester,
        store: h.store,
        audio: h.audio,
        catalogue: catalogue,
        onStoreFactory: () => storeFactories++,
        loader: () => clone);
    addTearDown(() => cleanup(container, h.audio));
    expect(find.text('Listen to sample A'), findsOneWidget);
    expect(storeFactories, 1);
  });

  testWidgets('valid but changed catalogue fields reject before store factory',
      (tester) async {
    final changedCatalogues = [
      _copyCatalogue(catalogue,
          firstInstruction: 'Changed neutral instruction.'),
      _copyCatalogue(catalogue, firstNote: 'Changed authored note.'),
      _copyCatalogue(catalogue, changeFirstTarget: true),
      _copyCatalogue(catalogue, reverse: true),
      _copyCatalogue(catalogue, revision: 2),
    ];
    for (final changed in changedCatalogues) {
      final h = await harness(tester);
      var storeFactories = 0;
      final container = await _mountComparison(tester,
          store: h.store,
          audio: h.audio,
          catalogue: catalogue,
          onStoreFactory: () => storeFactories++,
          loader: () => changed);
      expect(find.text('This comparison activity is unavailable.'),
          findsOneWidget);
      expect(storeFactories, 0);
      expect(h.persistence.reads, 0);
      cleanup(container, h.audio);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('malformed slot declaration fails before profile factory',
      (tester) async {
    final h = await harness(tester);
    var storeFactories = 0;
    final container = await _mountComparison(tester,
        store: h.store,
        audio: h.audio,
        catalogue: catalogue,
        onStoreFactory: () => storeFactories++,
        loader: () => _copyCatalogue(catalogue, changeFirstSlot: true));
    addTearDown(() => cleanup(container, h.audio));
    expect(
        find.text('This comparison activity is unavailable.'), findsOneWidget);
    expect(storeFactories, 0);
    expect(h.persistence.reads, 0);
  });

  testWidgets('comparison_finite_review_and_restore_8_of_10_review_is_finite',
      (tester) async {
    final h = await harness(tester);
    final seeded = await _seedFirstPass(tester, h.store,
        catalogue: catalogue, policy: LessonPolicy(), wrongIndexes: {0, 2});
    expect(seeded.slot!.checkpoint.sessionJson['phase'], 'debrief');
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    expect(find.text('You got 8 of 10 correct.'), findsOneWidget);
    expect(find.text('Passing needs 8 of 10 correct.'), findsOneWidget);
    expect(find.text('Review unresolved pairs'), findsOneWidget);
    expect(find.text('Finish comparison'), findsOneWidget);
    await tester.tap(find.text('Review unresolved pairs'));
    await _readSnapshot(tester, h.store);
    await tester.pump();
    await pumpUntil(tester, find.text('Listen to sample A'));
    expect(find.text('Comparison debrief'), findsNothing);
    expect(find.textContaining('phoneme'), findsNothing);
    for (final note in catalogue.notesFor([
      catalogue.exercises[0].id,
      catalogue.exercises[2].id,
    ])) {
      expect(find.text(note), findsNothing);
    }
    expect(h.audio.requests, isEmpty);
    await tester.tap(find.text('Listen to sample A'));
    expect(h.audio.requests.last.referenceId,
        catalogue.exercises[0].sampleA.referenceId);
    h.audio.completeNext(CourseAudioResult.completed(
        referenceId: catalogue.exercises[0].sampleA.referenceId,
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    await tester.tap(find.text('Listen to sample B'));
    h.audio.completeNext(CourseAudioResult.completed(
        referenceId: catalogue.exercises[0].sampleB.referenceId,
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    final exercise = catalogue.exercises[0];
    final correctRelation = exercise.expectedRelation;
    await tester.tap(find
        .text(correctRelation == PhonemeRelation.same ? 'Same' : 'Different'));
    await _readSnapshot(tester, h.store);
    await tester.pump();
    await pumpUntil(tester, find.text('Continue'));
    await tester.tap(find.text('Continue'));
    final afterAdvance = await _readSnapshot(tester, h.store);
    await tester.pump();
    final resumedSession = LessonSectionSession.fromJson(
      Map<String, dynamic>.from(afterAdvance.slot!.checkpoint.sessionJson),
      itemIds: catalogue.exercises.map((e) => e.id).toList(),
      contentRevision: catalogue.contentRevision,
    );
    expect(resumedSession.currentItemId, catalogue.exercises[2].id);
    await tester.pump();
    expect(h.audio.requests, hasLength(2));
    expect(find.text('Comparison debrief'), findsNothing);
  });

  testWidgets('eligible_finish_acknowledges_once_and_material_app_is_safe',
      (tester) async {
    final h = await harness(tester);
    final seeded = await _seedFirstPass(tester, h.store,
        catalogue: catalogue, policy: LessonPolicy());
    expect(seeded.slot!.checkpoint.sessionJson['phase'], 'debrief');
    final beforePrepares = h.store.prepareCalls;
    final beforeSubmits = h.store.submitCalls;
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    final finish = tester
        .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Finish comparison'))
        .onPressed!;
    finish();
    finish();
    await _readSnapshot(tester, h.store);
    await tester.pump();
    await pumpUntil(tester, find.text('Comparison complete.'));
    final snapshot = await _readSnapshot(tester, h.store);
    expect(snapshot.completions, hasLength(1));
    expect(h.store.prepareCalls - beforePrepares, 1);
    expect(h.store.submitCalls - beforeSubmits, 1);
    expect(find.text('Retry saving'), findsNothing);
    expect(find.text('Finish comparison'), findsNothing);
  });

  testWidgets('restored_saved_90_percent_policy_overrides_widget_80_percent',
      (tester) async {
    final h = await harness(tester);
    final seeded = await _seedFirstPass(tester, h.store,
        catalogue: catalogue,
        policy: LessonPolicy(completionThresholdPercent: 90),
        wrongIndexes: {0, 1});
    expect(seeded.slot!.checkpoint.policy.completionThresholdPercent, 90);
    final container = await _mountComparison(tester,
        store: h.store,
        audio: h.audio,
        catalogue: catalogue,
        policy: LessonPolicy(completionThresholdPercent: 80));
    addTearDown(() => cleanup(container, h.audio));
    expect(find.text('You got 8 of 10 correct.'), findsOneWidget);
    expect(find.text('Passing needs 9 of 10 correct.'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Finish comparison'))
            .onPressed,
        isNull);
  });

  testWidgets(
      'answered restore shows feedback without selected answer or audio',
      (tester) async {
    final h = await harness(tester);
    await _seedAnsweredFirst(tester, h.store, catalogue);
    final attempts = (await _readSnapshot(tester, h.store)).attempts.length;
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    final view = tester.widget<SoundComparison>(find.byType(SoundComparison));
    expect(view.state.answered, isTrue);
    expect(view.state.feedback, ListeningFeedback.correct);
    expect(view.selectedRelation, isNull);
    expect(h.audio.requests, isEmpty);
    expect(
        (await _readSnapshot(tester, h.store)).attempts, hasLength(attempts));
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('unanswered restore requires fresh A and B grants',
      (tester) async {
    final h = await harness(tester);
    await _seedFirstPass(tester, h.store,
        catalogue: catalogue, policy: LessonPolicy());
    final state = await _runRealAsync(tester, () async {
      final command = h.store.prepare(
          state: await h.store.load(),
          activityId: comparisonActivityId,
          action: StartComparisonRun(
              sessionId: 'new-generation', policy: LessonPolicy()));
      return (await h.store.submit(command)).state;
    });
    final historicalAttempts = state.attempts.length;
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    expect(h.audio.requests, isEmpty);
    expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Same'))
            .onPressed,
        isNull);
    expect(state.attempts, hasLength(historicalAttempts));
    await tester.tap(find.text('Listen to sample A'));
    expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Same'))
            .onPressed,
        isNull);
    h.audio.completeNext(CourseAudioResult.completed(
        referenceId: catalogue.exercises.first.sampleA.referenceId,
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Same'))
            .onPressed,
        isNull);
    expect(h.audio.requests, hasLength(1));
  });

  testWidgets(
      'seven of ten remains ineligible and wrong review does not requeue',
      (tester) async {
    final h = await harness(tester);
    final seeded = await _seedFirstPass(tester, h.store,
        catalogue: catalogue, policy: LessonPolicy(), wrongIndexes: {0, 1, 2});
    expect(seeded.slot!.checkpoint.sessionJson['phase'], 'debrief');
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    expect(find.text('You got 7 of 10 correct.'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Finish comparison'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Review unresolved pairs'));
    await _readSnapshot(tester, h.store);
    await tester.pump();
    await pumpUntil(tester, find.text('Listen to sample A'));
    for (final index in [0, 1, 2]) {
      await _answerVisiblePair(tester, h.store, h.audio, catalogue,
          exerciseIndex: index, correct: false);
    }
    expect(find.text('Comparison debrief'), findsOneWidget);
    expect(find.text('You got 7 of 10 correct.'), findsOneWidget);
    expect(h.audio.requests.map((r) => r.referenceId), [
      for (final i in [0, 1, 2]) ...[
        catalogue.exercises[i].sampleA.referenceId,
        catalogue.exercises[i].sampleB.referenceId,
      ],
    ]);
    final snapshot = await _readSnapshot(tester, h.store);
    expect(snapshot.attempts, hasLength(13));
    expect(snapshot.slot!.checkpoint.sessionJson['round'], 2);
    expect(snapshot.slot!.checkpoint.sessionJson['phase'], 'debrief');
  });

  testWidgets(
      'review finish records no completion and safely handles top route',
      (tester) async {
    final h = await harness(tester);
    final seeded = await _seedFirstPass(tester, h.store,
        catalogue: catalogue, policy: LessonPolicy());
    expect(seeded.completions, isEmpty);
    final screen = ComparisonLessonScreen(
      activityId: comparisonActivityId,
      review: true,
      catalogueLoader: () => catalogue,
    );
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => screen),
    ]);
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue, router: router);
    addTearDown(() {
      cleanup(container, h.audio);
      router.dispose();
    });
    final before = h.store.prepareCalls;
    await tester.tap(find.text('Finish comparison'));
    await _readSnapshot(tester, h.store);
    await tester.pump();
    await pumpUntil(tester, find.text('Comparison complete.'));
    final finished = await _readSnapshot(tester, h.store);
    expect(finished.completions, isEmpty);
    expect(h.store.prepareCalls - before, 1);
    expect(
        h.store.prepared.last.action,
        isA<FinishComparisonRun>()
            .having((a) => a.recordCompletion, 'recordCompletion', false));
    expect(find.text('Retry saving'), findsNothing);
  });

  testWidgets('route cover and app pause compose without hidden playback',
      (tester) async {
    final h = await harness(tester);
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    await tester.tap(find.text('Listen to sample A'));
    navigator.push(PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => const Scaffold(body: Text('Upper route')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Upper route'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to sample A'));
    expect(h.audio.pending, hasLength(2));
    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tout',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        isEmpty);
    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tout',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        {ComparisonSample.a});
    await tester.tap(find.text('Listen to sample B'));
    h.audio.completeNext(const CourseAudioResult.completed(
        referenceId: 'fr-word-tu',
        source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    navigator.push(PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => const Scaffold(body: Text('Upper route')),
    ));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    navigator.pop();
    final pausedRequestCount = h.audio.requests.length;
    expect(h.audio.requests, hasLength(pausedRequestCount));
    expect(h.store.prepared.where((c) => c.action is AnswerComparisonPair),
        isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Upper route'), findsNothing);
    final requestCount = pausedRequestCount;
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        isEmpty);
    expect(h.audio.requests, hasLength(requestCount));
    await tester.tap(find.text('Listen to sample A'));
    expect(h.audio.requests, hasLength(requestCount + 1));
  });

  testWidgets(
      'covered held initial load recovers in nested zero-transition route',
      (tester) async {
    final h = await harness(tester);
    final gate = await _runRealAsync(tester, () async => Completer<void>());
    h.persistence.holdNextRead = gate;
    final screen = ComparisonLessonScreen(
        activityId: comparisonActivityId, catalogueLoader: () => catalogue);
    final router = GoRouter(routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: '/compare',
            pageBuilder: (context, state) => NoTransitionPage(child: screen),
          ),
          GoRoute(
            path: '/other',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: Text('Nested upper route')),
          ),
        ],
      ),
    ], initialLocation: '/compare');
    final container = await _mountComparison(tester,
        store: h.store,
        audio: h.audio,
        catalogue: catalogue,
        router: router,
        pumpInitialReadBarrier: false);
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      cleanup(container, h.audio);
      router.dispose();
    });
    expect(h.store.prepareCalls, 0);
    router.push('/other');
    await tester.pump();
    expect(find.text('Nested upper route'), findsOneWidget);
    gate.complete();
    await _readSnapshot(tester, h.store);
    router.pop();
    await _readSnapshot(tester, h.store);
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    await _readSnapshot(tester, h.store);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(find.text('Listen to sample A'), findsOneWidget);
    expect(h.store.prepared.where((c) => c.action is StartComparisonRun),
        hasLength(1));
    expect(
        tester
            .widget<SoundComparison>(find.byType(SoundComparison))
            .heardSamples,
        isEmpty);
  });

  testWidgets('covered held load return before completion still starts once',
      (tester) async {
    final h = await harness(tester);
    final gate = await _runRealAsync(tester, () async => Completer<void>());
    h.persistence.holdNextRead = gate;
    final screen = ComparisonLessonScreen(
        activityId: comparisonActivityId, catalogueLoader: () => catalogue);
    final router = GoRouter(routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: '/compare',
            pageBuilder: (context, state) => NoTransitionPage(child: screen),
          ),
          GoRoute(
            path: '/other',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: Text('Nested upper route')),
          ),
        ],
      ),
    ], initialLocation: '/compare');
    final container = await _mountComparison(tester,
        store: h.store,
        audio: h.audio,
        catalogue: catalogue,
        router: router,
        pumpInitialReadBarrier: false);
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      cleanup(container, h.audio);
      router.dispose();
    });
    router.push('/other');
    await tester.pump();
    expect(find.text('Nested upper route'), findsOneWidget);
    router.pop();
    await tester.pump();
    gate.complete();
    await _readSnapshot(tester, h.store);
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    await _readSnapshot(tester, h.store);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(find.text('Listen to sample A'), findsOneWidget);
    expect(h.store.prepared.where((c) => c.action is StartComparisonRun),
        hasLength(1));
    expect(h.store.submitted.where((c) => c.action is StartComparisonRun),
        hasLength(1));
  });

  testWidgets(
      'covered failed answer preserves frozen command for explicit retry',
      (tester) async {
    final h = await harness(tester);
    final gate = await _runRealAsync(tester, () async => Completer<void>());
    final screen = ComparisonLessonScreen(
        activityId: comparisonActivityId, catalogueLoader: () => catalogue);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, state) => const Text('Home'),
          routes: [
            GoRoute(path: 'compare', builder: (context, state) => screen),
            GoRoute(
                path: 'other',
                builder: (context, state) => const Text('Upper route')),
          ]),
    ], initialLocation: '/compare');
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue, router: router);
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      cleanup(container, h.audio);
      router.dispose();
    });
    for (final sample in [
      ('Listen to sample A', 'fr-word-tout'),
      ('Listen to sample B', 'fr-word-tu'),
    ]) {
      await tester.tap(find.text(sample.$1));
      h.audio.completeNext(CourseAudioResult.completed(
          referenceId: sample.$2,
          source: CourseAudioSource.unverifiedRecording));
      await tester.pump();
    }
    final prepareCount = h.store.prepareCalls;
    final audioCount = h.audio.requests.length;
    h.persistence.holdNextWrite = gate;
    h.persistence.failAfterHeldWrite = StateError('held write rejected');
    await tester.tap(find.text('Different'));
    await tester.pump();
    final frozen = h.store.submitted.last;
    final frozenObservations =
        (frozen.action as AnswerComparisonPair).answer.observations;
    router.push('/other');
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    gate.complete();
    await _readSnapshot(tester, h.store);
    router.pop();
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Upper route'), findsNothing);
    expect(find.text('Retry saving'), findsOneWidget);
    expect(h.store.prepareCalls, prepareCount + 1);
    expect(h.audio.requests, hasLength(audioCount));
    final before = await _readSnapshot(tester, h.store);
    expect(before.attempts, isEmpty);
    await tester.tap(find.text('Retry saving'));
    await _readSnapshot(tester, h.store);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(h.store.prepareCalls, prepareCount + 1);
    expect(identical(h.store.submitted.last, frozen), isTrue);
    expect((frozen.action as AnswerComparisonPair).answer.observations,
        frozenObservations);
    expect((await _readSnapshot(tester, h.store)).attempts, hasLength(1));
  });

  for (final routeCase in [
    (name: 'different URI', path: '/other'),
    (name: 'same URI new page', path: '/compare'),
  ]) {
    testWidgets('covered Finish requires explicit retry: ${routeCase.name}',
        (tester) async {
      final h = await harness(tester);
      await _seedFirstPass(tester, h.store,
          catalogue: catalogue, policy: LessonPolicy());
      final gate = await _runRealAsync(tester, () async => Completer<void>());
      h.persistence.holdNextWrite = gate;
      final screen = ComparisonLessonScreen(
          activityId: comparisonActivityId, catalogueLoader: () => catalogue);
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (context, state) => const Text('Home'),
            routes: [
              GoRoute(path: 'compare', builder: (context, state) => screen),
              GoRoute(
                  path: 'other',
                  builder: (context, state) => const Text('Upper route')),
            ]),
      ], initialLocation: '/compare');
      final container = await _mountComparison(tester,
          store: h.store, audio: h.audio, catalogue: catalogue, router: router);
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
        cleanup(container, h.audio);
        router.dispose();
      });
      final commandCount = h.store.prepared.length;
      final submitCount = h.store.submitted.length;
      await tester.tap(find.text('Finish comparison'));
      await tester.pump();
      final frozen = h.store.submitted.last;
      router.push(routeCase.path);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(router.canPop(), isTrue);
      expect(
          find.text(routeCase.path == '/other'
              ? 'Upper route'
              : 'Comparison debrief'),
          findsWidgets);
      gate.complete();
      await _readSnapshot(tester, h.store);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(router.canPop(), isTrue);
      router.pop();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Retry saving'), findsOneWidget);
      await tester.tap(find.text('Retry saving'));
      await _readSnapshot(tester, h.store);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(h.store.prepared, hasLength(commandCount + 1));
      expect(h.store.submitted, hasLength(submitCount + 2));
      expect(identical(h.store.submitted[submitCount], frozen), isTrue);
      expect(identical(h.store.submitted.last, frozen), isTrue);
      expect((await _readSnapshot(tester, h.store)).completions, hasLength(1));
      expect(router.canPop(), isFalse);
      expect(find.text('Home'), findsOneWidget);
    });
  }

  testWidgets('app resume retries a transient frozen finish exactly once',
      (tester) async {
    final h = await harness(tester);
    await _seedFirstPass(tester, h.store,
        catalogue: catalogue, policy: LessonPolicy());
    final gate = await _runRealAsync(tester, () async => Completer<void>());
    h.persistence.holdNextWrite = gate;
    final screen = ComparisonLessonScreen(
        activityId: comparisonActivityId, catalogueLoader: () => catalogue);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, state) => const Text('Home'),
          routes: [
            GoRoute(path: 'compare', builder: (context, state) => screen),
          ]),
    ], initialLocation: '/compare');
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue, router: router);
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      cleanup(container, h.audio);
      router.dispose();
    });
    final submitIndex = h.store.submitted.length;
    await tester.tap(find.text('Finish comparison'));
    await tester.pump();
    final command = h.store.submitted.last;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    gate.complete();
    await _readSnapshot(tester, h.store);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final saved = await _readSnapshot(tester, h.store);
    expect(saved.completions, hasLength(1));
    expect(h.store.submitted.length, submitIndex + 2);
    expect(identical(h.store.submitted[submitIndex], command), isTrue);
    expect(identical(h.store.submitted.last, command), isTrue);
    expect(router.canPop(), isFalse);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('finish is durable only after held write acknowledgement',
      (tester) async {
    final h = await harness(tester);
    await _seedFirstPass(tester, h.store,
        catalogue: catalogue, policy: LessonPolicy());
    final key = h.store.scope.storageKey;
    final before = h.persistence.values[key];
    final gate = await _runRealAsync(tester, () async => Completer<void>());
    h.persistence.holdNextWrite = gate;
    ProviderContainer? container;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      final mounted = container;
      if (mounted != null) cleanup(mounted, h.audio);
    });
    container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    await tester.tap(find.text('Finish comparison'));
    await tester.pump();
    expect(h.persistence.values[key], before);
    expect(find.text('Comparison complete.'), findsNothing);
    expect(find.text('Saving progress…'), findsOneWidget);
    expect(h.store.prepared.last.action, isA<FinishComparisonRun>());
    gate.complete();
    await _readSnapshot(tester, h.store);
    await tester.pump();
    await pumpUntil(tester, find.text('Comparison complete.'));
    expect((await _readSnapshot(tester, h.store)).completions, hasLength(1));
    expect(h.persistence.values[key], isNot(before));
  });

  testWidgets('failed debrief finish exposes one guarded retry control',
      (tester) async {
    final h = await harness(tester);
    await _seedFirstPass(tester, h.store,
        catalogue: catalogue, policy: LessonPolicy());
    h.persistence.failNextWrite = true;
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    await tester.tap(find.text('Finish comparison'));
    await _readSnapshot(tester, h.store);
    await tester.pump();
    await pumpUntil(tester, find.text('Retry saving'));
    expect(find.text('Retry saving'), findsOneWidget);
    expect(find.text('Retry loading'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Finish comparison'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Retry saving'));
    await _readSnapshot(tester, h.store);
    await tester.pump();
    await pumpUntil(tester, find.text('Comparison complete.'));
    expect((await _readSnapshot(tester, h.store)).completions, hasLength(1));
  });

  testWidgets('practise again starts one generation and preserves history',
      (tester) async {
    final h = await harness(tester);
    final seeded = await _seedFirstPass(tester, h.store,
        catalogue: catalogue,
        policy: LessonPolicy(completionThresholdPercent: 90),
        wrongIndexes: {0, 1, 2});
    final beforeAttempts = seeded.attempts.length;
    final beforeMistakes = seeded.mistakes.length;
    final beforeSummaries = seeded.summaries.length;
    final beforePrepared = h.store.prepared.length;
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    final callback = tester
        .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Practise again'))
        .onPressed!;
    callback();
    callback();
    await _readSnapshot(tester, h.store);
    await tester.pump();
    await pumpUntil(tester, find.text('Listen to sample A'));
    final after = await _readSnapshot(tester, h.store);
    expect(after.slot!.cursor.generation, 2);
    expect(after.slot!.checkpoint.policy.completionThresholdPercent, 90);
    expect(after.attempts, hasLength(beforeAttempts));
    expect(after.mistakes, hasLength(beforeMistakes));
    expect(after.summaries, hasLength(beforeSummaries));
    expect(
        h.store.prepared
            .skip(beforePrepared)
            .where((c) => c.action is StartComparisonRun),
        hasLength(1));
  });

  testWidgets('fresh run answers all ten in authored order before debrief',
      (tester) async {
    final h = await harness(tester);
    final container = await _mountComparison(tester,
        store: h.store, audio: h.audio, catalogue: catalogue);
    addTearDown(() => cleanup(container, h.audio));
    for (var index = 0; index < catalogue.exercises.length; index++) {
      await _answerVisiblePair(tester, h.store, h.audio, catalogue,
          exerciseIndex: index, correct: true);
    }
    expect(find.text('Comparison debrief'), findsOneWidget);
    expect(find.text('You got 10 of 10 correct.'), findsOneWidget);
    expect(h.audio.requests.map((r) => r.referenceId), [
      for (final item in catalogue.exercises) ...[
        item.sampleA.referenceId,
        item.sampleB.referenceId,
      ],
    ]);
    final saved = await _readSnapshot(tester, h.store);
    expect(saved.attempts.map((a) => a.pairId),
        catalogue.exercises.map((item) => item.id));
    expect(saved.slot!.checkpoint.sessionJson['phase'], 'debrief');
    expect(saved.slot!.checkpoint.sessionJson['position'], 10);
  });
}
