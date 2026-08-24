import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { emptyFlightDataSnapshot, type FlightDataSnapshot } from '../../common/models/common-models';
import {
  flightLogToJson,
  type FlightLog,
  type FlightLogPoint,
} from '../models/flight-log-models';

const testState = vi.hoisted(() => ({
  activeArchives: new Map<string, unknown>(),
  moduleData: new Map<string, unknown>(),
  pushRecord: vi.fn(),
}));

vi.mock('idb-keyval', () => ({
  get: vi.fn((key: string) => Promise.resolve(testState.activeArchives.get(key))),
  set: vi.fn((key: string, value: unknown) => {
    testState.activeArchives.set(key, value);
    return Promise.resolve();
  }),
  del: vi.fn((key: string) => {
    testState.activeArchives.delete(key);
    return Promise.resolve();
  }),
}));

vi.mock('../../../core/services/backend-sync', () => ({
  mergeById: vi.fn((remote: unknown[], local: unknown[]) => [...remote, ...local]),
  pullRecords: vi.fn().mockResolvedValue(null),
  pushRecord: testState.pushRecord,
  removeRecord: vi.fn().mockResolvedValue({ ok: true, offline: false }),
}));

vi.mock('../../../core/services/persistence-service', () => ({
  PersistenceService: {
    ensureReady: vi.fn().mockResolvedValue(undefined),
    getModuleData: vi.fn((moduleName: string, key: string) =>
      testState.moduleData.get(`${moduleName}/${key}`),
    ),
    setModuleData: vi.fn((moduleName: string, key: string, value: unknown) => {
      testState.moduleData.set(`${moduleName}/${key}`, value);
      return Promise.resolve();
    }),
  },
}));

vi.mock('../services/runway-lookup', () => ({
  lookupRunwayAt: vi.fn().mockResolvedValue(undefined),
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
    testState.pushRecord.mockReset().mockResolvedValue({ ok: true, offline: false });
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
});
