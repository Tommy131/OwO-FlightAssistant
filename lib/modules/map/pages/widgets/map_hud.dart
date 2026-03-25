import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/services/localization_service.dart';
import '../../localization/map_localization_keys.dart';
import '../../models/map_models.dart';

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
                value: verticalSpeed != null
                    ? '${verticalSpeed!.round()}'
                    : '--',
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

class DangerOverlay extends StatefulWidget {
  final String message;
  final String subMessage;

  const DangerOverlay({
    super.key,
    required this.message,
    required this.subMessage,
  });

  @override
  State<DangerOverlay> createState() => _DangerOverlayState();
}

class _DangerOverlayState extends State<DangerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.red.withValues(alpha: _opacity.value),
                width: 20,
              ),
              color: Colors.red.withValues(alpha: _opacity.value * 0.2),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 100,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 20),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                  Text(
                    widget.subMessage,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 24,
                      shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CrashOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const CrashOverlay({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final quotes = [
      MapLocalizationKeys.crashQuote1.tr(context),
      MapLocalizationKeys.crashQuote2.tr(context),
      MapLocalizationKeys.crashQuote3.tr(context),
      MapLocalizationKeys.crashQuote4.tr(context),
      MapLocalizationKeys.crashQuote5.tr(context),
      MapLocalizationKeys.crashQuote6.tr(context),
      MapLocalizationKeys.crashQuote7.tr(context),
      MapLocalizationKeys.crashQuote8.tr(context),
      MapLocalizationKeys.crashQuote9.tr(context),
      MapLocalizationKeys.crashQuote10.tr(context),
      MapLocalizationKeys.crashQuote11.tr(context),
      MapLocalizationKeys.crashQuote12.tr(context),
    ];
    final randomQuote = quotes[Random().nextInt(quotes.length)];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.9),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 20),
              Text(
                MapLocalizationKeys.crashTitle.tr(context),
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                MapLocalizationKeys.crashSubtitle.tr(context),
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  '"$randomQuote"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(MapLocalizationKeys.crashResetButton.tr(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
