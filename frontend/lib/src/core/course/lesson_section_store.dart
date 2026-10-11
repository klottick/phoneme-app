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
/// - Public reads and outbox delivery expose only committed documents: an
///   in-flight or later-rejected preferences write is never returned or
///   uploaded.
/// - Stored entry metadata (`processedSessionId`, `processedAttemptCount`)
///   is validated against the stored checkpoint: a corrupt entry is unusable
///   (see [loadLessonSection]) and a new answer is never acknowledged as a
///   duplicate because of it.
abstract class LessonSectionStore {
  /// Returns the stored checkpoint for [lessonId], or null when the lesson
  /// has no usable saved state.
  ///
  /// A stored value that is not a snapshot map is reported as absent. Stored
  /// snapshot maps that fail validation are reported with [FormatException],
  /// as are entries whose `processedSessionId` or `processedAttemptCount`
  /// does not match the stored checkpoint (mismatched, missing, wrong-type,
  /// negative, or inflated counters). The caller surfaces both the same way
  /// and starts a fresh session; the next valid save replaces the entry.
  /// Missing metadata is not a resumable state: it is recovered by that
  /// replacement, not by reinterpreting the entry.
  Future<Map<String, dynamic>?> loadLessonSection(String lessonId);

  /// Persists [checkpoint] as the lesson's last saved session state.
  ///
  /// The snapshot must be the stored state itself, exactly one
  /// `advance`/`reviewMistakes` transition from it, or the first (zero-attempt)
  /// save of a new session. Unrecorded answers and changed outcomes at a
  /// stale attempt count are rejected.
  ///
  /// A valid snapshot captured from a state the store has already moved past
  /// (a different session at nonzero attempts, a checkpoint behind the stored
  /// one, or a same-session state that diverged at the stored attempt count,
  /// where another instance committed a different outcome) is rejected with
  /// [LessonSectionConflictException]; callers may offer an explicit reload
  /// for that case.
  Future<void> saveLessonSection(
      String lessonId, Map<String, dynamic> checkpoint);

  /// Records one submitted answer atomically: the checkpoint, the existing
  /// listening aggregate, and the compatible answer event (activity
  /// `discovery-section`). Attempts already recorded on this session are
  /// ignored instead of recorded twice.
  ///
  /// An answer for a different stored session, or one that skips ahead of
  /// the stored attempt count, is rejected with
  /// [LessonSectionConflictException]; callers may offer an explicit reload
  /// for that case.
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
  ///
  /// Completing a different session, a checkpoint behind the stored one, or a
  /// same-session debrief that diverged from the stored one at the same
  /// attempt count, is rejected with [LessonSectionConflictException];
  /// callers may offer an explicit reload for that case.
  Future<void> completeLessonSection(
      String lessonId, Map<String, dynamic> checkpoint);
}

/// A validly captured session snapshot conflicts with the store's already
/// advanced state: a different session on a started lesson, a checkpoint
/// that cannot be the store's next write (behind, ahead by more than one
/// attempt, or diverged from the stored one at the same attempt count where
/// another instance of the same session committed a different outcome).
///
/// Every rejected or conflicting write is refused without persisting
/// anything; the failure type says what kind of input was refused:
/// - a malformed snapshot or metadata — a caller checkpoint that is not a
///   parseable snapshot, or an unusable stored entry (corrupt checkpoint or
///   processed metadata) encountered at load — fails with a [FormatException];
/// - a validly captured snapshot that conflicts with the store's advanced
///   state (a different or stale session, a diverged outcome at the same
///   attempt count, a gap in the answer sequence) fails with this typed
///   conflict; an explicit reload of the saved state, then redoing the step,
///   can succeed;
/// - any other rejected input or ownership/auth failure — fabricated answers,
///   rewritten outcomes already committed, mismatched sound or correctness,
///   a first answer that is not a fresh first pass, ownership/account
///   rejection — fails with a plain [StateError]; resending the same input
///   never succeeds.
///
/// Only a corrupt *stored* entry follows the corrupt-snapshot contract (a
/// fresh session may start, and its next valid save replaces the entry);
/// malformed caller-supplied input is simply rejected — fresh-save recovery
/// does not apply to invalid input itself.
class LessonSectionConflictException extends StateError {
  LessonSectionConflictException(super.message);
}
