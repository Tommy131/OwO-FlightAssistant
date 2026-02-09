import 'package:flutter/material.dart';

/// 地图文字标签
class MapLabel extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color bgColor;
  final double fontSize;

  const MapLabel({
    super.key,
    required this.text,
    required this.textColor,
    required this.bgColor,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: textColor.withValues(alpha: 0.4), width: 1),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// 机场针脚标记（带标签和图标）
class AirportPin extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isBig;

  const AirportPin({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    this.isBig = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MapLabel(
          text: label,
          textColor: Colors.white,
          bgColor: Colors.black.withValues(alpha: 0.7),
          fontSize: isBig ? 12 : 10,
        ),
        Icon(
          icon,
          size: isBig ? 40 : 30,
          color: color,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 10)],
        ),
      ],
    );
  }
}
