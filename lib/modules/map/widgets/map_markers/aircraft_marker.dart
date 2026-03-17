import 'dart:math' as math;

import 'package:flutter/material.dart';

class AircraftMarker extends StatelessWidget {
  final double? heading;
  final bool isDark;

  const AircraftMarker({super.key, this.heading, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final angle = (heading ?? 0) * (math.pi / 180);
    return Transform.rotate(
      angle: angle,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
            ),
          ],
        ),
        child: const _AircraftGlyph(),
      ),
    );
  }
}

class _AircraftGlyph extends StatelessWidget {
  const _AircraftGlyph();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _AircraftGlyphPainter(),
    );
  }
}

class _AircraftGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..lineTo(w * 0.62, h * 0.42)
      ..lineTo(w * 0.94, h * 0.52)
      ..lineTo(w * 0.6, h * 0.56)
      ..lineTo(w * 0.56, h * 0.96)
      ..lineTo(w * 0.44, h * 0.96)
      ..lineTo(w * 0.4, h * 0.56)
      ..lineTo(w * 0.06, h * 0.52)
      ..lineTo(w * 0.38, h * 0.42)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
