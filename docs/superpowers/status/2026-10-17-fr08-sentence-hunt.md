# FR08 sentence hunt: engineering outcome and acceptance status

**Outcome:** engineering Tasks 1A–8 are integrated on published `main` at
`34c2daa6ba48947e1ad5fa3d5c89379289c46daf`. This is an engineering delivery,
not a qualified French sentence set, usable pilot, or release acceptance. The
15 production candidates remain pending and unqualified; no section is
available. The Task 9 outcome-document PR is the publication boundary for this
record and is pending while that PR is reviewed. This document intentionally
does not predict or embed its own future merge commit.

## Decision layers

| Decision | Status | Meaning |
| --- | --- | --- |
| FR08 design/specification | Approved | The approved contract remains the authority; this outcome does not reopen or widen it. |
| Engineering integration, Tasks 1A–8 | Accepted and published | PRs #66–76 are merged on `main`; Task 8's independent/controller integration acceptance is recorded at [the controller comment on PR #76](https://github.com/klottick/phoneme-app/pull/76#issuecomment-6251702399). |
| Sentence content and contextual answer keys | **Blocked** | No qualified French/audio/contextual-key review evidence is available. All 15 remain pending/unqualified; 0/3 sections are qualified and all three are unavailable. |
| Source rights and distribution | **Blocked** | No actual rights-reviewer decision over the archived grant, required credits/notices, and distribution constraints is recorded. |
| Real playback and platform support | **Unverified** | No real browser, iOS, or Android learner playback exercise was supplied. A web build and synthetic playback tests are not real-platform acceptance. |
| Assistive technology and privacy | **Unverified** | Automated semantic/keyboard checks do not substitute for real assistive-technology exercises or a privacy review. No learner audio upload or cloud grading is introduced or approved. |
| Assessment and release | **Not accepted** | Content, rights, playback, accessibility, privacy, assessment suitability, and release gates remain separate and open. The known web full-retention capacity limit below is a release blocker. |

No implementer or model supplies human approval by proxy. No reviewer names,
qualifications, dates, or decisions are invented here. When a qualified reviewer
is available, decisions must bind to the exact clip, answer key, and annotation
hash; rejection leaves the affected section unavailable. A change of audio/key
identity requires a separately scoped content-fix PR and affected tests.

## Current packet identity and qualification

The technical sentence verifier reports 15 candidates (five per section), 15
pending/unqualified, 0 qualified, and 0/3 qualified sections. `--require-reviewed`
correctly rejects the current packet because all 15 candidates are unqualified.
That expected gate failure is not a verifier defect and is not an approval result.

The packet references the pinned `FLEURS fr_fr/train` source revision
`d7c758a6dceecd54a98cac43404d3d576e721f07`. The following are SHA-256 hashes of
the current tracked packet metadata bytes; `manifest.json` and `provenance.json`
bind the exact original and derived audio identities. These hashes establish
which packet was checked, not that its French, keys, rights, or suitability have
been reviewed.

| Packet file | SHA-256 |
| --- | --- |
| `frontend/assets/audio/fr-sentences/manifest.json` | `c53dd4820af01e6f85bbd7927a5ea91e0fb93104776284fa7b382ee61c906121` |
| `frontend/assets/audio/fr-sentences/provenance.json` | `7d1813163d551cbbe980b3f69f37bf3f0d8279ee305c2b9a9059498802aac13b` |
| `frontend/assets/audio/fr-sentences/annotations.json` | `eda1ddb0e3f7a872418ea021300fa583dedf44a33785fa0e278f543f88c68bd9` |
| `frontend/assets/audio/fr-sentences/source-evidence.json` | `90bda4bf5b4dec845041c3f1334b3806e76c7539cf8d3838d76ea10b604bbc2f` |

The exact source packet and these hashes were not edited by Task 9. Candidate
draft labels or technical metadata must not be treated as reviewed transcripts,
target membership, distractors, liaison/schwa/elision decisions, crop-boundary
approval, rights clearance, or production readiness.

## Spec §7 acceptance matrix

The engineering evidence below is automated/test-fixture evidence from the
merged PRs. Where real content, device, human, or release evidence is required,
the table says so explicitly rather than promoting synthetic results into a
manual pass.

| Spec §7 area | Published engineering evidence | Remaining acceptance gate |
| --- | --- | --- |
| Content packet | PRs [#66](https://github.com/klottick/phoneme-app/pull/66)–[#70](https://github.com/klottick/phoneme-app/pull/70); Python package, preparation, WAV, and verifier tests; technical verifier confirms 15 pending records and packet/hash integrity. | Qualified reviewer must listen to all exact clips and resolve target membership, distractors, variants, liaison/schwa/elision, and crop boundaries. Rights reviewer must decide grant, attribution/notices, and distribution. Until then, 15/15 pending and 3/3 sections unavailable. |
| Contextual validation | `scripts/test_verify_french_sentences.py`, `frontend/test/unit/french_sentence_package_test.dart`, and `frontend/test/unit/sentence_hunt_content_test.dart` cover identity, schema, evidence bindings, malformed/mismatched inputs, and fail-closed availability. | Technical validation cannot establish that a target is truly present, a distractor absent, a transcript/context correct, or a linguistic variant appropriate. Human review is absent. |
| Scoring | `frontend/test/unit/sentence_hunt_content_test.dart` and `frontend/test/unit/sentence_hunt_learning_transition_test.dart` exercise exact target sets, invalid selections, and transition behavior. | These tests use authored/synthetic fixtures; qualified content/key review remains required before learner scoring is meaningful. |
| UI/debrief | `frontend/test/widget/sentence_hunt_test.dart` covers active-renderer visibility and input semantics; `frontend/test/widget/sentence_hunt_lesson_screen_test.dart` and `frontend/test/widget/sentence_hunt_section_debrief_test.dart` cover lesson/debrief visibility and saved debrief behavior. | No production key or teaching content is approved for use until the exact packet is qualified. Real assistive-technology acceptance is still open. |
| Audio | `frontend/test/unit/sentence_hunt_audio_test.dart` and the controller's reviewed-only timeout probe exercise conservative source classification, failure, and grant behavior. Runtime remains reviewed-recording-only, normal mode, with TTS disabled. | No real browser/iOS/Android playback, recording identity, or actual hearing evidence was supplied. PR #76's timeout test uses an intentionally permissive facade configuration as adversarial negative coverage; that test does not enable TTS or change runtime policy. |
| Sessions | `frontend/test/unit/sentence_hunt_learning_transition_test.dart`, `frontend/test/unit/sentence_hunt_learning_codec_test.dart`, and controller/widget tests cover independent sections, finite rounds, saved 4/5 policy, review-only mode, and completion boundaries. | Synthetic tests do not qualify real recordings, keys, assessment suitability, or release. |
| Evidence/progress | `frontend/test/unit/sentence_hunt_progress_summary_test.dart` and `frontend/test/widget/sentence_hunt_entry_flow_test.dart` cover committed-only section counts, item-scoped mistakes, unknown/loading state, and acknowledged publication. | No assessment or learner-outcome validation has been accepted; privacy and release review remain open. |
| Transactions | Store/provider tests plus `sentence_hunt_entry_flow_test.dart` exercise held writes, failed ACK, exact retry, duplicate idempotency, and provider/Home/progress publication. The Task 8 controller probe used the repository/providers and held persistence. | These checks do not demonstrate browser quota, physical-device storage capacity, power-loss durability, or real cross-device performance. |
| Restore/isolation | `frontend/test/unit/sentence_hunt_learning_codec_test.dart`, `sentence_hunt_learning_store_test.dart`, `sentence_hunt_learning_providers_test.dart`, and entry-flow tests exercise corrupt-byte preservation, sibling-family recovery, and owner isolation. | Real platform durability/capacity is still unverified; web full-retention capacity is a known blocker. |
| Navigation/accessibility | Navigation coverage: `frontend/test/widget/sentence_hunt_entry_flow_test.dart`, `frontend/test/widget/home_navigation_test.dart`, and `frontend/test/widget/course_learning_progress_test.dart` cover additive routes, unavailable sections, Home, and progress. Renderer/accessibility coverage: `frontend/test/widget/sentence_hunt_test.dart:116–227`, named `selection and submit use one pointer keyboard and semantics gate`, exercises pointer selection, semantic activation (`183–190`), and Tab/Enter (`192–199`). Narrow/large-text coverage is in `frontend/test/widget/sentence_hunt_lesson_screen_test.dart`. | Automated semantics and text-scale tests are not real screen-reader/assistive-technology acceptance. Browser/iOS/Android user paths remain unverified. |
| Preservation | Task 9 baseline is published `main` `34c2daa`; the final task check confirms all 522 original tracked-file hashes unchanged. The nine originally recorded user-file hashes and existing local user artifacts are preserved. Existing word/comparison readiness and Sound Match work are unchanged. | Preserve these boundaries in the separate content-qualification and release work; no gate waiver or status promotion is implied. |

### Historical evidence corrections and test-contract rulings

- **Task 3:** retained evidence did not include its initial behavioral RED. This
  is documented as missing evidence, not reconstructed. Later retained fix-round
  behavioral RED/GREEN evidence and the published suite remain distinct from that
  historic gap.
- **Task 7:** the earlier explicit-policy and explicit-Resume RED claims were
  retracted because the retained logs do not substantiate those failures. Current
  tests still exercise those contracts; no old failure is recreated or claimed.
- **Task 4/5 deferred tests:** PR #76 closed the raw resolver-timeout and forged
  selection matcher coverage items with tests only. The timeout test is
  deliberately negative/fail-closed coverage, including a permissive facade
  configuration; a separate controller probe passed under reviewed-only/normal/
  TTS-disabled settings. No production playback/TTS permission changed. The
  forged-selection assertions likewise added coverage without a production
  transition change.
- **Retry ruling:** the frozen contract is command/receipt identity, preservation
  of prior acknowledged bytes, one acknowledged publication, and duplicate
  idempotency. The `committedAt` of a newly successful completion can differ
  between failed and retried candidate evaluations. This is a test-contract
  correction, not a shared transaction-core fix or a promise of byte-identical
  failed candidate data.

### Known web full-retention capacity blocker

An isolated HeadlessChrome 156 localStorage probe accepted a 4 MiB serialized
value and rejected 5 MiB with `QuotaExceededError`; the prior value was preserved
and the probe key was removed. The retained sentence documents are roughly
18–32 MB, with a 35.77 MB supported-pilot envelope, so full retention cannot fit
the measured browser backend. The 36 MiB codec ceiling is a codec limit, not a
browser quota. This is a known web release blocker, not a generic unverified
runtime fix.

Flutter plugin/native capacity, memory/performance, physical durability, and
other browser/device capacities remain unverified. No storage/API/retention
redesign, retention reduction, split writer, automatic deletion, or cloud
fallback is authorized by this task.

## Tasks 1A–8 publication and verification record

The reviewed/published heads and merge commits below were cross-checked against
the retained Task 9 publication evidence and GitHub PR metadata. “Reviewed head”
is the exact head recorded for that task; the table does not infer reviewer
identity from missing GitHub review objects. Test source paths are tracked and
reachable from each linked PR. Ignored local logs are retained locally and are
not represented as files browsable from GitHub.

| Task | PR / reviewed head / merge commit | Named verification evidence at the published task head |
| --- | --- | --- |
| 1A | [#66](https://github.com/klottick/phoneme-app/pull/66)<br>Head `381807ce29719b303c3d33abd26bfaacc47be762`<br>Merge `7de5550bef305a86a1fd20e9bc60d758d4f617e3` | `python3 -m unittest discover -s scripts -p 'test_french_sentence_package.py' -v`: 8 focused tests; `python3 -m unittest discover -s scripts -p 'test_*.py' -v`: 60; `python3 scripts/verify_french_audio.py --repo-root .`: 24 pending candidates. |
| 1B | [#67](https://github.com/klottick/phoneme-app/pull/67)<br>Head `8c7b207dab9a314331194f27b1f46d64b04a9980`<br>Merge `ddb284108cde801dce9f577fdfe3ceeae1cfd213` | `python3 -m unittest discover -s scripts -p 'test_prepare_french_sentences.py' -v`: 19 focused tests; `python3 -m unittest discover -s scripts -p 'test_*.py' -v`: 79; `python3 scripts/verify_french_audio.py --repo-root .`: 24 pending. Preparation fixtures and fake process/network boundaries are not actual source acquisition. |
| 1C | [#68](https://github.com/klottick/phoneme-app/pull/68)<br>Head `5bdba20b2ca2bc127318ec4bd44c56d4a16a24c4`<br>Merge `e62f9d883e43a62d28ed891d48bc1b75cd273e33` | `python3 -m unittest discover -s scripts -p 'test_verify_french_sentences.py' -v`: 58 focused tests; `python3 -m unittest discover -s scripts -p 'test_*.py' -v`: 137; word verifier: 24 pending. Synthetic accepted fixtures test verifier behavior, not production approval. |
| 1D | [#69](https://github.com/klottick/phoneme-app/pull/69)<br>Head `64719445a5c506c317fb94e3f7615a29ef5688ab`<br>Merge `cecbaf456097bd62c5b0e8577f8a4f24151890b5` | `python3 -m unittest discover -s scripts -p 'test_french_sentence_wav.py' -v`: 18; `python3 -m unittest discover -s scripts -p 'test_prepare_french_sentences.py' -v`: 28; full Python suite: 171; read-only preflight of 15 selected originals; word verifier: 24 pending. No production listening or audio qualification. |
| 2 | [#70](https://github.com/klottick/phoneme-app/pull/70)<br>Head `c2fa145df77c70095e3f134678508c962bee4551`<br>Merge `74c9c1cdeb0dd1d1a68690979e65559a0adddb93` | `python3 -m unittest discover -s scripts -p 'test_*.py' -v`: 171; `python3 scripts/verify_french_sentences.py --package-root frontend/assets/audio/fr-sentences`: 15 pending/0 qualified/0 of 3 sections; `--require-reviewed`: expected exit 1 for 15 unqualified; word verifier: 24 pending. |
| 3 | [#71](https://github.com/klottick/phoneme-app/pull/71)<br>Head `023050d78f09563bd748f1ee4fbf259997573327`<br>Merge `d88a54a02b16a8623a89c651093dfb3a78675f28` | From `frontend/`: `flutter test --no-pub test/unit/sentence_hunt_test.dart test/unit/sentence_hunt_content_test.dart test/unit/french_sentence_package_test.dart --reporter expanded`: final focused feature set 50; named registry/audio regressions: 46; `flutter test --no-pub --reporter expanded`: 1,400; `flutter analyze --no-pub`; full Python suite 171; sentence verifier 15 pending and expected `--require-reviewed` failure. Initial behavioral RED history is missing as noted above. |
| 4 | [#72](https://github.com/klottick/phoneme-app/pull/72)<br>Head `a5fb1e34bb9419dc06a5407dd6a43e7841b0459e`<br>Merge `6cd706daaa300d85e4482513c978b3f661e16330` | Focused audio/listening/reference-audio set (including `course_reference_audio_test.dart` and `sentence_hunt_audio_test.dart`): 146; from `frontend/`, `flutter test --no-pub --reporter expanded`: full suite 1,410; `flutter analyze --no-pub`; `python3 -m unittest discover -s scripts -p 'test_*.py' -v`: 171; word/sentence verifiers; sentence `--require-reviewed` expected failure. Actual playback remains unverified. |
| 5 | [#73](https://github.com/klottick/phoneme-app/pull/73)<br>Head `554c75ca44e76ec56eb4df821105f6e01668011b`<br>Merge `172577b55c1da5f43f6fdde96c7b8398f33d4c48` | From `frontend/`, `flutter test --no-pub test/unit/sentence_hunt_learning_transition_test.dart test/unit/sentence_hunt_learning_codec_test.dart --reporter expanded`: 13 + 25; sentence-content regression: 33; comparison/course compatibility tests: 17/29/25; `flutter test --no-pub --reporter expanded`: full suite 1,448; Python suite 171; pending/expected-review-gate verifiers. |
| 6 | [#74](https://github.com/klottick/phoneme-app/pull/74)<br>Head `0c1b70d9f5514c220e8094ddbfbb5228cb206d06`<br>Merge `9333f53ba43844e7780372abdcd71230ceb4fb4e` | From `frontend/`, `flutter test --no-pub test/unit/sentence_hunt_learning_store_test.dart test/unit/sentence_hunt_learning_providers_test.dart --reporter expanded`: 22; full-suite `flutter test --no-pub --reporter expanded`: 1,470; analyzer; Python suite 171; pending/expected-review-gate verifiers. The separate real browser quota observation is recorded above. |
| 7 | [#75](https://github.com/klottick/phoneme-app/pull/75)<br>Head `c649275b8880ae61474ad8792fb72f168575b302`<br>Merge `518d7fe5c63cd5ae08cb6930e4d3ebfa23040c63` | From `frontend/`, `flutter test --no-pub test/unit/sentence_hunt_controller_test.dart test/widget/sentence_hunt_lesson_screen_test.dart test/widget/sentence_hunt_test.dart test/widget/sentence_hunt_section_debrief_test.dart --concurrency=1 --reporter expanded`: 23; named owner/legacy regressions: 262; `flutter test --no-pub --concurrency=1 --reporter expanded`: 1,493; analyzer; Python suite 171; pending/expected-review-gate verifiers. Historic RED corrections are noted above. |
| 8 | [#76](https://github.com/klottick/phoneme-app/pull/76)<br>Head `a74e04b1c38773f6e28f3a41126a0f1ad0b58449`<br>Merge `34c2daa6ba48947e1ad5fa3d5c89379289c46daf` | Exact-head controller verification: from `frontend/`, `flutter test --no-pub --reporter expanded`: 1,510. Selected command also covered `home_navigation_test.dart`, `course_learning_progress_test.dart`, `comparison_entry_flow_test.dart`, `sentence_hunt_entry_flow_test.dart`, `sentence_hunt_controller_test.dart`, `sentence_hunt_test.dart`, `sentence_hunt_lesson_screen_test.dart`, `sentence_hunt_section_debrief_test.dart`, `sentence_hunt_audio_test.dart`, `sentence_hunt_learning_transition_test.dart`, `sentence_hunt_progress_summary_test.dart`, `sentence_hunt_learning_store_test.dart`, and `sentence_hunt_learning_providers_test.dart`: 119. `flutter analyze --no-pub`; owned-path `dart format --output=none --set-exit-if-changed` (10 files); `flutter build web --release --no-pub`; Python suite 171; word verifier 24 pending; sentence verifier 15 pending/0 qualified; `--require-reviewed` expected failure for 15. Controller acceptance: [PR #76 comment](https://github.com/klottick/phoneme-app/pull/76#issuecomment-6251702399). |

The Task 8 web build emitted existing `flutter_tts` Wasm dry-run/JS-interop
warnings; it succeeded as a JavaScript web release build. Those warnings are
not evidence of actual playback or TTS approval.

At Task 9's read-only GitHub query, PRs #66–76 were all `MERGED` against `main`
with remote head and merge SHAs matching the table and retained publication
records. `statusCheckRollup` was empty for the queried PRs; no CI checks are
claimed as passing. The independent Task 8 acceptance is documented in the
controller comment linked above. Empty GitHub review/check fields are not
relabelled as passing CI or fabricated reviewer evidence.

### Task 9 data-only verification

The Task 9 change is documentation-only, so no behavior RED was applicable or
claimed. Fresh checks on the Task 9 worktree were:

| Command | Result |
| --- | --- |
| `python3 -m unittest discover -s scripts -p 'test_*.py' -v` | 171 passed. |
| `python3 scripts/verify_french_audio.py --repo-root .` | Pass: 24 pending word candidates, technical/metadata only. |
| `python3 scripts/verify_french_sentences.py --package-root frontend/assets/audio/fr-sentences` | Pass: 15 pending/unqualified, 0 qualified, 0/3 qualified sections. |
| `python3 scripts/verify_french_sentences.py --package-root frontend/assets/audio/fr-sentences --require-reviewed` | Expected exit 1: review gate reports 15 unqualified candidates. |

Task 9 did not rerun Flutter tests, analyzer, or the web build. The 1,510-test
Flutter run and web-build evidence above are from the exact reviewed/published
Task 8 head, not a Task 9 rerun. This change adds no runtime behavior.

## Task 9 scope and remaining actions

Task 9 changes this new status document only. It does not modify sentence
metadata/assets, `docs/french-sentence-audio.md`, word readiness, comparison
readiness, Sound Match, runtime/API/storage/retention, dependencies, or CI.

Next actions are gate-specific and do not presume named people or dates:

1. Identify a qualified French reviewer and a source-rights reviewer. Have them
   inspect the exact packet hashes above and record actual names,
   qualifications, dates, evidence, and accept/reject decisions. Rejected
   sections remain unavailable; identity changes require a separate content PR.
2. Obtain actual browser/iOS/Android playback and assistive-technology evidence
   on the supported environments, plus privacy and assessment review.
3. Resolve or explicitly release-block the measured browser full-retention
   capacity limitation through a separately approved design/scope decision. No
   storage or retention change is authorized by this status document.
4. Controller review of the Task 9 documentation PR, exact-head/current-base
   verification, preservation checks, and normal merge are still required.
   Until then this Task 9 publication is pending. The controller records its
   actual published head/merge in local process evidence after merge; no
   self-referential future hash is asserted here.

## Scope and evidence provenance

The acceptance categories correspond to approved FR08 design §7–8. PR links and
test paths above are public/tracked evidence; task reports and raw logs under
`.superpowers/sdd/2026-10-17-fr08-sentence-hunt/` are ignored local process
records, not GitHub-hosted files. This outcome therefore cites their tracked
test paths and published PRs rather than implying those local logs are remotely
browsable.
