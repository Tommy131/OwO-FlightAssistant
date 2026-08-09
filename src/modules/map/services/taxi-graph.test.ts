import { describe, expect, it } from 'vitest';
import {
  buildTaxiGraph,
  dedupeAdjacent,
  nearestNode,
  nodeKey,
  parseTaxiClearance,
  planTaxiRouteByRefs,
  componentAlongRef,
  concatPaths,
  nodesOnRef,
  shortestTaxiPath,
  summarizePathByRef,
} from './taxi-graph';
import type { MapAerowayFeature } from '../models/map-models';
import rcnnFixture from './__fixtures__/aeroway-rcnn.json';

/**
 * 滑行道路网
 *
 * 连通性靠坐标**精确相等**，刻意不做距离吸附：
 * 机场里的平行滑行道间距只有十几米，一旦吸附会被粘成一个节点，
 * 规划出穿越草坪的路线 —— 比断开危险得多。
 */

const at = (lat: number, lon: number) => ({ latitude: lat, longitude: lon });

/** 造一条要素；坐标用度数，1e-4 度约 11 米 */
const way = (
  kind: string,
  points: [number, number][],
  ref?: string,
): MapAerowayFeature => ({
  kind: kind as MapAerowayFeature['kind'],
  ref,
  closed: false,
  points: points.map(([lat, lon]) => at(lat, lon)),
});

/**
 *  A 道（东西）:  n0 ── n1 ── n2
 *  B 道（南北）:        n1 ── n3
 *  跑道       :  n2 ────────── n3   （抄近道用，应被惩罚权重挡住）
 */
const n0: [number, number] = [40.0, 116.0];
const n1: [number, number] = [40.0, 116.001];
const n2: [number, number] = [40.0, 116.002];
const n3: [number, number] = [40.001, 116.001];

const sampleFeatures = (): MapAerowayFeature[] => [
  way('taxiway', [n0, n1], 'A'),
  way('taxiway', [n1, n2], 'A'),
  way('taxiway', [n1, n3], 'B'),
  way('runway', [n2, n3], '09/27'),
];

describe('buildTaxiGraph', () => {
  it('相邻 way 共享端点即连成图', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    expect(graph.nodes.size).toBe(4);
    // n1 是三岔口：A 的两段 + B
    expect(graph.adjacency.get(nodeKey(at(...n1)))).toHaveLength(3);
  });

  it('无向图：两个方向都要有边', () => {
    const graph = buildTaxiGraph([way('taxiway', [n0, n1], 'A')]);
    expect(graph.adjacency.get(nodeKey(at(...n0)))![0].to).toBe(nodeKey(at(...n1)));
    expect(graph.adjacency.get(nodeKey(at(...n1)))![0].to).toBe(nodeKey(at(...n0)));
  });

  it('停机坪不参与路网 —— 那是面，连不成线', () => {
    const graph = buildTaxiGraph([way('apron', [n0, n1]), way('helipad', [n1, n2])]);
    expect(graph.nodes.size).toBe(0);
  });

  it('相距十几米的平行滑行道必须保持独立 —— 不做吸附', () => {
    /*
     * 1e-4 度纬度约 11 米，正是平行滑行道之间的典型间距。
     * 建图若按坐标取整（哪怕只到小数点后 4 位）就会把这两条粘成一条，
     * 规划出来的路线会从一条滑行道凭空跨到另一条上 —— 中间是草坪。
     */
    const graph = buildTaxiGraph([
      way('taxiway', [n0, n1], 'A'),
      way('taxiway', [[40.0001, 116.0], [40.0001, 116.001]], 'A2'),
    ]);
    expect(graph.nodes.size).toBe(4);
    // 两条道之间不该凭空多出连接
    expect(
      shortestTaxiPath(graph, nodeKey(at(...n0)), nodeKey(at(40.0001, 116.001))),
    ).toBeNull();
  });

  it('亚米级的坐标差异同样不合并', () => {
    // OSM 共享节点是逐位相同的；只要不完全相同就是两个点，不去猜
    const graph = buildTaxiGraph([
      way('taxiway', [n0, n1], 'A'),
      way('taxiway', [[40.000001, 116.0], [40.000001, 116.001]], 'A2'),
    ]);
    expect(graph.nodes.size).toBe(4);
  });

  it('自环丢弃', () => {
    const graph = buildTaxiGraph([way('taxiway', [n0, n0, n1], 'A')]);
    expect(graph.adjacency.get(nodeKey(at(...n0)))).toHaveLength(1);
  });

  it('空 ref 归一成 undefined，不是空串', () => {
    const graph = buildTaxiGraph([way('taxiway', [n0, n1], '  ')]);
    expect(graph.adjacency.get(nodeKey(at(...n0)))![0].ref).toBeUndefined();
  });

  it('要素为空或只有一个点时不炸', () => {
    expect(() => buildTaxiGraph([])).not.toThrow();
    expect(buildTaxiGraph([way('taxiway', [n0])]).nodes.size).toBe(0);
  });
});

describe('shortestTaxiPath', () => {
  it('走出连通的最短路径', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    const path = shortestTaxiPath(graph, nodeKey(at(...n0)), nodeKey(at(...n3)))!;
    expect(path.points.map((p) => nodeKey(p))).toEqual([
      nodeKey(at(...n0)),
      nodeKey(at(...n1)),
      nodeKey(at(...n3)),
    ]);
    expect(path.distanceM).toBeGreaterThan(0);
  });

  it('宁可绕也不上跑道', () => {
    // n2 → n3 直连是跑道；惩罚权重应把它挡回 n2→n1→n3
    const graph = buildTaxiGraph(sampleFeatures());
    const path = shortestTaxiPath(graph, nodeKey(at(...n2)), nodeKey(at(...n3)))!;
    expect(path.points).toHaveLength(3);
    expect(path.points[1]).toEqual(at(...n1));
  });

  it('惩罚设为 1 时就会直接穿跑道 —— 说明惩罚确实在起作用', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    const path = shortestTaxiPath(graph, nodeKey(at(...n2)), nodeKey(at(...n3)), {
      penalizeRunway: 1,
    })!;
    expect(path.points).toHaveLength(2);
  });

  it('起点即终点时给单点零距离，而不是 null', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    const path = shortestTaxiPath(graph, nodeKey(at(...n0)), nodeKey(at(...n0)))!;
    expect(path.points).toHaveLength(1);
    expect(path.distanceM).toBe(0);
  });

  it('不连通时返回 null，而不是给一条穿越草坪的直线', () => {
    const graph = buildTaxiGraph([
      way('taxiway', [n0, n1], 'A'),
      way('taxiway', [[41.0, 117.0], [41.0, 117.001]], 'Z'),
    ]);
    const path = shortestTaxiPath(graph, nodeKey(at(...n0)), nodeKey(at(41.0, 117.001)));
    expect(path).toBeNull();
  });

  it('起终点不在图上时返回 null', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    expect(shortestTaxiPath(graph, 'nope', nodeKey(at(...n0)))).toBeNull();
    expect(shortestTaxiPath(graph, nodeKey(at(...n0)), 'nope')).toBeNull();
  });

  it('refs 去掉相邻重复 —— 一条滑行道被切成几十段', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    const path = shortestTaxiPath(graph, nodeKey(at(...n0)), nodeKey(at(...n2)))!;
    // n0→n1→n2 全是 A 道，编号只该出现一次
    expect(path.refs).toEqual(['A']);
  });
});

describe('nearestNode', () => {
  it('找最近的节点', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    expect(nearestNode(graph, at(40.0, 116.00105))).toBe(nodeKey(at(...n1)));
  });

  it('超出上限返回 null —— 机位离滑行道太远说明数据对不上', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    expect(nearestNode(graph, at(41.0, 117.0), 200)).toBeNull();
  });

  it('空图返回 null', () => {
    expect(nearestNode(buildTaxiGraph([]), at(40, 116))).toBeNull();
  });
});

describe('parseTaxiClearance', () => {
  it('解析典型放行指令', () => {
    const got = parseTaxiClearance('Taxi to holding point via A5, B, hold short of 36L');
    expect(got.refs).toEqual(['A5', 'B']);
    expect(got.holdShort).toBe('36L');
  });

  it('跑道号不会被当成滑行道编号', () => {
    // hold short 之后的内容整段剪掉，否则 36L 会混进 refs
    expect(parseTaxiClearance('A5 hold short 36L').refs).toEqual(['A5']);
  });

  it('连接词与套话不算编号', () => {
    const got = parseTaxiClearance('TAXI VIA M THEN N AND CROSS RWY 08R');
    expect(got.refs).toEqual(['M', 'N']);
  });

  it('大小写与多余空白都能吃下', () => {
    expect(parseTaxiClearance('  taxi via  k6 , l ').refs).toEqual(['K6', 'L']);
  });

  it('HS 简写也认', () => {
    expect(parseTaxiClearance('B HS 25R').holdShort).toBe('25R');
  });

  it('hold short 之后的滑行道不算进本段指令', () => {
    /*
     * "via A5, hold short of 36L, then B" —— B 要等过了跑道才滑。
     * 混进当前这段，高亮出来的路线就会一路穿过跑道。
     */
    const got = parseTaxiClearance('via A5 hold short of 36L then B');
    expect(got.refs).toEqual(['A5']);
    expect(got.holdShort).toBe('36L');
  });

  it('没有 hold short 时该项为 undefined', () => {
    expect(parseTaxiClearance('via A B C').holdShort).toBeUndefined();
  });

  it('空串不炸', () => {
    expect(parseTaxiClearance('')).toEqual({ refs: [], holdShort: undefined });
  });
});

describe('summarizePathByRef', () => {
  it('按滑行道编号合并分段', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    const path = shortestTaxiPath(graph, nodeKey(at(...n0)), nodeKey(at(...n3)))!;
    const summary = summarizePathByRef(graph, path);
    // n0→n1 是 A，n1→n3 是 B
    expect(summary.map((s) => s.ref)).toEqual(['A', 'B']);
    expect(summary[0].distanceM).toBeGreaterThan(0);
  });

  it('同编号的连续段累加成一段', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    const path = shortestTaxiPath(graph, nodeKey(at(...n0)), nodeKey(at(...n2)))!;
    const summary = summarizePathByRef(graph, path);
    expect(summary).toHaveLength(1);
    expect(summary[0].ref).toBe('A');
  });
});

describe('nodesOnRef', () => {
  it('列出某个编号覆盖的全部节点', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    // A 道是 n0─n1─n2 两段
    expect(nodesOnRef(graph, 'A')).toEqual(
      new Set([nodeKey(at(...n0)), nodeKey(at(...n1)), nodeKey(at(...n2))]),
    );
  });

  it('数据里的编号是小写时也要认 —— OSM 里 "b" 与 "B" 混用', () => {
    // 只把查询串归一是不够的，边上存的 ref 同样要归一
    const graph = buildTaxiGraph([way('taxiway', [n0, n1], 'b')]);
    expect(nodesOnRef(graph, 'B').size).toBe(2);
    expect(nodesOnRef(graph, 'b').size).toBe(2);
  });

  it('不存在的编号返回空集合', () => {
    expect(nodesOnRef(buildTaxiGraph(sampleFeatures()), 'ZZ').size).toBe(0);
  });
});

describe('planTaxiRouteByRefs', () => {
  it('按顺序经过指定滑行道', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    const path = planTaxiRouteByRefs(graph, nodeKey(at(...n2)), ['A', 'B'])!;
    expect(path).not.toBeNull();
    // 从 n2 出发已在 A 道上，随后必须踏上 B 道（n1 或 n3）
    const keys = path.points.map((p) => nodeKey(p));
    expect(keys[0]).toBe(nodeKey(at(...n2)));
    expect(nodesOnRef(graph, 'B').has(keys[keys.length - 1])).toBe(true);
  });

  it('踏上目标滑行道时选最近的入口，而不是撞见的第一个', () => {
    /*
     *  起点 s ── A ── p（近端）
     *  长道 L: p ─────────────────── q（远端）
     * 指令说"走 L"，就该从 p 上道；挑到 q 会白白多滑一公里。
     */
    const s0: [number, number] = [40.0, 116.0];
    const p: [number, number] = [40.0, 116.001];
    const q: [number, number] = [40.0, 116.02];
    /*
     * 要素顺序是刻意的：把远端 q 排在前面，让它成为候选集合里第一个被
     * 枚举到的节点。否则「取第一个」那种写法会蒙对，这条测试也就证明不了
     * 代码真的在比距离。
     */
    const graph = buildTaxiGraph([
      way('taxiway', [q, p], 'L'),
      way('taxiway', [s0, p], 'A'),
    ]);
    const path = planTaxiRouteByRefs(graph, nodeKey(at(...s0)), ['L'])!;
    // 从近端 p 并上 L 道（而不是先跑到远端 q 再倒回来）
    const keys = path.points.map((point) => nodeKey(point));
    expect(keys[1]).toBe(nodeKey(at(...p)));
    // 并上去之后沿 L 滑到尽头 q —— 指令说"走 L"就是走完它
    expect(keys[keys.length - 1]).toBe(nodeKey(at(...q)));
  });

  it('已经在该道上则不再并线，直接沿它滑到尽头', () => {
    /*
     * 起点 n0 已在 A 道上（A 是 n0─n1─n2）。
     * "taxi via A" 的意思是沿 A 滑，而不是原地不动 ——
     * 只判「已在该道上」就收工的话，高亮出来会是一个点。
     */
    const graph = buildTaxiGraph(sampleFeatures());
    const path = planTaxiRouteByRefs(graph, nodeKey(at(...n0)), ['A'])!;
    expect(path.points.map((point) => nodeKey(point))).toEqual([
      nodeKey(at(...n0)),
      nodeKey(at(...n1)),
      nodeKey(at(...n2)),
    ]);
  });

  it('指令里出现机场没有的滑行道 → null，不糊一条差不多的路线', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    expect(planTaxiRouteByRefs(graph, nodeKey(at(...n0)), ['A', 'ZZ'])).toBeNull();
  });

  it('某一段接不上时整体返回 null', () => {
    // 另起一座孤立的机场，B 道够得着但 Z 道在天边
    const graph = buildTaxiGraph([
      ...sampleFeatures(),
      way('taxiway', [[41.0, 117.0], [41.0, 117.001]], 'Z'),
    ]);
    expect(planTaxiRouteByRefs(graph, nodeKey(at(...n0)), ['A', 'Z'])).toBeNull();
  });

  it('可以额外指定终点（hold short 的跑道口）', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    const path = planTaxiRouteByRefs(
      graph,
      nodeKey(at(...n0)),
      ['B'],
      nodeKey(at(...n2)),
    )!;
    expect(nodeKey(path.points[path.points.length - 1])).toBe(nodeKey(at(...n2)));
  });

  it('refs 为空且没有终点时给单点，而不是 null', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    const path = planTaxiRouteByRefs(graph, nodeKey(at(...n0)), [])!;
    expect(path.points).toHaveLength(1);
  });

  it('真实指令端到端：解析 → 规划', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    const clearance = parseTaxiClearance('taxi via A then B');
    const path = planTaxiRouteByRefs(graph, nodeKey(at(...n2)), clearance.refs);
    expect(path).not.toBeNull();
    expect(clearance.refs).toEqual(['A', 'B']);
  });
});

describe('concatPaths', () => {
  it('接缝处不重复计点', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    const first = shortestTaxiPath(graph, nodeKey(at(...n0)), nodeKey(at(...n1)))!;
    const second = shortestTaxiPath(graph, nodeKey(at(...n1)), nodeKey(at(...n2)))!;
    const joined = concatPaths([first, second]);
    expect(joined.points).toHaveLength(3);
    expect(joined.distanceM).toBeCloseTo(first.distanceM + second.distanceM, 6);
    // 全程都在 A 道上，编号只出现一次
    expect(joined.refs).toEqual(['A']);
  });
});

describe('dedupeAdjacent', () => {
  it('只去掉相邻重复，不去重整体', () => {
    // A → B → A 是真的绕回来了，不能压成 A → B
    expect(dedupeAdjacent(['A', 'A', 'B', 'B', 'A'])).toEqual(['A', 'B', 'A']);
    expect(dedupeAdjacent([])).toEqual([]);
  });
});

/**
 * 真实机场数据（RCNN 台南，OSM 原样导出）
 *
 * 合成的四节点图证明不了连通性假设成不成立 —— 那恰恰是这套东西的成败所在。
 * 这份夹具钉住的是「按坐标精确相等就能连成一张连通图」这个前提：
 * 哪天 Overpass 换了坐标精度或者建图改了键的算法，这里会先炸。
 */
describe('真实机场数据（RCNN）', () => {
  const features = (rcnnFixture as { features: MapAerowayFeature[] }).features;

  it('按坐标精确相等即可连成一张图', () => {
    const graph = buildTaxiGraph(features);
    expect(graph.nodes.size).toBeGreaterThan(300);

    // 全图应当基本连通：从任一点出发能走到绝大多数节点
    const start = [...graph.nodes.keys()][0];
    const seen = new Set([start]);
    const stack = [start];
    while (stack.length > 0) {
      for (const edge of graph.adjacency.get(stack.pop()!) ?? []) {
        if (!seen.has(edge.to)) {
          seen.add(edge.to);
          stack.push(edge.to);
        }
      }
    }
    // 实测 100% 连通；留一点余量，低于九成说明连通性假设塌了
    expect(seen.size / graph.nodes.size).toBeGreaterThan(0.9);
  });

  it('能在真实路网上规划出一条带编号的路线', () => {
    const graph = buildTaxiGraph(features);
    const keys = [...graph.nodes.keys()];
    const path = shortestTaxiPath(graph, keys[0], keys[keys.length - 1]);
    expect(path).not.toBeNull();
    expect(path!.points.length).toBeGreaterThan(2);
    // 真实机场的滑行距离不该是几米，也不该是几十公里
    expect(path!.distanceM).toBeGreaterThan(100);
    expect(path!.distanceM).toBeLessThan(20000);
    // 路径首尾必须正好是给定的起终点
    expect(nodeKey(path!.points[0])).toBe(keys[0]);
    expect(nodeKey(path!.points[path!.points.length - 1])).toBe(keys[keys.length - 1]);
  });
});

/**
 * 按指令规划：被点名的道必须真的走过
 *
 * 这条是三次返工换来的。前两版都会返回一条「看着像模像样其实没走那条道」的
 * 路线，EDDM 实测指令 `via E1, S, B2` 规划出来压根没经过 B2，函数还报成功。
 * 两个坑：
 *   ① 走到某条道的端点 ≠ 沿着它滑过；
 *   ② 同一个编号在 OSM 里可能是好几截互不相连的道，
 *      出口必须在「从入口沿该编号可达的那一截」里挑。
 */
describe('真实路网上的指令规划（RCNN）', () => {
  const features = (rcnnFixture as { features: MapAerowayFeature[] }).features;
  const graph = buildTaxiGraph(features);
  const start = [...graph.nodes.keys()][0];

  /**
   * 断言：路径**依次**经过每条被点名的道。
   *
   * 这里不断言"每条道都留下了行驶里程"。小机场上两条道的交叉口可能正好是
   * 最近的入口，此时沿某条道的里程确实是零 —— 那是几何上诚实的结果，
   * 不该判失败。真正的契约是顺序：先到 D 上，再到 E 上，不能颠倒或跳过。
   */
  const expectVisitsInOrder = (refs: string[]) => {
    const path = planTaxiRouteByRefs(graph, start, refs);
    expect(path, `refs=${refs.join(',')} 应能规划出路线`).not.toBeNull();
    const keys = path!.points.map((point) => nodeKey(point));

    let cursor = 0;
    for (const ref of refs) {
      const on = nodesOnRef(graph, ref);
      const hit = keys.findIndex((key, index) => index >= cursor && on.has(key));
      expect(hit, `路径应在第 ${cursor} 点之后经过 ${ref}`).toBeGreaterThanOrEqual(0);
      cursor = hit;
    }
    return path!;
  };

  it('单条道：沿它滑完，而不是碰一下端点就算', () => {
    const path = planTaxiRouteByRefs(graph, start, ['D'])!;
    expect(path).not.toBeNull();
    // 只点名一条道时不存在"停在交叉口"的歧义，必须真的产生行驶里程
    expect(path.refs.map((r) => r.toUpperCase())).toContain('D');
  });

  it('两条道：按顺序经过', () => {
    expectVisitsInOrder(['D', 'E']);
  });

  it('三条道：按顺序经过', () => {
    expectVisitsInOrder(['E', 'D', 'F']);
  });

  it('道与道之间允许经过没被点名的连接段', () => {
    // 管制只念关键滑行道，中间的连接段不念但确实要走。
    // 所以规划结果里出现指令之外的编号是正常的，不能因此判失败。
    const path = planTaxiRouteByRefs(graph, start, ['D', 'F'])!;
    expect(path).not.toBeNull();
    expect(path.refs.length).toBeGreaterThanOrEqual(2);
  });
});

describe('componentAlongRef', () => {
  it('只沿指定编号扩散，碰到别的编号就停', () => {
    const graph = buildTaxiGraph(sampleFeatures());
    // 从 n0 沿 A 能到 n0/n1/n2，但到不了只有 B 才能去的 n3
    const reachable = componentAlongRef(graph, nodeKey(at(...n0)), 'A');
    expect(reachable).toEqual(
      new Set([nodeKey(at(...n0)), nodeKey(at(...n1)), nodeKey(at(...n2))]),
    );
    expect(reachable.has(nodeKey(at(...n3)))).toBe(false);
  });

  it('同名但断开的另一截不算可达', () => {
    // A 在两处各有一截，中间不相连 —— 这正是 EDDM 上让规划失败的那个形态
    const graph = buildTaxiGraph([
      way('taxiway', [n0, n1], 'A'),
      way('taxiway', [[41.0, 117.0], [41.0, 117.001]], 'A'),
    ]);
    const reachable = componentAlongRef(graph, nodeKey(at(...n0)), 'A');
    expect(reachable.size).toBe(2);
    expect(reachable.has(nodeKey(at(41.0, 117.0)))).toBe(false);
    // 但按编号取节点会把两截都算上 —— 两者不是一回事
    expect(nodesOnRef(graph, 'A').size).toBe(4);
  });
});
