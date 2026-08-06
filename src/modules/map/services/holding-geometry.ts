import type { MapCoordinate, MapHoldingPattern } from '../models/map-models';
import { destination } from './geo';

/**
 * 等待航线几何
 *
 * 把公布的等待航线参数（定位点、入航道、转向、腿长）还原成地图上那个跑道形
 * 的环圈。标准形状：定位点是**入航段的终点**，飞过定位点后转 180°、
 * 飞一段平行的出航边、再转 180° 回到入航道上。
 *
 * ── 尺寸怎么来的 ──
 * 转弯半径按标准转弯率（3°/秒）：r(NM) = V(kt) / (20π)。
 * 直线段：公布了时间就用 V × 分钟，公布了距离就直接用距离。
 * 速度优先用公布的最大速度，没有就按 ICAO 常用的等待速度取默认值。
 *
 * ⚠️ 画出来的是**航线本身**，不是等待保护区（保护区还要叠加风修正、
 * 导航容差等，范围大得多）。真实运行以 AIP 为准。
 */

/** 没有公布最大速度时的默认等待速度（节） */
const DEFAULT_HOLD_SPEED_KT = 230;

/** 公布了时间但没给速度时，一分钟大约飞多远由速度决定；这里限定半径范围 */
const MIN_TURN_RADIUS_NM = 0.8;
const MAX_TURN_RADIUS_NM = 6;

/** 每个 180° 转弯画多少段 */
const TURN_SEGMENTS = 18;

export interface HoldingGeometry {
  readonly fix: string;
  /** 闭合的航线路径 */
  readonly path: MapCoordinate[];
  /** 定位点位置 */
  readonly fixPosition: MapCoordinate;
  readonly inboundCourse: number;
  readonly turnDirection: 'L' | 'R';
  readonly legNm: number;
  readonly radiusNm: number;
}

/**
 * 由公布参数生成等待航线路径
 *
 * @returns 参数不足以成形时返回 null
 */
export function buildHoldingGeometry(hold: MapHoldingPattern): HoldingGeometry | null {
  const fixPosition = { latitude: hold.lat, longitude: hold.lon };
  if (!Number.isFinite(hold.lat) || !Number.isFinite(hold.lon)) return null;

  const speedKt = hold.maxSpeedKt && hold.maxSpeedKt > 0 ? hold.maxSpeedKt : DEFAULT_HOLD_SPEED_KT;
  // 标准转弯率 3°/s 走完 360° 要 120 秒，于是 r = V·120/3600/(2π) = V/(20π)
  const radiusNm = clamp(speedKt / (20 * Math.PI), MIN_TURN_RADIUS_NM, MAX_TURN_RADIUS_NM);

  const legNm =
    hold.legDistanceNm && hold.legDistanceNm > 0
      ? hold.legDistanceNm
      : (hold.legMinutes && hold.legMinutes > 0 ? hold.legMinutes : 1) * (speedKt / 60);

  const inbound = hold.inboundCourse;
  if (!Number.isFinite(inbound)) return null;
  const right = hold.turnDirection !== 'L';

  // 出航边在入航边的哪一侧：右转等待，转弯把飞机带到入航道右侧
  const sideBearing = (inbound + (right ? 90 : -90) + 360) % 360;
  // 入航段起点：沿入航道反方向退一个腿长
  const inboundStart = destination(fixPosition, (inbound + 180) % 360, legNm);
  // 出航边与入航边平行、相距两个转弯半径
  const outboundStart = destination(fixPosition, sideBearing, radiusNm * 2);
  const outboundEnd = destination(inboundStart, sideBearing, radiusNm * 2);

  const path: MapCoordinate[] = [];
  // 入航段：起点 → 定位点
  path.push(inboundStart, fixPosition);
  // 定位点处的 180° 转弯，圆心在侧向一个半径处
  path.push(...turnArc(fixPosition, sideBearing, radiusNm, inbound, right));
  // 出航段
  path.push(outboundStart, outboundEnd);
  // 出航末端再转 180° 回到入航道
  path.push(...turnArc(outboundEnd, sideBearing, radiusNm, (inbound + 180) % 360, right));
  path.push(inboundStart);

  return {
    fix: hold.fix,
    path,
    fixPosition,
    inboundCourse: inbound,
    turnDirection: right ? 'R' : 'L',
    legNm,
    radiusNm,
  };
}

/**
 * 生成一个 180° 转弯的圆弧
 *
 * @param entry        进入转弯的位置
 * @param centerBearing 从进入点看圆心的方位
 * @param radiusNm     转弯半径
 * @param heading      进入转弯时的航向
 * @param right        是否右转
 */
function turnArc(
  entry: MapCoordinate,
  centerBearing: number,
  radiusNm: number,
  heading: number,
  right: boolean,
): MapCoordinate[] {
  const center = destination(entry, centerBearing, radiusNm);
  // 从圆心看进入点的方位
  const startBearing = (centerBearing + 180) % 360;
  const points: MapCoordinate[] = [];
  for (let i = 1; i <= TURN_SEGMENTS; i++) {
    const swept = (180 * i) / TURN_SEGMENTS;
    const bearing = right ? startBearing + swept : startBearing - swept;
    points.push(destination(center, (bearing + 360) % 360, radiusNm));
  }
  // heading 只用于表达语义，几何上由 centerBearing 决定，这里不再参与计算
  void heading;
  return points;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}
