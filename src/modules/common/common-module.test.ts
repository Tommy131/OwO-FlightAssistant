// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { AppLogger } from '../../core/utils/logger';
import { emptyFlightDataSnapshot, type FlightDataSnapshot } from './models/common-models';

type SnapshotSubscriber = (listener: SnapshotListener) => () => void;
type SnapshotListener = (
  state: { snapshot: FlightDataSnapshot },
  previous: { snapshot: FlightDataSnapshot },
) => void;

const doubles = vi.hoisted(() => {
  const manual = {
    hasActiveWork: false,
    refreshLogs: vi.fn(),
    recoverInterruptedLog: vi.fn(),
    recoverActiveLog: vi.fn(),
    handleFlightSnapshot: vi.fn(),
    handleDisconnect: vi.fn(),
    flushActiveLog: vi.fn(),
  };
  const automatic = {
    hasActiveWork: false,
    initialize: vi.fn(),
    recoverInterruptedReport: vi.fn(),
    handleFlightSnapshot: vi.fn(),
    handleDisconnect: vi.fn(),
    flushActiveReport: vi.fn(),
  };

  return {
    adapterDispose: vi.fn(),
    appModeHydrate: vi.fn(),
    automatic,
    createAdapter: vi.fn(),
    flightDataSubscribe: vi.fn<SnapshotSubscriber>(),
    manual,
    resumeSession: vi.fn(),
    workflowSubscribe: vi.fn(),
  };
});

vi.mock('./providers/flight-data-store', () => ({
  createDefaultFlightDataAdapter: doubles.createAdapter,
  useFlightDataStore: Object.assign(vi.fn(), {
    getState: () => ({ resumeSession: doubles.resumeSession }),
    subscribe: doubles.flightDataSubscribe,
  }),
}));

vi.mock('../flight_logs/providers/flight-logs-store', () => ({
  useFlightLogsStore: Object.assign(vi.fn(), {
    getState: () => doubles.manual,
    subscribe: doubles.workflowSubscribe,
  }),
}));

vi.mock('../flight_logs/providers/landing-reports-store', () => ({
  useLandingReportsStore: Object.assign(vi.fn(), {
    getState: () => doubles.automatic,
  }),
}));

vi.mock('./providers/app-mode-store', () => ({
  useAppModeStore: {
    getState: () => ({ hydrate: doubles.appModeHydrate }),
  },
}));

import { CommonModule } from './common-module';

interface Deferred<T> {
  promise: Promise<T>;
  resolve: (value: T) => void;
}

function deferred<T>(): Deferred<T> {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

function connectedSnapshot(): FlightDataSnapshot {
  return { ...emptyFlightDataSnapshot(), isConnected: true };
}

function recordingBinding() {
  const binding = ModuleRegistry.providers
    .getAll()
    .find((candidate) => candidate.id === 'recording_lifecycle');
  expect(binding).toBeDefined();
  return binding!;
}

describe('CommonModule recording lifecycle', () => {
  const cleanups: Array<() => void> = [];
  let emitSnapshot: SnapshotListener | undefined;

  beforeEach(() => {
    ModuleRegistry.clear();
    vi.clearAllMocks();
    vi.spyOn(AppLogger, 'warning').mockImplementation(() => undefined);
    doubles.manual.hasActiveWork = false;
    doubles.automatic.hasActiveWork = false;
    doubles.createAdapter.mockReturnValue({ dispose: doubles.adapterDispose });
    doubles.manual.refreshLogs.mockResolvedValue(undefined);
    doubles.automatic.initialize.mockResolvedValue(undefined);
    doubles.resumeSession.mockResolvedValue(false);
    doubles.manual.recoverInterruptedLog.mockResolvedValue(false);
    doubles.automatic.recoverInterruptedReport.mockResolvedValue(false);
    doubles.manual.handleFlightSnapshot.mockReturnValue(undefined);
    doubles.automatic.handleFlightSnapshot.mockResolvedValue(undefined);
    doubles.manual.handleDisconnect.mockResolvedValue(false);
    doubles.automatic.handleDisconnect.mockResolvedValue(undefined);
    doubles.manual.flushActiveLog.mockResolvedValue(undefined);
    doubles.automatic.flushActiveReport.mockResolvedValue(undefined);
    doubles.flightDataSubscribe.mockImplementation((listener) => {
      emitSnapshot = listener;
      return vi.fn();
    });
  });

  afterEach(() => {
    cleanups.splice(0).forEach((cleanup) => cleanup());
    ModuleRegistry.clear();
    vi.restoreAllMocks();
  });

  it('hydrates, resumes, and recovers before fanning one live snapshot to each store', async () => {
    const manualHydrated = deferred<void>();
    const automaticInitialized = deferred<void>();
    const sessionResumed = deferred<boolean>();
    doubles.manual.refreshLogs.mockReturnValue(manualHydrated.promise);
    doubles.automatic.initialize.mockReturnValue(automaticInitialized.promise);
    doubles.resumeSession.mockReturnValue(sessionResumed.promise);

    new CommonModule().register();
    cleanups.push(recordingBinding().setup());

    expect(doubles.manual.refreshLogs).toHaveBeenCalledTimes(1);
    expect(doubles.automatic.initialize).toHaveBeenCalledTimes(1);
    expect(doubles.flightDataSubscribe).toHaveBeenCalledTimes(1);
    expect(emitSnapshot).toBeDefined();

    const snapshot = connectedSnapshot();
    emitSnapshot!({ snapshot }, { snapshot: emptyFlightDataSnapshot() });
    await Promise.resolve();
    expect(doubles.manual.handleFlightSnapshot).not.toHaveBeenCalled();
    expect(doubles.automatic.handleFlightSnapshot).not.toHaveBeenCalled();

    manualHydrated.resolve(undefined);
    await Promise.resolve();
    expect(doubles.resumeSession).not.toHaveBeenCalled();

    automaticInitialized.resolve(undefined);
    await vi.waitFor(() => expect(doubles.resumeSession).toHaveBeenCalledTimes(1));
    expect(doubles.manual.recoverInterruptedLog).not.toHaveBeenCalled();
    expect(doubles.automatic.recoverInterruptedReport).not.toHaveBeenCalled();

    sessionResumed.resolve(true);
    await vi.waitFor(() => {
      expect(doubles.manual.recoverInterruptedLog).toHaveBeenCalledTimes(1);
      expect(doubles.automatic.recoverInterruptedReport).toHaveBeenCalledTimes(1);
      expect(doubles.manual.handleFlightSnapshot).toHaveBeenCalledTimes(1);
      expect(doubles.automatic.handleFlightSnapshot).toHaveBeenCalledTimes(1);
    });
    expect(doubles.manual.handleFlightSnapshot).toHaveBeenCalledWith(snapshot);
    expect(doubles.automatic.handleFlightSnapshot).toHaveBeenCalledWith(snapshot);
    expect(doubles.manual.recoverActiveLog).not.toHaveBeenCalled();
  });

  it('settles both disconnect handlers even when one recorder fails', async () => {
    doubles.manual.handleDisconnect.mockRejectedValue(new Error('manual save failed'));

    new CommonModule().register();
    cleanups.push(recordingBinding().setup());
    await vi.waitFor(() =>
      expect(doubles.automatic.recoverInterruptedReport).toHaveBeenCalledTimes(1),
    );

    emitSnapshot!(
      { snapshot: emptyFlightDataSnapshot() },
      { snapshot: connectedSnapshot() },
    );

    await vi.waitFor(() => {
      expect(doubles.manual.handleDisconnect).toHaveBeenCalledTimes(1);
      expect(doubles.automatic.handleDisconnect).toHaveBeenCalledTimes(1);
    });
    expect(doubles.manual.handleFlightSnapshot).not.toHaveBeenCalled();
    expect(doubles.automatic.handleFlightSnapshot).not.toHaveBeenCalled();
  });

  it('delivers a live snapshot to both stores when one handler throws synchronously', async () => {
    doubles.manual.handleFlightSnapshot.mockImplementation(() => {
      throw new Error('manual snapshot failed');
    });

    new CommonModule().register();
    cleanups.push(recordingBinding().setup());
    await vi.waitFor(() =>
      expect(doubles.automatic.recoverInterruptedReport).toHaveBeenCalledTimes(1),
    );
    const snapshot = connectedSnapshot();

    emitSnapshot!({ snapshot }, { snapshot: emptyFlightDataSnapshot() });

    await vi.waitFor(() => {
      expect(doubles.manual.handleFlightSnapshot).toHaveBeenCalledTimes(1);
      expect(doubles.automatic.handleFlightSnapshot).toHaveBeenCalledTimes(1);
    });
    expect(doubles.automatic.handleFlightSnapshot).toHaveBeenCalledWith(snapshot);
  });

  it('flushes both active archives and removes telemetry and unload listeners on cleanup', async () => {
    const unsubscribe = vi.fn();
    doubles.flightDataSubscribe.mockImplementation((listener) => {
      emitSnapshot = listener;
      return unsubscribe;
    });
    doubles.manual.hasActiveWork = true;
    doubles.manual.flushActiveLog.mockRejectedValue(new Error('manual flush failed'));

    new CommonModule().register();
    const cleanup = recordingBinding().setup();
    cleanups.push(cleanup);
    const guardedEvent = new Event('beforeunload', {
      cancelable: true,
    });

    window.dispatchEvent(guardedEvent);

    expect(guardedEvent.defaultPrevented).toBe(true);
    await vi.waitFor(() => {
      expect(doubles.manual.flushActiveLog).toHaveBeenCalledTimes(1);
      expect(doubles.automatic.flushActiveReport).toHaveBeenCalledTimes(1);
    });

    cleanup();
    expect(unsubscribe).toHaveBeenCalledTimes(1);
    window.dispatchEvent(
      new Event('beforeunload', { cancelable: true }),
    );
    expect(doubles.manual.flushActiveLog).toHaveBeenCalledTimes(1);
    expect(doubles.automatic.flushActiveReport).toHaveBeenCalledTimes(1);
  });
});
