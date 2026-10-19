import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_codec.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/course_skill_summary.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import '../support/course_learning_fixtures.dart';
import '../support/course_learning_persistence_fakes.dart';

class _BatchEngine extends LearningTransitionEngine {
  _BatchEngine() : super(LearningRegistry.french());

  @override
  LearningTransition evaluate({
    required CourseLearningState state,
    required LearningCommand command,
    required DateTime committedAt,
  }) {
    final before = state.activities[command.activityId];
    final start = command.action is StartLearningRun;
    final prior =
        before?.cursor ?? SlotCursor(generation: 0, sequence: 0, revision: 0);
    final cursor = start
        ? SlotCursor(
            generation: prior.generation + 1,
            sequence: prior.sequence + 1,
            revision: 0)
        : SlotCursor(
            generation: prior.generation,
            sequence: prior.sequence + 1,
            revision: prior.revision + 1);
    final ordinal = state.commitOrdinal + 1;
    final session = before?.snapshot is DiscoveryCheckpoint
        ? (before!.snapshot as DiscoveryCheckpoint).session
        : LessonSectionSession(itemIds: const ['i'], sessionId: command.token);
    final snapshot = DiscoveryCheckpoint(session: session);
    final canonical = const LearningDocumentCodec().canonicalCommand(command);
    final slot = ActivitySlot(
        activityId: command.activityId,
        kind: LearningActivityKind.discovery,
        contentRevision: 1,
        cursor: cursor,
        options: before?.options ?? RunOptions(),
        snapshot: snapshot,
        exposures: before?.exposures ?? const {},
        latestReceipt: CommandReceipt(
            token: command.token,
            canonicalCommand: canonical,
            before: prior,
            after: cursor,
            commitOrdinal: ordinal));
    final attempts = <CourseAttempt>[];
    if (!start) {
      for (var i = 0; i < 16; i++) {
        attempts.add(CourseAttempt(
            scope: state.scope,
            submissionId:
                '${state.scope.storageKey}.${command.activityId}.${cursor.generation}.${cursor.sequence}.${command.token}.a$i',
            activityId: command.activityId,
            runGeneration: cursor.generation,
            commandSequence: cursor.sequence,
            batchIndex: i,
            itemId: 'i$i',
            itemOccurrence: cursor.sequence,
            contentRevision: 1,
            commitOrdinal: ordinal,
            answeredAt: command.submittedAt,
            committedAt: committedAt,
            skill: LearningSkill.listening,
            targetSounds: const ['u'],
            answer: SoundChoiceAnswer(
                selectedSound: 'y',
                choices: const ['u', 'y'],
                expectedSound: 'u'),
            origin: AttemptOrigin.practice,
            presentation: cursor.sequence == 1
                ? AttemptPresentation.firstInRun
                : AttemptPresentation.repeatInRun,
            assistance: const {},
            contentState: AttemptContentState.existingCurated,
            audioSource: AttemptAudioSource.pendingRecording,
            correct: false));
      }
    }
    final summaries = addAttemptCounts(state.summaries, attempts);
    final mistakes = Map<MistakeKey, LearningMistake>.of(state.mistakes);
    if (attempts.isNotEmpty) {
      final key = MistakeKey(
          activityId: command.activityId,
          itemId: 'i0',
          contentRevision: 1,
          skill: LearningSkill.listening,
          targetSound: 'u');
      final old = mistakes[key];
      mistakes[key] = LearningMistake(
          key: key,
          firstWrongId: old?.firstWrongId ?? attempts.first.submissionId,
          firstWrongAt: old?.firstWrongAt ?? command.submittedAt,
          latestWrongId: attempts.first.submissionId,
          latestWrongAt: command.submittedAt,
          failureCount: (old?.failureCount ?? 0) + 1,
          lastRunGeneration: cursor.generation);
    }
    return LearningTransition(
        slot: slot,
        attempts: attempts,
        mistakes: mistakes,
        summaries: summaries,
        completions: state.completions,
        bestScores: state.bestScores);
  }
}

void main() {
  for (final historyLimit in [2000, 16]) {
    test('retains newest whole 16-attempt batches at limit $historyLimit',
        () async {
      final persistence = FakeLearningPersistence();
      final retentionOwner = LearningOwner.account('retention-owner');
      final scope = LearningScope(courseId: 'en-fr', owner: retentionOwner);
      var token = 0;
      final store = CourseLearningRepository(
          scope: scope,
          authGeneration: 0,
          currentAuth: () =>
              LearningAuthScope(owner: scope.owner, generation: 0, ready: true),
          backendOwner: () => scope.owner,
          persistence: persistence,
          transitions: _BatchEngine(),
          clock: () => fixedTime.add(const Duration(seconds: 10000)),
          newToken: () => tokenFor(++token),
          random: Random(1),
          historyLimit: historyLimit);
      final start = LearningCommand(
          scope: scope,
          authGeneration: 0,
          activityId: 'lesson:en-fr-u-y',
          expected: SlotCursor(generation: 0, sequence: 0, revision: 0),
          expectedScopeRevision: 0,
          token: tokenFor(++token),
          submittedAt: fixedTime,
          action: StartLearningRun(options: RunOptions()),
          draws: const [],
          candidate: DiscoveryCheckpoint(
              session: LessonSectionSession(
                  itemIds: const ['i'], sessionId: tokenFor(900))),
          feedback: const LearningFeedback.none());
      await store.submit(start);
      final batchCount = historyLimit == 2000 ? 126 : 2;
      CourseLearningState state = await store.load();
      for (var i = 0; i < batchCount; i++) {
        final slot = state.activities['lesson:en-fr-u-y']!;
        final command = LearningCommand(
            scope: scope,
            authGeneration: 0,
            activityId: slot.activityId,
            expected: slot.cursor,
            expectedScopeRevision: state.revision,
            token: tokenFor(++token),
            submittedAt: fixedTime.add(Duration(seconds: i + 1)),
            action: ChooseSound(
                selectedSound: 'y',
                audioSource: AttemptAudioSource.pendingRecording),
            draws: const [],
            candidate: slot.snapshot,
            feedback: const LearningFeedback.none());
        state = (await store.submit(command)).state;
      }
      final expected = historyLimit == 2000 ? 2000 : 16;
      expect(
          state.history
              .fold<int>(0, (sum, batch) => sum + batch.attempts.length),
          expected);
      expect(
          state.history.every((batch) => batch.attempts.length == 16), isTrue);
      expect(
          state.summaries.values
              .fold<int>(0, (sum, count) => sum + count.total),
          batchCount * 16);
      expect(state.mistakes.values.single.failureCount, batchCount);
      expect(state.pending, hasLength(batchCount * 16),
          reason: 'retention never drops undelivered supported projections');
    });
  }
}
