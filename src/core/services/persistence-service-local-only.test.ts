import { describe, expect, it, vi } from 'vitest';

const state = vi.hoisted<{ root: Record<string, unknown> }>(() => ({
  root: {
    'module:landing_reports': {
      reports: [{ id: 'offline-only', updated_at: 50 }],
    },
    theme: 'local-theme',
  },
}));

vi.mock('idb-keyval', () => ({
  clear: vi.fn().mockResolvedValue(undefined),
  del: vi.fn().mockResolvedValue(undefined),
  get: vi.fn((key: string) =>
    Promise.resolve(
      key === 'owo-flight-assistant/persistence' ? structuredClone(state.root) : undefined,
    ),
  ),
  set: vi.fn((key: string, value: unknown) => {
    if (key === 'owo-flight-assistant/persistence') {
      state.root = structuredClone(value) as Record<string, unknown>;
    }
    return Promise.resolve();
  }),
}));

vi.mock('./settings-sync', () => ({
  pullSettings: vi.fn().mockResolvedValue({
    'module:landing_reports': {
      reports: [{ id: 'stale-remote', updated_at: 10 }],
    },
    theme: 'remote-theme',
  }),
  pushSetting: vi.fn().mockResolvedValue(undefined),
  removeSetting: vi.fn().mockResolvedValue(undefined),
  resetSettings: vi.fn().mockResolvedValue(undefined),
}));

import { PersistenceService } from './persistence-service';

describe('local-only persistence keys', () => {
  it('does not overlay the legacy landing-report bucket with stale remote settings', async () => {
    await PersistenceService.ensureReady();

    expect(PersistenceService.getModuleData('landing_reports', 'reports')).toEqual([
      { id: 'offline-only', updated_at: 50 },
    ]);
    expect(PersistenceService.getString('theme')).toBe('remote-theme');
  });
});
