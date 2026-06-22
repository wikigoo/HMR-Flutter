import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/conversations_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/hmr_avatar.dart';
import '../widgets/app_background.dart';
import 'conversations_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy950,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(height: 16),
                  const HmrAvatar(size: 88),
                  const SizedBox(height: 20),
                  const Text('HMR', style: AppTheme.appTitle),
                  const SizedBox(height: 6),
                  const Text(
                    'مشاور هوشمند موبایل',
                    style: AppTheme.subtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 64),
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'خوش آمدید',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFa,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'برای ورود، حساب Google خود را انتخاب کنید',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFa,
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _GoogleSignInButton(
                          onSuccess: (context) async {
                            await context
                                .read<ConversationsProvider>()
                                .loadConversations();
                            if (!context.mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ConversationsScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _ErrorText(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          decoration: BoxDecoration(
            color: AppTheme.glassFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.glassBorder, width: 0.8),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onSuccess});

  final void Function(BuildContext context) onSuccess;

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: auth.isLoading
            ? null
            : () async {
                final bool ok = await auth.signInWithGoogle();
                if (ok && context.mounted) onSuccess(context);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          disabledBackgroundColor: const Color(0xFFE0E0E0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: auth.isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppTheme.blue,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _GoogleG(),
                  const SizedBox(width: 12),
                  const Text(
                    'ورود با Google',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFa,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF4285F4),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          height: 1,
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final String? error = context.watch<AuthProvider>().error;
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        error,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppTheme.fontFa,
          fontSize: 12,
          color: Color(0xFFFF8597),
        ),
      ),
    );
  }
}
