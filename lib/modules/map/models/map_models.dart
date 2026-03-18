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
  final double? headingTarget;
  final double? altitude;
  final double? groundSpeed;
  final double? airspeed;
  final double? pitch;
  final double? bank;
  final double? angleOfAttack;
  final double? verticalSpeed;
  final bool? stallWarning;
  final bool? onGround;
  final bool? parkingBrake;

  const MapAircraftState({
    required this.position,
    this.heading,
    this.headingTarget,
    this.altitude,
    this.groundSpeed,
    this.airspeed,
    this.pitch,
    this.bank,
    this.angleOfAttack,
    this.verticalSpeed,
    this.stallWarning,
    this.onGround,
    this.parkingBrake,
  });
}

enum MapAutoTimerStartMode { runwayMovement, pushback, anyMovement }

enum MapAutoTimerStopMode {
  stableLanding,
  runwayExitAfterLanding,
  parkingArrival,
}

enum MapFlightAlertLevel { caution, warning, danger }

class MapFlightAlert {
  final String id;
  final MapFlightAlertLevel level;
  final String message;

  const MapFlightAlert({
    required this.id,
    required this.level,
    required this.message,
  });
}

class MapSelectedAirportDetail {
  final MapAirportMarker marker;
  final String? source;
  final List<String> runways;
  final List<MapRunwayGeometry> runwayGeometries;
  final List<MapParkingSpot> parkingSpots;
  final List<String> frequencyBadges;
  final String? atis;
  final String? rawMetar;
  final String? decodedMetar;
  final String? approachRule;

  const MapSelectedAirportDetail({
    required this.marker,
    this.source,
    this.runways = const [],
    this.runwayGeometries = const [],
    this.parkingSpots = const [],
    this.frequencyBadges = const [],
    this.atis,
    this.rawMetar,
    this.decodedMetar,
    this.approachRule,
  });
}

class MapRunwayGeometry {
  final String ident;
  final String? leIdent;
  final String? heIdent;
  final MapCoordinate start;
  final MapCoordinate end;
  final double? lengthM;

  const MapRunwayGeometry({
    required this.ident,
    required this.start,
    required this.end,
    this.leIdent,
    this.heIdent,
    this.lengthM,
  });
}

class MapParkingSpot {
  final String? name;
  final MapCoordinate position;
  final double? headingDeg;

  const MapParkingSpot({this.name, required this.position, this.headingDeg});
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

enum MapLayerStyle { dark, satellite, terrain, taxiway }

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
