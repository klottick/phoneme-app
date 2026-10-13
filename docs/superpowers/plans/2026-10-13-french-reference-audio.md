# FR-02 Pending-Review Audio Candidates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce 24 licensed, unchanged French word-audio candidates with auditable provenance, expected phoneme mappings and offline verification, all pending linguistic review.

**Architecture:** A candidate JSON manifest and matching provenance records live beside original WAVs but are not registered or consumed by the app. A Python standard-library verifier checks strict metadata and binary integrity; Dart tests compare candidates against the actual authored catalogue. A human-readable guide preserves credits and the linguistic-review/release handoff.

**Tech Stack:** Existing Flutter/Dart tests; Python 3 standard library (`unittest`, `json`, `pathlib`, `hashlib`, `wave`, `struct`, `argparse`); no dependencies added.

**Spec:** [docs/superpowers/specs/2026-10-13-french-reference-audio-design.md](../specs/2026-10-13-french-reference-audio-design.md), approved by the user after commit `82ee5fd`.

## Global Constraints

- “Preserve each binary without trimming, normalization, conversion or cropping.”
- “Do not modify the root `LICENSE` or its copyright header.”
- “No new product or tooling dependencies are needed.”
- “The production app does not import or load these artefacts.”
- `schemaVersion: 1`, `catalogueStatus: "candidate"`, `language: "fr"`; this is not the app's persisted version/contentRevision.
- `review`: `status: "pending"`, `reviewer: null`, `reviewedAt: null`, `evidence: []`; `changes: []`.
- `speaker`: `sourceName: "LoquaxFR"`, `qualificationStatus: "unverified"`, `accent: null`.
- `CC-BY-SA-4.0` for 23 words; `CC-BY-4.0` for `sans`, with exact URLs and retained notices from the spec.
- “Ambiguous ownership or access/distribution terms block import.”
- “No `pubspec.yaml` registration, player, runtime catalogue loader, new enum or public API, routes/screens, lesson edits, assessment enablement, TTS changes”.
- No cloud storage/grading, microphone uploads, synthetic reference audio, accounts, purchases, corpus-scale downloads or multi-speaker expansion.
- “Word-context membership does not fill those seven gaps.” Isolated `/u y i o ɔ̃ ɑ̃ ʁ/`, sentences and paragraphs stay outstanding.
- “Network requests are not part of tests”; verification is read-only and offline.
- “Preserve unpublished Sound Match work and local branches; do not incidentally publish them.”

## Review Focus

1. A symlink in a parent directory or licence path must not bypass package containment (Task 1).
2. Nested duplicate JSON keys, `true` as a numeric value, and non-finite durations must fail rather than look valid (Task 1).
3. A plausible WAV header with short sample data must fail; legitimate extra RIFF chunks and padding must not cause rejection (Task 1).
4. A valid hash must not conceal mismatched transcription, licence, credit, media identity or description revision in provenance (Task 1 plus Task 2 manual source gate).
5. Unicode-decomposed `île` or reordered/character-split nasal phonemes must not become replacement content identities or answer keys (Tasks 1 and 2).

---

## Execution setup and ownership

This plan is **for user review**. Its existence does not authorize execution.
Preserve the selected method: sequential implementers using
`ollama/qwen3.8:27b`, controller review, independent verification and controlled
merges. Do not dispatch agents during planning. At execution, resolve that exact
requested model through the model catalogue; if unavailable, report the blocker
instead of substituting a model silently.

Use the worktree skill at execution time. Create an execution branch/worktree
from the reviewed spec/plan documentation head containing published FR-01
`cd62e19`; do not use local `main` or `feat/phoneme-word-match` as a product base
or publish their unpublished `4dff777`/`af7e871` work. Each worker owns only its
listed files and starts after the previous task's controller review/merge.
Retain the existing per-task spec/compliance and code-review gates and a final
independent whole-branch review. Reviewers do not manufacture French sign-off.
No force push, broad reset/cleanup or worker-worktree removal is authorized here.

Commands below run from the repository root unless `workdir: frontend` is stated.
The existing SDK path is `/home/klottick/develop/flutter/bin`; confirm it exists
at execution and use its `flutter`/`dart` binaries. Set up the existing locked
dependencies in the isolated frontend only if needed, without changing pubspec
or lockfiles. Python is available as `python3` (currently 3.14.4). Environment
failures are blockers, not evidence of the required RED test failure.

## File map

| File | Owner and responsibility |
| --- | --- |
| `scripts/verify_french_audio.py` | Task 1: strict offline manifest/provenance and binary verifier; read-only CLI |
| `scripts/test_verify_french_audio.py` | Task 1: temporary fixture builders and positive/negative unittest cases |
| `frontend/assets/audio/fr/words/<word>.wav` | Task 2: 24 untouched source binaries, Unicode word names |
| `frontend/assets/audio/fr/manifest.json` | Task 2: exact approved candidate schema and lexical mappings |
| `frontend/assets/audio/fr/provenance.json` | Task 2: exact approved evidence schema, source/media pins and rights declarations |
| `frontend/assets/audio/fr/licenses/CC-BY-4.0.txt` | Task 2: complete official licence text, not a paraphrase |
| `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | Task 2: complete official licence text, not a paraphrase |
| `frontend/test/unit/french_audio_manifest_test.dart` | Task 2: real package and actual catalogue parity, plus mutated negative cases |
| `frontend/test/support/french_audio_candidate_checks.dart` | Task 2: test-only parity assertion helper, never imported by runtime |
| `docs/french-reference-audio.md` | Task 2: credits, verification, review checklist and remaining-gate handoff |

The spec defines every JSON field and nested key set; implement that schema,
not a second informal variant. Paths in manifest entries and `license.textPath`
are repository-relative (including `frontend/assets/audio/fr/`). Do not add an
acquisition service, runtime model, Dart-source parser or forced aligner.

### Task 1: Offline candidate-package verifier

**Files:** Create `scripts/verify_french_audio.py` and `scripts/test_verify_french_audio.py`.

**Interfaces:**
- Consumes: the approved manifest/provenance schema and package paths under a supplied repository root; no network or production imports.
- Produces: `measure_wav(path: Path) -> dict[str, str | int | float]`, returning exactly the `audio` object; malformed, empty, unsupported or truncated WAVs raise `ValueError`.
- Produces: `verify_package(repo_root: Path) -> list[str]`, returning `[]` on success or deterministic, actionable diagnostics naming the file/record/field. Ordinary bad package inputs must yield diagnostics, not tracebacks.
- Produces: `main(argv: list[str] | None = None) -> int`, supporting `--repo-root PATH`, defaulting to the script's repository root independent of cwd. Exit 0 on success, 1 on package failure; standard argparse usage errors may exit 2.
- Test-only helper: `make_package(repo_root: Path) -> None` in the Python test file creates a complete 24-entry temporary fixture with small PCM test data and internally consistent evidence. These samples are unmistakable unit-test data, not human recordings or product assets.

- [ ] **Step 1: Write failing positive/measurement tests.** Create temporary-root unittest fixtures and tests named `test_valid_package`, `test_measure_wav`, and `test_cli_from_another_directory`. Assert `verify_package(root) == []`; a 16-bit mono, 8000 Hz, 80-frame PCM sample measures `bitsPerSample == 16`, `channels == 1`, `sampleRateHz == 8000`, `frameCount == 80`, and `durationSeconds == 0.01`. Assert the CLI uses the supplied root, exits 0, and prints `PASS: 24 pending French word candidates verified (technical/metadata only).` Patch network access to raise if attempted.

```python
def test_valid_package(self):
    self.assertEqual(verify_package(self.root), [])

def test_measure_wav(self):
    audio = measure_wav(self.root / "frontend/assets/audio/fr/words/tout.wav")
    self.assertEqual(audio, {
        "container": "wav", "encoding": "pcm", "sampleRateHz": 8000,
        "channels": 1, "bitsPerSample": 16, "frameCount": 80,
        "durationSeconds": 0.01,
    })
```

- [ ] **Step 2: Run RED.** Run `python3 -m unittest discover -s scripts -p 'test_verify_french_audio.py' -v`. Expect failure from the missing verifier/module functions, not fixture errors or missing dependencies; retain the command/output.

- [ ] **Step 3: Implement the minimal verifier/measurement/CLI.** Use strict UTF-8 JSON parsing with duplicate-key detection, basic root/list shape checks and the positive fixture's identity/hash/measurement checks; the complete nested schema/evidence/path constraints follow their failing tests in Step 7. Measure bytes with hashlib and PCM with wave plus RIFF bounds/data-length checks; allow legitimate extra RIFF chunks/padding. Match all 24 spec IDs/order without parsing Dart source; actual Dart mapping truth is Task 2's independent oracle. The success message explicitly excludes linguistic/rights verification. Print failures as `ERROR: <diagnostic>` to stderr and never rewrite files.

- [ ] **Step 4: Run GREEN.** Repeat the Step 2 command; expect exit 0 and all three positive tests passing before extending validation.

- [ ] **Step 5: Add failing corruption/schema/path tests.** Use independently mutated temporary copies; never corrupt tracked files. For each case below assert `verify_package(root)` is nonempty, diagnostics identify the affected record/field/file, and verification leaves input bytes unchanged. Add `test_measure_wav_rejects_invalid_input` asserting `ValueError` for corrupt/truncated/unsupported samples.

| Test name | Mutations/assertions |
| --- | --- |
| `test_schema_failures` | Invalid UTF-8/JSON; duplicate top-level and nested keys; missing/extra root and nested fields; schema 2; null required strings; booleans where integers expected; NaN/infinite durations |
| `test_identity_failures` | Missing/extra/reordered records; duplicate IDs/asset paths; wrong kind/text; ASCII `ile` and Unicode-decomposed `île`; extra/unlisted or absent WAVs |
| `test_path_failures` | Absolute paths, `..`, symlinked WAV, symlinked parent directory, symlinked licence file/parent, licence outside `licenses/`; no escaped file is treated as package content |
| `test_integrity_failures` | Tampered bytes, false byteLength/hash/audio properties, zero frames, claimed frame count exceeding actual data, incomplete RIFF chunk/padding |
| `test_rights_and_evidence_failures` | Swapped `sans` licence, incorrect URL, empty attribution/declaration/creators, absent licence text, different provenance hash/text/speaker/notices/credit, wrong source title/revision URL/media URL, malformed dates/SHA-1, available SHA-1 mismatching bytes |
| `test_pending_only` | `reviewed` status, invented reviewer/date/evidence, speaker qualification/accent claim, nonempty changes, wrong mapping-origin path/symbol/status/revision syntax |
| `test_cli_failure_is_read_only` | Bad package exits 1 with actionable stderr and no writes or network calls |

Use subtests for related mutations. A source title normalizing Commons spaces to
underscores must still designate the selected word's file, and its revision URL
must match that title and descriptionRevisionId; encode/decode Unicode safely.
Check HTTPS and expected Commons/Wikimedia hosts using URL parsing, not substring
matching. Validate UTC timestamps and source hash syntax as in the spec.
Licence text existence/nonempty content is machine-checkable; complete official
text and actual rights assertions still require Task 2's manual gate.

- [ ] **Step 6: Run RED for added tests.** Repeat the unittest command; retain the meaningful failures exposing absent validation. Any check already implemented may pass; the new tests as a group must expose missing behavior before fixes.

- [ ] **Step 7: Complete validation.** Keep schema, safe-path, evidence, and binary checks in small named functions inside the verifier. Reject symlinks at each path component, check readable regular files, compare provenance one-to-one against manifest, and enforce all spec constants. Verify measurement/hash fields from bytes, not recorded source estimates. Handle package errors without masking programming errors behind a blanket catch.

- [ ] **Step 8: Add a legitimate-format regression test.** `test_pcm_with_metadata_and_padding` supplies a valid PCM fixture with an odd-sized metadata chunk plus padding and asserts the same measured frames/duration and `verify_package(root) == []`. Ensure it exercises real RIFF bytes, not a mocked measurement function.

- [ ] **Step 9: Run final Task 1 checks.** Run the unittest command and `python3 -m unittest discover -s scripts -p 'test_mobile_configuration.py' -v`; expect exit 0 and no network. Check source imports are standard-library only. No assertion that real 24-word audio exists is allowed yet.

- [ ] **Step 10: Commit and report.** Stage only the two owned files; commit `feat: add offline French audio candidate verifier`. Report RED/GREEN evidence, interfaces, fixture limitations and changed paths. Controller reviews/tests the task before Task 2 begins.

### Task 2: Licensed original-word package and real-catalogue oracle

**Files:** Create the Task 2 files listed in the file map; modify no existing runtime file, pubspec, dependency lockfile or root licence. Consume Task 1 without silently changing its contract; report needed corrections to the controller.

**Interfaces:**
- Consumes: `measure_wav(path: Path)` and `verify_package(repo_root: Path)` from Task 1; source candidates/revision links from the committed research; current `frenchWords`, `frenchCurriculum.audioReferences`, `frenchAudioResources`, and `frenchCurriculumValidation` from the real Dart catalogue.
- Produces: the two approved version-1 JSON files, 24 unchanged WAVs and complete official licence texts; the guide is the rights/review handoff, not runtime configuration.
- Test-only Dart helper: `void expectFrenchAudioCandidateParity(Map<String, dynamic> manifest)` in `frontend/test/support/french_audio_candidate_checks.dart`. It uses flutter_test assertions against the actual imported catalogue, so invalid mutations fail with `TestFailure`; no runtime imports this helper. Python owns strict JSON/evidence/binary checks, avoiding a second implementation of that whole verifier in Dart.

- [ ] **Step 1: Write the failing real-package test.** In `french_audio_manifest_test.dart`, read `assets/audio/fr/manifest.json` using dart:io from the frontend workdir and pass decoded JSON to the parity helper. Start the helper with root candidate/version/language and exact entry order/count matching `frenchWords` and audio-reference IDs/text/kind. Step 8 adds the failing mapping/path/review mutations; Step 10 completes those checks. The initial test fails because the real manifest does not exist; do not skip it or add placeholder product entries.

```dart
test('real candidate package matches the authored catalogue', () {
  final manifest = jsonDecode(
    File('assets/audio/fr/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  expect(manifest['schemaVersion'], 1);
  expect(manifest['catalogueStatus'], 'candidate');
  expect(manifest['language'], 'fr');
  expectFrenchAudioCandidateParity(manifest);
});
```

- [ ] **Step 2: Run RED.** In `workdir: frontend`, run `/home/klottick/develop/flutter/bin/flutter test --no-pub test/unit/french_audio_manifest_test.dart`. Expect a missing candidate manifest failure after the test helper compiles; record it. If package setup is needed first, use the existing locked dependencies and verify lockfiles remain unchanged.

- [ ] **Step 3: Prepare source/rights evidence outside tracked asset paths.** Use a task-specific staging directory under `/tmp/opencode/`. Re-open each selected Commons description and original-media metadata; record actual audited revision, media timestamp, download URL, speaker, transcription, creator/credit, licence declaration and notices. Archive source responses in the local execution record for controller inspection. Investigate changes from research, incomplete metadata and redirects; do not substitute a source. Fetch only the selected original WAVs into staging to verify media hashes/version associations; do not edit them. Candidate selection is the exact 24 research filenames, not corpus search/download.

- [ ] **Step 4: Controller licensing gate before repository import.** Pause worker execution and present the 24-file evidence dossier. The controller independently checks linked source declarations/creators/notices, original-version associations, allowed redistribution/access terms, the 23 BY-SA / one BY split, and proposed attribution. Re-fetch primary evidence where needed and confirm staged bytes match available source SHA-1. Missing/ambiguous rights or unexpected replacements block import and return to the user for a source decision; no fake complete manifest or substitute recording. Record this review in the durable local ledger, separate from linguistic review. Resume the same worker only after this gate passes.

- [ ] **Step 5: Import originals and author metadata.** Copy approved unchanged bytes to `frontend/assets/audio/fr/words/<word>.wav`, preserving Unicode. Download complete official CC BY and CC BY-SA 4.0 plain-text legal codes into the specified licence files, checking content against official sources (not a summary deed). Author exact-schema manifest/provenance from inspected evidence and locally measured SHA-256/byteLength/`measure_wav` output. If actual audio is non-PCM or invalid, stop without converting. Record mapping origin as the full commit whose `frenchWords` was read and preserve current expected IPA/sounds; set every review/sign-off field exactly to the pending values. Investigate any size difference from research, without using 1,546,176 as a fixed binary oracle.

- [ ] **Step 6: Write the guide and per-file credits.** Include a 24-row table keyed by reference ID with creator attribution, linked Commons page/revision, exact licence link and unchanged-binary statement; credit all recorded creators, not just the source-named speaker. Link official licence texts and provenance. Explain that code is MIT and audio is separately CC-licensed; no audio native/accent/linguistic approval or platform playback approval is claimed. Document the exact verification commands, candidate format, non-registration and all deferred types/gates.

- [ ] **Step 7: Run initial GREEN.** Run `python3 scripts/verify_french_audio.py --repo-root .` from the root and the focused Flutter test from Step 2. Expect the technical/metadata-only PASS message and passing catalogue-parity test. Check actual source bytes against committed binaries independently; tool output alone is not the licensing gate.

- [ ] **Step 8: Add failing parity mutation tests.** Clone the loaded real manifest through JSON encode/decode so originals are unchanged. Each named mutation below must satisfy `expect(() => expectFrenchAudioCandidateParity(mutated), throwsA(isA<TestFailure>()))`; mutate exactly one condition per subcase.

| Test name | Mutations |
| --- | --- |
| `rejects coverage and reference drift` | Omitted/extra/duplicate/reordered entry; wrong spokenText/kind/id; ASCII or decomposed `île` |
| `rejects mapping drift` | Wrong expectedIpa; reordered phonemes; character-split `ɔ̃`/`ɑ̃`; incorrect/duplicated/out-of-order teachingTargets |
| `rejects candidate promotion` | Reviewed status, invented reviewer/date/evidence, speaker qualification/accent claim, nonempty changes |
| `rejects path identity drift` | Different word basename or ASCII `ile.wav`, even if a file with that path exists |

Also add `candidate package leaves production readiness unchanged`: after reading
the real package, assert every `frenchAudioResources` value is `practiceTts`,
`frenchCurriculumValidation.errors` is empty, and readiness has 35 items: six
`plannedNode`, five `plannedPhoneme`, 24 `missingReviewedAudio` (all assessment,
with exactly the actual reference IDs). Assert curriculum revision stays 1 and
the ten saved pilot IDs/order are unchanged using existing regression tests.

- [ ] **Step 9: Run RED for parity mutations.** Run the focused Flutter command and retain failures revealing missing mapping/path/review assertions. Identity assertions already covered by Step 1 may pass; the mutation suite must expose missing checks before implementing them.

- [ ] **Step 10: Complete the test-only parity helper.** In the support file only, add IPA/sounds equality with each current `CourseWord`, teachingTargets as the inventory-ordered intersection, exact repository-relative word paths, and spec-exact pending review/speaker/changes values. No code under `frontend/lib/` is edited to satisfy these tests.

- [ ] **Step 11: Run GREEN.** Repeat the focused Flutter command; expect all positive, mutation and unchanged-readiness tests passing with unmodified production source.

- [ ] **Step 12: Complete the reviewer/release checklist in the guide.** Provide a blank review worksheet keyed by ID/hash, with fields for actual reviewer qualification/name/date, exact-word/target mapping, citation form/accent/accepted variants, intelligibility/noise/clipping/volume/boundaries, decision and reasons. It must remain unfilled. Explain that future promotion needs genuine binary-specific sign-off and revised policy; assessment suitability and browser/iOS/Android playback remain separate decisions. Hand FR-03 candidate paths/hash/rights/format, asset registration/player responsibility, accurate in-app credits (existing generic CC BY-SA 3.0 is insufficient) and app-term/store/DRM checks. Record the unchanged MIT copyright provenance concern without attempting correction.

- [ ] **Step 13: Format the new Dart files.** In `workdir: frontend`, run `/home/klottick/develop/flutter/bin/dart format test/unit/french_audio_manifest_test.dart test/support/french_audio_candidate_checks.dart`. No other files may be formatted.

- [ ] **Step 14: Verify the complete task.** Run Task 1's unittest suite, the verifier and focused Flutter test; expect all passing. Inspect guide credits/evidence consistency, staged source-to-binary hash matches and untouched forbidden paths. Record actual results without implying linguistic/platform acceptance.

- [ ] **Step 15: Commit and report.** Stage only the Task 2 files and commit `feat: add licensed pending-review French word audio candidates`. Report source/rights inspection, RED/GREEN evidence, measurements, all pending gates and exact changed files; controller reviews/merges before final branch verification.

## Final controller verification and integration gate

- [ ] Re-run Python unittest discovery for both verifier and existing mobile configuration tests; expect exit 0.
- [ ] Run `python3 scripts/verify_french_audio.py --repo-root .`; expect 24 verified candidates with its explicit technical/metadata-only qualification.
- [ ] In `workdir: frontend`, run `/home/klottick/develop/flutter/bin/flutter test --no-pub` and `/home/klottick/develop/flutter/bin/flutter analyze --no-pub`; expect all tests passing and no issues. Do not describe this as browser/iOS/Android playback or linguistic validation.
- [ ] Independently compare each committed binary against approved staged source bytes/hash, read all 24 credits/evidence associations and compare both legal-code files against official sources. Re-check mapping-origin revision against the recorded Git source; inspect code/media licensing separation manually.
- [ ] Review the complete product diff against the approved base. Only the file-map paths may change; existing `frontend/lib/`, `pubspec.yaml`, lockfiles, root `LICENSE`, backend, settings/player/routes, legacy fixtures and saved progress remain untouched. Existing old-save/section tests and the new readiness guard must pass without weakening assertions.
- [ ] Obtain an independent whole-branch review, resolve findings with fresh verification, and record commands/exit codes and review decisions under `.superpowers/fr02/` plus concise actual verification results in the guide. No fabricated tests, reviewer sign-off or assessment-readiness claims.
- [ ] Present final slice results and outstanding linguistic/isolated/sentence/paragraph/playback/distribution gates. Confirm integration target/authorization with the user before publishing or merging; do not auto-publish local unpublished branches. Keep the full FR-02 ticket open for genuine reviewed-audio acceptance.

## Plan self-review and approval gate

Coverage: Task 1 implements strict schema, path/evidence/binary validation and
negative tests. Task 2 implements source/rights acquisition, unchanged assets,
actual-catalogue mappings, credits and pending-review handoff. Final controller
checks enforce no runtime/persistence/readiness changes and independent evidence.
All five Review Focus cases have assigned tests; source truth/licence completeness
remain explicit manual gates, not a misleading automated guarantee.

This plan has no asset-import or implementation approval yet. Ask the user to
review it and confirm it captures their intent, preserving the previously selected
sequential local-Qwen method. Only after that approval invoke the execution skill
and begin worktree setup/task dispatch.
