# SQLite learning storage qualification runbook

This is a test-only entrypoint; it is not a production route. Use the pinned
Flutter SDK in `../.flutter-version`. The Task 1 smoke and Task 9 retention
procedures below use a fresh browser profile; no existing browser profile or
learning database is cleared or reused. Keep the chosen profile after the run.

## Start the local app server

In one terminal, from the repository root:

```sh
cd frontend
PATH="/tmp/opencode/flutter-sdk-task1-3.47.7/bin:$PATH" flutter run \
  -d web-server \
  -t integration_test/learning_database_qualification_app.dart \
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
  --target=integration_test/learning_database_web_test.dart \
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

## Task 9 native and web SQLite retention/restart qualification

Use a fresh, unique run ID. The qualification owner is isolated as
`sqlite-qualification-<run-id>` in course `en-fr`; no cloud transport or user
credentials are used. The app uses the production SQL repositories. Record the
backend, run ID, counts, summaries, latest receipt, logical SQLite page bytes,
and durations shown after **Verify retention**. Page bytes are not a capacity or
quota guarantee.

### Native app and same-install restart

From `frontend`, build and run the app on an available Android device or iOS
Simulator/device:

```sh
PATH="/tmp/opencode/flutter-sdk-task1-3.47.7/bin:$PATH" flutter run \
  -d <device-id> \
  -t integration_test/learning_database_qualification_app.dart \
  --dart-define=learningRunId=<unique-run-id>
```

Confirm the displayed run ID and backend. Press **Seed retention**, wait for the
result, then press **Verify retention** and record all three families. Stop the
app without uninstalling it, clearing storage, or switching profiles. Restart
the same installed app with the same run ID, press **Verify retention**, and
compare the report before and after restart.

Android restart:

```sh
adb -s <serial> shell am force-stop com.example.phoneme_app
adb -s <serial> shell monkey -p com.example.phoneme_app 1
```

iOS Simulator restart:

```sh
xcrun simctl terminate <simulator-udid> com.example.phonemeApp
xcrun simctl launch <simulator-udid> com.example.phonemeApp
```

On physical iOS, close and reopen the same installed app through the app
switcher. Never uninstall or clear app data between seeding and verification.
A Linux file-backed test is not Android/iOS evidence.

### Web integration and same-profile tabs/restart

Attempt the task's exact integration command from `frontend`:

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/learning_database_web_test.dart -d chrome
```

The integration test seeds and reloads all three families through the SQL
repositories. Record the chosen implementation and full report. The prior
environment could not reach Flutter's Chrome debug service; if that still
occurs, preserve the failure and separately attempt the existing WebDriver
alternative documented above. Do not claim the alternative as a pass for the
exact command.

For manual same-profile qualification, run the qualification app on loopback:

```sh
cd frontend
PATH="/tmp/opencode/flutter-sdk-task1-3.47.7/bin:$PATH" flutter run \
  -d web-server \
  -t integration_test/learning_database_qualification_app.dart \
  --web-hostname 127.0.0.1 --web-port 7357
```

Use a new profile path under `/tmp/opencode` that does not exist; preserve it
after testing. Launch Chrome against
`http://127.0.0.1:7357/?runId=<unique-run-id>` with that profile. In tab A,
prepare command A; in tab B, prepare command B before either command is
submitted. In tab A, enable **Discard next submit acknowledgment**, then submit
A; record the committed result while its acknowledgment is discarded. Submit B
in tab B and record its stale-cursor conflict. Copy the exact canonical JSON
shown in tab A's `learning-storage-frozen-command` into tab B's
`learning-storage-replay-input`, then press **Replay frozen command**. Record
`duplicate=true`, one attempt for the run-ID scope, and an unchanged attempt
count. Both tabs must show the same backend, run ID, owner scope and current
cursor, and use the same origin/profile.

Verify successful responses for `drift_worker.dart.js` and `sqlite3.wasm`, with
`Content-Type: application/wasm` for the WASM response. Close every Chrome
window normally, verify the Chrome process using the profile has exited, then
relaunch the same command with the same profile, origin, and run ID. Verify the
rows, counts, and latest receipt again. Do not use a separate browser context,
delete/reuse an existing profile, or clear browser storage. Inspect only a
known authorized deployed origin; otherwise deployment headers, auth-popup,
and quota-denial gates remain OPEN.
