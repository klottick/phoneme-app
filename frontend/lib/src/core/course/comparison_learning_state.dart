import 'dart:convert';

import 'course_attempt.dart';
import 'comparison_content.dart';
import 'course_audio_contract.dart';
import 'lesson_policy.dart';

export 'course_attempt.dart' show LearningOwner, AttemptPresentation;

const int comparisonMaxSafeInteger = 9007199254740991;

int comparisonCounter(int value, String name) {
  if (value < 0 || value > comparisonMaxSafeInteger) {
    throw ArgumentError.value(value, name);
  }
  return value;
}

int comparisonPositive(int value, String name) {
  comparisonCounter(value, name);
  if (value == 0) throw ArgumentError.value(value, name, 'Must be positive.');
  return value;
}

bool comparisonUtc(DateTime value, String name) {
  if (!value.isUtc) throw ArgumentError.value(value, name, 'Must be UTC.');
  return true;
}

Object? _freezeJson(Object? value) {
  if (value is Map) {
    if (value.keys.any((key) => key is! String)) {
      throw ArgumentError('Snapshot map keys must be strings.');
    }
    return Map<String, Object?>.unmodifiable(
        {for (final e in value.entries) e.key as String: _freezeJson(e.value)});
  }
  if (value is List) return List.unmodifiable(value.map(_freezeJson));
  return value;
}

String comparisonRequired(String value, String name) {
  if (value.trim().isEmpty) throw ArgumentError.value(value, name);
  return value;
}

final class ComparisonProfileScope {
  ComparisonProfileScope({required this.courseId, required this.owner}) {
    if (courseId != 'en-fr') throw ArgumentError.value(courseId, 'courseId');
  }
  final String courseId;
  final LearningOwner owner;
  String get storageKey {
    String enc(String s) =>
        base64Url.encode(utf8.encode(s)).replaceAll('=', '');
    return 'course.learning.comparison.v1.${enc(courseId)}.${owner.isGuest ? 'g' : 'a.${enc(owner.userId!)}'}';
  }

  @override
  bool operator ==(Object other) =>
      other is ComparisonProfileScope &&
      courseId == other.courseId &&
      owner == other.owner;
  @override
  int get hashCode => Object.hash(courseId, owner);
}

final class ComparisonCursor {
  ComparisonCursor(
      {required this.generation,
      required this.sequence,
      required this.revision}) {
    comparisonCounter(generation, 'generation');
    comparisonCounter(sequence, 'sequence');
    comparisonCounter(revision, 'revision');
  }
  final int generation, sequence, revision;
  @override
  bool operator ==(Object other) =>
      other is ComparisonCursor &&
      generation == other.generation &&
      sequence == other.sequence &&
      revision == other.revision;
  @override
  int get hashCode => Object.hash(generation, sequence, revision);
}

final class ComparisonReceipt {
  ComparisonReceipt(
      {required this.scope,
      required this.activityId,
      required this.generation,
      required this.sequence,
      required this.token,
      required this.canonicalCommand,
      required this.before,
      required this.after,
      required this.commitOrdinal}) {
    comparisonRequired(activityId, 'activityId');
    comparisonCounter(generation, 'generation');
    comparisonCounter(sequence, 'sequence');
    comparisonCounter(commitOrdinal, 'commitOrdinal');
    comparisonPositive(generation, 'generation');
    comparisonPositive(sequence, 'sequence');
    comparisonPositive(commitOrdinal, 'commitOrdinal');
    final initial = before.generation == 0 &&
        before.sequence == 0 &&
        before.revision == 0 &&
        after.generation == 1 &&
        after.sequence == 1 &&
        after.revision == 0;
    final continuation = before.generation > 0 &&
        after.generation == before.generation &&
        after.sequence == before.sequence + 1 &&
        after.revision == before.revision + 1;
    final restart = before.generation > 0 &&
        after.generation == before.generation + 1 &&
        after.sequence == before.sequence + 1 &&
        after.revision == 0;
    if (!RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(token) ||
        canonicalCommand.trim().isEmpty ||
        !(initial || continuation || restart) ||
        generation != after.generation ||
        sequence != after.sequence) {
      throw ArgumentError('Invalid receipt');
    }
  }
  final ComparisonProfileScope scope;
  final String activityId, token, canonicalCommand;
  final int generation, sequence, commitOrdinal;
  final ComparisonCursor before, after;
}

final class ComparisonCheckpoint {
  ComparisonCheckpoint(
      {required this.scope,
      required this.sessionId,
      required this.contentRevision,
      required this.policy,
      required Map<String, Object?> sessionJson})
      : sessionJson = _freezeJson(sessionJson) as Map<String, Object?> {
    comparisonRequired(sessionId, 'sessionId');
    comparisonPositive(contentRevision, 'contentRevision');
    if (contentRevision < 1 ||
        policy.completionThresholdPercent < 1 ||
        policy.completionThresholdPercent > 100) {
      throw ArgumentError('Invalid checkpoint metadata');
    }
    final savedPolicy = this.sessionJson['policy'];
    if (this.sessionJson['sessionId'] != sessionId ||
        this.sessionJson['contentRevision'] != contentRevision ||
        savedPolicy is! Map ||
        savedPolicy['completionThresholdPercent'] !=
            policy.completionThresholdPercent) {
      throw ArgumentError('Checkpoint metadata must match saved session.');
    }
  }
  final ComparisonProfileScope scope;
  final String sessionId;
  final int contentRevision;
  final LessonPolicy policy;
  final Map<String, Object?> sessionJson;
}

final class ComparisonSlot {
  ComparisonSlot(
      {required this.scope,
      required this.activityId,
      required this.cursor,
      required this.checkpoint,
      required this.latestReceipt}) {
    if (scope != checkpoint.scope ||
        scope != latestReceipt.scope ||
        activityId != latestReceipt.activityId ||
        cursor != latestReceipt.after) {
      throw ArgumentError('Inconsistent comparison slot');
    }
  }
  final ComparisonProfileScope scope;
  final String activityId;
  final ComparisonCursor cursor;
  final ComparisonCheckpoint checkpoint;
  final ComparisonReceipt latestReceipt;
}

final class ComparisonPairMistakeKey {
  ComparisonPairMistakeKey(
      {required this.scope,
      required this.activityId,
      required this.pairId,
      required this.contentRevision}) {
    comparisonRequired(activityId, 'activityId');
    comparisonRequired(pairId, 'pairId');
    comparisonPositive(contentRevision, 'contentRevision');
  }
  final ComparisonProfileScope scope;
  final String activityId, pairId;
  final int contentRevision;
  @override
  bool operator ==(Object other) =>
      other is ComparisonPairMistakeKey &&
      scope == other.scope &&
      activityId == other.activityId &&
      pairId == other.pairId &&
      contentRevision == other.contentRevision;
  @override
  int get hashCode => Object.hash(scope, activityId, pairId, contentRevision);
}

final class ComparisonPairMistake {
  ComparisonPairMistake(
      {required this.scope,
      required this.key,
      required this.firstWrongAt,
      required this.latestWrongAt,
      required int failureCount})
      : failureCount = comparisonPositive(failureCount, 'failureCount') {
    if (scope != key.scope ||
        !firstWrongAt.isUtc ||
        !latestWrongAt.isUtc ||
        latestWrongAt.isBefore(firstWrongAt)) {
      throw ArgumentError('Invalid comparison mistake');
    }
  }
  final ComparisonProfileScope scope;
  final ComparisonPairMistakeKey key;
  final DateTime firstWrongAt, latestWrongAt;
  final int failureCount;
}

final class ComparisonSummaryKey {
  ComparisonSummaryKey(
      {required this.scope,
      required this.activityId,
      required this.pairId,
      required int contentRevision})
      : contentRevision =
            comparisonPositive(contentRevision, 'contentRevision') {
    comparisonRequired(activityId, 'activityId');
    comparisonRequired(pairId, 'pairId');
  }
  final ComparisonProfileScope scope;
  final String activityId, pairId;
  final int contentRevision;
  @override
  bool operator ==(Object other) =>
      other is ComparisonSummaryKey &&
      scope == other.scope &&
      activityId == other.activityId &&
      pairId == other.pairId &&
      contentRevision == other.contentRevision;
  @override
  int get hashCode => Object.hash(scope, activityId, pairId, contentRevision);
}

final class ComparisonCount {
  ComparisonCount({required this.correct, required this.total}) {
    comparisonCounter(correct, 'correct');
    comparisonCounter(total, 'total');
    if (correct > total) throw ArgumentError('Invalid comparison count');
  }
  final int correct, total;
}

final class ComparisonPairSummary {
  ComparisonPairSummary(
      {required this.key,
      required this.firstInRun,
      required this.repeatInRun,
      required this.afterDebrief}) {
    if (afterDebrief.total > firstInRun.total + repeatInRun.total ||
        afterDebrief.correct > firstInRun.correct + repeatInRun.correct ||
        afterDebrief.total - afterDebrief.correct >
            firstInRun.total -
                firstInRun.correct +
                repeatInRun.total -
                repeatInRun.correct) {
      throw ArgumentError('Invalid after-debrief subset');
    }
  }
  final ComparisonSummaryKey key;
  final ComparisonCount firstInRun, repeatInRun, afterDebrief;
}

final class ComparisonCompletion {
  ComparisonCompletion(
      {required this.scope,
      required this.activityId,
      required this.contentRevision,
      required this.policyRevision,
      required this.thresholdPercent,
      required this.committedAt}) {
    comparisonRequired(activityId, 'activityId');
    comparisonPositive(contentRevision, 'contentRevision');
    if (policyRevision != 1 ||
        thresholdPercent < 1 ||
        thresholdPercent > 100 ||
        !committedAt.isUtc) {
      throw ArgumentError('Invalid completion');
    }
  }
  final ComparisonProfileScope scope;
  final String activityId;
  final int contentRevision, policyRevision, thresholdPercent;
  final DateTime committedAt;
}

final class ComparisonPlaybackObservation {
  const ComparisonPlaybackObservation(
      {required this.slot,
      required this.referenceId,
      required this.outcome,
      required this.source,
      required this.activityId,
      required this.runGeneration,
      required this.round,
      required this.pairId,
      required this.profile,
      required this.uiGeneration});
  final ComparisonSample slot;
  final String referenceId, activityId, pairId;
  final CourseAudioOutcome outcome;
  final CourseAudioSource? source;
  final int runGeneration, round, uiGeneration;
  final ComparisonProfileScope profile;
}

final class ComparisonPairAttempt {
  ComparisonPairAttempt(
      {required this.scope,
      required this.activityId,
      required this.pairId,
      required this.contentRevision,
      required this.runGeneration,
      required this.round,
      required this.sequence,
      required this.selectedRelation,
      required this.expectedRelation,
      required this.correct,
      required this.presentation,
      required this.afterDebrief,
      required List<ComparisonPlaybackObservation> observations,
      required this.answeredAt,
      required this.committedAt})
      : observations = List.unmodifiable(observations) {
    comparisonRequired(activityId, 'activityId');
    comparisonRequired(pairId, 'pairId');
    comparisonPositive(contentRevision, 'contentRevision');
    comparisonPositive(runGeneration, 'runGeneration');
    comparisonPositive(round, 'round');
    comparisonPositive(sequence, 'sequence');
    if (correct != (selectedRelation == expectedRelation) ||
        observations.length != 2 ||
        observations[0].slot != ComparisonSample.a ||
        observations[1].slot != ComparisonSample.b ||
        !answeredAt.isUtc ||
        !committedAt.isUtc) {
      throw ArgumentError('Invalid pair attempt');
    }
    for (final o in observations) {
      comparisonRequired(o.referenceId, 'referenceId');
      comparisonCounter(o.uiGeneration, 'uiGeneration');
      if (o.outcome != CourseAudioOutcome.completed ||
          o.source != CourseAudioSource.unverifiedRecording ||
          o.profile != scope ||
          o.activityId != activityId ||
          o.pairId != pairId ||
          o.runGeneration != runGeneration ||
          o.round != round ||
          o.uiGeneration != observations.first.uiGeneration) {
        throw ArgumentError('Invalid pair provenance');
      }
    }
  }
  final ComparisonProfileScope scope;
  final String activityId, pairId;
  final int contentRevision, runGeneration, round, sequence;
  final PhonemeRelation selectedRelation, expectedRelation;
  final bool correct, afterDebrief;
  final AttemptPresentation presentation;
  final List<ComparisonPlaybackObservation> observations;
  final DateTime answeredAt, committedAt;
}

final class ComparisonLearningState {
  ComparisonLearningState(
      {required this.scope,
      required this.revision,
      required this.commitOrdinal,
      required this.slot,
      required List<ComparisonPairAttempt> attempts,
      required List<ComparisonReceipt> receipts,
      required Map<ComparisonPairMistakeKey, ComparisonPairMistake> mistakes,
      required Map<ComparisonSummaryKey, ComparisonPairSummary> summaries,
      required List<ComparisonCompletion> completions})
      : attempts = List.unmodifiable(attempts),
        receipts = List.unmodifiable(receipts),
        mistakes = Map.unmodifiable(mistakes),
        summaries = Map.unmodifiable(summaries),
        completions = List.unmodifiable(completions),
        schemaVersion = 1 {
    comparisonCounter(revision, 'revision');
    comparisonCounter(commitOrdinal, 'commitOrdinal');
    if (commitOrdinal > revision ||
        attempts.length > 2000 ||
        receipts.length > 2000 ||
        (commitOrdinal == 0) != (slot == null)) {
      throw ArgumentError('Invalid comparison state header');
    }
    final tokens = <String>{};
    final sequences = <String>{};
    final attemptIds = <String>{};
    final completionIds = <String>{};
    if (this.receipts.any((r) =>
            !tokens.add(r.token) ||
            !sequences.add('${r.activityId}:${r.generation}:${r.sequence}')) ||
        this.attempts.toSet().length != this.attempts.length ||
        this.mistakes.entries.any((e) => e.key != e.value.key) ||
        this.summaries.entries.any((e) => e.key != e.value.key) ||
        this.completions.toSet().length != this.completions.length ||
        (slot != null &&
            (slot!.scope != scope ||
                slot!.latestReceipt.after != slot!.cursor ||
                slot!.latestReceipt.commitOrdinal > commitOrdinal)) ||
        this.attempts.any((x) => x.scope != scope) ||
        this.receipts.any((x) => x.scope != scope) ||
        this.mistakes.values.any((x) => x.scope != scope) ||
        this.summaries.keys.any((x) => x.scope != scope) ||
        this
            .completions
            .any((x) => x.scope != scope || x.committedAt.isUtc == false)) {
      throw ArgumentError('Comparison state scope mismatch');
    }
    for (final attempt in this.attempts) {
      final identity =
          '${attempt.activityId}:${attempt.runGeneration}:${attempt.sequence}';
      if (!attemptIds.add(identity)) {
        throw ArgumentError('Duplicate attempt identity');
      }
    }
    for (final completion in this.completions) {
      final identity =
          '${completion.activityId}:${completion.contentRevision}:${completion.policyRevision}:${completion.thresholdPercent}';
      if (!completionIds.add(identity)) {
        throw ArgumentError('Duplicate completion identity');
      }
    }
    if (this.receipts.isNotEmpty &&
        this.receipts.last.commitOrdinal != commitOrdinal) {
      throw ArgumentError(
          'Latest receipt ordinal must equal state commit ordinal.');
    }
    if (slot != null && slot!.latestReceipt.commitOrdinal != commitOrdinal) {
      throw ArgumentError('Slot latest receipt must be the current commit.');
    }
    if (slot != null &&
        this.receipts.isNotEmpty &&
        (this.receipts.last.token != slot!.latestReceipt.token ||
            this.receipts.last.canonicalCommand !=
                slot!.latestReceipt.canonicalCommand)) {
      throw ArgumentError(
          'Latest receipt must match the retained receipt tail.');
    }
    final receiptsBySequence = <String, ComparisonReceipt>{
      for (final receipt in this.receipts)
        '${receipt.activityId}:${receipt.generation}:${receipt.sequence}':
            receipt
    };
    if (this.attempts.any((attempt) {
      final receipt = receiptsBySequence[
          '${attempt.activityId}:${attempt.runGeneration}:${attempt.sequence}'];
      return receipt != null && receipt.commitOrdinal < attempt.sequence;
    })) {
      throw ArgumentError('Available attempt/receipt link is inconsistent.');
    }
  }
  factory ComparisonLearningState.empty(ComparisonProfileScope scope) =>
      ComparisonLearningState(
          scope: scope,
          revision: 0,
          commitOrdinal: 0,
          slot: null,
          attempts: const [],
          receipts: const [],
          mistakes: const {},
          summaries: const {},
          completions: const []);
  final int schemaVersion;
  final ComparisonProfileScope scope;
  final int revision, commitOrdinal;
  final ComparisonSlot? slot;
  ComparisonCheckpoint? get checkpoint => slot?.checkpoint;
  final List<ComparisonPairAttempt> attempts;
  final List<ComparisonReceipt> receipts;
  final Map<ComparisonPairMistakeKey, ComparisonPairMistake> mistakes;
  final Map<ComparisonSummaryKey, ComparisonPairSummary> summaries;
  final List<ComparisonCompletion> completions;
}
