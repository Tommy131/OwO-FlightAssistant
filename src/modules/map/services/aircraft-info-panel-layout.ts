/**
 * 航空器信息迷你面板的定位计算（纯函数）
 *
 * 移植自桌面版 `map_markers/aircraft_info_mini_panel.dart` 的定位部分。
 * 面板可以拖，但必须始终留在视口里；引线接哪一侧取决于面板在飞机的哪一边 ——
 * 接错侧的话引线会横穿整个面板，把数字盖住。
 *
 * 纯计算：不 import React / Leaflet / store，可被直接单测。
 */

/**
 * 面板基准尺寸（px）。
 *
 * 桌面版是 192×74 的一行三格（ALT / SPD / XPDR）。后来加了第四格 LT（当地时间），
 * 宽度却没动 —— 四格挤在 192px 里，每格分不到 45px，于是
 * 「803 ft」被截成「803 …」、「7700 standby」被截成「7700 stand…」，
 * 最后一格干脆被挤出面板外。
 *
 * 改成两行两列：每格能分到近一倍的宽度，四个值都放得下。
 * 高度相应加一行。
 */
export const PANEL_BASE_WIDTH = 214;
export const PANEL_BASE_HEIGHT = 104;
/** 面板与视口边缘的最小间距 */
export const PANEL_BASE_MARGIN = 10;
/** 默认相对飞机的偏移：右上方 */
export const PANEL_DEFAULT_OFFSET = { x: 118, y: -92 } as const;

/** 屏幕坐标点 */
export interface ScreenPoint {
  x: number;
  y: number;
}

/** 视口尺寸 */
export interface ViewportSize {
  width: number;
  height: number;
}

/** 定位输入 */
export interface PanelLayoutInput {
  /** 飞机在屏幕上的位置 */
  aircraft: ScreenPoint;
  /** 视口尺寸 */
  viewport: ViewportSize;
  /** 用户拖出来的相对偏移 */
  offset: ScreenPoint;
  /** 缩放系数，默认 1 */
  scale?: number;
}

/** 定位结果 */
export interface PanelLayout {
  /** 面板左上角 */
  left: number;
  top: number;
  width: number;
  height: number;
  /** 引线在面板一侧的接点 */
  lineEnd: ScreenPoint;
  /** 引线在飞机一侧的接点（就是飞机本身） */
  lineStart: ScreenPoint;
}

/**
 * 算出面板位置与引线接点。
 *
 * 位置对视口做 clamp：拖到边缘也不会跑出屏幕，这是桌面版的既定行为 ——
 * 不 clamp 的话用户一拖出界，面板就再也找不回来了。
 */
export function layoutAircraftInfoPanel(input: PanelLayoutInput): PanelLayout {
  const scale = input.scale && input.scale > 0 ? input.scale : 1;
  const width = PANEL_BASE_WIDTH * scale;
  const height = PANEL_BASE_HEIGHT * scale;
  const margin = PANEL_BASE_MARGIN * scale;

  // 视口比面板还小时 clamp 的上下界会反过来，取 max 兜住
  const maxLeft = Math.max(margin, input.viewport.width - width - margin);
  const maxTop = Math.max(margin, input.viewport.height - height - margin);

  const left = clamp(input.aircraft.x + input.offset.x, margin, maxLeft);
  const top = clamp(input.aircraft.y + input.offset.y, margin, maxTop);

  const centerX = left + width / 2;
  const centerY = top + height / 2;

  // 面板在飞机右边就接它的左沿，在左边就接右沿 —— 这样引线永远不横穿面板
  const lineEnd: ScreenPoint =
    centerX >= input.aircraft.x ? { x: left, y: centerY } : { x: left + width, y: centerY };

  return { left, top, width, height, lineEnd, lineStart: { ...input.aircraft } };
}

/**
 * 主标签：有航班号就「航班号 · 注册号」，否则只显示注册号。
 *
 * 与桌面版 `_resolveMainLabel` 一致；两者都没有时显示 `--`，
 * 不显示空串 —— 空标签会让面板顶部塌掉一行。
 */
export function resolveAircraftLabel(
  flightNumber: string | undefined,
  registration: string | undefined,
): string {
  const flight = normalizeLabel(flightNumber);
  const reg = normalizeLabel(registration) ?? '--';
  return flight === undefined ? reg : `${flight} · ${reg}`;
}

function normalizeLabel(value: string | undefined): string | undefined {
  const text = (value ?? '').trim().toUpperCase();
  return text.length === 0 ? undefined : text;
}

function clamp(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
