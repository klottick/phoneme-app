# FR-11-A map-first course: engineering outcome and acceptance status

**Outcome:** The approved phone-first space map and scoped Home/router/theme
integration were reviewed and published on `main` through PRs #103–108. This
delivers **FR-11-A only**, not full FR-11 or FR-18. The map exposes the existing
`/u/`–`/y/` discovery lesson and preserves existing activities; it does not add
curriculum, assessment, or qualification. The approved design is PR #101 and the
approved implementation plan is PR #102. User plan approval was recorded before
implementation; after the user changed the worker choice from Qwen to GPT-6
Luna, no further Qwen workers were used.

## Decision layers and remaining gates

| Area | Status | Meaning |
| --- | --- | --- |
| Map-first design | Approved | PR #101; the approved design remains the scope authority. |
| Implementation plan | Approved | PR #102; approval authorized only its scoped FR-11-A delivery. |
| FR-11-A map, Home/router, and scoped course appearance | **Delivered and published** | PRs #103–108 are merged. The map presents the current discovery pilot and optional existing activities. |
| Full FR-11 / FR-18 | **Open** | Remaining path, curriculum, assessment, and integration work is not delivered by this slice. |
| Curriculum and assessment | **Open** | Unfinished curriculum, spelling, exams, and mastery assessment remain outside this delivery. Map progress is not a mastery score. |
| French content and reference audio | **Open** | No new French content or reviewed recording is claimed. Follow the separate [French reference-audio gates](../../french-reference-audio.md). |
| Native, assistive technology, real playback, privacy, and release | **Unverified / open** | Browser/widget evidence is not native-device, full AT, real-audio, privacy, assessment, or release qualification. No real audio was played. |

No user, linguistic, accessibility, platform, or release approval is inferred
from engineering acceptance. Existing activity access and qualification gates
remain authoritative.

## Published PR record

The exact reviewed heads and merge commits below were cross-checked against the
published PR metadata in the delivery process record. “Merged” means published
on GitHub `main`; these rows do not imply GitHub checks or formal reviews where
none were reported.

| Scope | PR | Reviewed head | Merge commit |
| --- | --- | --- | --- |
| Approved design | [#101](https://github.com/klottick/phoneme-app/pull/101) | `a65bd603e3fc8de6f1fd7a3ce133ab91f596548a` | `66c2e7934324326af0aea1753a8f98137f6fd3cf` |
| Approved implementation plan | [#102](https://github.com/klottick/phoneme-app/pull/102) | `e17f448608bbb3eb729417214ea6c1b2efa814ff` | `65e0fcf00b3fc273f62757d9bdac1c9ad698b12e` |
| Map catalogue and authored destinations | [#103](https://github.com/klottick/phoneme-app/pull/103) | `da93fe1a8082c14de0e16202cc1efa15a073d0a6` | `7c161c4d8bfeaf1c068cb1eddbc41108a22f61aa` |
| Owner-safe map projection | [#104](https://github.com/klottick/phoneme-app/pull/104) | `498137585e56e65baaf711dad97b34ccf50570ae` | `48e35a8b25982ef7d17624fde1f1243ea75d8695` |
| Map presentation and motion | [#105](https://github.com/klottick/phoneme-app/pull/105) | `57babd85d371f10a46a4670f2eda066d6bb31789` | `a76aa78bbe5d5063a27ddcc562664555819d00e3` |
| Home, routes, and legacy recovery | [#106](https://github.com/klottick/phoneme-app/pull/106) | `cb129dc5f37d9b3655f1082cdae8230ee0e2a223` | `daf6b1cae385e8b932f83596e29de3d154ac4973` |
| Scoped course theme and integration | [#107](https://github.com/klottick/phoneme-app/pull/107) | `6a8413b8ff49aac85bc4886d9314aa38d937ec88` | `ceb3963c75e79098bdfa120d770e08de996ea5ce` |
| Final integration corrections and acceptance | [#108](https://github.com/klottick/phoneme-app/pull/108) | `672a44673fed34fdd705113995f76c5c9f28411b` | `01740e094b030f3a8f33ae57e33cfc0beff224b6` |

The controller's final acceptance comment is [on PR #108](https://github.com/klottick/phoneme-app/pull/108#issuecomment-6363236021). It records the exact reviewed head, verification, and remaining limits.

## Final controller verification

Fresh final verification was run by the controller against reviewed code head
`672a44673fed34fdd705113995f76c5c9f28411b`, before merge:

| Check | Result |
| --- | --- |
| Ordinary Flutter unit/widget suite | **1,622 passed** across 130 enumerated files. The only exclusions were `course_learning_retention_test.dart` and `learning_sql_retention_test.dart`; no other test files were excluded. |
| `flutter analyze --no-pub` | **No issues found.** |
| `flutter build web --no-pub` | **Succeeded** as the default JavaScript build. Existing `flutter_tts` Wasm dry-run / JS-interop warnings were emitted; this was not a Wasm build. |
| GitHub checks | PRs reported no checks. **No CI pass is claimed.** |

The controller's [final browser verification](https://github.com/klottick/phoneme-app/pull/108#issuecomment-6363236021)
used the rebuilt JavaScript bundle at the primary 390×844 dark viewport and
360×640 light viewport. It confirmed 48×48-pixel navigation/action targets,
keyboard focus, no horizontal overflow, saved light preference, chart-to-Home
return, and the final motion behaviors: visible animation, zero steady-state
frames while scrolled offscreen, zero frames under platform reduced motion, and
pause retained across responsive reflow. The actual saved checkpoint shown in
the dark capture is “In progress,” not mockup progress. The two published
captures are [dark](../specs/assets/2026-10-23-space-course/implemented-map-dark.png)
and [light](../specs/assets/2026-10-23-space-course/implemented-map-light.png).

The integrated widget matrix covers Flutter `TextScaler` 1×/2×/3×. Browser CDP
font scaling did **not** propagate into the CanvasKit app; no browser 3× screenshot
or full assistive-technology claim is made. Prior unchanged-theme focus raster
measurements of 4.62:1 / 9.65:1 are not represented as fresh post-integration
measurements. Earlier browser checks cover focus/48-pixel targets, keyboard
lesson launch/back, existing activities, recovery, and root navigation; no real
audio playback was tested. Detailed raw logs and process records remain local
and ignored, not GitHub-linked artifacts.

## Integration rulings and recorded tradeoffs

- The map and recovery footer share one scroll owner. That owner gates the
  hidden map ticker using viewport visibility, with no polling; the separate
  optional footer seam avoided nested vertical scrolling.
- Map-tab activation is a no-op only when already on canonical `/home`. From a
  chart or explicit system route it returns to `/home`, as the approved spec
  requires. This reversed an earlier interpretation that treated chart-to-Home
  as a no-op; the correction is recorded, not hidden.
- The saved-comparison checkpoint doorway says **Open comparison practice**;
  it does not promise to start a new run. Review remains separate, and the
  existing comparison lesson owns the actual “Practise again” action. No new
  run/reset behavior or hidden session write was introduced.
- Final review found and corrected three integration defects: offscreen map
  animation, chart/system Map-tab return, and misleading comparison-practice
  wording. A further responsive reflow fix preserved explicit pause by keeping
  the motion ancestor identity stable. These fixes received scoped re-review
  and final integrated verification; they did not expand curriculum or storage.

## Scope and evidence provenance

This delivery changes the map/Home/navigation/course appearance only. It adds no
curriculum, French content, audio assets, storage schema, dependency, or release
qualification. The implementation's own raw test logs and detailed evidence are
retained in ignored local process records; they are not published as browsable
GitHub files. This status links only to the published PRs, controller comment,
and the two included browser captures. Full FR-11/FR-18 and all listed acceptance
gates remain open.
