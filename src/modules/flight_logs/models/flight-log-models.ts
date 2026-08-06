import { toBool, toDouble, toInt, toJsonMap, toStringOrUndefined, toText, type JsonMap } from '../../../core/utils/parse-utils';

/**
 * 飞行日志（黑匣子）数据模型
 *
 * 对应 Flutter 版 `modules/flight_logs/models/flight_log_models.dart`（693 行）。
 * JSON 键名（'lat' / 'alt' / 'g_src' …）与桌面版逐一保持一致，
 * 因此两端导出的 .json 文件可以互相导入。
 */

// ──────────────────────────────────────────────────────────────────────────
// 枚举
// ──────────────────────────────────────────────────────────────────────────

export type FlightLogAlertLevel = 'caution' | 'warning' | 'danger';

/** 落地 G 值来源：真实起落架传感器 vs 机身 G 回退估算 */
export type LandingGSource = 'gear' | 'body' | 'fallback';

export function landingGSourceFromRaw(raw: string | undefined): LandingGSource {
  const value = raw?.trim().toLowerCase();
  if (value === 'gear') return 'gear';
  if (value === 'body') return 'body';
  return 'fallback';
}

/** 落地评级 */
export type LandingRating = 'butter' | 'good' | 'firm' | 'hard' | 'crash';

/** 各评级的 G 值上限（含），超过最后一档即为 crash */
export const LANDING_RATING_THRESHOLDS: { rating: LandingRating; maxG: number }[] = [
  { rating: 'butter', maxG: 1.2 },
  { rating: 'good', maxG: 1.5 },
  { rating: 'firm', maxG: 1.9 },
  { rating: 'hard', maxG: 2.5 },
];

export function resolveLandingRating(gForce: number): LandingRating {
  for (const { rating, maxG } of LANDING_RATING_THRESHOLDS) {
    if (gForce <= maxG) return rating;
  }
  return 'crash';
}

// ──────────────────────────────────────────────────────────────────────────
// 告警
// ──────────────────────────────────────────────────────────────────────────

export interface FlightLogAlert {
  id: string;
  level: FlightLogAlertLevel;
  message: string;
}

function alertLevelFromRaw(raw: unknown): FlightLogAlertLevel {
  const value = toText(raw).trim().toLowerCase();
  if (value === 'danger') return 'danger';
  if (value === 'warning') return 'warning';
  return 'caution';
}

// ──────────────────────────────────────────────────────────────────────────
// 采样点（60+ 字段）
// ──────────────────────────────────────────────────────────────────────────

export interface FlightLogPoint {
  latitude: number;
  longitude: number;
  altitude: number;
  airspeed: number;
  groundSpeed: number;
  verticalSpeed: number;
  heading: number;
  pitch: number;
  roll: number;
  angleOfAttack?: number;
  gForce: number;
  gForceSource: LandingGSource;
  fuelQuantity: number;
  fuelFlow?: number;
  timestamp: Date;
  autopilotEngaged?: boolean;
  autothrottleEngaged?: boolean;
  flightPhase?: string;
  autopilotHeadingTarget?: number;
  autopilotLateralMode?: string;
  autopilotVerticalMode?: string;
  gearDown?: boolean;
  touchdownGearG?: number;
  noseGearG?: number;
  leftGearG?: number;
  rightGearG?: number;
  flapsPosition?: number;
  flapsLabel?: string;
  windSpeed?: number;
  windDirection?: number;
  windGust?: number;
  gustDelta?: number;
  gustFactorRate?: number;
  crosswindComponent?: number;
  radioAltitude?: number;
  outsideAirTemperature?: number;
  baroPressure?: number;
  masterWarning?: boolean;
  masterCaution?: boolean;
  engine1Running?: boolean;
  engine2Running?: boolean;
  engine1N1?: number;
  engine2N1?: number;
  engine1N2?: number;
  engine2N2?: number;
  engine1Egt?: number;
  engine2Egt?: number;
  transponderCode?: string;
  landingLights?: boolean;
  beacon?: boolean;
  strobes?: boolean;
  autoBrakeLevel?: number;
  speedBrakePosition?: number;
  aileronInput?: number;
  elevatorInput?: number;
  rudderInput?: number;
  aileronTrim?: number;
  elevatorTrim?: number;
  rudderTrim?: number;
  onGround?: boolean;
  anomalyAlerts: FlightLogAlert[];
}

export function flightLogPointToJson(point: FlightLogPoint): JsonMap {
  return {
    lat: point.latitude,
    lon: point.longitude,
    alt: point.altitude,
    spd: point.airspeed,
    gs: point.groundSpeed,
    vs: point.verticalSpeed,
    hdg: point.heading,
    pit: point.pitch,
    rol: point.roll,
    aoa: point.angleOfAttack ?? null,
    g: point.gForce,
    g_src: point.gForceSource,
    fuel: point.fuelQuantity,
    ff: point.fuelFlow ?? null,
    ts: point.timestamp.toISOString(),
    ap: point.autopilotEngaged ?? null,
    at: point.autothrottleEngaged ?? null,
    phase: point.flightPhase ?? null,
    ap_hdg: point.autopilotHeadingTarget ?? null,
    ap_lat: point.autopilotLateralMode ?? null,
    ap_ver: point.autopilotVerticalMode ?? null,
    gear: point.gearDown ?? null,
    tdg: point.touchdownGearG ?? null,
    ngg: point.noseGearG ?? null,
    lgg: point.leftGearG ?? null,
    rgg: point.rightGearG ?? null,
    flaps: point.flapsPosition ?? null,
    flap_lbl: point.flapsLabel ?? null,
    ws: point.windSpeed ?? null,
    wd: point.windDirection ?? null,
    wg: point.windGust ?? null,
    gust: point.gustDelta ?? null,
    gust_rate: point.gustFactorRate ?? null,
    xw: point.crosswindComponent ?? null,
    ra: point.radioAltitude ?? null,
    oat: point.outsideAirTemperature ?? null,
    baro: point.baroPressure ?? null,
    mw: point.masterWarning ?? null,
    mc: point.masterCaution ?? null,
    e1r: point.engine1Running ?? null,
    e2r: point.engine2Running ?? null,
    e1n1: point.engine1N1 ?? null,
    e2n1: point.engine2N1 ?? null,
    e1n2: point.engine1N2 ?? null,
    e2n2: point.engine2N2 ?? null,
    e1egt: point.engine1Egt ?? null,
    e2egt: point.engine2Egt ?? null,
    xpdr: point.transponderCode ?? null,
    ll: point.landingLights ?? null,
    beac: point.beacon ?? null,
    strob: point.strobes ?? null,
    grnd: point.onGround ?? null,
    ab: point.autoBrakeLevel ?? null,
    sb: point.speedBrakePosition ?? null,
    ail: point.aileronInput ?? null,
    ele: point.elevatorInput ?? null,
    rud: point.rudderInput ?? null,
    atr: point.aileronTrim ?? null,
    etr: point.elevatorTrim ?? null,
    rtr: point.rudderTrim ?? null,
    alerts: point.anomalyAlerts.map((alert) => ({
      id: alert.id,
      level: alert.level,
      message: alert.message,
    })),
  };
}

export function flightLogPointFromJson(json: JsonMap): FlightLogPoint {
  const airspeed = toDouble(json.spd) ?? 0;
  return {
    latitude: toDouble(json.lat) ?? 0,
    longitude: toDouble(json.lon) ?? 0,
    altitude: toDouble(json.alt) ?? 0,
    airspeed,
    // 旧版日志没有单独的 gs 字段，回退用 spd（与桌面版一致）
    groundSpeed: toDouble(json.gs) ?? airspeed,
    verticalSpeed: toDouble(json.vs) ?? 0,
    heading: toDouble(json.hdg) ?? 0,
    pitch: toDouble(json.pit) ?? 0,
    roll: toDouble(json.rol) ?? 0,
    angleOfAttack: toDouble(json.aoa),
    gForce: toDouble(json.g) ?? 1,
    gForceSource: landingGSourceFromRaw(
      typeof json.g_src === 'string' ? json.g_src : undefined,
    ),
    fuelQuantity: toDouble(json.fuel) ?? 0,
    fuelFlow: toDouble(json.ff),
    timestamp: json.ts ? new Date(toText(json.ts)) : new Date(),
    autopilotEngaged: toBool(json.ap),
    autothrottleEngaged: toBool(json.at),
    flightPhase: toStringOrUndefined(json.phase),
    autopilotHeadingTarget: toDouble(json.ap_hdg),
    autopilotLateralMode: toStringOrUndefined(json.ap_lat),
    autopilotVerticalMode: toStringOrUndefined(json.ap_ver),
    gearDown: toBool(json.gear),
    touchdownGearG: toDouble(json.tdg),
    noseGearG: toDouble(json.ngg),
    leftGearG: toDouble(json.lgg),
    rightGearG: toDouble(json.rgg),
    flapsPosition: toInt(json.flaps),
    flapsLabel: toStringOrUndefined(json.flap_lbl),
    windSpeed: toDouble(json.ws),
    windDirection: toDouble(json.wd),
    windGust: toDouble(json.wg),
    gustDelta: toDouble(json.gust),
    gustFactorRate: toDouble(json.gust_rate),
    crosswindComponent: toDouble(json.xw),
    radioAltitude: toDouble(json.ra),
    outsideAirTemperature: toDouble(json.oat),
    baroPressure: toDouble(json.baro),
    masterWarning: toBool(json.mw),
    masterCaution: toBool(json.mc),
    engine1Running: toBool(json.e1r),
    engine2Running: toBool(json.e2r),
    engine1N1: toDouble(json.e1n1),
    engine2N1: toDouble(json.e2n1),
    engine1N2: toDouble(json.e1n2),
    engine2N2: toDouble(json.e2n2),
    engine1Egt: toDouble(json.e1egt),
    engine2Egt: toDouble(json.e2egt),
    transponderCode: toStringOrUndefined(json.xpdr),
    landingLights: toBool(json.ll),
    beacon: toBool(json.beac),
    strobes: toBool(json.strob),
    autoBrakeLevel: toInt(json.ab),
    speedBrakePosition: toDouble(json.sb),
    aileronInput: toDouble(json.ail),
    elevatorInput: toDouble(json.ele),
    rudderInput: toDouble(json.rud),
    aileronTrim: toDouble(json.atr),
    elevatorTrim: toDouble(json.etr),
    rudderTrim: toDouble(json.rtr),
    onGround: toBool(json.grnd),
    anomalyAlerts: parseAlerts(json.alerts),
  };
}

function parseAlerts(value: unknown): FlightLogAlert[] {
  if (!Array.isArray(value)) return [];
  const alerts: FlightLogAlert[] = [];
  for (const item of value) {
    const map = toJsonMap(item);
    if (!map) continue;
    alerts.push({
      id: toText(map.id),
      level: alertLevelFromRaw(map.level),
      message: toText(map.message),
    });
  }
  return alerts;
}

// ──────────────────────────────────────────────────────────────────────────
// 起飞 / 落地数据
// ──────────────────────────────────────────────────────────────────────────

export interface TakeoffData {
  latitude: number;
  longitude: number;
  airspeed: number;
  groundSpeed: number;
  verticalSpeed: number;
  pitch: number;
  heading: number;
  timestamp: Date;
  remainingRunwayFt?: number;
  runway?: string;
  takeoffStabilityScore?: number;
  rotationSpeedKt?: number;
  rotationToLiftoffSec?: number;
  crosswindAtLiftoffKt?: number;
  pitchAt35FtDeg?: number;
}

export interface LandingData {
  latitude: number;
  longitude: number;
  gForce: number;
  gForceSource: LandingGSource;
  verticalSpeed: number;
  airspeed: number;
  groundSpeed: number;
  pitch: number;
  roll: number;
  rating: LandingRating;
  timestamp: Date;
  touchdownSequence: FlightLogPoint[];
  touchdownGForces: number[];
  remainingRunwayFt?: number;
  runway?: string;
  approachStabilityScore?: number;
  flareHeightFt?: number;
  sinkRateAt50FtFpm?: number;
  crosswindAtTouchdownKt?: number;
  bounceCount?: number;
}

// ──────────────────────────────────────────────────────────────────────────
// 飞行日志
// ──────────────────────────────────────────────────────────────────────────

export interface FlightLog {
  id: string;
  aircraftTitle: string;
  aircraftType?: string;
  simulatorLabel?: string;
  flightNumber?: string;
  departureAirport: string;
  arrivalAirport?: string;
  startTime: Date;
  endTime?: Date;
  points: FlightLogPoint[];
  maxG: number;
  minG: number;
  maxAltitude: number;
  maxAirspeed: number;
  maxGroundSpeed: number;
  totalFuelUsed?: number;
  wasOnGroundAtStart: boolean;
  wasOnGroundAtEnd: boolean;
  takeoffData?: TakeoffData;
  landingData?: LandingData;
}

/** 记录总时长（毫秒），负值归零 */
export function flightLogDurationMs(log: FlightLog): number {
  const end = log.endTime ?? new Date();
  const value = end.getTime() - log.startTime.getTime();
  return value < 0 ? 0 : value;
}

/**
 * 空中时长（毫秒）
 * 从「离地」到「接地」之间，逐点扫描 onGround 翻转（与桌面版逻辑一致）
 */
export function flightLogAirborneDurationMs(log: FlightLog): number {
  let takeoffTime: Date | undefined = log.takeoffData?.timestamp;
  let touchdownTime: Date | undefined = log.landingData?.timestamp;
  let previousOnGround = log.wasOnGroundAtStart;

  for (const point of log.points) {
    const currentOnGround = point.onGround ?? previousOnGround;
    if (!takeoffTime && previousOnGround && !currentOnGround) takeoffTime = point.timestamp;
    if (!takeoffTime && !currentOnGround) takeoffTime = point.timestamp;
    if (takeoffTime && !touchdownTime && !previousOnGround && currentOnGround) {
      touchdownTime = point.timestamp;
      break;
    }
    previousOnGround = currentOnGround;
  }

  if (!takeoffTime) return 0;
  const endReference =
    touchdownTime ??
    log.endTime ??
    (log.points.length > 0 ? log.points[log.points.length - 1].timestamp : takeoffTime);
  const value = endReference.getTime() - takeoffTime.getTime();
  return value < 0 ? 0 : value;
}

export function flightLogLastPoint(log: FlightLog): FlightLogPoint | undefined {
  return log.points.length === 0 ? undefined : log.points[log.points.length - 1];
}

/** 是否算作一次完整飞行：有到达机场且最终在地面 */
export function flightLogIsCompleted(log: FlightLog): boolean {
  const finalPoint = flightLogLastPoint(log);
  if (!finalPoint) return false;
  const hasArrival = (log.arrivalAirport ?? '').trim().length > 0;
  const endedOnGround = finalPoint.onGround ?? log.wasOnGroundAtEnd;
  return hasArrival && endedOnGround;
}

export function flightLogToJson(log: FlightLog): JsonMap {
  return {
    id: log.id,
    aircraft: log.aircraftTitle,
    aircraft_type: log.aircraftType ?? null,
    simulator: log.simulatorLabel ?? null,
    flight_number: log.flightNumber ?? null,
    departure: log.departureAirport,
    arrival: log.arrivalAirport ?? null,
    start: log.startTime.toISOString(),
    end: log.endTime?.toISOString() ?? null,
    max_g: log.maxG,
    min_g: log.minG,
    max_alt: log.maxAltitude,
    max_spd: log.maxAirspeed,
    max_gs: log.maxGroundSpeed,
    fuel_used: log.totalFuelUsed ?? null,
    ground_start: log.wasOnGroundAtStart,
    ground_end: log.wasOnGroundAtEnd,
    takeoff: log.takeoffData ? takeoffToJson(log.takeoffData) : null,
    landing: log.landingData ? landingToJson(log.landingData) : null,
    points: log.points.map(flightLogPointToJson),
  };
}

export function flightLogFromJson(json: JsonMap): FlightLog {
  const points = Array.isArray(json.points)
    ? json.points
        .map((item) => toJsonMap(item))
        .filter((item): item is JsonMap => item !== null)
        .map(flightLogPointFromJson)
    : [];

  return {
    id: toText(json.id) || crypto.randomUUID(),
    aircraftTitle: toText(json.aircraft) || 'Unknown',
    aircraftType: toStringOrUndefined(json.aircraft_type),
    simulatorLabel: toStringOrUndefined(json.simulator),
    flightNumber: toStringOrUndefined(json.flight_number),
    departureAirport: toText(json.departure) || '----',
    arrivalAirport: toStringOrUndefined(json.arrival),
    startTime: json.start ? new Date(toText(json.start)) : new Date(),
    endTime: json.end ? new Date(toText(json.end)) : undefined,
    points,
    maxG: toDouble(json.max_g) ?? 1,
    minG: toDouble(json.min_g) ?? 1,
    maxAltitude: toDouble(json.max_alt) ?? 0,
    maxAirspeed: toDouble(json.max_spd) ?? 0,
    maxGroundSpeed: toDouble(json.max_gs) ?? 0,
    totalFuelUsed: toDouble(json.fuel_used),
    wasOnGroundAtStart: toBool(json.ground_start) ?? false,
    wasOnGroundAtEnd: toBool(json.ground_end) ?? false,
    takeoffData: takeoffFromJson(toJsonMap(json.takeoff)),
    landingData: landingFromJson(toJsonMap(json.landing)),
  };
}

function takeoffToJson(data: TakeoffData): JsonMap {
  return {
    lat: data.latitude,
    lon: data.longitude,
    spd: data.airspeed,
    gs: data.groundSpeed,
    vs: data.verticalSpeed,
    pit: data.pitch,
    hdg: data.heading,
    ts: data.timestamp.toISOString(),
    rem_rwy: data.remainingRunwayFt ?? null,
    rwy: data.runway ?? null,
    stability: data.takeoffStabilityScore ?? null,
    vr: data.rotationSpeedKt ?? null,
    rot_sec: data.rotationToLiftoffSec ?? null,
    xw: data.crosswindAtLiftoffKt ?? null,
    pit35: data.pitchAt35FtDeg ?? null,
  };
}

function takeoffFromJson(json: JsonMap | null): TakeoffData | undefined {
  if (!json) return undefined;
  return {
    latitude: toDouble(json.lat) ?? 0,
    longitude: toDouble(json.lon) ?? 0,
    airspeed: toDouble(json.spd) ?? 0,
    groundSpeed: toDouble(json.gs) ?? 0,
    verticalSpeed: toDouble(json.vs) ?? 0,
    pitch: toDouble(json.pit) ?? 0,
    heading: toDouble(json.hdg) ?? 0,
    timestamp: json.ts ? new Date(toText(json.ts)) : new Date(),
    remainingRunwayFt: toDouble(json.rem_rwy),
    runway: toStringOrUndefined(json.rwy),
    takeoffStabilityScore: toDouble(json.stability),
    rotationSpeedKt: toDouble(json.vr),
    rotationToLiftoffSec: toInt(json.rot_sec),
    crosswindAtLiftoffKt: toDouble(json.xw),
    pitchAt35FtDeg: toDouble(json.pit35),
  };
}

function landingToJson(data: LandingData): JsonMap {
  return {
    lat: data.latitude,
    lon: data.longitude,
    g: data.gForce,
    g_src: data.gForceSource,
    vs: data.verticalSpeed,
    spd: data.airspeed,
    gs: data.groundSpeed,
    pit: data.pitch,
    rol: data.roll,
    rating: data.rating,
    ts: data.timestamp.toISOString(),
    seq: data.touchdownSequence.map(flightLogPointToJson),
    g_list: data.touchdownGForces,
    rem_rwy: data.remainingRunwayFt ?? null,
    rwy: data.runway ?? null,
    stability: data.approachStabilityScore ?? null,
    flare: data.flareHeightFt ?? null,
    sink50: data.sinkRateAt50FtFpm ?? null,
    xw: data.crosswindAtTouchdownKt ?? null,
    bounce: data.bounceCount ?? null,
  };
}

function landingFromJson(json: JsonMap | null): LandingData | undefined {
  if (!json) return undefined;
  const gForce = toDouble(json.g) ?? 1;
  const ratingRaw = toText(json.rating);
  const rating: LandingRating = (
    ['butter', 'good', 'firm', 'hard', 'crash'] as const
  ).includes(ratingRaw as LandingRating)
    ? (ratingRaw as LandingRating)
    : resolveLandingRating(gForce);

  return {
    latitude: toDouble(json.lat) ?? 0,
    longitude: toDouble(json.lon) ?? 0,
    gForce,
    gForceSource: landingGSourceFromRaw(
      typeof json.g_src === 'string' ? json.g_src : undefined,
    ),
    verticalSpeed: toDouble(json.vs) ?? 0,
    airspeed: toDouble(json.spd) ?? 0,
    groundSpeed: toDouble(json.gs) ?? 0,
    pitch: toDouble(json.pit) ?? 0,
    roll: toDouble(json.rol) ?? 0,
    rating,
    timestamp: json.ts ? new Date(toText(json.ts)) : new Date(),
    touchdownSequence: Array.isArray(json.seq)
      ? json.seq
          .map((item) => toJsonMap(item))
          .filter((item): item is JsonMap => item !== null)
          .map(flightLogPointFromJson)
      : [],
    touchdownGForces: Array.isArray(json.g_list)
      ? json.g_list.map((item) => toDouble(item) ?? 0)
      : [],
    remainingRunwayFt: toDouble(json.rem_rwy),
    runway: toStringOrUndefined(json.rwy),
    approachStabilityScore: toDouble(json.stability),
    flareHeightFt: toDouble(json.flare),
    sinkRateAt50FtFpm: toDouble(json.sink50),
    crosswindAtTouchdownKt: toDouble(json.xw),
    bounceCount: toInt(json.bounce),
  };
}

