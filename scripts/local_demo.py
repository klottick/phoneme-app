"""Build and manage the localhost-only demo; runtime files stay under the repo."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid


ROOT = Path(__file__).resolve().parents[1]
DEMO = ROOT / "build/local-demo"
UNIT = "phoneme-demo.service"
URL = "http://127.0.0.1:8088"
ARTIFACTS = ("index.html", "main.dart.js", "sqlite3.wasm", "drift_worker.dart.js")


def run(*args, cwd=ROOT, capture=False):
    return subprocess.run(args, cwd=cwd, check=True, text=True,
                          stdout=subprocess.PIPE if capture else None)


def validate_build(directory):
    missing = [name for name in ARTIFACTS if not (directory / name).is_file()]
    if missing:
        raise ValueError("Incomplete demo build: " + ", ".join(missing))


def update(flutter):
    current = DEMO / "current"
    if current.exists() and not current.is_symlink():
        raise ValueError(f"Refusing to replace a non-symlink: {current}")
    flutter = shutil.which(flutter)
    if not flutter:
        raise ValueError("Flutter not found. Supply --flutter /absolute/path/to/flutter")
    revision = run("git", "rev-parse", "HEAD", capture=True).stdout.strip()
    if run("git", "diff", "HEAD", "--name-only", capture=True).stdout.strip():
        raise ValueError("Commit tracked changes before publishing a stable demo build")
    release = DEMO / "releases" / (revision[:12] + "-" + uuid.uuid4().hex[:12])
    release.mkdir(parents=True)
    run(flutter, "pub", "get", "--enforce-lockfile", cwd=ROOT / "frontend")
    run(flutter, "build", "web", "--release", "--no-pub",
        "--output=" + str(release), cwd=ROOT / "frontend")
    validate_build(release)
    metadata = {"commit": revision, "builtAt": datetime.now(timezone.utc).isoformat()}
    (release / "demo-build.json").write_text(json.dumps(metadata, indent=2) + "\n")
    # Publish only after the entire build succeeds. Previous releases are retained.
    pending = DEMO / (".current-" + uuid.uuid4().hex)
    pending.symlink_to(release.relative_to(DEMO), target_is_directory=True)
    os.replace(pending, current)
    print(f"Published {revision} at {URL}\nBuild: {release}")


def quote(value):
    # Unit-file specifiers and ExecStart environment expansion are not shell syntax.
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"').replace(
        "%", "%%").replace("$", "$$") + '"'


def install():
    if not (DEMO / "current").is_dir():
        raise ValueError("Build first: python3 scripts/local_demo.py update --flutter /path/to/flutter")
    validate_build(DEMO / "current")
    git_dir = run("git", "rev-parse", "--absolute-git-dir", capture=True).stdout.strip()
    common = run("git", "rev-parse", "--git-common-dir", capture=True).stdout.strip()
    if Path(git_dir).resolve() != (ROOT / common).resolve():
        raise ValueError("Install from the primary checkout, not a temporary worktree")
    unit = DEMO / UNIT
    existing = run("systemctl", "--user", "show", UNIT, "--property=FragmentPath",
                   "--value", capture=True).stdout.strip()
    if existing and Path(existing).resolve() != unit.resolve():
        raise ValueError(f"Refusing to replace another service definition: {existing}")
    command = [sys.executable, "-m", "http.server", "--bind", "127.0.0.1",
               "--directory", str(DEMO / "current"), "8088"]
    text = ("[Unit]\nDescription=Phoneme localhost demo\n\n[Service]\nType=exec\n"
            "ExecStart=" + " ".join(quote(arg) for arg in command) + "\n"
            "Restart=on-failure\nRestartSec=3\n\n[Install]\nWantedBy=default.target\n")
    if unit.exists() and unit.read_text() != text:
        raise ValueError(f"Existing unit differs; inspect it before replacing: {unit}")
    unit.write_text(text)
    run("systemctl", "--user", "daemon-reload")
    run("systemctl", "--user", "enable", "--now", str(unit))
    print(f"Demo: {URL}\nService definition: {unit}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    build = commands.add_parser("update", help="Build a release and atomically publish it")
    build.add_argument("--flutter", default=os.environ.get("FLUTTER", "flutter"))
    for name in ("install", "start", "stop", "status", "logs"):
        commands.add_parser(name)
    args = parser.parse_args()
    try:
        if not DEMO.resolve().is_relative_to(ROOT):
            raise ValueError("Demo runtime directory must remain inside the repo")
        if args.command == "update":
            update(args.flutter)
        elif args.command == "install":
            install()
        elif args.command == "logs":
            run("journalctl", "--user", "-u", UNIT, "-n", "50", "--no-pager")
        else:
            command = ["systemctl", "--user", args.command, UNIT]
            if args.command == "status":
                command.append("--no-pager")
            run(*command)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Local demo: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
