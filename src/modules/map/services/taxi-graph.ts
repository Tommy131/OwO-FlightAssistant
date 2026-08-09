/**
 * 滑行道路网（纯计算）
 *
 * 把 OSM 的 aeroway 折线连成带权无向图，用来做「按管制指令高亮路线」
 * 与「从廊桥自动规划到跑道口」。
 *
 * ── 连通性靠坐标精确相等，不做模糊吸附 ──
 * 原以为要跟 OSM 的断头与重复节点搏斗，实测并非如此：OSM 在每个路口都把
 * 滑行道切成独立的 way，相邻 way 共享同一个节点，Overpass 的 `out geom`
 * 吐出来的坐标**逐位相同**。EDDM 608 条 way / 3509 个节点，
 * 按坐标原样建图后 99% 落在同一个连通分量里（RCNN、EDDN 是 100%）。
 *
 * 所以这里刻意**不做**按距离吸附：一旦引入容差，机场里那些本就该分开的
 * 平行滑行道（间距十几米）会被粘成一个节点，规划出穿越草坪的路线 ——
 * 那比断开危险得多。真正的断头（占 6%，多是通向机位的尽头）保持断开即可。
 */

import { bearingDeg } from './geo';
import { distanceInMeters } from './map-telemetry';
import type { MapAerowayFeature, MapCoordinate } from '../models/map-models';

/** 参与路网的要素类型；停机坪是面，连不成线 */
const ROUTABLE_KINDS = new Set(['taxiway', 'taxilane', 'runway']);

/** 节点键：坐标原样拼串。见文件头 —— 不取整、不吸附 */
export function nodeKey(point: MapCoordinate): string {
  return `${point.latitude},${point.longitude}`;
}

export interface TaxiEdge {
  readonly to: string;
  readonly distanceM: number;
  /** 该段所属的滑行道编号（A5 / K6）；跑道段是跑道号 */
  readonly ref?: string;
  readonly kind: string;
}

export interface TaxiGraph {
  readonly nodes: ReadonlyMap<string, MapCoordinate>;
  readonly adjacency: ReadonlyMap<string, readonly TaxiEdge[]>;
}

/** 从机场地面要素建图 */
export function buildTaxiGraph(features: readonly MapAerowayFeature[]): TaxiGraph {
  const nodes = new Map<string, MapCoordinate>();
  const adjacency = new Map<string, TaxiEdge[]>();

  const link = (from: MapCoordinate, to: MapCoordinate, feature: MapAerowayFeature) => {
    const fromKey = nodeKey(from);
    const toKey = nodeKey(to);
    // 自环没有意义，还会让最短路算法白转一圈
    if (fromKey === toKey) return;

    nodes.set(fromKey, from);
    nodes.set(toKey, to);
    const distanceM = distanceInMeters(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    const ref = feature.ref?.trim();
    const edge = { distanceM, ref: ref && ref.length > 0 ? ref : undefined, kind: feature.kind };

    if (!adjacency.has(fromKey)) adjacency.set(fromKey, []);
    if (!adjacency.has(toKey)) adjacency.set(toKey, []);
    adjacency.get(fromKey)!.push({ ...edge, to: toKey });
    adjacency.get(toKey)!.push({ ...edge, to: fromKey });
  };

  for (const feature of features) {
    if (!ROUTABLE_KINDS.has(feature.kind)) continue;
    const points = feature.points;
    for (let i = 1; i < points.length; i += 1) {
      link(points[i - 1], points[i], feature);
    }
  }

  return { nodes, adjacency };
}

/** 找离给定坐标最近的图节点；超出 maxDistanceM 就算没有 */
export function nearestNode(
  graph: TaxiGraph,
  point: MapCoordinate,
  maxDistanceM = 200,
): string | null {
  let best: string | null = null;
  let bestDistance = Number.POSITIVE_INFINITY;
  for (const [key, node] of graph.nodes) {
    const distance = distanceInMeters(
      point.latitude,
      point.longitude,
      node.latitude,
      node.longitude,
    );
    if (distance < bestDistance) {
      bestDistance = distance;
      best = key;
    }
  }
  return bestDistance <= maxDistanceM ? best : null;
}

export interface TaxiPath {
  /** 途经节点坐标，可直接画线 */
  readonly points: readonly MapCoordinate[];
  readonly distanceM: number;
  /** 依次经过的滑行道编号（已去重相邻重复），用于生成文字指令 */
  readonly refs: readonly string[];
}

/**
 * 最短路（Dijkstra）。
 *
 * 没上 A*：一个大机场也就三千多个节点，实测毫秒级；
 * A* 的启发式还得处理跑道穿越这类「直线距离骗人」的情形，不值当。
 *
 * `penalizeRunway` 给跑道段加权重：滑行时能不上跑道就不上，
 * 不加惩罚的话最短路会理直气壮地穿跑道抄近道。
 */
export function shortestTaxiPath(
  graph: TaxiGraph,
  fromKey: string,
  toKey: string,
  options: { penalizeRunway?: number; onlyRef?: string } = {},
): TaxiPath | null {
  // 限定只走某条编号的道：管制说"沿 B2 滑"，就不能中途拐到别的道上抄近路
  const onlyRef = options.onlyRef?.trim().toUpperCase();
  if (!graph.adjacency.has(fromKey) || !graph.adjacency.has(toKey)) return null;
  if (fromKey === toKey) {
    const node = graph.nodes.get(fromKey);
    return node ? { points: [node], distanceM: 0, refs: [] } : null;
  }

  const runwayPenalty = options.penalizeRunway ?? 8;
  const cost = new Map<string, number>([[fromKey, 0]]);
  const previous = new Map<string, { key: string; edge: TaxiEdge }>();
  const visited = new Set<string>();
  // 简单的「每轮线性扫最小值」而不是优先队列：节点数以千计，
  // 换成堆省下的时间还不够读懂它的成本。
  const pending = new Set<string>([fromKey]);

  while (pending.size > 0) {
    let current: string | null = null;
    let currentCost = Number.POSITIVE_INFINITY;
    for (const key of pending) {
      const value = cost.get(key) ?? Number.POSITIVE_INFINITY;
      if (value < currentCost) {
        currentCost = value;
        current = key;
      }
    }
    if (current === null) break;
    pending.delete(current);
    if (current === toKey) break;
    visited.add(current);

    for (const edge of graph.adjacency.get(current) ?? []) {
      if (visited.has(edge.to)) continue;
      if (onlyRef !== undefined && edge.ref?.toUpperCase() !== onlyRef) continue;
      const weight = edge.distanceM * (edge.kind === 'runway' ? runwayPenalty : 1);
      const next = currentCost + weight;
      if (next < (cost.get(edge.to) ?? Number.POSITIVE_INFINITY)) {
        cost.set(edge.to, next);
        previous.set(edge.to, { key: current, edge });
        pending.add(edge.to);
      }
    }
  }

  if (!cost.has(toKey)) return null;

  // 回溯
  const points: MapCoordinate[] = [];
  const refs: string[] = [];
  let distanceM = 0;
  let cursor = toKey;
  while (cursor !== fromKey) {
    const step = previous.get(cursor);
    if (!step) return null;
    const node = graph.nodes.get(cursor);
    if (node) points.push(node);
    distanceM += step.edge.distanceM;
    if (step.edge.ref) refs.push(step.edge.ref);
    cursor = step.key;
  }
  const start = graph.nodes.get(fromKey);
  if (start) points.push(start);
  points.reverse();
  refs.reverse();

  return { points, distanceM, refs: dedupeAdjacent(refs) };
}

/**
 * 滑行速度模型
 *
 * 直线段按 15 kt 算（多数机场的滑行限速在 15–25 kt，取偏保守的一头）；
 * 转弯要减到 8 kt 上下，机场里九十度弯必须慢下来。
 * 只按全程除以一个固定速度会明显低估 —— 一条 4 km 的滑行路线上
 * 十几个弯，那部分时间是实打实的。
 */
const TAXI_STRAIGHT_KT = 15;
/**
 * 每转过一度航向额外花的时间（秒）。九十度弯约多花 9 秒。
 *
 * 按**累计转角**计费，而不是「单步夹角超过 N 度就整段降速」——
 * 后者在 OSM 这种密集采样的几何上根本不成立：一个九十度弯被拆成十来个顶点，
 * 每步只转十几度，于是一个弯都识别不出来。EDDM 实测 92 个顶点里
 * 只有 2 段单步超过 30 度，算出来的时间和纯直线只差 1%。
 * 累计转角与采样密度无关，弯拆得再碎，转过的总度数不变。
 */
const TAXI_TURN_SECONDS_PER_DEG = 0.1;
/**
 * 每步扣掉的噪声余量（度）。
 *
 * OSM 的滑行道中心线是人描出来的，笔直的一段也会左右微抖一两度；
 * 不扣的话，一条四公里的直线滑行道能凑出好几百度的「转角」。
 *
 * 用「扣掉余量后累加」而不是「小于阈值就整步丢弃」：后者有悬崖 ——
 * 采样再密一点，每步角度落到阈值以下，一个真的九十度弯会被整个吞掉，
 * 而所有合成测试都还过得去。
 *
 * 扣减式仍有残余的密度敏感：一个九十度弯拆成 N 段，计入的是 `90 - 2N` 度，
 * N 大到 45 就归零。实测 OSM 的采样密度远没到那个程度（EDDM 上转弯占总时长
 * 9%–13%，折合均速 13.1–13.6 kt，与真实机场吻合），所以按当前数据源够用。
 * 真要彻底消除，得改成按固定距离窗口比较航向，而不是逐顶点。
 */
const TAXI_TURN_NOISE_DEG = 2;
const KT_TO_M_PER_S = 0.514444;

/** 两个航向之间的夹角（0–180） */
function headingDeltaDeg(from: number, to: number): number {
  const raw = Math.abs(to - from) % 360;
  return raw > 180 ? 360 - raw : raw;
}

/**
 * 估算滑行时间（秒）。
 *
 * 不含等待放行、跑道穿越等待这类不可预测的时间 —— 那些取决于管制，
 * 不该由几何算出来假装精确。这里只回答「一路不停要多久」。
 */
export function estimateTaxiSeconds(points: readonly MapCoordinate[]): number {
  // 不足两个点时下面的循环本就不会执行，返回 0 —— 不必再加一道提前返回
  let meters = 0;
  let turnDegrees = 0;
  let previousHeading: number | undefined;
  for (let i = 1; i < points.length; i += 1) {
    const from = points[i - 1];
    const to = points[i];
    const legMeters = distanceInMeters(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    // 重复点既没有长度也定不出航向，跳过；否则会把后一段误判成转弯
    if (legMeters <= 0) continue;
    meters += legMeters;

    const heading = bearingDeg(from, to);
    if (previousHeading !== undefined) {
      const delta = headingDeltaDeg(previousHeading, heading);
      turnDegrees += Math.max(0, delta - TAXI_TURN_NOISE_DEG);
    }
    previousHeading = heading;
  }
  return (
    meters / (TAXI_STRAIGHT_KT * KT_TO_M_PER_S) +
    turnDegrees * TAXI_TURN_SECONDS_PER_DEG
  );
}

/** 去掉相邻重复：一条滑行道被切成几十段，编号会重复几十次 */
export function dedupeAdjacent(values: readonly string[]): string[] {
  const result: string[] = [];
  for (const value of values) {
    if (result[result.length - 1] !== value) result.push(value);
  }
  return result;
}

/**
 * 解析管制指令里的滑行道序列。
 *
 * 例：`"A5, B, hold short 36L"` → `['A5', 'B']`，跑道口 `36L`。
 * 管制念的是滑行道编号，中间的连接词（taxi via / then / and）一律忽略。
 */
export function parseTaxiClearance(text: string): {
  refs: string[];
  holdShort?: string;
} {
  const upper = text.toUpperCase();

  // "hold short of 36L" / "HS 36L" —— 跑道号形如 09 / 09L / 09R / 09C
  const holdMatch = /(?:HOLD\s*SHORT(?:\s*OF)?|HS)\s+(?:RWY\s*)?(\d{1,2}[LRC]?)/.exec(upper);
  const holdShort = holdMatch ? holdMatch[1] : undefined;

  // 把 hold short 之后的内容剪掉，免得跑道号被当成滑行道编号
  const head = holdMatch ? upper.slice(0, holdMatch.index) : upper;

  // 滑行道编号：字母开头（可带数字），如 A / A5 / K6 / NP1
  const refs: string[] = [];
  for (const match of head.matchAll(/\b([A-Z]{1,3}\d{0,2})\b/g)) {
    const token = match[1];
    if (CLEARANCE_STOPWORDS.has(token)) continue;
    refs.push(token);
  }
  return { refs: dedupeAdjacent(refs), holdShort };
}

/** 指令里的连接词与套话，不是滑行道编号 */
const CLEARANCE_STOPWORDS = new Set([
  'TAXI', 'VIA', 'THEN', 'AND', 'TO', 'RWY', 'RUNWAY', 'HOLD', 'SHORT', 'OF',
  'GATE', 'STAND', 'CROSS', 'CONTACT', 'GROUND', 'TOWER', 'AT', 'ON', 'WITH',
  'PUSHBACK', 'APPROVED', 'EXPECT', 'DEPARTURE', 'HS',
]);

/** 某个编号的滑行道覆盖了哪些节点 */
export function nodesOnRef(graph: TaxiGraph, ref: string): Set<string> {
  const target = ref.trim().toUpperCase();
  const result = new Set<string>();
  // 邻接表是对称的（建图时两个方向都写了），所以只收 key 就够 ——
  // 另一端会在它自己那一轮里被收进来
  for (const [key, edges] of graph.adjacency) {
    for (const edge of edges) {
      // OSM 里的 ref 大小写不统一（见过 "b" 与 "B" 混用），两边都归一
      if (edge.ref?.toUpperCase() === target) {
        result.add(key);
        break;
      }
    }
  }
  return result;
}

/**
 * 按管制指令规划滑行路线。
 *
 * 管制念的是「先上 A5，再转 B」，这不是一条普通最短路 —— 必须**按顺序沿着**
 * 这些滑行道滑。每个编号分两步走：
 *   ① 先并到这条道上（不限制走法，因为怎么并过去指令没说）；
 *   ② 再**只沿这条道**滑到它与下一条道的交点。
 *
 * 第 ② 步是关键。只做第 ① 步的话，"走到该道上的某个节点"就算数了 ——
 * 而碰到一条道的端点根本不等于沿它滑过。EDDM 实测：指令写
 * `via E1, S, B2`，只判"到达"时规划出的路线压根没走 B2，函数还返回成功。
 * 那种"看起来像模像样其实错的"路线，比直接说规划不出来危险得多。
 *
 * 任何一段接不上就整体返回 null —— 地面滑行给错路线比不给更糟。
 */
export function planTaxiRouteByRefs(
  graph: TaxiGraph,
  fromKey: string,
  refs: readonly string[],
  toKey?: string,
  options: { penalizeRunway?: number } = {},
): TaxiPath | null {
  const legs: TaxiPath[] = [];
  let cursor = fromKey;

  const onRef = refs.map((ref) => nodesOnRef(graph, ref));
  if (onRef.some((set) => set.size === 0)) return null;

  for (let i = 0; i < refs.length; i += 1) {
    const candidates = onRef[i];

    // ① 并到这条道上（已经在上面就跳过）
    if (!candidates.has(cursor)) {
      const entry = nearestOf(graph, cursor, candidates, options);
      if (!entry) return null;
      legs.push(entry.leg);
      cursor = entry.key;
    }

    // ② 沿这条道滑到与下一条道的交点；最后一条道则滑向指令终点
    const isLast = i + 1 === refs.length;
    const alongOptions = { ...options, onlyRef: refs[i] };

    /*
     * ② 沿这条道滑到「最适合接下一段」的位置。
     *
     * 下一条道由 `aim` 指示：不是最后一条就瞄准下一条道，是最后一条就瞄准终点。
     * 出口点按到 aim 的直线距离挑（只用直线距离是刻意的：真跑一遍最短路要在
     * 几百个出口上各算一次，而这里只是决定"沿这条道滑多远"，差一两个路口
     * 由后一段的最短路自己修正）。
     */
    const aim = isLast
      ? toKey === undefined
        ? undefined
        : graph.nodes.get(toKey)
      : nearestPointOfSet(graph, graph.nodes.get(cursor), onRef[i + 1]);

    /*
     * 出口只能在「从入口沿这条道走得到」的那一段里挑。
     *
     * 同一个编号在 OSM 里往往是好几截互不相连的道（E1 在 EDDM 就分布在
     * 航站楼两侧），直接按全图的同名节点挑出口，会挑到走不过去的那一截，
     * 于是整条指令白白规划失败。
     */
    const reachable = componentAlongRef(graph, cursor, refs[i]);
    const exit = aim
      ? closestTo(graph, reachable, aim)
      : farthestOf(graph, cursor, reachable, alongOptions)?.key;

    if (exit !== undefined && exit !== cursor) {
      const along = shortestTaxiPath(graph, cursor, exit, alongOptions);
      if (!along) return null;
      legs.push(along);
      cursor = exit;
    }

    // 最后一条道若指定了终点（通常是 hold short 的跑道口），补一段接过去。
    // 终点一般不在滑行道上，所以这一段不限制编号。
    if (isLast && toKey !== undefined && toKey !== cursor) {
      const tail = shortestTaxiPath(graph, cursor, toKey, options);
      if (!tail) return null;
      legs.push(tail);
      cursor = toKey;
    }
  }

  if (toKey !== undefined && toKey !== cursor) {
    const tail = shortestTaxiPath(graph, cursor, toKey, options);
    if (!tail) return null;
    legs.push(tail);
  }

  if (legs.length === 0) {
    const node = graph.nodes.get(fromKey);
    return node ? { points: [node], distanceM: 0, refs: [] } : null;
  }
  return concatPaths(legs);
}

/** 在一组目标节点里挑距离最近的那个，并给出到它的路径 */
function nearestOf(
  graph: TaxiGraph,
  fromKey: string,
  targets: ReadonlySet<string>,
  options: { penalizeRunway?: number; onlyRef?: string },
): { key: string; leg: TaxiPath } | null {
  let best: { key: string; leg: TaxiPath } | null = null;
  for (const target of targets) {
    const leg = shortestTaxiPath(graph, fromKey, target, options);
    if (leg && (!best || leg.distanceM < best.leg.distanceM)) best = { key: target, leg };
  }
  return best;
}

/** 挑距离最远的可达目标 —— 指令的最后一条道要滑到尽头 */
function farthestOf(
  graph: TaxiGraph,
  fromKey: string,
  targets: ReadonlySet<string>,
  options: { penalizeRunway?: number; onlyRef?: string },
): { key: string; leg: TaxiPath } | null {
  let best: { key: string; leg: TaxiPath } | null = null;
  for (const target of targets) {
    if (target === fromKey) continue;
    const leg = shortestTaxiPath(graph, fromKey, target, options);
    if (leg && (!best || leg.distanceM > best.leg.distanceM)) best = { key: target, leg };
  }
  return best;
}

/**
 * 从 startKey 出发、**只沿指定编号的道**能走到的全部节点。
 *
 * 一个编号在 OSM 里可以对应好几截互不相连的道，所以「这条道上的节点」
 * 和「从这里沿这条道走得到的节点」是两回事，规划时要的是后者。
 */
export function componentAlongRef(
  graph: TaxiGraph,
  startKey: string,
  ref: string,
): Set<string> {
  const target = ref.trim().toUpperCase();
  const seen = new Set<string>([startKey]);
  const stack = [startKey];
  while (stack.length > 0) {
    for (const edge of graph.adjacency.get(stack.pop()!) ?? []) {
      if (seen.has(edge.to)) continue;
      if (edge.ref?.toUpperCase() !== target) continue;
      seen.add(edge.to);
      stack.push(edge.to);
    }
  }
  return seen;
}

/** 集合里离 origin 直线距离最近的那个点的坐标 */
function nearestPointOfSet(
  graph: TaxiGraph,
  origin: MapCoordinate | undefined,
  keys: ReadonlySet<string>,
): MapCoordinate | undefined {
  if (!origin) return undefined;
  let best: MapCoordinate | undefined;
  let bestDistance = Number.POSITIVE_INFINITY;
  for (const key of keys) {
    const node = graph.nodes.get(key);
    if (!node) continue;
    const distance = distanceInMeters(
      origin.latitude,
      origin.longitude,
      node.latitude,
      node.longitude,
    );
    if (distance < bestDistance) {
      bestDistance = distance;
      best = node;
    }
  }
  return best;
}

/** 候选集合里离 aim 直线距离最近的节点键 */
function closestTo(
  graph: TaxiGraph,
  keys: ReadonlySet<string>,
  aim: MapCoordinate,
): string | undefined {
  let best: string | undefined;
  let bestDistance = Number.POSITIVE_INFINITY;
  for (const key of keys) {
    const node = graph.nodes.get(key);
    if (!node) continue;
    const distance = distanceInMeters(
      aim.latitude,
      aim.longitude,
      node.latitude,
      node.longitude,
    );
    if (distance < bestDistance) {
      bestDistance = distance;
      best = key;
    }
  }
  return best;
}

/** 首尾相接地拼接多段路径（去掉接缝上重复的那个点） */
export function concatPaths(legs: readonly TaxiPath[]): TaxiPath {
  const points: MapCoordinate[] = [];
  const refs: string[] = [];
  let distanceM = 0;
  for (const leg of legs) {
    const slice = points.length === 0 ? leg.points : leg.points.slice(1);
    points.push(...slice);
    refs.push(...leg.refs);
    distanceM += leg.distanceM;
  }
  return { points, distanceM, refs: dedupeAdjacent(refs) };
}

/**
 * 把一条路径按滑行道编号切成可读的分段。
 *
 * 管制指令是按编号念的（"A5, B, M"），所以高亮出来也该按编号分段，
 * 而不是把几十个 OSM way 一段段列出来。
 */
export function summarizePathByRef(
  graph: TaxiGraph,
  path: TaxiPath,
): { ref: string | undefined; distanceM: number }[] {
  const result: { ref: string | undefined; distanceM: number }[] = [];
  for (let i = 1; i < path.points.length; i += 1) {
    const fromKey = nodeKey(path.points[i - 1]);
    const toKey = nodeKey(path.points[i]);
    const edge = (graph.adjacency.get(fromKey) ?? []).find((item) => item.to === toKey);
    if (!edge) continue;
    const last = result[result.length - 1];
    if (last && last.ref === edge.ref) {
      last.distanceM += edge.distanceM;
    } else {
      result.push({ ref: edge.ref, distanceM: edge.distanceM });
    }
  }
  return result;
}
