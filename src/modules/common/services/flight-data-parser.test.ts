import { describe, expect, it } from 'vitest';
import {
  airportFromNearestAirport,
  airportFromSuggestion,
  buildFlapsLabel,
  buildFuelPlanTotal,
  buildSpeedBrakeLabel,
  flightDataFromDataset,
  inferGearDownStateFromRatio,
  normalizeGearRatio,
  parseAIAircraft,
  parseFlightAlerts,
} from './flight-data-parser';

/**
 * 遥测数据解析
 *
 * 这层最容易出的错是**字段拼错**与**单位没换算**：两者都不报错，只会让
 * 仪表读数悄悄不对。所以下面既钉字段名，也钉换算结果。
 */

describe('flightDataFromDataset', () => {
  it('按中间件的键名取值 —— 带单位后缀，别写成裸名', () => {
    // altitude_ft 不是 altitude、ground_speed_kt 不是 ground_speed。
    // 写错了不报错，只是那个仪表永远空着
    const data = flightDataFromDataset({
      latitude: 40.078,
      longitude: 116.594,
      altitude_ft: 35000,
      ground_speed_kt: 450,
      heading_deg: 181,
      vertical_speed_fpm: -1200,
    });
    expect(data.latitude).toBe(40.078);
    expect(data.longitude).toBe(116.594);
    expect(data.altitude).toBe(35000);
    expect(data.groundSpeed).toBe(450);
    expect(data.heading).toBe(181);
    expect(data.verticalSpeed).toBe(-1200);
  });

  it('同一字段的多个历史键名都认', () => {
    // 不同模拟器/版本给的键名不一样，解析器用 ?? 串起来兜底
    expect(flightDataFromDataset({ vs_fpm: -800 }).verticalSpeed).toBe(-800);
    expect(flightDataFromDataset({ ias_kt: 250 }).airspeed).toBe(250);
    expect(flightDataFromDataset({ airspeed_kt: 250 }).airspeed).toBe(250);
    expect(flightDataFromDataset({ tas_kt: 300 }).trueAirspeed).toBe(300);
    // 首选键存在时不该被后备键顶掉（两个键都在时，顺序决定取谁）
    expect(flightDataFromDataset({ vertical_speed_fpm: -1, vs_fpm: -999 }).verticalSpeed).toBe(-1);
    expect(flightDataFromDataset({ ias_kt: 250, airspeed_kt: 999 }).airspeed).toBe(250);
    expect(flightDataFromDataset({ tas_kt: 300, true_airspeed_kt: 999 }).trueAirspeed).toBe(300);
    expect(flightDataFromDataset({ g_force_g: 1.2, g_force: 9.9 }).gForce).toBe(1.2);
  });

  it('空数据集不抛异常，字段一律 undefined 而非 0', () => {
    // 0 是合法读数（地面高度、静止地速），拿它当「没数据」会让界面显示假值
    const data = flightDataFromDataset({});
    expect(data.latitude).toBeUndefined();
    expect(data.altitude).toBeUndefined();
    expect(data.groundSpeed).toBeUndefined();
  });

  it('脏值不会变成 NaN 流进界面', () => {
    const data = flightDataFromDataset({
      latitude: 'not-a-number',
      altitude_ft: null,
      ground_speed_kt: {},
    });
    expect(data.latitude).toBeUndefined();
    expect(data.altitude).toBeUndefined();
    expect(data.groundSpeed).toBeUndefined();
  });

  it('feeds landing logic from the additive resolved height instead of the legacy radio field', () => {
    const parsed = flightDataFromDataset({
      radio_altitude_ft: 99,
      radio_altitude_source: 'radio',
      resolved_landing_height_ft: 18.5,
      resolved_landing_height_source: 'agl_fallback',
    });

    expect(parsed.radioAltitude).toBe(18.5);
    expect(parsed.radioAltitudeSource).toBe('agl_fallback');
  });

  it('still parses pre-1.3 resolved height payloads during a rolling upgrade', () => {
    const parsed = flightDataFromDataset({
      radio_altitude_ft: 18.5,
      radio_altitude_source: 'agl_fallback',
    });

    expect(parsed.radioAltitude).toBe(18.5);
    expect(parsed.radioAltitudeSource).toBe('agl_fallback');
  });

  it('accepts only known radio-height sources', () => {
    expect(
      flightDataFromDataset({ radio_altitude_source: 'radio' }).radioAltitudeSource,
    ).toBe('radio');
    expect(
      flightDataFromDataset({ radio_altitude_source: 'gps' }).radioAltitudeSource,
    ).toBeUndefined();
  });

  it('起落架状态由三个比例推断', () => {
    const down = flightDataFromDataset({
      nose_gear_down: 1,
      left_gear_down: 1,
      right_gear_down: 1,
    });
    expect(down.gearDown).toBe(true);

    const up = flightDataFromDataset({
      nose_gear_down: 0,
      left_gear_down: 0,
      right_gear_down: 0,
    });
    expect(up.gearDown).toBe(false);
  });
});

describe('normalizeGearRatio', () => {
  it('0~1 视为比例，原样返回', () => {
    expect(normalizeGearRatio(0)).toBe(0);
    expect(normalizeGearRatio(0.5)).toBe(0.5);
    expect(normalizeGearRatio(1)).toBe(1);
  });

  it('1~100 视为百分比，除以 100', () => {
    // 不同模拟器给的量纲不一样，这里统一收敛
    expect(normalizeGearRatio(50)).toBe(0.5);
    expect(normalizeGearRatio(100)).toBe(1);
  });

  it('超范围与非有限值一律丢弃', () => {
    expect(normalizeGearRatio(101)).toBeUndefined();
    expect(normalizeGearRatio(-1)).toBeUndefined();
    expect(normalizeGearRatio(Number.NaN)).toBeUndefined();
    expect(normalizeGearRatio(undefined)).toBeUndefined();
  });
});

describe('inferGearDownStateFromRatio', () => {
  it('平均值 ≥ 0.5 判为放下', () => {
    expect(inferGearDownStateFromRatio(0.5, 0.5, 0.5)).toBe(true);
    expect(inferGearDownStateFromRatio(0.49, 0.49, 0.49)).toBe(false);
  });

  it('只按有效值求平均，缺的那个不算 0', () => {
    // 把缺失当 0 会把「两个已放下、一个没数据」误判成收起
    expect(inferGearDownStateFromRatio(1, 1, undefined)).toBe(true);
  });

  it('三个都没有数据时返回 undefined 而不是 false', () => {
    // false 表示「确认收起」，undefined 表示「不知道」——两者不能混
    expect(inferGearDownStateFromRatio(undefined, undefined, undefined)).toBeUndefined();
  });

  it('百分比与比例混用也能算对', () => {
    expect(inferGearDownStateFromRatio(100, 1, 1)).toBe(true);
  });
});

describe('buildSpeedBrakeLabel / buildFlapsLabel', () => {
  it('减速板按百分比显示', () => {
    expect(buildSpeedBrakeLabel({ speed_brake_ratio: 0.5 })).toBe('50%');
    expect(buildSpeedBrakeLabel({ speed_brake_ratio: 0 })).toBe('0%');
    expect(buildSpeedBrakeLabel({})).toBeUndefined();
  });

  it('襟翼优先用角度，没有角度才退回比例', () => {
    expect(buildFlapsLabel({ flaps_angle_deg: 15 })).toBe('15°');
    expect(buildFlapsLabel({ flaps_deploy_ratio: 0.25 })).toBe('25%');
    // 两个都有时角度优先（更精确）
    expect(buildFlapsLabel({ flaps_angle_deg: 30, flaps_deploy_ratio: 0.9 })).toBe('30°');
    expect(buildFlapsLabel({})).toBeUndefined();
  });
});

describe('buildFuelPlanTotal', () => {
  it('航段 ×2.5 + 备份 1500 + 滑行 200 + 额外 5%', () => {
    // 1000nm 无备降：2500 + 0 + 1500 + 200 + 125 = 4325
    expect(buildFuelPlanTotal(1000, false)).toBe(4325);
  });

  it('带备降固定加 200nm 的量', () => {
    // 备降 200nm × 2.5 = 500
    expect(buildFuelPlanTotal(1000, true) - buildFuelPlanTotal(1000, false)).toBe(500);
  });

  it('零距离也要留备份与滑行油', () => {
    // 飞不动也得有油：1500 + 200
    expect(buildFuelPlanTotal(0, false)).toBe(1700);
  });
});

describe('parseFlightAlerts', () => {
  it('结构不对时返回空数组而不是抛异常', () => {
    expect(parseFlightAlerts(null)).toEqual([]);
    expect(parseFlightAlerts('x')).toEqual([]);
    expect(parseFlightAlerts({})).toEqual([]);
  });

  it('数组里的脏项被跳过', () => {
    expect(() => parseFlightAlerts([null, 1, 'x', {}])).not.toThrow();
  });
});

describe('parseAIAircraft', () => {
  it('结构不对时返回空数组', () => {
    expect(parseAIAircraft(null)).toEqual([]);
    expect(parseAIAircraft({})).toEqual([]);
  });

  it('脏项不会让整批解析失败', () => {
    expect(() => parseAIAircraft([null, {}, { id: 'x' }])).not.toThrow();
  });
});

describe('机场解析', () => {
  it('联想结果缺字段也不抛', () => {
    expect(() => airportFromSuggestion({})).not.toThrow();
  });

  it('最近机场缺坐标时返回 null，避免画到 (0,0)', () => {
    expect(airportFromNearestAirport({})).toBeNull();
  });
});
