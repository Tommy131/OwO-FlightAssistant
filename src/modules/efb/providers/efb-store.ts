import { create } from 'zustand';

import { AppLogger } from '../../../core/utils/logger';
import { pickDouble, pickString, toJsonMap, type JsonMap } from '../../../core/utils/parse-utils';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';

/**
 * EFB 近场机场与气象 store
 *
 * 数据来自中间件的两个新接口：
 *   - `/api/v1/airports/nearby` 取近场机场（后端顺手预热它们的详情）
 *   - `/api/v1/weather/metar-batch` 一次取回全部 METAR
 *
 * ── 为什么用批量接口 ──
 * 逐个机场串行打 `/metar/{icao}` 的话，五个机场就是五个来回、首屏要等好几秒，
 * 还容易被 NOAA 限流。批量接口默认只读中间件缓存并对未命中的发起后台预热，
 * 首帧一定很快，缺的那几个下一轮补齐。
 */

/** 近场机场（含该场最新 METAR 摘要） */
export interface NearbyAirport {
  icao: string;
  name: string;
  latitude: number;
  longitude: number;
  distanceNm: number;
  /** METAR 原文；尚未取到时为 undefined */
  rawMetar?: string;
  windText?: string;
  visibilityText?: string;
  altimeterText?: string;
  temperatureText?: string;
  /** 该条 METAR 的缓存新鲜度：fresh / stale / miss */
  freshness?: string;
}

/** 两次自动刷新之间的最小间隔 */
const REFRESH_MIN_INTERVAL_MS = 60_000;
/** 位移超过该距离就重新拉近场机场 */
const REFRESH_MOVE_THRESHOLD_NM = 25;

interface EfbState {
  airports: NearbyAirport[];
  loading: boolean;
  errorMessage?: string;
  lastUpdatedAt?: number;

  /** 按当前位置刷新近场机场与气象；节流由 store 内部处理 */
  refresh: (input: {
    latitude: number;
    longitude: number;
    /** 额外要看气象的机场（起飞/目的/备降），会并入批量查询 */
    extraIcaos?: readonly string[];
    /** 忽略节流，用户手动点刷新时传 true */
    force?: boolean;
  }) => Promise<void>;
  reset: () => void;
}

/** 节流状态不参与渲染，放在 store 外 */
let lastRefreshAt = 0;
let lastLat: number | null = null;
let lastLon: number | null = null;
let inFlight = false;

export const useEfbStore = create<EfbState>((set) => ({
  airports: [],
  loading: false,

  async refresh({ latitude, longitude, extraIcaos = [], force = false }) {
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return;
    if (inFlight) return;

    const now = Date.now();
    if (!force && lastRefreshAt > 0) {
      const movedNm =
        lastLat === null || lastLon === null
          ? Number.POSITIVE_INFINITY
          : haversineNm(lastLat, lastLon, latitude, longitude);
      if (now - lastRefreshAt < REFRESH_MIN_INTERVAL_MS && movedNm < REFRESH_MOVE_THRESHOLD_NM) {
        return;
      }
    }

    inFlight = true;
    set({ loading: true });
    try {
      await MiddlewareHttpService.init();
      const nearbyResponse = await MiddlewareHttpService.getNearbyAirports({
        latitude,
        longitude,
        radiusNm: 150,
        limit: 5,
      });
      const airports = parseNearbyAirports(nearbyResponse.objectBody);

      const icaos = dedupeIcaos([...airports.map((item) => item.icao), ...extraIcaos]);
      const metarByIcao =
        icaos.length > 0 ? await fetchMetarBatch(icaos) : new Map<string, MetarSummary>();
      const merged: NearbyAirport[] = airports.map((airport) => ({
        ...airport,
        ...(metarByIcao.get(airport.icao) ?? {}),
      }));

      lastRefreshAt = now;
      lastLat = latitude;
      lastLon = longitude;
      set({ airports: merged, loading: false, errorMessage: undefined, lastUpdatedAt: now });
    } catch (e) {
      AppLogger.warning(`EFB nearby refresh failed: ${String(e)}`);
      set({ loading: false, errorMessage: String(e) });
    } finally {
      inFlight = false;
    }
  },

  reset() {
    lastRefreshAt = 0;
    lastLat = null;
    lastLon = null;
    set({ airports: [], loading: false, errorMessage: undefined, lastUpdatedAt: undefined });
  },
}));

// ──────────────────────────────────────────────────────────────────────────
// 解析
// ──────────────────────────────────────────────────────────────────────────

function parseNearbyAirports(body: JsonMap | null): NearbyAirport[] {
  const rows = Array.isArray(body?.airports) ? body.airports : [];
  const out: NearbyAirport[] = [];
  for (const row of rows) {
    const item = toJsonMap(row);
    if (!item) continue;
    const icao = pickString(item, ['icao', 'ICAO'])?.toUpperCase();
    if (!icao) continue;
    out.push({
      icao,
      name: pickString(item, ['name', 'Name']) ?? '',
      latitude: pickDouble(item, ['latitude', 'lat', 'Lat']) ?? 0,
      longitude: pickDouble(item, ['longitude', 'lon', 'Lon']) ?? 0,
      distanceNm: pickDouble(item, ['distance_nm', 'distanceNm']) ?? 0,
    });
  }
  return out;
}

type MetarSummary = Pick<
  NearbyAirport,
  'rawMetar' | 'windText' | 'visibilityText' | 'altimeterText' | 'temperatureText' | 'freshness'
>;

async function fetchMetarBatch(icaos: string[]): Promise<Map<string, MetarSummary>> {
  const out = new Map<string, MetarSummary>();
  const response = await MiddlewareHttpService.getMetarBatch(icaos);
  const items = Array.isArray(response.objectBody?.items) ? response.objectBody.items : [];
  for (const row of items) {
    const item = toJsonMap(row);
    if (!item) continue;
    const icao = pickString(item, ['icao'])?.toUpperCase();
    if (!icao) continue;
    // available=false 表示后端也还没拿到，别把空串当成「该场无报文」
    if (item.available !== true) continue;
    const cache = toJsonMap(item.cache);
    out.set(icao, {
      rawMetar: pickString(item, ['raw_metar']),
      windText: pickString(item, ['display_wind']),
      visibilityText: pickString(item, ['display_visibility']),
      altimeterText: pickString(item, ['display_altimeter']),
      temperatureText: pickString(item, ['display_temperature']),
      freshness: cache ? pickString(cache, ['freshness']) : undefined,
    });
  }
  return out;
}

function dedupeIcaos(values: readonly string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const raw of values) {
    const icao = raw.trim().toUpperCase();
    if (icao.length !== 4 || seen.has(icao)) continue;
    seen.add(icao);
    out.push(icao);
  }
  return out;
}

/** 大圆距离（海里），仅用于节流判断 */
function haversineNm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const earthRadiusNm = 3440.065;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * earthRadiusNm * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
