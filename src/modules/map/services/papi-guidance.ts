import type {
  MapAircraftState,
  MapCoordinate,
  MapRunwayGeometry,
  MapRunwayNavaid,
  MapSelectedAirportDetail,
} from '../models/map-models';

/**
 * PAPI 目视进近坡度指示
 *
 * 真机跑道旁那四盏灯：每盏各自对准一个略有差别的仰角，
 * 飞机**高于**某盏灯的设定角就看到白光，**低于**就看到红光。
 * 于是从左到右的红白组合直接告诉你偏高还是偏低：
 *
 *   白白白白  过高
 *   白白白红  略高
 *   白白红红  正好在坡度上
 *   白红红红  略低
 *   红红红红  过低（危险）
 *
 * 四盏灯的设定角按 ICAO Annex 14，相对标称下滑角 θ 分别是
 * θ−0.5° / θ−1/6° / θ+1/6° / θ+0.5°，
 * 「正好」的窗口就是中间那两盏之间，约 ±0.17°（3° 坡度下 ≈ ±0.34% 梯度）。
 */

/** 单盏灯的颜色 */
export type PapiLight = 'white' | 'red';

/** 偏差判定 */
export type PapiVerdict = 'high' | 'slightlyHigh' | 'onSlope' | 'slightlyLow' | 'low';

export interface PapiGuidance {
  /** 四盏灯，从左到右（设定角由低到高） */
  readonly lights: readonly PapiLight[];
  readonly verdict: PapiVerdict;
  /** 当前对入口的实际仰角（度） */
  readonly currentAngle: number;
  /** 该跑道的标称下滑角（度） */
  readonly targetAngle: number;
  /** 瞄准的跑道端，如 `18L` */
  readonly runway: string;
  /** 距入口的水平距离（海里） */
  readonly distanceNm: number;
  /** 相对入口的高度（英尺） */
  readonly heightFt: number;
}

/** 灯位相对标称坡度的偏移（度），顺序即显示顺序 */
const PAPI_OFFSETS = [-0.5, -1 / 6, 1 / 6, 0.5] as const;

/** 没有 ILS 下滑道时的默认标称坡度 */
const DEFAULT_GLIDE_ANGLE = 3;

/** 超过这个距离不显示：PAPI 实际可视距离大约 5 海里，放宽一点便于提前建立 */
const MAX_DISTANCE_NM = 10;

/** 高于入口这么多就不是在做进近了 */
const MAX_HEIGHT_FT = 3000;

/** 与跑道方向的最大夹角（度）：偏太多说明不是冲着这条跑道来的 */
const MAX_ALIGNMENT_DEG = 45;

const EARTH_RADIUS_NM = 3440.065;
const FT_PER_NM = 6076.12;

/**
 * 算出当前应当看到的 PAPI 指示
 *
 * @returns 不在任何一条跑道的进近条件下时返回 null（此时不该显示指示器）
 */
export function computePapiGuidance(
  aircraft: MapAircraftState | null | undefined,
  detail: MapSelectedAirportDetail | null | undefined,
): PapiGuidance | null {
  if (!aircraft || !detail) return null;
  // 落地滑行时没有进近可言
  if (aircraft.onGround) return null;

  let best: PapiGuidance | null = null;

  for (const runway of detail.runwayGeometries) {
    for (const end of runwayEnds(runway)) {
      const navaid = detail.runwayNavaids?.[end.ident.toUpperCase()];
      const candidate = evaluateEnd(aircraft, end, navaid);
      if (!candidate) continue;
      // 多条跑道都满足时取最近的那条
      if (!best || candidate.distanceNm < best.distanceNm) best = candidate;
    }
  }

  return best;
}

interface RunwayEnd {
  readonly ident: string;
  /** 入口坐标 */
  readonly threshold: MapCoordinate;
  /** 跑道另一端，用来定进近方向 */
  readonly far: MapCoordinate;
}

function runwayEnds(runway: MapRunwayGeometry): RunwayEnd[] {
  const ends: RunwayEnd[] = [];
  if (runway.leIdent) {
    ends.push({ ident: runway.leIdent, threshold: runway.start, far: runway.end });
  }
  if (runway.heIdent) {
    ends.push({ ident: runway.heIdent, threshold: runway.end, far: runway.start });
  }
  return ends;
}

function evaluateEnd(
  aircraft: MapAircraftState,
  end: RunwayEnd,
  navaid: MapRunwayNavaid | undefined,
): PapiGuidance | null {
  const distanceNm = distanceInNm(aircraft.position, end.threshold);
  if (!Number.isFinite(distanceNm) || distanceNm > MAX_DISTANCE_NM || distanceNm < 0.05) {
    return null;
  }

  const heightFt = heightAboveThreshold(aircraft, navaid);
  if (heightFt === null || heightFt <= 0 || heightFt > MAX_HEIGHT_FT) return null;

  // 必须大致在进近方向上：从入口指向飞机的方位，应当与「跑道反方向」接近
  const runwayCourse = bearingDeg(end.threshold, end.far);
  const toAircraft = bearingDeg(end.threshold, aircraft.position);
  if (angleDifference(toAircraft, (runwayCourse + 180) % 360) > MAX_ALIGNMENT_DEG) {
    return null;
  }

  const currentAngle = (Math.atan2(heightFt, distanceNm * FT_PER_NM) * 180) / Math.PI;
  const targetAngle = navaid?.glideslopeAngle ?? DEFAULT_GLIDE_ANGLE;

  const lights = PAPI_OFFSETS.map<PapiLight>((offset) =>
    currentAngle > targetAngle + offset ? 'white' : 'red',
  );
  const whites = lights.filter((light) => light === 'white').length;

  return {
    lights,
    verdict: verdictFromWhites(whites),
    currentAngle,
    targetAngle,
    runway: end.ident,
    distanceNm,
    heightFt,
  };
}

function verdictFromWhites(whites: number): PapiVerdict {
  switch (whites) {
    case 4:
      return 'high';
    case 3:
      return 'slightlyHigh';
    case 2:
      return 'onSlope';
    case 1:
      return 'slightlyLow';
    default:
      return 'low';
  }
}

/**
 * 飞机相对跑道入口的高度
 *
 * 优先用无线电高度（离地高，跑道附近就是相对入口的高）；
 * 拿不到时退回气压高度减台站标高。两个都没有就没法判断。
 */
function heightAboveThreshold(
  aircraft: MapAircraftState,
  navaid: MapRunwayNavaid | undefined,
): number | null {
  if (aircraft.radioAltitude !== undefined && Number.isFinite(aircraft.radioAltitude)) {
    return aircraft.radioAltitude;
  }
  if (
    aircraft.altitude !== undefined &&
    Number.isFinite(aircraft.altitude) &&
    navaid?.elevationFt !== undefined
  ) {
    return aircraft.altitude - navaid.elevationFt;
  }
  return null;
}

function distanceInNm(from: MapCoordinate, to: MapCoordinate): number {
  const lat1 = (from.latitude * Math.PI) / 180;
  const lat2 = (to.latitude * Math.PI) / 180;
  const deltaLat = lat2 - lat1;
  const deltaLon = ((to.longitude - from.longitude) * Math.PI) / 180;
  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLon / 2) ** 2;
  return 2 * EARTH_RADIUS_NM * Math.asin(Math.min(1, Math.sqrt(a)));
}

function bearingDeg(from: MapCoordinate, to: MapCoordinate): number {
  const lat1 = (from.latitude * Math.PI) / 180;
  const lat2 = (to.latitude * Math.PI) / 180;
  const deltaLon = ((to.longitude - from.longitude) * Math.PI) / 180;
  const y = Math.sin(deltaLon) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(deltaLon);
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

/** 两个方位角之间的夹角（0–180） */
function angleDifference(a: number, b: number): number {
  const diff = Math.abs(a - b) % 360;
  return diff > 180 ? 360 - diff : diff;
}
