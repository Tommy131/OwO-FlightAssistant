class MapCoordinate {
  final double latitude;
  final double longitude;

  const MapCoordinate({required this.latitude, required this.longitude});
}

class MapRoutePoint extends MapCoordinate {
  final double? altitude;
  final double? groundSpeed;
  final DateTime? timestamp;

  const MapRoutePoint({
    required super.latitude,
    required super.longitude,
    this.altitude,
    this.groundSpeed,
    this.timestamp,
  });
}

class MapAirportMarker {
  final String code;
  final String? name;
  final MapCoordinate position;
  final bool isPrimary;

  const MapAirportMarker({
    required this.code,
    required this.position,
    this.name,
    this.isPrimary = false,
  });
}

class MapAircraftState {
  final MapCoordinate position;
  final double? heading;
  final double? altitude;
  final double? groundSpeed;
  final bool? onGround;

  const MapAircraftState({
    required this.position,
    this.heading,
    this.altitude,
    this.groundSpeed,
    this.onGround,
  });
}

class MapDataSnapshot {
  final MapAircraftState? aircraft;
  final List<MapRoutePoint> route;
  final List<MapAirportMarker> airports;
  final bool isConnected;

  const MapDataSnapshot({
    this.aircraft,
    this.route = const [],
    this.airports = const [],
    this.isConnected = false,
  });
}

abstract class MapDataAdapter {
  Stream<MapDataSnapshot> get stream;
}

enum MapLayerStyle {
  dark,
  satellite,
  terrain,
  taxiway,
}

String mapTileUrl(MapLayerStyle style) {
  switch (style) {
    case MapLayerStyle.satellite:
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    case MapLayerStyle.terrain:
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';
    case MapLayerStyle.taxiway:
      return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}{r}.png';
    case MapLayerStyle.dark:
      return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  }
}

enum MapOrientationMode { northUp, trackUp }
