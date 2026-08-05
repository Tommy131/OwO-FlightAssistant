import { calculateDistanceNm } from '../../../core/utils/parse-utils';
import type {
  AirportDetailData,
  MetarData,
} from '../../airport_search/models/airport-search-models';
import type { BriefingAirportBundle, BriefingFuelPlan } from '../models/briefing-models';

/**
 * 简报生成服务
 *
 * 对应 Flutter 版 `modules/briefing/services/briefing_service.dart`。
 * 燃油系数、跑道选择、报文摘要正则与文本模板逐条对齐 ——
 * 生成的简报文本与桌面版逐行一致。
 */

// ──────────────────────────────────────────────────────────────────────────
// 燃油计划
// ──────────────────────────────────────────────────────────────────────────

/**
 * 构建燃油计划
 * 航段 = 距离 × 2.5；备降固定按 200NM 计；备份 1500；滑行 200；额外 5%
 */
export function buildFuelPlan(options: {
  distanceNm?: number;
  hasAlternate: boolean;
}): BriefingFuelPlan {
  const { distanceNm, hasAlternate } = options;

  const trip = (distanceNm ?? 0) * 2.5;
  const alternate = hasAlternate ? 200 * 2.5 : 0;
  const reserve = 1500;
  const taxi = 200;
  const extra = trip * 0.05;
  const total = trip + alternate + reserve + taxi + extra;
  const estimatedArrivalFuel = reserve + alternate;

  // 估算平均小时油耗，限制在 1800–3400 KG/H
  const avgFlow =
    distanceNm === undefined || distanceNm <= 0
      ? 2600
      : Math.min(Math.max(trip / (distanceNm / 450), 1800), 3400);

  return { trip, alternate, reserve, taxi, extra, total, avgFlow, estimatedArrivalFuel };
}

// ──────────────────────────────────────────────────────────────────────────
// 跑道选择
// ──────────────────────────────────────────────────────────────────────────

/**
 * 按风向挑选最合适的跑道（逆风角最小者）
 * 无跑道数据返回 null；无法解析风向时退回第一条跑道
 */
export function selectBestRunway(
  airport: AirportDetailData,
  metar: MetarData | undefined,
): string | undefined {
  if (airport.runways.length === 0) return undefined;

  const windDirection = parseWindDirection(metar?.raw ?? metar?.decoded ?? '');
  if (windDirection === undefined) return airport.runways[0].ident;

  let best: string | undefined;
  let minDiff = 180;

  for (const runway of airport.runways) {
    const parts = runway.ident
      .split('/')
      .map((part) => part.trim())
      .filter((part) => part.length > 0);

    for (const part of parts) {
      const heading = parseRunwayHeading(part);
      if (heading === undefined) continue;
      const diff = Math.abs(windDirection - heading);
      const normalized = diff > 180 ? 360 - diff : diff;
      if (normalized < minDiff) {
        minDiff = normalized;
        best = part;
      }
    }
  }
  return best ?? airport.runways[0].ident;
}

/** 跑道编号 ×10 即为磁航向（`27L` → 270°） */
function parseRunwayHeading(ident: string): number | undefined {
  const match = ident.match(/^(\d{1,2})/);
  if (!match) return undefined;
  const value = Number.parseInt(match[1], 10);
  return Number.isFinite(value) ? value * 10 : undefined;
}

function parseWindDirection(source: string): number | undefined {
  const match = source.match(/\b(\d{3}|VRB)\d{2,3}(?:G\d{2,3})?KT\b/);
  if (!match || match[1] === 'VRB') return undefined;
  const value = Number.parseInt(match[1], 10);
  return Number.isFinite(value) ? value : undefined;
}

// ──────────────────────────────────────────────────────────────────────────
// 简报文本
// ──────────────────────────────────────────────────────────────────────────

/** 生成简报正文（纯文本，与桌面版逐行一致） */
export function buildBriefingSummary(options: {
  generatedAt: Date;
  flightNo: string;
  departure: BriefingAirportBundle;
  arrival: BriefingAirportBundle;
  alternate?: BriefingAirportBundle;
  route: string;
  cruiseAltitude: number;
  distanceNm?: number;
  estimatedMinutes?: number;
  depRunway?: string;
  arrRunway?: string;
  altRunway?: string;
  fuel: BriefingFuelPlan;
}): string {
  const {
    generatedAt,
    flightNo,
    departure,
    arrival,
    alternate,
    route,
    cruiseAltitude,
    distanceNm,
    estimatedMinutes,
    depRunway,
    arrRunway,
    altRunway,
    fuel,
  } = options;

  return [
    `FLT: ${flightNo}`,
    `GEN: ${formatDateTime(generatedAt)}`,
    `DEP: ${formatAirportLine(departure.airport)}`,
    `ARR: ${formatAirportLine(arrival.airport)}`,
    `ALT: ${alternate ? formatAirportLine(alternate.airport) : '--'}`,
    `RTE: ${route}`,
    `CRZ: FL${Math.round(cruiseAltitude / 100)}`,
    `DIST: ${distanceNm !== undefined ? `${distanceNm.toFixed(0)} NM` : '--'}`,
    `EET: ${estimatedMinutes !== undefined ? formatDuration(estimatedMinutes) : '--'}`,
    `DEP RWY: ${depRunway ?? '--'}`,
    `ARR RWY: ${arrRunway ?? '--'}`,
    `ALT RWY: ${altRunway ?? '--'}`,
    `DEP WX: ${formatWeatherLine(departure.metar)}`,
    `ARR WX: ${formatWeatherLine(arrival.metar)}`,
    `ALT WX: ${alternate ? formatWeatherLine(alternate.metar) : '--'}`,
    `TRIP FUEL: ${fuel.trip.toFixed(0)} KG`,
    `ALTN FUEL: ${fuel.alternate.toFixed(0)} KG`,
    `RESV FUEL: ${fuel.reserve.toFixed(0)} KG`,
    `TAXI FUEL: ${fuel.taxi.toFixed(0)} KG`,
    `EXTRA FUEL: ${fuel.extra.toFixed(0)} KG`,
    `TOTAL FUEL: ${fuel.total.toFixed(0)} KG`,
    `AVG FLOW: ${fuel.avgFlow.toFixed(0)} KG/H`,
    `ETA FUEL: ${fuel.estimatedArrivalFuel.toFixed(0)} KG`,
    '',
  ].join('\n');
}

function formatAirportLine(airport: AirportDetailData): string {
  return [airport.icao, airport.name, airport.city]
    .filter((part): part is string => part !== undefined && part.length > 0)
    .join(' | ');
}

/** 从原始报文正则提取风/能见/温露/QNH 四项关键徽章 */
function formatWeatherLine(metar: MetarData | undefined): string {
  if (!metar || (metar.raw ?? '').length === 0) return 'NO METAR';
  const source = (metar.raw ?? metar.decoded ?? '').trim();

  const wind = source.match(/\b(\d{3}|VRB)(\d{2,3})G?(\d{2,3})?KT\b/);
  const vis = source.match(/\b(\d{4})\b/);
  const temp = source.match(/\b(M?\d{2})\/(M?\d{2})\b/);
  const qnh = source.match(/\bQ(\d{4})\b/);

  const pieces = [
    wind ? `WIND ${wind[1]}${wind[2]}KT` : null,
    vis ? `VIS ${vis[1]}m` : null,
    temp ? `TEMP ${temp[1]}/${temp[2]}` : null,
    qnh ? `QNH ${qnh[1]}` : null,
  ].filter((piece): piece is string => piece !== null);

  return pieces.length > 0 ? pieces.join(' · ') : source;
}

function formatDateTime(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function formatDuration(minutes: number): string {
  return `${Math.trunc(minutes / 60)}H ${String(minutes % 60).padStart(2, '0')}M`;
}

/** 大圆航段距离（NM），任一坐标缺失返回 undefined */
export function computeLegDistanceNm(
  lat1?: number,
  lon1?: number,
  lat2?: number,
  lon2?: number,
): number | undefined {
  if (lat1 === undefined || lon1 === undefined || lat2 === undefined || lon2 === undefined) {
    return undefined;
  }
  return calculateDistanceNm(lat1, lon1, lat2, lon2);
}

/** 未填航班号时随机生成一个（与桌面版一致：CA + 1000–9999） */
export function generateFlightNumber(): string {
  return `CA${1000 + Math.floor(Math.random() * 9000)}`;
}
