/// 航空术语词库
/// 包含：缩写、全称、中文释义
class AviationTerm {
  final String abbreviation;
  final String fullName;
  final String chineseName;
  final String? description;

  const AviationTerm({
    required this.abbreviation,
    required this.fullName,
    required this.chineseName,
    this.description,
  });

  String get displayValue => '$chineseName ($fullName)';
}

class AviationTermsData {
  static const List<AviationTerm> terms = [
    // 速度相关 (V-Speeds)
    AviationTerm(
      abbreviation: 'V1',
      fullName: 'Takeoff Decision Speed',
      chineseName: '起飞决断速度',
      description: '在此速度前可以安全中断起飞，超过此速度必须继续起飞。',
    ),
    AviationTerm(
      abbreviation: 'VR',
      fullName: 'Rotation Speed',
      chineseName: '抬头速度',
      description: '飞行员开始拉杆使机头离开地面的速度。',
    ),
    AviationTerm(
      abbreviation: 'V2',
      fullName: 'Takeoff Safety Speed',
      chineseName: '起飞安全速度',
      description: '发动机失效时应保持的最低爬升速度。',
    ),
    AviationTerm(
      abbreviation: 'Vref',
      fullName: 'Reference Landing Speed',
      chineseName: '进近参考速度',
      description: '着陆时基于飞机重量和襟翼构型的基准空速。',
    ),
    AviationTerm(
      abbreviation: 'Vne',
      fullName: 'Never Exceed Speed',
      chineseName: '绝不超过速度',
      description: '红线速度，超过此速度可能导致结构损坏。',
    ),
    AviationTerm(
      abbreviation: 'Vmo',
      fullName: 'Maximum Operating Limit Speed',
      chineseName: '最大运行限制速度',
    ),
    AviationTerm(
      abbreviation: 'Vs0',
      fullName: 'Stalling Speed In Landing Configuration',
      chineseName: '着陆构型失速速度',
      description: '全襟翼、起落架伸出状态下的失速速度。',
    ),
    AviationTerm(
      abbreviation: 'Vs1',
      fullName: 'Stalling Speed In Specific Configuration',
      chineseName: '特定构型失速速度',
      description: '通常指清洁构型（襟翼收回）下的失速速度。',
    ),
    AviationTerm(
      abbreviation: 'Vx',
      fullName: 'Best Angle of Climb Speed',
      chineseName: '最佳爬升角速度',
    ),
    AviationTerm(
      abbreviation: 'Vy',
      fullName: 'Best Rate of Climb Speed',
      chineseName: '最佳爬升率速度',
    ),
    AviationTerm(
      abbreviation: 'Vlo',
      fullName: 'Maximum Landing Gear Operating Speed',
      chineseName: '最大起落架操作速度',
      description: '可以安全操作（伸出或缩回）起落架的最大速度。',
    ),
    AviationTerm(
      abbreviation: 'Vle',
      fullName: 'Maximum Landing Gear Extended Speed',
      chineseName: '最大起落架伸出速度',
      description: '起落架在伸出锁定状态下允许飞行的最高速度。',
    ),
    AviationTerm(
      abbreviation: 'Vfe',
      fullName: 'Maximum Flaps Extended Speed',
      chineseName: '最大襟翼收放速度',
      description: '在特定襟翼构型下允许飞行的最高速度。',
    ),
    AviationTerm(
      abbreviation: 'Vmc',
      fullName: 'Minimum Control Speed',
      chineseName: '最小控制速度',
      description: '多发飞机在一发失效时仍能保持方向控制的最低速度。',
    ),
    AviationTerm(
      abbreviation: 'Vmcg',
      fullName: 'Minimum Control Speed on Ground',
      chineseName: '地面最小控制速度',
      description: '在起飞滑跑过程中，关键发动机突然失效后，仅使用方向舵即可维持方向控制的最低速度。',
    ),
    AviationTerm(
      abbreviation: 'Vmca',
      fullName: 'Minimum Control Speed in the Air',
      chineseName: '空中最小控制速度',
      description: '起飞后在该速度以上，关键发动机失效时仍能保持对飞机的控制。',
    ),
    AviationTerm(
      abbreviation: 'Va',
      fullName: 'Design Maneuvering Speed',
      chineseName: '设计机动速度',
      description: '在此速度以下，满舵面偏转不会导致结构损坏。',
    ),
    AviationTerm(
      abbreviation: 'Vno',
      fullName: 'Maximum Structural Cruising Speed',
      chineseName: '最大结构巡航速度',
      description: '正常操作中不应超过的速度，除非在平稳气象条件下。',
    ),
    AviationTerm(
      abbreviation: 'Vbg',
      fullName: 'Best Glide Speed',
      chineseName: '最佳滑翔速度',
      description: '发动机失效时能获得最大滑翔距离的速度。',
    ),

    // 气象相关
    AviationTerm(
      abbreviation: 'METAR',
      fullName: 'Meteorological Aerodrome Report',
      chineseName: '整点天气报告',
    ),
    AviationTerm(
      abbreviation: 'TAF',
      fullName: 'Terminal Aerodrome Forecast',
      chineseName: '机场天气预报',
    ),
    AviationTerm(
      abbreviation: 'CAVOK',
      fullName: 'Ceiling and Visibility OK',
      chineseName: '云底高度及能见度OK',
      description: '能见度>10km，且在5000ft以下无云。',
    ),
    AviationTerm(
      abbreviation: 'SIGMET',
      fullName: 'Significant Meteorological Information',
      chineseName: '重要气象情报',
    ),
    AviationTerm(
      abbreviation: 'CAT',
      fullName: 'Clear Air Turbulence',
      chineseName: '晴空颠簸',
    ),
    AviationTerm(
      abbreviation: 'CB',
      fullName: 'Cumulonimbus',
      chineseName: '积雨云',
    ),
    AviationTerm(
      abbreviation: 'Wind Shear',
      fullName: 'Wind Shear',
      chineseName: '风切变',
    ),

    // 导航与空域
    AviationTerm(
      abbreviation: 'ILS',
      fullName: 'Instrument Landing System',
      chineseName: '仪表着陆系统',
    ),
    AviationTerm(
      abbreviation: 'VOR',
      fullName: 'VHF Omni-directional Range',
      chineseName: '甚高频全向信标',
    ),
    AviationTerm(
      abbreviation: 'NDB',
      fullName: 'Non-Directional Beacon',
      chineseName: '无方向性信标',
    ),
    AviationTerm(
      abbreviation: 'DME',
      fullName: 'Distance Measuring Equipment',
      chineseName: '测距仪',
    ),
    AviationTerm(
      abbreviation: 'RNAV',
      fullName: 'Area Navigation',
      chineseName: '区域导航',
    ),
    AviationTerm(
      abbreviation: 'RNP',
      fullName: 'Required Navigation Performance',
      chineseName: '所需导航性能',
    ),
    AviationTerm(
      abbreviation: 'SID',
      fullName: 'Standard Instrument Departure',
      chineseName: '标准仪表离场',
    ),
    AviationTerm(
      abbreviation: 'STAR',
      fullName: 'Standard Terminal Arrival Route',
      chineseName: '标准终端进场',
    ),
    AviationTerm(
      abbreviation: 'TORA',
      fullName: 'Take-Off Run Available',
      chineseName: '可用起飞跑道距离',
    ),
    AviationTerm(
      abbreviation: 'TODA',
      fullName: 'Take-Off Distance Available',
      chineseName: '可用起飞距离',
    ),
    AviationTerm(
      abbreviation: 'ASDA',
      fullName: 'Accelerate-Stop Distance Available',
      chineseName: '可用加速停止距离',
    ),
    AviationTerm(
      abbreviation: 'LDA',
      fullName: 'Landing Distance Available',
      chineseName: '可用着陆距离',
    ),
    AviationTerm(
      abbreviation: 'PAPI',
      fullName: 'Precision Approach Path Indicator',
      chineseName: '精密进近航道指示器',
    ),
    AviationTerm(
      abbreviation: 'RVR',
      fullName: 'Runway Visual Range',
      chineseName: '跑道视程',
    ),
    AviationTerm(
      abbreviation: 'NOTAM',
      fullName: 'Notice to Airmen',
      chineseName: '航行通告',
    ),

    // 高度与压力
    AviationTerm(
      abbreviation: 'QNH',
      fullName: 'Altimeter setting relative to sea level',
      chineseName: '修正海平面气压',
    ),
    AviationTerm(
      abbreviation: 'QFE',
      fullName: 'Altimeter setting relative to airport elevation',
      chineseName: '场面气压',
    ),
    AviationTerm(
      abbreviation: 'std',
      fullName: 'Standard Pressure',
      chineseName: '标准气压 (1013 hPa / 29.92 inHg)',
    ),
    AviationTerm(
      abbreviation: 'FL',
      fullName: 'Flight Level',
      chineseName: '飞行高度层',
    ),
    AviationTerm(
      abbreviation: 'MSL',
      fullName: 'Mean Sea Level',
      chineseName: '平均海平面高度',
    ),
    AviationTerm(
      abbreviation: 'AGL',
      fullName: 'Above Ground Level',
      chineseName: '离地高度',
    ),
    AviationTerm(
      abbreviation: 'MSA',
      fullName: 'Minimum Sector Altitude',
      chineseName: '最低扇区高度',
    ),
    AviationTerm(
      abbreviation: 'MEA',
      fullName: 'Minimum Enroute Altitude',
      chineseName: '最低航路高度',
    ),
    AviationTerm(
      abbreviation: 'MOCA',
      fullName: 'Minimum Obstacle Clearance Altitude',
      chineseName: '最低障碍物净空高度',
    ),
    AviationTerm(
      abbreviation: 'MORA',
      fullName: 'Minimum Off-Route Altitude',
      chineseName: '最低越障高度',
    ),

    // ATC 与通讯
    AviationTerm(
      abbreviation: 'ATIS',
      fullName: 'Automatic Terminal Information Service',
      chineseName: '自动终端情报服务',
    ),
    AviationTerm(
      abbreviation: 'ATC',
      fullName: 'Air Traffic Control',
      chineseName: '空中交通管制',
    ),
    AviationTerm(
      abbreviation: 'SQUAWK',
      fullName: 'Transponder Code',
      chineseName: '应答机代码',
    ),
    AviationTerm(
      abbreviation: 'MAYDAY',
      fullName: 'Emergency Call (Distress)',
      chineseName: '最高紧急呼叫 (紧急求救)',
    ),
    AviationTerm(
      abbreviation: 'PAN-PAN',
      fullName: 'Urgency Call',
      chineseName: '次级紧急呼叫 (紧急情况)',
    ),
    AviationTerm(
      abbreviation: 'Roger',
      fullName: 'Received',
      chineseName: '收到',
    ),
    AviationTerm(
      abbreviation: 'Wilco',
      fullName: 'Will Comply',
      chineseName: '遵照执行',
    ),
    AviationTerm(abbreviation: 'Affirm', fullName: 'Yes', chineseName: '是的'),
    AviationTerm(
      abbreviation: 'Negative',
      fullName: 'No',
      chineseName: '不 / 否定',
    ),

    // 系统与操作
    AviationTerm(
      abbreviation: 'APU',
      fullName: 'Auxiliary Power Unit',
      chineseName: '辅助动力装置',
    ),
    AviationTerm(
      abbreviation: 'FMC',
      fullName: 'Flight Management Computer',
      chineseName: '飞行管理计算机',
    ),
    AviationTerm(
      abbreviation: 'MCP',
      fullName: 'Mode Control Panel',
      chineseName: '模式控制面板',
    ),
    AviationTerm(
      abbreviation: 'PFD',
      fullName: 'Primary Flight Display',
      chineseName: '主飞行显示器',
    ),
    AviationTerm(
      abbreviation: 'ND',
      fullName: 'Navigation Display',
      chineseName: '导航显示器',
    ),
    AviationTerm(
      abbreviation: 'EICAS',
      fullName: 'Engine Indication and Crew Alerting System',
      chineseName: '发动机指示和机组警报系统',
    ),
    AviationTerm(
      abbreviation: 'ECAM',
      fullName: 'Electronic Centralized Aircraft Monitor',
      chineseName: '电子集中飞机监控 (空客系统)',
    ),
    AviationTerm(
      abbreviation: 'TOGA',
      fullName: 'Takeoff / Go-Around',
      chineseName: '起飞/复飞点',
    ),

    // 空速类型
    AviationTerm(
      abbreviation: 'IAS',
      fullName: 'Indicated Airspeed',
      chineseName: '指示空速',
    ),
    AviationTerm(
      abbreviation: 'TAS',
      fullName: 'True Airspeed',
      chineseName: '真空速',
    ),
    AviationTerm(
      abbreviation: 'GS',
      fullName: 'Ground Speed',
      chineseName: '地速',
    ),
    AviationTerm(
      abbreviation: 'CAS',
      fullName: 'Calibrated Airspeed',
      chineseName: '修正空速',
    ),

    // 进近相关
    AviationTerm(
      abbreviation: 'DH',
      fullName: 'Decision Height',
      chineseName: '决断高度',
    ),
    AviationTerm(
      abbreviation: 'MDA',
      fullName: 'Minimum Descent Altitude',
      chineseName: '最低下降高度',
    ),
    AviationTerm(
      abbreviation: 'FAF',
      fullName: 'Final Approach Fix',
      chineseName: '最后进近定位点',
    ),
    AviationTerm(
      abbreviation: 'MAP',
      fullName: 'Missed Approach Point',
      chineseName: '复飞点',
    ),
  ];

  static Map<String, AviationTerm> get termsMap => {
    for (var term in terms) term.abbreviation.toUpperCase(): term,
  };

  static List<AviationTerm> search(String query) {
    if (query.isEmpty) return [];
    final upperQuery = query.toUpperCase();
    return terms
        .where(
          (t) =>
              t.abbreviation.toUpperCase().contains(upperQuery) ||
              t.fullName.toUpperCase().contains(upperQuery) ||
              t.chineseName.contains(query),
        )
        .toList();
  }
}
