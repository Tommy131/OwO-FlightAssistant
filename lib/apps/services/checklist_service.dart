import '../models/flight_checklist.dart';

class ChecklistService {
  static final ChecklistService _instance = ChecklistService._internal();
  factory ChecklistService() => _instance;
  ChecklistService._internal();

  List<AircraftChecklist> getSupportedAircraft() {
    return [
      _createA320Checklist('A320-200 / A321 / A319'),
      _createB737Checklist('B737-800 / Max'),
    ];
  }

  AircraftChecklist _createA320Checklist(String name) {
    return AircraftChecklist(
      id: 'a320_series',
      name: name,
      family: AircraftFamily.a320,
      sections: [
        // ========== 冷舱启动 (COLD & DARK) ==========
        ChecklistSection(
          phase: ChecklistPhase.coldAndDark,
          items: [
            ChecklistItem(
              id: 'a1_1',
              task: '电池 (BAT 1+2)',
              response: '开启 (ON)',
            ),
            ChecklistItem(
              id: 'a1_2',
              task: '外部电源 (EXT PWR)',
              response: '可用/接通 (AVAIL/ON)',
            ),
            ChecklistItem(
              id: 'a1_3',
              task: '应急出口灯 (EMER EXIT LT)',
              response: '预位 (ARMED)',
            ),
            ChecklistItem(
              id: 'a1_4',
              task: '座椅安全带 (SEAT BELTS)',
              response: '开启 (ON)',
            ),
            ChecklistItem(
              id: 'a1_5',
              task: '禁止吸烟 (NO SMOKING)',
              response: '开启 (ON)',
            ),
            ChecklistItem(
              id: 'a1_6',
              task: 'ADIRS (1+2+3)',
              response: '调定导航 (NAV)',
            ),
            ChecklistItem(
              id: 'a1_7',
              task: '燃油泵 (FUEL PUMPS)',
              response: '开启 (ON)',
            ),
            ChecklistItem(id: 'a1_8', task: 'APU 主电门', response: '开启 (ON)'),
            ChecklistItem(id: 'a1_9', task: 'APU 启动', response: '启动 (START)'),
            ChecklistItem(
              id: 'a1_10',
              task: 'APU 发电机 (APU GEN)',
              response: '接通 (ON BUS)',
            ),
            ChecklistItem(id: 'a1_11', task: '外部电源', response: '断开 (OFF)'),
            ChecklistItem(
              id: 'a1_12',
              task: '导航灯 (NAV LIGHTS)',
              response: '开启 (ON)',
            ),
            ChecklistItem(
              id: 'a1_13',
              task: 'FMS 航路输入',
              response: '完成 (COMPLETED)',
            ),
            ChecklistItem(
              id: 'a1_14',
              task: 'MCDU 性能数据',
              response: '输入 (ENTERED)',
            ),
          ],
        ),

        // ========== 推出前检查 (BEFORE PUSHBACK) ==========
        ChecklistSection(
          phase: ChecklistPhase.beforePushback,
          items: [
            ChecklistItem(
              id: 'a2_1',
              task: '客舱准备 (CABIN READY)',
              response: '确认 (CONFIRMED)',
            ),
            ChecklistItem(
              id: 'a2_2',
              task: '机门 (DOORS)',
              response: '关闭 (CLOSED)',
            ),
            ChecklistItem(
              id: 'a2_3',
              task: '滑梯 (SLIDES)',
              response: '预位 (ARMED)',
            ),
            ChecklistItem(
              id: 'a2_4',
              task: '信标灯 (BEACON)',
              response: '开启 (ON)',
            ),
            ChecklistItem(
              id: 'a2_5',
              task: '刹车压力 (BRAKE PRESS)',
              response: '检查 (CHECKED)',
            ),
            ChecklistItem(id: 'a2_6', task: '襟翼 (FLAPS)', response: '调定 (SET)'),
            ChecklistItem(
              id: 'a2_7',
              task: '配平 (PITCH TRIM)',
              response: '调定 (SET)',
            ),
            ChecklistItem(
              id: 'a2_8',
              task: '舵面 (RUDDER TRIM)',
              response: '零位 (ZERO)',
            ),
            ChecklistItem(id: 'a2_9', task: '飞行引导 (FD)', response: '开启 (ON)'),
            ChecklistItem(
              id: 'a2_10',
              task: '自动刹车 (AUTO BRK)',
              response: '调定 (SET)',
            ),
            ChecklistItem(
              id: 'a2_11',
              task: '停机刹车 (PARK BRK)',
              response: '松开 (OFF)',
            ),
            ChecklistItem(id: 'a2_12', task: '推出许可', response: '获得 (OBTAINED)'),
          ],
        ),

        // ========== 滑行前检查 (BEFORE TAXI) ==========
        ChecklistSection(
          phase: ChecklistPhase.beforeTaxi,
          items: [
            ChecklistItem(
              id: 'a_taxi_1',
              task: '发动机 (ENGINES)',
              response: '启动完成 (STARTED)',
            ),
            ChecklistItem(
              id: 'a_taxi_2',
              task: '发动机参数',
              response: '正常 (NORMAL)',
            ),
            ChecklistItem(
              id: 'a_taxi_3',
              task: 'APU 引气 (APU BLEED)',
              response: '关闭 (OFF)',
            ),
            ChecklistItem(id: 'a_taxi_4', task: 'APU', response: '关闭 (OFF)'),
            ChecklistItem(id: 'a_taxi_5', task: '地面设备', response: '断开 (CLEAR)'),
            ChecklistItem(
              id: 'a_taxi_6',
              task: '防冰系统 (ANTI ICE)',
              response: '按需 (AS REQ)',
            ),
            ChecklistItem(
              id: 'a_taxi_7',
              task: '探头加热 (PROBE HEAT)',
              response: '开启 (ON)',
            ),
            ChecklistItem(
              id: 'a_taxi_8',
              task: '滑行灯 (TAXI LIGHTS)',
              response: '开启 (ON)',
            ),
            ChecklistItem(
              id: 'a_taxi_9',
              task: '跑道脱离灯 (RWY TURN OFF)',
              response: '开启 (ON)',
            ),
            ChecklistItem(
              id: 'a_taxi_10',
              task: 'ECAM 状态',
              response: '正常 (NORMAL)',
            ),
            ChecklistItem(id: 'a_taxi_11', task: '刹车', response: '测试 (TESTED)'),
          ],
        ),

        // ========== 起飞前检查 (BEFORE TAKEOFF) ==========
        ChecklistSection(
          phase: ChecklistPhase.beforeTakeoff,
          items: [
            ChecklistItem(
              id: 'a3_1',
              task: '飞行控制 (FLT CTL)',
              response: '检查完成 (CHECKED)',
            ),
            ChecklistItem(
              id: 'a3_2',
              task: '襟翼/缝翼 (FLAPS/SLATS)',
              response: '起飞位 (T.O)',
            ),
            ChecklistItem(
              id: 'a3_3',
              task: '配平 (PITCH TRIM)',
              response: '绿带内 (GREEN)',
            ),
            ChecklistItem(id: 'a3_4', task: '起飞简令', response: '完成 (BRIEFED)'),
            ChecklistItem(
              id: 'a3_5',
              task: '起飞构型 (T.O CONFIG)',
              response: '测试正常 (NORMAL)',
            ),
            ChecklistItem(id: 'a3_6', task: 'ECAM 备忘', response: '清除 (CLEAR)'),
            ChecklistItem(id: 'a3_7', task: '跨雷达 (TCAS)', response: 'TA/RA'),
            ChecklistItem(id: 'a3_8', task: '应答机 (XPDR)', response: 'TA/RA'),
            ChecklistItem(
              id: 'a3_9',
              task: '自动驾驶 (A/P)',
              response: '准备 (READY)',
            ),
            ChecklistItem(
              id: 'a3_10',
              task: '自动油门 (A/THR)',
              response: '预位 (ARMED)',
            ),
            ChecklistItem(id: 'a3_11', task: '起飞许可', response: '获得 (CLEARED)'),
          ],
        ),

        // ========== 巡航检查 (CRUISE) ==========
        ChecklistSection(
          phase: ChecklistPhase.cruise,
          items: [
            ChecklistItem(
              id: 'a_cruise_1',
              task: '高度',
              response: '巡航高度 (CRUISE ALT)',
            ),
            ChecklistItem(
              id: 'a_cruise_2',
              task: '自动驾驶 (A/P)',
              response: '接通 (ENGAGED)',
            ),
            ChecklistItem(
              id: 'a_cruise_3',
              task: '自动油门 (A/THR)',
              response: '接通 (ENGAGED)',
            ),
            ChecklistItem(
              id: 'a_cruise_4',
              task: '燃油平衡',
              response: '检查 (CHECKED)',
            ),
            ChecklistItem(
              id: 'a_cruise_5',
              task: '客舱高度',
              response: '正常 (NORMAL)',
            ),
            ChecklistItem(
              id: 'a_cruise_6',
              task: '安全带灯',
              response: '按需 (AS REQ)',
            ),
            ChecklistItem(
              id: 'a_cruise_7',
              task: '天气雷达',
              response: '监控 (MONITORED)',
            ),
            ChecklistItem(
              id: 'a_cruise_8',
              task: 'ECAM 状态',
              response: '正常 (NORMAL)',
            ),
          ],
        ),

        // ========== 下降前检查 (BEFORE DESCENT) ==========
        ChecklistSection(
          phase: ChecklistPhase.beforeDescent,
          items: [
            ChecklistItem(
              id: 'a_desc_1',
              task: '进近简令',
              response: '完成 (BRIEFED)',
            ),
            ChecklistItem(
              id: 'a_desc_2',
              task: 'ATIS 信息',
              response: '获得 (OBTAINED)',
            ),
            ChecklistItem(
              id: 'a_desc_3',
              task: '高度表 (BARO)',
              response: '调定 (SET)',
            ),
            ChecklistItem(
              id: 'a_desc_4',
              task: '着陆标高 (LDG ELEV)',
              response: '输入 (ENTERED)',
            ),
            ChecklistItem(
              id: 'a_desc_5',
              task: '最低标准 (MINIMUMS)',
              response: '调定 (SET)',
            ),
            ChecklistItem(
              id: 'a_desc_6',
              task: '自动刹车 (AUTO BRK)',
              response: '调定 (SET)',
            ),
            ChecklistItem(id: 'a_desc_7', task: '安全带灯', response: '开启 (ON)'),
            ChecklistItem(
              id: 'a_desc_8',
              task: '客舱准备',
              response: '通知 (NOTIFIED)',
            ),
          ],
        ),

        // ========== 进近前检查 (BEFORE APPROACH) ==========
        ChecklistSection(
          phase: ChecklistPhase.beforeApproach,
          items: [
            ChecklistItem(
              id: 'a_app_1',
              task: '着陆许可',
              response: '获得 (CLEARED)',
            ),
            ChecklistItem(
              id: 'a_app_2',
              task: '起落架 (GEAR)',
              response: '放下 (DOWN)',
            ),
            ChecklistItem(
              id: 'a_app_3',
              task: '襟翼 (FLAPS)',
              response: '着陆位 (FULL)',
            ),
            ChecklistItem(
              id: 'a_app_4',
              task: '着陆灯 (LDG LIGHTS)',
              response: '开启 (ON)',
            ),
            ChecklistItem(
              id: 'a_app_5',
              task: '地面扰流板 (GND SPLRS)',
              response: '预位 (ARMED)',
            ),
            ChecklistItem(id: 'a_app_6', task: '自动刹车', response: '调定 (SET)'),
            ChecklistItem(
              id: 'a_app_7',
              task: 'ECAM 备忘',
              response: '清除 (CLEAR)',
            ),
            ChecklistItem(
              id: 'a_app_8',
              task: '着陆检查单',
              response: '完成 (COMPLETED)',
            ),
          ],
        ),

        // ========== 落地后检查 (AFTER LANDING) ==========
        ChecklistSection(
          phase: ChecklistPhase.afterLanding,
          items: [
            ChecklistItem(
              id: 'a_land_1',
              task: '襟翼 (FLAPS)',
              response: '收起 (UP)',
            ),
            ChecklistItem(
              id: 'a_land_2',
              task: '减速板 (SPOILERS)',
              response: '收起 (RETRACTED)',
            ),
            ChecklistItem(
              id: 'a_land_3',
              task: '天气雷达 (WX RADAR)',
              response: '关闭 (OFF)',
            ),
            ChecklistItem(
              id: 'a_land_4',
              task: '预测风切变 (PWS)',
              response: '关闭 (OFF)',
            ),
            ChecklistItem(id: 'a_land_5', task: 'APU', response: '启动 (START)'),
            ChecklistItem(id: 'a_land_6', task: '跑道脱离灯', response: '开启 (ON)'),
            ChecklistItem(id: 'a_land_7', task: '滑行灯', response: '开启 (ON)'),
            ChecklistItem(id: 'a_land_8', task: '着陆灯', response: '关闭 (OFF)'),
            ChecklistItem(id: 'a_land_9', task: '应答机 (XPDR)', response: 'STBY'),
          ],
        ),

        // ========== 关车/停机检查 (PARKING) ==========
        ChecklistSection(
          phase: ChecklistPhase.parking,
          items: [
            ChecklistItem(
              id: 'a_park_1',
              task: '停机刹车 (PARK BRK)',
              response: '开启 (SET)',
            ),
            ChecklistItem(id: 'a_park_2', task: '轮挡', response: '放置 (CHOCKED)'),
            ChecklistItem(
              id: 'a_park_3',
              task: '发动机 (ENGINES)',
              response: '关闭 (OFF)',
            ),
            ChecklistItem(id: 'a_park_4', task: '安全带灯', response: '关闭 (OFF)'),
            ChecklistItem(id: 'a_park_5', task: '燃油泵', response: '关闭 (OFF)'),
            ChecklistItem(id: 'a_park_6', task: '信标灯', response: '关闭 (OFF)'),
            ChecklistItem(id: 'a_park_7', task: '外部电源', response: '接通 (ON)'),
            ChecklistItem(id: 'a_park_8', task: 'APU', response: '关闭 (OFF)'),
            ChecklistItem(
              id: 'a_park_9',
              task: '滑梯 (SLIDES)',
              response: '解除预位 (DISARMED)',
            ),
            ChecklistItem(id: 'a_park_10', task: '机门', response: '可以打开 (OPEN)'),
            ChecklistItem(id: 'a_park_11', task: 'ADIRS', response: '关闭 (OFF)'),
            ChecklistItem(id: 'a_park_12', task: '电池', response: '关闭 (OFF)'),
          ],
        ),
      ],
    );
  }

  AircraftChecklist _createB737Checklist(String name) {
    return AircraftChecklist(
      id: 'b737_series',
      name: name,
      family: AircraftFamily.b737,
      sections: [
        // ========== 冷舱启动 (COLD & DARK) ==========
        ChecklistSection(
          phase: ChecklistPhase.coldAndDark,
          items: [
            ChecklistItem(
              id: 'b1_1',
              task: '电池开关 (BATTERY)',
              response: '开启 (ON)',
            ),
            ChecklistItem(
              id: 'b1_2',
              task: '备用电源 (STANDBY PWR)',
              response: '自动 (AUTO)',
            ),
            ChecklistItem(
              id: 'b1_3',
              task: '外部电源 (EXT PWR)',
              response: '接通 (ON)',
            ),
            ChecklistItem(id: 'b1_4', task: '应急出口灯', response: '预位 (ARMED)'),
            ChecklistItem(id: 'b1_5', task: '安全带标志', response: '开启 (ON)'),
            ChecklistItem(id: 'b1_6', task: '禁止吸烟', response: '开启 (ON)'),
            ChecklistItem(id: 'b1_7', task: 'IRS 模式选择器', response: '导航 (NAV)'),
            ChecklistItem(
              id: 'b1_8',
              task: '液压泵 (HYD PUMPS)',
              response: '开启 (ON)',
            ),
            ChecklistItem(id: 'b1_9', task: 'APU 开关', response: '启动 (START)'),
            ChecklistItem(id: 'b1_10', task: 'APU 发电机', response: '开启 (ON)'),
            ChecklistItem(
              id: 'b1_11',
              task: 'FMC 航路',
              response: '输入 (ENTERED)',
            ),
            ChecklistItem(id: 'b1_12', task: '性能数据', response: '输入 (ENTERED)'),
          ],
        ),

        // ========== 推出前检查 (BEFORE PUSHBACK) ==========
        ChecklistSection(
          phase: ChecklistPhase.beforePushback,
          items: [
            ChecklistItem(id: 'b2_1', task: '客舱报告', response: '收到 (RECEIVED)'),
            ChecklistItem(id: 'b2_2', task: '机门', response: '关闭 (CLOSED)'),
            ChecklistItem(
              id: 'b2_3',
              task: '燃油泵 (FUEL PUMPS)',
              response: '开启 (ON)',
            ),
            ChecklistItem(id: 'b2_4', task: '座椅腰带', response: '开启 (ON)'),
            ChecklistItem(
              id: 'b2_5',
              task: '防撞灯 (ANTI COLLISION)',
              response: '开启 (ON)',
            ),
            ChecklistItem(id: 'b2_6', task: '襟翼', response: '调定 (SET)'),
            ChecklistItem(id: 'b2_7', task: '稳定器配平', response: '调定 (SET)'),
            ChecklistItem(
              id: 'b2_8',
              task: '推力杠 (THROTTLE)',
              response: '怠速 (IDLE)',
            ),
            ChecklistItem(id: 'b2_9', task: '停机刹车', response: '松开 (RELEASED)'),
            ChecklistItem(id: 'b2_10', task: '推出许可', response: '获得 (CLEARED)'),
          ],
        ),

        // ========== 滑行前检查 (BEFORE TAXI) ==========
        ChecklistSection(
          phase: ChecklistPhase.beforeTaxi,
          items: [
            ChecklistItem(
              id: 'b_taxi_1',
              task: '发动机启动',
              response: '完成 (COMPLETED)',
            ),
            ChecklistItem(
              id: 'b_taxi_2',
              task: '发电机 (GENERATORS)',
              response: '开启 (ON)',
            ),
            ChecklistItem(
              id: 'b_taxi_3',
              task: '探头加热 (PROBE HEAT)',
              response: '开启 (ON)',
            ),
            ChecklistItem(
              id: 'b_taxi_4',
              task: '引气 (BLEED AIR)',
              response: '开启 (ON)',
            ),
            ChecklistItem(
              id: 'b_taxi_5',
              task: '隔离阀 (ISOLATION VALVE)',
              response: '自动 (AUTO)',
            ),
            ChecklistItem(id: 'b_taxi_6', task: 'APU', response: '关闭 (OFF)'),
            ChecklistItem(
              id: 'b_taxi_7',
              task: '防冰系统',
              response: '按需 (AS REQ)',
            ),
            ChecklistItem(id: 'b_taxi_8', task: '滑行灯', response: '开启 (ON)'),
            ChecklistItem(id: 'b_taxi_9', task: '跑道脱离灯', response: '开启 (ON)'),
            ChecklistItem(
              id: 'b_taxi_10',
              task: '刹车测试',
              response: '完成 (TESTED)',
            ),
          ],
        ),

        // ========== 起飞前检查 (BEFORE TAKEOFF) ==========
        ChecklistSection(
          phase: ChecklistPhase.beforeTakeoff,
          items: [
            ChecklistItem(id: 'b3_1', task: '飞行控制', response: '检查 (CHECKED)'),
            ChecklistItem(id: 'b3_2', task: '襟翼', response: '起飞位 (T.O)'),
            ChecklistItem(id: 'b3_3', task: '配平', response: '绿带内 (GREEN)'),
            ChecklistItem(id: 'b3_4', task: '起飞简令', response: '完成 (BRIEFED)'),
            ChecklistItem(id: 'b3_5', task: '起飞数据', response: '确认 (VERIFIED)'),
            ChecklistItem(id: 'b3_6', task: 'TCAS', response: 'TA/RA'),
            ChecklistItem(id: 'b3_7', task: '应答机', response: 'TA/RA'),
            ChecklistItem(id: 'b3_8', task: '自动驾驶', response: '预位 (ARMED)'),
            ChecklistItem(id: 'b3_9', task: '自动油门', response: '预位 (ARMED)'),
            ChecklistItem(id: 'b3_10', task: '起飞许可', response: '获得 (CLEARED)'),
          ],
        ),

        // ========== 巡航检查 (CRUISE) ==========
        ChecklistSection(
          phase: ChecklistPhase.cruise,
          items: [
            ChecklistItem(
              id: 'b_cruise_1',
              task: '巡航高度',
              response: '到达 (REACHED)',
            ),
            ChecklistItem(
              id: 'b_cruise_2',
              task: '自动驾驶',
              response: '接通 (ENGAGED)',
            ),
            ChecklistItem(
              id: 'b_cruise_3',
              task: '自动油门',
              response: '接通 (ENGAGED)',
            ),
            ChecklistItem(
              id: 'b_cruise_4',
              task: '燃油平衡',
              response: '检查 (CHECKED)',
            ),
            ChecklistItem(
              id: 'b_cruise_5',
              task: '客舱高度',
              response: '正常 (NORMAL)',
            ),
            ChecklistItem(
              id: 'b_cruise_6',
              task: '安全带灯',
              response: '按需 (AS REQ)',
            ),
            ChecklistItem(
              id: 'b_cruise_7',
              task: '天气雷达',
              response: '监控 (MONITORED)',
            ),
          ],
        ),

        // ========== 下降前检查 (BEFORE DESCENT) ==========
        ChecklistSection(
          phase: ChecklistPhase.beforeDescent,
          items: [
            ChecklistItem(
              id: 'b_desc_1',
              task: '进近简令',
              response: '完成 (BRIEFED)',
            ),
            ChecklistItem(
              id: 'b_desc_2',
              task: 'ATIS',
              response: '获得 (OBTAINED)',
            ),
            ChecklistItem(id: 'b_desc_3', task: '高度表', response: '调定 (SET)'),
            ChecklistItem(
              id: 'b_desc_4',
              task: '着陆标高',
              response: '输入 (ENTERED)',
            ),
            ChecklistItem(id: 'b_desc_5', task: '最低标准', response: '调定 (SET)'),
            ChecklistItem(id: 'b_desc_6', task: '自动刹车', response: '调定 (SET)'),
            ChecklistItem(id: 'b_desc_7', task: '安全带灯', response: '开启 (ON)'),
            ChecklistItem(
              id: 'b_desc_8',
              task: '客舱通知',
              response: '完成 (NOTIFIED)',
            ),
          ],
        ),

        // ========== 进近前检查 (BEFORE APPROACH) ==========
        ChecklistSection(
          phase: ChecklistPhase.beforeApproach,
          items: [
            ChecklistItem(
              id: 'b_app_1',
              task: '着陆许可',
              response: '获得 (CLEARED)',
            ),
            ChecklistItem(id: 'b_app_2', task: '起落架', response: '放下 (DOWN)'),
            ChecklistItem(id: 'b_app_3', task: '襟翼', response: '着陆位 (LANDING)'),
            ChecklistItem(id: 'b_app_4', task: '着陆灯', response: '开启 (ON)'),
            ChecklistItem(id: 'b_app_5', task: '减速板', response: '预位 (ARMED)'),
            ChecklistItem(id: 'b_app_6', task: '自动刹车', response: '调定 (SET)'),
            ChecklistItem(
              id: 'b_app_7',
              task: '着陆检查单',
              response: '完成 (COMPLETED)',
            ),
          ],
        ),

        // ========== 落地后检查 (AFTER LANDING) ==========
        ChecklistSection(
          phase: ChecklistPhase.afterLanding,
          items: [
            ChecklistItem(id: 'b_land_1', task: '襟翼', response: '收起 (UP)'),
            ChecklistItem(id: 'b_land_2', task: '减速板', response: '收起 (DOWN)'),
            ChecklistItem(id: 'b_land_3', task: '天气雷达', response: '关闭 (OFF)'),
            ChecklistItem(id: 'b_land_4', task: 'APU', response: '启动 (START)'),
            ChecklistItem(id: 'b_land_5', task: '跑道脱离灯', response: '开启 (ON)'),
            ChecklistItem(id: 'b_land_6', task: '滑行灯', response: '开启 (ON)'),
            ChecklistItem(id: 'b_land_7', task: '着陆灯', response: '关闭 (OFF)'),
            ChecklistItem(id: 'b_land_8', task: '应答机', response: 'STBY'),
          ],
        ),

        // ========== 关车/停机检查 (PARKING) ==========
        ChecklistSection(
          phase: ChecklistPhase.parking,
          items: [
            ChecklistItem(id: 'b_park_1', task: '停机刹车', response: '开启 (SET)'),
            ChecklistItem(id: 'b_park_2', task: '轮挡', response: '放置 (CHOCKED)'),
            ChecklistItem(
              id: 'b_park_3',
              task: '燃油手柄 (FUEL LEVERS)',
              response: '切断 (CUT OFF)',
            ),
            ChecklistItem(id: 'b_park_4', task: '安全带灯', response: '关闭 (OFF)'),
            ChecklistItem(id: 'b_park_5', task: '燃油泵', response: '关闭 (OFF)'),
            ChecklistItem(id: 'b_park_6', task: '防撞灯', response: '关闭 (OFF)'),
            ChecklistItem(id: 'b_park_7', task: '外部电源', response: '接通 (ON)'),
            ChecklistItem(id: 'b_park_8', task: 'APU', response: '关闭 (OFF)'),
            ChecklistItem(id: 'b_park_9', task: '探头加热', response: '关闭 (OFF)'),
            ChecklistItem(id: 'b_park_10', task: 'IRS', response: '关闭 (OFF)'),
            ChecklistItem(id: 'b_park_11', task: '液压泵', response: '关闭 (OFF)'),
            ChecklistItem(id: 'b_park_12', task: '电池', response: '关闭 (OFF)'),
          ],
        ),
      ],
    );
  }
}
