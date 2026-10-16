import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/features/course/exercises/listening_exercise_contract.dart';
import 'package:linguist/src/features/course/exercises/listening_choice.dart';
import 'package:linguist/src/features/course/exercises/sound_comparison.dart';
import '../support/controlled_listening_audio.dart';
import '../support/listening_comparison_harness.dart';

ButtonStyleButton _button(WidgetTester t, String text) => t.widget(find
    .ancestor(
        of: find.text(text), matching: find.bySubtype<ButtonStyleButton>())
    .first);
String _semanticsText(WidgetTester t, Finder finder) {
  return t.getSemantics(finder).getSemanticsData().label;
}

List<SemanticsNode> _semanticsSubtree(WidgetTester tester, Finder finder) {
  final nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(finder));
  return nodes;
}

void _expectOneLabeledResponse(
  WidgetTester tester, {
  required String key,
  required String label,
  required bool selected,
  required bool enabled,
}) {
  final labelFinder =
      find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}' r'$'));
  expect(labelFinder, findsOneWidget, reason: 'one visible labeled response');
  final data = tester.getSemantics(labelFinder).getSemanticsData();
  expect(data.label, label);
  expect(data.flagsCollection.isButton, isTrue);
  expect(data.flagsCollection.isSelected.name, selected ? 'isTrue' : 'isFalse');
  expect(data.flagsCollection.isEnabled.name, enabled ? 'isTrue' : 'isFalse');
  expect(data.hasAction(SemanticsAction.tap), enabled,
      reason: 'tap action belongs to the labeled control');
  final buttonNodes = _semanticsSubtree(tester, find.byKey(ValueKey(key)))
      .where((node) =>
          !node.isMergedIntoParent &&
          node.getSemanticsData().flagsCollection.isButton)
      .toList();
  expect(buttonNodes, hasLength(1),
      reason: 'response has one button node, not an unlabeled wrapper button');
  expect(buttonNodes.single.getSemanticsData().label, label);
}

bool _primaryFocusContains(WidgetTester tester, String label) {
  final element = find.text(label).evaluate().single;
  return Focus.of(element).hasPrimaryFocus;
}

final _prompt = SoundComparisonPrompt(
    id: 'cmp',
    instruction: 'Compare the first sound in each word',
    sampleAReferenceId: 'ref-a',
    sampleBReferenceId: 'ref-b');
ComparisonFixture _fixture(PhonemeRelation expected, String a, String b,
        {String location = 'first sound',
        String? id,
        String referenceA = 'ref-a',
        String referenceB = 'ref-b'}) =>
    ComparisonFixture(
        prompt: SoundComparisonPrompt(
            id: id ?? _prompt.id,
            instruction: 'Compare the $location in each word',
            sampleAReferenceId: referenceA,
            sampleBReferenceId: referenceB),
        targetLocationA: location,
        targetLocationB: location,
        targetPhonemeA: a,
        targetPhonemeB: b,
        expected: expected);

void main() {
  testWidgets('identification_response_semantics_are_one_labeled_control',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final answers = <String>[];
    final prompt = ListeningChoicePrompt(
      id: 'semantic-prompt',
      instruction: 'Identify the sound',
      choices: [
        ListeningChoiceOption(id: 'u', label: '/u/'),
        ListeningChoiceOption(id: 'y', label: '/y/'),
      ],
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: ListeningChoice(
        prompt: prompt,
        state: ListeningExerciseState(),
        heard: true,
        selectedChoiceId: 'y',
        onListen: () {},
        onAnswer: answers.add,
      ),
    )));
    _expectOneLabeledResponse(tester,
        key: 'choice-y', label: '/y/', selected: true, enabled: true);
    _expectOneLabeledResponse(tester,
        key: 'choice-u', label: '/u/', selected: false, enabled: true);
    tester.semantics.performAction(
        find.semantics.byLabel(RegExp(r'^/y/$')), SemanticsAction.tap);
    expect(answers, ['y'],
        reason: 'semantics activation uses the real response callback');

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: ListeningChoice(
        prompt: prompt,
        state: ListeningExerciseState(busy: true, playing: true),
        heard: true,
        onListen: () {},
        onAnswer: answers.add,
      ),
    )));
    _expectOneLabeledResponse(tester,
        key: 'choice-y', label: '/y/', selected: false, enabled: false);
    expect(find.text('Playback in progress'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('comparison_response_semantics_are_one_labeled_control',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final answers = <PhonemeRelation>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: SoundComparison(
        prompt: _prompt,
        state: ListeningExerciseState(),
        heardSamples: ComparisonSample.values.toSet(),
        selectedRelation: PhonemeRelation.different,
        onListen: (_) {},
        onAnswer: answers.add,
      ),
    )));
    _expectOneLabeledResponse(tester,
        key: 'relation-same', label: 'Same', selected: false, enabled: true);
    _expectOneLabeledResponse(tester,
        key: 'relation-different',
        label: 'Different',
        selected: true,
        enabled: true);
    tester.semantics.performAction(
        find.semantics.byLabel(RegExp(r'^Same$')), SemanticsAction.tap);
    expect(answers, [PhonemeRelation.same],
        reason: 'semantics activation uses the typed callback');

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: SoundComparison(
        prompt: _prompt,
        state: ListeningExerciseState(busy: true, playing: true),
        heardSamples: ComparisonSample.values.toSet(),
        onListen: (_) {},
        onAnswer: answers.add,
      ),
    )));
    _expectOneLabeledResponse(tester,
        key: 'relation-same', label: 'Same', selected: false, enabled: false);
    expect(find.text('Playback in progress'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('controlled_views_render_only_supplied_state', (tester) async {
    final semantics = tester.ensureSemantics();
    var listened = 0;
    final answers = <String>[];
    final prompt = ListeningChoicePrompt(
        id: 'p',
        instruction: 'Identify the sound',
        choices: [
          ListeningChoiceOption(id: 'u', label: '/u/'),
          ListeningChoiceOption(id: 'y', label: '/y/'),
          ListeningChoiceOption(id: 'r', label: '/ʁ/')
        ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListeningChoice(
                prompt: prompt,
                state: ListeningExerciseState(),
                heard: true,
                onListen: () => listened++,
                onAnswer: answers.add))));
    expect(_button(tester, 'Listen to the word').enabled, true);
    expect(_button(tester, '/u/').enabled, true);
    await tester.tap(find.text('/u/'));
    expect(answers, ['u']);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListeningChoice(
                prompt: prompt,
                state: ListeningExerciseState(busy: true, playing: true),
                heard: true,
                onListen: () => listened++,
                onAnswer: answers.add))));
    expect(_button(tester, '/u/').enabled, false);
    expect(find.text('Playback in progress'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListeningChoice(
                prompt: prompt,
                state: ListeningExerciseState(
                    answered: true, feedback: ListeningFeedback.notYet),
                heard: true,
                selectedChoiceId: 'y',
                onListen: () => listened++,
                onAnswer: answers.add))));
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.text('Correct'), findsNothing);
    expect(_semanticsText(tester, find.text('/y/')), contains('/y/'));
    _expectOneLabeledResponse(tester,
        key: 'choice-y', label: '/y/', selected: true, enabled: false);
    final heard = {ComparisonSample.a, ComparisonSample.b};
    final comparison = SoundComparison(
        prompt: _prompt,
        state: ListeningExerciseState(),
        heardSamples: heard,
        onListen: (_) {},
        onAnswer: (_) {});
    heard.clear();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: comparison)));
    expect(_button(tester, 'Same').enabled, true);
    semantics.dispose();
  });
  testWidgets('controlled_view_state_matrix_gates_callbacks_and_feedback',
      (tester) async {
    final states = <(String, ListeningExerciseState, bool, bool)>[
      ('initial', ListeningExerciseState(), false, false),
      ('one sample heard', ListeningExerciseState(), true, true),
      ('both samples heard', ListeningExerciseState(), true, true),
      ('busy', ListeningExerciseState(busy: true), true, false),
      (
        'playing',
        ListeningExerciseState(busy: true, playing: true),
        true,
        false
      ),
      ('blocked', ListeningExerciseState(blocked: true), true, false),
      (
        'answered correct',
        ListeningExerciseState(
            answered: true, feedback: ListeningFeedback.correct),
        true,
        false
      ),
      (
        'answered not yet',
        ListeningExerciseState(
            answered: true, feedback: ListeningFeedback.notYet),
        true,
        false
      ),
      (
        'answered without feedback',
        ListeningExerciseState(answered: true),
        true,
        false
      ),
    ];
    final prompt = ListeningChoicePrompt(
      id: 'matrix',
      instruction: 'Identify',
      choices: [
        ListeningChoiceOption(id: 'a', label: '/a/'),
        ListeningChoiceOption(id: 'b', label: '/b/')
      ],
    );
    for (final (name, state, heard, enabled) in states) {
      var listens = 0;
      var answers = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ListeningChoice(
        prompt: prompt,
        state: state,
        heard: heard,
        selectedChoiceId: 'b',
        onListen: () => listens++,
        onAnswer: (_) => answers++,
      ))));
      expect(_button(tester, 'Listen to the word').enabled,
          !state.busy && !state.blocked && !state.answered,
          reason: name);
      expect(_button(tester, '/a/').enabled, enabled, reason: name);
      await tester.tap(find.text('Listen to the word'));
      await tester.tap(find.text('/a/'));
      expect(listens, !state.busy && !state.blocked && !state.answered ? 1 : 0,
          reason: name);
      expect(answers, enabled ? 1 : 0, reason: name);
      expect(
          find.text('Correct'),
          state.feedback == ListeningFeedback.correct
              ? findsOneWidget
              : findsNothing,
          reason: name);
      expect(
          find.text('Not yet'),
          state.feedback == ListeningFeedback.notYet
              ? findsOneWidget
              : findsNothing,
          reason: name);
    }

    for (final (name, state, heard, _) in states) {
      var listens = 0;
      var answers = 0;
      final bothHeard = name == 'both samples heard';
      final heardSamples = bothHeard
          ? {ComparisonSample.a, ComparisonSample.b}
          : heard
              ? {ComparisonSample.a}
              : <ComparisonSample>{};
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SoundComparison(
        prompt: _prompt,
        state: state,
        heardSamples: heardSamples,
        selectedRelation: PhonemeRelation.different,
        onListen: (_) => listens++,
        onAnswer: (_) => answers++,
      ))));
      heardSamples.add(ComparisonSample.b);
      expect(_button(tester, 'Listen to sample A').enabled,
          !state.busy && !state.blocked && !state.answered,
          reason: name);
      expect(_button(tester, 'Same').enabled,
          bothHeard && !state.busy && !state.blocked && !state.answered,
          reason: name);
      await tester.tap(find.text('Listen to sample A'));
      await tester.tap(find.text('Same'));
      expect(listens, !state.busy && !state.blocked && !state.answered ? 1 : 0,
          reason: name);
      expect(answers,
          bothHeard && !state.busy && !state.blocked && !state.answered ? 1 : 0,
          reason: name);
      expect(
          find.text('Correct'),
          state.feedback == ListeningFeedback.correct
              ? findsOneWidget
              : findsNothing,
          reason: name);
      expect(
          find.text('Not yet'),
          state.feedback == ListeningFeedback.notYet
              ? findsOneWidget
              : findsNothing,
          reason: name);
    }
  });
  testWidgets('comparison_uses_authored_phoneme_relation', (tester) async {
    for (final fixture in [
      _fixture(PhonemeRelation.same, 'u', 'u',
          location: 'final sound',
          referenceA: 'fr-word-tout',
          referenceB: 'fr-word-vous'),
      _fixture(PhonemeRelation.different, 'u', 'y',
          location: 'final sound',
          referenceA: 'fr-word-tout',
          referenceB: 'fr-word-tu'),
      _fixture(PhonemeRelation.same, 'ʁ', 'ʁ',
          referenceA: 'fr-word-rue', referenceB: 'fr-word-rouge'),
      _fixture(PhonemeRelation.different, 'ʁ', 'v',
          referenceA: 'fr-word-rue', referenceB: 'fr-word-vous')
    ]) {
      for (final order in [
        ComparisonSample.values,
        ComparisonSample.values.reversed
      ]) {
        final audio = ControlledListeningAudio(),
            submissions = <PhonemeRelation>[];
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: ComparisonHarness(
                    fixture: fixture,
                    audio: audio,
                    ownerId: 'owner',
                    onSubmitted: submissions.add))));
        expect(submissions, isEmpty);
        expect(_button(tester, 'Same').enabled, isFalse);
        var heardCount = 0;
        for (final sample in order) {
          await tester.tap(find.text(sample == ComparisonSample.a
              ? 'Listen to sample A'
              : 'Listen to sample B'));
          await tester.pump();
          expect(
            audio.requests.last.referenceId,
            sample == ComparisonSample.a
                ? fixture.prompt.sampleAReferenceId
                : fixture.prompt.sampleBReferenceId,
          );
          audio.requests.last.complete();
          await tester.pump();
        }
        expect(submissions, isEmpty);
        expect(_button(tester, 'Same').enabled, true);
        for (final chosen in PhonemeRelation.values) {
          await tester.tap(
              find.text(chosen == PhonemeRelation.same ? 'Same' : 'Different'));
          expect(submissions, [chosen]);
          await tester.pump();
          expect(find.text(chosen == fixture.expected ? 'Correct' : 'Not yet'),
              findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          submissions.clear();
          await tester.pumpWidget(MaterialApp(
              home: Scaffold(
                  body: ComparisonHarness(
                      fixture: fixture,
                      audio: audio,
                      ownerId: 'owner',
                      onSubmitted: submissions.add))));
          for (final sample in ComparisonSample.values) {
            await tester.tap(find.text(sample == ComparisonSample.a
                ? 'Listen to sample A'
                : 'Listen to sample B'));
            await tester.pump();
            audio.requests.last.complete();
            await tester.pump();
            heardCount++;
            if (heardCount == 1) {
              expect(submissions, isEmpty);
              expect(_button(tester, 'Same').enabled, isFalse);
            }
          }
        }
        await tester.pumpWidget(const SizedBox());
        audio.releaseAll();
      }
    }
  });
  testWidgets('comparison_replay_revokes_only_its_sample_and_claims_answer',
      (tester) async {
    final audio = ControlledListeningAudio(), submissions = <PhonemeRelation>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ComparisonHarness(
                fixture: _fixture(PhonemeRelation.same, 'u', 'u'),
                audio: audio,
                ownerId: 'o',
                onSubmitted: submissions.add))));
    for (final sample in ComparisonSample.values) {
      await tester.tap(find.text(sample == ComparisonSample.a
          ? 'Listen to sample A'
          : 'Listen to sample B'));
      await tester.pump();
      audio.requests.last.complete();
      await tester.pump();
    }
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    expect(_button(tester, 'Same').enabled, false);
    expect(_button(tester, 'Listen to sample B').enabled, false);
    audio.requests.last.complete();
    await tester.pump();
    await tester.tap(find.text('Same'));
    await tester.tap(find.text('Same'));
    expect(submissions, [PhonemeRelation.same]);
  });
  testWidgets('comparison_failure_and_wrong_reference_do_not_grant_hearing',
      (tester) async {
    final audio = ControlledListeningAudio(), submissions = <PhonemeRelation>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ComparisonHarness(
                fixture: _fixture(PhonemeRelation.same, 'u', 'u'),
                audio: audio,
                ownerId: 'o',
                onSubmitted: submissions.add))));
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    audio.requests.last.completeWith(const CourseAudioResult.completed(
        referenceId: 'wrong', source: CourseAudioSource.unverifiedRecording));
    await tester.pump();
    expect(
        find.text('Audio unavailable. Try listening again.'), findsOneWidget);
    expect(_button(tester, 'Same').enabled, false);
    expect(submissions, isEmpty);
  });
  testWidgets('exercise_semantics_and_layout_are_neutral', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    final audio = ControlledListeningAudio(), submissions = <PhonemeRelation>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
      ComparisonHarness(
          fixture: _fixture(PhonemeRelation.different, 'secret-a', 'secret-b',
              id: 'fr-word-tout'),
          audio: audio,
          ownerId: 'o',
          onSubmitted: submissions.add),
      TextButton(onPressed: () {}, child: const Text('Outside control'))
    ])))));
    expect(tester.takeException(), isNull);
    expect(
        tester.getSemantics(find.text('Listen to sample A')).label, isNotEmpty);
    expect(_button(tester, 'Same').enabled, isFalse);
    expect(
        tester
            .getSemantics(find.text('Same'))
            .getSemanticsData()
            .flagsCollection
            .isEnabled
            .name,
        'isFalse');

    // Tab into the controls and activate both plays with the keyboard only.
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.binding.focusManager.primaryFocus, isNotNull,
        reason: 'Tab must move focus into the exercise');
    expect(_primaryFocusContains(tester, 'Listen to sample A'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Playback in progress'), findsOneWidget);
    expect(tester.getSemantics(find.text('Playback in progress')).label,
        contains('Playback in progress'));
    expect(
        tester
            .getSemantics(find.text('Listen to sample B'))
            .getSemanticsData()
            .flagsCollection
            .isEnabled
            .name,
        'isFalse');
    audio.requests.last.complete();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(_primaryFocusContains(tester, 'Listen to sample B'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Playback in progress'), findsOneWidget);
    audio.requests.last.complete();
    await tester.pump();

    // Traverse both responses and leave the exercise without pointer focus.
    for (var tabPress = 0;
        tabPress < 6 && !_primaryFocusContains(tester, 'Same');
        tabPress++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    expect(_primaryFocusContains(tester, 'Same'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(_primaryFocusContains(tester, 'Different'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(_primaryFocusContains(tester, 'Outside control'), isTrue);
    // Shift-Tab back through Different to the deliberately wrong Same response.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(_primaryFocusContains(tester, 'Same'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(submissions, [PhonemeRelation.same],
        reason: 'rapid keyboard activation is claimed once before redraw');
    await tester.pump();
    expect(submissions, [PhonemeRelation.same]);
    expect(find.text('Not yet'), findsOneWidget);
    expect(
        tester.getSemantics(find.text('Not yet')).label, contains('Not yet'));
    _expectOneLabeledResponse(tester,
        key: 'relation-same', label: 'Same', selected: true, enabled: false);
    _expectOneLabeledResponse(tester,
        key: 'relation-different',
        label: 'Different',
        selected: false,
        enabled: false);

    // Search visible text, tooltips and recursively addressable semantic data;
    // the phoneme response labels are allowed, but hidden authored values are not.
    for (final sentinel in [
      'secret-a',
      'secret-b',
      'ref-a',
      'ref-b',
      'fr-word-tout',
      '/u/',
    ]) {
      expect(find.textContaining(sentinel), findsNothing, reason: sentinel);
      expect(find.byTooltip(sentinel), findsNothing, reason: sentinel);
      expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(sentinel))), findsNothing,
          reason: sentinel);
      final root = tester
          .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;
      final nodes = <SemanticsNode>[];
      void visit(SemanticsNode node) {
        nodes.add(node);
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(root);
      expect(
          nodes
              .expand((node) => [
                    node.getSemanticsData().label,
                    node.getSemanticsData().value,
                    node.getSemanticsData().hint,
                    node.getSemanticsData().tooltip,
                  ])
              .where((text) => text.contains(sentinel)),
          isEmpty,
          reason: sentinel);
    }
    await tester.ensureVisible(find.text('Different'));
    expect(tester.getTopLeft(find.text('Different')).dy, lessThan(640));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    audio.releaseAll();
    semantics.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  testWidgets('identification_keyboard_semantics_and_layout_are_neutral',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    var busy = false;
    var playing = false;
    var heard = false;
    var answered = false;
    String? selected;
    ListeningFeedback? feedback;
    var submissions = 0;
    late StateSetter rebuildOwner;
    final prompt = ListeningChoicePrompt(
      id: 'hidden-word-fr-word-tout',
      instruction: 'Identify the sound',
      choices: [
        ListeningChoiceOption(id: 'u', label: '/u/'),
        ListeningChoiceOption(id: 'y', label: '/y/'),
      ],
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
      StatefulBuilder(builder: (context, setState) {
        rebuildOwner = setState;
        return ListeningChoice(
          prompt: prompt,
          state: ListeningExerciseState(
              busy: busy,
              playing: playing,
              answered: answered,
              feedback: feedback),
          heard: heard,
          selectedChoiceId: selected,
          onListen: () => setState(() {
            busy = true;
            playing = true;
          }),
          onAnswer: (id) {
            if (answered) return;
            submissions++;
            setState(() {
              answered = true;
              selected = id;
              feedback = id == 'y'
                  ? ListeningFeedback.correct
                  : ListeningFeedback.notYet;
            });
          },
        );
      }),
      TextButton(onPressed: () {}, child: const Text('Identification outside'))
    ])))));

    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(
        Focus.of(find.text('Listen to the word').evaluate().single)
            .hasPrimaryFocus,
        isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Playback in progress'), findsOneWidget);
    expect(tester.getSemantics(find.text('Playback in progress')).label,
        contains('Playback in progress'));
    expect(_button(tester, '/u/').enabled, isFalse);
    expect(
        tester
            .getSemantics(find.text('/u/'))
            .getSemanticsData()
            .flagsCollection
            .isEnabled
            .name,
        'isFalse');
    rebuildOwner(() {
      busy = false;
      playing = false;
      heard = true;
    });
    await tester.pump();

    for (var tabPress = 0;
        tabPress < 6 &&
            !Focus.of(find.text('/u/').evaluate().single).hasPrimaryFocus;
        tabPress++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    expect(
        Focus.of(find.text('/u/').evaluate().single).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(
        Focus.of(find.text('/y/').evaluate().single).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(
        Focus.of(find.text('Identification outside').evaluate().single)
            .hasPrimaryFocus,
        isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(
        Focus.of(find.text('/u/').evaluate().single).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(submissions, 1,
        reason: 'owner claims repeated keyboard answer before redraw');
    await tester.pump();
    expect(find.text('Not yet'), findsOneWidget);
    expect(
        tester.getSemantics(find.text('Not yet')).label, contains('Not yet'));
    _expectOneLabeledResponse(tester,
        key: 'choice-u', label: '/u/', selected: true, enabled: false);
    _expectOneLabeledResponse(tester,
        key: 'choice-y', label: '/y/', selected: false, enabled: false);

    await tester.ensureVisible(find.text('/y/'));
    expect(tester.getTopLeft(find.text('/y/')).dy, lessThan(640));
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  testWidgets(
      'comparison_replay_completion_cancel_and_failure_restore_only_sample',
      (tester) async {
    for (final ending in ['complete', 'cancel', 'fail']) {
      final audio = ControlledListeningAudio(),
          submissions = <PhonemeRelation>[];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ComparisonHarness(
                  fixture: _fixture(PhonemeRelation.same, 'u', 'u'),
                  audio: audio,
                  ownerId: ending,
                  onSubmitted: submissions.add))));
      for (final sample in ComparisonSample.values) {
        await tester.tap(find.text(sample == ComparisonSample.a
            ? 'Listen to sample A'
            : 'Listen to sample B'));
        await tester.pump();
        audio.requests.last.complete();
        await tester.pump();
      }
      await tester.tap(find.text('Listen to sample A'));
      await tester.pump();
      final replay = audio.requests.last;
      expect(_button(tester, 'Same').enabled, isFalse);
      expect(_button(tester, 'Listen to sample B').enabled, isFalse);
      if (ending == 'complete') replay.complete();
      if (ending == 'cancel') replay.cancel();
      if (ending == 'fail') {
        replay.fail(cause: StateError('private diagnostic'));
      }
      await tester.pump();
      expect(_button(tester, 'Same').enabled, ending == 'complete');
      expect(submissions, isEmpty);
      expect(find.text('private diagnostic'), findsNothing);
      if (ending != 'complete') {
        await tester.tap(find.text('Listen to sample A'));
        await tester.pump();
        audio.requests.last.complete();
        await tester.pump();
        expect(_button(tester, 'Same').enabled, isTrue);
      }
      await tester.pumpWidget(const SizedBox());
      audio.releaseAll();
    }
  });

  testWidgets(
      'comparison_owner_replacement_resets_answer_and_stale_replays_are_ignored',
      (tester) async {
    final audioA = ControlledListeningAudio(),
        audioB = ControlledListeningAudio();
    final submissions = <PhonemeRelation>[];
    Widget host(String owner, ControlledListeningAudio audio,
            ComparisonFixture fixture) =>
        MaterialApp(
            home: Scaffold(
                body: ComparisonHarness(
                    key: const ValueKey('harness'),
                    fixture: fixture,
                    audio: audio,
                    ownerId: owner,
                    onSubmitted: submissions.add)));
    await tester.pumpWidget(
        host('A', audioA, _fixture(PhonemeRelation.same, 'u', 'u')));
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    final oldARequest = audioA.requests.last;
    await tester.pumpWidget(
        host('B', audioB, _fixture(PhonemeRelation.same, 'u', 'u')));
    expect(audioA.stopCalls, 1);
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    final heldBRequest = audioB.requests.last;
    await tester.pumpWidget(
        host('A', audioA, _fixture(PhonemeRelation.same, 'u', 'u')));
    expect(audioB.stopCalls, 1);
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    final currentARequest = audioA.requests.last;

    oldARequest.complete(); // Settles only after owner A has returned.
    await tester.pump();
    expect(find.text('Playback in progress'), findsOneWidget);
    expect(_button(tester, 'Listen to sample A').enabled, isFalse);
    expect(_button(tester, 'Same').enabled, isFalse);
    expect(audioA.stopCalls, 1, reason: 'stale A must not stop current A');
    expect(submissions, isEmpty);
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Not yet'), findsNothing);
    heldBRequest.complete();
    await tester.pump();
    expect(find.text('Playback in progress'), findsOneWidget,
        reason: 'stale B must not clear newer A busy state');
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Not yet'), findsNothing);
    expect(audioA.stopCalls, 1);
    currentARequest.complete();
    await tester.pump();
    expect(_button(tester, 'Listen to sample B').enabled, isTrue,
        reason: 'only current A success is heard after A→B→A');
    expect(_button(tester, 'Same').enabled, isFalse);
    expect(audioB.disposeCalls, 0);
    await tester.pumpWidget(const SizedBox());
    audioA.releaseAll();
    audioB.releaseAll();
  });

  testWidgets('comparison_stale_cancel_and_failure_cannot_clear_new_playback',
      (tester) async {
    for (final end in ['cancel', 'fail']) {
      final oldAudio = ControlledListeningAudio(),
          currentAudio = ControlledListeningAudio();
      final submitted = <PhonemeRelation>[];
      Widget host(String owner, ControlledListeningAudio audio) => MaterialApp(
          home: Scaffold(
              body: ComparisonHarness(
                  fixture: _fixture(PhonemeRelation.same, 'u', 'u'),
                  audio: audio,
                  ownerId: owner,
                  onSubmitted: submitted.add)));
      await tester.pumpWidget(host('old', oldAudio));
      await tester.tap(find.text('Listen to sample A'));
      await tester.pump();
      final stale = oldAudio.requests.last;
      await tester.pumpWidget(host('new', currentAudio));
      await tester.tap(find.text('Listen to sample B'));
      await tester.pump();
      if (end == 'cancel') stale.cancel();
      if (end == 'fail') stale.fail(cause: StateError('old failure'));
      await tester.pump();
      expect(_button(tester, 'Listen to sample A').enabled, isFalse);
      expect(_button(tester, 'Same').enabled, isFalse);
      expect(find.text('old failure'), findsNothing);
      expect(submitted, isEmpty);
      currentAudio.requests.last.complete();
      await tester.pump();
      expect(_button(tester, 'Listen to sample A').enabled, isTrue);
      await tester.pumpWidget(const SizedBox());
      oldAudio.releaseAll();
      currentAudio.releaseAll();
    }
  });

  testWidgets('comparison_owner_replacement_resets_an_actual_answer',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final audio = ControlledListeningAudio();
    final submissions = <PhonemeRelation>[];
    Widget host(String owner) => MaterialApp(
        home: Scaffold(
            body: ComparisonHarness(
                key: const ValueKey('answer-owner'),
                fixture: _fixture(PhonemeRelation.same, 'u', 'u'),
                audio: audio,
                ownerId: owner,
                onSubmitted: submissions.add)));
    Future<void> hearBoth() async {
      for (final sample in ComparisonSample.values) {
        await tester.tap(find.text(sample == ComparisonSample.a
            ? 'Listen to sample A'
            : 'Listen to sample B'));
        await tester.pump();
        audio.requests.last.complete();
        await tester.pump();
      }
    }

    await tester.pumpWidget(host('answered-owner'));
    await hearBoth();
    await tester.tap(find.text('Different'));
    await tester.pump();
    expect(submissions, [PhonemeRelation.different]);
    expect(find.text('Not yet'), findsOneWidget);
    _expectOneLabeledResponse(tester,
        key: 'relation-different',
        label: 'Different',
        selected: true,
        enabled: false);

    await tester.pumpWidget(host('replacement-owner'));
    expect(find.text('Not yet'), findsNothing);
    expect(find.text('Correct'), findsNothing);
    _expectOneLabeledResponse(tester,
        key: 'relation-different',
        label: 'Different',
        selected: false,
        enabled: false);
    expect(_button(tester, 'Same').enabled, isFalse);
    await hearBoth();
    expect(_button(tester, 'Same').enabled, isTrue);
    await tester.tap(find.text('Same'));
    expect(submissions, [PhonemeRelation.different, PhonemeRelation.same]);
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    audio.releaseAll();
    semantics.dispose();
  });

  testWidgets(
      'comparison_suspension_requires_fresh_hearing_and_resume_does_not_autoplay',
      (tester) async {
    for (final ending in ['complete', 'cancel', 'fail']) {
      final audio = ControlledListeningAudio();
      final submissions = <PhonemeRelation>[];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ComparisonHarness(
                  fixture: _fixture(PhonemeRelation.same, 'u', 'u'),
                  audio: audio,
                  ownerId: 'life-$ending',
                  onSubmitted: submissions.add))));
      for (final sample in ComparisonSample.values) {
        await tester.tap(find.text(sample == ComparisonSample.a
            ? 'Listen to sample A'
            : 'Listen to sample B'));
        await tester.pump();
        audio.requests.last.complete();
        await tester.pump();
      }
      expect(_button(tester, 'Same').enabled, isTrue);
      await tester.tap(find.text('Listen to sample A'));
      await tester.pump();
      final staleReplay = audio.requests.last;
      expect(_button(tester, 'Same').enabled, isFalse,
          reason: 'starting replay revokes A permission');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(audio.stopCalls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(audio.requests, hasLength(3), reason: 'resume must not autoplay');
      await tester.tap(find.text('Listen to sample B'));
      await tester.pump();
      final currentB = audio.requests.last;
      if (ending == 'complete') staleReplay.complete();
      if (ending == 'cancel') staleReplay.cancel();
      if (ending == 'fail') {
        staleReplay.fail(cause: StateError('stale failure'));
      }
      await tester.pump();
      expect(find.text('Playback in progress'), findsOneWidget,
          reason: 'stale result must not clear current B busy');
      expect(_button(tester, 'Same').enabled, isFalse);
      expect(_button(tester, 'Listen to sample A').enabled, isFalse);
      expect(
          find.text('Audio unavailable. Try listening again.'), findsNothing);
      expect(find.text('stale failure'), findsNothing);
      expect(audio.stopCalls, 1,
          reason: 'stale completion must not stop current B');
      expect(submissions, isEmpty);
      currentB.complete();
      await tester.pump();
      expect(_button(tester, 'Same').enabled, isFalse,
          reason: 'stale A replay cannot restore A permission');
      await tester.tap(find.text('Listen to sample A'));
      await tester.pump();
      expect(audio.requests.last.referenceId, 'ref-a');
      audio.requests.last.complete();
      await tester.pump();
      expect(_button(tester, 'Same').enabled, isTrue);
      await tester.pumpWidget(const SizedBox());
      audio.releaseAll();
    }
  });

  testWidgets(
      'comparison_suspended_owner_replacement_keeps_playback_blocked_until_resume',
      (tester) async {
    final oldAudio = ControlledListeningAudio();
    final newAudio = ControlledListeningAudio();
    final submissions = <PhonemeRelation>[];
    Widget host(String owner, ControlledListeningAudio audio) => MaterialApp(
        home: Scaffold(
            body: ComparisonHarness(
                key: const ValueKey('harness'),
                fixture: _fixture(PhonemeRelation.same, 'u', 'u'),
                audio: audio,
                ownerId: owner,
                onSubmitted: submissions.add)));

    await tester.pumpWidget(host('old-owner', oldAudio));
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    final heldOldRequest = oldAudio.requests.single;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pumpWidget(host('new-owner', newAudio));

    expect(_button(tester, 'Listen to sample A').enabled, isFalse);
    await tester.tap(find.text('Listen to sample A'));
    await tester.tap(find.text('Listen to sample B'));
    expect(newAudio.requests, isEmpty);
    expect(submissions, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(newAudio.requests, isEmpty, reason: 'resume must not autoplay');
    expect(_button(tester, 'Listen to sample A').enabled, isTrue);
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    expect(newAudio.requests.map((request) => request.referenceId), ['ref-a']);
    newAudio.requests.single.complete();
    await tester.pump();
    expect(_button(tester, 'Same').enabled, isFalse,
        reason: 'replacement reset requires both samples afresh');
    heldOldRequest.complete();
    await tester.pump();
    expect(_button(tester, 'Same').enabled, isFalse);
    await tester.pumpWidget(const SizedBox());
    oldAudio.releaseAll();
    newAudio.releaseAll();
  });

  testWidgets(
      'comparison_same_prompt_changed_references_invalidates_old_result',
      (tester) async {
    final audio = ControlledListeningAudio(), submissions = <PhonemeRelation>[];
    Widget host(ComparisonFixture fixture) => MaterialApp(
        home: Scaffold(
            body: ComparisonHarness(
                fixture: fixture,
                audio: audio,
                ownerId: 'stable',
                onSubmitted: submissions.add)));
    final original = _fixture(PhonemeRelation.same, 'u', 'u');
    await tester.pumpWidget(host(original));
    for (final sample in ComparisonSample.values) {
      await tester.tap(find.text(sample == ComparisonSample.a
          ? 'Listen to sample A'
          : 'Listen to sample B'));
      await tester.pump();
      audio.requests.last.complete();
      await tester.pump();
    }
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    final oldReplay = audio.requests.last;
    final changed = _fixture(PhonemeRelation.same, 'u', 'u',
        referenceA: 'new-a', referenceB: 'new-b');
    await tester.pumpWidget(host(changed));
    expect(audio.stopCalls, 1);
    await tester.tap(find.text('Listen to sample B'));
    await tester.pump();
    final currentB = audio.requests.last;
    expect(currentB.referenceId, 'new-b');
    oldReplay.complete();
    await tester.pump();
    expect(find.text('Playback in progress'), findsOneWidget);
    expect(_button(tester, 'Same').enabled, isFalse);
    expect(audio.stopCalls, 1,
        reason: 'stale old reference must not stop new playback');
    expect(submissions, isEmpty);
    currentB.complete();
    await tester.pump();
    expect(_button(tester, 'Same').enabled, isFalse,
        reason: 'stale old A replay cannot satisfy new A reference');
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    expect(audio.requests.last.referenceId, 'new-a');
    audio.requests.last.complete();
    await tester.pump();
    expect(_button(tester, 'Same').enabled, isTrue);
    await tester.pumpWidget(const SizedBox());
    audio.releaseAll();
  });

  testWidgets('comparison_equal_fixture_rebuild_retains_hearing',
      (tester) async {
    final audio = ControlledListeningAudio(), submissions = <PhonemeRelation>[];
    Widget host(ComparisonFixture fixture) => MaterialApp(
        home: Scaffold(
            body: ComparisonHarness(
                fixture: fixture,
                audio: audio,
                ownerId: 'same',
                onSubmitted: submissions.add)));
    await tester.pumpWidget(host(_fixture(PhonemeRelation.same, 'u', 'u')));
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    audio.requests.last.complete();
    await tester.pump();
    await tester.pumpWidget(host(_fixture(PhonemeRelation.same, 'u', 'u')));
    expect(audio.stopCalls, 0);
    expect(_button(tester, 'Listen to sample B').enabled, isTrue);
    expect(audio.requests, hasLength(1));
    expect(_button(tester, 'Same').enabled, isFalse);
    await tester.tap(find.text('Listen to sample B'));
    await tester.pump();
    expect(audio.requests.last.referenceId, 'ref-b');
    audio.requests.last.complete();
    await tester.pump();
    expect(_button(tester, 'Same').enabled, isTrue,
        reason: 'equal-value rebuild must retain A hearing');
    expect(audio.requests.map((request) => request.referenceId),
        ['ref-a', 'ref-b']);
    await tester.tap(find.text('Same'));
    expect(submissions, [PhonemeRelation.same]);
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    audio.releaseAll();
  });

  testWidgets(
      'comparison_disposal_stops_captured_audio_and_ignores_late_failure',
      (tester) async {
    final audio = ControlledListeningAudio(), submissions = <PhonemeRelation>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ComparisonHarness(
                fixture: _fixture(PhonemeRelation.same, 'u', 'u'),
                audio: audio,
                ownerId: 'dispose',
                onSubmitted: submissions.add))));
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    final pending = audio.requests.last;
    await tester.pumpWidget(const SizedBox());
    expect(audio.stopCalls, 1);
    expect(audio.disposeCalls, 0);
    pending.fail(cause: StateError('private'));
    await tester.pump();
    expect(submissions, isEmpty);
  });
}
