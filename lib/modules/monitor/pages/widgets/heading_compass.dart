import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 磁航向罗盘 Widget
///
/// 根据传入的 [heading] 值，通过 [CompassPainter] 自定义绘制一个旋转罗盘：
/// - 罗盘刻度盘随 [heading] 变化反向旋转，使飞机图标始终指向屏幕上方
/// - 主要方位（N/E/S/W）以橙色高亮显示
/// - 飞机符号固定在罗盘中心，不随刻度盘旋转
/// - 顶部橙色三角形指针始终固定朝上，指示当前航向方向
class HeadingCompass extends StatelessWidget {
  /// 当前磁航向（单位：度，0–360）
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

/// 罗盘自定义绘制器
///
/// 使用 [Canvas] 直接绘制：
/// 1. 外圈刻度环（透明圆弧）
/// 2. 每 10° 一个刻度线，每 30° 一个长刻度线并附标签
/// 3. 固定在中心的飞机形状
/// 4. 顶部橙色三角指针
class CompassPainter extends CustomPainter {
  /// 当前磁航向（度）
  final double heading;

  /// 主题颜色（用于刻度线、飞机图形）
  final Color color;

  CompassPainter({required this.heading, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // 绘制外圈轮廓（透明描边圆）
    final outerCirclePaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, outerCirclePaint);

    // 保存画布状态，将坐标原点移至圆心，并反向旋转（刻度盘跟随航向转动）
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * math.pi / 180);

    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 绘制 0°~350° 的刻度线（每 10° 一条）
    for (int i = 0; i < 360; i += 10) {
      final angle = i * math.pi / 180;
      // 每 30° 为主刻度（长线 + 文字标签），其余为次刻度（短线）
      final isMajor = i % 30 == 0;
      final tickLength = isMajor ? 15.0 : 8.0;

      final start = Offset(
        math.sin(angle) * (radius - tickLength),
        -math.cos(angle) * (radius - tickLength),
      );
      final end = Offset(math.sin(angle) * radius, -math.cos(angle) * radius);

      canvas.drawLine(start, end, tickPaint..strokeWidth = isMajor ? 2 : 1);

      // 主刻度绘制文字标签（N/E/S/W 及数字）
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

        // 方位字母使用橙色，其余使用主题色
        textPainter.text = TextSpan(
          text: label,
          style: TextStyle(
            color: (label == 'N' || label == 'E' || label == 'S' || label == 'W')
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

        // 保存子画布状态：将文字旋转回来，抵消刻度盘旋转，使文字始终正向可读
        canvas.save();
        canvas.translate(
          textOffset.dx + textPainter.width / 2,
          textOffset.dy + textPainter.height / 2,
        );
        canvas.rotate(i * math.pi / 180);
        canvas.rotate(heading * math.pi / 180);
        canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    // 恢复画布（退出刻度盘旋转坐标系）
    canvas.restore();

    // 绘制固定中心飞机图形（不随刻度盘旋转，始终指向上方）
    final airplanePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx, center.dy - 20); // 机头
    path.lineTo(center.dx - 15, center.dy + 10); // 左机翼
    path.lineTo(center.dx - 3, center.dy + 5);
    path.lineTo(center.dx - 5, center.dy + 15); // 左尾翼
    path.lineTo(center.dx, center.dy + 12);
    path.lineTo(center.dx + 5, center.dy + 15); // 右尾翼
    path.lineTo(center.dx + 3, center.dy + 5);
    path.lineTo(center.dx + 15, center.dy + 10); // 右机翼
    path.close();
    canvas.drawPath(path, airplanePaint);

    // 绘制顶部橙色三角形航向指针
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
