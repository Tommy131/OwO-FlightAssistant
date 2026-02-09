import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../apps/models/airport_detail_data.dart';
import '../models/map_types.dart';
import 'map_labels.dart';

/// 构建机场几何相关的图层（滑行道、跑道、门牌、停机位）
List<Widget> buildAirportGeometryLayers({
  required List<AirportDetailData> airports,
  required double zoom,
  required bool showTaxiways,
  required bool showRunways,
  required bool showParkings,
  required MapLayerType layerType,
  required double scale,
}) {
  final layers = <Widget>[];

  if (airports.isEmpty) return layers;

  if (showTaxiways) {
    layers.add(
      PolylineLayer(
        polylines: airports
            .expand((ap) => ap.taxiways)
            .where((t) => t.points.isNotEmpty)
            .map(
              (t) => Polyline(
                points: t.points
                    .map((p) => LatLng(p.latitude, p.longitude))
                    .toList(),
                color: layerType == MapLayerType.satellite
                    ? Colors.yellowAccent.withValues(alpha: 0.55)
                    : (layerType == MapLayerType.aviation ||
                          layerType == MapLayerType.aviationDark)
                    ? Colors.orangeAccent.withValues(alpha: 0.65)
                    : Colors.blueGrey.withValues(alpha: 0.45),
                strokeWidth: 4.2,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            )
            .toList(),
      ),
    );
    if (zoom > 13.5) {
      layers.add(
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
                    textColor: Colors.orangeAccent,
                    bgColor: Colors.black.withValues(alpha: 0.8),
                    fontSize: 10 * scale,
                  ),
                );
              })
              .toList(),
        ),
      );
    }
  }

  if (showRunways) {
    layers.add(
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
                color:
                    (layerType == MapLayerType.satellite ||
                        layerType == MapLayerType.dark ||
                        layerType == MapLayerType.aviationDark)
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.black.withValues(alpha: 0.6),
                strokeWidth:
                    (layerType == MapLayerType.aviation ||
                        layerType == MapLayerType.street ||
                        layerType == MapLayerType.terrain)
                    ? 11
                    : 10,
              ),
            )
            .toList(),
      ),
    );

    if (zoom > 13) {
      layers.add(
        MarkerLayer(
          rotate: true,
          markers: airports.expand((ap) => ap.runways).expand((r) {
            final markers = <Marker>[];
            if (r.leLat != null && r.leLon != null && r.leIdent != null) {
              markers.add(
                Marker(
                  point: LatLng(r.leLat!, r.leLon!),
                  width: 50,
                  height: 50,
                  child: MapLabel(
                    text: r.leIdent!,
                    textColor: Colors.white,
                    bgColor: Colors.black87,
                  ),
                ),
              );
            }
            if (r.heLat != null && r.heLon != null && r.heIdent != null) {
              markers.add(
                Marker(
                  point: LatLng(r.heLat!, r.heLon!),
                  width: 50,
                  height: 50,
                  child: MapLabel(
                    text: r.heIdent!,
                    textColor: Colors.white,
                    bgColor: Colors.black87,
                  ),
                ),
              );
            }
            return markers;
          }).toList(),
        ),
      );
    }
  }

  if (showParkings && zoom > 14.5) {
    layers.add(
      MarkerLayer(
        rotate: true,
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
                                color: Colors.orangeAccent.withValues(
                                  alpha: 0.4,
                                ),
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
      ),
    );
  }

  return layers;
}
