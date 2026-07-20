import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
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
                            fontFamily: AppTheme.fontFa,
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
                    const _GoogleMark(size: 20),
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
              fontFamily: AppTheme.fontFa,
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

/// The Google "G" drawn as flat paths, matching the design system's approach of
/// not shipping an external asset for it.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: size, child: CustomPaint(painter: _GooglePainter()));
}

class _GooglePainter extends CustomPainter {
  static const Color _blue = Color(0xFF4285F4);
  static const Color _green = Color(0xFF34A853);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 20; // paths are authored on a 20×20 grid
    void draw(Color color, Path path) {
      canvas.drawPath(
        path.transform(Matrix4.diagonal3Values(s, s, 1).storage),
        Paint()..color = color,
      );
    }

    draw(_blue, Path()
      ..moveTo(19.6, 10.23)
      ..cubicTo(19.6, 9.55, 19.54, 8.87, 19.42, 8.23)
      ..lineTo(10, 8.23)
      ..lineTo(10, 12.02)
      ..lineTo(15.4, 12.02)
      ..cubicTo(15.17, 13.26, 14.46, 14.31, 13.4, 15.04)
      ..lineTo(13.4, 17.54)
      ..lineTo(16.63, 17.54)
      ..cubicTo(18.53, 15.79, 19.6, 13.22, 19.6, 10.23)
      ..close());

    draw(_green, Path()
      ..moveTo(10, 20)
      ..cubicTo(12.7, 20, 14.97, 19.1, 16.63, 17.56)
      ..lineTo(13.39, 15.06)
      ..cubicTo(12.49, 15.66, 11.34, 16.02, 10, 16.02)
      ..cubicTo(7.4, 16.02, 5.2, 14.26, 4.4, 11.9)
      ..lineTo(1.06, 11.9)
      ..lineTo(1.06, 14.49)
      ..cubicTo(2.71, 17.77, 6.09, 20, 10, 20)
      ..close());

    draw(_yellow, Path()
      ..moveTo(4.4, 11.9)
      ..cubicTo(4.0, 10.66, 4.0, 9.34, 4.4, 8.1)
      ..lineTo(4.4, 5.51)
      ..lineTo(1.06, 5.51)
      ..cubicTo(-0.35, 8.32, -0.35, 11.68, 1.06, 14.49)
      ..lineTo(4.4, 11.9)
      ..close());

    draw(_red, Path()
      ..moveTo(10, 3.98)
      ..cubicTo(11.47, 3.98, 12.79, 4.48, 13.83, 5.48)
      ..lineTo(16.7, 2.61)
      ..cubicTo(14.97, 1.0, 12.7, 0, 10, 0)
      ..cubicTo(6.09, 0, 2.71, 2.23, 1.06, 5.51)
      ..lineTo(4.4, 8.1)
      ..cubicTo(5.2, 5.74, 7.4, 3.98, 10, 3.98)
      ..close());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
