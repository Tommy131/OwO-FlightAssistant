import { toJsonMap, type JsonMap } from '../../../core/utils/parse-utils';

/**
 * 收藏机场的数据模型（纯类型与纯函数）
 *
 * 与 store 分开放，是为了让 `airport_search/models` 也能引用这个类型而
 * 不被迫拖进 zustand —— 「models 不得依赖框架」是本项目的架构门禁之一。
 * 状态与持久化在 `providers/airport-favorites-store.ts`。
 */

/** 完整 ICAO：4 位字母/数字 */
const ICAO_PATTERN = /^[A-Z0-9]{4}$/;

export function normalizeIcao(input: string): string {
  return input.trim().toUpperCase();
}

export function isValidIcao(input: string): boolean {
  return ICAO_PATTERN.test(normalizeIcao(input));
}

/** 一条收藏记录 */
export interface FavoriteAirportEntry {
  icao: string;
  name?: string;
  latitude?: number;
  longitude?: number;
}

/** 从持久化的 JSON 还原一条收藏；结构不对的返回 null 由调用方丢弃 */
export function favoriteFromJson(raw: unknown): FavoriteAirportEntry | null {
  const json: JsonMap | null = toJsonMap(raw);
  if (!json) return null;
  const icao = typeof json.icao === 'string' ? json.icao.toUpperCase() : '';
  if (!isValidIcao(icao)) return null;
  return {
    icao,
    name: typeof json.name === 'string' ? json.name : undefined,
    latitude: typeof json.latitude === 'number' ? json.latitude : undefined,
    longitude: typeof json.longitude === 'number' ? json.longitude : undefined,
  };
}

/** 序列化成可写入持久化的形状（undefined 统一成 null） */
export function favoriteToJson(entry: FavoriteAirportEntry): JsonMap {
  return {
    icao: entry.icao,
    name: entry.name ?? null,
    latitude: entry.latitude ?? null,
    longitude: entry.longitude ?? null,
  };
}
