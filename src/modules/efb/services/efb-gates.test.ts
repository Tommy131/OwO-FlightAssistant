import { describe, expect, it } from 'vitest';

import { emptyFlightData, type FlightData } from '../../common/models/common-models';
import {
  ALTERNATE_DISTANCE_NM,
  FINAL_RESERVE_HOURS,
  buildGates,
  computeFuelMargin,
  normalizePhase,
  type FlightGate,
} from './efb-gates';

function data(overrides: Partial<FlightData>): FlightData {
  return { ...emptyFlightData(), ...overrides };
}

function gateById(gates: FlightGate[], id: string): FlightGate {
  const found = gates.find((gate) => gate.id === id);
  if (!found) throw new Error(`门限 ${id} 不存在：${gates.map((g) => g.id).join(', ')}`);
  return found;
}

describe('normalizePhase', () => {
  it('认识后端的标准阶段名', () => {
    expect(normalizePhase('approach')).toBe('approach');
    expect(normalizePhase('  CRUISE ')).toBe('cruise');
  });

  it('把历史用过的 ground / on_ground 映射到 parked', () => {
    expect(normalizePhase('ground')).toBe('parked');
    expect(normalizePhase('on_ground')).toBe('parked');
  });

  it('未知值回落到 unknown 而不是抛异常', () => {
    expect(normalizePhase('banana')).toBe('unknown');
    expect(normalizePhase(undefined)).toBe('unknown');
  });
});

describe('buildGates', () => {
  it('进近阶段下降率超 1000 fpm 判为超限', () => {
    const gates = buildGates('approach', data({ verticalSpeed: -1400, bank: 3, gearDown: true, flapsDeployed: true }));
    expect(gateById(gates, 'sink_rate').status).toBe('exceeded');
  });

  it('进近阶段各项达标时全绿', () => {
    const gates = buildGates(
      'approach',
      data({ verticalSpeed: -700, bank: 2, gearDown: true, flapsDeployed: true }),
    );
    for (const gate of gates) {
      expect(gate.status).toBe('ok');
    }
  });

  it('逼近门限时给 watch，而不是等超了才报', () => {
    const gates = buildGates('approach', data({ verticalSpeed: -950, gearDown: true, flapsDeployed: true }));
    expect(gateById(gates, 'sink_rate').status).toBe('watch');
  });

  it('坡度门限按绝对值判定，左右坡一视同仁', () => {
    const left = buildGates('approach', data({ bank: -20 }));
    const right = buildGates('approach', data({ bank: 20 }));
    expect(gateById(left, 'bank_angle').status).toBe('exceeded');
    expect(gateById(right, 'bank_angle').status).toBe('exceeded');
  });

  it('进近时起落架没放判为超限', () => {
    const gates = buildGates('approach', data({ gearDown: false, verticalSpeed: -600 }));
    expect(gateById(gates, 'gear_down').status).toBe('exceeded');
  });

  // 把「没有数据」显示成「一切正常」是这类面板最危险的失败方式。
  it('数据缺失时报 unknown 而不是默认通过', () => {
    const gates = buildGates('approach', emptyFlightData());
    expect(gateById(gates, 'sink_rate').status).toBe('unknown');
    expect(gateById(gates, 'sink_rate').value).toBe('—');
    expect(gateById(gates, 'gear_down').status).toBe('unknown');
  });

  it('10000 ft 以下超过 250 kt 判为超限', () => {
    const gates = buildGates('climb', data({ altitude: 8000, airspeed: 280 }));
    expect(gateById(gates, 'speed_below_10000').status).toBe('exceeded');
  });

  it('10000 ft 以上不适用 250 kt 限制', () => {
    const gates = buildGates('climb', data({ altitude: 20000, airspeed: 320 }));
    const gate = gateById(gates, 'speed_below_10000');
    expect(gate.status).toBe('ok');
    expect(gate.limit).toContain('N/A');
  });

  it('滑行超速判为超限', () => {
    const gates = buildGates('taxi', data({ groundSpeed: 42 }));
    expect(gateById(gates, 'taxi_speed').status).toBe('exceeded');
  });

  it('起飞时忘记松停留刹车判为超限', () => {
    const gates = buildGates('takeoff', data({ parkingBrake: true, gearDown: true }));
    expect(gateById(gates, 'parking_brake').status).toBe('exceeded');
  });

  it('接地过载超过 1.8g 判为重着陆', () => {
    const gates = buildGates('landing', data({ touchdownGearG: 2.4, spoilersDeployed: true }));
    expect(gateById(gates, 'touchdown_g').status).toBe('exceeded');
  });

  it('unknown 阶段不产出门限', () => {
    expect(buildGates('unknown', data({ airspeed: 300 }))).toEqual([]);
  });
});

describe('computeFuelMargin', () => {
  it('没有油量数据时报 unknown', () => {
    expect(computeFuelMargin({ hasAlternate: false }).status).toBe('unknown');
  });

  it('有油量没航段信息时只给续航，不硬编距离', () => {
    const margin = computeFuelMargin({
      fuelQuantityKg: 6000,
      fuelFlowKgh: 2000,
      hasAlternate: false,
    });
    expect(margin.enduranceHours).toBeCloseTo(3, 6);
    expect(margin.marginKg).toBeUndefined();
    expect(margin.status).toBe('unknown');
  });

  it('余量充裕时判 ok', () => {
    const margin = computeFuelMargin({
      fuelQuantityKg: 12000,
      fuelFlowKgh: 2000,
      distanceToDestinationNm: 400,
      groundSpeedKt: 450,
      hasAlternate: false,
    });
    // 到目的地约 0.89h × 2000 ≈ 1778 kg，落地剩约 10222 kg，储备只要 1500 kg
    expect(margin.status).toBe('ok');
    expect(margin.fuelAtDestinationKg ?? 0).toBeGreaterThan(9000);
  });

  it('落地剩油低于最低储备时判 critical', () => {
    const margin = computeFuelMargin({
      fuelQuantityKg: 1800,
      fuelFlowKgh: 2000,
      distanceToDestinationNm: 400,
      groundSpeedKt: 450,
      hasAlternate: false,
    });
    expect(margin.status).toBe('critical');
    expect(margin.marginKg ?? 0).toBeLessThan(0);
  });

  it('设了备降场时储备要求更高', () => {
    const base = {
      fuelQuantityKg: 8000,
      fuelFlowKgh: 2000,
      distanceToDestinationNm: 400,
      groundSpeedKt: 450,
    };
    const without = computeFuelMargin({ ...base, hasAlternate: false });
    const withAlternate = computeFuelMargin({ ...base, hasAlternate: true });

    expect(withAlternate.requiredReserveKg ?? 0).toBeGreaterThan(without.requiredReserveKg ?? 0);
    expect(withAlternate.marginKg ?? 0).toBeLessThan(without.marginKg ?? 0);
  });

  it('最低储备 = 末端 45 分钟（无备降时）', () => {
    const margin = computeFuelMargin({
      fuelQuantityKg: 8000,
      fuelFlowKgh: 2000,
      distanceToDestinationNm: 100,
      groundSpeedKt: 400,
      hasAlternate: false,
    });
    expect(margin.requiredReserveKg).toBeCloseTo(2000 * FINAL_RESERVE_HOURS, 6);
  });

  it('备降段按固定距离折算', () => {
    const margin = computeFuelMargin({
      fuelQuantityKg: 8000,
      fuelFlowKgh: 2000,
      distanceToDestinationNm: 100,
      groundSpeedKt: 400,
      hasAlternate: true,
    });
    const expected = 2000 * FINAL_RESERVE_HOURS + (ALTERNATE_DISTANCE_NM / 400) * 2000;
    expect(margin.requiredReserveKg).toBeCloseTo(expected, 6);
  });

  it('地速为 0 时不做除法，报 unknown', () => {
    const margin = computeFuelMargin({
      fuelQuantityKg: 8000,
      fuelFlowKgh: 2000,
      distanceToDestinationNm: 400,
      groundSpeedKt: 0,
      hasAlternate: false,
    });
    expect(margin.status).toBe('unknown');
    expect(margin.timeToDestinationHours).toBeUndefined();
  });

  it('流量为 0 时不给续航，但仍用兜底流量算余度', () => {
    const margin = computeFuelMargin({
      fuelQuantityKg: 8000,
      fuelFlowKgh: 0,
      distanceToDestinationNm: 300,
      groundSpeedKt: 420,
      hasAlternate: false,
    });
    expect(margin.enduranceHours).toBeUndefined();
    expect(margin.burnToDestinationKg ?? 0).toBeGreaterThan(0);
  });
});
