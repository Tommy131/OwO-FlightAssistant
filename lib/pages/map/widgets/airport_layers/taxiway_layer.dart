import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../apps/models/airport_detail_data.dart';
import '../../models/map_types.dart';
import '../../utils/map_utils.dart';
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

    return Stack(
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

        // 2. 滑行道标签 - 显示端点，使用黄色系与停机位橙色系区分
        if (zoom > 13.5)
          MarkerLayer(
            markers: airports
                .expand((ap) => ap.taxiways)
                .where(
                  (t) =>
                      t.name != null &&
                      t.name!.isNotEmpty &&
                      t.points.length >= 2,
                )
                .expand((t) {
                  final markers = <Marker>[];
                  final label = formatTaxiwayLabel(t.name!);
                  if (label.isEmpty) {
                    return markers;
                  }

                  // 起点标签 - 黄色系
                  final start = t.points.first;
                  markers.add(
                    Marker(
                      point: LatLng(start.latitude, start.longitude),
                      width: 70,
                      height: 30,
                      alignment: Alignment.center,
                      child: MapLabel(
                        text: label,
                        textColor: Colors.black87,
                        bgColor: Colors.yellow.shade600.withValues(alpha: 0.9),
                        fontSize: 9 * scale,
                      ),
                    ),
                  );

                  // 终点标签 - 黄色系
                  final end = t.points.last;
                  markers.add(
                    Marker(
                      point: LatLng(end.latitude, end.longitude),
                      width: 70,
                      height: 30,
                      alignment: Alignment.center,
                      child: MapLabel(
                        text: label,
                        textColor: Colors.black87,
                        bgColor: Colors.yellow.shade600.withValues(alpha: 0.9),
                        fontSize: 9 * scale,
                      ),
                    ),
                  );

                  return markers;
                })
                .toList(),
          ),
      ],
    );
  }
}
