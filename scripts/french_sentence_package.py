"""Shared offline parsing and identity primitives for French sentence data."""

import hashlib
import json
import re


class SentencePackageError(ValueError):
    """An actionable error in sentence package input."""


_TSV_FIELDS = (
    "id", "filename", "raw_transcription", "transcription", "unused",
    "num_samples", "gender",
)
_ASCII_DECIMAL = re.compile(r"[0-9]+\Z")
_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_TSV_RECORD_SEPARATOR = re.compile(r"\r?\n")


def _nonblank(value):
    return isinstance(value, str) and bool(value.strip())


def parse_fleurs_train_tsv(text):
    if not isinstance(text, str):
        raise SentencePackageError("TSV input must be text")
    rows = []
    seen = set()
    for line_number, line in enumerate(_TSV_RECORD_SEPARATOR.split(text), 1):
        if not line.strip():
            continue
        columns = line.split("\t")
        if len(columns) != len(_TSV_FIELDS):
            raise SentencePackageError(
                f"line {line_number}: expected 7 tab-separated fields, got {len(columns)}")
        row = dict(zip(_TSV_FIELDS, columns))
        if not _ASCII_DECIMAL.fullmatch(row["id"]):
            raise SentencePackageError(f"line {line_number}: id must be ASCII decimal")
        if not _nonblank(row["filename"]):
            raise SentencePackageError(f"line {line_number}: filename must not be blank")
        filename = row["filename"]
        if ("/" in filename or "\\" in filename or "\x00" in filename
                or filename in (".", "..") or not filename.endswith(".wav")):
            raise SentencePackageError(
                f"line {line_number}: filename must be a safe .wav basename")
        for field in ("raw_transcription", "transcription"):
            if not _nonblank(row[field]):
                raise SentencePackageError(
                    f"line {line_number}: {field} must not be blank")
        if not _ASCII_DECIMAL.fullmatch(row["num_samples"]):
            raise SentencePackageError(
                f"line {line_number}: num_samples must be positive ASCII decimal")
        if not row["num_samples"].strip("0"):
            raise SentencePackageError(
                f"line {line_number}: num_samples must be positive ASCII decimal")
        identity = (row["id"], filename)
        if identity in seen:
            raise SentencePackageError(
                f"line {line_number}: duplicate (id, filename) {identity!r}")
        seen.add(identity)
        rows.append(row)
    return rows


def canonical_json(value):
    def validate(item, path="$", active=None):
        if active is None:
            active = set()
        if item is None or isinstance(item, (str, bool, int)):
            return
        if isinstance(item, float):
            if item != item or item in (float("inf"), float("-inf")):
                raise SentencePackageError(f"{path}: non-finite numbers are not JSON values")
            return
        if isinstance(item, list):
            marker = id(item)
            if marker in active:
                raise SentencePackageError(f"{path}: cyclic value is not JSON")
            active.add(marker)
            try:
                for index, child in enumerate(item):
                    validate(child, f"{path}[{index}]", active)
            finally:
                active.remove(marker)
            return
        if isinstance(item, dict):
            marker = id(item)
            if marker in active:
                raise SentencePackageError(f"{path}: cyclic value is not JSON")
            active.add(marker)
            try:
                for key, child in item.items():
                    if not isinstance(key, str):
                        raise SentencePackageError(f"{path}: object keys must be strings")
                    validate(child, f"{path}.{key}", active)
            finally:
                active.remove(marker)
            return
        raise SentencePackageError(f"{path}: unsupported JSON value {type(item).__name__}")

    validate(value)
    try:
        return json.dumps(value, ensure_ascii=False, sort_keys=True,
                          separators=(",", ":"), allow_nan=False)
    except (TypeError, ValueError, RecursionError) as exc:
        raise SentencePackageError(f"invalid JSON value: {exc}") from exc


def annotation_hash(item):
    if not isinstance(item, dict):
        raise SentencePackageError("annotation must be an object")
    fields = ("sentenceId", "audioRefId", "text", "annotationRevision",
              "tokens", "expectedTokenIds")
    missing = [field for field in fields if field not in item]
    if missing:
        raise SentencePackageError("annotation missing fields: " + ", ".join(missing))
    for field in ("sentenceId", "audioRefId", "text"):
        if not _nonblank(item[field]):
            raise SentencePackageError(f"{field} must be a nonblank string")
    revision = item["annotationRevision"]
    if isinstance(revision, bool) or not isinstance(revision, int) or revision < 1:
        raise SentencePackageError("annotationRevision must be a positive integer")
    tokens = item["tokens"]
    if not isinstance(tokens, list):
        raise SentencePackageError("tokens must be a list")
    projected_tokens = []
    token_ids = []
    for index, token in enumerate(tokens):
        if not isinstance(token, dict):
            raise SentencePackageError(f"tokens[{index}] must be an object")
        if any(field not in token for field in ("id", "text", "phonemes")):
            raise SentencePackageError(f"tokens[{index}] requires id, text, and phonemes")
        token_id, token_text, phonemes = token["id"], token["text"], token["phonemes"]
        if not _nonblank(token_id) or not _nonblank(token_text):
            raise SentencePackageError(f"tokens[{index}] id and text must be nonblank strings")
        if not isinstance(phonemes, list) or any(not _nonblank(p) for p in phonemes):
            raise SentencePackageError(f"tokens[{index}].phonemes must be a list of nonblank strings")
        token_ids.append(token_id)
        projected_tokens.append({"id": token_id, "text": token_text,
                                 "phonemes": phonemes})
    if len(set(token_ids)) != len(token_ids):
        raise SentencePackageError("token IDs must be unique")
    expected = item["expectedTokenIds"]
    if not isinstance(expected, list) or any(not _nonblank(value) for value in expected):
        raise SentencePackageError("expectedTokenIds must be a list of nonblank strings")
    if len(set(expected)) != len(expected):
        raise SentencePackageError("expectedTokenIds must be unique")
    if any(value not in token_ids for value in expected):
        raise SentencePackageError("expectedTokenIds must refer to authored token IDs")
    if expected != [value for value in token_ids if value in set(expected)]:
        raise SentencePackageError("expectedTokenIds must follow authored token order")
    projection = {
        "sentenceId": item["sentenceId"], "audioRefId": item["audioRefId"],
        "text": item["text"], "annotationRevision": revision,
        "tokens": projected_tokens, "expectedTokenIds": expected,
    }
    return hashlib.sha256(canonical_json(projection).encode("utf-8")).hexdigest()


def valid_sha256(value):
    return isinstance(value, str) and _SHA256.fullmatch(value) is not None
