/// 飞行轨迹点模型
class FlightPoint {
  final double latitude;
  final double longitude;
  final double altitude; // 英尺
  final double airspeed; // 节
  final double verticalSpeed; // fpm
  final double heading; // 度
  final double pitch; // 度
  final double roll; // 度
  final double gForce;
  final double fuelQuantity; // kg
  final DateTime timestamp;

  FlightPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.airspeed,
    required this.verticalSpeed,
    required this.heading,
    required this.pitch,
    required this.roll,
    required this.gForce,
    required this.fuelQuantity,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'alt': altitude,
    'spd': airspeed,
    'vs': verticalSpeed,
    'hdg': heading,
    'pit': pitch,
    'rol': roll,
    'g': gForce,
    'fuel': fuelQuantity,
    'ts': timestamp.toIso8601String(),
  };

  factory FlightPoint.fromJson(Map<String, dynamic> json) => FlightPoint(
    latitude: json['lat'] as double,
    longitude: json['lon'] as double,
    altitude: json['alt'] as double,
    airspeed: json['spd'] as double,
    verticalSpeed: json['vs'] as double,
    heading: json['hdg'] as double,
    pitch: json['pit'] as double,
    roll: json['rol'] as double,
    gForce: json['g'] as double,
    fuelQuantity: json['fuel'] as double,
    timestamp: DateTime.parse(json['ts'] as String),
  );
}

/// 飞行日志模型
class FlightLog {
  final String id;
  final String aircraftTitle;
  final String departureAirport;
  final String? arrivalAirport;
  final DateTime startTime;
  DateTime? endTime;
  final List<FlightPoint> points;
  double maxG;
  double minG;
  double maxAltitude;
  double maxAirspeed;
  bool wasOnGroundAtStart;
  bool wasOnGroundAtEnd;

  FlightLog({
    required this.id,
    required this.aircraftTitle,
    required this.departureAirport,
    this.arrivalAirport,
    required this.startTime,
    this.endTime,
    required this.points,
    this.maxG = 1.0,
    this.minG = 1.0,
    this.maxAltitude = 0.0,
    this.maxAirspeed = 0.0,
    this.wasOnGroundAtStart = false,
    this.wasOnGroundAtEnd = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'aircraft': aircraftTitle,
    'dep': departureAirport,
    'arr': arrivalAirport,
    'start': startTime.toIso8601String(),
    'end': endTime?.toIso8601String(),
    'points': points.map((p) => p.toJson()).toList(),
    'maxG': maxG,
    'minG': minG,
    'maxAlt': maxAltitude,
    'maxSpd': maxAirspeed,
    'onGroundStart': wasOnGroundAtStart,
    'onGroundEnd': wasOnGroundAtEnd,
  };

  factory FlightLog.fromJson(Map<String, dynamic> json) => FlightLog(
    id: json['id'] as String,
    aircraftTitle: json['aircraft'] as String,
    departureAirport: json['dep'] as String,
    arrivalAirport: json['arr'] as String?,
    startTime: DateTime.parse(json['start'] as String),
    endTime: json['end'] != null ? DateTime.parse(json['end'] as String) : null,
    points: (json['points'] as List)
        .map((p) => FlightPoint.fromJson(p))
        .toList(),
    maxG: (json['maxG'] as num).toDouble(),
    minG: (json['minG'] as num).toDouble(),
    maxAltitude: (json['maxAlt'] as num).toDouble(),
    maxAirspeed: (json['maxSpd'] as num).toDouble(),
    wasOnGroundAtStart: json['onGroundStart'] as bool? ?? false,
    wasOnGroundAtEnd: json['onGroundEnd'] as bool? ?? false,
  );
}
