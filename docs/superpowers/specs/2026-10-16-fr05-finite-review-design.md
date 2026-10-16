# FR-05: finite-round lesson sessions

## 1. Intent, authority and scope

Help a learner work through a discovery section, understand the explanation at
its end, and revisit actual mistakes without an automatic or endless retry loop.
Lesson completion is a transparent coverage-and-correctness rule, not a validated
estimate of phoneme mastery.

The user selected **finite review rounds**, then approved this design direction:
reuse the existing session engine, attempt every authored item before debrief,
offer optional mistake-only rounds, preserve unresolved mistakes after passing,
and retain faithful resume, retry and account isolation. The earlier draft's
two-intervening-item retry delay and twelve-answer sitting cap are not adopted.
This document is the written-spec review artifact; implementation and its plan
remain unapproved until their respective review gates are satisfied.

Authority and baseline:

- [French backlog, FR-05](../plans/2026-10-10-french-learning-path-tickets.md):
  intent and acceptance requirements, subject to the policy decision above.
- [First-section design](2026-10-11-french-first-section-design.md): the shipped
  finite-round pilot, whose behavior is retained rather than replaced.
- [Curriculum design](2026-10-11-french-curriculum-design.md): authored identities
  and content boundaries.
- [FR-04 design](2026-10-15-fr04-learning-store-design.md): typed evidence,
  coordinated local commits, immutable Retry, run ownership and storage policy.
- Published baseline: PR37 merge
  `3238e6ece7b2253ec416a9b1066ed2976fe3e35b` on GitHub `main`.

The executable scope is the existing discovery listening-choice section and its
reusable pure session contract. Do not convert the remaining legacy one-pass
lessons, create new curriculum, or add future exercise renderers in this ticket.
Those changes belong to their own reviewed FR-06–FR-09 scope. The finite-round
policy is the default design for future discovery sections; registering or
projecting additional content requires separate content and integration review.

## 2. Approach and component boundaries

Retain `LessonSectionSession`, `LessonPolicy` and FR-04's typed discovery
commands/checkpoints as the single implementation path. Compare their existing
behavior and regressions against this contract; change only demonstrated gaps.
If a requirement is already implemented, cite and verify it rather than rewrite
it. A requirement with working behavior but inadequate regression coverage needs
a test, not an invented runtime redesign.

Alternatives considered:

- A new generic `lesson_session.dart` scheduler could anticipate future exercise
  types, but would duplicate a working state machine and churn checkpoint
  interfaces before those consumers are designed. Not selected.
- Documentation-only ticket closure would avoid runtime churn, but is premature
  until the requirement/evidence audit and applicable verification are complete.

| Component | Responsibility |
| --- | --- |
| `LessonSection` / curriculum projection | Ordered required item identities, choices, expected targets and content revision |
| `LessonPolicy` | Validated configured threshold and integer ceiling calculation |
| `LessonSectionSession` | Pure first-pass, answered-item, finite-round, debrief and completion-eligibility transitions |
| `DiscoveryCheckpoint` / learning codec | Detached typed snapshot and validated restore using existing FR-04 boundaries |
| Lesson / learning transitions | Validate the typed action; derive correctness and evidence from registered content; update mistakes and completion |
| Learning repository | Atomically commit state/evidence, provide idempotent Retry and preserve owner-scoped state |
| Discovery screen / section view | Playback capability and lifecycle, answer controls, immediate correctness, debrief and explicit learner actions |

Do not add a second persistence service, public serialization layer, scheduler,
random selection policy or clock-dependent retry mechanism. Keep the current
codec ownership and existing validated session serialization boundary; this
ticket does not refactor those internals for their own sake.

## 3. Session and explanation behavior

### 3.1 First pass

Start with every required item exactly once in authored order. The pilot retains
its ten items; there is no global hard-coded section size. Empty, duplicate or
incompatible item identities fail validation rather than producing a partial
section.

For each item, require successful user-triggered playback before accepting a
listening answer. A scored submission produces immediate right/wrong feedback
through the existing save-aware flow, without teaching explanations, displayed
answer words or answer-revealing hints. Do not add an artificial feedback delay;
do not enable advancement or claim a saved result before its commit succeeds.
One item accepts at most one scored submission per round.

The submitted choice and correctness feedback remain visible until the learner
advances. Advancing after the last submitted item enters debrief, even if every
answer was wrong. A wrong answer, repeated error or early-help action must not
unlock the explanation mid-round.

### 3.2 Debrief and optional review

Debrief shows the teaching explanation, latest correct count, required count and
unresolved items. Finishing a section attempt is distinct from passing the
completion rule. Below-threshold learners can still access the explanation and
leave; they are not forced into another round.

At debrief, `Review mistakes` is available when the current run has unresolved
items, including when it already meets the threshold. An explicit selection
captures exactly those item IDs, once each, in original authored order. Correct
items do not enter that queue. Each queued item can be submitted once in that
round; a wrong retry stays unresolved but is not appended to the same queue.
The final advance returns to debrief. Another round requires another explicit
learner action. With one unresolved item, one answer and advance end the round;
with no unresolved items, no review round can start.

During review exercises, the teaching explanation is not displayed again on the
active puzzle. Having already seen the debrief is not undone: retries retain
their after-debrief/repeated-item assistance context and earlier outcomes in
history. They must not be reclassified as fresh, unassisted or held-out evidence.

Every round is user-initiated and bounded by its captured queue, ending at
debrief. The number of optional rounds is not capped; this is not a promise of
a fixed sitting duration. There is no automatic restart, wall-clock deadline,
lives system or twelve-submission sitting limit. The learner may leave and resume
at any committed position. An unavailable item can block scored advancement, but
cannot force the learner to remain on the screen.

### 3.3 Completion

For `N` distinct required items and configured percentage `P`, require
`ceil(N * P / 100)` correct latest outcomes, calculated with integer arithmetic.
`P` defaults to 80 and must be an integer from 1 through 100. No learner-facing
configuration settings screen is added.

Eligibility requires all three conditions:

1. Every required item has at least one scored outcome.
2. The session is at debrief, not an answered-but-unadvanced final exercise.
3. The latest correct count meets the saved threshold.

A successful retry replaces that item's latest outcome for eligibility, not its
earlier historical attempt. Repeated successes cannot substitute for unseen
required items. Completion remains an explicit successfully persisted action;
an eligibility flag is not proof of a saved completion. Preserve the current
idempotent completion identity, policy kind/revision and threshold metadata.
Review-only route Finish must not award completion.

For discovery completion, identity is lesson ID, content revision, policy kind,
policy revision and threshold percentage. Record the threshold saved for the
current run, not a subsequently changed default. Re-finishing under that same
identity adds no duplicate; a later eligible run with a different saved threshold
records its own completion without rewriting or removing the earlier record.

Meeting the threshold or committing Finish must not erase remaining mistakes.
Resolve a durable mistake only through a correct scored answer for that same
activity/item/revision/skill-target identity, as in FR-04. Do not substitute an
unrelated example or mark all mistakes resolved on pass. Existing rules for
finished runs and explicit new runs remain; no automatic cross-activity or
cross-run review scheduler is introduced.

## 4. Persistence, failure and capability boundaries

Preserve current run identity, content revision, saved policy, phase, round,
ordered queue, position, current-round submission state, latest outcomes and
attempt count. Saved policy is authoritative on resume, even if a new default
is configured elsewhere. Keep the existing policy revision; there is no new
policy schema or storage namespace solely to name finite rounds.

Answers, historical attempts, mistake updates and their resulting checkpoint
commit together through the FR-04 repository. Advance, review start and Finish
also use the existing typed command path. A retryable persistence failure must
preserve the exact immutable pending command, captured owner/store and
continuation for Retry; no duplicate attempt, queue advancement, completion or
unlock may be claimed.
Concurrent or stale commands retain current revision/generation validation.
Typed conflicts, content changes and owner changes follow existing explicit
reload/recovery paths rather than blindly retrying an invalid command.

In particular, a held or failed Advance retains the committed answered item and
its feedback as the visible authoritative state. Disable further answer/advance
actions while it is pending; Retry resends that frozen Advance command, not the
answer and not a newly prepared advance. Publish the next position or debrief
only after its acknowledgement. Review-start and Finish also publish their
resulting navigation/state only after successful persistence.

Resume an unanswered item, an answered item awaiting advance, a partly completed
review round or a debrief without rebuilding the queue or replaying submissions.
Do not restore playback permission, active audio or microphone state. A restored
unanswered listening item needs fresh successful playback. Already committed
answers are not submitted again merely because the screen remounts.
If the answer committed but Advance did not, restore its committed choice and
feedback, awaiting explicit advance. A still-live same-owner pending command can
instead follow existing frozen-command Retry/resume recovery; pending UI intent
is not invented from a checkpoint after a process restart.

Playback failure/cancellation is a capability state, not a scored wrong answer.
It creates no attempt, mistake, synthetic answer or coverage credit and does not
silently skip the item. Offer playback Retry or leave/resume. Do not introduce
unassessed-speaking records or new schema variants: speaking and assessment
remain outside FR-05. Preserve actual audio-source provenance and existing
recording-failure behavior; never silently substitute TTS for a failed recording.
Preserve the current visible distinction: an actual playback failure shows
generic, non-answer-revealing audio feedback; a user/system cancellation is
quiet and retryable, not reported as an audio failure. Neither grants fresh
playback permission, and stale callbacks affect neither the old nor new screen.

Reject malformed or incompatible snapshots using current recovery behavior;
do not silently reinterpret content or reset a recoverable sibling activity.
Preserve bytes/quarantine and require the existing explicit fresh-run recovery
where applicable. Guest/A/B owners remain separate; delayed load, playback or
save completion cannot mutate or activate a replacement owner's session.

## 5. Acceptance and verification

Implementation planning must map every row to actual source and named tests,
marking existing verified coverage, a missing regression, or a reproduced defect.
Existing test counts alone do not establish compliance. New behavior fixes need
a runnable failing regression before the runtime edit. No replacement filenames
or public APIs are required merely to match the older draft ticket.

| Requirement | Required evidence |
| --- | --- |
| Threshold and rounding | Default80: 7/10 fails, 8/10 passes, 6/8 fails, 7/8 passes; configured75: 6/8 passes; configured100: 9/10 fails, 10/10 passes; invalid percentages rejected |
| Coverage and phase | Passing count before full coverage or before debrief cannot complete; duplicate submission cannot inflate coverage |
| Debrief access | All-wrong first pass still reaches explanation; no explanation or solution leakage before section end, including after errors |
| Finite review | Exact unresolved IDs in authored order; wrong retry does not grow its round; all-wrong, mixed, single-item and empty-review boundaries terminate or reject appropriately |
| History and mistakes | Retry updates latest outcome while retaining earlier attempt; actual repository keeps unresolved mistakes after pass/Finish; matching correct outcome resolves only its own mistake |
| Resume | Unanswered, answered-awaiting-advance, debrief and partial-review restore retain queue/outcomes/policy; changed default cannot alter saved eligibility |
| Capability failure | Failed/cancelled playback creates no wrong result, attempt, mistake or coverage; retry requires successful fresh playback |
| Durable completion | Held/failed save cannot claim completion; exact Retry does not duplicate evidence; review-only Finish preserves existing completion records |
| Isolation and recovery | Existing guest/A/B, stale callback, command revision, corrupt state and changed-content regressions remain passing |
| Honest retry evidence | After-debrief and repeat attribution survive the typed commit and resume path, not just local session counters |

Primary existing suites are `lesson_policy_test.dart`,
`lesson_section_session_test.dart`, `course_learning_lesson_transition_test.dart`,
`course_learning_store_test.dart` and discovery/widget commit, resume, recovery
and repeat suites under `frontend/test/`. Pure tests establish selection and
eligibility; repository tests establish durable evidence; widget tests establish
what is visible and actionable. Do not use an obsolete pre-FR-04 storage fixture
as the sole proof of runtime persistence.

Final code delivery requires independent actual-PR review and fresh controller
verification of the exact head/current base: relevant regressions, full Flutter
tests, analysis and JavaScript release build. Check scope and unchanged audio,
licence, dependency and backend files. Merge only the reviewed GitHub PR and
verify its published tree; preserve branches, worktrees and process evidence.
Missing GitHub checks are not a passing CI result.
This is an implementation-delivery requirement, not a claim that this written
spec or FR-05 is already accepted. A passing unchanged-product baseline does not
replace the requirement/evidence audit or the user's spec and plan review gates.

## 6. Non-goals and outstanding gates

No new exercises/content, legacy-lesson conversion, map, progression locks,
cross-activity scheduler, calibrated mastery score, assessment, microphone
workflow, backend/RPC changes, recording uploads, cloud evaluation, dependencies
or generated reference audio. Preserve unpublished Sound Match work and old
development data. No broad storage migration, deletion or serialization rewrite.

All pending French recordings remain pending; technical verification is not
linguistic/licensing approval. Real browser/native playback and cancellation,
qualified French audio/content/licensing review, live Supabase verification,
privacy, FR-15 and production release gates remain separate. No browser sandbox
bypass is authorized. A successful JavaScript web build does not certify Wasm,
real playback or a pronunciation evaluator.
