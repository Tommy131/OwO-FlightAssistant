import { del as idbDel, get as idbGet, set as idbSet } from 'idb-keyval';
import {
  pullRecords,
  pushRecord,
  removeRecord,
  type SyncResult,
} from '../../../core/services/backend-sync';
import { PersistenceService } from '../../../core/services/persistence-service';
import { AppLogger } from '../../../core/utils/logger';
import { toJsonMap, toText, type JsonMap } from '../../../core/utils/parse-utils';
import {
  deserializeLandingReport,
  serializeLandingReport,
  type LandingReport,
} from '../models/landing-report-models';

const MODULE_NAME = 'landing_reports';
const REPORTS_KEY = 'reports';
const DELETED_REPORT_IDS_KEY = 'deleted_report_ids';

export const ACTIVE_LANDING_REPORT_KEY =
  'owo-flight-assistant/landing-reports/active';

export interface LandingReportsPersistence {
  ensureReady: () => Promise<void>;
  getModuleData: <T>(moduleName: string, key: string) => T | undefined;
  setModuleData: (
    moduleName: string,
    key: string,
    value: unknown,
  ) => Promise<void>;
}

export interface LandingReportsArchiveStorage {
  get: (key: string) => Promise<unknown>;
  set: (key: string, value: unknown) => Promise<void>;
  remove: (key: string) => Promise<void>;
}

export interface LandingReportsBackend {
  push: (report: LandingReport) => Promise<SyncResult>;
  remove: (id: string) => Promise<SyncResult>;
  pull: () => Promise<unknown[] | null>;
}

export interface LandingReportsRepository {
  list: () => Promise<LandingReport[]>;
  get: (id: string) => Promise<LandingReport | undefined>;
  save: (report: LandingReport) => Promise<void>;
  remove: (id: string) => Promise<void>;
  writeActive: (report: LandingReport) => Promise<void>;
  readActive: () => Promise<LandingReport | undefined>;
  clearActive: () => Promise<void>;
  reconcile: () => Promise<void>;

  /** Split operations let finalization clear recovery state before network IO. */
  saveLocal: (report: LandingReport) => Promise<void>;
  sync: (report: LandingReport) => Promise<void>;
}

interface LandingReportsRepositoryDependencies {
  persistence?: LandingReportsPersistence;
  backend?: LandingReportsBackend;
  archiveStorage?: LandingReportsArchiveStorage;
}

const productionBackend: LandingReportsBackend = {
  push: (report) =>
    pushRecord('landingReport', report.id, serializeLandingReport(report)),
  remove: (id) => removeRecord('landingReport', id),
  pull: () => pullRecords('landingReport'),
};

const productionArchiveStorage: LandingReportsArchiveStorage = {
  get: (key) => idbGet(key),
  set: (key, value) => idbSet(key, value),
  remove: (key) => idbDel(key),
};

export function createLandingReportsRepository(
  dependencies: LandingReportsRepositoryDependencies = {},
): LandingReportsRepository {
  const persistence = dependencies.persistence ?? PersistenceService;
  const backend = dependencies.backend ?? productionBackend;
  const archiveStorage = dependencies.archiveStorage ?? productionArchiveStorage;

  async function readLocalReports(): Promise<LandingReport[]> {
    await persistence.ensureReady();
    const raw = persistence.getModuleData<unknown[]>(MODULE_NAME, REPORTS_KEY);
    if (!Array.isArray(raw)) return [];
    return raw
      .map(toJsonMap)
      .filter((item): item is JsonMap => item !== null && toText(item.id).length > 0)
      .map(deserializeLandingReport);
  }

  async function writeLocalReports(reports: LandingReport[]): Promise<void> {
    await persistence.setModuleData(
      MODULE_NAME,
      REPORTS_KEY,
      sortReports(reports).map(serializeLandingReport),
    );
  }

  async function readDeletedIds(): Promise<Set<string>> {
    await persistence.ensureReady();
    const raw = persistence.getModuleData<unknown[]>(MODULE_NAME, DELETED_REPORT_IDS_KEY);
    return new Set(
      Array.isArray(raw)
        ? raw.filter((item): item is string => typeof item === 'string' && item.length > 0)
        : [],
    );
  }

  async function writeDeletedIds(ids: ReadonlySet<string>): Promise<void> {
    await persistence.setModuleData(MODULE_NAME, DELETED_REPORT_IDS_KEY, [...ids]);
  }

  async function syncReport(report: LandingReport): Promise<boolean> {
    try {
      return (await backend.push(report)).ok;
    } catch (error) {
      AppLogger.warning(
        `[LandingReports] sync ${report.id} failed: ${String(error)}`,
      );
      return false;
    }
  }

  async function syncRemoval(id: string): Promise<boolean> {
    try {
      return (await backend.remove(id)).ok;
    } catch (error) {
      AppLogger.warning(`[LandingReports] remove ${id} failed: ${String(error)}`);
      return false;
    }
  }

  const repository: LandingReportsRepository = {
    async list() {
      return sortReports(await readLocalReports());
    },

    async get(id) {
      return (await readLocalReports()).find((report) => report.id === id);
    },

    async saveLocal(report) {
      const existing = (await readLocalReports()).filter((item) => item.id !== report.id);
      await writeLocalReports([report, ...existing]);

      const deletedIds = await readDeletedIds();
      if (deletedIds.delete(report.id)) await writeDeletedIds(deletedIds);
    },

    async sync(report) {
      await syncReport(report);
    },

    async save(report) {
      await repository.saveLocal(report);
      await repository.sync(report);
    },

    async remove(id) {
      const next = (await readLocalReports()).filter((report) => report.id !== id);
      await writeLocalReports(next);

      const deletedIds = await readDeletedIds();
      deletedIds.add(id);
      await writeDeletedIds(deletedIds);

      if (await syncRemoval(id)) {
        deletedIds.delete(id);
        await writeDeletedIds(deletedIds);
      }
    },

    async writeActive(report) {
      await archiveStorage.set(
        ACTIVE_LANDING_REPORT_KEY,
        JSON.stringify(serializeLandingReport(report)),
      );
    },

    async readActive() {
      const encoded = await archiveStorage.get(ACTIVE_LANDING_REPORT_KEY);
      if (typeof encoded !== 'string') {
        if (encoded !== undefined) await archiveStorage.remove(ACTIVE_LANDING_REPORT_KEY);
        return undefined;
      }
      try {
        const raw = toJsonMap(JSON.parse(encoded));
        if (!raw || toText(raw.id).length === 0) throw new Error('invalid archive');
        return deserializeLandingReport(raw);
      } catch (error) {
        AppLogger.warning(
          `[LandingReports] discarded malformed active archive: ${String(error)}`,
        );
        await archiveStorage.remove(ACTIVE_LANDING_REPORT_KEY);
        return undefined;
      }
    },

    async clearActive() {
      await archiveStorage.remove(ACTIVE_LANDING_REPORT_KEY);
    },

    async reconcile() {
      const local = await readLocalReports();
      const deletedIds = await readDeletedIds();

      let remoteRaw: unknown[] | null;
      try {
        remoteRaw = await backend.pull();
      } catch (error) {
        AppLogger.warning(`[LandingReports] pull failed: ${String(error)}`);
        return;
      }
      if (remoteRaw === null) return;

      const remote = remoteRaw
        .map(toJsonMap)
        .filter((item): item is JsonMap => item !== null && toText(item.id).length > 0)
        .map(deserializeLandingReport)
        .filter((report) => !deletedIds.has(report.id));

      const remoteById = new Map(remote.map((report) => [report.id, report]));
      const reconciled = new Map(remoteById);
      const localWinners: LandingReport[] = [];
      for (const report of local) {
        if (deletedIds.has(report.id)) continue;
        const remoteReport = remoteById.get(report.id);
        if (!remoteReport || report.updatedAt > remoteReport.updatedAt) {
          reconciled.set(report.id, report);
          localWinners.push(report);
        }
      }

      await writeLocalReports([...reconciled.values()]);
      for (const report of localWinners) await syncReport(report);

      const remainingDeletedIds = new Set<string>();
      for (const id of deletedIds) {
        if (!(await syncRemoval(id))) remainingDeletedIds.add(id);
      }
      await writeDeletedIds(remainingDeletedIds);
    },
  };

  return repository;
}

function sortReports(reports: LandingReport[]): LandingReport[] {
  return [...reports].sort(
    (left, right) => right.startedAt - left.startedAt || right.updatedAt - left.updatedAt,
  );
}

export const landingReportsRepository = createLandingReportsRepository();
