# FR-01 outcome — curriculum contracts and live pilot migration

Plan: [approved execution plan](../plans/2026-10-11-french-curriculum.md).
Authority: [migration design](../specs/2026-10-11-french-curriculum-design.md),
[exact contract revision 1](../specs/2026-10-10-french-learning-contracts.md).
User authorized immediate migration, sequential local `ollama/qwen3.8:27b`
implementers, controller review/verification/PR merges, and record preservation.

## Outcome

**FR-01 is implemented and merged.** Published product head:
`058188e48c680686198bc95070e6a5ee76179b52` (PR #19).

- Immutable curriculum, four typed exercise payloads, sentence/token/audio
  references and unique-or-null lookups are frozen at contract revision 1.
- Pure deterministic validation distinguishes structural errors from resource,
  review and planned-content readiness issues. No pronunciation is inferred from
  spelling; sentence keys use contextual annotations, not citation-word guesses.
- The French catalogue is the sole source of the live `/u/`–`/y/` pilot's ten
  exercise definitions. `LessonSection.fromCurriculum` supplies the compatibility
  projection; production validation runs before the cached pilot is exposed.
- Ten saved word IDs, their order, version 1, contentRevision 1, default/custom
  policy, immediate correctness, section-end explanation, finite mistake rounds,
  historical progress and outbox semantics remain unchanged. Non-pilot lookup
  remains null. No runtime/session/store/policy/UI/routes/backend changes.
- Coverage honestly marks `u`/`y` authored and `i,o,ɔ̃,ɑ̃,ʁ` planned. Six planned
  destinations reserve future stages/side quests; they are not new playable routes.

## Delivery and independent review

| Delivery | Worker / retained workspace | Reviewed head | PR / merge | Controller evidence |
|---|---|---|---|---|
| Design/plan | controller, `french-section-plan` | `4525aa6` | [#14](https://github.com/klottick/phoneme-app/pull/14), `fa09662` | Baseline 375 tests, analyzer and JS build |
| 1 immutable models | `ses_ed2bed4caffebXs1ia4N1lE2lL`, `fr-curriculum-models` | `8743d0a` | [#15](https://github.com/klottick/phoneme-app/pull/15), `241b2c8` | 417 tests, analyzer; final concrete types and nested mutation evidence repaired |
| 2 graph validation | `ses_ed247dec8ffeaMj50b0UoA6C13`, `fr-curriculum-graph` | `6f088be` | [#16](https://github.com/klottick/phoneme-app/pull/16), `61d3c49` | 458 tests, analyzer; 512 exhaustive cycle/determinism graphs plus 3 adversarial cases |
| 3 payload/readiness | `ses_ed1beb70fffe6nuAmXZ3xoq56s`, recovery `ses_ecff60321ffekrfl1o73R7gkM0`, `fr-curriculum-payload` | `261ab7c` | [#17](https://github.com/klottick/phoneme-app/pull/17), `9d71e0a` | 559 tests, analyzer; F1–F6 closed in three scoped rounds |
| 4 catalogue/live migration | `ses_ecfeb93feffeE0WJfylJBPH22C`, `fr-curriculum-migration` | `30f79c0` | [#18](https://github.com/klottick/phoneme-app/pull/18), `112519b` | 607 tests, analyzer/JS build; projection/mutation/literal-save evidence repaired |
| Final projection wave | `ses_ecf935d73ffeuYbe4edCYFGf8k`, `fr-curriculum-projection` | `a2dca5a` | [#19](https://github.com/klottick/phoneme-app/pull/19), `058188e` | 614 tests, analyzer; all-label distinctness and selected-branch reverse ownership repaired |

All workers used local Qwen, with one active implementer at a time and no worker
delegation/merge. Controller separately reviewed spec compliance and quality;
whole-batch review covered the entire `fa09662..112519b` range, followed by one
scoped final fix/re-review. No Critical/Important source findings remain open.
Validator size (1,322 lines, named pure phase helpers) is a nonblocking maintenance
follow-up, not grounds to split frozen contracts in this ticket.

Task 3 transport timeouts preserved filesystem changes; a fresh recovery finisher
completed reporting/commits. Evidence was corrected rather than overstated:
20,000-token Flutter tests passed even with recursion; the standalone Dart canary
genuinely overflowed. Strengthened **100,000-token** repository tests both failed
the old recursive implementation and passed the final iterative matcher.
The final wave's unrelated-branch tests prove projection compatibility/alias reuse,
not complete generic validity; the separately validated two-item synthetic
catalogue supplies the latter evidence.

## Final verification on published product head

Commands ran sequentially in `frontend/` with
`/home/klottick/develop/flutter/bin/flutter`:

- `pub get --enforce-lockfile`: succeeds; dependencies unchanged.
- `test --no-pub`: **614 passed**.
- `analyze --no-pub`: **No issues found**.
- `build web --no-pub`: **Built build/web**, JavaScript.
- Six standalone controller canaries: **2,546 independent cases passed**:
  515 graph, 5 payload-edge, 1 depth, 12 projection and 2,013 random exact-token,
  readiness-matrix, contamination and production-report cases.
- Stronger literal-save screen/parser oracle: **8 passed** against an isolated
  archive of original published baseline `a500651`, and in the final full suite.
  Five literal version-1 checkpoints independently match the pre-migration oracle.
  Tests use real preferences/store and actual screen continuation, including
  review-mode Finish, explicit widget 80% vs saved 100%, exactly-once evidence,
  closed playback gates, reopen and historical sibling/score/outbox retention.
- All 24 legacy word records, five lessons and course values match the independent
  frozen parity oracle; original French declarations remain byte-for-byte intact.
- Scope check: exactly 14 allowed frontend paths, five production source files;
  generic imports pure. Session/store/policy/audio/screens/router/dependencies and
  backend unchanged. Reviewed `a2dca5a` and published main have identical product
  trees; range whitespace clean. Unpublished local main remains `4dff777`.

Evidence: `/tmp/opencode/fr01-final-merged-{pub,tests,analyze,web}.log`,
`fr01-final-merged-{graph,payload,token-depth,projection,final-projection,final-validator}.log`,
`fr01-final-premigration-widgets.log`; task-level logs remain alongside them.
Detailed briefs/reports/review packages and the recovery ledger are retained under
`.superpowers/sdd/2026-10-11-french-curriculum/` in the controller workspace.

## Honest remaining gates

The production report has zero structural errors and **35 readiness issues**:
6 planned nodes, 5 planned phonemes and 24 missing reviewed word recordings.
Declared practice TTS is not a device voice guarantee or graded exam reference.
No new sentences/spelling/read-aloud/assessment content, reference assets,
recording/scoring, screens, local evaluator, backend events or dependencies landed.

FR-02 still needs recording provenance/rights and qualified French review; FR-03
playback and later UI/evidence/assessment tickets need their own approved designs.
Real browser/iOS/Android voice quality/lifecycle and live backend/RLS checks remain
separate. Existing `flutter_tts` Wasm dry-run warnings remain: JavaScript success
does not establish Wasm support. Pronunciation evaluation remains local-only,
with no recording uploads/cloud grading and no invented speaking score.

All worker branches/worktrees and process records are retained. Cleanup requires
a new explicit user request. Unpublished Sound Match work was not bundled,
overwritten or discarded. Broader FR-02+ completion is not implied by contracts.

## Rulings and costs (in decision order)

1. Task 4's “missing-reference issues” means `missingReviewedAudio` readiness,
   not structural dangling `missingReference`: the spec declares every word
   reference and requires validity. If wrong: readiness/test rework only.
2. Retain records/worktrees instead of skill-default deletion: explicit approved
   preservation requirements govern. If wrong: disk clutter until authorized cleanup.
3. Add graph-test integration to Task 3 ownership: structural-only intermediate
   expectations must accommodate independent payload/readiness diagnostics while
   retaining every graph invariant. If wrong: test-fixture/review-scope rework,
   no persisted-data change.
4. Use a fresh local-Qwen recovery finisher after repeated Task 3 transport
   timeouts: preserve tested source and avoid replaying a large task just for
   bookkeeping. If wrong: extra local context cost, not lost/restarted code.
