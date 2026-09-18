import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/course/course_audio.dart';
import '../../core/course/course_progress.dart';
import '../../core/course/french_course.dart';
import 'arcade_session.dart';
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
  final _session = ArcadeSession();
  final _word = WordMatchEngine();
  final _sound = SoundMatchEngine();
  final _store = CourseProgressStore(frenchCourse.id);
  final _chain = <int>[];
  final _boardKey = GlobalKey();
  Offset? _dragOrigin;
  Timer? _timer;
  bool _loading = true, _started = false, _hasSaved = false, _busy = false;
  bool _audioReady = false, _background = false, _saving = false;
  int? _selected;
  int _cueAge = 0;
  String? _cueSound, _cueWord;
  String _message = '';
  String? _saveError;
  CourseAudio? _audio;
  String get _game => widget.silent ? 'word' : 'sound';
  String get _key => 'arcade.v1.${_store.storageScope}.$_game';
  bool get _canMove =>
      _started && !_session.roundOver && !_session.paused && !_busy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _session.restore(Map<String, dynamic>.from(data['session'] as Map));
        final board = Map<String, dynamic>.from(data['board'] as Map);
        if (widget.silent) {
          _word.restore(board);
        } else {
          _sound.restore(board);
        }
        _hasSaved = true;
      }
    } catch (_) {
      _session.restore({'remaining': 60, 'round': 1, 'score': 0});
      _word.restore(WordMatchEngine().toJson());
      _sound.shuffle();
      _message = 'Your saved board could not be restored. Start a fresh round.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _start() {
    if (_session.roundOver) _session.continueRound();
    setState(() {
      _started = true;
      _session.paused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _session.paused || _session.roundOver || _busy) return;
      setState(() {
        _session.elapse(1);
        _cueAge++;
      });
      if (_session.roundOver) {
        _chain.clear();
        _selected = null;
        _save();
      } else if (!widget.silent && _cueSound == null && _cueAge >= 12) {
        _newCue();
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    _saving = true;
    try {
      final snapshot = jsonEncode({
        'session': _session.toJson(),
        'board': widget.silent ? _word.toJson() : _sound.toJson()
      });
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_key, snapshot)) {
        throw StateError('Storage unavailable');
      }
      await _store.saveScore(_game, _session.score);
      if (mounted) setState(() => _saveError = null);
      if (mounted) ref.invalidate(courseProgressProvider);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _saveError = 'Could not save this round. Retry before leaving.');
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _switchToWordMatch() async {
    if (_saving) return;
    // Freeze the session while persisting it. If storage fails, keep this
    // screen and its in-memory board so the pause menu can retry the save.
    setState(() => _session.paused = true);
    await _save();
    if (!mounted || _saveError != null) return;
    context.pushReplacement('/arcade/word');
  }

  Future<void> _record(List<(String, bool)> answers, String skill) async {
    try {
      for (final answer in answers) {
        await _store.record(answer.$1, skill, answer.$2, activity: _game);
      }
      if (mounted) ref.invalidate(courseProgressProvider);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _message = 'Game continues, but this answer could not be saved.');
      }
    }
  }

  Future<void> _newCue() async {
    final available = _sound.availableFamilies().toList()..shuffle();
    if (available.isEmpty) return;
    _cueSound = available.first;
    final words = frenchWords.where((w) => w.contains(_cueSound!)).toList()
      ..shuffle();
    _cueWord = words.first.text;
    await _playCue();
  }

  Future<void> _playCue() async {
    if (_cueWord == null || _busy) return;
    setState(() {
      _busy = true;
      _audioReady = false;
      _message = 'Listen… then match the vowel family.';
    });
    try {
      _audio = ref.read(courseAudioProvider);
      await _audio!.speak(_cueWord!);
      if (!mounted || _background) return;
      setState(() {
        _audioReady = true;
        _message = 'Which vowel did you hear? Your next match can earn +100.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Audio unavailable. Replay to retry, or play Word Match without sound.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _tapSound(int index) {
    if (!_canMove) return;
    if (_selected == null || !_sound.adjacent(_selected!, index)) {
      setState(() => _selected = index);
      return;
    }
    final result = _sound.swap(_selected!, index);
    setState(() {
      _selected = null;
      if (!result.accepted) {
        _message = 'Swap neighbors to make a line of three.';
        return;
      }
      _session.score += result.points;
      _message =
          '${result.cascades > 1 ? '${result.cascades} cascades! ' : ''}+${result.points}';
      // Ambiguous double-family matches and failed playback are not evidence.
      if (_cueSound != null && _audioReady && result.families.length == 1) {
        final correct = result.families.single == _cueSound;
        if (correct) _session.score += 100;
        _message += correct
            ? ' · Sound bonus +100!'
            : ' · $_cueWord contains /$_cueSound/.';
        _record([(_cueSound!, correct)], 'listening');
        _cueSound = null;
        _cueWord = null;
        _audioReady = false;
        _cueAge = 0;
      } else if (_cueSound != null &&
          !_sound.availableFamilies().contains(_cueSound)) {
        // Board changes may remove the correct move. Retire the cue unscored.
        _cueSound = null;
        _cueWord = null;
        _audioReady = false;
        _cueAge = 0;
      }
    });
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
    final result = _word.submit(List.of(_chain));
    setState(() {
      _chain.clear();
      _message = result.message;
      _session.score += result.points;
    });
    if (result.evidence.isNotEmpty) _record(result.evidence, 'spelling');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    if (_background && _started) {
      _session.paused = true;
      _audioReady = false;
      if (!widget.silent) {
        ref.read(courseAudioProvider).stop().catchError((Object _) {});
      }
      _save();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audio?.stop().catchError((Object _) {});
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_started,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _session.paused = true);
      },
      child: Scaffold(
        appBar: AppBar(
            title: Text(widget.silent ? 'Word Match' : 'Sound Match'),
            actions: [
              if (_started && !_session.roundOver)
                IconButton(
                    tooltip: 'Pause',
                    onPressed: () => setState(() => _session.paused = true),
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
                        if (!_started)
                          ..._intro(context)
                        else if (_session.roundOver || _session.paused)
                          ..._summary(context)
                        else ...[
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    'Round ${_session.round} · ${_session.remaining}s',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                Text('${_session.score} pts',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                              ]),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                              value: _session.remaining / 60),
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
            child: Text(
                _hasSaved ? 'Resume saved board' : 'Start 60-second round')),
        const SizedBox(height: 12),
        const Text(
            'Stop after a minute or continue the same board. Puzzle points do not determine lesson completion.'),
        if (_message.isNotEmpty) Text(_message),
      ];

  List<Widget> _summary(BuildContext context) => [
        const Icon(Icons.auto_awesome, size: 64),
        const SizedBox(height: 20),
        Text(_session.roundOver ? 'Round complete' : 'Paused',
            style: Theme.of(context).textTheme.headlineMedium),
        Text('${_session.score} points · Round ${_session.round}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        FilledButton(
            onPressed: _saving
                ? null
                : () => setState(() {
                      _session.continueRound();
                      _session.paused = false;
                      _chain.clear();
                      _selected = null;
                      _cueAge = 0;
                      _cueSound = null;
                      _cueWord = null;
                      _audioReady = false;
                    }),
            child: Text(_session.roundOver ? 'Continue this board' : 'Resume')),
        TextButton(
            onPressed: _saving
                ? null
                : () async {
                    await _save();
                    if (!mounted || _saveError != null) return;
                    setState(() => _started = false);
                    if (context.mounted) Navigator.of(context).pop();
                  },
            child: const Text('Finish')),
        if (_saveError != null) ...[
          Text(_saveError!),
          TextButton(onPressed: _save, child: const Text('Retry save')),
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
