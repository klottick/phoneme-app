# FR-02 — French word-audio candidates (pending review)

**Status: candidate package, linguistic review PENDING.** This document is the
rights/review handoff for the offline French word-audio candidate package. It
is **not** runtime configuration: the production app does not import or load
these artefacts, and no player, asset registration or catalogue loader exists
for them. Nothing here is linguistic sign-off, accent approval, or
browser/iOS/Android playback approval.

## What this package is

24 human-recorded French whole-word WAV candidates from Lingua Libre on
Wikimedia Commons, all source-named speaker **LoquaxFR** (a shared source name
is **not** an independently verified native-speaker, accent or pronunciation
qualification), mapped to the app's existing `fr-word-*` word references for
review by a qualified French reviewer against the **hashed binaries**.

- 23 words are declared **CC BY-SA 4.0**; `sans` is declared **CC BY 4.0**
  (the approved 2020 original of `mur` carries the uploader's explicit
  `{{cc-by-sa-4.0}}` grant — see the `mur` provenance note below).
- The complete official legal texts of both licences are retained in this
  package under `frontend/assets/audio/fr/licenses/` (`CC-BY-SA-4.0.txt`,
  `CC-BY-4.0.txt`), obtained from the official Creative Commons legal-code
  pages (retrieval records and extraction validation are archived with the
  task evidence).
- Every entry keeps `review.status: "pending"`, `reviewer: null`,
  `reviewedAt: null`, `evidence: []`, `speaker.qualificationStatus:
  "unverified"`, `speaker.accent: null`, `changes: []`.

## Per-file credits (keyed by reference ID)

All 24 files: credited creator **LoquaxFR** (speaker and recorder per the
Commons description), unchanged original bytes, no trimming, normalization,
conversion, repair or cropping.

| Reference ID | Creator credit (per file) | Source (audited description revision) | Licence (exact) and retained text | Unchanged binary (locally measured) |
| --- | --- | --- | --- | --- |
| fr-word-tout | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-tout.wav` | [audited revision 995917835](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-tout.wav&oldid=995917835) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 66,836 bytes, SHA-256 `ec761ca7114be7bb7178f380ff4e937763bbf934b0bd44d7366973394d61dec4` |
| fr-word-rouge | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-rouge.wav` | [audited revision 1284656035](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-rouge.wav&oldid=1284656035) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 88,364 bytes, SHA-256 `c4540087629c8034a58b7b4f6ca5354234c1dd492a5a8d74e0dc8bff6bf2bd40` |
| fr-word-vous | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-vous.wav` | [audited revision 1278768654](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-vous.wav&oldid=1278768654) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 41,324 bytes, SHA-256 `9027202be18f5a94dc116e887ace62385692cbbb3493a67da371427cb35d3cf4` |
| fr-word-doux | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-doux.wav` | [audited revision 1281359588](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-doux.wav&oldid=1281359588) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 36,972 bytes, SHA-256 `bf45923e17129f3d05c446062962e378840aa7e254fc908c21fdcd037b615b09` |
| fr-word-loup | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-loup.wav` | [audited revision 1279338035](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-loup.wav&oldid=1279338035) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 63,788 bytes, SHA-256 `62c67dece782ef8a4be248e10b5537db8fa51e9fc8c378a1c6784eb8d58b012e` |
| fr-word-soupe | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-soupe.wav` | [audited revision 1285345152](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-soupe.wav&oldid=1285345152) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 69,420 bytes, SHA-256 `9d850d99b78dd1c521e0512b9be8df85f798702ed8bda6bef3ea0417607ed495` |
| fr-word-tu | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-tu.wav` | [audited revision 1094009241](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-tu.wav&oldid=1094009241) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 66,836 bytes, SHA-256 `98f6aca710d17bc74b114e81b60b7d3e8ec8504b6073dbbe441af8df3a29020c` |
| fr-word-rue | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-rue.wav` | [audited revision 1166165910](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-rue.wav&oldid=1166165910) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 77,554 bytes, SHA-256 `be717dc3763ff96ad35852799bf77269740c2c851ac1daf696eaefbfd28ed20d` |
| fr-word-lune | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-lune.wav` | [audited revision 757831102](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-lune.wav&oldid=757831102) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 85,746 bytes, SHA-256 `9a7ef667189672b5ba2acb11dcb3b98449b958c0a535c85799309a225970e437` |
| fr-word-jus | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-jus.wav` | [audited revision 1185863234](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-jus.wav&oldid=1185863234) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 75,028 bytes, SHA-256 `27737f36cb89b05b59431bbf54426881e8f8e1cf786e54c551743cf9ed7a53df` |
| fr-word-mur | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-mur.wav` | [original upload revision <b>384728988</b> (approved 2020 original; later-page SDC conflict recorded, not resolved)](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-mur.wav&oldid=384728988) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 77,554 bytes, SHA-256 `c37f34379cce3c5245f1fe951d179f0f39c49fdf679f1cf83e4fd02e5f6a44ad` |
| fr-word-plume | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-plume.wav` | [audited revision 1280911696](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-plume.wav&oldid=1280911696) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 60,524 bytes, SHA-256 `767018eff1b9ec0e48546d71865e99d9d70670e94a5440d8314d16884aad1208` |
| fr-word-lit | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-lit.wav` | [audited revision 1279171160](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-lit.wav&oldid=1279171160) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 67,884 bytes, SHA-256 `41698332638a8540c2790a03dbbbfea871469a0d44b1dbe08825225fc918ab59` |
| fr-word-si | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-si.wav` | [audited revision 1128084534](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-si.wav&oldid=1128084534) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 75,028 bytes, SHA-256 `d9c5aff5fb44aed16963c68d1c7ebe49450c9e08c422f6affac76ca4c7870d7e` |
| fr-word-vite | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-vite.wav` | [audited revision 1284466369](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-vite.wav&oldid=1284466369) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 42,092 bytes, SHA-256 `5ae742cf467e17d6a5d183b1dd4b0b5a468df7e841b04486d9fe31de92216816` |
| fr-word-île | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-île.wav` | [audited revision 815828932](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-%C3%AEle.wav&oldid=815828932) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 69,362 bytes, SHA-256 `a7fed2bb2440a9980111cfe5c739e0abf722fc91b8de35be936d271f46f7f15a` |
| fr-word-beau | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-beau.wav` | [audited revision 1282497196](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-beau.wav&oldid=1282497196) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 57,196 bytes, SHA-256 `689c67d84da86eb932fed8e82c690951c44eda2c854962a943818b10a6cd2e21` |
| fr-word-mot | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-mot.wav` | [audited revision 758647723](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-mot.wav&oldid=758647723) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 77,554 bytes, SHA-256 `a478bb690e724b5bd98dbc9bbea80270231f78ebad08b523b11daddc02b36398` |
| fr-word-eau | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-eau.wav` | [audited revision 1280603339](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-eau.wav&oldid=1280603339) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 59,948 bytes, SHA-256 `7dfa03f4114a25322a881915a99ea2f0695727b045358e76396cba6373595f27` |
| fr-word-dos | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-dos.wav` | [audited revision 1252930601](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-dos.wav&oldid=1252930601) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 75,028 bytes, SHA-256 `e50683ee0d1de5e1c78cae14d9d7c7a8e61961ec2a2996a73a172c6df58e2d4c` |
| fr-word-bon | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-bon.wav` | [audited revision 1284656117](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-bon.wav&oldid=1284656117) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 54,892 bytes, SHA-256 `1f369b90c51e1696371ac3b9e59af96986b4e0bef4a531c19723c7c682d86aff` |
| fr-word-nom | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-nom.wav` | [audited revision 1279088536](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-nom.wav&oldid=1279088536) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 55,596 bytes, SHA-256 `a24dad922927a67621cc6a7feeeae6d0b047b2447e32922fd8e609a3d3ef60b1` |
| fr-word-banc | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-banc.wav` | [audited revision 1283505337](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-banc.wav&oldid=1283505337) | **CC BY-SA 4.0** [https://creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-SA-4.0.txt` | unchanged original — 48,748 bytes, SHA-256 `cac71e6ba32e78358fab63b5ee28d3ec467816395c1550aa8bf2117caf62d74f` |
| fr-word-sans | LoquaxFR (speaker and recorder) — `LL-Q150_(fra)-LoquaxFR-sans.wav` | [audited revision 1273911708](https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-sans.wav&oldid=1273911708) | **CC BY 4.0** [https://creativecommons.org/licenses/by/4.0](https://creativecommons.org/licenses/by/4.0/) — retained text: `frontend/assets/audio/fr/licenses/CC-BY-4.0.txt` | unchanged original — 69,932 bytes, SHA-256 `a053ac40269632413fd4d3fc288dc988febe07b06c137d9d848b889e1e795c24` |

`île` keeps its Unicode identity (`fr-word-île`, `words/île.wav`); no ASCII
replacement slug is used anywhere in this package.

### `mur` provenance note (approved recovery)

`mur` uses LoquaxFR's **2020-01-01T18:47:44Z original upload**
(description revision **384728988** — the page's first revision, authored by
LoquaxFR), whose wikitext license header is the explicit grant
`{{cc-by-sa-4.0}}` (word `mur`, speaker/author `LoquaxFR`, date 2020-01-01).
The current Commons description later shows conflicting structured data
(CC BY 4.0 / "dedicated to the public domain" items) and a 2026 replacement
recording; that later metadata conflict is **recorded, not resolved**, and is
not represented as a clean current-recording grant. A rendered historical
oldid page overlays **current** structured data and **current** media links;
it is not a snapshot of either. The package relies on the historical
original's explicit grant and its archived byte association (SHA-1
`14d1b1ee2a64653d1960c72c80dfe5ed621ff0b2`, SHA-256
`c37f3437…`, 77,554 bytes, archived original URL in
`provenance.json`). This is source provenance, **not an absolute rights
warranty**; no ownership or distribution guarantee beyond the stated licence
is claimed for any file, and none of these claims is a legal opinion.

### Four-byte RIFF-size header caveat (all 24 binaries)

All 24 originals arrived with their RIFF size field underdeclared by exactly
four bytes (the field holds `fileLength − 12` instead of `fileLength − 8`)
while the physical chunks are complete through end of file. The offline
verifier accepts **only this exact condition in these 24 selected,
SHA-256-pinned binaries**; it does not validate malformed WAVs generally.
Consequences you must carry into any future use:

- This is **not** a claim of standards-valid container framing and **not**
  device/player compatibility evidence.
- Python's ordinary WAV sample reader omits the final four PCM bytes when
  asked for samples; full-frame measurement here inspects the complete
  physical data chunk without rewriting the file.
- No repairing, trimming, converting or normalizing has been done, and no
  synthetic substitution exists. Browser/iOS/Android playback suitability
  remains a separate, unmet gate (owned by FR-03/release work).

## Verification (offline, read-only)

```sh
# from the repository root
python3 scripts/verify_french_audio.py --repo-root .

# focused Flutter catalogue-parity test
cd frontend
/home/klottick/develop/flutter/bin/flutter test --no-pub test/unit/french_audio_manifest_test.dart
```

Expected: the verifier prints
`PASS: 24 pending French word candidates verified (technical/metadata only)`
and the focused test passes. Actual run results are recorded in the task
process logs. A PASS means the package is internally consistent and meets the
technical/metadata rules — **not** that its licence assertions are true, not
that the speech is correct, and not playback approval. Manual per-file
evidence inspection remains an independent acceptance check.

## Candidate format and non-registration

- `frontend/assets/audio/fr/manifest.json` — `schemaVersion: 1`,
  `catalogueStatus: "candidate"`, `language: "fr"`, 24 ordered entries
  (coverage identity, mappings, speaker, licence, pending review).
- `frontend/assets/audio/fr/provenance.json` — one source/licence evidence
  record per word (page/revision, media timestamp, original URL, source SHA-1,
  creator, licence evidence, matching SHA-256).
- This schema version is independent of the app's persisted version or
  contentRevision, both unchanged.
- `AudioResourceStatus` remains `missing`/`practiceTts`/`reviewedRecording`;
  `frenchAudioResources` is **not** populated from this manifest, no entry is
  set to `reviewedRecording`, and all 35 production readiness items (including
  the 24 missing-reviewed word recordings) remain as they were.
- No `pubspec.yaml` registration, no player, no runtime catalogue loader, no
  new enum or public API; no product or tooling dependencies were added; the
  root `LICENSE` (MIT, and its recorded Supabase-notice provenance concern) is
  untouched.

## Remaining gaps (explicitly outstanding)

- Isolated `/u y i o ɔ̃ ɑ̃ ʁ/` exemplars remain missing; word-context
  membership does **not** fill those seven gaps.
- No approved sentence or paragraph catalogue texts exist for this course.
- Full FR-02 reviewed-audio delivery (linguistic sign-off on the hashed
  binaries, promotion policy revision, assessment suitability decision) is
  still outstanding.

## Review worksheet (BLANK — deliberately unfilled)

One row per binary. A qualified French reviewer listens to the **exact
binary shown** (hash match required), fills nothing here by proxy, and
records accept / reject / correction with reasons. Reviewer identity,
qualification, dates and decisions must come from an actual review — never be
invented by an implementer.

| Ref ID | SHA-256 (must match the reviewed binary) | Reviewer name | Qualification | Date | Exact word? | Target mapping correct? | Citation form / accent / accepted variant | Intelligibility | Noise | Clipping | Volume | Beginning/end boundaries | Decision | Reasons / evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fr-word-tout | `ec761ca7…` | | | | | | | | | | | | | |
| fr-word-rouge | `c4540087…` | | | | | | | | | | | | | |
| fr-word-vous | `9027202…` | | | | | | | | | | | | | |
| fr-word-doux | `bf45923…` | | | | | | | | | | | | | |
| fr-word-loup | `62c67de…` | | | | | | | | | | | | | |
| fr-word-soupe | `9d850d9…` | | | | | | | | | | | | | |
| fr-word-tu | `98f6aca…` | | | | | | | | | | | | | |
| fr-word-rue | `be717dc…` | | | | | | | | | | | | | |
| fr-word-lune | `9a7ef66…` | | | | | | | | | | | | | |
| fr-word-jus | `27737f3…` | | | | | | | | | | | | | |
| fr-word-mur | `c37f343…` | | | | | | | | | | | | | |
| fr-word-plume | `767018e…` | | | | | | | | | | | | | |
| fr-word-lit | `416983…` | | | | | | | | | | | | | |
| fr-word-si | `d9c5aff…` | | | | | | | | | | | | | |
| fr-word-vite | `5ae742c…` | | | | | | | | | | | | | |
| fr-word-île | `a7fed2b…` | | | | | | | | | | | | | |
| fr-word-beau | `689c67d…` | | | | | | | | | | | | | |
| fr-word-mot | `a478bb6…` | | | | | | | | | | | | | |
| fr-word-eau | `7dfa03f…` | | | | | | | | | | | | | |
| fr-word-dos | `e50683e…` | | | | | | | | | | | | | |
| fr-word-bon | `1f369b9…` | | | | | | | | | | | | | |
| fr-word-nom | `a24dad9…` | | | | | | | | | | | | | |
| fr-word-banc | `cac71e6…` | | | | | | | | | | | | | |
| fr-word-sans | `a053ac4…` | | | | | | | | | | | | | |

Promoting any entry to a reviewed runtime reference later requires: the
actual binary-specific sign-off above against its exact hash, a deliberate
revision of this slice's pending-only verifier policy, a separate
assessment-suitability decision, and real browser/iOS/Android playback
evidence. None of those has occurred.

## FR-03 / release handoff

FR-03 receives: these candidate IDs/paths/hashes/format and rights metadata,
this guide, and the explicit warning that the assets are **not approved
runtime references**. FR-03 (or release work) owns: a separately approved
loader/player contract, `pubspec.yaml` asset registration, **accurate
in-app credits** (the existing settings credits cite generic Wikipedia
audio under CC BY-SA 3.0 and are insufficient for this 4.0 package), real
playback checks on browser/iOS/Android, and app-terms/store/effective-DRM
checks for the audio's licensed reuse (do not presume shipping resolves DRMs).
It must not silently promote pending entries or clear readiness warnings on
import.

The app's code remains MIT under the root `LICENSE`; the audio is separately
licensed under the CC licences above. Do not relabel third-party audio MIT.
The existing root MIT notice naming Supabase (rather than the initial app
author) is a recorded provenance concern that remains **untouched** here;
audit it before any change.
