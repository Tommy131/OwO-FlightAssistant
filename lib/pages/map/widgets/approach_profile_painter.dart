import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 进近剖面图 Painter
class ApproachProfilePainter extends CustomPainter {
  final double altitude;
  final double distToRwy;

  const ApproachProfilePainter({
    required this.altitude,
    required this.distToRwy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final gsPath = ui.Path();
    gsPath.moveTo(size.width, size.height - 10);
    gsPath.lineTo(0, size.height - 10 - (size.width * 0.3));
    canvas.drawPath(gsPath, paint);

    final aircraftX = (distToRwy / 20 * size.width).clamp(0.0, size.width);
    final aircraftY =
        (size.height - 10 - (altitude / 5000 * size.height)).clamp(0.0, size.height);

    final planePaint = Paint()..color = Colors.orangeAccent;
    canvas.drawCircle(Offset(aircraftX, aircraftY), 3.5, planePaint);

    final groundPaint = Paint()..color = Colors.white.withValues(alpha: 0.24);
    canvas.drawLine(
      Offset(0, size.height - 5),
      Offset(size.width, size.height - 5),
      groundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
