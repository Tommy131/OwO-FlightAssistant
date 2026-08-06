import { describe, expect, it } from 'vitest';
import {
  extractLowestCeiling,
  extractWorstVisibility,
  parseCeilingFt,
  parseVisibilitySm,
  resolveRule,
} from './metar-decode';

/**
 * METAR/TAF 解码
 *
 * 报文里同一个量有好几种写法（能见度可以是米也可以是英里，还能是分数），
 * 飞行规则又是靠阈值分档的 —— 这两处都是「写错了也不报错，只是结论不对」，
 * 而结论会直接显示给飞行员看。边界值逐个钉住。
 */

describe('parseVisibilitySm', () => {
  it('ICAO 四位数按米换算成法定英里', () => {
    // 1609.344 m = 1 SM
    expect(parseVisibilitySm('1609')).toBeCloseTo(1, 2);
    expect(parseVisibilitySm('0800')).toBeCloseTo(0.497, 2);
  });

  it('9999 表示 10km 以上，约 6.2 SM', () => {
    expect(parseVisibilitySm('9999')).toBeCloseTo(6.21, 1);
  });

  it('FAA 英里制：整数、分数、P/M 前缀', () => {
    expect(parseVisibilitySm('6SM')).toBe(6);
    expect(parseVisibilitySm('1/4SM')).toBe(0.25);
    // P = plus（大于），M = minus（小于），前缀只是修饰，数值照取
    expect(parseVisibilitySm('P6SM')).toBe(6);
    expect(parseVisibilitySm('M1/4SM')).toBe(0.25);
  });

  it('取不到就返回 undefined，不猜 0', () => {
    // 0 会被判成 LIFR，和「没有数据」完全是两回事
    expect(parseVisibilitySm(undefined)).toBeUndefined();
    expect(parseVisibilitySm('')).toBeUndefined();
    expect(parseVisibilitySm('CAVOK')).toBeUndefined();
  });

  it('分母为 0 不产出 Infinity', () => {
    expect(parseVisibilitySm('1/0SM')).toBeUndefined();
  });
});

describe('parseCeilingFt', () => {
  it('只有 BKN/OVC/VV 构成云幕，FEW/SCT 不算', () => {
    expect(parseCeilingFt('BKN012')).toBe(1200);
    expect(parseCeilingFt('OVC003')).toBe(300);
    expect(parseCeilingFt('VV002')).toBe(200);
    // 少云/疏云不构成云幕，不能拿来判飞行规则
    expect(parseCeilingFt('FEW005 SCT010')).toBeUndefined();
  });

  it('多层云取最低的一层', () => {
    expect(parseCeilingFt('FEW005 BKN020 OVC008')).toBe(800);
  });

  it('没有云层信息返回 undefined', () => {
    expect(parseCeilingFt(undefined)).toBeUndefined();
    expect(parseCeilingFt('')).toBeUndefined();
  });
});

describe('resolveRule', () => {
  it('按 FAA 阈值分档', () => {
    expect(resolveRule(10, 5000)).toBe('VFR');
    expect(resolveRule(4, 2000)).toBe('MVFR');
    expect(resolveRule(2, 800)).toBe('IFR');
    expect(resolveRule(0.5, 200)).toBe('LIFR');
  });

  it('两个条件取更严的那个', () => {
    // 能见度很好但云底极低 → 仍是 LIFR
    expect(resolveRule(10, 300)).toBe('LIFR');
    // 云底很高但能见度极差 → 仍是 LIFR
    expect(resolveRule(0.5, 10000)).toBe('LIFR');
  });

  it('边界值落在正确的一档', () => {
    // 云幕 500 不是 LIFR（<500 才是），3000 仍算 MVFR（<=3000）
    expect(resolveRule(undefined, 499)).toBe('LIFR');
    expect(resolveRule(undefined, 500)).toBe('IFR');
    expect(resolveRule(undefined, 999)).toBe('IFR');
    expect(resolveRule(undefined, 1000)).toBe('MVFR');
    expect(resolveRule(undefined, 3000)).toBe('MVFR');
    expect(resolveRule(undefined, 3001)).toBe('VFR');
    // 能见度 5 仍算 MVFR（<=5），超过才是 VFR
    expect(resolveRule(5, undefined)).toBe('MVFR');
    expect(resolveRule(5.1, undefined)).toBe('VFR');
  });

  it('两个都缺时给 VFR —— 这是已知的乐观兜底', () => {
    // 记录既有行为：无数据时不阻断显示。调用方负责先判断有没有数据
    expect(resolveRule(undefined, undefined)).toBe('VFR');
  });
});

describe('从整段报文提取', () => {
  const metar = 'ZBAA 052300Z 01004MPS 0800 R36L/1200N BKN008 OVC020 M02/M04 Q1024';

  it('取最差能见度', () => {
    // 报文里有 0800（能见度）与 1200（跑道视程），取更差的
    expect(extractWorstVisibility(metar)).toBeCloseTo(0.497, 2);
  });

  it('取最低云幕', () => {
    expect(extractLowestCeiling(metar)).toBe(800);
  });

  it('无相关字段时返回 undefined', () => {
    expect(extractWorstVisibility('ZBAA 052300Z CAVOK')).toBeUndefined();
    expect(extractLowestCeiling('ZBAA 052300Z CAVOK')).toBeUndefined();
  });
});
