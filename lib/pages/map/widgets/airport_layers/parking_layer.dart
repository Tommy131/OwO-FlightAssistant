import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../apps/models/airport_detail_data.dart';
import '../map_labels.dart';

/// 停机位图层组件
class ParkingLayer extends StatelessWidget {
  final List<AirportDetailData> airports;
  final double scale;

  const ParkingLayer({super.key, required this.airports, required this.scale});

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: airports
          .expand((ap) => ap.parkings)
          .map(
            (p) => Marker(
              point: LatLng(p.latitude, p.longitude),
              width: 80,
              height: 80,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orangeAccent.withValues(alpha: 0.3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orangeAccent.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: Colors.orangeAccent.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 14 * scale,
                    child: MapLabel(
                      text: p.displayName,
                      textColor: Colors.orangeAccent,
                      bgColor: Colors.black.withValues(alpha: 0.8),
                      fontSize: 9 * scale,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
