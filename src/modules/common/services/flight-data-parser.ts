/**
 * 遥测数据解析（纯函数）
 *
 * 把中间件的数据集（96 个字段，键名与桌面版逐一对齐）翻译成 `FlightData`。
 * 原先和 WebSocket/轮询/健康监控挤在同一个适配器文件里，没法脱离那套 IO 单独调用。
 *
 * 这层最容易出的错是**字段拼错**或**单位没换算**：两者都不报错，
 * 只会让仪表读数悄悄不对。
 */

import {
  pickDouble,
  pickString,
  readAngleDegrees,
  toBool,
  toDouble,
  toInt,
  toJsonMap,
  toText,
  type JsonMap,
} from '../../../core/utils/parse-utils';
import {
  type AIAircraftState,
  type AirportInfo,
  type FlightAlert,
  type FlightData,
} from '../models/common-models';


/** 从中间件数据集构建 FlightData（96 字段，键名与桌面版逐一对齐） */
export function flightDataFromDataset(dataset: JsonMap): FlightData {
  const noseGearDown = toDouble(dataset.nose_gear_down);
  const leftGearDown = toDouble(dataset.left_gear_down);
  const rightGearDown = toDouble(dataset.right_gear_down);

  return {
    airspeed: toDouble(dataset.ias_kt ?? dataset.airspeed_kt),
    machNumber: toDouble(dataset.mach_number),
    trueAirspeed: toDouble(dataset.tas_kt ?? dataset.true_airspeed_kt),
    altitude: toDouble(dataset.altitude_ft),
    heading: toDouble(dataset.heading_deg),
    verticalSpeed: toDouble(dataset.vertical_speed_fpm ?? dataset.vs_fpm),
    gForce: toDouble(dataset.g_force_g ?? dataset.g_force),
    touchdownGearG: toDouble(dataset.touchdown_gear_g),
    /*
     * 窗口峰值与瞬时值并列，**不能**拿来覆盖瞬时值：
     * G 曲线画的是瞬时值，换成峰值保持会变成一段段平台；
     * 而落地评级要的恰恰是峰值（瞬时值几乎必然错过接地那一下）。
     */
    gForcePeak: toDouble(dataset.g_force_peak_g),
    touchdownGearGPeak: toDouble(dataset.touchdown_gear_g_peak),
    noseGearG: toDouble(dataset.nose_gear_g),
    leftGearG: toDouble(dataset.left_gear_g),
    rightGearG: toDouble(dataset.right_gear_g),
    pitch: readAngleDegrees(dataset, ['pitch_deg'], ['pitch']),
    bank: readAngleDegrees(dataset, ['bank_deg', 'roll_deg'], ['bank', 'roll']),
    angleOfAttack: readAngleDegrees(
      dataset,
      ['aoa_deg', 'angle_of_attack_deg', 'alpha_deg', 'angleofattack_deg'],
      ['aoa', 'angle_of_attack', 'alpha', 'angleofattack'],
    ),
    stallWarning: toBool(
      dataset.stall_warning ?? dataset.is_stalling ?? dataset.stall_warning_active,
    ),
    latitude: toDouble(dataset.latitude),
    longitude: toDouble(dataset.longitude),
    departureAirport: pickString(dataset, [
      'departure_airport',
      'departure_airport_icao',
      'origin_airport',
    ]),
    arrivalAirport: pickString(dataset, [
      'arrival_airport',
      'arrival_airport_icao',
      'destination_airport',
    ]),
    groundSpeed: toDouble(dataset.ground_speed_kt),
    com1Frequency: toDouble(dataset.com1_frequency_mhz),
    outsideAirTemperature: toDouble(dataset.outside_temp_c),
    totalAirTemperature: toDouble(dataset.total_temp_c),
    windSpeed: toDouble(dataset.wind_speed_kt),
    windDirection: toDouble(dataset.wind_direction_deg),
    windGust: toDouble(dataset.wind_gust_kt),
    gustDelta: toDouble(dataset.gust_delta_kt),
    gustFactorRate: toDouble(dataset.gust_factor_rate),
    crosswindComponent: toDouble(dataset.crosswind_component_kt),
    radioAltitude: toDouble(dataset.radio_altitude_ft),
    baroPressure: toDouble(dataset.baro_pressure_inhg),
    baroPressureUnit: asText(dataset.baro_pressure_unit),
    visibility: toDouble(dataset.visibility_m),
    numEngines: toInt(dataset.num_engines),
    fuelQuantity: toDouble(dataset.fuel_quantity_kg),
    fuelFlow: toDouble(dataset.fuel_flow_kg_h),
    engine1N1: toDouble(dataset.engine1_n1),
    engine2N1: toDouble(dataset.engine2_n1),
    engine1N2: toDouble(dataset.engine1_n2),
    engine2N2: toDouble(dataset.engine2_n2),
    engine1EGT: toDouble(dataset.engine1_egt_c),
    engine2EGT: toDouble(dataset.engine2_egt_c),
    aileronInput: toDouble(dataset.aileron_input),
    elevatorInput: toDouble(dataset.elevator_input),
    rudderInput: toDouble(dataset.rudder_input),
    aileronTrim: toDouble(dataset.aileron_trim),
    elevatorTrim: toDouble(dataset.elevator_trim),
    rudderTrim: toDouble(dataset.rudder_trim),
    masterWarning: toBool(dataset.master_warning),
    masterCaution: toBool(dataset.master_caution),
    fireWarningEngine1: toBool(dataset.fire_warning_engine1),
    fireWarningEngine2: toBool(dataset.fire_warning_engine2),
    fireWarningAPU: toBool(dataset.fire_warning_apu),
    beacon: toBool(dataset.beacon),
    strobes: toBool(dataset.strobes),
    navLights: toBool(dataset.nav_lights),
    logoLights: toBool(dataset.logo_lights),
    wingLights: toBool(dataset.wing_lights),
    landingLights: toBool(dataset.landing_lights),
    taxiLights: toBool(dataset.taxi_lights),
    runwayTurnoffLights: toBool(dataset.runway_turnoff_lights),
    wheelWellLights: toBool(dataset.wheel_well_lights),
    onGround: toBool(dataset.on_ground),
    parkingBrake: toBool(dataset.parking_brake),
    speedBrake: toBool(dataset.speed_brake_active),
    speedBrakeLabel: buildSpeedBrakeLabel(dataset),
    spoilersDeployed: toBool(dataset.spoilers_deployed),
    autoBrakeLabel: asText(dataset.auto_brake_label),
    flapsDeployed: toBool(dataset.flaps_deployed),
    flapsLabel: buildFlapsLabel(dataset),
    flapsAngle: toDouble(dataset.flaps_angle_deg),
    flapsDeployRatio: toDouble(dataset.flaps_deploy_ratio),
    gearDown:
      inferGearDownStateFromRatio(noseGearDown, leftGearDown, rightGearDown) ??
      toBool(dataset.gear_down),
    noseGearDown,
    leftGearDown,
    rightGearDown,
    apuRunning: toBool(dataset.apu_running),
    engine1Running: toBool(dataset.engine1_running),
    engine2Running: toBool(dataset.engine2_running),
    autopilotEngaged: toBool(dataset.autopilot_engaged),
    autothrottleEngaged: toBool(dataset.autothrottle_engaged),
    autopilotHeadingTarget: toDouble(
      dataset.autopilot_heading_target_deg ?? dataset.heading_target,
    ),
    autopilotLateralMode: pickString(dataset, ['autopilot_lateral_mode']),
    autopilotVerticalMode: pickString(dataset, ['autopilot_vertical_mode']),
    aircraftProfile: asText(dataset.aircraft_profile),
    aircraftId: asText(dataset.aircraft_id),
    aircraftManufacturer: asText(dataset.aircraft_manufacturer),
    aircraftFamily: asText(dataset.aircraft_family),
    aircraftModel: asText(dataset.aircraft_model),
    aircraftIcao: asText(dataset.aircraft_icao),
    aircraftDisplayName: asText(dataset.aircraft_display_name),
    // 注册码在两家模拟器里落在不同键上：X-Plane 走 tailnum，MSFS 走 ATC ID。
    aircraftRegistration: pickString(dataset, [
      'aircraft_atc_id',
      'aircraft_registration',
      'tail_number',
      'tailnum',
    ]),
    flightPhase: pickString(dataset, ['flight_phase']),
    flightAlertLevel: pickString(dataset, ['flight_alert_level']),
    flightAlerts: parseFlightAlerts(dataset.flight_alerts),
    aiAircraft: parseAIAircraft(dataset.ai_aircraft),
  };
}

export function parseFlightAlerts(value: unknown): FlightAlert[] {
  if (!Array.isArray(value)) return [];
  const alerts: FlightAlert[] = [];
  for (const item of value) {
    const map = toJsonMap(item);
    if (!map) continue;
    const id = pickString(map, ['id']) ?? '';
    const level = pickString(map, ['level']) ?? '';
    const message = pickString(map, ['message']) ?? '';
    if (id.length === 0 && message.length === 0) continue;
    alerts.push({ id, level, message });
  }
  return alerts;
}

export function parseAIAircraft(value: unknown): AIAircraftState[] {
  if (!Array.isArray(value)) return [];
  const result: AIAircraftState[] = [];
  for (const item of value) {
    const map = toJsonMap(item);
    if (!map) continue;
    const latitude = toDouble(map.latitude);
    const longitude = toDouble(map.longitude);
    if (latitude === undefined || longitude === undefined) continue;
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) continue;
    const id = asText(map.id);
    result.push({
      id: id && id.length > 0 ? id : `AI-${result.length + 1}`,
      type: asText(map.type),
      latitude,
      longitude,
      altitude: toDouble(map.altitude_ft),
      heading: toDouble(map.heading_deg),
      groundSpeed: toDouble(map.ground_speed_kt),
      onGround: toBool(map.on_ground),
    });
  }
  return result;
}

export function airportFromSuggestion(raw: JsonMap): AirportInfo {
  const icao = pickString(raw, ['icao', 'ICAO'])?.toUpperCase() ?? '';
  return {
    icaoCode: icao,
    iataCode: pickString(raw, ['iata', 'IATA']) ?? '',
    name: pickString(raw, ['name', 'Name']) ?? icao,
    nameChinese: '',
    latitude: pickDouble(raw, ['latitude', 'lat', 'Lat']) ?? 0,
    longitude: pickDouble(raw, ['longitude', 'lon', 'lng', 'Lng', 'Lon']) ?? 0,
  };
}

export function airportFromNearestAirport(raw: JsonMap): AirportInfo | null {
  const icao = asText(raw.icao)?.toUpperCase() ?? '';
  if (icao.length === 0) return null;
  const label = asText(raw.label);
  return {
    icaoCode: icao,
    iataCode: '',
    name: label && label.length > 0 ? label : icao,
    nameChinese: '',
    latitude: toDouble(raw.latitude) ?? 0,
    longitude: toDouble(raw.longitude) ?? 0,
  };
}

export function buildSpeedBrakeLabel(dataset: JsonMap): string | undefined {
  const ratio = toDouble(dataset.speed_brake_ratio);
  if (ratio === undefined) return undefined;
  return `${Math.round(ratio * 100)}%`;
}

export function buildFlapsLabel(dataset: JsonMap): string | undefined {
  const angle = toDouble(dataset.flaps_angle_deg);
  if (angle !== undefined) return `${Math.round(angle)}°`;
  const ratio = toDouble(dataset.flaps_deploy_ratio);
  if (ratio !== undefined) return `${Math.round(ratio * 100)}%`;
  return undefined;
}

/** 由三个起落架的放下比例推断整体状态（平均值 ≥ 0.5 视为放下） */
export function inferGearDownStateFromRatio(
  noseGearDown: number | undefined,
  leftGearDown: number | undefined,
  rightGearDown: number | undefined,
): boolean | undefined {
  const ratios: number[] = [];
  for (const raw of [noseGearDown, leftGearDown, rightGearDown]) {
    const normalized = normalizeGearRatio(raw);
    if (normalized !== undefined) ratios.push(normalized);
  }
  if (ratios.length === 0) return undefined;
  const average = ratios.reduce((a, b) => a + b, 0) / ratios.length;
  return average >= 0.5;
}

/** 起落架比例归一化：支持 0-1 与 0-100 两种量纲 */
export function normalizeGearRatio(value: number | undefined): number | undefined {
  if (value === undefined || !Number.isFinite(value)) return undefined;
  if (value >= 0 && value <= 1) return value;
  if (value > 1 && value <= 100) return value / 100;
  return undefined;
}

/**
 * 燃油计划总量（kg）
 * 航段 = 距离 × 2.5；备降固定按 200nm 计；备份 1500；滑行 200；额外 5%
 */
export function buildFuelPlanTotal(distanceNm: number, hasAlternate: boolean): number {
  const trip = distanceNm * 2.5;
  const alternate = hasAlternate ? 200 * 2.5 : 0;
  const reserve = 1500;
  const taxi = 200;
  const extra = trip * 0.05;
  return trip + alternate + reserve + taxi + extra;
}


/** 与 toStringOrUndefined 的区别：这里**不** trim，保留后端原样的空白 */
export function asText(value: unknown): string | undefined {
  const text = toText(value);
  return text.length > 0 ? text : undefined;
}
