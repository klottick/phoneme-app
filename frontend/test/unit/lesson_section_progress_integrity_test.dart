import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/course_learning_preferences_harness.dart';

void main() {
  test('malformed typed document stays unavailable without overwrite',
      () async {
    final harness = PreferencesLearningHarness();
    const raw = '{"schemaVersion":2,"activities":[';
    SharedPreferences.setMockInitialValues({harness.scope.storageKey: raw});
    await expectLater(
        harness.store.load(), throwsA(isA<LearningCorruptException>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(harness.scope.storageKey), raw);
  });

  test('future typed schema is non-destructive and cannot be downgraded',
      () async {
    final harness = PreferencesLearningHarness();
    const raw = '{"schemaVersion":99,"futureField":"retain"}';
    SharedPreferences.setMockInitialValues({harness.scope.storageKey: raw});
    await expectLater(harness.store.load(),
        throwsA(isA<LearningUnsupportedVersionException>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(harness.scope.storageKey), raw);
    expect(prefs.getKeys(), contains(harness.scope.storageKey));
  });

  test('a present but invalid typed root is not treated as an empty first run',
      () async {
    final harness = PreferencesLearningHarness();
    const raw = '[]';
    SharedPreferences.setMockInitialValues({harness.scope.storageKey: raw});
    await expectLater(
        harness.store.load(), throwsA(isA<LearningCorruptException>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(harness.scope.storageKey), raw);
  });
}
