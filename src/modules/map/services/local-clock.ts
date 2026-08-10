/**
 * 当地时间 / UTC 的格式化与格点判定
 *
 * 纯计算，不碰 React / Leaflet / Zustand / IO。时区从中间件
 * `/api/v1/timezone` 查一次（见 `timezone-lookup.ts`），拿到 **IANA 时区名**
 * 之后本地用 `Intl` 自己走时 —— 显示一个秒级跳动的钟不该每秒去问一次后端，
 * 而且交给 Intl 算意味着夏令时切换自动就是对的。
 */

/** 一次时区查询的结果 */
export interface ZoneInfo {
  /** IANA 时区名，例如 Europe/Berlin */
  readonly timezone: string;
  /** 查询当时的时区缩写，例如 CEST */
  readonly abbreviation: string;
  /** 查询当时相对 UTC 的偏移（秒） */
  readonly utcOffsetSeconds: number;
  /** 实际生效的格点坐标 */
  readonly latitude: number;
  readonly longitude: number;
}

/**
 * 时区查询的格点大小，必须与中间件 `localtime.QuantizeDeg` 一致。
 *
 * 同一个格子里后端给的是同一个答案，所以本机没跨出格子就没有再查的必要。
 */
export const ZONE_QUANTIZE_DEG = 0.1;

/** 格点键。本机还在同一个格子里就不必重新查时区 */
export function zoneCellKey(latitude: number, longitude: number): string | undefined {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return undefined;
  const lat = Math.round(latitude / ZONE_QUANTIZE_DEG);
  const lon = Math.round(longitude / ZONE_QUANTIZE_DEG);
  return `${lat}/${lon}`;
}

/**
 * 按时区格式化时钟（HH:MM:SS，24 小时制）。
 *
 * 时区名不认识时退回 UTC 而不是抛异常 —— 界面上宁可显示一个标着 UTC 的时间，
 * 也不能因为时区查歪了就把整块面板炸掉。
 */
export function formatClock(at: Date, timeZone: string | undefined): string {
  return formatWith(at, timeZone, {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  });
}

/**
 * 按时区格式化日期（YYYY-MM-DD）。
 *
 * 从 `formatToParts` 里逐段取，而不是把某个 locale 的输出拿来替换分隔符 ——
 * en-GB 给的是 DD/MM/YYYY，换掉斜杠只会得到一个顺序颠倒的日期。
 */
export function formatZonedDate(at: Date, timeZone: string | undefined): string {
  if (Number.isNaN(at.getTime())) return '--';
  const parts = formatPartsWith(at, timeZone, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const year = parts.find((part) => part.type === 'year')?.value ?? '----';
  const month = parts.find((part) => part.type === 'month')?.value ?? '--';
  const day = parts.find((part) => part.type === 'day')?.value ?? '--';
  return `${year}-${month}-${day}`;
}

/** UTC 时钟 */
export function formatUtcClock(at: Date): string {
  return formatClock(at, 'UTC');
}

/**
 * 偏移标签，例如 UTC+02:00 / UTC−05:30 / UTC±00:00。
 *
 * 负号用的是真正的减号 U+2212 而不是连字符：等宽数字里连字符又短又飘，
 * 和「+」摆在一起明显不对齐。
 */
export function formatOffsetLabel(offsetSeconds: number): string {
  if (!Number.isFinite(offsetSeconds)) return 'UTC';
  const total = Math.round(offsetSeconds);
  const sign = total === 0 ? '±' : total > 0 ? '+' : '−';
  const absolute = Math.abs(total);
  const hours = Math.floor(absolute / 3600);
  const minutes = Math.floor((absolute % 3600) / 60);
  return `UTC${sign}${pad2(hours)}:${pad2(minutes)}`;
}

/**
 * 当地日期与 UTC 日期是否不是同一天。
 *
 * 跨了日界的时候光显示 HH:MM 会让人以为差了十几个小时其实是差了一天，
 * 这时候界面上要把日期一起标出来。
 */
export function crossesDateBoundary(at: Date, timeZone: string | undefined): boolean {
  return formatZonedDate(at, timeZone) !== formatZonedDate(at, 'UTC');
}

function formatWith(
  at: Date,
  timeZone: string | undefined,
  options: Intl.DateTimeFormatOptions,
): string {
  if (Number.isNaN(at.getTime())) return '--';
  return formatterFor(timeZone, options).format(at);
}

function formatPartsWith(
  at: Date,
  timeZone: string | undefined,
  options: Intl.DateTimeFormatOptions,
): Intl.DateTimeFormatPart[] {
  return formatterFor(timeZone, options).formatToParts(at);
}

function formatterFor(
  timeZone: string | undefined,
  options: Intl.DateTimeFormatOptions,
): Intl.DateTimeFormat {
  const zone = (timeZone ?? '').trim() || 'UTC';
  try {
    return new Intl.DateTimeFormat('en-GB', { ...options, timeZone: zone });
  } catch {
    // 时区名不被运行时接受（拼错、太新、运行时裁过时区库）→ 退回 UTC
    return new Intl.DateTimeFormat('en-GB', { ...options, timeZone: 'UTC' });
  }
}

function pad2(value: number): string {
  return value.toString().padStart(2, '0');
}
