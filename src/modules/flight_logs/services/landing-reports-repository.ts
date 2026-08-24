import {
  del as idbDel,
  get as idbGet,
  set as idbSet,
  update as idbUpdate,
} from 'idb-keyval';
import {
  pullRecordState,
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
  type StoredLandingReport,
} from '../models/landing-report-models';

const MODULE_NAME = 'landing_reports';
const REPORTS_KEY = 'reports';
const DELETED_REPORT_IDS_KEY = 'deleted_report_ids';

export const LANDING_REPORTS_STATE_KEY =
  'owo-flight-assistant/landing-reports/state-v1';

export const ACTIVE_LANDING_REPORT_KEY =
  'owo-flight-assistant/landing-reports/active';

export interface LandingReportsPersistence {
  ensureReady: () => Promise<void>;
  getModuleData: <T>(moduleName: string, key: string) => T | undefined;
  getDurableModuleData: <T>(
    moduleName: string,
    key: string,
  ) => Promise<T | undefined>;
  setModuleData: (
    moduleName: string,
    key: string,
    value: unknown,
  ) => Promise<void>;
}

export interface LandingReportsArchiveStorage {
  get: (key: string) => Promise<unknown>;
  set: (key: string, value: unknown) => Promise<void>;
  update: (
    key: string,
    updater: (current: unknown) => unknown,
  ) => Promise<void>;
  remove: (key: string) => Promise<void>;
}

export interface LandingReportsBackend {
  push: (report: StoredLandingReport, expectedRevision: number) => Promise<SyncResult>;
  remove: (id: string, expectedRevision: number) => Promise<SyncResult>;
  pull: () => Promise<LandingReportsRemoteState | unknown[] | null>;
}

export interface LandingReportsRemoteState {
  records: unknown[];
  revisions: Record<string, number>;
  tombstones: Array<{ id: string; revision: number; deleted: true }>;
}

export interface LandingReportsRepository {
  list: () => Promise<StoredLandingReport[]>;
  get: (id: string) => Promise<StoredLandingReport | undefined>;
  save: (report: StoredLandingReport) => Promise<void>;
  remove: (id: string) => Promise<void>;
  writeActive: (report: LandingReport) => Promise<void>;
  readActive: () => Promise<StoredLandingReport | undefined>;
  clearActive: () => Promise<void>;
  reconcile: () => Promise<void>;

  /** Split operations let finalization clear recovery state before network IO. */
  saveLocal: (report: StoredLandingReport) => Promise<void>;
  sync: (report: StoredLandingReport) => Promise<void>;
}

interface LandingReportsRepositoryDependencies {
  persistence?: LandingReportsPersistence;
  backend?: LandingReportsBackend;
  archiveStorage?: LandingReportsArchiveStorage;
}

const productionBackend: LandingReportsBackend = {
  push: (report, expectedRevision) =>
    pushRecord('landingReport', report.id, serializeLandingReport(report), {
      expectedRevision,
    }),
  remove: (id, expectedRevision) =>
    removeRecord('landingReport', id, { expectedRevision }),
  pull: () => pullRecordState('landingReport'),
};

const productionArchiveStorage: LandingReportsArchiveStorage = {
  get: (key) => idbGet(key),
  set: (key, value) => idbSet(key, value),
  update: (key, updater) => idbUpdate(key, updater),
  remove: (key) => idbDel(key),
};

export function createLandingReportsRepository(
  dependencies: LandingReportsRepositoryDependencies = {},
): LandingReportsRepository {
  const persistence = dependencies.persistence ?? PersistenceService;
  const backend = dependencies.backend ?? productionBackend;
  const archiveStorage = dependencies.archiveStorage ?? productionArchiveStorage;
  let operationQueue = Promise.resolve();
  let initializationPromise: Promise<void> | undefined;

  function serialized<T>(operation: () => Promise<T>): Promise<T> {
    const result = operationQueue.then(operation, operation);
    operationQueue = result.then(
      () => undefined,
      () => undefined,
    );
    return result;
  }

  async function ensureState(): Promise<void> {
    if (initializationPromise) return initializationPromise;
    const attempt = (async () => {
      const existing = await archiveStorage.get(LANDING_REPORTS_STATE_KEY);
      if (existing !== undefined) {
        decodeLocalState(existing);
        return;
      }

      // Migration deliberately reads the last successful local IndexedDB root,
      // not the in-memory settings overlay, so a stale remote bucket cannot
      // replace an offline-only report before reconciliation.
      await persistence.ensureReady();
      const [legacyReports, legacyDeletedIds] = await Promise.all([
        persistence.getDurableModuleData<unknown[]>(MODULE_NAME, REPORTS_KEY),
        persistence.getDurableModuleData<unknown[]>(
          MODULE_NAME,
          DELETED_REPORT_IDS_KEY,
        ),
      ]);
      const reports = decodeReports(legacyReports);
      const tombstones = Array.isArray(legacyDeletedIds)
        ? legacyDeletedIds
            .filter(
              (id): id is string => typeof id === 'string' && id.trim().length > 0,
            )
            .map((id) => ({ id, revision: 0 }))
        : [];
      const migrated: LandingReportsLocalState = {
        version: 1,
        reports,
        revisions: Object.fromEntries(reports.map((report) => [report.id, 0])),
        tombstones,
      };
      await archiveStorage.update(
        LANDING_REPORTS_STATE_KEY,
        (current) => current ?? encodeLocalState(migrated),
      );
    })();
    initializationPromise = attempt;
    try {
      await attempt;
    } catch (error) {
      if (initializationPromise === attempt) initializationPromise = undefined;
      throw error;
    }
  }

  async function readState(): Promise<LandingReportsLocalState> {
    await ensureState();
    const raw = await archiveStorage.get(LANDING_REPORTS_STATE_KEY);
    if (raw === undefined) throw new Error('landing reports state disappeared');
    return decodeLocalState(raw);
  }

  async function updateState<T>(
    updater: (state: LandingReportsLocalState) => T,
  ): Promise<T> {
    await ensureState();
    let updated = false;
    let result: T | undefined;
    await archiveStorage.update(LANDING_REPORTS_STATE_KEY, (raw) => {
      if (raw === undefined) throw new Error('landing reports state disappeared');
      const state = decodeLocalState(raw);
      result = updater(state);
      updated = true;
      return encodeLocalState(state);
    });
    if (!updated) throw new Error('landing reports state update did not run');
    return result as T;
  }

  async function saveLocalUnlocked(report: StoredLandingReport): Promise<void> {
    await updateState((state) => {
      if (state.tombstones.some((item) => item.id === report.id)) {
        throw new Error(`landing report ${report.id} was deleted`);
      }
      state.reports = [
        report,
        ...state.reports.filter((item) => item.id !== report.id),
      ];
      state.revisions[report.id] ??= 0;
    });
  }

  async function syncReportUnlocked(report: StoredLandingReport): Promise<boolean> {
    const state = await readState();
    if (state.tombstones.some((item) => item.id === report.id)) return false;
    const expectedRevision = state.revisions[report.id] ?? 0;
    try {
      const result = await backend.push(report, expectedRevision);
      if (result.ok) {
        if (result.revision !== undefined) {
          await updateState((current) => {
            if (
              current.reports.some((item) => item.id === report.id) &&
              !current.tombstones.some((item) => item.id === report.id)
            ) {
              current.revisions[report.id] = Math.max(
                current.revisions[report.id] ?? 0,
                result.revision!,
              );
            }
          });
        }
        return true;
      }
      if (result.conflict && result.deleted) {
        await updateState((current) => {
          current.reports = current.reports.filter((item) => item.id !== report.id);
          upsertTombstone(current, report.id, result.revision ?? expectedRevision);
          delete current.revisions[report.id];
        });
      }
      return false;
    } catch (error) {
      AppLogger.warning(
        `[LandingReports] sync ${report.id} failed: ${String(error)}`,
      );
      return false;
    }
  }

  async function syncRemovalUnlocked(
    id: string,
    expectedRevision: number,
  ): Promise<boolean> {
    try {
      let result = await backend.remove(id, expectedRevision);
      // A deletion intent may legitimately outlive a stale local revision.
      // Retry once with the authoritative revision returned by the server.
      if (
        result.conflict &&
        !result.deleted &&
        result.revision !== undefined &&
        result.revision !== expectedRevision
      ) {
        result = await backend.remove(id, result.revision);
      }
      if (result.ok || (result.conflict && result.deleted)) {
        await updateState((state) => {
          upsertTombstone(state, id, result.revision ?? expectedRevision);
        });
        return true;
      }
      return false;
    } catch (error) {
      AppLogger.warning(`[LandingReports] remove ${id} failed: ${String(error)}`);
      return false;
    }
  }

  async function removeUnlocked(id: string): Promise<void> {
    const expectedRevision = await updateState((state) => {
      const revision = state.revisions[id] ?? tombstoneRevision(state, id) ?? 0;
      state.reports = state.reports.filter((report) => report.id !== id);
      delete state.revisions[id];
      upsertTombstone(state, id, revision);
      return revision;
    });
    // The report removal and deletion intent share one atomic IndexedDB value.
    await syncRemovalUnlocked(id, expectedRevision);
  }

  const repository: LandingReportsRepository = {
    async list() {
      return sortReports((await readState()).reports);
    },

    async get(id) {
      return (await readState()).reports.find((report) => report.id === id);
    },

    async saveLocal(report) {
      return serialized(() => saveLocalUnlocked(report));
    },

    async sync(report) {
      await serialized(() => syncReportUnlocked(report));
    },

    async save(report) {
      await serialized(async () => {
        await saveLocalUnlocked(report);
        await syncReportUnlocked(report);
      });
    },

    async remove(id) {
      await serialized(() => removeUnlocked(id));
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
      await serialized(async () => {
        let pulled: LandingReportsRemoteState | unknown[] | null;
        try {
          pulled = await backend.pull();
        } catch (error) {
          AppLogger.warning(`[LandingReports] pull failed: ${String(error)}`);
          return;
        }
        if (pulled === null) return;
        const remote = normalizeRemoteState(pulled);
        const remoteReports = decodeReports(remote.records);
        const remoteById = new Map(remoteReports.map((report) => [report.id, report]));
        const remoteTombstones = new Map(
          remote.tombstones.map((item) => [item.id, item.revision]),
        );
        const localWinners: Array<{ report: StoredLandingReport; expected: number }> = [];
        let tombstonesToSync: Array<{ id: string; revision: number }> = [];
        await updateState((state) => {
          for (const [id, revision] of remoteTombstones) {
            state.reports = state.reports.filter((report) => report.id !== id);
            delete state.revisions[id];
            upsertTombstone(state, id, revision);
          }

          const localTombstones = new Map(
            state.tombstones.map((item) => [item.id, item.revision]),
          );
          const localById = new Map(
            state.reports.map((report) => [report.id, report]),
          );
          const reconciled = new Map<string, StoredLandingReport>();
          const ids = new Set([...localById.keys(), ...remoteById.keys()]);
          for (const id of ids) {
            if (localTombstones.has(id) || remoteTombstones.has(id)) continue;
            const localReport = localById.get(id);
            const remoteReport = remoteById.get(id);
            const localRevision = state.revisions[id] ?? 0;
            const remoteRevision =
              remote.revisions[id] ?? embeddedRevision(remoteReport) ?? 0;
            if (!localReport && remoteReport) {
              reconciled.set(id, remoteReport);
              state.revisions[id] = remoteRevision;
              continue;
            }
            if (localReport && !remoteReport) {
              reconciled.set(id, localReport);
              localWinners.push({ report: localReport, expected: remoteRevision });
              continue;
            }
            if (!localReport || !remoteReport) continue;
            const localWins =
              localRevision > remoteRevision ||
              (localRevision === remoteRevision &&
                localReport.updatedAt > remoteReport.updatedAt);
            if (localWins) {
              reconciled.set(id, localReport);
              localWinners.push({ report: localReport, expected: remoteRevision });
            } else {
              reconciled.set(id, remoteReport);
              state.revisions[id] = remoteRevision;
            }
          }
          state.reports = [...reconciled.values()];
          tombstonesToSync = state.tombstones.map((item) => ({ ...item }));
        });

        for (const { report: candidate, expected } of localWinners) {
          try {
            const current = await readState();
            if (current.tombstones.some((item) => item.id === candidate.id)) continue;
            const report = current.reports.find((item) => item.id === candidate.id);
            if (!report) continue;
            const result = await backend.push(report, expected);
            if (result.ok && result.revision !== undefined) {
              await updateState((state) => {
                if (
                  state.reports.some((item) => item.id === report.id) &&
                  !state.tombstones.some((item) => item.id === report.id)
                ) {
                  state.revisions[report.id] = Math.max(
                    state.revisions[report.id] ?? 0,
                    result.revision!,
                  );
                }
              });
            } else if (result.conflict && result.deleted) {
              await updateState((state) => {
                state.reports = state.reports.filter((item) => item.id !== report.id);
                delete state.revisions[report.id];
                upsertTombstone(state, report.id, result.revision ?? expected);
              });
            }
          } catch (error) {
            AppLogger.warning(
              `[LandingReports] sync ${candidate.id} failed: ${String(error)}`,
            );
          }
        }

        for (const tombstone of tombstonesToSync) {
          if (remoteTombstones.has(tombstone.id)) continue;
          const expected = remote.revisions[tombstone.id] ?? tombstone.revision;
          const current = await readState();
          if (!current.tombstones.some((item) => item.id === tombstone.id)) continue;
          await syncRemovalUnlocked(tombstone.id, expected);
        }
      });
    },
  };

  return repository;
}

interface LandingReportsLocalState {
  version: 1;
  reports: StoredLandingReport[];
  revisions: Record<string, number>;
  tombstones: Array<{ id: string; revision: number }>;
}

function encodeLocalState(state: LandingReportsLocalState): string {
  return JSON.stringify({
    version: 1,
    reports: sortReports(state.reports).map(serializeLandingReport),
    revisions: sanitizeRevisions(state.revisions),
    tombstones: sortTombstones(state.tombstones),
  });
}

function decodeLocalState(raw: unknown): LandingReportsLocalState {
  const decoded = typeof raw === 'string' ? JSON.parse(raw) as unknown : raw;
  const map = toJsonMap(decoded);
  if (!map || map.version !== 1) throw new Error('invalid landing reports state');
  return {
    version: 1,
    reports: decodeReports(map.reports),
    revisions: sanitizeRevisions(map.revisions),
    tombstones: decodeTombstones(map.tombstones),
  };
}

function decodeReports(raw: unknown): StoredLandingReport[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .map(toJsonMap)
    .filter((item): item is JsonMap => item !== null && toText(item.id).length > 0)
    .map(deserializeLandingReport);
}

function decodeTombstones(raw: unknown): Array<{ id: string; revision: number }> {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((item) => {
    const map = toJsonMap(item);
    const id = toText(map?.id).trim();
    const revision = safeRevision(map?.revision);
    return id.length > 0 && revision !== undefined ? [{ id, revision }] : [];
  });
}

function sanitizeRevisions(raw: unknown): Record<string, number> {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {};
  const revisions: Record<string, number> = {};
  for (const [id, value] of Object.entries(raw)) {
    const revision = safeRevision(value);
    if (id.length > 0 && revision !== undefined) revisions[id] = revision;
  }
  return revisions;
}

function normalizeRemoteState(
  raw: LandingReportsRemoteState | unknown[],
): LandingReportsRemoteState {
  if (Array.isArray(raw)) {
    const reports = decodeReports(raw);
    return {
      records: raw,
      revisions: Object.fromEntries(
        reports.map((report) => [report.id, embeddedRevision(report) ?? 0]),
      ),
      tombstones: [],
    };
  }
  return {
    records: Array.isArray(raw.records) ? raw.records : [],
    revisions: sanitizeRevisions(raw.revisions),
    tombstones: decodeTombstones(raw.tombstones).map((item) => ({
      ...item,
      deleted: true,
    })),
  };
}

function embeddedRevision(report: StoredLandingReport | undefined): number | undefined {
  if (!report) return undefined;
  return safeRevision((report as StoredLandingReport & { _storage_revision?: unknown })._storage_revision);
}

function safeRevision(raw: unknown): number | undefined {
  return typeof raw === 'number' && Number.isSafeInteger(raw) && raw >= 0
    ? raw
    : undefined;
}

function tombstoneRevision(
  state: LandingReportsLocalState,
  id: string,
): number | undefined {
  return state.tombstones.find((item) => item.id === id)?.revision;
}

function upsertTombstone(
  state: LandingReportsLocalState,
  id: string,
  revision: number,
): void {
  const existing = state.tombstones.find((item) => item.id === id);
  if (existing) existing.revision = Math.max(existing.revision, revision);
  else state.tombstones.push({ id, revision });
}

function sortTombstones(
  tombstones: Array<{ id: string; revision: number }>,
): Array<{ id: string; revision: number }> {
  return [...tombstones].sort((left, right) => left.id.localeCompare(right.id));
}

function sortReports(reports: StoredLandingReport[]): StoredLandingReport[] {
  return [...reports].sort(
    (left, right) => right.startedAt - left.startedAt || right.updatedAt - left.updatedAt,
  );
}

export const landingReportsRepository = createLandingReportsRepository();
