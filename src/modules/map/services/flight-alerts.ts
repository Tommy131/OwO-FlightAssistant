/**
 * 飞行告警规则引擎（纯函数）
 *
 * 原先内嵌在 `map-store.ts` 里，读整个 `MapState`，没法脱离 Zustand 单独调用，
 * 也就一直没有测试 —— 而这是全模块**最该有测试**的一段：阈值判定错一个方向
 * （`>=` 写成 `>`、危险与警告级别写反），界面上仍然有告警在闪，
 * 只是闪错了级别，靠肉眼几乎发现不了。
 *
 * 这里只收规则真正用到的字段（而非整个 MapState），调用方按需组装。
 */

import type { FlightData } from '../../common/models/common-models';
import type { MapFlightAlert } from '../models/map-models';

/** 规则引擎所需的设置项 —— 刻意收窄，不依赖 MapState 的整体形状 */
export interface FlightAlertSettings {
  readonly alertsEnabled: boolean;
  readonly isConnected: boolean;
  readonly disabledAlertIds: readonly string[];
  readonly climbRateWarningFpm: number;
  readonly climbRateDangerFpm: number;
  readonly descentRateWarningFpm: number;
  readonly descentRateDangerFpm: number;
  readonly showTerrainWarning: boolean;
}

/** 坡度告警门限（度）：超过 45° 警告，超过 60° 危险 */
const BANK_WARNING_DEG = 45;
const BANK_DANGER_DEG = 60;

/** 迎角门限（度） */
const AOA_CAUTION_DEG = 15;
const AOA_DANGER_DEG = 18;

/** 近地告警：无线电高度低于此值且下降率超限才触发 */
const TERRAIN_RADIO_ALTITUDE_FT = 1000;
const TERRAIN_DESCENT_RATE_FPM = -1500;

/**
 * 评估当前遥测下应当亮起的告警
 *
 * 与桌面版一致：失速、爬升/下降率超限、大坡度、大迎角、近地。
 * 未连接模拟器或总开关关闭时一律不告警 —— 没有数据时保持沉默，
 * 而不是拿默认值算出一堆假告警。
 */
export function evaluateFlightAlerts(
  settings: FlightAlertSettings,
  flightData: FlightData,
): MapFlightAlert[] {
  if (!settings.alertsEnabled || !settings.isConnected) return [];

  const alerts: MapFlightAlert[] = [];
  const enabled = (id: string) => !settings.disabledAlertIds.includes(id);

  if (enabled('stall_warning') && flightData.stallWarning === true) {
    alerts.push({ id: 'stall_warning', level: 'danger', message: 'STALL' });
  }

  const verticalSpeed = flightData.verticalSpeed;
  if (verticalSpeed !== undefined) {
    if (enabled('excessive_climb_rate')) {
      // 先判危险再判警告：两个区间是包含关系，顺序反了永远出不了 danger
      if (verticalSpeed >= settings.climbRateDangerFpm) {
        alerts.push({ id: 'excessive_climb_rate', level: 'danger', message: 'CLIMB RATE' });
      } else if (verticalSpeed >= settings.climbRateWarningFpm) {
        alerts.push({ id: 'excessive_climb_rate', level: 'warning', message: 'CLIMB RATE' });
      }
    }
    if (enabled('excessive_descent_rate')) {
      // 下降率是负值，所以是 <=（阈值本身也是负数）
      if (verticalSpeed <= settings.descentRateDangerFpm) {
        alerts.push({ id: 'excessive_descent_rate', level: 'danger', message: 'SINK RATE' });
      } else if (verticalSpeed <= settings.descentRateWarningFpm) {
        alerts.push({ id: 'excessive_descent_rate', level: 'warning', message: 'SINK RATE' });
      }
    }
  }

  const bank = flightData.bank;
  if (enabled('bank_angle') && bank !== undefined && Math.abs(bank) >= BANK_WARNING_DEG) {
    alerts.push({
      id: 'bank_angle',
      level: Math.abs(bank) >= BANK_DANGER_DEG ? 'danger' : 'warning',
      message: 'BANK ANGLE',
    });
  }

  const aoa = flightData.angleOfAttack;
  if (enabled('high_aoa') && aoa !== undefined && aoa >= AOA_CAUTION_DEG) {
    alerts.push({
      id: 'high_aoa',
      level: aoa >= AOA_DANGER_DEG ? 'danger' : 'caution',
      message: 'HIGH AOA',
    });
  }

  // 近地告警：低无线电高度 + 大下降率，且未放起落架（放了说明是正常进近）
  const radioAltitude = flightData.radioAltitude;
  if (
    enabled('terrain_warning') &&
    settings.showTerrainWarning &&
    radioAltitude !== undefined &&
    radioAltitude < TERRAIN_RADIO_ALTITUDE_FT &&
    verticalSpeed !== undefined &&
    verticalSpeed < TERRAIN_DESCENT_RATE_FPM &&
    flightData.gearDown !== true
  ) {
    alerts.push({ id: 'terrain_warning', level: 'danger', message: 'TERRAIN' });
  }

  return alerts;
}
