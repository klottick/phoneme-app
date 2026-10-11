/// Persistence contract for a discovery listening section.
///
/// Implementations store the validated session snapshot next to the legacy
/// lesson progress on-device and keep cloud events compatible with the
/// existing answer/completion outbox shape.
///
/// Required guarantees:
/// - Writes validate the section content and the snapshot before mutating
///   anything; invalid input or state fails without changing persisted data.
/// - A submitted checkpoint is applied exactly once; duplicate or older
///   checkpoints are no-ops and never revert a newer one.
/// - A new session starts with zero attempts; silently switching session IDs
///   mid-answer, fabricating outcomes, and writes from a captured store whose
///   signed-in account changed are all rejected.
/// - Session snapshots never enter the cloud outbox and contain no recordings.
abstract class LessonSectionStore {
  /// Returns the stored checkpoint for [lessonId], or null when the lesson
  /// has no usable saved state.
  ///
  /// A stored value that is not a snapshot map is reported as absent. Stored
  /// snapshot maps that fail validation are returned as-is so the caller can
  /// surface them through `LessonSectionSession.fromJson` and choose between
  /// resuming and starting a fresh session.
  Future<Map<String, dynamic>?> loadLessonSection(String lessonId);

  /// Persists [checkpoint] as the lesson's last saved session state.
  ///
  /// The snapshot must be the stored state itself, exactly one
  /// `advance`/`reviewMistakes` transition from it, or the first (zero-attempt)
  /// save of a new session. Unrecorded answers and changed outcomes at a
  /// stale attempt count are rejected.
  Future<void> saveLessonSection(
      String lessonId, Map<String, dynamic> checkpoint);

  /// Records one submitted answer atomically: the checkpoint, the existing
  /// listening aggregate, and the compatible answer event (activity
  /// `discovery-section`). Attempts already recorded on this session are
  /// ignored instead of recorded twice.
  Future<void> recordLessonSectionAnswer(
    String lessonId,
    Map<String, dynamic> checkpoint, {
    required String sound,
    required bool correct,
  });

  /// Completes the section once [checkpoint] satisfies its own policy.
  ///
  /// The checkpoint must be the stored state or the unrecorded `advance` out
  /// of it at the same attempt count; the existing lesson-completion event is
  /// queued at most once.
  Future<void> completeLessonSection(
      String lessonId, Map<String, dynamic> checkpoint);
}
