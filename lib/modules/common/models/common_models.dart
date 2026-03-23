import 'package:flutter/material.dart';

/// 模拟器类型枚举
enum SimulatorType { none, xplane, msfs }

/// 机场基本信息
class AirportInfo {
  final String icaoCode;
  final String iataCode;
  final String name;
  final String nameChinese;
  final double latitude;
  final double longitude;

  const AirportInfo({
    required this.icaoCode,
    required this.iataCode,
    required this.name,
    required this.nameChinese,
    required this.latitude,
    required this.longitude,
  });

  /// 优先返回中文名称，无中文名则返回英文名
  String get displayName => nameChinese.isNotEmpty ? nameChinese : name;
}

/// METAR 气象报文数据
class LiveMetarData {
  final String raw;
  final DateTime timestamp;
  final String displayWind;
  final String displayVisibility;
  final String displayTemperature;
  final String displayAltimeter;

  const LiveMetarData({
    required this.raw,
    required this.timestamp,
    required this.displayWind,
    required this.displayVisibility,
    required this.displayTemperature,
    required this.displayAltimeter,
  });
}

/// 当前检查单阶段信息（用于仪表盘展示用途）
class FlightChecklistPhase {
  final String labelKey;
  final IconData icon;

  const FlightChecklistPhase({required this.labelKey, required this.icon});
}

/// 飞行警报条目
class FlightAlert {
  final String id;
  final String level;
  final String message;

  const FlightAlert({
    required this.id,
    required this.level,
    required this.message,
  });
}

/// 实时飞行数据快照（来自模拟器）
class FlightData {
  final double? airspeed;
  final double? machNumber;
  final double? altitude;
  final double? heading;
  final double? verticalSpeed;
  final double? gForce;
  final double? touchdownGearG;
  final double? noseGearG;
  final double? leftGearG;
  final double? rightGearG;
  final double? pitch;
  final double? bank;
  final double? angleOfAttack;
  final bool? stallWarning;
  final double? groundSpeed;
  final double? trueAirspeed;
  final double? latitude;
  final double? longitude;
  final String? departureAirport;
  final String? arrivalAirport;
  final double? com1Frequency;
  final double? outsideAirTemperature;
  final double? totalAirTemperature;
  final double? windSpeed;
  final double? windDirection;
  final double? windGust;
  final double? gustDelta;
  final double? gustFactorRate;
  final double? crosswindComponent;
  final double? radioAltitude;
  final double? baroPressure;
  final String? baroPressureUnit;
  final double? visibility;
  final int? numEngines;
  final double? fuelQuantity;
  final double? fuelFlow;
  final double? engine1N1;
  final double? engine2N1;
  final double? engine1N2;
  final double? engine2N2;
  final double? engine1EGT;
  final double? engine2EGT;
  final double? aileronInput;
  final double? elevatorInput;
  final double? rudderInput;
  final double? aileronTrim;
  final double? elevatorTrim;
  final double? rudderTrim;
  final bool? masterWarning;
  final bool? masterCaution;
  final bool? fireWarningEngine1;
  final bool? fireWarningEngine2;
  final bool? fireWarningAPU;
  final bool? beacon;
  final bool? strobes;
  final bool? navLights;
  final bool? logoLights;
  final bool? wingLights;
  final bool? landingLights;
  final bool? taxiLights;
  final bool? runwayTurnoffLights;
  final bool? wheelWellLights;
  final bool? onGround;
  final bool? parkingBrake;
  final bool? speedBrake;
  final String? speedBrakeLabel;
  final bool? spoilersDeployed;
  final String? autoBrakeLabel;
  final bool? flapsDeployed;
  final String? flapsLabel;
  final double? flapsAngle;
  final double? flapsDeployRatio;
  final bool? gearDown;
  final double? noseGearDown;
  final double? leftGearDown;
  final double? rightGearDown;
  final bool? apuRunning;
  final bool? engine1Running;
  final bool? engine2Running;
  final bool? autopilotEngaged;
  final bool? autothrottleEngaged;
  final double? autopilotHeadingTarget;
  final String? autopilotLateralMode;
  final String? autopilotVerticalMode;
  final String? aircraftProfile;
  final String? aircraftId;
  final String? aircraftManufacturer;
  final String? aircraftFamily;
  final String? aircraftModel;
  final String? aircraftIcao;
  final String? aircraftDisplayName;
  final String? flightPhase;
  final String? flightAlertLevel;
  final List<FlightAlert> flightAlerts;

  const FlightData({
    this.airspeed,
    this.machNumber,
    this.altitude,
    this.heading,
    this.verticalSpeed,
    this.gForce,
    this.touchdownGearG,
    this.noseGearG,
    this.leftGearG,
    this.rightGearG,
    this.pitch,
    this.bank,
    this.angleOfAttack,
    this.stallWarning,
    this.groundSpeed,
    this.trueAirspeed,
    this.latitude,
    this.longitude,
    this.departureAirport,
    this.arrivalAirport,
    this.com1Frequency,
    this.outsideAirTemperature,
    this.totalAirTemperature,
    this.windSpeed,
    this.windDirection,
    this.windGust,
    this.gustDelta,
    this.gustFactorRate,
    this.crosswindComponent,
    this.radioAltitude,
    this.baroPressure,
    this.baroPressureUnit,
    this.visibility,
    this.numEngines,
    this.fuelQuantity,
    this.fuelFlow,
    this.engine1N1,
    this.engine2N1,
    this.engine1N2,
    this.engine2N2,
    this.engine1EGT,
    this.engine2EGT,
    this.aileronInput,
    this.elevatorInput,
    this.rudderInput,
    this.aileronTrim,
    this.elevatorTrim,
    this.rudderTrim,
    this.masterWarning,
    this.masterCaution,
    this.fireWarningEngine1,
    this.fireWarningEngine2,
    this.fireWarningAPU,
    this.beacon,
    this.strobes,
    this.navLights,
    this.logoLights,
    this.wingLights,
    this.landingLights,
    this.taxiLights,
    this.runwayTurnoffLights,
    this.wheelWellLights,
    this.onGround,
    this.parkingBrake,
    this.speedBrake,
    this.speedBrakeLabel,
    this.spoilersDeployed,
    this.autoBrakeLabel,
    this.flapsDeployed,
    this.flapsLabel,
    this.flapsAngle,
    this.flapsDeployRatio,
    this.gearDown,
    this.noseGearDown,
    this.leftGearDown,
    this.rightGearDown,
    this.apuRunning,
    this.engine1Running,
    this.engine2Running,
    this.autopilotEngaged,
    this.autothrottleEngaged,
    this.autopilotHeadingTarget,
    this.autopilotLateralMode,
    this.autopilotVerticalMode,
    this.aircraftProfile,
    this.aircraftId,
    this.aircraftManufacturer,
    this.aircraftFamily,
    this.aircraftModel,
    this.aircraftIcao,
    this.aircraftDisplayName,
    this.flightPhase,
    this.flightAlertLevel,
    this.flightAlerts = const [],
  });
}

/// 应用级飞行数据快照（包含连接状态、机场、METAR 等聚合信息）
class FlightDataSnapshot {
  final bool isConnected;
  final bool isBackendReachable;
  final int backendOutageVersion;
  final SimulatorType simulatorType;
  final String? errorMessage;
  final String? aircraftTitle;
  final bool? isPaused;
  final String? transponderState;
  final String? transponderCode;
  final String? flightNumber;
  final bool? isFuelSufficient;
  final FlightChecklistPhase? checklistPhase;
  final double? checklistProgress;
  final FlightData flightData;
  final AirportInfo? departureAirport;
  final AirportInfo? destinationAirport;
  final AirportInfo? alternateAirport;
  final AirportInfo? nearestAirport;
  final List<AirportInfo> suggestedAirports;
  final Map<String, LiveMetarData> metarsByIcao;
  final Map<String, String> metarErrorsByIcao;
  final Set<String> metarRefreshingIcaos;

  const FlightDataSnapshot({
    required this.isConnected,
    this.isBackendReachable = false,
    this.backendOutageVersion = 0,
    required this.simulatorType,
    required this.flightData,
    required this.suggestedAirports,
    required this.metarsByIcao,
    required this.metarErrorsByIcao,
    required this.metarRefreshingIcaos,
    this.errorMessage,
    this.aircraftTitle,
    this.isPaused,
    this.transponderState,
    this.transponderCode,
    this.flightNumber,
    this.isFuelSufficient,
    this.checklistPhase,
    this.checklistProgress,
    this.departureAirport,
    this.destinationAirport,
    this.alternateAirport,
    this.nearestAirport,
  });

  /// 构建空/未连接状态快照
  factory FlightDataSnapshot.empty() {
    return FlightDataSnapshot(
      isConnected: false,
      isBackendReachable: false,
      backendOutageVersion: 0,
      simulatorType: SimulatorType.none,
      flightData: const FlightData(),
      suggestedAirports: const [],
      metarsByIcao: const {},
      metarErrorsByIcao: const {},
      metarRefreshingIcaos: const <String>{},
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 向后兼容类型别名（原 Home 前缀命名）
// 保留以确保尚未迁移的旧引用可以正常编译，后续统一替换为新名称
// ──────────────────────────────────────────────────────────────────────────

/// @deprecated 请使用 [SimulatorType]
typedef HomeSimulatorType = SimulatorType;

/// @deprecated 请使用 [AirportInfo]
typedef HomeAirportInfo = AirportInfo;

/// @deprecated 请使用 [FlightChecklistPhase]
typedef HomeChecklistPhase = FlightChecklistPhase;

/// @deprecated 请使用 [FlightAlert]
typedef HomeFlightAlert = FlightAlert;

/// @deprecated 请使用 [FlightData]
typedef HomeFlightData = FlightData;

/// @deprecated 请使用 [FlightDataSnapshot]
typedef HomeDataSnapshot = FlightDataSnapshot;
