import { create } from 'zustand';
import { AppLogger } from '../../../core/utils/logger';
import { toJsonMap, type JsonMap } from '../../../core/utils/parse-utils';
import { isValidIcao, normalizeIcao } from '../../common/models/airport-favorite';
import { useAirportFavoritesStore } from '../../common/providers/airport-favorites-store';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import {
  airportDetailFromApi,
  favoriteFromAirport,
  metarFromApi,
  suggestionFromApi,
  type AirportQueryResult,
  type AirportSuggestionData,
} from '../models/airport-search-models';

/**
 * 机场搜索状态管理
 *
 * 对应 Flutter 版 `airport_search_provider.dart` + `airport_search_service.dart`。
 *
 * ── 收藏不在这里 ──
 * 收藏列表已提到 `common/providers/airport-favorites-store`：地图的搜索框
 * 也要用同一份（没输入时列出收藏）。本 store 只保留一层转调，
 * 页面不用同时订阅两个 store；真正的读写与持久化都在那边。
 */

/** 部分输入（用于联想）：2–4 位 */
const ICAO_PARTIAL_PATTERN = /^[A-Z0-9]{2,4}$/;

export { isValidIcao, normalizeIcao };

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
  suggestions: AirportSuggestionData[];

  init: () => Promise<void>;
  queryAirport: (input: string) => Promise<void>;
  clearResult: () => void;
  updateSuggestions: (input: string) => Promise<void>;
  clearSuggestions: () => void;
  /** 收藏/取消收藏当前查询结果 */
  toggleFavorite: () => Promise<void>;
}

export const useAirportSearchStore = create<AirportSearchState>((set, get) => ({
  isInitializing: false,
  isSearching: false,
  isSuggesting: false,
  errorKey: null,
  latestResult: null,
  suggestions: [],

  async init() {
    if (get().isInitializing) return;
    set({ isInitializing: true });
    try {
      await useAirportFavoritesStore.getState().hydrate();
      set({ errorKey: useAirportFavoritesStore.getState().loadFailed ? 'favoriteLoadFailed' : null });
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
    await useAirportFavoritesStore.getState().toggle(favoriteFromAirport(airport));
  },
}));
