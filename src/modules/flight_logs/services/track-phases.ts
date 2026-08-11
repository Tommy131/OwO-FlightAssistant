import type { FlightLogPoint } from '../models/flight-log-models';

/**
 * 航迹阶段划分（纯函数）
 *
 * 把一条已经录完的航迹切成五段着色：
 *
 *   起飞前滑行 ── 爬升中 ── 巡航中 ── 进近中 ── 落地后滑行
 *
 * ── 为什么不复用检查单那套阶段推断 ──
 * 那套是**实时**的：只能看到「此刻」的高度与垂速，必须逐点猜。
 * 这里面对的是一条**完整**航迹，可以先整体扫一遍拿到离地点、接地点、
 * 巡航高度，再回头给每个点定性 —— 同样的数据，两遍扫描判得准得多。
 *
 * 典型差别：巡航中遇到一段扰流下沉，实时推断会瞬间跳成「下降」，
 * 而这里因为知道后面还会回到巡航高度、真正的下降要到很晚才开始，
 * 那一小段仍然算巡航。反过来，起飞前在跑道上加速滑跑（地速很高但没离地）
 * 实时容易误判成起飞，这里靠 onGround 翻转点卡得死死的。
 *
 * 不 import React / Leaflet / store，可直接单测。
 */

/** 航迹阶段 */
export type TrackPhase = 'taxiOut' | 'climb' | 'cruise' | 'approach' | 'taxiIn';

/** 阶段顺序，图例按这个次序排 */
export const TRACK_PHASE_ORDER: readonly TrackPhase[] = [
  'taxiOut',
  'climb',
  'cruise',
  'approach',
  'taxiIn',
];

/**
 * 判定用的阈值。
 *
 * 都取得比较宽松 —— 这些数只用来给航迹着色，判偏一两个点没有后果；
 * 卡太紧反而会让轻微的高度波动把巡航段切得七零八落。
 */
/** 视为「已离地」的对地高度（英尺） */
const AIRBORNE_AGL_FT = 50;
/** 视为「在地面滑行」的地速上限（节）—— 再低就是停着了 */
const TAXI_MAX_GROUND_SPEED_KT = 60;
/** 巡航判定：垂速绝对值低于此值算平飞（英尺/分钟） */
const LEVEL_VS_FPM = 300;
/** 巡航判定：高度达到全程最高的这个比例即算进入巡航层 */
const CRUISE_ALTITUDE_RATIO = 0.92;

/** 一段连续同阶段的航迹 */
export interface TrackSegment {
  phase: TrackPhase;
  /** 该段在原始点数组中的起止下标（闭区间） */
  startIndex: number;
  endIndex: number;
}

/**
 * 逐点定性。
 *
 * 返回的数组与输入等长，第 i 项即第 i 个点所处的阶段。
 * 空输入返回空数组。
 */
export function classifyTrackPhases(points: readonly FlightLogPoint[]): TrackPhase[] {
  if (points.length === 0) return [];

  const airborne = points.map((point) => isAirborne(point));

  // 离地点 = 第一次从地面切到空中；接地点 = 最后一次从空中切回地面。
  // 取「最后一次」而不是「第一次」，是为了不被起飞后的短暂弹跳
  // （touch and go、跳跃着陆）骗过去把整段巡航算成落地后滑行。
  const liftoffIndex = airborne.indexOf(true);
  const touchdownIndex = lastTransitionToGround(airborne);

  // 整条航迹都没离过地：全程都是滑行，没有必要再往下分
  if (liftoffIndex < 0) return points.map(() => 'taxiOut');

  const cruiseRange = findCruiseRange(points, liftoffIndex, touchdownIndex);

  return points.map((_, index) => {
    if (index < liftoffIndex) return 'taxiOut';
    // 接地点本身已经在地面上了，要一并算进落地滑行 —— 用 `>` 会把它漏在
    // 进近段里，而它恰好是整条航迹的最后一点时，落地滑行会一个点都不剩
    if (touchdownIndex >= 0 && index >= touchdownIndex) return 'taxiIn';
    if (cruiseRange && index >= cruiseRange.start && index <= cruiseRange.end) return 'cruise';
    if (cruiseRange && index > cruiseRange.end) return 'approach';
    if (!cruiseRange) {
      // 没识别出巡航段（短途、始终在爬或始终在降）：
      // 以全程最高点为界，前半段算爬升、后半段算进近
      return index <= highestIndex(points, liftoffIndex, touchdownIndex) ? 'climb' : 'approach';
    }
    return 'climb';
  });
}

/**
 * 把逐点阶段压成连续段落，供画线使用。
 *
 * 相邻两段共享一个点（前一段的末点 = 后一段的首点），
 * 否则每次换色都会在折线上留下一个缺口。
 */
export function buildTrackSegments(phases: readonly TrackPhase[]): TrackSegment[] {
  if (phases.length === 0) return [];

  const segments: TrackSegment[] = [];
  let startIndex = 0;

  for (let index = 1; index <= phases.length; index++) {
    const ended = index === phases.length || phases[index] !== phases[startIndex];
    if (!ended) continue;
    segments.push({
      phase: phases[startIndex],
      startIndex,
      // 与下一段接上，避免折线断开；最后一段就到末点为止
      endIndex: index === phases.length ? index - 1 : index,
    });
    startIndex = index;
  }

  return segments;
}

// ────────────────────────────────────────────────────────────────────────────
// 内部判定
// ────────────────────────────────────────────────────────────────────────────

/**
 * 该点是否在空中。
 *
 * `onGround` 是模拟器直接给的，最可靠，有就用它。
 * 没有（老日志、或该机型不提供）就退回高度 + 地速：
 * 光看高度不够 —— 高原机场停机坪的气压高度可能有好几千英尺，
 * 必须配合对地高度或地速才不会把停着的飞机判成在飞。
 */
function isAirborne(point: FlightLogPoint): boolean {
  if (point.onGround !== undefined) return !point.onGround;
  if (point.radioAltitude !== undefined && Number.isFinite(point.radioAltitude)) {
    return point.radioAltitude > AIRBORNE_AGL_FT;
  }
  return point.groundSpeed > TAXI_MAX_GROUND_SPEED_KT;
}

/** 最后一次「空中 → 地面」的下标；从未落地返回 -1 */
function lastTransitionToGround(airborne: readonly boolean[]): number {
  for (let index = airborne.length - 1; index > 0; index--) {
    if (!airborne[index] && airborne[index - 1]) return index;
  }
  return -1;
}

/** 空中段里高度最高的点 */
function highestIndex(
  points: readonly FlightLogPoint[],
  fromIndex: number,
  toIndex: number,
): number {
  const end = toIndex >= 0 ? toIndex : points.length - 1;
  let best = fromIndex;
  for (let index = fromIndex; index <= end && index < points.length; index++) {
    if (points[index].altitude > points[best].altitude) best = index;
  }
  return best;
}

/**
 * 找出巡航段。
 *
 * 判据是「高度接近全程最高 **且** 基本平飞」，两条都要满足：
 * 只看高度会把爬升末段和下降初段一并算进来，只看垂速会把地面滑行
 * （垂速当然是 0）也算成巡航。
 *
 * 返回首个与末个满足条件的点；一个都没有则返回 null。
 */
function findCruiseRange(
  points: readonly FlightLogPoint[],
  liftoffIndex: number,
  touchdownIndex: number,
): { start: number; end: number } | null {
  const end = touchdownIndex >= 0 ? touchdownIndex : points.length - 1;
  if (liftoffIndex > end) return null;

  let maxAltitude = -Infinity;
  for (let index = liftoffIndex; index <= end; index++) {
    if (points[index].altitude > maxAltitude) maxAltitude = points[index].altitude;
  }
  if (!Number.isFinite(maxAltitude) || maxAltitude <= 0) return null;

  const threshold = maxAltitude * CRUISE_ALTITUDE_RATIO;
  let start = -1;
  let last = -1;
  for (let index = liftoffIndex; index <= end; index++) {
    const point = points[index];
    const level = Math.abs(point.verticalSpeed) <= LEVEL_VS_FPM;
    if (point.altitude < threshold || !level) continue;
    if (start < 0) start = index;
    last = index;
  }

  return start >= 0 ? { start, end: last } : null;
}
