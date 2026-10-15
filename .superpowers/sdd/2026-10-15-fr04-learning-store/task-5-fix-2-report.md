# FR04 Task 5 fix round 2/5

## Controller finding C1

If the acknowledgment write fails and rollback/restore also fails, the
repository quarantines the scope. `SupportedProgressSync` previously caught
the acknowledgment error and called the normal `readPending` callback; that
callback correctly honored quarantine by throwing `LearningUnavailableException`,
so sync itself failed instead of returning pending status and the retained
committed-event count.

## Change

- Added an optional, backward-compatible `knownPendingCount` callback to
  `SupportedProgressSync`. It is used only when acknowledgment fails and only
  to produce pending status; ordinary send failures and progress reads continue
  to use `readPending` and keep quarantine enforced.
- The repository callback returns the count from its last successfully loaded
  committed state (`_committed`, with the sync-start state as a fallback). The
  failed acknowledgment path loads the latest persisted committed image under
  the coordinator before attempting its write, so this includes events
  committed while the network send was in flight. It does not inspect the
  rejected optimistic cache/document.
- `retryLoad` remains the sole recovery path: restore known committed bytes,
  reload, compare exact bytes, then clear quarantine. The test confirms stable
  pending IDs replay and are acknowledged only after this repair.
- No auth behavior, cloud schema, screen, backend, or general storage
  availability semantics changed.

## TDD and verification

RED (before production edits):

```sh
PATH=/home/klottick/develop/flutter/bin:$PATH flutter test \
  test/unit/course_learning_sync_test.dart \
  --plain-name 'failed ack rollback reports committed count and quarantines until repair' \
  --reporter expanded
```

Exit 1 with `Learning progress is unavailable.` from `readPending` inside
`SupportedProgressSync._run` after actual repository `sync()` successfully sent
the batch, the acknowledgment persistence write rejected, and rollback failed.
The test also staged a second committed pending event during the held send.

GREEN:

- Same isolated test command — exit 0, **1 test passed**.
- Focused sync/provider + Task 4 suite:
  ```sh
  PATH=/home/klottick/develop/flutter/bin:$PATH flutter test \
    test/unit/course_learning_sync_test.dart \
    test/unit/course_learning_providers_test.dart \
    test/unit/course_learning_store_test.dart \
    test/unit/course_learning_commit_isolation_test.dart \
    test/unit/course_learning_retention_test.dart
  ```
  — exit 0, **44 tests passed**.
- Full suite, one pass: `PATH=/home/klottick/develop/flutter/bin:$PATH flutter test`
  — exit 0, **1007 tests passed**.
- Analyzer: `PATH=/home/klottick/develop/flutter/bin:$PATH flutter analyze`
  — exit 0, `No issues found!`.
- `dart format` on the three changed Dart files; `git diff --check` — clean.

## Delivery

- Scoped files: `course_learning_sync.dart`, `course_learning_store.dart`,
  `course_learning_sync_test.dart`, and this report plus the Task 5 summary.
- Existing PR #36 (`feat/fr04-task5-sync-auth` → `main`):
  <https://github.com/klottick/phoneme-app/pull/36>. No merge performed.
- Independent scoped re-review remains pending. Live Supabase integration was
  not exercised; tests use the repository and mocked transport/persistence.
