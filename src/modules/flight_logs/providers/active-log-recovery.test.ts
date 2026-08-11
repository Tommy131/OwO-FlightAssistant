import { del as idbDel, get as idbGet, set as idbSet } from 'idb-keyval';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { FlightDataSnapshot } from '../../common/models/common-models';
import { emptyFlightDataSnapshot } from '../../common/models/common-models';
import {
  flightLogToJson,
  type FlightLog,
  type FlightLogPoint,
} from '../models/flight-log-models';
import { useFlightLogsStore } from './flight-logs-store';

/**
 * 录制中日志的崩溃恢复
 *
 * 这是 A 项里真正要命的那一半：刷新页面前，录制中的日志只活在内存里，
 * `stopRecording` 才落盘 —— 刷新一下，整段录制凭空消失。
 *
 * 用内存版 idb-keyval 打桩：真实 IndexedDB 在 node 环境下不存在，
 * 而这几条要验的是**恢复逻辑**，不是 IndexedDB 本身。
 */

const ACTIVE_LOG_IDB_KEY = 'owo-flight-assistant/flight-logs/active';

const store = new Map<string, unknown>();
vi.mock('idb-keyval', () => ({
  get: vi.fn((key: string) => Promise.resolve(store.get(key))),
  set: vi.fn((key: string, value: unknown) => {
    store.set(key, value);
    return Promise.resolve();
  }),
  del: vi.fn((key: string) => {
    store.delete(key);
    return Promise.resolve();
  }),
  clear: vi.fn(() => {
    store.clear();
    return Promise.resolve();
  }),
}));

const START = new Date('2026-08-10T10:00:00Z');

function makePoint(overrides: Partial<FlightLogPoint> = {}): FlightLogPoint {
  return {
    latitude: 40,
    longitude: 116,
    altitude: 1000,
    airspeed: 200,
    groundSpeed: 210,
    verticalSpeed: 800,
    heading: 90,
    pitch: 5,
    roll: 0,
    gForce: 1,
    gForceSource: 'body',
    fuelQuantity: 12000,
    onGround: false,
    timestamp: START,
    anomalyAlerts: [],
    ...overrides,
  };
}

function makeLog(overrides: Partial<FlightLog> = {}): FlightLog {
  const start = START;
  return {
    id: '1',
    aircraftTitle: 'A320',
    simulatorLabel: 'X-Plane',
    departureAirport: 'ZBAA',
    arrivalAirport: 'ZSSS',
    startTime: start,
    points: [makePoint()],
    maxG: 1,
    minG: 1,
    maxAltitude: 1000,
    maxAirspeed: 200,
    maxGroundSpeed: 210,
    wasOnGroundAtStart: true,
    wasOnGroundAtEnd: false,
    ...overrides,
  };
}

function connectedSnapshot(): FlightDataSnapshot {
  return { ...emptyFlightDataSnapshot(), isConnected: true };
}

function snapshotAtAirport({
  icaoCode,
  onGround,
  latitude,
  longitude,
  departureAirport,
}: {
  icaoCode: string;
  onGround: boolean;
  latitude: number;
  longitude: number;
  departureAirport?: string;
}): FlightDataSnapshot {
  const snapshot = emptyFlightDataSnapshot();
  return {
    ...snapshot,
    isConnected: true,
    nearestAirport: {
      icaoCode,
      iataCode: icaoCode.slice(1),
      name: icaoCode,
      nameChinese: icaoCode,
      latitude,
      longitude,
    },
    flightData: {
      ...snapshot.flightData,
      departureAirport,
      latitude,
      longitude,
      altitude: onGround ? 25 : 1500,
      airspeed: onGround ? 130 : 145,
      groundSpeed: onGround ? 128 : 140,
      verticalSpeed: onGround ? 0 : -600,
      heading: 90,
      pitch: 3,
      bank: 0,
      gForce: 1,
      fuelQuantity: 8000,
      onGround,
    },
  };
}
async function seedArchive(log: FlightLog, extra: Record<string, unknown> = {}) {
  await idbSet(ACTIVE_LOG_IDB_KEY, {
    log: flightLogToJson(log),
    touchdownPointIndexes: [],
    ...extra,
  });
}

describe('flight log identity', () => {
  beforeEach(() => {
    store.clear();
    useFlightLogsStore.setState({
      isRecording: false,
      isRecordingPaused: false,
      activeLog: null,
      logs: [],
    });
  });

  it('two circuit recordings started in the same millisecond get distinct UUIDs', () => {
    vi.useFakeTimers();
    vi.setSystemTime(START);
    try {
      const snapshot = connectedSnapshot();
      expect(useFlightLogsStore.getState().startRecording(snapshot)).toBe(true);
      const firstId = useFlightLogsStore.getState().activeLog?.id;

      useFlightLogsStore.setState({ isRecording: false, activeLog: null });
      expect(useFlightLogsStore.getState().startRecording(snapshot)).toBe(true);
      const secondId = useFlightLogsStore.getState().activeLog?.id;

      const uuidV4Pattern =
        /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
      expect(firstId).toMatch(uuidV4Pattern);
      expect(secondId).toMatch(uuidV4Pattern);
      expect(secondId).not.toBe(firstId);
    } finally {
      vi.useRealTimers();
    }
  });
  it('uses the airport nearest to touchdown instead of the departure fallback', () => {
    vi.useFakeTimers();
    vi.setSystemTime(START);
    try {
      const departure = snapshotAtAirport({
        icaoCode: 'LIRF',
        onGround: true,
        latitude: 41.8003,
        longitude: 12.2389,
        departureAirport: 'LIRF',
      });
      expect(useFlightLogsStore.getState().startRecording(departure)).toBe(true);

      vi.advanceTimersByTime(100);
      useFlightLogsStore.getState().handleFlightSnapshot(
        snapshotAtAirport({
          icaoCode: 'LIRE',
          onGround: false,
          latitude: 41.6545,
          longitude: 12.4451,
        }),
      );

      vi.advanceTimersByTime(100);
      useFlightLogsStore.getState().handleFlightSnapshot(
        snapshotAtAirport({
          icaoCode: 'LIRE',
          onGround: true,
          latitude: 41.6545,
          longitude: 12.4451,
        }),
      );

      expect(useFlightLogsStore.getState().activeLog?.arrivalAirport).toBe('LIRE');
    } finally {
      vi.useRealTimers();
    }
  });
});

describe('recoverActiveLog', () => {
  beforeEach(async () => {
    store.clear();
    useFlightLogsStore.setState({
      isRecording: false,
      isRecordingPaused: false,
      activeLog: null,
      logs: [],
    });
    await idbDel(ACTIVE_LOG_IDB_KEY);
  });

  it('没有存档时返回 false，不动任何状态', async () => {
    const recovered = await useFlightLogsStore.getState().recoverActiveLog();
    expect(recovered).toBe(false);
    expect(useFlightLogsStore.getState().isRecording).toBe(false);
  });

  // 核心验收：刷新后已录的航迹点一个不少
  it('有存档时接回录制，采样点一个不少', async () => {
    const log = makeLog({
      points: Array.from({ length: 137 }, (_, i) =>
        makePoint({ altitude: 1000 + i, timestamp: new Date(START.getTime() + i * 100) }),
      ),
    });
    await seedArchive(log);

    const recovered = await useFlightLogsStore.getState().recoverActiveLog();

    expect(recovered).toBe(true);
    const state = useFlightLogsStore.getState();
    expect(state.isRecording).toBe(true);
    expect(state.activeLog?.points).toHaveLength(137);
    expect(state.activeLog?.points[136].altitude).toBe(1136);
  });

  it('已经在录制时不覆盖当前录制', async () => {
    await seedArchive(makeLog());
    useFlightLogsStore.setState({ isRecording: true });

    expect(await useFlightLogsStore.getState().recoverActiveLog()).toBe(false);
  });

  it('存档为空点集时丢弃，不留一条空录制卡在那儿', async () => {
    await seedArchive(makeLog({ points: [] }));

    expect(await useFlightLogsStore.getState().recoverActiveLog()).toBe(false);
    expect(useFlightLogsStore.getState().isRecording).toBe(false);
    expect(await idbGet(ACTIVE_LOG_IDB_KEY)).toBeUndefined();
  });

  it('存档结构损坏时丢弃而不是抛异常，并且把坏存档清掉', async () => {
    await idbSet(ACTIVE_LOG_IDB_KEY, { log: 'not an object' });

    expect(await useFlightLogsStore.getState().recoverActiveLog()).toBe(false);
    expect(useFlightLogsStore.getState().isRecording).toBe(false);
    // 不清掉的话，每次启动都会重试这份永远解析不出来的存档
    expect(await idbGet(ACTIVE_LOG_IDB_KEY)).toBeUndefined();
  });

  // 不接回接地序列的话，落地检测会以为这是一段全新的空中飞行
  it('接地序列上下文一并恢复', async () => {
    const log = makeLog();
    await seedArchive(log, { touchdownPointIndexes: [12, 34], lastOnGround: false });

    expect(await useFlightLogsStore.getState().recoverActiveLog()).toBe(true);
    // 恢复后继续采样不应把已有接地点抹掉
    useFlightLogsStore.getState().handleFlightSnapshot(connectedSnapshot());
    expect(useFlightLogsStore.getState().activeLog?.points.length).toBeGreaterThanOrEqual(1);
  });
});

describe('录制中增量落盘', () => {
  beforeEach(async () => {
    store.clear();
    useFlightLogsStore.setState({
      isRecording: false,
      isRecordingPaused: false,
      activeLog: null,
      logs: [],
    });
    await idbDel(ACTIVE_LOG_IDB_KEY);
  });

  it('开始录制立刻写一次存档，不等节流窗口', async () => {
    useFlightLogsStore.getState().startRecording(connectedSnapshot(), 'CCA1501');
    // persistActiveLog 是 fire-and-forget，让出一轮微任务
    await Promise.resolve();
    await Promise.resolve();

    expect(await idbGet(ACTIVE_LOG_IDB_KEY)).toBeDefined();
  });

  it('flushActiveLog 在未录制时是空操作', async () => {
    await useFlightLogsStore.getState().flushActiveLog();
    expect(await idbGet(ACTIVE_LOG_IDB_KEY)).toBeUndefined();
  });

  it('flushActiveLog 会把当前进度写盘', async () => {
    useFlightLogsStore.setState({ isRecording: true, activeLog: makeLog() });
    await useFlightLogsStore.getState().flushActiveLog();

    const archive = await idbGet<{ log: { points: unknown[] } }>(ACTIVE_LOG_IDB_KEY);
    expect(archive?.log.points).toHaveLength(1);
  });

  // 防的是「有人把 captureSnapshot 里那行 persistActiveLog 删了」——
  // 删掉之后只有开始录制那一下有存档，后面采到的点全在内存里，刷新照样全丢。
  it('采样过程中会持续刷新存档', async () => {
    vi.useFakeTimers();
    try {
      useFlightLogsStore.getState().startRecording(connectedSnapshot(), 'CCA1501');
      await vi.advanceTimersByTimeAsync(0);

      // 越过 3 秒节流窗口后再采一帧
      await vi.advanceTimersByTimeAsync(4_000);
      useFlightLogsStore.getState().handleFlightSnapshot(connectedSnapshot());
      await vi.advanceTimersByTimeAsync(0);

      const archive = await idbGet<{ log: { points: unknown[] } }>(ACTIVE_LOG_IDB_KEY);
      expect(archive?.log.points.length).toBeGreaterThan(1);
    } finally {
      vi.useRealTimers();
    }
  });

  it('录制过短被丢弃时同时清掉存档', async () => {
    // startTime 必须取「刚刚」：写死一个过去的时间点，收尾时算出来的时长
    // 是「现在 - 那个时间点」，早就超过 1 分钟下限，走不到丢弃分支。
    const justNow = new Date();
    useFlightLogsStore.setState({
      isRecording: true,
      activeLog: makeLog({
        startTime: justNow,
        points: [makePoint({ timestamp: justNow })],
      }),
    });
    await useFlightLogsStore.getState().flushActiveLog();
    expect(await idbGet(ACTIVE_LOG_IDB_KEY)).toBeDefined();

    // 只有一个点、时长为 0 → 走「过短丢弃」分支
    const saved = await useFlightLogsStore.getState().stopRecording(connectedSnapshot());

    expect(saved).toBe(false);
    expect(await idbGet(ACTIVE_LOG_IDB_KEY)).toBeUndefined();
  });
});
