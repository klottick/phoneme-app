import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/course_skill_summary.dart';
import 'package:linguist/src/core/course/storage/course_learning_checkpoint_codec.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_repository.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import '../support/course_learning_widget_store.dart';

void main() {
  const activity = 'lesson:en-fr-u-y';
  late CourseLearningSqlTestHarness harness;
  late LearningTransitionEngine engine;

  SqliteCourseLearningRepository repository() => harness.createRepository();

  setUp(() {
    harness = CourseLearningSqlTestHarness();
    engine = harness.transitions;
  });

  test(
    'passing finish preserves mistakes until only matching answers resolve',
    () async {
      var repo = repository();
      var state = await repo.load();
      Future<LearningCommit> commit(LearningAction action) async {
        final result = await repo.submit(
          repo.prepare(state: state, activityId: activity, action: action),
        );
        state = result.state;
        return result;
      }

      await commit(StartLearningRun(options: RunOptions()));
      final items = engine.registry.require(activity).items;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final wrong = i == 1 || i == 3;
        await commit(
          ChooseSound(
            selectedSound: wrong
                ? _wrong(item.expectedChoice!)
                : item.expectedChoice!,
            audioSource: authoredAudioSource(item)!,
          ),
        );
        await commit(const AdvanceLesson());
      }
      final mistakeKeys = state.mistakes.keys.toSet();
      final originalWrong = state.history
          .expand((b) => b.attempts)
          .where((a) => !a.correct)
          .map((a) => a.submissionId)
          .toSet();
      expect(mistakeKeys.map((key) => key.itemId).toSet(), {
        'en-fr-u-y-listening-tu',
        'en-fr-u-y-listening-rue',
      });
      expect(state.summaries.values.fold<int>(0, (n, s) => n + s.correct), 8);
      await commit(const FinishLearningActivity());

      repo = repository();
      state = await repo.load();
      expect(state.completions, hasLength(1));
      expect(state.history.expand((b) => b.attempts), hasLength(10));
      expect(state.mistakes.keys, unorderedEquals(mistakeKeys));
      expect(
        state.history
            .expand((b) => b.attempts)
            .where((a) => !a.correct)
            .map((a) => a.submissionId)
            .toSet(),
        originalWrong,
      );

      state = (await repo.submit(
        repo.prepare(
          state: state,
          activityId: activity,
          action: StartLearningRun(options: RunOptions()),
        ),
      )).state;
      final tout = items.singleWhere((item) => item.id.endsWith('-tout'));
      state = (await repo.submit(
        repo.prepare(
          state: state,
          activityId: activity,
          action: ChooseSound(
            selectedSound: tout.expectedChoice!,
            audioSource: authoredAudioSource(tout)!,
          ),
        ),
      )).state;
      expect(state.mistakes.keys, unorderedEquals(mistakeKeys));
      state = (await repo.submit(
        repo.prepare(
          state: state,
          activityId: activity,
          action: const AdvanceLesson(),
        ),
      )).state;
      final tu = items.singleWhere((item) => item.id.endsWith('-tu'));
      state = (await repo.submit(
        repo.prepare(
          state: state,
          activityId: activity,
          action: ChooseSound(
            selectedSound: tu.expectedChoice!,
            audioSource: authoredAudioSource(tu)!,
          ),
        ),
      )).state;
      final remaining = mistakeKeys.singleWhere(
        (key) => key.itemId.endsWith('-rue'),
      );
      expect(state.mistakes.keys, {remaining});
      expect(
        state.history
            .expand((b) => b.attempts)
            .where((a) => !a.correct)
            .map((a) => a.submissionId)
            .toSet(),
        originalWrong,
      );
    },
  );

  test(
    'review reload retains policy, retry provenance and summary evidence',
    () async {
      var repo = repository();
      var state = await repo.load();
      Future<void> commit(LearningAction action) async {
        state = (await repo.submit(
          repo.prepare(state: state, activityId: activity, action: action),
        )).state;
      }

      final policy = LessonPolicy(completionThresholdPercent: 100);
      await commit(StartLearningRun(options: RunOptions(policy: policy)));
      final items = engine.registry.require(activity).items;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        await commit(
          ChooseSound(
            selectedSound: i == 9
                ? _wrong(item.expectedChoice!)
                : item.expectedChoice!,
            audioSource: authoredAudioSource(item)!,
          ),
        );
        await commit(const AdvanceLesson());
      }
      expect(state.completions, isEmpty);
      final wrongId = state.history
          .expand((b) => b.attempts)
          .singleWhere((a) => !a.correct)
          .submissionId;
      final key = state.mistakes.keys.single;
      await commit(const ReviewDiscoveryMistakes());

      repo = repository();
      state = await repo.load();
      final slot = state.activities[activity]!;
      expect(slot.options.policy.completionThresholdPercent, 100);
      final checkpoint = slot.snapshot as DiscoveryCheckpoint;
      expect(checkpoint.session.policy.completionThresholdPercent, 100);
      expect(checkpoint.session.queue, ['mur']);
      expect(checkpoint.session.round, 2);
      expect(checkpoint.session.phase.name, 'exercise');
      expect(checkpoint.session.correctCount, 9);

      final mur = items.singleWhere((item) => item.id.endsWith('-mur'));
      state = (await repo.submit(
        repo.prepare(
          state: state,
          activityId: activity,
          action: ChooseSound(
            selectedSound: mur.expectedChoice!,
            audioSource: authoredAudioSource(mur)!,
          ),
        ),
      )).state;
      state = (await repo.submit(
        repo.prepare(
          state: state,
          activityId: activity,
          action: const AdvanceLesson(),
        ),
      )).state;
      repo = repository();
      state = await repo.load();
      final attempts = state.history.expand((b) => b.attempts).toList();
      expect(attempts, hasLength(11));
      expect(attempts.any((a) => a.submissionId == wrongId), isTrue);
      expect(state.mistakes.containsKey(key), isFalse);
      final retry = attempts.singleWhere(
        (a) => a.correct && a.itemId == key.itemId,
      );
      expect(retry.presentation, AttemptPresentation.repeatInRun);
      expect(retry.itemOccurrence, 2);
      expect(retry.assistance, contains(AssistanceFlag.afterDebrief));
      expect(
        (state.activities[activity]!.snapshot as DiscoveryCheckpoint)
            .session
            .canComplete,
        isTrue,
      );
      final first = _sum(state.summaries, AttemptPresentation.firstInRun);
      final repeat = _sum(state.summaries, AttemptPresentation.repeatInRun);
      expect([first.total, first.correct], [10, 9]);
      expect([repeat.total, repeat.correct], [1, 1]);
    },
  );

  for (final scenario in ['advance', 'review start', 'finish']) {
    test('checkpoint rejection retries $scenario exactly once', () async {
      final repo = repository();
      var state = await repo.load();
      Future<LearningCommit> commit(LearningAction action) async {
        final ack = await repo.submit(
          repo.prepare(state: state, activityId: activity, action: action),
        );
        state = ack.state;
        return ack;
      }

      await commit(StartLearningRun(options: RunOptions()));
      final items = engine.registry.require(activity).items;
      final itemCount = scenario == 'advance' ? 1 : items.length;
      for (var i = 0; i < itemCount; i++) {
        final item = items[i];
        await commit(
          ChooseSound(
            selectedSound: scenario != 'advance' && (i == 1 || i == 3)
                ? _wrong(item.expectedChoice!)
                : item.expectedChoice!,
            audioSource: authoredAudioSource(item)!,
          ),
        );
        await commit(const AdvanceLesson());
      }
      final action = switch (scenario) {
        'advance' => const AdvanceLesson(),
        'review start' => const ReviewDiscoveryMistakes(),
        _ => const FinishLearningActivity(),
      };
      if (scenario == 'advance') {
        final item = items[1];
        await commit(
          ChooseSound(
            selectedSound: item.expectedChoice!,
            audioSource: authoredAudioSource(item)!,
          ),
        );
      }
      final command = repo.prepare(
        state: state,
        activityId: activity,
        action: action,
      );
      final attemptsBefore = state.history.expand((b) => b.attempts).toList();
      final checkpointBefore = const CourseLearningCheckpointCodec().encode(
        state.activities[activity]!.snapshot,
      );
      final cursorBefore = state.activities[activity]!.cursor;
      await harness.rejectNextInsertInto('learning_command_receipts');
      await expectLater(
        repo.submit(command),
        throwsA(isA<LearningSaveException>()),
      );
      await harness.clearWriteFailure();
      final restored = await repository().load();
      expect(
        const CourseLearningCheckpointCodec().encode(
          restored.activities[activity]!.snapshot,
        ),
        checkpointBefore,
        reason: 'failed $scenario checkpoint must restore the SQL checkpoint',
      );
      expect(
        restored.activities[activity]!.cursor.sequence,
        cursorBefore.sequence,
      );
      expect(
        restored.history.expand((b) => b.attempts).map((a) => a.submissionId),
        attemptsBefore.map((a) => a.submissionId),
      );
      expect(restored.summaries.keys, state.summaries.keys);
      expect(restored.completions.length, state.completions.length);

      final ack = await repo.submit(command);
      final duplicate = await repo.submit(command);
      expect(ack.duplicate, isFalse);
      expect(duplicate.duplicate, isTrue);
      expect(duplicate.slot.cursor.sequence, ack.slot.cursor.sequence);
      expect(ack.slot.cursor.sequence, cursorBefore.sequence + 1);
      expect(
        duplicate.state.history
            .expand((b) => b.attempts)
            .map((a) => a.submissionId),
        attemptsBefore.map((a) => a.submissionId),
      );
      final durable = await repository().load();
      expect(
        durable.activities[activity]!.cursor.sequence,
        ack.slot.cursor.sequence,
      );
      expect(
        durable.history.expand((b) => b.attempts).map((a) => a.submissionId),
        attemptsBefore.map((a) => a.submissionId),
      );
      if (scenario == 'advance') {
        expect(
          (durable.activities[activity]!.snapshot as DiscoveryCheckpoint)
              .session
              .position,
          2,
        );
      } else if (scenario == 'review start') {
        expect(
          (durable.activities[activity]!.snapshot as DiscoveryCheckpoint)
              .session
              .round,
          2,
        );
      } else {
        expect(
          (durable.activities[activity]!.snapshot as DiscoveryCheckpoint)
              .session
              .phase
              .name,
          'debrief',
        );
        expect(durable.completions, hasLength(1));
      }
    });
  }

  test('completion identity survives reload and threshold changes', () async {
    var repo = repository();
    var state = await repo.load();
    final items = engine.registry.require(activity).items;
    for (final threshold in [80, 100, 100]) {
      state = (await repo.submit(
        repo.prepare(
          state: state,
          activityId: activity,
          action: StartLearningRun(
            options: RunOptions(
              policy: LessonPolicy(completionThresholdPercent: threshold),
            ),
          ),
        ),
      )).state;
      for (final item in items) {
        state = (await repo.submit(
          repo.prepare(
            state: state,
            activityId: activity,
            action: ChooseSound(
              selectedSound: item.expectedChoice!,
              audioSource: authoredAudioSource(item)!,
            ),
          ),
        )).state;
        state = (await repo.submit(
          repo.prepare(
            state: state,
            activityId: activity,
            action: const AdvanceLesson(),
          ),
        )).state;
      }
      state = (await repo.submit(
        repo.prepare(
          state: state,
          activityId: activity,
          action: const FinishLearningActivity(),
        ),
      )).state;
      repo = repository();
      state = await repo.load();
      expect(
        state.activities[activity]!.options.policy.completionThresholdPercent,
        threshold,
      );
      expect(
        state.completions.map((c) => c.thresholdPercent),
        threshold == 80 ? [80] : [80, 100],
      );
      expect(
        state.completions.every(
          (c) =>
              c.lessonId == 'en-fr-u-y' &&
              c.contentRevision ==
                  engine.registry.require(activity).contentRevision &&
              c.policyKind == CompletionPolicyKind.discoveryThreshold &&
              c.policyRevision == 1,
        ),
        isTrue,
      );
    }
    expect(state.completions.map((c) => c.thresholdPercent), [80, 100]);
    expect(state.history.expand((b) => b.attempts), hasLength(30));
  });
}

String _wrong(String expected) => expected == 'u' ? 'y' : 'u';

SkillCount _sum(
  Map<SummaryKey, SkillCount> summaries,
  AttemptPresentation presentation,
) {
  final matches = summaries.entries.where(
    (e) => e.key.presentation == presentation,
  );
  return SkillCount(
    total: matches.fold(0, (n, e) => n + e.value.total),
    correct: matches.fold(0, (n, e) => n + e.value.correct),
  );
}
