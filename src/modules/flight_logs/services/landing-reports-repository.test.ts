import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { SyncResult } from '../../../core/services/backend-sync';
import { AppLogger } from '../../../core/utils/logger';
import { serializeLandingReport, type LandingReport } from '../models/landing-report-models';
import { makeFlightLogPoint } from '../test/flight-log-fixtures';
import {
  ACTIVE_LANDING_REPORT_KEY,
  LANDING_REPORTS_STATE_KEY,
  createLandingReportsRepository,
  type LandingReportsArchiveStorage,
  type LandingReportsBackend,
  type LandingReportsPersistence,
} from './landing-reports-repository';

function report(overrides: Partial<LandingReport> = {}): LandingReport {
  const point = makeFlightLogPoint(0, { onGround: false, radioAltitude: 100 });
  return {
    id: 'lr-1',
    simulator: 'MSFS',
    startedAt: 1_000,
    endedAt: 2_000,
    status: 'completed',
    endReason: 'stable_landing',
    points: [point],
    createdAt: 3_000,
    updatedAt: 4_000,
    ...overrides,
  };
}

function createHarness() {
  const modules = new Map<string, unknown>();
  const durableModules = new Map<string, unknown>();
  const archive = new Map<string, unknown>();
  const order: string[] = [];
  let archiveUpdateQueue = Promise.resolve();
  const getDurableModuleData = vi.fn((moduleName: string, key: string) =>
    Promise.resolve(durableModules.get(`${moduleName}/${key}`))) as unknown as
    LandingReportsPersistence['getDurableModuleData'];
  const persistence: LandingReportsPersistence & {
    getDurableModuleData: <T>(moduleName: string, key: string) => Promise<T | undefined>;
  } = {
    ensureReady: vi.fn().mockResolvedValue(undefined),
    getModuleData: <T>(moduleName: string, key: string) =>
      modules.get(`${moduleName}/${key}`) as T | undefined,
    getDurableModuleData,
    setModuleData: vi.fn(async (moduleName: string, key: string, value: unknown) => {
      order.push('local');
      modules.set(`${moduleName}/${key}`, value);
    }),
  };
  const archiveStorage: LandingReportsArchiveStorage & {
    update: (
      key: string,
      updater: (current: unknown) => unknown,
    ) => Promise<void>;
  } = {
    get: vi.fn((key: string) => Promise.resolve(archive.get(key))),
    set: vi.fn(async (key: string, value: unknown) => {
      if (key === LANDING_REPORTS_STATE_KEY) order.push('local');
      archive.set(key, value);
    }),
    remove: vi.fn(async (key: string) => {
      archive.delete(key);
    }),
    update: vi.fn((key: string, updater: (current: unknown) => unknown) => {
      const result = archiveUpdateQueue.then(() => {
        if (key === LANDING_REPORTS_STATE_KEY) order.push('local');
        archive.set(key, updater(archive.get(key)));
      });
      archiveUpdateQueue = result.then(
        () => undefined,
        () => undefined,
      );
      return result;
    }),
  };
  const online: SyncResult = { ok: true, offline: false };
  const backend: LandingReportsBackend = {
    push: vi.fn(async () => {
      order.push('sync');
      return online;
    }),
    remove: vi.fn().mockResolvedValue(online),
    pull: vi.fn().mockResolvedValue([]),
  };
  return {
    repository: createLandingReportsRepository({ persistence, backend, archiveStorage }),
    persistence,
    archiveStorage,
    backend,
    modules,
    durableModules,
    archive,
    order,
    createSecondRepository: () =>
      createLandingReportsRepository({ persistence, backend, archiveStorage }),
  };
}

describe('landing reports repository', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.spyOn(AppLogger, 'warning').mockImplementation(() => undefined);
  });

  it('writes locally before attempting backend sync and remains readable offline', async () => {
    const { repository, backend, order } = createHarness();
    vi.mocked(backend.push).mockRejectedValue(new Error('offline'));

    await repository.save(report());

    expect(await repository.get('lr-1')).toEqual(report());
    expect(order).toEqual(['local', 'local']);
    expect(backend.push).toHaveBeenCalledWith(report(), 0);
  });

  it('stores reports in a dedicated local-only IndexedDB state instead of settings', async () => {
    const { repository, persistence, archive } = createHarness();

    await repository.saveLocal(report());

    expect(persistence.setModuleData).not.toHaveBeenCalled();
    expect(archive.has('owo-flight-assistant/landing-reports/state-v1')).toBe(true);
    expect(await repository.get('lr-1')).toEqual(report());
  });

  it('propagates a rejected dedicated IndexedDB write', async () => {
    const { repository, archiveStorage } = createHarness();
    vi.mocked(archiveStorage.update).mockRejectedValueOnce(new Error('quota exceeded'));

    await expect(repository.saveLocal(report())).rejects.toThrow('quota exceeded');
    expect(await repository.get('lr-1')).toBeUndefined();
  });

  it('migrates the durable local legacy bucket without accepting a stale remote overlay', async () => {
    const { repository, modules, durableModules, archive } = createHarness();
    const offlineOnly = report({ id: 'offline-only', updatedAt: 50 });
    const staleRemoteOverlay = report({ id: 'stale-remote', updatedAt: 10 });
    durableModules.set('landing_reports/reports', [serializeLandingReport(offlineOnly)]);
    modules.set('landing_reports/reports', [serializeLandingReport(staleRemoteOverlay)]);

    expect(await repository.list()).toEqual([offlineOnly]);
    expect(archive.has('owo-flight-assistant/landing-reports/state-v1')).toBe(true);
  });

  it('does not let a late first-run migration overwrite a concurrently saved report', async () => {
    const { repository, persistence } = createHarness();
    let releaseLegacyRead: (() => void) | undefined;
    let markLegacyRead: (() => void) | undefined;
    const legacyReadStarted = new Promise<void>((resolve) => {
      markLegacyRead = resolve;
    });
    const delayedLegacyRead = new Promise<void>((resolve) => {
      releaseLegacyRead = resolve;
    });
    let reportsReads = 0;
    vi.mocked(persistence.getDurableModuleData).mockImplementation(
      async (_moduleName, key) => {
        if (key !== 'reports') return undefined;
        reportsReads += 1;
        if (reportsReads === 1) {
          markLegacyRead?.();
          await delayedLegacyRead;
        }
        return [];
      },
    );

    const listing = repository.list();
    await legacyReadStarted;
    const saving = repository.saveLocal(report({ id: 'saved-during-migration' }));
    expect(await Promise.race([
      saving.then(() => 'completed' as const),
      new Promise<'pending'>((resolve) => setTimeout(() => resolve('pending'), 10)),
    ])).toBe('pending');
    releaseLegacyRead?.();
    await Promise.all([listing, saving]);

    expect((await repository.list()).map((item) => item.id)).toContain(
      'saved-during-migration',
    );
  });

  it('atomically merges offline saves from separate repository instances', async () => {
    const {
      repository,
      createSecondRepository,
      archive,
      archiveStorage,
    } = createHarness();
    archive.set(
      LANDING_REPORTS_STATE_KEY,
      JSON.stringify({ version: 1, reports: [], revisions: {}, tombstones: [] }),
    );
    const second = createSecondRepository();
    let stateReads = 0;
    let releaseReads: (() => void) | undefined;
    const bothRead = new Promise<void>((resolve) => {
      releaseReads = resolve;
    });
    vi.mocked(archiveStorage.get).mockImplementation(async (key) => {
      const value = archive.get(key);
      if (key === LANDING_REPORTS_STATE_KEY && stateReads < 2) {
        stateReads += 1;
        if (stateReads === 2) releaseReads?.();
        await bothRead;
      }
      return value;
    });

    await Promise.all([
      repository.saveLocal(report({ id: 'tab-a' })),
      second.saveLocal(report({ id: 'tab-b' })),
    ]);

    expect((await repository.list()).map((item) => item.id).sort()).toEqual([
      'tab-a',
      'tab-b',
    ]);
    expect(archiveStorage.update).toHaveBeenCalled();
  });

  it('serializes a delayed save and delete for the same report id', async () => {
    const { repository, backend } = createHarness();
    let releasePush: (() => void) | undefined;
    const delayedPush = new Promise<void>((resolve) => {
      releasePush = resolve;
    });
    vi.mocked(backend.push).mockImplementationOnce(async () => {
      await delayedPush;
      return { ok: true, offline: false };
    });

    const saving = repository.save(report());
    await vi.waitFor(() => expect(backend.push).toHaveBeenCalledOnce());
    const deleting = repository.remove('lr-1');
    const earlyDeleteState = await Promise.race([
      deleting.then(() => 'completed' as const),
      new Promise<'pending'>((resolve) => setTimeout(() => resolve('pending'), 10)),
    ]);

    expect(earlyDeleteState).toBe('pending');
    expect(backend.remove).not.toHaveBeenCalled();
    releasePush?.();
    await Promise.all([saving, deleting]);
    expect(backend.remove).toHaveBeenCalledOnce();
    expect(await repository.get('lr-1')).toBeUndefined();
  });

  it('uses a landing-report-specific active archive containing codec JSON', async () => {
    const { repository, archiveStorage } = createHarness();

    await repository.writeActive(report());

    expect(archiveStorage.set).toHaveBeenCalledWith(
      ACTIVE_LANDING_REPORT_KEY,
      JSON.stringify(serializeLandingReport(report())),
    );
    expect(await repository.readActive()).toEqual(report());
  });

  it('reconciles each conflict to the report with the greatest updatedAt', async () => {
    const { repository, backend, durableModules } = createHarness();
    const localWinner = report({ id: 'local-wins', updatedAt: 20 });
    const remoteWinnerLocalCopy = report({ id: 'remote-wins', updatedAt: 10 });
    durableModules.set('landing_reports/reports', [
      serializeLandingReport(localWinner),
      serializeLandingReport(remoteWinnerLocalCopy),
    ]);
    vi.mocked(backend.pull).mockResolvedValue([
      serializeLandingReport(report({ id: 'local-wins', updatedAt: 15 })),
      serializeLandingReport(report({ id: 'remote-wins', updatedAt: 30 })),
    ]);

    await repository.reconcile();

    expect((await repository.get('local-wins'))?.updatedAt).toBe(20);
    expect((await repository.get('remote-wins'))?.updatedAt).toBe(30);
    expect(backend.push).toHaveBeenCalledWith(
      expect.objectContaining({ id: localWinner.id, updatedAt: 20 }),
      0,
    );
    expect(backend.push).not.toHaveBeenCalledWith(
      expect.objectContaining({ id: remoteWinnerLocalCopy.id, updatedAt: 10 }),
      expect.anything(),
    );
  });

  it('applies server tombstones before merging cached reports', async () => {
    const { repository, backend } = createHarness();
    const cached = report({ id: 'deleted-elsewhere', updatedAt: 50 });
    await repository.saveLocal(cached);
    vi.mocked(backend.pull).mockResolvedValue({
      records: [],
      revisions: {},
      tombstones: [{ id: cached.id, revision: 2, deleted: true }],
    });

    await repository.reconcile();

    expect(await repository.get(cached.id)).toBeUndefined();
    expect(backend.push).not.toHaveBeenCalledWith(cached, expect.anything());
  });

  it('uses server revisions for a save followed by delete', async () => {
    const { repository, backend } = createHarness();
    vi.mocked(backend.push).mockResolvedValue({
      ok: true,
      offline: false,
      revision: 1,
    });
    vi.mocked(backend.remove).mockResolvedValue({
      ok: true,
      offline: false,
      revision: 2,
      deleted: true,
    });

    await repository.save(report());
    await repository.remove('lr-1');

    expect(backend.push).toHaveBeenCalledWith(report(), 0);
    expect(backend.remove).toHaveBeenCalledWith('lr-1', 1);
  });

  it('keeps an offline deletion local during later reconciliation', async () => {
    const { repository, backend } = createHarness();
    const deleted = report({ id: 'deleted' });
    await repository.saveLocal(deleted);
    vi.mocked(backend.remove).mockRejectedValue(new Error('offline'));

    await repository.remove('deleted');
    vi.mocked(backend.pull).mockResolvedValue([serializeLandingReport(deleted)]);
    await repository.reconcile();

    expect(await repository.get('deleted')).toBeUndefined();
  });
});
