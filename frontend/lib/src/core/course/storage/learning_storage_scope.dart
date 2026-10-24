import '../course_attempt.dart';

/// A learning profile family as stored by the normalized SQLite schema.
enum LearningFamily {
  course('course'),
  comparison('comparison'),
  sentenceHunt('sentence-hunt'),
  spelling('spelling');

  const LearningFamily(this.databaseValue);

  final String databaseValue;
}

/// Exact owner/course/family identity for one normalized learning scope.
///
/// Values are intentionally kept verbatim: ownership is an exact database key,
/// not a concatenated storage key or a trimmed display value.
final class LearningStorageScope {
  const LearningStorageScope({
    required this.owner,
    required this.courseId,
    required this.family,
  });

  final LearningOwner owner;
  final String courseId;
  final LearningFamily family;

  String get ownerKind => owner.isGuest ? 'guest' : 'account';
  String get ownerId => owner.userId ?? '';
  String get databaseFamily => family.databaseValue;

  @override
  bool operator ==(Object other) =>
      other is LearningStorageScope &&
      other.owner == owner &&
      other.courseId == courseId &&
      other.family == family;

  @override
  int get hashCode => Object.hash(owner, courseId, family);
}
