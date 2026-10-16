# FR-06 reusable phoneme-listening exercises: published outcome

## Outcome and scope

The approved FR-06 implementation is published on GitHub `main` through
[PR46](https://github.com/klottick/phoneme-app/pull/46) and
[PR47](https://github.com/klottick/phoneme-app/pull/47). It adds controlled
identification and Same/Different phoneme-comparison views, integrates
identification into the existing discovery pilot, and enables explicit safe
replay before answering. Contracts and authored fake fixtures cover **vowels and
consonants**, not a vowel-only exercise framework.

The lesson owner still owns audio, hearing permission, correctness feedback,
typed commands, saving, recovery, finite rounds and navigation. No second runner,
session/store, persisted exercise kind or production comparison route was added.
Comparison production content, progress/evidence and playback-source integration
remain FR-07 scope. Test fixtures are declarations, not approved French content
or recordings.

- [Approved specification](../specs/2026-10-16-fr06-listening-exercises-design.md),
  [PR44](https://github.com/klottick/phoneme-app/pull/44): reviewed head
  `b409b6180dec70f4050068adfd80513ba828493c`, merge
  `508063883d5e1fc6534d0e7f62a6b3616d100ee4`.
- [Approved plan](../plans/2026-10-16-fr06-listening-exercises.md),
  [PR45](https://github.com/klottick/phoneme-app/pull/45): reviewed head
  `a8d9954783c8fda000ed8d90f02220969fbb2c74`, merge/execution baseline
  `8f17814aee566fb03606325cd2e2b0a7c71064c5`.

The user approved the written spec and then the written plan. Implementation used
sequential Luna workers, independent task specification/quality reviews, a final
whole-feature review and scoped rereviews. Incomplete early scaffolding was not
accepted or published. Each task started from current published `origin/main`
after the preceding reviewed PR merged.

| Delivery | Reviewed head | Published merge |
| --- | --- | --- |
| PR46: controlled components and comparison test owner | `2907a14b53840bfd4ae624e2fae844100ccf5168` | `35d22268a33e58414d9e8f862aa351cf4b0b2050` |
| PR47: pilot integration, replay and final semantics correction | `7c1b0721813d8b5a7e29830446835a645ccb544f` | `f5b3abc3bd0c0cf04f043294aa51c1baa5bac097` |

The final integrated review covered the execution baseline through PR47's reviewed
head. Controller verification used that exact final tree. Fetched merge trees
matched their respective reviewed heads completely. GitHub reported no checks,
formal reviews or inline feedback at the implementation merge gates; **missing
CI is not passing CI**. Independent agent reviews and controller acceptance are
recorded in PR comments and preserved process evidence, not represented as formal
GitHub approvals. No protection bypass, admin override or direct push to `main`
was used.

## Requirement and executed-evidence matrix

Source paths below are under `frontend/lib/src/features/course/`; test paths are
under `frontend/test/`. Every cited suite was included in the controller's final
full run. Passing fake-owner tests do not prove future comparison persistence or
real playback.

| Spec acceptance row | Source owner | Executed assertions / disposition |
| --- | --- | --- |
| Real extraction | `discovery_section_view.dart`, `discovery_lesson_screen.dart` | `widget/discovery_listening_exercise_test.dart`: `pilot_uses_reusable_choice_and_allows_replay` finds the reusable component and existing canonical `ChooseSound`. The actual diff removes the parallel inline puzzle; section recovery/Next/debrief remain outside the component. |
| Phoneme-wide contract | `exercises/listening_exercise_contract.dart`, `sound_comparison.dart` | `unit/listening_exercise_contract_test.dart` preserves three ordered opaque labels. `widget/listening_exercise_test.dart`: `comparison_uses_authored_phoneme_relation` covers four vowel/consonant pairs, both playback orders and both responses, and verifies actual requested reference IDs. Different words/references do not force Different. |
| Explicit targets | Pure prompts and test-only `ComparisonFixture` | Unit cases reject blank target declarations and inconsistent expected relations. Fake fixtures explicitly state first/final sound locations and target phoneme identities. No spelling-based locator, recording crop or linguistic certification is introduced. |
| Initial hearing gate | Controlled views and existing lesson owner | Component state matrices cover unheard, one-sample and both-sample states. Existing discovery before-hearing tests and new resume/review cases require current successful playback. Prompt/round identity does not restore permission. |
| Replay | Screen `_onListen`, comparison test owner | `pilot_uses_reusable_choice_and_allows_replay`, `replay_provider_failure_revokes_prior_hearing` and failure/cancel cases prove revocation before provider access, held-replay locking, fresh-success recovery and unchanged committed evidence. Comparison replay tests revoke only the replayed sample. |
| Failure vs cancellation | Typed injected audio and existing owner | Failure/cancel tests check no new answer preparation/submission and unchanged committed-state identity. Failure guidance is generic, cancellation quiet, wrong-reference completion unheard. No automatic skip, score or recording-failure TTS fallback is added. |
| Single submission / saving | Existing typed preparation/save callbacks | `replay_and_answer_claim_once_before_redraw_and_retry_is_frozen` gates an answer then fails it: immediate feedback/selection, locked retained callbacks, identical immutable Retry, one committed batch and ACK-only Advance. Keyboard and semantic activation through the real owner each admit one command before redraw. |
| Lifecycle / ownership | Captured audio, existing generation/store fences | Held replay crosses paused/hidden/detached resume, A→B→A, distinct active B audio, and disposal/remount. Success/failure/typed-cancel cases protect newer busy/hearing, player stop ownership and evidence. Comparison tests also distinguish equal-value rebuild retention from reference-only invalidation and preserve suspension across owner replacement. |
| No leakage | Neutral prompt projection, shared frame, generic errors | Component and real-pilot tests scan actual hidden word/transcription/explanation/error sentinels recursively in semantics label/value/hint/tooltip, text and tooltips before and after provider error/wrong feedback. Phoneme response labels remain intentionally visible; debrief owns teaching text. |
| Accessibility | Stateless controls and owner guards | Keyboard-only first admitted responses, traversal/exit, scrolling and 360×640/2× text remain covered. `identification_response_semantics_are_one_labeled_control`, `comparison_response_semantics_are_one_labeled_control` and `pilot_labeled_response_semantics_activation_is_owner_guarded` require label, selection, role, enabled state and action on the same exposed node, with no extra unnamed button. Semantic activation uses the real guarded callback. |
| FR-05 preservation | Unchanged session/store/codec/content and existing owner | All prior finite-round/repository/resume/recovery suites pass unchanged. One-item review pins saved 100% policy, 11 attempts, occurrence 2/repeat/after-debrief attribution and held final Advance. Known selection survives same-owner frozen recovery; fresh correct/wrong restore invents no selection and actual Next requires fresh hearing on item 2. |
| Comparison boundary | Typed UI-only `PhonemeRelation`, fake owner | No catalogue subtype, synthetic learning command, codec variant, production comparison progress or new recording-readiness claim. Widget grading remains owner-supplied. |

## Review dispositions and bounded adjustments

- Task1 review found suspension lost on owner replacement and insufficient
  keyboard/stale-hearing oracles. A reproduced test-owner failure and stronger
  real keyboard/held-replay assertions were corrected; independent rereview
  cleared them, including exact authored reference pairs.
- Task2 review required the non-exercise Listen guard, retention of known
  selection through same-owner frozen recovery, held/failed save locks, actual
  keyboard-first answers, stronger secrecy checks and active-B/disposed-replay
  evidence. Runnable failures preceded the guard/selection fixes. Scoped
  rereview cleared all Important findings.
- Final whole-feature review found selection attached to a separate semantics
  node from the labeled Material button. `MergeSemantics` now composes each
  response into one exposed control. A same-labeled-node selected-state RED and
  semantic activation assertions verify the correction, not just a moved test
  key. Final scoped rereview cleared it and the residual restored-Next Minor.
  **No FR-06 review finding remains unresolved.**
- Controller bounded the integration adjustments explicitly: preserve the
  pilot's Filled/Text button styles rather than weaken old tests or add a style
  API, and include both existing components in the final same-bug semantics fix.
  The corresponding owned-file extensions stayed within extraction/accessibility
  requirements. If wrong, these small presentation changes require rework and
  renewed accessibility verification; they do not migrate data or expand content.
- Replay is an intentional FR-06 addition, not an FR-05 defect claim. Missing API
  scaffolding and test-fixture compilation/assertion mistakes were not relabeled
  as product RED evidence. Existing behavior received preservation coverage;
  reproduced provider-hearing, phase, transient-selection and semantics failures
  justified the scoped runtime corrections.

## Controller verification and preservation

Commands below ran on final head
`7c1b0721813d8b5a7e29830446835a645ccb544f`; the fetched published merge tree
matched exactly. Flutter executable: `/home/klottick/develop/flutter/bin/flutter`.

| Working directory | Command | Result |
| --- | --- | --- |
| `frontend/` | `flutter test --no-pub --reporter expanded` | **1,093 passed**, exit 0; fresh unchanged-product execution baseline was 1,033, for 60 additional tests. |
| `frontend/` | `flutter analyze --no-pub` | No issues found, exit 0. |
| `frontend/` | `flutter build web --release --no-pub` | `Built build/web`, exit 0. Existing three `flutter_tts` Wasm dry-run cast warnings remain; this is a JavaScript build, not Wasm certification. |
| Repository root | `python3 -m unittest discover -s scripts -p 'test_*.py'` | **52 passed**, exit 0. |
| Repository root | `python3 scripts/verify_french_audio.py --repo-root .` | **24 pending** candidates passed technical/metadata verification only. |
| Repository root | `git diff 8f17814aee566fb03606325cd2e2b0a7c71064c5 7c1b0721813d8b5a7e29830446835a645ccb544f --check` | Clean; exactly 11 scoped Dart paths. |

The passing full-suite output includes three expected
`AudioPlayers Exception` / `FakePreparationError` stack outputs from unchanged
intentional backend-failure tests. It is not described as pristine output or a
new FR-06 failure. Final worker focused verification also passed: 60 new
contract/component/pilot cases and the 162-test focused regression bundle.

SHA-256 comparison verified **74** preserved asset/licence/policy/dependency/
backend/core paths against the published execution baseline. Recording bytes,
provenance, licences, root `LICENSE`, reference-audio policy, dependencies,
backend, registered content, session/storage formats and old namespaces remain
unchanged. Old development data, unpublished Sound Match work, local branches,
worktrees, untracked work and durable process records were preserved; no cleanup
or migration was performed. Local evidence, reports, reviews, acceptance matrix,
logs and publication ledger remain under
`.superpowers/sdd/2026-10-16-fr06-listening-exercises/`.

This outcome is delivered through its own scoped reviewed documentation PR.
Its exact PR/head/merge and published-tree verification are recorded in that
PR's comments and the local delivery ledger, avoiding a self-referential hash.

## Outstanding gates and non-goals

Real browser/native audio and assistive-technology acceptance, qualified French
linguistic/audio/licensing review, live Supabase validation, privacy, FR-15 and
production release remain open. Pending recordings remain pending and are not
assessment-ready by virtue of technical checks or fake-audio tests. This delivery
does not authorize recording uploads, microphone/cloud evaluation, pronunciation
grades, sandbox bypass, further Qwen investigation or silent TTS substitution.

FR-07 must separately design and integrate production comparison content,
validation, progress/evidence and source attribution. No broader legacy conversion,
new scheduler, storage migration, backend work or production pronunciation
evaluator is certified by FR-06.
