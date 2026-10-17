# FR-07-B phoneme comparison: published engineering outcome

## Outcome and authority

FR-07-B is published on `main` as an optional alpha Home-practice activity,
separate from the ten-item identification pilot. It presents ten authored
Same/Different pairs (five of each; six vowel and four consonant targets),
requires fresh successful playback of both A and B for each answer, and retains
the saved-debrief-only teaching rule. Review is finite and authored-order;
the saved completion threshold defaults to 80%. Comparison evidence is local,
uses an independent schema-1 document family and shared transaction/owner
helpers, and never contributes to phoneme mastery or identification history.
This is an engineering publication outcome, not linguistic or release approval.

The written design is [FR-07-B design](../specs/2026-10-17-fr07b-phoneme-comparison-design.md).
The approved implementation plan is
[FR-07-B implementation plan](../plans/2026-10-17-fr07b-phoneme-comparison.md).
Written-spec [PR55](https://github.com/klottick/phoneme-app/pull/55) reviewed
head `60ce881368dba16bac5766e5a071bb8e6e5f9411` merged as
`c2b11ce271e9a65122d7af5dc97ed8eea3eed528`. The approved plan was published in
[PR56](https://github.com/klottick/phoneme-app/pull/56), reviewed head
`71de378128d7b49bc6fefef2f22047ddc5b2bc20`, based on
`c2b11ce271e9a65122d7af5dc97ed8eea3eed528`, merge/fetched `main`
`57af5c3023388505a13d2fcbb407f5304a504853`. FR-07-A's historical outcome remains
[unchanged](2026-10-16-fr07a-discovery-remediation.md): B's later integration
does not retroactively authorize or rewrite A.

## Published engineering deliveries

The six sequential implementation PRs were based on published predecessors,
implemented by the selected sequential Luna workers, reviewed independently,
and then controller-verified and merged through normal PRs. The actual reviewed
heads and merge commits are:

| Delivery | PR | Reviewed head | Merge commit |
| --- | --- | --- | --- |
| Comparison content | [#57](https://github.com/klottick/phoneme-app/pull/57) | `3e47aa6341e30061f173e2e2afeb375937d7c0a2` | `6653b67078e49a3a951b3b9fce07a1d64642a1dd` |
| Shared learning transactions | [#58](https://github.com/klottick/phoneme-app/pull/58) | `bd90f94c265ae03f9e23d3811abf38eb11624486` | `66daefcd147021c6740effae39287faeb479f64d` |
| Comparison profile | [#59](https://github.com/klottick/phoneme-app/pull/59) | `94527b6ccd3e5c55cc385042d59a8280c185b04c` | `68ed35011dd0144c44cee57f464477a2f748f4f3` |
| Shared exercise owner | [#60](https://github.com/klottick/phoneme-app/pull/60) | `42a1efc5082de4db4dfdaa7cc006f5fd47d0b347` | `c78fc205e02c1b94f5e5f9dc4d3e9c73e966cf44` |
| Comparison flow | [#61](https://github.com/klottick/phoneme-app/pull/61) | `491bbe410cb1eafb8fba12a3a95d7d3e7b9a6b2e` | `53ba93d4dfaaab6f19425d9796bcd1dbb216229d` |
| Comparison entry | [#62](https://github.com/klottick/phoneme-app/pull/62) | `8733afb7ecf64bde1716883ac7db46b5e8f08744` | `6b59fbc00e244f53ea31d8ed5e2b9080d37f4a52` |

The PR62 published full tree matched the reviewed head, with parents
`53ba93d4dfaaab6f19425d9796bcd1dbb216229d` and
`8733afb7ecf64bde1716883ac7db46b5e8f08744`; fetched `main` matched merge
`6b59fbc00e244f53ea31d8ed5e2b9080d37f4a52`. Independent final rereview
approved the whole feature and closed I1/M1; the final acceptance is recorded in
[PR62 comment 6237046139](https://github.com/klottick/phoneme-app/pull/62#issuecomment-6237046139).
GitHub showed no CI checks or formal review records at the inspected gates;
missing CI is not passing CI. Merges used exact-head guards without bypasses,
overrides, or direct pushes to `main`.

## Specification acceptance evidence

The eleven acceptance rows in design §6 (lines 373–383) are mapped below to
named tests executed in the integrated/full run. These tests establish technical
behavior against authored fixtures and fake/controlled playback, not French
accuracy or external readiness.

| Spec row | Named executed evidence / boundary |
| --- | --- |
| Authored data | `french_comparison_inventory_matches_approved_spec`, `comparison_catalogue_rejects_incomplete_duplicate_and_unknown_content`, `wrong phoneme identity at a valid ordinal is rejected independently for A and B`; structural catalogue validation only. |
| UI contract | `comparison_view_is_neutral_and_accessible`, `first answer is acknowledgement gated and frozen retry preserves provenance`; neutral instructions/typed response and hidden metadata under test harness. |
| Audio | `comparison_audio_accepts_reverse_order_and_only_exact_unverified_results`, `app pause revokes both comparison hearing grants`, `route cover and app pause compose without hidden playback`; controlled events, not actual playback certification. |
| Session | `comparison_finite_review_and_restore_8_of_10_review_is_finite`, `seven of ten remains ineligible and wrong review does not requeue`, `review finish records no completion`, `fresh run answers all ten in authored order before debrief`, and `comparison_pair_review_preserves_finite_queue_context`; saved finite-session behavior and actual pair-linked queue. |
| Evidence | `registered answers derive correctness and pair-only evidence`, `comparison answers and completion leave real v2 evidence bytes untouched`, `comparison_summary_counts_only_current_committed_evidence`, and `comparison_owner_refresh_a_to_b_to_a_isolation`; typed pair/local summary and owner-isolation boundaries. |
| Storage seam | `v2 profile bytes and receipts remain exact`, `unsupported comparison raw remains unchanged while v2 sibling loads`, `one actual persistence isolates real v2 and comparison families`; exact v2 fixtures and profile separation. |
| Transactions | `failed write restores exact bytes and same frozen command retries once`, `held answer adds attempt and durable counts only after ACK`, `comparison_finish_ack_retry_and_duplicate_receipt_are_durable`; actual repository/persistence barriers. |
| Restore | `answered restore shows feedback without selected answer or audio`, `unanswered restore requires fresh A and B grants`, `restored_saved_90_percent_policy_overrides_widget_80_percent`; no inferred selection or hearing. |
| Discovery preservation | `real_links_preserve_legacy_unknown_and_review_semantics`, `comparison_entry_is_additive_and_unknown_is_local`, `home_primary_legacy_and_audio_compare_keep_real_destinations`; existing `/compare`, primary discovery, and four legacy links. |
| Audio preservation | `french_audio_manifest_test`, `course_audio_catalog_test`, `course_reference_audio_test`; manifest/assets remained pending and unchanged; technical verification is not source/rights review. |
| Accessibility | `keyboard hearing and relation activation claims once` covers keyboard activation; `comparison active and debrief scale and scroll matrix` covers 360×640 at 2×/3×; `comparison_view_is_neutral_and_accessible` and `v2_data_comparison_error_retry_and_pair_link_are_reachable_at_2.0x` (also run at 3×) cover neutral semantics and progress reachability. These tests are not assistive-technology or platform playback acceptance. |

The inventory consists of 10 distinct pairs, 5 Same/5 Different, six vowel and
four consonant targets, 20 slots across 13 known pending references. Playback
permissions are transient and revoked on replay/lifecycle/owner changes; frozen
save retry reuses typed receipts rather than restoring hearing permission.
Debrief notes are teaching, not learner diagnosis. The exact completion label is
**“Comparison completion policies: N”**: it counts distinct current-revision
completion policy identities `(activity, content revision, policy revision,
saved threshold)`, not chronological completed runs and not mastery.

## Review dispositions and known limits

Reviews closed earlier route-identity, conflict/retry, orphan-settlement,
initial-start and auth-readiness blockers. Final I1 was reproduced as factory
acquisition occurring outside its guarded boundary; recovery handling now catches
it. Final M1 required proof that an acknowledged finish automatically publishes
through the current provider; the integration test now holds/release barriers
around the actual ACK and publication. Independent rereview accepted the
exception-type coverage variation: the injected factory throws
`ComparisonUnavailableException`, not the exact validation subtype; catch logic
is type-agnostic and the real factory retry boundary is exercised. Do not claim
the subtype-specific recovery branch was executed.

Initial Task 5 screen behavior was written before its behavioral widget tests;
initial Task 6 route/projection/Home code also preceded meaningful behavioral
regressions. These sequencing deviations are disclosed in the task records; later
passing tests do not retroactively make those changes test-first. The user
approved expansion of Task 6's seven-path scope to ten paths to repair four
offscreen/lazy-widget assumptions and one cross-FakeAsync fixture-pollution
problem. Assertions were retained; no product layout change or kernel workaround
was used.

Nonblocking follow-ups remain explicit: discovery-hash identity weakness (no
grant leak demonstrated), Task 5's post-ACK callback-throw screen branch is
source-only (shared-helper callback-throw unit coverage and real Finish-ACK
behavior are covered separately), and Dart JSON decoding cannot detect duplicate
textual object keys after `jsonDecode` collapses them. These are not silently
treated as closed.

## Final controller verification and preservation

At exact PR62 head `8733afb7ecf64bde1716883ac7db46b5e8f08744`, fresh controller
results were:

| Working directory | Command/result |
| --- | --- |
| `frontend/` | `/home/klottick/develop/flutter/bin/flutter test --no-pub --reporter expanded` — **1,350 passed**, all seven process exits 0. Three known `AudioPlayers Exception` / `FakePreparationError` events from negative-path fixtures appeared. |
| `frontend/` | `/home/klottick/develop/flutter/bin/flutter analyze --no-pub` — no issues, exit 0. |
| `frontend/` | `/home/klottick/develop/flutter/bin/flutter build web --release --no-pub` — `Built build/web`, exit 0; JavaScript release build only. Three `flutter_tts 4.2.5` Wasm dry-run warnings; not Wasm or playback acceptance. |
| Repository root | `python3 -m unittest discover -s scripts -p 'test_*.py' -v` — **52 passed**, exit 0. |
| Repository root | `python3 scripts/verify_french_audio.py --repo-root .` — **24 pending** candidates verified technically/metadata only; still pending. |
| `frontend/` | `/home/klottick/develop/flutter/bin/dart format --output=none --set-exit-if-changed lib/src/features/course/comparison_progress_summary.dart lib/src/routing/app_router.dart lib/src/features/home/home_screen.dart lib/src/features/course/course_progress_screen.dart test/widget/comparison_entry_flow_test.dart test/widget/home_navigation_test.dart test/widget/course_learning_progress_test.dart test/widget/discovery_entry_flow_test.dart test/widget/course_flow_test.dart test/widget/discovery_lesson_test.dart` — 10 paths unchanged, exit 0. |
| Repository root | `python3 .superpowers/sdd/2026-10-17-fr07b-phoneme-comparison/verify_scope.py 6` — **432 unowned tracked paths byte-identical**, **2 original untracked paths intact**, **10 changed tracked/index paths, all owned**. |
| Repository root | `git diff 57af5c3023388505a13d2fcbb407f5304a504853 8733afb7ecf64bde1716883ac7db46b5e8f08744 --check` — clean; exact feature diff has **37 paths** (controller evidence: `status-controller-feature-diff.log`). This range is distinct from the PR62 merge/tree identity comparison above. |

All seven controller verification commands exited 0. The final run preserved
Sound Match work, branches, worktrees, process records,
assets and audio bytes, provenance, metadata, licences, v2 keys/fingerprints,
backups and user data. The only acceptance PR and ordinary merge do not imply
all FR-07, product release, or assessment readiness.

## Gates still open

Qualified French linguistic review, pair suitability, recording realization and
reference-audio review; licensing/rights; browser and native playback;
assistive-technology acceptance; live-backend and privacy review; assessment
suitability; and release readiness remain open. Candidates are unreviewed and
are not assessment assets. There is no silent TTS substitution after recording
failure, upload/cloud pronunciation analysis, or invented grade. Nothing here
authorizes FR-15, sandbox bypass, or further Qwen investigation.

This outcome document is delivered separately through its own scoped PR. Its
reviewed head/merge and fetched-tree verification belong in the PR comment and
local ledger, not in a self-referential hash claim.
