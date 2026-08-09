import { create } from 'zustand';
import { PersistenceService } from '../../../core/services/persistence-service';
import type { FlightDataSnapshot } from '../../common/models/common-models';
import {
  emptyMonitorData,
  MonitorChartBuffer,
  type MonitorData,
} from '../models/monitor-models';

/**
 * 监控模块状态管理
 *
 * 对应 Flutter 版 `modules/monitor/providers/monitor_provider.dart`。
 * 保留桌面版的「低性能模式 + UI 刷新间隔限流」—— 监控页每帧都在重绘图表，
 * 不限流会明显拉高 GPU 占用。
 */

const SETTINGS_MODULE_NAME = 'monitor';
const LOW_PERFORMANCE_MODE_KEY = 'low_performance_mode';
const UI_REFRESH_INTERVAL_MS_KEY = 'ui_refresh_interval_ms';

const DEFAULT_UI_REFRESH_INTERVAL_MS = 200;
/** 低性能模式下强制的最低刷新间隔 */
const LOW_PERFORMANCE_REFRESH_INTERVAL_MS = 500;
const MIN_REFRESH_INTERVAL_MS = 60;
const MAX_REFRESH_INTERVAL_MS = 2000;

interface MonitorState {
  data: MonitorData;
  lowPerformanceMode: boolean;
  uiRefreshIntervalMs: number;

  updateFromFlightSnapshot: (snapshot: FlightDataSnapshot) => void;
  loadPerformanceSettings: () => Promise<void>;
  setLowPerformanceMode: (enabled: boolean) => Promise<void>;
  setUiRefreshIntervalMs: (milliseconds: number) => Promise<void>;
}

/** 图表缓冲与限流时间戳不参与渲染，放在 store 外 */
const chartBuffer = new MonitorChartBuffer();
let lastUiNotifyAt: number | null = null;
/** 最近一次未被推送到 UI 的数据（限流窗口结束后补发） */
let pendingData: MonitorData | null = null;

export const useMonitorStore = create<MonitorState>((set, get) => ({
  data: emptyMonitorData(),
  lowPerformanceMode: false,
  uiRefreshIntervalMs: DEFAULT_UI_REFRESH_INTERVAL_MS,

  updateFromFlightSnapshot(snapshot) {
    const flightData = snapshot.flightData;
    const isPaused = snapshot.isPaused === true;

    // 暂停时不再向图表追加点，避免时间轴被无效数据拉长
    if (!isPaused) {
      chartBuffer.append({
        gForce: flightData.gForce ?? 1.0,
        altitude: flightData.altitude ?? 0,
        pressure: flightData.baroPressure ?? 29.92,
      });
    }

    const next: MonitorData = {
      isConnected: snapshot.isConnected,
      chartData: chartBuffer.buildSnapshot(),
      isPaused: snapshot.isPaused,
      masterWarning: flightData.masterWarning,
      masterCaution: flightData.masterCaution,
      heading: flightData.heading,
      aircraftIcao: flightData.aircraftIcao,
      aircraftTitle: flightData.aircraftDisplayName ?? flightData.aircraftModel,
      parkingBrake: flightData.parkingBrake,
      transponderState: snapshot.transponderState,
      transponderCode: snapshot.transponderCode,
      flapsLabel: flightData.flapsLabel,
      flapsDeployRatio: flightData.flapsDeployRatio,
      speedBrakeLabel: flightData.speedBrakeLabel,
      speedBrake: flightData.speedBrake,
      fireWarningEngine1: flightData.fireWarningEngine1,
      fireWarningEngine2: flightData.fireWarningEngine2,
      fireWarningAPU: flightData.fireWarningAPU,
      noseGearDown: flightData.noseGearDown,
      leftGearDown: flightData.leftGearDown,
      rightGearDown: flightData.rightGearDown,
      gForce: flightData.gForce,
      altitude: flightData.altitude,
      baroPressure: flightData.baroPressure,
    };

    if (shouldNotifyUi(get())) {
      pendingData = null;
      set({ data: next });
    } else {
      // 限流窗口内先攒着，窗口结束时由下一帧带出
      pendingData = next;
    }
  },

  async loadPerformanceSettings() {
    await PersistenceService.ensureReady();
    const lowPerformanceMode =
      PersistenceService.getModuleData<boolean>(
        SETTINGS_MODULE_NAME,
        LOW_PERFORMANCE_MODE_KEY,
      ) ?? false;
    const stored =
      PersistenceService.getModuleData<number>(
        SETTINGS_MODULE_NAME,
        UI_REFRESH_INTERVAL_MS_KEY,
      ) ?? DEFAULT_UI_REFRESH_INTERVAL_MS;

    set({
      lowPerformanceMode,
      uiRefreshIntervalMs: clampInterval(stored),
    });
  },

  async setLowPerformanceMode(enabled) {
    set({ lowPerformanceMode: enabled });
    await PersistenceService.setModuleData(
      SETTINGS_MODULE_NAME,
      LOW_PERFORMANCE_MODE_KEY,
      enabled,
    );
  },

  async setUiRefreshIntervalMs(milliseconds) {
    const clamped = clampInterval(milliseconds);
    set({ uiRefreshIntervalMs: clamped });
    await PersistenceService.setModuleData(
      SETTINGS_MODULE_NAME,
      UI_REFRESH_INTERVAL_MS_KEY,
      clamped,
    );
  },
}));

/** 限流判定：低性能模式下取「配置间隔」与「500ms」中的较大者 */
function shouldNotifyUi(state: MonitorState): boolean {
  const minInterval = state.lowPerformanceMode
    ? Math.max(state.uiRefreshIntervalMs, LOW_PERFORMANCE_REFRESH_INTERVAL_MS)
    : state.uiRefreshIntervalMs;

  const now = Date.now();
  if (lastUiNotifyAt === null || now - lastUiNotifyAt >= minInterval) {
    lastUiNotifyAt = now;
    return true;
  }
  return false;
}

function clampInterval(value: number): number {
  return Math.min(Math.max(Math.trunc(value), MIN_REFRESH_INTERVAL_MS), MAX_REFRESH_INTERVAL_MS);
}

/**
 * 冲刷被限流挡下的最后一帧
 *
 * 桌面版靠 Provider 的下一次 notify 自然带出；Web 版数据源静止时不会再有下一帧，
 * 因此监控页在卸载/暂停时主动调一次，避免图表停在上一个刷新窗口。
 */
export function flushPendingMonitorData(): void {
  if (pendingData === null) return;
  lastUiNotifyAt = Date.now();
  const data = pendingData;
  pendingData = null;
  useMonitorStore.setState({ data });
}

/** 重置图表缓冲（断开连接时使用） */
export function resetMonitorChartBuffer(): void {
  chartBuffer.reset();
  pendingData = null;
  useMonitorStore.setState({ data: emptyMonitorData() });
}
