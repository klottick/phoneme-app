# Phoneme app

## Flutter SDK

Use the stable Flutter SDK version in [`.flutter-version`](.flutter-version)
(Flutter 3.47.7, bundled Dart 3.13.5). Keep it side-by-side with any existing
Flutter installation; do not upgrade or replace a shared SDK. The version is an
official stable Flutter tag from <https://github.com/flutter/flutter>.

From the repository root, install a separate checkout (choose a new destination
if this one already exists):

```sh
FLUTTER_VERSION="$(cat frontend/.flutter-version)"
FLUTTER_SDK="$HOME/.local/share/flutter-$FLUTTER_VERSION"
git clone --depth 1 --branch "$FLUTTER_VERSION" --single-branch \
  https://github.com/flutter/flutter.git "$FLUTTER_SDK"
"$FLUTTER_SDK/bin/flutter" --version
export PATH="$FLUTTER_SDK/bin:$PATH"
```

The Flutter tool downloads the matching Dart and engine artifacts into this
checkout on first use. No global version manager is required.

## Frontend checks

From the repository root, with the pinned SDK's `bin` first on `PATH`:

```sh
cd frontend
flutter pub get
dart run build_runner build
flutter test --platform chrome test/unit/learning_database_connection_web_test.dart
flutter test test/unit/learning_database_connection_stub_test.dart
CHROME_BIN=/path/to/chrome
CHROME_EXECUTABLE="$CHROME_BIN" flutter drive \
  --driver=test_driver/integration_test.dart \
  --driver-port=4444 \
  --chrome-binary="$CHROME_BIN" \
  --target=learning_database_web_test_entrypoint.dart \
  -d web-server
flutter build web --release
flutter analyze
flutter test
```

Start a ChromeDriver matching `CHROME_BIN` on port `4444` before the web
integration-test command. This uses Flutter's Web Server device and the
WebDriver-launched Chrome; it avoids depending on Flutter's direct Chrome-device
debug-service startup.
