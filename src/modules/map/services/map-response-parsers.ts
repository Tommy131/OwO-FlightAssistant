import { pickDouble, pickString, toJsonMap, toText } from '../../../core/utils/parse-utils';
import type {
  MapAerowayFeature,
  MapCoordinate,
  MapAirportMarker,
  MapHoldingPattern,
  MapRestrictedZone,
  MapRunwayNavaid,
  MapTaxiwayFileData,
  MapTaxiwayNode,
  MapTaxiwaySegment,
} from '../models/map-models';

const AEROWAY_KINDS: readonly string[] = [
  'runway',
  'taxiway',
  'taxilane',
  'apron',
  'helipad',
];

export function isValidCoordinate(lat: number, lon: number): boolean {
  return (
    Number.isFinite(lat) &&
    Number.isFinite(lon) &&
    lat >= -90 &&
    lat <= 90 &&
    lon >= -180 &&
    lon <= 180 &&
    !(lat === 0 && lon === 0)
  );
}

/**
 * 后端响应 → 领域模型
 *
 * 这些函数原本挤在 map-store.ts 里（那个文件一度 1726 行）。它们其实是**纯解析**：
 * 输入一坨 unknown，输出领域模型，不碰 store、不发请求、不依赖框架。
 * 拆出来之后既能被单测直接调用，也让 store 回到「只管状态」的本分。
 *
 * ── 为什么到处是多候选键 ──
 * 中间件返回 PascalCase（`Runways` / `LeLat` / `HeIdent`），而部分接口又是
 * snake_case。解析一律走 `pickString` / `pickDouble` 的多候选键写法，
 * 不要写死单一大小写。
 */

export function parseHoldingPattern(raw: unknown): MapHoldingPattern | null {
  const map = toJsonMap(raw);
  if (!map) return null;
  const fix = pickString(map, ['fix']);
  const lat = pickDouble(map, ['lat']);
  const lon = pickDouble(map, ['lon']);
  if (!fix || lat === undefined || lon === undefined) return null;
  return {
    fix,
    lat,
    lon,
    inboundCourse: pickDouble(map, ['inbound_course', 'inboundCourse']) ?? 0,
    legMinutes: pickDouble(map, ['leg_minutes', 'legMinutes']) ?? 0,
    legDistanceNm: pickDouble(map, ['leg_distance_nm', 'legDistanceNm']) ?? 0,
    turnDirection: pickString(map, ['turn_direction', 'turnDirection']) === 'L' ? 'L' : 'R',
    minAltitudeFt: pickDouble(map, ['min_altitude_ft', 'minAltitudeFt']) ?? 0,
    maxAltitudeFt: pickDouble(map, ['max_altitude_ft', 'maxAltitudeFt']) ?? 0,
    maxSpeedKt: pickDouble(map, ['max_speed_kt', 'maxSpeedKt']) ?? 0,
  };
}

export function parseRunwayNavaid(raw: unknown): MapRunwayNavaid | null {
  const map = toJsonMap(raw);
  if (!map) return null;
  const runway = pickString(map, ['runway'])?.toUpperCase();
  if (!runway) return null;
  return {
    runway,
    category: pickString(map, ['category']),
    locIdent: pickString(map, ['loc_ident', 'locIdent']),
    locFrequency: pickString(map, ['loc_frequency', 'locFrequency']),
    locCourse: pickDouble(map, ['loc_course', 'locCourse']),
    locTrueBearing: pickDouble(map, ['loc_true_bearing', 'locTrueBearing']),
    glideslopeAngle: pickDouble(map, ['glideslope_angle', 'glideslopeAngle']),
    elevationFt: pickDouble(map, ['elevation_ft', 'elevationFt']),
    hasDme: map.has_dme === true || map.hasDme === true,
    dmeIdent: pickString(map, ['dme_ident', 'dmeIdent']),
  };
}

export function parseAerowayFeature(raw: unknown): MapAerowayFeature | undefined {
  const map = toJsonMap(raw);
  if (!map) return undefined;

  const kind = toText(map.kind).toLowerCase();
  if (!AEROWAY_KINDS.includes(kind)) return undefined;

  // 后端给的是 [lat, lon] 数对数组
  const rawPoints = Array.isArray(map.points) ? map.points : [];
  const points: MapCoordinate[] = [];
  for (const entry of rawPoints) {
    if (!Array.isArray(entry) || entry.length < 2) continue;
    const lat = Number(entry[0]);
    const lon = Number(entry[1]);
    if (!isValidCoordinate(lat, lon)) continue;
    points.push({ latitude: lat, longitude: lon });
  }
  if (points.length < 2) return undefined;

  const ref = toText(map.ref).trim();
  const name = toText(map.name).trim();
  return {
    kind: kind as MapAerowayFeature['kind'],
    ref: ref.length > 0 ? ref : undefined,
    name: name.length > 0 ? name : undefined,
    closed: map.closed === true,
    points,
  };
}

/** 后端返回 PascalCase 字段，这里做大小写兼容解析 */
export function parseNearbyAirport(raw: unknown): MapAirportMarker | undefined {
  const map = toJsonMap(raw);
  if (!map) return undefined;
  const pick = (...keys: string[]): unknown => {
    for (const key of keys) {
      if (map[key] !== undefined && map[key] !== null) return map[key];
    }
    return undefined;
  };
  const code = toText(pick('ICAO', 'icao')).trim().toUpperCase();
  const lat = Number(pick('Lat', 'lat', 'latitude'));
  const lon = Number(pick('Lon', 'lon', 'longitude'));
  if (code.length === 0 || !isValidCoordinate(lat, lon)) return undefined;

  const name = toText(pick('Name', 'name')).trim();
  return {
    code,
    name: name.length > 0 ? name : undefined,
    position: { latitude: lat, longitude: lon },
    // 视野内机场一律按次要标记画，主要标记留给航线上的起降/备降场
    isPrimary: false,
  };
}

export function parseTaxiwayFile(decoded: unknown): MapTaxiwayFileData | null {
  if (!decoded || typeof decoded !== 'object') return null;
  const raw = decoded as Record<string, unknown>;

  const nodesRaw = Array.isArray(raw.nodes) ? raw.nodes : [];
  const nodes: MapTaxiwayNode[] = [];
  for (const item of nodesRaw) {
    if (!item || typeof item !== 'object') continue;
    const node = item as Record<string, unknown>;
    const position = node.position as Record<string, unknown> | undefined;
    const latitude = Number(position?.latitude ?? node.lat);
    const longitude = Number(position?.longitude ?? node.lon);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) continue;
    nodes.push({
      position: { latitude, longitude },
      name: typeof node.name === 'string' ? node.name : undefined,
      note: typeof node.note === 'string' ? node.note : undefined,
    });
  }

  const segmentsRaw = Array.isArray(raw.segments) ? raw.segments : [];
  const segments: MapTaxiwaySegment[] = [];
  for (const item of segmentsRaw) {
    if (!item || typeof item !== 'object') continue;
    const segment = item as Record<string, unknown>;
    const fromIndex = Number(segment.fromIndex);
    const toIndex = Number(segment.toIndex);
    if (!Number.isInteger(fromIndex) || !Number.isInteger(toIndex)) continue;
    segments.push({
      fromIndex,
      toIndex,
      name: typeof segment.name === 'string' ? segment.name : undefined,
      note: typeof segment.note === 'string' ? segment.note : undefined,
      speedLimitKt: Number.isFinite(Number(segment.speedLimitKt))
        ? Number(segment.speedLimitKt)
        : undefined,
    });
  }

  return {
    icao: typeof raw.icao === 'string' ? raw.icao : undefined,
    nodes,
    segments,
  };
}

/**
 * 解析后端返回的限制空域
 * 中间件按机场生成圆形管制区（center_lat/center_lon/radius_meters + severity）
 */
export function parseRestrictedZone(raw: unknown): MapRestrictedZone | null {
  const map = toJsonMap(raw);
  if (!map) return null;

  const id = toText(map.id).trim();
  if (id.length === 0) return null;

  const lat = Number(map.center_lat ?? map.latitude);
  const lon = Number(map.center_lon ?? map.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;

  const radiusM = Number(map.radius_meters);
  return {
    id,
    name: typeof map.name === 'string' ? map.name : undefined,
    category: typeof map.severity === 'string' ? map.severity : undefined,
    polygon: [],
    center: { latitude: lat, longitude: lon },
    radiusM: Number.isFinite(radiusM) ? radiusM : 5000,
    lowerAltitudeFt: parseAltitudeFt(map.lower_limit),
    upperAltitudeFt: parseAltitudeFt(map.upper_limit),
  };
}

/** `"6500 ft AMSL"` / `"SFC"` → 数值高度 */
export function parseAltitudeFt(raw: unknown): number | undefined {
  if (typeof raw !== 'string') return undefined;
  if (raw.trim().toUpperCase() === 'SFC') return 0;
  const match = raw.match(/(\d+)/);
  return match ? Number(match[1]) : undefined;
}

export function isDefined<T>(value: T | null | undefined): value is T {
  return value !== null && value !== undefined;
}

/** 解析 RainViewer 索引，取雷达帧列表 */
export function extractRadarFrames(
  data: unknown,
): { time: number; host: string; path: string }[] {
  if (!data || typeof data !== 'object') return [];
  const root = data as Record<string, unknown>;
  const host = typeof root.host === 'string' ? root.host : '';
  const radar = root.radar as Record<string, unknown> | undefined;
  const past = Array.isArray(radar?.past) ? radar.past : [];

  return past
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const frame = item as Record<string, unknown>;
      const time = Number(frame.time);
      const path = typeof frame.path === 'string' ? frame.path : '';
      if (!Number.isFinite(time) || path.length === 0) return null;
      return { time, host, path };
    })
    .filter((frame): frame is { time: number; host: string; path: string } => frame !== null);
}
