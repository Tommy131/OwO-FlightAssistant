/// 飞行轨迹点模型
class FlightPoint {
  final double latitude;
  final double longitude;
  final double altitude; // 英尺
  final double airspeed; // 节
  final double groundSpeed; // 节
  final double verticalSpeed; // fpm
  final double heading; // 度
  final double pitch; // 度
  final double roll; // 度
  final double gForce;
  final double fuelQuantity; // kg
  final double? fuelFlow; // kg/h
  final DateTime timestamp;

  // 黑匣子扩展数据
  final bool? autopilotEngaged;
  final bool? autothrottleEngaged;
  final bool? gearDown;
  final int? flapsPosition;
  final String? flapsLabel;
  final double? windSpeed;
  final double? windDirection;
  final double? outsideAirTemperature;
  final double? baroPressure;
  final bool? masterWarning;
  final bool? masterCaution;
  final bool? engine1Running;
  final bool? engine2Running;
  final String? transponderCode;
  final bool? landingLights;
  final bool? beacon;
  final bool? strobes;
  final int? autoBrakeLevel;
  final double? speedBrakePosition;
  final bool? onGround;

  FlightPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.airspeed,
    required this.groundSpeed,
    required this.verticalSpeed,
    required this.heading,
    required this.pitch,
    required this.roll,
    required this.gForce,
    required this.fuelQuantity,
    this.fuelFlow,
    required this.timestamp,
    this.autopilotEngaged,
    this.autothrottleEngaged,
    this.gearDown,
    this.flapsPosition,
    this.flapsLabel,
    this.windSpeed,
    this.windDirection,
    this.outsideAirTemperature,
    this.baroPressure,
    this.masterWarning,
    this.masterCaution,
    this.engine1Running,
    this.engine2Running,
    this.transponderCode,
    this.landingLights,
    this.beacon,
    this.strobes,
    this.autoBrakeLevel,
    this.speedBrakePosition,
    this.onGround,
  });

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'alt': altitude,
    'spd': airspeed,
    'gs': groundSpeed,
    'vs': verticalSpeed,
    'hdg': heading,
    'pit': pitch,
    'rol': roll,
    'g': gForce,
    'fuel': fuelQuantity,
    'ff': fuelFlow,
    'ts': timestamp.toIso8601String(),
    'ap': autopilotEngaged,
    'at': autothrottleEngaged,
    'gear': gearDown,
    'flaps': flapsPosition,
    'flap_lbl': flapsLabel,
    'ws': windSpeed,
    'wd': windDirection,
    'oat': outsideAirTemperature,
    'baro': baroPressure,
    'mw': masterWarning,
    'mc': masterCaution,
    'e1r': engine1Running,
    'e2r': engine2Running,
    'xpdr': transponderCode,
    'll': landingLights,
    'beac': beacon,
    'strob': strobes,
    'grnd': onGround,
    'ab': autoBrakeLevel,
    'sb': speedBrakePosition,
  };

  factory FlightPoint.fromJson(Map<String, dynamic> json) => FlightPoint(
    latitude: (json['lat'] as num? ?? 0.0).toDouble(),
    longitude: (json['lon'] as num? ?? 0.0).toDouble(),
    altitude: (json['alt'] as num? ?? 0.0).toDouble(),
    airspeed: (json['spd'] as num? ?? 0.0).toDouble(),
    groundSpeed: (json['gs'] as num? ?? (json['spd'] as num? ?? 0.0))
        .toDouble(),
    verticalSpeed: (json['vs'] as num? ?? 0.0).toDouble(),
    heading: (json['hdg'] as num? ?? 0.0).toDouble(),
    pitch: (json['pit'] as num? ?? 0.0).toDouble(),
    roll: (json['rol'] as num? ?? 0.0).toDouble(),
    gForce: (json['g'] as num? ?? 1.0).toDouble(),
    fuelQuantity: (json['fuel'] as num? ?? 0.0).toDouble(),
    fuelFlow: (json['ff'] as num?)?.toDouble(),
    timestamp: json['ts'] != null
        ? DateTime.parse(json['ts'] as String)
        : DateTime.now(),
    autopilotEngaged: json['ap'] as bool?,
    autothrottleEngaged: json['at'] as bool?,
    gearDown: json['gear'] as bool?,
    flapsPosition: json['flaps'] as int?,
    flapsLabel: json['flap_lbl'] as String?,
    windSpeed: (json['ws'] as num?)?.toDouble(),
    windDirection: (json['wd'] as num?)?.toDouble(),
    outsideAirTemperature: (json['oat'] as num?)?.toDouble(),
    baroPressure: (json['baro'] as num?)?.toDouble(),
    masterWarning: json['mw'] as bool?,
    masterCaution: json['mc'] as bool?,
    engine1Running: json['e1r'] as bool?,
    engine2Running: json['e2r'] as bool?,
    transponderCode: json['xpdr'] as String?,
    landingLights: json['ll'] as bool?,
    beacon: json['beac'] as bool?,
    strobes: json['strob'] as bool?,
    onGround: json['grnd'] as bool?,
    autoBrakeLevel: json['ab'] as int?,
    speedBrakePosition: (json['sb'] as num?)?.toDouble(),
  );
}

/// 飞行日志模型
class FlightLog {
  final String id;
  final String aircraftTitle;
  final String? aircraftType;
  final String? flightNumber;
  final String departureAirport;
  final String? arrivalAirport;
  DateTime startTime;
  DateTime? endTime;
  final List<FlightPoint> points;

  // 统计数据
  double maxG;
  double minG;
  double maxAltitude;
  double maxAirspeed;
  double maxGroundSpeed;
  double? totalFuelUsed;

  // 地面状态
  bool wasOnGroundAtStart;
  bool wasOnGroundAtEnd;

  // 关键阶段数据
  TakeoffData? takeoffData;
  LandingData? landingData;

  FlightLog({
    required this.id,
    required this.aircraftTitle,
    this.aircraftType,
    this.flightNumber,
    required this.departureAirport,
    this.arrivalAirport,
    required this.startTime,
    this.endTime,
    required this.points,
    this.maxG = 1.0,
    this.minG = 1.0,
    this.maxAltitude = 0.0,
    this.maxAirspeed = 0.0,
    this.maxGroundSpeed = 0.0,
    this.totalFuelUsed,
    this.wasOnGroundAtStart = false,
    this.wasOnGroundAtEnd = false,
    this.takeoffData,
    this.landingData,
  });

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  Map<String, dynamic> toJson() => {
    'id': id,
    'aircraft': aircraftTitle,
    'ac_type': aircraftType,
    'fn': flightNumber,
    'dep': departureAirport,
    'arr': arrivalAirport,
    'start': startTime.toIso8601String(),
    'end': endTime?.toIso8601String(),
    'points': points.map((p) => p.toJson()).toList(),
    'maxG': maxG,
    'minG': minG,
    'maxAlt': maxAltitude,
    'maxSpd': maxAirspeed,
    'maxGs': maxGroundSpeed,
    'fuelUsed': totalFuelUsed,
    'groundStart': wasOnGroundAtStart,
    'groundEnd': wasOnGroundAtEnd,
    'takeoff': takeoffData?.toJson(),
    'landing': landingData?.toJson(),
  };

  factory FlightLog.fromJson(Map<String, dynamic> json) => FlightLog(
    id: json['id'] as String,
    aircraftTitle: json['aircraft'] as String,
    aircraftType: json['ac_type'] as String?,
    flightNumber: json['fn'] as String?,
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
    maxGroundSpeed: (json['maxGs'] as num? ?? 0.0).toDouble(),
    totalFuelUsed: (json['fuelUsed'] as num?)?.toDouble(),
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
  final double latitude;
  final double longitude;
  final double gForce;
  final double verticalSpeed;
  final double airspeed;
  final double groundSpeed;
  final double pitch;
  final double roll;
  final LandingRating rating;
  final DateTime timestamp;
  final List<FlightPoint> touchdownSequence; // 落地前后一段时间的数据点
  final double? remainingRunwayFt; // 剩余跑道长度 (英尺)
  final String? runway; // 落地跑道

  LandingData({
    required this.latitude,
    required this.longitude,
    required this.gForce,
    required this.verticalSpeed,
    required this.airspeed,
    required this.groundSpeed,
    required this.pitch,
    required this.roll,
    required this.rating,
    required this.timestamp,
    required this.touchdownSequence,
    this.remainingRunwayFt,
    this.runway,
  });

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'g': gForce,
    'vs': verticalSpeed,
    'spd': airspeed,
    'gs': groundSpeed,
    'pit': pitch,
    'rol': roll,
    'rating': rating.name,
    'ts': timestamp.toIso8601String(),
    'seq': touchdownSequence.map((p) => p.toJson()).toList(),
    'rem_rwy': remainingRunwayFt,
    'rwy': runway,
  };

  factory LandingData.fromJson(Map<String, dynamic> json) => LandingData(
    latitude: (json['lat'] as num? ?? 0.0).toDouble(),
    longitude: (json['lon'] as num? ?? 0.0).toDouble(),
    gForce: (json['g'] as num? ?? 1.0).toDouble(),
    verticalSpeed: (json['vs'] as num? ?? 0.0).toDouble(),
    airspeed: (json['spd'] as num? ?? 0.0).toDouble(),
    groundSpeed: (json['gs'] as num? ?? 0.0).toDouble(),
    pitch: (json['pit'] as num? ?? 0.0).toDouble(),
    roll: (json['rol'] as num? ?? 0.0).toDouble(),
    rating: json['rating'] != null
        ? LandingRating.values.byName(json['rating'] as String)
        : LandingRating.acceptable,
    timestamp: json['ts'] != null
        ? DateTime.parse(json['ts'] as String)
        : DateTime.now(), // Fallback for old logs
    touchdownSequence: (json['seq'] as List)
        .map((p) => FlightPoint.fromJson(p as Map<String, dynamic>))
        .toList(),
    remainingRunwayFt: (json['rem_rwy'] as num?)?.toDouble(),
    runway: json['rwy'] as String?,
  );
}

/// 起飞详细数据
class TakeoffData {
  final double latitude;
  final double longitude;
  final double airspeed;
  final double groundSpeed;
  final double verticalSpeed;
  final double pitch;
  final double heading;
  final DateTime timestamp;
  final double? remainingRunwayFt; // 剩余跑道长度 (英尺)
  final String? runway; // 起飞跑道

  TakeoffData({
    required this.latitude,
    required this.longitude,
    required this.airspeed,
    required this.groundSpeed,
    required this.verticalSpeed,
    required this.pitch,
    required this.heading,
    required this.timestamp,
    this.remainingRunwayFt,
    this.runway,
  });

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'spd': airspeed,
    'gs': groundSpeed,
    'vs': verticalSpeed,
    'pit': pitch,
    'hdg': heading,
    'ts': timestamp.toIso8601String(),
    'rem_rwy': remainingRunwayFt,
    'rwy': runway,
  };

  factory TakeoffData.fromJson(Map<String, dynamic> json) => TakeoffData(
    latitude: (json['lat'] as num? ?? 0.0).toDouble(),
    longitude: (json['lon'] as num? ?? 0.0).toDouble(),
    airspeed: (json['spd'] as num? ?? 0.0).toDouble(),
    groundSpeed: (json['gs'] as num? ?? 0.0).toDouble(),
    verticalSpeed: (json['vs'] as num? ?? 0.0).toDouble(),
    pitch: (json['pit'] as num? ?? 0.0).toDouble(),
    heading: (json['hdg'] as num? ?? 0.0).toDouble(),
    timestamp: json['ts'] != null
        ? DateTime.parse(json['ts'] as String)
        : DateTime.now(),
    remainingRunwayFt: (json['rem_rwy'] as num?)?.toDouble(),
    runway: json['rwy'] as String?,
  );
}
