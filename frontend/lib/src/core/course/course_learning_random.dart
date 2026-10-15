import 'dart:math';

import 'course_learning_command.dart';

/// A [Random] adapter which records every persisted-transition draw.
class RecordingLearningRandom implements Random {
  RecordingLearningRandom(this._source);

  final Random _source;
  final List<RandomDraw> _draws = [];

  List<RandomDraw> get draws => List.unmodifiable(_draws);

  @override
  int nextInt(int max) {
    if (max < 1) throw ArgumentError.value(max, 'max');
    final value = _source.nextInt(max);
    _draws.add(RandomDraw(upperBound: max, value: value));
    return value;
  }

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(0x100000000) / 0x100000000;
}

/// A [Random] adapter that consumes a recorded transcript exactly once.
class ReplayLearningRandom implements Random {
  ReplayLearningRandom(List<RandomDraw> draws)
      : _draws = List.unmodifiable(draws);

  final List<RandomDraw> _draws;
  int _index = 0;

  @override
  int nextInt(int max) {
    if (max < 1) throw ArgumentError.value(max, 'max');
    if (_index >= _draws.length) {
      throw StateError('Random transcript is missing a required draw.');
    }
    final draw = _draws[_index++];
    if (draw.upperBound != max || draw.value < 0 || draw.value >= max) {
      throw StateError(
          'Random transcript draw does not match its requested bound.');
    }
    return draw.value;
  }

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(0x100000000) / 0x100000000;

  void requireExhausted() {
    if (_index != _draws.length) {
      throw StateError('Random transcript contains unused draws.');
    }
  }
}
