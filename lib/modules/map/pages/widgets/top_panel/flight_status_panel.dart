import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class MapFlightStatusPanel extends StatelessWidget {
  final double scale;
  final double? groundSpeed;
  final double? altitude;
  final double? heading;
  final String duration;
  final double? verticalSpeed;
  final bool isSimulatorPaused;
  final bool blinkOn;

  const MapFlightStatusPanel({
    super.key,
    required this.scale,
    required this.groundSpeed,
    required this.altitude,
    required this.heading,
    required this.duration,
    required this.verticalSpeed,
    required this.isSimulatorPaused,
    required this.blinkOn,
  });

  @override
  Widget build(BuildContext context) {
    final vs = verticalSpeed ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16 * scale),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 20 * scale,
            vertical: 12 * scale,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FlightValueTile(
                scale: scale,
                label: 'GS',
                value: groundSpeed != null ? '${groundSpeed!.round()}' : '--',
                unit: 'kt',
              ),
              _FlightValueTile(
                scale: scale,
                label: 'ALT',
                value: altitude != null ? '${altitude!.round()}' : '--',
                unit: 'ft',
              ),
              _FlightValueTile(
                scale: scale,
                label: 'HDG',
                value: heading != null ? '${heading!.round()}°' : '--',
                unit: '',
              ),
              _FlightValueTile(
                scale: scale,
                label: 'TIME',
                value: duration,
                unit: '',
                color: Colors.cyanAccent,
                trailWidget: isSimulatorPaused
                    ? Icon(
                        Icons.pause_circle_filled,
                        color: Colors.redAccent.withValues(
                          alpha: blinkOn ? 1 : 0.35,
                        ),
                        size: 13 * scale,
                      )
                    : null,
              ),
              _FlightValueTile(
                scale: scale,
                label: 'VS',
                value: verticalSpeed != null ? '${verticalSpeed!.round()}' : '--',
                unit: 'fpm',
                color: _getVSColor(vs),
                icon: _getVSIcon(vs),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getVSColor(double vs) {
    if (vs.abs() > 2000) return Colors.redAccent;
    if (vs.abs() > 1000) return Colors.orangeAccent;
    if (vs.abs() > 100) return Colors.tealAccent;
    return Colors.white70;
  }

  IconData? _getVSIcon(double vs) {
    if (vs > 100) return Icons.arrow_upward;
    if (vs < -100) return Icons.arrow_downward;
    return null;
  }
}

class _FlightValueTile extends StatelessWidget {
  final double scale;
  final String label;
  final String value;
  final String unit;
  final Color? color;
  final IconData? icon;
  final Widget? trailWidget;

  const _FlightValueTile({
    required this.scale,
    required this.label,
    required this.value,
    required this.unit,
    this.color,
    this.icon,
    this.trailWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (icon != null) ...[
              SizedBox(width: 4 * scale),
              Icon(icon, size: 12 * scale, color: color ?? Colors.white70),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 14 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: 4 * scale),
                child: Text(
                  unit,
                  style: TextStyle(color: Colors.white70, fontSize: 10 * scale),
                ),
              ),
            if (trailWidget != null) ...[
              SizedBox(width: 6 * scale),
              trailWidget!,
            ],
          ],
        ),
      ],
    );
  }
}
