/**
 * 飞行罗盘刻度环（纯计算 + HTML 构造）
 *
 * 移植自 Flutter 版 `map_markers/compass_ring.dart` 的 `_AircraftCompassRingPainter`。
 * 那边用 CustomPainter 逐笔画，Web 版改成一次性拼出 SVG —— Leaflet 的 divIcon
 * 收的是字符串，每帧重建 DOM 的代价比重画 canvas 高，所以刻度只算一次并缓存。
 *
 * ── 与桌面版的一处有意差异 ──
 * 桌面版有 `mapRotation`（flutter_map 支持整幅地图旋转）；Leaflet 不旋转地图，
 * 因此这里恒按「上方为真北」绘制，只让航向线与目标箭头转。
 *
 * 纯函数：不 import Leaflet / React / store，可被直接单测。
 */

/** 罗盘基准直径（px），与桌面版一致 */
export const COMPASS_BASE_SIZE = 170;

/** 一条刻度 */
export interface CompassTick {
  /** 角度（0=正北，顺时针） */
  deg: number;
  /** 刻度线两端（相对罗盘中心的 px 偏移，y 轴向下） */
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  /** 主刻度（每 30°） */
  major: boolean;
  /** 四个基本方位（每 90°） */
  cardinal: boolean;
  /** 主刻度才有标签：N/E/S/W 或 030 这样的三位数 */
  label?: string;
  /** 标签中心位置 */
  labelX?: number;
  labelY?: number;
}

/** 罗盘配色，随底图明暗切换 */
export interface CompassPalette {
  ring: string;
  cardinal: string;
  majorTick: string;
  minorTick: string;
  headingLine: string;
  headingGlow: string;
  targetArrow: string;
  badgeBackground: string;
  badgeBorder: string;
  badgeText: string;
}

/**
 * 取配色。
 *
 * 底图切到卫星/地形这类亮图时，白色系罗盘会整个糊在背景里看不见 ——
 * 亮底下换成深色描边 + 白底徽标，这与桌面版
 * `highContrastOnBrightBackground` 的取值逐条对齐。
 */
export function compassPalette(brightBackground: boolean): CompassPalette {
  if (brightBackground) {
    return {
      ring: 'rgba(0,0,0,0.45)',
      cardinal: '#8B2C00',
      majorTick: 'rgba(0,0,0,0.87)',
      minorTick: 'rgba(0,0,0,0.54)',
      headingLine: '#8B2C00',
      headingGlow: 'rgba(0,0,0,0.45)',
      targetArrow: '#174E8C',
      badgeBackground: 'rgba(255,255,255,0.86)',
      badgeBorder: 'rgba(0,0,0,0.26)',
      badgeText: '#8B2C00',
    };
  }
  return {
    ring: 'rgba(255,255,255,0.24)',
    cardinal: '#ffab40',
    majorTick: 'rgba(255,255,255,0.70)',
    minorTick: 'rgba(255,255,255,0.38)',
    headingLine: '#ff5722',
    headingGlow: 'rgba(255,87,34,0.80)',
    targetArrow: '#18ffff',
    badgeBackground: 'rgba(0,0,0,0.55)',
    badgeBorder: 'rgba(255,255,255,0.24)',
    badgeText: '#ffab40',
  };
}

/**
 * 算出整圈刻度。
 *
 * 每 5° 一条：30° 的倍数为主刻度（带标签），10° 的倍数为中刻度，其余为短刻度。
 * 角度换算时减 90°，因为 SVG 的 0° 指向正右方而罗盘的 0° 要指向正上方。
 */
export function buildCompassTicks(size: number = COMPASS_BASE_SIZE): CompassTick[] {
  const scale = size / COMPASS_BASE_SIZE;
  const center = size / 2;
  const radius = size / 2;
  const ticks: CompassTick[] = [];

  for (let deg = 0; deg < 360; deg += 5) {
    const major = deg % 30 === 0;
    const medium = deg % 10 === 0;
    const cardinal = deg % 90 === 0;
    const tickLength = major ? 13 * scale : medium ? 8 * scale : 5 * scale;

    const angle = ((deg - 90) * Math.PI) / 180;
    const startRadius = radius - 6 * scale;
    const endRadius = startRadius - tickLength;

    const tick: CompassTick = {
      deg,
      x1: center + Math.cos(angle) * startRadius,
      y1: center + Math.sin(angle) * startRadius,
      x2: center + Math.cos(angle) * endRadius,
      y2: center + Math.sin(angle) * endRadius,
      major,
      cardinal,
    };

    if (major) {
      const textRadius = radius - 24 * scale;
      tick.label = cardinalLabel(deg);
      tick.labelX = center + Math.cos(angle) * textRadius;
      tick.labelY = center + Math.sin(angle) * textRadius;
    }
    ticks.push(tick);
  }
  return ticks;
}

/** 0/90/180/270 用字母，其余主刻度用三位数字 */
export function cardinalLabel(deg: number): string {
  switch (deg) {
    case 0:
      return 'N';
    case 90:
      return 'E';
    case 180:
      return 'S';
    case 270:
      return 'W';
    default:
      return String(deg).padStart(3, '0');
  }
}

/** 罗盘渲染入参 */
export interface CompassRingOptions {
  /** 当前航向（度）；缺失时不画航向线 */
  heading?: number;
  /** 自动驾驶目标航向（度）；缺失时不画目标箭头 */
  headingTarget?: number;
  /** 底图是否为亮色 */
  brightBackground: boolean;
  /** 直径（px），默认 170 */
  size?: number;
}

/**
 * 拼出罗盘的 SVG。
 *
 * 中心徽标显示目标航向（没有目标就显示当前航向），与桌面版一致 ——
 * 有目标时飞行员关心的是「要转到哪」，不是「现在朝哪」。
 */
export function compassRingHtml(options: CompassRingOptions): string {
  const size = options.size ?? COMPASS_BASE_SIZE;
  const scale = size / COMPASS_BASE_SIZE;
  const center = size / 2;
  const palette = compassPalette(options.brightBackground);
  const ticks = buildCompassTicks(size);

  const tickMarkup = ticks
    .map((tick) => {
      const color = tick.cardinal
        ? palette.cardinal
        : tick.major
          ? palette.majorTick
          : palette.minorTick;
      const width = tick.major ? 1.8 * scale : 1.1 * scale;
      return `<line x1="${round(tick.x1)}" y1="${round(tick.y1)}" x2="${round(tick.x2)}" y2="${round(tick.y2)}" stroke="${color}" stroke-width="${round(width)}" stroke-linecap="round"/>`;
    })
    .join('');

  const labelMarkup = ticks
    .filter((tick) => tick.label !== undefined)
    .map((tick) => {
      const color = tick.cardinal ? palette.cardinal : palette.majorTick;
      const fontSize = tick.cardinal ? 11 * scale : 8 * scale;
      const weight = tick.cardinal ? 800 : 600;
      return `<text x="${round(tick.labelX ?? 0)}" y="${round(tick.labelY ?? 0)}" fill="${color}" font-size="${round(fontSize)}" font-weight="${weight}" text-anchor="middle" dominant-baseline="central">${tick.label ?? ''}</text>`;
    })
    .join('');

  // 航向线：从中心向上画，再整体绕中心转到航向角
  const headingMarkup =
    options.heading === undefined
      ? ''
      : `<g transform="rotate(${round(normalizeDeg(options.heading))} ${round(center)} ${round(center)})">
      <line x1="${round(center)}" y1="${round(center)}" x2="${round(center)}" y2="${round(center - size * 0.36)}"
        stroke="${palette.headingLine}" stroke-width="${round(2.2 * scale)}" stroke-linecap="round"
        style="filter:drop-shadow(0 0 ${round(6 * scale)}px ${palette.headingGlow})"/>
    </g>`;

  // 目标航向箭头：环外一个朝内的三角
  const targetMarkup =
    options.headingTarget === undefined
      ? ''
      : `<g transform="rotate(${round(normalizeDeg(options.headingTarget))} ${round(center)} ${round(center)})">
      ${trianglePath(center, 3 * scale, 9 * scale, palette.targetArrow)}
    </g>`;

  const badgeText = `${Math.round(normalizeDeg(options.headingTarget ?? options.heading ?? Number.NaN))}`;
  const badgeLabel = Number.isFinite(options.headingTarget ?? options.heading ?? Number.NaN)
    ? `${badgeText}°`
    : '--°';
  const badgeWidth = 34 * scale;
  const badgeHeight = 17 * scale;

  return `<div style="width:${size}px;height:${size}px;pointer-events:none">
    <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" xmlns="http://www.w3.org/2000/svg">
      <circle cx="${round(center)}" cy="${round(center)}" r="${round(center - 1.5 * scale)}"
        fill="none" stroke="${palette.ring}" stroke-width="${round(1.2 * scale)}"/>
      ${tickMarkup}
      ${labelMarkup}
      ${headingMarkup}
      ${targetMarkup}
      <rect x="${round(center - badgeWidth / 2)}" y="${round(center - badgeHeight / 2)}"
        width="${round(badgeWidth)}" height="${round(badgeHeight)}" rx="${round(8 * scale)}"
        fill="${palette.badgeBackground}" stroke="${palette.badgeBorder}" stroke-width="1"/>
      <text x="${round(center)}" y="${round(center)}" fill="${palette.badgeText}"
        font-size="${round(11 * scale)}" font-weight="800" text-anchor="middle"
        dominant-baseline="central">${badgeLabel}</text>
    </svg>
  </div>`;
}

/** 环顶朝内的小三角（目标航向指示） */
function trianglePath(center: number, halfWidth: number, height: number, color: string): string {
  const tipY = 10 * (height / 9);
  return `<path d="M ${round(center - halfWidth)} ${round(tipY - height)} L ${round(center + halfWidth)} ${round(tipY - height)} L ${round(center)} ${round(tipY)} Z" fill="${color}"/>`;
}

/** 角度归一到 [0, 360) */
export function normalizeDeg(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return ((value % 360) + 360) % 360;
}

/** 保留一位小数，避免 SVG 里堆一长串浮点数 */
function round(value: number): number {
  return Math.round(value * 10) / 10;
}
