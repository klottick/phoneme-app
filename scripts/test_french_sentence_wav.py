import io
import math
import struct
import tempfile
import unittest
import wave
from pathlib import Path

from french_sentence_package import SentencePackageError
from french_sentence_wav import (
    convert_to_pcm16,
    parse_wav_bytes,
    read_wav,
    write_pcm16_wav,
    write_wav,
)


def _chunk(name, payload, pad=True):
    result = name + struct.pack("<I", len(payload)) + payload
    if pad and len(payload) & 1:
        result += b"\0"
    return result


def _fmt(tag=1, channels=1, rate=8000, bits=16, *, byte_rate=None,
         block_align=None, payload_size=16):
    width = (bits + 7) // 8
    body = struct.pack(
        "<HHIIHH", tag, channels, rate,
        rate * channels * width if byte_rate is None else byte_rate,
        channels * width if block_align is None else block_align,
        bits,
    )
    return body + bytes(max(0, payload_size - len(body)))


def _riff(chunks, *, size=None, magic=b"RIFF"):
    body = b"WAVE" + b"".join(chunks)
    return magic + struct.pack("<I", len(body) if size is None else size) + body


def _wav(tag, bits, samples, channels=1, rate=8000, *, ancillary=False):
    width = bits // 8
    frames = b"".join(int(sample).to_bytes(width, "little", signed=bits != 8)
                      for sample in samples) if tag == 1 else struct.pack(
                          "<" + ("f" if bits == 32 else "d") * len(samples), *samples)
    chunks = [_chunk(b"fmt ", _fmt(tag, channels, rate, bits))]
    if ancillary:
        chunks.extend((_chunk(b"JUNK", b"x"), _chunk(b"fact", struct.pack("<I", len(samples) // channels))))
    chunks.append(_chunk(b"data", frames))
    return _riff(chunks)


class FrenchSentenceWavTests(unittest.TestCase):
    def test_reader_identifies_supported_integer_and_float_encodings(self):
        cases = (
            (_wav(1, 8, [0, 128, 255]), "pcm-u8", 1, 3),
            (_wav(1, 16, [-32768, 0, 32767], channels=1), "pcm-s16le", 2, 3),
            (_wav(1, 24, [-8388608, 0, 8388607]), "pcm-s24le", 3, 3),
            (_wav(1, 32, [-2147483648, 0, 2147483647]), "pcm-s32le", 4, 3),
            (_wav(3, 32, [-1.0, 0.0, 1.0]), "ieee-float32le", 4, 3),
        )
        for raw, encoding, width, count in cases:
            with self.subTest(encoding=encoding):
                parsed = parse_wav_bytes(raw)
                self.assertEqual((parsed.sample_encoding, parsed.sample_width,
                                  parsed.frame_count), (encoding, width, count))

    def test_reader_skips_odd_padded_and_fact_ancillary_chunks(self):
        raw = _wav(3, 32, [-0.5, 0.5], channels=2, ancillary=True)
        parsed = parse_wav_bytes(raw)
        self.assertEqual((parsed.channels, parsed.frame_count, parsed.sample_rate),
                         (2, 1, 8000))
        self.assertEqual(parsed.frame_data, struct.pack("<ff", -0.5, 0.5))

    def test_writer_pads_odd_sized_pcm_data_chunks(self):
        raw = write_wav(b"\x80", sample_rate=8000, channels=1,
                        sample_encoding="pcm-u8")
        self.assertEqual(raw[-1:], b"\0")
        parsed = parse_wav_bytes(raw)
        self.assertEqual((parsed.sample_encoding, parsed.frame_count,
                          parsed.frame_data), ("pcm-u8", 1, b"\x80"))

    def test_reader_accepts_zero_length_format_extension_but_rejects_extended_fields(self):
        fmt18 = _fmt(3, bits=32) + struct.pack("<H", 0)
        raw = _riff([_chunk(b"fmt ", fmt18),
                     _chunk(b"fact", struct.pack("<I", 1)),
                     _chunk(b"data", struct.pack("<f", 0.5))])
        try:
            parsed = parse_wav_bytes(raw)
        except SentencePackageError as exc:
            self.fail(f"standard zero-length fmt extension was rejected: {exc}")
        self.assertEqual(parsed.sample_encoding, "ieee-float32le")
        self.assertEqual(parsed.frame_data, struct.pack("<f", 0.5))
        extended_fmt = _fmt(3, bits=32) + struct.pack("<H", 2) + b"\x00\x00"
        with self.assertRaisesRegex(SentencePackageError, "fmt extension"):
            parse_wav_bytes(_riff([_chunk(b"fmt ", extended_fmt),
                                   _chunk(b"data", struct.pack("<f", 0.5))]))

    def test_reader_rejects_unsupported_containers_encodings_and_bit_depths(self):
        good = _chunk(b"fmt ", _fmt()) + _chunk(b"data", b"\0\0")
        cases = (
            (b"RF64", _riff([_chunk(b"fmt ", _fmt()), _chunk(b"data", b"\0\0")], magic=b"RF64")),
            (b"RIFX", _riff([_chunk(b"fmt ", _fmt()), _chunk(b"data", b"\0\0")], magic=b"RIFX")),
            (b"WAVE_FORMAT_EXTENSIBLE", _riff([_chunk(b"fmt ", _fmt(0xFFFE)), _chunk(b"data", b"\0\0")])),
            (b"compressed", _riff([_chunk(b"fmt ", _fmt(6)), _chunk(b"data", b"\0\0")])),
            (b"float64", _riff([_chunk(b"fmt ", _fmt(3, bits=64)), _chunk(b"data", struct.pack("<d", 0.5))])),
            (b"bad integer depth", _riff([_chunk(b"fmt ", _fmt(1, bits=12)), _chunk(b"data", b"\0\0")])),
        )
        for name, raw in cases:
            with self.subTest(name=name):
                with self.assertRaises(SentencePackageError):
                    parse_wav_bytes(raw)

    def test_reader_rejects_duplicate_required_chunks_and_missing_required_chunks(self):
        fmt = _chunk(b"fmt ", _fmt())
        data = _chunk(b"data", b"\0\0")
        cases = (
            _riff([fmt, fmt, data]),
            _riff([fmt, data, data]),
            _riff([data]),
            _riff([fmt]),
        )
        for raw in cases:
            with self.subTest(length=len(raw)):
                with self.assertRaises(SentencePackageError):
                    parse_wav_bytes(raw)

    def test_reader_rejects_truncated_chunks_bad_padding_sizes_and_frame_alignment(self):
        fmt = _chunk(b"fmt ", _fmt())
        data = _chunk(b"data", b"\0\0")
        odd_data = b"data" + struct.pack("<I", 1) + b"\x80"
        odd_without_pad = b"RIFF" + struct.pack("<I", 4 + len(fmt) + len(odd_data)) + b"WAVE" + fmt + odd_data
        cases = (
            _riff([fmt, data])[:-1],
            _riff([fmt, b"JUNK" + struct.pack("<I", 100) + b"x"]),
            odd_without_pad,
            _riff([fmt, _chunk(b"data", b"\0")]),
            _riff([fmt, data], size=len(_riff([fmt, data])) - 9),
            _riff([_chunk(b"fmt ", _fmt(channels=0)), data]),
            _riff([_chunk(b"fmt ", _fmt(rate=0)), data]),
            _riff([_chunk(b"fmt ", _fmt(byte_rate=1)), data]),
            _riff([_chunk(b"fmt ", _fmt(block_align=1)), data]),
            _riff([_chunk(b"fmt ", _fmt(channels=2)), _chunk(b"data", b"\0\0")]),
        )
        for index, raw in enumerate(cases):
            with self.subTest(case=index):
                with self.assertRaises(SentencePackageError):
                    parse_wav_bytes(raw)

    def test_reader_enforces_bounded_bytes_and_file_reads(self):
        raw = _wav(1, 16, [1, 2])
        with self.assertRaisesRegex(SentencePackageError, "limit"):
            parse_wav_bytes(raw, max_bytes=len(raw) - 1)
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "large.wav"
            path.write_bytes(raw)
            with self.assertRaisesRegex(SentencePackageError, "limit"):
                read_wav(path, max_bytes=len(raw) - 1)

    def test_float_source_rejects_nonfinite_and_out_of_range_samples(self):
        for sample in (math.nan, math.inf, -math.inf, 1.00001, -1.00001):
            with self.subTest(sample=sample):
                with self.assertRaisesRegex(SentencePackageError, "finite|range|[-]1"):
                    parse_wav_bytes(_wav(3, 32, [sample]))

    def test_pcm16_v1_matches_independent_integer_golden_vectors(self):
        cases = (
            (_wav(1, 8, [0, 1, 127, 128, 129, 255]),
             [-32768, -32512, -256, 0, 256, 32512]),
            (_wav(1, 16, [-32768, -32767, -1, 0, 1, 32767]),
             [-32768, -32767, -1, 0, 1, 32767]),
            (_wav(1, 24, [-8388608, -384, -128, 0, 128, 384, 640, 8388607]),
             [-32768, -2, 0, 0, 0, 2, 2, 32767]),
            (_wav(1, 32, [-2147483648, -196608, -65536, 32768, 98304,
                          163840, 2147483647]),
             [-32768, -3, -1, 0, 2, 2, 32767]),
        )
        for raw, expected in cases:
            parsed = parse_wav_bytes(raw)
            actual = convert_to_pcm16(parsed, 0, parsed.frame_count)
            wanted = b"".join(struct.pack("<h", sample) for sample in expected)
            self.assertEqual(actual, wanted)

    def test_pcm16_v1_float_golden_ties_endpoints_and_negative_zero(self):
        samples = [-1.0, 1.0, 1 / 65536, 3 / 65536, 5 / 65536,
                   -1 / 65536, -3 / 65536, -5 / 65536, -0.0]
        raw = _wav(3, 32, samples)
        original = parse_wav_bytes(raw)
        before = original.frame_data
        actual = convert_to_pcm16(original, 0, len(samples))
        expected = [-32768, 32767, 0, 2, 2, 0, -2, -2, 0]
        self.assertEqual(actual, b"".join(struct.pack("<h", value) for value in expected))
        self.assertEqual(original.frame_data, before)

    def test_pcm16_conversion_preserves_frame_and_channel_order_for_off_boundary_crop(self):
        raw = _wav(3, 32, [-1.0, 0.25, -0.5, 0.5, 1.0, 0.0], channels=2)
        parsed = parse_wav_bytes(raw)
        cropped = convert_to_pcm16(parsed, 1, 3)
        self.assertEqual(cropped, struct.pack("<hhhh", -16384, 16384, 32767, 0))
        result = write_pcm16_wav(cropped, sample_rate=parsed.sample_rate,
                                 channels=parsed.channels)
        with wave.open(io.BytesIO(result), "rb") as output:
            self.assertEqual((output.getnframes(), output.getnchannels(),
                              output.getframerate(), output.getsampwidth()),
                             (2, 2, 8000, 2))
            self.assertEqual(output.readframes(2), cropped)

    def test_pcm16_conversion_rejects_invalid_half_open_ranges(self):
        parsed = parse_wav_bytes(_wav(1, 16, [1, 2]))
        for start, end in ((-1, 1), (0, 0), (1, 1), (0, 3), (False, 1), (0, 1.0)):
            with self.subTest(start=start, end=end):
                with self.assertRaises(SentencePackageError):
                    convert_to_pcm16(parsed, start, end)


if __name__ == "__main__":
    unittest.main()
