# Process ledger — first French discovery section

Plan: `docs/superpowers/plans/2026-10-11-french-first-section.md`
Spec: `docs/superpowers/specs/2026-10-11-french-first-section-design.md`
Coordinator: current OpenCode session; workers: `ollama/qwen3.8:27b` only.
Authorization: user requested plan, small local-Qwen tasks, PRs, controller review/merge/state ownership on 2026-10-11.

## State

| Task | State | Branch / workspace | Worker | PR / merge | Verification |
|---|---|---|---|---|---|
| Planning | merged | `docs/french-first-section`, `wks_0f327fd42c4ce757` | controller | [#1](https://github.com/klottick/phoneme-app/pull/1), `2ee916e` | docs-only scope/whitespace review; remote baseline 128 tests/analyzer clean |
| 1 policy | merged | `feat/fr-section-policy`, `wks_30e17a2a110b4685` | `ses_ed7b28857ffekgx7UgLTvK1dUe` | [#2](https://github.com/klottick/phoneme-app/pull/2), head `382f530`, merge `7130cb9` | controller: 161 full tests pass, analyzer clean; invalid-value reproduction fixed |
| 2 content/session | merged | `feat/fr-section-session`, `wks_c449fb2828dcbebc` | `ses_ed7aabf1cffe8amV18675aLqw4` | [#4](https://github.com/klottick/phoneme-app/pull/4), head `3a9bf82`, merge `77117b7` | controller: 219 full tests pass, analyzer clean, 8 invalid snapshots rejected |
| 3 persistence | merged | `feat/fr-section-persistence`, `wks_bccf671bff3e1262` | `ses_ed78b449dffelAD0FF2yNlyWif` | [#6](https://github.com/klottick/phoneme-app/pull/6), head `87d80f7`, merge `deb9906` | controller: 247 full tests and 5 targeted regressions pass; analyzer clean |
| 4 view | merged | `feat/fr-section-view`, `wks_456f5abd3290f0d6` | `ses_ed7665014ffe67N7wHb8H1Bkle` | [#7](https://github.com/klottick/phoneme-app/pull/7), head `93eeddb`, merge `14ec4c8` | controller: 265 full tests pass; analyzer clean |
| 5 screen/routes | merged | `feat/fr-discovery-screen`, `wks_3bfe435ea695759f` | `ses_ed7548eb3ffeXqyZ6xwxLH0Xw6` | [#9](https://github.com/klottick/phoneme-app/pull/9), head `7a6ae08`, merge `a4a5f33` | controller: 301 tests + 7 load/lifecycle regressions pass; analyzer clean; JS build succeeds |
| Final verification | complete; no important findings open | isolated controller workspace, `docs/fr-section-final-state` | controller | reviewed code matches `origin/main` at `a4a5f33`; final status PR [#8](https://github.com/klottick/phoneme-app/pull/8) | merged-tree 301 tests pass; analyzer clean; JS build succeeds; 1 documentation-only minor deferred |

## Outcome and follow-up gates

The approved `/u/`–`/y/` pilot is implemented and merged. The existing
`/course-lesson/en-fr-u-y` route now presents ten audio-first puzzles, immediate
feedback, a section-end explanation even below threshold, configurable completion
(default 8/10), and finite mistake-only review rounds. Progress resumes locally;
answers/checkpoints/evidence are retry-safe, account-scoped, and compatible with
the existing progress-only outbox. `?review=true` does not add completion. Other
lesson routes and microphone/game implementations remain unchanged.

Final controller review: policy/content/session/store/view/screen/router contracts
and complete task diffs checked together; important findings addressed. Exact
merged-tree verification, sequential in `frontend/` with
`/home/klottick/develop/flutter/bin/flutter`:

- `pub get --enforce-lockfile`: succeeds; lockfile unchanged.
- `test --no-pub --reporter expanded`: **301 tests passed**.
- `analyze --no-pub`: **No issues found**.
- `build web --no-pub`: **Built build/web** (JavaScript).
- `git diff --exit-code origin/main -- frontend`: empty before verification;
  verified code is the published merge `a4a5f33`, not unpublished local main.
- Evidence: `/tmp/opencode/fr-merged-{pub,tests,analyze,build}.log`.
- Independent load/lifecycle regression evidence (7 passing):
  `/tmp/opencode/fr-final-controller-repros.log`; full pre-merge gates:
  `/tmp/opencode/fr-final-controller-{tests,analyze,build}.log`.

Remaining gates: real French voice availability and OS/mobile suspend/resume
timing require device testing; automated coverage uses actual delayed Futures and
fake audio/lifecycle hooks. Reviewed reference recordings and linguistic review
are deferred. Existing third-party `flutter_tts` WebAssembly dry-run warnings do
not block the approved JavaScript build; Wasm support is not claimed. The broader
19-ticket path/map/spelling/sentence/assessment backlog and local pronunciation
grading remain queued, not delivered or newly authorized by this pilot.

All worker worktrees and ignored briefs/reports/review records are retained.
Existing unpublished Sound Match commits were not reset, overwritten or bundled.

## Baselines and constraints

- Inspected local source `4dff777`: 172 Flutter tests passed on 2026-10-11.
- Published base is `origin/main` at `706744a`: 128 Flutter tests passed; analyzer reported no issues on 2026-10-11. Evidence: `/tmp/opencode/french-remote-baseline-tests.log`, `/tmp/opencode/french-remote-baseline-analyze.log`.
- Existing local `main`/`feat/phoneme-word-match` include `af7e871`, `4dff777`, not yet on GitHub. Preserve and do not publish these as part of lesson PRs.
- GitHub CLI authenticated; no open PRs at initial inspection.
- Native Paseo worktrees explicitly use existing project `prj_b4a8c55c34b2481e` (`phoneme-app`).
- No automatic unattended daemon promised: this ledger is the durable resume point for coordinating sessions.

## Rulings and costs

1. Ruling: execute the first `/u/`–`/y/` slice, not all 19 draft tickets at once — matches the recommended next step the user accepted; cost if wrong: later requested features remain queued.
2. Ruling: ten existing curated examples, finite first pass then mistake-only review rounds — makes 80% an exact 8/10 and explanation timing deterministic; cost if wrong: retune section size/retry pacing, not rewrite evidence.
3. Ruling: first-pass debrief is available below 80%; completion remains gated — avoids withholding explanations from struggling learners; cost if wrong: adjust phase/gating policy.
4. Ruling: use labeled existing device French TTS for this practice-only slice and defer new recordings/generation — no approved recording source and user requested simplicity; cost if wrong: device voice limitations persist until reviewed assets land.
5. Ruling: workers implement sequentially on local Qwen; controller performs independent spec/quality review and merge — user explicitly assigned review to controller; cost if wrong: no separate reviewer model on these tasks.
6. Ruling: create and execute this scoped plan under the user's explicit create-plan-then-delegate authorization rather than repeat approval prompts — confirmed behavior is binding and remaining defaults are public; cost if wrong: user can request policy changes/rework.
7. Ruling: base PRs on published `origin/main`, not the two unpublished local commits — avoid publishing other work without bundling approval; cost if wrong: remote pilot verification does not include the newer Sound Match until its separate publication.
8. Ruling: serialized policy percentages must be `int` 1–100; reject doubles/nonfinite values with FormatException — actual JSON integer decoding is `int`, verified on the SDK, and the contract specifies integer percentages; cost if wrong: maps carrying `80.0` need upstream normalization. Unknown keys can be ignored; canonical serialization still emits one key.
9. Ruling: `answered` is current-round/current-item boolean submission status, not a Set of historical answers; latestAnswers and answeredItemCount provide aggregate coverage — necessary for retry gating and the consuming store/view contracts; cost if wrong: unshipped session snapshots/tests require schema adjustment. All exposed collections are unmodifiable.
10. Ruling: failed writes must restore same-process reads to last committed data, not merely leave physical disk unchanged — UI retries without restart and subsequent writers share the preferences cache; cost if wrong: a platform reload on failures, no success-path migration. Explicit fresh saves may recover unusable section state while preserving legacy data and valid sibling sections.
11. Ruling: the view's `error`/`Retry saving` path is for persistence failures; playback failures use separate generic audio feedback and allow Listen again — avoids presenting a save action for a microphone-free playback error; cost if wrong: the screen's audio notification UI may need refinement. Never display raw exceptions that can contain the hidden word/answer.
12. Ruling: backgrounding invalidates audio, not recoverable save intent; preserve same-owner pending actions or reconcile committed state on resume — needed for retry-safe progress without stale callback effects; cost if wrong: an additional idempotent retry/load on resume, not lost answers or false unlocks.
13. Ruling: only `resumed` reopens foreground recovery; `inactive` focus changes must not replay saves or settle suspended navigation — prevents duplicate callbacks and premature exits; cost if wrong: recovery waits for resumed rather than acting during transitional focus loss.
14. Ruling: final cleanup may modify `lesson_policy.dart` only to correct its false comment alongside the screen load fix — closes the deferred minor without changing policy behavior; cost if wrong: PR #9 adds one documentation-only core-file edit.
15. Ruling: defer the cleanup comment's new inaccurate “unlike TypeScript” comparison, not the load fix — Dart's actual bool/int claim is corrected and runtime parsing is unchanged; cost if wrong: a misleading cross-language phrase remains until documentation polish. No important behavior finding is parked.

## Preflight dependency/interface scan

| Task/pair | Check | Finding / decision |
|---|---|---|
| 1 | Tests vs policy contract/files | Integer rounding, validation and JSON all defined; 2 files only. |
| 2 | Tests vs content/session contract/files | Ten IDs, state transitions, strict restore defined; no storage/UI. |
| 3 | Tests vs store contract/files | Shared writer and compatible events; no new SQL or outbox event kinds. |
| 4 | Tests vs view contract/files | Stateless callbacks; screen remains sole I/O owner. |
| 5 | Tests vs screen/router contract/files | Pilot-only route preserves legacy recording flow; all dependencies merged first. |
| 1 ↔ 2,5 | Policy production/consumption | Session snapshots store policy; new defaults cannot change resumed eligibility. |
| 2 ↔ 3,4,5 | Content/session production/consumption | Exact fields/methods live in reachable spec; consumers cannot invent their own schema. |
| 3 ↔ 5 | Store/provider production/consumption | Same typed facade enables fake failures/account switches in tests. |
| 4 ↔ 5 | View callback production/consumption | No view-side persistence; screen controls heard/busy/error gating. |
| 3 ↔ legacy progress | Shared `course_progress.dart` | Preserve `_update` serialization and unknown data; tests cover existing arcade/sync calls. |
| 5 ↔ legacy routing | Shared `app_router.dart`/flow test | Modify only pilot branch; do not rewrite non-pilot screens or microphone tests. |

## Execution log

- 2026-10-11: Model resolved as `ollama/qwen3.8:27b`; isolated planning workspace created under the existing project. No implementation worker dispatched yet.
- 2026-10-11: Docs PR #1 reviewed and merged at `2ee916e`; worker Task 1 dispatched on `ollama/qwen3.8:27b`, session `ses_ed7b28857ffekgx7UgLTvK1dUe`, base `2ee916e`. Only policy/tests allowed; worker must create PR and may not merge.
- 2026-10-11: Task 1 PR #2 reviewed at `b17e457`; scoped policy is sound except invalid infinity escapes as UnsupportedError and JSON-type justification is incorrect. Fix round 1 requested with stricter integer decoding, malformed-value/real JSON round-trip tests, and formatting. No merge yet.
- 2026-10-11: Task 1 fix `382f530` re-reviewed: important findings addressed; spec compliance and task quality approved. Controller ran full Flutter tests (161 pass), analyzer (no issues), whitespace check, and invalid-value reproduction (all FormatException). Evidence: `/tmp/opencode/fr-policy-controller-tests.log`, `/tmp/opencode/fr-policy-controller-analyze.log`. PR #2 merged at `7130cb9`.
- 2026-10-11: Task 2 dispatched on local Qwen, base `7130cb9`; new isolated workspace baseline 161 tests passed (`/tmp/opencode/fr-session-baseline-tests.log`). Only content/session and their tests are owned.
- 2026-10-11: Task 2 PR #4 reviewed at `53f519b`; content approved, session changes required. Reproduction accepted contradictory outcomes, missing/future coverage, shortened queue, inflated counts and invalid review state. Fix round 1 requested; explicit answered-bool contract added before dependent work.
- 2026-10-11: Task 2 fix round 1 `53f519b..b08799c` re-reviewed; original findings addressed. New regression: removed zero-attempt/null-lastCorrect equivalence permits losing the prior outcome at review start. Reproduced using updated bool-schema snapshots; narrow fix round 2 requested. PR #4 remains unmerged.
- 2026-10-11: Task 2 fix round 2 `b08799c..3a9bf82` re-reviewed: lastCorrect equivalence restored with regression tests; spec compliance and quality approved. Controller full suite 219 tests passed, analyzer clean, whitespace clean, all 8 malformed reproductions rejected. PR #4 merged at `77117b7`. Evidence: `/tmp/opencode/fr-session-controller-tests.log`, `/tmp/opencode/fr-session-controller-analyze.log`. Initial concurrent verification hit an SDK engine-stamp HTTP 404 before tests began; standalone rerun passed.
- 2026-10-11: State/contracts docs PR #3 reviewed (docs-only, whitespace clean) and merged at `62d9300`. Task 3 dispatched to local Qwen in existing project workspace `wks_bccf671bff3e1262`, base `62d9300`, worker `ses_ed78b449dffelAD0FF2yNlyWif`. Controller prepared dependencies and verified baseline 219 tests passed (`/tmp/opencode/fr-persistence-baseline-tests.log`). Reminder in brief: compare checkpoints to legal stored-session transitions, not only attempt counts; stale owners must be rejected inside queued writes.
- 2026-10-11: Status rechecked at user request: Task 3 opened PR #6 at `96e698c`. Controller review changes required: answer recording omits submit replay and accepts historical-outcome/policy changes; mutable input can bypass validation; failed writes poison same-process cache; corrupt sections cannot recover. Five targeted regressions fail (`/tmp/opencode/fr-store-review-results.log`). Fix round 1 requested; no merge or duplicate implementation dispatched.
- 2026-10-11: Task 3 fix `96e698c..87d80f7` reviewed: important findings addressed, spec compliance and quality approved. Controller verified 247 full Flutter tests and all 5 targeted regressions passed; analyzer and whitespace checks clean. PR #6 merged at `deb9906`. Evidence: `/tmp/opencode/fr-store-controller-tests.log`, `/tmp/opencode/fr-store-controller-repro.log`, `/tmp/opencode/fr-store-controller-analyze.log`.
- 2026-10-11: Task 4 dispatched to local Qwen on base `deb9906` in workspace `wks_456f5abd3290f0d6`, worker `ses_ed7665014ffe67N7wHb8H1Bkle`. Only stateless view and widget tests owned. Baseline 247 full tests passed (`/tmp/opencode/fr-view-baseline-tests.log`). Screen/audio/store integration remains Task 5.
- 2026-10-11: Task 4 PR #7 reviewed at `93eeddb`: spec compliance and quality approved. Controller full Flutter suite 265 tests passed, analyzer no issues, whitespace check clean. PR #7 merged at `14ec4c8`. Evidence: `/tmp/opencode/fr-view-controller-tests.log`, `/tmp/opencode/fr-view-controller-analyze.log`. Hiding Review mistakes with no unresolved items meets the contract; audio-failure/save-failure UI distinction carried into Task 5.
- 2026-10-11: Docs/state PR #5 reviewed (docs-only, whitespace clean) and merged at `71970d1`. Task 5 dispatched to local Qwen on that base in workspace `wks_3bfe435ea695759f`, worker `ses_ed7548eb3ffeXqyZ6xwxLH0Xw6`. Controller baseline: 265 full Flutter tests passed (`/tmp/opencode/fr-screen-baseline-tests.log`). Owned screen/router/flow tests only; merged core/store/view and legacy recording/game files are off limits. Final integrated review/build remains pending.
- 2026-10-11: Task 5 PR #9 reviewed at `9db752f`: lifecycle changes required. Controller reproduced permanent spinner after backgrounded load, discarded failed-answer retry with Next falsely enabled, and missing audio stop on owner change (`/tmp/opencode/fr-screen-review-results.log`). Tests claiming delayed callbacks did not actually complete them. Fix round 1 requested with real completion gates and safe resume reconciliation. No merge.
- 2026-10-11: Task 5 fix `9db752f..bc6b8e7` re-reviewed: original reproductions pass, but 3 follow-up cases fail (`/tmp/opencode/fr-screen-rereview-results.log`): held answer enables Next while suspended; inactive/resumed events duplicate one save to 3 calls; suspended Finish navigates on inactive before resumed. Fix round 2 requested for explicit suspension state, coalescing and single-exit guards. PR #9 remains unmerged.
- 2026-10-11: Task 5 fix `bc6b8e7..df29733` scoped re-review approved. Controller: 298 full tests and all 6 lifecycle reproductions passed, analyzer clean, JavaScript web build succeeds, whitespace clean (`/tmp/opencode/fr-screen-controller-*-round2.log`). Existing TTS Wasm dry-run warnings remain nonblocking for JS.
- 2026-10-11: Whole-pilot controller review `706744a..df29733` found one important unchanged load race: double Retry loading can publish a late result over an already answered session (`/tmp/opencode/fr-final-load-review-results.log`). Single final fix wave requested, including the deferred policy comment correction; PR #9 held until scoped final re-review. Manual real-voice/mobile, reviewed audio/linguistics and broader backlog remain follow-up gates.
- 2026-10-11: Final wave `df29733..7a6ae08` scoped re-review approved: load retries coalesced before redraw, orphaned load identity guards late publication, owner/resume recovery remains possible with hung old loads; policy change is comment-only. Controller 301 full tests, 7 load/lifecycle reproductions, analyzer and JS build pass, whitespace/worktree clean. PR #9 merged at `a4a5f33`. No important findings remain; one nonfunctional comparative-comment nit deferred with ruling.
- 2026-10-11: Published merge brought into the isolated controller workspace without changing local main or worker branches. `frontend/` diff against `origin/main` empty; merged-tree 301 tests passed, analyzer clean, JS web build successful (`/tmp/opencode/fr-merged-*.log`). Final state prepared in docs PR #8. All five tasks complete; broader backlog remains queued.

## Deferred minor findings for final review

- Original Dart bool-subtype comment: corrected in `7a6ae08`, runtime guard unchanged; report's false rationale superseded without deleting prior evidence.
- Final comment at `lesson_policy.dart:89` adds a misleading “unlike TypeScript” comparison (TypeScript has no `int` type and its boolean is not a numeric subtype either). Documentation-only, deferred under ruling 15; no behavior blocker.
