/**
 * 自定义滑行道路线的编辑（纯函数）
 *
 * 这是一套**基于下标**的节点/分段手术：插入一个节点会让它后面所有分段的
 * `fromIndex` / `toIndex` 整体后移。这类代码错一位不会抛异常，只会让某条分段
 * 连到隔壁节点上 —— 画出来还是一条线，只是连错了地方。
 *
 * 原先内嵌在 `map-store.ts` 里，还依赖模块级的 `ctx.undoStack` / `ctx.redoStack`，
 * 没法脱离 Zustand 调用。这里把路线与撤销栈都改成值进值出。
 */

import type {
  MapCoordinate,
  MapTaxiwayNode,
  MapTaxiwaySegment,
} from '../models/map-models';

/** 一条路线的完整状态 */
export interface TaxiwayRoute {
  readonly nodes: MapTaxiwayNode[];
  readonly segments: MapTaxiwaySegment[];
}

/** 撤销栈上限，防止长时间编辑把内存吃满 */
export const MAX_UNDO_STEPS = 50;

export const EMPTY_ROUTE: TaxiwayRoute = { nodes: [], segments: [] };

/**
 * 节点列表变化后重建相邻分段，尽量保留已有分段的名称/限速。
 *
 * `previous` 传空数组表示「节点顺序变了，旧分段信息不再对得上」——
 * 删除与插入都属于这种情况，硬套会把 A→B 的限速安到 A→C 上。
 */
export function rebuildSegments(
  nodes: readonly MapTaxiwayNode[],
  previous: readonly MapTaxiwaySegment[],
): MapTaxiwaySegment[] {
  const segments: MapTaxiwaySegment[] = [];
  for (let i = 0; i + 1 < nodes.length; i++) {
    const existing = previous[i];
    segments.push({
      fromIndex: i,
      toIndex: i + 1,
      name: existing?.name,
      note: existing?.note,
      speedLimitKt: existing?.speedLimitKt,
    });
  }
  return segments;
}

function isValidIndex(length: number, index: number): boolean {
  return Number.isInteger(index) && index >= 0 && index < length;
}

/** 在末尾追加一个节点 */
export function addNode(route: TaxiwayRoute, point: MapCoordinate): TaxiwayRoute {
  const nodes = [...route.nodes, { position: point }];
  // 追加不打乱既有顺序，所以旧分段信息可以原样沿用
  return { nodes, segments: rebuildSegments(nodes, route.segments) };
}

/**
 * 移动某个节点。
 *
 * 下标非法时返回 `null` 表示「什么也没发生」，由调用方决定是否记撤销 ——
 * 越界还压一条撤销记录的话，用户按撤销会「什么都没变」，很困惑。
 */
export function moveNode(
  route: TaxiwayRoute,
  index: number,
  point: MapCoordinate,
): TaxiwayRoute | null {
  if (!isValidIndex(route.nodes.length, index)) return null;
  const nodes = route.nodes.map((node, i) =>
    i === index ? { ...node, position: point } : node,
  );
  // 只改坐标，拓扑没变，分段无需重建
  return { nodes, segments: route.segments };
}

/** 改节点的名称/备注 */
export function updateNodeInfo(
  route: TaxiwayRoute,
  index: number,
  info: { name?: string; note?: string },
): TaxiwayRoute | null {
  if (!isValidIndex(route.nodes.length, index)) return null;
  const nodes = route.nodes.map((node, i) => (i === index ? { ...node, ...info } : node));
  return { nodes, segments: route.segments };
}

/** 删除某个节点；分段全部重建（下标整体前移，旧信息对不上了） */
export function removeNode(route: TaxiwayRoute, index: number): TaxiwayRoute | null {
  if (!isValidIndex(route.nodes.length, index)) return null;
  const nodes = route.nodes.filter((_, i) => i !== index);
  return { nodes, segments: rebuildSegments(nodes, []) };
}

/**
 * 在某条分段中间插入一个节点。
 *
 * 不给坐标就取该分段两端的中点。
 */
export function insertNodeBetween(
  route: TaxiwayRoute,
  segmentIndex: number,
  coordinate?: MapCoordinate,
): TaxiwayRoute | null {
  const segment = route.segments[segmentIndex];
  if (!segment) return null;
  const from = route.nodes[segment.fromIndex];
  const to = route.nodes[segment.toIndex];
  if (!from || !to) return null;

  const position = coordinate ?? {
    latitude: (from.position.latitude + to.position.latitude) / 2,
    longitude: (from.position.longitude + to.position.longitude) / 2,
  };
  const nodes = [...route.nodes];
  nodes.splice(segment.toIndex, 0, { position });
  return { nodes, segments: rebuildSegments(nodes, []) };
}

/** 改分段的名称/备注/限速 */
export function updateSegmentInfo(
  route: TaxiwayRoute,
  index: number,
  info: { name?: string; note?: string; speedLimitKt?: number },
): TaxiwayRoute | null {
  if (!isValidIndex(route.segments.length, index)) return null;
  const segments = route.segments.map((segment, i) =>
    i === index ? { ...segment, ...info } : segment,
  );
  return { nodes: route.nodes, segments };
}

/**
 * 压入一步撤销记录，超出上限时丢弃最老的一步。
 *
 * 返回新栈（不改传入的那个），调用方负责同时清空重做栈。
 */
export function pushUndo(
  stack: readonly TaxiwayRoute[],
  route: TaxiwayRoute,
): TaxiwayRoute[] {
  const next = [...stack, route];
  return next.length > MAX_UNDO_STEPS ? next.slice(next.length - MAX_UNDO_STEPS) : next;
}
