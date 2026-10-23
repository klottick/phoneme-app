import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/features/course/comparison_section_debrief.dart';

LessonSectionSession _debrief({
  int correct = 10,
  LessonPolicy? policy,
  Set<int> unresolved = const {},
  List<String>? itemIds,
}) {
  final session = LessonSectionSession(
    itemIds:
        itemIds ??
        List.generate(
          10,
          (i) => 'fr07b-pair-${(i + 1).toString().padLeft(2, '0')}',
        ),
    sessionId: 'debrief-test',
    policy: policy,
  );
  var correctSoFar = 0;
  for (var i = 0; i < 10; i++) {
    final isCorrect = !unresolved.contains(i) && correctSoFar < correct;
    if (isCorrect) correctSoFar++;
    session.submit(isCorrect);
    session.advance();
  }
  return session;
}

void main() {
  final catalogue = loadFrenchComparisonCatalogue();

  testWidgets('all-correct debrief teaches the exact rule and saved threshold',
      (tester) async {
    final session =
        _debrief(policy: LessonPolicy(completionThresholdPercent: 90));
    var reviews = 0;
    var finishes = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ComparisonSectionDebrief(
      catalogue: catalogue,
      session: session,
      busy: false,
      error: null,
      conflict: null,
      canFinish: true,
      onReview: () => reviews++,
      onFinish: () => finishes++,
      onRetrySave: () {},
      onReload: () {},
    ))));
    expect(
        find.text(
            'Compare only the designated sound in each sample. Same means those two target phonemes are identical; Different means they are not. Ignore the rest of the word.'),
        findsOneWidget);
    expect(find.text('You got 10 of 10 correct.'), findsOneWidget);
    expect(find.text('Passing needs 9 of 10 correct.'), findsOneWidget);
    expect(find.text('Every comparison is correct now.'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
    expect(find.text('Review unresolved pairs'), findsNothing);
    await tester.tap(find.text('Finish comparison'));
    await tester.pump();
    expect(finishes, 1);
    expect(reviews, 0);
    expect(session.phase, LessonSectionPhase.debrief);
  });

  testWidgets('uy_demo_debrief_keeps_saved_threshold_and_authored_note_order', (
    tester,
  ) async {
    final demo = loadFrenchUyDemoComparisonCatalogue();
    final session = _debrief(
      correct: 8,
      policy: LessonPolicy(completionThresholdPercent: 90),
      unresolved: {0, 3},
      itemIds: demo.exercises.map((exercise) => exercise.id).toList(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComparisonSectionDebrief(
            catalogue: demo,
            session: session,
            busy: false,
            error: null,
            conflict: null,
            canFinish: true,
            onReview: () {},
            onFinish: () {},
            onRetrySave: () {},
            onReload: () {},
          ),
        ),
      ),
    );
    expect(find.text('You got 8 of 10 correct.'), findsOneWidget);
    expect(find.text('Passing needs 9 of 10 correct.'), findsOneWidget);
    const firstAuthoredNote =
        'The designated vowels are `/u/` in A and `/y/` in B; they differ.';
    const fourthAuthoredNote =
        'The designated vowels are `/y/` in A and `/u/` in B; they differ.';
    expect(find.text(firstAuthoredNote), findsOneWidget);
    expect(find.text(fourthAuthoredNote), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(firstAuthoredNote)).dy,
      lessThan(tester.getTopLeft(find.text(fourthAuthoredNote)).dy),
    );
    expect(find.text('Comparison practice'), findsNothing);
  });

  testWidgets(
      'unresolved notes retain authored order and only eligible actions appear',
      (tester) async {
    final session = _debrief(correct: 8, unresolved: {8, 0});
    var reviews = 0;
    var finishes = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ComparisonSectionDebrief(
      catalogue: catalogue,
      session: session,
      busy: false,
      error: null,
      conflict: null,
      canFinish: true,
      onReview: () => reviews++,
      onFinish: () => finishes++,
      onRetrySave: () {},
      onReload: () {},
    ))));
    expect(find.text('You got 8 of 10 correct.'), findsOneWidget);
    expect(find.text('Passing needs 8 of 10 correct.'), findsOneWidget);
    final notes = catalogue.notesFor(session.unresolvedItemIds);
    final first = tester.getTopLeft(find.text(notes.first)).dy;
    final second = tester.getTopLeft(find.text(notes.last)).dy;
    expect(first, lessThan(second));
    expect(find.textContaining('you chose'), findsNothing);
    await tester.tap(find.text('Review unresolved pairs'));
    await tester.pump();
    expect(reviews, 1);
    expect(finishes, 0);
  });

  testWidgets('cannot finish an under-threshold debrief even if caller permits',
      (tester) async {
    final session = _debrief(correct: 7, unresolved: {7, 8, 9});
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ComparisonSectionDebrief(
      catalogue: catalogue,
      session: session,
      busy: false,
      error: null,
      conflict: null,
      canFinish: true,
      onReview: () {},
      onFinish: () {},
      onRetrySave: () {},
      onReload: () {},
    ))));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Finish comparison'))
            .onPressed,
        isNull);
  });

  testWidgets('cannot finish before every pair has been attempted',
      (tester) async {
    final session = LessonSectionSession(
      itemIds: catalogue.exercises.map((exercise) => exercise.id).toList(),
      sessionId: 'incomplete-test',
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ComparisonSectionDebrief(
      catalogue: catalogue,
      session: session,
      busy: false,
      error: null,
      conflict: null,
      canFinish: true,
      onReview: () {},
      onFinish: () {},
      onRetrySave: () {},
      onReload: () {},
    ))));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Finish comparison'))
            .onPressed,
        isNull);
  });

  testWidgets('busy disables all actions and practice callback is optional',
      (tester) async {
    final session = _debrief(unresolved: {0});
    var practices = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ComparisonSectionDebrief(
      catalogue: catalogue,
      session: session,
      busy: true,
      error: null,
      conflict: null,
      canFinish: true,
      onReview: () {},
      onFinish: () {},
      onRetrySave: () {},
      onReload: () {},
      onPractiseAgain: () => practices++,
    ))));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Finish comparison'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Review unresolved pairs'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Practise again'))
            .onPressed,
        isNull);
    expect(find.text('Saving progress…'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ComparisonSectionDebrief(
      catalogue: catalogue,
      session: session,
      busy: false,
      error: null,
      conflict: null,
      canFinish: false,
      onReview: () {},
      onFinish: () {},
      onRetrySave: () {},
      onReload: () {},
    ))));
    expect(find.text('Practise again'), findsNothing);
    expect(practices, 0);
  });

  testWidgets('error and conflict offer only guarded recovery callbacks',
      (tester) async {
    var retries = 0;
    var reloads = 0;
    final session = _debrief(unresolved: {0});
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ComparisonSectionDebrief(
      catalogue: catalogue,
      session: session,
      busy: false,
      error: 'Save failed',
      conflict: 'Progress changed',
      canFinish: true,
      onReview: () {},
      onFinish: () {},
      onRetrySave: () => retries++,
      onReload: () => reloads++,
      onPractiseAgain: () {},
    ))));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Finish comparison'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Retry saving'))
            .onPressed,
        isNotNull);
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Reload saved progress'))
            .onPressed,
        isNotNull);
    await tester.tap(find.text('Retry saving'));
    await tester.tap(find.text('Reload saved progress'));
    await tester.pump();
    expect(retries, 1);
    expect(reloads, 1);
  });
}
