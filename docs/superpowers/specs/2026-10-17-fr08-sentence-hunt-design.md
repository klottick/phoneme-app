# FR-08: optional sentence sound-hunt practice

## 1. Intent, authority and approval stage

Give learners a short, optional way to recognize a designated French phoneme
in connected speech: listen to a recording, select every written word containing
that sound, and submit one complete answer. Support vowels and consonants,
saved sessions, honest progress and recovery using the existing learning engine.
This is contextual listening/word-selection practice, not pronunciation grading
or a measure of phoneme mastery.

The user approved the conversational design: FLEURS as the initial recording
source; natural contiguous excerpts allowed; 15 curated items in three sections
of five; vowel, consonant and mixed-review progression; exact-set scoring;
section-debrief-only explanations; optional Home entry; independently saved
sections; default four-of-five completion; finite mistake review; and separate
local evidence. The original renderer-only FR-08 roadmap scope is therefore
expanded to a complete optional practice pilot, not to a new learning engine.

**Status: written specification awaiting user review.** Conversational approval
authorizes writing and publishing this document, not implementation. After the
user approves the written specification, prepare a separate implementation plan
and obtain its approval and execution choice before product changes, corpus
acquisition, audio processing or model installation. Publishing this document
does not approve its written detail or qualify any recording.

Authorities and baseline:

- [French curriculum design](2026-10-11-french-curriculum-design.md)
- [FR-06 listening contracts](2026-10-16-fr06-listening-exercises-design.md)
- [FR-07-A discovery/remediation](2026-10-16-fr07a-discovery-remediation-design.md)
- [FR-07-B comparison design](2026-10-17-fr07b-phoneme-comparison-design.md)
- [Published FR-07-B outcome](../status/2026-10-17-fr07b-phoneme-comparison.md)
- [FR-08 roadmap](../plans/2026-10-10-french-learning-path-tickets.md)
- [French reference-audio policy](../../french-reference-audio.md)
- Published `origin/main`: `ad6c789de75936cca51711f3e0d3b223ad56d880`.

## 2. Scope, alternatives and responsibility boundaries

### Selected approach

Reuse `CourseSentence`, `SentenceToken`, `SentenceHuntExercise` and
sentence-kind `CourseAudioReference` content contracts. Add a controlled hunt
renderer and sentence-specific typed evidence/profile adapter. Compose the
existing `LessonSectionSession`, exercise-owner helpers and shared learning
transaction coordinator. Add an optional Home entry, section chooser, dedicated
routes and separately labeled progress/recovery surfaces.

A standalone renderer would be smaller but would not deliver the selected saved
practice activity. A separate session/store implementation would duplicate
already-published ownership, retry and recovery behavior. Neither is selected.
No generic exercise-framework rewrite or unrelated refactor is authorized.

| Boundary | Responsibility |
| --- | --- |
| Offline content preparation | Source identities, original/derived assets, transcripts, contextual annotations, draft keys, credits and review evidence |
| Sentence catalogue/validator | Immutable sections/items/tokens/audio identities, exact-set keys, debrief notes and structural/availability checks |
| Controlled hunt renderer | Present target, transcript, neutral playback and independently selectable words; emit selected token IDs, not a grade |
| Sentence projection/transition | Resolve registered content, validate typed selection/playback provenance, derive one item outcome and local sentence evidence |
| Existing session engine | Authored first pass, finite mistake rounds, saved policy and section completion eligibility |
| Shared exercise owner | Transient hearing permission, single-submit claim, lifecycle/auth fences and immutable save retry |
| Shared transaction coordinator | Serialized owner-scoped commits, acknowledgements, receipts, conflicts, rollback and recovery |
| Sentence profile adapter | Independent versioned local state, codec, attempts, checkpoints, mistakes and completion; no identification/comparison payload mixing |
| Home/progress routes | Optional entry and three independent section states; preserve existing destinations and counts |

Out of scope: microphone capture, pronunciation evaluation, learner-recording
upload, cloud inference, new backend/RPC/outbox events, automatic readiness
promotion, assessment, FR-15, full French phoneme coverage, altered Sound Match
work, sandbox bypass and replacement of existing identification/comparison flows.

## 3. Pilot content and availability

### 3.1 Fixed shape and identities

Use one Home grouping, `en-fr-sentence-hunt`, containing three independently
saved section activities. The grouping is navigation, not a fourth session or
completion identity. Each section has content revision `1` initially.

| Suggested order | Section/activity ID | Fixed item IDs in authored order | Role |
| --- | --- | --- | --- |
| 1 | `en-fr-sentence-hunt-vowels` | `fr08-vowel-01` through `fr08-vowel-05` | Five vowel-target items |
| 2 | `en-fr-sentence-hunt-consonants` | `fr08-consonant-01` through `fr08-consonant-05` | Five consonant-target items |
| 3 | `en-fr-sentence-hunt-mixed` | `fr08-mixed-01` through `fr08-mixed-05` | Five new-context items revisiting targets from sections 1 and 2; include both vowels and consonants |

Each item has one target phoneme. Mixed means different items revisit different
targets, not multiple simultaneous targets. Aim for short intelligible phrases
with manageable reading demands and useful spelling/silent-letter distractors;
do not force a trap or target into unsuitable recorded speech.

No exact FLEURS rows, French texts, targets, crop boundaries or answer sets have
been selected or audited. This specification fixes the selection contract, not
an invented inventory. A later approved implementation plan must include a
content-packet task before runtime integration. That packet must supply all 15
exact records and evidence required below. Inability to fill the agreed shape
is a blocker to return to the user, not permission to reduce the item count,
switch sources silently or manufacture keys. Content choices within this
contract do not by themselves require a new architecture; changed scope does.

### 3.2 Recording source and derivative evidence

Use [Google FLEURS](https://huggingface.co/datasets/google/fleurs), French
`fr_fr`, initially selecting training-split candidates. The dataset card
declares CC BY 4.0 and provides audio, `transcription` and `raw_transcription`.
This is a source declaration, not an independent rights warranty or a finding
that every French clip suits this activity. Do not use benchmark held-out test
material as app assessment. Tatoeba is not an automatic fallback; return to the
user if FLEURS cannot supply suitable candidates.

Every candidate must retain:

- Dataset/repository revision, configuration, split, row ID and original audio
  path; row ID alone is not a unique recording identity.
- Retrieval URL/date and original bytes with measured byte length, SHA-256,
  sample rate, channel/frame count and duration.
- Source raw and normalized transcripts unchanged, plus the authored displayed
  excerpt text and an explanation of any transcript correction.
- The source's supplied creator/attribution information, exact licence evidence,
  licence link and retained legal text, and any required notices. Do not invent
  speaker names, accent qualifications or missing permissions.
- A distinct derived-clip identity/hash, source recording identity and start/end
  sample offsets with sample rate, processing tool/version/settings and change
  notice for every crop or necessary format conversion. Preserve originals;
  derived assets never overwrite them or existing word recordings.
- Reviewer decisions tied to the exact original/derived hashes and annotation
  revision; pending/rejected/accepted status must reflect real evidence.

Use whole recordings or one contiguous excerpt per item, cut at natural
word/phrase boundaries. No word stitching, internal speech deletion, time-stretch
or synthetic replacement is included. Review boundary coarticulation, liaison,
clipped consonants/vowels and remaining neighboring speech. If a clean excerpt
cannot be made, reject it. Display exactly the audible excerpt, preserving its
authored punctuation; do not pretend a fragment is the source's whole sentence.
The existing sentence model may represent this connected-speech excerpt.

### 3.3 Contextual phonemes and tokenization

Calculate draft contextual token phonemes offline after selecting audio/text.
Pre-existing phoneme tags are not required. Retain tool/model versions, settings,
input hashes and annotation edits. A grapheme-to-phoneme prediction is a draft;
forced alignment only locates a supplied hypothesis and does not prove it true.
Phoneme timestamps are not required for this word-selection pilot.

Check annotations and keys against the actual clip, including schwa omission,
elision, liaison and pronunciation variants. Word citation-form membership is
not an answer key. For this pilot, exclude any item whose target-to-word
membership remains ambiguous, including cross-word liaison attribution; do not
accept the union of possible pronunciations as one key. Another recording or
pronunciation variant needs its own sentence/audio/key identities.

Preserve exact text order and whitespace/punctuation coverage under the existing
validator. Give every word occurrence its own stable token ID, even when its
spelling repeats. Punctuation-only tokens have no selectable answer and no
phonemes. For the pilot, whitespace-delimited written words retain internal
apostrophes/hyphens as one selectable unit; a target anywhere in that recorded
unit makes the unit a match. Separate surrounding punctuation without changing
the displayed text. Teach this selection unit in the neutral instructions and
test French apostrophe/hyphen cases explicitly.

Every item must have at least one matching word and one genuine non-target
word; punctuation cannot satisfy the distractor requirement. The frozen key is
the set of selectable token IDs whose reviewed contextual phonemes contain the
target, not a set of word strings, letter matches or phoneme occurrences.

### 3.4 Validation and learner availability

Validate the full 15-item catalogue shape before publishing it as complete, and
validate each section atomically before starting/resuming it. Reject duplicate,
blank, unknown or mismatched IDs; wrong audio kind/text; missing/reordered token
coverage; invalid/nonselectable keys; absent targets/distractors; incomplete
provenance; and inconsistent section target roles. Diagnostics must be
deterministic. Structural validity is not French or rights approval.

Candidates remain pending until actual sentence-specific French/audio and
rights review evidence clears their respective gates. This document does not
inherit FR-07-B's permission to expose pending word audio as an alpha pilot.
Do not enable a learner section with pending, rejected, absent or structurally
invalid required content, and never filter its five items down to a smaller
session. Keep the section visibly unavailable with a local reason/retry path as
appropriate; valid sibling sections and older activities remain independent.
Engineering fixtures can verify the flow without claiming reviewed real assets.
Browser/native playback, assistive technology and release acceptance remain
separate from content validation and require their own evidence.

## 4. Exercise, scoring and debrief

The Home entry opens the section chooser in the suggested order above, without
prerequisite locks. Labels distinguish unavailable, not started, resumable and
completed sections. Preserve the current primary Home action, legacy links,
identification/comparison routes and existing microphone `/compare` behavior.
Use `/course-sentence-hunt` for the chooser and
`/course-sentence-hunt/<section-id>` for a registered section; unknown IDs fail
locally without falling back to an unrelated lesson.

Show a neutral target label/IPA, the exact transcript and one sentence/excerpt
playback control. Unlike early listening-only identification, this exercise
intentionally displays written words. Selection has non-color state, keyboard
activation, accessible word/position/selected labels and stable reading order.
Repeated words are independent controls. Do not expose phoneme annotations,
matching status, solution highlights or teaching in semantics/tooltips/errors.

Permit changing selected words and replaying before submission. A typed answer
contains selected token IDs, not a widget-supplied correctness flag. The domain
validates IDs, rejects duplicate/unknown/punctuation IDs, and derives correctness
by exact set equality with the registered frozen key. Selection order is
irrelevant. An empty set is a valid wrong answer after successful listening;
selecting all words is wrong because every item has a non-target word. One
submission produces one item attempt, never one attempt per tap or per target.

Claim submission synchronously before asynchronous persistence. Lock selections
after the claim. Immediate Correct/Not yet feedback is permitted for the whole
answer, without revealing missing/extra words or teaching. Do not advance,
publish durable progress or expose debrief before save acknowledgement.

At the saved section debrief, show latest correct count, saved threshold,
completion eligibility, and the correct token set with concise explanations
for the five items in authored order. Notes may explain missed targets and
plausible false positives from the actual saved answer, but never invent a
selection or learner diagnosis. An answered restore shows saved correctness,
not checkboxes reconstructed from the solution. Debrief can use retained typed
attempts for actual selection details; if unavailable, show declarative keys
and notes only. Teaching remains absent during all active review puzzles.

## 5. Playback, sessions and evidence

### 5.1 Hearing and lifecycle

Use the shared reference-audio facade and exercise-owner seam with recording-only
requests (`allowPracticeTts: false`). No uncovered-text/device-speech path may
answer this activity. Exact asset/reference and source must be checked against
the current request before granting hearing permission.

Bind playback to owner/auth generation, section, content revision, run generation,
round, item, exact reference and UI generation. One successful completed current
playback is required before submitting. Replay revokes hearing immediately;
failure/cancellation leaves the item unheard. Failure offers Retry/unavailable
and creates no wrong answer, mistake or attempt. Cancellation is quiet/unscored.
Serialize playback; ignore stale completions and prevent them from stopping a
newer request or unlocking an answer.

Prompt/round changes, route cover/exit, backgrounding, disposal, repository
replacement and owner changes retire live playback/grants. Restoring a saved
unanswered item starts with no selected words and requires fresh playback.
An already answered restore shows saved feedback without playback or inferred
selection. Hearing permission is never persisted.

### 5.2 Three independent finite sessions

Each section uses `LessonSectionSession` for its five-item authored-order first
pass and saved `LessonPolicy`, default 80% (four of five). Completion eligibility
requires all five attempted, saved debrief and the threshold met using latest
per-item correctness. Saved policy remains authoritative on resume; do not
replace it with a new default.

When unresolved items remain, offer finite mistake review even on a passing
debrief. Queue those items once in original order; wrong retries do not grow the
round, and its end returns to debrief. Never auto-repeat. An eligible practice
Finish records completion only after its transaction succeeds. A review-only
Finish creates no new completion. New runs reset only that section's active
draft, not history or sibling checkpoints. Leaving and resuming a section must
not abandon another section's saved session.

### 5.3 Typed local evidence and honest progress

Use one sentence-specific typed answer carrying selected token IDs, expected key
snapshot, item/sentence/audio/annotation/content identities, and actual successful
playback reference/source observation. The owner claims live hearing; the pure
transition validates structural provenance against registered content and
derives correctness. This is consistency checking, not cryptographic proof that
the learner listened.

Keep attempts, mistakes and review routing scoped to the exact section/item/
content revision, not spelling or an individual phoneme. Correct resolves only
that item/revision. Store first-in-run versus repeat-in-run and teaching exposure
separately. Mark debrief exposure durably for that section/content revision so
starting a new run does not turn teaching-exposed answers into claimed unaided
evidence. Any mixed aggregate must disclose review/teaching exposure.

Progress shows per-section latest committed state, clearly labeled sentence
practice, plus a distinct-section completed count from zero to three for the
currently registered content and completion policy. Repeated runs, receipts or
multiple qualifying Finish commands cannot inflate that count. Historical
revision/policy completions remain retained but are not silently current. Do
not add these attempts/completions to identification numerators, comparison
counts, sound summaries, mastery, or chronological-run counts.

## 6. Persistence, transactions and recovery

Use the existing `LearningProfileAdapter` and
`LearningTransactionCoordinator`/`LearningTransactionKernel`, not a cloned
writer or session engine. Sentence practice owns an independent schema-1 local
document family `sentence-hunt` with key
`course.learning.sentence-hunt.v1.<base64url-course>.<owner-tag>`, using existing
owner component encoding (`g` for guest, `a.<base64url-account>` for an account).
Its payload holds three independent section checkpoints/cursors, bounded typed
attempts/receipts, item mistakes, summaries, teaching exposure and completion.
The plan must specify concrete bounds before implementation.

Canonical command identity includes family, schema, exact owner/course/section,
content/policy/annotation identities, cursor and typed payload. Normalize the
selected set deterministically in authored token order for fingerprints; reject
duplicates rather than silently repairing them. Preserve existing v2 and
comparison key/schema/codec/command/fingerprint bytes. No import, migration,
dual-write, reset, deletion or cloud backup allowlist expansion is included.

Commit answer, attempt, mistake/summary update, checkpoint and receipt atomically.
Validate expected cursor, run/round/item, registered content, selection and
playback observation before deriving a candidate. Only acknowledged committed
state feeds progress. Frozen retry retains exactly the original command,
selection, observed source, owner and receipt; no replay or new hearing grant
is needed to retry that already-claimed save. Duplicate receipts are idempotent;
conflict/stale commands require explicit reload, not blind resubmission.

Finish/debrief transitions also use the shared acknowledged transaction path.
Failure never advances or completes; rollback/cache repair and provider refresh
use shared behavior. Old-owner work can write only its captured namespace and
cannot update the new owner's visible progress. Test guest, account A/B and
A-to-B-to-A changes, including held playback and held writes.

Strictly validate schema/types/bounds, owner/course/family, unique IDs/sequences,
registered identities, typed variants, session reachability and receipt/cursor
consistency. Corrupt/unsupported sentence documents are unavailable, not empty;
preserve raw bytes and refuse writes for that document scope. Valid v2/comparison
sibling documents still load. A stale or unavailable section must not erase its
checkpoint or be replayed against a changed key. Explicit reload/retry is in
scope; destructive repair/reset UI is not. A family-wide invalid document may
block its three sections, but not older practice activities.

## 7. Acceptance and verification

The implementation plan must map each row to owned source files and named
test-first regressions. These are future requirements, not reported test results.

| Area | Required evidence |
| --- | --- |
| Content packet | Exactly 15 records, five per section, mixed revisits both target classes; pinned French FLEURS source, original/derived hashes, crop boundaries, transcripts, licence/credits and actual review evidence |
| Contextual validation | Missing/duplicate/unknown/mismatched identities, text/audio/token coverage, pending/rejected clips, incorrect target role and invalid keys rejected; punctuation not a distractor; variants/liaison explicitly resolved or excluded |
| Scoring | Exact multiple-target set succeeds; missed/extra/all/empty selections behave correctly; order irrelevant; repeats distinct; punctuation/unknown/duplicate IDs rejected; one attempt per submission, no tap-level evidence |
| UI/debrief | Target/text visible, teaching/key absent in active text and semantics; immediate whole-answer result; all five declarative keys/notes at saved debrief; no invented restored selection or learner diagnosis |
| Audio | Exact reference/source success required; replay revokes grant; failure/cancellation unscored with no TTS; stale prompt, covered route, background and owner events fenced; fresh hearing on unanswered restore |
| Sessions | Three independent authored five-item sessions; saved four-of-five default/configured policy; full coverage before eligible Finish; finite mistake rounds, no automatic requeue; review-only Finish adds no completion |
| Evidence/progress | Item-scoped mistakes/routes; first/repeat and teaching exposure explicit; committed-only current distinct-section count stays within zero to three; no identification/comparison/mastery or cloud event pollution |
| Transactions | Actual shared repository held/failing writes prove answer and Finish ACK barriers, identical retry, duplicate idempotency, conflicts, rollback/cache recovery and automatic current-owner provider publication |
| Restore/isolation | Independent section checkpoints, changed content/key unavailable without deletion, future/corrupt family raw preserved, valid sibling families load; guest/A/B and A-to-B-to-A refresh/held-work isolation |
| Navigation/accessibility | Real Home/router/progress paths including unavailable/unknown IDs; existing destinations preserved; keyboard/screen-reader controls, repeated-word position, non-color state, narrow viewport and 2x/3x text scaling |
| Preservation | Existing word/audio/licence bytes, pending statuses, frozen readiness, existing saved formats/fingerprints, Sound Match work, branches/worktrees and process evidence unchanged |

Run focused content/validator/scoring, profile/codec/transition, shared-store,
owner/lifecycle, widget and actual-router tests, followed by applicable full
Flutter tests, `flutter analyze`, JavaScript web release build, Python tests and
audio checks. Existing root commands remain:

```sh
python3 -m unittest discover -s scripts -p 'test_*.py' -v
python3 scripts/verify_french_audio.py --repo-root .
```

Run Flutter commands from `frontend/`. Extend verification for the new sentence
package; the current word verifier alone cannot qualify sentence assets. Check
exact changed paths and preservation hashes at each scoped PR head/current base.
Fake playback tests, structural checks and web builds do not establish French
accuracy, rights, actual browser/iOS/Android playback, assistive-technology
acceptance, privacy, assessment suitability or release readiness.

## 8. Handoff and retained gates

This is a reviewable written contract with a deliberately gated content-packet
deliverable, not a claim that the exact 15 clips already exist. No recording is
downloaded, annotated, cropped or promoted by this documentation task. Existing
word candidates and root `LICENSE` remain unchanged. Preserve unpublished Sound
Match work, user changes, all branches/worktrees and durable process records.

After written-spec approval, create the separate implementation plan specifying
concrete APIs/paths, candidate-selection and annotation tooling, owned tasks,
data bounds, verification commands, independent review and scoped PR delivery.
Do not infer approval of installation, acquisition, cloud work or release from
source selection alone. If content cannot be qualified, report the outstanding
gate rather than announcing a usable 15-item pilot.

Qualified French/contextual-key review, source rights, actual platform playback,
assistive technology, privacy, assessment and release remain independent gates.
No FR-15 or other unrelated scope is authorized. User review of this written
specification is the next approval step; implementation planning has not begun.
