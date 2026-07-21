import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/google_mark.dart';
import '../widgets/hmr_avatar.dart';
import '../widgets/hmr_background.dart';

/// First-launch welcome panel — the design system's "Login" screen.
///
/// Deliberately **not** an auth gate. Login is optional in HMR (chat works
/// anonymously), so this screen is shown once, both buttons lead into the app,
/// and a failed Google sign-in still continues as a guest rather than trapping
/// the user behind a door that will not open.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onDone});

  /// Called once the user has chosen a path — signed in, or continuing as guest.
  final VoidCallback onDone;

  Future<void> _google(BuildContext context) async {
    final AuthProvider auth = context.read<AuthProvider>();
    await auth.signInWithGoogle();
    // Success or failure, the user still gets in — sign-in is optional and a
    // hard failure here must never be a dead end.
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = context.watch<AuthProvider>().isLoading;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          const HmrBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(26, 34, 26, 26),
                    decoration: BoxDecoration(
                      color: AppTheme.glassFill,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppTheme.glassBorder, width: 0.8),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x59000000),
                          blurRadius: 40,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const HmrAvatar(size: 88),
                        const SizedBox(height: 22),
                        const Text('HMR', style: AppTheme.display),
                        const SizedBox(height: 10),
                        const Text(
                          AppStrings.welcomePanelBody,
                          textAlign: TextAlign.center,
                          style: AppTheme.welcomeBody,
                        ),
                        const SizedBox(height: 28),
                        _GoogleButton(
                          busy: busy,
                          onTap: busy ? null : () => _google(context),
                        ),
                        const SizedBox(height: 12),
                        _GuestButton(onTap: busy ? null : onDone),
                        const SizedBox(height: 18),
                        const Text(
                          AppStrings.welcomeTerms,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFa, fontFamilyFallback: AppTheme.faFallback,
                            fontSize: 11,
                            height: 1.7,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White pill with the official four-colour Google mark.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.signInWithGoogle,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.googleFill,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6)),
            ],
          ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.googleText),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const GoogleMark(size: 20),
                    const SizedBox(width: 12),
                    Text(
                      AppStrings.signInWithGoogle,
                      style: AppTheme.ctaLabel.copyWith(color: AppTheme.googleText),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Ghost pill — "continue as guest".
class _GuestButton extends StatelessWidget {
  const _GuestButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.continueAsGuest,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.inputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.chipBorder, width: 1),
          ),
          child: const Text(
            AppStrings.continueAsGuest,
            style: TextStyle(
              fontFamily: AppTheme.fontFa, fontFamilyFallback: AppTheme.faFallback,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.chipText,
            ),
          ),
        ),
      ),
    );
  }
}

// The Google "G" now lives in widgets/google_mark.dart (shared with the sidebar).
