import type { MapCoordinate, MapRunwayGeometry } from '../models/map-models';

/**
 * 判断本机当前是否位于某条跑道上（纯几何）
 *
 * ── 为什么不能只算到两端点的距离 ──
 * 跑道是一条**有宽度的线段**，不是点。只算到端点的距离，飞机在跑道中段时
 * 离两端都很远，会判成「不在跑道上」；只算垂直距离，跑道延长线上几海里外的
 * 飞机又会被算进来。正确判据是两条同时成立：
 *   1. 点到线段的垂距 < 跑道半宽；
 *   2. 投影点落在线段范围内（而不是落在延长线上）。
 *
 * 纯计算：不 import Leaflet / React / store，可被直接单测。
 */

/**
 * 跑道半宽（米）。
 *
 * ⚠️ 这是**估计值**：`MapRunwayGeometry` 只有 `lengthM`，没有宽度字段。
 * 民航跑道通常 45 m 宽（半宽 22.5 m），这里取 30 m 略放宽一点，
 * 容忍坐标本身的误差与飞机不完全压中线的情况。
 */
export const DEFAULT_RUNWAY_HALF_WIDTH_M = 30;

/**
 * 判定「在跑道上」的离地高度上限（英尺）。
 *
 * 不设这个门槛的话，从跑道正上方 3000 ft 飞过也会被高亮成「在这条跑道上」。
 * 100 ft 大致覆盖起飞抬轮到刚离地、以及落地拉平的整个过程。
 */
export const RUNWAY_OCCUPANCY_MAX_AGL_FT = 100;

/** 判定输入 */
export interface RunwayOccupancyInput {
  /** 本机位置 */
  position: MapCoordinate;
  /** 无线电高度（英尺）；未知时按「贴地」处理 */
  radioAltitudeFt?: number;
  /** 是否在地面；为 true 时跳过高度门槛 */
  onGround?: boolean;
  /** 半宽覆盖值，默认 DEFAULT_RUNWAY_HALF_WIDTH_M */
  halfWidthM?: number;
}

/** 命中结果 */
export interface RunwayOccupancy {
  /** 命中的跑道标识 */
  ident: string;
  /** 点到跑道中线的垂距（米） */
  offsetM: number;
  /** 沿跑道方向从 start 起算的距离（米） */
  alongM: number;
}

/**
 * 在一组跑道里找出本机正位于其上的那一条。
 *
 * 同时压中多条时取垂距最小的 —— 平行跑道间距通常远大于半宽，
 * 真出现两条都命中，靠得最近的那条才是实际所在。
 */
export function findOccupiedRunway(
  runways: readonly MapRunwayGeometry[],
  input: RunwayOccupancyInput,
): RunwayOccupancy | null {
  if (!isUsableCoordinate(input.position)) return null;
  if (!isWithinGroundBand(input)) return null;

  const halfWidth = input.halfWidthM ?? DEFAULT_RUNWAY_HALF_WIDTH_M;
  let best: RunwayOccupancy | null = null;

  for (const runway of runways) {
    if (!isUsableCoordinate(runway.start) || !isUsableCoordinate(runway.end)) continue;
    const hit = projectOntoRunway(input.position, runway);
    if (hit === null) continue;
    if (hit.offsetM > halfWidth) continue;
    if (best === null || hit.offsetM < best.offsetM) {
      best = { ident: runway.ident, offsetM: hit.offsetM, alongM: hit.alongM };
    }
  }
  return best;
}

/** 高度门槛：在地面直接算数；有无线电高度就看它；都没有则按贴地处理 */
function isWithinGroundBand(input: RunwayOccupancyInput): boolean {
  if (input.onGround === true) return true;
  const agl = input.radioAltitudeFt;
  if (agl === undefined || !Number.isFinite(agl)) {
    // 没有无线电高度时不能一票否决：很多机型压根不提供这个量，
    // 否决了就等于这个功能对它们永远不生效。
    return input.onGround !== false;
  }
  return agl <= RUNWAY_OCCUPANCY_MAX_AGL_FT;
}

/**
 * 把点投影到跑道线段上。
 *
 * 投影落在线段之外返回 null（那是延长线，不算在跑道上）。
 */
export function projectOntoRunway(
  point: MapCoordinate,
  runway: Pick<MapRunwayGeometry, 'start' | 'end'>,
): { offsetM: number; alongM: number } | null {
  // 先换算到以跑道起点为原点的局部平面（米）。单个机场跨度只有几公里，
  // 这个尺度上等距圆柱投影的误差远小于跑道半宽，够用。
  const origin = runway.start;
  const start = toLocalMeters(origin, runway.start);
  const end = toLocalMeters(origin, runway.end);
  const target = toLocalMeters(origin, point);

  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const lengthSquared = dx * dx + dy * dy;
  // 两端点重合：数据坏了，别除零
  if (lengthSquared <= 0) return null;

  const t = ((target.x - start.x) * dx + (target.y - start.y) * dy) / lengthSquared;
  if (t < 0 || t > 1) return null;

  const projX = start.x + t * dx;
  const projY = start.y + t * dy;
  const offsetM = Math.hypot(target.x - projX, target.y - projY);
  const alongM = t * Math.sqrt(lengthSquared);
  return { offsetM, alongM };
}

const METERS_PER_DEGREE_LAT = 111_320;

/**
 * 经纬度 → 以 origin 为原点的局部平面坐标（米）。
 *
 * 经差先跨 180° 归一 —— 滑行道路网那套曾经栽在这上面：不归一的话，
 * 经线两侧的两个点会被算成绕地球一圈那么远。
 */
function toLocalMeters(origin: MapCoordinate, point: MapCoordinate): { x: number; y: number } {
  const dLat = point.latitude - origin.latitude;
  const dLon = normalizeLongitudeDelta(point.longitude - origin.longitude);
  const latScale = Math.cos((origin.latitude * Math.PI) / 180);
  return {
    x: dLon * METERS_PER_DEGREE_LAT * latScale,
    y: dLat * METERS_PER_DEGREE_LAT,
  };
}

/** 经差归一到 [-180, 180) */
export function normalizeLongitudeDelta(delta: number): number {
  return ((((delta + 180) % 360) + 360) % 360) - 180;
}

/** 坐标可用性：(0,0) 视为「没有数据」而不是几内亚湾 */
function isUsableCoordinate(coordinate: MapCoordinate | undefined): coordinate is MapCoordinate {
  if (!coordinate) return false;
  const { latitude, longitude } = coordinate;
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return false;
  if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return false;
  return latitude !== 0 || longitude !== 0;
}
