import 'package:flutter/material.dart';

/// 地图上的通用按钮组件
/// - 支持高亮状态、提示文本、迷你尺寸
class MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool highlight;
  final String? tooltip;
  final bool mini;
  final double scale;

  const MapButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.highlight = false,
    this.tooltip,
    this.mini = false,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final btnSize = (mini ? 40.0 : 48.0) * scale;
    return Container(
      width: btnSize,
      height: btnSize,
      decoration: BoxDecoration(
        color: highlight ? Colors.orangeAccent : Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular((mini ? 10 : 12) * scale),
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: highlight ? Colors.black : Colors.white,
          size: (mini ? 18 : 20) * scale,
        ),
        padding: mini ? EdgeInsets.zero : const EdgeInsets.all(8.0),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
