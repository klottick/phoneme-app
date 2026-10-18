"""Small, strict, standard-library RIFF/WAVE boundary for FR08 sentence audio."""

from dataclasses import dataclass
import math
from pathlib import Path
import struct

from french_sentence_package import SentencePackageError


MAX_WAV_BYTES = 100 * 1024 * 1024
PCM16_POLICY = "pcm16-v1"
PCM16_ENCODING = "pcm-s16le"


@dataclass(frozen=True)
class WavData:
    """Validated frame data and actual encoding from one bounded RIFF/WAVE file."""

    sample_encoding: str
    sample_rate: int
    channels: int
    sample_width: int
    frame_count: int
    frame_data: bytes
    format_tag: int
    bits_per_sample: int
    block_align: int


def parse_wav_bytes(raw, max_bytes=MAX_WAV_BYTES):
    """Parse supported RIFF/WAVE PCM or IEEE-float bytes without reinterpretation."""
    if isinstance(max_bytes, bool) or not isinstance(max_bytes, int) or max_bytes <= 0:
        raise SentencePackageError("WAV byte limit must be a positive integer")
    if not isinstance(raw, (bytes, bytearray, memoryview)):
        raise SentencePackageError("WAV input must be bytes")
    if len(raw) > max_bytes:
        raise SentencePackageError(f"WAV exceeds {max_bytes} byte input limit")
    raw = bytes(raw)
    if len(raw) < 12:
        raise SentencePackageError("truncated RIFF/WAVE header")
    container = raw[:4]
    if container == b"RF64":
        raise SentencePackageError("unsupported RF64 WAV container")
    if container == b"RIFX":
        raise SentencePackageError("unsupported big-endian RIFX WAV container")
    if container != b"RIFF":
        raise SentencePackageError("unsupported WAV container; expected little-endian RIFF")
    if raw[8:12] != b"WAVE":
        raise SentencePackageError("RIFF form is not WAVE")

    declared_riff_size = struct.unpack_from("<I", raw, 4)[0]
    declared_file_size = declared_riff_size + 8
    if declared_file_size > max_bytes:
        raise SentencePackageError(f"RIFF exceeds {max_bytes} byte input limit")
    if declared_riff_size < 4 or declared_file_size != len(raw):
        raise SentencePackageError("RIFF size does not match the complete WAV file")

    position = 12
    fmt = None
    frame_data = None
    while position < declared_file_size:
        if declared_file_size - position < 8:
            raise SentencePackageError("truncated WAV chunk header")
        chunk_id = raw[position:position + 4]
        chunk_size = struct.unpack_from("<I", raw, position + 4)[0]
        chunk_start = position + 8
        chunk_end = chunk_start + chunk_size
        padded_end = chunk_end + (chunk_size & 1)
        if chunk_end > declared_file_size or padded_end > declared_file_size:
            raise SentencePackageError("truncated WAV chunk payload or padding")
        payload = raw[chunk_start:chunk_end]
        if chunk_id == b"fmt ":
            if fmt is not None:
                raise SentencePackageError("duplicate WAV fmt chunk")
            fmt = payload
        elif chunk_id == b"data":
            if frame_data is not None:
                raise SentencePackageError("duplicate WAV data chunk")
            frame_data = payload
        # Other well-formed chunks, including fact, are ancillary metadata.
        position = padded_end

    if fmt is None:
        raise SentencePackageError("WAV is missing required fmt chunk")
    if frame_data is None:
        raise SentencePackageError("WAV is missing required data chunk")
    if len(fmt) < 16:
        raise SentencePackageError("truncated WAV fmt chunk header")
    format_tag, channels, sample_rate, byte_rate, block_align, bits = struct.unpack_from(
        "<HHIIHH", fmt)
    if format_tag == 0xFFFE:
        raise SentencePackageError("unsupported WAVE_FORMAT_EXTENSIBLE encoding")
    if len(fmt) >= 18:
        extension_size = struct.unpack_from("<H", fmt, 16)[0]
        if extension_size != 0:
            raise SentencePackageError("unsupported WAV fmt extension; only cbSize=0 is supported")
        if len(fmt) != 18:
            raise SentencePackageError("unsupported WAV fmt chunk trailing extension bytes")
    elif len(fmt) != 16:
        raise SentencePackageError("unsupported WAV fmt chunk; only 16-byte headers and cbSize=0 extensions are supported")

    if channels <= 0:
        raise SentencePackageError("WAV channel count must be positive")
    if sample_rate <= 0:
        raise SentencePackageError("WAV sample rate must be positive")
    if format_tag == 1:
        encodings = {
            8: ("pcm-u8", 1),
            16: ("pcm-s16le", 2),
            24: ("pcm-s24le", 3),
            32: ("pcm-s32le", 4),
        }
        if bits not in encodings:
            raise SentencePackageError(f"unsupported integer PCM bit depth: {bits}")
        sample_encoding, sample_width = encodings[bits]
    elif format_tag == 3:
        if bits != 32:
            raise SentencePackageError(f"unsupported IEEE-float WAV bit depth: {bits}; only float32 is supported")
        sample_encoding, sample_width = "ieee-float32le", 4
    else:
        raise SentencePackageError(f"unsupported or compressed WAV format tag: {format_tag}")

    expected_block_align = channels * sample_width
    if expected_block_align > 0xFFFF or block_align != expected_block_align:
        raise SentencePackageError("WAV blockAlign is inconsistent with channels and sample width")
    expected_byte_rate = sample_rate * expected_block_align
    if expected_byte_rate > 0xFFFFFFFF or byte_rate != expected_byte_rate:
        raise SentencePackageError("WAV byteRate is inconsistent with sample rate and blockAlign")
    if len(frame_data) % block_align:
        raise SentencePackageError("WAV data does not contain complete interleaved frames")
    frame_count = len(frame_data) // block_align
    if frame_count <= 0:
        raise SentencePackageError("WAV data must contain at least one complete frame")

    if sample_encoding == "ieee-float32le":
        for (sample,) in struct.iter_unpack("<f", frame_data):
            if not math.isfinite(sample):
                raise SentencePackageError("IEEE-float32 WAV samples must be finite")
            if sample < -1.0 or sample > 1.0:
                raise SentencePackageError("IEEE-float32 WAV samples must be within [-1, +1]")

    return WavData(
        sample_encoding=sample_encoding,
        sample_rate=sample_rate,
        channels=channels,
        sample_width=sample_width,
        frame_count=frame_count,
        frame_data=frame_data,
        format_tag=format_tag,
        bits_per_sample=bits,
        block_align=block_align,
    )


def read_wav(path, max_bytes=MAX_WAV_BYTES):
    """Read and parse one WAV without reading beyond the caller's size bound."""
    if isinstance(max_bytes, bool) or not isinstance(max_bytes, int) or max_bytes <= 0:
        raise SentencePackageError("WAV byte limit must be a positive integer")
    try:
        with Path(path).open("rb") as stream:
            raw = stream.read(max_bytes + 1)
    except OSError as exc:
        raise SentencePackageError(f"cannot read WAV source: {exc.strerror or type(exc).__name__}") from exc
    return parse_wav_bytes(raw, max_bytes=max_bytes)


def convert_to_pcm16(wav, start_frame, end_frame):
    """Convert a validated source half-open frame range under deterministic pcm16-v1."""
    if not isinstance(wav, WavData):
        raise SentencePackageError("PCM16 conversion requires validated WavData")
    if any(isinstance(value, bool) or not isinstance(value, int)
           for value in (start_frame, end_frame)):
        raise SentencePackageError("crop offsets must be integers")
    if start_frame < 0 or end_frame <= start_frame or end_frame > wav.frame_count:
        raise SentencePackageError("crop range must be a valid nonempty half-open frame range")

    first_sample = start_frame * wav.channels
    final_sample = end_frame * wav.channels
    output = bytearray((final_sample - first_sample) * 2)
    output_offset = 0
    for sample_index in range(first_sample, final_sample):
        byte_offset = sample_index * wav.sample_width
        if wav.sample_encoding == "ieee-float32le":
            value = struct.unpack_from("<f", wav.frame_data, byte_offset)[0]
        elif wav.sample_encoding == "pcm-u8":
            value = (wav.frame_data[byte_offset] - 128) / 128
        else:
            integer = int.from_bytes(
                wav.frame_data[byte_offset:byte_offset + wav.sample_width],
                "little", signed=True)
            value = integer / (1 << (wav.bits_per_sample - 1))
        quantized = min(32767, max(-32768, round(value * 32768)))
        struct.pack_into("<h", output, output_offset, quantized)
        output_offset += 2
    return bytes(output)


def write_wav(frame_data, sample_rate, channels, sample_encoding):
    """Return a canonical 44-byte-header WAV for a supported interleaved encoding."""
    if not isinstance(frame_data, (bytes, bytearray, memoryview)):
        raise SentencePackageError("WAV output frame data must be bytes")
    if any(isinstance(value, bool) or not isinstance(value, int) or value <= 0
           for value in (sample_rate, channels)):
        raise SentencePackageError("WAV output sample rate and channels must be positive integers")
    encodings = {
        "pcm-u8": (1, 8, 1),
        "pcm-s16le": (1, 16, 2),
        "pcm-s24le": (1, 24, 3),
        "pcm-s32le": (1, 32, 4),
        "ieee-float32le": (3, 32, 4),
    }
    try:
        format_tag, bits_per_sample, sample_width = encodings[sample_encoding]
    except (KeyError, TypeError) as exc:
        raise SentencePackageError(f"unsupported WAV output encoding: {sample_encoding!r}") from exc
    frame_data = bytes(frame_data)
    block_align = channels * sample_width
    if not frame_data or len(frame_data) % block_align:
        raise SentencePackageError("WAV output must contain complete nonempty interleaved frames")
    byte_rate = sample_rate * block_align
    padding = len(frame_data) & 1
    riff_size = 36 + len(frame_data) + padding
    if byte_rate > 0xFFFFFFFF or riff_size > 0xFFFFFFFF:
        raise SentencePackageError("WAV output exceeds RIFF/WAVE size limits")
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF", riff_size, b"WAVE", b"fmt ", 16, format_tag, channels,
        sample_rate, byte_rate, block_align, bits_per_sample, b"data", len(frame_data),
    )
    return header + frame_data + (b"\0" if padding else b"")


def write_pcm16_wav(frame_data, sample_rate, channels):
    """Return a canonical 44-byte-header PCM16 little-endian RIFF/WAVE file."""
    return write_wav(frame_data, sample_rate, channels, PCM16_ENCODING)
