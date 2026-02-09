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
  TakeoffData? takeoffData;
  LandingData? landingData;

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
    this.takeoffData,
    this.landingData,
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
    'groundStart': wasOnGroundAtStart,
    'groundEnd': wasOnGroundAtEnd,
    'takeoff': takeoffData?.toJson(),
    'landing': landingData?.toJson(),
  };

  factory FlightLog.fromJson(Map<String, dynamic> json) => FlightLog(
    id: json['id'] as String,
    aircraftTitle: json['aircraft'] as String,
    departureAirport: json['dep'] as String,
    arrivalAirport: json['arr'] as String?,
    startTime: DateTime.parse(json['start'] as String),
    endTime: json['end'] != null ? DateTime.parse(json['end'] as String) : null,
    points: (json['points'] as List)
        .map((p) => FlightPoint.fromJson(p as Map<String, dynamic>))
        .toList(),
    maxG: (json['maxG'] as num).toDouble(),
    minG: (json['minG'] as num).toDouble(),
    maxAltitude: (json['maxAlt'] as num).toDouble(),
    maxAirspeed: (json['maxSpd'] as num).toDouble(),
    wasOnGroundAtStart: json['groundStart'] as bool? ?? false,
    wasOnGroundAtEnd: json['groundEnd'] as bool? ?? false,
    takeoffData: json['takeoff'] != null
        ? TakeoffData.fromJson(json['takeoff'] as Map<String, dynamic>)
        : null,
    landingData: json['landing'] != null
        ? LandingData.fromJson(json['landing'] as Map<String, dynamic>)
        : null,
  );
}

/// 着陆等级
enum LandingRating {
  perfect('完美着陆', '666，你是王牌飞行员！', 0.9, 1.15),
  soft('软着陆', '落地丝滑，机长辛苦了！', 0.8, 1.3),
  acceptable('可接受着陆', '安全落地，下次加油。', 0.6, 1.6),
  hard('硬着陆', '屁股有点痛，建议去检查起落架。', 0.4, 2.1),
  fired('你被开除了', '乘客正在排队退票，你已被解雇。', 0.2, 3.5),
  rip('R.I.P.', '愿天堂没有重力...', 0.0, 99.0);

  final String label;
  final String description;
  final double minScore; // 综合评分阈值
  final double maxG; // G值阈值

  const LandingRating(this.label, this.description, this.minScore, this.maxG);

  static LandingRating fromData(double gForce, double verticalSpeed) {
    // 简单评估逻辑：G值是主要参考，垂直速度辅助
    // 垂直速度通常为负值 (fpm)
    final absVs = verticalSpeed.abs();

    if (gForce > 3.5 || absVs > 1200) return LandingRating.rip;
    if (gForce > 2.1 || absVs > 800) return LandingRating.fired;
    if (gForce > 1.6 || absVs > 500) return LandingRating.hard;
    if (gForce > 1.3 || absVs > 300) return LandingRating.acceptable;
    if (gForce > 1.15 || absVs > 150) return LandingRating.soft;
    return LandingRating.perfect;
  }
}

/// 着陆详细数据
class LandingData {
  final double gForce;
  final double verticalSpeed;
  final double airspeed;
  final double pitch;
  final double roll;
  final LandingRating rating;
  final List<FlightPoint> touchdownSequence; // 落地前后一段时间的数据点
  final double? remainingRunwayFt; // 剩余跑道长度 (英尺)

  LandingData({
    required this.gForce,
    required this.verticalSpeed,
    required this.airspeed,
    required this.pitch,
    required this.roll,
    required this.rating,
    required this.touchdownSequence,
    this.remainingRunwayFt,
  });

  Map<String, dynamic> toJson() => {
    'g': gForce,
    'vs': verticalSpeed,
    'spd': airspeed,
    'pit': pitch,
    'rol': roll,
    'rating': rating.name,
    'seq': touchdownSequence.map((p) => p.toJson()).toList(),
    'rem_rwy': remainingRunwayFt,
  };

  factory LandingData.fromJson(Map<String, dynamic> json) => LandingData(
    gForce: (json['g'] as num).toDouble(),
    verticalSpeed: (json['vs'] as num).toDouble(),
    airspeed: (json['spd'] as num).toDouble(),
    pitch: (json['pit'] as num).toDouble(),
    roll: (json['rol'] as num).toDouble(),
    rating: LandingRating.values.byName(json['rating'] as String),
    touchdownSequence: (json['seq'] as List)
        .map((p) => FlightPoint.fromJson(p as Map<String, dynamic>))
        .toList(),
    remainingRunwayFt: json['rem_rwy'] as double?,
  );
}

/// 起飞详细数据
class TakeoffData {
  final double latitude;
  final double longitude;
  final double airspeed;
  final double verticalSpeed;
  final double pitch;
  final double heading;
  final DateTime timestamp;
  final double? remainingRunwayFt; // 剩余跑道长度 (英尺)

  TakeoffData({
    required this.latitude,
    required this.longitude,
    required this.airspeed,
    required this.verticalSpeed,
    required this.pitch,
    required this.heading,
    required this.timestamp,
    this.remainingRunwayFt,
  });

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'spd': airspeed,
    'vs': verticalSpeed,
    'pit': pitch,
    'hdg': heading,
    'ts': timestamp.toIso8601String(),
    'rem_rwy': remainingRunwayFt,
  };

  factory TakeoffData.fromJson(Map<String, dynamic> json) => TakeoffData(
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lon'] as num).toDouble(),
    airspeed: (json['spd'] as num).toDouble(),
    verticalSpeed: (json['vs'] as num).toDouble(),
    pitch: (json['pit'] as num).toDouble(),
    heading: (json['hdg'] as num).toDouble(),
    timestamp: DateTime.parse(json['ts'] as String),
    remainingRunwayFt: json['rem_rwy'] as double?,
  );
}
