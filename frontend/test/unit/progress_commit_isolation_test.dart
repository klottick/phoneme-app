import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';

import '../support/course_learning_persistence_fakes.dart';
import '../support/course_learning_preferences_harness.dart';

void main() {
  test('reads wait for optimistic preferences write acknowledgment', () async {
    final persistence = FakeLearningPersistence()..holdNextWrite();
    final harness = PreferencesLearningHarness(persistence: persistence);
    final pending = harness.store.submit(harness.store.prepare(
      state: await harness.store.load(),
      activityId: 'lesson:en-fr-u-y',
      action: StartLearningRun(options: RunOptions()),
    ));
    await persistence.writeEntered;
    expect(persistence.cache, isNotEmpty,
        reason: 'the adapter cache is optimistically updated before ack');
    expect(persistence.platform, isEmpty);
    var readFinished = false;
    final read = harness.store.load().then((value) {
      readFinished = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(readFinished, isFalse,
        reason: 'same-process readers cannot see an unacknowledged candidate');

    persistence.releaseWrite(persist: false);
    await expectLater(pending, throwsA(isA<LearningSaveException>()));
    final committed = await read;
    expect(committed.activities, isEmpty);
    expect(persistence.cache, isEmpty,
        reason: 'rejected optimistic bytes are repaired to last committed');
  });

  test('unrelated lesson and drill commits preserve both current slots',
      () async {
    final persistence = FakeLearningPersistence();
    final harness = PreferencesLearningHarness(persistence: persistence);
    await harness.start('lesson:en-fr-u-y');
    final drill = harness.store.prepare(
      state: await harness.store.load(),
      activityId: 'drill:minimal-pairs',
      action: StartLearningRun(options: RunOptions()),
    );
    await harness.store.submit(drill);
    final state = await harness.store.load();
    expect(state.activities.keys,
        containsAll(['lesson:en-fr-u-y', 'drill:minimal-pairs']));
  });

  test('a save failure never exposes answer counts or completion early',
      () async {
    final persistence = FakeLearningPersistence();
    final harness = PreferencesLearningHarness(persistence: persistence);
    await harness.start('lesson:en-fr-u-y');
    final before = await harness.store.load();
    persistence.holdNextWrite();
    final command = harness.store.prepare(
      state: before,
      activityId: 'lesson:en-fr-u-y',
      action: ChooseSound(
          selectedSound: 'u', audioSource: AttemptAudioSource.pendingRecording),
    );
    final save = harness.store.submit(command);
    await persistence.writeEntered;
    expect(persistence.cache, isNotEmpty);
    persistence.releaseWrite(persist: false);
    await expectLater(save, throwsA(isA<LearningSaveException>()));
    final after = await harness.store.load();
    expect(after.history, isEmpty);
    expect(after.summaries, isEmpty);
    expect(after.completions, isEmpty);
  });
}
