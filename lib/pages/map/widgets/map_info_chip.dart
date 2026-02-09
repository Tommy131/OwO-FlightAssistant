import 'package:flutter/material.dart';

/// 顶部信息行中的图标+文案小标签
class MapInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double scale;

  const MapInfoChip({
    super.key,
    required this.icon,
    required this.label,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 4 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 12 * scale),
          SizedBox(width: 4 * scale),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
