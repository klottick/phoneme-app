import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/course/comparison_content.dart';
import '../../core/course/comparison_learning_command.dart';
import '../../core/course/comparison_learning_state.dart';
import '../../core/course/comparison_learning_store.dart';
import '../../core/course/course_audio.dart';
import '../../core/course/course_attempt.dart';
import '../../core/course/course_learning_error.dart';
import '../../core/course/course_learning_providers.dart';
import '../../core/course/lesson_policy.dart';
import '../../core/course/lesson_section_session.dart';
import 'comparison_section_debrief.dart';
import 'exercises/listening_exercise_contract.dart';
import 'exercises/sound_comparison.dart';
import 'lesson_exercise_owner.dart';

class ComparisonLessonScreen extends ConsumerStatefulWidget {
  const ComparisonLessonScreen({
    super.key,
    required this.activityId,
    this.review = false,
    this.policy,
    this.pairId,
    this.catalogueLoader,
  });

  final String activityId;
  final bool review;
  final LessonPolicy? policy;
  final String? pairId;
  final ComparisonCatalogue Function()? catalogueLoader;

  @override
  ConsumerState<ComparisonLessonScreen> createState() =>
      _ComparisonLessonScreenState();
}

class _ComparisonLessonScreenState extends ConsumerState<ComparisonLessonScreen>
    with WidgetsBindingObserver {
  static const _unavailable = 'This comparison activity is unavailable.';
  static const _loadError =
      'Your saved comparison progress could not be loaded.';
  static const _saveError =
      'This change could not be saved. Tap "Retry saving" to try again.';
  ComparisonCatalogue? _catalogue;
  ComparisonLearningStore? _store;
  ComparisonLearningState? _state;
  LessonSectionSession? _session;
  String? _contentError, _error, _conflict, _audioError;
  bool _busy = false, _playing = false, _answered = false;
  bool _inputClaimed = false;
  bool _loadFailed = false;
  bool _finished = false;
  PhonemeRelation? _selected;
  bool? _localCorrect;
  ExerciseLifecycleFence _fence = ExerciseLifecycleFence();
  late ExerciseAudioGrants<CourseAudioSource> _grants =
      ExerciseAudioGrants<CourseAudioSource>(
          requiredSamples: {ComparisonSample.a, ComparisonSample.b});
  FrozenExerciseSave<ComparisonLearningCommand, ComparisonCommit>? _save;
  CourseReferenceAudio? _activeAudio;
  ExerciseRequestIdentity? _playback;
  ComparisonProfileScope? _ownerScope;
  int? _authGeneration;
  ModalRoute<dynamic>? _route;
  GoRouter? _goRouter;
  Animation<double>? _coverage;
  bool? _routeWasCurrent;
  bool _appSuspended = false;
  bool _routeCovered = false;
  bool _appResumeRecoveryPending = false;
  bool _authUnready = false;
  bool _explicitRetryRequired = false;
  int _widgetContextRevision = 0;
  int _loadOperation = 0;
  ProviderSubscription<ComparisonLearningStore>? _storeSubscription;
  ProviderSubscription<LearningAuthScope>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _validateAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_goRouter == null) {
      try {
        _goRouter = GoRouter.of(context)
          ..routerDelegate.addListener(_routeChanged);
      } catch (_) {
        // A route-less MaterialApp still receives app lifecycle fencing.
      }
    }
    final route = ModalRoute.of(context);
    if (_route == null) {
      _route = route;
      _routeWasCurrent = route?.isCurrent ?? true;
      _coverage = route?.secondaryAnimation?..addListener(_routeChanged);
    } else if (identical(route, _route)) {
      _routeChanged();
    }
  }

  @override
  void didUpdateWidget(covariant ComparisonLessonScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityId == widget.activityId &&
        oldWidget.review == widget.review &&
        oldWidget.pairId == widget.pairId) {
      return;
    }
    _widgetContextRevision++;
    _explicitRetryRequired = false;
    _loadOperation++;
    _fence.replaceOwner();
    _grants.retire();
    _save?.retireOwner();
    _save = null;
    _playback = null;
    _stopAudio();
    _state = null;
    _session = null;
    _catalogue = null;
    _finished = false;
    _error = null;
    _conflict = null;
    _audioError = null;
    _loadFailed = false;
    _busy = false;
    _playing = false;
    _answered = false;
    _selected = null;
    _localCorrect = null;
    _fence = ExerciseLifecycleFence();
    if (_appSuspended || _routeCovered || _authUnready) _fence.suspend();
    _grants = ExerciseAudioGrants<CourseAudioSource>(
        requiredSamples: {ComparisonSample.a, ComparisonSample.b});
    _validateAndLoad();
  }

  void _validateAndLoad() {
    final operation = ++_loadOperation;
    ComparisonCatalogue catalogue;
    try {
      if (widget.activityId != comparisonActivityId ||
          (widget.pairId != null &&
              !RegExp(r'^fr07b-pair-(0[1-9]|10)$').hasMatch(widget.pairId!))) {
        throw const _InvalidComparisonContext();
      }
      final provided = ref.read(comparisonCatalogueProvider);
      catalogue = widget.catalogueLoader?.call() ?? provided;
      if (!_sameCatalogue(catalogue, provided) ||
          catalogue.activityId != widget.activityId ||
          (widget.pairId != null &&
              !catalogue.byId.containsKey(widget.pairId))) {
        throw const _InvalidComparisonContext();
      }
    } on ComparisonContentValidationException {
      _contentFailure(operation);
      return;
    } on _InvalidComparisonContext {
      _contentFailure(operation);
      return;
    } catch (_) {
      _contentFailure(operation);
      return;
    }
    _catalogue = catalogue;
    _contentError = null;
    ComparisonLearningStore store;
    LearningAuthScope auth;
    try {
      _storeSubscription ??=
          ref.listenManual(comparisonLearningStoreProvider, _storeChanged);
      _authSubscription ??=
          ref.listenManual(learningAuthScopeProvider, _authChanged);
      auth = ref.read(learningAuthScopeProvider);
      store = ref.read(comparisonLearningStoreProvider);
    } catch (_) {
      setState(() => _error = _loadError);
      return;
    }
    _store = store;
    _ownerScope = store.scope;
    _authGeneration = auth.generation;
    _authUnready = !auth.ready;
    if (!auth.ready || _appSuspended || _routeCovered) {
      _fence.suspend();
      _busy = false;
      return;
    }
    unawaited(_load(store, operation));
  }

  static bool _sameCatalogue(ComparisonCatalogue a, ComparisonCatalogue b) {
    if (a.activityId != b.activityId ||
        a.sectionId != b.sectionId ||
        a.contentRevision != b.contentRevision ||
        a.exercises.length != b.exercises.length) {
      return false;
    }
    for (var i = 0; i < a.exercises.length; i++) {
      final x = a.exercises[i], y = b.exercises[i];
      if (x.id != y.id ||
          x.activityId != y.activityId ||
          x.sectionId != y.sectionId ||
          x.contentRevision != y.contentRevision ||
          x.purpose != y.purpose ||
          x.reviewState != y.reviewState ||
          x.instruction != y.instruction ||
          x.expectedRelation != y.expectedRelation ||
          x.debriefNote != y.debriefNote ||
          !_sameSample(x.sampleA, y.sampleA) ||
          !_sameSample(x.sampleB, y.sampleB)) {
        return false;
      }
    }
    return true;
  }

  static bool _sameSample(
          ComparisonSampleContent a, ComparisonSampleContent b) =>
      a.slot == b.slot &&
      a.referenceId == b.referenceId &&
      a.target.phonemeId == b.target.phonemeId &&
      a.target.phonemeOrdinal == b.target.phonemeOrdinal;

  void _contentFailure(int operation) {
    if (!mounted || operation != _loadOperation) {
      return;
    }
    setState(() {
      _contentError = _unavailable;
      _busy = false;
      _catalogue = null;
    });
  }

  Future<void> _load(ComparisonLearningStore store, int operation,
      {bool retry = false}) async {
    if (_contentError != null || !mounted) return;
    final fence = _fence;
    final epoch = fence.lifecycleEpoch;
    final contextRevision = _widgetContextRevision;
    setState(() {
      _busy = true;
      _error = null;
      _conflict = null;
      _loadFailed = false;
    });
    ComparisonLearningState loaded;
    try {
      loaded = retry ? await store.retryLoad() : await store.load();
    } catch (error) {
      if (operation != _loadOperation ||
          !_ownsOperationContext(store, fence, epoch, contextRevision)) {
        return;
      }
      setState(() {
        _busy = false;
        _loadFailed = true;
        if (error is LearningConflictException ||
            error is LearningContentChangedException) {
          _conflict = 'Saved comparison progress changed. Reload to continue.';
        } else {
          _error = error is ComparisonUnavailableException ||
                  error is LearningUnavailableException ||
                  error is LearningCorruptException ||
                  error is LearningUnsupportedVersionException
              ? 'Saved comparison progress is unavailable. Reload to continue.'
              : _loadError;
        }
      });
      return;
    }
    if (operation != _loadOperation ||
        !_ownsOperationContext(store, fence, epoch, contextRevision)) {
      return;
    }
    _state = loaded;
    final slot = loaded.slot;
    if (slot == null) {
      final freshPolicy = widget.policy ?? LessonPolicy();
      _busy = false;
      _prepareAndRun(
          store,
          loaded,
          StartComparisonRun(
              sessionId:
                  'comparison-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}',
              policy: freshPolicy));
      return;
    }
    try {
      if (slot.activityId != widget.activityId ||
          slot.checkpoint.contentRevision != _catalogue!.contentRevision) {
        throw const FormatException('Stale comparison content');
      }
      final session = LessonSectionSession.fromJson(
        Map<String, dynamic>.from(slot.checkpoint.sessionJson),
        itemIds: _catalogue!.exercises.map((e) => e.id).toList(),
        contentRevision: _catalogue!.contentRevision,
      );
      _publish(session);
    } catch (_) {
      setState(() {
        _busy = false;
        _loadFailed = true;
        _error =
            'Saved comparison progress is unavailable. Reload to try again.';
      });
    }
  }

  void _publish(LessonSectionSession session) {
    final slot = _state!.slot!;
    final identity = _prompt(session, slot.cursor.generation);
    _grants.beginPrompt(identity);
    setState(() {
      _session = session;
      _busy = false;
      _playing = false;
      _answered = session.answered;
      _selected = null;
      _localCorrect = session.answered ? session.lastCorrect : null;
      _audioError = null;
    });
  }

  ExercisePromptIdentity _prompt(
          LessonSectionSession session, int generation) =>
      ExercisePromptIdentity(
          activityId: widget.activityId,
          runGeneration: generation,
          round: session.round,
          itemId: session.currentItemId ?? 'debrief');

  bool _ownsAuthAndRoute(ComparisonLearningStore store) {
    if (!mounted ||
        !identical(_store, store) ||
        store.scope != _ownerScope ||
        !identical(ModalRoute.of(context), _route) ||
        (_route != null && !_route!.isCurrent) ||
        _fence.isSuspended ||
        _authUnready) {
      return false;
    }
    try {
      final auth = ref.read(learningAuthScopeProvider);
      return auth.ready &&
          auth.owner == store.scope.owner &&
          auth.generation == _authGeneration;
    } catch (_) {
      return false;
    }
  }

  bool _ownsOperationContext(ComparisonLearningStore store,
          ExerciseLifecycleFence fence, int epoch, int contextRevision) =>
      mounted &&
      contextRevision == _widgetContextRevision &&
      identical(_fence, fence) &&
      fence.owns(epoch) &&
      identical(_store, store) &&
      _ownsAuthAndRoute(store);

  void _storeChanged(
      ComparisonLearningStore? previous, ComparisonLearningStore next) {
    if (identical(previous, next) || _contentError != null) {
      return;
    }
    _fence.replaceOwner();
    _explicitRetryRequired = false;
    _grants.retire();
    _save?.retireOwner();
    _save = null;
    _playback = null;
    _stopAudio();
    _loadOperation++;
    _store = next;
    _state = null;
    _session = null;
    _finished = false;
    _error = null;
    _conflict = null;
    _audioError = null;
    _loadFailed = false;
    _answered = false;
    _selected = null;
    _localCorrect = null;
    _busy = false;
    _playing = false;
    _grants = ExerciseAudioGrants<CourseAudioSource>(
        requiredSamples: {ComparisonSample.a, ComparisonSample.b});
    _fence = ExerciseLifecycleFence();
    _ownerScope = next.scope;
    final auth = ref.read(learningAuthScopeProvider);
    _authGeneration = auth.generation;
    _authUnready = !auth.ready;
    if (_appSuspended || _routeCovered || !auth.ready) _fence.suspend();
    _validateAndLoad();
  }

  void _authChanged(LearningAuthScope? previous, LearningAuthScope next) {
    if (previous != null &&
        previous.owner == next.owner &&
        previous.generation == next.generation &&
        previous.ready == next.ready) {
      return;
    }
    if (_contentError != null) return;
    final currentStore = _store;
    final ownerOrGenerationChanged = currentStore != null &&
        (next.owner != currentStore.scope.owner ||
            next.generation != _authGeneration);
    if (!next.ready || ownerOrGenerationChanged) {
      _authUnready = !next.ready;
      _revokeAllGrants();
      _playback = null;
      _stopAudio();
      if (_save?.pendingCommand != null) _save?.orphanInFlight();
      if (ownerOrGenerationChanged) {
        _explicitRetryRequired = false;
        _fence.replaceOwner();
      } else {
        _fence.suspend();
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _playing = false;
        });
      }
      return;
    }

    if (currentStore == null ||
        next.owner != currentStore.scope.owner ||
        next.generation != _authGeneration) {
      return;
    }
    _authUnready = false;
    if (_fence.isSuspended && !_appSuspended && !_routeCovered) {
      final shouldRetry = !_explicitRetryRequired;
      _appResumeRecoveryPending = false;
      _resumeOwner(retryPendingSave: shouldRetry);
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _listen(ComparisonSample sample) async {
    final session = _session, store = _store, slot = _state?.slot;
    if (session == null ||
        store == null ||
        slot == null ||
        _busy ||
        _save?.claimed == true ||
        !_ownsAuthAndRoute(store) ||
        session.currentItemId == null ||
        session.answered) {
      return;
    }
    final exercise = _catalogue!.exercise(session.currentItemId!);
    final content =
        sample == ComparisonSample.a ? exercise.sampleA : exercise.sampleB;
    final fence = _fence;
    final contextRevision = _widgetContextRevision;
    final request = ExerciseRequestIdentity(
      prompt: _prompt(session, slot.cursor.generation),
      sample: sample,
      referenceId: content.referenceId,
      lifecycleEpoch: fence.lifecycleEpoch,
      playbackNonce: fence.beginPlayback(),
    );
    _grants.beginSample(request);
    _playback = request;
    setState(() {
      _busy = true;
      _playing = true;
      _audioError = null;
    });
    CourseReferenceAudio audio;
    try {
      audio = ref.read(courseReferenceAudioProvider);
    } catch (_) {
      _audioFailed(request, fence, store, contextRevision);
      return;
    }
    _activeAudio = audio;
    CourseAudioResult result;
    try {
      result = await audio.playReference(content.referenceId,
          use: CourseAudioUse.alphaPractice,
          variant: CourseAudioVariant.normal,
          allowPracticeTts: false);
    } catch (_) {
      _audioFailed(request, fence, store, contextRevision);
      return;
    }
    if (!mounted ||
        !identical(_playback, request) ||
        !_ownsOperationContext(
            store, fence, request.lifecycleEpoch, contextRevision) ||
        !identical(_state?.slot, slot) ||
        _session?.currentItemId != request.prompt.itemId) {
      return;
    }
    final accepted = result.outcome == CourseAudioOutcome.completed &&
        result.source == CourseAudioSource.unverifiedRecording &&
        _grants.acceptSuccess(
            request: request,
            actualReferenceId: result.referenceId,
            outcome: result.outcome,
            actualSource: result.source);
    _playback = null;
    setState(() {
      _busy = false;
      _playing = false;
      if (!accepted && result.outcome != CourseAudioOutcome.cancelled) {
        _audioError = 'The sample could not be played. Try listening again.';
      }
    });
  }

  void _audioFailed(
      ExerciseRequestIdentity request,
      ExerciseLifecycleFence fence,
      ComparisonLearningStore store,
      int contextRevision) {
    if (!mounted ||
        !identical(_playback, request) ||
        !_ownsOperationContext(
            store, fence, request.lifecycleEpoch, contextRevision)) {
      return;
    }
    _playback = null;
    setState(() {
      _busy = false;
      _playing = false;
      _audioError = 'The sample could not be played. Try listening again.';
    });
  }

  void _answer(PhonemeRelation relation) {
    final session = _session, state = _state, store = _store;
    if (session == null ||
        state == null ||
        store == null ||
        _busy ||
        _answered ||
        _inputClaimed ||
        !_grants.canAnswer ||
        !_ownsAuthAndRoute(store)) {
      return;
    }
    final exercise = _catalogue!.exercise(session.currentItemId!);
    final a = _grants.grantFor(ComparisonSample.a);
    final b = _grants.grantFor(ComparisonSample.b);
    final slot = state.slot!;
    if (a == null ||
        b == null ||
        a.request.prompt != _prompt(session, slot.cursor.generation) ||
        b.request.prompt != _prompt(session, slot.cursor.generation) ||
        a.request.lifecycleEpoch != _fence.lifecycleEpoch ||
        b.request.lifecycleEpoch != _fence.lifecycleEpoch ||
        a.request.referenceId != exercise.sampleA.referenceId ||
        b.request.referenceId != exercise.sampleB.referenceId ||
        a.source != CourseAudioSource.unverifiedRecording ||
        b.source != CourseAudioSource.unverifiedRecording) {
      return;
    }
    final observations = [
      _observation(a, ComparisonSample.a, exercise.id, session, slot),
      _observation(b, ComparisonSample.b, exercise.id, session, slot),
    ];
    if (!_claimInput()) return;
    _answered = true;
    _selected = relation;
    _localCorrect = relation == exercise.expectedRelation;
    _grants
      ..revoke(ComparisonSample.a)
      ..revoke(ComparisonSample.b);
    try {
      final command = store.prepare(
        state: state,
        activityId: widget.activityId,
        action: AnswerComparisonPair(ComparePhonemesAnswer(
          selectedRelation: relation,
          expectedRelationSnapshot: exercise.expectedRelation,
          observations: observations,
        )),
      );
      setState(() {});
      _run(command);
    } catch (_) {
      _answered = false;
      _selected = null;
      _localCorrect = null;
      _revokeAllGrants();
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _error =
              'Saved comparison progress is unavailable. Reload to continue.';
        });
      }
    } finally {
      _releaseInput();
    }
  }

  ComparisonPlaybackObservation _observation(
          ExerciseHearingGrant<CourseAudioSource> grant,
          ComparisonSample sample,
          String pairId,
          LessonSectionSession session,
          ComparisonSlot slot) =>
      ComparisonPlaybackObservation(
        slot: sample,
        referenceId: grant.request.referenceId,
        outcome: CourseAudioOutcome.completed,
        source: grant.source,
        activityId: widget.activityId,
        runGeneration: slot.cursor.generation,
        round: session.round,
        pairId: pairId,
        profile: slot.scope,
        uiGeneration: grant.request.lifecycleEpoch,
      );

  void _run(ComparisonLearningCommand command) {
    final store = _store;
    if (store == null ||
        _busy ||
        _save?.claimed == true ||
        !_ownsAuthAndRoute(store)) {
      return;
    }
    final fence = _fence;
    final contextRevision = _widgetContextRevision;
    late final FrozenExerciseSave<ComparisonLearningCommand, ComparisonCommit>
        owner;
    owner = FrozenExerciseSave(
      fence: fence,
      submit: store.submit,
      stillOwnsStoreAuthRoute: () => _ownsOperationContext(
          store, fence, fence.lifecycleEpoch, contextRevision),
      onAcknowledged: (commit) async {
        if (!identical(_save, owner) ||
            contextRevision != _widgetContextRevision ||
            !identical(_store, store)) {
          return;
        }
        _state = commit.state;
        final saved = LessonSectionSession.fromJson(
            Map<String, dynamic>.from(commit.slot.checkpoint.sessionJson),
            itemIds: _catalogue!.exercises.map((e) => e.id).toList(),
            contentRevision: _catalogue!.contentRevision);
        _error = null;
        _conflict = null;
        if (command.action is FinishComparisonRun) _finished = true;
        if (mounted) _publish(saved);
        if (command.action is FinishComparisonRun) {
          try {
            if (widget.review || context.canPop()) context.pop();
          } catch (_) {
            // Durable completion is authoritative; a missing or failed route
            // callback must not turn the committed finish into a save retry.
          }
        }
      },
    );
    _save = owner;
    setState(() {
      _busy = true;
      _error = null;
    });
    unawaited(owner.claimAndSubmit(command).then((result) {
      if (!mounted ||
          !identical(_save, owner) ||
          contextRevision != _widgetContextRevision ||
          !identical(_store, store)) {
        return;
      }
      if (result != null || owner.pendingCommand == null) {
        _explicitRetryRequired = false;
      }
      if (owner.acknowledgementError != null) {
        setState(() {
          _busy = false;
          _error = null;
          _conflict =
              'This change was saved, but the screen could not update. Reload saved progress.';
        });
      }
    }, onError: (Object error) {
      if (!mounted ||
          !identical(_save, owner) ||
          contextRevision != _widgetContextRevision ||
          !identical(_store, store)) {
        return;
      }
      setState(() {
        _busy = false;
        _classifySaveFailure(error);
      });
    }));
  }

  void _advance() => _command(const AdvanceComparisonPair());
  void _review() => _command(const ReviewComparisonPairs());
  void _finish() =>
      _command(FinishComparisonRun(recordCompletion: !widget.review));

  void _command(ComparisonAction action) {
    final store = _store, state = _state;
    if (store == null ||
        state == null ||
        _busy ||
        _save?.claimed == true ||
        _inputClaimed ||
        !_ownsAuthAndRoute(store)) {
      return;
    }
    _prepareAndRun(store, state, action);
  }

  bool _claimInput() {
    if (_inputClaimed || _busy || _save?.claimed == true) return false;
    _inputClaimed = true;
    return true;
  }

  void _releaseInput() => _inputClaimed = false;

  void _prepareAndRun(ComparisonLearningStore store,
      ComparisonLearningState state, ComparisonAction action) {
    if (!_ownsAuthAndRoute(store) || !_claimInput()) return;
    try {
      final command = store.prepare(
          state: state, activityId: widget.activityId, action: action);
      _run(command);
    } catch (_) {
      _releaseInput();
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _error =
              'Saved comparison progress is unavailable. Reload to continue.';
        });
      }
    }
    _releaseInput();
  }

  Future<void> _retrySave() async {
    final owner = _save;
    if (owner == null ||
        _busy ||
        _conflict != null ||
        _loadFailed ||
        !_ownsAuthAndRoute(_store!)) {
      return;
    }
    _explicitRetryRequired = false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await owner.retry();
      if (mounted && identical(_save, owner)) {
        if (owner.acknowledgementError != null) {
          setState(() {
            _busy = false;
            _error = null;
            _conflict =
                'This change was saved, but the screen could not update. Reload saved progress.';
          });
        } else {
          setState(() => _busy = false);
        }
      }
    } catch (error) {
      if (!mounted || !identical(_save, owner)) return;
      setState(() {
        _busy = false;
        _classifySaveFailure(error);
      });
    }
  }

  void _classifySaveFailure(Object error) {
    if (error is LearningConflictException ||
        error is LearningContentChangedException ||
        (error is LearningSaveException &&
            (error.cause is LearningConflictException ||
                error.cause is LearningContentChangedException))) {
      _conflict = 'Saved comparison progress changed. Reload to continue.';
    } else if (error is ComparisonUnavailableException ||
        error is LearningUnavailableException ||
        error is LearningCorruptException ||
        error is LearningUnsupportedVersionException) {
      _loadFailed = true;
      _error = 'Saved comparison progress is unavailable. Reload to continue.';
    } else {
      _error = _saveError;
    }
  }

  void _reload() {
    final store = _store;
    if (store == null || _busy) {
      return;
    }
    _save?.onConflictReloaded();
    _explicitRetryRequired = false;
    _save = null;
    _fence.replaceOwner();
    _stopAudio();
    _fence.resume();
    _grants = ExerciseAudioGrants<CourseAudioSource>(
        requiredSamples: {ComparisonSample.a, ComparisonSample.b});
    _fence = ExerciseLifecycleFence();
    _load(store, ++_loadOperation, retry: true);
  }

  void _restart() {
    final state = _state, store = _store;
    if (state == null ||
        store == null ||
        _busy ||
        _save?.claimed == true ||
        _inputClaimed ||
        !_ownsAuthAndRoute(store)) {
      return;
    }
    _prepareAndRun(
        store,
        state,
        StartComparisonRun(
            sessionId: 'comparison-${DateTime.now().microsecondsSinceEpoch}',
            policy: _session!.policy));
  }

  void _stopAudio() {
    final audio = _activeAudio;
    _activeAudio = null;
    if (audio != null) {
      unawaited(audio.stop().catchError((Object _) {}));
    }
  }

  void _revokeAllGrants() {
    _grants
      ..revoke(ComparisonSample.a)
      ..revoke(ComparisonSample.b);
  }

  void _routeChanged() {
    final route = _route;
    if (route == null || !identical(ModalRoute.of(context), route)) {
      return;
    }
    final current = route.isCurrent;
    if (_routeWasCurrent == current) return;
    _routeWasCurrent = current;
    if (!current) {
      _routeCovered = true;
      _revokeAllGrants();
      _playback = null;
      _stopAudio();
      if (_save?.pendingCommand != null) {
        _explicitRetryRequired = true;
        _save?.orphanInFlight();
      }
      _suspendOwner();
      if (_session == null && _busy) _loadOperation++;
      if (mounted) {
        setState(() {
          _busy = false;
          _playing = false;
        });
      }
    } else {
      _routeCovered = false;
      if (!_appSuspended && !_authUnready) {
        final retryPendingSave = _appResumeRecoveryPending;
        _appResumeRecoveryPending = false;
        _resumeOwner(retryPendingSave: retryPendingSave);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _appSuspended = true;
      _revokeAllGrants();
      _playback = null;
      _stopAudio();
      _suspendOwner();
      if (_session == null && _busy) _loadOperation++;
      if (mounted) {
        setState(() {
          _busy = false;
          _playing = false;
        });
      }
    } else if (state == AppLifecycleState.resumed && _appSuspended) {
      _appSuspended = false;
      if (_routeCovered) {
        _appResumeRecoveryPending = true;
      } else if (_authUnready) {
        _appResumeRecoveryPending = true;
      } else {
        _resumeOwner(retryPendingSave: true);
      }
    }
  }

  void _suspendOwner() {
    if (_save?.pendingCommand != null && _conflict == null) {
      _save?.orphanInFlight();
    }
    _fence.suspend();
    if (mounted) {
      setState(() {
        _busy = false;
        _playing = false;
      });
    }
  }

  void _resumeOwner({required bool retryPendingSave}) {
    if (!_fence.isSuspended) return;
    final store = _store;
    if (store == null ||
        _appSuspended ||
        _routeCovered ||
        _authUnready ||
        !_ownsAuthAndRouteIgnoringSuspension(store)) {
      return;
    }
    _fence.resume();
    if (mounted) setState(() {});
    if (_save?.pendingCommand != null && _conflict == null) {
      if (_loadFailed) {
        if (mounted) setState(() => _busy = false);
      } else if (retryPendingSave && !_explicitRetryRequired) {
        _explicitRetryRequired = false;
        unawaited(_retrySave());
      } else if (mounted) {
        setState(() {
          _busy = false;
          _playing = false;
          _error = _saveError;
        });
      }
    } else {
      _explicitRetryRequired = false;
      if (_session == null && _loadFailed == false) {
        unawaited(_load(store, ++_loadOperation));
      }
    }
  }

  bool _ownsAuthAndRouteIgnoringSuspension(ComparisonLearningStore store) {
    if (!mounted ||
        !identical(_store, store) ||
        store.scope != _ownerScope ||
        !identical(ModalRoute.of(context), _route) ||
        (_route != null && !_route!.isCurrent)) {
      return false;
    }
    try {
      final auth = ref.read(learningAuthScopeProvider);
      return auth.ready &&
          auth.owner == store.scope.owner &&
          auth.generation == _authGeneration;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _loadOperation++;
    _fence.dispose();
    _grants.retire();
    _save?.retireOwner();
    _stopAudio();
    _authSubscription?.close();
    _storeSubscription?.close();
    _goRouter?.routerDelegate.removeListener(_routeChanged);
    _coverage?.removeListener(_routeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = _catalogue;
    final session = _session;
    final state = _state;
    final active = catalogue != null &&
        session != null &&
        state?.slot != null &&
        session.phase == LessonSectionPhase.exercise &&
        session.currentItemId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Sound comparison practice')),
      body: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_contentError != null) ...[
                    Text(_contentError!),
                    TextButton(
                        onPressed: _busy ? null : _retryValidation,
                        child: const Text('Retry validation')),
                  ],
                  if (_contentError == null &&
                      _error == null &&
                      _conflict == null &&
                      !active &&
                      session == null)
                    const Center(child: CircularProgressIndicator()),
                  if (_error != null &&
                      session?.phase != LessonSectionPhase.debrief)
                    Text(_error!),
                  if (_loadFailed &&
                      session?.phase != LessonSectionPhase.debrief) ...[
                    TextButton(
                        onPressed:
                            _save?.claimed == true ? _reload : _retryLoad,
                        child: Text(_save?.claimed == true
                            ? 'Reload saved progress'
                            : 'Retry loading')),
                  ],
                  if (_conflict != null &&
                      session?.phase != LessonSectionPhase.debrief) ...[
                    Text(_conflict!),
                    TextButton(
                        onPressed: _reload,
                        child: const Text('Reload saved progress')),
                  ],
                  if (_finished) const Text('Comparison complete.'),
                  if (active) _activeView(catalogue, session, state!),
                  if (catalogue != null &&
                      session?.phase == LessonSectionPhase.debrief &&
                      !_finished)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.pairId != null)
                          Text('Requested pair: ${widget.pairId}'),
                        ComparisonSectionDebrief(
                          catalogue: catalogue,
                          session: session!,
                          busy: _busy,
                          error: _loadFailed ? null : _error,
                          conflict: _conflict ??
                              (_loadFailed
                                  ? 'Saved comparison progress is unavailable. Reload to continue.'
                                  : null),
                          canFinish: session.canComplete,
                          onReview: _review,
                          onFinish: _finish,
                          onRetrySave: _retrySave,
                          onReload: _reload,
                          onPractiseAgain: _restart,
                        ),
                      ],
                    ),
                  if (_error != null &&
                      !_loadFailed &&
                      session?.phase != LessonSectionPhase.debrief)
                    TextButton(
                        onPressed: _retrySave,
                        child: const Text('Retry saving')),
                  if (_busy) const LinearProgressIndicator(),
                ],
              ))),
    );
  }

  Widget _activeView(ComparisonCatalogue catalogue,
      LessonSectionSession session, ComparisonLearningState state) {
    final exercise = catalogue.exercise(session.currentItemId!);
    final correct = _localCorrect;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SoundComparison(
        prompt: SoundComparisonPrompt(
          id: 'comparison-active',
          instruction: exercise.instruction,
          sampleAReferenceId: exercise.sampleA.referenceId,
          sampleBReferenceId: exercise.sampleB.referenceId,
        ),
        state: ListeningExerciseState(
          busy: _busy,
          playing: _playing,
          blocked: !_ownsAuthAndRoute(_store!),
          answered: _answered,
          feedback: !_answered || correct == null
              ? null
              : correct
                  ? ListeningFeedback.correct
                  : ListeningFeedback.notYet,
        ),
        heardSamples: _grants.heardSamples,
        selectedRelation: _selected,
        onListen: _listen,
        onAnswer: _answer,
      ),
      if (_audioError != null) Text(_audioError!),
      if (_answered &&
          !_busy &&
          _error == null &&
          _conflict == null &&
          _save?.claimed != true)
        FilledButton(onPressed: _advance, child: const Text('Continue')),
    ]);
  }

  void _retryLoad() {
    final store = _store;
    if (store != null && !_busy && _loadFailed && _save?.claimed != true) {
      _load(store, ++_loadOperation, retry: true);
    }
  }

  void _retryValidation() {
    if (_busy || _contentError == null) return;
    setState(() {
      _contentError = null;
      _busy = true;
    });
    _validateAndLoad();
  }
}

final class _InvalidComparisonContext implements Exception {
  const _InvalidComparisonContext();
}
