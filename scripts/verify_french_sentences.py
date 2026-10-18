"""Read-only verifier for the offline FR08 sentence package."""

import argparse
import hashlib
import io
import json
import math
import os
import re
import stat
import sys
import unicodedata
import wave
from datetime import datetime
from pathlib import Path, PurePosixPath
from urllib.parse import urlsplit

from french_sentence_package import (
    SentencePackageError,
    annotation_hash,
    parse_fleurs_train_tsv,
    valid_sha256,
)
from prepare_french_sentences import REVISION, TSV_URL


MAX_JSON_BYTES = 16 * 1024 * 1024
MAX_AUDIO_BYTES = 100 * 1024 * 1024
MAX_LICENSE_BYTES = 2 * 1024 * 1024
MAX_EVIDENCE_TEXT_BYTES = 2 * 1024 * 1024

SECTION_IDS = (
    "en-fr-sentence-hunt-vowels",
    "en-fr-sentence-hunt-consonants",
    "en-fr-sentence-hunt-mixed",
)
SECTION_KINDS = ("vowels", "consonants", "mixed")
ITEM_PREFIXES = ("fr08-vowel", "fr08-consonant", "fr08-mixed")
VOWELS = frozenset((
    "i", "y", "u", "e", "ø", "o", "ɛ", "œ", "ɔ", "a", "ɑ", "ə",
    "ɛ̃", "œ̃", "ɑ̃", "ɔ̃",
))
CONSONANTS = frozenset((
    "p", "b", "t", "d", "k", "ɡ", "f", "v", "s", "z", "ʃ", "ʒ",
    "m", "n", "ɲ", "ŋ", "l", "ʁ", "j", "ɥ", "w",
))
PHONEMES = VOWELS | CONSONANTS
LICENSE_ID = "CC-BY-4.0"
LICENSE_URL = "https://creativecommons.org/licenses/by/4.0/"
LICENSE_TITLE = "Creative Commons Attribution 4.0 International"
UTC_SUFFIX = re.compile(r"(?:Z|\+00:00)\Z")
WORD_JOINERS = frozenset(("'", "’", "ʼ", "-", "‐", "‑"))

MANIFEST_ROOT_FIELDS = (
    "schemaVersion", "language", "courseId", "sections", "historicalSections",
)
SECTION_FIELDS = (
    "id", "kind", "title", "contentRevision", "policyRevision",
    "completionThresholdPercent", "items",
)
ITEM_FIELDS = (
    "id", "sentenceId", "audioRefId", "purpose", "reviewState", "targetSound",
    "targetLabel", "text", "debriefNote", "annotationRevision", "annotationHash",
    "tokens", "expectedTokenIds", "originalPath", "clipPath", "originalSha256",
    "clipSha256",
)
TOKEN_FIELDS = ("id", "text", "phonemes")
PACKAGE_ROOT_FIELDS = ("schemaVersion", "entries")
PROVENANCE_FIELDS = ("itemId", "source", "original", "clip", "derivation", "credit", "rightsReview")
SOURCE_FIELDS = (
    "repository", "revision", "config", "split", "rowId", "audioPath",
    "retrievalUrl", "retrievedAt", "rawTranscription", "transcription", "rawTsvRecord",
)
MEASUREMENT_FIELDS = (
    "path", "sha256", "byteLength", "sampleRate", "channels", "sampleWidth",
    "frameCount", "durationSeconds",
)
DERIVATION_FIELDS = (
    "startFrame", "endFrame", "tool", "version", "settings", "changes",
    "transcriptCorrectionRationale",
)
CREDIT_FIELDS = (
    "creator", "attribution", "licenseId", "licenseUrl", "licenseTextPath",
    "notices", "evidenceIds",
)
ANNOTATION_FIELDS = (
    "itemId", "annotationRevision", "annotationHash", "tool", "rawSentenceIpa",
    "draftTokenPhonemes", "corrections", "frenchAudioReview",
)
ANNOTATION_TOOL_FIELDS = ("name", "version", "settings", "inputSha256")
CORRECTION_FIELDS = ("tokenId", "before", "after", "rationale")
REVIEW_FIELDS = (
    "status", "reviewer", "qualification", "reviewedAt", "originalSha256",
    "clipSha256", "annotationHash", "evidenceIds", "notes",
)
EVIDENCE_FIELDS = ("id", "url", "retrievedAt", "sha256", "text", "scope", "itemIds")


class _DuplicateKey(ValueError):
    pass


def _object_without_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise _DuplicateKey(f"duplicate JSON object key {key!r}")
        result[key] = value
    return result


def _reject_constant(value):
    raise ValueError(f"non-finite JSON number {value}")


def _bounded_read(path, limit):
    with Path(path).open("rb") as stream:
        data = stream.read(limit + 1)
    if len(data) > limit:
        return None
    return data


def _is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _is_unicode_scalar_string(value):
    if not isinstance(value, str):
        return False
    try:
        value.encode("utf-8", errors="strict")
    except UnicodeEncodeError:
        return False
    return True


def _nonblank(value):
    return isinstance(value, str) and bool(value.strip())


def _positive_finite_number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return False
    try:
        return math.isfinite(value) and value > 0
    except OverflowError:
        return False


def _is_exact_excerpt(excerpt, source):
    start = source.find(excerpt)
    while start >= 0:
        end = start + len(excerpt)
        left_ok = start == 0 or not _word_component(source[start - 1])
        right_ok = end == len(source) or not _word_component(source[end])
        if left_ok and right_ok:
            return True
        start = source.find(excerpt, start + 1)
    return False


def _is_utc_timestamp(value):
    if not isinstance(value, str) or not UTC_SUFFIX.search(value):
        return False
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00" if value.endswith("Z") else value)
    except ValueError:
        return False
    return parsed.utcoffset() is not None and parsed.utcoffset().total_seconds() == 0


def _word_character(character):
    return unicodedata.category(character)[0] in ("L", "N")


def _word_component(character):
    return (character in WORD_JOINERS
            or unicodedata.category(character)[0] in ("L", "M", "N"))


def _word_spans(text):
    """Return selectable word spans; punctuation remains in the intervening text."""
    spans = []
    index = 0
    while index < len(text):
        if not _word_character(text[index]):
            index += 1
            continue
        start = index
        index += 1
        while index < len(text):
            category = unicodedata.category(text[index])[0]
            if category in ("L", "M", "N"):
                index += 1
                continue
            if (text[index] in WORD_JOINERS and index + 1 < len(text)
                    and _word_character(text[index + 1])):
                index += 2
                while index < len(text) and unicodedata.category(text[index])[0] in ("L", "M", "N"):
                    index += 1
                continue
            break
        spans.append((start, index))
    return spans


class _Verifier:
    def __init__(self, root, require_reviewed):
        self.root_arg = Path(root)
        self.root = self.root_arg
        self.require_reviewed = require_reviewed
        self.errors = []
        self.documents = {}
        self.items = []
        self.items_by_id = {}
        self.provenance_by_id = {}
        self.annotations_by_id = {}
        self.evidence_by_id = {}
        self.item_results = {}
        self.section_results = {}
        self.invalid_evidence_ids = set()
        self.invalid_evidence_document = False

    def error(self, path, message):
        self.errors.append(f"{path}: {message}")

    def run(self):
        if self.root_arg.is_symlink():
            self.error("package root", "must not be a symlink")
            return self.errors
        try:
            if not self.root_arg.is_dir():
                self.error("package root", "must be an existing directory")
                return self.errors
            self.root = self.root_arg.resolve(strict=True)
        except OSError as exc:
            self.error("package root", f"cannot access directory ({exc.strerror or type(exc).__name__})")
            return self.errors

        for filename in ("manifest.json", "provenance.json", "annotations.json", "source-evidence.json"):
            self.documents[filename] = self._read_json(filename)

        self._validate_manifest_root()
        self._validate_collection_root("provenance.json")
        self._validate_collection_root("annotations.json")
        evidence_root_error_count = len(self.errors)
        self._validate_collection_root("source-evidence.json")
        self.invalid_evidence_document = len(self.errors) > evidence_root_error_count
        self._build_item_index()
        self._build_evidence_index()
        self._build_associations("provenance.json", self.provenance_by_id)
        self._build_associations("annotations.json", self.annotations_by_id)

        if self.items:
            for section_index, section in enumerate(self._sections()):
                if not isinstance(section, dict):
                    continue
                section_id = section.get("id")
                result_key = (section_id if isinstance(section_id, str)
                              else f"invalid-section-{section_index}")
                section_path = f"manifest.json.sections[{section_index}]"
                section_items = section.get("items")
                if not isinstance(section_items, list):
                    continue
                qualified = []
                for item_index, item in enumerate(section_items):
                    if not isinstance(item, dict):
                        continue
                    item_id = item.get("id")
                    item_path = f"{section_path}.items[{item_index}]"
                    item_error_count = len(self.errors)
                    result = self._validate_item(item, item_path)
                    result = result and len(self.errors) == item_error_count
                    if isinstance(item_id, str):
                        self.item_results[item_id] = result
                    qualified.append(result)
                if len(qualified) == 5:
                    self.section_results[result_key] = all(qualified)
                else:
                    self.section_results[result_key] = False
            self._validate_mixed_contexts()

        unqualified = len(self.items) - sum(bool(value) for value in self.item_results.values())
        if self.require_reviewed and unqualified:
            suffix = "candidate is" if unqualified == 1 else "candidates are"
            self.error("review gate", f"--require-reviewed: {unqualified} {suffix} unqualified")
        return self.errors

    def _read_json(self, filename):
        path = self.root / filename
        try:
            info = path.lstat()
        except OSError:
            self.error(filename, "required metadata file is missing or unreadable")
            return None
        if stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode):
            self.error(filename, "must be a regular file, not a symlink")
            return None
        if info.st_size > MAX_JSON_BYTES:
            self.error(filename, "exceeds 16 MiB input limit")
            return None
        try:
            raw = _bounded_read(path, MAX_JSON_BYTES)
        except OSError as exc:
            self.error(filename, f"cannot read metadata ({exc.strerror or type(exc).__name__})")
            return None
        if raw is None:
            self.error(filename, "exceeds 16 MiB input limit")
            return None
        try:
            text = raw.decode("utf-8", errors="strict")
        except UnicodeDecodeError:
            self.error(filename, "must be valid UTF-8 JSON")
            return None
        try:
            return json.loads(text, object_pairs_hook=_object_without_duplicate_keys,
                              parse_constant=_reject_constant)
        except _DuplicateKey as exc:
            self.error(filename, str(exc))
        except json.JSONDecodeError as exc:
            self.error(filename, f"invalid JSON at line {exc.lineno} column {exc.colno}")
        except ValueError as exc:
            self.error(filename, str(exc))
        except RecursionError:
            self.error(filename, "JSON nesting exceeds supported depth")
        return None

    def _object(self, value, path, fields):
        if not isinstance(value, dict):
            self.error(path, "must be an object")
            return False
        for field in fields:
            if field not in value:
                self.error(path, f"missing required field '{field}'")
        allowed = set(fields)
        for field in sorted(set(value) - allowed):
            self.error(path, f"unknown field {field!r}")
        return True

    def _schema_version(self, value, path):
        if not _is_int(value) or value != 1:
            self.error(path, "expected integer 1")

    def _list(self, value, path):
        if not isinstance(value, list):
            self.error(path, "must be an array")
            return False
        return True

    def _string(self, value, path, nonblank=True):
        if not isinstance(value, str) or (nonblank and not value.strip()):
            qualifier = "nonblank " if nonblank else ""
            self.error(path, f"must be a {qualifier}string")
            return False
        if not _is_unicode_scalar_string(value):
            self.error(path, "must contain only valid Unicode scalar values")
            return False
        return True

    def _positive_int(self, value, path):
        if not _is_int(value) or value <= 0:
            self.error(path, "must be a strict positive integer")
            return False
        return True

    def _sha(self, value, path):
        if not valid_sha256(value):
            self.error(path, "must be a lowercase 64-character SHA-256")
            return False
        return True

    def _timestamp(self, value, path):
        if not _is_utc_timestamp(value):
            self.error(path, "must be an explicit UTC timestamp")
            return False
        return True

    def _validate_manifest_root(self):
        value = self.documents.get("manifest.json")
        if value is None:
            return
        if not self._object(value, "manifest.json", MANIFEST_ROOT_FIELDS):
            return
        self._schema_version(value.get("schemaVersion"), "manifest.json.schemaVersion")
        if value.get("language") != "fr":
            self.error("manifest.json.language", "must be 'fr'")
        if value.get("courseId") != "en-fr":
            self.error("manifest.json.courseId", "must be 'en-fr'")
        historical = value.get("historicalSections")
        if self._list(historical, "manifest.json.historicalSections") and historical:
            self.error("manifest.json.historicalSections", "non-empty history is unsupported")
        sections = value.get("sections")
        if not self._list(sections, "manifest.json.sections"):
            return
        if len(sections) != 3:
            self.error("manifest.json.sections", "must contain exactly three authored sections")
        ids = [section.get("id") if isinstance(section, dict) else None for section in sections]
        if tuple(ids) != SECTION_IDS:
            self.error("manifest.json.sections", "section IDs/order must be vowels, consonants, then mixed")
        for section_index, section in enumerate(sections):
            path = f"manifest.json.sections[{section_index}]"
            if not self._object(section, path, SECTION_FIELDS):
                continue
            expected_index = section_index if section_index < 3 else None
            if expected_index is not None:
                expected_id = SECTION_IDS[expected_index]
                expected_kind = SECTION_KINDS[expected_index]
                if section.get("id") != expected_id:
                    self.error(f"{path}.id", f"must be '{expected_id}'")
                if section.get("kind") != expected_kind:
                    self.error(f"{path}.kind", f"must be '{expected_kind}'")
            self._string(section.get("title"), f"{path}.title")
            for field in ("contentRevision", "policyRevision"):
                if not _is_int(section.get(field)) or section.get(field) != 1:
                    self.error(f"{path}.{field}", "expected integer 1")
            threshold = section.get("completionThresholdPercent")
            if not _is_int(threshold) or threshold != 80:
                self.error(f"{path}.completionThresholdPercent", "expected integer 80")
            items = section.get("items")
            if not self._list(items, f"{path}.items"):
                continue
            if len(items) != 5:
                self.error(f"{path}.items", "must contain exactly five authored items")
            if section_index < len(ITEM_PREFIXES):
                expected_item_ids = tuple(
                    f"{ITEM_PREFIXES[section_index]}-{item_index:02}"
                    for item_index in range(1, 6))
                actual_ids = tuple(item.get("id") if isinstance(item, dict) else None
                                   for item in items)
                if actual_ids != expected_item_ids:
                    self.error(f"{path}.items", "item IDs/order must match the five authored IDs")
            for item_index, item in enumerate(items):
                item_path = f"{path}.items[{item_index}]"
                if not self._object(item, item_path, ITEM_FIELDS):
                    continue
                for field in ("id", "sentenceId", "audioRefId", "targetSound", "targetLabel",
                              "text", "debriefNote", "originalPath", "clipPath"):
                    self._string(item.get(field), f"{item_path}.{field}")
                if item.get("purpose") != "practice":
                    self.error(f"{item_path}.purpose", "must be 'practice'")
                if item.get("reviewState") not in ("pending", "reviewed"):
                    self.error(f"{item_path}.reviewState", "must be 'pending' or 'reviewed'")
                revision = item.get("annotationRevision")
                if not _is_int(revision) or revision < 1:
                    self.error(f"{item_path}.annotationRevision", "must be a strict positive integer")
                self._sha(item.get("annotationHash"), f"{item_path}.annotationHash")
                self._sha(item.get("originalSha256"), f"{item_path}.originalSha256")
                self._sha(item.get("clipSha256"), f"{item_path}.clipSha256")
                tokens = item.get("tokens")
                if self._list(tokens, f"{item_path}.tokens"):
                    for token_index, token in enumerate(tokens):
                        token_path = f"{item_path}.tokens[{token_index}]"
                        if not self._object(token, token_path, TOKEN_FIELDS):
                            continue
                        self._string(token.get("id"), f"{token_path}.id")
                        self._string(token.get("text"), f"{token_path}.text")
                        phonemes = token.get("phonemes")
                        if self._list(phonemes, f"{token_path}.phonemes"):
                            for phoneme_index, phoneme in enumerate(phonemes):
                                self._string(phoneme, f"{token_path}.phonemes[{phoneme_index}]")
                expected_ids = item.get("expectedTokenIds")
                if self._list(expected_ids, f"{item_path}.expectedTokenIds"):
                    for expected_index, token_id in enumerate(expected_ids):
                        self._string(token_id, f"{item_path}.expectedTokenIds[{expected_index}]")
                self.items.append((section_index, item_index, item, item_path))

    def _validate_collection_root(self, filename):
        value = self.documents.get(filename)
        if value is None:
            return
        if not self._object(value, filename, PACKAGE_ROOT_FIELDS):
            return
        self._schema_version(value.get("schemaVersion"), f"{filename}.schemaVersion")
        if self._list(value.get("entries"), f"{filename}.entries"):
            for index, entry in enumerate(value["entries"]):
                path = f"{filename}.entries[{index}]"
                if filename == "provenance.json":
                    self._object(entry, path, PROVENANCE_FIELDS)
                elif filename == "annotations.json":
                    self._object(entry, path, ANNOTATION_FIELDS)
                else:
                    self._object(entry, path, EVIDENCE_FIELDS)

    def _sections(self):
        manifest = self.documents.get("manifest.json")
        if isinstance(manifest, dict) and isinstance(manifest.get("sections"), list):
            return manifest["sections"]
        return []

    def _build_item_index(self):
        seen_fields = {"id": set(), "sentenceId": set(), "audioRefId": set(),
                       "originalPath": set(), "clipPath": set()}
        source_items = {}
        for _, _, item, path in self.items:
            item_id = item.get("id")
            if isinstance(item_id, str):
                if item_id in self.items_by_id:
                    self.error(f"{path}.id", f"item ID {item_id!r} is not unique")
                else:
                    self.items_by_id[item_id] = item
            for field in seen_fields:
                value = item.get(field)
                if not isinstance(value, str) or not value:
                    continue
                if value in seen_fields[field]:
                    if field == "id":
                        continue
                    self.error(f"{path}.{field}", f"{field} {value!r} is not unique")
                seen_fields[field].add(value)

    def _build_evidence_index(self):
        document = self.documents.get("source-evidence.json")
        if not isinstance(document, dict) or not isinstance(document.get("entries"), list):
            return
        known_item_ids = set(self.items_by_id)
        for index, entry in enumerate(document["entries"]):
            path = f"source-evidence.json.entries[{index}]"
            if not isinstance(entry, dict):
                continue
            evidence_id = entry.get("id")
            if not isinstance(evidence_id, str) or not evidence_id:
                self.error(f"{path}.id", "must be a nonblank string")
                continue
            if evidence_id in self.evidence_by_id:
                self.error(f"{path}.id", f"duplicate source-evidence ID {evidence_id!r}")
                self.invalid_evidence_ids.add(evidence_id)
                continue
            self.evidence_by_id[evidence_id] = entry
            if set(entry) != set(EVIDENCE_FIELDS):
                self.invalid_evidence_ids.add(evidence_id)
            errors_before = len(self.errors)
            self._validate_evidence_entry(entry, path, known_item_ids)
            if len(self.errors) > errors_before:
                self.invalid_evidence_ids.add(evidence_id)

    def _validate_evidence_entry(self, entry, path, known_item_ids):
        self._string(entry.get("id"), f"{path}.id")
        self._url(entry.get("url"), f"{path}.url")
        self._timestamp(entry.get("retrievedAt"), f"{path}.retrievedAt")
        self._sha(entry.get("sha256"), f"{path}.sha256")
        text = entry.get("text")
        if self._string(text, f"{path}.text"):
            try:
                text_bytes = text.encode("utf-8", errors="strict")
                if len(text_bytes) > MAX_EVIDENCE_TEXT_BYTES:
                    self.error(f"{path}.text", "exceeds 2 MiB input limit")
                elif hashlib.sha256(text_bytes).hexdigest() != entry.get("sha256"):
                    self.error(f"{path}.sha256", "source-evidence sha256 does not match UTF-8 text")
            except UnicodeEncodeError:
                self.error(f"{path}.text", "contains invalid Unicode scalar data")
        scope = entry.get("scope")
        item_ids = entry.get("itemIds")
        if scope not in ("dataset", "tool", "item"):
            self.error(f"{path}.scope", "source-evidence scope must be dataset, tool, or item")
        if not isinstance(item_ids, list):
            self.error(f"{path}.itemIds", "must be an array")
        else:
            if any(not isinstance(value, str) for value in item_ids):
                self.error(f"{path}.itemIds", "must contain only item ID strings")
            if len(set(value for value in item_ids if isinstance(value, str))) != len(item_ids):
                self.error(f"{path}.itemIds", "must contain unique item IDs")
            for item_id in item_ids:
                if isinstance(item_id, str) and item_id not in known_item_ids:
                    self.error(f"{path}.itemIds", f"source-evidence itemIds contains unknown item {item_id!r}")
            if scope in ("dataset", "tool") and item_ids:
                self.error(f"{path}.itemIds", f"{scope} evidence itemIds must be empty")
            if scope == "item" and not item_ids:
                self.error(f"{path}.itemIds", "item evidence must cover at least one item")

    def _build_associations(self, filename, result):
        document = self.documents.get(filename)
        if not isinstance(document, dict) or not isinstance(document.get("entries"), list):
            return
        for index, entry in enumerate(document["entries"]):
            path = f"{filename}.entries[{index}]"
            if not isinstance(entry, dict):
                continue
            item_id = entry.get("itemId")
            if not isinstance(item_id, str) or not item_id:
                self.error(f"{path}.itemId", "must be a nonblank item ID string")
                continue
            if item_id in result:
                self.error(f"{filename}.entries", f"duplicate itemId {item_id!r}")
                continue
            if item_id not in self.items_by_id:
                self.error(f"{filename}.entries", f"orphan itemId {item_id!r}")
            result[item_id] = entry
        for _, _, item, _ in self.items:
            item_id = item.get("id")
            if isinstance(item_id, str) and item_id not in result:
                self.error(f"{filename}.entries", f"missing item entry for {item_id}")

    def _validate_item(self, item, path):
        initial_error_count = len(self.errors)
        structurally_valid = True
        item_id = item.get("id")
        provenance = self.provenance_by_id.get(item_id) if isinstance(item_id, str) else None
        annotation = self.annotations_by_id.get(item_id) if isinstance(item_id, str) else None
        section_index = next((section_index for section_index, _, candidate, _ in self.items
                              if candidate is item), None)
        kind = SECTION_KINDS[section_index] if section_index is not None and section_index < 3 else None
        token_ids, token_map = self._validate_tokens(item, path)
        target = item.get("targetSound")
        if not isinstance(target, str) or target not in PHONEMES:
            self.error(f"{path}.targetSound", "must be a known sentence-local IPA phoneme")
            structurally_valid = False
        elif kind in ("vowels", "consonants"):
            expected_class = VOWELS if kind == "vowels" else CONSONANTS
            if target not in expected_class:
                self.error(f"{path}.targetSound",
                           f"targetSound {target!r} is not a {kind[:-1] if kind == 'vowels' else 'consonant'} target for section kind {kind!r}")
                structurally_valid = False

        expected_ids = item.get("expectedTokenIds")
        if isinstance(expected_ids, list) and isinstance(target, str) and isinstance(item.get("tokens"), list):
            matched_ids = []
            non_target = False
            for token in item["tokens"]:
                if not isinstance(token, dict) or not isinstance(token.get("id"), str):
                    continue
                phonemes = token.get("phonemes")
                if isinstance(phonemes, list) and target in phonemes:
                    matched_ids.append(token["id"])
                elif isinstance(phonemes, list):
                    non_target = True
            if expected_ids != matched_ids:
                self.error(f"{path}.expectedTokenIds",
                           "expectedTokenIds must equal authored-order targetSound membership")
                structurally_valid = False
            if not matched_ids:
                self.error(path, "sentence needs at least one word matching targetSound")
                structurally_valid = False
            if not non_target:
                self.error(path, "sentence needs at least one genuine non-target word")
                structurally_valid = False

        if not self._validate_text_coverage(item, path):
            structurally_valid = False
        for field, directory in (("originalPath", "originals"), ("clipPath", "clips")):
            if self._safe_file(item.get(field), directory, f"{path}.{field}",
                               MAX_AUDIO_BYTES) is None:
                structurally_valid = False
        if not self._validate_provenance(item, provenance, path):
            structurally_valid = False
        if not self._validate_annotation(item, annotation, token_ids, token_map, path):
            structurally_valid = False

        reviews_valid = True
        rights_status = None
        french_status = None
        if isinstance(provenance, dict):
            rights_status, valid = self._validate_review(
                provenance.get("rightsReview"), item, path, "rightsReview")
            reviews_valid = reviews_valid and valid
        else:
            reviews_valid = False
        if isinstance(annotation, dict):
            french_status, valid = self._validate_review(
                annotation.get("frenchAudioReview"), item, path, "frenchAudioReview")
            reviews_valid = reviews_valid and valid
        else:
            reviews_valid = False

        reviewed = item.get("reviewState") == "reviewed"
        if reviewed and (rights_status != "accepted" or french_status != "accepted"):
            self.error(path, "reviewState reviewed requires accepted French/audio and rights decisions")
            reviews_valid = False
        qualifies = (structurally_valid and reviews_valid and reviewed
                     and rights_status == "accepted" and french_status == "accepted"
                     and len(self.errors) == initial_error_count)
        return qualifies

    def _validate_tokens(self, item, path):
        tokens = item.get("tokens")
        token_ids = []
        token_map = {}
        if not isinstance(tokens, list):
            return token_ids, token_map
        for token_index, token in enumerate(tokens):
            token_path = f"{path}.tokens[{token_index}]"
            if not isinstance(token, dict):
                continue
            token_id = token.get("id")
            token_text = token.get("text")
            if isinstance(token_id, str):
                if token_id in token_map:
                    self.error(f"{path}.tokens", "token IDs must be unique within an item")
                else:
                    token_map[token_id] = token
                token_ids.append(token_id)
            phonemes = token.get("phonemes")
            if not isinstance(phonemes, list):
                continue
            if not phonemes:
                self.error(f"{token_path}.phonemes", "must contain at least one phoneme label")
            seen = set()
            for phoneme_index, phoneme in enumerate(phonemes):
                phoneme_path = f"{token_path}.phonemes[{phoneme_index}]"
                if not _nonblank(phoneme):
                    continue
                if phoneme not in PHONEMES:
                    self.error(phoneme_path, f"unknown phoneme label {phoneme!r}")
                if phoneme in seen:
                    self.error(f"{token_path}.phonemes", "phoneme labels must be unique within each token")
                seen.add(phoneme)
            if isinstance(token_text, str):
                spans = _word_spans(token_text)
                if len(spans) != 1 or spans[0] != (0, len(token_text)):
                    self.error(f"{token_path}.text",
                               "token text must be one punctuation-free selectable word")
        return token_ids, token_map

    def _validate_text_coverage(self, item, path):
        text = item.get("text")
        tokens = item.get("tokens")
        if not isinstance(text, str) or not isinstance(tokens, list):
            return False
        spans = _word_spans(text)
        unsupported = False
        cursor = 0
        for start, end in spans + [(len(text), len(text))]:
            for index in range(cursor, start):
                character = text[index]
                if character.isspace() or unicodedata.category(character)[0] == "P":
                    continue
                self.error(f"{path}.text", f"whitespace gaps may contain punctuation only (offset {index})")
                unsupported = True
                break
            if unsupported:
                break
            cursor = end
        token_texts = [token.get("text") for token in tokens if isinstance(token, dict)]
        words = [text[start:end] for start, end in spans]
        if token_texts != words:
            self.error(path, "tokens do not exactly cover selectable words in text")
            return False
        return not unsupported

    def _validate_provenance(self, item, entry, path):
        if not isinstance(entry, dict):
            return False
        valid = True
        entry_path = f"provenance[{item.get('id', '?')}]"
        source = entry.get("source")
        if self._object(source, f"{entry_path}.source", SOURCE_FIELDS):
            expected_source = {
                "repository": "google/fleurs", "revision": REVISION,
                "config": "fr_fr", "split": "train", "retrievalUrl": TSV_URL,
            }
            for field, expected in expected_source.items():
                if source.get(field) != expected:
                    labels = {
                        "revision": "pinned FLEURS revision",
                        "repository": "google/fleurs repository",
                        "config": "fr_fr configuration",
                        "split": "train split",
                        "retrievalUrl": "pinned FLEURS TSV URL",
                    }
                    self.error(f"{entry_path}.source.{field}",
                               f"does not match {labels[field]}")
                    valid = False
            for field in ("rowId", "audioPath", "rawTranscription", "transcription", "rawTsvRecord"):
                if not self._string(source.get(field), f"{entry_path}.source.{field}"):
                    valid = False
            if not self._timestamp(source.get("retrievedAt"), f"{entry_path}.source.retrievedAt"):
                valid = False
            raw_record = source.get("rawTsvRecord")
            rows = []
            if isinstance(raw_record, str) and "\n" not in raw_record and "\r" not in raw_record:
                try:
                    rows = parse_fleurs_train_tsv(raw_record)
                except SentencePackageError:
                    rows = []
            if len(rows) != 1:
                self.error(f"{entry_path}.source.rawTsvRecord",
                           "source.rawTsvRecord must be exactly one valid seven-field FLEURS record")
                valid = False
            else:
                row = rows[0]
                if source.get("rowId") != row["id"]:
                    self.error(f"{entry_path}.source.rowId", "source.rowId does not match rawTsvRecord id")
                    valid = False
                if source.get("audioPath") != row["filename"]:
                    self.error(f"{entry_path}.source.audioPath", "source.audioPath does not match rawTsvRecord filename")
                    valid = False
                if source.get("rawTranscription") != row["raw_transcription"]:
                    self.error(f"{entry_path}.source.rawTranscription", "source.rawTranscription does not match rawTsvRecord")
                    valid = False
                if source.get("transcription") != row["transcription"]:
                    self.error(f"{entry_path}.source.transcription", "source.transcription does not match rawTsvRecord")
                    valid = False
                self._unique_source_identity(row["id"], row["filename"], entry_path)
        else:
            valid = False

        measurements = {}
        for role in ("original", "clip"):
            measure = entry.get(role)
            measure_path = f"{entry_path}.{role}"
            if not self._object(measure, measure_path, MEASUREMENT_FIELDS):
                valid = False
                continue
            expected_path = item.get("originalPath" if role == "original" else "clipPath")
            if measure.get("path") != expected_path:
                self.error(f"{measure_path}.path", f"does not match manifest {role}Path")
                valid = False
            self._sha(measure.get("sha256"), f"{measure_path}.sha256")
            self._positive_int(measure.get("byteLength"), f"{measure_path}.byteLength")
            for field in ("sampleRate", "channels", "sampleWidth", "frameCount"):
                self._positive_int(measure.get(field), f"{measure_path}.{field}")
            duration = measure.get("durationSeconds")
            if not _positive_finite_number(duration):
                self.error(f"{measure_path}.durationSeconds", "must be a strict positive finite number")
            relative = measure.get("path")
            expected_directory = "originals" if role == "original" else "clips"
            file_path = self._safe_file(relative, expected_directory, measure_path,
                                        MAX_AUDIO_BYTES)
            if file_path is None:
                valid = False
                continue
            audio = self._read_wav(file_path, measure_path)
            if audio is None:
                valid = False
                continue
            actual, frames = audio
            measurements[role] = (actual, frames)
            for field, actual_value in actual.items():
                if field == "path":
                    continue
                if field == "durationSeconds":
                    supplied = measure.get(field)
                    if (not _positive_finite_number(supplied)
                            or not math.isclose(supplied, actual_value, rel_tol=0, abs_tol=1e-12)):
                        self.error(f"{measure_path}.{field}", "does not match actual WAV duration")
                        valid = False
                elif measure.get(field) != actual_value:
                    label = "SHA-256" if field == "sha256" else "actual WAV"
                    self.error(f"{measure_path}.{field}", f"does not match {label}")
                    valid = False
            expected_hash_field = "originalSha256" if role == "original" else "clipSha256"
            if item.get(expected_hash_field) != actual["sha256"]:
                self.error(f"{path}.{expected_hash_field}",
                           f"manifest {expected_hash_field} does not match actual {role} file")
                valid = False

        if "original" in measurements and "clip" in measurements:
            original, original_frames = measurements["original"]
            clip, clip_frames = measurements["clip"]
            derivation = entry.get("derivation")
            derivation_path = f"{entry_path}.derivation"
            derivation_valid = self._validate_derivation(derivation, derivation_path)
            if derivation_valid:
                start, end = derivation["startFrame"], derivation["endFrame"]
                if start < 0 or end <= start or end > original["frameCount"]:
                    self.error(derivation_path, "frame range must be bounded in source and nonempty")
                    valid = False
                else:
                    if (original["sampleRate"] != clip["sampleRate"]
                            or original["channels"] != clip["channels"]
                            or original["sampleWidth"] != clip["sampleWidth"]):
                        self.error(f"{entry_path}.clip", "clip PCM rate/channels/sample width differ from source")
                        valid = False
                    frame_size = original["channels"] * original["sampleWidth"]
                    if clip["frameCount"] != end - start:
                        self.error(f"{entry_path}.clip.frameCount",
                                   "must equal derivation endFrame - startFrame")
                        valid = False
                    expected_frames = original_frames[start * frame_size:end * frame_size]
                    if clip_frames != expected_frames:
                        self.error(f"{entry_path}.clip", "clip PCM is not the exact claimed source frame slice")
                        valid = False
            else:
                valid = False
            if isinstance(derivation, dict):
                correction = derivation.get("transcriptCorrectionRationale")
                source = entry.get("source")
                source_text = source.get("transcription") if isinstance(source, dict) else None
                item_text = item.get("text")
                if (isinstance(item_text, str) and isinstance(source_text, str)
                        and not _is_exact_excerpt(item_text, source_text)
                        and not _nonblank(correction)):
                    self.error(f"{derivation_path}.transcriptCorrectionRationale",
                               "transcriptCorrectionRationale is required when item text is not an exact source excerpt")
                    valid = False
            source = entry.get("source")
            if isinstance(source, dict) and "original" in measurements:
                record = source.get("rawTsvRecord")
                try:
                    rows = parse_fleurs_train_tsv(record) if isinstance(record, str) else []
                except SentencePackageError:
                    rows = []
                if len(rows) == 1 and rows[0]["num_samples"] != str(original["frameCount"]):
                    self.error(f"{entry_path}.source.rawTsvRecord",
                               "source num_samples does not match actual original frame count")
                    valid = False

        credit = entry.get("credit")
        if self._object(credit, f"{entry_path}.credit", CREDIT_FIELDS):
            if not self._string(credit.get("creator"), f"{entry_path}.credit.creator"):
                self.errors[-1] = f"{entry_path}.credit.creator: must be a nonblank source-supplied attribution"
                valid = False
            if not self._string(credit.get("attribution"), f"{entry_path}.credit.attribution"):
                valid = False
            if credit.get("licenseId") != LICENSE_ID:
                self.error(f"{entry_path}.credit.licenseId", "credit.licenseId must be 'CC-BY-4.0'")
                valid = False
            if credit.get("licenseUrl") != LICENSE_URL:
                self.error(f"{entry_path}.credit.licenseUrl", "must be the canonical CC BY 4.0 URL")
                valid = False
            notices = credit.get("notices")
            if not isinstance(notices, list) or not notices or any(not _nonblank(note) for note in notices):
                self.error(f"{entry_path}.credit.notices", "must be a nonempty list of nonblank notices")
                valid = False
            evidence_ids = credit.get("evidenceIds")
            if not self._validate_citations(evidence_ids, item.get("id"),
                                            f"{entry_path}.credit.evidenceIds", require=True):
                valid = False
            license_path = credit.get("licenseTextPath")
            license_file = self._safe_file(license_path, "licenses",
                                           f"{entry_path}.credit.licenseTextPath",
                                           MAX_LICENSE_BYTES)
            if license_file is None:
                valid = False
            else:
                try:
                    legal_bytes = _bounded_read(license_file, MAX_LICENSE_BYTES)
                    if legal_bytes is None:
                        raise OSError("license text exceeds 2 MiB input limit")
                    legal_text = legal_bytes.decode("utf-8", errors="strict")
                except (OSError, UnicodeDecodeError):
                    self.error(f"{entry_path}.credit.licenseTextPath", "license text must be readable UTF-8")
                    valid = False
                else:
                    if not _nonblank(legal_text) or LICENSE_TITLE not in legal_text or LICENSE_URL not in legal_text:
                        self.error(f"{entry_path}.credit.licenseTextPath",
                                   "license text must be nonblank and identify CC BY 4.0")
                        valid = False
        else:
            valid = False
        return valid

    def _unique_source_identity(self, row_id, audio_path, path):
        row_ids = getattr(self, "_source_row_ids", None)
        if row_ids is None:
            self._source_row_ids = set()
            self._source_audio_paths = set()
            row_ids, audio_paths = self._source_row_ids, self._source_audio_paths
        else:
            audio_paths = self._source_audio_paths
        if row_id in row_ids:
            self.error(f"{path}.source.rowId", f"source rowId {row_id!r} is not unique")
        row_ids.add(row_id)
        if audio_path in audio_paths:
            self.error(f"{path}.source.audioPath", f"source audioPath {audio_path!r} is not unique")
        audio_paths.add(audio_path)

    def _validate_derivation(self, value, path):
        if not self._object(value, path, DERIVATION_FIELDS):
            return False
        valid = True
        for field in ("startFrame", "endFrame"):
            if not _is_int(value.get(field)):
                self.error(f"{path}.{field}", "derivation.startFrame/endFrame must be strict integers")
                valid = False
        for field in ("tool", "version"):
            if not self._string(value.get(field), f"{path}.{field}"):
                valid = False
        settings = value.get("settings")
        if not isinstance(settings, list) or not settings or any(not _nonblank(item) for item in settings):
            self.error(f"{path}.settings", "must be a nonempty ordered list of nonblank strings")
            valid = False
        changes = value.get("changes")
        if not isinstance(changes, list) or any(not _nonblank(item) for item in changes):
            self.error(f"{path}.changes", "must be an ordered list of nonblank strings")
            valid = False
        rationale = value.get("transcriptCorrectionRationale")
        if not isinstance(rationale, str):
            self.error(f"{path}.transcriptCorrectionRationale", "must be a string (empty when no correction was needed)")
            valid = False
        return valid

    def _validate_annotation(self, item, entry, token_ids, token_map, path):
        if not isinstance(entry, dict):
            return False
        valid = True
        entry_path = f"annotations[{item.get('id', '?')}]"
        revision = entry.get("annotationRevision")
        if not _is_int(revision) or revision != item.get("annotationRevision"):
            self.error(f"{entry_path}.annotationRevision", "does not match manifest annotationRevision")
            valid = False
        actual_hash = None
        try:
            actual_hash = annotation_hash(item)
        except SentencePackageError as exc:
            self.error(path, f"cannot compute final annotation hash ({exc})")
            valid = False
        except UnicodeEncodeError:
            self.error(f"{path}.text", "annotation contains invalid Unicode scalar data")
            valid = False
        if actual_hash is not None:
            if item.get("annotationHash") != actual_hash:
                self.error(f"{path}.annotationHash", "manifest annotationHash does not match computed final annotation hash")
                valid = False
            if entry.get("annotationHash") != actual_hash:
                self.error(f"{entry_path}.annotationHash", "annotations.annotationHash does not match computed final annotation hash")
                valid = False

        tool = entry.get("tool")
        if self._object(tool, f"{entry_path}.tool", ANNOTATION_TOOL_FIELDS):
            for field in ("name", "version"):
                if not self._string(tool.get(field), f"{entry_path}.tool.{field}"):
                    valid = False
            settings = tool.get("settings")
            if not isinstance(settings, list) or not settings or any(not _nonblank(item) for item in settings):
                self.error(f"{entry_path}.tool.settings", "tool.settings must be an ordered list of nonblank strings")
                valid = False
            self._sha(tool.get("inputSha256"), f"{entry_path}.tool.inputSha256")
            text = item.get("text")
            if (isinstance(text, str) and _is_unicode_scalar_string(text)
                    and hashlib.sha256(text.encode("utf-8")).hexdigest() != tool.get("inputSha256")):
                self.error(f"{entry_path}.tool.inputSha256", "tool.inputSha256 does not match exact sentence text")
                valid = False
        else:
            valid = False
        if not self._string(entry.get("rawSentenceIpa"), f"{entry_path}.rawSentenceIpa"):
            valid = False
        if not self._validate_draft(entry.get("draftTokenPhonemes"), token_ids, token_map, entry_path):
            valid = False
        if not self._validate_corrections(entry.get("corrections"), token_ids, token_map,
                                          entry.get("draftTokenPhonemes"), entry_path):
            valid = False
        return valid

    def _validate_draft(self, value, token_ids, token_map, path):
        if value is None:
            return True
        if not isinstance(value, list):
            self.error(f"{path}.draftTokenPhonemes", "must be null or an ordered list of draft records")
            return False
        valid = True
        if not value:
            self.error(f"{path}.draftTokenPhonemes", "must be null or a nonempty ordered list of draft records")
            valid = False
        seen = set()
        ordered_positions = []
        token_positions = {token_id: index for index, token_id in enumerate(token_ids)}
        for index, draft in enumerate(value):
            draft_path = f"{path}.draftTokenPhonemes[{index}]"
            if not self._object(draft, draft_path, ("tokenId", "phonemes")):
                valid = False
                continue
            token_id = draft.get("tokenId")
            if not isinstance(token_id, str) or token_id not in token_map:
                self.error(f"{draft_path}.tokenId", f"draftTokenPhonemes tokenId {token_id!r} is not an item token")
                valid = False
                continue
            if token_id in seen:
                self.error(f"{draft_path}.tokenId", "draftTokenPhonemes token IDs must be unique")
                valid = False
            seen.add(token_id)
            ordered_positions.append(token_positions[token_id])
            phonemes = draft.get("phonemes")
            if not isinstance(phonemes, list) or not phonemes:
                self.error(f"{draft_path}.phonemes", "must be a nonempty list of known phoneme labels")
                valid = False
                continue
            if any(not _nonblank(value) or value not in PHONEMES for value in phonemes):
                self.error(f"{draft_path}.phonemes", "must contain only known nonblank phoneme labels")
                valid = False
            if len(set(value for value in phonemes if isinstance(value, str))) != len(phonemes):
                self.error(f"{draft_path}.phonemes", "phoneme labels must be unique in a draft token mapping")
                valid = False
        if ordered_positions != sorted(ordered_positions):
            self.error(f"{path}.draftTokenPhonemes", "draft records must follow authored token order")
            valid = False
        return valid

    def _validate_corrections(self, value, token_ids, token_map, draft_value, path):
        if not isinstance(value, list):
            self.error(f"{path}.corrections", "must be an ordered list")
            return False
        valid = True
        draft_map = {}
        if isinstance(draft_value, list):
            for draft in draft_value:
                if isinstance(draft, dict) and isinstance(draft.get("tokenId"), str):
                    draft_map[draft["tokenId"]] = draft.get("phonemes")
        prior_after = {}
        final_after = {}
        for index, correction in enumerate(value):
            correction_path = f"{path}.corrections[{index}]"
            if not self._object(correction, correction_path, CORRECTION_FIELDS):
                valid = False
                continue
            token_id = correction.get("tokenId")
            if not isinstance(token_id, str) or token_id not in token_map:
                self.error(f"{correction_path}.tokenId", "correction tokenId must refer to an item token")
                valid = False
                continue
            before = correction.get("before")
            after = correction.get("after")
            for field, labels in (("before", before), ("after", after)):
                if not isinstance(labels, list) or any(not _nonblank(label) or label not in PHONEMES for label in labels):
                    self.error(f"{correction_path}.{field}", "must be a list of known nonblank phoneme labels")
                    valid = False
                elif len(set(labels)) != len(labels):
                    self.error(f"{correction_path}.{field}", "phoneme labels must be unique")
                    valid = False
            if not self._string(correction.get("rationale"), f"{correction_path}.rationale"):
                valid = False
            expected_before = prior_after.get(token_id, draft_map.get(token_id, []))
            if isinstance(before, list) and before != expected_before:
                self.error(f"{correction_path}.before", "correction.before does not match retained draft mapping")
                valid = False
            prior_after[token_id] = after
            final_after[token_id] = after
        for token_id, after in final_after.items():
            token = token_map.get(token_id)
            if isinstance(token, dict) and after != token.get("phonemes"):
                self.error(f"{path}.corrections", "correction final after does not match manifest token phonemes")
                valid = False
        for token_id, phonemes in draft_map.items():
            token = token_map.get(token_id)
            if isinstance(token, dict) and phonemes != token.get("phonemes"):
                if token_id not in final_after:
                    self.error(f"{path}.corrections", "changed draft mapping requires a retained correction")
                    valid = False
                elif final_after[token_id] != token.get("phonemes"):
                    self.error(f"{path}.corrections", "correction final after does not match manifest token phonemes")
                    valid = False
        return valid

    def _validate_review(self, value, item, item_path, name):
        path = f"{item_path}.{name}"
        if not self._object(value, path, REVIEW_FIELDS):
            return None, False
        valid = True
        status = value.get("status")
        if status not in ("pending", "accepted", "rejected"):
            self.error(f"{path}.status", "must be pending, accepted, or rejected")
            return status, False
        if not self._string(value.get("notes"), f"{path}.notes", nonblank=False):
            valid = False
        if status == "pending":
            if any(value.get(field) is not None for field in ("reviewer", "qualification", "reviewedAt")):
                self.error(path, "pending review must have null reviewer, qualification, and reviewedAt")
                valid = False
            for field, item_field in (("originalSha256", "originalSha256"),
                                      ("clipSha256", "clipSha256"),
                                      ("annotationHash", "annotationHash")):
                candidate_hash = value.get(field)
                if candidate_hash is not None:
                    if (not valid_sha256(candidate_hash)
                            or candidate_hash != item.get(item_field)):
                        self.error(f"{path}.{field}",
                                   "pending hash must be null or match the current candidate identity")
                        valid = False
            evidence_ids = value.get("evidenceIds")
            if not isinstance(evidence_ids, list) or evidence_ids:
                self.error(f"{path}.evidenceIds", "pending review must have no acceptance evidence")
                valid = False
            return status, valid

        if not _nonblank(value.get("reviewer")) or not _nonblank(value.get("qualification")):
            self.error(path, "accepted/rejected review requires nonblank reviewer and qualification")
            valid = False
        if not self._timestamp(value.get("reviewedAt"), f"{path}.reviewedAt"):
            valid = False
        for field, item_field in (("originalSha256", "originalSha256"),
                                  ("clipSha256", "clipSha256"),
                                  ("annotationHash", "annotationHash")):
            if not self._sha(value.get(field), f"{path}.{field}"):
                valid = False
            elif value.get(field) != item.get(item_field):
                self.error(f"{path}.{field}", f"{name}.{field} does not match item {item_field}")
                valid = False
        evidence_ids = value.get("evidenceIds")
        if not self._validate_citations(evidence_ids, item.get("id"),
                                        f"{path}.evidenceIds", require=True):
            valid = False
        if status == "rejected" and not _nonblank(value.get("notes")):
            self.error(f"{path}.notes", "rejected review must retain a nonblank decision reason")
            valid = False
        return status, valid

    def _validate_citations(self, values, item_id, path, require):
        if not isinstance(values, list):
            self.error(path, "must be an array of resolvable evidence IDs")
            return False
        if require and not values:
            self.error(path, "must cite nonempty resolvable item/dataset evidence")
            return False
        valid = True
        seen = set()
        for evidence_id in values:
            if not isinstance(evidence_id, str) or not evidence_id:
                self.error(path, "evidence IDs must be nonblank strings")
                valid = False
                continue
            if evidence_id in seen:
                self.error(path, f"duplicate evidence ID {evidence_id!r}")
                valid = False
            seen.add(evidence_id)
            evidence = self.evidence_by_id.get(evidence_id)
            if evidence is None:
                self.error(path, f"unresolved evidence ID {evidence_id!r}")
                valid = False
                continue
            scope = evidence.get("scope")
            covers = (not self.invalid_evidence_document
                      and evidence_id not in self.invalid_evidence_ids
                      and (scope == "dataset" or (scope == "item"
                           and isinstance(evidence.get("itemIds"), list)
                           and item_id in evidence["itemIds"])))
            if not covers:
                self.error(path, f"evidence {evidence_id!r} does not cover this item")
                valid = False
        return valid

    def _url(self, value, path):
        if not self._string(value, path):
            return False
        try:
            parts = urlsplit(value)
            valid = parts.scheme == "https" and bool(parts.hostname) and parts.username is None and parts.password is None
        except ValueError:
            valid = False
        if not valid:
            self.error(path, "must be an absolute HTTPS URL without embedded credentials")
        return valid

    def _safe_file(self, value, expected_directory, label, max_bytes):
        if not isinstance(value, str) or not value or "\\" in value or "\x00" in value:
            self.error(label, f"{label.split('.')[-1]} must be a safe relative path under {expected_directory}/")
            return None
        if not _is_unicode_scalar_string(value):
            self.error(label, f"{label.split('.')[-1]} contains invalid Unicode scalar data")
            return None
        pure = PurePosixPath(value)
        parts = value.split("/")
        if (pure.is_absolute() or not parts or parts[0] != expected_directory
                or any(part in ("", ".", "..") for part in parts)):
            self.error(label, f"{label.split('.')[-1]} must be a safe relative path under {expected_directory}/")
            return None
        current = self.root
        try:
            for part in parts:
                current = current / part
                info = current.lstat()
                if stat.S_ISLNK(info.st_mode):
                    self.error(label, f"{label.split('.')[-1]} traverses a symlink")
                    return None
            info = current.lstat()
        except OSError:
            self.error(label, f"{label.split('.')[-1]} does not name an existing regular file")
            return None
        if not stat.S_ISREG(info.st_mode):
            self.error(label, f"{label.split('.')[-1]} does not name an existing regular file")
            return None
        try:
            resolved = current.resolve(strict=True)
            resolved.relative_to(self.root)
        except (OSError, ValueError):
            self.error(label, f"{label.split('.')[-1]} escapes the package root")
            return None
        if info.st_size > max_bytes:
            self.error(label, f"{label.split('.')[-1]} exceeds {max_bytes // (1024 * 1024)} MiB input limit")
            return None
        return current

    def _read_wav(self, path, label):
        try:
            raw = _bounded_read(path, MAX_AUDIO_BYTES)
        except OSError as exc:
            self.error(label, f"cannot read WAV ({exc.strerror or type(exc).__name__})")
            return None
        if raw is None:
            self.error(label, "WAV exceeds 100 MiB input limit")
            return None
        digest = hashlib.sha256(raw).hexdigest()
        try:
            with wave.open(io.BytesIO(raw), "rb") as wav:
                params = wav.getparams()
                if params.comptype != "NONE" or params.sampwidth not in (1, 2, 3, 4):
                    self.error(label, "only uncompressed integer PCM WAV is supported")
                    return None
                if params.nchannels <= 0 or params.framerate <= 0 or params.nframes <= 0:
                    self.error(label, "WAV channels, sample rate, and frame count must be positive")
                    return None
                frame_bytes = wav.readframes(params.nframes)
                expected_length = params.nframes * params.nchannels * params.sampwidth
                if len(frame_bytes) != expected_length:
                    role = "original" if ".original" in label else "clip"
                    self.error(label, f"{role} WAV frame data is truncated")
                    return None
        except (wave.Error, EOFError, OSError) as exc:
            self.error(label, f"invalid or unsupported WAV ({type(exc).__name__})")
            return None
        actual = {
            "path": None,
            "sha256": digest,
            "byteLength": len(raw),
            "sampleRate": params.framerate,
            "channels": params.nchannels,
            "sampleWidth": params.sampwidth,
            "frameCount": params.nframes,
            "durationSeconds": params.nframes / params.framerate,
        }
        return actual, frame_bytes

    def _validate_mixed_contexts(self):
        sections = self._sections()
        if len(sections) < 3 or not all(isinstance(section, dict) for section in sections[:3]):
            return
        prior_vowels = sections[0].get("items", [])
        prior_consonants = sections[1].get("items", [])
        mixed = sections[2].get("items", [])
        if not all(isinstance(items, list) for items in (prior_vowels, prior_consonants, mixed)):
            return
        vowel_targets = {item.get("targetSound") for item in prior_vowels
                         if isinstance(item, dict) and isinstance(item.get("targetSound"), str)}
        consonant_targets = {item.get("targetSound") for item in prior_consonants
                             if isinstance(item, dict) and isinstance(item.get("targetSound"), str)}
        used_vowel, used_consonant = set(), set()
        for index, item in enumerate(mixed):
            if not isinstance(item, dict):
                continue
            target = item.get("targetSound")
            path = f"manifest.json.sections[2].items[{index}]"
            if not isinstance(target, str) or target not in vowel_targets | consonant_targets:
                self.error(f"{path}.targetSound",
                           f"mixed targetSound {target!r} is not used by a prior vowel or consonant section")
                continue
            matching_prior = [candidate for candidate in prior_vowels + prior_consonants
                              if isinstance(candidate, dict) and candidate.get("targetSound") == target]
            if target in vowel_targets:
                used_vowel.add(target)
            if target in consonant_targets:
                used_consonant.add(target)
            for prior in matching_prior:
                if (item.get("sentenceId") == prior.get("sentenceId")
                        or item.get("text") == prior.get("text")):
                    self.error(path, f"mixed target {target!r} must use a distinct sentence context")
                    break
        if not used_vowel:
            self.error("manifest.json.sections[2].items", "mixed section must revisit a prior vowel target")
        if not used_consonant:
            self.error("manifest.json.sections[2].items", "mixed section must revisit a prior consonant target")


def _guarded_verification(root, require_reviewed=False):
    try:
        verifier = _Verifier(root, require_reviewed)
        errors = verifier.run()
    except (OSError, UnicodeError, ValueError, TypeError, KeyError, IndexError,
            OverflowError, RecursionError, wave.Error, EOFError) as exc:
        # Malformed package bytes/types are user input, never a CLI traceback.
        return None, [f"package: malformed input prevented verification ({type(exc).__name__})"]
    return verifier, errors


def verify_package(root: Path, require_reviewed: bool = False) -> list[str]:
    """Return deterministic diagnostics; an empty list means technical validity only."""
    if not isinstance(require_reviewed, bool):
        return ["require_reviewed: must be a boolean"]
    _, errors = _guarded_verification(root, require_reviewed)
    return errors


def _summary(root):
    verifier, errors = _guarded_verification(root)
    if verifier is None:
        return errors, 0, 0, 0, 0
    qualified = sum(bool(value) for value in verifier.item_results.values())
    candidates = len(verifier.items)
    pending = max(0, candidates - qualified)
    qualified_sections = sum(bool(value) for value in verifier.section_results.values())
    return errors, candidates, pending, qualified, qualified_sections


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package-root", required=True, type=Path)
    parser.add_argument("--require-reviewed", action="store_true")
    args = parser.parse_args(argv)
    errors, candidates, pending, qualified, qualified_sections = _summary(args.package_root)
    if args.require_reviewed and not errors and pending:
        suffix = "candidate is" if pending == 1 else "candidates are"
        errors.append(f"review gate: --require-reviewed: {pending} {suffix} unqualified")
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1
    print(
        f"Technical package verification passed: candidates={candidates}; "
        f"pending/unqualified: {pending}; qualified: {qualified}; "
        f"qualified sections: {qualified_sections}/3. Metadata-only: this verifies "
        "declared evidence integrity, not linguistic truth, human rights clearance, "
        "or learner availability."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
