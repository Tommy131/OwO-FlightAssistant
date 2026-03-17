import 'package:flutter/material.dart';

class ApproachRuleBadge extends StatelessWidget {
  final double scale;
  final String label;
  final bool isDark;

  const ApproachRuleBadge({
    super.key,
    required this.scale,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = label.toUpperCase();
    final color = switch (normalized) {
      'VFR' => const Color(0xFF35D07F),
      'MVFR' => const Color(0xFF4DB7FF),
      'IFR' => const Color(0xFFFFA63D),
      'LIFR' => const Color(0xFFFF5C6A),
      _ => isDark ? Colors.white70 : Colors.black54,
    };
    final icon = switch (normalized) {
      'VFR' => Icons.wb_sunny_rounded,
      'MVFR' => Icons.cloud_queue_rounded,
      'IFR' => Icons.grain_rounded,
      'LIFR' => Icons.thunderstorm_rounded,
      _ => Icons.help_outline_rounded,
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 5 * scale),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.1),
        borderRadius: BorderRadius.circular(9 * scale),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.6 : 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12 * scale),
          SizedBox(width: 4 * scale),
          Text(
            normalized,
            style: TextStyle(
              color: color,
              fontSize: 11 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class SourceBadge extends StatelessWidget {
  final double scale;
  final String label;
  final bool isDark;

  const SourceBadge({
    super.key,
    required this.scale,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 130 * scale),
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 3 * scale),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(7 * scale),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
          fontSize: 10 * scale,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class MetarMiniToggle extends StatelessWidget {
  final double scale;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const MetarMiniToggle({
    super.key,
    required this.scale,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final width = 28 * scale;
    final height = 14 * scale;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        height: height,
        padding: EdgeInsets.all(2 * scale),
        decoration: BoxDecoration(
          color: value
              ? Colors.lightBlueAccent.withValues(alpha: 0.4)
              : (isDark ? Colors.white12 : Colors.black12),
          borderRadius: BorderRadius.circular(height),
          border: Border.all(
            color: value
                ? Colors.lightBlueAccent.withValues(alpha: 0.8)
                : (isDark ? Colors.white30 : Colors.black26),
          ),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 10 * scale,
            height: 10 * scale,
            decoration: BoxDecoration(
              color: value
                  ? Colors.lightBlueAccent
                  : (isDark ? Colors.white60 : Colors.black45),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class AirportMetaItem extends StatelessWidget {
  final double scale;
  final IconData icon;
  final String value;
  final String unit;
  final bool isDark;

  const AirportMetaItem({
    super.key,
    required this.scale,
    required this.icon,
    required this.value,
    required this.unit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12 * scale,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
        SizedBox(width: 4 * scale),
        Text(
          unit.isNotEmpty ? '$value $unit' : value,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 11 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class FrequencyBadge extends StatelessWidget {
  final double scale;
  final String label;
  final bool isDark;

  const FrequencyBadge({
    super.key,
    required this.scale,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 5 * scale),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 10 * scale,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
