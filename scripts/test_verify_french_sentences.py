import contextlib
import hashlib
import io
import json
import os
import tempfile
import unittest
import wave
from pathlib import Path
from unittest import mock

import prepare_french_sentences as preparation
from french_sentence_package import annotation_hash

try:
    from verify_french_sentences import main, verify_package
except ImportError:
    main = verify_package = None


SECTION_IDS = (
    "en-fr-sentence-hunt-vowels",
    "en-fr-sentence-hunt-consonants",
    "en-fr-sentence-hunt-mixed",
)
PREFIXES = ("fr08-vowel", "fr08-consonant", "fr08-mixed")
SAMPLE_RATE = 16000
CHANNELS = 1
SAMPLE_WIDTH = 2
SOURCE_FRAMES = 20
RETRIEVED_AT = "2026-10-17T12:00:00Z"
REVIEWED_AT = "2026-10-17T13:00:00Z"
LICENSE_URL = "https://creativecommons.org/licenses/by/4.0/"


def _wav_bytes(frames, rate=SAMPLE_RATE, channels=CHANNELS, width=SAMPLE_WIDTH):
    output = io.BytesIO()
    with wave.open(output, "wb") as wav:
        wav.setnchannels(channels)
        wav.setsampwidth(width)
        wav.setframerate(rate)
        wav.writeframes(frames)
    return output.getvalue()


def _measure(path):
    data = path.read_bytes()
    with wave.open(str(path), "rb") as wav:
        return {
            "path": path.relative_to(path.parents[1]).as_posix(),
            "sha256": hashlib.sha256(data).hexdigest(),
            "byteLength": len(data),
            "sampleRate": wav.getframerate(),
            "channels": wav.getnchannels(),
            "sampleWidth": wav.getsampwidth(),
            "frameCount": wav.getnframes(),
            "durationSeconds": wav.getnframes() / wav.getframerate(),
        }


def _write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, allow_nan=True,
                               separators=(",", ":")) + "\n", encoding="utf-8")


def _json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def _synthetic_sections():
    return [
        {
            "kind": "vowels",
            "prefix": "fr08-vowel",
            "items": [
                ("a", "chat", ["ʃ", "a"]),
                ("e", "nez", ["n", "e"]),
                ("i", "lit", ["l", "i", "t"]),
                ("y", "lune", ["l", "y", "n"]),
                ("u", "rouge", ["ʁ", "u", "ʒ"]),
            ],
        },
        {
            "kind": "consonants",
            "prefix": "fr08-consonant",
            "items": [
                ("p", "pomme", ["p", "ɔ", "m"]),
                ("t", "thé", ["t", "e"]),
                ("k", "quai", ["k", "e"]),
                ("s", "seau", ["s", "o"]),
                ("m", "mer", ["m", "e", "ʁ"]),
            ],
        },
        {
            "kind": "mixed",
            "prefix": "fr08-mixed",
            "items": [
                ("a", "balle", ["b", "a", "l"]),
                ("p", "porte", ["p", "ɔ", "ʁ", "t"]),
                ("y", "tu", ["t", "y"]),
                ("k", "carte", ["k", "a", "ʁ", "t"]),
                ("e", "clé", ["k", "l", "e"]),
            ],
        },
    ]


class SentencePackageFixture:
    """Build a complete, synthetic 15-item PCM package in a temporary directory."""

    def __init__(self, root, accepted=False):
        self.root = Path(root)
        for directory in ("originals", "clips", "licenses"):
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        self.license_path = self.root / "licenses" / "cc-by-4.0.txt"
        self.license_path.write_text(
            "SYNTHETIC TEST FIXTURE ONLY — not legal advice or production evidence.\n"
            "Creative Commons Attribution 4.0 International (CC BY 4.0)\n"
            f"{LICENSE_URL}\n", encoding="utf-8")
        source_frames = bytes(range(SOURCE_FRAMES * CHANNELS * SAMPLE_WIDTH))
        source_blob = _wav_bytes(source_frames)
        evidence_entries = [{
            "id": "dataset-source",
            "url": "https://huggingface.co/datasets/google/fleurs",
            "retrievedAt": RETRIEVED_AT,
            "sha256": hashlib.sha256(
                b"SYNTHETIC TEST ONLY: dataset source evidence, not real evidence.").hexdigest(),
            "text": "SYNTHETIC TEST ONLY: dataset source evidence, not real evidence.",
            "scope": "dataset",
            "itemIds": [],
        }, {
            "id": "tool-source",
            "url": "https://example.invalid/fr08/synthetic-tool-notice",
            "retrievedAt": RETRIEVED_AT,
            "sha256": hashlib.sha256(
                b"SYNTHETIC TEST ONLY: tool evidence.").hexdigest(),
            "text": "SYNTHETIC TEST ONLY: tool evidence.",
            "scope": "tool",
            "itemIds": [],
        }]
        sections = []
        provenance_entries = []
        annotation_entries = []
        self.items = {}
        for section_index, section_spec in enumerate(_synthetic_sections()):
            section_id = SECTION_IDS[section_index]
            section = {
                "id": section_id,
                "kind": section_spec["kind"],
                "title": f"SYNTHETIC {section_spec['kind']} section",
                "contentRevision": 1,
                "policyRevision": 1,
                "completionThresholdPercent": 80,
                "items": [],
            }
            for item_index, (target, target_word, target_phonemes) in enumerate(
                    section_spec["items"], 1):
                item_id = f"{section_spec['prefix']}-{item_index:02}"
                suffix = f"{section_index * 5 + item_index:02}"
                sentence_id = f"fleurs-synthetic-{suffix}"
                audio_ref_id = f"fr08-audio-synthetic-{suffix}"
                text = f"{target_word} non."
                tokens = [
                    {"id": f"{item_id}-token-01", "text": target_word,
                     "phonemes": target_phonemes},
                    {"id": f"{item_id}-token-02", "text": "non",
                     "phonemes": ["n", "ɔ̃"]},
                ]
                expected_ids = [tokens[0]["id"]]
                original_relative = f"originals/source-{suffix}.wav"
                clip_relative = f"clips/clip-{suffix}.wav"
                original_path = self.root / original_relative
                original_path.write_bytes(source_blob)
                start_frame = (section_index * 5 + item_index - 1) % 5
                end_frame = start_frame + 6
                clip_frames = source_frames[
                    start_frame * CHANNELS * SAMPLE_WIDTH:
                    end_frame * CHANNELS * SAMPLE_WIDTH]
                clip_path = self.root / clip_relative
                clip_path.write_bytes(_wav_bytes(clip_frames))
                original_measure = _measure(original_path)
                clip_measure = _measure(clip_path)
                original_sha = original_measure["sha256"]
                clip_sha = clip_measure["sha256"]
                item = {
                    "id": item_id,
                    "sentenceId": sentence_id,
                    "audioRefId": audio_ref_id,
                    "purpose": "practice",
                    "reviewState": "pending",
                    "targetSound": target,
                    "targetLabel": f"SYNTHETIC /{target}/",
                    "text": text,
                    "debriefNote": "SYNTHETIC TEST NOTE — not learner guidance.",
                    "annotationRevision": 1,
                    "annotationHash": "0" * 64,
                    "tokens": tokens,
                    "expectedTokenIds": expected_ids,
                    "originalPath": original_relative,
                    "clipPath": clip_relative,
                    "originalSha256": original_sha,
                    "clipSha256": clip_sha,
                }
                item["annotationHash"] = annotation_hash(item)
                section["items"].append(item)
                self.items[item_id] = item
                row = {
                    "id": str(1000 + section_index * 5 + item_index),
                    "filename": f"fleurs-{suffix}.wav",
                    "raw_transcription": text,
                    "transcription": text,
                    "unused": "synthetic-unused-field",
                    "num_samples": str(SOURCE_FRAMES),
                    "gender": "unspecified-source-value",
                }
                raw_tsv = "\t".join(row.values())
                source_evidence_id = f"item-evidence-{suffix}"
                self.source_evidence_ids = getattr(self, "source_evidence_ids", {})
                self.source_evidence_ids[item_id] = source_evidence_id
                evidence_text = (
                    f"SYNTHETIC TEST ONLY: item source evidence for {item_id}.")
                evidence_entries.append({
                    "id": source_evidence_id,
                    "url": f"https://example.invalid/fr08/{item_id}/source",
                    "retrievedAt": RETRIEVED_AT,
                    "sha256": hashlib.sha256(evidence_text.encode("utf-8")).hexdigest(),
                    "text": evidence_text,
                    "scope": "item",
                    "itemIds": [item_id],
                })
                pending = {
                    "status": "pending", "reviewer": None, "qualification": None,
                    "reviewedAt": None, "originalSha256": None, "clipSha256": None,
                    "annotationHash": None, "evidenceIds": [], "notes": "",
                }
                provenance_entries.append({
                    "itemId": item_id,
                    "source": {
                        "repository": "google/fleurs",
                        "revision": preparation.REVISION,
                        "config": "fr_fr",
                        "split": "train",
                        "rowId": row["id"],
                        "audioPath": row["filename"],
                        "retrievalUrl": preparation.TSV_URL,
                        "retrievedAt": RETRIEVED_AT,
                        "rawTranscription": row["raw_transcription"],
                        "transcription": row["transcription"],
                        "rawTsvRecord": raw_tsv,
                    },
                    "original": original_measure,
                    "clip": clip_measure,
                    "derivation": {
                        "startFrame": start_frame,
                        "endFrame": end_frame,
                        "tool": "Python wave (synthetic fixture)",
                        "version": "test-only",
                        "settings": ["sample-preserving half-open crop"],
                        "changes": ["SYNTHETIC TEST crop; not source production"],
                        "transcriptCorrectionRationale": "",
                    },
                    "credit": {
                        "creator": "SYNTHETIC source creator attribution",
                        "attribution": "SYNTHETIC FLEURS attribution; no speaker inferred",
                        "licenseId": "CC-BY-4.0",
                        "licenseUrl": LICENSE_URL,
                        "licenseTextPath": "licenses/cc-by-4.0.txt",
                        "notices": ["SYNTHETIC TEST NOTICE; not production attribution"],
                        "evidenceIds": ["dataset-source", source_evidence_id],
                    },
                    "rightsReview": dict(pending),
                })
                annotation_entries.append({
                    "itemId": item_id,
                    "annotationRevision": 1,
                    "annotationHash": item["annotationHash"],
                    "tool": {
                        "name": "SYNTHETIC G2P draft tool",
                        "version": "test-only",
                        "settings": ["no execution; synthetic fixture"],
                        "inputSha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
                    },
                    "rawSentenceIpa": f"SYNTHETIC IPA for {text}",
                    "draftTokenPhonemes": None,
                    "corrections": [],
                    "frenchAudioReview": dict(pending),
                })
            sections.append(section)

        self.manifest = {
            "schemaVersion": 1,
            "language": "fr",
            "courseId": "en-fr",
            "sections": sections,
            "historicalSections": [],
        }
        self.provenance = {"schemaVersion": 1, "entries": provenance_entries}
        self.annotations = {"schemaVersion": 1, "entries": annotation_entries}
        self.source_evidence = {"schemaVersion": 1, "entries": evidence_entries}
        self.write_all()
        if accepted:
            self.accept_all()

    def path(self, name):
        return self.root / name

    def write_all(self):
        _write_json(self.path("manifest.json"), self.manifest)
        _write_json(self.path("provenance.json"), self.provenance)
        _write_json(self.path("annotations.json"), self.annotations)
        _write_json(self.path("source-evidence.json"), self.source_evidence)

    def item(self, item_id):
        for section in self.manifest["sections"]:
            for item in section["items"]:
                if item["id"] == item_id:
                    return item
        raise KeyError(item_id)

    def provenance_entry(self, item_id):
        return next(entry for entry in self.provenance["entries"]
                    if entry["itemId"] == item_id)

    def annotation_entry(self, item_id):
        return next(entry for entry in self.annotations["entries"]
                    if entry["itemId"] == item_id)

    def bind_annotation(self, item_id):
        item = self.item(item_id)
        digest = annotation_hash(item)
        item["annotationHash"] = digest
        entry = self.annotation_entry(item_id)
        entry["annotationRevision"] = item["annotationRevision"]
        entry["annotationHash"] = digest
        entry["tool"]["inputSha256"] = hashlib.sha256(
            item["text"].encode("utf-8")).hexdigest()
        for review in (self.provenance_entry(item_id)["rightsReview"],
                       entry["frenchAudioReview"]):
            if review["status"] in ("accepted", "rejected"):
                review["annotationHash"] = digest

    def set_sentence(self, item_id, text, tokens, expected_ids):
        item = self.item(item_id)
        item["text"] = text
        item["tokens"] = tokens
        item["expectedTokenIds"] = expected_ids
        source = self.provenance_entry(item_id)["source"]
        source["rawTranscription"] = text
        source["transcription"] = text
        columns = source["rawTsvRecord"].split("\t")
        columns[2] = text
        columns[3] = text
        source["rawTsvRecord"] = "\t".join(columns)
        self.bind_annotation(item_id)
        self.write_all()

    def accept_all(self):
        for section in self.manifest["sections"]:
            for item in section["items"]:
                item["reviewState"] = "reviewed"
                source = self.provenance_entry(item["id"])
                annotation = self.annotation_entry(item["id"])
                evidence_ids = ["dataset-source", self.source_evidence_ids[item["id"]]]
                for review in (source["rightsReview"], annotation["frenchAudioReview"]):
                    review.update({
                        "status": "accepted",
                        "reviewer": "SYNTHETIC TEST REVIEWER — not a human decision",
                        "qualification": "SYNTHETIC TEST ONLY — never production qualification",
                        "reviewedAt": REVIEWED_AT,
                        "originalSha256": item["originalSha256"],
                        "clipSha256": item["clipSha256"],
                        "annotationHash": item["annotationHash"],
                        "evidenceIds": evidence_ids[:],
                        "notes": "SYNTHETIC ACCEPTED FIXTURE; no real decision or rights review.",
                    })
        self.write_all()

    def refresh_audio_measurements(self, item_id, role):
        item = self.item(item_id)
        entry = self.provenance_entry(item_id)
        relative = item["originalPath"] if role == "original" else item["clipPath"]
        actual = _measure(self.root / relative)
        entry[role].update(actual)
        item["originalSha256" if role == "original" else "clipSha256"] = actual["sha256"]
        self.bind_annotation(item_id)
        for review in (entry["rightsReview"], self.annotation_entry(item_id)["frenchAudioReview"]):
            if review["status"] in ("accepted", "rejected"):
                review["originalSha256"] = item["originalSha256"]
                review["clipSha256"] = item["clipSha256"]
        self.write_all()


def _snapshot(root):
    root = Path(root)
    result = {}
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            result[relative] = ("symlink", os.readlink(path))
        elif path.is_dir():
            result[relative] = ("directory",)
        elif path.is_file():
            result[relative] = ("file", path.read_bytes())
        else:
            result[relative] = ("other", path.stat().st_mode)
    return result


class VerifyFrenchSentenceTests(unittest.TestCase):
    def setUp(self):
        if hasattr(self, "temp"):
            self.temp.cleanup()
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "package"
        self.fixture = SentencePackageFixture(self.root)

    def tearDown(self):
        self.temp.cleanup()

    def _verify(self, root=None, require_reviewed=False):
        self.assertIsNotNone(verify_package,
                             "verify_package is not implemented yet")
        return verify_package(root or self.root, require_reviewed=require_reviewed)

    def _contains(self, errors, diagnostic):
        self.assertIn(diagnostic, "\n".join(errors),
                      f"expected diagnostic {diagnostic!r}, got {errors!r}")

    def _rewrite(self, filename, update):
        value = _json(self.root / filename)
        update(value)
        _write_json(self.root / filename, value)

    def _first_id(self):
        return "fr08-vowel-01"

    def test_verifier_api_is_available(self):
        self.assertIsNotNone(verify_package,
                             "verify_package is not implemented yet")

    def test_complete_pending_package_is_technical_pass_but_review_gate_is_separate(self):
        self.assertEqual(self._verify(), [])
        errors = self._verify(require_reviewed=True)
        self._contains(errors, "--require-reviewed: 15 candidates are unqualified")
        self.assertEqual(verify_package(self.root, require_reviewed=1),
                         ["require_reviewed: must be a boolean"])

    def test_synthetic_fully_accepted_fixture_binds_final_annotation_not_null_draft(self):
        self.fixture.accept_all()
        self.assertTrue(all(
            self.fixture.annotation_entry(item_id)["draftTokenPhonemes"] is None
            for item_id in self.fixture.items))
        self.assertEqual(self._verify(), [])
        self.assertEqual(self._verify(require_reviewed=True), [])

    def test_one_unqualified_member_blocks_only_its_five_item_section(self):
        self.fixture.accept_all()
        item = self.fixture.item("fr08-vowel-03")
        item["reviewState"] = "pending"
        self.fixture.write_all()
        self.assertEqual(self._verify(), [])
        errors = self._verify(require_reviewed=True)
        self._contains(errors, "--require-reviewed: 1 candidate is unqualified")
        stdout, stderr, status = self._run_cli()
        self.assertEqual(status, 0, stderr)
        self.assertIn("pending/unqualified: 1", stdout)
        self.assertIn("qualified: 14", stdout)
        self.assertIn("qualified sections: 2/3", stdout)

    def test_manifest_rejects_unknown_root_and_section_fields_and_future_history(self):
        self._rewrite("manifest.json", lambda value: value.update(unexpected=True))
        self._contains(self._verify(), "manifest.json: unknown field 'unexpected'")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0].update(unexpected=True))
        self._contains(self._verify(), "manifest.json.sections[0]: unknown field 'unexpected'")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value.update(historicalSections=[{"future": 2}]))
        self._contains(self._verify(), "manifest.json.historicalSections: non-empty history is unsupported")

    def test_manifest_requires_authored_section_and_item_identity_order(self):
        self._rewrite("manifest.json", lambda value: value["sections"].reverse())
        self._contains(self._verify(), "manifest.json.sections: section IDs/order must be")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"].reverse())
        self._contains(self._verify(), "manifest.json.sections[0].items: item IDs/order must match")

    def test_manifest_requires_exact_revision_policy_and_review_state_types(self):
        self._rewrite("manifest.json", lambda value: value.update(schemaVersion=True))
        self._contains(self._verify(), "manifest.json.schemaVersion: expected integer 1")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0].update(contentRevision=True))
        self._contains(self._verify(), "manifest.json.sections[0].contentRevision: expected integer 1")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0].update(reviewState="approved"))
        self._contains(self._verify(), ".reviewState: must be 'pending' or 'reviewed'")

    def test_unknown_item_fields_are_rejected_including_phoneme_grades(self):
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0].update(phonemeGrade=1))
        self._contains(self._verify(), "manifest.json.sections[0].items[0]: unknown field 'phonemeGrade'")

    def test_duplicate_json_keys_and_non_finite_numbers_fail_without_traceback(self):
        (self.root / "manifest.json").write_text(
            '{"schemaVersion":1,"schemaVersion":1}', encoding="utf-8")
        errors = self._verify()
        self._contains(errors, "manifest.json: duplicate JSON object key 'schemaVersion'")
        (self.root / "manifest.json").write_text('{"schemaVersion":NaN}', encoding="utf-8")
        self._contains(self._verify(), "manifest.json: non-finite JSON number NaN")

    def test_json_input_size_is_bounded(self):
        (self.root / "source-evidence.json").write_bytes(b" " * (16 * 1024 * 1024 + 1))
        self._contains(self._verify(), "source-evidence.json: exceeds 16 MiB input limit")

    def test_all_metadata_files_require_exact_item_associations(self):
        self._rewrite("provenance.json", lambda value: value["entries"].pop())
        self._contains(self._verify(), "provenance.json.entries: missing item entry for fr08-mixed-05")
        self.setUp()
        self._rewrite("annotations.json", lambda value: value["entries"].append(value["entries"][0]))
        self._contains(self._verify(), "annotations.json.entries: duplicate itemId 'fr08-vowel-01'")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0].update(itemId="orphan"))
        self._contains(self._verify(), "provenance.json.entries: orphan itemId 'orphan'")

    def test_item_identity_audio_reference_sentence_and_paths_are_unique(self):
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][1].update(audioRefId=value["sections"][0]["items"][0]["audioRefId"]))
        self._contains(self._verify(), "audioRefId 'fr08-audio-synthetic-01' is not unique")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][1].update(sentenceId=value["sections"][0]["items"][0]["sentenceId"]))
        self._contains(self._verify(), "sentenceId 'fleurs-synthetic-01' is not unique")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][1].update(originalPath=value["sections"][0]["items"][0]["originalPath"]))
        self._contains(self._verify(), "originalPath 'originals/source-01.wav' is not unique")

    def test_text_coverage_repeated_word_occurrences_and_internal_apostrophe_hyphen(self):
        item_id = self._first_id()
        repeated = [
            {"id": "occurrence-one", "text": "chat", "phonemes": ["ʃ", "a"]},
            {"id": "occurrence-two", "text": "chat", "phonemes": ["ʃ", "a"]},
            {"id": "other-word", "text": "non", "phonemes": ["n", "ɔ̃"]},
        ]
        self.fixture.set_sentence(item_id, "chat chat non.", repeated,
                                  ["occurrence-one", "occurrence-two"])
        self.assertEqual(self._verify(), [])
        compound = [
            {"id": "compound-one", "text": "l'amour", "phonemes": ["a", "m", "u", "ʁ"]},
            {"id": "compound-two", "text": "arc-en-ciel", "phonemes": ["a", "ʁ", "k", "s", "j", "ɛ", "l"]},
            {"id": "compound-three", "text": "non", "phonemes": ["n", "ɔ̃"]},
        ]
        self.fixture.set_sentence(item_id, "l'amour arc-en-ciel non.", compound,
                                  ["compound-one", "compound-two"])
        self.assertEqual(self._verify(), [])

    def test_token_coverage_rejects_uncovered_text_and_selectable_punctuation(self):
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0].update(text="chat encore non."))
        self._contains(self._verify(), "tokens do not exactly cover selectable words in text")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0]["tokens"][0].update(text="chat."))
        self._contains(self._verify(), "token text must be one punctuation-free selectable word")

    def test_token_ids_phonemes_and_expected_target_membership_are_exact(self):
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0]["tokens"][1].update(id=value["sections"][0]["items"][0]["tokens"][0]["id"]))
        self._contains(self._verify(), "token IDs must be unique within an item")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0]["tokens"][0].update(phonemes=["a", "a"]))
        self._contains(self._verify(), "phoneme labels must be unique within each token")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0]["tokens"][0].update(phonemes=["invented"]))
        self._contains(self._verify(), "unknown phoneme label 'invented'")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0].update(expectedTokenIds=[]))
        self._contains(self._verify(), "expectedTokenIds must equal authored-order targetSound membership")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0].update(expectedTokenIds=[value["sections"][0]["items"][0]["tokens"][0]["id"], value["sections"][0]["items"][0]["tokens"][1]["id"]]))
        self._contains(self._verify(), "expectedTokenIds must equal authored-order targetSound membership")

    def test_each_item_has_a_real_target_word_and_a_non_target_word(self):
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0]["tokens"][1].update(phonemes=["a", "n"]))
        self._contains(self._verify(), "sentence needs at least one genuine non-target word")

    def test_target_roles_and_mixed_prior_classes_and_contexts_are_validated(self):
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0].update(targetSound="p"))
        self._contains(self._verify(), "targetSound 'p' is not a vowel target for section kind 'vowels'")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][2]["items"][0].update(targetSound="ŋ"))
        self._contains(self._verify(), "mixed targetSound 'ŋ' is not used by a prior vowel or consonant section")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][2]["items"][0].update(text=value["sections"][0]["items"][0]["text"]))
        self._contains(self._verify(), "mixed target 'a' must use a distinct sentence context")

    def test_mixed_section_must_revisit_both_prior_target_classes(self):
        vowel_targets = ("a", "e", "i", "y", "u")
        self._rewrite("manifest.json", lambda value: [
            item.update(targetSound=vowel_targets[index])
            for index, item in enumerate(value["sections"][2]["items"])
        ])
        self._contains(self._verify(), "mixed section must revisit a prior consonant target")

    def test_provenance_source_pins_and_seven_field_row_must_agree(self):
        self._rewrite("provenance.json", lambda value: value["entries"][0]["source"].update(revision="other"))
        self._contains(self._verify(), ".source.revision: does not match pinned FLEURS revision")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["source"].update(rowId="9999"))
        self._contains(self._verify(), "source.rowId does not match rawTsvRecord id")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["source"].update(rawTsvRecord="bad\trow"))
        self._contains(self._verify(), "source.rawTsvRecord must be exactly one valid seven-field FLEURS record")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["source"].update(transcription="changed text"))
        self._contains(self._verify(), "source.transcription does not match rawTsvRecord")

    def test_excerpt_requires_exact_source_selection_or_correction_rationale(self):
        item_id = self._first_id()
        self.fixture.set_sentence(item_id, "chat, non.", [
            {"id": "one", "text": "chat", "phonemes": ["ʃ", "a"]},
            {"id": "two", "text": "non", "phonemes": ["n", "ɔ̃"]},
        ], ["one"])
        self.assertEqual(self._verify(), [])
        item = self.fixture.item(item_id)
        item["text"] = "chat et non."
        self.fixture.bind_annotation(item_id)
        self.fixture.write_all()
        self._contains(self._verify(), "transcriptCorrectionRationale is required when item text is not an exact source excerpt")

    def test_provenance_paths_measurements_and_pcm_crop_are_verified(self):
        self._rewrite("provenance.json", lambda value: value["entries"][0]["clip"].update(sampleRate=8000))
        self._contains(self._verify(), ".clip.sampleRate: does not match actual WAV")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["derivation"].update(startFrame=True))
        self._contains(self._verify(), ".derivation.startFrame: derivation.startFrame/endFrame must be strict integers")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0].update(originalPath="../outside.wav"))
        self._contains(self._verify(), "originalPath must be a safe relative path under originals/")
        self.setUp()
        item_id = self._first_id()
        clip = self.root / self.fixture.item(item_id)["clipPath"]
        with wave.open(str(clip), "rb") as wav:
            params = wav.getparams()
            samples = bytearray(wav.readframes(wav.getnframes()))
        samples[0] ^= 0x7f
        clip.write_bytes(_wav_bytes(bytes(samples), params.framerate,
                                    params.nchannels, params.sampwidth))
        self.fixture.refresh_audio_measurements(item_id, "clip")
        self._contains(self._verify(), "clip PCM is not the exact claimed source frame slice")

    def test_original_and_clip_hashes_lengths_and_truncation_are_checked(self):
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0].update(originalSha256="f" * 64))
        self._contains(self._verify(), "manifest originalSha256 does not match actual original file")
        self.setUp()
        item_id = self._first_id()
        original = self.root / self.fixture.item(item_id)["originalPath"]
        original.write_bytes(original.read_bytes()[:-1])
        self._contains(self._verify(), "original WAV frame data is truncated")

    def test_symlinked_audio_path_is_rejected_even_when_resolved_inside_root(self):
        item_id = self._first_id()
        original = self.root / self.fixture.item(item_id)["originalPath"]
        target = self.root / "originals" / "source-02.wav"
        original.unlink()
        original.symlink_to(target)
        self._contains(self._verify(), "original traverses a symlink")

    def test_actual_wav_shape_and_original_frame_count_are_strict(self):
        self._rewrite("provenance.json", lambda value: value["entries"][0]["original"].update(channels=True))
        self._contains(self._verify(), ".original.channels: must be a strict positive integer")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["source"].update(rawTsvRecord=value["entries"][0]["source"]["rawTsvRecord"].replace("\t20\t", "\t19\t")))
        self._contains(self._verify(), "source num_samples does not match actual original frame count")

    def test_annotation_hash_tool_input_draft_and_correction_history_are_bound(self):
        self._rewrite("annotations.json", lambda value: value["entries"][0].update(annotationHash="f" * 64))
        self._contains(self._verify(), "annotations.annotationHash does not match computed final annotation hash")
        self.setUp()
        self._rewrite("annotations.json", lambda value: value["entries"][0]["tool"].update(inputSha256="f" * 64))
        self._contains(self._verify(), "tool.inputSha256 does not match exact sentence text")
        self.setUp()
        self._rewrite("annotations.json", lambda value: value["entries"][0].update(draftTokenPhonemes=[{"tokenId": "unknown", "phonemes": ["a"]}]))
        self._contains(self._verify(), "draftTokenPhonemes tokenId 'unknown' is not an item token")
        self.setUp()
        entry = self.fixture.annotation_entry(self._first_id())
        entry["corrections"] = [{
            "tokenId": self.fixture.item(self._first_id())["tokens"][0]["id"],
            "before": [], "after": ["ʃ"], "rationale": "SYNTHETIC correction",
        }]
        self.fixture.write_all()
        self._contains(self._verify(), "correction final after does not match manifest token phonemes")

    def test_draft_mapping_and_correction_shapes_are_strict_but_not_final_truth(self):
        item_id = self._first_id()
        item = self.fixture.item(item_id)
        entry = self.fixture.annotation_entry(item_id)
        entry["draftTokenPhonemes"] = [
            {"tokenId": item["tokens"][0]["id"], "phonemes": ["ʃ", "a"]}
        ]
        self.fixture.write_all()
        self.assertEqual(self._verify(), [])
        self.fixture.accept_all()
        self.assertEqual(self._verify(), [])
        self.setUp()
        item_id = self._first_id()
        item = self.fixture.item(item_id)
        entry = self.fixture.annotation_entry(item_id)
        entry["corrections"] = [{
            "tokenId": item["tokens"][0]["id"], "before": ["a"],
            "after": item["tokens"][0]["phonemes"], "rationale": "synthetic",
        }]
        self.fixture.write_all()
        self._contains(self._verify(), "correction.before does not match retained draft mapping")

    def test_review_hashes_evidence_and_status_matrix_control_qualification(self):
        self.fixture.accept_all()
        entry = self.fixture.provenance_entry(self._first_id())
        entry["rightsReview"]["clipSha256"] = "f" * 64
        self.fixture.write_all()
        self._contains(self._verify(), "rightsReview.clipSha256 does not match item clipSha256")
        self.setUp()
        self.fixture.accept_all()
        entry = self.fixture.provenance_entry(self._first_id())
        entry["rightsReview"]["evidenceIds"] = ["tool-source"]
        self.fixture.write_all()
        self._contains(self._verify(), "rightsReview.evidenceIds: evidence 'tool-source' does not cover this item")
        self.setUp()
        self.fixture.accept_all()
        entry = self.fixture.annotation_entry(self._first_id())
        entry["frenchAudioReview"]["status"] = "pending"
        entry["frenchAudioReview"]["reviewer"] = None
        entry["frenchAudioReview"]["qualification"] = None
        entry["frenchAudioReview"]["reviewedAt"] = None
        entry["frenchAudioReview"]["originalSha256"] = None
        entry["frenchAudioReview"]["clipSha256"] = None
        entry["frenchAudioReview"]["annotationHash"] = None
        entry["frenchAudioReview"]["evidenceIds"] = []
        entry["frenchAudioReview"]["notes"] = ""
        self.fixture.write_all()
        self._contains(self._verify(), "reviewState reviewed requires accepted French/audio and rights decisions")

    def test_pending_review_cannot_contain_invented_acceptance_evidence(self):
        self._rewrite("provenance.json", lambda value: value["entries"][0]["rightsReview"].update(reviewer="SYNTHETIC invented"))
        self._contains(self._verify(), "pending review must have null reviewer, qualification, and reviewedAt")

    def test_pending_review_may_prebind_candidate_hashes_without_qualifying(self):
        item = self.fixture.item(self._first_id())
        review = self.fixture.provenance_entry(item["id"])["rightsReview"]
        review.update({
            "originalSha256": item["originalSha256"],
            "clipSha256": item["clipSha256"],
            "annotationHash": item["annotationHash"],
        })
        self.fixture.write_all()
        self.assertEqual(self._verify(), [])
        self._contains(self._verify(require_reviewed=True), "15 candidates are unqualified")
        review["annotationHash"] = "f" * 64
        self.fixture.write_all()
        self._contains(self._verify(), "pending hash must be null or match the current candidate identity")

    def test_rejected_review_retains_real_decision_and_reviewed_publication_is_invalid(self):
        self.fixture.accept_all()
        review = self.fixture.provenance_entry(self._first_id())["rightsReview"]
        review["status"] = "rejected"
        review["notes"] = "SYNTHETIC REJECTION: test fixture only."
        self.fixture.write_all()
        self._contains(self._verify(), "reviewState reviewed requires accepted French/audio and rights decisions")
        review["status"] = "pending"
        review["reviewer"] = None
        review["qualification"] = None
        review["reviewedAt"] = None
        review["originalSha256"] = None
        review["clipSha256"] = None
        review["annotationHash"] = None
        review["evidenceIds"] = []
        review["notes"] = ""
        self.fixture.item(self._first_id())["reviewState"] = "pending"
        self.fixture.write_all()
        self.assertEqual(self._verify(), [])

    def test_source_evidence_content_hash_scope_timestamp_and_license_text_are_verified(self):
        self._rewrite("source-evidence.json", lambda value: value["entries"][0].update(text="tampered evidence"))
        self._contains(self._verify(), "source-evidence sha256 does not match UTF-8 text")
        self.setUp()
        self._rewrite("source-evidence.json", lambda value: value["entries"][2].update(itemIds=["unknown-item"]))
        self._contains(self._verify(), "source-evidence itemIds contains unknown item 'unknown-item'")
        self.setUp()
        (self.root / "licenses" / "cc-by-4.0.txt").write_text("\n", encoding="utf-8")
        self._contains(self._verify(), "license text must be nonblank and identify CC BY 4.0")

    def test_credit_requires_declared_cc_by_attribution_not_speaker_invention(self):
        self._rewrite("provenance.json", lambda value: value["entries"][0]["credit"].update(licenseId="CC0-1.0"))
        self._contains(self._verify(), "credit.licenseId must be 'CC-BY-4.0'")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["credit"].update(creator=" "))
        self._contains(self._verify(), ".credit.creator: must be a nonblank source-supplied attribution")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["credit"].update(notices=[]))
        self._contains(self._verify(), "credit.notices: must be a nonempty list of nonblank notices")

    def test_metadata_fields_require_known_keys_and_strict_types(self):
        self._rewrite("provenance.json", lambda value: value["entries"][0]["derivation"].update(newToolFlag=True))
        self._contains(self._verify(), "derivation: unknown field 'newToolFlag'")
        self.setUp()
        self._rewrite("annotations.json", lambda value: value["entries"][0]["tool"].update(settings="not-a-list"))
        self._contains(self._verify(), "tool.settings must be an ordered list of nonblank strings")
        self.setUp()
        self._rewrite("source-evidence.json", lambda value: value["entries"][0].update(scope="unknown"))
        self._contains(self._verify(), "source-evidence scope must be dataset, tool, or item")

    def test_review_utc_and_acceptance_fields_are_strict(self):
        self.fixture.accept_all()
        self._rewrite("annotations.json", lambda value: value["entries"][0]["frenchAudioReview"].update(reviewedAt="yesterday"))
        self._contains(self._verify(), ".reviewedAt: must be an explicit UTC timestamp")
        self.setUp()
        self.fixture.accept_all()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["rightsReview"].update(reviewer=" "))
        self._contains(self._verify(), "accepted/rejected review requires nonblank reviewer and qualification")

    def test_manifest_requires_annotation_binding_even_with_publication_reviewed(self):
        self.fixture.accept_all()
        entry = self.fixture.annotation_entry(self._first_id())
        entry["annotationHash"] = "f" * 64
        self.fixture.write_all()
        self._contains(self._verify(), "annotations.annotationHash does not match computed final annotation hash")

    def test_reviewed_publication_cannot_qualify_without_annotation_association(self):
        self.fixture.accept_all()
        self.fixture.annotations["entries"] = [
            entry for entry in self.fixture.annotations["entries"]
            if entry["itemId"] != self._first_id()
        ]
        self.fixture.write_all()
        errors = self._verify()
        self._contains(errors, "annotations.json.entries: missing item entry for fr08-vowel-01")
        self._contains(errors, "reviewState reviewed requires accepted French/audio and rights decisions")

    def test_null_g2p_draft_never_substitutes_for_bound_final_human_reviews(self):
        item = self.fixture.item(self._first_id())
        item["reviewState"] = "reviewed"
        self.fixture.write_all()
        self._contains(self._verify(), "reviewState reviewed requires accepted French/audio and rights decisions")

    def test_metadata_roots_and_nested_records_fail_closed_on_unknown_fields(self):
        self._rewrite("provenance.json", lambda value: value.update(future=True))
        self._contains(self._verify(), "provenance.json: unknown field 'future'")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["source"].update(future=True))
        self._contains(self._verify(), "provenance[fr08-vowel-01].source: unknown field 'future'")
        self.setUp()
        self._rewrite("annotations.json", lambda value: value["entries"][0].update(future=True))
        self._contains(self._verify(), "annotations.json.entries[0]: unknown field 'future'")
        self.setUp()
        self._rewrite("source-evidence.json", lambda value: value["entries"][0].update(future=True))
        self._contains(self._verify(), "source-evidence.json.entries[0]: unknown field 'future'")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["original"].update(byteCount=1))
        self._contains(self._verify(), "provenance[fr08-vowel-01].original: unknown field 'byteCount'")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["rightsReview"].update(reviewSource="human"))
        self._contains(self._verify(), "manifest.json.sections[0].items[0].rightsReview: unknown field 'reviewSource'")

    def test_provenance_urls_raw_fields_and_transcript_correction_reasons_are_checked(self):
        self._rewrite("provenance.json", lambda value: value["entries"][0]["source"].update(retrievalUrl="http://example.invalid/source"))
        self._contains(self._verify(), "source.retrievalUrl: does not match pinned FLEURS TSV URL")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["source"].update(rawTranscription="changed"))
        self._contains(self._verify(), "source.rawTranscription does not match rawTsvRecord")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["derivation"].update(transcriptCorrectionRationale=" "))
        self.fixture.manifest["sections"][0]["items"][0]["text"] = "chat autre non."
        self.fixture.write_all()
        self._contains(self._verify(), "transcriptCorrectionRationale is required when item text is not an exact source excerpt")

    def test_source_excerpt_selection_cannot_cut_through_a_word_without_rationale(self):
        item = self.fixture.item(self._first_id())
        item["text"] = "ha"
        item["tokens"] = [{"id": "partial", "text": "ha", "phonemes": ["a"]}]
        item["expectedTokenIds"] = ["partial"]
        item["annotationHash"] = annotation_hash(item)
        entry = self.fixture.annotation_entry(item["id"])
        entry["annotationHash"] = item["annotationHash"]
        entry["tool"]["inputSha256"] = hashlib.sha256(b"ha").hexdigest()
        self.fixture.write_all()
        self._contains(self._verify(), "transcriptCorrectionRationale is required when item text is not an exact source excerpt")

    def test_source_excerpt_cannot_split_an_internal_hyphenated_word(self):
        item = self.fixture.item(self._first_id())
        item["text"] = "ami non."
        item["tokens"] = [
            {"id": "one", "text": "ami", "phonemes": ["a", "m", "i"]},
            {"id": "two", "text": "non", "phonemes": ["n", "ɔ̃"]},
        ]
        item["expectedTokenIds"] = ["one"]
        item["annotationHash"] = annotation_hash(item)
        annotation = self.fixture.annotation_entry(item["id"])
        annotation["annotationHash"] = item["annotationHash"]
        annotation["tool"]["inputSha256"] = hashlib.sha256(b"ami non.").hexdigest()
        source = self.fixture.provenance_entry(item["id"])["source"]
        source["rawTranscription"] = "chat-ami non."
        source["transcription"] = "chat-ami non."
        columns = source["rawTsvRecord"].split("\t")
        columns[2] = "chat-ami non."
        columns[3] = "chat-ami non."
        source["rawTsvRecord"] = "\t".join(columns)
        self.fixture.write_all()
        self._contains(self._verify(), "transcriptCorrectionRationale is required when item text is not an exact source excerpt")

    def test_pcm_crop_offsets_and_source_clip_encoding_are_bound(self):
        self._rewrite("provenance.json", lambda value: value["entries"][0]["derivation"].update(endFrame=SOURCE_FRAMES + 1))
        self._contains(self._verify(), "frame range must be bounded in source and nonempty")
        self.setUp()
        item_id = self._first_id()
        clip = self.root / self.fixture.item(item_id)["clipPath"]
        clip.write_bytes(_wav_bytes(bytes(range(12)), channels=2))
        self.fixture.refresh_audio_measurements(item_id, "clip")
        self._contains(self._verify(), "clip PCM rate/channels/sample width differ from source")
        self.setUp()
        original = self.root / self.fixture.item(self._first_id())["originalPath"]
        raw = bytearray(original.read_bytes())
        raw[20:22] = (3).to_bytes(2, "little")
        original.write_bytes(raw)
        self._contains(self._verify(), "invalid or unsupported WAV")

    def test_clip_hash_and_actual_measurement_length_are_checked_independently(self):
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0].update(clipSha256="f" * 64))
        self._contains(self._verify(), "manifest clipSha256 does not match actual clip file")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["clip"].update(byteLength=value["entries"][0]["clip"]["byteLength"] + 1))
        self._contains(self._verify(), ".clip.byteLength: does not match actual WAV")

    def test_actual_original_binary_hash_is_checked_even_if_manifest_claims_repeat(self):
        original = self.root / self.fixture.item(self._first_id())["originalPath"]
        raw = bytearray(original.read_bytes())
        raw[-1] ^= 0x55
        original.write_bytes(raw)
        self._contains(self._verify(), ".original.sha256: does not match SHA-256")

    def test_strict_numeric_metadata_rejects_boolean_duration_and_frame_width(self):
        self._rewrite("provenance.json", lambda value: value["entries"][0]["original"].update(durationSeconds=True))
        self._contains(self._verify(), ".original.durationSeconds: must be a strict positive finite number")
        self.setUp()
        self._rewrite("provenance.json", lambda value: value["entries"][0]["clip"].update(sampleWidth=True))
        self._contains(self._verify(), ".clip.sampleWidth: must be a strict positive integer")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0].update(policyRevision=1.0))
        self._contains(self._verify(), ".policyRevision: expected integer 1")

    def test_evidence_ids_are_unique_urls_timestamps_and_scopes_are_checked(self):
        self._rewrite("source-evidence.json", lambda value: value["entries"].append(dict(value["entries"][0])))
        self._contains(self._verify(), "duplicate source-evidence ID 'dataset-source'")
        self.setUp()
        self._rewrite("source-evidence.json", lambda value: value["entries"][0].update(url="file:///etc/passwd"))
        self._contains(self._verify(), "must be an absolute HTTPS URL without embedded credentials")
        self.setUp()
        self._rewrite("source-evidence.json", lambda value: value["entries"][0].update(retrievedAt="not-utc"))
        self._contains(self._verify(), ".retrievedAt: must be an explicit UTC timestamp")
        self.setUp()
        self._rewrite("source-evidence.json", lambda value: value["entries"][0].update(itemIds=["fr08-vowel-01"]))
        self._contains(self._verify(), "dataset evidence itemIds must be empty")

    def test_review_accepted_pending_rejected_and_unresolved_evidence_are_distinct(self):
        self.fixture.accept_all()
        item = self.fixture.item(self._first_id())
        item["reviewState"] = "pending"
        self.assertEqual(self._verify(), [])
        review = self.fixture.provenance_entry(item["id"])["rightsReview"]
        review.update({"status": "rejected", "notes": "SYNTHETIC rejection decision"})
        self.fixture.write_all()
        self.assertEqual(self._verify(), [])
        review["evidenceIds"] = ["missing-evidence"]
        self.fixture.write_all()
        self._contains(self._verify(), "unresolved evidence ID 'missing-evidence'")

    def test_null_draft_human_correction_and_final_mapping_must_be_consistent(self):
        item_id = self._first_id()
        item = self.fixture.item(item_id)
        first_token = item["tokens"][0]
        entry = self.fixture.annotation_entry(item_id)
        entry["corrections"] = [{
            "tokenId": first_token["id"], "before": [],
            "after": first_token["phonemes"],
            "rationale": "SYNTHETIC human contextual review resolution",
        }]
        self.fixture.write_all()
        self.assertEqual(self._verify(), [])
        entry["corrections"][0]["after"] = ["a"]
        self.fixture.write_all()
        self._contains(self._verify(), "correction final after does not match manifest token phonemes")

    def test_text_gap_cannot_hide_unselectable_nonpunctuation(self):
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0].update(text="chat ★ non."))
        self._contains(self._verify(), "whitespace gaps may contain punctuation only")

    def test_malformed_array_types_return_field_diagnostics_without_traceback(self):
        self._rewrite("manifest.json", lambda value: value["sections"][2]["items"][0].update(targetSound=["a"]))
        self._contains(self._verify(), "targetSound: must be a known sentence-local IPA phoneme")
        self.setUp()
        self._rewrite("manifest.json", lambda value: value["sections"][0].update(id=["wrong-shape"]))
        self._contains(self._verify(), "manifest.json.sections[0].id: must be 'en-fr-sentence-hunt-vowels'")

    def test_diagnostics_keep_authored_order_across_repeated_runs(self):
        self._rewrite("manifest.json", lambda value: value["sections"][0]["items"][0].update(targetSound="unknown"))
        first = self._verify()
        second = self._verify()
        self.assertEqual(first, second)
        self.assertIn("manifest.json.sections[0].items[0]", first[0])

    def test_cli_bad_source_evidence_is_failure_without_mutation_or_traceback(self):
        self._rewrite("source-evidence.json", lambda value: value["entries"][0].update(sha256="f" * 64))
        before = _snapshot(self.root)
        stdout, stderr, status = self._run_cli()
        self.assertEqual(status, 1)
        self.assertIn("source-evidence sha256 does not match UTF-8 text", stderr)
        self.assertNotIn("Traceback", stderr)
        self.assertEqual(_snapshot(self.root), before)

    def test_paths_must_be_confined_regular_files_under_expected_directories(self):
        self._rewrite("provenance.json", lambda value: value["entries"][0]["credit"].update(licenseTextPath="../LICENSE"))
        self._contains(self._verify(), "licenseTextPath must be a safe relative path under licenses/")

    def test_metadata_and_audio_verification_never_write_or_use_network_or_subprocess(self):
        before = _snapshot(self.root)
        with mock.patch("urllib.request.build_opener", side_effect=AssertionError("network edge used")), \
                mock.patch("urllib.request.urlopen", side_effect=AssertionError("network edge used")), \
                mock.patch("subprocess.run", side_effect=AssertionError("subprocess edge used")):
            self.assertEqual(self._verify(), [])
            stdout, stderr, status = self._run_cli()
            self.assertEqual(status, 0, stderr)
        self.assertEqual(_snapshot(self.root), before)
        (self.root / "manifest.json").write_text("{ malformed", encoding="utf-8")
        before = _snapshot(self.root)
        with mock.patch("urllib.request.build_opener", side_effect=AssertionError("network edge used")), \
                mock.patch("subprocess.run", side_effect=AssertionError("subprocess edge used")):
            errors = self._verify()
            self.assertTrue(errors)
            stdout, stderr, status = self._run_cli()
            self.assertEqual(status, 1)
            self.assertNotIn("Traceback", stderr)
        self.assertEqual(_snapshot(self.root), before)

    def test_cli_success_is_explicitly_metadata_only_and_reports_candidate_counts(self):
        stdout, stderr, status = self._run_cli()
        self.assertEqual(status, 0, stderr)
        self.assertEqual(stderr, "")
        self.assertIn("pending/unqualified: 15", stdout)
        self.assertIn("qualified: 0", stdout)
        self.assertIn("qualified sections: 0/3", stdout)
        self.assertIn("metadata-only", stdout.lower())
        self.assertIn("not linguistic truth", stdout.lower())

    def test_cli_require_reviewed_rejects_pending_without_mutation_or_traceback(self):
        before = _snapshot(self.root)
        stdout, stderr, status = self._run_cli(require_reviewed=True)
        self.assertEqual(status, 1)
        self.assertIn("--require-reviewed: 15 candidates are unqualified", stderr)
        self.assertNotIn("Traceback", stderr)
        self.assertEqual(_snapshot(self.root), before)

    def test_invalid_pcm_cli_failure_is_read_only_and_actionable(self):
        clip = self.root / self.fixture.item(self._first_id())["clipPath"]
        clip.write_bytes(b"not a WAV")
        before = _snapshot(self.root)
        stdout, stderr, status = self._run_cli()
        self.assertEqual(status, 1)
        self.assertIn("invalid or unsupported WAV", stderr)
        self.assertNotIn("Traceback", stderr)
        self.assertEqual(_snapshot(self.root), before)

    def _run_cli(self, require_reviewed=False):
        self.assertIsNotNone(main, "verifier CLI is not implemented yet")
        stdout, stderr = io.StringIO(), io.StringIO()
        argv = ["--package-root", str(self.root)]
        if require_reviewed:
            argv.append("--require-reviewed")
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            status = main(argv)
        return stdout.getvalue(), stderr.getvalue(), status


if __name__ == "__main__":
    unittest.main()
