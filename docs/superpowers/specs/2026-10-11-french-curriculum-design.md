# FR-01 — curriculum contracts and live-pilot content migration

## Intent and approval stage

Help English speakers progress from hearing French contrasts to locating sounds,
connecting spellings, and eventually demonstrating skills in separate assessments.
FR-01 supplies the authored curriculum contracts on which those features depend.
The user selected FR-01 next, then chose **migrate now** rather than an unused
additive catalogue. This written design is for user review; product implementation
and worker dispatch wait for written-spec approval and a reviewed execution plan.

Review record: user approved the core design committed at `62e6e98`. Planning
adds the explicit spelling targetSound clarification below; it is presented with
the execution plan/contracts for review before implementation.

## Selected architecture

Move the live `/u/`–`/y/` pilot's exercise definitions into the new typed catalogue.
The existing discovery screen, session engine and store consume a compatibility
projection of that catalogue immediately. There must not be two independently
authored pilot item lists. This migrates the live content source without rewriting
the proven lifecycle/persistence machinery or changing persisted identifiers.

Alternatives considered: an unused parallel catalogue defers integration bugs;
a simultaneous replacement of all screens, storage and legacy course models adds
unnecessary migration risk. The selected approach integrates the new source now,
retaining narrow compatibility boundaries for existing consumers.

### In scope

- Immutable curriculum, node, section, typed exercise and sentence/token models.
- Stable IDs, ordered prerequisites, content revision and explicit readiness.
- Listening-before-spelling stage order, optional side-quest and assessment slots.
- Structural/content validation and separate content/audio readiness reports.
- The exact existing ten-item pilot authored in the new catalogue.
- Immediate migration of `frenchUySection`/`sectionForLesson` to catalogue-derived
  content, with all existing callers still working.
- Explicit coverage of the seven proposed sounds: `u`, `y`, `i`, `o`, `ɔ̃`, `ɑ̃`, `ʁ`.
  Only `u`/`y` have migrated discovery exercises in this ticket.

### Not in scope

New lesson screens, extra teaching content, a map UI, route locking, recording,
pronunciation scores, speech dependencies, reviewed audio production/playback,
backend schema changes, evidence migration, exam scoring or assessment items.
Existing non-pilot lessons remain on their current screens. Planned catalogue
slots are not new playable lessons. No new dependencies or changes to unpublished
Sound Match work; verify against published `origin/main`.

## Files and dependency direction

New pure-Dart modules in `frontend/lib/src/core/course/`:
- `course_exercise.dart`: exercise/sentence/audio-reference contracts.
- `course_curriculum.dart`: curriculum/node/section/coverage contracts.
- `course_content_validator.dart`: deterministic diagnostics; no I/O.

`french_course.dart` retains `LanguageCourse`, `CourseWord`, `CourseLesson`,
`frenchCourse`, `frenchWords`, `frenchLessons`, and `wordByText` compatibility.
It authors `frenchCurriculum` using the existing curated words and metadata.
`lesson_section.dart` projects its existing public pilot objects from that
catalogue. Generic modules do not import French content, widgets, providers,
storage or audio plugins; French content may import those generic modules.

No edits to policy/session/store/audio runtime, screen/view/router behavior or
cloud events are necessary. If implementation discovers such a requirement,
return it to the controller before broadening the ticket.

## Model contracts

All authored models have final fields; constructors defensively copy nested
collections into unmodifiable views. Enums replace free-form kind/skill strings.
IDs are case-sensitive, nonempty strings. Constructors validate nonempty required
scalar strings and positive revisions/counts with `ArgumentError`. Relationship
rules (including choices, membership and answer keys within a record) belong to
the validator, so invalid authored fixtures can receive useful diagnostics.
These are code-authored models, not a new downloaded JSON format.
No new persistence serialization API is introduced in FR-01.

### Exercises, sentences and audio references

`SkillDimension`: `listening`, `spelling`, `speaking`.
`ExerciseKind`: `listeningChoice`, `spellingChoice`, `sentenceHunt`, `readAloud`.
`ContentPurpose`: `practice`, `assessment`.
`ContentReviewState`: `existingCurated`, `pending`, `reviewed`.

`CourseExercise` is a sealed immutable base with `id`, `sectionId`, `audioRefId`,
`purpose`, `reviewState`; kind and skill are determined by its subtype:
- `ListeningChoiceExercise`: `wordId`, `expectedSound`, ordered `choices`,
  nullable `legacyItemId`. Choices are phoneme labels without slash decoration;
  kind listeningChoice, skill listening. Expected sound must occur exactly once
  among at least two distinct choices. `legacyItemId` is only the pilot's saved-ID
  compatibility alias, not an alternative catalogue identity.
- `SpellingChoiceExercise`: `wordId`, explicit `targetSound`, ordered immutable `SpellingOption(id,text)`
  values, `correctOptionId`; kind spellingChoice, skill spelling. At least two
  distinct option IDs/texts; exactly one referenced correct option. No production
  spelling examples are authored in this ticket.
  Planning clarification: the explicit target lets node/coverage validation know
  which phoneme this task teaches without inferring it from orthography or every
  incidental sound in the word. This field is included in the plan-review handoff.
- `SentenceHuntExercise`: `sentenceId`, `targetSound`; kind sentenceHunt, skill
  listening. Answer locations come from contextual sentence annotations, not
  citation-word membership. No production sentences authored in this ticket.
- `ReadAloudExercise`: `promptText`, `targetSounds`; kind readAloud, skill
  speaking. This is a prompt contract, not a correctness key or validated grader.
  No production read-aloud content or scored speaking readiness is claimed.

`SentenceToken`: `id`, `text`, immutable `phonemes`. Punctuation may have an empty
phoneme list; repeated words require distinct token IDs.
`CourseSentence`: `id`, exact authored `text`, `audioRefId`, ordered `tokens`,
`reviewState`. Its audio reference's spokenText equals text; punctuation and
spacing are authored, not reconstructed by concatenating citation-word audio.
Every token appears in that text in token order; gaps before/between/after tokens
may contain whitespace only, so tokens cannot silently omit spoken words or
punctuation. Repeated words retain their distinct token IDs. One sentence record represents one accepted
contextual pronunciation. Another accepted pronunciation requires a separately
identified sentence/audio record and answer key; no guessed variants or implicit
liaison. This avoids a union of variants falsely becoming an exact-set answer.

`AudioReferenceKind`: `word`, `sound`, `sentence`, `paragraph`.
`CourseAudioReference`: `id`, `kind`, `spokenText`. References declare stable
content identity, not the existence of a reviewed recording or asset path.
For a word reference, spokenText must match the referenced curated word text.
FR-02 owns manifests/provenance/assets; FR-03 owns playback. FR-01 does neither.

### Curriculum structure

`CourseStage`: `hear`, `find`, `spell`, `assess`, in that order.
`CourseNodeKind`: `lesson`, `review`, `game`, `articulation`, `assessment`.
`ContentStatus`: `authored`, `planned` — an authored record is not necessarily
ready for graded use or routed by the app.

`CourseNode`: `id`, `title`, `kind`, `stage`, `status`, `optional`, ordered
`prerequisiteIds`, ordered `sectionIds`, `targetSounds`.
Optional side quests never become prerequisites of required main nodes. Node IDs
are content identities, not URLs; FR-18 owns future route/deep-link enforcement.

`CourseSection`: `id`, `nodeId`, `title`, `explanation`, positive
`contentRevision`, ordered `exerciseIds`, positive
`requiredItemCount`. Explanation is section-end content, never per-attempt help.
The required count describes distinct first-pass items, not retry submissions.
Planned nodes may have zero sections; authored lesson/assessment nodes may not.

`PhonemeCoverage`: `sound`, `discoveryStatus` (`authored` or `planned`),
`practiceExerciseIds`. This is catalogue coverage, not a learner score. Legacy
lesson/arcade membership must not masquerade as migrated discovery coverage.

`CourseCurriculum`: `courseId`, positive `revision`, ordered `nodes`, `sections`,
`exercises`, `sentences`, `audioReferences`, `phonemeCoverage`.
Expose nullable ID lookups `nodeById(String id)`, `sectionById(String id)`,
`exerciseById(String id)`, `sentenceById(String id)`,
`audioReferenceById(String id)`. Return the unique matching record, or null for
absent/ambiguous IDs. ID duplicates remain discoverable during validation rather
than being silently overwritten in a map. Production content
must pass structural validation before its pilot projection is exposed.

## Initial authored catalogue

Course ID `en-fr`, curriculum revision `1`. Preserve all legacy French word/lesson
values and order. Reuse the original title/explanation from `frenchLessons`; do
not duplicate and independently edit those strings.

The live lesson node keeps `en-fr-u-y`, stage hear, kind lesson, authored,
required, no prerequisites (existing access remains unchanged). Its sole section
ID is `en-fr-u-y-listening`; section contentRevision is **1**, requiredItemCount
**10**. Completion continues using the existing **80%** default LessonPolicy,
not a second policy embedded in the catalogue. The compatibility projection keeps sounds
`['u','y']` and the original title/explanation.

| Exercise ID | Word ID / legacy item ID | Expected sound |
|---|---|---|
| `en-fr-u-y-listening-tout` | `tout` | `u` |
| `en-fr-u-y-listening-tu` | `tu` | `y` |
| `en-fr-u-y-listening-rouge` | `rouge` | `u` |
| `en-fr-u-y-listening-rue` | `rue` | `y` |
| `en-fr-u-y-listening-vous` | `vous` | `u` |
| `en-fr-u-y-listening-lune` | `lune` | `y` |
| `en-fr-u-y-listening-doux` | `doux` | `u` |
| `en-fr-u-y-listening-jus` | `jus` | `y` |
| `en-fr-u-y-listening-loup` | `loup` | `u` |
| `en-fr-u-y-listening-mur` | `mur` | `y` |

All ten have purpose practice, reviewState existingCurated, choices `['u','y']`,
and audio reference `fr-word-<wordId>`. Declare word references for all existing
`frenchWords`, with their unchanged texts, so games' future resource needs are
visible. No reviewed recordings or held-out items are invented.

Planned main nodes: `en-fr-find-sounds` (find, prerequisite en-fr-u-y),
`en-fr-connect-spellings` (spell, prerequisite en-fr-find-sounds),
`en-fr-checkpoint` (assess, kind assessment, prerequisite en-fr-connect-spellings).
All are planned, required, with empty sectionIds and explicit readiness blockers.
Optional planned hear-stage nodes: `en-fr-targeted-review` (review),
`en-fr-games` (game), `en-fr-articulation` (articulation); no prerequisites.
They reserve catalogue destinations; do not replace today's review/game links.
The node array orders the pilot, optional nodes, then the three planned main
nodes. FR-11 will lay out the graph, not treat this array as a locked screen.

Coverage array order: u, y, i, o, ɔ̃, ɑ̃, ʁ. u/y list their respective five pilot
exercise IDs and are authored; the rest are planned with empty lists. A word
containing /ʁ/ does not establish an authored /ʁ/ discrimination exercise.

## Validation and resource readiness

`AudioResourceStatus`: `missing`, `practiceTts`, `reviewedRecording`.
`validateCourseContent(CourseCurriculum curriculum, {required
Map<String,List<String>> citationPhonemes, required Set<String> exposedWordIds,
required Map<String,AudioResourceStatus> audioResources})`
returns `CourseValidationReport`: immutable `errors`, `readinessIssues`, and
`bool isStructurallyValid` (errors.isEmpty). Inputs are not mutated. Citation
mapping validates word exercises only; sentence targets use their own phonemes.
The exposed-word set includes all legacy game words as well as practice words,
so a known game prompt cannot silently become a held-out assessment item.

Each diagnostic has stable `code`, `recordId`, and developer-facing `message`;
readiness issues also identify affected use (`practice` or `assessment`). These
are authoring diagnostics, not strings to show during hidden listening puzzles.
Reports are deterministic, in authored traversal order; retain all detectable
independent issues. IDs/lookups must never hide duplicate records.

Structural errors (invalid content): duplicate IDs within each record namespace,
unknown references, self/cyclic prerequisites, required nodes
depending on optional nodes, backward main-stage dependencies, inconsistent
node/section/exercise membership, missing explanations, undersized pools,
duplicate required items/compatibility aliases, unknown target sounds, bad choice
keys, inappropriate exercise/skill/stage/purpose combinations, dangling audio
references, word/audio text mismatches, missing sentence targets or distractors,
duplicate token IDs, incomplete token/text coverage, assessment reuse of exposed
words/audio. Linguistic correctness/variant acceptance still requires a reviewer;
the validator does not infer those from text.

Specific constraints:
- PhonemeCoverage has unique sound labels. Every node/exercise target belongs to
  that declared inventory; a token's full phoneme annotations may include other
  French consonants/vowels and are not restricted to the seven teaching targets.
  Authored coverage references distinct matching practice exercises; planned
  coverage lists none. Coverage references cannot be inferred from spelling or
  from a non-target sound that merely occurs in a practice word.
- IDs have distinct namespaces for node/section/exercise/sentence/audio. Each
  section/exercise has exactly one owner; section nodeId and exercise sectionId must agree
  with the corresponding ordered membership list.
  Each child exercise's teaching targets must be contained in its node's
  targetSounds; duplicate labels/choices are not separate targets.
- A section contains exactly requiredItemCount distinct exercises in FR-01;
  unused oversized sampling pools are not introduced.
- Practice listening choice belongs to hear; practice sentence hunt to find;
  practice spelling to spell. Their assessment-purpose counterparts belong only
  to assess-stage assessment nodes.
  Every exercise in an assessment node has purpose assessment; every exercise
  elsewhere has purpose practice. Lesson stages cannot contain read-aloud in
  this revision. Word choices reference word-kind audio, sentence hunts reference
  sentence-kind audio, and read-aloud prompts reference paragraph-kind audio
  whose spokenText equals promptText. Sound-kind audio is reserved for later
  comparison/coaching contracts and is not a word prompt substitute.
  Read-aloud is allowed in optional articulation or assessment nodes but never
  implies a valid speaking score. Planned empty nodes skip payload checks only,
  not graph/identity checks; planned nodes with sections are rejected in FR-01.
- Listening expectedSound and spelling targetSound belong to the word's curated
  citation phonemes.
  Sentence hunts require at least one matching contextual token and one non-target
  word token; punctuation alone is not a believable distractor.
- Assessment listening/spelling content may not reuse a practice/game word ID or
  an audioRefId referenced by practice. This is content separation, not a promise
  that tests prove exam equivalence or a calibrated score.

Readiness issues (honest incomplete resources): planned content, pending content
review, missing referenced audio resources; assessment content without reviewed
content/recordings; speaking without a validated evaluator. Practice may use
labeled TTS; reviewedRecording never automatically makes an unreviewed answer key
ready. All declared word audio references lacking recordings are reported for
assessment/reference use, including words used by legacy games. Unknown keys in
resource maps must not manufacture catalogue references.

The production catalogue is structurally valid but intentionally has readiness
issues: planned stages/sounds and missing reviewed recordings. The migration must
not fail the existing TTS practice route just because exams remain unavailable.
No new audio manifest/file existence check or native voice-availability claim.

## Compatibility migration and data flow

`frenchCurriculum` is the sole author of the ten exercise definitions.
`lesson_section.dart` adds `factory LessonSection.fromCurriculum(
CourseCurriculum curriculum, {required String lessonId})`. It looks up an authored
lesson node with exactly one section, validates supported listening payloads,
and maps them to existing LessonSectionItem objects. Every exercise must have the
same ordered sound choices, preserving the old section-wide choices contract.
The helper is pure and testable with synthetic catalogues; production lookup
remains pilot-only. It copies the section title/explanation/revision, not a newly
constructed default or an inferred answer key.
It uses legacyItemId for item ID, wordId for word, expectedSound for correctness.
It rejects unsupported kinds, missing aliases, duplicate aliases or missing
pilot records with a developer-facing StateError; never silently drops items.

Retain all public LessonSection/LessonSectionItem constructors and equality;
synthetic UI/unit fixtures must still work. `frenchUySection` remains the same
cached instance returned by `sectionForLesson('en-fr-u-y')`; every other ID still
returns null. Catalogue exercise IDs must **not** enter version-1 snapshots.

Persisted courseId `en-fr`, lessonId `en-fr-u-y`, contentRevision 1, version 1,
ordered item IDs/queues and policy serialization stay unchanged. Existing stores
still replay exact submit/advance/review transitions against the projected items.
No eager writes on loading, database migration, cache clearing, fresh-session reset
or outbox changes. Existing LessonPolicy defaults, saved session policy and
explicit fresh-session widget policy retain their current semantics. No duplicate
catalogue policy field can silently disagree with the active session's policy.

Legacy frenchWords, frenchLessons and citation membership remain unchanged in
value/order and public API. Legacy lesson completion does not become proof of
new proficiency. New catalogue lookups do not change home, routing or game rules.

## Verification and acceptance

- Models detach all nested caller collections; failed mutation attempts leave
  content unchanged. Constructors reject local misuse; validator reports fixture
  graph/key/content/resource problems without throwing incidental lookup errors.
- Test exact IDs/order/kinds/skills/targets/aliases and legacy content parity.
- Prove the pilot projection actually reads catalogue exercises, rather than
  comparing two hard-coded production lists. Use a pure projection helper with
  an injected synthetic valid catalogue to test changed word/order/target inputs;
  production values remain the exact approved pilot.
- Freeze independent pre-migration version-1 snapshots (first pass unanswered
  and answered, debrief, mistake review, custom saved policy). Seed real preferences,
  restore through the screen/store, continue through valid saves, and verify
  exactly-once listening evidence, completion/review behavior and historical
  sibling/score/outbox retention. Expected snapshots must not be generated from
  newly authored catalogue IDs; that would fail to test compatibility.
- Validator tests cover cycles and absent references, duplicate IDs, graph/stage
  errors, ambiguous answers, insufficient pools, sentence targets/distractors,
  practice/assessment contamination and missing/unreviewed audio. Synthetic
  sentence/spelling fixtures are software tests, not reviewed production content.
- Keep the current full repository suite and independent controller regressions
  green, including hidden-word titles, large text, conflict reload, repeat practice,
  committed-only progress reads and actual adapter cancellation.
- Full `flutter test`, `flutter analyze`, JavaScript web build, range whitespace
  check, independent review and explicit migration-scope review before merge.
  No tests may be weakened to tolerate changed IDs/old-save loss or extra routes.
- The broad draft names `sound_match_content_test.dart`, which is not present on
  published main. Do not bundle unpublished Sound Match commits to satisfy that
  path; use existing published game tests and legacy-data parity fixtures.

Acceptance is a live pilot using validated new curriculum content with unchanged
behavior/progress, frozen interfaces for downstream tickets, and honest readiness
diagnostics. It is not delivery of those downstream features or reviewed assets.

## Execution handoff

After user review of this written spec: create a small sequential TDD plan, exact
contract signatures/fixtures and owned files; include the extra lesson_section
migration boundary in FR-01 ownership. Use local ollama/qwen3.8:27b workers, one
active implementer at a time, with controller review and independent verification.
Continue the previously selected PR workflow; preserve current process records and
unpublished work. New worker worktrees belong to the existing phoneme-app project.
