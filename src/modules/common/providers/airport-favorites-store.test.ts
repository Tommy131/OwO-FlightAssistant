// @vitest-environment jsdom
import { beforeEach, describe, expect, it } from 'vitest';

import { PersistenceService } from '../../../core/services/persistence-service';
import { useAirportFavoritesStore } from './airport-favorites-store';

/**
 * 收藏 store 的行为测试
 *
 * 重点盯两件事：
 *   1. 持久化读写用的是**机场查询模块的老键**（换键 = 静默清空老用户收藏）
 *   2. 增删改之后 `favorites` 立刻反映出来 —— 地图和机场查询页读的都是它
 */

const STORAGE_MODULE = 'airport_search';
const STORAGE_KEY = 'favorites';

const ZBAA = { icao: 'ZBAA', name: 'Beijing Capital Intl', latitude: 40.08, longitude: 116.58 };
const EDDM = { icao: 'EDDM', name: 'Muenchen Franz-Josef-Strauss' };

function resetStore() {
  useAirportFavoritesStore.setState({ favorites: [], hydrated: false, loadFailed: false });
}

describe('useAirportFavoritesStore', () => {
  beforeEach(async () => {
    await PersistenceService.ensureReady();
    await PersistenceService.setModuleData(STORAGE_MODULE, STORAGE_KEY, []);
    resetStore();
  });

  it('加入收藏后立刻出现在列表里', async () => {
    await useAirportFavoritesStore.getState().add(ZBAA);
    expect(useAirportFavoritesStore.getState().favorites.map((f) => f.icao)).toEqual(['ZBAA']);
  });

  it('新收藏排在最前', async () => {
    await useAirportFavoritesStore.getState().add(ZBAA);
    await useAirportFavoritesStore.getState().add(EDDM);
    expect(useAirportFavoritesStore.getState().favorites.map((f) => f.icao)).toEqual([
      'EDDM',
      'ZBAA',
    ]);
  });

  it('重复收藏同一个机场不会出现两条', async () => {
    await useAirportFavoritesStore.getState().add(ZBAA);
    await useAirportFavoritesStore.getState().add(ZBAA);
    expect(useAirportFavoritesStore.getState().favorites).toHaveLength(1);
  });

  it('toggle 在收藏与取消之间来回切', async () => {
    await useAirportFavoritesStore.getState().toggle(ZBAA);
    expect(useAirportFavoritesStore.getState().isFavorite('ZBAA')).toBe(true);
    await useAirportFavoritesStore.getState().toggle(ZBAA);
    expect(useAirportFavoritesStore.getState().isFavorite('ZBAA')).toBe(false);
  });

  it('大小写不影响判定与去重', async () => {
    await useAirportFavoritesStore.getState().add({ icao: 'zbaa' });
    expect(useAirportFavoritesStore.getState().isFavorite('ZBAA')).toBe(true);
    await useAirportFavoritesStore.getState().add({ icao: 'ZBAA' });
    expect(useAirportFavoritesStore.getState().favorites).toHaveLength(1);
  });

  it('非法 ICAO 不入库', async () => {
    await useAirportFavoritesStore.getState().add({ icao: 'ZB' });
    await useAirportFavoritesStore.getState().add({ icao: '' });
    expect(useAirportFavoritesStore.getState().favorites).toHaveLength(0);
  });

  it('取消一个不存在的收藏不炸也不改动列表', async () => {
    await useAirportFavoritesStore.getState().add(ZBAA);
    await useAirportFavoritesStore.getState().remove('ZZZZ');
    expect(useAirportFavoritesStore.getState().favorites).toHaveLength(1);
  });

  /*
   * 这条守的是「别换持久化键」。
   *
   * 收藏原本是机场查询模块的私有状态，提到 common 时如果顺手把键名改成
   * `airport_favorites`，老用户攒的收藏会一次性消失且没有任何提示 ——
   * 界面只会显示「暂无收藏」。断言直接钉在老键上。
   */
  it('写入的是机场查询模块的老键，老用户的收藏不会丢', async () => {
    await useAirportFavoritesStore.getState().add(ZBAA);

    const stored = PersistenceService.getModuleData<unknown[]>(STORAGE_MODULE, STORAGE_KEY);
    expect(Array.isArray(stored)).toBe(true);
    expect((stored as { icao: string }[])[0].icao).toBe('ZBAA');
  });

  it('能读回老键里已有的收藏', async () => {
    await PersistenceService.setModuleData(STORAGE_MODULE, STORAGE_KEY, [
      { icao: 'ZBAA', name: 'Beijing Capital Intl', latitude: 40.08, longitude: 116.58 },
    ]);
    resetStore();

    await useAirportFavoritesStore.getState().hydrate();

    const favorites = useAirportFavoritesStore.getState().favorites;
    expect(favorites).toHaveLength(1);
    expect(favorites[0].name).toBe('Beijing Capital Intl');
    expect(favorites[0].latitude).toBeCloseTo(40.08, 5);
  });

  // 存档里混进坏数据时，宁可少一条也不要在列表里放一个点不动的空条目
  it('hydrate 丢掉结构不合法的条目', async () => {
    await PersistenceService.setModuleData(STORAGE_MODULE, STORAGE_KEY, [
      { icao: 'ZBAA' },
      { icao: 'ZB' },
      { name: '没有 icao' },
      'not an object',
      null,
    ] as never);
    resetStore();

    await useAirportFavoritesStore.getState().hydrate();

    expect(useAirportFavoritesStore.getState().favorites.map((f) => f.icao)).toEqual(['ZBAA']);
  });

  it('hydrate 是幂等的，重复调用不会重复追加', async () => {
    await PersistenceService.setModuleData(STORAGE_MODULE, STORAGE_KEY, [{ icao: 'ZBAA' }]);
    resetStore();

    await useAirportFavoritesStore.getState().hydrate();
    await useAirportFavoritesStore.getState().hydrate();

    expect(useAirportFavoritesStore.getState().favorites).toHaveLength(1);
  });
});
