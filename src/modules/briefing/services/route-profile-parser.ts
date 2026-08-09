/**
 * 航路气象剖面解析与派生计算（纯函数）
 *
 * 后端已经做过单位换算与缺测剔除，这里只做「字段翻译 + 图表要用的派生量」。
 *
 * 有一条贯穿全文件：**缺数据就是缺数据，不补零**。
 * 一条画在图上的「0 kt / 0 °C」看不出是没有数据，
 * 比少画一个点危险得多 —— 用户会当成真值去算配平。
 */

import { pickDouble, toJsonMap, toText } from '../../../core/utils/parse-utils';
import { isValidCoordinate } from '../../../core/utils/coordinates';
import type {
  RouteProfile,
  RouteProfileLevel,
  RouteProfileSample,
} from '../models/route-profile-models';

/** 解析一层 */
function parseLevel(raw: unknown): RouteProfileLevel | null {
  const map = toJsonMap(raw);
  if (!map) return null;

  const pressureHPa = pickDouble(map, ['pressure_hpa']);
  const altitudeFt = pickDouble(map, ['altitude_ft']);
  const temperatureC = pickDouble(map, ['temperature_c']);
  const windSpeedKt = pickDouble(map, ['wind_speed_kt']);
  const windDirectionDeg = pickDouble(map, ['wind_direction_deg']);

  // 五项缺一不可：图上的一个点同时要用到高度、温度和风
  if (
    pressureHPa === undefined ||
    altitudeFt === undefined ||
    temperatureC === undefined ||
    windSpeedKt === undefined ||
    windDirectionDeg === undefined
  ) {
    return null;
  }
  // 高度必须为正：0 或负数说明上游那一层根本没算出来
  if (!(altitudeFt > 0) || windSpeedKt < 0) return null;

  return {
    pressureHPa,
    altitudeFt,
    temperatureC,
    windSpeedKt,
    windDirectionDeg: ((windDirectionDeg % 360) + 360) % 360,
  };
}

/** 解析一个采样点 */
export function parseRouteProfileSample(raw: unknown): RouteProfileSample | null {
  const map = toJsonMap(raw);
  if (!map) return null;

  const latitude = pickDouble(map, ['latitude']);
  const longitude = pickDouble(map, ['longitude']);
  if (latitude === undefined || longitude === undefined) return null;
  if (!isValidCoordinate(latitude, longitude)) return null;

  const rawLevels = Array.isArray(map.levels) ? map.levels : [];
  const levels = rawLevels
    .map(parseLevel)
    .filter((level): level is RouteProfileLevel => level !== null)
    // 按高度自下而上排序：上游的顺序是按气压层给的，别指望它总是有序
    .sort((a, b) => a.altitudeFt - b.altitudeFt);

  if (levels.length === 0) return null;

  const timeUtc = toText(map.time_utc).trim();
  return {
    index: pickDouble(map, ['index']) ?? 0,
    latitude,
    longitude,
    timeUtc: timeUtc.length > 0 ? timeUtc : undefined,
    levels,
  };
}

/** 解析整份剖面 */
export function parseRouteProfile(raw: unknown): RouteProfile | null {
  const map = toJsonMap(raw);
  if (!map) return null;

  const rawSamples = Array.isArray(map.samples) ? map.samples : [];
  const samples = rawSamples
    .map(parseRouteProfileSample)
    .filter((sample): sample is RouteProfileSample => sample !== null)
    // 按航路顺序排：横轴是沿航线的进程，乱序会把剖面画成一团
    .sort((a, b) => a.index - b.index);

  if (samples.length === 0) return null;
  return { samples, cached: map.cached === true };
}

/**
 * 取某个采样点在指定高度上的气象。
 *
 * 巡航高度基本不会正好落在某个气压层上，所以在相邻两层之间线性插值。
 * 风向要按**最短弧**插值：350° 到 010° 之间是 20°，直接平均会得到 180°，
 * 正好指反 —— 顺风会被读成顶风。
 */
export function interpolateAtAltitude(
  sample: RouteProfileSample,
  altitudeFt: number,
): RouteProfileLevel | null {
  const levels = sample.levels;
  if (levels.length === 0) return null;
  if (levels.length === 1) return levels[0];

  // 超出上下界就取最近的那一层，不做外推 —— 外推出来的高空风没有依据
  if (altitudeFt <= levels[0].altitudeFt) return levels[0];
  const top = levels[levels.length - 1];
  if (altitudeFt >= top.altitudeFt) return top;

  let lower = levels[0];
  let upper = top;
  for (let i = 1; i < levels.length; i += 1) {
    if (levels[i].altitudeFt >= altitudeFt) {
      lower = levels[i - 1];
      upper = levels[i];
      break;
    }
  }

  const span = upper.altitudeFt - lower.altitudeFt;
  const ratio = span > 0 ? (altitudeFt - lower.altitudeFt) / span : 0;
  const lerp = (a: number, b: number) => a + (b - a) * ratio;

  // 最短弧插值：先把差值折进 (-180, 180]
  const delta = ((upper.windDirectionDeg - lower.windDirectionDeg) % 360 + 540) % 360 - 180;
  const direction = ((lower.windDirectionDeg + delta * ratio) % 360 + 360) % 360;

  return {
    pressureHPa: ratio < 0.5 ? lower.pressureHPa : upper.pressureHPa,
    altitudeFt,
    temperatureC: lerp(lower.temperatureC, upper.temperatureC),
    windSpeedKt: lerp(lower.windSpeedKt, upper.windSpeedKt),
    windDirectionDeg: direction,
  };
}

/**
 * 顺风分量（kt）：正为顺风，负为顶风。
 *
 * 气象上的风向是**风从哪来**，航向是**往哪去**，两者差 180° 才是顺风。
 * 这个符号搞反会让整段航程的油耗估算朝相反方向偏。
 */
export function tailwindComponentKt(
  windDirectionDeg: number,
  windSpeedKt: number,
  trackDeg: number,
): number {
  const angle = ((windDirectionDeg - trackDeg) * Math.PI) / 180;
  return -windSpeedKt * Math.cos(angle);
}
