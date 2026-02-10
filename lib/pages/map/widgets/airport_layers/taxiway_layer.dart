import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../apps/models/airport_detail_data.dart';
import '../../models/map_types.dart';
import '../map_labels.dart';

/// 滑行道图层组件
class TaxiwayLayer extends StatelessWidget {
  final List<AirportDetailData> airports;
  final double zoom;
  final MapLayerType layerType;
  final double scale;

  const TaxiwayLayer({
    super.key,
    required this.airports,
    required this.zoom,
    required this.layerType,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final isAviationDark = layerType == MapLayerType.taxiwayDark;
    
    return MobileLayerTransformer(
      child: Stack(
        children: [
          // 1. 滑行道线
          PolylineLayer(
            polylines: airports
                .expand((ap) => ap.taxiways)
                .where((t) => t.points.isNotEmpty)
                .map(
                  (t) => Polyline(
                    points: t.points
                        .map((p) => LatLng(p.latitude, p.longitude))
                        .toList(),
                    color: isAviationDark
                        ? Colors.orangeAccent.withValues(alpha: 0.9)
                        : (layerType == MapLayerType.satellite
                            ? Colors.yellowAccent.withValues(alpha: 0.55)
                            : (layerType == MapLayerType.taxiway)
                                ? Colors.orangeAccent.withValues(alpha: 0.65)
                                : Colors.blueGrey.withValues(alpha: 0.45)),
                    strokeWidth: isAviationDark ? 5.0 : 4.2,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                )
                .toList(),
          ),
          
          // 2. 滑行道标签
          if (zoom > 13.5)
            MarkerLayer(
              rotate: true,
              markers: airports
                  .expand((ap) => ap.taxiways)
                  .where((t) => t.name != null && t.points.isNotEmpty)
                  .map((t) {
                    final mid = t.points[t.points.length ~/ 2];
                    return Marker(
                      point: LatLng(mid.latitude, mid.longitude),
                      width: 80,
                      height: 40,
                      alignment: Alignment.center,
                      child: MapLabel(
                        text: t.name!,
                        textColor: isAviationDark ? Colors.white : Colors.orangeAccent,
                        bgColor: isAviationDark 
                            ? Colors.orange.withValues(alpha: 0.9) 
                            : Colors.black.withValues(alpha: 0.8),
                        fontSize: (isAviationDark ? 11 : 10) * scale,
                      ),
                    );
                  })
                  .toList(),
            ),
        ],
      ),
    );
  }
}
