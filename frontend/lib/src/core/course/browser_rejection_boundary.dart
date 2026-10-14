/// The single platform-aware recognition boundary for an actual browser
/// autoplay/gesture rejection — the exact DOMException name
/// `NotAllowedError` — that the locked recording web path passes
/// untranslated (a `play()`/AudioContext rejection converted through
/// `JSPromise.toDart()`).
///
/// On the web platform [isBrowserAutoplayRejection] performs the guarded
/// exact-name recognition on the JS value. On the VM (and any other
/// non-browser platform) the accompanying stub is conservative and
/// recognizes nothing: native Dart objects are not browser diagnostics and
/// must never be invented into one.
///
/// Recognition only labels the cause; the original error object and stack
/// are always retained by the caller. No string/substring inference, no
/// dependency, no global state.
library;

export 'browser_rejection_boundary_stub.dart'
    if (dart.library.js_interop) 'browser_rejection_boundary_web.dart';
