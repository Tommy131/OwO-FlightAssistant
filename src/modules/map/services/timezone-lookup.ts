/**
 * 经纬度 → 时区的取数适配器
 *
 * IO 在这里，格式化在 `local-clock.ts`（纯函数、有单测）。
 *
 * 中间件按 0.1° 格点长期缓存，所以同一片区域反复查也只有第一次真的打上游。
 * 本机在同一格里飞的时候连这一次请求都不该发 —— 由调用方拿
 * `zoneCellKey()` 自行判断，见 `local-clock.ts`。
 */

import { AppLogger } from '../../../core/utils/logger';
import { pickDouble, pickString } from '../../../core/utils/parse-utils';
import type { JsonMap } from '../../../core/utils/parse-utils';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import type { ZoneInfo } from './local-clock';

/**
 * 查询给定坐标的时区。
 *
 * 查不到一律返回 undefined，由调用方保持「时区未知」的显示，
 * 而不是默默按 UTC 当成当地时间 —— 那会给出一个看着很正常的错时间。
 */
export async function lookupZone(
  latitude: number,
  longitude: number,
): Promise<ZoneInfo | undefined> {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return undefined;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return undefined;

  try {
    await MiddlewareHttpService.init();
    const response = await MiddlewareHttpService.getTimezoneAt(latitude, longitude);
    const body = response.objectBody;
    if (!body) return undefined;
    return parseZone(body, latitude, longitude);
  } catch (e) {
    AppLogger.info(`[Map] timezone lookup failed: ${String(e)}`);
    return undefined;
  }
}

/** 解析时区响应；没有可用的时区名就当查不到 */
export function parseZone(
  body: JsonMap,
  fallbackLatitude: number,
  fallbackLongitude: number,
): ZoneInfo | undefined {
  const timezone = (pickString(body, ['timezone', 'Timezone']) ?? '').trim();
  if (timezone.length === 0) return undefined;

  return {
    timezone,
    abbreviation: (pickString(body, ['abbreviation', 'Abbreviation']) ?? '').trim(),
    utcOffsetSeconds: pickDouble(body, ['utc_offset_seconds', 'UTCOffsetSeconds']) ?? 0,
    latitude: pickDouble(body, ['latitude', 'Latitude']) ?? fallbackLatitude,
    longitude: pickDouble(body, ['longitude', 'Longitude']) ?? fallbackLongitude,
  };
}
