import { describe, expect, it } from 'vitest';

import type { FlightLogPoint } from '../models/flight-log-models';
import { buildTrackSegments, classifyTrackPhases, type TrackPhase } from './track-phases';

/**
 * 航迹阶段划分的行为测试
 *
 * 每条用例都拼一段有意义的航迹，断言的是「这一段该是什么颜色」。
 */

function point(overrides: Partial<FlightLogPoint>): FlightLogPoint {
  return {
    latitude: 0,
    longitude: 0,
    altitude: 0,
    airspeed: 0,
    groundSpeed: 0,
    verticalSpeed: 0,
    heading: 0,
    pitch: 0,
    roll: 0,
    gForce: 1,
    gForceSource: 'none' as FlightLogPoint['gForceSource'],
    fuelQuantity: 0,
    timestamp: new Date(0),
    anomalyAlerts: [],
    ...overrides,
  };
}

/** 地面滑行点 */
const taxi = (altitude = 0) => point({ onGround: true, altitude, groundSpeed: 15 });
/** 爬升点 */
const climbing = (altitude: number) =>
  point({ onGround: false, altitude, verticalSpeed: 2000, groundSpeed: 280 });
/** 平飞点 */
const level = (altitude: number) =>
  point({ onGround: false, altitude, verticalSpeed: 0, groundSpeed: 450 });
/** 下降点 */
const descending = (altitude: number) =>
  point({ onGround: false, altitude, verticalSpeed: -1800, groundSpeed: 300 });

/** 一条完整的短程航班：滑出 → 爬升 → 巡航 → 下降 → 滑入 */
function completeFlight(): FlightLogPoint[] {
  return [
    taxi(),
    taxi(),
    climbing(5000),
    climbing(20000),
    level(36000),
    level(36000),
    level(36000),
    descending(20000),
    descending(5000),
    taxi(),
    taxi(),
  ];
}

describe('classifyTrackPhases', () => {
  it('空输入返回空数组', () => {
    expect(classifyTrackPhases([])).toEqual([]);
  });

  it('完整航班切出全部五个阶段', () => {
    const phases = classifyTrackPhases(completeFlight());
    expect(new Set(phases)).toEqual(
      new Set<TrackPhase>(['taxiOut', 'climb', 'cruise', 'approach', 'taxiIn']),
    );
  });

  it('离地之前一律是起飞前滑行', () => {
    const phases = classifyTrackPhases(completeFlight());
    expect(phases[0]).toBe('taxiOut');
    expect(phases[1]).toBe('taxiOut');
    expect(phases[2]).not.toBe('taxiOut');
  });

  it('接地之后一律是落地后滑行', () => {
    const phases = classifyTrackPhases(completeFlight());
    expect(phases.at(-1)).toBe('taxiIn');
    expect(phases.at(-2)).toBe('taxiIn');
  });

  it('巡航高度上的平飞点判为巡航', () => {
    const phases = classifyTrackPhases(completeFlight());
    expect(phases[4]).toBe('cruise');
    expect(phases[5]).toBe('cruise');
    expect(phases[6]).toBe('cruise');
  });

  it('巡航之后的下降判为进近', () => {
    const phases = classifyTrackPhases(completeFlight());
    expect(phases[7]).toBe('approach');
    expect(phases[8]).toBe('approach');
  });

  it('阶段顺序单调，不会在巡航后又回到爬升', () => {
    const phases = classifyTrackPhases(completeFlight());
    const rank: Record<TrackPhase, number> = {
      taxiOut: 0,
      climb: 1,
      cruise: 2,
      approach: 3,
      taxiIn: 4,
    };
    for (let i = 1; i < phases.length; i++) {
      expect(rank[phases[i]]).toBeGreaterThanOrEqual(rank[phases[i - 1]]);
    }
  });

  /*
   * 这条是「精准判断」的关键：巡航途中遇到扰流掉一段高度，
   * 实时推断会立刻跳成下降，而整条航迹看下来那显然还在巡航 ——
   * 真正的下降在后面，且再也没回到巡航高度。
   */
  it('巡航中途的短暂下沉仍算巡航，不会提前切进近', () => {
    const points = [
      taxi(),
      climbing(20000),
      level(36000),
      point({ onGround: false, altitude: 35500, verticalSpeed: -600, groundSpeed: 450 }),
      level(36000),
      descending(10000),
      taxi(),
    ];
    const phases = classifyTrackPhases(points);
    expect(phases[2]).toBe('cruise');
    expect(phases[4]).toBe('cruise');
    // 掉高度那一点不该被判成进近——进近要到真正开始下降之后
    expect(phases[3]).not.toBe('approach');
    expect(phases[5]).toBe('approach');
  });

  /*
   * 起飞前在跑道上加速滑跑：地速已经很高但还没离地。
   * 只看地速会误判成已经起飞。
   */
  it('跑道加速滑跑地速很高但未离地，仍算起飞前滑行', () => {
    const points = [
      taxi(),
      point({ onGround: true, altitude: 0, groundSpeed: 140 }),
      climbing(3000),
      level(30000),
      descending(2000),
      taxi(),
    ];
    const phases = classifyTrackPhases(points);
    expect(phases[1]).toBe('taxiOut');
    expect(phases[2]).not.toBe('taxiOut');
  });

  it('全程没离过地时整条都是滑行', () => {
    const phases = classifyTrackPhases([taxi(), taxi(), taxi()]);
    expect(phases).toEqual<TrackPhase[]>(['taxiOut', 'taxiOut', 'taxiOut']);
  });

  it('还没落地的航迹不会出现落地后滑行', () => {
    const points = [taxi(), climbing(10000), level(30000), level(30000)];
    expect(classifyTrackPhases(points)).not.toContain('taxiIn');
  });

  /*
   * 起飞后短暂弹跳（touch and go / 跳跃着陆）不能把后面整段算成落地滑行 ——
   * 接地点要取最后一次落地，不是第一次。
   */
  it('起飞后的短暂接地不会把后续巡航误判成落地后滑行', () => {
    const points = [
      taxi(),
      climbing(500),
      point({ onGround: true, altitude: 0, groundSpeed: 120 }), // 弹跳接地
      climbing(15000),
      level(33000),
      descending(3000),
      taxi(),
    ];
    const phases = classifyTrackPhases(points);
    expect(phases[4]).toBe('cruise');
    // 只有最后那一点才是落地后滑行
    expect(phases.filter((phase) => phase === 'taxiIn')).toHaveLength(1);
  });

  it('没有 onGround 时退回高度与地速判定', () => {
    const points = [
      point({ altitude: 0, groundSpeed: 10, radioAltitude: 0 }),
      point({ altitude: 8000, groundSpeed: 300, radioAltitude: 7800, verticalSpeed: 1800 }),
      point({ altitude: 30000, groundSpeed: 450, radioAltitude: 29000, verticalSpeed: 0 }),
      point({ altitude: 0, groundSpeed: 12, radioAltitude: 0 }),
    ];
    const phases = classifyTrackPhases(points);
    expect(phases[0]).toBe('taxiOut');
    expect(phases.at(-1)).toBe('taxiIn');
  });

  // 高原机场停机坪的气压高度可能有好几千英尺，光看高度会把停着的飞机判成在飞
  it('高原机场地面高度很高也不会误判成在空中', () => {
    const points = [
      point({ onGround: true, altitude: 11000, groundSpeed: 10 }),
      point({ onGround: true, altitude: 11000, groundSpeed: 15 }),
    ];
    expect(classifyTrackPhases(points)).toEqual<TrackPhase[]>(['taxiOut', 'taxiOut']);
  });
});

describe('buildTrackSegments', () => {
  it('空输入返回空数组', () => {
    expect(buildTrackSegments([])).toEqual([]);
  });

  it('同阶段的连续点压成一段', () => {
    const segments = buildTrackSegments(['taxiOut', 'taxiOut', 'taxiOut']);
    expect(segments).toHaveLength(1);
    expect(segments[0]).toMatchObject({ phase: 'taxiOut', startIndex: 0, endIndex: 2 });
  });

  /*
   * 相邻两段必须共享一个点，否则折线在换色处会留下肉眼可见的缺口。
   */
  it('相邻段共享一个点，折线不会断开', () => {
    const segments = buildTrackSegments(['taxiOut', 'taxiOut', 'climb', 'climb']);
    expect(segments).toHaveLength(2);
    expect(segments[0].endIndex).toBe(2);
    expect(segments[1].startIndex).toBe(2);
  });

  it('最后一段以末点收尾，不会越界', () => {
    const phases: TrackPhase[] = ['climb', 'cruise', 'cruise'];
    const segments = buildTrackSegments(phases);
    expect(segments.at(-1)?.endIndex).toBe(phases.length - 1);
  });

  it('每个阶段各自成段，顺序与输入一致', () => {
    const segments = buildTrackSegments(['taxiOut', 'climb', 'cruise', 'approach', 'taxiIn']);
    expect(segments.map((segment) => segment.phase)).toEqual([
      'taxiOut',
      'climb',
      'cruise',
      'approach',
      'taxiIn',
    ]);
  });
});
