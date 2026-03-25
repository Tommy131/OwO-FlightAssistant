import '../models/flight_checklist.dart';
import '../../../core/services/localization_service.dart';

class A320Checklist {
  static String _l(String zh, String en) {
    return LocalizationService().currentLanguageCode == 'en_US' ? en : zh;
  }

  static AircraftChecklist create(String name) {
    return AircraftChecklist(
      id: 'a320_series',
      name: name,
      family: AircraftFamily.a320,
      sections: [
        ChecklistSection(
          phase: ChecklistPhase.coldAndDark,
          items: [
            ChecklistItem(
              id: 'a1_1',
              task: _l('电池 (BAT 1+2)', 'Battery (BAT 1+2)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a1_2',
              task: _l('外部电源 (EXT PWR)', 'External Power (EXT PWR)'),
              response: _l('可用/接通 (AVAIL/ON)', 'Avail/On (AVAIL/ON)'),
            ),
            ChecklistItem(
              id: 'a1_3',
              task: _l(
                '应急出口灯 (EMER EXIT LT)',
                'Emergency Exit Light (EMER EXIT LT)',
              ),
              response: _l('预位 (ARMED)', 'Armed (ARMED)'),
            ),
            ChecklistItem(
              id: 'a1_4',
              task: _l('座椅安全带 (SEAT BELTS)', 'Seat Belts (SEAT BELTS)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a1_5',
              task: _l('禁止吸烟 (NO SMOKING)', 'No Smoking (NO SMOKING)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a1_6',
              task: _l('ADIRS (1+2+3)', 'ADIRS (1+2+3)'),
              response: _l('调定导航 (NAV)', 'NAV (NAV)'),
            ),
            ChecklistItem(
              id: 'a1_7',
              task: _l('燃油泵 (FUEL PUMPS)', 'Fuel Pumps (FUEL PUMPS)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a1_8',
              task: _l('APU 主电门', 'APU Master Switch'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a1_9',
              task: _l('APU 启动', 'APU Start'),
              response: _l('启动 (START)', 'Start (START)'),
            ),
            ChecklistItem(
              id: 'a1_10',
              task: _l('APU 发电机 (APU GEN)', 'APU Generator (APU GEN)'),
              response: _l('接通 (ON BUS)', 'On Bus (ON BUS)'),
            ),
            ChecklistItem(
              id: 'a1_11',
              task: _l('外部电源', 'External Power'),
              response: _l('断开 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'a1_12',
              task: _l('导航灯 (NAV LIGHTS)', 'Nav Lights (NAV LIGHTS)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a1_13',
              task: _l('FMS 航路输入', 'FMS Route Entry'),
              response: _l('完成 (COMPLETED)', 'Completed (COMPLETED)'),
            ),
            ChecklistItem(
              id: 'a1_14',
              task: _l('MCDU 性能数据', 'MCDU Performance Data'),
              response: _l('输入 (ENTERED)', 'Entered (ENTERED)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforePushback,
          items: [
            ChecklistItem(
              id: 'a2_1',
              task: _l('客舱准备 (CABIN READY)', 'Cabin Ready (CABIN READY)'),
              response: _l('确认 (CONFIRMED)', 'Confirmed (CONFIRMED)'),
            ),
            ChecklistItem(
              id: 'a2_2',
              task: _l('机门 (DOORS)', 'Doors (DOORS)'),
              response: _l('关闭 (CLOSED)', 'Closed (CLOSED)'),
            ),
            ChecklistItem(
              id: 'a2_3',
              task: _l('滑梯 (SLIDES)', 'Slides (SLIDES)'),
              response: _l('预位 (ARMED)', 'Armed (ARMED)'),
            ),
            ChecklistItem(
              id: 'a2_4',
              task: _l('信标灯 (BEACON)', 'Beacon (BEACON)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a2_5',
              task: _l('刹车压力 (BRAKE PRESS)', 'Brake Pressure (BRAKE PRESS)'),
              response: _l('检查 (CHECKED)', 'Checked (CHECKED)'),
            ),
            ChecklistItem(
              id: 'a2_6',
              task: _l('襟翼 (FLAPS)', 'Flaps (FLAPS)'),
              response: _l('调定 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'a2_7',
              task: _l('配平 (PITCH TRIM)', 'Pitch Trim (PITCH TRIM)'),
              response: _l('调定 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'a2_8',
              task: _l('舵面 (RUDDER TRIM)', 'Rudder Trim (RUDDER TRIM)'),
              response: _l('零位 (ZERO)', 'Zero (ZERO)'),
            ),
            ChecklistItem(
              id: 'a2_9',
              task: _l('飞行引导 (FD)', 'Flight Director (FD)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a2_10',
              task: _l('自动刹车 (AUTO BRK)', 'Auto Brake (AUTO BRK)'),
              response: _l('调定 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'a2_11',
              task: _l('停机刹车 (PARK BRK)', 'Park Brake (PARK BRK)'),
              response: _l('松开 (OFF)', 'Released (OFF)'),
            ),
            ChecklistItem(
              id: 'a2_12',
              task: _l('推出许可', 'Pushback Clearance'),
              response: _l('获得 (OBTAINED)', 'Obtained (OBTAINED)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeTaxi,
          items: [
            ChecklistItem(
              id: 'a_taxi_1',
              task: _l('发动机 (ENGINES)', 'Engines (ENGINES)'),
              response: _l('启动完成 (STARTED)', 'Started (STARTED)'),
            ),
            ChecklistItem(
              id: 'a_taxi_2',
              task: _l('发动机参数', 'Engine Parameters'),
              response: _l('正常 (NORMAL)', 'Normal (NORMAL)'),
            ),
            ChecklistItem(
              id: 'a_taxi_3',
              task: _l('APU 引气 (APU BLEED)', 'APU Bleed (APU BLEED)'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'a_taxi_4',
              task: _l('APU', 'APU'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'a_taxi_5',
              task: _l('地面设备', 'Ground Equipment'),
              response: _l('断开 (CLEAR)', 'Disconnected (CLEAR)'),
            ),
            ChecklistItem(
              id: 'a_taxi_6',
              task: _l('防冰系统 (ANTI ICE)', 'Anti-Ice System (ANTI ICE)'),
              response: _l('按需 (AS REQ)', 'As Required (AS REQ)'),
            ),
            ChecklistItem(
              id: 'a_taxi_7',
              task: _l('探头加热 (PROBE HEAT)', 'Probe Heat (PROBE HEAT)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a_taxi_8',
              task: _l('滑行灯 (TAXI LIGHTS)', 'Taxi Lights (TAXI LIGHTS)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a_taxi_9',
              task: _l(
                '跑道脱离灯 (RWY TURN OFF)',
                'Runway Turn Off Lights (RWY TURN OFF)',
              ),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a_taxi_10',
              task: _l('ECAM 状态', 'ECAM Status'),
              response: _l('正常 (NORMAL)', 'Normal (NORMAL)'),
            ),
            ChecklistItem(
              id: 'a_taxi_11',
              task: _l('刹车', 'Brakes'),
              response: _l('测试 (TESTED)', 'Tested (TESTED)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeTakeoff,
          items: [
            ChecklistItem(
              id: 'a3_1',
              task: _l('飞行控制 (FLT CTL)', 'Flight Controls (FLT CTL)'),
              response: _l('检查完成 (CHECKED)', 'Checked (CHECKED)'),
            ),
            ChecklistItem(
              id: 'a3_2',
              task: _l('襟翼/缝翼 (FLAPS/SLATS)', 'Flaps/Slats (FLAPS/SLATS)'),
              response: _l('起飞位 (T.O)', 'Takeoff Position (T.O)'),
            ),
            ChecklistItem(
              id: 'a3_3',
              task: _l('配平 (PITCH TRIM)', 'Pitch Trim (PITCH TRIM)'),
              response: _l('绿带内 (GREEN)', 'In Green Band (GREEN)'),
            ),
            ChecklistItem(
              id: 'a3_4',
              task: _l('起飞简令', 'Takeoff Briefing'),
              response: _l('完成 (BRIEFED)', 'Briefed (BRIEFED)'),
            ),
            ChecklistItem(
              id: 'a3_5',
              task: _l('起飞构型 (T.O CONFIG)', 'Takeoff Config (T.O CONFIG)'),
              response: _l('测试正常 (NORMAL)', 'Test Normal (NORMAL)'),
            ),
            ChecklistItem(
              id: 'a3_6',
              task: _l('ECAM 备忘', 'ECAM Memo'),
              response: _l('清除 (CLEAR)', 'Clear (CLEAR)'),
            ),
            ChecklistItem(
              id: 'a3_7',
              task: _l('跨雷达 (TCAS)', 'TCAS (TCAS)'),
              response: _l('TA/RA', 'TA/RA'),
            ),
            ChecklistItem(
              id: 'a3_8',
              task: _l('应答机 (XPDR)', 'Transponder (XPDR)'),
              response: _l('TA/RA', 'TA/RA'),
            ),
            ChecklistItem(
              id: 'a3_9',
              task: _l('自动驾驶 (A/P)', 'Autopilot (A/P)'),
              response: _l('准备 (READY)', 'Ready (READY)'),
            ),
            ChecklistItem(
              id: 'a3_10',
              task: _l('自动油门 (A/THR)', 'Autothrust (A/THR)'),
              response: _l('预位 (ARMED)', 'Armed (ARMED)'),
            ),
            ChecklistItem(
              id: 'a3_11',
              task: _l('起飞许可', 'Takeoff Clearance'),
              response: _l('获得 (CLEARED)', 'Cleared (CLEARED)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.cruise,
          items: [
            ChecklistItem(
              id: 'a_cruise_1',
              task: _l('高度', 'Altitude'),
              response: _l('巡航高度 (CRUISE ALT)', 'Cruise Altitude (CRUISE ALT)'),
            ),
            ChecklistItem(
              id: 'a_cruise_2',
              task: _l('自动驾驶 (A/P)', 'Autopilot (A/P)'),
              response: _l('接通 (ENGAGED)', 'Engaged (ENGAGED)'),
            ),
            ChecklistItem(
              id: 'a_cruise_3',
              task: _l('自动油门 (A/THR)', 'Autothrust (A/THR)'),
              response: _l('接通 (ENGAGED)', 'Engaged (ENGAGED)'),
            ),
            ChecklistItem(
              id: 'a_cruise_4',
              task: _l('燃油平衡', 'Fuel Balance'),
              response: _l('检查 (CHECKED)', 'Checked (CHECKED)'),
            ),
            ChecklistItem(
              id: 'a_cruise_5',
              task: _l('客舱高度', 'Cabin Altitude'),
              response: _l('正常 (NORMAL)', 'Normal (NORMAL)'),
            ),
            ChecklistItem(
              id: 'a_cruise_6',
              task: _l('安全带灯', 'Seat Belt Sign'),
              response: _l('按需 (AS REQ)', 'As Required (AS REQ)'),
            ),
            ChecklistItem(
              id: 'a_cruise_7',
              task: _l('天气雷达', 'Weather Radar'),
              response: _l('监控 (MONITORED)', 'Monitored (MONITORED)'),
            ),
            ChecklistItem(
              id: 'a_cruise_8',
              task: _l('ECAM 状态', 'ECAM Status'),
              response: _l('正常 (NORMAL)', 'Normal (NORMAL)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeDescent,
          items: [
            ChecklistItem(
              id: 'a_desc_1',
              task: _l('进近简令', 'Approach Briefing'),
              response: _l('完成 (BRIEFED)', 'Briefed (BRIEFED)'),
            ),
            ChecklistItem(
              id: 'a_desc_2',
              task: _l('ATIS 信息', 'ATIS Information'),
              response: _l('获得 (OBTAINED)', 'Obtained (OBTAINED)'),
            ),
            ChecklistItem(
              id: 'a_desc_3',
              task: _l('高度表 (BARO)', 'Barometer (BARO)'),
              response: _l('调定 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'a_desc_4',
              task: _l('着陆标高 (LDG ELEV)', 'Landing Elevation (LDG ELEV)'),
              response: _l('输入 (ENTERED)', 'Entered (ENTERED)'),
            ),
            ChecklistItem(
              id: 'a_desc_5',
              task: _l('最低标准 (MINIMUMS)', 'Minimums (MINIMUMS)'),
              response: _l('调定 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'a_desc_6',
              task: _l('自动刹车 (AUTO BRK)', 'Auto Brake (AUTO BRK)'),
              response: _l('调定 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'a_desc_7',
              task: _l('安全带灯', 'Seat Belt Sign'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a_desc_8',
              task: _l('客舱准备', 'Cabin Ready'),
              response: _l('通知 (NOTIFIED)', 'Notified (NOTIFIED)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.beforeApproach,
          items: [
            ChecklistItem(
              id: 'a_app_1',
              task: _l('着陆许可', 'Landing Clearance'),
              response: _l('获得 (CLEARED)', 'Cleared (CLEARED)'),
            ),
            ChecklistItem(
              id: 'a_app_2',
              task: _l('起落架 (GEAR)', 'Landing Gear (GEAR)'),
              response: _l('放下 (DOWN)', 'Down (DOWN)'),
            ),
            ChecklistItem(
              id: 'a_app_3',
              task: _l('襟翼 (FLAPS)', 'Flaps (FLAPS)'),
              response: _l('着陆位 (FULL)', 'Landing Position (FULL)'),
            ),
            ChecklistItem(
              id: 'a_app_4',
              task: _l('着陆灯 (LDG LIGHTS)', 'Landing Lights (LDG LIGHTS)'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a_app_5',
              task: _l('地面扰流板 (GND SPLRS)', 'Ground Spoilers (GND SPLRS)'),
              response: _l('预位 (ARMED)', 'Armed (ARMED)'),
            ),
            ChecklistItem(
              id: 'a_app_6',
              task: _l('自动刹车', 'Auto Brake'),
              response: _l('调定 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'a_app_7',
              task: _l('ECAM 备忘', 'ECAM Memo'),
              response: _l('清除 (CLEAR)', 'Clear (CLEAR)'),
            ),
            ChecklistItem(
              id: 'a_app_8',
              task: _l('着陆检查单', 'Landing Checklist'),
              response: _l('完成 (COMPLETED)', 'Completed (COMPLETED)'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.afterLanding,
          items: [
            ChecklistItem(
              id: 'a_land_1',
              task: _l('襟翼 (FLAPS)', 'Flaps (FLAPS)'),
              response: _l('收起 (UP)', 'Up (UP)'),
            ),
            ChecklistItem(
              id: 'a_land_2',
              task: _l('减速板 (SPOILERS)', 'Spoilers (SPOILERS)'),
              response: _l('收起 (RETRACTED)', 'Retracted (RETRACTED)'),
            ),
            ChecklistItem(
              id: 'a_land_3',
              task: _l('天气雷达 (WX RADAR)', 'Weather Radar (WX RADAR)'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'a_land_4',
              task: _l('预测风切变 (PWS)', 'Predictive Windshear (PWS)'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'a_land_5',
              task: _l('APU', 'APU'),
              response: _l('启动 (START)', 'Start (START)'),
            ),
            ChecklistItem(
              id: 'a_land_6',
              task: _l('跑道脱离灯', 'Runway Turn Off Lights'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a_land_7',
              task: _l('滑行灯', 'Taxi Lights'),
              response: _l('开启 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a_land_8',
              task: _l('着陆灯', 'Landing Lights'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'a_land_9',
              task: _l('应答机 (XPDR)', 'Transponder (XPDR)'),
              response: _l('STBY', 'STBY'),
            ),
          ],
        ),
        ChecklistSection(
          phase: ChecklistPhase.parking,
          items: [
            ChecklistItem(
              id: 'a_park_1',
              task: _l('停机刹车 (PARK BRK)', 'Park Brake (PARK BRK)'),
              response: _l('开启 (SET)', 'Set (SET)'),
            ),
            ChecklistItem(
              id: 'a_park_2',
              task: _l('轮挡', 'Wheel Chocks'),
              response: _l('放置 (CHOCKED)', 'Chocked (CHOCKED)'),
            ),
            ChecklistItem(
              id: 'a_park_3',
              task: _l('发动机 (ENGINES)', 'Engines (ENGINES)'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'a_park_4',
              task: _l('安全带灯', 'Seat Belt Sign'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'a_park_5',
              task: _l('燃油泵', 'Fuel Pumps'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'a_park_6',
              task: _l('信标灯', 'Beacon'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'a_park_7',
              task: _l('外部电源', 'External Power'),
              response: _l('接通 (ON)', 'On (ON)'),
            ),
            ChecklistItem(
              id: 'a_park_8',
              task: _l('APU', 'APU'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'a_park_9',
              task: _l('滑梯 (SLIDES)', 'Slides (SLIDES)'),
              response: _l('解除预位 (DISARMED)', 'Disarmed (DISARMED)'),
            ),
            ChecklistItem(
              id: 'a_park_10',
              task: _l('机门', 'Doors'),
              response: _l('可以打开 (OPEN)', 'May Open (OPEN)'),
            ),
            ChecklistItem(
              id: 'a_park_11',
              task: _l('ADIRS', 'ADIRS'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
            ChecklistItem(
              id: 'a_park_12',
              task: _l('电池', 'Battery'),
              response: _l('关闭 (OFF)', 'Off (OFF)'),
            ),
          ],
        ),
      ],
    );
  }
}
