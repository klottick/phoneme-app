# FR-05 Finite Review Rounds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Verify the existing discovery session against the approved finite-round contract and close demonstrated behavior or regression-coverage gaps without building another scheduler.

**Architecture:** Retain `LessonSectionSession`, `LessonPolicy`, typed discovery commands/checkpoints and the FR-04 repository. Three sequential scopes establish pure-session boundaries, durable repository behavior and visible screen behavior. Existing passing behavior is reused; production edits require a reproduced defect.

**Tech Stack:** Existing Dart/Flutter tests, Riverpod provider overrides, local learning repository and deterministic persistence/audio fakes; no dependencies added.

**Spec:** [Approved FR-05 design](../specs/2026-10-16-fr05-finite-review-design.md), published through [PR38](https://github.com/klottick/phoneme-app/pull/38), merge `ed24386e5dc304018c4b9f1de0938f9855bfde64`.

## Global Constraints

- “Retain `LessonSectionSession`, `LessonPolicy` and FR-04's typed discovery commands/checkpoints as the single implementation path.”
- “The pilot retains its ten items; there is no global hard-coded section size.”
- “`P` defaults to 80 and must be an integer from 1 through 100.” Require `ceil(N * P / 100)` correct latest outcomes, full coverage and debrief.
- “Review-only route Finish must not award completion.”
- “Every round is user-initiated and bounded by its captured queue, ending at debrief.” No delayed retries or twelve-answer cap; no automatic next round.
- “A retryable persistence failure must preserve the exact immutable pending command, captured owner/store and continuation for Retry”. Typed conflicts/content/owner changes use existing recovery, not blind save retry.
- “Saved policy is authoritative on resume, even if a new default is configured elsewhere.” No policy/schema/namespace changes solely for finite rounds.
- “Playback failure/cancellation is a capability state, not a scored wrong answer.” Failure feedback stays generic; cancellation stays quiet; neither grants fresh hearing.
- “They must not be reclassified as fresh, unassisted or held-out evidence.” Retain after-debrief/repeat attribution and actual audio provenance.
- “No new exercises/content, legacy-lesson conversion, map, progression locks, cross-activity scheduler, calibrated mastery score, assessment, microphone workflow, backend/RPC changes, recording uploads, cloud evaluation, dependencies or generated reference audio.”
- “No broad storage migration, deletion or serialization rewrite.” Preserve old data, Sound Match work, audio/licences, branches/worktrees and process evidence.
- External playback, French linguistic/audio/licensing, live Supabase, privacy, FR-15 and release gates remain open. No sandbox bypass; pending recordings remain pending; JS build is not Wasm/playback certification.
- User-preserved execution method: sequential `openai/gpt-6-luna` implementation workers, no nested agents or worker merges; independent review and controller verification before each scoped PR merge. Do not revert to the superseded Qwen default.
- This plan requires user review before execution. Spec approval authorized planning, not product implementation.

## Review Focus

1. All-wrong sparse pools can grow a retry queue indefinitely: every explicit round must end, including after total submissions exceed twelve (Task1 test `all_wrong_rounds_remain_finite_beyond_twelve_submissions`).
2. Pass/Finish and later retries can lose unresolved mistakes or relabel assisted answers: verify actual durable bytes and reloaded repeat evidence, not just a pure transition (Task2 first two scenarios).
3. A failed non-answer checkpoint can replay the answer or publish a phase early: pin frozen command identity, unchanged evidence and no pre-ACK advance/debrief (Task2 parameterized checkpoints; Task3 held final advance).
4. A remount can reconstruct nonexistent pending intent or replace saved policy with current defaults: retain committed feedback/queue/threshold without implicit submission (Task3 remount and saved100/current80 scenarios).
5. A late review-start or cancelled playback can activate the wrong round/owner: require explicit foreground playback, unscored cancellation, and generation fencing even on A→B→A (Task3 capability and held-review owner scenarios).

---

## 1. Baseline audit and file ownership

At planning baseline `ed24386`, no FR-05 defect has been reproduced. The following nine existing suites ran together: **224 passed**, exit0. Command: from `frontend/`, `/home/klottick/develop/flutter/bin/flutter test --no-pub test/unit/lesson_policy_test.dart test/unit/lesson_section_session_test.dart test/unit/course_learning_lesson_transition_test.dart test/unit/course_learning_store_test.dart test/widget/discovery_lesson_test.dart test/widget/discovery_section_view_test.dart test/widget/course_learning_resume_test.dart test/widget/discovery_lesson_review_repeat_test.dart test/widget/discovery_lesson_recovery_test.dart --reporter expanded`. Local log: `/tmp/opencode/fr05-plan-existing-regressions.log`.

This verifies the cited tests ran, not all FR-05 acceptance. The additions below target missing boundary combinations; do not duplicate an equivalent existing test if further inspection locates its exact assertions. Record that reuse explicitly in task evidence. A no-op scope needs evidence, not an empty implementation PR.

| Spec requirement | Existing source and named regression | Remaining evidence / owner |
| --- | --- | --- |
| Threshold, invalid configuration, coverage/debrief | `lesson_policy.dart`; `lesson_policy_test.dart`: `requires 7 of 8 at the default 80 percent (ceiling of 6.4)`; `lesson_section_session_test.dart`: `completion cannot be reached before the debrief`, `7/10 fails and 8/10 passes under the default policy` | Full-session 8-item/75/100 boundary matrix, not policy arithmetic alone: Task1 |
| First-pass correctness and explanation timing | `discovery_lesson_screen.dart`, `discovery_section_view.dart`; `discovery_lesson_test.dart`: `full ten-item pass shows immediate feedback, no early explanation, debrief at 10/10, and completes once`; view suite's semantics/no-leak assertions | Preserve existing assertions; pin review exercises and all-wrong debrief as described in Task3 |
| All-wrong debrief and finite queues | `lesson_section_session.dart`; session tests: `the debrief is reachable even with 0/10, with all items unresolved`, `a wrong retry keeps the item unresolved and the round still ends` | Several all-wrong short rounds crossing twelve submissions: Task1; visible one-item round: Task3 |
| Latest outcome vs historical attempts, exact mistake identity | `course_learning_transition.dart`; transition tests: `same sound different item cannot resolve mistake`, `new run preserves unresolved mistakes` | Real repository/reload after passing/Finish and exact-context resolution: Task2 |
| Saved policy and state restore | Session round-trip/reachability tests; widget test `saved policy is authoritative on resume` | Partial multi-round saved-policy boundary: Task1; actual repository reload: Task2; failed-Advance remount: Task3 |
| Failure vs cancellation | Screen `_listen`; widget tests `audio failure creates no answer and keeps listening retryable`, `cancelled playback is silent and keeps listening retryable` | Repeat while in review; assert unchanged history/mistakes as well as controls: Task3 |
| Save completion separate from eligibility | Screen pending commands; widget tests `advance save failure keeps the saved item; retry advances`, `completion failure leaves no completion; retry completes exactly once`, `review start failure stays on the debrief; retry resumes` | Real repository non-answer checkpoint Retry: Task2; final-review Advance identity: Task3 |
| Completion policy identity / review-only Finish | Transition tests `completion idempotency includes the saved threshold policy`, `review only finish never completes lesson`; widget repeat/review-only tests | Identity across real repository reload and saved thresholds: Task2; existing review-only widgets rerun in Task3 |
| Honest repeated evidence | Transition test `closing help and pruning detail cannot make repeated item first` | Actual repository codec/reload must retain `repeatInRun`, occurrence2 and `afterDebrief`: Task2 |
| Owner, corrupt/content state and old work preservation | Store/provider/codec suites; widget tests `A to B to A never publishes a delayed old-generation answer`, `same-session competing advance reload preserves typed state`; discovery recovery suite | Preserve existing gates; held review-start owner cycle: Task3; scope/hash checks: controller final gate |

New files and responsibilities:

- `frontend/test/unit/lesson_finite_round_contract_test.dart`: pure completion/round/restore boundaries (Task1).
- `frontend/test/unit/course_learning_discovery_contract_test.dart`: real repository persistence, mistake/evidence/completion boundaries (Task2).
- `frontend/test/widget/discovery_finite_round_contract_test.dart`: visible finite-round, pending-Advance, capability and owner boundaries (Task3).
- Existing source is conditionally owned below only for a test-proven scoped defect; no blanket refactor permission. Existing tests remain intact.
- `docs/superpowers/status/2026-10-16-fr05-finite-review.md`: final controller-authored published outcome, through a separate reviewed docs PR after implementation gates.

Use existing support files read-only: `frontend/test/support/course_learning_persistence_fakes.dart`, `course_learning_widget_store.dart`, `course_learning_fixtures.dart`. The widget fake already has action gates/failures and captured `prepared`/`submitted` commands; no shared-fake redesign is needed. Do not import another test file's `main()` or use `seedSession` as proof of durable history.

## 2. Execution protocol for every implementation task

- [ ] Controller prepares an explicit brief with owned files and the spec/plan. Start each sequential scope on current published `origin/main` in isolation, after the preceding PR merges. Preserve existing worktrees and unrelated files.
- [ ] Worker inspects cited tests and adds only missing behavioral assertions. Run the new test before any source edit. Initial GREEN means coverage-only, not a fake RED or a claimed bug fix. A runtime fix requires a meaningful runnable RED, root-cause evidence and minimal change within that task's ownership; new schema/API/scope decisions return to the controller.
- [ ] Run task-specific verification and self-review the actual diff. Record exact commands, results, initial RED/GREEN status, limitations and scope in `.superpowers/sdd/2026-10-16-fr05-finite-review/task-N-report.md`.
- [ ] Commit only owned files, push a scoped branch and open its PR against `main`. Do not merge or spawn subagents. Each PR includes scope, verification and still-open external gates.
- [ ] Controller obtains independent actual-PR spec/quality review, dispositions findings, independently runs affected verification, and refreshes exact head/base/checks/feedback before merge. Missing CI is not success. Verify fetched merged tree and record PR URL, reviewed head and merge SHA before the next task.

### Task 1: Pin the pure finite-round contract

**Files:** Create `frontend/test/unit/lesson_finite_round_contract_test.dart`. Conditional source fixes only: `frontend/lib/src/core/course/lesson_policy.dart`, `lesson_section_session.dart`.

**Interfaces:** Consume existing `LessonPolicy({int completionThresholdPercent = 80})`, `requiredCorrect(int) -> int`; `LessonSectionSession({required List<String> itemIds, required String sessionId, int contentRevision = 1, LessonPolicy? policy})`, `submit(bool)`, `advance()`, `reviewMistakes()`, `toJson()`, `fromJson(Map<String,dynamic>, {required List<String> itemIds, required int contentRevision})`. Produce tests only; no new production API or schema. Test-local `_answeredSection({required int items, required int correct, int percent = 80}) -> LessonSectionSession` starts IDs `item-0` onward, submits every item (first `correct` true), and advances all except the last, returning an answered exercise ready for its final advance.

- [ ] **Step 1: Add `session_threshold_matrix_requires_full_coverage_and_debrief`.** Run each `(items, correct, percent, canComplete)` fixture through the actual session, not `isPassing()` alone:

  ```dart
  const cases = [
    (10, 7, 80, false), (10, 8, 80, true),
    (8, 6, 80, false), (8, 7, 80, true), (8, 6, 75, true),
    (10, 9, 100, false), (10, 10, 100, true),
  ];
  for (final (items, correct, percent, passes) in cases) {
    final s = _answeredSection(items: items, correct: correct, percent: percent);
    expect(s.answeredItemCount, items);
    expect(s.canComplete, isFalse);
    s.advance();
    expect(s.phase, LessonSectionPhase.debrief);
    expect(s.canComplete, passes);
  }
  ```

  Existing invalid constructor/serialized-policy and duplicate/early transition tests remain acceptance owners; do not weaken them.
- [ ] **Step 2: Add `all_wrong_rounds_remain_finite_beyond_twelve_submissions`.** Use IDs `['a','b','c']`; first pass plus four explicit all-wrong reviews. For rounds1–5, capture `queue` before submission; submit/advance exactly3 times; assert `phase == debrief`, `attemptCount == 3 * round`, unresolved IDs unchanged, `canComplete == false`. Do not call `reviewMistakes()` until the next explicit iteration. Final count15 proves no twelve-answer cap or implicit queue expansion.
- [ ] **Step 3: Add `partial_later_round_restore_preserves_queue_and_saved_policy`.** Start3 items under75%, all wrong; complete another all-wrong review; start round3, submit its first item true, retain answered-awaiting-advance. Round-trip through session JSON with the same IDs/revision; assert round3/position0/answeredtrue/attemptCount7/queue`['a','b','c']`/threshold75/latest a=true,b=c=false. Advance restored state and finish b/c wrong: debrief at count9, two unresolved. Also preserve the existing single-unresolved and empty-review regressions.
- [ ] **Step 4: Run new tests before source changes.** From `frontend/`: `/home/klottick/develop/flutter/bin/flutter test --no-pub test/unit/lesson_finite_round_contract_test.dart --reporter expanded`. Expected: all pass if existing behavior meets the new assertions; otherwise capture the behavioral failure before any minimal owned-source fix.
- [ ] **Step 5: Verify the pure scope.** Run the same command with `test/unit/lesson_policy_test.dart test/unit/lesson_section_session_test.dart` also included; expect exit0/all pass. Run `flutter analyze --no-pub` with the absolute Flutter path; expect no issues. Apply the per-task publication/review protocol; suggested commit `test: pin finite discovery session boundaries`.

### Task 2: Prove durable review, mistakes and checkpoint Retry

**Files:** Create `frontend/test/unit/course_learning_discovery_contract_test.dart`. Conditional source fixes only: `frontend/lib/src/core/course/course_learning_lesson_transition.dart`, `course_learning_transition.dart`, `course_learning_store.dart`. Any required codec/schema change is a controller decision, not implied ownership.

**Interfaces:** Consume `CourseLearningStore.load() -> Future<CourseLearningState>`, `prepare({required CourseLearningState state, required String activityId, required LearningAction action}) -> LearningCommand`, `submit(LearningCommand) -> Future<LearningCommit>`, `LearningCommit.state/slot/duplicate`. Use activity `lesson:en-fr-u-y`; `StartLearningRun(options: RunOptions(policy: ...))`, `ChooseSound(selectedSound: ..., audioSource: authoredAudioSource(item)!)`, `AdvanceLesson`, `ReviewDiscoveryMistakes`, `FinishLearningActivity({bool recordCompletion = true})`. Produce repository regressions; no API changes for Task3 to consume.

Create a test-local repository factory following `course_learning_store_test.dart:18–49`: actual `CourseLearningRepository`, `LearningTransitionEngine(LearningRegistry.french())`, `FakeLearningPersistence`, fixed clock/seeded random, and one monotonically increasing token generator shared across repository instances in a test. `commit(LearningAction) -> Future<LearningCommit>` always prepares from the latest loaded state and updates local state from the ACK. Fresh repositories reuse the same persistence image, not a manually reconstructed checkpoint. Never use pure `stateAfter()` as persistence proof.

- [ ] **Step 1: Add `passing_finish_keeps_mistakes_and_only_matching_answers_resolve`.** Commit a full pass wrong only at indices1/3 (`tu`/`rue`, both `/y/`), yielding8/10. Capture their mistake keys and original wrong submission IDs. Finish, construct/load a fresh repository, assert one completion/ten attempts/both exact mistakes preserved. Explicitly start a new run; correct `tout` must clear neither; advance and correct `tu` must clear only its key, leaving `rue` and both historical wrong attempts. Do not reopen a finished run via an automatic review command.
- [ ] **Step 2: Add `review_reload_preserves_saved_policy_and_after_debrief_evidence`.** Start100%, score9/10 with only index9 wrong; debrief cannot complete. Commit review start, then load through a new repository. Assert both saved slot options/session policy100, one-item queue`['mur']`, round2 and incomplete9/10. Submit the correct retry with authored audio provenance, advance to debrief, reload again. Assert all11 attempts retained, original wrong ID present, only its exact mistake resolved, retry presentation`repeatInRun`, itemOccurrence2, assistance contains`afterDebrief`, and canComplete true. Inspect typed attempts and first/repeat summary totals, not submission-call count alone.

  ```dart
  // retry is the reloaded mur attempt with itemOccurrence == 2.
  expect(retry.presentation, AttemptPresentation.repeatInRun);
  expect(retry.itemOccurrence, 2);
  expect(retry.assistance, contains(AssistanceFlag.afterDebrief));
  // Sum disjoint summary buckets: firstInRun total/correct == 10/9;
  // repeatInRun total/correct == 1/1. Earlier wrong ID remains in history.
  ```
- [ ] **Step 3: Add parameterized `non_answer_checkpoint_failure_retries_once` for Advance, review start and Finish.** Independently prepare the required committed state for each action (answered current item for Advance;8/10 debrief for review/Finish). Save the platform bytes and history before the checkpoint. Use `holdNextWrite()`, attach the expected `LearningSaveException` handler, submit the prepared command and await `writeEntered`. The durable platform image must remain unchanged while held. Release with `persist:false`, await failure, then verify rollback bytes and reloaded state exactly match the prior committed image. Do not await a coordinated repository load while its write is held. Retry the same command, then resubmit it once more: ACK then `duplicate == true`, one cursor increment, no new attempt or altered history, correct resulting phase/completion; verify using a fresh repository.
- [ ] **Step 4: Add `completion_identity_survives_reload_and_threshold_changes`.** Through real commits/fresh repository loads, finish all-correct runs under80, then100, then100 again. Assert completion thresholds`[80,100]`, same lesson/content/kind/revision, original record retained, no third completion. Assert saved run policy matches its completion threshold and earlier history remains intact.
- [ ] **Step 5: Run new tests before conditional source edits.** `/home/klottick/develop/flutter/bin/flutter test --no-pub test/unit/course_learning_discovery_contract_test.dart --reporter expanded`. Capture initial GREEN or meaningful RED; do not change a schema or unrelated caller to make a faulty fixture pass.
- [ ] **Step 6: Verify repository integration.** Run that command also including `test/unit/course_learning_lesson_transition_test.dart test/unit/course_learning_store_test.dart test/unit/course_learning_codec_test.dart test/unit/course_learning_commit_isolation_test.dart test/unit/course_learning_retention_test.dart`; expect all pass. Run full analysis; publish/review/merge per protocol. Suggested commit `test: verify durable finite review semantics`.

### Task 3: Pin visible finite rounds and late continuation boundaries

**Files:** Create `frontend/test/widget/discovery_finite_round_contract_test.dart`. Conditional source fixes only: `frontend/lib/src/features/course/discovery_lesson_screen.dart`, `discovery_section_view.dart`. Keep shared support fakes read-only and do not restructure the large existing discovery test suite.

**Interfaces:** Consume `DiscoveryLessonScreen({required String lessonId, bool review = false, LessonPolicy? policy})`, `courseLearningStoreProvider`, `courseAudioProvider`, and existing widget fake `committedState`, `discoverySession`, `prepared`, `submitted`, `actionGates`, `failingActions`. `CourseAudio` implements `Future<void> speak(String)`/`stop()` and throws `CourseAudioCancelledException` for cancellation. Produce visible behavior regressions only; use existing exact strings (`Correct`, `Not yet`, `Review mistakes`, `See section explanation`, `Retry saving`) without new user-facing copy.

Use a test-local `_seedDebrief(CourseLearningWidgetStore store, {Set<int> wrongIndexes = const {9}, int percent = 80}) -> Future<void>` that commits start/answers/advances using the real transition-backed fake, rather than `seedSession`. Keep audio failure/cancellation controls local to the new file. Mount provider overrides with a stable container for owner changes; dispose it, router if used, and the screen after each test. Use finite pumps while a gate is held, not `pumpAndSettle` on a live spinner.

- [ ] **Step 1: Add `failed_one_item_review_returns_to_debrief_without_auto_restart`.** Seed100% with only `mur` wrong; mount with current screen policy80. Assert saved required count remains10, no completion eligibility at9/10. Explicitly start review; explanation/word/IPA absent during puzzle and choices disabled before listening. Listen, choose wrong, assert immediate `Not yet`; advance once to debrief. Assert attempts11, one unresolved item, round2, saved100%, no completion. Extra pumps must not start round3; only another explicit `Review mistakes` can do so. Preserve existing correct-first-pass and no-mistake view tests.
- [ ] **Step 2: Add `held_review_final_advance_retries_frozen_command`.** Seed a one-item review and commit its answer via UI. Gate Advance and make it fail after release; while held and after failure assert committed answered position, feedback, unchanged history count and no debrief/explanation. Pending controls must not prepare a second answer/advance. Capture the submitted command and prepare count; clear failure, tap Retry; assert `identical(originalAdvance, store.submitted.last)`, no new prepare, no reanswer, then exactly one debrief transition after ACK. Check the command is Advance, not merely two equal submission counts.

  ```dart
  expect(originalAdvance.action, isA<AdvanceLesson>());
  // After Retry settles:
  expect(store.submitted.last, same(originalAdvance));
  expect(store.prepareCalls, preparesBeforeRetry);
  expect(store.discoverySession!.attemptCount, attemptsBeforeAdvance);
  expect(store.discoverySession!.phase, LessonSectionPhase.debrief);
  ```
- [ ] **Step 3: Add `remount_after_failed_advance_restores_answer_not_pending_intent`.** Fail Advance after a committed review answer, dispose the screen, and create a fresh widget store from its committed state. Remount: saved review queue/position and feedback remain, no implicit ChooseSound/Advance submission or reconstructed pending Retry. Explicit next advances to debrief without increasing attempts/history. This simulates restart from a committed checkpoint; separately retain existing same-process suspend/resume recovery tests.
- [ ] **Step 4: Add `review_audio_unavailable_is_unscored` for actual failure and cancellation.** Start a one-item review; capture history/mistake maps/attempt count. Listening failure shows generic audio guidance; cancellation shows no failure message. Both keep choices disabled, explanation absent and all captured learning evidence unchanged; no ChooseSound submitted. After successful fresh playback, permit one correct answer and verify its repeat/after-debrief context. Do not reveal the hidden word through an exception string or semantics.
- [ ] **Step 5: Add `held_review_start_cannot_publish_after_owner_cycle`.** A/B have distinct account scopes. Seed A's debrief, gate A's review start, switch A→B→A through the provider before releasing it. The old command may settle A's own store, but its old-generation callback cannot replace the reloaded UI/debrief, enable hearing, navigate, or write B's state. Assert B history/mistakes/completion unchanged and no exception. Also parameterize the terminal case as disposal instead of the owner cycle; it may commit once to its captured store but cannot touch the disposed screen. Do not confuse store settlement with permitted UI publication.
- [ ] **Step 6: Add `all_wrong_first_pass_debrief_is_available_but_not_passing`.** Start a fresh run and exercise all ten wrong answers through UI. Each shows `Not yet` without explanation before final advance; then debrief/explanation is visible, Finish disabled and ten actual mistakes retained. Mount with a two-route home/lesson navigation stack, tap the normal back control and assert home is visible while the committed debrief/mistakes persist and no Review command was submitted. Use semantics assertions for explanation/hidden words during puzzles, not just paint text.
- [ ] **Step 7: Run new tests before conditional source edits.** `/home/klottick/develop/flutter/bin/flutter test --no-pub test/widget/discovery_finite_round_contract_test.dart --reporter expanded`. Record initial coverage-only GREEN or behavioral RED. Minimal source fixes stay within this task's screen/view ownership and existing commit/owner guards.
- [ ] **Step 8: Verify screen integration.** Run that command also including `test/widget/discovery_lesson_test.dart test/widget/discovery_section_view_test.dart test/widget/course_learning_resume_test.dart test/widget/discovery_lesson_review_repeat_test.dart test/widget/discovery_lesson_recovery_test.dart test/widget/discovery_lesson_recovery_accessibility_test.dart test/widget/course_learning_cutover_test.dart`; expect all pass. Full Flutter suite, analysis and release JS build must pass on the final task head. Publish/review/merge per protocol. Suggested commit `test: pin finite review UI recovery boundaries`.

## 3. Controller final integration and published outcome

- [ ] Run this integrated gate on the Task3 candidate before its merge, with Tasks1–2 already published. If Task3 is a proven no-op, use current published main instead. Read actual complete FR-05 diffs against its published baseline, all task reports and independent reviews; map every spec acceptance row to the exact executed test(s), using existing verified coverage where sufficient. No requirement is accepted solely from a worker report or suite count. Obtain one independent whole-feature review of the changed paths and their integration, not a second implementation.
- [ ] Resolve all Critical/Important findings before merge/acceptance. For every set-aside behavior or coverage-only caveat, record the disposition and why it is not an observed blocker; scope increases or external gates need user decisions, not silent deferral.
- [ ] Independently verify the exact integrated tree from `frontend/` using `/home/klottick/develop/flutter/bin/flutter test --no-pub --reporter expanded`, `analyze --no-pub`, and `build web --release --no-pub`. Full tests exit0/all pass, analysis has no issues, build reports `Built build/web`. Recheck affected gates after any head/base change.
- [ ] From the root run `python3 -m unittest discover -s scripts -p 'test_*.py'` and `python3 scripts/verify_french_audio.py --repo-root .`. Require exit0; the latter establishes only technical/metadata validity of still-pending candidates, not reviewed audio.
- [ ] Check diff whitespace/scope and that `frontend/assets/` (including `audio/fr/provenance.json`, manifest and licences), root `LICENSE`, `docs/french-reference-audio.md`, dependencies and backend remain unchanged against the FR-05 published baseline. Preserve old namespaces, unpublished branches, worktrees, unrelated files and process captures; no automatic cleanup.
- [ ] Recheck actual PR head/current main, GitHub checks/review feedback and applicable protection requirements before every merge; never override protection or treat missing checks as success. Use the reviewed PR only, then fetch and verify the complete published tree matches the verified head (or rerun affected integrated checks).
- [ ] Create the scoped outcome doc `docs/superpowers/status/2026-10-16-fr05-finite-review.md` with the spec/plan links, actual PRs/reviewed heads/merge SHAs, requirement/evidence matrix, commands/counts, coverage-only versus behavior-fix dispositions and remaining external gates. Publish it via its own reviewed docs PR based on current main; no direct main push. Controller can author/review docs; record exact publication in the local ledger.
- [ ] Report FR-05 complete only after all approved task deliverables and the outcome record are published/verified. Do not claim future legacy-lesson conversion, assessment, real playback, French review, live Supabase, privacy/FR-15 or production release are complete.

## 4. Plan self-review and approval handoff

Coverage: spec1–2 → baseline audit/ownership and no replacement engine; spec3.1 → existing first-pass tests plus Task3 all-wrong/UI capability; spec3.2 → Tasks1/3 finite queues and explicit transitions; spec3.3 → Tasks1/2 threshold, history and completion; spec4 → Tasks2/3 durable Retry, restore, policy, capability and owner fences; spec5 → matrix and controller gates; spec6 → global constraints and outcome limitations. All five Review Focus conditions have named owning tests.

Interfaces use existing constructors/actions/properties; helpers are test-local and defined in their task. No task relies on a new API from an unmerged worker, and each scope has its own independently testable deliverable. Test-only GREEN is permitted evidence for an existing behavior, not falsely reported RED/GREEN remediation. No new libraries, schema, implementation, workers or release authorization are implied by this written plan.

**Approval gate:** user reviews this plan before execution. Preserve the previously selected sequential Luna subagent method unless the user changes it. After approval use `subagent-driven-development`; do not request approval again between already approved tasks unless a real blocker or scope decision arises.
