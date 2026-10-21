import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';

import '../support/course_learning_widget_store.dart'
    show CourseLearningSqlTestHarness;

void main() {
  test('SQL pruning keeps newest attempts and undelivered events', () async {
    final harness = CourseLearningSqlTestHarness(
      owner: LearningOwner.account('retention-owner'),
      historyLimit: 1,
    );
    const activity = 'lesson:en-fr-u-y';

    await harness.start(activity);
    await harness.answerPilot('u');
    await harness.start(activity);
    await harness.answerPilot('u');

    final state = await harness.store.load();
    expect(state.history, hasLength(1));
    expect(state.history.single.attempts, hasLength(1));
    expect(state.history.single.attempts.single.runGeneration, 2);
    expect(
      state.summaries.values.fold<int>(0, (total, item) => total + item.total),
      2,
    );
    expect(state.pending, hasLength(2));

    final database = await harness.database.open();
    final outboxCount = await database
        .customSelect('SELECT COUNT(*) AS row_count FROM supported_sync_outbox')
        .getSingle()
        .then((row) => row.read<int>('row_count'));
    final attemptCount = await database
        .customSelect('SELECT COUNT(*) AS row_count FROM learning_attempts')
        .getSingle()
        .then((row) => row.read<int>('row_count'));
    expect(attemptCount, 1);
    expect(outboxCount, 2);
  });
}
