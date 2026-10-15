class _LearningException implements Exception {
  const _LearningException([this.cause]);
  final Object? cause;
  String get message => 'Learning progress is unavailable.';
  @override
  String toString() => message;
}

class LearningSaveException extends _LearningException {
  const LearningSaveException([super.cause]);
}

class LearningUnavailableException extends _LearningException {
  const LearningUnavailableException([super.cause]);
}

class LearningConflictException extends _LearningException {
  const LearningConflictException([super.cause]);
}

class LearningOwnerChangedException extends _LearningException {
  const LearningOwnerChangedException([super.cause]);
}

class LearningInvalidCommandException extends _LearningException {
  const LearningInvalidCommandException([super.cause]);
}

class LearningCorruptException extends _LearningException {
  const LearningCorruptException([super.cause]);
}

class LearningUnsupportedVersionException extends _LearningException {
  const LearningUnsupportedVersionException([super.cause]);
}

class LearningContentChangedException extends _LearningException {
  const LearningContentChangedException([super.cause]);
}
