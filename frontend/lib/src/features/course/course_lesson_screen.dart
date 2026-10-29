import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/course/course_audio.dart';
import '../../core/course/course_attempt.dart';
import '../../core/course/course_learning_checkpoint.dart';
import '../../core/course/course_learning_command.dart';
import '../../core/course/course_learning_error.dart';
import '../../core/course/course_learning_providers.dart';
import '../../core/course/course_learning_registry.dart';
import '../../core/course/course_learning_state.dart';
import '../../core/course/course_learning_store.dart';
import '../../core/course/french_course.dart';
import '../../core/services/recording_service.dart';
import '../../core/services/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'lesson_progress_indicator.dart';

class CourseLessonScreen extends ConsumerStatefulWidget {
  const CourseLessonScreen({
    super.key,
    required this.lessonId,
    this.review = false,
  });
  final String lessonId;
  final bool review;

  @override
  ConsumerState<CourseLessonScreen> createState() => _CourseLessonScreenState();
}

class _CourseLessonScreenState extends ConsumerState<CourseLessonScreen>
    with WidgetsBindingObserver {
  static const _saveError = 'This answer could not be saved. Retry saving.';
  static const _loadError =
      'Saved progress is unavailable. Retry loading to try again.';
  int _index = 0;
  bool _heard = false,
      _busy = true,
      _answered = false,
      _candidateAnswer = false,
      _recording = false;
  bool _audioPending = false;
  bool _contentChanged = false;
  bool _finished = false;
  String _feedback = '';
  String? _recordingPath;
  RecordingService? _recorder;
  Future<void>? _recordingOperation;
  CourseAudio? _audio;
  CourseLearningStore? _store, _pendingStore;
  CourseLearningState? _state;
  LearningCommand? _pending;
  String? _loadMessage;
  bool _saveFailed = false, _conflict = false;
  int _generation = 0, _listenGeneration = 0, _saveOperation = 0;
  int _recordingGeneration = 0;

  CourseLesson get _lesson => frenchLessons.firstWhere(
    (lesson) => lesson.id == widget.lessonId,
    orElse: () => frenchLessons.last,
  );
  bool get _isKnownLesson =>
      frenchLessons.any((lesson) => lesson.id == widget.lessonId);
  String get _activityId => 'lesson:${widget.lessonId}';
  LearningActivityDefinition get _definition =>
      LearningRegistry.french().require(_activityId);
  LearningSourceItem get _item => _definition.items[_index];
  CourseWord get _word => wordByText(_lesson.words[_index]);
  List<String> get _options => _item.choices;
  bool get _hasSubmittedAnswer {
    final candidate = _pending?.candidate;
    return _answered ||
        _candidateAnswer ||
        (candidate is LegacyLessonCheckpoint &&
            candidate.selectedSound != null);
  }

  int? get _acknowledgedCompleted {
    final CourseLearningState? state = _state;
    if (state == null) return null;
    final ActivitySlot? slot = state.activities[_activityId];
    if (slot == null) return 0;
    if (slot.contentRevision != _definition.contentRevision ||
        slot.snapshot is! LegacyLessonCheckpoint) {
      return null;
    }
    final LegacyLessonCheckpoint checkpoint =
        slot.snapshot as LegacyLessonCheckpoint;
    final int submitted =
        checkpoint.wordIndex + (checkpoint.selectedSound == null ? 0 : 1);
    return submitted.clamp(0, _lesson.words.length).toInt();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(courseLearningStoreProvider, _onStoreReplaced);
    final store = ref.read(courseLearningStoreProvider);
    _store = store;
    if (_isKnownLesson) unawaited(_load(store));
  }

  void _onStoreReplaced(CourseLearningStore? old, CourseLearningStore next) {
    if (old == null || identical(old, next)) return;
    _generation++;
    _saveOperation++;
    _listenGeneration++;
    _stopAudio();
    _recordingGeneration++;
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) unawaited(_releaseRecorder(recorder));
    _heard = false;
    _busy = false;
    _audioPending = false;
    _recording = false;
    _recordingPath = null;
    _feedback = '';
    _pending = null;
    _pendingStore = null;
    _saveFailed = false;
    _conflict = false;
    _state = null;
    _index = 0;
    _answered = false;
    _candidateAnswer = false;
    _finished = false;
    _store = next;
    if (_isKnownLesson) unawaited(_load(next));
  }

  @override
  void dispose() {
    _generation++;
    _listenGeneration++;
    _saveOperation++;
    _recordingGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    final recorder = _recorder;
    if (recorder != null) unawaited(_releaseRecorder(recorder));
    _stopAudio();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _listenGeneration++;
      _stopAudio();
      final retiredAudio = _audioPending;
      _audioPending = false;
      if (mounted) {
        setState(() {
          _heard = false;
          if (retiredAudio) _busy = false;
        });
      }
    }
  }

  void _stopAudio() {
    final audio = _audio;
    _audio = null;
    if (audio != null) unawaited(audio.stop().catchError((Object _) {}));
  }

  Future<void> _load(CourseLearningStore store, {bool retry = false}) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _loadMessage = null;
      _contentChanged = false;
      _finished = false;
      _heard = false;
      _pending = null;
      _saveFailed = false;
      _conflict = false;
      _candidateAnswer = false;
    });
    try {
      final state = retry ? await store.retryLoad() : await store.load();
      if (!mounted || generation != _generation) return;
      _state = state;
      final slot = state.activities[_activityId];
      if (slot == null) {
        final command = store.prepare(
          state: state,
          activityId: _activityId,
          action: StartLearningRun(options: RunOptions()),
        );
        _pending = command;
        _pendingStore = store;
        _busy = false;
        await _submitPending();
        return;
      }
      if (slot.contentRevision != _definition.contentRevision ||
          slot.snapshot is! LegacyLessonCheckpoint) {
        setState(() {
          _busy = false;
          _contentChanged = true;
          _loadMessage =
              'This lesson has changed. Start a new run to continue.';
        });
        return;
      }
      final checkpoint = slot.snapshot as LegacyLessonCheckpoint;
      if (checkpoint.finished) {
        setState(() {
          _busy = false;
          _finished = true;
          _loadMessage =
              'This lesson is complete. Start a new run to practise again.';
        });
        return;
      }
      if (checkpoint.wordIndex >= _lesson.words.length) {
        setState(() {
          _index = _lesson.words.length - 1;
          _answered = true;
          _busy = false;
        });
        await _finishRun();
        return;
      }
      setState(() {
        _index = checkpoint.wordIndex.clamp(0, _lesson.words.length - 1);
        _answered = checkpoint.selectedSound != null;
        _feedback = _answered ? _answerFeedback(checkpoint.selectedSound!) : '';
        _busy = false;
      });
    } on LearningUnsupportedVersionException {
      if (mounted && generation == _generation) _showUnavailable();
    } on LearningCorruptException {
      if (mounted && generation == _generation) _showUnavailable();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _loadMessage = _loadError;
        });
      }
    }
  }

  void _showUnavailable() {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _loadMessage = 'Saved learning progress is unavailable. Retry loading.';
    });
  }

  String _answerFeedback(String selected) {
    // On resume this is committed checkpoint presentation only; the store's
    // frozen feedback is held in-memory for a just-submitted answer.
    return '$selected — ${_word.text} /${_word.ipa}/ — ${_word.meaning}';
  }

  Future<void> _listen() async {
    if (_busy || _recording || _saveFailed || _pending != null) return;
    final generation = ++_listenGeneration;
    _audioPending = true;
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
      // Cancellation is quiet and never counts as hearing.
    } catch (_) {
      if (mounted && generation == _listenGeneration) {
        setState(
          () => _feedback =
              'French audio is unavailable right now. Tap "Listen to French word" to try again. You can still read the examples below.',
        );
      }
    } finally {
      if (mounted && generation == _listenGeneration) {
        _audioPending = false;
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _answer(String sound) async {
    if (!_heard ||
        _answered ||
        _busy ||
        _saveFailed ||
        _pending != null ||
        _state == null) {
      return;
    }
    _listenGeneration++;
    final command = _store!.prepare(
      state: _state!,
      activityId: _activityId,
      action: ChooseSound(
        selectedSound: sound,
        audioSource:
            authoredAudioSource(_item) ?? AttemptAudioSource.notApplicable,
      ),
    );
    _feedback = command.feedback.message;
    _pending = command;
    _pendingStore = _store;
    final candidate = command.candidate as LegacyLessonCheckpoint;
    setState(() => _candidateAnswer = candidate.selectedSound != null);
    await _submitPending();
  }

  Future<void> _submitPending() async {
    final command = _pending;
    final store = _pendingStore;
    if (command == null || store == null || _busy) return;
    final operation = ++_saveOperation;
    final generation = _generation;
    setState(() {
      _busy = true;
      _saveFailed = false;
      if (command.action is ChooseSound) _answered = true;
    });
    try {
      final commit = await store.submit(command);
      if (!mounted ||
          generation != _generation ||
          operation != _saveOperation) {
        return;
      }
      _state = commit.state;
      _pending = null;
      _pendingStore = null;
      if (command.action is StartLearningRun) {
        setState(() {
          _busy = false;
          _saveFailed = false;
          _contentChanged = false;
          _finished = false;
          _loadMessage = null;
          _index = 0;
          _heard = false;
          _answered = false;
          _candidateAnswer = false;
          _feedback = '';
        });
        ref.invalidate(courseLearningStateProvider);
        return;
      }
      if (command.action is AdvanceLesson) {
        final checkpoint = commit.slot.snapshot as LegacyLessonCheckpoint;
        if (checkpoint.wordIndex >= _lesson.words.length) {
          setState(() => _busy = false);
          await _finishRun();
          return;
        }
        _listenGeneration++;
        setState(() {
          _index = checkpoint.wordIndex;
          _heard = false;
          _answered = false;
          _candidateAnswer = false;
          _feedback = '';
          _recordingPath = null;
          _busy = false;
        });
        ref.invalidate(courseLearningStateProvider);
        return;
      }
      if (command.action is FinishLearningActivity) {
        ref.invalidate(courseLearningStateProvider);
        if (mounted) Navigator.of(context).pop();
        return;
      }
      setState(() {
        _busy = false;
        _saveFailed = false;
        _answered = command.action is ChooseSound ? true : _answered;
      });
      ref.invalidate(courseLearningStateProvider);
    } on LearningContentChangedException {
      if (mounted && generation == _generation && operation == _saveOperation) {
        _pending = null;
        _pendingStore = null;
        setState(() {
          _busy = false;
          _saveFailed = false;
          _contentChanged = true;
          _loadMessage =
              'This lesson has changed. Start a new run to continue.';
        });
      }
    } on LearningConflictException {
      if (mounted && generation == _generation && operation == _saveOperation) {
        _pending = null;
        _pendingStore = null;
        setState(() {
          _busy = false;
          _saveFailed = false;
          _conflict = true;
          _loadMessage =
              'This answer no longer matches saved progress. Reload saved progress to continue.';
        });
      }
    } on LearningUnavailableException {
      if (mounted && generation == _generation && operation == _saveOperation) {
        _pending = null;
        _pendingStore = null;
        setState(() {
          _busy = false;
          _saveFailed = false;
          _conflict = false;
          _answered = false;
          _candidateAnswer = false;
          _heard = false;
          _loadMessage = _loadError;
        });
      }
    } on LearningSaveException {
      _showSaveFailure(generation, operation, command);
    } on LearningInvalidCommandException {
      _showReloadRequired(
        generation,
        operation,
        'This learning action is no longer valid. Reload saved progress to continue.',
      );
    } catch (_) {
      _showReloadRequired(
        generation,
        operation,
        'This learning action could not be confirmed. Reload saved progress to continue.',
      );
    }
  }

  void _showSaveFailure(
    int generation,
    int operation,
    LearningCommand command,
  ) {
    if (!mounted || generation != _generation || operation != _saveOperation) {
      return;
    }
    setState(() {
      _busy = false;
      _saveFailed = true;
      if (command.action is ChooseSound) _answered = true;
      _feedback = '$_feedback\n$_saveError';
    });
  }

  void _showReloadRequired(int generation, int operation, String message) {
    if (!mounted || generation != _generation || operation != _saveOperation) {
      return;
    }
    _pending = null;
    _pendingStore = null;
    setState(() {
      _busy = false;
      _saveFailed = false;
      _conflict = true;
      _loadMessage = message;
    });
  }

  void _retrySave() {
    if (_pending != null && !_busy) unawaited(_submitPending());
  }

  Future<void> _next() async {
    if (_busy ||
        _recording ||
        !_answered ||
        _saveFailed ||
        _pending != null ||
        _state == null) {
      return;
    }
    final command = _store!.prepare(
      state: _state!,
      activityId: _activityId,
      action: const AdvanceLesson(),
    );
    _pending = command;
    _pendingStore = _store;
    await _submitPending();
  }

  Future<void> _finishRun() async {
    if (_state == null || _store == null || _busy || _pending != null) return;
    final command = _store!.prepare(
      state: _state!,
      activityId: _activityId,
      action: FinishLearningActivity(recordCompletion: !widget.review),
    );
    _pending = command;
    _pendingStore = _store;
    await _submitPending();
  }

  Future<void> _record() {
    if (_busy || !_answered) return Future<void>.value();
    final operation = _toggleRecording();
    _recordingOperation = operation;
    return operation;
  }

  Future<void> _toggleRecording() async {
    if (_busy || !_answered) return;
    final recorder = _recorder ??= RecordingService();
    final generation = ++_recordingGeneration;
    setState(() => _busy = true);
    try {
      if (_recording) {
        final path = await recorder.stopRecording();
        if (mounted && generation == _recordingGeneration) {
          setState(() {
            _recording = false;
            _recordingPath = path;
          });
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        if (!mounted || generation != _recordingGeneration) return;
        if (!await recorder.hasPermission()) {
          throw StateError('Microphone permission denied');
        }
        if (!mounted || generation != _recordingGeneration) return;
        final path =
            '${dir.path}/course_${DateTime.now().millisecondsSinceEpoch}.wav';
        await recorder.startRecording(path, isActive: () => mounted);
        if (mounted && generation == _recordingGeneration) {
          setState(() {
            _recording = true;
            _recordingPath = null;
          });
        }
      }
    } catch (_) {
      if (mounted && generation == _recordingGeneration) {
        setState(() {
          _feedback = 'Recording unavailable. Check microphone permissions.';
          _recording = false;
        });
      }
    } finally {
      if (mounted && generation == _recordingGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _releaseRecorder(RecordingService recorder) async {
    try {
      await _recordingOperation;
      await recorder.cancel();
    } catch (_) {
    } finally {
      recorder.dispose();
    }
  }

  void _openReference(bool opened) {
    if (!opened || _state == null || _busy || _pending != null) return;
    final contexts = <ItemContextKey>{
      for (final item in _definition.items)
        for (final target in item.targetSounds)
          ItemContextKey(itemId: item.id, targetSound: target),
    };
    final command = _store!.prepare(
      state: _state!,
      activityId: _activityId,
      action: ObserveAssistance(
        items: contexts,
        flags: const {AssistanceFlag.answerRevealed},
      ),
    );
    _pending = command;
    _pendingStore = _store;
    unawaited(_submitPending());
  }

  Future<void> _startNewRun() async {
    if ((!_contentChanged && !_finished) ||
        _state == null ||
        _busy ||
        _pending != null) {
      return;
    }
    final command = _store!.prepare(
      state: _state!,
      activityId: _activityId,
      action: StartLearningRun(options: RunOptions()),
    );
    _pending = command;
    _pendingStore = _store;
    await _submitPending();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isKnownLesson) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson unavailable')),
        body: const Center(child: Text('This lesson is unavailable.')),
      );
    }
    final int? completed = _acknowledgedCompleted;
    final Widget content = _loadMessage != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(_loadMessage!, textAlign: TextAlign.center),
                if (_saveFailed)
                  FilledButton(
                    onPressed: _busy ? null : _retrySave,
                    child: const Text('Retry saving'),
                  )
                else if (_conflict)
                  FilledButton(
                    onPressed: _busy ? null : () => _load(_store!),
                    child: const Text('Reload saved progress'),
                  )
                else if (!_contentChanged && !_finished)
                  FilledButton(
                    onPressed: _busy ? null : () => _load(_store!, retry: true),
                    child: const Text('Retry loading'),
                  ),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('ENGLISH → FRENCH'),
              const SizedBox(height: 12),
              Text(
                _lesson.explanation,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Text(
                'Listen ${_index + 1} of ${_lesson.words.length}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text('Which focus sound do you hear?'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy || _recording ? null : _listen,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.volume_up),
                label: Text(_busy ? 'Please wait…' : 'Listen to French word'),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: <Widget>[
                  for (final sound in _options)
                    OutlinedButton(
                      onPressed: _heard && !_answered && !_busy
                          ? () => _answer(sound)
                          : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 52),
                      ),
                      child: Text(
                        '/$sound/',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                ],
              ),
              if (_feedback.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_feedback),
                ),
              if (_hasSubmittedAnswer) ...<Widget>[
                const Text(
                  'Say it yourself. Recording and self-comparison are optional; no automated pronunciation grade.',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _record,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 52),
                      ),
                      icon: Icon(_recording ? Icons.stop : Icons.mic),
                      label: Text(
                        _recording ? 'Stop recording' : 'Record yourself',
                      ),
                    ),
                    if (_recordingPath != null)
                      TextButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(audioServiceProvider)
                                .play(_recordingPath!);
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => _feedback =
                                    'Recording playback unavailable.',
                              );
                            }
                          }
                        },
                        child: const Text('Hear your recording'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              ExpansionTile(
                enabled: _pending == null,
                title: const Text('Word reference'),
                onExpansionChanged: _openReference,
                children: <Widget>[
                  for (final text in _lesson.words)
                    ListTile(
                      title: Text('$text /${wordByText(text).ipa}/'),
                      subtitle: Text(wordByText(text).meaning),
                    ),
                ],
              ),
            ],
          );
    return Scaffold(
      appBar: AppBar(title: Text(_lesson.title)),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (completed != null)
              LessonProgressIndicator(
                completed: completed,
                total: _lesson.words.length,
              ),
            Expanded(
              child: LessonContentViewport(
                maxWidth: 640,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: content,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomAction(),
    );
  }

  Widget? _bottomAction() {
    String? label;
    VoidCallback? action;
    bool canAct = !_busy && !_recording && _pending == null;
    if (_saveFailed && _pending != null) {
      label = 'Retry saving';
      action = _retrySave;
      canAct = !_busy;
    } else if (_loadMessage != null && (_contentChanged || _finished)) {
      label = 'Start new run';
      action = _startNewRun;
    } else if (_loadMessage == null && _hasSubmittedAnswer) {
      label = _index == _lesson.words.length - 1 ? 'Finish' : 'Next word';
      action = _next;
      canAct = canAct && !_saveFailed && !_conflict && !_contentChanged;
    }
    if (label == null || action == null) return null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canAct ? action : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
