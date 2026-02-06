import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 风向可视化组件（罗盘指示器）
class WindDirectionIndicator extends StatelessWidget {
  final double? windDirection; // 风向（度数）
  final double? windSpeed; // 风速（kt）
  final double size;
  final bool showLabel;

  const WindDirectionIndicator({
    super.key,
    required this.windDirection,
    required this.windSpeed,
    this.size = 120,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _WindCompassPainter(
              windDirection: windDirection,
              windSpeed: windSpeed,
              primaryColor: theme.colorScheme.primary,
              surfaceColor: theme.colorScheme.surface,
              outlineColor: theme.colorScheme.outline,
            ),
          ),
        ),
        if (showLabel && windDirection != null && windSpeed != null) ...[
          const SizedBox(height: 8),
          Text(
            '${windDirection!.toStringAsFixed(0)}° / ${windSpeed!.toStringAsFixed(0)} kt',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ] else if (showLabel) ...[
          const SizedBox(height: 8),
          Text(
            '无风向数据',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }
}

class _WindCompassPainter extends CustomPainter {
  final double? windDirection;
  final double? windSpeed;
  final Color primaryColor;
  final Color surfaceColor;
  final Color outlineColor;

  _WindCompassPainter({
    required this.windDirection,
    required this.windSpeed,
    required this.primaryColor,
    required this.surfaceColor,
    required this.outlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Draw compass circle
    final compassPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, compassPaint);

    // Draw compass border
    final borderPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw cardinal directions
    _drawCardinalDirections(canvas, center, radius);

    // Draw wind arrow if data available
    if (windDirection != null && windSpeed != null) {
      _drawWindArrow(canvas, center, radius);
    }
  }

  void _drawCardinalDirections(Canvas canvas, Offset center, double radius) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    final directions = [
      {'label': 'N', 'angle': 0.0},
      {'label': 'E', 'angle': 90.0},
      {'label': 'S', 'angle': 180.0},
      {'label': 'W', 'angle': 270.0},
    ];

    for (final dir in directions) {
      final angle = (dir['angle'] as double) * math.pi / 180;
      final x = center.dx + (radius - 20) * math.sin(angle);
      final y = center.dy - (radius - 20) * math.cos(angle);

      textPainter.text = TextSpan(
        text: dir['label'] as String,
        style: TextStyle(
          color: outlineColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  void _drawWindArrow(Canvas canvas, Offset center, double radius) {
    // Wind direction is "from" direction, so we need to point to opposite
    final angleRad = (windDirection! + 180) * math.pi / 180;

    // Arrow length based on wind speed (normalized)
    final maxLength = radius * 0.7;
    final speedNormalized = (windSpeed! / 50).clamp(0.3, 1.0);
    final arrowLength = maxLength * speedNormalized;

    // Arrow end point
    final endX = center.dx + arrowLength * math.sin(angleRad);
    final endY = center.dy - arrowLength * math.cos(angleRad);

    // Draw arrow shaft
    final arrowPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, Offset(endX, endY), arrowPaint);

    // Draw arrowhead
    final arrowHeadLength = 12.0;
    final arrowHeadAngle = 25 * math.pi / 180;

    final leftX = endX - arrowHeadLength * math.sin(angleRad - arrowHeadAngle);
    final leftY = endY + arrowHeadLength * math.cos(angleRad - arrowHeadAngle);

    final rightX = endX - arrowHeadLength * math.sin(angleRad + arrowHeadAngle);
    final rightY = endY + arrowHeadLength * math.cos(angleRad + arrowHeadAngle);

    final arrowHeadPath = Path()
      ..moveTo(leftX, leftY)
      ..lineTo(endX, endY)
      ..lineTo(rightX, rightY);

    canvas.drawPath(arrowHeadPath, arrowPaint);

    // Draw center circle
    final centerPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerPaint);
  }

  @override
  bool shouldRepaint(_WindCompassPainter oldDelegate) {
    return oldDelegate.windDirection != windDirection ||
        oldDelegate.windSpeed != windSpeed ||
        oldDelegate.primaryColor != primaryColor;
  }
}
