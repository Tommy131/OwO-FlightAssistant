import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../apps/models/airport_detail_data.dart';
import '../../../apps/providers/map_provider.dart';
import '../utils/map_utils.dart';
import 'airport_pin_widget.dart';

/// 机场标记图层组件 - 统一管理所有机场图钉
class AirportMarkersLayer extends StatelessWidget {
  final MapProvider mapProvider;
  final double scale;

  const AirportMarkersLayer({
    super.key,
    required this.mapProvider,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    // 1. 目的地机场
    if (mapProvider.destinationAirport != null) {
      markers.add(
        _buildAirportMarker(
          airport: mapProvider.destinationAirport!,
          icon: Icons.flight_land,
          color: Colors.purpleAccent,
          label: 'DEST',
        ),
      );
    }

    // 2. 起飞机场
    if (mapProvider.departureAirport != null) {
      markers.add(
        _buildAirportMarker(
          airport: mapProvider.departureAirport!,
          icon: Icons.star,
          color: Colors.amber,
          label: 'DEP',
        ),
      );
    }

    // 3. 备降机场
    if (mapProvider.alternateAirport != null) {
      markers.add(
        _buildAirportMarker(
          airport: mapProvider.alternateAirport!,
          icon: Icons.directions_outlined,
          color: Colors.cyanAccent,
          label: 'ALTN',
        ),
      );
    }

    // 4. 搜索的目标机场（最显眼）
    if (mapProvider.targetAirport != null) {
      markers.add(
        _buildAirportMarker(
          airport: mapProvider.targetAirport!,
          icon: Icons.location_on,
          color: Colors.redAccent,
          label: mapProvider.targetAirport!.icaoCode,
          isBig: true,
        ),
      );
    }

    return MarkerLayer(markers: markers);
  }

  Marker _buildAirportMarker({
    required AirportDetailData airport,
    required IconData icon,
    required Color color,
    required String label,
    bool isBig = false,
  }) {
    return Marker(
      point: getAirportMarkerPoint(
        latitude: airport.latitude,
        longitude: airport.longitude,
        detail: airport,
      ),
      width: isBig ? 80 : 60,
      height: isBig ? 80 : 60,
      alignment: Alignment.center,
      child: AirportPinWidget(
        icon: icon,
        color: color,
        label: label,
        isBig: isBig,
        scale: scale,
      ),
    );
  }
}
