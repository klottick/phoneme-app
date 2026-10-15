import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_random.dart';

void main() {
  test('recording random freezes exact nextInt bounds and values', () {
    final source = RecordingLearningRandom(Random(31));
    final values = [source.nextInt(7), source.nextInt(11), source.nextInt(3)];
    expect(source.draws.map((draw) => draw.upperBound), [7, 11, 3]);

    final transcript = source.draws;
    expect(() => (transcript as List).clear(), throwsUnsupportedError);
    final replay = ReplayLearningRandom(transcript);
    expect([replay.nextInt(7), replay.nextInt(11), replay.nextInt(3)], values);
    replay.requireExhausted();
  });

  test('replay rejects unused, missing and wrong-bound random draws', () {
    final extra = ReplayLearningRandom([
      RandomDraw(upperBound: 2, value: 1),
      RandomDraw(upperBound: 3, value: 1),
    ]);
    extra.nextInt(2);
    expect(extra.requireExhausted, throwsStateError);

    final missing = ReplayLearningRandom(const []);
    expect(() => missing.nextInt(2), throwsStateError);

    final wrongBound = ReplayLearningRandom([
      RandomDraw(upperBound: 3, value: 1),
    ]);
    expect(() => wrongBound.nextInt(2), throwsStateError);
  });

  test('recorded and replayed draws reject invalid bounds', () {
    final recording = RecordingLearningRandom(Random(3));
    expect(() => recording.nextInt(0), throwsArgumentError);
    expect(
        () => ReplayLearningRandom(const []).nextInt(0), throwsArgumentError);
  });
}
