import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt_section_debrief.dart';
import '../support/sentence_hunt_fixtures.dart';

void main() {
  testWidgets(
      'saved debrief shows authored keys and only actual retained selections',
      (WidgetTester tester) async {
    final SentenceHuntCatalogue catalogue = syntheticSentenceCatalogue();
    final SentenceHuntSection section = catalogue.section(fixtureSectionIds[0]);
    final LearningOwner owner = LearningOwner.guest();
    final SentenceHuntProfileScope scope =
        SentenceHuntProfileScope(courseId: 'en-fr', owner: owner);
    final LessonSectionSession session = LessonSectionSession(
      itemIds: fixtureItemIds.first,
      sessionId: 'debrief-review',
      policy: LessonPolicy(completionThresholdPercent: 80),
    );
    for (var index = 0; index < section.items.length; index++) {
      session.submit(index >= 2);
      session.advance();
    }
    final SentenceHuntItem actualWrong = section.items.first;
    final SentenceHuntItem actualCorrect = section.items[2];
    final List<SentenceHuntAttempt> attempts = <SentenceHuntAttempt>[
      _attempt(
        scope: scope,
        item: actualWrong,
        sequence: 1,
        selected: <String>[actualWrong.selectableTokenIds.last],
        correct: false,
      ),
      _attempt(
        scope: scope,
        item: actualCorrect,
        sequence: 3,
        selected: actualCorrect.expectedTokenIds,
        correct: true,
      ),
    ];
    var reviews = 0;
    var finishes = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SentenceHuntSectionDebrief(
            section: section,
            session: session,
            latestAttempts: attempts,
            busy: false,
            canReview: true,
            canFinish: false,
            completionEligible: false,
            reviewOnly: false,
            finished: false,
            error: null,
            conflict: null,
            onReviewMistakes: () => reviews++,
            onFinish: () => finishes++,
            onRetrySave: () {},
            onReload: () {},
          ),
        ),
      ),
    ));

    expect(find.text('You got 3 of 5 correct.'), findsOneWidget);
    expect(find.text('Passing needs 4 of 5 correct.'), findsOneWidget);
    expect(find.text('Completion is not eligible yet.'), findsOneWidget);
    expect(find.textContaining('Words with target:'), findsNWidgets(5));
    expect(find.text('You missed: Tu, tu'), findsOneWidget);
    expect(find.text('Other word selected: souris'), findsOneWidget);
    expect(find.text('Saved answer: correct'), findsOneWidget);
    expect(find.textContaining('You missed:'), findsOneWidget,
        reason:
            'the second wrong item has no retained attempt and no diagnosis');
    expect(find.text('Synthetic test note for fr08-vowel-02.'), findsOneWidget);
    final List<double> authoredTop = <double>[];
    for (final String id in fixtureItemIds.first) {
      authoredTop.add(tester.getTopLeft(find.text(id)).dy);
    }
    expect(authoredTop, orderedEquals(authoredTop.toList()..sort()));
    expect(find.textContaining('solution'), findsNothing);

    await tester.ensureVisible(find.text('Review mistakes'));
    await tester.tap(find.text('Review mistakes'));
    await tester.pump();
    expect(reviews, 1);
    expect(finishes, 0);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Finish'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('review-only debrief discloses keys but cannot claim completion',
      (WidgetTester tester) async {
    final SentenceHuntCatalogue catalogue = syntheticSentenceCatalogue();
    final SentenceHuntSection section = catalogue.section(fixtureSectionIds[0]);
    final LessonSectionSession session = LessonSectionSession(
      itemIds: fixtureItemIds.first,
      sessionId: 'review-only-debrief',
    );
    for (var index = 0; index < section.items.length; index++) {
      session.submit(index == 4);
      session.advance();
    }
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SentenceHuntSectionDebrief(
            section: section,
            session: session,
            latestAttempts: const <SentenceHuntAttempt>[],
            busy: false,
            canReview: false,
            canFinish: true,
            completionEligible: false,
            reviewOnly: true,
            finished: false,
            error: null,
            conflict: null,
            onReviewMistakes: () {},
            onFinish: () {},
            onRetrySave: () {},
            onReload: () {},
          ),
        ),
      ),
    ));

    expect(find.text('Review-only practice does not count toward completion.'),
        findsOneWidget);
    expect(find.text('Completion is not eligible yet.'), findsOneWidget);
    expect(find.text('Review mistakes'), findsNothing);
    expect(find.textContaining('You missed:'), findsNothing,
        reason: 'missing retained attempts cannot invent learner selections');
    expect(find.textContaining('Words with target:'), findsNWidgets(5));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Finish'))
          .onPressed,
      isNotNull,
    );
  });
}

SentenceHuntAttempt _attempt({
  required SentenceHuntProfileScope scope,
  required SentenceHuntItem item,
  required int sequence,
  required List<String> selected,
  required bool correct,
}) {
  final DateTime time = DateTime.utc(2026, 10, 18, 12, 0, sequence);
  return SentenceHuntAttempt(
    scope: scope,
    content: item.identity,
    runGeneration: 1,
    round: 1,
    sequence: sequence,
    selectedTokenIds: selected,
    expectedTokenIds: item.expectedTokenIds,
    correct: correct,
    presentation: AttemptPresentation.firstInRun,
    teachingExposed: false,
    playback: SentenceHuntPlaybackObservation(
      scope: scope,
      content: item.identity,
      runGeneration: 1,
      round: 1,
      uiGeneration: 0,
      referenceId: item.identity.audioRefId,
      outcome: CourseAudioOutcome.completed,
      source: CourseAudioSource.reviewedRecording,
    ),
    answeredAt: time,
    committedAt: time,
  );
}
