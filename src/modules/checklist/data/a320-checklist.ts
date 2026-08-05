import { l } from './checklist-i18n-helper';
import type { AircraftChecklist } from '../models/flight-checklist';

/**
 * A320 系列标准检查单
 *
 * 由 Flutter 版 `modules/checklist/data/a320_checklist.dart` 机械转换而来，
 * 条目 id / 中英文文案逐条保持一致。
 */

export function createA320Checklist(name: string): AircraftChecklist {
  return {
    id: 'a320_series',
    name,
    family: 'a320',
    sections: [
      {
        phase: 'coldAndDark',
        items: [
          { id: 'a1_1', task: l('电池 (BAT 1+2)', 'Battery (BAT 1+2)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a1_2', task: l('外部电源 (EXT PWR)', 'External Power (EXT PWR)'), response: l('可用/接通 (AVAIL/ON)', 'Avail/On (AVAIL/ON)'), isChecked: false },
          { id: 'a1_3', task: l('应急出口灯 (EMER EXIT LT)', 'Emergency Exit Light (EMER EXIT LT)'), response: l('预位 (ARMED)', 'Armed (ARMED)'), isChecked: false },
          { id: 'a1_4', task: l('座椅安全带 (SEAT BELTS)', 'Seat Belts (SEAT BELTS)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a1_5', task: l('禁止吸烟 (NO SMOKING)', 'No Smoking (NO SMOKING)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a1_6', task: l('ADIRS (1+2+3)', 'ADIRS (1+2+3)'), response: l('调定导航 (NAV)', 'NAV (NAV)'), isChecked: false },
          { id: 'a1_7', task: l('燃油泵 (FUEL PUMPS)', 'Fuel Pumps (FUEL PUMPS)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a1_8', task: l('APU 主电门', 'APU Master Switch'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a1_9', task: l('APU 启动', 'APU Start'), response: l('启动 (START)', 'Start (START)'), isChecked: false },
          { id: 'a1_10', task: l('APU 发电机 (APU GEN)', 'APU Generator (APU GEN)'), response: l('接通 (ON BUS)', 'On Bus (ON BUS)'), isChecked: false },
          { id: 'a1_11', task: l('外部电源', 'External Power'), response: l('断开 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'a1_12', task: l('导航灯 (NAV LIGHTS)', 'Nav Lights (NAV LIGHTS)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a1_13', task: l('FMS 航路输入', 'FMS Route Entry'), response: l('完成 (COMPLETED)', 'Completed (COMPLETED)'), isChecked: false },
          { id: 'a1_14', task: l('MCDU 性能数据', 'MCDU Performance Data'), response: l('输入 (ENTERED)', 'Entered (ENTERED)'), isChecked: false },
        ],
      },
      {
        phase: 'beforePushback',
        items: [
          { id: 'a2_1', task: l('客舱准备 (CABIN READY)', 'Cabin Ready (CABIN READY)'), response: l('确认 (CONFIRMED)', 'Confirmed (CONFIRMED)'), isChecked: false },
          { id: 'a2_2', task: l('机门 (DOORS)', 'Doors (DOORS)'), response: l('关闭 (CLOSED)', 'Closed (CLOSED)'), isChecked: false },
          { id: 'a2_3', task: l('滑梯 (SLIDES)', 'Slides (SLIDES)'), response: l('预位 (ARMED)', 'Armed (ARMED)'), isChecked: false },
          { id: 'a2_4', task: l('信标灯 (BEACON)', 'Beacon (BEACON)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a2_5', task: l('刹车压力 (BRAKE PRESS)', 'Brake Pressure (BRAKE PRESS)'), response: l('检查 (CHECKED)', 'Checked (CHECKED)'), isChecked: false },
          { id: 'a2_6', task: l('襟翼 (FLAPS)', 'Flaps (FLAPS)'), response: l('调定 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'a2_7', task: l('配平 (PITCH TRIM)', 'Pitch Trim (PITCH TRIM)'), response: l('调定 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'a2_8', task: l('舵面 (RUDDER TRIM)', 'Rudder Trim (RUDDER TRIM)'), response: l('零位 (ZERO)', 'Zero (ZERO)'), isChecked: false },
          { id: 'a2_9', task: l('飞行引导 (FD)', 'Flight Director (FD)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a2_10', task: l('自动刹车 (AUTO BRK)', 'Auto Brake (AUTO BRK)'), response: l('调定 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'a2_11', task: l('停机刹车 (PARK BRK)', 'Park Brake (PARK BRK)'), response: l('松开 (OFF)', 'Released (OFF)'), isChecked: false },
          { id: 'a2_12', task: l('推出许可', 'Pushback Clearance'), response: l('获得 (OBTAINED)', 'Obtained (OBTAINED)'), isChecked: false },
        ],
      },
      {
        phase: 'beforeTaxi',
        items: [
          { id: 'a_taxi_1', task: l('发动机 (ENGINES)', 'Engines (ENGINES)'), response: l('启动完成 (STARTED)', 'Started (STARTED)'), isChecked: false },
          { id: 'a_taxi_2', task: l('发动机参数', 'Engine Parameters'), response: l('正常 (NORMAL)', 'Normal (NORMAL)'), isChecked: false },
          { id: 'a_taxi_3', task: l('APU 引气 (APU BLEED)', 'APU Bleed (APU BLEED)'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'a_taxi_4', task: l('APU', 'APU'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'a_taxi_5', task: l('地面设备', 'Ground Equipment'), response: l('断开 (CLEAR)', 'Disconnected (CLEAR)'), isChecked: false },
          { id: 'a_taxi_6', task: l('防冰系统 (ANTI ICE)', 'Anti-Ice System (ANTI ICE)'), response: l('按需 (AS REQ)', 'As Required (AS REQ)'), isChecked: false },
          { id: 'a_taxi_7', task: l('探头加热 (PROBE HEAT)', 'Probe Heat (PROBE HEAT)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a_taxi_8', task: l('滑行灯 (TAXI LIGHTS)', 'Taxi Lights (TAXI LIGHTS)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a_taxi_9', task: l('跑道脱离灯 (RWY TURN OFF)', 'Runway Turn Off Lights (RWY TURN OFF)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a_taxi_10', task: l('ECAM 状态', 'ECAM Status'), response: l('正常 (NORMAL)', 'Normal (NORMAL)'), isChecked: false },
          { id: 'a_taxi_11', task: l('刹车', 'Brakes'), response: l('测试 (TESTED)', 'Tested (TESTED)'), isChecked: false },
        ],
      },
      {
        phase: 'beforeTakeoff',
        items: [
          { id: 'a3_1', task: l('飞行控制 (FLT CTL)', 'Flight Controls (FLT CTL)'), response: l('检查完成 (CHECKED)', 'Checked (CHECKED)'), isChecked: false },
          { id: 'a3_2', task: l('襟翼/缝翼 (FLAPS/SLATS)', 'Flaps/Slats (FLAPS/SLATS)'), response: l('起飞位 (T.O)', 'Takeoff Position (T.O)'), isChecked: false },
          { id: 'a3_3', task: l('配平 (PITCH TRIM)', 'Pitch Trim (PITCH TRIM)'), response: l('绿带内 (GREEN)', 'In Green Band (GREEN)'), isChecked: false },
          { id: 'a3_4', task: l('起飞简令', 'Takeoff Briefing'), response: l('完成 (BRIEFED)', 'Briefed (BRIEFED)'), isChecked: false },
          { id: 'a3_5', task: l('起飞构型 (T.O CONFIG)', 'Takeoff Config (T.O CONFIG)'), response: l('测试正常 (NORMAL)', 'Test Normal (NORMAL)'), isChecked: false },
          { id: 'a3_6', task: l('ECAM 备忘', 'ECAM Memo'), response: l('清除 (CLEAR)', 'Clear (CLEAR)'), isChecked: false },
          { id: 'a3_7', task: l('跨雷达 (TCAS)', 'TCAS (TCAS)'), response: l('TA/RA', 'TA/RA'), isChecked: false },
          { id: 'a3_8', task: l('应答机 (XPDR)', 'Transponder (XPDR)'), response: l('TA/RA', 'TA/RA'), isChecked: false },
          { id: 'a3_9', task: l('自动驾驶 (A/P)', 'Autopilot (A/P)'), response: l('准备 (READY)', 'Ready (READY)'), isChecked: false },
          { id: 'a3_10', task: l('自动油门 (A/THR)', 'Autothrust (A/THR)'), response: l('预位 (ARMED)', 'Armed (ARMED)'), isChecked: false },
          { id: 'a3_11', task: l('起飞许可', 'Takeoff Clearance'), response: l('获得 (CLEARED)', 'Cleared (CLEARED)'), isChecked: false },
        ],
      },
      {
        phase: 'cruise',
        items: [
          { id: 'a_cruise_1', task: l('高度', 'Altitude'), response: l('巡航高度 (CRUISE ALT)', 'Cruise Altitude (CRUISE ALT)'), isChecked: false },
          { id: 'a_cruise_2', task: l('自动驾驶 (A/P)', 'Autopilot (A/P)'), response: l('接通 (ENGAGED)', 'Engaged (ENGAGED)'), isChecked: false },
          { id: 'a_cruise_3', task: l('自动油门 (A/THR)', 'Autothrust (A/THR)'), response: l('接通 (ENGAGED)', 'Engaged (ENGAGED)'), isChecked: false },
          { id: 'a_cruise_4', task: l('燃油平衡', 'Fuel Balance'), response: l('检查 (CHECKED)', 'Checked (CHECKED)'), isChecked: false },
          { id: 'a_cruise_5', task: l('客舱高度', 'Cabin Altitude'), response: l('正常 (NORMAL)', 'Normal (NORMAL)'), isChecked: false },
          { id: 'a_cruise_6', task: l('安全带灯', 'Seat Belt Sign'), response: l('按需 (AS REQ)', 'As Required (AS REQ)'), isChecked: false },
          { id: 'a_cruise_7', task: l('天气雷达', 'Weather Radar'), response: l('监控 (MONITORED)', 'Monitored (MONITORED)'), isChecked: false },
          { id: 'a_cruise_8', task: l('ECAM 状态', 'ECAM Status'), response: l('正常 (NORMAL)', 'Normal (NORMAL)'), isChecked: false },
        ],
      },
      {
        phase: 'beforeDescent',
        items: [
          { id: 'a_desc_1', task: l('进近简令', 'Approach Briefing'), response: l('完成 (BRIEFED)', 'Briefed (BRIEFED)'), isChecked: false },
          { id: 'a_desc_2', task: l('ATIS 信息', 'ATIS Information'), response: l('获得 (OBTAINED)', 'Obtained (OBTAINED)'), isChecked: false },
          { id: 'a_desc_3', task: l('高度表 (BARO)', 'Barometer (BARO)'), response: l('调定 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'a_desc_4', task: l('着陆标高 (LDG ELEV)', 'Landing Elevation (LDG ELEV)'), response: l('输入 (ENTERED)', 'Entered (ENTERED)'), isChecked: false },
          { id: 'a_desc_5', task: l('最低标准 (MINIMUMS)', 'Minimums (MINIMUMS)'), response: l('调定 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'a_desc_6', task: l('自动刹车 (AUTO BRK)', 'Auto Brake (AUTO BRK)'), response: l('调定 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'a_desc_7', task: l('安全带灯', 'Seat Belt Sign'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a_desc_8', task: l('客舱准备', 'Cabin Ready'), response: l('通知 (NOTIFIED)', 'Notified (NOTIFIED)'), isChecked: false },
        ],
      },
      {
        phase: 'beforeApproach',
        items: [
          { id: 'a_app_1', task: l('着陆许可', 'Landing Clearance'), response: l('获得 (CLEARED)', 'Cleared (CLEARED)'), isChecked: false },
          { id: 'a_app_2', task: l('起落架 (GEAR)', 'Landing Gear (GEAR)'), response: l('放下 (DOWN)', 'Down (DOWN)'), isChecked: false },
          { id: 'a_app_3', task: l('襟翼 (FLAPS)', 'Flaps (FLAPS)'), response: l('着陆位 (FULL)', 'Landing Position (FULL)'), isChecked: false },
          { id: 'a_app_4', task: l('着陆灯 (LDG LIGHTS)', 'Landing Lights (LDG LIGHTS)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a_app_5', task: l('地面扰流板 (GND SPLRS)', 'Ground Spoilers (GND SPLRS)'), response: l('预位 (ARMED)', 'Armed (ARMED)'), isChecked: false },
          { id: 'a_app_6', task: l('自动刹车', 'Auto Brake'), response: l('调定 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'a_app_7', task: l('ECAM 备忘', 'ECAM Memo'), response: l('清除 (CLEAR)', 'Clear (CLEAR)'), isChecked: false },
          { id: 'a_app_8', task: l('着陆检查单', 'Landing Checklist'), response: l('完成 (COMPLETED)', 'Completed (COMPLETED)'), isChecked: false },
        ],
      },
      {
        phase: 'afterLanding',
        items: [
          { id: 'a_land_1', task: l('襟翼 (FLAPS)', 'Flaps (FLAPS)'), response: l('收起 (UP)', 'Up (UP)'), isChecked: false },
          { id: 'a_land_2', task: l('减速板 (SPOILERS)', 'Spoilers (SPOILERS)'), response: l('收起 (RETRACTED)', 'Retracted (RETRACTED)'), isChecked: false },
          { id: 'a_land_3', task: l('天气雷达 (WX RADAR)', 'Weather Radar (WX RADAR)'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'a_land_4', task: l('预测风切变 (PWS)', 'Predictive Windshear (PWS)'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'a_land_5', task: l('APU', 'APU'), response: l('启动 (START)', 'Start (START)'), isChecked: false },
          { id: 'a_land_6', task: l('跑道脱离灯', 'Runway Turn Off Lights'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a_land_7', task: l('滑行灯', 'Taxi Lights'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a_land_8', task: l('着陆灯', 'Landing Lights'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'a_land_9', task: l('应答机 (XPDR)', 'Transponder (XPDR)'), response: l('STBY', 'STBY'), isChecked: false },
        ],
      },
      {
        phase: 'parking',
        items: [
          { id: 'a_park_1', task: l('停机刹车 (PARK BRK)', 'Park Brake (PARK BRK)'), response: l('开启 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'a_park_2', task: l('轮挡', 'Wheel Chocks'), response: l('放置 (CHOCKED)', 'Chocked (CHOCKED)'), isChecked: false },
          { id: 'a_park_3', task: l('发动机 (ENGINES)', 'Engines (ENGINES)'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'a_park_4', task: l('安全带灯', 'Seat Belt Sign'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'a_park_5', task: l('燃油泵', 'Fuel Pumps'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'a_park_6', task: l('信标灯', 'Beacon'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'a_park_7', task: l('外部电源', 'External Power'), response: l('接通 (ON)', 'On (ON)'), isChecked: false },
          { id: 'a_park_8', task: l('APU', 'APU'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'a_park_9', task: l('滑梯 (SLIDES)', 'Slides (SLIDES)'), response: l('解除预位 (DISARMED)', 'Disarmed (DISARMED)'), isChecked: false },
          { id: 'a_park_10', task: l('机门', 'Doors'), response: l('可以打开 (OPEN)', 'May Open (OPEN)'), isChecked: false },
          { id: 'a_park_11', task: l('ADIRS', 'ADIRS'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'a_park_12', task: l('电池', 'Battery'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
        ],
      },
    ],
  };
}
