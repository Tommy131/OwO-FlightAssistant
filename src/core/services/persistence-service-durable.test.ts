import { beforeEach, describe, expect, it, vi } from 'vitest';

const storage = vi.hoisted(() => ({
  get: vi.fn<(key: string) => Promise<unknown>>(),
  set: vi.fn<(key: string, value: unknown) => Promise<void>>(),
}));

vi.mock('idb-keyval', () => ({
  clear: vi.fn().mockResolvedValue(undefined),
  del: vi.fn().mockResolvedValue(undefined),
  get: storage.get,
  set: storage.set,
}));

vi.mock('./settings-sync', () => ({
  pullSettings: vi.fn().mockResolvedValue(null),
  pushSetting: vi.fn().mockResolvedValue(undefined),
  removeSetting: vi.fn().mockResolvedValue(undefined),
  resetSettings: vi.fn().mockResolvedValue(undefined),
}));

import { PersistenceService } from './persistence-service';

describe('durable module persistence', () => {
  beforeEach(() => {
    storage.get.mockReset().mockResolvedValue(undefined);
    storage.set.mockReset().mockResolvedValue(undefined);
  });

  it('propagates IndexedDB failure to the caller', async () => {
    storage.set.mockRejectedValueOnce(new Error('disk failed'));

    await expect(
      PersistenceService.setModuleDataDurable('flight_logs', 'logs', [{ id: 'flight-1' }]),
    ).rejects.toThrow('disk failed');
  });

  it('resolves only after the module bucket reaches IndexedDB', async () => {
    await PersistenceService.setModuleDataDurable('flight_logs', 'logs', [{ id: 'flight-2' }]);

    expect(storage.set).toHaveBeenCalledOnce();
    const [key, value] = storage.set.mock.calls[0];
    expect(key).toBe('owo-flight-assistant/persistence');
    expect(value).toMatchObject({
      'module:flight_logs': {
        logs: [{ id: 'flight-2' }],
      },
    });
  });

  it('reads the last durable module value directly from IndexedDB', async () => {
    storage.get.mockResolvedValueOnce({
      'module:flight_logs': {
        logs: [{ id: 'durable-flight' }],
      },
    });

    await expect(
      PersistenceService.getDurableModuleData('flight_logs', 'logs'),
    ).resolves.toEqual([{ id: 'durable-flight' }]);
  });
});
