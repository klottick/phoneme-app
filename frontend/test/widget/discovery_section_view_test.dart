import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/features/course/discovery_section_view.dart';

LessonSection _makeSection() {
  return LessonSection(
    lessonId: 'en-fr-u-y',
    title: 'U versus Y',
    explanation:
        'The /u/ versus /y/ distinction is explained only at the debrief.',
    contentRevision: 1,
    items: List.generate(
      10,
      (int i) => LessonSectionItem(
        id: 'word$i',
        word: 'wordword$i',
        expectedSound: i.isOdd ? 'y' : 'u',
      ),
    ),
    sounds: const ['u', 'y'],
  );
}

List<String> _ids() => List.generate(10, (int i) => 'word$i');

/// A session whose current exercise item is at [position], optionally already
/// submitted this round with [currentCorrect].
LessonSectionSession _exerciseSession({
  required int position,
  bool currentAnswered = false,
  bool currentCorrect = true,
}) {
  final session =
      LessonSectionSession(itemIds: _ids(), sessionId: 'test-section');
  for (var i = 0; i < position; i++) {
    session.submit(true);
    session.advance();
  }
  if (currentAnswered) {
    session.submit(currentCorrect);
  }
  return session;
}

/// A session that has finished all ten items: the first [correctCount]
/// items are correct, the rest wrong.
LessonSectionSession _debriefSession({required int correctCount}) {
  final session =
      LessonSectionSession(itemIds: _ids(), sessionId: 'test-section');
  for (var i = 0; i < 10; i++) {
    session.submit(i < correctCount);
    session.advance();
  }
  return session;
}

Future<void> _pump(
  WidgetTester tester, {
  LessonSection? section,
  required LessonSectionSession session,
  bool heard = false,
  bool busy = false,
  String? error,
  void Function()? onListen,
  void Function(String)? onAnswer,
  void Function()? onNext,
  void Function()? onReview,
  void Function()? onFinish,
  void Function()? onRetrySave,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: DiscoverySectionView(
        section: section ?? _makeSection(),
        session: session,
        heard: heard,
        busy: busy,
        error: error,
        onListen: onListen ?? () {},
        onAnswer: onAnswer ?? (String sound) {},
        onNext: onNext ?? () {},
        onReview: onReview ?? () {},
        onFinish: onFinish ?? () {},
        onRetrySave: onRetrySave ?? () {},
      ),
    ),
  ));
  await tester.pump();
}

const Map<String, Type> _buttonTypes = {
  'Listen to the word': FilledButton,
  '/u/': TextButton,
  '/y/': TextButton,
  'Next word': FilledButton,
  'See section explanation': FilledButton,
  'Retry saving': TextButton,
  'Finish section': FilledButton,
  'Review mistakes': OutlinedButton,
};

bool _enabled(WidgetTester tester, String label) {
  return tester
      .widget<ButtonStyleButton>(find.ancestor(
          of: find.text(label), matching: find.byType(_buttonTypes[label]!)))
      .enabled;
}

String _semanticsText(WidgetTester tester) {
  final root = tester.getSemantics(find.byType(DiscoverySectionView).last);
  final buffer = StringBuffer();
  bool visit(SemanticsNode node) {
    buffer.writeln(node.label);
    buffer.writeln(node.value);
    buffer.writeln(node.hint);
    node.visitChildren(visit);
    return true;
  }

  visit(root);
  return buffer.toString();
}

void main() {
  group('active listening puzzle', () {
    testWidgets(
        'shows instructions and choice labels without exposing words, '
        'explanation, or early feedback', (tester) async {
      final section = _makeSection();
      final session = _exerciseSession(position: 3);
      await _pump(tester, section: section, session: session, heard: true);
      expect(find.text(section.title), findsOneWidget);
      expect(find.text('Listen to the word'), findsOneWidget);
      expect(find.text('/u/'), findsOneWidget);
      expect(find.text('/y/'), findsOneWidget);
      // No immediate feedback or debrief material before a submission.
      expect(find.text('Correct'), findsNothing);
      expect(find.text('Not yet'), findsNothing);
      for (final item in section.items) {
        expect(find.text(item.word), findsNothing, reason: item.id);
      }
      expect(find.text(section.explanation), findsNothing);
      expect(find.text('Finish section'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('assistive semantics before a submission do not leak answers',
        (tester) async {
      final section = _makeSection();
      final session = _exerciseSession(position: 5);
      await _pump(tester, section: section, session: session, heard: true);
      final text = _semanticsText(tester);
      for (final item in section.items) {
        expect(text.contains(item.word), isFalse, reason: item.id);
      }
      expect(text.contains('Correct'), isFalse);
      expect(text.contains('Not yet'), isFalse);
      expect(text.contains('expected sound'), isFalse);
    });

    testWidgets('choices stay disabled before hearing; listening calls back',
        (tester) async {
      var listens = 0;
      final answers = <String>[];
      final session = _exerciseSession(position: 0);
      await _pump(
        tester,
        session: session,
        heard: false,
        onListen: () => listens++,
        onAnswer: answers.add,
      );
      expect(_enabled(tester, 'Listen to the word'), isTrue);
      expect(_enabled(tester, '/u/'), isFalse);
      await tester.tap(find.text('/u/'));
      await tester.pump();
      expect(answers, isEmpty, reason: 'must not answer before hearing');
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      expect(listens, 1);
    });

    testWidgets('after hearing, tapping a choice submits that sound',
        (tester) async {
      final answers = <String>[];
      final session = _exerciseSession(position: 0);
      await _pump(tester, session: session, heard: true, onAnswer: answers.add);
      expect(_enabled(tester, '/u/'), isTrue);
      expect(_enabled(tester, '/y/'), isTrue);
      await tester.tap(find.text('/y/'));
      await tester.pump();
      expect(answers, ['y']);
    });

    testWidgets('while busy, every pending control is disabled',
        (tester) async {
      final session = _exerciseSession(position: 1, currentAnswered: true);
      await _pump(tester,
          session: session, heard: true, busy: true, error: 'Saving failed.');
      expect(_enabled(tester, 'Listen to the word'), isFalse);
      expect(_enabled(tester, '/u/'), isFalse);
      expect(_enabled(tester, '/y/'), isFalse);
      expect(_enabled(tester, 'Next word'), isFalse);
      expect(_enabled(tester, 'Retry saving'), isFalse);
    });

    testWidgets(
        'one submission shows immediate feedback and disables re-answer',
        (tester) async {
      final session = _exerciseSession(
          position: 2, currentAnswered: true, currentCorrect: true);
      await _pump(tester, session: session, heard: true);
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Not yet'), findsNothing);
      expect(_enabled(tester, 'Listen to the word'), isFalse);
      expect(_enabled(tester, '/u/'), isFalse);
      expect(_enabled(tester, '/y/'), isFalse);
      expect(_enabled(tester, 'Next word'), isTrue);
    });

    testWidgets('a wrong submission shows Not yet instead of Correct',
        (tester) async {
      final session = _exerciseSession(
          position: 2, currentAnswered: true, currentCorrect: false);
      await _pump(tester, session: session, heard: true);
      expect(find.text('Not yet'), findsOneWidget);
      expect(find.text('Correct'), findsNothing);
    });

    testWidgets('Next word advances; the last item invites the debrief',
        (tester) async {
      var nexts = 0;
      final session = _exerciseSession(
          position: 0, currentAnswered: true, currentCorrect: true);
      await _pump(tester, session: session, heard: true, onNext: () => nexts++);
      expect(find.text('Next word'), findsOneWidget);
      expect(find.text('See section explanation'), findsNothing);
      await tester.tap(find.text('Next word'));
      await tester.pump();
      expect(nexts, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      var nextsLast = 0;
      final last = _exerciseSession(
          position: 9, currentAnswered: true, currentCorrect: true);
      await _pump(tester,
          session: last, heard: true, onNext: () => nextsLast++);
      expect(find.text('See section explanation'), findsOneWidget);
      expect(find.text('Next word'), findsNothing);
      await tester.tap(find.text('See section explanation'));
      await tester.pump();
      expect(nextsLast, 1);
    });
  });

  group('errors', () {
    testWidgets(
        'a pre-answer error is shown but never masquerades as an answer',
        (tester) async {
      var retries = 0;
      final session = _exerciseSession(position: 0);
      await _pump(tester,
          session: session,
          heard: false,
          error: 'Audio unavailable.',
          onRetrySave: () => retries++);
      expect(find.text('Audio unavailable.'), findsOneWidget);
      expect(find.text('Correct'), findsNothing);
      expect(find.text('Not yet'), findsNothing);
      expect(_enabled(tester, 'Listen to the word'), isFalse);
      expect(_enabled(tester, '/u/'), isFalse);
      expect(_enabled(tester, '/y/'), isFalse);
      expect(_enabled(tester, 'Next word'), isFalse);
      expect(_enabled(tester, 'Retry saving'), isTrue);
      await tester.tap(find.text('Retry saving'));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets(
        'a failed save keeps feedback, blocks progression, offers retry',
        (tester) async {
      var retries = 0;
      var nexts = 0;
      final session = _exerciseSession(
          position: 0, currentAnswered: true, currentCorrect: true);
      await _pump(tester,
          session: session,
          heard: true,
          error: 'Saving failed.',
          onNext: () => nexts++,
          onRetrySave: () => retries++);
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Saving failed.'), findsOneWidget);
      expect(_enabled(tester, 'Next word'), isFalse);
      expect(_enabled(tester, 'Retry saving'), isTrue);
      await tester.tap(find.text('Next word'));
      await tester.pump();
      expect(nexts, 0, reason: 'save failure must not advance');
      await tester.tap(find.text('Retry saving'));
      await tester.pump();
      expect(retries, 1);
    });
  });

  group('debrief', () {
    testWidgets('passes at the 80% threshold with finish eligible',
        (tester) async {
      final section = _makeSection();
      final session = _debriefSession(correctCount: 8);
      var finishes = 0;
      await _pump(tester, session: session, onFinish: () => finishes++);
      expect(find.text(section.explanation), findsOneWidget);
      expect(find.text('You got 8 of 10 correct.'), findsOneWidget);
      expect(find.text('Passing needs 8 of 10 correct.'), findsOneWidget);
      expect(find.text('Correct'), findsNothing);
      expect(find.text('Not yet'), findsNothing);
      expect(_enabled(tester, 'Finish section'), isTrue);
      await tester.tap(find.text('Finish section'));
      await tester.pump();
      expect(finishes, 1);
    });

    testWidgets('lists unresolved words and offers review even when passing',
        (tester) async {
      final section = _makeSection();
      final session = _debriefSession(correctCount: 8);
      var reviews = 0;
      await _pump(tester,
          section: section, session: session, onReview: () => reviews++);
      expect(find.text('wordword8'), findsOneWidget);
      expect(find.text('wordword9'), findsOneWidget);
      expect(find.text('wordword7'), findsNothing);
      expect(_enabled(tester, 'Review mistakes'), isTrue);
      await tester.tap(find.text('Review mistakes'));
      await tester.pump();
      expect(reviews, 1);
    });

    testWidgets('below the threshold finish is blocked but review remains',
        (tester) async {
      final section = _makeSection();
      final session = _debriefSession(correctCount: 5);
      var finishes = 0;
      await _pump(tester,
          section: section, session: session, onFinish: () => finishes++);
      expect(find.text('You got 5 of 10 correct.'), findsOneWidget);
      expect(_enabled(tester, 'Finish section'), isFalse);
      await tester.tap(find.text('Finish section'));
      await tester.pump();
      expect(finishes, 0);
      expect(_enabled(tester, 'Review mistakes'), isTrue);
      expect(find.text('wordword5'), findsOneWidget);
      expect(find.text('wordword9'), findsOneWidget);
    });

    testWidgets('with no mistakes review is hidden and finish stays open',
        (tester) async {
      final session = _debriefSession(correctCount: 10);
      var finishes = 0;
      await _pump(tester, session: session, onFinish: () => finishes++);
      expect(find.text('Review mistakes'), findsNothing);
      expect(find.text('Every word is correct now.'), findsOneWidget);
      expect(find.text('wordword0'), findsNothing);
      expect(_enabled(tester, 'Finish section'), isTrue);
      await tester.tap(find.text('Finish section'));
      await tester.pump();
      expect(finishes, 1);
    });

    testWidgets('a debrief save error blocks completion and offers retry',
        (tester) async {
      var retries = 0;
      var finishes = 0;
      final session = _debriefSession(correctCount: 8);
      await _pump(tester,
          session: session,
          error: 'Saving failed.',
          onFinish: () => finishes++,
          onRetrySave: () => retries++);
      expect(_enabled(tester, 'Finish section'), isFalse);
      expect(_enabled(tester, 'Review mistakes'), isFalse);
      expect(_enabled(tester, 'Retry saving'), isTrue);
      await tester.tap(find.text('Finish section'));
      await tester.pump();
      expect(finishes, 0);
      await tester.tap(find.text('Retry saving'));
      await tester.pump();
      expect(retries, 1);
    });
  });

  group('layout', () {
    testWidgets('exercises and debriefs scroll at 360x800', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = _exerciseSession(
          position: 8, currentAnswered: true, currentCorrect: true);
      await _pump(tester, session: session, heard: true);
      expect(find.text('Next word'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Next word'), 200);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      final debrief = _debriefSession(correctCount: 8);
      await _pump(tester, session: debrief);
      await tester.scrollUntilVisible(find.text('Review mistakes'), 200);
      await tester.scrollUntilVisible(find.text('Finish section'), 200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('exercises and debriefs scroll at 390x844', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = _exerciseSession(
          position: 8, currentAnswered: true, currentCorrect: true);
      await _pump(tester, session: session, heard: true);
      await tester.scrollUntilVisible(find.text('Next word'), 200);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      final debrief = _debriefSession(correctCount: 8);
      await _pump(tester, session: debrief);
      await tester.scrollUntilVisible(find.text('Finish section'), 200);
      await tester.scrollUntilVisible(find.text('Review mistakes'), 200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text still reaches every control without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      // The test binding is recreated per test; reset defensively anyway.
      addTearDown(
          () => tester.platformDispatcher.textScaleFactorTestValue = 1.0);
      final session = _exerciseSession(
          position: 8, currentAnswered: true, currentCorrect: true);
      await _pump(tester, session: session, heard: true);
      await tester.scrollUntilVisible(find.text('Next word'), 200);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      final debrief = _debriefSession(correctCount: 8);
      await _pump(tester, session: debrief);
      await tester.scrollUntilVisible(find.text('Finish section'), 200);
      await tester.scrollUntilVisible(find.text('Review mistakes'), 200);
      expect(tester.takeException(), isNull);
    });
  });
}
