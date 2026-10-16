import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/course/course_audio.dart';
import '../../core/course/course_attempt.dart';
import '../../core/course/course_learning_checkpoint.dart';
import '../../core/course/course_learning_command.dart';
import '../../core/course/course_learning_error.dart';
import '../../core/course/course_learning_providers.dart';
import '../../core/course/course_learning_registry.dart';
import '../../core/course/course_learning_state.dart';
import '../../core/course/course_learning_store.dart';
import '../../core/course/lesson_policy.dart';
import '../../core/course/lesson_section.dart';
import '../../core/course/lesson_section_session.dart';
import '../../core/course/lesson_debrief_content.dart';
import '../../core/course/french_lesson_teaching.dart';
import 'discovery_section_view.dart';

/// Lifecycle-aware screen that owns a discovery listening section session:
/// loading (with corrupt-snapshot and load-failure recovery), playback with
/// a fresh-hearing requirement, per-action saves with retry, and owner-aware
/// state.
///
/// Each screen generation is bound to the [CourseLearningStore] captured when
/// it loaded. When the store provider is replaced (for example, the signed-in
/// account changes), the old owner's audio stops immediately, the departing
/// generation's in-flight operations are invalidated, and the replacement
/// owner's state is loaded; a pending save can never transfer a checkpoint
/// between owners.
///
/// Suspension (backgrounding) is only a playback invalidation: the current
/// hearing is lost (a fresh completed playback is required) and in-flight
/// completions that land while suspended are discarded, but the same-owner
/// learnable save intent — the pending action/checkpoint and any save error —
/// is preserved and the controls stay disabled until it settles. Explicit
/// suspension tracking drives recovery: only a `resumed` event reopens
/// foreground recovery (re-drives an interrupted load, or re-runs the pending
/// save idempotently, coalesced so one action publishes/exits exactly once);
/// `inactive` focus changes neither replay pending work nor settle suspended
/// navigation, and a `resumed` without a prior suspension does nothing.
/// Save runs are single-shot per identity: handlers ignore double taps before
/// a redraw, an orphaned run's late completion cannot settle the UI, clear a
/// newer pending action, or run a second exit. Disposal invalidates every
/// delayed callback.
///
/// `view.error` is for persistence failures only: a failed save exposes
/// `Retry saving` (same session, same attempt, never recorded twice). Audio
/// failures are reported separately, keep `heard=false`, and allow a new
/// Listen attempt. Raw exceptions and snapshot details are never surfaced
/// because they may contain the hidden answer.
///
/// A save rejected with the store's typed [LearningConflictException]
/// is different from a transient failure: the store's stored state has moved
/// ahead of this screen's session, so resending the checkpoint can never
/// succeed. The screen then exposes an explicit `Reload saved progress`
/// action (and drops the stale pending save intent). Tapping it — the only
/// path — abandons the stale in-memory draft, stops any pending hearing or
/// playback, and reconciles the stored checkpoint through the same
/// single-shot load guards as `Retry loading`.
///
/// A debrief (normal or review route, with or without unresolved words)
/// exposes `Practise again`: an explicit restart, never an automatic reset.
/// It creates a fresh zero-attempt session identity and persists it through
/// the captured owner before the exercise is exposed, so a failed restart
/// keeps the historical debrief, stays retryable, and never leaks the new
/// exercise or double-records. Completion history and evidence are retained
/// by the store; review-mode Finish never emits a completion.
///
/// The app bar and exercise heading use the neutral 'Listening practice'
/// title; the word-bearing authored title is revealed only at the debrief,
/// keeping the hidden item out of the UI and semantics during the active
/// listening puzzle, including loading and load-error states.
///
/// A successful write invalidates [courseLearningStateProvider] so the
/// home/dashboard refresh on return. Only a successful Finish exits the
/// screen; with no previous route it falls back to `/home`.
class DiscoveryLessonScreen extends ConsumerStatefulWidget {
  const DiscoveryLessonScreen({
    super.key,
    required this.lessonId,
    this.review = false,
    this.policy,
    this.debriefContentLoader,
  });

  /// Lesson the section is bound to (the pilot is `en-fr-u-y`).
  final String lessonId;

  /// Review-mode sessions save on Finish but never add a completion.
  final bool review;

  /// Policy used for fresh sessions; the saved policy is authoritative on
  /// resume.
  final LessonPolicy? policy;

  final LessonDebriefContent Function()? debriefContentLoader;

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
  static const String _conflictText =
      'This copy no longer matches the saved progress for this section. Tap '
      '"Reload saved progress" to load the saved state.';
  static const String _invalidCommandText =
      'This learning action is no longer valid. Tap "Reload saved progress" '
      'to load the saved state.';
  // Pure Retry/unavailable guidance (I1): the exact shared alpha disclosure
  // is pinned persistently on the exercise surface itself
  // (DiscoverySectionView), so the transient failure wording stays focused
  // on retry — mirroring the published lesson surface.
  static const String _audioErrorText =
      'The French audio could not be played. Tap "Listen to the word" to try '
      'again.';

  LessonSection? _section;
  CourseLearningStore? _store;
  CourseLearningState? _learningState;
  LessonSectionSession? _session;
  String? _loadError;
  String? _corruptNotice;
  String? _saveError;
  String? _conflictError;
  bool _heard = false;
  bool _busy = false;
  bool _playing = false;
  String? _selectedSound;

  /// Bumped when the screen's identity changes (owner replacement,
  /// disposal) and when the app suspends: in-flight save/playback
  /// completions that land in those windows are stale and must not publish
  /// or exit. For a same-owner suspension the retained pending action is
  /// re-run idempotently when `resumed` reopens recovery; for an owner
  /// replacement it is dropped (it stays reconciled in the old owner's
  /// storage).
  int _generation = 0;

  /// Bumped whenever an in-flight playback must stop counting: suspension,
  /// owner replacement, disposal. A late completion then never unlocks the
  /// choices on a screen that no longer owns that playback.
  int _playbackGeneration = 0;

  /// True while paused/hidden/detached; cleared only by a `resumed` event.
  /// Controls stay disabled while set (pending persistence must not
  /// masquerade as committed), nothing may settle or navigate while set, and
  /// neither `inactive` focus changes nor repeated `resumed` events without
  /// a prior suspension replay work.
  bool _suspended = false;

  /// A save run is awaiting its store call. A new invocation (double tap
  /// before the widget tree redraws) must not start a second run.
  bool _saveInFlight = false;

  /// Identity of the save run currently in flight (bumped when a run is
  /// orphaned, e.g. by a resumed-window re-drive or owner replacement). An
  /// orphaned run's late completion cannot settle the UI, clear a newer
  /// pending action, or run a second exit.
  int _saveOp = 0;

  /// A load call is awaiting its store read. A new retry (double tap before
  /// the widget tree redraws) must not start a competing load whose late
  /// result could publish over newer UI state.
  bool _loadInFlight = false;
  bool _contentChanged = false;
  LessonDebriefContent? _debriefContent;
  bool _teachingUnavailable = false;

  /// Identity of the load currently in flight (bumped when a load is
  /// orphaned, e.g. by a resumed-window re-drive or owner replacement). An
  /// orphaned load's late result cannot publish into newer UI state.
  int _loadOp = 0;

  CourseAudio? _activeAudio;

  /// The pending save (answer/advance/review/finish), kept verbatim so that
  /// `Retry saving` re-sends the very same checkpoint: same session, same
  /// attempt, recorded at most once.
  LearningCommand? _pendingCommand;
  CourseLearningStore? _pendingStore;
  FutureOr<void> Function()? _pendingOnSaved;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(courseLearningStoreProvider, _onStoreReplaced);
    _section = sectionForLesson(widget.lessonId);
    final section = _section;
    if (section != null) {
      try {
        final content =
            (widget.debriefContentLoader ?? loadFrenchPilotDebriefContent)();
        if (content.lessonId != section.lessonId ||
            content.contentRevision != section.contentRevision ||
            content.entries.length != section.items.length ||
            !List.generate(content.entries.length,
                    (i) => content.entries[i].itemId == section.items[i].id)
                .every((v) => v)) {
          throw const FormatException('Mismatched lesson teaching content.');
        }
        _debriefContent = content;
      } on LessonTeachingValidationException {
        _teachingUnavailable = true;
      } on FormatException {
        _teachingUnavailable = true;
      }
    }
    final CourseLearningStore store = ref.read(courseLearningStoreProvider);
    _store = store;
    if (!_teachingUnavailable) unawaited(_load(store));
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
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _onSuspend();
      case AppLifecycleState.inactive:
        // A focus/transition change is neither suspension nor recovery: it
        // must not replay pending work, settle a save, or navigate.
        break;
      case AppLifecycleState.resumed:
        _onForeground();
    }
  }

  /// Suspension invalidates playback and freezes the screen, but not the
  /// learner's recoverable save intent: the pending action/checkpoint and
  /// any save error stay in place and are reconciled only when `resumed`
  /// reopens foreground recovery. In-flight completions that land while
  /// suspended are stale (generation guard) — they must not publish, unlock
  /// controls, or exit.
  void _onSuspend() {
    _generation += 1;
    _playbackGeneration += 1;
    _suspended = true;
    _stopAudio();
    if (mounted) {
      setState(() {
        _heard = false;
        _busy = false;
        _playing = false;
      });
    }
  }

  /// Only a `resumed` event after a suspension reopens recovery. Re-drive a
  /// load that suspension invalidated (no permanent spinner), or settle the
  /// pending same-owner save idempotently — coalesced with the run the
  /// suspended window left behind so one action publishes/exits exactly
  /// once. A `resumed` without a prior suspension does nothing.
  void _onForeground() {
    if (_teachingUnavailable) return;
    if (!_suspended) return;
    final CourseLearningStore? store = _store;
    if (store == null || !mounted) return;
    _suspended = false;
    // The suspended flag was gating (disabling) the controls; clearing it
    // must schedule a rebuild of its own or the view stays frozen after
    // resume even when there is no pending work to re-drive.
    setState(() {});
    final int expectedGeneration = _generation;
    Future.microtask(() {
      if (expectedGeneration != _generation || !mounted) return;
      if (_session == null && _loadError == null) {
        // Orphan whatever load the suspended window left (even if still
        // hung) and re-drive: a load must never serialize the recovery
        // behind an orphaned call forever.
        if (_loadInFlight) _loadOp += 1;
        unawaited(_load(store));
      } else if (_pendingCommand != null) {
        // Orphan whatever run the suspended window left in flight; its late
        // completion must not settle the UI or run an exit alongside this one.
        if (_saveInFlight) _saveOp += 1;
        unawaited(_startSave());
      }
    });
  }

  void _onStoreReplaced(
      CourseLearningStore? previous, CourseLearningStore next) {
    if (identical(previous, next)) return;
    if (_teachingUnavailable) return;
    // The owner changed: stop the old owner's audio immediately, invalidate
    // the departed generation's playback and publications, orphan its
    // in-flight save run, and drop its pending save intent — it stays
    // reconciled in the old owner's storage and must never be re-sent by the
    // replacement screen. Then load the replacement owner's state.
    _generation += 1;
    _playbackGeneration += 1;
    _saveOp += 1; // orphan the old owner's in-flight run
    _saveInFlight = false;
    _loadOp += 1; // orphan the old owner's in-flight load
    _loadInFlight = false;
    _pendingCommand = null;
    _pendingStore = null;
    _pendingOnSaved = null;
    _stopAudio();
    _playing = false;
    _selectedSound = null;
    _store = next;
    if (!mounted) return;
    final int expectedGeneration = _generation;
    Future.microtask(() {
      if (expectedGeneration != _generation || !mounted) return;
      unawaited(_load(next));
    });
  }

  static String get _activityId => 'lesson:${frenchUySection.lessonId}';

  Future<void> _load(CourseLearningStore store, {bool retry = false}) async {
    if (_teachingUnavailable) return;
    final section = _section;
    if (section == null) return;
    _loadInFlight = true;
    final int op = _loadOp;
    final int generation = _generation;
    if (mounted) {
      setState(() {
        _session = null;
        _loadError = null;
        _contentChanged = false;
        _corruptNotice = null;
        _saveError = null;
        _conflictError = null;
        _heard = false;
        _busy = true;
        _playing = false;
        _selectedSound = null;
      });
    }
    CourseLearningState? loaded;
    Object? failure;
    try {
      loaded = retry ? await store.retryLoad() : await store.load();
    } catch (error) {
      failure = error;
    }
    // Orphaned (a resumed re-drive or owner replacement superseded this
    // load): its late result must not publish into newer UI state, and it
    // must not clear the flag a newer load now owns.
    if (op != _loadOp) return;
    _loadInFlight = false;
    // Stale after suspension/owner replacement/disposal: a completed load
    // must not publish either; resumed recovery re-drives it if needed.
    if (generation != _generation || _suspended || !mounted) return;
    if (failure != null) {
      setState(() {
        _busy = false;
        _loadError = _loadErrorText;
      });
      return;
    }
    _learningState = loaded!;
    final ActivitySlot? slot = loaded.activities[_activityId];
    if (slot == null) {
      final command = store.prepare(
        state: loaded,
        activityId: _activityId,
        action: StartLearningRun(options: RunOptions(policy: widget.policy)),
      );
      _session = (command.candidate as DiscoveryCheckpoint).session;
      _pendingCommand = command;
      _pendingStore = store;
      await _startSave();
      return;
    }
    if (slot.contentRevision != section.contentRevision ||
        slot.snapshot is! DiscoveryCheckpoint) {
      setState(() {
        _busy = false;
        _contentChanged = true;
        _loadError = 'This lesson has changed. Start a new run to continue.';
      });
      return;
    }
    _publish((slot.snapshot as DiscoveryCheckpoint).session, section, null);
  }

  void _publish(
      LessonSectionSession session, LessonSection section, String? notice) {
    if (!mounted) return;
    setState(() {
      _session = session;
      _corruptNotice = notice;
      _busy = false;
      _heard = false;
      _playing = false;
      _selectedSound = null;
    });
  }

  LessonSectionItem _currentItem(LessonSectionSession session) {
    final section = _section!;
    final String? id = session.currentItemId;
    return section.items.firstWhere(
      (LessonSectionItem item) => item.id == id,
      orElse: () => throw StateError('The session points outside its section.'),
    );
  }

  AttemptAudioSource _audioSourceForCurrentItem(LessonSectionSession session) {
    final String alias = _currentItem(session).id;
    final definition = LearningRegistry.french().require(_activityId);
    final source =
        definition.items.firstWhere((item) => item.sessionAlias == alias);
    return authoredAudioSource(source) ?? AttemptAudioSource.notApplicable;
  }

  // ---------------------------------------------------------------- playback

  Future<void> _onListen() async {
    if (_suspended) return;
    final session = _session;
    if (session == null ||
        session.phase != LessonSectionPhase.exercise ||
        session.answered) {
      return;
    }
    if (_busy ||
        _loadError != null ||
        _saveError != null ||
        _conflictError != null) {
      return;
    }
    final int generation = _generation;
    final int playback = _playbackGeneration;
    final String word = _currentItem(session).word;
    // Claim playback synchronously, before provider acquisition can throw or
    // a second callback can arrive before the next frame.
    setState(() {
      _busy = true;
      _playing = true;
      _heard = false;
    });
    CourseAudio audio;
    try {
      audio = ref.read(courseAudioProvider);
    } catch (error) {
      if (generation == _generation &&
          playback == _playbackGeneration &&
          mounted) {
        _showSnackBar(_audioErrorText);
        setState(() {
          _busy = false;
          _playing = false;
        });
      }
      return;
    }
    _activeAudio = audio;
    Object? failure;
    try {
      await audio.speak(word);
    } on CourseAudioCancelledException {
      // A user/system stop invalidates playback: quiet, retryable — it is
      // neither a success (no fresh-hearing) nor an audio failure.
      if (generation == _generation &&
          playback == _playbackGeneration &&
          mounted) {
        setState(() {
          _busy = false;
          _playing = false;
        });
      }
      return;
    } catch (error) {
      failure = error;
    }
    // A late completion (suspension, owner replacement, disposal) must not
    // unlock the choices or clear busy on a screen that no longer owns it.
    if (generation != _generation ||
        playback != _playbackGeneration ||
        !mounted) {
      return;
    }
    if (failure != null) {
      // Audio failure is separate from persistence: generic feedback, no
      // answer, still retryable.
      _showSnackBar(_audioErrorText);
      setState(() {
        _busy = false;
        _playing = false;
      });
      return;
    }
    setState(() {
      _busy = false;
      _playing = false;
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

  LearningCommand? _prepare(LearningAction action) {
    final CourseLearningStore? store = _store;
    final CourseLearningState? state = _learningState;
    if (store == null || state == null) return null;
    return store.prepare(state: state, activityId: _activityId, action: action);
  }

  void _runSave(LearningCommand command, {FutureOr<void> Function()? onSaved}) {
    // Single-shot: nothing while suspended, and no second run for the same
    // identity — a double tap before the widget tree redraws must not start
    // a duplicate save (duplicate completion, duplicate exit, ...).
    if (_suspended || _saveInFlight) return;
    _pendingCommand = command;
    _pendingStore = _store;
    _pendingOnSaved = onSaved;
    unawaited(_startSave());
  }

  Future<void> _startSave() async {
    final command = _pendingCommand;
    final onSaved = _pendingOnSaved;
    final CourseLearningStore? owner = _pendingStore;
    if (command == null || owner == null) return;
    _saveInFlight = true;
    final int op = _saveOp;
    final int generation = _generation;
    if (mounted) {
      setState(() {
        _busy = true;
        _saveError = null;
        _conflictError = null;
      });
    }
    Object? failure;
    LearningCommit? committed;
    try {
      committed = await owner.submit(command);
    } catch (error) {
      failure = error;
    }
    // Orphaned (a resumed re-drive or owner replacement superseded this run):
    // it must not settle the UI, clear a newer pending action, or exit.
    if (op != _saveOp) return;
    _saveInFlight = false;
    // Stale after suspension/owner replacement/disposal: settle nothing —
    // publish nothing, navigate nowhere. Same-owner recovery re-runs the
    // retained pending action when `resumed` reopens foreground.
    if (generation != _generation || _suspended || !mounted) return;
    if (failure != null) {
      if (failure is LearningConflictException ||
          failure is LearningContentChangedException) {
        // A typed conflict: the store's stored state moved ahead of this
        // session, so resending the same checkpoint can never succeed. The
        // stale in-memory draft is abandoned only by the explicit
        // `Reload saved progress` action, which reconciles the stored
        // checkpoint; drop the pending save intent so it is never re-sent.
        _pendingCommand = null;
        _pendingStore = null;
        _pendingOnSaved = null;
        setState(() {
          _busy = false;
          _saveError = null;
          _conflictError = _conflictText;
        });
        return;
      }
      if (failure is LearningUnavailableException) {
        _pendingCommand = null;
        _pendingStore = null;
        _pendingOnSaved = null;
        setState(() {
          _busy = false;
          _saveError = null;
          _conflictError = null;
          _loadError = _loadErrorText;
          _session = null;
        });
        return;
      }
      if (failure is LearningInvalidCommandException ||
          failure is LearningOwnerChangedException) {
        _pendingCommand = null;
        _pendingStore = null;
        _pendingOnSaved = null;
        setState(() {
          _busy = false;
          _saveError = null;
          _conflictError = _invalidCommandText;
        });
        return;
      }
      if (failure is! LearningSaveException) {
        _pendingCommand = null;
        _pendingStore = null;
        _pendingOnSaved = null;
        setState(() {
          _busy = false;
          _saveError = null;
          _conflictError = _invalidCommandText;
        });
        return;
      }
      // Persistence only: the view's error/Retry path. The pending action is
      // retained so `Retry saving` (and resumed recovery) re-sends the very
      // same checkpoint — the store records it at most once.
      setState(() {
        _busy = false;
        _saveError = _saveErrorText;
        _conflictError = null;
      });
      return;
    }
    final LearningCommit commit = committed!;
    _learningState = commit.state;
    if (commit.slot.snapshot case DiscoveryCheckpoint(:final session)) {
      if (command.action is! AdvanceLesson &&
          command.action is! ReviewDiscoveryMistakes) {
        _session = session;
      }
    }
    setState(() {
      _busy = false;
      _saveError = null;
      _conflictError = null;
    });
    // Refresh before the (possibly exiting) publish so navigating away and
    // disposing cannot skip the refresh.
    ref.invalidate(courseLearningStateProvider);
    // A successful write settles the pending action; a later resume must not
    // re-run it. Failed/uncertain ones are retained above.
    _pendingCommand = null;
    _pendingStore = null;
    _pendingOnSaved = null;
    if (onSaved != null) {
      await onSaved();
    }
  }

  Future<void> _onAnswer(String sound) async {
    final session = _session;
    if (session == null || session.answered) return;
    if (!_heard ||
        _busy ||
        _saveError != null ||
        _loadError != null ||
        _conflictError != null) {
      return;
    }
    final LearningCommand? command = _prepare(ChooseSound(
      selectedSound: sound,
      audioSource: _audioSourceForCurrentItem(session),
    ));
    if (command == null) return;
    _selectedSound = sound;
    // The engine freezes the candidate and immediate feedback together; the
    // screen never recalculates correctness or edits checkpoint state.
    final LessonSectionSession draft =
        (command.candidate as DiscoveryCheckpoint).session;
    if (mounted) setState(() => _session = draft);
    _runSave(command);
  }

  void _onNext() {
    final session = _session;
    if (session == null || !session.answered) return;
    final command = _prepare(const AdvanceLesson());
    if (command == null) return;
    final LessonSectionSession draft =
        (command.candidate as DiscoveryCheckpoint).session;
    _runSave(command, onSaved: () {
      if (mounted) {
        setState(() {
          _session = draft;
          // `heard` refers to the current item; a new item requires a fresh
          // completed playback before it can be answered.
          _heard = false;
          _playing = false;
          _selectedSound = null;
        });
      }
    });
  }

  void _onReview() {
    final session = _session;
    if (session == null || session.unresolvedItemIds.isEmpty) return;
    final command = _prepare(const ReviewDiscoveryMistakes());
    if (command == null) return;
    final LessonSectionSession draft =
        (command.candidate as DiscoveryCheckpoint).session;
    _runSave(command, onSaved: () {
      if (mounted) {
        setState(() {
          _session = draft;
          _heard = false;
          _playing = false;
          _selectedSound = null;
        });
      }
    });
  }

  void _onFinish() {
    final session = _session;
    if (session == null || !session.canComplete) return;
    final command = _prepare(FinishLearningActivity(
      recordCompletion: !widget.review,
    ));
    if (command != null) _runSave(command, onSaved: _exit);
  }

  void _onRetrySave() {
    if (_pendingCommand == null) {
      // Nothing pending: reload through the captured owner (coalesced with
      // any load already in flight).
      final CourseLearningStore? store = _store;
      if (store != null && !_suspended && !_saveInFlight && !_loadInFlight) {
        unawaited(_load(store, retry: true));
      }
      return;
    }
    if (_suspended || _saveInFlight) return;
    unawaited(_startSave());
  }

  /// Explicit `Reload saved progress` for a typed stale-session conflict:
  /// the only path that abandons the stale in-memory draft, and it
  /// reconciles the stored checkpoint under the existing single-shot load
  /// guards (a double tap before redraw cannot start a competing load).
  /// Cancellation of any pending hearing/playback is part of the reload;
  /// the retained pending save intent is dropped so the stale checkpoint is
  /// never re-submitted.
  void _onReload() {
    if (_suspended || _saveInFlight || _loadInFlight) return;
    _pendingCommand = null;
    _pendingStore = null;
    _pendingOnSaved = null;
    _stopAudio();
    _conflictError = null;
    final CourseLearningStore? store = _store;
    if (store == null) return;
    unawaited(_load(store));
  }

  /// Explicit `Practise again` at the debrief: start a fresh zero-attempt
  /// session identity and persist it (same owner, single-shot, retryable)
  /// before the new exercise is exposed. The stored history keeps its
  /// completion and evidence; the restart save replaces the section
  /// snapshot. A failed restart keeps the historical debrief and the retry
  /// UI — the new exercise is never shown before its identity is saved.
  void _onPractiseAgain() {
    final session = _session;
    final state = _learningState;
    final store = _store;
    if (session == null || state == null || store == null) return;
    if (session.phase != LessonSectionPhase.debrief) return;
    final LearningCommand command = store.prepare(
      state: state,
      activityId: _activityId,
      action: StartLearningRun(options: RunOptions(policy: session.policy)),
    );
    final LessonSectionSession fresh =
        (command.candidate as DiscoveryCheckpoint).session;
    _runSave(command, onSaved: () {
      if (mounted) {
        setState(() {
          _session = fresh;
          // A fresh item requires a fresh completed playback.
          _heard = false;
          _playing = false;
          _selectedSound = null;
        });
      }
    });
  }

  void _onRetryLoad() {
    final CourseLearningStore? store = _store;
    // Single-shot: a double tap before the busy state redraws (and any tap
    // while suspended) must not start a competing load whose late result
    // could publish over newer UI state.
    if (store == null || _suspended || _loadInFlight) return;
    unawaited(_load(store, retry: true));
  }

  void _onStartNewRun() {
    final store = _store;
    final state = _learningState;
    if (store == null || state == null || !_contentChanged || _saveInFlight) {
      return;
    }
    final command = store.prepare(
      state: state,
      activityId: _activityId,
      action: StartLearningRun(options: RunOptions(policy: widget.policy)),
    );
    _session = (command.candidate as DiscoveryCheckpoint).session;
    _loadError = null;
    _contentChanged = false;
    _runSave(command);
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
    if (section == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Discovery lesson')),
        body: _body(),
      );
    }
    // The word-bearing authored title (for example 'Tu or tout?') stays out
    // of the app bar while the item is hidden; only the debrief reveals it.
    final String title = _teachingUnavailable
        ? 'Discovery lesson'
        : _session?.phase == LessonSectionPhase.debrief
            ? section.title
            : 'Listening practice';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _body(),
    );
  }

  Widget _body() {
    if (_teachingUnavailable) {
      return const Center(child: Text('This discovery lesson is unavailable.'));
    }
    final section = _section;
    if (section == null) {
      return const Center(
        child: Text('This lesson is not part of the discovery section yet.'),
      );
    }
    if (_loadError != null) {
      final String loadError = _loadError!;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loadError, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                if (_contentChanged)
                  FilledButton(
                    onPressed: _onStartNewRun,
                    child: const Text('Start new run'),
                  )
                else
                  FilledButton(
                    onPressed: _store == null ? null : _onRetryLoad,
                    child: const Text('Retry loading'),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final session = _session;
    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return DiscoverySectionView(
      section: section,
      session: session,
      heard: _heard,
      busy: _busy || _suspended,
      playing: _playing,
      selectedSound: _selectedSound,
      error: _saveError,
      conflict: _conflictError,
      // The recovery notice lives inside the view's scrolling content, so a
      // long notice at large accessibility text cannot overflow the screen.
      notice: _corruptNotice,
      onListen: _onListen,
      onAnswer: _onAnswer,
      onNext: _onNext,
      onReview: _onReview,
      onFinish: _onFinish,
      onRetrySave: _onRetrySave,
      onReload: _onReload,
      onPractiseAgain: _onPractiseAgain,
      teachingEntries: session.phase == LessonSectionPhase.debrief
          ? _debriefContent!.forUnresolved(session.unresolvedItemIds)
          : const [],
    );
  }
}
