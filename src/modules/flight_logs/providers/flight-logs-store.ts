import { del as idbDel, get as idbGet, set as idbSet } from 'idb-keyval';
import { create } from 'zustand';
import {
  mergeById,
  pullRecords,
  pushRecord,
  removeRecord,
} from '../../../core/services/backend-sync';
import { PersistenceService } from '../../../core/services/persistence-service';
import { AppLogger } from '../../../core/utils/logger';
import { toJsonMap, toText } from '../../../core/utils/parse-utils';
import type { FlightDataSnapshot, SimulatorType } from '../../common/models/common-models';
import { lookupRunwayAt } from '../services/runway-lookup';
import {
  computeLandingMetrics,
  computeTakeoffMetrics,
  flareHeightFt,
  peakTouchdownG,
  touchdownSinkRateFpm,
} from '../services/takeoff-landing-metrics';
import {
  flightLogDurationMs,
  flightLogFromJson,
  flightLogToJson,
  resolveLandingRating,
  type FlightLog,
  type FlightLogAlert,
  type FlightLogPoint,
  type LandingGSource,
} from '../models/flight-log-models';

/**
 * 飞行日志 store
 *
 * 对应 Flutter 版 `modules/flight_logs/providers/flight_logs_provider.dart`（1356 行）。
 * 保留桌面版的采样节流、起飞/落地检测、燃油统计与最短记录时长约束。
 *
 * ── Web 降级说明 ──
 * 桌面版把每条日志写成 `<dataRoot>/flight_logs/flight_log_<id>.json`；
 * Web 版改存 IndexedDB（同一份 JSON 结构），导入导出走 file input / Blob 下载，
 * 因此两端的 .json 文件可以互通。
 */

const MODULE_NAME = 'flight_logs';
const LOGS_KEY = 'logs';
const SAMPLE_INTERVAL_MS_KEY = 'sample_interval_ms';

export const DEFAULT_SAMPLE_INTERVAL_MS = 100;
export const MIN_SAMPLE_INTERVAL_MS = 100;
export const MAX_SAMPLE_INTERVAL_MS = 2000;

/**
 * 录制中日志的崩溃恢复存档
 *
 * ── 为什么要单开一条 IndexedDB 键，不走 PersistenceService ──
 * 1. `PersistenceService.setModuleData` 内部是 **300ms 防抖且每次调用都重置计时器**，
 *    按 100ms 采样间隔调用它，计时器永远被推后，一次都不会真正落盘；
 * 2. 它还会把整桶数据 `pushSetting` 同步到中间件 —— 录制中的日志有几千个采样点，
 *    每隔几秒往后端推一份完整副本纯属浪费。
 *
 * 录制中的日志是崩溃恢复用的临时状态，不是用户设置，直接写 IndexedDB 最合适。
 */
const ACTIVE_LOG_IDB_KEY = 'owo-flight-assistant/flight-logs/active';
/**
 * 存档间隔。最坏情况丢这么多秒的数据 —— 相对于「刷新一下全没了」是天壤之别。
 * 写得再密就会和采样抢主线程。
 */
const ACTIVE_LOG_PERSIST_INTERVAL_MS = 3_000;

/** 短于 1 分钟的记录直接丢弃（与桌面版一致） */
const MINIMUM_RECORD_DURATION_MS = 60_000;
/** 接地后需连续 2 秒在地面才判定落地完成 */
const LANDING_STABLE_DURATION_MS = 2_000;
/** 有效落地 G 值区间，超出视为数据异常 */
const MIN_VALID_LANDING_G = 0.3;
const MAX_VALID_LANDING_G = 8.0;

interface FlightLogsState {
  logs: FlightLog[];
  isLoading: boolean;
  selectedLog: FlightLog | null;
  isRecording: boolean;
  isRecordingPaused: boolean;
  activeLog: FlightLog | null;
  sampleIntervalMs: number;

  refreshLogs: () => Promise<void>;
  /**
   * 恢复上次未收尾的录制（刷新页面 / 崩溃后）。
   * 返回 true 表示接上了，此时 `isRecording` 已置位、`activeLog` 已带上此前的采样点。
   */
  recoverActiveLog: () => Promise<boolean>;
  /** 把录制中的日志立刻写盘（页面卸载前调用，补上节流窗口里的那几秒） */
  flushActiveLog: () => Promise<void>;
  setSampleIntervalMs: (milliseconds: number) => Promise<void>;
  selectLog: (log: FlightLog | null) => void;

  /** 由飞行数据 store 驱动（等价于桌面版 ChangeNotifierProxyProvider 的 update） */
  handleFlightSnapshot: (snapshot: FlightDataSnapshot) => void;
  startRecording: (snapshot: FlightDataSnapshot, flightNumber?: string) => boolean;
  stopRecording: (snapshot: FlightDataSnapshot) => Promise<boolean>;

  deleteLog: (id: string) => Promise<void>;
  saveLog: (log: FlightLog) => Promise<void>;
  exportLog: (log: FlightLog) => void;
  importLogs: (file: File) => Promise<number>;
}

/** 采样与检测过程中的可变状态（不参与渲染，放在 store 外避免无谓重绘） */
const recordingContext = {
  lastSampleAt: null as number | null,
  lastOnGround: undefined as boolean | undefined,
  stableGroundSince: null as number | null,
  touchdownPointIndexes: [] as number[],
  autoStopping: false,
  lastActiveLogPersistAt: null as number | null,
};

function resetRecordingContext(): void {
  recordingContext.lastSampleAt = null;
  recordingContext.lastOnGround = undefined;
  recordingContext.stableGroundSince = null;
  recordingContext.touchdownPointIndexes = [];
  recordingContext.lastActiveLogPersistAt = null;
}

// ──────────────────────────────────────────────────────────────────────────
// 录制中日志的崩溃恢复
// ──────────────────────────────────────────────────────────────────────────

/** 存档结构：日志本体 + 恢复时要接着用的检测上下文 */
interface ActiveLogArchive {
  log: unknown;
  touchdownPointIndexes: number[];
  lastOnGround?: boolean;
}

/** 把录制中的日志写进 IndexedDB；`force` 跳过间隔节流 */
async function persistActiveLog(log: FlightLog, force = false): Promise<void> {
  const now = Date.now();
  if (
    !force &&
    recordingContext.lastActiveLogPersistAt !== null &&
    now - recordingContext.lastActiveLogPersistAt < ACTIVE_LOG_PERSIST_INTERVAL_MS
  ) {
    return;
  }
  recordingContext.lastActiveLogPersistAt = now;
  try {
    const archive: ActiveLogArchive = {
      log: flightLogToJson(log),
      touchdownPointIndexes: [...recordingContext.touchdownPointIndexes],
      lastOnGround: recordingContext.lastOnGround,
    };
    await idbSet(ACTIVE_LOG_IDB_KEY, archive);
  } catch (e) {
    AppLogger.warning(`[FlightLogs] persist active log failed: ${String(e)}`);
  }
}

/** 清掉录制中存档（正常收尾或丢弃后调用） */
async function clearActiveLogArchive(): Promise<void> {
  try {
    await idbDel(ACTIVE_LOG_IDB_KEY);
  } catch (e) {
    AppLogger.warning(`[FlightLogs] clear active log failed: ${String(e)}`);
  }
}

/** 读回录制中存档 */
async function readActiveLogArchive(): Promise<ActiveLogArchive | null> {
  try {
    const raw = await idbGet<ActiveLogArchive>(ACTIVE_LOG_IDB_KEY);
    if (!raw || typeof raw !== 'object') return null;
    return raw;
  } catch {
    return null;
  }
}

export const useFlightLogsStore = create<FlightLogsState>((set, get) => ({
  logs: [],
  isLoading: false,
  selectedLog: null,
  isRecording: false,
  isRecordingPaused: false,
  activeLog: null,
  sampleIntervalMs: DEFAULT_SAMPLE_INTERVAL_MS,

  async refreshLogs() {
    set({ isLoading: true });
    try {
      await PersistenceService.ensureReady();

      const stored = PersistenceService.getModuleData<unknown[]>(MODULE_NAME, LOGS_KEY);
      const localLogs = Array.isArray(stored)
        ? stored
            .map((item) => toJsonMap(item))
            .filter((item): item is Record<string, unknown> => item !== null)
            .map(flightLogFromJson)
        : [];

      // 后端是共享真相源：能连上就以它为准，本地独有的条目保留待补传
      const remoteRaw = await pullRecords('flightLog');
      const logs =
        remoteRaw === null
          ? localLogs
          : mergeById(remoteRaw.map(flightLogFromJson), localLogs);
      logs.sort((a, b) => b.startTime.getTime() - a.startTime.getTime());

      const interval =
        PersistenceService.getModuleData<number>(MODULE_NAME, SAMPLE_INTERVAL_MS_KEY) ??
        DEFAULT_SAMPLE_INTERVAL_MS;

      set({ logs, sampleIntervalMs: sanitizeSampleInterval(interval), isLoading: false });
      await persistLogs(logs);

      // 后端可达时补传离线期间积压的记录
      if (remoteRaw !== null) {
        const remoteIds = new Set(remoteRaw.map((item) => toText(item.id)));
        for (const log of logs) {
          if (remoteIds.has(log.id)) continue;
          await pushRecord('flightLog', log.id, flightLogToJson(log));
        }
      }
    } catch (e) {
      AppLogger.error('[FlightLogs] refresh failed', e);
      set({ isLoading: false });
    }
  },

  async setSampleIntervalMs(milliseconds) {
    const next = sanitizeSampleInterval(milliseconds);
    set({ sampleIntervalMs: next });
    await PersistenceService.setModuleData(MODULE_NAME, SAMPLE_INTERVAL_MS_KEY, next);
  },

  async recoverActiveLog() {
    if (get().isRecording) return false;
    const archive = await readActiveLogArchive();
    if (!archive) return false;

    const raw = toJsonMap(archive.log);
    if (!raw) {
      await clearActiveLogArchive();
      return false;
    }
    const log = flightLogFromJson(raw);
    if (log.points.length === 0) {
      await clearActiveLogArchive();
      return false;
    }

    // 把检测上下文一并接回来：不接的话落地检测会以为这是一段全新的空中飞行，
    // 已经收集到的接地序列会全部作废。
    resetRecordingContext();
    recordingContext.touchdownPointIndexes = [...(archive.touchdownPointIndexes ?? [])];
    recordingContext.lastOnGround = archive.lastOnGround;
    recordingContext.lastActiveLogPersistAt = Date.now();

    set({ activeLog: log, isRecording: true, isRecordingPaused: false });
    AppLogger.info(`[FlightLogs] recovered in-progress recording: ${log.points.length} points`);
    // 接不回模拟器时，下一帧 isConnected=false 的快照会走既有的自动收尾逻辑，
    // 把这段录制正常保存下来 —— 不需要在这里另写一套收尾。
    return true;
  },

  async flushActiveLog() {
    const log = get().activeLog;
    if (!get().isRecording || !log) return;
    await persistActiveLog(log, true);
  },

  selectLog(log) {
    set({ selectedLog: log });
  },

  handleFlightSnapshot(snapshot) {
    const state = get();
    if (!state.isRecording) return;

    // 模拟器断开：自动收尾保存
    if (!snapshot.isConnected) {
      if (recordingContext.autoStopping) return;
      recordingContext.autoStopping = true;
      void get()
        .stopRecording(snapshot)
        .finally(() => {
          recordingContext.autoStopping = false;
        });
      return;
    }

    const paused = snapshot.isPaused === true;
    if (state.isRecordingPaused !== paused) set({ isRecordingPaused: paused });
    if (paused) return;

    captureSnapshot(snapshot, false, set, get);
  },

  startRecording(snapshot, flightNumber) {
    if (get().isRecording) return false;

    const now = new Date();
    const data = snapshot.flightData;
    const departure =
      normalizeText(data.departureAirport) ??
      normalizeText(snapshot.nearestAirport?.icaoCode) ??
      '--';

    const activeLog: FlightLog = {
      id: String(now.getTime()),
      aircraftTitle:
        normalizeText(snapshot.aircraftTitle) ??
        normalizeText(data.aircraftDisplayName) ??
        'Unknown',
      aircraftType: normalizeText(data.aircraftIcao) ?? normalizeText(data.aircraftModel),
      simulatorLabel: simulatorLabel(snapshot.simulatorType),
      flightNumber: normalizeText(flightNumber),
      departureAirport: departure,
      arrivalAirport:
        normalizeText(data.arrivalAirport) ??
        normalizeText(snapshot.destinationAirport?.icaoCode) ??
        departure,
      startTime: now,
      points: [],
      maxG: 1,
      minG: 1,
      maxAltitude: 0,
      maxAirspeed: 0,
      maxGroundSpeed: 0,
      wasOnGroundAtStart: data.onGround ?? false,
      wasOnGroundAtEnd: false,
    };

    resetRecordingContext();
    set({
      activeLog,
      isRecording: true,
      isRecordingPaused: snapshot.isPaused === true,
    });
    void persistActiveLog(activeLog, true);
    captureSnapshot(snapshot, true, set, get);
    return true;
  },

  async stopRecording(snapshot) {
    const state = get();
    if (!state.isRecording || !state.activeLog) return false;

    if (snapshot.isConnected) captureSnapshot(snapshot, true, set, get);

    const log = get().activeLog;
    if (!log) return false;

    log.endTime = new Date();
    log.wasOnGroundAtEnd = snapshot.flightData.onGround ?? false;
    finalizeLandingAtStop(log);

    // 空记录或过短记录直接丢弃
    if (log.points.length === 0 || flightLogDurationMs(log) < MINIMUM_RECORD_DURATION_MS) {
      resetRecordingContext();
      await clearActiveLogArchive();
      set({ isRecording: false, isRecordingPaused: false, activeLog: null });
      AppLogger.info('[FlightLogs] recording discarded (too short)');
      return false;
    }

    updateFuelUsed(log);
    // 派生指标要在全部采样点都到齐之后才算得出来（抬轮、35ft 俯仰、稳定性
    // 都要看事件前后的一整段），所以放在收尾这一步而不是采样时。
    await enrichTakeoffLandingMetrics(log);
    await get().saveLog(log);
    resetRecordingContext();
    // 正式记录已落库，存档使命结束；先存后清，中间崩了也只是多留一份存档
    await clearActiveLogArchive();
    set({ isRecording: false, isRecordingPaused: false, activeLog: null });
    await get().refreshLogs();
    return true;
  },

  async saveLog(log) {
    const existing = get().logs.filter((item) => item.id !== log.id);
    const next = [log, ...existing].sort(
      (a, b) => b.startTime.getTime() - a.startTime.getTime(),
    );
    set({ logs: next });
    // 本地先落盘保证不丢，再推后端；后端不可达时下次 refreshLogs 会补传
    await persistLogs(next);
    await pushRecord('flightLog', log.id, flightLogToJson(log));
  },

  async deleteLog(id) {
    const next = get().logs.filter((log) => log.id !== id);
    set({
      logs: next,
      selectedLog: get().selectedLog?.id === id ? null : get().selectedLog,
    });
    await persistLogs(next);
    await removeRecord('flightLog', id);
  },

  exportLog(log) {
    const payload = JSON.stringify(flightLogToJson(log), null, 2);
    const blob = new Blob([payload], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = `flight_log_${log.id}.json`;
    anchor.click();
    URL.revokeObjectURL(url);
  },

  async importLogs(file) {
    const text = await file.text();
    const decoded: unknown = JSON.parse(text);
    // 支持单条对象与数组两种格式（与桌面版 _parseLogs 一致）
    const rawLogs = Array.isArray(decoded) ? decoded : [decoded];
    const imported = rawLogs
      .map((item) => toJsonMap(item))
      .filter((item): item is Record<string, unknown> => item !== null)
      .map(flightLogFromJson);

    if (imported.length === 0) return 0;

    const byId = new Map(get().logs.map((log) => [log.id, log]));
    for (const log of imported) byId.set(log.id, log);
    const next = [...byId.values()].sort(
      (a, b) => b.startTime.getTime() - a.startTime.getTime(),
    );
    set({ logs: next });
    await persistLogs(next);
    // 导入的记录同样落到后端，保证「本地文件 → 前端 → 后端」链路完整
    for (const log of imported) {
      await pushRecord('flightLog', log.id, flightLogToJson(log));
    }
    return imported.length;
  },
}));

// ──────────────────────────────────────────────────────────────────────────
// 采样
// ──────────────────────────────────────────────────────────────────────────

type SetState = (partial: Partial<FlightLogsState>) => void;
type GetState = () => FlightLogsState;

/** 捕获一帧飞行数据为采样点（对应桌面版 captureSnapshot） */
function captureSnapshot(
  snapshot: FlightDataSnapshot,
  force: boolean,
  set: SetState,
  get: GetState,
): void {
  const state = get();
  if (!state.isRecording || !state.activeLog) return;
  if (!force && state.isRecordingPaused) return;

  const now = Date.now();
  // 采样节流：非强制帧需满足最小采样间隔
  if (
    !force &&
    recordingContext.lastSampleAt !== null &&
    now - recordingContext.lastSampleAt < state.sampleIntervalMs
  ) {
    return;
  }

  const data = snapshot.flightData;
  const resolvedG = resolveSnapshotPointG(data);

  const point: FlightLogPoint = {
    latitude: data.latitude ?? 0,
    longitude: data.longitude ?? 0,
    altitude: data.altitude ?? 0,
    airspeed: data.airspeed ?? 0,
    groundSpeed: data.groundSpeed ?? data.airspeed ?? 0,
    verticalSpeed: data.verticalSpeed ?? 0,
    heading: data.heading ?? 0,
    pitch: data.pitch ?? 0,
    roll: data.bank ?? 0,
    angleOfAttack: data.angleOfAttack,
    gForce: resolvedG.value,
    gForcePeak: resolveSnapshotPointGPeak(data),
    gForceSource: resolvedG.source,
    fuelQuantity: data.fuelQuantity ?? 0,
    fuelFlow: data.fuelFlow,
    timestamp: new Date(now),
    autopilotEngaged: data.autopilotEngaged,
    autothrottleEngaged: data.autothrottleEngaged,
    flightPhase: data.flightPhase,
    autopilotHeadingTarget: data.autopilotHeadingTarget,
    autopilotLateralMode: data.autopilotLateralMode,
    autopilotVerticalMode: data.autopilotVerticalMode,
    gearDown: data.gearDown,
    touchdownGearG: data.touchdownGearG,
    noseGearG: data.noseGearG,
    leftGearG: data.leftGearG,
    rightGearG: data.rightGearG,
    flapsLabel: data.flapsLabel,
    windSpeed: data.windSpeed,
    windDirection: data.windDirection,
    windGust: data.windGust,
    gustDelta: data.gustDelta,
    gustFactorRate: data.gustFactorRate,
    crosswindComponent: data.crosswindComponent,
    radioAltitude: data.radioAltitude,
    outsideAirTemperature: data.outsideAirTemperature,
    baroPressure: data.baroPressure,
    masterWarning: data.masterWarning,
    masterCaution: data.masterCaution,
    engine1Running: data.engine1Running,
    engine2Running: data.engine2Running,
    engine1N1: data.engine1N1,
    engine2N1: data.engine2N1,
    engine1N2: data.engine1N2,
    engine2N2: data.engine2N2,
    engine1Egt: data.engine1EGT,
    engine2Egt: data.engine2EGT,
    transponderCode: snapshot.transponderCode,
    landingLights: data.landingLights,
    beacon: data.beacon,
    strobes: data.strobes,
    aileronInput: data.aileronInput,
    elevatorInput: data.elevatorInput,
    rudderInput: data.rudderInput,
    aileronTrim: data.aileronTrim,
    elevatorTrim: data.elevatorTrim,
    rudderTrim: data.rudderTrim,
    onGround: data.onGround,
    anomalyAlerts: buildPointAlerts(data.flightAlerts),
  };

  const log = state.activeLog;
  log.points.push(point);
  log.endTime = new Date(now);
  log.maxAltitude = Math.max(log.maxAltitude, point.altitude);
  log.maxAirspeed = Math.max(log.maxAirspeed, point.airspeed);
  log.maxGroundSpeed = Math.max(log.maxGroundSpeed, point.groundSpeed);
  /*
   * G 的极值用第一个采样点开张，不能拿建档时写死的 1 去比。
   *
   * 那个 1 是「静止时的过载」，拿它当种子等于给极值预置了一个假样本：
   * 全程都在 1.05 以上的飞行，最小 G 仍会报 1.00；全程都在 1 以下的
   * 平飞下降，最大 G 也仍是 1.00。两个数看着都正常，其实都不是真的极值。
   */
  if (log.points.length === 1) {
    log.maxG = point.gForce;
    log.minG = point.gForce;
  } else {
    log.maxG = Math.max(log.maxG, point.gForce);
    log.minG = Math.min(log.minG, point.gForce);
  }
  updateFuelUsed(log);

  const onGround = point.onGround ?? false;

  // 离地瞬间记录起飞数据
  if (recordingContext.lastOnGround === true && !onGround && !log.takeoffData) {
    log.takeoffData = {
      latitude: point.latitude,
      longitude: point.longitude,
      airspeed: point.airspeed,
      groundSpeed: point.groundSpeed,
      verticalSpeed: point.verticalSpeed,
      pitch: point.pitch,
      heading: point.heading,
      timestamp: point.timestamp,
      runway: runwayIdentFromHeading(point.heading),
      crosswindAtLiftoffKt: point.crosswindComponent,
    };
  }

  trackLandingState(log, onGround, now);
  recordingContext.lastOnGround = onGround;
  recordingContext.lastSampleAt = now;

  // 增量落盘（内部按 3 秒节流）：刷新页面时最多丢这几秒，而不是整段录制
  void persistActiveLog(log);

  // 触发订阅者更新（activeLog 为同一引用，故用计数字段驱动）
  set({ activeLog: { ...log } });
}

/**
 * 落地检测
 *
 * 空中 → 地面的翻转记为一次接地，收集接地序列的 G 值；
 * 连续在地面超过 2 秒后定稿落地数据（覆盖弹跳场景）。
 */
function trackLandingState(log: FlightLog, onGround: boolean, now: number): void {
  const wasOnGround = recordingContext.lastOnGround;

  if (!onGround) {
    // 重新离地（弹跳），重置稳定计时
    recordingContext.stableGroundSince = null;
    return;
  }

  if (wasOnGround === false) {
    // 空中 → 地面：记录接地点
    recordingContext.touchdownPointIndexes.push(log.points.length - 1);
    recordingContext.stableGroundSince = now;
  } else if (recordingContext.stableGroundSince === null) {
    recordingContext.stableGroundSince = now;
  }

  if (
    recordingContext.stableGroundSince !== null &&
    now - recordingContext.stableGroundSince >= LANDING_STABLE_DURATION_MS &&
    recordingContext.touchdownPointIndexes.length > 0
  ) {
    updateLandingDataFromTouchdowns(log);
  }
}

/** 由接地序列汇总落地数据与评级 */
function updateLandingDataFromTouchdowns(log: FlightLog): void {
  const indexes = recordingContext.touchdownPointIndexes;
  if (indexes.length === 0) return;

  const sequence = indexes
    .map((index) => log.points[index])
    .filter((item): item is FlightLogPoint => item !== undefined);
  if (sequence.length === 0) return;

  /*
   * 每次接地都在**触地之后**的窗口里取 G 峰值，而不是读触地那一个采样点。
   *
   * 触地瞬间减震支柱还没压缩，机身过载仍接近 1；峰值要晚 100–300ms 才出现。
   * 原来只读翻转点，于是无论落得多重都只报 1.0 出头（模拟器自报 3.36，
   * 这里显示 1.12）。取窗口极值才是真正砸下去的那一下。
   */
  const gForces = indexes
    .map((index) =>
      peakTouchdownG(log.points, index, {
        minValidG: MIN_VALID_LANDING_G,
        maxValidG: MAX_VALID_LANDING_G,
      }),
    )
    .filter((value): value is number => value !== undefined);

  const primary = sequence[0];
  // 取接地序列中的峰值 G 作为落地评级依据
  const peakG = gForces.length > 0 ? Math.max(...gForces) : primary.gForce;

  // 下沉率反过来要往前看：翻转点的垂速已经被起落架吃掉一截
  const touchdownSink = touchdownSinkRateFpm(log.points, indexes[0]);

  log.landingData = {
    latitude: primary.latitude,
    longitude: primary.longitude,
    gForce: peakG,
    gForceSource: primary.gForceSource,
    verticalSpeed: touchdownSink ?? primary.verticalSpeed,
    airspeed: primary.airspeed,
    groundSpeed: primary.groundSpeed,
    pitch: primary.pitch,
    roll: primary.roll,
    rating: resolveLandingRating(peakG),
    timestamp: primary.timestamp,
    touchdownSequence: sequence,
    touchdownGForces: gForces,
    runway: runwayIdentFromHeading(primary.heading),
    crosswindAtTouchdownKt: primary.crosswindComponent,
    // 首次接地之后的额外接地次数即为弹跳次数
    bounceCount: Math.max(0, sequence.length - 1),
    sinkRateAt50FtFpm: findSinkRateAt50Ft(log.points, primary.timestamp),
    /*
     * 拉平高度要在接地**之前**找，不能读 latestPoint —— 那是「连续在地 2 秒」
     * 之后定稿时的采样点，飞机早停在跑道上了，无线电高度恒为 0。
     * 界面上「拉平高度 0 ft」就是这么来的。
     */
    flareHeightFt: flareHeightFt(log.points, indexes[0]),
  };
}

/**
 * 收尾时补齐起飞/落地的派生指标。
 *
 * 剩余跑道要按坐标反查跑道几何（一次网络往返），拿不到就让该项保持不可用
 * 并记下原因 —— 这一步失败不能影响日志本身落库。
 */
async function enrichTakeoffLandingMetrics(log: FlightLog): Promise<void> {
  try {
    const takeoff = log.takeoffData;
    if (takeoff) {
      const runway = await lookupRunwayAt(log.departureAirport, {
        latitude: takeoff.latitude,
        longitude: takeoff.longitude,
      });
      const metrics = computeTakeoffMetrics(log, runway);
      takeoff.rotationSpeedKt = metrics.rotationSpeedKt;
      takeoff.rotationToLiftoffSec = metrics.rotationToLiftoffSec;
      takeoff.pitchAt35FtDeg = metrics.pitchAt35FtDeg;
      takeoff.takeoffStabilityScore = metrics.takeoffStabilityScore;
      takeoff.remainingRunwayFt = metrics.remainingRunwayFt;
      takeoff.metricNotes = Object.keys(metrics.unavailable).length > 0
        ? { ...metrics.unavailable }
        : undefined;
    }

    const landing = log.landingData;
    if (landing) {
      const runway = await lookupRunwayAt(log.arrivalAirport, {
        latitude: landing.latitude,
        longitude: landing.longitude,
      });
      const metrics = computeLandingMetrics(log, runway);
      landing.approachStabilityScore = metrics.approachStabilityScore;
      landing.remainingRunwayFt = metrics.remainingRunwayFt;
      landing.metricNotes = Object.keys(metrics.unavailable).length > 0
        ? { ...metrics.unavailable }
        : undefined;
    }
  } catch (e) {
    AppLogger.warning(`[FlightLogs] enrich metrics failed: ${String(e)}`);
  }
}

/** 停止记录时若仍有未定稿的接地序列，补一次落地汇总 */
function finalizeLandingAtStop(log: FlightLog): void {
  if (log.landingData) return;
  if (recordingContext.touchdownPointIndexes.length === 0) return;
  if (log.points.length === 0) return;
  updateLandingDataFromTouchdowns(log);
}

/** 回溯接地前最后一次无线电高度 ≈ 50ft 时的下降率 */
function findSinkRateAt50Ft(points: FlightLogPoint[], touchdownAt: Date): number | undefined {
  for (let i = points.length - 1; i >= 0; i--) {
    const point = points[i];
    if (point.timestamp.getTime() > touchdownAt.getTime()) continue;
    const radioAltitude = point.radioAltitude;
    if (radioAltitude === undefined) continue;
    if (radioAltitude >= 40 && radioAltitude <= 60) return point.verticalSpeed;
    if (radioAltitude > 200) break;
  }
  return undefined;
}

/**
 * 解析采样点 G 值
 * 优先使用起落架传感器读数，其次机身 G，最后回退为 1.0
 */
function resolveSnapshotPointG(data: {
  touchdownGearG?: number;
  noseGearG?: number;
  leftGearG?: number;
  rightGearG?: number;
  gForce?: number;
}): { value: number; source: LandingGSource } {
  const gearValues = [data.touchdownGearG, data.leftGearG, data.rightGearG, data.noseGearG]
    .filter((value): value is number => value !== undefined && Number.isFinite(value))
    .filter((value) => value >= MIN_VALID_LANDING_G && value <= MAX_VALID_LANDING_G);

  if (gearValues.length > 0) {
    return { value: Math.max(...gearValues), source: 'gear' };
  }
  if (data.gForce !== undefined && Number.isFinite(data.gForce)) {
    return { value: data.gForce, source: 'body' };
  }
  return { value: 1, source: 'fallback' };
}

/**
 * 解析采样点的过载**窗口峰值**（中间件下发的 `*_peak` 字段）。
 *
 * 与瞬时值同样优先起落架读数：机身 G 在软着陆时被机身姿态摊薄，
 * 起落架传感器才是真正吃到冲击的那个。两者都没有就返回 undefined，
 * 调用方退回瞬时值 —— 老中间件、MSFS 都走这条路。
 */
function resolveSnapshotPointGPeak(data: {
  touchdownGearGPeak?: number;
  gForcePeak?: number;
}): number | undefined {
  for (const value of [data.touchdownGearGPeak, data.gForcePeak]) {
    if (value === undefined || !Number.isFinite(value)) continue;
    if (value < MIN_VALID_LANDING_G || value > MAX_VALID_LANDING_G) continue;
    return value;
  }
  return undefined;
}

/** 燃油消耗 = 首个采样点油量 − 当前油量 */
function updateFuelUsed(log: FlightLog): void {
  if (log.points.length < 2) return;
  const first = log.points[0].fuelQuantity;
  const last = log.points[log.points.length - 1].fuelQuantity;
  const used = first - last;
  log.totalFuelUsed = used > 0 ? used : 0;
}

/** 把后端下发的飞行告警映射为日志点告警 */
function buildPointAlerts(
  alerts: { id: string; level: string; message: string }[],
): FlightLogAlert[] {
  return alerts.map((alert) => ({
    id: alert.id,
    level:
      alert.level.toLowerCase() === 'danger'
        ? 'danger'
        : alert.level.toLowerCase() === 'warning'
          ? 'warning'
          : 'caution',
    message: alert.message,
  }));
}

/** 由航向推导跑道编号（四舍五入到十位，01–36） */
function runwayIdentFromHeading(heading: number): string {
  const normalized = ((heading % 360) + 360) % 360;
  const number = Math.round(normalized / 10);
  const ident = number === 0 ? 36 : number;
  return String(ident).padStart(2, '0');
}

function simulatorLabel(type: SimulatorType): string | undefined {
  if (type === 'msfs') return 'MSFS';
  if (type === 'xplane') return 'X-Plane';
  return undefined;
}

function normalizeText(value: string | undefined | null): string | undefined {
  const text = value?.trim();
  return text && text.length > 0 ? text : undefined;
}

function sanitizeSampleInterval(value: number): number {
  if (value < MIN_SAMPLE_INTERVAL_MS) return MIN_SAMPLE_INTERVAL_MS;
  if (value > MAX_SAMPLE_INTERVAL_MS) return MAX_SAMPLE_INTERVAL_MS;
  return value;
}

async function persistLogs(logs: FlightLog[]): Promise<void> {
  await PersistenceService.setModuleData(
    MODULE_NAME,
    LOGS_KEY,
    logs.map(flightLogToJson),
  );
}
