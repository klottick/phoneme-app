import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/course/course_audio.dart';
import '../../core/course/course_progress.dart';
import '../../core/course/lesson_policy.dart';
import '../../core/course/lesson_section.dart';
import '../../core/course/lesson_section_session.dart';
import '../../core/course/lesson_section_store.dart';
import 'discovery_section_view.dart';

/// Lifecycle-aware screen that owns a discovery listening section session:
/// loading (with corrupt-snapshot and load-failure recovery), playback with
/// a fresh-hearing requirement, per-action saves with retry, and owner-aware
/// state.
///
/// Each screen generation is bound to the [LessonSectionStore] captured when
/// it loaded. When the store provider is replaced (for example, the signed-in
/// account changes), the in-flight operations of the departed generation are
/// invalidated and the replacement owner's state is loaded; a pending save
/// can never transfer a checkpoint between owners. Backgrounding invalidates
/// the current hearing and stops audio; a fresh completed playback is
/// required before answering again. Disposal stops audio and invalidates any
/// delayed callback.
///
/// `view.error` is for persistence failures only: a failed save exposes
/// `Retry saving` (same session, same attempt, never recorded twice). Audio
/// failures are reported separately, keep `heard=false`, and allow a new
/// Listen attempt. Raw exceptions and snapshot details are never surfaced
/// because they may contain the hidden answer.
///
/// A successful write invalidates [courseProgressProvider] so the
/// home/dashboard refresh on return. Only a successful Finish exits the
/// screen; with no previous route it falls back to `/home`.
class DiscoveryLessonScreen extends ConsumerStatefulWidget {
  const DiscoveryLessonScreen({
    super.key,
    required this.lessonId,
    this.review = false,
    this.policy,
  });

  /// Lesson the section is bound to (the pilot is `en-fr-u-y`).
  final String lessonId;

  /// Review-mode sessions save on Finish but never add a completion.
  final bool review;

  /// Policy used for fresh sessions; the saved policy is authoritative on
  /// resume.
  final LessonPolicy? policy;

  @override
  ConsumerState<DiscoveryLessonScreen> createState() =>
      _DiscoveryLessonScreenState();
}

class _DiscoveryLessonScreenState extends ConsumerState<DiscoveryLessonScreen>
    with WidgetsBindingObserver {
  static const String _saveErrorText =
      'This change could not be saved. Tap "Retry saving" to try again.';
  static const String _loadErrorText = 'Your saved progress could not be '
      'loaded. Tap "Retry loading" to try again.';
  static const String _corruptText =
      'Your saved progress for this section could not be restored, so this '
      'attempt starts fresh. It will not overwrite the saved progress until '
      'you save a new step.';
  static const String _audioErrorText =
      'The French audio could not be played. Tap "Listen to the word" to try '
      'again.';

  LessonSection? _section;
  LessonSectionStore? _store;
  LessonSectionSession? _session;
  String? _loadError;
  String? _corruptNotice;
  String? _saveError;
  bool _heard = false;
  bool _busy = false;

  /// Bumped on owner replacement, backgrounding, and disposal so that stale
  /// async callbacks can no longer publish state, enable choices, or exit.
  int _generation = 0;

  /// Identity counter for fresh session IDs kept within this generation.
  int _sessionCounter = 0;

  CourseAudio? _activeAudio;

  /// The pending save (answer/advance/review/finish), kept verbatim so that
  /// `Retry saving` re-sends the very same checkpoint: same session, same
  /// attempt, recorded at most once.
  Future<void> Function(LessonSectionStore store)? _pendingAction;
  FutureOr<void> Function()? _pendingOnSaved;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(lessonSectionStoreProvider, _onStoreReplaced);
    _section = sectionForLesson(widget.lessonId);
    final LessonSectionStore store = ref.read(lessonSectionStoreProvider);
    _store = store;
    unawaited(_load(store));
  }

  @override
  void dispose() {
    _generation += 1;
    _stopAudio();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.detached) {
      return;
    }
    // Backgrounding invalidates the hearing: a fresh completed playback is
    // required before answering again. In-flight saves belong to the departed
    // generation and are dropped from the UI; the store keeps its own
    // idempotency rules for whatever lands.
    _generation += 1;
    _pendingAction = null;
    _pendingOnSaved = null;
    _stopAudio();
    if (mounted) {
      setState(() {
        _heard = false;
        _busy = false;
        _saveError = null;
      });
    }
  }

  void _onStoreReplaced(LessonSectionStore? previous, LessonSectionStore next) {
    if (identical(previous, next)) return;
    // The owner changed: invalidate this generation (its pending saves and
    // playback must not land) and load the replacement owner's state.
    _generation += 1;
    _pendingAction = null;
    _pendingOnSaved = null;
    _store = next;
    if (!mounted) return;
    final int expectedGeneration = _generation;
    Future.microtask(() {
      if (expectedGeneration != _generation || !mounted) return;
      unawaited(_load(next));
    });
  }

  List<String> get _itemIds => _section!.items.map((item) => item.id).toList();

  String _freshSessionId() {
    _sessionCounter += 1;
    return 'dss-$_sessionCounter-${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _load(LessonSectionStore store) async {
    final section = _section;
    if (section == null) return;
    final int generation = _generation;
    if (mounted) {
      setState(() {
        _session = null;
        _loadError = null;
        _corruptNotice = null;
        _saveError = null;
        _heard = false;
        _busy = true;
      });
    }
    Map<String, dynamic>? json;
    Object? failure;
    try {
      json = await store.loadLessonSection(widget.lessonId);
    } catch (error) {
      failure = error;
    }
    if (generation != _generation || !mounted) return;
    if (failure != null) {
      setState(() {
        _busy = false;
        _loadError = _loadErrorText;
      });
      return;
    }
    if (json == null) {
      _publishFresh(section, null);
      return;
    }
    try {
      final LessonSectionSession session = LessonSectionSession.fromJson(
        json,
        itemIds: _itemIds,
        contentRevision: section.contentRevision,
      );
      _publish(session, section, null);
    } on FormatException {
      // A corrupt snapshot is never partially restored: start fresh, with a
      // notice, and write nothing until the learner saves a new step.
      _publishFresh(section, _corruptText);
    }
  }

  void _publishFresh(LessonSection section, String? corruptNotice) {
    final LessonSectionSession session = LessonSectionSession(
      itemIds: _itemIds,
      sessionId: _freshSessionId(),
      contentRevision: section.contentRevision,
      policy: widget.policy,
    );
    _publish(session, section, corruptNotice);
  }

  void _publish(
      LessonSectionSession session, LessonSection section, String? notice) {
    if (!mounted) return;
    setState(() {
      _session = session;
      _corruptNotice = notice;
      _busy = false;
      _heard = false;
    });
  }

  LessonSectionSession _cloneSession(LessonSectionSession session) =>
      LessonSectionSession.fromJson(
        session.toJson(),
        itemIds: _itemIds,
        contentRevision: session.contentRevision,
      );

  LessonSectionItem _currentItem(LessonSectionSession session) {
    final section = _section!;
    final String? id = session.currentItemId;
    return section.items.firstWhere(
      (LessonSectionItem item) => item.id == id,
      orElse: () => throw StateError('The session points outside its section.'),
    );
  }

  // ---------------------------------------------------------------- playback

  Future<void> _onListen() async {
    final session = _session;
    if (session == null || session.answered) return;
    if (_busy || _loadError != null || _saveError != null) return;
    final int generation = _generation;
    final String word = _currentItem(session).word;
    CourseAudio audio;
    try {
      audio = ref.read(courseAudioProvider);
    } catch (error) {
      if (generation == _generation && mounted) {
        _showSnackBar(_audioErrorText);
        setState(() => _busy = false);
      }
      return;
    }
    _activeAudio = audio;
    if (mounted) {
      setState(() {
        _busy = true;
        _heard = false;
      });
    }
    Object? failure;
    try {
      await audio.speak(word);
    } catch (error) {
      failure = error;
    }
    // Delayed playback (or a completion after background/dispose/owner
    // replacement) must not unlock the choices.
    if (generation != _generation || !mounted) return;
    if (failure != null) {
      // Audio failure is separate from persistence: generic feedback, no
      // answer, still retryable.
      _showSnackBar(_audioErrorText);
      setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = false;
      _heard = true;
    });
  }

  void _stopAudio() {
    final CourseAudio? audio = _activeAudio;
    if (audio == null) return;
    unawaited(audio.stop().catchError((Object _) {}));
    _activeAudio = null;
  }

  // ------------------------------------------------------------------- saves

  void _runSave(
    Future<void> Function(LessonSectionStore store) action,
    FutureOr<void> Function()? onSaved,
  ) {
    _pendingAction = action;
    _pendingOnSaved = onSaved;
    unawaited(_executeSave());
  }

  Future<void> _executeSave() async {
    final action = _pendingAction;
    final onSaved = _pendingOnSaved;
    final LessonSectionStore? owner = _store;
    if (action == null || owner == null || _session == null) return;
    final int generation = _generation;
    if (mounted) {
      setState(() {
        _busy = true;
        _saveError = null;
      });
    }
    Object? failure;
    try {
      await action(owner);
    } catch (error) {
      failure = error;
    }
    // Stale after owner replacement/background/dispose: publish nothing,
    // clear nothing, navigate nowhere.
    if (generation != _generation || !mounted) return;
    if (failure != null) {
      // Persistence only: the view's error/Retry path. The pending action is
      // retained so Retry saving re-sends the same checkpoint.
      setState(() {
        _busy = false;
        _saveError = _saveErrorText;
      });
      return;
    }
    setState(() => _busy = false);
    if (onSaved != null) {
      await onSaved();
      if (generation != _generation || !mounted) return;
    }
    ref.invalidate(courseProgressProvider);
  }

  Future<void> _onAnswer(String sound) async {
    final session = _session;
    if (session == null || session.answered) return;
    if (!_heard || _busy || _saveError != null || _loadError != null) return;
    final LessonSectionItem item = _currentItem(session);
    final bool correct = item.expectedSound == sound;
    // Publish the outcome immediately; persistence follows and can be
    // retried with this exact checkpoint.
    final LessonSectionSession draft = _cloneSession(session);
    draft.submit(correct);
    final Map<String, dynamic> checkpoint = draft.toJson();
    final String expectedSound = item.expectedSound;
    if (mounted) setState(() => _session = draft);
    _runSave(
        (LessonSectionStore store) => store.recordLessonSectionAnswer(
              widget.lessonId,
              checkpoint,
              sound: expectedSound,
              correct: correct,
            ),
        null);
  }

  void _onNext() {
    final session = _session;
    if (session == null || !session.answered) return;
    final LessonSectionSession draft = _cloneSession(session);
    draft.advance();
    final Map<String, dynamic> checkpoint = draft.toJson();
    _runSave(
        (LessonSectionStore store) =>
            store.saveLessonSection(widget.lessonId, checkpoint), () {
      if (mounted) {
        setState(() {
          _session = draft;
          // `heard` refers to the current item; a new item requires a fresh
          // completed playback before it can be answered.
          _heard = false;
        });
      }
    });
  }

  void _onReview() {
    final session = _session;
    if (session == null || session.unresolvedItemIds.isEmpty) return;
    final LessonSectionSession draft = _cloneSession(session);
    draft.reviewMistakes();
    final Map<String, dynamic> checkpoint = draft.toJson();
    _runSave(
        (LessonSectionStore store) =>
            store.saveLessonSection(widget.lessonId, checkpoint), () {
      if (mounted) {
        setState(() {
          _session = draft;
          _heard = false;
        });
      }
    });
  }

  void _onFinish() {
    final session = _session;
    if (session == null || !session.canComplete) return;
    final Map<String, dynamic> checkpoint = session.toJson();
    // review=true saves the section state but leaves completions unchanged.
    final Future<void> Function(LessonSectionStore) action = widget.review
        ? (LessonSectionStore store) =>
            store.saveLessonSection(widget.lessonId, checkpoint)
        : (LessonSectionStore store) =>
            store.completeLessonSection(widget.lessonId, checkpoint);
    _runSave(action, _exit);
  }

  void _onRetrySave() {
    if (_pendingAction == null) {
      // Nothing pending: reload through the captured owner.
      final LessonSectionStore? store = _store;
      if (store != null) unawaited(_load(store));
      return;
    }
    unawaited(_executeSave());
  }

  void _onRetryLoad() {
    final LessonSectionStore? store = _store;
    if (store == null) return;
    unawaited(_load(store));
  }

  // -------------------------------------------------------------------- exit

  Future<void> _exit() async {
    final BuildContext context = this.context;
    if (!context.mounted) return;
    try {
      final GoRouter router = GoRouter.of(context);
      if (router.canPop()) {
        if (context.mounted) context.pop();
      } else {
        // Entered this route directly with no previous route: safe fallback.
        if (context.mounted) context.go('/home');
      }
    } catch (error) {
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showSnackBar(String message) {
    final ScaffoldMessengerState? messenger =
        ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  // -------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    final section = _section;
    final String title = section?.title ?? 'Discovery lesson';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _body(),
    );
  }

  Widget _body() {
    final section = _section;
    if (section == null) {
      return const Center(
        child: Text('This lesson is not part of the discovery section yet.'),
      );
    }
    if (_loadError != null) {
      final String loadError = _loadError!;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loadError, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _store == null ? null : _onRetryLoad,
                child: const Text('Retry loading'),
              ),
            ],
          ),
        ),
      );
    }
    final session = _session;
    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final String? corruptNotice = _corruptNotice;
    return Column(
      children: [
        if (corruptNotice != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.orange.shade100,
            child: Text(
              corruptNotice,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        Expanded(
          child: DiscoverySectionView(
            section: section,
            session: session,
            heard: _heard,
            busy: _busy,
            error: _saveError,
            onListen: _onListen,
            onAnswer: _onAnswer,
            onNext: _onNext,
            onReview: _onReview,
            onFinish: _onFinish,
            onRetrySave: _onRetrySave,
          ),
        ),
      ],
    );
  }
}
