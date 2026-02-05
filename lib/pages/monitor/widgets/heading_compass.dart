import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 高度还原指南针仪表效果
class HeadingCompass extends StatelessWidget {
  final double heading;

  const HeadingCompass({super.key, required this.heading});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CompassPainter(
        heading: heading,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class CompassPainter extends CustomPainter {
  final double heading;
  final Color color;

  CompassPainter({required this.heading, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // 绘制外圈
    final outerCirclePaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, outerCirclePaint);

    // 旋转画布以适应航向
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * math.pi / 180);

    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 绘制刻度
    for (int i = 0; i < 360; i += 10) {
      final angle = i * math.pi / 180;
      final isMajor = i % 30 == 0;
      final tickLength = isMajor ? 15.0 : 8.0;

      final start = Offset(
        math.sin(angle) * (radius - tickLength),
        -math.cos(angle) * (radius - tickLength),
      );
      final end = Offset(math.sin(angle) * radius, -math.cos(angle) * radius);

      canvas.drawLine(start, end, tickPaint..strokeWidth = isMajor ? 2 : 1);

      if (isMajor) {
        String label = i == 0
            ? 'N'
            : i == 90
            ? 'E'
            : i == 180
            ? 'S'
            : i == 270
            ? 'W'
            : (i ~/ 10).toString();
        textPainter.text = TextSpan(
          text: label,
          style: TextStyle(
            color:
                (label == 'N' || label == 'E' || label == 'S' || label == 'W')
                ? Colors.orangeAccent
                : color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();

        final textOffset = Offset(
          math.sin(angle) * (radius - 35) - textPainter.width / 2,
          -math.cos(angle) * (radius - 35) - textPainter.height / 2,
        );

        // 保持文字正向 (相对于仪表) - 这里我们先平移回正再画或者简单点
        canvas.save();
        canvas.translate(
          textOffset.dx + textPainter.width / 2,
          textOffset.dy + textPainter.height / 2,
        );
        canvas.rotate(
          i * math.pi / 180,
        ); // 抵消外层旋转+自身角度使文字始终垂直于圆心向外？不，航空仪表文字通常是正的。
        canvas.rotate(heading * math.pi / 180); // 抵消全局旋转
        canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    canvas.restore();

    // 绘制中央指示器 (飞机形状)
    final airplanePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx, center.dy - 20); // 鼻
    path.lineTo(center.dx - 15, center.dy + 10); // 左翼末
    path.lineTo(center.dx - 3, center.dy + 5); // 躯干
    path.lineTo(center.dx - 5, center.dy + 15); // 左尾
    path.lineTo(center.dx, center.dy + 12); // 尾
    path.lineTo(center.dx + 5, center.dy + 15); // 右尾
    path.lineTo(center.dx + 3, center.dy + 5); // 躯干
    path.lineTo(center.dx + 15, center.dy + 10); // 右翼末
    path.close();

    canvas.drawPath(path, airplanePaint);

    // 绘制顶部的航向指示标
    final topPointerPaint = Paint()..color = Colors.orangeAccent;
    final pointerPath = Path();
    pointerPath.moveTo(center.dx, center.dy - radius - 5);
    pointerPath.lineTo(center.dx - 8, center.dy - radius - 20);
    pointerPath.lineTo(center.dx + 8, center.dy - radius - 20);
    pointerPath.close();
    canvas.drawPath(pointerPath, topPointerPaint);
  }

  @override
  bool shouldRepaint(covariant CompassPainter oldDelegate) =>
      oldDelegate.heading != heading;
}
