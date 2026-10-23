# Sound → spelling: /u/–/y/ demo design

**Status: approved specification (PR #118); [implementation plan](../plans/2026-10-23-uy-demo-spelling-implementation.md) awaiting separate user review.** The specification is approved; implementation is not authorized until the written plan is separately approved. No product verification or qualification is claimed here.

## Purpose and boundary

Add a small best-effort practice destination for English speakers learning the French /u/–/y/ contrast. The learner
hears one French word, chooses its spelling as `u` or `ou`, and sees teaching feedback only after the answer is durably
saved. It is a third recommended main body after discovery and comparison, but owns its content, checkpoint, answer
history, and completion independently.

This is spelling practice, not an assessment, mastery signal, qualified French lesson, full course stage, or claim that
the whole `en-fr-connect-spellings` curriculum node is ready. The general find-in-context lesson and checkpoint remain
planned. This U/Y-specific demo does not promote global coverage, authored curriculum chains, or any other sound.

The first answer to each item in a practice run remains separately visible from feedback-assisted retries. The saved
practice policy remains 80%. Only a qualifying, acknowledged Finish command for a practice-mode run may record
completion. Practice mistake review can improve that practice score; review-only work, inspection, restore, and lesson
entry create no completion credit.

## Existing foundations and explicit non-reuse

- `SpellingChoiceExercise`/`SpellingOption` already describe spelling choices but have no runtime consumer. They may be
  wrapped by a spelling-owned typed catalogue binding; their existence does not make the planned spelling node live.
  See [`course_exercise.dart`](../../../frontend/lib/src/core/course/course_exercise.dart).
- `frenchWords` and `frenchCitationPhonemes` are the existing word and citation-membership sources. The generic
  `en-fr-connect-spellings` node remains `planned` with no sections. Do not mark that node, global coverage inventory,
  or curriculum chain authored because of this demo. See
  [`french_course.dart`](../../../frontend/lib/src/core/course/french_course.dart).
- `LessonSection.fromCurriculum` accepts authored hear-stage listening-choice sections only. Do not disguise this
  spelling destination as discovery listening, a phoneme-answer exercise, or a comparison payload. See
  [`lesson_section.dart`](../../../frontend/lib/src/core/course/lesson_section.dart).
- `LessonSectionSession` provides a first pass, mistake-only review queue, latest outcomes, and saved `LessonPolicy`
  (default 80%). Its `latestAnswers` are replaceable on review, so spelling needs an owned checkpoint wrapper with
  immutable first-pass answers. Do not alter or broaden old checkpoint formats. See
  [`lesson_section_session.dart`](../../../frontend/lib/src/core/course/lesson_section_session.dart) and
  [`lesson_policy.dart`](../../../frontend/lib/src/core/course/lesson_policy.dart).
- The normalized learning database is physical schema v1. Its CHECK constraints/triggers reject spelling family,
  activity, answer, value, and playback-evidence kinds. Its v1 oracle validates table definitions, columns,
  constraints, indexes, triggers, foreign-key actions, and integrity. See
  [`learning_tables.dart`](../../../frontend/lib/src/core/course/storage/learning_tables.dart) and
  [`learning_database.dart`](../../../frontend/lib/src/core/course/storage/learning_database.dart).
- `LearningStorageScope` identifies owner, course, and family. The generic `SqliteLearningCommandCoordinator` provides
  durable receipts, owner checks, write fencing, scope compare-and-swap, family commit ordinals, and duplicate-command
  semantics. Reuse that shared database/coordinator; add no second database, writer, or sync outbox. See
  [`learning_storage_scope.dart`](../../../frontend/lib/src/core/course/storage/learning_storage_scope.dart) and
  [`learning_sql_transaction.dart`](../../../frontend/lib/src/core/course/storage/learning_sql_transaction.dart).
- The live map recommends `discovery`, then `comparison`; `spelling` is planned. Recommendation/completion use authored
  `mainOrder`, not orbital placement. Preserve discovery, comparison, sentence, legacy, and arcade routes/state. See
  [`french_space_map.dart`](../../../frontend/lib/src/features/course_map/french_space_map.dart),
  [`course_map_catalogue.dart`](../../../frontend/lib/src/features/course_map/course_map_catalogue.dart), and
  [`course_map_navigation.dart`](../../../frontend/lib/src/routing/course_map_navigation.dart).
- French reference recordings remain pending and disclosed alpha-practice material. Do not review, replace, alter, or
  promote recordings, metadata, credits, licence declarations, or readiness. See
  [`French reference-audio boundaries`](../../french-reference-audio.md) and the
  [published comparison demo status](../status/2026-10-23-uy-demo-comparison.md).

## Identity and authored inventory

Activity ID and section ID are both `en-fr-u-y-spelling`; content revision is `1`. The ten item IDs are exactly
`uy-demo-spelling-01` through `uy-demo-spelling-10` in this order. Visible ordered option IDs/text are exactly `u`,
then `ou`. Every row is practice with pending review state. The correct option is an explicit authored key, never
inferred from a letter, target membership, or grapheme heuristic.

Ranges are zero-based, half-open character offsets into each exact ASCII word. The target ordinal is zero-based in that
word's existing ordered citation-sound list; `/u/` and `/y/` name existing `u` and `y` sound labels.

| # | Word / audio reference | Target / ordinal | Range | Key | Exact saved English note |
|---:|---|---|---|---|---|
| 01 | `tout` / `fr-word-tout` | `/u/` / 1 | `[1,3)` | `ou` | `In tout, ou represents the authored target /u/.` |
| 02 | `tu` / `fr-word-tu` | `/y/` / 1 | `[1,2)` | `u` | `In tu, u represents the authored target /y/.` |
| 03 | `rue` / `fr-word-rue` | `/y/` / 1 | `[1,2)` | `u` | `In rue, u represents the authored target /y/.` |
| 04 | `rouge` / `fr-word-rouge` | `/u/` / 1 | `[1,3)` | `ou` | `In rouge, ou represents the authored target /u/.` |
| 05 | `loup` / `fr-word-loup` | `/u/` / 1 | `[1,3)` | `ou` | `In loup, ou represents the authored target /u/.` |
| 06 | `lune` / `fr-word-lune` | `/y/` / 1 | `[1,2)` | `u` | `In lune, u represents the authored target /y/.` |
| 07 | `doux` / `fr-word-doux` | `/u/` / 1 | `[1,3)` | `ou` | `In doux, ou represents the authored target /u/.` |
| 08 | `jus` / `fr-word-jus` | `/y/` / 1 | `[1,2)` | `u` | `In jus, u represents the authored target /y/.` |
| 09 | `plume` / `fr-word-plume` | `/y/` / 2 | `[2,3)` | `u` | `In plume, u represents the authored target /y/.` |
| 10 | `vous` / `fr-word-vous` | `/u/` / 1 | `[1,3)` | `ou` | `In vous, ou represents the authored target /u/.` |

There are ten unique IDs/references, five `/u/` items keyed to `ou`, and five `/y/` items keyed to `u`. Each ordinal
resolves to its target in existing citation membership; each range extracts exactly its key. Notes describe only the
authored target for that word: they are not a blanket French `u`/`ou` rule and do not prove an unreviewed recording's
realization.

### Catalogue validation

Validate the whole catalogue before any route, run, or checkpoint can use it: exact activity/section/revision; ten
ordered unique IDs; exact ordered options; word/reference identity; pending practice state; target/ordinal against
`frenchCitationPhonemes`; range bounds and substring; explicit key; exact nonblank note; five/five balance; no unknown,
duplicate, missing, or extra rows. Any mismatch rejects the entire catalogue. Never swap content, infer a key, repair
metadata, or publish partial rows.

The wrapper binds the existing exercise's `wordId`, `targetSound`, options, and `correctOptionId` to the authored
ordinal, grapheme range, and note. It preserves the `u`/`ou` choices and spelling skill without changing the
listening-only `LessonSection` projection or comparison identities/payloads.

## Learner interaction and playback contract

The active prompt is exactly:

> Listen, then choose how the vowel is written.

There is one `Listen to the word` playback/replay control. Before a saved answer, do not display the word, target range,
IPA, target phoneme, key, note, or hint in visual text, accessibility semantics, or tooltip. The two options `u` and
`ou` are visible from the start but cannot be submitted until the current prompt's covered recording completes.

Use the existing shared reference-audio service and alpha recording policy. Keep this exact disclosure visible:

> Alpha audio: recordings are unverified; device speech is practice-only.

All ten references are covered word recordings in the pending candidate set. A covered-recording failure shows
Retry/unavailable only and never substitutes device speech. Failed, cancelled, superseded, or stale playback grants no
answer, heard mark, unlocked choice, or progress. Initiating replay first retires any existing ready-to-answer grant;
only successful completion of that still-current replay creates a replacement grant. Cancellation, failure, or stale
completion cannot leave the old grant usable. Restoring saved answer feedback does not require replay.

Each grant is bound to current owner/auth generation, course, spelling family, activity/revision, run generation,
round, item, audio reference, and UI/prompt epoch; it is single-use for that answer. Stop, cancel, route exit,
backgrounding, disposal, or owner change retires request and grant. Stale completion cannot enable, submit, reveal, or
publish an ACK under a new owner.

Keep this exact practice disclosure:

> Demo practice: this authored spelling content has not had qualified French review. It is practice, not an assessment.

No new recording, audio metadata, binary, attribution, licence, credit, fallback, or readiness change is in scope.
Best-effort work does not require recruiting a qualified reviewer, and does not waive linguistic, rights, real-playback,
accessibility, privacy, assessment, or release gates.

## Durable answer, feedback, and retry state machine

States are pending playback, ready to answer, save pending, saved feedback, debrief, and finished. A visible selection
is not a saved answer. On choice, freeze one complete typed command—including token, expected scope revision/cursor,
selection, item, content binding, and exact playback evidence—before sending it to the shared coordinator.

Publish teaching feedback only after an accepted durable ACK for that command, or after a strict validated load proves
the same saved answer belongs to the current owner/activity/revision. Selection, pending request, optimistic state,
playback, or failed/uncertain save reveals nothing. During save, remain neutral. On save failure, retry the exact frozen
command/token; do not create another command or reveal teaching content. A duplicate ACK is idempotent. If ACK was
lost, load and validate the committed snapshot; do not record a second answer.

Only after accepted save, show correct/missed, the word with its exact target range highlighted, saved selection,
correct key, and that row's exact note. Continue is explicit; ACK never auto-advances. Restoring an answered checkpoint
shows saved feedback without replay or a new answer for that round. Corrupt, mismatched, or unsupported checkpoint
content fails closed and never reconstructs a reveal.

Each first-pass item accepts one answer in its round. A spelling-owned checkpoint wraps the shared session with an
immutable `firstAttemptAnswers` map. In round one its keys equal exactly the durable submitted first-pass prefix, in
authored order: the map is empty iff that prefix is empty, and each Boolean equals that item's durable first answer.
After the first pass it contains exactly one outcome for all ten items and never changes through review, retention, or
restore. Check these outcomes against retained matching answer attempts/receipts where available; never reconstruct
them from mutable `latestAnswers`. Restore also validates session reachability, queue/order, revision, item IDs, saved
policy, phase, round, cursor, and submissions. Use a new spelling checkpoint format; leave old
discovery/comparison/sentence bytes and decoders unchanged.

The first-attempt score counts immutable first-pass outcomes. A normal practice run's score counts its latest outcomes
after all ten first answers and at later debriefs. Display both; in-mode mistake retries can improve that practice score
but never the first score. “First attempt in this run” means only the first answer to that item in that practice run; it
never claims globally unseen, unexposed, or unassisted content. Review retries need fresh playback and are
conservatively recorded as repeat-in-run, post-debrief, feedback-assisted (answer-revealed and explanation-visible
flags). Review-only runs preserve the carried-forward practice first-attempt result; their retries do not rewrite that
result or the earlier practice score.

The saved default `LessonPolicy` is 80%; its exact threshold and policy revision govern resume rather than a new
default. Bind it as `discoveryThreshold`, policy revision `1`, threshold `80` at run start and persist those values.
Mistake review queues only currently wrong items in authored order. ACKed Finish with
`recordCompletion: true` is valid only at debrief, with all ten latest outcomes and saved threshold met. Only that
command writes this activity's revision-1 completion under saved policy. Review Finish uses
`recordCompletion: false`. The domain transition and storage validator require review-only Finish to remain false and
reject any new completion for a `reviewOnly` run, regardless of URL/query state. A `review=true` view of a saved
practice debrief also cannot issue a credit-eligible Finish. Entry, answer ACK, summary, inspection, provider load,
restore, and review Finish do not write completion. A below-threshold practice run may be reviewed, left, or
abandoned, but cannot finish with credit. The summary is practice, not assessment.

## Learning architecture and physical schema

Add typed family `spelling` to `LearningStorageScope` and the existing shared normalized database. Scope is exactly
`(owner, courseId: en-fr, family: spelling)`; activity is `en-fr-u-y-spelling`. Spelling owns typed state, commands,
canonical serialization, checkpoint, transition, validator, adapter, and aggregates. Family-profile schema version is
independent of physical DB version; existing family-profile versions remain 1 and the new spelling format starts at 1.

Reuse `SqliteLearningCommandCoordinator` for load, owner-generation checks, write serialization, scope CAS,
spelling-family commit ordinals, receipts, and frozen-command duplicate semantics. Add no second writer/database,
shared course/comparison profile, or spelling sync/outbox behavior. Spelling formats are strict and new; old codecs
remain closed to unknown kinds. Existing storage keys, payload bytes, receipts, and checkpoint formats stay unchanged.

Physical schema v2 is necessary: v1 CHECKs reject family/activity kind `spelling`, answer kind `spellingChoice`,
evidence kind `spellingPlayback`, and option-ID value fields. V2 explicitly validates spelling shapes for scopes,
bindings, runs (`activity_kind = spelling`), attempts, values/evidence, mistakes, summaries, completions, and exposure
where used. Normal practice runs use `run_mode = practice`; ordinary in-mode mistake review stays practice and may
raise its saved practice score to the 80% threshold. V2 permits both `practice` and `reviewOnly` for spelling run mode,
and exactly `firstInRun` and `afterDebrief` spelling summary buckets. Both SQL constraints/triggers and typed
validation reject cross-family field combinations.

`review=true` is inspection-only on route entry: it may read an existing complete-first-pass practice debrief or a
saved review-only state. Missing or incomplete-first-pass state shows unavailable/recovery guidance or an explicit
Continue practice link; it does not auto-start a run, create a first pass, answer, or issue a review command. Opening,
rendering, or inspecting state is read-only. From a saved practice debrief with mistakes, only an explicit learner
`Start review-only` action dispatches a saved start command. That command starts a new generation of this same
`en-fr-u-y-spelling` activity in the same spelling family, with `run_mode = reviewOnly` and the saved policy. It carries
forward the immutable practice `firstAttemptAnswers`, preserves historical practice attempts and existing completion,
and is not a second profile. No missed items means a saved read-only debrief, not an automatic review run. Returning to
the normal URL reloads the persisted `reviewOnly` mode; stripping the query cannot convert it into practice or enable
credit. Only a separate explicit new practice-start command/generation may begin a future credit-eligible practice run.
Review-only outcomes remain separate from the prior practice score and cannot create completion.

The attempt uses `answer_kind = spellingChoice`, spelling skill, practice origin, pending content state, and
selected/expected option IDs. First-pass attempts use `firstInRun`; retries use `repeatInRun` and the post-debrief
assistance flags above. Add text value discriminators `selected_option_id` and `expected_option_id`. Ordered `choice` values,
`word_id`, and `target_sound` may be reused only with exact checks: choices are precisely `u`, `ou`; item/target match
the catalogue; IDs are members; expected ID is the authored key. Reject missing, extra, mistyped, mismatched, or
duplicate fields. Never encode graphemes as phoneme answers or infer keys during persistence.

Each accepted answer has exactly one completed current-prompt `spellingPlayback` evidence row, with expected
`fr-word-*` reference and `unverifiedRecording` evidence source; its attempt has `audio_source = pendingRecording`.
Bind via scoped attempt plus activity, run, round, item, revision, reference ID, and current UI/prompt epoch.
Cancelled/failed evidence cannot authorize an answer. Scope and foreign keys bind owner/course/family; triggers require
this shape and reject comparison/sentence evidence.

Mistakes and summaries are spelling-family aggregates, never course/comparison aggregates. In
`learning_mistakes`, target identity is in the existing `target_sound` column; mistake identity is
activity/item/`target_sound`/revision. In `learning_summaries`, target identity is in the existing `sound` column (not a
`target_sound` column); summary identity is activity/item/`sound`/revision/bucket, with spelling skill required. Add or
validate explicit unique spelling keys for mistakes `(scope, activity, item, target_sound, revision)` and summaries
`(scope, activity, item, sound, revision, bucket)`. Preserve separate `firstInRun` and `afterDebrief` buckets.
Completion uses this activity, revision, and saved policy identity.
Any exposure is spelling-family-scoped; it cannot rewrite discovery progress. Run-local scores remain in spelling
checkpoint/summary state; do not write this demo to `learning_best_scores` or the supported cloud outbox.

## V1 → V2 migration and downgrade contract

This is a real physical migration, not a profile-version change disguised as a schema no-op. New empty DBs are exact
v2. Reject version-zero DBs containing any non-internal schema object (table, index, trigger, or view whose name is not
`sqlite_*`), unknown/future versions, altered v1, or v1 failing the frozen structural contract, without reset, repair,
or deletion.

Keep a frozen exact-v1 oracle independent of current v2 definitions. Before migration validate v1 table names/DDL,
columns, types/nullability, CHECKs, explicit indexes, triggers, foreign-key signatures/actions, and integrity. Do not
derive v1 expectations from v2 `allTables` or let a v2-only `beforeOpen` shortcut bypass validation. Add strict exact-v2
verification on every open, including definitions, indexes, triggers, foreign keys/actions, and `foreign_key_check`.

Rebuild constraints/indexes/triggers required for the new family/kinds while preserving every normalized old row, ID,
value, canonical command JSON, checkpoint JSON, latest/historical receipt, and outbox order exactly. Do not decode,
re-encode, skip, repair, or change legacy family payloads/versions; their adapters retain fail-closed validation. A
successful physical rebuild changes DB-file bytes; no whole-file identity is promised.

The migration has two failure boundaries. **Before commit**, rebuilding/copying rows, changing DDL, creating indexes and
triggers, transitioning `PRAGMA user_version`, and strict target structural/data/foreign-key validation all belong to
one recoverable atomic upgrade under shared open/connection and SQLite write fencing. Validate copied row identities,
values, order, canonical/checkpoint bytes, target schema, and `PRAGMA foreign_key_check` before commit; the foreign-key
check is available inside the transaction even when enforcement is temporarily off. Any pre-commit failure rolls back
to v1, retaining its logical rows, DDL, user version, and JSON bytes. No family command may observe a partial schema.

Foreign-key connection configuration occurs outside the transaction and is restored in a `finally` path as applicable.
**After commit**, verify foreign-key enforcement is on before publishing a usable connection. If restoration,
verification, or connection publication fails after commit, fail closed and close the unsafe handle while preserving
committed v2. Do not promise rollback from v2 to v1 or reset the database. Retry must reopen and validate v2 rather than
rerunning the v1 migration. Inject failures in both phases; verify pre-commit rollback and post-commit v2 preservation,
safe close, and v2 reopen. Test fresh-v2 create, v1 migrate/reopen, every rejection path, and concurrent
tab/connection opens/writes: no partial state, duplicate command, reset, second DB, or second writer.

Select exact Drift API/operation order only after checking the installed dependency and native/web paths; this spec
gives no unverified API syntax or copy/paste SQL.

Open/migration failure can make all shared-DB families unavailable. Preserve data and explicit retry/reopen; never
report empty state or promise unrelated families are available while their DB cannot open. With valid v2, spelling
content/profile corruption is local and does not block other valid family providers.

Older binaries after v2 are unsupported and may fail closed. There is no automatic destructive downgrade or promise
that an old release makes physical rollback safe. Recovery is forward repair or an explicitly reviewed
data-preserving recovery.

## Map, routes, and progress ownership

Add `MapTarget.dedicatedSpelling`. Keep the existing `spelling` body ID, planet role, title `Sound → spelling`, body
list order, normalized coordinates, orbit radius, and system IDs unchanged; the body already follows `context` in the
body list. “Third” means third in `mainOrder` only: set the order exactly to `discovery`, `comparison`, `spelling` and
bind the live required main destination to `en-fr-u-y-spelling`. Show the exact practice disclosure as the body's
authored explanation. When all three main destinations are known available, current, and complete, preserve the exact
existing completion message `All currently available lessons complete.` and show the count
`Available main lessons: 3/3 available complete`. Keep unknown/unavailable guards; do not rename the old label or count
format.

Spelling recommendation, run, review, and completion read only spelling family state. No discovery/comparison
prerequisite or credit transfer. Context and checkpoint remain planned; the generic curriculum spelling node and
whole-course claims remain planned. Orbital position is not a prerequisite; mixed comparison, sentence practice, and
legacy lessons are not remapped.

Only lesson route: `/course-spelling/en-fr-u-y-spelling`; review:
`/course-spelling/en-fr-u-y-spelling?review=true`. One `review=false` is valid. Reject unknown activity, unknown query
key, duplicate key, or invalid value before store, SQLite, or audio acquisition. Add no item deep link. Map
start/resume/review bind only to this route, never generic `open`. `review=true` reads only an existing complete-first-pass
practice debrief or saved review-only state; it never initializes a run or first pass. Missing/incomplete state shows
unavailable/recovery or an explicit Continue practice link. It restores saved feedback or saved queue state without
mutating on route entry/render/inspection. Starting review-only work requires the explicit learner action and saved
command above. Review-route Finish is false/no-credit even when viewing an old practice debrief; storage/domain rules,
not query state alone, enforce persisted `reviewOnly` credit denial. Preserve existing routes/labels, motion/pause,
theme, 48-pixel minimum targets, keyboard navigation, narrow layouts, large text, and saved preferences.

## Acceptance boundaries for later work

These are future requirements, not evidence any test or release gate has passed.

1. Catalogue tests assert exact rows/order, five/five balance, ordinals, ranges, notes, IDs, and rejection of duplicate,
   missing/extra, unknown-reference, membership, range/key, blank-note, and metadata/revision mutations. No partial
   catalogue or fallback.
2. Real native SQLite v1 fixture includes legacy course, mixed/dedicated comparison, sentence-hunt, and outbox state.
   Verify row/ID/value/canonical-byte/order preservation, strict v2 creation/reopen, altered/unknown/future rejection,
   injected-failure rollback, concurrent write fencing, and FK/action preservation.
3. Typed tests cover exact answer/value/evidence shapes, owner/family isolation, scoped/stale/cancelled playback,
   feedback hidden until save, wrong/correct answers, frozen retry, held/lost/duplicate ACKs, restore, stable first
   score, saved 80%, qualifying ACKed completion, and review Finish without completion. Verify persisted `reviewOnly`
   cannot create completion after query removal and does not alter prior practice results. Valid-v2 content corruption
   is local; DB migration failure may block all families without losing data.
4. Router tests reject invalid forms before store/SQLite/audio acquisition; review-route entry/render/inspection is
   read-only, and only the explicit learner action starts review-only work. Map tests assert the three ordered mains,
   third-body counts/recommendation, unknown/unavailable safety, independent progress, and no inspection credit.
5. The ordinary test set is the explicitly enumerated top-level `*_test.dart` files in `frontend/test/unit/` and
   `frontend/test/widget/`. Exclude exactly the files
   `frontend/test/unit/course_learning_retention_test.dart` and
   `frontend/test/unit/learning_sql_retention_test.dart`; these are files, not excluded test roots, and exclusions are
   not passing results. Do not substitute a bare recursive `flutter test`, use recursive discovery as the scope
   definition, or drop newly added test files from the enumeration. These ordinary tests are additional to, not a
   substitute for, the separately required native and web migration/integration gates. Preserve route/storage/
   canonical-byte/regression goldens. Run analysis and default JavaScript build, not Wasm. Audio checks are
   technical/metadata only; automated playback uses fake audio only.
6. Seeded-v1 real web-SQL migration plus new answer/reopen is a separate web gate. Full production actual-URL reload is
   a separate release gate; neither is implied by native SQL, fake audio, a normal web build, or this document. Real
   browser/iOS/Android playback, qualified French review, rights/licence, accessibility, privacy, assessment
   suitability, and release approval remain independent open gates.

## Review boundary

All existing Sound Match assets, metadata, learner progress, routes, legacy behavior, worktrees/branches, browser
profiles, process records, and hosted demo are preserved. This document adds no product behavior. Written-spec approval
must precede a separate implementation plan and its approval; Luna6 is the already selected later execution choice,
not authorization to skip either gate.
