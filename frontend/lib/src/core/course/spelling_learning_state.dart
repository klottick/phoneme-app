import 'dart:convert';

import 'course_attempt.dart';
import 'course_audio_contract.dart';
import 'lesson_policy.dart';
import 'storage/learning_storage_scope.dart';

const int spellingMaxSafeInteger = 9007199254740991;
const int spellingMaxRetainedAttempts = 2000;
const int spellingMaxRetainedReceipts = 2000;

int _counter(int value, String name, {int minimum = 0}) {
  if (value < minimum || value > spellingMaxSafeInteger) {
    throw ArgumentError.value(value, name, 'Outside the supported range.');
  }
  return value;
}

int _positive(int value, String name) => _counter(value, name, minimum: 1);

String _required(String value, String name) {
  if (value.trim().isEmpty) throw ArgumentError.value(value, name);
  return value;
}

Map<String, bool> _freezeAnswers(Map<String, bool> answers, String name) {
  final copy = <String, bool>{};
  for (final entry in answers.entries) {
    if (entry.key.trim().isEmpty) {
      throw ArgumentError.value(answers, name, 'Invalid answer map.');
    }
    copy[entry.key] = entry.value;
  }
  return Map<String, bool>.unmodifiable(copy);
}

Object? _freezeJson(Object? value) {
  if (value is Map) {
    if (value.keys.any((key) => key is! String)) {
      throw ArgumentError('Session snapshot keys must be strings.');
    }
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _freezeJson(entry.value),
    });
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freezeJson));
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw ArgumentError('Session snapshot must contain JSON values only.');
}

final class SpellingProfileScope {
  SpellingProfileScope({required this.courseId, required this.owner}) {
    if (courseId != 'en-fr') {
      throw ArgumentError.value(courseId, 'courseId', 'Expected en-fr.');
    }
  }

  final String courseId;
  final LearningOwner owner;

  LearningStorageScope toStorageScope() => LearningStorageScope(
    owner: owner,
    courseId: courseId,
    family: LearningFamily.spelling,
  );

  @override
  bool operator ==(Object other) =>
      other is SpellingProfileScope &&
      other.courseId == courseId &&
      other.owner == owner;

  @override
  int get hashCode => Object.hash(courseId, owner);
}

enum SpellingRunMode { practice, reviewOnly }

final class SpellingCursor {
  SpellingCursor({
    required this.generation,
    required this.sequence,
    required this.revision,
  }) {
    _counter(generation, 'generation');
    _counter(sequence, 'sequence');
    _counter(revision, 'revision');
  }

  final int generation;
  final int sequence;
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is SpellingCursor &&
      other.generation == generation &&
      other.sequence == sequence &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(generation, sequence, revision);
}

final class SpellingPlaybackObservation {
  SpellingPlaybackObservation({
    required this.profile,
    required int authGeneration,
    required this.activityId,
    required int contentRevision,
    required int runGeneration,
    required int round,
    required this.itemId,
    required this.referenceId,
    required int promptEpoch,
    required this.outcome,
    required this.source,
  }) : authGeneration = _counter(authGeneration, 'authGeneration'),
       contentRevision = _positive(contentRevision, 'contentRevision'),
       runGeneration = _positive(runGeneration, 'runGeneration'),
       round = _positive(round, 'round'),
       promptEpoch = _counter(promptEpoch, 'promptEpoch') {
    _required(activityId, 'activityId');
    _required(itemId, 'itemId');
    _required(referenceId, 'referenceId');
    if (outcome != CourseAudioOutcome.completed ||
        source != CourseAudioSource.unverifiedRecording) {
      throw ArgumentError(
        'Spelling requires a completed unverified recording.',
      );
    }
  }

  final SpellingProfileScope profile;
  final int authGeneration;
  final String activityId;
  final int contentRevision;
  final int runGeneration;
  final int round;
  final String itemId;
  final String referenceId;
  final int promptEpoch;
  final CourseAudioOutcome outcome;
  final CourseAudioSource source;
}

final class SpellingPracticeBaseline {
  SpellingPracticeBaseline({
    required int sourceGeneration,
    required this.sourceSessionId,
    required int sourceContentRevision,
    required int sourceRound,
    required Map<String, bool> firstAttemptAnswers,
    required Map<String, bool> latestPracticeAnswers,
    required this.policy,
  }) : sourceGeneration = _positive(sourceGeneration, 'sourceGeneration'),
       sourceContentRevision = _positive(
         sourceContentRevision,
         'sourceContentRevision',
       ),
       sourceRound = _positive(sourceRound, 'sourceRound'),
       firstAttemptAnswers = _freezeAnswers(
         firstAttemptAnswers,
         'firstAttemptAnswers',
       ),
       latestPracticeAnswers = _freezeAnswers(
         latestPracticeAnswers,
         'latestPracticeAnswers',
       ) {
    _required(sourceSessionId, 'sourceSessionId');
  }

  final int sourceGeneration;
  final String sourceSessionId;
  final int sourceContentRevision;
  final int sourceRound;
  final Map<String, bool> firstAttemptAnswers;
  final Map<String, bool> latestPracticeAnswers;
  final LessonPolicy policy;
}

final class SpellingCheckpoint {
  SpellingCheckpoint({
    required this.scope,
    required this.sessionId,
    required int contentRevision,
    required this.policy,
    required this.mode,
    required int runStartRound,
    required this.finished,
    required Map<String, Object?> sessionJson,
    required Map<String, bool> firstAttemptAnswers,
    this.baseline,
  }) : contentRevision = _positive(contentRevision, 'contentRevision'),
       runStartRound = _positive(runStartRound, 'runStartRound'),
       sessionJson = _freezeJson(sessionJson) as Map<String, Object?>,
       firstAttemptAnswers = _freezeAnswers(
         firstAttemptAnswers,
         'firstAttemptAnswers',
       ) {
    _required(sessionId, 'sessionId');
    if (this.sessionJson['sessionId'] != sessionId ||
        this.sessionJson['contentRevision'] != contentRevision ||
        jsonEncode(this.sessionJson['policy']) != jsonEncode(policy.toJson()) ||
        (mode == SpellingRunMode.practice && baseline != null) ||
        (mode == SpellingRunMode.reviewOnly && baseline == null)) {
      throw ArgumentError('Checkpoint metadata differs from its session.');
    }
  }

  final SpellingProfileScope scope;
  final String sessionId;
  final int contentRevision;
  final LessonPolicy policy;
  final SpellingRunMode mode;
  final int runStartRound;
  final bool finished;
  final Map<String, Object?> sessionJson;
  final Map<String, bool> firstAttemptAnswers;
  final SpellingPracticeBaseline? baseline;
}

final class SpellingReceipt {
  SpellingReceipt({
    required this.scope,
    required this.activityId,
    required int generation,
    required int sequence,
    required this.token,
    required this.canonicalCommand,
    required this.before,
    required this.after,
    required int commitOrdinal,
  }) : generation = _positive(generation, 'generation'),
       sequence = _positive(sequence, 'sequence'),
       commitOrdinal = _positive(commitOrdinal, 'commitOrdinal') {
    _required(activityId, 'activityId');
    final initial =
        before == SpellingCursor(generation: 0, sequence: 0, revision: 0) &&
        after == SpellingCursor(generation: 1, sequence: 1, revision: 0);
    final restart =
        before.generation > 0 &&
        before.generation < spellingMaxSafeInteger &&
        before.sequence < spellingMaxSafeInteger &&
        after.generation == before.generation + 1 &&
        after.sequence == before.sequence + 1 &&
        after.revision == 0;
    final continuation =
        before.generation > 0 &&
        before.sequence < spellingMaxSafeInteger &&
        before.revision < spellingMaxSafeInteger &&
        after.generation == before.generation &&
        after.sequence == before.sequence + 1 &&
        after.revision == before.revision + 1;
    if (!RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(token) ||
        canonicalCommand.isEmpty ||
        !(initial || restart || continuation) ||
        this.generation != after.generation ||
        this.sequence != after.sequence) {
      throw ArgumentError('Invalid spelling receipt.');
    }
  }

  final SpellingProfileScope scope;
  final String activityId;
  final int generation;
  final int sequence;
  final String token;
  final String canonicalCommand;
  final SpellingCursor before;
  final SpellingCursor after;
  final int commitOrdinal;
}

final class SpellingSlot {
  SpellingSlot({
    required this.scope,
    required this.activityId,
    required this.cursor,
    required this.checkpoint,
    required this.latestReceipt,
  }) {
    if (scope != checkpoint.scope ||
        scope != latestReceipt.scope ||
        activityId != latestReceipt.activityId ||
        cursor != latestReceipt.after) {
      throw ArgumentError('Inconsistent spelling slot.');
    }
  }

  final SpellingProfileScope scope;
  final String activityId;
  final SpellingCursor cursor;
  final SpellingCheckpoint checkpoint;
  final SpellingReceipt latestReceipt;
}

final class SpellingAttempt {
  SpellingAttempt({
    required this.scope,
    required this.attemptId,
    required this.activityId,
    required int generation,
    required int sequence,
    required this.itemId,
    required int round,
    required int contentRevision,
    required this.selectedOptionId,
    required this.expectedOptionId,
    required this.correct,
    required this.presentation,
    required this.afterDebrief,
    required this.teachingExposed,
    required this.audioSource,
    required this.playback,
    required this.committedAt,
  }) : generation = _positive(generation, 'generation'),
       sequence = _positive(sequence, 'sequence'),
       round = _positive(round, 'round'),
       contentRevision = _positive(contentRevision, 'contentRevision') {
    _required(attemptId, 'attemptId');
    _required(activityId, 'activityId');
    _required(itemId, 'itemId');
    if (!const {'u', 'ou'}.contains(selectedOptionId) ||
        !const {'u', 'ou'}.contains(expectedOptionId) ||
        correct != (selectedOptionId == expectedOptionId) ||
        afterDebrief != (round > 1) ||
        teachingExposed != afterDebrief ||
        presentation !=
            (afterDebrief
                ? AttemptPresentation.repeatInRun
                : AttemptPresentation.firstInRun) ||
        audioSource != AttemptAudioSource.pendingRecording ||
        playback.profile != scope ||
        playback.activityId != activityId ||
        playback.contentRevision != contentRevision ||
        playback.runGeneration != generation ||
        playback.round != round ||
        playback.itemId != itemId ||
        playback.outcome != CourseAudioOutcome.completed ||
        playback.source != CourseAudioSource.unverifiedRecording ||
        !committedAt.isUtc ||
        !playback.referenceId.isNotEmpty) {
      throw ArgumentError('Invalid spelling attempt.');
    }
  }

  final SpellingProfileScope scope;
  final String attemptId;
  final String activityId;
  final int generation;
  final int sequence;
  final String itemId;
  final int round;
  final int contentRevision;
  final String selectedOptionId;
  final String expectedOptionId;
  final bool correct;
  final AttemptPresentation presentation;
  final bool afterDebrief;
  final bool teachingExposed;
  final AttemptAudioSource audioSource;
  final SpellingPlaybackObservation playback;
  final DateTime committedAt;
}

final class SpellingMistakeKey {
  SpellingMistakeKey({
    required this.scope,
    required this.activityId,
    required this.itemId,
    required this.targetSound,
    required int contentRevision,
  }) : contentRevision = _positive(contentRevision, 'contentRevision') {
    _required(activityId, 'activityId');
    _required(itemId, 'itemId');
    _required(targetSound, 'targetSound');
  }

  final SpellingProfileScope scope;
  final String activityId;
  final String itemId;
  final String targetSound;
  final int contentRevision;

  @override
  bool operator ==(Object other) =>
      other is SpellingMistakeKey &&
      scope == other.scope &&
      activityId == other.activityId &&
      itemId == other.itemId &&
      targetSound == other.targetSound &&
      contentRevision == other.contentRevision;

  @override
  int get hashCode =>
      Object.hash(scope, activityId, itemId, targetSound, contentRevision);
}

final class SpellingMistake {
  SpellingMistake({
    required this.key,
    required this.firstWrongAt,
    required this.latestWrongAt,
    required int failureCount,
  }) : failureCount = _positive(failureCount, 'failureCount') {
    if (!firstWrongAt.isUtc ||
        !latestWrongAt.isUtc ||
        latestWrongAt.isBefore(firstWrongAt)) {
      throw ArgumentError('Invalid spelling mistake timestamps.');
    }
  }

  final SpellingMistakeKey key;
  final DateTime firstWrongAt;
  final DateTime latestWrongAt;
  final int failureCount;
}

final class SpellingSummaryKey {
  SpellingSummaryKey({
    required this.scope,
    required this.activityId,
    required this.itemId,
    required this.sound,
    required int contentRevision,
  }) : contentRevision = _positive(contentRevision, 'contentRevision') {
    _required(activityId, 'activityId');
    _required(itemId, 'itemId');
    _required(sound, 'sound');
  }

  final SpellingProfileScope scope;
  final String activityId;
  final String itemId;
  final String sound;
  final int contentRevision;

  @override
  bool operator ==(Object other) =>
      other is SpellingSummaryKey &&
      scope == other.scope &&
      activityId == other.activityId &&
      itemId == other.itemId &&
      sound == other.sound &&
      contentRevision == other.contentRevision;

  @override
  int get hashCode =>
      Object.hash(scope, activityId, itemId, sound, contentRevision);
}

final class SpellingCount {
  SpellingCount({required int correct, required int total})
    : correct = _counter(correct, 'correct'),
      total = _counter(total, 'total') {
    if (this.correct > this.total) {
      throw ArgumentError('Invalid spelling count.');
    }
  }

  final int correct;
  final int total;
}

final class SpellingSummary {
  const SpellingSummary({
    required this.key,
    required this.firstInRun,
    required this.afterDebrief,
  });

  final SpellingSummaryKey key;
  final SpellingCount firstInRun;
  final SpellingCount afterDebrief;
}

final class SpellingExposureKey {
  SpellingExposureKey({
    required this.scope,
    required this.activityId,
    required this.itemId,
    required this.targetSound,
    required int contentRevision,
  }) : contentRevision = _positive(contentRevision, 'contentRevision') {
    _required(activityId, 'activityId');
    _required(itemId, 'itemId');
    _required(targetSound, 'targetSound');
  }

  final SpellingProfileScope scope;
  final String activityId;
  final String itemId;
  final String targetSound;
  final int contentRevision;

  @override
  bool operator ==(Object other) =>
      other is SpellingExposureKey &&
      scope == other.scope &&
      activityId == other.activityId &&
      itemId == other.itemId &&
      targetSound == other.targetSound &&
      contentRevision == other.contentRevision;

  @override
  int get hashCode =>
      Object.hash(scope, activityId, itemId, targetSound, contentRevision);
}

final class SpellingExposure {
  SpellingExposure({
    required this.key,
    required int presentations,
    required int assistanceMask,
  }) : presentations = _counter(presentations, 'presentations'),
       assistanceMask = _counter(assistanceMask, 'assistanceMask') {
    if (this.assistanceMask > 15) {
      throw ArgumentError.value(assistanceMask, 'assistanceMask');
    }
  }

  final SpellingExposureKey key;
  final int presentations;
  final int assistanceMask;
}

final class SpellingCompletion {
  SpellingCompletion({
    required this.scope,
    required this.activityId,
    required int contentRevision,
    required this.policyKind,
    required int policyRevision,
    required int thresholdPercent,
    required this.committedAt,
  }) : contentRevision = _positive(contentRevision, 'contentRevision'),
       policyRevision = _positive(policyRevision, 'policyRevision'),
       thresholdPercent = _positive(thresholdPercent, 'thresholdPercent') {
    _required(activityId, 'activityId');
    if (policyKind != CompletionPolicyKind.discoveryThreshold ||
        policyRevision != 1 ||
        thresholdPercent != 80 ||
        !committedAt.isUtc) {
      throw ArgumentError('Invalid spelling completion.');
    }
  }

  final SpellingProfileScope scope;
  final String activityId;
  final int contentRevision;
  final CompletionPolicyKind policyKind;
  final int policyRevision;
  final int thresholdPercent;
  final DateTime committedAt;
}

final class SpellingLearningState {
  SpellingLearningState({
    required this.scope,
    required int revision,
    required int commitOrdinal,
    required Map<String, SpellingSlot> slots,
    required List<SpellingAttempt> attempts,
    required List<SpellingReceipt> receipts,
    required Map<SpellingMistakeKey, SpellingMistake> mistakes,
    required Map<SpellingSummaryKey, SpellingSummary> summaries,
    required Map<SpellingExposureKey, SpellingExposure> exposures,
    required List<SpellingCompletion> completions,
  }) : revision = _counter(revision, 'revision'),
       commitOrdinal = _counter(commitOrdinal, 'commitOrdinal'),
       slots = Map<String, SpellingSlot>.unmodifiable(slots),
       attempts = List<SpellingAttempt>.unmodifiable(attempts),
       receipts = List<SpellingReceipt>.unmodifiable(receipts),
       mistakes = Map<SpellingMistakeKey, SpellingMistake>.unmodifiable(
         mistakes,
       ),
       summaries = Map<SpellingSummaryKey, SpellingSummary>.unmodifiable(
         summaries,
       ),
       exposures = Map<SpellingExposureKey, SpellingExposure>.unmodifiable(
         exposures,
       ),
       completions = List<SpellingCompletion>.unmodifiable(completions) {
    if (this.commitOrdinal > this.revision ||
        this.attempts.length > spellingMaxRetainedAttempts ||
        this.receipts.length > spellingMaxRetainedReceipts ||
        this.slots.length > 1 ||
        this.slots.keys.any((id) => id != 'en-fr-u-y-spelling') ||
        (this.commitOrdinal == 0) != this.slots.isEmpty ||
        (this.commitOrdinal == 0 &&
            (this.attempts.isNotEmpty ||
                this.receipts.isNotEmpty ||
                this.mistakes.isNotEmpty ||
                this.summaries.isNotEmpty ||
                this.exposures.isNotEmpty ||
                this.completions.isNotEmpty))) {
      throw ArgumentError('Invalid spelling state header.');
    }
    if (this.slots.entries.any(
          (entry) =>
              entry.key != entry.value.activityId ||
              entry.value.scope != scope ||
              entry.value.checkpoint.scope != scope ||
              entry.value.latestReceipt.scope != scope ||
              entry.value.latestReceipt.commitOrdinal > this.commitOrdinal,
        ) ||
        this.attempts.any((attempt) => attempt.scope != scope) ||
        this.receipts.any((receipt) => receipt.scope != scope) ||
        this.mistakes.entries.any(
          (entry) => entry.key != entry.value.key || entry.key.scope != scope,
        ) ||
        this.summaries.entries.any(
          (entry) => entry.key != entry.value.key || entry.key.scope != scope,
        ) ||
        this.exposures.entries.any(
          (entry) => entry.key != entry.value.key || entry.key.scope != scope,
        ) ||
        this.completions.any((completion) => completion.scope != scope)) {
      throw ArgumentError('Spelling state scope or identity mismatch.');
    }
    final attemptIds = <String>{};
    for (final attempt in this.attempts) {
      if (!attemptIds.add(
        '${attempt.activityId}:${attempt.generation}:${attempt.sequence}',
      )) {
        throw ArgumentError('Duplicate spelling attempt identity.');
      }
    }
    final receiptTokens = <String>{};
    final receiptSequences = <String>{};
    for (final receipt in this.receipts) {
      if (!receiptTokens.add(receipt.token) ||
          !receiptSequences.add(
            '${receipt.activityId}:${receipt.generation}:${receipt.sequence}',
          )) {
        throw ArgumentError('Duplicate spelling receipt identity.');
      }
    }
    final completionIds = <String>{};
    for (final completion in this.completions) {
      final id =
          '${completion.activityId}:${completion.contentRevision}:'
          '${completion.policyKind.name}:${completion.policyRevision}:'
          '${completion.thresholdPercent}';
      if (!completionIds.add(id)) {
        throw ArgumentError('Duplicate spelling completion identity.');
      }
    }
    if (this.receipts.isNotEmpty &&
        this.receipts.last.commitOrdinal != this.commitOrdinal) {
      throw ArgumentError('Latest spelling receipt must match commit ordinal.');
    }
    if (this.receipts.isNotEmpty) {
      final latestSlot = this.slots[this.receipts.last.activityId];
      if (latestSlot == null ||
          !_sameReceipt(this.receipts.last, latestSlot.latestReceipt)) {
        throw ArgumentError('Latest spelling receipt must match its slot.');
      }
    }
  }

  factory SpellingLearningState.empty(SpellingProfileScope scope) =>
      SpellingLearningState(
        scope: scope,
        revision: 0,
        commitOrdinal: 0,
        slots: const <String, SpellingSlot>{},
        attempts: const <SpellingAttempt>[],
        receipts: const <SpellingReceipt>[],
        mistakes: const <SpellingMistakeKey, SpellingMistake>{},
        summaries: const <SpellingSummaryKey, SpellingSummary>{},
        exposures: const <SpellingExposureKey, SpellingExposure>{},
        completions: const <SpellingCompletion>[],
      );

  final SpellingProfileScope scope;
  final int revision;
  final int commitOrdinal;
  final Map<String, SpellingSlot> slots;
  final List<SpellingAttempt> attempts;
  final List<SpellingReceipt> receipts;
  final Map<SpellingMistakeKey, SpellingMistake> mistakes;
  final Map<SpellingSummaryKey, SpellingSummary> summaries;
  final Map<SpellingExposureKey, SpellingExposure> exposures;
  final List<SpellingCompletion> completions;
}

bool _sameReceipt(SpellingReceipt left, SpellingReceipt right) =>
    left.scope == right.scope &&
    left.activityId == right.activityId &&
    left.generation == right.generation &&
    left.sequence == right.sequence &&
    left.token == right.token &&
    left.canonicalCommand == right.canonicalCommand &&
    left.before == right.before &&
    left.after == right.after &&
    left.commitOrdinal == right.commitOrdinal;
