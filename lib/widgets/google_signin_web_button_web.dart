import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

/// Renders the official Google Identity Services (GIS) sign-in button.
///
/// This is the plugin-supported web sign-in entry point. `GoogleSignIn.
/// signIn()` is deprecated on web and can only synthesize a profile via the
/// People API (no `idToken`, and it warns in the console that it will be
/// removed). A successful click here populates the GIS SDK's last
/// credential response, which is exactly what lets `signInSilently()`
/// restore the session on the next page load without touching the People
/// API at all.
Widget renderGoogleSignInButton() {
  return gsi_web.renderButton(
    // Note: GSIButtonConfiguration's constructor is not const (it runs an
    // assert on minimumWidth), so this cannot be a const invocation.
    configuration: gsi_web.GSIButtonConfiguration(
      theme: gsi_web.GSIButtonTheme.filledBlack,
      size: gsi_web.GSIButtonSize.large,
      text: gsi_web.GSIButtonText.signinWith,
      shape: gsi_web.GSIButtonShape.pill,
      locale: 'fa',
      minimumWidth: 240,
    ),
  );
}
