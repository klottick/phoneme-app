import hashlib
import json
import unittest

from french_sentence_package import (
    SentencePackageError,
    annotation_hash,
    canonical_json,
    parse_fleurs_train_tsv,
    valid_sha256,
)


class FrenchSentencePackageTests(unittest.TestCase):
    def test_headerless_tsv_preserves_first_row_and_unicode(self):
        rows = parse_fleurs_train_tsv(
            '1\tbonjour.wav\tL’été — « oui »\tL’été — « oui »\tunused\t2\tfemale\n'
        )
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0], {
            "id": "1", "filename": "bonjour.wav",
            "raw_transcription": "L’été — « oui »",
            "transcription": "L’été — « oui »", "unused": "unused",
            "num_samples": "2", "gender": "female",
        })

    def test_tsv_preserves_unicode_separators_and_splits_only_record_terminators(self):
        content = "line\u2028para\u2029nel\x85vertical\x0bform\x0cfile\x1cgroup\x1drecord\x1e"
        first = f"1\ta.wav\traw\t{content}\tx\t1\tf"
        second = "2\tb.wav\traw\tsecond\tx\t1\tf"
        rows = parse_fleurs_train_tsv(first + "\r\n" + second + "\n")
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]["transcription"], content)
        self.assertEqual(rows[1]["transcription"], "second")
        with self.assertRaisesRegex(SentencePackageError, "line 3"):
            parse_fleurs_train_tsv(first + "\n" + second + "\r\npartial\trow")

    def test_tsv_identity_is_id_and_filename(self):
        rows = parse_fleurs_train_tsv(
            "7\ta.wav\traw a\ttext a\tx\t1\tf\n"
            "7\tb.wav\traw b\ttext b\ty\t2\tm\n"
        )
        self.assertEqual([row["filename"] for row in rows], ["a.wav", "b.wav"])
        with self.assertRaisesRegex(SentencePackageError, "duplicate"):
            parse_fleurs_train_tsv(
                "7\ta.wav\traw\ttext\tx\t1\tf\n"
                "7\ta.wav\traw\ttext\tx\t1\tf\n"
            )

    def test_tsv_rejects_malformed_or_unsafe_records(self):
        good = '1\ta.wav\traw\t"quoted\tunused\t1\tf\n'
        self.assertEqual(parse_fleurs_train_tsv(good)[0]["transcription"], '"quoted')
        bad_records = [
            "1\ta.wav\traw\ttext\tx\t1\n",
            "1\ta.wav\traw\ttext\tx\t1\tf\textra\n",
            "1\ta.wav\t\ttext\tx\t1\tf\n",
            "1\ta.wav\traw\t \t x\t1\tf\n",
            "١\ta.wav\traw\ttext\tx\t1\tf\n",
            "1\ta.wav\traw\ttext\tx\t0\tf\n",
            "id\tfilename\traw\ttext\tx\t1\tf\n",
            "1\t../a.wav\traw\ttext\tx\t1\tf\n",
            "1\t/a.wav\traw\ttext\tx\t1\tf\n",
            "1\ta.txt\traw\ttext\tx\t1\tf\n",
            "1\ta\x00.wav\traw\ttext\tx\t1\tf\n",
        ]
        for text in bad_records:
            with self.subTest(text=text), self.assertRaises(SentencePackageError):
                parse_fleurs_train_tsv(text)
        with self.assertRaisesRegex(SentencePackageError, "line 2"):
            parse_fleurs_train_tsv("\npartial\trow\n")
        self.assertEqual(parse_fleurs_train_tsv("\n\n"), [])

    def test_canonical_json_is_stable_unicode_and_strict(self):
        self.assertEqual(canonical_json({"é": [True, 1], "a": None}),
                         canonical_json({"a": None, "é": [True, 1]}))
        self.assertEqual(canonical_json({"x": "é"}), '{"x":"é"}')
        self.assertNotEqual(canonical_json([1, 2]), canonical_json([2, 1]))
        self.assertEqual(json.loads(canonical_json(True)), True)
        for value in (float("nan"), float("inf"), {1: "bad"}, {"x": object()}):
            with self.subTest(value=value), self.assertRaises(SentencePackageError):
                canonical_json(value)

    def test_annotation_hash_binds_exact_recording_specific_key(self):
        item = {
            "sentenceId": "fr-1", "audioRefId": "audio-a", "text": "Un été.",
            "annotationRevision": 2,
            "tokens": [
                {"id": "t1", "text": "Un", "phonemes": ["œ̃"]},
                {"id": "t2", "text": "été.", "phonemes": ["e", "t", "e"]},
            ],
            "expectedTokenIds": ["t1", "t2"],
            "review": {"reviewer": "Ada"}, "toolVersion": "v1", "updatedAt": "now",
        }
        projection = {
            "sentenceId": "fr-1", "audioRefId": "audio-a", "text": "Un été.",
            "annotationRevision": 2,
            "tokens": [
                {"id": "t1", "text": "Un", "phonemes": ["œ̃"]},
                {"id": "t2", "text": "été.", "phonemes": ["e", "t", "e"]},
            ],
            "expectedTokenIds": ["t1", "t2"],
        }
        expected = hashlib.sha256(
            json.dumps(projection, ensure_ascii=False, sort_keys=True,
                       separators=(",", ":"), allow_nan=False).encode("utf-8")
        ).hexdigest()
        self.assertEqual(annotation_hash(item), expected)
        for field, replacement in (
            ("sentenceId", "fr-2"), ("audioRefId", "audio-b"), ("text", "Un hiver."),
            ("annotationRevision", 3),
        ):
            changed = dict(item)
            changed[field] = replacement
            self.assertNotEqual(annotation_hash(changed), expected, field)
        for index in range(2):
            for field, replacement in (("id", "changed"), ("text", "changed"),
                                        ("phonemes", ["changed"])):
                changed = json.loads(json.dumps(item, ensure_ascii=False))
                changed["tokens"][index][field] = replacement
                if field == "id":
                    changed["expectedTokenIds"][index] = replacement
                self.assertNotEqual(annotation_hash(changed), expected, (index, field))
        changed = dict(item, expectedTokenIds=["t1"])
        self.assertNotEqual(annotation_hash(changed), expected)
        for extras in ({"review": {"reviewer": "Lin"}}, {"toolVersion": "v2"},
                       {"updatedAt": "later"}):
            self.assertEqual(annotation_hash(dict(item, **extras)), expected)
        for ids in (["unknown"], ["t1", "t1"], ["t2", "t1"]):
            with self.subTest(ids=ids), self.assertRaises(SentencePackageError):
                annotation_hash(dict(item, expectedTokenIds=ids))

    def test_annotation_projection_rejects_wrong_types(self):
        valid = {"sentenceId": "s", "audioRefId": "a", "text": "bonjour",
                 "annotationRevision": 1,
                 "tokens": [{"id": "t", "text": "bonjour", "phonemes": ["b"]}],
                 "expectedTokenIds": ["t"]}
        for field, value in (("annotationRevision", True), ("tokens", {}),
                             ("expectedTokenIds", "t"), ("text", " "),
                             ("sentenceId", 1), ("audioRefId", None)):
            changed = dict(valid, **{field: value})
            with self.subTest(field=field), self.assertRaises(SentencePackageError):
                annotation_hash(changed)
        for missing in valid:
            changed = dict(valid)
            del changed[missing]
            with self.subTest(missing=missing), self.assertRaises(SentencePackageError):
                annotation_hash(changed)
        for token in ({"id": "t", "text": "x"},
                      {"id": " ", "text": "x", "phonemes": []},
                      {"id": "t", "text": "x", "phonemes": [""]},
                      {"id": "t", "text": "x", "phonemes": "b"}):
            with self.subTest(token=token), self.assertRaises(SentencePackageError):
                annotation_hash(dict(valid, tokens=[token]))
        duplicate_tokens = [valid["tokens"][0], dict(valid["tokens"][0])]
        with self.assertRaises(SentencePackageError):
            annotation_hash(dict(valid, tokens=duplicate_tokens))

    def test_sha256_shape(self):
        self.assertTrue(valid_sha256("a" * 64))
        for value in ("a" * 63, "A" * 64, "g" * 64, None, 42, True):
            with self.subTest(value=value):
                self.assertFalse(valid_sha256(value))


if __name__ == "__main__":
    unittest.main()
