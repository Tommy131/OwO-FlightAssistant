import 'package:flutter/material.dart';
import '../../../apps/models/airport_detail_data.dart';
import '../models/map_types.dart';
import 'airport_layers/taxiway_layer.dart';
import 'airport_layers/runway_layer.dart';
import 'airport_layers/parking_layer.dart';

/// 构建机场几何相关的图层（滑行道、跑道、门牌、停机位）
/// 采用组件化重构，提高代码可维护性和复用性
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

  // 1. 滑行道图层
  if (showTaxiways) {
    layers.add(
      TaxiwayLayer(
        airports: airports,
        zoom: zoom,
        layerType: layerType,
        scale: scale,
      ),
    );
  }

  // 2. 跑道图层
  if (showRunways) {
    layers.add(
      RunwayLayer(
        airports: airports,
        zoom: zoom,
        layerType: layerType,
        scale: scale,
      ),
    );
  }

  // 3. 停机位图层
  if (showParkings && zoom > 14.5) {
    layers.add(ParkingLayer(airports: airports, scale: scale));
  }

  return layers;
}
