import 'package:flutter/material.dart';

/// 可复用的过滤切换按钮组件
class FilterToggleButton extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final Color? inactiveColor;
  final double scale;

  const FilterToggleButton({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.activeColor = Colors.orangeAccent,
    this.inactiveColor,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 4 * scale,
        ),
        decoration: BoxDecoration(
          color: value
              ? activeColor.withValues(alpha: 0.2)
              : (inactiveColor?.withValues(alpha: 0.2) ?? Colors.black54),
          borderRadius: BorderRadius.circular(16 * scale),
          border: Border.all(
            color: value ? activeColor : (inactiveColor ?? Colors.white24),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value) ...[
              SizedBox(width: 4 * scale),
              Icon(Icons.check, size: 12 * scale, color: activeColor),
            ],
            SizedBox(width: (value || inactiveColor != null) ? 4 * scale : 0),
            Text(
              label,
              style: TextStyle(
                color: (value || inactiveColor != null)
                    ? Colors.white
                    : Colors.white70,
                fontSize: 10 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
