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
  buildLandingDataFromTouchdowns,
  computeLandingMetrics,
  computeTakeoffMetrics,
  hasElapsedAtLeast,
  isTouchdownTransition,
  MAX_VALID_LANDING_G,
  MIN_VALID_LANDING_G,
} from '../services/takeoff-landing-metrics';
import {
  flightLogFromJson,
  flightLogStatusForEndReason,
  flightLogToJson,
  type FlightLog,
  type FlightLogAlert,
  type FlightLogPoint,
  type LandingGSource,
} from '../models/flight-log-models';
import type { RecordingEndReason } from '../models/recording-status';

/**
 * 飞行日志 store
 *
 * 对应 Flutter 版 `modules/flight_logs/providers/flight_logs_provider.dart`（1356 行）。
 * 保留桌面版的采样节流、起飞/落地检测与燃油统计。
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

/** 接地后需连续 2 秒在地面才判定落地完成 */
const LANDING_STABLE_DURATION_MS = 2_000;

export interface FlightLogsState {
  logs: FlightLog[];
  isLoading: boolean;
  selectedLog: FlightLog | null;
  isRecording: boolean;
  isRecordingPaused: boolean;
  activeLog: FlightLog | null;
  hasActiveWork: boolean;
  sampleIntervalMs: number;

  refreshLogs: () => Promise<void>;
  /**
   * 兼容旧调用方：恢复存档会收尾为 page_closed，不会继续录制。
   */
  recoverActiveLog: () => Promise<boolean>;
  /** 把启动时发现的孤儿存档收尾为 page_closed */
  recoverInterruptedLog: () => Promise<boolean>;
  /** 把录制中的日志立刻写盘（页面卸载前调用，补上节流窗口里的那几秒） */
  flushActiveLog: () => Promise<void>;
  setSampleIntervalMs: (milliseconds: number) => Promise<void>;
  selectLog: (log: FlightLog | null) => void;

  /** 由飞行数据 store 驱动（等价于桌面版 ChangeNotifierProxyProvider 的 update） */
  handleFlightSnapshot: (snapshot: FlightDataSnapshot) => void;
  handleDisconnect: () => Promise<boolean>;
  startRecording: (snapshot: FlightDataSnapshot, flightNumber?: string) => boolean;
  stopRecording: (
    snapshot: FlightDataSnapshot,
    reason?: RecordingEndReason,
  ) => Promise<boolean>;

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
  lastActiveLogPersistAt: null as number | null,
};

/** Serialized persistence mutations plus exclusive lifecycle operations. */
let persistenceOperations: Promise<void> = Promise.resolve();
let terminalOperation: Promise<boolean> | null = null;
let recoveryOperation: Promise<boolean> | null = null;
let activeArchiveWrites: Promise<void> = Promise.resolve();
let hasUnresolvedActiveArchive = false;

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
  /** Missing on legacy archives; terminal checkpoints are explicit going forward. */
  lifecycle?: 'recording' | 'terminal';
  log: unknown;
  touchdownPointIndexes: number[];
  lastOnGround?: boolean;
}

/** 把录制中的日志写进 IndexedDB；`force` 跳过间隔节流 */
async function persistActiveLog(
  log: FlightLog,
  force = false,
  strict = false,
  lifecycle: ActiveLogArchive['lifecycle'] = 'recording',
): Promise<void> {
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
      lifecycle,
      log: flightLogToJson(log),
      touchdownPointIndexes: [...recordingContext.touchdownPointIndexes],
      lastOnGround: recordingContext.lastOnGround,
    };
    const write = activeArchiveWrites.then(() => idbSet(ACTIVE_LOG_IDB_KEY, archive));
    activeArchiveWrites = write.catch(() => undefined);
    await write;
  } catch (e) {
    AppLogger.warning(`[FlightLogs] persist active log failed: ${String(e)}`);
    if (strict) throw e;
  }
}

/** 清掉录制中存档（正常收尾或丢弃后调用） */
async function clearActiveLogArchive(): Promise<void> {
  try {
    await activeArchiveWrites;
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
  hasActiveWork: false,
  sampleIntervalMs: DEFAULT_SAMPLE_INTERVAL_MS,

  refreshLogs() {
    return enqueuePersistenceOperation(() => refreshLogsNow(set));
  },

  async setSampleIntervalMs(milliseconds) {
    const next = sanitizeSampleInterval(milliseconds);
    set({ sampleIntervalMs: next });
    await PersistenceService.setModuleData(MODULE_NAME, SAMPLE_INTERVAL_MS_KEY, next);
  },

  async recoverActiveLog() {
    return get().recoverInterruptedLog();
  },

  recoverInterruptedLog() {
    return beginInterruptedRecovery(set, get);
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
      void get().handleDisconnect();
      return;
    }

    const paused = snapshot.isPaused === true;
    if (state.isRecordingPaused !== paused) set({ isRecordingPaused: paused });
    if (paused) return;

    captureSnapshot(snapshot, false, set, get);
  },

  startRecording(snapshot, flightNumber) {
    if (
      get().isRecording ||
      get().hasActiveWork ||
      terminalOperation !== null ||
      recoveryOperation !== null ||
      hasUnresolvedActiveArchive
    ) {
      return false;
    }

    const now = new Date();
    const data = snapshot.flightData;
    const departure =
      normalizeText(data.departureAirport) ??
      normalizeText(snapshot.nearestAirport?.icaoCode) ??
      '--';

    const activeLog: FlightLog = {
      id: crypto.randomUUID(),
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
      status: 'incomplete',
      endReason: 'interrupted',
    };

    resetRecordingContext();
    set({
      activeLog,
      isRecording: true,
      isRecordingPaused: snapshot.isPaused === true,
      hasActiveWork: false,
    });
    // 先采样再写首份存档，否则 3 秒节流窗口内只会留下空存档。
    captureSnapshot(snapshot, true, set, get);
    return true;
  },

  async handleDisconnect() {
    return finalizeActiveRecording(
      undefined,
      'simulator_disconnected',
      set,
      get,
    );
  },

  async stopRecording(snapshot, reason = 'user_stopped') {
    return finalizeActiveRecording(snapshot, reason, set, get);
  },

  saveLog(log) {
    return enqueuePersistenceOperation(() => saveLogDurably(log, set, get));
  },

  deleteLog(id) {
    return enqueuePersistenceOperation(() => deleteLogNow(id, set, get));
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

    return enqueuePersistenceOperation(() => importLogsNow(imported, set, get));
  },
}));

function enqueuePersistenceOperation<T>(operation: () => Promise<T>): Promise<T> {
  const result = persistenceOperations.then(operation, operation);
  persistenceOperations = result.then(
    () => undefined,
    () => undefined,
  );
  return result;
}

async function refreshLogsNow(set: SetState): Promise<void> {
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
}

function beginInterruptedRecovery(set: SetState, get: GetState): Promise<boolean> {
  if (
    recoveryOperation !== null ||
    terminalOperation !== null ||
    get().isRecording ||
    get().hasActiveWork
  ) {
    return Promise.resolve(false);
  }

  const operation = enqueuePersistenceOperation(() => recoverInterruptedLogNow(set, get));
  const tracked = operation.finally(() => {
    if (recoveryOperation === tracked) recoveryOperation = null;
  });
  recoveryOperation = tracked;
  return tracked;
}

async function recoverInterruptedLogNow(set: SetState, get: GetState): Promise<boolean> {
  if (get().isRecording || get().hasActiveWork || terminalOperation !== null) return false;
  const archive = await readActiveLogArchive();
  if (!archive) {
    hasUnresolvedActiveArchive = false;
    return false;
  }

  const raw = toJsonMap(archive.log);
  if (!raw) {
    await clearActiveLogArchive();
    hasUnresolvedActiveArchive = false;
    return false;
  }
  const log = flightLogFromJson(raw);
  if (log.points.length === 0) {
    await clearActiveLogArchive();
    hasUnresolvedActiveArchive = false;
    return false;
  }
  // 从这一刻起，除非恢复记录已可靠落库，否则禁止新录制覆盖同一个存档键。
  hasUnresolvedActiveArchive = true;

  const terminalCheckpoint = isTerminalArchiveCheckpoint(archive, log);
  const recoveryEndTime = terminalCheckpoint
    ? log.endTime!
    : interruptedRecoveryEndTime(log);
  const durableLogs = await readDurableFlightLogs();
  const durableWinner = durableLogs.find(
    (item) =>
      item.id === log.id &&
      item.endTime !== undefined &&
      item.endTime.getTime() >= recoveryEndTime.getTime(),
  );
  if (durableWinner) {
    const logs = mergeById(durableLogs, get().logs).sort(
      (a, b) => b.startTime.getTime() - a.startTime.getTime(),
    );
    await clearActiveLogArchive();
    hasUnresolvedActiveArchive = false;
    resetRecordingContext();
    set({
      logs,
      activeLog: null,
      isRecording: false,
      isRecordingPaused: false,
      hasActiveWork: false,
    });
    syncLogInBackground(durableWinner);
    AppLogger.info(`[FlightLogs] cleared stale finalized archive: ${log.id}`);
    return true;
  }

  // 恢复检测上下文只为了补齐已存档的落地汇总；
  // 孤儿存档不重新进入录制态。
  resetRecordingContext();
  recordingContext.touchdownPointIndexes = [...(archive.touchdownPointIndexes ?? [])];
  recordingContext.lastOnGround = archive.lastOnGround;

  if (!terminalCheckpoint) {
    const lastPoint = log.points[log.points.length - 1];
    log.endTime = recoveryEndTime;
    log.wasOnGroundAtEnd = lastPoint.onGround ?? log.wasOnGroundAtEnd;
    log.status = flightLogStatusForEndReason('page_closed');
    log.endReason = 'page_closed';
  }
  finalizeLandingAtStop(log);
  updateFuelUsed(log);
  await enrichTakeoffLandingMetrics(log);
  await saveLogDurably(log, set, get);

  resetRecordingContext();
  await clearActiveLogArchive();
  hasUnresolvedActiveArchive = false;
  set({
    activeLog: null,
    isRecording: false,
    isRecordingPaused: false,
    hasActiveWork: false,
  });
  AppLogger.info(`[FlightLogs] finalized interrupted recording: ${log.points.length} points`);
  return true;
}

function isTerminalArchiveCheckpoint(archive: ActiveLogArchive, log: FlightLog): boolean {
  if (archive.lifecycle === 'terminal') return true;
  if (archive.lifecycle === 'recording') return false;
  // Round-1/legacy archives have no marker. Their live checkpoints updated
  // `endTime` on every capture but kept `interrupted`, so that reason remains
  // the compatibility signal for an in-progress archive.
  return (
    log.endTime !== undefined &&
    log.endReason !== undefined &&
    log.endReason !== 'interrupted'
  );
}

function interruptedRecoveryEndTime(log: FlightLog): Date {
  const lastSampleTime = log.points[log.points.length - 1].timestamp.getTime();
  const archivedEndTime = log.endTime?.getTime();
  return new Date(
    archivedEndTime === undefined
      ? lastSampleTime
      : Math.max(archivedEndTime, lastSampleTime),
  );
}

async function readDurableFlightLogs(): Promise<FlightLog[]> {
  const stored = await PersistenceService.getDurableModuleData<unknown[]>(
    MODULE_NAME,
    LOGS_KEY,
  );
  if (!Array.isArray(stored)) return [];
  return stored
    .map((item) => toJsonMap(item))
    .filter((item): item is Record<string, unknown> => item !== null)
    .map(flightLogFromJson);
}

async function deleteLogNow(id: string, set: SetState, get: GetState): Promise<void> {
  const next = get().logs.filter((log) => log.id !== id);
  set({
    logs: next,
    selectedLog: get().selectedLog?.id === id ? null : get().selectedLog,
  });
  await persistLogs(next);
  await removeRecord('flightLog', id);
}

async function importLogsNow(
  imported: FlightLog[],
  set: SetState,
  get: GetState,
): Promise<number> {
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
}

async function saveLogDurably(log: FlightLog, set: SetState, get: GetState): Promise<void> {
  const existing = get().logs.filter((item) => item.id !== log.id);
  const next = [log, ...existing].sort(
    (a, b) => b.startTime.getTime() - a.startTime.getTime(),
  );
  set({ logs: next });
  // 本地先落盘保证不丢；同步不得延迟清理终态存档或解锁下一次录制。
  await persistLogsDurably(next);
  syncLogInBackground(log);
}

function syncLogInBackground(log: FlightLog): void {
  void pushRecord('flightLog', log.id, flightLogToJson(log)).catch((error: unknown) => {
    AppLogger.warning(`[FlightLogs] background sync failed for ${log.id}: ${String(error)}`);
  });
}

function finalizeActiveRecording(
  snapshot: FlightDataSnapshot | undefined,
  reason: RecordingEndReason,
  set: SetState,
  get: GetState,
): Promise<boolean> {
  if (terminalOperation !== null || recoveryOperation !== null) return Promise.resolve(false);
  const state = get();
  if (!state.activeLog || (!state.isRecording && !state.hasActiveWork)) {
    return Promise.resolve(false);
  }

  const isFirstTerminalAttempt = state.isRecording;
  if (isFirstTerminalAttempt && snapshot?.isConnected) {
    captureSnapshot(snapshot, true, set, get);
  }

  const log = get().activeLog;
  if (!log) return Promise.resolve(false);

  if (isFirstTerminalAttempt) {
    log.endTime = new Date();
    const lastPoint = log.points[log.points.length - 1];
    log.wasOnGroundAtEnd =
      snapshot?.flightData.onGround ?? lastPoint?.onGround ?? log.wasOnGroundAtEnd;
    log.status = flightLogStatusForEndReason(reason);
    log.endReason = reason;
    finalizeLandingAtStop(log);
    updateFuelUsed(log);
  }

  // 终态在第一个 await 之前就对采样端可见，禁止新采样与竞争收尾。
  set({
    isRecording: false,
    isRecordingPaused: false,
    activeLog: { ...log },
    hasActiveWork: log.points.length > 0,
  });

  // 只有真正的空记录可以丢弃；一个有效采样点就是可恢复的用户数据。
  if (log.points.length === 0) {
    return trackTerminalOperation(clearEmptyRecording(set));
  }

  return trackTerminalOperation(completeTerminalRecording(log, set, get));
}

function trackTerminalOperation(operation: Promise<boolean>): Promise<boolean> {
  const tracked = operation.finally(() => {
    if (terminalOperation === tracked) terminalOperation = null;
  });
  terminalOperation = tracked;
  return tracked;
}

async function clearEmptyRecording(set: SetState): Promise<boolean> {
  resetRecordingContext();
  await clearActiveLogArchive();
  set({
    isRecording: false,
    isRecordingPaused: false,
    activeLog: null,
    hasActiveWork: false,
  });
  AppLogger.info('[FlightLogs] empty recording discarded');
  return false;
}

async function completeTerminalRecording(
  log: FlightLog,
  set: SetState,
  get: GetState,
): Promise<boolean> {
  // 把最终采样、结束时间和原因强制落进恢复存档，再开始任何慢指标查询。
  await persistActiveLog(log, true, true, 'terminal');
  // 派生指标要在全部采样点都到齐之后才算得出来（抬轮、35ft 俯仰、稳定性
  // 都要看事件前后的一整段），所以放在收尾这一步而不是采样时。
  await enrichTakeoffLandingMetrics(log);
  return enqueuePersistenceOperation(async () => {
    await saveLogDurably(log, set, get);
    resetRecordingContext();
    // 正式记录已落库，存档使命结束；先存后清，中间崩了也只是多留一份存档
    await clearActiveLogArchive();
    set({
      isRecording: false,
      isRecordingPaused: false,
      activeLog: null,
      hasActiveWork: false,
    });
    return true;
  });
}

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
    autoBrakeLabel: data.autoBrakeLabel,
    windSpeed: data.windSpeed,
    windDirection: data.windDirection,
    windGust: data.windGust,
    gustDelta: data.gustDelta,
    gustFactorRate: data.gustFactorRate,
    crosswindComponent: data.crosswindComponent,
    radioAltitude: data.radioAltitude,
    radioAltitudeSource: data.radioAltitudeSource,
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

  if (recordingContext.lastOnGround === false && onGround) {
    updateArrivalAirportAtTouchdown(log, snapshot);
  }

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
  set({ activeLog: { ...log }, hasActiveWork: true });
}

function updateArrivalAirportAtTouchdown(
  log: FlightLog,
  snapshot: FlightDataSnapshot,
): void {
  const airport = normalizeText(snapshot.nearestAirport?.icaoCode);
  if (airport?.length === 4) {
    log.arrivalAirport = airport.toUpperCase();
  }
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

  if (isTouchdownTransition(wasOnGround, onGround)) {
    // 空中 → 地面：记录接地点
    recordingContext.touchdownPointIndexes.push(log.points.length - 1);
    recordingContext.stableGroundSince = now;
  } else if (recordingContext.stableGroundSince === null) {
    recordingContext.stableGroundSince = now;
  }

  if (
    hasElapsedAtLeast(
      recordingContext.stableGroundSince ?? undefined,
      now,
      LANDING_STABLE_DURATION_MS,
    ) &&
    recordingContext.touchdownPointIndexes.length > 0
  ) {
    updateLandingDataFromTouchdowns(log);
  }
}

/** 由接地序列汇总落地数据与评级 */
function updateLandingDataFromTouchdowns(log: FlightLog): void {
  const landing = buildLandingDataFromTouchdowns(
    log.points,
    recordingContext.touchdownPointIndexes,
  );
  if (!landing) return;
  landing.runway = runwayIdentFromHeading(landing.touchdownSequence[0].heading);
  log.landingData = landing;
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

async function persistLogsDurably(logs: FlightLog[]): Promise<void> {
  await PersistenceService.setModuleDataDurable(
    MODULE_NAME,
    LOGS_KEY,
    logs.map(flightLogToJson),
  );
}
