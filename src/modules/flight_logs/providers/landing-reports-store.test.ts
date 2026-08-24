import { beforeEach, describe, expect, it, vi } from 'vitest';

import { emptyFlightDataSnapshot, type FlightDataSnapshot } from '../../common/models/common-models';
import type { LandingReport } from '../models/landing-report-models';
import type {
  LandingRecorderEvent,
  LandingReportRecorder,
  LandingReportRecorderOptions,
} from '../services/landing-report-recorder';
import type { LandingReportsRepository } from '../services/landing-reports-repository';
import { makeFlightLogPoint } from '../test/flight-log-fixtures';
import {
  createLandingReportsStore,
  type LandingReportsSettingsPersistence,
} from './landing-reports-store';

function report(overrides: Partial<LandingReport> = {}): LandingReport {
  return {
    id: 'lr-1',
    simulator: 'MSFS',
    startedAt: 1_000,
    endedAt: 2_000,
    status: 'completed',
    endReason: 'stable_landing',
    points: [makeFlightLogPoint(0, { onGround: false, radioAltitude: 100 })],
    createdAt: 3_000,
    updatedAt: 4_000,
    ...overrides,
  };
}

function repository(overrides: Partial<LandingReportsRepository> = {}) {
  const base: LandingReportsRepository = {
    list: vi.fn().mockResolvedValue([]),
    get: vi.fn().mockResolvedValue(undefined),
    save: vi.fn().mockResolvedValue(undefined),
    remove: vi.fn().mockResolvedValue(undefined),
    writeActive: vi.fn().mockResolvedValue(undefined),
    readActive: vi.fn().mockResolvedValue(undefined),
    clearActive: vi.fn().mockResolvedValue(undefined),
    reconcile: vi.fn().mockResolvedValue(undefined),
    saveLocal: vi.fn().mockResolvedValue(undefined),
    sync: vi.fn().mockResolvedValue(undefined),
    ...overrides,
  };
  return base;
}

function settings(stored?: boolean): LandingReportsSettingsPersistence {
  return {
    ensureReady: vi.fn().mockResolvedValue(undefined),
    getModuleData: vi.fn().mockReturnValue(stored),
    setModuleData: vi.fn().mockResolvedValue(undefined),
  };
}

function snapshot(
  overrides: Partial<FlightDataSnapshot['flightData']> = {},
  topLevel: Partial<FlightDataSnapshot> = {},
): FlightDataSnapshot {
  const empty = emptyFlightDataSnapshot();
  return {
    ...empty,
    isConnected: true,
    simulatorType: 'msfs',
    aircraftTitle: 'A320neo',
    flightData: {
      ...empty.flightData,
      latitude: 40,
      longitude: 116,
      altitude: 2_000,
      airspeed: 140,
      groundSpeed: 138,
      verticalSpeed: -500,
      heading: 90,
      pitch: 3,
      bank: 0,
      gForce: 1,
      fuelQuantity: 8_000,
      onGround: false,
      radioAltitude: 100,
      radioAltitudeSource: 'radio',
      ...overrides,
    },
    ...topLevel,
  };
}

function recorder(overrides: Partial<LandingReportRecorder> = {}): LandingReportRecorder {
  return {
    push: vi.fn().mockReturnValue([]),
    pause: vi.fn(),
    resume: vi.fn(),
    disconnect: vi.fn().mockReturnValue([]),
    stop: vi.fn().mockReturnValue([]),
    hasActiveWork: vi.fn().mockReturnValue(false),
    ...overrides,
  };
}

describe('landing reports store', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('defaults automatic collection to enabled', async () => {
    const reports = repository();
    const store = createLandingReportsStore({ repository: reports, settings: settings() });

    await store.getState().initialize();

    expect(store.getState().enabled).toBe(true);
    expect(reports.reconcile).toHaveBeenCalledOnce();
  });

  it('recovers an orphan active archive as page_closed in local-clear-sync order', async () => {
    const order: string[] = [];
    const active = report({ status: 'incomplete', endReason: 'interrupted' });
    const reports = repository({
      readActive: vi.fn().mockResolvedValue(active),
      saveLocal: vi.fn(async () => {
        order.push('save-local');
      }),
      clearActive: vi.fn(async () => {
        order.push('clear-active');
      }),
      sync: vi.fn(async () => {
        order.push('sync');
      }),
    });
    const store = createLandingReportsStore({
      repository: reports,
      settings: settings(),
      now: () => 9_000,
    });

    expect(await store.getState().recoverInterruptedReport()).toBe(true);

    expect(reports.saveLocal).toHaveBeenCalledWith(expect.objectContaining({
      status: 'incomplete',
      endReason: 'page_closed',
      endedAt: 9_000,
      updatedAt: 9_000,
    }));
    expect(order).toEqual(['save-local', 'clear-active', 'sync']);
  });

  it('persists finalized reports locally, clears the archive, then syncs', async () => {
    const order: string[] = [];
    const finalized = report();
    const reports = repository({
      saveLocal: vi.fn(async () => {
        order.push('save-local');
      }),
      clearActive: vi.fn(async () => {
        order.push('clear-active');
      }),
      sync: vi.fn(async () => {
        order.push('sync');
      }),
    });
    const fakeRecorder = recorder({
      push: vi.fn().mockReturnValue([
        { type: 'finalize', report: finalized } satisfies LandingRecorderEvent,
      ]),
    });
    const store = createLandingReportsStore({
      repository: reports,
      settings: settings(),
      createRecorder: (_options: LandingReportRecorderOptions) => fakeRecorder,
    });

    await store.getState().handleFlightSnapshot(snapshot());

    expect(order).toEqual(['save-local', 'clear-active', 'sync']);
    expect(store.getState().reports).toEqual([finalized]);
  });

  it('writes the active archive after every armed sample with height provenance', async () => {
    let now = 1_000;
    const reports = repository();
    const store = createLandingReportsStore({
      repository: reports,
      settings: settings(),
      now: () => now,
      createId: () => 'active-lr',
    });

    await store.getState().handleFlightSnapshot(snapshot());
    now = 1_100;
    await store.getState().handleFlightSnapshot(snapshot({ radioAltitude: 80 }));

    expect(reports.writeActive).toHaveBeenCalledTimes(2);
    const latestArchive = vi.mocked(reports.writeActive).mock.calls.at(-1)?.[0];
    expect(latestArchive?.id).toBe('active-lr');
    expect(latestArchive?.points.at(-1)).toEqual(
      expect.objectContaining({ radioAltitude: 80, radioAltitudeSource: 'radio' }),
    );
    expect(store.getState().hasActiveWork).toBe(true);
  });

  it('flushes the latest armed draft without finalizing it', async () => {
    const reports = repository();
    const store = createLandingReportsStore({
      repository: reports,
      settings: settings(),
      now: () => 1_000,
      createId: () => 'active-lr',
    });
    await store.getState().handleFlightSnapshot(snapshot());

    await store.getState().flushActiveReport();

    expect(reports.writeActive).toHaveBeenCalledTimes(2);
    expect(reports.saveLocal).not.toHaveBeenCalled();
    expect(store.getState().hasActiveWork).toBe(true);
  });

  it('routes pause transitions to the recorder and excludes paused samples', async () => {
    const pause = vi.fn();
    const resume = vi.fn();
    const push = vi.fn().mockReturnValue([]);
    const fakeRecorder = recorder({ pause, resume, push });
    const store = createLandingReportsStore({
      repository: repository(),
      settings: settings(),
      createRecorder: () => fakeRecorder,
    });

    await store.getState().handleFlightSnapshot(snapshot({}, { isPaused: true }));
    await store.getState().handleFlightSnapshot(snapshot({}, { isPaused: false }));

    expect(pause).toHaveBeenCalledOnce();
    expect(resume).toHaveBeenCalledOnce();
    expect(push).toHaveBeenCalledOnce();
  });

  it('disabling saves user_stopped only after the recorder has armed', async () => {
    let now = 1_000;
    const armedRepository = repository();
    const armedSettings = settings();
    const armedStore = createLandingReportsStore({
      repository: armedRepository,
      settings: armedSettings,
      now: () => now,
      createId: () => 'active-id',
    });
    await armedStore.getState().handleFlightSnapshot(snapshot());
    now = 2_000;

    await armedStore.getState().setEnabled(false);

    expect(armedRepository.saveLocal).toHaveBeenCalledWith(expect.objectContaining({
      status: 'incomplete',
      endReason: 'user_stopped',
    }));
    expect(armedStore.getState().enabled).toBe(false);
    expect(armedSettings.setModuleData).toHaveBeenCalledWith(
      'landing_reports',
      'automatic_enabled',
      false,
    );

    const bufferingRepository = repository();
    const bufferingStore = createLandingReportsStore({
      repository: bufferingRepository,
      settings: settings(),
      now: () => now,
    });
    await bufferingStore.getState().handleFlightSnapshot(
      snapshot({ radioAltitude: 12_000, gearDown: false }),
    );

    await bufferingStore.getState().setEnabled(false);

    expect(bufferingRepository.saveLocal).not.toHaveBeenCalled();
    expect(bufferingRepository.clearActive).toHaveBeenCalled();
  });

  it('selects by id and clears selection when deleting the selected report', async () => {
    const saved = report();
    const reports = repository({ list: vi.fn().mockResolvedValue([saved]) });
    const store = createLandingReportsStore({ repository: reports, settings: settings() });
    await store.getState().initialize();

    store.getState().selectReport(saved.id);
    expect(store.getState().selectedReport).toEqual(saved);

    await store.getState().deleteReport(saved.id);

    expect(reports.remove).toHaveBeenCalledWith(saved.id);
    expect(store.getState().reports).toEqual([]);
    expect(store.getState().selectedReport).toBeUndefined();
  });

  it('finalizes an armed disconnect once and leaves cruise buffering unsaved', async () => {
    let now = 1_000;
    const armedRepository = repository();
    const armedStore = createLandingReportsStore({
      repository: armedRepository,
      settings: settings(),
      now: () => now,
    });
    await armedStore.getState().handleFlightSnapshot(snapshot());
    now = 2_000;

    await armedStore.getState().handleDisconnect();
    await armedStore.getState().handleDisconnect();

    expect(armedRepository.saveLocal).toHaveBeenCalledTimes(1);
    expect(armedRepository.saveLocal).toHaveBeenCalledWith(expect.objectContaining({
      status: 'incomplete',
      endReason: 'simulator_disconnected',
    }));

    const bufferingRepository = repository();
    const bufferingStore = createLandingReportsStore({
      repository: bufferingRepository,
      settings: settings(),
      now: () => now,
    });
    await bufferingStore.getState().handleFlightSnapshot(
      snapshot({ radioAltitude: 12_000, gearDown: false }),
    );
    await bufferingStore.getState().handleDisconnect();

    expect(bufferingRepository.saveLocal).not.toHaveBeenCalled();
  });
});
