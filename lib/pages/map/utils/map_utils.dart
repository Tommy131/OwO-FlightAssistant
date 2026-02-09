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
  }
}

/// 计算航线总航程（海里）
int calculateTotalDistance(MapProvider provider) {
  if (provider.departureAirport == null || provider.destinationAirport == null) {
    return 0;
  }

  final Distance distance = const Distance();
  double totalMeters = 0;

  if (provider.alternateAirport != null && provider.alternateAirport!.latitude != 0) {
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

  var hasRunway = false;
  for (final runway in airport.runways) {
    if (runway.leLat != null && runway.leLon != null) {
      addPoint(runway.leLat, runway.leLon);
      hasRunway = true;
    }
    if (runway.heLat != null && runway.heLon != null) {
      addPoint(runway.heLat, runway.heLon);
      hasRunway = true;
    }
  }

  if (!hasRunway) {
    for (final taxiway in airport.taxiways) {
      for (final point in taxiway.points) {
        addPoint(point.latitude, point.longitude);
      }
    }
  }

  if (minLat == null) {
    for (final parking in airport.parkings) {
      addPoint(parking.latitude, parking.longitude);
    }
  }

  if (minLat == null || maxLat == null || minLon == null || maxLon == null) {
    return LatLng(airport.latitude, airport.longitude);
  }

  return LatLng(
    (minLat! + maxLat!) / 2.0,
    (minLon! + maxLon!) / 2.0,
  );
}
