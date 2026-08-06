import { describe, expect, it } from 'vitest';
import { parsePlannedRoute } from './planned-route-parser';

/**
 * 计划航路解析
 *
 * 中间件已经归一化过一轮，但**缺失的数值字段会因为 omitempty 直接不出现**，
 * 而不是给 0。所以这里重点验证「字段不在」与「字段是 0」被区别对待 ——
 * 混淆两者会让「没规划备降」显示成「备降在 (0,0)」。
 */

const validPlan = () => ({
  flight_number: 'SWA1234',
  aircraft_icao: 'B738',
  origin: { icao: 'KLAS', name: 'Harry Reid Intl', lat: 36.083361, lon: -115.152333 },
  destination: { icao: 'KLGB', name: 'Long Beach', lat: 33.817931, lon: -118.151892 },
  alternate: { icao: 'KSNA', lat: 33.67, lon: -117.86 },
  route: 'RADYR2 SLVRR DCT FEYLA ROOBY3',
  route_distance_nm: 256,
  cruise_altitude_ft: 34000,
  generated_at: 1786000000,
  points: [
    {
      ident: 'RUDYY',
      lat: 36.068786,
      lon: -115.258975,
      altitude_ft: 6000,
      via_airway: 'RADYR2',
      is_sid_star: true,
      stage: 'CLB',
    },
    { ident: 'SLVRR', lat: 35.9, lon: -116.1, altitude_ft: 34000, is_sid_star: false, stage: 'CRZ' },
    { ident: 'KLGB', lat: 33.817931, lon: -118.151892, is_sid_star: true, stage: 'DSC' },
  ],
  fuel: { units: 'lbs', plan_ramp: 16863, enroute_burn: 6686, reserve: 5082 },
});

describe('parsePlannedRoute', () => {
  it('解析核心字段', () => {
    const plan = parsePlannedRoute(validPlan())!;
    expect(plan.origin.code).toBe('KLAS');
    expect(plan.destination.code).toBe('KLGB');
    expect(plan.alternate?.code).toBe('KSNA');
    expect(plan.flightNumber).toBe('SWA1234');
    expect(plan.aircraftIcao).toBe('B738');
    expect(plan.cruiseAltitudeFt).toBe(34000);
    expect(plan.distanceNm).toBe(256);
    expect(plan.points).toHaveLength(3);
  });

  it('ICAO 统一大写', () => {
    const raw = validPlan();
    raw.origin.icao = 'klas';
    expect(parsePlannedRoute(raw)!.origin.code).toBe('KLAS');
  });

  it('生成时间由 Unix 秒还原', () => {
    const plan = parsePlannedRoute(validPlan())!;
    expect(plan.generatedAt?.getTime()).toBe(1786000000 * 1000);
  });

  it('航路点保留高度/航路/阶段与 SID-STAR 标记', () => {
    const points = parsePlannedRoute(validPlan())!.points;
    expect(points[0]).toMatchObject({
      ident: 'RUDYY',
      altitudeFt: 6000,
      viaAirway: 'RADYR2',
      isSidStar: true,
      stage: 'CLB',
    });
    // 巡航段不该被当成程序段
    expect(points[1].isSidStar).toBe(false);
  });

  it('is_sid_star 只认真布尔', () => {
    const raw = validPlan();
    // 后端已归一成布尔；万一退化回字符串，不能把 "0" 当成真
    (raw.points[1] as unknown as { is_sid_star: unknown }).is_sid_star = '0';
    expect(parsePlannedRoute(raw)!.points[1].isSidStar).toBe(false);
    (raw.points[1] as unknown as { is_sid_star: unknown }).is_sid_star = '1';
    expect(parsePlannedRoute(raw)!.points[1].isSidStar).toBe(false);
  });
});

describe('缺失与脏数据', () => {
  it('没有备降场时是 undefined，而不是一个空壳机场', () => {
    const raw = validPlan();
    delete (raw as { alternate?: unknown }).alternate;
    expect(parsePlannedRoute(raw)!.alternate).toBeUndefined();
  });

  it('备降场缺 ICAO 同样丢弃 —— 否则简报上会多出一个空白机场', () => {
    const raw = validPlan();
    raw.alternate = { icao: '', lat: 33.67, lon: -117.86 };
    expect(parsePlannedRoute(raw)!.alternate).toBeUndefined();
  });

  it('起降场任缺其一即整份作废', () => {
    const noOrigin = validPlan();
    delete (noOrigin as { origin?: unknown }).origin;
    expect(parsePlannedRoute(noOrigin)).toBeNull();

    const badDest = validPlan();
    badDest.destination = { icao: 'KLGB', name: '', lat: 0, lon: 0 };
    expect(parsePlannedRoute(badDest)).toBeNull();
  });

  it('剔除坐标非法的航路点', () => {
    const raw = validPlan();
    raw.points = [
      ...raw.points,
      { ident: 'BAD', lat: 0, lon: 0, is_sid_star: false, stage: '' },
      { ident: 'OOB', lat: 999, lon: 999, is_sid_star: false, stage: '' },
      { ident: '', lat: 40, lon: 116, is_sid_star: false, stage: '' },
    ] as typeof raw.points;
    expect(parsePlannedRoute(raw)!.points).toHaveLength(3);
  });

  it('不足两点画不出线，整份作废', () => {
    const raw = validPlan();
    raw.points = [raw.points[0]];
    expect(parsePlannedRoute(raw)).toBeNull();
  });

  it('燃油字段缺失时是 undefined 而非 0', () => {
    // 0 是合法油量读数，与「没这项数据」语义不同
    const raw = validPlan();
    raw.fuel = { units: 'kg' } as typeof raw.fuel;
    const fuel = parsePlannedRoute(raw)!.fuel;
    expect(fuel.units).toBe('kg');
    expect(fuel.planRamp).toBeUndefined();
    expect(fuel.reserve).toBeUndefined();
  });

  it('脏输入返回 null 而不是抛异常', () => {
    for (const input of [null, undefined, 'x', 42, {}, { origin: 1, destination: 2 }]) {
      expect(() => parsePlannedRoute(input)).not.toThrow();
      expect(parsePlannedRoute(input)).toBeNull();
    }
  });
});
