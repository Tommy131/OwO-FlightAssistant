/**
 * 宽容型 JSON 解析工具
 *
 * 对应 Flutter 版散落在各 adapter/provider 中的 `_toDouble` / `_toBool` /
 * `_pickString` / `_pickMap` / `_pickDouble` 等私有方法，这里统一抽出复用。
 *
 * 中间件返回的字段命名并不完全统一（大小写、单位后缀、同义键都存在），
 * 因此这些函数都支持「多候选键 + 忽略大小写」的二次查找，与桌面版行为一致。
 */

export type JsonMap = Record<string, unknown>;

/** 转 double，失败返回 undefined */
export function toDouble(value: unknown): number | undefined {
  if (typeof value === 'number') return Number.isFinite(value) ? value : undefined;
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

/** 转 int，失败返回 undefined */
export function toInt(value: unknown): number | undefined {
  if (typeof value === 'number') return Number.isFinite(value) ? Math.trunc(value) : undefined;
  if (typeof value === 'string') {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

/** 转 bool（数字非 0 为真，字符串 'true'/'false'），失败返回 undefined */
export function toBool(value: unknown): boolean | undefined {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const text = value.toLowerCase().trim();
    if (text === 'true') return true;
    if (text === 'false') return false;
  }
  return undefined;
}

/** 转字符串，空串归一为 undefined */
export function toStringOrUndefined(value: unknown): string | undefined {
  if (value === null || value === undefined) return undefined;
  const text = String(value).trim();
  return text.length > 0 ? text : undefined;
}

/** 断言为对象 map，否则返回 null */
export function toJsonMap(value: unknown): JsonMap | null {
  if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
    return value as JsonMap;
  }
  return null;
}

/** 从多个候选键中取第一个非空字符串（先精确匹配，再忽略大小写） */
export function pickString(map: JsonMap, keys: readonly string[]): string | undefined {
  for (const key of keys) {
    if (Object.prototype.hasOwnProperty.call(map, key)) {
      const value = toStringOrUndefined(map[key]);
      if (value !== undefined) return value;
    }
  }
  const lowerKeys = keys.map((key) => key.toLowerCase());
  for (const [entryKey, entryValue] of Object.entries(map)) {
    if (!lowerKeys.includes(entryKey.toLowerCase())) continue;
    const value = toStringOrUndefined(entryValue);
    if (value !== undefined) return value;
  }
  return undefined;
}

/** 从多个候选键中取第一个可解析的数字 */
export function pickDouble(map: JsonMap, keys: readonly string[]): number | undefined {
  for (const key of keys) {
    if (Object.prototype.hasOwnProperty.call(map, key)) {
      const value = toDouble(map[key]);
      if (value !== undefined) return value;
    }
  }
  const lowerKeys = keys.map((key) => key.toLowerCase());
  for (const [entryKey, entryValue] of Object.entries(map)) {
    if (!lowerKeys.includes(entryKey.toLowerCase())) continue;
    const value = toDouble(entryValue);
    if (value !== undefined) return value;
  }
  return undefined;
}

/** 从多个候选键中取第一个对象 */
export function pickMap(map: JsonMap, keys: readonly string[]): JsonMap | null {
  for (const key of keys) {
    if (Object.prototype.hasOwnProperty.call(map, key)) {
      const value = toJsonMap(map[key]);
      if (value) return value;
    }
  }
  const lowerKeys = keys.map((key) => key.toLowerCase());
  for (const [entryKey, entryValue] of Object.entries(map)) {
    if (!lowerKeys.includes(entryKey.toLowerCase())) continue;
    const value = toJsonMap(entryValue);
    if (value) return value;
  }
  return null;
}

/** 取数组，非数组返回空数组 */
export function pickArray(map: JsonMap, keys: readonly string[]): unknown[] {
  for (const key of keys) {
    const value = map[key];
    if (Array.isArray(value)) return value;
  }
  return [];
}

/**
 * 读取角度值：优先取带 `_deg` 后缀的键，否则从候选键取值并做弧度判定
 * （对应桌面版 `_readAngleDegrees`）
 */
export function readAngleDegrees(
  map: JsonMap,
  degreeKeys: readonly string[],
  fallbackKeys: readonly string[],
): number | undefined {
  const degree = pickDouble(map, degreeKeys);
  if (degree !== undefined) return degree;
  return normalizeAngleDegrees(pickDouble(map, fallbackKeys));
}

/** 绝对值 ≤ 3.2 视为弧度制，自动换算为度（对应桌面版 `_normalizeAngleDegrees`） */
export function normalizeAngleDegrees(value: number | undefined): number | undefined {
  if (value === undefined) return undefined;
  if (Math.abs(value) <= 3.2) return value * 57.29577951308232;
  return value;
}

/** Haversine 大圆距离（海里），对应桌面版 `_calculateDistanceNm` */
export function calculateDistanceNm(
  startLat: number,
  startLon: number,
  endLat: number,
  endLon: number,
): number {
  const earthRadiusKm = 6371.0;
  const toRad = 0.017453292519943295;
  const lat1 = startLat * toRad;
  const lon1 = startLon * toRad;
  const lat2 = endLat * toRad;
  const lon2 = endLon * toRad;
  const deltaLat = lat2 - lat1;
  const deltaLon = lon2 - lon1;
  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c * 0.539956803;
}

/** 大圆方位角（度，0-360） */
export function calculateBearingDeg(
  startLat: number,
  startLon: number,
  endLat: number,
  endLon: number,
): number {
  const toRad = Math.PI / 180;
  const lat1 = startLat * toRad;
  const lat2 = endLat * toRad;
  const deltaLon = (endLon - startLon) * toRad;
  const y = Math.sin(deltaLon) * Math.cos(lat2);
  const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(deltaLon);
  return (Math.atan2(y, x) * (180 / Math.PI) + 360) % 360;
}
