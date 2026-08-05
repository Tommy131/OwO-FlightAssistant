/**
 * 气象报文解析工具
 *
 * 对应 Flutter 版 `modules/map/providers/map_weather_utils.dart`。
 * 由 map 与 toolbox 两个模块共用（能见度、云幕高、飞行规则判定）。
 */

/** 飞行规则类别 */
export type ApproachRule = 'VFR' | 'MVFR' | 'IFR' | 'LIFR' | 'UNK';

/**
 * 解析能见度为法定英里（SM）
 *
 * 支持两种格式：
 *   - ICAO：4 位数字代表米（`0000` – `9999`）
 *   - FAA：带 SM 单位，可为分数或带 P/M 前缀（`1/4SM`、`P6SM`）
 */
export function parseVisibilitySm(rawVisibility: string | undefined): number | undefined {
  const text = (rawVisibility ?? '').trim().toUpperCase();
  if (text.length === 0) return undefined;

  // ICAO 米制
  if (/^\d{4}$/.test(text)) {
    const meters = Number.parseFloat(text);
    return Number.isFinite(meters) ? meters / 1609.344 : undefined;
  }

  // FAA 英里制
  const smMatch = text.match(/([PM]?\d+(?:\/\d+)?(?:\.\d+)?)\s*SM/);
  if (!smMatch) return undefined;

  const normalized = smMatch[1].replace(/P/g, '').replace(/M/g, '');
  if (normalized.includes('/')) {
    const [numeratorText, denominatorText] = normalized.split('/');
    const numerator = Number.parseFloat(numeratorText);
    const denominator = Number.parseFloat(denominatorText);
    if (Number.isFinite(numerator) && Number.isFinite(denominator) && denominator !== 0) {
      return numerator / denominator;
    }
    return undefined;
  }
  const parsed = Number.parseFloat(normalized);
  return Number.isFinite(parsed) ? parsed : undefined;
}

/**
 * 解析云层字段，返回最低云幕高度（英尺）
 * 只统计 BKN / OVC / VV —— 这三类才构成云幕
 */
export function parseCeilingFt(cloudText: string | undefined): number | undefined {
  const text = (cloudText ?? '').toUpperCase();
  if (text.length === 0) return undefined;

  let minCeiling: number | undefined;
  for (const match of text.matchAll(/(BKN|OVC|VV)(\d{3})/g)) {
    const value = Number.parseInt(match[2], 10);
    if (!Number.isFinite(value)) continue;
    // METAR 云高以百英尺为单位
    const ceiling = value * 100;
    if (minCeiling === undefined || ceiling < minCeiling) minCeiling = ceiling;
  }
  return minCeiling;
}

/** 由能见度与云幕高判定飞行规则 */
export function resolveRule(
  visibilitySm: number | undefined,
  ceilingFt: number | undefined,
): ApproachRule {
  if ((ceilingFt !== undefined && ceilingFt < 500) || (visibilitySm !== undefined && visibilitySm < 1)) {
    return 'LIFR';
  }
  if (
    (ceilingFt !== undefined && ceilingFt < 1000) ||
    (visibilitySm !== undefined && visibilitySm < 3)
  ) {
    return 'IFR';
  }
  if (
    (ceilingFt !== undefined && ceilingFt <= 3000) ||
    (visibilitySm !== undefined && visibilitySm <= 5)
  ) {
    return 'MVFR';
  }
  return 'VFR';
}

/** 从任意文本中标准化提取飞行规则关键字 */
export function normalizeApproachRule(text: string | undefined): ApproachRule | null {
  const upper = (text ?? '').toUpperCase();
  if (upper.includes('LIFR')) return 'LIFR';
  if (upper.includes('MVFR')) return 'MVFR';
  if (upper.includes('IFR')) return 'IFR';
  if (upper.includes('VFR')) return 'VFR';
  return null;
}

/**
 * 综合判定飞行规则
 * 优先用结构化字段计算，其次从原始报文提取关键字，CAVOK 视为 VFR
 */
export function resolveApproachRule(options: {
  visibility?: string;
  clouds?: string;
  rawMetar?: string;
}): ApproachRule {
  const visibilitySm = parseVisibilitySm(options.visibility);
  const ceilingFt = parseCeilingFt(options.clouds);
  if (visibilitySm !== undefined || ceilingFt !== undefined) {
    return resolveRule(visibilitySm, ceilingFt);
  }
  const fromRaw = normalizeApproachRule(options.rawMetar);
  if (fromRaw) return fromRaw;
  if ((options.rawMetar ?? '').toUpperCase().includes('CAVOK')) return 'VFR';
  return 'UNK';
}

/** 各飞行规则对应的展示色（地图机场标记与工具箱共用） */
export const APPROACH_RULE_COLOR: Record<ApproachRule, string> = {
  VFR: '#2ECC71',
  MVFR: '#3498DB',
  IFR: '#E74C3C',
  LIFR: '#9B59B6',
  UNK: '#95A5A6',
};

/** 从整段报文中提取最差能见度（SM） */
export function extractWorstVisibility(raw: string): number | undefined {
  let minVis: number | undefined;
  for (const match of raw.matchAll(/(\d{4}|P?\d+\/\d+SM|P?\d+SM)/g)) {
    const vis = parseVisibilitySm(match[1]);
    if (vis === undefined) continue;
    if (minVis === undefined || vis < minVis) minVis = vis;
  }
  return minVis;
}

/** 从整段报文中提取最低云幕高（ft） */
export function extractLowestCeiling(raw: string): number | undefined {
  return parseCeilingFt(raw);
}
