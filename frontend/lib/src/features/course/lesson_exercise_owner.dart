import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';

final class ExercisePromptIdentity {
  const ExercisePromptIdentity(
      {required this.activityId,
      required this.runGeneration,
      required this.round,
      required this.itemId});
  final String activityId;
  final int runGeneration;
  final int round;
  final String itemId;
  @override
  bool operator ==(Object other) =>
      other is ExercisePromptIdentity &&
      activityId == other.activityId &&
      runGeneration == other.runGeneration &&
      round == other.round &&
      itemId == other.itemId;
  @override
  int get hashCode => Object.hash(activityId, runGeneration, round, itemId);
}

final class ExerciseRequestIdentity {
  const ExerciseRequestIdentity(
      {required this.prompt,
      required this.sample,
      required this.referenceId,
      required this.lifecycleEpoch,
      required this.playbackNonce});
  final ExercisePromptIdentity prompt;
  final ComparisonSample? sample;
  final String referenceId;
  final int lifecycleEpoch;
  final int playbackNonce;
  @override
  bool operator ==(Object other) =>
      other is ExerciseRequestIdentity &&
      prompt == other.prompt &&
      sample == other.sample &&
      referenceId == other.referenceId &&
      lifecycleEpoch == other.lifecycleEpoch &&
      playbackNonce == other.playbackNonce;
  @override
  int get hashCode =>
      Object.hash(prompt, sample, referenceId, lifecycleEpoch, playbackNonce);
}

final class ExerciseHearingGrant<TSource> {
  const ExerciseHearingGrant({required this.request, required this.source});
  final ExerciseRequestIdentity request;
  final TSource source;
}

final class ExerciseLifecycleFence {
  int _epoch = 0, _nonce = 0;
  bool _suspended = false, _retired = false;
  int get lifecycleEpoch => _epoch;
  bool get isSuspended => _suspended;
  int beginPlayback() {
    if (_retired || _suspended) return _nonce;
    return ++_nonce;
  }

  bool owns(int lifecycleEpoch) =>
      !_retired && !_suspended && lifecycleEpoch == _epoch;
  void suspend() {
    if (!_retired && !_suspended) {
      _suspended = true;
      _epoch++;
    }
  }

  void resume() {
    if (!_retired && _suspended) _suspended = false;
  }

  void replaceOwner() {
    _epoch++;
    _retired = true;
  }

  void dispose() {
    _epoch++;
    _retired = true;
  }
}

final class ExerciseAudioGrants<TSource> {
  ExerciseAudioGrants({required Set<ComparisonSample?> requiredSamples})
      : _required = Set.unmodifiable(requiredSamples) {
    if (_required.isEmpty) {
      throw ArgumentError.value(requiredSamples, 'requiredSamples');
    }
  }
  final Set<ComparisonSample?> _required;
  final Map<ComparisonSample?, ExerciseHearingGrant<TSource>> _grants = {};
  final Map<ComparisonSample?, ExerciseRequestIdentity> _latest = {};
  ExercisePromptIdentity? _prompt;
  int? _lifecycleEpoch;
  int _lastPlaybackNonce = -1;
  bool _retired = false;
  void beginPrompt(ExercisePromptIdentity prompt) {
    if (_retired) return;
    if (_prompt != prompt) {
      _prompt = prompt;
      _grants.clear();
      _latest.clear();
      _lifecycleEpoch = null;
      _lastPlaybackNonce = -1;
    }
  }

  void beginSample(ExerciseRequestIdentity request) {
    if (_retired ||
        request.prompt != _prompt ||
        !_required.contains(request.sample)) {
      return;
    }
    final currentEpoch = _lifecycleEpoch;
    if (currentEpoch != null && request.lifecycleEpoch < currentEpoch) return;
    if (currentEpoch != null && request.lifecycleEpoch > currentEpoch) {
      _grants.clear();
      _latest.clear();
      _lastPlaybackNonce = -1;
    }
    _lifecycleEpoch = request.lifecycleEpoch;
    if (request.playbackNonce <= _lastPlaybackNonce) return;
    _lastPlaybackNonce = request.playbackNonce;
    _grants.remove(request.sample);
    _latest[request.sample] = request;
  }

  void revoke(ComparisonSample? sample) {
    _grants.remove(sample);
    _latest.remove(sample);
  }

  ExerciseHearingGrant<TSource>? grantFor(ComparisonSample? sample) =>
      _grants[sample];
  Set<ComparisonSample> get heardSamples =>
      Set.unmodifiable(_grants.keys.whereType<ComparisonSample>());
  bool get canAnswer => !_retired && _required.every(_grants.containsKey);
  bool acceptSuccess(
      {required ExerciseRequestIdentity request,
      required String? actualReferenceId,
      required CourseAudioOutcome outcome,
      required TSource? actualSource}) {
    if (_retired ||
        request.prompt != _prompt ||
        !_required.contains(request.sample) ||
        request.lifecycleEpoch != _lifecycleEpoch ||
        _latest[request.sample] != request ||
        actualReferenceId != request.referenceId ||
        outcome != CourseAudioOutcome.completed ||
        actualSource == null) {
      return false;
    }
    _grants[request.sample] =
        ExerciseHearingGrant(request: request, source: actualSource);
    return true;
  }

  void retire() {
    _retired = true;
    _grants.clear();
    _latest.clear();
  }
}

final class FrozenExerciseSave<C, R> {
  FrozenExerciseSave(
      {required this.fence,
      required this.submit,
      required this.stillOwnsStoreAuthRoute,
      required this.onAcknowledged});
  final ExerciseLifecycleFence fence;
  final Future<R> Function(C) submit;
  final bool Function() stillOwnsStoreAuthRoute;
  final Future<void> Function(R) onAcknowledged;
  C? _pending;
  bool _claimed = false, _retired = false;
  int _operation = 0;
  int? _inFlightOperation;
  int? _inFlightEpoch;
  Object? _acknowledgementError;
  Object? get acknowledgementError => _acknowledgementError;
  bool get claimed => _claimed;
  C? get pendingCommand => _pending;
  Future<R?> claimAndSubmit(C command) {
    if (_claimed || _retired || !_eligible()) return Future.value(null);
    _pending = command;
    _claimed = true;
    _acknowledgementError = null;
    return _run(command);
  }

  Future<R?> retry() {
    final command = _pending;
    if (!_claimed || command == null || !_eligible()) return Future.value(null);
    if (_inFlightOperation == _operation &&
        _inFlightEpoch == fence.lifecycleEpoch) {
      return Future.value(null);
    }
    return _run(command);
  }

  bool _eligible() =>
      !_retired &&
      fence.owns(fence.lifecycleEpoch) &&
      stillOwnsStoreAuthRoute();

  Future<R?> _run(C command) async {
    final operation = ++_operation, epoch = fence.lifecycleEpoch;
    if (!_eligible()) return null;
    _inFlightOperation = operation;
    _inFlightEpoch = epoch;
    try {
      late final R result;
      try {
        result = await submit(command);
      } catch (error, stackTrace) {
        if (!_ownsOperation(operation, epoch)) return null;
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (!_ownsOperation(operation, epoch)) return null;
      _pending = null;
      _claimed = false;
      try {
        await onAcknowledged(result);
      } catch (error) {
        if (operation == _operation) _acknowledgementError = error;
      }
      return result;
    } finally {
      if (_inFlightOperation == operation) {
        _inFlightOperation = null;
        _inFlightEpoch = null;
      }
    }
  }

  bool _ownsOperation(int operation, int epoch) =>
      operation == _operation && fence.owns(epoch) && stillOwnsStoreAuthRoute();

  void onConflictReloaded() {
    _operation++;
    _inFlightOperation = null;
    _inFlightEpoch = null;
    _pending = null;
    _claimed = false;
  }

  void retireOwner() {
    _retired = true;
    _operation++;
    _inFlightOperation = null;
    _inFlightEpoch = null;
    _pending = null;
    _claimed = false;
  }
}
