import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/course/course_audio.dart';
import '../../core/course/course_attempt.dart';
import '../../core/course/course_learning_command.dart';
import '../../core/course/course_learning_checkpoint.dart';
import '../../core/course/course_learning_error.dart';
import '../../core/course/course_learning_providers.dart';
import '../../core/course/course_learning_state.dart';
import '../../core/course/course_learning_store.dart';
import '../../core/course/french_course.dart';
import 'sound_match_engine.dart';
import 'word_match_engine.dart';

class ArcadeLobby extends StatelessWidget {
  const ArcadeLobby({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sound arcade')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Text('One minute. One more combo.',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const Text(
              'English → French\nPlay a quick round or keep your board going. No lives, no daily limits.'),
          const SizedBox(height: 24),
          Card(
              child: ListTile(
                  contentPadding: const EdgeInsets.all(24),
                  leading: const Icon(Icons.headphones, size: 36),
                  title: const Text('Sound Match'),
                  subtitle: const Text(
                      'Swap gems. Chase cascades. Hear French sounds.\nAudio required · 60 seconds'),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => context.push('/arcade/sound'))),
          Card(
              child: ListTile(
                  contentPadding: const EdgeInsets.all(24),
                  leading: const Icon(Icons.gesture, size: 36),
                  title: const Text('Word Match'),
                  subtitle: const Text(
                      'Link words. Clear obstacles. Find their shared sound.\nNo audio needed · 60 seconds'),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => context.push('/arcade/word'))),
          const SizedBox(height: 20),
          const Text(
              'Game points reward puzzle skill. Sound answers are tracked separately from your score.'),
        ]),
      );
}

class ArcadeScreen extends ConsumerStatefulWidget {
  const ArcadeScreen({super.key, required this.silent});
  final bool silent;
  @override
  ConsumerState<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends ConsumerState<ArcadeScreen>
    with WidgetsBindingObserver {
  late CourseLearningStore _store;
  CourseLearningState? _state;
  ActivitySlot? _slot;
  WordMatchEngine _word = WordMatchEngine();
  SoundMatchEngine _sound = SoundMatchEngine();
  final _chain = <int>[];
  final _boardKey = GlobalKey();
  Offset? _dragOrigin;
  Timer? _timer;
  bool _loading = true, _started = false, _busy = false, _showSummary = false;
  bool _audioReady = false, _background = false;
  bool _saveBusy = false;
  int _elapsed = 0, _generation = 0, _loadOp = 0;
  LearningCommand? _pendingCommand;
  CourseLearningStore? _pendingStore;
  VoidCallback? _pendingSuccess;
  int? _selected;
  int _cueAge = 0;

  /// Cue request-generation (I3): a cue that is superseded (suspension,
  /// switch to Word Match, disposal) loses ownership BEFORE its stop; a
  /// stale settlement of the retired cue can then neither arm the bonus,
  /// publish failure feedback, nor clear a newer request's busy state.
  int _cueGeneration = 0;
  String? _cueSound, _cueWord;
  String _message = '';
  String? _saveError;
  CourseAudio? _audio;
  String get _activityId => widget.silent ? 'arcade:word' : 'arcade:sound';
  ArcadeClockState? get _clock => switch (_slot?.snapshot) {
        SoundGameCheckpoint(:final clock) => clock,
        WordGameCheckpoint(:final clock) => clock,
        _ => null,
      };
  int get _remaining => ((_clock?.remaining ?? 60) - _elapsed).clamp(0, 60);
  int get _score => _clock?.score ?? 0;
  int get _round => _clock?.round ?? 1;
  bool get _roundOver => _remaining == 0;
  bool get _canMove =>
      _started &&
      !_roundOver &&
      !_busy &&
      !_background &&
      _pendingCommand == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store = ref.read(courseLearningStoreProvider);
    ref.listenManual(courseLearningStoreProvider, _onStoreReplaced);
    unawaited(_load(_store));
  }

  Future<void> _load(CourseLearningStore store, {bool retry = false}) async {
    final op = ++_loadOp;
    final generation = _generation;
    if (mounted) {
      setState(() {
        _loading = true;
        _saveError = null;
      });
    }
    try {
      final state = retry ? await store.retryLoad() : await store.load();
      if (!mounted ||
          generation != _generation ||
          op != _loadOp ||
          !identical(store, _store)) {
        return;
      }
      _state = state;
      _slot = state.activities[_activityId];
      if (_slot?.snapshot case WordGameCheckpoint(:final board)) {
        _word = WordMatchEngine.fromState(board, random: Random());
      }
      if (_slot?.snapshot case SoundGameCheckpoint(:final board)) {
        _sound = SoundMatchEngine.fromState(board, random: Random());
      }
      _elapsed = 0;
      _started = false;
      _showSummary = false;
      _message = '';
      if (_slot != null) _observePreview();
    } catch (_) {
      if (!mounted || generation != _generation || op != _loadOp) return;
      _message =
          'Saved progress is unavailable. Retry loading before continuing.';
    }
    if (mounted && generation == _generation && op == _loadOp) {
      setState(() => _loading = false);
    }
  }

  void _onStoreReplaced(
      CourseLearningStore? previous, CourseLearningStore next) {
    if (identical(previous, next)) return;
    _generation++;
    _loadOp++;
    _timer?.cancel();
    _retireCue();
    _pendingCommand = null;
    _pendingStore = null;
    _pendingSuccess = null;
    _saveBusy = false;
    _elapsed = 0;
    _state = null;
    _slot = null;
    _started = false;
    _store = next;
    if (mounted) unawaited(_load(next));
  }

  Future<bool> _send(LearningAction action, {VoidCallback? onSuccess}) async {
    if (_saveBusy || _pendingCommand != null || _state == null) return false;
    final store = _store;
    final generation = _generation;
    _pendingCommand =
        store.prepare(state: _state!, activityId: _activityId, action: action);
    _pendingStore = store;
    _pendingSuccess = onSuccess;
    return _submitPending(generation);
  }

  Future<bool> _submitPending([int? expectedGeneration]) async {
    final command = _pendingCommand;
    final store = _pendingStore;
    if (command == null || store == null || _saveBusy) return false;
    final generation = expectedGeneration ?? _generation;
    _saveBusy = true;
    if (mounted) {
      setState(() {
        _busy = true;
        _saveError = null;
      });
    }
    try {
      final commit = await store.submit(command);
      if (!mounted || generation != _generation || !identical(store, _store)) {
        return false;
      }
      _state = commit.state;
      _slot = commit.slot;
      _elapsed = 0;
      if (commit.slot.snapshot case WordGameCheckpoint(:final board)) {
        _word = WordMatchEngine.fromState(board, random: Random());
      }
      if (commit.slot.snapshot case SoundGameCheckpoint(:final board)) {
        _sound = SoundMatchEngine.fromState(board, random: Random());
      }
      _pendingCommand = null;
      _pendingStore = null;
      final callback = _pendingSuccess;
      _pendingSuccess = null;
      setState(() {
        _busy = false;
        _saveError = null;
        if (command.feedback.message.isNotEmpty) {
          _message = command.feedback.message;
        }
      });
      callback?.call();
      return true;
    } catch (error) {
      if (mounted && generation == _generation && identical(store, _store)) {
        setState(() {
          _busy = false;
          _saveError = error is LearningOwnerChangedException
              ? 'This round belongs to a different account. Reload to continue.'
              : 'Could not save this round. Retry before leaving.';
        });
      }
      return false;
    } finally {
      if (generation == _generation) _saveBusy = false;
    }
  }

  Future<void> _switchToWordMatch() async {
    if (_saveBusy || _pendingCommand != null) return;
    // Retire any held cue before persisting and navigating away (I3): a
    // stale settlement of the retired cue can then neither arm the bonus,
    // publish failure feedback onto the next surface, nor clear a newer
    // request's busy state.
    _retireCue();
    // Freeze the session while persisting it. If storage fails, keep this
    // screen and its in-memory board so the pause menu can retry the save.
    _timer?.cancel();
    unawaited(_send(CheckpointArcade(elapsedSeconds: _elapsed, paused: true),
        onSuccess: () => context.pushReplacement('/arcade/word')));
  }

  Future<void> _start() async {
    if (_slot != null) {
      final ok = _remaining == 0
          ? await _send(const ContinueArcadeRound())
          : await _send(CheckpointArcade(elapsedSeconds: 0, paused: false));
      if (!ok) return;
      _activate(resetCueAge: true);
      return;
    }
    if (!await _send(StartLearningRun(options: RunOptions()))) return;
    if (!await _send(CheckpointArcade(elapsedSeconds: 0, paused: false))) {
      return;
    }
    _observePreview();
    _activate(resetCueAge: true);
  }

  void _activate({bool resetCueAge = false}) {
    setState(() {
      _started = true;
      _showSummary = false;
      if (resetCueAge) _cueAge = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_started || _busy || _background || _roundOver) return;
      setState(() {
        _elapsed++;
        _cueAge++;
      });
      if (_roundOver) {
        _chain.clear();
        _selected = null;
        _showSummary = true;
        _timer?.cancel();
        unawaited(
            _send(CheckpointArcade(elapsedSeconds: _elapsed, paused: true)));
      } else if (!widget.silent && _cueSound == null && _cueAge >= 12) {
        _newCue();
      }
    });
  }

  Future<void> _checkpoint({
    required bool paused,
    VoidCallback? onSuccess,
  }) async {
    if (_pendingCommand != null) return;
    _timer?.cancel();
    if (paused && !widget.silent) {
      _retireCue();
      _audioReady = false;
      _cueSound = null;
      _cueWord = null;
    }
    await _send(
      CheckpointArcade(elapsedSeconds: _elapsed, paused: paused),
      onSuccess: onSuccess,
    );
  }

  void _observePreview() {
    if (_slot == null) return;
    const preview = {
      'tout': 'u',
      'rouge': 'u',
      'vous': 'u',
      'tu': 'y',
      'rue': 'y',
      'lune': 'y',
      'lit': 'i',
      'beau': 'o',
    };
    final contexts = widget.silent
        ? preview.entries
            .where((entry) => entry.value == 'u' || entry.value == 'y')
        : preview.entries;
    final items = contexts
        .map((entry) =>
            ItemContextKey(itemId: entry.key, targetSound: entry.value))
        .toSet();
    unawaited(_send(ObserveAssistance(
        items: items, flags: {AssistanceFlag.explanationVisible})));
  }

  Future<void> _newCue() async {
    final available = _sound.availableFamilies().toList()..shuffle();
    if (available.isEmpty) return;
    final family = available.first;
    _cueSound = family;
    final words = frenchWords.where((w) => w.contains(family)).toList()
      ..shuffle();
    _cueWord = words.first.text;
    await _playCue();
  }

  Future<void> _playCue() async {
    if (_cueWord == null || _busy || _pendingCommand != null) return;
    final int generation = ++_cueGeneration;
    setState(() {
      _busy = true;
      _audioReady = false;
      _message = 'Listen… then match the vowel family.';
    });
    try {
      _audio = ref.read(courseAudioProvider);
      await _audio!.speak(_cueWord!);
      // Retired (suspension, switch, disposal): this settlement is stale —
      // it must not arm the bonus or touch the screen's current state.
      if (generation != _cueGeneration) return;
      if (!mounted || _background) return;
      setState(() {
        _audioReady = true;
        _message = 'Which vowel did you hear? Your next match can earn +100.';
      });
    } on CourseAudioCancelledException {
      // A user/system stop (backgrounding, switching, disposal) cancelled
      // the cue: it is not an audio failure, and it must never arm the
      // bonus or be displayed as one.
      if (generation != _cueGeneration || !mounted) return;
    } catch (_) {
      if (generation == _cueGeneration && mounted) {
        setState(() => _message =
            'Audio unavailable. Replay to retry, or play Word Match without sound.');
      }
    } finally {
      // A stale settlement must not clear a newer request's busy state.
      if (generation == _cueGeneration && mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Retires the in-flight cue (I3): ownership is invalidated BEFORE the
  /// captured shared playback is stopped, and the cue's audio-owned busy
  /// state is released so the round is usable again after resume/switch.
  void _retireCue() {
    if (widget.silent) return;
    _cueGeneration++;
    final CourseAudio? audio = _audio;
    if (audio != null) {
      unawaited(audio.stop().catchError((Object _) {}));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _tapSound(int index) {
    if (!_canMove) return;
    if (_selected == null || !_sound.adjacent(_selected!, index)) {
      setState(() => _selected = index);
      return;
    }
    final first = _selected!;
    final cue = _cueSound != null && _audioReady && _cueWord != null
        ? HeardSoundCue(
            wordId: _cueWord!,
            targetSound: _cueSound!,
            audioSource: AttemptAudioSource.pendingRecording)
        : null;
    setState(() => _selected = null);
    _timer?.cancel();
    unawaited(_send(
        SwapSoundTiles(
            first: first,
            second: index,
            cue: cue,
            elapsedSeconds: _elapsed), onSuccess: () {
      if (cue != null) {
        _cueSound = null;
        _cueWord = null;
        _audioReady = false;
        _cueAge = 0;
      }
      if (!_roundOver) {
        _activate();
      } else {
        _started = true;
      }
    }));
  }

  void _addWord(int index) {
    if (!_canMove) return;
    if (_chain.length >= 2 && _chain[_chain.length - 2] == index) {
      setState(() => _chain.removeLast());
    } else if (!_chain.contains(index) &&
        (_chain.isEmpty || _word.adjacent(_chain.last, index))) {
      setState(() => _chain.add(index));
    }
  }

  void _drag(Offset global) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(global);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx >= box.size.width ||
        local.dy >= box.size.height) {
      return;
    }
    _addWord((local.dy / (box.size.height / 4)).floor() * 4 +
        (local.dx / (box.size.width / 4)).floor());
  }

  void _submitWord() {
    if (!_canMove || _chain.isEmpty) return;
    final indices = List<int>.of(_chain);
    setState(() => _chain.clear());
    _timer?.cancel();
    unawaited(_send(LinkWordTiles(indices: indices, elapsedSeconds: _elapsed),
        onSuccess: () {
      if (!_roundOver) {
        _activate();
      } else {
        _started = true;
      }
    }));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    if (_background && _started) {
      _started = false;
      _showSummary = true;
      _audioReady = false;
      // Retire the held cue BEFORE stopping the shared playback, and release
      // the cue's busy ownership so the round is usable again after resume.
      _retireCue();
      _timer?.cancel();
      _send(CheckpointArcade(elapsedSeconds: _elapsed, paused: true));
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _generation++;
    // Disposal retires any held cue the same way as an explicit stop:
    // ownership is lost first, then the captured playback is stopped.
    // (No busy/state reset here: the element is already leaving, and a
    // disposal-time setState would be illegal.)
    if (!widget.silent) {
      _cueGeneration++;
      final CourseAudio? audio = _audio;
      if (audio != null) {
        unawaited(audio.stop().catchError((Object _) {}));
      }
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_started,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _timer?.cancel();
          _checkpoint(
              paused: true,
              onSuccess: () => setState(() {
                    _started = false;
                    _showSummary = true;
                  }));
        }
      },
      child: Scaffold(
        appBar: AppBar(
            title: Text(widget.silent ? 'Word Match' : 'Sound Match'),
            actions: [
              if (_started && !_roundOver)
                IconButton(
                    tooltip: 'Pause',
                    onPressed: () => _checkpoint(
                        paused: true,
                        onSuccess: () => setState(() {
                              _started = false;
                              _showSummary = true;
                            })),
                    icon: const Icon(Icons.pause)),
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (!_started && !_showSummary)
                          ..._intro(context)
                        else if (_roundOver || _showSummary)
                          ..._summary(context)
                        else ...[
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Round $_round · ${_remaining}s',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                Text('$_score pts',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                              ]),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: _remaining / 60),
                          const SizedBox(height: 16),
                          Text(
                              widget.silent
                                  ? 'Connect words containing /${_word.target}/'
                                  : 'Swap neighbors. Match three.',
                              style: Theme.of(context).textTheme.titleMedium),
                          if (!widget.silent && _cueSound != null)
                            Row(children: [
                              IconButton(
                                  tooltip: 'Replay sound',
                                  onPressed: _busy ? null : _playCue,
                                  icon: const Icon(Icons.volume_up)),
                              const Expanded(
                                  child: Text('Listen for the bonus sound')),
                            ]),
                          if (!widget.silent)
                            Text(alphaAudioDisclosure,
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 8),
                          if (widget.silent)
                            GestureDetector(
                              onPanDown: (d) => _dragOrigin = d.globalPosition,
                              onPanStart: (d) {
                                _chain.clear();
                                if (_dragOrigin != null) _drag(_dragOrigin!);
                                _drag(d.globalPosition);
                              },
                              onPanUpdate: (d) => _drag(d.globalPosition),
                              onPanEnd: (_) => _submitWord(),
                              child: _wordBoard(context),
                            )
                          else
                            _soundBoard(context),
                          const SizedBox(height: 12),
                          if (widget.silent)
                            Wrap(spacing: 8, children: [
                              FilledButton(
                                  onPressed:
                                      _chain.length >= 3 ? _submitWord : null,
                                  child: Text('Link ${_chain.length} words')),
                              TextButton(
                                  onPressed: () =>
                                      setState(() => _chain.clear()),
                                  child: const Text('Clear selection')),
                            ]),
                          const SizedBox(height: 8),
                          Text(_message,
                              key: const ValueKey('game-feedback'),
                              style: Theme.of(context).textTheme.bodyLarge),
                          if (_saveError != null) ...[
                            Text(_saveError!),
                            TextButton(
                                onPressed: _submitPending,
                                child: const Text('Retry save')),
                          ],
                          if (!widget.silent)
                            TextButton(
                                onPressed: _switchToWordMatch,
                                child: const Text(
                                    'Play without audio: Word Match')),
                        ],
                      ],
                    )),
              ),
      ),
    );
  }

  List<Widget> _intro(BuildContext context) => [
        Icon(widget.silent ? Icons.gesture : Icons.headphones,
            size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 20),
        Text(widget.silent ? 'No audio needed' : 'Headphones on. Gems ready.',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(widget.silent
            ? 'Drag through 3 or more neighboring words containing the target sound. Diagonals count! You can also tap words, then Link. Long chains earn stars; stars clear rows. Crack outlined obstacles for +50.'
            : 'Tap two neighboring gems to swap them. Match 3 or more to clear a line. Four earns a star that clears a row. Cascades multiply points. Every so often, listen to a French word and match its vowel family for a bonus.'),
        const SizedBox(height: 16),
        const Card(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Quick sound preview\n\n/u/ → tout, rouge, vous: “ou”, a steady rounded vowel.\n/y/ → tu, rue, lune: say /i/ with rounded lips.\n/i/ → lit: a steady “ee”.\n/o/ → beau: a steady “oh”, without a glide.'))),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _start,
            child: Text(_slot != null
                ? 'Resume saved board'
                : 'Start 60-second round')),
        const SizedBox(height: 12),
        const Text(
            'Stop after a minute or continue the same board. Puzzle points do not determine lesson completion.'),
        if (_message.isNotEmpty) Text(_message),
      ];

  List<Widget> _summary(BuildContext context) => [
        const Icon(Icons.auto_awesome, size: 64),
        const SizedBox(height: 20),
        Text(_roundOver ? 'Round complete' : 'Paused',
            style: Theme.of(context).textTheme.headlineMedium),
        Text('$_score points · Round $_round',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        FilledButton(
            onPressed: _saveBusy
                ? null
                : () async {
                    if (!await _send(_roundOver
                        ? const ContinueArcadeRound()
                        : CheckpointArcade(elapsedSeconds: 0, paused: false))) {
                      return;
                    }
                    setState(() {
                      _chain.clear();
                      _selected = null;
                      _cueAge = 0;
                      _cueSound = null;
                      _cueWord = null;
                      _audioReady = false;
                      _showSummary = false;
                    });
                    _activate();
                  },
            child: Text(_roundOver ? 'Continue this board' : 'Resume')),
        TextButton(
            onPressed: _saveBusy
                ? null
                : () async {
                    await _checkpoint(
                        paused: true,
                        onSuccess: () {
                          if (!mounted) return;
                          setState(() {
                            _started = false;
                            _showSummary = true;
                          });
                          if (context.mounted) Navigator.of(context).pop();
                        });
                  },
            child: const Text('Finish')),
        if (_saveError != null) ...[
          Text(_saveError!),
          TextButton(
              onPressed: _submitPending, child: const Text('Retry save')),
        ],
      ];

  Widget _wordBoard(BuildContext context) => AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        key: _boardKey,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 16,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, crossAxisSpacing: 4, mainAxisSpacing: 4),
        itemBuilder: (_, i) {
          final word = wordByText(_word.board[i]);
          final selected = _chain.contains(i);
          final hint = _word.moves < 4;
          final offset = word.text.indexOf(word.hint);
          return Tooltip(
              key: ValueKey('word-tile-$i'),
              message: word.meaning,
              child: Material(
                color: selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: _word.obstacles.contains(i)
                            ? Colors.orange
                            : selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                        width: _word.obstacles.contains(i) ? 3 : 2)),
                child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _addWord(i),
                    child: Center(
                        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_word.stars.contains(i))
                          const Icon(Icons.star, size: 18),
                        FittedBox(
                            child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text.rich(
                                    TextSpan(children: [
                                      TextSpan(
                                          text: word.text.substring(0, offset)),
                                      TextSpan(
                                          text: word.hint,
                                          style: hint
                                              ? const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  decoration:
                                                      TextDecoration.underline)
                                              : null),
                                      TextSpan(
                                          text: word.text.substring(
                                              offset + word.hint.length)),
                                    ]),
                                    style: const TextStyle(fontSize: 20)))),
                        if (selected)
                          Text('${_chain.indexOf(i) + 1}',
                              style: const TextStyle(fontSize: 11)),
                      ],
                    ))),
              ));
        },
      ));

  Widget _soundBoard(BuildContext context) {
    const colors = [
      Color(0xff2369a4),
      Color(0xff9450a0),
      Color(0xff287c62),
      Color(0xff9a6010)
    ];
    const icons = [
      Icons.circle_outlined,
      Icons.diamond_outlined,
      Icons.change_history,
      Icons.crop_square
    ];
    return AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 36,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6, crossAxisSpacing: 4, mainAxisSpacing: 4),
            itemBuilder: (_, i) {
              final family = SoundMatchEngine.families.indexOf(_sound.board[i]);
              return Semantics(
                  key: ValueKey('sound-tile-$i'),
                  label: 'Sound /${_sound.board[i]}/ tile ${i + 1}',
                  selected: _selected == i,
                  button: true,
                  child: Material(
                      color: colors[family],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: _selected == i
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3)),
                      child: InkWell(
                          onTap: () => _tapSound(i),
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                              child: FittedBox(
                                  child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  _sound.stars.contains(i)
                                      ? Icons.star
                                      : icons[family],
                                  color: Colors.white,
                                  size: 18),
                              Text('/${_sound.board[i]}/',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ))))));
            }));
  }
}
