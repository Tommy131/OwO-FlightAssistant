import { describe, expect, it } from 'vitest';

import { WsDeltaAssembler } from './ws-delta-assembler';

describe('WsDeltaAssembler', () => {
  it('把全量帧原样交给上层，并记住基准', () => {
    const assembler = new WsDeltaAssembler();
    const frame = {
      type: 'snapshot',
      seq: 1,
      simulator_type: 'xplane',
      client_dataset: { altitude_ft: 1000 },
    };

    const result = assembler.accept(frame);

    expect(result.needsResync).toBe(false);
    expect(result.body).toBe(frame);
    expect(assembler.hasBaseline).toBe(true);
  });

  it('老版本中间件不带 type 时按全量处理', () => {
    const assembler = new WsDeltaAssembler();
    const result = assembler.accept({ client_dataset: { altitude_ft: 1000 } });

    expect(result.needsResync).toBe(false);
    expect(result.body).not.toBeNull();
    expect(assembler.hasBaseline).toBe(true);
  });

  it('把增量合并回基准还原出完整 body', () => {
    const assembler = new WsDeltaAssembler();
    assembler.accept({
      type: 'snapshot',
      seq: 1,
      client_dataset: { altitude_ft: 1000, heading_deg: 90, nearest: { icao: 'ZBAA' } },
    });

    const result = assembler.accept({
      type: 'delta',
      seq: 2,
      base_seq: 1,
      simulator_version: 'X-Plane 12',
      changed: { client_dataset: { altitude_ft: 1200 } },
      removed: [],
    });

    expect(result.needsResync).toBe(false);
    expect(result.body?.client_dataset).toEqual({
      altitude_ft: 1200,
      heading_deg: 90,
      nearest: { icao: 'ZBAA' },
    });
    // 信封字段要保留下来
    expect(result.body?.simulator_version).toBe('X-Plane 12');
    // 增量的原始字段不该泄漏给上层
    expect(result.body?.changed).toBeUndefined();
    expect(result.body?.removed).toBeUndefined();
  });

  it('按路径数组删除嵌套字段', () => {
    const assembler = new WsDeltaAssembler();
    assembler.accept({
      type: 'snapshot',
      seq: 1,
      client_dataset: { nearest: { icao: 'ZBAA', label: '最近机场' } },
    });

    const result = assembler.accept({
      type: 'delta',
      seq: 2,
      base_seq: 1,
      changed: {},
      removed: [['client_dataset', 'nearest', 'label']],
    });

    expect(result.body?.client_dataset).toEqual({ nearest: { icao: 'ZBAA' } });
  });

  it('键名里带点号和斜杠时路径不会被拆错', () => {
    const assembler = new WsDeltaAssembler();
    assembler.accept({
      type: 'snapshot',
      seq: 1,
      raw_dataset: { DataRefs: { 'sim/flightmodel.position': 1, keep: 2 } },
    });

    const result = assembler.accept({
      type: 'delta',
      seq: 2,
      base_seq: 1,
      changed: {},
      removed: [['raw_dataset', 'DataRefs', 'sim/flightmodel.position']],
    });

    expect(result.body?.raw_dataset).toEqual({ DataRefs: { keep: 2 } });
  });

  it('数组整体替换而不是逐元素合并', () => {
    const assembler = new WsDeltaAssembler();
    assembler.accept({
      type: 'snapshot',
      seq: 1,
      client_dataset: { ai_aircraft: [{ id: 'A' }, { id: 'B' }] },
    });

    const result = assembler.accept({
      type: 'delta',
      seq: 2,
      base_seq: 1,
      changed: { client_dataset: { ai_aircraft: [{ id: 'C' }] } },
      removed: [],
    });

    expect(result.body?.client_dataset).toEqual({ ai_aircraft: [{ id: 'C' }] });
  });

  it('没有基准就收到增量时要求重同步', () => {
    const assembler = new WsDeltaAssembler();
    const result = assembler.accept({ type: 'delta', seq: 5, base_seq: 4, changed: {} });

    expect(result.body).toBeNull();
    expect(result.needsResync).toBe(true);
  });

  it('base_seq 对不上说明丢帧，必须要求重同步而不是硬合并', () => {
    const assembler = new WsDeltaAssembler();
    assembler.accept({ type: 'snapshot', seq: 1, client_dataset: { altitude_ft: 1000 } });

    const result = assembler.accept({
      type: 'delta',
      seq: 4,
      base_seq: 3,
      changed: { client_dataset: { altitude_ft: 9999 } },
    });

    expect(result.body).toBeNull();
    expect(result.needsResync).toBe(true);
  });

  it('重同步后的全量帧能重新接上增量流', () => {
    const assembler = new WsDeltaAssembler();
    assembler.accept({ type: 'snapshot', seq: 1, client_dataset: { altitude_ft: 1000 } });
    expect(assembler.accept({ type: 'delta', seq: 4, base_seq: 3, changed: {} }).needsResync).toBe(
      true,
    );

    assembler.accept({ type: 'snapshot', seq: 5, client_dataset: { altitude_ft: 2000 } });
    const result = assembler.accept({
      type: 'delta',
      seq: 6,
      base_seq: 5,
      changed: { client_dataset: { altitude_ft: 2100 } },
    });

    expect(result.needsResync).toBe(false);
    expect(result.body?.client_dataset).toEqual({ altitude_ft: 2100 });
  });

  it('删除嵌套字段不会改坏上一帧交出去的对象', () => {
    const assembler = new WsDeltaAssembler();
    const first = assembler.accept({
      type: 'snapshot',
      seq: 1,
      client_dataset: { nearest: { icao: 'ZBAA', label: '最近机场' } },
    });
    const firstNearest = (first.body?.client_dataset as { nearest: unknown }).nearest;

    assembler.accept({
      type: 'delta',
      seq: 2,
      base_seq: 1,
      changed: {},
      removed: [['client_dataset', 'nearest', 'label']],
    });

    expect(firstNearest).toEqual({ icao: 'ZBAA', label: '最近机场' });
  });

  it('reset 之后丢弃基准', () => {
    const assembler = new WsDeltaAssembler();
    assembler.accept({ type: 'snapshot', seq: 1, client_dataset: {} });
    assembler.reset();

    expect(assembler.hasBaseline).toBe(false);
    expect(assembler.accept({ type: 'delta', seq: 2, base_seq: 1 }).needsResync).toBe(true);
  });

  it('removed 里形状不对的项被忽略而不是抛异常', () => {
    const assembler = new WsDeltaAssembler();
    assembler.accept({ type: 'snapshot', seq: 1, client_dataset: { a: 1 } });

    const result = assembler.accept({
      type: 'delta',
      seq: 2,
      base_seq: 1,
      changed: {},
      removed: ['client_dataset.a', [], [1, 2], null],
    });

    expect(result.body?.client_dataset).toEqual({ a: 1 });
  });
});
