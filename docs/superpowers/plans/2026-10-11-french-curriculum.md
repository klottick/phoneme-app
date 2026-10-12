# FR-01 Curriculum Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development task-by-task. The user selected local `ollama/qwen3.8:27b` implementation workers and controller review/merge. Workers do not delegate or merge. Steps use checkbox tracking; no implementation before user review of this plan.

**Goal:** Make the new validated curriculum catalogue the live pilot's content source without changing existing lesson behavior or saved progress.

**Architecture:** Pure immutable models feed deterministic structural/readiness validation and one French catalogue. A compatibility projection replaces the pilot's old item literals; its existing engine/store/UI and legacy game APIs remain intact.

**Tech Stack:** Existing Dart/Flutter >=3.3-compatible language features, current Flutter tests/preferences/widget helpers. No new dependencies or backend changes.

**Spec:** `docs/superpowers/specs/2026-10-11-french-curriculum-design.md` (user approved). Exact signatures: `docs/superpowers/specs/2026-10-10-french-learning-contracts.md` revision 1.

**Execution complete (2026-10-12):** All four tasks and the final review wave are
merged. Completion tracking, verification, rulings and remaining gates are in the
[FR-01 outcome record](../status/2026-10-12-french-curriculum.md); the checklists
below preserve the approved worker handoff.

## Global Constraints

- Migrate the live content source now; there must not be two independently authored pilot item lists in the completed batch.
- Persisted courseId `en-fr`, lessonId `en-fr-u-y`, contentRevision `1`, session version `1`, ordered saved word IDs and policy serialization stay unchanged.
- Ten items remain `tout, tu, rouge, rue, vous, lune, doux, jus, loup, mur`; expected sounds alternate `u,y`; choices remain `['u','y']`.
- Preserve 80% default/custom saved policy, immediate correctness, teaching only at debrief, finite mistake rounds, repeat practice and explicit stale-conflict reload.
- Generic modules do not import French content, widgets, providers, storage or audio plugins. French content may import generic modules; no initialization cycle.
- Preserve all legacy French word/lesson values, ordering and public APIs; non-pilot `sectionForLesson` lookups remain null.
- Planned nodes/content and missing reviewed recordings remain explicit readiness issues, not structural validity failures or fabricated playable/graded content.
- No extra teaching/exam content, map UI, route locking, recording, scoring, speech dependencies, audio assets/playback, evidence migration or new cloud events.
- No runtime edits to session/policy/store/audio/screen/view/router modules. Raise a concrete dependency defect to controller instead of broadening scope.
- Local Qwen workers implement sequentially; controller independently reviews/verifies before authorized PR merges. Preserve process records and unpublished Sound Match work; branch from published origin/main, not local main.

## Review Focus

- Old version-1 saves must survive the new catalogue IDs, including answered/review/custom-policy states: Task 4 literal fixtures and real-store/screen continuation.
- A duplicate/missing linked record must produce deterministic diagnostics, not map overwrites or lookup crashes: Tasks 1–3 ambiguity/multi-error tests.
- An isolated nested mutation must not alter content used by another lesson instance: Task 1 deep immutability tests, Task 4 projection detachment.
- TTS availability declarations must never imply reviewed exam audio or linguistic approval: Task 3 readiness matrix and Task 4 production report.
- Global citation membership cannot override contextual sentence targets or recycle game exposure as held-out success: Task 3 annotated repeated-token and contamination fixtures.

---

## Files, ownership and task order

| Task | Files | Responsibility |
|---|---|---|
| 1 | new core/course/course_exercise.dart, course_curriculum.dart; new test/unit/course_curriculum_models_test.dart | Immutable types and unambiguous lookups |
| 2 | new core/course/course_content_validator.dart; new test/unit/course_content_graph_test.dart; new test/support/course_curriculum_fixtures.dart | Diagnostics/report API and identity/graph/ownership/pool rules |
| 3 | validator above; new test/unit/course_content_payload_test.dart, course_content_readiness_test.dart; fixture additions | Exercise/sentence/coverage correctness and resource readiness |
| 4 | modify core/course/french_course.dart and lesson_section.dart; new test/unit/course_content_test.dart, lesson_section_curriculum_test.dart; new test/widget/course_curriculum_migration_test.dart; new test/fixtures/course_curriculum_legacy_sessions.json | Author catalogue, migrate live pilot and prove old-save parity |

All paths in that table are relative to `frontend/lib/src/` for core modules or
`frontend/` for tests. Each task starts from the previous merged task. Tasks 2/3
share a file deliberately, never concurrently. Task 4 consumes their final API.
Intermediate validator work is not advertised as FR-01 completion. The only
product source migration happens in Task 4 after its RED tests are recorded.

## Coordinator setup

- [ ] User reviews this plan/contracts; retain selected local-worker execution method.
- [ ] Publish/review scoped design+plan docs with the existing PR workflow; baseline product remains published merge `a500651` unless origin/main moved (inspect any intervening changes).
- [ ] Verify existing isolated controller worktree; register new worker worktrees under existing Paseo phoneme-app project, no new top-level project. Detect native management before git fallback.
- [ ] Start a separate SDD ledger for this plan. Record base/head, worker/session, file ownership, RED/GREEN evidence, review loops, PR/merge and limits. Do not redispatch completed pilot/repair tasks.
- [ ] Run baseline full tests/analyzer sequentially in frontend with `/home/klottick/develop/flutter/bin/flutter`; record exact results, not inherited counts.

## Task 1: Immutable curriculum and typed exercise contracts

**Files:** Create the two model modules and `frontend/test/unit/course_curriculum_models_test.dart` only.
**Interfaces:** Produce every constructor/enum/getter/lookup in contract revision 1; consumes no app providers or French catalogue.

- [ ] **Step 1 — Add model tests.** Cover all four subtype kind/skill getters;
  empty/all-whitespace scalar and nonpositive revision/count rejection; preserve
  case-sensitive IDs verbatim; nullable aliases may be absent but not blank.
  Construct exercise choices, token phonemes, node prerequisites, sections,
  options and catalogue lists from mutable input collections; mutate each input
  afterward and attempt exposed-list mutation. Assert original values remain.
  Duplicate IDs are constructible; all five lookups return null when absent or
  ambiguous, return the unique object otherwise, and never hide list entries.
  Example assertions (build records with the exact constructors in the contract):
  ```dart
  expect(exercise.kind, ExerciseKind.listeningChoice);
  expect(exercise.skill, SkillDimension.listening);
  inputChoices.clear();
  expect(exercise.choices, ['u', 'y']);
  expect(() => exercise.choices.add('i'), throwsUnsupportedError);
  expect(duplicateCatalogue.exerciseById('test-u'), isNull);
  expect(duplicateCatalogue.exercises.length, 2);
  expect(() => CourseAudioReference(id: ' ',
    kind: AudioReferenceKind.word, spokenText: 'tout'), throwsArgumentError);
  ```
- [ ] **Step 2 — Verify RED.** Run `flutter test --no-pub test/unit/course_curriculum_models_test.dart`; expect missing model imports/symbols, not dependency/environment failure.
- [ ] **Step 3 — Implement the model modules.** Named required constructor fields
  are exactly those in the contracts. Final subtypes determine kind/skill; do not
  add mutable caches, copyWith, persistence JSON, content validators or UI.
  Relationship-invalid fixtures remain constructible; only documented scalar
  checks are constructor errors. Unique-or-null lookup may use a bounded scan.
- [ ] **Step 4 — Verify GREEN.** Rerun the named test; run full `flutter test --no-pub` and `flutter analyze --no-pub`, all exit 0. Check range whitespace and model import boundary.
- [ ] **Step 5 — Commit/report/PR.** Stage only the three owned files, commit
  `feat(course): immutable curriculum and exercise contracts`, push task branch,
  open PR main. Report base/head/PR, exact tests/counts/logs and self-review;
  controller independently reviews before merging. No worker merge.

## Task 2: Structural catalogue validation

**Files:** Create validator, graph tests and shared fixtures only.
**Interfaces:** Consume Task 1 types/lookups. Produce complete diagnostic/report,
AudioResourceStatus and validateCourseContent signatures in contract revision 1.
Task 3 fills payload/readiness rules into that same public validator; no overloads.

- [ ] **Step 1 — Add fixtures and structural tests.** Shared helper:
  `CourseCurriculum listeningFixture({List<CourseNode>? nodes,
  List<CourseSection>? sections, List<CourseExercise>? exercises,
  List<CourseSentence>? sentences, List<CourseAudioReference>? audioReferences,
  List<PhonemeCoverage>? phonemeCoverage})`. Defaults: courseId `test-course`,
  revision 1; authored required hear lesson `test-listen`, section `test-section`,
  requiredItemCount 1; practice/existingCurated exercise `test-u`, word/alias
  `tout`, expected u, choices u/y, audio `fr-word-tout`/word/spokenText tout.
  Coverage u authored references test-u, y planned empty. Expose immutable
  `fixtureCitations` (`tout:[t,u]`, `tu:[t,y]`, synthetic `new-u:[n,u]`),
  `fixtureExposure` (`tout,tu`) and `fixtureAudioResources` (fr-word-tout TTS).
  Null helper args use defaults; supplied empty lists must stay empty. No
  production copyWith or hidden French provider imports in fixture code.

  Add table-driven mutations of this fixture for each rule/code below. A valid
  baseline has errors empty; a malformed fixture reports its code; repeating
  validation gives identical `(code,recordId,use)` sequences. Combine a missing
  section, duplicated audio ID and cycle; assert all three independent diagnoses,
  no thrown lookup/null exception and unchanged caller collections.

  | Code | Concrete rejecting fixture |
  |---|---|
  | duplicateId | Two records sharing an ID in each of the five lookup namespaces |
  | duplicateMembership | Repeated prerequisite/section/exercise membership ID |
  | missingReference | Node/section/exercise link points to an absent or ambiguous ID |
  | cyclicPrerequisite | Self edge and two-node A→B→A cycle |
  | optionalPrerequisite | Required lesson depends on optional game |
  | backwardStage | Hear main node depends on spell main node |
  | invalidNodeKind | Assessment outside assess; review/game/articulation declared required |
  | ownershipMismatch | section.nodeId or exercise.sectionId disagrees with owning list |
  | unownedRecord | Section/exercise is in the catalogue but in no parent's list |
  | plannedPayload | Planned node declares a section |
  | missingSection | Authored lesson/assessment has zero sections |
  | poolSizeMismatch | Required count 2 but one distinct linked item (also reject excess) |
  | duplicateLegacyItemId | Distinct listening exercise IDs share an alias in one section |

  Scalar explanation/title/ID rejection is covered in Task 1; do not make fake
  malformed subclasses to bypass final models. Duplicate names across different
  record namespaces are allowed. Duplicate sentence token IDs belong to Task 3.
- [ ] **Step 2 — Verify RED.** `flutter test --no-pub test/unit/course_content_graph_test.dart` fails for missing validator or named rules.
- [ ] **Step 3 — Implement structural phases.** Return one immutable report;
  error use=null. Detect duplicates before resolving references. Walk graph via
  deterministic DFS in authored order; report each encountered back edge once,
  avoid recursion into absent/ambiguous records. Check ownership in both directions
  and required distinct pool counts. Invalid children cannot suppress unrelated
  errors. No readiness logic or linguistic inference in this task.
- [ ] **Step 4 — Verify GREEN.** Run graph and model tests, full tests/analyzer;
  expect no failures. Report partial validator scope clearly: payload/readiness
  completion is Task 3, no production migration yet.
- [ ] **Step 5 — Commit/report/PR.** Only three owned files; commit
  `feat(course): deterministic curriculum graph validation`, push/open PR; controller
  reviews spec/quality, independently verifies and merges before Task 3.

## Task 3: Payload, coverage and resource-readiness validation

**Files:** Modify validator/shared fixture file; create payload/readiness tests.
**Interfaces:** Same validateCourseContent/report/types as Task 2, no API changes.

- [ ] **Step 1 — Add failing payload fixtures.** Each rule below gets a specific
  valid fixture and one-field invalid variant; assert error code, not message prose.
  Test all subtype branches and practice vs assessment-stage equivalents.

  | Code | Rejecting condition |
  |---|---|
  | invalidExercisePlacement | Wrong practice stage, purpose/node mismatch, read-aloud in lesson or non-articulation non-assessment node |
  | invalidTargets | Duplicate/empty node target labels, undeclared target, child target outside node targets, empty read-aloud targets |
  | invalidListeningChoices | Fewer than two distinct choices, duplicate label, expected sound absent/repeated, choice outside inventory |
  | invalidSpellingOptions | Fewer than two options, duplicate ID/text, absent correct option |
  | unknownWord | Word exercise wordId absent from citationPhonemes |
  | citationTargetMismatch | Listening expectedSound or explicit spelling targetSound not in that word's curated phonemes |
  | invalidAudioKind | Word/sentence/read-aloud uses other than word/sentence/paragraph reference |
  | audioTextMismatch | Word text, sentence.text or read-aloud prompt disagrees with spokenText |
  | invalidSentenceTokens | Empty tokens, duplicate IDs or phoneme labels, missing/extra text between ordered tokens |
  | invalidSentenceTargets | Hunt has zero target tokens or no non-target word distractor (punctuation alone insufficient) |
  | sentenceAudioMismatch | Hunt audioRefId differs from its referenced sentence's audioRefId |
  | invalidCoverage | Duplicate coverage sound, planned coverage with exercises, authored coverage empty, duplicate/missing/nonpractice/nontarget exercise references |
  | exposedAssessmentWord | Listening/spelling assessment reuses an exposed game/practice word |
  | exposedAssessmentAudio | Assessment reuses practice audioRefId |

  Sentence fixture text `tout tu tout.` has four distinct token IDs, annotations
  [t,u], [t,y], [t,u], [] and target u. Assert the two distinct tout occurrences
  match; punctuation is not a word distractor. A separate synthetic annotation
  fixture deliberately differs from citation phonemes: acceptance follows its
  reviewed-in-fixture contextual labels, never a spelling/citation guess. These
  fixtures establish software behavior, not French linguistic approval.
  Include absent/ambiguous audio and sentence references (missingReference),
  isolated valid token punctuation, and repeated phoneme labels within one token.

  At least one assessment listening fixture uses synthetic unexposed word new-u;
  its reviewed audio/key baseline has no assessment readiness issue. Adding it
  to exposure or sharing a practice audio reference yields the corresponding error.
- [ ] **Step 2 — Add failing readiness matrix tests.** No readiness issue becomes
  a structural error. Codes and uses:
  | Code | use / condition |
  |---|---|
  | plannedNode | practice (assessment for assessment node) / planned payload slot |
  | plannedPhoneme | practice / planned discovery coverage |
  | pendingContentReview | exercise purpose / pending exercise or referenced sentence |
  | unreviewedAssessmentContent | assessment / existingCurated or pending assessed exercise/sentence |
  | missingPracticeAudio | practice / referenced resource absent or missing |
  | missingReviewedAudio | assessment / any declared word reference without reviewedRecording, or assessed sentence/paragraph resource without reviewedRecording |
  | speakingUnassessed | assessment / read-aloud without validated evaluator (always in FR-01) |
  TTS + existingCurated practice has no missingPracticeAudio, but does have
  missingReviewedAudio. Reviewed recording + pending key still has content
  issues. Unknown resource-map keys never repair dangling references. Resources
  are injected declarations, not device/file probes; speaking never gains scores.
- [ ] **Step 3 — Verify RED.** Run both new test files; record real missing rule
  failures on Task 2 implementation, not compile errors caused by changed APIs.
- [ ] **Step 4 — Implement payload/readiness phases.** No spelling-to-phoneme
  inference; exact ordered token text coverage permits whitespace gaps only.
  A word token is text containing a Unicode letter (not punctuation-only).
  Compare target membership, not incidental phonemes in practice words.
  Exposure is supplied IDs union practice word-exercise IDs; practice audio
  references form a separate contamination set. Do not let caller omission from
  exposure convert an already-authored practice word into held-out content.
  Emit all report lists in contract phase order; no score, ready-to-route flag,
  audio probing or exception containing production hidden data in the learner UI.
- [ ] **Step 5 — Verify GREEN.** Run all four model/graph/payload/readiness files,
  full tests/analyzer, whitespace; retain graph behavior and report API.
- [ ] **Step 6 — Commit/report/PR.** Commit only owned files as
  `feat(course): validate exercise keys and honest content readiness`, push/open
  PR; controller rechecks subtype placement, resource truth and deterministic
  malformed-graph behavior before independent verification/merge.

## Task 4: Author French catalogue and migrate the live pilot

**Files:** Modify only french_course.dart and lesson_section.dart; create the
three tests and literal JSON fixture file listed in the ownership table.
**Interfaces:** Consume final model/validator contracts. Produce French exports
and LessonSection.fromCurriculum constructor exactly as contract revision 1.

- [ ] **Step 1 — Write literal compatibility fixtures and migration tests.**
  Fixture JSON contains five named version-1 checkpoints and a frozen legacy
  word/lesson parity snapshot. Copy values from baseline a500651, not from a
  post-migration catalogue; provenance includes that SHA. Saved itemIds/first-pass
  queue literally equal the ten old word IDs. Every checkpoint includes all
  current toJson fields (version, sessionId, contentRevision, itemIds, queue,
  position, round, attemptCount, phase, submittedThisRound, lastCorrect, answered,
  latestAnswers, policy). Exact checkpoint differences:
  | Name | Fields beyond common version1/revision1/ten IDs/sessionId legacy-<name> |
  |---|---|
  | fresh | position0, round1, attempts0, exercise, submitted[], lastCorrect null, answered false, latestAnswers{}, threshold80 |
  | answered | position0, round1, attempts1, exercise, submitted[tout], lastCorrect true, answered true, latestAnswers{tout:true}, threshold80 |
  | debrief | position10, round1, attempts10, debrief, submitted all ten, lastCorrect true, answered false, latest all true except tu=false, threshold80 |
  | review | queue[tu], position0, round2, attempts10, exercise, submitted[], lastCorrect true, answered false, same latest as debrief, threshold80 |
  | custom-policy | same debrief state, threshold100 (9/10 cannot finish) |
  Seed canonical processedSessionId/count matching each checkpoint. Use literal
  historical lessons `[en-fr-vowels]`, score `{arcade:55}`, sibling section and
  listening:u/y aggregates matching the saved attempts (fresh: none; answered:
  u attempts1/correct1; debrief/review/custom: u attempts5/correct5 and y
  attempts5/correct4), plus
  a sentinel pre-existing pending event/unknown legacy field. Keep backend null
  so no uploads occur. Do not call saveLessonSection to generate the seed: that
  could reset incompatible entries and conceal data loss.

  Unit assertions: exact ten new IDs/aliases/words/choices; legacy parity for all
  words, IPA/membership/hints and five lessons; seven phoneme statuses; empty
  sentences and no assessment exercises; authored catalogue has no structural
  errors but planned/missing-reference issues. Assert all new French maps/sets
  detach/forbid mutation. Optional/planned graph matches spec IDs/order.

  Synthetic projection assertions: change item order/words/targets in a valid
  injected listening catalogue and assert LessonSection derives those fields,
  metadata and revision; mutation does not affect projection. Missing/ambiguous
  node, unsupported kind, wrong ownership, required-count mismatch, absent or
  duplicate aliases, different ordered choices and missing expected choice all
  throw StateError. It cannot silently filter or fall back to production literals.
  Assert sectionForLesson(en-fr-u-y) returns the cached frenchUySection instance,
  and every other legacy/unknown lesson ID returns null as before.

  Real-store/screen assertions for each seed: first load is exact and writes
  nothing; answered Next advances without rerecording; review restores Item1
  of1 and a closed hearing gate, then records its correction once; fresh advances
  after Listen/answer; normal debrief Finish completes once; review-mode Finish
  retains completion list; custom-policy debrief remains failing until its mistake
  review is corrected. Include explicit widget policy80 vs saved100 preservation.
  Verify sentinel outbox/sibling/scores survive, new answers use old IDs/revision,
  and a reopened screen resumes the continued saved state.
- [ ] **Step 2 — Verify RED.** Run course_content_test.dart and
  lesson_section_curriculum_test.dart; expect missing French exports/projection.
  Run literal snapshot parsing/store tests before migration too: compatibility
  fixtures must already pass against old IDs (these are the preservation oracle,
  not supposed to fail). Capture separate evidence from new-API RED failures.
- [ ] **Step 3 — Author the catalogue.** Keep legacy declarations unchanged;
  derive metadata from original en-fr-u-y lesson. Author the ten exercises solely
  in frenchCurriculum; all references fr-word-<existing-word>. Exact seven-node
  order: en-fr-u-y, en-fr-targeted-review, en-fr-games, en-fr-articulation,
  en-fr-find-sounds, en-fr-connect-spellings, en-fr-checkpoint. Planned titles:
  Targeted review, Games, Articulation coaching, Find sounds in context,
  Connect sounds and spellings, Check your progress. Optional nodes target all
  seven sounds and have no prerequisites; planned required main nodes target
  all seven and have the spec's prerequisite chain. No planned sections.
  Find/spell main nodes have kind lesson; checkpoint has kind assessment.
  Maps derive from existing words; audio declarations TTS only, no claimed native
  voice availability. Validate synchronously before publishing the pilot bridge.
- [ ] **Step 4 — Replace the old pilot authoring with the projection.** Add the
  exact factory; preserve current normal constructors/equality/cached lookup.
  Remove only duplicated ten-item literals from _buildFrenchUySection, now check
  frenchCurriculumValidation.isStructurallyValid and project the catalogue.
  Use aliases for saved IDs, never namespaced exercise IDs. Throw StateError for
  unsupported projection shapes; never silently restore fresh/drop records.
  No session/store/policy/runtime screen changes or extra routes.
- [ ] **Step 5 — Verify GREEN and integration.** Named new unit/widget tests and
  existing lesson_section_content/session/store, course_arcade/sync, discovery
  lesson/recovery/repeat/accessibility and audio suites all pass. Run full tests,
  analyzer and web build sequentially; whitespace/import/scope checks. Record
  exactly which literal fixtures passed before and after migration, distinct
  from newly generated test sessions. Do not run nonexistent unpublished tests.
- [ ] **Step 6 — Commit/report/PR.** Stage only the six owned files, commit
  `feat(course): migrate live pilot content to validated French curriculum`,
  push/open PR main. Report old-save evidence, data parity, validation diagnostics,
  base/head/PR and hardware/content/backend limits. Controller reviews source
  authority and compatibility before independent rerun/merge.

## Final controller gate and publication

- [ ] Review full batch range against the approved spec/contracts, not only the
  final migration commit; zero unaddressed Critical/Important findings.
- [ ] Independently run complete Flutter tests/analyzer/JS build and fresh
  migration/validator adversarial checks. SDK commands sequential, logs outside
  repo under /tmp/opencode. Inspect known Wasm dry-run warnings; no Wasm claim.
- [ ] Confirm merged frontend equals reviewed head and origin/main; preserve
  unpublished Sound Match changes. Do not reuse old external tests importing
  removed worker-worktree paths without adapting their helper imports first.
- [ ] Publish FR-01 outcome ledger: workers/tasks/PRs/reviews/fix evidence,
  migrated pilot, exact verification, readiness blockers and coordinator rulings.
  Update backlog links/readiness; do not mark FR-02+ consumers implemented merely
  because enum/node/model contracts now exist. Process records retained; worker
  worktree closure only under a new explicit cleanup request.

## Plan self-review / requirement-to-task map

| Approved requirement | Owner / proving evidence |
|---|---|
| Immutable exact contracts, unique-or-null lookups | Task1 mutation/getter/duplicate tests |
| Stage graph, optional quests, pool and ownership validation | Task2 graph/error fixtures |
| Typed keys, contextual tokens, held-out separation, honest resources | Task3 payload/readiness matrices |
| Seven-sound coverage and sole pilot content source | Task4 exact catalogue/projection assertions |
| Existing APIs, old saves, policy, aggregates and outbox retained | Task4 literal parity + real store/screen |
| No new routes/recordings/scoring/dependencies | Every task file boundary; final range review |

The sequence consumes only previously merged interfaces. Test helper APIs are
explicit, diagnostics have exact codes, scalar failures do not conflict with
validator fixtures, and readiness never becomes a runtime voice/grade promise.
The already-selected method is local Qwen implementation with controller review;
only user review of this written plan/contracts remains before dispatch. Planning
clarifies one model field in the approved spec: spelling exercises carry explicit
targetSound, so the validator never guesses teaching targets from orthography.
