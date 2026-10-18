import 'dart:convert';

import 'course_attempt.dart';
import 'course_audio_contract.dart';
import 'course_learning_transaction.dart';
import 'lesson_policy.dart';
import 'sentence_hunt_content.dart';

export 'course_attempt.dart' show LearningOwner, AttemptPresentation;

const int sentenceHuntMaxSafeInteger = 9007199254740991;
const int sentenceHuntMaxAttempts = 2000;
const int sentenceHuntMaxReceipts = 2000;
const int sentenceHuntMaxAggregateEntries = 4096;
const int sentenceHuntMaxSlots = 3;
const int sentenceHuntMaxDocumentBytes = 36 * 1024 * 1024;

final class SentenceHuntLearningLimits {
  const SentenceHuntLearningLimits({
    this.maxAttempts = sentenceHuntMaxAttempts,
    this.maxReceipts = sentenceHuntMaxReceipts,
    this.maxAggregateEntries = sentenceHuntMaxAggregateEntries,
    this.maxDocumentBytes = sentenceHuntMaxDocumentBytes,
  });

  final int maxAttempts;
  final int maxReceipts;
  final int maxAggregateEntries;
  final int maxDocumentBytes;

  void validate() {
    if (maxAttempts < 1 ||
        maxAttempts > sentenceHuntMaxAttempts ||
        maxReceipts < 1 ||
        maxReceipts > sentenceHuntMaxReceipts ||
        maxAggregateEntries < 1 ||
        maxAggregateEntries > sentenceHuntMaxAggregateEntries ||
        maxDocumentBytes < 1 ||
        maxDocumentBytes > sentenceHuntMaxDocumentBytes) {
      throw ArgumentError('Sentence-hunt limits must be positive and bounded.');
    }
  }
}

final class SentenceHuntUnavailableException implements Exception {
  const SentenceHuntUnavailableException([this.cause]);
  final Object? cause;
}

final class SentenceHuntCapacityException implements Exception {
  const SentenceHuntCapacityException(this.aggregate, this.limit);
  final String aggregate;
  final int limit;

  @override
  String toString() =>
      'SentenceHuntCapacityException($aggregate exceeds $limit entries)';
}

int sentenceHuntCounter(int value, String name) {
  if (value < 0 || value > sentenceHuntMaxSafeInteger) {
    throw ArgumentError.value(value, name, 'Out of supported range.');
  }
  return value;
}

int sentenceHuntPositive(int value, String name) {
  sentenceHuntCounter(value, name);
  if (value == 0) throw ArgumentError.value(value, name, 'Must be positive.');
  return value;
}

String sentenceHuntRequired(String value, String name) {
  if (value.trim().isEmpty) throw ArgumentError.value(value, name);
  return value;
}

void sentenceHuntUtc(DateTime value, String name) {
  if (!value.isUtc) throw ArgumentError.value(value, name, 'Must be UTC.');
}

Object? _freezeJson(Object? value) {
  if (value is Map) {
    if (value.keys.any((Object? key) => key is! String)) {
      throw ArgumentError('Snapshot map keys must be strings.');
    }
    return Map<String, Object?>.unmodifiable(<String, Object?>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        entry.key as String: _freezeJson(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(
        value.map<Object?>((Object? child) => _freezeJson(child)));
  }
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  throw ArgumentError('Snapshot must contain JSON values only.');
}

/// Profile identity for the isolated sentence-hunt learning document.
final class SentenceHuntProfileScope {
  SentenceHuntProfileScope({required this.courseId, required this.owner}) {
    if (courseId != 'en-fr') throw ArgumentError.value(courseId, 'courseId');
  }

  final String courseId;
  final LearningOwner owner;

  String get storageKey {
    String encode(String value) =>
        base64Url.encode(utf8.encode(value)).replaceAll('=', '');
    return 'course.learning.sentence-hunt.v1.${encode(courseId)}.'
        '${owner.isGuest ? 'g' : 'a.${encode(owner.userId!)}'}';
  }

  @override
  bool operator ==(Object other) =>
      other is SentenceHuntProfileScope &&
      courseId == other.courseId &&
      owner == other.owner;

  @override
  int get hashCode => Object.hash(courseId, owner);
}

enum SentenceHuntRunMode { practice, reviewOnly }

/// Durable identity for historical teaching exposure at a section revision.
final class SentenceHuntExposureKey {
  SentenceHuntExposureKey({
    required this.scope,
    required this.sectionId,
    required int contentRevision,
  }) : contentRevision =
            sentenceHuntPositive(contentRevision, 'contentRevision') {
    sentenceHuntRequired(sectionId, 'sectionId');
  }

  final SentenceHuntProfileScope scope;
  final String sectionId;
  final int contentRevision;

  @override
  bool operator ==(Object other) =>
      other is SentenceHuntExposureKey &&
      scope == other.scope &&
      sectionId == other.sectionId &&
      contentRevision == other.contentRevision;

  @override
  int get hashCode => Object.hash(scope, sectionId, contentRevision);
}

final class SentenceHuntPlaybackObservation {
  SentenceHuntPlaybackObservation({
    required this.scope,
    required this.content,
    required int runGeneration,
    required int round,
    required int uiGeneration,
    required this.referenceId,
    required this.outcome,
    required this.source,
  })  : runGeneration = sentenceHuntPositive(runGeneration, 'runGeneration'),
        round = sentenceHuntPositive(round, 'round'),
        uiGeneration = sentenceHuntCounter(uiGeneration, 'uiGeneration') {
    sentenceHuntRequired(referenceId, 'referenceId');
  }

  final SentenceHuntProfileScope scope;
  final SentenceHuntContentIdentity content;
  final int runGeneration;
  final int round;
  final int uiGeneration;
  final String referenceId;
  final CourseAudioOutcome outcome;
  final CourseAudioSource source;
}

/// Immutable section checkpoint; the nested session is an actual shared
/// LessonSectionSession JSON snapshot, never a live mutable session.
final class SentenceHuntCheckpoint {
  SentenceHuntCheckpoint({
    required this.scope,
    required this.sessionId,
    required this.sectionFingerprint,
    required int contentRevision,
    required this.mode,
    required this.finished,
    required this.policy,
    required Map<String, Object?> sessionJson,
    required int runStartRound,
  })  : contentRevision =
            sentenceHuntPositive(contentRevision, 'contentRevision'),
        runStartRound = sentenceHuntPositive(runStartRound, 'runStartRound'),
        sessionJson = _freezeJson(sessionJson) as Map<String, Object?> {
    sentenceHuntRequired(sessionId, 'sessionId');
    sentenceHuntRequired(sectionFingerprint, 'sectionFingerprint');
    final Object? savedPolicy = this.sessionJson['policy'];
    if (this.sessionJson['sessionId'] != sessionId ||
        this.sessionJson['contentRevision'] != contentRevision ||
        this.sessionJson['round'] != runStartRound &&
            (this.sessionJson['round'] is! int ||
                (this.sessionJson['round'] as int) < runStartRound) ||
        savedPolicy is! Map ||
        savedPolicy['completionThresholdPercent'] !=
            policy.completionThresholdPercent) {
      throw ArgumentError('Checkpoint metadata must match saved session.');
    }
  }

  final SentenceHuntProfileScope scope;
  final String sessionId;
  final String sectionFingerprint;
  final int contentRevision;
  final SentenceHuntRunMode mode;
  final bool finished;
  final LessonPolicy policy;
  final Map<String, Object?> sessionJson;

  /// First round number owned by this generation, needed to classify an
  /// already-reviewed carry-forward item as first-in-run after history trim.
  final int runStartRound;
}

final class SentenceHuntReceipt {
  SentenceHuntReceipt({
    required this.scope,
    required this.sectionId,
    required this.token,
    required this.canonicalCommand,
    required this.before,
    required this.after,
    required int commitOrdinal,
  }) : commitOrdinal = sentenceHuntPositive(commitOrdinal, 'commitOrdinal') {
    sentenceHuntRequired(sectionId, 'sectionId');
    if (!RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(token) ||
        canonicalCommand.trim().isEmpty ||
        !_reachableCursor(before, after)) {
      throw ArgumentError('Invalid sentence-hunt receipt.');
    }
  }

  final SentenceHuntProfileScope scope;
  final String sectionId;
  final String token;
  final String canonicalCommand;
  final LearningCursorPosition before;
  final LearningCursorPosition after;
  final int commitOrdinal;
  int get generation => after.generation;
  int get sequence => after.sequence;
}

bool _reachableCursor(
    LearningCursorPosition before, LearningCursorPosition after) {
  final values = <int>[
    before.generation,
    before.sequence,
    before.revision,
    after.generation,
    after.sequence,
    after.revision,
  ];
  if (values
      .any((int value) => value < 0 || value > sentenceHuntMaxSafeInteger)) {
    return false;
  }
  final bool initial = before.generation == 0 &&
      before.sequence == 0 &&
      before.revision == 0 &&
      after.generation == 1 &&
      after.sequence == 1 &&
      after.revision == 0;
  final bool continuation = before.generation > 0 &&
      after.generation == before.generation &&
      before.sequence < sentenceHuntMaxSafeInteger &&
      after.sequence == before.sequence + 1 &&
      before.revision < sentenceHuntMaxSafeInteger &&
      after.revision == before.revision + 1;
  final bool restart = before.generation > 0 &&
      before.generation < sentenceHuntMaxSafeInteger &&
      before.sequence < sentenceHuntMaxSafeInteger &&
      after.generation == before.generation + 1 &&
      after.sequence == before.sequence + 1 &&
      after.revision == 0;
  return initial || continuation || restart;
}

final class SentenceHuntSlot {
  SentenceHuntSlot({
    required this.sectionId,
    required this.checkpoint,
    required this.cursor,
    required this.latestReceipt,
  }) {
    if (sectionId != latestReceipt.sectionId ||
        checkpoint.scope != latestReceipt.scope ||
        cursor != latestReceipt.after) {
      throw ArgumentError('Inconsistent sentence-hunt slot.');
    }
  }

  final String sectionId;
  final SentenceHuntCheckpoint checkpoint;
  final LearningCursorPosition cursor;
  final SentenceHuntReceipt latestReceipt;
}

final class SentenceHuntAttempt {
  SentenceHuntAttempt({
    required this.scope,
    required this.content,
    required int runGeneration,
    required int round,
    required int sequence,
    required List<String> selectedTokenIds,
    required List<String> expectedTokenIds,
    required this.correct,
    required this.presentation,
    required this.teachingExposed,
    required this.playback,
    required this.answeredAt,
    required this.committedAt,
  })  : runGeneration = sentenceHuntPositive(runGeneration, 'runGeneration'),
        round = sentenceHuntPositive(round, 'round'),
        sequence = sentenceHuntPositive(sequence, 'sequence'),
        selectedTokenIds = List<String>.unmodifiable(selectedTokenIds),
        expectedTokenIds = List<String>.unmodifiable(expectedTokenIds) {
    sentenceHuntUtc(answeredAt, 'answeredAt');
    sentenceHuntUtc(committedAt, 'committedAt');
    if (this.selectedTokenIds.toSet().length != this.selectedTokenIds.length ||
        this.expectedTokenIds.toSet().length != this.expectedTokenIds.length ||
        this.selectedTokenIds.any((String id) => id.trim().isEmpty) ||
        this.expectedTokenIds.any((String id) => id.trim().isEmpty) ||
        correct !=
            _sameStringSet(this.selectedTokenIds, this.expectedTokenIds) ||
        playback.scope != scope ||
        playback.content != content ||
        playback.runGeneration != runGeneration ||
        playback.round != round) {
      throw ArgumentError('Invalid sentence-hunt attempt.');
    }
  }

  final SentenceHuntProfileScope scope;
  final SentenceHuntContentIdentity content;
  final int runGeneration;
  final int round;
  final int sequence;
  final List<String> selectedTokenIds;
  final List<String> expectedTokenIds;
  final bool correct;
  final AttemptPresentation presentation;
  final bool teachingExposed;
  final SentenceHuntPlaybackObservation playback;
  final DateTime answeredAt;
  final DateTime committedAt;
}

bool _sameStringSet(List<String> a, List<String> b) =>
    a.length == b.length && a.toSet().containsAll(b);

final class SentenceHuntMistakeKey {
  SentenceHuntMistakeKey({
    required this.scope,
    required this.content,
  });

  final SentenceHuntProfileScope scope;
  final SentenceHuntContentIdentity content;

  @override
  bool operator ==(Object other) =>
      other is SentenceHuntMistakeKey &&
      scope == other.scope &&
      content == other.content;

  @override
  int get hashCode => Object.hash(scope, content);
}

final class SentenceHuntMistake {
  SentenceHuntMistake({
    required this.key,
    required this.firstWrongAt,
    required this.latestWrongAt,
    required int failureCount,
  }) : failureCount = sentenceHuntPositive(failureCount, 'failureCount') {
    sentenceHuntUtc(firstWrongAt, 'firstWrongAt');
    sentenceHuntUtc(latestWrongAt, 'latestWrongAt');
    if (latestWrongAt.isBefore(firstWrongAt)) {
      throw ArgumentError('Latest wrong time precedes first wrong time.');
    }
  }

  final SentenceHuntMistakeKey key;
  final DateTime firstWrongAt;
  final DateTime latestWrongAt;
  final int failureCount;
  SentenceHuntProfileScope get scope => key.scope;
  SentenceHuntContentIdentity get content => key.content;
}

final class SentenceHuntCounts {
  SentenceHuntCounts({required this.correct, required this.total}) {
    sentenceHuntCounter(correct, 'correct');
    sentenceHuntCounter(total, 'total');
    if (correct > total) throw ArgumentError('Invalid sentence-hunt counts.');
  }

  final int correct;
  final int total;
}

final class SentenceHuntSummaryKey {
  SentenceHuntSummaryKey({required this.scope, required this.content});

  final SentenceHuntProfileScope scope;
  final SentenceHuntContentIdentity content;

  @override
  bool operator ==(Object other) =>
      other is SentenceHuntSummaryKey &&
      scope == other.scope &&
      content == other.content;

  @override
  int get hashCode => Object.hash(scope, content);
}

final class SentenceHuntSummary {
  SentenceHuntSummary({
    required this.key,
    required this.firstInRun,
    required this.repeatInRun,
    required this.firstTeachingExposed,
    required this.repeatTeachingExposed,
  }) {
    _requireSubset(firstTeachingExposed, firstInRun);
    _requireSubset(repeatTeachingExposed, repeatInRun);
  }

  final SentenceHuntSummaryKey key;
  final SentenceHuntCounts firstInRun;
  final SentenceHuntCounts repeatInRun;
  final SentenceHuntCounts firstTeachingExposed;
  final SentenceHuntCounts repeatTeachingExposed;
  SentenceHuntProfileScope get scope => key.scope;
  SentenceHuntContentIdentity get content => key.content;
}

void _requireSubset(SentenceHuntCounts subset, SentenceHuntCounts whole) {
  if (subset.total > whole.total ||
      subset.correct > whole.correct ||
      subset.total - subset.correct > whole.total - whole.correct) {
    throw ArgumentError('Exposure counts must be a subset of total counts.');
  }
}

final class SentenceHuntCompletion {
  SentenceHuntCompletion({
    required this.scope,
    required this.sectionId,
    required int contentRevision,
    required int policyRevision,
    required this.thresholdPercent,
    required this.committedAt,
  })  : contentRevision =
            sentenceHuntPositive(contentRevision, 'contentRevision'),
        policyRevision =
            sentenceHuntPositive(policyRevision, 'policyRevision') {
    sentenceHuntRequired(sectionId, 'sectionId');
    sentenceHuntUtc(committedAt, 'committedAt');
    if (thresholdPercent < 1 || thresholdPercent > 100) {
      throw ArgumentError.value(thresholdPercent, 'thresholdPercent');
    }
  }

  final SentenceHuntProfileScope scope;
  final String sectionId;
  final int contentRevision;
  final int policyRevision;
  final int thresholdPercent;
  final DateTime committedAt;

  @override
  bool operator ==(Object other) =>
      other is SentenceHuntCompletion &&
      scope == other.scope &&
      sectionId == other.sectionId &&
      contentRevision == other.contentRevision &&
      policyRevision == other.policyRevision &&
      thresholdPercent == other.thresholdPercent;

  @override
  int get hashCode => Object.hash(
        scope,
        sectionId,
        contentRevision,
        policyRevision,
        thresholdPercent,
      );
}

/// Atomic candidate state for the independent sentence-hunt family.
final class SentenceHuntLearningState {
  SentenceHuntLearningState({
    required this.scope,
    required int revision,
    required int commitOrdinal,
    required Map<String, SentenceHuntSlot> slots,
    required List<SentenceHuntAttempt> attempts,
    required List<SentenceHuntReceipt> receipts,
    required Map<SentenceHuntMistakeKey, SentenceHuntMistake> mistakes,
    required Map<SentenceHuntSummaryKey, SentenceHuntSummary> summaries,
    required List<SentenceHuntCompletion> completions,
    required Set<SentenceHuntExposureKey> teachingExposure,
  })  : revision = sentenceHuntCounter(revision, 'revision'),
        commitOrdinal = sentenceHuntCounter(commitOrdinal, 'commitOrdinal'),
        slots = Map<String, SentenceHuntSlot>.unmodifiable(slots),
        attempts = List<SentenceHuntAttempt>.unmodifiable(attempts),
        receipts = List<SentenceHuntReceipt>.unmodifiable(receipts),
        mistakes =
            Map<SentenceHuntMistakeKey, SentenceHuntMistake>.unmodifiable(
                mistakes),
        summaries =
            Map<SentenceHuntSummaryKey, SentenceHuntSummary>.unmodifiable(
                summaries),
        completions = List<SentenceHuntCompletion>.unmodifiable(completions),
        teachingExposure =
            Set<SentenceHuntExposureKey>.unmodifiable(teachingExposure),
        schemaVersion = 1 {
    if (commitOrdinal != revision ||
        attempts.length > sentenceHuntMaxAttempts ||
        receipts.length > sentenceHuntMaxReceipts ||
        slots.length > sentenceHuntMaxSlots ||
        mistakes.length > sentenceHuntMaxAggregateEntries ||
        summaries.length > sentenceHuntMaxAggregateEntries ||
        completions.length > sentenceHuntMaxAggregateEntries ||
        teachingExposure.length > sentenceHuntMaxAggregateEntries) {
      throw ArgumentError('Sentence-hunt state exceeds document bounds.');
    }
    if (slots.keys.any((String key) => key.trim().isEmpty) ||
        slots.entries.any((MapEntry<String, SentenceHuntSlot> entry) =>
            entry.key != entry.value.sectionId ||
            entry.value.checkpoint.scope != scope) ||
        attempts.any((SentenceHuntAttempt attempt) => attempt.scope != scope) ||
        receipts.any((SentenceHuntReceipt receipt) => receipt.scope != scope) ||
        mistakes.entries.any(
            (MapEntry<SentenceHuntMistakeKey, SentenceHuntMistake> entry) =>
                entry.key != entry.value.key || entry.key.scope != scope) ||
        summaries.entries.any(
            (MapEntry<SentenceHuntSummaryKey, SentenceHuntSummary> entry) =>
                entry.key != entry.value.key || entry.key.scope != scope) ||
        completions.any(
            (SentenceHuntCompletion completion) => completion.scope != scope) ||
        teachingExposure
            .any((SentenceHuntExposureKey key) => key.scope != scope)) {
      throw ArgumentError('Sentence-hunt state scope mismatch.');
    }
    if (commitOrdinal == 0 &&
        (slots.isNotEmpty ||
            attempts.isNotEmpty ||
            receipts.isNotEmpty ||
            mistakes.isNotEmpty ||
            summaries.isNotEmpty ||
            completions.isNotEmpty ||
            teachingExposure.isNotEmpty)) {
      throw ArgumentError('Uncommitted sentence-hunt state has evidence.');
    }

    final Set<String> attemptIds = <String>{};
    for (final SentenceHuntAttempt attempt in this.attempts) {
      final String id =
          '${attempt.content.sectionId}:${attempt.runGeneration}:${attempt.sequence}';
      if (!attemptIds.add(id)) throw ArgumentError('Duplicate attempt.');
    }
    final Set<String> receiptIds = <String>{};
    final Set<String> receiptTokens = <String>{};
    var priorOrdinal = 0;
    for (final SentenceHuntReceipt receipt in this.receipts) {
      final String id =
          '${receipt.sectionId}:${receipt.after.generation}:${receipt.after.sequence}';
      if (!receiptIds.add(id) ||
          !receiptTokens.add(receipt.token) ||
          receipt.commitOrdinal <= priorOrdinal ||
          receipt.commitOrdinal > commitOrdinal) {
        throw ArgumentError('Duplicate or out-of-order receipt.');
      }
      priorOrdinal = receipt.commitOrdinal;
    }
    if (this.mistakes.keys.toSet().length != this.mistakes.length ||
        this.summaries.keys.toSet().length != this.summaries.length ||
        this.completions.toSet().length != this.completions.length) {
      throw ArgumentError('Duplicate sentence-hunt aggregate identity.');
    }
    for (final MapEntry<String, SentenceHuntSlot> entry in this.slots.entries) {
      final SentenceHuntReceipt latest = entry.value.latestReceipt;
      if (entry.key != latest.sectionId ||
          latest.commitOrdinal > commitOrdinal) {
        throw ArgumentError('Slot receipt exceeds document commit ordinal.');
      }
      final SentenceHuntReceipt? retained = this
          .receipts
          .where((SentenceHuntReceipt receipt) =>
              receipt.sectionId == entry.key &&
              receipt.after == entry.value.cursor)
          .firstOrNull;
      if (retained != null && !_sameReceipt(retained, latest)) {
        throw ArgumentError('Slot receipt differs from retained receipt.');
      }
    }
    for (final SentenceHuntAttempt attempt in this.attempts) {
      if (attempt.sequence > commitOrdinal) {
        throw ArgumentError('Attempt sequence exceeds document history.');
      }
    }
  }

  factory SentenceHuntLearningState.empty(SentenceHuntProfileScope scope) =>
      SentenceHuntLearningState(
        scope: scope,
        revision: 0,
        commitOrdinal: 0,
        slots: const <String, SentenceHuntSlot>{},
        attempts: const <SentenceHuntAttempt>[],
        receipts: const <SentenceHuntReceipt>[],
        mistakes: const <SentenceHuntMistakeKey, SentenceHuntMistake>{},
        summaries: const <SentenceHuntSummaryKey, SentenceHuntSummary>{},
        completions: const <SentenceHuntCompletion>[],
        teachingExposure: const <SentenceHuntExposureKey>{},
      );

  final int schemaVersion;
  final SentenceHuntProfileScope scope;
  final int revision;
  final int commitOrdinal;
  final Map<String, SentenceHuntSlot> slots;
  final List<SentenceHuntAttempt> attempts;
  final List<SentenceHuntReceipt> receipts;
  final Map<SentenceHuntMistakeKey, SentenceHuntMistake> mistakes;
  final Map<SentenceHuntSummaryKey, SentenceHuntSummary> summaries;
  final List<SentenceHuntCompletion> completions;
  final Set<SentenceHuntExposureKey> teachingExposure;
}

bool _sameReceipt(SentenceHuntReceipt a, SentenceHuntReceipt b) =>
    a.scope == b.scope &&
    a.sectionId == b.sectionId &&
    a.token == b.token &&
    a.canonicalCommand == b.canonicalCommand &&
    a.before == b.before &&
    a.after == b.after &&
    a.commitOrdinal == b.commitOrdinal;

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
