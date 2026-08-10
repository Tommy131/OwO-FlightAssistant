import { beforeEach, describe, expect, it } from 'vitest';

import { PersistenceService } from '../../../core/services/persistence-service';
import { isReviewMode, useAppModeStore } from './app-mode-store';

describe('useAppModeStore', () => {
  beforeEach(() => {
    useAppModeStore.setState({ mode: 'live', hydrated: false });
  });

  it('默认是实时模式', () => {
    expect(useAppModeStore.getState().mode).toBe('live');
    expect(isReviewMode()).toBe(false);
  });

  it('切到复盘模式后 isReviewMode 立即为真', async () => {
    await useAppModeStore.getState().setMode('review');
    expect(useAppModeStore.getState().mode).toBe('review');
    expect(isReviewMode()).toBe(true);
  });

  it('toggle 在两种模式间往返', async () => {
    await useAppModeStore.getState().toggle();
    expect(useAppModeStore.getState().mode).toBe('review');
    await useAppModeStore.getState().toggle();
    expect(useAppModeStore.getState().mode).toBe('live');
  });

  it('设置成当前值时不做任何事', async () => {
    await useAppModeStore.getState().setMode('live');
    expect(useAppModeStore.getState().mode).toBe('live');
  });

  it('模式会持久化，重启后能恢复', async () => {
    await PersistenceService.ensureReady();
    await useAppModeStore.getState().setMode('review');

    // 模拟重启：清掉内存态再 hydrate
    useAppModeStore.setState({ mode: 'live', hydrated: false });
    await useAppModeStore.getState().hydrate();

    expect(useAppModeStore.getState().mode).toBe('review');
  });

  it('hydrate 幂等，不会把用户刚切的模式冲掉', async () => {
    await useAppModeStore.getState().hydrate();
    await useAppModeStore.getState().setMode('review');
    await useAppModeStore.getState().hydrate();
    expect(useAppModeStore.getState().mode).toBe('review');
  });

  it('存储里是脏值时回落到实时模式', async () => {
    await PersistenceService.ensureReady();
    await PersistenceService.setModuleData('app', 'app_mode', 'banana');

    useAppModeStore.setState({ mode: 'review', hydrated: false });
    await useAppModeStore.getState().hydrate();

    expect(useAppModeStore.getState().mode).toBe('live');
  });
});
