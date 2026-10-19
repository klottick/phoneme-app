final class LearningCursorPosition {
  const LearningCursorPosition({
    required this.generation,
    required this.sequence,
    required this.revision,
  });
  final int generation;
  final int sequence;
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is LearningCursorPosition &&
      other.generation == generation &&
      other.sequence == sequence &&
      other.revision == revision;
  @override
  int get hashCode => Object.hash(generation, sequence, revision);
}

final class LearningReceiptIdentity {
  const LearningReceiptIdentity({
    required this.activityId,
    required this.token,
    required this.canonicalCommand,
    required this.before,
    required this.after,
    required this.commitOrdinal,
  });
  final String activityId;
  final String token;
  final String canonicalCommand;
  final LearningCursorPosition before;
  final LearningCursorPosition after;
  final int commitOrdinal;
}

/// Historical v2 attempts do not persist receipt header fields.
final class LearningRetainedReceiptIdentity {
  const LearningRetainedReceiptIdentity({
    required this.activityId,
    required this.token,
    required this.canonicalCommand,
    required this.generation,
    required this.sequence,
  });
  final String activityId;
  final String token;
  final String canonicalCommand;
  final int generation;
  final int sequence;
}
