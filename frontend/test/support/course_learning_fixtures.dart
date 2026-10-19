import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';

final guestScope =
    LearningScope(courseId: 'en-fr', owner: LearningOwner.guest());
final accountAScope =
    LearningScope(courseId: 'en-fr', owner: LearningOwner.account('account/a'));
final accountBScope =
    LearningScope(courseId: 'en-fr', owner: LearningOwner.account('account/b'));
final fixedTime = DateTime.utc(2026, 10, 15, 12);
String tokenFor(int value) => base64Token(value);
String base64Token(int value) =>
    'AAAAAAAAAAAAAAAAAAAA${value.toRadixString(16).padLeft(2, '0')}';

CourseAttempt sampleAttempt(
        {bool correct = false,
        AttemptPresentation presentation = AttemptPresentation.firstInRun,
        int sequence = 1,
        int batchIndex = 0}) =>
    CourseAttempt(
        scope: guestScope,
        submissionId: 'submission-$sequence-$batchIndex',
        activityId: 'lesson:sample',
        runGeneration: 1,
        commandSequence: sequence,
        batchIndex: batchIndex,
        itemId: 'item-$batchIndex',
        itemOccurrence: 1,
        contentRevision: 1,
        commitOrdinal: sequence,
        answeredAt: fixedTime,
        committedAt: fixedTime,
        skill: LearningSkill.listening,
        targetSounds: const ['s'],
        answer: SoundChoiceAnswer(
            selectedSound: 'sh',
            choices: const ['s', 'sh'],
            expectedSound: 's'),
        origin: AttemptOrigin.practice,
        presentation: presentation,
        assistance: const {},
        contentState: AttemptContentState.existingCurated,
        audioSource: AttemptAudioSource.practiceSpeech,
        correct: correct);

CourseLearningState sampleState({LearningScope? scope}) {
  final activeScope = scope ?? guestScope;
  final attempt = sampleAttempt();
  return CourseLearningState(
    scope: activeScope,
    revision: 1,
    commitOrdinal: 1,
    history: [
      AttemptBatch(
        activityId: attempt.activityId,
        generation: 1,
        sequence: 1,
        token: tokenFor(1),
        canonicalCommand: 'fixture-command',
        attempts: [
          CourseAttempt(
            scope: activeScope,
            submissionId: attempt.submissionId,
            activityId: attempt.activityId,
            runGeneration: attempt.runGeneration,
            commandSequence: attempt.commandSequence,
            batchIndex: attempt.batchIndex,
            itemId: attempt.itemId,
            itemOccurrence: attempt.itemOccurrence,
            contentRevision: attempt.contentRevision,
            commitOrdinal: attempt.commitOrdinal,
            answeredAt: attempt.answeredAt,
            committedAt: attempt.committedAt,
            skill: attempt.skill,
            targetSounds: attempt.targetSounds,
            answer: attempt.answer,
            origin: attempt.origin,
            presentation: attempt.presentation,
            assistance: attempt.assistance,
            contentState: attempt.contentState,
            audioSource: attempt.audioSource,
            correct: attempt.correct,
          )
        ],
      ),
    ],
    activities: const {},
    mistakes: const {},
    summaries: const {},
    completions: const [],
    bestScores: const {},
    pending: const [],
  );
}

LearningCommand sampleCommand(
        {required List<RandomDraw> draws}) =>
    LearningCommand(
        scope: guestScope,
        authGeneration: 0,
        activityId: 'arcade:sound',
        expected: SlotCursor(generation: 1, sequence: 0, revision: 0),
        expectedScopeRevision: 0,
        token: tokenFor(1),
        submittedAt: fixedTime,
        action: const ContinueArcadeRound(),
        draws: draws,
        candidate: SoundGameCheckpoint(
            board:
                SoundBoardState(board: List.filled(36, 's'), stars: const {}),
            clock: ArcadeClockState(
                remaining: 60, round: 1, score: 0, paused: true)),
        feedback: const LearningFeedback.none());

ActivitySlot sampleActivitySlot() => ActivitySlot(
      activityId: 'lesson:sample',
      kind: LearningActivityKind.discovery,
      contentRevision: 1,
      cursor: SlotCursor(generation: 1, sequence: 2, revision: 1),
      options: RunOptions(),
      snapshot: DiscoveryCheckpoint(
          session: LessonSectionSession(
              itemIds: const ['item'], sessionId: 'sample-session')),
      exposures: const {},
      latestReceipt: CommandReceipt(
        token: 'AAAAAAAAAAAAAAAAAAAAAA',
        canonicalCommand: 'sample',
        before: SlotCursor(generation: 1, sequence: 1, revision: 0),
        after: SlotCursor(generation: 1, sequence: 2, revision: 1),
        commitOrdinal: 1,
      ),
    );

/// Applies a pure transition to an in-memory state for scenario tests only.
/// This deliberately models no persistence, pruning, or concurrency behavior.
CourseLearningState stateAfter(
    CourseLearningState state, LearningTransition transition) {
  final slot = transition.slot;
  final history = List<AttemptBatch>.of(state.history);
  if (transition.attempts.isNotEmpty) {
    history.add(AttemptBatch(
      activityId: slot.activityId,
      generation: slot.cursor.generation,
      sequence: slot.cursor.sequence,
      token: slot.latestReceipt.token,
      canonicalCommand: slot.latestReceipt.canonicalCommand,
      attempts: transition.attempts,
    ));
  }
  return CourseLearningState(
    scope: state.scope,
    revision: state.revision + 1,
    commitOrdinal: state.commitOrdinal + 1,
    history: history,
    activities: {...state.activities, slot.activityId: slot},
    mistakes: transition.mistakes,
    summaries: transition.summaries,
    completions: transition.completions,
    bestScores: transition.bestScores,
    pending: state.pending,
  );
}
