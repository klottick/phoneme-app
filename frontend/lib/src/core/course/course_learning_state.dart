import 'course_attempt.dart';
import 'course_learning_checkpoint.dart';
import 'course_skill_summary.dart';
import 'lesson_policy.dart';

class SlotCursor {
  const SlotCursor(
      {required this.generation,
      required this.sequence,
      required this.revision});
  final int generation, sequence, revision;
}

class ItemExposure {
  ItemExposure(
      {required this.presentations, required Set<AssistanceFlag> assistance})
      : assistance = Set.unmodifiable(assistance);
  final int presentations;
  final Set<AssistanceFlag> assistance;
}

class ItemContextKey {
  const ItemContextKey({required this.itemId, required this.targetSound});
  final String itemId, targetSound;
  @override
  bool operator ==(Object o) =>
      o is ItemContextKey && itemId == o.itemId && targetSound == o.targetSound;
  @override
  int get hashCode => Object.hash(itemId, targetSound);
}

class RunOptions {
  RunOptions({LessonPolicy? policy}) : policy = policy ?? LessonPolicy();
  final LessonPolicy policy;
}

class CommandReceipt {
  const CommandReceipt(
      {required this.token,
      required this.canonicalCommand,
      required this.before,
      required this.after,
      required this.commitOrdinal});
  final String token, canonicalCommand;
  final SlotCursor before, after;
  final int commitOrdinal;
}

class ActivitySlot {
  ActivitySlot(
      {required this.activityId,
      required this.kind,
      required this.contentRevision,
      required this.cursor,
      required this.options,
      required this.snapshot,
      required Map<ItemContextKey, ItemExposure> exposures,
      required this.latestReceipt})
      : exposures = Map.unmodifiable(exposures);
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
      {required this.activityId,
      required this.generation,
      required this.sequence,
      required this.token,
      required this.canonicalCommand,
      required List<CourseAttempt> attempts})
      : attempts = List.unmodifiable(attempts) {
    if (attempts.isEmpty) throw ArgumentError.value(attempts, 'attempts');
  }
  final String activityId, token, canonicalCommand;
  final int generation, sequence;
  final List<CourseAttempt> attempts;
}

class MistakeKey {
  const MistakeKey(
      {required this.activityId,
      required this.itemId,
      required this.contentRevision,
      required this.skill,
      required this.targetSound});
  final String activityId, itemId, targetSound;
  final int contentRevision;
  final LearningSkill skill;
  @override
  bool operator ==(Object o) =>
      o is MistakeKey &&
      activityId == o.activityId &&
      itemId == o.itemId &&
      contentRevision == o.contentRevision &&
      skill == o.skill &&
      targetSound == o.targetSound;
  @override
  int get hashCode =>
      Object.hash(activityId, itemId, contentRevision, skill, targetSound);
}

class LearningMistake {
  const LearningMistake(
      {required this.key,
      required this.firstWrongId,
      required this.firstWrongAt,
      required this.latestWrongId,
      required this.latestWrongAt,
      required this.failureCount,
      required this.lastRunGeneration});
  final MistakeKey key;
  final String firstWrongId, latestWrongId;
  final DateTime firstWrongAt, latestWrongAt;
  final int failureCount, lastRunGeneration;
}

class LearningCompletion {
  const LearningCompletion(
      {required this.lessonId,
      required this.contentRevision,
      required this.policyKind,
      required this.policyRevision,
      required this.thresholdPercent,
      required this.committedAt});
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
  const CloudAnswer(
      {required this.sound,
      required this.skill,
      required this.correct,
      required this.activity});
  final String sound, activity;
  final LearningSkill skill;
  final bool correct;
}

class CloudLesson extends SupportedCloudPayload {
  const CloudLesson({required this.lessonId});
  final String lessonId;
}

class CloudScore extends SupportedCloudPayload {
  const CloudScore({required this.game, required this.score});
  final String game;
  final int score;
}

class SupportedCloudEvent {
  const SupportedCloudEvent(
      {required this.id,
      required this.userId,
      required this.courseId,
      required this.payload});
  final String id, userId, courseId;
  final SupportedCloudPayload payload;
}

class CourseLearningState {
  CourseLearningState(
      {this.schemaVersion = 2,
      required this.scope,
      required this.revision,
      required this.commitOrdinal,
      required List<AttemptBatch> history,
      required Map<String, ActivitySlot> activities,
      required Map<MistakeKey, LearningMistake> mistakes,
      required Map<SummaryKey, SkillCount> summaries,
      required List<LearningCompletion> completions,
      required Map<String, int> bestScores,
      required List<SupportedCloudEvent> pending})
      : history = List.unmodifiable(history),
        activities = Map.unmodifiable(activities),
        mistakes = Map.unmodifiable(mistakes),
        summaries = Map.unmodifiable(summaries),
        completions = List.unmodifiable(completions),
        bestScores = Map.unmodifiable(bestScores),
        pending = List.unmodifiable(pending) {
    if (schemaVersion != 2 || revision < 0 || commitOrdinal < 0)
      throw ArgumentError('Invalid learning state header');
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
  @override
  bool operator ==(Object o) =>
      o is CourseLearningState &&
      schemaVersion == o.schemaVersion &&
      scope == o.scope &&
      revision == o.revision &&
      commitOrdinal == o.commitOrdinal &&
      history.length == o.history.length &&
      activities.length == o.activities.length &&
      mistakes.length == o.mistakes.length &&
      summaries.length == o.summaries.length &&
      completions.length == o.completions.length &&
      bestScores.length == o.bestScores.length &&
      pending.length == o.pending.length;
  @override
  int get hashCode => Object.hash(
      schemaVersion,
      scope,
      revision,
      commitOrdinal,
      history.length,
      activities.length,
      mistakes.length,
      summaries.length,
      completions.length,
      bestScores.length,
      pending.length);
}
