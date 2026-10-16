import 'package:flutter/material.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/features/course/exercises/listening_exercise_contract.dart';
import 'package:linguist/src/features/course/exercises/sound_comparison.dart';

final class ComparisonFixture {
  ComparisonFixture(
      {required this.prompt,
      required this.targetLocationA,
      required this.targetLocationB,
      required this.targetPhonemeA,
      required this.targetPhonemeB,
      required this.expected}) {
    for (final value in [
      targetLocationA,
      targetLocationB,
      targetPhonemeA,
      targetPhonemeB
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(
            value, 'target declaration', 'must not be blank');
      }
    }
    if ((targetPhonemeA == targetPhonemeB) !=
        (expected == PhonemeRelation.same)) {
      throw ArgumentError(
          'expected relation must match declared phoneme identities');
    }
  }
  final SoundComparisonPrompt prompt;
  final String targetLocationA, targetLocationB, targetPhonemeA, targetPhonemeB;
  final PhonemeRelation expected;
}

class ComparisonHarness extends StatefulWidget {
  const ComparisonHarness(
      {super.key,
      required this.fixture,
      required this.audio,
      required this.ownerId,
      required this.onSubmitted});
  final ComparisonFixture fixture;
  final CourseReferenceAudio audio;
  final String ownerId;
  final ValueChanged<PhonemeRelation> onSubmitted;
  @override
  State<ComparisonHarness> createState() => _ComparisonHarnessState();
}

class _ComparisonHarnessState extends State<ComparisonHarness>
    with WidgetsBindingObserver {
  final Set<ComparisonSample> _heard = {};
  bool _busy = false, _answered = false, _blocked = false;
  ComparisonSample? _playing;
  PhonemeRelation? _selected;
  ListeningFeedback? _feedback;
  String? _error;
  int _generation = 0;
  CourseReferenceAudio? _activeAudio;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _generation++;
        _blocked = false;
        _heard.clear();
        _busy = false;
        _playing = null;
        _activeAudio = null;
      });
    } else {
      _blocked = true;
      _invalidate(resetAnswer: false);
    }
  }

  void _invalidate({bool resetAnswer = true}) {
    final audio = _activeAudio;
    _generation++;
    _heard.clear();
    _busy = false;
    _playing = null;
    _activeAudio = null;
    if (resetAnswer) {
      _answered = false;
      _selected = null;
      _feedback = null;
    }
    _error = null;
    if (audio != null) audio.stop();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ComparisonHarness oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audio != widget.audio ||
        oldWidget.ownerId != widget.ownerId ||
        !_sameFixture(oldWidget.fixture, widget.fixture)) {
      _invalidate();
    }
  }

  bool _sameFixture(ComparisonFixture a, ComparisonFixture b) =>
      a.prompt.id == b.prompt.id &&
      a.prompt.instruction == b.prompt.instruction &&
      a.prompt.sampleAReferenceId == b.prompt.sampleAReferenceId &&
      a.prompt.sampleBReferenceId == b.prompt.sampleBReferenceId &&
      a.targetLocationA == b.targetLocationA &&
      a.targetLocationB == b.targetLocationB &&
      a.targetPhonemeA == b.targetPhonemeA &&
      a.targetPhonemeB == b.targetPhonemeB &&
      a.expected == b.expected;
  Future<void> _listen(ComparisonSample sample) async {
    if (_busy || _blocked || _answered) return;
    _busy = true;
    _playing = sample;
    _heard.remove(sample);
    _error = null;
    final generation = ++_generation;
    final audio = widget.audio;
    _activeAudio = audio;
    final referenceId = sample == ComparisonSample.a
        ? widget.fixture.prompt.sampleAReferenceId
        : widget.fixture.prompt.sampleBReferenceId;
    setState(() {});
    try {
      final result = await audio.playReference(referenceId,
          use: CourseAudioUse.alphaPractice,
          variant: CourseAudioVariant.normal,
          allowPracticeTts: false);
      if (!mounted || generation != _generation || audio != widget.audio) {
        return;
      }
      _busy = false;
      _playing = null;
      _activeAudio = null;
      if (result.outcome == CourseAudioOutcome.completed &&
          result.referenceId == referenceId) {
        _heard.add(sample);
      } else if (result.outcome == CourseAudioOutcome.failed ||
          (result.outcome == CourseAudioOutcome.completed &&
              result.referenceId != referenceId)) {
        _error = 'Audio unavailable. Try listening again.';
      }
      setState(() {});
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      _busy = false;
      _playing = null;
      _activeAudio = null;
      if (error is! CourseAudioCancelledException) {
        _error = 'Audio unavailable. Try listening again.';
      }
      setState(() {});
    }
  }

  void _answer(PhonemeRelation relation) {
    if (_busy || _blocked || _answered || _heard.length != 2) return;
    _answered = true;
    _selected = relation;
    _feedback = relation == widget.fixture.expected
        ? ListeningFeedback.correct
        : ListeningFeedback.notYet;
    widget.onSubmitted(relation);
    setState(() {});
  }

  @override
  void dispose() {
    final audio = _activeAudio;
    _generation++;
    _activeAudio = null;
    if (audio != null) audio.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
          child: Column(children: [
        if (_error != null) Text(_error!),
        SoundComparison(
            prompt: widget.fixture.prompt,
            state: ListeningExerciseState(
                busy: _busy,
                playing: _playing != null,
                blocked: _blocked,
                answered: _answered,
                feedback: _feedback),
            heardSamples: _heard,
            selectedRelation: _selected,
            onListen: _listen,
            onAnswer: _answer)
      ]));
}
