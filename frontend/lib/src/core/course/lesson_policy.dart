/// Completion policy for a listening lesson section.
///
/// A section passes once the number of items with a correct latest outcome
/// reaches [requiredCorrect] for the section's size, computed from
/// [completionThresholdPercent]. The threshold is configurable (default 80%)
/// and validated: constructor and method misuse throws [ArgumentError], while
/// invalid serialized values thrown by [fromJson] are [FormatException]s.
class LessonPolicy {
  /// Creates a policy requiring [completionThresholdPercent] percent of
  /// items to be answered correctly.
  ///
  /// [completionThresholdPercent] must be an integer between 1 and 100
  /// inclusive; otherwise an [ArgumentError] is thrown. Defaults to 80.
  LessonPolicy({int completionThresholdPercent = 80})
      : this._(_validatedThreshold(
          'completionThresholdPercent',
          completionThresholdPercent,
        ));

  /// Internal entry point for values already validated by [fromJson].
  const LessonPolicy._(this.completionThresholdPercent);

  /// The required percentage of correct answers, from 1 to 100.
  final int completionThresholdPercent;

  static int _validatedThreshold(String name, int value) {
    if (value < 1 || value > 100) {
      throw ArgumentError.value(
        value,
        name,
        'Must be an integer between 1 and 100.',
      );
    }
    return value;
  }

  /// The minimum number of correct outcomes required to pass a section of
  /// [itemCount] items, rounded up.
  ///
  /// [itemCount] must be positive; otherwise an [ArgumentError] is thrown.
  int requiredCorrect(int itemCount) {
    if (itemCount < 1) {
      throw ArgumentError.value(
        itemCount,
        'itemCount',
        'Must be a positive number of items.',
      );
    }
    // Integer ceiling of itemCount * percent / 100 without floating point:
    // ceil(a / b) = (a + b - 1) ~/ b for positive a and b.
    return (itemCount * completionThresholdPercent + 99) ~/ 100;
  }

  /// Whether [correct] correct outcomes out of [total] items reaches
  /// [completionThresholdPercent].
  ///
  /// Requires [total] > 0 and 0 <= [correct] <= [total]; otherwise an
  /// [ArgumentError] is thrown.
  bool isPassing({required int correct, required int total}) {
    if (total < 1) {
      throw ArgumentError.value(total, 'total', 'Must be positive.');
    }
    if (correct < 0 || correct > total) {
      throw ArgumentError.value(
        correct,
        'correct',
        'Must be between 0 and $total.',
      );
    }
    return correct >= requiredCorrect(total);
  }

  /// Serializes to exactly the `completionThresholdPercent` key.
  Map<String, dynamic> toJson() {
    return {
      'completionThresholdPercent': completionThresholdPercent,
    };
  }

  /// Restores a policy from a map produced by [toJson].
  ///
  /// The map must contain exactly one valid [completionThresholdPercent]:
  /// a missing key, a wrong type, a fractional value, or an out-of-range
  /// value throws a [FormatException]. Integer-valued numbers (such as the
  /// doubles produced by JSON decoding) are accepted.
  factory LessonPolicy.fromJson(Map<String, dynamic> json) {
    final Object? raw = json['completionThresholdPercent'];
    int? percent;
    if (raw is int) {
      percent = raw;
    } else if (raw is double && raw == raw.truncateToDouble()) {
      percent = raw.toInt();
    }
    if (percent == null) {
      throw FormatException(
        'completionThresholdPercent must be an integer: $raw',
        json,
      );
    }
    if (percent < 1 || percent > 100) {
      throw FormatException(
        'completionThresholdPercent must be between 1 and 100: $raw',
        json,
      );
    }
    return LessonPolicy._(percent);
  }
}
