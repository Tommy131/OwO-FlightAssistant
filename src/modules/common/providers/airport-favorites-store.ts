import { create } from 'zustand';

import { PersistenceService } from '../../../core/services/persistence-service';
import { AppLogger } from '../../../core/utils/logger';
import {
  favoriteFromJson,
  favoriteToJson,
  isValidIcao,
  normalizeIcao,
  type FavoriteAirportEntry,
} from '../models/airport-favorite';

/**
 * 收藏机场（跨模块共享）
 *
 * ── 为什么住在 common ──
 * 收藏原本是机场查询模块的私有状态，但地图的搜索框也要用同一份：
 * 没输入内容时列出收藏过的机场，点一下直接定位过去。
 * 让地图去 import 机场查询的 store 会把两个业务模块焊死
 * （删掉机场查询，地图就编译不过了），所以提到 common 这一层 ——
 * 与 flight-data / planned-route / app-mode 同一个位置。
 *
 * 两个模块读的是**同一个 store 实例**，因此不需要任何同步代码：
 * 在机场查询页点星标，地图搜索框里的列表当场就变。
 */

/**
 * 持久化命名空间沿用机场查询模块的老位置。
 *
 * ⚠️ 别「顺手」改成 `airport_favorites` 之类更好听的名字 —— 老用户的收藏
 * 就存在 `module:airport_search` 这个桶的 `favorites` 键下，换个键等于
 * 把人家攒的收藏一次性清空，而且是静默的（界面只会显示「暂无收藏」）。
 * 键名难看是小事，丢数据是大事。
 */
const STORAGE_MODULE = 'airport_search';
const STORAGE_KEY = 'favorites';

interface AirportFavoritesState {
  favorites: FavoriteAirportEntry[];
  /** 是否已从持久化载入过 */
  hydrated: boolean;
  loadFailed: boolean;

  /** 从持久化恢复（幂等，重复调用只生效一次） */
  hydrate: () => Promise<void>;
  /** 加入收藏；已存在则原样返回 */
  add: (entry: FavoriteAirportEntry) => Promise<void>;
  /** 取消收藏 */
  remove: (icao: string) => Promise<void>;
  /** 在收藏与未收藏之间切换 */
  toggle: (entry: FavoriteAirportEntry) => Promise<void>;
  isFavorite: (icao: string) => boolean;
}

export const useAirportFavoritesStore = create<AirportFavoritesState>((set, get) => ({
  favorites: [],
  hydrated: false,
  loadFailed: false,

  async hydrate() {
    if (get().hydrated) return;
    try {
      await PersistenceService.ensureReady();
      const stored = PersistenceService.getModuleData<unknown[]>(STORAGE_MODULE, STORAGE_KEY);
      // 脏数据（缺 icao、格式不对）直接丢，免得列表里出现点不动的空条目
      const favorites = Array.isArray(stored)
        ? stored
            .map(favoriteFromJson)
            .filter((item): item is FavoriteAirportEntry => item !== null)
        : [];
      set({ favorites, hydrated: true, loadFailed: false });
    } catch (e) {
      AppLogger.warning(`[AirportFavorites] hydrate failed: ${String(e)}`);
      set({ hydrated: true, loadFailed: true });
    }
  },

  async add(entry) {
    const icao = normalizeIcao(entry.icao);
    if (!isValidIcao(icao)) return;
    if (get().favorites.some((item) => item.icao === icao)) return;
    // 新收藏排在最前：刚标记的通常就是接下来要用的
    const next = [{ ...entry, icao }, ...get().favorites];
    set({ favorites: next });
    await persist(next);
  },

  async remove(icao) {
    const normalized = normalizeIcao(icao);
    const next = get().favorites.filter((item) => item.icao !== normalized);
    if (next.length === get().favorites.length) return;
    set({ favorites: next });
    await persist(next);
  },

  async toggle(entry) {
    const icao = normalizeIcao(entry.icao);
    if (get().favorites.some((item) => item.icao === icao)) {
      await get().remove(icao);
      return;
    }
    await get().add(entry);
  },

  isFavorite(icao) {
    const normalized = normalizeIcao(icao);
    return get().favorites.some((item) => item.icao === normalized);
  },
}));

async function persist(favorites: FavoriteAirportEntry[]): Promise<void> {
  await PersistenceService.setModuleData(STORAGE_MODULE, STORAGE_KEY, favorites.map(favoriteToJson));
}
