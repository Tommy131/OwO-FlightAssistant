import 'dart:math' as math;
import 'package:flutter/material.dart';

class AircraftCompass extends StatelessWidget {
  final double heading;
  final double scale;

  const AircraftCompass({
    super.key,
    required this.heading,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(200 * scale, 200 * scale),
        painter: _CompassPainter(heading: heading, scale: scale),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double heading;
  final double scale;

  _CompassPainter({required this.heading, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;

    // Draw main circle
    canvas.drawCircle(center, radius, paint);

    // Draw heading ticks and labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < 360; i += 10) {
      final angle = (i - 90) * math.pi / 180;
      final isMajor = i % 30 == 0;
      final tickLength = isMajor ? 10.0 * scale : 5.0 * scale;

      final start = Offset(
        center.dx + (radius - tickLength) * math.cos(angle),
        center.dy + (radius - tickLength) * math.sin(angle),
      );
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      canvas.drawLine(start, end, paint..color = Colors.blueAccent.withValues(alpha: 0.5));

      if (isMajor) {
        String label = i.toString();
        if (i == 0) label = 'N';
        else if (i == 90) label = 'E';
        else if (i == 180) label = 'S';
        else if (i == 270) label = 'W';
        else label = (i ~/ 10).toString();

        textPainter.text = TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.blueAccent,
            fontSize: 10 * scale,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        
        final textPos = Offset(
          center.dx + (radius - tickLength - 12 * scale) * math.cos(angle) - textPainter.width / 2,
          center.dy + (radius - tickLength - 12 * scale) * math.sin(angle) - textPainter.height / 2,
        );
        textPainter.paint(canvas, textPos);
      }
    }

    // Draw heading line with a gradient or glow
    final headingAngle = (heading - 90) * math.pi / 180;
    final headingEnd = Offset(
      center.dx + radius * math.cos(headingAngle),
      center.dy + radius * math.sin(headingAngle),
    );
    
    // Heading line shadow/glow
    canvas.drawLine(
      center,
      headingEnd,
      Paint()
        ..color = Colors.orangeAccent.withValues(alpha: 0.3)
        ..strokeWidth = 6 * scale
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawLine(
      center,
      headingEnd,
      Paint()
        ..color = Colors.orangeAccent
        ..strokeWidth = 2 * scale
        ..strokeCap = StrokeCap.round,
    );

    // Draw a small center circle
    canvas.drawCircle(
      center,
      4 * scale,
      Paint()..color = Colors.orangeAccent,
    );
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) {
    return oldDelegate.heading != heading || oldDelegate.scale != scale;
  }
}
