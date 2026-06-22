import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-screen dark glassmorphism background shared by all screens.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppTheme.background),
          child: SizedBox.expand(),
        ),
        _blob(top: -90, right: -70, size: 300, color: AppTheme.cyan, opacity: 0x38),
        _blob(bottom: 120, left: -90, size: 320, color: AppTheme.indigo, opacity: 0x38),
        _blob(top: 360, left: 180, size: 240, color: AppTheme.blue, opacity: 0x1A),
        child,
      ],
    );
  }

  static Widget _blob({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    required Color color,
    required int opacity,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[color.withAlpha(opacity), const Color(0x00000000)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
