# SQLite Learning Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. Each task is one scoped PR from the latest published `origin/main`; review and merge it before starting the next task. Do not spawn nested agents. Steps use checkbox syntax.

**Goal:** Replace the three learning families' preferences documents with one fresh, normalized SQLite learning database on native and web while preserving their domain transitions, progress views, and supported course-sync contract.

**Architecture:** One lazily opened Drift database uses app-private SQLite on native and Drift's SQLite/WASM backend on web. A shared SQL coordinator performs receipt-first idempotency, scope-revision compare-and-swap, owner fencing, and atomic writes; separate typed adapters/repositories map course, comparison, and sentence-hunt state to normalized rows while their existing pure transition engines remain authoritative. SQL repositories are constructed and tested while inactive; the three production providers keep their existing preferences repositories until one atomic provider cutover selects the SQL repositories together.

**Tech Stack:** Flutter 3.41.9 / Dart 3.11.5; candidate pins `drift 2.34.0`, `sqlite3 3.7.1`, `drift_dev 2.34.0`, `build_runner 2.15.1`; `NativeDatabase.createBackgroundConnection` for native; `WasmDatabase.open` for web; `integration_test` from the installed Flutter SDK; existing Riverpod providers and pure Dart learning transitions.

**Spec:** `docs/superpowers/specs/2026-10-18-sqlite-learning-storage-design.md` (design approved in conversation; this implementation plan is not approved for execution).

## Global Constraints

- Fresh progress only: old preferences keys/data stay untouched; the SQL runtime does not read, import, migrate, dual-write, delete, or fall back to them.
- One `phoneme_learning.sqlite` file per native installation and one `phoneme_learning` database per web origin; all families share it and are isolated by `(owner_kind, owner_id, course_id, family)`.
- Course, comparison, and sentence-hunt score, lesson, audio, completion, and lifecycle behavior remains unchanged. Persist only bounded typed current checkpoints as JSON; never serialize attempts, aggregates, or full history as one database value.
- Schema version 1 is explicit. Future SQLite upgrades are ordered, forward-only, and atomic. Unknown/newer versions and failed upgrades remain untouched and unavailable.
- Web accepts only Drift implementations `opfsShared`, `opfsLocks`, or `sharedIndexedDb`; reject `unsafeIndexedDb` and `inMemory`. No localStorage, SharedPreferences, in-memory, or other learning-data fallback.
- Each learner command atomically commits typed attempt/value/evidence rows, checkpoint, receipt, aggregates, completion/exposure/best-score changes, and any already-supported outbox rows. A failed or unknown commit is unavailable/retryable, never a successful save or empty profile.
- Matching receipt lookup precedes expected-revision rejection. Same token plus identical canonical payload is a no-op duplicate; changed payload is invalid; an unproven stale/pruned command conflicts.
- Retain at most 2,000 attempts and 2,000 receipts per owner/course/family. Trim whole course answer batches. Keep each current run's latest receipt after receipt pruning. Keep summaries, mistakes, completions, and exposure independent of detail pruning. Cap each applicable aggregate collection at 4,096 identities and reject overflow atomically.
- Do not impose the historical 36 MiB serialized-document/codec limit as a SQLite database or row limit.
- Preserve `course_learning_sync.dart`'s exact existing projection: supported course answer/lesson/score events only; unchanged `id`/`user_id`/`course_id`/`kind` envelope and answer fields; `record_course_events`; batches of at most 100; acknowledge delivered IDs. Add no comparison/sentence events or selected/expected answer, checkpoint, or full-attempt uploads.
- Guest/account identities remain distinct; account IDs are stored exactly, never delimiter-concatenated. Captured auth generation is fenced, including A→B→A; old work affects only its captured owner and cannot notify replacement providers.
- A new database is empty only after successful open, schema setup, and query. Loading, open/query failure, corruption, quota denial, unsupported backend, and unknown version are not zero/not-started. Do not restore playback, hearing grants, timers, microphone state, or autoplay authorization.
- Keep SharedPreferences for unrelated settings/auth state. Preserve unpublished Sound Match work, approvals, licences, release gates, other worktrees, and durable evidence.
- Candidate app SDK floor is `>=3.10.0 <4.0.0`; do not upgrade installed Flutter/Dart, add overrides, or silently choose another storage stack. Package pins are candidates, not a solved set. Solver, generation, or build incompatibility stops for a concrete decision.
- Every implementation task ends with the focused tests **and** `cd frontend && flutter analyze` plus `cd frontend && flutter test`. These whole-app gates are required before every task PR can be merged. Generated outputs must be inspected before generation; use `cd frontend && dart run build_runner build` without `--delete-conflicting-outputs`. If a conflict names an existing output, stop and report it; never discard it automatically.
- Real browser/device qualification is evidence, not inference. An unrun target, storage-denial path, or unsupported runtime remains OPEN and blocks any support/capacity claim. This plan itself performs no solve, code generation, device/browser probe, or capacity measurement.

## Review Focus

- Browser selects `unsafeIndexedDb`/`inMemory`, or worker/WASM fails: fail closed before publishing learning state. Tests: Task 1 selector/stub tests and web smoke; Task 9 same-profile browser runbook.
- Same-token retry arrives after scope revision advances, or token is reused with another payload: receipt wins before stale revision; changed payload is invalid; pruned unproven command conflicts. A nonempty outbox ACK advances scope revision only, so a command prepared before ACK conflicts and a reloaded command succeeds. Tests: Task 4 `receipt_retry_precedes_stale_scope_revision_and_changed_payload_is_invalid` and `outbox_ack_revision_conflicts_stale_snapshot_then_reloaded_command_succeeds`.
- Two connections commit from one snapshot, or auth switches A→B→A during work: one divergent writer conflicts; no cross-owner write or stale provider notification. Tests: Task 4 `independent_connections_commit_one_divergent_command`; Task 8 `aba_write_stays_in_captured_scope`; Task 9 actual two-tab test.
- SQL fails after candidate rows start, or caller loses commit acknowledgment: reopen shows the full prior or full committed state; exact retry creates one attempt. Tests: Task 4 `sql_trigger_failure_rolls_back_all_rows`; Task 9 `injected_sql_failure_rolls_back_and_lost_ack_retry_is_once` repeats exact-token retry across independent connections and actual runtimes.
- Attempt/receipt pruning crosses a batch boundary, or an aggregate reaches 4,096: retain latest receipt/checkpoint and cumulative summary; reject overflow without partial credit. Tests: Task 9 `all_families_reopen_at_limits_without_summary_drift` on file-backed and actual platform backends.

---

## File Map

All paths below are future implementation paths. The documentation task creates or changes only this plan.

| Path | Responsibility |
| --- | --- |
| `frontend/pubspec.yaml`, `frontend/pubspec.lock` | Candidate Drift/tool pins, `integration_test: sdk: flutter`, and actual successful solver result. |
| `frontend/lib/src/core/course/storage/learning_database_connection.dart`, `_native.dart`, `_web.dart`, `_stub.dart` | Conditional connection API, background native connection, selected-web-implementation gate, explicit unsupported-platform error. |
| `frontend/web/sqlite3.wasm`, `frontend/web/drift_worker.dart.js`, `frontend/web/learning_storage_assets.sha256` | Exact pinned-package runtime assets and verified source/archive/member SHA-256 provenance. |
| `frontend/test/support/learning_database_smoke.dart`, generated `.g.dart` | One-table typed probe DB; `writeProbe` / `readProbe` used only by platform smoke. |
| `frontend/integration_test/learning_database_native_test.dart`, `learning_database_web_test.dart`, `learning_database_qualification_app.dart`, `frontend/integration_test/support/learning_database_workload.dart`, `frontend/test_driver/integration_test.dart` | Real integration entrypoints, persistent-profile qualification UI, deterministic shared maximum-workload fixtures, and Flutter web driver. |
| `frontend/integration_test/learning_storage_qualification_runbook.md` | Owned start/stop/relaunch/verify procedures for same-profile browser and native app-process persistence. |
| `frontend/lib/src/core/course/learning_storage_types.dart` | Stable `LearningCursorPosition`, `LearningReceiptIdentity`, and `LearningRetainedReceiptIdentity`, moved out of the legacy transaction coordinator. |
| `frontend/lib/src/core/course/course_attempt.dart`, `comparison_learning_state.dart`, `sentence_hunt_learning_state.dart` | Keep existing `storageKey` identity strings unchanged where they salt stable attempt/event IDs; they are not database paths or preferences reads/writes. |
| `frontend/lib/src/core/course/course_learning_command_codec.dart`, `comparison_learning_command.dart`, `sentence_hunt_learning_command.dart` | Required scope-revision command identity. Existing document canonical forms remain separate and unchanged until cutover/cleanup. |
| `frontend/lib/src/core/course/storage/learning_tables.dart`, `learning_database.dart`, generated `learning_database.g.dart` | Named normalized v1 tables/indexes, safe version checks/migration runner, app-scoped lazy handle. |
| `frontend/lib/src/core/course/course_learning_error.dart` | Existing typed learning errors used by database lifecycle/coordinator; add no untyped storage-error channel. |
| `frontend/build.yaml`, `frontend/test/support/sqlite_learning_test_harness.dart`, `learning_migration_failure_probe.dart`, `frontend/test/unit/learning_database_schema_test.dart` | Generator config, file-backed tests, injected failed-migration probe, schema/unknown-version tests. |
| `frontend/lib/src/core/course/storage/learning_storage_scope.dart`, `learning_sql_transaction.dart` | Fully typed scope/receipt/adapter/coordinator contracts, receipt-first lock/CAS transaction, course outbox ACK. |
| `frontend/test/unit/learning_sql_transaction_test.dart` | Receipt order, owner identity, multi-connection CAS, rollback, unknown ACK, notification and ACK ordinal tests. |
| `frontend/lib/src/core/course/storage/course_learning_sql_adapter.dart`, `course_learning_sql_repository.dart`, `course_learning_state_validator.dart`, `course_learning_checkpoint_codec.dart` | Inactive course SQL implementation; existing transition preserved; normalized mapping, validation, bounded checkpoint. |
| `frontend/lib/src/core/course/storage/comparison_learning_sql_adapter.dart`, `comparison_learning_sql_repository.dart`, `comparison_learning_storage_validator.dart`, `comparison_learning_command_codec.dart`, `comparison_learning_checkpoint_codec.dart` | Inactive comparison SQL implementation and typed validation/checkpoint mapping. |
| `frontend/lib/src/core/course/storage/sentence_hunt_learning_sql_adapter.dart`, `sentence_hunt_learning_sql_repository.dart`, `sentence_hunt_learning_storage_validator.dart`, `sentence_hunt_learning_command_codec.dart`, `sentence_hunt_learning_checkpoint_codec.dart` | Inactive sentence-hunt SQL implementation, including `runStartRound` persistence. |
| `frontend/lib/src/core/course/course_learning_providers.dart`, `sentence_hunt_learning_providers.dart`, `frontend/lib/src/features/home/home_screen.dart`, `frontend/lib/src/features/course/course_progress_screen.dart` | One atomic provider switch to SQL, loading/unavailable/verified-empty/retry behavior. |
| `frontend/test/unit/learning_sql_retention_test.dart`, `learning_sql_recovery_test.dart`, `frontend/test/widget/course_learning_cutover_test.dart` | File-backed limits/recovery and shared-provider cutover regressions. |
| Legacy runtime slated for Task 10 only: `course_learning_persistence.dart`, `course_learning_transaction.dart`, `course_learning_codec.dart`, `comparison_learning_codec.dart`, `sentence_hunt_learning_codec.dart`, plus legacy repository/adapter sections in `course_learning_store.dart`, `comparison_learning_store.dart`, `sentence_hunt_learning_store.dart` | Remove only after SQL providers are active and every remaining reference is migrated. Keep typed store interfaces/result types, new codecs/validators/checkpoint codecs, stable storage types, and `course_learning_error.dart`. |
| Legacy test helpers slated for Task 10: `frontend/test/support/course_learning_persistence_fakes.dart`, `course_learning_preferences_harness.dart`, `sentence_hunt_harness.dart` | Replace with file-backed SQL test helper where still needed; delete only obsolete preferences-only helpers. |

## Task 1: Qualify the candidate cohort and platform connection bootstrap

**Files:**
- Modify: `frontend/pubspec.yaml`, `frontend/pubspec.lock`
- Create: `frontend/lib/src/core/course/storage/learning_database_connection.dart`, `learning_database_connection_native.dart`, `learning_database_connection_web.dart`, `learning_database_connection_stub.dart`
- Create: `frontend/web/sqlite3.wasm`, `frontend/web/drift_worker.dart.js`, `frontend/web/learning_storage_assets.sha256`
- Create: `frontend/test/support/learning_database_smoke.dart`, generated `learning_database_smoke.g.dart`
- Create: `frontend/test/unit/learning_database_connection_web_test.dart`, `learning_database_connection_stub_test.dart`
- Create: `frontend/integration_test/learning_database_web_test.dart`, `learning_database_qualification_app.dart`, `learning_storage_qualification_runbook.md`, `frontend/test_driver/integration_test.dart`

**Interfaces:**
- `LearningDatabaseConnection({required DatabaseConnection connection, String? webImplementation})`.
- `Future<LearningDatabaseConnection> openLearningDatabaseConnection()` and `bool acceptsLearningWebImplementation(String implementationName)`.
- `LearningStorageUnsupportedPlatformException` is the exact exception thrown by the stub and asserted by the stub test.
- `LearningDatabaseSmoke(DatabaseConnection connection)` uses one generated `LearningDatabaseSmokeRows` table with `probeKey` (unique text) and `probeValue` (text); it exposes `Future<void> writeProbe(String key, String value)` and `Future<String?> readProbe(String key)`.
- `LearningDatabaseSmoke.close() -> Future<void>` closes the generated database/connection after each smoke lifecycle.
- The qualification app displays `chosenImplementation` in `ValueKey('learning-storage-backend')`, and provides **Write probe** / **Read probe** actions with keys `learning-storage-write-probe` and `learning-storage-read-probe`; the exact observed value is rendered in `ValueKey('learning-storage-probe-result')`. It uses the fixed probe key supplied in the URL query and has no production route.
- The web integration test calls `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`. `test_driver/integration_test.dart` contains `Future<void> main() => integrationDriver();`.
- `learning_storage_qualification_runbook.md` records the Task 1 browser start/write/two-tab/close/relaunch/read steps without clearing or reusing a profile; Task 9 adds native process-restart and retention steps.

- [ ] **Step 1: Write selector and stub tests first.** Test accepted values (`opfsShared`, `opfsLocks`, `sharedIndexedDb`), rejected values (`unsafeIndexedDb`, `inMemory`), and directly import `learning_database_connection_stub.dart` to assert `LearningStorageUnsupportedPlatformException`.

```dart
test('accepts only coordinated persistent implementations', () {
  expect(acceptsLearningWebImplementation('opfsShared'), isTrue);
  expect(acceptsLearningWebImplementation('opfsLocks'), isTrue);
  expect(acceptsLearningWebImplementation('sharedIndexedDb'), isTrue);
  expect(acceptsLearningWebImplementation('unsafeIndexedDb'), isFalse);
  expect(acceptsLearningWebImplementation('inMemory'), isFalse);
});
```

- [ ] **Step 2: Run the tests RED.** Run `cd frontend && flutter test --platform chrome test/unit/learning_database_connection_web_test.dart` and `cd frontend && flutter test test/unit/learning_database_connection_stub_test.dart`. Expected: fail because the connection API and named stub exception do not exist. The stub test imports `learning_database_connection_stub.dart` directly; it does not rely on the conditional export selecting the stub on Chrome.
- [ ] **Step 3: Add only candidate dependencies.** Pin `drift: 2.34.0`, `sqlite3: 3.7.1`, `drift_dev: 2.34.0`, and `build_runner: 2.15.1`; add `integration_test: sdk: flutter` under `dev_dependencies`; add `path: 1.9.1` or `web: 1.1.1` only if production imports them directly. Raise the app SDK constraint from `>=3.3.0 <4.0.0` to `>=3.10.0 <4.0.0`. Do not change the installed SDK or use overrides.
- [ ] **Step 4: Implement connections and the typed smoke DB.** Web calls pinned `WasmDatabase.open` with database name `phoneme_learning`, `sqlite3.wasm`, and `drift_worker.dart.js`; inspect `chosenImplementation.name`, close/reject all but the three allowed values, then return `resolvedExecutor`. Native uses `getApplicationSupportDirectory()` and `NativeDatabase.createBackgroundConnection(file, readPool: 0)`; this exact Drift 2.34 API returns `DatabaseConnection` and opens outside the UI isolate. Stub throws the named exception. Implement the one-table smoke DB and its two methods.
- [ ] **Step 5: Acquire only exact release artifacts with provenance.** Inspect the pinned package archives, not a CDN's current files. Fetch Drift from `https://pub.dev/api/archives/drift-2.34.0.tar.gz` and verify `printf '%s  %s\n' '6cc0b623c0e83f7080524d8396e9301b1d78b9c66a4fdceeb0f798211303254c' drift-2.34.0.tar.gz | sha256sum --check -`; this archive SHA-256 was controller-verified against the exact archive. Fetch sqlite3 from `https://pub.dev/api/archives/sqlite3-3.7.1.tar.gz`; fetch `https://pub.dev/api/packages/sqlite3` and obtain only the `.versions[]` entry whose `.version == "3.7.1"` (for example `jq -er '.versions[] | select(.version == "3.7.1") | .archive_sha256'`), then verify with `printf '%s  %s\n' "$expected" sqlite3-3.7.1.tar.gz | sha256sum --check -`. List both archives with `tar -tzf`; identify the exact runtime-matched worker and WASM members required by the pinned API, copy their bytes without transformation to the destination names in the File Map, and record source archive member paths plus destination names. Record canonical package/archive URLs, archive hashes and extracted asset hashes in `learning_storage_assets.sha256`. If the release metadata/hash, exact assets, or version compatibility is unavailable/unclear, stop and report the blocker; do not use a CDN copy, substitute a release, or build with an unpinned tool.
- [ ] **Step 6: Resolve and generate without destructive cleanup.** Run `cd frontend && flutter pub get`; verify exact candidate pins and SDK result in `pubspec.lock`. Run `cd frontend && dart run build_runner build` (no delete-conflicting flag). Expected: solver succeeds and creates `learning_database_smoke.g.dart`; any conflict with a pre-existing output stops the task for review.
- [ ] **Step 7: Run focused tests and web compile.** Run `cd frontend && flutter test --platform chrome test/unit/learning_database_connection_web_test.dart`, `cd frontend && flutter test test/unit/learning_database_connection_stub_test.dart`, `cd frontend && flutter drive --driver=test_driver/integration_test.dart --target=integration_test/learning_database_web_test.dart -d chrome`, and `cd frontend && flutter build web --release`. Expected: selector/stub assertions pass and the pinned API/assets compile.
- [ ] **Step 8: Run the required same-profile browser gate before Task 2.** Follow `frontend/integration_test/learning_storage_qualification_runbook.md`. Start the app with `cd frontend && flutter run -d web-server -t integration_test/learning_database_qualification_app.dart --web-hostname 127.0.0.1 --web-port 7357`. Launch a dedicated, previously unused Chrome profile at `/tmp/opencode/learning-storage-profile-task1-<unique-run-id>` using `"${CHROME_BIN:-google-chrome}" --user-data-dir=<that-profile-path> --no-first-run http://127.0.0.1:7357/?probe=task1`. In tab 1 write the probe; open tab 2 in the same Chrome profile and same origin and read it. Assert exact value and allowed selected implementation. Close all Chrome windows normally, verify the process using that profile exited, relaunch the exact command with the same profile path, and read the value again. Do not use isolated Playwright BrowserContexts or delete/reuse an existing profile. Inspect worker/WASM responses and assert WASM MIME is `application/wasm`. If this gate cannot run, or the selected mode is unsafe/volatile, stop before Task 2 and record OPEN; do not cut over.
- [ ] **Step 9: Run whole-app gates and commit.** Run `cd frontend && flutter analyze` and `cd frontend && flutter test`; both must pass. Commit only the paths enumerated under Task 1 **Files**, staging those individual paths (no directories or globs), with `git commit -m "feat: qualify SQLite learning database platforms"`.

## Task 2: Move shared storage types and bind every command to required scope revision

**Files:**
- Create: `frontend/lib/src/core/course/learning_storage_types.dart`, `frontend/lib/src/core/course/course_learning_command_codec.dart`, `frontend/test/unit/learning_storage_types_test.dart`
- Modify under `frontend/lib/src/core/course/`: `course_learning_command.dart`, `course_learning_transition.dart`, `course_learning_codec.dart`, `comparison_learning_command.dart`, `comparison_learning_transition.dart`, `comparison_learning_codec.dart`, `sentence_hunt_learning_command.dart`, `sentence_hunt_learning_transition.dart`, `sentence_hunt_learning_codec.dart`.
- Modify: `frontend/lib/src/core/course/course_learning_transaction.dart` to move the three stable storage types and temporarily re-export them.
- Modify current constructor callers/fixtures:
  - `frontend/test/unit/course_learning_game_transition_test.dart`, `course_learning_store_test.dart`, `course_learning_lesson_transition_test.dart`, `course_learning_codec_test.dart`, `course_learning_retention_test.dart`;
  - `frontend/test/unit/comparison_learning_store_test.dart`, `comparison_learning_transition_test.dart`;
  - `frontend/test/unit/sentence_hunt_learning_codec_test.dart`, `sentence_hunt_learning_store_test.dart`, `sentence_hunt_learning_transition_test.dart`;
  - `frontend/test/widget/sentence_hunt_entry_flow_test.dart` and `frontend/test/support/course_learning_fixtures.dart`.
- Move shared type imports in `frontend/lib/src/core/course/`: `course_learning_store.dart`, `comparison_learning_store.dart`, `sentence_hunt_learning_store.dart`, `sentence_hunt_learning_transition.dart`, `sentence_hunt_learning_state.dart`, `sentence_hunt_learning_codec.dart`, and `sentence_hunt_learning_command.dart`; and in `frontend/test/unit/`: `sentence_hunt_learning_codec_test.dart`, `sentence_hunt_learning_store_test.dart`, `sentence_hunt_learning_transition_test.dart`, and `course_learning_commit_isolation_test.dart`.
- Keep production providers and all three current preferences repository constructors unchanged in this task.

**Interfaces:**
- `learning_storage_types.dart` owns unchanged public types `LearningCursorPosition({required int generation, required int sequence, required int revision})`, `LearningReceiptIdentity({required String activityId, required String token, required String canonicalCommand, required LearningCursorPosition before, required LearningCursorPosition after, required int commitOrdinal})`, and `LearningRetainedReceiptIdentity({required String activityId, required String token, required String canonicalCommand, required int generation, required int sequence})`.
- `LearningCommand`, `ComparisonLearningCommand`, and `SentenceHuntLearningCommand` each gain **required** `int expectedScopeRevision`; constructors validate `0..9007199254740991`. No default or nullable field is permitted.
- Each transition `prepare` copies `state.revision` into the required field; SQL adapters load the database scope revision into typed state before preparation. Pure transitions retain their existing activity-cursor/content rules; only `SqliteLearningCommandCoordinator` enforces the scope revision, after receipt-first lookup and before CAS. Direct constructor tests pass the relevant state revision explicitly.
- New SQL identity functions are `CourseLearningCommandCodec.canonicalCommand(LearningCommand)`, `comparisonLearningSqlCanonicalCommand(ComparisonLearningCommand)`, and `sentenceHuntLearningSqlCanonicalCommand(SentenceHuntLearningCommand)`; each includes `expectedScopeRevision` in canonical JSON.
- `CourseLearningCommandCodec` also exposes `decodeCanonicalCommand(String raw, {required LearningScope scope}) -> LearningCommand` and `legacyCanonicalCommand(LearningCommand) -> String`. SQL canonical payloads include `expectedScopeRevision`; the legacy projection stays byte-for-byte unchanged and is used only by the still-active preferences repositories before cutover.
- Existing preferences document canonical forms remain byte-for-byte unchanged until the production cutover. Legacy document decoders accept only the current format and explicitly supply `expectedScopeRevision: 0` when reconstructing a command from an old receipt, solely for structural validation/canonical comparison; decoded receipts are never re-evaluated or used for SQL CAS. Newly prepared legacy commands carry their actual revision in memory, but their legacy canonical projection remains unchanged. No old-format importer is created.
- `course_learning_transaction.dart` temporarily re-exports the three moved types for source compatibility, but no new shared type remains defined there. The file is removed only in Task 10.

- [ ] **Step 1: Add red command-binding tests and assert both identities.** Add `course_command_captures_scope_revision` in `frontend/test/unit/course_learning_store_test.dart`, `comparison_command_captures_scope_revision` in `frontend/test/unit/comparison_learning_transition_test.dart`, and `sentence_hunt_command_captures_scope_revision` in `frontend/test/unit/sentence_hunt_learning_transition_test.dart`. In each test, prepare from state with nonzero revision, assert exact equality, decode SQL canonical JSON, and assert the required revision member. Also assert the legacy canonical projection has the exact pre-change bytes/keys and omits `expectedScopeRevision`. Update every direct constructor call in the exact Task 2 test/fixture paths to pass the required field; the analyzer/full test gate proves no caller can omit it.

```dart
expect(command.expectedScopeRevision, state.revision);
expect(
  jsonDecode(CourseLearningCommandCodec.canonicalCommand(command))
      ['expectedScopeRevision'],
  state.revision,
);
```

- [ ] **Step 2: Move shared types and update all callers.** Copy the three types unchanged into `learning_storage_types.dart`; import them there from every listed caller. Leave the legacy coordinator and its current repository adapters in place, and add only the temporary re-export described above.
- [ ] **Step 3: Add required fields and split current/SQL canonical forms.** Update all three command constructors, transition `prepare` methods, the course transition's internal replay-command construction, direct constructors and fixtures. Keep the existing pure reducers' cursor/content checks unchanged. Keep `LearningDocumentCodec.canonicalCommand`, `comparisonCanonicalCommand`, and `sentenceHuntCanonicalCommand` exactly on the current preferences-document projection. Add the three SQL canonical functions with a required revision member; do not change the legacy projection to accept a missing field.
- [ ] **Step 4: Preserve current preferences reads while commands are staged.** In `ComparisonLearningCodec._readCanonicalCommand` and `SentenceHuntLearningCodec._readCanonicalCommand`, pass explicit `expectedScopeRevision: 0` only when reconstructing commands embedded in current-format receipt canonical JSON, whose historical payload has no scope-revision field. These decode-only commands are checked against the unchanged legacy canonical projection and never passed to a transition or SQL coordinator. The course document codec does not reconstruct commands from receipts; leave its stored projection unchanged. Newly prepared current preferences commands still bind their actual revision in memory; no legacy document is rewritten or imported.
- [ ] **Step 5: Run focused tests RED/GREEN and the full gate.** First run `cd frontend && flutter test test/unit/learning_storage_types_test.dart test/unit/course_learning_game_transition_test.dart test/unit/course_learning_store_test.dart test/unit/course_learning_lesson_transition_test.dart test/unit/course_learning_codec_test.dart test/unit/course_learning_retention_test.dart test/unit/comparison_learning_store_test.dart test/unit/comparison_learning_transition_test.dart test/unit/sentence_hunt_learning_codec_test.dart test/unit/sentence_hunt_learning_store_test.dart test/unit/sentence_hunt_learning_transition_test.dart test/widget/sentence_hunt_entry_flow_test.dart` to see missing required arguments fail. Implement; rerun the same command. Then run `cd frontend && flutter analyze` and `cd frontend && flutter test`; expected: all current preferences providers and legacy document tests still pass, and every SQL command identity includes a required scope revision.
- [ ] **Step 6: Commit the shared contract.** Stage only the exact Task 2 paths above and commit `refactor: bind learning commands to scope revisions`.

## Task 3: Define normalized SQLite schema version 1 and lifecycle handle

**Files:**
- Create: `frontend/lib/src/core/course/storage/learning_tables.dart`, `learning_database.dart`, generated `learning_database.g.dart`
- Create: `frontend/build.yaml`, `frontend/test/support/sqlite_learning_test_harness.dart`, `frontend/test/support/learning_migration_failure_probe.dart`, `frontend/test/unit/learning_database_schema_test.dart`
- Consume Task 1 connection and Task 2 stable storage types.

**Interfaces:**
- `LearningDatabase(DatabaseConnection connection)` has `schemaVersion == 1`; only verified version 0 creates v1, version 1 opens after schema validation, and any other version throws `LearningUnsupportedVersionException` without changing file bytes/schema.
- Test-only seam: `LearningDatabase.forTesting(DatabaseConnection connection, {required int targetSchemaVersion, required Future<void> Function(Migrator migrator, int from, int to) migrationRunner})` supplies an alternate migration callback to the same Drift `MigrationStrategy` transaction; production construction is fixed to schema version 1.
- `LearningDatabaseHandle({required Future<LearningDatabase> Function() open})` exposes `Future<LearningDatabase> open()`, `Future<LearningDatabase> reopen()`, and `Future<void> close()`. Concurrent `open()` callers share one opening future; `reopen()` closes/reopens the same configured database and does not clear or replace it.
- File-backed helper: `Future<LearningDatabase> openFileLearningTestDatabase(File file)`.
- A test-only migration probe uses the same `MigrationStrategy` transaction with a v1→v2 callback that writes a marker then throws. It is not a production v2 schema or a forward migration.

- [ ] **Step 1: Add red file-backed schema tests.** Test exact tables/index names, owner/family/check constraints, verified-empty after schema plus query, nonempty reopen, unknown `user_version=99` preserving marker/schema, and failed synthetic migration preserving v1 data/version and rolling back its marker.

```dart
expect(await tableNames(db), orderedEquals(<String>[
  'learning_scopes', 'learning_content_bindings', 'learning_runs',
  'learning_attempts', 'learning_attempt_values',
  'learning_attempt_evidence', 'learning_command_receipts',
  'learning_mistakes', 'learning_summaries', 'learning_completions',
  'learning_exposure', 'learning_best_scores', 'supported_sync_outbox',
]));
expect(await pragmaUserVersion(db), 1);
```

- [ ] **Step 2: Run schema tests RED.** Run `cd frontend && flutter test test/unit/learning_database_schema_test.dart`; expected: missing tables/handle and migration probe.
- [ ] **Step 3: Declare the concrete relations and checks.** Use integer primary keys and `scope_id` foreign keys; all durable scope rows use `ON DELETE RESTRICT`. Add checks for nonblank IDs, enum values, booleans `0/1`, safe counters `0..9007199254740991`, count ordering, and these exact owner encodings: `(owner_kind='guest' AND owner_id='') OR (owner_kind='account' AND length(trim(owner_id))>0)`. Store account IDs verbatim.

  All table and column identifiers below are literal snake_case names. `id` columns are `INTEGER PRIMARY KEY`; foreign keys are `INTEGER`; identity/enumeration/hash/payload columns are `TEXT`; counters/timestamps/booleans are `INTEGER`. Timestamps are UTC microseconds. Booleans are constrained to `0/1`; safe counters to `0..9007199254740991` unless a stricter positive range is stated.

  - `learning_scopes`: `id`, `owner_kind`, `owner_id`, `course_id`, `family`, `schema_version`, `revision`, `commit_ordinal`, `availability_state`. `owner_kind` is `guest|account`; `family` is `course|comparison|sentence-hunt`; availability is `available|unavailable`; the owner encoding check is exactly `(owner_kind='guest' AND owner_id='') OR (owner_kind='account' AND length(trim(owner_id))>0)`. Unique `(owner_kind, owner_id, course_id, family)`; `commit_ordinal <= revision`.
  - `learning_content_bindings`: `id`, `scope_id`, `activity_id`, `content_revision`, nullable `policy_kind`, nullable `policy_revision`, nullable `catalogue_fingerprint`, nullable `section_fingerprint`, nullable `annotation_hash`, nullable `annotation_revision`. Require positive content/policy/annotation revisions when present; family-specific CHECKs constrain applicable identity columns. `ux_learning_content_bindings_identity` is unique on all identity columns after `COALESCE(nullable_text,'')` / `COALESCE(nullable_integer,-1)` normalization. Store identity only, never catalogue/audio/licence content.
  - `learning_runs`: `scope_id`, `activity_id`, `activity_kind`, `run_generation`, `sequence`, `cursor_revision`, `content_binding_id`, nullable `run_mode`, `finished`, nullable `session_id`, nullable `policy_revision`, nullable `threshold_percent`, nullable positive safe `run_start_round`, bounded typed `checkpoint_json`, `latest_receipt_token`, `latest_receipt_payload`, `latest_receipt_before_generation`, `latest_receipt_before_sequence`, `latest_receipt_before_cursor_revision`, and `latest_receipt_commit_ordinal`. Unique `(scope_id, activity_id)`; every persisted run has all latest-receipt columns populated in the same command transaction.
  - `learning_attempts`: `scope_id`, `attempt_id`, `activity_id`, `run_generation`, `command_sequence`, `batch_index`, nullable `item_id`, nullable `item_occurrence`, `content_revision`, `commit_ordinal`, `answered_at_us`, `committed_at_us`, `answer_kind`, `correct`, nullable `skill`, nullable `origin`, nullable `presentation`, nullable `assistance_mask`, nullable `content_state`, nullable `audio_source`, nullable `round`, nullable `after_debrief`, nullable `teaching_exposed`, nullable `selected_relation`, nullable `expected_relation`, nullable `section_id`, nullable `sentence_id`, nullable `annotation_hash`, and nullable `annotation_revision`. Course answers require item ID/occurrence; comparison and sentence-hunt rows use their family-specific identities instead. Unique `(scope_id, attempt_id)` and `(scope_id, activity_id, run_generation, command_sequence, batch_index)`; family checks require only that family's typed columns.
  - `learning_attempt_values`: `scope_id`, `attempt_id`, `field`, `ordinal`, `value_type`, nullable `text_value`, nullable `int_value`, nullable `bool_value`; composite FK `(scope_id, attempt_id)` to attempts; primary key `(scope_id, attempt_id, field, ordinal)`. CHECK requires exactly one value column and matches it to `value_type`. Allowed `field` values are `selected_sound`, `expected_sound`, `choice`, `selected_word`, `expected_word`, `pair_id`, `selected_family`, `expected_family`, `word_id`, `tile_index`, `target_sound`, `expected_membership`, `selected_token_id`, and `expected_token_id`; repeated strings at distinct ordinals are allowed. Comparison relations use the typed `selected_relation` / `expected_relation` columns on `learning_attempts`.
  - `learning_attempt_evidence`: `scope_id`, `attempt_id`, `evidence_index`, `evidence_kind`, nullable `slot`, nullable `reference_id`, nullable `outcome`, nullable `source`, nullable `activity_id`, nullable `run_generation`, nullable `round`, nullable `pair_id`, nullable `ui_generation`, nullable `section_id`, nullable `item_id`, nullable `sentence_id`, nullable `audio_ref_id`, nullable `annotation_hash`, nullable `annotation_revision`, nullable `content_revision`; composite attempt FK and primary key `(scope_id, attempt_id, evidence_index)`. Family checks require ordered comparison A/B observations or sentence playback/content evidence; no audio bytes or new playback assertion.
  - `learning_command_receipts`: `scope_id`, `activity_id`, `token`, exact SQL `canonical_payload`, `before_generation`, `before_sequence`, `before_cursor_revision`, `after_generation`, `after_sequence`, `after_cursor_revision`, `commit_ordinal`, `result_activity_id`, `result_generation`, `result_sequence`, `result_cursor_revision`. Unique `(scope_id, token)` and `(scope_id, activity_id, after_generation, after_sequence)`; `canonical_payload` includes required `expectedScopeRevision`. Current latest receipt is also retained on `learning_runs` after receipt-history pruning.
  - `learning_mistakes`: `scope_id`, `family`, `activity_id`, nullable `item_id`, nullable `target_sound`, nullable `skill`, nullable `pair_id`, nullable `section_id`, nullable `sentence_id`, nullable `audio_ref_id`, nullable `annotation_hash`, nullable `annotation_revision`, `content_revision`, nullable `first_wrong_attempt_id`, nullable `latest_wrong_attempt_id`, `first_wrong_at_us`, `latest_wrong_at_us`, `failure_count`, and nullable `last_run_generation`. The immutable family identity is course `(activity_id,item_id,target_sound,skill,content_revision)`, comparison `(activity_id,pair_id,content_revision)`, or sentence hunt `(section_id,item_id,sentence_id,audio_ref_id,annotation_hash,annotation_revision,content_revision)`. First/latest attempt IDs, timestamps, failure count, and last run generation are mutable mistake values, not unique-key columns. `ux_learning_mistakes_identity` is unique on `scope_id`, `family`, and complete family identity after null normalization.
  - `learning_summaries`: `scope_id`, `family`, nullable `activity_id`, nullable `sound`, nullable `skill`, nullable `origin`, nullable `presentation`, nullable `assistance_mask`, nullable `pair_id`, nullable `section_id`, nullable `item_id`, nullable `sentence_id`, nullable `audio_ref_id`, nullable `annotation_hash`, nullable `annotation_revision`, nullable `content_revision`, `bucket`, `correct`, `total`. Course identity requires `(sound,skill,origin,presentation,assistance_mask)`, has null `activity_id` and `content_revision`, and bucket exactly `all`; comparison identity requires `(activity_id,pair_id,content_revision)` with buckets `firstInRun|repeatInRun|afterDebrief`; sentence-hunt identity requires `(section_id,item_id,sentence_id,audio_ref_id,annotation_hash,annotation_revision,content_revision)`, null `activity_id`, and buckets `firstInRun|repeatInRun|firstTeachingExposed|repeatTeachingExposed`. Family CHECKs require these columns and require unrelated-family columns null; `ux_learning_summaries_identity_bucket` is unique on `scope_id`, `family`, `bucket`, and every family-identity column after null normalization; requires `correct <= total`.
  - `learning_completions`: `scope_id`, `activity_id`, `content_revision`, `policy_kind`, `policy_revision`, `threshold_percent`, `committed_at_us`; threshold `-1` means only the current course `legacyOnePass` no-threshold policy; otherwise require `1..100`. Unique full completion identity.
  - `learning_exposure`: `scope_id`, `family`, nullable `item_id`, nullable `target_sound`, nullable `section_id`, nullable `content_revision`, nullable `presentations`, nullable `assistance_mask`. Course identity is `(scope_id, course, item_id, target_sound)`—matching `ItemContextKey`, which is scope-wide and has no activity dimension—with null `content_revision`, nonnegative `presentations`, and the exact assistance mask. Sentence-hunt identity is `(scope_id, sentence-hunt, section_id, content_revision)`, with row existence representing exposure and no count; comparison has no exposure rows. `ux_learning_exposure_identity` is unique on complete family identity after null normalization.
  - `learning_best_scores`: `scope_id`, `activity_id`, nonnegative safe `score`; primary key `(scope_id, activity_id)`.
  - `supported_sync_outbox`: `scope_id`, `event_id`, `user_id`, `course_id`, `kind`, nullable `sound`, nullable `skill`, nullable `correct`, nullable `activity`, nullable `lesson_id`, nullable `game`, nullable `score`. Unique `(scope_id, event_id)`. CHECK requires authenticated-account course scope and exactly the existing answer/lesson/score payload columns for each kind; no selected/expected values or additional wire fields.

- [ ] **Step 4: Name the indexes exactly.** Create these unique indexes:
  - `ux_learning_scopes_owner_course_family` on `learning_scopes(owner_kind, owner_id, course_id, family)`;
  - `ux_learning_content_bindings_identity` on the complete binding identity with null-normalized nullable columns;
  - `ux_learning_runs_scope_activity` on `learning_runs(scope_id, activity_id)`;
  - `ux_learning_attempts_scope_attempt` on `learning_attempts(scope_id, attempt_id)`;
  - `ux_learning_attempts_command_batch` on `learning_attempts(scope_id, activity_id, run_generation, command_sequence, batch_index)`;
  - `ux_learning_attempt_values_attempt_field_ordinal` on `learning_attempt_values(scope_id, attempt_id, field, ordinal)`;
  - `ux_learning_attempt_evidence_attempt_index` on `learning_attempt_evidence(scope_id, attempt_id, evidence_index)`;
  - `ux_learning_command_receipts_scope_token` on `learning_command_receipts(scope_id, token)`;
  - `ux_learning_command_receipts_activity_cursor` on `learning_command_receipts(scope_id, activity_id, after_generation, after_sequence)`;
  - `ux_learning_mistakes_identity` and `ux_learning_summaries_identity_bucket` on their complete family identities with null normalization;
  - `ux_learning_completions_identity` on `(scope_id, activity_id, content_revision, policy_kind, policy_revision, threshold_percent)`;
  - `ux_learning_exposure_identity` on its complete family identity with null normalization;
  - `ux_learning_best_scores_scope_activity` on `learning_best_scores(scope_id, activity_id)`;
  - `ux_supported_sync_outbox_scope_event` on `supported_sync_outbox(scope_id, event_id)`.
  Add ordered lookups `ix_learning_attempts_scope_commit_batch` on `(scope_id, commit_ordinal, activity_id, run_generation, command_sequence, batch_index)`, `ix_learning_receipts_scope_commit_ordinal` on `learning_command_receipts(scope_id, commit_ordinal, activity_id, after_generation, after_sequence)`, `ix_learning_runs_scope_cursor` on `(scope_id, activity_id, run_generation, sequence, cursor_revision)`, and `ix_supported_sync_outbox_scope_pending` on `(scope_id, event_id)`.
- [ ] **Step 5: Implement the handle and migration test hook.** Configure Drift generation; add create-v1 only, strict unknown-version refusal, verified-empty query, shared lazy handle, close, and reopen. In `learning_migration_failure_probe.dart`, open a v1 file through `LearningDatabase.forTesting(targetSchemaVersion: 2, migrationRunner: ...)`; have the callback execute `migrator.database.customStatement('CREATE TABLE migration_failure_probe (id INTEGER)')` and throw. Reopen with the production v1 constructor and assert original rows/version remain and the marker table is absent.
- [ ] **Step 6: Generate safely and run focused plus whole-app gates.** Inspect `build/` and generated-file status; run `cd frontend && dart run build_runner build` and the schema test. Then run `cd frontend && flutter analyze` and `cd frontend && flutter test`; expected: exact 13 relations/indexes/checks, unknown v99 unchanged, synthetic failure rolled back, all previous tests pass.
- [ ] **Step 7: Commit schema scope.** Stage the exact Task 3 files and commit `feat: define normalized learning schema v1`.

## Task 4: Add the shared typed SQL command coordinator

**Files:**
- Create: `frontend/lib/src/core/course/storage/learning_storage_scope.dart`, `learning_sql_transaction.dart`
- Modify: `frontend/lib/src/core/course/storage/learning_database.dart`, generated `.g.dart`
- Create: `frontend/test/unit/learning_sql_transaction_test.dart`; extend `frontend/test/support/sqlite_learning_test_harness.dart`.

**Interfaces:**
- `LearningFamily { course, comparison, sentenceHunt }` maps to exact DB strings `course`, `comparison`, `sentence-hunt`.
- `LearningStorageScope({required LearningOwner owner, required String courseId, required LearningFamily family})` maps the guest/account encoding and exact course identity.
- `LearningDatabase.ensureScope(LearningStorageScope scope) -> Future<int>` inserts the exact owner/course/family row with revision/ordinal `0` only after successful schema verification, or returns the existing scope ID; load and first-submit share this path.
- `LearningStoredReceipt({required String activityId, required String token, required String canonicalPayload, required LearningCursorPosition before, required LearningCursorPosition after, required int commitOrdinal, required String resultActivityId})`.
- `LearningSqlTransition<S,R>({required S state, required R result})`.
- `SqliteLearningProfileAdapter<S,C,R>` methods are fully typed:
  - `LearningStorageScope get scope`;
  - `String commandActivityId(C)`, `String commandToken(C)`, and `String commandCanonicalPayload(C)`;
  - `int commandAuthGeneration(C)`, `int commandExpectedScopeRevision(C)`, `LearningCursorPosition commandExpectedCursor(C)`, and `bool isStart(C)`;
  - `Future<S> loadState(LearningDatabase db, int scopeId, {required int revision, required int commitOrdinal})`;
  - `Future<LearningStoredReceipt?> findReceipt(LearningDatabase db, int scopeId, String activityId, String token)`;
  - `LearningCursorPosition? cursorFor(S state, String activityId)`;
  - `LearningSqlTransition<S,R> evaluate({required S before, required C command, required int nextRevision, required int nextCommitOrdinal, required DateTime committedAt})`;
  - `Future<void> persist(LearningDatabase db, int scopeId, S before, C command, S after)`;
  - `R duplicateResult({required S current, required C command})`.
- `SqliteLearningCommandCoordinator<S,C,R>` requires typed constructor fields `LearningDatabaseHandle database`, `SqliteLearningProfileAdapter<S,C,R> adapter`, `int authGeneration`, `LearningAuthScope Function() currentAuth`, `LearningOwner Function() backendOwner`, `DateTime Function() clock`, and optional `void Function()? onCommitted`. Its methods are `Future<S> load()`, `Future<S> retryLoad()`, `Future<R> submit(C command)`, `Future<List<SupportedCloudEvent>> readSupportedCourseEvents()`, and `Future<void> acknowledgeSupportedCourseEvents(Set<String> ids)`; the final two reject non-course scope.
- Exceptions are the existing typed classes from `course_learning_error.dart`: `LearningUnavailableException`, `LearningSaveException`, `LearningConflictException`, `LearningOwnerChangedException`, `LearningInvalidCommandException`, `LearningCorruptException`, `LearningUnsupportedVersionException`, and `LearningContentChangedException`.

- [ ] **Step 1: Write `receipt_retry_precedes_stale_scope_revision_and_changed_payload_is_invalid`, `independent_connections_commit_one_divergent_command`, `load_reads_one_consistent_normalized_snapshot`, `sql_trigger_failure_rolls_back_all_rows`, `outbox_ack_revision_conflicts_stale_snapshot_then_reloaded_command_succeeds`, and unknown-ACK tests RED against two file connections.**

```dart
final left = await openFileLearningTestDatabase(file);
final right = await openFileLearningTestDatabase(file);
await leftCoordinator.submit(commandAtRevision0);
await expectLater(rightCoordinator.submit(divergentCommandAtRevision0),
    throwsA(isA<LearningConflictException>()));
expect(await countReceipts(left), 1);
```

- [ ] **Step 2: Run the focused tests RED.** `cd frontend && flutter test test/unit/learning_sql_transaction_test.dart`; expected: missing coordinator/adapter contract.
- [ ] **Step 3: Implement scope, receipts, and lock/CAS wrappers.** Implement `LearningDatabase.ensureScope` as an exact-identity insert-on-conflict-no-op followed by selecting that row. Add `Future<int> acquireLearningScopeWriteLock(int scopeId)` as the first no-op `UPDATE learning_scopes SET revision=revision WHERE id=?` inside every learner mutation transaction; require one matching scope row. Add `Future<int> compareAndSwapLearningScope({required int scopeId, required int expectedRevision, required int expectedCommitOrdinal, required int nextRevision, required int nextCommitOrdinal})`, returning the affected-row count. Scope insert/open is unique by owner/course/family; never concatenate owner IDs.
- [ ] **Step 4: Implement receipt-first transaction order.** A public `load()` reads the scope row and every normalized relation used to rebuild typed state inside one SQLite read transaction/snapshot, so a concurrent commit cannot produce a mixed-version state. For each learner mutation, in one SQL write transaction: acquire the SQLite write lock; verify captured owner/course/family/auth generation; read the current scope revision/ordinal; look up matching retained receipt and the current run's latest receipt; return duplicate only for identical canonical payload, reject changed payload; compare required expected scope revision; load typed rows using the **old** committed revision/ordinal; compare the current activity cursor; evaluate with next revision/ordinal; persist attempt/value/evidence/checkpoint/receipt/aggregates/completion/exposure/best-score/outbox; enforce capacity; CAS exactly one scope row from the old revision/ordinal to the next values; commit. Any throw or zero-row CAS rolls back all rows. No process-wide future queue is a correctness mechanism.
- [ ] **Step 5: Implement ACK and notification semantics.** Invoke `onCommitted` after learner-command commit only and swallow observer errors. Course ACK deletes only IDs pending in this course/account scope; unknown/already-ACKed IDs are a no-op with no revision/ordinal change. A nonempty ACK increments scope revision but not learner `commit_ordinal` and emits no learner notification. Because this invalidates pre-ACK snapshots, verify that the normal conflict/reload path obtains the new scope revision before another command is prepared; do not silently accept a stale snapshot.
- [ ] **Step 6: Run focused and full gates.** Assert same-token stale-revision retry succeeds before CAS, changed payload is invalid, pruned unproven command conflicts, two actual file connections yield one commit, `load_reads_one_consistent_normalized_snapshot` cannot combine rows from opposite sides of a concurrent commit, `sql_trigger_failure_rolls_back_all_rows` leaves no partial rows, unknown ACK is a no-op, ACK ordinal is stable, and an old-snapshot command conflicts after nonempty ACK while a reloaded command succeeds. Run `cd frontend && flutter analyze` and `cd frontend && flutter test`; all must pass.
- [ ] **Step 7: Commit the coordinator.** Stage exact Task 4 paths and commit `feat: add transactional SQLite learning command core`.

## Task 5: Add inactive course SQL adapter and repository

**Files:**
- Create: `frontend/lib/src/core/course/storage/course_learning_sql_adapter.dart`, `course_learning_sql_repository.dart`, `course_learning_state_validator.dart`, `course_learning_checkpoint_codec.dart`
- Create: `frontend/test/unit/course_learning_sql_adapter_test.dart`
- Modify only the new SQL modules; do **not** change `CourseLearningRepository`'s persistence constructor or `courseLearningStoreProvider` in this task.

**Interfaces:**
- `CourseLearningSqlAdapter({required LearningScope scope, required LearningTransitionEngine transitions, required int historyLimit}) implements SqliteLearningProfileAdapter<CourseLearningState, LearningCommand, LearningCommit>`.
- `CourseLearningStateValidator.validate(CourseLearningState state, LearningRegistry registry) -> void` validates state/snapshot/content and aggregate consistency without encoding a whole document.
- `CourseLearningCheckpointCodec.encode(ActivitySnapshot snapshot) -> String`; `decode(String json, {required LearningActivityKind kind, required LearningActivityDefinition definition, required RunOptions options}) -> ActivitySnapshot`.
- `SqliteCourseLearningRepository({required LearningDatabaseHandle database, required LearningScope scope, required int authGeneration, required LearningAuthScope Function() currentAuth, required LearningOwner Function() backendOwner, required LearningTransitionEngine transitions, required DateTime Function() clock, required String Function() newToken, required Random random, required LearningCloudTransport? cloud, void Function()? onCommitted, int historyLimit = 2000}) implements CourseLearningStore`. It exposes the interface's exact `load`, `retryLoad`, `prepare`, `submit`, and `sync` signatures and returns existing `LearningCommit`/`SupportedSyncResult` types.
- SQL receipts store `CourseLearningCommandCodec.canonicalCommand(command)` (including required scope revision). When `loadState` rebuilds domain receipt objects, decode that SQL payload and populate their legacy `canonicalCommand` field using `legacyCanonicalCommand`; do not put either receipt history or SQL identity into `checkpoint_json`.
- The existing `CourseLearningRepository` remains the sole production implementation until Task 8; SQL tests instantiate `SqliteCourseLearningRepository` directly. Neither instance dual-writes nor falls back.

- [ ] **Step 1: Write the failing SQL repository test.** `course_answer_checkpoint_aggregates_and_outbox_reopen_together` starts and answers an account lesson, closes/reopens the file, and asserts selected/expected values, cursor, summary, mistake, and one existing supported answer outbox row. Also assert `prepare` captures nonzero `state.revision` into the required command field.

```dart
final command = repository.prepare(state: state, activityId: lessonId,
    action: answerAction);
expect(command.expectedScopeRevision, state.revision);
await repository.submit(command);
await database.close();
final reopened = await handle.reopen();
expect((await repository.load()).activities[lessonId]!.cursor,
    committedCursor);
expect(await answerValueRows(reopened), expectedSelectedAndExpectedValues);
```

- [ ] **Step 2: Run the focused test RED.** Run `cd frontend && flutter test test/unit/course_learning_sql_adapter_test.dart`; expected: SQL repository does not exist.
- [ ] **Step 3: Implement the independent SQL adapter/repository.** Reuse `LearningTransitionEngine` only; build a new repository and adapter alongside the preferences class. Scope revision comes from the required command field already introduced in Task 2; use `CourseLearningCommandCodec.canonicalCommand` for SQL receipts. On load, decode SQL receipt payloads and derive the unchanged legacy canonical projection for domain receipt objects; on commit, keep the SQL receipt canonical only in normalized receipt/latest-run columns. Reconstruct typed state from rows and validate before publication.
- [ ] **Step 4: Map course rows and retention.** Map each `AttemptAnswer` variant, selected/expected IDs, choices and ordered target sounds to `learning_attempt_values`; preserve batch indices and trim oldest whole command batches at 2,000 attempts. Upsert mistakes/summaries/completions/exposure/best score independently; cap each aggregate identity collection at 4,096 and retain each current activity's latest receipt. Encode only one bounded `ActivitySnapshot` in `checkpoint_json`.
- [ ] **Step 5: Preserve exact sync projection.** Reconstruct only current `SupportedCloudEvent` objects from `supported_sync_outbox`, and use coordinator transactional ACK. Keep `course_learning_sync.dart`, transport, allowlist, envelope, 100-event batching, retry, and account/course filter unchanged; comparison/sentence events remain absent.
- [ ] **Step 6: Run focused and full gates.** Run `cd frontend && flutter test test/unit/course_learning_sql_adapter_test.dart test/unit/course_learning_game_transition_test.dart test/unit/course_learning_lesson_transition_test.dart test/unit/course_learning_sync_test.dart`, then `cd frontend && flutter analyze` and `cd frontend && flutter test`. Confirm the preferences constructor and current providers are unchanged and no SQL repository is active in production.
- [ ] **Step 7: Commit course SQL staging.** Stage exact Task 5 paths and commit `feat: stage course learning SQLite repository`.

## Task 6: Add inactive comparison SQL adapter and repository

**Files:**
- Create: `frontend/lib/src/core/course/storage/comparison_learning_sql_adapter.dart`, `comparison_learning_sql_repository.dart`, `comparison_learning_storage_validator.dart`, `comparison_learning_command_codec.dart`, `comparison_learning_checkpoint_codec.dart`
- Create: `frontend/test/unit/comparison_learning_sql_adapter_test.dart`
- Modify: `frontend/lib/src/core/course/course_learning_error.dart`, `comparison_learning_codec.dart`, and `comparison_learning_store.dart` to move/retain the existing typed unavailable exception when the whole-document codec is later removed.
- Do not change `ComparisonLearningRepository`'s preferences constructor or production providers.

**Interfaces:**
- `ComparisonLearningSqlAdapter({required ComparisonProfileScope scope, required ComparisonLearningTransitionEngine transitions, required int historyLimit}) implements SqliteLearningProfileAdapter<ComparisonLearningState, ComparisonLearningCommand, ComparisonCommit>`.
- `ComparisonLearningStateValidator.validate(ComparisonLearningState state, ComparisonCatalogue catalogue) -> void`.
- `ComparisonLearningCommandCodec.canonicalCommand(ComparisonLearningCommand command) -> String` delegates to the Task 2 scope-bound canonical form; `decodeCanonicalCommand(String raw, {required ComparisonProfileScope scope, required ComparisonCatalogue catalogue}) -> ComparisonLearningCommand` and `legacyCanonicalCommand(ComparisonLearningCommand) -> String` provide typed receipt translation.
- `ComparisonLearningCheckpointCodec.encode(ComparisonCheckpoint checkpoint) -> String`; `decode(String json, {required ComparisonProfileScope scope, required String activityId, required ComparisonCatalogue catalogue, required LessonPolicy policy}) -> ComparisonCheckpoint`.
- `SqliteComparisonLearningRepository({required LearningDatabaseHandle database, required ComparisonProfileScope scope, required int authGeneration, required LearningAuthScope Function() currentAuth, required LearningOwner Function() backendOwner, required ComparisonLearningTransitionEngine transitions, required DateTime Function() clock, required String Function() newToken, void Function()? onCommitted, int historyLimit = 2000}) implements ComparisonLearningStore`.
- `ComparisonUnavailableException` moves from `comparison_learning_codec.dart` to `course_learning_error.dart`; `comparison_learning_store.dart` continues exporting the same exception name. SQL receipts keep the scope-bound canonical payload, while loaded typed domain receipts use `legacyCanonicalCommand` for compatibility with the pure transition state shape.

- [ ] **Step 1: Write the failing comparison SQL test.** `comparison_answer_evidence_and_checkpoint_reopen_from_rows` commits a start and valid A/B answer, reopens, and asserts selection/expected relation, both ordered playback observations, session, mistake, first/repeat/after-debrief summary, and completion. Also assert prepared `expectedScopeRevision` is in SQL canonical JSON.

```dart
final command = repository.prepare(state: state, activityId: catalogue.activityId,
    action: answer);
expect(command.expectedScopeRevision, state.revision);
expect(jsonDecode(ComparisonLearningCommandCodec.canonicalCommand(command))
    ['expectedScopeRevision'], state.revision);
```

- [ ] **Step 2: Run the focused test RED.** Run `cd frontend && flutter test test/unit/comparison_learning_sql_adapter_test.dart`; expected: missing SQL repository.
- [ ] **Step 3: Implement the inactive adapter/repository and typed validator.** Extract structural/content/checkpoint/receipt consistency from `ComparisonLearningCodec` into the validator; keep `ComparisonLearningTransitionEngine` as the only reducer. Map SQL receipt payloads to legacy domain receipt canonical values on load and preserve scope-bound payloads in SQL receipt rows. Map selected/expected relation and two ordered A/B evidence rows with exact reference IDs, completed outcome, observed source, activity, generation, round, pair and UI generation. Keep the legacy repository behavior unchanged and update its unavailable-exception import/export only.
- [ ] **Step 4: Persist typed rows/checkpoints and bounds.** Read/write one slot, current `ComparisonCheckpoint`, up to 2,000 attempts/receipts, pair mistakes, summary buckets and completions. Retain the latest slot receipt after history pruning; preserve summaries/completions when attempts prune; enforce 4,096 aggregate identities atomically.
- [ ] **Step 5: Run focused and full gates.** Run `cd frontend && flutter test test/unit/comparison_learning_sql_adapter_test.dart test/unit/comparison_learning_transition_test.dart`, then `cd frontend && flutter analyze` and `cd frontend && flutter test`. Confirm no comparison cloud outbox/event exists and production injection remains the legacy class.
- [ ] **Step 6: Commit comparison SQL staging.** Stage exact Task 6 paths and commit `feat: stage comparison learning SQLite repository`.

## Task 7: Add inactive sentence-hunt SQL adapter and repository

**Files:**
- Create: `frontend/lib/src/core/course/storage/sentence_hunt_learning_sql_adapter.dart`, `sentence_hunt_learning_sql_repository.dart`, `sentence_hunt_learning_storage_validator.dart`, `sentence_hunt_learning_command_codec.dart`, `sentence_hunt_learning_checkpoint_codec.dart`
- Create: `frontend/test/unit/sentence_hunt_learning_sql_adapter_test.dart`
- Do not change `SentenceHuntLearningRepository`'s preferences constructor or production provider.

**Interfaces:**
- `SentenceHuntLearningSqlAdapter({required SentenceHuntProfileScope scope, required SentenceHuntTransitionEngine transitions, required int historyLimit}) implements SqliteLearningProfileAdapter<SentenceHuntLearningState, SentenceHuntLearningCommand, SentenceHuntCommit>`.
- `SentenceHuntLearningStateValidator.validate(SentenceHuntLearningState state, SentenceHuntCatalogue catalogue) -> void`.
- `SentenceHuntCommandCodec.canonicalCommand(SentenceHuntLearningCommand command) -> String` uses the Task 2 scope-bound form; `decodeCanonicalCommand(String raw, {required SentenceHuntProfileScope scope, required SentenceHuntCatalogue catalogue}) -> SentenceHuntLearningCommand` and `legacyCanonicalCommand(SentenceHuntLearningCommand) -> String` provide typed receipt translation.
- `SentenceHuntCheckpointCodec.encode(SentenceHuntCheckpoint checkpoint) -> String`; `decode(String json, {required SentenceHuntProfileScope scope, required String sectionId, required SentenceHuntCatalogue catalogue, required SentenceHuntRunMode mode, required bool finished, required LessonPolicy policy, required int runStartRound}) -> SentenceHuntCheckpoint`.
- `SqliteSentenceHuntLearningRepository({required LearningDatabaseHandle database, required SentenceHuntProfileScope scope, required int authGeneration, required LearningAuthScope Function() currentAuth, required LearningOwner Function() backendOwner, required SentenceHuntTransitionEngine transitions, required DateTime Function() clock, required String Function() newToken, void Function()? onCommitted, int historyLimit = 2000}) implements SentenceHuntLearningStore`.

- [ ] **Step 1: Write the failing sentence-hunt SQL test.** `sentence_answer_values_playback_identity_and_checkpoint_reopen_together` commits a start and valid answer, reopens, then asserts ordered selected/expected token IDs, exact reviewed-recording/reference/annotation evidence, session position, summary and unresolved mistake. Assert SQL canonical JSON binds required scope revision.

```dart
final command = repository.prepare(state: state, sectionId: sectionId,
    action: answer);
expect(command.expectedScopeRevision, state.revision);
await repository.submit(command);
expect((await reopenedRepository.load()).slots[sectionId]!.cursor,
    committedCursor);
```

- [ ] **Step 2: Run the focused test RED.** Run `cd frontend && flutter test test/unit/sentence_hunt_learning_sql_adapter_test.dart`; expected: missing SQL adapter/repository.
- [ ] **Step 3: Extract validator, command codec, and checkpoint codec.** Move structural/content/annotation/receipt-chain/checkpoint/aggregate-subset validation out of `SentenceHuntLearningCodec` without whole-profile JSON. SQL receipt payloads retain `expectedScopeRevision`; when loading domain receipts, decode each payload and derive the unchanged legacy command projection. Preserve current/historical section fingerprint, canonical selection and playback provenance. Keep the legacy repository unchanged.
- [ ] **Step 4: Map sentence rows and preserve run metadata.** Store selected/expected IDs as ordered values; playback/reference/outcome/source, section/item/sentence/audio-reference identity, annotation hash/revision, content revision, round and UI generation as evidence. Store `SentenceHuntCheckpoint.runStartRound` in `learning_runs.run_start_round`; restore up to the three current section slots. Enforce 2,000 attempt/receipt and 4,096 aggregate limits while retaining each slot's latest receipt.
- [ ] **Step 5: Run focused and full gates.** Run `cd frontend && flutter test test/unit/sentence_hunt_learning_sql_adapter_test.dart test/unit/sentence_hunt_learning_transition_test.dart test/unit/sentence_hunt_progress_summary_test.dart`, then `cd frontend && flutter analyze` and `cd frontend && flutter test`. Confirm no sentence-hunt cloud outbox/event and no active provider switch.
- [ ] **Step 6: Commit sentence-hunt SQL staging.** Stage exact Task 7 paths and commit `feat: stage sentence-hunt learning SQLite repository`.

## Task 8: Atomically switch all production providers to SQL

**Files:**
- Modify: `frontend/lib/src/core/course/course_learning_providers.dart`, `sentence_hunt_learning_providers.dart`
- Modify the existing loading/unavailable/verified-empty branches only: `frontend/lib/src/features/home/home_screen.dart`, `frontend/lib/src/features/course/course_progress_screen.dart`
- Modify: `frontend/test/unit/course_learning_providers_test.dart`, `comparison_learning_providers_test.dart`, `sentence_hunt_learning_providers_test.dart`, `frontend/test/widget/course_learning_progress_test.dart`, `sentence_hunt_entry_flow_test.dart`, `comparison_entry_flow_test.dart`, `course_learning_cutover_test.dart`
- Do not delete legacy repository classes in this task; Task 10 owns their removal.

**Interfaces:**
- Add `learningDatabaseHandleProvider = Provider<LearningDatabaseHandle>(...)` in `course_learning_providers.dart`; it lazily owns exactly one `LearningDatabaseHandle` per ProviderContainer and closes it on disposal.
- `courseLearningStoreProvider`, `comparisonLearningStoreProvider`, and `sentenceHuntLearningStoreProvider` retain their existing interface types but each constructs its corresponding `Sqlite*Repository` with the same handle. The `learningPersistenceProvider` is removed from production provider wiring in this task; no provider selects both implementations.

- [ ] **Step 1: Write cutover tests RED.** Add `all_three_repositories_share_one_app_database_handle` to `frontend/test/unit/course_learning_providers_test.dart`, `aba_write_stays_in_captured_scope` to `frontend/test/unit/course_learning_commit_isolation_test.dart`, and widget tests in `frontend/test/widget/course_learning_progress_test.dart`, `sentence_hunt_entry_flow_test.dart`, `comparison_entry_flow_test.dart`, and `course_learning_cutover_test.dart` for loading/unavailable versus verified-empty, retry, no restored playback/hearing/timer/microphone/autoplay state, unrelated preferences, and a stale pre-ACK snapshot showing the standard conflict/reload path rather than crediting a command. In the ABA test, hold read/write across A→B→A and sign-out; assert only captured owner rows change and no stale callback notifies the replacement provider.

```dart
final tempDir = await Directory.systemTemp.createTemp('learning-sqlite-test-');
final file = File('${tempDir.path}/phoneme_learning.sqlite');
const legacyLearningSentinelKey = 'course.learning.v2.sentinel';
const legacyLearningSentinelValue = '{leave-this-value-alone}';
SharedPreferences.setMockInitialValues(<String, Object>{
  'theme': 'dark',
  legacyLearningSentinelKey: legacyLearningSentinelValue,
});
final unrelatedPreferences = await SharedPreferences.getInstance();
final db = await openFileLearningTestDatabase(file);
var testDatabaseOpenCount = 0;
final testHandle = LearningDatabaseHandle(open: () async {
  testDatabaseOpenCount++;
  return db;
});
final container = ProviderContainer(overrides: [
  learningDatabaseHandleProvider.overrideWithValue(testHandle),
]);
addTearDown(() async {
  container.dispose();
  await testHandle.close();
  await tempDir.delete(recursive: true);
});
final handle = container.read(learningDatabaseHandleProvider);
await Future.wait([
  container.read(courseLearningStoreProvider).load(),
  container.read(comparisonLearningStoreProvider).load(),
  container.read(sentenceHuntLearningStoreProvider.future)
      .then((store) => store.load()),
]);
expect(container.read(learningDatabaseHandleProvider), same(handle));
expect(testDatabaseOpenCount, 1);
expect(await familyNamesInOneScope(db), <String>{
  'course', 'comparison', 'sentence-hunt',
});
expect(await unrelatedPreferences.getString('theme'), 'dark');
expect(await unrelatedPreferences.getString(legacyLearningSentinelKey),
    legacyLearningSentinelValue);
```

- [ ] **Step 2: Run provider/widget tests RED.** Run `cd frontend && flutter test test/unit/course_learning_providers_test.dart test/unit/comparison_learning_providers_test.dart test/unit/sentence_hunt_learning_providers_test.dart test/unit/course_learning_commit_isolation_test.dart test/widget/course_learning_progress_test.dart test/widget/sentence_hunt_entry_flow_test.dart test/widget/comparison_entry_flow_test.dart test/widget/course_learning_cutover_test.dart`; expected: providers still construct preferences repositories and fail shared-handle assertions.
- [ ] **Step 3: Add one app-scoped handle provider and switch all three providers in the same change.** Remove production `learningPersistenceProvider` wiring and update every override in the exact Task 8 provider/widget files to override `learningDatabaseHandleProvider` with a file-backed test database. Inject the shared handle into each SQL repository for course, comparison, and sentence hunt. Preserve async catalogue acquisition, auth-generation capture/recheck, backend-owner check and post-commit notification fence.
- [ ] **Step 4: Preserve visible loading/error/empty behavior.** Show zero/not-started only after successful SQL open, schema validation and empty query. Retry reopens the same handle; failed open/query stays unavailable. Invalidate state only after a successful reload.
- [ ] **Step 5: Run focused and full gates.** Run the exact provider/widget test command from Step 2, then `cd frontend && flutter analyze` and `cd frontend && flutter test`. Inspect production provider graph and assert exactly one selected SQL repository per family and no preferences repository construction.
- [ ] **Step 6: Commit the atomic cutover.** Stage only Task 8 paths and commit `feat: cut learning providers over to shared SQLite`.

## Task 9: Qualify real native/web behavior, restart, and full retention

**Files:**
- Create: `frontend/integration_test/learning_database_native_test.dart`
- Extend: `frontend/integration_test/learning_database_web_test.dart`, `learning_database_qualification_app.dart`, `frontend/integration_test/support/learning_database_workload.dart`, `frontend/integration_test/learning_storage_qualification_runbook.md`, `frontend/test_driver/integration_test.dart`
- Create: `frontend/test/unit/learning_sql_retention_test.dart`, `learning_sql_recovery_test.dart`
- Create/modify: `frontend/test/widget/course_learning_cutover_test.dart`
- No dependency on Docker, services, deployment-header changes, or isolated browser contexts.

**Test entrypoints and bindings:**
- Native and web integration test `main()` begins with `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`.
- `frontend/test_driver/integration_test.dart` contains `import 'package:integration_test/integration_test_driver.dart'; Future<void> main() => integrationDriver();`.
- Native device commands from `frontend/`: `flutter test integration_test/learning_database_native_test.dart -d <android-device-id>` and `flutter test integration_test/learning_database_native_test.dart -d <ios-device-id>`.
- Browser integration command: `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/learning_database_web_test.dart -d chrome`.
- `learning_database_workload.dart` exports `Future<void> seedLearningAtRetentionLimits(LearningDatabaseHandle handle, {required String runId})` and `Future<LearningWorkloadReport> verifyLearningAtRetentionLimits(LearningDatabaseHandle handle, {required String runId})`; all platforms use the same deterministic fixture and run ID, including the largest current typed answer/evidence payloads. Where shipped content cannot produce 4,096 distinct valid identities, use test-only synthetic registries/catalogues that pass the real validators; do not change shipped content or bypass validation. Overflow tests add one valid new identity to each applicable collection at its cap. `LearningWorkloadReport` includes per-family/per-collection row counts, SQLite logical page bytes, open/load/write durations, prune result and overflow result. Logical page bytes are not a quota/capacity guarantee.
- The qualification app derives the isolated test-only account owner `LearningOwner.account('sqlite-qualification-$runId')`, uses course `en-fr`, and sets matching ready auth/backend scopes without a network/cloud transport. It shows backend name and `runId` in keys `learning-storage-backend` and `learning-storage-run-id`; exposes test-only buttons with keys `learning-storage-seed-retention`, `learning-storage-verify-retention`, `learning-storage-prepare-command-a`, `learning-storage-prepare-command-b`, `learning-storage-submit-command-a`, `learning-storage-submit-command-b`, and `learning-storage-replay-frozen-command`; exposes frozen canonical JSON in `learning-storage-frozen-command` for copy/paste between tabs; and renders result/cursor/counts in `learning-storage-result`. A test-only submit mode commits then discards the returned acknowledgment. It uses the production SQL repositories and scope isolation, not a fake or alternate writer.
- The owned runbook starts the native qualification app with `cd frontend && flutter run -d <device-id> -t integration_test/learning_database_qualification_app.dart --dart-define=learningRunId=<unique-run-id>`. Android restart uses `adb -s <serial> shell am force-stop com.example.phoneme_app`, then `adb -s <serial> shell monkey -p com.example.phoneme_app 1`; iOS Simulator restart uses `xcrun simctl terminate <simulator-udid> com.example.phonemeApp`, then `xcrun simctl launch <simulator-udid> com.example.phonemeApp`. For physical iOS, close and reopen the same installed app through the app switcher. It records the visible run ID/report before and after restart and explicitly forbids uninstall/clear-data/new-profile actions between them.

- [ ] **Step 1: Add file-backed limit and recovery tests RED.** `all_families_reopen_at_limits_without_summary_drift` seeds each family at 2,000 retained attempts/receipts and each applicable 4,096-identity aggregate cap, closes/reopens, loads, commits/prunes and asserts exact counts in each collection, latest receipts, summaries/mistakes/completions/exposure and atomic overflow. `injected_sql_failure_rolls_back_and_lost_ack_retry_is_once` installs family-appropriate test-only triggers after normalized answer data has begun persisting (course attempt/value rows; comparison and sentence-hunt attempt/evidence rows) and before all command effects complete; verifies rollback after reopen, then commits while dropping the caller acknowledgment and replays the exact token/payload through an independent connection; exactly one attempt and applicable aggregate/completion remain, with a single outbox event only for a supported course command. Add changed-payload invalidation, changed content/policy checkpoint rejection without rewriting old attempts/completions, unknown version, and unknown ACK assertions.

```dart
expect(await attemptCount(db, scope), 2000);
expect(await receiptCount(db, scope), 2000);
expect(await aggregateCount(db, scope), 4096);
final attemptsBeforeRetry = await attemptCount(db, retryScope);
expect(await replaySameFrozenCommand(otherConnection), isDuplicate);
expect(await attemptCount(db, retryScope), attemptsBeforeRetry + 1);
```

- [ ] **Step 2: Run RED tests and implement only evidence-backed defects.** Run `cd frontend && flutter test test/unit/learning_sql_retention_test.dart test/unit/learning_sql_recovery_test.dart`. Use SQL triggers/file reopen/typed row validation; do not restore the blob, legacy preferences writer, or fallback. Keep test fixtures deterministic and shared with integration entrypoints.
- [ ] **Step 3: Run native integration on actual Android and iOS targets.** Run each exact `flutter test ... -d <device-id>` command above. Tests use the app-private DB and background `NativeDatabase.createBackgroundConnection(..., readPool: 0)`. Exercise two independent DB connections with divergent same-revision commands and assert one commit/one conflict; also commit one command while dropping its result and replay that exact frozen token/payload through the second connection, asserting one attempt. Run the max-retention fixture on each target and record report bytes/timings. In a widget integration test, keep an animation/heartbeat active during open plus max-workload load; fail if no frames advance or a heartbeat gap exceeds 250 ms. Then follow the owned runbook: build/run `learning_database_qualification_app.dart` with a unique `runId`, seed/write and verify the report, stop the app without clearing data, relaunch the same installed app, and verify the same rows/report. Android commands: `adb -s <serial> shell am force-stop com.example.phoneme_app`, then `adb -s <serial> shell monkey -p com.example.phoneme_app 1`. iOS Simulator commands: `xcrun simctl terminate <simulator-udid> com.example.phonemeApp`, then `xcrun simctl launch <simulator-udid> com.example.phonemeApp`; on physical iOS use the app switcher to close and relaunch the installed app. Do not uninstall, clear app data, or use a new install between write and verify. A Linux host/file test is not native iOS/Android evidence.
- [ ] **Step 4: Run web integration and same-profile manual qualification.** Run the exact `flutter drive` command above, then run the qualification app at the actual same-origin deployment if available. Follow `frontend/integration_test/learning_storage_qualification_runbook.md`; for repeatable local qualification start `flutter run -d web-server -t integration_test/learning_database_qualification_app.dart --web-hostname 127.0.0.1 --web-port 7357` and launch a dedicated previously unused profile at `/tmp/opencode/learning-storage-profile-task9-<unique-run-id>` to `http://127.0.0.1:7357/?runId=<unique-run-id>`. Both tabs use the same run ID/test-owner scope. For cross-tab conflict and lost-ack replay, use the course family: load the same scope snapshot in both tabs and prepare divergent commands before either submits; assert one commit/one conflict plus cross-tab visibility. Then tab A commits in discard-ack mode; copy the exact frozen JSON shown in `learning-storage-frozen-command` into tab B's replay input and retry it; assert one attempt for the retry fixture scope. The shared full-retention fixture covers all three families. Close all browser windows and verify Chrome exited, relaunch the same command/profile, and verify rows/counts/receipt/checkpoint. Do not use separate Playwright BrowserContexts or delete/reuse an existing profile.
- [ ] **Step 5: Verify deployment/backend and record unrun failure gates.** Assert actual `chosenImplementation` is allowed, worker/WASM loads, WASM response MIME is `application/wasm`, and same-profile restart works. For the existing deployed origin, record `curl -fsSI` headers for the page and WASM, CSP/resource policy, COOP/COEP and auth-popup behavior without changing services/headers. Attempt a real quota/storage-denial path only when safe; if it cannot be exercised, mark it OPEN. SQL trigger failure is tested, but it does not substitute for browser quota denial.
- [ ] **Step 6: Run SQL qualification plus domain/wire and whole-app gates.** Run the two SQL tests from Step 2 and the native/web integration commands from Steps 3–4 against SQL. Run existing course, comparison, sentence-hunt, sync and widget suites as currently wired; unconverted tests may still exercise the retained preferences repositories until Task 10. Then run `cd frontend && flutter analyze` and `cd frontend && flutter test`. Task 10 repeats these gates after all callers are converted to SQL. Record per-target OPEN/PASS evidence; an unrun platform remains unsupported and no capacity claim is allowed.
- [ ] **Step 7: Commit qualification evidence/tests.** Stage exact Task 9 paths and commit `test: qualify SQLite learning retention and recovery`.

## Task 10: Remove the obsolete preferences writer and whole-document runtime

**Files:**
- Delete: `frontend/lib/src/core/course/course_learning_persistence.dart`, `course_learning_transaction.dart`, `course_learning_codec.dart`, `comparison_learning_codec.dart`, `sentence_hunt_learning_codec.dart`
- Modify to retain only typed store interfaces/result types: `frontend/lib/src/core/course/course_learning_store.dart`, `comparison_learning_store.dart`, `sentence_hunt_learning_store.dart`; their SQL repositories remain in the Task 5–7 storage files.
- Keep: `learning_storage_types.dart`, `course_learning_error.dart`, SQL command/checkpoint codecs, SQL validators, providers, and transitions.
- Delete obsolete helpers: `frontend/test/support/course_learning_persistence_fakes.dart`, `course_learning_preferences_harness.dart`; convert `frontend/test/support/sentence_hunt_harness.dart` to the file-backed SQL helper.
- Convert exact widget callers: `frontend/test/widget/course_learning_game_commit_test.dart`, `course_curriculum_migration_test.dart`, `course_learning_lesson_drill_commit_test.dart`, `course_learning_drill_repeat_test.dart`, `course_learning_quarantine_recovery_test.dart`, `course_learning_cutover_test.dart`, `comparison_lesson_screen_test.dart`, `comparison_entry_flow_test.dart`, `sentence_hunt_entry_flow_test.dart`, and `discovery_lesson_test.dart`.
- Convert exact unit callers: `frontend/test/unit/course_learning_discovery_contract_test.dart`, `course_learning_store_test.dart`, `sentence_hunt_learning_transition_test.dart`, `comparison_learning_transition_test.dart`, `sentence_hunt_learning_codec_test.dart`, `course_learning_retention_test.dart`, `comparison_learning_codec_test.dart`, `comparison_learning_providers_test.dart`, `progress_commit_isolation_test.dart`, `sentence_hunt_progress_summary_test.dart`, `sentence_hunt_learning_store_test.dart`, `sentence_hunt_learning_providers_test.dart`, `sentence_hunt_controller_test.dart`, `course_learning_commit_isolation_test.dart`, `course_learning_sync_test.dart`, `comparison_learning_store_test.dart`, and `course_learning_providers_test.dart`.
- Convert exact additional sentence-hunt harness consumers whose fail/hold assertions must become SQL-trigger/transaction assertions: `frontend/test/widget/sentence_hunt_lesson_screen_test.dart`.
- Migrate exact preferences-harness importers to the SQL harness: `frontend/test/unit/lesson_section_progress_integrity_test.dart`, `lesson_section_store_test.dart`, `course_arcade_test.dart`, and `course_sync_test.dart`; `progress_commit_isolation_test.dart` is already listed above.
- Modify: `frontend/test/support/course_learning_widget_store.dart` to stop calling the removed whole-document codec while retaining its widget-facing typed store behavior.
- Modify: `frontend/lib/src/core/course/course_learning_transition.dart` to use the retained `CourseLearningCommandCodec.legacyCanonicalCommand` instead of the deleted whole-document codec; keep its transition rules and output unchanged.
- Preserve `LearningScope.storageKey`, `ComparisonProfileScope.storageKey`, and `SentenceHuntProfileScope.storageKey` unchanged where they seed stable attempt/event IDs or current identity tests. These strings are not SQLite paths or preferences access; do not alter IDs in `course_learning_transition.dart` or `course_learning_sync.dart`.
- Replace legacy document-codec tests with SQL command/checkpoint/validator tests in `frontend/test/unit/course_learning_codec_test.dart`, `comparison_learning_codec_test.dart`, and `sentence_hunt_learning_codec_test.dart`; delete these three files only after the replacement assertions pass.

**Interfaces:**
- The three `*LearningStore` interfaces and their existing typed `*Commit` result classes remain in their current paths. Production providers select only `SqliteCourseLearningRepository`, `SqliteComparisonLearningRepository`, and `SqliteSentenceHuntLearningRepository` from Tasks 5–8.
- `LearningCursorPosition`, `LearningReceiptIdentity`, and `LearningRetainedReceiptIdentity` are imported from `learning_storage_types.dart`; no runtime/test import may refer to `course_learning_transaction.dart` after its deletion.

- [ ] **Step 1: Inventory references before editing.** Run `git grep -n -w -E 'LearningPersistence|PreferencesLearningPersistence|LearningTransactionCoordinator|LearningTransactionKernel|LearningProfileAdapter|LearningDocumentEnvelope|LearningTransactionTransition|LearningDocumentFamily|CourseLearningRepository|ComparisonLearningRepository|SentenceHuntLearningRepository|LearningDocumentCodec|ComparisonLearningCodec|SentenceHuntLearningCodec|learningPersistenceProvider' -- frontend/lib frontend/test`. The `-w` flag distinguishes removed class names from the new `Sqlite*Repository` and `SqliteLearningProfileAdapter` names. Before editing, verify every direct persistence/codec caller is in the exact Task 10 paths above; this is a bounded task, so any additional caller not listed blocks cleanup and must be separately reviewed rather than added implicitly. Keep stable scope-key identity strings used by event/attempt IDs and tests; they must not lead to a preferences read/write.
- [ ] **Step 2: Convert each remaining test/harness to SQL.** Replace preferences fakes with `openFileLearningTestDatabase`; run repository and provider assertions through the SQL repositories. Keep test coverage for exact retry, changed payload, stale cursor, rollback, whole-batch trim, independent summaries, owner fencing, sync allowlist/ACK, audio provenance and no legacy-preference reads/writes. Replace preferences-only rollback tests with the Task 9 trigger/reopen test. Remove only old full-document codec assertions already replaced in Tasks 5–7.
- [ ] **Step 3: Remove dead runtime after reference proof.** Remove the legacy preferences classes/coordinator and legacy repositories/adapters. Retain the typed store interfaces/result classes, `ComparisonUnavailableException` in `course_learning_error.dart`, sentence-hunt exceptions in `sentence_hunt_learning_state.dart`, and shared storage types. Remove whole-profile codecs only after transitions/SQL paths reference the extracted command/checkpoint codecs and validators. Run the exact `git grep` command again; expected: no runtime/test references to removed persistence/coordinator/whole-document codec symbols. A separate `git grep -n 'course\.learning\.' -- frontend/lib frontend/test` may still show the unchanged scope-key strings used to preserve stable event/attempt IDs and an explicit untouched-preferences sentinel test; none may be used by a learning persistence read/write. Old preference values remain untouched and unrelated SharedPreferences code remains.
- [ ] **Step 4: Run final safe generation and all tests.** Inspect generated files and run `cd frontend && dart run build_runner build`; then `cd frontend && flutter analyze` and `cd frontend && flutter test`. Expected: clean generated outputs, zero analyzer issues, all runnable tests pass. Separately report native/browser/denial/header/capacity evidence as PASS or OPEN; never infer platform support from a build or file-backed test.
- [ ] **Step 5: Commit exact cleanup paths only.** Stage individually named Task 10 files from the reviewed diff (no directories/globs) and commit `refactor: remove legacy learning preferences storage`.

## Execution and Review Handoff

This plan remains **proposed and unapproved for execution**. The intended future implementation sequence is one scoped task/PR at a time, based on the latest published `origin/main`, with an independent read-only review and whole-app verification before the controller proceeds. No worker spawns nested agents or merges. If Task 1's candidate solver, generated probe, exact artifacts, selected backend, same-profile two-tab smoke, or browser restart gate fails/unavailable, stop for a concrete decision before Task 2. Never silently change storage, weaken required scope-revision fields, switch an individual family early, or claim unrun native/browser/capacity gates.

After Task 10, the controller independently reviews each exact PR head/base, available checks/reviews, native/browser evidence, and unresolved gates. French/content/audio/licensing/privacy/assessment/release approvals remain separate. No implementation, dependency resolution, platform qualification, SQLite capacity result, or release acceptance is claimed by this plan.
