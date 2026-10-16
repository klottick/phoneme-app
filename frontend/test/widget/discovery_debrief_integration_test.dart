import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_curriculum.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/french_lesson_teaching.dart';
import 'package:linguist/src/core/course/lesson_debrief_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/features/course/discovery_section_view.dart';
import '../support/course_learning_widget_store.dart';
import '../support/controlled_listening_audio.dart';

class _FakeAudio implements CourseAudio {
  @override
  Future<void> speak(String word) async {}

  @override
  Future<void> stop() async {}
}

CourseLearningWidgetStore _debriefStore({
  Set<String> unresolved = const {'mur'},
  int thresholdPercent = 80,
}) {
  final store = CourseLearningWidgetStore();
  final section = frenchUySection;
  final session = LessonSectionSession(
    itemIds: section.items.map((item) => item.id).toList(),
    sessionId: 'restored-debrief-no-history',
    contentRevision: section.contentRevision,
    policy: LessonPolicy(completionThresholdPercent: thresholdPercent),
  );
  for (final item in section.items) {
    session.submit(!unresolved.contains(item.id));
    session.advance();
  }
  store.seedSession(session);
  return store;
}

Future<void> _pumpLesson(WidgetTester tester, CourseLearningWidgetStore store,
    {LessonDebriefContent Function()? loader,
    ControlledListeningAudio? audio,
    bool review = false}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      courseAudioProvider.overrideWithValue(audio ?? _FakeAudio()),
      courseLearningStoreProvider.overrideWithValue(store),
    ],
    child: MaterialApp(
      home: DiscoveryLessonScreen(
        lessonId: 'en-fr-u-y',
        debriefContentLoader: loader,
        review: review,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void _seedDebrief(CourseLearningWidgetStore store,
    {bool allCorrect = false, Set<String> wrong = const {'mur'}}) {
  final section = frenchUySection;
  final session = LessonSectionSession(
    itemIds: section.items.map((e) => e.id).toList(),
    sessionId: 'phase3-retry-${allCorrect ? 'all-correct' : 'mistakes'}',
    contentRevision: section.contentRevision,
  );
  for (final item in section.items) {
    session.submit(allCorrect || !wrong.contains(item.id));
    session.advance();
  }
  store.seedSession(session);
}

Future<void> _hear(WidgetTester tester, ControlledListeningAudio audio) async {
  await tester.tap(find.text('Listen to the word'));
  await tester.pump();
  audio.requests.last.complete();
  await tester.pumpAndSettle();
}

String _semanticsText(WidgetTester tester) {
  final root = tester.getSemantics(find.byType(DiscoverySectionView));
  final buffer = StringBuffer();
  bool visit(SemanticsNode node) {
    buffer.writeln('${node.label} ${node.value} ${node.hint}');
    node.visitChildren(visit);
    return true;
  }

  visit(root);
  return buffer.toString();
}

Future<void> _answer(
    WidgetTester tester, ControlledListeningAudio audio, String sound,
    {bool last = false}) async {
  await _hear(tester, audio);
  await tester.tap(find.text('/$sound/'));
  await tester.pumpAndSettle();
  final next = last ? 'See section explanation' : 'Next word';
  await tester.ensureVisible(find.text(next));
  await tester.tap(find.text(next));
  await tester.pumpAndSettle();
}

void _finishFirstPass(CourseLearningWidgetStore store,
    {Set<String> wrong = const {'mur'}, int thresholdPercent = 80}) {
  final section = frenchUySection;
  final session = LessonSectionSession(
    itemIds: section.items.map((item) => item.id).toList(),
    sessionId: 'phase3-review',
    contentRevision: section.contentRevision,
    policy: LessonPolicy(completionThresholdPercent: thresholdPercent),
  );
  for (final item in section.items) {
    session.submit(!wrong.contains(item.id));
    session.advance();
  }
  store.seedSession(session);
}

LessonDebriefContent _validMismatchedContent() {
  final originalNode = frenchCurriculum.nodeById('en-fr-u-y')!;
  final originalSection = frenchCurriculum.sectionById('en-fr-u-y-listening')!;
  final curriculum = CourseCurriculum(
    courseId: frenchCurriculum.courseId,
    revision: frenchCurriculum.revision,
    nodes: [
      for (final node in frenchCurriculum.nodes)
        if (node.id != originalNode.id) node,
      CourseNode(
        id: 'test-other-lesson',
        title: originalNode.title,
        kind: originalNode.kind,
        stage: originalNode.stage,
        status: originalNode.status,
        optional: originalNode.optional,
        prerequisiteIds: originalNode.prerequisiteIds,
        sectionIds: originalNode.sectionIds,
        targetSounds: originalNode.targetSounds,
      ),
    ],
    sections: [
      for (final section in frenchCurriculum.sections)
        if (section.id != originalSection.id) section,
      CourseSection(
        id: originalSection.id,
        nodeId: 'test-other-lesson',
        title: originalSection.title,
        explanation: originalSection.explanation,
        contentRevision: originalSection.contentRevision,
        exerciseIds: originalSection.exerciseIds,
        requiredItemCount: originalSection.requiredItemCount,
      ),
    ],
    exercises: frenchCurriculum.exercises,
    sentences: frenchCurriculum.sentences,
    audioReferences: frenchCurriculum.audioReferences,
    phonemeCoverage: frenchCurriculum.phonemeCoverage,
  );
  return LessonDebriefContent.fromCurriculum(curriculum,
      lessonId: 'test-other-lesson', notes: frenchPilotTeachingNotes);
}

void main() {
  testWidgets('restored_debrief_needs_no_history', (tester) async {
    final store = _debriefStore(thresholdPercent: 100);
    expect(store.committedState.history, isEmpty);

    await _pumpLesson(tester, store);

    expect(find.text(frenchUySection.explanation), findsOneWidget);
    expect(
      find.text(
          'For /y/ in tu, hold your tongue as for /i/ and round your lips.'),
      findsOneWidget,
    );
    expect(find.text('Passing needs 10 of 10 correct.'), findsOneWidget);
    final finish = tester.widget<FilledButton>(find.widgetWithText(
      FilledButton,
      'Finish section',
    ));
    final review = tester.widget<OutlinedButton>(find.widgetWithText(
      OutlinedButton,
      'Review mistakes',
    ));
    expect(finish.onPressed, isNull);
    expect(review.onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('finite_review_updates_notes_without_early_teaching',
      (tester) async {
    final store =
        _debriefStore(unresolved: const {'tout', 'mur'}, thresholdPercent: 80);
    final audio = ControlledListeningAudio();
    await _pumpLesson(tester, store, audio: audio);
    expect(
        find.text(
            'French /u/ in tout is close to the vowel in English “food”, but keep it steady.'),
        findsOneWidget);
    expect(
        find.text(
            'For /y/ in tu, hold your tongue as for /i/ and round your lips.'),
        findsOneWidget);
    expect(find.text('Finish section'), findsOneWidget);

    await tester.ensureVisible(find.text('Review mistakes'));
    await tester.tap(find.text('Review mistakes'));
    await tester.pumpAndSettle();
    expect(find.text('Review round 2 · item 1 of 2'), findsOneWidget);
    expect(find.textContaining('For /'), findsNothing);
    expect(find.text('tout'), findsNothing);
    expect(find.text('mur'), findsNothing);
    expect(find.text(frenchUySection.explanation), findsNothing);
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Not yet'), findsNothing);

    await _answer(tester, audio, 'u'); // tout, correct
    expect(find.text('Review round 2 · item 2 of 2'), findsOneWidget);
    expect(find.text('Correct'), findsNothing,
        reason: 'the retained last result must not leak to the next item');
    expect(find.textContaining('For /'), findsNothing);
    await _answer(tester, audio, 'u', last: true); // mur, deliberately wrong
    expect(find.text('You got 9 of 10 correct.'), findsOneWidget);
    expect(
        find.text(
            'For /y/ in tu, hold your tongue as for /i/ and round your lips.'),
        findsOneWidget);
    expect(
        find.text(
            'French /u/ in tout is close to the vowel in English “food”, but keep it steady.'),
        findsNothing);
    expect(find.text('tout'), findsNothing);
    expect(find.text('mur'), findsOneWidget);
    expect(store.discoverySession!.attemptCount, 12);
    expect(store.discoverySession!.round, 2);
    expect(store.discoverySession!.phase, LessonSectionPhase.debrief);
    expect(store.discoverySession!.policy.completionThresholdPercent, 80);
    expect(store.committedState.history, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('invalid_teaching_is_read_only_unavailable', (tester) async {
    final original = _debriefStore();
    final saved = original.committedState;
    final malformed = [
      () => LessonDebriefContent.fromCurriculum(frenchCurriculum,
          lessonId: 'en-fr-u-y',
          notes: frenchPilotTeachingNotes.skip(1).toList()),
      () => LessonDebriefContent.fromCurriculum(frenchCurriculum,
          lessonId: 'en-fr-u-y',
          notes: [...frenchPilotTeachingNotes, frenchPilotTeachingNotes.first]),
      _validMismatchedContent,
    ];
    for (var i = 0; i < malformed.length; i++) {
      final loader = malformed[i];
      final audio = ControlledListeningAudio();
      await _pumpLesson(tester, original, loader: loader, audio: audio);
      expect(find.text('Discovery lesson'), findsOneWidget);
      expect(
          find.text('This discovery lesson is unavailable.'), findsOneWidget);
      expect(find.text('tu'), findsNothing);
      expect(find.text('mur'), findsNothing);
      expect(find.text('mismatch sentinel'), findsNothing);
      expect(find.textContaining('note.'), findsNothing);
      expect(find.text('en-fr-u-y-listening-mur'), findsNothing);
      expect(find.text('Retry loading'), findsNothing);
      expect(original.loadCalls, 0);
      expect(original.retryLoadCalls, 0);
      expect(original.prepareCalls, 0);
      expect(original.submitCalls, 0);
      expect(original.committedState, same(saved));
      expect(audio.requests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }

    final scopeA = LearningScope(
        courseId: 'en-fr', owner: LearningOwner.account('phase3-a'));
    final scopeB = LearningScope(
        courseId: 'en-fr', owner: LearningOwner.account('phase3-b'));
    final accountA = CourseLearningWidgetStore(scope: scopeA);
    final accountB = CourseLearningWidgetStore(scope: scopeB);
    _finishFirstPass(accountA);
    final savedAccountA = accountA.committedState;
    final audio = ControlledListeningAudio();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          courseAudioProvider.overrideWithValue(audio),
          courseLearningStoreProvider.overrideWithValue(accountA),
        ],
        child: MaterialApp(
            home: DiscoveryLessonScreen(
          lessonId: 'en-fr-u-y',
          debriefContentLoader: malformed.first,
        ))));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          courseAudioProvider.overrideWithValue(audio),
          courseLearningStoreProvider.overrideWithValue(accountB),
        ],
        child: MaterialApp(
            home: DiscoveryLessonScreen(
          lessonId: 'en-fr-u-y',
          debriefContentLoader: malformed.first,
        ))));
    await tester.pumpAndSettle();
    expect(accountA.prepareCalls, 0);
    expect(accountB.prepareCalls, 0);
    expect(accountA.loadCalls, 0);
    expect(accountB.loadCalls, 0);
    expect(accountA.retryLoadCalls, 0);
    expect(accountB.retryLoadCalls, 0);
    expect(accountA.submitCalls, 0);
    expect(accountB.submitCalls, 0);
    expect(accountA.committedState, same(savedAccountA));
    expect(accountB.committedState.activities, isEmpty);
    expect(audio.requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pumpWidget(ProviderScope(
        overrides: [
          courseAudioProvider.overrideWithValue(audio),
          courseLearningStoreProvider.overrideWithValue(accountB),
        ],
        child: MaterialApp(
            home: DiscoveryLessonScreen(
          lessonId: 'en-fr-u-y',
          debriefContentLoader: malformed.first,
        ))));
    await tester.pumpAndSettle();
    expect(find.text('This discovery lesson is unavailable.'), findsOneWidget);
    expect(accountA.prepareCalls, 0);
    expect(accountB.prepareCalls, 0);
    expect(accountA.loadCalls, 0);
    expect(accountB.loadCalls, 0);
    expect(accountA.retryLoadCalls, 0);
    expect(accountB.retryLoadCalls, 0);
    expect(accountA.submitCalls, 0);
    expect(accountB.submitCalls, 0);
    expect(accountA.committedState, same(savedAccountA));
    expect(accountB.committedState.activities, isEmpty);
    expect(audio.requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());

    await _pumpLesson(tester, original);
    expect(find.text('This discovery lesson is unavailable.'), findsNothing);
    expect(
        find.text(
            'For /y/ in tu, hold your tongue as for /i/ and round your lips.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('restored_first_pass_and_review_require_fresh_hearing',
      (tester) async {
    for (final review in [false, true]) {
      final store = CourseLearningWidgetStore();
      final session = LessonSectionSession(
        itemIds: frenchUySection.items.map((e) => e.id).toList(),
        sessionId: 'restored-${review ? 'review' : 'first'}',
        contentRevision: frenchUySection.contentRevision,
      );
      if (review) {
        for (final item in frenchUySection.items) {
          session.submit(item.id != 'mur');
          session.advance();
        }
        session.reviewMistakes();
      } else {
        for (final _ in frenchUySection.items.take(9)) {
          session.submit(true);
          session.advance();
        }
      }
      store.seedSession(session);
      expect(store.committedState.history, isEmpty);
      final audio = ControlledListeningAudio();
      await _pumpLesson(tester, store, audio: audio);
      final visible = <String>[
        for (final e in tester.widgetList<Text>(find.byType(Text)))
          e.data ?? '',
      ].join(' ');
      final semantics = _semanticsText(tester);
      final tooltips = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((t) => t.message ?? '')
          .join(' ');
      for (final surface in [visible, semantics, tooltips]) {
        expect(surface.contains('For /'), isFalse);
        expect(surface.contains('French /u/ in tout'), isFalse);
        expect(surface.contains('tu'), isFalse);
        expect(surface.contains('mur'), isFalse);
        expect(surface.contains(frenchUySection.explanation), isFalse);
      }
      expect(
          find.text(review ? 'Review round 2 · item 1 of 1' : 'Item 10 of 10'),
          findsOneWidget);
      await tester.tap(find.text('/u/'));
      await tester.pump();
      expect(store.submitCalls, 0);
      await _hear(tester, audio);
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(store.submitCalls, 1);
      await tester.ensureVisible(find.text('See section explanation'));
      await tester.tap(find.text('See section explanation'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'For /y/ in tu, hold your tongue as for /i/ and round your lips.'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('debrief review retry keeps exact command and acknowledges once',
      (tester) async {
    final store = CourseLearningWidgetStore();
    _seedDebrief(store, wrong: const {'tout', 'mur'});
    store.failingActions.add(ReviewDiscoveryMistakes);
    await _pumpLesson(tester, store);
    final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Review mistakes'));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(store.submitted.where((c) => c.action is ReviewDiscoveryMistakes),
        hasLength(1));
    final original = store.submitted.single;
    expect(find.text('Section debrief'), findsOneWidget);
    expect(find.text('Retry saving'), findsOneWidget);
    store.failingActions.remove(ReviewDiscoveryMistakes);
    await tester.ensureVisible(find.text('Retry saving'));
    await tester.tap(find.text('Retry saving'));
    await tester.pumpAndSettle();
    final commands = store.submitted
        .where((c) => c.action is ReviewDiscoveryMistakes)
        .toList();
    expect(commands, hasLength(2));
    expect(commands.last, same(original));
    expect(store.discoverySession!.round, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'debrief finish retry keeps exact command and review finish has no completion',
      (tester) async {
    final store = CourseLearningWidgetStore();
    _seedDebrief(store, allCorrect: true);
    store.failingActions.add(FinishLearningActivity);
    await _pumpLesson(tester, store, review: true);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Finish section'));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(store.submitted.where((c) => c.action is FinishLearningActivity),
        hasLength(1));
    final original = store.submitted.single;
    store.failingActions.remove(FinishLearningActivity);
    await tester.tap(find.text('Retry saving'));
    await tester.pumpAndSettle();
    final commands = store.submitted
        .where((c) => c.action is FinishLearningActivity)
        .toList();
    expect(commands, hasLength(2));
    expect(commands.last, same(original));
    expect(store.committedState.completions, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('held review save cannot affect replacement account',
      (tester) async {
    final ownerA = CourseLearningWidgetStore(
        scope: LearningScope(
            courseId: 'en-fr', owner: LearningOwner.account('held-a')));
    final ownerB = CourseLearningWidgetStore(
        scope: LearningScope(
            courseId: 'en-fr', owner: LearningOwner.account('held-b')));
    _seedDebrief(ownerA, wrong: const {'tout', 'mur'});
    _seedDebrief(ownerB, wrong: const {'mur'});
    ownerA.actionGates[ReviewDiscoveryMistakes] = Completer<void>();
    final audio = ControlledListeningAudio();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          courseAudioProvider.overrideWithValue(audio),
          courseLearningStoreProvider.overrideWithValue(ownerA),
        ],
        child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'))));
    await tester.pumpAndSettle();
    tester
        .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Review mistakes'))
        .onPressed!();
    await tester.pump();
    expect(ownerA.submitCalls, 1);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          courseAudioProvider.overrideWithValue(audio),
          courseLearningStoreProvider.overrideWithValue(ownerB),
        ],
        child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'))));
    await tester.pumpAndSettle();
    expect(ownerB.discoverySession!.attemptCount, 10);
    ownerA.actionGates[ReviewDiscoveryMistakes]!.complete();
    await tester.pumpAndSettle();
    expect(ownerB.submitted.where((c) => c.action is ReviewDiscoveryMistakes),
        isEmpty);
    expect(ownerB.discoverySession!.attemptCount, 10);
    expect(find.text('Review round 2 · item 1 of 2'), findsNothing);
    expect(find.text('Correct'), findsNothing);
    expect(audio.requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('held finish settlement while suspended cannot navigate',
      (tester) async {
    final store = CourseLearningWidgetStore();
    _seedDebrief(store, allCorrect: true);
    store.actionGates[FinishLearningActivity] = Completer<void>();
    await _pumpLesson(tester, store, review: true);
    await tester.ensureVisible(find.text('Finish section'));
    await tester.tap(find.text('Finish section'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    store.actionGates[FinishLearningActivity]!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Section debrief'), findsOneWidget);
    expect(store.committedState.completions, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(store.committedState.completions, isEmpty);
    expect(store.submitted.where((c) => c.action is FinishLearningActivity),
        hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
