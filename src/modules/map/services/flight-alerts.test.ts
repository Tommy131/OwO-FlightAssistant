import { describe, expect, it } from 'vitest';
import { evaluateFlightAlerts, type FlightAlertSettings } from './flight-alerts';
import type { FlightData } from '../../common/models/common-models';

/**
 * 飞行告警规则引擎
 *
 * 阈值判定最容易出的错不是「不报警」，而是**报错级别**：`>=` 写成 `>`、
 * 危险与警告两个分支写反 —— 界面上照样有东西在闪，肉眼分辨不出来。
 * 所以这里对每条规则都卡边界值，并显式验证危险优先于警告。
 */

const settings: FlightAlertSettings = {
  alertsEnabled: true,
  isConnected: true,
  disabledAlertIds: [],
  climbRateWarningFpm: 3000,
  climbRateDangerFpm: 5000,
  descentRateWarningFpm: -3000,
  descentRateDangerFpm: -5000,
  showTerrainWarning: true,
};

/** 一份「什么都不触发」的干净遥测 */
const calm: FlightData = {} as FlightData;

function alertsOf(flightData: Partial<FlightData>, overrides: Partial<FlightAlertSettings> = {}) {
  return evaluateFlightAlerts({ ...settings, ...overrides }, {
    ...calm,
    ...flightData,
  });
}

function levelOf(flightData: Partial<FlightData>, id: string) {
  return alertsOf(flightData).find((alert) => alert.id === id)?.level;
}

describe('总开关', () => {
  it('未连接模拟器时一律不告警', () => {
    // 没有数据时应当沉默，而不是拿默认值算出一堆假告警
    expect(alertsOf({ stallWarning: true }, { isConnected: false })).toEqual([]);
  });

  it('告警总开关关闭时一律不告警', () => {
    expect(alertsOf({ stallWarning: true }, { alertsEnabled: false })).toEqual([]);
  });

  it('单条告警可被禁用', () => {
    expect(alertsOf({ stallWarning: true }, { disabledAlertIds: ['stall_warning'] })).toEqual([]);
  });
});

describe('失速告警', () => {
  it('只认布尔真，不把 undefined 当真', () => {
    expect(levelOf({ stallWarning: true }, 'stall_warning')).toBe('danger');
    expect(levelOf({ stallWarning: false }, 'stall_warning')).toBeUndefined();
    expect(levelOf({}, 'stall_warning')).toBeUndefined();
  });
});

describe('爬升率告警', () => {
  it('边界值取到即告警（>= 而非 >）', () => {
    expect(levelOf({ verticalSpeed: 2999 }, 'excessive_climb_rate')).toBeUndefined();
    expect(levelOf({ verticalSpeed: 3000 }, 'excessive_climb_rate')).toBe('warning');
    expect(levelOf({ verticalSpeed: 4999 }, 'excessive_climb_rate')).toBe('warning');
  });

  it('危险级优先于警告级', () => {
    // 两个区间是包含关系：5000 同时满足 >=3000 与 >=5000，必须判 danger
    expect(levelOf({ verticalSpeed: 5000 }, 'excessive_climb_rate')).toBe('danger');
    expect(levelOf({ verticalSpeed: 9999 }, 'excessive_climb_rate')).toBe('danger');
  });

  it('同一时刻只产出一条爬升率告警', () => {
    const climb = alertsOf({ verticalSpeed: 9999 }).filter(
      (a) => a.id === 'excessive_climb_rate',
    );
    expect(climb).toHaveLength(1);
  });
});

describe('下降率告警', () => {
  it('阈值是负数，用 <= 判定', () => {
    expect(levelOf({ verticalSpeed: -2999 }, 'excessive_descent_rate')).toBeUndefined();
    expect(levelOf({ verticalSpeed: -3000 }, 'excessive_descent_rate')).toBe('warning');
    expect(levelOf({ verticalSpeed: -5000 }, 'excessive_descent_rate')).toBe('danger');
  });

  it('爬升不会触发下降率告警，反之亦然', () => {
    expect(levelOf({ verticalSpeed: 6000 }, 'excessive_descent_rate')).toBeUndefined();
    expect(levelOf({ verticalSpeed: -6000 }, 'excessive_climb_rate')).toBeUndefined();
  });

  it('没有垂直速度数据时两条都不报', () => {
    expect(levelOf({}, 'excessive_climb_rate')).toBeUndefined();
    expect(levelOf({}, 'excessive_descent_rate')).toBeUndefined();
  });
});

describe('坡度告警', () => {
  it('按绝对值判定，左右坡一视同仁', () => {
    expect(levelOf({ bank: 44 }, 'bank_angle')).toBeUndefined();
    expect(levelOf({ bank: 45 }, 'bank_angle')).toBe('warning');
    expect(levelOf({ bank: -45 }, 'bank_angle')).toBe('warning');
    expect(levelOf({ bank: 60 }, 'bank_angle')).toBe('danger');
    expect(levelOf({ bank: -75 }, 'bank_angle')).toBe('danger');
  });
});

describe('迎角告警', () => {
  it('15° 起 caution，18° 起 danger', () => {
    expect(levelOf({ angleOfAttack: 14.9 }, 'high_aoa')).toBeUndefined();
    expect(levelOf({ angleOfAttack: 15 }, 'high_aoa')).toBe('caution');
    expect(levelOf({ angleOfAttack: 18 }, 'high_aoa')).toBe('danger');
  });
});

describe('近地告警', () => {
  const sinking: Partial<FlightData> = { radioAltitude: 500, verticalSpeed: -2000 };

  it('低高度 + 大下降率 + 未放起落架才触发', () => {
    expect(levelOf(sinking, 'terrain_warning')).toBe('danger');
  });

  it('已放起落架说明是正常进近，不报', () => {
    expect(levelOf({ ...sinking, gearDown: true }, 'terrain_warning')).toBeUndefined();
  });

  it('高度够高或下降率不大都不报', () => {
    expect(levelOf({ ...sinking, radioAltitude: 1000 }, 'terrain_warning')).toBeUndefined();
    expect(levelOf({ ...sinking, verticalSpeed: -1500 }, 'terrain_warning')).toBeUndefined();
  });

  it('地形图层关闭时不报', () => {
    expect(
      alertsOf(sinking, { showTerrainWarning: false }).find((a) => a.id === 'terrain_warning'),
    ).toBeUndefined();
  });
});

describe('多条告警并存', () => {
  it('互不干扰，各自按自己的规则产出', () => {
    const alerts = alertsOf({
      stallWarning: true,
      verticalSpeed: -6000,
      bank: 70,
      angleOfAttack: 20,
      radioAltitude: 300,
    });
    const ids = alerts.map((a) => a.id).sort();
    expect(ids).toEqual(
      ['bank_angle', 'excessive_descent_rate', 'high_aoa', 'stall_warning', 'terrain_warning'].sort(),
    );
  });
});
