import { AppLogger } from '../../../core/utils/logger';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import type { MapSelectedAirportDetail } from '../models/map-models';
import { parseAirportDetail } from './map-airport-parser';

const cache = new Map<string, MapSelectedAirportDetail | null>();
const pending = new Map<string, Promise<MapSelectedAirportDetail | null>>();

/** 为自动 PAPI 引导取最近机场跑道，不改动用户手动选中的机场。 */
export async function fetchPapiAirportDetail(
  icao: string,
): Promise<MapSelectedAirportDetail | null> {
  const code = icao.trim().toUpperCase();
  if (code.length === 0) return null;
  if (cache.has(code)) return cache.get(code) ?? null;

  const active = pending.get(code);
  if (active) return active;

  const request = (async () => {
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getAirportByIcao(code);
      const detail = response.objectBody ? parseAirportDetail(response.objectBody, code) : null;
      cache.set(code, detail);
      return detail;
    } catch (error) {
      AppLogger.warning(`[Map] PAPI airport fetch failed for ${code}: ${String(error)}`);
      return null;
    } finally {
      pending.delete(code);
    }
  })();

  pending.set(code, request);
  return request;
}
