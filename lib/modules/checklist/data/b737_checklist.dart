import '../models/flight_checklist.dart';
import '../../../core/services/localization_service.dart';

class B737Checklist {
  static String _l(String zh, String en) {
    return LocalizationService().currentLanguageCode == 'en_US' ? en : zh;
  }

  static AircraftChecklist create(String name) {
    return AircraftChecklist(
      id: 'b737_series',
      name: name,
      family: AircraftFamily.b737,
      sections: [
        ChecklistSection(
          phase: ChecklistPhase.coldAndDark,
          items: [
            ChecklistItem(
              id: 'b1_1',
              task: _l('电池开关 (BATTERY)', 'Battery Switch (BATTERY)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b1_2',
              task: _l('备用电源 (STANDBY PWR)', 'Standby Power (STANDBY PWR)'),
              response: _l('自动 (AUTO)', 'Auto (AUTO)'),
            ),
            ChecklistItem(
              id: 'b1_3',
              task: _l('外部电源 (EXT PWR)', 'External Power (EXT PWR)'),
              response: _l('接通 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b1_4',
              task: _l('应急出口灯', 'Emergency Exit Lights'),
              response: _l('预位 (ARMED)', 'Armed (ARMED)'),
            ),
            ChecklistItem(
              id: 'b1_5',
              task: _l('安全带标志', 'Seat Belt Sign'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b1_6',
              task: _l('禁止吸烟', 'No Smoking'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b1_7',
              task: _l('IRS 模式选择器', 'IRS Mode Selector'),
              response: _l('导航 (NAV)', 'Nav (NAV)'),
            ),
            ChecklistItem(
              id: 'b1_8',
              task: _l('液压泵 (HYD PUMPS)', 'Hydraulic Pumps (HYD PUMPS)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b1_9',
              task: _l('APU 开关', 'APU Switch'),
              response: _l('启动 (START)', 'Start (START)'),
            ),
            ChecklistItem(
              id: 'b1_10',
              task: _l('APU 发电机', 'APU Generator'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b1_11',
              task: _l('FMC 航路', 'FMC Route'),
              response: _l('输入 (ENTERED)', 'Entered (ENTERED)'),
            ),
            ChecklistItem(
              id: 'b1_12',
              task: _l('性能数据', 'Performance Data'),
              response: _l('输入 (ENTERED)', 'Entered (ENTERED)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforePushback,
          items: [
            ChecklistItem(
              id: 'b2_1',
              task: _l('客舱报告', 'Cabin Report'),
              response: _l('收到 (RECEIVED)', 'Received (RECEIVED)'),
            ),
            ChecklistItem(
              id: 'b2_2',
              task: _l('机门', 'Doors'),
              response: _l('关闭 (CLOSED)', 'Closed (CLOSED)'),
            ),
            ChecklistItem(
              id: 'b2_3',
              task: _l('燃油泵 (FUEL PUMPS)', 'Fuel Pumps (FUEL PUMPS)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b2_4',
              task: _l('座椅腰带', 'Seat Belts'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b2_5',
              task: _l('防撞灯 (ANTI COLLISION)', 'Anti-Collision Light (ANTI COLLISION)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b2_6',
              task: _l('襟翼', 'Flaps'),
              response: _l('调定 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'b2_7',
              task: _l('稳定器配平', 'Stabilizer Trim'),
              response: _l('调定 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'b2_8',
              task: _l('推力杠 (THROTTLE)', 'Throttle (THROTTLE)'),
              response: _l('怠速 (IDLE)', 'Idle (IDLE)'),
            ),
            ChecklistItem(
              id: 'b2_9',
              task: _l('停机刹车', 'Park Brake'),
              response: _l('松开 (RELEASED)', 'Released (RELEASED)'),
            ),
            ChecklistItem(
              id: 'b2_10',
              task: _l('推出许可', 'Pushback Clearance'),
              response: _l('获得 (CLEARED)', 'Cleared (CLEARED)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeTaxi,
          items: [
            ChecklistItem(
              id: 'b_taxi_1',
              task: _l('发动机启动', 'Engine Start'),
              response: _l('完成 (COMPLETED)', 'Completed (COMPLETED)'),
            ),
            ChecklistItem(
              id: 'b_taxi_2',
              task: _l('发电机 (GENERATORS)', 'Generators (GENERATORS)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b_taxi_3',
              task: _l('探头加热 (PROBE HEAT)', 'Probe Heat (PROBE HEAT)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b_taxi_4',
              task: _l('引气 (BLEED AIR)', 'Bleed Air (BLEED AIR)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b_taxi_5',
              task: _l('隔离阀 (ISOLATION VALVE)', 'Isolation Valve (ISOLATION VALVE)'),
              response: _l('自动 (AUTO)', 'Auto (AUTO)'),
            ),
            ChecklistItem(
              id: 'b_taxi_6',
              task: _l('APU', 'APU'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'b_taxi_7',
              task: _l('防冰系统', 'Anti-Ice System'),
              response: _l('按需 (AS REQ)', 'As Required (AS REQ)'),
            ),
            ChecklistItem(
              id: 'b_taxi_8',
              task: _l('滑行灯', 'Taxi Lights'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b_taxi_9',
              task: _l('跑道脱离灯', 'Runway Turn Off Lights'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b_taxi_10',
              task: _l('刹车测试', 'Brake Test'),
              response: _l('完成 (TESTED)', 'Tested (TESTED)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeTakeoff,
          items: [
            ChecklistItem(
              id: 'b3_1',
              task: _l('飞行控制', 'Flight Controls'),
              response: _l('检查 (CHECKED)', 'Checked (CHECKED)'),
            ),
            ChecklistItem(
              id: 'b3_2',
              task: _l('襟翼', 'Flaps'),
              response: _l('起飞位 (T.O)', 'Takeoff Position (T.O)'),
            ),
            ChecklistItem(
              id: 'b3_3',
              task: _l('配平', 'Trim'),
              response: _l('绿带内 (GREEN)', 'In Green Band (GREEN)'),
            ),
            ChecklistItem(
              id: 'b3_4',
              task: _l('起飞简令', 'Takeoff Briefing'),
              response: _l('完成 (BRIEFED)', 'Briefed (BRIEFED)'),
            ),
            ChecklistItem(
              id: 'b3_5',
              task: _l('起飞数据', 'Takeoff Data'),
              response: _l('确认 (VERIFIED)', 'Verified (VERIFIED)'),
            ),
            ChecklistItem(
              id: 'b3_6',
              task: _l('TCAS', 'TCAS'),
              response: _l('TA/RA', 'TA/RA'),
            ),
            ChecklistItem(
              id: 'b3_7',
              task: _l('应答机', 'Transponder'),
              response: _l('TA/RA', 'TA/RA'),
            ),
            ChecklistItem(
              id: 'b3_8',
              task: _l('自动驾驶', 'Autopilot'),
              response: _l('预位 (ARMED)', 'Armed (ARMED)'),
            ),
            ChecklistItem(
              id: 'b3_9',
              task: _l('自动油门', 'Autothrottle'),
              response: _l('预位 (ARMED)', 'Armed (ARMED)'),
            ),
            ChecklistItem(
              id: 'b3_10',
              task: _l('起飞许可', 'Takeoff Clearance'),
              response: _l('获得 (CLEARED)', 'Cleared (CLEARED)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.cruise,
          items: [
            ChecklistItem(
              id: 'b_cruise_1',
              task: _l('巡航高度', 'Cruise Altitude'),
              response: _l('到达 (REACHED)', 'Reached (REACHED)'),
            ),
            ChecklistItem(
              id: 'b_cruise_2',
              task: _l('自动驾驶', 'Autopilot'),
              response: _l('接通 (ENGAGED)', 'Engaged (ENGAGED)'),
            ),
            ChecklistItem(
              id: 'b_cruise_3',
              task: _l('自动油门', 'Autothrottle'),
              response: _l('接通 (ENGAGED)', 'Engaged (ENGAGED)'),
            ),
            ChecklistItem(
              id: 'b_cruise_4',
              task: _l('燃油平衡', 'Fuel Balance'),
              response: _l('检查 (CHECKED)', 'Checked (CHECKED)'),
            ),
            ChecklistItem(
              id: 'b_cruise_5',
              task: _l('客舱高度', 'Cabin Altitude'),
              response: _l('正常 (NORMAL)', 'Normal (NORMAL)'),
            ),
            ChecklistItem(
              id: 'b_cruise_6',
              task: _l('安全带灯', 'Seat Belt Sign'),
              response: _l('按需 (AS REQ)', 'As Required (AS REQ)'),
            ),
            ChecklistItem(
              id: 'b_cruise_7',
              task: _l('天气雷达', 'Weather Radar'),
              response: _l('监控 (MONITORED)', 'Monitored (MONITORED)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeDescent,
          items: [
            ChecklistItem(
              id: 'b_desc_1',
              task: _l('进近简令', 'Approach Briefing'),
              response: _l('完成 (BRIEFED)', 'Briefed (BRIEFED)'),
            ),
            ChecklistItem(
              id: 'b_desc_2',
              task: _l('ATIS', 'ATIS'),
              response: _l('获得 (OBTAINED)', 'Obtained (OBTAINED)'),
            ),
            ChecklistItem(
              id: 'b_desc_3',
              task: _l('高度表', 'Altimeter'),
              response: _l('调定 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'b_desc_4',
              task: _l('着陆标高', 'Landing Elevation'),
              response: _l('输入 (ENTERED)', 'Entered (ENTERED)'),
            ),
            ChecklistItem(
              id: 'b_desc_5',
              task: _l('最低标准', 'Minimums'),
              response: _l('调定 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'b_desc_6',
              task: _l('自动刹车', 'Auto Brake'),
              response: _l('调定 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'b_desc_7',
              task: _l('安全带灯', 'Seat Belt Sign'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b_desc_8',
              task: _l('客舱通知', 'Cabin Notification'),
              response: _l('完成 (NOTIFIED)', 'Notified (NOTIFIED)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeApproach,
          items: [
            ChecklistItem(
              id: 'b_app_1',
              task: _l('着陆许可', 'Landing Clearance'),
              response: _l('获得 (CLEARED)', 'Cleared (CLEARED)'),
            ),
            ChecklistItem(
              id: 'b_app_2',
              task: _l('起落架', 'Landing Gear'),
              response: _l('放下 (DOWN)', 'Down (DOWN)'),
            ),
            ChecklistItem(
              id: 'b_app_3',
              task: _l('襟翼', 'Flaps'),
              response: _l('着陆位 (LANDING)', 'Landing Position (LANDING)'),
            ),
            ChecklistItem(
              id: 'b_app_4',
              task: _l('着陆灯', 'Landing Lights'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b_app_5',
              task: _l('减速板', 'Speedbrake'),
              response: _l('预位 (ARMED)', 'Armed (ARMED)'),
            ),
            ChecklistItem(
              id: 'b_app_6',
              task: _l('自动刹车', 'Auto Brake'),
              response: _l('调定 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'b_app_7',
              task: _l('着陆检查单', 'Landing Checklist'),
              response: _l('完成 (COMPLETED)', 'Completed (COMPLETED)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.afterLanding,
          items: [
            ChecklistItem(
              id: 'b_land_1',
              task: _l('襟翼', 'Flaps'),
              response: _l('收起 (UP)', 'Up (UP)'),
            ),
            ChecklistItem(
              id: 'b_land_2',
              task: _l('减速板', 'Speedbrake'),
              response: _l('收起 (DOWN)', 'Down (DOWN)'),
            ),
            ChecklistItem(
              id: 'b_land_3',
              task: _l('天气雷达', 'Weather Radar'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'b_land_4',
              task: _l('APU', 'APU'),
              response: _l('启动 (START)', 'Start (START)'),
            ),
            ChecklistItem(
              id: 'b_land_5',
              task: _l('跑道脱离灯', 'Runway Turn Off Lights'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b_land_6',
              task: _l('滑行灯', 'Taxi Lights'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b_land_7',
              task: _l('着陆灯', 'Landing Lights'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'b_land_8',
              task: _l('应答机', 'Transponder'),
              response: _l('STBY', 'STBY'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.parking,
          items: [
            ChecklistItem(
              id: 'b_park_1',
              task: _l('停机刹车', 'Park Brake'),
              response: _l('开启 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'b_park_2',
              task: _l('轮挡', 'Wheel Chocks'),
              response: _l('放置 (CHOCKED)', 'Chocked (CHOCKED)'),
            ),
            ChecklistItem(
              id: 'b_park_3',
              task: _l('燃油手柄 (FUEL LEVERS)', 'Fuel Levers (FUEL LEVERS)'),
              response: _l('切断 (CUT OFF)', 'Cut Off (CUT OFF)'),
            ),
            ChecklistItem(
              id: 'b_park_4',
              task: _l('安全带灯', 'Seat Belt Sign'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'b_park_5',
              task: _l('燃油泵', 'Fuel Pumps'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'b_park_6',
              task: _l('防撞灯', 'Anti-Collision Light'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'b_park_7',
              task: _l('外部电源', 'External Power'),
              response: _l('接通 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'b_park_8',
              task: _l('APU', 'APU'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'b_park_9',
              task: _l('探头加热', 'Probe Heat'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'b_park_10',
              task: _l('IRS', 'IRS'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'b_park_11',
              task: _l('液压泵', 'Hydraulic Pumps'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'b_park_12',
              task: _l('电池', 'Battery'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
          ],
        ),
      ],
    );
  }
}
