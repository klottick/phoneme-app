# FR-07-B Phoneme Comparison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the optional, local-only ten-pair French Same/Different comparison activity without changing the existing identification pilot or its saved v2 behavior.

**Architecture:** Keep authored pair content and its typed relation in core, and validate the complete activity before exposing its route or loading its profile. Extract one typed family-aware transaction coordinator from the existing learning repository, retain the v2 adapter’s public state/codec/key/fingerprints, and give comparison an independent schema-1 payload, transition and profile. Reuse the existing finite session policy and a narrow shared lesson-owner seam for playback generations, frozen retry and lifecycle fencing; the new owner/view composes that seam rather than cloning the discovery screen.

**Tech Stack:** Existing Dart/Flutter, Riverpod, go_router, `LessonSectionSession`, typed course audio contracts, SharedPreferences-backed learning persistence and current controlled-widget/store test fakes; no new dependencies.

**Spec:** [Approved FR-07-B design](../specs/2026-10-17-fr07b-phoneme-comparison-design.md), approved for plan writing after reviewed PR55 head `60ce881368dba16bac5766e5a071bb8e6e5f9411` merged as `c2b11ce271e9a65122d7af5dc97ed8eea3eed528`.

## Global Constraints

- The plan is a separate approval gate. No implementation starts until the user approves this plan; plan publication is not feature delivery.
- Comparison identity is activity/section `en-fr-phoneme-comparison`, content revision `1`, route `/course-comparison/en-fr-phoneme-comparison`, key `course.learning.comparison.v1.<base64url-course>.<owner-tag>`; guest tag `g`, account tag `a.<base64url-account>` using v2 component encoding.
- Author exactly ten ordered IDs `fr07b-pair-01`…`fr07b-pair-10`, with keys `Different, Same, Same, Different, Different, Same, Different, Same, Same, Different`; five of each, six vowel/four consonant, 20 slots/13 distinct existing pending references. Copy references, target ordinals, instructions, and notes from spec §3.2 exactly. No phonetic heuristic, new asset, annotation edit, FR-01 readiness change, or linguistic-truth claim.
- New pair content is `ContentPurpose.practice` and `ContentReviewState.pending`. Reject missing declarations, unknown references/targets, duplicate records, invalid ordinals, target/key disagreement, and imbalance before comparison load/start; unrelated existing practice remains available.
- Core owns typed same/different relation and answer. `SoundComparison` remains neutral controlled presentation and reports typed intent only. Do not convert pair answers into `ChooseSound`, `CourseAttempt`, per-sound summaries/mistakes, or cloud events.
- Keep public v2 APIs, schema 2, key, canonical command bytes/fingerprints, backup behavior, readonly pending counts, quarantine, rollback/cache repair, and cloud acknowledgment behavior byte/behavior compatible. No schema-1 `CourseLearningState`, dynamic/Object-erased family payloads, fake course ID, second writer, or second transaction/retry engine.
- Comparison has a distinct local document family and schema-1 typed payload with pair attempts, pair mistakes, pair summaries, completion, checkpoint/session and family-scoped receipts; no cloud outbox. Same owner/course is allowed, but family never shares documents or receipts.
- Use normal-variant `alphaPractice` reference playback with `allowPracticeTts: false`; exact disclosure: “Alpha audio: recordings are unverified; device speech is practice-only.” Do not promote manifest status, change audio bytes/provenance/licences/root `LICENSE`, or substitute TTS after recording failure.
- Playback is successful only for exact current activity/run/round/pair/slot/reference/UI generation and actual typed source/reference. Fresh A/B grants are transient; claim both synchronously into the immutable command. Saved observations are provenance, never restored hearing permission. Frozen save retry may reuse its observations without replay; all store/auth/route fences remain.
- Retain saved default 80% policy, ten-item first pass, all-attempted/debrief threshold eligibility, ordered finite unresolved rounds, optional review even on a pass, and no completion from review-mode Finish. Deliberate new runs preserve historical evidence, mistakes and completions.
- Add separate labeled Home and progress entry/read models, preserving primary discovery and all four legacy links. A comparison profile failure is locally unavailable and cannot block identification. Existing `/compare` remains the microphone activity.
- Review links resolve exact comparison activity and pair to the dedicated screen/finite queue; never route through the first lesson containing a target sound. Keep `first-in-run`/`repeat-in-run` and `after-debrief` attribution distinct; label summaries “comparison practice, not phoneme mastery.”
- Test with `/home/klottick/develop/flutter/bin/flutter` (`$FLUTTER`) and `--no-pub`, from `frontend/`; do not install dependencies. New async tests release audio/write gates in teardown and do not use `pumpAndSettle` while work is held.
- Scope each task to its listed owned paths. Each implementation task starts from freshly fetched published `origin/main` only after the predecessor PR is reviewed, verified, merged and the merged tree checked; sequential `openai/gpt-6-luna` worker, no worker subagents/merges. Test-first behavior regressions, explicit owned-file staging, scoped PR to `main`, independent review, controller exact-diff/head/base/checks review and verification, merge only through approved PR. Missing CI is not passing CI.
- Preserve local/unpublished Sound Match work, branches, worktrees, user data and `.superpowers/` evidence. At each task, capture `BASELINE=$(git rev-parse origin/main)` only after its predecessor merge; record `git status --porcelain=v1 -z > /tmp/opencode/fr07b-status-$TASK.before` and `git ls-files --others --exclude-standard -z > /tmp/opencode/fr07b-untracked-$TASK.before`. Use an `OWNED=(...)` bash array copied exactly from that task’s **Files** block. NUL-safe baseline verification:

  ```bash
  while IFS= read -r -d '' p; do
    owned=false
    for q in "${OWNED[@]}"; do [[ "$p" == "$q" ]] && owned=true && break; done
    if [[ "$owned" == false ]]; then
      [[ -f "$p" ]] || { echo "missing unowned: $p" >&2; exit 1; }
      expected=$(git rev-parse "$BASELINE:$p")
      actual=$(git hash-object -- "$p")
      [[ "$expected" == "$actual" ]] || { echo "changed unowned: $p" >&2; exit 1; }
    fi
  done < <(git ls-tree -r -z --name-only "$BASELINE")
  ```

Also inspect `git diff --name-only -z "$BASELINE"` and require every changed tracked path in `OWNED`; compare initial `fr07b-untracked-$TASK.before` entries and contents after work, allowing no deletion/overwrite. Avoid glob/line-based path parsing (accented filenames exist). Do not reset, clean, delete or overwrite preserved work. Controller owns final outcome records.
- Technical tests do not constitute French linguistic/audio review, rights/licensing clearance, native/browser playback or assistive technology acceptance, privacy review, assessment suitability, or release readiness. These remain explicit gates.

## Review Focus

1. Malformed or incomplete comparison content must reject the entire comparison branch before profile load/start while unrelated practice stays usable. Task 1 owns `comparison_catalogue_rejects_incomplete_duplicate_and_unknown_content`; Task 5 owns `comparison_catalogue_failure_precedes_profile_load`.
2. Malformed, future, wrong-family/owner or unknown-field comparison bytes must remain untouched/unavailable without affecting valid v2 state. Task 3 owns `comparison_codec_preserves_unsupported_bytes_and_v2_sibling`.
3. Pair evidence must never leak into single-sound summaries/mistakes or cloud projection, including repeated/review answers. Task 3 owns `pair_attempts_never_project_to_sound_or_cloud_evidence`.
4. Late/stale audio callbacks, replay failure, route/background/owner changes and rapid answer activation must not grant hearing, affect newer playback, or fork a command; frozen retry still works without replay. Task 5 owns `comparison_owner_fences_audio_and_freezes_claimed_retry`.
5. A comparison save failure or review Finish must not publish progress/completion or route out; acknowledged first-run completion must be isolated in Home/progress. Task 6 owns `comparison_entry_counts_only_acknowledged_first_run_finish`.

---

## 1. File responsibilities and delivery gates

Every path below is repository-relative. The task’s named worker owns only its listed paths, including intentional test updates. Existing support, unrelated discovery tests, catalogue/manifest/audio binaries and provenance, `LICENSE`, backend, dependency files, old documents and all other source remain read-only. A demonstrated need outside scope returns to the controller before edits. Do not change approved spec content in this plan; target-ordinal or source mismatch is a blocker, not permission to silently re-author.

| File | Responsibility / task |
| --- | --- |
| `frontend/lib/src/core/course/comparison_content.dart` | Core relation, pair/sample/content records, deterministic full-catalogue validator; Task 1 create |
| `frontend/lib/src/core/course/french_comparison_content.dart` | Exact ten spec §3.2 records and on-demand validated factory; Task 1 create |
| `frontend/lib/src/features/course/exercises/listening_exercise_contract.dart` | Preserve existing `ComparisonSample` and `PhonemeRelation` source compatibility by re-exporting both core types, not declaring duplicate enums; Task 1 modify |
| `frontend/test/unit/comparison_content_test.dart` | Exact inventory/structural validation/branch rejection; Task 1 create |
| `frontend/test/unit/listening_exercise_contract_test.dart` | Assert UI enum re-export retains exact core enum types; Task 1 modify |
| `frontend/lib/src/core/course/course_learning_store.dart` | Preserve `CourseLearningRepository` public v2 behavior while delegating typed operations to shared coordinator; Task 2 modify |
| `frontend/lib/src/core/course/course_learning_transaction.dart` | Shared family-aware serialized transaction/rollback/auth/receipt coordinator with statically typed adapter contract; Task 2 create |
| `frontend/lib/src/core/course/course_learning_codec.dart` and `course_learning_command.dart` | Read-only v2 serialization/fingerprint authority; Task 2 must not alter bytes/types |
| `frontend/test/unit/course_learning_store_test.dart`, `frontend/test/unit/course_learning_commit_isolation_test.dart`, `frontend/test/widget/course_learning_quarantine_recovery_test.dart`, `frontend/test/unit/course_learning_sync_test.dart`, `frontend/test/unit/course_learning_codec_test.dart` | Existing v2 behavior fixtures/regressions; Task 2 modify only if API refactor requires test setup adjustment, preserving all assertions |
| `frontend/lib/src/core/course/comparison_learning_state.dart` | Typed comparison profile scope/payload/attempt/mistake/summary/completion/receipt/checkpoint models; Task 3 create |
| `frontend/lib/src/core/course/comparison_learning_command.dart` | Typed compare answer/start/advance/review/finish commands and exact structural observations; Task 3 create |
| `frontend/lib/src/core/course/comparison_learning_transition.dart` | Pure content-validated comparison transition/session projection; Task 3 create |
| `frontend/lib/src/core/course/comparison_learning_codec.dart` | Strict schema-1 comparison codec, key and comparison-family canonical identity; Task 3 create |
| `frontend/lib/src/core/course/comparison_learning_store.dart` | Comparison adapter/provider-facing store over Task 2 typed coordinator; Task 3 create |
| `frontend/lib/src/core/course/course_learning_providers.dart` | Add independent comparison profile store and committed-state providers; Task 3 modify using existing auth/persistence providers and `_backendOwner`/`_newToken`; Task 6 consumes these providers |
| `frontend/test/unit/comparison_learning_transition_test.dart`, `comparison_learning_codec_test.dart`, `comparison_learning_store_test.dart`, `comparison_learning_providers_test.dart` | Pure state/codec, real persistence/coordinator, provider identity/invalidation integration; Task 3 create |
| `frontend/lib/src/features/course/lesson_exercise_owner.dart` | Reusable typed lifecycle/audio-grant/claim/frozen-retry mechanics extracted from discovery owner; Task 4 create |
| `frontend/test/unit/lesson_exercise_owner_test.dart` | Pure typed grant/lifecycle/frozen-save unit contract; Task 4 create |
| `frontend/lib/src/features/course/discovery_lesson_screen.dart` | Behavior-preserving use of shared owner seam; Task 4 modify |
| `frontend/test/widget/discovery_lesson_test.dart`, `discovery_lesson_recovery_test.dart`, `discovery_lesson_recovery_accessibility_test.dart`, `discovery_lesson_review_repeat_test.dart` | Preserve/assert existing discovery owner behavior after seam extraction; Task 4 modify |
| `frontend/lib/src/features/course/comparison_lesson_screen.dart` | Dedicated comparison UI composing shared owner and `SoundComparison`; Task 5 create |
| `frontend/lib/src/features/course/comparison_section_debrief.dart` | Controlled pair debrief/review/finish; Task 5 create |
| `frontend/test/widget/comparison_lesson_screen_test.dart`, `comparison_section_debrief_test.dart` | Audio gates, feedback, hidden metadata, finite flow and accessibility; Task 5 create |
| `frontend/lib/src/routing/app_router.dart` | Dedicated exact route and safe unavailable behavior; Task 6 modify |
| `frontend/lib/src/features/home/home_screen.dart` | Add optional separately labeled comparison entry; Task 6 modify |
| `frontend/lib/src/features/course/course_progress_screen.dart` | Separate comparison-local count/history labels; Task 6 modify |
| `frontend/lib/src/features/course/comparison_progress_summary.dart` | Pure committed-only comparison count/mistake/completion projection; Task 6 create |
| `frontend/test/widget/comparison_entry_flow_test.dart`, `home_navigation_test.dart`, `course_learning_progress_test.dart` | Real app-router/home/progress and unchanged identification/legacy access; Task 6 create/modify |

The path list names new contracts, not permission to clone the discovery screen or create a second persistence engine. Inspect actual imports/types before editing; if a required narrow owner/store seam cannot be extracted without changing this scope, stop for controller review.

## Task 1: Author and validate typed comparison content

**Files:** Create/modify only the Task 1 paths in the table.

**Consumes:** `CourseCurriculum.audioReferences` of `CourseAudioReference` (`id`, `kind`, `spokenText`) and `frenchCitationPhonemes: Map<String,List<String>>` keyed by exact word text from `french_course.dart`; derive the explicit id→word mapping only from `frenchCurriculum.audioReferences` entries (`fr-word-<word>` and exact `spokenText`), then look up `frenchCitationPhonemes[wordText]`. `CourseAudioCatalog` is a recording catalogue and is not the phoneme source. Also consume `ContentPurpose`, `ContentReviewState`, current UI references to `ComparisonSample`/`PhonemeRelation`. Verify each ordinal and target against published source; all proposed records are pending practice, not linguistic approval.

**Produces in `comparison_content.dart`:**

```dart
enum ComparisonSample { a, b }
enum PhonemeRelation { same, different }
final class ComparisonTarget {
  const ComparisonTarget({required this.phonemeId, required this.phonemeOrdinal});
  final String phonemeId;
  final int phonemeOrdinal;
}
final class ComparisonSampleContent {
  const ComparisonSampleContent({required this.slot, required this.referenceId, required this.target});
  final ComparisonSample slot;
  final String referenceId;
  final ComparisonTarget target;
}
final class ComparisonExercise {
  const ComparisonExercise({required this.id, required this.activityId, required this.sectionId,
    required this.contentRevision, required this.purpose, required this.reviewState,
    required this.instruction, required this.sampleA, required this.sampleB,
    required this.expectedRelation, required this.debriefNote});
  final String id, activityId, sectionId, instruction, debriefNote;
  final int contentRevision;
  final ContentPurpose purpose;
  final ContentReviewState reviewState;
  final ComparisonSampleContent sampleA, sampleB;
  final PhonemeRelation expectedRelation;
}
final class ComparisonExerciseDraft {
  const ComparisonExerciseDraft({required this.id, required this.activityId, required this.sectionId,
    required this.contentRevision, required this.purpose, required this.reviewState,
    required this.instruction, required this.sampleA, required this.sampleB,
    required this.expectedRelation, required this.debriefNote});
  final String? id, activityId, sectionId, instruction, debriefNote;
  final int? contentRevision;
  final ContentPurpose? purpose;
  final ContentReviewState? reviewState;
  final ComparisonSampleDraft? sampleA, sampleB;
  final PhonemeRelation? expectedRelation;
}
final class ComparisonSampleDraft {
  const ComparisonSampleDraft({required this.slot, required this.referenceId, required this.target});
  final ComparisonSample? slot;
  final String? referenceId;
  final ComparisonTargetDraft? target;
}
final class ComparisonTargetDraft {
  const ComparisonTargetDraft({required this.phonemeId, required this.phonemeOrdinal});
  final String? phonemeId;
  final int? phonemeOrdinal;
}
final class ComparisonContentDiagnostic {
  const ComparisonContentDiagnostic({required this.code, required this.recordId});
  final String code, recordId;
}
```

`ComparisonExercise` is the nonnullable validated production record consumed by UI/engine; `ComparisonExerciseDraft` is nullable solely to let
malformed test/authored records reach diagnostics. Add `ComparisonSampleDraft({required ComparisonSample? slot, required String? referenceId, required
ComparisonTargetDraft? target})` and `ComparisonTargetDraft({required String? phonemeId, required int? phonemeOrdinal})`; production
`ComparisonSampleContent`/`ComparisonTarget` remain fully nonnullable. `ComparisonContentValidationException(List<ComparisonContentDiagnostic>
diagnostics)` exposes detached `diagnostics`. `ComparisonCatalogue.fromDrafts({required String activityId, required String sectionId, required int
contentRevision, required List<ComparisonExerciseDraft> exercises, required Map<String,List<String>> referencePhonemes})` validates then projects an
unmodifiable list of nonnullable `ComparisonExercise`; exposes detached `activityId`, `sectionId`, `contentRevision`, authored-order `exercises`,
`Map<String,ComparisonExercise> byId`, `exercise(String id)` (throws `ArgumentError` for unknown ID), `noteFor(String pairId)` and
`notesFor(Iterable<String> pairIds) -> List<String>` returns notes in authored catalogue order regardless of input order, rejecting duplicate/unknown IDs. `validateComparisonCatalogue({required String activityId,required
String sectionId,required int contentRevision,required List<ComparisonExerciseDraft> exercises,required Map<String,List<String>> referencePhonemes})
-> List<ComparisonContentDiagnostic>` runs ownership/declaration checks in input order, then sample A-before-B, relation checks, and activity totals.
Exact stable codes/order: `catalogue.activity`, `catalogue.section`, `catalogue.revision`, `exercise.id.blank`, `exercise.id.duplicate`,
`exercise.activity`, `exercise.section`, `exercise.revision`, `exercise.purpose`, `exercise.reviewState`, `exercise.instruction`,
`exercise.sampleA.missing`, `exercise.sampleA.slot`, `exercise.sampleA.reference`, `exercise.sampleA.target.missing`,
`exercise.sampleA.target.phoneme`, `exercise.sampleA.target.ordinal`, corresponding `exercise.sampleB.*`, `exercise.note`,
`exercise.relation.missing`, `exercise.relation.mismatch`, `catalogue.count`, `catalogue.balance`. Reference phonemes are keyed by exact reference ID,
built from `frenchCurriculum.audioReferences` and `frenchCitationPhonemes` via exact `spokenText`; no spelling/IPA/audio heuristic.
`ComparisonCatalogue loadFrenchComparisonCatalogue()` synchronously validates all records and throws before profile load/start if invalid. UI contract
removes local enum declarations and re-exports both core enums.

Author this exact inventory (slots always A then B, ordinals zero-based; preserve the authored instructions/notes verbatim):

| ID | A reference/ordinal/phoneme | B reference/ordinal/phoneme | Instruction | Relation | Debrief note |
| --- | --- | --- | --- | --- | --- |
| `fr07b-pair-01` | `fr-word-tout` / 1 / `/u/` | `fr-word-tu` / 1 / `/y/` | Compare the vowel in each sample. | Different | The vowel targets are `/u/` in A and `/y/` in B; the designated sounds differ. |
| `fr07b-pair-02` | `fr-word-rue` / 0 / `/ʁ/` | `fr-word-rouge` / 0 / `/ʁ/` | Compare the first consonant in each sample. | Same | Both designated first consonants are `/ʁ/`. |
| `fr07b-pair-03` | `fr-word-tout` / 1 / `/u/` | `fr-word-vous` / 1 / `/u/` | Compare the vowel in each sample. | Same | Both designated vowels are `/u/`. |
| `fr07b-pair-04` | `fr-word-tu` / 0 / `/t/` | `fr-word-doux` / 0 / `/d/` | Compare the first consonant in each sample. | Different | The designated first consonants are `/t/` and `/d/`; they differ. |
| `fr07b-pair-05` | `fr-word-loup` / 0 / `/l/` | `fr-word-rue` / 0 / `/ʁ/` | Compare the first consonant in each sample. | Different | The designated first consonants are `/l/` and `/ʁ/`; they differ. |
| `fr07b-pair-06` | `fr-word-rue` / 1 / `/y/` | `fr-word-lune` / 1 / `/y/` | Compare the vowel in each sample. | Same | Both designated vowels are `/y/`. |
| `fr07b-pair-07` | `fr-word-beau` / 1 / `/o/` | `fr-word-bon` / 1 / `/ɔ̃/` | Compare the vowel in each sample. | Different | The designated vowels are `/o/` and `/ɔ̃/`; they differ. |
| `fr07b-pair-08` | `fr-word-lit` / 1 / `/i/` | `fr-word-vite` / 1 / `/i/` | Compare the vowel in each sample. | Same | Both designated vowels are `/i/`. |
| `fr07b-pair-09` | `fr-word-tu` / 0 / `/t/` | `fr-word-tout` / 0 / `/t/` | Compare the first consonant in each sample. | Same | Both designated first consonants are `/t/`. |
| `fr07b-pair-10` | `fr-word-mur` / 1 / `/y/` | `fr-word-rouge` / 1 / `/u/` | Compare the vowel in each sample. | Different | The designated vowels are `/y/` and `/u/`; they differ. |

Every row also has `activityId == sectionId == 'en-fr-phoneme-comparison'`, `contentRevision == 1`, `purpose == ContentPurpose.practice`, `reviewState == ContentReviewState.pending`. The inventory is 6 vowel/4 consonant targets, 5 Same/5 Different, 20 sample slots/13 distinct pending references. These declarations establish structural consistency only, not linguistic review.

- [ ] **Step 1: Write `french_comparison_inventory_matches_approved_spec`** in `frontend/test/unit/comparison_content_test.dart`; assert exact IDs/order and key list `[different,same,same,different,different,same,different,same,same,different]`; target tuples `tout#1/u,tu#1/y`; `rue#0/ʁ,rouge#0/ʁ`; `tout#1/u,vous#1/u`; `tu#0/t,doux#0/d`; `loup#0/l,rue#0/ʁ`; `rue#1/y,lune#1/y`; `beau#1/o,bon#1/ɔ̃`; `lit#1/i,vite#1/i`; `tu#0/t,tout#0/t`; `mur#1/y,rouge#1/u`. Assert spec §3.2 instructions/notes exactly for all records, purpose/review/activity/section/revision, length 10, 5/5 keys, 6 vowels/4 consonants, 20 slots and 13 refs. In `listening_exercise_contract_test.dart`, assign both imported `ComparisonSample.a` and `PhonemeRelation.same` to core-typed variables and pass them to core-typed function parameters; analyzer/test proves imports re-export the same declarations, not parallel enums.
- [ ] **Step 2: Write `comparison_catalogue_rejects_incomplete_duplicate_and_unknown_content`** using nullable drafts. Duplicate-ID fixture retains ten raw rows, replaces one row with a duplicate using the same relation (counts remain 5/5), and asserts only `exercise.id.duplicate`; count validation uses raw row length and does not cascade on duplicates. Missing A + unknown B ref + blank note asserts `['exercise.sampleA.missing','exercise.sampleB.reference','exercise.note']` (missing sample suppresses child diagnostics for that sample). Wrong-relation fixture swaps relation declarations on two otherwise-valid rows and asserts two `exercise.relation.mismatch` diagnostics; mismatch suppresses balance. Nine otherwise-valid unique rows assert only `catalogue.count`; separate ten fully valid 4/6 rows assert `catalogue.balance`. Add missing ownership/purpose/review/target/instruction, bad ordinal/phoneme tests; same phoneme across distinct refs is accepted; factory rejects whole catalogue; discovery registry stays valid.

```dart
expect(validateComparisonCatalogue(activityId: comparisonActivityId,
    sectionId: comparisonActivityId, contentRevision: 1,
    exercises: duplicateIdTenRecordFixture, referencePhonemes: fixturePhonemes)
    .map((d) => d.code), ['exercise.id.duplicate']);
expect(validateComparisonCatalogue(activityId: comparisonActivityId,
    sectionId: comparisonActivityId, contentRevision: 1,
    exercises: nineValidRecordFixture, referencePhonemes: fixturePhonemes)
    .map((d) => d.code), ['catalogue.count']);
expect(validateComparisonCatalogue(activityId: comparisonActivityId,
    sectionId: comparisonActivityId, contentRevision: 1,
    exercises: tenRecordFourSixFixture, referencePhonemes: fixturePhonemes)
    .map((d) => d.code), ['catalogue.balance']);
```

Validator order is catalogue headers, per-record input order (identity/declarations, A, B, note, relation), then totals. Missing-parent records suppress child/relation checks; duplicate IDs suppress count; relation mismatch suppresses balance; invalid declarations, targets or samples suppress balance. `catalogue.count` is emitted only when raw row count differs from ten. `catalogue.balance` is emitted only for ten unique records with valid relations/targets. `exercise(String id) -> ComparisonExercise`; `noteFor(String pairId) -> String`; `notesFor(Iterable<String> pairIds) -> List<String>` returns authored catalogue order irrespective of pairIds input order, rejecting duplicate/unknown IDs.
- [ ] **Step 3: Run RED** with `$FLUTTER test --no-pub test/unit/comparison_content_test.dart --reporter expanded`; missing APIs are scaffolding RED, not a claimed product regression.
- [ ] **Step 4: Implement core records/validator and exact factory.** Compare declared phoneme identities only; do not infer targets from spelling, reference equality or audio. If published annotations do not support a spec ordinal/identity, stop and report the exact mismatch rather than changing content.
- [ ] **Step 5: Run GREEN and preservation checks:** rerun Step 3; `$FLUTTER test --no-pub test/unit/course_learning_registry_test.dart test/unit/listening_exercise_contract_test.dart --reporter expanded`; `$FLUTTER analyze --no-pub`; format owned Dart files and `git diff --check`. Require all pass/no issues; confirm no manifest/content promotion or unrelated registry change.
- [ ] **Step 6: Commit/publish Task 1** with `git add frontend/lib/src/core/course/comparison_content.dart frontend/lib/src/core/course/french_comparison_content.dart frontend/lib/src/features/course/exercises/listening_exercise_contract.dart frontend/test/unit/comparison_content_test.dart frontend/test/unit/listening_exercise_contract_test.dart`; commit `feat: add validated phoneme comparison content`, push scoped PR to `main`. Obtain independent review/controller verification and merge; verify published merged tree before Task 2.

## Task 2: Extract typed shared transaction orchestration without v2 drift

**Files:** Create `frontend/lib/src/core/course/course_learning_transaction.dart`; modify `frontend/lib/src/core/course/course_learning_store.dart` and only the named existing store/sync test files if required. `course_learning_codec.dart` and `course_learning_command.dart` remain read-only. No comparison profile implementation yet.

**Consumes:** Existing `LearningScope`, `LearningOwner`, `LearningAuthScope`, `LearningPersistence`, `LearningCloudTransport`, `LearningDocumentCodec`, `LearningTransitionEngine`, `LearningCommit`, and concrete coordinator rules in current `course_learning_store.dart`. Read the full `_acknowledge`, `_knownPendingCount`, rollback/quarantine and provider call paths before extraction.

**Produces in `course_learning_transaction.dart`:** Keep serialization across *all* keys process-wide, matching current `_LearningCoordinator._tail`; do not substitute per-key locks. Quarantine/known committed bytes are keyed by full storage key. The typed coordinator owns read/reload, duplicate/cursor conflict checks, write, rollback verification, revision/ordinal update and ACK callback. Typed profile hooks own decode/encode, command identity/cursor, transition evaluation, next-state construction and commit projection. The shared kernel stores only the process tail and raw quarantine bytes. This is the only write path for v2 and comparison.

Use one non-generic process singleton only for serialized execution/quarantine bytes; typed repositories retain typed committed state caches:

```dart
final class LearningTransactionKernel {
  LearningTransactionKernel._();
  static final LearningTransactionKernel instance = LearningTransactionKernel._();
  Future<T> run<T>(String storageKey, Future<T> Function() action);
  bool isBlocked(String storageKey);
  bool hasKnownBytes(String storageKey);
  String? knownBytes(String storageKey);
  void block(String storageKey, String? committedBytes);
  void unblock(String storageKey);
}
```

`run` maintains one process-wide `_tail`; `block/knownBytes` are keyed by full storage key. `LearningTransactionCoordinator<P,S,C,R>` holds only typed `S? _committedPayload` plus its adapter’s `String? _committedRaw`; it always reloads storage under the singleton tail before treating a cache as merge base. This keeps the synchronization lock shared across generic instantiations without `Object`-erased profile caches.

```dart
final class LearningDocumentFamily {
  const LearningDocumentFamily(this.name);
  final String name;
}
final class LearningDocumentEnvelope<P, S> {
  const LearningDocumentEnvelope({required this.scope, required this.family,
    required this.revision, required this.commitOrdinal, required this.payload});
  final P scope;
  final LearningDocumentFamily family;
  final int revision, commitOrdinal;
  final S payload;
}
final class LearningTransactionTransition<P, S, R> {
  const LearningTransactionTransition({required this.nextDocument, required this.result});
  final LearningDocumentEnvelope<P, S> nextDocument;
  final R result;
}
final class LearningCursorPosition {
  const LearningCursorPosition({required this.generation, required this.sequence,
    required this.revision});
  final int generation, sequence, revision;
}
final class LearningReceiptIdentity {
  const LearningReceiptIdentity({required this.activityId, required this.token,
    required this.canonicalCommand, required this.before, required this.after,
    required this.commitOrdinal});
  final String activityId, token, canonicalCommand;
  final LearningCursorPosition before, after;
  final int commitOrdinal;
}
abstract interface class LearningProfileAdapter<P, S, C, R> {
  P get scope;
  LearningOwner get owner;
  String get courseId;
  LearningDocumentFamily get family;
  String get storageKey;
  LearningDocumentEnvelope<P, S> emptyDocument();
  LearningDocumentEnvelope<P, S> decodeDocument(String raw);
  String encodePayload(LearningDocumentEnvelope<P, S> document);
  P commandScope(C command);
  int commandAuthGeneration(C command);
  String commandToken(C command);
  String commandFingerprint(C command);
  String commandActivityId(C command);
  LearningCursorPosition commandExpected(C command);
  LearningCursorPosition? currentCursor(S payload, String activityId);
  LearningReceiptIdentity? latestReceipt(S payload, String activityId);
  LearningReceiptIdentity? retainedReceipt(S payload, String activityId,
    LearningCursorPosition after, String token);
  bool isStart(C command);
  LearningTransactionTransition<P, S, R> evaluate({
    required LearningDocumentEnvelope<P, S> before, required C command,
    required int nextRevision, required int nextCommitOrdinal,
    required DateTime committedAt});
  R duplicateResult({required LearningDocumentEnvelope<P, S> current, required C command});
}
final class LearningTransactionCoordinator<P, S, C, R> {
  LearningTransactionCoordinator({required LearningProfileAdapter<P,S,C,R> adapter,
    required LearningPersistence persistence, required int authGeneration,
    required LearningAuthScope Function() currentAuth,
    required LearningOwner Function() backendOwner,
    required DateTime Function() clock, void Function()? onCommitted});
  final LearningProfileAdapter<P,S,C,R> adapter;
  final LearningPersistence persistence;
  final int authGeneration;
  final LearningAuthScope Function() currentAuth;
  final LearningOwner Function() backendOwner;
  final DateTime Function() clock;
  final void Function()? onCommitted;
  Future<LearningDocumentEnvelope<P,S>> load();
  Future<LearningDocumentEnvelope<P,S>> retryLoad();
  Future<R> submit(C command);
  int knownCommittedCount(int Function(S payload) count, {required S fallback});
  Future<void> acknowledge(Set<String> receiptIds,
    LearningDocumentEnvelope<P, S> Function({required LearningDocumentEnvelope<P,S> current,
      required Set<String> receiptIds, required int nextRevision,
      required int currentCommitOrdinal}) removeAcknowledged);
}
```

Command preparation remains synchronous in each typed facade, exactly as current `CourseLearningRepository.prepare` is. Before duplicate lookup,
coordinator requires `adapter.commandScope(command) == adapter.scope`, command auth generation equals captured `authGeneration`, `currentAuth()`
matches that generation/owner, and `backendOwner() == adapter.owner`; stale A→B→A commands therefore cannot replay. After persistence reload/decode,
`decodeDocument(raw)` returns validated envelope headers and typed payload. `emptyDocument()` supplies a zero-header initial document.
`LearningCursorPosition` and `LearningReceiptIdentity` are scalar views only. Compute `nextRevision = before.revision + 1` and `nextCommitOrdinal =
before.commitOrdinal + 1` in kernel; call `evaluate(before,command,nextRevision,nextCommitOrdinal,committedAt)`, then reject unless returned envelope
has exact adapter scope/family and those header values. For ACK, callback receives `nextRevision` and unchanged `currentCommitOrdinal`; returned
envelope is checked the same way. V2 adapter keeps its existing candidate state in `LearningCommand`, validates it, and wraps it with the
kernel-supplied headers; comparison adapter constructs its typed next payload and envelope. Encode and validate the candidate, then recheck auth/scope/
generation immediately before `persistence.write(capturedStorageKey, encoded)` and outside the write-failure catch. Await that write using the captured
key. A write that succeeds is ACKed into cache/receipt for that captured namespace even if auth changes while the write is held: never post-write
reject or roll back committed bytes. Only a persistence-write error enters restore of exact last committed bytes plus reload/verify, else per-key
quarantine. Post-ACK callback failures are separate and cannot trigger rollback. UI/provider/lifecycle guards suppress stale notification/navigation,
not the durable ACK. Apply this captured-scope write policy to comparison too. Duplicate/conflict/cursor checks and all writes/rollback remain one generic
implementation. V2 canonical command bytes remain owned by `LearningDocumentCodec`; comparison maps its own cursor/receipts into scalar views only.

The adapter retains public v2 responsibilities: `CourseLearningRepository.prepare({required CourseLearningState state, required String activityId, required LearningAction action}) -> LearningCommand`, `submit(LearningCommand) -> Future<LearningCommit>`, `sync() -> Future<SupportedSyncResult>`, and `_acknowledge(Set<String>)` delegate to the same kernel. `SupportedProgressProjector` (v2-only) continues to run during submit candidate construction, exactly where it does today. `knownCommittedCount(int Function(S payload) count,{required S fallback}) -> int` is synchronous. At call time inspect the process kernel’s blocked flag and `hasKnownBytes` for the full storage key: when blocked and known raw bytes exist, synchronously decode those current bytes through the adapter’s `decodeDocument()` and count that payload; when blocked with no known raw bytes, count `emptyDocument().payload`. Otherwise count `typedCommittedPayload ?? fallback`. Never prioritize stale fallback over newer known committed bytes. It performs no persistence read/reload/restore/repair, awaits nothing, and queues no work. V2 sync wires `knownPendingCount: () => coordinator.knownCommittedCount((payload) => payload.pending.length, fallback: stateAtSyncStart)` directly into `SupportedProgressSync`; do not pre-read a count before transport. Sync still only transports already-created pending events and acknowledges accepted receipts; it does not project progress. ACK uses kernel write/rollback, revision +1, unchanged commit ordinal. No second writer remains.

Use in-memory family constants `LearningDocumentFamily('course-learning-v2')` and `LearningDocumentFamily('comparison')`. V2 persisted JSON/key/fingerprint must not gain a family field; its storage key is already the distinct v2 namespace. Comparison stores `family:'comparison'` and its distinct key/schema. `LearningTransactionCoordinator.acknowledge` is called by v2 `sync` only; no comparison `sync` or cloud projector is exposed.

- [ ] **Step 1: Add `v2_profile_bytes_and_receipts_remain_exact`** to `course_learning_store_test.dart`: assert `LearningScope(courseId:'en-fr', owner:guest).storageKey == 'course.learning.v2.ZW4tZnI.g'`; use existing canonical command fixture and assert exact canonical string/encoded JSON bytes; submit the same command twice and assert second `duplicate == true`, same state revision/commitOrdinal, one attempt batch and no second persistence write.
- [ ] **Step 2: Add `kernel_serializes_all_document_families_and_preserves_quarantine_count`** in `course_learning_commit_isolation_test.dart` and `frontend/test/widget/course_learning_quarantine_recovery_test.dart`: block a first-key write, start a second-key load, assert its future is pending; release first write before awaiting second load (never await queued work while holding the global-tail gate). Force write plus rollback failure and assert retry recovers exact known committed bytes, unavailable is scoped by full storage key, and synchronous known pending count reports current committed bytes without persistence `read/reload/restore` calls. Add the exact preservation oracle from `course_learning_commit_isolation_test.dart`: hold A’s write, change auth A→B→A while the old command is queued, assert the first already-started write succeeds/ACKs to A’s captured key, the queued old command throws `LearningOwnerChanged` before duplicate lookup, and `writeCount == 1`.
- [ ] **Step 3: Add `cloud_ack_uses_kernel_without_advancing_commit_ordinal`** to `course_learning_sync_test.dart`: acknowledge a pending event, assert only that receipt disappears, document revision increments exactly once, commit ordinal unchanged, and no new attempt/receipt/cloud event. Preserve synchronous readonly count while quarantined. Pin `SupportedProgressSync` held-send regression from `course_learning_sync_test.dart` (existing test around lines 275–380): commit event 1 then hold cloud send; another repository commits event 2, then failed event 3 plus failed rollback quarantines the key; when held send fails, fallback count is exactly 2 (neither stale 1 nor optimistic 3), with zero persistence count-access calls. The sync callback is a synchronous `int Function()?`; do not await or pre-read its result before transport, preserving source unknown-pending-count priority.
- [ ] **Step 4: Write `typed_kernel_accepts_distinct_profile_types_and_family_identity`** in `course_learning_commit_isolation_test.dart`, using test-local `LearningProfileAdapter<LearningScope,CourseLearningState,LearningCommand,LearningCommit>` and `LearningProfileAdapter<ComparisonTestScope,String,ComparisonTestCommand,ComparisonTestResult>` constructors with explicit `commandScope`, `commandAuthGeneration`, empty/decode envelope, and evaluate signatures. Compile-time typed helper parameters reject cross-family payload/command calls; assert identical token/activity/cursor yields separate first receipts because full keys differ. Expected initial failure: missing seam declarations only.

```dart
expect(v2Adapter.commandScope(v2Command), v2Adapter.scope);
expect(v2Adapter.commandAuthGeneration(v2Command), capturedGeneration);
expect(comparisonAdapter.commandScope(comparisonCommand), comparisonAdapter.scope);
Future<LearningCommit> submitV2(LearningCommand command) => v2Coordinator.submit(command);
Future<ComparisonTestResult> submitComparison(ComparisonTestCommand command) =>
    comparisonCoordinator.submit(command);
```

The disjoint helper signatures make cross-family calls analyzer errors; assert this with a test-local compile fixture if the repo has an established analyzer-test harness, otherwise retain the visible static signatures and prohibit dynamic casts. Runtime assertions cover command scope/auth fencing and exact next envelope revision/ordinal.
- [ ] **Step 5: Run the pre-refactor focused tests** with `$FLUTTER test --no-pub test/unit/course_learning_store_test.dart test/unit/course_learning_commit_isolation_test.dart test/widget/course_learning_quarantine_recovery_test.dart test/unit/course_learning_sync_test.dart test/unit/course_learning_codec_test.dart --reporter expanded`. Record which characterization assertions were already true; the API compile failure is expected scaffolding RED, not product regression.
- [ ] **Step 6: Implement typed kernel and adapt v2.** Keep the one process-wide tail; move v2 submit and ack writes to this kernel; preserve exact duplicate/retained/conflict checks and byte fixtures; no dynamic/Object payload or casts.

```dart
final transition = adapter.evaluate(before: before, command: command,
    nextRevision: before.revision + 1,
    nextCommitOrdinal: before.commitOrdinal + 1, committedAt: committedAt);
expect(transition.nextDocument.revision, before.revision + 1);
expect(transition.nextDocument.commitOrdinal, before.commitOrdinal + 1);
```
- [ ] **Step 7: Verify v2** by rerunning Step 5 and `$FLUTTER analyze --no-pub`; require pass/no issues, compare canonical/encoded fixtures byte-for-byte, format owned files and `git diff --check`.
- [ ] **Step 8: Commit/publish Task 2** with `git add frontend/lib/src/core/course/course_learning_transaction.dart frontend/lib/src/core/course/course_learning_store.dart frontend/test/unit/course_learning_store_test.dart frontend/test/unit/course_learning_commit_isolation_test.dart frontend/test/widget/course_learning_quarantine_recovery_test.dart frontend/test/unit/course_learning_sync_test.dart frontend/test/unit/course_learning_codec_test.dart`; commit `refactor: share typed learning transactions`, scoped PR, independent review/controller verification and merged-tree check. Task 3 waits for published baseline.

## Task 3: Add comparison schema, pure transition and local profile adapter

**Files:** Create the five Task 3 core files and four Task 3 tests in the table; modify `frontend/lib/src/core/course/course_learning_providers.dart` to add the comparison store and state providers. This keeps Task 5 screen tests runnable against the real provider/repository before route integration.

**Consumes:** Published Task 1 `ComparisonCatalogue`/typed relation; published Task 2 exact coordinator/adapter signatures; `LearningOwner`, `LearningAuthScope`, `LearningPersistence`; `LessonPolicy({int completionThresholdPercent = 80})`, `LessonSectionSession({required List<String> itemIds, required String sessionId, int contentRevision = 1, LessonPolicy? policy})`, `LessonSectionSession.fromJson(Map<String,dynamic>, {required List<String> itemIds, required int contentRevision})`, `CourseAudioSource {unverifiedRecording, reviewedRecording, practiceTts}` from `course_audio_contract.dart`, and `CourseAudioResult {outcome,referenceId,source,failure}`. Never use `CourseLearningState` as comparison payload.

**Produced public API (all path-specific Dart APIs, no domain `Object`/dynamic payload):**

```dart
final class ComparisonProfileScope {
  ComparisonProfileScope({required String courseId, required this.owner})
      : courseId = courseId {
    if (courseId != 'en-fr') throw ArgumentError.value(courseId, 'courseId');
  }
  final String courseId;
  final LearningOwner owner;
  String get storageKey; // exact family v1 key
  bool operator ==(Object other);
  int get hashCode;
}
final class ComparisonPairAttempt {
  ComparisonPairAttempt({required this.scope, required this.activityId, required this.pairId,
    required this.contentRevision, required this.runGeneration, required this.round,
    required this.sequence, required this.selectedRelation, required this.expectedRelation,
    required this.correct, required this.presentation, required this.afterDebrief,
    required List<ComparisonPlaybackObservation> observations, required this.answeredAt,
    required this.committedAt}) : observations = List.unmodifiable(observations);
  final ComparisonProfileScope scope;
  final String activityId, pairId;
  final int contentRevision, runGeneration, round, sequence;
  final PhonemeRelation selectedRelation, expectedRelation;
  final bool correct, afterDebrief;
  final AttemptPresentation presentation; // firstInRun / repeatInRun
  final List<ComparisonPlaybackObservation> observations; // exactly A then B
  final DateTime answeredAt, committedAt;
}
final class ComparisonPairMistake {
  const ComparisonPairMistake({required this.scope, required this.key, required this.firstWrongAt,
    required this.latestWrongAt, required this.failureCount});
  final ComparisonProfileScope scope;
  final ComparisonPairMistakeKey key;
  final DateTime firstWrongAt, latestWrongAt;
  final int failureCount;
}
final class ComparisonCount {
  ComparisonCount({required this.correct, required this.total}) {
    if (correct < 0 || total < 0 || correct > total) {
      throw ArgumentError('Comparison count must satisfy 0 <= correct <= total.');
    }
  }
  final int correct, total; }
final class ComparisonSummaryKey {
  const ComparisonSummaryKey({required this.scope, required this.activityId, required this.pairId,
    required this.contentRevision});
  final ComparisonProfileScope scope;
  final String activityId, pairId;
  final int contentRevision;
}
final class ComparisonPairSummary {
  ComparisonPairSummary({required this.key, required this.firstInRun,
    required this.repeatInRun, required this.afterDebrief}) {
    if (afterDebrief.total > firstInRun.total + repeatInRun.total ||
        afterDebrief.correct > firstInRun.correct + repeatInRun.correct) {
      throw ArgumentError('After-debrief bucket must be an overlapping subset.');
    }
  }
  final ComparisonSummaryKey key;
  final ComparisonCount firstInRun, repeatInRun, afterDebrief;
}
final class ComparisonCompletion {
  const ComparisonCompletion({required this.scope, required this.activityId, required this.contentRevision,
    required this.policyRevision, required this.thresholdPercent, required this.committedAt});
  final ComparisonProfileScope scope;
  final String activityId;
  final int contentRevision, policyRevision, thresholdPercent;
  final DateTime committedAt;
}
final class ComparisonLearningState {
  ComparisonLearningState({required this.scope, required this.revision,
    required this.commitOrdinal, required this.slot,
    required List<ComparisonPairAttempt> attempts, required List<ComparisonReceipt> receipts,
    required Map<ComparisonPairMistakeKey,ComparisonPairMistake> mistakes,
    required Map<ComparisonSummaryKey,ComparisonPairSummary> summaries,
    required List<ComparisonCompletion> completions})
      : schemaVersion = 1,
        attempts = List.unmodifiable(attempts), receipts = List.unmodifiable(receipts),
        mistakes = Map.unmodifiable(mistakes), summaries = Map.unmodifiable(summaries),
        completions = List.unmodifiable(completions);
  factory ComparisonLearningState.empty(ComparisonProfileScope scope);
  final int schemaVersion; // always 1
  final ComparisonProfileScope scope;
  final int revision, commitOrdinal;
  final ComparisonSlot? slot;
  ComparisonCheckpoint? get checkpoint => slot?.checkpoint;
  final List<ComparisonPairAttempt> attempts;
  final List<ComparisonReceipt> receipts;
  final Map<ComparisonPairMistakeKey,ComparisonPairMistake> mistakes;
  final Map<ComparisonSummaryKey,ComparisonPairSummary> summaries;
  final List<ComparisonCompletion> completions;
}
sealed class ComparisonAction { const ComparisonAction(); }
final class StartComparisonRun extends ComparisonAction {
  const StartComparisonRun({required this.sessionId, required this.policy});
  final String sessionId;
  final LessonPolicy policy;
}
final class AnswerComparisonPair extends ComparisonAction {
  const AnswerComparisonPair(this.answer);
  final ComparePhonemesAnswer answer;
}
final class AdvanceComparisonPair extends ComparisonAction { const AdvanceComparisonPair(); }
final class ReviewComparisonPairs extends ComparisonAction { const ReviewComparisonPairs(); }
final class FinishComparisonRun extends ComparisonAction {
  const FinishComparisonRun({required this.recordCompletion});
  final bool recordCompletion; // false for route review mode
}
final class ComparisonLearningCommand {
  ComparisonLearningCommand({required ComparisonProfileScope scope, required int authGeneration,
    required String activityId, required ComparisonCursor expected, required String token,
    required DateTime submittedAt, required ComparisonAction action});
  final ComparisonProfileScope scope;
  final int authGeneration;
  final String activityId, token;
  final ComparisonCursor expected;
  final DateTime submittedAt;
  final ComparisonAction action;
}
final class ComparisonPlaybackObservation {
  const ComparisonPlaybackObservation({required this.slot, required this.referenceId,
    required this.outcome, required this.source, required this.activityId,
    required this.runGeneration, required this.round, required this.pairId,
    required this.profile, required this.uiGeneration});
  final ComparisonSample slot;
  final String referenceId, activityId, pairId;
  final CourseAudioOutcome outcome;
  final CourseAudioSource? source;
  final int runGeneration, round, uiGeneration;
  final ComparisonProfileScope profile;
}
final class ComparePhonemesAnswer {
  ComparePhonemesAnswer({required this.selectedRelation, required this.expectedRelationSnapshot,
    required List<ComparisonPlaybackObservation> observations})
      : observations = List.unmodifiable(observations);
  final PhonemeRelation selectedRelation, expectedRelationSnapshot;
  final List<ComparisonPlaybackObservation> observations; // constructor enforces exactly [A,B]
}
final class ComparisonUnavailableException implements Exception {
  const ComparisonUnavailableException();
}
final class ComparisonCommit {
  const ComparisonCommit({required this.state, required this.slot, required this.duplicate});
  final ComparisonLearningState state;
  final ComparisonSlot slot;
  final bool duplicate;
}
abstract interface class ComparisonLearningStore {
  ComparisonProfileScope get scope;
  Future<ComparisonLearningState> load();
  Future<ComparisonLearningState> retryLoad();
  ComparisonLearningCommand prepare({required ComparisonLearningState state,
    required String activityId, required ComparisonAction action});
  Future<ComparisonCommit> submit(ComparisonLearningCommand command);
}
```

Supporting records also carry explicit `ComparisonProfileScope scope`: `ComparisonPairAttempt`, `ComparisonPairMistakeKey`, `ComparisonPairMistake`,
`ComparisonSummaryKey`, `ComparisonCompletion`, `ComparisonReceipt`, `ComparisonCheckpoint`, and `ComparisonSlot`.
`ComparisonPlaybackObservation.profile` is explicit. `ComparisonCursor` is nested under the scoped slot and inherits that scope; state validation
requires every contained scope equal its own. These scope fields are runtime typed invariants, not repeated in nested JSON; codec derives them from
and validates against outer courseId/owner before constructing records. Define supporting fields: `ComparisonCursor(generation,sequence,revision)`;
`ComparisonReceipt(scope,activityId,generation,sequence,token,canonicalCommand,before,after,commitOrdinal)`;
`ComparisonCheckpoint(scope,sessionId,contentRevision,policy,sessionJson)`; `ComparisonPairMistakeKey(scope,activityId,pairId,contentRevision)`;
`ComparisonSlot(scope,activityId,cursor,checkpoint,latestReceipt)`. `ComparisonLearningTransition(nextState,slot,attempts,duplicate)` is the engine
result. State enforces schema 1, safe integers `0..9007199254740991`, 22-character base64url tokens, UTC timestamps, `commitOrdinal <= revision`, all
record scopes equal state scope, attempts/receipts each capped at 2000, unique receipt tokens/per-activity sequences, observable receipt/cursor links.
Cursor reachability mirrors v2: initial `(0,0,0)` to run `(1,1,0)`; continuation same generation with sequence/revision each +1; new run
generation/sequence +1 and slot revision reset 0. Validate only observable receipt-to-attempt links and latest-receipt/cursor; pruning does not
require full attempt history. Restore active session from checkpoint alone. Completion policy revision fixed `1` (existing `LessonPolicy` has
threshold only); threshold stores `completionThresholdPercent`. Deduplicate identity `(activityId,contentRevision,policyRevision,thresholdPercent)`;
one finish receipt appends at most one identity.

Implement value-based `==`/`hashCode` for `LearningDocumentFamily.name`, `ComparisonProfileScope(courseId,owner)`, `ComparisonCursor(generation,sequence,revision)`, `ComparisonPairMistakeKey(scope,activityId,pairId,contentRevision)`, and `ComparisonSummaryKey(scope,activityId,pairId,contentRevision)`; use these as map keys and for decoded/reconstructed comparisons. State, attempt, answer, and snapshot constructors detach every input list/map into unmodifiable copies. Validate every `ComparisonCount` with `0 <= correct <= total`; `afterDebrief.total <= firstInRun.total + repeatInRun.total` and `afterDebrief.correct <= firstInRun.correct + repeatInRun.correct` because that bucket is an overlapping subset.

`ComparisonCursor` rejects negative or >`9007199254740991` counters. `ComparisonLearningCommand` validates same-scope equality, auth generation in `0..9007199254740991`, activity exactly `en-fr-phoneme-comparison`, token regex `^[A-Za-z0-9_-]{22}$`, UTC `submittedAt`, and expected cursor. `ComparePhonemesAnswer` detaches observations and requires exactly ordered `[ComparisonSample.a, ComparisonSample.b]`; observations are durable provenance, not playback permission. `ComparisonPairAttempt` detaches observations and validates both references/sources match the expected pair and command identity.

`ComparisonLearningTransitionEngine({required ComparisonCatalogue catalogue})` exposes exact `prepare({required ComparisonLearningState state,required String activityId,required ComparisonAction action,required int authGeneration,required String token,required DateTime submittedAt}) -> ComparisonLearningCommand` and `evaluate({required ComparisonLearningState state,required ComparisonLearningCommand command,required DateTime committedAt}) -> ComparisonLearningTransition`. It applies `LessonSectionSession` methods only to local copies reconstructed from session JSON; saves JSON after each transition. Answer validates identity/current pair/round and structural A/B observations (both completed, expected exact reference, source exactly `CourseAudioSource.unverifiedRecording`, nonnull; no reviewed-source or TTS substitution), then computes correctness from registered content. It creates no command for audio failure/cancel. Session projection records one boolean per pair, keeps selected relation only in typed attempt, and never guesses a restored selection. Completion is appended only by acknowledged `FinishComparisonRun(recordCompletion:true)` with `session.canComplete`, all ten answered, first-run mode and debrief; route `review=true` prepares `recordCompletion:false`. New run replaces only checkpoint. Summary buckets separate firstInRun and repeatInRun, with afterDebrief overlapping as an explicit exposure dimension; no summary feeds phoneme identification.

`ComparisonLearningCodec` API: `String keyFor(ComparisonProfileScope scope)`, `String canonicalCommand(ComparisonLearningCommand command)`, `String
encode(ComparisonLearningState state)`, `ComparisonLearningState decode(String raw, ComparisonProfileScope expectedScope, ComparisonCatalogue
catalogue)`. Exact top-level closed keys:
`schemaVersion,family,courseId,owner,revision,commitOrdinal,slot,attempts,receipts,mistakes,summaries,completions`; require schema 1, family
`comparison`, exact owner object `{kind:'guest',userId:null}` or `{kind:'account',userId:<id>}`. Slot is null or
`{activityId,cursor,checkpoint,latestReceipt}`; checkpoint `{sessionId,contentRevision,policy,session}`. Session JSON keys are exactly those emitted
by `LessonSectionSession.toJson()`; validate closed keys/types in the comparison codec before calling `fromJson`, restore exact pair order/revision,
and require checkpoint sessionId/contentRevision/policy to equal restored session fields. Profile is derived from outer courseId/owner for
attempts/observations and must match expected scope before encode and after decode; it is not duplicated in nested JSON. Attempt keys:
`activityId,pairId,contentRevision,runGeneration,round,sequence,selectedRelation,expectedRelation,correct,presentation,afterDebrief,observations,answeredAt,committedAt`;
observation keys `slot,referenceId,outcome,source,activityId,runGeneration,round,pairId,uiGeneration`. Receipt/cursor keys are
`activityId,generation,sequence,token,canonicalCommand,before,after,commitOrdinal` and `generation,sequence,revision`. Mistake map key is canonical
ordered JSON array `[activityId,pairId,contentRevision]`; value keys `firstWrongAt,latestWrongAt,failureCount`. Summary map key is canonical ordered
JSON array `[activityId,pairId,contentRevision]`; value keys `firstInRun,repeatInRun,afterDebrief`, each count `{correct,total}`. Completion keys
`activityId,contentRevision,policyRevision,thresholdPercent,committedAt`. Reject unknown fields/variants, bool-as-int, bounds violations, duplicate
IDs/sequences/tokens, and all observable cursor/receipt/fingerprint/session cross-links inconsistent with available bounded records; do not require
pruned history. Wrong owner/course/family/future version throws `ComparisonUnavailableException`; decode never writes/resets bytes. Canonical command
uses ordered closed top keys `family,courseId,owner,activityId,generation,sequence,revision,token,submittedAt,action`; every action has discriminator
`kind` (`start|answer|advance|review|finish`) and action-specific closed fields: start `sessionId,policy`; answer
`selectedRelation,expectedRelationSnapshot,observations`; advance/review no additional fields; finish `recordCompletion`. Ordered UTC ISO timestamps.
Do not call v2 canonicalizer.

`ComparisonProfileAdapter implements
LearningProfileAdapter<ComparisonProfileScope,ComparisonLearningState,ComparisonLearningCommand,ComparisonCommit>` and delegates `emptyDocument`,
decode/encode, command scope/auth/token/fingerprint/activity/cursor accessors and evaluate to codec/engine.
`ComparisonLearningRepository({required ComparisonProfileScope scope,required int authGeneration,required LearningAuthScope Function() currentAuth,required LearningOwner Function() backendOwner,required LearningPersistence persistence,required ComparisonLearningTransitionEngine transitions,required DateTime Function() clock,required String Function() newToken,void Function()? onCommitted,int historyLimit=2000}) implements ComparisonLearningStore`; synchronous prepare uses `_newToken()` and UTC clock; submit delegates to typed coordinator. `ComparisonProfileScope` is actual course/owner identity, not fake `LearningScope`. In providers define `final _comparisonLearningStateRevisionProvider = StateProvider<int>((ref) => 0);`, `final comparisonCatalogueProvider = Provider<ComparisonCatalogue>((ref) => loadFrenchComparisonCatalogue());`, `final comparisonLearningStoreProvider = Provider<ComparisonLearningStore>((ref) { ... });`, and `final comparisonLearningStateProvider = FutureProvider<ComparisonLearningState>((ref) { ref.watch(_comparisonLearningStateRevisionProvider); ref.watch(comparisonCatalogueProvider); return ref.watch(comparisonLearningStoreProvider).load(); });`. Store provider watches only shared `learningAuthScopeProvider.select((a) => (owner:a.owner,generation:a.generation))` and `learningPersistenceProvider`, reads auth tracker and `_comparisonLearningStateRevisionProvider.notifier`, constructs a scope from identity owner, and does not watch `learningCloudTransportProvider`. Its `onCommitted` increments only comparison revision, guarded in order by `isAlive`, `tracker.current.owner/generation == captured identity`, and `_backendOwner() == captured owner`; notification is best-effort and cannot turn committed write into failure. Provider declarations/container creation are lazy. Reading comparison store builds the catalogue-dependent transition engine before persistence access; state provider validates catalogue before store.load. Screen default reads this same catalogue provider once within its catchable loading path before store/state access. v2 providers/revision are unchanged.

- [ ] **Step 1: Write `comparison_transition_derives_only_registered_pair_correctness`** and assert answer for pair 1 selecting Same yields `attempt.correct == false`, selected relation Same, expected Different, one pair attempt, mistake key `(en-fr-phoneme-comparison,fr07b-pair-01,1)`, and unchanged identification fields (not present); pair 2 selecting Same yields true despite distinct refs `fr-word-rue`/`fr-word-rouge`.
- [ ] **Step 2: Write `comparison_transition_rejects_missing_stale_or_cross_profile_observations`**: reject missing/duplicate A/B, B ref swapped, `practiceTts`, `reviewedRecording`, cancelled, wrong activity/run/round/pair/profile, mismatched A/B lifecycle epochs and stale cursor; confirm no attempt/state advancement. Pure transition can validate structural consistency only; it cannot attest whether a mutually matching old UI epoch was current. Transient owner grants enforce freshness before command construction; frozen saved commands retain those observations through retry.
- [ ] **Step 3: Write `comparison_key_matches_owner_encoding_and_family_isolated`**: guest key exact `course.learning.comparison.v1.ZW4tZnI.g`; account `acct-1` uses base64url `YWNjdC0x` → `.a.YWNjdC0x`; course key differs from `LearningScope.storageKey`; same token/activity/sequence in separate family documents is accepted as a first commit in each, never treated as cross-family duplicate.

The test-local helper signatures are `LearningCommand v2CommandWithToken(LearningCommand fixture,String token)` and `ComparisonLearningCommand comparisonCommandWithToken(ComparisonLearningCommand fixture,String token)`; each reconstructs the same command fields with only token replaced. `v2Fixture.command` and `comparisonFixture.command` are valid start commands at each family’s initial cursor.

```dart
final sharedToken = 'abcdefghijklmnopqrstuv'; // exactly 22 base64url characters
final v2 = await v2Repository.submit(v2CommandWithToken(v2Fixture.command, sharedToken));
final pair = await comparisonRepository.submit(
    comparisonCommandWithToken(comparisonFixture.command, sharedToken));
expect(v2.duplicate, isFalse);
expect(pair.duplicate, isFalse);
expect(v2.state.revision, 1);
expect(pair.state.revision, 1);
```
- [ ] **Step 4: Write `comparison_codec_preserves_unsupported_bytes_and_v2_sibling`**: encode exact top-level schema/family/closed key set; test future schema 2, wrong owner/course/family, unknown top-level/nested field, bool-as-int, bad session, wrong receipt fingerprint all throw unavailable; assert raw string identical before/after; load valid v2 fixture after each comparison failure and assert exact v2 bytes/fingerprint unchanged.

```dart
final original = jsonEncode(<String, Object?>{...validComparisonDocument,
  'schemaVersion': 2});
expect(() => codec.decode(original, guestScope, catalogue),
    throwsA(isA<ComparisonUnavailableException>()));
expect(persistence.platform[guestScope.storageKey], original);
expect(const LearningDocumentCodec().encode(v2Fixture), v2FixtureBytes);
expect(codec.canonicalCommand(advanceCommand), contains('"kind":"advance"'));
expect(codec.canonicalCommand(reviewCommand), contains('"kind":"review"'));
```

- [ ] **Step 5: Write real adapter tests** `comparison_store_atomic_retry_duplicate_and_rollback` and `pair_attempts_never_project_to_sound_or_cloud_evidence`, using existing `FakeLearningPersistence` from `frontend/test/support/course_learning_persistence_fakes.dart` implementing `read/write/restore/reload`, plus `SharedPreferences.setMockInitialValues` integration. When write is held, compare only the already-loaded committed state/read model and assert it has no new attempt; do not await another `load()` behind the global tail until gate release. Then release and assert ACK state. Failure+verified rollback retains old bytes; rollback failure blocks only comparison key; retry exact command commits once; duplicate leaves revision/ordinal/count unchanged; guest/account and A→B→A isolated; no cloud or sound evidence projection.

```dart
final first = await store.submit(answerCommand);
final duplicate = await store.submit(answerCommand);
expect(first.duplicate, isFalse);
expect(duplicate.duplicate, isTrue);
expect(duplicate.state.revision, first.state.revision);
expect(duplicate.state.commitOrdinal, first.state.commitOrdinal);
expect(duplicate.state.attempts, hasLength(1));
```

- [ ] **Step 6: Write `comparison_summaries_survive_bounded_attempt_pruning`**: commit >2000 valid answers; attempts/receipts cap at 2000 while each per-pair exposure bucket, mistake and completion policy remain unchanged. Restore checkpoint without old answer history; debrief counts remain and next `AttemptPresentation` derives from current session, not pruned records.
- [ ] **Step 7: Write `comparison_provider_is_independent_and_invalidates_only_its_read`** in `comparison_learning_providers_test.dart`: comparison commit invalidates `_comparisonLearningStateRevisionProvider`/comparison state only; v2 commit invalidates v2 state only; failures do not cross-block; A→B→A old callback cannot increment revisions. Assert callback is suppressed when provider `isAlive` is false, auth tracker owner/generation differs from captured identity, or `_backendOwner()` differs. Creating ProviderContainer/provider declarations does not validate/load; reading comparison store/state validates catalogue before persistence; invalid catalogue asserts zero persistence reads.
- [ ] **Step 8: Run focused RED** `$FLUTTER test --no-pub test/unit/comparison_learning_transition_test.dart test/unit/comparison_learning_codec_test.dart test/unit/comparison_learning_store_test.dart test/unit/comparison_learning_providers_test.dart --reporter expanded`; missing APIs are scaffolding RED, not product regression.
- [ ] **Step 9: Implement typed payload, commands, pure transition, strict codec, adapter, repository and providers** using signatures above. Preserve raw bytes on decode failure; no reset/migration. Provider declarations are lazy; reading comparison store/state validates full catalogue before any persistence read.
- [ ] **Step 10: Run GREEN and v2 regression suites:** rerun Step 8 and `$FLUTTER test --no-pub test/unit/course_learning_store_test.dart test/unit/course_learning_commit_isolation_test.dart test/widget/course_learning_quarantine_recovery_test.dart test/unit/course_learning_sync_test.dart test/unit/course_learning_codec_test.dart --reporter expanded`; `$FLUTTER analyze --no-pub`; require pass/no issues, format owned files, `git diff --check`.
- [ ] **Step 11: Commit/publish Task 3** with explicit `git add` for the five comparison core files, providers file and four tests from the table; commit `feat: add isolated comparison learning profile`; scoped PR, independent review/controller verification/merge and published-tree check before Task 4.

## Task 4: Extract the shared discovery/comparison owner seam

**Files:** Create `frontend/lib/src/features/course/lesson_exercise_owner.dart` and `frontend/test/unit/lesson_exercise_owner_test.dart`; modify `frontend/lib/src/features/course/discovery_lesson_screen.dart` and only the four listed discovery owner test files.

**Consumes:** Actual legacy `CourseAudio` (`Future<void> speak(String word); Future<void> stop()`), `CourseReferenceAudio.playReference(String referenceId,{CourseAudioUse use = alphaPractice, CourseAudioVariant variant = normal, bool allowPracticeTts = false}) -> Future<CourseAudioResult>`, and `CourseAudioResult` fields `outcome/referenceId/source/failure` from `course_audio_contract.dart`; providers `courseAudioProvider` and `courseReferenceAudioProvider` in `course_audio.dart`. Discovery currently reads `courseAudioProvider`, calls `speak(word)`, and uses `_generation`, `_playbackGeneration`, `_suspended`, `_pendingCommand`, `_pendingStore`, `_pendingOnSaved`, `_saveOp`, `_loadOp`, `_onListen`, `_runSave`, `_onRetrySave`, `didChangeAppLifecycleState` and `_onStoreReplaced` in `discovery_lesson_screen.dart`. There is no `didUpdateWidget` override. Extract mechanics only; leave discovery on unchanged `CourseAudio.speak/stop` and preserve pending-recording/practice-speech evidence mapping.

**Produces in `lesson_exercise_owner.dart`:** `ExercisePromptIdentity({required String activityId,required int runGeneration,required int
round,required String itemId})`; equality covers prompt fields only. `ExerciseRequestIdentity({required ExercisePromptIdentity prompt,required
ComparisonSample? sample,required String referenceId,required int lifecycleEpoch,required int playbackNonce})`; lifecycle epoch is shared for prompt;
playback nonce increments per sample request/replay. `ExerciseHearingGrant<TSource>({required ExerciseRequestIdentity request,required TSource
source})`. `ExerciseLifecycleFence` exposes `int get lifecycleEpoch`, `bool get isSuspended`, `int beginPlayback()`, `bool owns(int lifecycleEpoch)`,
`void suspend()`, `void resume()`, `void replaceOwner()`, `void dispose()`. `inactive` no-op; beginPlayback advances a separate playback nonce;
paused/hidden/detached increments lifecycle epoch/suspends grants but retains frozen command; resume reopens only if previously suspended and never
resubmits itself. Owner replacement/disposal retires grants/pending. `ExerciseAudioGrants<TSource>({required Set<ComparisonSample?> requiredSamples})`
accepts `{null}` discovery or `{a,b}` comparison; exact methods: `void beginPrompt(ExercisePromptIdentity prompt)`, `void
beginSample(ExerciseRequestIdentity request)`, `void revoke(ComparisonSample? sample)`, `ExerciseHearingGrant<TSource>? grantFor(ComparisonSample?
sample)`, `Set<ComparisonSample> get heardSamples` (filters null), `bool get canAnswer`, `bool acceptSuccess({required ExerciseRequestIdentity
request,required String? actualReferenceId,required CourseAudioOutcome outcome,required TSource? actualSource})`, `void retire()`. Beginning a sample
revokes only that slot and records latest nonce, preserving the other grant. Success requires exact latest request+nonce, matching ref, completed
outcome and nonnull source. Durable observation `uiGeneration` records lifecycle epoch, never playback nonce.

`FrozenExerciseSave<C,R>({required ExerciseLifecycleFence fence,required Future<R> Function(C) submit,required bool Function() stillOwnsStoreAuthRoute,required Future<void> Function(R) onAcknowledged})` exposes `bool get claimed`, `C? get pendingCommand`, `Future<R?> claimAndSubmit(C command)`, `Future<R?> retry()`, `void onConflictReloaded()`, `void retireOwner()`. No command is held by constructor: `claimAndSubmit` synchronously claims the supplied command once before its first await. Failed transient save retains exact command; conflict retains it only until explicit reload calls `onConflictReloaded`, which clears pending and claim. Retry captures lifecycle epoch and operation ID; if suspend/resume occurs during held old write, old completion cannot clear a newer retry, and retry can resubmit the same frozen command through idempotent receipt handling. `stillOwnsStoreAuthRoute` must check captured store identity, auth generation, route mounted/identity in addition to fence generation; suspended state blocks answer/navigation. ACK clears pending before invoking navigation; callback failures are reported separately and never reinterpret committed write as failed/retryable. Old finally blocks mutate state only when their captured operation ID is still current. Discovery creates its existing `LearningCommand`; comparison creates its typed command outside the helper.

Implement value equality and matching `hashCode` for `ExercisePromptIdentity` (activity/run/round/item) and `ExerciseRequestIdentity` (prompt/sample/reference/lifecycleEpoch/playbackNonce); completion tests and keyed grant maps must compare decoded/equivalent identities by value, not instance identity.

- [ ] **Step 1: Write owner-unit `grant_requires_exact_request_and_retry_reuses_claim`** using `ExerciseAudioGrants<CourseAudioSource>(requiredSamples:{ComparisonSample.a,ComparisonSample.b})`: accept A only for current prompt/lifecycleEpoch/playbackNonce/ref/completed/unverifiedRecording; assert canAnswer false until B succeeds; replay A changes nonce and revokes only A, late prior A completion fails. Create a second grant helper with `requiredSamples:{null}` and assert one legacy sample-null completion enables discovery. In parallel assert claim/retry uses `identical(originalCommand)`, duplicate claim fails, callback fires once after ACK, and simulated callback throw leaves `pendingCommand == null` and saved-result classification successful.

```dart
final prompt = ExercisePromptIdentity(activityId: comparisonActivityId,
    runGeneration: 1, round: 1, itemId: 'fr07b-pair-01');
final aRequest = ExerciseRequestIdentity(prompt: prompt,
    sample: ComparisonSample.a, referenceId: 'fr-word-tout',
    lifecycleEpoch: 7, playbackNonce: 1);
grants.beginPrompt(prompt);
grants.beginSample(aRequest);
expect(grants.acceptSuccess(request: aRequest,
    actualReferenceId: 'fr-word-tout', outcome: CourseAudioOutcome.completed,
    actualSource: CourseAudioSource.unverifiedRecording), isTrue);
expect(grants.grantFor(ComparisonSample.a)?.request.playbackNonce, 1);
expect(grants.canAnswer, isFalse);
final bRequest = ExerciseRequestIdentity(prompt: prompt,
    sample: ComparisonSample.b, referenceId: 'fr-word-tu',
    lifecycleEpoch: 7, playbackNonce: 2);
grants.beginSample(bRequest);
expect(grants.acceptSuccess(request: bRequest, actualReferenceId: 'fr-word-tu',
    outcome: CourseAudioOutcome.completed,
    actualSource: CourseAudioSource.unverifiedRecording), isTrue);
expect(grants.canAnswer, isTrue);
final oldA = aRequest;
grants.beginSample(ExerciseRequestIdentity(prompt: prompt,
    sample: ComparisonSample.a, referenceId: 'fr-word-tout',
    lifecycleEpoch: 7, playbackNonce: 3));
expect(grants.acceptSuccess(request: oldA, actualReferenceId: 'fr-word-tout',
    outcome: CourseAudioOutcome.completed,
    actualSource: CourseAudioSource.unverifiedRecording), isFalse);
expect(grants.grantFor(ComparisonSample.b), isNotNull);
expect(grants.canAnswer, isFalse);
```

For the same test, define `final originalCommand = TestCommand();` and `FrozenExerciseSave<TestCommand,TestResult> save = FrozenExerciseSave(fence:fence,submit:(c) async { submitted.add(c); if (failOnce) throw StateError('write failed'); return result; },stillOwnsStoreAuthRoute:()=>true,onAcknowledged:(r) async { callbackCount++; });`; assert `await save.claimAndSubmit(originalCommand)` fails/retains, then `await save.retry()` sends `identical(originalCommand)`. A second `claimAndSubmit` while claimed returns null. Test conflict + explicit `onConflictReloaded` clears pending, and callback throw does not reinstate it.
- [ ] **Step 2: Add discovery regression assertions** in existing discovery widgets for one-word success, stale completion after next item, cancellation/failure, suspension/resume and owner replacement; assert the legacy `CourseAudio.speak` fake call and evidence source remain unchanged. Existing coverage which already passes is a preservation guard, not a claimed defect.
- [ ] **Step 3: Run pre-extraction tests**: `$FLUTTER test --no-pub test/unit/lesson_exercise_owner_test.dart test/widget/discovery_lesson_test.dart test/widget/discovery_lesson_recovery_test.dart test/widget/discovery_lesson_recovery_accessibility_test.dart test/widget/discovery_lesson_review_repeat_test.dart --reporter expanded`.
- [ ] **Step 4: Implement helper and migrate discovery fields/methods.** `didChangeAppLifecycleState`, `_onStoreReplaced`, `_onListen`, `_runSave`, `_onRetrySave`, and `dispose` delegate ownership/retirement only; existing screen retains prompts, session, command construction, errors, layout and route effects. Do not call `CourseReferenceAudio` from discovery or change `CourseAudio` policy.
- [ ] **Step 5: Add `shared_owner_preserves_discovery_frozen_retry_and_lifecycle`** as a post-migration integration assertion for same-owner resume, A→B→A repository swap, orphaned old load/save, one exit after ACK and no late old callback stopping newer playback; settle held completers in `addTearDown`/`try-finally`.
- [ ] **Step 6: Verify** Step 3 suites plus `$FLUTTER test --no-pub test/widget/discovery_section_view_test.dart test/widget/discovery_finite_round_contract_test.dart test/widget/discovery_listening_exercise_test.dart --reporter expanded` and `$FLUTTER analyze --no-pub`; require pass/no issues, format owned files, `git diff --check`, and inspect discovery diff for changes beyond typed delegation.
- [ ] **Step 7: Commit/publish Task 4** with explicit `git add frontend/lib/src/features/course/lesson_exercise_owner.dart frontend/lib/src/features/course/discovery_lesson_screen.dart frontend/test/unit/lesson_exercise_owner_test.dart frontend/test/widget/discovery_lesson_test.dart frontend/test/widget/discovery_lesson_recovery_test.dart frontend/test/widget/discovery_lesson_recovery_accessibility_test.dart frontend/test/widget/discovery_lesson_review_repeat_test.dart`; commit `refactor: share lesson audio ownership fences`, scoped PR and independent/controller review/verification/merge. Task 5 starts only from merged published tree.

## Task 5: Build the dedicated controlled comparison flow

**Files:** Create only `frontend/lib/src/features/course/comparison_lesson_screen.dart`, `comparison_section_debrief.dart`, `frontend/test/widget/comparison_lesson_screen_test.dart`, and `comparison_section_debrief_test.dart`. All new fakes/helpers live in those test files; do not import another test's `main` or edit shared test support.

**Consumes:** Published comparison catalogue/profile/store/commands/providers and shared owner seam; `courseReferenceAudioProvider` (not legacy `courseAudioProvider`) returning `CourseReferenceAudio`; existing `SoundComparison({required SoundComparisonPrompt prompt,required ListeningExerciseState state,required Set<ComparisonSample> heardSamples,PhonemeRelation? selectedRelation,required ValueChanged<ComparisonSample> onListen,required ValueChanged<PhonemeRelation> onAnswer})`; `ListeningExerciseState({bool busy=false,bool playing=false,bool blocked=false,bool answered=false,ListeningFeedback? feedback})`; `CourseAudioResult`. Do not modify this controlled component.

**Produces:** Dedicated screen with discovery-equivalent load/resume, error/reload, practice/debrief/review/Finish/retry states; active prompt exposes only neutral target instruction, A/B and Same/Different, exact disclosure, no pair ID/word/meaning/IPA/phoneme/key/debrief in visible text or semantics. Audio uses shared owner with exact `alphaPractice`, `allowPracticeTts:false`, normal variant. Build durable A/B observations only from `grantFor(a/b)` after both successes; copy exact reference/source/activity/run/round/pair/profile and shared lifecycle epoch; never persist playback nonce. Cancel/failure creates no answer. Queue is finite unresolved authored order, optional review at passing debrief, no auto-repeat; first-run completion requires all ten attempted plus saved threshold/debrief; review Finish never completes. Debrief shows full rule and authored-order notes, latest counts/threshold, no guessed choice.

**Exact screen/debrief contracts:**

```dart
class ComparisonLessonScreen extends ConsumerStatefulWidget {
  const ComparisonLessonScreen({super.key, required this.activityId,
    this.review = false, this.policy, this.pairId, this.catalogueLoader});
  final String activityId;
  final bool review;
  final LessonPolicy? policy; // fresh runs only; saved policy wins on resume
  final String? pairId; // validated display context only; never changes queue order
  final ComparisonCatalogue Function()? catalogueLoader;
}
class ComparisonSectionDebrief extends StatelessWidget {
  const ComparisonSectionDebrief({super.key, required this.catalogue,
    required this.session, required this.busy, required this.error,
    required this.conflict, required this.canFinish, required this.onReview,
    required this.onFinish, required this.onRetrySave, required this.onReload,
    this.onPractiseAgain});
  final ComparisonCatalogue catalogue;
  final LessonSectionSession session;
  final bool busy, canFinish;
  final String? error, conflict;
  final VoidCallback onReview, onFinish, onRetrySave, onReload;
  final VoidCallback? onPractiseAgain;
}
```

The screen validates `activityId` and optional `pairId` inside its recoverable load/error try before persistence access. Production default reads `comparisonCatalogueProvider` once and uses that exact cached object for both UI and transition/store; do not call `loadFrenchComparisonCatalogue()` again and create a distinct instance. Only after catalogue validation succeeds does it read comparison store/state. An optional `catalogueLoader` exists for tests: a loader that throws a typed validation exception is shown as local unavailable and that failure remains through owner/lifecycle refresh until explicit retry/remount; it must not read store/state. If a test loader returns a catalogue, require full equality with provider catalogue: activity/section/revision, ordered pair IDs, sample references/target phoneme+ordinal, slots, keys, declarations, instructions and notes. Test overrides use the same valid instance for loader and provider. `pairId` is display context only, never queue reordering. UI/debrief behavior remains as specified above.

Widget-test `_ControlledCourseReferenceAudio implements CourseReferenceAudio` records `List<({String referenceId,CourseAudioUse use,CourseAudioVariant variant,bool allowPracticeTts})> requests`, queues `Completer<CourseAudioResult>`, and exposes `completeNext(CourseAudioResult result)`. `_mountComparison(WidgetTester tester,{required _ComparisonWidgetStore store,required _ControlledCourseReferenceAudio audio,required ComparisonCatalogue catalogue,bool review=false,String? pairId,ComparisonCatalogue Function()? loader}) -> Future<ProviderContainer>` defaults loader to return the exact provider catalogue instance; override both sources with the same valid instance. A deliberately throwing loader may diverge only to test early unavailable; a returning loader must fully match the provider catalogue in all content fields. Release gates and dispose container in teardown.

- [ ] **Step 1: Write `comparison_view_is_neutral_and_accessible`** with a catalogue containing unique hidden sentinels; assert exact disclosure, target instruction, A/B/Same/Different, and `find.text/find.byTooltip/semantics` reveal no pair ID/word/meaning/IPA/target/key/note. Assert only explicit playback source controls, non-color feedback, keyboard relation activation and no overflow/scroll reachability at 360×640 with 2× and 3× text.
- [ ] **Step 2: Write `comparison_catalogue_failure_precedes_profile_load`**: inject malformed catalogue loader; assert neutral unavailable, `store.loadCalls == 0`, `prepareCalls == 0`, `submitCalls == 0`, no audio. Replace owner/provider and remount; no run starts, discovery/legacy unaffected.

```dart
await _mountComparison(tester, store: store, audio: audio,
    catalogue: approvedCatalogue,
    loader: () => ComparisonCatalogue.fromDrafts(
        activityId: comparisonActivityId, sectionId: comparisonActivityId,
        contentRevision: 1, exercises: malformedDrafts,
        referencePhonemes: fixturePhonemes));
await tester.pump();
expect(find.text('This comparison activity is unavailable.'), findsOneWidget);
expect(store.loadCalls, 0);
expect(store.prepareCalls, 0);
expect(store.submitCalls, 0);
expect(audio.requests, isEmpty);
```
- [ ] **Step 3: Write `comparison_audio_requires_both_exact_successes_and_replay_revokes`**: request A and B separately; assert exact `alphaPractice/normal/false`, successful A actual ref/source grants only A, answer disabled until B; unexpected ref/source and failed/cancelled result grant nothing; replay A immediately removes A only, failure remains unscored; reverse B→A also succeeds. Assert no `speak` TTS fallback.

```dart
await tester.tap(find.text('Listen to sample A'));
expect(audio.requests.single, (referenceId: 'fr-word-tout',
    use: CourseAudioUse.alphaPractice, variant: CourseAudioVariant.normal,
    allowPracticeTts: false));
audio.completeNext(CourseAudioResult.completed(
    referenceId: 'fr-word-tout', source: CourseAudioSource.unverifiedRecording));
await tester.pump();
expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Same'))
    .onPressed, isNull);
await tester.tap(find.text('Listen to sample B'));
audio.completeNext(CourseAudioResult.completed(
    referenceId: 'fr-word-tu', source: CourseAudioSource.unverifiedRecording));
await tester.pump();
expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Same'))
    .onPressed, isNotNull);
```
- [ ] **Step 4: Write `comparison_owner_fences_audio_and_freezes_claimed_retry`**: hold result A, navigate/rebuild next prompt or replace owner, settle result and assert no unlock/feedback/submit/stop of newer audio. Background/route/dispose fence late results. Double tap/keyboard produces one prepared command. Fail held submit, assert no progress advance/completion; Retry sends identical command and original source observations without replay; old store result after A→B→A cannot change new owner or pop route. Complete gates in `try/finally`.
- [ ] **Step 5: Write `comparison_finite_review_and_restore`**: assert first-pass order ten; default 8/10 pass; saved threshold resumes; incomplete/underthreshold cannot Finish; queue exactly unresolved authored order once; wrong repeat does not grow queue; queue ends at debrief with optional review on pass; Review-mode Finish never adds completion; unanswered restore requires fresh A/B; answered restore shows feedback with `selectedRelation == null`, no playback; new run preserves historical attempts/mistakes/completions.
- [ ] **Step 6: Write controlled debrief tests** for full rule and all-correct no unresolved notes; unresolved notes in authored order, current threshold, Review and Finish enabled/disabled correctly, `error/conflict/busy` controls and exact callbacks. Run RED: `$FLUTTER test --no-pub test/widget/comparison_lesson_screen_test.dart test/widget/comparison_section_debrief_test.dart --reporter expanded`; classify missing API vs real failure.
- [ ] **Step 7: Implement screen/debrief** with exact constructors above, Task 3 provider and Task 4 owner; no duplicate session/retry/audio mechanics. Immediate Correct/Not yet can reflect claimed answer; advance and committed counts/completion remain ACK-gated; conflicts require explicit reload.
- [ ] **Step 8: Run GREEN** Step 6 suites plus `$FLUTTER test --no-pub test/unit/comparison_learning_transition_test.dart test/unit/comparison_learning_codec_test.dart test/unit/comparison_learning_store_test.dart test/unit/comparison_learning_providers_test.dart test/widget/listening_exercise_test.dart --reporter expanded` and `$FLUTTER analyze --no-pub`; require pass/no issues, format owned paths and `git diff --check`.
- [ ] **Step 9: Commit/publish Task 5** `git add frontend/lib/src/features/course/comparison_lesson_screen.dart frontend/lib/src/features/course/comparison_section_debrief.dart frontend/test/widget/comparison_lesson_screen_test.dart frontend/test/widget/comparison_section_debrief_test.dart`; commit `feat: add finite phoneme comparison practice`, scoped PR, independent review/controller verification/merge, exact merged tree check before Task 6.

## Task 6: Wire independent route, Home and honest comparison progress

**Files:** Create only `frontend/lib/src/features/course/comparison_progress_summary.dart`; modify only `frontend/lib/src/routing/app_router.dart`, `frontend/lib/src/features/home/home_screen.dart`, and `frontend/lib/src/features/course/course_progress_screen.dart`; create `frontend/test/widget/comparison_entry_flow_test.dart` and modify only `frontend/test/widget/home_navigation_test.dart` and `frontend/test/widget/course_learning_progress_test.dart`. Comparison providers are produced and tested in Task 3, not rewired here.

**Consumes:** Published `comparisonLearningStoreProvider`, `comparisonLearningStateProvider`, `ComparisonLearningState`, `ComparisonCompletion`, `ComparisonPairMistake`, `ComparisonCatalogue`, `ComparisonLessonScreen`, `CourseLearningState`, existing `courseLearningStateProvider`, `LinguistApp` from `frontend/lib/src/app.dart`, and `appRouterProvider` from `frontend/lib/src/routing/app_router.dart`. Existing `appRouterProvider` routes `/course-lesson/:id`, `/course-progress`, `/course-review`, `/home`, `/compare`; use the real router in integration tests.

**Produces:** `ComparisonProgressSummary.fromState({required ComparisonLearningState state, required ComparisonCatalogue catalogue})` exposes immutable `int completedRuns`, `int uniqueAttemptedPairs`, `int correctAnswers`, `int totalAnswers`, `int afterDebriefAnswers`, `int unresolvedPairCount`, `List<ComparisonPairMistake> unresolvedMistakes`, and `bool hasCurrentRevisionCompletion`. Constructor copies `unresolvedMistakes` into an unmodifiable list. Derive U from positive per-pair buckets, never bounded attempts. `correctAnswers/totalAnswers` sum `firstInRun + repeatInRun`; `afterDebrief` is an overlapping dimension, separately labeled and not added again. These are exposures, not mastery. `completedRuns` counts distinct current-revision completion-policy identities `(activityId,contentRevision,policyRevision,thresholdPercent)`, not chronological runs; label `Comparison completion policies: N`. Never infer completion from draft checkpoint. Labels: `Comparison practice, not phoneme mastery`, `Comparison pairs attempted: U/10`, `Comparison answers: C/T`, `After-debrief comparison answers: D`, `Comparison completion policies: N`, `Unresolved comparison pairs: N`. Home Review appears only after current committed first-run completion. New run is explicit `Practise again`.

Register `GoRoute(path:'/course-comparison/:activityId', builder:...)`. Parse exact `review` and optional `pairId`, reject unknown/duplicate query parameters and invalid values before provider access, then build `ComparisonLessonScreen(activityId: activityId, review: review, pairId: pairId)`. Only activity `en-fr-phoneme-comparison` and catalogue-registered pair IDs are valid. A pairId never jumps/reorders queue: show context at saved debrief, require explicit Review, preserve authored-order finite unresolved queue; active checkpoints resume unchanged. Mistake links use `?pairId=<id>&review=true`; Home review uses `?review=true`, Continue no query. Unknown activity/query/pair displays local unavailable before load/start/write.

Home always renders the additive `Comparison alpha` entry independently of either progress `AsyncValue`; a comparison state error changes only its count/action to `Unavailable` and entry still routes to local recovery. Comparison error/corrupt loader never replaces v2 content; v2 load failure does not hide comparison entry/count. Progress similarly renders each section from its own provider; each uses `skipLoadingOnRefresh:false` for owner-sensitive values, never showing stale-owner counts during refresh/error. Existing primary discovery card and four legacy links remain exactly; `/compare` remains its current screen. Tests mount actual router; no hand-built route map.

- [ ] **Step 1: Write `comparison_summary_counts_only_current_committed_evidence`** in `comparison_entry_flow_test.dart`: duplicate current completion identity dedupes; stale content revision/policy and unknown activity do not count; draft checkpoint with ten correct but no committed completion yields `completedRuns == 0`; committed finish adds one policy identity. Assert exact labels and immutable per-pair summary counts.
- [ ] **Step 2: Write real-router `comparison_entry_is_additive_and_unknown_is_local`** using actual `LinguistApp`/`appRouterProvider`: Home card opens `/course-comparison/en-fr-phoneme-comparison`; current discovery primary and each of `en-fr-vowels`, `en-fr-nasal`, `en-fr-r`, `en-fr-mix` continue to their actual existing screen; `/compare` remains `AudioCompareScreen`. Unknown activity, `review=maybe`, duplicate query, unknown pairId and invalid content display neutral unavailable, `loadCalls/prepareCalls/submitCalls == 0`; discovery/legacy remain accessible.
- [ ] **Step 3: Write `comparison_pair_review_preserves_finite_queue_context`**: exact mistake link `/course-comparison/en-fr-phoneme-comparison?pairId=fr07b-pair-04&review=true`; seed current checkpoint at debrief with unresolved `pair-01,pair-04`; assert context identifies pair-04 but does not start or mutate a round, explicit Review queues `[pair-01,pair-04]` in authored order exactly once, active checkpoint deep link resumes unchanged, route pop count exactly one on successful Finish.
- [ ] **Step 4: Write `comparison_entry_counts_only_acknowledged_first_run_finish`**: real route flow answer all ten, then hold final first-run Finish write; before ACK assert one pending command, route still present, committed completion/count `0`, existing identification summary unchanged. Fail write then retry and assert identical command; release ACK and assert exactly one completion/count; repeat same receipt no change. Enter `review=true`, finish and assert no completion. Owner A→B→A assertions ensure stale count never rendered.

```dart
expect(container.read(comparisonLearningStateProvider).value!.completions, isEmpty);
await tester.tap(find.text('Finish comparison'));
await tester.pump(); // Finish write remains gated; do not pumpAndSettle.
expect(find.byType(ComparisonLessonScreen), findsOneWidget);
expect(summaryForCurrentOwner().completedRuns, 0);
store.completeWrite();
await tester.pump();
expect(summaryForCurrentOwner().completedRuns, 1);
```

- [ ] **Step 5: Write `comparison_and_discovery_load_failures_are_independent`**: inject comparison corrupt/failing load and assert Home/progress still renders discovery/legacy; reverse with v2 load failure and assert comparison card/progress remains. Hold refresh and assert stale owner count is not displayed (`skipLoadingOnRefresh:false`).
- [ ] **Step 6: Run RED** `$FLUTTER test --no-pub test/widget/comparison_entry_flow_test.dart --reporter expanded`; verify missing Home/route/projection assertions fail on expected behavior, not missing fixture setup.
- [ ] **Step 7: Implement pure summary, exact route/query handling, Home and progress**; use Task 3 providers, no provider edits or duplicated counts. Pair deeplink never bypasses saved state/finite queue; explicit new run stays a user action.
- [ ] **Step 8: Update only superseded assertions** in `home_navigation_test.dart` and `course_learning_progress_test.dart`, retaining all discovery/legacy/ownership/retry expectations.
- [ ] **Step 9: Run focused then integrated verification:** `$FLUTTER test --no-pub test/widget/comparison_entry_flow_test.dart test/widget/home_navigation_test.dart test/widget/course_learning_progress_test.dart --reporter expanded`; then all comparison unit/widget tests, actual route tests and `$FLUTTER test --no-pub --reporter expanded`; `$FLUTTER analyze --no-pub`; `$FLUTTER build web --release --no-pub`. Require test exits 0, analyze no issues and build `Built build/web`. From root run `python3 -m unittest discover -s scripts -p 'test_*.py' -v` and `python3 scripts/verify_french_audio.py --repo-root .`; require exit 0 and still-pending asset state. Format owned files and `git diff --check`.
- [ ] **Step 10: Preserve and review exact integrated scope.** Compare preservation hashes/status with execution baseline: manifest, binaries, provenance/licences/root `LICENSE`, FR-01 content/revision, v2 codec/key/fingerprint fixtures, v2 backup/cloud behavior, discovery Home/route/counts and `/compare` unchanged. Check full Task 1–6 diff against every spec acceptance row; no new dependencies/backend, no generated build output staged, no out-of-scope product changes.
- [ ] **Step 11: Commit/publish Task 6** with `git add frontend/lib/src/features/course/comparison_progress_summary.dart frontend/lib/src/routing/app_router.dart frontend/lib/src/features/home/home_screen.dart frontend/lib/src/features/course/course_progress_screen.dart frontend/test/widget/comparison_entry_flow_test.dart frontend/test/widget/home_navigation_test.dart frontend/test/widget/course_learning_progress_test.dart`; commit `feat: expose local phoneme comparison practice`, scoped PR to `main`; obtain independent code review/controller whole-feature review, resolve blockers, verify exact PR head/current base/reviews/checks, rerun affected gates if either changes, merge only reviewed PR without override and verify published merged tree.

## 2. Controller integration and final gates

- [ ] Map spec §6 rows to named executed tests: content/inventory Task 1; controlled neutral UI/audio/session/restore Task 5; codec/profile/transactions/evidence isolation Tasks 2–3; owner lifecycle Task 4–5; Home/route/progress/discovery preservation Task 6; audio preservation verifier and immutable preservation checks.
- [ ] Independently review actual integrated PR diff and obtain independent code review; check spec compliance, type/API consistency, v2 compatibility, no hidden metadata, no unrelated changes, and no unresolved blocking findings. A worker self-review is not independent review.
- [ ] From `frontend/`, independently run `/home/klottick/develop/flutter/bin/flutter test --no-pub --reporter expanded`, `/home/klottick/develop/flutter/bin/flutter analyze --no-pub`, and `/home/klottick/develop/flutter/bin/flutter build web --release --no-pub`; require exit 0, no analysis issues, build success. From repository root run `python3 -m unittest discover -s scripts -p 'test_*.py' -v` and `python3 scripts/verify_french_audio.py --repo-root .`; report exact outputs/results and candidate pending state. Historical Python counts are not evidence; inspect current command exit and output.
- [ ] Verify exact PR head and current `main` base, available checks/reviews/protection, preservation hashes and full diff. Missing checks are outstanding gates, not success. If base/head changes, reassess integrated tree and rerun affected verification. Merge only the approved reviewed PR, no bypass.
- [ ] Fetch/verify published merged tree and have controller record PR URL, reviewed head, merge commit, exact commands/results, outstanding gates in separate controller-owned `docs/superpowers/status/2026-10-17-fr07b-phoneme-comparison.md` documentation PR only after feature integration. Keep French linguistic/audio, rights/licensing, platform playback, assistive-tech, privacy and release gates explicit; do not claim production readiness or FR-01 promotion.

## 3. Plan self-review and approval handoff

Spec content §3 → Task 1 exact content and structural rejection; active presentation/audio §3–4 → Tasks 4–5 typed grants, neutral interface and lifecycle; session/completion/evidence §4 → Tasks 3/5 pair transition and finite-flow gates; profile/recovery §5 → Tasks 2–3 family-aware transaction and strict isolated schema; Home/routes/progress §4 → Task 6; acceptance/preservation §6–7 → each task’s named tests plus controller gates. All five Review Focus conditions have named owning tests. Source paths and referenced existing API names were checked against the current tree; this is plan-only work and no runtime tests or implementation verification were run.

Task 1 output types feed Tasks 3/5/6; Task 2’s typed coordinator is consumed by Task 3 without `Object`/dynamic erasure; Task 3 typed profile/command/receipt contracts feed Tasks 4–6; Task 4 shared owner seam is consumed by Task 5. Discovery behavior remains the Task 4 preservation oracle. Task order is intentionally serial because each published PR establishes the next interface baseline. No source or runtime verification was changed or run for this planning document.

**This plan awaits user review and approval.** The approved execution preference is sequential `openai/gpt-6-luna`; do not ask the user to choose an execution method again. No product implementation, setup/scaffolding or implementation worker starts before approval.
