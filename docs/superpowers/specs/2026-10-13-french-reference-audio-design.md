# FR-02 — French word-audio candidates, pending linguistic review

## Intent and approval stage

Prepare a small, auditable human-recorded French word catalogue for the existing
pilot and supported games. The user prefers recordings with phoneme annotations
but accepts mapping untagged recordings. They accept CC BY-SA, require clear
licensing due diligence, retain MIT for the app, and choose **review pending**.

The user approved the conversational design: 24 Lingua Libre / LoquaxFR word
candidates, untouched original WAVs, per-file rights/provenance, explicit phoneme
mappings, technical verification and a reviewer checklist; no runtime changes.
The user approved this written specification at commit `82ee5fd` (“I approve”).
Asset acquisition, implementation and worker dispatch still wait for a reviewed
implementation plan and confirmation of the preserved execution method.

This is a preparatory slice of FR-02, not completion of its original reviewed-audio
acceptance criteria. Linguistic sign-off and platform playback validation remain
unmet; neither automated tests nor source metadata can supply them.

## Selected approach and boundaries

Use the 24 whole-word candidates identified in the
[source research](../research/2026-10-12-french-reference-audio-sources.md).
All identify LoquaxFR as the speaker. A shared source name is not independently
verified native-speaker, accent or pronunciation qualification.

Alternatives considered: SIWIS offers aligned phones and CC BY 4.0, but exact
word coverage and extraction suitability are unverified; transcript-only sentence
corpora add mapping work and do not establish one-speaker word coverage. Keep
these as future leads, not additional imports in this slice.

### In scope

- Acquire only the selected public original WAVs after per-file rights checks.
- Preserve each binary without trimming, normalization, conversion or cropping.
- Store an offline candidate manifest keyed to existing `fr-word-*` references.
- Preserve source transcription separately from expected app IPA and membership.
- Record exact licences, credits, retained notices and auditable source evidence.
- Measure binary hashes and WAV properties; validate coverage and integrity.
- Document pending linguistic review, missing reference types and FR-03 handoff.

### Not in scope

No `pubspec.yaml` registration, player, runtime catalogue loader, new enum or
public API, routes/screens, lesson edits, assessment enablement, TTS changes,
cloud storage/grading, microphone uploads, synthetic audio, dependencies,
accounts, purchases, corpus-scale downloads or multi-speaker expansion.
Do not modify the root `LICENSE` or its copyright header.

Isolated `/u y i o ɔ̃ ɑ̃ ʁ/` exemplars remain missing. Word-context membership
does not fill those seven gaps. Sentences/paragraphs require separately approved
texts and recordings; no such catalogue texts are currently authored.

## Files and dependency direction

| Artefact | Responsibility |
| --- | --- |
| `frontend/assets/audio/fr/words/<word>.wav` | Untouched selected original binaries |
| `frontend/assets/audio/fr/manifest.json` | Versioned offline candidate records |
| `frontend/assets/audio/fr/provenance.json` | Per-file source/licence evidence and retrieval record |
| `frontend/assets/audio/fr/licenses/` | Complete official texts of the exact accepted audio licences |
| `docs/french-reference-audio.md` | Human-readable credits, verification instructions, review checklist and handoff |
| `frontend/test/unit/french_audio_manifest_test.dart` | Offline manifest/catalogue identity and mapping checks |
| `scripts/verify_french_audio.py` and focused script tests | Offline binary/hash/WAV/provenance checks using the Python standard library |

Names retain Unicode: `words/île.wav` and `fr-word-île`, never a replacement ASCII
identity. Asset paths are repository-relative, under `frontend/assets/audio/fr/`.
The production app does not import or load these artefacts. Test and verification
tools may read them; tools must not rewrite the curated catalogue or manifest to
make a failing check pass. No new product or tooling dependencies are needed.

`CourseAudioReference` remains its frozen id/kind/spokenText declaration.
`AudioResourceStatus` remains `missing`, `practiceTts`, `reviewedRecording`;
do not add a pending runtime status. In particular, do not populate
`frenchAudioResources` from this manifest or change any entry to
`reviewedRecording`. The candidate format is not the final approved playback API.

## Catalogue and manifest contract

Use UTF-8 JSON with a root `schemaVersion: 1`, `catalogueStatus: "candidate"`,
`language: "fr"`, and an ordered `entries` list. This schema version is independent
of the app's persisted version/contentRevision, which stay unchanged.

Exactly these 24 words appear once, in current `frenchWords` order:

`tout, rouge, vous, doux, loup, soupe, tu, rue, lune, jus, mur, plume, lit, si,
vite, île, beau, mot, eau, dos, bon, nom, banc, sans`.

Each entry carries the following required fields; null values are allowed only
where explicitly stated below. Unknown fields and unsupported schema versions
are errors, rather than implicit production approval.

| Field | Meaning and constraint |
| --- | --- |
| `id`, `kind`, `spokenText` | Exact existing `fr-word-<word>`, `"word"`, and word text |
| `assetPath` | Unique relative WAV path inside the asset directory; no absolute paths, traversal or symlinks |
| `sha256`, `byteLength` | Locally measured lowercase 64-hex SHA-256 and positive binary byte count |
| `audio` | WAV `container: "wav"`, `encoding: "pcm"`, positive integer `sampleRateHz`, `channels`, `bitsPerSample`, `frameCount`, and positive numeric `durationSeconds` |
| `mapping` | `expectedIpa`, ordered `phonemes`, ordered `teachingTargets`, and `origin` as specified below |
| `speaker` | Source-named `sourceName: "LoquaxFR"`; `qualificationStatus: "unverified"`; `accent: null` |
| `license` | Exact `spdxId`, `url`, `textPath`, human-readable `attribution`, and retained `notices` list |
| `provenanceId` | Same ID as the corresponding source-evidence record |
| `changes` | Empty list: original bytes are unchanged |
| `review` | `status: "pending"`, `reviewer: null`, `reviewedAt: null`, `evidence: []` |

All nested objects have only the fields listed in this contract. Text fields are
nonempty strings unless specified as null; lists contain strings unless specified
as records. Numeric fields exclude booleans and non-finite values. `license.url`
is `https://creativecommons.org/licenses/by-sa/4.0/` for `CC-BY-SA-4.0`, or
`https://creativecommons.org/licenses/by/4.0/` for `CC-BY-4.0`. The former applies
to the 23 words other than `sans`; the latter applies to `sans`. `textPath` follows
the same path-safety rules and resolves to the appropriate licence text under
the package's `licenses/` directory. Empty notices are valid only if none were
supplied by the source. `audio` duration
equals frameCount / sampleRateHz within 1 microsecond; sample width must be an
integral number of bytes. A parseable PCM file is technical evidence only, not
browser/mobile codec compatibility or acceptable pronunciation.

`mapping.expectedIpa` exactly matches the current `CourseWord.ipa` string without
slash decoration. `phonemes` matches its ordered `sounds` list; do not split the
IPA string into Unicode characters, which would break nasal-vowel symbols.
`teachingTargets` is the intersection with `u, y, i, o, ɔ̃, ɑ̃, ʁ`, ordered by that
teaching inventory. `mapping.origin` records
`path: "frontend/lib/src/core/course/french_course.dart"`,
`symbol: "frenchWords"`, the full Git `revision` read for the mapping, and
`status: "existingCuratedNotRecordingReviewed"`.
These are expected lexical mappings, not observed/timed phones. No automatic
alignment or phoneme-time intervals are invented. A recording mismatch goes to
the reviewer queue; it does not silently change the app's answer keys.

## Licensing and binary provenance

The research identified **23 CC BY-SA 4.0** candidates and **`sans` under CC BY
4.0**. Verify those licences again for the selected file versions; never assume
all Lingua Libre or Wikipedia files share one licence. A different licence,
creator, transcription, speaker or unexplained replacement requires reporting
and a source decision before importing that candidate.

`provenance.json` contains `schemaVersion: 1` and ordered `entries`. Each entry
has `id`, `sourcePageUrl`, `sourceTitle`, `descriptionRevisionId`,
`descriptionRevisionUrl`, `retrievedAt` (UTC ISO 8601), `originalDownloadUrl`,
`mediaTimestamp`, `sourceSha1` (nullable if unavailable), `sourceTranscription`,
`sourceSpeaker`, `creditedCreators` (nonempty list), `licenseEvidence`, and
`sha256` (matching the manifest). `licenseEvidence` records `spdxId`, `url`,
`creditText`, `notices`, and the exact source licence declaration as `declaration`.
Retain a concise faithful extraction, not an invented declaration or a database
badge treated as sufficient evidence. Match it to the linked description revision.

Evidence IDs/order, transcription, source speaker, hashes, licence IDs/URLs,
credit text and notices must agree with their manifest counterparts. The
description revision ID is a positive integer; mediaTimestamp is UTC ISO 8601;
sourceSha1 is lowercase 40-hex when available. URLs identify the audited Commons
page/revision and original Wikimedia media, not merely the source's home page.

Pin the binary independently: a Commons description revision does not pin media
bytes. Record the media-version timestamp and actual original download URL, and
compute local SHA-256, size and WAV properties. If a source SHA-1 is available,
compare it against the downloaded bytes. Investigate discrepancies, redirects to
unexpected sources or incomplete responses; do not copy stale source properties
as measurements. Use public HTTPS source links; no account or payment is needed.

Before a binary is added to git, confirm licence/creator provenance is consistent
with the selected file and permits redistribution, and preserve all required
credit, licence links, copyright and other supplied notices. Ambiguous ownership
or access/distribution terms block import. Record limitations; do not claim an
absolute rights guarantee merely because a file is on Commons.

Include official CC BY 4.0 and CC BY-SA 4.0 licence texts with source URLs. The
guide lists credits for every reference (shared credits may be grouped only if
their per-file associations and the `sans` exception stay clear). Audio remains
separately licensed, not MIT. No new rights in speaker identity are claimed.

The unchanged recordings remain freely reusable under their source licences.
Future substantive adaptations need a new changes/provenance record and applicable
share-alike treatment. Before app distribution, FR-03/release work must check app
terms, stores and effective DRM for restrictions on the audio's licensed reuse.
Do not presume shipping elsewhere resolves those restrictions automatically.

The existing root MIT notice names Supabase rather than the initial app author;
that provenance concern is recorded but untouched. Existing settings credits cite
generic Wikipedia CC BY-SA 3.0: they are not credits for this 4.0 package. Runtime
credit corrections are a documented FR-03/release handoff, not a change here.

## Acquisition, failures and offline verification

### Approved recovery amendment (2026-10-13)

After acquisition exposed contradictory current `mur` structured licensing data
and a uniform four-byte RIFF-size defect, the user approved this bounded recovery:

- Select LoquaxFR's **2020-01-01T18:47:44Z `mur` original**, not its 2026
  replacement. Original upload description revision **384728988** explicitly
  names LoquaxFR and declares `CC-BY-SA-4.0`; preserve that original wikitext grant
  and its association with the archived binary. Historical rendered pages can
  include current structured data and current media links; they do not freeze
  either of those. Record the later metadata conflict rather than hiding it.
- Its archived original URL is
  `https://upload.wikimedia.org/wikipedia/commons/archive/7/79/20261007075226%21LL-Q150_%28fra%29-LoquaxFR-mur.wav`.
  The archive-name prefix identifies the replacement event, not the old recording
  timestamp. Its source/local SHA-1 is
  `14d1b1ee2a64653d1960c72c80dfe5ed621ff0b2`; measured SHA-256 is
  `c37f34379cce3c5245f1fe951d179f0f39c49fdf679f1cf83e4fd02e5f6a44ad`;
  byte count is **77,554**. No other source/version substitution is authorized.
- Retain all original bytes. The offline verifier may accept **only the exact
  four-byte RIFF-size omission in these 24 selected, SHA-256-pinned binaries**
  (23 staged current originals plus this old `mur`, excluding current `mur`).
  All physical chunk bounds, complete PCM frames, format, hashes and other
  corruption checks remain enforced. Unknown hashes cannot obtain this exception.
  This does not turn malformed WAVs generally into valid references.
- Document that Python's ordinary WAV sample reader omits the final four PCM
  bytes of these originals; successful header parsing is not complete playback.
  Full-frame measurement must inspect the physical data chunk without rewriting
  the file. Browser/iOS/Android playback suitability remains a separate gate.

The selected measured total is now **1,563,206 bytes**, 17,030 above the research
estimate because of the approved `mur` version switch. Public signatures, schema,
pending linguistic statuses, unchanged-production constraints, independent
controller import review and the final integration gate remain unchanged.

After implementation approval, check source evidence, acquire each selected
original, compute measurements, author manifest/provenance/credits, then verify
the complete package offline. Do not publish an apparently complete catalogue
with missing or placeholder entries. Report blocked words explicitly if an import
gate cannot be met; do not substitute another speaker, TTS or a cropped corpus clip.
The source-listed total of 1,546,176 bytes is an estimate, not a fixed acceptance
oracle for downloaded bytes; any difference needs investigation.

Offline checks must fail clearly on malformed JSON, duplicate JSON keys/IDs/paths,
unknown schema/fields, wrong types, absent required evidence or credits, invalid
licences, unsafe paths, missing/unlisted WAVs, corrupt/truncated or unsupported
audio, zero frames, mismatched hashes/size/properties, and catalogue/mapping drift.
Validate all 24 records against the actual Dart catalogue and declared audio
reference text, not merely a duplicated 24-word fixture. Network requests are
not part of tests; source availability must not make CI flaky.

Use negative fixtures for duplicates, missing coverage/files, tampered bytes,
invalid headers, path escape, incorrect licences/mappings and a forged reviewed
status. A passing verifier means the package is internally consistent and meets
technical/metadata rules, not that its licence assertions or speech are true.
Manual per-file evidence inspection remains an independent acceptance check.

Keep verification read-only with respect to production. Run the existing frontend
tests and analyzer to detect regressions. Confirm no product changes, asset
registration, dependency changes, persisted identity/contentRevision changes, or
readiness changes: current baseline has zero structural errors and 35 readiness
issues (including 24 missing reviewed word recordings). Preserve unpublished
Sound Match work and local branches; do not incidentally publish them.

## Linguistic review and FR-03 handoff

Every entry stays pending with no reviewer or sign-off date. The guide supplies
a checklist for a later qualified French reviewer to listen to the **hashed
binary**, verify exact word/pronunciation and target membership, assess citation
form/accent and accepted variants, intelligibility, clipping, noise, volume and
beginning/end boundaries, and record accept/reject/correction evidence.
Correctly parsing a WAV does not clear any of these checks. Reviewer identity,
qualification, date, hash and decisions must be supplied by actual review, never
fabricated by an implementer. Reviewer assignment is intentionally deferred by
the user's pending-review choice, not a missing field to fill with a guess.

Later approval of a reviewed catalogue and its runtime contract is required
before promotion to `reviewedRecording`. Assessment suitability needs its own
explicit decision. This slice's verifier rejects any non-pending review status;
future review/promotion work must deliberately revise that policy.

FR-03 receives candidate ID/path/hash/format/rights metadata and the guide, with
an explicit warning that these assets are **not approved runtime references**.
It owns a separately approved loader/player contract, asset registration,
accurate in-app credits and real browser/iOS/Android playback checks; it must not
silently promote pending entries or clear readiness warnings on import.

## Acceptance of this preparatory slice

1. All 24 selected unchanged binaries have clear, inspected licensing evidence,
   accurate attribution and binary-version pins; unclear rights block delivery.
2. The manifest/provenance pair covers exact current references and expected
   mappings with all linguistic statuses pending and no invented qualifications.
3. Offline integrity, structure, catalogue parity and negative-fixture tests pass;
   verification instructions and actual results are recorded.
4. The guide includes per-file credits, a usable review checklist, remaining gaps
   and the FR-03/release handoff; code/media licensing stays distinct.
5. Production behavior, progress, TTS, APIs, readiness and unpublished work remain
   unchanged. Full FR-02 reviewed-audio delivery is explicitly still outstanding.

## Written-spec review gate

Written-spec review is complete. The implementation plan must now be reviewed
and its execution method confirmed before implementation.
Retain the existing preference for sequential local-Qwen implementers with
controller review and independent verification, subject to that plan review.
