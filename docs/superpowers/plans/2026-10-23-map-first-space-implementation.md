# Map-first Space Course Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (standing repository execution method) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the approved phone-first orbital journey in front of the existing French discovery pilot without inventing content, unlocks, or progress.

**Architecture:** An authored presentation catalogue binds map bodies to existing activities. A read-only projection consumes the current owner's committed providers; widgets separately own inspection and decorative motion. Existing routes and controllers remain authoritative, with scoped course appearance and root navigation added at their boundaries.

**Tech Stack:** Existing Flutter/Dart, Riverpod 2, go_router 14, Flutter test; existing SQLite learning stores. No new package, font, image service, backend, or schema.

**Spec:** [Approved map-first space-course design](../specs/2026-10-23-map-first-space-course-design.md), approved in the controlling conversation and merged through [PR #101](https://github.com/klottick/phoneme-app/pull/101), merge `66c2e7934324326af0aea1753a8f98137f6fd3cf`.

**Plan status:** approved by the user before product-code execution and published
in PR #102. User subsequently changed the implementation worker choice from
Qwen to GPT-6 Luna; no further Qwen workers were used. The scoped FR-11-A
implementation and Home/router/theme integration were reviewed and merged in
PRs #103–108. See the [delivery status](../status/2026-10-23-map-first-space-course.md).
This plan does not claim full FR-11/FR-18 or close the remaining content,
assessment, platform, accessibility, privacy, or release gates.
The original planning baseline was published `origin/main` at the design merge;
each implementation PR was based on its preceding published merge.

## Global Constraints

- Phone-first solar-system view, not a winding path through lesson buttons.
- Individually authored routes; orbital distance does not establish lesson order.
- First-delivery policy: do not introduce new progression locks on existing live activities.
- The initial system has presentation ID `en-fr-u-y-system`; discovery maps to `lesson:en-fr-u-y` and `/course-lesson/en-fr-u-y`.
- Existing mixed comparison is optional cross-system alpha practice, not a dedicated `/u/`–`/y/` lesson. Sentence qualification remains enforced.
- Only acknowledged durable completion updates map markers. Unknown data is not “not started.”
- No storage schemas, migrations, second progress store, cloud download/merge, recording uploads, revised completion thresholds, or new content.
- Preserve all existing course/lesson/section/item/audio/owner identities, validated direct links, legacy access, audio disclosures, timers, and recovery controls.
- Use 390×844 as the primary reference; verify 360×640 and 2×/3× text. Interactive targets are at least 48×48 logical pixels.
- One ship lap takes approximately 34 seconds. Inspection does not travel, launch audio, or write progress.
- Honor reduced motion and explicit pause; stop tickers when covered, hidden, paused, or disposed. No new persisted motion/navigation setting.
- Preserve Light/Dark/System and `theme_mode`. Midnight-blue artwork in both appearances; approved course controls in dark appearance only.
- Exact palette: canvas `#172231`, background `#142131`, panel `#1D2C40`, raised `#213349`, border `#3C4C62`, action `#68428A`, selected `#513367`, ship `#70438F`, current ring `#9461BA`, primary text `#F3F5F9`, secondary text `#B9C8DB`.
- Purple means identity/selection/action, not correctness. Keep natural planets, warm starlight, semantic success/error, and quieter exercises.
- Preserve unpublished Sound Match work, user files, worktrees, and durable evidence; no automatic cleanup or direct `main` push.

## Review Focus

1. Async refresh retaining old data, especially guest→A→B→A: no previous-owner completion, ship cue, feedback, or counts (Task 2 and Task 5).
2. Mixed-family failure: broken comparison/sentence data cannot hide discovery, fabricate empty progress, or remove recovery access (Task 2 and Task 5).
3. Valid debrief/review checkpoint versus acknowledged Finish: Continue preserves phase, while completion remains durable and revision-aware (Task 2 and Task 5).
4. Tiny viewport/large text/keyboard: inspection and launch remain separate and reachable; the linear list is not a decorative afterthought (Task 3 and Task 5).
5. Covered map, platform reduce-motion changes, and saved light preference: stop animation without disabling navigation or recoloring legacy tools (Task 4 and Task 6).

## Execution and file map

Use **six sequential implementation PRs**, one per task below. Start each from
current published `origin/main` only after the previous PR is independently
reviewed and merged. Tasks 1–4 add tested components without changing Home;
Task 5 connects them; Task 6 finishes scoped course appearance and integrated
verification. These are parts of one navigation feature, not separate curriculum
projects. Do not report the map delivery complete after infrastructure-only PRs.

The controller dispatches one `ollama/qwen3.8:27b` implementer at a time with the
task, exact owned files, dependency PRs and acceptance criteria. Workers do not
spawn agents or merge. Each task requires red/green evidence, a scoped commit,
push and PR against `main`; the controller obtains independent code review and
runs applicable checks on exact head/current base before normal guarded merge.
If the chosen worker is unavailable, ask rather than substitute silently.

Owned file groups (all relative to repository root):

| Task | Files / responsibility |
| --- | --- |
| 1 | New `frontend/lib/src/features/course_map/course_map_catalogue.dart`, `french_space_map.dart`: immutable metadata, typed bindings, validation, authored layout. New unit catalogue tests. |
| 2 | New `course_map_state.dart`, `course_map_projection.dart`, `course_map_providers.dart` in that directory: detached state, projection, existing-provider adapter. New projection/provider tests. |
| 3 | New `course_system_view.dart`, `course_map_canvas.dart`, `course_destination_panel.dart`, `course_destination_list.dart`, `course_star_chart_view.dart` in that directory: static responsive/semantic presentation. New `frontend/lib/src/core/theme/space_course_colors.dart`: exact semantic colors. New view/accessibility tests. |
| 4 | New `course_map_motion.dart` in that directory: lifecycle-aware decorative layer; modify `course_map_canvas.dart` only to host it. New motion tests. |
| 5 | New `course_map_screen.dart`, `course_chart_screen.dart`, `course_legacy_entries.dart` there; new `frontend/lib/src/routing/course_map_navigation.dart`, `course_root_navigation.dart`; modify `home_screen.dart`, `app_router.dart`, entry-flow tests: actual navigation/recovery integration. |
| 6 | New `frontend/lib/src/core/theme/space_course_theme.dart`; narrowly modify `app_router.dart` to apply it at supported route builders. New scoped-theme tests and final map integration test. |

Task-local file names above omit the already stated `features/course_map/`
directory only in this overview. Detailed ownership below is authoritative.
No task owns curriculum sources, stores, SQL, generated files, manifests,
game engines, lesson controllers, `DesignColors`, or theme persistence.

## Shared test and delivery convention

All Flutter commands below run with working directory `frontend/`. Use the
installed SDK and locked dependencies (`flutter pub get` if needed, never a
dependency upgrade). First record `flutter --version` and `dart --version`.
Read this plan **and** the spec, existing relevant tests, and repository
`AGENTS.md` before implementation. Failures unrelated to the task are reported,
not hidden by weaker assertions or broad source cleanup.

For each task's final step, stage only its listed owned paths, commit with its
specified message, push a scoped branch, and open a PR against `main`. Include
red/green commands/results, scope, deferred gates and any findings. Commit
commands use `git add -- <explicit owned paths>` (no blanket `git add .`).
Controller process records under `.superpowers/` retain reviewed head, exact
base, independent review, commands, GitHub checks/reviews, PR URL, merge commit,
and published-result verification. Missing CI is not passing CI.

### Task 1: Authored systems and validated destination bindings

**Files:** Create `frontend/lib/src/features/course_map/course_map_catalogue.dart`,
`frontend/lib/src/features/course_map/french_space_map.dart`, and
`frontend/test/unit/course_map_catalogue_test.dart`.

**Interfaces:**
- Produce enums `MapBodyRole { planet, moon, station, asteroidField }` and
  `MapTarget { discovery, mixedComparison, sentenceSections, review, arcade }`.
- Produce immutable `MapBodyDefinition` with named fields `String id, title,
  description`, `MapBodyRole role`, `bool optional, planned`, `MapTarget? target`,
  `String? activityId, parentId`, `List<String> prerequisites`, and normalized
  `double x, y, orbitRadius`. Constructor defensively copies collections.
- Produce immutable `MapSystemDefinition` with `String id, title, description`,
  `bool planned`, `List<MapBodyDefinition> bodies`, `List<String> mainOrder`.
- Produce `List<MapSystemDefinition> frenchSpaceSystems` and
  `MapSystemDefinition? findSpaceSystem(String id)`.
- Produce `void validateMapSystem(MapSystemDefinition system,
  {required LearningRegistry registry})`; throws `FormatException` for invalid
  metadata, without validating unrelated systems or loading learner state.

- [ ] **1. Write catalogue tests** named `initial_system_has_one_live_main_lesson`,
  `mixed_practice_is_not_a_system_lesson`, `planned_systems_have_no_launch`,
  `invalid_graph_fails_per_system`, and `orbital_position_does_not_order_learning`.
  Assert initial ID, discovery activity/target, 10 bodies, five planned bodies,
  one live main destination, and two planned chart systems. Mutate fixture graphs
  to exercise duplicate IDs, unknown prerequisite/parent/order IDs, cycles,
  required→optional prerequisites, invalid bindings, and nonfinite/out-of-range
  geometry; each throws. Permuting positions does not change `mainOrder`.

```dart
expect(findSpaceSystem('en-fr-u-y-system')!.mainOrder, ['discovery']);
expect(findSpaceSystem('not-a-system'), isNull);
expect(() => validateMapSystem(invalidSystem, registry: registry),
    throwsFormatException);
```

- [ ] **2. Run red:** `flutter test test/unit/course_map_catalogue_test.dart`.
  Expect missing new interfaces; record the failure before implementation.
- [ ] **3. Implement metadata and validator.** Use body IDs `discovery`,
  `comparison`, `context`, `spelling`, `checkpoint`, `coaching`, `review`,
  `mixed-comparison`, `sentence-practice`, `arcade`. Titles/meaning follow spec
  section 3. First five are planets; coaching is a planned optional moon of
  discovery; review/mixed/sentence are optional stations; arcade is optional.
  Planned targets/activity IDs are null. Discovery binds activity ID
  `lesson:en-fr-u-y`; mixed station binds `en-fr-phoneme-comparison` explicitly.
  Prerequisites are empty in the initial catalogue; `mainOrder` is discovery only.
  Planned chart IDs are `en-fr-nasals-system` and `en-fr-r-system`, with no bodies
  or launch. Validate discovery registry kind and `/u/`–`/y/` instructional
  coverage, exact mixed binding, target/role consistency, uniqueness and graph.
  Author stable normalized positions against the approved map image; orbits are
  illustration, never graph edges. No copied questions/answer keys or routing.
- [ ] **4. Run green:** repeat the catalogue command; all tests pass.
- [ ] **5. Publish:** commit `feat: define validated French space map catalogue`;
  obtain review/verification and merge this PR before Task 2.

### Task 2: Owner-safe read-only map projection

**Files:** Create `frontend/lib/src/features/course_map/course_map_state.dart`,
`frontend/lib/src/features/course_map/course_map_projection.dart`,
`frontend/lib/src/features/course_map/course_map_providers.dart`,
`frontend/test/unit/course_map_projection_test.dart`, and
`frontend/test/unit/course_map_providers_test.dart`.

**Interfaces:** Consume Task 1 plus existing learning/qualification providers.
- Produce `MapReadiness { alpha, planned, qualificationBlocked, loading,
  unavailable }`, `MapProgress { unknown, notStarted, resumable, completed }`,
  `MapLaunch { start, resume, review, open }`.
- `MapBodyState` contains `MapBodyDefinition definition`, `MapReadiness readiness`,
  `MapProgress progress`, `bool recommended`, `String explanation`,
  `MapLaunch? launch`, `List<String> evidenceLabels`; no mutable state/store.
- `CourseMapState` contains `String systemId`, `List<MapBodyState> bodies`,
  `String? currentBodyId`, `bool allAvailableMainComplete`, and
  `Set<String>? completedLegacyLessonIds` (null means unknown).
- Produce `CourseMapState projectCourseMap({required MapSystemDefinition system,
  required LearningAuthScope auth, required LearningRegistry registry,
  required AsyncValue<CourseLearningState> course,
  required AsyncValue<ComparisonLearningState> comparison,
  required AsyncValue<ComparisonCatalogue> comparisonCatalogue,
  required AsyncValue<SentenceHuntLearningState> sentences,
  required AsyncValue<SentenceHuntCatalogue> sentenceCatalogue})`.
- Produce `courseMapStateProvider`, a Riverpod `Provider.family<CourseMapState,
  String>` for validated live systems. Route UI handles unknown/planned systems
  before reading it. Synchronous content/registry failures become explanatory
  unavailable state for the affected family/system, never an empty profile.

- [ ] **1. Write projection tests** `unknown_is_not_empty`,
  `refresh_does_not_retain_progress`, `scope_mismatch_is_unknown`,
  `resume_preserves_exercise_debrief_and_review`,
  `only_current_discovery_threshold_completes`,
  `comparison_failure_is_local`, `sentence_qualification_dominates_progress`,
  and `recommendation_uses_authored_order_not_orbit`.
  Use existing transition/widget-store fixtures to construct valid snapshots,
  including held/failed Finish and current versus historical completion.
  A fabricated slot is not acceptable regression evidence.

```dart
expect(loading.bodies.singleWhere((b) => b.definition.id == 'discovery').progress,
    MapProgress.unknown);
expect(loading.currentBodyId, isNull);
expect(committed.currentBodyId, 'discovery');
expect(committed.allAvailableMainComplete, isTrue);
// Repeat with loading-with-previous-data, AsyncError, foreign scope,
// revision mismatch, and unfinished current-revision debrief snapshots.
```

- [ ] **2. Write provider tests** `guest_A_B_A_discards_late_results` and
  `projection_never_writes_or_starts_audio`. Override existing stores/providers
  with controlled futures/counters; change owner/generation while loads are
  pending. Assert no stale marker/count/continuation and zero command/audio calls.
- [ ] **3. Run red:** `flutter test test/unit/course_map_projection_test.dart test/unit/course_map_providers_test.dart`.
- [ ] **4. Implement projection and provider.** Check auth readiness, loading/
  refresh flags and exact scope before reading any retained async data. Use
  `CourseCompletionSummary`, `ComparisonProgressSummary`, and
  `SentenceHuntProgressSummary`; preserve their evidence labels, not a new score.
  Check `ActivitySlot` kind/revision and `DiscoveryCheckpoint.session` against
  current registry/section before treating it as resumable. Current discovery
  completion wins the marker/Review action; otherwise a valid slot gives Continue,
  including debrief/review phases; absence gives Start. Invalid/mismatched slots
  offer recovery, not Start. No main completion without committed threshold.
  Unknown discovery has no learner-location cue; loaded discovery anchors the
  ship regardless of inspected optional body. Recommendation honors resumable
  main order, then incomplete eligible main order; optional evidence never moves it.
  Sentence station may open the section selector, explicitly not an exercise,
  even when every section awaits review. Mark qualification-blocked and explain
  it; do not expose a playable section. Unavailable families keep a separate
  recovery entry at integration. Watch owner/generation and existing committed
  revision providers; do not cache projections across owners or run queries per
  animation frame. Do not invalidate/write from the pure projection.
- [ ] **5. Run green:** repeat red command; also run
  `flutter test test/unit/course_completion_summary_test.dart test/unit/sentence_hunt_progress_summary_test.dart test/unit/comparison_learning_providers_test.dart`.
- [ ] **6. Publish:** commit `feat: project owner-isolated committed map progress`;
  review and merge before Task 3.

### Task 3: Static orbital map, destination inspection, and star chart

**Files:** Create `frontend/lib/src/features/course_map/course_system_view.dart`,
`frontend/lib/src/features/course_map/course_map_canvas.dart`,
`frontend/lib/src/features/course_map/course_destination_panel.dart`,
`frontend/lib/src/features/course_map/course_destination_list.dart`,
`frontend/lib/src/features/course_map/course_star_chart_view.dart`,
`frontend/lib/src/core/theme/space_course_colors.dart`,
`frontend/test/widget/course_system_view_test.dart`,
`frontend/test/widget/course_map_accessibility_test.dart`, and
`frontend/test/widget/course_star_chart_view_test.dart`.

**Interfaces:** Consume Tasks 1–2; produce:
- `CourseSystemView({super.key, required CourseMapState state,
  required String? selectedBodyId, required ValueChanged<String> onInspect,
  required ValueChanged<MapBodyState> onLaunch})`.
- `CourseMapCanvas` takes the same state/selection/inspection inputs, no launch.
- `CourseDestinationPanel({super.key, required MapBodyState body,
  required VoidCallback? onLaunch})` and `CourseDestinationList` taking the view's
  state/selection/inspection inputs; the list inspects rather than auto-launches.
- `CourseStarChartView({super.key, required List<MapSystemDefinition> systems,
  required ValueChanged<String> onOpenSystem})`; planned systems inspect inline.
- `SpaceCourseColors` exposes static `Color` constants `canvas`, `background`,
  `panel`, `raised`, `border`, `action`, `selected`, `ship`, `currentRing`,
  `textPrimary`, `textSecondary`, in spec table order and exact hex values.

- [ ] **1. Write view tests** `inspection_is_not_launch_or_travel`,
  `planned_and_unavailable_explain_without_play`, and
  `chart_planned_system_has_no_launch`. Assert only an explicit valid action
  invokes `onLaunch`, and body inspection preserves `state.currentBodyId`.
- [ ] **2. Write accessibility/layout tests** `small_phone_large_text_actions_reachable`,
  `keyboard_inspects_then_launches`, and `destinations_announce_state_and_role`.
  Iterate 390×844 and 360×640 at text scales 1, 2, 3 plus a long title. Assert no
  framework overflow, all actions reachable by scrolling, ≥48px controls, authored
  traversal order, and text/icon state independent of opacity. Test linear-list
  inspection and a named stationary current-location cue, excluding decorative
  stars/ship painting from duplicate semantics.
- [ ] **3. Run red:** `flutter test test/widget/course_system_view_test.dart test/widget/course_map_accessibility_test.dart test/widget/course_star_chart_view_test.dart`.
- [ ] **4. Implement static widgets and colors.** Use normal Flutter text/buttons
  over stable primitive/vector bodies, not labels painted into a bitmap. Main
  view is vertically scrollable, with map followed by selected panel and an
  explicit destination-list disclosure; the panel/action is never trapped in a
  fixed-height overlay. Keep the list reachable with keyboard and screen reader.
  On tight/large-text layouts prioritize readable panel/list over shrinking text.
  Canvas stays midnight blue in light appearance; controls inherit theme.
  Fade body art, not essential status text. Keep selected ring distinct from the
  current ship indicator. Start static; no providers, route strings, audio,
  storage, or animation in these view widgets.
- [ ] **5. Run green:** repeat the three-file command and inspect rendered map
  against the durable spec screenshots (fictional image progress is not copied).
- [ ] **6. Publish:** commit `feat: render accessible orbital course destinations`;
  review and merge before Task 4.

### Task 4: Bounded, lifecycle-safe decorative motion

**Files:** Create `frontend/lib/src/features/course_map/course_map_motion.dart`
and `frontend/test/widget/course_map_motion_test.dart`; modify only
`frontend/lib/src/features/course_map/course_map_canvas.dart` to host the layer.

**Interfaces:** Produce `CourseMapMotion({super.key, required Offset? anchor,
required Widget child})`, with `static const orbitPeriod = Duration(seconds: 34)`.
Anchor is a canvas-local coordinate derived from `currentBodyId`, never selection.
This widget owns pause state/control, ship/stars/comet painting and lifecycle;
it does not own the supplied static child or learning providers.

- [ ] **1. Write tests** `orbit_is_34_seconds_and_selection_does_not_move_anchor`,
  `pause_and_each_platform_motion_flag_stop_frames`,
  `covered_background_offstage_and_disposed_stop_tickers`, and
  `animation_does_not_rebuild_learning_state`.
  Pump bounded durations, check painted ship positions at quarter-lap, use
  `FakeAccessibilityFeatures` with `disableAnimations` and `reduceMotion`
  independently, toggle while mounted, cover using both a route and modal sheet,
  background/resume, and remove widget. Assert stationary accessible location
  remains, pause is named, providers not reread per frame, no pending ticker.
- [ ] **2. Run red:** `flutter test test/widget/course_map_motion_test.dart`.
- [ ] **3. Implement motion.** Use widget-aware ticker provider, a repaint-isolated
  controller, deterministic geometry, slow low-amplitude stars and a sparse
  comet. Effective motion requires a non-null anchor, resumed app, current route,
  enabled `TickerMode`, no platform reduction and no user pause. Observe route
  currentness/coverage (including popup routes) and lifecycle changes explicitly;
  `TickerMode` alone is insufficient. Remove listeners/dispose controller.
  Reduced motion overrides Play; pause affects only decoration. Read installed
  SDK accessibility APIs, including platform `reduceMotion` separately from
  `disableAnimations`; do not assume one MediaQuery flag covers both platforms.
  Use no timers, random rebuild positions, delayed callbacks, or audio.
- [ ] **4. Run green:** motion test plus Task 3 tests; static semantics/layout
  remain unchanged. Tests that need settling explicitly reduce motion or pause;
  never make production motion conditional on test mode.
- [ ] **5. Publish:** commit `feat: add pausable lifecycle-safe map motion`;
  review and merge before Task 5.

### Task 5: Connect Home, roots, preserved tools, and recovery

**Files:** Create `frontend/lib/src/features/course_map/course_map_screen.dart`,
`frontend/lib/src/features/course_map/course_chart_screen.dart`,
`frontend/lib/src/features/course_map/course_legacy_entries.dart`,
`frontend/lib/src/routing/course_map_navigation.dart`,
`frontend/lib/src/routing/course_root_navigation.dart`,
`frontend/test/widget/course_map_navigation_test.dart`,
`frontend/test/widget/course_map_owner_recovery_test.dart`, and
`frontend/test/support/map_motion_test_support.dart`. Modify
`frontend/lib/src/features/home/home_screen.dart`,
`frontend/lib/src/routing/app_router.dart`, and the existing widget tests
`home_screen_test.dart`, `home_navigation_test.dart`, `course_flow_test.dart`,
`course_learning_cutover_test.dart`, `course_learning_progress_test.dart`,
`discovery_entry_flow_test.dart`, `discovery_lesson_test.dart`,
`legacy_navigation_test.dart`, `sentence_hunt_entry_flow_test.dart`,
`comparison_entry_flow_test.dart` under `frontend/test/widget/`.

**Interfaces:**
- `CourseMapScreen({super.key, required String systemId})` owns ephemeral selection,
  watches Task 2, and renders Task 3. Key its learner-local subtree by
  `(owner, generation, systemId)`; ready/loading transitions clear learner feedback.
- `CourseChartScreen({super.key})` consumes Task 1 and renders the chart.
- `CourseLegacyEntries({super.key, required Set<String>? completedLessonIds})`
  preserves legacy lesson links/counts and the old Practice tools disclosure.
- `String? courseMapLocation(MapTarget target, MapLaunch launch)` maps the finite
  combinations to validated existing locations (null for invalid combinations).
- `CourseRootNavigation({super.key, required String location, required Widget child})`
  hosts root tabs outside the supplied screen, with no extra app bar or exercise
  session. Repeated current-tab activation is a no-op; changes use `go`, not push.

- [ ] **1. Write route tests** `onboarding_enters_live_map`,
  `tabs_do_not_duplicate_roots`, `invalid_or_planned_system_has_safe_return`,
  `mixed_practice_keeps_its_identity`, `all_legacy_tools_remain_reachable`,
  `direct_targeted_links_keep_validation`, and `inspection_makes_no_commands`.
  Assert `/home`, `/course-chart`, `/course-system/en-fr-u-y-system`, planned and
  unknown IDs; root tabs go to exact spec routes. Open/Back/Finish real lessons
  using existing fake audio/store harnesses; games keep one session/timer and no
  bottom tabs. Invalid/duplicate comparison and sentence query parameters still
  fail, while valid targeted review still reaches its original item/pair.
- [ ] **2. Write owner/recovery tests** `guest_A_B_A_resets_inspection_and_feedback`,
  `late_retry_cannot_publish_into_new_owner`,
  `failed_finish_does_not_complete_map`, and
  `family_failures_leave_other_bodies_and_recovery_usable`.
  Capture held loads/saves with existing store fixtures; assert old raw data is
  preserved, exact retry is retained, and maps only change after durable ACK.
  Test comparison recovery and sentence-selector access while discovery fails,
  plus progress reload with retained previous data. Unknown counts remain unknown.
- [ ] **3. Run red:** `flutter test test/widget/course_map_navigation_test.dart test/widget/course_map_owner_recovery_test.dart`.
- [ ] **4. Implement adapters/screens and route wiring.** Home delegates to initial
  system; add explicit chart/system builders and safe return explanations. Keep
  all existing route validators/controllers intact. Discovery Start/Continue use
  `/course-lesson/en-fr-u-y`; Review adds `?review=true`. Mixed comparison uses
  its existing activity URL/review flag; sentence station opens sections, never
  a blocked exercise. Review/arcade retain existing routes. Only map/chart,
  course-review/progress and arcade lobby receive root navigation. No retained
  tab stacks or nested lesson/game navigators. Keep settings, all original
  non-pilot `frenchLessons`, historical markers and six Practice tools reachable
  below the map through explicit disclosures.
- [ ] **5. Implement recovery callbacks.** Keep the old Home store-aware
  `retryLoad()` behavior for discovery with captured owner/store checks after
  every await. Invalidate only the matching state provider, never reset data.
  Other failed families retain named recovery links to existing screens; sentence
  package retry invalidates its catalogue provider. Recovery controls are distinct
  from a disabled lesson launch and available while other families work.
  At activation, re-read current owner/generation and body readiness; a captured
  old callback cannot navigate on behalf of a replaced owner. Pin this with
  `launch_rechecks_current_owner_and_readiness` in the new navigation test.
- [ ] **6. Update only changed entry selectors and test motion setup.** Add
  `void disableMapMotion(WidgetTester tester)` test helper setting platform fake
  accessibility flags and registering reset teardown. Use in Home-bearing tests
  with `pumpAndSettle`; motion tests retain real bounded pumps. Update selectors
  to inspect a destination then launch. Preserve existing assertions on session
  phases, saved state, owner identity, evidence, audio cancellation and routes.
- [ ] **7. Run green:** repeat the new-test command, then
  `flutter test test/widget/home_screen_test.dart test/widget/home_navigation_test.dart test/widget/course_flow_test.dart test/widget/course_learning_cutover_test.dart test/widget/course_learning_progress_test.dart test/widget/discovery_entry_flow_test.dart test/widget/discovery_lesson_test.dart test/widget/legacy_navigation_test.dart test/widget/sentence_hunt_entry_flow_test.dart test/widget/comparison_entry_flow_test.dart test/widget/course_learning_resume_test.dart test/widget/course_learning_quarantine_recovery_test.dart test/widget/course_audio_lifecycle_test.dart test/widget/course_recording_lifecycle_test.dart test/widget/course_learning_game_commit_test.dart test/widget/arcade_switch_test.dart`.
- [ ] **8. Publish:** commit `feat: make the orbital map the course entry`;
  independently review actual diff and verify integrated routes before merging.

### Task 6: Scoped course appearance and final integrated acceptance

**Files:** Create `frontend/lib/src/core/theme/space_course_theme.dart`,
`frontend/test/widget/space_course_theme_test.dart`,
`frontend/test/widget/course_map_integration_test.dart`; modify
`frontend/lib/src/routing/app_router.dart` only for supported appearance wrappers.
If a palette defect is in Task 3's new color file, return it as a reviewed fix
there rather than changing global `DesignColors` or unrelated legacy widgets.

**Interfaces:** Consume `SpaceCourseColors`; produce
`ThemeData spaceCourseTheme(ThemeData inherited)` and
`SpaceCourseTheme({super.key, required Widget child})`. Light input returns the
existing light styling; dark input overrides semantic surfaces/actions/text and
component states using the exact approved table, keeping existing typography,
success/error meanings, and accessible focus/disabled states.

- [ ] **1. Write theme tests** `palette_is_exact_and_legacy_theme_unchanged`,
  `saved_light_dark_system_preferences_survive_navigation`, and
  `supported_routes_inherit_course_theme_not_game_boards`.
  Assert all eleven color roles, visible dark button labels, panel/secondary-text
  contrast, selection/current indicator distinction, and focus/disabled contrast.
  Start with each stored `theme_mode`, change system brightness at runtime, then
  visit map, discovery/debrief, comparison, review, progress, arcade lobby,
  settings, legacy IPA and both game boards. Only supported surfaces change;
  theme preference is not written by map navigation. Error/correctness remains
  distinguishable using text/icons, not purple.
- [ ] **2. Write integrated test** `map_journey_uses_real_committed_state`.
  Start guest with an empty valid store, inspect a planned planet, launch live
  discovery with controlled audio, reach debrief, hold/fail/retry Finish, and
  return. Assert saved phase and ACK-only marker, all-current-lessons-complete
  copy, no fictitious mastery percentage, optional practice does not move ship,
  and real blocked sentence content still cannot launch.
- [ ] **3. Run red:** `flutter test test/widget/space_course_theme_test.dart test/widget/course_map_integration_test.dart`.
- [ ] **4. Implement route-scoped theme wrapper.** Wrap Home/chart/system,
  authored discovery branch only, comparison (including recovery), review,
  progress and arcade lobby. Do not wrap the router wholesale, legacy fallback
  `CourseLessonScreen`, games, settings or tools. Keep active exercises quieter
  than map; no additional planets/particles on lesson screens. Do not replace
  controllers, help timing, correctness labels, game tiles or audio disclosure.
- [ ] **5. Run green:** repeat new-test command; then run the ordinary final
  gate below and preserve raw results. Analyze any failure before making fixes.
- [ ] **6. Browser acceptance:** build/serve the integrated JavaScript output
  with a bounded local server (use a free port, do not replace the running demo).
  From `frontend/build/web`, run `timeout 15m python3 -m http.server 8094 --bind 127.0.0.1`
  as a harness background command; choose another free port if occupied. Use
  Playwright at `http://127.0.0.1:8094/` and retain evidence under `.superpowers/`.
  At 390×844 and 360×640 inspect map, list, planned explanation, live lesson,
  back/review/progress, mixed practice, unavailable sentences and arcade lobby.
  Capture dark/light and large-text evidence, horizontal overflow, keyboard
  inspection/launch, pause, platform reduced motion and covered-map inactivity.
  Inspect actual control contrast, not screenshots alone. Audio fakes/builds
  cannot establish real playback, French quality or release qualification.
- [ ] **7. Publish:** commit `feat: apply scoped space course appearance`;
  independent reviewer checks whole delivered feature against spec plus this
  task's actual diff. Controller repeats affected gates on exact head/current
  base, checks GitHub feedback, and merges only with no blocking findings.
- [ ] **8. Verify published result:** fetch `origin/main`, confirm reviewed head
  is included and published tree matches reviewed integration. Record PRs, merge
  commits, final commands/results and remaining gates. Do not delete worktrees,
  evidence or Sound Match work. Mark FR-11-A delivered only; broader FR-11/FR-18,
  unfinished curriculum, content qualification and release remain open.

## Ordinary final verification gate

Do not run the deferred retention/stress suites as an accidental consequence of
`flutter test` with no file list. From `frontend/`, enumerate the current ordinary
unit/widget files, excluding only the two previously deferred retention files:

```python
from pathlib import Path
import subprocess
excluded = {'course_learning_retention_test.dart', 'learning_sql_retention_test.dart'}
files = sorted(str(p) for root in ('test/unit', 'test/widget')
               for p in Path(root).glob('*_test.dart') if p.name not in excluded)
assert files
print('\n'.join(files), flush=True)
subprocess.run(['flutter', 'test', *files], check=True)
```

Run that code with `python3` and save the enumerated list/results. Expected:
exit 0, all selected tests pass. Deferred platform/storage stress and integration
device qualification are not silently added; record exclusions explicitly.
Then run `flutter analyze` (no new diagnostics; record any existing baseline),
`flutter build web` (default JavaScript build succeeds; not `--wasm`), and
`git diff --check` from the repo root (exit 0). Each intermediate PR also runs
its focused tests and analysis; controller selects additional affected ordinary
tests, never waives a known relevant failure merely because the whole gate is
scheduled for Task 6. No native/full accessibility/audio qualification is implied.

## Plan review and approval ledger

- [x] Read the approved spec and existing routes, theme preferences, committed
  summary/checkpoint providers, qualification and test harnesses.
- [x] Define owned files, shared signatures, sequencing and regression gates.
- [x] Self-review spec coverage, types, task step precision and Review Focus.
- [x] User approved this plan before Task 1; during the Task 1 handoff, Qwen had
  already been dispatched and left a local catalogue commit. The user then
  changed the worker choice to GPT-6 Luna; Luna audited/finalized Task 1 and
  handled all subsequent implementation. No further Qwen dispatch or resume
  occurred.

Coverage: spec §§1–3 → Tasks 1, 3, 5; §§4–5 → Tasks 1–2, 5; §6 → Task 5;
§7 → Tasks 3–4; §8 → Tasks 3, 6; §§9–10 → every PR plus final gate.
Content/spelling/assessment/release work is deliberately excluded, not missing
implementation. Plan publication and approval do not change the running demo.
