import '../data/aircraft_catalog.dart';

class SimulatorData {
  final bool isConnected;
  final String? aircraftTitle;
  final String? aircraftType;
  final AircraftIdentity? identity;

  // 模拟器状态
  final bool? isPaused; // 模拟器是否暂停

  // 飞行数据
  final double? airspeed;
  final double? altitude;
  final double? heading;
  final double? verticalSpeed;
  final double? gForce; // 重力加速度
  final double? baroPressure; // 气压 (inHg 或 hPa)
  final String? baroPressureUnit; // 气压单位 (inHg 或 hPa)
  final double? machNumber; // 马赫数

  // 位置和导航
  final double? latitude;
  final double? longitude;
  final double? groundSpeed;
  final double? trueAirspeed;
  final String? departureAirport;
  final String? arrivalAirport;

  // 环境数据
  final double? outsideAirTemperature;
  final double? totalAirTemperature;
  final double? windSpeed;
  final double? windDirection;
  final double? visibility; // 可见度 (米 或 海里)

  // 系统状态
  final bool? parkingBrake;
  final bool? beacon;
  final bool? landingLights;
  final bool? taxiLights;
  final bool? navLights;
  final bool? strobes;
  final bool? logoLights; // Logo灯
  final bool? wingLights; // 机翼灯
  final bool? wheelWellLights; // 轮舱灯
  final bool? runwayTurnoffLights; // 跑道脱离灯
  final int? flapsPosition;
  final int? flapDetentsCount; // 襟翼挡位数量 (总数)
  final int? numEngines;
  final double? wingArea;
  final double? flapsAngle; // 襟翼角度(度)
  final double? flapsDeployRatio; // 襟翼展开比例 (0-1)
  final bool? flapsDeployed; // 襟翼是否展开
  final String? flapsLabel; // 襟翼档位标签（如 "UP", "1", "5", "15" 等）
  final bool? gearDown;
  final bool? onGround; // 是否在地面

  // 起落架详细状态
  final double? noseGearDown; // 前起落架 (0=UP, 1=DN)
  final double? leftGearDown; // 左主起落架
  final double? rightGearDown; // 右主起落架

  // 减速与刹车系统
  final bool? speedBrake; // 减速板/速度刹车
  final double? speedBrakePosition; // 减速板位置 (0-1)
  final bool? spoilersDeployed; // 扰流板展开
  final int? autoBrakeLevel; // 自动刹车挡位 (0=OFF, 1-5)
  // 警告系统
  final bool? masterWarning; // 主警告
  final bool? masterCaution; // 主告警
  final bool? fireWarningEngine1; // 发动机1火警
  final bool? fireWarningEngine2; // 发动机2火警
  final bool? fireWarningAPU; // APU火警

  // 燃油和发动机
  final double? fuelQuantity;
  final double? fuelFlow;
  final bool? apuRunning;
  final bool? engine1Running;
  final bool? engine2Running;
  final double? engine1N1;
  final double? engine2N1;
  final double? engine1EGT;
  final double? engine2EGT;

  // 自动驾驶状态
  final bool? autopilotEngaged;
  final bool? autothrottleEngaged;

  // 扩展机场数据
  final String? activeRunway;
  final double? com1Frequency;

  SimulatorData({
    this.isConnected = false,
    this.aircraftTitle,
    this.aircraftType,
    this.identity,
    this.isPaused,
    this.airspeed,
    this.altitude,
    this.heading,
    this.verticalSpeed,
    this.latitude,
    this.longitude,
    this.groundSpeed,
    this.trueAirspeed,
    this.outsideAirTemperature,
    this.totalAirTemperature,
    this.windSpeed,
    this.windDirection,
    this.visibility,
    this.parkingBrake,
    this.beacon,
    this.landingLights,
    this.taxiLights,
    this.navLights,
    this.strobes,
    this.logoLights,
    this.wingLights,
    this.wheelWellLights, // 轮舱灯
    this.runwayTurnoffLights,
    this.flapsPosition,
    this.flapDetentsCount,
    this.numEngines,
    this.wingArea,
    this.flapsAngle,
    this.flapsDeployRatio,
    this.flapsDeployed,
    this.flapsLabel,
    this.gearDown,
    this.onGround,
    // 起落架详细状态
    this.noseGearDown,
    this.leftGearDown,
    this.rightGearDown,
    // 减速与刹车系统
    this.speedBrake,
    this.speedBrakePosition,
    this.spoilersDeployed,
    this.autoBrakeLevel,
    // 警告系统
    this.masterWarning,
    this.masterCaution,
    this.fireWarningEngine1,
    this.fireWarningEngine2,
    this.fireWarningAPU,
    this.fuelQuantity,
    this.fuelFlow,
    this.apuRunning,
    this.engine1Running,
    this.engine2Running,
    this.engine1N1,
    this.engine2N1,
    this.engine1EGT,
    this.engine2EGT,
    this.departureAirport,
    this.arrivalAirport,
    this.autopilotEngaged,
    this.autothrottleEngaged,
    this.activeRunway,
    this.com1Frequency,
    this.gForce,
    this.baroPressure,
    this.baroPressureUnit,
    this.machNumber,
  });

  factory SimulatorData.empty() {
    return SimulatorData(isConnected: false, gForce: 1.0, baroPressure: 29.92);
  }

  SimulatorData copyWith({
    bool? isConnected,
    String? aircraftTitle,
    String? aircraftType,
    AircraftIdentity? identity,
    bool? isPaused,
    double? airspeed,
    double? altitude,
    double? heading,
    double? verticalSpeed,
    double? latitude,
    double? longitude,
    double? groundSpeed,
    double? trueAirspeed,
    double? outsideAirTemperature,
    double? totalAirTemperature,
    double? windSpeed,
    double? windDirection,
    double? visibility,
    bool? parkingBrake,
    bool? beacon,
    bool? landingLights,
    bool? taxiLights,
    bool? navLights,
    bool? strobes,
    bool? logoLights,
    bool? wingLights,
    bool? wheelWellLights,
    bool? runwayTurnoffLights,
    int? flapsPosition,
    int? flapDetentsCount,
    int? numEngines,
    double? wingArea,
    double? flapsAngle,
    double? flapsDeployRatio,
    bool? flapsDeployed,
    String? flapsLabel,
    bool? gearDown,
    bool? onGround,
    // 起落架详细状态
    double? noseGearDown,
    double? leftGearDown,
    double? rightGearDown,
    // 减速与刹车系统
    bool? speedBrake,
    double? speedBrakePosition,
    bool? spoilersDeployed,
    int? autoBrakeLevel,
    // 警告系统
    bool? masterWarning,
    bool? masterCaution,
    bool? fireWarningEngine1,
    bool? fireWarningEngine2,
    bool? fireWarningAPU,
    double? fuelQuantity,
    double? fuelFlow,
    bool? apuRunning,
    bool? engine1Running,
    bool? engine2Running,
    double? engine1N1,
    double? engine2N1,
    double? engine1EGT,
    double? engine2EGT,
    String? departureAirport,
    String? arrivalAirport,
    bool? autopilotEngaged,
    bool? autothrottleEngaged,
    String? activeRunway,
    double? com1Frequency,
    double? gForce,
    double? baroPressure,
    String? baroPressureUnit,
    double? machNumber,
  }) {
    return SimulatorData(
      isConnected: isConnected ?? this.isConnected,
      aircraftTitle: aircraftTitle ?? this.aircraftTitle,
      aircraftType: aircraftType ?? this.aircraftType,
      identity: identity ?? this.identity,
      isPaused: isPaused ?? this.isPaused,
      airspeed: airspeed ?? this.airspeed,
      altitude: altitude ?? this.altitude,
      heading: heading ?? this.heading,
      verticalSpeed: verticalSpeed ?? this.verticalSpeed,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      groundSpeed: groundSpeed ?? this.groundSpeed,
      trueAirspeed: trueAirspeed ?? this.trueAirspeed,
      outsideAirTemperature:
          outsideAirTemperature ?? this.outsideAirTemperature,
      totalAirTemperature: totalAirTemperature ?? this.totalAirTemperature,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
      visibility: visibility ?? this.visibility,
      parkingBrake: parkingBrake ?? this.parkingBrake,
      beacon: beacon ?? this.beacon,
      landingLights: landingLights ?? this.landingLights,
      taxiLights: taxiLights ?? this.taxiLights,
      navLights: navLights ?? this.navLights,
      strobes: strobes ?? this.strobes,
      logoLights: logoLights ?? this.logoLights,
      wingLights: wingLights ?? this.wingLights,
      wheelWellLights: wheelWellLights ?? this.wheelWellLights,
      runwayTurnoffLights: runwayTurnoffLights ?? this.runwayTurnoffLights,
      flapsPosition: flapsPosition ?? this.flapsPosition,
      flapDetentsCount: flapDetentsCount ?? this.flapDetentsCount,
      numEngines: numEngines ?? this.numEngines,
      wingArea: wingArea ?? this.wingArea,
      flapsAngle: flapsAngle ?? this.flapsAngle,
      flapsDeployRatio: flapsDeployRatio ?? this.flapsDeployRatio,
      flapsDeployed: flapsDeployed ?? this.flapsDeployed,
      flapsLabel: flapsLabel ?? this.flapsLabel,
      gearDown: gearDown ?? this.gearDown,
      onGround: onGround ?? this.onGround,
      // 起落架详细状态
      noseGearDown: noseGearDown ?? this.noseGearDown,
      leftGearDown: leftGearDown ?? this.leftGearDown,
      rightGearDown: rightGearDown ?? this.rightGearDown,
      // 减速与刹车系统
      speedBrake: speedBrake ?? this.speedBrake,
      speedBrakePosition: speedBrakePosition ?? this.speedBrakePosition,
      spoilersDeployed: spoilersDeployed ?? this.spoilersDeployed,
      autoBrakeLevel: autoBrakeLevel ?? this.autoBrakeLevel,
      // 警告系统
      masterWarning: masterWarning ?? this.masterWarning,
      masterCaution: masterCaution ?? this.masterCaution,
      fireWarningEngine1: fireWarningEngine1 ?? this.fireWarningEngine1,
      fireWarningEngine2: fireWarningEngine2 ?? this.fireWarningEngine2,
      fireWarningAPU: fireWarningAPU ?? this.fireWarningAPU,
      fuelQuantity: fuelQuantity ?? this.fuelQuantity,
      fuelFlow: fuelFlow ?? this.fuelFlow,
      apuRunning: apuRunning ?? this.apuRunning,
      engine1Running: engine1Running ?? this.engine1Running,
      engine2Running: engine2Running ?? this.engine2Running,
      engine1N1: engine1N1 ?? this.engine1N1,
      engine2N1: engine2N1 ?? this.engine2N1,
      engine1EGT: engine1EGT ?? this.engine1EGT,
      engine2EGT: engine2EGT ?? this.engine2EGT,
      departureAirport: departureAirport ?? this.departureAirport,
      arrivalAirport: arrivalAirport ?? this.arrivalAirport,
      autopilotEngaged: autopilotEngaged ?? this.autopilotEngaged,
      autothrottleEngaged: autothrottleEngaged ?? this.autothrottleEngaged,
      activeRunway: activeRunway ?? this.activeRunway,
      com1Frequency: com1Frequency ?? this.com1Frequency,
      gForce: gForce ?? this.gForce,
      baroPressure: baroPressure ?? this.baroPressure,
      baroPressureUnit: baroPressureUnit ?? this.baroPressureUnit,
      machNumber: machNumber ?? this.machNumber,
    );
  }

  /// 获取自动刹车挡位文本 (支持机型自动识别)
  /// 获取自动刹车挡位文本
  String get autoBrakeLabel {
    if (identity != null) {
      return identity!.formatAutoBrake(autoBrakeLevel);
    }
    // 回退到通用逻辑
    if (autoBrakeLevel == null || autoBrakeLevel == 0) return 'OFF';
    if (autoBrakeLevel == -1) return 'RTO';
    if (autoBrakeLevel == 4) return 'MAX';
    return autoBrakeLevel.toString();
  }

  /// 获取减速板展开文本
  String get speedBrakeLabel {
    if (identity != null) {
      return identity!.formatSpeedBrake(speedBrake, speedBrakePosition);
    }
    // 回退到通用逻辑
    if (speedBrake != true) return 'RETRACTED';
    final pos = (speedBrakePosition ?? 0) * 100;
    if (pos <= 0.01) return 'ARMED';
    return 'DEPLOYED (${pos.toStringAsFixed(0)}%)';
  }
}
