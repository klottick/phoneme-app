# Dedicated /u/–/y/ comparison planet — demo design

**Status: written specification awaiting user review.** The roadmap and the
clarification “Just do your best effort for the demo” authorize clearly labeled
best-effort practice content without recruiting a qualified French reviewer.
They do not approve this written spec, an implementation plan, product changes,
linguistic/rights/playback sign-off, assessment use, or release. Product code is
out of scope until this spec and a later plan have each been reviewed and
approved.

**Baseline inspected:** published `origin/main`
`e3b6e613c1dbbdeb51cbdeabe7d0830708538e5c`.

**Existing contract references:** [FR-07-B comparison design](2026-10-17-fr07b-phoneme-comparison-design.md),
[FR-07-B published engineering status](../status/2026-10-17-fr07b-phoneme-comparison.md),
[map-first course design](2026-10-23-map-first-space-course-design.md), and
[French reference-audio policy](../../french-reference-audio.md).

## 1. Purpose and boundary

Make the existing planned **Compare /u/ and /y/** body on the live `Tu or tout?`
system a real dedicated practice destination, following discovery in the authored
main order. The activity compares only the designated vowel in each sample. It
is a small authored demo, not a qualified French lesson, formal assessment, or
completion of the wider mini-course.

Included: one new stable comparison activity and section at content revision 1;
ten balanced authored pairs; dedicated routing, session ownership, progress and
map projection; the existing comparison session/audio/transaction mechanics; and
clear best-effort/unreviewed copy.

Preserve unchanged: discovery lesson/activity/item IDs, content revision, saved
progress and completion rules; mixed activity `en-fr-phoneme-comparison`, its ten
pair IDs, catalogue, checkpoints, run, evidence, completion, route and exact
canonical command bytes; old `/course-comparison/en-fr-phoneme-comparison` and
`/compare` behavior; audio manifest/review metadata/readiness; and all map
destinations not explicitly updated below. No schema migration, second writer,
new audio/text assets, word/sentence TTS, runtime spelling heuristic, content
qualification, new hard lock, graded checkpoint, speaking, cloud sync, or
licensing/release decision.

## 2. Alternatives and selected architecture

1. **Recommended — register both comparison activities in the existing
   comparison family and give each an independent activity run slot.** Keep the
   existing owner/course/family scope, transaction coordinator, tables, audio
   owner, session engine, and typed comparison evidence. Extend the domain and
   SQL adapter from one registered catalogue/slot to a validated activity map
   and activity-keyed slots. The existing `learning_runs` primary key is
   `(scope_id, activity_id)`; receipts, attempts, mistakes, summaries and
   completions also carry activity identity. Avoid a SQL rewrite or parallel
   writer.
   Preserve a legacy `slot` read accessor as the mixed activity's slot where
   compatibility requires it; new callers select `slots[activityId]`.
2. **Namespaced comparison profile.** Gives the demo a physically separate
   persistence scope, but current profile scope and validators are family-level
   and only one comparison catalogue is registered. Introducing another
   profile/schema family would require more storage/version surface and could
   duplicate orchestration. Not selected.
3. **Ephemeral preview.** Avoids durable-state changes but cannot truthfully
   project resumable/completed map progress and would diverge from the real
   session/recovery flow. It is not a dedicated persistent planet; not selected.

The selected approach is additive in the existing comparison family, not
“replace the global catalogue.” It must reject duplicate/unknown activity IDs,
validate each catalogue against its own content revision, load and validate every
registered activity row independently, and leave unrecognized/corrupt data
preserved and unavailable rather than silently dropping it. No SQL table/schema
change is intended: confirm this against the existing unique activity-keyed run
constraint during the later plan. If that constraint is absent or cannot safely
represent independent run cursors, stop and return for a revised written design;
do not improvise a second profile/writer.

### Named interfaces and data flow

- `comparison_content.dart` / `french_comparison_content.dart`: add stable
  `uyDemoComparisonActivityId = 'en-fr-u-y-comparison'`, section ID of the same
  value, and a loader for its separately authored catalogue. Preserve the
  existing mixed constant and loader exactly. New pair IDs use
  `uy-demo-pair-01` … `uy-demo-pair-10`.
- Comparison learning domain, command codec, checkpoint codec, storage
  validator, and `comparison_learning_sql_adapter.dart`: accept only the
  registry's explicit activity-to-catalogue mapping; key checkpoint/cursor by
   activity. Keep the existing mixed command JSON/fingerprint bytes and storage
   key unchanged. Preserve the scope-wide monotone commit ordinal while
   validating run cursors and receipt before/after chains per activity; never
    compare one activity's cursor with another's. A commit in one activity still
    advances the shared scope revision/ordinal; a concurrent command captured
    against the prior scope revision must use existing conflict/reload behavior,
    not overwrite the sibling activity. Comparison profile persistence remains
    local and owner-isolated. No comparison value enters course discovery state
    or the cloud outbox.
- `course_learning_providers.dart`: expose an immutable registered catalogue
  lookup by activity ID; construct the existing comparison repository once
  with that complete registry, not separate repositories/writers. The route
  resolves the requested registered catalogue and binds it to that activity's
  saved slot.
- `comparison_lesson_screen.dart` and `app_router.dart`: route both exact
  activity IDs to the shared screen/session flow, with per-catalogue pair
  validation. Preserve old route/query validation. A bad or unknown new
  activity is locally unavailable and cannot affect mixed practice.
- `course_map_catalogue.dart`, `french_space_map.dart`, and
  `course_map_projection.dart`: use a typed dedicated-comparison target and
  validate its exact registered activity binding; do not alias it to
  `mixedComparison`. Projection reads only its own slot and current-revision
  completion. Existing mixed station remains independently typed/bound.

Playback and answer flow stays the FR-07-B contract: both exact A/B references
must successfully play in the current prompt before one typed answer; retries,
cancellation, owner/lifecycle fencing, acknowledged saves, and finite review are
unchanged. Use the existing `LessonPolicy` default (80%) and saved threshold. Only
acknowledged Finish from an eligible current-revision practice run creates this
activity's completion. Review Finish does not create one. A demo completion is
practice completion, never phoneme mastery or assessment evidence.

## 3. Authored inventory and audio disclosure

All samples use existing citation annotations and existing alpha-practice-
permitted pending `fr-word-*` recordings. Every target is the single vowel at
zero-based phoneme ordinal **1** in the current curated citation sequence. These
are proposed author declarations, not independently verified French truth.
Every row is `ContentPurpose.practice` and `ContentReviewState.pending`; relation
keys are explicitly authored, not generated. Answer keys are five Same and five
Different and are not predictably alternating.

| # | New pair ID | A reference / target | B reference / target | Key | Saved debrief note |
| ---: | --- | --- | --- | --- | --- |
| 1 | `uy-demo-pair-01` | `fr-word-tout` / ordinal 1 `/u/` | `fr-word-tu` / ordinal 1 `/y/` | Different | The designated vowels are `/u/` in A and `/y/` in B; they differ. |
| 2 | `uy-demo-pair-02` | `fr-word-rouge` / ordinal 1 `/u/` | `fr-word-vous` / ordinal 1 `/u/` | Same | Both designated vowels are `/u/`. |
| 3 | `uy-demo-pair-03` | `fr-word-soupe` / ordinal 1 `/u/` | `fr-word-doux` / ordinal 1 `/u/` | Same | Both designated vowels are `/u/`. |
| 4 | `uy-demo-pair-04` | `fr-word-tu` / ordinal 1 `/y/` | `fr-word-loup` / ordinal 1 `/u/` | Different | The designated vowels are `/y/` in A and `/u/` in B; they differ. |
| 5 | `uy-demo-pair-05` | `fr-word-rue` / ordinal 1 `/y/` | `fr-word-lune` / ordinal 1 `/y/` | Same | Both designated vowels are `/y/`. |
| 6 | `uy-demo-pair-06` | `fr-word-jus` / ordinal 1 `/y/` | `fr-word-tout` / ordinal 1 `/u/` | Different | The designated vowels are `/y/` in A and `/u/` in B; they differ. |
| 7 | `uy-demo-pair-07` | `fr-word-loup` / ordinal 1 `/u/` | `fr-word-soupe` / ordinal 1 `/u/` | Same | Both designated vowels are `/u/`. |
| 8 | `uy-demo-pair-08` | `fr-word-tu` / ordinal 1 `/y/` | `fr-word-jus` / ordinal 1 `/y/` | Same | Both designated vowels are `/y/`. |
| 9 | `uy-demo-pair-09` | `fr-word-doux` / ordinal 1 `/u/` | `fr-word-lune` / ordinal 1 `/y/` | Different | The designated vowels are `/u/` in A and `/y/` in B; they differ. |
| 10 | `uy-demo-pair-10` | `fr-word-vous` / ordinal 1 `/u/` | `fr-word-rue` / ordinal 1 `/y/` | Different | The designated vowels are `/u/` in A and `/y/` in B; they differ. |

The new catalogue validator must verify all references, ordinal-to-annotation
identity, relation/key consistency, unique IDs, exactly ten rows and 5/5 key
balance. It may not derive phonemes from word spelling, word identity or
reference equality. If a source annotation/reference changes or a declared
ordinal/key fails validation, reject the whole dedicated catalogue and show
unavailable/retry; do not silently swap content or audio.

Show the exact existing alpha disclosure wherever audio is offered:

> Alpha audio: recordings are unverified; device speech is practice-only.

Also display this exact demo-specific copy on the planet destination and lesson
before starting:

> Demo practice: this authored comparison content has not had qualified French
> review. It is practice, not an assessment.

Keep candidates `pending`, speakers unverified, and all existing review/rights
metadata untouched. Use the existing alpha recording-first player with its
no-TTS-substitution-on-covered-recording-failure behavior. Technical playback
tests do not qualify audio, content, rights, or devices.

Active prompt copy exposes only “Compare the vowel in each sample,” neutral A/B
sample controls, and Same/Different. Do not reveal word spelling, meaning, IPA,
phoneme identity, pair key, or teaching note until saved debrief. At debrief show
the comparison rule, current saved score/threshold, and only applicable authored
notes in authored order; notes explain the pair, not the learner's presumed
choice or error.

## 4. Map journey, state and compatibility

- Keep map system ID `en-fr-u-y-system`, discovery body ID `discovery`,
  mixed-station body ID `mixed-comparison`, and all existing destination IDs.
  Existing body ID `comparison` changes from planned to live and binds to
  `en-fr-u-y-comparison` as a dedicated comparison target, not a mixed-station
  alias.
- Main recommendation order becomes `['discovery', 'comparison']`. Do not add
  a hard access prerequisite: both existing and new live practice routes remain
  launchable. With a resumable discovery or comparison run, recommend that run
  in authored order; otherwise recommend the first incomplete available main
  activity in that order. After both current-revision completions, say the
  available lessons are complete, while context, spelling, and checkpoint
  remain visibly planned/“Coming soon.” Never claim the whole mini-course is
  complete or a course/mastery percentage.
- Dedicated planet readiness/progress comes only from its validated registered
  catalogue and its own comparison slot/completion. Counts and labels identify
  dedicated `/u/`–`/y/` comparison practice; mixed counts/completion stay
  mixed. Neither activity transfers attempts, checkpoints, evidence, retry
  state, completion, recommendations, or credit to the other or to discovery.
- Preserve map loading/error/corruption and guest/account isolation semantics.
  Failure in the new comparison registration or slot yields a local unavailable
  body with recovery/retry; it must not erase, empty, or block valid discovery
  and mixed state. A completed or corrupted sibling activity must not overwrite
  another activity's checkpoint.
- Preserve discovery IDs/content revision/progress and mixed activity IDs,
  pair IDs, checkpoint, canonical commands, saved history, route and owners.
  Add no navigation-progress store. Existing route IDs and data remain
  interpretable after update; older app versions simply do not present the new
  activity.

## 5. Acceptance criteria for the later implementation plan

The plan must map each item below to source interfaces and test-first regressions.
These are future acceptance requirements, not test results or approval to code.

1. The new catalogue is exactly the ten table rows, IDs/references/ordinal 1,
   pending practice metadata, explicit keys/notes, and five of each relation;
   invalid reference/ordinal/target/key/duplicate/count/balance rejects the
   entire new catalogue. Existing mixed catalogue fixtures remain byte/value
   identical.
2. Each activity has an independent saved run, finite review, pair evidence,
   mistakes, summaries and current-revision completion under the current owner.
   Tests interleave starts, answers, held/failed commits, retries, finishes,
   reloads and review across both activity IDs without cross-writing cursors or
   checkpoints. Existing mixed canonical command bytes and data remain exact.
   Receipt ordering is scope-wide by commit ordinal, while before/after cursor
   continuity is checked only within one activity; stale cross-activity scope
   revisions conflict/reload rather than overwrite.
3. Existing SQL schema constraints support independent activity-keyed run rows;
   old mixed SQLite data loads unchanged. Corrupt/unknown new-activity data is
   preserved and surfaced unavailable, not treated as empty or used to suppress
   another valid activity. No second persistence writer or table migration.
4. Existing route and query behavior for mixed comparison and `/compare` is
   unchanged. The new exact route launches/resumes/reviews its own activity;
   unknown activity/pair/query values fail locally and cannot fall through to
   the mixed catalogue.
5. The body `comparison` has typed dedicated activity binding, follows
   `discovery` in main order, and uses only its own acknowledged current
   completion. Mixed practice remains an optional separate station. Loading,
   unavailable, not-started, resumable and completed states are distinct and
   owner-safe. Remaining context/spelling/checkpoint stay planned; no fake
   full-course completion or new hard lock.
6. Audio surfaces retain the exact alpha disclosure and retry/unavailable
   behavior with no covered-word TTS substitution. Both A/B fresh successes,
   cancellation, replay, save ACK/retry, route/background and owner-change
   fences remain. No candidate status/readiness/metadata/assets change.
7. UI copy identifies unreviewed demo practice and “not an assessment”; active
   answer hides words/meaning/IPA/phoneme/key/debrief; saved debrief alone shows
   authored teaching. Keyboard/semantics and narrow/large-text flows preserve
   these boundaries.
8. Discovery saved state/completion, mixed saved run/history/evidence, existing
   map route destinations, sentence qualification gates, and mixed review remain
   unchanged. Context, sound-to-spelling, checkpoint, speech assessment, cloud
   policy and wider roadmap work are not included.

Required future evidence includes focused content/validator, multi-activity
transition/store/SQLite/recovery, real router, map-catalogue/projection, widget/
accessibility, owner isolation and existing regression tests; plus applicable
Flutter full tests/analyze/web build and audio technical verifier. The exact
commands belong in the approved implementation plan. No tests are claimed by
this documentation-only change. None of those automated checks establishes
qualified French review, licensed distribution, real browser/iOS/Android
playback, assessment suitability, privacy, or release readiness.

## 6. Remaining gates and next approval

This demo uses best-effort authored content with no qualified French review.
Linguistic accuracy, reference realization, rights/licensing, real playback
compatibility, assistive technology, assessment suitability, privacy and release
remain separate gates. The activity cannot be promoted to assessment or
production-qualified content by this spec, an automated test, or the user's
demo clarification. Existing sentence/context qualification checks remain
unchanged; later roadmap slices require their own reviewed specs/plans.

Next: user reviews this written spec. If approved, write a separate focused
implementation plan naming exact files, activity-keyed domain and SQL adaptation,
test-first sequence, preservation checks and verification commands; obtain plan
review before any product-code changes. This document's publication is not demo
implementation or feature delivery.
