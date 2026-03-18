import 'package:flutter/material.dart';

import '../../../../../core/services/localization_service.dart';
import '../../../models/map_models.dart';

class MapInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double scale;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;
  final Color? textColor;

  const MapInfoChip({
    super.key,
    required this.icon,
    required this.label,
    required this.scale,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 4 * scale,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: borderColor ?? Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor ?? Colors.white54, size: 12 * scale),
          SizedBox(width: 4 * scale),
          Text(
            label,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontSize: 11 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class FilterToggleButton extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final Color? inactiveColor;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final bool showActiveCheck;
  final double scale;

  const FilterToggleButton({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.activeColor = Colors.orangeAccent,
    this.inactiveColor,
    this.leadingIcon,
    this.leadingIconColor,
    this.showActiveCheck = true,
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
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                size: 12 * scale,
                color: value
                    ? activeColor
                    : (leadingIconColor ?? inactiveColor ?? Colors.white70),
              ),
              SizedBox(width: 4 * scale),
            ],
            if (showActiveCheck && value) ...[
              Icon(Icons.check, size: 12 * scale, color: activeColor),
              SizedBox(width: 4 * scale),
            ],
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

class FlightAlertChip extends StatelessWidget {
  final MapFlightAlert alert;
  final double scale;
  final bool blinkOn;

  const FlightAlertChip({
    super.key,
    required this.alert,
    required this.scale,
    this.blinkOn = true,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, border, icon) = switch (alert.level) {
      MapFlightAlertLevel.danger => (
        Colors.redAccent.withValues(alpha: 0.2),
        Colors.redAccent,
        Icons.warning_amber_rounded,
      ),
      MapFlightAlertLevel.warning => (
        Colors.orangeAccent.withValues(alpha: 0.2),
        Colors.orangeAccent,
        Icons.report_problem_outlined,
      ),
      MapFlightAlertLevel.caution => (
        Colors.yellowAccent.withValues(alpha: 0.2),
        Colors.yellowAccent,
        Icons.info_outline,
      ),
    };
    final isStallAlert =
        alert.id == 'stall_warning' || alert.id == 'stall_speed_warning';
    final opacity = isStallAlert ? (blinkOn ? 1.0 : 0.35) : 1.0;
    final backgroundOpacity = 0.2 * opacity;
    return Container(
      margin: EdgeInsets.only(right: 8 * scale),
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: backgroundOpacity),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: border.withValues(alpha: opacity)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14 * scale,
            color: border.withValues(alpha: opacity),
          ),
          SizedBox(width: 6 * scale),
          Text(
            alert.message.tr(context),
            style: TextStyle(
              color: Colors.white.withValues(alpha: opacity),
              fontSize: 11 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
