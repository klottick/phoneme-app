# FR04 Task 5 implementation report

## Scope and interfaces

Implemented only supported cloud delivery and auth-bound provider wiring; new
providers are not imported by production screens and therefore do not cut over
the existing runtime (Task 6 remains the cutover gate).

Owned files:

- `frontend/lib/src/core/course/course_learning_sync.dart`
  - Added `SupabaseLearningCloudTransport`, sending only the legacy
    `record_course_events` RPC with exact `events` parameter and legacy snake
    case payload fields.
  - Added bounded batches of 100, per-storage-scope in-process coalescing, and
    owner/generation/backend checks before each send and before acknowledgment.
  - Captures IDs pending at sync start, so unrelated events committed during a
    network wait remain pending and are not swept into this run.
- `frontend/lib/src/core/course/course_learning_store.dart`
  - Runs network work outside the process coordinator; pending reads and ID
    acknowledgment use the existing private coordinator and reload latest
    committed persistence.
  - Acknowledgment removes only sent IDs from current state, preserves current
    activity/history data, and follows Task 4 rollback/quarantine behavior.
  - Send/ack failures return `pending` with the actual remaining count; owner
    changes retain pending IDs. Guest sync exits without backend delivery.
  - Added an optional commit callback for invalidating the learning-state
    provider after a nonduplicate successful commit.
- `frontend/lib/src/core/course/course_learning_providers.dart`
  - Added `LearningAuthTracker`, auth-controller observation, preferences,
    registry, nullable cloud, owner-generation-keyed store, and state providers.
  - Same-owner ready/loading/error changes preserve generation; owner changes
    advance it, including A→B→A. Repository callbacks close over the tracker,
    not a provider `Ref`; backend owner is read authoritatively from the current
    Supabase client.
- `frontend/test/unit/course_learning_sync_test.dart`
  - Covers real repository sync and a real Supabase RPC transport over an HTTP
    mock: 201 events / `[100, 100, 1]`, guest, send and ack failure/retry IDs,
    optimistic failed-write isolation, latest-state acknowledgment, account and
    guest coalescing boundaries, auth switches including A→B→A, and exact RPC
    wire shape.
- `frontend/test/unit/course_learning_providers_test.dart`
  - Covers owner epoch/store identity, initial-loading guest command block,
    same-owner readiness/error stability, and supported-sync status semantics.

No backend schema, auth/profile/streak schema, dependencies, screens, or
download paths changed. The existing Task 4 projector remains authoritative.

## TDD and verification evidence

- RED: `flutter test test/unit/course_learning_sync_test.dart test/unit/course_learning_providers_test.dart`
  - Initial implementation-missing failure reported unresolved
    `SupabaseLearningCloudTransport`, missing
    `course_learning_providers.dart`, and undefined declared providers and
    `LearningAuthTracker`. Test-harness typos found during this first compile
    were corrected before implementation continued.
- Focused GREEN + Task 4 safety suite (exit 0; 40 tests):
  ```sh
  flutter test test/unit/course_learning_sync_test.dart \
    test/unit/course_learning_providers_test.dart \
    test/unit/course_learning_store_test.dart \
    test/unit/course_learning_commit_isolation_test.dart \
    test/unit/course_learning_retention_test.dart
  ```
- Full suite (single requested pass, exit 0): `flutter test` — **1003 tests
  passed**.
- Analyzer (exit 0): `flutter analyze` — `No issues found!`.
- Formatting: `dart format` on the five owned Dart files — no outstanding
  formatting changes.
- Diff whitespace check: `git diff --check` — exit 0.
- Production provider import check: `grep -R course_learning_providers
  frontend/lib --include='*.dart'` — no matches.
- No live Supabase credentials or network were used. The RPC was exercised
  through `SupabaseClient` and `http/testing` mock transport; live auth/RPC
  behavior remains an explicit external limitation.

## Documentation lookup fallback

Context7 `resolve-library-id` was attempted for Riverpod and Supabase Flutter,
but both calls returned `Monthly quota exceeded`. Fallback references consulted:

- Supabase Dart RPC documentation:
  <https://supabase.com/docs/reference/dart/rpc>
- `flutter_riverpod` 2.6.1 API documentation (the dependency resolved by this
  repository):
  <https://pub.dev/documentation/flutter_riverpod/2.6.1/flutter_riverpod/flutter_riverpod-library.html>
- `supabase_flutter` 2.12.4 package documentation:
  <https://pub.dev/packages/supabase_flutter/versions/2.12.4>

## Self-review, concerns, and delivery

- Reviewed changes are restricted to the two named implementation files, two
  named test files, and this task report. The initial branch remains based on
  published `origin/main` commit `de7acfc106b969a1b3fb6cb0ebbd5a4a78b4bf82`.
- Checks confirmed no production screen imports the new providers; no rejected
  optimistic write reached the transport; auth transitions cannot revive an
  earlier generation; acknowledgment preserves newer pending data.
- No blocking implementation concerns identified. Runtime screen migration,
  real service credentials/integration, and merge remain outside this task.
- Commit: pending.
- PR against GitHub `main`: pending publication; do not merge from this worker.
