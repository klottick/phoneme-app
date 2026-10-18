import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_store.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt_controller.dart';
import 'sentence_hunt_fixtures.dart';

final class ControlledSentenceHuntPlayback {
  ControlledSentenceHuntPlayback({
    required this.referenceId,
    required this.use,
    required this.variant,
    required this.allowPracticeTts,
  }) : _result = Completer<CourseAudioResult>();

  final String referenceId;
  final CourseAudioUse use;
  final CourseAudioVariant variant;
  final bool allowPracticeTts;
  final Completer<CourseAudioResult> _result;

  Future<CourseAudioResult> get future => _result.future;
  bool get isCompleted => _result.isCompleted;

  void complete({
    String? referenceId,
    CourseAudioSource source = CourseAudioSource.reviewedRecording,
  }) {
    _result.complete(CourseAudioResult.completed(
      referenceId: referenceId ?? this.referenceId,
      source: source,
    ));
  }

  void cancel() => _result.complete(
        CourseAudioResult.cancelled(referenceId: referenceId),
      );

  void fail() => _result.complete(CourseAudioResult.failed(
        referenceId: referenceId,
        failure: const CourseAudioFailure(
          reason: CourseAudioFailureReason.unsupportedPlayback,
        ),
      ));
}

final class ControlledSentenceHuntAudio implements CourseReferenceAudio {
  final List<ControlledSentenceHuntPlayback> requests =
      <ControlledSentenceHuntPlayback>[];
  int speakCalls = 0;
  int stopCalls = 0;

  @override
  Future<CourseAudioResult> playReference(
    String referenceId, {
    CourseAudioUse use = CourseAudioUse.alphaPractice,
    CourseAudioVariant variant = CourseAudioVariant.normal,
    bool allowPracticeTts = false,
  }) {
    final ControlledSentenceHuntPlayback request =
        ControlledSentenceHuntPlayback(
      referenceId: referenceId,
      use: use,
      variant: variant,
      allowPracticeTts: allowPracticeTts,
    );
    requests.add(request);
    return request.future;
  }

  @override
  Future<void> speak(String word) async {
    speakCalls++;
    throw StateError('Sentence-hunt playback must never use speech.');
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {}
}

final class SentenceHuntMemoryPersistence implements LearningPersistence {
  final Map<String, String> cache = <String, String>{};
  final Map<String, String> durable = <String, String>{};
  int reads = 0;
  int writes = 0;
  Completer<void>? _writeGate;
  Completer<void>? _writeEntered;
  Object? _writeFailure;

  void holdNextWrite({Object? failure}) {
    _writeGate = Completer<void>();
    _writeEntered = Completer<void>();
    _writeFailure = failure;
  }

  Future<void> get writeEntered =>
      _writeEntered?.future ?? Future<void>.value();

  void releaseWrite() {
    final Completer<void>? gate = _writeGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<String?> read(String key) async {
    reads++;
    return cache[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    cache[key] = value;
    final Completer<void>? gate = _writeGate;
    if (gate != null) {
      _writeEntered?.complete();
      _writeEntered = null;
      await gate.future;
      if (identical(_writeGate, gate)) _writeGate = null;
      final Object? failure = _writeFailure;
      _writeFailure = null;
      if (failure != null) throw failure;
    }
    durable[key] = value;
  }

  @override
  Future<void> restore(String key, String? lastCommitted) async {
    if (lastCommitted == null) {
      cache.remove(key);
      durable.remove(key);
    } else {
      cache[key] = lastCommitted;
      durable[key] = lastCommitted;
    }
  }

  @override
  Future<void> reload() async {
    cache
      ..clear()
      ..addAll(durable);
  }
}

/// Instrumentation wraps the actual repository and transition coordinator;
/// it records call identity without replacing transactional behavior.
final class RecordingSentenceHuntStore implements SentenceHuntLearningStore {
  RecordingSentenceHuntStore({
    required this.catalogue,
    required this.persistence,
    LearningOwner? owner,
  }) : scope = SentenceHuntProfileScope(
          courseId: 'en-fr',
          owner: owner ?? LearningOwner.guest(),
        ) {
    _repository = SentenceHuntLearningRepository(
      scope: scope,
      authGeneration: 0,
      currentAuth: () => _auth,
      backendOwner: () => _backendOwner,
      persistence: persistence,
      transitions: SentenceHuntTransitionEngine(catalogue: catalogue),
      clock: () => DateTime.utc(2026, 10, 18, 12, 0, _clockTick++),
      newToken: () => (++_token).toRadixString(36).padLeft(22, '0'),
    );
  }

  final SentenceHuntCatalogue catalogue;
  final SentenceHuntMemoryPersistence persistence;
  @override
  final SentenceHuntProfileScope scope;
  late final SentenceHuntLearningRepository _repository;
  LearningOwner _backendOwner = LearningOwner.guest();
  LearningAuthScope _auth = LearningAuthScope(
      owner: LearningOwner.guest(), generation: 0, ready: true);
  int _token = 0;
  int _clockTick = 0;
  final List<SentenceHuntCommand> prepared = <SentenceHuntCommand>[];
  final List<SentenceHuntCommand> submitted = <SentenceHuntCommand>[];

  void updateAuth({
    LearningOwner? owner,
    bool? ready,
    bool changeBackendOwner = false,
  }) {
    final LearningOwner nextOwner = owner ?? _auth.owner;
    final int nextGeneration =
        _auth.generation + (nextOwner == _auth.owner ? 0 : 1);
    _auth = LearningAuthScope(
      owner: nextOwner,
      generation: nextGeneration,
      ready: ready ?? _auth.ready,
    );
    if (changeBackendOwner) _backendOwner = nextOwner;
  }

  @override
  Future<SentenceHuntState> load() => _repository.load();

  @override
  Future<SentenceHuntState> retryLoad() => _repository.retryLoad();

  @override
  SentenceHuntCommand prepare({
    required SentenceHuntState state,
    required String sectionId,
    required SentenceHuntAction action,
  }) {
    final SentenceHuntCommand command = _repository.prepare(
      state: state,
      sectionId: sectionId,
      action: action,
    );
    prepared.add(command);
    return command;
  }

  @override
  Future<SentenceHuntCommit> submit(SentenceHuntCommand command) {
    submitted.add(command);
    return _repository.submit(command);
  }
}

final class SentenceHuntTestRig {
  SentenceHuntTestRig({
    bool reviewed = true,
    this.sectionId = 'en-fr-sentence-hunt-vowels',
  })  : catalogue = syntheticSentenceCatalogue(reviewed: reviewed),
        persistence = SentenceHuntMemoryPersistence(),
        audio = ControlledSentenceHuntAudio() {
    store = RecordingSentenceHuntStore(
      catalogue: catalogue,
      persistence: persistence,
    );
  }

  final String sectionId;
  final SentenceHuntCatalogue catalogue;
  final SentenceHuntMemoryPersistence persistence;
  final ControlledSentenceHuntAudio audio;
  late final RecordingSentenceHuntStore store;

  SentenceHuntController controller({
    SentenceHuntEntryMode entryMode = SentenceHuntEntryMode.practice,
    LessonPolicy? policy,
    bool Function()? isCurrent,
    VoidCallback? onStateChanged,
  }) =>
      SentenceHuntController(
        sectionId: sectionId,
        catalogue: catalogue,
        store: store,
        audio: audio,
        entryMode: entryMode,
        policy: policy,
        isCurrent: isCurrent ?? () => true,
        onStateChanged: onStateChanged ?? () {},
      );

  ProviderContainer providerContainer({
    SentenceHuntCatalogue? providedCatalogue,
    Future<SentenceHuntCatalogue> Function()? acquireCatalogue,
    Future<SentenceHuntLearningStore> Function()? acquireStore,
    ControlledSentenceHuntAudio? providedAudio,
    LearningAuthTracker? authTracker,
  }) =>
      ProviderContainer(
        overrides: <Override>[
          learningAuthScopeProvider.overrideWith(
            (ref) =>
                authTracker ??
                LearningAuthTracker(
                  owner: LearningOwner.guest(),
                  ready: true,
                ),
          ),
          sentenceHuntCatalogueProvider.overrideWith(
            (ref) async => acquireCatalogue == null
                ? providedCatalogue ?? catalogue
                : await acquireCatalogue(),
          ),
          sentenceHuntLearningStoreProvider.overrideWith(
            (ref) async => acquireStore == null ? store : await acquireStore(),
          ),
          courseReferenceAudioProvider.overrideWith(
            (ref) => providedAudio ?? audio,
          ),
        ],
      );
}
