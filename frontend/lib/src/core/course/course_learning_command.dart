import 'course_attempt.dart';
import 'course_learning_checkpoint.dart';
import 'course_learning_state.dart';

class RandomDraw {
  const RandomDraw({required this.upperBound, required this.value})
      : assert(upperBound > 0 &&
            value >= 0 &&
            value < upperBound &&
            upperBound <= 9007199254740991);
  final int upperBound, value;
}

class LearningFeedback {
  LearningFeedback(
      {required this.message,
      required int points,
      required int cascades,
      required int bonus,
      required this.correct})
      : points = _nonnegative(points, 'points'),
        cascades = _nonnegative(cascades, 'cascades'),
        bonus = _nonnegative(bonus, 'bonus');
  const LearningFeedback.none()
      : message = '',
        points = 0,
        cascades = 0,
        bonus = 0,
        correct = null;
  final String message;
  final int points, cascades, bonus;
  final bool? correct;
}

int _nonnegative(int value, String name) {
  if (value < 0 || value > 9007199254740991) {
    throw ArgumentError.value(value, name);
  }
  return value;
}

String _requiredText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be blank.');
  }
  return value;
}

sealed class LearningAction {
  const LearningAction();
}

class StartLearningRun extends LearningAction {
  const StartLearningRun({required this.options});
  final RunOptions options;
}

class ChooseSound extends LearningAction {
  ChooseSound({required String selectedSound, required this.audioSource})
      : selectedSound = _requiredText(selectedSound, 'selectedSound');
  final String selectedSound;
  final AttemptAudioSource audioSource;
}

class ChooseDrillWord extends LearningAction {
  ChooseDrillWord({required String selectedWord, required this.audioSource})
      : selectedWord = _requiredText(selectedWord, 'selectedWord');
  final String selectedWord;
  final AttemptAudioSource audioSource;
}

class AdvanceLesson extends LearningAction {
  const AdvanceLesson();
}

class ReviewDiscoveryMistakes extends LearningAction {
  const ReviewDiscoveryMistakes();
}

class ObserveAssistance extends LearningAction {
  ObserveAssistance(
      {required Set<ItemContextKey> items, required Set<AssistanceFlag> flags})
      : items = Set.unmodifiable(items),
        flags = Set.unmodifiable(flags);
  final Set<ItemContextKey> items;
  final Set<AssistanceFlag> flags;
}

class FinishLearningActivity extends LearningAction {
  const FinishLearningActivity({this.recordCompletion = true});
  final bool recordCompletion;
}

class EndDrill extends LearningAction {
  const EndDrill();
}

class HeardSoundCue {
  HeardSoundCue(
      {required String wordId,
      required String targetSound,
      required this.audioSource})
      : wordId = _requiredText(wordId, 'wordId'),
        targetSound = _requiredText(targetSound, 'targetSound');
  final String wordId, targetSound;
  final AttemptAudioSource audioSource;
}

class SwapSoundTiles extends LearningAction {
  SwapSoundTiles(
      {required this.first,
      required this.second,
      this.cue,
      int elapsedSeconds = 0})
      : elapsedSeconds = _nonnegative(elapsedSeconds, 'elapsedSeconds');
  final int first, second, elapsedSeconds;
  final HeardSoundCue? cue;
}

class LinkWordTiles extends LearningAction {
  LinkWordTiles({required List<int> indices, int elapsedSeconds = 0})
      : indices = List.unmodifiable(indices),
        elapsedSeconds = _nonnegative(elapsedSeconds, 'elapsedSeconds') {
    if (indices.isEmpty ||
        indices.toSet().length != indices.length ||
        indices.any((index) => index < 0 || index >= 16)) {
      throw ArgumentError.value(
          indices, 'indices', 'Must be distinct valid word-board positions.');
    }
  }
  final List<int> indices;
  final int elapsedSeconds;
}

class CheckpointArcade extends LearningAction {
  CheckpointArcade({required int elapsedSeconds, required this.paused})
      : elapsedSeconds = _nonnegative(elapsedSeconds, 'elapsedSeconds');
  final int elapsedSeconds;
  final bool paused;
}

class ContinueArcadeRound extends LearningAction {
  const ContinueArcadeRound();
}

class LearningCommand {
  LearningCommand(
      {required this.scope,
      required int authGeneration,
      required String activityId,
      required this.expected,
      required String token,
      required this.submittedAt,
      required this.action,
      required List<RandomDraw> draws,
      required this.candidate,
      required this.feedback})
      : authGeneration = _nonnegative(authGeneration, 'authGeneration'),
        activityId = _requiredText(activityId, 'activityId'),
        token = _validateToken(token),
        draws = List.unmodifiable(draws) {
    if (submittedAt.isUtc == false ||
        draws.any((draw) => draw.upperBound < 1)) {
      throw ArgumentError('Command timestamp must be UTC and draws valid.');
    }
  }
  final LearningScope scope;
  final int authGeneration;
  final String activityId, token;
  final SlotCursor expected;
  final DateTime submittedAt;
  final LearningAction action;
  final List<RandomDraw> draws;
  final ActivitySnapshot candidate;
  final LearningFeedback feedback;
}

String _validateToken(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(value)) {
    throw ArgumentError.value(
        value, 'token', 'Must be a 22-character base64url token.');
  }
  return value;
}
