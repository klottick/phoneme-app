# Linguist

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

Web and native iOS/Android apps are equally important, as confirmed by the user
on 2026-10-30. Flutter is the existing shared implementation. Equal priority is a
product requirement, not a claim that native conventions, device behavior or
accessibility have already been validated on every platform. Adapt interaction
and accessibility to each platform while preserving one recognizable identity.

## Users

The primary audience is English-speaking adults beginning French. They use short,
optional games to reinforce sounds introduced in lessons. This audience and the
reinforcement role were confirmed by the user on 2026-10-30.

## Product Purpose

Help learners notice and practice unfamiliar speech sounds, connect them to French
words and spelling, and return to focused practice. Make the next real lesson and
saved continuation easy to find. The authored demo is English → French; it is not
a complete general vocabulary or grammar course.

Success means learners can understand the current sound objective, take a useful
practice turn, see honest feedback and resume their work. Puzzle score is not a
measure of pronunciation, sound mastery or lesson completion.

## Positioning

A directional language course organized around phonemes, listening and
pronunciation practice, with an explorable course journey and optional arcade
reinforcement. Explicitly authored sound membership and separate listening and
spelling evidence distinguish the learning tasks from general word matching.
This describes the implemented approach, not a comparative efficacy claim.

## Operating Context

Learners enter through a space course map, choose a real lesson or optional
practice destination, review mistakes and continue saved sessions. Games offer
short rounds, continuation, pause/resume and a silent Word Match option. An account
is not required for the demo. The existing browser demo is useful for inspection;
real iOS/Android touch, audio, interruption and assistive-technology behavior still
need device verification.

## Capabilities and Constraints

- Preserve existing lesson, activity, sound, audio and saved-progress identities.
  Local records are scoped to the course and learner account/guest.
- Keep listening, spelling, puzzle scores and lesson completion distinct. Assisted
  answers and repeated presentations are not independent unassisted mastery.
- Word Match currently practices sound–spelling association without audio. Sound
  Match combines visual gem matching with optional heard-word vowel challenges.
  Neither game has demonstrated learning gains through a learner efficacy study.
- Planned destinations must remain honestly labeled; a map illustration does
  not make a lesson available. Optional games do not unlock unqualified content.
- No fuel, lives, artificial daily limits, currency or movement-based learning
  credit. Preserve optional play and the freedom to stop or continue.
- Recording candidates and assessment features retain their existing review,
  rights, playback and release gates. Product presentation does not waive them.
  See [French audio policy](docs/french-reference-audio.md).
- Favor legible, stable controls, clear current objectives and specific recoverable
  feedback. Test both web and native behavior rather than extrapolating from one.

## Confirmed Arcade Redesign Direction

On 2026-10-31 the user authorized complete game redesign, specified that **all
games must be learning first**, and selected a three-game set. At least one game
must work silently. The user's proposed silent interaction is falling words
swiped left or right according to the phoneme they contain.

The selected scope separates listening discrimination, sound-to-spelling and
silent written-word classification. The detailed
[three-game design](docs/superpowers/specs/2026-10-31-learning-first-arcade-design.md)
is a proposal awaiting review; it is not implemented capability. The older game
descriptions above record current behavior rather than requirements to preserve
their mechanics. Preserve their saved data and the confirmed space identity.

## Brand Commitments

**Space exploration is the correct, user-confirmed product theme.** The user
explicitly reaffirmed it on 2026-10-30. Future Impeccable work must strengthen and
carry this identity through the map, lessons and arcade; it must not replace it
with a different visual world or a generic education/game interface.

The product is Linguist. The map presents a sound-learning journey through systems,
planets, stations and optional asteroid-arcade detours. Atmospheric navigation and
quiet, focused exercise/play surfaces belong to the same world. Space theming
must support reading and interaction; it does not justify visual clutter, moving
backgrounds behind a puzzle, new currencies or fictional mastery.

The existing approved visual authority is the
[map-first space course design](docs/superpowers/specs/2026-10-23-map-first-space-course-design.md),
its committed visual references and the implemented course theme. The
[phone-first delivery record](docs/superpowers/status/2026-10-29-phone-first-ui-refresh.md)
provides current presentation evidence. Preserve semantic sound-family colors,
shapes and IPA, readable text, light/dark preference and reduced motion when
extending the identity. A missing DESIGN.md is not permission to invent a new theme.

## Evidence on Hand

- Authored French word/sound catalogue and curriculum in
  `frontend/lib/src/core/course/`.
- Actual course map, practice screens, games and persistent learning records.
- Existing approved space design, selected screenshots and implementation records
  in `docs/superpowers/`.
- Automated engine, storage, navigation and widget tests. These verify software
  behavior; they are not evidence of human learning gains.
- The [arcade learning evaluation](docs/superpowers/research/2026-10-30-arcade-learning-evaluation.md)
  separates plausible reinforcement from unproven transfer and pronunciation.

## Product Principles

1. Reinforce a clear sound-learning objective; keep the distinction between
   practice, assistance, assessment and puzzle reward honest.
2. Preserve the confirmed space identity throughout the journey while keeping
   words, sounds and controls easy to perceive.
3. Teach a first action in context, reveal advanced rules when relevant and give
   concrete feedback without shaming errors.
4. Let people return, pause, recover and continue without losing their work.
5. Treat web and native platforms as equal product surfaces, with appropriate
   interaction and accessibility verification for each.

## Accessibility & Inclusion

Existing course requirements include reduced-motion behavior, keyboard/semantic
access and an accessible non-spatial alternative to map navigation. Preserve
redundant sound-family labels/shapes in addition to color. Provide alternatives
to drag-only controls, describe gameplay states and special tiles accessibly, and
verify large text, focus, screen readers and touch targets on each target platform.
Do not claim completed accessibility certification from source or browser
semantics inspection alone.
