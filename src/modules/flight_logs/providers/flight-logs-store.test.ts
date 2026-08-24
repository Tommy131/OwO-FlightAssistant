import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { emptyFlightDataSnapshot, type FlightDataSnapshot } from '../../common/models/common-models';
import {
  flightLogDurationMs,
  flightLogFromJson,
  flightLogToJson,
  type FlightLog,
  type FlightLogPoint,
} from '../models/flight-log-models';

const testState = vi.hoisted(() => ({
  activeArchives: new Map<string, unknown>(),
  idbGet: vi.fn(),
  idbSet: vi.fn(),
  moduleData: new Map<string, unknown>(),
  lookupRunwayAt: vi.fn(),
  pullRecords: vi.fn(),
  pushRecord: vi.fn(),
  getDurableModuleData: vi.fn(),
  setModuleDataDurable: vi.fn(),
}));

vi.mock('idb-keyval', () => ({
  get: testState.idbGet,
  set: testState.idbSet,
  del: vi.fn((key: string) => {
    testState.activeArchives.delete(key);
    return Promise.resolve();
  }),
}));

vi.mock('../../../core/services/backend-sync', () => ({
  mergeById: vi.fn((remote: unknown[], local: unknown[]) => [...remote, ...local]),
  pullRecords: testState.pullRecords,
  pushRecord: testState.pushRecord,
  removeRecord: vi.fn().mockResolvedValue({ ok: true, offline: false }),
}));

vi.mock('../../../core/services/persistence-service', () => ({
  PersistenceService: {
    ensureReady: vi.fn().mockResolvedValue(undefined),
    getModuleData: vi.fn((moduleName: string, key: string) =>
      testState.moduleData.get(`${moduleName}/${key}`),
    ),
    getDurableModuleData: testState.getDurableModuleData,
    setModuleData: vi.fn((moduleName: string, key: string, value: unknown) => {
      testState.moduleData.set(`${moduleName}/${key}`, value);
      return Promise.resolve();
    }),
    setModuleDataDurable: testState.setModuleDataDurable,
  },
}));

vi.mock('../services/runway-lookup', () => ({
  lookupRunwayAt: testState.lookupRunwayAt,
}));

import { useFlightLogsStore } from './flight-logs-store';

const ACTIVE_LOG_IDB_KEY = 'owo-flight-assistant/flight-logs/active';
const START = new Date('2026-08-24T10:00:00.000Z');

function snapshot(overrides: Partial<FlightDataSnapshot['flightData']> = {}): FlightDataSnapshot {
  const base = emptyFlightDataSnapshot();
  return {
    ...base,
    isConnected: true,
    simulatorType: 'msfs',
    flightData: {
      ...base.flightData,
      latitude: 50.03,
      longitude: 8.57,
      altitude: 321,
      airspeed: 140,
      groundSpeed: 137,
      verticalSpeed: -300,
      heading: 250,
      pitch: 2,
      bank: 0,
      gForce: 1.02,
      fuelQuantity: 4_000,
      radioAltitude: 80,
      radioAltitudeSource: 'radio',
      onGround: false,
      ...overrides,
    },
  };
}

function point(overrides: Partial<FlightLogPoint> = {}): FlightLogPoint {
  return {
    latitude: 50.03,
    longitude: 8.57,
    altitude: 321,
    airspeed: 140,
    groundSpeed: 137,
    verticalSpeed: -300,
    heading: 250,
    pitch: 2,
    roll: 0,
    gForce: 1.02,
    gForceSource: 'body',
    fuelQuantity: 4_000,
    timestamp: START,
    onGround: false,
    anomalyAlerts: [],
    ...overrides,
  };
}

function activeLog(overrides: Partial<FlightLog> = {}): FlightLog {
  return {
    id: 'manual-recovery',
    aircraftTitle: 'A320neo',
    simulatorLabel: 'MSFS',
    departureAirport: 'EDDF',
    arrivalAirport: 'EDDM',
    startTime: START,
    points: [point()],
    maxG: 1.02,
    minG: 1.02,
    maxAltitude: 321,
    maxAirspeed: 140,
    maxGroundSpeed: 137,
    wasOnGroundAtStart: false,
    wasOnGroundAtEnd: false,
    status: 'incomplete',
    endReason: 'interrupted',
    ...overrides,
  };
}

function persistedLogs(): Record<string, unknown>[] {
  return (testState.moduleData.get('flight_logs/logs') ?? []) as Record<string, unknown>[];
}

function activeArchiveLog(): Record<string, unknown> | undefined {
  const archive = testState.activeArchives.get(ACTIVE_LOG_IDB_KEY) as
    | { log?: Record<string, unknown> }
    | undefined;
  return archive?.log;
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((next) => {
    resolve = next;
  });
  return { promise, resolve };
}

async function settleInitialArchive(): Promise<void> {
  await Promise.resolve();
  await Promise.resolve();
}

describe('manual flight recording finalization', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(START);
    testState.activeArchives.clear();
    testState.moduleData.clear();
    testState.idbGet.mockReset().mockImplementation((key: string) =>
      Promise.resolve(testState.activeArchives.get(key)),
    );
    testState.idbSet.mockReset().mockImplementation((key: string, value: unknown) => {
      testState.activeArchives.set(key, value);
      return Promise.resolve();
    });
    testState.lookupRunwayAt.mockReset().mockResolvedValue(undefined);
    testState.pullRecords.mockReset().mockResolvedValue(null);
    testState.pushRecord.mockReset().mockResolvedValue({ ok: true, offline: false });
    testState.getDurableModuleData.mockReset().mockImplementation(
      (moduleName: string, key: string) =>
        Promise.resolve(testState.moduleData.get(`${moduleName}/${key}`)),
    );
    testState.setModuleDataDurable.mockReset().mockImplementation(
      (moduleName: string, key: string, value: unknown) => {
        testState.moduleData.set(`${moduleName}/${key}`, value);
        return Promise.resolve();
      },
    );
    useFlightLogsStore.setState({
      logs: [],
      selectedLog: null,
      isRecording: false,
      isRecordingPaused: false,
      activeLog: null,
      hasActiveWork: false,
    });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('does not promote an incomplete legacy log to completed while refreshing', async () => {
    testState.moduleData.set('flight_logs/logs', [{
      id: 'legacy-incomplete',
      aircraft: 'A320',
      departure: 'EDDF',
      start: START.toISOString(),
      max_g: 1,
      min_g: 1,
      max_alt: 1_000,
      max_spd: 180,
      max_gs: 170,
      ground_start: true,
      ground_end: false,
      points: [],
    }]);

    await useFlightLogsStore.getState().refreshLogs();

    expect(persistedLogs()[0]).not.toHaveProperty('status');
    expect(flightLogFromJson(persistedLogs()[0]).status).toBeUndefined();
  });

  it('saves a non-empty manual recording shorter than one minute as user-stopped', async () => {
    expect(useFlightLogsStore.getState().startRecording(snapshot(), 'DLH123')).toBe(true);
    await settleInitialArchive();

    expect(useFlightLogsStore.getState().hasActiveWork).toBe(true);
    expect(await useFlightLogsStore.getState().stopRecording(snapshot(), 'user_stopped')).toBe(true);

    const saved = persistedLogs();
    expect(saved).toHaveLength(1);
    expect(saved[0]).toMatchObject({
      status: 'incomplete',
      end_reason: 'user_stopped',
      flight_number: 'DLH123',
    });
    expect(saved[0].points).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ alt: 321, spd: 140, ra: 80, ras: 'radio' }),
      ]),
    );
    expect(useFlightLogsStore.getState().hasActiveWork).toBe(false);
    expect(testState.activeArchives.has(ACTIVE_LOG_IDB_KEY)).toBe(false);
  });

  it('marks a simulator disconnect incomplete and remains idempotent', async () => {
    expect(useFlightLogsStore.getState().startRecording(snapshot())).toBe(true);
    await settleInitialArchive();

    expect(await useFlightLogsStore.getState().handleDisconnect()).toBe(true);
    expect(await useFlightLogsStore.getState().handleDisconnect()).toBe(false);

    expect(persistedLogs()).toEqual([
      expect.objectContaining({
        status: 'incomplete',
        end_reason: 'simulator_disconnected',
      }),
    ]);
    expect(testState.pushRecord).toHaveBeenCalledTimes(1);
  });

  it('uses completed status only for a stable landing reason', async () => {
    expect(useFlightLogsStore.getState().startRecording(snapshot())).toBe(true);

    expect(await useFlightLogsStore.getState().stopRecording(snapshot(), 'stable_landing')).toBe(true);

    expect(persistedLogs()).toEqual([
      expect.objectContaining({ status: 'completed', end_reason: 'stable_landing' }),
    ]);
  });

  it('finalizes an orphan archive as page-closed without silently resuming it', async () => {
    const archived = activeLog({
      points: [
        point({ fuelQuantity: 4_000, radioAltitude: 80, radioAltitudeSource: 'radio' }),
        point({
          altitude: 200,
          fuelQuantity: 3_950,
          timestamp: new Date(START.getTime() + 500),
        }),
      ],
      totalFuelUsed: 50,
    });
    testState.activeArchives.set(ACTIVE_LOG_IDB_KEY, {
      log: flightLogToJson(archived),
      touchdownPointIndexes: [],
      lastOnGround: false,
    });

    expect(await useFlightLogsStore.getState().recoverInterruptedLog()).toBe(true);

    const state = useFlightLogsStore.getState();
    expect(state.isRecording).toBe(false);
    expect(state.activeLog).toBeNull();
    expect(state.hasActiveWork).toBe(false);
    expect(persistedLogs()).toEqual([
      expect.objectContaining({
        id: 'manual-recovery',
        status: 'incomplete',
        end_reason: 'page_closed',
        fuel_used: 50,
        points: [
          expect.objectContaining({ ra: 80, ras: 'radio', fuel: 4_000 }),
          expect.objectContaining({ alt: 200, fuel: 3_950 }),
        ],
      }),
    ]);
    expect(testState.activeArchives.has(ACTIVE_LOG_IDB_KEY)).toBe(false);
  });

  it('treats an unmarked legacy interrupted archive with an end time as in progress', async () => {
    const lastSampleTime = new Date(START.getTime() + 500);
    testState.activeArchives.set(ACTIVE_LOG_IDB_KEY, {
      log: flightLogToJson(activeLog({
        endTime: lastSampleTime,
        points: [point(), point({ timestamp: lastSampleTime })],
        status: 'incomplete',
        endReason: 'interrupted',
      })),
      touchdownPointIndexes: [],
      lastOnGround: false,
    });

    expect(await useFlightLogsStore.getState().recoverInterruptedLog()).toBe(true);

    expect(persistedLogs()[0]).toMatchObject({
      status: 'incomplete',
      end_reason: 'page_closed',
      end: lastSampleTime.toISOString(),
    });
  });

  it('preserves a user-stopped terminal checkpoint after a crash before final save', async () => {
    const endTime = new Date(START.getTime() + 750);
    testState.activeArchives.set(ACTIVE_LOG_IDB_KEY, {
      log: flightLogToJson(activeLog({
        endTime,
        points: [point(), point({ altitude: 222, timestamp: endTime })],
        status: 'incomplete',
        endReason: 'user_stopped',
      })),
      touchdownPointIndexes: [],
      lastOnGround: false,
    });

    expect(await useFlightLogsStore.getState().recoverInterruptedLog()).toBe(true);

    expect(persistedLogs()[0]).toMatchObject({
      status: 'incomplete',
      end_reason: 'user_stopped',
      end: endTime.toISOString(),
      points: [expect.any(Object), expect.objectContaining({ alt: 222 })],
    });
  });

  it('preserves a stable-landing terminal checkpoint after a crash', async () => {
    const endTime = new Date(START.getTime() + 900);
    testState.activeArchives.set(ACTIVE_LOG_IDB_KEY, {
      log: flightLogToJson(activeLog({
        endTime,
        points: [point(), point({ onGround: true, timestamp: endTime })],
        status: 'completed',
        endReason: 'stable_landing',
        wasOnGroundAtEnd: true,
      })),
      touchdownPointIndexes: [],
      lastOnGround: true,
    });

    expect(await useFlightLogsStore.getState().recoverInterruptedLog()).toBe(true);

    expect(persistedLogs()[0]).toMatchObject({
      status: 'completed',
      end_reason: 'stable_landing',
      end: endTime.toISOString(),
    });
  });

  it('preserves an explicitly interrupted terminal checkpoint', async () => {
    const endTime = new Date(START.getTime() + 600);
    testState.activeArchives.set(ACTIVE_LOG_IDB_KEY, {
      lifecycle: 'terminal',
      log: flightLogToJson(activeLog({
        endTime,
        status: 'incomplete',
        endReason: 'interrupted',
      })),
      touchdownPointIndexes: [],
      lastOnGround: false,
    });

    expect(await useFlightLogsStore.getState().recoverInterruptedLog()).toBe(true);

    expect(persistedLogs()[0]).toMatchObject({
      status: 'incomplete',
      end_reason: 'interrupted',
      end: endTime.toISOString(),
    });
  });

  it('keeps equal durable finalized data after a crash before archive clear', async () => {
    const endTime = new Date(START.getTime() + 750);
    const takeoffData = {
      latitude: 50.03,
      longitude: 8.57,
      airspeed: 140,
      groundSpeed: 137,
      verticalSpeed: 300,
      pitch: 8,
      heading: 250,
      timestamp: START,
    };
    const checkpoint = activeLog({
      endTime,
      points: [point(), point({ altitude: 222, timestamp: endTime })],
      status: 'incomplete',
      endReason: 'user_stopped',
      takeoffData,
    });
    const durable = activeLog({
      ...checkpoint,
      takeoffData: { ...takeoffData, rotationSpeedKt: 155 },
    });
    testState.moduleData.set('flight_logs/logs', [flightLogToJson(durable)]);
    await useFlightLogsStore.getState().refreshLogs();
    testState.activeArchives.set(ACTIVE_LOG_IDB_KEY, {
      log: flightLogToJson(checkpoint),
      touchdownPointIndexes: [],
      lastOnGround: false,
    });

    expect(await useFlightLogsStore.getState().recoverInterruptedLog()).toBe(true);

    const recovered = flightLogFromJson(persistedLogs()[0]);
    expect(recovered.endReason).toBe('user_stopped');
    expect(recovered.endTime).toEqual(endTime);
    expect(recovered.takeoffData?.rotationSpeedKt).toBe(155);
    expect(testState.activeArchives.has(ACTIVE_LOG_IDB_KEY)).toBe(false);
  });

  it('waits for delayed hydration before merging a recovered archive', async () => {
    const historical = activeLog({
      id: 'historical-log',
      startTime: new Date(START.getTime() - 60_000),
      status: 'completed',
      endReason: 'stable_landing',
    });
    testState.moduleData.set('flight_logs/logs', [flightLogToJson(historical)]);
    testState.activeArchives.set(ACTIVE_LOG_IDB_KEY, {
      log: flightLogToJson(activeLog()),
      touchdownPointIndexes: [],
      lastOnGround: false,
    });
    const pull = deferred<null>();
    testState.pullRecords.mockReturnValueOnce(pull.promise);

    const hydrating = useFlightLogsStore.getState().refreshLogs();
    for (let turn = 0; turn < 10 && testState.pullRecords.mock.calls.length === 0; turn += 1) {
      await Promise.resolve();
    }
    expect(testState.pullRecords).toHaveBeenCalledOnce();
    const recovering = useFlightLogsStore.getState().recoverInterruptedLog();
    await Promise.resolve();
    expect(testState.setModuleDataDurable).not.toHaveBeenCalled();

    pull.resolve(null);
    await Promise.all([hydrating, recovering]);

    expect(persistedLogs().map((item) => item.id)).toEqual([
      'manual-recovery',
      'historical-log',
    ]);
  });

  it('serializes two refreshes that would otherwise finish out of order', async () => {
    const historical = activeLog({
      id: 'historical-log',
      startTime: new Date(START.getTime() - 60_000),
      status: 'completed',
      endReason: 'stable_landing',
    });
    testState.moduleData.set('flight_logs/logs', [flightLogToJson(historical)]);
    testState.activeArchives.set(ACTIVE_LOG_IDB_KEY, {
      log: flightLogToJson(activeLog()),
      touchdownPointIndexes: [],
      lastOnGround: false,
    });
    const olderPull = deferred<null>();
    const newerPull = deferred<null>();
    testState.pullRecords
      .mockReturnValueOnce(olderPull.promise)
      .mockReturnValueOnce(newerPull.promise);

    const olderRefresh = useFlightLogsStore.getState().refreshLogs();
    for (let turn = 0; turn < 10 && testState.pullRecords.mock.calls.length < 1; turn += 1) {
      await Promise.resolve();
    }
    const newerRefresh = useFlightLogsStore.getState().refreshLogs();
    for (let turn = 0; turn < 10; turn += 1) {
      await Promise.resolve();
    }
    expect(testState.pullRecords).toHaveBeenCalledOnce();
    const recovering = useFlightLogsStore.getState().recoverInterruptedLog();

    olderPull.resolve(null);
    for (let turn = 0; turn < 10 && testState.pullRecords.mock.calls.length < 2; turn += 1) {
      await Promise.resolve();
    }
    expect(testState.pullRecords).toHaveBeenCalledTimes(2);
    newerPull.resolve(null);
    await Promise.all([olderRefresh, newerRefresh, recovering]);

    expect(persistedLogs().map((item) => item.id)).toEqual([
      'manual-recovery',
      'historical-log',
    ]);
  });

  it('claims recovery before the archive read and blocks starts and duplicate recovery', async () => {
    const archive = {
      log: flightLogToJson(activeLog()),
      touchdownPointIndexes: [],
      lastOnGround: false,
    };
    testState.activeArchives.set(ACTIVE_LOG_IDB_KEY, archive);
    const read = deferred<typeof archive>();
    testState.idbGet.mockReturnValueOnce(read.promise);

    const firstRecovery = useFlightLogsStore.getState().recoverInterruptedLog();
    expect(useFlightLogsStore.getState().startRecording(snapshot())).toBe(false);
    const duplicateRecovery = useFlightLogsStore.getState().recoverInterruptedLog();
    read.resolve(archive);

    expect(await firstRecovery).toBe(true);
    expect(await duplicateRecovery).toBe(false);
    expect(testState.pushRecord).toHaveBeenCalledTimes(1);
  });

  it('keeps starts blocked after orphan recovery persistence fails and allows recovery retry', async () => {
    testState.activeArchives.set(ACTIVE_LOG_IDB_KEY, {
      log: flightLogToJson(activeLog()),
      touchdownPointIndexes: [],
      lastOnGround: false,
    });
    testState.setModuleDataDurable.mockRejectedValueOnce(new Error('disk failed'));

    await expect(useFlightLogsStore.getState().recoverInterruptedLog()).rejects.toThrow(
      'disk failed',
    );

    expect(useFlightLogsStore.getState().startRecording(snapshot())).toBe(false);
    expect(testState.activeArchives.has(ACTIVE_LOG_IDB_KEY)).toBe(true);
    expect(await useFlightLogsStore.getState().recoverInterruptedLog()).toBe(true);
    expect(testState.activeArchives.has(ACTIVE_LOG_IDB_KEY)).toBe(false);
  });

  it('serializes an import behind a delayed refresh so the imported log is not overwritten', async () => {
    const historical = activeLog({
      id: 'historical-log',
      startTime: new Date(START.getTime() - 60_000),
      status: 'completed',
      endReason: 'stable_landing',
    });
    const imported = activeLog({
      id: 'imported-log',
      startTime: new Date(START.getTime() + 60_000),
      status: 'completed',
      endReason: 'stable_landing',
    });
    testState.moduleData.set('flight_logs/logs', [flightLogToJson(historical)]);
    const pull = deferred<null>();
    testState.pullRecords.mockReturnValueOnce(pull.promise);

    const refreshing = useFlightLogsStore.getState().refreshLogs();
    for (let turn = 0; turn < 10 && testState.pullRecords.mock.calls.length === 0; turn += 1) {
      await Promise.resolve();
    }
    const importing = useFlightLogsStore.getState().importLogs({
      text: () => Promise.resolve(JSON.stringify(flightLogToJson(imported))),
    } as File);
    await Promise.resolve();
    pull.resolve(null);
    await Promise.all([refreshing, importing]);

    expect(persistedLogs().map((item) => item.id)).toEqual([
      'imported-log',
      'historical-log',
    ]);
  });

  it('serializes a deletion behind a delayed refresh so stale hydration cannot restore it', async () => {
    const historical = activeLog({
      id: 'historical-log',
      startTime: new Date(START.getTime() - 60_000),
      status: 'completed',
      endReason: 'stable_landing',
    });
    testState.moduleData.set('flight_logs/logs', [flightLogToJson(historical)]);
    const pull = deferred<null>();
    testState.pullRecords.mockReturnValueOnce(pull.promise);

    const refreshing = useFlightLogsStore.getState().refreshLogs();
    for (let turn = 0; turn < 10 && testState.pullRecords.mock.calls.length === 0; turn += 1) {
      await Promise.resolve();
    }
    const deleting = useFlightLogsStore.getState().deleteLog('historical-log');
    pull.resolve(null);
    await Promise.all([refreshing, deleting]);

    expect(useFlightLogsStore.getState().logs).toEqual([]);
    expect(persistedLogs()).toEqual([]);
  });

  it('locks terminal finalization before awaits and rejects competing stop paths', async () => {
    expect(useFlightLogsStore.getState().startRecording(snapshot())).toBe(true);
    const log = useFlightLogsStore.getState().activeLog!;
    log.takeoffData = {
      latitude: 50.03,
      longitude: 8.57,
      airspeed: 140,
      groundSpeed: 137,
      verticalSpeed: 300,
      pitch: 8,
      heading: 250,
      timestamp: START,
    };
    useFlightLogsStore.setState({ activeLog: { ...log } });
    const lookup = deferred<undefined>();
    const durableSave = deferred<void>();
    testState.lookupRunwayAt.mockReturnValueOnce(lookup.promise);
    testState.setModuleDataDurable.mockImplementationOnce(
      (moduleName: string, key: string, value: unknown) => {
        testState.moduleData.set(`${moduleName}/${key}`, value);
        return durableSave.promise;
      },
    );

    const stopping = useFlightLogsStore
      .getState()
      .stopRecording(snapshot({ altitude: 222 }), 'user_stopped');
    await Promise.resolve();
    await Promise.resolve();

    expect(useFlightLogsStore.getState().isRecording).toBe(false);
    expect(await useFlightLogsStore.getState().handleDisconnect()).toBe(false);
    expect(
      await useFlightLogsStore
        .getState()
        .stopRecording(snapshot({ altitude: 777 }), 'stable_landing'),
    ).toBe(false);
    useFlightLogsStore.getState().handleFlightSnapshot(snapshot({ altitude: 999 }));
    expect(useFlightLogsStore.getState().activeLog?.points).toHaveLength(2);
    expect(testState.pushRecord).not.toHaveBeenCalled();

    lookup.resolve(undefined);
    for (
      let turn = 0;
      turn < 10 && testState.setModuleDataDurable.mock.calls.length === 0;
      turn += 1
    ) {
      await Promise.resolve();
    }
    expect(testState.setModuleDataDurable).toHaveBeenCalledOnce();
    expect(await useFlightLogsStore.getState().handleDisconnect()).toBe(false);
    durableSave.resolve();
    expect(await stopping).toBe(true);
    expect(testState.pushRecord).toHaveBeenCalledTimes(1);
    expect(persistedLogs()[0]).toMatchObject({
      status: 'incomplete',
      end_reason: 'user_stopped',
    });
  });

  it('checkpoints terminal reason and final sample before enrichment awaits', async () => {
    expect(useFlightLogsStore.getState().startRecording(snapshot())).toBe(true);
    const log = useFlightLogsStore.getState().activeLog!;
    log.takeoffData = {
      latitude: 50.03,
      longitude: 8.57,
      airspeed: 140,
      groundSpeed: 137,
      verticalSpeed: 300,
      pitch: 8,
      heading: 250,
      timestamp: START,
    };
    useFlightLogsStore.setState({ activeLog: { ...log } });
    const lookup = deferred<undefined>();
    testState.lookupRunwayAt.mockReturnValueOnce(lookup.promise);

    const stopping = useFlightLogsStore
      .getState()
      .stopRecording(snapshot({ altitude: 222 }), 'user_stopped');
    for (
      let turn = 0;
      turn < 10 && testState.lookupRunwayAt.mock.calls.length === 0;
      turn += 1
    ) {
      await Promise.resolve();
    }
    expect(testState.lookupRunwayAt).toHaveBeenCalledOnce();

    expect(activeArchiveLog()).toMatchObject({
      status: 'incomplete',
      end_reason: 'user_stopped',
      points: [expect.any(Object), expect.objectContaining({ alt: 222 })],
    });
    expect(testState.activeArchives.get(ACTIVE_LOG_IDB_KEY)).toMatchObject({
      lifecycle: 'terminal',
    });
    lookup.resolve(undefined);
    await stopping;
  });

  it('orders a terminal checkpoint after an older in-flight archive write', async () => {
    expect(useFlightLogsStore.getState().startRecording(snapshot())).toBe(true);
    await settleInitialArchive();
    await vi.advanceTimersByTimeAsync(4_000);
    const olderWrite = deferred<void>();
    testState.idbSet.mockImplementationOnce((key: string, value: unknown) =>
      olderWrite.promise.then(() => {
        testState.activeArchives.set(key, value);
      }),
    );
    const log = useFlightLogsStore.getState().activeLog!;
    log.takeoffData = {
      latitude: 50.03,
      longitude: 8.57,
      airspeed: 140,
      groundSpeed: 137,
      verticalSpeed: 300,
      pitch: 8,
      heading: 250,
      timestamp: START,
    };
    useFlightLogsStore.setState({ activeLog: { ...log } });
    const lookup = deferred<undefined>();
    testState.lookupRunwayAt.mockReturnValueOnce(lookup.promise);

    const stopping = useFlightLogsStore
      .getState()
      .stopRecording(snapshot({ altitude: 222 }), 'user_stopped');
    await Promise.resolve();
    olderWrite.resolve();
    for (
      let turn = 0;
      turn < 10 && testState.lookupRunwayAt.mock.calls.length === 0;
      turn += 1
    ) {
      await Promise.resolve();
    }
    expect(testState.lookupRunwayAt).toHaveBeenCalledOnce();

    expect(activeArchiveLog()).toMatchObject({
      end_reason: 'user_stopped',
      points: [expect.any(Object), expect.objectContaining({ alt: 222 })],
    });
    lookup.resolve(undefined);
    await stopping;
  });

  it('keeps the terminal archive when durable local persistence fails offline', async () => {
    expect(useFlightLogsStore.getState().startRecording(snapshot())).toBe(true);
    await settleInitialArchive();
    testState.setModuleDataDurable.mockRejectedValueOnce(new Error('IndexedDB unavailable'));
    testState.pushRecord.mockResolvedValueOnce({ ok: false, offline: true });

    await expect(
      useFlightLogsStore.getState().stopRecording(snapshot(), 'user_stopped'),
    ).rejects.toThrow('IndexedDB unavailable');

    expect(activeArchiveLog()).toMatchObject({
      status: 'incomplete',
      end_reason: 'user_stopped',
    });
    expect(testState.pushRecord).not.toHaveBeenCalled();
    expect(useFlightLogsStore.getState()).toMatchObject({
      isRecording: false,
      hasActiveWork: true,
    });
  });

  it('cleans up a finalized manual recording after its durable local save without waiting for backend sync', async () => {
    expect(useFlightLogsStore.getState().startRecording(snapshot())).toBe(true);
    await settleInitialArchive();
    const sync = deferred<{ ok: boolean; offline: boolean }>();
    testState.pushRecord.mockReturnValueOnce(sync.promise);

    const stopping = useFlightLogsStore
      .getState()
      .stopRecording(snapshot({ altitude: 222 }), 'user_stopped');
    for (let turn = 0; turn < 20 && testState.pushRecord.mock.calls.length === 0; turn += 1) {
      await Promise.resolve();
    }
    for (
      let turn = 0;
      turn < 20 &&
      (testState.activeArchives.has(ACTIVE_LOG_IDB_KEY) ||
        useFlightLogsStore.getState().activeLog !== null);
      turn += 1
    ) {
      await Promise.resolve();
    }
    for (let turn = 0; turn < 5; turn += 1) {
      await Promise.resolve();
    }

    try {
      expect(testState.pushRecord).toHaveBeenCalledOnce();
      expect(persistedLogs()).toHaveLength(1);
      expect(testState.activeArchives.has(ACTIVE_LOG_IDB_KEY)).toBe(false);
      expect(useFlightLogsStore.getState()).toMatchObject({
        activeLog: null,
        hasActiveWork: false,
      });
      expect(useFlightLogsStore.getState().startRecording(snapshot())).toBe(true);
    } finally {
      sync.resolve({ ok: true, offline: false });
      await stopping;
    }
  });

  it('uses the archived final sample time instead of delayed recovery time', async () => {
    const archived = activeLog({
      points: [
        point(),
        point({ timestamp: new Date(START.getTime() + 500) }),
      ],
      endTime: undefined,
    });
    testState.activeArchives.set(ACTIVE_LOG_IDB_KEY, {
      log: flightLogToJson(archived),
      touchdownPointIndexes: [],
      lastOnGround: false,
    });
    vi.setSystemTime(new Date(START.getTime() + 86_400_000));

    expect(await useFlightLogsStore.getState().recoverInterruptedLog()).toBe(true);

    const recovered = flightLogFromJson(persistedLogs()[0]);
    expect(recovered.endTime).toEqual(new Date(START.getTime() + 500));
    expect(flightLogDurationMs(recovered)).toBe(500);
  });
});
