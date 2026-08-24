import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import type {
  FlightDataSnapshot,
  RadioAltitudeSource,
  SimulatorType,
} from '../../common/models/common-models';
import { emptyFlightDataSnapshot } from '../../common/models/common-models';
import {
  flightLogFromJson,
  type FlightLog,
} from '../models/flight-log-models';
import {
  serializeLandingReport,
  type StoredLandingReport,
} from '../models/landing-report-models';
import {
  createLandingReportsRepository,
  type LandingReportsArchiveStorage,
  type LandingReportsBackend,
  type LandingReportsPersistence,
  type LandingReportsRepository,
} from '../services/landing-reports-repository';
import {
  createLandingReportsStore,
  type LandingReportsSettingsPersistence,
} from './landing-reports-store';

const persistenceState = vi.hoisted(() => ({
  archives: new Map<string, unknown>(),
  moduleData: new Map<string, unknown>(),
}));

vi.mock('idb-keyval', () => ({
  get: vi.fn((key: string) => Promise.resolve(persistenceState.archives.get(key))),
  set: vi.fn((key: string, value: unknown) => {
    persistenceState.archives.set(key, value);
    return Promise.resolve();
  }),
  del: vi.fn((key: string) => {
    persistenceState.archives.delete(key);
    return Promise.resolve();
  }),
}));

vi.mock('../../../core/services/backend-sync', () => ({
  mergeById: vi.fn((remote: FlightLog[], local: FlightLog[]) => {
    const merged = new Map(local.map((log) => [log.id, log]));
    for (const log of remote) merged.set(log.id, log);
    return [...merged.values()];
  }),
  pullRecords: vi.fn().mockResolvedValue(null),
  pushRecord: vi.fn().mockResolvedValue({ ok: true, offline: false }),
  removeRecord: vi.fn().mockResolvedValue({ ok: true, offline: false }),
}));

vi.mock('../../../core/services/persistence-service', () => ({
  PersistenceService: {
    ensureReady: vi.fn().mockResolvedValue(undefined),
    getModuleData: vi.fn(<T>(moduleName: string, key: string): T | undefined =>
      persistenceState.moduleData.get(`${moduleName}/${key}`) as T | undefined,
    ),
    getDurableModuleData: vi.fn(<T>(moduleName: string, key: string): Promise<T | undefined> =>
      Promise.resolve(
        persistenceState.moduleData.get(`${moduleName}/${key}`) as T | undefined,
      ),
    ),
    setModuleData: vi.fn((moduleName: string, key: string, value: unknown) => {
      persistenceState.moduleData.set(`${moduleName}/${key}`, value);
      return Promise.resolve();
    }),
    setModuleDataDurable: vi.fn((moduleName: string, key: string, value: unknown) => {
      persistenceState.moduleData.set(`${moduleName}/${key}`, value);
      return Promise.resolve();
    }),
  },
}));

vi.mock('../services/runway-lookup', () => ({
  lookupRunwayAt: vi.fn().mockResolvedValue(undefined),
}));

import { useFlightLogsStore } from './flight-logs-store';

const ACTIVE_MANUAL_LOG_KEY = 'owo-flight-assistant/flight-logs/active';
const ACTIVE_LANDING_REPORT_KEY = 'owo-flight-assistant/landing-reports/active';
const START_TIME = Date.parse('2026-08-24T12:00:00.000Z');

interface SimulatorFixture {
  name: string;
  simulatorType: Exclude<SimulatorType, 'none'>;
  expectedSimulatorLabel: 'MSFS' | 'X-Plane';
  radioAltitudeSource: RadioAltitudeSource;
}

const simulatorFixtures = [
  {
    name: 'MSFS store-contract fixture with native radio height',
    simulatorType: 'msfs',
    expectedSimulatorLabel: 'MSFS',
    radioAltitudeSource: 'radio',
  },
  {
    name: 'MSFS store-contract fixture with AGL fallback height',
    simulatorType: 'msfs',
    expectedSimulatorLabel: 'MSFS',
    radioAltitudeSource: 'agl_fallback',
  },
  {
    name: 'X-Plane store-contract fixture with native radio height',
    simulatorType: 'xplane',
    expectedSimulatorLabel: 'X-Plane',
    radioAltitudeSource: 'radio',
  },
  {
    name: 'X-Plane store-contract fixture with AGL fallback height',
    simulatorType: 'xplane',
    expectedSimulatorLabel: 'X-Plane',
    radioAltitudeSource: 'agl_fallback',
  },
] as const satisfies readonly SimulatorFixture[];

class MemoryPersistence
  implements LandingReportsPersistence, LandingReportsSettingsPersistence
{
  async ensureReady(): Promise<void> {}

  getModuleData<T>(moduleName: string, key: string): T | undefined {
    return persistenceState.moduleData.get(`${moduleName}/${key}`) as T | undefined;
  }

  getDurableModuleData<T>(moduleName: string, key: string): Promise<T | undefined> {
    return Promise.resolve(this.getModuleData<T>(moduleName, key));
  }

  async setModuleData(moduleName: string, key: string, value: unknown): Promise<void> {
    persistenceState.moduleData.set(`${moduleName}/${key}`, value);
  }
}

class MemoryLandingBackend implements LandingReportsBackend {
  readonly reports = new Map<string, ReturnType<typeof serializeLandingReport>>();

  async push(report: StoredLandingReport) {
    this.reports.set(report.id, serializeLandingReport(report));
    return { ok: true, offline: false } as const;
  }

  async remove(id: string) {
    this.reports.delete(id);
    return { ok: true, offline: false } as const;
  }

  async pull(): Promise<unknown[]> {
    return [...this.reports.values()];
  }
}

const archiveStorage: LandingReportsArchiveStorage = {
  get: (key) => Promise.resolve(persistenceState.archives.get(key)),
  set: (key, value) => {
    persistenceState.archives.set(key, value);
    return Promise.resolve();
  },
  update: (key, updater) => {
    persistenceState.archives.set(
      key,
      updater(persistenceState.archives.get(key)),
    );
    return Promise.resolve();
  },
  remove: (key) => {
    persistenceState.archives.delete(key);
    return Promise.resolve();
  },
};

function flightSnapshot(
  fixture: SimulatorFixture,
  overrides: Partial<FlightDataSnapshot['flightData']> = {},
): FlightDataSnapshot {
  const empty = emptyFlightDataSnapshot();
  return {
    ...empty,
    isConnected: true,
    isBackendReachable: true,
    simulatorType: fixture.simulatorType,
    aircraftTitle: 'Integration Test Aircraft',
    flightData: {
      ...empty.flightData,
      latitude: 50.03,
      longitude: 8.57,
      altitude: 420,
      airspeed: 135,
      groundSpeed: 132,
      verticalSpeed: -450,
      heading: 250,
      pitch: 3,
      bank: 0,
      gForce: 1.02,
      fuelQuantity: 4_000,
      gearDown: true,
      onGround: false,
      radioAltitude: 100,
      radioAltitudeSource: fixture.radioAltitudeSource,
      ...overrides,
    },
  };
}

function manualLogs(): FlightLog[] {
  const raw = persistenceState.moduleData.get('flight_logs/logs');
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((item): item is Record<string, unknown> => item !== null && typeof item === 'object')
    .map(flightLogFromJson);
}

function createRepository(): LandingReportsRepository {
  const persistence = new MemoryPersistence();
  return createLandingReportsRepository({
    persistence,
    archiveStorage,
    backend: new MemoryLandingBackend(),
  });
}

function createRecordingHarness(fixture: SimulatorFixture) {
  let now = START_TIME;
  let reportSequence = 0;
  const repository = createRepository();
  const settings = new MemoryPersistence();
  const landingStore = createLandingReportsStore({
    repository,
    settings,
    now: () => now,
    createId: () => `landing-report-${++reportSequence}`,
  });

  async function deliver(
    offsetMs: number,
    overrides: Partial<FlightDataSnapshot['flightData']>,
  ): Promise<void> {
    now = START_TIME + offsetMs;
    vi.setSystemTime(now);
    const next = flightSnapshot(fixture, overrides);
    useFlightLogsStore.getState().handleFlightSnapshot(next);
    await landingStore.getState().handleFlightSnapshot(next);
  }

  return {
    fixture,
    repository,
    settings,
    landingStore,
    setNow(offsetMs: number) {
      now = START_TIME + offsetMs;
      vi.setSystemTime(now);
    },
    async initialize() {
      await landingStore.getState().initialize();
    },
    async startManualLog(
      overrides: Partial<FlightDataSnapshot['flightData']> = {},
    ) {
      const first = flightSnapshot(fixture, overrides);
      expect(useFlightLogsStore.getState().startRecording(first, 'TASK10')).toBe(true);
      await landingStore.getState().handleFlightSnapshot(first);
    },
    async flyStableLanding() {
      await deliver(1_000, {
        altitude: 320,
        onGround: true,
        radioAltitude: 0,
        verticalSpeed: -120,
      });
      await deliver(16_000, {
        altitude: 315,
        groundSpeed: 60,
        onGround: true,
        radioAltitude: 0,
        verticalSpeed: 0,
      });
    },
    deliver,
  };
}

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(START_TIME);
  vi.clearAllMocks();
  persistenceState.archives.clear();
  persistenceState.moduleData.clear();
  useFlightLogsStore.setState({
    logs: [],
    isLoading: false,
    selectedLog: null,
    isRecording: false,
    isRecordingPaused: false,
    activeLog: null,
    hasActiveWork: false,
    sampleIntervalMs: 100,
  });
});

afterEach(async () => {
  if (useFlightLogsStore.getState().isRecording) {
    await useFlightLogsStore.getState().flushActiveLog();
  }
  useFlightLogsStore.setState({
    isRecording: false,
    isRecordingPaused: false,
    activeLog: null,
    hasActiveWork: false,
  });
  vi.useRealTimers();
});

describe('manual and automatic recording store-contract integration', () => {
  it.each(simulatorFixtures)(
    'creates a stable landing report for $name using $radioAltitudeSource height while manual logging continues',
    async (fixture) => {
      const harness = createRecordingHarness(fixture);
      await harness.initialize();
      await harness.startManualLog();

      await harness.flyStableLanding();

      const reports = await harness.repository.list();
      expect(reports).toHaveLength(1);
      expect(reports[0]).toMatchObject({
        simulator: fixture.expectedSimulatorLabel,
        status: 'completed',
        endReason: 'stable_landing',
      });
      expect(reports[0].points.map((point) => point.radioAltitudeSource)).toEqual([
        fixture.radioAltitudeSource,
        fixture.radioAltitudeSource,
        fixture.radioAltitudeSource,
      ]);
      expect(reports[0].points.at(-1)).toMatchObject({
        radioAltitude: 0,
        radioAltitudeSource: fixture.radioAltitudeSource,
        onGround: true,
      });

      const manual = useFlightLogsStore.getState();
      expect(manual.isRecording).toBe(true);
      expect(manual.activeLog?.simulatorLabel).toBe(fixture.expectedSimulatorLabel);
      expect(manual.activeLog?.points.at(-1)?.radioAltitudeSource).toBe(
        fixture.radioAltitudeSource,
      );
      expect(manualLogs()).toEqual([]);
    },
  );

  it('finalizes both armed recorders once on disconnect without crossing their persistence boundaries', async () => {
    const fixture = simulatorFixtures[3];
    const harness = createRecordingHarness(fixture);
    await harness.initialize();
    await harness.startManualLog();
    await harness.deliver(1_000, { radioAltitude: 80 });

    harness.setNow(2_000);
    const [manualSaved] = await Promise.all([
      useFlightLogsStore.getState().handleDisconnect(),
      harness.landingStore.getState().handleDisconnect(),
    ]);

    expect(manualSaved).toBe(true);
    expect(manualLogs()).toEqual([
      expect.objectContaining({
        simulatorLabel: 'X-Plane',
        status: 'incomplete',
        endReason: 'simulator_disconnected',
      }),
    ]);
    expect(manualLogs()[0].points.at(-1)?.radioAltitudeSource).toBe('agl_fallback');

    const reports = await harness.repository.list();
    expect(reports).toHaveLength(1);
    expect(reports[0]).toMatchObject({
      simulator: 'X-Plane',
      status: 'incomplete',
      endReason: 'simulator_disconnected',
    });
    expect(reports[0].points.at(-1)?.radioAltitudeSource).toBe('agl_fallback');
    expect(reports[0].id).not.toBe(manualLogs()[0].id);

    await harness.landingStore.getState().handleDisconnect();
    expect(await useFlightLogsStore.getState().handleDisconnect()).toBe(false);
    expect(await harness.repository.list()).toHaveLength(1);
    expect(manualLogs()).toHaveLength(1);
  });

  it('recovers armed manual and automatic archives as independent page-closed records', async () => {
    const fixture = simulatorFixtures[0];
    const harness = createRecordingHarness(fixture);
    await harness.initialize();
    await harness.startManualLog();
    await harness.deliver(500, { radioAltitude: 60 });
    await Promise.all([
      useFlightLogsStore.getState().flushActiveLog(),
      harness.landingStore.getState().flushActiveReport(),
    ]);

    expect(persistenceState.archives.has(ACTIVE_MANUAL_LOG_KEY)).toBe(true);
    expect(persistenceState.archives.has(ACTIVE_LANDING_REPORT_KEY)).toBe(true);

    useFlightLogsStore.setState({
      isRecording: false,
      isRecordingPaused: false,
      activeLog: null,
      hasActiveWork: false,
      logs: [],
    });
    harness.setNow(5_000);
    const recoveredLandingStore = createLandingReportsStore({
      repository: harness.repository,
      settings: harness.settings,
      now: () => START_TIME + 5_000,
    });
    await recoveredLandingStore.getState().initialize();

    const [manualRecovered, automaticRecovered] = await Promise.all([
      useFlightLogsStore.getState().recoverInterruptedLog(),
      recoveredLandingStore.getState().recoverInterruptedReport(),
    ]);

    expect(manualRecovered).toBe(true);
    expect(automaticRecovered).toBe(true);
    expect(manualLogs()).toEqual([
      expect.objectContaining({
        status: 'incomplete',
        endReason: 'page_closed',
      }),
    ]);
    expect(manualLogs()[0].points.at(-1)?.radioAltitudeSource).toBe('radio');

    const reports = await harness.repository.list();
    expect(reports).toHaveLength(1);
    expect(reports[0]).toMatchObject({
      status: 'incomplete',
      endReason: 'page_closed',
      endedAt: START_TIME + 500,
    });
    expect(reports[0].points.at(-1)?.radioAltitudeSource).toBe('radio');
    expect(persistenceState.archives.has(ACTIVE_MANUAL_LOG_KEY)).toBe(false);
    expect(persistenceState.archives.has(ACTIVE_LANDING_REPORT_KEY)).toBe(false);
    expect(useFlightLogsStore.getState().isRecording).toBe(false);
    expect(recoveredLandingStore.getState().hasActiveWork).toBe(false);
  });

  it('recovers a manual archive but does not invent an automatic report from unarmed cruise buffering', async () => {
    const fixture = simulatorFixtures[2];
    const harness = createRecordingHarness(fixture);
    await harness.initialize();
    await harness.startManualLog({
      gearDown: false,
      radioAltitude: 8_000,
    });
    await Promise.all([
      useFlightLogsStore.getState().flushActiveLog(),
      harness.landingStore.getState().flushActiveReport(),
    ]);

    expect(persistenceState.archives.has(ACTIVE_MANUAL_LOG_KEY)).toBe(true);
    expect(persistenceState.archives.has(ACTIVE_LANDING_REPORT_KEY)).toBe(false);

    useFlightLogsStore.setState({
      isRecording: false,
      isRecordingPaused: false,
      activeLog: null,
      hasActiveWork: false,
      logs: [],
    });
    harness.setNow(5_000);
    const recoveredLandingStore = createLandingReportsStore({
      repository: harness.repository,
      settings: harness.settings,
      now: () => START_TIME + 5_000,
    });

    expect(await useFlightLogsStore.getState().recoverInterruptedLog()).toBe(true);
    expect(await recoveredLandingStore.getState().recoverInterruptedReport()).toBe(false);

    expect(manualLogs()).toEqual([
      expect.objectContaining({
        status: 'incomplete',
        endReason: 'page_closed',
      }),
    ]);
    expect(await harness.repository.list()).toEqual([]);
  });
});
