/**
 * 计划航路解析（纯函数）
 *
 * 中间件已经把 SimBrief 的原始 OFP 归一化过一轮（210KB → 5KB），这里只做
 * 「后端字段 → 前端模型」的翻译与校验。
 *
 * 仍然要校验的原因：后端归一化时**保留了上游的宽松语义** —— 缺失的数值字段
 * 会因为 `omitempty` 直接不出现，而不是给 0。所以这里每个可选值都得判在。
 */

import { pickDouble, toJsonMap, toText } from '../../../core/utils/parse-utils';
import { isValidCoordinate } from '../../../core/utils/coordinates';
import type {
  PlannedAirport,
  PlannedFuel,
  PlannedRoute,
  PlannedRoutePoint,
} from '../models/planned-route-models';

/** 解析后端返回的一个机场块 */
function parsePlannedAirport(raw: unknown): PlannedAirport | null {
  const map = toJsonMap(raw);
  if (!map) return null;

  const code = toText(map.icao).trim().toUpperCase();
  if (code.length === 0) return null;

  const latitude = pickDouble(map, ['lat']);
  const longitude = pickDouble(map, ['lon']);
  if (latitude === undefined || longitude === undefined) return null;
  if (!isValidCoordinate(latitude, longitude)) return null;

  const name = toText(map.name).trim();
  return {
    code,
    name: name.length > 0 ? name : undefined,
    position: { latitude, longitude },
  };
}

/** 解析一个航路点；坐标不合法就丢弃（画到 (0,0) 比不画更糟） */
function parsePlannedPoint(raw: unknown): PlannedRoutePoint | null {
  const map = toJsonMap(raw);
  if (!map) return null;

  const latitude = pickDouble(map, ['lat']);
  const longitude = pickDouble(map, ['lon']);
  if (latitude === undefined || longitude === undefined) return null;
  if (!isValidCoordinate(latitude, longitude)) return null;

  const ident = toText(map.ident).trim();
  if (ident.length === 0) return null;

  const name = toText(map.name).trim();
  const viaAirway = toText(map.via_airway).trim();
  const stage = toText(map.stage).trim();

  return {
    ident,
    name: name.length > 0 ? name : undefined,
    position: { latitude, longitude },
    altitudeFt: pickDouble(map, ['altitude_ft']),
    viaAirway: viaAirway.length > 0 ? viaAirway : undefined,
    // 后端已经把上游的 "1"/"0" 归一成布尔，这里只认真布尔
    isSidStar: map.is_sid_star === true,
    stage: stage.length > 0 ? stage : undefined,
  };
}

function parsePlannedFuel(raw: unknown): PlannedFuel {
  const map = toJsonMap(raw);
  if (!map) return {};
  const units = toText(map.units).trim();
  return {
    units: units.length > 0 ? units : undefined,
    planRamp: pickDouble(map, ['plan_ramp']),
    planTakeoff: pickDouble(map, ['plan_takeoff']),
    planLanding: pickDouble(map, ['plan_landing']),
    enrouteBurn: pickDouble(map, ['enroute_burn']),
    alternateBurn: pickDouble(map, ['alternate_burn']),
    contingency: pickDouble(map, ['contingency']),
    reserve: pickDouble(map, ['reserve']),
    taxi: pickDouble(map, ['taxi']),
    extra: pickDouble(map, ['extra']),
  };
}

/**
 * 把中间件返回的 plan 解析成前端模型。
 *
 * 起降场缺任何一个都返回 null —— 一份连起降场都不全的计划没法用来做简报，
 * 与其半残地导入，不如让调用方明确报错。
 */
export function parsePlannedRoute(raw: unknown): PlannedRoute | null {
  const map = toJsonMap(raw);
  if (!map) return null;

  const origin = parsePlannedAirport(map.origin);
  const destination = parsePlannedAirport(map.destination);
  if (!origin || !destination) return null;

  const rawPoints = Array.isArray(map.points) ? map.points : [];
  const points = rawPoints
    .map(parsePlannedPoint)
    .filter((point): point is PlannedRoutePoint => point !== null);

  // 一条画不出线的航路（不足两点）同样视为无效
  if (points.length < 2) return null;

  const flightNumber = toText(map.flight_number).trim();
  const aircraftIcao = toText(map.aircraft_icao).trim();
  const routeText = toText(map.route).trim();
  const generatedAtSec = pickDouble(map, ['generated_at']);

  return {
    flightNumber: flightNumber.length > 0 ? flightNumber : undefined,
    aircraftIcao: aircraftIcao.length > 0 ? aircraftIcao : undefined,
    origin,
    destination,
    alternate: parsePlannedAirport(map.alternate) ?? undefined,
    routeText: routeText.length > 0 ? routeText : undefined,
    distanceNm: pickDouble(map, ['route_distance_nm']),
    cruiseAltitudeFt: pickDouble(map, ['cruise_altitude_ft']),
    enrouteSeconds: pickDouble(map, ['enroute_seconds']),
    points,
    fuel: parsePlannedFuel(map.fuel),
    // 后端给的是 Unix 秒
    generatedAt:
      generatedAtSec !== undefined && generatedAtSec > 0
        ? new Date(generatedAtSec * 1000)
        : undefined,
  };
}
