import '../../models/flight_checklist.dart';

class B737Checklist {
  static AircraftChecklist create(String name) {
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
