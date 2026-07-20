import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The shared HMR backdrop: a navy radial gradient base with three blurred
/// ambient glow blobs (cyan / indigo / blue). Drop it as the first child of
/// a Stack so glass chrome reads consistently across all screens.
class HmrBackground extends StatelessWidget {
  const HmrBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: AppTheme.background),
      child: Stack(
        children: <Widget>[
          _GlowBlob(top: -90, right: -70, size: 300, color: AppTheme.cyan, opacity: 0x38),
          _GlowBlob(bottom: 120, left: -90, size: 320, color: AppTheme.indigo, opacity: 0x38),
          _GlowBlob(top: 360, left: 180, size: 240, color: AppTheme.blue, opacity: 0x1A),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.size,
    required this.color,
    required this.opacity,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  final double size;
  final Color color;
  final int opacity;
  final double? top, left, right, bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  color.withAlpha(opacity),
                  const Color(0x00000000),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
