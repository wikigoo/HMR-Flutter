import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The HMR robot mark. A clean transparent-PNG logo on the dark UI; an optional
/// soft cyan glow is used only on large hero placements (kept off for the small
/// app-bar / bubble avatars to respect the performance budget).
class HmrAvatar extends StatelessWidget {
  const HmrAvatar({super.key, this.size = 30, this.glow = false});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: glow
          ? const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppTheme.glow,
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: Image.asset(
        'assets/images/hmr-mark.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
