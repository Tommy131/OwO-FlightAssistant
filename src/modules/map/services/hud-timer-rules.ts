/**
 * HUD 计时器自动启停判定（纯函数）
 *
 * 原先内嵌在 `map-store.ts` 里，判定与副作用（调 store 的 start/pause）混在一起，
 * 没法单独验证。这里只回答「该做什么」，由调用方去做。
 *
 * 这段逻辑值得单独锁住：三种启动模式与三种停止模式两两组合，
 * 判错了的表现是「计时器该走的时候没走」——飞完一整段才发现，
 * 而且没有任何报错。
 */

import type {
  MapAircraftState,
  MapAutoTimerStartMode,
  MapAutoTimerStopMode,
} from '../models/map-models';

export interface HudTimerSettings {
  readonly autoHudTimerEnabled: boolean;
  readonly hasHudTimerStarted: boolean;
  readonly isHudTimerRunning: boolean;
  readonly autoTimerStartMode: MapAutoTimerStartMode;
  readonly autoTimerStopMode: MapAutoTimerStopMode;
}

/** 判定结果：调用方据此调用 startHudTimer / pauseHudTimer */
export type HudTimerAction = 'start' | 'stop' | 'none';

/** runwayMovement：地速超过此值视为进跑道加速 */
const RUNWAY_MOVEMENT_GROUND_SPEED_KT = 30;
/** runwayExitAfterLanding：地速降到此值以下视为已脱离跑道 */
const RUNWAY_EXIT_GROUND_SPEED_KT = 30;
/** stableLanding：完全停稳 */
const STABLE_STOP_GROUND_SPEED_KT = 5;
/** parkingArrival：到位且刹车已设 */
const PARKED_GROUND_SPEED_KT = 1;

/**
 * 根据当前状态判断计时器该启动、停止，还是什么都不做。
 *
 * `isMoving` 由调用方按自己的判定给出（地速阈值可能与这里的模式阈值不同）。
 */
export function resolveHudTimerAction(
  settings: HudTimerSettings,
  aircraft: MapAircraftState,
  isMoving: boolean,
): HudTimerAction {
  if (!settings.autoHudTimerEnabled) return 'none';

  // onGround 缺失时按「在地面」处理：宁可晚一点开始计时，
  // 也不要在空中把一段巡航误判成滑行起点
  const onGround = aircraft.onGround ?? true;
  const groundSpeed = aircraft.groundSpeed ?? 0;

  // ── 自动启动：只在「还没起过」时判定 ──
  // 这里直接返回而不落到停止分支，是安全的：startHudTimer 同时置起
  // isHudTimerRunning 与 hasHudTimerStarted，resetHudTimer 同时清掉两者，
  // pause 只动前者。所以 isHudTimerRunning 为真必然蕴含 hasHudTimerStarted 为真，
  // 「没起过却在跑」这个状态不存在。
  if (!settings.hasHudTimerStarted) {
    if (!isMoving) return 'none';
    switch (settings.autoTimerStartMode) {
      case 'anyMovement':
        return 'start';
      case 'pushback':
        // 推出：还在地面且已松刹车
        return onGround && aircraft.parkingBrake !== true ? 'start' : 'none';
      default:
        // runwayMovement
        return onGround && groundSpeed >= RUNWAY_MOVEMENT_GROUND_SPEED_KT ? 'start' : 'none';
    }
  }

  // ── 自动停止：只在计时器正在走且已落地时判定 ──
  if (settings.isHudTimerRunning && onGround) {
    switch (settings.autoTimerStopMode) {
      case 'parkingArrival':
        return groundSpeed < PARKED_GROUND_SPEED_KT && aircraft.parkingBrake === true
          ? 'stop'
          : 'none';
      case 'runwayExitAfterLanding':
        return groundSpeed < RUNWAY_EXIT_GROUND_SPEED_KT ? 'stop' : 'none';
      default:
        // stableLanding
        return groundSpeed < STABLE_STOP_GROUND_SPEED_KT ? 'stop' : 'none';
    }
  }

  return 'none';
}
