import { create, type StateCreator } from 'zustand';
import { createStore, type StoreApi } from 'zustand/vanilla';

import { PersistenceService } from '../../../core/services/persistence-service';
import { AppLogger } from '../../../core/utils/logger';
import type { FlightDataSnapshot, SimulatorType } from '../../common/models/common-models';
import type {
  FlightLogAlert,
  FlightLogPoint,
  LandingGSource,
} from '../models/flight-log-models';
import type { LandingReport } from '../models/landing-report-models';
import {
  createLandingReportRecorder,
  PRE_TOUCHDOWN_MS,
  type LandingRecorderEvent,
  type LandingReportRecorder,
  type LandingReportRecorderOptions,
} from '../services/landing-report-recorder';
import {
  landingReportsRepository,
  type LandingReportsRepository,
} from '../services/landing-reports-repository';
import {
  MAX_VALID_LANDING_G,
  MIN_VALID_LANDING_G,
} from '../services/takeoff-landing-metrics';

const SETTINGS_MODULE = 'landing_reports';
const ENABLED_SETTING_KEY = 'automatic_enabled';

export interface LandingReportsSettingsPersistence {
  ensureReady: () => Promise<void>;
  getModuleData: <T>(moduleName: string, key: string) => T | undefined;
  setModuleData: (moduleName: string, key: string, value: unknown) => Promise<void>;
}

export interface LandingReportsState {
  enabled: boolean;
  reports: LandingReport[];
  selectedReport: LandingReport | undefined;
  hasActiveWork: boolean;

  initialize(): Promise<void>;
  setEnabled(enabled: boolean): Promise<void>;
  handleFlightSnapshot(snapshot: FlightDataSnapshot): Promise<void>;
  handleDisconnect(): Promise<void>;
  stopAutomaticRecording(): Promise<void>;
  flushActiveReport(): Promise<void>;
  recoverInterruptedReport(): Promise<boolean>;
  deleteReport(id: string): Promise<void>;
  selectReport(id: string | undefined): void;
}

interface LandingReportsStoreDependencies {
  repository: LandingReportsRepository;
  settings: LandingReportsSettingsPersistence;
  createRecorder?: (options: LandingReportRecorderOptions) => LandingReportRecorder;
  now?: () => number;
  createId?: () => string;
}

export function createLandingReportsStore(
  dependencies: LandingReportsStoreDependencies,
): StoreApi<LandingReportsState> {
  return createStore<LandingReportsState>(landingReportsStateCreator(dependencies));
}

function landingReportsStateCreator(
  dependencies: LandingReportsStoreDependencies,
): StateCreator<LandingReportsState> {
  const repository = dependencies.repository;
  const settings = dependencies.settings;
  const now = dependencies.now ?? Date.now;
  const createId = dependencies.createId ?? (() => crypto.randomUUID());
  const createRecorder = dependencies.createRecorder ?? createLandingReportRecorder;

  let recorder: LandingReportRecorder | undefined;
  let recorderSimulator = 'Unknown';
  let reportId: string | undefined;
  let capturePoints: FlightLogPoint[] = [];
  let activeDraft: LandingReport | undefined;
  let paused = false;
  let operationQueue = Promise.resolve();

  function enqueue<T>(operation: () => Promise<T>): Promise<T> {
    const result = operationQueue.then(operation, operation);
    operationQueue = result.then(
      () => undefined,
      () => undefined,
    );
    return result;
  }

  function resetCapture(): void {
    recorder = undefined;
    recorderSimulator = 'Unknown';
    reportId = undefined;
    capturePoints = [];
    activeDraft = undefined;
    paused = false;
  }

  function ensureRecorder(simulator: string): LandingReportRecorder {
    if (
      recorder === undefined ||
      (capturePoints.length === 0 &&
        !recorder.hasActiveWork() &&
        recorderSimulator !== simulator)
    ) {
      recorderSimulator = simulator;
      reportId = createId();
      recorder = createRecorder({
        now,
        createId: () => reportId ?? createId(),
        simulator,
      });
    }
    return recorder;
  }

  function updateReports(
    set: (partial: Partial<LandingReportsState>) => void,
    get: () => LandingReportsState,
    report: LandingReport,
  ): void {
    const reports = sortReports([
      report,
      ...get().reports.filter((item) => item.id !== report.id),
    ]);
    set({
      reports,
      selectedReport:
        get().selectedReport?.id === report.id ? report : get().selectedReport,
    });
  }

  async function persistFinalReport(
    report: LandingReport,
    set: (partial: Partial<LandingReportsState>) => void,
    get: () => LandingReportsState,
  ): Promise<void> {
    // This order is intentional: a network stall must never strand the only
    // durable copy in the transient recovery archive.
    await repository.saveLocal(report);
    await repository.clearActive();
    updateReports(set, get, report);
    await repository.sync(report);
  }

  function keepNextTouchAndGoBuffer(finalized: LandingReport): void {
    const cutoff = finalized.touchdownAt ?? finalized.endedAt;
    capturePoints = capturePoints.filter(
      (point) => point.timestamp.getTime() > cutoff,
    );
    activeDraft = undefined;
    reportId = createId();
  }

  function buildActiveDraft(): LandingReport | undefined {
    if (capturePoints.length === 0 || reportId === undefined) return undefined;
    const timestamp = now();
    const createdAt = activeDraft?.createdAt ?? timestamp;
    return {
      id: reportId,
      simulator: recorderSimulator,
      startedAt: capturePoints[0].timestamp.getTime(),
      endedAt: capturePoints[capturePoints.length - 1].timestamp.getTime(),
      status: 'incomplete',
      endReason: 'interrupted',
      points: [...capturePoints],
      createdAt,
      updatedAt: timestamp,
    };
  }

  async function persistEvents(
    events: LandingRecorderEvent[],
    set: (partial: Partial<LandingReportsState>) => void,
    get: () => LandingReportsState,
  ): Promise<void> {
    for (const event of events) {
      await persistFinalReport(event.report, set, get);
      if (event.report.endReason === 'touch_and_go') {
        keepNextTouchAndGoBuffer(event.report);
      } else {
        resetCapture();
      }
    }
  }

  async function persistActiveDraft(): Promise<void> {
    const next = buildActiveDraft();
    if (!next) return;
    activeDraft = next;
    try {
      await repository.writeActive(next);
    } catch (error) {
      AppLogger.warning(`[LandingReports] persist active report failed: ${String(error)}`);
    }
  }

  return (set, get) => {
    async function stopWith(
      interrupt: (activeRecorder: LandingReportRecorder) => LandingRecorderEvent[],
    ): Promise<void> {
      const events = recorder ? interrupt(recorder) : [];
      if (events.length > 0) await persistEvents(events, set, get);
      else await repository.clearActive();
      resetCapture();
      set({ hasActiveWork: false });
    }

    return {
      enabled: true,
      reports: [],
      selectedReport: undefined,
      hasActiveWork: false,

      initialize() {
        return enqueue(async () => {
          await settings.ensureReady();
          const stored = settings.getModuleData<unknown>(
            SETTINGS_MODULE,
            ENABLED_SETTING_KEY,
          );
          set({ enabled: typeof stored === 'boolean' ? stored : true });
          await repository.reconcile();
          set({ reports: sortReports(await repository.list()) });
        });
      },

      setEnabled(enabled) {
        return enqueue(async () => {
          if (!enabled) await stopWith((activeRecorder) => activeRecorder.stop());
          else if (!get().enabled) resetCapture();
          set({ enabled });
          await settings.setModuleData(
            SETTINGS_MODULE,
            ENABLED_SETTING_KEY,
            enabled,
          );
        });
      },

      handleFlightSnapshot(snapshot) {
        return enqueue(async () => {
          if (!get().enabled) return;
          if (!snapshot.isConnected) {
            await stopWith((activeRecorder) => activeRecorder.disconnect());
            return;
          }

          const activeRecorder = ensureRecorder(simulatorLabel(snapshot.simulatorType));
          const isPaused = snapshot.isPaused === true;
          if (isPaused) {
            if (!paused) activeRecorder.pause();
            paused = true;
            return;
          }
          if (paused) activeRecorder.resume();
          paused = false;

          const wasActive = activeRecorder.hasActiveWork();
          const point = snapshotToPoint(snapshot, now());
          capturePoints.push(point);
          if (!wasActive) trimPreTouchdownBuffer(capturePoints, point.timestamp.getTime());

          const events = activeRecorder.push(point);
          await persistEvents(events, set, get);

          const hasActiveWork = recorder?.hasActiveWork() ?? false;
          set({ hasActiveWork });
          if (hasActiveWork) await persistActiveDraft();
        });
      },

      handleDisconnect() {
        return enqueue(() =>
          stopWith((activeRecorder) => activeRecorder.disconnect()),
        );
      },

      stopAutomaticRecording() {
        return enqueue(() => stopWith((activeRecorder) => activeRecorder.stop()));
      },

      flushActiveReport() {
        return enqueue(async () => {
          if (!(recorder?.hasActiveWork() ?? false)) return;
          await persistActiveDraft();
        });
      },

      recoverInterruptedReport() {
        return enqueue(async () => {
          const active = await repository.readActive();
          if (!active || active.points.length === 0) {
            if (active) await repository.clearActive();
            return false;
          }
          const timestamp = now();
          const recovered: LandingReport = {
            ...active,
            endedAt: timestamp,
            status: 'incomplete',
            endReason: 'page_closed',
            updatedAt: timestamp,
          };
          await persistFinalReport(recovered, set, get);
          return true;
        });
      },

      deleteReport(id) {
        return enqueue(async () => {
          await repository.remove(id);
          set({
            reports: get().reports.filter((report) => report.id !== id),
            selectedReport:
              get().selectedReport?.id === id ? undefined : get().selectedReport,
          });
        });
      },

      selectReport(id) {
        set({ selectedReport: get().reports.find((report) => report.id === id) });
      },
    };
  };
}

function trimPreTouchdownBuffer(points: FlightLogPoint[], timestamp: number): void {
  const cutoff = timestamp - PRE_TOUCHDOWN_MS;
  while (points.length > 0 && points[0].timestamp.getTime() < cutoff) points.shift();
}

function snapshotToPoint(snapshot: FlightDataSnapshot, timestamp: number): FlightLogPoint {
  const data = snapshot.flightData;
  const resolvedG = resolveSnapshotPointG(data);
  return {
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
    timestamp: new Date(timestamp),
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
    flapsPosition: finiteInteger(data.flapsAngle),
    flapsLabel: data.flapsLabel,
    windSpeed: data.windSpeed,
    windDirection: data.windDirection,
    windGust: data.windGust,
    gustDelta: data.gustDelta,
    gustFactorRate: data.gustFactorRate,
    crosswindComponent: data.crosswindComponent,
    radioAltitude: validHeight(data.radioAltitude),
    radioAltitudeSource:
      validHeight(data.radioAltitude) === undefined
        ? undefined
        : data.radioAltitudeSource,
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
    speedBrakePosition: data.speedBrake === undefined ? undefined : Number(data.speedBrake),
    aileronInput: data.aileronInput,
    elevatorInput: data.elevatorInput,
    rudderInput: data.rudderInput,
    aileronTrim: data.aileronTrim,
    elevatorTrim: data.elevatorTrim,
    rudderTrim: data.rudderTrim,
    onGround: data.onGround,
    anomalyAlerts: buildPointAlerts(data.flightAlerts),
  };
}

function resolveSnapshotPointG(data: FlightDataSnapshot['flightData']): {
  value: number;
  source: LandingGSource;
} {
  const gearValues = [
    data.touchdownGearG,
    data.leftGearG,
    data.rightGearG,
    data.noseGearG,
  ].filter(isValidLandingG);
  if (gearValues.length > 0) return { value: Math.max(...gearValues), source: 'gear' };
  if (data.gForce !== undefined && Number.isFinite(data.gForce)) {
    return { value: data.gForce, source: 'body' };
  }
  return { value: 1, source: 'fallback' };
}

function resolveSnapshotPointGPeak(
  data: FlightDataSnapshot['flightData'],
): number | undefined {
  return [data.touchdownGearGPeak, data.gForcePeak].find(isValidLandingG);
}

function isValidLandingG(value: number | undefined): value is number {
  return (
    value !== undefined &&
    Number.isFinite(value) &&
    value >= MIN_VALID_LANDING_G &&
    value <= MAX_VALID_LANDING_G
  );
}

function validHeight(value: number | undefined): number | undefined {
  return value !== undefined && Number.isFinite(value) && value >= 0 ? value : undefined;
}

function finiteInteger(value: number | undefined): number | undefined {
  return value !== undefined && Number.isFinite(value) ? Math.round(value) : undefined;
}

function buildPointAlerts(alerts: FlightDataSnapshot['flightData']['flightAlerts']): FlightLogAlert[] {
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

function simulatorLabel(type: SimulatorType): string {
  if (type === 'msfs') return 'MSFS';
  if (type === 'xplane') return 'X-Plane';
  return 'Unknown';
}

function sortReports(reports: LandingReport[]): LandingReport[] {
  return [...reports].sort(
    (left, right) => right.startedAt - left.startedAt || right.updatedAt - left.updatedAt,
  );
}

export const useLandingReportsStore = create<LandingReportsState>(
  landingReportsStateCreator({
    repository: landingReportsRepository,
    settings: PersistenceService,
  }),
);
