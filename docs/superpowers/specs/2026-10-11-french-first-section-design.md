# First discovery section: /u/ versus /y/

## Scope and authorization

The user requested small tasks implemented by local `qwen3.8` subagents, each
opening a PR, with the controller reviewing, merging, and maintaining state.
This batch delivers the first listening section, not the entire French-path
backlog. The explicit create-plan-then-execute request supplies the execution
handoff; remaining low-risk defaults are recorded below and in the ledger.

Confirmed requirements: immediate right/wrong feedback, teaching explanations
only at section end, configurable 80% completion, mistakes brought back,
browser and native targets, and no cloud speech evaluation or recording upload.

No new dependencies, generated audio, automatic pronunciation scores, overworld,
sentence/spelling exam, or microphone changes in this batch. Those stay in the
broader backlog. Existing device French TTS is visibly labeled practice audio;
this batch does not claim reviewed recorded audio or a graded placement exam.

## Learning flow

Reuse the existing `en-fr-u-y` lesson ID and explanation, so backend registration
and historical progress remain valid. The ten items, in order, are `tout`, `tu`,
`rouge`, `rue`, `vous`, `lune`, `doux`, `jus`, `loup`, `mur`; expected sounds
alternate `u`, `y`. Item IDs are the word texts. Choices are `/u/` and `/y/`.
Words, IPA transcriptions, meanings, and the explanation are not displayed during
active listening puzzles. Choice labels identify the possible sounds, not the
answer. Playback uses the current `CourseAudio.speak(word)` abstraction.

After successful playback, submit one choice. Show only `Correct` or `Not yet`
immediately. Disable further submissions for that item. `Next word` advances;
after the last answer it becomes `See section explanation`. Neither first wrong
answers nor repeated errors reveal the explanation early.

After all first-pass answers, enter the debrief whether or not 80% was reached.
Show the teaching explanation, correct count, threshold, and unresolved words.
This avoids locking a struggling learner away from the explanation. Ten items
require eight correct latest outcomes at the default threshold. Once eligible,
`Finish` saves completion. `Review mistakes` is available whenever any latest
outcome is wrong, even when the section already passes. It starts a finite round
of only unresolved items, in original order, then returns to the debrief.

Retries replace the latest item outcome for completion but retain earlier
aggregate attempts. No retry on a correct item can substitute for a required
unseen item. Every round is finite (at most ten submissions); leaving saves the
last successful state. There are no lives or forced infinite sessions. This
batch deliberately uses round-boundary remediation instead of arbitrary
two-item delays and a twelve-submission cap.

## Contracts

### Policy — `lesson_policy.dart`

`LessonPolicy({int completionThresholdPercent = 80})` validates integer 1–100.
`int requiredCorrect(int itemCount)` rejects nonpositive counts and rounds up
`itemCount * percent / 100`. `bool isPassing({required int correct, required int
total})` validates 0 <= correct <= total and total > 0. `Map<String, dynamic>
toJson()` and `factory LessonPolicy.fromJson(Map<String, dynamic> json)` use
exactly `completionThresholdPercent`; invalid serialized values throw
`FormatException`. Constructor/method misuse throws `ArgumentError`.

### Content — `lesson_section.dart`

Immutable `LessonSectionItem` has `id`, `word`, `expectedSound` strings.
Immutable `LessonSection` has `lessonId`, `title`, `explanation`, integer
`contentRevision`, `List<LessonSectionItem> items`, and `List<String> sounds`.
Expose `frenchUySection` and `LessonSection? sectionForLesson(String lessonId)`;
only `en-fr-u-y` maps to the new section. Reuse existing curated words and
explanation, do not alter other lessons or their APIs.

### Session — `lesson_section_session.dart`

`enum LessonSectionPhase { exercise, debrief }`.
`LessonSectionSession({required List<String> itemIds, required String sessionId,
int contentRevision = 1, LessonPolicy? policy})` copies/validates unique nonempty
IDs, nonempty session ID, positive revision; policy defaults to `LessonPolicy()`.
Expose read-only `itemIds`, `queue`, `position`, `round`, `attemptCount`,
`sessionId`, `contentRevision`, `policy`, `phase`, `answered`, `lastCorrect`,
`currentItemId`, `latestAnswers`, `unresolvedItemIds`, `correctCount`,
`answeredItemCount`, `canComplete`.

`void submit(bool correct)` records the current outcome and increments attempts
once, leaving the item visible/answered. `void advance()` requires an answered
exercise, moves to the next item, and enters debrief at round end.
`void reviewMistakes()` requires debrief and unresolved items; starts the next
round. Invalid state transitions throw `StateError`. `canComplete` requires
debrief, every item attempted, and policy eligibility.

`toJson()` serializes version `1`, all state above, and policy.
`factory LessonSectionSession.fromJson(Map<String, dynamic> json, {required
List<String> itemIds, required int contentRevision})` rejects incompatible
version/content/IDs, unknown or duplicate queued IDs, bad positions/types/counts,
unknown outcomes, inconsistent answered/phase/current outcome, and impossible
first-pass coverage. All corruption throws `FormatException`, not partial
restore. The saved policy is authoritative on resume, not a new default.

### Persistence — `lesson_section_store.dart` and existing progress store

Define abstract `LessonSectionStore` with:
- `Future<Map<String, dynamic>?> loadLessonSection(String lessonId)`
- `Future<void> saveLessonSection(String lessonId, Map<String, dynamic> checkpoint)`
- `Future<void> recordLessonSectionAnswer(String lessonId, Map<String, dynamic>
  checkpoint, {required String sound, required bool correct})`
- `Future<void> completeLessonSection(String lessonId, Map<String, dynamic> checkpoint)`

`CourseProgressStore implements LessonSectionStore`. Expose
`lessonSectionStoreProvider` in `course_progress.dart`, watching the authenticated
user like `courseProgressProvider`. Use the existing serialized `_update` writer
and `course.v1.<scope>` data, adding a `sections` map without losing unknown keys,
old completions/evidence/scores/outbox. Entries contain `checkpoint`,
`processedSessionId`, and `processedAttemptCount`.

Validate supported section content/session before writes. Reject stale owners.
Initial save has zero attempts; advance/review saves cannot fabricate unrecorded
answers. A submitted checkpoint must be answered with matching lastCorrect and
current item's expected sound; its attempt number must be the next processed
number for that session. Duplicate/older already processed numbers are no-ops
and must not revert the current checkpoint. New sessions start at attempt zero;
do not permit silently switching IDs mid-answer. Invalid input/state fails
without mutating preferences.

Recording an answer atomically saves its checkpoint, updates the existing
listening aggregate once, and queues only the existing compatible answer event
with activity `discovery-section`. Completing validates `canComplete`, atomically
saves the checkpoint and existing lesson completion, queues completion only once.
Session snapshots never enter the cloud outbox and contain no recordings.
Old aggregate calls continue working. Incorrect item IDs remain in the saved
session even if a different correct word shares their phoneme.

### UI boundaries

`DiscoverySectionView` in `features/course/discovery_section_view.dart` is
stateless: `section`, `session`, `heard`, `busy`, nullable `error`, callbacks
`onListen`, `onAnswer(String)`, `onNext`, `onReview`, `onFinish`, `onRetrySave`.
Required callbacks are non-null; buttons disable themselves according to state.
It never writes progress or initializes audio. Render practice-TTS copy, progress,
immediate correctness, errors, debrief and reviewed word references. Do not add
recording controls to the active listening section.

`DiscoveryLessonScreen({required String lessonId, bool review = false,
LessonPolicy? policy})` owns session loading, playback, saves, retries and
lifecycle. Load/store errors provide retry; corrupt snapshots show an explanatory
message and a fresh session without overwriting history until a new saved action.
Each screen generation is bound to its captured store/owner. Account/provider
changes load a fresh owner's state; delayed load/playback/save callbacks cannot
modify a departed or replacement screen. Backgrounding invalidates playback and
requires fresh playback before answering; disposal stops audio.

Submission shows correctness immediately while persistence is pending; Next and
Finish stay disabled until save succeeds. Failed save exposes `Retry saving`
using the same session/attempt, never records it twice, and never advances.
Advance/review use a validated session clone and publish the new phase only after
a successful save. Finish calls `completeLessonSection`, except `review=true`
only saves and leaves existing completions unchanged. Only successful Finish
navigates back. Missing French audio cannot be marked incorrect or heard.

Route `/course-lesson/en-fr-u-y` to this screen, retaining `?review=true`;
all other lesson routes keep `CourseLessonScreen`. Unknown lesson behavior stays
unchanged. No home/navigation reskin in this batch.

## Validation and rollout

Workers use only `ollama/qwen3.8:27b`, no nested subagents. One implementation
worker/PR at a time; controller independently reviews spec compliance, code
quality, diff scope and test evidence, then reruns tests before merge. No worker
may merge or force-push. PRs target GitHub `main` from `origin/main`; existing
unpushed local Sound Match commits are preserved, not bundled/published.

Each task must demonstrate failing tests before implementation and passing
focused tests afterward. Full Flutter tests/analyzer gate code merges; final
JavaScript build verifies integration. Phone layout and fake lifecycle/account
tests are automated; real French voice/mobile behavior remains explicitly manual.
Reference recordings and linguistic validity are separate follow-up gates.

The status ledger names branch, workspace, agent, commits, PR, review findings,
verification evidence, merge result, and every coordinator ruling. It remains
available after completion; do not delete the process record.
