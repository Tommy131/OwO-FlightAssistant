import 'dart:math' as math;

import 'package:flutter/material.dart';

class AircraftCompassRing extends StatelessWidget {
  final double? heading;
  final double? headingTarget;
  final double mapRotation;
  final double scale;

  const AircraftCompassRing({
    super.key,
    required this.heading,
    required this.headingTarget,
    required this.mapRotation,
    required this.scale,
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
                    painter: _AircraftCompassRingPainter(scale: scale),
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
                            color: Colors.deepOrange,
                            borderRadius: BorderRadius.circular(2 * scale),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepOrange.withValues(alpha: 0.8),
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
                      color: Colors.cyanAccent,
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
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8 * scale),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                '$headingText°',
                style: TextStyle(
                  color: Colors.orangeAccent,
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

  const _AircraftCompassRingPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scale
      ..color = Colors.white24;
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
            ? Colors.orangeAccent
            : (isMajor ? Colors.white70 : Colors.white38)
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
          color: isCardinal ? Colors.orangeAccent : Colors.white70,
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
    return oldDelegate.scale != scale;
  }
}
