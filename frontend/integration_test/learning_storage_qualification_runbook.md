# Task 1 browser persistence qualification

This is a test-only entrypoint; it is not a production route. Use the pinned
Flutter SDK in `../.flutter-version`. No existing browser profile or learning
database is cleared or reused. Keep the chosen fresh profile after the run.

## Start the local app server

In one terminal, from the repository root:

```sh
cd frontend
PATH="/tmp/opencode/flutter-sdk-task1-3.47.7/bin:$PATH" flutter run \
  -d web-server \
  -t learning_database_qualification_app_entrypoint.dart \
  --web-hostname 127.0.0.1 \
  --web-port 7357
```

Use only `127.0.0.1`; leave this server running for both tabs and the restart.

## Automated web integration test

The verified driver path uses ChromeDriver matching the chosen Chrome binary.
Start ChromeDriver in a separate terminal, listening on port `4444` and allowing
loopback connections, then run from `frontend`:

```sh
CHROME_BIN=/absolute/path/to/chrome
CHROME_EXECUTABLE="$CHROME_BIN" flutter drive \
  --driver=test_driver/integration_test.dart \
  --driver-port=4444 \
  --chrome-binary="$CHROME_BIN" \
  --target=learning_database_web_test_entrypoint.dart \
  -d web-server
```

This executes the integration test in Chrome through WebDriver while Flutter
serves the test app. The direct `-d chrome` device path did not reach its debug
service in this environment; use the Web Server/WebDriver path above.

## Same-profile tabs and full-browser restart

Choose a new run-specific profile path under `/tmp/opencode`, verify it does not
exist, and preserve it after testing. For example:

```sh
PROFILE=/tmp/opencode/learning-storage-profile-task1-20261019-a
test ! -e "$PROFILE"
CHROME_BIN="${CHROME_BIN:-/home/klottick/.cache/ms-playwright/chromium-1248/chrome-linux64/chrome}"
"$CHROME_BIN" --headless=new --no-sandbox --no-first-run \
  --window-size=1280,800 \
  --user-data-dir="$PROFILE" --remote-debugging-port=9222 \
  'http://127.0.0.1:7357/?probe=task1'
```

Use Chrome DevTools Protocol on this actual Chrome process. Focus
`flt-semantics-placeholder` and press Enter to enable Flutter's accessibility
tree. In tab 1, record the
visible `learning-storage-backend` value, verify it is exactly one of
`opfsShared`, `opfsLocks`, or `sharedIndexedDb`, press **Write probe**, and
verify `learning-storage-probe-result` is exactly
`learning-storage-task1-persisted`. Open tab 2 in the same Chrome process and
same browser profile at the same origin (the same `?probe=task1` key); press
**Read probe** and verify the same backend and exact value. Do not create an
isolated browser context.

Inspect network responses for `drift_worker.dart.js` and `sqlite3.wasm`; both
must return successfully and the WASM response must have
`Content-Type: application/wasm`.

Close the browser normally using CDP `Browser.close` (or close all its windows
normally). Verify the Chrome process using this profile has exited. Relaunch the
same command with the same profile path, port, and origin, open one tab, and
press **Read probe**. Verify the selected implementation is still allowed and
the exact persisted value is still displayed. Do not clear the profile. Record
the Chrome version, selected backend, response status/MIME, observed values,
profile path, process-exit/relaunch result, and any open limits in the Task 1
report.
