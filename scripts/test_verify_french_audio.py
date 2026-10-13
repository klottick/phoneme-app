"""Focused tests for the offline French word-audio candidate verifier.

The fixture built here is unmistakable unit-test data: tiny synthetic 8 kHz
16-bit mono PCM WAVs, placeholder provenance URLs and licence texts. It is
not a human recording, and a passing verifier only proves the package is
internally consistent in a technical/metadata sense - it is not linguistic
sign-off or rights clearance.
"""

import contextlib
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
from pathlib import Path
from unittest import mock
from urllib.parse import urlencode

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
    for index, word in enumerate(WORDS):
        spdx, url, text_path = BY if word == "sans" else BY_SA
        title = f"File:LoquaFr-{word}.wav"
        revision_id = 1_000_000 + index
        credit_text = (
            f"« {word} » spoken by LoquaxFR (Lingua Libre), {spdx}, "
            f"via Wikimedia Commons (unmistakable test fixture)."
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
            "sourcePageUrl": f"https://commons.wikimedia.org/wiki/{title}",
            "sourceTitle": title,
            "descriptionRevisionId": revision_id,
            "descriptionRevisionUrl": (
                "https://commons.wikimedia.org/index.php?"
                + urlencode({"title": title, "oldid": revision_id})
            ),
            "retrievedAt": "2026-10-12T10:00:00Z",
            "originalDownloadUrl": (
                "https://upload.wikimedia.org/wikipedia/commons/ab/cd/"
                + urlencode({"path": title})
            ),
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


if __name__ == "__main__":
    unittest.main()
