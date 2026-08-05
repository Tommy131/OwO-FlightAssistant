import { toJsonMap } from '../../../core/utils/parse-utils';
import { metarFromApi } from '../../airport_search/models/airport-search-models';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';

/**
 * 选中机场的实时天气
 *
 * 桌面版底卡上那条 METAR 是有数据的，Web 版移植时把 `rawMetar` /
 * `decodedMetar` / `approachRule` 三个字段硬写成了 undefined，
 * 接口其实一直都在（`/api/v1/metar/{icao}` 同时返回原文与中文解读）。
 */

export interface AirportWeather {
  readonly rawMetar?: string;
  readonly decodedMetar?: string;
  /** 目视/仪表飞行等级：VFR / MVFR / IFR / LIFR */
  readonly approachRule: string;
}

export async function fetchAirportWeather(icao: string): Promise<AirportWeather | null> {
  await MiddlewareHttpService.init();
  const response = await MiddlewareHttpService.getMetarByIcao(icao);
  const body = response.objectBody;
  if (!body) return null;

  const metar = metarFromApi(body);
  const raw = (metar.raw ?? '').trim();
  const decoded = (metar.decoded ?? '').trim();
  if (raw.length === 0 && decoded.length === 0) return null;

  return {
    rawMetar: raw.length > 0 ? raw : undefined,
    decodedMetar: decoded.length > 0 ? decoded : undefined,
    approachRule: deriveApproachRule(body, raw),
  };
}

/**
 * 由能见度与云底高推出飞行等级
 *
 * 后端不提供这个字段，按 FAA 的标准分级现算：
 * - LIFR 云底 <500ft 或 能见度 <1 法定英里
 * - IFR  云底 500–1000ft 或 能见度 1–3 英里
 * - MVFR 云底 1000–3000ft 或 能见度 3–5 英里
 * - VFR  云底 >3000ft 且 能见度 >5 英里
 *
 * 两个条件取更严的那个；数据不足时返回 UNK，不猜。
 */
function deriveApproachRule(body: Record<string, unknown>, raw: string): string {
  const map = toJsonMap(body) ?? {};
  const visibilityMiles = parseVisibilityMiles(String(map.visibility ?? ''), raw);
  const ceilingFt = parseCeilingFt(String(map.clouds ?? ''), raw);
  if (visibilityMiles === undefined && ceilingFt === undefined) return 'UNK';

  const rank = (value: number): number => value; // 0=LIFR 1=IFR 2=MVFR 3=VFR
  const visRank =
    visibilityMiles === undefined
      ? 3
      : visibilityMiles < 1
        ? rank(0)
        : visibilityMiles < 3
          ? rank(1)
          : visibilityMiles <= 5
            ? rank(2)
            : rank(3);
  const ceilRank =
    ceilingFt === undefined
      ? 3
      : ceilingFt < 500
        ? rank(0)
        : ceilingFt < 1000
          ? rank(1)
          : ceilingFt <= 3000
            ? rank(2)
            : rank(3);

  return ['LIFR', 'IFR', 'MVFR', 'VFR'][Math.min(visRank, ceilRank)];
}

/** METAR 能见度：4 位米数（9999=10km+），或 `1 1/2SM` 这类英里写法 */
function parseVisibilityMiles(field: string, raw: string): number | undefined {
  const meters = Number.parseInt(field.trim(), 10);
  if (Number.isFinite(meters) && meters > 0) return meters / 1609.34;

  const statute = raw.match(/(\d+)(?:\s+(\d+)\/(\d+))?SM/);
  if (statute) {
    const whole = Number(statute[1]);
    const fraction =
      statute[2] && statute[3] ? Number(statute[2]) / Number(statute[3]) : 0;
    return whole + fraction;
  }
  return undefined;
}

/** 云底高：只有 BKN/OVC 才算「云底」，FEW/SCT 不构成 ceiling */
function parseCeilingFt(field: string, raw: string): number | undefined {
  const text = `${field} ${raw}`;
  let lowest: number | undefined;
  for (const match of text.matchAll(/(BKN|OVC|VV)(\d{3})/g)) {
    const hundreds = Number(match[2]);
    if (!Number.isFinite(hundreds)) continue;
    const feet = hundreds * 100;
    if (lowest === undefined || feet < lowest) lowest = feet;
  }
  return lowest;
}
