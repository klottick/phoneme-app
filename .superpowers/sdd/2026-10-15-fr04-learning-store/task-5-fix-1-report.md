# FR04 Task 5 fix round 1/5

## Review finding

Important I1 from `task-5-review.md`: a synchronous `onCommitted` observer could
throw after persistence had committed, turning a durable success into a failed
`submit`; the provider callback retained `Ref` and could be called after owner
rebuild/disposal.

## Changes

- `frontend/lib/src/core/course/course_learning_store.dart`: invoke
  `onCommitted` only after `_committed`/`_committedRaw` have been updated, inside
  a best-effort exception boundary. The comment records why observer errors
  cannot change durable acknowledgment. Persistence errors remain outside this
  boundary and retain the existing rollback/quarantine and `LearningSaveException`
  behavior.
- `frontend/lib/src/core/course/course_learning_providers.dart`: replace the
  stale `Ref.invalidate` closure with a private state revision notifier watched
  by `courseLearningStateProvider`. The callback captures that notifier and the
  existing tracker (not `Ref`), checks provider liveness and captured
  owner/generation against current tracker/backend identity, and only then
  notifies. `ref.onDispose` closes the old provider's callback authority.
- `frontend/test/unit/course_learning_providers_test.dart`: added a real
  repository throwing-observer case, held-write real provider owner-rebuild
  case using mock-authenticated Supabase owner identity, and live state refresh
  plus failed-write no-invalidation case.

No schema, cloud delivery, auth tracking, screens, dependencies, or persistence
failure behavior changed.

## TDD and verification

RED evidence (exit 1, prior to production fix):

- `flutter test test/unit/course_learning_providers_test.dart` (initial RED)
  reported `Bad state: observer failed` escaping from
  `CourseLearningRepository.submit` after the write.
- `flutter test test/unit/course_learning_providers_test.dart --plain-name 'old provider commit after owner rebuild stays on captured scope' --reporter expanded`
  failed with `CircularDependencyError` from the disposed store provider's
  `Ref.invalidate` closure after the held old-owner write was released.
- `flutter test test/unit/course_learning_providers_test.dart --plain-name 'live commit refreshes state provider but failed write does not' --reporter expanded`
  failed with `CircularDependencyError`; the state provider remained stale
  (`activities == {}`) after the durable normal commit.

The first aggregate RED attempt also hit timeouts because the test awaited the
new owner's queued load before releasing the held old-owner write; the
repository's process coordinator correctly serialized both. The test now
asserts provider replacement first, releases the old write, and only then awaits
the new-owner load. The isolated RED runs above verify the production failures.

GREEN evidence:

- `PATH=/home/klottick/develop/flutter/bin:$PATH flutter test test/unit/course_learning_providers_test.dart`
  — exit 0, **7 tests passed**.
- Focused sync/provider + Task 4 suite (store, commit isolation, retention):
  ```sh
  PATH=/home/klottick/develop/flutter/bin:$PATH flutter test \
    test/unit/course_learning_sync_test.dart \
    test/unit/course_learning_providers_test.dart \
    test/unit/course_learning_store_test.dart \
    test/unit/course_learning_commit_isolation_test.dart \
    test/unit/course_learning_retention_test.dart
  ```
  — exit 0, **42 tests passed**.
- Full suite, one requested pass: `PATH=/home/klottick/develop/flutter/bin:$PATH flutter test`
  — exit 0, **1006 tests passed**.
- Analyzer: `PATH=/home/klottick/develop/flutter/bin:$PATH flutter analyze`
  — exit 0, `No issues found!`.
- Formatting: `dart format` on the three changed Dart files — formatted; no
  outstanding formatter changes.
- `git diff --check` and staged `git diff --cached --check` — exit 0.

## Delivery

- Commit: `ee2c2c632ec9ef5eab5dfe32280393057c63f1c6`
  (`fix: isolate FR04 commit notifications from persistence`).
- PR #36: <https://github.com/klottick/phoneme-app/pull/36>, updated on the
  existing `feat/fr04-task5-sync-auth` branch; no merge performed.
- Remaining gates: independent re-review and real Supabase auth/RPC validation
  with external credentials. No secrets or live service calls were used.
