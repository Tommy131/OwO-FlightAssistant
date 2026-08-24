import { create, type StateCreator } from 'zustand';
import { createStore, type StoreApi } from 'zustand/vanilla';

import { PersistenceService } from '../../../core/services/persistence-service';
import { AppLogger } from '../../../core/utils/logger';
import type { FlightDataSnapshot, SimulatorType } from '../../common/models/common-models';
import type { MapRunwayGeometry } from '../../map/models/map-models';
import type {
  FlightLogAlert,
  FlightLogPoint,
  LandingGSource,
} from '../models/flight-log-models';
import type {
  LandingReport,
  StoredLandingReport,
} from '../models/landing-report-models';
import {
  createLandingReportRecorder,
  type LandingRecorderEvent,
  type LandingReportRecorder,
  type LandingReportRecorderOptions,
} from '../services/landing-report-recorder';
import {
  landingReportsRepository,
  type LandingReportsRepository,
} from '../services/landing-reports-repository';
import {
  computeLandingMetrics,
  MAX_VALID_LANDING_G,
  MIN_VALID_LANDING_G,
} from '../services/takeoff-landing-metrics';
import { lookupRunwayAt } from '../services/runway-lookup';

const SETTINGS_MODULE = 'landing_reports';
const ENABLED_SETTING_KEY = 'automatic_enabled';

export interface LandingReportsSettingsPersistence {
  ensureReady: () => Promise<void>;
  getModuleData: <T>(moduleName: string, key: string) => T | undefined;
  setModuleData: (moduleName: string, key: string, value: unknown) => Promise<void>;
}

export interface LandingReportsState {
  enabled: boolean;
  reports: StoredLandingReport[];
  selectedReport: StoredLandingReport | undefined;
  hasActiveWork: boolean;

  initialize: () => Promise<void>;
  setEnabled: (enabled: boolean) => Promise<void>;
  handleFlightSnapshot: (snapshot: FlightDataSnapshot) => Promise<void>;
  handleDisconnect: () => Promise<void>;
  stopAutomaticRecording: () => Promise<void>;
  flushActiveReport: () => Promise<void>;
  recoverInterruptedReport: () => Promise<boolean>;
  deleteReport: (id: string) => Promise<void>;
  selectReport: (id: string | undefined) => void;
}

interface LandingReportsStoreDependencies {
  repository: LandingReportsRepository;
  settings: LandingReportsSettingsPersistence;
  createRecorder?: (options: LandingReportRecorderOptions) => LandingReportRecorder;
  now?: () => number;
  createId?: () => string;
  lookupRunway?: (
    icao: string | undefined,
    position: { latitude: number; longitude: number },
  ) => Promise<MapRunwayGeometry | undefined>;
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
  const lookupRunway = dependencies.lookupRunway ?? lookupRunwayAt;

  let recorder: LandingReportRecorder | undefined;
  let paused = false;
  let pendingFinalReport: LandingReport | undefined;
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
    paused = false;
  }

  function ensureRecorder(simulator: string): LandingReportRecorder {
    if (recorder === undefined) {
      recorder = createRecorder({
        now,
        createId,
        simulator,
      });
    }
    return recorder;
  }

  function updateReports(
    set: (partial: Partial<LandingReportsState>) => void,
    get: () => LandingReportsState,
    report: StoredLandingReport,
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
    pendingFinalReport = report;
    set({ hasActiveWork: true });
    // Preserve the exact finalized payload as recovery state before any
    // enrichment or collection write that can fail.
    await repository.writeActive(report);
    const durableReport = await enrichRunway(report, lookupRunway);
    await repository.saveLocal(durableReport);
    await repository.clearActive();
    pendingFinalReport = undefined;
    updateReports(set, get, durableReport);
    startBestEffortSync(durableReport);
  }

  function startBestEffortSync(report: StoredLandingReport): void {
    try {
      void repository.sync(report).catch((error: unknown) => {
        AppLogger.warning(`[LandingReports] sync ${report.id} failed: ${String(error)}`);
      });
    } catch (error) {
      AppLogger.warning(`[LandingReports] sync ${report.id} failed: ${String(error)}`);
    }
  }

  async function persistEvents(
    events: LandingRecorderEvent[],
    set: (partial: Partial<LandingReportsState>) => void,
    get: () => LandingReportsState,
  ): Promise<void> {
    for (const event of events) {
      await persistFinalReport(event.report, set, get);
      if (event.report.endReason !== 'touch_and_go') resetCapture();
    }
  }

  async function drainPendingFinal(
    set: (partial: Partial<LandingReportsState>) => void,
    get: () => LandingReportsState,
  ): Promise<void> {
    const pending = pendingFinalReport;
    if (!pending) return;
    await persistFinalReport(pending, set, get);
    if (pending.endReason !== 'touch_and_go') resetCapture();
  }

  async function persistActiveDraft(): Promise<void> {
    const next = recorder?.getRecoverableReport();
    if (!next) return;
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
          const reports = sortReports(await repository.list());
          const selectedId = get().selectedReport?.id;
          set({
            reports,
            selectedReport:
              selectedId === undefined
                ? undefined
                : reports.find((report) => report.id === selectedId),
          });
        });
      },

      setEnabled(enabled) {
        return enqueue(async () => {
          await drainPendingFinal(set, get);
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
          await drainPendingFinal(set, get);
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

          const point = snapshotToPoint(snapshot, now());
          const events = activeRecorder.push(point, captureContext(snapshot));
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
          const existing = await repository.get(active.id);
          if (existing && existing.updatedAt >= active.updatedAt) {
            await repository.clearActive();
            updateReports(set, get, existing);
            startBestEffortSync(existing);
            return false;
          }
          const timestamp = now();
          const recovered: LandingReport = {
            ...active,
            endedAt: recoveredEndTime(active),
            status: 'incomplete',
            endReason: 'page_closed',
            updatedAt: timestamp,
          };
          await persistFinalReport(recovered, set, get);
          set({ hasActiveWork: false });
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

function captureContext(snapshot: FlightDataSnapshot): {
  aircraftTitle?: string;
  aircraftType?: string;
  airport?: string;
} {
  const data = snapshot.flightData;
  return {
    aircraftTitle:
      normalizeIdentity(snapshot.aircraftTitle) ??
      normalizeIdentity(data.aircraftDisplayName) ??
      normalizeIdentity(data.aircraftModel),
    aircraftType:
      normalizeIdentity(data.aircraftIcao) ??
      normalizeIdentity(data.aircraftModel) ??
      normalizeIdentity(data.aircraftFamily),
    airport:
      normalizeIdentity(snapshot.nearestAirport?.icaoCode)?.toUpperCase() ??
      normalizeIdentity(data.arrivalAirport)?.toUpperCase(),
  };
}

function normalizeIdentity(value: string | undefined): string | undefined {
  const normalized = value?.trim();
  return normalized && normalized.length > 0 ? normalized : undefined;
}

function recoveredEndTime(report: StoredLandingReport): number {
  if (Number.isFinite(report.endedAt) && report.endedAt > 0) return report.endedAt;
  return report.points.at(-1)?.timestamp.getTime() ?? report.startedAt;
}

async function enrichRunway(
  report: LandingReport,
  lookupRunway: (
    icao: string | undefined,
    position: { latitude: number; longitude: number },
  ) => Promise<MapRunwayGeometry | undefined>,
): Promise<LandingReport> {
  const landing = report.landing;
  if (!landing || !report.airport) return report;
  const runway = await lookupRunway(report.airport, {
    latitude: landing.latitude,
    longitude: landing.longitude,
  });
  if (!runway) return report;
  const metrics = computeLandingMetrics(
    { points: report.points, landingData: landing },
    runway,
  );
  const metricNotes = { ...(landing.metricNotes ?? {}), ...metrics.unavailable };
  if (metrics.remainingRunwayFt !== undefined) delete metricNotes.remainingRunwayFt;
  if (metrics.approachStabilityScore !== undefined) {
    delete metricNotes.approachStabilityScore;
  }
  return {
    ...report,
    landing: {
      ...landing,
      runway: runway.ident,
      approachStabilityScore: metrics.approachStabilityScore,
      remainingRunwayFt: metrics.remainingRunwayFt,
      metricNotes: Object.keys(metricNotes).length > 0 ? metricNotes : undefined,
    },
  };
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
    autoBrakeLabel: data.autoBrakeLabel,
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

function sortReports(reports: StoredLandingReport[]): StoredLandingReport[] {
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
