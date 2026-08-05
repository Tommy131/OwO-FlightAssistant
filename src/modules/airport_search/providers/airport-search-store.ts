import { create } from 'zustand';
import { PersistenceService } from '../../../core/services/persistence-service';
import { AppLogger } from '../../../core/utils/logger';
import { toJsonMap, type JsonMap } from '../../../core/utils/parse-utils';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import {
  airportDetailFromApi,
  favoriteFromAirport,
  favoriteFromJson,
  metarFromApi,
  suggestionFromApi,
  type AirportQueryResult,
  type AirportSuggestionData,
  type FavoriteAirportEntry,
} from '../models/airport-search-models';

/**
 * 机场搜索状态管理
 *
 * 对应 Flutter 版 `airport_search_provider.dart` + `airport_search_service.dart`。
 * 收藏列表持久化到 IndexedDB（桌面版写在自定义数据目录的 JSON 里）。
 */

const MODULE_NAME = 'airport_search';
const FAVORITES_KEY = 'favorites';

/** 完整 ICAO：4 位字母/数字 */
const ICAO_PATTERN = /^[A-Z0-9]{4}$/;
/** 部分输入（用于联想）：2–4 位 */
const ICAO_PARTIAL_PATTERN = /^[A-Z0-9]{2,4}$/;

export function normalizeIcao(input: string): string {
  return input.trim().toUpperCase();
}

export function isValidIcao(input: string): boolean {
  return ICAO_PATTERN.test(normalizeIcao(input));
}

export function isValidIcaoPartial(input: string): boolean {
  return ICAO_PARTIAL_PATTERN.test(normalizeIcao(input));
}

/** 错误类型，对应桌面版存 errorKey 再由页面翻译的做法 */
export type AirportSearchErrorKey =
  | 'invalidIcao'
  | 'queryFailed'
  | 'favoriteLoadFailed'
  | null;

interface AirportSearchState {
  isInitializing: boolean;
  isSearching: boolean;
  isSuggesting: boolean;
  errorKey: AirportSearchErrorKey;
  latestResult: AirportQueryResult | null;
  favorites: FavoriteAirportEntry[];
  suggestions: AirportSuggestionData[];

  init: () => Promise<void>;
  queryAirport: (input: string) => Promise<void>;
  clearResult: () => void;
  updateSuggestions: (input: string) => Promise<void>;
  clearSuggestions: () => void;
  toggleFavorite: () => Promise<void>;
  removeFavorite: (icao: string) => Promise<void>;
  isFavorite: (icao: string) => boolean;
}

export const useAirportSearchStore = create<AirportSearchState>((set, get) => ({
  isInitializing: false,
  isSearching: false,
  isSuggesting: false,
  errorKey: null,
  latestResult: null,
  favorites: [],
  suggestions: [],

  async init() {
    if (get().isInitializing) return;
    set({ isInitializing: true });
    try {
      await PersistenceService.ensureReady();
      const stored = PersistenceService.getModuleData<unknown[]>(MODULE_NAME, FAVORITES_KEY);
      const favorites = Array.isArray(stored)
        ? stored
            .map((item) => toJsonMap(item))
            .filter((item): item is JsonMap => item !== null)
            .map(favoriteFromJson)
            .filter((item) => item.icao.length > 0 && isValidIcao(item.icao))
        : [];
      set({ favorites, errorKey: null });
    } catch (e) {
      AppLogger.warning(`[AirportSearch] load favorites failed: ${String(e)}`);
      set({ errorKey: 'favoriteLoadFailed' });
    } finally {
      set({ isInitializing: false });
    }
  },

  async queryAirport(input) {
    const normalized = normalizeIcao(input);
    // 全量查询要求标准 4 位 ICAO
    if (!isValidIcao(normalized)) {
      set({ errorKey: 'invalidIcao' });
      return;
    }

    // 清空建议列表以突出当前结果
    set({ isSearching: true, suggestions: [], errorKey: null });
    try {
      await MiddlewareHttpService.init();
      // 机场详情与 METAR 并行拉取；METAR 失败不影响详情展示
      const [airportResponse, metarResponse] = await Promise.all([
        MiddlewareHttpService.getAirportByIcao(normalized),
        MiddlewareHttpService.getMetarByIcao(normalized).catch(() => null),
      ]);

      const airportBody = airportResponse.objectBody;
      if (!airportBody) throw new Error('invalid airport response');

      set({
        latestResult: {
          airport: airportDetailFromApi(airportBody),
          metar: metarResponse?.objectBody ? metarFromApi(metarResponse.objectBody) : {},
        },
      });
    } catch (e) {
      AppLogger.warning(`[AirportSearch] query ${normalized} failed: ${String(e)}`);
      set({ errorKey: 'queryFailed' });
    } finally {
      set({ isSearching: false });
    }
  },

  clearResult() {
    set({ latestResult: null, errorKey: null, suggestions: [] });
  },

  async updateSuggestions(input) {
    const normalized = normalizeIcao(input);
    if (!isValidIcaoPartial(normalized)) {
      set({ suggestions: [] });
      return;
    }

    set({ isSuggesting: true });
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getAirportSuggestions(normalized);
      const body = response.objectBody;
      // 兼容 suggestions / items 两种包装
      const rawList = Array.isArray(body?.suggestions)
        ? body.suggestions
        : Array.isArray(body?.items)
          ? body.items
          : [];
      const suggestions = rawList
        .map((item) => toJsonMap(item))
        .filter((item): item is JsonMap => item !== null)
        .map(suggestionFromApi)
        .filter((item) => item.icao.length > 0);
      set({ suggestions });
    } catch {
      set({ suggestions: [] });
    } finally {
      set({ isSuggesting: false });
    }
  },

  clearSuggestions() {
    set({ suggestions: [] });
  },

  async toggleFavorite() {
    const airport = get().latestResult?.airport;
    if (!airport || airport.icao.length === 0) return;

    const icao = normalizeIcao(airport.icao);
    const existing = get().favorites;
    const next = existing.some((item) => item.icao === icao)
      ? existing.filter((item) => item.icao !== icao)
      : [favoriteFromAirport(airport), ...existing];

    set({ favorites: next });
    await persistFavorites(next);
  },

  async removeFavorite(icao) {
    const normalized = normalizeIcao(icao);
    const next = get().favorites.filter((item) => item.icao !== normalized);
    set({ favorites: next });
    await persistFavorites(next);
  },

  isFavorite(icao) {
    const normalized = normalizeIcao(icao);
    return get().favorites.some((item) => item.icao === normalized);
  },
}));

async function persistFavorites(favorites: FavoriteAirportEntry[]): Promise<void> {
  await PersistenceService.setModuleData(
    MODULE_NAME,
    FAVORITES_KEY,
    favorites.map((item) => ({
      icao: item.icao,
      name: item.name ?? null,
      latitude: item.latitude ?? null,
      longitude: item.longitude ?? null,
    })),
  );
}
