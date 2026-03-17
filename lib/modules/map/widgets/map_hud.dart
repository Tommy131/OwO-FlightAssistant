import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/map_models.dart';

class MapLoadingOverlay extends StatelessWidget {
  const MapLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface.withValues(alpha: 0.6),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class VirtualHudPanel extends StatelessWidget {
  final double scale;
  final MapAircraftState aircraft;
  final double? verticalSpeed;

  const VirtualHudPanel({
    super.key,
    required this.scale,
    required this.aircraft,
    required this.verticalSpeed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12 * scale),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 8 * scale,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            border: Border.all(
              color: Colors.lightGreenAccent.withValues(alpha: 0.55),
            ),
            borderRadius: BorderRadius.circular(12 * scale),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              HudValue(
                label: 'GS',
                value: aircraft.groundSpeed != null
                    ? '${aircraft.groundSpeed!.round()}'
                    : '--',
                unit: 'kt',
                scale: scale,
              ),
              HudValue(
                label: 'ALT',
                value: aircraft.altitude != null
                    ? '${aircraft.altitude!.round()}'
                    : '--',
                unit: 'ft',
                scale: scale,
              ),
              HudValue(
                label: 'HDG',
                value: aircraft.heading != null
                    ? '${aircraft.heading!.round()}'
                    : '--',
                unit: '°',
                scale: scale,
              ),
              HudValue(
                label: 'VS',
                value: verticalSpeed != null ? '${verticalSpeed!.round()}' : '--',
                unit: 'fpm',
                scale: scale,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HudValue extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final double scale;

  const HudValue({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.lightGreenAccent.withValues(alpha: 0.9),
            fontSize: 10 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: Colors.lightGreenAccent,
                fontSize: 14 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: 4 * scale),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: Colors.lightGreenAccent.withValues(alpha: 0.82),
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
