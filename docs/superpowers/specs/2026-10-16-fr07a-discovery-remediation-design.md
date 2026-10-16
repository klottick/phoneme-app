# FR-07-A: complete the existing discovery/remediation slice

## 1. Intent, authority and approval stage

Make the existing French discovery pilot the clear primary learning entry and
complete its section-end teaching without rebuilding the lesson engine. Learners
should attempt listening puzzles before seeing explanations, receive immediate
correctness feedback, understand unresolved examples at debrief, and resume or
finish without losing mistakes or claiming an unsaved pass.

The user approved a read-only gap audit, selected **staged FR-07**, and separately
approved the conversational architecture/legacy boundary, debrief/content flow,
and persistence/error/verification sections. This document records those choices.

**This written specification awaits user review.** Conversational approval permits
preparing this document, not implementation. Written-spec approval permits writing
an implementation plan; that written plan also needs approval before execution.
Retain the selected sequential Luna implementation method when execution is
authorized. Documentation publication is not feature delivery.

FR-07 is split deliberately:

- **FR-07-A (this specification):** targeted debrief, minimal discovery entry,
  explicit legacy boundary, and real-route integration/preservation regressions.
- **FR-07-B (outstanding):** production Same/Different catalogue content,
  validation, typed submissions, playback attribution and progress/evidence
  integration. It needs its own approved specification and plan. Completing A
  does **not** complete all of FR-07.

Authorities and audited baseline:

- [Roadmap FR-07](../plans/2026-10-10-french-learning-path-tickets.md).
- [Curriculum contracts](2026-10-11-french-curriculum-design.md).
- [FR-04 learning store](2026-10-15-fr04-learning-store-design.md).
- [FR-05 finite review](2026-10-16-fr05-finite-review-design.md).
- [FR-06 controlled exercise design](2026-10-16-fr06-listening-exercises-design.md)
  and [published outcome](../status/2026-10-16-fr06-listening-exercises.md).
- [Reference-audio policy](../../french-reference-audio.md).
- Published `origin/main` at audit/spec preparation:
  `bdecde20c10440ebf184389d60fa926189022e6a` (FR-06 outcome PR48).

## 2. Audit findings and selected scope

The pilot already has hidden active-puzzle teaching, immediate Correct/Not yet,
finite authored-order mistake rounds, explicit replay, resumable checkpoints,
immutable save retries and eligibility/persistence-gated Finish. Reuse these;
historically unchecked roadmap boxes are not evidence that the engine is absent.

The remaining A gaps are specific:

1. `DiscoverySectionView` shows the full section rule and unresolved word chips,
   but no authored teaching selected for those unresolved examples.
2. Home's first unfinished lesson comes from the five-element legacy list and
   initially opens explanation-first `en-fr-vowels`, not the discovery pilot.
3. Only `en-fr-u-y` has authored discovery content. The other four known lesson
   IDs still use `CourseLessonScreen`, immediate explanations and Word reference.
   They are not already authored discovery exercises merely awaiting a new view.
4. Many discovery tests construct their own routers. Changes to the real Home,
   route selection and review entry require tests using the application router.

Alternatives considered:

- **Staged A then B (selected):** finish the working identification slice first,
  then design comparison's additional content/evidence/compatibility surface.
- **Combined A+B:** a larger coupled catalogue, playback, codec and evidence
  change; deferred to avoid making A depend on unapproved comparison semantics.
- **Convert all legacy lessons:** requires new authored content, linguistic
  decisions and progress migration policy; outside this integration scope.

No full overworld, stage navigation, new prerequisites, general runner, sentence
hunts, spelling puzzles, assessment, pronunciation evaluator or FR-15 is included.
Do not change phoneme-wide interfaces into vowel-only contracts. The live pilot
remains `/u/`–`/y/`; its limited coverage is not whole-course readiness.

## 3. Architecture and ownership

| Boundary | Responsibility in A |
| --- | --- |
| Authored debrief content | Stable section/exercise-linked teaching notes, detached from widgets and learner data |
| Pure teaching validation/projection | Validate the notes against their owning section/exercises; resolve notes in authored order from unresolved item identities |
| Debrief presentation | Full rule, counts, unresolved examples, targeted notes and existing owner-controlled recovery/review/Finish callbacks |
| `DiscoverySectionView` | Active puzzle/layout adapter; delegates debrief presentation rather than acquiring persistence or audio ownership |
| `DiscoveryLessonScreen` | Existing playback/hearing permissions, transient selection, lifecycle/account ownership, typed commands, immutable Retry and navigation |
| Existing session/policy/store | Correctness, latest outcomes, finite queues, evidence, persisted policy and completion authority; unchanged semantics |
| Home/progress/route integration | Explicit discovery entry and honest labels, while keeping legacy IDs and saved progress reachable |

Extract a focused `lesson_section_debrief.dart` beside the current course views.
It is controlled presentation, not a second session, repository or scheduler.
The active exercise must not receive or expose targeted teaching notes.

Use a small additive authored teaching collection and its pure validation helper
under `core/course/`; do not reopen the frozen FR-01 catalogue signature or add a
new persisted exercise kind just to carry debrief copy. Exact filenames and API
names belong to the implementation plan, within these responsibility boundaries.

## 4. Authored teaching and validation

Each teaching record has an explicit owning section identity, stable catalogue
exercise identity and nonblank note. Use an ordered record collection so duplicate
keys remain detectable; detach exposed collections from caller mutation.

For the ten-item pilot, every exercise has exactly one note binding. Notes may
share existing `/u/` or `/y/` teaching text, but bindings are authored explicitly:
do not select a note using spelling, list position, a word-string heuristic or an
inferred learner response. The projection resolves the existing session aliases
through the validated catalogue identities, preserving those aliases in storage.

Validation must report missing pilot bindings, duplicate identities, blank text,
unknown exercises, mismatched section ownership and duplicate/ambiguous source
identities. Diagnostics must be deterministic; no first-match fallback may hide
an ambiguous record. Validation must not convert content errors into wrong answers.

For A, targeted copy reuses the existing section's steady `/u/` and tongue/lip
position `/y/` teaching, selected for each authored target. Do not introduce new
pronunciation claims, additional examples, variant rules or new French answer
keys under this integration task. Structural validity is not qualified linguistic
review; any additional linguistic claim requires that review before inclusion.

A note explains the unresolved example's authored target. It must not say the
learner confused particular phonemes or selected a particular distractor:
`LessonSectionSession` retains latest correctness, not the selected response.
Answer history is not a prerequisite for restoring a correct debrief.

Invalid required teaching content rejects the affected discovery entry with a
neutral unavailable message. It must not expose partial/guessed teaching, start a
new run, overwrite saved data or fall back to the explanation-first screen.
Authoring diagnostics stay out of learner-facing text/semantics. Legacy practice
must remain independently usable; do not make its access depend on new teaching
validation succeeding.

## 5. Learner flow

### 5.1 Active puzzles

Preserve neutral listening instructions, phoneme response labels, explicit
listen/replay and immediate Correct/Not yet after a scored submission. Keep the
word-bearing title, word/IPA reference, section rule and targeted teaching absent
from active text, tooltips, accessibility semantics, errors and recovery states.
These restrictions apply to first-pass and review puzzles alike.

No early-help bypass, first-attempt shortcut or correctness-dependent response
ordering is added. Cancellation remains quiet; audio failure remains generic and
unscored. Successful hearing permissions and replay revocation remain owner-held.

### 5.2 Section-end debrief

After each finite round reaches its saved end state, display:

1. Authored section title and full existing teaching rule.
2. Latest-correct count over distinct required examples and the saved policy's
   required passing count; not total taps or lifetime attempts.
3. Unresolved examples with their authored teaching notes, in original section
   order, regardless of the order of stored unresolved IDs.
4. Existing Finish section, Review mistakes and Practise again controls when
   eligible, with the existing recovery/busy-state guards.

If every example is currently correct, show the existing success message and full
rule, with no mistake-specific notes or Review mistakes control. If the learner
passes while mistakes remain, still show their notes and offer optional review.
Do not silently replace the configurable default-80% policy with 100% mastery.

Review starts only through the existing persisted finite-round command. Hide the
teaching again while puzzles are active; on the next debrief select notes from
the newly updated unresolved set. A failed round returns to debrief, not an
automatic repeat loop. No new debrief playback or recording feature is added.

## 6. Entry, labels and legacy compatibility

Home's primary learning card represents the **one authored discovery lesson**:

- With no current-revision completion, offer **Continue discovery** through the
  existing `/course-lesson/en-fr-u-y` route. Saved first-pass, answered-item,
  review and debrief checkpoints resume through the existing owner.
- With a current-revision completion, show discovery completion and offer
  **Review discovery** through the same route with `review=true`. Keep the
  existing explicit Practise again action; entering Home must not start a run.
- Derive any displayed discovery count from the pilot's committed current-revision
  completion only: zero or one of one, never the five-lesson list or a local draft.
  Show loading/load recovery rather than treating unavailable progress as saved.

Place the other four lessons under an explicit **Legacy practice** heading. Keep
their existing IDs, current saved runs, completion records and optional recording
behavior. Do not re-author them, rename their activity IDs, map them to the pilot,
invalidate their badges or treat their one-pass completion as a discovery pass.
Keep the legacy UI and audio/recording cleanup behavior intact.

The existing five-lesson completion tally may remain on the progress screen, but
label it explicitly as **Existing lessons (includes discovery pilot)**. A separate
**Discovery lessons** count uses the one authored pilot. Do not call the combined
tally five completed discovery lessons or claim four new authored discoveries.
Retain practice/game evidence separation and speaking-not-assessed disclosures.

Preserve the existing public lesson route: pilot IDs resolve to discovery, known
legacy IDs to legacy practice, unknown IDs to Lesson unavailable. Do not expose
Word reference or other legacy controls inside the discovery puzzle. Review links
retain `review=true` and cannot create new completion records. Existing sound
review routing stays within the registered content; this is not a new cross-course
mistake scheduler or the FR-11 path/navigation redesign.

## 7. Persistence, recovery and ownership

Teaching notes are authored presentation metadata, not saved learner state. Resolve
them from the current validated content and saved unresolved identities; do not
persist their rendered text, require history, or backfill selected responses.

A preserves the ten pilot items, authored order, answer keys, section/activity IDs,
session aliases, scored content revision, saved policy and checkpoint/storage
formats. This additive teaching/entry change must not invalidate compatible
sessions or completions. If implementation uncovers a necessary scoring or format
incompatibility, stop and return that scope decision to the user; do not migrate,
reset or bump revisions silently.

Immediate result feedback remains possible before answer persistence settles, but
Next, review-start and Finish remain save-gated. A failed save retains the exact
pending command for explicit Retry saving, crediting once. A stale-session
conflict requires explicit Reload saved progress. No draft may change committed
counts, exit the route, unlock progression or claim successful completion.

Retain lifecycle, store/account replacement and navigation fences. Departed
callbacks cannot grant hearing, publish feedback, resubmit into a new owner or
navigate after late completion. Restored unknown selection stays unknown; known
live selection and immutable retries retain existing FR-06 behavior. No persistence
of hearing permission is introduced. Review-mode Finish still saves without adding
a completion. Audio failure/cancellation creates neither an answer nor a mistake.

## 8. Acceptance and verification

| Requirement | Required evidence during implementation |
| --- | --- |
| Explicit teaching bindings | Pure tests for complete pilot coverage, ownership, duplicate/unknown/blank records, deterministic diagnostics and detached collections |
| Correct note selection | Authored-order unresolved notes, all-correct omission, partial-pass notes, below-threshold debrief and changed notes after finite review |
| Restore without history | Compatible saved first-pass/review/debrief fixtures restore; notes need only saved unresolved identities and authored content |
| No early teaching | Visible and semantic assertions before/after playback, correct/wrong submission, retry/reload and active review; no legacy Word reference |
| Real primary entry | Application-router tests from Home to pilot, loading/error states, resume and completed-pilot review entry |
| Safe compatibility | Real-router tests for each legacy ID, pilot and unknown ID, review query behavior and no silent remapping |
| Honest counts | Separate discovery versus combined historical counts, current revisions, failed/held Finish and committed-only updates |
| Recovery ownership | Existing and targeted held/failed save, immutable retry, conflict reload, duplicate callback, lifecycle, account/store replacement and remount regressions |
| Audio preservation | Existing replay/hearing guards, cancellation/failure unscored, no stale playback permission or silent recording-to-TTS fallback |
| Legacy recording | Existing microphone cleanup regressions pass; new navigation does not delete legacy access or recording behavior |
| Accessible presentation | Keyboard activation, coherent response semantics, reachable debrief/recovery controls on small screens and at large text scale |
| Invalid teaching | Safe unavailable discovery entry without store mutation or legacy fallback; independent legacy access preserved |

Use test-first regressions for new behavior. Verify targeted pure/widget/app-route
tests, the full Flutter suite, analysis and the JavaScript web build against the
actual integrated tree. Run Python and audio-candidate checks and preservation
hashes as appropriate to that scope; record exact commands/results in process
evidence. Confirm the PR diff changes only owned files. Independent code review
and controller verification of the exact PR head/current base precede merge.

This documentation-only specification does not establish any new runtime test
result. Historical FR-06 verification is not FR-07-A acceptance. Missing GitHub CI
is not passing CI, and a successful JavaScript build is not Wasm or playback proof.

## 9. Preservation, exclusions and outstanding gates

Preserve old development namespaces, unpublished Sound Match work, branches,
worktrees, user changes and durable process/evidence records. Preserve recording
bytes, provenance, licences and root `LICENSE`; pending candidates remain pending.
No new recording uploads, cloud pronunciation evaluation, invented pronunciation
grades, silent recording-failure TTS substitution or assessment-readiness claims.
Do not bypass the browser sandbox or resume deferred Qwen investigation.

Actual browser/native playback and assistive-technology acceptance, qualified
French linguistic/audio/licensing review, live backend validation, privacy and
production release remain separate open gates. Reused alpha teaching and practice
audio are not proof that those gates are satisfied.

FR-07-B remains responsible for explicit comparison targets/pairs and answer keys,
content validation, typed actions/answers, identities, checkpoint/codec
compatibility, per-sample hearing and playback-source attribution, finite review
and honest summaries. Equality concerns authored target phonemes, not whole words,
speaker or recording IDs. FR-06 fake fixtures do not certify production content.
No comparison catalogue kind, persisted action or production route is authorized
by this specification. FR-15 and later release/assessment work remain deferred.
