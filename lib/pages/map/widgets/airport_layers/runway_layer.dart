import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../apps/models/airport_detail_data.dart';
import '../../models/map_types.dart';
import '../map_labels.dart';

/// 跑道图层组件
class RunwayLayer extends StatelessWidget {
  final List<AirportDetailData> airports;
  final double zoom;
  final MapLayerType layerType;
  final double scale;

  const RunwayLayer({
    super.key,
    required this.airports,
    required this.zoom,
    required this.layerType,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final isAviationDark = layerType == MapLayerType.taxiwayDark;

    return Stack(
      children: [
        // 1. 跑道线
        PolylineLayer(
          polylines: airports
              .expand((ap) => ap.runways)
              .where((r) => r.leLat != null && r.leLon != null)
              .map(
                (r) => Polyline(
                  points: [
                    LatLng(r.leLat!, r.leLon!),
                    LatLng(r.heLat!, r.heLon!),
                  ],
                  color: isAviationDark
                      ? Colors.grey.withValues(alpha: 0.5)
                      : ((layerType == MapLayerType.satellite ||
                                layerType == MapLayerType.dark ||
                                layerType == MapLayerType.taxiwayDark)
                            ? Colors.white.withValues(alpha: 0.8)
                            : Colors.black.withValues(alpha: 0.6)),
                  strokeWidth: isAviationDark ? 8 : 10,
                ),
              )
              .toList(),
        ),

        // 2. 跑道标识标签
        if (zoom > 13)
          MarkerLayer(
            markers: airports.expand((ap) => ap.runways).expand((r) {
              final markers = <Marker>[];
              if (r.leLat != null && r.leLon != null && r.leIdent != null) {
                markers.add(
                  Marker(
                    point: LatLng(r.leLat!, r.leLon!),
                    width: 60,
                    height: 40,
                    child: MapLabel(
                      text: r.leIdent!,
                      textColor: Colors.white,
                      bgColor: isAviationDark
                          ? Colors.blueGrey.shade800
                          : Colors.black87,
                      fontSize: 11 * scale,
                    ),
                  ),
                );
              }
              if (r.heLat != null && r.heLon != null && r.heIdent != null) {
                markers.add(
                  Marker(
                    point: LatLng(r.heLat!, r.heLon!),
                    width: 60,
                    height: 40,
                    child: MapLabel(
                      text: r.heIdent!,
                      textColor: Colors.white,
                      bgColor: isAviationDark
                          ? Colors.blueGrey.shade800
                          : Colors.black87,
                      fontSize: 11 * scale,
                    ),
                  ),
                );
              }
              return markers;
            }).toList(),
          ),
      ],
    );
  }
}
