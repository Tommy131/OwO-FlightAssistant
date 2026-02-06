enum XPlaneDataRefKey {
  airspeed,
  altitude,
  heading,
  verticalSpeed,
  latitude,
  longitude,
  groundSpeed,
  trueAirspeed,
  parkingBrake,
  beaconLights,
  landingLightsMain,
  taxiLights,
  navLights,
  strobeLights,
  flapsRequest,
  gearDeploy,
  logoLights,
  wingLights,
  apuRunning,
  engine1Running,
  engine2Running,
  flapsAngle,
  wheelWellLights,
  autopilotMode,
  autothrottle,
  outsideTemp,
  totalTemp,
  windSpeed,
  windDirection,
  fuelTotal,
  fuelFlow,
  engine1N1,
  engine2N1,
  engine1EGT,
  engine2EGT,
  gForce,
  baroPressure,
  isPaused,
  onGround,
  numEngines,
  flapDetents,
  com1Frequency,
  landingLight0,
  landingLight1,
  landingLight2,
  landingLight3,
  runwayTurnoffLeft,
  runwayTurnoffRight,
  noseGearDeploy,
  leftGearDeploy,
  rightGearDeploy,
  speedBrakeRatio,
  spoilersDeployed,
  flapsDeployRatio,
  flapsActualDegrees,
  flapsLeverZibo,
  autoBrake,
  autoBrakeZibo,
  masterWarning,
  masterCaution,
  fireWarningEng1,
  fireWarningEng2,
  fireWarningAPU,
  visibility,
}

/// X-Plane DataRef 配置项
class XPlaneDataRef {
  final XPlaneDataRefKey key;
  final String path;
  final String description;

  const XPlaneDataRef({
    required this.key,
    required this.path,
    required this.description,
  });

  /// 获取对应的 X-Plane 订阅索引
  int get index => key.index;
}

/// X-Plane DataRefs 配置管理
///
/// 集中管理所有订阅的 DataRef，方便维护和扩展
class XPlaneDataRefs {
  // ==================== 飞行数据 ====================

  static const XPlaneDataRef airspeed = XPlaneDataRef(
    key: XPlaneDataRefKey.airspeed,
    path: 'sim/flightmodel/position/indicated_airspeed',
    description: '指示空速',
  );

  static const XPlaneDataRef altitude = XPlaneDataRef(
    key: XPlaneDataRefKey.altitude,
    path: 'sim/flightmodel/position/elevation',
    description: '高度',
  );

  static const XPlaneDataRef heading = XPlaneDataRef(
    key: XPlaneDataRefKey.heading,
    path: 'sim/flightmodel/position/mag_psi',
    description: '磁航向',
  );

  static const XPlaneDataRef verticalSpeed = XPlaneDataRef(
    key: XPlaneDataRefKey.verticalSpeed,
    path: 'sim/flightmodel/position/vh_ind',
    description: '垂直速度',
  );

  // ==================== 位置和导航 ====================

  static const XPlaneDataRef latitude = XPlaneDataRef(
    key: XPlaneDataRefKey.latitude,
    path: 'sim/flightmodel/position/latitude',
    description: '纬度',
  );

  static const XPlaneDataRef longitude = XPlaneDataRef(
    key: XPlaneDataRefKey.longitude,
    path: 'sim/flightmodel/position/longitude',
    description: '经度',
  );

  static const XPlaneDataRef groundSpeed = XPlaneDataRef(
    key: XPlaneDataRefKey.groundSpeed,
    path: 'sim/flightmodel/position/groundspeed',
    description: '地速',
  );

  static const XPlaneDataRef trueAirspeed = XPlaneDataRef(
    key: XPlaneDataRefKey.trueAirspeed,
    path: 'sim/flightmodel/position/true_airspeed',
    description: '真空速',
  );

  // ==================== 系统状态 ====================

  static const XPlaneDataRef parkingBrake = XPlaneDataRef(
    key: XPlaneDataRefKey.parkingBrake,
    path: 'sim/flightmodel/controls/parkbrake',
    description: '停机刹车状态',
  );

  static const XPlaneDataRef beaconLights = XPlaneDataRef(
    key: XPlaneDataRefKey.beaconLights,
    path: 'sim/cockpit/electrical/beacon_lights_on',
    description: '信标灯',
  );

  static const XPlaneDataRef landingLightsMain = XPlaneDataRef(
    key: XPlaneDataRefKey.landingLightsMain,
    path: 'sim/cockpit2/switches/landing_lights_on',
    description: '着陆灯主开关',
  );

  static const XPlaneDataRef taxiLights = XPlaneDataRef(
    key: XPlaneDataRefKey.taxiLights,
    path: 'sim/cockpit2/switches/generic_lights_switch[4]',
    description: '滑行灯',
  );

  static const XPlaneDataRef navLights = XPlaneDataRef(
    key: XPlaneDataRefKey.navLights,
    path: 'sim/cockpit2/switches/navigation_lights_on',
    description: '航行灯',
  );

  static const XPlaneDataRef strobeLights = XPlaneDataRef(
    key: XPlaneDataRefKey.strobeLights,
    path: 'sim/cockpit/electrical/strobe_lights_on',
    description: '频闪灯',
  );

  static const XPlaneDataRef flapsRequest = XPlaneDataRef(
    key: XPlaneDataRefKey.flapsRequest,
    path: 'sim/flightmodel/controls/flaprqst',
    description: '襟翼请求',
  );

  static const XPlaneDataRef gearDeploy = XPlaneDataRef(
    key: XPlaneDataRefKey.gearDeploy,
    path: 'sim/aircraft/parts/acf_gear_deploy',
    description: '起落架放下',
  );

  static const XPlaneDataRef logoLights = XPlaneDataRef(
    key: XPlaneDataRefKey.logoLights,
    path: 'sim/cockpit2/switches/generic_lights_switch[1]',
    description: 'Logo灯',
  );

  static const XPlaneDataRef wingLights = XPlaneDataRef(
    key: XPlaneDataRefKey.wingLights,
    path: 'sim/cockpit2/switches/generic_lights_switch[0]',
    description: '机翼灯',
  );

  // ==================== 发动机与燃油 ====================

  static const XPlaneDataRef apuRunning = XPlaneDataRef(
    key: XPlaneDataRefKey.apuRunning,
    path: 'sim/cockpit/engine/APU_running',
    description: 'APU运行',
  );

  static const XPlaneDataRef engine1Running = XPlaneDataRef(
    key: XPlaneDataRefKey.engine1Running,
    path: 'sim/flightmodel/engine/ENGN_running[0]',
    description: '发动机1运行',
  );

  static const XPlaneDataRef engine2Running = XPlaneDataRef(
    key: XPlaneDataRefKey.engine2Running,
    path: 'sim/flightmodel/engine/ENGN_running[1]',
    description: '发动机2运行',
  );

  static const XPlaneDataRef flapsAngle = XPlaneDataRef(
    key: XPlaneDataRefKey.flapsAngle,
    path: 'sim/flightmodel2/controls/flap_handle_deploy_ratio',
    description: '襟翼角度',
  );

  static const XPlaneDataRef wheelWellLights = XPlaneDataRef(
    key: XPlaneDataRefKey.wheelWellLights,
    path: 'sim/cockpit2/switches/generic_lights_switch[5]',
    description: '轮舱灯',
  );

  // ==================== 自动驾驶 ====================

  static const XPlaneDataRef autopilotMode = XPlaneDataRef(
    key: XPlaneDataRefKey.autopilotMode,
    path: 'sim/cockpit/autopilot/autopilot_mode',
    description: '自动驾驶模式',
  );

  static const XPlaneDataRef autothrottle = XPlaneDataRef(
    key: XPlaneDataRefKey.autothrottle,
    path: 'sim/cockpit/autopilot/autothrottle_enabled',
    description: '自动油门',
  );

  // ==================== 环境数据 ====================

  static const XPlaneDataRef outsideTemp = XPlaneDataRef(
    key: XPlaneDataRefKey.outsideTemp,
    path: 'sim/weather/temperature_ambient_c',
    description: '外部温度',
  );

  static const XPlaneDataRef totalTemp = XPlaneDataRef(
    key: XPlaneDataRefKey.totalTemp,
    path: 'sim/weather/temperature_le_c',
    description: '总温度',
  );

  static const XPlaneDataRef windSpeed = XPlaneDataRef(
    key: XPlaneDataRefKey.windSpeed,
    path: 'sim/weather/wind_speed_kt',
    description: '风速',
  );

  static const XPlaneDataRef windDirection = XPlaneDataRef(
    key: XPlaneDataRefKey.windDirection,
    path: 'sim/weather/wind_direction_degt',
    description: '风向',
  );

  static const XPlaneDataRef visibility = XPlaneDataRef(
    key: XPlaneDataRefKey.visibility,
    path: 'sim/weather/visibility_reported_m',
    description: '能见度',
  );

  // ==================== 燃油 ====================

  static const XPlaneDataRef fuelTotal = XPlaneDataRef(
    key: XPlaneDataRefKey.fuelTotal,
    path: 'sim/flightmodel/weight/m_fuel_total',
    description: '总燃油',
  );

  static const XPlaneDataRef fuelFlow = XPlaneDataRef(
    key: XPlaneDataRefKey.fuelFlow,
    path: 'sim/cockpit2/engine/indicators/fuel_flow_kg_sec[0]',
    description: '燃油流量',
  );

  // ==================== 发动机参数 ====================

  static const XPlaneDataRef engine1N1 = XPlaneDataRef(
    key: XPlaneDataRefKey.engine1N1,
    path: 'sim/flightmodel/engine/ENGN_N1_[0]',
    description: '发动机1 N1',
  );

  static const XPlaneDataRef engine2N1 = XPlaneDataRef(
    key: XPlaneDataRefKey.engine2N1,
    path: 'sim/flightmodel/engine/ENGN_N1_[1]',
    description: '发动机2 N1',
  );

  static const XPlaneDataRef engine1EGT = XPlaneDataRef(
    key: XPlaneDataRefKey.engine1EGT,
    path: 'sim/flightmodel/engine/ENGN_EGT_c[0]',
    description: '发动机1 EGT',
  );

  static const XPlaneDataRef engine2EGT = XPlaneDataRef(
    key: XPlaneDataRefKey.engine2EGT,
    path: 'sim/flightmodel/engine/ENGN_EGT_c[1]',
    description: '发动机2 EGT',
  );

  // ==================== 监控数据 ====================

  static const XPlaneDataRef gForce = XPlaneDataRef(
    key: XPlaneDataRefKey.gForce,
    path: 'sim/flightmodel/forces/g_nrml',
    description: 'G力',
  );

  static const XPlaneDataRef baroPressure = XPlaneDataRef(
    key: XPlaneDataRefKey.baroPressure,
    path: 'sim/weather/barometer_current_inhg',
    description: '气压',
  );

  // ==================== 模拟器状态 ====================

  static const XPlaneDataRef isPaused = XPlaneDataRef(
    key: XPlaneDataRefKey.isPaused,
    path: 'sim/time/paused',
    description: '暂停状态',
  );

  static const XPlaneDataRef onGround = XPlaneDataRef(
    key: XPlaneDataRefKey.onGround,
    path: 'sim/flightmodel/failures/onground_any',
    description: '地面状态',
  );

  static const XPlaneDataRef numEngines = XPlaneDataRef(
    key: XPlaneDataRefKey.numEngines,
    path: 'sim/aircraft/engine/acf_num_engines',
    description: '发动机数量',
  );

  static const XPlaneDataRef flapDetents = XPlaneDataRef(
    key: XPlaneDataRefKey.flapDetents,
    path: 'sim/aircraft/controls/acf_flap_detents',
    description: '襟翼档位数',
  );

  static const XPlaneDataRef com1Frequency = XPlaneDataRef(
    key: XPlaneDataRefKey.com1Frequency,
    path: 'sim/cockpit2/radios/actuators/com1_frequency_hz',
    description: 'COM1频率',
  );

  // ==================== 灯光开关数组 ====================

  static const XPlaneDataRef landingLight0 = XPlaneDataRef(
    key: XPlaneDataRefKey.landingLight0,
    path: 'sim/cockpit2/switches/landing_lights_switch[0]',
    description: '着陆灯开关0',
  );

  static const XPlaneDataRef landingLight1 = XPlaneDataRef(
    key: XPlaneDataRefKey.landingLight1,
    path: 'sim/cockpit2/switches/landing_lights_switch[1]',
    description: '着陆灯开关1',
  );

  static const XPlaneDataRef landingLight2 = XPlaneDataRef(
    key: XPlaneDataRefKey.landingLight2,
    path: 'sim/cockpit2/switches/landing_lights_switch[2]',
    description: '着陆灯开关2',
  );

  static const XPlaneDataRef landingLight3 = XPlaneDataRef(
    key: XPlaneDataRefKey.landingLight3,
    path: 'sim/cockpit2/switches/landing_lights_switch[3]',
    description: '着陆灯开关3',
  );

  static const XPlaneDataRef runwayTurnoffLeft = XPlaneDataRef(
    key: XPlaneDataRefKey.runwayTurnoffLeft,
    path: 'sim/cockpit2/switches/generic_lights_switch[2]',
    description: '跑道脱离灯左',
  );

  static const XPlaneDataRef runwayTurnoffRight = XPlaneDataRef(
    key: XPlaneDataRefKey.runwayTurnoffRight,
    path: 'sim/cockpit2/switches/generic_lights_switch[3]',
    description: '跑道脱离灯右',
  );

  // ==================== 起落架详细状态 ====================

  static const XPlaneDataRef noseGearDeploy = XPlaneDataRef(
    key: XPlaneDataRefKey.noseGearDeploy,
    path: 'sim/flightmodel2/gear/deploy_ratio[0]',
    description: '前起落架展开比例',
  );

  static const XPlaneDataRef leftGearDeploy = XPlaneDataRef(
    key: XPlaneDataRefKey.leftGearDeploy,
    path: 'sim/flightmodel2/gear/deploy_ratio[1]',
    description: '左主起落架展开比例',
  );

  static const XPlaneDataRef rightGearDeploy = XPlaneDataRef(
    key: XPlaneDataRefKey.rightGearDeploy,
    path: 'sim/flightmodel2/gear/deploy_ratio[2]',
    description: '右主起落架展开比例',
  );

  // ==================== 减速板与扰流板 ====================

  static const XPlaneDataRef speedBrakeRatio = XPlaneDataRef(
    key: XPlaneDataRefKey.speedBrakeRatio,
    path: 'sim/cockpit2/controls/speedbrake_ratio',
    description: '速度刹车/减速板位置',
  );

  static const XPlaneDataRef spoilersDeployed = XPlaneDataRef(
    key: XPlaneDataRefKey.spoilersDeployed,
    path: 'sim/flightmodel2/wing/spoiler1_deg[0]',
    description: '扰流板展开角度',
  );

  // ==================== 襟翼状态 ====================

  static const XPlaneDataRef flapsDeployRatio = XPlaneDataRef(
    key: XPlaneDataRefKey.flapsDeployRatio,
    path: 'sim/flightmodel2/controls/flap_handle_deploy_ratio',
    description: '襟翼手柄展开比例',
  );

  static const XPlaneDataRef flapsActualDegrees = XPlaneDataRef(
    key: XPlaneDataRefKey.flapsActualDegrees,
    path: 'sim/flightmodel2/wing/flap1_deg[0]',
    description: '襟翼实际角度',
  );

  static const XPlaneDataRef flapsLeverZibo = XPlaneDataRef(
    key: XPlaneDataRefKey.flapsLeverZibo,
    path: 'laminar/B738/flt_ctrls/flap_lever',
    description: 'ZIBO 738襟翼手柄位置',
  );

  // ==================== 自动刹车 ====================

  static const XPlaneDataRef autoBrake = XPlaneDataRef(
    key: XPlaneDataRefKey.autoBrake,
    path: 'sim/cockpit2/switches/auto_brake_level',
    description: '自动刹车挡位（通用）',
  );

  static const XPlaneDataRef autoBrakeZibo = XPlaneDataRef(
    key: XPlaneDataRefKey.autoBrakeZibo,
    path: 'laminar/B738/autobrake/autobrake_pos',
    description: 'ZIBO 738自动刹车位置',
  );

  // ==================== 警告系统 ====================

  static const XPlaneDataRef masterWarning = XPlaneDataRef(
    key: XPlaneDataRefKey.masterWarning,
    path: 'sim/cockpit2/annunciators/master_warning',
    description: '主警告',
  );

  static const XPlaneDataRef masterCaution = XPlaneDataRef(
    key: XPlaneDataRefKey.masterCaution,
    path: 'sim/cockpit2/annunciators/master_caution',
    description: '主告警',
  );

  static const XPlaneDataRef fireWarningEng1 = XPlaneDataRef(
    key: XPlaneDataRefKey.fireWarningEng1,
    path: 'sim/cockpit2/annunciators/fire_warning[0]',
    description: '发动机1火警',
  );

  static const XPlaneDataRef fireWarningEng2 = XPlaneDataRef(
    key: XPlaneDataRefKey.fireWarningEng2,
    path: 'sim/cockpit2/annunciators/fire_warning[1]',
    description: '发动机2火警',
  );

  static const XPlaneDataRef fireWarningAPU = XPlaneDataRef(
    key: XPlaneDataRefKey.fireWarningAPU,
    path: 'sim/cockpit2/annunciators/fire_warning[2]',
    description: 'APU火警',
  );

  // ==================== 获取所有DataRefs ====================

  /// 获取所有需要订阅的 DataRef 列表
  static List<XPlaneDataRef> getAllDataRefs() {
    return [
      // 飞行数据
      airspeed, altitude, heading, verticalSpeed,
      // 位置和导航
      latitude, longitude, groundSpeed, trueAirspeed,
      // 环境数据
      outsideTemp, totalTemp, windSpeed, windDirection,
      // 模拟器状态
      isPaused, onGround,
      // 系统状态
      parkingBrake, beaconLights,
      // 灯光
      landingLightsMain,
      landingLight0,
      landingLight1,
      landingLight2,
      landingLight3,
      taxiLights, navLights, strobeLights, logoLights, wingLights,
      runwayTurnoffLeft, runwayTurnoffRight, wheelWellLights,
      // 襟翼和起落架
      flapsRequest, flapsAngle, gearDeploy,
      // 燃油和发动机
      fuelTotal, fuelFlow,
      apuRunning, engine1Running, engine2Running,
      engine1N1, engine2N1, engine1EGT, engine2EGT,
      // 自动驾驶
      autopilotMode, autothrottle,
      // 监控数据
      gForce, baroPressure,
      // 机型辅助
      numEngines, flapDetents, com1Frequency,
      // 起落架详细状态
      noseGearDeploy, leftGearDeploy, rightGearDeploy,
      // 襟翼状态
      flapsDeployRatio, flapsActualDegrees, flapsLeverZibo,
      // 减速板与扰流板
      speedBrakeRatio, spoilersDeployed,
      // 自动刹车
      autoBrake, autoBrakeZibo,
      // 警告系统
      masterWarning, masterCaution,
      fireWarningEng1, fireWarningEng2, fireWarningAPU,
      visibility,
    ];
  }
}
