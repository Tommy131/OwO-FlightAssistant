import 'dart:math' as math;

import 'package:flutter/material.dart';

class AircraftMarker extends StatelessWidget {
  final double? heading;
  final bool isDark;
  final bool highContrastOnBrightBackground;

  const AircraftMarker({
    super.key,
    this.heading,
    required this.isDark,
    this.highContrastOnBrightBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final angle = (heading ?? 0) * (math.pi / 180);
    final markerColor = highContrastOnBrightBackground
        ? Colors.black
        : (isDark ? Colors.black : Colors.white);
    final borderColor = highContrastOnBrightBackground
        ? Colors.white70
        : (isDark ? Colors.white24 : Colors.black12);
    final glyphColor = highContrastOnBrightBackground
        ? Colors.lightBlueAccent
        : Colors.blue;
    return Transform.rotate(
      angle: angle,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: markerColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 7,
            ),
          ],
        ),
        child: _AircraftGlyph(color: glyphColor),
      ),
    );
  }
}

class _AircraftGlyph extends StatelessWidget {
  final Color color;

  const _AircraftGlyph({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _AircraftGlyphPainter(color: color),
    );
  }
}

class _AircraftGlyphPainter extends CustomPainter {
  final Color color;

  const _AircraftGlyphPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
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
  bool shouldRepaint(covariant _AircraftGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
