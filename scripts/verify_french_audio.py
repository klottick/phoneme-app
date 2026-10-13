"""Offline, read-only verifier for the FR-02 French word-audio candidate package.

Reads and measures only files under the repository's
``frontend/assets/audio/fr`` directory; it never rewrites the package and
never performs network activity. A PASS result is technical/metadata
validation only - it is not linguistic sign-off or rights clearance. The
live Dart catalogue mapping is checked by a separate independent oracle and
is deliberately not parsed here.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import re
import struct
import sys
import wave
from datetime import datetime
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlsplit

SCHEMA_VERSION = 1
CATALOGUE_STATUS = "candidate"
LANGUAGE = "fr"
ASSET_DIR = ("frontend", "assets", "audio", "fr")
LICENSES_DIR = "licenses"

# Current `frenchWords` order, per the approved FR-02 spec.
WORD_SEQUENCE = [
    "tout", "rouge", "vous", "doux", "loup", "soupe", "tu", "rue", "lune",
    "jus", "mur", "plume", "lit", "si", "vite", "île", "beau", "mot", "eau",
    "dos", "bon", "nom", "banc", "sans",
]

LICENSE_URLS = {
    "CC-BY-SA-4.0": "https://creativecommons.org/licenses/by-sa/4.0/",
    "CC-BY-4.0": "https://creativecommons.org/licenses/by/4.0/",
}
SPEAKER_NAME = "LoquaxFR"
SPEAKER_QUALIFICATION = "unverified"
ORIGIN_PATH = "frontend/lib/src/core/course/french_course.dart"
ORIGIN_SYMBOL = "frenchWords"
ORIGIN_STATUS = "existingCuratedNotRecordingReviewed"
REVIEW_STATUS = "pending"
TEACHING_INVENTORY = ("u", "y", "i", "o", "ɔ̃", "ɑ̃", "ʁ")

MANIFEST_FIELDS = ("schemaVersion", "catalogueStatus", "language", "entries")
ENTRY_FIELDS = (
    "id", "kind", "spokenText", "assetPath", "sha256", "byteLength", "audio",
    "mapping", "speaker", "license", "provenanceId", "changes", "review",
)
AUDIO_FIELDS = (
    "container", "encoding", "sampleRateHz", "channels", "bitsPerSample",
    "frameCount", "durationSeconds",
)
MAPPING_FIELDS = ("expectedIpa", "phonemes", "teachingTargets", "origin")
ORIGIN_FIELDS = ("path", "symbol", "revision", "status")
SPEAKER_FIELDS = ("sourceName", "qualificationStatus", "accent")
LICENSE_FIELDS = ("spdxId", "url", "textPath", "attribution", "notices")
REVIEW_FIELDS = ("status", "reviewer", "reviewedAt", "evidence")
PROVENANCE_FIELDS = (
    "id", "sourcePageUrl", "sourceTitle", "descriptionRevisionId",
    "descriptionRevisionUrl", "retrievedAt", "originalDownloadUrl",
    "mediaTimestamp", "sourceSha1", "sourceTranscription", "sourceSpeaker",
    "creditedCreators", "licenseEvidence", "sha256",
)
EVIDENCE_FIELDS = ("spdxId", "url", "creditText", "notices", "declaration")

SHA256_RE = re.compile(r"[0-9a-f]{64}")
SHA1_RE = re.compile(r"[0-9a-f]{40}")
UTC_ISO_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$")
COMMONS_HOST = "commons.wikimedia.org"
MEDIA_HOST = "upload.wikimedia.org"

PASS_MESSAGE = (
    "PASS: 24 pending French word candidates verified "
    "(technical/metadata only)."
)


def _required_spdx(word: str) -> str:
    """Spec: 23 words are CC BY-SA 4.0; `sans` is CC BY 4.0."""
    return "CC-BY-4.0" if word == "sans" else "CC-BY-SA-4.0"


# ---------------------------------------------------------------------------
# small shared checks
# ---------------------------------------------------------------------------

def _reject_constant(value: str) -> object:
    raise ValueError(f"non-finite JSON constant is not allowed: {value!r}")


def _strict_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    keys = [key for key, _ in pairs]
    duplicates = sorted({key for key in keys if keys.count(key) > 1})
    if duplicates:
        raise ValueError(
            "duplicate JSON keys: " + ", ".join(duplicates))
    return dict(pairs)


def _parse_json_file(path: Path, diagnostics: list[str]) -> object | None:
    """Parse UTF-8 JSON strictly (duplicate keys, NaN/Infinity, bad UTF-8)."""
    try:
        text = path.read_bytes().decode("utf-8")
    except FileNotFoundError:
        diagnostics.append(f"{path}: missing file")
        return None
    except UnicodeDecodeError as exc:
        diagnostics.append(f"{path}: invalid UTF-8 ({exc.reason})")
        return None
    except OSError as exc:
        diagnostics.append(f"{path}: unreadable ({exc.strerror or exc})")
        return None
    try:
        return json.loads(
            text, object_pairs_hook=_strict_object,
            parse_constant=_reject_constant)
    except ValueError as exc:
        diagnostics.append(f"{path}: invalid JSON ({exc})")
        return None


def _is_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _is_string(value: object) -> bool:
    return isinstance(value, str)


def _check_fields(obj: dict, names: tuple[str, ...], label: str,
                  diagnostics: list[str]) -> None:
    unknown = sorted(key for key in obj if key not in names)
    missing = [name for name in names if name not in obj]
    if unknown:
        diagnostics.append(f"{label}: unknown fields: {', '.join(unknown)}")
    if missing:
        diagnostics.append(f"{label}: missing fields: {', '.join(missing)}")


def _check_positive_int(value: object, label: str, diagnostics: list[str]) -> bool:
    if not _is_int(value) or value < 1:
        diagnostics.append(
            f"{label} is {value!r}; it must be a positive integer "
            f"(booleans and other types are not integers)")
        return False
    return True


def _check_duration_value(value: object, label: str,
                          diagnostics: list[str]) -> bool:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or \
            not math.isfinite(value):
        diagnostics.append(f"{label} is {value!r}; it must be a finite number")
        return False
    if value <= 0:
        diagnostics.append(f"{label} is {value!r}; it must be positive")
        return False
    return True


def _check_nonempty_string(value: object, label: str,
                           diagnostics: list[str]) -> bool:
    if not _is_string(value) or not value.strip():
        diagnostics.append(f"{label} is {value!r}; it must be a nonempty string")
        return False
    return True


def _check_string_list(value: object, label: str, diagnostics: list[str],
                       require_items: bool = True) -> bool:
    if not isinstance(value, list):
        diagnostics.append(f"{label} is {value!r}; it must be a list of strings")
        return False
    for index, item in enumerate(value):
        if not _is_string(item) or (require_items and not item.strip()):
            diagnostics.append(
                f"{label}[{index}] is {item!r}; items must be nonempty strings")
            return False
    return True


def _check_utc_iso(value: object, label: str, diagnostics: list[str]) -> bool:
    if not _is_string(value) or not UTC_ISO_RE.match(value):
        diagnostics.append(
            f"{label} is {value!r}; it must be a UTC ISO 8601 timestamp "
            f"(YYYY-MM-DDTHH:MM:SSZ)")
        return False
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        diagnostics.append(f"{label} {value!r} is not a valid calendar date")
        return False
    return True


def _check_file_chain(root: Path, target: Path, label: str, display: str,
                      diagnostics: list[str]) -> bool:
    """Reject symlinks at every component; require a regular readable file."""
    current = root
    for part in target.relative_to(root).parts:
        current = current / part
        if current.is_symlink():
            diagnostics.append(
                f"{label}: {display!r} is or passes through a symlink "
                f"(component {part!r}); symlinks are not allowed")
            return False
    if not current.is_file():
        diagnostics.append(
            f"{label}: {display!r} does not resolve to a readable regular file")
        return False
    return True


def _safe_relative(value: object, base: Path, label: str,
                   diagnostics: list[str]) -> Path | None:
    """Accept only relative, non-traversing paths; escapees are never content."""
    if not _is_string(value) or not value:
        diagnostics.append(f"{label} is {value!r}; it must be a nonempty string")
        return None
    candidate = Path(value)
    if candidate.is_absolute():
        diagnostics.append(
            f"{label}: {value!r} must be a relative path (absolute paths are unsafe)")
        return None
    if ".." in candidate.parts:
        diagnostics.append(
            f"{label}: {value!r} must not traverse ('..') outside the package")
        return None
    return base / candidate


def _check_https_url(value: object, host: str, label: str,
                     diagnostics: list[str]) -> object:
    if not _is_string(value):
        diagnostics.append(f"{label} is {value!r}; it must be a string URL")
        return None
    try:
        parts = urlsplit(value)
    except ValueError:
        diagnostics.append(f"{label}: {value!r} is not a valid URL")
        return None
    if parts.scheme != "https":
        diagnostics.append(f"{label}: {value!r} must use HTTPS")
        return parts
    if (parts.hostname or "").lower() != host:
        diagnostics.append(f"{label}: {value!r} must point at {host}")
        return parts
    return parts


# ---------------------------------------------------------------------------
# WAV measurement
# ---------------------------------------------------------------------------

def _reject_format(fmt_code: int) -> None:
    raise ValueError(
        f"unsupported WAV audio format code {fmt_code:04X} "
        f"(only PCM is allowed)")


def _parse_fmt(chunk: bytes) -> tuple[int, int, int, int, int]:
    """Return (rate, channels, bits, byte_rate, block_align) from a fmt chunk."""
    if len(chunk) < 16:
        raise ValueError("fmt chunk is truncated")
    (audio_format, channels, rate, byte_rate, block_align, bits) = (
        struct.unpack_from("<HHIIHH", chunk, 0)[:6])
    if audio_format == 0xFFFE:  # WAVE_FORMAT_EXTENSIBLE: read the true subformat
        cb_size = struct.unpack_from("<H", chunk, 16)[0] if len(chunk) >= 18 \
            else -1
        if len(chunk) < 40 or cb_size != 22:
            raise ValueError("extensible fmt chunk is truncated or invalid")
        sub = struct.unpack_from("<H", chunk, 24)[0]  # SubFormat GUID data1
        if sub != 1:
            _reject_format(sub)
    elif audio_format != 1:
        _reject_format(audio_format)
    if channels < 1 or rate < 1 or bits < 1 or block_align < 1:
        raise ValueError("fmt chunk has degenerate values")
    if bits % 8 != 0:
        raise ValueError(
            f"bits per sample {bits} is not an integral number of bytes")
    if byte_rate != rate * channels * (bits // 8):
        raise ValueError("byte rate does not match rate * channels * width")
    if block_align != channels * (bits // 8):
        raise ValueError("block align does not match channels * width")
    return rate, channels, bits, byte_rate, block_align


def _parse_riff_container(raw: bytes) -> tuple[int, int, int, bytes]:
    """Validate RIFF/WAVE bounds and return (rate, channels, bits, data).

    Legitimate extra chunks (e.g. LIST metadata) and chunk-alignment padding
    inside the declared container are allowed; incomplete chunks, padding
    beyond the declared container, or non-PCM formats raise ValueError.
    """
    if len(raw) < 12:
        raise ValueError("file is too small to be a RIFF container")
    if raw[0:4] != b"RIFF":
        raise ValueError("missing RIFF header")
    if raw[8:12] != b"WAVE":
        raise ValueError("missing WAVE form type (not a WAV file)")
    container_size = struct.unpack_from("<I", raw, 4)[0]
    if container_size != len(raw) - 8:
        raise ValueError(
            f"RIFF size {container_size} does not cover the whole file "
            f"({len(raw) - 8} bytes present)")
    end = len(raw)
    pos = 12
    fmt_payload = None
    data_payload = None
    while pos < end:
        if pos + 8 > end:
            raise ValueError("truncated RIFF chunk header")
        chunk_id = raw[pos:pos + 4]
        size = struct.unpack_from("<I", raw, pos + 4)[0]
        body_start = pos + 8
        if body_start + size > end:
            raise ValueError(
                f"chunk {chunk_id.decode('latin-1')} is incomplete: "
                f"declared {size} bytes, only {end - body_start} available")
        if chunk_id == b"fmt ":
            if fmt_payload is not None:
                raise ValueError("multiple fmt chunks")
            fmt_payload = raw[body_start:body_start + size]
        elif chunk_id == b"data":
            if data_payload is not None:
                raise ValueError("multiple data chunks")
            data_payload = raw[body_start:body_start + size]
        # Other chunks (LIST, INFO, ...) are permitted; bounds already checked.
        pos = body_start + size
        if size & 1 and pos < end:
            pos += 1  # chunk-alignment padding, inside the container
    if fmt_payload is None:
        raise ValueError("missing fmt chunk")
    if data_payload is None:
        raise ValueError("missing data chunk")
    rate, channels, bits, _, block_align = _parse_fmt(fmt_payload)
    if block_align == 0:
        raise ValueError("zero sample width")
    return rate, channels, bits, data_payload


def measure_wav(path: Path) -> dict[str, str | int | float]:
    """Return the entry's `audio` object, measured from the file's bytes.

    Malformed, empty, truncated or unsupported (non-PCM) WAVs raise ValueError.
    """
    try:
        raw = Path(path).read_bytes()
    except OSError as exc:
        raise ValueError(f"unreadable WAV ({exc.strerror or exc})") from exc
    rate, channels, bits, data = _parse_riff_container(raw)
    width = bits // 8
    sample_bytes = width * channels
    if sample_bytes <= 0 or len(data) % sample_bytes:
        raise ValueError("data length is not a whole number of frames")
    frames = len(data) // sample_bytes
    # Cross-check against the stdlib parser, which rejects unknown formats.
    with wave.open(io.BytesIO(raw), "rb") as handle:
        if (handle.getframerate(), handle.getnchannels(),
                handle.getsampwidth() * 8) != (rate, channels, bits):
            raise ValueError("fmt chunk disagrees with the WAVE header")
        if handle.getnframes() != frames:
            raise ValueError("data length disagrees with the frame count")
    if frames <= 0:
        raise ValueError("WAV contains no audio frames")
    return {
        "container": "wav",
        "encoding": "pcm",
        "sampleRateHz": rate,
        "channels": channels,
        "bitsPerSample": bits,
        "frameCount": frames,
        "durationSeconds": frames / rate,
    }


# ---------------------------------------------------------------------------
# manifest entry checks
# ---------------------------------------------------------------------------

def _check_audio_object(audio: object, label: str,
                        diagnostics: list[str]) -> bool:
    if not isinstance(audio, dict):
        diagnostics.append(f"{label} is {audio!r}; it must be an object")
        return False
    _check_fields(audio, AUDIO_FIELDS, label, diagnostics)
    ok = True
    if "container" in audio and audio["container"] != "wav":
        diagnostics.append(
            f"{label}.container is {audio['container']!r}; it must be 'wav'")
        ok = False
    if "encoding" in audio and audio["encoding"] != "pcm":
        diagnostics.append(
            f"{label}.encoding is {audio['encoding']!r}; it must be 'pcm'")
        ok = False
    integral = True
    for field in ("sampleRateHz", "channels", "bitsPerSample", "frameCount"):
        if field in audio and \
                not _check_positive_int(audio[field], f"{label}.{field}",
                                        diagnostics):
            integral = False
    if "bitsPerSample" in audio and \
            _is_int(audio["bitsPerSample"]) and \
            audio["bitsPerSample"] % 8 != 0:
        diagnostics.append(
            f"{label}.bitsPerSample {audio['bitsPerSample']!r} "
            f"is not an integral number of bytes")
        integral = False
    duration_ok = True
    if "durationSeconds" in audio and \
            not _check_duration_value(
                audio["durationSeconds"], f"{label}.durationSeconds",
                diagnostics):
        duration_ok = False
    if integral and duration_ok:
        rate, frames = audio.get("sampleRateHz"), audio.get("frameCount")
        if _is_int(rate) and rate > 0 and _is_int(frames) and frames > 0 and \
                isinstance(audio["durationSeconds"], (int, float)) and \
                not isinstance(audio["durationSeconds"], bool):
            expected = frames / rate
            if abs(audio["durationSeconds"] - expected) > 1e-06:
                diagnostics.append(
                    f"{label}.durationSeconds is {audio['durationSeconds']!r}; "
                    f"it must equal frameCount/sampleRateHz ({expected!r}) "
                    f"within 1 microsecond")
    return ok


def _check_audio_against_measurement(audio: object, measured: dict,
                                     label: str,
                                     diagnostics: list[str]) -> None:
    if not isinstance(audio, dict):
        return
    for field, expected in measured.items():
        if field in audio and audio[field] != expected:
            diagnostics.append(
                f"{label}.{field} is {audio[field]!r}, "
                f"but the file measures {expected!r}")


def _check_targets(value: object, label: str, diagnostics: list[str]) -> None:
    if not _check_string_list(value, label, diagnostics):
        return
    for index, item in enumerate(value):
        if item not in TEACHING_INVENTORY:
            diagnostics.append(
                f"{label}[{index}] is {item!r}; teachingTargets must be drawn "
                f"from the teaching inventory "
                f"({', '.join(TEACHING_INVENTORY)})")
    ranks = [TEACHING_INVENTORY.index(item)
             for item in value if item in TEACHING_INVENTORY]
    if ranks != sorted(ranks):
        diagnostics.append(
            f"{label} {value!r} must follow the teaching inventory order "
            f"({', '.join(TEACHING_INVENTORY)})")
    if len(set(value)) != len(value):
        diagnostics.append(f"{label} {value!r} must not repeat a target")


def _check_mapping(mapping: object, label: str,
                   diagnostics: list[str]) -> None:
    if not isinstance(mapping, dict):
        diagnostics.append(f"{label} must be an object")
        return
    _check_fields(mapping, MAPPING_FIELDS, label, diagnostics)
    if "expectedIpa" in mapping:
        ipa = mapping["expectedIpa"]
        if _check_nonempty_string(ipa, f"{label}.expectedIpa", diagnostics):
            if isinstance(ipa, str) and (ipa.startswith("/") or ipa.endswith("/")):
                diagnostics.append(
                    f"{label}.expectedIpa is {ipa!r}; it must not be "
                    f"slash-decorated")
    if "phonemes" in mapping:
        phonemes = mapping["phonemes"]
        if _check_string_list(phonemes, f"{label}.phonemes", diagnostics) and \
                not phonemes:
            diagnostics.append(
                f"{label}.phonemes must list the ordered sounds of the word")
    if "teachingTargets" in mapping:
        _check_targets(mapping["teachingTargets"], f"{label}.teachingTargets",
                       diagnostics)
    if "origin" in mapping:
        _check_origin(mapping["origin"], f"{label}.origin", diagnostics)


def _check_origin(origin: object, label: str,
                  diagnostics: list[str]) -> None:
    if not isinstance(origin, dict):
        diagnostics.append(f"{label} must be an object")
        return
    _check_fields(origin, ORIGIN_FIELDS, label, diagnostics)
    if "path" in origin and origin["path"] != ORIGIN_PATH:
        diagnostics.append(
            f"{label}.path is {origin['path']!r}; it must be {ORIGIN_PATH!r}")
    if "symbol" in origin and origin["symbol"] != ORIGIN_SYMBOL:
        diagnostics.append(
            f"{label}.symbol is {origin['symbol']!r}; it must be {ORIGIN_SYMBOL!r}")
    if "status" in origin and origin["status"] != ORIGIN_STATUS:
        diagnostics.append(
            f"{label}.status is {origin['status']!r}; it must be "
            f"{ORIGIN_STATUS!r}")
    if "revision" in origin:
        revision = origin["revision"]
        if not (isinstance(revision, str) and
                re.fullmatch(r"[0-9a-f]{40}", revision)):
            diagnostics.append(
                f"{label}.revision is {revision!r}; it must be a full "
                f"lowercase 40-hex Git revision")


def _check_speaker(speaker: object, label: str,
                   diagnostics: list[str]) -> None:
    if not isinstance(speaker, dict):
        diagnostics.append(f"{label} must be an object")
        return
    _check_fields(speaker, SPEAKER_FIELDS, label, diagnostics)
    if "sourceName" in speaker and \
            not _check_nonempty_string(speaker["sourceName"], f"{label}.sourceName",
                                       diagnostics):
        return
    if "sourceName" in speaker and speaker["sourceName"] != SPEAKER_NAME:
        diagnostics.append(
            f"{label}.sourceName is {speaker['sourceName']!r}; it must be "
            f"{SPEAKER_NAME!r} (the recorded source speaker)")
    if "qualificationStatus" in speaker and \
            speaker["qualificationStatus"] != SPEAKER_QUALIFICATION:
        diagnostics.append(
            f"{label}.qualificationStatus is "
            f"{speaker['qualificationStatus']!r}; speaker qualification is "
            f"unverified and must stay {SPEAKER_QUALIFICATION!r}")
    if "accent" in speaker and speaker["accent"] is not None:
        diagnostics.append(
            f"{label}.accent is {speaker['accent']!r}; accent must remain null "
            f"(no accent claim)")


def _check_license(license_obj: object, word: str, root: Path,
                   asset_dir: Path, label: str,
                   diagnostics: list[str]) -> None:
    if not isinstance(license_obj, dict):
        diagnostics.append(f"{label} must be an object")
        return
    _check_fields(license_obj, LICENSE_FIELDS, label, diagnostics)
    required = _required_spdx(word)
    spdx = license_obj.get("spdxId")
    if _is_string(spdx) and spdx != required:
        diagnostics.append(
            f"{label}.spdxId is {spdx!r}; word {word!r} requires {required!r}")
    if "url" in license_obj:
        url = license_obj["url"]
        if _is_string(spdx) and spdx in LICENSE_URLS:
            expected = LICENSE_URLS[spdx]
            if url != expected:
                diagnostics.append(
                    f"{label}.url is {url!r}; {spdx} requires {expected!r}")
        elif not _is_string(url) or not url:
            diagnostics.append(f"{label}.url must be a nonempty URL")
    if "attribution" in license_obj:
        _check_nonempty_string(
            license_obj["attribution"], f"{label}.attribution", diagnostics)
    if "notices" in license_obj:
        _check_string_list(license_obj["notices"], f"{label}.notices",
                           diagnostics)
    if "textPath" in license_obj:
        _check_license_text(
            license_obj["textPath"], word, root, asset_dir,
            f"{label}.textPath", diagnostics)


def _check_license_text(value: object, word: str, root: Path,
                        asset_dir: Path, label: str,
                        diagnostics: list[str]) -> None:
    target = _safe_relative(value, asset_dir, label, diagnostics)
    if target is None:
        return
    try:
        relative_parts = target.relative_to(asset_dir).parts
    except ValueError:
        diagnostics.append(
            f"{label} {value!r} must stay under the asset directory")
        return
    if not relative_parts or relative_parts[0] != LICENSES_DIR:
        diagnostics.append(
            f"{label} {value!r} must resolve to a licence text under the "
            f"package '{LICENSES_DIR}/' directory")
        return
    if not _check_file_chain(root, target, label, _is_string(value) and value or "",
                             diagnostics):
        return
    try:
        content = target.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        diagnostics.append(f"{label} {value!r} is not readable UTF-8 text")
        return
    if not content.strip():
        diagnostics.append(f"{label} {value!r} is empty; the official licence "
                           f"for word {word!r} must be retained")


def _check_review(review: object, label: str,
                  diagnostics: list[str]) -> None:
    if not isinstance(review, dict):
        diagnostics.append(f"{label} must be an object")
        return
    _check_fields(review, REVIEW_FIELDS, label, diagnostics)
    if "status" in review:
        status = review["status"]
        if not _is_string(status) or status != REVIEW_STATUS:
            diagnostics.append(
                f"{label}.status is {status!r}; it must be "
                f"{REVIEW_STATUS!r} (linguistic review is deliberately pending)")
    if "reviewer" in review and review["reviewer"] is not None:
        diagnostics.append(
            f"{label}.reviewer is {review['reviewer']!r}; it must be null "
            f"while the review is pending")
    if "reviewedAt" in review and review["reviewedAt"] is not None:
        diagnostics.append(
            f"{label}.reviewedAt is {review['reviewedAt']!r}; it must be "
            f"null while the review is pending")
    if "evidence" in review and review["evidence"] != []:
        diagnostics.append(
            f"{label}.evidence is {review['evidence']!r}; it must be empty "
            f"while the review is pending")


def _check_manifest_entry(index: int, word: str, entry: object,
                          root: Path, asset_dir: Path,
                          seen_ids: set[str], seen_paths: set[str],
                          listed_wavs: set[Path],
                          diagnostics: list[str]) -> bytes | None:
    label = f"entries[{index}] (word {word!r})"
    if not isinstance(entry, dict):
        diagnostics.append(f"manifest.json {label}: entry must be an object")
        return None
    _check_fields(entry, ENTRY_FIELDS, f"manifest.json {label}", diagnostics)
    label = f"manifest.json {label}"

    expected_id = f"fr-word-{word}"
    if "id" in entry:
        entry_id = entry["id"]
        if entry_id != expected_id:
            diagnostics.append(
                f"{label}: id is {entry_id!r}, expected {expected_id!r}")
        if _is_string(entry_id):
            if entry_id in seen_ids:
                diagnostics.append(f"{label}: id {entry_id!r} is duplicated")
            seen_ids.add(entry_id)
    if "kind" in entry and entry["kind"] != "word":
        diagnostics.append(
            f"{label}: kind is {entry['kind']!r}, it must be 'word'")
    if "spokenText" in entry:
        spoken = entry["spokenText"]
        if not _is_string(spoken) or spoken != word:
            diagnostics.append(
                f"{label}: spokenText is {spoken!r}; it must be exactly "
                f"{word!r}")
    if "provenanceId" in entry:
        _check_nonempty_string(
            entry["provenanceId"], f"{label}: provenanceId", diagnostics)
    if "changes" in entry:
        changes = entry["changes"]
        if not isinstance(changes, list) or changes:
            diagnostics.append(
                f"{label}: changes is {changes!r}; it must be an empty list "
                f"(the original bytes must be unchanged)")

    wav_bytes = None
    asset_path = entry.get("assetPath")
    target = _safe_relative(
        asset_path, asset_dir, f"{label}: assetPath", diagnostics)
    if target is None:
        pass
    else:
        if str(target) in seen_paths:
            diagnostics.append(
                f"{label}: assetPath {asset_path!r} is not unique across entries")
        seen_paths.add(str(target))
        listed_wavs.add(target)
        if _check_file_chain(
                root, target, f"{label}: assetPath",
                _is_string(asset_path) and asset_path or "", diagnostics):
            try:
                wav_bytes = target.read_bytes()
            except OSError as exc:
                diagnostics.append(
                    f"{label}: assetPath {asset_path!r} is unreadable "
                    f"({exc.strerror or exc})")
            else:
                if "sha256" in entry:
                    declared = entry["sha256"]
                    if not (_is_string(declared) and
                            SHA256_RE.fullmatch(declared)):
                        diagnostics.append(
                            f"{label}: sha256 is {declared!r}; it must be 64 "
                            f"lowercase hex characters")
                    elif declared != hashlib.sha256(wav_bytes).hexdigest():
                        diagnostics.append(
                            f"{label}: sha256 is {declared!r}; the file "
                            f"measures "
                            f"{hashlib.sha256(wav_bytes).hexdigest()!r}")
                if "byteLength" in entry:
                    declared = entry["byteLength"]
                    if not _check_positive_int(
                            declared, f"{label}: byteLength", diagnostics) or \
                            declared != len(wav_bytes):
                        diagnostics.append(
                            f"{label}: byteLength is {declared!r}; the file "
                            f"measures {len(wav_bytes)} bytes")
                if "audio" in entry:
                    if wav_bytes is not None:
                        try:
                            measured = measure_wav(target)
                        except ValueError as exc:
                            diagnostics.append(f"{label}: {exc}")
                        else:
                            _check_audio_against_measurement(
                                entry["audio"], measured,
                                f"{label}.audio", diagnostics)

    if "audio" in entry:
        _check_audio_object(entry["audio"], f"{label}.audio", diagnostics)
    if "mapping" in entry:
        _check_mapping(entry["mapping"], f"{label}.mapping", diagnostics)
    if "speaker" in entry:
        _check_speaker(entry["speaker"], f"{label}.speaker", diagnostics)
    if "license" in entry:
        _check_license(entry["license"], word, root, asset_dir,
                       f"{label}.license", diagnostics)
    if "review" in entry:
        _check_review(entry["review"], f"{label}.review", diagnostics)
    return wav_bytes


def _check_unlisted_wavs(root: Path, asset_dir: Path,
                         listed_wavs: set[Path],
                         diagnostics: list[str]) -> None:
    if not asset_dir.is_dir():
        return
    for path in sorted(asset_dir.rglob("*.wav")):
        if path not in listed_wavs:
            diagnostics.append(
                f"{path.relative_to(root)}: WAV file is not listed in the "
                f"manifest entries")


# ---------------------------------------------------------------------------
# provenance entry checks
# ---------------------------------------------------------------------------

def _check_source_page_url(value: object, label: str,
                           diagnostics: list[str]) -> None:
    parts = _check_https_url(value, COMMONS_HOST, label, diagnostics)
    if parts is None:
        return
    if "File:" not in unquote(parts.path):
        diagnostics.append(
            f"{label}: {value!r} must identify the audited Commons file page")


def _normalized_title(value: object) -> str | None:
    if not _is_string(value) or not value.strip():
        return None
    return value.replace("_", " ").strip()


def _check_source_title(value: object, word: str, label: str,
                        diagnostics: list[str]) -> None:
    if not _check_nonempty_string(value, label, diagnostics):
        return
    if word not in _normalized_title(value):  # type: ignore[arg-type]
        diagnostics.append(
            f"{label} is {value!r}; it must designate the selected word "
            f"{word!r} (Commons spaces vs underscores do not matter)")


def _check_revision_url(value: object, title: object, revision_id: object,
                        label: str, diagnostics: list[str]) -> None:
    parts = _check_https_url(value, COMMONS_HOST, label, diagnostics)
    if parts is None:
        return
    params = parse_qs(parts.query, keep_blank_values=True)
    url_title = params.get("title", [None])[0]
    expected_title = _normalized_title(title)
    if url_title is None or expected_title is None:
        diagnostics.append(
            f"{label}: the 'title' query parameter must match sourceTitle")
    elif _normalized_title(url_title) != expected_title:
        diagnostics.append(
            f"{label}: 'title' is {url_title!r}; it must match sourceTitle "
            f"{title!r}")
    url_oldid = params.get("oldid", [None])[0]
    if url_oldid is None or not _is_int(revision_id) or \
            not re.fullmatch(r"\d+", url_oldid):
        diagnostics.append(
            f"{label}: the 'oldid' query parameter must be the positive "
            f"integer descriptionRevisionId")
        return
    if int(url_oldid) != revision_id:
        diagnostics.append(
            f"{label}: 'oldid' is {url_oldid!r}; it must match "
            f"descriptionRevisionId {revision_id!r}")


def _check_media_url(value: object, word: str, label: str,
                     diagnostics: list[str]) -> None:
    parts = _check_https_url(value, MEDIA_HOST, label, diagnostics)
    if parts is None:
        return
    if not parts.path or parts.path == "/":
        diagnostics.append(
            f"{label}: {value!r} must reference the original media file path")
        return
    file_name = unquote(parts.path.rsplit("/", 1)[-1]).replace("_", " ")
    if word not in file_name:
        diagnostics.append(
            f"{label}: {value!r} must reference the media file for word "
            f"{word!r}")


def _check_license_evidence(evidence: object, word: object, label: str,
                            manifest_license: object,
                            diagnostics: list[str]) -> None:
    if not isinstance(evidence, dict):
        diagnostics.append(f"{label} must be an object")
        return
    _check_fields(evidence, EVIDENCE_FIELDS, label, diagnostics)
    if "spdxId" in evidence:
        declared = evidence["spdxId"]
        if _is_string(declared) and declared not in LICENSE_URLS:
            diagnostics.append(
                f"{label}.spdxId is {declared!r}; it is not a supported "
                f"audio licence")
        elif _is_string(word) and _is_string(declared) and \
                declared != _required_spdx(word):
            diagnostics.append(
                f"{label}.spdxId is {declared!r}; word {word!r} requires "
                f"{_required_spdx(word)!r}")
    if "url" in evidence:
        declared = evidence["url"]
        expected = LICENSE_URLS.get(
            evidence.get("spdxId")) if _is_string(evidence.get("spdxId")) \
            else None
        if expected is not None and declared != expected:
            diagnostics.append(
                f"{label}.url is {declared!r}; it must match the licence "
                f"URL {expected!r}")
    if "creditText" in evidence:
        _check_nonempty_string(
            evidence["creditText"], f"{label}.creditText", diagnostics)
    if "notices" in evidence:
        declared = evidence["notices"]
        if not _check_string_list(declared, f"{label}.notices", diagnostics):
            return
        if isinstance(manifest_license, dict) and \
                isinstance(manifest_license.get("notices"), list) and \
                declared != manifest_license["notices"]:
            diagnostics.append(
                f"{label}.notices is {declared!r}; it must agree with the "
                f"manifest license.notices {manifest_license['notices']!r}")
    if "declaration" in evidence:
        _check_nonempty_string(
            evidence["declaration"], f"{label}.declaration", diagnostics)


def _check_provenance_entry(index: int, word: str, prov: object,
                            manifest_entry: object, wav_bytes: bytes | None,
                            root: Path,
                            diagnostics: list[str]) -> None:
    label = f"provenance.json entries[{index}] (word {word!r})"
    if not isinstance(prov, dict):
        diagnostics.append(f"{label}: entry must be an object")
        return
    _check_fields(prov, PROVENANCE_FIELDS, label, diagnostics)
    manifest = manifest_entry if isinstance(manifest_entry, dict) else {}

    if "id" in prov:
        pid = prov["id"]
        expected = manifest.get("provenanceId")
        if not _is_string(pid) or not pid:
            diagnostics.append(f"{label}: id must be a nonempty string")
        elif _is_string(expected) and pid != expected:
            diagnostics.append(
                f"{label}: id is {pid!r}; it must match the manifest "
                f"provenanceId {expected!r}")
    if "sourcePageUrl" in prov:
        _check_source_page_url(prov["sourcePageUrl"],
                               f"{label}.sourcePageUrl", diagnostics)
    if "sourceTitle" in prov:
        _check_source_title(prov["sourceTitle"], word,
                            f"{label}.sourceTitle", diagnostics)
    if "descriptionRevisionId" in prov:
        _check_positive_int(
            prov["descriptionRevisionId"],
            f"{label}.descriptionRevisionId", diagnostics)
    if "descriptionRevisionUrl" in prov:
        _check_revision_url(
            prov["descriptionRevisionUrl"], prov.get("sourceTitle"),
            prov.get("descriptionRevisionId"),
            f"{label}.descriptionRevisionUrl", diagnostics)
    if "retrievedAt" in prov:
        _check_utc_iso(prov["retrievedAt"], f"{label}.retrievedAt",
                       diagnostics)
    if "originalDownloadUrl" in prov:
        _check_media_url(prov["originalDownloadUrl"], word,
                         f"{label}.originalDownloadUrl", diagnostics)
    if "mediaTimestamp" in prov:
        _check_utc_iso(prov["mediaTimestamp"], f"{label}.mediaTimestamp",
                       diagnostics)
    if "sourceSha1" in prov:
        declared = prov["sourceSha1"]
        if declared is None:
            pass
        elif not (_is_string(declared) and SHA1_RE.fullmatch(declared)):
            diagnostics.append(
                f"{label}: sourceSha1 is {declared!r}; it must be null or "
                f"lowercase 40-hex")
        elif wav_bytes is not None and \
                hashlib.sha1(wav_bytes, usedforsecurity=False).hexdigest() \
                != declared:
            diagnostics.append(
                f"{label}: sourceSha1 is {declared!r}; it does not match "
                f"the audited file bytes")
    if "sourceTranscription" in prov:
        declared = prov["sourceTranscription"]
        if not _is_string(declared) or declared != word:
            diagnostics.append(
                f"{label}: sourceTranscription is {declared!r}; it must "
                f"agree with the manifest spokenText {word!r}")
    if "sourceSpeaker" in prov:
        declared = prov["sourceSpeaker"]
        if declared != SPEAKER_NAME:
            diagnostics.append(
                f"{label}: sourceSpeaker is {declared!r}; it must be "
                f"{SPEAKER_NAME!r}")
    if "creditedCreators" in prov:
        creators = prov["creditedCreators"]
        if not _check_string_list(
                creators, f"{label}.creditedCreators", diagnostics) or \
                not creators:
            diagnostics.append(
                f"{label}: creditedCreators is {creators!r}; it must be a "
                f"nonempty list of credited names")
    if "licenseEvidence" in prov:
        _check_license_evidence(
            prov["licenseEvidence"], word, f"{label}.licenseEvidence",
            manifest.get("license"), diagnostics)
    if "sha256" in prov:
        declared = prov["sha256"]
        expected = manifest.get("sha256")
        if not (_is_string(declared) and SHA256_RE.fullmatch(declared)):
            diagnostics.append(
                f"{label}: sha256 is {declared!r}; it must be 64 lowercase "
                f"hex characters")
        elif _is_string(expected) and declared != expected:
            diagnostics.append(
                f"{label}: sha256 is {declared!r}; it must match the "
                f"manifest sha256 {expected!r}")


def _check_manifest_root(manifest: object,
                         diagnostics: list[str]) -> list | None:
    if not isinstance(manifest, dict):
        diagnostics.append("manifest.json: root must be an object")
        return None
    _check_fields(manifest, MANIFEST_FIELDS, "manifest.json", diagnostics)
    if "schemaVersion" in manifest and \
            manifest["schemaVersion"] != SCHEMA_VERSION:
        diagnostics.append(
            f"manifest.json: schemaVersion is "
            f"{manifest['schemaVersion']!r}; it must be {SCHEMA_VERSION}")
    if "catalogueStatus" in manifest and \
            manifest["catalogueStatus"] != CATALOGUE_STATUS:
        diagnostics.append(
            f"manifest.json: catalogueStatus is "
            f"{manifest['catalogueStatus']!r}; it must be "
            f"{CATALOGUE_STATUS!r}")
    if "language" in manifest and manifest["language"] != LANGUAGE:
        diagnostics.append(
            f"manifest.json: language is {manifest['language']!r}; it must "
            f"be {LANGUAGE!r}")
    entries = manifest.get("entries")
    if not isinstance(entries, list):
        diagnostics.append("manifest.json: entries must be a list")
        return None
    if len(entries) != len(WORD_SEQUENCE):
        diagnostics.append(
            f"manifest.json: entries must list exactly the "
            f"{len(WORD_SEQUENCE)} candidate words in frenchWords order "
            f"(got {len(entries)})")
        return None
    return entries


def _check_provenance_root(provenance: object,
                           diagnostics: list[str]) -> list | None:
    if not isinstance(provenance, dict):
        diagnostics.append("provenance.json: root must be an object")
        return None
    _check_fields(provenance, ("schemaVersion", "entries"),
                  "provenance.json", diagnostics)
    if "schemaVersion" in provenance and \
            provenance["schemaVersion"] != SCHEMA_VERSION:
        diagnostics.append(
            f"provenance.json: schemaVersion is "
            f"{provenance['schemaVersion']!r}; it must be {SCHEMA_VERSION}")
    entries = provenance.get("entries")
    if not isinstance(entries, list):
        diagnostics.append("provenance.json: entries must be a list")
        return None
    if len(entries) != len(WORD_SEQUENCE):
        diagnostics.append(
            f"provenance.json: entries must list exactly the "
            f"{len(WORD_SEQUENCE)} evidence records (got {len(entries)})")
        return None
    return entries


# ---------------------------------------------------------------------------
# orchestration
# ---------------------------------------------------------------------------

def verify_package(repo_root: Path) -> list[str]:
    """Validate the candidate package under ``repo_root``.

    Returns deterministic, actionable diagnostics; an empty list means the
    package passed every technical/metadata check. Only ValueError/OSError
    from reading package files are turned into diagnostics; programming
    errors are not masked.
    """
    root = Path(repo_root).resolve()
    diagnostics: list[str] = []
    if not root.is_dir():
        diagnostics.append(
            f"{root}: repository root is missing or is not a directory")
        return diagnostics
    asset_dir = root.joinpath(*ASSET_DIR)

    manifest = _parse_json_file(asset_dir / "manifest.json", diagnostics)
    provenance = _parse_json_file(asset_dir / "provenance.json", diagnostics)
    if not isinstance(manifest, dict) or not isinstance(provenance, dict):
        return diagnostics

    manifest_entries = _check_manifest_root(manifest, diagnostics)
    provenance_entries = _check_provenance_root(provenance, diagnostics)
    if manifest_entries is None or provenance_entries is None:
        return diagnostics

    seen_ids: set[str] = set()
    seen_paths: set[str] = set()
    listed_wavs: set[Path] = set()
    wav_bytes_by_index: list[bytes | None] = []
    for index, (word, entry) in enumerate(zip(WORD_SEQUENCE, manifest_entries)):
        wav_bytes_by_index.append(
            _check_manifest_entry(
                index, word, entry, root, asset_dir, seen_ids, seen_paths,
                listed_wavs, diagnostics))

    _check_unlisted_wavs(root, asset_dir, listed_wavs, diagnostics)

    for index, (word, prov) in enumerate(zip(WORD_SEQUENCE, provenance_entries)):
        _check_provenance_entry(
            index, word, prov, manifest_entries[index],
            wav_bytes_by_index[index], root, diagnostics)

    return diagnostics


def main(argv: list[str] | None = None) -> int:
    """CLI entry point: exit 0 on a valid package, 1 on failure, 2 on usage."""
    default_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(
        prog="verify_french_audio",
        description="Read-only, offline check of the French word-audio "
                    "candidate package (technical/metadata only; no network, "
                    "no rewrites).")
    parser.add_argument(
        "--repo-root", type=Path, default=default_root, metavar="PATH",
        help="repository root containing frontend/ "
             "(default: this script's repository root)")
    args = parser.parse_args(argv)
    diagnostics = verify_package(args.repo_root)
    for diagnostic in diagnostics:
        print(f"ERROR: {diagnostic}", file=sys.stderr)
    if diagnostics:
        return 1
    print(PASS_MESSAGE)
    return 0


if __name__ == "__main__":
    sys.exit(main())
