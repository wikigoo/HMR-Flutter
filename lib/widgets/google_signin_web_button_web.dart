import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

/// Renders the official Google Identity Services (GIS) sign-in button.
///
/// This is the only supported web sign-in entry point in google_sign_in v7+:
/// `GoogleSignIn.authenticate()` throws `UnimplementedError` on web
/// (`supportsAuthenticate()` is always false there). A click on this button
/// is handled entirely by the GIS SDK outside Flutter's widget tree; success
/// surfaces through `GoogleSignIn.instance.authenticationEvents`, which
/// `AuthProvider` subscribes to as its single source of truth for the signed
/// in user.
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
