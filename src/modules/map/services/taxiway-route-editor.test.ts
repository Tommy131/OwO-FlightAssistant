import { describe, expect, it } from 'vitest';
import {
  addNode,
  EMPTY_ROUTE,
  insertNodeBetween,
  MAX_UNDO_STEPS,
  moveNode,
  pushUndo,
  rebuildSegments,
  removeNode,
  updateNodeInfo,
  updateSegmentInfo,
  type TaxiwayRoute,
} from './taxiway-route-editor';
import type { MapCoordinate } from '../models/map-models';

/**
 * 滑行道路线编辑
 *
 * 全是**基于下标**的手术：插一个节点，它后面所有分段的 fromIndex/toIndex
 * 都要整体后移。错一位不抛异常，只是某条分段连到了隔壁节点上 —— 画出来
 * 仍然是一条线，只是连错地方。所以这里逐个断言分段的连接关系。
 */

const at = (lat: number, lon: number): MapCoordinate => ({ latitude: lat, longitude: lon });

/** 造一条 n 个节点的直线路线 */
function lineOf(n: number): TaxiwayRoute {
  let route = EMPTY_ROUTE;
  for (let i = 0; i < n; i++) route = addNode(route, at(i, 0));
  return route;
}

/** 把分段压成 "0->1,1->2" 便于断言 */
const shape = (route: TaxiwayRoute) =>
  route.segments.map((s) => `${s.fromIndex}->${s.toIndex}`).join(',');

describe('rebuildSegments', () => {
  it('n 个节点产生 n-1 条相邻分段', () => {
    expect(rebuildSegments([], [])).toEqual([]);
    expect(rebuildSegments([{ position: at(0, 0) }], [])).toEqual([]);
    expect(shape({ nodes: [], segments: rebuildSegments(lineOf(4).nodes, []) })).toBe(
      '0->1,1->2,2->3',
    );
  });

  it('沿用旧分段的名称与限速', () => {
    const previous = [{ fromIndex: 0, toIndex: 1, name: 'A1', speedLimitKt: 20 }];
    const rebuilt = rebuildSegments(lineOf(3).nodes, previous);
    expect(rebuilt[0].name).toBe('A1');
    expect(rebuilt[0].speedLimitKt).toBe(20);
    // 新增的那条没有旧信息可继承
    expect(rebuilt[1].name).toBeUndefined();
  });

  it('传空 previous 时旧信息一律丢弃', () => {
    const previous = [{ fromIndex: 0, toIndex: 1, name: 'A1' }];
    expect(rebuildSegments(lineOf(3).nodes, [])[0].name).toBeUndefined();
    expect(previous[0].name).toBe('A1'); // 不改传入的数组
  });
});

describe('addNode', () => {
  it('追加节点并接上新分段', () => {
    const route = lineOf(3);
    expect(route.nodes).toHaveLength(3);
    expect(shape(route)).toBe('0->1,1->2');
  });

  it('追加不打乱既有顺序，旧分段信息保留', () => {
    let route = lineOf(2);
    route = updateSegmentInfo(route, 0, { name: 'W1' })!;
    route = addNode(route, at(9, 9));
    expect(route.segments[0].name).toBe('W1');
  });

  it('不修改传入的路线', () => {
    const route = lineOf(2);
    addNode(route, at(5, 5));
    expect(route.nodes).toHaveLength(2);
  });
});

describe('moveNode', () => {
  it('只改坐标，拓扑不变', () => {
    const route = lineOf(3);
    const moved = moveNode(route, 1, at(99, 99))!;
    expect(moved.nodes[1].position).toEqual(at(99, 99));
    expect(shape(moved)).toBe('0->1,1->2');
    // 分段对象原样沿用（拓扑没变就不该重建）
    expect(moved.segments).toBe(route.segments);
  });

  it('保留该节点的名称等其它字段', () => {
    let route = lineOf(2);
    route = updateNodeInfo(route, 0, { name: 'N1' })!;
    const moved = moveNode(route, 0, at(7, 7))!;
    expect(moved.nodes[0].name).toBe('N1');
  });

  it('下标越界返回 null（而不是静默改错节点）', () => {
    const route = lineOf(2);
    expect(moveNode(route, -1, at(0, 0))).toBeNull();
    expect(moveNode(route, 2, at(0, 0))).toBeNull();
    expect(moveNode(EMPTY_ROUTE, 0, at(0, 0))).toBeNull();
  });
});

describe('removeNode', () => {
  it('删中间节点后分段重新首尾相接', () => {
    const route = lineOf(4); // 0->1,1->2,2->3
    const next = removeNode(route, 1)!;
    expect(next.nodes).toHaveLength(3);
    expect(shape(next)).toBe('0->1,1->2');
    // 删掉的是原来的 1 号点，剩下的应是 0/2/3
    expect(next.nodes.map((n) => n.position.latitude)).toEqual([0, 2, 3]);
  });

  it('删除会丢弃旧分段信息 —— 下标已经对不上了', () => {
    let route = lineOf(3);
    route = updateSegmentInfo(route, 0, { name: '0到1', speedLimitKt: 15 })!;
    const next = removeNode(route, 0)!;
    // 原来的 0→1 已经不存在，硬套会把限速安到别的分段上
    expect(next.segments[0]?.name).toBeUndefined();
  });

  it('删到只剩一个节点时没有分段', () => {
    const next = removeNode(lineOf(2), 0)!;
    expect(next.nodes).toHaveLength(1);
    expect(next.segments).toEqual([]);
  });

  it('下标越界返回 null', () => {
    expect(removeNode(lineOf(2), 5)).toBeNull();
    expect(removeNode(EMPTY_ROUTE, 0)).toBeNull();
  });
});

describe('insertNodeBetween', () => {
  it('插到分段中间，后续分段整体后移', () => {
    const route = lineOf(3); // 节点 0,1,2；分段 0->1,1->2
    const next = insertNodeBetween(route, 0)!;
    expect(next.nodes).toHaveLength(4);
    expect(shape(next)).toBe('0->1,1->2,2->3');
    // 新点插在原 0 和原 1 之间，取中点
    expect(next.nodes[1].position).toEqual(at(0.5, 0));
    // 原来的 1、2 号点顺延到 2、3
    expect(next.nodes.map((n) => n.position.latitude)).toEqual([0, 0.5, 1, 2]);
  });

  it('可以指定插入坐标', () => {
    const next = insertNodeBetween(lineOf(2), 0, at(42, 43))!;
    expect(next.nodes[1].position).toEqual(at(42, 43));
  });

  it('在最后一条分段上插入也正确', () => {
    const route = lineOf(3);
    const next = insertNodeBetween(route, 1)!;
    expect(next.nodes.map((n) => n.position.latitude)).toEqual([0, 1, 1.5, 2]);
  });

  it('分段下标不存在时返回 null', () => {
    expect(insertNodeBetween(lineOf(3), 9)).toBeNull();
    expect(insertNodeBetween(EMPTY_ROUTE, 0)).toBeNull();
    // 只有一个节点时没有任何分段
    expect(insertNodeBetween(lineOf(1), 0)).toBeNull();
  });
});

describe('updateSegmentInfo', () => {
  it('只改指定分段', () => {
    const route = lineOf(3);
    const next = updateSegmentInfo(route, 1, { name: 'W2', speedLimitKt: 25 })!;
    expect(next.segments[0].name).toBeUndefined();
    expect(next.segments[1].name).toBe('W2');
    expect(next.segments[1].speedLimitKt).toBe(25);
    // 拓扑不能因为改名而变
    expect(shape(next)).toBe('0->1,1->2');
  });

  it('下标越界返回 null', () => {
    expect(updateSegmentInfo(lineOf(3), 5, { name: 'x' })).toBeNull();
  });
});

describe('pushUndo', () => {
  it('压栈不改原栈', () => {
    const stack: TaxiwayRoute[] = [];
    const next = pushUndo(stack, lineOf(1));
    expect(stack).toHaveLength(0);
    expect(next).toHaveLength(1);
  });

  it('超过上限时丢掉最老的一步', () => {
    let stack: TaxiwayRoute[] = [];
    for (let i = 0; i < MAX_UNDO_STEPS + 10; i++) stack = pushUndo(stack, lineOf(i % 5));
    expect(stack).toHaveLength(MAX_UNDO_STEPS);
  });

  it('保留的是最近的若干步，不是最早的', () => {
    let stack: TaxiwayRoute[] = [];
    for (let i = 0; i < MAX_UNDO_STEPS + 3; i++) {
      stack = pushUndo(stack, addNode(EMPTY_ROUTE, at(i, 0)));
    }
    // 最后压入的那一步必须还在栈顶
    const top = stack[stack.length - 1];
    expect(top.nodes[0].position.latitude).toBe(MAX_UNDO_STEPS + 2);
  });
});

describe('连续编辑', () => {
  it('画线 → 插点 → 删点，分段始终首尾相接', () => {
    let route = lineOf(4);
    route = insertNodeBetween(route, 1)!;
    route = removeNode(route, 0)!;
    route = addNode(route, at(50, 50));

    // 不管怎么编辑，分段必须是 0->1,1->2,... 的连续链
    const expected = route.nodes.map((_, i) => `${i}->${i + 1}`).slice(0, -1).join(',');
    expect(shape(route)).toBe(expected);
    expect(route.segments).toHaveLength(route.nodes.length - 1);
  });
});
