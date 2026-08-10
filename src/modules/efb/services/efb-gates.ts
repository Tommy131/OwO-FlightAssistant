import type { FlightData } from '../../common/models/common-models';

/**
 * EFB 关键门限计算
 *
 * 把「这个阶段该盯什么」写成数据：每个飞行阶段一组门限，逐条给出
 * 当前值、判据与状态。飞行中没空翻十几个仪表盘，一屏之内看清楚
 * 「现在哪条超了」才有用。
 *
 * ── 门限取值依据 ──
 * 稳定进近判据取业界通行的 1000 ft AAL 标准（IATA/FSF 的稳定进近准则）：
 * 速度在 Vref-5 ~ Vref+20、下降率不超过 1000 fpm、坡度 ±15° 以内、
 * 构型与推力已稳定。其余阶段取常见运行限制（10000 ft 以下 250 kt 等）。
 * 这些是**通用参考值**，不替代具体机型的 AFM/FCOM。
 *
 * 纯计算：不 import React / IO / 任何框架，可被直接单测。
 */

/** 门限状态 */
export type GateStatus = 'ok' | 'watch' | 'exceeded' | 'unknown';

/** 一条门限 */
export interface FlightGate {
  /** 稳定的标识，用于 i18n 与 React key */
  id: string;
  /** 当前实测值的显示文本 */
  value: string;
  /** 判据的显示文本 */
  limit: string;
  status: GateStatus;
}

/** 归一化后的飞行阶段 */
export type EfbPhase =
  | 'unknown'
  | 'parked'
  | 'taxi'
  | 'takeoff'
  | 'climb'
  | 'cruise'
  | 'descent'
  | 'approach'
  | 'landing';

const KNOWN_PHASES: readonly EfbPhase[] = [
  'unknown',
  'parked',
  'taxi',
  'takeoff',
  'climb',
  'cruise',
  'descent',
  'approach',
  'landing',
];

/** 把后端的飞行阶段字符串归一化 */
export function normalizePhase(raw: string | undefined): EfbPhase {
  const value = (raw ?? '').trim().toLowerCase();
  const matched = KNOWN_PHASES.find((phase) => phase === value);
  if (matched) return matched;
  // 后端历史上用过 ground / on_ground 表示停机
  if (value === 'ground' || value === 'on_ground') return 'parked';
  return 'unknown';
}

/** 10000 ft 以下的速度限制（kt） */
export const SPEED_LIMIT_BELOW_10000_KT = 250;
/** 稳定进近的下降率上限（fpm，取绝对值） */
export const STABILIZED_SINK_RATE_FPM = 1000;
/** 稳定进近的坡度上限（deg） */
export const STABILIZED_BANK_DEG = 15;
/** 滑行速度上限（kt） */
export const TAXI_SPEED_LIMIT_KT = 30;
/** 接地过载的舒适上限（g），超过按重着陆看 */
export const FIRM_TOUCHDOWN_G = 1.8;

/**
 * 按当前阶段算出该盯的门限。
 *
 * 数据缺失时返回 `unknown` 而不是默默按 0 算 —— 把「没有数据」显示成
 * 「一切正常」，是这类面板最危险的失败方式。
 */
export function buildGates(phase: EfbPhase, data: FlightData): FlightGate[] {
  switch (phase) {
    case 'taxi':
    case 'parked':
      return [
        gateMaxAbs('taxi_speed', data.groundSpeed, TAXI_SPEED_LIMIT_KT, 'kt', 0),
        gateBool('parking_brake', data.parkingBrake, phase === 'parked'),
        gateText('flaps', data.flapsLabel, data.flapsAngle, 'deg'),
      ];
    case 'takeoff':
      return [
        gateBool('gear_down', data.gearDown, true),
        gateText('flaps', data.flapsLabel, data.flapsAngle, 'deg'),
        gateMaxAbs('elevator_trim', data.elevatorTrim, 0.5, '', 2),
        gateBool('parking_brake', data.parkingBrake, false),
      ];
    case 'climb':
      return [
        speedBelow10000Gate(data),
        gateMinSigned('climb_rate', data.verticalSpeed, 300, 'fpm', 0),
        gateBool('gear_down', data.gearDown, false),
      ];
    case 'cruise':
      return [
        gateText('mach', formatNumber(data.machNumber, 3), undefined, ''),
        gateMaxAbs('vertical_deviation', data.verticalSpeed, 500, 'fpm', 0),
        gateBool('autopilot', data.autopilotEngaged, true),
      ];
    case 'descent':
      return [
        speedBelow10000Gate(data),
        gateMaxAbs('descent_rate', data.verticalSpeed, 3000, 'fpm', 0),
        gateBool('speed_brake', data.speedBrake, undefined),
      ];
    case 'approach':
      return [
        gateMaxAbs('sink_rate', data.verticalSpeed, STABILIZED_SINK_RATE_FPM, 'fpm', 0),
        gateMaxAbs('bank_angle', data.bank, STABILIZED_BANK_DEG, 'deg', 1),
        gateBool('gear_down', data.gearDown, true),
        gateBool('flaps_deployed', data.flapsDeployed, true),
      ];
    case 'landing':
      return [
        gateMaxAbs('touchdown_g', data.touchdownGearG, FIRM_TOUCHDOWN_G, 'g', 2),
        gateBool('spoilers', data.spoilersDeployed, true),
        gateBool('reverse_ready', data.speedBrake, undefined),
      ];
    default:
      return [];
  }
}

/** 10000 ft 以下限速门限；在 10000 ft 以上则不适用 */
function speedBelow10000Gate(data: FlightData): FlightGate {
  const altitude = data.altitude;
  const speed = data.airspeed;
  if (altitude === undefined || speed === undefined) {
    return { id: 'speed_below_10000', value: '—', limit: `≤ ${SPEED_LIMIT_BELOW_10000_KT} kt`, status: 'unknown' };
  }
  if (altitude >= 10000) {
    return {
      id: 'speed_below_10000',
      value: `${formatNumber(speed, 0)} kt`,
      limit: 'N/A > FL100',
      status: 'ok',
    };
  }
  return gateMaxAbs('speed_below_10000', speed, SPEED_LIMIT_BELOW_10000_KT, 'kt', 0);
}

/**
 * 绝对值不超过 limit 的门限。
 *
 * 逼近上限（≥90%）时给 watch 而不是等到超了才报 —— 门限的意义在于
 * 提前收手，超了才亮红灯就已经晚了。
 */
function gateMaxAbs(
  id: string,
  value: number | undefined,
  limit: number,
  unit: string,
  digits: number,
): FlightGate {
  const suffix = unit ? ` ${unit}` : '';
  if (value === undefined || !Number.isFinite(value)) {
    return { id, value: '—', limit: `≤ ${formatNumber(limit, digits)}${suffix}`, status: 'unknown' };
  }
  const magnitude = Math.abs(value);
  let status: GateStatus = 'ok';
  if (magnitude > limit) status = 'exceeded';
  else if (magnitude >= limit * 0.9) status = 'watch';
  return {
    id,
    value: `${formatNumber(value, digits)}${suffix}`,
    limit: `≤ ${formatNumber(limit, digits)}${suffix}`,
    status,
  };
}

/** 带符号的下限门限（例如爬升率至少要有多少） */
function gateMinSigned(
  id: string,
  value: number | undefined,
  minimum: number,
  unit: string,
  digits: number,
): FlightGate {
  const suffix = unit ? ` ${unit}` : '';
  if (value === undefined || !Number.isFinite(value)) {
    return { id, value: '—', limit: `≥ ${formatNumber(minimum, digits)}${suffix}`, status: 'unknown' };
  }
  let status: GateStatus = 'ok';
  if (value < minimum) status = 'exceeded';
  else if (value < minimum * 1.1) status = 'watch';
  return {
    id,
    value: `${formatNumber(value, digits)}${suffix}`,
    limit: `≥ ${formatNumber(minimum, digits)}${suffix}`,
    status,
  };
}

/** 布尔门限；expected 为 undefined 时只展示不判定 */
function gateBool(id: string, value: boolean | undefined, expected: boolean | undefined): FlightGate {
  if (value === undefined) {
    return { id, value: '—', limit: expected === undefined ? '—' : boolText(expected), status: 'unknown' };
  }
  if (expected === undefined) {
    return { id, value: boolText(value), limit: '—', status: 'ok' };
  }
  return {
    id,
    value: boolText(value),
    limit: boolText(expected),
    status: value === expected ? 'ok' : 'exceeded',
  };
}

/** 纯展示门限（不判定），文本优先、数值兜底 */
function gateText(
  id: string,
  text: string | undefined,
  fallbackNumber: number | undefined,
  unit: string,
): FlightGate {
  const trimmed = text?.trim();
  if (trimmed) return { id, value: trimmed, limit: '—', status: 'ok' };
  if (fallbackNumber !== undefined && Number.isFinite(fallbackNumber)) {
    return { id, value: `${formatNumber(fallbackNumber, 0)}${unit ? ` ${unit}` : ''}`, limit: '—', status: 'ok' };
  }
  return { id, value: '—', limit: '—', status: 'unknown' };
}

function boolText(value: boolean): string {
  return value ? 'ON' : 'OFF';
}

function formatNumber(value: number | undefined, digits: number): string {
  if (value === undefined || !Number.isFinite(value)) return '—';
  return value.toFixed(digits);
}

// ──────────────────────────────────────────────────────────────────────────
// 油量余度
// ──────────────────────────────────────────────────────────────────────────

/** 油量余度计算的输入 */
export interface FuelMarginInput {
  /** 剩余燃油（kg） */
  fuelQuantityKg?: number;
  /** 燃油流量（kg/h） */
  fuelFlowKgh?: number;
  /** 到目的地的剩余距离（NM） */
  distanceToDestinationNm?: number;
  /** 地速（kt） */
  groundSpeedKt?: number;
  /** 是否已设定备降场 */
  hasAlternate: boolean;
}

/** 油量余度结果 */
export interface FuelMargin {
  /** 按当前流量还能飞多久（小时）；流量为 0 时为 undefined */
  enduranceHours?: number;
  /** 到目的地预计还要多久（小时） */
  timeToDestinationHours?: number;
  /** 到目的地预计耗油（kg） */
  burnToDestinationKg?: number;
  /** 落地预计剩油（kg），可能为负 */
  fuelAtDestinationKg?: number;
  /** 落地剩油相对最低储备的余量（kg） */
  marginKg?: number;
  /** 最低储备（kg）：末端 45 分钟 + 备降段 */
  requiredReserveKg?: number;
  /** ok=充裕，watch=接近储备线，critical=已低于储备 */
  status: 'ok' | 'watch' | 'critical' | 'unknown';
}

/** 末端储备：45 分钟按当前流量折算（ICAO 对涡轮机的常见最低要求） */
export const FINAL_RESERVE_HOURS = 0.75;
/** 没有实测流量时的兜底流量（kg/h），量级取窄体机巡航 */
export const FALLBACK_FUEL_FLOW_KGH = 2400;
/** 备降段按 200 NM 估算 */
export const ALTERNATE_DISTANCE_NM = 200;

/**
 * 算出油量余度。
 *
 * 关键判断是「落地时还剩多少、够不够最低储备」，而不是「油箱里还有多少」——
 * 后者是个大数字，看着永远很安心。
 */
export function computeFuelMargin(input: FuelMarginInput): FuelMargin {
  const fuel = input.fuelQuantityKg;
  if (fuel === undefined || !Number.isFinite(fuel) || fuel < 0) {
    return { status: 'unknown' };
  }
  const flow =
    input.fuelFlowKgh !== undefined && Number.isFinite(input.fuelFlowKgh) && input.fuelFlowKgh > 0
      ? input.fuelFlowKgh
      : undefined;
  const effectiveFlow = flow ?? FALLBACK_FUEL_FLOW_KGH;

  const enduranceHours = flow !== undefined ? fuel / flow : undefined;
  const finalReserveKg = effectiveFlow * FINAL_RESERVE_HOURS;

  const distance = input.distanceToDestinationNm;
  const groundSpeed = input.groundSpeedKt;
  if (
    distance === undefined ||
    !Number.isFinite(distance) ||
    groundSpeed === undefined ||
    !Number.isFinite(groundSpeed) ||
    groundSpeed <= 0
  ) {
    // 没有航段信息时只能给续航，不能给余度 —— 硬编一个假距离更糟。
    return { enduranceHours, requiredReserveKg: finalReserveKg, status: 'unknown' };
  }

  const timeToDestinationHours = distance / groundSpeed;
  const burnToDestinationKg = timeToDestinationHours * effectiveFlow;
  const alternateBurnKg = input.hasAlternate
    ? (ALTERNATE_DISTANCE_NM / groundSpeed) * effectiveFlow
    : 0;
  const requiredReserveKg = finalReserveKg + alternateBurnKg;
  const fuelAtDestinationKg = fuel - burnToDestinationKg;
  const marginKg = fuelAtDestinationKg - requiredReserveKg;

  let status: FuelMargin['status'] = 'ok';
  if (marginKg < 0) status = 'critical';
  else if (marginKg < requiredReserveKg * 0.25) status = 'watch';

  return {
    enduranceHours,
    timeToDestinationHours,
    burnToDestinationKg,
    fuelAtDestinationKg,
    marginKg,
    requiredReserveKg,
    status,
  };
}
