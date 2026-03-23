import 'package:flutter/material.dart';

import '../../../../../core/services/localization_service.dart';
import '../../../localization/map_localization_keys.dart';
import '../../../models/map_models.dart';

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

class HomeAirportPin extends StatelessWidget {
  final String code;
  final double scale;

  const HomeAirportPin({super.key, required this.code, required this.scale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.tertiary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8 * scale,
            vertical: 4 * scale,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(7 * scale),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home_rounded, color: Colors.white, size: 12 * scale),
              SizedBox(width: 4 * scale),
              Text(
                code,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10 * scale,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 2 * scale),
        Icon(
          Icons.place_rounded,
          color: color,
          size: 34 * scale,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 8),
          ],
        ),
      ],
    );
  }
}

class AirportRolePin extends StatelessWidget {
  final String code;
  final String title;
  final IconData icon;
  final Color color;
  final double scale;

  const AirportRolePin({
    super.key,
    required this.code,
    required this.title,
    required this.icon,
    required this.color,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8 * scale,
            vertical: 4 * scale,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(7 * scale),
            border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 12 * scale),
              SizedBox(width: 4 * scale),
              Text(
                '$title $code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 2 * scale),
        Icon(
          Icons.place_rounded,
          color: color,
          size: 34 * scale,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 8),
          ],
        ),
      ],
    );
  }
}

class CombinedAirportPin extends StatelessWidget {
  final String code;
  final List<AirportPinTag> tags;
  final IconData icon;
  final Color color;
  final double scale;

  const CombinedAirportPin({
    super.key,
    required this.code,
    required this.tags,
    required this.icon,
    required this.color,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedTags = tags
        .where((tag) => tag.label.trim().isNotEmpty)
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tag in normalizedTags) ...[
          _RoleTag(tag: tag, scale: scale),
          SizedBox(height: 2 * scale),
        ],
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8 * scale,
            vertical: 4 * scale,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(7 * scale),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 12 * scale),
                  SizedBox(width: 4 * scale),
                  Text(
                    code,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 2 * scale),
        Icon(
          Icons.place_rounded,
          color: color,
          size: 34 * scale,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 8),
          ],
        ),
      ],
    );
  }
}

class AirportPinTag {
  final String label;
  final Color color;

  const AirportPinTag({required this.label, required this.color});
}

class _RoleTag extends StatelessWidget {
  final AirportPinTag tag;
  final double scale;

  const _RoleTag({required this.tag, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: tag.color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6 * scale),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Text(
        tag.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: 8 * scale,
          fontWeight: FontWeight.w700,
        ),
      ),
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
