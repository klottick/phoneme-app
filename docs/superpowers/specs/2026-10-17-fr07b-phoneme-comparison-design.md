# FR-07-B: optional phoneme comparison practice

## 1. Intent, authority and approval stage

Add an optional, separate Same/Different practice activity for explicitly
designated French phoneme targets. It supplements, and is not a required section
of, the unchanged ten-item identification pilot. Reuse its session, persistence,
audio ownership and recovery machinery; comparison is a different evidence
dimension, not another way to manufacture individual phoneme-identification
observations.

Conversational approvals selected a separate optional activity; labeled alpha
use of existing pending bundled audio; typed pair-level answers and independently
versioned local data; ten balanced pairs; fresh two-sample hearing; finite saved
review; and preservation/recovery constraints. The proposed inventory and notes
below are authored candidates for written review, not linguistically reviewed
content. A gitignored local audit record preserves the discussion history; it is
not a public authority.

**Status: written specification awaits user review.** Conversational approval
authorizes this document only. Written-spec approval is a prerequisite to a
separate implementation plan; that plan requires approval before implementation.
Documentation publication is not feature delivery.

Authorities:

- [FR-07-A discovery/remediation design](2026-10-16-fr07a-discovery-remediation-design.md)
- [FR-06 controlled listening exercises](2026-10-16-fr06-listening-exercises-design.md)
- [FR-05 finite review](2026-10-16-fr05-finite-review-design.md)
- [FR-04 learning store](2026-10-15-fr04-learning-store-design.md)
- [French reference-audio policy](../../french-reference-audio.md)
- [FR-07 roadmap](../plans/2026-10-10-french-learning-path-tickets.md)
- Audit baseline: published `origin/main` `67e94f7a024e045d4106e171f1678ad36eb5a5ad`.

## 2. Scope and selected architecture

### Included

- A separately identified comparison practice activity, discovered through an
  additive optional Home entry and reachable through its own route.
- A fixed authored set of ten pairs with five Same and five Different answers,
  vowel and consonant target locations, pair-level results and debrief teaching.
- A narrow typed comparison exercise/content contract and pure structural
  validation. The existing controlled `SoundComparison` remains presentation
  only; its answer callback does not decide correctness or save progress.
- Per-sample successful exact-reference playback/source evidence, transient
  hearing permission and owner/lifecycle fences.
- Existing finite-round session policy, configurable saved threshold defaulting
  to 80%, explicit debrief/review/Finish and repository transaction/idempotency
  machinery, extended without sending pair evidence through single-sound
  summaries or mistake attribution.
- An independent comparison-local document profile/namespace, isolated from the
  existing v2 document, its codecs, commands, fingerprints and saved data.

### Excluded

No change to the ten-item identification content, IDs, revision, saved state,
completion, thresholds, Home primary discovery behavior, its four legacy
links, existing `/compare` microphone screen, or old completion counts. No
pronunciation evaluation, recording upload, cloud comparison event, backend/RPC,
new asset, TTS fallback after recording failure, content promotion, FR-15,
assessment/readiness/release claim, or browser-sandbox bypass. No generic
exercise framework or second session/persistence engine.

### Responsibility boundaries

| Boundary | Responsibility |
| --- | --- |
| Comparison catalogue and validator | Stable activity/pair/sample identities, target declarations, explicit Same/Different key and debrief copy; validate completeness and internal consistency without claiming linguistic truth |
| Existing `LessonSectionSession` | Authored-order first pass and finite unresolved-pair rounds, latest correctness, saved policy and completion eligibility |
| Typed comparison projection/transition | Resolve pair identities to the comparison prompt; validate typed answer and hearing evidence; derive correctness and pair evidence from registered content |
| Shared repository orchestration | Owner checks, serialized coordinator, document commit/rollback, receipts, sequence/revision conflict, immutable Retry and auth-generation fencing; independent of family payload types |
| Family-specific state adapter | Existing public v2 API/state/codec remains default. Comparison adapter validates and evolves only its own payload through shared orchestration; no comparison data enters v2 typed fields |
| Shared exercise-owner seam | Narrow reusable playback-generation/hearing-grant, single-submit claim, frozen-command Retry/reload and lifecycle/owner fencing used by discovery and comparison screens; comparison composes it rather than cloning discovery screen |
| `SoundComparison` | Controlled neutral A/B controls and Same/Different input; receives presentation state and emits typed user intent only |
| Home/progress/read models | Add optional labeled entry and separately labeled local comparison counts/history; leave primary discovery and existing counts intact |

The actual code has closed activity-kind, action, evidence, checkpoint and
summary switches; `CourseLearningState` enforces schema version 2 and contains
typed per-sound mistakes/summaries. A different codec or empty-state factory
alone cannot represent comparison state. The implementation plan must trace
these seams and extract a narrow shared orchestration envelope with
family-specific typed payload adapters. The envelope owns owner/course,
document revision, commit ordinal and family-domain receipts. The v2 payload
adapter keeps its existing typed state, codec, key and public API as the exact
default. The comparison payload owns its session/checkpoint, typed pair attempts,
pair mistakes, pair summaries and completion, with no cloud outbox. Shared
orchestration serializes reads/writes, checks owners/sequences, and commits or
rolls back either payload. No pair evidence passes through `CourseAttempt` or
per-sound maps. This is one transaction/retry engine, not a second engine or
writer. Do not make `targetSounds.single` stand in for a pair. Existing v2
canonical command bytes/fingerprints remain byte-for-byte stable; comparison
identity includes document family and activity.

Comparison has activity and section ID `en-fr-phoneme-comparison`, content
revision `1`, and dedicated route `/course-comparison/en-fr-phoneme-comparison`.
Its exact key is
`course.learning.comparison.v1.<base64url-course>.<owner-tag>` where guest is
`g` and account is `a.<base64url-account>`, using the existing v2 component
encoding rules. Explicit family and schema are part of command identity.
Never put comparison fields into v2 JSON or reuse v2 fingerprints.

## 3. Authored content and validation

### 3.1 Contract

Each immutable `ComparisonExercise` has a stable pair ID, `ContentPurpose.practice`,
new pair `ContentReviewState.pending`, ordered A and B samples,
neutral target instruction, explicit target declarations, expected relation and
debrief note. Each sample binds an exact registered reference ID and a target
phoneme identity at an explicit zero-based phoneme ordinal in that word's
catalogue annotation. The current proposal uses ordinal 0 for the explicitly
named first consonant and ordinal 1 for the single vowel where applicable;
authorship must verify the catalogue's actual phoneme sequence and document that
mapping in the content. No runtime spelling heuristic, waveform matching,
reference equality or word identity may determine target equality.

Core owns a typed relation (`same`/`different`) and typed selected relation;
these are not feature-widget strings, `ChooseSound`, or a correctness boolean.
Both target declarations must be nonblank and explicit. The expected relation is
valid only when it agrees with the two authored target phoneme identities. Same
targets across distinct words and references are valid. A Different answer
means only that the two designated targets differ, not that the words, speakers,
or recordings differ.

Validator requirements: deterministic explicit diagnostics for missing
activity/section ownership, missing purpose/review-state declarations, missing
pair/sample/target/key/instruction/note fields, duplicates and invalid values.
Reject these rather than defaulting absent ownership or review state. Exactly ten
distinct nonblank pair IDs; exactly two
ordered samples per pair with distinct A/B slots; exact known reference IDs;
valid target ordinals and phoneme IDs; nonblank neutral instruction and debrief;
answer key consistent with designated targets; exactly five keys of each
relation; authored order retained; and complete, unique IDs. Detect duplicate
records before map projection. Return deterministic developer diagnostics and
reject the whole comparison activity before starting/loading a run if required
content is structurally invalid. Do not partially show, silently repair, infer,
or score invalid content. Structural checks do not establish that recordings
realize the annotated target or that the key is linguistically correct.

### 3.2 Proposed exact pilot inventory

All references below are existing manifest IDs (`fr-word-*`); every use is new
pair content. The keys/order are fixed and authored, not generated or alternating.
The target notation is phoneme identity, not a displayed answer. Target locations
are authored ordinal 0/1 and the active instruction exposes only the stated
location. Inventory is proposed for written review, not French review.

| Order | Stable pair ID | A reference / target | B reference / target | Learner instruction | Key | Debrief note |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | `fr07b-pair-01` | `fr-word-tout` / vowel ordinal 1 `/u/` | `fr-word-tu` / vowel ordinal 1 `/y/` | Compare the vowel in each sample. | Different | The vowel targets are `/u/` in A and `/y/` in B; the designated sounds differ. |
| 2 | `fr07b-pair-02` | `fr-word-rue` / initial consonant ordinal 0 `/ʁ/` | `fr-word-rouge` / initial consonant ordinal 0 `/ʁ/` | Compare the first consonant in each sample. | Same | Both designated first consonants are `/ʁ/`. |
| 3 | `fr07b-pair-03` | `fr-word-tout` / vowel ordinal 1 `/u/` | `fr-word-vous` / vowel ordinal 1 `/u/` | Compare the vowel in each sample. | Same | Both designated vowels are `/u/`. |
| 4 | `fr07b-pair-04` | `fr-word-tu` / initial consonant ordinal 0 `/t/` | `fr-word-doux` / initial consonant ordinal 0 `/d/` | Compare the first consonant in each sample. | Different | The designated first consonants are `/t/` and `/d/`; they differ. |
| 5 | `fr07b-pair-05` | `fr-word-loup` / initial consonant ordinal 0 `/l/` | `fr-word-rue` / initial consonant ordinal 0 `/ʁ/` | Compare the first consonant in each sample. | Different | The designated first consonants are `/l/` and `/ʁ/`; they differ. |
| 6 | `fr07b-pair-06` | `fr-word-rue` / vowel ordinal 1 `/y/` | `fr-word-lune` / vowel ordinal 1 `/y/` | Compare the vowel in each sample. | Same | Both designated vowels are `/y/`. |
| 7 | `fr07b-pair-07` | `fr-word-beau` / vowel ordinal 1 `/o/` | `fr-word-bon` / vowel ordinal 1 `/ɔ̃/` | Compare the vowel in each sample. | Different | The designated vowels are `/o/` and `/ɔ̃/`; they differ. |
| 8 | `fr07b-pair-08` | `fr-word-lit` / vowel ordinal 1 `/i/` | `fr-word-vite` / vowel ordinal 1 `/i/` | Compare the vowel in each sample. | Same | Both designated vowels are `/i/`. |
| 9 | `fr07b-pair-09` | `fr-word-tu` / initial consonant ordinal 0 `/t/` | `fr-word-tout` / initial consonant ordinal 0 `/t/` | Compare the first consonant in each sample. | Same | Both designated first consonants are `/t/`. |
| 10 | `fr07b-pair-10` | `fr-word-mur` / vowel ordinal 1 `/y/` | `fr-word-rouge` / vowel ordinal 1 `/u/` | Compare the vowel in each sample. | Different | The designated vowels are `/y/` and `/u/`; they differ. |

The five Same keys occur at 2, 3, 6, 8, 9; the five Different keys at 1, 4,
5, 7, 10. This authored order is not an alternating key pattern. Content validation must test both declared target equality and
relation, including same phoneme across distinct references. The inventory
includes consonants `/t d l ʁ/`; this additive activity does not expand FR-01
readiness or claim full consonant coverage.

Reference IDs and existing word annotations are the source for structural
binding only. In particular, ordinals, target phoneme sequence, audibility,
pair suitability, and linguistic relation must be checked against current
catalogue content during implementation planning; any mismatch is a blocker to
shipping the affected authored item, not permission to change frozen FR-01
content or infer a replacement. Preserve the recording manifest's all-pending
status and assets unchanged.

### 3.3 Teaching boundary

The active exercise exposes no word, semantic translation, spelling, IPA,
target phoneme, answer key, pair ID, hidden catalogue metadata or teaching text
in visible copy, accessibility semantics, tooltip, feedback or error. Show only
the exact alpha disclosure, section-level neutral direction, target-location
instruction, A/B sample labels and Same/Different choices. Playback buttons
remain explicit and neutral.

At saved debrief only, display the full rule: **“Compare only the designated
sound in each sample. Same means those two target phonemes are identical;
Different means they are not. Ignore the rest of the word.”** Also show latest
correct count/required threshold and unresolved pair notes in original authored
order. Do not claim which relation the learner chose: the session stores latest
correctness, not necessarily the selected relation. The notes above are
declarative target explanations, not invented learner diagnoses. All-correct
debrief has the rule and no unresolved-specific notes.

## 4. Learner flow, playback and evidence

### 4.1 Route and exercise lifecycle

Add an optional Home comparison card/entry, clearly labeled **Comparison alpha**
or equivalent and separate from the primary discovery lesson. Preserve all
existing primary and four legacy links. Route to a dedicated comparison activity
screen, not `/compare` (the existing microphone self-comparison). Route
unavailable/corrupt comparison state locally; it must not block existing
practice. Progress labels/counts must distinguish comparison practice from
discovery, legacy lesson and individual phoneme summaries.

Use the shared session's ten-item first pass in authored order. Permit one
typed relation submission per pair per round, only after both A and B have
successful playback during the current prompt/generation. The learner may hear
either order and replay either sample before submitting. Immediate Correct/Not
yet is owner-supplied and does not reveal the key. Do not show words, meaning,
IPA, semantic clue or teaching before the first and review-round debrief.

At debrief, whenever unresolved pairs remain, offer Review unresolved pairs,
including on a passing round; the learner may decline and finish if eligible.
Queue exactly unresolved pair IDs once in authored order. Each
pair is answered once per round; wrong retries remain unresolved and do not
grow that round. Return to debrief when the queue ends. Never auto-repeat.
Use the saved `LessonPolicy` default of 80% (8/10) and its saved threshold on
resume. Eligibility requires
all ten attempted, debrief phase and threshold met. Only a successfully saved
eligible first/practice Finish records a distinct comparison activity
completion. Review-mode Finish never creates a new completion. Starting a
deliberate new run resets only its draft/session state; historical pair attempts,
mistakes and completion remain.

### 4.2 Audio request and permissions

Use the existing reference-audio facade in `alphaPractice` mode with
`allowPracticeTts: false`; the playback request pins the normal variant. Pin the exact
disclosure: “Alpha audio: recordings are unverified; device speech is
practice-only.” These manifest assets remain pending candidates. A covered
recording failure is Retry/unavailable, never substitution to TTS and never a
scored error. Cancellation is quiet and unscored. Do not alter source manifest,
bytes, provenance, licenses or readiness.

The owner requests playback for an exact `(activity, run generation, round,
pair ID, sample slot, reference ID, UI generation)`. Capture the returned
successful exact reference and actual source. Only successful completion for
that exact current request grants hearing. A and B each need independent current
success; requests serialize to one active playback. Starting replay immediately
revokes that sample's permission and blocks answer submission until replay
succeeds. If replay fails/cancels, the sample remains unheard; the other
sample's success may remain valid while the uninterrupted prompt remains active.
All 20 sample slots reference 13 distinct known pending recordings; an
unexpected source or reference returned by playback is rejected and grants no
permission. Persist
provenance from the actual typed `CourseAudioResult` source/reference, never
infer it from manifest coverage or requested policy.
No persisted checkpoint restores hearing permission. An unanswered restored
pair must freshly play both samples. An already answered restored pair shows
saved feedback and does not request or infer a selected relation.

Backgrounding, route exit, prompt/round transition, screen disposal, repository
replacement, owner/auth generation change and stale request completion retire
the request and permission. Late success/failure cannot unlock, submit, feedback,
navigate, or stop newer playback. Claim one answer synchronously before async
save; rapid taps/keyboard activation cannot fork commands.

### 4.3 Typed pair evidence and review

The owner validates both live hearing grants and synchronously claims them while
creating the immutable answer command. The pure transition has no access to
live audio/UI state: it validates structural provenance (exact A/B slots and
references, successful source observations, activity/run/round/pair/profile
identity) against registered content, then derives correctness. This is data
consistency validation, not cryptographic audio attestation. A frozen command
retry uses its original observations and needs no live grants or replay;
retiring UI permission cannot invalidate an already claimed save retry.

Add a typed `ComparePhonemesAnswer` (or equivalent core domain value) with
selected relation `same|different`, plus expected relation snapshot and exactly
two playback observations. Each observation carries sample slot, exact
reference ID, successful result, actual source enum and prompt/run identity.
The transition validates these against the registered pair and command identity,
derives correctness from the authored key, and commits one
attempt for one pair. The widget never supplies a boolean grade. Failure or
cancellation creates no answer command, attempt, mistake, coverage or completion
(a playback request itself is not a learning command).

Pair attempts use explicit comparison activity and pair IDs, comparison content
revision, typed answer kind, relation selection/key, A/B source references and
provenance, plus distinct first-in-run/repeat-in-run presentation and after-
debrief assistance attribution. Preserve these in saved attempts and separate
summary buckets; any aggregate that mixes them must be labeled as including
review/teaching-exposed attempts, never as unaided first attempts. They must not
become two `SoundChoiceAnswer`s or flow through
the existing target-sound summary builder. Pair summaries are separate counts
of correct/total comparison answers by comparison activity (and optionally
pair), with an explicit **comparison practice, not phoneme mastery** label.
Do not update individual phoneme identification numerator/denominator from a
pair result.

Durable mistakes are keyed by comparison activity, pair ID and comparison
content revision, not by either target sound. A wrong pair adds/updates only
that pair mistake; a correct answer resolves only that same pair/revision.
Review routing resolves the exact registered comparison activity/pair and
opens its dedicated screen/debrief or finite review; it must not route via the
first lesson containing one of the pair's sounds. Existing sound mistake and
summary behavior remains unchanged. Comparison evidence is local-only: add no
comparison activity to cloud backup allowlists and do not collapse a pair to
the first target in an existing cloud answer event.

## 5. Persistence profile, compatibility and recovery

### 5.1 Versioned profile contract

Keep one process-wide serialized repository coordinator and transaction/receipt
orchestration, with a typed family envelope and family-specific payload adapters.
The envelope owns owner/course identity, family, document revision, commit
ordinal and family-scoped command receipts. The unchanged v2 adapter maps its
existing `CourseLearningState` (schema 2) and public APIs to that envelope;
comparison has its own schema-1 payload and cannot be represented by constructing
`CourseLearningState(schemaVersion: 1)`. Its payload contains the comparison
activity checkpoint/session, bounded typed pair attempts and receipts, pair
mistakes, pair summaries and completion, with no cloud outbox and no
identification state. Reuse the shared coordinator's sequence, transaction,
rollback and auth-generation logic; keep the state/evidence adapters separate.

The canonical command/fingerprint domain includes profile family in the
comparison path, preventing cross-document replay even with identical owner,
course, activity sequence and payload. Do not alter canonical v2 bytes or
fingerprints. Do not dual-write, migrate, import, reset, delete, or rewrite any
existing v2 data. An older app simply does not discover comparison progress;
existing lesson data remains as it was. Guest and each exact account ID remain
isolated under the same owner encoding/auth-generation fencing used by the
repository.

Codec validation is strict: exact supported schema, owner/course/family match,
strict integer types and bounds, unique IDs/sequences, registered activity and
revision, legal typed answer/sample-source variants, valid pair-key checkpoint,
strict `LessonSectionSession` restore and receipt/fingerprint consistency.
Unknown answer kinds, fields/variants that cannot be safely ignored, malformed
JSON, wrong owner/family and unsupported future schema are unavailable, not an
empty state. Preserve original bytes and refuse writes for that comparison
scope. Do not reset the existing v2 sibling document or make its provider
unavailable because comparison data failed. Recovery is explicit reload or
later repair tooling; this increment adds no reset/delete UI.

### 5.2 Commit and retry behavior

Answer, comparison attempt, pair mistake, summary, receipt and checkpoint commit
as one owner-scoped document replacement. Validate the profile, content/run
revision, expected command sequence, current pair/round, typed relation and
structural playback observations before deriving a candidate. Serialize reads
and writes through the shared coordinator. Immediate Correct/Not yet feedback
may be shown from the claimed answer, but do not publish draft progress or
completion, advance, or show a committed count until acknowledgement. Retry uses
the exact frozen command, owner/store,
identity and payload; duplicate receipt is idempotent and cannot double count.
Save failure never advances, finishes, or claims a completion. Conflict/stale
receipt uses explicit reload, not blind retry. Completion commits only from the
saved eligible first-run debrief. If owner changes, retire old UI work; a write
already begun can affect only its captured namespace.

Live playback permissions remain transient and are never restored. Durable
source/reference observations belong to the frozen answer command, attempt and
comparison document; they record the claimed answer's actual source but NEVER
grant permission to answer or play again. Retry uses those exact serialized
observations without restoring grants. Restored unanswered items need both
fresh successes; saved answered items retain correctness/feedback but unknown
selection remains unknown because no selected choice is reconstructed from the
key. Active audio is never serialized.

## 6. Acceptance and verification gates

The later implementation plan must map these requirements to concrete source
paths and named tests, identify existing reusable coverage, and establish
test-first failing regressions for new behavior. No runtime passing result is
claimed by this specification.

| Area | Required evidence |
| --- | --- |
| Authored data | All ten exact IDs/references/target ordinals, key count/order and pair notes; validator rejects missing/duplicate/unknown/blank/mismatched targets, invalid relation and wrong balance; same phoneme across different refs accepted |
| UI contract | Real controlled component keeps A/B labels, exact target instructions and typed Same/Different; no keys, word/meaning/IPA/phoneme/debrief leaks in text or semantics |
| Audio | Either A/B order; exact reference/source recorded only after success; both required; replay revokes its permission; cancellation/failure unscored/no TTS; stale prompt, route, background and owner callbacks fenced |
| Session | Ten authored first-pass items, saved 80% default/configurable threshold, all-attempted/debrief eligibility, ordered finite unresolved queue, wrong retry does not grow queue, no automatic round, review Finish no new completion |
| Evidence | One typed pair attempt per answer; no two per-sound attempts or changes to phoneme identification summary; pair-scoped mistake resolve/review route; separate local comparison summary and completion; first/repeat and after-debrief assistance remain distinct and honestly labeled |
| Storage seam | Existing v2 default codec/key/command fingerprint fixtures byte-identical; profile-specific key/schema and command domain; corrupt/unsupported comparison document preserved and isolated from valid v2 practice |
| Transactions | Real repository/coordinator held-write and failed-write tests; no draft progress/completion before ack (immediate answer feedback permitted); exact retry/idempotency, duplicate/conflict, rollback/cache repair, concurrent screens, guest/A/B and A→B→A ownership |
| Restore | Unanswered pair requires fresh A/B; answered feedback restores without guessing selection; review/debrief queues and saved policy survive; stale/changed content requires explicit recovery |
| Discovery preservation | Existing Home primary discovery and four legacy links, route IDs, completion totals, v2 state and behavior remain unchanged; comparison route cannot alias `/compare` |
| Audio preservation | Manifest pending status, candidate binaries, provenance/license files and root `LICENSE` unchanged; no readiness promotion |
| Accessibility | Keyboard and assistive activation use same gates; non-color feedback, explicit sample labels, usable narrow/large text layout; no hidden metadata in semantics |

During implementation, run focused pure validator/transition, codec/profile,
store, component/widget, owner/lifecycle and real application-router tests, then
the applicable full Flutter tests, `flutter analyze`, JavaScript web build,
Python suite (`python3 -m unittest discover -s scripts -p 'test_*.py' -v`) and
audio verifier (`python3 scripts/verify_french_audio.py --repo-root .`). Run
Flutter commands from `frontend/`. Confirm preservation hashes/status and exact
diff scope. These are future verification gates, not results of this doc task.
Fake tests, technical audio verification or a web build do not establish French
linguistic accuracy, licensing clearance, real browser/native playback, assistive
technology acceptance, assessment suitability, privacy or release readiness.

## 7. Preserved gates and handoff

Keep unpublished Sound Match work, branches, worktrees, user changes and durable
process evidence. Preserve all candidate audio bytes, metadata, licences and root
`LICENSE`. Do not promote any pending entry or expand frozen FR-01 readiness.
There is no production implementation authorization in this document. FR-15,
cloud/RPC work, pronunciation evaluation, upload, assessment and release remain
out of scope. Qualified French linguistic/audio review, rights/licensing review,
actual browser/iOS/Android playback, privacy and release are independent gates.

After written-spec review/approval, prepare a separate implementation plan with
exact APIs/files, test-first task sequence, acceptance mapping and preservation
commands. Obtain approval of that plan before product edits. Implementation and
publication then require scoped PR review and controller verification under the
repository workflow. This specification itself remains awaiting user approval.
