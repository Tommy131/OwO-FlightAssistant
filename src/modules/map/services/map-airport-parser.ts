import { isValidCoordinate } from '../../../core/utils/coordinates';
import { pickMap, type JsonMap } from '../../../core/utils/parse-utils';
import {
  airportDetailFromApi,
  type AirportDetailData,
  type AirportRunwayData,
} from '../../airport_search/models/airport-search-models';
import type {
  MapAirportMarker,
  MapParkingSpot,
  MapRunwayGeometry,
  MapSelectedAirportDetail,
} from '../models/map-models';

/**
 * 机场 API → 地图详情
 *
 * 对应 Flutter 版 `modules/map/providers/map_airport_api_parser.dart`。
 * 复用 airport_search 模块已有的解析结果，再补上地图专用的几何信息。
 */

/** 从 `/api/v1/airport/{icao}` 响应构建地图选中机场详情 */
export function parseAirportDetail(
  body: JsonMap,
  fallbackIcao: string,
): MapSelectedAirportDetail | null {
  // 后端返回结构在不同版本间有嵌套差异，逐层向下探测
  const payload = pickMap(body, ['data']) ?? body;
  const detailRoot = pickMap(payload, ['airport_detail', 'airportDetail']) ?? payload;

  const detail = airportDetailFromApi(detailRoot);
  const code = (detail.icao || fallbackIcao).trim().toUpperCase();
  if (code.length === 0) return null;

  const marker: MapAirportMarker = {
    code,
    name: detail.name,
    position: {
      latitude: detail.latitude ?? 0,
      longitude: detail.longitude ?? 0,
    },
    isPrimary: true,
  };

  return {
    marker,
    source: detail.source,
    runways: detail.runways.map((runway) => runway.ident).filter((ident) => ident.length > 0),
    runwayGeometries: detail.runways
      .map(toRunwayGeometry)
      .filter((geometry): geometry is MapRunwayGeometry => geometry !== null),
    parkingSpots: toParkingSpots(detail),
    frequencyBadges: detail.frequencies
      .map((frequency) =>
        [frequency.type, frequency.value].filter((part) => part && part.length > 0).join(' '),
      )
      .filter((badge) => badge.length > 0),
    atis: detail.frequencies.find((frequency) =>
      (frequency.type ?? '').toUpperCase().includes('ATIS'),
    )?.value,
    rawMetar: undefined,
    decodedMetar: undefined,
    approachRule: undefined,
  };
}

/** 跑道两端坐标齐全时才生成几何 */
function toRunwayGeometry(runway: AirportRunwayData): MapRunwayGeometry | null {
  const { leLat, leLon, heLat, heLon } = runway;
  if (
    leLat === undefined ||
    leLon === undefined ||
    heLat === undefined ||
    heLon === undefined
  ) {
    return null;
  }
  if (!isValidCoordinate(leLat, leLon) || !isValidCoordinate(heLat, heLon)) return null;

  return {
    ident: runway.ident,
    leIdent: runway.leIdent,
    heIdent: runway.heIdent,
    start: { latitude: leLat, longitude: leLon },
    end: { latitude: heLat, longitude: heLon },
    lengthM: runway.lengthM,
    surface: runway.surface,
  };
}

function toParkingSpots(detail: AirportDetailData): MapParkingSpot[] {
  return detail.parkings
    .filter(
      (parking) =>
        parking.latitude !== undefined &&
        parking.longitude !== undefined &&
        isValidCoordinate(parking.latitude, parking.longitude),
    )
    .map((parking) => ({
      name: parking.name,
      position: { latitude: parking.latitude!, longitude: parking.longitude! },
      headingDeg: parking.headingDeg,
    }));
}

