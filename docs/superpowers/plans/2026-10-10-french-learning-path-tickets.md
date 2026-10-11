# French Learning Path Implementation Plan — Draft Tickets

> **For agentic workers:** After the review gates below, use `subagent-driven-development` or `executing-plans` for an approved ticket. Track steps with checkboxes. This draft is not authorization to implement the entire backlog or to launch agents.

**Goal:** Help English speakers hear, identify, spell, and produce French phonemes through a puzzle-first learning path, targeted mistake review, and transparent per-phoneme progress.

**Architecture:** Extend the existing directional course, not the legacy language-only tools. Keep authored curriculum, audio, exercise evaluation, session scheduling, evidence, and UI separate. A main path sequences learning; optional side quests provide games, articulation coaching, and targeted review.

**Tech stack:** Existing Dart/Flutter, Riverpod, local preferences, audio/recording abstractions, and optional Supabase progress backend. Speech evaluation stays local; new local-model dependencies and microphone hosting requirements need separate approval. No cloud speech service or generated-audio pipeline in this iteration.

**Spec:** The proposed brief below records the user's review and provisional policies. No written design for this larger redesign has been approved. `FR-00` produces reviewed subproject specs and execution contracts before implementation tickets are dispatched. The existing Sound Match spec remains authoritative for its game rules.

**Status:** Draft for product review, 2026-10-10. Repository inspected at `4dff777` on `feat/phoneme-word-match`. Documentation only; no product changes or external tickets created.

**Execution update (2026-10-11):** The user authorized local Qwen workers, small PRs, controller review/merge, and durable state tracking. The first approved execution batch is defined in `2026-10-11-french-first-section.md` and its scoped design spec; that spec supersedes this draft's provisional item/retry defaults for the pilot only. The rest of this backlog stays queued. Current state lives in `../status/2026-10-11-french-first-section.md`.

## 1. Product brief

### Requirements from the review

1. A Duolingo-inspired overworld: one main path, optional side quests, puzzles, and explanations.
2. Early stages teach phoneme discrimination; later stages emphasize sound–spelling relationships.
3. Sentence puzzles ask where a phoneme occurs, including believable red herrings.
4. Speaking exercises check pronunciation and focus on English-speaker pitfalls.
5. Lessons contain multiple examples, require eventual mostly-correct performance, and bring back mistakes.
6. Do not front-load the explanation: let learners discover the pattern, then present explanations at the end of a section (confirmed in follow-up).
7. Supply reliable French reference sounds for every supported game.
8. Teach mouth/tongue/lip positioning and how to produce the sounds.
9. Offer an initial paragraph-based assessment and a later listening/identification/spelling exam.
10. Show an overall view of scores for individual phonemes.

### Recommended approach and alternatives

- **Recommended: incremental course upgrade.** Reuse current games, account isolation, and local-first progress. Deliver a complete listening lesson loop first, then add the map and richer exercises. More integration work than a rewrite, but existing behavior remains usable and testable.
- **Navigation-first reskin.** Deliver the map quickly using today's lessons. Lower initial cost, but leaves explanations-first, weak completion requirements, and unreliable audio unresolved. Not sufficient on its own.
- **Full course/speech rewrite.** Maximum architectural freedom, but introduces migration risk and makes an unvalidated pronunciation service a release dependency. Not recommended.

### Proposed policies — require approval in FR-00

**Confirmed assessment decision:** Listening/identification and read-aloud speaking are different sections with separate results. This decision does not approve the remaining proposed policies below.

**Confirmed completion decision:** Start with an **80%** completion threshold and make it configurable. Keep the threshold in lesson policy/configuration, not a hard-coded correct-answer count; a learner-facing settings control has not been requested.

**Confirmed platform decision:** Recording and pronunciation assessment must support **both the browser and native mobile apps**. Browser microphone verification requires a secure context (HTTPS for remote/LAN access); native mobile requires real iOS/Android permission, capture, playback, and cleanup checks. Platform scope does not establish that a pronunciation evaluator is accurate.

**Confirmed simplicity/privacy decision:** Pronunciation evaluation stays **local for now, with no recording uploads or cloud speech services**. Generated reference audio is a possible later option, not a current implementation ticket. Start with a small bundled French reference catalogue and the existing labeled TTS practice fallback; do not add a generation pipeline. Validated local automatic grading remains a separate research gate, so the initial speaking section offers recording, self-comparison, and coaching without invented scores. Existing optional progress-only backup is unchanged; it must not include recordings.

**Confirmed explanation timing:** Explanations appear **at the end of a section**, not after individual attempts. The user rejected first-attempt unlock and immediate “Help me start” access to explanations. Task instructions, playback controls, and technical/accessibility assistance remain available during puzzles; they must not reveal the teaching rule or answers. This governs course sections, not a silent redesign of existing arcade help.

**Confirmed correctness timing:** Show **right/wrong after each submitted, objectively scored answer**. This immediate result is distinct from the teaching explanation, which remains at section end. Playback/capture failures or unvalidated speaking results are unavailable/unassessed, not “wrong.” Record the answer and schedule any mistake without revealing the rule early.

- Pilot with `/u/`, `/y/`, `/i/`, `/o/`, `/ɔ̃/`, `/ɑ̃/`, and `/ʁ/`; this is not the complete French phoneme inventory. Expansion requires content and audio coverage, not just new labels.
- Main stages: **Hear the difference → Find sounds in words/sentences → Connect sounds and spellings → Demonstrate with an exam**. Articulation coaching can follow an early section's debrief; speaking need not wait until the final exam.
- Begin a section with puzzles, not the full rule; show right/wrong after each scored answer and present teaching explanations in the section-end debrief. Do not offer first-attempt or error-triggered explanation unlocks. Proposed section boundary: a finite authored group of exercises ends after its required first-pass submissions, regardless of whether the lesson's 80% completion threshold has been reached. The debrief can then lead into remediation; a learner below threshold should not be trapped without the explanation. Section size/boundaries still require approval; correctness timing is settled.
- Completion policy: `completionThresholdPercent` defaults to `80` and is configurable. Require `ceil(distinctRequiredItems * completionThresholdPercent / 100)` correct latest item outcomes, after every required item has been attempted; repeated successes on one item cannot inflate coverage. At 80%, ten items require eight correct; eight items require seven. Proposed configuration validation: integer percentages from 1 through 100, with the policy revision saved for resumable sessions. This is a completion rule, not a validated mastery estimate.
- Remaining starter-session proposals: eight distinct authored items; incorrect items reappear after two intervening items when possible; unresolved mistakes remain due even if the lesson completes. Cap a sitting at twelve submissions, save it, and offer a break/resume rather than an endless retry loop. Item count, retry delay, and sitting limit still require approval.
- Retry success updates an item's latest outcome but never erases its earlier incorrect attempt. Repeated examples help remediation; unseen held-out examples assess transfer.
- Side quests are optional and never gate the main path. No lives, punitive currency, or streak requirement. “Duolingo-inspired” means recognizable path structure, not copying its art or adding its monetization systems.
- Use curated, licensed French recordings as reference material. TTS is an explicitly labeled development/practice fallback, not the reference for graded listening exams or isolated phoneme production.
- Separate **listening**, **spelling**, and **speaking**. Show practice accuracy with sample size, held-out assessment results separately, and “not assessed” when no valid evidence exists. Do not present an invented calibrated mastery/confidence score.
- A paragraph read aloud measures production, not listening comprehension. A listened-to paragraph with identification questions measures listening. The user confirmed separate sections and results. Remaining proposals: make the speaking section optional until validated scoring exists, and do not let the paragraph alone determine placement.
- Initial assessment can be skipped. Before validation, recommend a start/review point rather than automatically skip or permanently lock curriculum based on a score.
- Sentence correctness follows authored contextual pronunciation, not spelling guesses or the existing citation-word membership list. Limit initial content to reviewed sentences; annotate or exclude liaison, elision, and pronunciation variants explicitly.

### Decisions that block specific tickets

| Decision | Proposal / question | Blocks |
|---|---|---|
| D1: assessment sections — resolved | User confirmed separate listening/identification and read-aloud speaking sections; results stay separate. | Format settled for FR-12/FR-16; validated local speech scoring is still gated by FR-15. |
| D2: lesson completion/sections — partially resolved | Default 80%, configurable; explanations at section end; right/wrong after each scored answer are confirmed. Item count, section boundaries, retry delay, sitting limit, and configuration exposure still need review. | Remaining policies block final FR-05/FR-07 design; threshold, explanation timing, and correctness timing are settled. |
| D3: speech platform — resolved | User confirmed both browser and native mobile. Use HTTPS for remote browser microphone testing; verify iOS/Android on real devices. | Scope settled for FR-14/FR-15/FR-16; local scoring validation remains required. |
| D4: speech evaluation — resolved | Local-only for now; no recording uploads or cloud speech services. Defer generated-audio tooling. | FR-15/FR-16 are local-only, deferred validation work; research criteria, recording retention, and local-model footprint still need review. |
| D5: audio/content resources | Who supplies/reviews recordings, rights, sentence pronunciation, and articulation instructions? | FR-02, content sign-off throughout |

## 2. Current implementation and constraints

- `frontend/lib/src/core/course/french_course.dart`: five lessons, curated citation-word IPA/membership, English-speaker explanations. No sentence annotations or exercise/session model.
- `frontend/lib/src/features/course/course_lesson_screen.dart`: explanation first; one-pass listening choices; wrong answers still permit finishing; native recording/self-comparison only.
- `frontend/lib/src/core/course/course_progress.dart`: course/account-scoped local storage, serialized writes, listening/spelling aggregates, completions, arcade scores, and cloud outbox. No item-level mistake queue or assessment history.
- `frontend/lib/src/core/course/course_audio.dart`: device French TTS with cancellation safeguards. No bundled reference catalogue.
- `frontend/lib/src/features/home/home_screen.dart`: lesson cards and bottom Practice tools dropdown, not an overworld.
- `frontend/lib/src/features/course/course_progress_screen.dart`: separate evidence counts and arcade scores; no full phoneme inventory dashboard or speaking results.
- `frontend/lib/src/features/arcade/sound_match_screen.dart` and `sound_word_help.dart`: redesigned word-based Sound Match with optional audio. Preserve its neutral tiles, match rules, and evidence exclusions.
- `frontend/lib/src/features/arcade/arcade_screen.dart`: separate Word Match. Add audio access without silently replacing its rules.
- `frontend/lib/src/core/services/phoneme_assessment_service.dart`: experimental byte statistics/phoneme hash and transcription string comparison. Neither establishes correct phoneme production; do not use these scores for the new course.
- `backend/supabase/migrations/202609180001_language_pair_courses.sql`: current RPC permits listening/spelling and five registered lesson IDs only. New lesson IDs, speaking evidence, and assessments need coordinated additive changes.

### Global constraints

- Preserve existing lesson history, arcade scores, game checkpoints, and guest/account isolation. Do not relabel historical completion as proven mastery.
- Guest learning must work without a backend, API key, or account. Unavailable audio/scoring is a capability state, never a wrong answer.
- Audio must not start automatically in a browser before a user action. Playback/recording cleanup must survive navigation, backgrounding, delayed startup, and account changes.
- Do not alter shared schemas or APIs independently in parallel tickets. Approve contracts first; update them with all affected owners if necessary.
- No recording uploads, cloud speech services, or speech-service credentials. Evaluation must run locally on the device/in the browser; any self-hosted scoring server would require a separate scope decision. Keep recording capture/retention transparent and provide cleanup/deletion.
- Do not add generated-audio tooling in this iteration. Keep the reference catalogue small; label the existing TTS practice fallback and never substitute it silently for reviewed exam references.
- Do not add unrelated legacy-tool refactors, cloud download/merge, a vocabulary/grammar course, or additional games to this scope.
- Implementation work belongs in a worktree registered under the existing Paseo `phoneme-app` project. Do not create a new top-level project. Do not merge/push without a separate request.

### Review focus

1. A correct retry must not turn repeated memorized answers into held-out assessment success: FR-04, FR-05, FR-12.
2. Wrong answers, interrupted sessions, and save failure must not unlock the next node or lose mistakes: FR-04, FR-05, FR-07, FR-11.
3. Unavailable French audio/microphone/scorer must not fabricate failure or trap the learner: FR-03, FR-06, FR-14, FR-16.
4. “Select all words” and visually plausible silent-letter distractors must not pass sentence puzzles: FR-01, FR-08.
5. Guest/account switching, content revisions, and outbox replay must not mix owners or reinterpret old results: FR-04, FR-17, FR-18.

## 3. Ticket conventions and agent handoff

Each ticket below has one accountable owner. `P0` establishes the learning foundation; `P1` completes the intended experience; `P2` is validation-gated, not discarded. Except FR-00, tickets are **blocked on approved design/contracts** even where only functional dependencies are listed.

Proposed filenames are ownership boundaries, not permission to invent incompatible interfaces. FR-00/FR-01 must freeze constructors, method signatures, serialization, IDs, and mock fixtures in `docs/superpowers/specs/2026-10-10-french-learning-contracts.md` before workers rely on them.

### Common implementation checklist (applies to each implementation ticket)

- [ ] Read the approved subproject spec, contract revision, ticket, and existing neighboring code.
- [ ] Confirm all dependencies and file ownership; do not implement neighboring tickets “to make it work.”
- [ ] Add the ticket's failing unit/widget tests; run them and confirm a relevant failure.
- [ ] Implement the minimum scoped change; rerun the named tests and analyzer.
- [ ] Check every acceptance criterion; list automated versus manual evidence separately.
- [ ] Obtain review, resolve findings, and commit only the ticket's files after approval of the execution workflow. Never stage unrelated work.
- [ ] Handoff: commit/worktree, files changed, contract consumed/produced, exact test commands/results, remaining limitations, and manual checks required.

Run Flutter commands from `frontend/`. Test paths below are existing or planned files; a planned test is not currently runnable until its ticket creates it. Speech/content investigation tickets deliver evidence reports rather than pretend TDD proves linguistic validity.

### FR-00 — Approve product policy and divide the design into subprojects

**Priority/type:** P0 / design gate. **Owner:** product lead + coordinating agent. **Depends on:** user review of this draft.

**Outcome:** An agreed, staged scope that implementation agents cannot reinterpret independently.

**Files:** Create reviewed specs under `docs/superpowers/specs/` for lesson/evidence foundations, audio/content, path/assessment UI, and pronunciation; create `2026-10-10-french-learning-contracts.md`. Update this backlog with links and readiness.

- [x] Resolve D1: separate listening/identification and read-aloud speaking sections, with separate results.
- [x] Record D2 completion decision: 80% default with a configurable threshold.
- [x] Record D2 explanation decision: explanations at section end, with no first-attempt/early-help unlock.
- [x] Record D2 correctness decision: right/wrong after each submitted, objectively scored answer.
- [x] Resolve D3: both browser and native mobile recording/pronunciation assessment.
- [x] Resolve D4: local-only pronunciation evaluation; defer generated-audio tooling and keep the initial scope simple.
- [ ] Resolve remaining D2 policies and D5 one at a time; confirm pilot inventory, section boundaries, completion, placement policy, and local evaluation/retention requirements.
- [ ] Approve one working vertical slice: `/u/` versus `/y/`, puzzle-first listening, section-end explanation, mistake retries, saved progress, reference audio.
- [ ] Specify session/evidence/audio/exercise contracts, error states, ID/version policy, and legacy completion treatment.
- [ ] Produce a detailed TDD execution plan per approved subproject, rather than dispatching this entire draft as one implementation.

**Acceptance:** User approves the written specs and plans; every downstream ticket is either ready with a contract revision or explicitly blocked. Missing audio/content reviewers and speech feasibility remain visible blockers.

**Verification/handoff:** Requirement-to-ticket review and published contract examples; no product code.

### FR-01 — Author the curriculum and exercise contracts

**Priority:** P0. **Owner:** curriculum/model agent. **Depends on:** FR-00.

**Files:** Create `frontend/lib/src/core/course/course_curriculum.dart`, `course_exercise.dart`, `course_content_validator.dart`; modify `french_course.dart`; create `frontend/test/unit/course_content_test.dart`.

**Consumes/produces:** Approved IDs and contracts; immutable `CourseNode`, `CourseSection`, `CourseExercise`, `ExerciseKind`, `SkillDimension`, `CourseSentence`, and `SentenceToken` models, plus a validated course catalogue. Content records use stable IDs, section membership, audio references, targets, distractors, section-debrief explanation/articulation references, and curriculum revision.

- [ ] Sequence discrimination before spelling, with review/game/articulation branches and assessment nodes.
- [ ] Author the `/u/`–`/y/` vertical slice with enough distinct examples for the approved session policy; separate practice from held-out exam items.
- [ ] Validate prerequisite references, cycles, duplicate IDs, missing audio references, ambiguous answer keys, and undersized pools.
- [ ] Preserve citation-word membership for games; sentence tokens own contextual target annotations and accepted variants.

**Acceptance:** No phoneme inference from spelling; every exercise has a reviewed answer/explanation; missing assets are reported by validation, not hidden until play. Every proposed pilot phoneme is either covered or visibly not yet authored. Existing word/game content continues working.

**Verify:** `flutter test test/unit/course_content_test.dart test/unit/sound_match_content_test.dart test/unit/course_arcade_test.dart`.

### FR-02 — Produce and linguistically review French reference audio

**Priority:** P0. **Owner:** audio/content worker + qualified French reviewer. **Depends on:** FR-00, FR-01 identifiers; D5.

**Files:** Create `frontend/assets/audio/fr/`, `frontend/assets/audio/fr/manifest.json`, `docs/french-reference-audio.md`, and `frontend/test/unit/french_audio_manifest_test.dart`. Do not edit `pubspec.yaml`; hand asset registration to FR-03.

**Produces:** Licensed, reviewed word, isolated-sound, sentence, and paragraph assets mapped to content IDs, with speaker/accent, recording provenance, format, and rights metadata. Scope is all content used by supported games/lessons, not all French words.

- [ ] Audit all supported arcade word/audio IDs and the pilot exercises, including nasal-vowel and `/ʁ/` references.
- [ ] Start with a small bundled catalogue and one consistent reviewed voice; do not build generated-audio tooling, a multi-speaker library, or a recording-production platform. Expand only as approved lesson/game coverage requires.
- [ ] Supply native/reviewed recordings; isolated sounds must not contain an unintended English glide or added syllable.
- [ ] Review pronunciation, intelligibility, clipping, consistent volume, accepted variants, and exam/paragraph suitability.
- [ ] Validate manifest coverage, duplicate IDs, missing files, codec compatibility, and provenance.

**Acceptance:** Every released supported game's word can play a reviewed French reference; graded listening content has reviewed assets. Missing coverage is a release blocker, not a fabricated recording or unmarked TTS substitution.

**Verify:** `flutter test test/unit/french_audio_manifest_test.dart`; reviewer sign-off plus browser/iOS/Android playback sample. Automated tests cannot substitute for linguistic review.

### FR-03 — Add a shared reference-audio player

**Priority:** P0. **Owner:** audio-platform agent. **Depends on:** FR-01, FR-02 manifest contract.

**Files:** Modify `frontend/lib/src/core/course/course_audio.dart`, `frontend/pubspec.yaml`, `frontend/test/unit/course_audio_test.dart`; create `course_audio_catalog.dart` beside it.

**Consumes/produces:** FR-02 manifest; approved playback-by-reference-ID contract with stop/cancel/error semantics, retaining compatibility with current `CourseAudio.speak(String)` callers until integration.

- [ ] Add bundled playback for words, sounds, sentences, paragraphs, and available reviewed slow versions.
- [ ] Keep TTS fallback labeled and policy-controlled; graded exercises cannot silently use fallback or pretend playback completed.
- [ ] Preserve cancellation ordering so stale requests cannot start after stop/navigation; normalize missing assets and unsupported playback as retryable capability failures.

**Acceptance:** No audio initializes until requested; completion means actual playback completed; browser user-gesture restrictions are handled; stops work during startup/playback; offline bundled assets play. Existing Sound Match help remains compatible.

**Verify:** `flutter test test/unit/course_audio_test.dart test/widget/sound_word_help_test.dart`; manual native/browser audio checks.

### FR-04 — Persist typed evidence, mistake history, and resumable sessions

**Priority:** P0. **Owner:** evidence/storage agent. **Depends on:** FR-01.

**Files:** Modify `frontend/lib/src/core/course/course_progress.dart`; create `course_attempt.dart`, `course_learning_store.dart`, `course_skill_summary.dart` in the course directory; create `frontend/test/unit/course_learning_store_test.dart` and `course_skill_summary_test.dart`.

**Consumes/produces:** Approved attempt/session schemas. Store item ID, selected answer, expected targets, skill, assistance/retry context, origin (practice/game/assessment), content revision, owner, and timestamp; expose session load/save and per-phoneme summaries.

- [ ] Preserve legacy evidence/completions/scores and distinguish historical completion from new proficiency policy.
- [ ] Save the answer, mistake queue, and session state atomically; deduplicate double submissions by stable attempt ID.
- [ ] Retain first and retry outcomes; reject corrupt/unknown payloads safely without erasing recoverable data.
- [ ] Define bounded history retention while retaining summary and unresolved-mistake information; do not persist raw audio as learning history.

**Acceptance:** Guest/A/B histories never mix; concurrent lesson/game writes do not overwrite each other; failed saves are retryable without duplicate evidence; held-out results cannot be reconstructed from retry practice. New local-only events do not poison the legacy cloud outbox before FR-17 supports them.

**Verify:** `flutter test test/unit/course_learning_store_test.dart test/unit/course_skill_summary_test.dart test/unit/course_sync_test.dart test/unit/course_arcade_test.dart`.

### FR-05 — Implement mastery-based lesson sessions and mistake retries

**Priority:** P0. **Owner:** pure-session-engine agent. **Depends on:** FR-01, FR-04; D2.

**Files:** Create `frontend/lib/src/core/course/lesson_session.dart`, `lesson_review_policy.dart`, and `frontend/test/unit/lesson_session_test.dart`.

**Consumes/produces:** Authored sections/exercise pool and saved attempt/session state; deterministic selection, retry scheduling, section/debrief state, completion eligibility, and bounded-sitting outcomes. Inject clock/randomness for tests.

- [ ] Implement configurable `completionThresholdPercent` with default `80`; derive the required correct count by rounding up, rather than hard-coding seven or eight answers. Implement the separately approved delayed mistakes, sitting limit, and resume behavior.
- [ ] Gate teaching explanations by section-end state, not first attempt, error count, or an early-help button. Persist section/debrief state and keep explanation availability distinct from lesson completion eligibility.
- [ ] Produce a correctness result after every scored submission without unlocking teaching explanations; separately represent unavailable/unassessed outcomes so capability failures cannot enter the mistake queue as wrong answers.
- [ ] Track outcomes per item; repeating a correct item cannot replace coverage of an unseen required item.
- [ ] Preserve unresolved mistakes when completing or taking a break; future review uses actual missed items/contrasts rather than restarting an entire unrelated lesson.

**Acceptance:** At the default 80%, seven of ten distinct items cannot complete a lesson, but eight of ten can once all required items have been attempted. Changing the configuration changes eligibility without rewriting the engine; rounding never admits a below-threshold result. Explanations cannot appear before section end, including after wrong answers; ending a section is distinct from passing the lesson. An interrupted sitting resumes the same section/queue and saved policy revision; sparse pools cannot loop forever; retries respect delay where possible; unresolved mistakes remain due after completion; learning completion and save completion remain distinct states.

**Verify:** `flutter test test/unit/lesson_session_test.dart`; include default-80 fixtures (7/10 fails, 8/10 passes, 6/8 fails, 7/8 passes), a configured-75 fixture (6/8 passes), a configured-100 fixture (9/10 fails, 10/10 passes), and invalid-configuration cases from the approved contract. Test explanation absence before section end even after repeated errors, presence at debrief, and restoration of section state. Pin retry/section-boundary fixtures after the remaining D2 policy is approved.

### FR-06 — Build reusable listening-discrimination puzzles

**Priority:** P0. **Owner:** listening-exercise UI agent. **Depends on:** FR-01, FR-03 contracts.

**Files:** Create `frontend/lib/src/features/course/exercises/listening_choice.dart`, `sound_comparison.dart`, and `frontend/test/widget/listening_exercise_test.dart`.

**Consumes/produces:** Typed exercise plus injectable audio; answer/help callbacks with no direct writes to global progress. FR-07 owns session/evidence submission.

- [ ] Present audio-led identification and sound-comparison examples with plausible English-speaker confusions.
- [ ] Avoid revealing the correct answer through a displayed word, IPA transcription, button position, or spelling hint when the skill is listening.
- [ ] Enable submission only after required playback succeeds; permit replay and retry unavailable audio without recording an incorrect answer.
- [ ] Support immediate right/wrong result presentation through the common exercise/session contract, without displaying teaching explanations or full solution hints mid-section.

**Acceptance:** Clear task instructions before discovery; keyboard/assistive controls; double taps submit once; audio failure/background/navigation do not submit or resume stale actions. First `/u/`–`/y/` lesson is testable with fake audio.

**Verify:** `flutter test test/widget/listening_exercise_test.dart`.

### FR-07 — Replace the explanation-first lesson flow with discovery and remediation

**Priority:** P0. **Owner:** lesson-shell agent. **Depends on:** FR-03, FR-04, FR-05, FR-06.

**Files:** Modify `frontend/lib/src/features/course/course_lesson_screen.dart`; create `lesson_section_debrief.dart` beside it and `frontend/test/widget/discovery_lesson_test.dart`; extend `course_flow_test.dart` only after coordinating regression ownership with FR-18.

**Consumes/produces:** Lesson session, exercise renderer callbacks, progress/audio contracts; a resumable lesson screen with explicit completion and review outcomes.

- [ ] Show section puzzles without teaching explanations or early-unlock controls; retain instructions/audio and prevent answer leakage through the old Word reference, accessibility labels, or navigation shortcuts.
- [ ] Show right/wrong immediately after each scored submission. Present targeted explanations and the section's full teaching rule at its end-of-section debrief; bring back actual mistakes using the approved remediation policy. Immediate result feedback must not reveal those explanations mid-section.
- [ ] Commit completion only after eligibility and successful persistence; handle Finish/retry, leave/resume, and account changes.

**Acceptance:** Correctness feedback appears after each scored answer, while teaching explanations are absent throughout active section puzzles and present at the debrief; no first-attempt or early-help bypass exists. Tests assert immediate right/wrong for correct and incorrect submissions, explanation absence before section end, unavailable audio producing neither a wrong result nor a mistake, and navigation/resume. A learner can finish an attempt section without falsely passing the lesson; progress represents distinct examples; failed save cannot claim success/unlock the path; old direct lesson links fail safely or resolve through the approved mapping. Preserve existing microphone cleanup behavior until FR-14/FR-16 replace it.

**Verify:** `flutter test test/widget/discovery_lesson_test.dart test/widget/course_flow_test.dart test/widget/course_recording_lifecycle_test.dart`.

### FR-08 — Add sentence phoneme hunts with red herrings

**Priority:** P1. **Owner:** sentence-content/UI agent. **Depends on:** FR-01, FR-03, FR-06 contracts.

**Files:** Create `frontend/lib/src/core/course/french_sentence_exercises.dart`, `frontend/lib/src/features/course/exercises/sentence_hunt.dart`, `frontend/test/unit/sentence_hunt_test.dart`, and `frontend/test/widget/sentence_hunt_test.dart`.

**Consumes/produces:** Contextually annotated sentence tokens/audio references; a renderer returning selected token IDs and exact-set correctness through the common exercise callback.

- [ ] Ask learners to find every word containing the target phoneme; author visually plausible non-targets, including reviewed silent-letter/spelling traps.
- [ ] Score the selected set against the authored set; “select everything” fails when distractors exist. Do not award a separate full correct attempt for every tap.
- [ ] Show right/wrong for the submitted selection immediately, without exposing the target-location solution or teaching explanation before the section-end debrief.
- [ ] Supply explanations for missed targets and false positives to the section-end debrief; do not show phoneme-location solution highlights or teaching explanations during the active section.

**Acceptance:** Punctuation/repeated words have stable distinct token IDs; multiple targets and false positives evaluate correctly; variants/liaison are annotated or intentionally excluded; sentence-level audio is not assembled from mismatched citation pronunciations.

**Verify:** `flutter test test/unit/sentence_hunt_test.dart test/widget/sentence_hunt_test.dart`; French reviewer signs off answer keys and red herrings.

### FR-09 — Add later-stage sound–spelling puzzles

**Priority:** P1. **Owner:** spelling-content/UI agent. **Depends on:** FR-01, FR-03, FR-06 contracts.

**Files:** Create `frontend/lib/src/core/course/french_spelling_exercises.dart`, `frontend/lib/src/features/course/exercises/spelling_choice.dart`, and `frontend/test/widget/spelling_exercise_test.dart`.

**Consumes/produces:** Reviewed sound–spelling examples and distractors; the common exercise callback labeled `spelling`, even when the prompt includes audio.

- [ ] Start with `/u/`–`/y/` spelling contrasts, then other authored sound/spelling patterns.
- [ ] Contrast minimal pairs, plausible misspellings, and different spellings for a sound without asserting a universal letter-to-sound rule.
- [ ] Show right/wrong after each submitted spelling answer while keeping pattern explanations at section end.
- [ ] Supply the relevant spelling-pattern explanation to the section-end debrief, not per-attempt help; let FR-05 schedule mistakes rather than implementing a second retry engine.

**Acceptance:** Early listening does not require reading the answer word; later spelling results stay separate from listening/speaking; option keys are unambiguous for the recorded pronunciation and task wording.

**Verify:** `flutter test test/widget/spelling_exercise_test.dart`; content review of distractors and accepted spellings.

### FR-10 — Add English-speaker articulation coaching

**Priority:** P1. **Owner:** articulation-content/UI agent + reviewer. **Depends on:** FR-01, FR-03.

**Files:** Create `frontend/lib/src/core/course/french_articulation.dart`, `frontend/lib/src/features/course/articulation_sheet.dart`, `frontend/test/unit/articulation_content_test.dart`, and `frontend/test/widget/articulation_sheet_test.dart`.

**Consumes/produces:** Phoneme/help IDs and reference audio; reviewed mouth-position lessons available from explanations and optional path branches.

- [ ] Describe lips, tongue placement, airflow/nasality, voicing, and a comfortable practice sequence where relevant.
- [ ] Address English vowel glides, `/u/`–`/y/` confusion, added `/n/` after nasal vowels, and English-style R, while recognizing English dialect differences and French variants.
- [ ] Provide text alternatives for any diagrams; reference playback and self-comparison must not promise that following a diagram guarantees correctness.

**Acceptance:** Each pilot sound has reviewed coaching; English analogies are labeled approximations; no forced harsh throat production or unsupported diagnosis. Coaching can follow an early section's debrief rather than waiting for the final exam; it must not become a hidden explanation bypass during that active course section.

**Verify:** `flutter test test/unit/articulation_content_test.dart test/widget/articulation_sheet_test.dart`; linguistic review required.

### FR-11 — Build the main-path overworld and optional side quests

**Priority:** P1. **Owner:** path/navigation UI agent. **Depends on:** FR-01, FR-04, FR-05 contracts; FR-07 for end-to-end validation.

**Files:** Create `frontend/lib/src/features/home/course_overworld.dart`, `course_path_node.dart`, `frontend/lib/src/core/course/course_path_state.dart`, `frontend/test/unit/course_path_state_test.dart`, and `frontend/test/widget/course_overworld_test.dart`. FR-18 owns edits to `home_screen.dart` and `app_router.dart`.

**Consumes/produces:** Authored prerequisite graph + typed progress; map widget and destination callbacks without competing router edits.

- [ ] Render one main path with completed/current/locked nodes, stage labels, checkpoint exams, and optional review/game/coaching branches.
- [ ] Place Continue, Review, Games, and phoneme scores within easy reach; do not require scrolling through all lessons to a bottom tools dropdown.
- [ ] Gate future main nodes by approved prerequisites; allow revisiting completed nodes and opening side quests without advancing unrelated lessons.

**Acceptance:** Completion/save failure never advances the path; no lesson path dead ends; current node remains reachable on 360px phones and large text; keyboard/screen-reader linear navigation conveys order without relying on color. Deep-link gating is enforced in FR-18, not just drawn as a lock.

**Verify:** `flutter test test/unit/course_path_state_test.dart test/widget/course_overworld_test.dart`; phone-layout and assistive navigation checks.

### FR-12 — Add baseline assessment and held-out checkpoint exams

**Priority:** P1. **Owner:** assessment agent. **Depends on:** FR-01, FR-03, FR-04, FR-06, FR-08, FR-09. D1 section format is resolved; scored speaking still depends on FR-15/FR-16.

**Files:** Create `frontend/lib/src/core/course/course_assessment.dart`, `french_assessment_content.dart`, `frontend/lib/src/features/course/course_assessment_screen.dart`, `frontend/test/unit/course_assessment_test.dart`, and `frontend/test/widget/course_assessment_test.dart`.

**Consumes/produces:** Held-out content, skill-specific results, and assessment snapshots; baseline recommendations and later comparable exam results, not an automatic universal proficiency certificate.

- [ ] Implement a listening/identification section and a separate read-aloud speaking section, with independent results. Include balanced independent listening/spelling probes so one paragraph or one sound does not dominate the result; implement scored speaking only through FR-16.
- [ ] Give instructions and replay policy; show right/wrong after each scored answer, but defer explanations until the section ends. Score only the first submitted answer per held-out item; feedback, practice retries, and corrected resubmissions cannot add assessment credit. Account for possible learning from immediate feedback when reviewing exam comparability; do not claim the exam is a calibrated mastery measure.
- [ ] Record per-sound coverage, numerator/denominator, skill, assessment/content version, and assistance; show untested sounds as unassessed.
- [ ] Permit skip/interruption/resume; do not score missing audio or abandoned questions as phoneme ignorance.

**Acceptance:** Listening/identification and read-aloud speaking are distinct sections with separate results; initial assessment and later exam are distinct snapshots; later exam uses different reviewed examples; zero-evidence divisions are safe; weak sounds produce review recommendations. Read-aloud production remains ungraded until FR-15/FR-16 gates pass.

**Verify:** `flutter test test/unit/course_assessment_test.dart test/widget/course_assessment_test.dart`; content review for leakage, coverage, and exam equivalence.

### FR-13 — Show a full per-phoneme skills dashboard

**Priority:** P1. **Owner:** progress UI agent. **Depends on:** FR-01, FR-04, FR-12 result contract.

**Files:** Modify `frontend/lib/src/features/course/course_progress_screen.dart`; create `phoneme_skill_card.dart` beside it and `frontend/test/widget/phoneme_dashboard_test.dart`.

**Consumes/produces:** FR-04 summary and FR-12 snapshots; accessible overview of every pilot phoneme, including unassessed ones, plus targeted-review callbacks.

- [ ] Show listening, spelling, and speaking separately, with sample size, latest assessment, and due mistakes.
- [ ] Label practice accuracy separately from exam results; retain arcade high scores in a clearly recreational section.
- [ ] Link each sound/skill to its actual remediation examples and coaching; unavailable speaking assessment is not a zero score.

**Acceptance:** No-data/partial-data states are honest; legacy evidence is labeled appropriately; practice repeats never masquerade as exam improvement; no overall weighted score is invented without approved policy. Device-local/backup limitations remain visible.

**Verify:** `flutter test test/widget/phoneme_dashboard_test.dart`; fixtures for guest/account changes, unassessed sounds, sparse samples, and mixed historical/new evidence.

### FR-14 — Make speech capture safe on browser and native mobile

**Priority:** P1. **Owner:** recording-platform agent. **Depends on:** FR-00, FR-01 recording contract. D3 is resolved: browser and native mobile are required targets.

**Files:** Modify `frontend/lib/src/core/services/recording_service.dart`; create `speech_capture.dart` and platform adapters beside it, `frontend/test/unit/speech_capture_test.dart`, and `frontend/test/widget/speech_capture_lifecycle_test.dart`. Coordinate existing `course_recording_lifecycle_test.dart` with FR-18.

**Consumes/produces:** User-triggered recording with capability state, playable bytes/URI and format metadata, explicit cancellation, and disposal; no assumption that every platform has a filesystem path.

- [ ] Support browser and native iOS/Android capture through the same approved contract, without calling native documents-directory APIs in browser recording.
- [ ] Explain secure-context/permission requirements; provide a tested HTTPS preview path for remote browser microphones. Never bypass browser security checks.
- [ ] Handle permission denial, silence/short clips, navigation/background/account switching, and delayed start cancellation; delete/release temporary recordings per approved retention policy.

**Acceptance:** Capture and self-comparison work in supported HTTPS browsers and native iOS/Android apps. Microphone cannot reactivate after leaving a screen; denied permissions or unsupported browser/device capabilities offer a non-recording path and no fake grade. Native permission declarations and real-device behavior are verified; a browser-only or native-only implementation does not satisfy this ticket.

**Verify:** `flutter test test/unit/speech_capture_test.dart test/widget/speech_capture_lifecycle_test.dart test/widget/course_recording_lifecycle_test.dart`; real native/HTTPS browser capture and cleanup checks.

### FR-15 — Validate a local French pronunciation evaluator (deferred research gate)

**Priority/type:** P2 / deferred, time-boxed feasibility investigation; not a first-release dependency. **Owner:** speech-evaluation worker + French reviewer. **Depends on:** FR-00, FR-01, approved local-evaluation criteria; FR-14 if collecting recordings. D3/D4 are resolved: candidates run locally and support browser and native mobile capture inputs, with no recording uploads.

**Files:** Create `docs/speech/french-pronunciation-evaluation.md` and an approved evaluation manifest without private recordings/credentials. Any prototype lives outside production and is explicitly disposable.

**Produces:** A go/no-go report and approved scorer contract: correct/needs-practice/uncertain/unavailable, per-target observations, version, reliability limits, and permissible coaching. No production integration in this ticket.

- [ ] Compare local phoneme-aware options on isolated sounds, words, and paragraphs; ordinary ASR transcription is not proof of phoneme correctness. Do not investigate paid cloud speech services or send evaluation clips externally in this scope.
- [ ] Evaluate recordings from both browser and native mobile pipelines, including format/sample-rate differences; approval on one platform does not establish validity on the other.
- [ ] Obtain consented, reviewer-labeled native/learner recordings, including English-specific confusions, acceptable French variation, noise/silence, and different devices/speakers.
- [ ] Pre-register acceptable false-accept/false-reject and abstention criteria, evaluate held-out speakers, and report confusion matrices, latency, model/download size, memory/device support, local retention, and differences across test conditions.
- [ ] Reject the existing byte-hash evaluator as evidence; do not replace real evaluation with a new deterministic heuristic or confidence label.

**Acceptance:** User/reviewer approves measured performance and limitations before graded speaking can ship. If no candidate meets agreed criteria, keep self-comparison/coaching and mark scored speaking blocked; the rest of the course still ships.

**Verify:** Reproducible local evaluation command/results and reviewer labels, not merely mocked tests. Verify no recording network requests and document retention/deletion plus browser/native model limitations. No remote-provider or credential work is included.

### FR-16 — Integrate pronunciation practice and validated feedback

**Priority:** P2 / validation-gated. **Owner:** pronunciation-feature agent. **Depends on:** FR-03, FR-04, FR-10, FR-14, successful FR-15 and approved speaking spec.

**Files:** Create `frontend/lib/src/core/course/course_pronunciation.dart`, `frontend/lib/src/features/course/exercises/pronunciation_practice.dart`, `frontend/test/unit/course_pronunciation_test.dart`, and `frontend/test/widget/pronunciation_practice_test.dart`. Use the approved local evaluator; no remote proxy, cloud API, or speech-service credentials.

**Consumes/produces:** SpeechCapture and validated evaluator contracts; explicit speaking evidence and target-specific coaching, separate from listening/spelling.

- [ ] Let learners hear a reference, record, self-compare, and request evaluation; connect validated common-confusion observations to reviewed articulation explanations in the section-end debrief, not during active course-section puzzles.
- [ ] Treat silence/noise/uncertainty/timeout/unavailability as retryable or unassessed states, not a certain incorrect phoneme; do not fall back to a cloud evaluator.
- [ ] Explain that recordings/evaluation remain local and describe retention; provide deletion/cancellation behavior and safe stale-result handling. Do not include recording bytes/URIs in backup events or telemetry.

**Acceptance:** The approved assessment pipeline runs locally and supports both browser and native mobile inputs without uploading recordings. Only validated evaluator outputs create scored speaking evidence; evaluator failure never falls back to pseudo-grades or cloud services. Paragraph scoring distinguishes coverage and uncertainty, not a single transcription match. Feedback never guesses a mouth adjustment from an uninformative numeric score.

**Verify:** `flutter test test/unit/course_pronunciation_test.dart test/widget/pronunciation_practice_test.dart`; local-retention/deletion, no-upload, timeout, late-result, and account-switch fixtures; FR-15 held-out evaluation and device checks rerun against the integrated pipeline.

### FR-17 — Extend backend backup contracts without breaking existing events

**Priority:** P1. **Owner:** backend/sync agent. **Depends on:** FR-01, FR-04, FR-12 contracts; FR-16 contract for speaking backup (which may be deferred).

**Files:** Create `backend/supabase/migrations/202610100001_course_learning_evidence.sql` and `backend/supabase/tests/course_learning_evidence.sql`; modify `frontend/lib/src/core/course/course_learning_store.dart` only after FR-04 handoff and `frontend/test/unit/course_sync_test.dart`. Do not edit the historical migration.

**Consumes/produces:** Approved lesson IDs and versioned events; additive registrations, supported new evidence/assessment storage, and owner-scoped idempotent backup.

- [ ] Register new curriculum lesson IDs before their completion events are uploaded.
- [ ] Add explicit validation for new skill/origin/version fields and assessment snapshots; retain old answer/lesson/score compatibility.
- [ ] Keep incompatible/new events out of legacy RPC batches until supported; failure/retry must not block existing event delivery permanently.
- [ ] Preserve server-derived ownership, row-level isolation, duplicate handling, and atomic aggregates; never include raw speech audio, recording URIs, or microphone captures in cloud events/storage. Local-only speech evaluation does not disable the existing optional progress-only backup.

**Acceptance:** Replayed events do not inflate evidence; account changes do not upload someone else's history; guest history remains local; old clients and legacy event batches still work. Cloud download/merge remains outside scope.

**Verify:** `flutter test test/unit/course_sync_test.dart`; run both `backend/supabase/tests/course_events.sql` and `course_learning_evidence.sql` against an isolated Supabase-compatible database with auth/RLS fixtures. Document the exact database command/setup in the approved execution plan; do not claim a schema-only test proves user isolation.

### FR-18 — Integrate routes, audio in every game, and release verification

**Priority:** P1. **Owner:** integration/release agent. **Depends on:** FR-07–FR-13, FR-17 and FR-02/FR-03; FR-14/FR-16 only for an approved speaking-enabled release.

**Files:** Modify `frontend/lib/src/routing/app_router.dart`, `frontend/lib/src/features/home/home_screen.dart`, `frontend/lib/src/features/onboarding/onboarding_screen.dart`, `frontend/lib/src/features/arcade/arcade_screen.dart`, `sound_word_help.dart`, `frontend/test/widget/course_flow_test.dart`, `home_navigation_test.dart`, `arcade_switch_test.dart`, `sound_word_help_test.dart`, `README.md`, `docs/course-arcade.md`, and `docs/roadmap-status.md`; create `frontend/test/widget/french_learning_path_flow_test.dart` and `arcade_reference_audio_test.dart`.

**Consumes/produces:** Approved feature widgets/destinations and audio/evidence APIs; integrated course with preserved direct links or documented safe redirects. This ticket is the sole owner of shared routing/home integration.

- [ ] Wire the overworld, discovery lessons, review, assessment, coaching, and dashboard; enforce prerequisites on direct URLs as well as on the map.
- [ ] Offer initial assessment after course selection without forcing it; connect exam recommendations and actual mistakes to the path.
- [ ] Add French reference playback to Word Match word help and connect Sound Match to bundled references, without revealing sound groups on neutral tiles or changing game mechanics.
- [ ] Audit every game exposed by the supported course menu for reference coverage; clearly classify any legacy mode outside that menu rather than silently omit it from “all games.”
- [ ] Preserve game timer/help/background behavior; audio requests and automatic cascades do not create listening mastery evidence.
- [ ] Run the complete suite and publish the manual/automated verification matrix; update stale roadmap claims rather than treating old documentation as current implementation.

**Acceptance:** A new guest can follow the complete pilot loop; returning users retain history; scored answers show immediate right/wrong; wrong answers reappear; explanations appear at section-end debriefs, never mid-section; side quests are optional; all supported games have French playback. No-route-dead-end, save-failure, missing-audio, sign-in/out, and corrupt-state flows remain usable. Unsupported scoring is visibly unassessed.

**Verify:** `flutter test`, `flutter analyze`, `flutter build web`, existing and new SQL suites. Test 360×800 and 390×844, large text, keyboard/assistive controls, HTTPS microphone flows when included, and real iOS/Android audio. For LAN debug previews, use `flutter run -d web-server --web-hostname 0.0.0.0 --web-port <free-port> --no-web-experimental-hot-reload`; do not take over another workspace's demo port.

## 4. Dependency waves and conflict control

These are eligible parallel groups, not instructions to launch all workers. Readiness still requires approved contracts and reviewed dependencies.

| Wave | Tickets | Coordination |
|---|---|---|
| 0 | FR-00 | User approves policy/specs/plans. |
| 1 | FR-01 | Freeze model/ID/fixture contracts before consumers. |
| 2 | FR-02, FR-04, FR-14 | Content production, evidence, and platform capture have separate ownership. FR-15 is deferred; when separately approved it waits for capture or approved supplied fixtures, not a core-release dependency. |
| 3 | FR-03, FR-05 | Audio delivery and pure session policy have separate ownership. |
| 4 | FR-06, FR-08, FR-09, FR-10, FR-11 | Exercise widgets, authored content files, coaching, and map; consumers of FR-06 start after its common callback contract is frozen, or use the approved contract fixture. |
| 5 | FR-07, FR-12 | Assemble the lesson loop and independent assessment UI. |
| 6 | FR-13, FR-17, optionally FR-16 | Dashboard, backend, validated speaking. FR-16 may run earlier after its own dependencies pass. |
| 7 | FR-18 | Serial integration and full-system verification. |

- **Small first release:** FR-01–FR-07 vertical slice, integrating only those destinations with a scoped FR-18 pass. Do not wait for a full French course or speech evaluator to validate the learning loop.
- **Full non-speaking release:** Through FR-13/FR-17/FR-18 with reviewed content/audio; speaking shown as available self-comparison or unassessed, never graded by a placeholder.
- **Locally graded speaking release:** Only after FR-14–FR-16 pass platform, privacy, and linguistic validation. Until then, ship local recording/self-comparison/coaching with speaking marked unassessed; generated-audio tooling remains deferred.
- Shared files (`french_course.dart`, `course_audio.dart`, `course_progress.dart`, `pubspec.yaml`, home/router, common tests) have named owners. Workers request changes through that owner; no parallel opportunistic rewrites.
- Assign one ticket per worker/worktree, branch from reviewed dependency commits, use fixtures at frozen boundaries, and integrate serially. Do not make one worker's uncommitted files another's dependency.
- The coordinator updates this file's ticket status and links, not multiple workers concurrently. Each implementation receives its ticket, approved spec, contract revision, allowed files, exact verification commands, and explicit out-of-scope list.

## 5. Requirement coverage and review gate

| User request | Tickets |
|---|---|
| Overworld, one path, side quests, puzzle then explanation | FR-01, FR-07, FR-11, FR-18 |
| Differentiate sounds first, spelling later | FR-01, FR-06, FR-09 |
| Sentence phoneme locations and red herrings | FR-01, FR-08 |
| Say sounds correctly; English-speaker pitfalls | FR-10, FR-14, FR-15, FR-16 |
| Multiple examples, mostly correct, bring back mistakes | FR-04, FR-05, FR-07 |
| Discover first; explanation at section end | FR-01, FR-05, FR-07, FR-08, FR-09 |
| French sounds for all games | FR-02, FR-03, FR-18 |
| Mouth-position instruction | FR-10 |
| Initial paragraph assessment and later exam | FR-12, validated spoken section in FR-16 |
| Scores for each phoneme | FR-04, FR-12, FR-13 |

### Review before dispatch

- [x] User confirms D1: different listening/identification and read-aloud speaking sections.
- [x] User confirms completion threshold: start at 80% and make it configurable.
- [x] User confirms explanations at section end, rejecting first-attempt and immediate-help unlocks.
- [x] User confirms right/wrong feedback after each submitted, objectively scored answer.
- [x] User confirms recording/pronunciation platforms: both browser and native mobile.
- [x] User confirms local-only speech evaluation for now and defers generated-audio tooling to keep scope simple.
- [ ] User confirms the rest of the intended experience and proposed policies.
- [ ] FR-00 resolves remaining policy/platform/content questions and links approved subproject specs/plans.
- [ ] Coordinator marks only dependency-complete, contract-stable tickets ready.
- [ ] No agent claims implemented/verified functionality from the existence of this document.

**Remaining review:** Section/item counts, retry spacing, sitting limits, content/audio review resources, and local-evaluator feasibility remain provisional. Resolve them in FR-00 and the individual subproject specs before dispatch; the confirmed decisions above are not approval of those remaining defaults.
