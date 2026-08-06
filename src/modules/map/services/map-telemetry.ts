/**
 * 从飞行遥测派生地图要素（纯函数）
 *
 * 两件事：把飞机位置累积成航迹、把快照里的各类机场归并成地图标记。
 * 原先内嵌在 `map-store.ts` 里，航迹那段还依赖模块级可变量 `ctx.lastRoutePoint`，
 * 没法单独调用。这里把「上一个点」与「当前时间」都改成入参，函数就纯了。
 */

import { calculateDistanceNm } from '../../../core/utils/parse-utils';
import type { FlightDataSnapshot } from '../../common/models/common-models';
import type {
  MapAircraftState,
  MapAirportMarker,
  MapCoordinate,
  MapRoutePoint,
} from '../models/map-models';
import { isValidCoordinate } from './map-response-parsers';

/** 距上一点不足此距离就不记新点，避免停机时把航迹刷爆 */
export const MIN_ROUTE_POINT_DISTANCE_M = 30;

const METERS_PER_NM = 1852;

/** 两点间大圆距离（米）—— 航迹与 AI 机去重都按米判定，换算收在一处 */
export function distanceInMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  return calculateDistanceNm(lat1, lon1, lat2, lon2) * METERS_PER_NM;
}

export interface RouteAppendResult {
  /** 新的航迹（未追加时原样返回，引用不变，便于 store 跳过重渲染） */
  readonly route: MapRoutePoint[];
  /** 追加后的「上一个点」，调用方需存回去 */
  readonly lastPoint: MapCoordinate;
  readonly appended: boolean;
}

/**
 * 航迹追加：距上一点足够远才记，并裁剪到最大点数。
 *
 * `lastPoint` 传 null 表示还没有航迹，第一个点无条件记录。
 * `now` 可注入，方便测试断言时间戳。
 */
export function appendRoutePoint(
  route: MapRoutePoint[],
  aircraft: MapAircraftState,
  lastPoint: MapCoordinate | null,
  now: Date = new Date(),
): RouteAppendResult {
  const position = aircraft.position;

  if (lastPoint) {
    const meters = distanceInMeters(
      lastPoint.latitude,
      lastPoint.longitude,
      position.latitude,
      position.longitude,
    );
    if (meters < MIN_ROUTE_POINT_DISTANCE_M) {
      return { route, lastPoint, appended: false };
    }
  }

  const next: MapRoutePoint[] = [
    ...route,
    {
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: aircraft.altitude,
      groundSpeed: aircraft.groundSpeed,
      timestamp: now,
    },
  ];

  // 不设点数上限：300ms 轮询下巡航时每点间隔约 69m，4000 点只够 20 分钟，
  // 长航线会把前半程整段丢掉。抑制刷点靠的是上面的最小间距过滤，不是砍历史。
  // 代价是航迹会一直变长，所以渲染侧必须增量追加而非整条重建（见 map-canvas）。
  return { route: next, lastPoint: position, appended: true };
}

/**
 * 把快照里的起飞/目的/备降/最近/推荐机场归并成地图标记。
 *
 * 同一 ICAO 只留第一个 —— 先加入的优先级更高（起飞地 > 目的地 > 备降 > 最近 > 推荐），
 * 所以「目的地恰好也是最近机场」时它保持 primary，不会被后面的降级覆盖。
 */
export function buildAirportsFromSnapshot(snapshot: FlightDataSnapshot): MapAirportMarker[] {
  const result: MapAirportMarker[] = [];
  const seen = new Set<string>();

  const push = (
    airport: { icaoCode: string; name: string; latitude: number; longitude: number } | undefined,
    isPrimary: boolean,
  ) => {
    if (!airport) return;
    const code = airport.icaoCode.trim().toUpperCase();
    if (code.length === 0 || seen.has(code)) return;
    if (!isValidCoordinate(airport.latitude, airport.longitude)) return;
    seen.add(code);
    result.push({
      code,
      name: airport.name,
      position: { latitude: airport.latitude, longitude: airport.longitude },
      isPrimary,
    });
  };

  push(snapshot.departureAirport, true);
  push(snapshot.destinationAirport, true);
  push(snapshot.alternateAirport, true);
  push(snapshot.nearestAirport, false);
  for (const airport of snapshot.suggestedAirports) push(airport, false);

  return result;
}
