/**
 * 地图几何基元（纯函数）
 *
 * 这几个函数原先散在 `approach-beam.ts` 与 `papi-guidance.ts` 里：`bearingDeg`
 * 两处逐字符相同、`EARTH_RADIUS_NM` 各写一份，而 `holding-geometry` 为了拿
 * `destination` 得去 import「进近波束」—— 名字和用途对不上。统一收到这里。
 *
 * 与 `core/utils/parse-utils.ts` 里的 `calculateDistanceNm` 分工：那边收
 * 四个标量（lat, lon, lat, lon），给非地图模块用；这边收 `MapCoordinate`，
 * 给地图几何用。两套签名各有调用场景，不强行合并 —— 但 Haversine 的**算式本身
 * 只保留一份**（这里委托过去），否则改了一处漏另一处，两边会悄悄给出不同的距离。
 */

import { calculateDistanceNm } from '../../../core/utils/parse-utils';
import type { MapCoordinate } from '../models/map-models';

/** 地球平均半径（海里） */
export const EARTH_RADIUS_NM = 3440.065;

/**
 * 从某点按方位角走一段距离
 *
 * 大圆公式；这个尺度（几十海里）用平面近似也行，但大圆写起来一样简单，
 * 高纬度时还不会变形。
 */
export function destination(
  from: MapCoordinate,
  bearing: number,
  distanceNm: number,
): MapCoordinate {
  const angular = distanceNm / EARTH_RADIUS_NM;
  const theta = (bearing * Math.PI) / 180;
  const lat1 = (from.latitude * Math.PI) / 180;
  const lon1 = (from.longitude * Math.PI) / 180;

  const lat2 = Math.asin(
    Math.sin(lat1) * Math.cos(angular) + Math.cos(lat1) * Math.sin(angular) * Math.cos(theta),
  );
  const lon2 =
    lon1 +
    Math.atan2(
      Math.sin(theta) * Math.sin(angular) * Math.cos(lat1),
      Math.cos(angular) - Math.sin(lat1) * Math.sin(lat2),
    );

  return {
    latitude: (lat2 * 180) / Math.PI,
    // 归一化到 -180..180，跨日界线时才不会画出一条横穿地图的线
    longitude: (((lon2 * 180) / Math.PI + 540) % 360) - 180,
  };
}

/** 两点间的大圆方位角（真方位，0–360） */
export function bearingDeg(from: MapCoordinate, to: MapCoordinate): number {
  const lat1 = (from.latitude * Math.PI) / 180;
  const lat2 = (to.latitude * Math.PI) / 180;
  const deltaLon = ((to.longitude - from.longitude) * Math.PI) / 180;
  const y = Math.sin(deltaLon) * Math.cos(lat2);
  const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(deltaLon);
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

/** 两点间的大圆距离（海里，Haversine） */
export function distanceInNm(from: MapCoordinate, to: MapCoordinate): number {
  return calculateDistanceNm(from.latitude, from.longitude, to.latitude, to.longitude);
}
