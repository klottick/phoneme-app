"""Safe offline preparation tools for the FR08 sentence package."""

import argparse
import ctypes
import errno
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import wave
from pathlib import Path

from french_sentence_package import SentencePackageError, canonical_json, parse_fleurs_train_tsv

REVISION = "d7c758a6dceecd54a98cac43404d3d576e721f07"
TSV_URL = f"https://huggingface.co/datasets/google/fleurs/resolve/{REVISION}/data/fr_fr/train.tsv"
ARCHIVE_URL = f"https://huggingface.co/datasets/google/fleurs/resolve/{REVISION}/data/fr_fr/audio/train.tar.gz"
TSV_SIZE = 2064047
TSV_SHA256 = "3df668c3b9b4101cc3e3d8f3024b311ccfd2e9a8c8f910b3efedc27fd4219a0f"
ARCHIVE_SIZE = 1730529959
ARCHIVE_SHA256 = "39b5bad1f61d3ae4ef64c2eb16f9524ffb21d8568965dd71b09702befdbd7f95"
CHUNK_SIZE = 1024 * 1024
MEMBER_LIMIT = 100 * 1024 * 1024
TIMEOUT = 30


def _identity(path):
    digest = hashlib.sha256()
    size = 0
    with Path(path).open("rb") as stream:
        while True:
            chunk = stream.read(CHUNK_SIZE)
            if not chunk:
                break
            size += len(chunk)
            digest.update(chunk)
    return size, digest.hexdigest()


def _verify(path, expected_size, expected_hash, label):
    size, digest = _identity(path)
    if size != expected_size or digest != expected_hash:
        raise SentencePackageError(f"{label} source size or SHA256 does not match pinned identity")
    return size, digest


def _fresh_target(path):
    path = Path(path)
    if path.exists() or path.is_symlink():
        raise SentencePackageError(f"output already exists: {path}")
    if not path.parent.is_dir():
        raise SentencePackageError(f"output parent directory does not exist: {path.parent}")
    return path


def _publish_staging(staging, target):
    try:
        _renameat2(staging, target)
    except OSError as exc:
        if exc.errno == errno.EEXIST:
            raise SentencePackageError(f"output already exists: {target}") from exc
        if exc.errno in (errno.ENOSYS, errno.EINVAL, errno.ENOTSUP, errno.EOPNOTSUPP):
            raise SentencePackageError("atomic no-overwrite publication is unsupported on this platform") from exc
        raise SentencePackageError(f"cannot publish output without overwrite: {target} ({exc.strerror or exc})") from exc


def _renameat2(staging, target):
    """Atomically rename a path without replacing any existing target."""
    try:
        libc = ctypes.CDLL(None, use_errno=True)
        renameat2 = libc.renameat2
    except (AttributeError, OSError) as exc:
        raise OSError(errno.ENOSYS, "libc renameat2 is unavailable") from exc
    renameat2.argtypes = (ctypes.c_int, ctypes.c_char_p, ctypes.c_int,
                          ctypes.c_char_p, ctypes.c_uint)
    renameat2.restype = ctypes.c_int
    at_fdcwd, rename_noreplace = -100, 1
    result = renameat2(at_fdcwd, os.fsencode(staging), at_fdcwd,
                       os.fsencode(target), rename_noreplace)
    if result != 0:
        code = ctypes.get_errno()
        raise OSError(code, os.strerror(code), os.fspath(target))


def _safe_member_name(name):
    parts = name.split("/")
    return (bool(name) and not name.startswith("/") and "\\" not in name
            and "\x00" not in name and all(part not in ("", ".", "..") for part in parts)
            and not (len(parts[0]) >= 2 and parts[0][1] == ":"))


def select_originals(archive, filenames, output):
    archive, output = Path(archive), _fresh_target(output)
    _verify(archive, ARCHIVE_SIZE, ARCHIVE_SHA256, "archive")
    if not isinstance(filenames, list) or not filenames:
        raise SentencePackageError("selection must be a nonempty list of member names")
    if any(not isinstance(n, str) or not _safe_member_name(n) for n in filenames):
        raise SentencePackageError("selection contains an unsafe archive member name")
    if len(set(filenames)) != len(filenames):
        raise SentencePackageError("selection contains duplicate member names")
    selected = set(filenames)
    staging = Path(tempfile.mkdtemp(prefix=f".{output.name}.", dir=output.parent))
    found = {}
    try:
        with tarfile.open(archive, "r:gz") as tar:
            for member in tar:
                name = member.name
                if not _safe_member_name(name):
                    raise SentencePackageError(f"unsafe archive member name: {name!r}")
                if not (member.isfile() or member.isdir()):
                    raise SentencePackageError(f"unsupported archive member type: {name!r}")
                if name not in selected:
                    continue
                if name in found:
                    raise SentencePackageError(f"duplicate archive member: {name}")
                if not member.isfile() or member.size > MEMBER_LIMIT:
                    raise SentencePackageError(f"selected member is not a bounded regular file: {name}")
                source = tar.extractfile(member)
                if source is None:
                    raise SentencePackageError(f"cannot read archive member: {name}")
                destination = staging.joinpath(*name.split("/"))
                destination.parent.mkdir(parents=True, exist_ok=True)
                digest, size = hashlib.sha256(), 0
                with destination.open("xb") as out:
                    while True:
                        chunk = source.read(min(CHUNK_SIZE, MEMBER_LIMIT + 1 - size))
                        if not chunk:
                            break
                        size += len(chunk)
                        if size > MEMBER_LIMIT:
                            raise SentencePackageError(f"selected member exceeds 100 MiB: {name}")
                        digest.update(chunk)
                        out.write(chunk)
                if size != member.size:
                    raise SentencePackageError(f"truncated archive member: {name}")
                found[name] = {"byteLength": size, "sha256": digest.hexdigest(), "path": name}
        missing = selected - found.keys()
        if missing:
            raise SentencePackageError("missing archive member(s): " + ", ".join(sorted(missing)))
        _publish_staging(staging, output)
        return found
    except (tarfile.TarError, OSError) as exc:
        raise SentencePackageError(f"cannot safely select archive members: {exc}") from exc
    finally:
        if staging.exists():
            shutil.rmtree(staging)


def _fetch_to(url, destination, expected_size, expected_hash):
    if url not in {TSV_URL, ARCHIVE_URL}:
        raise SentencePackageError("source URL is not in the fixed source allowlist")
    request = urllib.request.Request(url, headers={"User-Agent": "fr08-offline-preparer"})
    try:
        opener = urllib.request.build_opener(_AllowedRedirects())
        response = opener.open(request, timeout=TIMEOUT)
    except (OSError, urllib.error.URLError) as exc:
        raise SentencePackageError(f"source fetch failed ({type(exc).__name__})") from exc
    with response:
        final = urllib.parse.urlparse(response.geturl())
        if final.scheme != "https" or final.hostname not in {"huggingface.co", "us.aws.cdn.hf.co"}:
            raise SentencePackageError("source redirected to an untrusted HTTPS host")
        digest, size = hashlib.sha256(), 0
        with Path(destination).open("xb") as out:
            while True:
                chunk = response.read(CHUNK_SIZE)
                if not chunk:
                    break
                size += len(chunk)
                if size > expected_size:
                    raise SentencePackageError("source exceeds pinned size")
                digest.update(chunk)
                out.write(chunk)
        if size != expected_size or digest.hexdigest() != expected_hash:
            raise SentencePackageError("downloaded source size or SHA256 does not match pinned identity")


def fetch_source(cache):
    cache = _fresh_target(cache)
    staging = Path(tempfile.mkdtemp(prefix=f".{cache.name}.", dir=cache.parent))
    try:
        _fetch_to(TSV_URL, staging / "train.tsv", TSV_SIZE, TSV_SHA256)
        _fetch_to(ARCHIVE_URL, staging / "train.tar.gz", ARCHIVE_SIZE, ARCHIVE_SHA256)
        try:
            text = (staging / "train.tsv").read_text(encoding="utf-8")
        except (UnicodeError, OSError) as exc:
            raise SentencePackageError(f"invalid source TSV: {exc}") from exc
        parse_fleurs_train_tsv(text)
        _publish_staging(staging, cache)
        return {name: {"byteLength": size, "sha256": digest, "path": name}
                for name, (size, digest) in (("train.tsv", (TSV_SIZE, TSV_SHA256)),
                                             ("train.tar.gz", (ARCHIVE_SIZE, ARCHIVE_SHA256)))}
    finally:
        if staging.exists():
            shutil.rmtree(staging)


def crop_pcm(source, destination, start_frame, end_frame):
    destination = _fresh_target(destination)
    if any(isinstance(v, bool) or not isinstance(v, int) for v in (start_frame, end_frame)):
        raise SentencePackageError("crop offsets must be integers")
    try:
        with wave.open(str(source), "rb") as inp:
            params = inp.getparams()
            if params.comptype != "NONE" or params.sampwidth not in (1, 2, 3, 4):
                raise SentencePackageError("only uncompressed integer PCM WAV is supported")
            total, frame_size = params.nframes, params.nchannels * params.sampwidth
            if start_frame < 0 or end_frame <= start_frame or end_frame > total:
                raise SentencePackageError("crop range must be a valid nonempty half-open frame range")
            inp.setpos(start_frame)
            data = inp.readframes(end_frame - start_frame)
            if len(data) != (end_frame - start_frame) * frame_size:
                raise SentencePackageError("WAV data is truncated")
    except (wave.Error, EOFError, OSError) as exc:
        raise SentencePackageError(f"invalid or unsupported WAV: {exc}") from exc
    try:
        staging_fd, staging_name = tempfile.mkstemp(
            prefix=f".{destination.name}.", suffix=".tmp", dir=destination.parent)
    except OSError as exc:
        raise SentencePackageError(f"cannot create private crop staging file: {exc}") from exc
    staging = Path(staging_name)
    published = False
    try:
        with os.fdopen(staging_fd, "wb") as raw:
            with wave.open(raw, "wb") as out:
                out.setparams(params)
                out.writeframes(data)
        _publish_staging(staging, destination)
        published = True
    finally:
        if not published:
            staging.unlink(missing_ok=True)
    size, digest = _identity(destination)
    count = end_frame - start_frame
    return {"path": str(destination), "sha256": digest, "byteLength": size,
            "frameCount": count, "sampleRate": params.framerate, "channels": params.nchannels,
            "sampleWidth": params.sampwidth, "durationSeconds": count / params.framerate,
            "startFrame": start_frame, "endFrame": end_frame}


def draft_phonemes(text, executable, data_parent):
    if not isinstance(text, str) or not text:
        raise SentencePackageError("annotation text must be nonempty UTF-8 text")
    exe = Path(executable)
    if not exe.is_file():
        raise SentencePackageError(f"phonemizer executable not found: {exe}")
    base = [str(exe), "-q", "-v", "fr-fr", "--ipa=3", "--stdin", f"--path={data_parent}"]
    try:
        version = subprocess.run([str(exe), "--version"], input="", text=True, capture_output=True, timeout=TIMEOUT, check=False)
        result = subprocess.run(base, input=text, text=True, capture_output=True, timeout=TIMEOUT, check=False)
    except (OSError, subprocess.SubprocessError) as exc:
        raise SentencePackageError(f"phonemizer execution failed: {exc}") from exc
    if version.returncode or not (version.stdout or version.stderr).strip() or result.returncode or not result.stdout.strip():
        raise SentencePackageError("phonemizer failed or returned empty IPA; check local French voice data")
    return {"status": "draft", "reviewStatus": "pending", "text": text,
            "inputSha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
            "version": (version.stdout or version.stderr).strip(), "settings": base[1:], "ipa": result.stdout,
            "tokenMapping": "unresolved"}


class _AllowedRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urllib.parse.urlparse(newurl)
        if parsed.scheme != "https" or parsed.hostname not in {"huggingface.co", "us.aws.cdn.hf.co"}:
            raise SentencePackageError("source redirected to an untrusted HTTPS host")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    fetch = commands.add_parser("fetch-source")
    fetch.add_argument("--cache", required=True, type=Path)
    select = commands.add_parser("select")
    select.add_argument("--selection", required=True, type=Path); select.add_argument("--cache", required=True, type=Path); select.add_argument("--output", required=True, type=Path)
    crop = commands.add_parser("crop")
    crop.add_argument("--source", required=True, type=Path); crop.add_argument("--destination", required=True, type=Path); crop.add_argument("--start-frame", required=True, type=int); crop.add_argument("--end-frame", required=True, type=int)
    annotate = commands.add_parser("annotate")
    annotate.add_argument("--text-file", required=True, type=Path); annotate.add_argument("--executable", required=True, type=Path); annotate.add_argument("--data-parent", required=True, type=Path); annotate.add_argument("--output", required=True, type=Path)
    try:
        args = parser.parse_args(argv)
        if args.command == "fetch-source":
            result = fetch_source(args.cache)
        elif args.command == "select":
            selection = json.loads(args.selection.read_text(encoding="utf-8"))
            if (not isinstance(selection, list) or not selection
                    or any(not isinstance(name, str) or not name for name in selection)
                    or len(set(selection)) != len(selection)):
                raise SentencePackageError("selection JSON must be a nonempty list of unique archive member-name strings")
            result = select_originals(args.cache / "train.tar.gz", selection, args.output)
        elif args.command == "crop":
            result = crop_pcm(args.source, args.destination, args.start_frame, args.end_frame)
        else:
            text = args.text_file.read_text(encoding="utf-8")
            result = draft_phonemes(text, args.executable, args.data_parent)
            _fresh_target(args.output)
            _write_json(args.output, result)
        if args.command != "annotate":
            print(canonical_json(result))
        return 0
    except (SentencePackageError, OSError, UnicodeError, json.JSONDecodeError, tarfile.TarError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


def _write_json(path, value):
    path = _fresh_target(path)
    try:
        staging_fd, staging_name = tempfile.mkstemp(
            prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    except OSError as exc:
        raise SentencePackageError(f"cannot create private JSON staging file: {exc}") from exc
    staging = Path(staging_name)
    published = False
    try:
        with os.fdopen(staging_fd, "w", encoding="utf-8", errors="strict") as out:
            out.write(canonical_json(value) + "\n")
        _publish_staging(staging, path)
        published = True
    finally:
        if not published:
            staging.unlink(missing_ok=True)
    return value


if __name__ == "__main__":
    raise SystemExit(main())
