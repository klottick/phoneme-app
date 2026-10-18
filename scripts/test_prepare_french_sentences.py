import hashlib
import io
import json
import tarfile
import tempfile
import unittest
import wave
from pathlib import Path
from unittest import mock

import prepare_french_sentences as prep
from french_sentence_package import SentencePackageError


def make_wav(path, frames, channels=2, width=2, rate=16000):
    with wave.open(str(path), "wb") as out:
        out.setnchannels(channels)
        out.setsampwidth(width)
        out.setframerate(rate)
        out.writeframes(frames)


def archive_bytes(entries):
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w:gz") as archive:
        for name, data in entries:
            item = tarfile.TarInfo(name)
            item.size = len(data)
            archive.addfile(item, io.BytesIO(data))
    return output.getvalue()


class PreparationTests(unittest.TestCase):
    def test_archive_rejects_traversal_links_and_duplicate_members(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for entries, requested in [
                ([('../outside', b'x')], ['../outside']),
                ([('/absolute', b'x')], ['/absolute']),
                ([('chosen.wav', b'a'), ('chosen.wav', b'b')], ['chosen.wav']),
            ]:
                archive = root / 'source.tar'
                archive.write_bytes(archive_bytes(entries))
                output = root / 'new'
                with self.assertRaises(SentencePackageError):
                    prep.select_originals(archive, requested, output)
                self.assertFalse(output.exists())
                self.assertFalse((root / 'outside').exists())
            good = archive_bytes([('nested/chosen.wav', b'original')])
            archive = root / 'good.tar'
            archive.write_bytes(good)
            with mock.patch.object(prep, 'ARCHIVE_SIZE', len(good)), \
                 mock.patch.object(prep, 'ARCHIVE_SHA256', hashlib.sha256(good).hexdigest()):
                selected = prep.select_originals(archive, ['nested/chosen.wav'], root / 'selected')
            self.assertEqual((root / 'selected/nested/chosen.wav').read_bytes(), b'original')
            self.assertEqual(selected['nested/chosen.wav']['sha256'], hashlib.sha256(b'original').hexdigest())
            output = root / 'link.tar'
            with tarfile.open(output, 'w') as tar:
                link = tarfile.TarInfo('chosen.wav')
                link.type = tarfile.SYMTYPE
                link.linkname = '../outside'
                tar.addfile(link)
            with self.assertRaises(SentencePackageError):
                prep.select_originals(output, ['chosen.wav'], root / 'link-out')

    def test_source_fetch_is_pinned_streaming_and_transactional(self):
        tsv = b'1\tone.wav\tbonjour\tbonjour\tx\t2\tfemale\n'
        tar = archive_bytes([('one.wav', b'RIFF')])
        payloads = {prep.TSV_URL: tsv, prep.ARCHIVE_URL: tar}
        with tempfile.TemporaryDirectory() as temp:
            cache = Path(temp) / 'cache'
            with mock.patch.object(prep, '_fetch_to', side_effect=lambda url, path, *_: path.write_bytes(payloads[url])), \
                 mock.patch.object(prep, 'TSV_SIZE', len(tsv)), \
                 mock.patch.object(prep, 'TSV_SHA256', hashlib.sha256(tsv).hexdigest()), \
                 mock.patch.object(prep, 'ARCHIVE_SIZE', len(tar)), \
                 mock.patch.object(prep, 'ARCHIVE_SHA256', hashlib.sha256(tar).hexdigest()):
                result = prep.fetch_source(cache)
            self.assertEqual((cache / 'train.tsv').read_bytes(), tsv)
            self.assertEqual(result['train.tar.gz']['sha256'], hashlib.sha256(tar).hexdigest())
            with self.assertRaises(SentencePackageError):
                prep.fetch_source(cache)

    def test_crop_preserves_original_and_exact_pcm_slice(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, dest = root / 'source.wav', root / 'crop.wav'
            pcm = b'abcdefghijkl'
            make_wav(source, pcm)
            before = source.read_bytes()
            meta = prep.crop_pcm(source, dest, 1, 2)
            with wave.open(str(dest), 'rb') as cropped:
                self.assertEqual(cropped.readframes(9), pcm[4:8])
            self.assertEqual(meta['frameCount'], 1)
            self.assertEqual(source.read_bytes(), before)
            with self.assertRaises(SentencePackageError):
                prep.crop_pcm(source, root / 'bad.wav', True, 2)
            with self.assertRaises(SentencePackageError):
                prep.crop_pcm(source, dest, 0, 1)

    def test_draft_annotations_never_qualify_content(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            executable = root / 'fake-tool'
            executable.write_text('fake')
            def runner(argv, **kwargs):
                if '--version' in argv:
                    return mock.Mock(returncode=0, stdout='fake 1.0\n', stderr='')
                self.assertIn('-q', argv)
                self.assertEqual(kwargs['input'], 'bonjour; $(touch nope)')
                return mock.Mock(returncode=0, stdout='bɔ̃.ʒuʁ\n', stderr='')
            with mock.patch.object(prep.subprocess, 'run', side_effect=runner):
                result = prep.draft_phonemes('bonjour; $(touch nope)', executable, root)
            self.assertEqual(result['status'], 'draft')
            self.assertEqual(result['reviewStatus'], 'pending')
            self.assertEqual(result['ipa'], 'bɔ̃.ʒuʁ\n')
            self.assertEqual(result['inputSha256'], hashlib.sha256('bonjour; $(touch nope)'.encode()).hexdigest())

    def test_cli_is_explicit_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            text = root / 'text.txt'
            text.write_text('été', encoding='utf-8')
            output = root / 'annotation.json'
            with mock.patch.object(prep, 'draft_phonemes', return_value={'status': 'draft'}):
                code = prep.main(['annotate', '--text-file', str(text), '--executable', '/fake',
                                  '--data-parent', str(root), '--output', str(output)])
            self.assertEqual(code, 0)
            self.assertTrue(output.exists())
            with self.assertRaises(SystemExit) as exit_status:
                prep.main(['not-a-command'])
            self.assertEqual(exit_status.exception.code, 2)


if __name__ == '__main__':
    unittest.main()
