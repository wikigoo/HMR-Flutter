import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Circular HMR robot mascot with a neon gradient ring + soft cyan glow.
/// Shared by the app bar, AI bubbles and the typing indicator.
class HmrAvatar extends StatelessWidget {
  const HmrAvatar({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    final double inset = size >= 38 ? 2 : 1.5;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(inset),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.neon,
        boxShadow: AppTheme.ringGlow,
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          // Solid dark-navy core. The neon ring separates the orb from the
          // page so the logo reads cleanly against the app background.
          color: AppTheme.avatarCore,
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: Image.asset(
            'assets/images/hmr-avatar.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
