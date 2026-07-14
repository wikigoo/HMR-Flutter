import 'package:flutter/widgets.dart';

/// Stub for the web-only Google Identity Services button.
///
/// Kept behind a conditional export (see `google_signin_web_button.dart`) so
/// that `package:google_sign_in_web` — which pulls in `dart:ui_web` — never
/// gets compiled into the Android build. Callers must gate on `kIsWeb`
/// before invoking [renderGoogleSignInButton]; this stub only exists to
/// satisfy the shared import surface on non-web platforms and must never
/// actually run.
Widget renderGoogleSignInButton() {
  throw UnsupportedError(
      'renderGoogleSignInButton is web-only. Callers must check kIsWeb.');
}
