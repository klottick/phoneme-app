import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_store.dart';
import 'package:linguist/src/features/course/exercises/listening_exercise_contract.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt.dart';
import 'package:linguist/src/features/course/lesson_exercise_owner.dart';

enum SentenceHuntEntryMode { practice, reviewOnly }

enum SentenceHuntPhase { loading, unavailable, exercise, debrief, finished }

/// Immutable UI projection. It deliberately contains no mutable learning
/// document; [session] is a detached read-only-for-this-view reconstruction.
final class SentenceHuntViewState {
  SentenceHuntViewState({
    required this.phase,
    required this.loading,
    required this.busy,
    required this.playing,
    required this.error,
    required this.conflict,
    required this.audioError,
    required this.feedback,
    required this.prompt,
    required Set<String> selectedTokenIds,
    required this.session,
    required List<SentenceHuntAttempt>? debriefAttempts,
    required this.canSubmit,
    required this.canAdvance,
    required this.canReview,
    required this.canFinish,
    required this.completionEligible,
    required this.reviewOnly,
    required this.finished,
    required this.modeMismatch,
    required this.loadFailed,
    required this.savePending,
  })  : selectedTokenIds = Set<String>.unmodifiable(selectedTokenIds),
        debriefAttempts = debriefAttempts == null
            ? null
            : List<SentenceHuntAttempt>.unmodifiable(debriefAttempts);

  final SentenceHuntPhase phase;
  final bool loading;
  final bool busy;
  final bool playing;
  final String? error;
  final String? conflict;
  final String? audioError;
  final ListeningFeedback? feedback;
  final SentenceHuntPrompt? prompt;
  final Set<String> selectedTokenIds;
  final LessonSectionSession? session;
  final List<SentenceHuntAttempt>? debriefAttempts;
  final bool canSubmit;
  final bool canAdvance;
  final bool canReview;
  final bool canFinish;
  final bool completionEligible;
  final bool reviewOnly;
  final bool finished;
  final bool modeMismatch;
  final bool loadFailed;
  final bool savePending;
}

/// Owns one section's temporary prompt, observed playback grant and frozen
/// save. Durable session transitions remain in the shared sentence domain.
class SentenceHuntController {
  SentenceHuntController({
    required this.sectionId,
    required this.catalogue,
    required this.store,
    required this.audio,
    this.entryMode = SentenceHuntEntryMode.practice,
    this.policy,
    required this.isCurrent,
    required this.onStateChanged,
  })  : _scope = store.scope,
        _grants = ExerciseAudioGrants<CourseAudioSource>(
          requiredSamples: <ComparisonSample?>{null},
        );

  static const String unavailableMessage =
      'This complete sentence section is unavailable until its content and audio are reviewed.';
  static const String loadErrorMessage =
      'Saved sentence-hunt progress could not be loaded.';
  static const String saveErrorMessage =
      'This change could not be saved. Tap "Retry saving" to try again.';
  static const String conflictMessage =
      'Saved sentence-hunt progress changed. Reload saved progress to continue.';
  static const String audioErrorMessage =
      'The sentence recording could not be played. Try listening again.';

  final String sectionId;
  final SentenceHuntCatalogue catalogue;
  final SentenceHuntLearningStore store;
  final CourseReferenceAudio audio;
  final SentenceHuntEntryMode entryMode;
  final LessonPolicy? policy;
  final bool Function() isCurrent;
  final VoidCallback onStateChanged;
  final SentenceHuntProfileScope _scope;

  ExerciseLifecycleFence _fence = ExerciseLifecycleFence();
  late ExerciseAudioGrants<CourseAudioSource> _grants;
  SentenceHuntState? _saved;
  SentenceHuntSlot? _slot;
  SentenceHuntSection? _section;
  LessonSectionSession? _session;
  SentenceHuntPrompt? _prompt;
  FrozenExerciseSave<SentenceHuntCommand, SentenceHuntCommit>? _save;
  ExerciseRequestIdentity? _playback;
  CourseReferenceAudio? _activeAudio;
  final Set<String> _selected = <String>{};

  int _loadOperation = 0;
  int _sessionIdCounter = 0;
  bool _loading = false;
  bool _busy = false;
  bool _playing = false;
  bool _answered = false;
  bool _inputClaimed = false;
  bool _loadFailed = false;
  bool _modeMismatch = false;
  bool _retired = false;
  bool _disposed = false;
  String? _error;
  String? _conflict;
  String? _audioError;
  ListeningFeedback? _feedback;

  SentenceHuntViewState get state {
    final LessonSectionSession? session = _session;
    final SentenceHuntSlot? slot = _slot;
    final bool blocked = !_ownsStoreAuthRoute();
    final bool debrief = session?.phase == LessonSectionPhase.debrief;
    final bool reviewOnly =
        slot?.checkpoint.mode == SentenceHuntRunMode.reviewOnly;
    final bool pendingSave = _save?.pendingCommand != null;
    final bool unavailable =
        _section == null || !catalogue.isAvailable(sectionId);
    final List<SentenceHuntAttempt>? attempts =
        debrief && session != null && slot != null && _saved != null
            ? _latestAttempts(_saved!, slot, session)
            : null;
    return SentenceHuntViewState(
      phase: unavailable && !_loading
          ? SentenceHuntPhase.unavailable
          : _loading && session == null
              ? SentenceHuntPhase.loading
              : debrief
                  ? slot?.checkpoint.finished == true
                      ? SentenceHuntPhase.finished
                      : SentenceHuntPhase.debrief
                  : SentenceHuntPhase.exercise,
      loading: _loading,
      busy: _busy || _playing,
      playing: _playing,
      error: _error,
      conflict: _conflict,
      audioError: _audioError,
      feedback: _feedback,
      prompt: _prompt,
      selectedTokenIds: _selected,
      session: session == null ? null : _copySession(session),
      debriefAttempts: attempts,
      canSubmit: !blocked &&
          !_busy &&
          !_playing &&
          !_answered &&
          !_inputClaimed &&
          !pendingSave &&
          _session?.answered != true &&
          _grants.canAnswer,
      canAdvance: !blocked &&
          !_busy &&
          !_playing &&
          !_inputClaimed &&
          !pendingSave &&
          _session?.answered == true &&
          _error == null &&
          _conflict == null,
      canReview: !blocked &&
          !_busy &&
          !_inputClaimed &&
          !pendingSave &&
          debrief &&
          session!.unresolvedItemIds.isNotEmpty &&
          (slot!.checkpoint.mode == SentenceHuntRunMode.practice),
      canFinish: !blocked &&
          !_busy &&
          !_inputClaimed &&
          !pendingSave &&
          debrief &&
          !slot!.checkpoint.finished &&
          (reviewOnly || session!.canComplete) &&
          _error == null &&
          _conflict == null,
      completionEligible: !reviewOnly && (session?.canComplete ?? false),
      reviewOnly: reviewOnly,
      finished: slot?.checkpoint.finished ?? false,
      modeMismatch: _modeMismatch,
      loadFailed: _loadFailed,
      savePending: pendingSave,
    );
  }

  Future<void> load({bool retry = false}) async {
    if (_disposed || _retired || _loading || _busy || !_ownsStoreAuthRoute()) {
      return;
    }
    SentenceHuntSection section;
    try {
      section = catalogue.section(sectionId);
    } on Object {
      _setUnavailable();
      return;
    }
    _section = section;
    if (!catalogue.isAvailable(sectionId)) {
      _setUnavailable();
      return;
    }

    if (retry) _prepareReload();
    final int operation = ++_loadOperation;
    final ExerciseLifecycleFence fence = _fence;
    final int epoch = fence.lifecycleEpoch;
    _loading = true;
    _loadFailed = false;
    _error = null;
    _conflict = null;
    _emit();

    late final SentenceHuntState loaded;
    try {
      loaded = retry ? await store.retryLoad() : await store.load();
    } on Object catch (error) {
      if (!_ownsLoad(operation, fence, epoch)) return;
      _loading = false;
      _loadFailed = true;
      _classifyError(error, loading: true);
      _emit();
      return;
    }
    if (!_ownsLoad(operation, fence, epoch)) return;
    if (loaded.scope != _scope || store.scope != _scope) {
      _loading = false;
      _loadFailed = true;
      _error = loadErrorMessage;
      _emit();
      return;
    }
    _saved = loaded;
    final SentenceHuntSlot? slot = loaded.slots[sectionId];
    if (slot == null) {
      if (entryMode == SentenceHuntEntryMode.reviewOnly) {
        _loading = false;
        _modeMismatch = true;
        _error = 'There is no saved sentence mistake round to review.';
        _emit();
        return;
      }
      await _startRun(
        loaded,
        mode: SentenceHuntRunMode.practice,
        savedPolicy: policy ?? section.policy,
      );
      return;
    }

    try {
      final LessonSectionSession restored = _restore(slot, section);
      _slot = slot;
      _publishSession(loaded, slot, restored, clearSelection: true);
      if (entryMode == SentenceHuntEntryMode.reviewOnly &&
          !slot.checkpoint.finished &&
          slot.checkpoint.mode != SentenceHuntRunMode.reviewOnly) {
        _modeMismatch = true;
      } else {
        _modeMismatch = false;
      }
      _loading = false;
      _error = null;
      _loadFailed = false;
      _emit();

      if (entryMode == SentenceHuntEntryMode.reviewOnly &&
          slot.checkpoint.finished &&
          slot.checkpoint.mode == SentenceHuntRunMode.practice &&
          restored.unresolvedItemIds.isNotEmpty) {
        await _startRun(
          loaded,
          mode: SentenceHuntRunMode.reviewOnly,
          savedPolicy: slot.checkpoint.policy,
        );
      } else if (entryMode == SentenceHuntEntryMode.reviewOnly &&
          slot.checkpoint.finished &&
          restored.unresolvedItemIds.isEmpty) {
        _error = 'There are no saved sentence mistakes to review.';
        _emit();
      }
    } on Object catch (error) {
      _loading = false;
      _loadFailed = true;
      _classifyError(error, loading: true);
      _emit();
    }
  }

  Future<void> _startRun(
    SentenceHuntState from, {
    required SentenceHuntRunMode mode,
    required LessonPolicy savedPolicy,
  }) async {
    if (!_ownsStoreAuthRoute()) return;
    _loading = false;
    _inputClaimed = true;
    try {
      final SentenceHuntCommand command = store.prepare(
        state: from,
        sectionId: sectionId,
        action: StartSentenceHuntRun(
          sessionId: _newSessionId(),
          policy: savedPolicy,
          mode: mode,
        ),
      );
      await _runCommand(command, clearSelection: true);
    } on Object catch (error) {
      _inputClaimed = false;
      _loadFailed = true;
      _classifyError(error, loading: true);
      _emit();
    }
  }

  Future<void> play() async {
    final SentenceHuntSlot? slot = _slot;
    final LessonSectionSession? session = _session;
    final SentenceHuntPrompt? prompt = _prompt;
    final SentenceHuntItem? item = _currentItem;
    if (_disposed ||
        _retired ||
        !_ownsStoreAuthRoute() ||
        slot == null ||
        session == null ||
        item == null ||
        prompt == null ||
        _busy ||
        _playing ||
        _inputClaimed ||
        _save?.claimed == true ||
        _answered ||
        session.answered) {
      return;
    }

    final ExerciseLifecycleFence fence = _fence;
    final int epoch = fence.lifecycleEpoch;
    final ExerciseRequestIdentity request = ExerciseRequestIdentity(
      prompt: _promptIdentity(session, slot),
      sample: null,
      referenceId: item.identity.audioRefId,
      lifecycleEpoch: epoch,
      playbackNonce: fence.beginPlayback(),
    );
    _grants.beginSample(request);
    _playback = request;
    _activeAudio = audio;
    _playing = true;
    _audioError = null;
    _emit();

    late final CourseAudioResult result;
    try {
      result = await audio.playReference(
        request.referenceId,
        use: CourseAudioUse.reviewedOnly,
        variant: CourseAudioVariant.normal,
        allowPracticeTts: false,
      );
    } on Object {
      if (!_ownsPlayback(request, fence, epoch, slot, session)) return;
      _playback = null;
      _activeAudio = null;
      _playing = false;
      _audioError = audioErrorMessage;
      _emit();
      return;
    }
    if (!_ownsPlayback(request, fence, epoch, slot, session)) return;

    final bool reviewedSource =
        result.source == CourseAudioSource.reviewedRecording;
    final bool accepted = reviewedSource &&
        _grants.acceptSuccess(
          request: request,
          actualReferenceId: result.referenceId,
          outcome: result.outcome,
          actualSource: result.source,
        );
    _playback = null;
    _activeAudio = null;
    _playing = false;
    if (!accepted) {
      _grants.revoke(null);
      if (result.outcome != CourseAudioOutcome.cancelled) {
        _audioError = audioErrorMessage;
      }
    } else {
      _audioError = null;
    }
    _emit();
  }

  void toggleToken(String id) {
    final SentenceHuntItem? item = _currentItem;
    if (_disposed ||
        _retired ||
        !_ownsStoreAuthRoute() ||
        item == null ||
        _busy ||
        _playing ||
        _answered ||
        _inputClaimed ||
        _save?.claimed == true ||
        !item.selectableTokenIds.contains(id)) {
      return;
    }
    if (!_selected.add(id)) _selected.remove(id);
    _emit();
  }

  Future<void> submit() async {
    final SentenceHuntState? saved = _saved;
    final SentenceHuntSlot? slot = _slot;
    final LessonSectionSession? session = _session;
    final SentenceHuntItem? item = _currentItem;
    if (_disposed ||
        _retired ||
        !_ownsStoreAuthRoute() ||
        saved == null ||
        slot == null ||
        session == null ||
        item == null ||
        !_grants.canAnswer ||
        _busy ||
        _playing ||
        _answered ||
        _inputClaimed ||
        _save?.claimed == true ||
        session.answered) {
      return;
    }

    final ExerciseHearingGrant<CourseAudioSource>? grant =
        _grants.grantFor(null);
    if (grant == null || !_validGrant(grant, item, slot, session)) return;

    // Claim first, then freeze an authored-order typed answer and its exact
    // observed recording before the first persistence await.
    _inputClaimed = true;
    final List<String> selection = canonicalSentenceSelection(item, _selected);
    final ExerciseRequestIdentity request = grant.request;
    final SentenceHuntAnswer answer = SentenceHuntAnswer(
      content: item.identity,
      selectedTokenIds: selection,
      expectedTokenIdsSnapshot: item.expectedTokenIds,
      playback: SentenceHuntPlaybackObservation(
        scope: _scope,
        content: item.identity,
        runGeneration: slot.cursor.generation,
        round: session.round,
        uiGeneration: request.lifecycleEpoch,
        referenceId: request.referenceId,
        outcome: CourseAudioOutcome.completed,
        source: grant.source,
      ),
    );
    _grants.revoke(null);
    late final SentenceHuntCommand command;
    try {
      command = store.prepare(
        state: saved,
        sectionId: sectionId,
        action: AnswerSentenceHuntItem(answer),
      );
    } on Object catch (error) {
      _inputClaimed = false;
      _answered = false;
      _feedback = null;
      _loadFailed = true;
      _classifyError(error, loading: false);
      _emit();
      return;
    }

    _answered = true;
    _feedback = scoreSentenceSelection(item, selection)
        ? ListeningFeedback.correct
        : ListeningFeedback.notYet;
    _audioError = null;
    _emit();
    await _runCommand(command, clearSelection: false);
  }

  Future<void> advance() async {
    final SentenceHuntState? saved = _saved;
    final LessonSectionSession? session = _session;
    if (saved == null ||
        session == null ||
        !session.answered ||
        !_ownsAction() ||
        _busy ||
        _save?.claimed == true) {
      return;
    }
    await _prepareAction(saved, const AdvanceSentenceHuntItem());
  }

  Future<void> reviewMistakes() async {
    final SentenceHuntState? saved = _saved;
    final SentenceHuntSlot? slot = _slot;
    final LessonSectionSession? session = _session;
    if (saved == null ||
        slot == null ||
        session == null ||
        session.phase != LessonSectionPhase.debrief ||
        session.unresolvedItemIds.isEmpty ||
        !_ownsAction() ||
        _busy ||
        _save?.claimed == true) {
      return;
    }
    if (slot.checkpoint.mode == SentenceHuntRunMode.reviewOnly) return;
    if (!slot.checkpoint.finished) {
      await _prepareAction(saved, const ReviewSentenceHuntMistakes());
      return;
    }
    await _startRun(
      saved,
      mode: SentenceHuntRunMode.reviewOnly,
      savedPolicy: slot.checkpoint.policy,
    );
  }

  Future<void> finish() async {
    final SentenceHuntState? saved = _saved;
    final SentenceHuntSlot? slot = _slot;
    final LessonSectionSession? session = _session;
    if (saved == null ||
        slot == null ||
        session == null ||
        session.phase != LessonSectionPhase.debrief ||
        slot.checkpoint.finished ||
        (slot.checkpoint.mode == SentenceHuntRunMode.practice &&
            !session.canComplete) ||
        !_ownsAction() ||
        _busy ||
        _save?.claimed == true) {
      return;
    }
    await _prepareAction(saved, const FinishSentenceHuntRun());
  }

  Future<void> _prepareAction(
      SentenceHuntState saved, SentenceHuntAction action) async {
    if (!_ownsAction() || _inputClaimed) return;
    _inputClaimed = true;
    try {
      final SentenceHuntCommand command = store.prepare(
        state: saved,
        sectionId: sectionId,
        action: action,
      );
      await _runCommand(command, clearSelection: true);
    } on Object catch (error) {
      _inputClaimed = false;
      _loadFailed = true;
      _classifyError(error, loading: false);
      _emit();
    }
  }

  Future<void> _runCommand(
    SentenceHuntCommand command, {
    required bool clearSelection,
  }) async {
    if (!_ownsStoreAuthRoute() || _retired) {
      _inputClaimed = false;
      return;
    }
    final ExerciseLifecycleFence fence = _fence;
    final int epoch = fence.lifecycleEpoch;
    late final FrozenExerciseSave<SentenceHuntCommand, SentenceHuntCommit> save;
    save = FrozenExerciseSave<SentenceHuntCommand, SentenceHuntCommit>(
      fence: fence,
      submit: store.submit,
      stillOwnsStoreAuthRoute: () =>
          identical(_fence, fence) && _ownsStoreAuthRoute(),
      onAcknowledged: (SentenceHuntCommit commit) async {
        if (!identical(_save, save) ||
            !_ownsOperation(fence, epoch) ||
            commit.state.scope != _scope ||
            commit.slot.sectionId != sectionId) {
          return;
        }
        try {
          final LessonSectionSession restored =
              _restore(commit.slot, _section!);
          _saved = commit.state;
          _slot = commit.slot;
          _publishSession(
            commit.state,
            commit.slot,
            restored,
            clearSelection: clearSelection,
          );
          _error = null;
          _conflict = null;
          _loadFailed = false;
          _loading = false;
          _modeMismatch = false;
        } on Object {
          _loadFailed = true;
          _conflict = conflictMessage;
        }
        _emit();
      },
    );
    _save = save;
    _busy = true;
    _loading = false;
    _error = null;
    _conflict = null;
    _loadFailed = false;
    _emit();
    try {
      await save.claimAndSubmit(command);
      if (!_ownsOperation(fence, epoch) || !identical(_save, save)) return;
      _busy = false;
      if (save.acknowledgementError != null) {
        _conflict =
            'This change was saved, but the screen could not update. Reload saved progress.';
      } else if (save.pendingCommand != null) {
        _error = saveErrorMessage;
      }
      _emit();
    } on Object catch (error) {
      if (!_ownsOperation(fence, epoch) || !identical(_save, save)) return;
      _busy = false;
      _classifyError(error, loading: false);
      _emit();
    } finally {
      if (identical(_save, save) && _ownsOperation(fence, epoch)) {
        _inputClaimed = false;
      }
    }
  }

  Future<void> retrySave() async {
    final FrozenExerciseSave<SentenceHuntCommand, SentenceHuntCommit>? save =
        _save;
    if (_disposed ||
        _retired ||
        save == null ||
        save.pendingCommand == null ||
        _busy ||
        !_ownsStoreAuthRoute()) {
      return;
    }
    final ExerciseLifecycleFence fence = _fence;
    final int epoch = fence.lifecycleEpoch;
    _busy = true;
    _error = null;
    _conflict = null;
    _emit();
    try {
      await save.retry();
      if (!_ownsOperation(fence, epoch) || !identical(_save, save)) return;
      _busy = false;
      if (save.acknowledgementError != null) {
        _conflict =
            'This change was saved, but the screen could not update. Reload saved progress.';
      } else if (save.pendingCommand != null) {
        _error = saveErrorMessage;
      }
      _emit();
    } on Object catch (error) {
      if (!_ownsOperation(fence, epoch) || !identical(_save, save)) return;
      _busy = false;
      _classifyError(error, loading: false);
      _emit();
    }
  }

  void suspend() {
    if (_disposed || _retired || _fence.isSuspended) return;
    final ExerciseRequestIdentity? request = _playback;
    final CourseReferenceAudio? activeAudio = _activeAudio;
    _playback = null;
    _activeAudio = null;
    _grants.revoke(null);
    _fence.suspend();
    _inputClaimed = false;
    if (_save?.pendingCommand != null) {
      _save?.orphanInFlight();
      _error = saveErrorMessage;
    }
    if (request != null && activeAudio != null) _stopAudio(activeAudio);
    if (_loading && _session == null) {
      _loadOperation++;
      _loadFailed = true;
      _error ??= loadErrorMessage;
    }
    _loading = false;
    _busy = false;
    _playing = false;
    _emit();
  }

  void resume() {
    if (_disposed || _retired || !_fence.isSuspended || !isCurrent()) return;
    _fence.resume();
    if (_save?.pendingCommand != null) {
      _error = saveErrorMessage;
    } else if (_session == null) {
      _error = loadErrorMessage;
      _loadFailed = true;
    }
    _emit();
  }

  void retireOwner() {
    if (_retired) return;
    _retired = true;
    _loadOperation++;
    final ExerciseRequestIdentity? request = _playback;
    final CourseReferenceAudio? activeAudio = _activeAudio;
    _playback = null;
    _activeAudio = null;
    _grants.retire();
    _save?.retireOwner();
    _save = null;
    _fence.replaceOwner();
    _selected.clear();
    if (request != null && activeAudio != null) _stopAudio(activeAudio);
    _loading = false;
    _busy = false;
    _playing = false;
    _inputClaimed = false;
  }

  void dispose() {
    if (_disposed) return;
    retireOwner();
    _disposed = true;
  }

  bool _validGrant(
    ExerciseHearingGrant<CourseAudioSource> grant,
    SentenceHuntItem item,
    SentenceHuntSlot slot,
    LessonSectionSession session,
  ) {
    final ExerciseRequestIdentity request = grant.request;
    return grant.source == CourseAudioSource.reviewedRecording &&
        request.prompt == _promptIdentity(session, slot) &&
        request.sample == null &&
        request.referenceId == item.identity.audioRefId &&
        request.lifecycleEpoch == _fence.lifecycleEpoch &&
        _fence.owns(request.lifecycleEpoch) &&
        request.playbackNonce > 0;
  }

  bool _ownsPlayback(
    ExerciseRequestIdentity request,
    ExerciseLifecycleFence fence,
    int epoch,
    SentenceHuntSlot slot,
    LessonSectionSession session,
  ) {
    final SentenceHuntItem? item = _currentItem;
    return !_disposed &&
        !_retired &&
        identical(_playback, request) &&
        identical(_fence, fence) &&
        fence.owns(epoch) &&
        _ownsStoreAuthRoute() &&
        identical(_slot, slot) &&
        identical(_session, session) &&
        item != null &&
        request.prompt == _promptIdentity(session, slot) &&
        request.referenceId == item.identity.audioRefId;
  }

  bool _ownsLoad(int operation, ExerciseLifecycleFence fence, int epoch) =>
      !_disposed &&
      !_retired &&
      operation == _loadOperation &&
      identical(_fence, fence) &&
      fence.owns(epoch) &&
      _ownsStoreAuthRoute();

  bool _ownsOperation(ExerciseLifecycleFence fence, int epoch) =>
      !_disposed &&
      !_retired &&
      identical(_fence, fence) &&
      fence.owns(epoch) &&
      _ownsStoreAuthRoute();

  bool _ownsStoreAuthRoute() {
    if (_disposed || _retired || _fence.isSuspended || store.scope != _scope) {
      return false;
    }
    try {
      return isCurrent();
    } on Object {
      return false;
    }
  }

  bool _ownsAction() =>
      !_disposed && !_retired && _ownsStoreAuthRoute() && _session != null;

  SentenceHuntItem? get _currentItem {
    final String? itemId = _session?.currentItemId;
    if (itemId == null || _section == null) return null;
    try {
      return catalogue.item(sectionId, itemId);
    } on Object {
      return null;
    }
  }

  ExercisePromptIdentity _promptIdentity(
    LessonSectionSession session,
    SentenceHuntSlot slot,
  ) =>
      ExercisePromptIdentity(
        activityId: sectionId,
        runGeneration: slot.cursor.generation,
        round: session.round,
        itemId: session.currentItemId!,
      );

  void _publishSession(
    SentenceHuntState state,
    SentenceHuntSlot slot,
    LessonSectionSession session, {
    required bool clearSelection,
  }) {
    _saved = state;
    _slot = slot;
    _session = session;
    if (session.currentItemId != null) {
      _grants.beginPrompt(_promptIdentity(session, slot));
    } else {
      _grants.revoke(null);
    }
    if (clearSelection) _selected.clear();
    _answered = session.answered;
    _feedback = session.answered
        ? session.lastCorrect == true
            ? ListeningFeedback.correct
            : ListeningFeedback.notYet
        : null;
    _audioError = null;
    _playing = false;
    _playback = null;
    _activeAudio = null;
    _prompt = session.phase == LessonSectionPhase.exercise &&
            session.currentItemId != null
        ? _promptFor(catalogue.item(sectionId, session.currentItemId!))
        : null;
  }

  SentenceHuntPrompt _promptFor(SentenceHuntItem item) {
    final String text = item.sentence.text;
    final List<SentenceHuntDisplayToken> display = <SentenceHuntDisplayToken>[];
    var offset = 0;
    var separatorIndex = 0;
    for (final SentenceToken token in item.sentence.tokens) {
      final int start = text.indexOf(token.text, offset);
      if (start < offset) {
        throw StateError(
            'Sentence word sequence does not match authored text.');
      }
      if (start > offset) {
        display.add(SentenceHuntDisplayToken(
          id: 'separator-${++separatorIndex}',
          text: text.substring(offset, start),
          selectable: false,
        ));
      }
      display.add(SentenceHuntDisplayToken(
        id: token.id,
        text: token.text,
        selectable: true,
      ));
      offset = start + token.text.length;
    }
    if (offset < text.length) {
      display.add(SentenceHuntDisplayToken(
        id: 'separator-${++separatorIndex}',
        text: text.substring(offset),
        selectable: false,
      ));
    }
    return SentenceHuntPrompt(
      itemId: item.identity.itemId,
      targetLabel: item.targetLabel,
      targetIpa: '/${item.exercise.targetSound}/',
      displayTokens: display,
      instruction:
          'Listen to the sentence, then select every word with this target sound.',
    );
  }

  List<SentenceHuntAttempt> _latestAttempts(
    SentenceHuntState state,
    SentenceHuntSlot slot,
    LessonSectionSession session,
  ) {
    final List<SentenceHuntAttempt> attempts = <SentenceHuntAttempt>[];
    for (final SentenceHuntItem item in _section!.items) {
      final bool? savedOutcome = session.latestAnswers[item.identity.itemId];
      if (savedOutcome == null) continue;
      final List<SentenceHuntAttempt> matches = state.attempts
          .where((SentenceHuntAttempt attempt) =>
              attempt.scope == _scope &&
              attempt.content == item.identity &&
              attempt.runGeneration == slot.cursor.generation &&
              attempt.correct == savedOutcome)
          .toList()
        ..sort((SentenceHuntAttempt a, SentenceHuntAttempt b) {
          final int round = a.round.compareTo(b.round);
          return round != 0 ? round : a.sequence.compareTo(b.sequence);
        });
      if (matches.isNotEmpty) attempts.add(matches.last);
    }
    return List<SentenceHuntAttempt>.unmodifiable(attempts);
  }

  LessonSectionSession _restore(
    SentenceHuntSlot slot,
    SentenceHuntSection section,
  ) {
    if (slot.sectionId != sectionId ||
        slot.checkpoint.sectionFingerprint != section.sectionFingerprint ||
        slot.checkpoint.contentRevision != section.contentRevision ||
        slot.checkpoint.scope != _scope) {
      throw const FormatException('Saved sentence section is stale.');
    }
    final LessonSectionSession session = LessonSectionSession.fromJson(
      _mutableJson(slot.checkpoint.sessionJson) as Map<String, dynamic>,
      itemIds: section.items
          .map((SentenceHuntItem item) => item.identity.itemId)
          .toList(growable: false),
      contentRevision: section.contentRevision,
    );
    if (slot.checkpoint.finished &&
        session.phase != LessonSectionPhase.debrief) {
      throw const FormatException(
          'Finished sentence section is not at debrief.');
    }
    return session;
  }

  LessonSectionSession _copySession(LessonSectionSession session) =>
      LessonSectionSession.fromJson(
        _mutableJson(session.toJson()) as Map<String, dynamic>,
        itemIds: session.itemIds,
        contentRevision: session.contentRevision,
      );

  void _prepareReload() {
    _save?.onConflictReloaded();
    _save = null;
    final ExerciseRequestIdentity? request = _playback;
    final CourseReferenceAudio? activeAudio = _activeAudio;
    _playback = null;
    _activeAudio = null;
    _grants.retire();
    if (request != null && activeAudio != null) _stopAudio(activeAudio);
    _fence.replaceOwner();
    _fence = ExerciseLifecycleFence();
    _grants = ExerciseAudioGrants<CourseAudioSource>(
      requiredSamples: <ComparisonSample?>{null},
    );
    _selected.clear();
    _session = null;
    _slot = null;
    _saved = null;
    _prompt = null;
    _answered = false;
    _feedback = null;
    _inputClaimed = false;
    _busy = false;
  }

  void _setUnavailable() {
    _loading = false;
    _loadFailed = false;
    _error = unavailableMessage;
    _conflict = null;
    _audioError = null;
    _emit();
  }

  void _classifyError(Object error, {required bool loading}) {
    if (error is LearningConflictException ||
        error is LearningContentChangedException ||
        (error is LearningSaveException &&
            (error.cause is LearningConflictException ||
                error.cause is LearningContentChangedException))) {
      _conflict = conflictMessage;
      _error = null;
      return;
    }
    if (error is LearningUnavailableException ||
        error is LearningCorruptException ||
        error is LearningUnsupportedVersionException ||
        error is SentenceHuntUnavailableException) {
      _loadFailed = true;
      _error = loadErrorMessage;
      _conflict = null;
      return;
    }
    _error = loading ? loadErrorMessage : saveErrorMessage;
    _conflict = null;
  }

  void _stopAudio(CourseReferenceAudio activeAudio) {
    try {
      unawaited(activeAudio.stop().catchError((Object _) {}));
    } on Object {
      // Shared facade retirement is best-effort; the lifecycle fence is final.
    }
  }

  String _newSessionId() =>
      'sentence-hunt-$sectionId-${DateTime.now().microsecondsSinceEpoch}-${++_sessionIdCounter}';

  void _emit() {
    if (!_disposed) onStateChanged();
  }
}

Object? _mutableJson(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        entry.key as String: _mutableJson(entry.value),
    };
  }
  if (value is List) {
    final List<Object?> result =
        value.map<Object?>((Object? child) => _mutableJson(child)).toList();
    return result.every((Object? child) => child is String)
        ? result.cast<String>()
        : result;
  }
  return value;
}
