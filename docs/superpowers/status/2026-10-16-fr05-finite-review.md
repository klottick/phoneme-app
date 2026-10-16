# FR-05 finite review rounds: published outcome

## Outcome and scope

The approved FR-05 code/test deliverables are published on GitHub `main` through
[PR40](https://github.com/klottick/phoneme-app/pull/40),
[PR41](https://github.com/klottick/phoneme-app/pull/41) and
[PR42](https://github.com/klottick/phoneme-app/pull/42).
The existing discovery implementation satisfied the tested contract; **no
production behavior change was needed**. Eighteen additional tests pin the
pure session, real repository and visible UI boundaries. This is coverage-only
delivery, not a new scheduler, a calibrated mastery claim or release approval.

- [Approved spec](../specs/2026-10-16-fr05-finite-review-design.md)
- [Approved implementation plan](../plans/2026-10-16-fr05-finite-review.md)
- Spec publication: [PR38](https://github.com/klottick/phoneme-app/pull/38),
  merge `ed24386e5dc304018c4b9f1de0938f9855bfde64`.
- Plan publication: [PR39](https://github.com/klottick/phoneme-app/pull/39),
  reviewed head `cb5a3d35b4ef25cd52b43edb1f79927101b95e3a`,
  merge `d58e2dfb164e0ebd878e2a259a8aa2bbf6f9aa2a`.

The user approved the written spec and then confirmed the written plan for
sequential Luna execution. Each task started from the preceding published merge,
received independent specification/quality review and controller verification,
and merged only through its scoped PR. The controller fetched each merge and
verified its complete tree against the reviewed head.

| Task | Reviewed head | Published merge |
| --- | --- | --- |
| PR40: pure finite-round contract, 3 tests | `9febee9ac62a6131a792f08e008fd6600f6ff1ef` | `a7ee2ee75989fc947ff46d3371336b43a7b01ca4` |
| PR41: durable discovery contract, 6 tests | `a5bab7bef33f6ba0c7a061df9b30e06530804478` | `d117b3c839529aa6acd4eda4ad52483a84a7b90a` |
| PR42: visible recovery contract, 9 tests | `4f7f581e8167b4555d0cd87b759238cbe77813f0` | `dd0e66f7135be45dca2f1c91ebb961c215f5fe17` |

The final integrated review covered
`d58e2dfb164e0ebd878e2a259a8aa2bbf6f9aa2a..4f7f581e8167b4555d0cd87b759238cbe77813f0`.
Its specification and quality verdicts both passed, with no unresolved
Critical/Important findings. PR42's current base was
`d117b3c839529aa6acd4eda4ad52483a84a7b90a`; its fetched merge tree was identical
to the exact reviewed/tested head. GitHub reported no checks, formal reviews or
inline feedback at the implementation merge gates; **missing CI is not passing
CI**. Independent agent reviews and controller acceptance were recorded separately
in the PR comments and preserved process evidence, not represented as formal
GitHub approvals.

## Requirement and executed-evidence matrix

New suites (paths relative to `frontend/test/`):

- **Pure:** `unit/lesson_finite_round_contract_test.dart`
- **Repository:** `unit/course_learning_discovery_contract_test.dart`
- **Widget:** `widget/discovery_finite_round_contract_test.dart`

Every cited new and existing test was included in the controller's exact-head
full run. The matrix uses their assertions, not the total count alone as evidence.
Source owners below are under `frontend/lib/src/`.

| Spec acceptance row | Source owner | Executed assertions / disposition |
| --- | --- | --- |
| Threshold and rounding | `core/course/lesson_policy.dart`, `lesson_section_session.dart` | Pure `session_threshold_matrix_requires_full_coverage_and_debrief` covers all seven required 80/75/100% fixtures. Existing `unit/lesson_policy_test.dart` pins default80, integer-only decoding, invalid 0/101/negative percentages and ceiling arithmetic. |
| Coverage and phase | Session and `course_learning_lesson_transition.dart` | Pure matrix rejects completion before the final advance. Existing session tests `rejects submitting the current item twice in one round` and `repeating a correct answer cannot inflate coverage`, plus transition `unseen item cannot be replaced by repeated correct word`, reject inflated coverage. |
| Debrief access and no leakage | `features/course/discovery_lesson_screen.dart`, `discovery_section_view.dart` | Widget `all_wrong_first_pass_debrief_is_available_but_not_passing` checks ten wrong answers, immediate feedback, hidden word/explanation semantics absent during puzzles, explanation at debrief, disabled Finish, ten retained mistakes and Back navigation without starting review. |
| Finite review | Session and discovery screen | Pure `all_wrong_rounds_remain_finite_beyond_twelve_submissions` executes five rounds / fifteen submissions. Widget `failed_one_item_review_returns_to_debrief_without_auto_restart` checks one-item termination, idle debrief and explicit next-round start. Existing session `queues only unresolved items in original order` and `rejects a review round when every latest outcome is correct`, and discovery widget review playback-order assertions, cover mixed/order/empty boundaries. See the nonblocking caveat below. |
| History and mistakes | `core/course/course_learning_transition.dart`, `course_learning_store.dart` | Repository `passing finish preserves mistakes until only matching answers resolve` proves 8/10 Finish retains both mistakes after reload, correct `tout` resolves neither, correct `tu` resolves only its own mistake and earlier wrong-attempt IDs remain. |
| Resume and saved policy | Session, codec and discovery screen | Pure `partial_later_round_restore_preserves_queue_and_saved_policy`, repository `review reload retains policy, retry provenance and summary evidence`, and widget `remount_after_failed_advance_restores_answer_not_pending_intent` pin saved queue/outcomes/policy and answered feedback without reconstructed pending intent. The one-item widget mounts saved100% with a current80% policy. Existing session JSON round trips cover unanswered/answered/debrief/review states; `widget/course_learning_resume_test.dart` requires fresh playback on reopen. |
| Capability failure | `core/course/course_audio.dart`, discovery screen | Widget `review_audio_unavailable_is_unscored (cancel=false)` and `(cancel=true)` compare history/mistakes/attempt count, disabled choices and absent explanations; actual failure shows generic guidance, cancellation stays quiet, and successful fresh playback is required before a scored answer. Real hardware/browser playback remains external. |
| Durable completion | Repository, lesson transition and discovery screen | Repository `checkpoint rejection retries advance exactly once`, `checkpoint rejection retries review start exactly once` and `checkpoint rejection retries finish exactly once` compare full fresh-loaded canonical state and adapter/cache rollback, then prove idempotent same-command retry, one sequence increment and no new answer evidence. `completion identity survives reload and threshold changes` checks saved80/100/100 metadata and retained earlier completion. Widget frozen Advance Retry publishes debrief only after ACK. Existing transition `review only finish never completes lesson` and discovery widget `review=true Finish saves but never records completion`, plus held-Finish navigation assertions, cover review-only and save-aware Finish. |
| Isolation and recovery | Repository/codec and discovery screen | Widget `held_review_start_cannot_publish_after_owner-cycle`, `held_review_start_cannot_publish_after_disposal` and `failed_final_advance_retry_intent_is_retired_on_provider_owner_change` pin late continuation and pending-intent retirement. Existing owner/resume, repository stale-generation/conflicting-token/corrupt/future-schema and transition `content mismatch requires explicit new run` regressions passed unchanged. |
| Honest retry evidence | Learning transition and repository | Repository `review reload retains policy, retry provenance and summary evidence` verifies saved100%, `mur` occurrence2, after-debrief attribution, first/repeat summary totals and retained history across reload. Widget capability recovery checks repeat/after-debrief context on the scored retry. No held-out or mastery inference is made. |

## Review dispositions

- Task1 was coverage-only GREEN from its first focused run. Tasks2/3 encountered
  test-fixture compilation/selection/assertion mistakes; these were corrected
  against actual APIs and were not reported as product defects or runtime
  RED/GREEN fixes. The first runnable complete contract suites passed unchanged
  product code. An earlier incomplete Task2 worker result was not published or
  accepted; a fresh worker completed the required scope.
- Task2 review required a stronger full-state rollback assertion. The fix compares
  the fresh repository's canonical codec image with the pre-failure committed
  image for all three checkpoint actions; independent rereview cleared it.
- Task3 review required the pending final-Advance owner-replacement boundary.
  The fix proves A's pending Retry retires without resubmission or any B write.
  Explicit next-round and explanation-semantics assertions were also added.
  Independent rereview cleared these findings.
- **Nonblocking coverage Minor retained:** the new pure fifteen-answer loop does
  not directly assert `currentItemId == capturedQueue[index]` before every answer.
  It asserts bounded attempts, unchanged captured queues and debrief boundaries.
  Existing session and widget assertions independently pin authored unresolved
  order. The final reviewer judged this a narrow optional assertion-strengthening
  opportunity, not an observed behavior defect or merge blocker.

## Controller verification

Final integrated commands were run on head
`4f7f581e8167b4555d0cd87b759238cbe77813f0`; its published merge tree matched
exactly. Flutter executable: `/home/klottick/develop/flutter/bin/flutter`.

| Working directory | Command | Result |
| --- | --- | --- |
| `frontend/` | `flutter test --no-pub --reporter expanded` | **1,033 passed**, exit0; unchanged-product planning baseline was 1,015. |
| `frontend/` | `flutter analyze --no-pub` | No issues, exit0. |
| `frontend/` | `flutter build web --release --no-pub` | `Built build/web`, exit0. Existing `flutter_tts` Wasm dry-run incompatibility warnings remain; this is a JavaScript build, not Wasm certification. |
| Repository root | `python3 -m unittest discover -s scripts -p 'test_*.py'` | **52 passed**, exit0. |
| Repository root | `python3 scripts/verify_french_audio.py --repo-root .` | **24 pending** candidates passed technical/metadata verification only. |
| Repository root | `git diff d58e2dfb164e0ebd878e2a259a8aa2bbf6f9aa2a 4f7f581e8167b4555d0cd87b759238cbe77813f0 --check` | Clean. Exact code-delivery diff is the three new test files only. |

Scoped controller runs also passed: Task1's three pure suites (87 tests),
Task2's six repository suites (88 tests), and Task2's covering fix suite (6 tests).
The final full suite includes all Task3 integration suites and all final fixes.

All production code, dependencies, backend, assets and storage namespaces remain
unchanged. SHA-256 comparison verified 30 audio/licence/policy paths against the
published execution baseline, including root `LICENSE`, provenance and
`docs/french-reference-audio.md`. Unpublished Sound Match work, old development
data, branches, worktrees and process records were preserved; no automatic cleanup
or migration was performed. Durable local evidence is under
`.superpowers/sdd/2026-10-16-fr05-finite-review/` (logs, reports, task reviews,
acceptance matrix and final review).

This outcome record is delivered through its own scoped reviewed documentation
PR; its exact PR/head/merge and published-tree verification are recorded in the
local delivery ledger and PR comments, avoiding a self-referential merge hash.

## Outstanding gates and non-goals

Real browser/native playback and cancellation, qualified French linguistic,
audio and licensing review, live Supabase validation, privacy, FR-15 and
production release remain open. All pending recordings remain pending. Technical
verification does not make them reviewed recordings or assessment-ready assets.
No browser sandbox bypass, further Qwen investigation, cloud pronunciation
evaluation, recording upload, invented grade or silent TTS substitution is
authorized by this delivery.

FR-05 covers the existing discovery listening-choice section and reusable session
contract only. Future legacy-lesson conversion, new exercises/content, speaking,
assessment, progression/map work and cross-activity scheduling remain separate
scopes. A passing JavaScript build does not certify Wasm, real playback or a
production-ready pronunciation evaluator.
