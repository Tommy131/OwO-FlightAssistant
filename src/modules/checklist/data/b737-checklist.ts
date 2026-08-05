import { l } from './checklist-i18n-helper';
import type { AircraftChecklist } from '../models/flight-checklist';

/**
 * B737 系列标准检查单
 *
 * 由 Flutter 版 `modules/checklist/data/b737_checklist.dart` 机械转换而来，
 * 条目 id / 中英文文案逐条保持一致。
 */

export function createB737Checklist(name: string): AircraftChecklist {
  return {
    id: 'b737_series',
    name,
    family: 'b737',
    sections: [
      {
        phase: 'coldAndDark',
        items: [
          { id: 'b1_1', task: l('电池开关 (BATTERY)', 'Battery Switch (BATTERY)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b1_2', task: l('备用电源 (STANDBY PWR)', 'Standby Power (STANDBY PWR)'), response: l('自动 (AUTO)', 'Auto (AUTO)'), isChecked: false },
          { id: 'b1_3', task: l('外部电源 (EXT PWR)', 'External Power (EXT PWR)'), response: l('接通 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b1_4', task: l('应急出口灯', 'Emergency Exit Lights'), response: l('预位 (ARMED)', 'Armed (ARMED)'), isChecked: false },
          { id: 'b1_5', task: l('安全带标志', 'Seat Belt Sign'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b1_6', task: l('禁止吸烟', 'No Smoking'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b1_7', task: l('IRS 模式选择器', 'IRS Mode Selector'), response: l('导航 (NAV)', 'Nav (NAV)'), isChecked: false },
          { id: 'b1_8', task: l('液压泵 (HYD PUMPS)', 'Hydraulic Pumps (HYD PUMPS)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b1_9', task: l('APU 开关', 'APU Switch'), response: l('启动 (START)', 'Start (START)'), isChecked: false },
          { id: 'b1_10', task: l('APU 发电机', 'APU Generator'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b1_11', task: l('FMC 航路', 'FMC Route'), response: l('输入 (ENTERED)', 'Entered (ENTERED)'), isChecked: false },
          { id: 'b1_12', task: l('性能数据', 'Performance Data'), response: l('输入 (ENTERED)', 'Entered (ENTERED)'), isChecked: false },
        ],
      },
      {
        phase: 'beforePushback',
        items: [
          { id: 'b2_1', task: l('客舱报告', 'Cabin Report'), response: l('收到 (RECEIVED)', 'Received (RECEIVED)'), isChecked: false },
          { id: 'b2_2', task: l('机门', 'Doors'), response: l('关闭 (CLOSED)', 'Closed (CLOSED)'), isChecked: false },
          { id: 'b2_3', task: l('燃油泵 (FUEL PUMPS)', 'Fuel Pumps (FUEL PUMPS)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b2_4', task: l('座椅腰带', 'Seat Belts'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b2_5', task: l('防撞灯 (ANTI COLLISION)', 'Anti-Collision Light (ANTI COLLISION)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b2_6', task: l('襟翼', 'Flaps'), response: l('调定 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'b2_7', task: l('稳定器配平', 'Stabilizer Trim'), response: l('调定 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'b2_8', task: l('推力杠 (THROTTLE)', 'Throttle (THROTTLE)'), response: l('怠速 (IDLE)', 'Idle (IDLE)'), isChecked: false },
          { id: 'b2_9', task: l('停机刹车', 'Park Brake'), response: l('松开 (RELEASED)', 'Released (RELEASED)'), isChecked: false },
          { id: 'b2_10', task: l('推出许可', 'Pushback Clearance'), response: l('获得 (CLEARED)', 'Cleared (CLEARED)'), isChecked: false },
        ],
      },
      {
        phase: 'beforeTaxi',
        items: [
          { id: 'b_taxi_1', task: l('发动机启动', 'Engine Start'), response: l('完成 (COMPLETED)', 'Completed (COMPLETED)'), isChecked: false },
          { id: 'b_taxi_2', task: l('发电机 (GENERATORS)', 'Generators (GENERATORS)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b_taxi_3', task: l('探头加热 (PROBE HEAT)', 'Probe Heat (PROBE HEAT)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b_taxi_4', task: l('引气 (BLEED AIR)', 'Bleed Air (BLEED AIR)'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b_taxi_5', task: l('隔离阀 (ISOLATION VALVE)', 'Isolation Valve (ISOLATION VALVE)'), response: l('自动 (AUTO)', 'Auto (AUTO)'), isChecked: false },
          { id: 'b_taxi_6', task: l('APU', 'APU'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'b_taxi_7', task: l('防冰系统', 'Anti-Ice System'), response: l('按需 (AS REQ)', 'As Required (AS REQ)'), isChecked: false },
          { id: 'b_taxi_8', task: l('滑行灯', 'Taxi Lights'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b_taxi_9', task: l('跑道脱离灯', 'Runway Turn Off Lights'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b_taxi_10', task: l('刹车测试', 'Brake Test'), response: l('完成 (TESTED)', 'Tested (TESTED)'), isChecked: false },
        ],
      },
      {
        phase: 'beforeTakeoff',
        items: [
          { id: 'b3_1', task: l('飞行控制', 'Flight Controls'), response: l('检查 (CHECKED)', 'Checked (CHECKED)'), isChecked: false },
          { id: 'b3_2', task: l('襟翼', 'Flaps'), response: l('起飞位 (T.O)', 'Takeoff Position (T.O)'), isChecked: false },
          { id: 'b3_3', task: l('配平', 'Trim'), response: l('绿带内 (GREEN)', 'In Green Band (GREEN)'), isChecked: false },
          { id: 'b3_4', task: l('起飞简令', 'Takeoff Briefing'), response: l('完成 (BRIEFED)', 'Briefed (BRIEFED)'), isChecked: false },
          { id: 'b3_5', task: l('起飞数据', 'Takeoff Data'), response: l('确认 (VERIFIED)', 'Verified (VERIFIED)'), isChecked: false },
          { id: 'b3_6', task: l('TCAS', 'TCAS'), response: l('TA/RA', 'TA/RA'), isChecked: false },
          { id: 'b3_7', task: l('应答机', 'Transponder'), response: l('TA/RA', 'TA/RA'), isChecked: false },
          { id: 'b3_8', task: l('自动驾驶', 'Autopilot'), response: l('预位 (ARMED)', 'Armed (ARMED)'), isChecked: false },
          { id: 'b3_9', task: l('自动油门', 'Autothrottle'), response: l('预位 (ARMED)', 'Armed (ARMED)'), isChecked: false },
          { id: 'b3_10', task: l('起飞许可', 'Takeoff Clearance'), response: l('获得 (CLEARED)', 'Cleared (CLEARED)'), isChecked: false },
        ],
      },
      {
        phase: 'cruise',
        items: [
          { id: 'b_cruise_1', task: l('巡航高度', 'Cruise Altitude'), response: l('到达 (REACHED)', 'Reached (REACHED)'), isChecked: false },
          { id: 'b_cruise_2', task: l('自动驾驶', 'Autopilot'), response: l('接通 (ENGAGED)', 'Engaged (ENGAGED)'), isChecked: false },
          { id: 'b_cruise_3', task: l('自动油门', 'Autothrottle'), response: l('接通 (ENGAGED)', 'Engaged (ENGAGED)'), isChecked: false },
          { id: 'b_cruise_4', task: l('燃油平衡', 'Fuel Balance'), response: l('检查 (CHECKED)', 'Checked (CHECKED)'), isChecked: false },
          { id: 'b_cruise_5', task: l('客舱高度', 'Cabin Altitude'), response: l('正常 (NORMAL)', 'Normal (NORMAL)'), isChecked: false },
          { id: 'b_cruise_6', task: l('安全带灯', 'Seat Belt Sign'), response: l('按需 (AS REQ)', 'As Required (AS REQ)'), isChecked: false },
          { id: 'b_cruise_7', task: l('天气雷达', 'Weather Radar'), response: l('监控 (MONITORED)', 'Monitored (MONITORED)'), isChecked: false },
        ],
      },
      {
        phase: 'beforeDescent',
        items: [
          { id: 'b_desc_1', task: l('进近简令', 'Approach Briefing'), response: l('完成 (BRIEFED)', 'Briefed (BRIEFED)'), isChecked: false },
          { id: 'b_desc_2', task: l('ATIS', 'ATIS'), response: l('获得 (OBTAINED)', 'Obtained (OBTAINED)'), isChecked: false },
          { id: 'b_desc_3', task: l('高度表', 'Altimeter'), response: l('调定 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'b_desc_4', task: l('着陆标高', 'Landing Elevation'), response: l('输入 (ENTERED)', 'Entered (ENTERED)'), isChecked: false },
          { id: 'b_desc_5', task: l('最低标准', 'Minimums'), response: l('调定 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'b_desc_6', task: l('自动刹车', 'Auto Brake'), response: l('调定 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'b_desc_7', task: l('安全带灯', 'Seat Belt Sign'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b_desc_8', task: l('客舱通知', 'Cabin Notification'), response: l('完成 (NOTIFIED)', 'Notified (NOTIFIED)'), isChecked: false },
        ],
      },
      {
        phase: 'beforeApproach',
        items: [
          { id: 'b_app_1', task: l('着陆许可', 'Landing Clearance'), response: l('获得 (CLEARED)', 'Cleared (CLEARED)'), isChecked: false },
          { id: 'b_app_2', task: l('起落架', 'Landing Gear'), response: l('放下 (DOWN)', 'Down (DOWN)'), isChecked: false },
          { id: 'b_app_3', task: l('襟翼', 'Flaps'), response: l('着陆位 (LANDING)', 'Landing Position (LANDING)'), isChecked: false },
          { id: 'b_app_4', task: l('着陆灯', 'Landing Lights'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b_app_5', task: l('减速板', 'Speedbrake'), response: l('预位 (ARMED)', 'Armed (ARMED)'), isChecked: false },
          { id: 'b_app_6', task: l('自动刹车', 'Auto Brake'), response: l('调定 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'b_app_7', task: l('着陆检查单', 'Landing Checklist'), response: l('完成 (COMPLETED)', 'Completed (COMPLETED)'), isChecked: false },
        ],
      },
      {
        phase: 'afterLanding',
        items: [
          { id: 'b_land_1', task: l('襟翼', 'Flaps'), response: l('收起 (UP)', 'Up (UP)'), isChecked: false },
          { id: 'b_land_2', task: l('减速板', 'Speedbrake'), response: l('收起 (DOWN)', 'Down (DOWN)'), isChecked: false },
          { id: 'b_land_3', task: l('天气雷达', 'Weather Radar'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'b_land_4', task: l('APU', 'APU'), response: l('启动 (START)', 'Start (START)'), isChecked: false },
          { id: 'b_land_5', task: l('跑道脱离灯', 'Runway Turn Off Lights'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b_land_6', task: l('滑行灯', 'Taxi Lights'), response: l('开启 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b_land_7', task: l('着陆灯', 'Landing Lights'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'b_land_8', task: l('应答机', 'Transponder'), response: l('STBY', 'STBY'), isChecked: false },
        ],
      },
      {
        phase: 'parking',
        items: [
          { id: 'b_park_1', task: l('停机刹车', 'Park Brake'), response: l('开启 (SET)', 'Set (SET)'), isChecked: false },
          { id: 'b_park_2', task: l('轮挡', 'Wheel Chocks'), response: l('放置 (CHOCKED)', 'Chocked (CHOCKED)'), isChecked: false },
          { id: 'b_park_3', task: l('燃油手柄 (FUEL LEVERS)', 'Fuel Levers (FUEL LEVERS)'), response: l('切断 (CUT OFF)', 'Cut Off (CUT OFF)'), isChecked: false },
          { id: 'b_park_4', task: l('安全带灯', 'Seat Belt Sign'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'b_park_5', task: l('燃油泵', 'Fuel Pumps'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'b_park_6', task: l('防撞灯', 'Anti-Collision Light'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'b_park_7', task: l('外部电源', 'External Power'), response: l('接通 (ON)', 'On (ON)'), isChecked: false },
          { id: 'b_park_8', task: l('APU', 'APU'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'b_park_9', task: l('探头加热', 'Probe Heat'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'b_park_10', task: l('IRS', 'IRS'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'b_park_11', task: l('液压泵', 'Hydraulic Pumps'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
          { id: 'b_park_12', task: l('电池', 'Battery'), response: l('关闭 (OFF)', 'Off (OFF)'), isChecked: false },
        ],
      },
    ],
  };
}
