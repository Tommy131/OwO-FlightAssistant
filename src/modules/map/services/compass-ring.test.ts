import { describe, expect, it } from 'vitest';

import {
  COMPASS_BASE_SIZE,
  buildCompassTicks,
  cardinalLabel,
  compassPalette,
  compassRingHtml,
  normalizeDeg,
} from './compass-ring';

/**
 * 罗盘刻度环
 *
 * 几何算错不会报错，只会画出一个「看着挺像罗盘、但北不在正上方」的东西 ——
 * 所以方位换算这几条要钉死。
 */

describe('normalizeDeg', () => {
  it('归一到 [0, 360)', () => {
    expect(normalizeDeg(0)).toBe(0);
    expect(normalizeDeg(359)).toBe(359);
    expect(normalizeDeg(360)).toBe(0);
    expect(normalizeDeg(450)).toBe(90);
    expect(normalizeDeg(-90)).toBe(270);
    expect(normalizeDeg(-450)).toBe(270);
  });

  it('非有限值回落到 0，不把 NaN 传进 SVG', () => {
    expect(normalizeDeg(Number.NaN)).toBe(0);
    expect(normalizeDeg(Number.POSITIVE_INFINITY)).toBe(0);
  });
});

describe('cardinalLabel', () => {
  it('四个基本方位用字母', () => {
    expect(cardinalLabel(0)).toBe('N');
    expect(cardinalLabel(90)).toBe('E');
    expect(cardinalLabel(180)).toBe('S');
    expect(cardinalLabel(270)).toBe('W');
  });

  it('其余主刻度补足三位', () => {
    expect(cardinalLabel(30)).toBe('030');
    expect(cardinalLabel(120)).toBe('120');
  });
});

describe('buildCompassTicks', () => {
  const ticks = buildCompassTicks();

  it('每 5° 一条，共 72 条', () => {
    expect(ticks).toHaveLength(72);
    expect(ticks[1].deg).toBe(5);
  });

  it('30° 的倍数是主刻度且带标签', () => {
    const major = ticks.filter((t) => t.major);
    expect(major).toHaveLength(12);
    expect(major.every((t) => t.label !== undefined)).toBe(true);
  });

  it('90° 的倍数是基本方位', () => {
    expect(ticks.filter((t) => t.cardinal).map((t) => t.deg)).toEqual([0, 90, 180, 270]);
  });

  // 这条是关键：0° 必须指向正上方（SVG 的 0° 在正右方，换算漏了 -90 就会整体偏 90°）
  it('0° 刻度在正上方', () => {
    const north = ticks.find((t) => t.deg === 0);
    const center = COMPASS_BASE_SIZE / 2;
    expect(north?.x1).toBeCloseTo(center, 5);
    expect(north?.y1).toBeLessThan(center);
  });

  it('90° 刻度在正右方', () => {
    const east = ticks.find((t) => t.deg === 90);
    const center = COMPASS_BASE_SIZE / 2;
    expect(east?.x1).toBeGreaterThan(center);
    expect(east?.y1).toBeCloseTo(center, 5);
  });

  it('180° 刻度在正下方', () => {
    const south = ticks.find((t) => t.deg === 180);
    const center = COMPASS_BASE_SIZE / 2;
    expect(south?.x1).toBeCloseTo(center, 5);
    expect(south?.y1).toBeGreaterThan(center);
  });

  it('主刻度比短刻度长', () => {
    const majorLen = tickLength(ticks.find((t) => t.deg === 30)!);
    const minorLen = tickLength(ticks.find((t) => t.deg === 35)!);
    expect(majorLen).toBeGreaterThan(minorLen);
  });

  it('刻度都落在半径以内', () => {
    const center = COMPASS_BASE_SIZE / 2;
    for (const tick of ticks) {
      expect(Math.hypot(tick.x1 - center, tick.y1 - center)).toBeLessThanOrEqual(center);
      expect(Math.hypot(tick.x2 - center, tick.y2 - center)).toBeLessThanOrEqual(center);
    }
  });

  it('换尺寸时整体等比缩放', () => {
    const half = buildCompassTicks(COMPASS_BASE_SIZE / 2);
    expect(half).toHaveLength(72);
    const center = COMPASS_BASE_SIZE / 4;
    const north = half.find((t) => t.deg === 0);
    expect(north?.x1).toBeCloseTo(center, 5);
  });
});

describe('compassPalette', () => {
  // 底图切到卫星图时白色系罗盘会整个糊进背景
  it('亮底与暗底给出不同配色', () => {
    const dark = compassPalette(false);
    const bright = compassPalette(true);
    expect(dark.headingLine).not.toBe(bright.headingLine);
    expect(dark.badgeBackground).not.toBe(bright.badgeBackground);
  });
});

describe('compassRingHtml', () => {
  it('画出刻度、方位字母与外环', () => {
    const html = compassRingHtml({ heading: 90, brightBackground: false });
    expect(html).toContain('<svg');
    expect(html).toContain('<circle');
    expect(html).toContain('>N<');
    expect(html).toContain('>E<');
  });

  it('有航向时画航向线并按航向旋转', () => {
    const html = compassRingHtml({ heading: 123, brightBackground: false });
    expect(html).toContain('rotate(123');
  });

  it('没有航向时不画航向线，徽标显示 --', () => {
    const html = compassRingHtml({ brightBackground: false });
    expect(html).toContain('--°');
  });

  it('有目标航向时画目标箭头', () => {
    const withTarget = compassRingHtml({ heading: 10, headingTarget: 250, brightBackground: false });
    const without = compassRingHtml({ heading: 10, brightBackground: false });
    expect(withTarget).toContain('rotate(250');
    expect(countOccurrences(withTarget, '<path')).toBeGreaterThan(
      countOccurrences(without, '<path'),
    );
  });

  // 有目标航向时飞行员关心的是「要转到哪」，不是「现在朝哪」
  it('徽标优先显示目标航向', () => {
    expect(compassRingHtml({ heading: 10, headingTarget: 250, brightBackground: false })).toContain(
      '>250°<',
    );
    expect(compassRingHtml({ heading: 10, brightBackground: false })).toContain('>10°<');
  });

  it('超范围航向先归一再画', () => {
    expect(compassRingHtml({ heading: 450, brightBackground: false })).toContain('>90°<');
    expect(compassRingHtml({ heading: -90, brightBackground: false })).toContain('>270°<');
  });

  it('亮底时用高对比配色', () => {
    expect(compassRingHtml({ heading: 0, brightBackground: true })).toContain('#8B2C00');
  });
});

function tickLength(tick: { x1: number; y1: number; x2: number; y2: number }): number {
  return Math.hypot(tick.x2 - tick.x1, tick.y2 - tick.y1);
}

function countOccurrences(text: string, needle: string): number {
  return text.split(needle).length - 1;
}
