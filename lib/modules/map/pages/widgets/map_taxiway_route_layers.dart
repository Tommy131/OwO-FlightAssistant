import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/map_models.dart';

class TaxiwayRoutePolylineLayer extends StatelessWidget {
  final List<MapCoordinate> points;
  final double scale;

  const TaxiwayRoutePolylineLayer({
    super.key,
    required this.points,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const SizedBox.shrink();
    }
    return PolylineLayer(
      polylines: [
        Polyline(
          points: points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(),
          color: Colors.amberAccent.withValues(alpha: 0.95),
          strokeWidth: (4.2 * scale).clamp(3.0, 6.5),
          borderColor: Colors.black.withValues(alpha: 0.5),
          borderStrokeWidth: (1.4 * scale).clamp(1.0, 2.0),
        ),
      ],
    );
  }
}

class TaxiwayRoutePointMarkerLayer extends StatelessWidget {
  final List<MapCoordinate> points;
  final double scale;

  const TaxiwayRoutePointMarkerLayer({
    super.key,
    required this.points,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }
    return MarkerLayer(
      markers: points
          .asMap()
          .entries
          .map(
            (entry) => Marker(
              point: LatLng(entry.value.latitude, entry.value.longitude),
              width: 28 * scale,
              height: 28 * scale,
              child: _TaxiwayPlanPoint(index: entry.key + 1, scale: scale),
            ),
          )
          .toList(),
    );
  }
}

class _TaxiwayPlanPoint extends StatelessWidget {
  final int index;
  final double scale;

  const _TaxiwayPlanPoint({required this.index, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.75)),
      ),
      child: Text(
        '$index',
        style: TextStyle(
          color: Colors.black,
          fontSize: 9 * scale,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
