import { afterEach, describe, expect, it, vi } from 'vitest';
import type { BackendTransport } from './backend-transport';
import { setBackendTransport } from './backend-transport';
import { pushRecord } from './backend-sync';

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
});
