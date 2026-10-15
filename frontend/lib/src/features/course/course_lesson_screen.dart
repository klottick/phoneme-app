import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/course/french_course.dart';
import '../../core/course/course_audio.dart';
import '../../core/course/course_progress.dart';
import '../../core/services/recording_service.dart';
import '../../core/services/audio_service.dart';
import 'package:path_provider/path_provider.dart';

class CourseLessonScreen extends ConsumerStatefulWidget {
  const CourseLessonScreen(
      {super.key, required this.lessonId, this.review = false});
  final String lessonId;
  final bool review;
  @override
  ConsumerState<CourseLessonScreen> createState() => _CourseLessonScreenState();
}

class _CourseLessonScreenState extends ConsumerState<CourseLessonScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  bool _heard = false, _busy = false, _answered = false, _recording = false;
  bool _audioBusy = false;
  String _feedback = '';
  String? _recordingPath;
  RecordingService? _recorder;
  Future<void>? _recordingOperation;
  CourseAudio? _audio;

  /// Request-generation guard: a listen request that is superseded (new
  /// word, retry, or leaving the lesson) must not publish its late
  /// settlement over the newer state.
  int _listenGeneration = 0;
  CourseLesson get _lesson =>
      frenchLessons.firstWhere((l) => l.id == widget.lessonId,
          orElse: () => frenchLessons.last);
  CourseWord get _word => wordByText(_lesson.words[_index]);
  String get _expected => _lesson.sounds.firstWhere(_word.contains);
  List<String> get _options {
    final options = [
      _expected,
      ...['u', 'y', 'i', 'o', 'ɔ̃', 'ɑ̃', 'ʁ']
          .where((s) => !_word.contains(s))
          .take(3)
    ]..sort();
    return options;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final recorder = _recorder;
    if (recorder != null) unawaited(_releaseRecorder(recorder));
    _listenGeneration++;
    _audio?.stop().catchError((Object _) {});
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

  /// App suspension retires a held playback (I2): the generation is
  /// invalidated BEFORE the captured shared playback is stopped, then only
  /// the audio-owned state is reset. The microphone/recorder operation is
  /// deliberately untouched: a capture in flight keeps its own busy guard
  /// and its own cleanup; resuming requires a fresh listen and never
  /// auto-replays the retired request.
  void _retireForBackground() {
    final CourseAudio? audio = _audio;
    if (audio == null && !_audioBusy) return;
    _listenGeneration++;
    _audio = null;
    if (audio != null) {
      unawaited(audio.stop().catchError((Object _) {}));
    }
    final bool retiredAudioBusy = _audioBusy;
    _audioBusy = false;
    if (mounted) {
      setState(() {
        _heard = false;
        if (retiredAudioBusy) {
          _busy = false;
        }
      });
    }
  }

  Future<void> _releaseRecorder(RecordingService recorder) async {
    try {
      // A native start already in flight must finish before cancellation and
      // disposal; otherwise it could reactivate the microphone after cleanup.
      await _recordingOperation;
      await recorder.cancel();
    } catch (_) {
      // Release native resources even when startup or cancellation fails.
    } finally {
      recorder.dispose();
    }
  }

  Future<void> _listen() async {
    if (_busy || _recording) return;
    final int generation = ++_listenGeneration;
    _audioBusy = true;
    setState(() {
      _busy = true;
      _heard = false;
      _feedback = '';
    });
    try {
      _audio = ref.read(courseAudioProvider);
      await _audio!.speak(_word.text);
      if (mounted && generation == _listenGeneration) {
        setState(() => _heard = true);
      }
    } on CourseAudioCancelledException {
      // Cancellation (Stop, disposal, navigation) is not an audio failure:
      // no feedback, never a heard mark, and listening stays retryable.
    } catch (_) {
      if (mounted && generation == _listenGeneration) {
        setState(() => _feedback =
            'French audio is unavailable right now. Tap "Listen to French word" to try again. You can still read the examples below.');
      }
    } finally {
      if (mounted && generation == _listenGeneration) {
        _audioBusy = false;
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _answer(String sound) async {
    if (!_heard || _answered || _busy) return;
    final correct = sound == _expected;
    setState(() {
      _answered = true;
      _feedback =
          '${correct ? 'Yes!' : 'Listen again:'} ${_word.text} /${_word.ipa}/ — ${_word.meaning}';
    });
    try {
      await CourseProgressStore(frenchCourse.id)
          .record(_expected, 'listening', correct);
      if (mounted) ref.invalidate(courseProgressProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _feedback += '\nThis answer could not be saved.');
      }
    }
  }

  Future<void> _record() {
    if (_busy || !_answered) return Future<void>.value();
    final operation = _toggleRecording();
    _recordingOperation = operation;
    return operation;
  }

  Future<void> _toggleRecording() async {
    if (_busy || !_answered) return;
    // The lesson owns this recorder. Delayed cleanup must never stop a recorder
    // that another screen obtained from the shared application provider.
    final recorder = _recorder ??= RecordingService();
    setState(() => _busy = true);
    try {
      if (_recording) {
        final path = await recorder.stopRecording();
        if (mounted) {
          setState(() {
            _recording = false;
            _recordingPath = path;
          });
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        if (!mounted) return;
        if (!await recorder.hasPermission()) {
          throw StateError('Microphone permission denied');
        }
        if (!mounted) return;
        final path =
            '${dir.path}/course_${DateTime.now().millisecondsSinceEpoch}.wav';
        await recorder.startRecording(path, isActive: () => mounted);
        if (mounted) {
          setState(() {
            _recording = true;
            _recordingPath = null;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedback = 'Recording unavailable. Check microphone permissions.';
          _recording = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (_busy || _recording) return;
    if (_index < _lesson.words.length - 1) {
      // A new word owns the next listen request: the previous one's late
      // settlement must not publish over this state.
      _listenGeneration++;
      setState(() {
        _index++;
        _heard = false;
        _answered = false;
        _feedback = '';
        _recordingPath = null;
      });
    } else {
      setState(() => _busy = true);
      try {
        if (!widget.review) {
          await CourseProgressStore(frenchCourse.id).completeLesson(_lesson.id);
        }
        ref.invalidate(courseProgressProvider);
        if (mounted) Navigator.of(context).pop();
      } catch (_) {
        if (mounted) {
          setState(() {
            _busy = false;
            _feedback = 'Could not save completion. Tap Finish to retry.';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_lesson.title)),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text('ENGLISH → FRENCH'),
                    const SizedBox(height: 12),
                    Text(_lesson.explanation,
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                        value: _index / _lesson.words.length),
                    const SizedBox(height: 16),
                    Text('Listen ${_index + 1} of ${_lesson.words.length}',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Text('Which focus sound do you hear?'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                        onPressed: _busy || _recording ? null : _listen,
                        icon: const Icon(Icons.volume_up),
                        label: Text(
                            _busy ? 'Please wait…' : 'Listen to French word')),
                    const SizedBox(height: 8),
                    Text(alphaAudioDisclosure,
                        style: Theme.of(context).textTheme.bodySmall),
                    Wrap(spacing: 12, children: [
                      for (final sound in _options)
                        OutlinedButton(
                            onPressed: _heard && !_answered && !_busy
                                ? () => _answer(sound)
                                : null,
                            child: Text('/$sound/',
                                style: const TextStyle(fontSize: 24))),
                    ]),
                    if (_feedback.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(_feedback)),
                    if (_answered) ...[
                      const Text(
                          'Say it yourself. Recording and self-comparison are optional; no automated pronunciation grade.'),
                      Wrap(spacing: 8, children: [
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _record,
                            icon: Icon(_recording ? Icons.stop : Icons.mic),
                            label: Text(_recording
                                ? 'Stop recording'
                                : 'Record yourself')),
                        if (_recordingPath != null)
                          TextButton(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(audioServiceProvider)
                                      .play(_recordingPath!);
                                } catch (_) {
                                  if (mounted) {
                                    setState(() => _feedback =
                                        'Recording playback unavailable.');
                                  }
                                }
                              },
                              child: const Text('Hear your recording')),
                      ]),
                      FilledButton(
                          onPressed: _busy || _recording ? null : _next,
                          child: Text(_index == _lesson.words.length - 1
                              ? 'Finish'
                              : 'Next word')),
                    ],
                    const SizedBox(height: 24),
                    ExpansionTile(
                        title: const Text('Word reference'),
                        children: [
                          for (final text in _lesson.words)
                            ListTile(
                                title: Text('$text /${wordByText(text).ipa}/'),
                                subtitle: Text(wordByText(text).meaning)),
                        ]),
                  ],
                ))),
      );
}
