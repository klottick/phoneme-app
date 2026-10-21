"""Exercise local-demo operations without touching the real user service manager."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("local_demo.py")
ARTIFACTS = ("index.html", "main.dart.js", "sqlite3.wasm", "drift_worker.dart.js")


class LocalDemoTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="phoneme-demo-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo with spaces % and $"
        (self.root / "scripts").mkdir(parents=True)
        (self.root / "frontend").mkdir()
        if SCRIPT.exists():
            shutil.copy2(SCRIPT, self.root / "scripts/local_demo.py")
        self.bin = Path(self.temp.name) / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        self.calls = Path(self.temp.name) / "calls.jsonl"
        self.env["FAKE_CALL_LOG"] = str(self.calls)
        self.tool("flutter", """
import json, os, pathlib, sys
with open(os.environ['FAKE_CALL_LOG'], 'a') as f:
    f.write(json.dumps(['flutter', *sys.argv[1:]]) + '\\n')
if sys.argv[1] == 'build':
    if os.environ.get('FAKE_BUILD_FAIL'):
        sys.exit(7)
    output = pathlib.Path(next(a.split('=', 1)[1] for a in sys.argv if a.startswith('--output=')))
    output.mkdir(parents=True, exist_ok=True)
    for name in ('index.html', 'main.dart.js', 'sqlite3.wasm', 'drift_worker.dart.js'):
        if name != os.environ.get('FAKE_MISSING_ARTIFACT'):
            (output / name).write_text('built ' + name)
""")
        self.tool("systemctl", """
import json, os, sys
with open(os.environ['FAKE_CALL_LOG'], 'a') as f:
    f.write(json.dumps(['systemctl', *sys.argv[1:]]) + '\\n')
if 'show' in sys.argv:
    print(os.environ.get('FAKE_EXISTING_UNIT', ''))
""")
        self.tool("journalctl", """
import json, os, sys
with open(os.environ['FAKE_CALL_LOG'], 'a') as f:
    f.write(json.dumps(['journalctl', *sys.argv[1:]]) + '\\n')
""")
        for args in (("init", "-q"), ("-c", "user.name=Demo test", "-c",
                     "user.email=demo@example.invalid", "commit", "--allow-empty", "-qm", "test")):
            subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True)

    def tool(self, name, body):
        path = self.bin / name
        path.write_text(f"#!{sys.executable}\n" + body)
        path.chmod(0o755)
        return path

    def command(self, *args, **environment):
        return subprocess.run(
            [sys.executable, str(self.root / "scripts/local_demo.py"), *args],
            cwd=self.root, env=dict(self.env, **environment), text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20,
        )

    def call_log(self):
        return [json.loads(line) for line in self.calls.read_text().splitlines()] if self.calls.exists() else []

    def update(self, **environment):
        result = self.command("update", "--flutter", str(self.bin / "flutter"), **environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        return self.root / "build/local-demo/current"

    def test_update_publishes_complete_release_and_records_revision(self):
        current = self.update()
        self.assertTrue(current.is_symlink())
        for artifact in ARTIFACTS:
            self.assertTrue((current / artifact).is_file(), artifact)
        revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=self.root, text=True).strip()
        self.assertEqual(json.loads((current / "demo-build.json").read_text())["commit"], revision)
        calls = self.call_log()
        self.assertEqual(calls[0], ["flutter", "pub", "get", "--enforce-lockfile"])
        self.assertIn("--release", calls[1])
        self.assertIn("--no-pub", calls[1])
        self.assertFalse(any(call[0] == "systemctl" for call in calls))

    def test_failed_build_keeps_current_release(self):
        current = self.update()
        old_target = current.readlink()
        result = self.command("update", "--flutter", str(self.bin / "flutter"), FAKE_BUILD_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(current.readlink(), old_target)
        self.assertTrue((current / "index.html").is_file())

    def test_incomplete_build_is_not_published(self):
        current = self.update()
        old_target = current.readlink()
        result = self.command("update", "--flutter", str(self.bin / "flutter"), FAKE_MISSING_ARTIFACT="sqlite3.wasm")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(current.readlink(), old_target)

    def test_successful_update_retains_previous_build(self):
        current = self.update()
        previous = current.resolve()
        self.update()
        self.assertNotEqual(current.resolve(), previous)
        self.assertTrue((previous / "index.html").is_file())

    def test_install_without_a_build_does_not_register_a_service(self):
        result = self.command("install")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("update", result.stderr)
        self.assertFalse(self.call_log())

    def test_install_registers_repo_unit_with_loopback_and_restart(self):
        current = self.update()
        result = self.command("install")
        self.assertEqual(result.returncode, 0, result.stderr)
        unit = self.root / "build/local-demo/phoneme-demo.service"
        text = unit.read_text()
        self.assertIn('"127.0.0.1"', text)
        self.assertIn('"8088"', text)
        self.assertNotIn("0.0.0.0", text)
        self.assertIn("Restart=on-failure", text)
        self.assertIn("WantedBy=default.target", text)
        self.assertIn(str(current).replace("%", "%%").replace("$", "$$"), text)
        self.assertIn(["systemctl", "--user", "enable", "--now", str(unit)], self.call_log())
        self.assertNotIn("linger", json.dumps(self.call_log()))

    def test_install_refuses_another_units_definition(self):
        self.update()
        result = self.command("install", FAKE_EXISTING_UNIT="/some/other/phoneme-demo.service")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any("enable" in call for call in self.call_log()))

    def test_existing_non_symlink_current_is_not_overwritten(self):
        current = self.root / "build/local-demo/current"
        current.mkdir(parents=True)
        marker = current / "user-file"
        marker.write_text("preserve me")
        result = self.command("update", "--flutter", str(self.bin / "flutter"))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(marker.read_text(), "preserve me")

    def test_unmanaged_or_dangling_current_is_neither_served_nor_replaced(self):
        for dangling in (False, True):
            with self.subTest(dangling=dangling):
                current = self.root / "build/local-demo/current"
                current.parent.mkdir(parents=True, exist_ok=True)
                target = Path(self.temp.name) / ("missing" if dangling else "user-files")
                if not dangling:
                    target.mkdir()
                    for artifact in ARTIFACTS:
                        (target / artifact).write_text("not managed")
                current.symlink_to(target, target_is_directory=True)
                try:
                    for command in (("install",), ("update", "--flutter", str(self.bin / "flutter"))):
                        result = self.command(*command)
                        self.assertNotEqual(result.returncode, 0, result.stdout)
                        self.assertEqual(current.readlink(), target)
                    self.assertFalse(self.call_log())
                finally:
                    current.unlink(missing_ok=True)
                    self.calls.unlink(missing_ok=True)

    def test_untracked_frontend_source_prevents_publication(self):
        current = self.update()
        previous = current.readlink()
        (self.root / "frontend/untracked.dart").write_text("untracked source")
        result = self.command("update", "--flutter", str(self.bin / "flutter"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("untracked", result.stderr.lower())
        self.assertEqual(current.readlink(), previous)

    def test_unrelated_untracked_capture_does_not_block_update(self):
        (self.root / "capture.png").write_bytes(b"local evidence")
        self.update()

    def test_lifecycle_commands_use_user_manager_only(self):
        for command in ("start", "stop", "status", "logs"):
            result = self.command(command)
            self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.call_log()
        self.assertIn(["systemctl", "--user", "start", "phoneme-demo.service"], calls)
        self.assertIn(["systemctl", "--user", "stop", "phoneme-demo.service"], calls)
        self.assertTrue(any(call[:3] == ["systemctl", "--user", "status"] for call in calls))
        self.assertTrue(any(call[:3] == ["journalctl", "--user", "-u"] for call in calls))


if __name__ == "__main__":
    unittest.main()
