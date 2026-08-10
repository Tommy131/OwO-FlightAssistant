import { describe, expect, it } from 'vitest';

import type { MapRunwayGeometry } from '../../map/models/map-models';
import type { FlightLog, FlightLogPoint, TakeoffData, LandingData } from '../models/flight-log-models';
import {
  APPROACH_WINDOW_AGL_FT,
  ROTATION_PITCH_DEG,
  SCREEN_HEIGHT_FT,
  computeLandingMetrics,
  computeRemainingRunwayFt,
  computeTakeoffMetrics,
  headingDifference,
  scoreApproachStability,
  scoreTakeoffStability,
} from './takeoff-landing-metrics';

/**
 * 起飞 / 落地派生指标
 *
 * 这六项此前恒为 `--`：模型、序列化、i18n、渲染都齐了，就是没人算。
 * 评分公式是自拟的，所以这里重点钉「单调性」与「边界」而不是绝对分值 ——
 * 断言具体分数会让每次调权重都要改一堆测试。
 */

const T0 = new Date('2026-08-10T10:00:00Z').getTime();

function point(overrides: Partial<FlightLogPoint> & { t: number }): FlightLogPoint {
  const { t, ...rest } = overrides;
  return {
    latitude: 40,
    longitude: 116,
    altitude: 1000,
    airspeed: 140,
    groundSpeed: 140,
    verticalSpeed: 0,
    heading: 360,
    pitch: 0,
    roll: 0,
    gForce: 1,
    gForceSource: 'body',
    fuelQuantity: 8000,
    onGround: true,
    timestamp: new Date(T0 + t * 1000),
    anomalyAlerts: [],
    ...rest,
  };
}

function takeoffAt(t: number, overrides: Partial<TakeoffData> = {}): TakeoffData {
  return {
    latitude: 40,
    longitude: 116,
    airspeed: 150,
    groundSpeed: 150,
    verticalSpeed: 700,
    pitch: 10,
    heading: 360,
    timestamp: new Date(T0 + t * 1000),
    ...overrides,
  };
}

function landingAt(t: number, overrides: Partial<LandingData> = {}): LandingData {
  return {
    latitude: 40,
    longitude: 116,
    gForce: 1.2,
    gForceSource: 'body',
    verticalSpeed: -200,
    airspeed: 130,
    groundSpeed: 130,
    pitch: 3,
    roll: 0,
    rating: 'good',
    timestamp: new Date(T0 + t * 1000),
    touchdownSequence: [],
    touchdownGForces: [],
    ...overrides,
  };
}

/** 一次典型起飞：0–4s 地面加速，2s 起抬轮，5s 离地，之后爬升 */
function takeoffLog(): Pick<FlightLog, 'points' | 'takeoffData'> {
  const points: FlightLogPoint[] = [
    point({ t: 0, airspeed: 60, pitch: 0, altitude: 1000 }),
    point({ t: 1, airspeed: 100, pitch: 0, altitude: 1000 }),
    point({ t: 2, airspeed: 130, pitch: 3, altitude: 1000 }), // 抬轮
    point({ t: 3, airspeed: 140, pitch: 6, altitude: 1000 }),
    point({ t: 4, airspeed: 148, pitch: 9, altitude: 1000 }),
    point({ t: 5, airspeed: 150, pitch: 10, altitude: 1000, onGround: false }), // 离地
    point({ t: 6, airspeed: 155, pitch: 12, altitude: 1030, onGround: false }),
    point({ t: 7, airspeed: 160, pitch: 13, altitude: 1080, onGround: false }),
    point({ t: 8, airspeed: 165, pitch: 13, altitude: 1200, onGround: false }),
  ];
  return { points, takeoffData: takeoffAt(5) };
}

describe('抬轮速度与抬轮到离地耗时', () => {
  it('取俯仰首次越过门限那一点的速度', () => {
    const metrics = computeTakeoffMetrics(takeoffLog());
    expect(metrics.rotationSpeedKt).toBe(130);
  });

  it('耗时是抬轮到离地的间隔', () => {
    const metrics = computeTakeoffMetrics(takeoffLog());
    expect(metrics.rotationToLiftoffSec).toBe(3);
  });

  // 从空中开始录制时压根没有滑跑段
  it('没采到滑跑段时标记为未采到抬轮', () => {
    const airborneOnly = {
      points: [
        point({ t: 0, onGround: false, altitude: 5000 }),
        point({ t: 1, onGround: false, altitude: 5100 }),
      ],
      takeoffData: takeoffAt(0),
    };
    const metrics = computeTakeoffMetrics(airborneOnly);
    expect(metrics.rotationSpeedKt).toBeUndefined();
    expect(metrics.unavailable.rotationSpeedKt).toBe('no_rotation');
    expect(metrics.unavailable.rotationToLiftoffSec).toBe('no_rotation');
  });

  it('俯仰始终没到门限时不认抬轮', () => {
    const flat = {
      points: [
        point({ t: 0, pitch: 0 }),
        point({ t: 1, pitch: ROTATION_PITCH_DEG - 0.5 }),
        point({ t: 2, pitch: 1, onGround: false }),
      ],
      takeoffData: takeoffAt(2),
    };
    expect(computeTakeoffMetrics(flat).unavailable.rotationSpeedKt).toBe('no_rotation');
  });

  /**
   * 训练起落航线（touch-and-go）：一次录制里有多次起降。
   *
   * 关键在于**接地全程都保持抬头姿态**，俯仰从没掉回门限以下 ——
   * 所以「俯仰低于门限就停」这条判据在这里完全不会触发，
   * 只有「回退到空中就停」那条能把上一段航程隔开。
   * 少了它就会一路回溯到第一次起飞，报出那次的抬轮速度。
   */
  it('连续起落时不会回溯到上一次起飞的抬轮点', () => {
    const points: FlightLogPoint[] = [
      point({ t: 0, airspeed: 100, pitch: 5 }), // 第一次抬轮
      point({ t: 1, airspeed: 120, pitch: 8, onGround: false }), // 空中，仍抬头
      point({ t: 2, airspeed: 135, pitch: 4, onGround: true }), // 接地续滑，仍抬头
      point({ t: 3, airspeed: 145, pitch: 9, onGround: false }), // 第二次离地
    ];
    const metrics = computeTakeoffMetrics({ points, takeoffData: takeoffAt(3) });
    expect(metrics.rotationSpeedKt).toBe(135);
  });
});

describe('35 英尺俯仰角', () => {
  it('用无线电高度时按插值取', () => {
    const points = [
      point({ t: 0, onGround: false, radioAltitude: 0, pitch: 10 }),
      point({ t: 1, onGround: false, radioAltitude: 70, pitch: 14 }),
    ];
    const metrics = computeTakeoffMetrics({ points, takeoffData: takeoffAt(0) });
    // 35ft 正好在两点中间 → 俯仰取中值 12
    expect(metrics.pitchAt35FtDeg).toBeCloseTo(12, 1);
  });

  // 一大批机型不提供无线电高度，硬要它就等于这项永远取不到
  it('没有无线电高度时退回气压高度差', () => {
    const points = [
      point({ t: 0, onGround: false, altitude: 1000, pitch: 10 }),
      point({ t: 1, onGround: false, altitude: 1000 + SCREEN_HEIGHT_FT, pitch: 15 }),
    ];
    const metrics = computeTakeoffMetrics({ points, takeoffData: takeoffAt(0) });
    expect(metrics.pitchAt35FtDeg).toBeCloseTo(15, 1);
  });

  it('整段都没爬到 35ft 时标记为无离地高度', () => {
    const points = [
      point({ t: 0, onGround: false, altitude: 1000, pitch: 8 }),
      point({ t: 1, onGround: false, altitude: 1010, pitch: 9 }),
    ];
    const metrics = computeTakeoffMetrics({ points, takeoffData: takeoffAt(0) });
    expect(metrics.pitchAt35FtDeg).toBeUndefined();
    expect(metrics.unavailable.pitchAt35FtDeg).toBe('no_agl');
  });
});

describe('起飞稳定性评分', () => {
  const window = (overrides: Partial<FlightLogPoint>[]): FlightLogPoint[] =>
    overrides.map((o, i) => point({ t: i, onGround: false, ...o }));

  it('全程对正跑道、机翼水平、俯仰平稳时接近满分', () => {
    const score = scoreTakeoffStability(
      window(Array.from({ length: 8 }, () => ({ heading: 360, roll: 0, pitch: 12 }))),
      360,
    );
    expect(score).toBe(100);
  });

  it('偏离跑道方向会扣分', () => {
    const drifted = scoreTakeoffStability(
      window(Array.from({ length: 8 }, () => ({ heading: 340, roll: 0, pitch: 12 }))),
      360,
    );
    expect(drifted).toBeLessThan(100);
  });

  it('偏得越多扣得越多', () => {
    const small = scoreTakeoffStability(
      window(Array.from({ length: 8 }, () => ({ heading: 355, pitch: 12 }))),
      360,
    );
    const large = scoreTakeoffStability(
      window(Array.from({ length: 8 }, () => ({ heading: 330, pitch: 12 }))),
      360,
    );
    expect(large).toBeLessThan(small);
  });

  it('早压坡度会扣分', () => {
    const banked = scoreTakeoffStability(
      window(Array.from({ length: 8 }, () => ({ heading: 360, roll: 20, pitch: 12 }))),
      360,
    );
    expect(banked).toBeLessThan(100);
  });

  it('俯仰忽上忽下会扣分', () => {
    const oscillating = scoreTakeoffStability(
      window([
        { pitch: 5 },
        { pitch: 18 },
        { pitch: 6 },
        { pitch: 17 },
        { pitch: 4 },
        { pitch: 19 },
      ]),
      360,
    );
    expect(oscillating).toBeLessThan(100);
  });

  it('分数永远落在 0–100', () => {
    const awful = scoreTakeoffStability(
      window(Array.from({ length: 8 }, (_, i) => ({ heading: i * 45, roll: 80, pitch: i * 10 }))),
      360,
    );
    expect(awful).toBeGreaterThanOrEqual(0);
    expect(awful).toBeLessThanOrEqual(100);
  });

  // 航向跨 0°/360° 时不能算成偏了 358 度
  it('航向跨越 360° 时按最短夹角算', () => {
    // 1° 与 359° 实际只差 2°，扣分应当很轻
    const nearlyAligned = scoreTakeoffStability(
      window(Array.from({ length: 8 }, () => ({ heading: 1, pitch: 12 }))),
      359,
    );
    // 同样是「1」这个读数，对着 181° 的跑道才是真的偏了 180°
    const trulyReversed = scoreTakeoffStability(
      window(Array.from({ length: 8 }, () => ({ heading: 1, pitch: 12 }))),
      181,
    );
    expect(nearlyAligned).toBeGreaterThanOrEqual(95);
    expect(trulyReversed).toBeLessThan(70);
  });

  it('采样点太少时不给分', () => {
    const metrics = computeTakeoffMetrics({
      points: [point({ t: 0, onGround: false }), point({ t: 1, onGround: false })],
      takeoffData: takeoffAt(0),
    });
    expect(metrics.takeoffStabilityScore).toBeUndefined();
    expect(metrics.unavailable.takeoffStabilityScore).toBe('insufficient_samples');
  });
});

describe('进近稳定性评分', () => {
  const approach = (overrides: Partial<FlightLogPoint>[]): FlightLogPoint[] =>
    overrides.map((o, i) => point({ t: i, onGround: false, ...o }));

  it('全程稳定时满分', () => {
    const score = scoreApproachStability(
      approach(Array.from({ length: 10 }, () => ({ verticalSpeed: -700, roll: 2, airspeed: 140 }))),
    );
    expect(score).toBe(100);
  });

  it('下降率超限会扣分', () => {
    const score = scoreApproachStability(
      approach(Array.from({ length: 10 }, () => ({ verticalSpeed: -1400, airspeed: 140 }))),
    );
    expect(score).toBeLessThan(100);
  });

  // 偶尔一帧超限和一路都在超是完全不同的两件事
  it('按超限占比扣分，而不是按峰值', () => {
    const occasional = scoreApproachStability(
      approach(
        Array.from({ length: 10 }, (_, i) => ({
          verticalSpeed: i === 0 ? -1400 : -700,
          airspeed: 140,
        })),
      ),
    );
    const persistent = scoreApproachStability(
      approach(Array.from({ length: 10 }, () => ({ verticalSpeed: -1400, airspeed: 140 }))),
    );
    expect(occasional).toBeGreaterThan(persistent);
  });

  it('大坡度会扣分', () => {
    const score = scoreApproachStability(
      approach(Array.from({ length: 10 }, () => ({ roll: 25, verticalSpeed: -700, airspeed: 140 }))),
    );
    expect(score).toBeLessThan(100);
  });

  it('速度忽快忽慢会扣分', () => {
    const score = scoreApproachStability(
      approach([
        { airspeed: 120 },
        { airspeed: 155 },
        { airspeed: 125 },
        { airspeed: 158 },
        { airspeed: 122 },
        { airspeed: 160 },
      ].map((o) => ({ ...o, verticalSpeed: -700 }))),
    );
    expect(score).toBeLessThan(100);
  });

  it('空窗口不炸', () => {
    expect(scoreApproachStability([])).toBe(100);
  });

  it('只取接地前 1000ft 以内的段', () => {
    const points = [
      // 远在窗口之外，姿态再差也不该影响评分
      point({ t: 0, onGround: false, altitude: 5000, roll: 60, verticalSpeed: -3000 }),
      ...Array.from({ length: 8 }, (_, i) =>
        point({
          t: 1 + i,
          onGround: false,
          altitude: 1000 + (APPROACH_WINDOW_AGL_FT - 100) - i * 50,
          roll: 1,
          verticalSpeed: -600,
          airspeed: 135,
        }),
      ),
      // 接地点的速度要与进近段一致，否则速度标准差会自己扣掉几分，
      // 就分不清「窗口外的坏点漏进来了」还是「fixture 自己不一致」
      point({ t: 9, altitude: 1000, onGround: true, airspeed: 135, verticalSpeed: -600 }),
    ];
    const metrics = computeLandingMetrics({ points, landingData: landingAt(9) });
    expect(metrics.approachStabilityScore).toBe(100);
  });
});

describe('剩余跑道', () => {
  /** 南北向、约 3336 m 长的跑道 */
  const runway: MapRunwayGeometry = {
    ident: '18/36',
    start: { latitude: 40.0, longitude: 116.0 },
    end: { latitude: 40.03, longitude: 116.0 },
  };

  it('朝 end 方向时剩余 = 全长 - 已走', () => {
    // 落在四分之一处，机头朝北（朝 end）
    const remaining = computeRemainingRunwayFt(
      { latitude: 40.0075, longitude: 116.0 },
      360,
      runway,
    );
    // 全长约 3336 m ≈ 10945 ft，剩四分之三 ≈ 8200 ft
    expect(remaining ?? 0).toBeGreaterThan(7800);
    expect(remaining ?? 0).toBeLessThan(8600);
  });

  // 方向搞反会把「还剩 400 m」报成「还剩 2600 m」—— 这个数是用来判断能不能停住的
  it('朝 start 方向时从另一头算', () => {
    const remaining = computeRemainingRunwayFt(
      { latitude: 40.0075, longitude: 116.0 },
      180,
      runway,
    );
    // 反向落地 → 只剩四分之一 ≈ 2700 ft
    expect(remaining ?? 0).toBeGreaterThan(2400);
    expect(remaining ?? 0).toBeLessThan(3000);
  });

  it('两个方向加起来等于全长', () => {
    const forward = computeRemainingRunwayFt({ latitude: 40.02, longitude: 116 }, 360, runway) ?? 0;
    const backward = computeRemainingRunwayFt({ latitude: 40.02, longitude: 116 }, 180, runway) ?? 0;
    expect(forward + backward).toBeGreaterThan(10800);
    expect(forward + backward).toBeLessThan(11100);
  });

  it('没有跑道几何时返回 undefined', () => {
    expect(computeRemainingRunwayFt({ latitude: 40, longitude: 116 }, 360, undefined)).toBeUndefined();
  });

  it('没有航向时返回 undefined —— 不知道朝哪飞就算不出剩多少', () => {
    expect(
      computeRemainingRunwayFt({ latitude: 40.01, longitude: 116 }, undefined, runway),
    ).toBeUndefined();
  });

  it('点在跑道延长线之外时返回 undefined', () => {
    expect(computeRemainingRunwayFt({ latitude: 39.9, longitude: 116 }, 360, runway)).toBeUndefined();
  });

  it('取不到跑道时在结果里说明原因', () => {
    const metrics = computeTakeoffMetrics(takeoffLog());
    expect(metrics.remainingRunwayFt).toBeUndefined();
    expect(metrics.unavailable.remainingRunwayFt).toBe('no_runway_geometry');
  });
});

describe('缺少起飞/落地记录时', () => {
  it('起飞侧全部标为 no_takeoff', () => {
    const metrics = computeTakeoffMetrics({ points: [], takeoffData: undefined });
    expect(metrics.unavailable.rotationSpeedKt).toBe('no_takeoff');
    expect(metrics.unavailable.pitchAt35FtDeg).toBe('no_takeoff');
    expect(metrics.unavailable.takeoffStabilityScore).toBe('no_takeoff');
    expect(metrics.unavailable.remainingRunwayFt).toBe('no_takeoff');
  });

  it('落地侧全部标为 no_landing', () => {
    const metrics = computeLandingMetrics({ points: [], landingData: undefined });
    expect(metrics.unavailable.approachStabilityScore).toBe('no_landing');
    expect(metrics.unavailable.remainingRunwayFt).toBe('no_landing');
  });
});

describe('headingDifference', () => {
  it('给出最短夹角', () => {
    expect(headingDifference(10, 350)).toBe(20);
    expect(headingDifference(350, 10)).toBe(-20);
    expect(headingDifference(90, 90)).toBe(0);
    expect(Math.abs(headingDifference(0, 180))).toBe(180);
  });
});
