# Arcade learning evaluation — 2026-10-30

Status: source/interaction evaluation before a broader arcade redesign. This is
not an efficacy study, learner trial, pronunciation assessment, or audio review.
Evaluated published source: `7055ec524e3d014dac5e1d50735c7d5c13fd8d3d`.
Hosted runtime: `818c335765198f0da798e541498d3c1908cf5adf`; the newer published
commit changes delivery documentation only.

## What each game actually asks the learner to do

| Game | Task with plausible learning value | What success does not establish |
| --- | --- | --- |
| Sound Match | After successful playback of a French word, deliberately make a single-family match corresponding to its vowel. Qualified answers create listening evidence. | Most gem swaps require visual matching only. Puzzle score, cascades and stars do not establish listening ability, sound production or transfer. |
| Word Match | Read French words and select neighboring words containing the displayed target `/u/` or `/y/`. Submitted chains of at least three distinct neighboring tiles create spelling evidence. | No audio is played. A player can use written `ou` versus `u` or memorize this small word set; success does not establish auditory discrimination or pronunciation. |

Both are plausible optional reinforcement activities after a lesson. The current
implementation is too narrow and unvalidated to claim that either teaches French
pronunciation independently.

## Strengths supported by implementation

- `french_course.dart` explicitly authors word sound membership. Correctness is
  not guessed from substring spelling matches.
- The learning transition distinguishes listening from spelling, and game origin
  from other practice. Automatic cascades and row clears do not become deliberate
  learning answers. Puzzle score does not complete the course.
- Initial spelling hints, preview explanations, previous revelations and repeated
  presentations are recorded as assistance/context. They are not silently treated
  as unassisted first attempts.
- Chains containing a word without the target sound provide a counterexample
  with that word's IPA; invalid chain geometry receives gesture guidance instead.
  Incorrect heard cues identify the target sound. Save failures do not create
  partial evidence batches, and failed audio does not create a wrong answer.
- Optional short rounds, continuation and silent play lower the cost of returning
  to practice. Actual retention or engagement improvement has not been measured.

## Main learning limitations

1. **The listening decision is peripheral to Sound Match.** A cue becomes eligible
   after roughly twelve active seconds, with only one cue pending at a time.
   Most play and much of the score are visual puzzle activity. The `Audio
   required` lobby label overstates the dependency: ordinary gem play is possible
   before any audio. Fixing the continuation bug alone will not change this.
2. **Word Match permits a spelling shortcut.** Its initial twelve-word pool uses
   `ou` for `/u/` and `u` for `/y/`. Underlines disappear after four successful
   moves, but the same words and visible spelling remain. This is reasonable for
   sound–spelling reinforcement; it is not an audio-only listening test. The target
   rotates every four successful moves rather than responding to demonstrated
   individual difficulty.
3. **Little evidence of transfer.** The game uses a small fixed catalogue. Word
   candidates have a shared source-named speaker, and their review is pending.
   There is no game-specific pre/post test, delayed retention test, unfamiliar-word
   test or unfamiliar-speaker test. Existing automated tests verify software, not
   that humans learn from it.
4. **Evidence counts are not independent trials.** A three-word chain can record
   three tile answers, including repeated words in the same context. Those are
   useful interaction records, but cannot be interpreted as three independent
   demonstrations of generalized phoneme knowledge.
5. **The round ends with puzzle information only.** Points and round number do
   not explain which sound distinctions were practiced or where the learner was
   uncertain. A brief skill-specific debrief would make the educational purpose
   clearer while preserving the arcade score as a game measure.
6. **Cue retirement currently truncates opportunities.** The UI clears a heard cue
   after every committed swap, even when a rejected swap or ambiguous match
   produces no listening answer. Preserve it until an unambiguous deliberate
   answer, or retire it unscored when the correct move is unavailable. This is a
   separately identified existing behavior, not repaired by a visual reskin.

There is no speaking/recording task in either arcade game. Calling the arcade
pronunciation training would require evidence beyond the present mechanics.

## Research context and limits of inference

A primary phonetic-training experiment found generalization to a new talker after
multi-talker identification practice, while its single-talker condition improved
on training without the same new-talker generalization. That study used Japanese
learners and English `/r/`–`/l/`; it supports testing transfer and stimulus variety,
not a claim that this French arcade is effective. See [Lively, Logan & Pisoni
(1993)](https://pmc.ncbi.nlm.nih.gov/articles/PMC3509365/).

Orthographic information can support word learning while pulling pronunciation
toward familiar first-language targets. A study of French speakers learning novel
English words found faster recognition/naming with spelling but less native-like
vowel targets. That is a different learner population and task; it does not show
that Word Match harms English speakers learning French. It does show why spelling
success should be kept separate from listening/production success. See [Welby,
Spinelli & Bürki (2022)](https://doi.org/10.1016/j.wocn.2022.101172).

## Recommended direction before a broad implementation

- Keep both games as optional reinforcement, with a clear label for the skill
  each practices. Do not award lesson mastery from game score.
- Align the initial sound focus with the learner's current `/u/`–`/y/` lesson;
  expand only with authored content. A fixed four-family visual board and a
  lesson-aligned listening objective can coexist, but the instructions must
  explain the relationship.
- Make the listening objective legible and fair: preserve unanswered cues,
  clearly separate listening success from puzzle points, and avoid forcing an
  answer when no legal matching move remains. Decide the desired balance between
  uninterrupted puzzle play and listening practice through playtesting.
- Teach Word Match through one short playable example, then fade explicit help.
  Retain an honest silent spelling mode. Adding audio would change its purpose
  and should be a deliberate product choice, not an unannounced dependency.
- Give a short post-round debrief separating puzzle performance from the actual
  listening/spelling answers; avoid treating correlated chain tiles as mastery.
- Validate learning with audio-only pre/post and delayed checks using held-out
  words and qualified unfamiliar speakers, alongside a time-matched comparison.
  Measure game enjoyment separately. These are proposed validation activities,
  not completed results or authorization for telemetry/data collection.

## Sources of implementation evidence

- `frontend/lib/src/features/arcade/arcade_screen.dart`: rendered instructions,
  cue interval/playback ownership, selected word chains, feedback and summaries.
- `frontend/lib/src/features/arcade/{sound_match_engine,word_match_engine}.dart`:
  legal moves, fixed families/pool, target rotation, scoring and automatic clears.
- `frontend/lib/src/core/course/course_learning_game_transition.dart`:
  deliberate answer qualification and skill-specific feedback/evidence.
- `frontend/lib/src/core/course/course_learning_transition.dart`: assistance,
  repeated presentations, game origin and separate listening/spelling attempts.
- `docs/french-reference-audio.md`: unverified recording-candidate scope. This
  evaluation does not change linguistic, rights, playback or assessment gates.
