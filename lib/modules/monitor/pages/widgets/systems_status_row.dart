import 'package:flutter/material.dart';

/// 系统状态单行组件
///
/// 用于在 [SystemsStatusCard] 中展示单项系统状态，
/// 左侧为状态标签名称，右侧为带色块背景的数值徽章。
///
/// 支持通过 [isHighlight] 和 [highlightColor] 控制告警着色：
/// - 普通状态：蓝色调（[Colors.blueAccent]）
/// - 告警状态：使用传入的 [highlightColor]
class SystemsStatusRow extends StatelessWidget {
  /// 状态项名称（左侧文字）
  final String label;

  /// 当前状态值（右侧徽章文字）
  final String value;

  /// 是否高亮显示（表示该状态处于告警或特殊状态）
  final bool isHighlight;

  /// 高亮时使用的颜色
  final Color highlightColor;

  const SystemsStatusRow({
    super.key,
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.highlightColor = Colors.orangeAccent,
  });

  @override
  Widget build(BuildContext context) {
    // 根据是否高亮选择显示颜色
    final displayColor = isHighlight ? highlightColor : Colors.blueAccent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 左侧：状态标签（次要文字样式，低透明度）
        Text(
          label,
          style: TextStyle(
            color:
                Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
                Colors.grey,
            fontSize: 13,
          ),
        ),

        // 右侧：状态数值徽章（等宽字体，带圆角色块背景）
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: displayColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: displayColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'Monospace',
            ),
          ),
        ),
      ],
    );
  }
}
