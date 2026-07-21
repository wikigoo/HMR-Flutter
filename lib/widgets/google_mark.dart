import 'package:flutter/material.dart';

/// The Google "G" drawn as flat paths, matching the design system's approach of
/// not shipping an external asset for it. Reused by the welcome screen and the
/// sidebar's sign-in button.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _GooglePainter()),
      );
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
