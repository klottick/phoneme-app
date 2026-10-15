import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/course/course_audio.dart';
import '../../core/course/course_progress.dart';

class DrillScreen extends ConsumerStatefulWidget {
  const DrillScreen({super.key});

  @override
  ConsumerState<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends ConsumerState<DrillScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  int _correct = 0;
  bool _isPlaying = false;
  bool _heard = false;
  bool _ending = false;
  bool _answerTransition = false;
  CourseAudio? _audio;

  /// Request-generation guard: a playback that is superseded (Stop control,
  /// End Session, leaving the screen) must not publish its late settlement
  /// over the current state — no heard mark, no unlock, no failure text.
  int _playGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retireAudio();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _retireForBackground();
    }
  }

  /// Retires in-flight shared playback: the current request loses ownership
  /// FIRST (its late settlement is cancelled and ignored) and then stops.
  void _retireAudio() {
    _playGeneration++;
    final CourseAudio? audio = _audio;
    if (audio != null) {
      unawaited(audio.stop().catchError((Object _) {}));
    }
  }

  /// App suspension retires a held playback (I2): invalidate the generation
  /// before stopping the captured shared playback, then reset the drill's
  /// playback/hearing state so a stale settlement cannot unlock or replay.
  /// Scoring and the End Session streak path are untouched; a fresh
  /// foreground Play is required and resume never auto-replays.
  void _retireForBackground() {
    _retireAudio();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _heard = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairs = ref.watch(minimalPairsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minimal Pair Drill'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_correct / ${_index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: pairs.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No drill items yet.'));
          }

          final current = items[_index % items.length];
          final int itemIndex = _index;
          final options = <String>[current.wordA, current.wordB]
            ..shuffle(Random());

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item ${_index + 1}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Listen and choose the word you hear.'),
                const SizedBox(height: 4),
                const Text(
                  alphaAudioDisclosure,
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '${current.phonemeA} vs ${current.phonemeB}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                      iconSize: 36,
                      tooltip: 'Play audio',
                       onPressed: _ending || _answerTransition
                           ? null
                           : () => _onPlayStop(current, itemIndex),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                for (final option in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: !_ending && !_answerTransition && _heard && !_isPlaying
                            ? () => _handleAnswer(option, current.wordA, current, itemIndex)
                            : null,
                        child: Text(option, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                const Spacer(),
                Center(
                  child: TextButton(
                    onPressed: _ending ? null : _endSession,
                    child: const Text('End Session'),
                  ),
                ),
              ],
            ),
          );
        },
        error: (error, _) =>
            Center(child: Text('Failed to load drills: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  /// Play/Stop control: while a playback is held, the same control retires
  /// it — the request loses ownership and its late settlement is ignored —
  /// so a user stop never marks heard, unlocks the choices, or surfaces as
  /// an audio failure.
  Future<void> _onPlayStop(dynamic currentPair, int itemIndex) async {
    if (_ending || _answerTransition || _index != itemIndex) return;
    if (_isPlaying) {
      _retireAudio();
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _heard = false;
        });
      }
      return;
    }
    await _playAudio(currentPair, itemIndex);
  }

  Future<void> _playAudio(dynamic currentPair, int itemIndex) async {
    if (_ending || _answerTransition || _index != itemIndex) return;
    final int generation = ++_playGeneration;
    setState(() {
      _isPlaying = true;
      _heard = false;
    });
    try {
      final CourseAudio audio = ref.read(courseAudioProvider);
      // Captured for retirement: Stop, End Session, and disposal must be
      // able to stop exactly this shared playback.
      _audio = audio;
      await audio.speak(currentPair.wordA);
      if (mounted && generation == _playGeneration) {
        setState(() => _heard = true);
      }
    } on CourseAudioCancelledException {
      // Retired by the Stop control, End Session, or screen disposal: the
      // request is no longer owned, so its settlement is ignored.
    } catch (_) {
      if (mounted && generation == _playGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('French audio unavailable. Please retry.')));
      }
    } finally {
      if (mounted && generation == _playGeneration) {
        setState(() => _isPlaying = false);
      }
    }
  }

  Future<void> _handleAnswer(
    String selected,
    String correct,
    dynamic currentPair,
    int itemIndex,
  ) async {
    if (_ending || _answerTransition || _index != itemIndex || !_heard || _isPlaying) return;
    _answerTransition = true;
    ++_playGeneration;
    final int answeringIndex = _index;
    final isCorrect = selected == correct;
    if (isCorrect) {
      _correct++;
    }

    setState(() => _heard = false);
    try {
      await CourseProgressStore('en-fr').record(
          (currentPair.phonemeA as String).replaceAll('/', ''),
          'listening',
          isCorrect);
    } catch (_) {
      if (mounted && answeringIndex == _index) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save your answer. Please try again.')));
      }
      return;
    } finally {
      _answerTransition = false;
      if (mounted && answeringIndex == _index) {
        setState(() {
          _isPlaying = false;
          _heard = false;
        });
      }
    }
    ref.invalidate(courseProgressProvider);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isCorrect ? '✓ Correct' : '✗ Try: $correct'),
        backgroundColor: isCorrect ? Colors.green : Colors.orange,
      ),
    );

    setState(() {
      ++_playGeneration;
      _isPlaying = false;
      _heard = false;
      _index++;
    });
  }

  Future<void> _endSession() async {
    if (_ending) return;
    setState(() {
      _ending = true;
      _heard = false;
      _isPlaying = false;
    });
    // Retire any in-flight playback before the screen exits, so a late
    // settlement can never mark heard or unlock the choices.
    _retireAudio();
    try {
      await ref.read(streakServiceProvider).recordPractice();
    } catch (_) {
      if (mounted) setState(() => _ending = false);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Session complete! $_correct / ${_index + 1} correct'),
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
