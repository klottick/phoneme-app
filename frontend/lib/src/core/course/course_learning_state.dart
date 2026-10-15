import 'course_attempt.dart';
import 'course_learning_checkpoint.dart';
import 'course_skill_summary.dart';
import 'lesson_policy.dart';

const int _maxSafeInteger = 9007199254740991;

int _count(int value, String name,
    {int minimum = 0, int maximum = _maxSafeInteger}) {
  if (value < minimum || value > maximum) {
    throw ArgumentError.value(value, name, 'Out of supported range.');
  }
  return value;
}

String _nonblank(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be blank.');
  }
  return value;
}

String _validToken(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(value)) {
    throw ArgumentError.value(
        value, 'token', 'Must be a 22-character base64url token.');
  }
  return value;
}

class SlotCursor {
  SlotCursor(
      {required this.generation,
      required this.sequence,
      required this.revision}) {
    _count(generation, 'generation');
    _count(sequence, 'sequence');
    _count(revision, 'revision');
  }
  final int generation, sequence, revision;
}

class ItemExposure {
  ItemExposure(
      {required int presentations, required Set<AssistanceFlag> assistance})
      : presentations = _count(presentations, 'presentations'),
        assistance = Set.unmodifiable(assistance);
  final int presentations;
  final Set<AssistanceFlag> assistance;
}

class ItemContextKey {
  ItemContextKey({required String itemId, required String targetSound})
      : itemId = _nonblank(itemId, 'itemId'),
        targetSound = _nonblank(targetSound, 'targetSound');
  final String itemId, targetSound;
  @override
  bool operator ==(Object other) =>
      other is ItemContextKey &&
      itemId == other.itemId &&
      targetSound == other.targetSound;
  @override
  int get hashCode => Object.hash(itemId, targetSound);
}

class RunOptions {
  RunOptions({LessonPolicy? policy}) : policy = policy ?? LessonPolicy();
  final LessonPolicy policy;
}

class CommandReceipt {
  CommandReceipt(
      {required this.token,
      required this.canonicalCommand,
      required this.before,
      required this.after,
      required this.commitOrdinal}) {
    _validToken(token);
    _nonblank(canonicalCommand, 'canonicalCommand');
    _count(commitOrdinal, 'commitOrdinal', minimum: 1);
  }
  final String token, canonicalCommand;
  final SlotCursor before, after;
  final int commitOrdinal;
}

class ActivitySlot {
  ActivitySlot(
      {required String activityId,
      required this.kind,
      required int contentRevision,
      required this.cursor,
      required this.options,
      required this.snapshot,
      required Map<ItemContextKey, ItemExposure> exposures,
      required this.latestReceipt})
      : activityId = _nonblank(activityId, 'activityId'),
        contentRevision =
            _count(contentRevision, 'contentRevision', minimum: 1),
        exposures = Map.unmodifiable(exposures) {
    final snapshotMatchesKind = switch (kind) {
      LearningActivityKind.discovery => snapshot is DiscoveryCheckpoint,
      LearningActivityKind.legacyLesson => snapshot is LegacyLessonCheckpoint,
      LearningActivityKind.drill => snapshot is DrillCheckpoint,
      LearningActivityKind.soundGame => snapshot is SoundGameCheckpoint,
      LearningActivityKind.wordGame => snapshot is WordGameCheckpoint,
    };
    if (!snapshotMatchesKind ||
        cursor.generation < 0 ||
        cursor.sequence < 0 ||
        cursor.revision < 0 ||
        cursor.generation > _maxSafeInteger ||
        cursor.sequence > _maxSafeInteger ||
        cursor.revision > _maxSafeInteger ||
        !RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(latestReceipt.token) ||
        latestReceipt.canonicalCommand.trim().isEmpty ||
        latestReceipt.commitOrdinal < 1 ||
        latestReceipt.commitOrdinal > _maxSafeInteger ||
        latestReceipt.after.generation != latestReceipt.before.generation ||
        latestReceipt.after.sequence != latestReceipt.before.sequence + 1 ||
        latestReceipt.after.revision != latestReceipt.before.revision + 1 ||
        latestReceipt.after.generation != cursor.generation ||
        latestReceipt.after.sequence != cursor.sequence ||
        latestReceipt.after.revision != cursor.revision ||
        exposures.keys.any((key) =>
            key.itemId.trim().isEmpty || key.targetSound.trim().isEmpty)) {
      throw ArgumentError(
          'Activity slot cursor/receipt or exposure identity is inconsistent.');
    }
  }
  final String activityId;
  final LearningActivityKind kind;
  final int contentRevision;
  final SlotCursor cursor;
  final RunOptions options;
  final ActivitySnapshot snapshot;
  final Map<ItemContextKey, ItemExposure> exposures;
  final CommandReceipt latestReceipt;
}

class AttemptBatch {
  AttemptBatch(
      {required String activityId,
      required int generation,
      required int sequence,
      required String token,
      required String canonicalCommand,
      required List<CourseAttempt> attempts})
      : activityId = _nonblank(activityId, 'activityId'),
        generation = _count(generation, 'generation', minimum: 1),
        sequence = _count(sequence, 'sequence', minimum: 1),
        token = _validToken(token),
        canonicalCommand = _nonblank(canonicalCommand, 'canonicalCommand'),
        attempts = List.unmodifiable(attempts) {
    if (attempts.isEmpty) {
      throw ArgumentError.value(attempts, 'attempts');
    }
    if (attempts.asMap().entries.any((entry) =>
        entry.value.activityId != this.activityId ||
        entry.value.runGeneration != this.generation ||
        entry.value.commandSequence != this.sequence ||
        entry.value.batchIndex != entry.key)) {
      throw ArgumentError(
          'Batch attempts must match activity, generation, sequence and member index.');
    }
  }
  final String activityId, token, canonicalCommand;
  final int generation, sequence;
  final List<CourseAttempt> attempts;
}

class MistakeKey {
  MistakeKey(
      {required String activityId,
      required String itemId,
      required int contentRevision,
      required this.skill,
      required String targetSound})
      : activityId = _nonblank(activityId, 'activityId'),
        itemId = _nonblank(itemId, 'itemId'),
        contentRevision =
            _count(contentRevision, 'contentRevision', minimum: 1),
        targetSound = _nonblank(targetSound, 'targetSound');
  final String activityId, itemId, targetSound;
  final int contentRevision;
  final LearningSkill skill;
  @override
  bool operator ==(Object other) =>
      other is MistakeKey &&
      activityId == other.activityId &&
      itemId == other.itemId &&
      contentRevision == other.contentRevision &&
      skill == other.skill &&
      targetSound == other.targetSound;
  @override
  int get hashCode =>
      Object.hash(activityId, itemId, contentRevision, skill, targetSound);
}

class LearningMistake {
  LearningMistake(
      {required this.key,
      required String firstWrongId,
      required this.firstWrongAt,
      required String latestWrongId,
      required this.latestWrongAt,
      required int failureCount,
      required int lastRunGeneration})
      : firstWrongId = _nonblank(firstWrongId, 'firstWrongId'),
        latestWrongId = _nonblank(latestWrongId, 'latestWrongId'),
        failureCount = _count(failureCount, 'failureCount', minimum: 1),
        lastRunGeneration =
            _count(lastRunGeneration, 'lastRunGeneration', minimum: 1) {
    if (latestWrongAt.isBefore(firstWrongAt)) {
      throw ArgumentError('latestWrongAt precedes firstWrongAt.');
    }
  }
  final MistakeKey key;
  final String firstWrongId, latestWrongId;
  final DateTime firstWrongAt, latestWrongAt;
  final int failureCount, lastRunGeneration;
}

class LearningCompletion {
  LearningCompletion(
      {required String lessonId,
      required int contentRevision,
      required this.policyKind,
      required int policyRevision,
      required int? thresholdPercent,
      required this.committedAt})
      : lessonId = _nonblank(lessonId, 'lessonId'),
        contentRevision =
            _count(contentRevision, 'contentRevision', minimum: 1),
        policyRevision = _count(policyRevision, 'policyRevision', minimum: 1),
        thresholdPercent = thresholdPercent == null
            ? null
            : _count(thresholdPercent, 'thresholdPercent', maximum: 100) {
    if ((policyKind == CompletionPolicyKind.legacyOnePass) !=
        (thresholdPercent == null)) {
      throw ArgumentError(
          'Threshold must be present only for discovery completion.');
    }
  }
  final String lessonId;
  final int contentRevision;
  final CompletionPolicyKind policyKind;
  final int policyRevision;
  final int? thresholdPercent;
  final DateTime committedAt;
}

sealed class SupportedCloudPayload {
  const SupportedCloudPayload();
}

class CloudAnswer extends SupportedCloudPayload {
  CloudAnswer(
      {required String sound,
      required this.skill,
      required this.correct,
      required String activity})
      : sound = _nonblank(sound, 'sound'),
        activity = _nonblank(activity, 'activity');
  final String sound, activity;
  final LearningSkill skill;
  final bool correct;
}

class CloudLesson extends SupportedCloudPayload {
  CloudLesson({required String lessonId})
      : lessonId = _nonblank(lessonId, 'lessonId');
  final String lessonId;
}

class CloudScore extends SupportedCloudPayload {
  CloudScore({required String game, required int score})
      : game = _nonblank(game, 'game'),
        score = _count(score, 'score');
  final String game;
  final int score;
}

class SupportedCloudEvent {
  SupportedCloudEvent(
      {required String id,
      required String userId,
      required String courseId,
      required this.payload})
      : id = _nonblank(id, 'id'),
        userId = _nonblank(userId, 'userId'),
        courseId = _nonblank(courseId, 'courseId');
  // Cloud event identity is deliberately kept independent of raw payload text.
  // State construction validates it against the containing owner and course.
  final String id, userId, courseId;
  final SupportedCloudPayload payload;
}

class CourseLearningState {
  CourseLearningState(
      {this.schemaVersion = 2,
      required this.scope,
      required int revision,
      required int commitOrdinal,
      required List<AttemptBatch> history,
      required Map<String, ActivitySlot> activities,
      required Map<MistakeKey, LearningMistake> mistakes,
      required Map<SummaryKey, SkillCount> summaries,
      required List<LearningCompletion> completions,
      required Map<String, int> bestScores,
      required List<SupportedCloudEvent> pending})
      : revision = _count(revision, 'revision'),
        commitOrdinal = _count(commitOrdinal, 'commitOrdinal'),
        history = List.unmodifiable(history),
        activities = Map.unmodifiable(activities),
        mistakes = Map.unmodifiable(mistakes),
        summaries = Map.unmodifiable(summaries),
        completions = List.unmodifiable(completions),
        bestScores = Map.unmodifiable(bestScores),
        pending = List.unmodifiable(pending) {
    if (schemaVersion != 2 || commitOrdinal > revision) {
      throw ArgumentError('Invalid learning state header');
    }
    for (final batch in this.history) {
      if (batch.attempts.any((attempt) =>
          attempt.scope != scope || attempt.commitOrdinal > commitOrdinal)) {
        throw ArgumentError(
            'History attempt scope/ordinal is inconsistent with state.');
      }
    }
    if (this.activities.entries.any((entry) =>
        entry.key != entry.value.activityId ||
        entry.value.latestReceipt.commitOrdinal > commitOrdinal)) {
      throw ArgumentError(
          'Activity map key/receipt ordinal is inconsistent with state.');
    }
    if (this.mistakes.entries.any((entry) => entry.key != entry.value.key)) {
      throw ArgumentError('Mistake map key is inconsistent with its record.');
    }
    if (this.bestScores.entries.any((entry) =>
            entry.key.trim().isEmpty ||
            entry.value < 0 ||
            entry.value > _maxSafeInteger) ||
        this.pending.any((event) =>
            event.courseId != scope.courseId ||
            scope.owner.isGuest ||
            event.userId != scope.owner.userId)) {
      throw ArgumentError('Invalid score or cloud event identity.');
    }
  }
  factory CourseLearningState.empty(LearningScope scope) => CourseLearningState(
      scope: scope,
      revision: 0,
      commitOrdinal: 0,
      history: const [],
      activities: const {},
      mistakes: const {},
      summaries: const {},
      completions: const [],
      bestScores: const {},
      pending: const []);
  final int schemaVersion;
  final LearningScope scope;
  final int revision, commitOrdinal;
  final List<AttemptBatch> history;
  final Map<String, ActivitySlot> activities;
  final Map<MistakeKey, LearningMistake> mistakes;
  final Map<SummaryKey, SkillCount> summaries;
  final List<LearningCompletion> completions;
  final Map<String, int> bestScores;
  final List<SupportedCloudEvent> pending;
}
