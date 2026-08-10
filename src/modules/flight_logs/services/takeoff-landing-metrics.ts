import type { MapRunwayGeometry } from '../../map/models/map-models';
import { projectOntoRunway } from '../../map/services/runway-occupancy';
import type { FlightLog, FlightLogPoint } from '../models/flight-log-models';

/**
 * 起飞 / 落地派生指标（纯计算）
 *
 * ── 这些字段此前为什么一直是 `--` ──
 * 数据模型、序列化、i18n、渲染四样都齐了，但**从来没有代码往里写过值**；
 * Flutter 桌面版同样只有标签没有计算。所以这不是移植遗漏，是两边都没做。
 *
 * ── 口径声明（重要）──
 * 「起飞稳定性 / 进近稳定性」两项**没有可对齐的桌面版实现，评分公式是本项目自拟的**，
 * 只用来横向比较自己的几次飞行，不对应任何行业标准评分。
 * 拆分权重与阈值都写在下面的常量里，要调直接改常量。
 * 进近部分的判据取自业界通行的稳定进近准则（下降率 / 坡度 / 速度稳定性），
 * 但「扣多少分」是本项目定的。
 *
 * 纯计算：不 import React / store / IO，可被直接单测。
 */

// ──────────────────────────────────────────────────────────────────────────
// 阈值与权重
// ──────────────────────────────────────────────────────────────────────────

/** 抬轮判据：仍在地面且俯仰越过该角度即视为开始抬轮 */
export const ROTATION_PITCH_DEG = 2;
/** 35 英尺屏障高度（起飞性能的标准参考截面） */
export const SCREEN_HEIGHT_FT = 35;
/** 起飞稳定性的评估窗口：离地后到该高度为止 */
export const TAKEOFF_WINDOW_AGL_FT = 400;
/** 进近稳定性的评估窗口：从该高度到接地 */
export const APPROACH_WINDOW_AGL_FT = 1000;

/** 稳定进近准则里的下降率上限（fpm） */
export const STABLE_SINK_RATE_FPM = 1000;
/** 稳定进近准则里的坡度上限（度） */
export const STABLE_BANK_DEG = 15;

/** 起飞稳定性扣分上限：航向偏差 / 坡度 / 俯仰抖动 */
const TAKEOFF_HEADING_PENALTY_CAP = 40;
const TAKEOFF_BANK_PENALTY_CAP = 30;
const TAKEOFF_PITCH_PENALTY_CAP = 30;
/** 每 1° 航向 RMS 偏差扣的分 */
const TAKEOFF_HEADING_PENALTY_PER_DEG = 2;
/** 每 1° 最大坡度扣的分 */
const TAKEOFF_BANK_PENALTY_PER_DEG = 2;
/** 每 1° 俯仰标准差扣的分 */
const TAKEOFF_PITCH_PENALTY_PER_DEG = 6;

/** 进近稳定性扣分上限：下降率超限 / 坡度超限 / 速度抖动 */
const APPROACH_SINK_PENALTY_CAP = 40;
const APPROACH_BANK_PENALTY_CAP = 30;
const APPROACH_SPEED_PENALTY_CAP = 30;
/** 速度标准差每 1 kt 扣的分 */
const APPROACH_SPEED_PENALTY_PER_KT = 6;

/** 少于这么多采样点就不给评分：样本太少算出来的标准差没有意义 */
const MIN_SCORE_SAMPLES = 5;

const METERS_TO_FEET = 3.280_84;

// ──────────────────────────────────────────────────────────────────────────
// 结果
// ──────────────────────────────────────────────────────────────────────────

/**
 * 指标取不到时的原因码。
 *
 * 界面上要显示原因而不是统一一个 `--` —— 「这架飞机不提供这个量」和
 * 「这次飞行没走完这个阶段」对用户是完全不同的两件事。
 */
export type MetricUnavailableReason =
  | 'no_takeoff'
  | 'no_landing'
  | 'no_rotation'
  | 'no_agl'
  | 'insufficient_samples'
  | 'no_runway_geometry';

export interface TakeoffMetrics {
  rotationSpeedKt?: number;
  rotationToLiftoffSec?: number;
  pitchAt35FtDeg?: number;
  takeoffStabilityScore?: number;
  remainingRunwayFt?: number;
  /** 字段名 → 取不到的原因 */
  unavailable: Partial<Record<keyof Omit<TakeoffMetrics, 'unavailable'>, MetricUnavailableReason>>;
}

export interface LandingMetrics {
  approachStabilityScore?: number;
  remainingRunwayFt?: number;
  unavailable: Partial<Record<keyof Omit<LandingMetrics, 'unavailable'>, MetricUnavailableReason>>;
}

// ──────────────────────────────────────────────────────────────────────────
// 起飞
// ──────────────────────────────────────────────────────────────────────────

/**
 * 算出起飞段的派生指标。
 *
 * `runway` 可选：拿得到跑道几何才能算剩余跑道，拿不到就在 unavailable 里说明。
 */
export function computeTakeoffMetrics(
  log: Pick<FlightLog, 'points' | 'takeoffData'>,
  runway?: MapRunwayGeometry,
): TakeoffMetrics {
  const result: TakeoffMetrics = { unavailable: {} };
  const takeoff = log.takeoffData;
  if (!takeoff) {
    return markAll(result, 'no_takeoff', [
      'rotationSpeedKt',
      'rotationToLiftoffSec',
      'pitchAt35FtDeg',
      'takeoffStabilityScore',
      'remainingRunwayFt',
    ]);
  }

  const liftoffAt = takeoff.timestamp.getTime();
  const liftoffIndex = indexOfTimestamp(log.points, liftoffAt);

  // ── 抬轮：离地前最后一段地面滑跑里，俯仰首次越过门限的那一点 ──
  const rotation = findRotationPoint(log.points, liftoffIndex);
  if (rotation) {
    result.rotationSpeedKt = round(rotation.airspeed, 1);
    result.rotationToLiftoffSec = round(
      (liftoffAt - rotation.timestamp.getTime()) / 1000,
      1,
    );
  } else {
    // 从空中开始录制、或整段滑跑都没采到，都会落到这里
    result.unavailable.rotationSpeedKt = 'no_rotation';
    result.unavailable.rotationToLiftoffSec = 'no_rotation';
  }

  // ── 35 英尺俯仰角 ──
  const pitchAt35 = findPitchAtAgl(log.points, liftoffIndex, SCREEN_HEIGHT_FT, takeoff.latitude);
  if (pitchAt35 !== undefined) {
    result.pitchAt35FtDeg = round(pitchAt35, 1);
  } else {
    result.unavailable.pitchAt35FtDeg = 'no_agl';
  }

  // ── 起飞稳定性 ──
  const climbWindow = collectClimbWindow(log.points, liftoffIndex);
  if (climbWindow.length >= MIN_SCORE_SAMPLES) {
    result.takeoffStabilityScore = scoreTakeoffStability(climbWindow, takeoff.heading);
  } else {
    result.unavailable.takeoffStabilityScore = 'insufficient_samples';
  }

  // ── 剩余跑道 ──
  const remaining = computeRemainingRunwayFt(
    { latitude: takeoff.latitude, longitude: takeoff.longitude },
    takeoff.heading,
    runway,
  );
  if (remaining !== undefined) result.remainingRunwayFt = round(remaining, 0);
  else result.unavailable.remainingRunwayFt = 'no_runway_geometry';

  return result;
}

/**
 * 找抬轮点：从离地点往回走，最后一个「仍在地面且俯仰已越过门限」的连续段的起点。
 *
 * 往回走而不是从头找，是因为一次录制里可能有多次起降（训练起落航线）——
 * 从头找会拿到第一次起飞的抬轮点。
 */
function findRotationPoint(
  points: readonly FlightLogPoint[],
  liftoffIndex: number,
): FlightLogPoint | undefined {
  if (liftoffIndex <= 0) return undefined;
  let rotation: FlightLogPoint | undefined;
  for (let i = liftoffIndex - 1; i >= 0; i--) {
    const point = points[i];
    // 一旦回退到空中，说明已经越过上一段航程，停止
    if (point.onGround === false) break;
    if (point.pitch >= ROTATION_PITCH_DEG) {
      rotation = point;
      continue;
    }
    // 俯仰掉回门限以下 —— 抬轮就是从这之后开始的
    break;
  }
  return rotation;
}

/**
 * 取达到指定离地高度时的俯仰角（线性插值）。
 *
 * 优先用无线电高度；机型不提供时退回「气压高度 - 离地时的气压高度」——
 * 刚离地的几十秒里气压没时间漂，这个差值在几百英尺内足够准，
 * 否则一大批不给无线电高度的机型永远拿不到这项。
 */
function findPitchAtAgl(
  points: readonly FlightLogPoint[],
  liftoffIndex: number,
  targetAglFt: number,
  _referenceLatitude: number,
): number | undefined {
  if (liftoffIndex < 0 || liftoffIndex >= points.length) return undefined;
  const baseAltitude = points[liftoffIndex].altitude;

  let previous: { agl: number; pitch: number } | undefined;
  for (let i = liftoffIndex; i < points.length; i++) {
    const point = points[i];
    // 又落地了：这一段爬升结束，没到过目标高度
    if (i > liftoffIndex && point.onGround === true) return undefined;

    const agl = aglOf(point, baseAltitude);
    if (agl === undefined) continue;
    if (agl >= targetAglFt) {
      if (!previous || agl === previous.agl) return point.pitch;
      // 在跨过目标高度的两点之间插值
      const ratio = (targetAglFt - previous.agl) / (agl - previous.agl);
      return previous.pitch + (point.pitch - previous.pitch) * ratio;
    }
    previous = { agl, pitch: point.pitch };
  }
  return undefined;
}

/** 离地高度：优先无线电高度，其次用气压高度差 */
function aglOf(point: FlightLogPoint, baseAltitude: number): number | undefined {
  if (point.radioAltitude !== undefined && Number.isFinite(point.radioAltitude)) {
    return point.radioAltitude;
  }
  if (!Number.isFinite(point.altitude) || !Number.isFinite(baseAltitude)) return undefined;
  return point.altitude - baseAltitude;
}

/** 收集离地后到评估高度为止的采样点 */
function collectClimbWindow(
  points: readonly FlightLogPoint[],
  liftoffIndex: number,
): FlightLogPoint[] {
  if (liftoffIndex < 0) return [];
  const baseAltitude = points[liftoffIndex]?.altitude ?? 0;
  const window: FlightLogPoint[] = [];
  for (let i = liftoffIndex; i < points.length; i++) {
    const point = points[i];
    if (i > liftoffIndex && point.onGround === true) break;
    const agl = aglOf(point, baseAltitude);
    if (agl !== undefined && agl > TAKEOFF_WINDOW_AGL_FT) break;
    window.push(point);
  }
  return window;
}

/**
 * 起飞稳定性评分（自拟口径，见文件头声明）。
 *
 * 看三件事：有没有偏离跑道方向、有没有早压坡度、俯仰稳不稳。
 */
export function scoreTakeoffStability(
  window: readonly FlightLogPoint[],
  runwayHeading: number,
): number {
  const headingDeviations = window.map((point) =>
    Math.abs(headingDifference(point.heading, runwayHeading)),
  );
  const headingPenalty = Math.min(
    TAKEOFF_HEADING_PENALTY_CAP,
    rootMeanSquare(headingDeviations) * TAKEOFF_HEADING_PENALTY_PER_DEG,
  );

  const maxBank = Math.max(...window.map((point) => Math.abs(point.roll)), 0);
  const bankPenalty = Math.min(
    TAKEOFF_BANK_PENALTY_CAP,
    maxBank * TAKEOFF_BANK_PENALTY_PER_DEG,
  );

  const pitchPenalty = Math.min(
    TAKEOFF_PITCH_PENALTY_CAP,
    standardDeviation(window.map((point) => point.pitch)) * TAKEOFF_PITCH_PENALTY_PER_DEG,
  );

  return clampScore(100 - headingPenalty - bankPenalty - pitchPenalty);
}

// ──────────────────────────────────────────────────────────────────────────
// 落地
// ──────────────────────────────────────────────────────────────────────────

export function computeLandingMetrics(
  log: Pick<FlightLog, 'points' | 'landingData'>,
  runway?: MapRunwayGeometry,
): LandingMetrics {
  const result: LandingMetrics = { unavailable: {} };
  const landing = log.landingData;
  if (!landing) {
    return markAll(result, 'no_landing', ['approachStabilityScore', 'remainingRunwayFt']);
  }

  const touchdownAt = landing.timestamp.getTime();
  const touchdownIndex = indexOfTimestamp(log.points, touchdownAt);

  const approachWindow = collectApproachWindow(log.points, touchdownIndex);
  if (approachWindow.length >= MIN_SCORE_SAMPLES) {
    result.approachStabilityScore = scoreApproachStability(approachWindow);
  } else {
    result.unavailable.approachStabilityScore = 'insufficient_samples';
  }

  const remaining = computeRemainingRunwayFt(
    { latitude: landing.latitude, longitude: landing.longitude },
    landing.pitch !== undefined ? headingOfTouchdown(log.points, touchdownIndex) : undefined,
    runway,
  );
  if (remaining !== undefined) result.remainingRunwayFt = round(remaining, 0);
  else result.unavailable.remainingRunwayFt = 'no_runway_geometry';

  return result;
}

/** 接地时的航向；接地点本身没记航向时退回最近一个采样点 */
function headingOfTouchdown(
  points: readonly FlightLogPoint[],
  touchdownIndex: number,
): number | undefined {
  const point = points[touchdownIndex];
  return point && Number.isFinite(point.heading) ? point.heading : undefined;
}

/** 收集接地前 1000 ft 到接地这一段 */
function collectApproachWindow(
  points: readonly FlightLogPoint[],
  touchdownIndex: number,
): FlightLogPoint[] {
  if (touchdownIndex <= 0) return [];
  const touchdownAltitude = points[touchdownIndex]?.altitude ?? 0;
  const window: FlightLogPoint[] = [];
  for (let i = touchdownIndex; i >= 0; i--) {
    const point = points[i];
    const agl = aglOf(point, touchdownAltitude);
    if (agl !== undefined && agl > APPROACH_WINDOW_AGL_FT) break;
    window.push(point);
  }
  return window.reverse();
}

/**
 * 进近稳定性评分（判据取自通行的稳定进近准则，扣分权重自拟）。
 *
 * 三件事：下降率有没有超、坡度有没有超、速度稳不稳。
 * 前两项按「超限采样点占比」扣，而不是按峰值 —— 偶尔一帧超限和
 * 一路都在超，是完全不同的两件事。
 */
export function scoreApproachStability(window: readonly FlightLogPoint[]): number {
  const total = window.length;
  if (total === 0) return 100;

  const sinkExceed =
    window.filter((point) => Math.abs(point.verticalSpeed) > STABLE_SINK_RATE_FPM).length / total;
  const bankExceed =
    window.filter((point) => Math.abs(point.roll) > STABLE_BANK_DEG).length / total;

  const sinkPenalty = sinkExceed * APPROACH_SINK_PENALTY_CAP;
  const bankPenalty = bankExceed * APPROACH_BANK_PENALTY_CAP;
  const speedPenalty = Math.min(
    APPROACH_SPEED_PENALTY_CAP,
    standardDeviation(window.map((point) => point.airspeed)) * APPROACH_SPEED_PENALTY_PER_KT,
  );

  return clampScore(100 - sinkPenalty - bankPenalty - speedPenalty);
}

// ──────────────────────────────────────────────────────────────────────────
// 剩余跑道
// ──────────────────────────────────────────────────────────────────────────

/**
 * 从当前点算到跑道尽头还剩多少（英尺）。
 *
 * 方向很关键：先把点投影到跑道中线拿到「距 start 多远」，再看机头朝向与
 * start→end 的夹角决定往哪头算。搞反的话在一条 3000 m 跑道上会把
 * 「还剩 400 m」报成「还剩 2600 m」—— 这个数是用来判断能不能停住的。
 */
export function computeRemainingRunwayFt(
  position: { latitude: number; longitude: number },
  headingDeg: number | undefined,
  runway: MapRunwayGeometry | undefined,
): number | undefined {
  if (!runway || headingDeg === undefined || !Number.isFinite(headingDeg)) return undefined;
  const projection = projectOntoRunway(position, runway);
  if (!projection) return undefined;

  const runwayLengthM = distanceMeters(runway.start, runway.end);
  if (runwayLengthM <= 0) return undefined;

  const runwayBearing = bearingDeg(runway.start, runway.end);
  const towardEnd = Math.abs(headingDifference(headingDeg, runwayBearing)) <= 90;
  const remainingM = towardEnd ? runwayLengthM - projection.alongM : projection.alongM;
  if (remainingM < 0) return 0;
  return remainingM * METERS_TO_FEET;
}

// ──────────────────────────────────────────────────────────────────────────
// 小工具
// ──────────────────────────────────────────────────────────────────────────

/** 两个航向之间的最短夹角，落在 [-180, 180] */
export function headingDifference(a: number, b: number): number {
  return ((((a - b) % 360) + 540) % 360) - 180;
}

function bearingDeg(
  from: { latitude: number; longitude: number },
  to: { latitude: number; longitude: number },
): number {
  const lat1 = (from.latitude * Math.PI) / 180;
  const lat2 = (to.latitude * Math.PI) / 180;
  const dLon = (((to.longitude - from.longitude + 540) % 360) - 180) * (Math.PI / 180);
  const y = Math.sin(dLon) * Math.cos(lat2);
  const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
  return (((Math.atan2(y, x) * 180) / Math.PI) + 360) % 360;
}

function distanceMeters(
  from: { latitude: number; longitude: number },
  to: { latitude: number; longitude: number },
): number {
  const earthRadiusM = 6_371_000;
  const dLat = ((to.latitude - from.latitude) * Math.PI) / 180;
  const dLon = ((((to.longitude - from.longitude + 540) % 360) - 180) * Math.PI) / 180;
  const lat1 = (from.latitude * Math.PI) / 180;
  const lat2 = (to.latitude * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * earthRadiusM * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/** 找时间戳最接近的采样点下标 */
function indexOfTimestamp(points: readonly FlightLogPoint[], at: number): number {
  let best = -1;
  let bestDelta = Number.POSITIVE_INFINITY;
  for (let i = 0; i < points.length; i++) {
    const delta = Math.abs(points[i].timestamp.getTime() - at);
    if (delta < bestDelta) {
      best = i;
      bestDelta = delta;
    }
  }
  return best;
}

function rootMeanSquare(values: readonly number[]): number {
  if (values.length === 0) return 0;
  const sum = values.reduce((total, value) => total + value * value, 0);
  return Math.sqrt(sum / values.length);
}

function standardDeviation(values: readonly number[]): number {
  if (values.length < 2) return 0;
  const mean = values.reduce((total, value) => total + value, 0) / values.length;
  const variance =
    values.reduce((total, value) => total + (value - mean) ** 2, 0) / values.length;
  return Math.sqrt(variance);
}

function clampScore(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.round(Math.min(100, Math.max(0, value)));
}

function round(value: number, digits: number): number {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function markAll<T extends { unavailable: Record<string, MetricUnavailableReason> }>(
  result: T,
  reason: MetricUnavailableReason,
  fields: readonly string[],
): T {
  for (const field of fields) result.unavailable[field] = reason;
  return result;
}
