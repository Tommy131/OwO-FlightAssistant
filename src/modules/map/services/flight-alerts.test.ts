import { describe, expect, it } from 'vitest';

import { emptyFlightData, type FlightAlert, type FlightData } from '../../common/models/common-models';
import { MapLocalizationKeys as K } from '../localization/map-localization';
import {
  BACKEND_ALERT_MESSAGE_KEY,
  CONFIGURABLE_ALERT_IDS,
  evaluateFlightAlerts,
  normalizeAlertLevel,
  resolveAlertMessageKey,
  type FlightAlertSettings,
} from './flight-alerts';

/**
 * 飞行告警规则引擎
 *
 * 这一版的重点是「姿态告警从后端流里来」—— 早先前端完全不读那条流，
 * 中间件算出来的三十来种姿态告警一条都到不了界面。
 */

function settings(overrides: Partial<FlightAlertSettings> = {}): FlightAlertSettings {
  return {
    alertsEnabled: true,
    isConnected: true,
    disabledAlertIds: [],
    climbRateWarningFpm: 3000,
    climbRateDangerFpm: 5000,
    descentRateWarningFpm: -3000,
    descentRateDangerFpm: -5000,
    showTerrainWarning: true,
    ...overrides,
  };
}

function data(overrides: Partial<FlightData> = {}): FlightData {
  return { ...emptyFlightData(), ...overrides };
}

function backendAlert(id: string, level: string, message = id): FlightAlert {
  return { id, level, message };
}

describe('总开关', () => {
  it('未连接时一律不告警', () => {
    const alerts = evaluateFlightAlerts(
      settings({ isConnected: false }),
      data({ flightAlerts: [backendAlert('bank_danger', 'danger')] }),
    );
    expect(alerts).toEqual([]);
  });

  it('告警总开关关闭时一律不告警', () => {
    const alerts = evaluateFlightAlerts(
      settings({ alertsEnabled: false }),
      data({ flightAlerts: [backendAlert('bank_danger', 'danger')] }),
    );
    expect(alerts).toEqual([]);
  });
});

describe('后端姿态告警', () => {
  // 这是本次修复的核心：桌面版有的姿态告警，Web 版都要能触发
  it.each([
    ['pitch_up_danger', K.alertPitchUpDanger],
    ['pitch_down_warning', K.alertPitchDownWarning],
    ['bank_danger', K.alertBankDanger],
    ['inverted_flight_danger', K.alertInvertedFlightDanger],
    ['knife_edge_warning', K.alertKnifeEdgeWarning],
    ['pull_up_danger', K.alertPullUpDanger],
    ['push_over_warning', K.alertPushOverWarning],
    ['spiral_dive_danger', K.alertSpiralDiveDanger],
    ['unusual_attitude_warning', K.alertUnusualAttitudeWarning],
    ['high_g_danger', K.alertHighGDanger],
    ['negative_g_warning', K.alertNegativeGWarning],
    ['overspeed_danger', K.alertOverspeedDanger],
    ['stall_warning', K.alertStallWarning],
    ['sink_rate_danger', K.alertSinkRateDanger],
  ])('%s 能从后端流触发', (token, expectedKey) => {
    const alerts = evaluateFlightAlerts(
      settings(),
      data({ flightAlerts: [backendAlert(token, 'danger')] }),
    );
    expect(alerts.map((a) => a.message)).toContain(expectedKey);
  });

  it('级别按后端给的映射，认不出的按 caution', () => {
    expect(normalizeAlertLevel('danger')).toBe('danger');
    expect(normalizeAlertLevel('WARNING')).toBe('warning');
    expect(normalizeAlertLevel('weird')).toBe('caution');
    expect(normalizeAlertLevel(undefined)).toBe('caution');
  });

  it('认不出文案的后端告警直接丢掉，不把裸令牌显示出去', () => {
    const alerts = evaluateFlightAlerts(
      settings(),
      data({ flightAlerts: [backendAlert('brand_new_alert', 'danger')] }),
    );
    expect(alerts).toEqual([]);
  });

  // 中间件里多个 id 共用一条 message（spiral_dive_danger 的 message 是 push_over_danger）
  it('共用同一条文案的告警合并成一条', () => {
    const alerts = evaluateFlightAlerts(
      settings(),
      data({
        flightAlerts: [
          backendAlert('push_over_danger', 'danger', 'push_over_danger'),
          backendAlert('spiral_dive_danger', 'danger', 'push_over_danger'),
          backendAlert('unusual_attitude_danger', 'danger', 'push_over_danger'),
        ],
      }),
    );
    expect(alerts).toHaveLength(1);
    expect(alerts[0].message).toBe(K.alertPushOverDanger);
  });

  it('被用户关掉的告警不出现', () => {
    const alerts = evaluateFlightAlerts(
      settings({ disabledAlertIds: ['bank_danger'] }),
      data({ flightAlerts: [backendAlert('bank_danger', 'danger')] }),
    );
    expect(alerts).toEqual([]);
  });

  it('关闭判定不区分大小写与空白', () => {
    const alerts = evaluateFlightAlerts(
      settings({ disabledAlertIds: ['  BANK_DANGER '] }),
      data({ flightAlerts: [backendAlert('bank_danger', 'danger')] }),
    );
    expect(alerts).toEqual([]);
  });
});

describe('升降率告警按用户阈值重算', () => {
  it('超过危险阈值报 danger', () => {
    const alerts = evaluateFlightAlerts(settings(), data({ verticalSpeed: 5200 }));
    expect(alerts).toEqual([
      { id: 'climb_rate_danger', level: 'danger', message: K.alertClimbRateDanger },
    ]);
  });

  it('先判危险再判警告，顺序反了永远出不了 danger', () => {
    expect(evaluateFlightAlerts(settings(), data({ verticalSpeed: 3500 }))[0].level).toBe('warning');
    expect(evaluateFlightAlerts(settings(), data({ verticalSpeed: 6000 }))[0].level).toBe('danger');
  });

  it('下降阈值是负值，用 <= 判', () => {
    expect(evaluateFlightAlerts(settings(), data({ verticalSpeed: -3200 }))[0].id).toBe(
      'descent_rate_warning',
    );
    expect(evaluateFlightAlerts(settings(), data({ verticalSpeed: -5200 }))[0].id).toBe(
      'descent_rate_danger',
    );
  });

  it('阈值内不报', () => {
    expect(evaluateFlightAlerts(settings(), data({ verticalSpeed: 1000 }))).toEqual([]);
  });

  // 阈值在用户设置里，后端用的是自己那套固定值，两边同时出会打架
  it('后端发的同名升降率告警被丢掉，只保留按用户阈值算的那条', () => {
    const alerts = evaluateFlightAlerts(
      settings({ climbRateWarningFpm: 9000, climbRateDangerFpm: 12000 }),
      data({
        verticalSpeed: 4000,
        flightAlerts: [backendAlert('climb_rate_danger', 'danger')],
      }),
    );
    // 用户把阈值调高了 → 4000 fpm 不该再报
    expect(alerts).toEqual([]);
  });

  it('用户关掉升降率告警后不报', () => {
    const alerts = evaluateFlightAlerts(
      settings({ disabledAlertIds: ['climb_rate_danger'] }),
      data({ verticalSpeed: 6000 }),
    );
    expect(alerts).toEqual([]);
  });

  it('没有垂直速度时不报', () => {
    expect(evaluateFlightAlerts(settings(), data({}))).toEqual([]);
  });
});

describe('近地接近告警', () => {
  it('极低高度 + 大下沉率报 danger', () => {
    const alerts = evaluateFlightAlerts(
      settings(),
      data({ radioAltitude: 200, verticalSpeed: -1300, onGround: false }),
    );
    expect(alerts.map((a) => a.id)).toContain('terrain_pull_up_danger');
  });

  it('中等高度 + 中等下沉率报 warning', () => {
    const alerts = evaluateFlightAlerts(
      settings(),
      data({ radioAltitude: 500, verticalSpeed: -800, onGround: false }),
    );
    expect(alerts.map((a) => a.id)).toContain('terrain_pull_up_warning');
  });

  it('在地面时不报 —— 否则每次落地滑跑都会亮', () => {
    const alerts = evaluateFlightAlerts(
      settings(),
      data({ radioAltitude: 0, verticalSpeed: -1500, onGround: true }),
    );
    expect(alerts.map((a) => a.id)).not.toContain('terrain_pull_up_danger');
  });

  it('地形图层关闭时不报', () => {
    const alerts = evaluateFlightAlerts(
      settings({ showTerrainWarning: false }),
      data({ radioAltitude: 200, verticalSpeed: -1300, onGround: false }),
    );
    expect(alerts.map((a) => a.id)).not.toContain('terrain_pull_up_danger');
  });

  it('没有无线电高度时不报', () => {
    const alerts = evaluateFlightAlerts(settings(), data({ verticalSpeed: -1500, onGround: false }));
    expect(alerts.map((a) => a.id)).not.toContain('terrain_pull_up_danger');
  });

  it('高度低但没在下降时不报', () => {
    const alerts = evaluateFlightAlerts(
      settings(),
      data({ radioAltitude: 200, verticalSpeed: -100, onGround: false }),
    );
    expect(alerts.map((a) => a.id)).not.toContain('terrain_pull_up_danger');
  });
});

describe('多来源并存', () => {
  it('后端姿态 + 前端升降率 + 近地各自产出', () => {
    const alerts = evaluateFlightAlerts(
      settings(),
      data({
        flightAlerts: [backendAlert('bank_danger', 'danger')],
        verticalSpeed: -5200,
        radioAltitude: 200,
        onGround: false,
      }),
    );
    const ids = alerts.map((a) => a.id);
    expect(ids).toContain('bank_danger');
    expect(ids).toContain('descent_rate_danger');
    expect(ids).toContain('terrain_pull_up_danger');
  });

  // 后端也会发 terrain_pull_up_*，与前端本地那条判据文案相同 —— 只能出一条
  it('后端与前端产出同一条近地文案时只显示一条', () => {
    const alerts = evaluateFlightAlerts(
      settings(),
      data({
        flightAlerts: [backendAlert('terrain_pull_up_danger', 'danger')],
        radioAltitude: 200,
        verticalSpeed: -1300,
        onGround: false,
      }),
    );
    const terrainAlerts = alerts.filter((a) => a.message === K.alertTerrainPullUpDanger);
    expect(terrainAlerts).toHaveLength(1);
  });

  it('后端 sink_rate 与前端 descent_rate 文案不同，不会互相吞掉', () => {
    const alerts = evaluateFlightAlerts(
      settings(),
      data({
        flightAlerts: [backendAlert('sink_rate_danger', 'danger')],
        verticalSpeed: -5200,
      }),
    );
    expect(alerts).toHaveLength(2);
  });
});

describe('可配置告警清单', () => {
  it('与映射表一致，不再是手写的平行清单', () => {
    expect(CONFIGURABLE_ALERT_IDS).toEqual(Object.keys(BACKEND_ALERT_MESSAGE_KEY));
    expect(CONFIGURABLE_ALERT_IDS.length).toBeGreaterThan(25);
  });

  it('每一项都有对应文案，设置页不会露出裸 id', () => {
    for (const id of CONFIGURABLE_ALERT_IDS) {
      expect(BACKEND_ALERT_MESSAGE_KEY[id]).toBeDefined();
    }
  });
});

describe('resolveAlertMessageKey', () => {
  it('大小写与空白不敏感', () => {
    expect(resolveAlertMessageKey(' BANK_DANGER ')).toBe(K.alertBankDanger);
  });

  it('认不出的返回 undefined，让调用方决定怎么兜底', () => {
    expect(resolveAlertMessageKey('nope')).toBeUndefined();
    expect(resolveAlertMessageKey('')).toBeUndefined();
    expect(resolveAlertMessageKey(undefined)).toBeUndefined();
  });
});
