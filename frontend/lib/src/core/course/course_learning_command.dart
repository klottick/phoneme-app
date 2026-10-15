import 'course_attempt.dart';
import 'course_learning_checkpoint.dart';
import 'course_learning_state.dart';

class RandomDraw {
  const RandomDraw({required this.upperBound, required this.value})
      : assert(upperBound > 0 && value >= 0 && value < upperBound);
  final int upperBound, value;
}

class LearningFeedback {
  const LearningFeedback(
      {required this.message,
      required this.points,
      required this.cascades,
      required this.bonus,
      required this.correct});
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

sealed class LearningAction {
  const LearningAction();
}

class StartLearningRun extends LearningAction {
  const StartLearningRun({required this.options});
  final RunOptions options;
}

class ChooseSound extends LearningAction {
  const ChooseSound({required this.selectedSound, required this.audioSource});
  final String selectedSound;
  final AttemptAudioSource audioSource;
}

class ChooseDrillWord extends LearningAction {
  const ChooseDrillWord(
      {required this.selectedWord, required this.audioSource});
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
  const HeardSoundCue(
      {required this.wordId,
      required this.targetSound,
      required this.audioSource});
  final String wordId, targetSound;
  final AttemptAudioSource audioSource;
}

class SwapSoundTiles extends LearningAction {
  const SwapSoundTiles(
      {required this.first,
      required this.second,
      this.cue,
      this.elapsedSeconds = 0});
  final int first, second, elapsedSeconds;
  final HeardSoundCue? cue;
}

class LinkWordTiles extends LearningAction {
  LinkWordTiles({required List<int> indices, this.elapsedSeconds = 0})
      : indices = List.unmodifiable(indices);
  final List<int> indices;
  final int elapsedSeconds;
}

class CheckpointArcade extends LearningAction {
  const CheckpointArcade({required this.elapsedSeconds, required this.paused});
  final int elapsedSeconds;
  final bool paused;
}

class ContinueArcadeRound extends LearningAction {
  const ContinueArcadeRound();
}

class LearningCommand {
  LearningCommand(
      {required this.scope,
      required this.authGeneration,
      required this.activityId,
      required this.expected,
      required this.token,
      required this.submittedAt,
      required this.action,
      required List<RandomDraw> draws,
      required this.candidate,
      required this.feedback})
      : draws = List.unmodifiable(draws);
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
