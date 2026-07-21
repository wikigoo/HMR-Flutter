// Conditional export that keeps `package:google_sign_in_web` (and its
// `dart:ui_web` dependency) out of native builds — mirroring the pattern
// used by the `google_sign_in` package's own example app
// (flutter/packages: google_sign_in/example/lib/src/web_wrapper.dart).
//
// Import this file and call `renderGoogleSignInButton()` only when
// `kIsWeb` is true.
export 'google_signin_web_button_stub.dart'
    if (dart.library.js_interop) 'google_signin_web_button_web.dart';
