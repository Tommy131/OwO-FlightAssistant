import { beforeEach, describe, expect, it, vi } from 'vitest';

import { PersistenceService } from '../../../core/services/persistence-service';
import { MiddlewareHttpException } from '../../http/models/http-models';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import { MiddlewareFlightDataAdapter } from './middleware-flight-data-adapter';

/**
 * 刷新页面后接回模拟器会话
 *
 * 修的是 A 项的前一半：token 只活在适配器的内存字段里，刷新后前端一律按
 * 「未连接」初始化，**而后端其实还连着模拟器**。用户被迫重新点连接，
 * 正在录制的话还会顺带丢掉数据。
 */

const SESSION_MODULE = 'common';
const SESSION_KEY = 'simulator_session';

/** 造一个 MiddlewareHttpResponse 的最小替身 */
function jsonResponse(body: Record<string, unknown>) {
  return {
    statusCode: 200,
    objectBody: body,
    decodedBody: body,
    isSuccess: true,
    uri: 'test',
  };
}

async function seedSession(value: unknown) {
  await PersistenceService.ensureReady();
  await PersistenceService.setModuleData(SESSION_MODULE, SESSION_KEY, value);
}

async function storedSession(): Promise<unknown> {
  await PersistenceService.ensureReady();
  return PersistenceService.getModuleData<unknown>(SESSION_MODULE, SESSION_KEY);
}

describe('resumeSession', () => {
  let adapter: MiddlewareFlightDataAdapter;

  beforeEach(async () => {
    vi.restoreAllMocks();
    adapter = new MiddlewareFlightDataAdapter();
    await PersistenceService.ensureReady();
    await PersistenceService.removeModuleData(SESSION_MODULE, SESSION_KEY);
    // 不让适配器在测试里真的去连 WebSocket / 起轮询
    vi.spyOn(
      adapter as unknown as { startRealtimeUpdates: (t: string) => Promise<void> },
      'startRealtimeUpdates',
    ).mockResolvedValue(undefined);
  });

  it('没有存档会话时直接返回 false', async () => {
    expect(await adapter.resumeSession()).toBe(false);
  });

  it('token 仍有效时接回连接状态', async () => {
    await seedSession({ token: 'tok-1', type: 'xplane' });
    const spy = vi
      .spyOn(MiddlewareHttpService, 'getSimulatorData')
      .mockResolvedValue(
        jsonResponse({ client_dataset: { connected: true, altitude_ft: 3000 } }) as never,
      );

    const resumed = await adapter.resumeSession();

    expect(resumed).toBe(true);
    expect(spy).toHaveBeenCalledWith('tok-1');
    let snapshot = null as unknown as { isConnected: boolean; simulatorType: string };
    adapter.subscribe((s) => {
      snapshot = s;
    });
    // subscribe 立即回放当前快照
    expect(snapshot.isConnected).toBe(true);
    expect(snapshot.simulatorType).toBe('xplane');
  });

  // token 过期（后端会话 10 分钟 idle TTL）时必须老实按未连接处理
  it('token 失效时清掉存档并返回 false', async () => {
    await seedSession({ token: 'stale', type: 'msfs' });
    vi.spyOn(MiddlewareHttpService, 'getSimulatorData').mockRejectedValue(
      new MiddlewareHttpException({ message: 'invalid_token', statusCode: 401 }),
    );

    expect(await adapter.resumeSession()).toBe(false);
    expect(await storedSession()).toBeUndefined();
  });

  it('后端不可达时也只是接不回去，不抛异常', async () => {
    await seedSession({ token: 'tok', type: 'xplane' });
    vi.spyOn(MiddlewareHttpService, 'getSimulatorData').mockRejectedValue(
      new Error('network down'),
    );

    await expect(adapter.resumeSession()).resolves.toBe(false);
  });

  it('存档结构不合法时忽略', async () => {
    const spy = vi.spyOn(MiddlewareHttpService, 'getSimulatorData');

    await seedSession({ token: '', type: 'xplane' });
    expect(await adapter.resumeSession()).toBe(false);

    await seedSession({ token: 'tok', type: 'p3d' });
    expect(await adapter.resumeSession()).toBe(false);

    await seedSession('garbage');
    expect(await adapter.resumeSession()).toBe(false);

    // 一次上游请求都不该发出去
    expect(spy).not.toHaveBeenCalled();
  });

  it('已经连着时不重复接回', async () => {
    const spy = vi
      .spyOn(MiddlewareHttpService, 'getSimulatorData')
      .mockResolvedValue(jsonResponse({ client_dataset: { connected: true } }) as never);
    await seedSession({ token: 'tok', type: 'xplane' });

    expect(await adapter.resumeSession()).toBe(true);
    spy.mockClear();
    expect(await adapter.resumeSession()).toBe(false);
    expect(spy).not.toHaveBeenCalled();
  });

  // 闭环的另一半：连接时不存 token，后面再怎么改恢复逻辑也永远接不回来
  it('连接成功后把 token 存下来', async () => {
    vi.spyOn(MiddlewareHttpService, 'connectSimulator').mockResolvedValue(
      jsonResponse({ token: 'fresh-token', type: 'msfs' }) as never,
    );
    vi.spyOn(MiddlewareHttpService, 'getSimulatorData').mockResolvedValue(
      jsonResponse({ client_dataset: { connected: true } }) as never,
    );

    expect(await adapter.connect('msfs')).toBe(true);
    expect(await storedSession()).toEqual({ token: 'fresh-token', type: 'msfs' });
  });

  it('主动断开会清掉存档，下次启动不再尝试接回', async () => {
    await seedSession({ token: 'tok', type: 'xplane' });
    vi.spyOn(MiddlewareHttpService, 'disconnectSimulator').mockResolvedValue(
      jsonResponse({ disconnected: true }) as never,
    );

    await adapter.disconnect();

    expect(await storedSession()).toBeUndefined();
  });
});
