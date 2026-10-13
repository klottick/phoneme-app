# FR-02: human French recording sources

Research date: 2026-10-12. **Research findings, not an approved implementation
specification, imported asset catalogue, or linguistic sign-off.**

## Brief and recommendation

User direction: research human recordings; prefer a database already tagged with
phonemes, but French recordings that we can map to phonemes are acceptable.
Preserve the FR-02 small-catalogue scope and FR-03 playback boundary.

**SIWIS is the strongest verified phoneme-aligned lead. Lingua Libre is the
strongest immediately identified source for the existing 24 isolated words.**
Recommend considering Lingua Libre's single-speaker word set for the first
catalogue, with SIWIS shortlisted for later approved sentence/context references.
This is a proposed approach, not approval to expand into a two-speaker library.
No corpus supplies an app-reviewed reference merely by including an annotation.

### User-approved licence policy

The user accepts CC BY-SA assets and explicitly requires clear licensing due
diligence. This settles licence-category acceptability, not individual-file
approval. For each selected binary, verify source/creator provenance, original
licence and notices, required credit, changes and applicable distribution terms;
retain auditable evidence and hashes. Unclear rights block import. Do not relabel
third-party audio MIT merely because the app declares MIT.

The repository has a tracked root `LICENSE` containing MIT terms, also declared
in `README.md`. Its current notice names “2021 Supabase, Inc. and contributors”.
History shows the initial notice named “2026 Kadan Lottick” (`20ed710`) and was
replaced in `329592a` without changing MIT terms. Audit that attribution's
provenance before changing or removing notices; no licence-file change has been
made. Existing settings credits cite generic Wikipedia audio under CC BY-SA 3.0;
future 4.0 imports need accurate asset-specific credits and an explicit distinction
between the app's MIT code and separately licensed media.

### Review mode selected

The user chose to proceed with **review pending**, retaining MIT for the app.
The next proposed slice is the 24-word candidate package, not a linguistically
approved reference catalogue. Pending candidates must remain separate from the
production resource declaration; importing them cannot set `reviewedRecording`,
clear missing-reviewed-audio readiness warnings, or enable assessment use.
The user subsequently approved the conversational candidate-package design;
the [written spec](../specs/2026-10-13-french-reference-audio-design.md) was approved
at `82ee5fd`. The [implementation plan](../plans/2026-10-13-french-reference-audio.md)
is now for review. Implementation-plan approval remains required before
asset import or product/test implementation. The original FR-02
linguistic-sign-off gate is deferred explicitly, not waived or represented as met.

Assumption for comparison: keep redistribution and possible commercial use open;
do not depend on noncommercial/research-only permissions. This is not a legal
opinion. Source licence, applicable access terms, and intended distribution must
be checked for each imported file.

## Comparison

| Source | Human recordings and annotations | Rights/access evidence | Fit and cost |
| --- | --- | --- | --- |
| [SIWIS][siwis] | 9,750 utterances, over ten hours, professional French voice talent. Aligned HTS labels for parts 1–3; transcript files. Parts 1–4 share the main speaker; part 5 is another speaker. | Official repository README and [end-user licence][siwis-license] explicitly specify CC BY 4.0. Official archive is 2.67 GB. | Best phoneme-indexed lead. Mostly connected utterances, not a demonstrated 24-word citation set. Label decoding, boundary and pronunciation review required. |
| [Lingua Libre / Commons][ll-example] | Individual word recordings, language/transcription/speaker metadata. Wiktionary provides separate dictionary IPA/context information, not verified per-recording phone timing. | Per-file licence; our 24 LoquaxFR candidates list 23 CC BY-SA 4.0 and one CC BY 4.0. Public file pages expose original WAV links without a new account. | All 24 existing words identified for one named speaker; approximately 1.55 MB by source metadata. No sentence cropping necessary. Phoneme mappings still require review against the actual recordings. |
| [SynPaFlex][synpa-paper] | 87h23m of French audiobooks, one amateur reader; automatically aligned French SAMPA phones, boundaries, words and syllables. | Primary paper describes LibriVox origins. [Project corpus site][synpa-site] could not be reached during this research; current corpus/annotation licence not verified. A secondary list claims CC BY 2.0, which is not sufficient import evidence. | Good tagged alternative, but access/rights unresolved. Expressive character voices and uneven recording conditions make neutral beginner references harder to curate. |
| [FLEURS][fleurs] | French `fr_fr` human read-speech recordings with orthographic transcripts; standard fields do not include phone labels or timings. Audio feature uses 16 kHz. | Google's dataset card specifies CC BY 4.0 in its metadata. | Useful sentence fallback if texts fit an approved lesson. Requires phonetic annotation and acoustic review; does not establish one-speaker word coverage. |
| [Common Voice][cv] | Crowdsourced French sentence recordings and text; not a native phoneme-aligned catalogue. Multiple speakers/conditions. | Mozilla lists French scripted speech under CC0-1.0. Current MDC access requires an account and acceptance of dataset/platform terms. [May 2026 terms][mdc-terms] include redistribution restrictions that require clarification for app bundling. | Reserve, not first choice: transcript mapping, variable recording quality and access-term questions add work. Do not treat a CC0 badge alone as authorization to redistribute a current MDC download. |
| [Freesound IPA packs][fs-pack] | Human IPA demonstration recordings tagged by phonetic symbol; not established as French-specific exemplars. | One inspected vowel file, [640335][fs-example], explicitly lists CC0; downloading requires login. Other files need their own checks. | Possible isolated-sound leads only. Generic IPA is not proof of the intended French realization, native speaker, nasal-vowel coverage or matching voice. |

### Important annotation caveats

- SIWIS's [official README][siwis-readme] reports `[s]` in *c'est* often labelled
  `[k]`, and incomplete emphasis marking. These are annotation errors, **not**
  evidence that the speaker pronounces *c'est* with /k/. Parts 4–5 lack labels.
- SynPaFlex's paper reports 6.1% phoneme error rate and 11.4 ms mean alignment
  error on its 35m52s validation subset. It specifically mentions schwa deletion
  and /e–ɛ/, /o–ɔ/ substitutions. These figures do not validate selected clips.
- No per-phoneme tag should be inferred from French spelling alone. Corpus phone
  codes, dictionary phonemes, actual phonetic realizations and teaching-target
  membership are different records; retain their origins and review status.
- Extracting a phone from connected speech does not produce a pedagogically
  valid isolated-sound recording automatically. Coarticulation, liaison, vowel
  reduction and cut boundaries can make a segment unsuitable.

## Verified word-candidate metadata

Method: inspect all 24 English Wiktionary French sections for audio file links,
then fetch each selected Commons file page. All 24 pages returned HTTP 200 and
listed French, the exact word transcription, speaker LoquaxFR, an audio/WAV
original link and the licence below. LoquaxFR covered 24/24 in that link audit;
Poslovitch and WikiLucas00 each covered 23/24. This is not exhaustive source-wide
speaker coverage and not a pronunciation-quality ranking.

Filename pattern: `LL-Q150_(fra)-LoquaxFR-<word>.wav` (Commons titles display
underscores as spaces). Each linked revision preserves the audited description;
**a page revision is not a pinned audio-binary revision**. Pin the downloaded
binary and its hash separately if an import is later approved.

Expected IPA below comes from the current app's curated `frenchWords`, not from
listening to these files. The existing reference ID is `fr-word-<word>`; keep the
Unicode `île` identity rather than replacing it with an ASCII filename slug.

| Word / reference suffix | App's expected IPA | Commons description revision | Source-listed bytes | Licence |
| --- | --- | --- | ---: | --- |
| tout | /tu/ | [995917835](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-tout.wav&oldid=995917835) | 66836 | CC BY-SA 4.0 |
| rouge | /ʁuʒ/ | [1284656035](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-rouge.wav&oldid=1284656035) | 88364 | CC BY-SA 4.0 |
| vous | /vu/ | [1278768654](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-vous.wav&oldid=1278768654) | 41324 | CC BY-SA 4.0 |
| doux | /du/ | [1281359588](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-doux.wav&oldid=1281359588) | 36972 | CC BY-SA 4.0 |
| loup | /lu/ | [1279338035](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-loup.wav&oldid=1279338035) | 63788 | CC BY-SA 4.0 |
| soupe | /sup/ | [1285345152](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-soupe.wav&oldid=1285345152) | 69420 | CC BY-SA 4.0 |
| tu | /ty/ | [1094009241](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-tu.wav&oldid=1094009241) | 66836 | CC BY-SA 4.0 |
| rue | /ʁy/ | [1166165910](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-rue.wav&oldid=1166165910) | 77554 | CC BY-SA 4.0 |
| lune | /lyn/ | [757831102](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-lune.wav&oldid=757831102) | 85746 | CC BY-SA 4.0 |
| jus | /ʒy/ | [1185863234](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-jus.wav&oldid=1185863234) | 75028 | CC BY-SA 4.0 |
| mur | /myʁ/ | [1284027183](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-mur.wav&oldid=1284027183) | 60524 | CC BY-SA 4.0 |
| plume | /plym/ | [1280911696](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-plume.wav&oldid=1280911696) | 60524 | CC BY-SA 4.0 |
| lit | /li/ | [1279171160](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-lit.wav&oldid=1279171160) | 67884 | CC BY-SA 4.0 |
| si | /si/ | [1128084534](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-si.wav&oldid=1128084534) | 75028 | CC BY-SA 4.0 |
| vite | /vit/ | [1284466369](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-vite.wav&oldid=1284466369) | 42092 | CC BY-SA 4.0 |
| île | /il/ | [815828932](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-%C3%AEle.wav&oldid=815828932) | 69362 | CC BY-SA 4.0 |
| beau | /bo/ | [1282497196](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-beau.wav&oldid=1282497196) | 57196 | CC BY-SA 4.0 |
| mot | /mo/ | [758647723](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-mot.wav&oldid=758647723) | 77554 | CC BY-SA 4.0 |
| eau | /o/ | [1280603339](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-eau.wav&oldid=1280603339) | 59948 | CC BY-SA 4.0 |
| dos | /do/ | [1252930601](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-dos.wav&oldid=1252930601) | 75028 | CC BY-SA 4.0 |
| bon | /bɔ̃/ | [1284656117](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-bon.wav&oldid=1284656117) | 54892 | CC BY-SA 4.0 |
| nom | /nɔ̃/ | [1279088536](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-nom.wav&oldid=1279088536) | 55596 | CC BY-SA 4.0 |
| banc | /bɑ̃/ | [1283505337](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-banc.wav&oldid=1283505337) | 48748 | CC BY-SA 4.0 |
| sans | /sɑ̃/ | [1273911708](https://commons.wikimedia.org/w/index.php?title=File:LL-Q150_(fra)-LoquaxFR-sans.wav&oldid=1273911708) | 69932 | CC BY 4.0 |

Total listed size: **1,546,176 bytes**. These values were read from source metadata,
not measured from downloaded WAVs. Some source structured durations/checksums
were absent or potentially stale; do not copy them into a production manifest
without measuring the selected binary. No audio files have been imported or
listened to for this audit; no codec/playback, native-speaker or accent sign-off
is claimed. Dictionary location labels are leads, not app review evidence.

## Mapping untagged recordings

[Lexique][lexique] is a useful **text-only mapping resource**, not an audio corpus:
140,000 French words with phonological representations and other lexical data;
the current site links CC BY-SA 4.0. Wiktionary pronunciation entries are another
lead. Neither proves the actual phones in a selected recording.

For a small word catalogue, start from the app's curated IPA and target membership,
check lexical references where needed, then have a qualified French reviewer
listen to the selected binary and confirm the mapping and acceptable realization.
Retain the original source transcription/phone encoding separately from the
reviewed teaching mapping. Do not require automatic forced-alignment tooling just
to tag 24 whole-word clips. Larger sentence corpora can use existing alignments
as candidate annotations, with selected boundaries and phone codes checked.

Isolated `/u y i o ɔ̃ ɑ̃ ʁ/` exemplars need separate sourcing and approval. The
24 words cover those teaching targets **in word context**, not seven isolated
recordings. No accepted sentence/paragraph texts exist in the current catalogue;
do not quietly substitute corpus sentences or claim that part of FR-02 complete.

## Approaches for the next design discussion

1. **Small isolated-word set first (recommended for current product):** consider
   the 24 LoquaxFR candidates, preserve file-specific credit/licences, and review
   mapping/quality before release. One source-named speaker, minimal processing.
   Tradeoff: no timed phone annotations and share-alike obligations on adaptations
   of 23 files; other reference types remain explicit gaps.
2. **Phoneme-indexed corpus first:** audit SIWIS's texts/labels for suitable
   examples using the main voice. CC BY avoids share-alike, and supplied alignments
   support lookup. Tradeoff: exact word coverage is unverified, connected speech
   may not yield good citation/isolated clips, and processing/review cost is higher.
3. **Transcript-only sentence corpus plus mapping:** use FLEURS if its texts
   match an approved lesson, annotate/review the selected material. Tradeoff:
   more annotation work and no established single-speaker coverage. Common Voice
   stays a reserve until its current access/distribution terms are resolved.

Before import/release: verify individual licences under the accepted policy; settle qualified French-review
ownership; approve scope/design/plan; pin original and derived files with hashes,
source and recording provenance, speaker/known accent, credited authors, rights,
edits, mapping provenance and reviewer sign-off; verify audio technical properties
and downstream playback. CC BY-SA permits reuse with conditions; adaptations
require the same or a compatible licence. Do not assume this automatically
relicenses the entire app, or that platform/store packaging always complies.

No product code, asset registration, playback, dependencies, recording uploads,
synthetic audio, purchases, account creation or corpus-scale downloads performed.

[siwis]: https://datashare.ed.ac.uk/handle/10283/2353
[siwis-readme]: https://datashare.ed.ac.uk/bitstreams/a15e775d-abd6-496f-815b-68d3a9229e90/download
[siwis-license]: https://datashare.ed.ac.uk/bitstreams/d7204860-2dc9-48e6-bb9a-604a3a49d9ce/download
[ll-example]: https://commons.wikimedia.org/wiki/File:LL-Q150_(fra)-LoquaxFR-tout.wav
[synpa-paper]: https://aclanthology.org/L18-1677/
[synpa-site]: https://synpaflex.irisa.fr/corpus/
[fleurs]: https://huggingface.co/datasets/google/fleurs
[cv]: https://mozilladatacollective.com/organization/cmfh0j9o10006ns07jq45h7xk
[mdc-terms]: https://mozilladatacollective.com/terms/consumers
[fs-pack]: https://freesound.org/people/ipapronunciations/packs/35567/
[fs-example]: https://freesound.org/people/ipapronunciations/sounds/640335/
[lexique]: https://www.lexique.org/?lang=en
