import { afterEach, describe, expect, it, vi } from 'vitest';
import type { BackendTransport } from './backend-transport';
import { setBackendTransport } from './backend-transport';
import { pullRecordState, pushRecord, removeRecord } from './backend-sync';

describe('pushRecord', () => {
  afterEach(() => {
    setBackendTransport(null);
  });

  it('forwards landing reports as their own backend record kind', async () => {
    const saveRecord = vi.fn<BackendTransport['saveRecord']>().mockResolvedValue(undefined);
    setBackendTransport({
      init: vi.fn().mockResolvedValue(undefined),
      saveRecord,
      deleteRecord: vi.fn().mockResolvedValue(undefined),
      listRecords: vi.fn().mockResolvedValue([]),
      getAllSettings: vi.fn().mockResolvedValue({}),
      setSetting: vi.fn().mockResolvedValue(undefined),
      deleteSetting: vi.fn().mockResolvedValue(undefined),
      resetSettings: vi.fn().mockResolvedValue(undefined),
      setSettingsBulk: vi.fn().mockResolvedValue(undefined),
    });

    await pushRecord('landingReport', 'lr-1', { id: 'lr-1', updatedAt: 42 });

    expect(saveRecord).toHaveBeenCalledWith('landingReport', 'lr-1', {
      id: 'lr-1',
      updatedAt: 42,
    });
    expect(saveRecord).not.toHaveBeenCalledWith('flightLog', expect.anything(), expect.anything());
  });

  it('forwards expected revisions and returns the accepted server revision', async () => {
    const saveRecord = vi.fn<BackendTransport['saveRecord']>().mockResolvedValue({
      revision: 4,
    });
    setBackendTransport({
      init: vi.fn().mockResolvedValue(undefined),
      saveRecord,
      deleteRecord: vi.fn().mockResolvedValue({ revision: 5, deleted: true }),
      listRecords: vi.fn().mockResolvedValue([]),
      getAllSettings: vi.fn().mockResolvedValue({}),
      setSetting: vi.fn().mockResolvedValue(undefined),
      deleteSetting: vi.fn().mockResolvedValue(undefined),
      resetSettings: vi.fn().mockResolvedValue(undefined),
      setSettingsBulk: vi.fn().mockResolvedValue(undefined),
    });

    await expect(
      pushRecord('landingReport', 'lr-1', { id: 'lr-1' }, { expectedRevision: 3 }),
    ).resolves.toMatchObject({ ok: true, revision: 4 });
    await expect(
      removeRecord('landingReport', 'lr-1', { expectedRevision: 4 }),
    ).resolves.toMatchObject({ ok: true, revision: 5, deleted: true });
    expect(saveRecord).toHaveBeenCalledWith(
      'landingReport',
      'lr-1',
      { id: 'lr-1' },
      { expectedRevision: 3 },
    );
  });

  it('classifies a revision conflict instead of treating it as offline', async () => {
    setBackendTransport({
      init: vi.fn().mockResolvedValue(undefined),
      saveRecord: vi.fn().mockRejectedValue({
        statusCode: 409,
        data: {
          error: 'record_deleted',
          current_revision: 7,
          deleted: true,
        },
      }),
      deleteRecord: vi.fn().mockResolvedValue(undefined),
      listRecords: vi.fn().mockResolvedValue([]),
      getAllSettings: vi.fn().mockResolvedValue({}),
      setSetting: vi.fn().mockResolvedValue(undefined),
      deleteSetting: vi.fn().mockResolvedValue(undefined),
      resetSettings: vi.fn().mockResolvedValue(undefined),
      setSettingsBulk: vi.fn().mockResolvedValue(undefined),
    });

    await expect(
      pushRecord('landingReport', 'lr-1', {}, { expectedRevision: 2 }),
    ).resolves.toEqual({
      ok: false,
      offline: false,
      conflict: true,
      revision: 7,
      deleted: true,
    });
  });

  it('pulls additive revisions and tombstones when the transport supports them', async () => {
    setBackendTransport({
      init: vi.fn().mockResolvedValue(undefined),
      saveRecord: vi.fn().mockResolvedValue(undefined),
      deleteRecord: vi.fn().mockResolvedValue(undefined),
      listRecords: vi.fn().mockResolvedValue([]),
      listRecordState: vi.fn().mockResolvedValue({
        records: [{ id: 'lr-1' }],
        revisions: { 'lr-1': 3 },
        tombstones: [{ id: 'gone', revision: 2, deleted: true }],
      }),
      getAllSettings: vi.fn().mockResolvedValue({}),
      setSetting: vi.fn().mockResolvedValue(undefined),
      deleteSetting: vi.fn().mockResolvedValue(undefined),
      resetSettings: vi.fn().mockResolvedValue(undefined),
      setSettingsBulk: vi.fn().mockResolvedValue(undefined),
    });

    await expect(pullRecordState('landingReport')).resolves.toEqual({
      records: [{ id: 'lr-1' }],
      revisions: { 'lr-1': 3 },
      tombstones: [{ id: 'gone', revision: 2, deleted: true }],
    });
  });
});
