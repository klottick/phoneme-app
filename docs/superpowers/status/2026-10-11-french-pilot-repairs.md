# French pilot review repairs — outcome ledger

**All eight reviewed findings are repaired and merged.** No Critical/Important
findings remain open. This supersedes the original pilot's verification outcome
where the later full review found missed entry states and async interleavings.

Scope: F1–F8 from the independent full pilot review, not the wider French-course
backlog. Binding behavior remains the
[pilot spec](../specs/2026-10-11-french-first-section-design.md).
Implementation workers used only `ollama/qwen3.8:27b`, sequentially; controller
independently reviewed, tested, and merged. Local plan and process artifacts are
preserved under `.superpowers/sdd/2026-10-11-fr-pilot-review/` in the
`french-section-plan` worktree; original findings are `/tmp/opencode/fr-full-review.md`.

## Merged batches

| Batch | Findings | Branch / worktree | Head | PR / merge |
|---|---|---|---|---|
| 1 persistence integrity | F1, F5; typed conflict contract | `fix/fr-progress-integrity` / `fr-section-persistence` | `a56db17` | [#10](https://github.com/klottick/phoneme-app/pull/10) / `e571489` |
| 2 audio cancellation | F3 | `fix/fr-audio-cancellation` / `fr-section-policy` | `0b3f0dd` | [#11](https://github.com/klottick/phoneme-app/pull/11) / `0a38ace` |
| 3 practice/recovery/UI/docs | F2, F4, F6, F7, F8; carried conflict comment | `fix/fr-practice-recovery` / `fr-discovery-screen` | `deb893f` | [#12](https://github.com/klottick/phoneme-app/pull/12) / `90d1f87` |

Worker identities:
- Batch 1: `ses_ed6c6c66effeMOlAEaTzLGLBb2`.
- Batch 2: `ses_ed5cb749effe8f7GNieiVnS3Yb`.
- Batch 3 original: `ses_ed5877544ffeRY2bcM7DHrsk4R`; transport timeout after
  partial implementation. Fresh recovery worker: `ses_ed431d250ffetmsXppsB1etL4i`.

Batch 3's original worker last completed an action at 16:09:25Z, then retried a
provider response-header timeout and terminated. It was not stalled for its entire
six-hour lifetime. Partial work and all test evidence were retained; recovery
finished that existing branch rather than restarting implementation.

## Repairs and review loops

| Finding | Result |
|---|---|
| F1 optimistic progress reads/cloud duplication | Public reads and outbox sync share the persistence serialization barrier; internal writer reads avoid deadlock. Rejected writes repair cache before visibility; backend waits remain outside the writer. |
| F2 mastered lessons cannot repeat | Explicit **Practise again** at normal/review debrief, with/without mistakes. A fresh zero-attempt identity is saved before exercise publication; unfinished sessions still resume, history is retained, and review Finish adds no completion. |
| F3 pending TTS starts after stop | Ownership checks after each asynchronous setup/utterance boundary; cancelled/superseded successes, errors and timeouts drain without affecting replacement speech. Current-request failure semantics retained. |
| F4 stale instances retry forever | Typed conflicts offer explicit **Reload saved progress**, clearing stale intent and hearing before reconciling the captured owner's saved state. Transient failures retain **Retry saving**. |
| F5 corrupt processed counters drop answers | Canonical processed session/count validation at load and before writes/deduplication. Strict fresh-session recovery preserves historical aggregates and siblings; no fabricated progress accepted. |
| F6 large-text recovery overflow | Recovery notice shares scrolling content; feedback wraps. Full-screen 360×800 / 3× tests scroll to and use answer, save-retry and conflict-reload controls. |
| F7 authored title leaks words | Neutral **Listening practice** title during exercise/loading/errors; authored title appears only at debrief. Actual French content/semantics tested. |
| F8 inaccurate TypeScript comparison | Comment corrected; runtime policy unchanged. |

Controller review corrections, one fix round per batch:
1. Valid equal-count same-session divergence needed the typed conflict too;
   reproduced independently, repaired and retained as regression tests.
2. Async platform exceptions/timeouts bypassed success-path ownership checks;
   seven independent reproductions failed then passed after the fix.
3. The initial repeat-practice report overclaimed real-store review coverage;
   three independently passing real-store scenarios were promoted into repository
   tests, the report corrected, and exception taxonomy documentation clarified.

Final broad review covered `d92ec22..deb893f`, including cross-task interfaces and
preservation of duplicate no-ops, exact transition rejection, owner/lifecycle
guards, 80% gating, finite mistake rounds and debrief-only teaching. No findings
were parked. The unchanged due-list pushes the exact tested `?review=true` route;
due-list row rendering itself is not newly tested.

## Independent verification

SDK: `/home/klottick/develop/flutter/bin/flutter`. Commands ran sequentially.

| Gate | Controller result | Evidence |
|---|---|---|
| `test --no-pub --reporter expanded` on final task head | **375 passed** | `/tmp/opencode/fr-repairs-final-tests.log` |
| Independent controller/exhaustive tests on final task head | **13 passed** | `/tmp/opencode/fr-repairs-final-controller-tests.log` |
| `analyze --no-pub` on final task head | No issues | `/tmp/opencode/fr-repairs-final-analyze.log` |
| `build web --no-pub` on final task head | JavaScript build succeeds | `/tmp/opencode/fr-repairs-final-build.log` |
| `test --no-pub --reporter expanded` on published merge `90d1f87` | **375 passed** | `/tmp/opencode/fr-repairs-merged-tests.log` |
| `analyze --no-pub` on published merge | No issues | `/tmp/opencode/fr-repairs-merged-analyze.log` |
| `build web --no-pub` on published merge | JavaScript build succeeds | `/tmp/opencode/fr-repairs-merged-build.log` |
| `git diff --check d92ec22 deb893f` | Clean | Controller tool output |
| `git diff --exit-code deb893f HEAD -- frontend`; diff against `origin/main` | Empty on merged controller tree | Controller tool output |

Independent files: `/tmp/opencode/fr-t1-controller-conflict_test.dart`,
`fr-t2-controller-cancel_errors_test.dart`, `fr-t3-controller-integration_test.dart`,
and `fr-session-exhaustive-review_test.dart`. The last covers every one of 1,024
pilot first-pass patterns and reachable 1–3-item states through four rounds.
Old full-review repros with await-before-release ordering were superseded by
barrier-compatible repository regressions, not run into deadlocks again.

## Rulings and costs

1. Ruling: treat the user's bugfix request as approval of the bounded repair
   designs already presented — no broader feature work authorized. Cost if wrong:
   an additional repair-design confirmation was desired.
2. Ruling: retain the previously authorized sequential PR/push/controller-merge
   workflow. Cost if wrong: reviewed merged fixes require reversion rather than
   simply closing PRs.
3. Ruling: preserve all process records/worktrees rather than skill cleanup.
   Cost if wrong: retained ignored artifacts consume disk.
4. Ruling: controller performs task and final review itself, matching the user's
   assigned reviewer role. Cost if wrong: less fresh review context, mitigated by
   independent reproductions and durable diff/review artifacts.
5. Ruling: recover the terminated worker in a fresh local Qwen context on the
   existing dirty task branch. Cost if wrong: a focused handoff/audit is needed;
   no partial work discarded and no model change.

## Remaining gates and preserved work

- Real French voice quality and actual OS/mobile suspend-resume timing require
  hardware checks. Audio tests use the real adapter with mocked MethodChannel.
- Live backend/RLS execution remains unverified. Sync uses mock HTTP plus static
  SQL review; no live credentials, recording uploads or cloud speech grading.
- Reviewed recordings and specialist linguistic validation remain rollout gates.
- Existing `flutter_tts-4.2.5` Wasm dry-run warnings persist; approved JavaScript
  builds pass. WebAssembly support is not claimed.
- Broader map, spelling, sentence, assessment, reliable local pronunciation and
  HTTPS microphone work remains queued; obtain scope approval before execution.
- Every worker branch/worktree and ignored process record remains. Local
  `main`/`feat/phoneme-word-match` and unpublished `af7e871`/`4dff777` were not
  reset, overwritten or bundled.
