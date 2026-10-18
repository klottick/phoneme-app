import hashlib
import gzip
import io
import json
import tarfile
import tempfile
import unittest
import urllib.error
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
                raw_archive = archive_bytes(entries)
                archive.write_bytes(raw_archive)
                output = root / 'new'
                with mock.patch.object(prep, 'ARCHIVE_SIZE', len(raw_archive)), mock.patch.object(
                        prep, 'ARCHIVE_SHA256', hashlib.sha256(raw_archive).hexdigest()):
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
            link_bytes = output.read_bytes()
            with mock.patch.object(prep, 'ARCHIVE_SIZE', len(link_bytes)), mock.patch.object(
                    prep, 'ARCHIVE_SHA256', hashlib.sha256(link_bytes).hexdigest()):
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
                self.assertEqual(kwargs['input'], 'été; $(touch nope)')
                return mock.Mock(returncode=0, stdout='bɔ̃.ʒuʁ\n', stderr='')
            with mock.patch.object(prep.subprocess, 'run', side_effect=runner) as run:
                result = prep.draft_phonemes('été; $(touch nope)', executable, root)
            self.assertEqual(result['status'], 'draft')
            self.assertEqual(result['reviewStatus'], 'pending')
            self.assertEqual(result['ipa'], 'bɔ̃.ʒuʁ\n')
            self.assertEqual(result['inputSha256'], hashlib.sha256('été; $(touch nope)'.encode()).hexdigest())
            phoneme_call = run.call_args_list[1]
            self.assertEqual(phoneme_call.args[0], [str(executable), '-q', '-v', 'fr-fr', '--ipa=3', '--stdin', f'--path={root}'])
            self.assertEqual(phoneme_call.kwargs['input'], 'été; $(touch nope)')
            self.assertEqual(phoneme_call.kwargs['timeout'], prep.TIMEOUT)
            self.assertEqual(result['version'], 'fake 1.0')
            self.assertEqual(result['settings'], ['-q', '-v', 'fr-fr', '--ipa=3', '--stdin', f'--path={root}'])
            self.assertEqual(result['tokenMapping'], 'unresolved')

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
            original_output = output.read_bytes()
            with mock.patch.object(prep, 'draft_phonemes', return_value={'status': 'replacement'}), mock.patch('sys.stderr', io.StringIO()):
                self.assertEqual(prep.main(['annotate', '--text-file', str(text), '--executable', '/fake',
                                            '--data-parent', str(root), '--output', str(output)]), 1)
            self.assertEqual(output.read_bytes(), original_output)
            with self.assertRaises(SystemExit) as exit_status:
                prep.main(['not-a-command'])
            self.assertEqual(exit_status.exception.code, 2)

    def test_archive_rejects_links_devices_oversize_bad_identity_and_unsafe_requests(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            bad_types = []
            for kind in (tarfile.LNKTYPE, tarfile.FIFOTYPE, tarfile.CHRTYPE, tarfile.BLKTYPE):
                data = io.BytesIO()
                with tarfile.open(fileobj=data, mode='w') as tar:
                    member = tarfile.TarInfo('picked.wav')
                    member.type = kind
                    member.linkname = 'target.wav'
                    tar.addfile(member)
                bad_types.append(data.getvalue())
            member = tarfile.TarInfo('picked.wav'); member.size = prep.MEMBER_LIMIT + 1
            header = member.tobuf(format=tarfile.USTAR_FORMAT, encoding='utf-8', errors='strict')
            compressed = io.BytesIO()
            with gzip.GzipFile(fileobj=compressed, mode='wb') as gz:
                gz.write(header)
                for _ in range((prep.MEMBER_LIMIT + 1) // (1024 * 1024)):
                    gz.write(b'\0' * (1024 * 1024))
                gz.write(b'\0' * ((prep.MEMBER_LIMIT + 1) % (1024 * 1024)))
                gz.write(b'\0' * 1024)
            bad_types.append(compressed.getvalue())
            for raw in bad_types:
                archive, target = root / 'bad.tar.gz', root / 'publish'
                archive.write_bytes(raw)
                with mock.patch.object(prep, 'ARCHIVE_SIZE', len(raw)), mock.patch.object(
                        prep, 'ARCHIVE_SHA256', hashlib.sha256(raw).hexdigest()):
                    with self.assertRaises(SentencePackageError):
                        prep.select_originals(archive, ['picked.wav'], target)
                self.assertFalse(target.exists())
                self.assertEqual(archive.read_bytes(), raw)
            good = archive_bytes([('picked.wav', b'ok')])
            archive.write_bytes(good)
            with mock.patch.object(prep, 'ARCHIVE_SIZE', len(good)), mock.patch.object(
                    prep, 'ARCHIVE_SHA256', hashlib.sha256(good).hexdigest()):
                for names in (None, [], [''], ['../x'], ['/x'], ['C:/x'], ['a//b'], ['a/./b'], ['x\\y'], ['x\0y'], [1], ['picked.wav', 'picked.wav'], ['missing.wav']):
                    with self.assertRaises(SentencePackageError):
                        prep.select_originals(archive, names, root / 'absent')
                for existing in (root / 'existing-dir', root / 'existing-link'):
                    if existing.name.endswith('dir'):
                        existing.mkdir()
                    else:
                        existing.symlink_to(root / 'sentinel')
                    with self.assertRaises(SentencePackageError):
                        prep.select_originals(archive, ['picked.wav'], existing)
                    self.assertTrue(existing.is_symlink() if existing.name.endswith('link') else existing.is_dir())
            for malformed in ('C:/x.wav', 'a//x.wav', 'a/./x.wav'):
                raw = archive_bytes([(malformed, b'ok')]); archive.write_bytes(raw)
                with mock.patch.object(prep, 'ARCHIVE_SIZE', len(raw)), mock.patch.object(
                        prep, 'ARCHIVE_SHA256', hashlib.sha256(raw).hexdigest()):
                    with self.assertRaises(SentencePackageError):
                        prep.select_originals(archive, [malformed], root / 'malformed-name')
            raw_tar = io.BytesIO()
            with tarfile.open(fileobj=raw_tar, mode='w') as tar:
                item = tarfile.TarInfo('picked.wav'); item.size = 2
                tar.addfile(item, io.BytesIO(b'ok'))
            archive.write_bytes(gzip.compress(raw_tar.getvalue()[:514]))
            truncated_bytes = archive.read_bytes()
            with mock.patch.object(prep, 'ARCHIVE_SIZE', len(truncated_bytes)), mock.patch.object(
                    prep, 'ARCHIVE_SHA256', hashlib.sha256(truncated_bytes).hexdigest()):
                with self.assertRaises(SentencePackageError):
                    prep.select_originals(archive, ['picked.wav'], root / 'truncated')
            with mock.patch.object(prep, 'ARCHIVE_SIZE', len(good)), mock.patch.object(
                    prep, 'ARCHIVE_SHA256', '0' * 64):
                archive.write_bytes(good)
                with self.assertRaises(SentencePackageError):
                    prep.select_originals(archive, ['picked.wav'], root / 'forged')

    def test_source_fetch_rejects_bad_sources_stream_failures_and_redirects(self):
        tsv = b'1\tone.wav\tbonjour\tbonjour\tx\t2\tfemale\n'
        tar = archive_bytes([('one.wav', b'RIFF')])
        values = [(prep.TSV_URL, tsv, prep.TSV_SIZE, prep.TSV_SHA256),
                  (prep.ARCHIVE_URL, tar, prep.ARCHIVE_SIZE, prep.ARCHIVE_SHA256)]
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.assertIn('/data/fr_fr/audio/train.tar.gz', prep.ARCHIVE_URL)
            self.assertEqual(prep.TSV_URL, f'https://huggingface.co/datasets/google/fleurs/resolve/{prep.REVISION}/data/fr_fr/train.tsv')
            self.assertEqual(prep.ARCHIVE_URL, f'https://huggingface.co/datasets/google/fleurs/resolve/{prep.REVISION}/data/fr_fr/audio/train.tar.gz')
            for index, (url, body, size, digest) in enumerate(values):
                target = root / f'failed-{index}'
                def bad_fetch(which, dest, *_):
                    Path(dest).write_bytes(b'bad')
                    if which in {prep.TSV_URL, prep.ARCHIVE_URL}: raise SentencePackageError('synthetic source failure')
                pins = mock.patch.multiple(prep, TSV_SIZE=len(tsv), TSV_SHA256=hashlib.sha256(tsv).hexdigest(),
                                           ARCHIVE_SIZE=len(tar), ARCHIVE_SHA256=hashlib.sha256(tar).hexdigest())
                with pins, mock.patch.object(prep, '_fetch_to', side_effect=bad_fetch):
                    with self.assertRaises(SentencePackageError):
                        prep.fetch_source(target)
                self.assertFalse(target.exists())
            with self.assertRaises(SentencePackageError):
                prep._fetch_to('https://attacker.invalid/file', root / 'nope', 1, '0' * 64)
            class Response:
                def __init__(self, final): self.final, self.calls = final, []
                def __enter__(self): return self
                def __exit__(self, *args): pass
                def geturl(self): return self.final
                def read(self, count):
                    self.calls.append(count)
                    return b'x' if len(self.calls) == 1 else b''
            for final in ('http://huggingface.co/file', 'https://evil.example/file', 'https://sub.us.aws.cdn.hf.co/file'):
                response = Response(final)
                opener = mock.Mock()
                opener.open.return_value = response
                with mock.patch.object(prep.urllib.request, 'build_opener', return_value=opener):
                    with self.assertRaises(SentencePackageError):
                        prep._fetch_to(prep.TSV_URL, root / 'redirect', 1, hashlib.sha256(b'x').hexdigest())
                self.assertEqual(response.calls, [])
            source_response = Response(prep.TSV_URL)
            opener = mock.Mock(); opener.open.return_value = source_response
            with mock.patch.object(prep.urllib.request, 'build_opener', return_value=opener):
                with self.assertRaises(SentencePackageError):
                    prep._fetch_to(prep.TSV_URL, root / 'interrupted', 2, '0' * 64)
            self.assertTrue(all(value <= prep.CHUNK_SIZE for value in source_response.calls))
            self.assertEqual(opener.open.call_args.args[0].full_url, prep.TSV_URL)
            for expected_size, expected_hash in ((2, hashlib.sha256(b'x').hexdigest()),
                                                  (1, '0' * 64)):
                response = Response('https://us.aws.cdn.hf.co/object')
                opener = mock.Mock(); opener.open.return_value = response
                with mock.patch.object(prep.urllib.request, 'build_opener', return_value=opener):
                    with self.assertRaises(SentencePackageError):
                        prep._fetch_to(prep.TSV_URL, root / f'bad-{expected_size}-{expected_hash[:1]}', expected_size, expected_hash)
            opener = mock.Mock(); opener.open.side_effect = urllib.error.URLError('offline')
            with mock.patch.object(prep.urllib.request, 'build_opener', return_value=opener):
                with self.assertRaises(SentencePackageError): prep._fetch_to(prep.TSV_URL, root / 'http-failure', 1, '0' * 64)
            handler = prep._AllowedRedirects()
            request = urllib.request.Request(prep.TSV_URL)
            for destination in ('http://huggingface.co/file', 'https://evil.example/file', 'https://sub.us.aws.cdn.hf.co/file'):
                with self.assertRaises(SentencePackageError):
                    handler.redirect_request(request, None, 302, 'redirect', {}, destination)
            self.assertIsNotNone(handler.redirect_request(request, None, 302, 'redirect', {}, 'https://us.aws.cdn.hf.co/file'))
            for name in ('old-empty', 'old-link'):
                dest = root / name
                if name.endswith('empty'): dest.mkdir()
                else: dest.symlink_to(root / 'elsewhere')
                with self.assertRaises(SentencePackageError): prep.fetch_source(dest)

    def test_source_fetch_tsv_parse_and_second_source_failure_leave_no_cache(self):
        good_tsv = b'1\tone.wav\tbonjour\tbonjour\tx\t2\tfemale\n'
        good_archive = archive_bytes([('one.wav', b'RIFF')])
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            def fetch_parse(url, destination, *_):
                Path(destination).write_bytes(b'not a valid row' if url == prep.TSV_URL else good_archive)
            with mock.patch.multiple(prep, TSV_SIZE=len(b'not a valid row'), TSV_SHA256=hashlib.sha256(b'not a valid row').hexdigest(),
                                     ARCHIVE_SIZE=len(good_archive), ARCHIVE_SHA256=hashlib.sha256(good_archive).hexdigest()), \
                 mock.patch.object(prep, '_fetch_to', side_effect=fetch_parse):
                target = root / 'bad-parse'
                with self.assertRaises(SentencePackageError): prep.fetch_source(target)
                self.assertFalse(target.exists())
            class Stream:
                def __init__(self, body, final): self.body, self.final, self.offset = body, final, 0
                def __enter__(self): return self
                def __exit__(self, *args): pass
                def geturl(self): return self.final
                def read(self, count):
                    chunk = self.body[self.offset:self.offset + count]; self.offset += len(chunk)
                    return chunk
            for index, tsv_body in enumerate((b'x', b'X' * len(good_tsv))):
                opener = mock.Mock()
                opener.open.return_value = Stream(tsv_body, prep.TSV_URL)
                with mock.patch.multiple(prep, TSV_SIZE=len(good_tsv), TSV_SHA256=hashlib.sha256(good_tsv).hexdigest(),
                                         ARCHIVE_SIZE=len(good_archive), ARCHIVE_SHA256=hashlib.sha256(good_archive).hexdigest()), \
                     mock.patch.object(prep.urllib.request, 'build_opener', return_value=opener):
                    target = root / f'tsv-integrity-failure-{index}'
                    with self.assertRaises(SentencePackageError): prep.fetch_source(target)
                    self.assertFalse(target.exists())
            http_opener = mock.Mock(); http_opener.open.side_effect = urllib.error.URLError('offline')
            with mock.patch.multiple(prep, TSV_SIZE=len(good_tsv), TSV_SHA256=hashlib.sha256(good_tsv).hexdigest(),
                                     ARCHIVE_SIZE=len(good_archive), ARCHIVE_SHA256=hashlib.sha256(good_archive).hexdigest()), \
                 mock.patch.object(prep.urllib.request, 'build_opener', return_value=http_opener):
                target = root / 'http-failure-cache'
                with self.assertRaises(SentencePackageError): prep.fetch_source(target)
                self.assertFalse(target.exists())
            for index, archive_body in enumerate((b'bad', b'X' * len(good_archive))):
                opener = mock.Mock()
                opener.open.side_effect = [Stream(good_tsv, prep.TSV_URL), Stream(archive_body, prep.ARCHIVE_URL)]
                with mock.patch.multiple(prep, TSV_SIZE=len(good_tsv), TSV_SHA256=hashlib.sha256(good_tsv).hexdigest(),
                                         ARCHIVE_SIZE=len(good_archive), ARCHIVE_SHA256=hashlib.sha256(good_archive).hexdigest()), \
                     mock.patch.object(prep.urllib.request, 'build_opener', return_value=opener):
                    target = root / f'archive-failure-{index}'
                    with self.assertRaises(SentencePackageError): prep.fetch_source(target)
                    self.assertFalse(target.exists())

    def test_pcm_matrix_preserves_formats_and_rejects_bad_inputs_transactionally(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for width, rate, channels in ((1, 8000, 1), (2, 16000, 2), (3, 22050, 2), (4, 44100, 1)):
                pcm = bytes(range(24))
                source, output = root / f'{width}.wav', root / f'{width}-crop.wav'
                make_wav(source, pcm, channels, width, rate)
                original_hash = hashlib.sha256(source.read_bytes()).hexdigest()
                result = prep.crop_pcm(source, output, 0, 24 // (width * channels))
                with wave.open(str(output), 'rb') as wav:
                    self.assertEqual(wav.readframes(99), pcm)
                    self.assertEqual((wav.getsampwidth(), wav.getframerate(), wav.getnchannels()), (width, rate, channels))
                frames = 24 // (width * channels)
                self.assertEqual((result['startFrame'], result['endFrame'], result['sampleWidth']), (0, frames, width))
                self.assertEqual((result['sampleRate'], result['channels'], result['durationSeconds']),
                                 (rate, channels, frames / rate))
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), original_hash)
            source = root / '2.wav'
            for start, end in ((-1, 1), (2, 1), (0, 99), (0.5, 1), ('0', 1), (False, 1)):
                target = root / f'invalid-{start}-{end}.wav'
                with self.assertRaises(SentencePackageError): prep.crop_pcm(source, target, start, end)
                self.assertFalse(target.exists())
            raw = source.read_bytes()
            truncated = root / 'truncated.wav'; truncated.write_bytes(raw[:-4])
            with self.assertRaises(SentencePackageError): prep.crop_pcm(truncated, root / 'truncated-out.wav', 5, 6)
            unsupported = root / 'unsupported.wav'
            with wave.open(str(unsupported), 'wb') as wav:
                wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(8000); wav.writeframes(b'\0\0')
            bytes_with_unsupported_encoding = bytearray(unsupported.read_bytes())
            bytes_with_unsupported_encoding[20:22] = (3).to_bytes(2, 'little')
            unsupported.write_bytes(bytes_with_unsupported_encoding)
            with self.assertRaises(SentencePackageError): prep.crop_pcm(unsupported, root / 'unsupported-out.wav', 0, 1)
            for existing in (root / 'already.wav', root / 'linked.wav'):
                if existing.name == 'already.wav': existing.write_bytes(b'existing')
                else: existing.symlink_to(source)
                before = existing.read_bytes()
                with self.assertRaises(SentencePackageError): prep.crop_pcm(source, existing, 0, 1)
                self.assertEqual(existing.read_bytes(), before)
            failed_output = root / 'write-failed.wav'
            real_wave_open = wave.open
            def fail_output(path, mode='rb'):
                if mode == 'wb': raise OSError('synthetic write failure')
                return real_wave_open(path, mode)
            with mock.patch.object(prep.wave, 'open', side_effect=fail_output):
                with self.assertRaises(OSError): prep.crop_pcm(source, failed_output, 0, 1)
            self.assertFalse(failed_output.exists())

    def test_annotation_errors_are_bounded_and_never_claim_review(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); executable = root / 'fake-tool'; executable.write_text('fake')
            with self.assertRaises(SentencePackageError): prep.draft_phonemes('salut', root / 'missing', root)
            for responses in (
                [mock.Mock(returncode=1, stdout='', stderr='bad'), mock.Mock(returncode=0, stdout='ipa', stderr='')],
                [mock.Mock(returncode=0, stdout='version', stderr=''), mock.Mock(returncode=1, stdout='ipa', stderr='bad')],
                [mock.Mock(returncode=0, stdout='', stderr=''), mock.Mock(returncode=0, stdout='ipa', stderr='')],
                [mock.Mock(returncode=0, stdout='version', stderr=''), mock.Mock(returncode=0, stdout=' \n', stderr='')],
            ):
                with mock.patch.object(prep.subprocess, 'run', side_effect=responses):
                    with self.assertRaises(SentencePackageError): prep.draft_phonemes('été', executable, root)
            def timeout(*args, **kwargs): raise prep.subprocess.TimeoutExpired(args[0], kwargs['timeout'])
            with mock.patch.object(prep.subprocess, 'run', side_effect=timeout) as run:
                with self.assertRaises(SentencePackageError): prep.draft_phonemes('été', executable, root)
            self.assertEqual(run.call_args.kwargs['timeout'], prep.TIMEOUT)

    def test_cli_runs_all_commands_and_errors_without_network_or_partial_output(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            tsv = root / 'selection.json'; tsv.write_text('["one.wav"]')
            cache = root / 'cache'; cache.mkdir(); (cache / 'train.tar.gz').write_bytes(b'tar')
            output = root / 'selected'
            with mock.patch.object(prep, 'fetch_source', return_value={'ok': 1}), mock.patch.object(prep, 'select_originals', return_value={'ok': 1}) as select, mock.patch.object(prep, 'crop_pcm', return_value={'ok': 1}), mock.patch.object(prep, 'draft_phonemes', return_value={'status': 'draft', 'text': 'été'}), mock.patch.object(prep.urllib.request, 'build_opener', side_effect=AssertionError('unexpected network')):
                self.assertEqual(prep.main(['fetch-source', '--cache', str(root / 'cache2')]), 0)
                self.assertEqual(prep.main(['select', '--selection', str(tsv), '--cache', str(cache), '--output', str(output)]), 0)
                wav = root / 'source.wav'; make_wav(wav, b'\0\0')
                self.assertEqual(prep.main(['crop', '--source', str(wav), '--destination', str(root / 'crop.wav'), '--start-frame', '0', '--end-frame', '1']), 0)
                text = root / 'text'; text.write_text('été', encoding='utf-8')
                annotation = root / 'annotation.json'
                self.assertEqual(prep.main(['annotate', '--text-file', str(text), '--executable', str(root / 'fake'), '--data-parent', str(root), '--output', str(annotation)]), 0)
                self.assertIn('été', annotation.read_text(encoding='utf-8'))
                self.assertEqual(select.call_count, 1)
            for content in ('{', 'null', '["one.wav", "one.wav"]'):
                selection = root / 'bad-selection.json'; selection.write_text(content)
                stderr = io.StringIO()
                with mock.patch('sys.stderr', stderr), mock.patch.object(prep, 'select_originals') as select_call:
                    status = prep.main(['select', '--selection', str(selection), '--cache', str(cache), '--output', str(root / 'bad-output')])
                self.assertEqual(status, 1); self.assertIn('error:', stderr.getvalue())
                self.assertNotIn('Traceback', stderr.getvalue()); self.assertFalse((root / 'bad-output').exists())
                select_call.assert_not_called()
            for content in ('{}', '[1]'):
                selection = root / 'bad-selection.json'; selection.write_text(content)
                stderr = io.StringIO()
                with mock.patch('sys.stderr', stderr):
                    status = prep.main(['select', '--selection', str(selection), '--cache', str(cache), '--output', str(root / 'bad-output')])
                self.assertEqual(status, 1); self.assertIn('error:', stderr.getvalue())
                self.assertFalse((root / 'bad-output').exists())
            stderr = io.StringIO()
            with mock.patch('sys.stderr', stderr), mock.patch.object(
                    prep, 'crop_pcm', side_effect=SentencePackageError('bad crop')):
                status = prep.main(['crop', '--source', str(root / 'absent.wav'), '--destination', str(root / 'failed-crop.wav'), '--start-frame', '0', '--end-frame', '1'])
            self.assertEqual(status, 1); self.assertIn('bad crop', stderr.getvalue())
            self.assertNotIn('Traceback', stderr.getvalue()); self.assertFalse((root / 'failed-crop.wav').exists())


if __name__ == '__main__':
    unittest.main()
