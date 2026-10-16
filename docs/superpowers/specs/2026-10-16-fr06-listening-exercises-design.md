# FR-06: reusable phoneme-listening exercises

## 1. Intent, authority and approval stage

Help learners distinguish French **phonemes**, including vowels and consonants,
without turning a listening task into a spelling task. Extract reusable exercise
presentation from the existing discovery lesson, retaining its tested ownership,
audio, saving and finite-round behavior.

The user selected same/different comparison, corrected the initial vowel-only
wording, and approved these conversational design sections:

- Two small controlled components: listening identification and phoneme comparison.
- The lesson owner retains playback, feedback, persistence and recovery.
- The existing pilot consumes listening identification; comparison establishes a
  typed UI contract and fake-audio tests. Production comparison content and its
  progress/evidence integration remain FR-07 scope.
- Explicit playback and replay, successful-hearing gates, immediate save-aware
  correctness feedback, no early explanation, and safe cancellation/lifecycle.

**This written specification awaits user review.** Conversational approval permits
writing it, not implementation. Written-spec approval permits preparing the plan;
execution still requires approval of that written plan. Preserve the selected
sequential Luna execution method when execution is authorized.

Authorities and baseline:

- [Roadmap FR-06 and FR-07](../plans/2026-10-10-french-learning-path-tickets.md).
- [Curriculum contracts](2026-10-11-french-curriculum-design.md).
- [FR-04 learning-store design](2026-10-15-fr04-learning-store-design.md).
- [FR-05 finite-round design](2026-10-16-fr05-finite-review-design.md) and
  [published outcome](../status/2026-10-16-fr05-finite-review.md).
- [Reference-audio provenance/readiness policy](../../french-reference-audio.md)
  and existing FR-03 audio interfaces/source selection.
- Published starting point: GitHub `main`
  `665d10476ff888c3317236ee100b07cdac4d58ba` (FR-05 outcome PR43).

## 2. Selected approach and component boundaries

Use controlled exercise views, not a second exercise runner. A component receives
an immutable prompt and owner-supplied interaction state, and reports typed
playback/answer requests. It never creates an audio engine, accesses providers or
storage, computes a grade from spelling, or advances a session.

| Boundary | Responsibility |
| --- | --- |
| Listening-choice component | Neutral task instructions, listen/replay control, ordered phoneme response choices and owner-supplied correctness feedback |
| Phoneme-comparison component | Target-location instructions, neutral sample A/B controls, Same/Different responses and owner-supplied correctness feedback |
| Pure UI prompt/response contracts | Detached prompt values, stable choice/sample identities, explicit typed responses; no persistence codec or catalogue registration |
| `DiscoverySectionView` | Section layout/progress, recovery controls, Next, debrief/explanation, review and Finish; delegates its active identification puzzle to the reusable component |
| `DiscoveryLessonScreen` | Pilot playback permission, audio injection, transient activity, lifecycle/owner fences, preparation/submission of existing typed commands and immutable Retry |
| Existing session/repository | Correctness from registered content, attempt/mistake evidence, checkpoints, finite rounds and saved completion policy; unchanged ownership |
| Comparison test owner | Injectable fake-audio harness exercising the contract without global progress writes; not a new production lesson route |

Alternatives considered:

1. **Controlled components (selected):** reuse the existing owner and separate
   presentation; smallest real integration surface and no duplicate scheduler.
2. **A general runner owning audio, sessions and saving:** could host future kinds,
   but duplicates working FR-03/04/05 boundaries and expands this ticket into a
   persistence/lifecycle redesign. Not selected.

Suggested locations are `features/course/exercises/listening_choice.dart`,
`sound_comparison.dart` and a small pure UI-contract file beside them, plus
`test/widget/listening_exercise_test.dart`. The implementation plan assigns exact
files/APIs. Do not restructure the entire discovery screen or its large test
suite merely to perform this extraction.

## 3. Prompt and response contracts

### 3.1 Shared constraints

- Prompt identity must distinguish the current authored item; owner-held playback
  permission additionally belongs to its run/round and current UI generation.
  Reusing an item ID on another round does not preserve hearing permission.
- Learner-visible instructions are authored and neutral. Hidden words, metadata
  identifying the correct choice, audio-reference IDs and answer-bearing
  transcriptions must not appear in text, semantics, tooltips or error messages
  during the puzzle. Identification response labels remain visible as below.
- Phoneme symbols are opaque authored identities, not a vowel-only enumeration,
  a hard-coded two-choice assumption or Unicode characters split from IPA.
- Response order is authored/stable and independent of which answer is correct.
  No correct-first sorting, correctness-dependent styling or position-based key.
  This scope adds no shuffle or randomization policy.
- Reject structurally invalid UI prompts explicitly: blank identities or neutral
  instructions, duplicate/blank choice identities, fewer than two identification
  choices, or a missing comparison sample reference/target instruction. Do not
  turn invalid prompts into a scored wrong answer or invent missing content.

### 3.2 Listening identification

Adapt the existing `ListeningChoiceExercise` / pilot projection rather than
introducing another catalogue exercise kind. The view needs a prompt identity,
neutral instructions and ordered response IDs/labels; the owner resolves the
existing audio reference and retains the correctness key.

Phoneme-labelled response options such as `/u/` and `/y/` remain visible: these
are the possible answers, not an answer-bearing word transcription. The adapter
must preserve selected response identity, authored ordering and current feedback;
the view must not receive a highlighted expected answer.

Expose a supplied selection accurately when known. This does not require a new
persisted selected-choice field: on restoring an answered checkpoint, preserve
the existing feedback/answered state and never guess a missing selected response
from correctness or from an unselected answer key.

The existing pilot's ten items, IDs, content revision, answer keys and saved
session/storage formats remain unchanged.

### 3.3 Same/different phoneme comparison

Use a separate UI prompt contract with exactly two stable sample slots, **A**
and **B**, audio-reference identities for the owner, and neutral authored
target-location instructions. The typed answer is **Same** or **Different**,
not a claimed correctness boolean, phoneme guess or synthetic `ChooseSound` value.

An instruction such as “Compare the first sound in each word” identifies where
to listen without naming the target phoneme. Each sample's intended position and
phoneme identity must be explicitly authored and unambiguous; they are not
inferred from spelling, reference-ID equality, waveform similarity or a generic
list of sounds occurring somewhere in a word. Do not invent audio alignment,
crop a recording or substitute an isolated-sound reference for a word reference.

The owner retains the authored expected relation for checking a submitted
response. Same means the designated targets represent the same phoneme, even
across different words or acoustic realizations. Different means different target
phonemes; it does not mean different words, recordings, speakers or spellings.
The widget consumes the resulting feedback, not the correctness key.

FR-06 adds no subtype to the sealed `CourseExercise` catalogue, persisted action,
codec variant, skill summary or production comparison route. A future FR-07
design must explicitly integrate comparison content, validation, answer evidence
and playback-source attribution before it can create real course progress.
Test fixtures and the harness do not satisfy that future integration gate.

Structural prompt validation is not linguistic validation. Fixture authors must
state the target positions, phoneme identities and consistent expected relation
explicitly; tests can check those declared values and interaction behavior, not
certify that a real recording realizes them. FR-06 does not build an automatic
target locator or production comparison-content validator.

## 4. Playback, replay and submission flow

1. Mount with no successful-hearing permission. Do not autoplay or restore
   permission from a persisted checkpoint.
2. A user requests playback through the owner. Identification requires its sample;
   comparison requires a successful completion for both A and B, in either order.
   Only one playback request may be active at a time.
3. Permission is granted only when that exact current request completes
   successfully. Starting a replay immediately clears permission for that sample
   and blocks answers while playback is pending. A completed other comparison
   sample may retain permission within the same uninterrupted prompt/generation.
4. Replay is available before submission, including after a successful listen.
   Failed or cancelled replay leaves that sample unqualified until a new
   successful playback. Replay produces no scored answer, mistake or coverage.
5. Accept at most one answer per item per round. The owner synchronously claims
   the submission before an asynchronous boundary or redraw, so rapid taps or
   keyboard activation cannot prepare multiple commands. Components disable
   answer/playback controls when the owner is pending, blocked or answered.
6. Present immediate `Correct` / `Not yet` feedback from the owner using the
   existing save-aware flow. Do not derive or display a second local grade,
   reveal the correct solution, or unlock a teaching explanation on an error.
7. A failed save retains the exact immutable command and existing recovery UI;
   never re-enable answering to reconstruct that command. Advancement/debrief
   publication waits for the relevant successful acknowledgement. The section
   owner retains Next, explicit finite review and Finish; components do not
   automatically advance, repeat, navigate or award completion.

For the existing pilot, replay is the intentional behavior addition. Preserve
its FR-05 threshold, complete first-pass coverage, authored mistake-only queues,
after-debrief/repeat attribution, unresolved mistakes and saved-policy rules.

## 5. Failure, lifecycle and source policy

- Playback failure is a retryable capability state, not a wrong answer. Show
  generic non-answer-revealing guidance and permit another explicit play request
  or leaving. Do not print exception messages containing hidden content.
- Cancellation stays quiet and grants no hearing permission. No failure,
  cancellation or unsuccessful replay changes attempt counts, durable mistakes,
  completion, coverage or current item/queue position.
- Backgrounding, leaving, owner/store replacement, disposal and prompt/round
  changes invalidate the applicable playback generation and hearing permission.
  Late success or error cannot enable answers, publish feedback, navigate, submit
  an answer or stop a newer owner's playback. Resuming requires fresh successful
  listening; an already committed answer remains answered without resubmission.
- Preserve existing account isolation and command recovery. A transient
  same-owner failed save retries its captured command/store; owner changes retire
  old pending intent rather than transferring it to a replacement owner.
- Reuse injected FR-03 audio and its typed completion/cancellation/failure
  behavior, recording-first alpha policy and exact shared alpha disclosure.
  No player construction in a view, source-policy rewrite, new audio dependency,
  automatic fallback after recording failure or claimed reviewed audio.
- The comparison harness injects fake audio through the owner. Its lifecycle
  tests demonstrate contract behavior, not actual device playback or a production
  comparison persistence path that does not yet exist.

## 6. Accessibility and presentation

Use explicit task instructions and readable control labels, including neutral
sample A/B labels, rather than asking learners to infer what sound to compare.
Keyboard and assistive activation use the same guarded actions as pointer taps.
Expose enabled/disabled, playback activity, selection and feedback meaning
without relying on color. Preserve scrolling and usable controls at 360px width
and large text; avoid keyboard traps and keep normal leaving/navigation available.

Puzzle semantics must not contain hidden words, complete IPA transcriptions,
expected relation metadata or section teaching text. The learner's selected
response and right/wrong feedback may be announced, without revealing an
unselected correct answer. The section's existing debrief remains the only place
that displays its teaching explanation.

## 7. Acceptance and verification

The plan must map these requirements to named tests and owned files. Test new
behavior before runtime edits; establish extraction-preservation assertions
against the current implementation where possible. Existing behavior may produce
coverage-only GREEN; do not invent behavioral RED evidence from fixture errors.

| Requirement | Required evidence |
| --- | --- |
| Real extraction | Pilot mounts the reusable identification component and still uses existing owner/typed commands; no second session/store or dead parallel identification implementation |
| Phoneme-wide contract | Same and different fixtures for vowels and consonants; include same target in different hidden words and a different target without using whole-word/reference equality as the answer key |
| Explicit targets | Comparison instructions identify the intended sound location without revealing its identity; missing/ambiguous authored fixture data is not silently accepted as a meaningful phoneme task |
| Initial hearing gate | Identification cannot answer before its sample succeeds; comparison cannot answer before both samples succeed; success for A alone or a stale prompt is insufficient |
| Replay | Explicit replay works after first success; answers blocked while replay is held; failed/cancelled replay revokes that sample's permission, fresh success restores it; no extra attempts/evidence |
| Failure vs cancellation | Generic failure guidance, quiet cancellation, unchanged evidence, no answer callback, no automatic skip or fallback |
| Single submission / saving | Rapid pointer/keyboard submissions produce one owner command; immediate owner feedback, save lock, same frozen Retry and ACK-only progression survive the extraction |
| Lifecycle / ownership | Held playback/replay through background/resume, prompt/round change, owner change or disposal cannot unlock or submit stale actions; fresh playback required on resume |
| No leakage | Text/semantics/tooltips/error paths omit hidden words, answer-bearing transcription, correct-key metadata and teaching explanations, before and after a wrong answer |
| Accessibility | Keyboard and semantics exercise the real guarded controls, report selection/feedback without color dependence, and work at small width/large text |
| FR-05 preservation | Existing finite-round, threshold, durable mistake/history, honest repeat evidence, saved-policy resume, recovery and owner-cycle regressions remain passing |
| Comparison boundary | Typed Same/Different callback and fake owner harness; no catalogue registration, synthetic learning command, production progress or new recording readiness claims |

Verification layers: pure UI-contract validation, component widget tests with a
controlled owner/audio harness, pilot integration tests through the real discovery
screen, and existing session/repository regressions. Harness-only passing tests
cannot prove real owner persistence or future comparison course integration.

Final code delivery requires independent actual-PR specification/quality review,
whole-feature review and fresh controller full Flutter tests, analysis and release
JavaScript build on the exact reviewed head/current base. Run the existing Python
tests and technical French-audio verifier, check scope/whitespace, and verify that
assets/provenance/licences, root `LICENSE`, dependencies and backend are unchanged.
Missing GitHub checks are not passing CI. Publish scoped reviewed PRs only, fetch
the merged result and verify its tree. Preserve old data, Sound Match work,
branches, worktrees and durable process evidence; do not automatically clean up.

## 8. Non-goals and outstanding gates

No new production comparison curriculum, additional lesson registration,
legacy-lesson conversion, storage migration, generic runner, new scheduler,
changed threshold, randomization, content answer-key rewrite, backend/RPC work,
dependencies, microphone workflow, recording uploads, cloud evaluation or
pronunciation grades. FR-15 remains deferred; no further Qwen investigation or
browser sandbox bypass is authorized.

Real browser/native playback, qualified French linguistic/audio/licensing review,
live Supabase validation, privacy and release remain external gates. Pending
recordings stay pending; fake-audio tests and technical checks do not establish
phoneme pronunciation accuracy or recording suitability. A JavaScript build does
not certify Wasm, real playback or a production pronunciation evaluator.
