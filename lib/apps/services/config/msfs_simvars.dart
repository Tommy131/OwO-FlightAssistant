/// MSFS SimConnect 变量配置
class MSFSSimVar {
  final String name;
  final String unit;
  final String description;

  const MSFSSimVar({
    required this.name,
    required this.unit,
    required this.description,
  });

  /// 转换为订阅格式的 Map
  Map<String, String> toSubscriptionMap() {
    return {'name': name, 'unit': unit};
  }
}

/// MSFS SimConnect 变量配置管理
class MSFSSimVars {
  // ==================== 飞行数据 ====================

  static const MSFSSimVar airspeed = MSFSSimVar(
    name: 'AIRSPEED_INDICATED',
    unit: 'knots',
    description: '指示空速',
  );

  static const MSFSSimVar mach = MSFSSimVar(
    name: 'AIRSPEED_MACH',
    unit: 'mach',
    description: '马赫数',
  );

  static const MSFSSimVar altitude = MSFSSimVar(
    name: 'INDICATED_ALTITUDE',
    unit: 'feet',
    description: '指示高度',
  );

  static const MSFSSimVar heading = MSFSSimVar(
    name: 'PLANE_HEADING_DEGREES_MAGNETIC',
    unit: 'degrees',
    description: '磁航向',
  );

  static const MSFSSimVar verticalSpeed = MSFSSimVar(
    name: 'VERTICAL_SPEED',
    unit: 'feet per minute',
    description: '垂直速度',
  );

  static const MSFSSimVar pitch = MSFSSimVar(
    name: 'PLANE PITCH DEGREES',
    unit: 'degrees',
    description: '俯仰角',
  );

  static const MSFSSimVar roll = MSFSSimVar(
    name: 'PLANE BANK DEGREES',
    unit: 'degrees',
    description: '横滚角',
  );

  static const MSFSSimVar latitude = MSFSSimVar(
    name: 'PLANE_LATITUDE',
    unit: 'degrees',
    description: '纬度',
  );

  static const MSFSSimVar longitude = MSFSSimVar(
    name: 'PLANE_LONGITUDE',
    unit: 'degrees',
    description: '经度',
  );

  static const MSFSSimVar aircraftTitle = MSFSSimVar(
    name: 'TITLE',
    unit: 'string',
    description: '机型名称',
  );

  static const MSFSSimVar atcModel = MSFSSimVar(
    name: 'ATC MODEL',
    unit: 'string',
    description: '机型型号',
  );

  static const MSFSSimVar atcType = MSFSSimVar(
    name: 'ATC TYPE',
    unit: 'string',
    description: '机型类型',
  );

  static const MSFSSimVar atcId = MSFSSimVar(
    name: 'ATC ID',
    unit: 'string',
    description: '机身注册号',
  );

  // ==================== 系统状态 ====================

  static const MSFSSimVar parkingBrake = MSFSSimVar(
    name: 'BRAKE PARKING INDICATOR',
    unit: 'bool',
    description: '停机刹车指示',
  );

  static const MSFSSimVar beaconLight = MSFSSimVar(
    name: 'LIGHT_BEACON',
    unit: 'bool',
    description: '信标灯',
  );

  static const MSFSSimVar landingLight = MSFSSimVar(
    name: 'LIGHT_LANDING',
    unit: 'bool',
    description: '着陆灯',
  );

  static const MSFSSimVar taxiLight = MSFSSimVar(
    name: 'LIGHT_TAXI',
    unit: 'bool',
    description: '滑行灯',
  );

  static const MSFSSimVar navLight = MSFSSimVar(
    name: 'LIGHT_NAV',
    unit: 'bool',
    description: '航行灯',
  );

  static const MSFSSimVar strobeLight = MSFSSimVar(
    name: 'LIGHT_STROBE',
    unit: 'bool',
    description: '频闪灯',
  );

  static const MSFSSimVar flapsHandleIndex = MSFSSimVar(
    name: 'FLAPS_HANDLE_INDEX',
    unit: 'number',
    description: '襟翼手柄位置',
  );

  static const MSFSSimVar flapsHandlePositions = MSFSSimVar(
    name: 'FLAPS_NUM_HANDLE_POSITIONS',
    unit: 'number',
    description: '襟翼档位数量',
  );

  static const MSFSSimVar flapsDeployRatio = MSFSSimVar(
    name: 'TRAILING_EDGE_FLAPS_LEFT_PERCENT',
    unit: 'percent over 100',
    description: '襟翼展开比例',
  );

  // ==================== 发动机 ====================

  static const MSFSSimVar apuSwitch = MSFSSimVar(
    name: 'APU_SWITCH',
    unit: 'bool',
    description: 'APU开关',
  );

  static const MSFSSimVar engine1Combustion = MSFSSimVar(
    name: 'GENERAL_ENG_COMBUSTION:1',
    unit: 'bool',
    description: '发动机1燃烧',
  );

  static const MSFSSimVar engine2Combustion = MSFSSimVar(
    name: 'GENERAL_ENG_COMBUSTION:2',
    unit: 'bool',
    description: '发动机2燃烧',
  );

  static const MSFSSimVar engine1N1 = MSFSSimVar(
    name: 'ENG_N1:1',
    unit: 'percent',
    description: '发动机1 N1',
  );

  static const MSFSSimVar engine2N1 = MSFSSimVar(
    name: 'ENG_N1:2',
    unit: 'percent',
    description: '发动机2 N1',
  );

  static const MSFSSimVar engineCount = MSFSSimVar(
    name: 'NUMBER OF ENGINES',
    unit: 'number',
    description: '发动机数量',
  );

  // ==================== 自动驾驶 ====================

  static const MSFSSimVar autopilotMaster = MSFSSimVar(
    name: 'AUTOPILOT_MASTER',
    unit: 'bool',
    description: '自动驾驶主开关',
  );

  static const MSFSSimVar autopilotThrottle = MSFSSimVar(
    name: 'AUTOPILOT_THROTTLE_ARM',
    unit: 'bool',
    description: '自动油门',
  );

  // ==================== 监控数据 ====================

  static const MSFSSimVar gForce = MSFSSimVar(
    name: 'G FORCE',
    unit: 'number',
    description: 'G力',
  );

  static const MSFSSimVar barometerPressure = MSFSSimVar(
    name: 'BAROMETER PRESSURE',
    unit: 'Inches of Mercury',
    description: '气压',
  );

  // ====================  起落架详细状态 ====================

  static const MSFSSimVar noseGearPosition = MSFSSimVar(
    name: 'GEAR CENTER POSITION',
    unit: 'percent over 100',
    description: '前起落架位置',
  );

  static const MSFSSimVar leftGearPosition = MSFSSimVar(
    name: 'GEAR LEFT POSITION',
    unit: 'percent over 100',
    description: '左主起落架位置',
  );

  static const MSFSSimVar rightGearPosition = MSFSSimVar(
    name: 'GEAR RIGHT POSITION',
    unit: 'percent over 100',
    description: '右主起落架位置',
  );

  // ====================  减速板与扰流板 ====================

  static const MSFSSimVar speedBrakePosition = MSFSSimVar(
    name: 'SPOILERS HANDLE POSITION',
    unit: 'percent over 100',
    description: '减速板手柄位置',
  );

  static const MSFSSimVar spoilersDeployed = MSFSSimVar(
    name: 'SPOILERS LEFT POSITION',
    unit: 'percent over 100',
    description: '扰流板展开位置',
  );

  // ====================  自动刹车 ====================

  static const MSFSSimVar autoBrakeSwitch = MSFSSimVar(
    name: 'AUTOBRAKES_ACTIVE',
    unit: 'number',
    description: '自动刹车激活状态',
  );

  static const MSFSSimVar transponderState = MSFSSimVar(
    name: 'TRANSPONDER STATE:1',
    unit: 'Number',
    description: '应答机状态',
  );

  static const MSFSSimVar transponderCode = MSFSSimVar(
    name: 'TRANSPONDER CODE:1',
    unit: 'BCO16',
    description: '应答机编码',
  );

  // ==================== 环境数据 ====================

  static const MSFSSimVar outsideAirTemperature = MSFSSimVar(
    name: 'AMBIENT TEMPERATURE',
    unit: 'Celsius',
    description: '外部温度',
  );

  static const MSFSSimVar totalAirTemperature = MSFSSimVar(
    name: 'TOTAL AIR TEMPERATURE',
    unit: 'Celsius',
    description: '总温',
  );

  static const MSFSSimVar windSpeed = MSFSSimVar(
    name: 'AMBIENT WIND VELOCITY',
    unit: 'knots',
    description: '风速',
  );

  static const MSFSSimVar windDirection = MSFSSimVar(
    name: 'AMBIENT WIND DIRECTION',
    unit: 'degrees',
    description: '风向',
  );

  static const MSFSSimVar visibility = MSFSSimVar(
    name: 'AMBIENT VISIBILITY',
    unit: 'meters',
    description: '能见度',
  );

  static const MSFSSimVar com1Frequency = MSFSSimVar(
    name: 'COM ACTIVE FREQUENCY:1',
    unit: 'MHz',
    description: 'COM1 频率',
  );

  // ====================  警告系统 ====================

  static const MSFSSimVar masterWarning = MSFSSimVar(
    name: 'MASTER WARNING',
    unit: 'bool',
    description: '主警告',
  );

  static const MSFSSimVar masterCaution = MSFSSimVar(
    name: 'MASTER CAUTION',
    unit: 'bool',
    description: '主告警',
  );

  static const MSFSSimVar engineFire1 = MSFSSimVar(
    name: 'ENG ON FIRE:1',
    unit: 'bool',
    description: '发动机1火警',
  );

  static const MSFSSimVar engineFire2 = MSFSSimVar(
    name: 'ENG ON FIRE:2',
    unit: 'bool',
    description: '发动机2火警',
  );

  static const MSFSSimVar apuFire = MSFSSimVar(
    name: 'APU ON FIRE',
    unit: 'bool',
    description: 'APU火警',
  );

  // ==================== 获取所有SimVars ====================

  /// 获取所有需要订阅的 SimVar 列表
  static List<MSFSSimVar> getAllSimVars() {
    return [
      // 飞行数据
      airspeed,
      mach,
      altitude,
      heading,
      verticalSpeed,
      pitch,
      roll,
      latitude,
      longitude,
      aircraftTitle,
      atcModel,
      atcType,
      atcId,
      // 系统状态
      parkingBrake,
      beaconLight,
      landingLight,
      taxiLight,
      navLight,
      strobeLight,
      flapsHandleIndex,
      flapsHandlePositions,
      flapsDeployRatio,
      // 发动机
      apuSwitch,
      engine1Combustion,
      engine2Combustion,
      engine1N1,
      engine2N1,
      engineCount,
      // 自动驾驶
      autopilotMaster, autopilotThrottle,
      // 监控数据
      gForce, barometerPressure,
      // 起落架详细状态
      noseGearPosition, leftGearPosition, rightGearPosition,
      // 减速板与扰流板
      speedBrakePosition, spoilersDeployed,
      // 自动刹车
      autoBrakeSwitch,
      transponderState,
      transponderCode,
      // 警告系统
      masterWarning, masterCaution,
      engineFire1, engineFire2, apuFire,
      // 环境数据
      outsideAirTemperature, totalAirTemperature,
      windSpeed, windDirection, visibility,
      com1Frequency,
    ];
  }

  /// 生成订阅消息
  static Map<String, dynamic> generateSubscriptionMessage() {
    return {
      'subscribe': getAllSimVars()
          .map((simVar) => simVar.toSubscriptionMap())
          .toList(),
    };
  }
}
