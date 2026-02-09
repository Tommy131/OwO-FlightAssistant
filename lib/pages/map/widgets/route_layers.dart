import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../apps/providers/map_provider.dart';

/// 构建轨迹与航程线图层
List<Widget> buildRouteLayers({
  required MapProvider provider,
  required bool showRouteDistance,
}) {
  final layers = <Widget>[];

  if (provider.path.isNotEmpty) {
    layers.add(
      PolylineLayer(
        polylines: [
          Polyline(
            points: provider.path,
            color: Colors.orangeAccent.withValues(alpha: 0.7),
            strokeWidth: 2,
          ),
        ],
      ),
    );
  }

  if (showRouteDistance &&
      provider.departureAirport != null &&
      provider.destinationAirport != null) {
    layers.add(
      PolylineLayer(
        polylines: [
          Polyline(
            points: [
              LatLng(provider.departureAirport!.latitude, provider.departureAirport!.longitude),
              if (provider.alternateAirport != null)
                LatLng(provider.alternateAirport!.latitude, provider.alternateAirport!.longitude),
              LatLng(provider.destinationAirport!.latitude, provider.destinationAirport!.longitude),
            ],
            color: Colors.purpleAccent,
            strokeWidth: 2,
          ),
        ],
      ),
    );
  }

  return layers;
}
