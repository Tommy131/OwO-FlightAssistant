import 'dart:math' as math;

import 'package:flutter/material.dart';

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
        final labelMaxWidth =
            (availableWidth - (10 * scale) - (4 * scale) - (14 * scale))
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
                border: Border.all(
                  color: Colors.white,
                  width: math.max(1, scale),
                ),
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
