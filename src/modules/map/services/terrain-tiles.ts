/**
 * 地形高程瓦片的取数适配器
 *
 * IO 在这里，判定在 `terrain-model.ts`（纯函数、有单测）。
 *
 * 瓦片在中间件侧长期缓存，同一片区域只有第一次会真的打上游，所以这里
 * 只需要做两件事：**不重复拉已经在手的瓦片**，以及**同一批请求不并发重入**。
 */

import { AppLogger } from '../../../core/utils/logger';
import { pickDouble } from '../../../core/utils/parse-utils';
import type { JsonMap } from '../../../core/utils/parse-utils';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import type { TerrainBounds, TerrainTile } from './terrain-model';

/** 一块瓦片的缓存键 —— 用西南角定位，与中间件的瓦片划分一致 */
export function tileCacheKey(tile: Pick<TerrainTile, 'south' | 'west'>): string {
  return `${tile.south.toFixed(4)}/${tile.west.toFixed(4)}`;
}

/**
 * 拉取覆盖给定范围的瓦片。
 *
 * 拉不到（接口失败、范围被后端拒掉、返回里没有瓦片）一律返回空数组，
 * 由调用方保持「这块区域不做地形判定」而不是当成一马平川。
 */
export async function fetchTerrainTiles(bounds: TerrainBounds): Promise<TerrainTile[]> {
  if (
    !Number.isFinite(bounds.south) ||
    !Number.isFinite(bounds.west) ||
    !Number.isFinite(bounds.north) ||
    !Number.isFinite(bounds.east)
  ) {
    return [];
  }

  try {
    await MiddlewareHttpService.init();
    const response = await MiddlewareHttpService.getTerrainTiles(bounds);
    const body = response.objectBody;
    if (!body) return [];
    return parseTerrainTiles(body);
  } catch (e) {
    AppLogger.info(`[Map] terrain tiles fetch failed: ${String(e)}`);
    return [];
  }
}

/**
 * 解析瓦片响应。
 *
 * 网格数与 grid² 对不上的瓦片直接丢掉 —— 一块残缺的瓦片会让 `elevationAt`
 * 在某些格子上给出错位的高程，那比没有数据更危险。
 */
export function parseTerrainTiles(body: JsonMap): TerrainTile[] {
  const raw = body['tiles'];
  if (!Array.isArray(raw)) return [];

  const tiles: TerrainTile[] = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) continue;
    const map = item as JsonMap;

    const south = pickDouble(map, ['south', 'South']);
    const west = pickDouble(map, ['west', 'West']);
    const spanDeg = pickDouble(map, ['span_deg', 'SpanDeg']);
    const cellSpanDeg = pickDouble(map, ['cell_span_deg', 'CellSpanDeg']);
    const grid = pickDouble(map, ['grid', 'Grid']);
    const elevations = map['elevations_m'] ?? map['ElevationsM'];

    if (south === undefined || west === undefined || grid === undefined) continue;
    if (!Array.isArray(elevations)) continue;

    const size = Math.round(grid);
    if (size <= 0 || elevations.length !== size * size) continue;

    const elevationsM: number[] = [];
    let usable = true;
    for (const value of elevations) {
      if (typeof value !== 'number' || !Number.isFinite(value)) {
        usable = false;
        break;
      }
      elevationsM.push(value);
    }
    if (!usable) continue;

    const span = spanDeg !== undefined && spanDeg > 0 ? spanDeg : (cellSpanDeg ?? 0) * size;
    if (!(span > 0)) continue;

    tiles.push({
      south,
      west,
      spanDeg: span,
      cellSpanDeg: cellSpanDeg !== undefined && cellSpanDeg > 0 ? cellSpanDeg : span / size,
      grid: size,
      elevationsM,
    });
  }
  return tiles;
}

/**
 * 把新拉到的瓦片并进已有的一批，按西南角去重。
 *
 * `limit` 之外的旧瓦片按加入顺序淘汰 —— 长航线上一路往前飞，
 * 身后几百海里的地形没有再留着的理由。
 */
export function mergeTerrainTiles(
  existing: readonly TerrainTile[],
  incoming: readonly TerrainTile[],
  limit: number,
): TerrainTile[] {
  const byKey = new Map<string, TerrainTile>();
  for (const tile of existing) byKey.set(tileCacheKey(tile), tile);
  // 后到的覆盖先到的：同一块瓦片重新拉过就以新的为准
  for (const tile of incoming) {
    const key = tileCacheKey(tile);
    byKey.delete(key);
    byKey.set(key, tile);
  }
  const merged = [...byKey.values()];
  return merged.length <= limit ? merged : merged.slice(merged.length - limit);
}
