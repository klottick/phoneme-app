/// VM (non-browser) fallback for `isBrowserAutoplayRejection`.
///
/// A genuine browser `NotAllowedError` DOMException cannot exist off the web
/// platform, and a native Dart object — including a test double with a `name`
/// property — must not be invented into a browser diagnosis. This stub
/// therefore deliberately recognizes nothing; it returns `false` for every
/// input so unknown sources stay generic.
///
/// The actual JS rejection path lives in
/// `browser_rejection_boundary_web.dart` and is verified only by the
/// browser-only test that exercises genuine JS rejections — a Dart `.name`
/// double through this stub is not proof of that path.
bool isBrowserAutoplayRejection(Object? error) => false;
