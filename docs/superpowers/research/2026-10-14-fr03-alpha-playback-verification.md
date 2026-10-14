# FR-03 Task 4 — Alpha playback: automation evidence and remaining manual gates

**Date:** 2026-10-14
**Branch:** `feat/fr03-recording-first-alpha` (base `f6250d7`, published
`origin/main`)
**Worker HEAD:** `ee15875`
**PR:** https://github.com/klottick/phoneme-app/pull/29 — opened against
`main`; merge pending controller review
**Purpose:** record exactly what was verified by automation this task, what
was not, and where the remaining manual/browser/native/linguistic evidence
must come from. No gate in the PENDING section below has passing evidence.

## Environment facts (as observed, 2026-10-14)

- Worktree: `/home/klottick/.paseo/worktrees/34ubk100/french-section-plan`
  (Linux, headless).
- Flutter: **3.41.9** (channel `user-branch`; Framework revision 00b0c91f06,
  Engine 9161402dc0e134b, Dart **3.11.5**), CLI at
  `/home/klottick/develop/flutter/bin/flutter`; all commands run with
  `--no-pub` against the cached dependency set (riverpod 2.6.1).
- **No browser is available here.** `which google-chrome`, `which chromium`,
  `which chromium-browser` all returned nothing; `/usr/bin` contains no
  `chrom*`/`firefox` binaries. The gate owner must run the browser gate on a
  machine that has a real user agent.
- No iOS/Android device or emulator is attached to this environment.

The automated results below were produced with no browser, device, network,
locale, or audio hardware: widget/unit tests over deterministic gate-
controlled doubles at the plugin boundary (recording engine and flutter_tts
adapter) and a real file-based asset bundle reading the bundled WAV manifest,
provenance and licence bytes.

## Automated verification (real commands, 2026-10-14)

| Command | Workdir | Exit | Result |
| --- | --- | --- | --- |
| `flutter test --no-pub test/unit/course_audio_provider_test.dart test/widget/course_audio_lifecycle_test.dart test/widget/drill_audio_lifecycle_test.dart` (RED, pre-wiring) | `frontend` | 1 | `+6 -8` — real assertion failures (missing exact disclosure; voice-setup text presented on cancelled playback; Stop/end/leave never stopped in-flight audio), plus the provider file's deliberate compile gap on the not-yet-existing `courseReferenceAudioProvider`. Logs: `.superpowers/sdd/2026-10-14-fr03-alpha-reference-player/task-4-red-phase-a.log`, `task-4-red-phase-b.log`, `task-4-red.log` |
| same targeted suite (GREEN, post-wiring) | `frontend` | 0 | `+23 All tests passed!` (log: `task-4-green.log`) |
| `flutter test --no-pub` (full suite) | `frontend` | 0 | `+841 All tests passed!` (814 pre-Task-4 baseline + 27 new) |
| `flutter analyze --no-pub` | `frontend` | 0 | `No issues found!` |
| `python3 -m unittest discover -s scripts -p 'test_*.py'` | repo root | 0 | `Ran 52 tests … OK` |
| `python3 scripts/verify_french_audio.py --repo-root .` | repo root | 0 | `PASS: 24 pending French word candidates verified (technical/metadata only)` |

Scope check (same revision): `git status`/`git diff --stat` show only the
Task-4 owned files — 5 `lib` files, 3 new and 3 extended test files, 2 docs
files. No WAV bytes, no `manifest.json`/`provenance.json`, no `licenses/`,
no `pubspec.yaml`/lockfile, no root `LICENSE`, no `scripts/` change.

## What the automation proves

- `courseAudioProvider` and the new `courseReferenceAudioProvider` serve
  **one** shared `FrenchReferenceAudio` instance; existing
  `courseAudioProvider.overrideWithValue(...)` legacy mocks compile and run
  unchanged; provider disposal retires a held request distinctly as
  cancellation (Riverpod note: an `overrideWith` body does **not** inherit the
  overridden provider's `ref.onDispose` hooks — the test override registers
  the same disposal contract itself; see `course_audio_provider_test.dart`).
- Recording-first selection for all 24 covered words; practice speech only
  for uncovered legacy text (`roue`); a catalogue or recording failure never
  substitutes TTS and stays Retry-retryable.
- Cancellation is delivery-distinct from audio failure on every surface:
  lesson listen, discovery listen, drill Play/Stop/End Session/leave, arcade
  background suspend and the held-cue switch to Word Match — no heard mark,
  no choice unlock, no progress/evidence, no failure text.
- The exact label `Alpha audio: recordings are unverified; device speech is
  practice-only.` appears on the lesson, discovery (failure guidance),
  drill, and arcade surfaces; failure copy is Retry/unavailable, never
  "Install a French voice".
- Readiness stays 35 pending; WAV/provenance/licence bytes unchanged; no
  `sound_word_help_test` import was introduced; FR-15 untouched.

## Manual gates — PENDING (no evidence exists; not passed)

1. **Browser playback (controller-owned gate; no browser was launched —
   none exists in this sandbox; see environment facts).** On a machine with
   a real user agent: load the app and confirm (a) covered words (e.g.
   `tout`, `île`) play the bundled recording from the lesson, discovery,
   drill and arcade surfaces; (b) all four surfaces render the exact
   disclosure string; (c) Stop / End Session / navigation / background
   cancel in-flight playback with no late audio and no error noise;
   (d) a failed playback surfaces the Retry guidance (never "install a
   French voice"); (e) the unmapped `roue` play path uses audible device
   practice speech; (f) the credits view still loads with no engine
   side-effects.
2. **Native playback (iOS/Android real devices):** the 24 WAV binaries carry
   the four-byte RIFF-size header caveat recorded in
   `docs/french-reference-audio.md`; device/player compatibility is a
   separate, still-unmet gate.
3. **Linguistic review / readiness / FR-15:** the 24 binaries remain
   `review.status: "pending"` (worksheet blank), readiness stays 35 pending,
   and FR-15 validation stays deferred. Automated tests do not substitute
   for any of these.

A passing gate requires the corresponding real browser/device/reviewer
evidence recorded by its owner; nothing in the automated output above is
such evidence.
