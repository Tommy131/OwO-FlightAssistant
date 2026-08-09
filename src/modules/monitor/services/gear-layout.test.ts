import { describe, expect, it } from 'vitest';
import {
  effectiveGearRatio,
  resolveGearLayout,
  wheelsPerStrut,
} from './gear-layout';

/**
 * 起落架构型识别
 *
 * 构型是机型的固有属性，只能靠机型判 —— 收放比例只说明「现在放下了多少」，
 * 说明不了「有没有收放功能」：固定起落架的塞斯纳比例恒为 1，
 * 和一架已放下的 737 在数据上毫无区别。
 */

describe('resolveGearLayout', () => {
  it('737 是双轮主起、两支支柱', () => {
    const layout = resolveGearLayout('B738');
    expect(layout.retractable).toBe(true);
    expect(layout.bogie).toBe('dual');
    expect(layout.mainStruts).toBe(2);
  });

  it('747 是四支主起 —— 这是它最好认的特征', () => {
    // 两组挂机身、两组挂机翼；画成两支就和 737 没区别了
    const layout = resolveGearLayout('B744');
    expect(layout.mainStruts).toBe(4);
    expect(layout.bogie).toBe('bogie4');
  });

  it('777 是六轮小车', () => {
    expect(resolveGearLayout('B77W').bogie).toBe('bogie6');
    expect(wheelsPerStrut(resolveGearLayout('B77W').bogie)).toBe(6);
  });

  it('A320 全系都是双轮', () => {
    for (const code of ['A319', 'A320', 'A321', 'A20N']) {
      expect(resolveGearLayout(code).bogie, code).toBe('dual');
    }
  });

  it('A350 六轮、A330 四轮、A380 四支支柱', () => {
    expect(resolveGearLayout('A359').bogie).toBe('bogie6');
    expect(resolveGearLayout('A333').bogie).toBe('bogie4');
    expect(resolveGearLayout('A388').mainStruts).toBe(4);
  });

  it('通航机是固定起落架', () => {
    for (const code of ['C172', 'C152', 'P28A', 'DA40', 'SR22']) {
      expect(resolveGearLayout(code).retractable, code).toBe(false);
    }
  });

  it('没有 ICAO 代码时按机模名兜底', () => {
    expect(resolveGearLayout(undefined, 'Cessna 172 Skyhawk').retractable).toBe(false);
    expect(resolveGearLayout('', 'Boeing 747-8 Intercontinental').mainStruts).toBe(4);
  });

  it('认不出的机型退回窄体，而不是抛错或给空构型', () => {
    const layout = resolveGearLayout('ZZZZ', 'Unknown Type');
    expect(layout.retractable).toBe(true);
    expect(layout.mainStruts).toBe(2);
    expect(layout.noseWheels).toBeGreaterThan(0);
  });

  it('完全没有机型信息也不炸', () => {
    expect(() => resolveGearLayout()).not.toThrow();
    expect(resolveGearLayout().mainStruts).toBe(2);
  });

  it('大小写与空白不影响识别', () => {
    expect(resolveGearLayout('  b738  ').bogie).toBe('dual');
    expect(resolveGearLayout('c172').retractable).toBe(false);
  });
});

describe('effectiveGearRatio', () => {
  const fixed = resolveGearLayout('C172');
  const retractable = resolveGearLayout('B738');

  it('固定起落架永远是放下 —— 收上是不存在的状态', () => {
    expect(effectiveGearRatio(fixed, 0)).toBe(1);
    expect(effectiveGearRatio(fixed, undefined)).toBe(1);
    expect(effectiveGearRatio(fixed, 0.5)).toBe(1);
  });

  it('可收放机型照实反映', () => {
    expect(effectiveGearRatio(retractable, 0)).toBe(0);
    expect(effectiveGearRatio(retractable, 1)).toBe(1);
    expect(effectiveGearRatio(retractable, 0.5)).toBe(0.5);
  });

  it('缺数据时按收上算，不假装放下', () => {
    // 可收放机型没有数据就是不知道，画成放下会给出错误的安全感
    expect(effectiveGearRatio(retractable, undefined)).toBe(0);
  });

  it('有的模拟器给的是百分比', () => {
    expect(effectiveGearRatio(retractable, 100)).toBe(1);
    expect(effectiveGearRatio(retractable, 50)).toBe(0.5);
  });
});
