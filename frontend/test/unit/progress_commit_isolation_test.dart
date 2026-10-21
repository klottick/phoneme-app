import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';

import '../support/course_learning_widget_store.dart';

void main() {
  test('failed SQL start rolls back and reload remains empty', () async {
    final harness = CourseLearningSqlTestHarness();
    final store = harness.store;
    final initial = await store.load();
    final start = store.prepare(
      state: initial,
      activityId: 'lesson:en-fr-u-y',
      action: StartLearningRun(options: RunOptions()),
    );

    await harness.rejectNextInsertInto('learning_runs');
    await expectLater(
      store.submit(start),
      throwsA(isA<LearningSaveException>()),
    );
    await harness.clearWriteFailure();

    expect((await store.load()).activities, isEmpty);
    final database = await harness.database.open();
    final count = await database
        .customSelect(
          'SELECT COUNT(*) AS row_count FROM learning_command_receipts',
        )
        .getSingle();
    expect(count.read<int>('row_count'), 0);
  });

  test('unrelated activity commits preserve both SQL slots', () async {
    final harness = CourseLearningSqlTestHarness();
    final store = harness.store;
    await harness.start('lesson:en-fr-u-y');
    final drill = store.prepare(
      state: await store.load(),
      activityId: 'drill:minimal-pairs',
      action: StartLearningRun(options: RunOptions()),
    );
    await store.submit(drill);

    final state = await store.load();
    expect(
      state.activities.keys,
      containsAll(['lesson:en-fr-u-y', 'drill:minimal-pairs']),
    );
  });

  test(
    'failed SQL answer exposes no attempt or summary before exact retry',
    () async {
      final harness = CourseLearningSqlTestHarness();
      final store = harness.store;
      await harness.start('lesson:en-fr-u-y');
      final before = await store.load();
      final command = store.prepare(
        state: before,
        activityId: 'lesson:en-fr-u-y',
        action: ChooseSound(
          selectedSound: 'u',
          audioSource: AttemptAudioSource.pendingRecording,
        ),
      );

      await harness.rejectNextInsertInto('learning_attempts');
      await expectLater(
        store.submit(command),
        throwsA(isA<LearningSaveException>()),
      );
      await harness.clearWriteFailure();
      final afterFailure = await store.load();
      expect(afterFailure.history, isEmpty);
      expect(afterFailure.summaries, isEmpty);
      expect(afterFailure.completions, isEmpty);

      final commit = await store.submit(command);
      final duplicate = await store.submit(command);
      expect(commit.state.history.single.attempts, hasLength(1));
      expect(duplicate.duplicate, isTrue);
      expect(duplicate.state.history.single.attempts, hasLength(1));
    },
  );
}
