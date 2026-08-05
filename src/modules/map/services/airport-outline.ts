import type { MapCoordinate, MapSelectedAirportDetail } from '../models/map-models';

/**
 * 机场轮廓计算
 *
 * 后端（以及桌面版）都不提供机场边界多边形，只有跑道端点与停机位坐标。
 * 这里用这些已知点算**凸包**并向外扩一圈，得到一个能包住全部跑道与机坪的
 * 近似轮廓 —— 用于在地图上圈出机场范围。
 *
 * 注意：这是几何近似，不是权威的机场边界（AIP boundary）。
 * 若后端将来提供真实边界，应优先使用后端数据。
 */

/** 轮廓向外扩张的距离（米），确保跑道两侧不被切到 */
const OUTLINE_PADDING_M = 260;

/**
 * 由选中机场的跑道与停机位算出轮廓多边形
 * @returns 顶点数组；点太少（无法构成面）时返回 null
 */
export function computeAirportOutline(
  detail: MapSelectedAirportDetail,
): MapCoordinate[] | null {
  const points: MapCoordinate[] = [];

  for (const runway of detail.runwayGeometries) {
    points.push(runway.start, runway.end);
  }
  for (const spot of detail.parkingSpots) {
    points.push(spot.position);
  }

  // 少于 3 个点构不成多边形
  if (points.length < 3) return null;

  const hull = convexHull(points);
  if (hull.length < 3) return null;

  return expandPolygon(hull, OUTLINE_PADDING_M);
}

/**
 * Andrew monotone chain 凸包
 *
 * 在机场这个尺度上（几公里），直接把经纬度当平面坐标用的误差可以忽略，
 * 不必投影到平面直角坐标系。
 */
function convexHull(points: MapCoordinate[]): MapCoordinate[] {
  const sorted = [...points].sort(
    (a, b) => a.longitude - b.longitude || a.latitude - b.latitude,
  );

  // 去重，避免重合点导致叉积为 0 卡住
  const unique: MapCoordinate[] = [];
  for (const point of sorted) {
    const last = unique[unique.length - 1];
    if (last && last.longitude === point.longitude && last.latitude === point.latitude) {
      continue;
    }
    unique.push(point);
  }
  if (unique.length < 3) return unique;

  const cross = (o: MapCoordinate, a: MapCoordinate, b: MapCoordinate) =>
    (a.longitude - o.longitude) * (b.latitude - o.latitude) -
    (a.latitude - o.latitude) * (b.longitude - o.longitude);

  const lower: MapCoordinate[] = [];
  for (const point of unique) {
    while (
      lower.length >= 2 &&
      cross(lower[lower.length - 2], lower[lower.length - 1], point) <= 0
    ) {
      lower.pop();
    }
    lower.push(point);
  }

  const upper: MapCoordinate[] = [];
  for (let i = unique.length - 1; i >= 0; i--) {
    const point = unique[i];
    while (
      upper.length >= 2 &&
      cross(upper[upper.length - 2], upper[upper.length - 1], point) <= 0
    ) {
      upper.pop();
    }
    upper.push(point);
  }

  // 首尾点在两条链里各出现一次，去掉重复
  lower.pop();
  upper.pop();
  return [...lower, ...upper];
}

/**
 * 把多边形各顶点沿「质心 → 顶点」方向外推固定距离
 *
 * 比逐边偏移（需要处理自交）简单得多，在凸包上效果足够好。
 */
function expandPolygon(polygon: MapCoordinate[], paddingM: number): MapCoordinate[] {
  const centroidLat =
    polygon.reduce((sum, point) => sum + point.latitude, 0) / polygon.length;
  const centroidLon =
    polygon.reduce((sum, point) => sum + point.longitude, 0) / polygon.length;

  // 纬度 1° ≈ 111320m；经度按纬度收缩
  const metersPerDegLat = 111_320;
  const metersPerDegLon = 111_320 * Math.cos((centroidLat * Math.PI) / 180);

  return polygon.map((point) => {
    const dLatM = (point.latitude - centroidLat) * metersPerDegLat;
    const dLonM = (point.longitude - centroidLon) * metersPerDegLon;
    const distance = Math.hypot(dLatM, dLonM);

    // 顶点与质心重合时无方向可推，原样返回
    if (distance < 1e-6) return point;

    const scale = (distance + paddingM) / distance;
    return {
      latitude: centroidLat + (dLatM * scale) / metersPerDegLat,
      longitude: centroidLon + (dLonM * scale) / metersPerDegLon,
    };
  });
}
