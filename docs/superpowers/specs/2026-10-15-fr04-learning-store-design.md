# FR-04: clean learning-store replacement

## 1. Intent, approval and scope

**Status:** Written spec for user review. The conversational design is approved;
this document and an implementation plan still require review before product
implementation. This is not authorization to dispatch implementation workers.

The intended outcome is dependable local learning history and resume behavior
for the English-to-French course. Record what the learner actually answered,
retain incorrect first attempts after successful retries, and provide honest
per-sound practice summaries without calling them mastery or pronunciation grades.

The user confirmed the app is pre-alpha with no users, selected a clean storage
replacement over extending the mixed progress document, and approved:

- Breaking internal storage APIs and saved-data formats rather than maintaining
  local migration/compatibility machinery.
- One typed store used by discovery, other course lessons, drills, arcade,
  home and progress screens, not just the `/u/`–`/y/` pilot.
- Atomic answer/checkpoint/mistake/summary persistence, stable submission
  identities, account isolation, retryable failures and bounded detailed history.
- Fresh versioned storage; old development progress is neither imported nor
  deleted. Supported cloud progress remains separate from local detailed history.
- Preservation of current lesson rules, gameplay, content and audio behavior.

This spec replaces the local persistence/API requirements in the older
[first-section design](2026-10-11-french-first-section-design.md), and the legacy
progress-preservation requirement of scoped FR-04 in the
[roadmap](../plans/2026-10-10-french-learning-path-tickets.md). It does not replace
the curriculum contracts, section teaching policy or reference-audio policy.
Those documents remain historical records; their old compatibility requirements
must not be implemented alongside this replacement.

### Included

- Immutable attempts, activity snapshots, mistake records, completion records,
  skill summaries and supported-cloud outbox entries.
- A typed repository, a pure transition/validation layer, one local persistence
  adapter and a separately testable cloud projection/delivery boundary.
- Switching every current `CourseProgressStore` consumer to that repository.
- Reliable resume for discovery and equivalent safe checkpoints for other
  lessons, drills and arcade; only the discovery flow acquires the existing
  discovery completion/remediation policy.
- Updating home/progress/review screens to consume typed results and accurately
  label first-presentation practice, retries, game evidence and backup limits.

### Excluded

- New lessons, games, sentence puzzles, path/map UI, placement or assessment UI,
  spaced-repetition scheduling, new completion policies or revised game rules.
- Pronunciation evaluation, recording uploads, recording history, cloud history
  download/merge, backend schema/RPC changes or local model dependencies.
- Import, deletion or delivery of the old local progress/outbox/arcade documents.
  Already uploaded server progress remains untouched and may include older runs.
- Refactoring other legacy language-only progress, profile, streak or assessment
  systems merely because they also store data.

Unpublished Sound Match work, all other branches/worktrees, diagnostic evidence,
reference-audio bytes/provenance/licences and root `LICENSE` remain untouched.
FR-15, qualified French review, real browser/native playback and release gates
remain separate. Implementation workers use the user's selected GPT-6 Luna,
not the earlier Qwen preference; the exact available ID is resolved at dispatch.

## 2. Architecture and ownership

Current baseline: published `origin/main` at
`d3532f7f6fb2bead4698402992680c6eb3b8d203`.

`CourseProgressStore` currently combines raw-map preferences, serialized writes,
discovery transition checking, aggregates and cloud delivery. Its consumers are
`DiscoveryLessonScreen`, `CourseLessonScreen`, `DrillScreen`, `ArcadeScreen`,
`HomeScreen` and `CourseProgressScreen`. Arcade boards are separately persisted,
and `WordMove.evidence` drops the selected word/tile information needed for
typed history. These are the storage boundaries being replaced, not preserved
behind a permanent compatibility facade.

Use small modules under `frontend/lib/src/core/course/`:

| Module | Responsibility |
| --- | --- |
| `course_attempt.dart` | Immutable answer payload, evidence context and attempt record; no widgets/plugins |
| `course_learning_state.dart` | Immutable owner-scoped document, run handles, checkpoints, mistakes and completions |
| `course_learning_transition.dart` | Pure command validation, evaluation and next-state calculation |
| `course_skill_summary.dart` | Typed buckets and incremental summary calculations |
| `course_learning_store.dart` | Repository contract and coordinated read/commit implementation |
| `course_learning_persistence.dart` | Codec and local preferences I/O; raw JSON never leaves this boundary |
| `course_learning_sync.dart` | Allowlisted legacy RPC projection and retryable delivery |
| `course_learning_providers.dart` | Auth-bound repository and typed read-model providers |

These are responsibility boundaries, not a demand for a class per field. Reuse
existing pure `LessonPolicy`, `LessonSectionSession` and curriculum types rather
than introducing a second completion engine. Typed activity-specific checkpoints
may live in focused companion files if necessary. Widgets do not encode JSON,
manufacture correctness or directly call preferences for course/arcade progress.

Remove the superseded `CourseProgressStore` and raw-map `LessonSectionStore`
contract once callers/tests switch. Provider names may change together; do not
retain unused APIs solely to make old tests compile. Update tests to the new
contract while retaining their behavioral assertions. Curriculum/audio contracts
and unrelated language-only persistence remain unchanged.

## 3. Typed state and evidence

### 3.1 Owner and document

`LearningOwner` identifies guest or an exact account ID; `courseId` is separate.
Neither uses string concatenation that can alias guest/account identifiers.
An auth generation is captured by the repository to detect even an A→B→A switch.

`CourseLearningState` contains schema version `2`, owner/course identity, a
nonnegative document revision, a monotonic commit ordinal, bounded recent
attempts with their batch command fingerprints, activity slots, unresolved
mistakes, cumulative summary buckets, completion records, arcade best scores
and a supported-event outbox.

All public collections are detached, immutable and validated. Integers are
strict integers, not coerced strings/doubles; UTC timestamps are parseable;
identifiers are nonblank and revisions positive where applicable. Serialization
uses explicit enum strings and canonical field ordering for identity comparisons.

### 3.2 Attempt record

Each `CourseAttempt` stores:

- Owner/course, stable submission ID, activity ID, run generation, command
  sequence, item ID, item occurrence, content revision and commit ordinal.
- Answered-at UTC time frozen when the answer is submitted, not refreshed on
  retrying its save. Commit time is separate; ordering uses commit ordinals,
  not a potentially moving wall clock.
- Exercise/answer kind, target phoneme(s), skill dimension, selected answer and
  the expected answer snapshot used for evaluation.
- Origin (`practice` or `game`), presentation (`firstInRun` or `repeatInRun`),
  and assistance flags (`explanationVisible`, `afterDebrief`, `answerRevealed`).
  An empty flag set means no tracked in-app assistance, not proof of an unseen
  item or independent performance outside the app.
- Objectively evaluated correct/incorrect result. Source content/review state
  and audio provenance (`pendingRecording` or `practiceSpeech` for current
  audible tasks, `notApplicable` for silent spelling) are recorded explicitly;
  playback failure is not an answer.

Assistance flags may coexist. Existing explanation-first lessons start with
`explanationVisible`; showing their reference answers also sets `answerRevealed`
for affected items. Discovery review after its debrief sets `afterDebrief`.
Track assistance already displayed in the run; closing a reference or retrying
a save must not relabel the attempt as unassisted. No new teaching help is added.

Use a sealed answer payload with the current task shapes:

| Shape | Stored selection and expected answer |
| --- | --- |
| Sound choice | Selected sound; permitted choices and expected sound |
| Drill word choice | Selected word ID/text; presented pair and expected word |
| Sound Match cue | Selected single matched family; cue word/ref and expected family |
| Word Match tile | Selected word identity and tile occurrence; target sound and authored membership boolean |

Capture submitted word/tile data before engines refill, collapse, clear chains
or change targets. A Word Match move produces one atomic batch containing one
attempt per explicitly selected tile, preserving existing evidence counts even
when two tiles contain the same word. Invalid geometry, automatic clears,
cascades and ambiguous Sound Match families produce no attempt.

The transition layer derives correctness, expected targets, skill and origin
from the registered activity/content rather than trusting a widget's boolean.
Pilot history includes its canonical curriculum exercise ID; its existing word
aliases may remain internal session item IDs. Other current lesson words,
minimal pairs and game words retain their actual source IDs and explicit
source revision `1`; do not invent missing curriculum exercise IDs. Any future
change to those sources' meaning must increment their revision.

No assessment submission is accepted in this increment. The store must reject
attempts to mark practice/game evidence as assessment or speaking accuracy.
Assessment and unassessed-speaking schema extensions belong to later tickets;
FR-04 must not ship dead scoring paths that bypass their gates.

### 3.3 Activity slots and checkpoint types

An activity slot is one current run for a registered activity: each course
lesson, `drill:minimal-pairs`, `arcade:sound`, or `arcade:word`. The registry is
finite for the installed course; arbitrary caller-generated activity names are
rejected. A run handle contains the activity, positive generation and revision.
Starting a replacement run increments the durable generation; callers cannot
choose or resurrect generations.

The slot's command sequence is monotonic across run generations, not reset on
new-run start. Each run revision begins at zero after its creation commit and
increments for every later committed command in that run. Keep per-item
presentation counts/assistance within the current run independently of pruned
attempt detail, so retention cannot turn a repeated item into `firstInRun`.

- **Discovery:** Preserve ordered items, policy, phase, answered state, finite
  mistake-only rounds and end-of-section debrief from `LessonSectionSession`.
  Store selected-answer/context evidence alongside its validated state.
- **Other lessons:** Store word index, submitted choice/feedback state and
  completion state. Preserve their current one-pass lesson rules; do not apply
  discovery's 80% rule to them. Label completion policy accordingly.
- **Drill:** Store pair sequence identity/revision, index and committed correct
  count. Resume at the next unanswered pair. Repeating a pair within the run
  is `repeatInRun`; never increment the displayed correct count before commit.
- **Arcade:** Store the existing board/engine snapshot, timer/session state,
  score and evidence command sequence together. Resume paused; random refill
  results are frozen in the submitted command and reused on a save retry.
  Score-only and unscored board changes still save their checkpoint.

Never resume heard/playback permissions, active timers, microphone state,
recording paths or temporary audio. Fresh user-triggered playback is required
before any restored listening item can accept an answer. Current audio
cancellation, navigation and busy-ownership safeguards remain intact.

### 3.4 Mistakes and completion

Unresolved mistakes are keyed by activity, source item, content revision and
skill/target. Store the first wrong submission ID/time, latest wrong outcome,
failure count and most recent run/attempt reference. Repeated errors update
that record; a correct answer to that same item/target/revision resolves it.
A different word with the same sound cannot clear it. Word Match tile
occurrences contribute separate attempts but the same word/target mistake.

Persist mistakes independently of the current run and lesson completion.
Starting a fresh run or meeting 80% does not silently clear them. The discovery
round queue still follows the current run's latest outcomes in authored order;
this ticket does not add an automatic cross-activity scheduler. Other activities'
mistakes contribute to the existing review-sound entry points, not a new game
mode. Items no longer compatible with installed content remain stored and are
labeled unavailable for targeted review, rather than reinterpreted or deleted.

Completion records identify lesson, content revision, policy kind/revision and
commit time. Discovery completion requires the committed debrief and saved
threshold/coverage policy. Other lessons record their existing one-pass
completion; neither is labeled mastery. Completing again is idempotent for the
same lesson/revision/policy. No new progression locks are added.

## 4. Repository commands and transaction semantics

The public interface exposes typed equivalents of:

- Load the course read model and bounded recent history.
- Load/resume an activity; start or explicitly replace its run.
- Submit an activity command with its run handle, expected run revision,
  next command sequence and frozen payload.
- Complete a supported lesson from its committed checkpoint.
- Retry supported-cloud delivery and read its typed result.

The implementation plan must freeze exact Dart signatures and shared fixtures
before workers depend on them. No independent worker may invent a neighboring
schema/API. Commands include answer, advance, review-round start, game move,
checkpoint/pause and completion; a generic arbitrary-map write API is prohibited.

### Commit algorithm

1. Capture immutable command input and the owning auth generation.
2. Join the process-wide serialized repository read/write coordinator. Reads
   use it too; independent repository instances cannot expose optimistic state
   or overwrite each other's lesson/game updates.
3. Recheck ownership, read committed state and validate schema/identity. Check
   the activity generation, command sequence, expected run revision, content
   revision and legal transition. Mutations of unrelated activity slots use the
   latest document and do not conflict merely because its revision changed.
4. Derive the complete candidate: attempts, checkpoint, unresolved mistakes,
   lifetime buckets, score/completion and supported outbox projections. Apply
   detail retention to that same candidate; never split a Word Match batch.
5. Recheck auth immediately before starting I/O, encode and perform one
   replacement write of the owner-scoped document. There is no per-attempt
   multi-key transaction. A candidate is not visible to readers or sync yet.
6. Only after successful persistence publish the new immutable committed state
   and return the committed run handle/result. On failure return a retryable
   save error with the command identity unchanged and no credited evidence.

Use the existing preferences dependency through an injected adapter; do not
add a database merely to replace this small pre-alpha store. The production
adapter must prevent the preferences cache's pre-acknowledgment update from
becoming visible: retain the last committed image, repair a rejected write's
cache, and keep reads/sync on the coordinator. If repair cannot be established,
mark that owner scope storage-unavailable until a verified reload/retry; never
continue on a possibly optimistic document. Negative-control tests must hold
the actual adapter's write future and exercise its failure path.

The guarantee is a single-document application commit within one app process,
not cross-tab/process locking or database-grade crash durability. A process
restart loads the last readable complete document; a partial/invalid document
follows the non-destructive corruption contract below. Multi-tab simultaneous
writers are unsupported and must not be advertised as safe; cross-context
transactions require a separately designed storage upgrade.

### Duplicate and conflict rules

For each activity, persist the current generation, last committed sequence,
run revision and canonical receipt for the most recent command. Each prepared
command also has a unique opaque operation token, frozen before its first
submission and reused on Retry. Two screens competing for the same next
sequence have different tokens: the loser gets a conflict, rather than being
misidentified as a mutated duplicate. Reusing one token with changed input is
an invalid submission. Recent answer batches retain a canonical full-command
fingerprint to prove their identities while their attempts remain retained.
Submission IDs derive from owner/course/activity/generation/sequence/token plus
the batch member index, using an unambiguous encoding; they are not regenerated
on save retries.

- Identical repeated latest command returns its committed acknowledgment,
  without changing evidence, checkpoint, summary or outbox. Validate identity
  and canonical payload before applying ordinary stale-revision rejection.
- Same retained command identity with a changed payload is an invalid
  submission, never an acknowledged duplicate.
- An older proven identical command in the current run is a no-op and returns
  the current handle, never an old checkpoint. If its proof was pruned, reject
  it as stale rather than crediting it again or pretending its payload was
  verified. A proof covers the complete command, including its batch and frozen
  resulting checkpoint, not just one retained attempt's correctness.
- Old run generations, sequence gaps, divergent revisions and replaced-run
  writes are typed conflicts. Creating a new run is an explicit command, not
  something an answer may do implicitly. A run start itself uses the slot's
  next sequence/generation and has a retryable receipt, including the first
  run, so losing its acknowledgment cannot accidentally create two runs.
- New slots begin with a persisted zero-answer state. Answer-only snapshots,
  fabricated completion, changed old outcomes or unknown content are invalid
  commands and cannot manufacture evidence.

This bounded high-watermark design prevents replay after history pruning
without retaining an ever-growing UUID tombstone list.

## 5. Retention and summaries

Keep the newest **2,000 attempt records per owner/course**, ordered by commit
ordinal and deterministic batch member order. Drop oldest whole answer batches
until the bound is satisfied; the current maximum Word Match batch is 16, so
the retained count may be slightly below 2,000. Prune a batch's command fingerprint
with its attempts. Outside those bounded batch fingerprints, keep only the
current checkpoint and most recent command receipt per registered activity
slot. A test-only retention limit may be injected; production uses 2,000.

Detailed pruning does not subtract from lifetime summary counts, remove
unresolved mistakes, erase completion or remove undelivered cloud events.
Persist cumulative summaries at commit time; never reconstruct them from the
remaining recent history and present that as lifetime evidence. Bounded detail
does not mean that the entire document or offline outbox is bounded forever.

Summary keys separate sound, skill, origin, presentation and assistance.
Expose correct/total counts with sample sizes and unresolved-mistake counts.
Practice and game counts stay separately labeled. A correct retry cannot
increase the first-presentation numerator or erase its wrong denominator.
Any combined practice total must retain access to its separate buckets.

Empty listening/spelling buckets show no evidence; speaking and held-out
assessment show **not assessed**. Do not infer calibrated mastery, confidence,
placement or production quality. No new assessment score is derived from
practice/retry history. Audio-source labels remain honest about pending
recordings and practice-only speech, even when answer correctness is objective.

Recent-history queries are storage/read-model functionality, not authorization
for a new history navigation feature. The current progress screen shows the
separated summary counts; its review variant lists unresolved/reviewable sound
groups using existing lesson/game routes. This replaces the old arbitrary
"correct means due tomorrow" aggregate timestamp with actual unresolved
mistakes; it does not introduce a spaced-repetition algorithm.

## 6. Ownership, recovery and UI behavior

### Fresh namespace

Use `course.learning.v2.<encoded-course>.<encoded-owner>`; owner encoding has
distinct guest/account tags and escaped components. No code reads, writes,
deletes or syncs `course.v1.*` or `arcade.v1.*` during normal new-store use.
Old arcade boards therefore do not get paired with fresh evidence counters.
Do not clear preferences globally or reset auth/profile/streak storage.

The progress screen explains: "This alpha uses a new progress format. Earlier
development progress has not been imported." The copy does not imply old data
was deleted. It may remain static alpha disclosure for this increment.

### Account changes

Providers rebuild on owner/auth-generation changes; each screen captures its
repository before playback or submission, not after awaiting it. A store for
guest/A/B never changes its storage destination. Account changes cancel new
commands for the captured generation and retire playback/UI work as today.

If auth changes after a platform write has begun, its successful commit may
finish only in the captured owner's document; it can never be redirected to the
new owner or credited on that owner's screen. Suppress obsolete UI callbacks
and do not start cloud delivery for that departed identity. Later access by the
original owner can read its committed result. Guest/account histories are never
automatically copied or merged.

### Typed errors and recovery

| Result | Required behavior |
| --- | --- |
| Save failure | Retain the frozen pending command in memory; Retry uses the same identity/payload. Do not advance or credit it |
| Conflict/stale receipt | Offer reload of committed state; do not silently replace it with the screen's candidate |
| Owner changed | Retire old screen work and load the active owner's state |
| Invalid command | Developer-facing validation failure; never retry as though storage were offline |
| Corrupt stored document | Keep exact original bytes untouched; show unavailable/retry, not an empty usable store |
| Unknown schema version | Keep exact bytes and refuse writes; do not downgrade/reset it |
| Content revision changed | Keep historical evidence; mark the old run nonresumable and offer explicit new-run start |
| Audio unavailable/cancelled | No attempt, mistake or accuracy change; preserve current playback error/cancellation policy |

This increment does not add a reset/delete/export recovery UI. Whole-document
corruption blocks writes for that scope without destroying recoverable data;
explicit repair/import tooling is later work. A content-incompatible but valid
document is not corrupt: a new current-revision run can be started explicitly,
without re-evaluating historical answers against new content.

### Pending UI state

Authoritative counters, completion and progress providers change only on commit.
Discovery keeps its current feedback/debrief timing and retry UX, adapted to
typed commands. Other lessons/drills must offer retry before advancing past an
unsaved answer; a failed save must not permanently lock an item as answered.

Arcade captures a candidate engine/checkpoint and displays save-pending status;
pause its timer and block further moves while committing or waiting for Retry.
On failure preserve that candidate and allow retry or explicit reload of the
committed board. Never rerun random refill on a save retry. Save unscored moves,
pause/end transitions and score updates through the same typed activity path.
The pause is storage backpressure, not a new game timer/scoring rule.

All delayed load/save/playback settlements are generation-guarded. A completion
or game-save callback cannot clear a newer recorder/audio/save busy owner.

## 7. Supported cloud backup only

Keep the current `record_course_events` RPC and its supported event shapes.
Generate supported projections in the same local commit, with stable event IDs
derived from the committed operation and batch member. The wire encoding must
stay within the RPC's 128-character ID limit; use a deterministic bounded digest
if the full local identity is longer. Verify uniqueness with fixtures; never
truncate identifiers into possible collisions.

- Correct/incorrect listening/spelling practice and valid game answers may
  project to the current answer event (`sound`, `skill`, `correct`, `activity`).
- Only the five currently registered lesson IDs may project completion events.
- Only existing `sound`/`word` games project nonnegative best-score events.
- No selected answer, expected key, detailed attempt, mistake, checkpoint,
  recording/path, speaking or assessment payload enters this outbox.
- Guest commits queue no cloud events. Existing old-namespace outboxes remain
  untouched, undelivered by the new store and excluded from new backup results.

Delivery is serialized per owner/course and sends at most 100 supported events
per RPC call. It reads only committed state; network I/O runs outside the local
writer. Acknowledgment removes only acknowledged IDs from the latest document,
preserving newer local events. Failed sends retain their IDs; replay relies on
server `(user_id, id)` deduplication. Recheck captured owner/auth generation
before every batch; abort later batches on change. An already sent request may
finish under its original credentials but never gets reassigned to a new user.

Sync returns a typed supported-progress result, not a boolean meaning complete
backup. UI copy: "Supported scores and answer totals backed up. Detailed
history, mistakes and lesson resume stay on this device." When offline, say
the supported backup is pending and local commits remain saved. State clearly
that prior server totals are not reset/imported, so server totals need not equal
the fresh local summary. No cloud-read reconciliation or historical completion
upgrade is added here. Outbox growth during long offline use is preserved rather
than silently dropping undelivered progress; storage exhaustion is a retryable
save failure, not permission to omit an event from an otherwise credited commit.

## 8. Verification and acceptance

Use test-first behavior regressions, real production persistence/provider paths
where applicable, held futures and failing-write fakes. Tests must demonstrate
the named boundary, not just assert that a helper was called.

### Pure contract tests

- Strict codecs and immutable collections; unknown/corrupt schemas and owner
  mismatches; canonical identity encoding and fixed content snapshots.
- Actual selections, expected keys, provenance and objective evaluation for all
  four current answer shapes; reject invented assessment/speaking evidence.
- Wrong-first/correct-retry buckets stay distinct; no inflated sample counts;
  two selected copies of one game word remain two tile attempts.
- Same-item mistake resolution, same-sound nonresolution, cross-run persistence,
  content-revision isolation and completion-with-mistakes.
- Finite discovery review, configurable 80%, full coverage and debrief timing
  remain the shipped policy; legacy completion remains separately identified.

### Store and synchronization tests

- Save answer/checkpoint/mistakes/summary/projection as one committed image;
  hold/reject actual persistence and prove reads/sync see only committed data.
- Retry after rejection, cache repair and failed repair; no duplicate summary,
  attempt or outbox event. Crash/reopen fixtures exercise complete and corrupt
  images without claiming platform crash-durability guarantees.
- Same identity/same payload, changed payload, sequence gap, replaced run,
  competing same-run writers and concurrent unrelated lesson/game writes.
- Lost run-start acknowledgment, lost answer acknowledgment, pruning beyond
  2,000 records and replay after proof pruning; no tombstone leak or recounting.
- Whole-batch pruning; lifetime counts, unresolved mistakes, completion and
  outbox survive pruning and process reopen.
- Guest/A/B and A→B→A changes at load/playback/queue/platform-write/sync
  boundaries; a held old-owner write can affect only its captured namespace.
- Seed literal old progress/arcade/outbox bytes and prove no import, deletion,
  mutation or old-event delivery; leave unrelated preference keys untouched.
- Supported RPC projection allowlist, stable bounded IDs, 100-event batching,
  failure/replay, acknowledgment versus concurrent writes and auth change.

### Integration/widget tests

- All six consuming screens use typed providers/repository; no runtime
  `CourseProgressStore`, raw course-map consumer or direct arcade progress write
  remains. Include a source search as a supplementary check, not the main test.
- Discovery resume/debrief/retry/conflict/accessibility and account-switch
  regressions preserve current content order and audio ownership.
- Lesson and drill saves cannot double-credit on Retry or advance on failure;
  reopened checkpoints require fresh playback and resume correctly.
- Sound Match retains current evidence exclusions/bonus rules. Word Match
  records pre-collapse selections atomically with the frozen post-move board;
  partial batch failure or restore cannot duplicate evidence.
- Arcade save backpressure pauses timers and prevents another move; Retry does
  not reroll the board. Paused/end/score checkpoints restore coherently.
- Home completion and progress/review summaries use committed typed results;
  new-format, sample-size, game separation, not-assessed and partial-backup copy
  is visible and correct.

### Required implementation delivery evidence

The implementation plan names exact test files/commands before execution.
Controller verification includes full `flutter test`, `flutter analyze`, the
existing Python suite (`python3 -m unittest discover -s scripts -p 'test_*.py' -v`),
the audio verifier (`python3 scripts/verify_french_audio.py --repo-root .`), and a
JavaScript web build, plus targeted boundary/negative-control evidence. Flutter
commands run from `frontend/`; the Python commands run from the repo root. No browser sandbox
bypass is authorized. Existing browser/native playback and linguistic gates
remain pending unless separately verified; a web build is not playback evidence.

Deliver implementation through scoped PRs based on published `origin/main`.
Obtain independent code review, inspect the actual PR head/base and available
GitHub checks, rerun affected checks if either changes, merge only when no
blocking findings remain, and verify the published merge. Missing CI is not a
passing CI result. Preserve branch/worktree/process records rather than cleaning
them automatically. Record URLs, reviewed heads, merge commits, exact commands,
results and remaining gates in the local task ledger.

## 9. Handoff gate

This document deliberately chooses a fresh local model and a coordinated caller
cutover, not a backward-compatible store extension. The detailed defaults for
review are 2,000 retained attempts, current-run/high-watermark deduplication,
single-process preferences commits, non-destructive corruption blocking and
supported-progress-only cloud delivery.

After the user approves this written spec, create a reviewed implementation
plan with exact APIs, file ownership, test-first task boundaries and sequential
worker delivery. Do not begin implementation from conversational approval alone.
