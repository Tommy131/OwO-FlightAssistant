import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { SyncResult } from '../../../core/services/backend-sync';
import { AppLogger } from '../../../core/utils/logger';
import { serializeLandingReport, type LandingReport } from '../models/landing-report-models';
import { makeFlightLogPoint } from '../test/flight-log-fixtures';
import {
  ACTIVE_LANDING_REPORT_KEY,
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
  const archive = new Map<string, unknown>();
  const order: string[] = [];
  const persistence: LandingReportsPersistence = {
    ensureReady: vi.fn().mockResolvedValue(undefined),
    getModuleData: <T>(moduleName: string, key: string) =>
      modules.get(`${moduleName}/${key}`) as T | undefined,
    setModuleData: vi.fn(async (moduleName: string, key: string, value: unknown) => {
      order.push('local');
      modules.set(`${moduleName}/${key}`, value);
    }),
  };
  const archiveStorage: LandingReportsArchiveStorage = {
    get: vi.fn((key: string) => Promise.resolve(archive.get(key))),
    set: vi.fn(async (key: string, value: unknown) => {
      archive.set(key, value);
    }),
    remove: vi.fn(async (key: string) => {
      archive.delete(key);
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
    archive,
    order,
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
    expect(order).toEqual(['local']);
    expect(backend.push).toHaveBeenCalledWith(report());
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
    const { repository, backend, persistence } = createHarness();
    const localWinner = report({ id: 'local-wins', updatedAt: 20 });
    const remoteWinnerLocalCopy = report({ id: 'remote-wins', updatedAt: 10 });
    await persistence.setModuleData('landing_reports', 'reports', [
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
    expect(backend.push).toHaveBeenCalledWith(localWinner);
    expect(backend.push).not.toHaveBeenCalledWith(remoteWinnerLocalCopy);
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
