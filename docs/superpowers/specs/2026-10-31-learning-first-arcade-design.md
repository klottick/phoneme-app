# Three learning-first space games

**Status: proposed design, awaiting user review.** The user selected the three-game
approach, authorized complete game redesign and requested browser mockups. This
does not yet constitute approval of this written design or product implementation.

**Baseline:** published `origin/main`,
`e668600fbdab7c1ab6cfccce797264247e925af0`.

## Intent and confirmed choices

The arcade should make the learning decision the game action. Learners should not
be able to earn most of a round's rewards through an unrelated visual puzzle.
The audience is English-speaking adults beginning French. Web, iOS and Android
have equal priority. The existing space-exploration identity is confirmed correct;
extend it rather than selecting a new visual world.

The user chose three complementary games and wants at least one silent game.
Their proposed silent interaction is falling words sorted left/right according
to the phoneme they contain. Preserve that interaction in **Word Fall**.

The names, twelve-turn session length, initial `/u/`–`/y/` focus, exact interaction
details and persistence design below are controller proposals for approval, not
choices the user has already made. Proposed names preserve the recognizable
Sound Match and Word Match entries and add Word Fall.

## Approaches considered and selected

| Approach | Advantage | Tradeoff | Decision |
| --- | --- | --- | --- |
| Two games: listening plus silent falling-word classification | Smaller scope with distinct audible/silent jobs | No dedicated audio-to-spelling game | Offered; user selected the three-game set instead |
| Three games: auditory discrimination, sound-to-spelling, silent word classification | Three explicit practice goals, including the requested silent interaction | More content, persistence and interaction verification | Selected by the user |
| Cosmetic repair of existing swap/chain games | Reuses most engines | Keeps listening peripheral and allows puzzle skill to dominate | Does not meet the user's learning-first instruction |

## Goals, non-goals and failure conditions

Goals:

- Every scored action must be a deliberate response to the current learning task.
- Keep hearing a distinction, spelling a heard sound and classifying a written
  word separate in instruction, attempts and feedback.
- Provide immediate teaching after an acknowledged answer, a useful finite recap
  and an optional revisit of mistakes. Make assistance and repeated practice honest.
- Preserve clear space identity, stable controls, readable French/IPA and native
  interaction/accessibility expectations.
- Preserve saved data, owner isolation, exact-command retries, audio cancellation
  and all content/recording qualification boundaries.

Non-goals: a new French curriculum, new recordings, linguistic sign-off, speaking
or microphone assessment, new currencies/lives, leaderboard, cloud sync changes,
telemetry, forced lesson unlocks or a claim of measured learning improvement.

It is a failure if a player can advance by matching colors without a language
judgement; if text/semantics leak an audio answer; if timeouts count as wrong sound
answers; if a new score becomes lesson mastery; or if the new games erase earlier
boards, histories or scores.

## Shared mission structure

Each game starts with a short explanation and one guided example outside the
scored mission. The example clearly reveals and explains the target distinction.
Its items become assistance/exposure context for later encounters. Repeat visits
may skip the tutorial; skip does not erase previous exposure.

The proposed first delivery is a twelve-turn `/u/`–`/y/` mission in each game.
There is no sixty-second expiry and no speed bonus. A small mission trail is a
view of acknowledged turns, never invented mastery. Use shape/labels as well as
color for answered/correct/revisit states. Correct language judgements reconnect
the corresponding signal or route a word to its destination. Decorative actions,
replays, help and automatic animation earn no learning answers or game points.
There is no separate puzzle-point total in the first delivery: show acknowledged
turns, first-answer correctness and assisted revisit outcomes as distinct facts.

Keep first answers immutable for the run. At recap show `First answers: X/12`,
the specific practiced skill, and the missed items. Offer **Practice missed**,
**Play again** and **Finish**. Revisit answers are explicitly feedback-assisted;
they can resolve the current revisit queue but cannot rewrite the first result.
No threshold, game completion or animation completes a course lesson.

**Controller call: finite revisit passes.** Practice missed presents each currently
unresolved item once per pass, in its frozen original mission order. A correct
assisted response removes it from the unresolved set; an incorrect response stays
unresolved but is not reinserted into the same pass. At the next recap the learner
may start another pass or finish. No forced repeat-until-correct loop. Persist the
pass queue/cursor and unresolved set so interruption cannot lose a mistake. The
original first-answer outcome never changes, including after assisted success.

Explicit **Next** follows saved feedback. Do not auto-advance while someone is
reading or listening to a correction. A mission can be paused or left at any turn;
resume restores the exact run/turn/feedback without replaying or re-answering it.
Leaving early keeps the run resumable; it does not mark the twelve-turn mission
complete. Partial summaries say how many turns were actually answered. **Finish**
is a recap action; the pause surface uses **Leave for now** without completion.

## Game 1: Sound Match — compare the vowel

**Learning action:** hear two different French words and judge whether their
designated vowel sounds are the same or different. This practices discrimination
without requiring a spelling response.

The prompt is **Same vowel, or different vowels?** The two signals are labeled
**A** and **B**. The words, their IPA, the specific expected vowels and the
correct relation remain hidden before the answer, including semantics/tooltips.
The neutral contrast inventory `/u/`–`/y/` is allowed as context; it does not identify
which vowel is in either hidden word.

The learner explicitly plays both signals through one **Listen to both** control.
Playback is sequential, A then B, with a short fixed gap and clear playing/complete
states. Enable **Same vowel** and **Different vowels** only after both current
recordings successfully complete. **Replay both** retires the old readiness grant
and repeats the entire pair. Individual A/B replay is outside the first delivery;
never combine grants from different pair requests into a ready answer.

After the answer is saved, reveal both words and their citation IPA and explain
the actual vowel relation. Example: `tout /tu/ and vous /vu/ share /u/. Different
words, same vowel.` A wrong relation receives the same concrete teaching without
losing a life or inventing a sound-production diagnosis.

Use distinct words on same-vowel pairs so whole-word equality is not the solution.
The initial twelve authored pairs are balanced: three `/u,u/`, three `/y,y/`,
three `/u,y/`, three `/y,u/`. Shuffle the frozen pair order per run without a
predictable alternating answer pattern.

| Pair | A | B | Authored targets | Relation |
| --- | --- | --- | --- | --- |
| uy-listen-01 | tout | vous | u, u | same |
| uy-listen-02 | rouge | loup | u, u | same |
| uy-listen-03 | soupe | doux | u, u | same |
| uy-listen-04 | tu | lune | y, y | same |
| uy-listen-05 | rue | mur | y, y | same |
| uy-listen-06 | jus | plume | y, y | same |
| uy-listen-07 | tout | tu | u, y | different |
| uy-listen-08 | rouge | rue | u, y | different |
| uy-listen-09 | vous | lune | u, y | different |
| uy-listen-10 | jus | soupe | y, u | different |
| uy-listen-11 | mur | doux | y, u | different |
| uy-listen-12 | plume | loup | y, u | different |

These are proposed authored practice bindings to existing words, not acoustic
validation of pending recordings. This twelve-pair set is small and shares source
recordings; it does not establish generalization to unfamiliar words or speakers.

## Game 2: Word Match — choose the spelling you heard

**Learning action:** hear a word, then choose how its designated vowel is written.
This is sound-to-spelling practice, separate from both auditory comparison and
silent written-word classification.

The prompt is **How is the vowel written?** The two stable options are **u** and
**ou**. The word pod shows a neutral audio symbol before answering. Do not show
the word, partial spelling, target phoneme, highlighted letters, meaning, correct
lane, IPA or expected key before the acknowledged answer. These restrictions
apply equally to semantics, tooltips and decorative animations.

Successful current playback unlocks a single deliberate spelling choice. After
save acknowledgement, reveal the word with its exact target grapheme highlighted,
IPA and a word-specific explanation. Example: `lune /lyn/: u writes /y/ in this
word.` Route the pod and light its mission node only from committed state.

There are twelve unique words in the first pass, six per target. Explicitly bind
the correct spelling and range; never derive correctness from a substring rule.
Freeze a shuffled word order per run; the grouped table below is not presentation
order. Do not use predictable target blocks or a fixed alternating answer pattern.

| Word | Target | Correct option | Grapheme range [start,end) |
| --- | --- | --- | --- |
| tout | u | ou | [1,3) |
| rouge | u | ou | [1,3) |
| vous | u | ou | [1,3) |
| doux | u | ou | [1,3) |
| loup | u | ou | [1,3) |
| soupe | u | ou | [1,3) |
| tu | y | u | [1,2) |
| rue | y | u | [1,2) |
| lune | y | u | [1,2) |
| jus | y | u | [1,2) |
| mur | y | u | [1,2) |
| plume | y | u | [2,3) |

All words reference their existing `fr-word-<word>` recordings. Reuse the current
ten-item spelling catalogue's data and semantics where identical; the additional
two game bindings do not change that lesson's identity, content revision or
completion. The new game owns a separate run and cannot write lesson answers.

## Game 3: Word Fall — silent falling-word classification

**Learning action:** read a French word and classify its authored vowel `/u/` or
`/y/`. This strengthens word/pronunciation/spelling knowledge; it is not listening
evidence and makes no spoken-production claim.

A single word pod falls through a quiet asteroid field. **Swipe left for /u/**,
**right for /y/**. Keep these lanes fixed, labeled and visible throughout. Provide
equivalent large tap buttons, keyboard Left/Right and screen-reader actions.
Vertical scroll must not become an answer; incomplete/cancelled drags submit
nothing. One gesture may create at most one answer command.

Proposed motion settings are **Steady**, **Relaxed** and **Still**. In moving modes
the pod stops at a safe decision shelf if unanswered. Reaching the shelf is not
a wrong answer, omission penalty, lost item or forced advance. No speed bonus;
correctness depends only on classification. Still mode and reduced motion use a
static word card with identical content, choices, rewards and learning records.

After the response is acknowledged, freeze the word, show its IPA, highlight its
target spelling and explain the correct family. Then offer **Next word**. A wrong
answer joins the revisit queue. The initial twelve unique words and targets are
the table above; the word is visible here by design. No audio provider is created,
no voice/audio request is made, and no audio setting blocks a silent mission.
Freeze a shuffled word order per run here too, independently of the other games;
never present the table's six `/u/` words followed by its six `/y/` words as blocks.

Avoid multiple simultaneous answerable words: they split attention, encourage
uncredited accidental responses and make accessible equivalent play harder.
Falling is the pacing/interaction layer around one genuine language decision.

## Content, evidence and learning limits

- Validate all catalogue identities, declared target membership, exact grapheme
  ranges, expected responses, unique item IDs and twelve-turn balance before use.
  A catalogue mismatch offers unavailable/retry, never silently repaired content.
- Bind references to existing word/audio definitions, preserve pending review
  state, and retain source/rights/disclosure policy. No new assets or TTS fallback
  for covered recording failure are authorized.
- Game 1 records one pair-level judgement, not two independent correct word
  identifications. Game 2 records a sound–spelling judgement. Game 3 records a
  silent written-word classification. Preserve game origin, content revision,
  first-in-run/repeat context and all assistance/exposure flags.
- Tutorials/help and feedback are assistance, not independent correct answers.
  Practice-missed responses are explicitly assisted repeats. A new run is not
  falsely described as globally unseen material.
- Do not pool the three skills into one mastery percentage. Do not count passive
  animation, replay, mere selection, failed playback, unsaved responses, cancelled
  gestures or reaching the shelf as a correct/incorrect learning judgement.
- The small `/u/`–`/y/` word set permits memorization and spelling shortcuts in
  Word Fall. That is compatible with its stated silent reinforcement goal; it
  does not prove hearing or transfer. Add future contrasts only through authored,
  validated content, not arbitrary word generation.

### Exposure and assistance across the three games

**Controller call: shared word provenance within the new arcade profile.** Keep
turn/item occurrence identity separate from word familiarity. A pair judgement
is first-in-run only for that pair/task; this does not say its component words
are new to the learner. A word judgement is first-in-run for that game's item.

Within the same owner/course arcade profile, record word-level exposure for the
authored word/target/content binding across turns, runs and games. Distinguish
visible orthography, completed audio exposure and disclosed pronunciation/grapheme
teaching. Seeing a Word Fall word does not itself reveal its expected family;
its saved feedback does. Successful required playback on the current turn is a
prerequisite, not automatically a revealed-answer assistance flag.

Build an answer's prior-context provenance from the state before that response:
earlier tutorial/help/feedback about its word/target remains assistance even when
the next encounter is in another game or run. For a pair, retain the provenance
of each component word and an aggregate assistance flag; do not convert that
provenance into two independently scored identifications. New feedback updates
future exposure only after its acknowledged reveal. Repeated viewing/replay may
record exposure but never creates another learning judgement or correctness score.

Earlier lesson/comparison/spelling/legacy-game histories remain in their existing
families; do not backfill invented new-game assistance from unrelated aggregates.
Consequently labels must say **first answer in this run**, **revisit after feedback**
and the actual skill, never **globally unseen**, **unassisted mastery** or **never
practiced before**. Preserve the underlying earlier records. The implementation
plan may choose normalized provenance columns/codecs, but must retain these
distinctions and owner isolation rather than treating every new activity as a
blank learner history.

Learning validation is a separate proposed activity: compare audio-only pre/post
and delayed performance using held-out words and qualified unfamiliar speakers,
and evaluate enjoyment separately. This design does not authorize collecting
learner data, shipping new recordings or claiming efficacy.

## UI, space identity and platform behavior

Extend the approved course theme: midnight-blue ground, quiet panel surfaces,
purple actions and familiar course typography. Preserve light appearance and
semantic success/error colors. Use existing licensed course art for restrained
asteroid/ship framing; no moving background competes with the word or controls.

The games are **Operate** surfaces: completing the language action governs layout.
Use a stable header with title, pause and help; current skill/turn count; one
large learning stimulus; fixed answer controls near the lower reach area; and a
reserved feedback region. Do not insert rows that displace active controls.

The three stimulus areas differ visibly: two signal beacons for Sound Match, a
hidden-word pod plus spelling lanes for Word Match, a readable falling pod plus
sound lanes for Word Fall. Correct judgements cause a brief meaningful connection
or routing animation; reduced motion resolves to the same static acknowledged
state. No game point or decorative progress is awarded before persistence.

Phone acceptance covers at least 360×640 and 390×844 plus safe areas. Desktop and
tablet use a comfortably bounded play area instead of stretching a word/choice
to the full viewport. Verify 200% Flutter text scaling through Flutter, not CSS
root font-size. Preserve scroll and avoid clipped feedback/controls. Native
acceptance requires actual simulator/emulator/device captures and platform Back,
safe-area, interruption and assistive-technology checks. Browser captures do not
qualify native behavior. Touch targets: at least 44pt iOS and 48dp Android.

All controls have clear focus, role and state. Selected/pending/saved/revisit
states and first/repeat results must be nonvisual as well as visual. Focus moves
to saved feedback after ACK, then to the next prompt only on explicit Next;
never announce an answer before it is durably revealed. Replays/help cannot steal
newer prompt ownership. Screen-reader silent mode defaults to Still unless the
user explicitly chooses motion; no performance penalty applies.

## Audio, saving and interruption state machine

Shared phases: tutorial, prompt, playing (audio games), ready, save-pending,
saved-feedback, recap, revisit and finished. Pause is an overlay/state retaining
the acknowledged phase, not an invented answer or extra run.

Audio readiness is transient and bound to owner/auth generation, course, game,
content revision/fingerprint, run, turn, prompt epoch, word/reference and request.
Game 1 also binds both ordered references. Failure/cancellation, replay, route
coverage, backgrounding, Stop, disposal or owner change retires it. No late
completion may unlock a newer prompt or clear a newer busy operation. Resume of
an unanswered audio prompt requires fresh valid playback; saved feedback does not.

Freeze one typed response command/token before save. Disable duplicate input
while pending and keep feedback neutral. The same successful transaction writes
the answer, first/repeat context, progress, feedback checkpoint, recap/revisit
state and receipt. Retry save resends the identical command. A lost ACK is
reconciled through strict current-owner state/receipt loading, not a second answer.
Invalid/conflicting state offers reload; I/O failure does not reset progress.

On background/route coverage, pause falling and cancel playback immediately.
An in-flight write may settle, but cannot resume play or start audio/motion in the
background. Foreground return shows paused state and explicit Resume. Restore
starts paused; it never synthesizes a playback grant, answer or extra turn.
Leaving while a write is unresolved offers safe retry/reconciliation; it does
not discard an in-memory pending command while pretending the response was saved.

## Persistence, routes and earlier progress

Proposed new activity IDs are `arcade:listen-uy`, `arcade:spell-uy` and
`arcade:sort-uy`, with content revision 1 and independently fingerprinted bindings.
Never reinterpret old `arcade:sound` / `arcade:word` checkpoint bytes as the new
games. Keep all earlier histories, scores and boards unchanged. The earlier
unpublished Sound Match work and repair diagnostics remain untouched.

Use a typed **arcade** profile family in the existing shared learning database,
with `LearningStorageScope` owner/course identity and the existing SQL command
coordinator's transaction, write fencing and receipt protocol. This requires an
additive physical v2→v3 migration (plus supported older→current upgrade paths),
strict schema/oracle updates and family-specific adapters; no second database,
preferences store or new sync outbox. The implementation plan must enumerate
every changed constraint/trigger and prove unchanged existing rows/families on
migration, rollback, reopen and cross-connection writes.

Store typed pair judgements, heard-word spelling choices and silent word
classifications distinctly. Persist first answers and later attempts separately,
frozen turn order, catalogue binding, assistance/exposure provenance, current
phase/feedback, revisit queue and exact acknowledged progress. Store no raw audio
or microphone content. Do not upload new arcade data through a legacy sync shape.
The new games have local durable progress; cloud sync expansion is out of scope.

Preserve existing course lesson/comparison/spelling/sentence identities and their
completion policies. Do not write new-game events through a legacy answer codec
or silently merge them into existing review/mastery summaries. The arcade recap
and Progress view may show the three new skills separately as game practice.
Old puzzle scores remain historical and labeled as previous puzzle scores; no
automatic score migration or new-game credit occurs. Old boards remain on disk;
replaying the old puzzle engines is outside this redesign's main three entries.

The `/arcade` lobby presents three clearly labeled jobs and audio requirements.
Keep `/arcade/sound` and `/arcade/word` as entry routes to the redesigned games and
add `/arcade/fall` for Word Fall. When old progress exists, explain once that the
games were redesigned and prior puzzle progress is preserved separately. Never
silently resume a new activity from an old board. The map's optional Asteroid
arcade destination remains optional and never changes the learner's main lesson.

## Verification and delivery boundaries

Test first against the real typed transitions, repository and rendered flows:

1. Balanced authored content and correct hidden-answer behavior, including text,
   tooltip and semantics; no whole-word equality shortcut in same-vowel pairs.
2. Both ordered recordings required for Game 1; stale/failing/replayed/superseded
   audio cannot answer. Game 3 never initializes audio.
3. One deliberate response creates one answer; first outcomes stay immutable;
   revisits are assisted; passive motion, timeout and cancelled swipe create none.
4. Whole response rollback, identical retry/lost-ACK reconciliation, owner changes,
   multiple connections, interruption during write and restoration at every phase.
5. Silent swipe/button/keyboard equivalence, vertical scroll, Still/reduced motion,
   pause-at-shelf and no timer penalty. No board movement from asynchronous rows.
6. Existing data preserved through all supported migrations; lessons, earlier
   games, progress and content gates unaffected. Three new skills remain separate.
7. Web viewport/theme/large-text and native platform/accessibility evidence, with
   actual limitations recorded rather than counting unrun checks as passes.

Deliver implementation in sequential scoped branches/PRs from published main,
independent review, controller exact-head/base verification and normal guarded
GitHub merge. Missing CI is not a passing result. Preserve all worktrees/evidence.
This design PR is documentation only. After the user approves it, write and review
the implementation plan; no production game code is authorized by the mockup alone.

## Preview and open decisions

The requested browser companion is a throwaway code-based interaction sketch,
not product code. It uses labeled sample turns, simulated playback and no saved
results. The preview's repetitive sample sequence and simplified state are not
the production catalogue, persistence model or complete accessibility behavior.

Captured previews: [three games on desktop](assets/2026-10-31-learning-first-arcade/preview-desktop.png)
and [Word Fall on a phone-width page](assets/2026-10-31-learning-first-arcade/preview-phone.png).
These are browser mockups, not native captures. Ship/asteroid artwork reuses the
existing course assets and their [recorded sources/CC0 credits](../../../frontend/assets/images/course_map/README.md).

The independent builder check identified cross-game exposure and repeated missed
items as planning gaps. The shared-provenance and finite-revisit rules above
resolve them as explicit controller proposals. There are no remaining questions
that require inventing a different product scope to write the implementation plan.

User review is requested on the three learning loops, proposed twelve-turn format
and Word Fall's adjustable fall-then-wait pacing. These are concrete choices to
approve or correct, not a request to choose the space theme again.
