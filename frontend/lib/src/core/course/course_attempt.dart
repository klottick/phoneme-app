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
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be blank.');
  }
  return value;
}

const int _maxSafeInteger = 9007199254740991;

int _counter(int value, String name, {int minimum = 0}) {
  if (value < minimum || value > _maxSafeInteger) {
    throw ArgumentError.value(value, name, 'Out of supported range.');
  }
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
  bool operator ==(Object other) =>
      other is LearningScope &&
      courseId == other.courseId &&
      owner == other.owner;
  @override
  int get hashCode => Object.hash(courseId, owner);
}

class LearningAuthScope {
  LearningAuthScope(
      {required this.owner, required int generation, required this.ready})
      : generation = _counter(generation, 'generation');
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
      : choices =
            _answerChoices(choices, selectedSound, expectedSound, 'sound');
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
      : choices = _answerChoices(choices, selectedWord, expectedWord, 'word');
  final String selectedWord;
  final String pairId;
  final List<String> choices;
  final String expectedWord;
}

class SoundCueAnswer extends AttemptAnswer {
  SoundCueAnswer(
      {required this.selectedFamily,
      required this.wordId,
      required this.expectedFamily}) {
    _required(selectedFamily, 'selectedFamily');
    _required(wordId, 'wordId');
    _required(expectedFamily, 'expectedFamily');
  }
  final String selectedFamily;
  final String wordId;
  final String expectedFamily;
}

class WordTileAnswer extends AttemptAnswer {
  WordTileAnswer(
      {required this.wordId,
      required this.tileIndex,
      required this.targetSound,
      required this.expectedMembership}) {
    _required(wordId, 'wordId');
    _counter(tileIndex, 'tileIndex', minimum: 0);
    if (tileIndex >= 16) {
      throw ArgumentError.value(
          tileIndex, 'tileIndex', 'Must be a word-board position.');
    }
    _required(targetSound, 'targetSound');
  }
  final String wordId;
  final int tileIndex;
  final String targetSound;
  final bool expectedMembership;
}

class CourseAttempt {
  CourseAttempt(
      {required this.scope,
      required String submissionId,
      required String activityId,
      required int runGeneration,
      required int commandSequence,
      required int batchIndex,
      required String itemId,
      required int itemOccurrence,
      required int contentRevision,
      required int commitOrdinal,
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
      : submissionId = _required(submissionId, 'submissionId'),
        activityId = _required(activityId, 'activityId'),
        runGeneration = _counter(runGeneration, 'runGeneration', minimum: 1),
        commandSequence =
            _counter(commandSequence, 'commandSequence', minimum: 1),
        batchIndex = _counter(batchIndex, 'batchIndex'),
        itemId = _required(itemId, 'itemId'),
        itemOccurrence = _counter(itemOccurrence, 'itemOccurrence', minimum: 1),
        contentRevision =
            _counter(contentRevision, 'contentRevision', minimum: 1),
        commitOrdinal = _counter(commitOrdinal, 'commitOrdinal', minimum: 1),
        targetSounds = _uniqueStrings(targetSounds, 'targetSounds'),
        assistance = Set.unmodifiable(assistance) {
    if (committedAt.isBefore(answeredAt)) {
      throw ArgumentError.value(
          committedAt, 'committedAt', 'Must not precede answeredAt.');
    }
  }
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

List<String> _answerChoices(
    List<String> choices, String selected, String expected, String name) {
  final copy = _uniqueStrings(choices, 'choices');
  if (copy.isEmpty || !copy.contains(selected) || !copy.contains(expected)) {
    throw ArgumentError.value(choices, 'choices',
        'Must uniquely contain selected and expected $name.');
  }
  return copy;
}

List<String> _uniqueStrings(List<String> values, String name) {
  final copy = List<String>.of(values);
  if (copy.any((value) => value.trim().isEmpty) ||
      copy.toSet().length != copy.length) {
    throw ArgumentError.value(
        values, name, 'Values must be nonblank and unique.');
  }
  return List.unmodifiable(copy);
}
