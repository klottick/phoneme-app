import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/features/course/exercises/listening_exercise_contract.dart';
import 'package:linguist/src/features/course/exercises/listening_choice.dart';
import 'package:linguist/src/features/course/exercises/sound_comparison.dart';
import '../support/controlled_listening_audio.dart';
import '../support/listening_comparison_harness.dart';

ButtonStyleButton _button(WidgetTester t, String text) => t.widget(find
    .ancestor(of: find.text(text), matching: find.byType(ElevatedButton))
    .first);
String _semanticsText(WidgetTester t, Finder finder) {
  return t.getSemantics(finder).getSemanticsData().label;
}

final _prompt = SoundComparisonPrompt(
    id: 'cmp',
    instruction: 'Compare the first sound in each word',
    sampleAReferenceId: 'ref-a',
    sampleBReferenceId: 'ref-b');
ComparisonFixture _fixture(PhonemeRelation expected, String a, String b,
        {String location = 'first sound', String? id}) =>
    ComparisonFixture(
        prompt: SoundComparisonPrompt(
            id: id ?? _prompt.id,
            instruction: 'Compare the $location in each word',
            sampleAReferenceId: _prompt.sampleAReferenceId,
            sampleBReferenceId: _prompt.sampleBReferenceId),
        targetLocationA: location,
        targetLocationB: location,
        targetPhonemeA: a,
        targetPhonemeB: b,
        expected: expected);

void main() {
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
    expect(
        tester
            .getSemantics(find.byKey(const ValueKey('choice-y')))
            .getSemanticsData()
            .flagsCollection
            .isSelected
            .name,
        'isTrue');
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
          location: 'final sound', id: 'fr-word-tout/fr-word-vous'),
      _fixture(PhonemeRelation.different, 'u', 'y',
          location: 'final sound', id: 'fr-word-tout/fr-word-tu'),
      _fixture(PhonemeRelation.same, 'ʁ', 'ʁ', id: 'fr-word-rue/fr-word-rouge'),
      _fixture(PhonemeRelation.different, 'ʁ', 'v',
          id: 'fr-word-rue/fr-word-vous')
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
                child: ComparisonHarness(
                    fixture: _fixture(
                        PhonemeRelation.different, 'secret-a', 'secret-b',
                        id: 'fr-word-tout'),
                    audio: audio,
                    ownerId: 'o',
                    onSubmitted: submissions.add)))));
    expect(tester.takeException(), isNull);
    expect(
        tester.getSemantics(find.text('Listen to sample A')).label, isNotEmpty);
    expect(_button(tester, 'Same').enabled, isFalse);

    // Exercise real keyboard focus and activation, not a direct callback.
    await tester.ensureVisible(find.text('Listen to sample A'));
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    audio.requests.last.complete();
    await tester.pump();
    await tester.ensureVisible(find.text('Listen to sample B'));
    await tester.tap(find.text('Listen to sample B'));
    await tester.pump();
    audio.requests.last.complete();
    await tester.pump();
    await tester.ensureVisible(find.text('Same'));
    await tester.tap(find.text('Same')); // Focus the actual Material button.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(submissions, [PhonemeRelation.same]);
    expect(find.text('Not yet'), findsOneWidget);
    expect(
        tester
            .getSemantics(find.byKey(const ValueKey('relation-same')))
            .getSemanticsData()
            .flagsCollection
            .isSelected
            .name,
        'isTrue');
    expect(
        tester
            .getSemantics(find.byKey(const ValueKey('relation-different')))
            .getSemanticsData()
            .flagsCollection
            .isSelected
            .name,
        'isFalse');

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
    await tester.pumpWidget(
        host('B', audioB, _fixture(PhonemeRelation.same, 'u', 'u')));
    expect(audioA.stopCalls, 1);
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    final current = audioB.requests.last;
    audioA.requests.last.complete();
    await tester.pump();
    expect(_button(tester, 'Listen to sample B').enabled, isFalse);
    current.complete();
    await tester.pump();
    expect(_button(tester, 'Listen to sample B').enabled, isTrue);
    await tester.pumpWidget(
        host('A', audioA, _fixture(PhonemeRelation.same, 'u', 'u')));
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

  testWidgets(
      'comparison_suspension_requires_fresh_hearing_and_resume_does_not_autoplay',
      (tester) async {
    final audio = ControlledListeningAudio(), submissions = <PhonemeRelation>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ComparisonHarness(
                fixture: _fixture(PhonemeRelation.same, 'u', 'u'),
                audio: audio,
                ownerId: 'life',
                onSubmitted: submissions.add))));
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    final old = audio.requests.last;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(audio.stopCalls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(audio.requests, hasLength(1));
    old.complete();
    await tester.pump();
    expect(_button(tester, 'Same').enabled, isFalse);
    expect(submissions, isEmpty);
    await tester.pumpWidget(const SizedBox());
    audio.releaseAll();
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
    await tester.pumpWidget(host(_fixture(PhonemeRelation.same, 'u', 'u')));
    await tester.tap(find.text('Listen to sample A'));
    await tester.pump();
    final old = audio.requests.last;
    final changed = ComparisonFixture(
        prompt: SoundComparisonPrompt(
            id: 'cmp',
            instruction: 'Compare the final sound in each word',
            sampleAReferenceId: 'new-a',
            sampleBReferenceId: 'new-b'),
        targetLocationA: 'final sound',
        targetLocationB: 'final sound',
        targetPhonemeA: 'u',
        targetPhonemeB: 'u',
        expected: PhonemeRelation.same);
    await tester.pumpWidget(host(changed));
    old.complete();
    await tester.pump();
    expect(_button(tester, 'Same').enabled, isFalse);
    expect(audio.requests, hasLength(1));
    expect(audio.stopCalls, 1);
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
