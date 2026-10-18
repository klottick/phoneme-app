# SQLite learning-storage redesign

**Status: Proposed — conversational design approved; written spec awaiting user review.**

This specification records the approved direction to replace local learning-history
storage with SQLite. It is not implementation approval, an implementation plan, a
dependency-installation authorization, or a platform-support claim. Review this
document before preparing a separate implementation plan.

## 1. Intent and success criteria

Use one reliable, local SQLite learning database on web and native platforms for
the learner's saved course progress. Store attempts, resumable session state,
deduplication receipts, aggregates, and the already-supported course-sync outbox
as separate records rather than serializing the complete learning history into
one preferences value.

Success means:

- Existing identification/course lessons, comparison practice, and sentence
  hunt use the same database foundation without changing their scoring, lesson,
  audio, or completion behavior.
- Each learner command commits its answer evidence, session position, progress
  aggregates, receipt, and any already-supported sync event in one transaction.
- Retries are idempotent; a repeated or stale-tab command cannot double-credit
  progress or overwrite a newer checkpoint.
- A storage error is reported as unavailable or retryable, never as a successful
  save, a fresh empty profile, a reset, or permission to use volatile memory.
- Committed progress survives supported app/browser restart paths. The selected
  web backend is genuinely persistent and coordinates simultaneous tabs.
- Full retained learning history is exercised on real browser and native
  runtimes before support or capacity is claimed.

## 2. Decisions, scope, and exclusions

The user approved a complete redesign and chose SQLite. “Existing learning
history” means saved learner progress. The new store starts fresh and may ignore
all old local progress formats. The old keys/data are left untouched; normal
runtime does not read, import, migrate, dual-write, delete, or fall back to them.

Included:

- One SQLite learning database per app installation/origin, shared by the
  learning repositories for all current learning families.
- Typed repository access for the existing course/identification, comparison,
  and sentence-hunt consumers, preserving their current domain rules.
- Local owner isolation, transactional saves, retries, revision conflicts,
  bounded retention, committed-only progress, and future SQLite schema upgrades.
- Preserve the existing supported course-progress sync projection and its
  delivery boundary exactly, without adding fields or event types. The existing
  limited projection continues; it is not a new or expanded upload.

Not included:

- Importers or compatibility handling for old preferences, JSON documents,
  preference keys, or database formats; old keys are not deleted.
- New cloud storage, cloud history downloads/merges, learner-data uploads beyond
  the existing allowlisted course-learning event projection, backup fallback, or
  new comparison/sentence-hunt sync events. Selected/expected answer values,
  full local attempt records, and checkpoints remain local; the existing
  projection carries only its allowlisted fields.
- Changes to exercise content, scoring, completion rules, French approval,
  audio policy, routes, or unrelated settings/authentication storage.
- Reworking or integrating unpublished Sound Match work.
- Automatic recovery that discards, repairs by replacement, or resets an
  unreadable/unknown-version database.

The database stores learning records, not exercise assets or course catalogues.
Existing SharedPreferences use for unrelated settings/auth state may remain.

## 3. Alternatives and selection

| Approach | Trade-off | Decision |
| --- | --- | --- |
| Keep one serialized preferences document | Minimal change, but retains the single-value quota, coarse rewrites, and app-process-only coordination that motivated this redesign. | Reject. |
| Use a native SQLite package and a separate web persistence implementation | Could use SQLite natively, but would create separate query, schema, and transaction behavior across platforms. | Reject unless Drift cannot meet the qualification gates. |
| Drift typed repositories over SQLite on native and SQLite/WASM on web | One typed Dart schema/repository surface and SQL transactions; web still requires shipped WASM/worker assets and a suitable persistent, synchronized browser backend. | Recommend, subject to SDK/dependency and real-platform qualification. |

The user selected SQLite, not a specific Dart package. Drift is the proposed
cross-platform access layer; SQLite remains the storage engine. No dependency is
added by this specification. Before an implementation plan or dependency change,
verify the installed Flutter/Dart SDK and the declared
`frontend/pubspec.yaml` constraint (`>=3.3.0 <4.0.0`) against the chosen pinned
`drift`, web-support, and code-generation package versions. The current lockfile
does not contain Drift. If a compatible and maintainable Drift configuration
cannot be qualified, return with the concrete incompatibility rather than
quietly substituting a second persistence model.

## 4. Architecture

### 4.1 One database, typed family repositories

Create one lazily opened learning database named independently of legacy
preference keys (proposed logical name: `phoneme_learning`). Native platforms
use an app-private SQLite file; web uses Drift's SQLite/WASM database name in the
current origin's persistent browser storage. The database is common to all
learning activities; feature-specific typed repositories remain separate API
boundaries over that database. There is no database or writer per exercise.

The storage boundary consists conceptually of:

- **Database lifecycle:** open the platform implementation, apply only a known
  schema upgrade, validate the selected web implementation, and expose
  open/unsupported/unavailable outcomes. It does not convert open errors into
  an empty database.
- **Typed learning repositories:** course learning (including identification,
  lessons, drill/game activity already in this store), comparison, and sentence
  hunt. Each keeps its existing typed commands, pure transitions, owner scope,
  and feature-specific read models; persistence is replaced underneath rather
  than wrapping the old whole-document codecs as the long-term database format.
- **Transaction boundary:** all repositories use the same database transaction
  and scope-revision rules. An isolate-local future queue may reduce contention,
  but is not the correctness or cross-tab mechanism.
- **Provider/read-model boundary:** providers publish only rows read from a
  committed database snapshot. Home and progress distinguish loading, new/empty,
  and unavailable states. Unknown/loading/error is never presented as zero or
  “not started.”
- **Current sync adapter:** only the existing course-learning supported-event
  projection reads committed outbox rows and sends the current allowlisted wire
  events through `record_course_events`. Selected/expected answer values,
  full-detail attempt records, and checkpoints remain local; only the existing
  allowlisted event fields are projected. Comparison and sentence hunt remain
  without cloud event delivery.

### 4.2 Platform strategy and qualification

On native Flutter, use Drift's native SQLite executor with an app-private path;
database opening and transactions must not block interactive UI. Use the chosen
Drift background/isolate facility only as an execution detail, not as a
replacement for SQL transactions or revision checks.

On Flutter web, use Drift's current Wasm database API with the matching
`sqlite3.wasm` and Drift worker artifacts. Select only a persistent backend with
real cross-context coordination. Drift's current web documentation describes
OPFS with shared-worker/locking variants and shared-worker IndexedDB as
coordinated options; `unsafeIndexedDb` is explicitly unsafe for multiple tabs,
and `inMemory` is not durable. Those modes are rejected for learning storage.
If required browser APIs, worker support, quota, WASM serving, or deployment
configuration are unavailable, storage is unavailable rather than downgraded.

Web deployment must qualify worker loading, WASM `application/wasm` MIME type,
CSP/resource policy, and any COOP/COEP headers with the actual app and auth
flows. Drift documents that some persistence modes require COOP/COEP and that
those headers can interfere with popup-based authentication. Do not enable those
headers or claim broad browser support without verifying this app's deployment.
The implementation must inspect the backend Drift actually selected and reject
unsupported selections; feature detection alone is not evidence of durable
storage. Browser/database close and reopen behavior must also be exercised, not
assumed from a worker or tab lifecycle.

No browser or device has been probed for this specification. A web build, a
synthetic test, or a Drift compatibility page does not qualify runtime storage.

### 4.3 Conceptual normalized schema

Exact SQL names/types/indexes belong in the implementation plan. The relational
model must preserve these identities and invariants; common scope keys appear as
foreign keys rather than being repeated as mutable JSON documents.

| Relation | Key and purpose |
| --- | --- |
| `learning_scopes` | Unique `(owner_kind, owner_id, course_id, family)`; stores schema version, scope revision, learner-command commit ordinal, and scope availability metadata. Guest and account identities have distinct encodings; account IDs are exact, never concatenated ambiguously. Families distinguish course learning, comparison, and sentence hunt. |
| `learning_content_bindings` | `(scope, activity_id, content_revision, policy identity where applicable)`; stores the registered catalogue fingerprint and only the source/evidence identity fields already supplied by that activity (for example sentence annotation hash). It binds saved work to the content/policy actually used; it does not copy audio, licences, or the full catalogue into the database. |
| `learning_runs` | One current checkpoint per registered activity/section in a scope, keyed by `(scope, activity_id)`; stores run generation, sequence/revision cursor, content and policy identity, completion/run mode, and the typed activity's bounded session snapshot. The snapshot may encode one checkpoint, but never the attempts, aggregates, or entire learner history. Latest command receipt metadata remains available here after bounded receipt-history pruning. |
| `learning_attempts` | One row per committed answer attempt, with stable attempt/command identity, activity/run/item identity, content revision, answer kind, derived correctness, presentation/assistance dimensions, answered/committed times, and commit ordinal. |
| `learning_attempt_values` | Zero or more ordered selected/expected answer-value rows per attempt. Preserve typed identity (including token IDs and repeated occurrences); do not infer or reconstruct a saved answer from a later catalogue. |
| `learning_attempt_evidence` | Per-attempt evidence that the current domain already records, such as exact comparison references/source observations or sentence reference, annotation/content identity, and observed playback source. This records evidence, not audio bytes or a new assertion that the learner listened. |
| `learning_command_receipts` | Per-scope operation token, exact canonical command identity/payload binding, activity/run cursor before and after, commit ordinal, and acknowledgment result identity. Unique scope/token and scope/activity/generation/sequence constraints prevent re-crediting or divergent writers. |
| `learning_mistakes` | Current unresolved, item/revision-scoped mistakes and failure counters, keyed by the current family-specific mistake identity. |
| `learning_summaries` | Typed cumulative buckets and counts, including first/repeat and assistance dimensions where currently used. This is committed progress, not a value recomputed from pruned attempts. |
| `learning_completions` | Idempotent completion records keyed by activity/content/policy identity and threshold where applicable. Historical completion remains distinct from currently registered completion. |
| `learning_exposure` and `learning_best_scores` | Durable teaching exposure and current game best-score identities where the existing family uses them. |
| `supported_sync_outbox` | Only the existing supported course-learning event IDs and allowlisted event payload fields, scoped to the authenticated account/course. No selected/expected answer values, full attempt records beyond those projected fields, checkpoints, recordings, or new event family. |

Use foreign keys and unique constraints for scope, attempt, receipt, run, and
aggregate identities. Validate decoded checkpoint snapshots with their existing
typed domain constructors and registered catalogue; SQL row presence alone does
not make data valid. Immutable course/audio packages remain the source of content
truth. Old schema versions of preferences are not database migrations.

### 4.4 Command, transaction, and retry semantics

Commands are prepared from committed typed state and capture owner/auth
generation, course, family, activity, run generation, expected scope revision,
expected activity cursor, content/policy/catalogue identity, one opaque operation
token, and the complete immutable typed payload. A retry reuses the exact same
token and payload. Reusing a token with a different canonical payload is an
invalid command.

For each command, the database transaction must:

1. Begin a real SQLite write transaction before reading the target scope for
   mutation. Verify the command still targets its captured owner/course/family.
2. Look up the command receipt **before** rejecting an old expected revision.
   A matching token and identical canonical payload returns an idempotent
   acknowledgment without changing answers or aggregates; a matching token with
   a different payload is rejected. A pruned, non-current unproven command is
   stale/conflicting, never assumed to be a duplicate.
3. If there is no receipt, check expected scope revision and the current
   activity/run cursor, content/policy identity, and legal typed transition.
   Use a database compare-and-swap on the scope revision (and the activity
   cursor where applicable); a stale tab receives a conflict and reloads
   committed state instead of overwriting it.
4. Derive the transition through the existing family domain logic. Insert the
   answer attempt/value/evidence rows; update the session position, receipt,
   mistakes, cumulative summaries, completion/exposure/best-score rows and any
   currently supported outbox entries in the same transaction. Enforce
   retention/capacity before commit. A command that cannot retain all required
   state is rejected atomically; it is not partially credited.
5. Increment scope revision and learner commit ordinal according to the existing
   distinction (an outbox acknowledgment may revise local storage without
   creating a learner attempt). Commit. Only after commit succeeds may the
   repository return success and providers publish updated progress.

Cross-tab/process correctness must come from SQLite transactions and revision
checks shared by all connections, not a Dart isolate queue, Riverpod cache,
single-tab mutex, or optimistic preferences-style cache. If the selected web
backend cannot provide those semantics, it is not an accepted learning backend.

On any failure before commit, rollback all command rows and leave the prior
committed progress/checkpoint authoritative. The UI retains a retryable command
in memory while it remains live; retry uses its frozen identity. If commit may
have succeeded but acknowledgment was interrupted, reopening reads the committed
receipt/attempt/checkpoint. Retrying the same retained command is a duplicate
because receipt lookup precedes stale-cursor rejection. A restart without a
live command still resumes from the committed checkpoint and does not replay an
answer. Never display a candidate answer or progress as committed while the
transaction result is unknown; reopen/reload or show unavailable.

### 4.5 Identity, retention, and failure handling

Every query/write is scoped to `(owner, course, family)` plus a registered
activity. Guest and authenticated-account rows cannot collide; a captured old
owner can never be redirected to the current account. Existing A→B→A auth
generation checks remain. A successful old-owner transaction, if already in
flight, can affect only that owner's rows and cannot notify the new owner's
providers.

Preserve the existing detailed-history bounds per owner/course/family: up to
2,000 attempts and up to 2,000 command receipts. Retain the latest receipt
identity in each current run checkpoint even if its receipt-history row is
pruned. Trim whole command batches where attempts are batched. Keep cumulative
summaries, unresolved mistakes, completions, and exposure independent of detail
pruning. Where the current family uses bounded aggregate collections, cap each
such collection at 4,096 identities; refuse an overflowing command without
dropping older durable aggregates. Do not impose the old 36 MiB serialized
document/codec bound as a SQLite database or row limit.

Storage exhaustion, quota denial, permission failure, corruption, unknown
database/schema version, transaction failure, or unsupported web backend must
fail closed. Distinguish a verified new database (successful open/schema setup
and empty query) from a failed read/open. Preserve the database and show
unavailable/retry; never create a second writer, clear data, report zero, or
fall back to SharedPreferences/localStorage/in-memory storage. A successful retry
may reread the committed database; it may not invent an empty state.

Use explicit database schema versioning. Supported upgrades are forward-only,
ordered, and atomic, and must preserve every retained row and its identity.
Unknown newer versions and failed migrations remain untouched and unavailable;
do not downgrade, recreate, or delete the database. This is future SQLite schema
upgrade support only, not import of any old learning format.

Loading state is unknown until a successful database read. Home/progress must
not display zero or “not started” for loading/unavailable storage. Once the new
database has successfully opened and queried as empty, a true new profile may
display zero. Resumed work restores only committed session position and answers;
playback, hearing grants, timers, microphone state, and autoplay authorization
are never restored.

## 5. Behavior preservation and existing sync boundary

The persistence redesign must not change the exercise/domain contracts in the
published FR-08 sentence-hunt design or the current course/comparison behavior.
Keep exact existing answer derivation, review/session policies, completion
eligibility, user-visible availability, audio ownership/source rules, and
committed-only progress. The new store is not permission to change French
content, assessment, or audio qualification.

The checked `course_learning_sync.dart` currently projects only supported
course-learning answer/lesson/score events for authenticated users. Its existing
per-attempt answer event has answer-specific fields `sound`, `skill`, `correct`,
and `activity`, alongside the unchanged `id`/`user_id`/`course_id`/`kind: "answer"`
event envelope. The current sender passes the event unchanged through
`record_course_events`, in batches of at most 100, and acknowledges delivered IDs.
The comparison and sentence-hunt repositories currently have no corresponding
cloud event outbox. Preserve that distinction: keep the existing supported
course sync behavior and wire payload allowlist, persist/ack its outbox rows
transactionally, and add no comparison/sentence uploads or cloud fallback.
Already-uploaded server totals are neither imported nor reset by the fresh local
database. On sign-out, do not copy guest data to an account or vice versa.

## 6. Acceptance and qualification matrix

This matrix specifies evidence required from future implementation work. A fake,
unit test, web build, or documentation lookup is not real browser/native
qualification. If a required browser/device/backend cannot be exercised, that
platform remains unqualified; do not mark the row passed by inference.

| Area | Required evidence |
| --- | --- |
| Shared schema and family isolation | Test new empty schema, exact owner/course/family keys and foreign-key constraints; prove course, comparison, and sentence-hunt records remain isolated while using the same database. Seed unrelated settings/auth preference keys and show they are untouched. |
| Atomic answer and resume | Through each typed repository, hold/fail a command and verify no attempt, aggregate, checkpoint advance, completion, or outbox event becomes visible. After acknowledged writes, close/reopen the database and verify answer plus exact session position/progress return together. |
| Duplicate and lost acknowledgment | Submit once, lose the caller acknowledgment, reopen, and retry the same frozen token/payload; assert exactly one attempt/aggregate/completion/event. Repeat across two independent connections/tabs. Same token with changed payload is invalid. |
| Stale/concurrent writers | In two real web tabs/connections, prepare divergent commands from the same revision; one commits and the other conflicts without lost update. Matching receipt retry succeeds idempotently before revision rejection. Repeat relevant native multi-connection coverage. An isolate-only test does not pass this row. |
| Failure and restart | Exercise injected SQL failure/rollback and a real backend storage-denial/quota path where safely available; reopen and show either the complete previous state or complete committed state, never a partial/false save. Verify app/browser restart recovery and explicit retry. If real error injection is unavailable, record that limitation as an open qualification gate. |
| Retention/full workload | Seed the maximum retained 2,000 attempts and 2,000 receipts for each family, latest receipts/checkpoints, all applicable 4,096-entry aggregate collections, and realistic maximum typed answer/evidence values. Verify reopen, load, further commit, pruning policy, no history-to-summary drift, and failure without data loss at a real browser backend and each native target. Report measured database size and behavior; no size is preapproved by this spec. |
| Content/policy binding | Change a registered content, annotation, or policy fingerprint and prove an old checkpoint cannot be silently replayed against changed content. Preserve historical evidence and current completion labels without rewriting answers. |
| Account boundaries | Exercise guest, account A/B, A→B→A, sign-out during held read/write, and provider replacement. No data crosses scopes and stale work cannot update the visible new owner's progress. |
| Migration and unknown versions | Test every supported schema upgrade with retained rows, plus unknown newer version and failed migration. Upgrade is atomic; unknown/failed data stays untouched and unavailable. Literal old preference formats are neither read, changed, nor deleted. |
| Provider/Home state | Verify database opening is loading/unknown, a verified new database is empty, and errors/unsupported backends show unavailable/retry—not zero, reset, or “not started.” After reload, only committed progress is published; there is no restored autoplay/hearing grant. |
| Existing behavior and sync | Run current course, comparison, sentence-hunt, Home, and progress regressions through the real repositories. Confirm current course sync event allowlist, IDs/payload contract, 100-event batching, acknowledgment/retry, and no new comparison/sentence events. Beyond that unchanged projection, selected/expected values, full local attempt records, and checkpoints are not uploaded. |
| Real platform matrix | On each declared supported browser, qualify the actual selected persistent Drift backend, multiple-tab coordination, worker/WASM loading, MIME/CSP/deployment headers, restart, and full retention. Exercise native iOS and Android application database/restart paths. A platform not run remains OPEN and cannot be advertised as supported by this change. |

Historical capacity evidence explains the replacement but sets no SQLite
capacity guarantee: `docs/superpowers/status/2026-10-17-fr08-sentence-hunt.md`
records an isolated HeadlessChrome 156 localStorage success at 4 MiB and failure
at 5 MiB, sentence documents around 18–32 MB, and a 35,765,729-byte supported
pilot envelope. Its 36 MiB codec ceiling is not a browser quota or SQL maximum.
These serialized-document sizes do not predict the size or quota behavior of
normalized SQLite rows. Real browser/native full-retention results remain
required.

## 7. Future planning boundary and independent gates

A separate implementation plan should first qualify Drift package/SDK versions
and each target's actual SQLite backend, then define the concrete schema,
database lifecycle, transaction/receipt contract, and repository cutover. It
should stage the course-learning, comparison, and sentence-hunt consumer changes
without leaving a parallel preferences writer or silent fallback. The plan
must assign owned paths, test-first regressions, platform verification, and
review/preservation checks. This section is a boundary for that plan, not a task
list or authorization to begin it.

Engineering acceptance does not clear the existing independent French/content,
source-rights/licensing, playback, assistive-technology, privacy, assessment, or
release gates. Follow `docs/french-reference-audio.md` and the FR-08 status record;
pending audio/content is not qualified by the storage redesign. Preserve
unpublished Sound Match work, other branches/worktrees, user changes, and durable
process/evidence records.

## 8. References and inspected baseline

### Repository sources checked

- `docs/superpowers/status/2026-10-17-fr08-sentence-hunt.md` — published
  acceptance boundaries and historical browser-quota observation.
- `docs/superpowers/specs/2026-10-17-fr08-sentence-hunt-design.md` and
  `docs/superpowers/plans/2026-10-17-fr08-sentence-hunt.md` — approved exercise,
  answer, audio, session, retention, and transaction behavior to preserve.
- `frontend/lib/src/core/course/course_learning_persistence.dart` — current
  preferences read/write/restore boundary.
- `frontend/lib/src/core/course/course_learning_transaction.dart` — current
  process-wide transaction kernel, receipt/revision coordination, and recovery;
  the transaction kernel is in this file (there is no
  `course_learning_kernel.dart` at the inspected baseline).
- `frontend/lib/src/core/course/course_learning_store.dart`,
  `comparison_learning_store.dart`, and `sentence_hunt_learning_store.dart` —
  current typed repository and family boundaries.
- `frontend/lib/src/core/course/course_learning_sync.dart` — existing supported
  course event projection and outbox delivery boundary.
- `frontend/lib/src/core/course/course_learning_providers.dart` and
  `sentence_hunt_learning_providers.dart` — current owner-scoped providers.
- `frontend/lib/src/features/home/home_screen.dart` and
  `frontend/lib/src/features/course/course_progress_screen.dart` — Home and
  progress consumers and current loading/recovery surfaces.
- `frontend/pubspec.yaml` — current Dart SDK lower bound and absence of Drift
  dependency; no dependency was installed or changed.

### Current upstream storage documentation

Context7 documentation lookup was attempted but its monthly quota was exhausted;
the official current documentation pages below were consulted instead. These
documents are design inputs, not proof that this app's pinned Flutter/Drift
versions or deployment support the described behavior.

- [Drift web platform](https://drift.simonbinder.eu/platforms/web/) — Wasm
  database setup, worker/WASM asset requirements, storage implementations,
  fallback modes, multi-tab caveats, and COOP/COEP/MIME considerations.
- [Drift native platform](https://drift.simonbinder.eu/platforms/vm/) — native
  SQLite support and background-isolate options.
- [Drift transactions](https://drift.simonbinder.eu/dart_api/transactions/) —
  atomic transaction API and awaiting operations inside transaction callbacks.
- [Drift migrations](https://drift.simonbinder.eu/migrations/) — versioned
  schema upgrades and migration-test tooling.
- [SQLite transactions](https://www.sqlite.org/lang_transaction.html) —
  single-writer behavior, transaction modes, snapshots, and error handling.

No package installation, browser/platform probe, product implementation, or
storage-capacity measurement was performed for this written specification.
