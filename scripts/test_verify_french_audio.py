"""Focused tests for the offline French word-audio candidate verifier.

The fixture built here is unmistakable unit-test data: tiny synthetic 8 kHz
16-bit mono PCM WAVs, placeholder provenance URLs and licence texts. It is
not a human recording, and a passing verifier only proves the package is
internally consistent in a technical/metadata sense - it is not linguistic
sign-off or rights clearance.
"""

import contextlib
import copy
import hashlib
import io
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import wave
from pathlib import Path
from unittest import mock
from urllib.parse import quote, urlencode

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import verify_french_audio  # noqa: E402  (scripts/ is the module under test)

WORDS = [
    "tout", "rouge", "vous", "doux", "loup", "soupe", "tu", "rue", "lune",
    "jus", "mur", "plume", "lit", "si", "vite", "île", "beau", "mot", "eau",
    "dos", "bon", "nom", "banc", "sans",
]

WORD_IPAS = {
    "tout": "tu", "rouge": "ʁuʒ", "vous": "vu", "doux": "du", "loup": "lu",
    "soupe": "sup", "tu": "ty", "rue": "y", "lune": "lyn", "jus": "ʒy",
    "mur": "myʁ", "plume": "plym", "lit": "li", "si": "si", "vite": "vit",
    "île": "il", "beau": "bo", "mot": "mo", "eau": "o", "dos": "do",
    "bon": "bɔ̃", "nom": "nɔ̃", "banc": "bɑ̃k", "sans": "sɑ̃",
}

WORD_PHONEMES = {
    "tout": ["t", "u"], "rouge": ["ʁ", "u", "ʒ"], "vous": ["v", "u"],
    "doux": ["d", "u"], "loup": ["l", "u"], "soupe": ["s", "u", "p"],
    "tu": ["t", "y"], "rue": ["y"], "lune": ["l", "y", "n"], "jus": ["ʒ", "y"],
    "mur": ["m", "y", "ʁ"], "plume": ["p", "l", "y", "m"], "lit": ["l", "i"],
    "si": ["s", "i"], "vite": ["v", "i", "t"], "île": ["i", "l"],
    "beau": ["b", "o"], "mot": ["m", "o"], "eau": ["o"], "dos": ["d", "o"],
    "bon": ["b", "ɔ̃"], "nom": ["n", "ɔ̃"], "banc": ["b", "ɑ̃", "k"],
    "sans": ["s", "ɑ̃"],
}

WORD_TARGETS = {
    "tout": ["u"], "rouge": ["u", "ʁ"], "vous": ["u"], "doux": ["u"],
    "loup": ["u"], "soupe": ["u"], "tu": ["y"], "rue": ["y"], "lune": ["y"],
    "jus": ["y"], "mur": ["y", "ʁ"], "plume": ["y"], "lit": ["i"], "si": ["i"],
    "vite": ["i"], "île": ["i"], "beau": ["o"], "mot": ["o"], "eau": ["o"],
    "dos": ["o"], "bon": ["ɔ̃"], "nom": ["ɔ̃"], "banc": ["ɑ̃"], "sans": ["ɑ̃"],
}

BY_SA = ("CC-BY-SA-4.0",
         "https://creativecommons.org/licenses/by-sa/4.0/",
         "frontend/assets/audio/fr/licenses/cc-by-sa-4-0.txt")
BY = ("CC-BY-4.0",
      "https://creativecommons.org/licenses/by/4.0/",
      "frontend/assets/audio/fr/licenses/cc-by-4-0.txt")
def _canonical_media_url(word: str) -> str:
    """Canonical current original-media URL shape for the selected file.

    '/wikipedia/commons/<1 hex>/<2 hex>/<complete filename>' — the ordinary
    original-file layout, with the full selected filename
    (LL-Q150_(fra)-LoquaxFR-<word>.wav) URL-encoded.  The hash directories
    route the object storage layout; the identity is the complete filename.
    """
    name = f"LL-Q150_(fra)-LoquaxFR-{word}.wav"
    digest = hashlib.md5(name.encode("utf-8")).hexdigest()
    return ("https://upload.wikimedia.org/wikipedia/commons/"
            + digest[0] + "/" + digest[:2] + "/" + quote(name, safe=""))


# Independently observed canonical selected originals, extracted from the
# current Commons description pages by the reviewer and the controller
# (task-1-controller-fix3-findings.log; read-only page inspection, no binary
# downloads).  These literals — not the helper's algorithm — are the oracle
# for the positive media controls.
CANONICAL_ORIGINALS = {
    "tout": ("https://upload.wikimedia.org/wikipedia/commons/4/4b/"
             "LL-Q150_%28fra%29-LoquaxFR-tout.wav"),
    "île": ("https://upload.wikimedia.org/wikipedia/commons/c/c7/"
            "LL-Q150_%28fra%29-LoquaxFR-%C3%AEle.wav"),
}

# The 24 selected description revisions, verbatim from the committed research
# (docs/superpowers/research/2026-10-12-french-reference-audio-sources.md,
# lines 102-125).  These are the actual selected Commons links the verifier
# must accept: real /w/index.php route, real recorded oldids, parenthesized
# filenames, and the percent-encoded UTF-8 identity for `île`.
SELECTED_REVISIONS = {
    "tout": (995917835,
             "https://commons.wikimedia.org/w/index.php?"
             "title=File:LL-Q150_(fra)-LoquaxFR-tout.wav&oldid=995917835"),
    "rouge": (1284656035,
              "https://commons.wikimedia.org/w/index.php?"
              "title=File:LL-Q150_(fra)-LoquaxFR-rouge.wav&oldid=1284656035"),
    "vous": (1278768654,
             "https://commons.wikimedia.org/w/index.php?"
             "title=File:LL-Q150_(fra)-LoquaxFR-vous.wav&oldid=1278768654"),
    "doux": (1281359588,
             "https://commons.wikimedia.org/w/index.php?"
             "title=File:LL-Q150_(fra)-LoquaxFR-doux.wav&oldid=1281359588"),
    "loup": (1279338035,
             "https://commons.wikimedia.org/w/index.php?"
             "title=File:LL-Q150_(fra)-LoquaxFR-loup.wav&oldid=1279338035"),
    "soupe": (1285345152,
              "https://commons.wikimedia.org/w/index.php?"
              "title=File:LL-Q150_(fra)-LoquaxFR-soupe.wav&oldid=1285345152"),
    "tu": (1094009241,
           "https://commons.wikimedia.org/w/index.php?"
           "title=File:LL-Q150_(fra)-LoquaxFR-tu.wav&oldid=1094009241"),
    "rue": (1166165910,
            "https://commons.wikimedia.org/w/index.php?"
            "title=File:LL-Q150_(fra)-LoquaxFR-rue.wav&oldid=1166165910"),
    "lune": (757831102,
             "https://commons.wikimedia.org/w/index.php?"
             "title=File:LL-Q150_(fra)-LoquaxFR-lune.wav&oldid=757831102"),
    "jus": (1185863234,
            "https://commons.wikimedia.org/w/index.php?"
            "title=File:LL-Q150_(fra)-LoquaxFR-jus.wav&oldid=1185863234"),
    "mur": (1284027183,
            "https://commons.wikimedia.org/w/index.php?"
            "title=File:LL-Q150_(fra)-LoquaxFR-mur.wav&oldid=1284027183"),
    "plume": (1280911696,
              "https://commons.wikimedia.org/w/index.php?"
              "title=File:LL-Q150_(fra)-LoquaxFR-plume.wav&oldid=1280911696"),
    "lit": (1279171160,
            "https://commons.wikimedia.org/w/index.php?"
            "title=File:LL-Q150_(fra)-LoquaxFR-lit.wav&oldid=1279171160"),
    "si": (1128084534,
           "https://commons.wikimedia.org/w/index.php?"
           "title=File:LL-Q150_(fra)-LoquaxFR-si.wav&oldid=1128084534"),
    "vite": (1284466369,
             "https://commons.wikimedia.org/w/index.php?"
             "title=File:LL-Q150_(fra)-LoquaxFR-vite.wav&oldid=1284466369"),
    "île": (815828932,
            "https://commons.wikimedia.org/w/index.php?"
            "title=File:LL-Q150_(fra)-LoquaxFR-%C3%AEle.wav&oldid=815828932"),
    "beau": (1282497196,
             "https://commons.wikimedia.org/w/index.php?"
             "title=File:LL-Q150_(fra)-LoquaxFR-beau.wav&oldid=1282497196"),
    "mot": (758647723,
            "https://commons.wikimedia.org/w/index.php?"
            "title=File:LL-Q150_(fra)-LoquaxFR-mot.wav&oldid=758647723"),
    "eau": (1280603339,
            "https://commons.wikimedia.org/w/index.php?"
            "title=File:LL-Q150_(fra)-LoquaxFR-eau.wav&oldid=1280603339"),
    "dos": (1252930601,
            "https://commons.wikimedia.org/w/index.php?"
            "title=File:LL-Q150_(fra)-LoquaxFR-dos.wav&oldid=1252930601"),
    "bon": (1284656117,
            "https://commons.wikimedia.org/w/index.php?"
            "title=File:LL-Q150_(fra)-LoquaxFR-bon.wav&oldid=1284656117"),
    "nom": (1279088536,
            "https://commons.wikimedia.org/w/index.php?"
            "title=File:LL-Q150_(fra)-LoquaxFR-nom.wav&oldid=1279088536"),
    "banc": (1283505337,
             "https://commons.wikimedia.org/w/index.php?"
             "title=File:LL-Q150_(fra)-LoquaxFR-banc.wav&oldid=1283505337"),
    "sans": (1273911708,
             "https://commons.wikimedia.org/w/index.php?"
             "title=File:LL-Q150_(fra)-LoquaxFR-sans.wav&oldid=1273911708"),
}
NOTICES = ["Unmistakable unit-test notice; a placeholder, not a real rights statement."]
ORIGIN = {
    "path": "frontend/lib/src/core/course/french_course.dart",
    "symbol": "frenchWords",
    "revision": "a" * 40,  # full 40-hex Git revision placeholder (test data)
    "status": "existingCuratedNotRecordingReviewed",
}


def _pcm_wav_bytes(frames=80, sample_rate=8000, extra_metadata=b""):
    """Compose a tiny 16-bit mono PCM RIFF/WAVE container (test-only bytes)."""
    payload = b"\x01\x02" * frames  # 16-bit little-endian test pattern, not speech
    fmt = struct.pack("<HHIIHH", 1, 1, sample_rate, sample_rate * 2, 2, 16)
    extra = extra_metadata
    if len(extra) & 1:
        extra += b"\x00"  # RIFF chunk-alignment padding
    body = (b"fmt " + struct.pack("<I", len(fmt)) + fmt) + extra + \
        (b"data" + struct.pack("<I", len(payload)) + payload)
    return b"RIFF" + struct.pack("<I", len(body) + 4) + b"WAVE" + body


def _wav_data_before_fmt() -> bytes:
    """Coherent RIFF/WAVE container whose data chunk precedes the fmt chunk."""
    payload = b"\x01\x02" * 80
    fmt = struct.pack("<HHIIHH", 1, 1, 8000, 16000, 2, 16)
    body = (b"data" + struct.pack("<I", len(payload)) + payload) + \
        (b"fmt " + struct.pack("<I", len(fmt)) + fmt)
    return b"RIFF" + struct.pack("<I", len(body) + 4) + b"WAVE" + body


def make_package(repo_root: Path) -> None:
    """Create a complete 24-entry temporary candidate fixture.

    The samples are tiny, unmistakable unit-test PCM data, not human
    recordings or product assets.
    """
    asset_dir = repo_root / "frontend" / "assets" / "audio" / "fr"
    words_dir = asset_dir / "words"
    licenses_dir = asset_dir / "licenses"
    words_dir.mkdir(parents=True, exist_ok=True)
    licenses_dir.mkdir(parents=True, exist_ok=True)

    (licenses_dir / "cc-by-sa-4-0.txt").write_text(
        "Official CC BY-SA 4.0 legal code excerpt (unmistakable test fixture).\n"
        "Source: https://creativecommons.org/licenses/by-sa/4.0/legalcode\n",
        encoding="utf-8",
    )
    (licenses_dir / "cc-by-4-0.txt").write_text(
        "Official CC BY 4.0 legal code excerpt (unmistakable test fixture).\n"
        "Source: https://creativecommons.org/licenses/by/4.0/legalcode\n",
        encoding="utf-8",
    )

    wav_bytes = _pcm_wav_bytes()
    sha256 = hashlib.sha256(wav_bytes).hexdigest()
    sha1 = hashlib.sha1(wav_bytes, usedforsecurity=False).hexdigest()
    audio = {
        "container": "wav", "encoding": "pcm", "sampleRateHz": 8000,
        "channels": 1, "bitsPerSample": 16, "frameCount": 80,
        "durationSeconds": 0.01,
    }
    speaker = {
        "sourceName": "LoquaxFR",
        "qualificationStatus": "unverified",
        "accent": None,
    }
    review = {
        "status": "pending",
        "reviewer": None,
        "reviewedAt": None,
        "evidence": [],
    }

    entries = []
    provenance_entries = []
    for word in WORDS:
        spdx, url, text_path = BY if word == "sans" else BY_SA
        # Structurally valid selected-source representations: the chosen
        # filename pattern and the documented /w/index.php description
        # revisions from the committed research.  The audio bytes themselves
        # remain synthetic unit-test data (see credit).
        revision_id, revision_url = SELECTED_REVISIONS[word]
        title = f"File:LL-Q150_(fra)-LoquaxFR-{word}.wav"
        credit_text = (
            f"« {word} » spoken by LoquaxFR (Lingua Libre), {spdx}, "
            f"via Wikimedia Commons (unmistakable test fixture; the unit-test "
            f"WAV bytes are synthetic, not the source binary)."
        )
        entries.append({
            "id": f"fr-word-{word}",
            "kind": "word",
            "spokenText": word,
            "assetPath": "frontend/assets/audio/fr/words/" + word + ".wav",
            "sha256": sha256,
            "byteLength": len(wav_bytes),
            "audio": dict(audio),
            "mapping": {
                "expectedIpa": WORD_IPAS[word],
                "phonemes": list(WORD_PHONEMES[word]),
                "teachingTargets": list(WORD_TARGETS[word]),
                "origin": dict(ORIGIN),
            },
            "speaker": dict(speaker),
            "license": {
                "spdxId": spdx,
                "url": url,
                "textPath": text_path,
                "attribution": credit_text,
                "notices": list(NOTICES),
            },
            "provenanceId": f"prov-{word}",
            "changes": [],
            "review": dict(review),
        })
        provenance_entries.append({
            "id": f"prov-{word}",
            "sourcePageUrl": (
                "https://commons.wikimedia.org/wiki/" + quote(title, safe="")
            ),
            "sourceTitle": title,
            "descriptionRevisionId": revision_id,
            "descriptionRevisionUrl": revision_url,
            "retrievedAt": "2026-10-12T10:00:00Z",
            "originalDownloadUrl": _canonical_media_url(word),
            "mediaTimestamp": "2026-01-15T09:30:00Z",
            "sourceSha1": sha1,
            "sourceTranscription": word,
            "sourceSpeaker": "LoquaxFR",
            "creditedCreators": ["LoquaxFR"],
            "licenseEvidence": {
                "spdxId": spdx,
                "url": url,
                "creditText": credit_text,
                "notices": list(NOTICES),
                "declaration": (
                    f"Unmistakable test-fixture declaration: source records {spdx}."
                ),
            },
            "sha256": sha256,
        })
        (words_dir / f"{word}.wav").write_bytes(wav_bytes)

    manifest = {
        "schemaVersion": 1,
        "catalogueStatus": "candidate",
        "language": "fr",
        "entries": entries,
    }
    provenance = {"schemaVersion": 1, "entries": provenance_entries}
    (asset_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (asset_dir / "provenance.json").write_text(
        json.dumps(provenance, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


class FixtureBase(unittest.TestCase):
    """Temporary fixture package, cwd control, and hard network denial."""

    def setUp(self):
        # Any network use by the module under test must raise here.
        self._denials = [
            mock.patch("socket.socket",
                       side_effect=AssertionError("test network is denied")),
            mock.patch("socket.create_connection",
                       side_effect=AssertionError("test network is denied")),
            mock.patch("socket.getaddrinfo",
                       side_effect=AssertionError("test network is denied")),
        ]
        for patcher in self._denials:
            patcher.start()
        self.addCleanup(self._stop_denials)

        self._original_cwd = os.getcwd()
        self.addCleanup(os.chdir, self._original_cwd)

        self._tmp = tempfile.TemporaryDirectory(prefix="fr-audio-verify-")
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        make_package(self.root)

    def _stop_denials(self):
        for patcher in self._denials:
            patcher.stop()

    def _fresh(self) -> None:
        """Rebuild an intact fixture inside a new temporary root."""
        self._tmp.cleanup()
        self._tmp = tempfile.TemporaryDirectory(prefix="fr-audio-verify-")
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        make_package(self.root)

    # -- fixture access helpers -------------------------------------------

    def _asset(self) -> Path:
        return self.root / "frontend" / "assets" / "audio" / "fr"

    def _json(self, name: str):
        return json.loads((self._asset() / name).read_text(encoding="utf-8"))

    def _write_json(self, name: str, value) -> None:
        (self._asset() / name).write_text(
            json.dumps(value, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8")

    def _replace_in_text(self, name: str, old: str, new: str) -> None:
        path = self._asset() / name
        text = path.read_text(encoding="utf-8")
        assertIn = self.assertIn
        assertIn(old, text)
        path.write_text(text.replace(old, new, 1), encoding="utf-8")

    def _entry(self, entries, word: str) -> dict:
        for entry in entries:
            if isinstance(entry, dict) and (
                    entry.get("spokenText") == word or
                    entry.get("id") in (f"fr-word-{word}", f"prov-{word}")):
                return entry
        raise AssertionError(f"fixture entry for {word!r} not found")

    def _mutate_entry(self, word: str, change) -> None:
        manifest = self._json("manifest.json")
        change(self._entry(manifest["entries"], word))
        self._write_json("manifest.json", manifest)

    def _mutate_provenance_entry(self, word: str, change) -> None:
        doc = self._json("provenance.json")
        change(self._entry(doc["entries"], word))
        self._write_json("provenance.json", doc)

    # -- snapshot / read-only assertions ------------------------------------

    def _tree_snapshot(self) -> dict[str, bytes]:
        return {
            str(path.relative_to(self.root)): path.read_bytes()
            for path in sorted(p for p in self.root.rglob("*") if p.is_file())
        }

    def _expect_failure(self, *tokens: str) -> str:
        """Run verify_package; require diagnostics naming `tokens`, no writes."""
        before = self._tree_snapshot()
        diagnostics = verify_french_audio.verify_package(self.root)
        self.assertTrue(diagnostics, "verification unexpectedly passed")
        joined = "\n".join(diagnostics)
        for token in tokens:
            self.assertIn(token, joined)
        self.assertEqual(
            self._tree_snapshot(), before,
            "verification must leave the package bytes unchanged")
        return joined


class VerifierTests(FixtureBase):
    """Positive behaviour of the offline verifier on the fixture package."""

    def test_valid_package(self):
        self.assertEqual(verify_french_audio.verify_package(self.root), [])

    def test_measure_wav(self):
        audio = verify_french_audio.measure_wav(
            self.root / "frontend/assets/audio/fr/words/tout.wav")
        self.assertEqual(audio, {
            "container": "wav", "encoding": "pcm", "sampleRateHz": 8000,
            "channels": 1, "bitsPerSample": 16, "frameCount": 80,
            "durationSeconds": 0.01,
        })

    def test_cli_from_another_directory(self):
        os.chdir(tempfile.gettempdir())
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = verify_french_audio.main(["--repo-root", str(self.root)])
        self.assertEqual(status, 0)
        self.assertIn(
            "PASS: 24 pending French word candidates verified "
            "(technical/metadata only).",
            output.getvalue(),
        )

    def test_cli_from_default_repository_root(self):
        """--repo-root defaults to the script's own repository root, not the cwd."""
        nested_root = self.root / "nested-repo"
        nested_scripts = nested_root / "scripts"
        nested_scripts.mkdir(parents=True)
        script = nested_scripts / "verify_french_audio.py"
        shutil.copy2(SCRIPT_DIR / "verify_french_audio.py", script)
        make_package(nested_root)
        # The cwd (self.root) deliberately contains no package and cannot
        # supply the default root; only the script location can.
        process = subprocess.run(
            [sys.executable, str(script)],
            cwd=self.root,
            capture_output=True,
            text=True,
            env={**os.environ, "PYTHONPATH": str(SCRIPT_DIR)},
        )
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        self.assertIn(
            "PASS: 24 pending French word candidates verified", process.stdout)


class PackageMutationTests(FixtureBase):
    """Planted defects must yield actionable diagnostics, never rewrites."""

    # -- schema -------------------------------------------------------------

    def test_schema_failures(self):
        with self.subTest("invalid UTF-8"):
            self._fresh()
            (self._asset() / "manifest.json").write_bytes(b"\xff\xfe{")
            self._expect_failure("UTF-8")
        with self.subTest("invalid JSON"):
            self._fresh()
            (self._asset() / "manifest.json").write_text(
                '{"schemaVersion": oops', encoding="utf-8")
            self._expect_failure("JSON")
        with self.subTest("duplicate top-level key"):
            self._fresh()
            self._replace_in_text(
                "manifest.json",
                '"schemaVersion": 1',
                '"schemaVersion": 1, "schemaVersion": 1',
            )
            self._expect_failure("duplicate")
        with self.subTest("nested duplicate key"):
            self._fresh()
            self._replace_in_text(
                "manifest.json",
                '"kind": "word"',
                '"kind": "word", "kind": "sentence"',
            )
            self._expect_failure("duplicate")
        with self.subTest("missing root field"):
            self._fresh()
            manifest = self._json("manifest.json")
            del manifest["catalogueStatus"]
            self._write_json("manifest.json", manifest)
            self._expect_failure("catalogueStatus")
        with self.subTest("unknown root field"):
            self._fresh()
            manifest = self._json("manifest.json")
            manifest["extra"] = True
            self._write_json("manifest.json", manifest)
            self._expect_failure("extra", "unknown")
        with self.subTest("schemaVersion 2"):
            self._fresh()
            manifest = self._json("manifest.json")
            manifest["schemaVersion"] = 2
            self._write_json("manifest.json", manifest)
            self._expect_failure("schemaVersion")
        with self.subTest("missing nested field"):
            self._fresh()
            self._mutate_entry("tout", lambda e: e.__delitem__("license"))
            self._expect_failure("license")
        with self.subTest("unknown nested field"):
            self._fresh()
            self._mutate_entry("tout", lambda e: e.update({"extra": 1}))
            self._expect_failure("extra", "unknown")
        with self.subTest("null required string"):
            self._fresh()
            self._mutate_entry("tout", lambda e: e.update({"spokenText": None}))
            self._expect_failure("spokenText")
        with self.subTest("boolean where integer expected"):
            self._fresh()
            def bad_numbers(entry):
                entry["byteLength"] = True
                entry["audio"]["sampleRateHz"] = False
            self._mutate_entry("tout", bad_numbers)
            self._expect_failure("byteLength", "sampleRateHz")
        with self.subTest("NaN duration"):
            self._fresh()
            self._replace_in_text(
                "manifest.json",
                '"durationSeconds": 0.01',
                '"durationSeconds": NaN',
            )
            self._expect_failure("non-finite")
        with self.subTest("Infinity duration"):
            self._fresh()
            self._replace_in_text(
                "manifest.json",
                '"durationSeconds": 0.01',
                '"durationSeconds": Infinity',
            )
            self._expect_failure("non-finite")
        with self.subTest("missing durationSeconds"):
            self._fresh()
            self._mutate_entry(
                "tout", lambda e: e["audio"].pop("durationSeconds"))
            self._expect_failure("durationSeconds")
        with self.subTest("enormous integer duration"):
            self._fresh()
            self._mutate_entry(
                "tout", lambda e: e["audio"].update({"durationSeconds": 10 ** 400}))
            self._expect_failure("durationSeconds")
        with self.subTest("negative duration"):
            self._fresh()
            self._mutate_entry(
                "tout", lambda e: e["audio"].update({"durationSeconds": -5}))
            self._expect_failure("durationSeconds")
        with self.subTest("boolean manifest schemaVersion"):
            self._fresh()
            manifest = self._json("manifest.json")
            manifest["schemaVersion"] = True
            self._write_json("manifest.json", manifest)
            self._expect_failure("schemaVersion")
        with self.subTest("boolean provenance schemaVersion"):
            self._fresh()
            doc = self._json("provenance.json")
            doc["schemaVersion"] = True
            self._write_json("provenance.json", doc)
            self._expect_failure("schemaVersion")

    # -- I1: non-object parsed roots must never pass -----------------------

    def test_non_object_roots_fail(self):
        with self.subTest("manifest root is a list"):
            self._fresh()
            (self._asset() / "manifest.json").write_text("[]", encoding="utf-8")
            self._expect_failure("manifest.json", "object")
        with self.subTest("manifest root is a scalar"):
            self._fresh()
            (self._asset() / "manifest.json").write_text("42", encoding="utf-8")
            self._expect_failure("manifest.json", "object")
        with self.subTest("provenance root is null"):
            self._fresh()
            (self._asset() / "provenance.json").write_text(
                "null", encoding="utf-8")
            self._expect_failure("provenance.json", "object")
        with self.subTest("provenance root is a scalar"):
            self._fresh()
            (self._asset() / "provenance.json").write_text(
                "42", encoding="utf-8")
            self._expect_failure("provenance.json", "object")

    # -- identity ------------------------------------------------------------

    def test_identity_failures(self):
        with self.subTest("missing record"):
            self._fresh()
            manifest = self._json("manifest.json")
            manifest["entries"].pop(0)
            self._write_json("manifest.json", manifest)
            self._expect_failure("entries")
        with self.subTest("extra record"):
            self._fresh()
            manifest = self._json("manifest.json")
            manifest["entries"].append(dict(manifest["entries"][0]))
            self._write_json("manifest.json", manifest)
            self._expect_failure("entries")
        with self.subTest("reordered records"):
            self._fresh()
            manifest = self._json("manifest.json")
            manifest["entries"][0], manifest["entries"][1] = (
                manifest["entries"][1], manifest["entries"][0])
            self._write_json("manifest.json", manifest)
            self._expect_failure("fr-word-tout")
        with self.subTest("duplicate id"):
            self._fresh()
            self._mutate_entry(
                "rouge", lambda e: e.update({"id": "fr-word-tout"}))
            self._expect_failure("fr-word-tout")
        with self.subTest("duplicate assetPath"):
            self._fresh()
            self._mutate_entry(
                "rouge", lambda e: e.update({"assetPath": "words/tout.wav"}))
            self._expect_failure("words/tout.wav")
        with self.subTest("wrong kind"):
            self._fresh()
            self._mutate_entry("tout", lambda e: e.update({"kind": "sentence"}))
            self._expect_failure("kind")
        with self.subTest("wrong spokenText"):
            self._fresh()
            self._mutate_entry(
                "tout", lambda e: e.update({"spokenText": "toût"}))
            self._expect_failure("spokenText")
        with self.subTest("ASCII ile instead of île"):
            self._fresh()
            self._mutate_entry("île", lambda e: e.update({"id": "fr-word-ile"}))
            self._expect_failure("île")
        with self.subTest("Unicode-decomposed île"):
            self._fresh()
            self._mutate_entry(
                "île", lambda e: e.update({"spokenText": "i\u0308"}))
            self._expect_failure("î")
        with self.subTest("unlisted WAV"):
            self._fresh()
            (self._asset() / "words" / "zz-not-listed.wav").write_bytes(
                b"\x01\x02" * 8)
            self._expect_failure("zz-not-listed.wav")
        with self.subTest("missing WAV"):
            self._fresh()
            (self._asset() / "words" / "tout.wav").unlink()
            self._expect_failure("words/tout.wav")

    # -- paths ----------------------------------------------------------------

    def _replace_with_symlink(self, target: Path, outside: Path) -> None:
        target.unlink()
        target.symlink_to(outside)

    def test_path_failures(self):
        with self.subTest("absolute assetPath"):
            self._fresh()
            self._mutate_entry(
                "tout", lambda e: e.update({"assetPath": "/etc/passwd"}))
            self._expect_failure("/etc/passwd")
        with self.subTest("traversal assetPath"):
            self._fresh()
            (self._asset().parent / "sneaky.wav").write_bytes(b"\x01\x02" * 8)
            self._mutate_entry(
                "tout", lambda e: e.update({"assetPath": "../sneaky.wav"}))
            self._expect_failure("../sneaky.wav")
        with self.subTest("assetPath outside the asset directory"):
            self._fresh()
            target = self.root / "frontend" / "lib" / "imported.wav"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(b"\x01\x02" * 8)
            self._mutate_entry(
                "tout",
                lambda e: e.update(
                    {"assetPath": "../../../lib/imported.wav"}))
            self._expect_failure("../../../lib/imported.wav")
        with self.subTest("symlinked WAV"):
            self._fresh()
            outside = self.root / "elsewhere.wav"
            outside.write_bytes(b"\x01\x02" * 8)
            self._replace_with_symlink(self._asset() / "words" / "tout.wav",
                                       outside)
            self._expect_failure("symlink")
        with self.subTest("symlinked parent directory"):
            self._fresh()
            words = self._asset() / "words"
            real = self._asset() / "words-real"
            words.rename(real)
            words.symlink_to(real)
            self._expect_failure("symlink")
        with self.subTest("symlinked licence file"):
            self._fresh()
            text = self._asset() / "licenses" / "cc-by-sa-4-0.txt"
            outside = self.root / "licence.txt"
            outside.write_bytes(text.read_bytes())
            self._replace_with_symlink(text, outside)
            self._expect_failure("symlink")
        with self.subTest("symlinked licence parent"):
            self._fresh()
            licenses = self._asset() / "licenses"
            real = self._asset() / "licenses-real"
            licenses.rename(real)
            licenses.symlink_to(real)
            self._expect_failure("symlink")
        with self.subTest("licence outside licenses/"):
            self._fresh()
            (self._asset() / "escape-licence.txt").write_text(
                "not under licenses/\n", encoding="utf-8")
            self._mutate_entry(
                "tout",
                lambda e: e["license"].update({"textPath": "escape-licence.txt"}))
            self._expect_failure("licenses/")
        with self.subTest("package-relative assetPath is invalid"):
            self._fresh()
            self._mutate_entry(
                "tout", lambda e: e.update({"assetPath": "words/tout.wav"}))
            self._expect_failure("frontend/assets/audio/fr/")
        with self.subTest("package-relative textPath is invalid"):
            self._fresh()
            self._mutate_entry(
                "tout",
                lambda e: e["license"].update(
                    {"textPath": "licenses/cc-by-sa-4-0.txt"}))
            self._expect_failure("frontend/assets/audio/fr/licenses/")

    # -- integrity --------------------------------------------------------------

    def test_integrity_failures(self):
        with self.subTest("tampered bytes"):
            self._fresh()
            wav = self._asset() / "words" / "tout.wav"
            raw = bytearray(wav.read_bytes())
            raw[len(raw) // 2] ^= 0xFF
            wav.write_bytes(bytes(raw))
            self._expect_failure("sha256")
        with self.subTest("false byteLength"):
            self._fresh()
            manifest = self._json("manifest.json")
            entry = self._entry(manifest["entries"], "tout")
            entry["byteLength"] += 1
            self._write_json("manifest.json", manifest)
            self._expect_failure("byteLength")
        with self.subTest("false sha256"):
            self._fresh()
            self._mutate_entry("tout", lambda e: e.update({"sha256": "0" * 64}))
            self._expect_failure("sha256")
        with self.subTest("false audio properties"):
            self._fresh()
            self._mutate_entry(
                "tout", lambda e: e["audio"].update({"sampleRateHz": 44100}))
            self._expect_failure("sampleRateHz")
        with self.subTest("zero frames"):
            self._fresh()
            empty = (b"RIFF" + struct.pack("<I", 4 + 8 + 16 + 8) + b"WAVE"
                     + b"fmt " + struct.pack("<I", 16)
                     + struct.pack("<HHIIHH", 1, 1, 8000, 16000, 2, 16)
                     + b"data" + struct.pack("<I", 0))
            (self._asset() / "words" / "tout.wav").write_bytes(empty)
            def zero(entry):
                entry["sha256"] = hashlib.sha256(empty).hexdigest()
                entry["byteLength"] = len(empty)
                entry["audio"]["frameCount"] = 0
                entry["audio"]["durationSeconds"] = 0
            self._mutate_entry("tout", zero)
            self._expect_failure("frame")
        with self.subTest("claimed frame count exceeds actual"):
            self._fresh()
            self._mutate_entry(
                "tout",
                lambda e: e["audio"].update(
                    {"frameCount": 120, "durationSeconds": 0.015}))
            self._expect_failure("frameCount")
        with self.subTest("incomplete RIFF chunk"):
            self._fresh()
            wav = self._asset() / "words" / "tout.wav"
            wav.write_bytes(wav.read_bytes()[:60])
            self._expect_failure("RIFF")
        with self.subTest("data chunk before fmt chunk"):
            self._fresh()
            wav_bytes = _wav_data_before_fmt()
            wav_path = self._asset() / "words" / "tout.wav"
            wav_path.write_bytes(wav_bytes)
            sha256 = hashlib.sha256(wav_bytes).hexdigest()
            sha1 = hashlib.sha1(wav_bytes, usedforsecurity=False).hexdigest()
            self._mutate_entry(
                "tout",
                lambda e: e.update(
                    {"sha256": sha256, "byteLength": len(wav_bytes)}))
            self._mutate_provenance_entry(
                "tout",
                lambda e: e.update({"sha256": sha256, "sourceSha1": sha1}))
            self._expect_failure("fmt")

    # -- rights and evidence -----------------------------------------------------

    def test_rights_and_evidence_failures(self):
        with self.subTest("swapped sans licence"):
            self._fresh()
            self._mutate_entry(
                "sans",
                lambda e: e["license"].update({
                    "spdxId": "CC-BY-SA-4.0",
                    "url": BY_SA[1],
                    "textPath": BY_SA[2],
                }))
            self._expect_failure("sans", "CC-BY-4.0")
        with self.subTest("wrong licence URL"):
            self._fresh()
            self._mutate_entry(
                "sans",
                lambda e: e["license"].update(
                    {"url": "https://creativecommons.org/licenses/by/3.0/"}))
            self._expect_failure("url")
        with self.subTest("empty attribution"):
            self._fresh()
            self._mutate_entry(
                "tout", lambda e: e["license"].update({"attribution": ""}))
            self._expect_failure("attribution")
        with self.subTest("empty declaration"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e["licenseEvidence"].update({"declaration": ""}))
            self._expect_failure("declaration")
        with self.subTest("empty credited creators"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout", lambda e: e.update({"creditedCreators": []}))
            self._expect_failure("creditedCreators")
        with self.subTest("absent licence text"):
            self._fresh()
            (self._asset() / "licenses" / "cc-by-sa-4-0.txt").unlink()
            self._expect_failure("cc-by-sa-4-0.txt")
        with self.subTest("provenance hash mismatch"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout", lambda e: e.update({"sha256": "f" * 64}))
            self._expect_failure("sha256")
        with self.subTest("different transcription"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout", lambda e: e.update({"sourceTranscription": "toutt"}))
            self._expect_failure("sourceTranscription")
        with self.subTest("different speaker"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout", lambda e: e.update({"sourceSpeaker": "SomebodyElse"}))
            self._expect_failure("sourceSpeaker")
        with self.subTest("different notices"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e["licenseEvidence"].update({"notices": ["forged"]}))
            self._expect_failure("notices")
        with self.subTest("different licence evidence id"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e["licenseEvidence"].update(
                    {"spdxId": "CC-BY-4.0", "url": BY[1]}))
            self._expect_failure("spdxId")
        with self.subTest("null manifest spdx with bogus URL"):
            self._fresh()
            self._mutate_entry(
                "tout",
                lambda e: e["license"].update(
                    {"spdxId": None, "url": "bogus"}))
            self._expect_failure("spdxId", "url")
        with self.subTest("null evidence spdx and url"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e["licenseEvidence"].update(
                    {"spdxId": None, "url": None}))
            self._expect_failure("spdxId", "url")
        with self.subTest("different credit text"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e["licenseEvidence"].update(
                    {"creditText": "Different credit"}))
            self._expect_failure("creditText")
        with self.subTest("source title not designating the word"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e.update({"sourceTitle": "File:Some-Other-File.wav"}))
            self._expect_failure("sourceTitle")
        with self.subTest("revision URL mismatch"):
            self._fresh()
            def bad_revision(entry):
                entry["descriptionRevisionUrl"] = (
                    "https://commons.wikimedia.org/index.php?"
                    + urlencode({"title": entry["sourceTitle"], "oldid": 1}))
            self._mutate_provenance_entry("tout", bad_revision)
            self._expect_failure("descriptionRevisionUrl")
        with self.subTest("wrong media URL"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e.update(
                    {"originalDownloadUrl":
                        "https://upload.wikimedia.org/wikipedia/foo/other.bin"}))
            self._expect_failure("originalDownloadUrl")
        with self.subTest("malformed retrievedAt"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e.update({"retrievedAt": "12/10/2026 10:00"}))
            self._expect_failure("retrievedAt")
        with self.subTest("non-UTC offset timestamp"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e.update(
                    {"retrievedAt": "2026-10-12T12:00:00+02:00"}))
            self._expect_failure("retrievedAt")
        with self.subTest("malformed SHA-1"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout", lambda e: e.update({"sourceSha1": "xyz"}))
            self._expect_failure("sourceSha1")
        with self.subTest("available SHA-1 mismatching bytes"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout", lambda e: e.update({"sourceSha1": "0" * 40}))
            self._expect_failure("sourceSha1")

    # -- pending-only ------------------------------------------------------------

    def test_pending_only(self):
        with self.subTest("reviewed status"):
            self._fresh()
            self._mutate_entry(
                "tout", lambda e: e["review"].update({"status": "reviewed"}))
            self._expect_failure("review.status")
        with self.subTest("invented reviewer"):
            self._fresh()
            self._mutate_entry(
                "tout", lambda e: e["review"].update({"reviewer": "Alice"}))
            self._expect_failure("reviewer")
        with self.subTest("invented reviewedAt"):
            self._fresh()
            self._mutate_entry(
                "tout",
                lambda e: e["review"].update(
                    {"reviewedAt": "2026-01-01T00:00:00Z"}))
            self._expect_failure("reviewedAt")
        with self.subTest("invented evidence"):
            self._fresh()
            self._mutate_entry(
                "tout",
                lambda e: e["review"].update({"evidence": ["approved"]}))
            self._expect_failure("evidence")
        with self.subTest("speaker qualification claim"):
            self._fresh()
            self._mutate_entry(
                "tout",
                lambda e: e["speaker"].update(
                    {"qualificationStatus": "verified"}))
            self._expect_failure("qualificationStatus")
        with self.subTest("accent claim"):
            self._fresh()
            self._mutate_entry(
                "tout", lambda e: e["speaker"].update({"accent": "parisien"}))
            self._expect_failure("accent")
        with self.subTest("nonempty changes"):
            self._fresh()
            self._mutate_entry(
                "tout", lambda e: e.update({"changes": ["renormalized"]}))
            self._expect_failure("changes")
        with self.subTest("wrong origin path"):
            self._fresh()
            self._mutate_entry(
                "tout",
                lambda e: e["mapping"]["origin"].update(
                    {"path": "frontend/lib/src/other/dart"}))
            self._expect_failure("origin.path")
        with self.subTest("wrong origin symbol"):
            self._fresh()
            self._mutate_entry(
                "tout",
                lambda e: e["mapping"]["origin"].update(
                    {"symbol": "frenchSentences"}))
            self._expect_failure("origin.symbol")
        with self.subTest("wrong origin status"):
            self._fresh()
            self._mutate_entry(
                "tout",
                lambda e: e["mapping"]["origin"].update(
                    {"status": "whatever"}))
            self._expect_failure("origin.status")
        with self.subTest("revision syntax"):
            self._fresh()
            self._mutate_entry(
                "tout",
                lambda e: e["mapping"]["origin"].update(
                    {"revision": "82ee5fd"}))
            self._expect_failure("origin.revision")
        with self.subTest("wrong speaker name"):
            self._fresh()
            self._mutate_entry(
                "tout", lambda e: e["speaker"].update({"sourceName": "Nobody"}))
            self._expect_failure("sourceName")

    # -- I6: provenance identity and one-to-one linkage ---------------------

    def test_provenance_identity_failures(self):
        with self.subTest("coordinated duplicate provenance IDs"):
            self._fresh()
            manifest = self._json("manifest.json")
            entry0 = self._entry(manifest["entries"], "tout")
            entry1 = self._entry(manifest["entries"], "rouge")
            entry1["provenanceId"] = entry0["provenanceId"]
            self._write_json("manifest.json", manifest)
            self._mutate_provenance_entry(
                "rouge", lambda e: e.update({"id": entry0["provenanceId"]}))
            self._expect_failure("prov-tout", "duplicat")
        with self.subTest("duplicate manifest provenance references"):
            self._fresh()
            self._mutate_entry(
                "rouge", lambda e: e.update({"provenanceId": "prov-tout"}))
            self._expect_failure("prov-tout", "duplicat")

    def test_metadata_file_path_failures(self):
        with self.subTest("symlinked manifest with identical content"):
            self._fresh()
            manifest = self._asset() / "manifest.json"
            external = self.root / "manifest-external.json"
            external.write_bytes(manifest.read_bytes())
            self._replace_with_symlink(manifest, external)
            self._expect_failure("symlink")
        with self.subTest("symlinked provenance with identical content"):
            self._fresh()
            provenance = self._asset() / "provenance.json"
            external = self.root / "provenance-external.json"
            external.write_bytes(provenance.read_bytes())
            self._replace_with_symlink(provenance, external)
            self._expect_failure("symlink")
        with self.subTest("symlinked package parent directory"):
            self._fresh()
            package = self._asset()
            real = self._asset().parent / "fr-real"
            package.rename(real)
            package.symlink_to(real)
            self._expect_failure("symlink")

    # -- N1: the 24 documented selected revision links -------------------------

    def test_selected_revision_links_pass(self):
        # Offline positive control: every selected description-revision link
        # from docs/superpowers/research/2026-10-12-french-reference-audio-sources.md
        # (lines 102-125) must validate verbatim — the real /w/index.php
        # route, the recorded oldids, the parenthesized filenames, and the
        # percent-encoded UTF-8 identity for `île`.  No network is used.
        self.assertEqual(set(SELECTED_REVISIONS), set(WORDS))
        self.assertEqual(len(SELECTED_REVISIONS), 24)
        self.assertIn("%C3%AEle", SELECTED_REVISIONS["île"][1])
        self.assertTrue(
            SELECTED_REVISIONS["tout"][1].startswith(
                "https://commons.wikimedia.org/w/index.php?title=File:"
                "LL-Q150_(fra)-LoquaxFR-tout.wav&oldid=995917835"))
        for word in WORDS:
            with self.subTest(word=word):
                self._fresh()
                entry = self._entry(
                    self._json("provenance.json")["entries"], word)
                oldid, link = SELECTED_REVISIONS[word]
                self.assertEqual(entry["descriptionRevisionId"], oldid)
                self.assertEqual(entry["descriptionRevisionUrl"], link)
                self.assertEqual(
                    entry["sourceTitle"],
                    f"File:LL-Q150_(fra)-LoquaxFR-{word}.wav")
                self.assertEqual(
                    verify_french_audio.verify_package(self.root), [],
                    msg="the documented selected revision link must be "
                        "accepted for this word")

    # -- I8: original-media route and complete source-filename identity -------

    def test_original_media_failures(self):
        with self.subTest("valid selected tout and île original-media URLs"):
            for word, literal in CANONICAL_ORIGINALS.items():
                with self.subTest(word=word):
                    self._fresh()
                    self.assertEqual(
                        _canonical_media_url(word), literal,
                        msg="helper must reproduce the independently "
                            "observed canonical original for this word")
                    entry = self._entry(
                        self._json("provenance.json")["entries"], word)
                    self.assertEqual(
                        entry["originalDownloadUrl"], literal,
                        msg="fixture must carry the independently observed "
                            "canonical original URL for this word")
                    self.assertEqual(
                        verify_french_audio.verify_package(self.root), [],
                        msg=f"the canonical selected original must be "
                            f"accepted for {word!r}")
        with self.subTest("File:-prefixed media basename is not the original"):
            for word, literal in CANONICAL_ORIGINALS.items():
                with self.subTest(word=word):
                    self._fresh()
                    prefix, base = literal.rsplit("/", 1)
                    prefixed = prefix + "/File%3A" + base
                    self.assertNotEqual(prefixed, literal)
                    self._mutate_provenance_entry(
                        word,
                        lambda e: e.update(
                            {"originalDownloadUrl": prefixed}))
                    self._expect_failure("originalDownloadUrl", "File:")
        with self.subTest("wrong original route, correct full source filename"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e.update({
                    "originalDownloadUrl":
                        "https://upload.wikimedia.org/not-original/"
                        "LL-Q150_%28fra%29-LoquaxFR-tout.wav"}))
            self._expect_failure(
                "originalDownloadUrl", "wikipedia/commons")
        with self.subTest("recognized route, other speaker's full filename"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e.update({
                    "originalDownloadUrl":
                        "https://upload.wikimedia.org/wikipedia/commons/a/ab/"
                        "OtherSpeaker-tout.wav"}))
            self._expect_failure(
                "originalDownloadUrl",
                "LL-Q150_(fra)-LoquaxFR-tout.wav")
        with self.subTest("recognized route, transcoded derivative name"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e.update({
                    "originalDownloadUrl":
                        "https://upload.wikimedia.org/wikipedia/commons/a/ab/"
                        "transcoded/LoquaxFR-tout.ogg"}))
            self._expect_failure("originalDownloadUrl")
        with self.subTest("same word embedded in a different full title"):
            self._fresh()
            def different_full_name(entry):
                fake = "File:LL-Q150_(fra)-LoquaxFR-toutt.wav"
                entry["sourceTitle"] = fake
                entry["sourcePageUrl"] = (
                    "https://commons.wikimedia.org/wiki/" + quote(fake, safe=""))
            self._mutate_provenance_entry("tout", different_full_name)
            self._expect_failure("sourceTitle", "LoquaxFR-tout.wav")

    def test_source_link_failures(self):
        with self.subTest("same-word JPEG title"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e.update({"sourceTitle": "File:tout.jpg"}))
            self._expect_failure("sourceTitle")
        with self.subTest("unrelated title containing the word"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e.update({"sourceTitle": "File:tout-rouge.wav"}))
            self._expect_failure("sourceTitle")
        with self.subTest("unrelated page title in page URL"):
            self._fresh()
            self._mutate_provenance_entry(
                "tout",
                lambda e: e.update(
                    {"sourcePageUrl":
                        "https://commons.wikimedia.org/wiki/File:Unrelated.wav"}))
            self._expect_failure("sourcePageUrl")
        with self.subTest("unrecognized revision endpoint"):
            self._fresh()
            def bad_endpoint(entry):
                entry["descriptionRevisionUrl"] = (
                    "https://commons.wikimedia.org/not-a-revision?"
                    + urlencode({"title": entry["sourceTitle"],
                                "oldid": entry["descriptionRevisionId"]}))
            self._mutate_provenance_entry("tout", bad_endpoint)
            self._expect_failure("descriptionRevisionUrl")
        with self.subTest("coordinated unrelated page, endpoint and media"):
            self._fresh()
            def coordinated(entry):
                entry["sourcePageUrl"] = (
                    "https://commons.wikimedia.org/wiki/File:Unrelated.wav")
                entry["descriptionRevisionUrl"] = (
                    "https://commons.wikimedia.org/not-a-revision?"
                    + urlencode({"title": "File:Unrelated.wav",
                                 "oldid": entry["descriptionRevisionId"]}))
                entry["originalDownloadUrl"] = (
                    "https://upload.wikimedia.org/wikipedia/commons/"
                    "ab/cd/not-original/tout.jpg")
            self._mutate_provenance_entry("tout", coordinated)
            self._expect_failure(
                "sourcePageUrl", "descriptionRevisionUrl",
                "originalDownloadUrl")

    def _wav_odd_terminal_data(self, padded: bool) -> bytes:
        """Coherent RIFF/WAVE whose final data chunk is odd (8-bit, 1 frame)."""
        payload = b"\x41"  # one 8-bit sample; unmistakable test byte
        fmt = struct.pack("<HHIIHH", 1, 1, 8000, 8000, 1, 8)
        body = (b"fmt " + struct.pack("<I", len(fmt)) + fmt) + \
            (b"data" + struct.pack("<I", len(payload)) + payload)
        if padded:
            body += b"\x00"  # required terminal pad byte, inside RIFF bounds
        return b"RIFF" + struct.pack("<I", len(body) + 4) + b"WAVE" + body

    def test_riff_padding_failures(self):
        with self.subTest("missing terminal padding after odd data chunk"):
            self._fresh()
            path = self.root / "odd-terminal.wav"
            path.write_bytes(self._wav_odd_terminal_data(padded=False))
            with self.assertRaises(ValueError):
                verify_french_audio.measure_wav(path)
        with self.subTest("padded odd terminal data chunk is valid"):
            self._fresh()
            path = self.root / "odd-terminal-padded.wav"
            path.write_bytes(self._wav_odd_terminal_data(padded=True))
            audio = verify_french_audio.measure_wav(path)
            self.assertEqual(
                audio,
                {"container": "wav", "encoding": "pcm", "sampleRateHz": 8000,
                 "channels": 1, "bitsPerSample": 8, "frameCount": 1,
                 "durationSeconds": 0.000125})

    def test_duration_tolerance(self):
        with self.subTest("inside one microsecond is accepted"):
            self._fresh()
            self._mutate_entry(
                "tout",
                lambda e: e["audio"].update({"durationSeconds": 0.0100005}))
            self.assertEqual(
                verify_french_audio.verify_package(self.root), [])
        with self.subTest("outside one microsecond is rejected"):
            self._fresh()
            self._mutate_entry(
                "tout",
                lambda e: e["audio"].update({"durationSeconds": 0.0100011}))
            self._expect_failure("durationSeconds")

    # -- CLI read-only failure -----------------------------------------------------

    def test_cli_failure_is_read_only(self):
        self._fresh()
        (self._asset() / "words" / "tout.wav").unlink()
        before = self._tree_snapshot()
        output, errors = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
            status = verify_french_audio.main(["--repo-root", str(self.root)])
        self.assertEqual(status, 1)
        self.assertIn("ERROR:", errors.getvalue())
        self.assertIn("words/tout.wav", errors.getvalue())
        self.assertNotIn("Traceback", errors.getvalue())
        self.assertEqual(self._tree_snapshot(), before)

    # -- invalid WAV inputs -----------------------------------------------------

    def test_measure_wav_rejects_invalid_input(self):
        for name, data in {
            "empty": b"",
            "garbage": b"definitely not a riff container file",
            "truncated": _pcm_wav_bytes()[:60],
            "missing data chunk": (
                b"RIFF" + struct.pack("<I", 4 + 8 + 16) + b"WAVE"
                + b"fmt " + struct.pack("<I", 16)
                + struct.pack("<HHIIHH", 1, 1, 8000, 16000, 2, 16)
            ),
            "zero frames": (
                b"RIFF" + struct.pack("<I", 4 + 8 + 16 + 8) + b"WAVE"
                + b"fmt " + struct.pack("<I", 16)
                + struct.pack("<HHIIHH", 1, 1, 8000, 16000, 2, 16)
                + b"data" + struct.pack("<I", 0)
            ),
            "unsupported float": (
                b"RIFF" + struct.pack("<I", 4 + 8 + 16 + 8 + 80) + b"WAVE"
                + b"fmt " + struct.pack("<I", 16)
                + struct.pack("<HHIIHH", 3, 1, 8000, 32000, 4, 32)
                + b"data" + struct.pack("<I", 80) + b"\x00" * 80
            ),
            "data chunk before fmt chunk": _wav_data_before_fmt(),
        }.items():
            with self.subTest(name=name):
                path = self.root / f"invalid-{name}.wav"
                path.write_bytes(data)
                with self.assertRaises(ValueError):
                    verify_french_audio.measure_wav(path)

    # -- legitimate extra RIFF chunk + padding ----------------------------------

    def test_pcm_with_metadata_and_padding(self):
        self._fresh()
        metadata = b"LIST" + struct.pack("<I", 5) + b"XXXXX"  # odd-sized chunk
        wav = _pcm_wav_bytes(extra_metadata=metadata)
        path = self._asset() / "words" / "tout.wav"
        path.write_bytes(wav)
        sha256 = hashlib.sha256(wav).hexdigest()
        sha1 = hashlib.sha1(wav, usedforsecurity=False).hexdigest()
        self._mutate_entry(
            "tout",
            lambda e: e.update({"sha256": sha256, "byteLength": len(wav)}))
        self._mutate_provenance_entry(
            "tout",
            lambda e: e.update({"sha256": sha256, "sourceSha1": sha1}))
        audio = verify_french_audio.measure_wav(path)
        self.assertEqual(audio["frameCount"], 80)
        self.assertEqual(audio["durationSeconds"], 0.01)
        self.assertEqual(verify_french_audio.verify_package(self.root), [])


# ---------------------------------------------------------------------------
# Approved FR-02 recovery amendment (2026-10-13): bounded byte-level
# acceptance.  Two new acceptance rules, pinned to explicit immutable
# literals copied from the amended spec and the recovery brief (NOT derived
# from the implementation, and NOT learned from package metadata):
#
#   1. the exact four-byte RIFF-size underdeclaration in the 24 selected,
#      SHA-256-pinned binaries (23 current originals + the 2020 `mur`
#      original; the 2026 `mur` replacement is excluded);
#   2. the single approved historical `mur` archive association (archive URL
#      + revision 384728988 + sourceSHA1 + fullSHA256 + the original
#      2020-01-01T18:47:44Z timestamp), everything else rejected.
# ---------------------------------------------------------------------------

# Measured SHA-256 -> (word, byteLength), exactly as the recovery brief's
# table of approved pins (recomputed from inspected staged bytes).
APPROVED_RIFF_PINS = {
    "ec761ca7114be7bb7178f380ff4e937763bbf934b0bd44d7366973394d61dec4": ("tout", 66836),
    "c4540087629c8034a58b7b4f6ca5354234c1dd492a5a8d74e0dc8bff6bf2bd40": ("rouge", 88364),
    "9027202be18f5a94dc116e887ace62385692cbbb3493a67da371427cb35d3cf4": ("vous", 41324),
    "bf45923e17129f3d05c446062962e378840aa7e254fc908c21fdcd037b615b09": ("doux", 36972),
    "62c67dece782ef8a4be248e10b5537db8fa51e9fc8c378a1c6784eb8d58b012e": ("loup", 63788),
    "9d850d99b78dd1c521e0512b9be8df85f798702ed8bda6bef3ea0417607ed495": ("soupe", 69420),
    "98f6aca710d17bc74b114e81b60b7d3e8ec8504b6073dbbe441af8df3a29020c": ("tu", 66836),
    "be717dc3763ff96ad35852799bf77269740c2c851ac1daf696eaefbfd28ed20d": ("rue", 77554),
    "9a7ef667189672b5ba2acb11dcb3b98449b958c0a535c85799309a225970e437": ("lune", 85746),
    "27737f36cb89b05b59431bbf54426881e8f8e1cf786e54c551743cf9ed7a53df": ("jus", 75028),
    "c37f34379cce3c5245f1fe951d179f0f39c49fdf679f1cf83e4fd02e5f6a44ad": ("mur", 77554),
    "767018eff1b9ec0e48546d71865e99d9d70670e94a5440d8314d16884aad1208": ("plume", 60524),
    "41698332638a8540c2790a03dbbbfea871469a0d44b1dbe08825225fc918ab59": ("lit", 67884),
    "d9c5aff5fb44aed16963c68d1c7ebe49450c9e08c422f6affac76ca4c7870d7e": ("si", 75028),
    "5ae742cf467e17d6a5d183b1dd4b0b5a468df7e841b04486d9fe31de92216816": ("vite", 42092),
    "a7fed2bb2440a9980111cfe5c739e0abf722fc91b8de35be936d271f46f7f15a": ("île", 69362),
    "689c67d84da86eb932fed8e82c690951c44eda2c854962a943818b10a6cd2e21": ("beau", 57196),
    "a478bb690e724b5bd98dbc9bbea80270231f78ebad08b523b11daddc02b36398": ("mot", 77554),
    "7dfa03f4114a25322a881915a99ea2f0695727b045358e76396cba6373595f27": ("eau", 59948),
    "e50683ee0d1de5e1c78cae14d9d7c7a8e61961ec2a2996a73a172c6df58e2d4c": ("dos", 75028),
    "1f369b90c51e1696371ac3b9e59af96986b4e0bef4a531c19723c7c682d86aff": ("bon", 54892),
    "a24dad922927a67621cc6a7feeeae6d0b047b2447e32922fd8e609a3d3ef60b1": ("nom", 55596),
    "cac71e6ba32e78358fab63b5ee28d3ec467816395c1550aa8bf2117caf62d74f": ("banc", 48748),
    "a053ac40269632413fd4d3fc288dc988febe07b06c137d9d848b889e1e795c24": ("sans", 69932),
}
# The 2026 `mur` replacement original (the excluded one) carries a different
# hash; equality of the whole set is what proves it holds no exception.

MUR_ARCHIVE = {
    # Archived original media URL (the `!` archive separator stays
    # percent-encoded in the canonical spelling).
    "url": ("https://upload.wikimedia.org/wikipedia/commons/archive/7/79/"
            "20261007075226%21LL-Q150_%28fra%29-LoquaxFR-mur.wav"),
    "revisionId": 384728988,
    "revisionUrl": ("https://commons.wikimedia.org/w/index.php?"
                    "title=File:LL-Q150_(fra)-LoquaxFR-mur.wav&oldid=384728988"),
    "sourceSha1": "14d1b1ee2a64653d1960c72c80dfe5ed621ff0b2",
    "sha256": "c37f34379cce3c5245f1fe951d179f0f39c49fdf679f1cf83e4fd02e5f6a44ad",
    # The original recording timestamp — the archive-name prefix is the
    # replacement event, NOT a timestamp.
    "mediaTimestamp": "2020-01-01T18:47:44Z",
    "sourceTitle": "File:LL-Q150_(fra)-LoquaxFR-mur.wav",
}


class RiffAbbreviationRecoveryTests(FixtureBase):
    """The approved four-byte RIFF-size exception, pinned by measured hash.

    The synthetic fixtures here are unmistakable test PCM; the module's
    allowlist is test-only overridden with the fixture's own measured
    SHA-256/byteLength to exercise the parser branch.  Real-byte acceptance
    is evidenced separately by the manual staged-file integration probe.
    """

    def _abbrev_wav(self, frames=80, size_delta=-4, tail=b"") -> bytes:
        """Fixture PCM WAV; `size_delta` offsets the RIFF size field from the
        normal fileLength-8 (the approved defect is exactly -4)."""
        payload = b"\x01\x02" * frames
        fmt = struct.pack("<HHIIHH", 1, 1, 8000, 16000, 2, 16)
        body = (b"fmt " + struct.pack("<I", len(fmt)) + fmt) + \
            (b"data" + struct.pack("<I", len(payload)) + payload) + tail
        return b"RIFF" + struct.pack("<I", len(body) + 4 + size_delta) + \
            b"WAVE" + body

    def _pin(self, data: bytes, word: str) -> None:
        """Test-only override: pin the exception to the fixture's own bytes."""
        patcher = mock.patch.object(
            verify_french_audio, "RIFF_ABBREV_SIZE_ALLOWLIST",
            {hashlib.sha256(data).hexdigest(): (word, len(data))})
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_allowlist_pins_match_approved_table(self):
        # The 24 literal pins, copied from the recovery brief's requirement
        # table, are the sole authority — equality of the whole set also
        # proves the 2026 `mur` replacement (any other hash) is excluded.
        self.assertEqual(
            verify_french_audio.RIFF_ABBREV_SIZE_ALLOWLIST,
            dict(APPROVED_RIFF_PINS),
            "the allowlist must be exactly the 24 approved pins, nothing more")
        self.assertEqual(len(verify_french_audio.RIFF_ABBREV_SIZE_ALLOWLIST), 24)
        self.assertEqual(
            verify_french_audio.RIFF_ABBREV_SIZE_ALLOWLIST[
                "c37f34379cce3c5245f1fe951d179f0f39c49fdf679f1cf83e4fd02e5f6a44ad"],
            ("mur", 77554),
            "the mur pin must be the approved 2020 original")

    def test_measured_pins_cover_all_words(self):
        self.assertEqual(
            sorted(pin[0] for pin in
                   verify_french_audio.RIFF_ABBREV_SIZE_ALLOWLIST.values()),
            sorted(WORDS),
            "each of the 24 words maps to exactly one pinned hash")

    def test_approved_defect_measures_full_physical_frames(self):
        # stdlib would read 78 frames (four PCM bytes short); the verifier
        # must measure all 80 physical frames without touching the bytes.
        data = self._abbrev_wav(frames=80)
        self._pin(data, "tout")
        wav = self._asset() / "words" / "tout.wav"
        wav.write_bytes(data)
        self._mutate_entry(
            "tout",
            lambda e: e.update(
                {"sha256": hashlib.sha256(data).hexdigest(),
                 "byteLength": len(data)}))
        self._mutate_provenance_entry(
            "tout",
            lambda e: e.update(
                {"sha256": hashlib.sha256(data).hexdigest(),
                 "sourceSha1": hashlib.sha1(data, usedforsecurity=False).hexdigest()}))
        before = wav.read_bytes()
        audio = verify_french_audio.measure_wav(wav)
        self.assertEqual(audio, {
            "container": "wav", "encoding": "pcm", "sampleRateHz": 8000,
            "channels": 1, "bitsPerSample": 16, "frameCount": 80,
            "durationSeconds": 0.01,
        }, "measurement must cover the full physical data chunk")
        # Disclosure check (version-dependent, not the acceptance rule): the
        # stdlib sample reader may see all 160 bytes or the approved
        # four-byte omission (156), but never more; the authoritative frame
        # count above is the full physical one either way.
        with wave.open(io.BytesIO(data), "rb") as handle:
            read_len = len(handle.readframes(handle.getnframes()))
        self.assertIn(read_len, (156, 160),
                      "stdlib must read no more than the declared data")
        self.assertEqual(
            verify_french_audio.verify_package(self.root), [],
            "the approved, pinned defect must pass verification")
        self.assertEqual(
            wav.read_bytes(), before, "verification must not rewrite the file")

    def test_unapproved_same_defect_rejected(self):
        # Identical four-byte defect, different (unpinned) bytes: no blessing.
        approved = self._abbrev_wav(frames=80)
        other = self._abbrev_wav(frames=64)
        self.assertNotEqual(
            hashlib.sha256(approved).hexdigest(),
            hashlib.sha256(other).hexdigest())
        self._pin(approved, "tout")
        wav = self._asset() / "words" / "tout.wav"
        wav.write_bytes(other)
        with self.assertRaisesRegex(ValueError, r"RIFF size"):
            verify_french_audio.measure_wav(wav)
        self._expect_failure("RIFF size", "does not cover the whole file")

    def test_wrong_offset_defect_not_blessed(self):
        # A two-byte underdeclaration (fileLength-10) must be rejected even
        # though its own hash is pinned: only the exact fileLength-12 field.
        data = self._abbrev_wav(frames=80, size_delta=-2)
        self._pin(data, "tout")
        wav = self._asset() / "words" / "tout.wav"
        wav.write_bytes(data)
        with self.assertRaisesRegex(ValueError, r"RIFF size"):
            verify_french_audio.measure_wav(wav)

    def test_data_not_final_chunk_not_blessed(self):
        # The exception requires ONE complete data chunk reaching EOF; a
        # trailing LIST chunk is not that layout and must not be blessed.
        tail = b"LIST" + struct.pack("<I", 8) + b"ABCDABCD"
        data = self._abbrev_wav(frames=80, size_delta=-4, tail=tail)
        self._pin(data, "tout")
        wav = self._asset() / "words" / "tout.wav"
        wav.write_bytes(data)
        with self.assertRaisesRegex(
                ValueError, "single complete data chunk"):
            verify_french_audio.measure_wav(wav)

    def test_trailing_extra_bytes_not_blessed(self):
        # Eight stray bytes beyond the declared container: reject even when
        # the hash-pinned table is overridden for these exact bytes.
        data = self._abbrev_wav(frames=80, size_delta=0) + b"\x00" * 8
        self._pin(data, "tout")
        wav = self._asset() / "words" / "tout.wav"
        wav.write_bytes(data)
        with self.assertRaisesRegex(ValueError, r"RIFF size"):
            verify_french_audio.measure_wav(wav)

    def test_wrong_word_pin_rejected(self):
        # The pin belongs to `tout`; listing those exact bytes under `rouge`
        # is a word-identity mismatch the verifier must name.
        data = self._abbrev_wav(frames=80)
        self._pin(data, "tout")
        self._fresh()
        (self._asset() / "words" / "rouge.wav").write_bytes(data)
        self._mutate_entry(
            "rouge",
            lambda e: e.update(
                {"sha256": hashlib.sha256(data).hexdigest(),
                 "byteLength": len(data)}))
        self._expect_failure(
            "approved RIFF size exception binary", "'tout'", "'rouge'")


class MurArchiveAssociationTests(FixtureBase):
    """The single approved historical `mur` archive association."""

    def _apply_correct_association(self) -> None:
        manifest = self._json("manifest.json")
        m_entry = self._entry(manifest["entries"], "mur")
        m_entry["sha256"] = MUR_ARCHIVE["sha256"]
        self._write_json("manifest.json", manifest)

        def pair(prov):
            prov["originalDownloadUrl"] = MUR_ARCHIVE["url"]
            prov["descriptionRevisionId"] = MUR_ARCHIVE["revisionId"]
            prov["descriptionRevisionUrl"] = MUR_ARCHIVE["revisionUrl"]
            prov["sourceSha1"] = MUR_ARCHIVE["sourceSha1"]
            prov["mediaTimestamp"] = MUR_ARCHIVE["mediaTimestamp"]
            prov["sha256"] = MUR_ARCHIVE["sha256"]
        self._mutate_provenance_entry("mur", pair)

    def test_approved_mur_archive_literals(self):
        self.assertEqual(
            verify_french_audio.MUR_ARCHIVE_MEDIA_URL, MUR_ARCHIVE["url"])
        self.assertEqual(
            verify_french_audio.MUR_ARCHIVE_MEDIA_PATH,
            "/wikipedia/commons/archive/7/79/"
            "20261007075226!LL-Q150_(fra)-LoquaxFR-mur.wav")
        self.assertEqual(
            verify_french_audio.MUR_ARCHIVE_REVISION_ID,
            MUR_ARCHIVE["revisionId"])
        self.assertEqual(
            verify_french_audio.MUR_ARCHIVE_SHA1, MUR_ARCHIVE["sourceSha1"])
        self.assertEqual(
            verify_french_audio.MUR_ARCHIVE_SHA256, MUR_ARCHIVE["sha256"])
        self.assertEqual(
            verify_french_audio.MUR_ARCHIVE_MEDIA_TIMESTAMP,
            MUR_ARCHIVE["mediaTimestamp"])

    def test_correct_association_accepted(self):
        self._apply_correct_association()
        prov = self._entry(
            self._json("provenance.json")["entries"], "mur")
        manifest_entry = self._entry(
            self._json("manifest.json")["entries"], "mur")
        diagnostics: list[str] = []
        verify_french_audio._check_mur_archive_association(
            prov, manifest_entry, "provenance.json entries[mur]", diagnostics)
        self.assertEqual(diagnostics, [])

    def test_single_field_breaks_rejected(self):
        self._apply_correct_association()
        prov = self._entry(
            self._json("provenance.json")["entries"], "mur")
        manifest_entry = self._entry(
            self._json("manifest.json")["entries"], "mur")
        cases = [
            ("wrong revision",
             {"descriptionRevisionId": 1284027183}, None,
             ("descriptionRevisionId", "384728988")),
            ("null revision",
             {"descriptionRevisionId": None}, None,
             ("descriptionRevisionId", "384728988")),
            ("wrong sha1",
             {"sourceSha1": "0" * 40}, None,
             ("sourceSha1", MUR_ARCHIVE["sourceSha1"][0:16])),
            ("missing sha1",
             {"sourceSha1": None}, None,
             ("sourceSha1", MUR_ARCHIVE["sourceSha1"][0:16])),
            ("wrong prov sha256",
             {"sha256": "f" * 64}, None,
             ("sha256", MUR_ARCHIVE["sha256"][0:16])),
            ("wrong manifest sha256",
             None, {"sha256": "f" * 64},
             ("sha256", MUR_ARCHIVE["sha256"][0:16])),
            ("wrong timestamp",
             {"mediaTimestamp": "2026-01-15T09:30:00Z"}, None,
             ("mediaTimestamp", "2020-01-01T18:47:44Z")),
            ("timestamp swapped for the archive prefix date",
             {"mediaTimestamp": "2026-10-07T07:52:26Z"}, None,
             ("mediaTimestamp", "2020-01-01T18:47:44Z")),
        ]
        for name, prov_patch, manifest_patch, tokens in cases:
            with self.subTest(name=name):
                broken = copy.deepcopy(prov)
                if prov_patch is not None:
                    broken.update(prov_patch)
                broken_manifest = copy.deepcopy(manifest_entry)
                if manifest_patch is not None:
                    broken_manifest.update(manifest_patch)
                diagnostics = []
                verify_french_audio._check_mur_archive_association(
                    broken, broken_manifest, "provenance.json entries[mur]",
                    diagnostics)
                self.assertTrue(diagnostics)
                joined = "\n".join(diagnostics)
                for token in tokens:
                    self.assertIn(token, joined)

    def test_correct_association_not_route_rejected(self):
        # Through the full verifier: the archive URL must be accepted for
        # `mur` in the paired state.  The synthetic fixture bytes still fail
        # the hash/byteLength measurements (expected — the fixture is not the
        # real binary), but no association-pairing diagnostic may appear.
        self._apply_correct_association()
        diagnostics = verify_french_audio.verify_package(self.root)
        self.assertTrue(
            diagnostics, "the synthetic fixture must still fail byte checks")
        joined = "\n".join(diagnostics)
        self.assertNotIn("mur archive association", joined)
        self.assertNotIn("originalDownloadUrl", joined)
        self.assertNotIn("2020-01-01T18:47:44Z", joined)

    def test_wrong_word_association_rejected(self):
        self._mutate_provenance_entry(
            "tout",
            lambda e: e.update({"originalDownloadUrl": MUR_ARCHIVE["url"]}))
        self._expect_failure("originalDownloadUrl")

    def test_wrong_prefix_rejected(self):
        wrong = MUR_ARCHIVE["url"].replace(
            "20261007075226%21", "20200101000000%21")
        self.assertNotEqual(wrong, MUR_ARCHIVE["url"])
        self._mutate_provenance_entry(
            "mur", lambda e: e.update({"originalDownloadUrl": wrong}))
        self._expect_failure("originalDownloadUrl")

    def test_wrong_title_rejected(self):
        wrong = MUR_ARCHIVE["url"].replace(
            "LoquaxFR-mur.wav", "LoquaxFR-sans.wav")
        self._mutate_provenance_entry(
            "mur", lambda e: e.update({"originalDownloadUrl": wrong}))
        self._expect_failure("originalDownloadUrl")

    def test_wrong_revision_link_rejected(self):
        self._apply_correct_association()
        revision_id, revision_url = SELECTED_REVISIONS["mur"]  # 2026 rev
        self.assertEqual(revision_id, 1284027183)
        self._mutate_provenance_entry(
            "mur",
            lambda e: e.update(
                {"descriptionRevisionId": revision_id,
                 "descriptionRevisionUrl": revision_url}))
        self._expect_failure(
            "descriptionRevisionId", "384728988")

    def test_wrong_timestamp_rejected(self):
        self._apply_correct_association()
        self._mutate_provenance_entry(
            "mur",
            lambda e: e.update(
                {"mediaTimestamp": "2026-01-15T09:30:00Z"}))
        self._expect_failure("mediaTimestamp", "2020-01-01T18:47:44Z")

    def test_wrong_sha1_rejected(self):
        self._apply_correct_association()
        self._mutate_provenance_entry(
            "mur", lambda e: e.update({"sourceSha1": "0" * 40}))
        self._expect_failure(
            "sourceSha1", MUR_ARCHIVE["sourceSha1"])

    def test_wrong_sha256_rejected(self):
        self._apply_correct_association()
        manifest = self._json("manifest.json")
        self._entry(manifest["entries"], "mur")["sha256"] = "f" * 64
        self._write_json("manifest.json", manifest)
        self._mutate_provenance_entry(
            "mur", lambda e: e.update({"sha256": "f" * 64}))
        self._expect_failure("sha256", MUR_ARCHIVE["sha256"])

    def test_selected_revision_requires_archive_url(self):
        # The 2020 original upload revision cannot be paired with the current
        # redirect (which now serves the replacement binary).
        self._mutate_provenance_entry(
            "mur",
            lambda e: e.update(
                {"descriptionRevisionId": MUR_ARCHIVE["revisionId"],
                 "descriptionRevisionUrl": MUR_ARCHIVE["revisionUrl"]}))
        self.assertEqual(
            self._entry(self._json("provenance.json")["entries"], "mur")[
                "originalDownloadUrl"],
            _canonical_media_url("mur"))
        self._expect_failure("originalDownloadUrl", "archive")


if __name__ == "__main__":
    unittest.main()
