import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The HMR robot mark on a flat dark disc with a thin cyan hairline and a subtle
/// glow — the redesigned avatar (no gradient ring). One widget for every
/// placement (app bar, AI bubble, hero, login). `glow` can be turned off where a
/// placement wants a completely flat mark.
class HmrAvatar extends StatelessWidget {
  const HmrAvatar({super.key, this.size = 30, this.glow = true});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final double blur = size > 60 ? 30 : 13;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.avatarDisc,
        border: Border.all(color: AppTheme.avatarHairline, width: 1),
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(color: AppTheme.avatarGlow, blurRadius: blur),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.09),
        child: Image.asset('assets/images/hmr-mark.png', fit: BoxFit.contain),
      ),
    );
  }
}
