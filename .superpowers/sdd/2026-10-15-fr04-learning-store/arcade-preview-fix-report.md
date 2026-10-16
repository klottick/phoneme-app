# Arcade fresh-preview assistance fix report

## Scope and implementation

- `frontend/lib/src/features/arcade/arcade_screen.dart`: successful durable
  writes now release `_saveBusy` before invoking their continuation. Continuation
  exceptions are reported as Flutter errors rather than handled as if the
  already-committed write failed. The initial checkpoint continuation persists
  the displayed Sound/Word preview assistance and activates only from that
  observation's success callback. Its failed save therefore keeps the existing
  immutable pending command/store/callback available to Retry.
- `frontend/test/widget/arcade_preview_assistance_test.dart`: adds four widget
  cases for both fresh game kinds, exact shown contexts/assistance and zero
  presentations, held observation preventing play/timer, identical Retry, and
  A→B→A owner replacement while the observation is held.
- `frontend/test/widget/arcade_switch_test.dart`: accounts for the extra
  durable preview-observation command after an explicit changed-content Start.

No fake seam was needed. No model, transition, audio, content, scoring, or
dependency changes. The existing game-transition test continues to verify that
preview explanation assistance is consumed by later applicable game attempts.

## TDD evidence

Base: `b99ac9373101adf340d0b4576489454990977698` on
`feat/fr04-task6-caller-cutover`.

RED command, from `frontend/` (test-only changes, before runtime edits):

```sh
PATH="/home/klottick/develop/flutter/bin:$PATH" \
  flutter test --no-pub test/widget/arcade_preview_assistance_test.dart --reporter expanded
```

Result: **exit 1, 4 failed**. Both fresh Sound and Word cases failed because
no `ObserveAssistance` was submitted; the Retry case found no observation command
to retain/retry; the owner case likewise found no held observation command.
These are behavioral failures, not compile/import failures.

The controller's private diagnostic was independently reproduced on base as
**1 failed** (its pre-existing `controller-arcade-preview-probe.log` records
actual commands `StartLearningRun, CheckpointArcade` and missing explanation
assistance). After the implementation, it passed unchanged:

```sh
PATH="/home/klottick/develop/flutter/bin:$PATH" \
  flutter test --no-pub \
  /home/klottick/.paseo/worktrees/34ubk100/french-section-plan/.superpowers/sdd/2026-10-15-fr04-learning-store/controller-arcade-preview-probe_test.dart \
  --reporter expanded
```

Result: **exit 0, 1 passed**.

## Verification

Focused regression and retained game tests:

```sh
PATH="/home/klottick/develop/flutter/bin:$PATH" \
  flutter test --no-pub \
  test/widget/arcade_preview_assistance_test.dart \
  test/widget/arcade_switch_test.dart \
  test/widget/course_learning_game_commit_test.dart \
  test/unit/course_learning_game_transition_test.dart --reporter expanded
```

Result: **exit 0, 37 passed**.

Full suite (run once after focused tests):

```sh
PATH="/home/klottick/develop/flutter/bin:$PATH" \
  flutter test --no-pub --reporter expanded
```

Result: **exit 0, 1015 passed**.

Static analysis:

```sh
PATH="/home/klottick/develop/flutter/bin:$PATH" flutter analyze --no-pub
```

Result: **exit 0, No issues found**.

Release web build:

```sh
PATH="/home/klottick/develop/flutter/bin:$PATH" \
  flutter build web --release --no-pub
```

Result: **exit 0, built `build/web`**. Flutter's wasm dry-run emitted three
existing `flutter_tts` JS-interop lint findings; the requested JavaScript web
build completed successfully.

`dart format` was run on the three changed frontend files. `git diff --check`
passed. The current real repository game-commit widget test and pure game
transition suite were included in the 37-test focused run.

## Review, limitations, delivery

The only extra persisted command on fresh Arcade starts is the required shown
preview observation. Activation remains downstream of its acknowledgement;
input/timer stay inactive during a held write or Retry. Existing pending-command
exclusivity, Start/checkpoint retry continuation, board/score/timer/audio logic,
and save-retry identity remain in place.

Implementation commit: `fd210a4` (`fix arcade fresh-start preview assistance`).
Existing draft PR37: https://github.com/klottick/phoneme-app/pull/37 (base
`main`, head `feat/fr04-task6-caller-cutover`); remains unmerged for controller
review. This report metadata is committed separately after the implementation
commit.
No live cloud, browser, or sandbox run was performed; the requested local
release JavaScript build and widget/regression coverage passed.
