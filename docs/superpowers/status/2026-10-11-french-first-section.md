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
| 2 content/session | implementing | `feat/fr-section-session`, `wks_c449fb2828dcbebc` | `ses_ed7aabf1cffe8amV18675aLqw4` | pending, base `7130cb9` | controller baseline: 161 tests pass |
| 3 persistence | blocked: 2 | — | — | — | — |
| 4 view | blocked: 2; serial after 3 | — | — | — | — |
| 5 screen/routes | blocked: 3, 4 | — | — | — | — |
| Final verification | blocked: 5 | — | controller | — | — |

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

## Deferred minor findings for final review

- Task 1 `lesson_policy.dart` bool-subtype comment is false: Dart bool is not a subtype of int. The explicit guard is redundant but harmless; correct the comment/report at final cleanup. No behavior blocker.
