/**
 * 飞行告警规则引擎（纯函数）
 *
 * 对应桌面版 `map/providers/components/map_alert_component.dart`。
 *
 * ── 告警从哪来（这一版的核心改动）──
 * **姿态类判据在中间件**：`internal/apps/simulators/utils/utils.go` 的
 * `buildFlightAlerts` 拿得到全量 dataref，能判俯仰/坡度/倒飞/刀锋/螺旋下降/
 * 过载/超速等三十来种，结果随遥测放在 `client_dataset.flight_alerts` 里下发。
 *
 * 早先 Web 端**完全没读这条流**，只在前端另写了六条薄规则（失速、升降率、
 * 坡度、迎角、近地），于是后端算出来的姿态告警一条都到不了界面 ——
 * 用户反馈的「智能感知告警过于简陋」就是这么来的。桌面版从一开始就是读后端流的。
 *
 * 现在的分工与桌面版一致：
 *   - 姿态与性能类：**用后端的**；
 *   - 升降率：**前端按用户阈值重算**（阈值是用户可调的，后端不知道），
 *     因此后端同名告警要跳过，否则两套判据会打架；
 *   - 近地接近：前端按无线电高度 + 下沉率补一条（后端没有地形数据）。
 *
 * `message` 里放的是 **i18n key**，不是文案 —— 渲染处负责翻译。
 * 早先直接放 'STALL' 这种英文串，黑匣子明细里就是一片没翻译的英文。
 */

import type { FlightAlert, FlightData } from '../../common/models/common-models';
import { MapLocalizationKeys as K } from '../localization/map-localization';
import type { MapFlightAlert, MapFlightAlertLevel } from '../models/map-models';

/**
 * 后端告警 message 令牌 → i18n key
 *
 * ⚠️ 键是**后端 message 字段**而不是 id：中间件的 `appendAlert(id, level, message)`
 * 会让多个 id 共用一个 message（如 `spiral_dive_danger` 的 message 是
 * `push_over_danger`），桌面版正是按 message 查表并按 message 去重，
 * 把语义相同的告警合成一条。这里逐条对齐，不要改成按 id 查。
 */
export const BACKEND_ALERT_MESSAGE_KEY: Record<string, string> = {
  pitch_up_danger: K.alertPitchUpDanger,
  pitch_up_warning: K.alertPitchUpWarning,
  pitch_down_danger: K.alertPitchDownDanger,
  pitch_down_warning: K.alertPitchDownWarning,
  bank_danger: K.alertBankDanger,
  bank_warning: K.alertBankWarning,
  stall_warning: K.alertStallWarning,
  sink_rate_danger: K.alertSinkRateDanger,
  sink_rate_warning: K.alertSinkRateWarning,
  inverted_flight_danger: K.alertInvertedFlightDanger,
  knife_edge_danger: K.alertKnifeEdgeDanger,
  knife_edge_warning: K.alertKnifeEdgeWarning,
  pull_up_danger: K.alertPullUpDanger,
  pull_up_warning: K.alertPullUpWarning,
  push_over_danger: K.alertPushOverDanger,
  push_over_warning: K.alertPushOverWarning,
  spiral_dive_danger: K.alertSpiralDiveDanger,
  spiral_dive_warning: K.alertSpiralDiveWarning,
  unusual_attitude_danger: K.alertUnusualAttitudeDanger,
  unusual_attitude_warning: K.alertUnusualAttitudeWarning,
  climb_rate_danger: K.alertClimbRateDanger,
  climb_rate_warning: K.alertClimbRateWarning,
  descent_rate_danger: K.alertDescentRateDanger,
  descent_rate_warning: K.alertDescentRateWarning,
  high_g_danger: K.alertHighGDanger,
  high_g_warning: K.alertHighGWarning,
  negative_g_danger: K.alertNegativeGDanger,
  negative_g_warning: K.alertNegativeGWarning,
  overspeed_danger: K.alertOverspeedDanger,
  overspeed_warning: K.alertOverspeedWarning,
  terrain_pull_up_danger: K.alertTerrainPullUpDanger,
  terrain_pull_up_warning: K.alertTerrainPullUpWarning,
};

/**
 * 可在设置里逐条开关的告警 id。
 *
 * 与桌面版一致，直接取自上面的映射表 —— 手写一份平行清单迟早对不上，
 * 早先那份只有 8 项，其中 `overspeed` 这个 id 后端根本不会发。
 */
/**
 * 前端自己算、后端不发的告警 id → i18n key。
 *
 * 前视地形要拿高程瓦片比对，后端没有这个数据，判定只能在前端做
 * （见 `terrain-model.ts`）。但它同样要能在设置里逐条关掉，
 * 所以必须进文案表 —— 只进 id 清单不进文案表，设置页上就会露出裸 id。
 */
export const LOCAL_ALERT_MESSAGE_KEY: Record<string, string> = {
  terrain_ahead_danger: K.alertTerrainAheadDanger,
  terrain_ahead_caution: K.alertTerrainAheadCaution,
};

/**
 * 全部告警 id → i18n key。
 *
 * 设置页的清单与文案都从这一张表取，**不要**再各写一份 ——
 * 手写平行清单迟早对不上，这正是早先那份只有 8 项的清单出的问题。
 */
export const ALERT_MESSAGE_KEY: Record<string, string> = {
  ...BACKEND_ALERT_MESSAGE_KEY,
  ...LOCAL_ALERT_MESSAGE_KEY,
};

export const CONFIGURABLE_ALERT_IDS: readonly string[] = Object.keys(ALERT_MESSAGE_KEY);

/**
 * 由前端按用户阈值重算的升降率告警 id。
 *
 * 后端发的同名告警要**丢掉**：阈值在用户设置里，后端用的是自己那套固定值，
 * 两边同时出会让用户改了阈值却发现告警照旧。
 */
const VERTICAL_RATE_ALERT_IDS = new Set([
  'climb_rate_warning',
  'climb_rate_danger',
  'descent_rate_warning',
  'descent_rate_danger',
]);

/** 近地接近判据（与桌面版逐条对齐） */
const TERRAIN_DANGER_RADIO_ALT_FT = 250;
const TERRAIN_DANGER_SINK_FPM = 1200;
const TERRAIN_WARNING_RADIO_ALT_FT = 600;
const TERRAIN_WARNING_SINK_FPM = 700;

/** 规则引擎所需的设置项 —— 刻意收窄，不依赖 MapState 的整体形状 */
export interface FlightAlertSettings {
  readonly alertsEnabled: boolean;
  readonly isConnected: boolean;
  readonly disabledAlertIds: readonly string[];
  readonly climbRateWarningFpm: number;
  readonly climbRateDangerFpm: number;
  /** 下降阈值在本项目里存的是**负值**（-3000 / -5000），与桌面版存正值不同 */
  readonly descentRateWarningFpm: number;
  readonly descentRateDangerFpm: number;
  readonly showTerrainWarning: boolean;
}

/** 把后端 message 令牌翻成 i18n key；认不出来返回 undefined */
export function resolveAlertMessageKey(rawMessage: string | undefined): string | undefined {
  const token = (rawMessage ?? '').trim().toLowerCase();
  if (token.length === 0) return undefined;
  return BACKEND_ALERT_MESSAGE_KEY[token];
}

/** 后端 level 字符串 → 地图告警级别；认不出的按 caution 处理 */
export function normalizeAlertLevel(raw: string | undefined): MapFlightAlertLevel {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'danger':
      return 'danger';
    case 'warning':
      return 'warning';
    default:
      return 'caution';
  }
}

/**
 * 评估当前遥测下应当亮起的告警。
 *
 * 未连接模拟器或总开关关闭时一律不告警 —— 没有数据时保持沉默，
 * 而不是拿默认值算出一堆假告警。
 */
export function evaluateFlightAlerts(
  settings: FlightAlertSettings,
  flightData: FlightData,
  /**
   * 调用方算好的附加告警（目前是前视地形，见 `terrain-model.ts`）。
   *
   * 前视判定要用高程瓦片，那是 IO 拿回来的，不能塞进这个纯函数；
   * 但它必须和其它告警走同一套「逐条开关 + 按文案去重」，所以从这里并进来。
   */
  extraAlerts: readonly MapFlightAlert[] = [],
): MapFlightAlert[] {
  if (!settings.alertsEnabled || !settings.isConnected) return [];

  const disabled = new Set(settings.disabledAlertIds.map((id) => id.trim().toLowerCase()));
  const alerts: MapFlightAlert[] = [];
  // 按**文案**去重：多个后端 id 共用一条文案时只显示一条（见映射表的说明）
  const shownMessages = new Set<string>();

  for (const alert of mapBackendAlerts(flightData.flightAlerts)) {
    const id = alert.id.trim().toLowerCase();
    if (VERTICAL_RATE_ALERT_IDS.has(id)) continue;
    if (disabled.has(id)) continue;
    if (shownMessages.has(alert.message)) continue;
    shownMessages.add(alert.message);
    alerts.push(alert);
  }

  const verticalRate = buildVerticalRateAlert(settings, flightData.verticalSpeed);
  if (
    verticalRate &&
    !disabled.has(verticalRate.id) &&
    !shownMessages.has(verticalRate.message)
  ) {
    shownMessages.add(verticalRate.message);
    alerts.push(verticalRate);
  }

  if (settings.showTerrainWarning) {
    const terrain = buildTerrainProximityAlert(flightData);
    if (terrain && !disabled.has(terrain.id) && !shownMessages.has(terrain.message)) {
      shownMessages.add(terrain.message);
      alerts.push(terrain);
    }
    // 前视地形与近地接近共用「地形告警」这一个开关
    for (const extra of extraAlerts) {
      const id = extra.id.trim().toLowerCase();
      if (disabled.has(id)) continue;
      if (shownMessages.has(extra.message)) continue;
      shownMessages.add(extra.message);
      alerts.push(extra);
    }
  }

  return alerts;
}

/** 把后端告警流翻成地图告警；认不出文案的直接丢掉 */
function mapBackendAlerts(backendAlerts: readonly FlightAlert[]): MapFlightAlert[] {
  const out: MapFlightAlert[] = [];
  const seen = new Set<string>();
  for (const alert of backendAlerts) {
    const message = resolveAlertMessageKey(alert.message);
    if (message === undefined || seen.has(message)) continue;
    seen.add(message);
    out.push({
      id: alert.id.trim().length > 0 ? alert.id : alert.message,
      level: normalizeAlertLevel(alert.level),
      message,
    });
  }
  return out;
}

/** 按用户阈值算升降率告警；先判危险再判警告，两个区间是包含关系 */
function buildVerticalRateAlert(
  settings: FlightAlertSettings,
  verticalSpeed: number | undefined,
): MapFlightAlert | null {
  if (verticalSpeed === undefined || !Number.isFinite(verticalSpeed)) return null;

  if (verticalSpeed >= settings.climbRateDangerFpm) {
    return { id: 'climb_rate_danger', level: 'danger', message: K.alertClimbRateDanger };
  }
  if (verticalSpeed >= settings.climbRateWarningFpm) {
    return { id: 'climb_rate_warning', level: 'warning', message: K.alertClimbRateWarning };
  }
  // 下降阈值本身是负数，所以用 <=
  if (verticalSpeed <= settings.descentRateDangerFpm) {
    return { id: 'descent_rate_danger', level: 'danger', message: K.alertDescentRateDanger };
  }
  if (verticalSpeed <= settings.descentRateWarningFpm) {
    return { id: 'descent_rate_warning', level: 'warning', message: K.alertDescentRateWarning };
  }
  return null;
}

/** 近地接近：低无线电高度 + 大下沉率。地面上不判 */
function buildTerrainProximityAlert(flightData: FlightData): MapFlightAlert | null {
  if (flightData.onGround === true) return null;
  const radioAltitude = flightData.radioAltitude;
  if (radioAltitude === undefined || !Number.isFinite(radioAltitude)) return null;

  const sinkRate = -(flightData.verticalSpeed ?? 0);
  if (radioAltitude <= TERRAIN_DANGER_RADIO_ALT_FT && sinkRate >= TERRAIN_DANGER_SINK_FPM) {
    return { id: 'terrain_pull_up_danger', level: 'danger', message: K.alertTerrainPullUpDanger };
  }
  if (radioAltitude <= TERRAIN_WARNING_RADIO_ALT_FT && sinkRate >= TERRAIN_WARNING_SINK_FPM) {
    return {
      id: 'terrain_pull_up_warning',
      level: 'warning',
      message: K.alertTerrainPullUpWarning,
    };
  }
  return null;
}
