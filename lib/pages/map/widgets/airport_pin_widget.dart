import 'package:flutter/material.dart';

/// 可复用的机场图钉组件
class AirportPinWidget extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isBig;
  final double scale;

  const AirportPinWidget({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    this.isBig = false,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final size = isBig ? 36.0 : 28.0;
    final labelFontSize = isBig ? 11.0 : 9.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 4 * scale,
            vertical: 2 * scale,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4 * scale),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: labelFontSize * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 2 * scale),
        Icon(
          icon,
          color: color,
          size: size * scale,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8),
          ],
        ),
      ],
    );
  }
}
