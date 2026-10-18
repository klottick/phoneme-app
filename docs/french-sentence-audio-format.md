# FR08 sentence-audio WAV and delivery format

**Scope:** offline preparation and verification for the unpublished FR08
sentence package. This is a binary-format and provenance contract, not a
content selection, pronunciation review, rights decision, or runtime-readiness
approval.

## Supported WAV inputs

`scripts/french_sentence_wav.py` is the shared standard-library-only RIFF/WAVE
boundary used by preparation and the read-only verifier. It accepts only
little-endian `RIFF`/`WAVE` with uncompressed integer PCM or IEEE float32:

| WAV format | `sampleEncoding` | Bits/sample | Bytes/sample |
| --- | --- | ---: | ---: |
| PCM, unsigned | `pcm-u8` | 8 | 1 |
| PCM, signed little-endian | `pcm-s16le` | 16 | 2 |
| PCM, signed little-endian | `pcm-s24le` | 24 | 3 |
| PCM, signed little-endian | `pcm-s32le` | 32 | 4 |
| IEEE float, little-endian | `ieee-float32le` | 32 | 4 |

A 16-byte `fmt ` header is accepted. The standard 18-byte form is also
accepted only when its `cbSize` is zero; this is the form used by the 15
selected originals preflighted for Task1D. Valid ancillary chunks such as
`fact` are skipped as metadata, including their required RIFF padding; they are
never counted as samples.

The reader bounds each file to 100 MiB and validates RIFF/chunk sizes and
padding, unique `fmt `/`data` chunks, positive channel count/sample rate,
format tag and bit depth, `blockAlign`, `byteRate`, and complete interleaved
frames. RF64, RIFX, WAVE_FORMAT_EXTENSIBLE, nonzero `fmt ` extensions,
compressed formats, float64, unsupported bit depths, missing/duplicate or
truncated chunks, incomplete frames, and malformed headers are rejected with
`SentencePackageError`. Float32 source samples must be finite and in `[-1,+1]`;
the reader never silently clips, normalizes, or treats float bit patterns as
integer PCM.

## Deterministic PCM16 delivery (`pcm16-v1`)

The untouched original is retained byte-for-byte. The delivered clip is
interleaved signed 16-bit little-endian PCM (`pcm-s16le`), with the source
sample rate, channel count, and authored half-open frame range unchanged. No
resampling, channel mixing, gain change, dither, or randomness is used.

For each normalized source sample `x`, quantize as:

```text
q = min(32767, max(-32768, round(x * 32768)))
```

`round` is nearest, ties-to-even. Integer PCM is normalized exactly by
`2^(bits-1)` after subtracting 128 from unsigned 8-bit samples. Therefore
signed 16-bit input is preserved exactly, while 8/24/32-bit integer and
float32 input is reproducibly quantized. `+1` maps to `32767`, `-1` to
`-32768`, and both signs of zero map to zero. For example, `3/65536` maps to
`2` (the `1.5` tie rounds to even), and `5/65536` maps to `2` (the `2.5` tie
also rounds to even). This conversion is not lossless; original bytes remain
available for future analysis or regeneration.

The preparation API remains backwards-compatible for existing integer users:

```python
crop_pcm(source, destination, start_frame, end_frame)
crop_pcm(source, destination, start_frame, end_frame,
         output_encoding="pcm-s16le")
```

The first form performs the former exact integer-sample crop and does not
convert. IEEE-float32 input requires the explicit second form. The CLI
equivalents are `crop --source ... --destination ... --start-frame ...
--end-frame ...` and the explicit `--output-encoding pcm-s16le` option. Crop
publication retains the existing atomic no-replace staging, descriptor/inode
checks, and guarded cleanup. Invalid input or an existing output leaves no
partial delivery and never changes the source.

`crop_pcm` returns `path`, `sha256`, `byteLength`, `frameCount`, `sampleRate`,
`channels`, `sampleWidth`, actual `sampleEncoding`, `durationSeconds`,
`startFrame`, and `endFrame`. Only an explicit PCM16 conversion adds
`conversionPolicy: "pcm16-v1"`; omitted output encoding never implies
conversion. The shared helper API is `read_wav(path) -> WavData`,
`parse_wav_bytes(raw) -> WavData`, and
`convert_to_pcm16(wav, start_frame, end_frame) -> bytes`. `WavData` exposes
`sample_encoding`, `sample_rate`, `channels`, `sample_width`, `frame_count`,
`frame_data`, `format_tag`, `bits_per_sample`, and `block_align`. The serialized
preflight JSON has exactly `sampleEncoding`, `sampleRate`, `channels`,
`frameCount`, and `supportedDeliveryPolicy`.

`preflight --source <wav>` is a read-only format check. It reports exactly
`sampleEncoding`, `sampleRate`, `channels`, `frameCount`, and
`supportedDeliveryPolicy` (`pcm16-v1`); it writes no audio. Preflight confirms
only that the header/samples fit this supported format and conversion policy.
It is not listening approval, a claim that a selected utterance is suitable,
or linguistic, legal, platform, accessibility, or release clearance.

## Schema 1 measurements and provenance

Both `provenance.json` measurement records (`original` and `clip`) require
`sampleEncoding`, describing the actual file bytes alongside `sampleWidth`,
`sampleRate`, `channels`, `frameCount`, `durationSeconds`, `byteLength`, and
SHA-256. `original` records the source's actual encoding; each delivered
sentence `clip` must actually be `pcm-s16le`, width 2, with the same rate and
channel count as its source and exactly `endFrame - startFrame` frames.

Every `derivation` requires `conversionPolicy: "pcm16-v1"`, ordered `settings`,
and a nonempty `changes` notice recording the crop and PCM16 conversion. These
fields are mandatory: consumers must not infer an encoding from width, alias a
missing field, or accept a caller-declared alternate algorithm. Settings are
preserved as provenance, not as an override of the documented policy.

The verifier checks the source file's actual format, bytes, measured metadata,
and hash, then independently checks the clip frame bytes against the policy
conversion of that exact source frame range. A self-consistent clip hash and
metadata cannot make an incorrect conversion valid. Original and derived
hashes remain distinct; reviews bind the original hash, delivered clip hash,
and final annotation hash. Any changed clip or crop invalidates existing
hash-bound review. Technical verification remains distinct from pending,
accepted/rejected human review and learner availability.

For Task2/Task3 consumers, the schema additions are exactly:

```json
{
  "original": {"sampleEncoding": "ieee-float32le"},
  "clip": {"sampleEncoding": "pcm-s16le"},
  "derivation": {"conversionPolicy": "pcm16-v1"}
}
```

The abbreviated object above illustrates the added required fields; it is not
a complete measurement or provenance record.

## Source and tool preflight before further selection/tooling

Before selecting source speech or running any new format-dependent tool,
perform the read-only WAV header/sample preflight for every selected original
and confirm the source hashes are unchanged. Separately confirm the already
pinned, locally extracted runtime/tool identities and loadability, the French
`fr-fr` voice, and the approved quiet IPA-only invocation. Do not download,
install, replace, or silently substitute dependencies. This quiet IPA check
must not produce synthesized speech. Passing either check does not authorize
listening, candidate selection, crop production, content promotion, or human
review.

## Task1D correction history

The earlier Task1A–1C synthetic integer-WAV tests did not validate the actual
selected source headers. The approved 2026-10-18 Task1D correction makes the
format and quantization contract explicit rather than claiming that those
earlier checks had covered real-source encoding. Task1D performs no production
crop/conversion and creates no sentence packet or review evidence. Its
read-only preflight found all 15 selected originals to be mono IEEE-float32le
at 16 kHz with standard zero-length `fmt ` extensions; their source hashes
remained unchanged. This compatibility finding is not audio review.
