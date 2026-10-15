import 'dart:convert';

enum AttemptOrigin { practice, game }

enum AttemptPresentation { firstInRun, repeatInRun }

enum AssistanceFlag {
  explanationVisible,
  graphemeHint,
  afterDebrief,
  answerRevealed
}

enum AttemptAudioSource { pendingRecording, practiceSpeech, notApplicable }

enum AttemptContentState { existingCurated, pending, reviewed }

enum LearningSkill { listening, spelling }

enum CompletionPolicyKind { discoveryThreshold, legacyOnePass }

enum LearningActivityKind {
  discovery,
  legacyLesson,
  drill,
  soundGame,
  wordGame
}

String _required(String value, String name) {
  if (value.trim().isEmpty)
    throw ArgumentError.value(value, name, 'Must not be blank.');
  return value;
}

class LearningOwner {
  LearningOwner._(this.userId);
  factory LearningOwner.guest() => LearningOwner._(null);
  factory LearningOwner.account(String userId) =>
      LearningOwner._(_required(userId, 'userId'));
  final String? userId;
  bool get isGuest => userId == null;
  @override
  bool operator ==(Object other) =>
      other is LearningOwner && userId == other.userId;
  @override
  int get hashCode => userId.hashCode;
}

class LearningScope {
  LearningScope({required String courseId, required this.owner})
      : courseId = _required(courseId, 'courseId');
  final String courseId;
  final LearningOwner owner;
  String get storageKey {
    String enc(String value) =>
        base64Url.encode(utf8.encode(value)).replaceAll('=', '');
    return 'course.learning.v2.${enc(courseId)}.${owner.isGuest ? 'g' : 'a.${enc(owner.userId!)}'}';
  }

  @override
  bool operator ==(Object o) =>
      o is LearningScope && courseId == o.courseId && owner == o.owner;
  @override
  int get hashCode => Object.hash(courseId, owner);
}

class LearningAuthScope {
  const LearningAuthScope(
      {required this.owner, required this.generation, required this.ready});
  final LearningOwner owner;
  final int generation;
  final bool ready;
}

sealed class AttemptAnswer {
  const AttemptAnswer();
}

class SoundChoiceAnswer extends AttemptAnswer {
  SoundChoiceAnswer(
      {required this.selectedSound,
      required List<String> choices,
      required this.expectedSound})
      : choices = List.unmodifiable(choices);
  final String selectedSound;
  final List<String> choices;
  final String expectedSound;
}

class DrillChoiceAnswer extends AttemptAnswer {
  DrillChoiceAnswer(
      {required this.selectedWord,
      required this.pairId,
      required List<String> choices,
      required this.expectedWord})
      : choices = List.unmodifiable(choices);
  final String selectedWord;
  final String pairId;
  final List<String> choices;
  final String expectedWord;
}

class SoundCueAnswer extends AttemptAnswer {
  const SoundCueAnswer(
      {required this.selectedFamily,
      required this.wordId,
      required this.expectedFamily});
  final String selectedFamily;
  final String wordId;
  final String expectedFamily;
}

class WordTileAnswer extends AttemptAnswer {
  const WordTileAnswer(
      {required this.wordId,
      required this.tileIndex,
      required this.targetSound,
      required this.expectedMembership});
  final String wordId;
  final int tileIndex;
  final String targetSound;
  final bool expectedMembership;
}

class CourseAttempt {
  CourseAttempt(
      {required this.scope,
      required this.submissionId,
      required this.activityId,
      required this.runGeneration,
      required this.commandSequence,
      required this.batchIndex,
      required this.itemId,
      required this.itemOccurrence,
      required this.contentRevision,
      required this.commitOrdinal,
      required this.answeredAt,
      required this.committedAt,
      required this.skill,
      required List<String> targetSounds,
      required this.answer,
      required this.origin,
      required this.presentation,
      required Set<AssistanceFlag> assistance,
      required this.contentState,
      required this.audioSource,
      required this.correct})
      : targetSounds = List.unmodifiable(targetSounds),
        assistance = Set.unmodifiable(assistance);
  final LearningScope scope;
  final String submissionId;
  final String activityId;
  final int runGeneration;
  final int commandSequence;
  final int batchIndex;
  final String itemId;
  final int itemOccurrence;
  final int contentRevision;
  final int commitOrdinal;
  final DateTime answeredAt;
  final DateTime committedAt;
  final LearningSkill skill;
  final List<String> targetSounds;
  final AttemptAnswer answer;
  final AttemptOrigin origin;
  final AttemptPresentation presentation;
  final Set<AssistanceFlag> assistance;
  final AttemptContentState contentState;
  final AttemptAudioSource audioSource;
  final bool correct;
}
