import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/course_learning_preferences_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('typed answer persists one committed attempt and separated summary',
      () async {
    final harness = PreferencesLearningHarness();
    await harness.start('lesson:en-fr-u-y');
    final commit = await harness.answerPilot('u');
    expect(commit.state.history.single.attempts.single.correct, isTrue);
    expect(commit.state.summaries.values.single.total, 1);
    expect(commit.state.summaries.values.single.correct, 1);
    final reopened = PreferencesLearningHarness();
    final loaded = await reopened.store.load();
    expect(loaded.history, hasLength(1));
    final loadedCursor = loaded.activities['lesson:en-fr-u-y']!.cursor;
    expect(loadedCursor.generation, commit.slot.cursor.generation);
    expect(loadedCursor.sequence, commit.slot.cursor.sequence);
    expect(loadedCursor.revision, commit.slot.cursor.revision);
  });

  test('retrying an acknowledged typed command cannot double credit', () async {
    final harness = PreferencesLearningHarness();
    await harness.start('lesson:en-fr-u-y');
    final command = harness.store.prepare(
      state: await harness.store.load(),
      activityId: 'lesson:en-fr-u-y',
      action: ChooseSound(
          selectedSound: 'u', audioSource: AttemptAudioSource.pendingRecording),
    );
    final committed = await harness.store.submit(command);
    final duplicate = await harness.store.submit(command);
    expect(duplicate.duplicate, isTrue);
    expect(duplicate.state.revision, committed.state.revision);
    expect(duplicate.state.history.single.attempts, hasLength(1));
  });

  test('legacy course and arcade bytes stay untouched and are not imported',
      () async {
    const oldCourse = '{"lessons":["en-fr-u-y"],"evidence":{"u":7}}';
    const oldArcade = '{"score":17}';
    SharedPreferences.setMockInitialValues({
      'course.v1.en-fr': oldCourse,
      'arcade.v1.en-fr.sound': oldArcade,
      'auth.token': 'keep',
    });
    final harness = PreferencesLearningHarness();
    final state = await harness.store.load();
    final prefs = await SharedPreferences.getInstance();
    expect(state.history, isEmpty);
    expect(state.completions, isEmpty);
    expect(prefs.getString('course.v1.en-fr'), oldCourse);
    expect(prefs.getString('arcade.v1.en-fr.sound'), oldArcade);
    expect(prefs.getString('auth.token'), 'keep');
  });

  test('corrupt typed bytes remain blocked and byte-preserved', () async {
    final harness = PreferencesLearningHarness();
    SharedPreferences.setMockInitialValues({harness.scope.storageKey: '{bad'});
    await expectLater(
        harness.store.load(), throwsA(isA<LearningCorruptException>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(harness.scope.storageKey), '{bad');
  });

  test('guest and account state use isolated typed preference keys', () async {
    final guest = PreferencesLearningHarness();
    final account =
        PreferencesLearningHarness(owner: LearningOwner.account('account-1'));
    expect(guest.scope.storageKey, isNot(account.scope.storageKey));
    await guest.start('lesson:en-fr-u-y');
    await account.start('lesson:en-fr-u-y');
    expect((await guest.store.load()).activities, hasLength(1));
    expect((await account.store.load()).activities, hasLength(1));
  });
}
