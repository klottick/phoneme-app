# Dedicated /u/–/y/ Comparison Planet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan one task at a time. The current execution choice is sequential GPT-6 Luna implementation workers with controller review; do not begin until the user separately approves this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing planned `comparison` body into a dedicated, resumable best-effort `/u/`–`/y/` practice destination without changing mixed comparison or discovery progress.

**Architecture:** Register the new comparison catalogue beside the existing mixed catalogue, then extend the existing comparison state and SQL adapter to use activity-keyed run slots in the same owner/course/family scope and transaction coordinator. Route and map layers resolve the registered catalogue and project only that activity's state; no parallel writer, schema migration, hard lock, or completion transfer is introduced.

**Tech Stack:** Flutter 3.47.7, Dart 3.13.5, Riverpod, GoRouter, Drift/SQLite, existing `LessonSectionSession`, audio-grant and SQL transaction machinery.

**Spec:** [approved design](../specs/2026-10-23-uy-demo-comparison-design.md)

## Global Constraints

- New activity ID and section ID are both `en-fr-u-y-comparison`; content revision is `1`; pair IDs are `uy-demo-pair-01` … `uy-demo-pair-10`.
- Use exactly the ten rows in spec §3. Every target is at zero-based phoneme ordinal `1`; every row is `ContentPurpose.practice` and `ContentReviewState.pending`; relations/notes are explicit; answer keys are five Same and five Different.
- Preserve the existing mixed activity `en-fr-phoneme-comparison`, its pair IDs/catalogue/checkpoints/run/evidence/completion/routes, the discovery IDs/revision/progress, storage key, and exact canonical mixed command bytes.
- Preserve existing discovery/mixed recovery and settings routes, all map destinations not explicitly changed, and sentence qualification gates.
- Show exactly: “Alpha audio: recordings are unverified; device speech is practice-only.”
- Show exactly: “Demo practice: this authored comparison content has not had qualified French review. It is practice, not an assessment.”
- Active instruction is exactly `Compare the vowel in each sample.` with neutral A/B controls and Same/Different; spelling, meaning, IPA, phoneme identity, key and note stay hidden until saved debrief.
- Use the existing `LessonPolicy` default of 80% and saved threshold. Only acknowledged Finish on an eligible current-revision practice run records this activity's completion; review Finish does not.
- Keep both live routes launchable. Main recommendation order is exactly `['discovery', 'comparison']`; mixed comparison remains optional and separate. Never claim whole-course completion, mastery, or a course percentage.
- Keep one comparison family scope, SQL writer/coordinator and existing schema. `ux_learning_runs_scope_activity` is the existing unique index, not a table composite primary key. No migration, second writer/profile, partial-row recovery, quarantine, downgrade guarantee, or user-data reset.
- Preserve recording-first playback, no TTS substitution on covered-recording failure, owner/lifecycle fences, saved ACK/retry, map motion and viewport pause, light/dark appearance, keyboard/semantics, 48px controls and narrow/large-text behavior.
- Keep candidates pending and metadata/assets untouched. Automated/browser/audio-technical checks do not qualify French, rights, real playback, assessment, assistive technology, privacy or release.

## Review Focus

1. Two activities start/answer against one scope at interleaved times: each keeps its own cursor/checkpoint and a stale sibling scope revision conflicts/reloads — Task 3's SQLite test asserts both slots, global ordinals and unchanged sibling checkpoint bytes.
2. A pre-upgrade mixed profile with a corrupt or unknown comparison-family row is not treated as empty, skipped or rewritten — Task 3 snapshots normalized rows/canonical bytes around the failed read and proves other family scopes remain loadable.
3. A registered-but-unavailable dedicated catalogue differs from both an unknown activity and an empty profile with a persisted dedicated binding — Tasks 1, 3 and 5 assert local unavailability on empty state, fail-closed family handling for an unvalidatable persisted binding, and unchanged rows.
4. Owner changes during B playback or frozen-save retry cannot answer/commit with the new owner or retain A/B grants — Task 4's controlled-audio test asserts no stale submit and unchanged owner-scoped rows.
5. Debrief, route review and map inspection do not transfer completion or move the learner — Tasks 4–5 assert hidden active content, saved authored notes only at debrief, review Finish without new completion, inspection without navigation/write, dedicated start/resume/review routing, unchanged mixed open/review routes, and no sibling/discovery credit.

---

## Owned-file map

| Paths | Responsibility |
| --- | --- |
| `frontend/lib/src/core/course/comparison_content.dart`, `french_comparison_content.dart` | Dedicated ID, authored catalogue loader, immutable registered/available catalogue lookup; existing mixed ID/loader unchanged. |
| `frontend/lib/src/core/course/comparison_learning_state.dart`, `comparison_learning_command.dart`, `comparison_learning_transition.dart`, `storage/comparison_learning_command_codec.dart`, `storage/comparison_learning_checkpoint_codec.dart`, `storage/comparison_learning_storage_validator.dart` | Activity-keyed domain slots, per-activity cursor/content validation, preserved legacy mixed accessor and command shape. |
| `frontend/lib/src/core/course/storage/comparison_learning_sql_adapter.dart`, `storage/comparison_learning_sql_repository.dart`, `course_learning_providers.dart`, `frontend/test/support/course_learning_widget_store.dart` | One registry-backed SQL repository/provider and test harness; normalized rows remain in the existing shared transaction. |
| `frontend/lib/src/routing/app_router.dart`, `frontend/lib/src/features/course/comparison_lesson_screen.dart` | Exact activity route and shared screen/session flow, resolving only the requested registered catalogue. |
| `frontend/lib/src/features/course_map/course_map_catalogue.dart`, `french_space_map.dart`, `course_map_projection.dart`, `course_map_providers.dart`, `course_map_screen.dart`, `course_destination_panel.dart`, `frontend/lib/src/routing/course_map_navigation.dart`, `frontend/lib/src/features/course/comparison_progress_summary.dart` | Typed dedicated target, honest main-order/progress projection, recovery and navigation. |
| `frontend/test/unit/comparison_content_test.dart`, create `comparison_catalogue_registry_test.dart`, `comparison_multi_activity_codec_test.dart`, `comparison_learning_multi_activity_sql_test.dart`; extend existing comparison/map unit and widget tests; create `frontend/integration_test/uy_demo_comparison_browser_test.dart` | Exact catalogue, byte/state/SQLite/router/map regressions and one real-browser route flow with controlled fake audio. |

Do not edit `learning_database.dart`, generated schema, audio manifests/assets, dependency files, cloud/outbox code, discovery implementation or unrelated map destinations. The SQL index/schema and course/sentence family writers are read-only references.

## Shared interfaces (define once; use unchanged downstream)

- Task 1 adds `const String uyDemoComparisonActivityId = 'en-fr-u-y-comparison'` and `ComparisonCatalogue loadFrenchUyDemoComparisonCatalogue()`; both catalogue `activityId` and `sectionId` equal that constant, revision is `1`.
- Task 1 adds immutable `ComparisonCatalogueRegistration.available(ComparisonCatalogue catalogue)` and `.unavailable({required String activityId, required Object cause})`; `ComparisonCatalogueRegistry(Iterable<ComparisonCatalogueRegistration> registrations)` exposes immutable `Map<String, ComparisonCatalogueRegistration> byActivityId`, `registrationFor(String activityId) -> ComparisonCatalogueRegistration?`, `requireAvailable(String activityId) -> ComparisonCatalogue`, and `single(ComparisonCatalogue catalogue)` for legacy callers. Duplicate keys and mismatched registration/catalogue IDs throw `FormatException`; unknown (`null`) and registered-unavailable (non-null, `catalogue == null`) remain distinct. Task 3 validates the dedicated ID before construction and converts only an invalid dedicated registration into unavailable; mixed catalogue/registry failures still propagate.
- Task 2 preserves `ComparisonLearningTransitionEngine({ComparisonCatalogue? catalogue, ComparisonCatalogueRegistry? registry})`; exactly one argument is supplied. `registry` is the complete map; legacy `catalogue:` builds a one-entry registry. `catalogue` remains a mixed-activity getter.
- Task 2 preserves `ComparisonLearningState.slot` as `slots[comparisonActivityId]` and `checkpoint` as `slot?.checkpoint`. Add immutable `Map<String, ComparisonSlot> slots`; new callers use `slots[activityId]`. Preserve the `ComparisonLearningState({required ComparisonProfileScope scope, required int revision, required int commitOrdinal, ComparisonSlot? slot, Map<String, ComparisonSlot>? slots, required List<ComparisonPairAttempt> attempts, required List<ComparisonReceipt> receipts, required Map<ComparisonPairMistakeKey, ComparisonPairMistake> mistakes, required Map<ComparisonSummaryKey, ComparisonPairSummary> summaries, required List<ComparisonCompletion> completions})` named constructor contract; accept legacy `slot:` or new `slots:` and reject inconsistent/duplicate identities.
- Task 2 preserves `ComparisonLearningStateValidator.validate(state, catalogue)` for old mixed callers and adds `validateRegistered(state, registry)`. `ComparisonLearningCommandCodec` preserves catalogue-based decode methods and adds `decodeRegisteredCanonicalCommand(raw, {required scope, required registry})` and `decodeRegisteredLegacyCanonicalCommand(raw, {required scope, required registry})`.
- Task 3 preserves `comparisonCatalogueProvider` as the existing mixed `Provider<ComparisonCatalogue>`; adds `uyDemoComparisonCatalogueProvider` and `comparisonCatalogueRegistryProvider`. `comparisonLearningStoreProvider` constructs exactly one `SqliteComparisonLearningRepository` with the registry-backed transition engine; it does not open SQLite until load/submit.
- Task 4 preserves `ComparisonLessonScreen({key, required activityId, review = false, policy, pairId, catalogueLoader})`; its default mixed provider behavior and legacy route remain compatible. Registry lookup occurs before store acquisition; a registered unavailable activity displays local retry, unknown IDs never fall back to mixed.
- Task 3 preserves legacy `ComparisonLearningSqlTestHarness` calls while using the exact constructor `ComparisonLearningSqlTestHarness({ComparisonCatalogue? catalogue, ComparisonCatalogueRegistry? registry, required LearningAuthScope Function() currentAuth, required LearningOwner Function() backendOwner})`. It rejects both/neither `catalogue` and `registry` with `ArgumentError`, stores the resolved immutable `registry` as the authoritative field, and keeps `ComparisonCatalogue get catalogue => registry.requireAvailable(comparisonActivityId)` as the legacy mixed-catalogue getter. Legacy tests continue passing only `catalogue:`; registry tests pass only `registry:`. `createRepository` always constructs the transition engine from the resolved registry.
- Task 5 adds `MapTarget.dedicatedComparison`; `MapBodyDefinition.activityId` is exactly `uyDemoComparisonActivityId`, and map-catalogue validation requires the dedicated target to be a planet. The new target reads only `state.slots[activityId]`, that registration's catalogue and its current-revision acknowledged completion. Its not-started/resumable/completed states produce `MapLaunch.start`/`resume`/`review`; it never produces `.open`.
- Task 5 preserves `projectCourseMap`'s existing named arguments and adds optional `AsyncValue<ComparisonCatalogueRegistry>? comparisonCatalogueRegistry`; omitted legacy callers retain mixed projection while the dedicated body is unavailable, never fabricated as available. `courseMapLocation(MapTarget target, MapLaunch launch)` keeps its signature: dedicated `.start` and `.resume` map to `/course-comparison/en-fr-u-y-comparison`, dedicated `.review` maps to `/course-comparison/en-fr-u-y-comparison?review=true`, and dedicated `.open` has no route. Existing mixed `.open` and `.review` routes remain unchanged. `ComparisonProgressSummary.fromState({required state, required catalogue})` keeps its signature and derives activity identity from `catalogue.activityId`; mixed labels stay byte-for-byte the same.

## Task 1: Authored catalogue and local registry contract

**Files:**
- Modify `frontend/lib/src/core/course/comparison_content.dart`, `french_comparison_content.dart`.
- Modify `frontend/test/unit/comparison_content_test.dart`; create `frontend/test/unit/comparison_catalogue_registry_test.dart`.

**Interfaces:**
- Consumes: existing `ComparisonCatalogue.fromDrafts`, citation sequence loader and the exact inventory in approved spec §3.
- Produces: the two IDs/loader and immutable registration/registry API in Shared interfaces. Do not alter `comparisonActivityId` or `loadFrenchComparisonCatalogue()`.

- [ ] **Step 1: Write red inventory/registry tests.** In `comparison_content_test.dart`, add `uy_demo_catalogue_matches_spec_inventory_and_validates_ordinals`; compare all ten ordered `(pairId, A reference/target, B reference/target, relation, note)` tuples to spec §3 table, and assert both ordinals are `1`, revision `1`, purpose `practice`, review `pending`, ten unique IDs and 5/5 balance. Add `uy_demo_invalid_reference_ordinal_target_key_duplicate_count_or_balance_rejects_whole_catalogue` with separate mutations for unknown reference, invalid ordinal/target identity, annotation-target mismatch, invalid relation/key, duplicate ID, row count, and relation balance. In the new registry test, assert immutable lookup, duplicate rejection, and distinct unknown/unavailable results.

```dart
expect(catalogue.exercises.map((e) => e.id),
  List.generate(10, (i) => 'uy-demo-pair-${(i + 1).toString().padLeft(2, "0")}'));
expect(catalogue.exercises.where((e) => e.expectedRelation == PhonemeRelation.same), hasLength(5));
```

- [ ] **Step 2: Run RED.** From `frontend/`, run `$FLUTTER test --no-pub test/unit/comparison_content_test.dart test/unit/comparison_catalogue_registry_test.dart --reporter expanded`. Expected: missing new loader/registry and new inventory assertions fail; existing mixed tests still pass.
- [ ] **Step 3: Implement the dedicated catalogue and registry.** Add only the ID, immutable registration/registry and loader. Copy the ten rows and saved notes from spec §3 without inference, heuristic, generated relation or metadata changes. Keep mixed loader/constants byte/value-identical.
- [ ] **Step 4: Run GREEN and old behavior.** Rerun the Step 2 command; also run `$FLUTTER test --no-pub test/unit/comparison_learning_transition_test.dart test/unit/comparison_learning_store_test.dart --reporter expanded`. Expect all pass and mixed catalogue fixtures unchanged.
- [ ] **Step 5: Check, commit and publish Task 1.** Format only owned Dart paths; run `$FLUTTER analyze --no-pub` and `git diff --check`. From a scoped branch based on current published `origin/main`, run `git add frontend/lib/src/core/course/comparison_content.dart frontend/lib/src/core/course/french_comparison_content.dart frontend/test/unit/comparison_content_test.dart frontend/test/unit/comparison_catalogue_registry_test.dart` and `git commit -m "feat: register dedicated u-y comparison catalogue"`; push/open one PR to `main`, await controller review/verification/merge. Task 2 starts from that merged published `origin/main`, never this unmerged head.

## Task 2: Multi-activity domain, codecs and legacy compatibility

**Files:**
- Modify `frontend/lib/src/core/course/comparison_learning_state.dart`, `comparison_learning_command.dart`, `comparison_learning_transition.dart`, `storage/comparison_learning_command_codec.dart`, `storage/comparison_learning_checkpoint_codec.dart`, `storage/comparison_learning_storage_validator.dart`.
- Modify `frontend/test/unit/comparison_learning_transition_test.dart`, `comparison_learning_store_test.dart`; create `frontend/test/unit/comparison_multi_activity_codec_test.dart`.

**Interfaces:**
- Consumes: Task 1 `ComparisonCatalogueRegistry`, `registrationFor` and `requireAvailable`.
- Produces: the engine constructor, `state.slots` plus mixed `slot`/`checkpoint` accessors, `validateRegistered`, and registered decoder methods above. `prepare/evaluate` keep their current names and parameter/return types.

- [ ] **Step 1: Write red multi-slot and frozen-byte tests.** Add `interleaved_domain_slots_keep_activity_cursors_and_scope_ordinals`: prepare mixed and dedicated starts from the same state; assert the stale second command fails after the first advances scope revision; reprepare it and assert both independent initial cursors, slots and commit ordinals `[1, 2]`. Add `mixed_legacy_and_sql_command_bytes_and_storage_key_are_frozen`; use this exact origin/main golden and its SQL-only suffix; decoder rejects unknown activity and cross-catalogue pair/reference.

```dart
expect(state.slots.keys, containsAll([comparisonActivityId, uyDemoComparisonActivityId]));
expect(state.slot, same(state.slots[comparisonActivityId]));
expect(state.receipts.map((r) => r.commitOrdinal), [1, 2]);
const frozenMixedLegacy = '{"schemaVersion":1,"family":"comparison","courseId":"en-fr","owner":{"kind":"guest","userId":null},"authGeneration":7,"activityId":"en-fr-phoneme-comparison","generation":0,"sequence":0,"revision":0,"token":"AAAAAAAAAAAAAAAAAAAAAA","submittedAt":"2026-10-23T00:00:00.000Z","action":{"kind":"start","sessionId":"frozen-mixed-start","policy":{"completionThresholdPercent":80}}}';
expect(comparisonCanonicalCommand(mixedStart), frozenMixedLegacy);
expect(ComparisonLearningCommandCodec.canonicalCommand(mixedStart),
  '${frozenMixedLegacy.substring(0, frozenMixedLegacy.length - 1)},"expectedScopeRevision":0}');
expect(mixedStart.scope.storageKey, 'course.learning.comparison.v1.ZW4tZnI.g');
```

- [ ] **Step 2: Run RED.** Run `$FLUTTER test --no-pub test/unit/comparison_learning_transition_test.dart test/unit/comparison_learning_store_test.dart test/unit/comparison_multi_activity_codec_test.dart --reporter expanded`. Expected: the new two-activity/byte tests fail against the one-slot implementation; old tests remain green.
- [ ] **Step 3: Implement activity-keyed pure transitions and validation.** `ComparisonLearningState` stores immutable slots keyed by activity and retains the mixed getter. `prepare/evaluate` resolve the command activity's catalogue, take/replace only that slot, and require `expectedScopeRevision == state.revision`; each commit increments shared revision/commit ordinal once. Keep receipt ordinals scope-wide; validate before/after cursor continuity only against the same activity. A slot's latest receipt ordinal may be less than the profile ordinal; only the globally latest retained receipt equals the scope ordinal. Validate attempts, mistakes, summaries, completions, checkpoints and legacy receipts against their activity catalogue. New commands may carry a nonblank ID, but registry resolution rejects unknown IDs before persistence.
- [ ] **Step 4: Preserve legacy codecs and prove GREEN.** Add the registered codec methods; checkpoint validation accepts any exact matching registered activity. Do not add canonical JSON fields, reorder mixed keys, change `comparisonCanonicalCommand`, SQL canonical bytes or `ComparisonProfileScope.storageKey`. Rerun the Step 2 command plus `$FLUTTER test --no-pub test/unit/comparison_content_test.dart test/unit/comparison_learning_providers_test.dart --reporter expanded`; expect all pass.
- [ ] **Step 5: Check, commit and publish Task 2.** Format owned Dart paths; run `$FLUTTER analyze --no-pub` and `git diff --check`. From a new scoped branch based on current published `origin/main`, stage only Task 2's six source paths and three test paths from its Files block; commit `feat: support activity-keyed comparison state`, push/open one PR to `main`, and wait for guarded merge before Task 3.

## Task 3: One registry-backed SQLite adapter/provider

**Files:**
- Modify `frontend/lib/src/core/course/storage/comparison_learning_sql_adapter.dart`, `storage/comparison_learning_sql_repository.dart`, `course_learning_providers.dart`.
- Modify `frontend/test/support/course_learning_widget_store.dart`, `test/unit/comparison_learning_sql_adapter_test.dart`, `comparison_learning_providers_test.dart`; create `frontend/test/unit/comparison_learning_multi_activity_sql_test.dart`.
- Read-only schema reference: `frontend/lib/src/core/course/storage/learning_database.dart:448`.

**Interfaces:**
- Consumes: Task 2 registry engine/state/validator/codecs and existing `SqliteLearningCommandCoordinator` contract, including `commandExpectedScopeRevision` and `cursorFor(state, activityId)`.
- Produces: one `SqliteComparisonLearningRepository` over one `ComparisonLearningSqlAdapter`; `cursorFor` reads `state.slots[activityId]`, `duplicateResult` returns that slot, and writes touch only the submitted activity run.

- [ ] **Step 1: Write red real-SQL tests.** Extend `ComparisonLearningSqlTestHarness` using the exact signature and exactly-one-of `catalogue:`/`registry:` contract in Shared interfaces. Keep every existing `catalogue:` call source-compatible; new multi-activity tests construct it with only `registry:`. Assert the constructor rejects both and neither inputs, and that the legacy `catalogue` getter resolves the mixed entry. In `comparison_learning_multi_activity_sql_test.dart`, use the real repository/SQLite handle to test `interleaved_activity_commands_keep_independent_sql_slots_and_scope_fence`, `failed_frozen_command_retries_once_and_ack_survives_reopen_for_each_activity`, `preupgrade_mixed_rows_and_canonical_bytes_load_without_rewrite`, `unknown_comparison_row_fails_closed_without_mutation`, and `unavailable_registration_empty_vs_persisted_binding`. Include two independent finishes/reviews, held receipt-insert failure, exact-command retry/duplicate ACK, owner isolation, and SQL assertions that both `learning_runs` rows coexist under the existing unique index.

```dart
expect(reloaded.slots.keys, containsAll([comparisonActivityId, uyDemoComparisonActivityId]));
expect(reloaded.slots[comparisonActivityId]!.checkpoint.sessionJson, mixedCheckpointBefore);
expect(reloaded.commitOrdinal, greaterThan(reloaded.slots[comparisonActivityId]!.latestReceipt.commitOrdinal));
```

- [ ] **Step 2: Run RED.** Run `$FLUTTER test --no-pub test/unit/comparison_learning_multi_activity_sql_test.dart test/unit/comparison_learning_sql_adapter_test.dart test/unit/comparison_learning_providers_test.dart --reporter expanded`. Expected: SQL adapter rejects the second run/activity; no schema change is allowed to make this pass.
- [ ] **Step 3: Adapt the existing adapter and activate the registry.** Load every run row into `slots[activityId]`; resolve every run/binding/attempt/evidence/mistake/summary/completion/receipt against that activity's catalogue. Preflight all persisted activity identities: a registered-but-unavailable activity with persisted data raises `LearningContentChangedException` before generic validation wrapping; unknown IDs raise `LearningCorruptException`. Keep all rows in one validated snapshot; never skip or manufacture an empty profile. Upsert only the command's run via existing `(scope_id, activity_id)` uniqueness; preserve other slots, scope revision fence and global ordinal. Per-slot latest receipt may precede the current scope ordinal; compare cursor chains only within an activity. Keep transaction coordinator, table schema/indexes, owner scope, storage key and canonical mixed payload unchanged.
- [ ] **Step 4: Pin registration-error versus family-corruption policy and run GREEN.** `comparisonCatalogueProvider` stays the mixed provider. Before building the registry, validate the new catalogue's exact dedicated ID/section; convert only its validation, mismatched-ID or duplicate registration failure to `unavailable(activityId: uyDemoComparisonActivityId, cause: error)`. Do not catch a mixed catalogue failure or mask a registry failure involving the mixed entry. The mixed catalogue and mixed-only empty profile remain usable, and a start for the unavailable activity fails before a write. A persisted row/binding for a registered-but-unavailable activity throws `LearningContentChangedException` and fails closed for the shared comparison family; an unknown/unrecognized persisted activity throws `LearningCorruptException`. In both cases retain every raw row/byte; do not partially load, skip, or rewrite. Unknown profile corruption must not block discovery/sentence family providers. Rerun Step 2 plus `$FLUTTER test --no-pub test/unit/learning_database_schema_test.dart test/unit/course_learning_providers_test.dart test/unit/sentence_hunt_learning_providers_test.dart --reporter expanded`; expect all pass and no schema diff.
- [ ] **Step 5: Check, commit and publish Task 3.** Format owned Dart paths; run `$FLUTTER analyze --no-pub` and `git diff --check`. From a new scoped branch based on current published `origin/main`, stage only Task 3's three source paths, test harness, two existing tests and new SQL test from its Files block; commit `feat: persist independent comparison activity runs`, push/open one PR to `main`, and wait for controller verification/merge before Task 4.

## Task 4: Shared screen and exact typed route

**Files:**
- Modify `frontend/lib/src/routing/app_router.dart`, `frontend/lib/src/features/course/comparison_lesson_screen.dart`.
- Modify `frontend/test/widget/comparison_lesson_screen_test.dart`, `comparison_entry_flow_test.dart`, `comparison_section_debrief_test.dart`.

**Interfaces:**
- Consumes: Task 3 `comparisonCatalogueRegistryProvider`, unchanged `ComparisonLearningStore` methods and Task 2 `state.slots[activityId]`.
- Produces: `/course-comparison/en-fr-u-y-comparison` into the existing shared `ComparisonLessonScreen`; no new screen/session/store or route alias. Constructor and existing mixed `/course-comparison/en-fr-phoneme-comparison` and `/compare` behavior remain unchanged.

- [ ] **Step 1: Write red production-router/widget tests.** Add `uy_demo_route_uses_exact_catalogue_and_rejects_unknown_or_duplicate_query_before_store`: exercise `LinguistApp`/`appRouterProvider`, assert `?pairId=uy-demo-pair-01` and singleton `review=true|false` resolve only in the dedicated catalogue; reject an unknown activity, unknown query key, invalid `review` value, duplicated `pairId`, duplicate `review`, and foreign/mixed `?pairId=fr07b-pair-01` before store acquisition or audio request. Preserve the existing query contract: only one `review=true|false` and one `pairId` are accepted; duplicates/unknowns never fall through to mixed. Add `uy_demo_active_prompt_hides_authored_answers_until_saved_debrief` and `uy_demo_owner_change_during_sample_b_and_frozen_retry_has_no_stale_submit` using the existing controlled audio and file-backed SQL fixture.

```dart
expect(router.state.uri.path, '/course-comparison/en-fr-u-y-comparison');
expect(storeProviderReads, 0);
expect(databaseOpenCalls, 0);
expect(audio.requests, isEmpty, reason: 'invalid route is rejected before acquisition');
```

- [ ] **Step 2: Run RED.** Run `$FLUTTER test --no-pub test/widget/comparison_lesson_screen_test.dart test/widget/comparison_entry_flow_test.dart test/widget/comparison_section_debrief_test.dart --reporter expanded`. Expected: new exact route/content/lifecycle assertions fail; old mixed-route and `/compare` tests remain green.
- [ ] **Step 3: Resolve the exact registration before store load.** Router rejects unknown IDs and repeated/unknown query keys/values before constructing the store/screen; registered-unavailable content reaches the shared screen's local unavailable/retry state without store acquisition. Select the requested catalogue and validate `pairId` against only its `byId`; do not use the mixed regex/catalogue as a fallback. Screen loads/resumes only `loaded.slots[widget.activityId]`; all cursor, observation, checkpoint, retry and finish operations keep that activity ID.
- [ ] **Step 4: Add only dedicated disclosure/presentation and run GREEN.** Display the exact demo disclosure before starting and keep the existing exact alpha disclosure wherever audio is offered. The active UI exposes only the specified neutral instruction and controls. Existing debrief reveals only saved applicable notes in authored order; saved score/threshold remain policy-driven. Keep A-then-B successful recording grants, cancellation/replay, background/route pause, owner replacement, frozen ACK/retry and review `recordCompletion: false`. Rerun Step 2 plus `$FLUTTER test --no-pub test/unit/comparison_learning_transition_test.dart test/unit/comparison_learning_multi_activity_sql_test.dart --reporter expanded`; expect all pass.
- [ ] **Step 5: Check, commit and publish Task 4.** Format owned Dart paths; run `$FLUTTER analyze --no-pub` and `git diff --check`. From a new scoped branch based on current published `origin/main`, stage only Task 4's two source and three test paths from its Files block; commit `feat: route dedicated comparison activity`, push/open one PR to `main`, and await guarded merge before map work.

## Task 5: Dedicated map binding, projection and integrated browser acceptance

**Files:**
- Modify `frontend/lib/src/features/course_map/course_map_catalogue.dart`, `french_space_map.dart`, `course_map_projection.dart`, `course_map_providers.dart`, `course_map_screen.dart`, `course_destination_panel.dart`, `frontend/lib/src/routing/course_map_navigation.dart`, `frontend/lib/src/features/course/comparison_progress_summary.dart`.
- Modify `frontend/test/unit/course_map_catalogue_test.dart`, `course_map_projection_test.dart`, `course_map_providers_test.dart`, `frontend/test/widget/course_map_navigation_test.dart`, `course_map_integration_test.dart`, `course_map_accessibility_test.dart`; create `frontend/integration_test/uy_demo_comparison_browser_test.dart`.

**Interfaces:**
- Consumes: Task 1 registration IDs/lookup; Task 3 registry provider and shared SQL state; Task 4 exact comparison route. Mixed target/navigation and all old map IDs remain intact.
- Produces: `MapTarget.dedicatedComparison`; body `comparison` is a live required planet bound to `uyDemoComparisonActivityId`; `mainOrder == ['discovery', 'comparison']`; projection uses only that activity's registration/slot/current-revision completion.

- [ ] **Step 1: Write red map and browser tests.** Add exact map assertions for discovery/comparison main order, typed dedicated planet binding, unchanged mixed station, still-planned context/spelling/checkpoint, and activity-local launch states. Assert inspection performs no navigation/write; dedicated start/resume/review map to their fixed route, while the existing mixed `.open`/`.review` mappings and query remain unchanged. Assert the dedicated target never emits `.open`. Add projection cases for not-started/resumable/current-revision-completed, invalid new registration with empty profile versus persisted binding, family corruption leaving discovery/sentence independent, and sibling completion not affecting this planet. In `uy_demo_comparison_browser_test.dart`, use the production router and real web SQL with controlled fake audio to record one A/B answer, dispose the provider container and database handle, recreate them in the same browser page/profile, and assert the dedicated checkpoint resumes and mixed state is unchanged. Keep held/failed ACK and exact retry coverage in Task 3's file-backed SQL tests and lifecycle/owner-fence coverage in Task 4's controlled widget tests; this browser test does not replace those. The browser test is an in-page provider/database reopen, not a browser/page reload; do not use real audio.

```dart
expect(system.mainOrder, ['discovery', 'comparison']);
expect(comparison.definition.target, MapTarget.dedicatedComparison);
expect(comparison.definition.activityId, uyDemoComparisonActivityId);
expect(comparison.launch, MapLaunch.start); // not-started; resume/review are also asserted
expect(courseMapLocation(MapTarget.dedicatedComparison, MapLaunch.start),
    '/course-comparison/en-fr-u-y-comparison');
expect(courseMapLocation(MapTarget.dedicatedComparison, MapLaunch.resume),
    '/course-comparison/en-fr-u-y-comparison');
expect(courseMapLocation(MapTarget.dedicatedComparison, MapLaunch.review),
    '/course-comparison/en-fr-u-y-comparison?review=true');
expect(courseMapLocation(MapTarget.dedicatedComparison, MapLaunch.open), isNull);
expect(mixed.definition.target, MapTarget.mixedComparison);
expect(courseMapLocation(MapTarget.mixedComparison, MapLaunch.open),
    '/course-comparison/en-fr-phoneme-comparison');
expect(courseMapLocation(MapTarget.mixedComparison, MapLaunch.review),
    '/course-comparison/en-fr-phoneme-comparison?review=true');
```

- [ ] **Step 2: Run RED.** Run `$FLUTTER test --no-pub test/unit/course_map_catalogue_test.dart test/unit/course_map_projection_test.dart test/unit/course_map_providers_test.dart test/widget/course_map_navigation_test.dart test/widget/course_map_integration_test.dart test/widget/course_map_accessibility_test.dart --reporter expanded`. Expected: missing target/order/role/dedicated projection assertions fail; discovery and mixed baseline assertions stay green. Also run the Step 5 WebDriver integration command against the new browser test before implementation; the driver must start and the test must reach a behavioral failure for the unavailable new map/route, not a browser/driver setup failure. Preserve the raw RED log; if the environment prevents reaching the assertion, record it as not-run/open rather than claiming a RED result.
- [ ] **Step 3: Add typed map target and activity-local projection.** Change only the existing `comparison` body from planned to live; validate the dedicated target as a planet bound exactly to `uyDemoComparisonActivityId`, independently of catalogue availability, while the existing mixed target remains a station bound exactly to `comparisonActivityId`. Render the exact demo disclosure on this planet. Resolve registration by activity ID. A registered-invalid new catalogue yields a dedicated local unavailable/retry body while mixed remains valid on an empty profile; a shared-family read failure may make both comparison bodies unavailable but leaves discovery/sentence independent. Completed is only its own acknowledged current-revision completion; resumable reads only its own valid slot/checkpoint. Not-started/resumable/completed map to `.start`/`.resume`/`.review`, never `.open`; selection remains inspection only. Do not add a prerequisite, transfer credit, or rewrite route destinations.
- [ ] **Step 4: Make map counts/navigation honest and run focused GREEN.** Map selection remains inspection only. Dedicated `.start` and `.resume` go to `/course-comparison/en-fr-u-y-comparison`; `.review` goes to that fixed route with `?review=true`; no dedicated `.open` action is offered. Show dedicated action labels (“Start comparison”, “Continue comparison”, “Review comparison”) without changing mixed `.open` (“Open destination”) or mixed `.review` (“Review comparison”) behavior. Progress counts only available authored main activities, labels dedicated pair counts as `/u/`–`/y/` comparison, leaves optional mixed counts separate, and retains visible “Coming soon” context/spelling/checkpoint. Preserve map animation, pause, light/dark, focus/semantics and 48px controls. Rerun Step 2 plus `$FLUTTER test --no-pub test/widget/comparison_entry_flow_test.dart test/widget/course_map_owner_recovery_test.dart test/widget/course_map_motion_test.dart --reporter expanded`.
- [ ] **Step 5: Run the web integration gate with the verified WebDriver path.** No new dependency is required. Do not use `-d chrome`: that device path did not reach the debug service in this environment. Follow `frontend/integration_test/learning_storage_qualification_runbook.md`'s Web Server/WebDriver pattern, reusing `test_driver/integration_test.dart`. From `frontend/`, set `CHROME_BIN` and `CHROMEDRIVER_BIN` to installed version-matching absolute executable paths and choose a dedicated free `DRIVER_PORT` (use `4445` only if the loopback port is free; if occupied, choose another free port and do not stop/replace its owner). Confirm the browser/driver versions, start only the owned ChromeDriver process with loopback access, bound the drive run to 10 minutes, and stop only that captured PID in an `EXIT` trap. Do not reuse a human Chrome profile; let WebDriver use its fresh automation profile. Preserve the raw command output and ChromeDriver log under unique `.superpowers/uy-mini-course-design/` evidence filenames.

```bash
# From frontend/. Set absolute paths to installed, version-matching executables.
set -euo pipefail
FLUTTER=/home/klottick/develop/flutter-3.47.7-sqlite/bin/flutter
CHROME_BIN=/absolute/path/to/installed/chrome
CHROMEDRIVER_BIN=/absolute/path/to/matching/chromedriver
DRIVER_PORT=4445
RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)-$$
DRIVER_LOG=../.superpowers/uy-mini-course-design/task-5-chromedriver-$RUN_ID.log
"$CHROME_BIN" --version
"$CHROMEDRIVER_BIN" --version
if ss -H -ltn "sport = :$DRIVER_PORT" | grep -q .; then
  echo "ChromeDriver port $DRIVER_PORT is occupied; choose another free port." >&2
  exit 1
fi
"$CHROMEDRIVER_BIN" --port="$DRIVER_PORT" --allowed-ips=127.0.0.1 \
  >"$DRIVER_LOG" 2>&1 &
DRIVER_PID=$!
trap 'kill "$DRIVER_PID" 2>/dev/null || true; wait "$DRIVER_PID" 2>/dev/null || true' EXIT
ready=false
for _ in $(seq 1 40); do
  if curl --fail --silent "http://127.0.0.1:$DRIVER_PORT/status" |
      python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)["value"]["ready"] else 1)'; then
    ready=true
    break
  fi
  sleep 0.25
done
test "$ready" = true
PATH="/home/klottick/develop/flutter-3.47.7-sqlite/bin:$PATH" \
CHROME_EXECUTABLE="$CHROME_BIN" timeout 10m "$FLUTTER" drive \
  --driver=test_driver/integration_test.dart \
  --driver-port="$DRIVER_PORT" \
  --chrome-binary="$CHROME_BIN" \
  --target=integration_test/uy_demo_comparison_browser_test.dart \
  -d web-server 2>&1 | tee "../.superpowers/uy-mini-course-design/task-5-web-integration-$RUN_ID.log"
```

Expected: ChromeDriver `/status` reports `value.ready == true`; `flutter drive` exits 0 and reports the browser integration test passed; the test asserts one fake-audio answer, provider/database close-and-reopen, dedicated checkpoint resume, unchanged mixed state, and invalid/unknown route rejection without store acquisition. This is real web-SQL/provider-reopen evidence, not a full browser/page reload or real-audio evidence.
- [ ] **Step 6: Check, commit and publish Task 5.** Format owned Dart paths; run `$FLUTTER analyze --no-pub` and `git diff --check`. From a new scoped branch based on current published `origin/main`, stage only Task 5's eight source, six existing widget/unit tests and browser test from its Files block; commit `feat: add dedicated comparison planet to map`, push/open the final scoped PR to `main`; controller independently reviews exact head/base and gates before guarded merge.

## Verification and publication gates

Set the approved SDK paths; commands below run from the stated directories:

```bash
FLUTTER=/home/klottick/develop/flutter-3.47.7-sqlite/bin/flutter
DART=/home/klottick/develop/flutter-3.47.7-sqlite/bin/dart
```

- Each task PR: focused tests and named affected-neighbor tests in its task; `$FLUTTER analyze --no-pub`; `git diff --check`; `$DART format --output=none --set-exit-if-changed <owned Dart paths>`. Capture actual output; no historical counts are new evidence.
- Final ordinary unit/widget suite, from `frontend/`, explicitly enumerate only the top-level `*_test.dart` files in `test/unit` and `test/widget`, excluding exactly `course_learning_retention_test.dart` and `learning_sql_retention_test.dart`. Use the bounded original Python enumeration (not recursive `find`), save both the printed sorted file list and unfiltered stdout/stderr/exit status, and do not accidentally add integration or new test roots:

```bash
set -o pipefail
RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)-$$
python3 - <<'PY' 2>&1 | tee "../.superpowers/uy-mini-course-design/task-5-ordinary-tests-$RUN_ID.log"
from pathlib import Path
import subprocess
excluded = {'course_learning_retention_test.dart', 'learning_sql_retention_test.dart'}
files = sorted(str(p) for root in ('test/unit', 'test/widget')
               for p in Path(root).glob('*_test.dart') if p.name not in excluded)
assert files
print('\n'.join(files), flush=True)
subprocess.run(['/home/klottick/develop/flutter-3.47.7-sqlite/bin/flutter',
                'test', '--no-pub', '--reporter', 'expanded', *files], check=True)
PY
```

Expected: Python/test command exits 0 and all explicitly enumerated files pass.
Deferred platform/storage stress and integration device qualification are not
silently added; record the exact two exclusions.

- Final static/build gates, from `frontend/`: `$FLUTTER analyze --no-pub`; `$FLUTTER build web --release --no-pub` (default JavaScript build, not Wasm).
- Web integration gate, from `frontend/`: the Task 5 `flutter drive ... -d web-server` WebDriver command. It uses controlled fake audio and real web SQL for one answer plus in-page provider/database close-and-reopen; it is not real playback or browser-reload evidence.
- Read-only audio technical verifier, from repository root: `python3 scripts/verify_french_audio.py --repo-root .`. Expect only technical/metadata verification of pending candidates; do not promote status or claim linguistic/rights/device qualification.
- Keep the existing unrelated Sound Match work, `.playwright-mcp/`, other branches/worktrees and durable records untouched. The historical 1,622 frontend pass baseline is not a fresh run and must not be repeated as evidence.
- After Task 5 is reviewed and merged, controller fast-forwards a clean primary checkout to published `main` and runs `python3 scripts/local_demo.py update --flutter /home/klottick/develop/flutter-3.47.7-sqlite/bin/flutter`; preserve hosted-demo origin/config/progress/prior releases. Verify `demo-build.json` and the production-JavaScript map/lesson. For the separate controller Playwright gate, set `WEB_PORT=8095`; check `ss -H -ltn "sport = :$WEB_PORT"` and, if occupied, choose another free port without stopping/replacing its owner. Serve `build/local-demo/current` from a separate terminal at repository root with `timeout 15m python3 -m http.server --bind 127.0.0.1 --directory build/local-demo/current "$WEB_PORT"`. Use the same origin and a fresh run-specific profile under `/tmp/opencode`; assert it does not exist and neither reuse nor clear/delete it (do not use the human profile or `.playwright-mcp/`). Through the map UI, activate “Start comparison”, wait for the first neutral prompt/initial checkpoint save without using audio, and record both `window.location.href` and the visible lesson. Do not assume `context.push` changes the browser href. Reload that exact recorded href. If it remains `/#/home`, assert the home projection shows the new comparison run in progress; select the planet, activate “Continue comparison”, and verify the initial prompt/checkpoint returns with the same saved run/checkpoint/receipt position and no new learning command. If the actual href is the dedicated route, verify its prompt/checkpoint resumes after that reload. Separately, in the same profile/origin, directly navigate to `/#/course-comparison/en-fr-u-y-comparison` for the known saved checkpoint, record that actual href, reload that same direct URL, and verify the checkpoint resumes. Capture both actual hrefs and the visible UI before/after each reload; do not claim that map `context.push` rewrites the address, change URL strategy/routing, play real audio, or reset storage. No automatic qualification, public release, or data-wiping rollback.

## Plan self-review

- **Spec coverage:** §1–2 preservation/scope, registry errors and family corruption: Tasks 1–3. §3 inventory, metadata, prompt/disclosure/debrief/audio gates: Tasks 1 and 4. §4 routing, typed map binding, independent state/progress/recovery and no hard lock: Tasks 3–5. §5 acceptance/preservation and verification: all tasks plus final gates. §6 pending linguistic/rights/playback/accessibility/privacy/release gates remain explicit.
- **Step scan:** Every task starts with named failing assertions, has a red command, an implementation boundary, green focused/neighbor commands and scoped publication. No product code is included in this documentation change.
- **Type consistency:** Registry/registration names, `registry:` engine constructor, `slots[activityId]`, legacy mixed `slot`, registered validator/codec, exact one-of catalogue/registry test harness constructor, and dedicated map start/resume/review actions are defined above and reused consistently.
- **Review Focus:** All five conditions map to explicit SQLite, provider, widget/router or map/browser assertions in the owning task.
- **Browser gates:** Flutter WebDriver integration and controller production-JavaScript Playwright reload are separate complementary gates; no in-process test claims a full page reload.
- **Browser href behavior:** The production gate records the actual href and rendered lesson after map launch, reloads that exact href, handles a retained `/home` projection with Continue comparison, and separately verifies direct dedicated-route reload. It makes no assumption that imperative `context.push` reflects in `window.location.href` and does not change shared URL strategy or mixed routing.
- **Verification scope:** Ordinary unit/widget enumeration is bounded to the two original roots and excludes only the named retention suites; raw list and output are retained. No bare `flutter test` or native/full retention gate is implied.
- **Proportion:** The plan reuses the exact spec inventory table by reference rather than copying it; test snippets are assertions, not a solution transcript. The execution note sends shared constraints/interfaces/review focus with each assigned task rather than duplicating the full plan.

**Execution boundary:** This is a plan only. Human review/approval is required before any Task 1 product-code work. Execute with one sequential GPT-6 Luna implementation subagent at a time; workers do not spawn subagents or merge PRs, and the controller independently reviews/verifies and merges only through the guarded PR process. Dependent tasks start only from the preceding merged `origin/main`.

**Worker execution note:** For each handoff, give the assigned worker the exact text of **Global Constraints**, **Shared interfaces**, and **Review Focus** verbatim as binding context, plus only that worker's task section, its owned-file/interface contract, and acceptance steps. Keep tasks sequential on the preceding published merge; do not copy or reissue the full plan, and do not begin any worker task before separate human approval of this plan.
