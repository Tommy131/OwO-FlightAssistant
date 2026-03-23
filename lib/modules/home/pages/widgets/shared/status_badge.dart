import 'package:flutter/material.dart';

/// 状态徽章组件，用于在系统状态面板中展示带颜色圆点的状态标签
class StatusBadge extends StatelessWidget {
  /// 状态文本
  final String label;

  /// 状态主题色（决定背景、边框、圆点颜色）
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLightColor = color.computeLuminance() > 0.8;
    final textColor = isLightColor ? (isDark ? color : Colors.black87) : color;
    final borderColor = isLightColor
        ? (isDark ? color.withValues(alpha: 0.5) : Colors.black45)
        : color.withValues(alpha: 0.3);
    final dotColor = color;
    final backgroundColor = isLightColor
        ? (isDark ? color.withValues(alpha: 0.2) : Colors.black12)
        : color.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 彩色状态圆点
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: isLightColor
                  ? Border.all(color: Colors.black26, width: 0.5)
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
