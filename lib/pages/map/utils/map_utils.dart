import 'package:latlong2/latlong.dart';
import '../../../apps/models/airport_detail_data.dart';
import '../../../apps/providers/map_provider.dart';
import '../models/map_types.dart';

/// 获取不同地图底图的瓦片地址
String getTileUrl(MapLayerType type) {
  switch (type) {
    case MapLayerType.satellite:
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    case MapLayerType.street:
      return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
    case MapLayerType.terrain:
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';
    case MapLayerType.dark:
      return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
    case MapLayerType.taxiway:
      return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}{r}.png';
    case MapLayerType.taxiwayDark:
      return 'https://{s}.basemaps.cartocdn.com/rastertiles/dark_nolabels/{z}/{x}/{y}{r}.png';
  }
}

String? getAviationOverlayUrl(MapLayerType type) {
  switch (type) {
    case MapLayerType.taxiway:
    case MapLayerType.taxiwayDark:
      return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    default:
      return null;
  }
}

/// 计算航线总航程（海里）
int calculateTotalDistance(MapProvider provider) {
  if (provider.departureAirport == null ||
      provider.destinationAirport == null) {
    return 0;
  }

  final Distance distance = const Distance();
  double totalMeters = 0;

  if (provider.alternateAirport != null &&
      provider.alternateAirport!.latitude != 0) {
    totalMeters += distance(
      LatLng(
        provider.departureAirport!.latitude,
        provider.departureAirport!.longitude,
      ),
      LatLng(
        provider.alternateAirport!.latitude,
        provider.alternateAirport!.longitude,
      ),
    );
    totalMeters += distance(
      LatLng(
        provider.alternateAirport!.latitude,
        provider.alternateAirport!.longitude,
      ),
      LatLng(
        provider.destinationAirport!.latitude,
        provider.destinationAirport!.longitude,
      ),
    );
  } else {
    totalMeters += distance(
      LatLng(
        provider.departureAirport!.latitude,
        provider.departureAirport!.longitude,
      ),
      LatLng(
        provider.destinationAirport!.latitude,
        provider.destinationAirport!.longitude,
      ),
    );
  }

  return (totalMeters * 0.000539957).round();
}

/// 获取机场的几何中心点
///
/// 通过收集机场所有几何要素（跑道、滑行道、停机位）的坐标点，
/// 计算边界框（bounding box）的中心作为机场中心。
/// 这样可以确保图钉放置在机场的真实中央位置。
LatLng getAirportCenter(AirportDetailData airport) {
  double? minLat;
  double? maxLat;
  double? minLon;
  double? maxLon;

  void addPoint(double? lat, double? lon) {
    if (lat == null || lon == null) return;
    if (lat == 0 && lon == 0) return;
    minLat = minLat == null ? lat : (lat < minLat! ? lat : minLat);
    maxLat = maxLat == null ? lat : (lat > maxLat! ? lat : maxLat);
    minLon = minLon == null ? lon : (lon < minLon! ? lon : minLon);
    maxLon = maxLon == null ? lon : (lon > maxLon! ? lon : maxLon);
  }

  // 1. 收集所有跑道端点
  for (final runway in airport.runways) {
    if (runway.leLat != null && runway.leLon != null) {
      addPoint(runway.leLat, runway.leLon);
    }
    if (runway.heLat != null && runway.heLon != null) {
      addPoint(runway.heLat, runway.heLon);
    }
  }

  // 2. 收集滑行道点（用于更准确的边界）
  // 但为了性能，只采样部分点
  for (final taxiway in airport.taxiways) {
    if (taxiway.points.isNotEmpty) {
      // 采样：首尾点 + 中间点
      addPoint(taxiway.points.first.latitude, taxiway.points.first.longitude);
      if (taxiway.points.length > 2) {
        final mid = taxiway.points[taxiway.points.length ~/ 2];
        addPoint(mid.latitude, mid.longitude);
      }
      addPoint(taxiway.points.last.latitude, taxiway.points.last.longitude);
    }
  }

  // 3. 收集停机位点（用于更准确的边界）
  // 停机位通常在航站楼附近，有助于确定机场范围
  for (final parking in airport.parkings) {
    addPoint(parking.latitude, parking.longitude);
  }

  // 4. 如果没有任何几何数据，使用机场的参考点（ARP）
  if (minLat == null || maxLat == null || minLon == null || maxLon == null) {
    return LatLng(airport.latitude, airport.longitude);
  }

  // 5. 计算边界框的中心点
  return LatLng((minLat! + maxLat!) / 2.0, (minLon! + maxLon!) / 2.0);
}

/// 获取机场边界框信息（用于调试和可视化）
///
/// 返回机场的边界框坐标，可用于绘制机场范围矩形
Map<String, double> getAirportBounds(AirportDetailData airport) {
  double? minLat;
  double? maxLat;
  double? minLon;
  double? maxLon;

  void addPoint(double? lat, double? lon) {
    if (lat == null || lon == null) return;
    if (lat == 0 && lon == 0) return;
    minLat = minLat == null ? lat : (lat < minLat! ? lat : minLat);
    maxLat = maxLat == null ? lat : (lat > maxLat! ? lat : maxLat);
    minLon = minLon == null ? lon : (lon < minLon! ? lon : minLon);
    maxLon = maxLon == null ? lon : (lon > maxLon! ? lon : maxLon);
  }

  // 收集所有几何点
  for (final runway in airport.runways) {
    addPoint(runway.leLat, runway.leLon);
    addPoint(runway.heLat, runway.heLon);
  }

  for (final taxiway in airport.taxiways) {
    for (final point in taxiway.points) {
      addPoint(point.latitude, point.longitude);
    }
  }

  for (final parking in airport.parkings) {
    addPoint(parking.latitude, parking.longitude);
  }

  return {
    'minLat': minLat ?? airport.latitude,
    'maxLat': maxLat ?? airport.latitude,
    'minLon': minLon ?? airport.longitude,
    'maxLon': maxLon ?? airport.longitude,
  };
}

LatLng getAirportMarkerPoint({
  required double latitude,
  required double longitude,
  AirportDetailData? detail,
}) {
  if (detail != null) {
    final center = getAirportCenter(detail);
    if (center.latitude != 0 && center.longitude != 0) {
      return center;
    }
  }
  return LatLng(latitude, longitude);
}

String formatTaxiwayLabel(String name) {
  var label = name.trim();
  label = label.replaceAll(RegExp(r'^\d+\.\d+\s*'), '');
  label = label.replaceAll(
    RegExp(r'\b(TAXIWAY|TAXI|TWY|TXY)\b', caseSensitive: false),
    '',
  );
  label = label.replaceAll(RegExp(r'[()\[\]{}]'), '');
  label = label.replaceAll(RegExp(r'[_-]+'), ' ');
  label = label.replaceAll(RegExp(r'\s{2,}'), ' ');
  label = label.trim();
  if (label.isEmpty) {
    return name.trim();
  }
  return label.toUpperCase();
}
