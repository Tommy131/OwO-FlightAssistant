import { describe, expect, it } from 'vitest';

import {
  classifyFrequency,
  formatFrequencyValues,
  groupFrequencies,
  FREQUENCY_CATEGORY_COLOR,
  type FrequencyCategory,
} from './airport-frequencies';

describe('classifyFrequency', () => {
  it('认得常见全称', () => {
    expect(classifyFrequency('ATIS')).toBe('atis');
    expect(classifyFrequency('CLEARANCE')).toBe('clearance');
    expect(classifyFrequency('GROUND')).toBe('ground');
    expect(classifyFrequency('TOWER')).toBe('tower');
    expect(classifyFrequency('APPROACH')).toBe('approach');
    expect(classifyFrequency('DEPARTURE')).toBe('departure');
  });

  it('认得简写', () => {
    expect(classifyFrequency('TWR')).toBe('tower');
    expect(classifyFrequency('GND')).toBe('ground');
    expect(classifyFrequency('APP')).toBe('approach');
    expect(classifyFrequency('DEP')).toBe('departure');
    expect(classifyFrequency('CLNC DEL')).toBe('clearance');
  });

  it('大小写与分隔符都不影响判定', () => {
    expect(classifyFrequency('tower')).toBe('tower');
    expect(classifyFrequency('Clearance Delivery')).toBe('clearance');
    expect(classifyFrequency('GROUND_2')).toBe('ground');
    expect(classifyFrequency('APPROACH-1')).toBe('approach');
  });

  /*
   * 顺序即优先级：有些导航库把离场写成 "APPROACH/DEPARTURE"。
   * 按字母序或把 APPROACH 排在前面的话，离场会被吞进进近里。
   */
  it('DEPARTURE 优先于 APPROACH，不会被吞掉', () => {
    expect(classifyFrequency('APPROACH/DEPARTURE')).toBe('departure');
    expect(classifyFrequency('DEPARTURE/APPROACH')).toBe('departure');
  });

  it('空值与未知类型落到 other', () => {
    expect(classifyFrequency(undefined)).toBe('other');
    expect(classifyFrequency('')).toBe('other');
    expect(classifyFrequency('   ')).toBe('other');
    expect(classifyFrequency('FSS')).toBe('other');
  });
});

describe('groupFrequencies', () => {
  it('同类合并成一行', () => {
    const groups = groupFrequencies([
      { type: 'GROUND', value: '121.900' },
      { type: 'GROUND', value: '121.800' },
      { type: 'GROUND', value: '121.700' },
    ]);
    expect(groups).toHaveLength(1);
    expect(groups[0].values).toEqual(['121.900', '121.800', '121.700']);
  });

  // 导航库里第一条通常是主用频率，排序会把它挪走
  it('只去重、不排序，保留原始先后', () => {
    const groups = groupFrequencies([
      { type: 'TOWER', value: '124.300' },
      { type: 'TOWER', value: '118.500' },
      { type: 'TOWER', value: '124.300' },
    ]);
    expect(groups[0].values).toEqual(['124.300', '118.500']);
  });

  it('不同类别按固定顺序排，与实际调频先后一致', () => {
    const groups = groupFrequencies([
      { type: 'APPROACH', value: '119.000' },
      { type: 'ATIS', value: '127.600' },
      { type: 'TOWER', value: '124.300' },
      { type: 'GROUND', value: '121.900' },
      { type: 'CLEARANCE', value: '121.600' },
    ]);
    expect(groups.map((g) => g.category)).toEqual([
      'atis',
      'clearance',
      'ground',
      'tower',
      'approach',
    ]);
  });

  it('丢掉没有频率值的条目', () => {
    const groups = groupFrequencies([
      { type: 'TOWER', value: '' },
      { type: 'TOWER', value: '   ' },
      { type: 'TOWER', value: undefined },
      { type: 'TOWER', value: '118.500' },
    ]);
    expect(groups).toHaveLength(1);
    expect(groups[0].values).toEqual(['118.500']);
  });

  it('全空输入返回空数组，不炸', () => {
    expect(groupFrequencies([])).toEqual([]);
    expect(groupFrequencies([{ type: 'TOWER' }])).toEqual([]);
  });

  it('已知类别的标签统一大写，避免同类显示成两种写法', () => {
    const groups = groupFrequencies([
      { type: 'tower', value: '118.500' },
      { type: 'Tower', value: '124.300' },
    ]);
    expect(groups).toHaveLength(1);
    expect(groups[0].label).toBe('TOWER');
  });

  // other 类可能是 FSS、EMERGENCY 这些，原样显示比统一成 "OTHER" 有用
  it('other 类保留导航库的原始写法', () => {
    const groups = groupFrequencies([{ type: 'FSS', value: '122.200' }]);
    expect(groups[0].category).toBe('other');
    expect(groups[0].label).toBe('FSS');
  });

  it('类型缺失时 other 也有个兜底标签', () => {
    const groups = groupFrequencies([{ value: '122.200' }]);
    expect(groups[0].label).toBe('OTHER');
  });

  it('ZBAA 的真实频率表合并后只剩五行', () => {
    const groups = groupFrequencies([
      { type: 'ATIS', value: '127.600' },
      { type: 'ATIS', value: '128.650' },
      { type: 'CLEARANCE', value: '121.600' },
      { type: 'CLEARANCE', value: '121.650' },
      { type: 'GROUND', value: '121.900' },
      { type: 'GROUND', value: '121.800' },
      { type: 'GROUND', value: '121.700' },
      { type: 'GROUND', value: '121.750' },
      { type: 'GROUND', value: '121.850' },
      { type: 'TOWER', value: '124.300' },
      { type: 'TOWER', value: '118.500' },
      { type: 'TOWER', value: '118.050' },
      { type: 'APPROACH', value: '119.000' },
      { type: 'APPROACH', value: '126.010' },
    ]);
    expect(groups).toHaveLength(5);
    expect(formatFrequencyValues(groups[2].values)).toBe(
      '121.900 / 121.800 / 121.700 / 121.750 / 121.850',
    );
  });
});

describe('FREQUENCY_CATEGORY_COLOR', () => {
  it('每个类别都有配色，界面不会拿到 undefined', () => {
    const categories: FrequencyCategory[] = [
      'atis',
      'clearance',
      'ground',
      'tower',
      'approach',
      'departure',
      'center',
      'unicom',
      'other',
    ];
    for (const category of categories) {
      expect(FREQUENCY_CATEGORY_COLOR[category]).toBeTruthy();
    }
  });

  /*
   * 放行→地面→塔台→进近/离场 是实际会依次调到的频率，
   * 相邻两类撞色会让人念错频率。
   */
  it('管制流程上相邻的类别不撞色', () => {
    const sequence: FrequencyCategory[] = ['clearance', 'ground', 'tower', 'approach', 'departure'];
    const colors = sequence.map((category) => FREQUENCY_CATEGORY_COLOR[category]);
    expect(new Set(colors).size).toBe(sequence.length);
  });
});

describe('formatFrequencyValues', () => {
  it('用斜杠拼接', () => {
    expect(formatFrequencyValues(['118.500', '124.300'])).toBe('118.500 / 124.300');
  });

  it('单个值不加分隔符', () => {
    expect(formatFrequencyValues(['118.500'])).toBe('118.500');
  });
});
