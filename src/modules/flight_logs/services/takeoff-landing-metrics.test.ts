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
  flareHeightFt,
  headingDifference,
  peakTouchdownG,
  scoreApproachStability,
  scoreTakeoffStability,
  touchdownSinkRateFpm,
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

/*
 * 接地冲击取值
 *
 * 这一组是那个「不管怎么落都只报 1.12 G」的回归测试。
 * 症结是取值时机：G 的峰值在触地**之后**，下沉率的真值在触地**之前**，
 * 只读 onGround 翻转的那一个采样点，两个都读不对。
 */
const G_BOUNDS = { minValidG: 0.3, maxValidG: 8 };

/** 一次重着陆：0.2s 触地，0.4s 支柱压到底出现峰值，随后回落 */
function hardLandingPoints(): FlightLogPoint[] {
  return [
    point({ t: 0.0, onGround: false, gForce: 1.0, verticalSpeed: -515 }),
    point({ t: 0.2, onGround: true, gForce: 1.12 }), // 触地瞬间，支柱还没压缩
    point({ t: 0.4, onGround: true, gForce: 3.36 }), // 真正的冲击峰值
    point({ t: 0.6, onGround: true, gForce: 1.8 }),
    point({ t: 1.0, onGround: true, gForce: 1.05 }),
  ];
}

describe('peakTouchdownG', () => {
  // 用户实测：模拟器自报 3.36，应用却显示 1.12（触地那一点的值）
  it('取触地之后窗口内的峰值，而不是触地瞬间的值', () => {
    expect(peakTouchdownG(hardLandingPoints(), 1, G_BOUNDS)).toBeCloseTo(3.36, 2);
  });

  it('轻着陆不会被放大', () => {
    const points = [
      point({ t: 0.0, onGround: false, gForce: 1.0 }),
      point({ t: 0.2, onGround: true, gForce: 1.03 }),
      point({ t: 0.4, onGround: true, gForce: 1.12 }),
      point({ t: 0.6, onGround: true, gForce: 1.04 }),
    ];
    expect(peakTouchdownG(points, 1, G_BOUNDS)).toBeCloseTo(1.12, 2);
  });

  // 窗口不能长到把滑跑段扫进来 —— 压过跑道接缝也会有小尖峰
  it('窗口之外的尖峰不算数', () => {
    const points = [
      point({ t: 0.0, onGround: true, gForce: 1.1 }),
      point({ t: 5.0, onGround: true, gForce: 2.9 }), // 滑跑中压过接缝
    ];
    expect(peakTouchdownG(points, 0, G_BOUNDS)).toBeCloseTo(1.1, 2);
  });

  it('区间外的坏读数被丢掉', () => {
    const points = [
      point({ t: 0.0, onGround: true, gForce: 1.2 }),
      point({ t: 0.3, onGround: true, gForce: 99 }), // 模拟器坏值
      point({ t: 0.6, onGround: true, gForce: 0 }),
    ];
    expect(peakTouchdownG(points, 0, G_BOUNDS)).toBeCloseTo(1.2, 2);
  });

  /*
   * 采样本身可能整个错过那 100~300ms 的尖峰（X-Plane 原本 5Hz 订阅，
   * 200ms 一个样）。中间件按 60Hz 收 G 并保持窗口峰值下发，
   * 这里必须优先采信那个数，否则前端再怎么扫也只能扫到 1.0 出头。
   */
  it('优先采用中间件下发的窗口峰值，而不是采样点的瞬时值', () => {
    const points = [
      point({ t: 0.0, onGround: false, gForce: 1.0 }),
      point({ t: 0.2, onGround: true, gForce: 1.12, gForcePeak: 3.36 }),
      point({ t: 0.4, onGround: true, gForce: 1.05, gForcePeak: 3.36 }),
    ];
    expect(peakTouchdownG(points, 1, G_BOUNDS)).toBeCloseTo(3.36, 2);
  });

  it('没有窗口峰值时退回瞬时值', () => {
    const points = [
      point({ t: 0.0, onGround: true, gForce: 1.4, gForcePeak: undefined }),
      point({ t: 0.3, onGround: true, gForce: 1.9 }),
    ];
    expect(peakTouchdownG(points, 0, G_BOUNDS)).toBeCloseTo(1.9, 2);
  });

  it('区间外的窗口峰值同样被丢掉', () => {
    const points = [point({ t: 0, onGround: true, gForce: 1.2, gForcePeak: 99 })];
    expect(peakTouchdownG(points, 0, G_BOUNDS)).toBeUndefined();
  });

  it('全是坏读数时返回 undefined 而不是硬凑一个数', () => {
    const points = [point({ t: 0, onGround: true, gForce: 99 })];
    expect(peakTouchdownG(points, 0, G_BOUNDS)).toBeUndefined();
  });

  it('下标越界不炸', () => {
    expect(peakTouchdownG([], 0, G_BOUNDS)).toBeUndefined();
    expect(peakTouchdownG(hardLandingPoints(), 99, G_BOUNDS)).toBeUndefined();
  });
});

describe('touchdownSinkRateFpm', () => {
  // 触地后起落架已经吃掉一截垂速，读那一点会把 -515 报成 -254
  it('取触地前最后一个空中采样的垂速', () => {
    expect(touchdownSinkRateFpm(hardLandingPoints(), 1)).toBe(-515);
  });

  it('跳过触地后的采样点', () => {
    const points = [
      point({ t: 0.0, onGround: false, verticalSpeed: -600 }),
      point({ t: 0.2, onGround: true, verticalSpeed: -254 }),
      point({ t: 0.4, onGround: true, verticalSpeed: -20 }),
    ];
    expect(touchdownSinkRateFpm(points, 1)).toBe(-600);
  });

  it('回看窗口之外的不算', () => {
    const points = [
      point({ t: 0.0, onGround: false, verticalSpeed: -700 }),
      point({ t: 10.0, onGround: true, verticalSpeed: -30 }),
    ];
    expect(touchdownSinkRateFpm(points, 1)).toBeUndefined();
  });

  it('没有 onGround 时按垂速判断是否在空中', () => {
    const points = [
      point({ t: 0.0, onGround: undefined, verticalSpeed: -480 }),
      point({ t: 0.2, onGround: true, verticalSpeed: -100 }),
    ];
    expect(touchdownSinkRateFpm(points, 1)).toBe(-480);
  });

  // 宁可显示不可用，也不要给一个偏小的数让人以为落得比实际轻
  it('前面没有空中采样时返回 undefined', () => {
    const points = [
      point({ t: 0.0, onGround: true, verticalSpeed: -10 }),
      point({ t: 0.2, onGround: true, verticalSpeed: -5 }),
    ];
    expect(touchdownSinkRateFpm(points, 1)).toBeUndefined();
  });
});

/*
 * 拉平高度此前恒为 0 —— 读的是「落地定稿那一刻」的无线电高度，
 * 而定稿在连续在地 2 秒之后，飞机早停在跑道上了。
 */
describe('flareHeightFt', () => {
  /** 一次正常拉平：80ft 沉得最快，之后逐渐拉平接地 */
  const approach = [
    point({ t: 0, radioAltitude: 200, verticalSpeed: -700 }), // 超出搜索范围
    point({ t: 1, radioAltitude: 120, verticalSpeed: -720 }),
    point({ t: 2, radioAltitude: 80, verticalSpeed: -800 }), // 沉得最快 = 拉平起点
    point({ t: 3, radioAltitude: 40, verticalSpeed: -500 }),
    point({ t: 4, radioAltitude: 12, verticalSpeed: -220 }),
    point({ t: 5, radioAltitude: 0, verticalSpeed: -60, onGround: true }),
  ];

  it('取下沉最快那一点的对地高度，而不是接地后的 0', () => {
    expect(flareHeightFt(approach, 5)).toBe(80);
  });

  it('excludes a hard-touchdown ground sample even when it has the most-negative sink rate', () => {
    const hardTouchdown = [
      point({ t: 0, radioAltitude: 120, verticalSpeed: -700, onGround: false }),
      point({ t: 1, radioAltitude: 80, verticalSpeed: -800, onGround: false }),
      point({ t: 2, radioAltitude: 25, verticalSpeed: -400, onGround: false }),
      point({ t: 3, radioAltitude: 0, verticalSpeed: -1_200, onGround: true }),
    ];

    expect(flareHeightFt(hardTouchdown, 3)).toBe(80);
  });

  it('搜索上限之外的采样不参与', () => {
    // 200ft 那点垂速更负也不能选，它在 FLARE_SEARCH_AGL_FT 之上
    expect(flareHeightFt(approach, 5)).not.toBe(200);
  });

  it('接地后的回弹（正垂速）不参与', () => {
    const points = [
      point({ t: 0, radioAltitude: 60, verticalSpeed: -600 }),
      point({ t: 1, radioAltitude: 0, verticalSpeed: 0, onGround: true }),
      point({ t: 2, radioAltitude: 5, verticalSpeed: 300, onGround: false }),
    ];
    expect(flareHeightFt(points, 2)).toBe(60);
  });

  it('没有无线电高度时返回 undefined', () => {
    const points = [
      point({ t: 0, radioAltitude: undefined, verticalSpeed: -500 }),
      point({ t: 1, radioAltitude: undefined, verticalSpeed: -200, onGround: true }),
    ];
    expect(flareHeightFt(points, 1)).toBeUndefined();
  });

  it('下标越界不炸', () => {
    expect(flareHeightFt([], 0)).toBeUndefined();
    expect(flareHeightFt(approach, 99)).toBeUndefined();
  });

  it('忽略接地前无效的负数对地高度', () => {
    const points = [
      point({ t: 0, radioAltitude: 100, verticalSpeed: -500 }),
      point({ t: 1, radioAltitude: -2, verticalSpeed: -900 }),
      point({ t: 2, radioAltitude: 0, verticalSpeed: -50, onGround: true }),
    ];

    expect(flareHeightFt(points, 2)).toBe(100);
  });
});
