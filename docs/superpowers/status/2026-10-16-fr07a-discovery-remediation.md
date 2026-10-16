# FR-07-A discovery/remediation: published outcome

## Outcome and scope

The approved FR-07-A implementation is published on GitHub `main` through
[PR51](https://github.com/klottick/phoneme-app/pull/51),
[PR52](https://github.com/klottick/phoneme-app/pull/52) and
[PR53](https://github.com/klottick/phoneme-app/pull/53). The existing ten-item
`/u/`–`/y/` discovery pilot now has authored, unresolved-item teaching at debrief,
the primary Home entry, four explicit legacy-practice links, and separate honest
discovery versus historical completion counts. **This completes A, not all FR-07.**
Production comparison integration remains **FR-07-B outstanding**, requiring its
own approved design and implementation plan.

The existing lesson owner/session/store remains authoritative for audio, fresh
hearing, correctness, finite authored-order review, saved completion policy,
immutable Retry, committed evidence and navigation. Teaching is additive authored
presentation metadata, not persisted learner state or a diagnosis of a selected
distractor. No second lesson engine, catalogue kind, codec or storage migration
was added. Contracts remain phoneme-wide, not vowel-only; the live pilot does not
claim a complete discovery course.

- [Approved specification](../specs/2026-10-16-fr07a-discovery-remediation-design.md),
  [PR49](https://github.com/klottick/phoneme-app/pull/49): reviewed head
  `41ba4bdb836ea1edc466ba811aee0449a6a70e22`, merge
  `512c9d2406afde244aa7302ff5014ca0ed4f2108`.
- [Approved implementation plan](../plans/2026-10-16-fr07a-discovery-remediation.md),
  [PR50](https://github.com/klottick/phoneme-app/pull/50): reviewed head
  `141f4019857ee43d77931a257837794be6e9bf0c`, merge/execution baseline
  `79a4850ba03963558606912acd56fbf4415ecf85`.

The user approved the written specification and then the written plan. Execution
used sequential Luna implementers, independent task spec/quality reviews and a
whole-feature review of all 15 changed Dart paths. Incomplete first reports were
not accepted. Each task started from its predecessor's published merged baseline.

| Delivery | Reviewed head | Published merge |
| --- | --- | --- |
| PR51: pure teaching metadata/validation | `6620155af845fb8e7497be8655aa86c3b80da045` | `2d5755867cfb140a3fbca14e839b16156aaa0e8a` |
| PR52: controlled debrief/owner integration | `11f1c55f57b9e82b9edf461906852df3075ea403` | `191bf3567297edef46f14c9a1f9b3205e29cefcd` |
| PR53: primary entry/shared honest counts | `7fcc053c0313386534c3ff537eb786147ddd3d5b` | `e8a7a3e3039e0793ca22259e2c9f8dbef84a48da` |

Fetched full merge trees matched their respective reviewed heads. The final
whole-feature review covered the execution baseline through PR53's reviewed head;
controller verification used that exact final tree. GitHub reported no CI checks
or formal reviews at the inspected merge gates; **missing CI is not passing CI**.
Independent agent reviews and controller acceptance are recorded in durable
process evidence and PR comments, not represented as formal GitHub approvals.
Merges used exact-head guards without protection overrides or direct `main` pushes.

## All 12 acceptance rows and executed evidence

Test paths below are under `frontend/test/`; each cited suite was included in the
controller's final full run. Fake audio and structural validation do not certify
recordings, linguistic accuracy, real playback or production comparison assets.

| Spec acceptance row | Executed evidence / disposition |
| --- | --- |
| Explicit teaching bindings | `unit/lesson_debrief_content_test.dart`: ten exact authored bindings/copy, duplicate/unknown/blank/missing/wrong-section diagnostics, selected-source duplicate records/aliases/ownership, detached immutable collections and opaque consonant/multi-choice fixture. Unrelated malformed branches/shared aliases do not block the selected lesson. |
| Correct note selection | Pure projection preserves authored order; `widget/lesson_section_debrief_test.dart` covers 10/10, 8/10 at 80% and 7/10. `finite_review_updates_notes_without_early_teaching` ends finite round 2 with only `mur` unresolved, latest 9/10 and 12 attempts. |
| Restore without history | `restored_debrief_needs_no_history` preserves saved 100% threshold and separate note with empty history; `restored_first_pass_and_review_require_fresh_hearing` and three actual-primary-route saved-phase tests resume without a new start or duplicate evidence. |
| No early teaching | Active exercises receive no teaching entries. New restored/finite-review tests scan text/tooltips/semantics, and unchanged `widget/discovery_listening_exercise_test.dart` retains the FR-06 answer/error/replay/semantic secrecy checks. No legacy Word reference is exposed in the pilot. |
| Real primary entry | `widget/discovery_entry_flow_test.dart`: `home_enters_real_discovery_before_legacy` uses actual `LinguistApp`/`appRouterProvider`; saved first-pass/review/debrief resume, completed-pilot review intent, held/error loading and explicit refresh are exercised. No handcrafted router substitutes for this entry. |
| Safe compatibility | `real_links_preserve_legacy_unknown_and_review_semantics` checks all four legacy IDs and Home tiles, their unchanged listening/recording access, pilot/unknown behavior, actual Home review query and non-crediting review Finish. Direct review-hub sound-row activation is a retained nonblocking coverage follow-up; unchanged sound-link generation includes review intent. |
| Honest counts | `unit/course_completion_summary_test.dart` filters current revisions/known IDs, deduplicates and distinguishes historical pilot `legacyOnePass` from `discoveryThreshold`, including saved threshold 100. `home_counts_only_acknowledged_finish` drives ten UI answers, holds/fails Finish, retries the identical command and observes one route exit/one completion before Home 1/1 and Progress 1/5. |
| Recovery ownership | New held/failed Review/Finish tests retain command identity and duplicate-invocation guards. Actual A→B→A tests cover departed counts/badges and real `Correct` feedback before departure and its absence after replacement/late failed save. Unchanged recovery, explicit reload and router-backed lifecycle/three-entry one-pop tests preserve suspension/navigation behavior. |
| Audio preservation | Unchanged discovery/listening/audio lifecycle suites preserve fresh hearing, replay revocation, failure/cancellation without an answer, and owner fencing. No audio implementation or recording-failure substitution policy changed; preserved file hashes confirm technical scope only. |
| Legacy recording | Actual routes reach the matching legacy lesson and recording controls; unchanged `widget/course_recording_lifecycle_test.dart` begins/holds recorder startup and checks resource cleanup after navigation. Native device acceptance remains external. |
| Accessible presentation | Effective 360×640/2× and 360×800/3× debrief tests scroll/keyboard-activate Finish, Review, Retry, Reload and Practise again with exact callback counts. Actual Home Tab/Enter activates primary plus four legacy destinations at 360×640/2×. Unchanged FR-06 coherent response semantics and recovery-accessibility tests pass. |
| Invalid teaching | `invalid_teaching_is_read_only_unavailable` covers missing/duplicate notes and valid mismatched lesson content: neutral terminal unavailable entry, zero load/retry/prepare/submit/audio and unchanged saved data through owner replacement, lifecycle and remount; fresh valid entry restores the saved debrief. Independent legacy routes remain available. |

## Review dispositions and bounded presentation decision

- Task1 initially lacked required fixtures. Completion work reproduced an
  unrelated-branch shared-alias lookup bug, scoped lookup to selected identities,
  and added selected-source ambiguity/ownership acceptance cases. Independent
  rereview cleared blocking findings; no catalogue API was changed.
- Task2 review required large-text keyboard checks for Retry, Reload and Practise
  again, beyond Finish/Review. Effective text scale and all five action callbacks
  are now asserted at both sizes. Independent rereview cleared the finding.
- Task3 review reproduced retained counts/actions during explicit provider refresh.
  Home's two projections and Progress now use strict loading rather than retained
  data. Review also strengthened the real-router single-exit and actual departed
  feedback observations; the corrected tests were independently rereviewed.
- Whole-feature review found **no Critical or Important findings**. Its retained
  nonblocking test-hardening notes are: a combined simultaneous diagnostic-order
  fixture; failure-safe cleanup/gate completion for early assertion failures in
  some layout tests; and direct review-hub sound-row activation. These are not
  claimed fixed or silently discarded. The new root-only suspension test's local
  navigation-oracle limitation is covered in aggregate by unchanged router-backed
  suspension and three-entry one-pop regressions, not by its root-only assertion.
- Controller decision: keep progression/recovery controls before the expanded
  note list, after the full rule/counts, with existing parent scrolling. Added
  notes otherwise pushed old actions below the default viewport; the spec has no
  read-before-Finish gate. If wrong, this costs layout/reachability rework and
  renewed accessibility verification, not a scoring or data migration.
- Runnable missing-note, missing-primary-entry and strict-refresh failures were
  retained before their source changes. Missing-API scaffolding and fixture/setup
  corrections were not relabeled product defects. Known backend-failure output
  remains disclosed rather than suppressed through unrelated changes.

## Controller verification and preservation

Commands ran at final reviewed head
`7fcc053c0313386534c3ff537eb786147ddd3d5b`; a fresh premerge full suite passed
again, and the fetched published merge tree matched completely. Flutter executable:
`/home/klottick/develop/flutter/bin/flutter`.

| Working directory | Command | Result |
| --- | --- | --- |
| `frontend/` | `flutter test --no-pub --reporter expanded` | **1,123 passed**, exit 0; fresh execution baseline 1,093, for 30 additional tests. |
| `frontend/` | `flutter analyze --no-pub` | No issues found, exit 0. |
| `frontend/` | `flutter build web --release --no-pub` | `Built build/web`, exit 0; JavaScript build, not Wasm/playback certification. |
| Repository root | `python3 -m unittest discover -s scripts -p 'test_*.py'` | **52 passed**, exit 0. |
| Repository root | `python3 scripts/verify_french_audio.py --repo-root .` | **24 still-pending** candidates verified technically/for metadata only. |
| Repository root | `git diff 79a4850ba03963558606912acd56fbf4415ecf85 7fcc053c0313386534c3ff537eb786147ddd3d5b --check` | Clean; exactly 15 scoped Dart paths. |

The full suite emits three known `AudioPlayers Exception` / `FakePreparationError`
events from unchanged intentional backend-failure fixtures. It passes but its
output is not pristine. The web build retains three existing `flutter_tts` Wasm
dry-run cast warnings; these are not treated as Wasm success.

SHA-256 comparison verified **all 403 other baseline tracked paths unchanged**,
including accented recording filenames, recording bytes/provenance/licences, root
`LICENSE`, audio policy, dependencies/backend, core catalogue/registry/session/
policy/storage/codecs and legacy recording screen. An initial smaller preservation
snapshot omitted Git-quoted accented paths; the final NUL-delimited complete
baseline audit closed that evidence limitation. Old development namespaces/data,
unpublished Sound Match work, local branches/worktrees, untracked work and durable
process records were preserved; no cleanup or migration was performed.

Local reports, reviews, acceptance mapping, exact commands/results and publication
ledger remain under `.superpowers/sdd/2026-10-16-fr07a-discovery-remediation/`.
This outcome is delivered through a separate scoped reviewed documentation PR;
its exact head/merge and fetched-tree verification are recorded in PR comments
and the local ledger, avoiding a self-referential commit hash.

## Outstanding gates and exclusions

Actual browser/native playback and assistive-technology acceptance, qualified
French linguistic/audio/licensing review, live backend validation, privacy, FR-15
and production release remain open. Reused alpha teaching and fake-audio tests
do not qualify pending recordings or establish assessment readiness. No recording
uploads, cloud pronunciation evaluation, invented grades, silent recording-failure
TTS substitution, browser sandbox bypass or further Qwen investigation is authorized.

FR-07-B must separately design production comparison targets/pairs and keys,
content validation, typed evidence/actions, identities/checkpoint compatibility,
per-sample hearing/source attribution, finite review and honest summaries. Equality
concerns authored target phonemes, not words, speakers or reference IDs. No
production comparison route or persisted kind is delivered or authorized by A.
