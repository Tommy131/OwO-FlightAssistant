enum FlightLogAlertLevel { caution, warning, danger }

class FlightLogAlert {
  final String id;
  final FlightLogAlertLevel level;
  final String message;

  const FlightLogAlert({
    required this.id,
    required this.level,
    required this.message,
  });

  Map<String, dynamic> toJson() => {'id': id, 'lv': level.name, 'msg': message};

  factory FlightLogAlert.fromJson(Map<String, dynamic> json) => FlightLogAlert(
    id: (json['id'] as String? ?? '').trim(),
    level: _flightLogAlertLevelFromRaw(json['lv'] as String?),
    message: (json['msg'] as String? ?? '').trim(),
  );
}

FlightLogAlertLevel _flightLogAlertLevelFromRaw(String? raw) {
  final value = raw?.trim().toLowerCase();
  if (value == FlightLogAlertLevel.danger.name) {
    return FlightLogAlertLevel.danger;
  }
  if (value == FlightLogAlertLevel.warning.name) {
    return FlightLogAlertLevel.warning;
  }
  return FlightLogAlertLevel.caution;
}

bool? _boolFromRaw(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    if (value == 1) return true;
    if (value == 0) return false;
    return null;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'on' ||
        normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'off' ||
        normalized == 'no') {
      return false;
    }
  }
  return null;
}

class FlightLogPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double airspeed;
  final double groundSpeed;
  final double verticalSpeed;
  final double heading;
  final double pitch;
  final double roll;
  final double? angleOfAttack;
  final double gForce;
  final double fuelQuantity;
  final double? fuelFlow;
  final DateTime timestamp;
  final bool? autopilotEngaged;
  final bool? autothrottleEngaged;
  final String? flightPhase;
  final double? autopilotHeadingTarget;
  final String? autopilotLateralMode;
  final String? autopilotVerticalMode;
  final bool? gearDown;
  final double? noseGearG;
  final double? leftGearG;
  final double? rightGearG;
  final int? flapsPosition;
  final String? flapsLabel;
  final double? windSpeed;
  final double? windDirection;
  final double? windGust;
  final double? gustDelta;
  final double? gustFactorRate;
  final double? crosswindComponent;
  final double? radioAltitude;
  final double? outsideAirTemperature;
  final double? baroPressure;
  final bool? masterWarning;
  final bool? masterCaution;
  final bool? engine1Running;
  final bool? engine2Running;
  final double? engine1N1;
  final double? engine2N1;
  final double? engine1N2;
  final double? engine2N2;
  final double? engine1Egt;
  final double? engine2Egt;
  final String? transponderCode;
  final bool? landingLights;
  final bool? beacon;
  final bool? strobes;
  final int? autoBrakeLevel;
  final double? speedBrakePosition;
  final double? aileronInput;
  final double? elevatorInput;
  final double? rudderInput;
  final double? aileronTrim;
  final double? elevatorTrim;
  final double? rudderTrim;
  final bool? onGround;
  final List<FlightLogAlert> anomalyAlerts;

  FlightLogPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.airspeed,
    required this.groundSpeed,
    required this.verticalSpeed,
    required this.heading,
    required this.pitch,
    required this.roll,
    this.angleOfAttack,
    required this.gForce,
    required this.fuelQuantity,
    this.fuelFlow,
    required this.timestamp,
    this.autopilotEngaged,
    this.autothrottleEngaged,
    this.flightPhase,
    this.autopilotHeadingTarget,
    this.autopilotLateralMode,
    this.autopilotVerticalMode,
    this.gearDown,
    this.noseGearG,
    this.leftGearG,
    this.rightGearG,
    this.flapsPosition,
    this.flapsLabel,
    this.windSpeed,
    this.windDirection,
    this.windGust,
    this.gustDelta,
    this.gustFactorRate,
    this.crosswindComponent,
    this.radioAltitude,
    this.outsideAirTemperature,
    this.baroPressure,
    this.masterWarning,
    this.masterCaution,
    this.engine1Running,
    this.engine2Running,
    this.engine1N1,
    this.engine2N1,
    this.engine1N2,
    this.engine2N2,
    this.engine1Egt,
    this.engine2Egt,
    this.transponderCode,
    this.landingLights,
    this.beacon,
    this.strobes,
    this.autoBrakeLevel,
    this.speedBrakePosition,
    this.aileronInput,
    this.elevatorInput,
    this.rudderInput,
    this.aileronTrim,
    this.elevatorTrim,
    this.rudderTrim,
    this.onGround,
    this.anomalyAlerts = const <FlightLogAlert>[],
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
    'aoa': angleOfAttack,
    'g': gForce,
    'fuel': fuelQuantity,
    'ff': fuelFlow,
    'ts': timestamp.toIso8601String(),
    'ap': autopilotEngaged,
    'at': autothrottleEngaged,
    'phase': flightPhase,
    'ap_hdg': autopilotHeadingTarget,
    'ap_lat': autopilotLateralMode,
    'ap_ver': autopilotVerticalMode,
    'gear': gearDown,
    'ngg': noseGearG,
    'lgg': leftGearG,
    'rgg': rightGearG,
    'flaps': flapsPosition,
    'flap_lbl': flapsLabel,
    'ws': windSpeed,
    'wd': windDirection,
    'wg': windGust,
    'gust': gustDelta,
    'gust_rate': gustFactorRate,
    'xw': crosswindComponent,
    'ra': radioAltitude,
    'oat': outsideAirTemperature,
    'baro': baroPressure,
    'mw': masterWarning,
    'mc': masterCaution,
    'e1r': engine1Running,
    'e2r': engine2Running,
    'e1n1': engine1N1,
    'e2n1': engine2N1,
    'e1n2': engine1N2,
    'e2n2': engine2N2,
    'e1egt': engine1Egt,
    'e2egt': engine2Egt,
    'xpdr': transponderCode,
    'll': landingLights,
    'beac': beacon,
    'strob': strobes,
    'grnd': onGround,
    'ab': autoBrakeLevel,
    'sb': speedBrakePosition,
    'ail': aileronInput,
    'ele': elevatorInput,
    'rud': rudderInput,
    'atr': aileronTrim,
    'etr': elevatorTrim,
    'rtr': rudderTrim,
    'alerts': anomalyAlerts.map((alert) => alert.toJson()).toList(),
  };

  factory FlightLogPoint.fromJson(Map<String, dynamic> json) => FlightLogPoint(
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
    angleOfAttack: (json['aoa'] as num?)?.toDouble(),
    gForce: (json['g'] as num? ?? 1.0).toDouble(),
    fuelQuantity: (json['fuel'] as num? ?? 0.0).toDouble(),
    fuelFlow: (json['ff'] as num?)?.toDouble(),
    timestamp: json['ts'] != null
        ? DateTime.parse(json['ts'] as String)
        : DateTime.now(),
    autopilotEngaged: json['ap'] as bool?,
    autothrottleEngaged: json['at'] as bool?,
    flightPhase: json['phase'] as String?,
    autopilotHeadingTarget: (json['ap_hdg'] as num?)?.toDouble(),
    autopilotLateralMode: json['ap_lat'] as String?,
    autopilotVerticalMode: json['ap_ver'] as String?,
    gearDown: _boolFromRaw(json['gear']),
    noseGearG: (json['ngg'] as num?)?.toDouble(),
    leftGearG: (json['lgg'] as num?)?.toDouble(),
    rightGearG: (json['rgg'] as num?)?.toDouble(),
    flapsPosition: (json['flaps'] as num?)?.toInt(),
    flapsLabel: json['flap_lbl'] as String?,
    windSpeed: (json['ws'] as num?)?.toDouble(),
    windDirection: (json['wd'] as num?)?.toDouble(),
    windGust: (json['wg'] as num?)?.toDouble(),
    gustDelta: (json['gust'] as num?)?.toDouble(),
    gustFactorRate: (json['gust_rate'] as num?)?.toDouble(),
    crosswindComponent: (json['xw'] as num?)?.toDouble(),
    radioAltitude: (json['ra'] as num?)?.toDouble(),
    outsideAirTemperature: (json['oat'] as num?)?.toDouble(),
    baroPressure: (json['baro'] as num?)?.toDouble(),
    masterWarning: json['mw'] as bool?,
    masterCaution: json['mc'] as bool?,
    engine1Running: json['e1r'] as bool?,
    engine2Running: json['e2r'] as bool?,
    engine1N1: (json['e1n1'] as num?)?.toDouble(),
    engine2N1: (json['e2n1'] as num?)?.toDouble(),
    engine1N2: (json['e1n2'] as num?)?.toDouble(),
    engine2N2: (json['e2n2'] as num?)?.toDouble(),
    engine1Egt: (json['e1egt'] as num?)?.toDouble(),
    engine2Egt: (json['e2egt'] as num?)?.toDouble(),
    transponderCode: json['xpdr'] as String?,
    landingLights: json['ll'] as bool?,
    beacon: json['beac'] as bool?,
    strobes: json['strob'] as bool?,
    autoBrakeLevel: (json['ab'] as num?)?.toInt(),
    speedBrakePosition: (json['sb'] as num?)?.toDouble(),
    aileronInput: (json['ail'] as num?)?.toDouble(),
    elevatorInput: (json['ele'] as num?)?.toDouble(),
    rudderInput: (json['rud'] as num?)?.toDouble(),
    aileronTrim: (json['atr'] as num?)?.toDouble(),
    elevatorTrim: (json['etr'] as num?)?.toDouble(),
    rudderTrim: (json['rtr'] as num?)?.toDouble(),
    onGround: _boolFromRaw(json['grnd']),
    anomalyAlerts: (json['alerts'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(FlightLogAlert.fromJson)
        .where((alert) => alert.message.isNotEmpty)
        .toList(),
  );
}

class FlightLog {
  final String id;
  final String aircraftTitle;
  final String? aircraftType;
  final String? simulatorLabel;
  final String? flightNumber;
  final String departureAirport;
  final String? arrivalAirport;
  DateTime startTime;
  DateTime? endTime;
  final List<FlightLogPoint> points;
  double maxG;
  double minG;
  double maxAltitude;
  double maxAirspeed;
  double maxGroundSpeed;
  double? totalFuelUsed;
  bool wasOnGroundAtStart;
  bool wasOnGroundAtEnd;
  TakeoffData? takeoffData;
  LandingData? landingData;

  FlightLog({
    required this.id,
    required this.aircraftTitle,
    this.aircraftType,
    this.simulatorLabel,
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

  Duration get duration {
    final value = (endTime ?? DateTime.now()).difference(startTime);
    return value.isNegative ? Duration.zero : value;
  }

  Duration get totalRecordedDuration => duration;
  Duration get airborneDuration {
    DateTime? takeoffTime = takeoffData?.timestamp;
    DateTime? touchdownTime = landingData?.timestamp;
    var previousOnGround = wasOnGroundAtStart;
    for (final point in points) {
      final currentOnGround = point.onGround ?? previousOnGround;
      if (takeoffTime == null && previousOnGround && !currentOnGround) {
        takeoffTime = point.timestamp;
      }
      if (takeoffTime == null && !currentOnGround) {
        takeoffTime = point.timestamp;
      }
      if (takeoffTime != null &&
          touchdownTime == null &&
          !previousOnGround &&
          currentOnGround) {
        touchdownTime = point.timestamp;
        break;
      }
      previousOnGround = currentOnGround;
    }
    if (takeoffTime == null) return Duration.zero;
    final endReference =
        touchdownTime ??
        endTime ??
        (points.isNotEmpty ? points.last.timestamp : takeoffTime);
    if (endReference.isBefore(takeoffTime)) return Duration.zero;
    return endReference.difference(takeoffTime);
  }

  FlightLogPoint? get lastPoint => points.isEmpty ? null : points.last;
  bool get isCompleted {
    final finalPoint = lastPoint;
    if (finalPoint == null) return false;
    final hasArrivalAirport =
        arrivalAirport != null && arrivalAirport!.trim().isNotEmpty;
    final endedOnGround = finalPoint.onGround ?? wasOnGroundAtEnd;
    return hasArrivalAirport && endedOnGround;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'aircraft': aircraftTitle,
    'ac_type': aircraftType,
    'sim': simulatorLabel,
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
    simulatorLabel: json['sim'] as String?,
    flightNumber: json['fn'] as String?,
    departureAirport: json['dep'] as String,
    arrivalAirport: json['arr'] as String?,
    startTime: DateTime.parse(json['start'] as String),
    endTime: json['end'] != null ? DateTime.parse(json['end'] as String) : null,
    points: (json['points'] as List)
        .map((p) => FlightLogPoint.fromJson(p as Map<String, dynamic>))
        .toList(),
    maxG: (json['maxG'] as num).toDouble(),
    minG: (json['minG'] as num).toDouble(),
    maxAltitude: (json['maxAlt'] as num).toDouble(),
    maxAirspeed: (json['maxSpd'] as num).toDouble(),
    maxGroundSpeed: (json['maxGs'] as num? ?? 0.0).toDouble(),
    totalFuelUsed: (json['fuelUsed'] as num?)?.toDouble(),
    wasOnGroundAtStart: _boolFromRaw(json['groundStart']) ?? false,
    wasOnGroundAtEnd: _boolFromRaw(json['groundEnd']) ?? false,
    takeoffData: json['takeoff'] != null
        ? TakeoffData.fromJson(json['takeoff'] as Map<String, dynamic>)
        : null,
    landingData: json['landing'] != null
        ? LandingData.fromJson(json['landing'] as Map<String, dynamic>)
        : null,
  );
}

enum LandingRating {
  perfect('完美着陆', '666，你是王牌飞行员！', 0.9, 1.15),
  soft('软着陆', '落地丝滑，机长辛苦了！', 0.8, 1.3),
  acceptable('可接受着陆', '安全落地，下次加油。', 0.6, 1.6),
  hard('硬着陆', '屁股有点痛，建议去检查起落架。', 0.4, 2.1),
  fired('你被开除了', '乘客正在排队退票，你已被解雇。', 0.2, 3.5),
  rip('R.I.P.', '愿天堂没有重力...', 0.0, 99.0);

  final String label;
  final String description;
  final double minScore;
  final double maxG;

  const LandingRating(this.label, this.description, this.minScore, this.maxG);

  static LandingRating fromName(String? name) {
    if (name == null) return LandingRating.acceptable;
    for (final rating in LandingRating.values) {
      if (rating.name == name) return rating;
    }
    return LandingRating.acceptable;
  }
}

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
  final List<FlightLogPoint> touchdownSequence;
  final List<double> touchdownGForces;
  final double? remainingRunwayFt;
  final String? runway;
  final double? approachStabilityScore;
  final double? flareHeightFt;
  final double? sinkRateAt50FtFpm;
  final double? crosswindAtTouchdownKt;
  final int? bounceCount;

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
    required this.touchdownGForces,
    this.remainingRunwayFt,
    this.runway,
    this.approachStabilityScore,
    this.flareHeightFt,
    this.sinkRateAt50FtFpm,
    this.crosswindAtTouchdownKt,
    this.bounceCount,
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
    'seq_g': touchdownGForces,
    'rem_rwy': remainingRunwayFt,
    'rwy': runway,
    'stability': approachStabilityScore,
    'flare_h': flareHeightFt,
    'sink_50': sinkRateAt50FtFpm,
    'xw_td': crosswindAtTouchdownKt,
    'bounce': bounceCount,
  };

  factory LandingData.fromJson(Map<String, dynamic> json) {
    final touchdownSequence = (json['seq'] as List? ?? const [])
        .map((p) => FlightLogPoint.fromJson(p as Map<String, dynamic>))
        .toList();
    final serializedTouchdownGs = json['seq_g'] as List?;
    final touchdownGForces = serializedTouchdownGs != null
        ? serializedTouchdownGs
              .map((value) => (value as num).toDouble())
              .toList()
        : touchdownSequence.map((point) => point.gForce).toList();
    return LandingData(
      latitude: (json['lat'] as num? ?? 0.0).toDouble(),
      longitude: (json['lon'] as num? ?? 0.0).toDouble(),
      gForce: (json['g'] as num? ?? 1.0).toDouble(),
      verticalSpeed: (json['vs'] as num? ?? 0.0).toDouble(),
      airspeed: (json['spd'] as num? ?? 0.0).toDouble(),
      groundSpeed: (json['gs'] as num? ?? 0.0).toDouble(),
      pitch: (json['pit'] as num? ?? 0.0).toDouble(),
      roll: (json['rol'] as num? ?? 0.0).toDouble(),
      rating: LandingRating.fromName(json['rating'] as String?),
      timestamp: json['ts'] != null
          ? DateTime.parse(json['ts'] as String)
          : DateTime.now(),
      touchdownSequence: touchdownSequence,
      touchdownGForces: touchdownGForces,
      remainingRunwayFt: (json['rem_rwy'] as num?)?.toDouble(),
      runway: json['rwy'] as String?,
      approachStabilityScore: (json['stability'] as num?)?.toDouble(),
      flareHeightFt: (json['flare_h'] as num?)?.toDouble(),
      sinkRateAt50FtFpm: (json['sink_50'] as num?)?.toDouble(),
      crosswindAtTouchdownKt: (json['xw_td'] as num?)?.toDouble(),
      bounceCount: (json['bounce'] as num?)?.toInt(),
    );
  }
}

class TakeoffData {
  final double latitude;
  final double longitude;
  final double airspeed;
  final double groundSpeed;
  final double verticalSpeed;
  final double pitch;
  final double heading;
  final DateTime timestamp;
  final double? remainingRunwayFt;
  final String? runway;
  final double? takeoffStabilityScore;
  final double? rotationSpeedKt;
  final int? rotationToLiftoffSec;
  final double? crosswindAtLiftoffKt;
  final double? pitchAt35FtDeg;

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
    this.takeoffStabilityScore,
    this.rotationSpeedKt,
    this.rotationToLiftoffSec,
    this.crosswindAtLiftoffKt,
    this.pitchAt35FtDeg,
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
    'to_stab': takeoffStabilityScore,
    'rot_spd': rotationSpeedKt,
    'rot_to': rotationToLiftoffSec,
    'xw_to': crosswindAtLiftoffKt,
    'pit_35': pitchAt35FtDeg,
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
    takeoffStabilityScore: (json['to_stab'] as num?)?.toDouble(),
    rotationSpeedKt: (json['rot_spd'] as num?)?.toDouble(),
    rotationToLiftoffSec: (json['rot_to'] as num?)?.toInt(),
    crosswindAtLiftoffKt: (json['xw_to'] as num?)?.toDouble(),
    pitchAt35FtDeg: (json['pit_35'] as num?)?.toDouble(),
  );
}
