import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/lesson_debrief_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/features/course/lesson_section_debrief.dart';

LessonSection _section() => LessonSection(
      lessonId: 'en-fr-u-y',
      title: 'U versus Y',
      explanation: 'The full section rule.',
      contentRevision: 1,
      items: List.generate(
          10,
          (i) => LessonSectionItem(
              id: 'item$i',
              word: 'word$i',
              expectedSound: i.isEven ? 'u' : 'y')),
      sounds: const ['u', 'y'],
    );

LessonSectionSession _session(int correct, {int threshold = 80}) {
  final session = LessonSectionSession(
    itemIds: List.generate(10, (i) => 'item$i'),
    sessionId: 'debrief-test',
    policy: LessonPolicy(completionThresholdPercent: threshold),
  );
  for (var i = 0; i < 10; i++) {
    session.submit(i < correct);
    session.advance();
  }
  return session;
}

List<LessonDebriefEntry> _entries() => const [
      LessonDebriefEntry(itemId: 'item8', word: 'word8', text: 'note eight'),
      LessonDebriefEntry(itemId: 'item9', word: 'word9', text: 'note nine'),
    ];

Future<void> _pump(
  WidgetTester tester, {
  required int correct,
  int threshold = 80,
  List<LessonDebriefEntry>? entries,
  bool busy = false,
  String? error,
  String? conflict,
  VoidCallback? onReload,
  VoidCallback? onPractiseAgain,
  VoidCallback? onRetrySave,
}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: LessonSectionDebrief(
    section: _section(),
    session: _session(correct, threshold: threshold),
    teachingEntries: entries ?? _entries(),
    busy: busy,
    error: error,
    conflict: conflict,
    onReload: onReload,
    onPractiseAgain: onPractiseAgain,
    onReview: () {},
    onFinish: () {},
    onRetrySave: onRetrySave ?? () {},
  ))));
  await tester.pump();
}

bool _enabled(WidgetTester tester, String text) => tester
    .widget<ButtonStyleButton>(find.ancestor(
      of: find.text(text),
      matching: find.byType(switch (text) {
        'Finish section' => FilledButton,
        'Review mistakes' || 'Practise again' => OutlinedButton,
        _ => TextButton,
      }),
    ))
    .enabled;

void main() {
  testWidgets('debrief renders supplied notes and existing guards',
      (tester) async {
    await _pump(tester, correct: 10, entries: const []);
    expect(find.text('You got 10 of 10 correct.'), findsOneWidget);
    expect(find.text('Every word is correct now.'), findsOneWidget);
    expect(find.text('Review mistakes'), findsNothing);
    expect(_enabled(tester, 'Finish section'), isTrue);

    await _pump(tester, correct: 8);
    expect(find.text('Passing needs 8 of 10 correct.'), findsOneWidget);
    expect(_enabled(tester, 'Finish section'), isTrue);
    expect(_enabled(tester, 'Review mistakes'), isTrue);
    expect(find.text('note eight'), findsOneWidget);
    expect(find.text('note nine'), findsOneWidget);
    expect(tester.getTopLeft(find.text('note eight')).dy,
        lessThan(tester.getTopLeft(find.text('note nine')).dy));

    await _pump(tester, correct: 7);
    expect(_enabled(tester, 'Finish section'), isFalse);
    expect(_enabled(tester, 'Review mistakes'), isTrue);
  });

  testWidgets('busy error conflict and optional actions retain guards',
      (tester) async {
    var retries = 0, reloads = 0, practise = 0;
    await _pump(tester,
        correct: 8,
        busy: true,
        error: 'Save failed.',
        onReload: () => reloads++,
        onPractiseAgain: () => practise++,
        onRetrySave: () => retries++);
    expect(_enabled(tester, 'Finish section'), isFalse);
    expect(_enabled(tester, 'Review mistakes'), isFalse);
    expect(_enabled(tester, 'Practise again'), isFalse);
    expect(_enabled(tester, 'Retry saving'), isFalse);

    await _pump(tester,
        correct: 8,
        error: 'Save failed.',
        onReload: () => reloads++,
        onPractiseAgain: () => practise++,
        onRetrySave: () => retries++);
    expect(find.text('Retry saving'), findsOneWidget);
    expect(_enabled(tester, 'Retry saving'), isTrue);
    await tester.tap(find.text('Retry saving'));
    await tester.pump();
    expect(retries, 1);

    await _pump(tester,
        correct: 8, conflict: 'Stale.', onReload: () => reloads++);
    expect(find.text('Reload saved progress'), findsOneWidget);
    expect(_enabled(tester, 'Finish section'), isFalse);
    expect(_enabled(tester, 'Review mistakes'), isFalse);
    await tester.tap(find.text('Reload saved progress'));
    await tester.pump();
    expect(reloads, 1);
    await _pump(tester, correct: 8, onPractiseAgain: () => practise++);
    await tester.tap(find.text('Practise again'));
    await tester.pump();
    expect(practise, 1);
  });

  testWidgets('large text layouts scroll to actions and keyboard activate',
      (tester) async {
    for (final config in [(360.0, 640.0, 2.0), (360.0, 800.0, 3.0)]) {
      var finishes = 0;
      var reviews = 0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(config.$1, config.$2);
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(
            size: Size(config.$1, config.$2),
            textScaler: TextScaler.linear(config.$3)),
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: LessonSectionDebrief(
          section: _section(),
          session: _session(8),
          teachingEntries: _entries(),
          busy: false,
          error: null,
          onReview: () => reviews++,
          onFinish: () => finishes++,
          onRetrySave: () {},
        )))),
      ));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Finish section'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(finishes, 1);
      await tester.ensureVisible(find.text('Review mistakes'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(reviews, 1);
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
