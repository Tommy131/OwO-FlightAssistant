class SimulatorData {
  final bool isConnected;
  final String? aircraftTitle;
  final String? aircraftType;

  // 模拟器状态
  final bool? isPaused; // 模拟器是否暂停

  // 飞行数据
  final double? airspeed;
  final double? altitude;
  final double? heading;
  final double? verticalSpeed;

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
  final double? flapsAngle; // 襟翼角度(度)
  final bool? gearDown;
  final bool? onGround; // 是否在地面

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
  final double? atisFrequency;

  SimulatorData({
    this.isConnected = false,
    this.aircraftTitle,
    this.aircraftType,
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
    this.flapsAngle,
    this.gearDown,
    this.onGround,
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
    this.atisFrequency,
  });

  factory SimulatorData.empty() {
    return SimulatorData();
  }

  SimulatorData copyWith({
    bool? isConnected,
    String? aircraftTitle,
    String? aircraftType,
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
    double? flapsAngle,
    bool? gearDown,
    bool? onGround,
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
    double? atisFrequency,
  }) {
    return SimulatorData(
      isConnected: isConnected ?? this.isConnected,
      aircraftTitle: aircraftTitle ?? this.aircraftTitle,
      aircraftType: aircraftType ?? this.aircraftType,
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
      flapsAngle: flapsAngle ?? this.flapsAngle,
      gearDown: gearDown ?? this.gearDown,
      onGround: onGround ?? this.onGround,
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
      atisFrequency: atisFrequency ?? this.atisFrequency,
    );
  }
}
