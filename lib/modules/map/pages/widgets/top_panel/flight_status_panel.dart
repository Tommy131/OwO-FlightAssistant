import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class MapFlightStatusPanel extends StatefulWidget {
  final double scale;
  final double? groundSpeed;
  final double? altitude;
  final double? heading;
  final String duration;
  final double? verticalSpeed;
  final bool isHudTimerRunning;
  final bool showPauseIndicator;

  const MapFlightStatusPanel({
    super.key,
    required this.scale,
    required this.groundSpeed,
    required this.altitude,
    required this.heading,
    required this.duration,
    required this.verticalSpeed,
    required this.isHudTimerRunning,
    required this.showPauseIndicator,
  });

  @override
  State<MapFlightStatusPanel> createState() => _MapFlightStatusPanelState();
}

class _MapFlightStatusPanelState extends State<MapFlightStatusPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncBlinking();
  }

  @override
  void didUpdateWidget(covariant MapFlightStatusPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showPauseIndicator != widget.showPauseIndicator) {
      _syncBlinking();
    }
  }

  void _syncBlinking() {
    if (widget.showPauseIndicator) {
      _blinkController.repeat(reverse: true);
      return;
    }
    _blinkController.stop();
    _blinkController.value = 1;
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vs = widget.verticalSpeed ?? 0;
    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, _) {
        final pulse = widget.showPauseIndicator ? _blinkController.value : 1.0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16 * widget.scale),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 20 * widget.scale,
                vertical: 12 * widget.scale,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _FlightValueTile(
                    scale: widget.scale,
                    label: 'GS',
                    value: widget.groundSpeed != null
                        ? '${widget.groundSpeed!.round()}'
                        : '--',
                    unit: 'kt',
                  ),
                  _FlightValueTile(
                    scale: widget.scale,
                    label: 'ALT',
                    value: widget.altitude != null
                        ? '${widget.altitude!.round()}'
                        : '--',
                    unit: 'ft',
                  ),
                  _FlightValueTile(
                    scale: widget.scale,
                    label: 'HDG',
                    value: widget.heading != null
                        ? '${widget.heading!.round()}°'
                        : '--',
                    unit: '',
                  ),
                  _FlightValueTile(
                    scale: widget.scale,
                    label: 'TIME',
                    value: widget.duration,
                    unit: '',
                    color: Colors.cyanAccent,
                    trailWidget:
                        widget.showPauseIndicator && !widget.isHudTimerRunning
                        ? Container(
                            padding: EdgeInsets.all(2 * widget.scale),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(
                                alpha: 0.28 + 0.62 * pulse,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Icon(
                              Icons.pause,
                              color: Colors.white.withValues(
                                alpha: 0.75 + 0.25 * pulse,
                              ),
                              size: 10 * widget.scale,
                            ),
                          )
                        : null,
                  ),
                  _FlightValueTile(
                    scale: widget.scale,
                    label: 'VS',
                    value: widget.verticalSpeed != null
                        ? '${widget.verticalSpeed!.round()}'
                        : '--',
                    unit: 'fpm',
                    color: _getVSColor(vs),
                    icon: _getVSIcon(vs),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
