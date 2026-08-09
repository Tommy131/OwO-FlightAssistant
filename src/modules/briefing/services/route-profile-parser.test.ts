import { describe, expect, it } from 'vitest';
import {
  interpolateAtAltitude,
  parseRouteProfile,
  parseRouteProfileSample,
  tailwindComponentKt,
} from './route-profile-parser';
import type { RouteProfileSample } from '../models/route-profile-models';

/**
 * 航路气象剖面
 *
 * 两条最要紧的：
 * 1. 缺数据就是缺数据，绝不补零 —— 图上的「0 kt」看不出是没有数据。
 * 2. 风向按最短弧插值 —— 350° 与 010° 之间是 20°，直接平均会得到 180°，正好指反。
 */

const level = (over: Record<string, unknown> = {}) => ({
  pressure_hpa: 300,
  altitude_ft: 30000,
  temperature_c: -45,
  wind_speed_kt: 100,
  wind_direction_deg: 270,
  ...over,
});

const sample = (over: Record<string, unknown> = {}) => ({
  index: 0,
  latitude: 40.1,
  longitude: 116.6,
  time_utc: '2026-08-09T06:00',
  levels: [level()],
  ...over,
});

describe('parseRouteProfileSample', () => {
  it('解析核心字段', () => {
    const got = parseRouteProfileSample(sample({ index: 7 }))!;
    expect(got.index).toBe(7);
    expect(got.latitude).toBeCloseTo(40.1);
    expect(got.timeUtc).toBe('2026-08-09T06:00');
    expect(got.levels).toHaveLength(1);
    expect(got.levels[0].windSpeedKt).toBe(100);
  });

  it('层按高度自下而上排序', () => {
    const got = parseRouteProfileSample(
      sample({
        levels: [
          level({ pressure_hpa: 200, altitude_ft: 39000 }),
          level({ pressure_hpa: 850, altitude_ft: 5000 }),
          level({ pressure_hpa: 300, altitude_ft: 30000 }),
        ],
      }),
    )!;
    expect(got.levels.map((l) => l.altitudeFt)).toEqual([5000, 30000, 39000]);
  });

  it('缺任一项的层整层丢弃 —— 不补零', () => {
    for (const missing of [
      'pressure_hpa',
      'altitude_ft',
      'temperature_c',
      'wind_speed_kt',
      'wind_direction_deg',
    ]) {
      const broken = level();
      delete (broken as Record<string, unknown>)[missing];
      const got = parseRouteProfileSample(sample({ levels: [broken, level({ altitude_ft: 39000 })] }));
      expect(got!.levels).toHaveLength(1);
      expect(got!.levels[0].altitudeFt).toBe(39000);
    }
  });

  it('高度非正的层丢弃 —— 那是上游没算出来', () => {
    const got = parseRouteProfileSample(
      sample({ levels: [level({ altitude_ft: 0 }), level({ altitude_ft: -100 }), level()] }),
    )!;
    expect(got.levels).toHaveLength(1);
    expect(got.levels[0].altitudeFt).toBe(30000);
  });

  it('风向归一到 [0,360)', () => {
    const got = parseRouteProfileSample(sample({ levels: [level({ wind_direction_deg: -30 })] }))!;
    expect(got.levels[0].windDirectionDeg).toBe(330);
  });

  it('坐标非法或一层都不剩时返回 null', () => {
    expect(parseRouteProfileSample(sample({ latitude: 999 }))).toBeNull();
    expect(parseRouteProfileSample(sample({ levels: [] }))).toBeNull();
  });

  it('脏输入返回 null 而不是抛异常', () => {
    for (const input of [null, undefined, 42, 'x', {}, { levels: 'nope' }]) {
      expect(() => parseRouteProfileSample(input)).not.toThrow();
      expect(parseRouteProfileSample(input)).toBeNull();
    }
  });
});

describe('parseRouteProfile', () => {
  it('按 index 排序并剔除无效采样点', () => {
    const profile = parseRouteProfile({
      cached: true,
      samples: [sample({ index: 5 }), null, sample({ index: 1 }), sample({ levels: [] })],
    })!;
    expect(profile.samples.map((s) => s.index)).toEqual([1, 5]);
    expect(profile.cached).toBe(true);
  });

  it('一个有效采样点都没有时返回 null', () => {
    expect(parseRouteProfile({ samples: [] })).toBeNull();
    expect(parseRouteProfile({ samples: [{ latitude: 999, longitude: 0 }] })).toBeNull();
    expect(parseRouteProfile(null)).toBeNull();
  });

  it('cached 只认真布尔', () => {
    expect(parseRouteProfile({ samples: [sample()], cached: 'true' })!.cached).toBe(false);
  });
});

describe('interpolateAtAltitude', () => {
  const twoLevels: RouteProfileSample = {
    index: 0,
    latitude: 0,
    longitude: 0,
    levels: [
      { pressureHPa: 400, altitudeFt: 24000, temperatureC: -30, windSpeedKt: 60, windDirectionDeg: 350 },
      { pressureHPa: 250, altitudeFt: 34000, temperatureC: -50, windSpeedKt: 100, windDirectionDeg: 10 },
    ],
  };

  it('两层之间线性插值', () => {
    const got = interpolateAtAltitude(twoLevels, 29000)!;
    expect(got.altitudeFt).toBe(29000);
    expect(got.temperatureC).toBeCloseTo(-40);
    expect(got.windSpeedKt).toBeCloseTo(80);
  });

  it('风向走最短弧 —— 350° 到 010° 的中点是 0°，不是 180°', () => {
    // 直接平均会得到 180°，把顺风读成顶风
    expect(interpolateAtAltitude(twoLevels, 29000)!.windDirectionDeg).toBeCloseTo(0);
  });

  it('反向跨零同样走最短弧', () => {
    const reversed: RouteProfileSample = {
      ...twoLevels,
      levels: [
        { ...twoLevels.levels[0], windDirectionDeg: 10 },
        { ...twoLevels.levels[1], windDirectionDeg: 350 },
      ],
    };
    expect(interpolateAtAltitude(reversed, 29000)!.windDirectionDeg).toBeCloseTo(0);
  });

  it('超出上下界取最近的层，不外推', () => {
    // 外推出来的高空风没有依据，宁可给边界值
    expect(interpolateAtAltitude(twoLevels, 5000)!.altitudeFt).toBe(24000);
    expect(interpolateAtAltitude(twoLevels, 45000)!.altitudeFt).toBe(34000);
  });

  it('只有一层时直接返回它', () => {
    const one: RouteProfileSample = { ...twoLevels, levels: [twoLevels.levels[0]] };
    expect(interpolateAtAltitude(one, 99000)).toEqual(twoLevels.levels[0]);
  });

  it('没有层时返回 null', () => {
    expect(interpolateAtAltitude({ ...twoLevels, levels: [] }, 30000)).toBeNull();
  });
});

describe('tailwindComponentKt', () => {
  it('风从正后方来是满额顺风', () => {
    // 航向 090，风从 270 来（即吹向 090）＝ 正顺风
    expect(tailwindComponentKt(270, 100, 90)).toBeCloseTo(100);
  });

  it('风从正前方来是满额顶风', () => {
    // 符号搞反会让整段航程的油耗朝相反方向偏
    expect(tailwindComponentKt(90, 100, 90)).toBeCloseTo(-100);
  });

  it('正侧风的顺风分量为零', () => {
    expect(tailwindComponentKt(180, 100, 90)).toBeCloseTo(0);
    expect(tailwindComponentKt(0, 100, 90)).toBeCloseTo(0);
  });

  it('45 度夹角取分量', () => {
    expect(tailwindComponentKt(225, 100, 90)).toBeCloseTo(70.71, 1);
  });
});
