# Repository agent workflow

## Required delivery process for all subagents

The standing user instruction is: **push a scoped branch, open a pull request
against GitHub `main`, review it, and merge only when the controller is satisfied
with the review and verification.** This applies to all subagent implementation
work, including documentation changes. A local commit or a worker's completion
report is not delivery to `main`.

1. Start scoped work from current published `origin/main` in an isolated branch
   and worktree. For dependent tasks, wait for the preceding PR to be reviewed
   and merged, then use that merged baseline. Do not use unpublished local
   `main` or another worker's unmerged branch as the publication baseline.
2. Give each implementer an explicit task, owned files and acceptance criteria.
   Use sequential `ollama/qwen3.8:27b` implementation workers unless the user
   changes that choice. Workers must not spawn other subagents or merge PRs.
   Read-only reviewers do not create implementation PRs.
3. Implement and verify the scoped change; use test-first regressions for code
   behavior. Commit only owned files. Push the task branch and open a PR against
   `main` (the worker or controller may publish the approved task branch).
   Include scope, verification evidence, limitations and deferred findings.
4. The controller reviews the actual PR diff for specification compliance,
   code quality, preservation of existing behavior and unrelated changes.
   Obtain independent review for code changes; a worker's self-review does not
   replace review. Return blocking findings to the implementer and review fixes.
5. Before merging, the controller independently runs applicable verification,
   checks the exact PR head and current base, and checks available GitHub checks
   and review feedback. Missing CI is not a passing CI result. If the base or
   head changes, re-evaluate the integrated tree and repeat affected checks.
6. Merge through the reviewed GitHub PR only when there are no unresolved
   blocking findings and applicable checks pass. The controller may merge under
   this standing instruction without asking again for the routine merge of the
   approved scope. New scope, destructive actions and unresolved blockers still
   require a user decision. Never bypass protection rules or use admin overrides.
7. Verify the published merged result and record the PR URL, reviewed head,
   merge commit, commands/results and outstanding gates in the task's process
   records. Do not report an unmerged task as published or fully accepted.

## Preservation and scope

- Do not push directly to `main`, integrate by an unreviewed local merge, or
  force-push without explicit user authorization.
- Preserve unpublished Sound Match work, other local branches, user changes,
  worktrees and durable process/evidence records. Do not delete them as automatic
  finishing cleanup. Current planning/status records live in `docs/superpowers/`;
  local task ledgers/evidence live in `.superpowers/`.
- Execution approval is not approval for unrelated features or a bypass of
  linguistic, licensing, playback, assessment, privacy or release gates. For
  French reference audio, follow `docs/french-reference-audio.md`; pending
  candidates are not reviewed recordings or runtime-ready assessment assets.
- A user's explicit task-specific instruction may override these defaults;
  record the changed scope or process rather than silently assuming an override.
