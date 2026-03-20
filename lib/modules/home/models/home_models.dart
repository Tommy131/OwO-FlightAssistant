import 'package:flutter/material.dart';

enum HomeSimulatorType { none, xplane, msfs }

class HomeAirportInfo {
  final String icaoCode;
  final String iataCode;
  final String name;
  final String nameChinese;
  final double latitude;
  final double longitude;

  const HomeAirportInfo({
    required this.icaoCode,
    required this.iataCode,
    required this.name,
    required this.nameChinese,
    required this.latitude,
    required this.longitude,
  });

  String get displayName => nameChinese.isNotEmpty ? nameChinese : name;
}

class HomeMetarData {
  final String raw;
  final DateTime timestamp;
  final String displayWind;
  final String displayVisibility;
  final String displayTemperature;
  final String displayAltimeter;

  const HomeMetarData({
    required this.raw,
    required this.timestamp,
    required this.displayWind,
    required this.displayVisibility,
    required this.displayTemperature,
    required this.displayAltimeter,
  });
}

class HomeChecklistPhase {
  final String labelKey;
  final IconData icon;

  const HomeChecklistPhase({required this.labelKey, required this.icon});
}

class HomeFlightAlert {
  final String id;
  final String level;
  final String message;

  const HomeFlightAlert({
    required this.id,
    required this.level,
    required this.message,
  });
}

class HomeFlightData {
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
  final List<HomeFlightAlert> flightAlerts;

  const HomeFlightData({
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

class HomeDataSnapshot {
  final bool isConnected;
  final bool isBackendReachable;
  final int backendOutageVersion;
  final HomeSimulatorType simulatorType;
  final String? errorMessage;
  final String? aircraftTitle;
  final bool? isPaused;
  final String? transponderState;
  final String? transponderCode;
  final String? flightNumber;
  final bool? isFuelSufficient;
  final HomeChecklistPhase? checklistPhase;
  final double? checklistProgress;
  final HomeFlightData flightData;
  final HomeAirportInfo? departureAirport;
  final HomeAirportInfo? destinationAirport;
  final HomeAirportInfo? alternateAirport;
  final HomeAirportInfo? nearestAirport;
  final List<HomeAirportInfo> suggestedAirports;
  final Map<String, HomeMetarData> metarsByIcao;
  final Map<String, String> metarErrorsByIcao;
  final Set<String> metarRefreshingIcaos;

  const HomeDataSnapshot({
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

  /// 功能：执行empty的核心业务流程。
  /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
  factory HomeDataSnapshot.empty() {
    return HomeDataSnapshot(
      isConnected: false,
      isBackendReachable: false,
      backendOutageVersion: 0,
      simulatorType: HomeSimulatorType.none,
      flightData: const HomeFlightData(),
      suggestedAirports: const [],
      metarsByIcao: const {},
      metarErrorsByIcao: const {},
      metarRefreshingIcaos: const <String>{},
    );
  }
}
