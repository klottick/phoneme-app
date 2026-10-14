import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web (browser) implementation of `isBrowserAutoplayRejection`.
///
/// Recognizes a genuine JS value whose `name` property is exactly the string
/// `NotAllowedError` — the browser's own discriminator for the
/// `play()`/AudioContext autoplay-rejection a locked recording path passes
/// through `.toDart()` untranslated. The recognition is fully guarded:
///
/// * a value that is not a JS object (native Dart objects, strings, numbers,
///   `null`) is rejected — the representation conversion is itself guarded;
/// * a missing `name` property is rejected — the `in` check never invokes a
///   getter, so a throwing getter cannot break the surface check;
/// * a throwing `name` getter is rejected safely (the guarded read);
/// * a non-string `name` is rejected (the supported `isA` interop check, not
///   an extension-type `is` test);
/// * any other name is rejected — exact string equality only, never
///   substring/`toString` inference.
///
/// Recognition labels the cause only; it never replaces, wraps, or rethrows
/// the original error, so the original object and stack remain with the
/// caller.
bool isBrowserAutoplayRejection(Object? error) {
  // Guarded representation conversion (JSObject.fromInteropObject is a
  // representation cast, not provenance proof — the property surface is
  // checked below independently).
  final JSObject? object = _asJsObject(error);
  if (object == null) {
    return false;
  }
  // A DOMException is a JS object; non-object sources are not recognized.
  if (!object.typeofEquals('object')) {
    return false;
  }
  // Guarded property surface: `name` must exist.
  final bool hasName;
  try {
    hasName = object.has('name');
  } on Object {
    return false;
  }
  if (!hasName) {
    return false;
  }
  // Guarded property read: a throwing `name` getter is a safe rejection.
  final JSAny? name;
  try {
    name = object['name'];
  } on Object {
    return false;
  }
  // A non-string `name` is not a DOMException name (the supported
  // `typeofEquals` interop check, not an extension-type `is` test).
  if (name == null || !name.typeofEquals('string')) {
    return false;
  }
  return (name as JSString).toDart == 'NotAllowedError';
}

/// Guarded representation conversion of [error] to a `JSObject`.
///
/// Returns `null` when the value is `null`, is not a JS value, or the
/// conversion throws. Native Dart objects are not source-shaped JS values
/// and are therefore never recognized.
JSObject? _asJsObject(Object? error) {
  if (error == null) {
    return null;
  }
  try {
    return JSObject.fromInteropObject(error);
  } on Object {
    return null;
  }
}
