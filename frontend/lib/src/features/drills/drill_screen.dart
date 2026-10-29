import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/course/course_audio.dart';
import '../../core/course/course_attempt.dart';
import '../../core/course/course_learning_checkpoint.dart';
import '../../core/course/course_learning_command.dart';
import '../../core/course/course_learning_error.dart';
import '../../core/course/course_learning_providers.dart';
import '../../core/course/course_learning_registry.dart';
import '../../core/course/course_learning_state.dart';
import '../../core/course/course_learning_store.dart';
import '../../core/models/minimal_pair.dart';

class DrillScreen extends ConsumerStatefulWidget {
  const DrillScreen({super.key});

  @override
  ConsumerState<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends ConsumerState<DrillScreen>
    with WidgetsBindingObserver {
  static const _activityId = 'drill:minimal-pairs';
  static const _saveError = 'Could not save your answer. Please try again.';
  CourseLearningStore? _store, _pendingStore;
  CourseLearningState? _state;
  LearningCommand? _pending;
  DrillCheckpoint? _checkpoint;
  bool _loading = true, _contentChanged = false;
  bool _busy = false, _isPlaying = false, _heard = false;
  bool _answerTransition = false, _ending = false, _saveFailed = false;
  bool _conflict = false;
  String? _message;
  String _feedback = '';
  CourseAudio? _audio;
  int _playGeneration = 0,
      _ownerGeneration = 0,
      _saveOperation = 0,
      _answerOperation = 0,
      _finishOperation = 0;
  bool _endCommitted = false;

  LearningActivityDefinition get _definition =>
      LearningRegistry.french().require(_activityId);
  List<MinimalPair> get _pairs => frenchDrillPairs;
  int get _index => _checkpoint?.index ?? 0;
  int get _correct => _checkpoint?.correct ?? 0;
  bool get _ended => _checkpoint?.ended ?? false;
  MinimalPair get _current => _pairs[_index % _pairs.length];
  LearningSourceItem get _item =>
      _definition.items.firstWhere((item) => item.id == _current.id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(courseLearningStoreProvider, _onStoreReplaced);
    final store = ref.read(courseLearningStoreProvider);
    _store = store;
    unawaited(_load(store));
  }

  void _onStoreReplaced(CourseLearningStore? old, CourseLearningStore next) {
    if (old == null || identical(old, next)) return;
    _ownerGeneration++;
    _saveOperation++;
    _answerOperation++;
    _finishOperation++;
    _playGeneration++;
    _retireAudio();
    _pending = null;
    _pendingStore = null;
    _state = null;
    _checkpoint = null;
    _busy = false;
    _answerTransition = false;
    _heard = false;
    _conflict = false;
    _saveFailed = false;
    _ending = false;
    _endCommitted = false;
    _isPlaying = false;
    _feedback = '';
    _store = next;
    unawaited(_load(next));
  }

  @override
  void dispose() {
    _ownerGeneration++;
    _saveOperation++;
    _answerOperation++;
    _finishOperation++;
    WidgetsBinding.instance.removeObserver(this);
    _retireAudio();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _retireAudio();
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _heard = false;
        });
      }
    }
  }

  void _retireAudio() {
    _playGeneration++;
    final audio = _audio;
    if (audio != null) unawaited(audio.stop().catchError((Object _) {}));
    _audio = null;
  }

  Future<void> _load(CourseLearningStore store, {bool retry = false}) async {
    final generation = ++_ownerGeneration;
    setState(() {
      _loading = true;
      _busy = false;
      _message = null;
      _contentChanged = false;
      _conflict = false;
      _heard = false;
    });
    try {
      final state = retry ? await store.retryLoad() : await store.load();
      if (!mounted || generation != _ownerGeneration) return;
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
        await _submitPending();
        return;
      }
      if (slot.contentRevision != _definition.contentRevision ||
          slot.snapshot is! DrillCheckpoint) {
        setState(() {
          _loading = false;
          _contentChanged = true;
          _message = 'This drill has changed. Start a new run to continue.';
        });
        return;
      }
      final checkpoint = slot.snapshot as DrillCheckpoint;
      if (checkpoint.pairIds.length != _pairs.length ||
          checkpoint.pairIds.asMap().entries.any(
            (entry) => entry.value != _pairs[entry.key].id,
          )) {
        setState(() {
          _loading = false;
          _contentChanged = true;
          _message = 'This drill has changed. Start a new run to continue.';
        });
        return;
      }
      setState(() {
        _checkpoint = checkpoint;
        _loading = false;
        _heard = false;
        _endCommitted = checkpoint.ended;
      });
    } on LearningCorruptException {
      if (mounted && generation == _ownerGeneration) _unavailableState();
    } on LearningUnsupportedVersionException {
      if (mounted && generation == _ownerGeneration) _unavailableState();
    } catch (_) {
      if (mounted && generation == _ownerGeneration) {
        setState(() {
          _loading = false;
          _message = 'Saved progress is unavailable. Retry loading.';
        });
      }
    }
  }

  void _unavailableState() {
    if (mounted) {
      setState(() {
        _loading = false;
        _message = 'Saved learning progress is unavailable. Retry loading.';
      });
    }
  }

  Future<void> _play(MinimalPair pair, int itemIndex) async {
    if (_loading ||
        _busy ||
        _pending != null ||
        _ending ||
        _answerTransition ||
        _checkpoint == null ||
        _ended ||
        _index != itemIndex) {
      return;
    }
    final generation = ++_playGeneration;
    setState(() {
      _isPlaying = true;
      _heard = false;
      _feedback = '';
    });
    try {
      final audio = ref.read(courseAudioProvider);
      _audio = audio;
      await audio.speak(pair.wordA);
      if (mounted && generation == _playGeneration) {
        setState(() {
          _heard = true;
          _isPlaying = false;
        });
      }
    } on CourseAudioCancelledException {
      // Cancel is quiet and does not satisfy the fresh-hearing gate.
      if (mounted && generation == _playGeneration) {
        setState(() => _isPlaying = false);
      }
    } catch (_) {
      if (mounted && generation == _playGeneration) {
        setState(() {
          _isPlaying = false;
          _feedback = 'French audio unavailable. Please retry.';
        });
      }
    }
  }

  Future<void> _onPlayStopFor(MinimalPair pair, int itemIndex) async {
    if (_index != itemIndex ||
        _pending != null ||
        _ending ||
        _ended ||
        _answerTransition ||
        _busy) {
      return;
    }
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
    await _play(pair, itemIndex);
  }

  Future<void> _answer(String selected, int itemIndex) async {
    if (_loading ||
        _busy ||
        _pending != null ||
        _ending ||
        _ended ||
        _answerTransition ||
        _index != itemIndex ||
        !_heard ||
        _state == null ||
        _checkpoint == null) {
      return;
    }
    final owner = _ownerGeneration;
    final operation = ++_answerOperation;
    _answerTransition = true;
    _playGeneration++;
    final command = _store!.prepare(
      state: _state!,
      activityId: _activityId,
      action: ChooseDrillWord(
        selectedWord: selected,
        audioSource:
            authoredAudioSource(_item) ?? AttemptAudioSource.notApplicable,
      ),
    );
    _pending = command;
    _pendingStore = _store;
    setState(() {
      _heard = false;
      _saveFailed = false;
      _feedback = command.feedback.message;
    });
    await _submitPending();
    if (mounted && owner == _ownerGeneration && operation == _answerOperation) {
      _answerTransition = false;
    }
  }

  Future<void> _submitPending() async {
    final command = _pending;
    final store = _pendingStore;
    if (command == null || store == null || _busy) return;
    final operation = ++_saveOperation;
    final owner = _ownerGeneration;
    setState(() {
      _busy = true;
      _loading = false;
      _saveFailed = false;
    });
    try {
      final commit = await store.submit(command);
      if (!mounted ||
          owner != _ownerGeneration ||
          operation != _saveOperation) {
        return;
      }
      _state = commit.state;
      _checkpoint = commit.slot.snapshot as DrillCheckpoint;
      _pending = null;
      _pendingStore = null;
      _endCommitted = _checkpoint!.ended;
      if (command.action is StartLearningRun) {
        setState(() {
          _busy = false;
          _loading = false;
          _saveFailed = false;
          _contentChanged = false;
          _message = null;
          _heard = false;
        });
        ref.invalidate(courseLearningStateProvider);
        return;
      }
      setState(() {
        _busy = false;
        _saveFailed = false;
        _feedback = command.feedback.message;
      });
      ref.invalidate(courseLearningStateProvider);
      if (command.action is EndDrill) await _finishSession();
    } on LearningContentChangedException {
      if (mounted && owner == _ownerGeneration && operation == _saveOperation) {
        _pending = null;
        _pendingStore = null;
        setState(() {
          _busy = false;
          _saveFailed = false;
          _contentChanged = true;
          _message = 'This drill has changed. Start a new run to continue.';
        });
      }
    } on LearningConflictException {
      if (mounted && owner == _ownerGeneration && operation == _saveOperation) {
        _showReloadRequired(
          'This answer no longer matches saved progress. Reload saved progress to continue.',
          owner,
          operation,
        );
      }
    } on LearningUnavailableException {
      if (mounted && owner == _ownerGeneration && operation == _saveOperation) {
        _pending = null;
        _pendingStore = null;
        setState(() {
          _busy = false;
          _loading = false;
          _saveFailed = false;
          _ending = false;
          _conflict = false;
          _heard = false;
          _checkpoint = null;
          _message = 'Saved progress is unavailable. Retry loading.';
        });
      }
    } on LearningSaveException {
      _showSaveFailure(owner, operation, command);
    } on LearningInvalidCommandException {
      _showReloadRequired(
        'This learning action is no longer valid. Reload saved progress to continue.',
        owner,
        operation,
      );
    } catch (_) {
      _showReloadRequired(
        'This learning action could not be confirmed. Reload saved progress to continue.',
        owner,
        operation,
      );
    }
  }

  void _showSaveFailure(int owner, int operation, LearningCommand command) {
    if (!mounted || owner != _ownerGeneration || operation != _saveOperation) {
      return;
    }
    setState(() {
      _busy = false;
      _saveFailed = true;
      if (command.action is EndDrill) _ending = false;
      _heard = false;
      _feedback = command.feedback.message.isEmpty
          ? _saveError
          : '${command.feedback.message}\n$_saveError';
    });
  }

  void _showReloadRequired(String message, int owner, int operation) {
    if (!mounted || owner != _ownerGeneration || operation != _saveOperation) {
      return;
    }
    _pending = null;
    _pendingStore = null;
    setState(() {
      _busy = false;
      _saveFailed = false;
      _ending = false;
      _conflict = true;
      _message = message;
    });
  }

  void _retrySave() {
    if (_pending != null && !_busy) unawaited(_submitPending());
  }

  Future<void> _endSession() async {
    if (_ending || _pending != null || _state == null || _checkpoint == null) {
      return;
    }
    if (!_endCommitted) {
      final command = _store!.prepare(
        state: _state!,
        activityId: _activityId,
        action: const EndDrill(),
      );
      _pending = command;
      _pendingStore = _store;
      _ending = true;
      _retireAudio();
      setState(() {
        _heard = false;
        _isPlaying = false;
      });
      await _submitPending();
      return;
    }
    _ending = true;
    _retireAudio();
    setState(() {
      _heard = false;
      _isPlaying = false;
    });
    await _finishSession();
  }

  Future<void> _finishSession() async {
    final owner = _ownerGeneration;
    final operation = ++_finishOperation;
    try {
      await ref.read(streakServiceProvider).recordPractice();
    } catch (_) {
      if (mounted &&
          owner == _ownerGeneration &&
          operation == _finishOperation) {
        setState(() {
          _ending = false;
          _busy = false;
          _feedback = 'Could not save session. Tap End Session to retry.';
        });
      }
      return;
    }
    if (!mounted ||
        owner != _ownerGeneration ||
        operation != _finishOperation) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Session complete! $_correct / ${_index == 0 ? 0 : _index} correct',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _startNewRun() async {
    if (!_contentChanged || _state == null || _busy || _pending != null) return;
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_message != null || _checkpoint == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Minimal Pair Drill')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_message ?? 'Saved progress is unavailable.'),
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
              else if (_contentChanged)
                FilledButton(
                  onPressed: _busy ? null : _startNewRun,
                  child: const Text('Start new run'),
                )
              else
                FilledButton(
                  onPressed: _busy ? null : () => _load(_store!, retry: true),
                  child: const Text('Retry loading'),
                ),
            ],
          ),
        ),
      );
    }
    final current = _current;
    final itemIndex = _index;
    final options = _item.choices;
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Item ${itemIndex + 1}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Listen and choose the word you hear.'),
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
                  onPressed:
                      _ending ||
                          _ended ||
                          _answerTransition ||
                          _busy ||
                          _pending != null
                      ? null
                      : () => _onPlayStopFor(current, itemIndex),
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
                    onPressed:
                        !_ending &&
                            !_ended &&
                            !_answerTransition &&
                            !_busy &&
                            _pending == null &&
                            _heard &&
                            !_isPlaying
                        ? () => _answer(option, itemIndex)
                        : null,
                    child: Text(option, textAlign: TextAlign.center),
                  ),
                ),
              ),
            if (_feedback.isNotEmpty) Text(_feedback),
            if (_saveFailed)
              FilledButton(
                onPressed: _busy ? null : _retrySave,
                child: const Text('Retry saving'),
              ),
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: _ending || _busy || _pending != null
                    ? null
                    : _endSession,
                child: const Text('End Session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
