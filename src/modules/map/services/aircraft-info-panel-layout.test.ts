import { describe, expect, it } from 'vitest';

import {
  PANEL_BASE_HEIGHT,
  PANEL_BASE_MARGIN,
  PANEL_BASE_WIDTH,
  PANEL_DEFAULT_OFFSET,
  layoutAircraftInfoPanel,
  resolveAircraftLabel,
} from './aircraft-info-panel-layout';

const VIEWPORT = { width: 1200, height: 800 };
const CENTER = { x: 600, y: 400 };

describe('layoutAircraftInfoPanel', () => {
  it('默认浮在飞机右上方', () => {
    const layout = layoutAircraftInfoPanel({
      aircraft: CENTER,
      viewport: VIEWPORT,
      offset: { ...PANEL_DEFAULT_OFFSET },
    });
    expect(layout.left).toBe(CENTER.x + PANEL_DEFAULT_OFFSET.x);
    expect(layout.top).toBe(CENTER.y + PANEL_DEFAULT_OFFSET.y);
    expect(layout.width).toBe(PANEL_BASE_WIDTH);
    expect(layout.height).toBe(PANEL_BASE_HEIGHT);
  });

  // 不 clamp 的话用户一拖出界，面板就再也找不回来了
  it('拖到左上角外时被拉回视口内', () => {
    const layout = layoutAircraftInfoPanel({
      aircraft: CENTER,
      viewport: VIEWPORT,
      offset: { x: -5000, y: -5000 },
    });
    expect(layout.left).toBe(PANEL_BASE_MARGIN);
    expect(layout.top).toBe(PANEL_BASE_MARGIN);
  });

  it('拖到右下角外时被拉回视口内', () => {
    const layout = layoutAircraftInfoPanel({
      aircraft: CENTER,
      viewport: VIEWPORT,
      offset: { x: 5000, y: 5000 },
    });
    expect(layout.left).toBe(VIEWPORT.width - PANEL_BASE_WIDTH - PANEL_BASE_MARGIN);
    expect(layout.top).toBe(VIEWPORT.height - PANEL_BASE_HEIGHT - PANEL_BASE_MARGIN);
  });

  it('视口比面板还小时不会算出反向区间', () => {
    const layout = layoutAircraftInfoPanel({
      aircraft: { x: 10, y: 10 },
      viewport: { width: 100, height: 50 },
      offset: { x: 500, y: 500 },
    });
    expect(layout.left).toBeGreaterThanOrEqual(PANEL_BASE_MARGIN);
    expect(layout.top).toBeGreaterThanOrEqual(PANEL_BASE_MARGIN);
  });

  // 接错侧的话引线会横穿整个面板，把数字盖住
  it('面板在飞机右侧时引线接面板左沿', () => {
    const layout = layoutAircraftInfoPanel({
      aircraft: CENTER,
      viewport: VIEWPORT,
      offset: { x: 150, y: -60 },
    });
    expect(layout.lineEnd.x).toBe(layout.left);
  });

  it('面板在飞机左侧时引线接面板右沿', () => {
    const layout = layoutAircraftInfoPanel({
      aircraft: CENTER,
      viewport: VIEWPORT,
      offset: { x: -350, y: -60 },
    });
    expect(layout.lineEnd.x).toBe(layout.left + layout.width);
  });

  it('引线纵向接在面板中线上', () => {
    const layout = layoutAircraftInfoPanel({
      aircraft: CENTER,
      viewport: VIEWPORT,
      offset: { ...PANEL_DEFAULT_OFFSET },
    });
    expect(layout.lineEnd.y).toBe(layout.top + layout.height / 2);
  });

  it('引线起点就是飞机位置', () => {
    const layout = layoutAircraftInfoPanel({
      aircraft: CENTER,
      viewport: VIEWPORT,
      offset: { ...PANEL_DEFAULT_OFFSET },
    });
    expect(layout.lineStart).toEqual(CENTER);
  });

  it('缩放时尺寸与边距等比变化', () => {
    const layout = layoutAircraftInfoPanel({
      aircraft: CENTER,
      viewport: VIEWPORT,
      offset: { x: -5000, y: -5000 },
      scale: 2,
    });
    expect(layout.width).toBe(PANEL_BASE_WIDTH * 2);
    expect(layout.height).toBe(PANEL_BASE_HEIGHT * 2);
    expect(layout.left).toBe(PANEL_BASE_MARGIN * 2);
  });

  it('非法 scale 回落到 1', () => {
    const layout = layoutAircraftInfoPanel({
      aircraft: CENTER,
      viewport: VIEWPORT,
      offset: { ...PANEL_DEFAULT_OFFSET },
      scale: 0,
    });
    expect(layout.width).toBe(PANEL_BASE_WIDTH);
  });

  it('偏移是 NaN 时退到边距而不是把面板画到 NaN 位置', () => {
    const layout = layoutAircraftInfoPanel({
      aircraft: CENTER,
      viewport: VIEWPORT,
      offset: { x: Number.NaN, y: Number.NaN },
    });
    expect(Number.isFinite(layout.left)).toBe(true);
    expect(Number.isFinite(layout.top)).toBe(true);
  });
});

describe('resolveAircraftLabel', () => {
  it('有航班号时显示「航班号 · 注册号」', () => {
    expect(resolveAircraftLabel('cca1501', 'b-6075')).toBe('CCA1501 · B-6075');
  });

  it('没有航班号时只显示注册号', () => {
    expect(resolveAircraftLabel(undefined, 'B-6075')).toBe('B-6075');
    expect(resolveAircraftLabel('   ', 'B-6075')).toBe('B-6075');
  });

  // 空标签会让面板顶部塌掉一行
  it('两者都没有时显示占位符而不是空串', () => {
    expect(resolveAircraftLabel(undefined, undefined)).toBe('--');
  });
});
