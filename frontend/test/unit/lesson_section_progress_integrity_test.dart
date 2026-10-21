import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/course_learning_widget_store.dart';

void main() {
  test(
    'malformed old typed preference remains untouched and is not imported',
    () async {
      const raw = '{"schemaVersion":2,"activities":[';
      SharedPreferences.setMockInitialValues({
        'course.learning.v2.ZW4tZnI.g': raw,
      });
      final harness = CourseLearningSqlTestHarness();
      expect((await harness.store.load()).history, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'course.learning.v2.ZW4tZnI.g',
        ),
        raw,
      );
    },
  );

  test(
    'future typed preference schema is non-destructive and is not imported',
    () async {
      const raw = '{"schemaVersion":99,"futureField":"retain"}';
      SharedPreferences.setMockInitialValues({
        'course.learning.v2.ZW4tZnI.g': raw,
      });
      final harness = CourseLearningSqlTestHarness();
      expect((await harness.store.load()).history, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('course.learning.v2.ZW4tZnI.g'), raw);
      expect(prefs.getKeys(), contains('course.learning.v2.ZW4tZnI.g'));
    },
  );

  test(
    'invalid old typed root remains byte-preserved while SQL starts empty',
    () async {
      const raw = '[]';
      SharedPreferences.setMockInitialValues({
        'course.learning.v2.ZW4tZnI.g': raw,
      });
      final harness = CourseLearningSqlTestHarness();
      final state = await harness.store.load();
      expect(state.history, isEmpty);
      await harness.start('lesson:en-fr-u-y');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('course.learning.v2.ZW4tZnI.g'), raw);
      expect((await harness.store.load()).activities, hasLength(1));
    },
  );
}
