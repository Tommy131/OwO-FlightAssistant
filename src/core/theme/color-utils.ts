/**
 * 颜色工具
 *
 * 复刻 Flutter `Color` / `Color.lerp` / `computeLuminance` 的相关行为，
 * 使主题生成结果与桌面版保持像素级一致。
 */

export interface Rgb {
  r: number;
  g: number;
  b: number;
}

/** 将 `#RRGGBB` / `#AARRGGBB` / `0xFFRRGGBB` 解析为 RGB */
export function parseColor(input: string | number): Rgb {
  if (typeof input === 'number') {
    return { r: (input >> 16) & 0xff, g: (input >> 8) & 0xff, b: input & 0xff };
  }
  let hex = input.trim().replace(/^#/, '').replace(/^0x/i, '');
  // Flutter 的 ARGB 写法：丢弃 alpha 通道，只取 RGB
  if (hex.length === 8) hex = hex.slice(2);
  if (hex.length === 3) hex = hex.split('').map((c) => c + c).join('');
  const value = Number.parseInt(hex, 16);
  return { r: (value >> 16) & 0xff, g: (value >> 8) & 0xff, b: value & 0xff };
}

export function toHex({ r, g, b }: Rgb): string {
  const h = (n: number) => Math.round(clamp(n, 0, 255)).toString(16).padStart(2, '0');
  return `#${h(r)}${h(g)}${h(b)}`;
}

export function clamp(value: number, min: number, max: number): number {
  return value < min ? min : value > max ? max : value;
}

/** 线性插值，等价于 Flutter 的 `Color.lerp(a, b, t)` */
export function lerpColor(a: string | Rgb, b: string | Rgb, t: number): string {
  const from = typeof a === 'string' ? parseColor(a) : a;
  const to = typeof b === 'string' ? parseColor(b) : b;
  const ratio = clamp(t, 0, 1);
  return toHex({
    r: from.r + (to.r - from.r) * ratio,
    g: from.g + (to.g - from.g) * ratio,
    b: from.b + (to.b - from.b) * ratio,
  });
}

/**
 * 相对亮度，等价于 Flutter 的 `Color.computeLuminance()`
 * （sRGB → 线性化 → ITU-R BT.709 加权）
 */
export function computeLuminance(color: string | Rgb): number {
  const { r, g, b } = typeof color === 'string' ? parseColor(color) : color;
  const linearize = (channel: number) => {
    const c = channel / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b);
}

/**
 * 取对比前景色，等价于 `AppThemeData.getContrastColor`
 * 亮度 > 0.5 → black87，否则 → white
 */
export function getContrastColor(color: string): string {
  return computeLuminance(color) > 0.5 ? 'rgba(0, 0, 0, 0.87)' : '#FFFFFF';
}

/** 生成带透明度的 rgba()，等价于 Flutter 的 `color.withValues(alpha: x)` */
export function withAlpha(color: string, alpha: number): string {
  const { r, g, b } = parseColor(color);
  return `rgba(${r}, ${g}, ${b}, ${clamp(alpha, 0, 1)})`;
}

/** WCAG 对比度（map 模块的 AI 机标签配色用到） */
