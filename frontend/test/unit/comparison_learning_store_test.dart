import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_sql_repository.dart';

import '../support/course_learning_widget_store.dart'
    show ComparisonLearningSqlTestHarness;

void main() {
  test('comparison legacy scope keys remain exact stable identities', () {
    expect(
      ComparisonProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.guest(),
      ).storageKey,
      'course.learning.comparison.v1.ZW4tZnI.g',
    );
    expect(
      ComparisonProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.account('French/User:7'),
      ).storageKey,
      'course.learning.comparison.v1.ZW4tZnI.a.RnJlbmNoL1VzZXI6Nw',
    );
  });

  test(
    'SQL comparison commit retries exact identity without a second write',
    () async {
      final owner = LearningOwner.account('comparison-store-test');
      final auth = LearningAuthScope(owner: owner, generation: 4, ready: true);
      var notifications = 0;
      final harness = ComparisonLearningSqlTestHarness(
        catalogue: loadFrenchComparisonCatalogue(),
        currentAuth: () => auth,
        backendOwner: () => owner,
      );
      addTearDown(harness.dispose);
      final SqliteComparisonLearningRepository repository = harness
          .createRepository(
            owner: owner,
            generation: auth.generation,
            onCommitted: () => notifications++,
          );

      final empty = await repository.load();
      final command = repository.prepare(
        state: empty,
        activityId: comparisonActivityId,
        action: StartComparisonRun(
          sessionId: 'store-run',
          policy: LessonPolicy(),
        ),
      );
      final committed = await repository.submit(command);
      final database = await repository.database.open();
      final writesAfterCommit = await database
          .customSelect(
            'SELECT COUNT(*) AS row_count FROM learning_command_receipts',
          )
          .getSingle()
          .then((row) => row.read<int>('row_count'));
      final duplicate = await repository.submit(command);

      expect(committed.duplicate, isFalse);
      expect(committed.state.revision, 1);
      expect(committed.state.commitOrdinal, 1);
      expect(duplicate.duplicate, isTrue);
      expect(duplicate.state.revision, 1);
      expect(duplicate.state.commitOrdinal, 1);
      expect(notifications, 1);
      expect(
        await database
            .customSelect(
              'SELECT COUNT(*) AS row_count FROM learning_command_receipts',
            )
            .getSingle()
            .then((row) => row.read<int>('row_count')),
        writesAfterCommit,
      );

      final changed = ComparisonLearningCommand(
        scope: command.scope,
        authGeneration: command.authGeneration,
        activityId: command.activityId,
        expected: command.expected,
        expectedScopeRevision: command.expectedScopeRevision,
        token: command.token,
        submittedAt: command.submittedAt,
        action: StartComparisonRun(
          sessionId: 'changed-payload',
          policy: LessonPolicy(),
        ),
      );
      await expectLater(
        repository.submit(changed),
        throwsA(isA<LearningInvalidCommandException>()),
      );
      expect((await repository.load()).revision, 1);
      expect(notifications, 1);
    },
  );
}
