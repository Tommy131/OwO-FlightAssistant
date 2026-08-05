import { AppLogger } from '../utils/logger';
import { toJsonMap, type JsonMap } from '../utils/parse-utils';
import { getBackendTransport } from './backend-transport';

/**
 * 后端存储同步
 *
 * 飞行日志与简报的落盘策略：
 *   - **后端为准**：中间件把记录写在 `resources/persistent/{flight_logs,briefings}/`，
 *     多个前端实例共享同一份数据
 *   - **IndexedDB 为缓存**：后端不可达时仍能查看与新增，恢复连通后自动补传
 *
 * 这样「前端保存 → 自动落到后端对应路径」，且离线不丢数据。
 */

/** 待补传队列的持久化键（存在 PersistenceService 的模块命名空间下） */
export const PENDING_SYNC_KEY = 'pending_backend_sync';

export type SyncKind = 'flightLog' | 'briefing';

export interface SyncResult {
  /** 后端是否成功接收 */
  ok: boolean;
  /** 后端不可达时为 true —— 调用方据此决定是否入队补传 */
  offline: boolean;
}

/** 保存一条记录到后端 */
export async function pushRecord(
  kind: SyncKind,
  id: string,
  record: unknown,
): Promise<SyncResult> {
  const transport = getBackendTransport();
  if (!transport) return { ok: false, offline: true };
  try {
    await transport.init();
    await transport.saveRecord(kind, id, record);
    return { ok: true, offline: false };
  } catch (e) {
    AppLogger.warning(`[BackendSync] push ${kind} ${id} failed: ${String(e)}`);
    return { ok: false, offline: true };
  }
}

/** 从后端删除一条记录 */
export async function removeRecord(kind: SyncKind, id: string): Promise<SyncResult> {
  const transport = getBackendTransport();
  if (!transport) return { ok: false, offline: true };
  try {
    await transport.init();
    await transport.deleteRecord(kind, id);
    return { ok: true, offline: false };
  } catch (e) {
    AppLogger.warning(`[BackendSync] delete ${kind} ${id} failed: ${String(e)}`);
    return { ok: false, offline: true };
  }
}

/**
 * 拉取后端全部记录
 * 后端不可达返回 null（与「后端有但为空」区分开，避免误判为需要清空本地）
 */
export async function pullRecords(kind: SyncKind): Promise<JsonMap[] | null> {
  const transport = getBackendTransport();
  if (!transport) return null;
  try {
    await transport.init();
    const records = await transport.listRecords(kind);
    if (!Array.isArray(records)) return [];

    return records
      .map((item) => toJsonMap(item))
      .filter((item): item is JsonMap => item !== null);
  } catch (e) {
    AppLogger.warning(`[BackendSync] pull ${kind} failed: ${String(e)}`);
    return null;
  }
}

/**
 * 合并后端与本地记录
 *
 * 以 id 去重；两边都有时**以后端为准**（后端是共享真相源），
 * 本地独有的条目保留 —— 它们是离线期间新增的，随后会被补传。
 */
export function mergeById<T extends { id: string }>(remote: T[], local: T[]): T[] {
  const byId = new Map<string, T>();
  for (const item of local) byId.set(item.id, item);
  for (const item of remote) byId.set(item.id, item);
  return [...byId.values()];
}
