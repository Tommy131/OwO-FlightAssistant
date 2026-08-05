import {
  pickDouble,
  pickString,
  toDouble,
  toInt,
  toJsonMap,
  type JsonMap,
} from '../../../core/utils/parse-utils';

/**
 * 机场搜索数据模型
 *
 * 对应 Flutter 版 `modules/airport_search/models/` 下的 9 个文件。
 * 后端在不同版本间字段命名不一致（snake_case / camelCase / PascalCase 混用），
 * 因此全部走 `pick*` 多候选键解析，与桌面版 `model_utils.dart` 行为一致。
 */

// ──────────────────────────────────────────────────────────────────────────
// 跑道 / 频率 / 停机位
// ──────────────────────────────────────────────────────────────────────────

export interface AirportRunwayData {
  ident: string;
  lengthM?: number;
  surface?: string;
  leIdent?: string;
  heIdent?: string;
  leLat?: number;
  leLon?: number;
  heLat?: number;
  heLon?: number;
}

export function runwayFromApi(data: JsonMap): AirportRunwayData {
  return {
    ident: pickString(data, ['ident', 'Ident', 'name', 'Name']) ?? '-',
    lengthM: pickDouble(data, ['length_m', 'lengthM', 'LengthM']),
    surface: pickString(data, ['surface', 'Surface', 'type', 'Type']),
    leIdent: pickString(data, ['le_ident', 'leIdent', 'LeIdent']),
    heIdent: pickString(data, ['he_ident', 'heIdent', 'HeIdent']),
    leLat: pickDouble(data, ['le_lat', 'leLat', 'LeLat']),
    leLon: pickDouble(data, ['le_lon', 'leLon', 'LeLon']),
    heLat: pickDouble(data, ['he_lat', 'heLat', 'HeLat']),
    heLon: pickDouble(data, ['he_lon', 'heLon', 'HeLon']),
  };
}

export interface AirportFrequencyData {
  type?: string;
  value?: string;
}

export function frequencyFromApi(data: JsonMap): AirportFrequencyData {
  return {
    type: pickString(data, ['type', 'Type']),
    value: pickString(data, ['frequency', 'Frequency', 'value']),
  };
}

export interface AirportParkingData {
  name?: string;
  latitude?: number;
  longitude?: number;
  headingDeg?: number;
}

export function parkingFromApi(data: JsonMap): AirportParkingData {
  return {
    name: pickString(data, ['name', 'Name', 'ident', 'Ident']),
    latitude: pickDouble(data, ['lat', 'latitude', 'Lat']),
    longitude: pickDouble(data, ['lon', 'lng', 'longitude', 'Lon']),
    headingDeg: pickDouble(data, ['heading_deg', 'headingDeg', 'heading', 'Heading']),
  };
}

// ──────────────────────────────────────────────────────────────────────────
// 机场详情
// ──────────────────────────────────────────────────────────────────────────

export interface AirportDetailData {
  /** 原始响应，用于调试展示 */
  payload: JsonMap;
  icao: string;
  iata?: string;
  name?: string;
  city?: string;
  country?: string;
  latitude?: number;
  longitude?: number;
  elevationFt?: number;
  source?: string;
  airac?: string;
  runways: AirportRunwayData[];
  parkings: AirportParkingData[];
  frequencies: AirportFrequencyData[];
}

export function airportDetailFromApi(data: JsonMap): AirportDetailData {
  const payloadRoot = toJsonMap(data.data) ?? data;

  // 详情可能嵌在 airport_detail 里，也可能就是 payloadRoot 本身
  let detail = pickMapMulti(payloadRoot, ['airport_detail', 'airportDetail', 'AirportDetail']);
  if (
    !detail &&
    (pickMapMulti(payloadRoot, ['airport', 'Airport']) !== null ||
      payloadRoot.sources !== undefined ||
      payloadRoot.Sources !== undefined)
  ) {
    detail = payloadRoot;
  }
  const scope = detail ?? payloadRoot;
  const airport = pickMapMulti(scope, ['airport', 'Airport']);

  const icao = (
    pickStringIn(airport, ['icao', 'ICAO']) ??
    pickString(scope, ['icao', 'ICAO']) ??
    pickString(payloadRoot, ['icao', 'ICAO']) ??
    ''
  ).toUpperCase();

  return {
    payload: data,
    icao,
    iata: pickStringIn(airport, ['iata', 'IATA']),
    name: pickStringIn(airport, ['name', 'Name']) ?? pickString(scope, ['name', 'Name']),
    city: pickStringIn(airport, ['city', 'City']) ?? pickString(scope, ['city', 'City']),
    country:
      pickStringIn(airport, ['country', 'Country']) ?? pickString(scope, ['country', 'Country']),
    latitude:
      pickDoubleIn(airport, ['latitude', 'lat', 'Lat']) ??
      pickDouble(payloadRoot, ['lat', 'latitude', 'Lat']),
    longitude:
      pickDoubleIn(airport, ['longitude', 'lon', 'lng', 'Lon']) ??
      pickDouble(payloadRoot, ['lng', 'lon', 'longitude', 'Lon']),
    elevationFt:
      (airport ? toInt(airport.elevation ?? airport.Elevation) : undefined) ??
      toInt(payloadRoot.elevation ?? payloadRoot.Elevation),
    source:
      pickString(payloadRoot, ['database_source', 'source', 'Source']) ??
      pickStringIn(airport, ['source', 'Source']) ??
      pickString(scope, ['data_source', 'source', 'Source']),
    airac: pickString(payloadRoot, ['airac', 'AIRAC']) ?? pickString(scope, ['airac', 'AIRAC']),
    runways: mapList(scope, ['runways', 'Runways']).map(runwayFromApi),
    parkings: mapList(scope, [
      'parkings',
      'Parkings',
      'parking_spots',
      'parkingSpots',
      'parking_points',
    ]).map(parkingFromApi),
    frequencies: mapList(scope, ['frequencies', 'Frequencies']).map(frequencyFromApi),
  };
}

// ──────────────────────────────────────────────────────────────────────────
// 搜索建议 / 收藏 / METAR / 查询结果
// ──────────────────────────────────────────────────────────────────────────

export interface AirportSuggestionData {
  icao: string;
  name?: string;
  source?: string;
}

export function suggestionFromApi(data: JsonMap): AirportSuggestionData {
  return {
    icao: (pickString(data, ['icao', 'ICAO']) ?? '').toUpperCase(),
    name: pickString(data, ['name', 'Name']),
    source: pickString(data, ['source', 'Source']),
  };
}

export interface FavoriteAirportEntry {
  icao: string;
  name?: string;
  latitude?: number;
  longitude?: number;
}

export function favoriteFromAirport(airport: AirportDetailData): FavoriteAirportEntry {
  return {
    icao: airport.icao.toUpperCase(),
    name: airport.name,
    latitude: airport.latitude,
    longitude: airport.longitude,
  };
}

export function favoriteFromJson(json: JsonMap): FavoriteAirportEntry {
  return {
    icao: (pickString(json, ['icao']) ?? '').toUpperCase(),
    name: pickString(json, ['name']),
    latitude: toDouble(json.latitude),
    longitude: toDouble(json.longitude),
  };
}

export interface MetarData {
  raw?: string;
  decoded?: string;
  wind?: string;
  visibility?: string;
  temperature?: string;
  altimeter?: string;
}

export function metarFromApi(data: JsonMap): MetarData {
  const payloadRoot = toJsonMap(data.data) ?? data;
  return {
    raw: pickString(payloadRoot, ['raw_metar', 'raw', 'Raw', 'metar']),
    decoded: pickString(payloadRoot, [
      'translated_metar',
      'decoded',
      'Decoded',
      'translatedMetar',
    ]),
    wind: pickString(payloadRoot, ['display_wind', 'wind']),
    visibility: pickString(payloadRoot, ['display_visibility', 'visibility']),
    temperature: pickString(payloadRoot, ['display_temperature', 'temperature']),
    altimeter: pickString(payloadRoot, ['display_altimeter', 'altimeter']),
  };
}

export interface AirportQueryResult {
  airport: AirportDetailData;
  metar: MetarData;
}

// ──────────────────────────────────────────────────────────────────────────
// 内部工具
// ──────────────────────────────────────────────────────────────────────────

function pickMapMulti(map: JsonMap, keys: readonly string[]): JsonMap | null {
  for (const key of keys) {
    const value = toJsonMap(map[key]);
    if (value) return value;
  }
  return null;
}

function pickStringIn(map: JsonMap | null, keys: readonly string[]): string | undefined {
  return map ? pickString(map, keys) : undefined;
}

function pickDoubleIn(map: JsonMap | null, keys: readonly string[]): number | undefined {
  return map ? pickDouble(map, keys) : undefined;
}

/** 从多个候选键取数组，并过滤出对象元素 */
function mapList(map: JsonMap, keys: readonly string[]): JsonMap[] {
  for (const key of keys) {
    const value = map[key];
    if (!Array.isArray(value)) continue;
    return value.map((item) => toJsonMap(item)).filter((item): item is JsonMap => item !== null);
  }
  return [];
}
