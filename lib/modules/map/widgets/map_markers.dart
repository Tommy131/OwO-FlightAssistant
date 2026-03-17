import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/localization_service.dart';
import '../localization/map_localization_keys.dart';
import '../models/map_models.dart';

class AircraftMarker extends StatelessWidget {
  final double? heading;
  final bool isDark;

  const AircraftMarker({super.key, this.heading, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final angle = (heading ?? 0) * (math.pi / 180);
    return Transform.rotate(
      angle: angle,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Icon(Icons.flight, color: Colors.blue, size: 22),
      ),
    );
  }
}

class AirportMarker extends StatelessWidget {
  final MapAirportMarker airport;
  final bool showLabel;

  const AirportMarker({
    super.key,
    required this.airport,
    required this.showLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = airport.isPrimary
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;
    final pin = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.local_airport, color: Colors.white, size: 14),
    );
    if (!showLabel) {
      return pin;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pin,
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            airport.code,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class SelectedAirportPin extends StatelessWidget {
  final MapAirportMarker airport;
  final double scale;

  const SelectedAirportPin({
    super.key,
    required this.airport,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8 * scale,
            vertical: 4 * scale,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(6 * scale),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Text(
            '${MapLocalizationKeys.selectedAirport.tr(context)} ${airport.code}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: 2 * scale),
        Icon(
          Icons.location_on,
          color: color,
          size: 34 * scale,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8),
          ],
        ),
      ],
    );
  }
}

class FlightEventMarker extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const FlightEventMarker({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Icon(icon, color: color, size: 34),
      ],
    );
  }
}

class AircraftCompassRing extends StatelessWidget {
  final double? heading;
  final double mapRotation;
  final double scale;

  const AircraftCompassRing({
    super.key,
    required this.heading,
    required this.mapRotation,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final angle = -((heading ?? 0) + mapRotation) * (math.pi / 180);
    final headingText = heading == null ? '--' : heading!.round().toString();
    return IgnorePointer(
      child: SizedBox(
        width: 120 * scale,
        height: 120 * scale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: angle,
              child: Container(
                width: 120 * scale,
                height: 120 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: 6 * scale),
                        child: Text(
                          'N',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12 * scale,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 6 * scale),
                        child: Text(
                          'E',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 10 * scale,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 6 * scale),
                        child: Text(
                          'S',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 10 * scale,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 6 * scale),
                        child: Text(
                          'W',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 10 * scale,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8 * scale,
                vertical: 3 * scale,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8 * scale),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                '$headingText°',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 11 * scale,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RunwayEndpointLabel extends StatelessWidget {
  final String label;
  final double scale;

  const RunwayEndpointLabel({
    super.key,
    required this.label,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.75)
            : Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(6 * scale),
        border: Border.all(
          color: isDark
              ? Colors.orangeAccent.withValues(alpha: 0.9)
              : Colors.orangeAccent,
          width: isDark ? 1 : 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4 * scale,
                  offset: Offset(0, 2 * scale),
                ),
              ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.orangeAccent,
          fontWeight: FontWeight.w900,
          fontSize: 9 * scale,
        ),
      ),
    );
  }
}

class ParkingSpotMarker extends StatelessWidget {
  final double scale;
  final String? name;

  const ParkingSpotMarker({super.key, required this.scale, this.name});

  @override
  Widget build(BuildContext context) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: math.max(1, scale)),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 180 * scale;
        final labelMaxWidth = (availableWidth - (10 * scale) - (4 * scale) - (14 * scale))
            .clamp(28 * scale, 180 * scale)
            .toDouble();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10 * scale,
              height: 10 * scale,
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: math.max(1, scale)),
              ),
            ),
            SizedBox(width: 4 * scale),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: labelMaxWidth),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 6 * scale,
                  vertical: 3 * scale,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(6 * scale),
                  border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.8),
                  ),
                ),
                child: Text(
                  trimmed,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 9 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
