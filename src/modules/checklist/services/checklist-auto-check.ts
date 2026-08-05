import type { FlightData } from '../../common/models/common-models';
import type { AircraftChecklist } from '../models/flight-checklist';

/**
 * 检查单条目自动勾选
 *
 * 模拟器已经在遥测里如实回报了停留刹车、灯光、发动机、襟翼、起落架等开关的
 * 真实状态，没有理由再让飞行员手动去勾一遍。这里把条目 id 映射成一个针对
 * `FlightData` 的判定函数，由后端数据直接驱动条目的勾选状态。
 *
 * ── 三条硬性约定 ──
 *
 * 1. **只认有效数据**：字段缺失（undefined）时判定函数返回 undefined，
 *    表示「无法判断」，绝不按缺省值当成 false 去取消勾选 ——
 *    模拟器没连、或某型号不上报该字段时，条目必须保持用户自己的选择。
 *
 * 2. **手动优先**：用户一旦手动点过某条目，该条目就从自动同步中摘出去，
 *    直到重置为止。自动化不该跟人抢方向盘。
 *
 * 3. **判定要匹配条目的 response**：同样是「停留刹车」，推出前那条要求
 *    松开（OFF）、停机那条要求设置（SET），判定方向正好相反。
 *    所以规则按条目 id 逐条写，不做按名称的模糊匹配。
 */

/** 判定结果：true=符合、false=不符合、undefined=数据缺失无法判断 */
export type AutoCheckVerdict = boolean | undefined;

type AutoCheckRule = (data: FlightData) => AutoCheckVerdict;

/** 期望某个布尔字段为指定值；字段缺失返回 undefined */
function expect(value: boolean | undefined, wanted: boolean): AutoCheckVerdict {
  return value === undefined ? undefined : value === wanted;
}

/**
 * 全部发动机都在运转 / 都已关车
 *
 * 双发机型只上报 1、2 号；`numEngines` 缺失时按已上报的字段判断。
 */
function allEngines(data: FlightData, running: boolean): AutoCheckVerdict {
  const states = [data.engine1Running, data.engine2Running].filter(
    (value): value is boolean => value !== undefined,
  );
  if (states.length === 0) return undefined;
  return states.every((value) => value === running);
}

/**
 * 条目 id → 判定规则
 *
 * 只收录遥测能**明确**对应的条目。像「起飞简令 已完成」「ATIS 已抄收」
 * 这类需要人确认的条目不在此列，仍然由飞行员手动勾选 ——
 * 自动勾一个飞行员根本没做的动作，比不自动更危险。
 */
const AUTO_CHECK_RULES: Record<string, AutoCheckRule> = {
  // ── A320 ──
  a1_9: (d) => expect(d.apuRunning, true), // APU 启动 (START)
  a1_12: (d) => expect(d.navLights, true), // 导航灯 (ON)
  a2_4: (d) => expect(d.beacon, true), // 信标灯 (ON)
  a2_6: (d) => expect(d.flapsDeployed, true), // 襟翼 (SET)
  a2_11: (d) => expect(d.parkingBrake, false), // 停机刹车 (OFF)
  a_taxi_1: (d) => allEngines(d, true), // 发动机 (STARTED)
  a_taxi_4: (d) => expect(d.apuRunning, false), // APU (OFF)
  a_taxi_8: (d) => expect(d.taxiLights, true), // 滑行灯 (ON)
  a_taxi_9: (d) => expect(d.runwayTurnoffLights, true), // 跑道脱离灯 (ON)
  a3_2: (d) => expect(d.flapsDeployed, true), // 襟翼/缝翼 (T.O)
  a_cruise_2: (d) => expect(d.autopilotEngaged, true), // 自动驾驶 (ENGAGED)
  a_cruise_3: (d) => expect(d.autothrottleEngaged, true), // 自动油门 (ENGAGED)
  a_app_2: (d) => expect(d.gearDown, true), // 起落架 (DOWN)
  a_app_3: (d) => expect(d.flapsDeployed, true), // 襟翼 (FULL)
  a_app_4: (d) => expect(d.landingLights, true), // 着陆灯 (ON)
  a_land_1: (d) => expect(d.flapsDeployed, false), // 襟翼 (UP)
  a_land_2: (d) => expect(d.spoilersDeployed, false), // 减速板 (RETRACTED)
  a_land_5: (d) => expect(d.apuRunning, true), // APU (START)
  a_land_6: (d) => expect(d.runwayTurnoffLights, true), // 跑道脱离灯 (ON)
  a_land_7: (d) => expect(d.taxiLights, true), // 滑行灯 (ON)
  a_land_8: (d) => expect(d.landingLights, false), // 着陆灯 (OFF)
  a_park_1: (d) => expect(d.parkingBrake, true), // 停机刹车 (SET)
  a_park_3: (d) => allEngines(d, false), // 发动机 (OFF)
  a_park_6: (d) => expect(d.beacon, false), // 信标灯 (OFF)
  a_park_8: (d) => expect(d.apuRunning, false), // APU (OFF)

  // ── B737 ──
  b1_9: (d) => expect(d.apuRunning, true), // APU 启动 (START)
  b2_5: (d) => expect(d.beacon, true), // 防撞灯 (ON)
  b2_6: (d) => expect(d.flapsDeployed, true), // 襟翼 (SET)
  b2_9: (d) => expect(d.parkingBrake, false), // 停机刹车 (RELEASED)
  b_taxi_1: (d) => allEngines(d, true), // 发动机启动 (COMPLETED)
  b_taxi_6: (d) => expect(d.apuRunning, false), // APU (OFF)
  b_taxi_8: (d) => expect(d.taxiLights, true), // 滑行灯 (ON)
  b_taxi_9: (d) => expect(d.runwayTurnoffLights, true), // 跑道脱离灯 (ON)
  b3_2: (d) => expect(d.flapsDeployed, true), // 襟翼 (T.O)
  b_cruise_2: (d) => expect(d.autopilotEngaged, true), // 自动驾驶 (ENGAGED)
  b_cruise_3: (d) => expect(d.autothrottleEngaged, true), // 自动油门 (ENGAGED)
  b_app_2: (d) => expect(d.gearDown, true), // 起落架 (DOWN)
  b_app_3: (d) => expect(d.flapsDeployed, true), // 襟翼 (LANDING)
  b_app_4: (d) => expect(d.landingLights, true), // 着陆灯 (ON)
  b_land_1: (d) => expect(d.flapsDeployed, false), // 襟翼 (UP)
  b_land_2: (d) => expect(d.spoilersDeployed, true), // 减速板 (DOWN，即已放出)
  b_land_4: (d) => expect(d.apuRunning, true), // APU (START)
  b_land_5: (d) => expect(d.runwayTurnoffLights, true), // 跑道脱离灯 (ON)
  b_land_6: (d) => expect(d.taxiLights, true), // 滑行灯 (ON)
  b_land_7: (d) => expect(d.landingLights, false), // 着陆灯 (OFF)
  b_park_1: (d) => expect(d.parkingBrake, true), // 停机刹车 (SET)
  b_park_6: (d) => expect(d.beacon, false), // 防撞灯 (OFF)
  b_park_8: (d) => expect(d.apuRunning, false), // APU (OFF)

  // ── 通用机型 ──
  g1_1: (d) => expect(d.parkingBrake, true), // 停留刹车 (SET)
  g3_2: (d) => {
    // 起飞灯光：着陆灯 + 频闪灯同时打开
    const landing = d.landingLights;
    const strobes = d.strobes;
    if (landing === undefined || strobes === undefined) return undefined;
    return landing && strobes;
  },
  g6_1: (d) => expect(d.flapsDeployed, false), // 襟翼 (UP)
  g6_2: (d) => expect(d.taxiLights, true), // 滑行灯 (TAXI)
};

/** 该条目是否由遥测驱动 */
export function isAutoCheckable(itemId: string): boolean {
  return itemId in AUTO_CHECK_RULES;
}

/**
 * 对整份检查单求值
 *
 * @returns 条目 id → 应有的勾选状态；只包含判定明确的条目，
 *          数据缺失的条目不出现在结果里（调用方据此保持原状）。
 */
export function evaluateAutoChecks(
  aircraft: AircraftChecklist,
  flightData: FlightData,
): Map<string, boolean> {
  const verdicts = new Map<string, boolean>();
  for (const section of aircraft.sections) {
    for (const item of section.items) {
      const rule = AUTO_CHECK_RULES[item.id];
      if (!rule) continue;
      const verdict = rule(flightData);
      if (verdict === undefined) continue;
      verdicts.set(item.id, verdict);
    }
  }
  return verdicts;
}
