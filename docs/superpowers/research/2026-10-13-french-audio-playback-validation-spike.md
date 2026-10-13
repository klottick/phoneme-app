# French reference audio: playback spike and validation tools

## Outcome and scope

**The 24 unchanged candidates decoded completely in the tested Chromium build.**
Both HTML audio and Web Audio reached software playback completion for all 24.
This does **not** establish human audibility, French correctness, mobile playback,
standards-valid WAV headers or assessment readiness.

The user approved a temporary playback probe, followed by validation-tool research.
The source package is published PR [#21](https://github.com/klottick/phoneme-app/pull/21),
baseline `3e28a0f8a5313acfa61a5a2c2d5bf64bae75231f`. Measurements and research were
performed on 2026-10-13. Only this findings document is retained in the product
repository; the probe code is explicitly throwaway, not a player implementation.
No runtime, asset registration, manifest, review status, source bytes or dependency
changed. No recordings were uploaded, and no ASR/scoring models were downloaded.
All linguistic fields remain pending under [the candidate guide](../../french-reference-audio.md).

## Environment and method

- Linux x86-64; Python 3.14.4; Node 24.21.0; cached Chromium
  **Chrome/156.0.8078.4**, revision `f842f52ef39fd97b449eb27cff414bf05a98ddce`.
  This is a headless build, not a general stable-browser compatibility claim.
- The normal Playwright browser failed before loading audio because the host
  cannot provide its Chromium sandbox. The user explicitly permitted a temporary
  sandbox-disabled local run. Host/browser-tool configuration was not changed.
- A localhost-only server exposed the probe page, manifest and selected WAVs.
  Page requests were restricted to its loopback origin using CDP interception;
  other hostnames were blocked by resolver rules. No external page requests were
  observed in the successful run. Browser and server processes were stopped afterward.
- Python independently read the physical PCM chunk, checked source SHA-256,
  format/chunk bounds and frame counts, and measured levels without rewriting.
- Browser-side SHA-256 checked each fetched original against the manifest.
  `OfflineAudioContext` decoding used each file's original 44.1/48 kHz rate to
  avoid mistaking resampling for lost source frames. Every recovered integer PCM
  sample and PCM SHA-256 matched the independent physical oracle.
- Offline rendering reproduced the decoded float samples exactly. Real click
  events then exercised HTML audio and a running Web Audio context sequentially;
  both reached `ended` without timeouts or errors. HTML duration differed from
  physical duration by less than one microsecond. Live Web Audio resamples to its
  context rate; its frame count is not a source-rate identity oracle.
- Output was muted. Completion events and offline rendering do not prove sound
  reached a physical speaker, nor that a listener heard the expected word.

### Sample normalization and controls

The first comparison assumed every signed PCM16 sample divides by 32768.
That produced small positive-sample differences, **not missing frames**. Synthetic
controls showed Chromium's endpoint normalization: negative samples use 32768,
positive samples use 32767, with float rounding. Recovering the original signed
integer samples from this mapping yielded exact PCM hashes for all 24 originals.
This comparison did not edit or normalize a source file.

Unmistakably synthetic controls, never product reference audio:

| Control | Physical/declared frames | Browser frames | Result |
| --- | --- | --- | --- |
| Normally framed PCM16 WAV | 16 / 16 | 16 | Nonzero final two samples preserved |
| Same PCM with the selected four-byte RIFF-size omission | 16 / 16 | 16 | All samples identical to normal control, including nonzero tail |
| Actual final four PCM bytes removed, data size still claiming 16 frames | 14 / 16 | 14 | Decoder accepted a shortened signal rather than rejecting it |

**Playback success alone is not an integrity test.** Keep the strict package
verifier/hash pins ahead of any eventual reference playback. Python's ordinary
`wave.readframes` still returns two fewer PCM16 frames in every selected original;
successful header parsing must not be used as evidence of complete sample reads.

## Per-file technical results

All rows had matching original SHA-256 and recovered PCM SHA-256, zero missing
browser frames, unchanged source bytes, and completion in both playback paths.
Levels below use raw physical samples divided by 32768; whole-file RMS includes
silence and is not perceptual loudness or an SNR measurement.

| Word | Source Hz | Physical frames | Browser frames | Peak dBFS | RMS dBFS |
| --- | --- | --- | --- | --- | --- |
| tout | 44100 | 33396 | 33396 | -5.62 | -23.69 |
| rouge | 48000 | 44160 | 44160 | -7.24 | -22.57 |
| vous | 48000 | 20640 | 20640 | -11.81 | -27.51 |
| doux | 48000 | 18464 | 18464 | -14.28 | -29.36 |
| loup | 48000 | 31872 | 31872 | -9.13 | -25.52 |
| soupe | 48000 | 34688 | 34688 | -10.91 | -32.01 |
| tu | 44100 | 33396 | 33396 | -13.20 | -34.02 |
| rue | 44100 | 38755 | 38755 | -7.22 | -25.70 |
| lune | 44100 | 42851 | 42851 | -3.42 | -21.54 |
| jus | 44100 | 37492 | 37492 | -7.48 | -25.79 |
| mur | 44100 | 38755 | 38755 | -6.11 | -21.48 |
| plume | 48000 | 30240 | 30240 | -9.58 | -25.80 |
| lit | 48000 | 33920 | 33920 | -8.51 | -26.41 |
| si | 44100 | 37492 | 37492 | -13.24 | -31.71 |
| vite | 48000 | 21024 | 21024 | -11.98 | -31.02 |
| île | 44100 | 34659 | 34659 | -6.89 | -22.51 |
| beau | 48000 | 28576 | 28576 | -7.79 | -22.42 |
| mot | 44100 | 38755 | 38755 | -2.08 | -19.49 |
| eau | 48000 | 29952 | 29952 | -11.93 | -29.07 |
| dos | 44100 | 37492 | 37492 | -12.12 | -30.01 |
| bon | 48000 | 27424 | 27424 | -8.64 | -26.98 |
| nom | 48000 | 27776 | 27776 | -9.91 | -28.46 |
| banc | 48000 | 24352 | 24352 | -5.21 | -24.74 |
| sans | 48000 | 34944 | 34944 | -5.86 | -26.80 |

No samples hit either exact PCM16 rail (-32768 or 32767); this does not prove
there is no clipping, distortion or background noise below full scale. The
whole-file RMS spread is about 14.53 dB and merits reviewer attention to perceived
volume. This spike authorizes no trimming, repair, conversion or normalization.

### Untested platforms and limitations

- No iOS runtime/device (`xcrun` unavailable) or Android device/emulator (`adb`
  unavailable) was present. Neither native platform passed or failed this probe.
- Firefox, Safari/WebKit, actual mobile browsers, speaker output, interruption,
  navigation cancellation and the app's eventual plugin/player were not tested.
- `ffmpeg`, `ffprobe`, SoX and Praat were not available on PATH. A cached
  Playwright FFmpeg exists, but its build enables video/image codecs only, not
  WAV/PCM decoding; it is not an independent audio-decoder validation result.

## Tools for validation: availability is not validation

The following tools were researched from primary documentation after the spike.
They were **not installed, run on the candidates or benchmarked here**. Existing
technical measurements above come from the throwaway probe, not these tools.

| Tool | Useful role | French/privacy fit | Limit before acceptance |
| --- | --- | --- | --- |
| [Praat](https://www.fon.hum.uva.nl/praat/) | Reviewer listening, waveform/spectrogram inspection, formants, pitch/intensity and TextGrid annotation | Language-independent local analysis; no audio upload required; standalone GPLv3-or-later tool | Best first choice with a qualified French reviewer. Formant tracking/settings and acceptable variants need expert interpretation; it does not certify pronunciation automatically. Verify complete loading of these nonstandard WAVs first. |
| [Parselmouth](https://parselmouth.readthedocs.io/en/stable/) | Batch/scripted access to Praat analyses | Local Python interface to Praat; GPLv3-or-later | Optional later automation, not a new app dependency. Check supported Python/Praat versions and sample fidelity; automatic measurements are not human sign-off. |
| [Montreal Forced Aligner](https://montreal-forced-aligner.readthedocs.io/en/latest/user_guide/index.html) | Proposed word/phone timing labels and corpus/dictionary diagnostics | Local execution after obtaining suitable models/dictionaries; French `french_mfa` v3.0.0 acoustic-model metadata declares CC BY 4.0 | Forced alignment conditions on supplied text and lexicon; a plausible alignment is not independent evidence the expected phoneme was pronounced correctly. Check phone-set compatibility and separate dictionary/model licences; any analysis-only resampling needs a separate approved workflow. |
| [OpenPronounce](https://github.com/Halleck45/OpenPronounce) | Experimental phoneme recognition/comparison and pronunciation-score research | Maintainer documents experimental French support and local CPU operation; package declares MIT, underlying models/components require separate review | Only English is calibrated against human ratings. French reuses English thresholds/weights; short words can produce false alarms. Default gTTS requires network access; do not run that path under the local-only policy. Model downloads and an isolated benchmark need separate approval. Never use its score as FR-02 sign-off or learner grading. |
| [Whisper](https://github.com/openai/whisper) | Optional coarse spoken-text mismatch triage | Multilingual ASR can run locally with downloaded weights; code/weights declared MIT | ASR transcription is not phoneme validation, native/accent qualification or pronunciation scoring. Its model card warns of hallucinated text and uneven language/accent performance; short isolated words are not a proven validation domain here. |
| Full FFmpeg/ffprobe or SoX | Independent decoding, sample counts and technical level checks | Local file processing | Technical checks only, not French linguistic validation. No full installation or run occurred; do not confuse the restricted cached video build with these tools. |

OpenPronounce's README documents two approximately 1.2 GB Wav2Vec2 checkpoints
on first use, plus other dependencies/reference-voice requirements. That is an
optional future tooling experiment, not a reason to add models to the app or
download them silently. Disable network-dependent reference generation and audit
actual dependency/model access before any approved offline benchmark.

Cloud scoring demos were not used: they would violate the current no-recording-
upload boundary and do not supply trusted binary-specific reviewer sign-off.

## Recommended next step

1. Use a qualified French reviewer with **Praat** for exact-word/citation-form,
   `/u/`–`/y/`, nasal vowels, `/ʁ/`, intelligibility, boundaries and level review.
   Populate full hashes in the worksheet before collecting sign-off; retain
   reviewer identity/qualification, date, accepted variants and reasons separately.
   First check that the chosen review tool reads every physical sample unchanged.
2. If timing annotations help, evaluate MFA later as an assistive labeler, not a
   grader. Keep generated timing hypotheses separate from observed/reviewed phones.
3. Treat OpenPronounce as a possible **separate local research benchmark**, not
   an acceptance shortcut. French reviewer-labelled positive/negative examples
   and measured false-accept/reject behavior are prerequisites for trusting scores.
4. Design FR-03 only after its playback/error/cancellation and candidate-vs-reviewed
   policy are approved. This spike is not implementation approval; native-device
   playback, assessment suitability and release/licensing gates remain outstanding.

## Evidence and reproducibility

Temporary code: `/tmp/opencode/fr03-playback-spike/{physical_probe.py,server.py,probe.html,browser_probe.mjs}`.
The browser run required the separately approved sandbox exception; do not assume
that exception carries forward to another run or production.

Observed commands (all successful final runs exit 0):

```sh
python3 -B /tmp/opencode/fr03-playback-spike/physical_probe.py
python3 -B -u /tmp/opencode/fr03-playback-spike/server.py
node /tmp/opencode/fr03-playback-spike/browser_probe.mjs
```

The server is a temporary long-running process, not a passing test; it was stopped
with SIGTERM after testing. Earlier browser setup failures were recorded, not
counted as audio failures. Raw browser results, independent PCM oracle, before/
after hash checks, synthetic-control outputs, throwaway source snapshots and
primary-document retrieval timestamps/hashes are retained locally under
`.superpowers/fr03-playback-spike/`. The findings and per-file table above are the
durable handoff; local ignored evidence is not a new runtime verification service.

Primary sources inspected on 2026-10-13:

- [Web Audio decoding/resampling](https://developer.mozilla.org/en-US/docs/Web/API/BaseAudioContext/decodeAudioData)
- [Praat functionality](https://www.fon.hum.uva.nl/praat/) and [licence](https://www.fon.hum.uva.nl/praat/manual/License.html)
- [Parselmouth documentation](https://parselmouth.readthedocs.io/en/stable/) and [licence declaration](https://github.com/YannickJadoul/Parselmouth#license)
- [MFA alignment concepts](https://montreal-forced-aligner.readthedocs.io/en/latest/user_guide/index.html) and [French model metadata](https://github.com/MontrealCorpusTools/mfa-models/blob/main/acoustic/french/mfa/v3.0.0/meta.json)
- [OpenPronounce README: French/calibration/privacy limits](https://github.com/Halleck45/OpenPronounce#limitations)
- [Whisper model card: evaluated use and limitations](https://github.com/openai/whisper/blob/main/model-card.md)
