import 'dart:math' as math;

import 'package:flutter/material.dart';

class AircraftCompassRing extends StatelessWidget {
  final double? heading;
  final double? headingTarget;
  final double mapRotation;
  final double scale;
  final bool highContrastOnBrightBackground;

  const AircraftCompassRing({
    super.key,
    required this.heading,
    required this.headingTarget,
    required this.mapRotation,
    required this.scale,
    this.highContrastOnBrightBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final ringSize = 170 * scale;
    final baseRotation = mapRotation * (math.pi / 180);
    final currentHeadingAngle = (heading ?? 0) * (math.pi / 180);
    final targetHeadingAngle = (headingTarget ?? 0) * (math.pi / 180);
    final targetArrowAngle = baseRotation + targetHeadingAngle;
    final indicatorHeading = headingTarget ?? heading;
    final headingText = indicatorHeading == null
        ? '--'
        : indicatorHeading.round().toString();
    final headingLineColor = highContrastOnBrightBackground
        ? const Color(0xFF8B2C00)
        : Colors.deepOrange;
    final headingLineGlow = highContrastOnBrightBackground
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.deepOrange.withValues(alpha: 0.8);
    final targetArrowColor = highContrastOnBrightBackground
        ? const Color(0xFF174E8C)
        : Colors.cyanAccent;
    final headingBadgeBackground = highContrastOnBrightBackground
        ? Colors.white.withValues(alpha: 0.86)
        : Colors.black.withValues(alpha: 0.55);
    final headingBadgeBorder = highContrastOnBrightBackground
        ? Colors.black26
        : Colors.white24;
    final headingTextColor = highContrastOnBrightBackground
        ? const Color(0xFF8B2C00)
        : Colors.orangeAccent;

    return IgnorePointer(
      child: SizedBox(
        width: ringSize,
        height: ringSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: baseRotation,
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(ringSize, ringSize),
                    painter: _AircraftCompassRingPainter(
                      scale: scale,
                      highContrastOnBrightBackground:
                          highContrastOnBrightBackground,
                    ),
                  ),
                  Transform.rotate(
                    angle: currentHeadingAngle,
                    child: SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 2.2 * scale,
                          height: ringSize * 0.36,
                          decoration: BoxDecoration(
                            color: headingLineColor,
                            borderRadius: BorderRadius.circular(2 * scale),
                            boxShadow: [
                              BoxShadow(
                                color: headingLineGlow,
                                blurRadius: 12 * scale,
                                spreadRadius: 2 * scale,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Transform.rotate(
              angle: headingTarget == null ? 0 : targetArrowAngle,
              child: SizedBox(
                width: ringSize,
                height: ringSize,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: Offset(0, -10 * scale),
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: targetArrowColor,
                      size: 22 * scale,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8 * scale,
                vertical: 3 * scale,
              ),
              decoration: BoxDecoration(
                color: headingBadgeBackground,
                borderRadius: BorderRadius.circular(8 * scale),
                border: Border.all(color: headingBadgeBorder),
              ),
              child: Text(
                '$headingText°',
                style: TextStyle(
                  color: headingTextColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 11 * scale,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AircraftCompassRingPainter extends CustomPainter {
  final double scale;
  final bool highContrastOnBrightBackground;

  const _AircraftCompassRingPainter({
    required this.scale,
    required this.highContrastOnBrightBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final ringColor = highContrastOnBrightBackground
        ? Colors.black45
        : Colors.white24;
    final cardinalColor = highContrastOnBrightBackground
        ? const Color(0xFF8B2C00)
        : Colors.orangeAccent;
    final majorTickColor = highContrastOnBrightBackground
        ? Colors.black87
        : Colors.white70;
    final minorTickColor = highContrastOnBrightBackground
        ? Colors.black54
        : Colors.white38;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scale
      ..color = ringColor;
    canvas.drawCircle(center, radius - 1.5 * scale, ringPaint);

    for (var deg = 0; deg < 360; deg += 5) {
      final isMajor = deg % 30 == 0;
      final isMedium = deg % 10 == 0;
      final isCardinal = deg % 90 == 0;
      final tickLength = isMajor
          ? 13 * scale
          : (isMedium ? 8 * scale : 5 * scale);
      final angle = (deg - 90) * (math.pi / 180);
      final startRadius = radius - 6 * scale;
      final endRadius = startRadius - tickLength;
      final start = Offset(
        center.dx + math.cos(angle) * startRadius,
        center.dy + math.sin(angle) * startRadius,
      );
      final end = Offset(
        center.dx + math.cos(angle) * endRadius,
        center.dy + math.sin(angle) * endRadius,
      );
      final tickPaint = Paint()
        ..color = isCardinal
            ? cardinalColor
            : (isMajor ? majorTickColor : minorTickColor)
        ..strokeWidth = isMajor ? 1.8 * scale : 1.1 * scale
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, tickPaint);

      if (isMajor) {
        final label = switch (deg) {
          0 => 'N',
          90 => 'E',
          180 => 'S',
          270 => 'W',
          _ => deg.toString().padLeft(3, '0'),
        };
        final textStyle = TextStyle(
          color: isCardinal ? cardinalColor : majorTickColor,
          fontSize: isCardinal ? 11 * scale : 8 * scale,
          fontWeight: isCardinal ? FontWeight.w800 : FontWeight.w600,
        );
        final textPainter = TextPainter(
          text: TextSpan(text: label, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final textRadius = radius - 24 * scale;
        final textOffset = Offset(
          center.dx + math.cos(angle) * textRadius - textPainter.width / 2,
          center.dy + math.sin(angle) * textRadius - textPainter.height / 2,
        );
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AircraftCompassRingPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.highContrastOnBrightBackground !=
            highContrastOnBrightBackground;
  }
}
