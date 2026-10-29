import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/course/course_attempt.dart';
import '../../core/course/course_audio.dart';
import '../../core/course/course_learning_error.dart';
import '../../core/course/course_learning_providers.dart';
import '../../core/course/french_uy_demo_spelling_content.dart';
import '../../core/widgets/purposeful_motion.dart';
import '../../core/course/lesson_policy.dart';
import '../../core/course/lesson_section_session.dart';
import '../../core/course/spelling_learning_command.dart';
import '../../core/course/spelling_learning_providers.dart';
import '../../core/course/spelling_learning_state.dart';
import '../../core/course/spelling_learning_store.dart';
import '../../core/course/spelling_learning_validator.dart';
import '../../core/course/storage/spelling_learning_command_codec.dart';
import 'lesson_progress_indicator.dart';

const String _spellingPrompt = 'Listen, then choose how the vowel is written.';
const String _spellingLoadError =
    'Saved spelling progress could not be loaded.';
const String _spellingSaveError =
    'This answer could not be saved. Tap "Retry saving" to try again.';

class SpellingLessonScreen extends ConsumerStatefulWidget {
  const SpellingLessonScreen({super.key, required this.review});

  final bool review;

  @override
  ConsumerState<SpellingLessonScreen> createState() =>
      _SpellingLessonScreenState();
}

class _SpellingLessonScreenState extends ConsumerState<SpellingLessonScreen>
    with WidgetsBindingObserver {
  FrenchUyDemoSpellingCatalogue? _catalogue;
  SpellingLearningStore? _store;
  SpellingLearningState? _state;
  SpellingSlot? _slot;
  LessonSectionSession? _session;
  SpellingAttempt? _feedback;
  SpellingPlaybackObservation? _grant;
  SpellingLearningCommand? _frozenCommand;
  CourseReferenceAudio? _activeAudio;
  SpellingProfileScope? _ownerScope;
  String? _error;
  String? _audioError;
  bool _loading = true;
  bool _loadFailed = false;
  bool _saveFailed = false;
  bool _busy = false;
  bool _playing = false;
  bool _readOnlyUnavailable = false;
  bool _routeCovered = false;
  bool _appSuspended = false;
  bool _authUnready = false;
  int _loadOperation = 0;
  int _saveOperation = 0;
  int _playbackOperation = 0;
  int _promptEpoch = 0;
  int _contextRevision = 0;
  int? _authGeneration;
  ModalRoute<dynamic>? _route;
  GoRouter? _goRouter;
  Animation<double>? _coverage;
  bool? _routeWasCurrent;
  ProviderSubscription<SpellingLearningStore>? _storeSubscription;
  ProviderSubscription<LearningAuthScope>? _authSubscription;

  bool get _isSavingAnswer =>
      _busy && _frozenCommand?.action is AnswerSpellingChoice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_acquireAndLoad());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_goRouter == null) {
      try {
        _goRouter = GoRouter.of(context)
          ..routerDelegate.addListener(_routeChanged);
      } on Object {
        // A route-less test surface still gets lifecycle and owner fencing.
      }
    }
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (_route == null) {
      _route = route;
      _routeWasCurrent = route?.isCurrent ?? true;
      _coverage = route?.secondaryAnimation?..addListener(_routeChanged);
    } else if (identical(route, _route)) {
      _routeChanged();
    }
  }

  @override
  void didUpdateWidget(covariant SpellingLessonScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review == widget.review) return;
    _contextRevision++;
    _loadOperation++;
    _retirePrompt();
    _state = null;
    _slot = null;
    _session = null;
    _feedback = null;
    _error = null;
    _audioError = null;
    _loadFailed = false;
    _saveFailed = false;
    _busy = _frozenCommand != null;
    _readOnlyUnavailable = false;
    unawaited(_acquireAndLoad());
  }

  Future<void> _acquireAndLoad() async {
    final int operation = ++_loadOperation;
    try {
      final FrenchUyDemoSpellingCatalogue catalogue = ref.read(
        spellingCatalogueProvider,
      );
      validateFrenchUyDemoSpellingCatalogue(catalogue);
      if (catalogue.activityId != uyDemoSpellingActivityId ||
          catalogue.contentRevision != uyDemoSpellingContentRevision) {
        throw const FormatException('Unsupported spelling activity.');
      }
      _catalogue = catalogue;
      _storeSubscription ??= ref.listenManual<SpellingLearningStore>(
        spellingLearningStoreProvider,
        _storeChanged,
      );
      _authSubscription ??= ref.listenManual<LearningAuthScope>(
        learningAuthScopeProvider,
        _authChanged,
      );
      final LearningAuthScope auth = ref.read(learningAuthScopeProvider);
      final SpellingLearningStore store = ref.read(
        spellingLearningStoreProvider,
      );
      if (store.scope !=
          SpellingProfileScope(courseId: 'en-fr', owner: auth.owner)) {
        throw const LearningOwnerChangedException();
      }
      _store = store;
      _ownerScope = store.scope;
      _authGeneration = auth.generation;
      _authUnready = !auth.ready;
      if (!auth.ready) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = _spellingLoadError;
          });
        }
        return;
      }
      await _load(store, operation);
    } on Object {
      if (!mounted || operation != _loadOperation) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
        _error = _spellingLoadError;
      });
    }
  }

  Future<void> _load(
    SpellingLearningStore store,
    int operation, {
    bool retry = false,
  }) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
      _error = null;
    });
    try {
      final SpellingLearningState loaded = retry
          ? await store.retryLoad()
          : await store.load();
      if (!_ownsLoad(store, operation)) return;
      _installLoadedState(loaded);
      final SpellingLearningCommand? pending = _frozenCommand;
      final bool pendingUnproven =
          pending != null && !_provesSavedCommand(loaded, pending);
      if (!pendingUnproven) _frozenCommand = null;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = false;
        _busy = false;
        _saveFailed = pendingUnproven;
        _error = pendingUnproven ? _spellingSaveError : null;
      });
    } on Object {
      if (!_ownsLoad(store, operation)) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
        _error = _spellingLoadError;
        _state = null;
        _slot = null;
        _session = null;
        _feedback = null;
      });
    }
  }

  void _installLoadedState(SpellingLearningState loaded) {
    final FrenchUyDemoSpellingCatalogue catalogue = _catalogue!;
    SpellingLearningStateValidator.validate(loaded, catalogue);
    final SpellingLearningStore store = _store!;
    if (loaded.scope != store.scope) {
      throw const FormatException('Saved spelling owner does not match.');
    }
    final SpellingSlot? slot = loaded.slots[catalogue.activityId];
    if (widget.review) {
      if (slot == null) {
        _state = loaded;
        _slot = null;
        _session = null;
        _feedback = null;
        _readOnlyUnavailable = true;
        return;
      }
      final LessonSectionSession session = _restoreSession(slot);
      final bool reviewOnly =
          slot.checkpoint.mode == SpellingRunMode.reviewOnly;
      final bool completePracticeDebrief =
          slot.checkpoint.mode == SpellingRunMode.practice &&
          session.phase == LessonSectionPhase.debrief &&
          session.latestAnswers.length == catalogue.rows.length &&
          slot.checkpoint.firstAttemptAnswers.length == catalogue.rows.length;
      if (!reviewOnly && !completePracticeDebrief) {
        _state = loaded;
        _slot = null;
        _session = null;
        _feedback = null;
        _readOnlyUnavailable = true;
        return;
      }
    }
    _readOnlyUnavailable = false;
    _state = loaded;
    _slot = slot;
    _session = slot == null ? null : _restoreSession(slot);
    _feedback = slot == null ? null : _savedFeedback(loaded, slot, _session!);
    _error = null;
  }

  LessonSectionSession _restoreSession(SpellingSlot slot) =>
      LessonSectionSession.fromJson(
        Map<String, dynamic>.from(slot.checkpoint.sessionJson),
        itemIds: _catalogue!.rows
            .map((UyDemoSpellingRow row) => row.exercise.id)
            .toList(),
        contentRevision: _catalogue!.contentRevision,
      );

  SpellingAttempt? _savedFeedback(
    SpellingLearningState state,
    SpellingSlot slot,
    LessonSectionSession session,
  ) {
    if (!session.answered || session.currentItemId == null) return null;
    final List<SpellingAttempt> matches = state.attempts
        .where(
          (SpellingAttempt attempt) =>
              attempt.activityId == slot.activityId &&
              attempt.generation == slot.cursor.generation &&
              attempt.round == session.round &&
              attempt.itemId == session.currentItemId,
        )
        .toList();
    if (matches.isEmpty) {
      throw const FormatException('Saved spelling answer has no proof.');
    }
    return matches.last;
  }

  bool _ownsLoad(SpellingLearningStore store, int operation) {
    if (!mounted ||
        operation != _loadOperation ||
        !identical(_store, store) ||
        store.scope != _ownerScope ||
        _routeCovered ||
        _appSuspended ||
        _authUnready) {
      return false;
    }
    return _ownsAuthAndRoute(store);
  }

  bool _ownsAuthAndRoute(SpellingLearningStore store) {
    if (!mounted ||
        !identical(_store, store) ||
        store.scope != _ownerScope ||
        _routeCovered ||
        _appSuspended ||
        _authUnready) {
      return false;
    }
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (_route != null &&
        (!identical(route, _route) || !(_route?.isCurrent ?? false))) {
      return false;
    }
    try {
      final LearningAuthScope current = ref.read(learningAuthScopeProvider);
      return current.ready &&
          current.owner == store.scope.owner &&
          current.generation == _authGeneration;
    } on Object {
      return false;
    }
  }

  void _storeChanged(
    SpellingLearningStore? previous,
    SpellingLearningStore next,
  ) {
    if (identical(previous, next)) return;
    _contextRevision++;
    _loadOperation++;
    _retirePrompt();
    _store = next;
    _ownerScope = next.scope;
    _state = null;
    _slot = null;
    _session = null;
    _feedback = null;
    _frozenCommand = null;
    _saveFailed = false;
    _error = null;
    try {
      final LearningAuthScope auth = ref.read(learningAuthScopeProvider);
      _authGeneration = auth.generation;
      _authUnready = !auth.ready;
    } on Object {
      _authUnready = true;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _loading = true;
      _loadFailed = false;
    });
    if (!_authUnready) unawaited(_load(next, ++_loadOperation));
  }

  void _authChanged(LearningAuthScope? previous, LearningAuthScope next) {
    if (previous != null &&
        previous.owner == next.owner &&
        previous.generation == next.generation &&
        previous.ready == next.ready) {
      return;
    }
    final SpellingLearningStore? store = _store;
    final bool ownerChanged =
        store != null &&
        (store.scope.owner != next.owner || next.generation != _authGeneration);
    if (!next.ready || ownerChanged) {
      _authUnready = !next.ready;
      _contextRevision++;
      _loadOperation++;
      _retirePrompt();
      _state = null;
      _slot = null;
      _session = null;
      _feedback = null;
      _frozenCommand = null;
      _saveFailed = false;
      _error = _spellingLoadError;
      if (ownerChanged) _authGeneration = next.generation;
      if (mounted) {
        setState(() {
          _busy = false;
          _loading = false;
        });
      }
      return;
    }
    _authGeneration = next.generation;
    _authUnready = false;
    if (mounted) setState(() {});
  }

  bool _ownsPlayback(
    SpellingLearningStore store,
    int playbackOperation,
    int epoch,
    String itemId,
    int generation,
    int round,
  ) =>
      mounted &&
      playbackOperation == _playbackOperation &&
      epoch == _promptEpoch &&
      identical(_store, store) &&
      _slot?.cursor.generation == generation &&
      _session?.round == round &&
      _session?.currentItemId == itemId &&
      _ownsAuthAndRoute(store);

  Future<void> _listen() async {
    final SpellingLearningStore? store = _store;
    final SpellingSlot? slot = _slot;
    final LessonSectionSession? session = _session;
    final UyDemoSpellingRow? row = _currentRow;
    if (store == null ||
        slot == null ||
        session == null ||
        row == null ||
        session.phase != LessonSectionPhase.exercise ||
        session.answered ||
        _busy ||
        !_ownsAuthAndRoute(store)) {
      return;
    }

    // Invalidate the previous grant and request before requesting another
    // recording. A failed or stale replay can never reuse the old grant.
    _retirePrompt();
    final int epoch = _promptEpoch;
    final int playbackOperation = ++_playbackOperation;
    final int contextRevision = _contextRevision;
    _audioError = null;
    if (mounted) {
      setState(() {
        _playing = true;
      });
    }

    CourseReferenceAudio audio;
    try {
      audio = ref.read(courseReferenceAudioProvider);
    } on Object {
      _playbackFailed(playbackOperation, epoch, row.exercise.id);
      return;
    }
    _activeAudio = audio;
    CourseAudioResult result;
    try {
      result = await audio.playReference(
        row.exercise.audioRefId,
        use: CourseAudioUse.alphaPractice,
        allowPracticeTts: false,
      );
    } on Object {
      if (_ownsPlayback(
            store,
            playbackOperation,
            epoch,
            row.exercise.id,
            slot.cursor.generation,
            session.round,
          ) &&
          contextRevision == _contextRevision) {
        _playbackFailed(playbackOperation, epoch, row.exercise.id);
      }
      return;
    }
    if (!_ownsPlayback(
          store,
          playbackOperation,
          epoch,
          row.exercise.id,
          slot.cursor.generation,
          session.round,
        ) ||
        contextRevision != _contextRevision) {
      return;
    }
    final LearningAuthScope currentAuth = ref.read(learningAuthScopeProvider);
    final bool accepted =
        result.outcome == CourseAudioOutcome.completed &&
        result.source == CourseAudioSource.unverifiedRecording &&
        result.referenceId == row.exercise.audioRefId &&
        currentAuth.ready &&
        currentAuth.owner == store.scope.owner &&
        currentAuth.generation == _authGeneration;
    _grant = accepted
        ? SpellingPlaybackObservation(
            profile: store.scope,
            authGeneration: currentAuth.generation,
            activityId: uyDemoSpellingActivityId,
            contentRevision: _catalogue!.contentRevision,
            runGeneration: slot.cursor.generation,
            round: session.round,
            itemId: row.exercise.id,
            referenceId: row.exercise.audioRefId,
            promptEpoch: epoch,
            outcome: result.outcome,
            source: result.source!,
          )
        : null;
    if (mounted) {
      setState(() {
        _playing = false;
        if (!accepted && result.outcome != CourseAudioOutcome.cancelled) {
          _audioError = 'The recording is unavailable. Try listening again.';
        }
      });
    }
  }

  void _playbackFailed(int operation, int epoch, String itemId) {
    if (!mounted ||
        operation != _playbackOperation ||
        epoch != _promptEpoch ||
        _session?.currentItemId != itemId) {
      return;
    }
    _grant = null;
    setState(() {
      _playing = false;
      _audioError = 'The recording is unavailable. Try listening again.';
    });
  }

  bool get _grantIsCurrent {
    final SpellingPlaybackObservation? grant = _grant;
    final SpellingLearningStore? store = _store;
    final SpellingSlot? slot = _slot;
    final LessonSectionSession? session = _session;
    final UyDemoSpellingRow? row = _currentRow;
    return grant != null &&
        store != null &&
        slot != null &&
        session != null &&
        row != null &&
        grant.profile == store.scope &&
        grant.authGeneration == _authGeneration &&
        grant.activityId == uyDemoSpellingActivityId &&
        grant.contentRevision == _catalogue?.contentRevision &&
        grant.runGeneration == slot.cursor.generation &&
        grant.round == session.round &&
        grant.itemId == row.exercise.id &&
        grant.referenceId == row.exercise.audioRefId &&
        grant.promptEpoch == _promptEpoch &&
        grant.outcome == CourseAudioOutcome.completed &&
        grant.source == CourseAudioSource.unverifiedRecording;
  }

  void _answer(String optionId) {
    final SpellingLearningStore? store = _store;
    final SpellingLearningState? state = _state;
    final SpellingSlot? slot = _slot;
    final LessonSectionSession? session = _session;
    final UyDemoSpellingRow? row = _currentRow;
    final SpellingPlaybackObservation? grant = _grant;
    if (store == null ||
        state == null ||
        slot == null ||
        session == null ||
        row == null ||
        session.answered ||
        _busy ||
        !_grantIsCurrent ||
        !_ownsAuthAndRoute(store)) {
      return;
    }
    // A grant is single use. Retire it before prepare/submit can yield.
    _retirePrompt(stopAudio: false);
    try {
      final SpellingLearningCommand command = store.prepare(
        state: state,
        action: AnswerSpellingChoice(
          itemId: row.exercise.id,
          contentRevision: _catalogue!.contentRevision,
          selectedOptionId: optionId,
          expectedOptionIdSnapshot: row.exercise.correctOptionId,
          playback: grant!,
        ),
      );
      _feedback = null;
      _audioError = null;
      _frozenCommand = command;
      _saveFailed = false;
      unawaited(_submitFrozen(command));
    } on Object {
      setState(() {
        _loadFailed = true;
        _error = _spellingLoadError;
      });
    }
  }

  void _perform(SpellingAction action) {
    final SpellingLearningStore? store = _store;
    final SpellingLearningState? state = _state;
    if (store == null ||
        state == null ||
        _busy ||
        _frozenCommand != null ||
        !_ownsAuthAndRoute(store)) {
      return;
    }
    try {
      final SpellingLearningCommand command = store.prepare(
        state: state,
        action: action,
      );
      _frozenCommand = command;
      _saveFailed = false;
      unawaited(_submitFrozen(command));
    } on Object {
      setState(() {
        _loadFailed = true;
        _error = _spellingLoadError;
      });
    }
  }

  Future<void> _submitFrozen(SpellingLearningCommand command) async {
    final SpellingLearningStore? store = _store;
    if (store == null || !_ownsAuthAndRoute(store)) return;
    final int operation = ++_saveOperation;
    final int contextRevision = _contextRevision;
    setState(() {
      _busy = true;
      _saveFailed = false;
      _error = null;
    });
    try {
      final SpellingCommit commit = await store.submit(command);
      if (!_ownsSave(store, operation, contextRevision)) return;
      if (!_provesSavedCommand(commit.state, command) ||
          commit.slot.activityId != command.activityId ||
          commit.slot.scope != command.scope) {
        throw const FormatException('Saved spelling receipt did not match.');
      }
      _installLoadedState(commit.state);
      _frozenCommand = null;
      _saveFailed = false;
      setState(() {
        _busy = false;
        _loading = false;
        _error = null;
      });
    } on Object {
      if (!_ownsSave(store, operation, contextRevision)) return;
      await _reloadToProveSave(store, command, operation, contextRevision);
    }
  }

  Future<void> _reloadToProveSave(
    SpellingLearningStore store,
    SpellingLearningCommand command,
    int operation,
    int contextRevision,
  ) async {
    try {
      final SpellingLearningState loaded = await store.retryLoad();
      if (!_ownsSave(store, operation, contextRevision)) return;
      SpellingLearningStateValidator.validate(loaded, _catalogue!);
      if (_provesSavedCommand(loaded, command)) {
        _installLoadedState(loaded);
        _frozenCommand = null;
        _saveFailed = false;
        setState(() {
          _busy = false;
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _busy = false;
          _saveFailed = true;
          _error = _spellingSaveError;
        });
      }
    } on Object {
      if (!_ownsSave(store, operation, contextRevision)) return;
      setState(() {
        _busy = false;
        _saveFailed = true;
        _error = _spellingSaveError;
      });
    }
  }

  bool _provesSavedCommand(
    SpellingLearningState state,
    SpellingLearningCommand command,
  ) {
    try {
      SpellingLearningStateValidator.validate(state, _catalogue!);
      final String canonical = const SpellingLearningCommandCodec().encode(
        command,
      );
      final bool receiptExists = state.receipts.any(
        (SpellingReceipt receipt) =>
            receipt.scope == command.scope &&
            receipt.activityId == command.activityId &&
            receipt.token == command.token &&
            receipt.canonicalCommand == canonical,
      );
      if (!receiptExists) return false;
      if (command.action case AnswerSpellingChoice(
        :final itemId,
        :final contentRevision,
        :final selectedOptionId,
        :final expectedOptionIdSnapshot,
        :final playback,
      )) {
        return state.attempts.any(
          (SpellingAttempt attempt) =>
              attempt.attemptId == command.token &&
              attempt.scope == command.scope &&
              attempt.activityId == command.activityId &&
              attempt.itemId == itemId &&
              attempt.contentRevision == contentRevision &&
              attempt.selectedOptionId == selectedOptionId &&
              attempt.expectedOptionId == expectedOptionIdSnapshot &&
              _samePlayback(attempt.playback, playback),
        );
      }
      return true;
    } on Object {
      return false;
    }
  }

  bool _samePlayback(
    SpellingPlaybackObservation left,
    SpellingPlaybackObservation right,
  ) =>
      left.profile == right.profile &&
      left.authGeneration == right.authGeneration &&
      left.activityId == right.activityId &&
      left.contentRevision == right.contentRevision &&
      left.runGeneration == right.runGeneration &&
      left.round == right.round &&
      left.itemId == right.itemId &&
      left.referenceId == right.referenceId &&
      left.promptEpoch == right.promptEpoch &&
      left.outcome == right.outcome &&
      left.source == right.source;

  bool _ownsSave(
    SpellingLearningStore store,
    int operation,
    int contextRevision,
  ) =>
      mounted &&
      operation == _saveOperation &&
      contextRevision == _contextRevision &&
      identical(_store, store) &&
      _ownsAuthAndRoute(store);

  void _retrySaving() {
    final SpellingLearningCommand? command = _frozenCommand;
    if (command == null || _busy || !_saveFailed) return;
    unawaited(_submitFrozen(command));
  }

  void _startPractice() => _perform(
    StartSpellingPractice(
      sessionId: 'spelling-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      policy: LessonPolicy(),
    ),
  );

  void _startReviewOnly() => _perform(
    StartSpellingReviewOnly(
      sessionId:
          'spelling-review-${DateTime.now().toUtc().microsecondsSinceEpoch}',
    ),
  );

  void _advance() => _perform(const AdvanceSpellingItem());

  void _reviewMistakes() => _perform(const ReviewSpellingMistakes());

  void _finish() {
    final SpellingSlot? slot = _slot;
    final LessonSectionSession? session = _session;
    if (slot == null || session == null) return;
    final bool recordCompletion =
        !widget.review &&
        slot.checkpoint.mode == SpellingRunMode.practice &&
        session.canComplete;
    _perform(FinishSpellingRun(recordCompletion: recordCompletion));
  }

  void _retryLoad() {
    final SpellingLearningStore? store = _store;
    if (store == null || _busy || !_loadFailed) return;
    unawaited(_load(store, ++_loadOperation, retry: true));
  }

  void _continuePractice() =>
      context.go('/course-spelling/$uyDemoSpellingActivityId');

  void _retirePrompt({bool stopAudio = true}) {
    _promptEpoch++;
    _playbackOperation++;
    _grant = null;
    _playing = false;
    final CourseReferenceAudio? audio = _activeAudio;
    _activeAudio = null;
    if (stopAudio && audio != null) {
      unawaited(audio.stop().catchError((Object _) {}));
    }
  }

  void _routeChanged() {
    final ModalRoute<dynamic>? route = _route;
    if (route == null || !identical(ModalRoute.of(context), route)) return;
    final bool current = route.isCurrent;
    if (_routeWasCurrent == current) return;
    _routeWasCurrent = current;
    if (!current) {
      _routeCovered = true;
      _contextRevision++;
      _retirePrompt();
      if (mounted) {
        setState(() {
          _busy = false;
          _playing = false;
        });
      }
    } else {
      _routeCovered = false;
      if (_frozenCommand != null && _store != null) {
        _recoverPendingCommand();
      } else if (_state == null &&
          _store != null &&
          !_appSuspended &&
          !_authUnready) {
        unawaited(_load(_store!, ++_loadOperation, retry: true));
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _appSuspended = true;
      _contextRevision++;
      _retirePrompt();
      if (mounted) {
        setState(() {
          _busy = false;
          _playing = false;
        });
      }
    } else if (state == AppLifecycleState.resumed && _appSuspended) {
      _appSuspended = false;
      if (_frozenCommand != null && _store != null && !_routeCovered) {
        _recoverPendingCommand();
      } else if (_state == null &&
          _frozenCommand == null &&
          !_routeCovered &&
          !_authUnready) {
        unawaited(_acquireAndLoad());
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  void _recoverPendingCommand() {
    final SpellingLearningStore? store = _store;
    final SpellingLearningCommand? command = _frozenCommand;
    if (store == null || command == null || !_ownsAuthAndRoute(store)) return;
    final int operation = ++_saveOperation;
    final int contextRevision = _contextRevision;
    setState(() {
      _busy = true;
      _saveFailed = false;
      _error = null;
    });
    unawaited(_reloadToProveSave(store, command, operation, contextRevision));
  }

  UyDemoSpellingRow? get _currentRow {
    final String? itemId = _session?.currentItemId;
    if (itemId == null) return null;
    for (final UyDemoSpellingRow row in _catalogue!.rows) {
      if (row.exercise.id == itemId) return row;
    }
    return null;
  }

  bool get _canListen {
    final SpellingLearningStore? store = _store;
    return store != null &&
        _slot != null &&
        _session?.phase == LessonSectionPhase.exercise &&
        _currentRow != null &&
        !_session!.answered &&
        !_busy &&
        _frozenCommand == null &&
        !_readOnlyUnavailable &&
        _ownsAuthAndRoute(store);
  }

  bool get _canAnswer => _canListen && _grantIsCurrent && !_playing;

  OutlinedButton _optionButton(String optionId) => OutlinedButton(
    onPressed: _canAnswer ? () => _answer(optionId) : null,
    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    child: Text(optionId),
  );

  @override
  Widget build(BuildContext context) {
    final SpellingSlot? slot = _slot;
    final LessonSectionSession? session = _session;
    final int total = session?.queue.length ?? _catalogue?.rows.length ?? 0;
    final int completed = session == null
        ? 0
        : completedItemsThisRound(session);
    final bool showProgress = _state != null && !_readOnlyUnavailable;
    final bool reviewRound =
        slot?.checkpoint.mode == SpellingRunMode.reviewOnly ||
        (session?.round ?? 1) > 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Sound → spelling practice')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (showProgress)
              LessonProgressIndicator(
                completed: completed,
                total: total,
                roundLabel: reviewRound
                    ? 'Review round ${session?.round ?? 1}'
                    : null,
              ),
            Expanded(
              child: LessonContentViewport(
                maxWidth: 640,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(_spellingPrompt),
                    if (_loading) ...<Widget>[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(_error!),
                    ],
                    if (_loadFailed)
                      TextButton(
                        onPressed: _busy ? null : _retryLoad,
                        child: const Text('Retry loading'),
                      ),
                    if (_saveFailed && _frozenCommand != null)
                      TextButton(
                        onPressed: _busy ? null : _retrySaving,
                        child: const Text('Retry saving'),
                      ),
                    if (_state == null && !_readOnlyUnavailable)
                      _optionButtons(),
                    if (_readOnlyUnavailable) ...<Widget>[
                      const SizedBox(height: 12),
                      const Text(
                        'Saved spelling practice is unavailable in this review view.',
                      ),
                    ] else if (!_loading &&
                        !_loadFailed &&
                        _state != null) ...<Widget>[
                      if (slot == null)
                        _emptyState()
                      else if (widget.review &&
                          slot.checkpoint.mode == SpellingRunMode.practice &&
                          session?.phase == LessonSectionPhase.debrief)
                        _debriefView(slot, session!)
                      else if (slot.checkpoint.finished)
                        _finishedView(slot)
                      else if (session?.phase == LessonSectionPhase.exercise &&
                          session?.currentItemId != null)
                        PurposefulSwitcher(
                          child: KeyedSubtree(
                            key: ValueKey(
                              'spelling-problem-${session!.currentItemId}',
                            ),
                            child: _exerciseView(),
                          ),
                        )
                      else if (session?.phase == LessonSectionPhase.debrief)
                        _debriefView(slot, session!)
                      else
                        const Center(child: CircularProgressIndicator()),
                    ],
                    if (_isSavingAnswer)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('Saving your answer…'),
                      ),
                    if (_busy && !_isSavingAnswer)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomAction(slot, session),
    );
  }

  Widget _emptyState() {
    if (widget.review) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 16),
        _listenButton(),
        _optionButtons(),
      ],
    );
  }

  Widget _exerciseView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const SizedBox(height: 16),
      _listenButton(),
      if (_audioError != null) ...<Widget>[
        const SizedBox(height: 8),
        Text(_audioError!),
      ],
      _optionButtons(),
      const SizedBox(height: 16),
      PurposefulSwitcher(
        child: _feedback == null
            ? const SizedBox.shrink(key: ValueKey('spelling-feedback-none'))
            : KeyedSubtree(
                key: ValueKey('spelling-feedback-${_feedback!.itemId}'),
                child: _feedbackView(_feedback!),
              ),
      ),
    ],
  );

  Widget _listenButton() => FilledButton.icon(
    onPressed: _canListen ? _listen : null,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    icon: _playing
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.volume_up),
    label: const Text('Listen to the word'),
  );

  Widget _optionButtons() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: <Widget>[
        Expanded(child: _optionButton('u')),
        const SizedBox(width: 12),
        Expanded(child: _optionButton('ou')),
      ],
    ),
  );

  Widget _feedbackView(SpellingAttempt attempt) {
    final UyDemoSpellingRow row = _rowFor(attempt.itemId);
    final String word = row.exercise.wordId;
    final int start = row.graphemeStart;
    final int end = row.graphemeEnd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(attempt.correct ? 'Correct' : 'Missed'),
        if (attempt.afterDebrief)
          const Text('Repeat in this run — feedback-assisted review.'),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(text: word.substring(0, start)),
              TextSpan(
                text: word.substring(start, end),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
              TextSpan(text: word.substring(end)),
            ],
          ),
          key: const ValueKey<String>('spelling-feedback-word'),
        ),
        Text('Your choice: ${attempt.selectedOptionId}'),
        Text('Correct spelling: ${attempt.expectedOptionId}'),
        Text(row.note),
      ],
    );
  }

  Widget _debriefView(SpellingSlot slot, LessonSectionSession session) {
    final bool reviewOnly = slot.checkpoint.mode == SpellingRunMode.reviewOnly;
    final Map<String, bool> firstAnswers = slot.checkpoint.firstAttemptAnswers;
    final Map<String, bool> latestPractice = reviewOnly
        ? slot.checkpoint.baseline!.latestPracticeAnswers
        : session.latestAnswers;
    final int firstCorrect = firstAnswers.values
        .where((bool value) => value)
        .length;
    final int latestCorrect = latestPractice.values
        .where((bool value) => value)
        .length;
    final bool hasMisses = session.unresolvedItemIds.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 16),
        const Text('Section debrief'),
        Text(
          '${reviewOnly ? 'First attempt in the source practice run' : 'First attempt in this run'}: '
          '$firstCorrect/${firstAnswers.length}',
        ),
        Text('Latest practice score: $latestCorrect/${latestPractice.length}'),
        if (widget.review && !reviewOnly) ...<Widget>[
          if (hasMisses)
            FilledButton(
              onPressed: _busy || _frozenCommand != null
                  ? null
                  : _startReviewOnly,
              child: const Text('Start review-only'),
            )
          else
            const Text('This saved debrief has no mistakes to review.'),
          const Text('Read-only debrief inspection.'),
        ] else if (widget.review && reviewOnly) ...<Widget>[
          if (hasMisses)
            OutlinedButton(
              onPressed: _busy || _frozenCommand != null
                  ? null
                  : _reviewMistakes,
              child: const Text('Review mistakes'),
            ),
        ] else if (reviewOnly) ...<Widget>[
          if (hasMisses)
            OutlinedButton(
              onPressed: _busy || _frozenCommand != null
                  ? null
                  : _reviewMistakes,
              child: const Text('Review mistakes'),
            ),
        ] else ...<Widget>[
          if (hasMisses)
            OutlinedButton(
              onPressed: _busy || _frozenCommand != null
                  ? null
                  : _reviewMistakes,
              child: const Text('Review mistakes'),
            ),
        ],
      ],
    );
  }

  Widget _finishedView(SpellingSlot slot) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const SizedBox(height: 16),
      Text(
        slot.checkpoint.mode == SpellingRunMode.reviewOnly
            ? 'Review run complete.'
            : 'Practice run complete.',
      ),
    ],
  );

  Widget? _bottomAction(SpellingSlot? slot, LessonSectionSession? session) {
    String? label;
    VoidCallback? action;
    bool canAct = !_busy && !_loading && !_loadFailed && !_saveFailed;

    if (_readOnlyUnavailable) {
      label = 'Continue practice';
      action = _continuePractice;
      canAct = !_busy && _frozenCommand == null;
    } else if (_state != null && slot == null && !widget.review) {
      label = 'Start practice';
      action = _startPractice;
      canAct = canAct && _frozenCommand == null;
    } else if (slot?.checkpoint.finished == true) {
      final bool canStartNew =
          slot!.checkpoint.mode == SpellingRunMode.reviewOnly ||
          (!widget.review && slot.checkpoint.mode == SpellingRunMode.practice);
      if (canStartNew) {
        label = 'Start new practice';
        action = _startPractice;
        canAct = canAct && _frozenCommand == null;
      }
    } else if (session?.phase == LessonSectionPhase.exercise &&
        session!.answered) {
      label = 'Continue';
      action = _advance;
      canAct = canAct && _frozenCommand == null;
    } else if (session?.phase == LessonSectionPhase.debrief &&
        !(widget.review && slot?.checkpoint.mode == SpellingRunMode.practice)) {
      final bool reviewOnly =
          slot?.checkpoint.mode == SpellingRunMode.reviewOnly;
      label = reviewOnly ? 'Finish review' : 'Finish practice';
      action = _finish;
      canAct = canAct && _frozenCommand == null;
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

  UyDemoSpellingRow _rowFor(String itemId) => _catalogue!.rows.singleWhere(
    (UyDemoSpellingRow row) => row.exercise.id == itemId,
  );

  @override
  void dispose() {
    _loadOperation++;
    _saveOperation++;
    _contextRevision++;
    _retirePrompt();
    _storeSubscription?.close();
    _authSubscription?.close();
    _goRouter?.routerDelegate.removeListener(_routeChanged);
    _coverage?.removeListener(_routeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
