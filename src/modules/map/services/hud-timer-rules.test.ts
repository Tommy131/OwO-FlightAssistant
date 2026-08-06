import { describe, expect, it } from 'vitest';
import { resolveHudTimerAction, type HudTimerSettings } from './hud-timer-rules';
import type { MapAircraftState } from '../models/map-models';

/**
 * HUD 计时器自动启停
 *
 * 三种启动模式 × 三种停止模式。判错的表现是「该走的时候没走」——
 * 飞完一整段才发现，全程没有任何报错。所以每种模式都单独卡边界。
 */

const base: HudTimerSettings = {
  autoHudTimerEnabled: true,
  hasHudTimerStarted: false,
  isHudTimerRunning: false,
  autoTimerStartMode: 'anyMovement',
  autoTimerStopMode: 'stableLanding',
};

function aircraft(overrides: Partial<MapAircraftState> = {}): MapAircraftState {
  return {
    position: { latitude: 40, longitude: 116 },
    ...overrides,
  };
}

describe('总开关', () => {
  it('自动计时关闭时永远不动', () => {
    const action = resolveHudTimerAction(
      { ...base, autoHudTimerEnabled: false },
      aircraft({ onGround: true, groundSpeed: 50 }),
      true,
    );
    expect(action).toBe('none');
  });
});

describe('启动模式', () => {
  it('anyMovement：一动就开始', () => {
    expect(resolveHudTimerAction(base, aircraft({ onGround: true }), true)).toBe('start');
    // 没在动就不开始
    expect(resolveHudTimerAction(base, aircraft({ onGround: true }), false)).toBe('none');
  });

  it('pushback：地面 + 已松刹车才开始', () => {
    const settings = { ...base, autoTimerStartMode: 'pushback' as const };
    expect(
      resolveHudTimerAction(settings, aircraft({ onGround: true, parkingBrake: false }), true),
    ).toBe('start');
    // 刹车还没松 —— 只是在原地推油门，不算推出
    expect(
      resolveHudTimerAction(settings, aircraft({ onGround: true, parkingBrake: true }), true),
    ).toBe('none');
    // 已经在空中，不可能是推出
    expect(
      resolveHudTimerAction(settings, aircraft({ onGround: false, parkingBrake: false }), true),
    ).toBe('none');
  });

  it('runwayMovement：地速达到 30kt 才开始', () => {
    const settings = { ...base, autoTimerStartMode: 'runwayMovement' as const };
    expect(
      resolveHudTimerAction(settings, aircraft({ onGround: true, groundSpeed: 29 }), true),
    ).toBe('none');
    expect(
      resolveHudTimerAction(settings, aircraft({ onGround: true, groundSpeed: 30 }), true),
    ).toBe('start');
  });

  it('已经起过的计时器不会再次 start', () => {
    const settings = { ...base, hasHudTimerStarted: true, isHudTimerRunning: true };
    // 满足启动条件，但已经起过了 —— 应当进入停止判定而非重新开始
    expect(resolveHudTimerAction(settings, aircraft({ onGround: false }), true)).toBe('none');
  });
});

describe('停止模式', () => {
  const running: HudTimerSettings = {
    ...base,
    hasHudTimerStarted: true,
    isHudTimerRunning: true,
  };

  it('stableLanding：完全停稳（<5kt）', () => {
    expect(resolveHudTimerAction(running, aircraft({ onGround: true, groundSpeed: 5 }), false)).toBe(
      'none',
    );
    expect(resolveHudTimerAction(running, aircraft({ onGround: true, groundSpeed: 4 }), false)).toBe(
      'stop',
    );
  });

  it('runwayExitAfterLanding：降到 30kt 以下即停', () => {
    const settings = { ...running, autoTimerStopMode: 'runwayExitAfterLanding' as const };
    expect(
      resolveHudTimerAction(settings, aircraft({ onGround: true, groundSpeed: 30 }), false),
    ).toBe('none');
    expect(
      resolveHudTimerAction(settings, aircraft({ onGround: true, groundSpeed: 29 }), false),
    ).toBe('stop');
  });

  it('parkingArrival：停稳且已设刹车', () => {
    const settings = { ...running, autoTimerStopMode: 'parkingArrival' as const };
    expect(
      resolveHudTimerAction(
        settings,
        aircraft({ onGround: true, groundSpeed: 0, parkingBrake: true }),
        false,
      ),
    ).toBe('stop');
    // 停稳了但没设刹车 —— 还在等指挥，没到位
    expect(
      resolveHudTimerAction(
        settings,
        aircraft({ onGround: true, groundSpeed: 0, parkingBrake: false }),
        false,
      ),
    ).toBe('none');
  });

  it('还在空中时不停 —— 巡航中地速再低也不算落地', () => {
    expect(
      resolveHudTimerAction(running, aircraft({ onGround: false, groundSpeed: 0 }), false),
    ).toBe('none');
  });

  it('计时器已暂停时不重复停', () => {
    const paused = { ...running, isHudTimerRunning: false };
    expect(resolveHudTimerAction(paused, aircraft({ onGround: true, groundSpeed: 0 }), false)).toBe(
      'none',
    );
  });
});

describe('字段缺失时的兜底', () => {
  it('onGround 缺失按「在地面」处理', () => {
    // 宁可晚一点开始计时，也不要把一段巡航误判成滑行起点
    const settings = { ...base, autoTimerStartMode: 'pushback' as const };
    expect(resolveHudTimerAction(settings, aircraft({ parkingBrake: false }), true)).toBe('start');
  });

  it('groundSpeed 缺失按 0 处理', () => {
    const settings = { ...base, autoTimerStartMode: 'runwayMovement' as const };
    expect(resolveHudTimerAction(settings, aircraft({ onGround: true }), true)).toBe('none');
  });
});
