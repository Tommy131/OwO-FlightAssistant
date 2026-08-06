/**
 * 气象报文解码（纯函数）
 *
 * 对应 Flutter 版 `modules/map/providers/map_weather_utils.dart`。
 *
 * 原先放在 `modules/map/providers/` 下，但那里有两个问题：`providers/` 按分层约定
 * 装的是 Zustand store，而这些是纯函数；且 map 模块自己一处都没用，唯一的消费方
 * 是 toolbox 的气象解码页 —— 等于 toolbox 越过模块边界去读 map 的内部实现，
 * map 模块就没法独立裁剪了。现按实际归属挪到 toolbox 的领域层。
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

/** 由能见度与云幕高判定飞行规则；两个条件取更严的那个 */
export function resolveRule(
  visibilitySm: number | undefined,
  ceilingFt: number | undefined,
): ApproachRule {
  if (
    (ceilingFt !== undefined && ceilingFt < 500) ||
    (visibilitySm !== undefined && visibilitySm < 1)
  ) {
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

/**
 * 从整段报文中提取最差能见度（SM）
 *
 * ⚠️ 两侧的 `\b` 是必需的，不是可有可无的收紧。报文里到处都是四位数字：
 * 时间戳 `052300Z`、风组 `01004MPS`、跑道视程 `R36L/1200N`、修正海压 `Q1024`。
 * 少了词边界就会把它们全当成能见度，而本函数取的是**最小值** ——
 * 风组里的 `0100` 会让任何一份报文都被判成 LIFR，连 CAVOK 都不例外。
 */
export function extractWorstVisibility(raw: string): number | undefined {
  let minVis: number | undefined;
  for (const match of raw.matchAll(/\b(\d{4}|P?\d+\/\d+SM|P?\d+SM)\b/g)) {
    const vis = parseVisibilitySm(match[1]);
    if (vis === undefined) continue;
    if (minVis === undefined || vis < minVis) minVis = vis;
  }
  return minVis;
}

/**
 * 从整段报文中提取最低云幕高（ft）
 *
 * 实现上等同于对全文跑一遍 `parseCeilingFt`，但保留独立命名：调用方传的是
 * 整段 TAF/METAR，而不是已经切好的云层字段，语义不同。
 */
export function extractLowestCeiling(raw: string): number | undefined {
  return parseCeilingFt(raw);
}
