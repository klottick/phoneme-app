# Task 6 lesson and drill caller subunit report

## Status

**Lesson/drill caller subunit implemented and targeted verification passed; parent
Task 6 remains incomplete and unmergeable.** This subunit migrates only the
legacy lesson and drill callers and adapts their existing lifecycle tests. It
does not modify the three outstanding cutover/game/progress RED probes, any
other caller, or remove old runtime modules. No merge was performed.

## Typed caller behavior

- `CourseLessonScreen` and `DrillScreen` load and submit through the captured
  `CourseLearningStore`, using typed activities, checkpoints, and immutable
  commands. No legacy progress store/provider/key reference remains in either
  runtime file.
- Answer and finish persistence failures keep the pending command and captured
  store for explicit retry; advancement and exit remain blocked until commit.
  Resume uses committed checkpoint feedback and requires fresh playback.
- Store-owner replacement invalidates old generations and resets owner-specific
  UI state, preventing delayed saves/playback/recording work from publishing into
  a replacement owner.
- Corrupt/unavailable state remains blocked until explicit reload retry;
  incompatible content offers an explicit new run. Lesson reference assistance
  records typed observation. Review finish uses
  `FinishLearningActivity(recordCompletion: false)`.
- Drill items use canonical `frenchDrillPairs` registry order. Existing
  playback, recording, navigation, and teaching assertions remain in the
  lifecycle suites.

## Regression mapping

| Coverage | Test evidence |
| --- | --- |
| Existing lesson playback/lifecycle policy and stale playback settlements | `course_audio_lifecycle_test.dart` — included in 47 passing cases |
| Recorder permission/start/stop, route disposal, held finish, and suspension | `course_recording_lifecycle_test.dart` — included in 47 passing cases |
| Drill playback retirement, failed persistence retry, and end-session behavior | `drill_audio_lifecycle_test.dart` — included in 47 passing cases |
| Lesson/drill failed-answer retry submits same command and credits once | `course_learning_lesson_drill_commit_test.dart` |
| Reopen resumes lesson/drill without restored hearing | `course_learning_lesson_drill_commit_test.dart` |
| A→B→A stale drill commit cannot update current owner UI | `course_learning_lesson_drill_commit_test.dart` |
| Production typed repository persists answer with mocked preferences | `course_learning_lesson_drill_commit_test.dart` |
| Corrupt-state explicit retry, reference assistance, review completion suppression | `course_learning_lesson_drill_commit_test.dart` |
| Existing discovery resume and review-repeat integration | `course_learning_resume_test.dart`, `discovery_lesson_review_repeat_test.dart` |

The three existing probes `course_learning_cutover_test.dart`,
`course_learning_game_commit_test.dart`, and
`course_learning_progress_test.dart` remain unmodified and unstaged.

## Verification evidence

Commands ran from `frontend/` with
`PATH=/home/klottick/develop/flutter/bin:$PATH`:

- Earlier RED: the lesson/drill failed-answer feedback probes failed before the
  caller migration because the legacy callers did not expose typed pending-save
  retry feedback. They were then covered by the typed commit tests.
- `flutter test test/widget/course_audio_lifecycle_test.dart test/widget/course_recording_lifecycle_test.dart test/widget/drill_audio_lifecycle_test.dart test/widget/course_learning_lesson_drill_commit_test.dart`
  → **47 tests passed**.
- `flutter test test/widget/course_learning_resume_test.dart test/widget/discovery_lesson_review_repeat_test.dart`
  → **6 tests passed**.
- `flutter analyze lib/src/features/course/course_lesson_screen.dart lib/src/features/drills/drill_screen.dart test/widget/course_audio_lifecycle_test.dart test/widget/course_recording_lifecycle_test.dart test/widget/drill_audio_lifecycle_test.dart test/widget/course_learning_lesson_drill_commit_test.dart`
  → **No issues found**.
- `git diff --check` → **passed**.
- Search for `CourseProgressStore`, `courseProgressProvider`,
  `course_progress`, and `courseProgress` in both migrated runtime files
  → **no matches**.

Only the four owned suites plus the two named integration suites were run; the
full suite/build and parent Task 6 gates were not run by design.

## Delivery scope and remaining gates

Owned changes are limited to the two runtime callers, three existing lifecycle
suites, this dedicated commit/recovery test suite, and this report. Preserve the
pre-existing untracked RED probes and other local work. The parent migration,
source-wide legacy-store search, independent PR review, full integrated
verification, and controller acceptance remain outstanding. PR #37 remains the
only PR and must not be merged as part of this subunit.
