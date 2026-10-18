import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsData;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course/exercises/listening_exercise_contract.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt.dart';

SentenceHuntPrompt _prompt() => SentenceHuntPrompt(
      itemId: 'fr08-vowel-01',
      targetLabel: 'French vowel',
      targetIpa: '/ɑ̃/',
      instruction: 'Listen, then select each word with the target sound.',
      displayTokens: const <SentenceHuntDisplayToken>[
        SentenceHuntDisplayToken(id: 'token-01', text: 'Tu', selectable: true),
        SentenceHuntDisplayToken(id: 'space-01', text: ' ', selectable: false),
        SentenceHuntDisplayToken(
            id: 'token-02', text: 'vois', selectable: true),
        SentenceHuntDisplayToken(id: 'space-02', text: ' ', selectable: false),
        SentenceHuntDisplayToken(
            id: 'token-03', text: 'tout', selectable: true),
        SentenceHuntDisplayToken(id: 'punct-01', text: ', ', selectable: false),
        SentenceHuntDisplayToken(id: 'token-04', text: 'tu', selectable: true),
        SentenceHuntDisplayToken(id: 'space-03', text: ' ', selectable: false),
        SentenceHuntDisplayToken(
            id: 'token-05', text: 'souris', selectable: true),
        SentenceHuntDisplayToken(id: 'punct-02', text: '.', selectable: false),
      ],
    );

SentenceHuntPrompt _punctuatedPrompt() => SentenceHuntPrompt(
      itemId: 'fr08-vowel-02',
      targetLabel: 'French vowel',
      targetIpa: '/y/',
      instruction: 'Select the word units that contain this target sound.',
      displayTokens: const <SentenceHuntDisplayToken>[
        SentenceHuntDisplayToken(
            id: 'word-01', text: "l'homme", selectable: true),
        SentenceHuntDisplayToken(id: 'space-01', text: ' ', selectable: false),
        SentenceHuntDisplayToken(
            id: 'word-02', text: 'arc-en-ciel', selectable: true),
        SentenceHuntDisplayToken(id: 'punct-01', text: ' !', selectable: false),
      ],
    );

void main() {
  testWidgets('transcript preserves exact spacing punctuation and word units',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SentenceHunt(
          prompt: _prompt(),
          state: ListeningExerciseState(),
          selectedTokenIds: const <String>{},
          canSubmit: false,
          onPlay: () {},
          onToggleToken: (_) {},
          onSubmit: () {},
        ),
      ),
    ));

    final Finder transcript = find.byWidgetPredicate((Widget widget) {
      if (widget is! Text || widget.textSpan is! TextSpan) return false;
      final List<InlineSpan> children =
          (widget.textSpan! as TextSpan).children ?? const <InlineSpan>[];
      return children.whereType<WidgetSpan>().length == 5;
    });
    expect(transcript, findsOneWidget);
    final Text transcriptWidget = tester.widget<Text>(transcript);
    final List<InlineSpan> spans =
        (transcriptWidget.textSpan! as TextSpan).children!;
    expect(
      spans.whereType<TextSpan>().map((TextSpan span) => span.text),
      <String?>[' ', ' ', ', ', ' ', '.'],
      reason: 'all inter-word spaces and punctuation remain exact text slices',
    );
    expect(find.bySemanticsLabel('Word 1 of 5: Tu'), findsOneWidget);
    expect(find.bySemanticsLabel('Word 4 of 5: tu'), findsOneWidget);
    expect(find.textContaining('Synthetic test note'), findsNothing);
    expect(find.textContaining('Words with target:'), findsNothing);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SentenceHunt(
          prompt: _punctuatedPrompt(),
          state: ListeningExerciseState(),
          selectedTokenIds: const <String>{},
          canSubmit: false,
          onPlay: () {},
          onToggleToken: (_) {},
          onSubmit: () {},
        ),
      ),
    ));
    expect(find.bySemanticsLabel("Word 1 of 2: l'homme"), findsOneWidget);
    expect(find.bySemanticsLabel('Word 2 of 2: arc-en-ciel'), findsOneWidget);
    final Finder punctuatedTranscript = find.byWidgetPredicate((Widget widget) {
      if (widget is! Text || widget.textSpan is! TextSpan) return false;
      final List<InlineSpan> children =
          (widget.textSpan! as TextSpan).children ?? const <InlineSpan>[];
      return children.whereType<WidgetSpan>().length == 2;
    });
    final Text punctuatedText = tester.widget<Text>(punctuatedTranscript);
    expect(
      (punctuatedText.textSpan! as TextSpan)
          .children!
          .whereType<TextSpan>()
          .map((TextSpan span) => span.text),
      <String?>[' ', ' !'],
    );
    semantics.dispose();
  });

  testWidgets(
      'selection and submit use one pointer keyboard and semantics gate',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final Set<String> selected = <String>{};
    final List<String> toggles = <String>[];
    var submissions = 0;
    var busy = false;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            rebuild = setState;
            return SentenceHunt(
              prompt: _prompt(),
              state: busy
                  ? ListeningExerciseState(busy: true, playing: true)
                  : ListeningExerciseState(),
              selectedTokenIds: selected,
              canSubmit: !busy,
              onPlay: () {},
              onToggleToken: (String id) {
                toggles.add(id);
                setState(() {
                  if (!selected.add(id)) selected.remove(id);
                });
              },
              onSubmit: () => submissions++,
            );
          },
        ),
      ),
    ));

    final Finder firstWord =
        find.byKey(const ValueKey<String>('sentence-word-token-01'));
    final Finder repeatedWord = find.bySemanticsLabel('Word 4 of 5: tu');
    final Finder submit = find.text('Submit answer');
    expect(
        tester
            .getSemantics(firstWord)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue);
    await tester.tap(firstWord);
    await tester.pump();
    expect(toggles, <String>['token-01']);
    expect(selected, <String>{'token-01'});
    expect(
        tester
            .getSemantics(firstWord)
            .getSemanticsData()
            .flagsCollection
            .isSelected
            .name,
        'isTrue');
    expect(
        tester
            .getSemantics(repeatedWord)
            .getSemanticsData()
            .flagsCollection
            .isSelected
            .name,
        'isFalse');
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Not yet'), findsNothing);

    tester.semantics.performAction(
      find.semantics.byLabel(RegExp(r'^Word 1 of 5: Tu, selected$')),
      SemanticsAction.tap,
    );
    await tester.pump();
    expect(toggles, <String>['token-01', 'token-01']);
    expect(selected, isEmpty,
        reason: 'semantics activation shares the controlled toggle intent');

    // The first keyboard focusable word is activated without a pointer tap.
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(Focus.of(find.text('Tu').evaluate().single).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(toggles, <String>['token-01', 'token-01', 'token-01']);
    expect(selected, <String>{'token-01'});

    await tester.tap(repeatedWord);
    await tester.pump();
    expect(toggles.last, 'token-04');
    expect(selected, <String>{'token-01', 'token-04'});
    await tester.tap(submit);
    expect(submissions, 1);
    expect(find.text('Correct'), findsNothing,
        reason: 'selection and the Submit intent do not grade locally');

    rebuild(() => busy = true);
    await tester.pump();
    final SemanticsData disabledWord =
        tester.getSemantics(firstWord).getSemanticsData();
    expect(disabledWord.flagsCollection.isEnabled.name, 'isFalse');
    expect(disabledWord.hasAction(SemanticsAction.tap), isFalse);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Submit answer'))
            .onPressed,
        isNull);
    await tester.tap(firstWord);
    await tester.pump();
    expect(toggles, <String>['token-01', 'token-01', 'token-01', 'token-04']);
    expect(submissions, 1);
    semantics.dispose();
  });

  testWidgets('whole-answer feedback is textual and icon-supported',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              SentenceHunt(
                prompt: _prompt(),
                state: ListeningExerciseState(
                  answered: true,
                  feedback: ListeningFeedback.correct,
                ),
                selectedTokenIds: const <String>{},
                canSubmit: false,
                onPlay: () {},
                onToggleToken: (_) {},
                onSubmit: () {},
              ),
              SentenceHunt(
                prompt: _punctuatedPrompt(),
                state: ListeningExerciseState(
                  answered: true,
                  feedback: ListeningFeedback.notYet,
                ),
                selectedTokenIds: const <String>{},
                canSubmit: false,
                onPlay: () {},
                onToggleToken: (_) {},
                onSubmit: () {},
              ),
            ],
          ),
        ),
      ),
    ));

    expect(find.text('Correct'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.textContaining('Words with target:'), findsNothing);
    expect(find.textContaining('Synthetic test note'), findsNothing);
  });
}
