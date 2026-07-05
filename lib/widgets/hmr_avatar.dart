import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The HMR robot mark set in the brand's gradient ring over a dark core, with a
/// soft cyan glow — matches the design-system Avatar. One widget for every
/// placement (app bar, AI bubble, hero, login). `glow` can be turned off where a
/// placement wants a flat mark.
class HmrAvatar extends StatelessWidget {
  const HmrAvatar({super.key, this.size = 30, this.glow = true});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final double pad = size > 60 ? 3 : 1.5;
    final double blur = size > 60 ? 34 : 16;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppTheme.cyan, AppTheme.blue],
        ),
        boxShadow: glow
            ? <BoxShadow>[BoxShadow(color: AppTheme.glow, blurRadius: blur)]
            : null,
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.avatarCore,
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(size * 0.11),
          child: Image.asset('assets/images/hmr-mark.png', fit: BoxFit.contain),
        ),
      ),
    );
  }
}
