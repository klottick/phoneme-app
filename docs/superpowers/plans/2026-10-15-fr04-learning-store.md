# FR-04 Learning-Store Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace mixed course progress with typed, resumable, owner-isolated learning evidence across all current course/game callers.

**Architecture:** Build immutable contracts, deterministic activity transitions,
one coordinated preferences repository and a supported-cloud adapter. Keep the
old runtime active while foundational PRs land, then switch every consumer and
remove the old course/arcade persistence in one coordinated cutover PR. This is
one subsystem, not separate independently evolving stores.

**Tech Stack:** Dart/Flutter, current Riverpod, shared_preferences and optional
Supabase dependencies; existing pure session/game engines. No database, cloud
schema or model dependency is added. Canonical command proofs use exact strings,
not a new hashing dependency.

**Spec:** [Approved FR-04 design](../specs/2026-10-15-fr04-learning-store-design.md),
published by [PR #30](https://github.com/klottick/phoneme-app/pull/30) at merge
`77144836b0dc9bc60039cf2e54023b16f4e81a09`.

**Status:** Written plan for user review. Spec approval permits this plan, not
implementation. Preserve the existing sequential GPT-6 Luna subagent preference;
the user still must approve this written plan before any worker starts.

## Global Constraints

- "Fresh versioned storage; old development progress is neither imported nor deleted."
- "Keep the newest **2,000 attempt records per owner/course**"; prune whole batches.
- "Submission IDs derive from owner/course/activity/generation/sequence/token plus the batch member index"; Retry keeps that identity.
- "The slot's command sequence is monotonic across run generations, not reset on new-run start."
- "Guest/account histories are never automatically copied or merged."
- "No assessment submission is accepted in this increment."
- "No selected answer, expected key, detailed attempt, mistake, checkpoint, recording/path, speaking or assessment payload enters this outbox."
- "Multi-tab simultaneous writers are unsupported and must not be advertised as safe."
- "No new progression locks are added." Preserve current discovery policy and other lessons' one-pass rules.
- "No browser sandbox bypass is authorized." Playback, linguistic/licensing, FR-15 and release gates stay separate.
- Preserve unpublished Sound Match work, other branches/worktrees and process records; no automatic cleanup.
- Do not change audio asset bytes, provenance, licences, root `LICENSE`, audio ownership contracts or recorder policy.
- Existing SDK constraint `>=3.3.0 <4.0.0` and dependencies remain; no incidental package upgrade or lockfile churn.
- This plan's exact names, signatures, wire values and fixture locations are shared contracts. A worker may propose a correction but not silently invent alternatives.

## Review Focus

1. Lost acknowledgment of the very first run-start: Retry must return the same generation, not create another run (Task 4).
2. Auth moves A→B→A while a save/playback is held: the old A generation must not regain authority (Tasks 4–6).
3. Two valid screens choose different answers for the same next sequence: one commits; the other gets reloadable conflict, not a fake duplicate (Task 4).
4. A Word Match batch straddles retention and save failure: no partial credit, rerolled board or forgotten unresolved mistake (Tasks 3–4, 6).
5. Existing hints/feedback close before the learner submits or resumes: assistance stays recorded, without retroactively assisting the prior answer (Tasks 2–3, 6).

---

## Delivery order and file map

Six sequential implementation/review units. Tasks 1–5 add tested foundations but
do not wire new learning persistence into production callers. Task 6 is the
coordinated runtime cutover; never ship half the screens on each namespace.
Each task starts from published `origin/main` after the preceding PR merges.

| Task | Owned deliverable | Production activation |
| --- | --- | --- |
| 1 | Immutable records, strict codecs, summary math, shared fixtures | None |
| 2 | Registry, lesson/drill commands and pure transitions | None; drill content extraction is value-identical |
| 3 | Typed game snapshots and deterministic game commands | None; old engine APIs retain behavior until cutover |
| 4 | Coordinated preferences repository, replay/retention/recovery | None |
| 5 | Supported sync adapter and auth-bound providers | None; providers are not yet consumed by screens |
| 6 | All six callers, lifecycle/recovery tests, old-store removal | All callers together |

New core files live in `frontend/lib/src/core/course/`; shorthand `core/` below
means that exact directory. New unit tests live in `frontend/test/unit/`, widget
tests in `frontend/test/widget/`, and shared fixtures in `frontend/test/support/`.
File names below are exact; shorthand is used only in interface discussions.

### Contract conventions used by every task

Constructors use named fields listed below, all required unless a default is
shown. Fields are read-only; collections deep-copy and expose unmodifiable
views. A `LessonSectionSession` field is copied on construction and access,
because the existing session is mutable. Every persisted model has `toJson()`
and strict `fromJson(Map<String, dynamic> json)`; only the codec/pure adapters
call those methods, not widgets. Constructor misuse throws `ArgumentError`;
invalid stored payloads throw the typed corruption error. No permissive cast
may silently turn malformed saved state into empty progress.

Canonical JSON sorts map keys recursively; list order is semantic; enum values
are their exact names below. Canonical command text is an exact collision-free
proof, stored once per retained batch plus one latest receipt per activity.
This uses more bytes than a digest but avoids a dependency or bespoke hash.

## Shared API contract

### Domain records (Task 1)

```dart
enum AttemptOrigin { practice, game }
enum AttemptPresentation { firstInRun, repeatInRun }
enum AssistanceFlag { explanationVisible, graphemeHint, afterDebrief, answerRevealed }
enum AttemptAudioSource { pendingRecording, practiceSpeech, notApplicable }
enum AttemptContentState { existingCurated, pending, reviewed }
enum LearningSkill { listening, spelling } // no speaking/assessment submissions
enum CompletionPolicyKind { discoveryThreshold, legacyOnePass }
enum LearningActivityKind { discovery, legacyLesson, drill, soundGame, wordGame }
```

In `core/course_attempt.dart` define `LearningOwner.guest()` and
`LearningOwner.account(String userId)` with value equality, `String? userId`
and `bool isGuest`. `LearningScope({String courseId, LearningOwner owner})` has
value equality and `String get storageKey`. Encode UTF-8 course/account strings
as unpadded base64url; guest tag is `g`, account tag is `a.<encoded-user>`:
`course.learning.v2.<encoded-course>.<owner-tag>`. Never concatenate raw IDs.
`LearningAuthScope({required LearningOwner owner, required int generation,
required bool ready})` is also defined in this file, with immutable fields.

Define sealed `AttemptAnswer` and these immutable subtypes:

| Type | Fields |
| --- | --- |
| `SoundChoiceAnswer` | `String selectedSound`, `List<String> choices`, `String expectedSound` |
| `DrillChoiceAnswer` | `String selectedWord`, `String pairId`, `List<String> choices`, `String expectedWord` |
| `SoundCueAnswer` | `String selectedFamily`, `String wordId`, `String expectedFamily` |
| `WordTileAnswer` | `String wordId`, `int tileIndex`, `String targetSound`, `bool expectedMembership` |

`CourseAttempt` fields: `LearningScope scope`, `String submissionId`,
`String activityId`, `int runGeneration`, `int commandSequence`, `int batchIndex`,
`String itemId`, `int itemOccurrence`, `int contentRevision`, `int commitOrdinal`,
`DateTime answeredAt`, `DateTime committedAt`, `LearningSkill skill`,
`List<String> targetSounds`, `AttemptAnswer answer`, `AttemptOrigin origin`,
`AttemptPresentation presentation`, `Set<AssistanceFlag> assistance`,
`AttemptContentState contentState`, `AttemptAudioSource audioSource`, `bool correct`.
Persist these exact camelCase keys, subtype discriminator `answerKind` and enum
names. Times serialize as UTC ISO-8601; item occurrence starts at 1.

In `core/course_learning_state.dart` define:

| Type | Fields / exact meaning |
| --- | --- |
| `SlotCursor` | `int generation`, `int sequence`, `int revision`; absent slot is all zero |
| `ItemExposure` | `int presentations`, `Set<AssistanceFlag> assistance`; assistance survives closing help |
| `ItemContextKey` | `String itemId`, `String targetSound`; value equality, canonical item/target identity within an activity |
| `RunOptions` | Constructor `RunOptions({LessonPolicy? policy})`; exposed `LessonPolicy policy` uses `LessonPolicy()` when omitted |
| `ActivitySlot` | `String activityId`, `LearningActivityKind kind`, `int contentRevision`, `SlotCursor cursor`, `RunOptions options`, `ActivitySnapshot snapshot`, `Map<ItemContextKey, ItemExposure> exposures`, `CommandReceipt latestReceipt` |
| `CommandReceipt` | `String token`, `String canonicalCommand`, `SlotCursor before`, `SlotCursor after`, `int commitOrdinal` |
| `AttemptBatch` | `String activityId`, `int generation`, `int sequence`, `String token`, `String canonicalCommand`, `List<CourseAttempt> attempts`; nonempty |
| `MistakeKey` | `String activityId`, `String itemId`, `int contentRevision`, `LearningSkill skill`, `String targetSound`; value equality |
| `LearningMistake` | `MistakeKey key`, `String firstWrongId`, `DateTime firstWrongAt`, `String latestWrongId`, `DateTime latestWrongAt`, `int failureCount`, `int lastRunGeneration` |
| `LearningCompletion` | `String lessonId`, `int contentRevision`, `CompletionPolicyKind policyKind`, `int policyRevision`, `int? thresholdPercent`, `DateTime committedAt`; threshold null for legacy |
| `SupportedCloudEvent` | `String id`, `String userId`, `String courseId`, sealed `SupportedCloudPayload payload`; subtypes have named required fields: `CloudAnswer` (`String sound`, `LearningSkill skill`, `bool correct`, `String activity`), `CloudLesson` (`String lessonId`), `CloudScore` (`String game`, `int score`) |

Snapshot types in `core/course_learning_checkpoint.dart`:

- `DiscoveryCheckpoint({LessonSectionSession session})`.
- `LegacyLessonCheckpoint({int wordIndex, String? selectedSound, bool finished})`.
- `DrillCheckpoint({List<String> pairIds, int index, int correct, bool ended})`.
- `SoundGameCheckpoint({SoundBoardState board, ArcadeClockState clock})`.
- `WordGameCheckpoint({WordBoardState board, ArcadeClockState clock})`.

`ActivitySnapshot` is their sealed base. `ArcadeClockState` has integer
`remaining` (0–60), `round` (positive), `score` (nonnegative) and `bool paused`.
New/restored games are paused. `SoundBoardState` has ordered `List<String> board`
(36 entries) and `Set<int> stars`. `WordBoardState` has `board` (16 entries),
`String target`, `int moves`, `int combo`, `Set<int> stars`, `Set<int> obstacles`.
Codec checks sizes/types/ranges; registry/engine transition checks valid content,
reachable state and legal moves without normalizing/re-randomizing corrupt data.
The codec preserves the serialized paused value for exact receipt validation;
screen restoration always starts paused and requires an explicit resume command,
never auto-restarting a saved running timer.

`CourseLearningState` fields are `int schemaVersion = 2`, `LearningScope scope`,
`int revision`, `int commitOrdinal`, `List<AttemptBatch> history`,
`Map<String, ActivitySlot> activities`, `Map<MistakeKey, LearningMistake> mistakes`,
`Map<SummaryKey, SkillCount> summaries`, `List<LearningCompletion> completions`,
`Map<String, int> bestScores`, `List<SupportedCloudEvent> pending`.
Composite map keys serialize as arrays of typed entries, not delimiter strings.
`CourseLearningState.empty(LearningScope scope)` has all counters zero and empty
collections. Nonempty state must have matching nested scope/IDs, positive
ordinals bounded by document counters and coherent slot/receipt/batch metadata.

In `core/course_skill_summary.dart` define `SummaryKey` fields `String sound`,
`LearningSkill skill`, `AttemptOrigin origin`, `AttemptPresentation presentation`,
`Set<AssistanceFlag> assistance`; value equality ignores assistance set order.
`SkillCount({int total, int correct})` validates `0 <= correct <= total`.
Expose:

```dart
Map<SummaryKey, SkillCount> addAttemptCounts(
  Map<SummaryKey, SkillCount> previous, Iterable<CourseAttempt> attempts);
```

Each attempt contributes once to each distinct target sound, never to an
assessment/speaking bucket. Only production reducers create attempts; the codec
checks structural coherence, not authenticity against mutable current content.

`core/course_learning_error.dart` defines distinct exceptions:
`LearningSaveException`, `LearningUnavailableException`,
`LearningConflictException`, `LearningOwnerChangedException`,
`LearningInvalidCommandException`, `LearningCorruptException`,
`LearningUnsupportedVersionException`, `LearningContentChangedException`.
They expose a safe generic message and optional internal cause, never hidden
answer/raw snapshot details to widgets.

### Commands and pure transitions (Tasks 2–3)

`core/course_learning_command.dart` defines `LearningCommand` fields
`LearningScope scope`, `int authGeneration`, `String activityId`,
`SlotCursor expected`, `String token`, `DateTime submittedAt`,
`LearningAction action`, `List<RandomDraw> draws`, `ActivitySnapshot candidate`,
`LearningFeedback feedback`. Define `LearningFeedback` in the same module with
fields `String message`, `int points`, `int cascades`, `int bonus`, `bool? correct`;
`LearningFeedback.none()` has empty message, zero counts and null correctness.
It is presentation output derived by the pure engine, not an accuracy counter.
Both candidate and feedback enter canonical command identity; evaluation replays
and verifies them rather than trusting caller-supplied feedback. Widgets read
`prepared.feedback` for immediate results and existing engine messages, not
re-evaluating answers or executing a second game move. Attempts/summary buckets
do not derive evidence from this presentation text.
`RandomDraw({int upperBound, int value})` is valid only for
`0 <= value < upperBound`. The token is 16 securely random bytes encoded as
22-character unpadded base64url, created once when preparing the command.
Tests inject tokens of that same format.

Sealed `LearningAction` subtypes and named inputs:

- `StartLearningRun({RunOptions options})` (create or explicit replace).
- `ChooseSound({String selectedSound, AttemptAudioSource audioSource})`.
- `ChooseDrillWord({String selectedWord, AttemptAudioSource audioSource})`.
- `AdvanceLesson()`; `ReviewDiscoveryMistakes()`.
- `ObserveAssistance({Set<ItemContextKey> items, Set<AssistanceFlag> flags})`.
- `FinishLearningActivity({bool recordCompletion = true})`; `EndDrill()`.
- `SwapSoundTiles({int first, int second, HeardSoundCue? cue, int elapsedSeconds = 0})`.
- `LinkWordTiles({List<int> indices, int elapsedSeconds = 0})`.
- `CheckpointArcade({int elapsedSeconds, bool paused})`.
- `ContinueArcadeRound()`.

`HeardSoundCue` has `String wordId`, `String targetSound`,
`AttemptAudioSource audioSource`. It is accepted only from a current screen's
successful user-triggered playback; it is not a durable heard permission.
The reducer validates word/target membership and board eligibility. The UI
retires the cue on cancel/failed playback/account change; restored boards start
without a cue. UI-generated source metadata comes from the current catalogue
policy for that word, not guessing from whether audio made noise.

In `core/course_learning_registry.dart`, `LearningRegistry.french()` registers
the five current lesson IDs with activity IDs `lesson:<lessonId>`,
`drill:minimal-pairs`, `arcade:sound`, `arcade:word`. Export the value-identical
`List<MinimalPair> frenchDrillPairs` extracted from `minimalPairsProvider`.
Catalogue exercise IDs identify pilot attempts; other IDs are the existing word
texts/pair IDs scoped to the activity, revision `1`. Keep the current three
drill pairs and all source word/order/policy values exactly unchanged.

`LearningRegistry` exposes `LearningActivityDefinition require(String activityId)`
and `Iterable<LearningActivityDefinition> get activities`. A definition has `String id`,
`LearningActivityKind kind`, `int contentRevision`, `List<LearningSourceItem> items`.
`LearningSourceItem` has `String id`, `String? sessionAlias`, `String? audioText`,
`List<String> choices`, `String? expectedChoice`, `List<String> targetSounds`,
`AttemptContentState contentState`; game definitions expose their finite word
pool as items, with authored membership resolved via `wordByText`, not guessed
from spelling. Game `expectedChoice` is null because the cue/target selects the
key for that move; lesson/drill items have a nonnull expected choice. All fields
are required, including explicitly nullable ones.
`LearningRegistry` and its definition/item records live in the registry module.
No widget may submit arbitrary content/revision/skill/origin. Preserve the pilot's
aliases inside `LessonSectionSession`, with explicit canonical-ID lookup for evidence.

```dart
class LearningTransitionEngine {
  LearningTransitionEngine(this.registry);
  final LearningRegistry registry;
  LearningCommand prepare({required CourseLearningState state,
    required int authGeneration, required String activityId,
    required LearningAction action, required String token,
    required DateTime submittedAt, required Random random});
  LearningTransition evaluate({required CourseLearningState state,
    required LearningCommand command, required DateTime committedAt});
}
```

`LearningTransition` fields: `ActivitySlot slot`, `List<CourseAttempt> attempts`,
`Map<MistakeKey, LearningMistake> mistakes`,
`Map<SummaryKey, SkillCount> summaries`, `List<LearningCompletion> completions`,
`Map<String, int> bestScores`. These are the full proposed next values of those
sections; unrelated activities remain in the input document for repository merge.
Cloud projection, retention and document revision publication belong to Task 4.
Completion `policyRevision` is `1` for both shipped policy kinds; discovery
records its saved threshold separately. Identical lesson/revision/policy records
are never appended twice. Presentation counts/assistance use `ItemContextKey`,
so the same word under a different explicit target is a distinct item context.

`prepare` records every `Random.nextInt` draw used in initial boards/refills,
freezes the resulting candidate, and has no storage side effects. `evaluate`
replays the draws against the committed input; rejects unused/out-of-bounds/
missing draws or candidate disagreement; derives all evidence itself. No random
method other than `nextInt` may influence a persisted transition. Private
recording/replay `Random` adapters can implement `nextBool`/`nextDouble` in terms
of recorded integers if an SDK helper requires them. Reusing a command never
reruns an unrecorded random source.

### Repository, persistence and provider APIs (Tasks 4–5)

```dart
abstract class LearningPersistence {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> restore(String key, String? lastCommitted);
  Future<void> reload();
}
class LearningAuthScope {
  // required immutable fields: LearningOwner owner, int generation, bool ready
}
abstract class CourseLearningStore {
  LearningScope get scope;
  Future<CourseLearningState> load();
  Future<CourseLearningState> retryLoad();
  LearningCommand prepare({required CourseLearningState state,
    required String activityId, required LearningAction action});
  Future<LearningCommit> submit(LearningCommand command);
  Future<SupportedSyncResult> sync();
}
```

`LearningCommit` has immutable `CourseLearningState state`, `ActivitySlot slot`,
`bool duplicate`. Duplicate success returns the current committed state/handle,
not a prior checkpoint. `SupportedSyncResult` has `SupportedSyncStatus status`
(`guest`, `synced`, `pending`, `ownerChanged`) and `int remainingEvents`.

`PreferencesLearningPersistence({Future<SharedPreferences> Function()? preferences})`
uses current preferences APIs; false writes/removals throw. In
`core/course_learning_persistence.dart`, `LearningDocumentCodec` exposes
`String encode(CourseLearningState state)`,
`CourseLearningState decode(String raw, LearningScope expectedScope)` and
`String canonicalCommand(LearningCommand command)`.

`CourseLearningRepository` in `core/course_learning_store.dart` implements the
store. Constructor required: `LearningScope scope`, `int authGeneration`,
`LearningAuthScope Function() currentAuth`, `LearningOwner Function() backendOwner`,
`LearningPersistence persistence`, `LearningTransitionEngine transitions`,
`LearningCloudTransport? cloud`, `DateTime Function() clock`,
`String Function() newToken`, `Random random`; optional `int historyLimit = 2000`.
`backendOwner` checks authoritative backend auth immediately before writes/sends,
in addition to the tracked auth generation; tests inject both signals.

`LearningAuthTracker` in `core/course_learning_providers.dart` is a
`StateNotifier<LearningAuthScope>` with constructor
`LearningAuthTracker({required LearningOwner owner, required bool ready})`,
getter `LearningAuthScope get current`, and
`void observe({required LearningOwner owner, required bool ready})`.
Generation increments on owner changes, not loading-only changes/token refresh;
not-ready state blocks new commands. Keep the captured tracker object, not a
disposed provider `Ref`, in repository callbacks. Old in-flight writes can finish
only under their captured storage scope; an auth transition never changes keys.

Provider declarations, all in that file:

```dart
final learningAuthScopeProvider = StateNotifierProvider<LearningAuthTracker, LearningAuthScope>(...);
final learningRegistryProvider = Provider<LearningRegistry>(...);
final learningPersistenceProvider = Provider<LearningPersistence>(...);
final learningCloudTransportProvider = Provider<LearningCloudTransport?>(...);
final courseLearningStoreProvider = Provider<CourseLearningStore>(...);
final courseLearningStateProvider = FutureProvider<CourseLearningState>(...);
```

The tracker listens to `authControllerProvider`; initialize from backend/current
auth state with `ready=false` while auth initializes. All activity screens watch
store identity; successful commits invalidate `courseLearningStateProvider`.

`LearningCloudTransport` in `core/course_learning_sync.dart` exposes
`Future<void> send(List<SupportedCloudEvent> events)`.
`SupabaseLearningCloudTransport(SupabaseClient client)` implements the existing
RPC only. `SupportedProgressProjector.project({required CourseLearningState before,
required LearningTransition transition, required LearningCommand command})`
returns `List<SupportedCloudEvent>`; guest returns empty. `SupportedProgressSync`
owns per-scope send coalescing; repository-owned acknowledgment uses the same
read/write coordinator, never a second public arbitrary-map update API.
Its constructor takes `LearningScope scope`, `int authGeneration`,
`LearningCloudTransport transport`, `Future<List<SupportedCloudEvent>> Function()
readPending`, `Future<void> Function(Set<String> ids) acknowledge`, and
`bool Function() isCurrent`; its method is `Future<SupportedSyncResult> run()`.
The repository supplies serialized read/ack callbacks that recheck identity.
Project one answer per transition attempt, a lesson event only for a newly added
completion, and a score event only when that game's best score increases over
the prior value (default zero). These rules do not depend on later sync success.

Cloud IDs use fixed activity codes `l0`–`l4` (current lesson order), `d0`, `gs`,
`gw`, course code `c0` for `en-fr`, and
`fr04.c0.<activity-code>.<generation-base36>.<sequence-base36>.<token>.<kind-member>`.
Kind/member is `a0` etc. for answer indices, `l0` for completion and `s0` for score.
Validate positive counters fit the exact portable integer range `<= 9007199254740991`;
reject overflow instead of wrapping. All generated IDs stay below 128 characters
without truncation or a hash. Distinct token/generation/sequence/kind/member
components are collision-free for the accepted fixed-length tokens; callers
generate fresh tokens for different prepared operations.

## Task 1: Immutable state, codecs and summary contracts

**Files — create:**
- `frontend/lib/src/core/course/course_attempt.dart`
- `frontend/lib/src/core/course/course_learning_state.dart`
- `frontend/lib/src/core/course/course_learning_checkpoint.dart`
- `frontend/lib/src/core/course/course_learning_command.dart`
- `frontend/lib/src/core/course/course_learning_error.dart`
- `frontend/lib/src/core/course/course_skill_summary.dart`
- `frontend/lib/src/core/course/course_learning_codec.dart`
- `frontend/test/support/course_learning_fixtures.dart`
- `frontend/test/unit/course_attempt_test.dart`
- `frontend/test/unit/course_learning_codec_test.dart`
- `frontend/test/unit/course_skill_summary_test.dart`

**Interfaces:** Produces the Domain records, command records/actions and errors
above. `LearningDocumentCodec` lives in `course_learning_codec.dart` and is
re-exported by the Task 4 persistence module. No plugin imports in records/codecs.
Fixtures export `guestScope`, `accountAScope`, `accountBScope`, UTC `fixedTime`,
`String tokenFor(int value)` (valid 22-character tokens),
`CourseAttempt sampleAttempt({bool correct = false,
AttemptPresentation presentation = AttemptPresentation.firstInRun,
int sequence = 1, int batchIndex = 0})` and
`CourseLearningState sampleState({LearningScope? scope})`.

- [ ] **1. Write contract tests before models.** Add named tests
  `round trip preserves exact selected and expected answer`,
  `constructors detach nested lists sets and session`,
  `composite keys cannot alias owners or targets`,
  `unsupported version never becomes empty progress`,
  `malformed nested receipt and scope are corrupt`,
  `canonical command ignores map insertion order but not list order`.
  Parameterize malformed integers (`1.0`, `"1"`, negative, overflow), timestamps,
  enum names, duplicate entries and unknown answer kinds.
  Summary oracle:
  ```dart
  final buckets = addAttemptCounts({}, [
    sampleAttempt(),
    sampleAttempt(correct: true,
      presentation: AttemptPresentation.repeatInRun, sequence: 2),
  ]);
  expect(buckets.values.map((c) => c.total).reduce((a, b) => a + b), 2);
  expect(buckets.keys.map((k) => k.presentation).toSet(), {
    AttemptPresentation.firstInRun, AttemptPresentation.repeatInRun});
  ```
- [ ] **2. Run RED:** from `frontend/`, `flutter test test/unit/course_attempt_test.dart test/unit/course_learning_codec_test.dart test/unit/course_skill_summary_test.dart`. Missing-contract compilation failures are expected at this first stage; record them.
- [ ] **3. Implement records, strict codecs, canonical command text and `addAttemptCounts`** using the exact contract above. Serialize errors safely; reject unknown schema versions before nested decoding; validate state counters/identity, not current curriculum meaning. No migration, dependency change or runtime wiring.
- [ ] **4. Run GREEN:** same three tests, then `flutter analyze`. Expect every test passed and no analyzer issues. Include tests for 36/16 board sizes, all answer subtypes, UTC normalization, flag-order equality and unchanged input buckets.
- [ ] **5. Commit only owned files** with `feat: define typed FR04 learning state and evidence`; push scoped branch, open PR against `main`, obtain independent review and controller verification/merge. Report exact RED/GREEN evidence, limitations and approved contracts; do not start Task 2 from an unmerged branch.

## Task 2: Registry and deterministic lesson/drill transitions

**Files — create:**
- `frontend/lib/src/core/course/course_learning_registry.dart`
- `frontend/lib/src/core/course/course_learning_transition.dart`
- `frontend/lib/src/core/course/course_learning_lesson_transition.dart`
- `frontend/test/unit/course_learning_lesson_transition_test.dart`
- `frontend/test/unit/course_learning_registry_test.dart`

**Modify:** `frontend/lib/src/core/providers/app_providers.dart` (only delegate
the existing three-pair list to `frenchDrillPairs`), shared fixtures.

**Interfaces:** Consumes Task 1 records; produces `LearningRegistry`,
`LearningTransition`, and `LearningTransitionEngine.prepare/evaluate` above for
discovery/legacy/drill actions. Game actions return invalid-command until Task 3
adds their implementation. Registry definition lookup is exhaustive; unknown
activities are invalid, not new slots. `LearningTransitionEngine` routes by kind
to the lesson helper; later game helper implements the same internal transition
result, not a second store. Extend fixtures with
`CourseLearningState stateAfter(CourseLearningState state, LearningTransition transition)`
for pure tests, updating the target slot/counters without pretending to be I/O.

- [ ] **1. Write failing tests** `registry retains pilot canonical ids aliases order and ten items`, `drill extraction is value identical`, `invalid selected choice cannot create evidence`, `eight of ten reaches saved 80 percent only at debrief`, `unseen item cannot be replaced by repeated correct word`, `review round contains only unresolved items in authored order`, `same sound different item cannot resolve mistake`, `new run preserves unresolved mistakes`, `legacy explanation and opened reference remain assisted`, `closing help and pruning detail cannot make repeated item first`, `review only finish never completes lesson`, `content mismatch requires explicit new run`.
  Use the actual ten-item catalogue and `LessonSectionSession`, not a replacement
  fake session. Oracle after wrong first/correct review: first bucket `0/1`,
  repeat bucket `1/1`, no remaining mistake for that item, saved first wrong
  attempt still present in the transition inputs/history fixture.
  In `same sound different item cannot resolve mistake`, pin:
  ```dart
  expect(afterCorrectOther.mistakes.containsKey(wrongItemKey), isTrue);
  expect(afterCorrectSame.mistakes.containsKey(wrongItemKey), isFalse);
  expect((afterReview.slot.snapshot as DiscoveryCheckpoint).session.round, 2);
  ```
  Variables are the engine transitions produced by the named fixture sequence,
  and `wrongItemKey` identifies the original wrong source item/revision/target.
- [ ] **2. Run RED:** `flutter test test/unit/course_learning_registry_test.dart test/unit/course_learning_lesson_transition_test.dart`. Confirm missing engine or named assertions fail for the intended reasons.
- [ ] **3. Implement registry, pure lesson engine and content extraction.** Start increments generation and slot sequence; run revision becomes zero. Other commands increment slot sequence/revision. Derive selections/targets/skills from content, increment occurrence per item, union exposure flags monotonically, update mistakes and buckets together. A discovery answer submits to a cloned existing session; advance/review operate on that session. Legacy answer/advance obey its one-pass flow; drill uses pair index/order and increments correct count only in the candidate. `FinishLearningActivity` applies the saved policy and adds completion only when `recordCompletion` is true on a lesson; review routes pass false even when resuming a normal-route run. Do not persist route review mode as a permanent property of a shared run. `EndDrill` marks ended without a pronunciation grade. Current content/revision remains unchanged.
- [ ] **4. Run GREEN:** targeted tests plus `test/unit/lesson_section_session_test.dart test/unit/lesson_section_curriculum_test.dart test/unit/lesson_section_content_test.dart`, then `flutter analyze`. Expect no failures/issues; existing production still uses old storage.
- [ ] **5. Commit only owned files** with `feat: derive typed lesson and drill learning transitions`; publish/review/verify/merge sequentially under the shared delivery gate.

## Task 3: Deterministic typed arcade transitions

**Files — create:**
- `frontend/lib/src/core/course/course_learning_game_transition.dart`
- `frontend/lib/src/core/course/course_learning_random.dart`
- `frontend/test/unit/course_learning_game_transition_test.dart`
- `frontend/test/unit/course_learning_random_test.dart`

**Modify:**
- `frontend/lib/src/core/course/course_learning_transition.dart` (game dispatch)
- `frontend/lib/src/features/arcade/sound_match_engine.dart`
- `frontend/lib/src/features/arcade/word_match_engine.dart`
- `frontend/lib/src/features/arcade/arcade_session.dart`
- shared fixtures; `frontend/test/unit/course_arcade_test.dart` only for added typed snapshot assertions, keeping current tests intact.

**Interfaces:** Consumes Task 1–2 contracts. Add
`WordBoardState snapshot()` / `SoundBoardState snapshot()` to the respective
engine, and named constructors `WordMatchEngine.fromState(WordBoardState state,
{required Random random})` / `SoundMatchEngine.fromState(SoundBoardState state,
{required Random random})`. Those constructors strictly restore without an
initial refill/shuffle or ignored invalid indices. Leave current constructors,
`submit`, `swap`, `toJson`/`restore` behavior unchanged for still-active legacy
callers; these old map methods are removed from runtime use in Task 6.
Add `ArcadeClockState snapshot()` and
`ArcadeSession.fromState(ArcadeClockState state)` without permissive clamps.
The new game transition helper captures input tiles before calling existing
engines, so no temporary change to `WordMove.evidence` is required.

`RecordingLearningRandom(Random source)` has immutable getter
`List<RandomDraw> get draws`. `ReplayLearningRandom(List<RandomDraw> draws)`
validates draw bounds and exposes `void requireExhausted()`; both implement
`Random`. `prepare` stores the recorded transcript and candidate; evaluation
consumes it exactly. Constructors from state never consume draws.

- [ ] **1. Write failing tests** `same frozen command replays identical board stars and score`, `replay rejects unused missing or wrong-bound random draws`, `two equal word tiles are two attempts`, `invalid geometry and automatic clears produce no attempts`, `wrong chain snapshots words before any mutation`, `single heard family gets one answer and existing 100 bonus`, `ambiguous family or unavailable audio gets no answer`, `board removed cue is retired unscored`, `first four moves keep grapheme hint exposure`, `feedback assists only subsequent occurrence`, `pause elapsed and continue preserve existing 60 second rules`. Mutating a submitted chain/board/draw list afterward must not change the prepared command.
  Pin deterministic replay and explicit-tile counts:
  ```dart
  expect(replayed.slot.snapshot.toJson(), prepared.candidate.toJson());
  expect(tileResult.attempts.length, selectedIndices.length);
  expect(tileResult.attempts.map((a) => a.batchIndex).toSet().length,
    selectedIndices.length);
  expect(ambiguousCueResult.attempts, isEmpty);
  ```
  Prepare/evaluate use the same pre-move state and injected random fixture;
  `selectedIndices` includes two different positions containing the same word.
  Also pin `prepared.feedback.message`, points, cascades and bonus against the
  existing engine/UI outputs on the identical input fixture; subsequent replay
  must verify the same feedback without consuming a new random source.
- [ ] **2. Run RED:** `flutter test test/unit/course_learning_random_test.dart test/unit/course_learning_game_transition_test.dart`. Record the missing typed restore/dispatcher failures.
- [ ] **3. Implement strict typed snapshots, replay random and game reducer.** Reuse existing scoring/matching algorithms. Validate submitted indices/cue membership, derive one batch from explicit selected tiles or one qualified cue, and freeze the post-move board/score with the same receipt. Apply a move's frozen `elapsedSeconds` before that move in the same transition; if time reaches zero, reject the move and require a clock-only checkpoint, never grant post-timeout points. Word feedback updates exposure for later attempts only; intro preview is `explanationVisible`. Clock checkpoint deltas must be nonnegative and no more than available time; resume/continue clears transient cue state. No engine refactor unrelated to deterministic snapshots.
- [ ] **4. Run GREEN:** targeted tests and `flutter test test/unit/course_arcade_test.dart`, then `flutter analyze`. Seeded legacy engine tests must remain unchanged; compare old/new action outcomes on identical typed input fixtures.
- [ ] **5. Commit only owned files** with `feat: make arcade learning transitions replayable and typed`; publish/review/verify/merge before repository work begins.

## Task 4: Coordinated local commits, replay protection and retention

**Files — create:**
- `frontend/lib/src/core/course/course_learning_persistence.dart`
- `frontend/lib/src/core/course/course_learning_store.dart`
- `frontend/lib/src/core/course/course_learning_sync.dart` (projector and transport/result contracts only; delivery in Task 5)
- `frontend/test/support/course_learning_persistence_fakes.dart`
- `frontend/test/unit/course_learning_store_test.dart`
- `frontend/test/unit/course_learning_commit_isolation_test.dart`
- `frontend/test/unit/course_learning_retention_test.dart`

**Modify:** shared fixtures only. The store may initially return `pending` from
`sync()` when a transport is configured; Task 5 supplies delivery. Define the
transport/result/projector contracts in `course_learning_sync.dart` in this task
so local commits already queue the exact supported projections; Task 5 adds the
network implementation, never a second event-generation path.

**Interfaces:** Produces the persistence/repository/codec API above. Private
process-wide coordinator serializes all repository reads, writes, rollback,
retryLoad and acknowledgment across instances. Tests use injected independent
store instances sharing one fake or real preferences adapter. The projector
must be ready here because omission from an answer commit is not atomic backup.

- [ ] **1. Write failing store tests** for: `lost initial start acknowledgment returns same generation`; `same token payload retry is no op`; `different token same next sequence is conflict`; `same retained identity changed payload is invalid`; `older current run receipt never rewinds`; `old generation and pruned proof are stale`; `fresh run requires zero-answer creation`; `unrelated activities merge while same activity conflicts`; `corrupt and future-version bytes remain exact`; `old namespaces remain unread unmodified and undelivered`.
  Held-boundary oracle:
  ```dart
  final saving = store.submit(answer);
  await fake.writeEntered.future;
  final reading = secondStore.load();
  expect(fake.platformValue, committedBefore);
  fake.rejectWrite();
  await expectLater(saving, throwsA(isA<LearningSaveException>()));
  expect((await reading).history, committedState.history);
  ```
  Fake must actually model preferences' optimistic cache and platform image,
  not merely return an error before the candidate enters the cache.
- [ ] **2. Run RED:** `flutter test test/unit/course_learning_store_test.dart test/unit/course_learning_commit_isolation_test.dart test/unit/course_learning_retention_test.dart`. Preserve exact first failing output.
- [ ] **3. Implement repository commit/recovery and supported event projection.** Duplicate lookup precedes ordinary stale-cursor rejection. For new commands validate both auth sources, evaluate against latest committed document, queue supported projections, append whole batches and trim oldest batches to 2,000. Persist candidate once; only publish after acknowledgment. On failure restore last committed cache/image inside the coordinator. If repair fails, block that scope; `retryLoad()` must successfully restore/reload/compare its remembered committed image before allowing writes, not adopt a rejected optimistic candidate. Never repair corrupt/unknown-schema source bytes into empty state. Successful old-owner in-flight writes finish only in their captured scope.
- [ ] **4. Add pruning, auth and projection assertions**, then run GREEN. Cover at least 2,016 submitted tile attempts with batches crossing 2,000; correct lifetime counts/retained whole batches; unresolved mistakes and pending events survive. Force the same suite with `historyLimit: 16`. Exercise guest/A/B and A→B→A at queued and in-platform-write boundaries; authoritative backend-owner mismatch rejects even before auth provider catches up. Verify portable counter overflow rejects without writing. Projector tests prove guest/unsupported payload exclusion, supported lesson/game allowlists, stable distinct IDs shorter than 128 characters, and no hidden answer fields in wire payloads.
- [ ] **5. Run real-adapter negative controls.** Hold a real `PreferencesLearningPersistence` platform mock after cache update; reject it and verify second-store reads and a queued sync cannot see its event. Temporarily disable coordinator/rollback checks in the worker's owned code to demonstrate the regression test fails, restore those edits, rerun GREEN, and record the diff of the negative control privately. Run all three targeted files and `flutter analyze`; do not commit the intentionally broken variant.
- [ ] **6. Commit only owned files** with `feat: commit FR04 learning progress with bounded replay protection`; publish/review/verify/merge. Report that crash durability and multi-tab writes are deliberately not guaranteed.

## Task 5: Supported cloud delivery and auth-bound providers

**Files — modify:** `frontend/lib/src/core/course/course_learning_sync.dart`,
`frontend/lib/src/core/course/course_learning_store.dart` (delivery integration).
**Create:**
- `frontend/lib/src/core/course/course_learning_providers.dart`
- `frontend/test/unit/course_learning_sync_test.dart`
- `frontend/test/unit/course_learning_providers_test.dart`

**Interfaces:** Consumes Tasks 1–4 store/projector contracts. Produces transport,
sync/tracker and providers above. Auth tracker observes the auth controller's
identity transitions, including A→B→A, while ordinary loading/error/token-refresh
updates with the same owner do not manufacture a new identity. `currentAuth`
callbacks retain that tracker object. Do not modify auth/profile/streak schemas.

- [ ] **1. Write failing tests** `offline guest learning requires no backend`, `provider rebuild tracks owner epoch not only equal final id`, `initial loading cannot save into guest scope`, `100 event batches use exact legacy wire shape`, `failed send and ack retain stable ids`, `ack removes only sent ids while another activity commits`, `held failed local candidate never reaches transport`, `auth change prevents next batch and new-owner acknowledgment`, `sync coalesces same scope but not guest and another account`, `supported synced status never claims detailed history backup`.
  With 201 committed supported events, pin:
  ```dart
  expect(transport.batches.map((b) => b.length).toList(), [100, 100, 1]);
  expect(result.status, SupportedSyncStatus.synced);
  expect(result.remainingEvents, 0);
  expect((await store.load()).pending, isEmpty);
  ```
  `transport` is a recording implementation of `LearningCloudTransport`;
  after injected send failure the same fixture expects `pending` and unchanged
  unsent IDs, not a synthetic empty queue.
- [ ] **2. Run RED:** `flutter test test/unit/course_learning_sync_test.dart test/unit/course_learning_providers_test.dart`. Tests must exercise repository `sync()` plus the transport adapter, not only a fake queue algorithm.
- [ ] **3. Implement RPC delivery and provider wiring.** Send at most 100 committed supported events; network awaits stay outside the local coordinator. Recheck auth/backend owner before each send; acknowledge IDs on captured owner scope only if its generation remains current. If auth changed after send, leave events for later safe replay rather than acknowledging under a new identity. Send/ack failures return pending with the remaining count; preserve IDs for server deduplication. Serialize/coalesce same-scope sends across store instances. No reads of old local queues, cloud-download queries or backend migrations.
- [ ] **4. Run GREEN:** targeted files plus Task 4 store/isolation suite and `flutter analyze`. Verify no production screen yet imports the new providers; the old runtime remains coherent through this merge.
- [ ] **5. Commit only owned files** with `feat: wire owner scoped FR04 backup and providers`; publish/review/verify/merge. Record missing external Supabase/live credentials testing as a limitation, not a passing live-cloud check.

## Task 6: Coordinated caller cutover and old-store removal

**Files — modify:**
- `frontend/lib/src/features/course/discovery_lesson_screen.dart`
- `frontend/lib/src/features/course/course_lesson_screen.dart`
- `frontend/lib/src/features/course/course_progress_screen.dart`
- `frontend/lib/src/features/drills/drill_screen.dart`
- `frontend/lib/src/features/arcade/arcade_screen.dart`
- `frontend/lib/src/features/home/home_screen.dart`
- `frontend/lib/src/features/course/discovery_section_view.dart` only for typed recovery/notice inputs, preserving teaching and accessibility behavior.
- Existing test consumers enumerated below; shared fixtures/fakes only as needed.

**Delete after all consumers switch:**
- `frontend/lib/src/core/course/course_progress.dart`
- `frontend/lib/src/core/course/lesson_section_store.dart`

**Create:**
- `frontend/test/widget/course_learning_cutover_test.dart`
- `frontend/test/widget/course_learning_resume_test.dart`
- `frontend/test/widget/course_learning_game_commit_test.dart`
- `frontend/test/widget/course_learning_progress_test.dart`
- `frontend/test/support/course_learning_widget_store.dart`

**Adapt existing tests, preserving behavioral assertions:**
- Unit: `lesson_section_store_test.dart`, `progress_commit_isolation_test.dart`,
  `lesson_section_progress_integrity_test.dart`, `course_sync_test.dart`,
  `course_arcade_test.dart`.
- Widget: `course_flow_test.dart`, `discovery_lesson_test.dart`,
  `discovery_lesson_review_repeat_test.dart`,
  `discovery_lesson_recovery_test.dart`,
  `discovery_lesson_recovery_accessibility_test.dart`,
  `course_curriculum_migration_test.dart`, `arcade_switch_test.dart`,
  `course_audio_lifecycle_test.dart`, `course_recording_lifecycle_test.dart`,
  `drill_audio_lifecycle_test.dart`.
  Replace old-map/store APIs with new typed fixtures/assertions; old-save import
  assertions specifically become old-byte preservation/no-import assertions.
  Keep pure session/content/audio tests unchanged unless their imports alone
  need adjustment. Do not delete a regression merely because it fails cutover.

**Interfaces:** All six screens consume `courseLearningStoreProvider` and
`courseLearningStateProvider`. Screens retain one immutable pending
`LearningCommand` and captured store until acknowledgment, explicit Reload or
owner replacement. Use `prepare` for candidates and immediate discovery
correctness feedback, `submit` for authoritative state; never recalculate
correctness or mutate counts independently in widgets. Widget fake implements
the complete `CourseLearningStore` contract, with held/failing load/submit paths;
at least the new cutover/game tests use the real repository and preferences mock.

- [ ] **1. Write new failing end-to-end cutover tests.** Seed literal old
  course/arcade/outbox bytes and unrelated auth/profile/streak keys. Visit all
  six screens; assert fresh typed progress, untouched old bytes and no old-event
  sends. Named tests: `all learning surfaces use same committed typed state`,
  `one failed answer blocks advance and retry credits once`,
  `reopen resumes next unanswered item but never restores hearing`,
  `wrong first and successful retry stay separately visible`,
  `whole game batch failure retains same frozen board for retry`,
  `new owner does not receive delayed old owner feedback or score`,
  `corruption shows unavailable without destructive fresh start`.
  Before runtime wiring, these fail on old namespace/count/resume behavior.
  New-format/progress and negative-audio assertions include:
  ```dart
  expect(find.text('This alpha uses a new progress format. Earlier development progress has not been imported.'), findsOneWidget);
  expect(find.textContaining('not assessed'), findsWidgets);
  expect((await store.load()).history.length, beforeFailedAudio.history.length);
  ```
- [ ] **2. Run RED:** `flutter test test/widget/course_learning_cutover_test.dart test/widget/course_learning_resume_test.dart test/widget/course_learning_game_commit_test.dart test/widget/course_learning_progress_test.dart`. Record the concrete mismatches, not just missing provider imports.
- [ ] **3. Switch discovery, other lessons and drill together.** Preserve
  generation guards, single-shot pending saves, audio cancellation and hidden
  item semantics. Discovery immediate Correct/Not yet uses the frozen candidate;
  counts/completion refresh only on commit. Review-only finish uses
  `FinishLearningActivity(recordCompletion: false)` and never completes;
  Practise again is explicit StartLearningRun. Legacy/drill answer failure has
  Retry and blocks Next; correct count comes from checkpoint. On resume require
  fresh playback, restore submitted feedback only for committed answers and
  offer explicit new-run start for incompatible content. Corruption/unknown
  schema block that scope; remove the old discovery auto-overwrite-on-next-save
  recovery. Reference opening sends ObserveAssistance with visible item/target
  keys; per-target context prevents help on one target relabeling another.
- [ ] **4. Switch arcade checkpoint/evidence writes.** Replace direct
  `SharedPreferences` and `_store.record/saveScore` with typed commands.
  Current screen captures heard cue word/source before clearing it. Every move
  snapshots timer delta, engine state, points and explicit evidence together;
  include timer delta in the prepared move by first applying a frozen clock
  adjustment in that same command, not a preceding separate commit. Use the
  move actions' defined `elapsedSeconds` field for this purpose. Pause timer
  and block further input during pending save/Retry. Resume
  or Reload uses committed board; Retry uses original random transcript. Intro,
  hints and corrective feedback update durable exposure, without changing what
  the game shows. End/pause/continue go through typed checkpoints; no raw board
  namespace remains active.
  Accumulate integer timer ticks only while active and not busy/paused, as the
  current game does; do not use wall-clock catch-up that charges save latency or
  background time. Freeze that delta when preparing a command and clear it on
  commit or explicit Reload of the committed board; Retry must not add it a
  second time. Clamp a clock-only expiry
  checkpoint to remaining time, never submit an expired scoring move.
  Use the prepared command's typed feedback for the existing Word Match
  message and Sound Match cascade/points/bonus text. The pure adapter obtains
  it from the same engine execution that produced the frozen checkpoint; UI
  code neither drops that feedback nor reconstructs correctness/scoring itself.
- [ ] **5. Switch home/progress/review and pin exact copy.** Home counts only
  committed current-revision completions; no new locks. Progress shows separate
  practice/game, first/repeat/assistance counts with sample sizes and unresolved
  sounds; speaking/assessment are "not assessed". Preserve current routes for
  review, with unavailable content labeled nonreviewable instead of crashing
  `firstWhere`. Display the spec's exact new-format and supported-backup copy;
  offline copy promises local commits only. Old cloud totals are not reset or
  presented as equal to new local history.
- [ ] **6. Adapt regression suites and remove obsolete contracts.** Replace
  only storage-dependent test setup/assertions; maintain lifecycle, double-tap,
  busy-owner, accessibility, TTS/recording-error, debrief, repeat and audio policy
  coverage. Delete the two old runtime modules only after all callers compile.
  Rename old store regression files only if their new purpose becomes unclear;
  document one-to-one mappings instead of dropping coverage. Supplement with
  `rg 'CourseProgressStore|lessonSectionStoreProvider|courseProgressProvider|course\.v1\.|arcade\.v1\.' lib` from `frontend/`; expect no active runtime usage (historical documentation/test fixtures may mention old keys).
- [ ] **7. Run GREEN and negative controls.** Run the four new widget files,
  every adapted existing file listed above, then full `flutter test` and
  `flutter analyze`. Hold game/answer platform saves while double-tapping,
  pausing/resuming, ending sessions, disposing and switching A→B→A. Disable one
  save-generation guard and one game-batch atomicity boundary in separate
  temporary negative controls; their targeted tests must fail, then pass after
  restoration. Record exact commands/outputs privately; commit no broken code.
- [ ] **8. Commit only owned files** with `feat: cut course and arcade over to typed learning history`; push PR, request independent spec/code review, resolve blockers and rerun affected tests before controller merge. This is intentionally one coordinated activation PR, not six independently shipped caller migrations.

## Controller delivery and final verification gates

Apply to each task; workers implement sequentially and never merge PRs or spawn
subagents. The controller supplies task text, owned files, accepted upstream
interfaces and test commands. Resolve GPT-6 Luna against available models before
dispatch; do not silently fall back to Qwen or replay the earlier degeneration.

- [ ] Before each task: fetch `origin/main`, preserve unrelated work, use an
  isolated scoped branch/worktree under the existing project, run baseline tests
  appropriate to that task. No dependent work starts on an unmerged baseline.
- [ ] Worker records RED/GREEN commands/results, limitations and PR URL; stages
  only owned files. No direct push to `main`, force push or local merge delivery.
- [ ] Controller reviews actual PR diff for scope/spec/quality and obtains
  independent code review. Return blocking findings to that implementer; verify
  fixes rather than accepting a completion report.
- [ ] Before every merge, inspect exact head/current base, GitHub feedback and
  checks, rerun applicable tests independently. Missing CI is not a pass. If
  head/base changed, re-evaluate integrated tree and affected evidence.
- [ ] For Task 6's integrated head, from `frontend/` run `flutter test`,
  `flutter analyze`, and `flutter build web --release`; from repository root run
  `python3 -m unittest discover -s scripts -p 'test_*.py' -v` and
  `python3 scripts/verify_french_audio.py --repo-root .`.
  Expect zero test/analyzer/build failures and honest audio-verifier pending
  status, not falsely reviewed audio. Existing Wasm warnings do not certify Wasm.
- [ ] Compare tracked audio/licence asset hashes to Task 6's current base;
  ensure no incidental product/dependency/backend changes. Source search and
  full test compile prove no obsolete runtime store import remains.
- [ ] Merge only the reviewed PR when all blockers are resolved; verify merged
  published tree equals reviewed tree or rerun affected integrated checks.
  Record PR URL, reviewed head, current base, merge commit, commands/results,
  review dispositions and outstanding playback/linguistic/privacy/release gates
  under `.superpowers/`. Preserve branches/worktrees/evidence after delivery.

## Plan self-review and execution handoff

Coverage: spec sections 1–3 → Tasks 1–3 and caller cutover; section 4 → Task 4;
section 5 → Tasks 1/4/6; section 6 → Tasks 4–6; section 7 → Tasks 4–6;
section 8 → each task's regressions and controller gates. All five Review Focus
conditions have named owning tests. No assessment, migration, cloud-download or
new game/UI subsystem has been smuggled into the cutover.

This plan preserves sequential Luna subagent implementation and independent
review. User review of this written plan is the next gate. No implementation
starts and no plan is treated as execution approval merely because the spec
was approved. After approval, publish/merge this documentation through its PR,
then use subagent-driven-development for Task 1 from that published baseline.
