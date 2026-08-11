/**
 * 从 METAR 报文里解出风向与风速（纯函数）
 *
 * 不碰 React / IO —— 只为「把 `10003MPS` 这样一段电码变成能画指针的数字」。
 *
 * 后端已经给了一条现成的展示串（`display_wind`，如 `100° / 03 m/s`），
 * 但那是给人看的：要把指针转到正确角度得有**数值**，而且单位可能是
 * m/s 也可能是节，画之前必须先统一。所以这里直接解原始报文。
 */

/** 解析出的风况 */
export interface MetarWind {
  /** 风向（真北，度）。VRB（不定风）或缺测时为 undefined */
  directionDeg?: number;
  /** 风速，统一换算成节 */
  speedKt?: number;
  /** 阵风，统一换算成节 */
  gustKt?: number;
  /** 是否为不定风（VRB）——有风速但没有确定风向 */
  variable: boolean;
  /** 是否静风（00000KT） */
  calm: boolean;
}

const MPS_TO_KT = 1.943844;
const KMH_TO_KT = 0.539957;

/**
 * 风组的位置：`dddff(f)Gff(f)UNIT`。
 *
 * - `ddd` 三位风向，或 `VRB` 表示不定风
 * - `ff` 两到三位风速（三位是为了台风级别的大风）
 * - `Gff` 可选阵风
 * - 单位是 KT / MPS / KMH 之一，**必须匹配到单位才算风组** ——
 *   不锚定单位的话，`Q1007`、日期时间组 `110430Z` 里的数字段
 *   都可能被当成风组解出来。
 */
const WIND_GROUP = /\b(\d{3}|VRB)(\d{2,3})(?:G(\d{2,3}))?(KT|MPS|KMH)\b/;

/** 把风速换算成节 */
function toKnots(value: number, unit: string): number {
  switch (unit) {
    case 'MPS':
      return value * MPS_TO_KT;
    case 'KMH':
      return value * KMH_TO_KT;
    default:
      return value;
  }
}

/** 从原始 METAR 解析风况；没有风组时返回 null */
export function parseMetarWind(raw: string | undefined): MetarWind | null {
  const text = (raw ?? '').toUpperCase();
  if (text.length === 0) return null;

  const match = WIND_GROUP.exec(text);
  if (!match) return null;

  const [, rawDirection, rawSpeed, rawGust, unit] = match;
  const speedKt = toKnots(Number.parseInt(rawSpeed, 10), unit);
  const gustKt = rawGust === undefined ? undefined : toKnots(Number.parseInt(rawGust, 10), unit);

  // 00000KT 是静风：既没有方向也没有速度，指针不该乱指
  if (rawDirection === '000' && speedKt === 0) {
    return { variable: false, calm: true, speedKt: 0 };
  }

  if (rawDirection === 'VRB') {
    return { variable: true, calm: false, speedKt, gustKt };
  }

  const directionDeg = Number.parseInt(rawDirection, 10);
  // 风向 360 与 0 都表示正北，统一成 360 之内；超过 360 的是坏数据，丢掉方向但保留风速
  if (!Number.isFinite(directionDeg) || directionDeg > 360) {
    return { variable: false, calm: false, speedKt, gustKt };
  }

  return {
    directionDeg: directionDeg % 360,
    speedKt,
    gustKt,
    variable: false,
    calm: false,
  };
}

/** 风速的展示串：整数节 */
export function formatWindSpeedKt(speedKt: number | undefined): string {
  if (speedKt === undefined || !Number.isFinite(speedKt)) return '--';
  return `${Math.round(speedKt)} kt`;
}

/** 风向的展示串：三位补零 + 度号 */
export function formatWindDirection(wind: MetarWind | null): string {
  if (!wind) return '--';
  if (wind.calm) return 'CALM';
  if (wind.variable || wind.directionDeg === undefined) return 'VRB';
  return `${String(Math.round(wind.directionDeg)).padStart(3, '0')}°`;
}
