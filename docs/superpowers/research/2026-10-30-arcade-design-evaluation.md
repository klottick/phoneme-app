Method: dual-agent (A: `/root/arcade_design_a` · B: `/root/arcade_design_b`)

# Arcade look, feel and learning fit — 2026-10-30

Target: `frontend/lib/src/features/arcade/arcade_screen.dart`, both games and their
lobby. Published source `7055ec524e3d014dac5e1d50735c7d5c13fd8d3d`; hosted runtime
`818c335765198f0da798e541498d3c1908cf5adf`. This evaluates current behavior before
broader fixes. It is a design judgment supported by source and browser evidence,
not a learner efficacy study or native-device acceptance test.

The user confirms that space exploration is the correct overarching theme, web
and native apps have equal priority, and the primary audience is English-speaking
adult French beginners using games as optional lesson reinforcement. The problem
is carrying that identity and purpose through the games, not choosing a new theme.

## Design specificity and overall impression

These are recognizable French-sound puzzles, but the active screens could belong
to an unrelated casual-game app. The dark lobby uses the approved midnight-blue
and purple course styling. Both game routes switch to legacy black/gray surfaces
and green controls: the router wraps `/arcade` in `SpaceCourseTheme`, but not
`/arcade/sound` or `/arcade/word`.

The strongest direction is a coherent **Asteroid arcade** detour with restrained
space framing and quiet, legible boards. Keep the existing four sound-family
colors, distinct shapes and IPA. A purple wash or moving starfield behind words
would weaken the puzzle rather than fix the theme discontinuity.

## Design health

Scores are qualitative, not measured learner usability outcomes. All ten
heuristics apply; 4 means excellent.

| # | Heuristic | Score / 4 | Main observation |
| --- | --- | --- | --- |
| 1 | System status | 3 | Time, score and selection visible; listening cue changes layout. |
| 2 | Match with the real world | 2 | Clear swap/link verbs; bare IPA requires prior sound knowledge. |
| 3 | Control and freedom | 3 | Pause, finish, clear, replay and silent alternative; no in-round help. |
| 4 | Consistency | 2 | Familiar boards, but course-to-game theme discontinuity. |
| 5 | Error prevention | 3 | Neighbor rules and disabled short-chain Link; first move not taught in context. |
| 6 | Recognition over recall | 2 | Target visible; sound examples and special rules disappear after intro. |
| 7 | Flexibility | 2 | Drag/tap alternatives; keyboard-only primary play not verified. |
| 8 | Aesthetic restraint | 2 | Focused boards, generic chrome, dense intros. |
| 9 | Error recovery | 3 | Specific wrong-word feedback; retry paths exist but shared resume defects reproduced. |
| 10 | Help | 2 | Basic preview/rules before play, little contextual help. |
| **Total** | | **24 / 40** | **Acceptable; significant improvements needed.** |

## What works

- The board is the focus, with no root navigation competing during a round.
  Word tiles measured 79–86.5 browser CSS pixels and sound tiles about 51–56 at
  the inspected phone widths; ordinary boards and controls fit.
- Color, shape and IPA redundantly distinguish sound families. Word spelling
  hints support initial recognition. Valid Word chains and Sound swaps scored
  in isolated browser checks, and Word dragging also scored.
- No lives or daily limits, a silent alternative, pause/continue freedom and
  specific non-shaming feedback support optional practice. Puzzle points and
  learning records are deliberately separated.

## Priority issues

1. **P1 — Teach the learning action in context.** A dense introductory rules
   paragraph gives way to a bare IPA target. Use one playable example before
   timing begins, reveal advanced rules when relevant and make help reachable.
   A Word Match target example can support practice. Sound Match must not reveal
   a pending cue's expected answer before the learner responds; keep any legend
   neutral, and preserve assistance flags when help is shown. Suggested work:
   `impeccable onboard` and `impeccable clarify`.
2. **P1 — Keep Sound Match tiles stationary when a cue arrives.** At roughly
   twelve active seconds a replay row appears above the grid, moving it about
   40 pixels beneath the player's hand. Reserve a stable cue region and clearly
   separate listening, ready-to-answer and answered states. Keep the cue prompt
   beside its controls. Changes to timing/answer rules are a separate learning
   design decision. Suggested work: `impeccable harden` and `impeccable layout`.
3. **P1 — Describe special tiles accessibly.** Word tiles expose the word,
   meaning and selected chain number, but obstacle status and stars have no
   reliable descriptive semantics. A nonvisual player cannot reliably locate
   those mechanics. Add explicit state labels and verify keyboard/screen-reader
   play; do not infer acceptance from the semantics tree alone. Suggested work:
   `impeccable harden`.
4. **P2 — Carry the confirmed space theme into both game routes.** Extend the
   existing background, panel and action roles through game chrome and use
   restrained asteroid/orbit framing at entry. Preserve family colors, obstacle
   cues, light mode and quiet boards. This is continuity work, not a theme
   replacement. Suggested work: `impeccable colorize`, then `impeccable polish`.
5. **P2 — Make the round's learning purpose visible at the end.** Invitation,
   bonuses and summaries emphasize points and combos. Keep puzzle rewards, but
   add a brief account of the valid listening/spelling practice completed.
   Do not label a tile count or game score as mastery. Suggested work:
   `impeccable clarify` and `impeccable shape`.

## Actual learning ability

| Game | Plausible practice | Current limit |
| --- | --- | --- |
| Sound Match | Heard-word vowel identification when an eligible deliberate match answers a successfully played cue. | Most swaps and rewards are visual; sparse optional listening and a small fixed word/recording set do not demonstrate transfer. |
| Word Match | Repeated `/u/`–`/y/` sound–spelling classification. | Silent `ou` versus `u` selection can be solved through spelling or memorization; it does not test hearing or spoken production. |

Neither game has demonstrated improved pronunciation or generalization to new
words/speakers. Keep them as optional reinforcement, not replacement lessons.
The separate learning evaluation details the code evidence and a proposed
pre/post, delayed and held-out-word/speaker validation approach. No new telemetry,
content qualification or assessment policy is authorized by this recommendation.

## Cognitive load and emotional journey

Word intros fail the chunking, working-memory and progressive-disclosure checklist
items: moderate load. Sound additionally adds a listening decision to timed
visual search: high load by this checklist in that interaction. **Sixteen or
thirty-six puzzle tiles are intrinsic spatial search, not sixteen/thirty-six
navigation choices.** Two game entries and four repeating sound families are
reasonable. Do not shrink the puzzle merely to satisfy a four-choice heuristic.

The current journey starts with a welcoming absence of lives/limits, drops into
dense rules, recovers during focused board play, adds surprise complexity at the
Sound bonus, then ends in a generic points-led summary. Specific wrong-word
feedback and freedom to pause are strengths. A short guided opening and useful
skill-specific ending would improve confidence without adding a new economy.

## Persona risks and smaller observations

- A first-time learner must remember IPA examples and power-up rules from the
  intro. Teach one action and keep help accessible.
- A distracted phone player encounters a moving Sound board and a top-right
  Pause control; interruptions need fresh save/resume and device testing.
- An assistive-technology user gets useful sound labels and Word chain numbers,
  but special-tile descriptions and complete keyboard/screen-reader operation
  remain gaps.

Several button/Pause semantics rectangles were only 40 pixels high in the
browser. Board targets are larger. Verify platform targets against iOS 44-point
and Android 48-dp expectations rather than calling this a blanket WCAG failure
or claiming native compliance from browser measurements. Meanings in tooltips
can overlay word tiles after pointer interaction; verify touch feel. Combo,
clear and refill transitions currently update immediately rather than showing
purposeful game motion; any later motion must preserve stable hit testing,
committed state and reduced-motion behavior.

## Deterministic evidence and interpretation

The real CLI detector returned exit 0 with `[]` for the Dart target. Its web-markup
rules cannot establish that a Flutter canvas screen is clean. Browser overlay
injection executed in the lobby and both games; it reported one
`undersized-ui-text` finding per view, targeting the invisible generated semantics
heading at 10px. All three are false positives for the visible canvas headings,
which screenshots and source show at normal title size.

The four explicit opaque Sound tile colors with white text/icons calculated
between **5.06:1 and 5.79:1** contrast. This verifies those pairs only, not all UI
contrast. Sound selection exports `aria-current=true`; do not claim Sound selection
is missing. Word selection adds its chain number but lacks an explicit selected
property. A root-font-size injection did not exercise Flutter text scaling; no
200% text-scaling pass is claimed. Native accessibility and audio remain untested.

## Questions that determine the next scope

- Should the next pass preserve the present game mechanics while fixing identity,
  stable cues, teaching/help and accessibility, or also redesign how frequently
  listening decisions drive play?
- Should Sound Match remain primarily a relaxing visual puzzle with occasional
  listening bonuses, or become focused listening practice expressed through a
  puzzle? The answer changes learning frequency, pacing and validation needs.

## Captures

All captures are actual isolated browser renders of the baseline runtime, not
proposed redesigns or proof of native behavior. The original map work deliberately
excluded game reskins; this evaluation identifies the next extension of the
confirmed identity rather than retroactively changing that delivery's scope.

- Dark lobby: `assets/2026-10-30-arcade-evaluation/dark-lobby-390.png`.
- Dark Word board: `assets/2026-10-30-arcade-evaluation/dark-Word-board-390.png`.
- Sound before/after cue: `assets/2026-10-30-arcade-evaluation/dark-Sound-board-360.png`
  and `dark-Sound-cue-360.png` in the same directory.
- Light Word board: `assets/2026-10-30-arcade-evaluation/light-Word-board-390.png`.
