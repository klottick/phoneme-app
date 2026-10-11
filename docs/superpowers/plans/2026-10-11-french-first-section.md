# First French Discovery Section Implementation Plan

> **For agentic workers:** Use `subagent-driven-development` for the coordinator workflow. Workers do not delegate. The user selected local `ollama/qwen3.8:27b` workers; the controller reviews and merges PRs. Execute small tasks sequentially from merged dependencies.

**Goal:** Deliver a puzzle-first `/u/`–`/y/` section with immediate correctness, section-end explanations, configurable 80% completion, persisted mistakes and retry-safe progress.

**Architecture:** Pure policy/content/session types; a typed facade over the existing serialized progress store; a stateless view and lifecycle-aware screen; selective existing-route integration.

**Tech stack:** Existing Flutter/Dart, Riverpod, preferences, CourseAudio and Supabase event schema. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-11-french-first-section-design.md`.

## Global constraints

- Immediate right/wrong, teaching explanations only at section end; default 80%, configurable.
- Ten authored existing words and the existing `en-fr-u-y` lesson ID; no other course/game behavior changes.
- Preserve all historical progress, account isolation, outbox compatibility, and native microphone lifecycle tests.
- No cloud speech evaluation, recording uploads, generated audio, microphone work, or fabricated pronunciation grades.
- Existing TTS is labeled practice audio, not a reviewed reference/placement exam.
- Worker model: `ollama/qwen3.8:27b`; no nested agents, no merging, no force pushes.
- Each code task creates a PR against `main`, based on the latest merged dependency. Controller reviews and verifies before merging.

## Review focus

- Rounding/duplicate successes cannot allow below-threshold completion: Tasks 1–2.
- Corrupt or mismatched snapshots cannot unlock completion or erase old history: Tasks 2–3 and 5.
- A failed save/retry must not duplicate evidence or advance: Tasks 3 and 5.
- Delayed playback/load/save after leave/background/account change must not affect replacement state: Task 5.
- Listening word/IPA/explanation leakage, inaccessible controls, and small-phone overflow: Tasks 4–5.

## Coordinator checklist

- [ ] Commit/PR the spec, plan, backlog and ledger; inspect scope and merge docs PR.
- [ ] Run baseline on the remote base; record counts and analyzer evidence.
- [ ] Create one Paseo worktree under `phoneme-app` per implementation ticket.
- [ ] Dispatch Qwen with only its task brief, binding spec, allowed files and report path.
- [ ] Review the PR; route fixes back to its worker; verify independently before merge.
- [ ] Record branch/agent/PR/review/test/merge state after every transition.
- [ ] Final integrated tests/analyzer/web build and documentation/state PR.

## Task 1: Configurable completion policy

**Files:** Create `frontend/lib/src/core/course/lesson_policy.dart` and `frontend/test/unit/lesson_policy_test.dart` only.

**Interfaces:** Produce exactly the `LessonPolicy` contract in the spec; no Flutter widgets/storage/network imports.

- [ ] Add tests: default 80; required counts 8/10 and 7/8; configured 75 gives 6/8; 100 gives 10/10. Below-boundary values fail; exact boundaries pass.
- [ ] Add invalid tests: percentages 0/101, zero/negative totals, negative/too-many correct answers; strict JSON rejects missing/string/fractional/out-of-range values; round trip preserves configured percentage.
- [ ] Run `flutter test test/unit/lesson_policy_test.dart`; record relevant missing-symbol failure before code.
- [ ] Implement validated policy and integer ceiling without hard-coded item counts.
- [ ] Run the same tests and `flutter analyze`; expect passing tests and no diagnostics.
- [ ] Commit scoped files; push feature branch and create PR with test evidence; do not merge.

## Task 2: Authored pilot and pure section state machine

**Depends:** Task 1 merged.

**Files:** Create `frontend/lib/src/core/course/lesson_section.dart`, `lesson_section_session.dart`, `frontend/test/unit/lesson_section_content_test.dart`, and `lesson_section_session_test.dart` only.

**Interfaces:** Consume `LessonPolicy`; produce content/session APIs exactly as defined in the spec. `sectionForLesson` returns null for every non-pilot lesson.

- [ ] Write content tests for the ten specified words/IDs/expected sounds, existing curated membership, original explanation, and non-pilot null mapping.
- [ ] Write session tests: invalid IDs/configuration; submit twice/advance unsubmitted/review before debrief reject; first-pass completion cannot occur before debrief; explanations can appear at debrief even with 0/10; 7/10 fails and 8/10 passes.
- [ ] Test review queue includes only unresolved items, latest success updates coverage without erasing attemptCount, correct-item repetition cannot inflate coverage, all-correct review rejects, and each round terminates.
- [ ] Test exact JSON round trips in unanswered/answered/debrief/review states; retain configured threshold. Corrupt type/version/revision/item IDs/queue/position/counts/latest outcomes/phase combinations fail atomically with FormatException.
- [ ] Run `flutter test test/unit/lesson_section_content_test.dart test/unit/lesson_section_session_test.dart`; record relevant failure.
- [ ] Implement the pure validated content/session types; do not create UI/store scaffolding.
- [ ] Rerun focused tests and analyzer; commit, push, create scoped PR.

## Task 3: Atomic session and answer persistence

**Depends:** Task 2 merged.

**Files:** Create `frontend/lib/src/core/course/lesson_section_store.dart` and `frontend/test/unit/lesson_section_store_test.dart`; modify `frontend/lib/src/core/course/course_progress.dart` only.

**Interfaces:** Implement the four `LessonSectionStore` methods and account-aware provider exactly as in the spec, preserving existing public progress APIs and serialized writer.

- [ ] Test initial save/load, new-key preservation of lessons/evidence/scores/unknown fields, and exact snapshots through advance/review.
- [ ] Test two retries of one submitted checkpoint record once; older duplicates cannot revert a newer checkpoint; gaps, new-session answer injection, wrong target/correctness and ineligible completion do not mutate data.
- [ ] Test failed preferences write then retry, concurrent arcade/section writes, completion only once, and unresolved word IDs retained despite shared phoneme aggregate successes. Test guest/account scopes with existing auth test patterns where possible; no new live credentials.
- [ ] Run `flutter test test/unit/lesson_section_store_test.dart`; record failure, implement minimally.
- [ ] Rerun focused tests plus `test/unit/course_arcade_test.dart`, `test/unit/course_sync_test.dart` and analyzer; no schema/dependency changes.
- [ ] Commit, push, create PR; report the exact event shape compatibility and tests.

## Task 4: Stateless puzzle and section-debrief view

**Depends:** Task 2 merged (execute after Task 3 to keep one worker active).

**Files:** Create `frontend/lib/src/features/course/discovery_section_view.dart` and `frontend/test/widget/discovery_section_view_test.dart` only.

**Interfaces:** Consume content/session; produce the stateless view constructor/callback contract in the spec. No provider/audio/network/storage initialization in this widget.

- [ ] Test active puzzles contain instructions/IPA choice labels but not word text, word IPA, meaning, full explanation, reference list, or early-help unlock.
- [ ] Test listen/answer callbacks, disabled choices before hearing/while busy/after one submission, immediate Correct/Not yet, and Next/last-item button labels.
- [ ] Test debrief explanation, actual count/threshold, Finish eligibility, Review mistakes even with a passing score, and Retry saving with disabled advancement.
- [ ] Test 360×800 and 390×844, large text, scrolling to all controls and no layout exceptions; keyboard/assistive labels must not leak answers.
- [ ] Run `flutter test test/widget/discovery_section_view_test.dart`; record failure, implement, rerun and analyze.
- [ ] Commit, push, create scoped PR.

## Task 5: Lifecycle-aware screen and selective routing

**Depends:** Tasks 3–4 merged.

**Files:** Create `frontend/lib/src/features/course/discovery_lesson_screen.dart`, `frontend/test/widget/discovery_lesson_test.dart`; modify `frontend/lib/src/routing/app_router.dart`, `frontend/test/widget/course_flow_test.dart` only if required by selective routing. Do not alter legacy lesson/recording/game implementations or unrelated tests.

**Interfaces:** Consume policy/session/store/view and existing `CourseAudio`; produce `DiscoveryLessonScreen` and pilot-only `/course-lesson/en-fr-u-y` routing preserving review query.

- [ ] With fake audio/store, test full ten-item first pass, feedback after each answer, no early explanation, debrief at both passing/failing scores, mistake-only retry, successful completion and review-only behavior.
- [ ] Test resumable answered/first-pass/debrief/review states, corrupt snapshot fresh fallback with notice, load failure/retry, and configured-policy restore.
- [ ] Test record/advance/complete save failures and retries: no duplicate answer, no new item/completion/pop before success. Delayed store/audio completions after dispose/account provider replacement/background cannot mutate state or enable unanswered audio.
- [ ] Test audio failure/unavailable voice creates no answer; provider changes load the new owner's state, never copy the prior owner's checkpoint. Test actual pilot route, existing non-pilot lesson and query behavior.
- [ ] Run `flutter test test/widget/discovery_lesson_test.dart`; record failure, implement scoped screen/router.
- [ ] Run focused tests, `test/widget/course_flow_test.dart`, `test/widget/course_recording_lifecycle_test.dart`, full `flutter test`, `flutter analyze`, and `flutter build web`; report outputs and manual limitations.
- [ ] Commit, push, create PR. Controller reviews behavior and integration before merging.

## Final coordinator verification and state publication

- [ ] Read each complete task diff against the spec; no unresolved important findings.
- [ ] Verify merged `origin/main` in an isolated checkout: full tests, analyzer and JavaScript web build.
- [ ] Publish the ledger's reviewed/merged PRs, exact evidence and remaining work in a final docs PR.
- [ ] Retain worker worktrees/reports until outcome is recorded; never delete user work.
- [ ] Broader FR-02 audio-recording/FR-08+ path/sentence/spelling/assessment work remains queued; local scoring remains deferred.
